"""La planche de l'équité de V3 : les dix corps recadrés, en colonnes ; rangées gris / V3 avant / V3 après à 0,15 (telles quelles
puis exposées ×6 pour la lecture), puis à 0,8. Usage : planche_equite.py <avant> <apres> <sortie> <rapport.txt>"""
import sys, re
from PIL import Image, ImageDraw, ImageFont
AV, AP, SORTIE, RAP = sys.argv[1:5]
SLUGS = ["pistolet", "fusil", "pompe", "arbalete", "fumiste", "incendiaire", "sentinelle", "occulteur", "allumeur", "spectre"]
NOMS = {"pistolet": "Parasite", "fusil": "Illusionniste", "pompe": "Terrassier", "arbalete": "Braconnier", "fumiste": "Fumiste",
        "incendiaire": "Incendiaire", "sentinelle": "Sentinelle", "occulteur": "Occulteur", "allumeur": "Allumeur", "spectre": "Spectre"}
def im(d, l, t): return Image.open("%s/corps_%s_%s.png" % (d, l, t)).convert("RGB")
a = im(AV, "0.8", "gris").load(); b0 = im(AV, "0.8", "sombre2"); W, H = b0.size; b = b0.load()
pts = [(x, y) for y in range(H) for x in range(W) if max(abs(a[x, y][i] - b[x, y][i]) for i in range(3)) > 4]
xs = sorted(p[0] for p in pts); ys = sorted(p[1] for p in pts); B = {}
for x, y in pts:
    c = min(4, int((x - xs[0]) * 5 / (xs[-1] - xs[0] + 1))); r = min(1, int((y - ys[0]) * 2 / (ys[-1] - ys[0] + 1)))
    q = B.setdefault(r * 5 + c, [W, H, 0, 0]); q[0], q[1], q[2], q[3] = min(q[0], x), min(q[1], y), max(q[2], x), max(q[3], y)
cw = max(q[2] - q[0] for q in B.values()) + 12; ch = max(q[3] - q[1] for q in B.values()) + 12
Z = 2
rapports = {}
for l in open(RAP, encoding="utf-8"):
    m = re.match(r"(\w+)\s+0\.12:.*0\.15:\s+(\d+)\s+/\s+(\d+)\s+/\s+(\d+)\s+\(([\d.]+)\)", l)
    if m: rapports[m.group(1)] = (int(m.group(2)), int(m.group(3)), int(m.group(4)))
def police(t):
    for c in ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try: return ImageFont.truetype(c, t)
        except OSError: pass
    return ImageFont.load_default()
RANGS = [("0.15", AV, "gris", "gris, 0,15", 1), ("0.15", AV, "sombre3", "V3 avant, 0,15", 1), ("0.15", AP, "sombre3", "V3 après, 0,15", 1),
         ("0.15", AV, "gris", "gris, 0,15 ×6", 6), ("0.15", AV, "sombre3", "V3 avant, 0,15 ×6", 6), ("0.15", AP, "sombre3", "V3 après, 0,15 ×6", 6),
         ("0.8", AV, "gris", "gris, 0,8", 1), ("0.8", AV, "sombre3", "V3 avant, 0,8", 1), ("0.8", AP, "sombre3", "V3 après, 0,8", 1)]
G = 160
P = Image.new("RGB", (G + 10 * (cw * Z + 8), 110 + len(RANGS) * (ch * Z + 10) + 40), (14, 13, 12)); d = ImageDraw.Draw(P)
d.text((10, 10), "L'équité de V3 froide — les dix classes, avant / après le facteur par classe (banc des corps, temps figé, même partie)",
       fill=(230, 160, 70), font=police(22))
d.text((10, 42), "à 0,15 : part des pixels visibles du gris gardée par V3 — avant 0,13 à 0,92, après 0,47 à 0,55 (bande 0,47-0,57) ; "
       "apparition inchangée pour les dix classes ; noir 0/255", fill=(225, 215, 195), font=police(15))
for k, s in enumerate(SLUGS):
    x = G + k * (cw * Z + 8)
    g, v0, v1 = rapports.get(s, (1, 0, 0))
    d.text((x, 70), NOMS[s], fill=(225, 215, 195), font=police(15))
    d.text((x, 88), "%.2f → %.2f" % (v0 / g, v1 / g), fill=(150, 140, 125), font=police(13))
y = 110
cache = {}
for (l, dd, t, lib, gain) in RANGS:
    if (dd, l, t) not in cache: cache[(dd, l, t)] = im(dd, l, t)
    src = cache[(dd, l, t)]
    d.text((10, y + 10), lib, fill=(225, 215, 195), font=police(14))
    for k in range(10):
        q = B[k]; cx, cy = (q[0] + q[2]) // 2, (q[1] + q[3]) // 2
        c = src.crop((cx - cw // 2, cy - ch // 2, cx + cw // 2, cy + ch // 2))
        if gain != 1: c = c.point(lambda v: min(255, v * gain))
        P.paste(c.resize((cw * Z, ch * Z), Image.NEAREST), (G + k * (cw * Z + 8), y))
    y += ch * Z + 10
P.save(SORTIE, quality=90); print("planche →", SORTIE, P.size)
