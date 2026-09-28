#!/usr/bin/env python3
"""L'ombre des classes, suite — analyse de tools/planche_orientation.gd (session cloud ombre-orientation, 2026-09-27).

    python3 docs/iso/cloud/ombre-orientation/analyse_orientation.py <dossier orient45> [<dossier orient0>] <sortie>

Écrit `orientation.md` et `orientation.json` dans <sortie>.

1. Le capteur mesuré (moyenne de l'anneau lu, et son maximum), dix classes × huit orientations × deux places.
2. La géométrie exacte (la vraie torche, l'occluder relevé ; `analyse_ombre.py` de la base) : la prédiction du niveau.
3. La voie (d), recalculée ici À L'IDENTIQUE de `ombre_compensee.gd` (rayons parallèles, 64 points, 64 directions,
   interpolation, bornes 0,25-4) : les facteurs (d1) et (d2), et l'écart qui reste entre classes une fois le capteur
   mesuré multiplié par eux. La compensation ne change pas le capteur (elle agit dans le shader du corps) : lire × facteur
   EST ce que le corps lit sous le drapeau, sans autre approximation.
"""
import json, math, os, sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../ombre-classes"))
from analyse_ombre import eclaire, anneau, NOMS, ORDRE  # noqa: E402

ORIENTS = ["face", "diag_face_g", "profil_g", "diag_dos_g", "dos", "diag_dos_d", "profil_d", "diag_face_d"]
NOMS_O = {"face": "de face", "diag_face_g": "diag. face, torche à gauche", "profil_g": "profil, torche à gauche",
          "diag_dos_g": "diag. dos, torche à gauche", "dos": "de dos", "diag_dos_d": "diag. dos, torche à droite",
          "profil_d": "profil, torche à droite", "diag_face_d": "diag. face, torche à droite"}
R_LU, POINTS, DIRECTIONS, FMIN, FMAX = 15.0, 64, 64, 0.25, 4.0


def local(p):
    """L'occluder relevé (monde) ramené dans le repère du corps (celui de `LightOccluder2D`, enfant du joueur)."""
    rot, (cx, cy) = p["j2_rotation"], p["corps"]
    c, s = math.cos(-rot), math.sin(-rot)
    return [((x - cx) * c - (y - cy) * s, (x - cx) * s + (y - cy) * c) for x, y in p["occluder"]]


def vers_torche_local(p):
    rot, (cx, cy), (tx, ty) = p["j2_rotation"], p["corps"], p["torche"]
    c, s = math.cos(-rot), math.sin(-rot)
    return ((tx - cx) * c - (ty - cy) * s, (tx - cx) * s + (ty - cy) * c)


def part_parallele(poly, w):
    """Miroir exact de `OmbreCompensee.part_eclairee` (rayons parallèles venus de la direction w)."""
    n = math.hypot(*w)
    w = (w[0] / n, w[1] / n)
    o = (w[1], -w[0])  # Vector2.orthogonal() de Godot : (y, -x)
    ts = [x * o[0] + y * o[1] for x, y in poly]
    ss = [x * w[0] + y * w[1] for x, y in poly]
    lit = 0
    for k in range(POINTS):
        a = 2 * math.pi * (k + 0.5) / POINTS  # décalés d'un demi-pas, comme `ombre_compensee.gd`
        px, py = math.cos(a) * R_LU, math.sin(a) * R_LU
        t, s = px * o[0] + py * o[1], px * w[0] + py * w[1]
        ombre = False
        for i in range(len(poly)):
            j = (i + 1) % len(poly)
            ta, tb = ts[i], ts[j]
            if (ta <= t) == (tb <= t):
                continue
            if ss[i] + (ss[j] - ss[i]) * (t - ta) / (tb - ta) > s:
                ombre = True
                break
        if not ombre:
            lit += 1
    return lit / POINTS


_tables = {}


def table(cle, poly):
    if cle not in _tables:
        # Décalée d'un demi-pas, comme `OmbreCompensee.direction_de_case`.
        _tables[cle] = [part_parallele(poly, (math.cos(2 * math.pi * (i + 0.5) / DIRECTIONS),
                                              math.sin(2 * math.pi * (i + 0.5) / DIRECTIONS)))
                        for i in range(DIRECTIONS)]
    return _tables[cle]


