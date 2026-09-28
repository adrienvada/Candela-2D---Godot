#!/usr/bin/env python3
"""L'ombre des classes, suite — analyse de tools/planche_apparition.gd (session cloud ombre-orientation, 2026-09-27).

    python3 docs/iso/cloud/ombre-orientation/analyse_apparition.py <sortie> <orient45> <appar45> [<appar0>]

Écrit `apparition.md`, `apparition.json`, les découpes `img/` (JPEG 85) et `planche.html` dans <sortie>.

1. Les recherches à l'image : où le dernier pixel du corps s'éteint, cas par cas, mode par mode (0 aujourd'hui, 1, 2).
2. La prédiction de TOUTES les classes × orientations × modes, à partir du balayage (le capteur sans ombre propre le
   long de l'axe) et de la géométrie de chaque occluder (relevé par `planche_orientation`) : le premier pixel s'allume
   quand facteur × maximum de l'anneau éclairé dépasse le seuil T. T n'est pas supposé : il est lu à l'image, sur le
   Parasite (facteur 1), au point où son dernier pixel s'éteint. Les autres recherches à l'image jugent la prédiction.
3. La planche : les dix classes, aujourd'hui / (d1) / (d2), à 1:1 et à la loupe ×3, et ce que la compensation change
   au pixel (dans la silhouette du corps : pixels plus clairs, de combien ; hors d'elle : rien, sinon on le dit).
"""
import json, math, os, sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../ombre-classes"))
from analyse_ombre import eclaire, anneau, NOMS, ORDRE  # noqa: E402
from analyse_orientation import (local, part_table, table, rapport, ORIENTS, NOMS_O, R_LU)  # noqa: E402

THETA = {"face": 0, "diag_face_g": 45, "profil_g": 90, "diag_dos_g": 135, "dos": 180, "diag_dos_d": 225,
         "profil_d": 270, "diag_face_d": 315}


def charger(d):
    return json.load(open(os.path.join(d, "journal.json")))


def recherches(j):
    out = {}
    for p in j["prises"]:
        if p.get("partie") == "apparition":
            out[(p["classe"], p["orientation"], p["mode_d"])] = p
    return out


def polygones(orient_journal):
    """Les occluders de chaque classe dans le repère du corps (relevés par planche_orientation)."""
    polys = {}
    for p in orient_journal["prises"]:
        if p.get("mode") == "etoile" and p.get("orientation") == "profil_g" and p.get("scene") == "b10" \
                and not p.get("controle"):
            polys[p["classe"]] = local(p)
    return polys


def predire(j, polys, T):
    """Pour chaque classe × orientation × mode : la dernière distance du balayage où facteur × max(éclairé) ≥ T."""
    axe = j["axe"]
    bal = [p for p in j["prises"] if p.get("partie") == "balayage"]
    ref = polys["pistolet"]
    moy = {c: sum(table(c, polys[c])) / 64 for c in polys}
    res = {}
    for c in polys:
        for o in ORIENTS:
            th = math.radians(THETA[o])
            # J2 vise (−axe) tourné de θ ; dans le repère du corps, la torche vient de (visée tournée de −θ).
            w = (math.cos(-th), math.sin(-th))
            f = {0: 1.0,
                 1: 1.0 if polys[c] == ref else rapport(moy["pistolet"], moy[c]),
                 2: 1.0 if polys[c] == ref else rapport(part_table("pistolet", ref, w), part_table(c, polys[c], w))}
            vise = (-axe[0], -axe[1])
            ang = math.atan2(vise[1], vise[0]) + th
            rot = ang
            cs, sn = math.cos(rot), math.sin(rot)
            derniere = {0: None, 1: None, 2: None}
            for b in bal:
                cx, cy = b["corps"]
                monde = [(cx + x * cs - y * sn, cy + x * sn + y * cs) for x, y in polys[c]]
                lit = [eclaire(b["torche"], q, monde) for q in anneau(b["corps"], R_LU)]
                mx = max([v for v, l in zip(b["profil"], lit) if l] or [0.0])
                for m in (0, 1, 2):
                    if f[m] * mx >= T:
                        derniere[m] = b["distance"]
            res[(c, o)] = {"facteurs": f, "derniere": derniere}
    return res


