#!/usr/bin/env python3
"""Le sol marqué — la DEMI-table écrite à la main, carte par carte, et ses jumeaux par la symétrie de la carte.

Ce script n'invente rien : il prend la moitié de gauche (ou la moitié « J1 » de la Croisée) posée à la main ci-dessous,
en calcule les jumeaux, vérifie la place (sol libre, 12 px au moins de tout mur, 3 cases au moins des départs) et
imprime la table GDScript de `arena_decor.gd` (SOL_MARQUE_ESSAI). La garde headless (`tools/test_sol_marque.gd`) refait
TOUTES ces vérifications de son côté, dans le jeu : ce script n'est qu'un aide-mémoire pour écrire la table.

    python3 docs/iso/cloud/sol-marque/table.py grilles.txt   # grilles : sortie de la vidange ASCII des six cartes
"""
import math, sys

T = 35.0
# famille, centre (cases, x puis y ; ,5 = entre deux cases), angle°, param, graine
#   gravats : un tas allongé au pied d'un mur, param = longueur en cases, angle = le long du mur
#   eclats  : quelques débris épars sur un disque, param = diamètre en cases
#   chaine  : une chaîne au sol, param = longueur en cases
#   cadre   : un cadre de bandes peintes, param = (largeur, hauteur) en cases — symétrique par construction
#   bande   : une bande peinte droite, param = longueur en cases — symétrique par construction
#   lettres : des lettres sombres au pochoir, param = le texte
DEMI = {
 "00000002": [  # Arène Circulaire, miroir x → 23 − x
  ("gravats", (7, 11.5), 90, 1.0, 11), ("gravats", (8, 9.5), 90, 1.0, 12), ("gravats", (6, 2), 0, 1.6, 13),
  ("gravats", (2, 16), 90, 1.6, 14), ("eclats", (5, 6), 0, 1.0, 15), ("eclats", (7.5, 17.5), 0, 1.0, 16),
  ("chaine", (6.5, 20.5), -8, 2.0, 17), ("lettres", (6, 15.5), 0, "07", 0),
  ("cadre", (11.5, 4.5), 0, (5.2, 1.4), 18), ("cadre", (11.5, 19.5), 0, (5.2, 1.4), 19),
 ],
 "00000001": [  # Arène Standard, miroir x → 31 − x
  ("gravats", (5, 3), 0, 1.8, 21), ("gravats", (11, 3), 0, 1.2, 22), ("gravats", (3, 8), 90, 2.0, 23),
  ("gravats", (3, 24), 90, 1.6, 24), ("gravats", (6, 28), 0, 2.0, 25), ("eclats", (9, 11), 0, 1.2, 26),
  ("eclats", (12, 19), 0, 1.0, 27), ("eclats", (7, 6), 0, 1.0, 28), ("chaine", (10, 26), 20, 2.4, 29),
  ("chaine", (11.5, 8.5), -30, 1.8, 30), ("lettres", (5, 11), 90, "07", 0),
  ("cadre", (15.5, 6), 0, (5.2, 1.4), 31), ("cadre", (15.5, 26), 0, (5.2, 1.4), 32), ("bande", (15.5, 16), 90, 4.0, 33),
 ],
 "map_001": [  # Le Cloître, miroir x → 29 − x
  ("gravats", (10, 12), 0, 2.2, 41), ("gravats", (8, 10), 90, 1.6, 42), ("gravats", (6, 3), 0, 1.4, 43),
  ("gravats", (3, 20), 90, 1.8, 44), ("gravats", (13, 13), 90, 1.5, 45), ("eclats", (5.5, 6.5), 0, 1.2, 46),
  ("eclats", (12, 23), 0, 1.0, 47), ("chaine", (5.5, 25), 15, 2.2, 48), ("chaine", (7, 6), -20, 1.8, 49),
  ("lettres", (4.5, 10), 90, "B-07", 0),
  ("cadre", (14.5, 5), 0, (5.2, 1.4), 50), ("cadre", (14.5, 24), 0, (5.2, 1.4), 51), ("bande", (14.5, 8), 90, 2.0, 52),
 ],
 "map_002": [  # L'Usine, miroir x → 31 − x (symétrie approchée : rien près du bloc central décalé)
  ("gravats", (7, 7.5), 90, 1.6, 61), ("gravats", (4, 3), 0, 1.6, 62), ("gravats", (8.5, 10), 0, 1.0, 63),
  ("gravats", (10, 17.5), 90, 1.6, 64), ("gravats", (7, 22), 0, 1.6, 65), ("gravats", (11, 12.5), 90, 1.0, 66),
  ("eclats", (5, 7), 0, 1.0, 67), ("eclats", (11, 21), 0, 1.0, 68), ("chaine", (11.5, 5), 10, 2.0, 69),
  ("chaine", (4.5, 17), 80, 1.8, 70), ("lettres", (4.5, 8.5), 90, "C3", 0),
  ("cadre", (15.5, 4), 0, (5.2, 1.4), 71), ("cadre", (15.5, 21), 0, (5.2, 1.4), 72),
 ],
 "map_003": [  # La Croisée, demi-tour (x, y) → (27 − x, 27 − y)
  ("gravats", (8.5, 10), 0, 2.4, 81), ("gravats", (18.5, 6), 0, 2.4, 82), ("gravats", (10, 3), 0, 1.6, 83),
  ("gravats", (3, 15), 90, 2.0, 84), ("gravats", (11, 13.5), 90, 1.0, 85), ("eclats", (13.5, 10), 0, 1.0, 86),
  ("eclats", (5, 20), 0, 1.2, 87), ("chaine", (21.5, 4.5), 170, 2.0, 88), ("chaine", (4, 23), -15, 1.8, 89),
  ("lettres", (4, 17), 90, "B-07", 0), ("cadre", (14, 4), 0, (5.2, 1.4), 90),
 ],
 "map_004": [  # Le Bunker, miroir x → 25 − x
  ("gravats", (10, 7), 0, 2.0, 101), ("gravats", (7, 8.8), 90, 1.0, 102), ("gravats", (9, 10), 90, 1.4, 103),
  ("gravats", (11, 12.5), 90, 1.0, 104), ("gravats", (6, 22), 0, 1.8, 105), ("eclats", (5, 6), 0, 1.0, 106),
  ("eclats", (10.5, 15), 0, 1.0, 107), ("chaine", (8, 5), 10, 2.0, 108), ("lettres", (4, 16), 90, "C3", 0),
  ("cadre", (12.5, 4), 0, (5.2, 1.4), 109), ("cadre", (12.5, 21), 0, (5.2, 1.4), 110),
 ],
}
SYM = {"00000002": "miroir", "00000001": "miroir", "map_001": "miroir", "map_002": "miroir", "map_003": "demi_tour",
       "map_004": "miroir"}
