"""ISO14 — prototype Python du banc d'équité (écrit le 2026-09-24 sans aucun Godot : le Mac était à Adrien).

Même règle que la ligne des Décisions actées (session cloud, 2026-09-24 01:44). Sert à valider l'algorithme avant le
portage en GDScript, et à prévoir ce que le banc imprimera. **Les chiffres du banc GDScript doivent être les MÊMES** :
ce script écrit `reference_prototype.json` à côté de lui, que `tools/banc_equite.gd` relit pour imprimer, carte par
carte, son écart maximal avec ce calcul-ci (demande de la session cloud, 05:00). Deux écritures du même algorithme
qui rendent les mêmes chiffres : la preuve que le portage n'a rien perdu. L'algorithme lui-même se vérifie ailleurs,
contre `analyser_equite` (la garde (4) du banc, et `tools/test_iso_equite.gd`).

Usage : python3 docs/iso/iso14/proto_equite.py [slug…]   (depuis la racine du dépôt ; ~40 s pour les six cartes)"""
import json
import math
import sys
import time

T = 35.0                                   # tuile (CandelaTileSet.TILE_SIZE)
TANGAGE = 52.0
H_HAUT = 1.25                              # MapGeometry.HAUTEUR_MUR_HAUT
BANDE = H_HAUT * T / math.tan(math.radians(TANGAGE))
RAYON = 18.0                               # hitbox d'un corps
ABRI = 1.5 * T                             # « p à l'abri de q » : un mur à moins d'1,5 case de p
LIGNES = 8                                 # lignes de vue par case pour l'aire cachée
import os
ICI = os.path.dirname(os.path.abspath(__file__))
MAPS = os.path.join(ICI, "..", "..", "..", "assets", "maps") + os.sep
REFERENCE = os.path.join(ICI, "reference_prototype.json")
CARTES = ["default", "arene_circulaire", "map_001_le_cloitre", "map_002_l_usine", "map_003_la_croisee",
          "map_004_le_bunker"]


def runs(s):
    out = []
    for r in s.split(";"):
        if not r:
            continue
        x, y, n = (int(v) for v in r.split(","))
        out += [(x + i, y) for i in range(n)]
    return out


def vers_camera(lacet):
    """Direction horizontale, au sol, du point vers la caméra (base.z de CameraIso, en (x, z) = (x, y 2D))."""
    a = math.radians(lacet)
    return (math.sin(a), math.cos(a))


def traverser(ox, oy, dx, dy, longueur):
    """DDA exact : les cases traversées par le segment [o, o + longueur·d], avec (case, t_entrée, t_sortie)."""
    cx, cy = math.floor(ox / T), math.floor(oy / T)
    pas_x = 1 if dx > 0 else -1
    pas_y = 1 if dy > 0 else -1
    inf = float("inf")
    tmx = ((cx + (pas_x > 0)) * T - ox) / dx if abs(dx) > 1e-12 else inf
    tmy = ((cy + (pas_y > 0)) * T - oy) / dy if abs(dy) > 1e-12 else inf
    tdx = T / abs(dx) if abs(dx) > 1e-12 else inf
    tdy = T / abs(dy) if abs(dy) > 1e-12 else inf
    t = 0.0
    out = []
    while t < longueur:
        suivant = min(tmx, tmy)
        out.append(((cx, cy), t, min(suivant, longueur)))
        t = suivant
        if tmx < tmy:
            cx += pas_x
            tmx += tdx
        elif tmy < tmx:
            cy += pas_y
            tmy += tdy
        else:                              # coin exact : les deux à la fois
            cx += pas_x
            cy += pas_y
            tmx += tdx
            tmy += tdy
    return out


def point_cache(px, py, d, murs):
    for (c, t0, t1) in traverser(px, py, d[0], d[1], BANDE):
        if t1 > t0 + 1e-9 and t0 > -1e-9 and c in murs:
            return True
    return False


