"""ISO13 lot B — le contour au banc des corps : sans contour contre 1 px et 2 px (même partie, temps fixe) — pixels où le
corps se voit (≥ 3/255), clarté rapportée à sans contour, noir absolu (noir sans, non noir avec), pixels plus clairs qu'avant."""
import statistics, sys
from PIL import Image
D = sys.argv[1]
LUM = ["0.8", "0.2", "0.15", "0.12", "0.1", "0"]
def lum(p): return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
tot_noir = 0; tot_clair = 0
print("lumière | pixels visibles sans / 1 px / 2 px | clarté 1 px / 2 px")
for l in LUM:
    ims = [Image.open("%s/corps_%s_contour_%d.png" % (D, l, px)).convert("RGB") for px in (0, 1, 2)]
    p = [im.load() for im in ims]
    W, H = ims[0].size
    vis = [0, 0, 0]; som = [0.0, 0.0, 0.0]
    for y in range(0, H):
        for x in range(0, W):
            v = [p[k][x, y] for k in range(3)]
            for k in range(3):
                if lum(v[k]) >= 3.0:
                    vis[k] += 1
                som[k] += lum(v[k])
            for k in (1, 2):
                if max(v[0]) == 0 and max(v[k]) > 0:
                    tot_noir += 1
                if any(v[k][i] > v[0][i] for i in range(3)):
                    tot_clair += 1
    r = ["%.3f" % (som[k] / som[0]) if som[0] > 0 else "-" for k in (1, 2)]
    print("%5s  | %d / %d / %d | %s / %s" % (l, vis[0], vis[1], vis[2], r[0], r[1]))
print("noir absolu : %d pixels noirs sans contour et non noirs avec" % tot_noir)
print("pixels plus clairs qu'avant, sur un canal au moins : %d" % tot_clair)
