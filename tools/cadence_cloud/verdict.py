#!/usr/bin/env python3
"""Le verdict d'une série (`serie.sh`) : par étiquette, les prises VALIDES — la DERNIÈRE de chaque rang, une prise refusée
étant refaite et jamais comptée (Pièges connus, 2026-09-24) —, leur temps d'image médian et leur 1 % bas, puis le rapport de
chaque étiquette à la référence, EN CADENCE : cadence de l'étiquette / cadence de la référence, soit temps de la référence /
temps de l'étiquette (0,95 : 5 % moins d'images par seconde que la référence). Médiane des médianes par étiquette.

Usage : verdict.py <dossier des prises> <nom de série> [<référence>=A]
"""
import glob
import os
import re
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from analyse import analyser  # noqa: E402

dossier, serie = sys.argv[1], sys.argv[2]
ref = sys.argv[3] if len(sys.argv) > 3 else "A"
par_rang = {}
for f in sorted(glob.glob(os.path.join(dossier, "%s_*.log" % serie))):
    m = re.match(r"%s_(\d+)_(.+?)(_r\d+)?\.log$" % re.escape(serie), os.path.basename(f))
    if not m:
        continue
    rang, etiquette, essai = int(m.group(1)), m.group(2), m.group(3) or ""
    r = analyser(f)
    # La DERNIÈRE prise de chaque rang compte (une prise refusée est refaite, jamais comptée) — piège du 2026-09-24.
    if rang not in par_rang or essai > par_rang[rang][1]:
        par_rang[rang] = (etiquette, essai, r)
par_etiquette = {}
for rang in sorted(par_rang):
    etiquette, essai, r = par_rang[rang]
    if not r["valide"]:
        print("  rang %d (%s%s) : REFUSÉE — %s" % (rang, etiquette, essai, "; ".join(r["refus"])))
        continue
    par_etiquette.setdefault(etiquette, []).append(r)
if ref not in par_etiquette:
    sys.exit("✗ aucune prise valide pour la référence %s" % ref)
# LA MOYENNE fait foi, pas la médiane : sous llvmpipe, `physics_jitter_fix` recale le temps d'image rapporté sur des multiples
# du pas de physique (500 ms = 4 × 125 ms revient une image sur cinq), ce qui tire la médiane vers ces valeurs ; la somme des
# temps, elle, reste celle du temps réel (le déficit est reporté d'une image à l'autre).
t_ref = statistics.mean([r["moyenne_ms"] for r in par_etiquette[ref]])
b_ref = statistics.median([r["un_pc_bas_ms"] for r in par_etiquette[ref]])
print("Série %s — référence %s : moyenne %.1f ms (%.2f i/s), 1 %% bas %.1f ms" % (serie, ref, t_ref, 1000 / t_ref, b_ref))
print("%-14s %-26s %-26s %-9s %-8s %-9s %s" % ("étiquette", "moyennes (ms)", "médianes (ms)", "moyenne", "rapport", "Δ ms",
                                              "1 % bas (ms)"))
for etiquette, rs in par_etiquette.items():
    moy = [r["moyenne_ms"] for r in rs]
    meds = [r["mediane_ms"] for r in rs]
    bas = [r["un_pc_bas_ms"] for r in rs]
    t = statistics.mean(moy)
    print("%-14s %-26s %-26s %-9s %-8s %-9s %s" % (etiquette, " / ".join("%.1f" % x for x in moy),
          " / ".join("%.1f" % x for x in meds), "%.1f" % t, "%.3f" % (t_ref / t), "%+.1f" % (t - t_ref),
          " / ".join("%.0f" % x for x in bas)))