def part_case(case, d, murs):
    """Aire cachée d'une case de sol / aire de la case : lignes de vue parallèles à d, longueur cachée exacte sur chacune."""
    x0, y0 = case[0] * T, case[1] * T
    n = (-d[1], d[0])
    coins = [(x0, y0), (x0 + T, y0), (x0, y0 + T), (x0 + T, y0 + T)]
    us = [c[0] * n[0] + c[1] * n[1] for c in coins]
    u0, u1 = min(us), max(us)
    du = (u1 - u0) / LIGNES
    aire = 0.0
    longueur_max = 0.0
    for k in range(LIGNES):
        u = u0 + (k + 0.5) * du
        # corde de la case sur la ligne {u·n + t·d}
        ta, tb = -1e18, 1e18
        for (o, dd, lo, hi) in ((u * n[0], d[0], x0, x0 + T), (u * n[1], d[1], y0, y0 + T)):
            if abs(dd) < 1e-12:
                if not (lo <= o <= hi):
                    ta, tb = 1, 0
                continue
            a, b = (lo - o) / dd, (hi - o) / dd
            ta, tb = max(ta, min(a, b)), min(tb, max(a, b))
        if tb <= ta:
            continue
        ox, oy = u * n[0] + ta * d[0], u * n[1] + ta * d[1]
        intervalles = []
        for (c, t0, t1) in traverser(ox, oy, d[0], d[1], (tb - ta) + BANDE):
            if c in murs and t1 > t0 + 1e-9:
                intervalles.append((t0 - BANDE, t1))
        cache = 0.0
        fin = 0.0
        for (a, b) in sorted(intervalles):
            a, b = max(a, fin, 0.0), min(b, tb - ta)
            if b > a:
                cache += b - a
                fin = b
        aire += cache * du
        longueur_max = max(longueur_max, cache)
    return aire / (T * T), longueur_max


def carte(slug):
    data = json.load(open(MAPS + slug + ".json"))
    g = (int(data["grid_size"]["x"]), int(data["grid_size"]["y"]))
    murs = set(runs(data.get("walls", "")))
    sol = [c for c in runs(data.get("floor", "")) if c not in murs and 0 <= c[0] < g[0] and 0 <= c[1] < g[1]]
    s1 = (data["spawn_p1"]["x"], data["spawn_p1"]["y"])
    s2 = (data["spawn_p2"]["x"], data["spawn_p2"]["y"])
    return data, g, murs, sol, s1, s2


def poids(c, s1, s2):
    d1 = (c[0] - s1[0]) ** 2 + (c[1] - s1[1]) ** 2
    d2 = (c[0] - s2[0]) ** 2 + (c[1] - s2[1]) ** 2
    return (1.0, 0.0) if d1 < d2 else ((0.0, 1.0) if d2 < d1 else (0.5, 0.5))


def symetries(g, murs, sol, s1, s2):
    W, H = g
    tr = {"centrale": lambda c: (W - 1 - c[0], H - 1 - c[1]),
          "miroir gauche-droite": lambda c: (W - 1 - c[0], c[1]),
          "miroir haut-bas": lambda c: (c[0], H - 1 - c[1])}
    if W == H:
        tr["diagonale"] = lambda c: (c[1], c[0])
        tr["anti-diagonale"] = lambda c: (H - 1 - c[1], W - 1 - c[0])
    lignes = []
    for nom, f in tr.items():
        echange = f(s1) == s2 and f(s2) == s1
        hors = sum(1 for c in murs if f(c) not in murs)
        lignes.append((nom, echange, hors))
    return lignes


