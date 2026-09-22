#!/usr/bin/env python3
"""ISO12, lot L4 — LE PROFIL RADIAL : le rapport 3D / 2D par anneaux, autour d'une source.

Pourquoi des anneaux et pas une moyenne : une moyenne à 1,09 a déjà caché une flaque
(ROADMAP, lot 0 ter), et les deux défauts que L4 corrige sont RADIAUX — ils ne se voient
qu'en fonction de la distance à la lampe. Un anneau qui s'effondre au bord du halo, c'est
ε qui mord ; un anneau qui tombe NET à zéro, c'est la portée 3D qui s'arrête avant le
disque éclairé en 2D. Une moyenne confond les deux avec un succès.

    python3 profil_radial.py --3d=PRISE.png --2d=REFERENCE.png --ancre=X,Y --rayon2d=R \
                             [--pas=10] [--jusqu-a=1.3] [--seuil=8] [--sol=MASQUE.png] \
                             [--titre=NOM] [--brut]
    python3 profil_radial.py --autotest

⚠️ **Le rapport se prend en LINÉAIRE.** Une capture est encodée en sRGB ; le rapport de deux
valeurs encodées n'est pas le rapport des deux lumières. R est un multiplicateur linéaire, et
c'est exactement l'erreur qui a fait tomber le halo de fusée 35 % sous la 2D dans le miroir
(défaut 6 de la revue de Beauté). `--brut` compare les valeurs encodées, pour comparaison.

⚠️ **Le sol seul.** Sans masque de sol, les murs et les corps pris dans l'anneau comptent
aussi. Deux garde-fous plutôt qu'un silence : la médiane (qui résiste à une minorité de
pixels), et le nombre de pixels retenus imprimé pour chaque anneau — un anneau qui en garde
peu ne se lit pas. `--sol=` prend un masque (blanc = sol) quand le banc sait en produire un.

Dépendance : Pillow. Pas de numpy (absent du poste).
"""
import math
import sys
from statistics import median

from PIL import Image

POIDS = (0.2126, 0.7152, 0.0722)  # PATE_POIDS, la luminance avec laquelle la pâte lit la lumière


def lin(c):
    """sRGB 0-255 → linéaire 0-1."""
    x = c / 255.0
    return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4


TABLE_LIN = [lin(i) for i in range(256)]


def luminance(px, brut):
    if brut:
        return (POIDS[0] * px[0] + POIDS[1] * px[1] + POIDS[2] * px[2]) / 255.0
    return POIDS[0] * TABLE_LIN[px[0]] + POIDS[1] * TABLE_LIN[px[1]] + POIDS[2] * TABLE_LIN[px[2]]


def percentile(valeurs, p):
    if not valeurs:
        return 0.0
    v = sorted(valeurs)
    k = (len(v) - 1) * p
    bas = int(math.floor(k))
    haut = min(bas + 1, len(v) - 1)
    return v[bas] + (v[haut] - v[bas]) * (k - bas)


