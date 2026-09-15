"""ISO11, L2 — la bande de trente images de killcam, composée et mesurée.

Usage : python3 bande_killcam.py DOSSIER_FINS SORTIE.jpg

Compose les trente prises `NN-killcam-bande-MM.png` (dans l'ordre de prise) en une planche 6 × 5, et mesure, d'une
image à la suivante, le glissement de l'image : la translation entière (dx, dy) qui minimise l'écart moyen de
luminance sur un carré central réduit, cherchée dans ±12 px. Un saut de caméra se lit comme un glissement brusque ;
un mouvement lent comme une suite de petits glissements réguliers. PIL seul, pas de numpy (règle du dépôt).
"""
import glob
import os
import re
import sys

from PIL import Image, ImageDraw

dossier, sortie = sys.argv[1], sys.argv[2]
fichiers = sorted(glob.glob(os.path.join(dossier, "*-killcam-bande-*.png")),
                  key=lambda f: int(re.search(r"killcam-bande-(\d+)", f).group(1)))
if len(fichiers) < 30:
    sys.exit(f"{len(fichiers)} prises seulement")
images = [Image.open(f).convert("RGB") for f in fichiers[:30]]

# --- la mesure ---
ECHELLE = 4
COTE = 160
RECHERCHE = 12


def reduite(img):
    w, h = img.size
    petite = img.convert("L").resize((w // ECHELLE, h // ECHELLE), Image.BILINEAR)
    return petite


def ecart(a, b, dx, dy):
    w, h = a.size
    cx, cy = w // 2, h // 2
    total = 0
    n = 0
    pa = a.load()
    pb = b.load()
    for y in range(cy - COTE // 2, cy + COTE // 2, 2):
        for x in range(cx - COTE // 2, cx + COTE // 2, 2):
            total += abs(pa[x, y] - pb[x + dx, y + dy])
            n += 1
    return total / n


reduites = [reduite(i) for i in images]
glissements = []
for k in range(1, 30):
    a, b = reduites[k - 1], reduites[k]
    meilleur = None
    for dy in range(-RECHERCHE // ECHELLE * 2, RECHERCHE // ECHELLE * 2 + 1):
        for dx in range(-RECHERCHE // ECHELLE * 2, RECHERCHE // ECHELLE * 2 + 1):
            e = ecart(a, b, dx, dy)
            if meilleur is None or e < meilleur[0]:
                meilleur = (e, dx, dy)
    identique = ecart(a, b, 0, 0)
    glissements.append((meilleur[1] * ECHELLE, meilleur[2] * ECHELLE, meilleur[0], identique))

for k, (dx, dy, e, e0) in enumerate(glissements, start=2):
    print(f"  {k - 1:02d}→{k:02d} glissement ({dx:+d}, {dy:+d}) px écran, écart résiduel {e:.2f}, sans glissement {e0:.2f}")
plus_grand = max(abs(dx) + abs(dy) for dx, dy, _e, _e0 in glissements)
print(f"MESURE plus grand glissement d'une image à la suivante : {plus_grand} px d'écran (pas de mesure {ECHELLE} px)")

# --- la planche ---
COL, LIG = 6, 5
L_CASE = 480
H_CASE = int(L_CASE * images[0].size[1] / images[0].size[0])
BANDEAU = 22
planche = Image.new("RGB", (COL * L_CASE, LIG * (H_CASE + BANDEAU) + 40), (12, 11, 10))
d = ImageDraw.Draw(planche)
d.text((8, 12), "ISO11 L2 — la killcam, trente images de suite dès le début du rejeu", fill=(230, 180, 90))
for i, img in enumerate(images):
    x = (i % COL) * L_CASE
    y = 40 + (i // COL) * (H_CASE + BANDEAU)
    planche.paste(img.resize((L_CASE, H_CASE), Image.LANCZOS), (x, y))
    etiquette = f"{i + 1:02d}"
    if i > 0:
        dx, dy, _e, _e0 = glissements[i - 1]
        etiquette += f"  glissement ({dx:+d}, {dy:+d})"
    d.text((x + 6, y + H_CASE + 4), etiquette, fill=(200, 200, 200))
planche.save(sortie, quality=88)
print("planche", sortie, planche.size)
