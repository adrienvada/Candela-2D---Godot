#!/usr/bin/env python3
"""Sol marqué 2 — le noir entre DEUX lancements : pixels noirs (≤ 7 au canal max) dans X et allumés dans Y, prise par prise.

    python3 entre.py <dossier X> <dossier Y> [suffixe, par défaut _A]
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

SEUIL = 7
x_rep, y_rep = sys.argv[1], sys.argv[2]
suffixe = sys.argv[3] if len(sys.argv) > 3 else "_A"
for fx in sorted(glob.glob(os.path.join(x_rep, f"*_noir*{suffixe}.png"))):
    fy = os.path.join(y_rep, os.path.basename(fx))
    if not os.path.exists(fy):
        continue
    x = np.asarray(Image.open(fx).convert("RGB")).astype(int)
    y = np.asarray(Image.open(fy).convert("RGB")).astype(int)
    lit = (x.max(2) <= SEUIL) & (y.max(2) > SEUIL)
    ys, xs = np.nonzero(lit)
    print(f"{os.path.basename(fx):44s} noirs dans X : {int((x.max(2) <= SEUIL).sum()):8d} · allumés dans Y : {int(lit.sum()):5d}"
          f" (max {int(y.max(2)[lit].max()) if lit.any() else 0})")
    for px, py in list(zip(xs, ys))[:8]:
        print(f"      ({px}, {py}) : {x[py, px].tolist()} → {y[py, px].tolist()}")
