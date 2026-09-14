#!/usr/bin/env python3
"""Planche d'ISO2 : les canaux par vue en écran scindé iso, et le noir absolu des deux vues.

Usage : python3 docs/iso/planche_iso2.py [--captures DIR] [--journal FICHIER]

Lit les captures écrites par `tools/banc_iso.gd --jeu` dans docs/iso/captures_iso2/ (les
commandes sont dans la ROADMAP, section ISO2), les compresse sur place sous --max-ko et
compose docs/iso/planche_iso2.jpg :

- ligne 1 : écran scindé iso, pâte D, torche de J1 seule — l'écran, puis la lightmap de J1
  et celle de J2 lues à la même image ;
- ligne 2 : la même scène, torche de J2 seule ;
- ligne 3 : le noir absolu — vue unique puis écran scindé, toutes lumières éteintes, et
  l'écran lightmaps noires, avec les valeurs maximales relevées par le banc (--journal).

Ce qui doit se lire sur les deux premières lignes : le halo de proximité d'un joueur n'est
que dans SA lightmap ; le faisceau d'une torche éclaire le sol des deux (règle du jeu, que
la vue de dessus applique déjà et que l'iso conserve).

⚠️ Les captures « noir » sont ÉCLAIRCIES pour la planche (×8, légende à l'appui) : noires,
elles ne montreraient rien. Le verdict est le chiffre du banc, jamais l'œil.

Dépendance : Pillow. Police, compression et vignettes : celles de planche_iso.py et
planche_iso1.py.
"""
import argparse
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
from planche_iso import compresser  # noqa: E402
from planche_iso1 import planche  # noqa: E402


def releves_noir(journal):
    """vue → (verdict, px hors support, écran max a, écran max b, lightmap max b, moitiés)."""
    out = {}
    if not journal or not os.path.exists(journal):
        return out
    texte = open(journal, encoding="utf-8", errors="replace").read()
    motif = (r"BANC_ISO noir pate=(\w+) vue=(\w+) verdict=([^(]+)\(a : (-?\d+) pixel\(s\) allumé\(s\) "
             r"hors du support de la brute, écran max (\d+), capteurs (\[[^\]]*\]) ; b : écran (\d+) sur "
             r"lightmap (-?\d+) ; moitiés (\[[^\]]*\])\)")
    for m in re.finditer(motif, texte):
        out[m.group(2)] = (m.group(3).strip(), int(m.group(4)), int(m.group(5)), int(m.group(7)),
                           int(m.group(8)), m.group(9), m.group(6))
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--captures", default=os.path.join(ICI, "captures_iso2"))
    p.add_argument("--journal", default="")
    p.add_argument("--max-ko", type=int, default=450)
    p.add_argument("--max-planche-ko", type=int, default=1400)
    a = p.parse_args()
    c = a.captures

    for nom in sorted(os.listdir(c)):
        if nom.endswith(".png"):
            compresser(os.path.join(c, nom), os.path.join(c, nom), a.max_ko * 1024)

    noir = releves_noir(a.journal)
    cases = []
    for qui, autre in (("j1", "J2"), ("j2", "J1")):
        base = os.path.join(c, "torche_%s" % qui)
        cases.append((base + ".png", "écran scindé iso, torche de %s seule" % qui.upper(),
                      "pâte D · vue de J1 à gauche, de J2 à droite", 1))
        cases.append((base + "_lightmap1.png", "lightmap de J1 (torche de %s)" % qui.upper(),
                      "ce que J1 a le droit de voir : son halo, pas celui de J2", 1))
        cases.append((base + "_lightmap2.png", "lightmap de J2 (torche de %s)" % qui.upper(),
                      "ce que J2 a le droit de voir : son halo, pas celui de J1", 1))
    for vue, titre in (("unique", "vue unique"), ("scinde", "écran scindé")):
        r = noir.get(vue)
        detail = ("%s · a : %d px hors support, capteurs %s" % (r[0], r[1], r[6])) if r else "relevé absent"
        cases.append((os.path.join(c, "noir_%s.png" % vue), "%s, lumières éteintes (×8)" % titre, detail, 8))
    r = noir.get("scinde")
    detail = ("b : écran %d/255, lightmaps %d/255, moitiés %s" % (r[3], r[4], r[5])) if r else "relevé absent"
    cases.append((os.path.join(c, "noir_scinde_lightmap_noire.png"), "écran scindé, lightmaps noires (×8)", detail, 8))

    planche(cases, 3, "ISO2 — chaque vue n'a que ses canaux",
            "Écran scindé iso · pâte D · capteurs de corps · noir absolu des deux vues",
            os.path.join(ICI, "planche_iso2.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
