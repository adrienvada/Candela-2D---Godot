#!/usr/bin/env python3
"""L'écart aux illustrations, évaluation 11 — `planche.html` (autonome, images en chemins relatifs).

Les descriptions et le choix de la scène par illustration viennent de l'évaluation 10 (`../ecart-illustrations/analyse.py`,
son tableau thème par thème reste valable pour « hier ») ; les commentaires de cette évaluation dans `commentaires.py` ;
les chiffres dans `mesures.json` (`mesurer.py`).
"""
import html
import json
import os
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.normpath(os.path.join(ICI, "../../../.."))
sys.path.insert(0, os.path.join(RACINE, "docs/iso/cloud/ecart-illustrations"))
sys.path.insert(0, ICI)
from analyse import ILLUSTRATIONS, SCENES_LIBELLES  # noqa: E402
from commentaires import COMMENTAIRES, EN_TETE, CINQ_LIGNES, AUTRES_CARTES  # noqa: E402

LIBELLES = dict(SCENES_LIBELLES, **{
    "equite": "l'écran scindé, J1 et J2 aux places symétriques",
    "croisee_duel": "la Croisée, le duel", "croisee_noir": "la Croisée, torches éteintes",
    "bunker_duel": "le Bunker, le duel", "bunker_noir": "le Bunker, torches éteintes",
})
LANCS = [("defaut", "le jeu par défaut"), ("hier", "« hier » : les neuf essais de l'évaluation 10"),
         ("tout", "« tout » : les neuf, plus les cinq de la nuit")]


def nb(n):
    return f"{n:,}".replace(",", " ")


def pastille(rgb):
    return f'<span class="pastille" style="background:rgb({rgb[0]},{rgb[1]},{rgb[2]})"></span>' if rgb else ""


def chiffres(s, corps=None):
    if not s:
        return ""
    t = (f"médiane {s['mediane']:.0f} · 1 % le plus clair {s['top1']:.0f} {pastille(s['top1_rgb'])}"
         f"· montre {100 * s['eclaire']:.0f} %")
    if corps:
        t += f" · ton corps {corps['lum']:.0f} {pastille(corps['rgb'])}"
    return t


def fig(chemin, legende, classe=""):
    if chemin and os.path.exists(os.path.join(ICI, chemin)):
        return (f'<figure class="{classe}"><a href="{chemin}"><img loading="lazy" src="{chemin}" '
                f'alt="{html.escape(legende, quote=True)}"></a><figcaption>{legende}</figcaption></figure>')
    return f'<figure class="vide"><div>{legende}</div></figure>' if legende else "<figure></figure>"


def rangee_scene(m, scene, ill=None):
    cases = []
    if ill:
        cases.append(fig(f"img/{ill}.jpg", "L'illustration<br>" + chiffres(m["illustrations"].get(ill))))
    for lanc, lib in LANCS:
        s = m["prises"].get(f"{lanc}/{scene}")
        c = m["corps"].get(f"{lanc}/{scene}")
        cases.append(fig(f"img/jeu_{lanc}_{scene}.jpg", f"{html.escape(lib)}<br>" + chiffres(s, c)))
    if scene not in ("scinde", "equite"):
        if ill:
            cases.append("<figure></figure>")
        for lanc, lib in LANCS:
            cases.append(fig(f"img/loupe_{lanc}_{scene}.jpg", f"loupe ×2, même cadre — {html.escape(lib)}"))
    return f'<div class="grille {"quatre" if ill else "trois"}">{"".join(cases)}</div>'


def ligne_ecarts(m, scene):
    morceaux = []
    b = m["ecarts"].get(f"temoin/{scene}", {})
    for lanc in ("hier", "tout"):
        e = m["ecarts"].get(f"{lanc}/{scene}")
        if e:
            morceaux.append(f"« {lanc} » change {nb(e['change'])} pixels ({nb(e['plus_clair'])} plus clairs, "
                            f"{nb(e['plus_sombre'])} plus sombres ; noirs allumés {nb(e['noir_allume'])})")
    if not morceaux:
        return ""
    return (f'<p class="mesure">Contre le défaut : {" ; ".join(morceaux)}. Bruit (témoin) : {nb(b.get("change", 0))} '
            f'pixels, noirs allumés {nb(b.get("noir_allume", 0))}.</p>')


