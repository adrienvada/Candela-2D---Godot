#!/usr/bin/env python3
"""Compression des captures du prototype iso et composition de la planche.

Usage : python3 docs/iso/planche_iso.py [--brut DIR] [--sortie DIR] [--max-ko 400]

Lit DIR/manifeste.json (écrit par capturer_iso.mjs), compresse chaque PNG brut vers
docs/iso/captures/<nom>.png sous --max-ko (palette réduite par paliers : les scènes sont
sombres, 256 couleurs suffisent presque toujours), puis compose docs/iso/planche_iso.jpg :
un bandeau de titre et une grille 3×4 de vignettes 640×360 légendées, sous 1,2 Mo.

Dépendance : Pillow (`pip install pillow`). Légendes : une police TTF système si l'une
de celles de POLICES existe (accents garantis), sinon la police embarquée de Pillow.
"""
import argparse
import io
import json
import os
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
PALIERS = (256, 192, 128, 96, 64)
VIGNETTE = (640, 360)
COLONNES, LIGNES = 3, 4
BANDEAU, LEGENDE, MARGE = 64, 26, 6
ENCRE, PAPIER, AMBRE, MUET = (5, 5, 5), (216, 210, 196), (245, 176, 61), (138, 133, 120)


# Une police système avec les accents : la police embarquée de Pillow n'a pas le latin
# étendu (« Arène » y devient « Ar▯ne »). Candidats Linux puis macOS, sinon repli.
POLICES = (
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    "/usr/share/fonts/truetype/freefont/FreeSans.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/Library/Fonts/Arial.ttf",
    "C:/Windows/Fonts/arial.ttf",
)


def police(taille):
    for chemin in POLICES:
        if os.path.exists(chemin):
            try:
                return ImageFont.truetype(chemin, taille)
            except OSError:
                continue
    try:
        return ImageFont.load_default(size=taille)
    except TypeError:  # Pillow < 10.1 : police bitmap, taille fixe
        return ImageFont.load_default()


def compresser(source, cible, max_octets):
    """PNG RGB si assez petit, sinon palette réduite jusqu'à passer sous le seuil."""
    im = Image.open(source).convert("RGB")
    tampon = io.BytesIO()
    im.save(tampon, "PNG", optimize=True)
    meilleur, mode = tampon.getvalue(), "RGB"
    if len(meilleur) > max_octets:
        for couleurs in PALIERS:
            q = im.quantize(colors=couleurs, method=Image.Quantize.MEDIANCUT)
            tampon = io.BytesIO()
            q.save(tampon, "PNG", optimize=True)
            meilleur, mode = tampon.getvalue(), "P%d" % couleurs
            if len(meilleur) <= max_octets:
                break
    with open(cible, "wb") as f:
        f.write(meilleur)
    return len(meilleur), mode


def planche(entrees, cible, max_octets):
    largeur = COLONNES * VIGNETTE[0] + (COLONNES + 1) * MARGE
    hauteur = BANDEAU + LIGNES * (VIGNETTE[1] + LEGENDE + MARGE) + MARGE
    im = Image.new("RGB", (largeur, hauteur), ENCRE)
    d = ImageDraw.Draw(im)
    titre, sous = police(26), police(15)
    d.rectangle([0, 0, largeur, BANDEAU], fill=(10, 10, 10))
    d.rectangle([0, BANDEAU - 2, largeur, BANDEAU], fill=AMBRE)
    d.text((MARGE + 10, 12), "CANDELA — PROTOTYPE ISO 3D", font=titre, fill=(250, 232, 204))
    d.text((MARGE + 10, 42), "Vraies cartes du jeu · Three.js · torche = SpotLight avec ombres · murs 1 tuile · caméra orthographique",
           font=sous, fill=MUET)
    for i, e in enumerate(entrees[: COLONNES * LIGNES]):
        col, lig = i % COLONNES, i // COLONNES
        x = MARGE + col * (VIGNETTE[0] + MARGE)
        y = BANDEAU + MARGE + lig * (VIGNETTE[1] + LEGENDE + MARGE)
        vignette = Image.open(e["fichier"]).convert("RGB").resize(VIGNETTE, Image.LANCZOS)
        im.paste(vignette, (x, y))
        d.rectangle([x, y, x + VIGNETTE[0] - 1, y + VIGNETTE[1] - 1], outline=(43, 42, 39))
        texte = "%02d  %s" % (i + 1, e["legende"])
        while d.textlength(texte, font=sous) > VIGNETTE[0] - 4 and len(texte) > 8:
            texte = texte[:-2].rstrip() + "…"
        d.text((x + 2, y + VIGNETTE[1] + 5), texte, font=sous, fill=PAPIER)
    qualite = 88
    while True:
        tampon = io.BytesIO()
        im.save(tampon, "JPEG", quality=qualite, optimize=True, progressive=True)
        if len(tampon.getvalue()) <= max_octets or qualite <= 40:
            break
        qualite -= 6
    with open(cible, "wb") as f:
        f.write(tampon.getvalue())
    return len(tampon.getvalue()), qualite


def principal():
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--brut", default=os.path.join(tempfile.gettempdir(), "candela_iso_brut"))
    p.add_argument("--sortie", default=os.path.join(ICI, "captures"))
    p.add_argument("--planche", default=os.path.join(ICI, "planche_iso.jpg"))
    p.add_argument("--max-ko", type=int, default=400)
    p.add_argument("--max-planche-ko", type=int, default=1200)
    a = p.parse_args()

    manifeste = os.path.join(a.brut, "manifeste.json")
    if not os.path.exists(manifeste):
        sys.exit("manifeste introuvable : %s (lancer capturer_iso.mjs d'abord)" % manifeste)
    entrees = json.load(open(manifeste, encoding="utf-8"))
    os.makedirs(a.sortie, exist_ok=True)

    for e in entrees:
        cible = os.path.join(a.sortie, e["nom"] + ".png")
        taille, mode = compresser(e["fichier"], cible, a.max_ko * 1000)
        etat = "ok" if taille <= a.max_ko * 1000 else "TROP GROS"
        print("%-34s %4d Ko  %-5s %s" % (e["nom"] + ".png", taille // 1000, mode, etat))

    taille, qualite = planche(entrees, a.planche, a.max_planche_ko * 1000)
    print("%-34s %4d Ko  q=%d %s" % (os.path.basename(a.planche), taille // 1000, qualite,
                                      "ok" if taille <= a.max_planche_ko * 1000 else "TROP GROS"))


if __name__ == "__main__":
    principal()
