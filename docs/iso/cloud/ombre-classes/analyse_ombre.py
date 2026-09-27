#!/usr/bin/env python3
"""L'ombre des classes — analyse du journal de tools/planche_ombre.gd (session cloud ombre-classes, 2026-09-27).

    python3 docs/iso/cloud/ombre-classes/analyse_ombre.py "<dossier user://ombre>" docs/iso/cloud/ombre-classes

Écrit tableau.md et chiffres.json ; découpe les images (1:1 et loupe ×3) si elles sont là.

Le calcul géométrique : pour chaque point de l'anneau lu par le corps (rayon `rayon_lu_px`, 64 points, les mêmes que
le banc), le segment torche → point traverse-t-il l'occluder du corps (en coordonnées du monde, relevé par le banc) ?
Une Light2D ombre tout point plus loin de la lampe que le premier bord d'occluder sur son rayon, intérieur compris.
Prédiction du niveau : la moyenne, sur l'anneau, du profil SANS ombre propre (mode `sans`, même classe, même place)
multiplié par « éclairé » (0 ou 1). Aucun paramètre ajusté.
"""
import json, math, os, sys

NOMS = {"pistolet": "Parasite", "fusil": "Illusionniste", "pompe": "Terrassier", "arbalete": "Braconnier",
        "occulteur": "Occulteur", "fumiste": "Fumiste", "incendiaire": "Incendiaire", "sentinelle": "Sentinelle",
        "allumeur": "Allumeur", "spectre": "Spectre"}
ORDRE = list(NOMS)


