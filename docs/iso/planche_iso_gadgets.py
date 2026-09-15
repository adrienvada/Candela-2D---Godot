#!/usr/bin/env python3
"""Planches du chantier Gadgets et lumières en iso.

Usage : python3 docs/iso/planche_iso_gadgets.py [--captures DIR] [--journal FICHIER]

Lit les captures de `tools/banc_iso_gadgets.gd` (docs/iso/captures_gadgets/ par défaut) et son journal,
et compose :

- docs/iso/planche_iso_gadgets.jpg : chaque gadget en iso sous la torche de J1 réglée à 0,8 (ligne 1 et 2),
  et le même cadre toutes lumières éteintes, 2D coupée (lignes 3 et 4) — avec la valeur maximale mesurée
  par le banc sous chaque vignette noire ;
- docs/iso/planche_lumieres_hauteur.jpg : la fusée en vol puis posée derrière le muret, la torche derrière le
  même muret (les deux vues), puis la lightmap de J1 pour les trois hauteurs, zone morte attendue et mesurée
  en légende.

⚠️ Les vignettes noires sont affichées telles quelles : un noir absolu tenu est un carré noir. Le verdict est
le chiffre du banc, jamais l'œil.

Dépendance : Pillow.
"""
import argparse
import os
import re

from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
SLUGS = ["mine_magnesium", "ombre_habitee", "torche_fantome", "voile", "gresillement", "leurre",
         "cartouche_suie", "poussiere", "nappe_braises", "poudre_contact"]
FOND = (18, 18, 20)
ENCRE = (235, 228, 210)


def police(taille):
    for chemin in ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc",
                   "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(chemin):
            return ImageFont.truetype(chemin, taille)
    return ImageFont.load_default()


def ouvrir(c, nom, taille):
    chemin = os.path.join(c, nom + ".png")
    if not os.path.exists(chemin):
        im = Image.new("RGB", taille, (60, 20, 20))
        ImageDraw.Draw(im).text((8, 8), "absente", fill=ENCRE, font=police(18))
        return im
    im = Image.open(chemin).convert("RGB")
    im.thumbnail(taille)
    fond = Image.new("RGB", taille, FOND)
    fond.paste(im, ((taille[0] - im.width) // 2, (taille[1] - im.height) // 2))
    return fond


def grille(vignettes, colonnes, titre, fichier):
    w, h = vignettes[0][0].size
    marge, legende, entete = 16, 46, 64
    lignes = (len(vignettes) + colonnes - 1) // colonnes
    planche = Image.new("RGB", (colonnes * (w + marge) + marge, entete + lignes * (h + legende + marge)), FOND)
    d = ImageDraw.Draw(planche)
    d.text((marge, 18), titre, fill=ENCRE, font=police(26))
    for i, (im, texte) in enumerate(vignettes):
        x = marge + (i % colonnes) * (w + marge)
        y = entete + (i // colonnes) * (h + legende + marge)
        planche.paste(im, (x, y))
        for k, ligne in enumerate(texte.split("\n")[:2]):
            d.text((x, y + h + 4 + k * 20), ligne, fill=ENCRE, font=police(16))
    planche.save(fichier, "JPEG", quality=88, optimize=True)
    print("écrit", fichier, planche.size)


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--captures", default=os.path.join(ICI, "captures_gadgets"))
    a.add_argument("--journal", default=os.path.join(ICI, "captures_gadgets", "releves_gadgets.txt"))
    args = a.parse_args()
    c = args.captures
    t = open(args.journal, encoding="utf-8", errors="replace").read() if os.path.exists(args.journal) else ""

    vignettes = []
    for s in SLUGS:
        vignettes.append((ouvrir(c, "gadget_%s_lampe" % s, (320, 320)), "%s\nsous la lampe 0,8" % s))
    for s in SLUGS:
        m = re.search(r"gadget=%s lampe_max=(\d+) noir_lumieres_eteintes=(\d+) noir_sans_2d=(\d+)" % s, t)
        texte = "%s — lumière 0\nécran %s/255 (2D coupée)" % (s, m.group(3) if m else "?")
        vignettes.append((ouvrir(c, "gadget_%s_noir" % s, (320, 320)), texte))
    grille(vignettes, 5, "Gadgets et lumières en iso — chaque gadget sous la lampe, puis dans le noir absolu",
           os.path.join(ICI, "planche_iso_gadgets.jpg"))

    scenes = [
        (ouvrir(c, "scene_fusee_vol", (640, 360)), "fusée en vol à 1,2 tuile au-dessus du muret\nles deux vues"),
        (ouvrir(c, "scene_fusee_sol", (640, 360)), "fusée posée derrière le muret (0,15 : elle bute)\nles deux vues"),
        (ouvrir(c, "scene_torche", (640, 360)), "torche de joueur derrière le même muret\nrègle du jeu (bande constante)"),
    ]
    for h in ["005", "070", "150"]:
        valeur = "%s,%s" % (h[0], h[1:])
        m = re.search(r"hauteur=%s vue=J1 zone_attendue=([^ ]+(?: px \([^)]*\))?) zone_mesuree=([^ ]+(?: px \([^)]*\))?)"
                      % re.escape("%.2f" % (int(h) / 100.0)), t)
        texte = "lightmap de J1, source à %s tuile\nattendue %s, mesurée %s" % (
            valeur, m.group(1) if m else "?", m.group(2) if m else "?")
        scenes.append((ouvrir(c, "hauteur_%s_lightmap_j1" % h, (640, 360)), texte))
    scenes.append((ouvrir(c, "hauteur_070_ecran", (640, 360)), "vue iso, source à 0,70\nles deux vues : la même zone"))
    scenes.append((ouvrir(c, "hauteur_150_ecran", (640, 360)), "vue iso, source à 1,50\nzone plus courte"))
    m = re.search(r"hauteur=0\.70 vue=J2 zone_attendue=([^ ]+(?: px \([^)]*\))?) zone_mesuree=([^ ]+(?: px \([^)]*\))?)", t)
    scenes.append((ouvrir(c, "hauteur_070_lightmap_j2", (640, 360)),
                   "lightmap de J2, source à 0,70\nattendue %s, mesurée %s" % (m.group(1) if m else "?", m.group(2) if m else "?")))
    grille(scenes, 3, "Les lumières ont une hauteur — zone morte derrière un muret à D = 2 tuiles",
           os.path.join(ICI, "planche_lumieres_hauteur.jpg"))


if __name__ == "__main__":
    main()
