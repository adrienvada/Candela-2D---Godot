#!/usr/bin/env python3
"""Planche d'ISO4 : les objets debout, le leurre, la balle, le viseur et la ligne de visée dans la vue iso.

Usage : python3 docs/iso/planche_iso4.py [--captures DIR] [--journal FICHIER]

Lit les captures de `tools/banc_iso.gd` (commandes dans la ROADMAP, section ISO4) rangées dans
docs/iso/captures_iso4/, et le journal des bancs, et compose docs/iso/planche_iso4.jpg :

- lignes 1 et 2 : chaque objet de la vague 3 posé au contact devant J2, du côté de la caméra de J1, son
  voxel montré — gros plan sur la zone du corps, verdict « tête et torse intacts » en légende ;
- ligne 3 : le leurre (information), un tir en écran scindé iso (balle, viseur et ligne de visée en quads
  au sol), et le noir absolu de l'écran scindé avec les miroirs (×8).

⚠️ La capture « noir » est ÉCLAIRCIE pour la planche (×8, légende à l'appui). Le verdict est le chiffre
du banc, jamais l'œil.

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

OBJETS = ("mine", "torche_fantome", "voile", "ombre", "gresillement", "fusee")


def lire(journal):
    if not journal or not os.path.exists(journal):
        return ""
    return open(journal, encoding="utf-8", errors="replace").read()


def gros_plan(c, slug, ligne):
    """Recadre la capture d'un objet sur la zone du corps de J2 relevée par le banc, avec de la marge."""
    source = os.path.join(c, "objets_objet_%s.png" % slug)
    cible = os.path.join(c, "gros_plan_%s.png" % slug)
    m = re.search(r"zone=(\d+),(\d+),(\d+),(\d+)", ligne or "")
    if not os.path.exists(source) or not m:
        return source
    x, y, w, h = (int(v) for v in m.groups())
    im = Image.open(source).convert("RGB")
    marge = max(w, h)
    boite = (max(0, x - marge), max(0, y - marge // 2), min(im.width, x + w + marge), min(im.height, y + h + marge))
    im.crop(boite).save(cible)
    return cible


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--captures", default=os.path.join(ICI, "captures_iso4"))
    p.add_argument("--journal", default="")
    p.add_argument("--max-ko", type=int, default=450)
    p.add_argument("--max-planche-ko", type=int, default=1400)
    a = p.parse_args()
    c = a.captures
    t = lire(a.journal)
    cases = []
    for slug in OBJETS + ("leurre",):
        ligne = next((l for l in t.split("\n") if "BANC_ISO objet slug=%s " % slug in l), "")
        v = re.search(r"ecart=(\d+) pixels_changes=(\d+)/(\d+) eclaire=(\w+) verdict=(.+)$", ligne)
        legende = ("tête et torse : écart %s ; %s pixels changés sur %s — %s" % (v.group(1), v.group(2), v.group(3), v.group(5))) \
            if v else "relevé absent"
        titre = "le leurre devant J2 (un corps : information)" if slug == "leurre" else "%s posé devant J2" % slug.replace("_", " ")
        cases.append((gros_plan(c, slug, ligne), titre, legende, 1))
    for nom in sorted(os.listdir(c)):
        if nom.endswith(".png"):
            compresser(os.path.join(c, nom), os.path.join(c, nom), a.max_ko * 1024)
    cases.append((os.path.join(c, "tir.png"), "écran scindé iso, J1 tire",
                  "balle, viseur et ligne de visée en quads au sol", 1))
    noir = re.search(r"BANC_ISO noir pate=\w+ vue=scinde verdict=([^(]+)", t)
    cases.append((os.path.join(c, "noir_scinde.png"), "écran scindé, lumières éteintes (×8)",
                  noir.group(1).strip() if noir else "relevé absent", 8))
    planche(cases, 3, "ISO4 — les objets debout dans la vue iso",
            "Voxels des gadgets sous capteurs · leurre au corps de sa classe · balle, viseur et ligne de visée au sol",
            os.path.join(ICI, "planche_iso4.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
