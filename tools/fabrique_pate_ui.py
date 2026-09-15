"""Fabrique la matière de la pâte d'interface : un grain de lavis TUILABLE.

Chantier Habillage iso (2026-09-15). Les planches de la pâte D sont peintes au
lavis et au pochoir : des traînées de brosse horizontales, un grain fin, quelques
mouchetures d'encre. Les fonds de panneaux reprennent cette matière au lieu d'un
aplat. `menu_pate.gdshader` l'AJOUTE à la plaque, centrée sur 0,5.

Pourquoi un script plutôt qu'une image générée : une image générée n'est jamais
l'asset (« Décisions actées »), et une matière tuilable se juge à ses raccords,
qu'un générateur ne garantit pas. Graine fixe : relancer le script rend le même
fichier, octet pour octet.

Tuilable par construction : chaque couche est calculée sur une mosaïque 3 × 3
de la même tuile, puis recadrée au centre — le flou et le rééchantillonnage
voient donc, au bord, la tuile voisine qui la continuera à l'écran.

Usage : python3 tools/fabrique_pate_ui.py [sortie.png]
        (défaut : assets/ui/matiere/pate_grain.png)
Imprime la moyenne, l'écart-type et l'écart de raccord, pour qu'on les relise.
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

COTE = 256
GRAINE = 15092026
SORTIE = sys.argv[1] if len(sys.argv) > 1 else "assets/ui/matiere/pate_grain.png"


def bruit(largeur, hauteur, rnd):
    im = Image.new("L", (largeur, hauteur))
    im.putdata([rnd.randrange(256) for _ in range(largeur * hauteur)])
    return im


def mosaique(im):
    l, h = im.size
    grand = Image.new("L", (l * 3, h * 3))
    for i in range(3):
        for j in range(3):
            grand.paste(im, (i * l, j * h))
    return grand


def lavis(rnd):
    """Traînées de brosse : un bruit de 8 × 64 étiré en 256 × 256 — 32 px de
    long pour 4 de haut, donc des coups horizontaux, comme sur les planches."""
    petit = bruit(8, 64, rnd)
    grand = mosaique(petit).resize((COTE * 3, COTE * 3), Image.BICUBIC)
    grand = grand.filter(ImageFilter.GaussianBlur(1.2))
    return grand.crop((COTE, COTE, COTE * 2, COTE * 2))


def grain_fin(rnd):
    grand = mosaique(bruit(COTE, COTE, rnd)).filter(ImageFilter.GaussianBlur(0.7))
    return grand.crop((COTE, COTE, COTE * 2, COTE * 2))


def mouchetures(rnd, nombre=70):
    """Quelques points d'encre, dessinés sur la mosaïque pour qu'un point à
    cheval sur un bord réapparaisse de l'autre côté."""
    grand = Image.new("L", (COTE * 3, COTE * 3), 0)
    d = ImageDraw.Draw(grand)
    for _ in range(nombre):
        x, y = rnd.uniform(0, COTE), rnd.uniform(0, COTE)
        r = rnd.choice([0.6, 0.8, 1.0, 1.4, 2.0])
        for i in range(3):
            for j in range(3):
                cx, cy = x + i * COTE, y + j * COTE
                d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    grand = grand.filter(ImageFilter.GaussianBlur(0.5))
    return grand.crop((COTE, COTE, COTE * 2, COTE * 2))


def main():
    rnd = random.Random(GRAINE)
    a, b, m = lavis(rnd), grain_fin(rnd), mouchetures(rnd)
    pa, pb, pm = a.load(), b.load(), m.load()
    sortie = Image.new("L", (COTE, COTE))
    ps = sortie.load()
    for y in range(COTE):
        for x in range(COTE):
            v = 128.0 + 0.55 * (pa[x, y] - 128) + 0.35 * (pb[x, y] - 128) - 0.45 * pm[x, y]
            ps[x, y] = max(0, min(255, int(round(v))))
    # Recentrage exact sur 128 : le shader AJOUTE (g − 0,5) ; une moyenne à 120
    # assombrirait chaque panneau d'un vingtième de force, sans que rien ne le dise.
    valeurs = list(sortie.getdata())
    moyenne = sum(valeurs) / len(valeurs)
    decalage = 128 - moyenne
    sortie = sortie.point(lambda v: max(0, min(255, int(round(v + decalage)))))
    valeurs = list(sortie.getdata())
    moyenne = sum(valeurs) / len(valeurs)
    ecart = (sum((v - moyenne) ** 2 for v in valeurs) / len(valeurs)) ** 0.5
    ps = sortie.load()
    raccord_h = sum(abs(ps[0, y] - ps[COTE - 1, y]) for y in range(COTE)) / COTE
    raccord_v = sum(abs(ps[x, 0] - ps[x, COTE - 1]) for x in range(COTE)) / COTE
    # ⚠️ Un raccord se compare à l'écart entre voisins DANS LE MÊME AXE. Le lavis
    # est fait de traînées horizontales : deux voisins verticaux diffèrent
    # davantage que deux voisins horizontaux, et comparer le raccord haut/bas à
    # l'écart horizontal le ferait passer pour une couture qu'il n'est pas.
    voisins_h = sum(abs(ps[x, y] - ps[x + 1, y]) for y in range(COTE) for x in range(COTE - 1)) \
        / (COTE * (COTE - 1))
    voisins_v = sum(abs(ps[x, y] - ps[x, y + 1]) for y in range(COTE - 1) for x in range(COTE)) \
        / (COTE * (COTE - 1))
    os.makedirs(os.path.dirname(SORTIE) or ".", exist_ok=True)
    sortie.save(SORTIE, optimize=True)
    print(f"{SORTIE} : {COTE}x{COTE}, moyenne {moyenne:.2f}, écart-type {ecart:.2f}")
    print(f"raccord gauche/droite {raccord_h:.2f} (voisins horizontaux {voisins_h:.2f}) ; "
          f"haut/bas {raccord_v:.2f} (voisins verticaux {voisins_v:.2f})")


if __name__ == "__main__":
    main()
