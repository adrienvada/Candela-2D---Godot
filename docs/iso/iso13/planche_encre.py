#!/usr/bin/env python3
"""Planche ISO13, lot B — l'encre en essai, à côté de l'illustration de l'entraînement : le même instant sous la torche de J1,
aujourd'hui contre l'encre (mannequin, hachures dans la pénombre, arêtes des murs épaisses), en gris puis en V3 froide ;
un grand cadre 1:1 autour de J2 et de la face du mur, puis la loupe ×3 sur J2.

Usage : planche_encre.py <sortie.jpg> <dépôt> <captures_encre_<classe>>
"""
import json, re, sys
from PIL import Image, ImageDraw, ImageFont

LIGNE = re.compile(r"BANC_LUMIERE3D tenue cadrage=(\S+) tenue=(\S+) camera=(-?\d+),(-?\d+) fichier=(\S+) ancres=(\{.*\})$")
FOND, TEXTE, SOURD, AMBRE = (12, 12, 12), (225, 215, 195), (150, 140, 125), (230, 160, 70)
COLONNES = [("", "aujourd'hui"), ("_c1", "contour 1 px"), ("_c2", "contour 2 px"), ("_c2h", "contour 2 px + hachures")]
RANGEES = [("gris", "gris"), ("sombre3_froide", "V3 froide")]
LW, LH = 460, 300
DEMI, G = 34, 3


def police(t):
    for c in ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try:
            return ImageFont.truetype(c, t)
        except OSError:
            pass
    return ImageFont.load_default()


def main(a):
    sortie, depot, dossier = a[0], a[1], a[2]
    prises = {}
    for l in open(dossier + "/journal.log", encoding="utf-8", errors="replace"):
        m = LIGNE.search(l.strip())
        if m:
            prises[(m.group(1), m.group(2))] = (m.group(5), json.loads(m.group(6)), (int(m.group(3)), int(m.group(4))))
    marge = 14
    largeur = marge * 5 + 4 * LW
    ill = Image.open("%s/assets/ui/ill_entrainement.png" % depot).convert("RGB")
    ill = ill.resize((largeur - 2 * marge, int(ill.height * (largeur - 2 * marge) / ill.width)), Image.LANCZOS)
    hauteur = 90 + ill.height + 40 + 2 * (LH + 30) + 10 * (2 * DEMI * G + 40) + 40
    planche = Image.new("RGB", (largeur, hauteur), FOND)
    d = ImageDraw.Draw(planche)
    d.text((marge, 12), "ISO13 · l'encre en essai — contour, arêtes, hachures dans la pénombre", fill=AMBRE, font=police(28))
    d.text((marge, 50), "la 2D du jeu, Le Cloître, 1920×1080, bandeau de LED coupé, sous la torche de J1 ; mêmes instants deux à deux ; "
           "cadres 1:1, loupes ×3 sans lissage", fill=TEXTE, font=police(15))
    planche.paste(ill, (marge, 80))
    d.text((marge, 84 + ill.height), "illustration de l'entraînement", fill=SOURD, font=police(13))
    y = 80 + ill.height + 30
    cams = set()
    for base, lib_r in RANGEES:
        for c, (suffixe, lib_c) in enumerate(COLONNES):
            t, nom = base + suffixe, "%s · %s" % (lib_r, lib_c)
            p = prises[("tenues_torche", t)]
            cams.add(p[2])
            im = Image.open("%s/%s" % (dossier, p[0])).convert("RGB")
            x0, y0 = p[1]["j2"]
            cadre = im.crop((x0 - LW // 2, y0 - LH // 2 - 40, x0 + LW // 2, y0 + LH // 2 - 40))
            xx = marge + c * (LW + marge)
            d.text((xx, y), nom, fill=SOURD, font=police(13))
            planche.paste(cadre, (xx, y + 18))
        y += LH + 30
    for (cad, nom), (base, lib_r) in [(c, r) for r in RANGEES for c in [("tenues_torche", "de face"), ("tenues_torche_dos", "de dos")]]:
        d.text((marge, y), "J2 %s, %s — aujourd'hui, contour 1 px, contour 2 px, contour 2 px + hachures" % (nom, lib_r), fill=TEXTE, font=police(14))
        y += 18
        for k, (suffixe, lib) in enumerate(COLONNES):
            p = prises[(cad, base + suffixe)]
            cams.add(p[2])
            im = Image.open("%s/%s" % (dossier, p[0])).convert("RGB")
            x0, y0 = p[1]["j2"]
            loupe = im.crop((x0 - DEMI, y0 - DEMI, x0 + DEMI, y0 + DEMI)).resize((2 * DEMI * G, 2 * DEMI * G), Image.NEAREST)
            planche.paste(loupe, (marge + k * (2 * DEMI * G + 8), y))
        y += 2 * DEMI * G + 22
    # Trois loupes de plus, là où l'encre se voit : J1 (le joueur local, sur le sol que sa rétrodiffusion éclaire — le contour
    # s'y détache ; J2 se tient dans l'ombre de son propre corps, où un liseré noir ne se voit pas), le sol dans la pénombre
    # du bras gauche du cône, la face du mur au-dessus de J2. Décalages relatifs à J2, lus sur les captures de ce cadrage.
    for base, lib_r in RANGEES:
        for cle, lib, dx, dy in [("j1", "J1, sol éclairé", 0, 0), ("j2", "sol dans la pénombre du cône", -190, -150),
                                 ("j2", "face du mur", 80, -95)]:
            d.text((marge, y), "%s, %s — aujourd'hui, contour 1 px, contour 2 px, contour 2 px + hachures" % (lib, lib_r), fill=TEXTE, font=police(14))
            y += 18
            for k, (suffixe, _) in enumerate(COLONNES):
                p = prises[("tenues_torche", base + suffixe)]
                im = Image.open("%s/%s" % (dossier, p[0])).convert("RGB")
                x0, y0 = p[1][cle]
                x0 += dx; y0 += dy
                loupe = im.crop((x0 - DEMI, y0 - DEMI, x0 + DEMI, y0 + DEMI)).resize((2 * DEMI * G, 2 * DEMI * G), Image.NEAREST)
                planche.paste(loupe, (marge + k * (2 * DEMI * G + 8), y))
            y += 2 * DEMI * G + 22
    if len(cams) > 1:
        raise SystemExit("la caméra a bougé : %s" % cams)
    planche = planche.crop((0, 0, largeur, y + 10))
    planche.save(sortie, "JPEG", quality=90)
    print("planche %dx%d → %s" % (planche.width, planche.height, sortie))


if __name__ == "__main__":
    main(sys.argv[1:])
