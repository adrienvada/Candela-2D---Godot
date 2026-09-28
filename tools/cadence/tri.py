#!/usr/bin/env python3
"""LE TRI DU CLOUD — l'analyse (session cloud « cadence-version », 2026-09-28). Appelé par `tools/cadence/tri_cloud.sh`.

    python3 tools/cadence/tri.py <sortie> <référence> [--temoin=<nom>] <nom> [<nom> …]

Pour chaque lancement <nom> (fait par `tri_cloud.sh` : l'outil Budget avec captures et GLSL capturé), comparé à <référence> :
  1. LES COMPTES (`<sortie>/journaux/<nom>.log`, lignes `BUDGET`) : appels de dessin, primitives, vues rendues, copies
     d'écran, lumières à ombre — six cartes à 45° B (médiane des six écarts) et le pompe sous une fusée (écart des moyennes
     de 120 images), en vue unique et en écran scindé ;
  2. LES PROGRAMMES DE SHADER (`<sortie>/glsl/<nom>/*.shader_test`, le GLSL que Godot donne à Mesa) : ceux qui n'existent
     pas dans la référence, chacun compilé en SPIR-V et optimisé (glslangValidator, spirv-opt -O) et comparé au programme
     le plus proche de la référence : instructions, lectures de texture, boucles EN PLUS ;
  3. LA PART DE L'ÉCRAN qui change (`<sortie>/captures/<nom>/`) : sur les six cartes, les pixels dont un canal bouge de plus
     de 16/255 — une borne BASSE des pixels touchés (un shader plus cher qui rend la même image n'y paraît pas).
Puis il CLASSE : neutre, à surveiller, lourde (seuils et leur pourquoi : SEUILS ci-dessous). Écrit `<sortie>/TRI.md` et
`<sortie>/tri.json`. Aucun chiffre de temps : le cloud ne mesure pas la cadence.
"""
import collections
import glob
import hashlib
import json
import os
import re
import statistics
import subprocess
import sys

# ─── LES SEUILS, et d'où ils viennent (mesures du Mac, règle 278 : pompe sous une fusée, vue unique) ───
# Le bruit des comptes, relevé par la session « Budget » (deux lancements de la même chose) : ±3 appels par carte en vue
# unique, ±7 en écran scindé ; au pompe, la moyenne de 120 images à ±2 et ±8. Un témoin (--temoin) le remplace s'il est
# plus grand.
BRUIT = {"carte/unique": 3.0, "carte/scinde": 7.0, "pompe/unique": 2.0, "pompe/scinde": 8.0}
# Les personnages détaillés : +12 appels par carte en vue unique (+9 %), +24 en écran scindé, et 0,976 au Mac (ROADMAP,
# Q33, `cef9d93`) — ils TIENNENT, à 0,6 point de la barre. Au-delà de +12 appels en vue unique (ou +24 en écran scindé),
# on n'a aucune preuve que la règle tienne : « lourde ». Entre le bruit et +12 : « à surveiller ».
APPELS_LOURDS = {"carte/unique": 12.0, "carte/scinde": 24.0, "pompe/unique": 12.0, "pompe/scinde": 24.0}
# Les tuyaux : +1 appel, mais les primitives de la scène 3D ×3 (Budget), jamais mesurés au Mac. Une hausse des primitives
# de plus de 10 % se surveille ; au-delà de +50 %, c'est une nouveauté de GÉOMÉTRIE lourde (et l'écran scindé se mesure).
PRIMITIVES_SURVEILLER = 0.10
PRIMITIVES_LOURDES = 0.50
# Une vue rendue, une copie d'écran ou une lumière à ombre de plus : une passe entière de plus, sur tout l'écran. Le
# premier masque de la fumée, qui copiait l'écran, a coûté 0,943 (docs/iso/iso13/plan_lots_d_e.md) : « lourde » d'office.
# Les programmes de shader. Le masque de la fumée et sa bande ne changent AUCUN compte et ont coûté 0,838 (ROADMAP,
# bande des faces, iso11) : zéro appel n'est pas gratuit. Ce que le tri voit de lui (tri de calibrage, `--fumee-masque` sur
# 1dc5ec8, TRI.md du rapport) : des boucles et des lectures de texture en plus dans le fragment des volumes. Le rouge long
# (1,024 au Mac : il tient) n'ajoute aucun programme. D'où :
#   - une boucle dynamique de plus dans un programme : « lourde » (le coût se multiplie par le nombre de tours, par pixel) ;
#   - des lectures de texture en plus (LECTURES_LOURDES ou plus) : « lourde » ; moins, mais au moins une : « à surveiller » ;
#   - des instructions en plus (INSTR_SURVEILLER ou plus) sans lecture ni boucle : « à surveiller » ;
#   - en deçà : « neutre » pour le shader.
LECTURES_LOURDES = 4
INSTR_SURVEILLER = 150
# La part de l'écran qui change (six cartes, max de la vue unique et de l'écran scindé, bruit du témoin retiré). Elle ne
# classe pas seule — une image qui change sans shader plus cher ne coûte rien — ; elle dit OÙ un shader plus cher paie.
PART_NEGLIGEABLE = 0.001
SEUIL_PIXEL = 16

