"""ISO12, lot 0 — la calibration des énergies : la même scène, lumière 3D éteinte (référence ISO11) et allumée.

Usage : python3 calibrer.py REFERENCE.png ECLAIREE.png [X0 Y0 X1 Y1 ...]

Sur les pixels où la référence est éclairée (luminance > SEUIL), le rapport des luminances moyennes éclairée / référence,
global puis par zone (rectangles optionnels, en pixels de la capture : un par type de source — cône de la torche, halo de
la fusée, rétrodiffusion autour du porteur). La valeur affichée suit à peu près la puissance 1/2,2 de l'énergie : le
facteur d'énergie suggéré est (1 / rapport)^2,2, à appliquer à la constante du type de source puis à revérifier au banc.
PIL seul, tous les pixels.
"""
import sys

from PIL import Image

SEUIL = 12
ref = Image.open(sys.argv[1]).convert("L")
ecl = Image.open(sys.argv[2]).convert("L")
if ref.size != ecl.size:
    sys.exit(f"tailles différentes : {ref.size} contre {ecl.size}")
pr, pe = ref.load(), ecl.load()
w, h = ref.size


def mesurer(x0, y0, x1, y1):
    sr = se = n = noirs = 0
    for y in range(max(0, y0), min(h, y1)):
        for x in range(max(0, x0), min(w, x1)):
            if pr[x, y] > SEUIL:
                sr += pr[x, y]
                se += pe[x, y]
                n += 1
                if pe[x, y] <= 2:
                    noirs += 1
    if n == 0:
        return None
    rapport = se / sr if sr else 0.0
    facteur = (1.0 / rapport) ** 2.2 if rapport > 0 else float("inf")
    return n, sr / n, se / n, rapport, facteur, noirs / n


zones = [("global", (0, 0, w, h))]
args = [int(a) for a in sys.argv[3:]]
for i in range(0, len(args) - 3, 4):
    zones.append((f"zone{i // 4 + 1}", tuple(args[i:i + 4])))
for nom, r in zones:
    m = mesurer(*r)
    if m is None:
        print(f"{nom} {r} : aucun pixel éclairé dans la référence")
        continue
    n, lr, le, rapport, facteur, noirs = m
    print(f"{nom} {r} : {n} px éclairés en 2D ; luminance 2D {lr:.1f}, 3D {le:.1f} ; rapport {rapport:.3f} ; "
          f"facteur d'énergie suggéré {facteur:.2f} ; {noirs * 100:.1f} % de ces pixels NOIRS en 3D")
