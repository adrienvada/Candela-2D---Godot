#!/usr/bin/env python3
"""L'allègement de la 0.8.0 — la planche des éventails : pour chaque cookie livré, le cookie lui-même (son alpha, en gris),
le CARRÉ que chaque couche du rayon rastérisait avant (toute la texture), et l'ÉVENTAIL qu'elle rastérise désormais (vert),
avec celui qu'aurait le juge dans l'OPTION du juge taillé (orange, dilaté de la parallaxe ; par défaut le juge garde son
disque). Les sommets viennent du code du jeu (`eventails.gd`).

    godot --headless --path . --script res://tools/faisceau_taille/eventails.gd -- /tmp/eventails.json
    python3 tools/faisceau_taille/planche_eventails.py /tmp/eventails.json assets/torche docs/iso/allegement_080/planche_eventails.jpg
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def police(taille=13):
    """Une police qui écrit les accents (celle de Pillow par défaut ne les écrit pas) : DejaVu (Linux), Arial (Mac)."""
    for chemin in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/System/Library/Fonts/Supplemental/Arial.ttf",
                   "/Library/Fonts/Arial Unicode.ttf"):
        if os.path.exists(chemin):
            return ImageFont.truetype(chemin, taille)
    return ImageFont.load_default(size=taille)


POLICE = police()

donnees = json.load(open(sys.argv[1]))
cookies, sortie = sys.argv[2], sys.argv[3]
T = 300
cases = []
for slug, d in donnees.items():
    a = np.asarray(Image.open(os.path.join(cookies, "cookie_%s.png" % slug)).convert("RGBA"))[..., 3]
    fond = Image.fromarray((a > 0).astype(np.uint8) * 90 + (a.astype(np.float32) / 255 * 165).astype(np.uint8)).convert("RGB")
    fond = fond.resize((T, T), Image.LANCZOS)
    case = Image.new("RGB", (T, T + 34), (14, 14, 14))
    case.paste(fond, (0, 0))
    dessin = ImageDraw.Draw(case)
    # Le repère du maillage : le carré d'avant va de −0,5 à 0,5 (la texture entière) ; x vers l'axe de la lampe.
    def px(p):
        return ((p[0] + 0.5) * T, (p[1] + 0.5) * T)
    dessin.rectangle([0, 0, T - 1, T - 1], outline=(200, 60, 60), width=2)
    dessin.polygon([px(p) for p in d["juge"]], outline=(240, 150, 40))
    dessin.polygon([px(p) for p in d["couche"]], outline=(80, 230, 110))
    dessin.text((6, T + 4), "%s : couches %.1f %% du carré" % (slug, 100.0 * d["part_couche"]), fill=(230, 230, 230),
                font=POLICE)
    # Le disque ajusté d'avant (V5) : rayon (portée + 8,4 px) à 728 px, seize côtés circonscrits — ~81 % du carré.
    dessin.text((6, T + 18), "option du juge : %.1f %% (son disque : ~81 %%)" % (100.0 * d["part_juge"]), fill=(200, 200, 200),
                font=POLICE)
    cases.append(case)
colonnes = 5
lignes = (len(cases) + colonnes - 1) // colonnes
planche = Image.new("RGB", (colonnes * (T + 8) + 8, lignes * (T + 42) + 30), (8, 8, 8))
ImageDraw.Draw(planche).text((10, 8), "Rouge : le carré que chaque couche rastérisait (toute la texture de la lampe). Vert : l'éventail "
                             "des couches (le défaut). Orange : celui du juge dans l'option du juge taillé. Gris : le cookie (alpha).",
                             fill=(230, 230, 230), font=POLICE)
for i, c in enumerate(cases):
    planche.paste(c, (8 + (i % colonnes) * (T + 8), 30 + (i // colonnes) * (T + 42)))
planche.save(sortie, quality=88)
print("écrit : %s" % sortie)
