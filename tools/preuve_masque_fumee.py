#!/usr/bin/env python3
"""LA PREUVE À L'IMAGE DU MASQUE DE LA FUMÉE (ISO13, Q31) — l'analyse des captures de `loupe-fusee-masque-preuve`.

Règles déclarées par la session cloud AVANT les chiffres (2026-09-25 : 14:01, 14:07, 14:16, 16:02, 16:11, 18:34), à ne
jamais changer en route :
  - HUD exclu.
  - ENSEMBLE INSTABLE : l'union des pixels qui diffèrent entre les CINQ prises de référence (a, a1, a2, a3, a4 : deux avant B,
    une entre B et C, deux après C), dilatée d'un pixel ; plus le corps de J1 (classe « autre » de la carte des murs). Exclu
    de tous les critères, compté et montré à part. RIEN D'AUTRE N'EST EXCLU : J2, l'adversaire, est jugé comme le reste.
  1. Fuite ZÉRO partout (sol, faces, dessus), bande de 5 px comprise : là où A est noir, C est noir.
  2. Perte ZÉRO sur les faces et les dessus (A > 7/255 et C ≠ B) ; les dessus des murs hauts comptés à part (exception
     déclarée). Au SOL, perte zéro, sauf à un pixel au plus d'une frontière noir/non-noir du sol dans A, ou sur une couture
     de `glisse` que le masque détecte (carte optionnelle, voir plus bas) : les deux ensemble, 200 au plus par lancement,
     les coutures comptées À PART.
  3. Témoins : B ≠ A et C ≠ B quelque part (du même ordre qu'au 25/09 : B ≠ A ≈ 239 600 au sommet des LED, ≈ 72 800 au
     creux, sur la carte du Cloître et la même fusée).
Les TROUS (un pixel de sol noir dans A dont les huit voisins ne le sont pas, fumée en B, silence en C) sont comptés et
montrés ; ils se jugent sur l'image (acceptés le 2026-09-25, 4 au sommet et 28 au creux).

Référence de V1f (commit b8c1b49, 2026-09-25 20:38) : sommet 0 fuite, 0 perte ; creux 0 fuite, 9 pertes au sol (8 à la
frontière, 1 sur une couture).

    python3 tools/preuve_masque_fumee.py <dossier> <prefixe> [<carte_des_coutures>]

<dossier>/<prefixe>-{a,a1,b,a2,c,a3,a4,murs}.png, écrits par `tools/preuve_masque_fumee.sh`. La carte des coutures est un
préfixe `<dossier>/<prefixe>` dont les prises `-b` et `-c` viennent d'un instrument NON commité qui peint, là où la fumée
est dessinée, en rouge la couture z et en vert la couture x (au même repère 2D) ; sans elle, une perte sur une couture
compte « ailleurs ». Sort 0 si la preuve passe, 1 sinon. Pillow requis (pas numpy)."""
import sys
from PIL import Image

D, P = sys.argv[1], sys.argv[2]
COUT = sys.argv[3] if len(sys.argv) > 3 else None
HUD = [(0, 0, 580, 185), (1130, 0, 1336, 100)]
AS = ("a1", "a2", "a3", "a4")
im = {k: Image.open("%s/%s-%s.png" % (D, P, k)).convert("RGB") for k in ("a", "b", "c", "murs") + AS}
W, H = im["a"].size
a, b, c, mu = (im[k].load() for k in ("a", "b", "c", "murs"))
autres = [im[k].load() for k in AS]
if COUT:
    _cc = Image.open(COUT + "-c.png").convert("RGB").load()
    _cb = Image.open(COUT + "-b.png").convert("RGB").load()


def couture(x, y):
    return bool(COUT) and _cc[x, y] != _cb[x, y] and (_cc[x, y][0] > 150 or _cc[x, y][1] > 150)


def hud(x, y):
    return any(x0 <= x < x1 and y0 <= y < y1 for x0, y0, x1, y1 in HUD)


def classe(p):
    r, g, bl = p
    if r > 200 and g > 200 and bl > 200:
        return "faces"
    if r > 200 and g < 60 and bl < 60:
        return "dessus hauts"
    if g > 200 and r < 60 and bl < 60:
        return "dessus murets"
    if max(p) < 20:
        return "sol"
    return "corps"


