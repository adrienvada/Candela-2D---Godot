#!/usr/bin/env python3
"""La peinture périmée — ce que chaque chemin allume dans le noir.

    python3 mesurer.py <dossier de la séance> [<dossier> …]

Chaque dossier est une séance de `tools/photo_peinture_perimee.gd` : A (tel que le jeu l'a laissé), B (peinture refaite à
la main), B2 (le bruit), au même instant, jeu en pause. Un pixel est NOIR s'il vaut ≤ 7 au canal maximal (le seuil des
sessions « sol marqué ») ; il est « allumé » s'il est noir dans une prise et > 7 dans l'autre.

Pour chaque séance : pixels différents entre A et B (et leur écart max), noirs de B allumés dans A (et au-dessus de 30 et
100/255, et la valeur max), et le même compte pour B → B2 (le bruit). `--contre=<dossier>` compare en plus les prises B de
chaque séance à la prise B d'une séance de référence (la carte posée directement) : même carte, même mise en scène.
"""
import os
import sys

import numpy as np
from PIL import Image

SEUIL = 7


def lire(chemin):
    return np.asarray(Image.open(chemin).convert("RGB")).astype(int)


def allumes(noir, autre):
    m = (noir.max(2) <= SEUIL) & (autre.max(2) > SEUIL)
    v = autre.max(2)[m]
    return {"allumes": int(m.sum()), "sup30": int((v > 30).sum()), "sup100": int((v > 100).sum()),
            "max": int(v.max()) if m.any() else 0}


def diff(a, b):
    d = np.abs(a - b).max(2)
    return int((d > 0).sum()), int(d.max())


def ligne(nom, a, b):
    n, m = diff(a, b)
    s = allumes(b, a)
    return (f"  {nom:10s} différents {n:8d} (écart max {m:3d}) · noirs allumés {s['allumes']:6d}"
            f" (> 30 : {s['sup30']:5d}, > 100 : {s['sup100']:4d}, max {s['max']:3d})")


args = [a for a in sys.argv[1:] if not a.startswith("--contre=")]
contre = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--contre=")), None)
ref = lire(os.path.join(contre, "B.png")) if contre else None
for dossier in args:
    print(os.path.basename(os.path.normpath(dossier)))
    a, b, b2 = (lire(os.path.join(dossier, f"{n}.png")) for n in ("A", "B", "B2"))
    print(ligne("A ← B", a, b))
    print(ligne("B2 ← B", b2, b))
    if ref is not None:
        print(ligne("B ← réf.", b, ref))
        print(ligne("A ← réf.", a, ref))
