"""ISO12 v27 — la planche de la recette du relief : bandes à 1:1 et ×4, et le tableau complet, cadrage par cadrage.

Usage : python3 planche_v27.py DOSSIER_ANALYSE DOSSIER_DE_SORTIE [CADENCE_TXT] [DOSSIER_PHOTOGRAPHE…]

- `DOSSIER_ANALYSE` : la sortie d'`analyse_v27.py` (`v27.json` et `loupes/`).
- Pour chaque cadrage et chaque ancre, UNE BANDE : référence 2D | 3D sans ombres | 3D avec ombres (| sabotage), côte à côte,
  sans aucun redimensionnement pour la bande 1:1, au plus proche voisin pour la bande ×4. Juger « pixel par pixel » veut
  dire comparer le MÊME pixel des trois rendus, donc les poser l'un contre l'autre plutôt que dans trois fichiers.
- Le tableau (a)/(b)/rouge/blancs de chaque prise et de chaque zone, en texte ET en HTML — et les deux contrôles du seuil au
  point noir : « moins » (visible en 2D, noir en 3D ; sous ombres, c'est la PREUVE INVERSE, cible < 1 %) et « plus » (noir en
  2D, lumineux en 3D, cible < 0,01 %).
- `CADENCE_TXT` : les six relevés, recopiés tels quels.
- `DOSSIER_PHOTOGRAPHE…` : les séances `loupe-corps` du photographe (3D éteinte, sans ombres, avec ombres).
"""
import html
import json
import os
import sys

from PIL import Image

analyse, sortie = sys.argv[1], sys.argv[2]
cadence = open(sys.argv[3], encoding="utf-8").read() if len(sys.argv) > 3 and os.path.isfile(sys.argv[3]) else ""
photos = sys.argv[4:]
os.makedirs(os.path.join(sortie, "bandes"), exist_ok=True)
donnees = json.load(open(os.path.join(analyse, "v27.json"), encoding="utf-8"))
loupes = os.path.join(analyse, "loupes")
ORDRE = ["reference2d", "neutre", "sans_ombres", "ombres", "sabotage"]
TITRES = {"reference2d": "2D (référence)", "neutre": "3D, R = 1 forcé", "sans_ombres": "3D sans ombres",
          "ombres": "3D avec ombres", "sabotage": "SABOTAGE (bride coupée)"}


def bande(cadrage, ancre, x4):
    suffixe = "_x4" if x4 else ""
    tuiles = []
    for v in ORDRE:
        f = os.path.join(loupes, "%s__%s__%s%s.png" % (cadrage, v, ancre, suffixe))
        if os.path.isfile(f):
            tuiles.append(Image.open(f).convert("RGB"))
    if not tuiles:
        return None
    w, h = tuiles[0].size
    b = Image.new("RGB", (w * len(tuiles) + 6 * (len(tuiles) - 1), h), (60, 60, 60))
    for k, t in enumerate(tuiles):
        b.paste(t, (k * (w + 6), 0))
    nom = "%s__%s%s.png" % (cadrage, ancre, suffixe)
    b.save(os.path.join(sortie, "bandes", nom), optimize=True)
    return "bandes/" + nom


def fmt(x, n=3):
    return "—" if x is None else ("%." + str(n) + "f") % x


def verdict_a(a):
    return a is not None and 0.85 <= a <= 1.15


def cellules_seuil(p):
    """« moins » et « plus », avec leur verdict ; vides pour une analyse d'avant le seuil."""
    if "moins_part" not in p:
        return "<td></td><td></td>"
    km = "ok" if p["moins_part"] < 1.0 else "ko"
    kp = "ok" if p["plus_part"] < 0.01 else "ko"
    return "<td class='%s'>%.2f %% <small>(%d px)</small></td><td class='%s'>%.4f %% <small>(%d px)</small></td>" \
        % (km, p["moins_part"], p["moins_px"], kp, p["plus_part"], p["plus_px"])


