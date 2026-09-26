#!/usr/bin/env python3
"""La planche des enseignes : éteint (sans) et allumé (avec), 1:1 et ×3, à côté de l'illustration.

Entrée : les dossiers du photographe (`tools/photo_enseignes.gd`), un par prise, et son journal (lignes `CADRE`).
    python3 docs/iso/cloud/enseignes/planche_enseignes.py <dossier des prises> <journal> <sortie.jpg>
Chaque prise « enseignes_<suffixe>_A1.png » (avec), « _S.png » (sans), « _N1.png » (avec, torches éteintes) ; le journal
porte, dans l'ordre des prises, « CADRE x,y x,y x,y x,y » précédé de la ligne « · « SORTE », … lacet L° ».
"""
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RACINE = Path(__file__).resolve().parents[4]
ILLUSTRATION = {"arena": "assets/ui/ill_accueil.png", "zone": "assets/ui/ill_amical.png"}
# Là où l'illustration porte l'enseigne (fractions de l'image) : la plaque « ARENA », le « ZONE 4 » du pilier.
ILL_CADRE = {"arena": (0.50, 0.08, 0.74, 0.30), "zone": (0.72, 0.12, 0.86, 0.40)}
L1 = (420, 280)      # le cadre 1:1, autour de l'enseigne
L3 = (140, 93)       # le cadre ×3 (agrandi au plus proche : les pixels du jeu, pas un lissage)


def police(t):
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"]:
        if Path(f).exists():
            return ImageFont.truetype(f, t)
    return ImageFont.load_default()


def recadrer(img, centre, taille):
    x0 = int(round(centre[0] - taille[0] / 2))
    y0 = int(round(centre[1] - taille[1] / 2))
    return img.crop((x0, y0, x0 + taille[0], y0 + taille[1]))


def main():
    dossier, journal, sortie = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    lignes = journal.read_text(encoding="utf-8", errors="replace").splitlines()
    prises = []
    courant = None
    for l in lignes:
        m = re.search(r"« (ARENA|ZONE \d) », face .* lacet (-?[\d.]+)°", l)
        if m:
            courant = (m.group(1), float(m.group(2)))
        if l.startswith("CADRE") and courant:
            pts = [tuple(map(float, p.split(","))) for p in l.split()[1:]]
            prises.append((courant, pts))
    f_titre, f_texte = police(22), police(15)
    rangees = []
    for (sorte, lacet), pts in prises:
        cle = "arena" if sorte == "ARENA" else "zone"
        suffixe = "lacet%d_%s" % (round(lacet), cle)
        chemins = {k: dossier / ("enseignes_%s_%s.png" % (suffixe, k)) for k in ["S", "A1", "N1"]}
        if not all(p.exists() for p in chemins.values()):
            print("prise manquante :", suffixe)
            continue
        ims = {k: Image.open(p).convert("RGB") for k, p in chemins.items()}
        cx = sum(p[0] for p in pts) / 4
        cy = sum(p[1] for p in pts) / 4
        ill = Image.open(RACINE / ILLUSTRATION[cle]).convert("RGB")
        w, h = ill.size
        fx0, fy0, fx1, fy1 = ILL_CADRE[cle]
        ill_c = ill.crop((int(fx0 * w), int(fy0 * h), int(fx1 * w), int(fy1 * h)))
        ill_c.thumbnail((L1[0], L1[1]))
        cases = [("illustration (%s)" % Path(ILLUSTRATION[cle]).name, ill_c)]
        for k, nom in [("S", "éteint (sans)"), ("A1", "allumé (avec)")]:
            cases.append((nom + " 1:1", recadrer(ims[k], (cx, cy), L1)))
        for k, nom in [("S", "éteint"), ("A1", "allumé")]:
            cases.append((nom + " ×3", recadrer(ims[k], (cx, cy), L3).resize((L3[0] * 3, L3[1] * 3), Image.NEAREST)))
        cases.append(("allumé, torches éteintes 1:1", recadrer(ims["N1"], (cx, cy), L1)))
        joueur = "J2 à 45° B (caméra à 225°)" if round(lacet) in (-135, 225) else "J1, lacet %d°" % round(lacet)
        rangees.append(("« %s » — %s" % (sorte, joueur), cases))
    if not rangees:
        sys.exit("aucune prise")
    marge, entete = 12, 34
    largeur_case = max(L1[0], L3[0] * 3)
    hauteur_case = max(L1[1], L3[1] * 3) + 24
    W = marge + len(rangees[0][1]) * (largeur_case + marge)
    H = marge + len(rangees) * (entete + hauteur_case + marge)
    planche = Image.new("RGB", (W, H), (24, 24, 24))
    d = ImageDraw.Draw(planche)
    y = marge
    for titre, cases in rangees:
        d.text((marge, y + 4), titre, fill=(235, 225, 205), font=f_titre)
        y += entete
        x = marge
        for nom, im in cases:
            planche.paste(im, (x, y))
            d.text((x, y + im.size[1] + 3), nom, fill=(200, 200, 200), font=f_texte)
            x += largeur_case + marge
        y += hauteur_case + marge
    planche.save(sortie, quality=85)
    print("planche :", sortie, planche.size)


if __name__ == "__main__":
    main()
