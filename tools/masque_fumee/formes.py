#!/usr/bin/env python3
"""LE MASQUE DE LA FUMÉE ET SES FORMES, À L'IMAGE (session cloud « masque-fumée », 2026-09-27).

Lit les prises du plan `loupe-fusee-masque-formes` (tools/loupe.gd) et rend, pour chaque forme du masque :
  1. le verdict de `tools/preuve_masque_fumee.py` (les critères de Gadgets, inchangés : fuite zéro là où A est noir, B au
     pixel là où A montre le sol) — la prise de la forme tient lieu de C ;
  2. l'écart AU PIXEL à la prise C (le masque de Gadgets) : combien de pixels diffèrent, de combien au plus, et de quel
     côté — « fumée perdue » (la forme montre A là où Gadgets montrait la fumée) ou « fumée gardée en plus » ;
puis le COMPTE des fragments de fumée (prises `compte`, `compte-visible`, `compte-zero`) : chaque fragment y écrit 50/255
en mélange additif sur une scène noire, l'écran montre donc 0, 1, 2, 3 ou 4 couches ; les niveaux se lisent aux pics de
l'histogramme (la courbe de la sortie 3D n'est pas linéaire), les pixels déjà allumés sans fumée (`compte-zero` : le
voxel de la fusée) sont retirés.

    python3 tools/masque_fumee/formes.py <dossier des prises> [<dossier de travail>]

Sort 0 si toutes les formes passent la preuve, 1 sinon. Pillow requis."""
import glob, os, re, subprocess, sys, tempfile
from PIL import Image

D = sys.argv[1]
T = sys.argv[2] if len(sys.argv) > 2 else tempfile.mkdtemp()
ICI = os.path.dirname(os.path.abspath(__file__))
PREUVE = os.path.join(ICI, "..", "preuve_masque_fumee.py")
ID = "loupe-fusee-masque-formes"


def prise(suffixe):
    tout = glob.glob(os.path.join(D, "*%s-%s.png" % (ID, suffixe)))
    if not tout:
        sys.exit("✗ prise introuvable : %s" % suffixe)
    return tout[0]


FORMES = [("c", "Gadgets (--fumee-masque)"), ("c0", "Gadgets, seconde prise (le bruit entre deux prises)"),
          ("c1", "compacte (--fumee-masque-compact)"), ("c2", "bande resserrée (--fumee-masque-resserre)"),
          ("c3", "pochoir (--fumee-masque-pochoir)")]
ok = True
a = Image.open(prise("a")).convert("RGB")
b = Image.open(prise("b")).convert("RGB")
c0 = Image.open(prise("c")).convert("RGB")
W, H = a.size
pa, pb, pc = a.load(), b.load(), c0.load()
HUD = [(0, 0, 580, 185), (1130, 0, 1336, 100)]


def hud(x, y):
    return any(x0 <= x < x1 and y0 <= y < y1 for x0, y0, x1, y1 in HUD)


# L'ENSEMBLE INSTABLE, comme `tools/preuve_masque_fumee.py` le définit : les écarts entre les cinq A, dilatés d'un pixel, et
# le corps de J1 (ni noir, ni blanc, ni rouge, ni vert dans la carte des murs). L'écart au pixel se donne dedans ET dehors :
# dedans, deux prises du MÊME masque diffèrent déjà (le corps frémit, son contact au sol avec lui).
_as = [Image.open(prise(k)).convert("RGB").load() for k in ("a1", "a2", "a3", "a4")]
_mu = Image.open(prise("murs")).convert("RGB").load()
INSTABLE = set()
for y in range(H):
    for x in range(W):
        if any(q[x, y] != pa[x, y] for q in _as):
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    INSTABLE.add((x + dx, y + dy))
        elif _mu[x, y] not in ((0, 0, 0), (255, 255, 255), (255, 0, 0), (0, 255, 0)):
            INSTABLE.add((x, y))


for suffixe, nom in FORMES:
    dossier = os.path.join(T, suffixe)
    os.makedirs(dossier, exist_ok=True)
    for k in ("a", "a1", "a2", "a3", "a4", "b", "murs"):
        cible = os.path.join(dossier, "p-%s.png" % k)
        if os.path.lexists(cible):
            os.remove(cible)
        os.symlink(os.path.abspath(prise(k)), cible)
    cible = os.path.join(dossier, "p-c.png")
    if os.path.lexists(cible):
        os.remove(cible)
    os.symlink(os.path.abspath(prise(suffixe)), cible)
    r = subprocess.run([sys.executable, PREUVE, dossier, "p"], capture_output=True, text=True)
    lignes = [l for l in r.stdout.splitlines() if re.search(r"fuite|perte|VERDICT|témoins|trous", l)]
    print("\n== %s ==" % nom)
    for l in lignes:
        print("   " + l.strip())
    ok = ok and r.returncode == 0
    if suffixe == "c":
        continue
    ck = Image.open(prise(suffixe)).convert("RGB").load()
    n = perdue = gardee = autre = noir_a = egal_b = dehors = dehors_noir_a = 0
    ecart = 0
    for y in range(H):
        for x in range(W):
            if hud(x, y) or ck[x, y] == pc[x, y]:
                continue
            n += 1
            ecart = max(ecart, max(abs(ck[x, y][i] - pc[x, y][i]) for i in range(3)))
            if max(pa[x, y]) == 0:
                noir_a += 1
            if ck[x, y] == pb[x, y]:
                egal_b += 1
            if (x, y) not in INSTABLE:
                dehors += 1
                if max(pa[x, y]) == 0:
                    dehors_noir_a += 1
            if ck[x, y] == pa[x, y] and pc[x, y] != pa[x, y]:
                perdue += 1
            elif pc[x, y] == pa[x, y] and ck[x, y] != pa[x, y]:
                gardee += 1
            else:
                autre += 1
    print("   écart au masque de Gadgets : %d pixels (écart max %d/255) — fumée perdue %d, gardée en plus %d, autre %d ;"
          " dont %d sur un pixel noir dans A, %d égaux à B (la fumée sans masque)" % (n, ecart, perdue, gardee, autre, noir_a,
                                                                                    egal_b))
    print("   HORS de l'ensemble instable : %d pixels diffèrent du masque de Gadgets, dont %d sur un pixel noir dans A"
          % (dehors, dehors_noir_a))

