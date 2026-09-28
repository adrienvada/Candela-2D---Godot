#!/usr/bin/env python3
"""Disque violacé — mesures avant/après sur les prises de tools/photo_disque.gd (--prises).

Lit user://disque/<avant|apres><suffixe>_<45|0>/{equite,eblouis}.png (XDG_DATA_HOME, défaut ./.xdg), écrit mesures.json
et les images de la planche dans img/. Pour chaque lacet et chaque scène :
  - le disque : pixels violacés faibles (R ≥ V+2, B ≥ V+2, 8 ≤ max < 60) par moitié ;
  - ce que le correctif change : pixels qui diffèrent de plus de 7/255 (le seuil du noir) entre avant et après, par moitié ;
  - pour l'éblouissement : la luminance moyenne de chaque moitié (le voile est plein cadre sur la moitié éblouie).
"""
import json, os, sys
import numpy as np
from PIL import Image

XDG = os.environ.get("XDG_DATA_HOME", os.path.join(os.getcwd(), ".xdg"))
SRC = os.path.join(XDG, "godot/app_userdata/Candela 2D/disque")
ICI = os.path.dirname(os.path.abspath(__file__))
SUFFIXE = os.environ.get("SUFFIXE", "2")


def charger(nom, scene):
    p = os.path.join(SRC, nom, scene + ".png")
    return np.array(Image.open(p).convert("RGB")).astype(int) if os.path.exists(p) else None


def violaces(im):
    m = (im[..., 0] - im[..., 1] >= 2) & (im[..., 2] - im[..., 1] >= 2) & (im.max(-1) >= 8) & (im.max(-1) < 60)
    w = im.shape[1] // 2
    return int(m[:, :w].sum()), int(m[:, w:].sum())


def moities(masque):
    w = masque.shape[1] // 2
    return int(masque[:, :w].sum()), int(masque[:, w:].sum())


def jpeg(im, nom, gain=1):
    Image.fromarray(np.clip(im * gain, 0, 255).astype("uint8")).save(os.path.join(ICI, "img", nom), quality=85)


sortie = {}
os.makedirs(os.path.join(ICI, "img"), exist_ok=True)
for lacet in ("45", "0"):
    for scene in ("equite", "eblouis"):
        av = charger(f"avant{SUFFIXE}_{lacet}", scene)
        ap = charger(f"apres{SUFFIXE}_{lacet}", scene)
        if av is None or ap is None:
            print("manque", lacet, scene)
            continue
        diff = np.abs(av - ap).max(-1)
        allume = (av.max(-1) - ap.max(-1)) > 7
        cle = f"{scene}_{lacet}"
        w = av.shape[1] // 2
        sortie[cle] = {
            "violaces_avant_j1_j2": violaces(av),
            "violaces_apres_j1_j2": violaces(ap),
            "differents_gt7_j1_j2": moities(diff > 7),
            "allumes_par_le_disque_j1_j2": moities(allume),
            "differents_gt0_hors_disque": int(((diff > 0) & ~(diff > 7)).sum()),
            "luminance_apres_j1_j2": [round(float(ap[:, :w].mean()), 2), round(float(ap[:, w:].mean()), 2)],
            "luminance_avant_j1_j2": [round(float(av[:, :w].mean()), 2), round(float(av[:, w:].mean()), 2)],
        }
        print(cle, sortie[cle])
        jpeg(av, f"{cle}_avant.jpg")
        jpeg(ap, f"{cle}_apres.jpg")
        if scene == "equite":
            jpeg(av, f"{cle}_avant_x6.jpg", 6)
            jpeg(ap, f"{cle}_apres_x6.jpg", 6)
            jpeg(np.repeat((diff > 0)[..., None] * 255, 3, -1), f"{cle}_difference.jpg")
json.dump(sortie, open(os.path.join(ICI, "mesures.json"), "w"), indent=1, ensure_ascii=False)
