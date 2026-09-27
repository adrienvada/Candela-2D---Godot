#!/usr/bin/env python3
"""L'écart du jeu à ses illustrations — `planche.html` (autonome, images en chemins relatifs) et `ILLUSTRATIONS.md`.

Le contenu (descriptions, scènes, tableaux) vit dans `analyse.py` ; les chiffres dans `mesures.json` (`mesurer.py`).
"""
import html
import json
import os

from analyse import ILLUSTRATIONS, SCENES_LIBELLES, VERDICTS

ICI = os.path.dirname(os.path.abspath(__file__))


def pct(x):
    return f"{100 * x:.0f} %" if x is not None else "—"


def chiffres(m, cle):
    s = m.get(cle)
    if not s:
        return "—"
    t = s.get("teinte")
    pastille = (f'<span class="pastille" style="background:rgb({t[0]},{t[1]},{t[2]})"></span>' if t else "")
    return f"{pastille}montre {pct(s['eclaire'])} de l'image · luminance {s['lum_moy']:.0f}"


def cellule_image(chemin, legende):
    if chemin and os.path.exists(os.path.join(ICI, chemin)):
        return (f'<figure><a href="{chemin}"><img loading="lazy" src="{chemin}" alt="{html.escape(legende)}"></a>'
                f'<figcaption>{legende}</figcaption></figure>')
    return f'<figure class="vide"><div>{legende}</div></figure>'


def main():
    with open(os.path.join(ICI, "mesures.json"), encoding="utf-8") as f:
        m = json.load(f)
    blocs = []
    md = ["# L'écart, illustration par illustration", "",
          "Engendré par `planche.py` depuis `analyse.py` et `mesures.json` — ne pas éditer à la main.", ""]
    for ill in ILLUSTRATIONS:
        nom = ill["nom"]
        scene = ill.get("scene")
        s_ill = m["illustrations"].get(nom, {})
        tete = f'<h2 id="{nom}">{html.escape(ill["titre"])} <code>{nom}.png</code></h2>'
        desc = f'<p class="desc">{html.escape(ill["decrit"])}</p>'
        if scene:
            lib = SCENES_LIBELLES[scene]
            ecart = m["ecarts"].get(scene, {})
            bruit = m["bruit"].get(scene, {})
            figs = "".join([
                cellule_image(f"img/{nom}.jpg", "L'illustration<br>" + chiffres({"x": s_ill}, "x")),
                cellule_image(f"img/jeu_defaut_{scene}.jpg",
                              f"Le jeu par défaut — {html.escape(lib)}<br>" + chiffres(m["prises"], f"defaut/{scene}")),
                cellule_image(f"img/jeu_tous_{scene}.jpg",
                              "Le jeu, tous les essais allumés<br>" + chiffres(m["prises"], f"tous/{scene}")),
            ])
            mesure = ""
            if ecart:
                mesure = (f'<p class="mesure">Des essais au défaut : {ecart["change"]:,} pixels changent '
                          f'({ecart["plus_clair"]:,} plus clairs, {ecart["plus_sombre"]:,} plus sombres) ; '
                          f'noirs allumés : {ecart["noir_allume"]:,} (dont noir strict : {ecart["noir_strict_allume"]:,}). '
                          f'Bruit entre deux lancements par défaut : {bruit.get("change", 0):,} pixels, '
                          f'noirs allumés {bruit.get("noir_allume", 0):,}.</p>').replace(",", " ")
            if ill.get("note_scene"):
                mesure += f'<p class="mesure">{html.escape(ill["note_scene"])}</p>'
        else:
            figs = cellule_image(f"img/{nom}.jpg", "L'illustration<br>" + chiffres({"x": s_ill}, "x")) + \
                '<figure class="vide"><div>Aucune scène du jeu n\'approche cette image.<br>' + \
                html.escape(ill.get("pourquoi_rien", "")) + '</div></figure>'
            mesure = ""
        lignes = []
        for r in ill.get("tableau", []):
            v = VERDICTS[r["verdict"]]
            lignes.append(f'<tr><th>{html.escape(r["theme"])}</th><td>{html.escape(r["la"])}</td>'
                          f'<td>{html.escape(r["essais"])}</td><td>{html.escape(r["manque"])}</td>'
                          f'<td class="v {r["verdict"]}">{html.escape(v)}</td></tr>')
        tableau = ""
        if lignes:
            tableau = ('<table><thead><tr><th>Thème</th><th>Déjà là</th><th>Ce que les essais apportent</th>'
                       '<th>Ce qui manque</th><th>Invariants</th></tr></thead><tbody>' + "".join(lignes) +
                       '</tbody></table>')
        blocs.append(f'<section>{tete}{desc}<div class="trio">{figs}</div>{mesure}{tableau}</section>')

        md += [f"## {ill['titre']} — `{nom}.png`", "", ill["decrit"], ""]
        if scene:
            md += [f"Scène du jeu : **{SCENES_LIBELLES[scene]}** (`img/jeu_defaut_{scene}.jpg`, "
                   f"`img/jeu_tous_{scene}.jpg`).", ""]
        else:
            md += [f"Aucune scène du jeu ne l'approche : {ill.get('pourquoi_rien', '')}", ""]
        if ill.get("tableau"):
            md += ["| Thème | Déjà là | Les essais apportent | Manque | Invariants |", "|---|---|---|---|---|"]
            for r in ill["tableau"]:
                md.append(f"| {r['theme']} | {r['la']} | {r['essais']} | {r['manque']} | {VERDICTS[r['verdict']]} |")
            md.append("")

    page = f"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Écart aux illustrations</title>
