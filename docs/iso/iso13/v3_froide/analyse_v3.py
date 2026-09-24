"""V3 froide par défaut : après analyse_seuil.py (seuil.json), les pixels visibles à 0,15 par classe, gris contre V3 froide,
face à la garde de 5 % du lot B ; les seuils d'apparition comparés ; le noir absolu à lumière 0 (pixel maximal)."""
import json, sys
from PIL import Image
D = sys.argv[1]
j = json.load(open(D + "/seuil.json"))
vis, seuils = j["visibles"], j["seuils"]
print("à 0,15 — pixels visibles, gris → V3 froide (écart ; garde 5 %) :")
for s in vis["gris"]:
    g, v = vis["gris"][s]["0.15"], vis["sombre3"][s]["0.15"]
    e = (v - g) / g * 100.0 if g else 0.0
    print("  %-12s %5d → %5d  (%+.1f %%)%s" % (s, g, v, e, "" if abs(e) <= 5 else "  HORS GARDE"))
plus_tot = [s for s in seuils["gris"] if seuils["sombre3"][s] is not None and seuils["gris"][s] is not None and seuils["sombre3"][s] < seuils["gris"][s]]
plus_tard = [s for s in seuils["gris"] if (seuils["sombre3"][s] or 9) > (seuils["gris"][s] or 9)]
trop_tard = [s for s in seuils["gris"] if seuils["gris"][s] and (seuils["sombre3"][s] is None or seuils["sombre3"][s] > seuils["gris"][s] * 1.10 + 1e-9)]
print("apparition : V3 plus tard de plus de 10 %% de lumière pour %s" % (trop_tard or "aucune classe"))
for s in seuils["gris"]:
    print("  %-12s gris %s  V3 %s" % (s, seuils["gris"][s], seuils["sombre3"][s]))
print("apparition (≥ 30 px) : V3 plus TÔT que le gris pour %s ; plus tard pour %s" % (plus_tot or "aucune classe", plus_tard or "aucune classe"))
for t in ["gris", "sombre3"]:
    im = Image.open("%s/corps_0_%s.png" % (D, t)).convert("RGB")
    print("noir absolu, lumière 0, %s : pixel maximal %d/255" % (t, max(max(p) for p in im.getdata())))