print("règles : HUD exclu %s ; instable = écarts entre les cinq A dilatés d'un pixel, + le corps de J1 ; rien d'autre" % HUD)
brut = [[any(a[x, y] != o[x, y] for o in autres) for x in range(W)] for y in range(H)]
instable = [[False] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        if brut[y][x]:
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if 0 <= y + dy < H and 0 <= x + dx < W:
                        instable[y + dy][x + dx] = True


def frontiere_sol(x, y):
    n0 = max(a[x, y]) == 0
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            xx, yy = x + dx, y + dy
            if 0 <= xx < W and 0 <= yy < H and (max(a[xx, yy]) == 0) != n0:
                return True
    return False


def pres_d_un_bord(x, y):
    m = classe(mu[x, y]) not in ("sol", "corps")
    for dy in range(-5, 6):
        for dx in range(-5, 6):
            xx, yy = x + dx, y + dy
            if 0 <= xx < W and 0 <= yy < H and (classe(mu[xx, yy]) not in ("sol", "corps")) != m:
                return True
    return False


cl = {k: {"noirs": 0, "eclaires": 0, "fuite": [], "perdue": []} for k in ("sol", "faces", "dessus murets", "dessus hauts")}
exclus = {"instable": 0, "corps": 0}
exc_fuite = exc_perdue = 0
bd = cd = 0
for y in range(H):
    for x in range(W):
        if hud(x, y):
            continue
        k = classe(mu[x, y])
        pa = a[x, y]
        if b[x, y] != pa:
            bd += 1
        if c[x, y] != b[x, y]:
            cd += 1
        if k == "corps" or instable[y][x]:
            exclus["corps" if k == "corps" else "instable"] += 1
            if max(pa) == 0 and max(c[x, y]) > 0:
                exc_fuite += 1
            if max(pa) > 7 and c[x, y] != b[x, y]:
                exc_perdue += 1
            continue
        e = cl[k]
        if max(pa) == 0:
            e["noirs"] += 1
            if max(c[x, y]) > 0:
                e["fuite"].append((x, y, max(c[x, y])))
        else:
            e["eclaires"] += 1
            if max(pa) > 7 and c[x, y] != b[x, y]:
                e["perdue"].append((x, y, max(pa)))


def hist(v):
    h = {}
    for t in v:
        h[t] = h.get(t, 0) + 1
    return dict(sorted(h.items()))


def boite(p):
    return (min(q[0] for q in p), min(q[1] for q in p), max(q[0] for q in p), max(q[1] for q in p)) if p else None


print("exclus : %d pixels instables (cinq A), %d du corps de J1 — dont %d « fuites » et %d « pertes », comptées à part"
      % (exclus["instable"], exclus["corps"], exc_fuite, exc_perdue))
ok = True
for k in ("sol", "faces", "dessus murets", "dessus hauts"):
    e = cl[k]
    bande = sum(1 for q in e["fuite"] if pres_d_un_bord(q[0], q[1]))
    print("%-13s : %d noirs dans A, %d éclairés" % (k, e["noirs"], e["eclaires"]))
    print("   1. fuite : %d%s" % (len(e["fuite"]), "" if not e["fuite"] else " (dont %d dans la bande de 5 px) · boîte %s · C %s"
                                  % (bande, boite(e["fuite"]), hist([q[2] for q in e["fuite"]]))))
    ok = ok and not e["fuite"]
    if k == "sol":
        fr = [q for q in e["perdue"] if frontiere_sol(q[0], q[1])]
        co = [q for q in e["perdue"] if not frontiere_sol(q[0], q[1]) and couture(q[0], q[1])]
        hors = [q for q in e["perdue"] if not frontiere_sol(q[0], q[1]) and not couture(q[0], q[1])]
        print("   2. perte : %d, dont %d à un pixel d'une frontière noir/non-noir, %d sur une couture (%s) — ensemble ≤ 200 admis — et %d ailleurs%s"
              % (len(e["perdue"]), len(fr), len(co), ", ".join("(%d, %d)" % (q[0], q[1]) for q in co[:8]) or "aucune",
                 len(hors), "" if not hors else " · boîte %s · A %s" % (boite(hors), hist([q[2] for q in hors]))))
        ok = ok and not hors and len(fr) + len(co) <= 200
    elif k == "dessus hauts":
        print("   2. perte (exception déclarée, comptée à part) : %d%s"
              % (len(e["perdue"]), "" if not e["perdue"] else " · A %s" % hist([q[2] for q in e["perdue"]])))
    else:
        print("   2. perte : %d%s" % (len(e["perdue"]), "" if not e["perdue"] else " · boîte %s · A %s"
                                      % (boite(e["perdue"]), hist([q[2] for q in e["perdue"]]))))
        ok = ok and not e["perdue"]
trous = []
for y in range(1, H - 1):
    for x in range(1, W - 1):
        if hud(x, y) or instable[y][x] or classe(mu[x, y]) != "sol" or max(a[x, y]) != 0:
            continue
        if b[x, y] == a[x, y] or c[x, y] != a[x, y]:
            continue
        if all(max(a[x + dx, y + dy]) > 0 for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dx, dy) != (0, 0)):
            trous.append((x, y))
print("   trous (sol noir isolé, fumée tue en C, visible en B) : %d%s"
      % (len(trous), "" if not trous else " · boîte %s" % str(boite([(x, y, 0) for x, y in trous]))))
print("3. témoins : B ≠ A sur %d pixels · C ≠ B sur %d pixels" % (bd, cd))
ok = ok and bd > 0 and cd > 0
print("VERDICT : %s" % ("PASSE" if ok else "ÉCHOUE"))
carte = im["b"].copy()
pk = carte.load()
for y in range(H):
    for x in range(W):
        if instable[y][x]:
            pk[x, y] = (40, 40, 120)
for k in cl:
    for q in cl[k]["fuite"]:
        pk[q[0], q[1]] = (255, 0, 255)
    for q in cl[k]["perdue"]:
        pk[q[0], q[1]] = (0, 255, 255)
for x, y in trous:
    pk[x, y] = (255, 255, 0)
carte.save("%s/%s-carte.png" % (D, P))
sys.exit(0 if ok else 1)
