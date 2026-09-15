#!/usr/bin/env python3
"""Planche d'ISO8, étape 4 : la caméra serrée, avant et après.

Usage : python3 docs/iso/planche_iso8.py --captures DIR [--journal FICHIER]

Lit les captures de `tools/banc_claustro.tscn -- --avant-apres --captures DIR`
(`<carte>_<vue>_<avant|apres>.png`) et, si --journal est donné, les lignes `BANC_CLAUSTRO avant_apres` (zoom,
décalage, portée, appels de dessin). Compose docs/iso/planche_iso8.jpg : pour Le Cloître (murs hauts) puis la
carte d'essai des murs bas, en vue unique puis en écran scindé, le jeu d'avant ISO8 (zoom ×1,0, aucun décalage,
portée ×1,0) à gauche, les défauts d'ISO8 (zoom ×1,8, décalage 0,25, portée ×0,75) à droite.

Dépendance : Pillow. Mise en page : celle de planche_iso1.py.
"""
import argparse
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
from planche_iso1 import planche  # noqa: E402

CARTES = [("cloitre", "Le Cloître (murs hauts)"), ("murs_bas", "Carte d'essai (murets)")]
VUES = [("unique", "vue unique"), ("scinde", "écran scindé")]
ETATS = [("avant", "AVANT ISO8 : zoom ×1,0 · sans décalage · portée ×1,0"),
         ("apres", "ISO8 : zoom ×1,8 · regard vers la visée · portée ×0,75")]


def releves(journal):
    out = {}
    if not journal or not os.path.exists(journal):
        return out
    for ligne in open(journal, encoding="utf-8", errors="replace"):
        m = re.search(r"BANC_CLAUSTRO avant_apres .*portee_px=(\d+) .*appels=(\d+) fichier=(\S+)", ligne)
        if m:
            out[m.group(3)] = (m.group(1), m.group(2))
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--captures", required=True)
    p.add_argument("--journal", default="")
    p.add_argument("--max-planche-ko", type=int, default=1600)
    a = p.parse_args()
    r = releves(a.journal)
    cases = []
    for cle, nom_carte in CARTES:
        for vue, nom_vue in VUES:
            for etat, titre in ETATS:
                nom = "%s_%s_%s.png" % (cle, vue, etat)
                chemin = os.path.join(a.captures, nom)
                info = r.get(nom)
                detail = ("%s · %s · portée du pistolet %s px · %s appels" % (nom_carte, nom_vue, info[0], info[1])) \
                    if info else "%s · %s" % (nom_carte, nom_vue)
                cases.append((chemin if os.path.exists(chemin) else None, titre, detail, 1))
    planche(cases, 2, "CANDELA — ISO8 : LA CAMÉRA SERRÉE, AVANT ET APRÈS",
            "iso8-claustro · banc_claustro --avant-apres · J1 face à un mur haut à 3,5 tuiles, J2 derrière un mur · 2026-09-15",
            os.path.join(ICI, "planche_iso8.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
