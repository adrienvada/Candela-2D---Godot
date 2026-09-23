"""Le bord du cône : pour chaque décalage de J2 vers le bord du faisceau, l'écart de couleur corps/sol (ΔE76) et le nombre
de pixels où le corps se voit, en gris et dans chaque tenue, par classe. Imprime la médiane des dix classes et, par tenue,
le dernier décalage où chaque classe se distingue encore (ΔE ≥ SEUIL et pixels visibles ≥ PIX)."""
import glob, json, re, statistics, sys
D = sys.argv[1]
SEUIL, PIX = 2.3, 40
R = re.compile(r"BANC_ISO_CONTRASTE_CLASSE (\S+) tenue=(\S+) distance=(\d+) décalage=(-?\d+) \| ΔE76 peint ([\d.]+) gris ([\d.]+) \| "
               r"clarté corps/sol peint ([\d.]+) gris ([\d.]+) \| corps (\d+)/(\d+) px \| lum corps peint ([\d.]+) gris ([\d.]+)")
m = {}
for f in glob.glob(D + "/cone_*.log"):
    for l in open(f, encoding="utf-8", errors="replace"):
        g = R.search(l)
        if g:
            s, t, dec = g.group(1), g.group(2), int(g.group(4))
            m.setdefault(dec, {}).setdefault(s, {})[t] = dict(de=float(g.group(5)), px=int(g.group(9)), lum=float(g.group(11)),
                                                              rap=float(g.group(7)))
            m[dec][s]["gris"] = dict(de=float(g.group(6)), px=int(g.group(10)), lum=float(g.group(12)), rap=float(g.group(8)))
decs = sorted(m)
tenues = ["gris", "sombre1", "sombre2", "sombre3"]
print("décalage | médiane ΔE76 (pixels visibles) : " + "  ".join(tenues))
for dec in decs:
    cells = []
    for t in tenues:
        des = [m[dec][s][t]["de"] for s in m[dec] if t in m[dec][s]]
        pxs = [m[dec][s][t]["px"] for s in m[dec] if t in m[dec][s]]
        cells.append("%5.1f (%4d)" % (statistics.median(des), statistics.median(pxs)))
    print("%4d px  | %s" % (dec, "  ".join(cells)))
limite = {}
for t in tenues:
    for s in sorted({s for dec in decs for s in m[dec]}):
        der = None
        for dec in decs:
            e = m[dec].get(s, {}).get(t)
            if e and e["de"] >= SEUIL and e["px"] >= PIX:
                der = dec
        limite.setdefault(t, {})[s] = der
print("dernier décalage où le corps se distingue (ΔE ≥ %.1f et ≥ %d px) :" % (SEUIL, PIX))
for s in limite["gris"]:
    print("  %-12s %s" % (s, "  ".join("%s %s" % (t, limite[t][s]) for t in tenues)))
json.dump({"mesures": {str(k): v for k, v in m.items()}, "limite": limite}, open(D + "/cone.json", "w"), indent=1)
