"""ISO13 — le mannequin au banc des corps : pour chaque lumière et chaque côté de la lumière (aucune, sud, nord, est, ouest),
la clarté de chaque corps rapportée à celle du corps sans mannequin (même partie, temps figé), les pixels où il se voit
(≥ 3/255), le noir absolu (noir sans mannequin, non noir avec), et le pixel le plus clair contre Charte.DIM."""
import json, statistics, sys
from PIL import Image
D = sys.argv[1]
SLUGS = ["pistolet", "fusil", "pompe", "arbalete", "fumiste", "incendiaire", "sentinelle", "occulteur", "allumeur", "spectre"]
COTES = ["aucune", "sud", "nord", "est", "ouest"]
LUM = ["0.8", "0.2", "0.15", "0.12", "0.1", "0"]
DIM = (0.49 * 255, 0.532 * 255, 0.574 * 255)
def lum(p): return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
def charge(l, n): return Image.open("%s/corps_%s_mannequin_%s.png" % (D, l, n)).convert("RGB")
a, b = charge("0.8", "sans").load(), charge("0.8", "sud").load()
W, H = charge("0.8", "sans").size
pts = [(x, y) for y in range(0, H, 2) for x in range(0, W, 2) if max(abs(a[x, y][i] - b[x, y][i]) for i in range(3)) > 3]
xs = sorted(p[0] for p in pts); ys = sorted(p[1] for p in pts)
bx = {}
for x, y in pts:
    c = min(4, int((x - xs[0]) * 5 / (xs[-1] - xs[0] + 1))); r = min(1, int((y - ys[0]) * 2 / (ys[-1] - ys[0] + 1)))
    q = bx.setdefault(r * 5 + c, [W, H, 0, 0]); q[0], q[1], q[2], q[3] = min(q[0], x), min(q[1], y), max(q[2], x), max(q[3], y)
bx = {k: (q[0] - 6, q[1] - 6, q[2] + 7, q[3] + 7) for k, q in bx.items()}
res = {}
noirs = 0; trop = 0; maxi = 0
for l in LUM:
    ims = {n: charge(l, n).load() for n in ["sans"] + COTES}
    for i, s in enumerate(SLUGS):
        q = bx[i]
        somme = {n: 0.0 for n in ims}; vis = {n: 0 for n in ims}
        for y in range(q[1], q[3]):
            for x in range(q[0], q[2]):
                v = {n: ims[n][x, y] for n in ims}
                for n in ims:
                    somme[n] += lum(v[n])
                    if lum(v[n]) >= 3.0:
                        vis[n] += 1
                for n in COTES:
                    if max(v["sans"]) == 0 and max(v[n]) > 0:
                        noirs += 1
                    for k in range(3):
                        if v[n][k] > DIM[k] + 1.0 and v[n][k] > v["sans"][k]:
                            trop += 1
                            break
                    maxi = max(maxi, max(v[n]))
        res.setdefault(s, {})[l] = {"rapport": {n: somme[n] / somme["sans"] if somme["sans"] > 0 else None for n in COTES},
                                    "visibles": vis}
print("clarté / sans mannequin, médiane des dix classes (min-max) :")
print("lumière  " + "  ".join("%18s" % n for n in COTES))
for l in LUM[:-1]:
    cells = []
    for n in COTES:
        v = [res[s][l]["rapport"][n] for s in SLUGS if res[s][l]["rapport"][n]]
        cells.append("%.3f (%.2f-%.2f)" % (statistics.median(v), min(v), max(v)) if v else "  -")
    print("%6s   %s" % (l, "  ".join("%18s" % c for c in cells)))
print("équité sud / nord (clarté du corps éclairé du sud sur celle du corps éclairé du nord), par lumière :")
for l in LUM[:-1]:
    v = [res[s][l]["rapport"]["sud"] / res[s][l]["rapport"]["nord"] for s in SLUGS if res[s][l]["rapport"]["nord"]]
    print("  %s : %.3f (%.3f-%.3f)" % (l, statistics.median(v), min(v), max(v)))
print("pixels visibles (≥ 3/255), médiane des dix classes : sans / aucune / sud / nord / est / ouest")
for l in LUM:
    print("  %s : %s" % (l, " / ".join("%d" % statistics.median(res[s][l]["visibles"][n] for s in SLUGS) for n in ["sans"] + COTES)))
print("noir absolu : %d pixels noirs sans mannequin et non noirs avec" % noirs)
print("au-dessus de Charte.DIM et plus clair que sans mannequin : %d pixels ; pixel le plus clair %d" % (trop, maxi))
json.dump(res, open(D + "/mannequin.json", "w"), indent=1)
