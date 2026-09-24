"""La bouteille face au VRAI gris d'ISO3 (sans bouteille) : pixels du corps visibles (≥ 3/255) par classe, gris contre V3
froide, aux lumières de l'apparition ; la lumière la plus faible où chaque corps montre ≥ 30 px."""
import sys
from PIL import Image
D = sys.argv[1]
SLUGS = ["pistolet", "fusil", "pompe", "arbalete", "fumiste", "incendiaire", "sentinelle", "occulteur", "allumeur", "spectre"]
LUM = ["0.15", "0.12", "0.1", "0.08", "0.06"]
def lum(p): return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
g = Image.open(D + "/gris_0.8.png").convert("RGB"); v = Image.open(D + "/sombre3_0.8.png").convert("RGB")
pg, pv = g.load(), v.load(); W, H = g.size
pts = [(x, y) for y in range(0, H) for x in range(0, W) if max(abs(pg[x, y][i] - pv[x, y][i]) for i in range(3)) > 4]
xs = sorted(p[0] for p in pts); ys = sorted(p[1] for p in pts)
classe = {}
for x, y in pts:
    c = min(4, int((x - xs[0]) * 5 / (xs[-1] - xs[0] + 1))); r = min(1, int((y - ys[0]) * 2 / (ys[-1] - ys[0] + 1)))
    classe.setdefault(r * 5 + c, []).append((x, y))
print("corps (px, masque commun) : " + ", ".join("%s %d" % (SLUGS[i], len(classe[i])) for i in range(10)))
vis = {}
for t in ["gris", "sombre3"]:
    for l in LUM:
        im = Image.open("%s/%s_%s.png" % (D, t, l)).convert("RGB").load()
        for i in range(10):
            vis[(t, l, i)] = sum(1 for (x, y) in classe[i] if lum(im[x, y]) >= 3)
print("classe        " + "  ".join("%-13s" % l for l in LUM) + "   apparition gris / V3")
plus_tot = []
for i, s in enumerate(SLUGS):
    ap = {}
    for t in ["gris", "sombre3"]:
        ok = [float(l) for l in LUM if vis[(t, l, i)] >= 30]
        ap[t] = min(ok) if ok else None
    if ap["sombre3"] is not None and (ap["gris"] is None or ap["sombre3"] < ap["gris"]):
        plus_tot.append(s)
    print("%-12s  " % s + "  ".join("%5d → %5d  " % (vis[("gris", l, i)], vis[("sombre3", l, i)]) for l in LUM)
          + "   %s / %s" % (ap["gris"], ap["sombre3"]))
print("V3 (bouteille comprise) apparaît plus TÔT que le gris d'ISO3 pour : %s" % (plus_tot or "aucune classe"))