def part_table(cle, poly, w):
    t = table(cle, poly)
    x = (math.atan2(w[1], w[0]) / (2 * math.pi) * DIRECTIONS - 0.5) % DIRECTIONS
    i = int(math.floor(x)) % DIRECTIONS
    f = x - math.floor(x)
    return t[i] + (t[(i + 1) % DIRECTIONS] - t[i]) * f


def rapport(ref, forme):
    return 1.0 if forme <= 0 else min(FMAX, max(FMIN, ref / forme))


def ecart(v):
    v = [x for x in v if x is not None]
    return (max(v) - min(v)) / max(v) if v and max(v) > 0 else float("nan")


def charger(dossier):
    j = json.load(open(os.path.join(dossier, "journal.json")))
    par = {}
    for p in j["prises"]:
        if p.get("controle"):
            par.setdefault("ctl", {})[(p["classe"], p["scene"], p["orientation"])] = p
            continue
        par[(p["classe"], p["scene"], p["mode"], p["orientation"])] = p
    return j, par


def analyser(dossier):
    j, par = charger(dossier)
    classes = [c for c in ORDRE if (c, "b10", "etoile", "face") in par]
    scenes = [s for s in ["b10", "mi"] if ("pistolet", s, "etoile", "face") in par]
    polys = {c: local(par[(c, scenes[0], "etoile", "profil_g")]) for c in classes}
    ref = polys["pistolet"]
    moy = {c: sum(table(c, polys[c])) / DIRECTIONS for c in classes}
    f1 = {c: 1.0 if polys[c] == ref else rapport(moy["pistolet"], moy[c]) for c in classes}
    out = {"lacet": j.get("lacet"), "option_lacet": j.get("option_lacet"), "commit": j.get("commit"),
           "part_moyenne": moy, "facteur_d1": f1, "places": {}}
    # Le facteur de profil seul (l'autre référence possible pour d1).
    f1_profil = {}
    for c in classes:
        w = vers_torche_local(par[(c, scenes[0], "etoile", "profil_g")])
        f1_profil[c] = rapport(part_table("pistolet", ref, w), part_table(c, polys[c], w))
    out["facteur_d1_profil"] = f1_profil
    for s in scenes:
        sans = par.get(("pistolet", s, "sans", "profil_g"))
        sans_vals = [par[k]["niveau"] for k in par if k != "ctl" and k[1] == s and k[2] == "sans"]
        place = {"sans": {"min": min(sans_vals), "max": max(sans_vals), "n": len(sans_vals)}, "classes": {}}
        for c in classes:
            for o in ORIENTS:
                p = par.get((c, s, "etoile", o))
                if not p:
                    continue
                pts = anneau(p["corps"], R_LU)
                lit = [eclaire(p["torche"], q, p["occluder"]) for q in pts]
                pr = sum(v * l for v, l in zip(sans["profil"], lit)) / 64.0
                pr_max = max([v for v, l in zip(sans["profil"], lit) if l] or [0.0])
                w = vers_torche_local(p)
                part_exacte = sum(lit) / 64.0
                part_par = part_parallele(polys[c], w)
                f2 = 1.0 if polys[c] == ref else rapport(part_table("pistolet", ref, w), part_table(c, polys[c], w))
                ctl = par.get("ctl", {}).get((c, s, o))
                place["classes"].setdefault(c, {})[o] = {
                    "niveau": p["niveau"], "max": p["niveau_max"], "predit": pr, "predit_max": pr_max,
                    "part_exacte": part_exacte, "part_parallele": part_par, "f1": f1[c], "f2": f2,
                    "d1": p["niveau"] * f1[c], "d2": p["niveau"] * f2, "max_d1": p["niveau_max"] * f1[c],
                    "max_d2": p["niveau_max"] * f2, "controle": ctl["niveau"] if ctl else None}
        out["places"][s] = place
    return out