<style>
:root {{ --fond:#111; --texte:#ddd; --doux:#999; --ligne:#333; --ok:#6a6; --non:#c55; --moitie:#ca5; }}
body {{ background:var(--fond); color:var(--texte); font:15px/1.45 system-ui,sans-serif; margin:0 auto; padding:16px;
  max-width:1500px; }}
h1 {{ font-size:1.5em; }} h2 {{ font-size:1.2em; margin-top:2.2em; border-top:1px solid var(--ligne); padding-top:1em; }}
code {{ color:var(--doux); font-size:.85em; }}
.desc {{ color:#ccc; max-width:70em; }}
.trio {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(300px,1fr)); gap:10px; }}
figure {{ margin:0; }} img {{ width:100%; height:auto; display:block; border:1px solid var(--ligne); }}
figcaption {{ font-size:.85em; color:var(--doux); padding:4px 0; }}
figure.vide div {{ border:1px dashed var(--ligne); color:var(--doux); padding:2em 1em; min-height:8em; }}
.pastille {{ display:inline-block; width:.9em; height:.9em; vertical-align:-2px; margin-right:.4em; border:1px solid #555; }}
.mesure {{ font-size:.85em; color:var(--doux); }}
table {{ border-collapse:collapse; width:100%; margin-top:.6em; font-size:.9em; }}
th, td {{ border:1px solid var(--ligne); padding:5px 7px; vertical-align:top; text-align:left; }}
thead th {{ background:#1c1c1c; }} tbody th {{ white-space:nowrap; }}
td.v.compatible {{ color:var(--ok); }} td.v.contredit {{ color:var(--non); }} td.v.moitie {{ color:var(--moitie); }}
nav a {{ color:#bbb; margin-right:.8em; font-size:.85em; }}
@media (max-width:700px) {{ tbody th {{ white-space:normal; }} table {{ font-size:.8em; }} }}
</style></head><body>
<h1>Le jeu devant ses illustrations</h1>
<p>Pour chacune des vingt illustrations des menus : l'image, la scène du jeu qui l'approche le plus
(1920×1080, lacet 45° B, zoom ×1,5 — les valeurs du jeu), le jeu par défaut, puis le même instant avec <b>tous</b> les
essais de la nuit allumés (<code>--faisceau --mannequin --pochoirs-essai --encre-essai --tuyaux-essai --corps-detaille
--enseignes-essai --fusee-rouge-long --fusee-rouge-sang</code>). Rendu du cloud (llvmpipe) : les couleurs et le noir
valent, la cadence non. Détail et synthèse : <code>RAPPORT.md</code>. Cliquer une image l'ouvre en grand.</p>
<nav>{"".join(f'<a href="#{i["nom"]}">{i["nom"][4:]}</a>' for i in ILLUSTRATIONS)}</nav>
{"".join(blocs)}
</body></html>
"""
    with open(os.path.join(ICI, "planche.html"), "w", encoding="utf-8") as f:
        f.write(page)
    with open(os.path.join(ICI, "ILLUSTRATIONS.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(md) + "\n")
    print("planche.html et ILLUSTRATIONS.md écrits")


if __name__ == "__main__":
    main()
