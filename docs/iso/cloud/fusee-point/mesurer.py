#!/usr/bin/env python3
"""Le point de braise de la fusée, avant et après (session cloud « fusée-point », 2026-09-27) — mesures, JPEG, planche.

Lit, pour chaque passage (avant/après × défaut/rouge long), le journal du photographe (lignes `FUSEE_AGES {json}`,
plan `loupe-fusee-ages`) et le dossier qu'il a écrit (`manifeste.json` + PNG), puis écrit dans le dossier de sortie :
- `<passage>/aX_Y-loupe.jpg`  640×360 autour de la fusée, vue de J1, à l'échelle 1 ;
- `<passage>/aX_Y-point.jpg`  48×48 autour du point, agrandi ×6 au plus proche ;
- `mesures.json` et `planche.html` (autonome, images en chemins relatifs).

Le point est mesuré LÀ OÙ IL EST, et non comme « le pixel le plus lumineux » (sur un sol orange, ce peut être le sol) :
chaque âge a deux prises au même instant, avec et sans le point (`IsoVolumes.coeur_fusee` à 0). Les pixels qui diffèrent
d'au moins 8/255 sont le point ; sa couleur est la moyenne, sur la prise AVEC, des 9 pixels qui diffèrent le plus (le
cœur du disque). La « contribution » est la même moyenne sur la différence (avec − sans) : ce que le halo ajoute seul.

Le noir absolu : torches éteintes, fumée coupée / rétablie / recoupée (A, B, A'). Un pixel noir dans A et A' et allumé
dans B est un pixel que la fumée allume hors de la lumière. Et, d'un passage à l'autre (avant / après, même variante,
même âge, horloge fixe) : les pixels de la prise B qui diffèrent HORS du disque du point (rayon 16 px) — la correction
ne doit rien changer ailleurs.

Usage :
  python3 mesurer.py --passage defaut-avant=JOURNAL,DOSSIER ... --sortie DOSSIER
"""
import argparse
import colorsys
import html
import json
import math
import os

import numpy as np
from PIL import Image

LOUPE = (640, 360)
ZOOM_POINT = 48
SEUIL_POINT = 8
RAYON_POINT = 16


def lire_journal(chemin):
    lignes = []
    with open(chemin, encoding="utf-8", errors="replace") as f:
        for l in f:
            if "FUSEE_AGES " in l:
                lignes.append(json.loads(l.split("FUSEE_AGES ", 1)[1]))
    return lignes


def fichiers(dossier):
    with open(os.path.join(dossier, "manifeste.json"), encoding="utf-8") as f:
        m = json.load(f)
    return {p["id"]: os.path.join(dossier, p["fichier"]) for p in m["photos"]}


def ts(rgb):
    h, s, v = colorsys.rgb_to_hsv(*(np.array(rgb, dtype=float) / 255.0))
    return round(h * 360.0, 1), round(s, 3), round(v, 3)


def rouge(t, s):
    return (t >= 350.0 or t <= 15.0) and s >= 0.6


def charger(chemin):
    return np.array(Image.open(chemin).convert("RGB")).astype(int)


def mesurer(e, ids):
    j, a, b, a2, sp = (charger(p) for p in ids)
    px, py = e["geometrie"]["point"]
    yy, xx = np.mgrid[0:j.shape[0], 0:j.shape[1]]
    pres = (xx - px) ** 2 + (yy - py) ** 2 <= RAYON_POINT ** 2
    diff = np.abs(j - sp).max(axis=2)
    masque = (diff >= SEUIL_POINT) & pres
    n = int(masque.sum())
    point = contribution = None
    if n:
        ys, xs = np.nonzero(masque)
        ordre = np.argsort(-diff[ys, xs])[:9]
        point = j[ys[ordre], xs[ordre]].mean(axis=0).round().astype(int).tolist()
        contribution = (j - sp)[ys[ordre], xs[ordre]].mean(axis=0).round().astype(int).tolist()
    sol = sp[masque].mean(axis=0).round().astype(int).tolist() if n else None
    noir_a = (a.max(axis=2) == 0) & (a2.max(axis=2) == 0)
    fuite = noir_a & (b.max(axis=2) > 0)
    hors_point = int((diff >= SEUIL_POINT)[~pres].sum())
    m = {
        "point_pixels": n, "point": point, "contribution": contribution, "sol_sous_le_point": sol,
        "noir_reference": int(noir_a.sum()), "noir_fuites": int(fuite.sum()),
        "noir_fuite_max": int(b[fuite].max()) if fuite.any() else 0,
        "diff_hors_point_avec_sans": hors_point,
    }
    if point:
        m["point_teinte"], m["point_saturation"], m["point_valeur"] = ts(point)
        m["point_rouge"] = rouge(m["point_teinte"], m["point_saturation"])
    if contribution:
        c = [max(0, v) for v in contribution]
        m["contribution_teinte"], m["contribution_saturation"], _ = ts(c)
    if sol:
        m["sol_teinte"], m["sol_saturation"], _ = ts(sol)
    return m, b