def tableau_resume(m):
    lignes = []
    for ill in ILLUSTRATIONS:
        a = m["a_l_illustration"].get(ill["nom"])
        if not a:
            continue
        cellules = []
        for lanc in ("defaut", "hier", "tout"):
            x = a.get(lanc, {})
            cellules.append(f"<td>{x.get('emd', '—')}</td>")
        for lanc in ("defaut", "tout"):
            x = a.get(lanc, {})
            cellules.append(f"<td>{x.get('top1', '—'):+}</td><td>{x.get('top1_rgb', '—')}</td>")
        lignes.append(f'<tr><th><a href="#{ill["nom"]}">{ill["nom"][4:]}</a></th><td>{a["scene"]}</td>'
                      + "".join(cellules) + "</tr>")
    return ('<table class="resume"><thead><tr><th>illustration</th><th>scène</th><th>écart défaut</th>'
            '<th>écart hier</th><th>écart tout</th><th>1 % clair, défaut</th><th>sa couleur, défaut</th>'
            '<th>1 % clair, tout</th><th>sa couleur, tout</th></tr></thead><tbody>' + "".join(lignes) +
            '</tbody></table><p class="mesure">« Écart » : la distance moyenne entre les deux distributions de '
            'luminance (0..255, quantile à quantile) — 0 si l\'image du jeu avait exactement les clairs et les sombres '
            'de l\'illustration. « 1 % clair » : de combien la lumière la plus claire du jeu est plus sombre (−) ou '
            'plus claire (+) que celle du dessin ; « sa couleur » : la distance RGB entre les deux couleurs de ce '
            '1 %.</p>')


def section_noir(m):
    lignes = []
    for cle, v in sorted(m["noir"].items()):
        lanc, scene = cle.split("/")
        lignes.append(f"<tr><th>{html.escape(LIBELLES.get(scene, scene))}</th><td>{lanc}</td>"
                      f"<td>{nb(v['noir_allume'])}</td><td>{nb(v['bruit'])}</td><td>{v['max_allume']}</td></tr>")
    return ('<table><thead><tr><th>scène, torches éteintes</th><th>lancement</th><th>pixels noirs (A et A\') '
            'allumés par B</th><th>bruit (A → A\')</th><th>valeur max allumée</th></tr></thead><tbody>'
            + "".join(lignes) + "</tbody></table>")


def section_equite(m):
    lignes = []
    for lanc in ("defaut", "temoin", "hier", "tout"):
        e = m["equite"].get(lanc)
        if not e:
            continue
        for cle, lib in (("decor_eclaire", "décor éclairé"), ("lumiere", "lumière (> 40)"), ("corps", "corps")):
            a, b = e["j1"][cle], e["j2"][cle]
            ecart = (b - a) / max(a, 1)
            lignes.append(f"<tr><td>{lanc}</td><th>{lib}</th><td>{nb(a)}</td><td>{nb(b)}</td>"
                          f"<td>{100 * ecart:+.2f} %</td></tr>")
        lignes.append(f"<tr><td>{lanc}</td><th>pixels qui diffèrent d'une moitié à l'autre</th>"
                      f"<td colspan=3>{nb(e['demi_tour_differe'])}</td></tr>")
    return ('<table><thead><tr><th>lancement</th><th>ce qui est compté</th><th>moitié de J1</th><th>moitié de J2</th>'
            '<th>J2 − J1</th></tr></thead><tbody>' + "".join(lignes) + "</tbody></table>")


def main():
    with open(os.path.join(ICI, "mesures.json"), encoding="utf-8") as f:
        m = json.load(f)
    blocs = []
    for ill in ILLUSTRATIONS:
        nom, scene = ill["nom"], ill.get("scene")
        com = COMMENTAIRES.get(nom, "")
        tete = f'<h2 id="{nom}">{html.escape(ill["titre"])} <code>{nom}.png</code></h2>'
        desc = f'<p class="desc">{html.escape(ill["decrit"])}</p>'
        if scene:
            corps = rangee_scene(m, scene, nom) + ligne_ecarts(m, scene)
        else:
            corps = ('<div class="grille quatre">' + fig(f"img/{nom}.jpg", "L'illustration") +
                     f'<figure class="vide large"><div>Aucune scène du jeu n\'approche cette image. '
                     f'{html.escape(ill.get("pourquoi_rien", ""))}</div></figure></div>')
        blocs.append(f'<section>{tete}{desc}{corps}<p class="com">{com}</p></section>')
    autres = "".join(f'<h3>{html.escape(LIBELLES[s])}</h3>{rangee_scene(m, s)}{ligne_ecarts(m, s)}'
                     for s in ("croisee_duel", "croisee_noir", "bunker_duel", "bunker_noir"))
    en_tete = "".join(
        f'<div class="paire"><h3>{html.escape(p["titre"])}</h3><div class="grille deux">'
        f'{fig(p["gauche"], p["legende_gauche"])}{fig(p["droite"], p["legende_droite"])}</div>'
        f'<p class="com">{p["texte"]}</p></div>' for p in EN_TETE)
    cinq = "".join(f"<li>{l}</li>" for l in CINQ_LIGNES)
    page = f"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Écart aux illustrations 11</title>