# L'ÉCRAN SCINDÉ : J1 à gauche, J2 à droite. Le pochoir contre A (fuite : A noir, C3 non) et contre C (Gadgets), hors des
# pixels instables (les trois A diffèrent) ; vue par vue.
if glob.glob(os.path.join(D, "*%s-s-c3.png" % ID)):
    sa, sb, sc, s3 = (Image.open(prise(k)).convert("RGB").load() for k in ("s-a", "s-b", "s-c", "s-c3"))
    sas = [Image.open(prise(k)).convert("RGB").load() for k in ("s-a1", "s-a2")]
    for nom, x0, x1 in (("J1 (gauche)", 0, W // 2), ("J2 (droite)", W // 2, W)):
        fuite = fuite_c = ecart = sale = noirs = instables = 0
        for y in range(H):
            for x in range(x0, x1):
                if hud(x, y):
                    continue
                if any(q[x, y] != sa[x, y] for q in sas):
                    instables += 1
                    continue
                if max(sa[x, y]) == 0:
                    noirs += 1
                    fuite += max(s3[x, y]) > 0
                    fuite_c += max(sc[x, y]) > 0
                    sale += max(sb[x, y]) > 0
                ecart += s3[x, y] != sc[x, y]
        print("\n== écran scindé, %s == %d pixels noirs dans A (%d instables exclus) ; la fumée sans masque en allume %d ;"
              " fuite : Gadgets %d, pochoir %d ; le pochoir diffère de Gadgets sur %d pixels"
              % (nom, noirs, instables, sale, fuite_c, fuite, ecart))
        ok = ok and fuite == 0

# LE COMPTE DES FRAGMENTS
zero = Image.open(prise("compte-zero")).convert("L").load()
murs = Image.open(prise("murs")).convert("RGB").load()
FRAG = {}
for suffixe in ("compte", "compte-visible", "compte-masque", "compte-bande-tait", "compte-bande-garde", "compte-resserre-tait",
                "compte-resserre-garde"):
    if not glob.glob(os.path.join(D, "*%s-%s.png" % (ID, suffixe))):
        continue
    im = Image.open(prise(suffixe)).convert("RGB").load()
    hist = {}
    for y in range(H):
        for x in range(W):
            if hud(x, y) or zero[x, y] > 0:
                continue
            v = im[x, y][0]
            if v:
                hist[v] = hist.get(v, 0) + 1
    # Les niveaux : les pics de l'histogramme, du plus sombre au plus clair (une couche, deux, trois, quatre).
    pics = sorted(sorted(hist, key=lambda v: -hist[v])[:12])
    niveaux = []
    for v in pics:
        if not niveaux or v - niveaux[-1] > 12:
            niveaux.append(v)
    niveaux = niveaux[:4]

    def couches(v):
        return 1 + min(range(len(niveaux)), key=lambda i: abs(niveaux[i] - v)) if v else 0

    par_couches = [0] * 5
    chemin = {"sol": 0, "face": 0, "dessus": 0}
    fragments = 0
    for y in range(H):
        for x in range(W):
            if hud(x, y) or zero[x, y] > 0:
                continue
            k = couches(im[x, y][0])
            par_couches[k] += 1
            fragments += k
            if k:
                r, g, bb = murs[x, y]
                chemin["face" if r > 128 and g > 128 else ("dessus" if r > 128 or g > 128 else "sol")] += k
    FRAG[suffixe] = fragments
    print("\n== %s == niveaux lus %s ; pixels sous 1/2/3/4 couches : %s ; FRAGMENTS %d (%.2f par pixel couvert) ;"
          " par surface montrée : %s ; exclus (allumés sans fumée) %d"
          % (suffixe, niveaux, par_couches[1:], fragments, fragments / max(1, sum(par_couches[1:])), chemin,
             sum(1 for y in range(H) for x in range(W) if zero[x, y] > 0)))
if all(k in FRAG for k in ("compte", "compte-masque", "compte-bande-tait", "compte-bande-garde")):
    bande = FRAG["compte-bande-garde"] - FRAG["compte-bande-tait"]
    print("\n== LE TRAVAIL DU MASQUE DE GADGETS == %d fragments de fumée, dont %d gardés par le masque (%.1f %%) ; %d entrent dans"
          " une bande et paient le calcul exact (%.1f %% des fragments ; comptés par différence, au moins)"
          % (FRAG["compte"], FRAG["compte-masque"], 100.0 * FRAG["compte-masque"] / FRAG["compte"], bande,
             100.0 * bande / FRAG["compte"]))
if all(k in FRAG for k in ("compte", "compte-resserre-tait", "compte-resserre-garde")):
    bande = FRAG["compte-resserre-garde"] - FRAG["compte-resserre-tait"]
    print("== LA BANDE RESSERRÉE (forme 2) == %d fragments paient le calcul exact (%.1f %% des fragments)"
          % (bande, 100.0 * bande / FRAG["compte"]))
print("\nVERDICT GLOBAL : %s" % ("toutes les formes passent la preuve" if ok else "UNE FORME ÉCHOUE"))
sys.exit(0 if ok else 1)
