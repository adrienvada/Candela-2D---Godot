#!/usr/bin/env python3
"""Le sol marqué — la planche (`planche.html`), à partir de `mesures.json` et de `img/` (écrits par `mesurer.py`)."""
import html, json, os

ICI = os.path.dirname(os.path.abspath(__file__))
M = json.load(open(os.path.join(ICI, "mesures.json"), encoding="utf-8"))
NOMS = {"gravats": "Gravats", "eclats": "Éclats épars", "chaine": "Chaînes", "cadre": "Cadres de bandes",
        "bande": "Bandes de marquage", "lettres": "Lettres de secteur"}
LEGENDES = {
    "gravats": "un tas allongé au pied du pilier, à une demi-case de lui : on n'en garde que l'ombre (noir à 38-60 %)",
    "eclats": "quelques débris sur un disque d'une case, dans la salle",
    "chaine": "maillons à plat et de chant, en arc lâche, noirs à 60 %",
    "cadre": "le cadre du « DEATHMATCH » nord, bandes de 3,5 px noires à 30 %, usées symétriquement",
    "bande": "la bande de l'axe, entre les deux piliers du nord",
    "lettres": "« B-07 », noir à 40 %, fonte des pochoirs à 14 px",
}
ILL = {"gravats": "amical", "eclats": "intro_prix", "chaine": "créer local", "cadre": "créer local",
       "bande": "créer local", "lettres": "créer local"}


def fig(src, legende, classe=""):
    if not src or not os.path.exists(os.path.join(ICI, src)):
        return f'<figure class="{classe}"><div class="manque">absente</div><figcaption>{html.escape(legende)}</figcaption></figure>'
    return (f'<figure class="{classe}"><a href="{src}"><img src="{src}" loading="lazy" alt="{html.escape(legende)}"></a>'
            f'<figcaption>{html.escape(legende)}</figcaption></figure>')


def chiffres(m):
    e, b = m["essai"], m["bruit"]
    return (f"<p class=\"chiffres\">A − B : <b>{e['pixels_changes']:,}</b> pixels changent, {e['plus_sombres']:,} plus "
            f"sombres (−{e['assombrissement_moyen']} en moyenne) ; plus clairs : <b>{e['plus_clairs_2']}</b> de 2/255 ou plus, "
            f"{e['plus_clairs_1']} d'1/255 (l'arrondi). Bruit A − A' : <b>{b['pixels_changes']}</b>. Noirs allumés : "
            f"<b>{m['noirs_allumes_A']}</b>.</p>").replace(",", "&#8239;")