# ⚠️ Le jumeau par la symétrie de la carte NE SUFFIT PAS à 45° B : J2 regarde depuis le côté opposé (lacet + 180°), donc
# ce que J1 voit en p, J2 le voit en DEMI-TOUR(p) — pas en MIROIR(p). Un tas au pied SUD d'un pilier, visible de J1,
# a pour jumeau-miroir un autre pied sud : caché derrière le pilier dans la vue de J2 (mesuré : 713 pixels assombris
# dans le cône de J1, 27 dans celui de J2, écran scindé du 28/09). La table est donc fermée par le demi-tour AUSSI :
# pour une carte en miroir, par les deux miroirs et le demi-tour (les six cartes livrées ont les deux symétries —
# l'Usine à une case près). Les cadres suivent les pochoirs qu'ils encadrent (miroir gauche-droite seulement) : sur deux
# cartes, les « DEATHMATCH » ne sont pas à des places échangées par le miroir haut-bas (défaut des pochoirs, signalé).
GROUPE = {"miroir": ("mx", "my", "r"), "demi_tour": ("r",)}
SYMETRIQUES = ("cadre", "bande", "lettres")


def image(m, g, t):
    """L'image d'une marque par une transformation de la carte : « mx » (x → W−1−x), « my » (y → H−1−y), « r » (le
    demi-tour). Le motif tiré au hasard se retourne par un miroir, pas par le demi-tour ; les familles symétriques par
    construction ne se retournent jamais."""
    fam, (x, y), a, p, s = m[:5]
    retourne = m[5] if len(m) > 5 else False
    sym = fam in SYMETRIQUES
    if t == "mx":
        return (fam, (g[0] - 1 - x, y), (-a) % 360, p, s, False if sym else not retourne)
    if t == "my":
        return (fam, (x, g[1] - 1 - y), (180 - a) % 360, p, s, False if sym else not retourne)
    return (fam, (g[0] - 1 - x, g[1] - 1 - y), (a + 180) % 360, p, s, retourne)


