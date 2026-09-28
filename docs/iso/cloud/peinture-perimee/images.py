#!/usr/bin/env python3
"""La peinture périmée — les JPEG du rapport (qualité 85), éclaircis ×4 pour que le noir allumé se voie.

    python3 images.py <avant/chemin> <après/chemin> <nom>

Écrit img/<nom>.jpg : en haut, la prise A AVANT la correction (telle que le chemin l'a laissée) et la prise A APRÈS, côte à
côte, en demi-taille ; en bas, une loupe à pleine résolution sur la zone où les noirs de B s'allument dans A (avant), avec
ces pixels cerclés de magenta à droite.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

SEUIL = 7
ICI = os.path.dirname(os.path.abspath(__file__))


def lire(chemin):
    return np.asarray(Image.open(chemin).convert("RGB")).astype(int)


def eclaircir(a):
    return Image.fromarray(np.clip(a * 4, 0, 255).astype("uint8"))


avant, apres, nom = sys.argv[1], sys.argv[2], sys.argv[3]
a_av, b_av = lire(os.path.join(avant, "A.png")), lire(os.path.join(avant, "B.png"))
a_ap = lire(os.path.join(apres, "A.png"))
h, w, _ = a_av.shape
lit = (b_av.max(2) <= SEUIL) & (a_av.max(2) > SEUIL)
haut = Image.new("RGB", (w, h // 2 + 30), (20, 20, 20))
haut.paste(eclaircir(a_av).resize((w // 2, h // 2)), (0, 30))
haut.paste(eclaircir(a_ap).resize((w // 2, h // 2)), (w // 2, 30))
d = ImageDraw.Draw(haut)
d.text((10, 8), "AVANT la correction (prise A, eclaircie x4)", fill=(255, 255, 255))
d.text((w // 2 + 10, 8), "APRES la correction (prise A, eclaircie x4)", fill=(255, 255, 255))
if lit.any():
    ys, xs = np.nonzero(lit)
    # La loupe : la fenêtre de 640 × 360 px qui contient le plus de noirs allumés.
    meilleur, cx, cy = -1, 0, 0
    for y0 in range(0, h - 360 + 1, 60):
        for x0 in range(0, w - 640 + 1, 80):
            n = int(lit[y0:y0 + 360, x0:x0 + 640].sum())
            if n > meilleur:
                meilleur, cx, cy = n, x0, y0
    boite = (cx, cy, cx + 640, cy + 360)
    g = eclaircir(a_av).crop(boite)
    dr = eclaircir(a_ap).crop(boite)
    marque = ImageDraw.Draw(g)
    for x, y in zip(xs, ys):
        if cx <= x < cx + 640 and cy <= y < cy + 360:
            marque.point((x - cx, y - cy), fill=(255, 0, 255))
    bas = Image.new("RGB", (w, 540 + 30), (20, 20, 20))
    bas.paste(g.resize((w // 2, 540), Image.NEAREST), (0, 30))
    bas.paste(dr.resize((w // 2, 540), Image.NEAREST), (w // 2, 30))
    dd = ImageDraw.Draw(bas)
    dd.text((10, 8), f"loupe x1,5 sur {boite} : en magenta, les {meilleur} noirs allumes (avant)", fill=(255, 255, 255))
    dd.text((w // 2 + 10, 8), "la meme zone, apres", fill=(255, 255, 255))
    tout = Image.new("RGB", (w, haut.height + bas.height), (20, 20, 20))
    tout.paste(haut, (0, 0))
    tout.paste(bas, (0, haut.height))
else:
    tout = haut
os.makedirs(os.path.join(ICI, "img"), exist_ok=True)
tout.save(os.path.join(ICI, "img", f"{nom}.jpg"), quality=85)
print(f"img/{nom}.jpg : {int(lit.sum())} noirs allumés (avant)")
