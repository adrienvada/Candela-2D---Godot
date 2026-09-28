#!/usr/bin/env python3
"""Q40, la lampe claire : les images de la planche (JPEG ~85) et `planche.html`.

    python3 docs/iso/cloud/lampe-claire/planche.py <dossier des prises> <mesures.json>

Pour chaque carte : le duel, aujourd'hui / l'essai, recadré à 1:1 autour du cône (640×360) et en loupe ×3 sur son cœur ;
l'écran scindé du Cloître en entier ; torches éteintes (le noir). À côté : les illustrations qui montrent une lampe, avec la
couleur de leur 1 % le plus clair.
"""
import sys, os, json, colorsys, html
import numpy as np
from PIL import Image

src, mesures = sys.argv[1], json.load(open(sys.argv[2]))
ici = os.path.dirname(os.path.abspath(__file__))
img = os.path.join(ici, "img")
os.makedirs(img, exist_ok=True)
racine = os.path.abspath(os.path.join(ici, "..", "..", "..", ".."))
L = lambda x: 0.2126 * x[..., 0] + 0.7152 * x[..., 1] + 0.0722 * x[..., 2]

CARTES = [("map_001_le_cloitre", "Le Cloître"), ("map_002_l_usine", "L'Usine"), ("map_003_la_croisee", "La Croisée"),
          ("map_004_le_bunker", "Le Bunker"), ("arene_circulaire", "L'Arène circulaire"), ("default", "La carte d'essai")]
ILLUS = ["accueil", "amical", "ecran_scinde", "entrainement", "intro_allumage", "intro_prix", "intro_seuil", "quitter",
         "creer_local", "intro_descente"]


def ouvrir(nom, etat):
    f = f"{src}/{nom}__{etat}.png"
    return Image.open(f).convert("RGB") if os.path.exists(f) else None


def jpeg(im, nom):
    im.save(os.path.join(img, nom), quality=85)
    return f"img/{nom}"


def centre_du_cone(a, b):
    """Le barycentre des pixels que l'essai éclaircit le plus (le cœur du cône)."""
    la, lb = L(np.asarray(a).astype(float)), L(np.asarray(b).astype(float))
    gain = lb - la
    if gain.max() <= 0:
        return a.size[0] // 2, a.size[1] // 2
    m = gain >= np.percentile(gain[gain > 0], 75)
    ys, xs = np.nonzero(m)
    return int(np.median(xs)), int(np.median(ys))


