#!/usr/bin/env python3
"""Vérifie qu'une texture se tuile sans couture visible (chantier ISO7 Beauté).

Une texture tuilable pose son bord droit contre son bord gauche, et son bas contre
son haut. La couture se voit quand l'écart entre ces deux bords dépasse l'écart
ORDINAIRE entre deux colonnes (ou lignes) voisines de la même image : c'est ce
rapport qui est mesuré, pas un écart absolu. Un béton très granuleux a de gros
écarts entre voisins et peut donc avoir de gros écarts de couture ; un lavis lisse
n'a pas ce droit.

Deuxième mesure, la LUMIÈRE CUITE : en jeu la texture est multipliée par la
lumière de la lightmap, donc une image déjà éclairée (un quart clair, un quart
sombre) dessine une seconde lumière qui ne vient d'aucune source. On compare les
moyennes des quatre quarts.

Usage : tools/verifie_tuilable.py <image> [<image>…]   (code 1 si une échoue)
        --json pour une sortie lisible par la suite GDScript.

PIL seulement, pas numpy.

⚠️ Miroir GDScript : `mesurer_tuilable()` dans `tools/test_iso_beaute.gd`, mêmes formules et seuils.
La suite ne peut pas appeler ce script : le lot tourne sous un `HOME` isolé où PIL est introuvable.
Toute retouche se fait DANS LES DEUX fichiers.
"""
import json
import sys

from PIL import Image, ImageStat

# Une couture au plus 1,6 fois l'écart moyen entre deux voisins.
RAPPORT_MAX = 1.6
# Écart maximal entre le quart le plus clair et le plus sombre, en niveaux sur 255.
ECART_QUARTS_MAX = 12.0


def _ecart(a, b):
    return sum(abs(x - y) for x, y in zip(a, b)) / len(a)


def mesurer(chemin):
    im = Image.open(chemin).convert("L")
    w, h = im.size
    px = im.load()

    def col(x):
        return [px[x, y] for y in range(h)]

    def lig(y):
        return [px[x, y] for x in range(w)]

    # L'écart ordinaire : la moyenne sur une dizaine de paires de voisins réparties.
    xs = range(max(1, w // 11), w - 1, max(1, w // 11))
    ys = range(max(1, h // 11), h - 1, max(1, h // 11))
    voisins_x = sum(_ecart(col(x), col(x + 1)) for x in xs) / len(xs)
    voisins_y = sum(_ecart(lig(y), lig(y + 1)) for y in ys) / len(ys)
    couture_x = _ecart(col(w - 1), col(0))
    couture_y = _ecart(lig(h - 1), lig(0))
    quarts = [ImageStat.Stat(im.crop(c)).mean[0] for c in
              [(0, 0, w // 2, h // 2), (w // 2, 0, w, h // 2), (0, h // 2, w // 2, h), (w // 2, h // 2, w, h)]]
    r_x = couture_x / max(voisins_x, 0.5)
    r_y = couture_y / max(voisins_y, 0.5)
    ecart_quarts = max(quarts) - min(quarts)
    return {
        "chemin": chemin,
        "taille": [w, h],
        "rapport_x": round(r_x, 3),
        "rapport_y": round(r_y, 3),
        "ecart_quarts": round(ecart_quarts, 2),
        "moyenne": round(ImageStat.Stat(im).mean[0], 2),
        "tuilable": r_x <= RAPPORT_MAX and r_y <= RAPPORT_MAX,
        "plate": ecart_quarts <= ECART_QUARTS_MAX,
    }


def main(args):
    en_json = "--json" in args
    chemins = [a for a in args if a != "--json"]
    if not chemins:
        print(__doc__)
        return 2
    resultats = [mesurer(c) for c in chemins]
    ok = all(r["tuilable"] and r["plate"] for r in resultats)
    if en_json:
        print(json.dumps({"ok": ok, "textures": resultats}))
    else:
        for r in resultats:
            etat = "OK " if r["tuilable"] and r["plate"] else "NON"
            print("%s %s %dx%d couture x %.2f y %.2f (max %.1f) · quarts ±%.1f (max %.0f) · moyenne %.1f"
                  % (etat, r["chemin"], r["taille"][0], r["taille"][1], r["rapport_x"], r["rapport_y"],
                     RAPPORT_MAX, r["ecart_quarts"], ECART_QUARTS_MAX, r["moyenne"]))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