def profil(img3d, img2d, ancre, rayon2d, pas=10.0, jusqu_a=1.3, seuil=8, sol=None, brut=False):
    """Rend la liste des anneaux : (r0, r1, n, mediane, p10, p90)."""
    if img3d.size != img2d.size:
        raise SystemExit("PROFIL ERREUR : les deux prises n'ont pas la même taille (%s vs %s)"
                         % (img3d.size, img2d.size))
    w, h = img3d.size
    rmax = rayon2d * jusqu_a
    x0, y0 = int(max(0, ancre[0] - rmax)), int(max(0, ancre[1] - rmax))
    x1, y1 = int(min(w, ancre[0] + rmax + 1)), int(min(h, ancre[1] + rmax + 1))
    if x1 <= x0 or y1 <= y0:
        raise SystemExit("PROFIL ERREUR : l'ancre %s tombe hors de l'image %s" % (ancre, img3d.size))
    boite = (x0, y0, x1, y1)
    p3 = list(img3d.convert("RGB").crop(boite).getdata())
    p2 = list(img2d.convert("RGB").crop(boite).getdata())
    ps = list(sol.convert("L").crop(boite).getdata()) if sol is not None else None
    lseuil = luminance((seuil, seuil, seuil), brut)
    larg = x1 - x0
    anneaux = {}
    for i in range(len(p3)):
        x = x0 + (i % larg)
        y = y0 + (i // larg)
        d = math.hypot(x - ancre[0], y - ancre[1])
        if d > rmax or d < 1.0:
            continue
        if ps is not None and ps[i] < 128:
            continue
        l2 = luminance(p2[i], brut)
        if l2 < lseuil:  # la 2D n'éclaire pas ici : le rapport n'y a pas de sens
            continue
        anneaux.setdefault(int(d // pas), []).append(luminance(p3[i], brut) / l2)
    out = []
    for k in sorted(anneaux):
        v = anneaux[k]
        out.append((k * pas, (k + 1) * pas, len(v), median(v), percentile(v, 0.1), percentile(v, 0.9)))
    return out


def imprimer(titre, anneaux, rayon2d):
    print("PROFIL %s — rayon 2D %.0f px ; rapport 3D/2D par anneau, sur les pixels éclairés en 2D" % (titre, rayon2d))
    print("PROFIL %8s %8s %10s %8s %8s %8s" % ("de(px)", "a(px)", "pixels", "mediane", "p10", "p90"))
    pire, pire_ou = 1e9, None
    for r0, r1, n, med, p10, p90 in anneaux:
        marque = ""
        if r1 <= rayon2d:
            if med < 0.90:
                marque = "  << SOUS LA 2D"
            elif med > 1.10:
                marque = "  << AU-DESSUS"
            if n >= 50 and med < pire:
                pire, pire_ou = med, (r0, r1)
        print("PROFIL %8.0f %8.0f %10d %8.3f %8.3f %8.3f%s" % (r0, r1, n, med, p10, p90, marque))
    if pire_ou:
        print("PROFIL PIRE ANNEAU dans le disque 2D : %.3f entre %.0f et %.0f px" % (pire, pire_ou[0], pire_ou[1]))
    vides = [a for a in anneaux if a[1] <= rayon2d and a[2] < 50]
    if vides:
        print("PROFIL ⚠️ %d anneau(x) sous 50 pixels retenus dans le disque 2D : ne pas les lire." % len(vides))


def autotest():
    """Rejoue le défaut B sur des images fabriquées, et vérifie que le script le retrouve.

    Braises : h = 1,75 px, halo 2D de 170 px, ε = 0,02 → R = 1 jusqu'à 87,5 px, puis 87,5/d.
    Attendu : ~1,00 près du centre, ~0,51 au bord du halo.
    """
    taille, c, h, eps, r2d = 420, 210, 1.75, 0.02, 170.0
    im2 = Image.new("RGB", (taille, taille))
    im3 = Image.new("RGB", (taille, taille))
    p2, p3 = im2.load(), im3.load()
    def enc(v):
        v = max(0.0, min(1.0, v))
        s = 12.92 * v if v <= 0.0031308 else 1.055 * (v ** (1 / 2.4)) - 0.055
        return int(round(s * 255))
    for y in range(taille):
        for x in range(taille):
            d = math.hypot(x - c, y - c)
            l2d = max(0.0, 0.85 * (1.0 - (d / 260.0) ** 2))
            s = h / max(d, 0.5)
            r = s / max(s, eps)
            p2[x, y] = (enc(l2d),) * 3
            p3[x, y] = (enc(l2d * r),) * 3
    anneaux = profil(im3, im2, (c, c), r2d)
    imprimer("AUTOTEST braises (défaut B rejoué)", anneaux, r2d)
    proche = [a[3] for a in anneaux if a[1] <= 80]
    bord = [a[3] for a in anneaux if 160 <= a[0] < 170]
    ok = proche and bord and abs(median(proche) - 1.0) < 0.02 and abs(bord[0] - 0.53) < 0.05
    print("PROFIL AUTOTEST %s (près du centre %.3f attendu 1,00 ; au bord %.3f attendu ~0,52)"
          % ("OK" if ok else "ÉCHEC", median(proche) if proche else 0, bord[0] if bord else 0))
    return 0 if ok else 1


def main():
    args = sys.argv[1:]
    if "--autotest" in args:
        sys.exit(autotest())
    o = {}
    for a in args:
        if a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            o[k] = v
    for requis in ("3d", "2d", "ancre", "rayon2d"):
        if requis not in o:
            raise SystemExit(__doc__)
    ax, ay = (float(v) for v in o["ancre"].split(","))
    anneaux = profil(Image.open(o["3d"]), Image.open(o["2d"]), (ax, ay), float(o["rayon2d"]),
                     float(o.get("pas", 10.0)), float(o.get("jusqu-a", 1.3)), int(o.get("seuil", 8)),
                     Image.open(o["sol"]) if "sol" in o else None, "--brut" in args)
    imprimer(o.get("titre", o["3d"]), anneaux, float(o["rayon2d"]))


if __name__ == "__main__":
    main()
