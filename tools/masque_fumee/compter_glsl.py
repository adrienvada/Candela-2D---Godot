#!/usr/bin/env python3
"""LE MASQUE DE LA FUMÉE, COMPTÉ DANS LE GLSL QUE GODOT GÉNÈRE (session cloud « masque-fumée », 2026-09-27).

Le cloud ne mesure pas le temps ; il peut compter le CODE. Mesa (le pilote du conteneur) écrit chaque programme GLSL que
Godot lui donne à compiler si on lance le jeu avec MESA_SHADER_CAPTURE_PATH=<dossier> : un fichier `.shader_test` par
programme, le GLSL final, après le préprocesseur de Godot (les `#ifdef` du jeu y sont déjà résolus, les includes collés).
Ce script en retire le fragment de chaque programme de la fumée (celui qui contient `m_lire_lightmap_lissee`), le compile
en SPIR-V (glslangValidator), l'optimise (spirv-opt -O : inlining, élimination du code mort, comme un pilote) et compte :
instructions, lectures de texture, branchements, boucles, fonctions mathématiques ; puis, AVANT inlining, la taille de
chaque fonction et sa taille une fois recopiée à chacun de ses appels.

Ce que ces nombres disent : la taille du code que le GPU reçoit, et combien de fois une fonction y est recopiée. Ce qu'ils
ne disent pas : le temps. Le compilateur du Mac (Apple, derrière OpenGL) n'est pas spirv-opt ; les proportions valent, pas
les valeurs absolues.

    python3 tools/masque_fumee/compter_glsl.py <dossier de capture> [<dossier de travail>]

Requiert glslang-tools et spirv-tools (apt-get install glslang-tools spirv-tools)."""
import collections, functools, glob, os, re, subprocess, sys

CAP = sys.argv[1]
TRAV = sys.argv[2] if len(sys.argv) > 2 else os.path.join(CAP, "compte")
os.makedirs(TRAV, exist_ok=True)


def fragment(chemin):
    texte = open(chemin, errors="replace").read()
    m = re.search(r"\[fragment shader\]\n(.*?)(?=\n\[[a-z ]+\]\n|\Z)", texte, re.S)
    return m.group(1) if m else ""


def forme(glsl):
    # Toutes les fonctions de l'include sont émises, appelées ou non : une forme se reconnaît à ce que son fragment APPELLE
    # (une définition plus au moins un appel = deux occurrences).
    def appelle(f):
        return glsl.count(f + "(") >= 2
    if appelle("m_juge_couvre"):
        # Session « masque-fumée-2 » : le juge de V4 (et de V5, dont MASQUE_AJUSTE n'ajoute aucun code) appelle la borne.
        return "pochoir : le juge, lumière d'abord" if appelle("m_sol_borne_lumiere") else "pochoir : le juge"
    # Godot n'émet que les fonctions appelées, mais TOUS les uniformes : les couches du pochoir se reconnaissent à ceux du juge.
    if "juge_rayons" in glsl and not appelle("m_masque_compact_montre_noir"):
        return "pochoir : les couches"
    if appelle("m_masque_compact_montre_noir"):
        return "bande resserrée" if "m_sol_montre_noir_resserre_au_point(" in glsl else "compacte"
    if appelle("m_masque_montre_noir"):
        return "Gadgets"
    return "sans masque"


def compter(dis):
    return {
        "instructions": sum(1 for l in dis.splitlines() if re.search(r"\bOp[A-Z]", l) and "OpName" not in l
                            and "OpDecorate" not in l and "OpMemberDecorate" not in l and "OpMemberName" not in l),
        "lectures": dis.count("OpImageSample"),
        "branchements": dis.count("OpBranchConditional"),
        "boucles": dis.count("OpLoopMerge"),
        "math": dis.count("OpExtInst"),
    }