<style>
:root {{ --fond:#111; --texte:#ddd; --doux:#9a9a9a; --ligne:#333; }}
body {{ background:var(--fond); color:var(--texte); font:15px/1.45 system-ui,sans-serif; margin:0 auto; padding:16px;
  max-width:1600px; }}
h1 {{ font-size:1.5em; }} h2 {{ font-size:1.2em; margin-top:2.2em; border-top:1px solid var(--ligne); padding-top:1em; }}
h3 {{ font-size:1.05em; margin:1.4em 0 .4em; }}
code {{ color:var(--doux); font-size:.85em; }}
.desc, .com {{ max-width:75em; }} .com {{ color:#e8e0cc; }}
.grille {{ display:grid; gap:10px; }}
.grille.quatre {{ grid-template-columns:repeat(4,minmax(0,1fr)); }}
.grille.trois {{ grid-template-columns:repeat(3,minmax(0,1fr)); }}
.grille.deux {{ grid-template-columns:repeat(2,minmax(0,1fr)); }}
figure.large {{ grid-column:span 3; }}
@media (max-width:800px) {{ .grille.quatre, .grille.trois, .grille.deux {{ grid-template-columns:1fr; }}
  .grille figure:empty {{ display:none; }} figure.large {{ grid-column:auto; }} }}
code, p, td {{ overflow-wrap:anywhere; }}
nav {{ display:flex; flex-wrap:wrap; gap:.2em .8em; }} nav a {{ color:#bbb; font-size:.85em; }}
figure {{ margin:0; }} img {{ width:100%; height:auto; display:block; border:1px solid var(--ligne); }}
figcaption {{ font-size:.82em; color:var(--doux); padding:4px 0; }}
figure.vide div {{ border:1px dashed var(--ligne); color:var(--doux); padding:2em 1em; min-height:6em; }}
.pastille {{ display:inline-block; width:.9em; height:.9em; vertical-align:-2px; margin:0 .3em; border:1px solid #555; }}
.mesure {{ font-size:.85em; color:var(--doux); }}
table {{ border-collapse:collapse; margin-top:.6em; font-size:.9em; display:block; overflow-x:auto; }}
th, td {{ border:1px solid var(--ligne); padding:5px 7px; vertical-align:top; text-align:left; }}
thead th {{ background:#1c1c1c; }} a {{ color:#cbb892; }}
.paire {{ border:1px solid var(--ligne); padding:10px; margin:12px 0; }}
ol.cinq li {{ margin:.3em 0; }}
</style></head><body>
<h1>Le jeu devant ses illustrations — évaluation 11 : tout allumé ensemble</h1>
<ol class="cinq">{cinq}</ol>
<p>Pour chaque illustration des menus : l'image, puis la scène du jeu qui l'approche (1920×1080, lacet 45° B, zoom ×1,5)
en trois états — <b>défaut</b> ; <b>hier</b>, les neuf essais de l'évaluation 10 (<code>--faisceau --mannequin
--pochoirs-essai --encre-essai --tuyaux-essai --corps-detaille --enseignes-essai --fusee-rouge-long --fusee-rouge-sang</code>) ;
<b>tout</b>, les mêmes plus les cinq de la nuit du 28/09 (<code>--lampe-claire --corps-soi-sombre --murs-meubles-essai
--sol-marque-essai --fumee-masque-pochoir</code>). Même instant de jeu dans les trois (graine et horloge fixes). Dessous,
la loupe ×2 au même cadre. Rendu du cloud (llvmpipe) : les couleurs et le noir valent, la cadence non. Cliquer une image
l'ouvre en 1:1. Détail : <code>RAPPORT.md</code>.</p>
<h2>Les paires les plus parlantes</h2>{en_tete}
<h2>De combien l'écart s'est réduit</h2>{tableau_resume(m)}
<h2>Le noir, torches éteintes</h2>
<p>A = le défaut, A' = le témoin (le même lancement, refait), B = « hier » ou « tout ». Un pixel compte s'il est noir
(≤ 7,5/255 au canal maximal) dans A et dans A' et s'allume dans B.</p>{section_noir(m)}
<h2>L'équité — écran scindé, 45° B, les deux moitiés au même instant</h2>
<p>J1 et J2 aux places symétriques par le centre du Cloître, torche vers le pilier central ; au lacet B, la vue de J2
est celle de J1 à la même place de l'autre côté. Décor et lumière sont comptés sur la prise sans les corps, les corps par
différence entre les deux prises (même instant gelé).</p>
{rangee_scene(m, "equite")}{section_equite(m)}
<h2>Deux autres cartes</h2><p>{AUTRES_CARTES}</p>{autres}
<h2>Illustration par illustration</h2>
<nav>{"".join(f'<a href="#{i["nom"]}">{i["nom"][4:]}</a>' for i in ILLUSTRATIONS)}</nav>
{"".join(blocs)}
</body></html>
"""
    with open(os.path.join(ICI, "planche.html"), "w", encoding="utf-8") as f:
        f.write(page)
    print("planche.html écrite")


if __name__ == "__main__":
    main()
