#!/usr/bin/env python3
"""Sol marqué 2 — les images du rapport, depuis les prises de `tools/photo_sol_marque_noir.gd`.

    python3 images.py "<dossier user://sm2>" cause      # img/cause_*.jpg : la loupe du défaut, et le témoin plein cadre
    python3 images.py "<dossier user://sm2>" preuve     # img/preuve_*.jpg : les six cartes, A et B, vue unique et scindée

Les prises noires sont éclaircies (×4) pour que l'œil voie le sol éclairé par les LED ; les mesures, elles, se font sur les
PNG bruts (`noir.py`, `entre.py`). JPEG qualité 85.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(ICI, "img")
try:
    FONTE = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
except OSError:
    FONTE = ImageFont.load_default()


def lire(p):
    return np.asarray(Image.open(p).convert("RGB")).astype(float)


def eclaircir(a, g=4.0):
    return Image.fromarray(np.clip(a * g, 0, 255).astype("uint8"))


def loupe(a, cx, cy, w=120, h=70, g=4.0, z=2):
    c = a[cy - h:cy + h, cx - w:cx + w]
    return eclaircir(c, g).resize((2 * w * z, 2 * h * z), Image.NEAREST)


def planche(images, legendes, colonnes, sortie):
    w, h = images[0].size
    lignes = (len(images) + colonnes - 1) // colonnes
    pl = Image.new("RGB", (colonnes * w + (colonnes - 1) * 10, lignes * (h + 28)), (18, 18, 18))
    dr = ImageDraw.Draw(pl)
    for i, (im, t) in enumerate(zip(images, legendes)):
        x = (i % colonnes) * (w + 10)
        y = (i // colonnes) * (h + 28) + 24
        pl.paste(im, (x, y))
        dr.text((x + 6, y - 21), t, fill=(235, 235, 235), font=FONTE)
    pl.save(sortie, quality=85)
    print("écrit :", sortie)


def cause(rep):
    cas = [("direct_temoin", "Croisée posée directement, sans essai"),
           ("essai2", "Croisée posée directement, sol marqué"),
           ("par_temoin", "par le Cloître, sans essai"),
           ("par_avec", "par le Cloître, sol marqué — les taches")]
    ims = [loupe(lire(f"{rep}/{d}/map_003_la_croisee_noir_A.png"), 1041, 305) for d, _ in cas]
    planche(ims, [t for _, t in cas], 2, os.path.join(IMG, "cause_loupe.jpg"))
    for d, n in [("direct_temoin", "cause_direct_temoin"), ("par_temoin", "cause_par_cloitre_temoin")]:
        eclaircir(lire(f"{rep}/{d}/map_003_la_croisee_noir_A.png")).resize((960, 540), Image.LANCZOS) \
            .save(os.path.join(IMG, n + ".jpg"), quality=85)
        print("écrit :", n)


def preuve(rep):
    for scene in ["noir", "noir_scinde", "allume", "allume_scinde"]:
        ims, leg = [], []
        for a in sorted(glob.glob(f"{rep}/*_{scene}_A.png")):
            carte = os.path.basename(a)[:-len(f"_{scene}_A.png")]
            g = 4.0 if scene.startswith("noir") else 1.0
            for k, t in [("A", "marques"), ("B", "sans marques")]:
                ims.append(eclaircir(lire(f"{rep}/{carte}_{scene}_{k}.png"), g).resize((640, 360), Image.LANCZOS))
                leg.append(f"{carte} · {t}")
        if ims:
            planche(ims, leg, 2, os.path.join(IMG, f"preuve_{scene}.jpg"))


if __name__ == "__main__":
    os.makedirs(IMG, exist_ok=True)
    {"cause": cause, "preuve": preuve}[sys.argv[2]](sys.argv[1])
