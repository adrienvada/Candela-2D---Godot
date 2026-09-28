#!/usr/bin/env python3
"""Sol marqué 2 — le noir absolu sur les prises triples A / B / A' (`tools/photo_sol_marque_noir.gd`).

Un pixel est NOIR s'il vaut au plus 7 au canal max (le seuil de l'évaluation 11 : ≤ 7,5). Pour chaque prise :
  allumés par l'essai = noirs dans B (marques retirées) et allumés dans A (marques) ;
  bruit              = noirs dans A et allumés dans A' (les marques retirées puis remises : le protocole seul).
Et, pour tous les pixels, « plus clairs que sans l'essai » : A − B > 0 sur un canal (de combien, combien de pixels).

    python3 noir.py <dossier des prises> [--json sortie.json]
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

SEUIL = 7


def lire(c):
    return np.asarray(Image.open(c).convert("RGB")).astype(int)


def main():
    rep = sys.argv[1]
    bilan = {}
    for a_chemin in sorted(glob.glob(os.path.join(rep, "*_A.png"))):
        nom = os.path.basename(a_chemin)[:-6]
        if nom.endswith("_peinture"):
            continue
        a = lire(a_chemin)
        b = lire(os.path.join(rep, nom + "_B.png"))
        a2 = lire(os.path.join(rep, nom + "_A2.png"))
        ma, mb, ma2 = a.max(2), b.max(2), a2.max(2)
        allumes = (mb <= SEUIL) & (ma > SEUIL)
        bruit = (ma <= SEUIL) & (ma2 > SEUIL)
        plus_clair = (a - b).max(2)
        ys, xs = np.nonzero(allumes)
        r = {"noirs_B": int((mb <= SEUIL).sum()), "allumes_par_l_essai": int(allumes.sum()), "bruit": int(bruit.sum()),
             "valeur_max_allumee": int(ma[allumes].max()) if allumes.any() else 0,
             "plus_clairs_1": int((plus_clair >= 1).sum()), "plus_clairs_2": int((plus_clair >= 2).sum()),
             "eclaircissement_max": int(plus_clair.max()),
             "changes": int((np.abs(a - b).max(2) > 0).sum()),
             "points": [[int(x), int(y), a[y, x].tolist(), b[y, x].tolist()] for x, y in list(zip(xs, ys))[:12]]}
        bilan[nom] = r
        print(f"{nom:36s} noirs {r['noirs_B']:8d} · allumés par l'essai {r['allumes_par_l_essai']:4d} (max {r['valeur_max_allumee']:3d})"
              f" · bruit {r['bruit']:4d} · plus clairs ≥1 {r['plus_clairs_1']:5d}, ≥2 {r['plus_clairs_2']:5d} (max +{r['eclaircissement_max']})"
              f" · changés {r['changes']}")
        for p in r["points"][:6]:
            print("     ", p)
    if "--json" in sys.argv:
        json.dump(bilan, open(sys.argv[sys.argv.index("--json") + 1], "w"), indent=1)


if __name__ == "__main__":
    main()
