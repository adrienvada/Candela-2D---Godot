#!/usr/bin/env python3
"""Planche d'E2 : les corps épais (vague 4 d'ISO Corps) dans le vrai duel iso, zone de touche gardée à 18 px.

Usage : python3 docs/iso/planche_corps_epais_jeu.py [--captures DIR]

Lit les captures de `tools/banc_iso.gd --jeu --scinde` (commandes dans la ROADMAP, section « E2 — Corps
épais et hitbox ») rangées dans docs/iso/captures_corps_epais/, et leurs relevés
(`releves_corps_epais.txt`), et compose docs/iso/planche_corps_epais_jeu.jpg :

- ligne 1 : l'écran scindé iso, torche de J1, J1 vient de tirer (balle et traçante au sol) ; gros plan sur
  le corps épais de chaque vue ;
- ligne 2 : torche de J2, J2 vient de tirer ; le porteur sous sa propre torche, sans tir ; la planche
  d'ISO Corps « avant / après » (réglage `x1_6`), en référence.

Les gros plans sont recadrés autour du corps le plus clair de chaque moitié d'écran.

Dépendance : Pillow. Police, compression et vignettes : celles de planche_iso.py et planche_iso1.py.
"""
import argparse
import os
import re
import sys

from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
from planche_iso import compresser  # noqa: E402
from planche_iso1 import planche  # noqa: E402


def lire(chemin):
    return open(chemin, encoding="utf-8", errors="replace").read() if os.path.exists(chemin) else ""


def gros_plan(c, source, cible, moitie, demi=(220, 160)):
    """Recadre la moitié `moitie` (0 gauche, 1 droite) de `source` autour de son corps : le centre des
    pixels saturés en couleur (bleu de J1, rose de J2), à défaut le centre de la moitié."""
    chemin = os.path.join(c, source)
    if not os.path.exists(chemin):
        return chemin
    im = Image.open(chemin).convert("RGB")
    w, h = im.size
    x0 = 0 if moitie == 0 else w // 2
    petit = im.crop((x0, 0, x0 + w // 2, h)).resize((w // 8, h // 4))
    px = petit.load()
    sx = sy = n = 0
    for y in range(petit.height // 6, petit.height):  # sous le HUD
        for x in range(petit.width):
            r, g, b = px[x, y]
            # Le bleu de J1 ou le rose de J2 — jamais l'orangé des halos et de la LED (r > g > b, b bas).
            bleu = b > r + 30 and b > 110
            rose = r > g + 30 and b > g + 10 and r > 110
            if bleu or rose:
                sx += x
                sy += y
                n += 1
    cx = x0 + (sx / n * 4 if n else w // 4)
    cy = sy / n * 4 if n else h // 2
    boite = (int(max(0, cx - demi[0])), int(max(0, cy - demi[1])), int(min(w, cx + demi[0])), int(min(h, cy + demi[1])))
    sortie = os.path.join(c, cible)
    im.crop(boite).save(sortie)
    return sortie


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--captures", default=os.path.join(ICI, "captures_corps_epais"))
    p.add_argument("--max-ko", type=int, default=450)
    p.add_argument("--max-planche-ko", type=int, default=1400)
    a = p.parse_args()
    c = a.captures
    t = lire(os.path.join(c, "releves_corps_epais.txt"))
    gp1 = gros_plan(c, "duel_j1.png", "gros_plan_vue_j1.png", 0)
    gp2 = gros_plan(c, "duel_j1.png", "gros_plan_vue_j2.png", 1)
    for nom in sorted(os.listdir(c)):
        if nom.endswith(".png"):
            compresser(os.path.join(c, nom), os.path.join(c, nom), a.max_ko * 1024)
    plafonds = re.findall(r"BANC_ISO corps verdict=([^(\n]+)", t)
    porteur = re.search(r"porteur (J\d) chez (J\d) : (\d+/\d+/\d+)", t)
    cases = [
        (os.path.join(c, "duel_j1.png"), "écran scindé iso, corps épais, torche de J1, J1 tire",
         "plafond : %s" % (plafonds[0].strip() if plafonds else "relevé absent"), 1),
        (gp1, "gros plan, vue de J1", "zone de touche 18 px · corps seul ≤ 17,3 px (ISO Corps)", 1),
        (gp2, "gros plan, vue de J2", "l'arme dépasse (corps + arme 24,4 px) et ne se touche pas", 1),
        (os.path.join(c, "duel_j2.png"), "torche de J2, J2 tire",
         "plafond : %s" % (plafonds[1].strip() if len(plafonds) > 1 else "relevé absent"), 1),
        (os.path.join(c, "porteur_j1.png"), "le porteur sous sa propre torche, sans tir",
         ("porteur %s chez %s : %s (plafond 81/88/95)" % porteur.groups()) if porteur else "relevé absent", 1),
        (os.path.join(ICI, "planche_corps_epais.png"), "référence : ISO Corps, avant / après (x1_6)",
         "Adrien tranche le réglage (×1,3 / ×1,6 / ×2,0) au jalon H-ISO5", 1),
    ]
    planche(cases, 3, "E2 — les corps épais dans le duel iso",
            "Vague 4 d'ISO Corps fusionnée · zone de touche gardée à 18 px (décision d'Adrien) · les deux vues",
            os.path.join(ICI, "planche_corps_epais_jeu.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