def main():
    seul = M["seances"].get("seul", {})
    tous = M["seances"].get("tous", {})
    parts = []
    for fam in NOMS:
        m = seul.get(fam)
        if m is None:
            continue
        parts.append(f'<section><h2>{NOMS[fam]}</h2><p class="leg">{html.escape(LEGENDES[fam])}</p><div class="rang">')
        parts.append(fig(f"img/ill_{fam}.jpg", f"l'illustration ({ILL[fam]})", "ill"))
        parts.append(fig(m.get("jeu_sans"), "le jeu, sans (1:1)"))
        parts.append(fig(m.get("jeu_avec"), "le jeu, avec (1:1)"))
        parts.append('</div><div class="rang">')
        parts.append(fig(m.get("loupe_sans"), "loupe ×3, sans"))
        parts.append(fig(m.get("loupe_avec"), "loupe ×3, avec"))
        t = tous.get(fam)
        if t is not None:
            parts.append(fig(t.get("jeu_avec"), "tous les essais + sol marqué (1:1)"))
        parts.append("</div>" + chiffres(m) + "</section>")

    preuves = []
    noir = seul.get("noir")
    if noir:
        preuves.append(f"<li><b>Le noir absolu</b> (torches éteintes, scène des gravats) : sur {noir['noirs_de_B']:,} pixels "
                       f"noirs sans marques, <b>{noir['noirs_allumes_A']}</b> s'allument avec (A) et "
                       f"<b>{noir['noirs_allumes_A2']}</b> en A'. Plus clairs de 2/255 ou plus : "
                       f"{noir['essai']['plus_clairs_2']}.</li>")
    sc = seul.get("scinde")
    if sc:
        j1, j2 = sc["j1"], sc["j2"]
        r = j2["assombrissement_somme"] / max(j1["assombrissement_somme"], 1e-6)
        preuves.append(f"<li><b>La symétrie à 45° B</b> (écran scindé, J1 devant un tas, J2 devant son jumeau) : vue de J1, "
                       f"{j1['plus_sombres']:,} pixels assombris (somme {j1['assombrissement_somme']:,}) ; vue de J2, "
                       f"{j2['plus_sombres']:,} (somme {j2['assombrissement_somme']:,}) — rapport J2/J1 {r:.3f}.</li>")
    for nom in ("contraste4", "contraste7"):
        c = seul.get(nom)
        if c and "marque" in c:
            preuves.append(f"<li><b>Le contraste d'un corps adverse</b> ({nom[-1]} cases dans le cône, torche éteinte, debout "
                           f"sur des marques) : corps {c['nu']['corps']} contre sol {c['nu']['anneau']} sur sol nu "
                           f"(Δ {c['nu']['difference']}, Michelson {c['nu']['michelson']}) ; corps {c['marque']['corps']} contre "
                           f"sol {c['marque']['anneau']} sur sol marqué (Δ {c['marque']['difference']}, Michelson "
                           f"{c['marque']['michelson']}).</li>")
    contr = ""
    for nom in ("contraste4", "contraste7"):
        c = seul.get(nom)
        if c and "img_nu" in c:
            contr += '<div class="rang">' + fig(c["img_nu"], f"{nom} : sol nu (×2)") + fig(c["img_marque"],
                                                                                       f"{nom} : sol marqué (×2)") + "</div>"
    ens = ""
    g = tous.get("gravats")
    if g:
        ens = ('<section><h2>Vue d\'ensemble : tous les essais allumés</h2><div class="rang deux">'
               + fig(g.get("img_plein_sans"), "tous les essais, sans le sol marqué")
               + fig(g.get("img_plein_avec"), "tous les essais, avec le sol marqué") + "</div>")
        if sc:
            ens += '<div class="rang deux">' + fig(sc.get("img_sans"), "écran scindé, sans") + fig(sc.get("img_avec"),
                                                                                                 "écran scindé, avec") + "</div>"
        ens += "</section>"
    page = f"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sol marqué</title>
<style>
:root {{ --fond: #111; --texte: #ddd; --doux: #999; --trait: #333; --accent: #d9a441; }}
body {{ background: var(--fond); color: var(--texte); font: 15px/1.5 system-ui, sans-serif; margin: 0 auto; max-width: 1400px;
  padding: 16px; }}
h1 {{ font-size: 1.6em; margin: .2em 0; }} h2 {{ color: var(--accent); border-bottom: 1px solid var(--trait); padding-bottom: .2em; }}
.rang {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin: 8px 0; }}
.rang.deux {{ grid-template-columns: repeat(2, 1fr); }}
figure {{ margin: 0; }} img {{ width: 100%; display: block; image-rendering: pixelated; border: 1px solid var(--trait); }}
figure.ill img {{ image-rendering: auto; }}
figcaption, .leg {{ color: var(--doux); font-size: .9em; }} .chiffres {{ font-size: .9em; }}
.manque {{ padding: 2em; text-align: center; border: 1px dashed var(--trait); color: var(--doux); }}
li {{ margin: .4em 0; }}
@media (max-width: 800px) {{ .rang, .rang.deux {{ grid-template-columns: 1fr; }} }}
</style></head><body>
<h1>Le sol marqué, à l'essai</h1>
<p class="leg">Drapeau <code>--sol-marque-essai</code>, éteint par défaut. Le Cloître, 1920×1080, lacet 45° B, zoom du duel.
Chaque paire « sans / avec » est prise au <b>même instant</b>, jeu en pause (les marques retirées puis remises : A, B, A').
Rendu logiciel du cloud : les couleurs valent à ~1/255 du Mac ; aucune cadence ici.</p>
<section><h2>Les preuves</h2><ul>{''.join(preuves)}</ul>{contr}</section>
{''.join(parts)}
{ens}
</body></html>
"""
    open(os.path.join(ICI, "planche.html"), "w", encoding="utf-8").write(page)
    print("planche.html écrite")


main()