SORTIE = sys.argv[1]
REF = sys.argv[2]
TEMOIN = None
NOMS = []
for a in sys.argv[3:]:
    if a.startswith("--temoin="):
        TEMOIN = a.split("=", 1)[1]
    else:
        NOMS.append(a)


# ─── 1. LES COMPTES ───
def releves(nom):
    r = {}
    chemin = os.path.join(SORTIE, "journaux", nom + ".log")
    if not os.path.exists(chemin):
        return r
    for ligne in open(chemin, encoding="utf-8", errors="replace"):
        if ligne.startswith("BUDGET\t"):
            d = json.loads(ligne.split("\t", 1)[1])
            r[(d["famille"], d["scene"], d["vue"])] = d
    return r


def val(d, cle):
    v = d["compteurs"].get(cle)
    if v is None:
        return 0.0
    # Au pompe, la moyenne de 120 images (la médiane ment d'un lancement à l'autre : rapport Budget) ; ailleurs la médiane.
    return float(v.get("moy", v["med"]) if d["famille"] == "pompe" else v["med"])


CLES = [("total.appels", "appels"), ("total.primitives", "primitives"), ("passes.vues_rendues", "vues"),
        ("passes.copies_ecran", "copies"), ("lumieres.2d_ombre", "ombres2d"), ("lumieres.3d_ombre", "ombres3d")]


def ecarts(ref, var):
    """Par famille/vue : la médiane des écarts (cartes) ou l'écart (pompe), pour chaque clé ; et la référence."""
    par = collections.defaultdict(lambda: collections.defaultdict(list))
    base = collections.defaultdict(lambda: collections.defaultdict(list))
    for k, d in var.items():
        if k not in ref:
            continue
        fam = "%s/%s" % ("pompe" if k[0] == "pompe" else "carte", k[2])
        for cle, court in CLES:
            par[fam][court].append(val(d, cle) - val(ref[k], cle))
            base[fam][court].append(val(ref[k], cle))
    out = {}
    for fam in par:
        out[fam] = {c: statistics.median(v) for c, v in par[fam].items()}
        out[fam]["ref_appels"] = statistics.median(base[fam]["appels"])
        out[fam]["ref_primitives"] = statistics.median(base[fam]["primitives"])
        out[fam]["max_appels"] = max(par[fam]["appels"])
        out[fam]["n"] = len(par[fam]["appels"])
    return out


# ─── 2. LES PROGRAMMES DE SHADER ───
CACHE = os.path.join(SORTIE, "glsl_compte")
os.makedirs(CACHE, exist_ok=True)


def sections(chemin):
    texte = open(chemin, errors="replace").read()
    out = {}
    for m in re.finditer(r"\[(fragment|vertex) shader\]\n(.*?)(?=\n\[[a-z ]+\]\n|\Z)", texte, re.S):
        out[m.group(1)] = m.group(2)
    return out


def programmes(nom):
    """{empreinte : (fichier, fragment)} — l'empreinte porte sur le vertex ET le fragment."""
    r = {}
    for chemin in glob.glob(os.path.join(SORTIE, "glsl", nom, "*.shader_test")):
        s = sections(chemin)
        if "fragment" not in s:
            continue
        h = hashlib.sha1((s.get("vertex", "") + "\n@@\n" + s["fragment"]).encode()).hexdigest()[:16]
        r[h] = (chemin, s["fragment"])
    return r


