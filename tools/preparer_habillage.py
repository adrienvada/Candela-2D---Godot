"""Prépare les images de l'habillage iso : de la source Gemini à l'asset du jeu.

Chantier Habillage iso (2026-09-15). Une image générée n'est jamais l'asset,
seulement sa matière (« Décisions actées ») : chaque source passe ici par le même
traitement, rejouable, et c'est ce traitement qui fait l'unité de la série —
pas la chance de dix générations qui se ressemblent.

- **fond** : recadrage 16:9 et réduction à 1920×1071 (le format des autres fonds),
  JPEG ; la source est déjà dans la pâte D, elle n'est pas virée.
- **portrait** : détourage du fond vert, recadrage sur le sujet avec marge,
  VIRAGE encre/papier commun, réduction à 256 px, PNG avec alpha.
- **icone** : même chaîne, 128 px.

Le détourage reprend le principe de `tools/incruster_vert.py` (alpha tiré de la
« verdeur », seuils mesurés sur le bord de CETTE image, déversement) — piège
payé : Gemini ne rend jamais deux fois le même vert.

Le virage : la luminance de la source pilote un dégradé ENCRE → BÉTON → PAPIER
(les couleurs de `charte.gd`), puis la couleur d'origine est rendue à 35 % pour
que la lumière de torche reste chaude là où elle frappe. Dix portraits orangés
de dix nuances différentes deviennent dix planches du même papier.

Usage :
  python3 tools/preparer_habillage.py fond     source.jpg sortie.jpg
  python3 tools/preparer_habillage.py portrait source.png sortie.png
  python3 tools/preparer_habillage.py icone    source.png sortie.png
Imprime ce qu'il a mesuré (seuils de vert, boîte du sujet), pour qu'on le relise.
"""
import sys

from PIL import Image

# Les couleurs de la pâte, recopiées de `charte.gd` — et vérifiées contre lui par
# `tools/test_habillage.gd`, qui relit ce fichier : une copie qui diverge rougit.
ENCRE = (0.075, 0.063, 0.051)
BETON = (0.4375, 0.3915, 0.3355)
PAPIER = (0.80, 0.72, 0.62)
PART_ORIGINE = 0.35
MARGE = 0.08


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def fond(source, sortie):
    im = Image.open(source).convert("RGB")
    l, h = im.size
    cible = 1920 / 1071
    if l / h > cible:
        nl = int(round(h * cible))
        x = (l - nl) // 2
        im = im.crop((x, 0, x + nl, h))
    else:
        nh = int(round(l / cible))
        y = (h - nh) // 2
        im = im.crop((0, y, l, y + nh))
    im = im.resize((1920, 1071), Image.LANCZOS)
    im.save(sortie, quality=90, optimize=True)
    print(f"fond : {source} {l}x{h} -> {sortie} 1920x1071")


def detourer(im):
    l, h = im.size
    p = im.load()
    bord = [p[x, 0] for x in range(0, l, 7)] + [p[x, h - 1] for x in range(0, l, 7)] \
        + [p[0, y] for y in range(0, h, 7)] + [p[l - 1, y] for y in range(0, h, 7)]
    verdeurs = sorted(g - max(r, b) for r, g, b in bord)
    v_fond = verdeurs[len(verdeurs) // 2]
    # Opaque sous 30 % de la verdeur du fond, transparent au-dessus de 75 %.
    bas, haut = v_fond * 0.30, v_fond * 0.75
    alpha = Image.new("L", (l, h))
    a = alpha.load()
    out = Image.new("RGB", (l, h))
    o = out.load()
    for y in range(h):
        for x in range(l):
            r, g, b = p[x, y]
            v = g - max(r, b)
            if v <= bas:
                t = 255
            elif v >= haut:
                t = 0
            else:
                t = int(round(255 * (haut - v) / (haut - bas)))
            a[x, y] = t
            # Déversement : le vert en excès sur les bords redescend au niveau
            # du plus fort des deux autres canaux.
            o[x, y] = (r, min(g, max(r, b)), b)
    print(f"  verdeur du fond {v_fond}, seuils {bas:.0f} / {haut:.0f}")
    return out, alpha


def virer(im):
    p = im.load()
    l, h = im.size
    for y in range(h):
        for x in range(l):
            r, g, b = (c / 255.0 for c in p[x, y])
            lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
            base = lerp(ENCRE, BETON, lum * 2.0) if lum < 0.5 else lerp(BETON, PAPIER, (lum - 0.5) * 2.0)
            c = lerp(base, (r, g, b), PART_ORIGINE)
            p[x, y] = tuple(int(round(max(0.0, min(1.0, v)) * 255)) for v in c)
    return im


def sujet(source, sortie, cote):
    im = Image.open(source).convert("RGB")
    rgb, alpha = detourer(im)
    boite = alpha.point(lambda v: 255 if v > 40 else 0).getbbox()
    if boite is None:
        raise SystemExit(f"aucun sujet détecté dans {source}")
    x0, y0, x1, y1 = boite
    touche = x0 <= 1 or y0 <= 1 or x1 >= im.width - 1 or y1 >= im.height - 1
    print(f"  sujet {boite} dans {im.size}" + ("  ⚠️ TOUCHE LE BORD : sujet rogné à la source" if touche else ""))
    c = max(x1 - x0, y1 - y0)
    c = int(round(c * (1 + 2 * MARGE)))
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    carre = (cx - c // 2, cy - c // 2, cx - c // 2 + c, cy - c // 2 + c)
    rgb = virer(rgb.crop(carre))
    alpha = alpha.crop(carre)
    rgba = rgb.convert("RGBA")
    rgba.putalpha(alpha)
    rgba = rgba.resize((cote, cote), Image.LANCZOS)
    rgba.save(sortie, optimize=True)
    print(f"{source} -> {sortie} {cote}x{cote}")


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    mode, source, sortie = sys.argv[1:]
    if mode == "fond":
        fond(source, sortie)
    elif mode == "portrait":
        sujet(source, sortie, 256)
    elif mode == "icone":
        sujet(source, sortie, 128)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
