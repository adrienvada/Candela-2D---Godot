#!/usr/bin/env python3
"""Planche ISO13, lot A — le mannequin : J2 sous la torche de J1, de face et de dos, AVANT et APRÈS (gris, puis V3 froide), en
loupe 1:1 et agrandie ×3 sans lissage, à côté des illustrations de l'accueil et de l'écran scindé.

Usage : planche_mannequin.py <sortie.jpg> <dépôt> <captures_mannequin_<classe>>...
"""
import json, re, sys
from PIL import Image, ImageDraw, ImageFont

COLS = [("gris", "gris · avant"), ("gris_mannequin", "gris · après"), ("sombre3_froide", "V3 froide · avant"),
        ("sombre3_froide_mannequin", "V3 froide · après")]
LIB = {"pistolet": "Le Parasite", "arbalete": "Le Braconnier", "incendiaire": "L'Incendiaire", "fusil": "L'Illusionniste",
       "pompe": "Le Terrassier", "fumiste": "Le Fumiste", "sentinelle": "La Sentinelle", "occulteur": "L'Occulteur",
       "allumeur": "L'Allumeur", "spectre": "Le Spectre"}
DEMI = 34
FOND, TEXTE, SOURD, AMBRE = (12, 12, 12), (225, 215, 195), (150, 140, 125), (230, 160, 70)
LIGNE = re.compile(r"BANC_LUMIERE3D tenue cadrage=(\S+) tenue=(\S+) camera=(-?\d+),(-?\d+) fichier=(\S+) ancres=(\{.*\})$")


def police(t):
    for c in ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try:
            return ImageFont.truetype(c, t)
        except OSError:
            pass
    return ImageFont.load_default()


def main(a):
    if len(a) < 3:
        print(__doc__); return 2
    sortie, depot, dossiers = a[0], a[1], a[2:]
    marge, gauche, g = 14, 90, 3
    case = 2 * DEMI * g
    largeur = marge * 2 + gauche + 4 * (case + 2 * DEMI + 14)
    ill_h = 300
    hauteur = 120 + ill_h + 40 + len(dossiers) * (2 * (case + 10) + 50) + 20
    planche = Image.new("RGB", (largeur, hauteur), FOND)
    d = ImageDraw.Draw(planche)
    d.text((marge, 12), "ISO13 · les personnages en mannequins — avant / après, sous la torche", fill=AMBRE, font=police(28))
    d.text((marge, 50), "la 2D du jeu, Le Cloître, 1920×1080, bandeau de LED coupé ; J2 vu dans la vue de J1, de face puis de dos ; "
           "pour chaque prise, la loupe 1:1 puis ×3 sans lissage ; même instant dans une ligne", fill=TEXTE, font=police(15))
    x = marge
    for nom, lib in [("ill_accueil", "illustration de l'accueil"), ("ill_ecran_scinde", "illustration de l'écran scindé")]:
        im = Image.open("%s/assets/ui/%s.png" % (depot, nom)).convert("RGB")
        im = im.resize((int(im.width * ill_h / im.height), ill_h), Image.LANCZOS)
        planche.paste(im, (x, 84))
        d.text((x, 84 + ill_h + 4), lib, fill=SOURD, font=police(13))
        x += im.width + 16
    y = 84 + ill_h + 34
    for dossier in dossiers:
        slug = dossier.rstrip("/").split("captures_mannequin_")[-1]
        prises = {}
        for l in open(dossier + "/journal.log", encoding="utf-8", errors="replace"):
            m = LIGNE.search(l.strip())
            if m:
                prises[(m.group(1), m.group(2))] = (m.group(5), json.loads(m.group(6)), (int(m.group(3)), int(m.group(4))))
        d.text((marge, y), "%s (%s)" % (LIB.get(slug, slug), slug), fill=AMBRE, font=police(20))
        y += 28
        for k, (_, nom) in enumerate(COLS):
            d.text((marge + gauche + k * (case + 2 * DEMI + 14), y), nom, fill=SOURD, font=police(13))
        y += 18
        for cad, nom in [("tenues_torche", "de face"), ("tenues_torche_dos", "de dos")]:
            d.text((marge, y + case // 2 - 8), nom, fill=TEXTE, font=police(14))
            cams = set()
            for k, (t, _) in enumerate(COLS):
                p = prises.get((cad, t))
                if p is None:
                    raise SystemExit("%s : prise %s %s absente" % (slug, cad, t))
                cams.add(p[2])
                im = Image.open("%s/%s" % (dossier, p[0])).convert("RGB")
                x0, y0 = p[1]["j2"]
                loupe = im.crop((x0 - DEMI, y0 - DEMI, x0 + DEMI, y0 + DEMI))
                xx = marge + gauche + k * (case + 2 * DEMI + 14)
                planche.paste(loupe, (xx, y + case - 2 * DEMI))
                planche.paste(loupe.resize((case, case), Image.NEAREST), (xx + 2 * DEMI + 4, y))
            if len(cams) > 1:
                raise SystemExit("%s %s : la caméra a bougé entre les prises %s" % (slug, cad, cams))
            y += case + 10
        y += 12
    planche = planche.crop((0, 0, largeur, y + 10))
    planche.save(sortie, "JPEG", quality=90)
    print("planche %dx%d → %s" % (planche.width, planche.height, sortie))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