def seuil(j, rech):
    """T : le maximum de l'anneau (sans ombre propre, balayage) à la distance où le Parasite (profil) s'éteint à l'image."""
    p = rech.get(("pistolet", "profil_g", 0))
    bal = sorted([b for b in j["prises"] if b.get("partie") == "balayage"], key=lambda b: b["distance"])
    if not p or not bal:
        return None, None
    d_on, d_off = p["distance"], p["distance_eteint"]
    # Le max « sans » est celui du Parasite de profil là où son point le plus proche de la torche est éclairé (vérifié
    # par la base : max étoile = max sans de profil). Interpolé linéairement entre les points du balayage.
    def mx(d):
        for a, b in zip(bal, bal[1:]):
            if a["distance"] <= d <= b["distance"]:
                t = (d - a["distance"]) / (b["distance"] - a["distance"])
                return a["niveau_max"] + (b["niveau_max"] - a["niveau_max"]) * t
        return None
    return mx(d_on), mx(d_off)


def main():
    dst = sys.argv[1]
    orient = charger(sys.argv[2])
    dossiers = sys.argv[3:]
    lignes = ["# Où un corps apparaît — aujourd'hui, (d1), (d2)", ""]
    sortie = {}
    for d, nom in zip(dossiers, ["45° B", "0°"]):
        j = charger(d)
        rech = recherches(j)
        lignes += ["## %s" % nom, "", "### À l'image : le dernier pixel allumé (distance à J1, en px)", "",
                   "| Classe | orientation | aujourd'hui | (d1) | (d2) |", "|---|---|---|---|---|"]
        cas = sorted({(k[0], k[1]) for k in rech}, key=lambda k: (ORDRE.index(k[0]), ORIENTS.index(k[1])))
        for c, o in cas:
            cel = []
            for m in (0, 1, 2):
                p = rech.get((c, o, m))
                cel.append("—" if not p else ("aucun dès b10" if p["distance"] < 0 else "%.0f" % p["distance"]))
            lignes.append("| %s | %s | %s |" % (NOMS[c], o, " | ".join(cel)))
        lignes.append("")
        t_on, t_off = seuil(j, rech)
        sortie[nom] = {"recherches": {"%s|%s|%d" % k: v for k, v in rech.items()}, "seuil": [t_on, t_off]}
        if orient is not None and t_on is not None:
            polys = polygones(orient)
            T = (t_on + t_off) / 2
            pred = predire(j, polys, T)
            sortie[nom]["prediction"] = {"%s|%s" % k: v for k, v in pred.items()}
            lignes += ["### Prédiction, toutes classes × orientations (seuil T = %.4f, lu sur le Parasite)" % T, "",
                       "Dernière distance du balayage (pas de 2 px) où facteur × maximum de l'anneau éclairé ≥ T ;",
                       "« — » : aucun pixel dès le début du balayage (b15).", ""]
            for m, nm in [(0, "aujourd'hui"), (1, "(d1)"), (2, "(d2)")]:
                lignes += ["**%s**" % nm, "", "| Classe | " + " | ".join(ORIENTS) + " |",
                           "|---|" + "---|" * len(ORIENTS)]
                for c in [c for c in ORDRE if c in polys]:
                    v = [pred[(c, o)]["derniere"][m] for o in ORIENTS]
                    lignes.append("| %s | %s |" % (NOMS[c], " | ".join("—" if x is None else "%.0f" % x for x in v)))
                et = []
                for o in ORIENTS:
                    v = [pred[(c, o)]["derniere"][m] for c in polys]
                    v = [x for x in v if x is not None]
                    et.append("%.0f" % (max(v) - min(v)) if len(v) == len(polys) else "n/a")
                lignes += ["| **écart entre classes (px)** | %s |" % " | ".join(et), ""]
            # Le jugement de la prédiction par les recherches à l'image.
            lignes += ["Prédiction contre image (dernier pixel allumé) :", ""]
            for (c, o, m), p in sorted(rech.items(), key=lambda kv: (ORDRE.index(kv[0][0]), kv[0][1], kv[0][2])):
                pr = pred.get((c, o), {}).get("derniere", {}).get(m)
                lignes.append("- %s %s mode %d : image %s, prédit %s" % (
                    NOMS[c], o, m, "%.0f" % p["distance"] if p["distance"] >= 0 else "aucun",
                    "%.0f" % pr if pr is not None else "aucun"))
            lignes.append("")
        imgs = planche_images(d, j, dst, nom)
        sortie[nom]["planche"] = imgs
    open(os.path.join(dst, "apparition.md"), "w").write("\n".join(lignes) + "\n")
    json.dump(sortie, open(os.path.join(dst, "apparition.json"), "w"), indent=1, ensure_ascii=False)
    html(dst, sortie)
    print("\n".join(lignes))


