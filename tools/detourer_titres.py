"""Retire le liseré blanc-gris (reste du damier de fausse transparence) autour
des images générées, adoucit le bord d'un demi-pixel et noircit le RVB des
pixels transparents (sans quoi le filtrage bilinéaire ramène le blanc)."""
import sys
from PIL import Image, ImageFilter

R = 4          # le liseré vit à moins de R px de la transparence
SAT_MAX = 45   # gris : écart max-min des canaux
LUM_MIN = 35   # au-dessus : trop clair pour être de l'encre
GRAIN_MAX = 8  # composante isolée plus petite : un reste de damier


def _grains(im, bande):
    """Retire les petites îles opaques (8-connexes) situées dans la bande."""
    W, H = im.size
    px = im.load()
    vu = bytearray(W * H)
    retires = 0
    for y0 in range(H):
        for x0 in range(W):
            i0 = y0 * W + x0
            if vu[i0] or px[x0, y0][3] == 0 or not bande[x0, y0]:
                continue
            pile = [(x0, y0)]
            vu[i0] = 1
            ile = []
            while pile and len(ile) <= GRAIN_MAX:
                x, y = pile.pop()
                ile.append((x, y))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < W and 0 <= ny < H:
                            j = ny * W + nx
                            if not vu[j] and px[nx, ny][3] > 0:
                                vu[j] = 1
                                pile.append((nx, ny))
            if len(ile) <= GRAIN_MAX and not pile:
                for x, y in ile:
                    px[x, y] = (0, 0, 0, 0)
                retires += len(ile)
    return retires


def nettoyer(chemin, sortie):
    im = Image.open(chemin).convert("RGBA")
    W, H = im.size
    px = im.load()
    transp = im.getchannel("A").point(lambda v: 255 if v == 0 else 0)
    bande = transp.filter(ImageFilter.MaxFilter(2 * R + 1)).load()
    retires = 0
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            if a == 0 or bande[x, y] == 0:
                continue
            if max(r, g, b) - min(r, g, b) < SAT_MAX and (r + g + b) / 3 > LUM_MIN:
                px[x, y] = (0, 0, 0, 0)
                retires += 1
    retires += _grains(im, bande)
    # Poussières : pixels opaques presque isolés dans la bande (restes du damier).
    for _ in range(2):
        a_img = im.getchannel("A").point(lambda v: 255 if v > 0 else 0)
        voisins = a_img.filter(ImageFilter.BoxBlur(1)).load()  # moyenne 3x3
        for y in range(H):
            for x in range(W):
                if px[x, y][3] > 0 and bande[x, y] and voisins[x, y] < 255 * 3 / 9:
                    px[x, y] = (0, 0, 0, 0)
                    retires += 1
    # Bord adouci d'un demi-pixel, sans jamais épaissir la forme.
    a_bin = im.getchannel("A").point(lambda v: 255 if v > 0 else 0)
    flou = a_bin.filter(ImageFilter.GaussianBlur(0.7)).load()
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            if a == 0:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (r, g, b, min(a, min(255, int(flou[x, y] * 1.6))))
    im.save(sortie, optimize=True)
    return retires


if __name__ == "__main__":
    for chemin in sys.argv[1:]:
        print(chemin, "retirés:", nettoyer(chemin, chemin))
