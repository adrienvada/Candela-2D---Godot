#!/usr/bin/env python3
"""Tableau de décomposition d'une série (audit M) : pour chaque étiquette, les moyennes d'image de ses prises VALIDES (la dernière de
chaque rang), l'écart à la référence DE LA MÊME SÉRIE, le rapport en cadence, et — quand la prise portait `--sonde` — les compteurs
de rendu (appels de dessin, objets, primitives, lumières à ombre, part des scripts dans l'image).

Usage : tableau.py <dossier> <série> [<référence>=A] [--md]
"""
import glob
import os
import re
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analyse import analyser  # noqa: E402

args = [a for a in sys.argv[1:] if not a.startswith("--")]
md = "--md" in sys.argv
dossier, serie = args[0], args[1]
ref = args[2] if len(args) > 2 else "A"

RE_GLOBAL = re.compile(r"appels de dessin (\d+) / (\d+) / (\d+) · objets (\d+) / (\d+) / (\d+) · primitives (\d+) / (\d+) / (\d+)")
RE_PROC = re.compile(r"TIME_PROCESS \(scripts\+process, sans rendu\) : moyenne ([0-9.]+) ms · TIME_PHYSICS_PROCESS : moyenne ([0-9.]+) ms")
RE_LUM = re.compile(r"lumières 2D allumées \(médiane / max\) : (\d+) / (\d+) dont à ombre (\d+) / (\d+)")
RE_BBC = re.compile(r"PAR IMAGE — BackBufferCopy visibles : moyenne ([0-9.]+) \(min (\d+), max (\d+)\) · CanvasItem visibles qui lisent l'écran \(hint_screen_texture\) : moyenne ([0-9.]+)")
RE_VUES = re.compile(r"viewports recensés : (\d+), dont qui rendent \(mode ≠ DISABLED\) : (\d+), pour ([0-9.]+) Mpx")

par_rang = {}
for f in sorted(glob.glob(os.path.join(dossier, "%s_*.log" % serie))):
    m = re.match(r"%s_(\d+)_(.+?)(_r\d+)?\.log$" % re.escape(serie), os.path.basename(f))
    if not m:
        continue
    rang, etiquette, essai = int(m.group(1)), m.group(2), m.group(3) or ""
    r = analyser(f)
    texte = open(f, encoding="utf-8", errors="replace").read()
    r["fichier"] = os.path.basename(f)
    mg = RE_GLOBAL.search(texte)
    if mg:
        r["dc"], r["obj"], r["prim"] = int(mg.group(1)), int(mg.group(4)), int(mg.group(7))
    mp = RE_PROC.search(texte)
    if mp:
        r["proc"], r["phys"] = float(mp.group(1)), float(mp.group(2))
    ml = RE_LUM.search(texte)
    if ml:
        r["lum"], r["lum_omb"] = int(ml.group(1)), int(ml.group(3))
    mb = RE_BBC.search(texte)
    if mb:
        r["bbc"], r["lecteurs"] = float(mb.group(1)), float(mb.group(4))
    mv = RE_VUES.search(texte)
    if mv:
        r["vues"], r["vues_actives"], r["mpx"] = int(mv.group(1)), int(mv.group(2)), float(mv.group(3))
    if rang not in par_rang or essai > par_rang[rang][1]:
        par_rang[rang] = (etiquette, essai, r)

par_etiquette = {}
ordre = []
for rang in sorted(par_rang):
    etiquette, essai, r = par_rang[rang]
    if not r["valide"]:
        print("  rang %d (%s%s) : REFUSÉE — %s" % (rang, etiquette, essai, "; ".join(r["refus"])))
        continue
    if etiquette not in par_etiquette:
        ordre.append(etiquette)
    par_etiquette.setdefault(etiquette, []).append((rang, r))
if ref not in par_etiquette:
    sys.exit("✗ aucune prise valide pour la référence %s" % ref)

t_ref = statistics.mean([r["moyenne_ms"] for _, r in par_etiquette[ref]])
ent = ["Poste retiré (étiquette)", "Prises (rang : moyenne ms)", "Moyenne (ms)", "Δ vs A (ms)", "Δ (%)", "Rapport (cadence)", "appels de dessin", "objets",
       "primitives", "lumières à ombre", "TIME_PROCESS (image entière hors attente, ms)", "BackBufferCopy visibles / image", "lecteurs d'écran visibles / image"]
lignes = []
for e in ordre:
    rs = par_etiquette[e]
    moy = statistics.mean([r["moyenne_ms"] for _, r in rs])
    detail = " / ".join("%d: %.1f" % (rang, r["moyenne_ms"]) for rang, r in rs)
    dc = [r["dc"] for _, r in rs if "dc" in r]
    ob = [r["obj"] for _, r in rs if "obj" in r]
    pr = [r["prim"] for _, r in rs if "prim" in r]
    lo = [r["lum_omb"] for _, r in rs if "lum_omb" in r]
    sp = [r["proc"] + r["phys"] for _, r in rs if "proc" in r]
    bb = [r["bbc"] for _, r in rs if "bbc" in r]
    lc = [r["lecteurs"] for _, r in rs if "lecteurs" in r]
    lignes.append([e, detail, "%.1f" % moy, "%+.1f" % (moy - t_ref), "%+.1f %%" % (100.0 * (moy - t_ref) / t_ref), "%.3f" % (t_ref / moy),
                   "%d" % statistics.median(dc) if dc else "—", "%d" % statistics.median(ob) if ob else "—", "%d" % statistics.median(pr) if pr else "—",
                   "%d" % statistics.median(lo) if lo else "—", "%.1f" % statistics.mean(sp) if sp else "—",
                   "%.2f" % statistics.mean(bb) if bb else "—", "%.2f" % statistics.mean(lc) if lc else "—"])
if md:
    print("| " + " | ".join(ent) + " |")
    print("|" + "|".join(["---"] * len(ent)) + "|")
    for l in lignes:
        print("| " + " | ".join(l) + " |")
else:
    print("Série %s — référence %s : moyenne %.1f ms (%.2f i/s)" % (serie, ref, t_ref, 1000.0 / t_ref))
    for l in lignes:
        print("  %-14s %-44s moy %7s  Δ %8s (%8s)  rapport %s  dc %s obj %s prim %s lum.ombre %s TIME_PROCESS %s BBC %s lecteurs %s" % tuple(l))