def planche_images(src, j, dst, nom):
    """Découpes et comptes au pixel pour la planche (45° B seulement : c'est la vue du jeu)."""
    import numpy as np
    from PIL import Image
    out = os.path.join(dst, "img")
    os.makedirs(out, exist_ok=True)
    suf = "45" if nom.startswith("45") else "0"
    res = {}
    lignes = [p for p in j["prises"] if p.get("partie") == "planche"]
    for p in lignes:
        f = os.path.join(src, p["fichier"])
        if not os.path.exists(f):
            continue
        a = np.asarray(Image.open(f).convert("RGB")).astype(int)
        V = np.asarray(Image.open(os.path.join(src, p["vide"])).convert("RGB")).astype(int)
        S = np.asarray(Image.open(os.path.join(src, p["sil"])).convert("RGB")).astype(int)
        Z = np.asarray(Image.open(os.path.join(src, p["zero"])).convert("RGB")).astype(int)
        ref_nom = p["fichier"].replace("_d%d.png" % p["mode_d"], "_d0.png")
        R0 = np.asarray(Image.open(os.path.join(src, ref_nom)).convert("RGB")).astype(int)
        masque = np.abs(S - Z).max(axis=2) > 2
        diff = (a - R0).max(axis=2)
        dedans = masque & (np.abs(a - R0).max(axis=2) > 0)
        dehors = (~masque) & (np.abs(a - R0).max(axis=2) > 0)
        # « Plus clair que le sol qui le porte » : pixels du corps plus clairs que le vide au même endroit.
        plus_clair = masque & (a.max(axis=2) > V.max(axis=2))
        plus_clair0 = masque & (R0.max(axis=2) > V.max(axis=2))
        ex, ey = p["ecran"]
        im = Image.open(f).convert("RGB")
        base = "%s_%s_%s_%s_d%d" % (p["classe"], p["scene"], p["orientation"], suf, p["mode_d"])
        x0, y0 = int(ex - 120), int(ey - 120)
        im.crop((x0, y0, x0 + 240, y0 + 240)).save(os.path.join(out, base + ".jpg"), quality=85)
        im.crop((int(ex - 50), int(ey - 50), int(ex + 50), int(ey + 50))).resize((300, 300), Image.NEAREST) \
            .save(os.path.join(out, base + "_x3.jpg"), quality=85)
        res[base] = {"classe": p["classe"], "scene": p["scene"], "orientation": p["orientation"], "mode": p["mode_d"],
                     "niveau": p["niveau"], "compensation": p["compensation"], "silhouette": int(masque.sum()),
                     "visibles": p["visibles"], "haut": p["haut"], "pixels_changes_corps": int(dedans.sum()),
                     "pixels_changes_hors_corps": int(dehors.sum()),
                     "hausse_max": int(diff[masque].max()) if masque.any() else 0,
                     "hausse_moyenne_changes": float(diff[dedans].mean()) if dedans.any() else 0.0,
                     "plus_clair_que_le_sol": int(plus_clair.sum()), "plus_clair_que_le_sol_d0": int(plus_clair0.sum()),
                     "fichier": "img/" + base + ".jpg"}
    return res


