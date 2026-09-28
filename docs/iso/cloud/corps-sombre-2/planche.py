#!/usr/bin/env python3
"""Q39, deuxième tour — monte `planche.html` depuis `mesures.json` et `img/` (écrits par `mesurer.py`), les preuves de la
pré-passe (`preuve_passe.json`, `img/passe_*.jpg`) et les illustrations à personnages sombres (`assets/ui/ill_*.png`).

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
    ("adverse", "Dans la torche adverse (ébloui)", "sa torche éteinte, J2 le braque droit (le voile laiteux de llvmpipe)"),
    ("fusee", "Sous une fusée", "sa torche éteinte, sa fusée lancée 1,5 s plus tôt"),
]
ETATS = (("defaut", "aujourd'hui"), ("essai", "essai A (sombre partout)"), ("fondu", "essai B (fondu)"))


def illustrations():
    out = []
    for nom, legende in ILLUSTRATIONS:
        src = os.path.join(RACINE, "assets", "ui", "ill_%s.png" % nom)
        dst = os.path.join(ICI, "img", "ill_%s.jpg" % nom)
        if not os.path.exists(src):
            continue
        if not os.path.exists(dst):
            im = Image.open(src).convert("RGB")
            if im.width > 800:
                im = im.resize((800, im.height * 800 // im.width), Image.LANCZOS)
            im.save(dst, quality=85)
        out.append((nom, legende))
    return out


def pc(m):
    return "%d %%" % round(100 * m["part_lisible"]) if m else "—"


def chiffres(m):
    if not m:
        return "—"
    return "corps %.0f · liseré p90 %.0f · sol %.0f · <b>%d %%</b> lisible" % (
        m["corps_moyenne"], m["corps_p90"], m["sol_autour"], round(100 * m["part_lisible"]))


def plage(vals, fmt="%d"):
    vals = [v for v in vals if v is not None]
    if not vals:
        return "—"
    a, b = min(vals), max(vals)
    return (fmt % a) if a == b else (fmt + "–" + fmt) % (a, b)


def main():
    with open(os.path.join(ICI, "mesures.json")) as f:
        mesures = json.load(f)
    preuve = {}
    if os.path.exists(os.path.join(ICI, "preuve_passe.json")):
        with open(os.path.join(ICI, "preuve_passe.json")) as f:
            preuve = json.load(f)
    ills = illustrations()
    h = []
    h.append("""<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Q39 — trois corps de soi</title>