def meme(m, q):
    """Deux marques identiques à l'image près (même place, même motif ; l'angle à un demi-tour près pour une famille
    symétrique par construction)."""
    if m[0] != q[0] or m[3] != q[3] or m[4] != q[4] or abs(m[1][0] - q[1][0]) > 1e-9 or abs(m[1][1] - q[1][1]) > 1e-9:
        return False
    periode = 180 if m[0] in SYMETRIQUES else 360
    return (m[2] - q[2]) % periode == 0 and (m[0] in SYMETRIQUES or m[5] == q[5])


def demi_taille(fam, p):
    """La demi-emprise locale (le long de l'angle, en travers), en pixels — la même que `_emprise_marque` du jeu."""
    if fam == "gravats":
        return (p * T * 0.5 + 4.0, 5.0)
    if fam == "eclats":
        return (p * T * 0.5 + 3.0, p * T * 0.5 + 3.0)
    if fam == "chaine":
        return (p * T * 0.5 + 4.0, 9.0)
    if fam == "cadre":
        return (p[0] * T * 0.5 + 2.0, p[1] * T * 0.5 + 2.0)
    if fam == "bande":
        return (p * T * 0.5, 2.5)
    return (len(p) * 5.0, 6.0)  # lettres : ~9 px par signe à 14 px de fonte, au large


def lire_grilles(chemin):
    cartes, cur = {}, None
    for l in open(chemin, encoding="utf-8"):
        if l.startswith("== "):
            mots = l.split()
            cur = {"id": mots[2], "lignes": []}
            cartes[mots[2]] = cur
        elif cur is not None and len(l) > 4 and l[:3].strip().isdigit():
            cur["lignes"].append(l[4:].rstrip("\n"))
    return cartes


