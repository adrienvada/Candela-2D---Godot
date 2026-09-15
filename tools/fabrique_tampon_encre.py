"""Fabrique le cadre de tampon à l'encre projetée de la killcam iso.

Chantier Habillage iso (2026-09-15), étape 5. Les planches `killcam_tireur_01`
et `killcam_victime_01` signent le kill d'un TAMPON : un cadre tracé à l'encre,
bords rugueux, mouchetures projetées autour — jamais de lettre lisible dans
l'image, le texte reste au jeu. L'estampe de kill (`estampe_de_kill.gd`) garde son
« KILL — mm:ss », sa place, son inclinaison et son rebond, jugés par Adrien ; ce
fichier ne lui donne que la MATIÈRE.

Un script et non une image générée : une image générée n'est jamais l'asset
(« Décisions actées »), et un tampon doit rester net à toutes les tailles, ce que
se juge à la netteté de son bord — un seuil franc, pas un flou de photographie.

Sortie : un MASQUE blanc sur transparent (le code le teinte, discipline DA1.5),
1024 × 340 — le rapport d'un « KILL — 04:12 » en fonte d'enseigne, marge comprise.
Graine fixe : relancer rend le même fichier.

Usage : python3 tools/fabrique_tampon_encre.py [sortie.png]
        (défaut : assets/ui/matiere/tampon_encre.png)
"""
import math
import os
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

LARGEUR, HAUTEUR = 1024, 340
GRAINE = 15092027
SORTIE = sys.argv[1] if len(sys.argv) > 1 else "assets/ui/matiere/tampon_encre.png"
# Épaisseur du trait du cadre, en pixels, et amplitude de son tremblé.
TRAIT = 16
TREMBLE = 5.0


def cadre(rnd):
    """Le cadre : quatre côtés tracés en segments courts, chacun décalé d'un
    tremblé lissé — la main qui tient l'encreur, pas une règle."""
    im = Image.new("L", (LARGEUR, HAUTEUR), 0)
    d = ImageDraw.Draw(im)
    m = 34
    coins = [(m, m), (LARGEUR - m, m), (LARGEUR - m, HAUTEUR - m), (m, HAUTEUR - m)]
    for i in range(4):
        (x0, y0), (x1, y1) = coins[i], coins[(i + 1) % 4]
        long = math.hypot(x1 - x0, y1 - y0)
        n = max(2, int(long / 18))
        derive = 0.0
        points = []
        for k in range(n + 1):
            t = k / n
            derive = derive * 0.7 + rnd.uniform(-TREMBLE, TREMBLE) * 0.3
            nx, ny = -(y1 - y0) / long, (x1 - x0) / long
            points.append((x0 + (x1 - x0) * t + nx * derive, y0 + (y1 - y0) * t + ny * derive))
        for a, b in zip(points, points[1:]):
            largeur = int(TRAIT * rnd.uniform(0.8, 1.15))
            d.line([a, b], fill=255, width=largeur)
            d.ellipse((b[0] - largeur / 2, b[1] - largeur / 2, b[0] + largeur / 2, b[1] + largeur / 2), fill=255)
    return im


def mouchetures(rnd):
    """L'encre projetée : des gouttes groupées vers deux coins opposés, plus
    grosses près du cadre, plus fines au loin, et quelques coulures."""
    im = Image.new("L", (LARGEUR, HAUTEUR), 0)
    d = ImageDraw.Draw(im)
    for (cx, cy) in [(60, HAUTEUR - 50), (LARGEUR - 70, 44)]:
        for _ in range(140):
            ang = rnd.uniform(0, math.tau)
            dist = abs(rnd.gauss(0, 70))
            x, y = cx + math.cos(ang) * dist, cy + math.sin(ang) * dist
            r = max(0.8, 9.0 * math.exp(-dist / 45.0) * rnd.uniform(0.3, 1.0))
            d.ellipse((x - r, y - r, x + r, y + r), fill=255)
        for _ in range(3):
            x = cx + rnd.uniform(-30, 30)
            y = cy + rnd.uniform(-10, 10)
            longueur = rnd.uniform(18, 46)
            d.line([(x, y), (x + rnd.uniform(-4, 4), y + longueur)], fill=255, width=int(rnd.uniform(2, 5)))
    return im


def brosse_seche(rnd, masque):
    """Le tampon ne prend pas partout : des trous d'encre, là où la gomme a
    manqué le papier. Un bruit flouté puis seuillé, retiré du masque."""
    petit = Image.new("L", (LARGEUR // 4, HAUTEUR // 4))
    petit.putdata([rnd.randrange(256) for _ in range(petit.width * petit.height)])
    bruit = petit.resize((LARGEUR, HAUTEUR), Image.BICUBIC).filter(ImageFilter.GaussianBlur(1.5))
    trous = bruit.point(lambda v: 255 if v > 178 else 0)
    return ImageChops.subtract(masque, trous)


def main():
    rnd = random.Random(GRAINE)
    masque = ImageChops.lighter(cadre(rnd), mouchetures(rnd))
    masque = brosse_seche(rnd, masque)
    # Un bord d'encre, pas un bord de photo : léger flou pour tuer l'escalier,
    # puis un seuil adouci sur quelques niveaux seulement.
    masque = masque.filter(ImageFilter.GaussianBlur(0.8)).point(
        lambda v: 0 if v < 90 else (255 if v > 150 else int((v - 90) * 255 / 60)))
    rgba = Image.new("RGBA", (LARGEUR, HAUTEUR), (255, 255, 255, 0))
    rgba.putalpha(masque)
    os.makedirs(os.path.dirname(SORTIE) or ".", exist_ok=True)
    rgba.save(SORTIE, optimize=True)
    couvert = sum(1 for v in masque.getdata() if v > 127) / (LARGEUR * HAUTEUR)
    print(f"{SORTIE} : {LARGEUR}x{HAUTEUR}, encre sur {couvert * 100:.1f} % de la surface")


if __name__ == "__main__":
    main()
