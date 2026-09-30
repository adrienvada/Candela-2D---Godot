#!/usr/bin/env python3
"""Q71 À L'IMAGE — le modelé des corps vu par J1 et par J2 (plan `loupe-modele-q71`, `tools/loupe_modele_q71.gd`).

Écran scindé : la moitié gauche est la vue de J1, la droite celle de J2. Chacun regarde l'ADVERSAIRE : le corps de J2 dans
la vue de J1, le corps de J1 dans la vue de J2 — même classe, dos à dos, même lumière posée. Pour chaque corps regardé :
  - ses pixels, et la face de chacun, lus dans la prise `idN` (le corps peint de sa normale MONDE) contre `fond` ;
  - érodés d'un pixel (les arêtes : encre et anticrénelage) ;
  - par face — le dessus, et chaque face latérale nommée par sa normale MONDE (+x, −x, +z, −z) —, le nombre de pixels, la
    moyenne de luminance de `m1` (le jeu, en valeurs affichées, Rec. 709) et le FACTEUR de modelé (médiane de m1 / m0, sur
    les pixels où m0 dépasse 8/255).
Les faces se jumellent par le demi-tour qui envoie un joueur sur l'autre (la face +x du corps de J2 vue par J1 est la face
−x du corps de J1 vue par J2) : l'équité, c'est chaque paire égale. Critère écrit d'avance : chaque paire au même facteur
à 0,01 près, et aux mêmes moyennes à 2/255 près (la pâte a un motif lié à la position dans le monde).

    python3 tools/modele_q71/mesurer.py <dossier des prises> <sortie> [étiquette]

Sort 1 si une paire diffère. numpy et Pillow requis."""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

D, S = sys.argv[1], sys.argv[2]
ETIQ = sys.argv[3] if len(sys.argv) > 3 else ""
ID = "loupe-modele-q71"
os.makedirs(S, exist_ok=True)


def police(taille=13):
    for chemin in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/System/Library/Fonts/Supplemental/Arial.ttf",
                   "/Library/Fonts/Arial Unicode.ttf"):
        if os.path.exists(chemin):
            return ImageFont.truetype(chemin, taille)
    return ImageFont.load_default(size=taille)


def lire(suffixe):
    f = sorted(glob.glob(os.path.join(D, "*%s-%s.png" % (ID, suffixe))))
    if not f:
        sys.exit("✗ prise %s manquante dans %s" % (suffixe, D))
    return np.asarray(Image.open(f[-1]).convert("RGB")).astype(np.float64)


def luminance(img):
    return img[..., 0] * 0.2126 + img[..., 1] * 0.7152 + img[..., 2] * 0.0722


