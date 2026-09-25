"""Levier 1, preuve A/B dans UN processus : « avec usure » par la texture de proximité contre « avec usure » par l'ancien chemin
(huit lectures), au même instant figé. Sur TOUTE l'image, corps compris : ils n'ont pas bougé entre les deux prises, le temps
figé et rien d'autre ne changeant — sinon, on les exclut et on le dit."""
import sys, glob, re, json
from PIL import Image
L = re.compile(r"tenue cadrage=(\S+) tenue=(\S+) camera=\S+ fichier=(\S+) ancres=(\{.*\})$")
S = sys.argv[1]
for l in (0, 45):
    d = "%s/ab_l%d" % (S, l)
    nom = "usure" if l == 0 else "usure_lacet45"
    t = Image.open("%s/%s_avec.png" % (d, nom)).convert("RGB"); W, H = t.size; t = t.load()
    a = Image.open("%s/%s_avec_ancienne.png" % (d, nom)).convert("RGB").load()
    s = Image.open("%s/%s_sans.png" % (d, nom)).convert("RGB").load()
    anc = None
    for ligne in open(d + "/journal.log", errors="replace"):
        m = L.search(ligne.strip())
        if m and m.group(2) == "avec": anc = json.loads(m.group(4))
    def corps(x, y): return any(abs(x - c[0]) <= 40 and c[1] - 45 <= y <= c[1] + 30 for c in (anc["j1"], anc["j2"]))
    tous = [(x, y, a[x, y], t[x, y]) for y in range(H) for x in range(W) if a[x, y] != t[x, y]]
    ecarts = [p for p in tous if not corps(p[0], p[1])]
    print("lacet %d° — %d pixels différents en tout, dont %d dans les cadres des corps (J1 %s, J2 %s)" % (l, len(tous), len(tous) - len(ecarts), anc["j1"], anc["j2"]))
    pire = max((max(abs(p[2][i] - p[3][i]) for i in range(3)) for p in ecarts), default=0)
    print("lacet %d° — DÉCOR, texture contre huit lectures, même instant : %d pixels différents, plus grand écart %d/255"
          % (l, len(ecarts), pire))
    if ecarts:
        xs = [p[0] for p in ecarts]; ys = [p[1] for p in ecarts]
        print("   boîte (%d, %d)-(%d, %d) ; premiers %s" % (min(xs), min(ys), max(xs), max(ys), ecarts[:5]))
    for lib, img in (("texture", t), ("huit lectures", a)):
        allumes = sum(1 for y in range(H) for x in range(W) if not corps(x, y) and max(s[x, y]) <= 2 and max(img[x, y]) > 2)
        clairs = sum(1 for y in range(H) for x in range(W) if not corps(x, y) and max(img[x, y]) > max(s[x, y]) + 1)
        print("   %s — avec contre sans, décor : %d noirs allumés, %d plus clairs" % (lib, allumes, clairs))
