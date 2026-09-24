"""Le pistolet détaillé : pixels visibles (≥ 3/255) du pistolet, sans et avec le détail, à chaque lumière ; son seuil
d'apparition (30 px) ; le noir à 0. Le masque : l'union des pixels du corps à 0,8, sans et avec (accessoires compris)."""
import sys
from PIL import Image
D = sys.argv[1]
L = ["0.3", "0.15", "0.12", "0.11", "0.1", "0.09", "0.08", "0.06"]
def lum(p): return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
g = Image.open(D + "/sans_0.8_gris.png").convert("RGB").load()
s8 = Image.open(D + "/sans_0.8.png").convert("RGB"); W, H = s8.size; s8 = s8.load()
a8 = Image.open(D + "/avec_0.8.png").convert("RGB").load()
pts = [(x, y) for y in range(H) for x in range(W) if max(abs(s8[x, y][i] - g[x, y][i]) for i in range(3)) > 4 or max(abs(a8[x, y][i] - g[x, y][i]) for i in range(3)) > 4]
xs = sorted(p[0] for p in pts); ys = sorted(p[1] for p in pts)
x_lim = xs[0] + (xs[-1] - xs[0]) / 5.0; y_lim = ys[0] + (ys[-1] - ys[0]) / 2.0
M = [(x, y) for (x, y) in pts if x < x_lim and y < y_lim]
print("pistolet : %d pixels de corps (masque commun)" % len(M))
seuil = {}
for q in ["sans", "avec"]:
    for l in L:
        p = Image.open("%s/%s_%s.png" % (D, q, l)).convert("RGB").load()
        n = sum(1 for (x, y) in M if lum(p[x, y]) >= 3)
        print("  %s %s : %d" % (q, l, n))
        if n >= 30: seuil[q] = min(seuil.get(q, 9), float(l))
print("apparition : sans %s, avec %s — %s" % (seuil.get("sans"), seuil.get("avec"),
      "PLUS TÔT" if seuil.get("avec", 9) < seuil.get("sans", 9) else "pas plus tôt"))
for q in ["sans", "avec"]:
    print("noir %s : %d/255" % (q, max(max(p) for p in Image.open("%s/%s_0.png" % (D, q)).convert("RGB").getdata())))
