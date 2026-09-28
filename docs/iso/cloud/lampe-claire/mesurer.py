#!/usr/bin/env python3
"""Q40, la lampe claire : les chiffres d'une séance de `tools/photo_lampe.gd`.

    python3 docs/iso/cloud/lampe-claire/mesurer.py <dossier des prises> > mesures.json

Chaque scène a trois prises AU MÊME INSTANT (jeu en pause) : `defaut`, `essai`, `defaut2`. Luminance Rec. 709 des
valeurs sRGB, 0..255. Le « sol éclairé par la torche » : les pixels que la scène torches allumées montre au moins 6/255
plus clairs que la même scène torches éteintes (prise juste après, même place), corps exclus (écart nul à l'essai).
"""
import sys, json, glob, os, colorsys
import numpy as np
from PIL import Image

d = sys.argv[1]
L = lambda x: 0.2126 * x[..., 0] + 0.7152 * x[..., 1] + 0.0722 * x[..., 2]


def charger(nom, etat):
    f = f"{d}/{nom}__{etat}.png"
    return np.asarray(Image.open(f)).astype(float) if os.path.exists(f) else None


def teinte(px):
    if len(px) == 0:
        return None
    r, g, b = px.mean(0) / 255
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return {"teinte_deg": round(h * 360, 1), "saturation": round(s, 3), "rgb": [round(v) for v in px.mean(0)]}


def stats(la, px, m):
    if m.sum() == 0:
        return {"n": 0}
    return {"n": int(m.sum()), "mediane": round(float(np.median(la[m])), 1), "p99": round(float(np.percentile(la[m], 99)), 1),
            "couleur": teinte(px[m])}


def une_scene(nom, noir, moities=False):
    a, b, a2 = charger(nom, "defaut"), charger(nom, "essai"), charger(nom, "defaut2")
    if a is None or b is None:
        return None
    la, lb = L(a), L(b)
    r = {"bruit_px": int((np.abs(a - a2).sum(2) > 0).sum()) if a2 is not None else None,
         "changes_px": int((np.abs(a - b).sum(2) > 0).sum()),
         "noir_allume_px": int(((a.max(2) == 0) & (b.max(2) > 0)).sum()),
         "plus_sombre_px": int((lb < la - 0.5).sum()),
         "image_p99": [round(float(np.percentile(la, 99)), 1), round(float(np.percentile(lb, 99)), 1)],
         "image_1pc_couleur": [teinte(a[la >= np.percentile(la, 99)]), teinte(b[lb >= np.percentile(lb, 99)])]}
    e = charger(noir, "defaut") if noir else None
    if e is not None:
        torche = (la - L(e)) > 6.0
        parts = {"tout": np.ones(la.shape, bool)}
        if moities:
            w = la.shape[1] // 2
            g = np.zeros(la.shape, bool); g[:, :w] = True
            parts = {"vue_j1": g, "vue_j2": ~g}
        for k, p in parts.items():
            m = torche & p
            r[f"torche_{k}"] = {"defaut": stats(la, a, m), "essai": stats(lb, b, m)}
            c = m & (la >= 60)
            r[f"coeur_{k}"] = {"defaut": stats(la, a, c), "essai": stats(lb, b, c)}
    return r


sortie = {}
for f in sorted(glob.glob(f"{d}/*__defaut.png")):
    nom = os.path.basename(f)[:-len("__defaut.png")]
    if "_classe" in nom:
        continue
    if nom.endswith("_noir"):
        sortie[nom] = une_scene(nom, None)
    elif nom.endswith("_scinde"):
        sortie[nom] = une_scene(nom, nom + "_noir", moities=True)
    else:
        sortie[nom] = une_scene(nom, nom[:-len("_duel")] + "_noir" if nom.endswith("_duel") else None)

# Les classes : le corps de J2 (masque : écart entre la prise et la même corps caché) au bord du cône de J1.
classes = {}
for i in range(10):
    nom = f"map_001_le_cloitre_classe{i}"
    a, b, sa, sb = (charger(nom, k) for k in ("defaut", "essai", "sans_corps_defaut", "sans_corps_essai"))
    if a is None or sa is None:
        continue
    corps = np.abs(a - sa).sum(2) > 0
    sol_change = np.abs(sa - sb).sum(2) > 0
    propre = corps & ~sol_change
    classes[nom] = {"corps_px": int(corps.sum()), "corps_propre_px": int(propre.sum()),
                    "corps_propre_ecart_max": float(np.abs(a - b)[propre].max()) if propre.any() else 0.0,
                    "corps_propre_ecart_px": int((np.abs(a - b)[propre].sum(1) > 0).sum()),
                    "ombre_au_sol_changee_px": int((corps & sol_change).sum())}
sortie["classes"] = classes
capteurs = f"{d}/capteurs.json"
if os.path.exists(capteurs):
    cap = json.load(open(capteurs))
    sortie["capteurs_identiques"] = {k: (v["defaut"] == v["essai"] == v["defaut2"]) for k, v in cap.items()}
    sortie["capteurs"] = cap
print(json.dumps(sortie, indent=1, ensure_ascii=False))
