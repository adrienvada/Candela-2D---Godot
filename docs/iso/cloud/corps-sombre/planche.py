#!/usr/bin/env python3
"""Q39 — monte `planche.html` depuis `mesures.json` et `img/` (écrits par `mesurer.py`), plus les illustrations qui
montrent des personnages sombres (`assets/ui/ill_*.png`, réduites en JPEG dans `img/`).

    python3 planche.py
"""
import json
import os

from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, "..", "..", "..", ".."))
ILLUSTRATIONS = [
    ("accueil", "L'accueil : deux silhouettes sombres dans l'arène, le liseré du côté de la lampe."),
    ("ecran_scinde", "L'écran scindé : chaque joueur sombre, cerné de la couleur de sa lampe."),
    ("entrainement", "L'entraînement : le personnage de dos, sombre, découpé par la lumière du plafond."),
    ("amical", "Le mode amical : deux silhouettes en tenue noire autour du pilier."),
    ("intro_prix", "Le prix : le corps noir, le liseré seul dit où il est."),
]
CLASSES = [("pistolet", "Le Parasite (pistolet)"), ("pompe", "Le Terrassier (pompe)"), ("fumiste", "Le Fumiste"),
           ("spectre", "Le Spectre")]
SCENES = [
    ("noir", "Dans le noir", "torches éteintes ; le sol ne doit sa clarté qu'aux bandeaux LED des murs"),
    ("vide", "Au bord de sa lumière", "sa torche vers le sud, dans le vide : son corps à la naissance du cône"),
    ("torche", "Sa pleine lumière", "sa torche vers le mur haut, à 1,5 case : la rétrodiffusion"),
    ("lisiere", "Au bord du cône adverse", "sa torche éteinte, J2 le braque de biais"),
    ("adverse", "Dans la torche adverse", "sa torche éteinte, J2 le braque droit (J1 ébloui : le voile laiteux)"),
    ("fusee", "Sous une fusée", "sa torche éteinte, sa fusée lancée 1,5 s plus tôt"),
]


