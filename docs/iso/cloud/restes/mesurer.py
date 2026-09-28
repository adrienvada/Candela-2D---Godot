#!/usr/bin/env python3
"""Mesures et images de la session « restes ».

  mesurer.py traces <dossier photo_restes> <nom>   : A (traces présentes) contre B (retirées), B contre B2 (bruit)
  mesurer.py regard <dossier photo_regard> <nom>   : pour chaque paire <x>_ui / <x>_sansui, les pixels que
                                                      l'interface allume dans le noir, groupés en taches
Un pixel est noir à ≤ 7 au canal maximal (le seuil des sessions « sol marqué »). Images : JPEG qualité 85 dans img/.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ICI = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(ICI, "img")
NOIR = 7


def lire(chemin):
    return np.asarray(Image.open(chemin).convert("RGB")).astype(int)


def boite(masque):
    ys, xs = np.nonzero(masque)
    if len(xs) == 0:
        return None
    return [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]


def taches(masque, image):
    etiq, n = ndimage.label(masque, structure=np.ones((3, 3)))
    sortie = []
    for i, sl in enumerate(ndimage.find_objects(etiq), start=1):
        m = etiq[sl] == i
        px = image[sl][m]
        sortie.append({"boite": [sl[1].start, sl[0].start, sl[1].stop - 1, sl[0].stop - 1], "pixels": int(m.sum()),
                       "max": int(px.max()), "couleur_moyenne": [round(float(c), 1) for c in px.mean(0)]})
    return sorted(sortie, key=lambda t: -t["pixels"])


def enregistrer(img, nom):
    os.makedirs(IMG, exist_ok=True)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(IMG, nom + ".jpg"), quality=85)


def traces(dossier, nom):
    a, b, b2 = (lire(os.path.join(dossier, f"{x}.png")) for x in ("A", "B", "B2"))
    d = np.abs(a - b).max(2)
    bruit = np.abs(b - b2).max(2)
    noirs_allumes = (b.max(2) <= NOIR) & (a.max(2) > NOIR)
    r = {"A≠B (>7)": int((d > 7).sum()), "A≠B (>0)": int((d > 0).sum()), "écart max": int(d.max()),
         "boîte": boite(d > 7), "noirs de B allumés dans A": int(noirs_allumes.sum()),
         "bruit B→B2 (>0)": int((bruit > 0).sum())}
    print(nom, json.dumps(r, ensure_ascii=False))
    # Planche : A | B, recadrées sur la boîte des différences (marge 120 px), et la différence en blanc.
    bx = boite(d > 7) or [0, 0, a.shape[1] - 1, a.shape[0] - 1]
    x0, y0 = max(0, bx[0] - 120), max(0, bx[1] - 120)
    x1, y1 = min(a.shape[1], bx[2] + 120), min(a.shape[0], bx[3] + 120)
    diff = np.repeat(((d > 7) * 255)[..., None], 3, 2)
    planche = np.concatenate([a[y0:y1, x0:x1], np.full((y1 - y0, 8, 3), 255), b[y0:y1, x0:x1],
                              np.full((y1 - y0, 8, 3), 255), diff[y0:y1, x0:x1]], 1)
    enregistrer(planche, f"{nom}_A_B_difference")
    return r


def regard(dossier, nom):
    res = {}
    for f in sorted(os.listdir(dossier)):
        if not f.endswith("_ui.png"):
            continue
        x = f[:-7]
        avec, sans = lire(os.path.join(dossier, f)), lire(os.path.join(dossier, f"{x}_sansui.png"))
        fuite = (sans.max(2) <= NOIR) & (avec.max(2) > NOIR)
        # Les cadres du HUD sont légitimes : on ne garde que les taches de moins de 400 pixels hors du bandeau du haut
        # (les yeux font une trentaine de pixels) ; tout le reste est listé à part.
        t = taches(fuite, avec)
        petites = [z for z in t if z["pixels"] < 400 and z["boite"][1] > 200]
        res[x] = {"fuite totale": int(fuite.sum()), "taches": len(t), "petites hors HUD": petites[:10],
                  "grandes": [z for z in t if z not in petites][:6]}
        print(nom, x, json.dumps(res[x], ensure_ascii=False))
        for i, z in enumerate(petites[:2]):
            cx, cy = (z["boite"][0] + z["boite"][2]) // 2, (z["boite"][1] + z["boite"][3]) // 2
            x0, y0 = max(0, cx - 60), max(0, cy - 40)
            vignette = avec[y0:y0 + 80, x0:x0 + 120]
            grand = np.kron(vignette, np.ones((6, 6, 1), dtype=int))
            enregistrer(np.clip(grand * 4, 0, 255), f"{nom}_{x}_tache{i}_x6_eclaircie4")
    return res


if __name__ == "__main__":
    genre, dossier, nom = sys.argv[1:4]
    out = traces(dossier, nom) if genre == "traces" else regard(dossier, nom)
    chemin = os.path.join(ICI, "mesures.json")
    tout = json.load(open(chemin)) if os.path.exists(chemin) else {}
    tout[nom] = out
    json.dump(tout, open(chemin, "w"), ensure_ascii=False, indent=1)
