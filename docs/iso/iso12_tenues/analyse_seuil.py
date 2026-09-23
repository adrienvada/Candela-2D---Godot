"""Le seuil de visibilité : à chaque lumière, le nombre de pixels où chaque corps se voit (clarté ≥ 3/255 sur le fond noir
du banc), en gris et dans les trois tenues ; puis, par tenue, la lumière la plus faible où un corps montre encore au moins
PIX pixels, et le rapport à celle du gris."""
import json, statistics, sys
from PIL import Image
D = sys.argv[1]
SLUGS = ["pistolet", "fusil", "pompe", "arbalete", "fumiste", "incendiaire", "sentinelle", "occulteur", "allumeur", "spectre"]
TENUES = ["gris", "sombre1", "sombre2", "sombre3"]
LUM = ["0.8", "0.4", "0.3", "0.25", "0.2", "0.17", "0.15", "0.12", "0.1", "0.08", "0.06", "0.05", "0.04"]
PIX, SEUIL = 30, 3.0
def lum(p): return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
g = Image.open(D + "/corps_0.8_gris.png").convert("RGB"); v = Image.open(D + "/corps_0.8_sombre2.png").convert("RGB")
pg, pv = g.load(), v.load(); W, H = g.size
pts = [(x, y) for y in range(0, H, 2) for x in range(0, W, 2) if max(abs(pg[x, y][i] - pv[x, y][i]) for i in range(3)) > 3]
xs = sorted(p[0] for p in pts); ys = sorted(p[1] for p in pts)
bx = {}
for x, y in pts:
    c = min(4, int((x - xs[0]) * 5 / (xs[-1] - xs[0] + 1))); r = min(1, int((y - ys[0]) * 2 / (ys[-1] - ys[0] + 1)))
    q = bx.setdefault(r * 5 + c, [W, H, 0, 0]); q[0], q[1], q[2], q[3] = min(q[0], x), min(q[1], y), max(q[2], x), max(q[3], y)
bx = {k: (q[0] - 6, q[1] - 6, q[2] + 7, q[3] + 7) for k, q in bx.items()}
# Les pixels du CORPS : ceux où V2 diffère du gris de plus de 4/255 à 0,8 (le fond, au grain près, en est exclu).
ims08 = [Image.open("%s/corps_0.8_%s.png" % (D, t)).convert("RGB").load() for t in TENUES]
corps = {}
for i in range(10):
    b = bx[i]
    corps[i] = [(x, y) for y in range(b[1], b[3]) for x in range(b[0], b[2]) if max(abs(ims08[0][x, y][c] - ims08[2][x, y][c]) for c in range(3)) > 4]
vis = {}
for l in LUM:
    for t in TENUES:
        im = Image.open("%s/corps_%s_%s.png" % (D, l, t)).convert("RGB").load()
        for i, s in enumerate(SLUGS):
            n = sum(1 for (x, y) in corps[i] if lum(im[x, y]) >= SEUIL)
            vis.setdefault(t, {}).setdefault(s, {})[l] = n
print("pixels du corps visibles (≥ %d/255), médiane des dix classes (corps entier : %d px) :" % (SEUIL, statistics.median(len(c) for c in corps.values())))
print("lumière  " + "  ".join("%8s" % t for t in TENUES))
for l in LUM:
    print("%6s   %s" % (l, "  ".join("%8d" % statistics.median(vis[t][s][l] for s in SLUGS) for t in TENUES)))
seuils = {}
for t in TENUES:
    for s in SLUGS:
        visibles = [float(l) for l in LUM if vis[t][s][l] >= PIX]
        seuils.setdefault(t, {})[s] = min(visibles) if visibles else None
print("lumière la plus faible où le corps montre ≥ %d px :" % PIX)
for s in SLUGS:
    print("  %-12s %s" % (s, "  ".join("%s %s" % (t, seuils[t][s]) for t in TENUES)))
json.dump({"visibles": vis, "seuils": seuils}, open(D + "/seuil.json", "w"), indent=1)
