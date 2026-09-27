#!/usr/bin/env python3
"""La planche de la fusée par âges (Q34 = C, Q35 = B) — mesures, JPEG et planche.html.

Lit, pour chaque variante, le journal du photographe (lignes `FUSEE_AGES {json}`) et le dossier qu'il a écrit
(`manifeste.json` + PNG), puis écrit dans le dossier de sortie :
- `<variante>/aX_Y-plein.jpg`  la fenêtre entière vue par J1 (1920×1080) ;
- `<variante>/aX_Y-loupe.jpg`  la loupe ×3 autour de la fusée (640×360 agrandis au plus proche) ;
- `mesures.json` et `planche.html` (autonome, images en chemins relatifs).

Les mesures, par âge :
- sol éclairé : dans l'anneau du monde de 24 à 64 px autour de la fusée (projeté par la caméra de J1), sur l'image
  du joueur, les pixels allumés (max des canaux ≥ 8/255) : teinte moyenne (circulaire) et saturation moyenne (HSV) ;
- point de braise : le pixel le plus lumineux à 14 px au plus du point projeté, et la moyenne de ses 9 plus lumineux ;
- part de fumée visible : dans le disque de fumée projeté, la part des pixels où la paire torches éteintes
  (fumée coupée / rétablie) diffère d'au moins 4/255 sur un canal ;
- noir absolu : les pixels NOIRS (0,0,0) dans les DEUX prises fumée coupée et ALLUMÉS fumée rétablie, sur toute la
  fenêtre — ce que la fumée allume hors de la lumière. Le nombre de pixels noirs de la référence est donné à côté (à 0,
  le test ne dirait rien), et celui des pixels qui changent seuls entre les deux prises coupées (le bruit écarté).

Usage :
  python3 mesurer.py --variante defaut=JOURNAL,DOSSIER --variante long=JOURNAL,DOSSIER --sortie DOSSIER
"""
import argparse
import colorsys
import html
import json
import math
import os
import shutil

import numpy as np
from PIL import Image, ImageDraw

LOUPE = (640, 360)
SEUIL_ALLUME = 8
SEUIL_FUMEE = 4


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


def masque(taille, poly):
    im = Image.new("L", taille, 0)
    ImageDraw.Draw(im).polygon([tuple(p) for p in poly], fill=255)
    return np.array(im) > 0


def teinte_saturation(px):
    """Teinte moyenne circulaire (degrés) et saturation moyenne, sur des pixels RGB 0-255."""
    if len(px) == 0:
        return None, None
    hs = np.array([colorsys.rgb_to_hsv(*(c / 255.0)) for c in px])
    ang = hs[:, 0] * 2 * math.pi
    h = math.degrees(math.atan2(np.sin(ang).mean(), np.cos(ang).mean())) % 360
    return round(h, 1), round(float(hs[:, 1].mean()), 3)


def mesurer(e, ids):
    g = e["geometrie"]
    j = np.array(Image.open(ids[0]).convert("RGB")).astype(int)
    a = np.array(Image.open(ids[1]).convert("RGB")).astype(int)
    b = np.array(Image.open(ids[2]).convert("RGB")).astype(int)
    a2 = np.array(Image.open(ids[3]).convert("RGB")).astype(int)
    taille = (j.shape[1], j.shape[0])
    anneau = masque(taille, g["anneau_ext"]) & ~masque(taille, g["anneau_int"])
    allume = j.max(axis=2) >= SEUIL_ALLUME
    sol = j[anneau & allume]
    # Un échantillon suffit à la moyenne ; colorsys est lent sur 50 000 pixels.
    ech = sol[:: max(1, len(sol) // 4000)]
    h, s = teinte_saturation(ech)
    lum = float((0.2126 * sol[:, 0] + 0.7152 * sol[:, 1] + 0.0722 * sol[:, 2]).mean()) if len(sol) else 0.0
    # Le point de braise.
    px, py = g["point"]
    yy, xx = np.mgrid[0:j.shape[0], 0:j.shape[1]]
    pres = (xx - px) ** 2 + (yy - py) ** 2 <= 14 ** 2
    cand = j[pres]
    somme = cand.sum(axis=1)
    ordre = np.argsort(-somme)
    plus = cand[ordre[0]].tolist()
    neuf = cand[ordre[:9]].mean(axis=0).round().astype(int).tolist()
    ph, ps = teinte_saturation(np.array([neuf]))
    # La fumée.
    disque = masque(taille, g["fumee"])
    diff = np.abs(b - a).max(axis=2) >= SEUIL_FUMEE
    part_fumee = float((diff & disque).sum()) / max(1, int(disque.sum()))
    # Le noir absolu.
    noir_a = (a.max(axis=2) == 0) & (a2.max(axis=2) == 0)
    allume_b = b.max(axis=2) > 0
    fuite = noir_a & allume_b
    # Ce qui bouge seul entre les deux prises coupées : le bruit que la double exigence écarte.
    instable = (a.max(axis=2) == 0) != (a2.max(axis=2) == 0)
    ys, xs = np.nonzero(fuite)
    return {
        "sol_teinte": h, "sol_saturation": s, "sol_luminance": round(lum, 1), "sol_pixels_allumes": int(len(sol)),
        "sol_part_allumee": round(float(len(sol)) / max(1, int(anneau.sum())), 3),
        "point_max": plus, "point_moy9": neuf, "point_teinte": ph, "point_saturation": ps,
        "part_fumee": round(part_fumee, 3),
        "noir_reference": int(noir_a.sum()), "noir_instables": int(instable.sum()), "noir_fuites": int(fuite.sum()),
        "noir_fuites_disque_fumee": int((fuite & disque).sum()), "joueur_pixels_noirs": int((j.max(axis=2) == 0).sum()),
        "noir_fuites_boite": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())] if len(xs) else None,
        "noir_fuite_max": int(b[fuite].max()) if len(xs) else 0,
    }


