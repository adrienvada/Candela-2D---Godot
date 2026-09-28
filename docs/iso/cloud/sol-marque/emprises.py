#!/usr/bin/env python3
"""Le sol marqué — les textures cuites du décor (`cuisson.gd --sortie=…`), avec et sans l'essai : chaque texel que l'essai
touche doit tomber dans l'emprise que promet la garde headless (`tools/test_sol_marque.gd`, `_demi_emprise`), et l'essai
ne doit qu'ASSOMBRIR (alpha qui monte, jamais de couleur). Écrit aussi une vue de dessus de chaque carte (img/carte_*.jpg).

    python3 docs/iso/cloud/sol-marque/emprises.py <dossier branche> <dossier essai>
"""
import math, os, re, sys
import numpy as np
from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
T = 35.0
FICHIERS = {"00000002": "arene_circulaire", "00000001": "default", "map_001": "map_001_le_cloitre",
            "map_002": "map_002_l_usine", "map_003": "map_003_la_croisee", "map_004": "map_004_le_bunker"}


def table():
    src = open(os.path.join(ICI, "../../../../arena_decor.gd"), encoding="utf-8").read()
    bloc = src[src.index("const SOL_MARQUE_ESSAI := {"):]
    bloc = bloc[:bloc.index("\n}\n")]
    out, cur = {}, None
    for l in bloc.splitlines():
        m = re.match(r'\t"([^"]+)": \[', l)
        if m:
            cur = out.setdefault(m.group(1), [])
            continue
        m = re.match(r'\t\t\["(\w+)", Vector2\(([-\d.]+), ([-\d.]+)\), ([-\d.]+), (.+), (\d+), (true|false)\],', l)
        if m and cur is not None:
            p = m.group(5)
            v = re.match(r"Vector2\(([-\d.]+), ([-\d.]+)\)", p)
            param = (float(v.group(1)), float(v.group(2))) if v else (p.strip('"') if p.startswith('"') else float(p))
            cur.append((m.group(1), (float(m.group(2)), float(m.group(3))), float(m.group(4)), param))
    return out


def demi(fam, p):
    # La promesse de la garde (`_demi_emprise`) ; les lettres : la boîte de la fonte à 14 px, prise large (9 px par signe).
    if fam == "gravats":
        return (p * T * 0.5 + 4.0, 5.0)
    if fam == "eclats":
        return (p * T * 0.5 + 3.0,) * 2
    if fam == "chaine":
        return (p * T * 0.5 + 4.0, 9.0)
    if fam == "cadre":
        return (p[0] * T * 0.5 + 2.0, p[1] * T * 0.5 + 2.0)
    if fam == "bande":
        return (p * T * 0.5, 2.0)
    return (len(p) * 4.5 + 1.0, 8.0)


def main():
    branche, essai = sys.argv[1], sys.argv[2]
    tab = table()
    os.makedirs(os.path.join(ICI, "img"), exist_ok=True)
    total_hors = 0
    for cid, nom in FICHIERS.items():
        a = np.asarray(Image.open(os.path.join(branche, nom + ".png")).convert("RGBA")).astype(int)
        b = np.asarray(Image.open(os.path.join(essai, nom + ".png")).convert("RGBA")).astype(int)
        change = np.abs(a - b).max(-1) > 0
        ys, xs = np.nonzero(change)
        wx, wy = xs + 0.5 - T, ys + 0.5 - T  # le cadre de la cuisson commence à (−35, −35) dans le monde
        dedans = np.zeros(len(xs), bool)
        for fam, c, ang, p in tab.get(cid, []):
            du, dv = demi(fam, p)
            cx, cy = (c[0] + 0.5) * T, (c[1] + 0.5) * T
            r = math.radians(ang)
            u = (wx - cx) * math.cos(r) + (wy - cy) * math.sin(r)
            v = -(wx - cx) * math.sin(r) + (wy - cy) * math.cos(r)
            dedans |= (np.abs(u) <= du + 1.0) & (np.abs(v) <= dv + 1.0)
        hors = int((~dedans).sum())
        total_hors += hors
        # L'essai n'ajoute que du noir : sur un texel touché, l'alpha monte ou reste, la couleur prémultipliée ne monte pas.
        eclaircis = int(((b[..., :3] * b[..., 3:4] - a[..., :3] * a[..., 3:4]).max(-1)[change] > 255).sum())
        print(f"{cid:9} {int(change.sum()):6} texels touchés, {hors} hors des emprises promises, {eclaircis} éclaircis")
        # Vue de dessus : la texture composée sur un sol gris moyen.
        fond = np.full(a.shape[:2] + (3,), 120.0)
        for img, suffixe in ((a, "sans"), (b, "avec")):
            al = img[..., 3:4] / 255.0
            comp = fond * (1 - al) + img[..., :3] * al
            Image.fromarray(comp.clip(0, 255).astype(np.uint8)).save(
                os.path.join(ICI, "img", f"carte_{cid}_{suffixe}.jpg"), quality=85)
    print("total hors emprises :", total_hors)
    sys.exit(1 if total_hors else 0)


main()
