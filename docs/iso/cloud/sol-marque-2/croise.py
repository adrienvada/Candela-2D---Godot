#!/usr/bin/env python3
"""Sol marqué 2 — la peinture PÉRIMÉE, sur les 6 × 6 couples de cartes : les murs de la carte posée lisent la peinture de
la précédente (défaut de `presentation_3d.gd`, voir RAPPORT § 1). Pour chaque couple (précédente → posée), le gain maximal
de la lecture d'un mur (`lecture.py`) :
  décor — le décor cuit par défaut (chevrons, pochoirs d'origine) de la précédente, contre celui de la posée. ⚠️ La cuisson
          ne contient QUE le décor : ni le sol, ni l'encre des murs, ni les murs — le défaut du jeu par défaut se mesure en
          jeu (`entre.py`, 822 pixels), pas ici ;
  sol   — même peinture périmée, avec le sol marqué, contre sans (ce que le sol marqué y AJOUTE) ;
  poch  — idem avec les pochoirs.
La diagonale (précédente = posée) est le cas sain : la peinture de la carte elle-même.

    python3 croise.py grilles.json <cuisson sans> <cuisson sol marqué> <cuisson pochoirs>
"""
import json
import sys

import numpy as np

import lecture as L

grilles = json.load(open(sys.argv[1]))
sans, sol, poch = sys.argv[2:5]
noms = list(grilles)
p = {k: {n: L.peinture(f"{r}/{n}.png") for n in noms} for k, r in (("sans", sans), ("sol", sol), ("poch", poch))}


def gain_max(carte, num, den):
    t, pied = carte["tuile"], carte["pied"]
    g = 1.0
    for ar in L.aretes(carte):
        _, a = L.lire(num, pied, ar, t)
        _, b = L.lire(den, pied, ar, t)
        g = max(g, float(np.max(a / b)))
    return g


print("précédente → posée".ljust(44), "décor seul  sol marqué  pochoirs")
for prec in noms:
    for posee in noms:
        c = grilles[posee]
        jeu = gain_max(c, p["sans"][prec], p["sans"][posee])
        gs = gain_max(c, p["sol"][prec], p["sans"][prec])
        gp = gain_max(c, p["poch"][prec], p["sans"][prec])
        print(f"{prec:20s} → {posee:20s}  ×{jeu:5.2f}      ×{gs:5.2f}      ×{gp:5.2f}")
