"""Teinte froide contre olive : (1) le rapport de clarté au gris de chaque tenue, froide contre olive, par classe et par lumière
(deux parties du banc des corps, chacune rapportée à son propre gris) ; (2) le ΔE76 au sol ocre, gris / olive / froide, au
centre du cône et à 90 px (même partie)."""
import json, re, sys
o = json.load(open(sys.argv[1] + "/analyse.json")); f = json.load(open(sys.argv[2] + "/analyse.json"))
SL = ["pistolet", "fusil", "pompe", "arbalete", "fumiste", "incendiaire", "sentinelle", "occulteur", "allumeur", "spectre"]
pire = {}
for t in ["sombre1", "sombre2", "sombre3"]:
    for L in ["0.8", "0.2", "0.15", "0.1"]:
        for s in SL:
            a, b = o[s][L][t], f[s][L][t]
            if a and b:
                e = b / a - 1
                if abs(e) > abs(pire.get((t, L), (0, ""))[0]):
                    pire[(t, L)] = (e, s)
print("(1) écart de clarté froide / olive, le pire par tenue et lumière :")
for k, v in sorted(pire.items()):
    print("  %s %s : %+.1f %% (%s)" % (k[0], k[1], 100 * v[0], v[1]))
R = re.compile(r"BANC_ISO_CONTRASTE_CLASSE (\S+) tenue=(\S+)/(\S+) distance=\d+ décalage=(-?\d+) \| ΔE76 peint ([\d.]+) gris ([\d.]+)")
de = {}
import glob
for fl in glob.glob(sys.argv[3] + "/cone_*.log"):
    for l in open(fl, encoding="utf-8", errors="replace"):
        g = R.search(l)
        if g:
            s, t, te, dec = g.group(1), g.group(2), g.group(3), g.group(4)
            de.setdefault(dec, {}).setdefault(s, {})[t + "/" + te] = float(g.group(5))
            de[dec][s]["gris"] = float(g.group(6))
print("(2) ΔE76 au sol ocre : gris | V1 olive froide | V2 olive froide | V3 olive froide")
for dec in sorted(de, key=int):
    print(" décalage", dec)
    for s in SL:
        e = de[dec][s]
        v1f = e["sombre1/froide"]
        mark = "" if v1f >= e["gris"] else "  ← V1 froide sous le gris"
        print("  %-12s %5.1f | %5.1f %5.1f | %5.1f %5.1f | %5.1f %5.1f%s" % (s, e["gris"], e["sombre1/olive"], v1f, e["sombre2/olive"],
              e["sombre2/froide"], e["sombre3/olive"], e["sombre3/froide"], mark))
json.dump({"pire": {"%s %s" % k: v for k, v in pire.items()}, "de": de}, open(sys.argv[3] + "/teintes.json", "w"), indent=1)