def coupe(a, b, c, d):
    """Les segments [a,b] et [c,d] se coupent-ils (au sens strict, à 1e-9 près) ?"""
    def o(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
    d1, d2, d3, d4 = o(c, d, a), o(c, d, b), o(a, b, c), o(a, b, d)
    return (d1 * d2 < 0) and (d3 * d4 < 0)


def dedans(p, poly):
    x, y = p
    n = len(poly)
    ins = False
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            ins = not ins
    return ins


def eclaire(t, p, poly):
    if dedans(p, poly):
        return False
    n = len(poly)
    return not any(coupe(t, p, poly[i], poly[(i + 1) % n]) for i in range(n))


def anneau(centre, r):
    return [(centre[0] + math.cos(2 * math.pi * a / 64) * r, centre[1] + math.sin(2 * math.pi * a / 64) * r)
            for a in range(64)]


def vue_de_dessus(racine, prise):
    """La vue de dessus, en GÉOMÉTRIE (pas un rendu) : la part des pixels opaques du sprite adverse (sa silhouette,
    alpha > 0,35, le seuil de `Charte.ombre_de_silhouette`) que la torche atteint sans traverser l'occluder DU corps,
    posé tel que le banc l'a relevé. Le sprite est centré sur le corps et tourne avec lui (`player.gd`, quad centré,
    1 texel par unité de monde)."""
    from PIL import Image
    im = Image.open(os.path.join(racine, "assets/sprites/%s_silhouette.png" % prise["classe"])).convert("RGBA")
    l, h = im.size
    a = im.load()
    rot = prise["j2_rotation"]
    c, s_ = math.cos(rot), math.sin(rot)
    cx, cy = prise["corps"]
    poly = prise["occluder"]
    n = eclaires = 0
    for y in range(h):
        for x in range(l):
            if a[x, y][3] / 255.0 <= 0.35:
                continue
            lx, ly = x + 0.5 - l / 2.0, y + 0.5 - h / 2.0
            q = (cx + c * lx - s_ * ly, cy + s_ * lx + c * ly)
            n += 1
            if eclaire(prise["torche"], q, poly):
                eclaires += 1
    return n, eclaires


def main():
    src, dst = sys.argv[1], sys.argv[2]
    j = json.load(open(os.path.join(src, "journal.json")))
    r_lu = j.get("rayon_lu_px", 15.0)
    prises = j["prises"]
    par = {}
    for p in prises:
        cle = (p["classe"], p["scene"], p["mode"], p["controle"])
        par[cle] = p
    classes = [c for c in ORDRE if any(k[0] == c for k in par)]
    modes = [m for m in ["etoile", "rond12", "rond18", "sans", "couche"] if any(k[2] == m for k in par)]
    scenes = [s for s in ["mi", "b15", "b10"] if any(k[1] == s for k in par)]
    sortie = {"rayon_lu_px": r_lu, "commit": j.get("commit"), "lacet": j.get("lacet"),
              "option_lacet": j.get("option_lacet"), "classes": {}, "ecarts": {}, "geometrie": {}}
    lignes = ["# L'ombre des classes — le capteur de J2, dix classes, cinq ombres", "",
              "Même processus, mêmes places (trouvées avec le Parasite et l'ombre d'aujourd'hui), même torche (Parasite).",
              "Niveau = moyenne de l'anneau lu par le corps (rayon %.0f px), luminance Rec. 709." % r_lu, ""]
    for s in scenes:
        lignes += ["## Place `%s`" % s, "",
                   "| Classe | " + " | ".join(modes) + " | géométrie : part éclairée (étoile / rond 12 / rond 18) "
                   "| prédit (étoile) | contrôle étoile |",
                   "|---|" + "---|" * len(modes) + "---|---|---|"]
        for c in classes:
            vals = []
            for m in modes:
                p = par.get((c, s, m, False))
                vals.append("%.4f" % p["niveau"] if p else "—")
            sans = par.get((c, s, "sans", False))
            geo, pred = [], None
            for m in ["etoile", "rond12", "rond18"]:
                p = par.get((c, s, m, False))
                if not p:
                    geo.append("—")
                    continue
                pts = anneau(p["corps"], r_lu)
                lit = [eclaire(p["torche"], q, p["occluder"]) for q in pts]
                frac = sum(lit) / 64.0
                geo.append("%.3f" % frac)
                sortie["geometrie"].setdefault(c, {}).setdefault(s, {})[m] = {"part": frac}
                if sans:
                    pr = sum(v * l for v, l in zip(sans["profil"], lit)) / 64.0
                    sortie["geometrie"][c][s][m]["predit"] = pr
                    sortie["geometrie"][c][s][m]["mesure"] = p["niveau"]
                    if m == "etoile":
                        pred = pr
            ctl = par.get((c, s, "etoile", True))
            lignes.append("| %s | %s | %s | %s | %s |" % (NOMS[c], " | ".join(vals), " / ".join(geo),
                          "%.4f" % pred if pred is not None else "—", "%.4f" % ctl["niveau"] if ctl else "—"))
            for m in modes:
                p = par.get((c, s, m, False))
                if p:
                    sortie["classes"].setdefault(c, {}).setdefault(s, {})[m] = {
                        "niveau": p["niveau"], "max": p["niveau_max"], "disque_eclaire": p["disque_eclaire"],
                        "disque_moyen": p["disque_moyen"]}
        lignes.append("")
        lignes.append("Écart entre classes à `%s` (max − min, et rapport min/max) :" % s)
        lignes.append("")
        for m in modes:
            v = [par[(c, s, m, False)]["niveau"] for c in classes if (c, s, m, False) in par]
            if not v:
                continue
            e = max(v) - min(v)
            rel = min(v) / max(v) if max(v) > 0 else float("nan")
            sortie["ecarts"].setdefault(s, {})[m] = {"max": max(v), "min": min(v), "ecart": e, "rapport": rel}
            lignes.append("- `%s` : de %.4f à %.4f, écart %.4f (%.1f %% du plus haut)" % (
                m, min(v), max(v), e, 100 * e / max(v) if max(v) > 0 else float("nan")))
        lignes.append("")
    racine = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.."))
    lignes += ["## La vue de dessus — en géométrie (pas un rendu)", "",
               "Part des pixels du sprite adverse (silhouette) que la torche atteint sans traverser l'occluder du corps,",
               "à la même place et sous la même torche. Étoile d'aujourd'hui, puis rond de 12.", "",
               "| Classe | " + " | ".join("%s étoile | %s rond 12" % (s, s) for s in scenes) + " |",
               "|---|" + "---|---|" * len(scenes)]
    for c in classes:
        cell = []
        for s in scenes:
            for m in ["etoile", "rond12"]:
                p = par.get((c, s, m, False))
                if not p:
                    cell.append("—")
                    continue
                n, e = vue_de_dessus(racine, p)
                sortie["geometrie"].setdefault(c, {}).setdefault(s, {}).setdefault(m, {})["dessus"] = [n, e]
                cell.append("%.3f (%d/%d)" % (e / n, e, n))
        lignes.append("| %s | %s |" % (NOMS[c], " | ".join(cell)))
    lignes.append("")
    open(os.path.join(dst, "tableau.md"), "w").write("\n".join(lignes) + "\n")
    res = images(src, dst, par, classes)
    sortie["images"] = res
    if res:
        planche(dst, classes, res, sortie)
    json.dump(sortie, open(os.path.join(dst, "chiffres.json"), "w"), indent=1, ensure_ascii=False)
    print("\n".join(lignes))


def images(src, dst, par, classes):
    """Découpes 1:1 (240×240 autour de J2 : le corps et son ombre au sol) et loupe ×3 (100×100), JPEG 85 ; le noir
    absolu : les pixels allumés dans un mode et NOIRS dans l'étoile d'aujourd'hui, avec leur plus grande distance au
    corps à l'écran (une ombre qui s'ouvre les allume près du corps ; un pixel loin serait une fuite)."""
    import numpy as np
    from PIL import Image
    out = os.path.join(dst, "img")
    os.makedirs(out, exist_ok=True)
    res = {}
    for c in classes:
        for s in ["mi", "b10"]:
            ref = par.get((c, s, "etoile", False))
            if not ref or "fichier" not in ref or not os.path.exists(os.path.join(src, ref["fichier"])):
                continue
            a_ref = np.asarray(Image.open(os.path.join(src, ref["fichier"])).convert("RGB")).astype(int)
            for m in ["etoile", "rond12", "sans", "couche"]:
                p = par.get((c, s, m, False))
                if not p or "fichier" not in p:
                    continue
                im = Image.open(os.path.join(src, p["fichier"])).convert("RGB")
                a = np.asarray(im).astype(int)
                ex, ey = p["ecran"]
                x0, y0 = int(ex - 120), int(ey - 120)
                im.crop((x0, y0, x0 + 240, y0 + 240)).save(os.path.join(out, "%s_%s_%s.jpg" % (c, s, m)), quality=85)
                im.crop((int(ex - 50), int(ey - 50), int(ex + 50), int(ey + 50))).resize((300, 300), Image.NEAREST) \
                    .save(os.path.join(out, "%s_%s_%s_x3.jpg" % (c, s, m)), quality=85)
                neufs = (a.max(axis=2) > 0) & (a_ref.max(axis=2) == 0)
                ys, xs = np.nonzero(neufs)
                dmax = float(np.max(np.hypot(xs - ex, ys - ey))) if len(xs) else 0.0
                diff = int(np.count_nonzero(np.abs(a - a_ref).max(axis=2) > 0))
                res.setdefault(c, {}).setdefault(s, {})[m] = {"allumes_hors_etoile": int(len(xs)),
                                                             "distance_max_px": dmax, "pixels_differents": diff}
    return res


def planche(dst, classes, res, sortie):
    t = ["<!doctype html><html lang=fr><head><meta charset=utf-8><meta name=viewport content='width=device-width'>",
         "<title>L'ombre des classes</title><style>body{background:#111;color:#ddd;font:14px system-ui;margin:16px}",
         "img{image-rendering:pixelated;display:block}td{vertical-align:top;padding:4px}figure{margin:0}",
         "figcaption{font-size:12px;color:#aaa}h2{margin-top:32px}</style></head><body>",
         "<h1>L'ombre des classes — le capteur de J2 sous la même torche</h1>",
         "<p>Vue de J1 (iso, lacet %s %s), J1 Parasite torche allumée, J2 de chaque classe, de profil. "
         "<b>etoile</b> = aujourd'hui (voie a) ; <b>rond12</b> = occluder rond du torse (voie c) ; "
         "<b>sans</b> = aucune ombre propre (le capteur de la voie b, mais sans ombre au sol) ; "
         "<b>couche</b> = l'étoile gardée, invisible au capteur si le moteur le permet (voie b). "
         "Découpe 240×240 à 1:1 (le corps et son ombre au sol), puis loupe ×3.</p>" % (
             sortie.get("lacet"), sortie.get("option_lacet"))]
    for c in classes:
        t.append("<h2>%s</h2>" % NOMS[c])
        for s in ["b10", "mi"]:
            t.append("<table><tr>")
            for m in ["etoile", "rond12", "sans", "couche"]:
                f = "img/%s_%s_%s.jpg" % (c, s, m)
                if not os.path.exists(os.path.join(dst, f)):
                    continue
                niv = sortie["classes"].get(c, {}).get(s, {}).get(m, {}).get("niveau")
                r = res.get(c, {}).get(s, {}).get(m, {})
                t.append("<td><figure><img src='%s' width=240><img src='%s' width=300><figcaption>%s · %s · capteur "
                         "%.4f<br>allumés hors étoile : %s (à %s px au plus du corps)</figcaption></figure></td>" % (
                             f, f.replace(".jpg", "_x3.jpg"), s, m, niv if niv is not None else -1,
                             r.get("allumes_hors_etoile", "—"), "%.0f" % r["distance_max_px"] if r else "—"))
            t.append("</tr></table>")
    t.append("</body></html>")
    open(os.path.join(dst, "planche.html"), "w").write("\n".join(t))


if __name__ == "__main__":
    main()
