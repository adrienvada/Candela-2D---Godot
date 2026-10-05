#!/usr/bin/env python3
"""Recompte V4 (contradicteur) -- lecture seule, Godot non lance.

Ports fideles (commit 52a29c1) de MapCodec.decode_runs, MapGeometry.build_grid / build_solid_grid,
NavigationBot._construire / _fabriquer_astar / _pres_d_un_mur, et des tailles d'images de
IsoMateriaux.image_proximite_usure.  Ce script COMPTE (appels, cellules, pixels) : ce sont des
nombres independants du materiel (PROUVES).  Les durees, elles, sont des ESTIMATIONS d'un modele
de cout (voir MODELE) calibre sur les deux seules mesures GDScript du depot :
  - fusee.gd:338-340 : 3 x 16 384 set_pixel (boucle a ~9 appels natifs) = 8,5 ms  -> 0,17 us/iteration (Mac M3)
  - ROADMAP l.22739 : cuisson LED 272^2 en deux passes = 83 ms -> ~10-15 ns par operation GDScript simple
A lancer depuis n'importe ou : python3 recompte_V4.py
"""
import collections
import glob
import json
import os
import statistics

DEPOT = "/home/user/Candela-2D---Godot"
BORDER = 1
TUILE = 35


def decode(s):
    cells, runs = [], 0
    if not s:
        return cells, 0
    for run in s.split(';'):
        p = run.split(',')
        if len(p) != 3:
            continue
        try:
            x, y, l = int(p[0]), int(p[1]), int(p[2])
        except ValueError:
            continue
        if l <= 0 or l > 128:
            continue
        runs += 1
        for i in range(l):
            cells.append((x + i, y))
    return cells, runs


def grilles(c):
    gx, gy = c['grid_size']['x'], c['grid_size']['y']
    fl, rf = decode(c.get('floor', ''))
    wl, rw = decode(c.get('walls', ''))
    lw, rl = decode(c.get('low_walls', ''))
    fs = {p for p in fl if 0 <= p[0] < gx and 0 <= p[1] < gy}
    ws = {p for p in wl if 0 <= p[0] < gx and 0 <= p[1] < gy}
    ls = {p for p in lw if 0 <= p[0] < gx and 0 <= p[1] < gy}
    W, H = gx + 2 * BORDER, gy + 2 * BORDER
    solid = [[False] * H for _ in range(W)]
    for ix in range(W):
        for iy in range(H):
            p = (ix - BORDER, iy - BORDER)
            walls = p in ws
            lows = (p in ls) and not walls
            pits = (p not in fs) and not walls and (p not in ls)
            solid[ix][iy] = walls or pits or lows
    return solid, dict(W=W, H=H, floor=len(fl), walls=len(wl), lows=len(lw), runs=rf + rw + rl, gx=gx, gy=gy,
                       opaque=len(ws) + len(ls - ws))


def navigation(c):
    """_construire + _fabriquer_astar : compte les appels est_libre (court-circuits GDScript respectes)."""
    solid, m = grilles(c)
    gx, gy = m['gx'], m['gy']
    k = collections.Counter()

    def est_libre(x, y):
        k['est_libre'] += 1
        if x < 0 or y < 0 or x >= gx or y >= gy:
            return False
        return not solid[x + BORDER][y + BORDER]

    def etranglee(x, y):
        if not est_libre(x - 1, y) and not est_libre(x + 1, y):
            return True
        if not est_libre(x, y - 1) and not est_libre(x, y + 1):
            return True
        return False

    prat = set()
    for cy in range(gy):
        for cx in range(gx):
            if est_libre(cx, cy) and not etranglee(cx, cy):
                prat.add((cx, cy))
    k['construire'] = k['est_libre']
    for cy in range(gy):
        for cx in range(gx):
            if (cx, cy) in prat:
                found = False
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if (dx != 0 or dy != 0) and not est_libre(cx + dx, cy + dy):
                            found = True
                            break
                    if found:
                        break
    k['astar'] = k['est_libre'] - k['construire']
    m.update(prat=len(prat), est_libre_construire=k['construire'], est_libre_astar=k['astar'])
    return m


