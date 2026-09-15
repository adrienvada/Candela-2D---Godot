#!/usr/bin/env python3
"""Planche finale de la vague « grand budget » : le duel iso avec tout, tel qu'il se joue.

Usage : python3 docs/iso/planche_finale.py --photos DIR --gadgets DIR [--photos-cloitre DIR]

- --photos : le dossier de `./tools/run_photos.sh --famille=menus,jeu,fins --sortie=DIR`, lancé SANS
  drapeau (manifeste `mode_rendu` = `iso`, refusé sinon) ;
- --photos-cloitre : le même, relancé avec `--carte-duel=res://assets/maps/map_001_le_cloitre.json` (les plans
  du duel au Cloître, murs hauts intérieurs) ;
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
## Séquence de fin (session cloud, 14:39) : la planche finale se fait AUSSI sur Le Cloître, la carte livrée
## aux murs hauts intérieurs — le photographe relancé avec `--carte-duel=res://assets/maps/map_001_le_cloitre.json`.
PHOTOS_CLOITRE = [
    ("jeu/06-hud.png", "Le duel au Cloître", "J1 face à un mur haut intérieur, J2 caché derrière · zoom ×1,8 · HUD"),
    ("jeu/10-volume.png", "Le volume d'un mur du Cloître", "même scène, torche rasante le long de la face"),
    ("jeu/17-fusee.png", "La fusée au Cloître", "sa lueur sur les faces des murs hauts"),
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
## Séquence de fin d'ISO10 (session cloud, 19:53) : les cases d'ISO10, recadrages 800×450 à la fenêtre native au Cloître
## (`--famille=loupe`, voir tools/loupe.gd), et la bande de rampe du voile, cinq niveaux au cadrage du corps de J1.
LOUPES_ISO10 = [
    ("loupe-pilier", "La face d'un pilier (ISO10, 1b)", "lavis au pied, matière de la face · loupe 1:1"),
    ("loupe-sol", "Le sol et une tache (1b)", "fissures et pores en gris moyen, sang à paliers · loupe 1:1"),
    ("loupe-corps-j1", "Le corps de J1 (1d)", "MSAA 3D ×4, ombre de contact · loupe 1:1"),
    ("loupe-fusee-suie", "La fusée posée et la suie (1c)", "plus d'anneaux, lueur rouge en mélange, suie ambre · loupe 1:1"),
    ("loupe-face-sang-peinture", "Une face au-dessus du sang (1f)", "la face lit la lumière, pas le sol peint · loupe 1:1"),
]
RAMPE = [("loupe-rampe-%s" % n, "Le voile à %s" % v, "rampe de l'aberration, corps de J1 éclairé · loupe 1:1")
         for n, v in (("012", "0,12"), ("020", "0,2"), ("035", "0,35"), ("060", "0,6"), ("100", "1,0"))]


def loupes(dossier, entrees):
    """Les PNG de loupe d'une séance du photographe, par identifiant (manifeste), recopiés TELS QUELS."""
    m = json.load(open(os.path.join(dossier, "manifeste.json"), encoding="utf-8"))
    par_id = {f["id"]: f for f in m["photos"] if f.get("famille") == "loupe"}
    dest = os.path.join(ICI, "captures_finale")
    out = []
    for ident, titre, detail in entrees:
        fiche = par_id.get(ident)
        if fiche is None:
            out.append((None, titre, detail, 1))
            continue
        fichier = fiche["fichier"]
        source = fichier if os.path.isabs(fichier) else os.path.join(dossier, fichier)
        cible = os.path.join(dest, ident + ".png")
        shutil.copyfile(source, cible)
        out.append((cible, titre, detail, 1))
    return out


def copier(source, dest, max_ko):
    cible = os.path.join(dest, os.path.basename(os.path.dirname(source)) + "_" + os.path.basename(source))
    shutil.copyfile(source, cible)
    compresser(cible, cible, max_ko * 1024)
    return cible


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--photos", required=True)
    p.add_argument("--gadgets", required=True)
    p.add_argument("--photos-cloitre", default="")
    p.add_argument("--loupe", default="", help="séance --famille=loupe au Cloître : cases d'ISO10 et bande de rampe")
    p.add_argument("--tete", default="", help="le commit de la tête fusionnée, pour le sous-titre")
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
    if a.photos_cloitre:
        manifeste_c = json.load(open(os.path.join(a.photos_cloitre, "manifeste.json"), encoding="utf-8"))
        if manifeste_c.get("mode_rendu") != "iso":
            sys.exit("✗ manifeste du Cloître mode_rendu=%s" % manifeste_c.get("mode_rendu"))
        for rel, titre, detail in PHOTOS_CLOITRE:
            source = os.path.join(a.photos_cloitre, rel)
            cible = os.path.join(dest, "cloitre_" + rel.replace("/", "_"))
            if os.path.exists(source):
                shutil.copyfile(source, cible)
                compresser(cible, cible, a.max_ko * 1024)
                cases.append((cible, titre, detail, 1))
            else:
                cases.append((None, titre, detail, 1))
    for nom, titre, detail in GADGETS:
        source = os.path.join(a.gadgets, nom)
        cases.append((copier(source, dest, a.max_ko) if os.path.exists(source) else None, titre, detail, 1))
    for rel, titre, detail in FINS:
        cases.append((copier(os.path.join(a.photos, rel), dest, a.max_ko), titre, detail, 1))
    if a.loupe:
        cases.extend(loupes(a.loupe, LOUPES_ISO10))
        cases.extend(loupes(a.loupe, RAMPE))
    ref, titre, detail = REFERENCE
    cases.append((os.path.join(ICI, ref), titre, detail, 1))
    planche(cases, 3, "CANDELA — LE DUEL EN VUE ISOMÉTRIQUE, VAGUE « GRAND BUDGET » ET FINITION ISO10",
            "iso2-vues @ %s · photographe sans drapeau (mode_rendu=iso), murs bas et Cloître · banc des gadgets · cases d'ISO10 et rampe du voile, loupes 1:1 · 2026-09-15"
            % (a.tete or manifeste.get("commit", "?")),
            os.path.join(ICI, "planche_finale.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
