#!/usr/bin/env python3
"""Q15 — fabrique planche.html (autonome, images en chemins relatifs) à partir de images/mesures-*.json.

Aucune dépendance hors de la bibliothèque standard. Lancer depuis n'importe où :
    python3 docs/iso/cloud/zoom/fabrique_planche.py
"""
import glob
import html
import json
import math
import os

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, "../../../.."))
ZOOMS = [1.25, 1.5, 1.75, 2.0]
CARTES = [("map_001_le_cloitre", "Le Cloître"), ("map_003_la_croisee", "La Croisée")]
COULEURS = {1.25: "#5aa9e6", 1.5: "#f2c14e", 1.75: "#e07a5f", 2.0: "#b388eb"}
SIN52 = math.sin(math.radians(52.0))
DECALAGE = 0.15  # part de la hauteur visible dont la caméra avance vers la visée (Q17 = B)


def etiquette(z):
    return "z%03d" % round(z * 100)


def lire_mesures():
    out = {}
    for f in glob.glob(os.path.join(ICI, "images", "mesures-z*.json")):
        if "p-" in os.path.basename(f).split("-")[1] + "-":
            pass
        for m in json.load(open(f)):
            cle = (round(float(m["zoom"]), 2), m["carte"], tuple(m.get("image_px", [1920, 1080])))
            out[cle] = m
    return out


def runs(chaine):
    cases = []
    for bout in chaine.split(";"):
        if not bout:
            continue
        x, y, n = (int(v) for v in bout.split(","))
        cases.append((x, y, n))
    return cases


def plan_svg(carte, mesures):
    """Le plan de la carte vu de dessus, en pixels du monde, avec l'empreinte au sol de l'écran à chaque zoom."""
    data = json.load(open(os.path.join(RACINE, "assets/maps/%s.json" % carte)))
    t = data.get("tile_size", 35)
    gx, gy = data["grid_size"]["x"], data["grid_size"]["y"]
    marge = 60
    w, h = gx * t, gy * t
    p = []
    p.append('<svg viewBox="%d %d %d %d" role="img" aria-label="Plan de %s et ce que montre l\'écran à chaque zoom">'
             % (-marge, -marge, w + 2 * marge, h + 2 * marge, html.escape(carte)))
    p.append('<rect x="0" y="0" width="%d" height="%d" fill="#0b0b0d"/>' % (w, h))
    for x, y, n in runs(data.get("floor", "")):
        p.append('<rect x="%d" y="%d" width="%d" height="%d" fill="#2a2620"/>' % (x * t, y * t, n * t, t))
    for x, y, n in runs(data.get("walls", "")):
        p.append('<rect x="%d" y="%d" width="%d" height="%d" fill="#6b6255"/>' % (x * t, y * t, n * t, t))
    for x, y, n in runs(data.get("low_walls", "")):
        p.append('<rect x="%d" y="%d" width="%d" height="%d" fill="#4a443b"/>' % (x * t, y * t, n * t, t))
    j1 = j2 = None
    for z in ZOOMS:
        m = mesures.get((z, carte, (1920, 1080)))
        if not m:
            continue
        pts = " ".join("%.1f,%.1f" % (a, b) for a, b in m["empreinte"])
        p.append('<polygon points="%s" fill="none" stroke="%s" stroke-width="5" stroke-linejoin="round"/>'
                 % (pts, COULEURS[z]))
        j1, j2 = m["j1"], m["j2"]
        visee, portee, demi = m["visee"], m["torche_monde_px"], math.radians(m["demi_angle_deg"])
    if j1:
        a0 = math.atan2(visee[1], visee[0])
        cone = [(j1[0], j1[1])]
        for k in range(21):
            a = a0 - demi + 2 * demi * k / 20
            cone.append((j1[0] + portee * math.cos(a), j1[1] + portee * math.sin(a)))
        p.append('<polygon points="%s" fill="#f7e3a1" fill-opacity="0.35" stroke="#f7e3a1" stroke-width="2"/>'
                 % " ".join("%.1f,%.1f" % c for c in cone))
        p.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="#f7e3a1" stroke-width="2" '
                 'stroke-dasharray="10 8"/>' % (j1[0], j1[1], portee))
        p.append('<circle cx="%.1f" cy="%.1f" r="16" fill="#5aa9e6" stroke="#fff" stroke-width="3"/>' % tuple(j1))
        p.append('<circle cx="%.1f" cy="%.1f" r="16" fill="#e5484d" stroke="#fff" stroke-width="3"/>' % tuple(j2))
    p.append("</svg>")
    return "\n".join(p)