m1, m0, fond = lire("m1"), lire("m0"), lire("fond")
ids = [lire("id1"), lire("id2")]
h, w = m1.shape[:2]
moities = {0: slice(0, w // 2), 1: slice(w // 2, w)}   # 0 : la vue de J1, 1 : la vue de J2


def faces(corps, vue):
    """Les pixels du corps `corps` (0 : J1, 1 : J2) dans la vue `vue`, par face (normale monde)."""
    idc = ids[corps]
    sl = moities[vue]
    masque = np.zeros((h, w), bool)
    masque[:, sl] = np.any(np.abs(idc[:, sl] - fond[:, sl]) > 0, axis=2)
    # Érodé d'un pixel : les arêtes portent l'encre et l'anticrénelage.
    er = masque.copy()
    er[1:, :] &= masque[:-1, :]
    er[:-1, :] &= masque[1:, :]
    er[:, 1:] &= masque[:, :-1]
    er[:, :-1] &= masque[:, 1:]
    n = idc / 255.0 * 2.0 - 1.0
    classes = {}
    dessus = er & (n[..., 1] > 0.5)
    classes["dessus"] = dessus
    cote = er & (np.abs(n[..., 1]) <= 0.5)
    selon_x = np.abs(n[..., 0]) >= np.abs(n[..., 2])
    classes["+x"] = cote & selon_x & (n[..., 0] > 0)
    classes["-x"] = cote & selon_x & (n[..., 0] < 0)
    classes["+z"] = cote & ~selon_x & (n[..., 2] > 0)
    classes["-z"] = cote & ~selon_x & (n[..., 2] < 0)
    return masque, classes


l1, l0 = luminance(m1), luminance(m0)
rapport = {}
lignes = []
# Le corps de J2 vu par J1 (vue 0), le corps de J1 vu par J2 (vue 1).
regards = {"J1 regarde J2": (1, 0), "J2 regarde J1": (0, 1)}
mesures = {}
for nom, (corps, vue) in regards.items():
    masque, classes = faces(corps, vue)
    r = {"pixels": int(masque.sum())}
    for face, c in classes.items():
        if c.sum() < 20:
            continue
        ok = c & (l0 > 8.0)
        facteur = float(np.median(l1[ok] / l0[ok])) if ok.sum() > 0 else float("nan")
        r[face] = {"pixels": int(c.sum()), "moyenne": round(float(l1[c].mean()), 2),
                   "moyenne_sans_modele": round(float(l0[c].mean()), 2), "facteur": round(facteur, 4)}
    mesures[nom] = r
    print("%s%s (le corps de J%d, dans la vue de J%d) : %d pixels" % ("[%s] " % ETIQ if ETIQ else "", nom, corps + 1, vue + 1,
                                                                     r["pixels"]))
    for face in ["dessus", "+x", "-x", "+z", "-z"]:
        if face in r:
            f = r[face]
            print("    %-6s %5d px · moyenne %6.2f/255 (sans modelé %6.2f) · facteur %.3f"
                  % (face, f["pixels"], f["moyenne"], f["moyenne_sans_modele"], f["facteur"]))
rapport["mesures"] = mesures
# Les paires : la face F du corps de J2 vue par J1, contre la face « F tournée d'un demi-tour » du corps de J1 vue par J2.
demi_tour = {"dessus": "dessus", "+x": "-x", "-x": "+x", "+z": "-z", "-z": "+z"}
a, b = mesures["J1 regarde J2"], mesures["J2 regarde J1"]
ok = True
paires = []
for face in ["dessus", "+x", "-x", "+z", "-z"]:
    if face not in a or demi_tour[face] not in b:
        continue
    fa, fb = a[face], b[demi_tour[face]]
    df = abs(fa["facteur"] - fb["facteur"])
    dm = abs(fa["moyenne"] - fb["moyenne"])
    bon = df <= 0.01 and dm <= 2.0
    ok = ok and bon
    paires.append({"face_J2_vue_par_J1": face, "face_J1_vue_par_J2": demi_tour[face], "facteurs": [fa["facteur"], fb["facteur"]],
                   "moyennes": [fa["moyenne"], fb["moyenne"]], "egales": bon})
    print("  %s %-6s ↔ %-6s : facteur %.3f / %.3f · moyenne %6.2f / %6.2f /255"
          % ("✓" if bon else "✗", face, demi_tour[face], fa["facteur"], fb["facteur"], fa["moyenne"], fb["moyenne"]))
rapport["paires"] = paires
rapport["egales"] = ok
json.dump(rapport, open(os.path.join(S, "mesures%s.json" % ("_" + ETIQ if ETIQ else "")), "w"), ensure_ascii=False, indent=1)

# La planche : pour chaque regard, le corps (m1), le facteur en fausses couleurs (bleu 0,9 · gris 1,0 · orange 1,15).
POLICE = police()
tuiles = []
for nom, (corps, vue) in regards.items():
    masque, _ = faces(corps, vue)
    ys, xs = np.nonzero(masque)
    if len(xs) == 0:
        continue
    x0, x1 = max(0, xs.min() - 12), min(w, xs.max() + 13)
    y0, y1 = max(0, ys.min() - 12), min(h, ys.max() + 13)
    crop = m1[y0:y1, x0:x1].astype(np.uint8)
    f = np.where(masque, l1 / np.maximum(l0, 1.0), 0.0)[y0:y1, x0:x1]
    carte = np.zeros(crop.shape, np.uint8)
    carte[(f > 0.85) & (f < 0.95)] = (60, 120, 255)
    carte[(f >= 0.95) & (f < 1.07)] = (150, 150, 150)
    carte[(f >= 1.07) & (f < 1.25)] = (255, 160, 40)
    z = 6
    t1 = Image.fromarray(crop).resize((crop.shape[1] * z, crop.shape[0] * z), Image.NEAREST)
    t2 = Image.fromarray(carte).resize((crop.shape[1] * z, crop.shape[0] * z), Image.NEAREST)
    tuile = Image.new("RGB", (t1.width * 2 + 8, t1.height + 24), (16, 16, 16))
    tuile.paste(t1, (0, 24))
    tuile.paste(t2, (t1.width + 8, 24))
    ImageDraw.Draw(tuile).text((4, 4), "%s — l'image | le facteur (bleu 0,9 · gris 1 · orange 1,15)" % nom,
                                fill=(230, 230, 230), font=POLICE)
    tuiles.append(tuile)
if tuiles:
    W = sum(t.width for t in tuiles) + 8 * (len(tuiles) - 1)
    H = max(t.height for t in tuiles) + 28
    planche = Image.new("RGB", (W, H), (8, 8, 8))
    x = 0
    for t in tuiles:
        planche.paste(t, (x, 28))
        x += t.width + 8
    ImageDraw.Draw(planche).text((4, 6), "Q71 %s — même corps, même lumière, vu par J1 puis par J2 (45° B) : %s"
                                 % (ETIQ, "les faces jumelles sont égales" if ok else "des faces jumelles DIFFÈRENT"),
                                 fill=(230, 230, 230), font=POLICE)
    planche.save(os.path.join(S, "planche_q71%s.jpg" % ("_" + ETIQ if ETIQ else "")), quality=88)
print("\n%s" % ("✓ chaque face jumelle a le même facteur et la même moyenne, vue par J1 et par J2" if ok
                else "✗ des faces jumelles diffèrent entre J1 et J2"))
sys.exit(0 if ok else 1)
