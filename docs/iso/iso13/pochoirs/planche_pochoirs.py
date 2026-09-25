"""Les pochoirs : sans / avec au même instant (temps du jeu figé, même partie), à 0° et 45°. Mesures sur le décor (hors des
cadres des corps) : noirs allumés, plus clairs, assombris, et la boîte des pixels changés ; les appels de dessin des deux prises
(journal) ; l'illustration à côté. Usage : planche_pochoirs.py <scratchpad> <dépôt> <sortie.jpg>"""
import sys, re, json
from PIL import Image, ImageDraw, ImageFont
S, DEPOT, SORTIE = sys.argv[1:4]
L = re.compile(r"tenue cadrage=(\S+) tenue=(\S+) camera=\S+ fichier=(\S+) ancres=(\{.*\})$")
C = re.compile(r"pochoirs_cout cadrage=(\S+) (\S+) appels=(\d+) objets=(\d+) textures_mo=([\d.]+)")
def police(t):
    for c in ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try: return ImageFont.truetype(c, t)
        except OSError: pass
    return ImageFont.load_default()
lignes, rapport = [], []
for l in (0, 45):
    d = "%s/po_l%d" % (S, l)
    P, couts = {}, {}
    for x in open(d + "/journal.log", errors="replace"):
        m = L.search(x.strip())
        if m: P[m.group(2)] = (d + "/" + m.group(3).split("/")[-1], json.loads(m.group(4)))
        m = C.search(x)
        if m: couts[m.group(2)] = (int(m.group(3)), int(m.group(4)), float(m.group(5)))
    fs, anc = P["sans"]; fa, _ = P["avec"]
    a, b = Image.open(fs).convert("RGB"), Image.open(fa).convert("RGB")
    W, H = a.size; pa, pb = a.load(), b.load()
    def corps(x, y): return any(abs(x - c[0]) <= 40 and c[1] - 45 <= y <= c[1] + 30 for c in (anc["j1"], anc["j2"]))
    allumes = clairs = sombres = 0; xs = []; ys = []
    for y in range(H):
        for x in range(W):
            if corps(x, y): continue
            p, q = max(pa[x, y]), max(pb[x, y])
            allumes += p <= 2 and q > 2
            clairs += q > p + 1
            if q < p: sombres += 1; xs.append(x); ys.append(y)
    boite = (min(xs), min(ys), max(xs), max(ys)) if xs else None
    r = "lacet %d° — décor : %d noirs allumés, %d plus clairs, %d assombris (boîte %s, pochoir en %s) ; appels de dessin sans / avec : %s / %s ; objets : %s / %s ; textures %s / %s Mo" % (
        l, allumes, clairs, sombres, boite, anc["pochoir"], couts.get("sans", ("?",))[0], couts.get("avec", ("?",))[0],
        couts.get("sans", ("?", "?"))[1], couts.get("avec", ("?", "?"))[1], couts.get("sans", ("?", "?", "?"))[2], couts.get("avec", ("?", "?", "?"))[2])
    rapport.append(r); print(r)
    lignes.append((l, a, b, anc, allumes, clairs))
ill = Image.open(DEPOT + "/assets/ui/ill_creer_local.png").convert("RGB"); ill = ill.resize((int(ill.width * 360 / ill.height), 360))
CW, CH, Z = 520, 300, 3
Wt = 20 + 2 * (CW + 20)
Pl = Image.new("RGB", (max(Wt, ill.width + 40), 120 + 360 + len(lignes) * (CH + 60 + 240)), (13, 12, 11)); d = ImageDraw.Draw(Pl)
d.text((20, 12), "Les pochoirs de l'illustration, à l'essai (--pochoirs-essai) — sans / avec au même instant", fill=(230, 160, 70), font=police(24))
d.text((20, 46), "peinture sombre (le sol × 0,55), cuite avec le décor ; Le Cloître, « ZONE 1 » sous la torche de J1 ; temps du jeu figé entre les deux prises",
       fill=(228, 218, 200), font=police(14))
Pl.paste(ill, (20, 80)); d.text((30 + ill.width, 84), "l'illustration (ill_creer_local) : DEATHMATCH peint au sol", fill=(150, 140, 126), font=police(14))
y = 80 + 380
for (l, a, b, anc, allumes, clairs), r in zip(lignes, rapport):
    d.text((20, y), r[:150], fill=(208, 112, 74) if (allumes or clairs) else (228, 218, 200), font=police(13)); y += 22
    cx, cy = anc["pochoir"]
    for k, (img, nom) in enumerate([(a, "sans"), (b, "avec")]):
        Pl.paste(img.crop((cx - CW // 2, cy - CH // 2, cx + CW // 2, cy + CH // 2)), (20 + k * (CW + 20), y))
        d.text((24 + k * (CW + 20), y + 4), nom, fill=(150, 140, 126), font=police(13))
    y += CH + 12
    for k, img in enumerate([a, b]):
        Pl.paste(img.crop((cx - 80, cy - 35, cx + 80, cy + 35)).resize((480, 210), Image.NEAREST), (20 + k * (CW + 20), y))
    d.text((24, y + 2), "×3", fill=(150, 140, 126), font=police(13))
    y += 230
Pl.crop((0, 0, Pl.width, y + 10)).save(SORTIE, quality=88); print("planche →", SORTIE)