lignes_txt = []
sections = []
for cadrage in sorted(donnees):
    d = donnees[cadrage]
    ancres = set()
    for p in d["prises"].values():
        ancres.update(p.get("zones", {}).keys())
    rangs = []
    for v in ("sans_ombres", "ombres", "sabotage"):
        p = d["prises"].get(v)
        if p is None:
            continue
        ok = verdict_a(p["a"])
        lignes_txt.append("%-44s %-12s image (a) %s %s · (b) %.2f %% · rouge %d · blancs %d (2D %d) · moins %s %% · plus %s %%"
                          % (cadrage, v, fmt(p["a"]), "OK" if ok else "HORS", p["b_part"], p["rouge"], p["blancs"],
                             d["blancs_2d"], fmt(p.get("moins_part"), 2), fmt(p.get("plus_part"), 4)))
        rangs.append("<tr class='%s'><th>%s — image</th><td>%s</td><td>%.2f %% <small>(%d px)</small></td><td>%d</td><td>%d <small>(2D %d)</small></td>%s</tr>"
                     % ("ok" if ok and p["b_part"] < 1.0 else "ko", TITRES[v], fmt(p["a"]), p["b_part"], p["b_population"],
                        p["rouge"], p["blancs"], d["blancs_2d"], cellules_seuil(p)))
        for nom_a in sorted(p.get("zones", {})):
            z = p["zones"][nom_a]
            okz = z["a"] is None or verdict_a(z["a"])
            lignes_txt.append("%-44s %-12s   %-12s (a) %s · (b) %.2f %% · rouge %d · moins %s px · plus %s px"
                              % ("", "", nom_a, fmt(z["a"]), z["b_part"], z["rouge"], z.get("moins_px", "—"),
                                 z.get("plus_px", "—")))
            rangs.append("<tr class='%s zone'><th>&nbsp;&nbsp;%s</th><td>%s</td><td>%.2f %% <small>(%d px)</small></td><td>%d</td><td></td><td>%s px</td><td>%s px</td></tr>"
                         % ("ok" if okz and z["b_part"] < 1.0 else "ko", html.escape(nom_a), fmt(z["a"]), z["b_part"],
                            z["b_population"], z["rouge"], z.get("moins_px", "—"), z.get("plus_px", "—")))
        for nom_f, t in p.get("fusee", {}).items():
            lignes_txt.append("%-44s %-12s   %-12s teinte/saturation 3D %s · 2D %s" % ("", "", nom_f, t["3d"], t["2d"]))
    if "ombres_plus_claires_px" in d:
        lignes_txt.append("%-44s OMBRES : %d px plus clairs avec ombres, %d plus sombres"
                          % (cadrage, d["ombres_plus_claires_px"], d["ombres_plus_sombres_px"]))
    images = []
    for a in sorted(ancres):
        for x4 in (True, False):
            chemin = bande(cadrage, a, x4)
            if chemin:
                images.append("<figure><img src='%s' loading='lazy'><figcaption>%s — %s</figcaption></figure>"
                              % (chemin, html.escape(a), "×4, plus proche voisin" if x4 else "1:1"))
    ombres = ""
    if "ombres_plus_claires_px" in d:
        ombres = "<p class='ombres'>Ombres : <b>%d</b> px plus CLAIRS avec ombres que sans (il en faut zéro), %d plus sombres.</p>" \
                 % (d["ombres_plus_claires_px"], d["ombres_plus_sombres_px"])
    sections.append("<section><h2>%s</h2><p class='meta'>%s · 2D : %d px blancs</p><div class='tablewrap'><table><tr><th></th><th>(a) 3D/2D</th><th>(b) &lt; 1 %%</th><th>rouge</th><th>blancs</th><th>moins &lt; 1 %%<br><small>visible 2D, noir 3D</small></th><th>plus &lt; 0,01 %%<br><small>noir 2D, lumineux 3D</small></th></tr>%s</table></div>%s<div class='bandes'>%s</div></section>"
                    % (html.escape(cadrage), "écran scindé" if d["scinde"] else "vue unique", d["blancs_2d"],
                       "".join(rangs), ombres, "".join(images)))

