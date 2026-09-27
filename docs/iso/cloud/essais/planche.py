#!/usr/bin/env python3
"""Monte `planche.html` (autonome, images en chemins relatifs) à partir de `mesures.json` — lancer `mesurer.py` avant."""
import html
import json
import os

ICI = os.path.dirname(os.path.abspath(__file__))
M = json.load(open(os.path.join(ICI, "mesures.json"), encoding="utf-8"))
NOM_ILL = {
    "ill_intro_allumage": "Intro, « allumage »", "ill_accueil": "Accueil", "ill_ecran_scinde": "Écran scindé",
    "ill_creer_local": "Créer en local", "ill_entrainement": "Entraînement",
}
ETAT = {"allumees": "torches allumées", "eteintes": "torches éteintes"}


def e(t):
    return html.escape(str(t))


def fig(src, legende, classe=""):
    if not src:
        return ""
    return (f'<figure class="{classe}"><a href="{e(src)}"><img loading="lazy" src="{e(src)}" alt="{e(legende)}"></a>'
            f"<figcaption>{legende}</figcaption></figure>")


def chiffres_entre(ch, scene):
    if not ch:
        return ""
    h, z = ch["hors_corps"], ch["zone_corps"]
    t3 = M["scenes"].get(scene, {}).get("temoin3", {}).get("zone_corps")
    ref = (f" — un 3ᵉ témoin, sans aucun essai, y fait {t3['changes']} changés, {t3['plus_clairs']} plus clairs, "
           f"{t3['noirs_allumes_stricts']} noirs allumés") if t3 else ""
    return (f"<li><b>Hors des corps</b> (entre lancements, bruit mesuré 0) : {h['changes']} pixels changés · "
            f"<b>{h['noirs_allumes_stricts']}</b> noirs allumés (0 → plus), {h['noirs_allumes_seuil']} au seuil 7,5/255 · "
            f"<b>{h['plus_clairs']}</b> plus clairs que sans (écart max {h['exces_max']}/255)</li>"
            f"<li><b>Zone des corps</b> (le souffle des corps diffère d'un lancement à l'autre) : {z['changes']} changés · "
            f"{z['noirs_allumes_stricts']} noirs allumés · {z['plus_clairs']} plus clairs (max {z['exces_max']}){ref}</li>")


def chiffres_intra(r):
    if not r:
        return ""
    s = (f"<li><b>Même instant, sans l'essai</b> (jeu en pause, seul l'essai caché) : {r['changes']} pixels changés · "
         f"<b>{r['noirs_allumes_stricts']}</b> noirs allumés, {r['noirs_allumes_seuil']} au seuil · "
         f"<b>{r['plus_clairs']}</b> plus clairs que la surface derrière (écart max {r['exces_max']}/255) · "
         f"bruit (l'essai contre lui-même) : {r['bruit_avec_contre_avec2']}</li>")
    if "emprise_lum_moy_avec" in r:
        s += (f"<li>Sur l'emprise : luminance moyenne {r['emprise_lum_moy_avec']} avec, {r['emprise_lum_moy_sans']} sans ; "
              f"{round(100 * r['emprise_plus_clairs_part'], 1)} % de ses pixels plus clairs que la surface qu'ils cachent "
              f"(écarts 3-8 / 9-16 / 17-32 / 33-64 / 65+ : {' / '.join(str(x) for x in r['exces_histo_3_8_16_32_64_255'])})</li>")
    return s