def recadrer(im, cx, cy, w, h):
    x0 = min(max(cx - w // 2, 0), im.size[0] - w)
    y0 = min(max(cy - h // 2, 0), im.size[1] - h)
    return im.crop((x0, y0, x0 + w, y0 + h))


def fmt(s):
    if not s or not s.get("n"):
        return "—"
    c = s["couleur"]
    return f"méd <b>{s['mediane']:.0f}</b> · p99 {s['p99']:.0f} · {c['teinte_deg']:.0f}° · sat. {c['saturation']:.2f}"


def pastille(rgb):
    return f'<span class="pastille" style="background:rgb({rgb[0]},{rgb[1]},{rgb[2]})"></span>'


lignes = []
for slug, titre in CARTES:
    a, b = ouvrir(f"{slug}_duel", "defaut"), ouvrir(f"{slug}_duel", "essai")
    if a is None:
        continue
    cx, cy = centre_du_cone(a, b)
    m = mesures.get(f"{slug}_duel") or {}
    cellules = []
    for etat, im in (("defaut", a), ("essai", b)):
        un = jpeg(recadrer(im, cx, cy, 640, 360), f"{slug}_duel_{etat}_1x1.jpg")
        loupe = recadrer(im, cx, cy, 214, 120).resize((642, 360), Image.NEAREST)
        trois = jpeg(loupe, f"{slug}_duel_{etat}_loupe3.jpg")
        cellules.append((un, trois))
    t = m.get("coeur_tout", {})
    tt = m.get("torche_tout", {})
    lignes.append(f"""
<section><h3>{html.escape(titre)} — duel, 45° B</h3>
<div class="paire"><figure><img src="{cellules[0][0]}"><figcaption>aujourd'hui, 1:1</figcaption></figure>
<figure><img src="{cellules[1][0]}"><figcaption>l'essai <code>--lampe-claire</code>, 1:1</figcaption></figure></div>
<div class="paire"><figure><img src="{cellules[0][1]}"><figcaption>aujourd'hui, loupe ×3</figcaption></figure>
<figure><img src="{cellules[1][1]}"><figcaption>l'essai, loupe ×3</figcaption></figure></div>
<table><tr><th></th><th>aujourd'hui</th><th>l'essai</th></tr>
<tr><td>cœur du cône (≥ 60 aujourd'hui)</td><td>{pastille(t.get('defaut',{}).get('couleur',{}).get('rgb',[0,0,0]))} {fmt(t.get('defaut'))}</td>
<td>{pastille(t.get('essai',{}).get('couleur',{}).get('rgb',[0,0,0]))} {fmt(t.get('essai'))}</td></tr>
<tr><td>tout ce que la torche éclaire</td><td>{fmt(tt.get('defaut'))}</td><td>{fmt(tt.get('essai'))}</td></tr>
<tr><td>pixels changés · noirs allumés · plus sombres · bruit</td><td colspan="2">{m.get('changes_px','?')} · <b>{m.get('noir_allume_px','?')}</b> · {m.get('plus_sombre_px','?')} · {m.get('bruit_px','?')}</td></tr>
</table></section>""")

# L'écran scindé du Cloître, en entier, et le noir.
scinde = []
for nom, legende in (("map_001_le_cloitre_scinde", "écran scindé, J1 à gauche, J2 à droite (vu du côté opposé, lacet B)"),
                     ("map_001_le_cloitre_noir", "torches éteintes (vue unique)")):
    a, b = ouvrir(nom, "defaut"), ouvrir(nom, "essai")
    if a is None:
        continue
    fa = jpeg(a, f"{nom}_defaut.jpg")
    fb = jpeg(b, f"{nom}_essai.jpg")
    m = mesures.get(nom) or {}
    detail = ""
    for k, nom_vue in (("coeur_vue_j1", "cœur du cône, vue de J1"), ("coeur_vue_j2", "cœur du cône, vue de J2")):
        if k in m:
            detail += f"<tr><td>{nom_vue}</td><td>{fmt(m[k]['defaut'])}</td><td>{fmt(m[k]['essai'])}</td></tr>"
    scinde.append(f"""
<section><h3>{html.escape(legende)}</h3>
<figure class="plein"><img src="{fa}"><figcaption>aujourd'hui</figcaption></figure>
<figure class="plein"><img src="{fb}"><figcaption>l'essai</figcaption></figure>
<table><tr><th></th><th>aujourd'hui</th><th>l'essai</th></tr>{detail}
<tr><td>pixels changés · noirs allumés · plus sombres · bruit</td><td colspan="2">{m.get('changes_px','?')} · <b>{m.get('noir_allume_px','?')}</b> · {m.get('plus_sombre_px','?')} · {m.get('bruit_px','?')}</td></tr></table>
</section>""")

illus = []
for nom in ILLUS:
    f = os.path.join(racine, "assets", "ui", f"ill_{nom}.png")
    if not os.path.exists(f):
        continue
    im = Image.open(f).convert("RGB")
    a = np.asarray(im).astype(float)
    la = L(a)
    t = np.percentile(la, 99)
    c = a[la >= t].mean(0)
    h, s, v = colorsys.rgb_to_hsv(*(c / 255))
    petit = im.copy()
    petit.thumbnail((512, 320))
    chemin = jpeg(petit, f"ill_{nom}.jpg")
    illus.append(f"""<figure class="ill"><img src="{chemin}"><figcaption>{nom} — 1 % le plus clair : {pastille([int(x) for x in c])}
{t:.0f}, {h*360:.0f}° · sat. {s:.2f}</figcaption></figure>""")

page = f"""<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lampe claire (Q40)</title>
<style>
:root {{ --fond:#111; --texte:#ddd; --trait:#333; }}
body {{ background:var(--fond); color:var(--texte); font:15px/1.45 system-ui, sans-serif; margin:0 auto; max-width:1340px; padding:16px; }}
h1,h2,h3 {{ font-weight:600; }} code {{ color:#f5d9a8; }}
.paire {{ display:flex; gap:8px; flex-wrap:wrap; }} .paire figure {{ flex:1 1 320px; margin:0; }}
figure img {{ width:100%; height:auto; display:block; image-rendering:pixelated; border:1px solid var(--trait); }}
figure.plein {{ margin:6px 0; }} figcaption {{ font-size:13px; color:#aaa; margin:2px 0 8px; }}
.ills {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(240px,1fr)); gap:8px; }} .ill {{ margin:0; }}
table {{ border-collapse:collapse; margin:6px 0 18px; font-size:13px; width:100%; }}
td,th {{ border:1px solid var(--trait); padding:3px 6px; text-align:left; vertical-align:top; }}
.pastille {{ display:inline-block; width:14px; height:14px; border:1px solid #555; vertical-align:middle; }}
section {{ border-top:1px solid var(--trait); padding-top:6px; }}
</style></head><body>
<h1>La lampe plus claire et plus pâle — Q40, l'essai <code>--lampe-claire</code></h1>
<p>Même instant, jeu en pause : la seule différence entre « aujourd'hui » et « l'essai » est la courbe à la sortie du sol
et des murs. Rien d'autre du jeu ne change : ni la lumière, ni sa portée, ni ce que le jeu en lit. Images du cloud
(rendu logiciel) : elles valent pour les couleurs et les comptes de pixels, pas pour la cadence. Détail et preuves :
<a href="RAPPORT.md">RAPPORT.md</a>.</p>
<h2>Les illustrations qui montrent une lampe</h2>
<div class="ills">{''.join(illus)}</div>
<h2>Les six cartes</h2>
{''.join(lignes)}
<h2>Écran scindé et noir</h2>
{''.join(scinde)}
</body></html>
"""
open(os.path.join(ici, "planche.html"), "w", encoding="utf-8").write(page)
print("planche.html :", len(lignes), "cartes,", len(scinde), "vues entières,", len(illus), "illustrations")