def compter(frag):
    h = hashlib.sha1(frag.encode()).hexdigest()[:16]
    memo = os.path.join(CACHE, h + ".json")
    if os.path.exists(memo):
        return json.load(open(memo))
    base = os.path.join(CACHE, h)
    open(base + ".frag", "w").write(frag)
    r = subprocess.run(["glslangValidator", "-G", "--auto-map-bindings", "--auto-map-locations", "-S", "frag", "-o",
                        base + ".spv", base + ".frag"], capture_output=True, text=True)
    if r.returncode != 0:
        c = {"erreur": r.stdout[-300:]}
    else:
        subprocess.run(["spirv-opt", "-O", base + ".spv", "-o", base + ".o.spv"], check=True)
        dis = subprocess.run(["spirv-dis", base + ".o.spv"], capture_output=True, text=True, check=True).stdout
        c = {
            "instructions": sum(1 for l in dis.splitlines() if re.search(r"\bOp[A-Z]", l) and not re.search(
                r"Op(Name|MemberName|Decorate|MemberDecorate|Label|Variable|Type|Constant|Capability|Extension|Source|"
                r"String|Line|ExtInstImport|MemoryModel|EntryPoint|ExecutionMode)", l)),
            "lectures": len(re.findall(r"OpImage(Sample|Fetch|Gather|Read)", dis)),
            "boucles": dis.count("OpLoopMerge"),
            "branchements": dis.count("OpBranchConditional"),
        }
        for ext in (".spv", ".o.spv"):
            try:
                os.remove(base + ext)
            except OSError:
                pass
    json.dump(c, open(memo, "w"))
    return c


def identifiants(frag):
    # Godot préfixe les fonctions de l'utilisateur par « m_ » : elles disent de quel shader du jeu vient le programme.
    return set(re.findall(r"\bm_\w+", frag)) | set(re.findall(r"^#define (\w+)", frag, re.M))


def comparer_shaders(ref_p, var_p):
    nouveaux = [h for h in var_p if h not in ref_p]
    disparus = [h for h in ref_p if h not in var_p]
    ref_ids = {h: identifiants(f) for h, (_, f) in ref_p.items()}
    lignes = []
    for h in nouveaux:
        chemin, frag = var_p[h]
        ids = identifiants(frag)
        # Le programme le plus proche de la référence : le plus d'identifiants communs (Jaccard).
        meilleur, score = None, -1.0
        for hr, ir in ref_ids.items():
            u = len(ids | ir)
            s = len(ids & ir) / u if u else 0.0
            if s > score:
                meilleur, score = hr, s
        c = compter(frag)
        if "erreur" in c:
            lignes.append({"programme": os.path.basename(chemin), "erreur": c["erreur"]})
            continue
        p = compter(ref_p[meilleur][1]) if meilleur and score >= 0.5 else {"instructions": 0, "lectures": 0, "boucles": 0}
        if "erreur" in p:
            p = {"instructions": 0, "lectures": 0, "boucles": 0}
        propres = sorted(i for i in ids - (ref_ids.get(meilleur, set()) if score >= 0.5 else set()) if i.startswith("m_"))
        famille = sorted(i for i in ids if i.startswith("m_"))[:3]
        lignes.append({
            "programme": os.path.basename(chemin), "proche": os.path.basename(ref_p[meilleur][0]) if meilleur else "-",
            "ressemblance": round(score, 2), "instructions": c["instructions"], "lectures": c["lectures"],
            "boucles": c["boucles"], "d_instructions": c["instructions"] - p["instructions"],
            "d_lectures": c["lectures"] - p["lectures"], "d_boucles": c["boucles"] - p["boucles"],
            "nouveau_code": propres[:6], "famille": famille,
        })
    return {"nouveaux": len(nouveaux), "disparus": len(disparus), "total_ref": len(ref_p), "total": len(var_p),
            "detail": sorted(lignes, key=lambda x: -x.get("d_instructions", 0))}


