#!/usr/bin/env python3
"""Deux vignettes pour le rapport, tirées des prises (même source que `mesurer.py`) :
- `img/noir_sol_marque.jpg` : torches éteintes, « hier » puis « tout », autour des pixels noirs que « tout » allume à la
  Croisée (1044, 307) et au Bunker (1806, 426) ; agrandies ×2 au plus proche voisin, valeurs ×2 pour les voir ;
- `img/equite_disque.jpg` : l'écran scindé de la scène `equite` (sans les corps), pixels éclairés d'un seul côté (blanc),
  défaut / témoin / tout — le disque violacé sur la moitié de J1."""
import os

import numpy as np
from PIL import Image

from mesurer import ICI, SOURCE, SEUIL_NOIR, moities

tuiles = []
for scene, (x, y) in (("croisee_noir", (1044, 307)), ("bunker_noir", (1806, 426))):
    for lanc in ("hier", "tout"):
        im = Image.open(os.path.join(SOURCE, lanc, scene + ".png")).convert("RGB")
        im = im.crop((x - 120, y - 70, x + 120, y + 70)).resize((480, 280), Image.NEAREST)
        tuiles.append(im.point(lambda v: min(255, v * 2)))
sortie = Image.new("RGB", (960, 560))
for i, t in enumerate(tuiles):
    sortie.paste(t, ((i % 2) * 480, (i // 2) * 280))
sortie.save(os.path.join(ICI, "img", "noir_sol_marque.jpg"), quality=85)

rangs = []
for lanc in ("defaut", "temoin", "tout"):
    a = np.asarray(Image.open(os.path.join(SOURCE, lanc, "equite_sans_corps.png")).convert("RGB")).astype(float)
    g, d = moities(a)
    lg, ld = g.max(axis=2) > SEUIL_NOIR, d.max(axis=2) > SEUIL_NOIR
    rangs.append(((lg ^ ld) * 255).astype(np.uint8))
Image.fromarray(np.concatenate(rangs, axis=1)).resize((1437, 540)).save(
    os.path.join(ICI, "img", "equite_disque.jpg"), quality=85)
print("vignettes écrites")
