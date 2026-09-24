"""L'équité de V3 : pour chaque facteur g, le rapport V3/gris des pixels visibles (≥ 3/255) par classe à 0,15 ; puis le g
par classe qui vise la cible (interpolation linéaire entre deux g encadrants). Usage : analyse_equite.py <dossier> [cible]"""
import sys, glob, re, json
from PIL import Image
D = sys.argv[1]; CIBLE = float(sys.argv[2]) if len(sys.argv) > 2 else 0.52
SLUGS = ["pistolet", "fusil", "pompe", "arbalete", "fumiste", "incendiaire", "sentinelle", "occulteur", "allumeur", "spectre"]
def lum(p): return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
NOMS = {float(re.search(r"g([\d.]+)_0\.8\.png", f).group(1)): re.search(r"g([\d.]+)_0\.8\.png", f).group(1) for f in glob.glob(D + "/g*_0.8.png")}
gs = sorted(NOMS)
def masque(g):
    a = Image.open("%s/g%s_0.8_gris.png" % (D, g)).convert("RGB").load(); b = Image.open("%s/g%s_0.8_sombre2.png" % (D, g)).convert("RGB")
    W, H = b.size; b = b.load()
    pts = [(x, y) for y in range(H) for x in range(W) if max(abs(a[x, y][i] - b[x, y][i]) for i in range(3)) > 4]
    xs = sorted(p[0] for p in pts); ys = sorted(p[1] for p in pts); cl = {}
    for x, y in pts:
        c = min(4, int((x - xs[0]) * 5 / (xs[-1] - xs[0] + 1))); r = min(1, int((y - ys[0]) * 2 / (ys[-1] - ys[0] + 1)))
        cl.setdefault(r * 5 + c, []).append((x, y))
    return cl
def fmt(g): return NOMS[g] if g in NOMS else ("%g" % g)
M = masque(fmt(gs[0]))
rap = {}
for g in gs:
    G = Image.open("%s/g%s_0.15_gris.png" % (D, fmt(g))).convert("RGB").load()
    V = Image.open("%s/g%s_0.15_sombre3.png" % (D, fmt(g))).convert("RGB").load()
    for i, s in enumerate(SLUGS):
        ng = sum(1 for (x, y) in M[i] if lum(G[x, y]) >= 3); nv = sum(1 for (x, y) in M[i] if lum(V[x, y]) >= 3)
        rap[(s, g)] = nv / max(ng, 1)
print("g     " + "  ".join("%-11s" % s[:11] for s in SLUGS))
for g in gs:
    print("%-5g " % g + "  ".join("%-11.2f" % rap[(s, g)] for s in SLUGS))
choix = {}
for s in SLUGS:
    pts = [(g, rap[(s, g)]) for g in gs]
    g_c = None
    for (g0, r0), (g1, r1) in zip(pts, pts[1:]):
        if (r0 - CIBLE) * (r1 - CIBLE) <= 0 and r1 != r0:
            g_c = g0 + (CIBLE - r0) * (g1 - g0) / (r1 - r0); break
    choix[s] = round(g_c, 2) if g_c is not None else None
print("cible %.2f → g par classe : %s" % (CIBLE, json.dumps(choix)))