def recadrer(src, centre, taille, facteur, sortie):
    im = Image.open(src).convert("RGB")
    w, h = taille
    x = min(max(int(round(centre[0])) - w // 2, 0), im.width - w)
    y = min(max(int(round(centre[1])) - h // 2, 0), im.height - h)
    im = im.crop((x, y, x + w, y + h))
    if facteur != 1:
        im = im.resize((w * facteur, h * facteur), Image.NEAREST)
    im.save(sortie, "JPEG", quality=85)


def pastille(rgb):
    if not rgb:
        return ""
    return '<span class="pa" style="background:rgb(%d,%d,%d)"></span>' % tuple(max(0, min(255, v)) for v in rgb)


def legende(m):
    if not m.get("point"):
        return '<div class="lg">point absent</div>'
    ok = "rouge" if m.get("point_rouge") else ("presque blanc" if m["point_saturation"] < 0.15 else "NI ROUGE NI BLANC")
    return ('<div class="lg">%s point (%d, %d, %d) · %.0f° · sat. %.2f · <b>%s</b><br>'
            'contribution du halo seul %s (%d, %d, %d) · %.0f°<br>noir : %d fuite(s) de fumée</div>') % (
        pastille(m["point"]), *m["point"], m["point_teinte"], m["point_saturation"], ok,
        pastille([max(0, v) for v in m["contribution"]]), *m["contribution"], m.get("contribution_teinte", 0),
        m["noir_fuites"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--passage", action="append", required=True, help="nom=JOURNAL,DOSSIER")
    ap.add_argument("--sortie", required=True)
    args = ap.parse_args()
    tout = {}
    prises_b = {}
    for v in args.passage:
        nom, reste = v.split("=", 1)
        journal, dossier = reste.split(",", 1)
        fs = fichiers(dossier)
        os.makedirs(os.path.join(args.sortie, nom), exist_ok=True)
        tout[nom] = []
        for e in lire_journal(journal):
            ids = [fs[i] for i in e["ids"]]
            m, b = mesurer(e, ids)
            prises_b[(nom, e["nom"])] = (b, e["geometrie"]["point"])
            recadrer(ids[0], e["geometrie"]["centre"], LOUPE, 1, os.path.join(args.sortie, nom, e["nom"] + "-loupe.jpg"))
            recadrer(ids[0], e["geometrie"]["point"], (ZOOM_POINT, ZOOM_POINT), 6,
                     os.path.join(args.sortie, nom, e["nom"] + "-point.jpg"))
            tout[nom].append({k: e[k] for k in ("nom", "age_demande", "age_lu", "acte", "energie_relative",
                                                  "alpha_fumee", "duree_plein_feu", "coeur_fusee")} | {"mesures": m})
            print("%-14s %-6s %-9s lu %.4f  point %s  %s°  sat %s  fuites %d" % (
                nom, e["nom"], e["acte"], e["age_lu"], m.get("point"), m.get("point_teinte"),
                m.get("point_saturation"), m["noir_fuites"]))
    # Avant / après : ce qui change dans la prise B (torches éteintes, fumée) hors du disque du point.
    for variante in ("defaut", "long"):
        for e in tout.get(variante + "-apres", []):
            k_av, k_ap = (variante + "-avant", e["nom"]), (variante + "-apres", e["nom"])
            if k_av in prises_b:
                b0, _ = prises_b[k_av]
                b1, (px, py) = prises_b[k_ap]
                yy, xx = np.mgrid[0:b0.shape[0], 0:b0.shape[1]]
                hors = (xx - px) ** 2 + (yy - py) ** 2 > RAYON_POINT ** 2
                d = np.abs(b1 - b0).max(axis=2)
                e["mesures"]["avant_apres_hors_point"] = int(((d > 0) & hors).sum())
                e["mesures"]["avant_apres_hors_point_max"] = int(d[hors].max())
                e["mesures"]["avant_apres_noir_allume"] = int(((b0.max(axis=2) == 0) & (b1.max(axis=2) > 0) & hors).sum())
                print("%s %s : prise B, hors du point, %d pixel(s) différents (max %d), %d noir(s) allumé(s)" % (
                    variante, e["nom"], e["mesures"]["avant_apres_hors_point"],
                    e["mesures"]["avant_apres_hors_point_max"], e["mesures"]["avant_apres_noir_allume"]))
    with open(os.path.join(args.sortie, "mesures.json"), "w", encoding="utf-8") as f:
        json.dump(tout, f, ensure_ascii=False, indent=1)
    ecrire_planche(tout, args.sortie)


def ecrire_planche(tout, sortie):
    lignes = []
    noms = [e["nom"] for e in tout.get("defaut-avant", tout[next(iter(tout))])]
    for n in noms:
        cellules = []
        for p in ("defaut-avant", "defaut-apres", "long-avant", "long-apres"):
            e = next((x for x in tout.get(p, []) if x["nom"] == n), None)
            if e is None:
                cellules.append("<td>—</td>")
                continue
            cellules.append(
                '<td><div class="ac">%s · énergie rel. %.2f · âge lu %.3f s</div>'
                '<a href="%s/%s-loupe.jpg"><img class="lo" src="%s/%s-loupe.jpg" alt="loupe"></a>'
                '<img class="pt" src="%s/%s-point.jpg" alt="point ×6">%s</td>' % (
                    html.escape(e["acte"]), e["energie_relative"], e["age_lu"], p, n, p, n, p, n, legende(e["mesures"])))
        lignes.append('<tr><th>%s s</th>%s</tr>' % (n[1:].replace("_", ","), "".join(cellules)))
    page = """<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Point de braise, avant et après</title>
<style>
:root{--f:#111;--t:#ddd;--l:#888}
body{background:var(--f);color:var(--t);font:13px/1.4 system-ui,sans-serif;margin:16px}
table{border-collapse:collapse}td,th{border:1px solid #333;padding:6px;vertical-align:top}
th{position:sticky;left:0;background:#1a1a1a}.lo{width:320px;display:block;image-rendering:pixelated}
.pt{width:144px;display:block;margin-top:4px;image-rendering:pixelated}.ac{color:var(--l);font-size:12px}
.lg{font-size:12px;max-width:320px}.pa{display:inline-block;width:12px;height:12px;border:1px solid #666;vertical-align:middle}
.tete{overflow-x:auto}
</style></head><body>
<h1>Le point de braise de la fusée — avant / après</h1>
<p>Vue de J1, lacet 45°, zoom ×1,5, 1920×1080, Cloître ; la fusée posée dans le noir, hors de la torche de J1. Âges pilotés
en temps de jeu (horloge fixe), un demi-pas au-delà des bornes. Dans chaque case : la loupe (640×360, échelle 1), le point
agrandi ×6, sa couleur mesurée (pixels qui diffèrent de la même prise SANS le point), la contribution du halo seul
(avec − sans), et les fuites de fumée dans le noir (torches éteintes, A, B, A').</p>
<p>Q34 = C : presque blanc pendant le plein feu (2 s par défaut, 4 s avec le rouge long), puis <b>rouge</b> (teinte 350° à
15°, saturation ≥ 0,6).</p>
<div class="tete"><table><tr><th>âge</th><th>défaut — avant</th><th>défaut — après</th><th>rouge long — avant</th>
<th>rouge long — après</th></tr>
%s
</table></div></body></html>""" % "\n".join(lignes)
    with open(os.path.join(sortie, "planche.html"), "w", encoding="utf-8") as f:
        f.write(page)


if __name__ == "__main__":
    main()