# ─── 3. LA PART DE L'ÉCRAN ───
def part_ecran(nom_ref, nom):
    try:
        from PIL import Image
        import numpy as np
    except ImportError:
        return None
    out = {}
    for chemin in glob.glob(os.path.join(SORTIE, "captures", nom, "%s_carte_*.jpg" % nom)):
        fin = os.path.basename(chemin)[len(nom) + 1:]
        autre = os.path.join(SORTIE, "captures", nom_ref, "%s_%s" % (nom_ref, fin))
        if not os.path.exists(autre):
            continue
        a = np.asarray(Image.open(autre).convert("RGB"), dtype=np.int16)
        b = np.asarray(Image.open(chemin).convert("RGB"), dtype=np.int16)
        if a.shape != b.shape:
            continue
        out[fin.replace("carte_", "").replace("_l45.jpg", "").replace("_l0.jpg", "")] = float(
            (np.abs(a - b).max(axis=2) > SEUIL_PIXEL).mean())
    return out


# ─── LE CLASSEMENT ───
def classer(c, sh, part, bruit):
    raisons_l, raisons_s = [], []
    geometrie = False
    for fam, e in c.items():
        b = bruit.get(fam, 3.0)
        da = e["appels"]
        if da > APPELS_LOURDS[fam]:
            raisons_l.append("%+.1f appels en %s (> %+g, le détail des corps qui tient à 0,976)" % (da, fam, APPELS_LOURDS[fam]))
            geometrie = True
        elif da > b:
            raisons_s.append("%+.1f appels en %s (bruit ±%g)" % (da, fam, b))
        rp = e["primitives"] / e["ref_primitives"] if e["ref_primitives"] else 0.0
        if rp > PRIMITIVES_LOURDES:
            raisons_l.append("primitives %+.0f %% en %s (géométrie : les tuyaux, ×3, jamais mesurés)" % (100 * rp, fam))
            geometrie = True
        elif rp > PRIMITIVES_SURVEILLER:
            raisons_s.append("primitives %+.0f %% en %s" % (100 * rp, fam))
        for cle, lib in (("vues", "vue rendue"), ("copies", "copie d'écran"), ("ombres2d", "lumière 2D à ombre"),
                         ("ombres3d", "lumière 3D à ombre")):
            if e[cle] >= 0.5:
                raisons_l.append("%+.1f %s en %s (une passe entière de plus)" % (e[cle], lib, fam))
    for p in sh["detail"]:
        if "erreur" in p:
            raisons_s.append("programme %s non compilé par glslang (compte impossible)" % p["programme"])
            continue
        qui = ", ".join(p["nouveau_code"] or p["famille"]) or "?"
        if p["d_boucles"] >= 1:
            raisons_l.append("shader : +%d boucle(s) (%s)" % (p["d_boucles"], qui))
        elif p["d_lectures"] >= LECTURES_LOURDES:
            raisons_l.append("shader : +%d lectures de texture (%s)" % (p["d_lectures"], qui))
        elif p["d_lectures"] >= 1:
            raisons_s.append("shader : +%d lecture(s) de texture (%s)" % (p["d_lectures"], qui))
        elif p["d_instructions"] >= INSTR_SURVEILLER:
            raisons_s.append("shader : +%d instructions (%s)" % (p["d_instructions"], qui))
    classe = "lourde" if raisons_l else ("à surveiller" if raisons_s else "neutre")
    return classe, raisons_l + raisons_s, geometrie


ref_r = releves(REF)
ref_p = programmes(REF)
bruit = dict(BRUIT)
temoin = {}
if TEMOIN:
    t = ecarts(ref_r, releves(TEMOIN))
    for fam, e in t.items():
        bruit[fam] = max(bruit[fam], abs(e["appels"]), abs(e["max_appels"]))
    temoin = {"comptes": t, "shaders": comparer_shaders(ref_p, programmes(TEMOIN)), "part": part_ecran(REF, TEMOIN)}
bruit_part = max((temoin.get("part") or {}).values() or [0.0])

resultats = {"reference": REF, "temoin": temoin, "bruit": bruit, "bruit_part": bruit_part, "essais": {}}
for nom in NOMS:
    c = ecarts(ref_r, releves(nom))
    sh = comparer_shaders(ref_p, programmes(nom))
    # Un programme que le TÉMOIN a aussi fait naître n'est pas l'œuvre de l'essai (compilation paresseuse selon la scène).
    if temoin:
        vus_t = {(p.get("d_instructions"), p.get("d_lectures"), p.get("d_boucles"), tuple(p.get("nouveau_code", [])))
                 for p in temoin["shaders"]["detail"]}
        sh["detail"] = [p for p in sh["detail"] if (p.get("d_instructions"), p.get("d_lectures"), p.get("d_boucles"),
                                                     tuple(p.get("nouveau_code", []))) not in vus_t]
    part = part_ecran(REF, nom) or {}
    classe, raisons, geometrie = classer(c, sh, part, bruit)
    resultats["essais"][nom] = {"comptes": c, "shaders": sh, "part": part, "classe": classe, "raisons": raisons,
                                "geometrie": geometrie}

