#!/usr/bin/env python3
"""Fabrique les textures de jeu de la vue iso depuis les sources du DA (chantier ISO7 Beauté).

Les images générées par ISO Assets (Gemini, pâte D) ne sont pas utilisables telles
quelles — « une image générée n'est jamais l'asset, seulement sa matière »
(Décisions actées) :

1. **La lumière y est cuite** (dégradé d'un coin à l'autre). En jeu la texture est
   MULTIPLIÉE par la lumière de la lightmap : une lumière cuite serait une seconde
   source, qui éclaire là où le jeu n'éclaire pas. On divise par un flou très large
   (la basse fréquence = l'éclairage), on garde la matière.
2. **Elles ne se tuilent pas** : on croise l'image avec elle-même décalée d'une
   demi-période, en prenant la version décalée près des bords (où elle est
   continue) et l'originale au centre.
3. **Elles sont trop grandes** (2048 px) pour ce qu'un écran en montre : à 52° et
   1080 lignes, un pixel de monde vaut ~1,27 pixel d'écran. 512 px suffisent,
   mipmaps à l'import.
4. **La texture est un FACTEUR, pas une couleur** : niveaux de gris, moyenne posée à
   `MOYENNE`, minimum borné par `PLANCHER`. Une case éclairée reste éclairée ; une
   case noire reste noire (0 × facteur).

Usage : tools/fabrique_textures_iso.py <source> <destination.png> [--taille 512] [--flou 160]
                                       [--moyenne 200] [--plancher 110]
"""
import sys

from PIL import Image, ImageFilter, ImageChops


def aplanir(im, flou):
    base = im.filter(ImageFilter.GaussianBlur(flou))
    a = list(im.getdata())
    b = list(base.getdata())
    m = sum(a) / len(a)
    sortie = Image.new("L", im.size)
    sortie.putdata([min(255, max(0, int(v / max(w, 1) * m))) for v, w in zip(a, b)])
    return sortie


def tuiler(im, decalage):
    w, h = im.size
    # ⚠️ **Le décalage n'est pas toujours la demi-période.** Une source de coffrage porte ses joints
    # de panneaux au quart et à la moitié : décalée d'une demi-période, la couture tombait PILE sur
    # un joint, et le vérificateur y lisait une couture de 2 fois l'écart ordinaire (2026-09-15).
    decale = ImageChops.offset(im, int(w * decalage), int(h * decalage))
    valeurs = []
    for y in range(h):
        dy = abs(y + 0.5 - h / 2) / (h / 2)
        for x in range(w):
            dx = abs(x + 0.5 - w / 2) / (w / 2)
            # 0 au centre (l'originale), 1 au bord (la décalée, continue d'un bord à l'autre).
            t = min(1.0, max(0.0, (max(dx, dy) - 0.55) / 0.4))
            valeurs.append(int(t * t * (3 - 2 * t) * 255))
    masque = Image.new("L", im.size)
    masque.putdata(valeurs)
    return Image.composite(decale, im, masque)


def en_facteur(im, moyenne, plancher):
    a = list(im.getdata())
    m = sum(a) / len(a)
    bas = min(a) - m + moyenne
    sortie = []
    for v in a:
        f = v - m + moyenne
        if f < moyenne and bas < moyenne:
            # Le bas est comprimé vers le plancher : la tache la plus sombre y arrive, pas plus bas.
            f = moyenne - (moyenne - f) * (moyenne - plancher) / (moyenne - bas)
        sortie.append(int(min(255, max(plancher, f))))
    r = Image.new("L", im.size)
    r.putdata(sortie)
    return r


def _option(args, nom, defaut):
    return float(args[args.index(nom) + 1]) if nom in args else defaut


def main(args):
    if len(args) < 2:
        print(__doc__)
        return 2
    source, destination = args[0], args[1]
    taille = int(_option(args, "--taille", 512))
    flou = _option(args, "--flou", 160.0)
    im = Image.open(source).convert("L")
    # Carré : le plus grand carré central.
    c = min(im.size)
    im = im.crop(((im.width - c) // 2, (im.height - c) // 2, (im.width + c) // 2, (im.height + c) // 2))
    # ⚠️ **Réduire AVANT de tuiler, jamais après.** Le filtre de réduction ne boucle pas : il
    # répète le bord au lieu de lire la colonne d'en face, et une image tuilée à 1024 px
    # sortait à 512 px avec une couture de 2,2 fois l'écart entre voisins (mesuré le 2026-09-15).
    im = im.resize((taille, taille), Image.LANCZOS)
    im = aplanir(im, flou * taille / 2048)
    im = tuiler(im, _option(args, "--decalage", 0.5))
    en_facteur(im, _option(args, "--moyenne", 200.0), _option(args, "--plancher", 110.0)).save(destination)
    print("écrit %s (%d px)" % (destination, taille))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
