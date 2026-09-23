"""Tenues sombres, banc des corps au temps figé : clarté de chaque tenue rapportée au gris, par classe et par lumière, et le
noir absolu (pixels noirs au gris, non noirs dans la tenue). Corps repérés par la grille du banc (5 × 2, ordre du catalogue),
pixels du corps = ceux qui changent d'une tenue à l'autre (le fond est identique dans les quatre prises)."""
import sys, json
from PIL import Image
D = sys.argv[1]
SLUGS = ["pistolet", "fusil", "pompe", "arbalete", "fumiste", "incendiaire", "sentinelle", "occulteur", "allumeur", "spectre"]
TENUES = ["sombre1", "sombre2", "sombre3"]
LUM = ["0.8", "0.2", "0.15", "0.1", "0.06", "0"]
def lum(p): return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
def charge(l, n): return Image.open("%s/corps_%s_%s.png" % (D, l, n)).convert("RGB")
# La grille, lue une fois à 0,8 : pixels qui diffèrent entre le gris et V2.
g, v = charge("0.8", "gris").load(), charge("0.8", "sombre2").load()
W, H = charge("0.8", "gris").size
pts = [(x, y) for y in range(0, H, 2) for x in range(0, W, 2) if max(abs(g[x, y][i] - v[x, y][i]) for i in range(3)) > 3]
xs = sorted(p[0] for p in pts); ys = sorted(p[1] for p in pts)
x0, x1, y0, y1 = xs[0], xs[-1], ys[0], ys[-1]
boites = {}
for x, y in pts:
    c = min(4, int((x - x0) * 5 / (x1 - x0 + 1))); r = min(1, int((y - y0) * 2 / (y1 - y0 + 1)))
    b = boites.setdefault(r * 5 + c, [W, H, 0, 0])
    b[0], b[1], b[2], b[3] = min(b[0], x), min(b[1], y), max(b[2], x), max(b[3], y)
boites = {k: (b[0] - 6, b[1] - 6, b[2] + 7, b[3] + 7) for k, b in boites.items()}
out = {}
for l in LUM:
    ims = {n: charge(l, n).load() for n in ["gris"] + TENUES}
    for i, s in enumerate(SLUGS):
        bx = boites[i]
        somme = {n: 0.0 for n in ["gris"] + TENUES}
        noirs = {n: 0 for n in TENUES}
        noirs2 = {n: 0 for n in TENUES}
        for y in range(bx[1], bx[3]):
            for x in range(bx[0], bx[2]):
                vals = {n: ims[n][x, y] for n in ims}
                if all(vals[n] == vals["gris"] for n in TENUES):
                    continue
                for n in vals:
                    somme[n] += lum(vals[n])
                for n in TENUES:
                    if max(vals["gris"]) == 0 and max(vals[n]) > 0:
                        noirs[n] += 1
                    if max(vals["gris"]) <= 2 and max(vals[n]) > 2:
                        noirs2[n] += 1
        out.setdefault(s, {})[l] = {n: (somme[n] / somme["gris"] if somme["gris"] > 0 else None) for n in TENUES}
        out[s][l]["noirs"] = noirs
        out[s][l]["noirs2"] = noirs2
        out[s][l]["gris_somme"] = somme["gris"]
json.dump(out, open(D + "/analyse.json", "w"), indent=1)
for n in TENUES:
    print("==", n, "(rapport de clarté au gris ; lumières", " ".join(LUM[:5]), ")")
    for s in SLUGS:
        cells = []
        for l in LUM[:5]:
            r = out[s][l][n]
            cells.append("  -  " if r is None else "%.3f" % r)
        print("  %-12s %s" % (s, "  ".join(cells)))
print("noir absolu (noir au gris, non noir dans la tenue ; ≤2 → >2) :")
for n in TENUES:
    tot = sum(out[s][l]["noirs"][n] for s in SLUGS for l in LUM)
    tot2 = sum(out[s][l]["noirs2"][n] for s in SLUGS for l in LUM)
    print("  %s : %d px (0 → >0), %d px (≤2 → >2)" % (n, tot, tot2))