def tableau(res, titre):
    L = ["## %s (lacet %s %s)" % (titre, res["lacet"], res["option_lacet"]), ""]
    classes = [c for c in ORDRE if c in res["facteur_d1"]]
    L += ["Facteurs de la voie (d) : **d1** (constant, parts moyennées sur 64 directions) ; *d1 profil* (la même chose avec "
          "le seul profil de la base, pour comparaison).", "",
          "| Classe | part moyenne | d1 | d1 profil |", "|---|---|---|---|"]
    for c in classes:
        L.append("| %s | %.3f | %.3f | %.3f |" % (NOMS[c], res["part_moyenne"][c], res["facteur_d1"][c],
                                                res["facteur_d1_profil"][c]))
    L.append("")
    for s, place in res["places"].items():
        L += ["### Place `%s` — capteur mesuré (moyenne de l'anneau)" % s, "",
              "Sans ombre propre : %.4f à %.4f sur %d prises (classes et orientations mêlées)." % (
                  place["sans"]["min"], place["sans"]["max"], place["sans"]["n"]), "",
              "| Classe | " + " | ".join(ORIENTS) + " | écart entre orientations |", "|---|" + "---|" * (len(ORIENTS) + 1)]
        for c in classes:
            v = [place["classes"][c].get(o, {}).get("niveau") for o in ORIENTS]
            L.append("| %s | %s | %.0f %% |" % (NOMS[c], " | ".join("%.4f" % x if x is not None else "—" for x in v),
                                              100 * ecart(v)))
        for cle, nom in [("niveau", "aujourd'hui"), ("d1", "(d1)"), ("d2", "(d2)"), ("max", "maximum, aujourd'hui"),
                         ("max_d1", "maximum × d1"), ("max_d2", "maximum × d2")]:
            v = [ecart([place["classes"][c].get(o, {}).get(cle) for c in classes]) for o in ORIENTS]
            L.append("| **écart entre classes — %s** | %s | |" % (nom, " | ".join("%.0f %%" % (100 * x) for x in v)))
        L.append("")
        L += ["Géométrie : erreur de la prédiction (vraie torche) et part éclairée exacte / rayons parallèles.", ""]
        err = [abs(d["niveau"] - d["predit"]) for c in classes for d in place["classes"][c].values()]
        errm = [abs(d["max"] - d["predit_max"]) for c in classes for d in place["classes"][c].values()]
        dpar = [abs(d["part_exacte"] - d["part_parallele"]) for c in classes for d in place["classes"][c].values()]
        exact = sum(1 for e in err if e < 5e-4)
        L.append("- niveau : erreur moyenne %.4f, au pire %.4f ; %d prises sur %d prédites à 0,0005 près" % (
            sum(err) / len(err), max(err), exact, len(err)))
        L.append("- maximum : erreur moyenne %.4f, au pire %.4f" % (sum(errm) / len(errm), max(errm)))
        L.append("- part éclairée, vraie torche contre rayons parallèles : écart moyen %.3f, au pire %.3f (en points "
                 "d'anneau : %.1f / %.1f sur 64)" % (sum(dpar) / len(dpar), max(dpar), 64 * sum(dpar) / len(dpar),
                                                    64 * max(dpar)))
        ctl = [abs(d["niveau"] - d["controle"]) for c in classes for d in place["classes"][c].values()
               if d["controle"] is not None]
        if ctl:
            L.append("- contrôle (de face repris après les sept autres) : écart au pire %.4f sur %d classes" % (
                max(ctl), len(ctl)))
        L.append("")
    return L


def main():
    args = sys.argv[1:]
    dst = args[-1]
    res = {}
    lignes = ["# L'orientation — le capteur de J2, dix classes × huit orientations", "",
              "Même processus, mêmes places que la base (Parasite, profil, ombre d'aujourd'hui), même torche (Parasite).",
              "Orientation = où regarde J2 par rapport à la torche de J1 : `face` il la regarde, `dos` il lui tourne le dos,",
              "`_g` / `_d` la torche à sa gauche / droite. Écart = (plus haut − plus bas) / plus haut.", ""]
    for d, nom in zip(args[:-1], ["45° B", "0°"]):
        r = analyser(d)
        res[nom] = r
        lignes += tableau(r, nom)
    open(os.path.join(dst, "orientation.md"), "w").write("\n".join(lignes) + "\n")
    json.dump(res, open(os.path.join(dst, "orientation.json"), "w"), indent=1, ensure_ascii=False)
    print("\n".join(lignes))


if __name__ == "__main__":
    main()
