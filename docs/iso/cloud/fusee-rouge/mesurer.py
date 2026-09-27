#!/usr/bin/env python3
"""La planche du rouge sang (`--fusee-rouge-sang`) contre l'illustration — mesures, JPEG et planche.html.

Reprend les mesures de la session « fusée » (`docs/iso/cloud/fusee/mesurer.py`, importé tel quel : sol éclairé, point,
fumée, noir absolu en trois prises A, B, A') et y ajoute ce que la règle de l'essai demande :
- le sol éclairé mesuré AUSSI torches éteintes (prise A, fumée coupée) : la lumière de la fusée seule, sans le voile
  d'éblouissement ni la torche de J1 — la mesure la plus propre de sa couleur ;
- l'écart de luminance du sol entre chaque variante « sang » et sa référence, au même âge (règle : ±3 %) ;
- le NOIR CROISÉ : dans chacune des trois prises torches éteintes, les pixels noirs (0,0,0) chez la référence et allumés
  chez la variante sang, et l'inverse ; plus, pour vérifier que les deux passages sont au même instant de jeu, le nombre
  de pixels qui diffèrent hors du disque de lumière de la fusée (0 attendu : même horloge, même respiration des LED).

Usage :
  python3 mesurer.py --variante defaut=JOURNAL,DOSSIER --variante sang=... --variante long=... --variante longsang=... \
      --sortie DOSSIER
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ICI, "..", "fusee"))
sys.dont_write_bytecode = True
import mesurer as base  # noqa: E402  (la session « fusée »)

PAIRES = (("sang", "defaut"), ("longsang", "long"))
TITRES = {
    "defaut": "Défaut (Q34)",
    "sang": "--fusee-rouge-sang",
    "long": "--fusee-rouge-long (Q35)",
    "longsang": "rouge long + rouge sang",
}
# Rayon (px écran) autour du centre de la fusée au-delà duquel sa lumière ne porte plus : 440 px d'empreinte au monde,
# ×1,5 de zoom, plus une marge. Sert au contrôle « même instant de jeu ».
RAYON_LUMIERE_ECRAN = 440 * 1.5 * 0.5 + 60


def lire(ids, i):
    return np.array(Image.open(ids[i]).convert("RGB")).astype(int)


def sol_eteint(e, ids):
    """Sol éclairé dans l'anneau, sur la prise torches éteintes et fumée coupée (A)."""
    g = e["geometrie"]
    a = lire(ids, 1)
    taille = (a.shape[1], a.shape[0])
    anneau = base.masque(taille, g["anneau_ext"]) & ~base.masque(taille, g["anneau_int"])
    sol = a[anneau & (a.max(axis=2) >= base.SEUIL_ALLUME)]
    h, s = base.teinte_saturation(sol[:: max(1, len(sol) // 4000)])
    lum = float((0.2126 * sol[:, 0] + 0.7152 * sol[:, 1] + 0.0722 * sol[:, 2]).mean()) if len(sol) else 0.0
    return {"teinte": h, "saturation": s, "luminance": round(lum, 2), "pixels": int(len(sol))}


def noir_croise(e_ref, ids_ref, e_var, ids_var):
    """Prise par prise (A, B, A'), les pixels noirs chez la référence et allumés chez la variante, et l'inverse."""
    out = {}
    cx, cy = e_ref["geometrie"]["centre"]
    for nom, i in (("A", 1), ("B", 2), ("A2", 3)):
        r = lire(ids_ref, i)
        v = lire(ids_var, i)
        noir_r = r.max(axis=2) == 0
        noir_v = v.max(axis=2) == 0
        yy, xx = np.mgrid[0:r.shape[0], 0:r.shape[1]]
        loin = (xx - cx) ** 2 + (yy - cy) ** 2 > RAYON_LUMIERE_ECRAN ** 2
        diff = np.abs(r - v).max(axis=2) > 0
        out[nom] = {
            "noirs_ref": int(noir_r.sum()), "noirs_var": int(noir_v.sum()),
            "allumes_par_la_variante": int((noir_r & ~noir_v).sum()),
            "eteints_par_la_variante": int((~noir_r & noir_v).sum()),
            "max_allume": int(v[noir_r & ~noir_v].max()) if (noir_r & ~noir_v).any() else 0,
            "differences_loin_de_la_fusee": int((diff & loin).sum()),
        }
    return out


def ecart(v, r):
    """Écart relatif en %, ou None si la référence n'a rien d'allumé."""
    return round(100.0 * (v / r - 1.0), 2) if r else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variante", action="append", required=True)
    ap.add_argument("--sortie", required=True)
    ap.add_argument("--illustration", default="assets/ui/ill_creer_ligne.png")
    args = ap.parse_args()
    os.makedirs(args.sortie, exist_ok=True)
    ill = base.illustration(args.illustration, args.sortie)
    a = np.array(Image.open(args.illustration).convert("RGB")).astype(int)
    zone = a[480:560, 240:560].reshape(-1, 3)
    zone = zone[zone.max(axis=1) >= base.SEUIL_ALLUME]
    ill["sol_luminance"] = round(float((0.2126 * zone[:, 0] + 0.7152 * zone[:, 1] + 0.0722 * zone[:, 2]).mean()), 1)
    tout = {"illustration": ill, "variantes": {}, "croise": {}}
    brut = {}
    for v in args.variante:
        nom, reste = v.split("=", 1)
        journal, dossier = reste.split(",", 1)
        f = base.fichiers(dossier)
        os.makedirs(os.path.join(args.sortie, nom), exist_ok=True)
        lignes = []
        brut[nom] = []
        for e in base.lire_journal(journal):
            ids = [f[i] for i in e["ids"]]
            m = base.mesurer(e, ids)
            m["eteint"] = sol_eteint(e, ids)
            racine = os.path.join(args.sortie, nom, e["nom"])
            Image.open(ids[0]).convert("RGB").save(racine + "-plein.jpg", quality=85)
            base.loupe(ids[0], e["geometrie"]["centre"], racine + "-loupe.jpg")
            base.loupe(ids[1], e["geometrie"]["centre"], racine + "-loupe-eteint.jpg")
            e2 = {k: e[k] for k in e if k not in ("geometrie", "ids")}
            e2["mesures"] = m
            lignes.append(e2)
            brut[nom].append((e, ids))
            print(nom, e["nom"], "âge lu %.4f" % e["age_lu"], e["acte"],
                  "sol %s° %s L%s | éteint %s" % (m["sol_teinte"], m["sol_saturation"], m["sol_luminance"],
                                                   json.dumps(m["eteint"])))
        tout["variantes"][nom] = lignes
    for var, ref in PAIRES:
        if var not in brut or ref not in brut:
            continue
        rangs = []
        for (ev, iv), (er, ir), lv, lr in zip(brut[var], brut[ref], tout["variantes"][var], tout["variantes"][ref]):
            mv, mr = lv["mesures"], lr["mesures"]
            c = {
                "age": er["age_demande"],
                "meme_age": abs(ev["age_lu"] - er["age_lu"]) < 1e-9,
                "lum_joueur": ecart(mv["sol_luminance"], mr["sol_luminance"]),
                "lum_eteint": ecart(mv["eteint"]["luminance"], mr["eteint"]["luminance"]),
                "noir": noir_croise(er, ir, ev, iv),
            }
            rangs.append(c)
            print("croisé", var, "contre", ref, json.dumps(c))
        tout["croise"][var] = rangs
    with open(os.path.join(args.sortie, "mesures.json"), "w", encoding="utf-8") as f:
        json.dump(tout, f, ensure_ascii=False, indent=1)
    ecrire_planche(tout, args.sortie)


def n(x, fmt="%.1f"):
    return "—" if x is None else fmt % x


def legende(e, croise):
    m = e["mesures"]
    t = m["eteint"]
    lignes = [
        '<div class="k">âge lu %.3f s · %s · énergie %.2f</div><table>' % (
            e["age_lu"], e["acte"].replace("_", " ").lower(), e["energie_relative"]),
        '<tr><th>sol, vue de J1</th><td><b>%s°</b> · sat. <b>%s</b> · lum. %s</td></tr>' % (
            n(m["sol_teinte"]), n(m["sol_saturation"], "%.2f"), n(m["sol_luminance"])),
        '<tr><th>sol, torches éteintes</th><td><b>%s°</b> · sat. <b>%s</b> · lum. %s</td></tr>' % (
            n(t["teinte"]), n(t["saturation"], "%.2f"), n(t["luminance"])),
    ]
    if croise is not None:
        noir = croise["noir"]
        allumes = sum(noir[k]["allumes_par_la_variante"] for k in noir)
        lignes.append('<tr><th>écart de luminance</th><td>%s %% (J1) · %s %% (éteintes)</td></tr>' % (
            n(croise["lum_joueur"], "%+.2f"), n(croise["lum_eteint"], "%+.2f")))
        lignes.append('<tr><th>noir absolu</th><td>%s</td></tr>' % (
            "✅ 0 pixel noir allumé (A, B, A')" if allumes == 0 else "⚠️ %d pixels noirs allumés" % allumes))
    lignes.append('</table>')
    return "".join(lignes)


def ecrire_planche(tout, sortie):
    ill = tout["illustration"]
    v = tout["variantes"]
    ordre = [k for k in ("defaut", "sang", "long", "longsang") if k in v]
    css = (':root{--fond:#0b0b0d;--carte:#141416;--bord:#26262c;--texte:#e8e4dc;--doux:#9a9389;--or:#c9a227}'
           'body{background:var(--fond);color:var(--texte);font:14px/1.5 system-ui,sans-serif;margin:0;padding:24px 16px}'
           'h1{font-size:20px;letter-spacing:.12em;text-transform:uppercase;margin:0 0 6px}'
           'h2{font-size:13px;letter-spacing:.18em;text-transform:uppercase;color:var(--or);border-bottom:1px solid var(--bord);'
           'padding-bottom:6px;margin:36px 0 12px}p{max-width:1000px;color:var(--doux)}'
           '.r{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:12px}'
           '@media(max-width:1300px){.r{grid-template-columns:repeat(3,minmax(0,1fr))}}'
           '@media(max-width:800px){.r{grid-template-columns:1fr}}'
           'figure{margin:0;background:var(--carte);border:1px solid var(--bord);border-radius:4px;overflow:hidden}'
           'img{width:100%;display:block;background:#000}figcaption{padding:8px 10px;font-size:12px}'
           '.t{font-weight:600;font-size:13px}.k{color:var(--doux);margin:2px 0 4px}'
           'table{border-collapse:collapse}th{text-align:left;color:var(--doux);font-weight:400;padding:1px 8px 1px 0;'
           'white-space:nowrap;vertical-align:top}td{padding:1px 0}a{color:var(--or)}code{color:var(--texte)}')
    h = ['<!doctype html><html lang="fr"><head><meta charset="utf-8">'
         '<meta name="viewport" content="width=device-width,initial-scale=1"><title>Fusée, rouge sang</title>'
         '<style>%s</style></head><body>' % css,
         '<h1>Le rouge de la fusée contre celui de l’illustration — essai <code>--fusee-rouge-sang</code></h1>',
         '<p>Vue de J1, lacet 45°, zoom ×1,5, 1920×1080, loupe ×3 autour de la fusée posée (Cloître, dans le noir, hors de '
         'la torche de J1). Âge piloté en temps de jeu (<code>--fixed-fps 60</code>) et lu sur la fusée. Chaque vignette '
         'ouvre l’image entière ; « éteintes » ouvre la loupe torches éteintes (la lumière de la fusée seule). Rendu logiciel '
         'du cloud : valable pour les couleurs et les comptes de pixels, pas pour la cadence ni l’éblouissement.</p>',
         '<p>Illustration, même mesure (sol, %s) : teinte <b>%.1f°</b>, saturation <b>%.2f</b>, luminance %.1f.</p>' % (
             ill["zone_sol"], ill["sol_teinte"], ill["sol_saturation"], ill["sol_luminance"])]
    croise = {var: {c["age"]: c for c in tout["croise"].get(var, [])} for var in ordre}
    for i, e0 in enumerate(v["defaut"]):
        age = e0["age_demande"]
        h.append('<h2>%s s</h2><div class="r">' % str(age).replace(".", ","))
        h.append('<figure><a href="illustration.jpg"><img src="illustration.jpg" alt="Illustration Créer en ligne" '
                 'loading="lazy"></a><figcaption><div class="t">L’illustration cible</div></figcaption></figure>')
        for var in ordre:
            e = v[var][i]
            h.append('<figure><a href="%s/%s-plein.jpg"><img src="%s/%s-loupe.jpg" alt="%s à %s s" loading="lazy"></a>'
                     '<figcaption><div class="t">%s</div>%s<a href="%s/%s-loupe-eteint.jpg">éteintes</a></figcaption>'
                     '</figure>' % (var, e["nom"], var, e["nom"], TITRES[var], age, TITRES[var],
                                    legende(e, croise[var].get(age)), var, e["nom"]))
        h.append('</div>')
    h.append('</body></html>')
    with open(os.path.join(sortie, "planche.html"), "w", encoding="utf-8") as f:
        f.write("\n".join(h))


if __name__ == "__main__":
    main()
