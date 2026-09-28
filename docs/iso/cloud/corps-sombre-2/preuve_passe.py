#!/usr/bin/env python3
"""Q39 (2) — la preuve à l'image du correctif de pré-passe, sous llvmpipe (critère de l'ordre 426).

Pour chaque prise `<cfg>_<classe>_<lumiere>.png` du banc des corps, on la compare à `<...>_sp.png`, la MÊME scène (même
drapeaux, `--temps-fixe`) avec les passes de profondeur cachées (`--sans-profondeur`) : sans pré-passe, aucune pièce ne peut
perdre le test contre SA propre pré-passe ; c'est la référence de l'ordre 422. Les corps sont opaques (silhouette de soi à
0,5 sur une opacité 1 : alpha 1), donc les deux images doivent être les mêmes au pixel, sauf des traits d'arête.

- `corps` : l'empreinte, les pixels où la référence diffère du fond (la même scène, corps effacé : `vide_<classe>_<lumiere>.png`) ;
- `noirs` : pixels NOIRS (max des canaux ≤ 3) dans la prise, qui ne le sont pas dans la référence, sur l'empreinte ;
- `blocs2x2` : blocs 2×2 entièrement faits de tels pixels (le critère : aucun) ;
- `diff` : pixels de l'empreinte qui diffèrent de plus de 8/255 de la référence, et le plus grand écart.
Avec `--fusion-ab`, la prise `_boites` (accessoires en boîtes séparées) est jugée de même contre sa référence `_sp_boites`.

    python3 preuve_passe.py <dossier des prises>      → preuve_passe.json + un résumé
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image


def lire(p):
    return np.asarray(Image.open(p).convert("RGB")).astype(np.int16)


def juger(prise, ref, vide):
    corps = np.abs(ref - vide).max(axis=2) > 3
    noir_p = prise.max(axis=2) <= 3
    noir_r = ref.max(axis=2) <= 3
    anormal = noir_p & ~noir_r & corps
    blocs = anormal[:-1, :-1] & anormal[1:, :-1] & anormal[:-1, 1:] & anormal[1:, 1:]
    d = np.abs(prise - ref).max(axis=2)
    diff = (d > 8) & corps
    return {
        "corps": int(corps.sum()),
        "noirs": int(anormal.sum()),
        "blocs2x2": int(blocs.sum()),
        "diff": int(diff.sum()),
        "ecart_max": int(d[corps].max()) if corps.any() else 0,
    }


def main():
    dos = sys.argv[1]
    res = {}
    for f in sorted(os.listdir(dos)):
        m = re.match(r"^(.+)_(\d\.\d+)\.png$", f)
        if not m or "_sp" in f or f.startswith("vide"):
            continue
        base, lum = m.group(1), m.group(2)
        vide = lire(os.path.join(dos, "vide_%s_%s.png" % (base.split("_", 1)[1], lum)))
        for suffixe in ["", "_boites"]:
            p = os.path.join(dos, "%s_%s%s.png" % (base, lum, suffixe))
            r = os.path.join(dos, "%s_%s_sp%s.png" % (base, lum, suffixe))
            if os.path.exists(p) and os.path.exists(r):
                res["%s_%s%s" % (base, lum, suffixe)] = juger(lire(p), lire(r), vide)
    with open(os.path.join(dos, "preuve_passe.json"), "w") as fh:
        json.dump(res, fh, indent=1, ensure_ascii=False)
    for k, v in res.items():
        print("%-48s corps %6d  noirs %4d  blocs2x2 %4d  diff>8 %4d  max %3d" % (k, v["corps"], v["noirs"], v["blocs2x2"],
            v["diff"], v["ecart_max"]))


main()