def main():
    reference = {}
    for slug in (sys.argv[1:] or CARTES):
        reference[slug] = {}
        t_depart = time.time()
        data, g, murs, sol, s1, s2 = carte(slug)
        print("\n=== %s — %d×%d, %d cases de sol, %d de mur, apparitions %s et %s ===" % (
            slug, g[0], g[1], len(sol), len(murs), s1, s2))
        for (nom, echange, hors) in symetries(g, murs, sol, s1, s2):
            print("  symétrie %-22s échange les apparitions : %-3s  murs hors symétrie : %d" % (
                nom, "oui" if echange else "non", hors))
        w = {c: poids(c, s1, s2) for c in sol}
        # Les points p (5 × 5 par case) et leur compte d'abris contre les centres q de l'autre moitié : ne dépend
        # d'aucune caméra, calculé une fois.
        pts = []
        for c in sol:
            for i in range(5):
                for j in range(5):
                    pts.append((c, (c[0] + (i + 0.5) / 5) * T, (c[1] + (j + 0.5) / 5) * T))
        proches = set()
        for c in murs:
            for ox in range(-2, 3):
                for oy in range(-2, 3):
                    proches.add((c[0] + ox, c[1] + oy))
        abri = []                          # par point : (poids q abritants, poids q total) pour chaque joueur
        for (c, px, py) in pts:
            a = [0.0, 0.0]
            tot = [0.0, 0.0]
            for q in sol:
                qx, qy = (q[0] + 0.5) * T, (q[1] + 0.5) * T
                for i in range(2):
                    wp, wq = w[c][i], w[q][1 - i]
                    if wp * wq == 0.0:
                        continue
                    tot[i] += wp * wq
                    if c in proches:
                        dx, dy = qx - px, qy - py
                        L = math.hypot(dx, dy)
                        if L < 1e-9:
                            continue
                        for (cc, t0, t1) in traverser(px, py, dx / L, dy / L, min(ABRI, L)):
                            if cc in murs and t1 > t0 + 1e-9:
                                a[i] += wp * wq
                                break
            abri.append((a, tot))
        tot_couples = [sum(t[1][i] for t in abri) for i in range(2)]
        abri_couples = [sum(t[0][i] for t in abri) for i in range(2)]
        print("  abris : J1 à l'abri dans %.1f %% des couples, J2 dans %.1f %% (sans caméra)" % (
            100 * abri_couples[0] / tot_couples[0], 100 * abri_couples[1] / tot_couples[1]))

        cache_par_lacet = {}

        def releve(lacet):
            if lacet in cache_par_lacet:
                return cache_par_lacet[lacet]
            d = vers_camera(lacet)
            parts = {c: part_case(c, d, murs) for c in sol}
            ptc = [point_cache(px, py, d, murs) for (c, px, py) in pts]
            # corps entièrement cachés : centres tous les 5 px, disque hors des murs, 25 points du disque cachés
            corps = 0
            disque = [(0.0, 0.0)] + [(r * math.cos(k * math.pi / n), r * math.sin(k * math.pi / n))
                                     for (r, n) in ((9.0, 4), (18.0, 8)) for k in range(2 * n)]
            for c in sol:
                for i in range(7):
                    for j in range(7):
                        cx, cy = c[0] * T + 2.5 + 5 * i, c[1] * T + 2.5 + 5 * j
                        libre = all((math.floor((cx + ox) / T), math.floor((cy + oy) / T)) not in murs
                                    for (ox, oy) in disque)
                        if libre and all(point_cache(cx + ox, cy + oy, d, murs) for (ox, oy) in disque):
                            corps += 1
            r = {"parts": parts, "pts": ptc, "corps": corps,
                 "invisibles": sum(1 for c in sol if parts[c][0] >= 1 - 1e-6),
                 "longueur_max": max(p[1] for p in parts.values()),
                 "totale": sum(p[0] for p in parts.values()) / len(sol)}
            cache_par_lacet[lacet] = r
            return r

        def moities(r_adv_j1, r_adv_j2):
            """Part cachée de la moitié de chaque joueur SUR L'ÉCRAN DE SON ADVERSAIRE."""
            out = []
            for i, r in ((0, r_adv_j1), (1, r_adv_j2)):
                s = sum(w[c][i] for c in sol)
                out.append(sum(w[c][i] * r["parts"][c][0] for c in sol) / s)
            return out

        def apparitions(r_adv_j1, r_adv_j2):
            out = []
            for s, r in ((s1, r_adv_j1), (s2, r_adv_j2)):
                cs = [c for c in sol if math.hypot(c[0] - s[0], c[1] - s[1]) <= 6.0]
                out.append(sum(r["parts"][c][0] for c in cs) / len(cs))
            return out

        def abri_cache(r_adv_j1, r_adv_j2):
            out, cond = [], []
            for i, r in ((0, r_adv_j1), (1, r_adv_j2)):
                num = sum(abri[k][0][i] for k in range(len(pts)) if r["pts"][k])
                out.append(num / tot_couples[i])
                cond.append(num / abri_couples[i] if abri_couples[i] > 0 else 0.0)
            return out, cond

        ref = None
        for lacet in (0.0, 45.0):
            for nom, (l1, l2) in (("A", (lacet, lacet)), ("B", (lacet, lacet + 180.0)), ("C", (lacet, -lacet))):
                if lacet == 0.0 and nom == "C":
                    continue               # C = A à 0°
                r1, r2 = releve(l1), releve(l2)
                m = moities(r2, r1)        # la moitié de J1 vue par J2, celle de J2 vue par J1
                a = apparitions(r2, r1)
                e, econd = abri_cache(r2, r1)
                ecart = abs(m[0] - m[1]) * 100
                if lacet == 0.0 and nom == "A":
                    ref = ecart
                ok0 = r1["invisibles"] == 0 and r2["invisibles"] == 0 and r1["corps"] == 0 and r2["corps"] == 0
                oka = ecart <= 1.0 and ecart <= ref + 0.5
                okb = abs(a[0] - a[1]) * 100 <= 1.0
                oke = abs(e[0] - e[1]) * 100 <= 1.0
                reference[slug]["%d%s" % (lacet, nom)] = {
                    "moitie_j1": m[0], "moitie_j2": m[1], "apparition_j1": a[0], "apparition_j2": a[1],
                    "abri_j1": e[0], "abri_j2": e[1], "abri_cond_j1": econd[0], "abri_cond_j2": econd[1],
                    "invisibles_j1": r1["invisibles"], "invisibles_j2": r2["invisibles"],
                    "corps_j1": r1["corps"], "corps_j2": r2["corps"],
                    "longueur_max_j1": r1["longueur_max"], "longueur_max_j2": r2["longueur_max"],
                    "totale_j1": r1["totale"], "totale_j2": r2["totale"]}
                print("  %3d° %s (J1 %4d°, J2 %4d°) : moitiés %5.2f / %5.2f %% (écart %4.2f)  apparitions %5.2f / %5.2f"
                      "  abri caché %5.2f / %5.2f (sachant l'abri %5.2f / %5.2f)  invisibles %d/%d  corps cachés %d/%d"
                      "  long. max %4.1f/%4.1f px  totale %5.2f/%5.2f %%  → %s%s" % (
                          lacet, nom, l1, l2, 100 * m[0], 100 * m[1], ecart, 100 * a[0], 100 * a[1],
                          100 * e[0], 100 * e[1], 100 * econd[0], 100 * econd[1],
                          r1["invisibles"], r2["invisibles"], r1["corps"], r2["corps"],
                          r1["longueur_max"], r2["longueur_max"], 100 * r1["totale"], 100 * r2["totale"],
                          "ÉQUITABLE" if ok0 and oka and okb and oke else "NON",
                          "" if ok0 and oka and okb and oke else " (" + ",".join(
                              k for k, v in (("0", ok0), ("a", oka), ("b", okb), ("e", oke)) if not v) + ")"))
        r0, r45 = releve(0.0), releve(45.0)
        print("  (d) prix de l'angle : part totale cachée 45° / 0° = %.2f" % (r45["totale"] / r0["totale"]))
        print("  (%.1f s)" % (time.time() - t_depart))
    if not sys.argv[1:]:
        with open(REFERENCE, "w", encoding="utf-8") as f:
            json.dump(reference, f, indent=1, sort_keys=True)
        print("\nréférence écrite : %s" % REFERENCE)


main()