def par_fonction(dis):
    noms, corps, lect, appels = {}, collections.Counter(), collections.Counter(), collections.defaultdict(collections.Counter)
    for l in dis.splitlines():
        m = re.match(r'\s*OpName (%\S+) "([^"(]+)', l)
        if m:
            noms[m.group(1)] = m.group(2)
    cur = None
    for l in dis.splitlines():
        m = re.match(r"\s*(%\S+) = OpFunction ", l)
        if m:
            cur = noms.get(m.group(1), m.group(1))
            continue
        if "OpFunctionEnd" in l:
            cur = None
            continue
        if cur:
            if re.search(r"\bOp[A-Z]", l) and "OpLabel" not in l and "OpVariable" not in l:
                corps[cur] += 1
            if "OpImageSample" in l:
                lect[cur] += 1
            m = re.search(r"OpFunctionCall %\S+ (%\S+)", l)
            if m:
                appels[cur][noms.get(m.group(1), m.group(1))] += 1

    @functools.lru_cache(None)
    def taille(f):
        return corps[f] + sum(n * taille(g) for g, n in appels[f].items())

    @functools.lru_cache(None)
    def lectures(f):
        return lect[f] + sum(n * lectures(g) for g, n in appels[f].items())

    return corps, appels, taille, lectures


def signature(glsl):
    """Les #define de Godot qui choisissent la SPÉCIALISATION du programme (passe, lumières, instances…) : on ne compare
    les formes que sur une même spécialisation."""
    tete = glsl.split("precision highp float;")[0]
    return tuple(sorted(l for l in tete.splitlines() if l.startswith("#define ") and "MAX_" not in l))


vus = {}
for chemin in sorted(glob.glob(os.path.join(CAP, "*.shader_test")), key=lambda p: int(re.sub(r"\D", "", os.path.basename(p)) or 0)):
    glsl = fragment(chemin)
    if ("m_lire_lightmap_lissee" not in glsl and "m_juge_couvre" not in glsl) or "#define BASE_PASS" not in glsl:
        continue
    # Les doubles qui COMPTENT (plan `loupe-fusee-masque-formes`, 50/255 par fragment) ne sont pas des shaders du jeu.
    if "albedo=vec3((50.0 / 255.0))" in glsl:
        continue
    cle = (forme(glsl), "usure" if "m_usure_face" in glsl or "m_usure_poids" in glsl or "m_usure_mur_pres" in glsl
           else "sans usure", signature(glsl))
    if cle in vus:
        continue
    base = os.path.join(TRAV, os.path.basename(chemin).replace(".shader_test", ""))
    open(base + ".frag", "w").write(glsl)
    r = subprocess.run(["glslangValidator", "-G", "--auto-map-bindings", "--auto-map-locations", "-S", "frag",
                        "-o", base + ".spv", base + ".frag"], capture_output=True, text=True)
    if r.returncode != 0:
        print("✗", chemin, r.stdout[-400:])
        continue
    subprocess.run(["spirv-opt", "-O", base + ".spv", "-o", base + ".o.spv"], check=True)
    subprocess.run(["spirv-dis", base + ".o.spv", "-o", base + ".o.dis"], check=True)
    subprocess.run(["spirv-dis", base + ".spv", "-o", base + ".dis"], check=True)
    vus[cle] = (chemin, compter(open(base + ".o.dis").read()), par_fonction(open(base + ".dis").read()))

# La spécialisation que le plus de formes partagent : la seule où les comparer.
compte_sig = collections.Counter(k[2] for k in vus)
SIG = compte_sig.most_common(1)[0][0] if compte_sig else None
vus = {(f, u): v for (f, u, sg), v in vus.items() if sg == SIG}
print("spécialisation comparée : %s" % " ".join(d.split()[1] for d in (SIG or ())))
print("forme du masque        | usure      | instr. optimisées | lectures (statiques) | branchements | boucles | math | fichier")
for (f, u), (chemin, c, _) in sorted(vus.items()):
    print("%-22s | %-10s | %17d | %20d | %12d | %7d | %4d | %s" % (f, u, c["instructions"], c["lectures"], c["branchements"],
                                                                 c["boucles"], c["math"], os.path.basename(chemin)))
for (f, u), (chemin, c, (corps, appels, taille, lectures)) in sorted(vus.items()):
    if f == "sans masque":
        continue
    print("\n— %s, %s : les fonctions du masque AVANT inlining (propre / recopiée à chaque appel / lectures recopiées)" % (f, u))
    for nom in sorted(corps, key=lambda n: -taille(n))[:14]:
        if not nom.startswith("m_") and nom != "main":
            continue
        print("  %-36s %5d  %7d  %4d   appelle %s" % (nom, corps[nom], taille(nom), lectures(nom),
              ", ".join("%s×%d" % (g, n) for g, n in appels[nom].items() if n > 1 or taille(g) > 400)[:150]))
