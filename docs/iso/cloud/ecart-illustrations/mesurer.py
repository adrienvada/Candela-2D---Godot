#!/usr/bin/env python3
"""L'écart du jeu à ses illustrations — les chiffres et les JPEG.

Lit les prises de `tools/photo_ecart.gd` (user://ecart/{defaut,temoin,tous}/<scene>.png, ou $ECART_SOURCE) et les vingt
illustrations `assets/ui/ill_*.png`. Écrit `img/` (JPEG qualité 85 : illustrations à 1024 de large, prises à 1920×1080) et
`mesures.json`.

Les mesures, toutes en valeurs sRGB 0..255 :
- `eclaire` : la part de l'image plus claire que 7,5/255 au canal maximal (le seuil « noir » des bancs du projet) — ce que
  l'image MONTRE ; `noir_strict` : la part à 0 exactement ;
- `lum_moy` : la luminance moyenne (Rec. 709 des valeurs sRGB, la règle des pochoirs) ; `lum_eclaire` : celle des seuls
  pixels éclairés ; `teinte` : la couleur moyenne des pixels éclairés, et `chroma` son écart au gris ;
- entre `tous` et `defaut` : les pixels qui changent de plus de 8/255 (au-delà du bruit mesuré entre `defaut` et `temoin`),
  ceux qui deviennent plus clairs, et ceux qui étaient noirs (≤ 7,5) et s'allument — le noir absolu.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.normpath(os.path.join(ICI, "../../../.."))
SOURCE = os.environ.get("ECART_SOURCE") or os.path.expanduser(
    os.path.join(os.environ.get("XDG_DATA_HOME", "~/.local/share"), "godot/app_userdata/Candela 2D/ecart"))
LANCEMENTS = ["defaut", "temoin", "tous"]
SCENES = ["duel", "noir", "scinde", "sol", "mur", "arena", "zone", "impacts", "fusee1", "fusee2", "entrainement"]
SEUIL_NOIR = 7.5
SEUIL_CHANGE = 8


def lire(chemin):
    return np.asarray(Image.open(chemin).convert("RGB")).astype(np.float32)


def stats(a):
    mx = a.max(axis=2)
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    ecl = mx > SEUIL_NOIR
    sortie = {
        "eclaire": round(float(ecl.mean()), 4),
        "noir_strict": round(float((mx == 0).mean()), 4),
        "lum_moy": round(float(lum.mean()), 2),
    }
    if ecl.any():
        teinte = a[ecl].mean(axis=0)
        sortie["lum_eclaire"] = round(float(lum[ecl].mean()), 2)
        sortie["teinte"] = [int(round(v)) for v in teinte]
        sortie["chroma"] = round(float(teinte.max() - teinte.min()), 1)
    return sortie


def ecart(a, b):
    """Ce qui change de a (défaut) à b (essais)."""
    d = np.abs(b - a).max(axis=2)
    lum_a = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    lum_b = 0.2126 * b[..., 0] + 0.7152 * b[..., 1] + 0.0722 * b[..., 2]
    noirs = a.max(axis=2) <= SEUIL_NOIR
    return {
        "change": int((d > SEUIL_CHANGE).sum()),
        "plus_clair": int((lum_b - lum_a > SEUIL_CHANGE).sum()),
        "plus_sombre": int((lum_a - lum_b > SEUIL_CHANGE).sum()),
        "noir_allume": int((noirs & (b.max(axis=2) > SEUIL_NOIR)).sum()),
        "noir_strict_allume": int(((a.max(axis=2) == 0) & (b.max(axis=2) > 0)).sum()),
    }


def jpeg(tableau_ou_chemin, sortie, largeur=None):
    img = Image.open(tableau_ou_chemin).convert("RGB") if isinstance(tableau_ou_chemin, str) else tableau_ou_chemin
    if largeur and img.width > largeur:
        img = img.resize((largeur, round(img.height * largeur / img.width)), Image.LANCZOS)
    img.save(sortie, quality=85, optimize=True)


def boite_loupe(a):
    """Le cadre 640×360 centré sur la lumière de la prise par défaut (barycentre des pixels de luminance > 60), borné à
    l'image : la même boîte sert aux deux prises, pour les comparer au même endroit."""
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    ys, xs = np.nonzero(lum > 60)
    h, w = lum.shape
    cx, cy = (float(xs.mean()), float(ys.mean())) if xs.size else (w / 2, h / 2)
    x0 = int(min(max(cx - 320, 0), w - 640))
    y0 = int(min(max(cy - 180, 0), h - 360))
    return (x0, y0, x0 + 640, y0 + 360)


def main():
    os.makedirs(os.path.join(ICI, "img"), exist_ok=True)
    mesures = {"source": SOURCE, "illustrations": {}, "prises": {}, "ecarts": {}, "bruit": {}}
    ill_dir = os.path.join(RACINE, "assets/ui")
    for nom in sorted(f for f in os.listdir(ill_dir) if f.startswith("ill_") and f.endswith(".png")):
        chemin = os.path.join(ill_dir, nom)
        a = lire(chemin)
        s = stats(a)
        s["taille"] = [a.shape[1], a.shape[0]]
        mesures["illustrations"][nom[:-4]] = s
        jpeg(chemin, os.path.join(ICI, "img", nom[:-4] + ".jpg"), 1024)
    manquantes = []
    for scene in SCENES:
        images = {}
        for lanc in LANCEMENTS:
            chemin = os.path.join(SOURCE, lanc, scene + ".png")
            if not os.path.exists(chemin):
                manquantes.append(f"{lanc}/{scene}")
                continue
            images[lanc] = lire(chemin)
            mesures["prises"][f"{lanc}/{scene}"] = stats(images[lanc])
            if lanc != "temoin":
                jpeg(chemin, os.path.join(ICI, "img", f"jeu_{lanc}_{scene}.jpg"))
        if "defaut" in images:
            boite = boite_loupe(images["defaut"])
            mesures.setdefault("loupes", {})[scene] = list(boite)
            for lanc in ("defaut", "tous"):
                if lanc in images:
                    img = Image.fromarray(images[lanc].astype(np.uint8)).crop(boite).resize((1280, 720), Image.LANCZOS)
                    jpeg(img, os.path.join(ICI, "img", f"loupe_{lanc}_{scene}.jpg"))
        if "defaut" in images and "temoin" in images:
            mesures["bruit"][scene] = ecart(images["defaut"], images["temoin"])
        if "defaut" in images and "tous" in images:
            mesures["ecarts"][scene] = ecart(images["defaut"], images["tous"])
    mesures["manquantes"] = manquantes
    with open(os.path.join(ICI, "mesures.json"), "w", encoding="utf-8") as f:
        json.dump(mesures, f, ensure_ascii=False, indent=1)
    print(f"{len(mesures['prises'])} prises, {len(manquantes)} manquantes : {manquantes}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
