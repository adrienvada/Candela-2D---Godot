#!/usr/bin/env python3
"""La planche de loupe : chaque recadrage 1:1 du jeu à côté de la planche du DA qui lui répond.

Ordre 40 de la session cloud (pas 4 bis de la séquence de fin, 2026-09-15), méthode du brief
briefs/iso10_finition.md : le verdict se prend loupe par loupe, sur ces images.

Usage :
  python3 docs/iso/planche_loupe.py --photos DIR [--fluidite DIR] --da RACINE

- --photos : le dossier de `./tools/run_photos.sh --famille=loupe --taille=2560x1440 --sortie=DIR` ;
- --fluidite : le dossier de la séance `--plan=loupe-fluidite` lancée sous `--fixed-fps 60` (voir
  tools/loupe.gd) ; à défaut, la bande est absente ;
- --da : la racine du worktree d'« ISO Assets Sonnet », où vivent les planches Gemini du DA.

Écrit :
- docs/iso/loupe/<identifiant>.png : chaque loupe, recopiée TELLE QUELLE (PNG, 800×450, aucun redimensionnement) ;
- docs/iso/loupe/fluidite_bande.jpg : les trente images réduites en planche contact ;
- docs/iso/planche_loupe.jpg : les loupes à 1:1 à gauche, la planche du DA réduite à droite.

La planche est un JPEG de qualité 95 : les loupes PNG de docs/iso/loupe/ font foi pour juger le pixel.
Dépendance : Pillow.
"""
import argparse
import json
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
LOUPE = (800, 450)
MARGE = 16
LEGENDE = 38
FOND = (18, 18, 18)
TEXTE = (235, 225, 205)
GRIS = (150, 145, 135)

GEMINI = "docs/iso/planches_gemini"
## Loupe → planches du DA, chemins relatifs à --da. La frise et la fumée existent en plusieurs planches :
## la plus proche du cadrage (consigne de la session cloud, 15:36). E1 et E3 : la variante en pleine
## taille (`assets/sources/iso/`) plutôt que la planche contact où elle est réduite.
DA = {
    "loupe-pilier": [GEMINI + "/textures/face_mur_01.jpg"],
    "loupe-sol": [GEMINI + "/textures/sol_01.jpg"],
    "loupe-corps-j1": [GEMINI + "/classes/frise_1_a_5.jpg"],
    "loupe-corps-j2": [GEMINI + "/classes/frise_1_a_5.jpg"],
    "loupe-bord-cone": ["assets/sources/iso/E1_promesse_02.jpg"],
    "loupe-ombre": ["assets/sources/iso/E1_promesse_02.jpg"],
    "loupe-hud-hud": [],
    "loupe-hud-viseur": [],
    "loupe-led": ["assets/sources/iso/E1_promesse_02.jpg"],
    "loupe-balle-vol": ["assets/sources/iso/E3_flash_pro.jpg"],
    "loupe-balle-impact": ["assets/sources/iso/E3_flash_pro.jpg"],
    "loupe-fusee-suie": [GEMINI + "/objets/fusee_posee_01.jpg", GEMINI + "/effets/fumee_03.png"],
    "loupe-torche-fantome": ["assets/ui/icones/gadget_torche_fantome.png"],
    "loupe-scinde-pilier": [GEMINI + "/textures/face_mur_01.jpg"],
    "loupe-scinde-corps-j1": [GEMINI + "/classes/frise_1_a_5.jpg"],
    "loupe-scinde-corps-j2": [GEMINI + "/classes/frise_1_a_5.jpg"],
    "loupe-scinde-bord-cone": ["assets/sources/iso/E1_promesse_02.jpg"],
}
ORDRE = list(DA.keys())


def police(taille):
    for chemin in ("/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc",
                   "/Library/Fonts/Arial.ttf"):
        if os.path.exists(chemin):
            return ImageFont.truetype(chemin, taille)
    return ImageFont.load_default()


def manifeste(dossier):
    with open(os.path.join(dossier, "manifeste.json"), encoding="utf-8") as f:
        return json.load(f)


def chemin_photo(dossier, fiche):
    fichier = fiche["fichier"]
    return fichier if os.path.isabs(fichier) else os.path.join(dossier, fichier)


