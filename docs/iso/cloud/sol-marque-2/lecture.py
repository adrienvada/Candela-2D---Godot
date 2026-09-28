#!/usr/bin/env python3
"""Sol marqué 2 — ce que les murs LISENT de la peinture du sol, carte par carte.

La face d'un mur haut et le liseré de son sommet lisent la lumière du sol à `pied` px devant l'arête (`mur_iso.gdshader`,
`lire_lumiere_moyenne`), en quatre lectures à ±0,625 et ±1,875 px le long d'elle, et DIVISENT chaque lecture par la
peinture de la carte (`lire_lumiere` : l × réf ÷ max(peinture, plancher)). `pied` vaut 12 px en jeu : `presentation_3d.gd`
pose 8, puis `IsoMateriaux.accorder_mur` repose `PIED_FACE_PX` = 12 juste après.

Ce script prend la texture cuite du décor (`docs/iso/cloud/sol-marque/cuisson.gd`, 1 texel par pixel du monde, le coin du
cadre en (−35, −35) — celle que la peinture recopie texel pour texel), sans et avec un essai, la compose sur le sol, et lit
la peinture comme le shader : filtrage bilinéaire, les quatre lectures, la division, la moyenne. Il imprime, pour chaque arête
exposée de mur haut, le GAIN de la lecture (lecture avec l'essai ÷ lecture sans) : 1 partout où l'essai ne touche pas la
lecture ; au-dessus de 1, la face et le liseré sortent PLUS CLAIRS que sans l'essai, sous la même lumière.

    python3 lecture.py grilles.json <cuisson sans> <cuisson avec> [--json sortie.json]
"""
import json
import sys

import numpy as np
from PIL import Image

ORIGINE = -35.0            # le coin du cadre, en pixels du monde (une case de bordure)
SOL = (0.148 + 0.178) / 2  # le gris moyen du sol dessiné (CandelaTileSet.SOL_DESSIN_A/B), la référence de la division
PLANCHER = 0.05            # IsoMateriaux.PEINTURE_PLANCHER_AFFICHE
TAPS = (-1.875, -0.625, 0.625, 1.875)
PAS = 0.25                 # le pas le long de l'arête, en pixels du monde


def peinture(chemin):
    """La peinture du sol sous le décor : le décor (RGBA) posé sur le gris du sol, canal vert (le plus lumineux)."""
    im = np.asarray(Image.open(chemin).convert("RGBA")).astype(np.float64) / 255.0
    a = im[..., 3]
    return im[..., 1] * a + SOL * (1.0 - a)


def bilineaire(p, x, y):
    """`texture(peinture, uv)` en filtrage linéaire : les centres des texels sont en ORIGINE + i + 0,5."""
    u = x - ORIGINE - 0.5
    v = y - ORIGINE - 0.5
    i0 = np.floor(u).astype(int)
    j0 = np.floor(v).astype(int)
    fu = u - i0
    fv = v - j0
    h, w = p.shape
    i0 = np.clip(i0, 0, w - 2)
    j0 = np.clip(j0, 0, h - 2)
    return (p[j0, i0] * (1 - fu) * (1 - fv) + p[j0, i0 + 1] * fu * (1 - fv)
            + p[j0 + 1, i0] * (1 - fu) * fv + p[j0 + 1, i0 + 1] * fu * fv)


def aretes(carte):
    """Les arêtes exposées des murs hauts, par case : (origine de l'arête, direction le long, sortie), en px du monde."""
    t = carte["tuile"]
    murs = set()
    for x, y, w, h in carte["hauts"]:
        for i in range(int(round(x / t)), int(round((x + w) / t))):
            for j in range(int(round(y / t)), int(round((y + h) / t))):
                murs.add((i, j))
    out = []
    for (i, j) in murs:
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (i + di, j + dj) in murs:
                continue
            # L'arête du côté (di, dj) de la case, parcourue de a à a + le_long × t.
            if di == 1:
                a, le_long = ((i + 1) * t, j * t), (0, 1)
            elif di == -1:
                a, le_long = (i * t, j * t), (0, 1)
            elif dj == 1:
                a, le_long = (i * t, (j + 1) * t), (1, 0)
            else:
                a, le_long = (i * t, j * t), (1, 0)
            out.append(((i, j), np.array(a, float), np.array(le_long, float), np.array((di, dj), float)))
    return out


def lire(p, pied, arete, t):
    """La lecture moyenne (quatre lectures divisées puis moyennées), en chaque point du liseré le long de l'arête."""
    _, a, le_long, sortie = arete
    s = np.arange(0.0, t + 1e-9, PAS)
    base = a[None, :] + s[:, None] * le_long[None, :] + sortie[None, :] * pied
    total = np.zeros(len(s))
    for k in TAPS:
        q = base + k * le_long[None, :]
        total += SOL / np.maximum(bilineaire(p, q[:, 0], q[:, 1]), PLANCHER)
    return s, total / len(TAPS)


def main():
    args = sys.argv[1:]
    sortie_json = None
    if "--json" in args:
        k = args.index("--json")
        sortie_json = args[k + 1]
        del args[k:k + 2]
    grilles = json.load(open(args[0]))
    rep_sans, rep_avec = args[1], args[2]
    bilan = {}
    for nom, carte in grilles.items():
        t = carte["tuile"]
        pied = carte["pied"]
        p0 = peinture(f"{rep_sans}/{nom}.png")
        p1 = peinture(f"{rep_avec}/{nom}.png")
        fautes = []
        for ar in aretes(carte):
            s, l0 = lire(p0, pied, ar, t)
            _, l1 = lire(p1, pied, ar, t)
            gain = l1 / l0
            k = int(np.argmax(gain))
            if gain[k] > 1.0 + 1e-6:
                (i, j), a, le_long, sortie = ar
                q = a + s[k] * le_long + sortie * pied
                # La peinture la plus sombre sous les quatre lectures, avec et sans l'essai.
                taps = [q + tk * le_long for tk in TAPS]
                pmin1 = min(float(bilineaire(p1, np.array([x]), np.array([y]))[0]) for x, y in taps)
                pmin0 = min(float(bilineaire(p0, np.array([x]), np.array([y]))[0]) for x, y in taps)
                fautes.append({"case": [i, j], "sortie": sortie.astype(int).tolist(), "point": [round(q[0], 2), round(q[1], 2)],
                               "gain": round(float(gain[k]), 4), "peinture_sans": round(pmin0, 4),
                               "peinture_avec": round(pmin1, 4), "longueur_touchee_px": float(np.sum(gain > 1.0 + 1e-6) * PAS)})
        fautes.sort(key=lambda f: -f["gain"])
        bilan[nom] = {"id": carte["id"], "aretes": len(aretes(carte)), "touchees": len(fautes),
                      "gain_max": fautes[0]["gain"] if fautes else 1.0, "fautes": fautes}
        print(f"{nom:20s} ({carte['id']}) : {len(fautes):3d} arêtes lues autrement sur {bilan[nom]['aretes']}"
              f" · gain max {bilan[nom]['gain_max']:.3f}")
        for f in fautes[:6]:
            print(f"    case {f['case']} sortie {f['sortie']} lecture en {f['point']} : gain ×{f['gain']:.3f}"
                  f" (peinture {f['peinture_sans']:.3f} → {f['peinture_avec']:.3f}), sur {f['longueur_touchee_px']:.1f} px")
    if sortie_json:
        json.dump(bilan, open(sortie_json, "w"), indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