def illustrations():
    out = []
    for nom, legende in ILLUSTRATIONS:
        src = os.path.join(RACINE, "assets", "ui", "ill_%s.png" % nom)
        dst = os.path.join(ICI, "img", "ill_%s.jpg" % nom)
        if not os.path.exists(src):
            continue
        if not os.path.exists(dst):
            im = Image.open(src).convert("RGB")
            if im.width > 1024:
                im = im.resize((1024, im.height * 1024 // im.width), Image.LANCZOS)
            im.save(dst, quality=85)
        out.append((nom, legende))
    return out


def chiffres(m):
    if not m:
        return "—"
    return ("corps %.0f (liseré p90 %.0f) · derrière %.0f · sol autour %.0f · <b>%d %%</b> du corps lisible" %
            (m["corps_moyenne"], m["corps_p90"], m["derriere_moyenne"], m["sol_autour"], round(100 * m["part_lisible"])))


def main():
    with open(os.path.join(ICI, "mesures.json")) as f:
        mesures = json.load(f)
    ills = illustrations()
    h = []
    h.append("""<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Q39 — le corps de soi</title>
<style>
:root{--fond:#111;--texte:#ddd;--pale:#999;--cadre:#333;--accent:#8fc4e8}
body{background:var(--fond);color:var(--texte);font:15px/1.5 system-ui,sans-serif;margin:0 auto;max-width:1560px;padding:16px}
h1{font-size:24px}h2{margin-top:40px;border-bottom:1px solid var(--cadre)}h3{margin:24px 0 6px}
.rang{display:flex;flex-wrap:wrap;gap:10px;align-items:flex-start}
figure{margin:0}figcaption{color:var(--pale);font-size:13px;max-width:480px}
img{max-width:100%;height:auto;image-rendering:pixelated;border:1px solid var(--cadre)}
.ill img{image-rendering:auto;max-width:500px}
table{border-collapse:collapse;font-size:13px}td,th{border:1px solid var(--cadre);padding:3px 8px;text-align:right}
th{text-align:left}.ok{color:#7c7}.ko{color:#e77}.note{color:var(--pale)}
</style></head><body>""")
    h.append("<h1>Q39 — ton propre corps : aujourd'hui (silhouette bleue) et l'essai (sombre, liseré)</h1>")
    h.append("<p>Chaque paire est prise <b>au même instant</b> (jeu gelé, l'essai basculé en direct) : seul le corps de "
             "soi change. Rendu logiciel du cloud (llvmpipe) : les couleurs et les comptes de pixels valent, pas la "
             "cadence ni l'éblouissement. Lacet 45° (B pour J2), zoom du duel, 1920×1080. Luminances Rec. 709, 0..255. "
             "« Lisible » : un pixel du corps qui diffère d'au moins 10/255 de ce qu'il cache.</p>")
    h.append("<h2>Les illustrations qui montrent des personnages sombres</h2><div class='rang ill'>")
    for nom, legende in ills:
        h.append("<figure><img src='img/ill_%s.jpg' alt='%s'><figcaption><b>ill_%s</b> — %s</figcaption></figure>"
                 % (nom, nom, nom, legende))
    h.append("</div>")

    # Le tableau de synthèse.
    h.append("<h2>La lisibilité, en chiffres</h2><table><tr><th>classe</th><th>scène</th><th>corps aujourd'hui</th>"
             "<th>corps essai</th><th>liseré essai (p90)</th><th>sol autour</th><th>lisible aujourd'hui</th>"
             "<th>lisible essai</th><th>changés hors du corps</th></tr>")
    for slug, titre in CLASSES:
        for sc, nom_sc, _ in SCENES:
            m = mesures.get("%s_%s" % (slug, sc))
            if not m or not m.get("aujourd_hui"):
                continue
            a, e = m["aujourd_hui"], m["essai"]
            hors = m["essai_hors_du_corps"]
            h.append("<tr><th>%s</th><th>%s</th><td>%.0f</td><td>%.0f</td><td>%.0f</td><td>%.0f</td><td>%d %%</td>"
                     "<td>%d %%</td><td class='%s'>%d</td></tr>" % (
                         slug, nom_sc, a["corps_moyenne"], e["corps_moyenne"], e["corps_p90"], a["sol_autour"],
                         round(100 * a["part_lisible"]), round(100 * e["part_lisible"]), "ok" if hors == 0 else "ko",
                         hors))
    h.append("</table>")

    for slug, titre in CLASSES:
        h.append("<h2>%s</h2>" % titre)
        for sc, nom_sc, detail in SCENES:
            nom = "%s_%s" % (slug, sc)
            m = mesures.get(nom)
            if not m or not os.path.exists(os.path.join(ICI, "img", "%s_defaut_x3.jpg" % nom)):
                continue
            h.append("<h3>%s <span class='note'>— %s</span></h3><div class='rang'>" % (nom_sc, detail))
            for etat, lib, cle in (("defaut", "aujourd'hui", "aujourd_hui"), ("essai", "l'essai", "essai")):
                h.append("<figure><img src='img/%s_%s_1x.jpg' alt='%s 1:1'><figcaption>%s, 1:1</figcaption></figure>"
                         % (nom, etat, lib, lib))
            for etat, lib, cle in (("defaut", "aujourd'hui", "aujourd_hui"), ("essai", "l'essai", "essai")):
                h.append("<figure><img src='img/%s_%s_x3.jpg' alt='%s ×3'><figcaption>%s, loupe ×3 — %s</figcaption>"
                         "</figure>" % (nom, etat, lib, lib, chiffres(m.get(cle))))
            h.append("</div><p class='note'>Pixels que l'essai change hors du corps de soi : <b>%d</b> (dont allumés %d) · "
                     "bruit défaut/défaut recapturé : %s</p>" % (m["essai_hors_du_corps"], m["essai_allume_hors_du_corps"],
                                                                  m["bruit_defaut_defaut2"]))

    h.append("<h2>L'écran scindé : deux couleurs de joueur, et la vue de l'adversaire au pixel</h2>")
    h.append("<p>J1 à gauche (lacet 45°), J2 à droite (lacet B, 225°). Les deux torches allumées, J2 braque J1 de biais. "
             "Chaque joueur est local, donc chacun voit SON corps à l'essai ; dans la vue d'en face, le corps de l'autre "
             "doit rester celui d'aujourd'hui, au pixel.</p>")
    for slug, titre in CLASSES:
        nom = "%s_scinde" % slug
        m = mesures.get(nom)
        if not m:
            continue
        v1, v2 = m["vue_j1"], m["vue_j2"]
        h.append("<h3>%s</h3><div class='rang'>" % titre)
        for etat, lib in (("defaut", "aujourd'hui"), ("essai", "l'essai")):
            h.append("<figure><img src='img/%s_%s_ecran.jpg' alt='%s'><figcaption>%s, l'écran entier (réduit)"
                     "</figcaption></figure>" % (nom, etat, lib, lib))
        h.append("</div><div class='rang'>")
        for cote, v, lib_cote in (("j1", v1, "J1 dans sa vue (bleu)"), ("j2", v2, "J2 dans sa vue (rouge)")):
            for etat, lib, cle in (("defaut", "aujourd'hui", "aujourd_hui"), ("essai", "l'essai", "essai")):
                chemin = "img/%s_%s_%s_x3.jpg" % (nom, cote, etat)
                if os.path.exists(os.path.join(ICI, chemin)):
                    h.append("<figure><img src='%s' alt=''><figcaption>%s, %s ×3 — %s</figcaption></figure>"
                             % (chemin, lib_cote, lib, chiffres(v["soi"].get(cle))))
        for etat, lib in (("defaut", "aujourd'hui"), ("essai", "l'essai")):
            chemin = "img/%s_j1_chez_j2_%s_x3.jpg" % (nom, etat)
            if os.path.exists(os.path.join(ICI, chemin)):
                h.append("<figure><img src='%s' alt=''><figcaption>J1 vu par J2 (l'adversaire), %s ×3</figcaption>"
                         "</figure>" % (chemin, lib))
        h.append("</div>")
        ok = v2["adversaire_j1_change"] == 0 and v1["adversaire_j2_change"] == 0
        h.append("<p class='%s'>Vue de J2 : J1 y occupe %d pixels, <b>%d</b> changés par l'essai ; vue de J1 : J2 y occupe "
                 "%d pixels, <b>%d</b> changés. Hors du corps de soi : %d (vue de J1), %d (vue de J2). Noir rallumé hors "
                 "des corps : %d. Bruit : %s.</p>" % (
                     "ok" if ok else "ko", v2["adversaire_j1_pixels"], v2["adversaire_j1_change"],
                     v1["adversaire_j2_pixels"], v1["adversaire_j2_change"], v1["essai_hors_du_corps_de_soi"],
                     v2["essai_hors_du_corps_de_soi"], m["noir_rallume_hors_des_corps"], m["bruit_defaut_defaut2"]))
    h.append("</body></html>")
    with open(os.path.join(ICI, "planche.html"), "w") as f:
        f.write("\n".join(h))
    print("planche.html écrite")


if __name__ == "__main__":
    main()
