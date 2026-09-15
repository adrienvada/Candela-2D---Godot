#!/usr/bin/env python3
"""Planche finale de la vague « grand budget » : le duel iso avec tout, tel qu'il se joue.

Usage : python3 docs/iso/planche_finale.py --photos DIR --gadgets DIR

- --photos : le dossier de `./tools/run_photos.sh --famille=menus,jeu,fins --sortie=DIR`, lancé SANS
  drapeau (manifeste `mode_rendu` = `iso`, refusé sinon) ;
- --gadgets : le dossier de `tools/banc_iso_gadgets.tscn -- --captures DIR`, pris APRÈS les quatre
  fusions (murs et sol texturés d'ISO7, encre des corps de la vague 5, volumes et lueurs de Gadgets).

Compose docs/iso/planche_finale.jpg : les deux vues (vue unique HUD compris, écran scindé), la fusée en vol
par-dessus un muret, les fumées (suie, poussière) sous la lampe, la fusée au sol, l'éblouissement, la
killcam, le gel signé et l'affiche de fin — l'habillage dans la pâte —, et la planche des corps v5 d'ISO
Corps en référence. Les images retenues sont recopiées, compressées, dans docs/iso/captures_finale/.

Dépendance : Pillow. Mise en page : celle de planche_iso1.py.
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

PHOTOS = [
    ("jeu/06-hud.png", "Le duel, vue unique", "carte d'essai des murs bas · J1 face au mur haut, J2 derrière un muret · HUD"),
    ("jeu/10-volume.png", "Le volume du mur", "même scène, torche rasante le long du mur"),
    ("jeu/02-ecran-scinde.png", "L'écran scindé", "deux caméras iso, deux lightmaps, le halo propre à chaque vue"),
]
GADGETS = [
    ("scene_fusee_vol.png", "La fusée en vol par-dessus un muret", "carte d'essai des murs bas · la lueur a une hauteur"),
    ("gadget_cartouche_suie_lampe.png", "La cartouche de suie", "volume iso sous la lampe, chaleur de la lumière"),
    ("gadget_poussiere_lampe.png", "La poussière", "volume iso sous la lampe"),
    ("scene_fusee_sol.png", "La fusée posée derrière le muret", "ce que le muret lui cache"),
]
FINS = [
    ("jeu/17-fusee.png", "La fusée éclairante, en match", "sa lueur projetée sur le mur et le sol"),
    ("jeu/16-eblouissement.png", "L'éblouissement", "le voile tel que le jeu le peint"),
    ("fins/03-killcam.png", "La killcam", "le rejeu dans la vue iso, fantômes alignés sur la 2D"),
    ("fins/04-gel-fatal.png", "Le gel signé", "l'estampe à l'encre"),
    ("fins/05-affiche.png", "L'affiche de fin", "le verdict dans la pâte"),
]
REFERENCE = ("planche_corps_v5.png", "Les dix corps v5 (ISO Corps)", "référence : le gabarit du DA")


def copier(source, dest, max_ko):
    cible = os.path.join(dest, os.path.basename(os.path.dirname(source)) + "_" + os.path.basename(source))
    shutil.copyfile(source, cible)
    compresser(cible, cible, max_ko * 1024)
    return cible


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--photos", required=True)
    p.add_argument("--gadgets", required=True)
    p.add_argument("--max-ko", type=int, default=450)
    p.add_argument("--max-planche-ko", type=int, default=1800)
    a = p.parse_args()

    manifeste = json.load(open(os.path.join(a.photos, "manifeste.json"), encoding="utf-8"))
    if manifeste.get("mode_rendu") != "iso":
        sys.exit("✗ manifeste mode_rendu=%s : ces photos ne sont pas le jeu par défaut" % manifeste.get("mode_rendu"))

    dest = os.path.join(ICI, "captures_finale")
    os.makedirs(dest, exist_ok=True)
    cases = []
    for rel, titre, detail in PHOTOS:
        cases.append((copier(os.path.join(a.photos, rel), dest, a.max_ko), titre, detail, 1))
    for nom, titre, detail in GADGETS:
        source = os.path.join(a.gadgets, nom)
        cases.append((copier(source, dest, a.max_ko) if os.path.exists(source) else None, titre, detail, 1))
    for rel, titre, detail in FINS:
        cases.append((copier(os.path.join(a.photos, rel), dest, a.max_ko), titre, detail, 1))
    ref, titre, detail = REFERENCE
    cases.append((os.path.join(ICI, ref), titre, detail, 1))
    planche(cases, 3, "CANDELA — LE DUEL EN VUE ISOMÉTRIQUE, VAGUE « GRAND BUDGET »",
            "iso2-vues @ %s · photographe sans drapeau (mode_rendu=iso) · banc des gadgets après les quatre fusions · 2026-09-15"
            % manifeste.get("commit", "?"),
            os.path.join(ICI, "planche_finale.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