def ajuster(im, boite):
    """L'image réduite (jamais agrandie) pour tenir dans `boite`, rapport gardé."""
    k = min(boite[0] / im.width, boite[1] / im.height, 1.0)
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--photos", required=True)
    p.add_argument("--fluidite", default="")
    p.add_argument("--da", required=True)
    a = p.parse_args()

    m = manifeste(a.photos)
    loupes = {f["id"]: f for f in m["photos"] if f.get("famille") == "loupe"}
    manquantes = [i for i in ORDRE if i not in loupes]
    if manquantes:
        print("⚠ loupes absentes de la séance : " + ", ".join(manquantes))

    dest = os.path.join(ICI, "loupe")
    os.makedirs(dest, exist_ok=True)
    rangs = [i for i in ORDRE if i in loupes]
    for i in rangs:
        source = chemin_photo(a.photos, loupes[i])
        im = Image.open(source)
        if im.size != LOUPE:
            sys.exit("✗ %s fait %dx%d, pas %dx%d : ce n'est plus une loupe" % (i, im.width, im.height, *LOUPE))
        shutil.copyfile(source, os.path.join(dest, i + ".png"))

    bande, note_bande = None, ""
    if a.fluidite:
        mf = manifeste(a.fluidite)
        images = sorted((f for f in mf["photos"] if f["id"].startswith("loupe-fluidite-")), key=lambda f: f["id"])
        if images:
            note_bande = next((f.get("note", "") for f in images if f.get("note")), "")
            cols, vignette = 6, (400, 225)
            lignes = (len(images) + cols - 1) // cols
            bande = Image.new("RGB", (cols * vignette[0] + (cols + 1) * 6, lignes * vignette[1] + (lignes + 1) * 6), FOND)
            for k, f in enumerate(images):
                v = Image.open(chemin_photo(a.fluidite, f)).convert("RGB").resize(vignette, Image.LANCZOS)
                bande.paste(v, (6 + (k % cols) * (vignette[0] + 6), 6 + (k // cols) * (vignette[1] + 6)))
            bande.save(os.path.join(dest, "fluidite_bande.jpg"), quality=92, optimize=True)

    largeur = MARGE * 3 + LOUPE[0] * 2
    hauteur = 96 + len(rangs) * (LEGENDE + LOUPE[1] + MARGE)
    bande_planche = None
    if bande is not None:
        bande_planche = ajuster(bande, (largeur - 2 * MARGE, 10000))
        hauteur += LEGENDE + bande_planche.height + MARGE
    planche = Image.new("RGB", (largeur, hauteur), FOND)
    d = ImageDraw.Draw(planche)
    titre, petit = police(30), police(18)
    d.text((MARGE, 16), "CANDELA — LA LOUPE : LE JEU À 1:1 CONTRE LES PLANCHES DU DA", font=titre, fill=(232, 170, 80))
    d.text((MARGE, 56), "iso2-vues @ %s + l'outil de loupe · fenêtre %s · recadrages 800×450 sans redimensionnement · "
           "à gauche le jeu, à droite le DA" % (m.get("commit", "?"), m.get("taille_demandee", "?")), font=petit, fill=GRIS)
    y = 96
    for i in rangs:
        f = loupes[i]
        d.text((MARGE, y + 8), "%s — %s" % (i, f.get("titre", "")), font=petit, fill=TEXTE)
        y += LEGENDE
        planche.paste(Image.open(os.path.join(dest, i + ".png")).convert("RGB"), (MARGE, y))
        refs = [r for r in DA.get(i, []) if os.path.exists(os.path.join(a.da, r))]
        x0 = MARGE * 2 + LOUPE[0]
        if not refs:
            d.text((x0 + 12, y + 12), "aucune planche du DA pour ce cadrage", font=petit, fill=GRIS)
        else:
            boite = (LOUPE[0] // len(refs) - (8 if len(refs) > 1 else 0), LOUPE[1] - 26)
            for k, r in enumerate(refs):
                ref = ajuster(Image.open(os.path.join(a.da, r)).convert("RGB"), boite)
                planche.paste(ref, (x0 + k * (boite[0] + 8), y))
                d.text((x0 + k * (boite[0] + 8), y + LOUPE[1] - 22), os.path.basename(r), font=petit, fill=GRIS)
        y += LOUPE[1] + MARGE
    if bande_planche is not None:
        d.text((MARGE, y + 8), "loupe-fluidite — trente images consécutives à 60 Hz · " + note_bande, font=petit, fill=TEXTE)
        y += LEGENDE
        planche.paste(bande_planche, (MARGE, y))
    sortie = os.path.join(ICI, "planche_loupe.jpg")
    planche.save(sortie, quality=95, optimize=True)
    print("planche %s : %dx%d, %d Ko, %d loupe(s)%s" % (sortie, planche.width, planche.height,
          os.path.getsize(sortie) // 1024, len(rangs), ", bande de fluidité" if bande is not None else ""))


if __name__ == "__main__":
    main()
