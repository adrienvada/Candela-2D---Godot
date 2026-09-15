#!/usr/bin/env python3
"""Planche ISO7 Beauté : l'habillage de la vue iso, avant / après, contre la planche du DA.

Lit les captures de `tools/banc_iso_beaute.gd` (`<base>_avant.png`, `<base>_apres.png`) pour chaque
cadrage donné, et la planche E1 (« la promesse du jeu en iso ») de la branche d'ISO Assets par
`git show` — elle n'est pas copiée dans cette branche.

Usage : docs/iso/planche_iso7.py <sortie.jpg> <base_cadrage_1> [<base_cadrage_2> …]
"""
import io
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

BRANCHE_DA = "claude/iso-assets-gemini-boards-4e8d33"
PLANCHE_DA = "docs/iso/planches_gemini/planche_promesse.jpg"
LARGEUR_CASE = 760
FOND = (12, 12, 12)
TEXTE = (225, 215, 195)
AMBRE = (230, 160, 70)


def police(taille):
    for chemin in ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try:
            return ImageFont.truetype(chemin, taille)
        except OSError:
            pass
    return ImageFont.load_default()


def case(image):
    h = int(image.height * LARGEUR_CASE / image.width)
    return image.convert("RGB").resize((LARGEUR_CASE, h), Image.LANCZOS)


def planche_da():
    try:
        brut = subprocess.run(["git", "show", "%s:%s" % (BRANCHE_DA, PLANCHE_DA)], capture_output=True, check=True).stdout
        return Image.open(io.BytesIO(brut))
    except (subprocess.CalledProcessError, OSError):
        return None


def main(args):
    if len(args) < 2:
        print(__doc__)
        return 2
    sortie, bases = args[0], args[1:]
    lignes = []
    for base in bases:
        avant = case(Image.open(base + "_avant.png"))
        apres = case(Image.open(base + "_apres.png"))
        lignes.append((base.rsplit("/", 1)[-1], avant, apres))
    da = planche_da()
    marge = 18
    titre_h = 70
    legende_h = 30
    hauteur = titre_h + sum(max(a.height, b.height) + legende_h + marge for _, a, b in lignes)
    if da is not None:
        da_case = da.convert("RGB").resize((LARGEUR_CASE * 2 + marge, int(da.height * (LARGEUR_CASE * 2 + marge) / da.width)))
        hauteur += da_case.height + legende_h + marge
    planche = Image.new("RGB", (LARGEUR_CASE * 2 + marge * 3, hauteur), FOND)
    d = ImageDraw.Draw(planche)
    d.text((marge, 14), "ISO7 — la beauté de la vue iso : avant / après", fill=AMBRE, font=police(30))
    d.text((marge, 48), "matière des murs et du sol, encre d'arête, liseré du sommet, dessus des murets — "
           "toujours multipliés par la lightmap", fill=TEXTE, font=police(16))
    y = titre_h
    for nom, avant, apres in lignes:
        planche.paste(avant, (marge, y))
        planche.paste(apres, (marge * 2 + LARGEUR_CASE, y))
        h = max(avant.height, apres.height)
        d.text((marge, y + h + 4), "%s — avant (ISO1-ISO5)" % nom, fill=TEXTE, font=police(18))
        d.text((marge * 2 + LARGEUR_CASE, y + h + 4), "%s — après (ISO7)" % nom, fill=TEXTE, font=police(18))
        y += h + legende_h + marge
    if da is not None:
        planche.paste(da_case, (marge, y))
        d.text((marge, y + da_case.height + 4), "référence : planche E1 du DA (ISO Assets, Gemini)", fill=TEXTE,
               font=police(18))
    planche.save(sortie, quality=88)
    print("écrit", sortie, planche.size)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
