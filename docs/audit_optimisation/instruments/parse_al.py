#!/usr/bin/env python3
"""Lit les journaux de la « ferme » de démarrage (lignes `[AL] …`) et rend, par autoload, le coût de son `_init` (chargement du script +
instanciation) et de son `_ready` (entrée dans l'arbre + prêt), puis les jalons de la scène principale.

Usage : parse_al.py <journal> [<journal> …]   (plusieurs journaux : la médiane de chaque grandeur)
"""
import re
import statistics
import sys

RE_INIT = re.compile(r"^\[AL\] init (\S+) (\d+)")
RE_READY = re.compile(r"^\[AL\] ready (\S+) (\d+)")
RE_SCENE = re.compile(r"^\[AL\] scene_sonde_ready (\d+)")
RE_MAIN = re.compile(r"^\[AL\] main\.tscn (\w+) (\d+)")
RE_SCRIPT = re.compile(r"^\[AL\] script (\S+) (\d+)")
RE_FIN = re.compile(r"^\[AL\] fin_mesures (\d+)")
RE_IMAGES = re.compile(r"^\[AL\] images 1-12 \(ms\) : (.*)")
RE_REG = re.compile(r"^\[AL\] images 13-\d+ \(ms\) : médiane ([0-9.]+), p99 ([0-9.]+), max ([0-9.]+)")


def lire(chemin):
    r = {"init": [], "ready": [], "main": {}, "images": [], "regime": None}
    for l in open(chemin, encoding="utf-8", errors="replace"):
        m = RE_INIT.match(l)
        if m:
            r["init"].append((m.group(1), int(m.group(2))))
            continue
        m = RE_READY.match(l)
        if m:
            r["ready"].append((m.group(1), int(m.group(2))))
            continue
        m = RE_SCENE.match(l)
        if m:
            r["scene"] = int(m.group(1))
            continue
        m = RE_MAIN.match(l)
        if m:
            r["main"][m.group(1)] = int(m.group(2))
            continue
        m = RE_SCRIPT.match(l)
        if m:
            r.setdefault("scripts", []).append((m.group(1), int(m.group(2))))
            continue
        m = RE_IMAGES.match(l)
        if m:
            r["images"] = [float(x) for x in m.group(1).split()]
            continue
        m = RE_REG.match(l)
        if m:
            r["regime"] = tuple(float(x) for x in m.groups())
            continue
        m = RE_FIN.match(l)
        if m:
            r["fin"] = int(m.group(1))
    return r


def deltas(r):
    """{nom: (init_ms, ready_ms)}, et les jalons en ms."""
    out = {}
    prev = 0
    noms = []
    for nom, t in r["init"]:
        out[nom] = [(t - prev) / 1000.0, None]
        prev = t
        noms.append(nom)
    avant_ready = prev
    prev_r = avant_ready
    for nom, t in r["ready"]:
        if nom in out:
            out[nom][1] = (t - prev_r) / 1000.0
        prev_r = t
    jalons = {
        "premier_init_depuis_demarrage": r["init"][0][1] / 1000.0 if r["init"] else None,
        "dernier_init_depuis_demarrage": r["init"][-1][1] / 1000.0 if r["init"] else None,
        "dernier_ready_depuis_demarrage": r["ready"][-1][1] / 1000.0 if r["ready"] else None,
        "scene_sonde_ready": r.get("scene", 0) / 1000.0,
        "fin": r.get("fin", 0) / 1000.0,
    }
    for k, v in r["main"].items():
        jalons["main.tscn " + k] = v / 1000.0
    return noms, out, jalons


if __name__ == "__main__":
    runs = [lire(c) for c in sys.argv[1:]]
    ds = [deltas(r) for r in runs]
    noms = ds[0][0]
    print("%-22s %12s %12s   (médiane de %d lancement(s), ms)" % ("autoload", "_init", "_ready", len(runs)))
    tot_i = tot_r = 0.0
    for n in noms:
        ii = [d[1][n][0] for d in ds if n in d[1]]
        rr = [d[1][n][1] for d in ds if n in d[1] and d[1][n][1] is not None]
        mi = statistics.median(ii) if ii else 0.0
        mr = statistics.median(rr) if rr else 0.0
        tot_i += mi
        tot_r += mr
        print("%-22s %12.1f %12.1f" % (n, mi, mr))
    print("%-22s %12.1f %12.1f" % ("TOTAL des autoloads", tot_i, tot_r))
    ks = ds[0][2].keys()
    print("\nJalons (ms depuis le démarrage du processus, médiane) :")
    for k in ks:
        vals = [d[2][k] for d in ds if d[2].get(k) is not None]
        if vals:
            print("  %-34s %10.1f" % (k, statistics.median(vals)))
    if runs[0].get("scripts"):
        print("\nCoût incrémental du chargement des plus gros scripts (ms, médiane) :")
        noms_s = [n for n, _ in runs[0]["scripts"]]
        for n in noms_s:
            vals = [dict(r["scripts"]).get(n, 0) / 1000.0 for r in runs if r.get("scripts")]
            print("  %-34s %10.1f" % (n, statistics.median(vals)))
    imgs = [r["images"] for r in runs if r["images"]]
    if imgs:
        print("\nimages 1 à 12 (ms), lancement le plus proche de la médiane de la 1re image :")
        imgs.sort(key=lambda x: x[0])
        print("  " + " ".join("%.1f" % x for x in imgs[len(imgs) // 2]))
    regs = [r["regime"] for r in runs if r["regime"]]
    if regs:
        print("images 13 à 150 : médiane %.2f ms, p99 %.2f, max %.2f" % tuple(statistics.median([x[i] for x in regs]) for i in range(3)))
