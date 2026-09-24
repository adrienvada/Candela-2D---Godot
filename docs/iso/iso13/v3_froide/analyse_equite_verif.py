"""L'équité de V3, avant / après : pixels visibles par classe (gris, V3 avant, V3 après) à 0,12 / 0,15 / 0,2 / 0,3 ; le rapport
V3/gris à 0,15 face à la bande ; les dix seuils d'apparition (≥ 30 px) au balayage fin ; le noir à 0 ; et la planche des dix
classes à 0,15 et à 0,8. Usage : analyse_equite_verif.py <bancs_eq_avant> <bancs_eq_apres> <planche.jpg>"""
import sys, statistics
from PIL import Image, ImageDraw, ImageFont
AV, AP, SORTIE = sys.argv[1:4]
SLUGS = ["pistolet", "fusil", "pompe", "arbalete", "fumiste", "incendiaire", "sentinelle", "occulteur", "allumeur", "spectre"]
FIN = ["0.2", "0.17", "0.15", "0.14", "0.13", "0.12", "0.11", "0.1", "0.09", "0.08", "0.06", "0.05", "0.04"]
def lum(p): return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
def im(d, l, t): return Image.open("%s/corps_%s_%s.png" % (d, l, t)).convert("RGB")
a = im(AV, "0.8", "gris").load(); b0 = im(AV, "0.8", "sombre2"); W, H = b0.size; b = b0.load()
pts = [(x, y) for y in range(H) for x in range(W) if max(abs(a[x, y][i] - b[x, y][i]) for i in range(3)) > 4]
xs = sorted(p[0] for p in pts); ys = sorted(p[1] for p in pts); M = {}
for x, y in pts:
    c = min(4, int((x - xs[0]) * 5 / (xs[-1] - xs[0] + 1))); r = min(1, int((y - ys[0]) * 2 / (ys[-1] - ys[0] + 1)))
    M.setdefault(r * 5 + c, []).append((x, y))
cache = {}
def vis(d, l, t, i):
    k = (d, l, t)
    if k not in cache: cache[k] = im(d, l, t).load()
    p = cache[k]
    return sum(1 for (x, y) in M[i] if lum(p[x, y]) >= 3)
print("pixels visibles — gris / V3 avant / V3 après (rapport après)")
for i, s in enumerate(SLUGS):
    print("%-12s " % s + "  ".join("%s: %4d / %4d / %4d (%.2f)" % (l, vis(AV, l, "gris", i), vis(AV, l, "sombre3", i), vis(AP, l, "sombre3", i),
          vis(AP, l, "sombre3", i) / max(vis(AV, l, "gris", i), 1)) for l in ["0.12", "0.15", "0.2", "0.3"]))
rav = [vis(AV, "0.15", "sombre3", i) / max(vis(AV, "0.15", "gris", i), 1) for i in range(10)]
rap = [vis(AP, "0.15", "sombre3", i) / max(vis(AV, "0.15", "gris", i), 1) for i in range(10)]
print("rapport à 0,15 — avant : %.2f à %.2f (médiane %.3f) ; après : %.2f à %.2f (médiane %.3f) ; bande 0,47-0,57 : %s" % (
    min(rav), max(rav), statistics.median(rav), min(rap), max(rap), statistics.median(rap),
    "TENUE" if all(0.47 <= r <= 0.57 for r in rap) else "HORS : " + ", ".join("%s %.2f" % (SLUGS[i], r) for i, r in enumerate(rap) if not 0.47 <= r <= 0.57)))
def seuil(d, t, i):
    ok = [float(l) for l in FIN if vis(d, l, t, i) >= 30]
    return min(ok) if ok else None
print("apparition (≥ 30 px) — gris / V3 avant / V3 après :")
pire = 0.0
for i, s in enumerate(SLUGS):
    g, v0, v1 = seuil(AV, "gris", i), seuil(AV, "sombre3", i), seuil(AP, "sombre3", i)
    pire = max(pire, v1 or 9)
    print("  %-12s %s / %s / %s%s" % (s, g, v0, v1, "  PLUS TÔT QUE LE GRIS" if (v1 is not None and g is not None and v1 < g) else ""))
print("la plus tardive après : %s — borne 0,12 : %s" % (pire, "TENUE" if pire <= 0.12 else "DÉPASSÉE"))
for d, n in [(AV, "avant"), (AP, "après")]:
    for t in ["gris", "sombre3"]:
        print("noir, lumière 0, %s %s : pixel maximal %d/255" % (n, t, max(max(p) for p in im(d, "0", t).getdata())))
# La planche : trois rangées (gris, V3 avant, V3 après) × deux lumières (0,15 puis 0,8), les dix corps.
x0, x1, y0, y1 = xs[0] - 8, xs[-1] + 9, ys[0] - 8, ys[-1] + 9
cw, ch = x1 - x0, y1 - y0
def police(t):
    for c in ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try: return ImageFont.truetype(c, t)
        except OSError: pass
    return ImageFont.load_default()
Z = 2 if cw < 900 else 1
P = Image.new("RGB", (cw * Z + 220, 70 + 6 * (ch * Z + 30)), (12, 12, 12)); d = ImageDraw.Draw(P)
d.text((10, 10), "L'équité de V3 — les dix classes, gris / V3 avant / V3 après, à 0,15 puis 0,8 (banc des corps, temps figé)",
       fill=(230, 160, 70), font=police(20))
y = 50
for l in ["0.15", "0.8"]:
    for (dd, t, lib) in [(AV, "gris", "gris"), (AV, "sombre3", "V3 avant"), (AP, "sombre3", "V3 après")]:
        c = im(dd, l, t).crop((x0, y0, x1, y1)).resize((cw * Z, ch * Z), Image.NEAREST)
        P.paste(c, (210, y)); d.text((10, y + 10), "%s — %s" % (lib, l.replace(".", ",")), fill=(225, 215, 195), font=police(16))
        y += ch * Z + 30
P.save(SORTIE, quality=90); print("planche →", SORTIE)
