#!/usr/bin/env python3
"""Planche ISO12 — les dix corps d'après leurs portraits de classe, au banc des corps.

Pour chaque classe, une ligne : le portrait (ISO Assets, lu par `git show`), le corps gris d'ISO3 à 0,8, puis le corps
peint d'après son portrait à 0,8, 0,2 et 0 (le noir absolu). Les corps sont repérés sans deviner : ce sont les pixels qui
diffèrent entre la capture grise et la capture peinte à 0,8 (seuls les corps changent entre elles), regroupés sur la
grille du banc (5 colonnes, dans l'ordre de `VoxelCatalogue.slugs()`).

Usage : docs/iso/planche_corps_portraits.py <sortie.jpg> <dossier des captures du banc>
Captures attendues : corps_gris_0.8.png, corps_portraits_0.8.png, corps_portraits_0.2.png, corps_portraits_0.png.
"""
import io
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

BRANCHE_DA = "claude/iso-assets-gemini-boards-4e8d33"
PORTRAIT = "docs/iso/planches_gemini/habillage/portrait_%s.png"
SLUGS = ["pistolet", "fusil", "pompe", "arbalete", "fumiste", "incendiaire", "sentinelle", "occulteur", "allumeur", "spectre"]
LIBELLES = {"pistolet": "Le Parasite", "fusil": "L'Illusionniste", "pompe": "Le Terrassier", "arbalete": "Le Braconnier",
            "fumiste": "Le Fumiste", "incendiaire": "L'Incendiaire", "sentinelle": "La Sentinelle",
            "occulteur": "L'Occulteur", "allumeur": "L'Allumeur", "spectre": "Le Spectre"}
CASE = 190
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


def portrait(slug):
    brut = subprocess.run(["git", "show", "%s:%s" % (BRANCHE_DA, PORTRAIT % slug)], capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(brut)).convert("RGB").resize((CASE, CASE), Image.LANCZOS)


def boites(gris, peint):
    """Les dix boîtes englobantes des corps : pixels qui diffèrent, rangés sur la grille 5 × 2."""
    w, h = gris.size
    a, b = gris.load(), peint.load()
    pts = [(x, y) for y in range(0, h, 2) for x in range(0, w, 2)
           if max(abs(a[x, y][i] - b[x, y][i]) for i in range(3)) > 8]
    if not pts:
        raise SystemExit("aucun corps repéré : les deux captures sont identiques")
    xs = sorted(p[0] for p in pts)
    ys = sorted(p[1] for p in pts)
    x0, x1, y0, y1 = xs[0], xs[-1], ys[0], ys[-1]
    cols, lignes = 5, 2
    groupes = {}
    for x, y in pts:
        c = min(cols - 1, int((x - x0) * cols / max(1, x1 - x0 + 1)))
        l = min(lignes - 1, int((y - y0) * lignes / max(1, y1 - y0 + 1)))
        g = groupes.setdefault((l, c), [w, h, 0, 0])
        g[0], g[1], g[2], g[3] = min(g[0], x), min(g[1], y), max(g[2], x), max(g[3], y)
    out = []
    for l in range(lignes):
        for c in range(cols):
            g = groupes.get((l, c))
            if g is None:
                raise SystemExit("corps manquant ligne %d colonne %d" % (l, c))
            cx, cy = (g[0] + g[2]) / 2, (g[1] + g[3]) / 2
            demi = max(g[2] - g[0], g[3] - g[1]) / 2 + 6
            out.append((int(cx - demi), int(cy - demi), int(cx + demi), int(cy + demi)))
    return out


def main(args):
    if len(args) != 2:
        print(__doc__)
        return 2
    sortie, dossier = args
    noms = ["corps_gris_0.8", "corps_portraits_0.8", "corps_portraits_0.2", "corps_portraits_0"]
    images = {n: Image.open("%s/%s.png" % (dossier, n)).convert("RGB") for n in noms}
    cadres = boites(images["corps_gris_0.8"], images["corps_portraits_0.8"])
    entetes = ["portrait", "gris d'ISO3, 0,8", "portrait, 0,8", "portrait, 0,2", "portrait, 0"]
    colonnes_par_classe = len(entetes)
    marge, titre_h, legende_h = 14, 96, 22
    largeur_bloc = colonnes_par_classe * (CASE + 6)
    largeur = marge * 3 + largeur_bloc * 2
    hauteur = titre_h + 5 * (CASE + legende_h + 10) + marge
    planche = Image.new("RGB", (largeur, hauteur), FOND)
    d = ImageDraw.Draw(planche)
    d.text((marge, 12), "ISO12 — les dix corps d'après leurs portraits de classe", fill=AMBRE, font=police(28))
    d.text((marge, 48), "banc des corps, lumière simulée 0,8 / 0,2 / 0, modelé et encre des arêtes du jeu — albédo seul : "
           "à 0 le corps est noir", fill=TEXTE, font=police(15))
    for k, e in enumerate(entetes * 2):
        bloc = k // colonnes_par_classe
        x = marge + bloc * (largeur_bloc + marge) + (k % colonnes_par_classe) * (CASE + 6)
        d.text((x, 74), e, fill=TEXTE, font=police(14))
    for i, slug in enumerate(SLUGS):
        bloc, ligne = i // 5, i % 5
        x = marge + bloc * (largeur_bloc + marge)
        y = titre_h + ligne * (CASE + legende_h + 10)
        cases = [portrait(slug)] + [images[n].crop(cadres[i]).resize((CASE, CASE), Image.NEAREST) for n in noms]
        for k, c in enumerate(cases):
            planche.paste(c, (x + k * (CASE + 6), y))
        d.text((x, y + CASE + 3), "%s (%s)" % (LIBELLES[slug], slug), fill=TEXTE, font=police(15))
    planche.save(sortie, "JPEG", quality=86)
    print("planche %dx%d → %s" % (planche.width, planche.height, sortie))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