def verifier(cid, marques, carte):
    lignes = carte["lignes"]
    murs, departs = set(), []
    for y, l in enumerate(lignes):
        for x, ch in enumerate(l):
            if ch == "#" or ch == " ":
                murs.add((x, y))
            if ch in "12":
                departs.append((x, y))
    fautes = []
    for m in marques:
        fam, (cx, cy), a, p = m[0], m[1], m[2], m[3]
        du, dv = demi_taille(fam, p)
        c, s = abs(math.cos(math.radians(a))), abs(math.sin(math.radians(a)))
        hx, hy = du * c + dv * s, du * s + dv * c
        px, py = (cx + 0.5) * T, (cy + 0.5) * T
        x0, x1, y0, y1 = px - hx, px + hx, py - hy, py + hy
        for (mx, my) in murs:  # 12 px de dégagement autour de tout mur
            if x0 - 12 < (mx + 1) * T and x1 + 12 > mx * T and y0 - 12 < (my + 1) * T and y1 + 12 > my * T:
                fautes.append(f"{fam} {m[1]} trop près du mur {(mx, my)}")
                break
        for (sx, sy) in departs:
            for x in range(int(x0 // T), int(x1 // T) + 1):
                for y in range(int(y0 // T), int(y1 // T) + 1):
                    if max(abs(x - sx), abs(y - sy)) < 3:
                        fautes.append(f"{fam} {m[1]} à moins de 3 cases du départ {(sx, sy)}")
                        break
                else:
                    continue
                break
    return fautes


POCHOIRS = {  # recopiés d'arena_decor.gd (POCHOIRS_ESSAI) : [texte, centre (cases), angle]
    "00000002": [("DEATHMATCH", (11.5, 4.5), 0), ("DEATHMATCH", (11.5, 19.5), 0), ("ZONE 1", (4, 18), 0), ("ZONE 2", (19, 18), 0)],
    "00000001": [("DEATHMATCH", (15.5, 6), 0), ("DEATHMATCH", (15.5, 26), 0), ("ZONE 1", (8, 23), 0), ("ZONE 2", (23, 23), 0)],
    "map_001": [("DEATHMATCH", (14.5, 5), 0), ("DEATHMATCH", (14.5, 24), 0), ("ZONE 1", (8, 22), 0), ("ZONE 2", (21, 22), 0)],
    "map_002": [("DEATHMATCH", (15.5, 4), 0), ("DEATHMATCH", (15.5, 21), 0), ("ZONE 1", (5, 20), 0), ("ZONE 2", (26, 20), 0)],
    "map_003": [("DEATHMATCH", (14, 4), 0), ("DEATHMATCH", (13, 23), 180), ("ZONE 1", (5, 11), 0), ("ZONE 2", (22, 16), 180)],
    "map_004": [("DEATHMATCH", (12.5, 4), 0), ("DEATHMATCH", (12.5, 21), 0), ("ZONE 1", (5, 20), 0), ("ZONE 2", (20, 20), 0)],
}


def boite(fam, c, a, p):
    du, dv = demi_taille(fam, p)
    co, si = abs(math.cos(math.radians(a))), abs(math.sin(math.radians(a)))
    hx, hy = du * co + dv * si, du * si + dv * co
    px, py = (c[0] + 0.5) * T, (c[1] + 0.5) * T
    return px - hx, px + hx, py - hy, py + hy


def chevauchements(cid, marques):
    out = []
    for m in marques:
        if m[0] == "cadre":
            continue
        a = boite(m[0], m[1], m[2], m[3])
        for (t, c, ang) in POCHOIRS.get(cid, []):
            b = boite("lettres", c, ang, " " * int(len(t) * 1.8))  # ~9 px par signe à 20 px de fonte
            if a[0] < b[1] and a[1] > b[0] and a[2] < b[3] and a[3] > b[2]:
                out.append(f"{m[0]} {m[1]} chevauche le pochoir {t} {c}")
    return out


def gd(v):
    if isinstance(v, str):
        return '"%s"' % v
    if isinstance(v, tuple):
        return "Vector2(%s, %s)" % (gd(v[0]), gd(v[1]))
    if isinstance(v, bool):
        return "true" if v else "false"
    f = float(v)
    return ("%d" % f if f == int(f) else ("%g" % f)) + (".0" if f == int(f) else "")


def main():
    cartes = lire_grilles(sys.argv[1]) if len(sys.argv) > 1 else {}
    tailles = {"00000002": (24, 24), "00000001": (32, 32), "map_001": (30, 30), "map_002": (32, 26),
               "map_003": (28, 28), "map_004": (26, 26)}
    total = 0
    print("const SOL_MARQUE_ESSAI := {")
    for cid, demi in DEMI.items():
        g, sym = tailles[cid], SYM[cid]
        toutes = []
        for m in demi:
            m = m + (False,)
            transfos = (("mx",) if sym == "miroir" else ("r",)) if m[0] == "cadre" else GROUPE[sym]
            for q in [m] + [image(m, g, t) for t in transfos]:
                if not any(meme(q, r) for r in toutes):
                    toutes.append(q)
        if cid in cartes:
            for f in verifier(cid, toutes, cartes[cid]) + chevauchements(cid, toutes):
                print("# ✗", cid, f, file=sys.stderr)
        total += len(toutes)
        print('\t"%s": [' % cid)
        for m in toutes:
            print("\t\t[%s, %s, %s, %s, %d, %s]," % (gd(m[0]), gd(m[1]), gd(float(m[2])), gd(m[3]), m[4], gd(m[5])))
        print("\t],")
    print("}")
    print("# %d marques" % total, file=sys.stderr)


main()