json.dump(resultats, open(os.path.join(SORTIE, "tri.json"), "w"), indent=1, ensure_ascii=False)

# ─── LE TABLEAU ───
def f(x, sig=True):
    return ("%+.1f" if sig else "%.1f") % x if isinstance(x, float) and not float(x).is_integer() else (("%+d" if sig else "%d") % x)


L = []
L.append("# Tri du cloud — référence « %s »%s\n" % (REF, " · témoin « %s »" % TEMOIN if TEMOIN else ""))
L.append("Comptes : écart à la référence, médiane des six cartes (vue unique U, écran scindé S) et moyenne de 120 images au "
         "pompe sous une fusée (PU, PS). Bruit retenu : %s. Aucun temps : le cloud ne mesure pas la cadence.\n"
         % ", ".join("%s ±%g" % (k, v) for k, v in bruit.items()))
L.append("| nouveauté | classe | Δ appels U / S | Δ appels PU / PS | Δ primitives U (%) | vues, copies, ombres | "
         "programmes nouveaux | pire programme : Δ instr. / lect. / boucles | part de l'écran (max, cartes) |")
L.append("|---|---|---|---|---|---|---|---|---|")
for nom, r in resultats["essais"].items():
    c = r["comptes"]
    g = lambda fam, k: c.get(fam, {}).get(k, 0.0)
    passes = sum(abs(g(fam, k)) for fam in c for k in ("vues", "copies", "ombres2d", "ombres3d"))
    pire = r["shaders"]["detail"][0] if r["shaders"]["detail"] else None
    pire_txt = ("%+d / %+d / %+d" % (pire["d_instructions"], pire["d_lectures"], pire["d_boucles"])
                if pire and "erreur" not in pire else "—")
    rp = 100.0 * g("carte/unique", "primitives") / (g("carte/unique", "ref_primitives") or 1.0)
    part = max(r["part"].values()) if r["part"] else None
    L.append("| %s | **%s** | %s / %s | %s / %s | %+.1f | %s | %d | %s | %s |" % (
        nom, r["classe"], f(g("carte/unique", "appels")), f(g("carte/scinde", "appels")), f(g("pompe/unique", "appels")),
        f(g("pompe/scinde", "appels")), rp, "aucune" if passes < 0.5 else "%+.1f" % passes,
        len(r["shaders"]["detail"]), pire_txt, "—" if part is None else "%.2f %%" % (100 * part)))
L.append("")
for nom, r in resultats["essais"].items():
    L.append("**%s — %s.** %s" % (nom, r["classe"], " ; ".join(r["raisons"]) or "rien au-delà du bruit, aucun programme de "
                                                                                      "shader nouveau."))
    for p in r["shaders"]["detail"][:4]:
        if "erreur" in p:
            continue
        L.append("  - programme %s (proche : %s, ressemblance %.2f) : %d instructions, %d lectures, %d boucles ; Δ %+d / %+d / "
                 "%+d ; code propre : %s" % (p["programme"], p["proche"], p["ressemblance"], p["instructions"],
                                              p["lectures"], p["boucles"], p["d_instructions"], p["d_lectures"],
                                              p["d_boucles"], ", ".join(p["nouveau_code"]) or "—"))
    L.append("")
if temoin:
    L.append("**Témoin** (la référence relancée) : Δ appels %s ; programmes nouveaux %d ; part de l'écran %.2f %% au plus "
             "— c'est le bruit." % (", ".join("%s %s" % (k, f(v["appels"])) for k, v in temoin["comptes"].items()),
                                   len(temoin["shaders"]["detail"]), 100 * bruit_part))
open(os.path.join(SORTIE, "TRI.md"), "w").write("\n".join(L) + "\n")
print("\n".join(L))