def portees_ouvertes(z):
    """Jusqu'où l'écran montre le sol depuis le joueur, en pixels du monde, hors des bords de carte (calcul de la
    caméra : horizontale ×zoom/sin 52°, profondeur ×zoom ; regard avancé de 0,15 × 1080/zoom vers la visée)."""
    av = DECALAGE * 1080.0 / z
    cote = 960.0 * SIN52 / z
    prof = 540.0 / z
    return {
        "haut": {"devant": prof + av, "derriere": prof - av, "cote": cote},
        "droite": {"devant": cote + av, "derriere": cote - av, "cote": prof},
    }


def fmt(v, n=0):
    s = ("%." + str(n) + "f") % v
    return s.replace(".", ",")


def main():
    mes = lire_mesures()
    classes = None
    for m in mes.values():
        classes = m["classes"]
        break
    classes = sorted(classes or [], key=lambda c: c["portee"])

    lignes = []
    for z in ZOOMS:
        ms = [mes.get((z, c, (1920, 1080))) for c, _ in CARTES]
        ms = [m for m in ms if m]
        if not ms:
            continue
        corps = [max(m["corps_px"]) for m in ms]
        corps_l = [m["corps_px"][0] for m in ms]
        corps_h = [m["corps_px"][1] for m in ms]
        o = portees_ouvertes(z)
        lignes.append({
            "z": z,
            "corps_l": sum(corps_l) / len(ms), "corps_h": sum(corps_h) / len(ms),
            "touche": ms[0]["touche_px"],
            "torche": ms[0]["torche_ecran_max_px"], "part": ms[0]["torche_part_demi_largeur"],
            "portee": ms[0]["torche_monde_px"],
            "visible": {m["carte"]: m["carte_visible"] for m in ms},
            "visible_scinde": {m["carte"]: m["scinde"]["carte_visible"] for m in ms},
            "corps_scinde": [m["scinde"]["corps_px"] for m in ms],
            "o": o,
        })

    H = []
    H.append("""<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Zoom du duel</title>
<style>
:root{--fond:#111214;--carte:#1b1c1f;--texte:#e8e6e1;--doux:#a19d94;--trait:#2e2f33;--accent:#f2c14e}
@media (prefers-color-scheme: light){:root:not([data-theme="dark"]){--fond:#f6f4ef;--carte:#fff;--texte:#1d1c1a;--doux:#5f5b53;--trait:#dcd8cf;--accent:#9a6a00}}
*{box-sizing:border-box}body{margin:0;background:var(--fond);color:var(--texte);font:16px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif}
main{max-width:1500px;margin:0 auto;padding:24px 16px 64px}
h1{font-size:1.7rem;margin:0 0 4px}h2{margin:40px 0 8px;font-size:1.3rem}h3{margin:24px 0 8px;font-size:1.05rem}
p,li{max-width:80ch}.doux{color:var(--doux)}
.grille{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:12px}
figure{margin:0;background:var(--carte);border:1px solid var(--trait);border-radius:8px;overflow:hidden}
figure img{display:block;width:100%;height:auto}figcaption{padding:6px 10px;font-size:.9rem}
.pastille{display:inline-block;width:.8em;height:.8em;border-radius:50%;margin-right:.4em;vertical-align:-.05em}
.tableau{overflow-x:auto;border:1px solid var(--trait);border-radius:8px;background:var(--carte)}
table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums;font-size:.93rem}
th,td{padding:7px 10px;border-bottom:1px solid var(--trait);text-align:right;white-space:nowrap}
th:first-child,td:first-child{text-align:left}thead th{position:sticky;top:0;background:var(--carte)}
.defaut{outline:2px solid var(--accent);outline-offset:-2px}
.plans{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:12px}
.plans svg{width:100%;height:auto;display:block;background:#050506}
.corps{display:grid;grid-template-columns:repeat(4,1fr);gap:8px}
@media (max-width:700px){.corps{grid-template-columns:repeat(2,1fr)}}
.encadre{background:var(--carte);border:1px solid var(--trait);border-left:4px solid var(--accent);border-radius:8px;padding:12px 16px;margin:16px 0}
a{color:inherit}
</style></head><body><main>
<h1>Le zoom du duel — Q15, sur image</h1>
<p class="doux">Vue isométrique, lacet 45° (J2 à +180°, option B), décalage vers la visée 0,15, torche ×0,75 (pistolet, la classe
de départ). Rendu logiciel du cloud (llvmpipe) : les couleurs et le noir valent, <strong>pas la cadence</strong>. Aucune
ligne du jeu n'a changé : les images viennent du drapeau de débogage <code>--zoom=X</code>. Le défaut actuel, ×1,5, est encadré.</p>
""")
    H.append('<div class="encadre"><strong>Ce qu\'il faut savoir avant de regarder.</strong> Le zoom ne change PAS ce que la '
             'torche éclaire dans le monde : sa portée reste la même (%s px de monde au pistolet). Il change la taille des choses '
             'à l\'écran, et ce que l\'écran montre <em>au-delà</em> de la lumière : là où s\'allume la lumière de l\'adversaire. '
             'En ligne, tout le monde a le même zoom.</div>' % fmt(lignes[0]["portee"] if lignes else 0))

    # Les chiffres.
    H.append("<h2>Les chiffres</h2>")
    H.append('<p class="doux">Pixels d\'écran en 1920×1080 ; sur un écran de 1440 lignes le jeu se rastérise à la fenêtre, '
             'tout est ×4/3. « Corps » : la boîte du corps voxel de J2 projetée par la caméra iso (largeur × hauteur). « Carte '
             'visible » : la part de la surface de la carte que couvre l\'écran dans la scène photographiée.</p>')
    H.append('<div class="tableau"><table><thead><tr><th>Zoom</th><th>Corps 1080</th><th>Corps 1440</th>'
             '<th>Zone de touche (Ø 36 px)</th><th>Torche à l\'écran (au plus long)</th><th>… en part de la demi-largeur</th>'
             '<th>Carte visible — Cloître</th><th>— Croisée</th><th>Écran scindé — Cloître / Croisée</th></tr></thead><tbody>')
    for l in lignes:
        cls = ' class="defaut"' if l["z"] == 1.5 else ""
        H.append("<tr%s><td><span class=\"pastille\" style=\"background:%s\"></span>×%s</td><td>%s × %s</td><td>%s × %s</td>"
                 "<td>%s × %s</td><td>%s px</td><td>%s %%</td><td>%s %%</td><td>%s %%</td><td>%s %% / %s %%</td></tr>" % (
                     cls, COULEURS[l["z"]], fmt(l["z"], 2), fmt(l["corps_l"]), fmt(l["corps_h"]),
                     fmt(l["corps_l"] * 4 / 3), fmt(l["corps_h"] * 4 / 3),
                     fmt(l["touche"][0]), fmt(l["touche"][1]), fmt(l["torche"]), fmt(100 * l["part"]),
                     fmt(100 * l["visible"].get("map_001_le_cloitre", float("nan"))),
                     fmt(100 * l["visible"].get("map_003_la_croisee", float("nan"))),
                     fmt(100 * l["visible_scinde"].get("map_001_le_cloitre", float("nan"))),
                     fmt(100 * l["visible_scinde"].get("map_003_la_croisee", float("nan")))))
    H.append("</tbody></table></div>")

    # Voir avant d'être vu.
    H.append("<h3>Jusqu'où l'écran montre, comparé aux torches</h3>")
    H.append('<p class="doux">Depuis le joueur, en pixels du monde, en terrain ouvert (loin des bords de carte, où la caméra '
             's\'arrête). La caméra avance de 0,15 × la hauteur visible vers la visée : on voit plus loin devant que derrière. '
             'Deux cas, selon que la visée monte vers le haut de l\'écran (le plus serré : l\'image est moins haute que large) '
             'ou part vers la droite. <strong>Devant</strong> : si l\'écran montre plus loin que votre torche, la lumière d\'un '
             'adversaire qui arrive en face apparaît avant qu\'il n\'entre dans votre faisceau. <strong>Derrière</strong> : si une '
             'torche porte plus loin que ce que votre écran montre, son porteur peut vous éclairer — vous voir — depuis hors de '
             'votre écran ; vous voyez la lumière vous toucher, pas d\'où elle vient.</p>')
    H.append('<div class="tableau"><table><thead><tr><th>Zoom</th><th>Visée vers le haut : devant</th><th>derrière</th>'
             '<th>côtés</th><th>Visée vers la droite : devant</th><th>derrière</th><th>côtés</th>'
             '<th>Classes qui éclairent depuis hors écran (dans le dos, visée haute)</th></tr></thead><tbody>')
    for l in lignes:
        o = l["o"]
        dos = o["haut"]["derriere"]
        hors = [c["slug"] for c in classes if c["portee"] > dos]
        cls = ' class="defaut"' if l["z"] == 1.5 else ""
        H.append("<tr%s><td>×%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td>"
                 "<td style=\"text-align:left;white-space:normal\">%d sur %d : %s</td></tr>" % (
                     cls, fmt(l["z"], 2), fmt(o["haut"]["devant"]), fmt(o["haut"]["derriere"]), fmt(o["haut"]["cote"]),
                     fmt(o["droite"]["devant"]), fmt(o["droite"]["derriere"]), fmt(o["droite"]["cote"]),
                     len(hors), len(classes), ", ".join(hors) or "aucune"))
    H.append("</tbody></table></div>")
    H.append('<p class="doux">Portées des torches (px de monde, ×0,75 compris) : %s.</p>'
             % " · ".join("%s %s" % (c["slug"], fmt(c["portee"])) for c in classes))

    # Les images.
    for carte, nom in CARTES:
        H.append("<h2>%s</h2>" % nom)
        H.append('<h3>Vue unique, 1920×1080</h3><p class="doux">J1 (bleu) au centre du bas, torche vers l\'avant ; J2 au bord de '
                 'son faisceau, torche allumée, qui regarde de côté. Même instant, même position, à chaque zoom.</p>')
        H.append('<div class="grille">')
        for z in ZOOMS:
            f = "images/%s-%s-unique.jpg" % (etiquette(z), carte)
            if os.path.exists(os.path.join(ICI, f)):
                H.append('<figure><a href="%s"><img loading="lazy" src="%s" alt="%s, zoom ×%s, vue unique"></a>'
                         '<figcaption><span class="pastille" style="background:%s"></span>×%s%s</figcaption></figure>'
                         % (f, f, nom, fmt(z, 2), COULEURS[z], fmt(z, 2), " — défaut" if z == 1.5 else ""))
        H.append("</div>")
        H.append('<h3>Le corps de J2, recadré 1:1 (320 px de côté)</h3><div class="corps">')
        for z in ZOOMS:
            f = "images/%s-%s-corps.jpg" % (etiquette(z), carte)
            if os.path.exists(os.path.join(ICI, f)):
                H.append('<figure><img loading="lazy" src="%s" alt="Corps de J2 à ×%s"><figcaption>×%s</figcaption></figure>'
                         % (f, fmt(z, 2), fmt(z, 2)))
        H.append("</div>")
        H.append('<h3>Écran scindé, au même instant</h3><p class="doux">À droite, J2 est pris dans le faisceau de J1 : le voile '
                 'blanc est son éblouissement, pas un défaut d\'image.</p><div class="grille">')
        for z in ZOOMS:
            f = "images/%s-%s-scinde.jpg" % (etiquette(z), carte)
            if os.path.exists(os.path.join(ICI, f)):
                H.append('<figure><a href="%s"><img loading="lazy" src="%s" alt="%s, zoom ×%s, écran scindé"></a>'
                         '<figcaption>×%s</figcaption></figure>' % (f, f, nom, fmt(z, 2), fmt(z, 2)))
        H.append("</div>")

    H.append("<h2>Jusqu'où voit un joueur</h2>")
    H.append('<p class="doux">Chaque carte vue de dessus (murs clairs, sol brun). Le contour coloré est ce que l\'écran de J1 '
             'montre au sol, à chaque zoom, dans la scène photographiée (vue unique, lacet 45°, regard avancé, caméra arrêtée '
             'aux bords). Le cône jaune est sa torche, le cercle pointillé sa portée : ils ne changent pas avec le zoom. '
             'Point bleu J1, point rouge J2.</p>')
    H.append('<p>%s</p>' % " ".join('<span class="pastille" style="background:%s"></span>×%s&nbsp;&nbsp;'
                                     % (COULEURS[z], fmt(z, 2)) for z in ZOOMS))
    H.append('<div class="plans">')
    for carte, nom in CARTES:
        H.append("<figure>%s<figcaption>%s</figcaption></figure>" % (plan_svg(carte, mes), nom))
    H.append("</div>")

    v1440 = [m for k, m in mes.items() if k[2] != (1920, 1080)]
    if v1440:
        H.append("<h2>Contrôle en 2560×1440</h2><div class=\"grille\">")
        for m in v1440:
            f = "images/%s-1440p-%s-unique.jpg" % (etiquette(float(m["zoom"])), m["carte"])
            if os.path.exists(os.path.join(ICI, f)):
                H.append('<figure><a href="%s"><img loading="lazy" src="%s" alt="1440 lignes"></a><figcaption>×%s, %s, '
                         '2560×1440</figcaption></figure>' % (f, f, fmt(float(m["zoom"]), 2), m["carte"]))
        H.append("</div>")
    H.append('<p class="doux">Refaire : <code>docs/iso/cloud/zoom/refaire.sh</code> puis '
             '<code>python3 docs/iso/cloud/zoom/fabrique_planche.py</code>. Détails et limites : RAPPORT.md.</p>')
    H.append("</main></body></html>")
    open(os.path.join(ICI, "planche.html"), "w").write("\n".join(H))
    print("planche.html écrite (%d zooms)" % len(lignes))


if __name__ == "__main__":
    main()
