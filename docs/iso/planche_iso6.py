#!/usr/bin/env python3
"""Planche d'ISO6 : le jeu tel qu'il s'ouvre, en iso par défaut, et le fantôme de killcam aligné.

Usage : python3 docs/iso/planche_iso6.py --photos DIR --banc DIR

- --photos : le dossier écrit par `./tools/run_photos.sh --famille=menus,jeu,fins --sortie=DIR`, lancé
  SANS drapeau (l'iso est le défaut ; le manifeste doit dire « mode_rendu »: « iso ») ;
- --banc : le dossier des captures de `tools/banc_iso.gd --jeu --scinde --killcam --vue j1 --capture
  DIR/killcam_j1.png`.

Les images retenues sont recopiées, compressées, dans docs/iso/captures_iso6/, puis composées dans
docs/iso/planche_iso6.jpg. Le verdict du fantôme est le chiffre du banc (ROADMAP, section ISO6), jamais
l'œil : la vignette « lumières éteintes » est éclaircie ×4 pour se lire.

Dépendance : Pillow. Police et compression : celles de planche_iso.py.
"""
import argparse
import json
import os
import shutil
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
from planche_iso1 import planche  # noqa: E402
from planche_iso import compresser  # noqa: E402

PLANS = [
    ("menus/02-accueil.png", "L'accueil", "le jeu s'ouvre sur ses menus, inchangés"),
    ("jeu/01-decompte.png", "Le décompte", "la première image du duel : l'iso, sans drapeau"),
    ("jeu/06-hud.png", "Le duel, HUD compris", "vue unique · pâte D · corps voxel · murs en relief"),
    ("jeu/02-ecran-scinde.png", "L'écran scindé", "deux caméras iso, deux lightmaps"),
    ("jeu/05-duel.png", "Source « vue » du photographe", "la caméra iso de J1, interface cachée"),
    ("fins/03-killcam.png", "La killcam", "le rejeu dans la vue iso"),
]
BANC = [
    ("killcam_j1_noir.png", "Killcam, lumières éteintes (×4)", "fantômes iso 21/27/31 et 31/21/21 · 2D 22/29/30 et 31/23/22", 4),
    ("killcam_j1_vue_de_dessus.png", "Le même instant en vue de dessus (--2d)", "l'étalon du fantôme 2D", 1),
]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--photos", required=True)
    p.add_argument("--banc", required=True)
    p.add_argument("--max-ko", type=int, default=450)
    p.add_argument("--max-planche-ko", type=int, default=1400)
    a = p.parse_args()

    manifeste = json.load(open(os.path.join(a.photos, "manifeste.json"), encoding="utf-8"))
    rendu = manifeste.get("mode_rendu", "?")
    if rendu != "iso":
        sys.exit("✗ le manifeste dit mode_rendu=%s : ces photos ne sont pas celles du jeu par défaut" % rendu)

    dest = os.path.join(ICI, "captures_iso6")
    os.makedirs(dest, exist_ok=True)
    cases = []
    for rel, titre, detail in PLANS:
        cible = os.path.join(dest, rel.replace("/", "_"))
        shutil.copyfile(os.path.join(a.photos, rel), cible)
        compresser(cible, cible, a.max_ko * 1024)
        cases.append((cible, titre, detail, 1))
    for nom, titre, detail, eclaircir in BANC:
        cible = os.path.join(dest, nom)
        shutil.copyfile(os.path.join(a.banc, nom), cible)
        compresser(cible, cible, a.max_ko * 1024)
        cases.append((cible, titre, detail, eclaircir))
    planche(cases, 2, "CANDELA — ISO6 : LE JEU TEL QU'IL S'OUVRE, EN ISO PAR DÉFAUT",
            "Photographe sans drapeau (manifeste : mode_rendu=%s, commit %s) · banc killcam --vue j1 · 2026-09-15"
            % (rendu, manifeste.get("commit", "?")),
            os.path.join(ICI, "planche_iso6.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