def html(dst, sortie):
    t = ["<!doctype html><html lang=fr><head><meta charset=utf-8><meta name=viewport content='width=device-width'>",
         "<title>Ombre et orientation</title><style>:root{--bg:#111;--fg:#ddd;--mute:#999}",
         "body{background:var(--bg);color:var(--fg);font:14px system-ui;margin:16px;max-width:1400px}",
         "img{image-rendering:pixelated;display:block;max-width:100%}td{vertical-align:top;padding:4px}figure{margin:0}",
         "figcaption{font-size:12px;color:var(--mute)}h2{margin-top:32px}.defile{overflow-x:auto}</style></head><body>",
         "<h1>L'ombre des classes — l'orientation, et la voie (d)</h1>",
         "<p>Vue de J1 (iso 45° B), J1 Parasite torche allumée, J2 de chaque classe, <b>de profil, torche à sa gauche</b> "
         "(l'orientation de la session précédente). Trois colonnes : <b>aujourd'hui</b> ; <b>(d1)</b> un facteur constant "
         "par classe ; <b>(d2)</b> un facteur recalculé selon la direction de la torche. Corps rendu tel que le jeu le "
         "calcule (opacité 1 : l'effacement de la vue de dessus est mis de côté). Découpe 240×240 à 1:1, puis loupe ×3.</p>",
         "<h2>Pourquoi l'orientation compte : les dix ombres propres</h2>",
         "<p>Chaque vignette : l'étoile de l'occluder du corps (J2 regarde vers le haut), l'anneau de 15 px où le corps "
         "lit sa lumière, en jaune les points que la torche atteint (trait pointillé : d'où elle vient). Le pourcentage "
         "est la part éclairée.</p><div class=defile><img src='etoiles.svg' alt='les dix étoiles' width=880></div>"]
    pl = sortie.get("45° B", {}).get("planche", {})
    classes = [c for c in ORDRE if any(v["classe"] == c for v in pl.values())]
    for c in classes:
        t.append("<h2>%s</h2>" % NOMS[c])
        for s in ["b10", "mi"]:
            t.append("<div class=defile><table><tr>")
            for m, nm in [(0, "aujourd'hui"), (1, "(d1)"), (2, "(d2)")]:
                k = [kk for kk, v in pl.items() if v["classe"] == c and v["scene"] == s and v["mode"] == m]
                if not k:
                    continue
                v = pl[k[0]]
                t.append("<td><figure><img src='%s' width=240 height=240 alt=''><img src='%s' width=300 height=300 "
                         "alt=''><figcaption>%s · %s · facteur ×%.3f · capteur lu %.4f<br>pixels du corps changés : %d "
                         "(au plus +%d/255) · hors du corps : %d · plus clairs que le sol : %d</figcaption></figure>"
                         "</td>" % (v["fichier"], v["fichier"].replace(".jpg", "_x3.jpg"), s, nm, v["compensation"],
                                    v["niveau"] * v["compensation"], v["pixels_changes_corps"], v["hausse_max"],
                                    v["pixels_changes_hors_corps"], v["plus_clair_que_le_sol"]))
            t.append("</tr></table></div>")
    t.append("</body></html>")
    open(os.path.join(dst, "planche.html"), "w").write("\n".join(t))


if __name__ == "__main__":
    main()