def loupe(src, centre, sortie):
    im = Image.open(src).convert("RGB")
    w, h = LOUPE
    x = min(max(int(round(centre[0])) - w // 2, 0), im.width - w)
    y = min(max(int(round(centre[1])) - h // 2, 0), im.height - h)
    im.crop((x, y, x + w, y + h)).resize((w * 3, h * 3), Image.NEAREST).save(sortie, quality=85)


def illustration(src, sortie_dir):
    im = Image.open(src).convert("RGB")
    im.save(os.path.join(sortie_dir, "illustration.jpg"), quality=85)
    # Le sol éclairé de l'illustration, sous la fusée et devant elle (repéré à l'œil sur l'image 1024×640) : la même
    # mesure que sous la fusée du jeu, pour comparer les chiffres.
    a = np.array(im).astype(int)
    zone = a[480:560, 240:560].reshape(-1, 3)
    zone = zone[zone.max(axis=1) >= SEUIL_ALLUME]
    h, s = teinte_saturation(zone[:: max(1, len(zone) // 4000)])
    # Le cœur blanc de la flamme.
    flamme = a[380:450, 410:470].reshape(-1, 3)
    top = flamme[np.argsort(-flamme.sum(axis=1))[:9]].mean(axis=0).round().astype(int).tolist()
    return {"sol_teinte": h, "sol_saturation": s, "zone_sol": "x 240-560, y 480-560", "flamme_moy9": top}


def pastille(rgb):
    return '<span class="sw" style="background:rgb(%d,%d,%d)"></span>' % tuple(rgb)


def legende(e):
    m = e["mesures"]
    noir = ("✅ 0 pixel" if m["noir_fuites"] == 0 else "⚠️ %d pixels (%d dans le disque de fumée, max %d/255)"
            % (m["noir_fuites"], m["noir_fuites_disque_fumee"], m["noir_fuite_max"]))
    return (
        '<div class="k">âge lu <b>%.4f s</b> · %s · énergie %.2f · fumée α %.2f</div>'
        '<table>'
        '<tr><th>sol éclairé</th><td>teinte <b>%.1f°</b> · saturation <b>%.2f</b> · luminance %.0f</td></tr>'
        '<tr><th>point de braise</th><td>%s (%d, %d, %d) · teinte %.0f° · sat. %.2f</td></tr>'
        '<tr><th>fumée visible</th><td><b>%.0f %%</b> du disque</td></tr>'
        '<tr><th>noir absolu</th><td>%s <span class="d">(réf. %d px noirs, %d instables écartés)</span></td></tr>'
        '</table>'
    ) % (e["age_lu"], e["acte"].replace("_", " ").lower(), e["energie_relative"], e["alpha_fumee"],
         m["sol_teinte"], m["sol_saturation"], m["sol_luminance"],
         pastille(m["point_moy9"]), *m["point_moy9"], m["point_teinte"], m["point_saturation"],
         100 * m["part_fumee"], noir, m["noir_reference"], m["noir_instables"])


def ecrire_planche(tout, sortie, tete=""):
    ill = tout["illustration"]
    v = tout["variantes"]
    h = ['<!doctype html><html lang="fr"><head><meta charset="utf-8">'
         '<meta name="viewport" content="width=device-width,initial-scale=1">'
         '<title>Fusée par âges</title><style>'
         ':root{--fond:#0b0b0d;--carte:#141416;--bord:#26262c;--texte:#e8e4dc;--doux:#9a9389;--or:#c9a227}'
         'body{background:var(--fond);color:var(--texte);font:14px/1.5 system-ui,sans-serif;margin:0;padding:24px 16px}'
         'h1{font-size:20px;letter-spacing:.12em;text-transform:uppercase;margin:0 0 6px}'
         'h2{font-size:13px;letter-spacing:.18em;text-transform:uppercase;color:var(--or);border-bottom:1px solid var(--bord);'
         'padding-bottom:6px;margin:36px 0 12px}'
         'p{max-width:980px;color:var(--doux)}'
         '.r{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}'
         '@media(max-width:900px){.r{grid-template-columns:1fr}}'
         'figure{margin:0;background:var(--carte);border:1px solid var(--bord);border-radius:4px;overflow:hidden}'
         'img{width:100%;display:block;background:#000}figcaption{padding:8px 10px;font-size:12px}'
         '.t{font-weight:600;font-size:13px}.k{color:var(--doux);margin:2px 0 4px}'
         'table{border-collapse:collapse}th{text-align:left;color:var(--doux);font-weight:400;padding:1px 8px 1px 0;'
         'white-space:nowrap;vertical-align:top}td{padding:1px 0}.d{color:#6d675f}'
         '.sw{display:inline-block;width:11px;height:11px;border:1px solid #555;vertical-align:-1px;margin-right:3px}'
         'a{color:var(--or)}</style></head><body>']
    h.append('<h1>La fusée posée, par âges — Q34 = C et Q35 = B</h1>')
    h.append('<p>Vue de J1, lacet 45°, zoom ×1,5, 1920×1080, loupe ×3 autour de la fusée (640×360 agrandis au plus proche). '
             'À gauche l’illustration « Créer en ligne », au milieu le défaut (Q34 : plein feu 2 s), à droite '
             '<code>--fusee-rouge-long</code> (Q35 : plein feu 4 s, braise 8 s, vie 20 s). L’âge est piloté en temps de jeu '
             '(photographe sous <code>--fixed-fps 60</code>) et lu sur la fusée. Rendu logiciel du cloud (llvmpipe) : '
             'valable pour les couleurs et les comptes de pixels, pas pour la cadence ni l’éblouissement. '
             'Chaque vignette ouvre l’image entière. %s</p>' % tete)
    h.append('<p>Illustration, mêmes mesures : sol (%s) teinte <b>%.1f°</b>, saturation <b>%.2f</b> ; cœur de la flamme %s (%d, %d, %d).</p>'
             % (ill["zone_sol"], ill["sol_teinte"], ill["sol_saturation"], pastille(ill["flamme_moy9"]), *ill["flamme_moy9"]))
    noms = [e["nom"] for e in v["defaut"]]
    for i, nom in enumerate(noms):
        age = v["defaut"][i]["age_demande"]
        h.append('<h2>%s s%s</h2><div class="r">' % (str(age).replace(".", ","), " — le cœur de la question" if age == 3.5 else ""))
        h.append('<figure><a href="illustration.jpg"><img src="illustration.jpg" alt="Illustration Créer en ligne" loading="lazy"></a>'
                 '<figcaption><div class="t">L’illustration cible</div></figcaption></figure>')
        for var, titre in (("defaut", "Q34 — défaut"), ("long", "Q35 — rouge long")):
            e = v[var][i]
            h.append('<figure><a href="%s/%s-plein.jpg"><img src="%s/%s-loupe.jpg" alt="%s à %s s" loading="lazy"></a>'
                     '<figcaption><div class="t">%s</div>%s <a href="%s/%s-noir.jpg">torches éteintes</a></figcaption></figure>'
                     % (var, nom, var, nom, titre, age, titre, legende(e), var, nom))
        h.append('</div>')
    h.append('</body></html>')
    with open(os.path.join(sortie, "planche.html"), "w", encoding="utf-8") as f:
        f.write("\n".join(h))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variante", action="append", required=True)
    ap.add_argument("--sortie", required=True)
    ap.add_argument("--illustration", default="assets/ui/ill_creer_ligne.png")
    args = ap.parse_args()
    os.makedirs(args.sortie, exist_ok=True)
    tout = {"illustration": illustration(args.illustration, args.sortie), "variantes": {}}
    for v in args.variante:
        nom, reste = v.split("=", 1)
        journal, dossier = reste.split(",", 1)
        f = fichiers(dossier)
        os.makedirs(os.path.join(args.sortie, nom), exist_ok=True)
        lignes = []
        for e in lire_journal(journal):
            ids = [f[i] for i in e["ids"]]
            m = mesurer(e, ids)
            base = os.path.join(args.sortie, nom, e["nom"])
            Image.open(ids[0]).convert("RGB").save(base + "-plein.jpg", quality=85)
            Image.open(ids[2]).convert("RGB").save(base + "-noir.jpg", quality=85)
            loupe(ids[0], e["geometrie"]["centre"], base + "-loupe.jpg")
            e2 = {k: e[k] for k in e if k not in ("geometrie", "ids")}
            e2["centre"] = e["geometrie"]["centre"]
            e2["point"] = e["geometrie"]["point"]
            e2["mesures"] = m
            lignes.append(e2)
            print(nom, e["nom"], "âge lu %.4f" % e["age_lu"], e["acte"], json.dumps(m))
        tout["variantes"][nom] = lignes
    with open(os.path.join(args.sortie, "mesures.json"), "w", encoding="utf-8") as f:
        json.dump(tout, f, ensure_ascii=False, indent=1)
    ecrire_planche(tout, args.sortie)


if __name__ == "__main__":
    main()