photo_html = []
for dossier in photos:
    if not os.path.isdir(dossier):
        continue
    etiquette = os.path.basename(dossier.rstrip("/"))
    for f in sorted(os.listdir(dossier)):
        if f.endswith(".png") and "loupe-corps" in f:
            cible = "photographe_%s_%s" % (etiquette, f)
            Image.open(os.path.join(dossier, f)).save(os.path.join(sortie, cible), optimize=True)
            photo_html.append("<figure><img src='%s' loading='lazy'><figcaption>%s — %s</figcaption></figure>"
                              % (cible, html.escape(etiquette), html.escape(f)))

open(os.path.join(sortie, "tableau_v27.txt"), "w", encoding="utf-8").write("\n".join(lignes_txt) + "\n")
page = """<title>Planche v27 ISO12</title>
<style>
:root{--fond:#f6f5f2;--encre:#1d1d1b;--doux:#6b6a66;--ok:#1f7a45;--ko:#b3261e;--ligne:#d9d6cf;--carte:#fff}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--fond:#161615;--encre:#ecebe7;--doux:#a19f99;--ok:#6fcf97;--ko:#ff8a80;--ligne:#34332f;--carte:#1f1f1d}}
:root[data-theme="dark"]{--fond:#161615;--encre:#ecebe7;--doux:#a19f99;--ok:#6fcf97;--ko:#ff8a80;--ligne:#34332f;--carte:#1f1f1d}
body{background:var(--fond);color:var(--encre);font:14px/1.45 -apple-system,system-ui,sans-serif;padding-inline:16px;padding-block:24px;margin:0 auto;max-width:1400px}
h1{font-size:22px;margin:0 0 4px}h2{font-size:17px;margin:28px 0 6px;font-family:ui-monospace,monospace}
.meta,small{color:var(--doux)}table{border-collapse:collapse;margin:8px 0;font-variant-numeric:tabular-nums}
.tablewrap{overflow-x:auto}td,th{border-bottom:1px solid var(--ligne);padding:3px 10px;text-align:left}
tr.ok td:nth-child(2){color:var(--ok)}tr.ko td:nth-child(2),tr.ko td:nth-child(3){color:var(--ko);font-weight:600}
tr.zone th{font-weight:400;color:var(--doux)}
td.ok{color:var(--ok)}td.ko{color:var(--ko);font-weight:600}
.bandes{display:flex;flex-direction:column;gap:14px}figure{margin:0;overflow-x:auto}
figure img{display:block;max-width:none;image-rendering:pixelated}figcaption{color:var(--doux);font-size:12px;margin-top:3px}
pre{background:var(--carte);border:1px solid var(--ligne);padding:10px;overflow-x:auto;font-size:12px}
.ombres{font-weight:500}
</style>
<h1>Planche v27 — le relief normalisé</h1>
<p class='meta'>Chaque bande pose côte à côte, dans l'ordre : 2D de référence · 3D à R = 1 forcé · 3D sans ombres · 3D avec ombres · (sabotage). Les bandes ×4 sont au plus proche voisin ; les bandes 1:1 ne sont pas redimensionnées (défiler horizontalement). (a) = rapport des luminances brutes 3D/2D sur les pixels visibles en 2D, cible 1,0 ± 0,15 ; (b) = part des pixels à L2D &lt; 0,15 où la 3D dépasse 0,25 (même échelle), cible &lt; 1 %%.</p>
%s
%s
%s
""" % (("<h2>Cadence indicative</h2><pre>%s</pre>" % html.escape(cadence)) if cadence else "",
       "".join(sections),
       ("<h2>L'adversaire au photographe — loupe-corps, torche de J2 éteinte</h2><div class='bandes'>%s</div>" % "".join(photo_html)) if photo_html else "")
open(os.path.join(sortie, "index.html"), "w", encoding="utf-8").write(page)
print("planche :", os.path.join(sortie, "index.html"))
print("tableau :", os.path.join(sortie, "tableau_v27.txt"))
