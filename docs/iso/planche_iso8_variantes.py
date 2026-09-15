#!/usr/bin/env python3
"""Planche d'ISO8, étape 1 : les variantes de la caméra serrée, pour que la session cloud choisisse sur image.

Usage : python3 docs/iso/planche_iso8_variantes.py --captures DIR [--journal FICHIER]

Lit les captures de `tools/banc_claustro.tscn -- --captures DIR` (`<carte>_<vue>_z<zoom>_t<portée>[_a30].png`)
et, si --journal est donné, les lignes `BANC_CLAUSTRO` (taille de lightmap, appels de dessin). Compose
docs/iso/planche_iso8_variantes.jpg, par carte (carte d'essai des murs bas, puis Le Cloître) :

- vue unique, grille zoom (lignes ×1,0 · ×1,5 · ×1,8 · ×2,2) × portée (colonnes torch_scale 1,6 · 1,2 · 1,0) ;
- vue unique, zoom ×1,8, demi-angle 30° (cookie du Fumiste) pour les trois portées ;
- écran scindé, zoom ×1,8, demi-angle 35°, pour les trois portées.

Les autres prises (écran scindé à tous les zooms) restent dans le dossier du banc, pour la galerie.
Le témoin est la première case de chaque grille : zoom ×1,0, portée 1,6, 35°.

Dépendance : Pillow. Mise en page : celle de planche_iso1.py.
"""
import argparse
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
from planche_iso1 import planche  # noqa: E402

CARTES = [("murs_bas", "Carte d'essai des murs bas"), ("cloitre", "Le Cloître")]
ZOOMS = ["1.0", "1.5", "1.8", "2.2"]
TORCHES = ["1.6", "1.2", "1.0"]
PORTEE = {"1.6": 410, "1.2": 307, "1.0": 256}


def virgule(x):
    return x.replace(".", ",")


def releves(journal):
    out = {}
    if not journal or not os.path.exists(journal):
        return out
    for ligne in open(journal, encoding="utf-8", errors="replace"):
        m = re.search(r"BANC_CLAUSTRO .*lightmap=(\d+x\d+) .*appels=(\d+) iso=(\S+) fichier=(\S+)", ligne)
        if m:
            out[m.group(4)] = (m.group(1), m.group(2), m.group(3))
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--captures", required=True)
    p.add_argument("--journal", default="")
    p.add_argument("--max-planche-ko", type=int, default=2800)
    a = p.parse_args()
    r = releves(a.journal)

    def case(nom, titre):
        chemin = os.path.join(a.captures, nom)
        info = r.get(nom)
        detail = ("lightmap %s · %s appels · iso %s" % info) if info else nom
        return (chemin if os.path.exists(chemin) else None, titre, detail, 1)

    cases = []
    for cle, nom_carte in CARTES:
        for z in ZOOMS:
            for t in TORCHES:
                temoin = " (TÉMOIN)" if (z, t) == ("1.0", "1.6") else ""
                cases.append(case("%s_unique_z%s_t%s.png" % (cle, z, t),
                                  "%s · zoom ×%s · portée %s (%d px) · 35°%s"
                                  % (nom_carte, virgule(z), virgule(t), PORTEE[t], temoin)))
        for t in TORCHES:
            cases.append(case("%s_unique_z1.8_t%s_a30.png" % (cle, t),
                              "%s · zoom ×1,8 · portée %s (%d px) · 30° (cookie du Fumiste)"
                              % (nom_carte, virgule(t), PORTEE[t])))
        for t in TORCHES:
            cases.append(case("%s_scinde_z1.8_t%s.png" % (cle, t),
                              "%s · ÉCRAN SCINDÉ · zoom ×1,8 · portée %s (%d px) · 35°"
                              % (nom_carte, virgule(t), PORTEE[t])))
    planche(cases, 3, "CANDELA — ISO8 : LA CAMÉRA SERRÉE, VARIANTES À CHOISIR",
            "iso8-claustro · banc_claustro · lignes : zoom ×1,0 / ×1,5 / ×1,8 / ×2,2, puis 30°, puis écran scindé ·"
            " colonnes : portée 1,6 / 1,2 / 1,0 · 2026-09-15",
            os.path.join(ICI, "planche_iso8_variantes.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
