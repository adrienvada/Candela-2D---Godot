#!/usr/bin/env python3
"""Sol marqué 2 — la distance RÉELLE des texels qu'un essai touche aux cases non-sol (murs, vide), carte par carte, sur les
textures cuites du décor (`docs/iso/cloud/sol-marque/cuisson.gd --sortie=…`, sans puis avec l'essai). Distance euclidienne du
centre du texel au bord de la case. Les murs lisent la peinture À `pied` = 12 px de leur arête, filtrage bilinéaire compris
jusqu'à 13 px : un texel dont le centre est à plus de 13 px n'entre dans aucune lecture.

    python3 distance.py grilles.json <cuisson sans> <cuisson avec>
"""
import json
import sys

import numpy as np
from PIL import Image

g = json.load(open(sys.argv[1]))
pire = 1e9
for nom, c in g.items():
    t = c["tuile"]
    a = np.asarray(Image.open(f"{sys.argv[2]}/{nom}.png").convert("RGBA")).astype(int)
    b = np.asarray(Image.open(f"{sys.argv[3]}/{nom}.png").convert("RGBA")).astype(int)
    ys, xs = np.nonzero(np.any(a != b, axis=2))
    cx, cy = xs - 35 + 0.5, ys - 35 + 0.5
    sol = set(map(tuple, c["sol"]))
    w, h = c["grille"]
    non = np.array([(i, j) for i in range(-1, w + 1) for j in range(-1, h + 1) if (i, j) not in sol], float)
    x0, x1, y0, y1 = non[:, 0] * t, (non[:, 0] + 1) * t, non[:, 1] * t, (non[:, 1] + 1) * t
    meilleur, ou = 1e9, None
    for k in range(len(cx)):
        dx = np.maximum(0, np.maximum(x0 - cx[k], cx[k] - x1))
        dy = np.maximum(0, np.maximum(y0 - cy[k], cy[k] - y1))
        d = np.sqrt(dx * dx + dy * dy)
        i = int(np.argmin(d))
        if d[i] < meilleur:
            meilleur, ou = float(d[i]), (float(cx[k]), float(cy[k]), tuple(int(v) for v in non[i]))
    pire = min(pire, meilleur)
    print(f"{nom:20s} {len(cx):6d} texels touchés · le plus près d'une case non-sol : {meilleur:5.2f} px (texel {ou[:2]}, case {ou[2]})")
print(f"pire : {pire:.2f} px — {'hors de portée' if pire > 13.0 else 'À PORTÉE'} des lectures des murs (12 px + 1 texel)")
sys.exit(0 if pire > 13.0 else 1)