def main():
    salles = []
    for f in sorted(glob.glob(DEPOT + '/assets/solo/chapitre_*/niveau_*.json')):
        d = json.load(open(f))
        m = navigation(d['carte'])
        m['f'] = os.path.relpath(f, DEPOT + '/assets/solo')
        m['pnj'] = d['pnj']
        m['plafonniers'] = len(d.get('plafonniers', []))
        salles.append(m)
    T = collections.Counter()
    for m in salles:
        for k in ('W', 'H', 'floor', 'walls', 'lows', 'runs', 'prat', 'est_libre_construire', 'est_libre_astar'):
            T[k] += m[k]
        T['cells'] += m['W'] * m['H']
    print("== BOT-01 : recompte de chapitres_livres() (100 salles) ==")
    print("salles                         :", len(salles))
    print("cases de grille (L+2)(H+2)     : {:,}".format(T['cells']))
    print("cases de sol / mur / mur bas   : {:,} / {:,} / {:,}".format(T['floor'], T['walls'], T['lows']))
    print("runs RLE decodes par chaine    : {:,}".format(T['runs']))
    print("cases praticables              : {:,}".format(T['prat']))
    print("est_libre dans _construire     : {:,}".format(T['est_libre_construire']))
    print("est_libre dans _fabriquer_astar: {:,}  ({:.0f} % du total)".format(
        T['est_libre_astar'], 100 * T['est_libre_astar'] / (T['est_libre_construire'] + T['est_libre_astar'])))
    dec = T['floor'] + T['walls'] + T['lows']
    print("build_grid de validation       : 3 par salle = {} ; cellules decodees+inserees : {:,}".format(
        3 * len(salles), 3 * dec))
    avec_ronde = sum(1 for m in salles if any('ronde' in p for p in m['pnj']))
    print("salles avec ronde (=> _numeroter_les_composantes a la validation) :", avec_ronde)

    print("\n-- modele de cout (ms) : 'rapide' = calibre M3 release ; 'lent' = x2,2 --")
    for nom, k in (("rapide", 1.0), ("lent", 2.2)):
        est_libre_ns, v2i, call, dict_set, dict_has = 350 * k, 30 * k, 100 * k, 80 * k, 60 * k
        construire = (T['est_libre_construire'] * est_libre_ns + T['prat'] * (call + 2 * 60 * k + dict_set + 40 * k)) / 1e6
        astar = (T['est_libre_astar'] * (est_libre_ns + 100 * k) + T['cells'] * (v2i + call + dict_has)) / 1e6
        solid = (3 * T['cells'] * 150 * k + 3 * dec * 250 * k + T['cells'] * 100 * k + 3 * T['runs'] * 1000 * k) / 1e6
        check = dec * 160 * k / 1e6
        print("{:7s}: construire {:4.0f} + A* {:4.0f} + build_solid_grid {:4.0f} + check_playable {:3.0f} = {:5.0f} ms (hors composantes)".format(
            nom, construire, astar, solid, check, construire + astar + solid + check))

    print("\n== BOT-03 : cases praticables par salle ==")
    prat = sorted(m['prat'] for m in salles)
    print("mediane {} ; > 1000 : {} salles ; > 2000 : {} salles ; max {}".format(
        prat[50], sum(1 for x in prat if x > 1000), sum(1 for x in prat if x > 2000), prat[-1]))

    print("\n== BOT-02 : modele 15 us + 3 us/plafonnier par PNJ qui voit, par pas ==")
    couts = []
    for m in salles:
        nper = sum(1 for p in m['pnj'] if ('voit' in p['profil'] or 'entend' in p['profil'] or p['profil'] == 'boss'))
        couts.append(nper * (15 + 3 * m['plafonniers']))
    couts.sort()
    print("us par pas de physique : mediane {:.0f}, p90 {:.0f}, max {:.0f}".format(couts[50], couts[90], couts[-1]))

    print("\n== GEO-02 : pixels visites par image_proximite_usure (8 blend_rect plein cadre) ==")
    print("%-22s %5s %7s %9s %9s" % ("carte", "cases", "opaque", "Mpx", "8 passes Mpx"))
    cartes = []
    for f in sorted(glob.glob(DEPOT + '/assets/maps/*.json')):
        cartes.append((os.path.basename(f), json.load(open(f))))
    cartes.append(("solo 8.9", json.load(open(DEPOT + '/assets/solo/chapitre_08/niveau_09.json'))['carte']))
    for nom, c in cartes:
        _, m = grilles(c)
        cases = (m['W'] + 2) * (m['H'] + 2)
        opaque = m['opaque'] + (cases - m['W'] * m['H'])
        mpx = cases * TUILE * TUILE / 1e6
        print("%-22s %5d %6.0f%% %9.2f %9.1f" % (nom, cases, 100 * opaque / cases, mpx, 8 * mpx))
    areas = sorted((m['W'] + 2) * (m['H'] + 2) * TUILE * TUILE / 1e6 for m in salles)
    print("100 salles solo : mediane {:.2f} Mpx, {} salles >= 3 Mpx, max {:.2f} Mpx".format(
        statistics.median(areas), sum(1 for a in areas if a >= 3.0), areas[-1]))

    print("\n== CAR-03 / BOT-04 : build_grid par depart ==")
    print("duel (iso, LED, usure par defaut) : 3 (build_collisions) + 1 (rects_monde) + 4 (MurLed) + 2 (MurEncre)"
          " + 2 (IsoGeometrie) + 2 (accorder_grille mur) + 2 (image_proximite_usure) + 4 (2 sols x 2) = 20 ; 14 avec --sans-usure")
    sup = [m for m in salles if m['f'].endswith('chapitre_08/niveau_09.json')][0]
    nper = sum(1 for p in sup['pnj'] if ('voit' in p['profil'] or 'entend' in p['profil'] or p['profil'] == 'boss'))
    print("salle 8.9 : 20 + 3 (NavigationBot) + 2 x {} (perception) = {} build_grid, grille {}x{}".format(
        nper, 20 + 3 + 2 * nper, sup['W'], sup['H']))


if __name__ == '__main__':
    main()