<style>
:root{--fond:#111;--texte:#ddd;--pale:#999;--cadre:#333}
body{background:var(--fond);color:var(--texte);font:15px/1.5 system-ui,sans-serif;margin:0 auto;max-width:1560px;padding:16px}
h1{font-size:24px}h2{margin-top:40px;border-bottom:1px solid var(--cadre)}h3{margin:24px 0 6px}
.rang{display:flex;flex-wrap:wrap;gap:10px;align-items:flex-start}
figure{margin:0}figcaption{color:var(--pale);font-size:13px;max-width:480px}
img{max-width:100%;height:auto;image-rendering:pixelated;border:1px solid var(--cadre)}
.ill img{image-rendering:auto;max-width:380px}
.tab{overflow-x:auto}table{border-collapse:collapse;font-size:13px}td,th{border:1px solid var(--cadre);padding:3px 8px;text-align:right}
th{text-align:left}.ok{color:#7c7}.ko{color:#e77}.note{color:var(--pale)}.b{background:#1b2a1b}
</style></head><body>""")
    h.append("<h1>Q39, deuxième tour — ton propre corps : aujourd'hui, essai A, essai B</h1>")
    h.append("<p><b>Aujourd'hui</b> : moitié corps éclairé, moitié ta couleur (bleu glacier). <b>Essai A</b> "
             "(<code>--corps-soi-sombre</code>) : sombre partout, un liseré. <b>Essai B</b> "
             "(<code>--corps-soi-sombre=fondu</code>, l'idée de Beauté) : sombre <i>seulement</i> là où le corps "
             "d'aujourd'hui se fond dans le sol, celui d'aujourd'hui ailleurs. Les trois sont pris <b>au même instant</b> "
             "(jeu gelé, bascule en direct). Rendu logiciel du cloud : couleurs et comptes de pixels, pas la cadence ni "
             "l'éblouissement. Lacet 45° (225° pour J2), zoom du duel, 1920×1080. « Lisible » : pixel du corps qui "
             "diffère d'au moins 10/255 de ce qu'il cache.</p>")

    # Le tableau des trois colonnes, en tête.
    h.append("<h2>La part du corps qui se détache du sol</h2><div class='tab'><table><tr><th>lumière</th><th>classes</th>"
             "<th>sol autour</th><th>corps aujourd'hui</th><th>corps A</th><th>corps B</th><th>lisible aujourd'hui</th>"
             "<th>lisible A</th><th class='b'>lisible B</th><th>B hors du corps (allumés)</th></tr>")
    for sc, nom_sc, _ in SCENES:
        ms = [mesures.get("%s_%s" % (c, sc)) for c, _ in CLASSES]
        ms = [m for m in ms if m and m.get("defaut")]
        if not ms:
            continue
        h.append("<tr><th>%s</th><td>%d</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td>"
                 "<td class='b'>%s</td><td>%s (%s)</td></tr>" % (
                     nom_sc, len(ms), plage([round(m["defaut"]["sol_autour"]) for m in ms]),
                     plage([round(m["defaut"]["corps_moyenne"]) for m in ms]),
                     plage([round(m["essai"]["corps_moyenne"]) for m in ms]),
                     plage([round(m["fondu"]["corps_moyenne"]) for m in ms]),
                     plage([round(100 * m["defaut"]["part_lisible"]) for m in ms], "%d %%"),
                     plage([round(100 * m["essai"]["part_lisible"]) for m in ms], "%d %%"),
                     plage([round(100 * m["fondu"]["part_lisible"]) for m in ms], "%d %%"),
                     plage([m["fondu_hors_du_corps"] for m in ms]), plage([m["fondu_allume_hors_du_corps"] for m in ms])))
    h.append("</table></div>")
    h.append("<h3>Écran scindé</h3><div class='tab'><table><tr><th>scène</th><th>joueur</th><th>corps aujourd'hui → A → B"
             "</th><th>lisible aujourd'hui</th><th>lisible A</th><th class='b'>lisible B</th><th>l'adversaire dans sa vue : "
             "pixels / changés par A / par B</th></tr>")
    for sc, lib in (("scinde_noir", "torches éteintes"), ("scinde", "torches allumées, J2 braque J1")):
        for j, adv, nomj in (("j1", "j2_chez_j1", "J1 (bleu)"), ("j2", "j1_chez_j2", "J2 (rouge)")):
            ms = [mesures.get("%s_%s" % (c, sc)) for c, _ in CLASSES]
            ms = [m for m in ms if m and m["defaut"][j]]
            if not ms:
                continue
            h.append("<tr><th>%s</th><th>%s</th><td>%s → %s → %s</td><td>%s</td><td>%s</td><td class='b'>%s</td>"
                     "<td>%s / <b>%s</b> / <b>%s</b></td></tr>" % (
                         lib, nomj, plage([round(m["defaut"][j]["corps_moyenne"]) for m in ms]),
                         plage([round(m["essai"][j]["corps_moyenne"]) for m in ms]),
                         plage([round(m["fondu"][j]["corps_moyenne"]) for m in ms]),
                         plage([round(100 * m["defaut"][j]["part_lisible"]) for m in ms], "%d %%"),
                         plage([round(100 * m["essai"][j]["part_lisible"]) for m in ms], "%d %%"),
                         plage([round(100 * m["fondu"][j]["part_lisible"]) for m in ms], "%d %%"),
                         plage([m[adv + "_pixels"] for m in ms]), plage([m["essai_" + adv + "_change"] for m in ms]),
                         plage([m["fondu_" + adv + "_change"] for m in ms])))
    h.append("</table></div>")

    h.append("<h2>Les illustrations qui montrent des personnages sombres</h2><div class='rang ill'>")
    for nom, legende in ills:
        h.append("<figure><img src='img/ill_%s.jpg' alt='%s'><figcaption><b>ill_%s</b> — %s</figcaption></figure>"
                 % (nom, nom, nom, legende))
    h.append("</div>")

    for slug, titre in CLASSES:
        h.append("<h2>%s</h2>" % titre)
        for sc, nom_sc, detail in SCENES:
            nom = "%s_%s" % (slug, sc)
            m = mesures.get(nom)
            if not m or not os.path.exists(os.path.join(ICI, "img", "%s_defaut_x3.jpg" % nom)):
                continue
            h.append("<h3>%s <span class='note'>— %s</span></h3><div class='rang'>" % (nom_sc, detail))
            for etat, lib in ETATS:
                h.append("<figure><img src='img/%s_%s_x3.jpg' alt='%s ×3'><figcaption>%s, loupe ×3 — %s</figcaption>"
                         "</figure>" % (nom, etat, lib, lib, chiffres(m.get(etat))))
            h.append("</div><p class='note'>Hors du corps de soi : A change %d pixels (%d allumés), B %d (%d allumés) · "
                     "bruit défaut/défaut recapturé : %s</p>" % (
                         m["essai_hors_du_corps"], m["essai_allume_hors_du_corps"], m["fondu_hors_du_corps"],
                         m["fondu_allume_hors_du_corps"], m["bruit_defaut_defaut2"]))

    h.append("<h2>L'écran scindé, et la vue de l'adversaire au pixel</h2>")
    for slug, titre in CLASSES:
        nom = "%s_scinde" % slug
        m = mesures.get(nom)
        if not m:
            continue
        h.append("<h3>%s</h3><div class='rang'>" % titre)
        for etat, lib in ETATS:
            h.append("<figure><img src='img/%s_%s_ecran.jpg' alt='%s'><figcaption>%s, l'écran entier (réduit)"
                     "</figcaption></figure>" % (nom, etat, lib, lib))
        h.append("</div><div class='rang'>")
        for cote, lib_cote in (("j1", "J1 dans sa vue"), ("j2", "J2 dans sa vue")):
            for etat, lib in ETATS:
                chemin = "img/%s_%s_%s_x3.jpg" % (nom, cote, etat)
                if os.path.exists(os.path.join(ICI, chemin)):
                    h.append("<figure><img src='%s' alt=''><figcaption>%s, %s ×3 — %s</figcaption></figure>"
                             % (chemin, lib_cote, lib, chiffres(m[etat].get(cote))))
        for etat, lib in ETATS:
            chemin = "img/%s_j1_chez_j2_%s_x3.jpg" % (nom, etat)
            if os.path.exists(os.path.join(ICI, chemin)):
                h.append("<figure><img src='%s' alt=''><figcaption>J1 vu par J2 (l'adversaire), %s ×3</figcaption>"
                         "</figure>" % (chemin, lib))
        h.append("</div>")
        ok = all(m[k] == 0 for k in ("essai_j1_chez_j2_change", "essai_j2_chez_j1_change", "fondu_j1_chez_j2_change",
                                     "fondu_j2_chez_j1_change"))
        h.append("<p class='%s'>J1 dans la vue de J2 : %d pixels, changés par A <b>%d</b>, par B <b>%d</b> ; J2 dans la vue de "
                 "J1 : %d pixels, changés par A <b>%d</b>, par B <b>%d</b>. Bruit : %s.</p>" % (
                     "ok" if ok else "ko", m["j1_chez_j2_pixels"], m["essai_j1_chez_j2_change"],
                     m["fondu_j1_chez_j2_change"], m["j2_chez_j1_pixels"], m["essai_j2_chez_j1_change"],
                     m["fondu_j2_chez_j1_change"], m["bruit_defaut_defaut2"]))

    if preuve:
        h.append("<h2>Le correctif de pré-passe, à l'image (banc des corps, llvmpipe)</h2>")
        h.append("<p>Chaque prise jugée contre la même scène, pré-passes cachées (critère de l'ordre 426). <b>État "
                 "corrigé</b> : rien, détail, Q39, Q39 + détail (fusionné et boîtes). <b>État d'avant</b> "
                 "(<code>--passe-ancienne</code>) : deux programmes, exprès. <b>Témoin</b> : la couleur du torse cachée, sa "
                 "pré-passe laissée — l'aspect exact du défaut, que la mesure doit voir.</p><div class='tab'><table><tr>"
                 "<th>prise</th><th>corps (px)</th><th>noirs anormaux</th><th>blocs 2×2</th><th>différents &gt; 8/255</th>"
                 "<th>écart max</th></tr>")
        for k, v in preuve.items():
            mauvais = v["noirs"] or v["blocs2x2"] or v["diff"]
            h.append("<tr><th>%s</th><td>%d</td><td>%d</td><td>%d</td><td class='%s'>%d</td><td>%d</td></tr>" % (
                k, v["corps"], v["noirs"], v["blocs2x2"], ("ko" if mauvais else "ok"), v["diff"], v["ecart_max"]))
        h.append("</table></div><div class='rang'>")
        for f, lib in (("passe_rien_pistolet_0.8", "sans rien, 0,8"), ("passe_q39_pistolet_0.8", "Q39, 0,8"),
                       ("passe_q39det_pistolet_0.8", "Q39 + détail, fusionné, 0,8"),
                       ("passe_q39det_pistolet_0.8_boites", "Q39 + détail, boîtes, 0,8"),
                       ("passe_q39_occulteur_0.8", "Occulteur, Q39, 0,8"), ("passe_q39_pistolet_0.15", "Q39, 0,15"),
                       ("passe_temoin_pistolet_0.8", "TÉMOIN (défaut simulé), 0,8"),
                       ("passe_temoin_pistolet_0.15", "TÉMOIN (défaut simulé), 0,15")):
            if os.path.exists(os.path.join(ICI, "img", f + ".jpg")):
                h.append("<figure><img src='img/%s.jpg' alt=''><figcaption>%s</figcaption></figure>" % (f, lib))
        h.append("</div>")
    h.append("</body></html>")
    with open(os.path.join(ICI, "planche.html"), "w") as f:
        f.write("\n".join(h))
    print("planche.html écrite")


if __name__ == "__main__":
    main()