def section(ident, es):
    out = [f'<section id="{e(ident)}"><h2>{e(es["titre"])} <code>{e(es["drapeau"])}</code></h2><p class="quoi">{e(es["quoi"])}</p>']
    for s in es["montrees"]:
        cle = f"{s}_allumees"
        v = es["scenes"].get(cle)
        if not v:
            continue
        eteint = v.get("image_sans") or f"img/temoin_{cle}.jpg"
        leg_eteint = "Éteint — même instant, l'essai caché" if v.get("image_sans") else "Éteint — lancement témoin"
        cadre = ("en écran scindé : J1 à gauche, J2 à droite depuis le côté opposé (lacet B)" if s == "scinde"
                 else "à la taille du jeu (1920×1080, zoom ×1,5, 45° B)" if ident != "tuyaux_pres"
                 else "de près : caméra ×4,5, un vrai rendu")
        out.append(f'<h3>Scène « {e(s)} », {ETAT["allumees"]}, {cadre}</h3><div class="rang">')
        for ill in es["cibles"]:
            out.append(fig(f"img/{ill}.jpg", f"Cible : {NOM_ILL.get(ill, ill)}", "cible"))
        out.append(fig(eteint, leg_eteint))
        out.append(fig(v.get("image"), "Allumé"))
        out.append("</div>")
        if v.get("loupe"):
            out.append('<div class="rang deux">')
            out.append(fig(v.get("loupe_sans") or v.get("loupe_temoin"), "Loupe ×3 — éteint"))
            out.append(fig(v.get("loupe"), "Loupe ×3 — allumé"))
            out.append("</div>")
        if v.get("carte_exces"):
            out.append('<div class="rang deux">')
            out.append(fig(v.get("carte_exces"), "Carte : en bleu l'emprise de l'essai, en ROUGE ses pixels plus clairs que le mur qu'ils cachent"))
            out.append(fig(v.get("carte_exces_loupe"), "La même carte, loupe ×3"))
            out.append("</div>")
    out.append("<h3>Les chiffres</h3>")
    for cle, v in es["scenes"].items():
        out.append(f"<p class=\"cle\">{e(cle.replace('_', ' — ').replace('allumees', ETAT['allumees']).replace('eteintes', ETAT['eteintes']))}</p><ul>")
        out.append(chiffres_entre(v.get("chiffres"), cle))
        out.append(chiffres_intra(v.get("intra")))
        out.append("</ul>")
        if cle.endswith("eteintes") and cle.split("_")[0] in es["montrees"] and v.get("loupe"):
            out.append('<div class="rang deux petit">')
            out.append(fig(v.get("loupe_sans") or v.get("loupe_temoin"), "Torches éteintes, loupe ×3 — éteint"))
            out.append(fig(v.get("loupe"), "Torches éteintes, loupe ×3 — allumé"))
            out.append("</div>")
    out.append("</section>")
    return "\n".join(out)


def main():
    tete = open(os.path.join(ICI, "planche_tete.html"), encoding="utf-8").read() if os.path.exists(
        os.path.join(ICI, "planche_tete.html")) else ""
    nav = " · ".join(f'<a href="#{e(k)}">{e(v["titre"])}</a>' for k, v in M["essais"].items())
    corps = "\n".join(section(k, v) for k, v in M["essais"].items())
    page = f"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Essais éteints, sur image</title>
<style>
:root {{ --fond:#111; --texte:#ddd; --doux:#999; --trait:#333; --accent:#e0a040; }}
body {{ background:var(--fond); color:var(--texte); font:15px/1.5 system-ui, sans-serif; margin:0 auto; max-width:1800px; padding:16px; }}
h1 {{ font-size:1.6em; }} h2 {{ border-top:1px solid var(--trait); padding-top:1em; margin-top:2em; }}
h2 code {{ color:var(--accent); font-size:.7em; }} h3 {{ font-size:1em; color:var(--doux); }}
.rang {{ display:grid; grid-template-columns:repeat(auto-fit, minmax(300px, 1fr)); gap:10px; }}
.rang.deux {{ grid-template-columns:repeat(auto-fit, minmax(420px, 1fr)); }}
.rang.petit {{ max-width:900px; }}
figure {{ margin:0; }} img {{ width:100%; height:auto; display:block; border:1px solid var(--trait); }}
figcaption {{ font-size:.85em; color:var(--doux); }} figure.cible figcaption {{ color:var(--accent); }}
.quoi {{ color:var(--doux); }} .cle {{ margin:.8em 0 0; font-weight:600; }} ul {{ margin:.2em 0; }}
nav {{ font-size:.9em; }} a {{ color:var(--accent); }}
@media (max-width:700px) {{ .rang, .rang.deux {{ grid-template-columns:1fr; }} }}
</style></head><body>
<h1>Les essais éteints, sur image</h1>
{tete}
<nav>{nav}</nav>
{corps}
</body></html>"""
    open(os.path.join(ICI, "planche.html"), "w", encoding="utf-8").write(page)
    print("planche.html écrite")


if __name__ == "__main__":
    main()
