#!/usr/bin/env python3
"""La planche des murs meublés : lit `planche.json` et `mesures.json` (écrits par `mesurer.py`), écrit `planche.html`."""
import html
import json
import os

ICI = os.path.dirname(os.path.abspath(__file__))


def chiffre(m, cle, defaut="—"):
    if not m or m.get(cle) is None:
        return defaut
    v = m[cle]
    return ("{:,}".format(v).replace(",", " ")) if isinstance(v, int) else str(v)


def main():
    p = json.load(open(os.path.join(ICI, "planche.json")))
    mesures = json.load(open(os.path.join(ICI, "mesures.json")))
    h = []
    h.append("""<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Murs meublés</title>
<style>
:root { --fond:#141210; --carte:#1f1b17; --texte:#e8e0d4; --doux:#a39888; --trait:#3a332b; --accent:#d9a65a; }
body { margin:0; background:var(--fond); color:var(--texte); font:15px/1.5 system-ui, sans-serif; }
main { max-width:1500px; margin:0 auto; padding:24px 16px 64px; }
h1 { font-size:26px; margin:0 0 4px; } h2 { font-size:19px; margin:36px 0 10px; color:var(--accent); }
p.doux, .doux { color:var(--doux); }
.rangee { display:grid; grid-template-columns:repeat(auto-fit, minmax(220px, 1fr)); gap:10px; align-items:start; }
figure { margin:0; background:var(--carte); border:1px solid var(--trait); border-radius:6px; padding:6px; }
figure img { width:100%; height:auto; display:block; image-rendering:pixelated; border-radius:3px; }
figcaption { font-size:12.5px; color:var(--doux); margin-top:4px; }
table { border-collapse:collapse; margin:10px 0; font-size:13.5px; width:100%; }
td, th { border-bottom:1px solid var(--trait); padding:4px 8px; text-align:right; }
th:first-child, td:first-child { text-align:left; }
.ok { color:#8fc98f; } .ko { color:#e07a6a; }
.large { grid-column:1 / -1; }
@media (max-width:800px) { .rangee { grid-template-columns:1fr 1fr; } }
</style></head><body><main>
<h1>Les murs meublés, à l'essai</h1>
<p class="doux">Drapeau <code>--murs-meubles-essai</code>, éteint par défaut. Carte : le Cloître, cadrage du jeu (1920×1080,
lacet 45° B). « Sans » et « avec » sont pris au MÊME instant (jeu en pause, l'essai caché puis montré). Les loupes sont
agrandies trois fois au plus proche : ce sont les pixels du jeu. Rendu logiciel du cloud : les couleurs et les comptes de
pixels valent, pas la cadence.</p>
""")
    for r in p["rangees"]:
        m, mn = r.get("m") or {}, r.get("mn") or {}
        h.append("<h2>%s</h2><div class='rangee'>" % html.escape(r["nom"]))
        h.append("<figure><img src='%s' alt='illustration'><figcaption>L'illustration (%s)</figcaption></figure>"
                 % (r["ill"], html.escape(r["illustration"])))
        h.append("<figure><img src='%s' alt='sans'><figcaption>Le jeu sans, 1:1</figcaption></figure>" % r["sans"])
        h.append("<figure><img src='%s' alt='avec'><figcaption>Le jeu avec, 1:1</figcaption></figure>" % r["avec"])
        h.append("<figure><img src='%s' alt='sans x3'><figcaption>Sans, ×3</figcaption></figure>" % r["sans3"])
        h.append("<figure><img src='%s' alt='avec x3'><figcaption>Avec, ×3</figcaption></figure>" % r["avec3"])
        h.append("<figure><img src='%s' alt='torches éteintes'><figcaption>Avec, torches éteintes, 1:1</figcaption>"
                 "</figure>" % r["noir"])
        if r.get("tous"):
            h.append("<figure><img src='%s' alt='tous'><figcaption>Avec tous les essais de la nuit, 1:1</figcaption>"
                     "</figure>" % r["tous"])
        h.append("</div>")
        clair = m.get("plus_clairs_lum_px", -1) == 0 and mn.get("plus_clairs_lum_px", -1) == 0
        noir = mn.get("noirs_allumes_strict_px", -1) == 0 and m.get("emprise_sur_noir_allumes_px", -1) == 0
        h.append("<table><tr><th>mesure</th><th>torches allumées</th><th>torches éteintes</th></tr>")
        for cle, nom in (("emprise_px", "emprise à l'écran (px)"), ("emprise_eclairee_px", "dont sur une face éclairée"),
                         ("emprise_sur_noir_px", "dont sur un pixel noir (A et A2)"),
                         ("changes_px", "pixels changés par l'essai"),
                         ("changes_hors_emprise_px", "dont hors de l'emprise"),
                         ("plus_clairs_lum_px", "plus clairs que sans (luminance +0,5)"),
                         ("plus_clairs_canal2_px", "un canal +2 (pour mémoire)"),
                         ("noirs_allumes_strict_px", "noirs allumés (0 → plus, A = A2 = 0)"),
                         ("noirs_allumes_seuil_px", "noirs allumés (seuil 7,5/255)"),
                         ("rapport_B_sur_A_median", "clarté avec / sans, sur l'emprise éclairée (médiane)"),
                         ("rapport_B_sur_A_max", "idem, maximum"),
                         ("bruit_A_A2_px", "bruit : A contre A2")):
            h.append("<tr><td>%s</td><td>%s</td><td>%s</td></tr>" % (nom, chiffre(m, cle), chiffre(mn, cle)))
        h.append("</table><p>%s · %s</p>" % (
            "<span class='ok'>jamais plus clair que sans</span>" if clair else "<span class='ko'>plus clair par endroits</span>",
            "<span class='ok'>noir resté noir</span>" if noir else "<span class='ko'>du noir allumé</span>"))
    v = p["vues"]
    sym = mesures["seul"].get("sym") or {}
    h.append("<h2>La symétrie J1 / J2 à 45° B</h2><p class='doux'>Écran scindé : J1 devant un faisceau, J2 à son image par le "
             "demi-tour, sa caméra à 225°. À droite, l'emprise des murs meublés en blanc : les deux moitiés doivent "
             "coïncider.</p><div class='rangee'>")
    for cle, nom in (("sym", "l'écran scindé, avec"), ("sym_m", "l'emprise")):
        if v.get(cle):
            h.append("<figure class='large'><img src='%s' alt=''><figcaption>%s</figcaption></figure>" % (v[cle], nom))
    h.append("</div><table><tr><th>mesure</th><th>valeur</th></tr>")
    for cle, nom in (("emprise_J1_px", "emprise, moitié de J1"), ("emprise_J2_px", "emprise, moitié de J2"),
                     ("xor_px", "pixels d'une seule moitié"), ("xor_recale_px", "idem, au meilleur recalage ±3 px"),
                     ("recalage_dx", "recalage x"), ("recalage_dy", "recalage y"),
                     ("lum_moy_emprise_J1", "luminance moyenne sur l'emprise, J1"),
                     ("lum_moy_emprise_J2", "idem, J2")):
        h.append("<tr><td>%s</td><td>%s</td></tr>" % (nom, chiffre(sym, cle)))
    h.append("</table>")
    h.append("<h2>La vue d'ensemble</h2><div class='rangee'>")
    for cle, nom in (("seul__a", "le jeu par défaut (l'essai caché)"), ("seul__b", "les murs meublés seuls"),
                     ("tous__a", "tous les essais de la nuit, sans les murs meublés"),
                     ("tous__b", "tous les essais de la nuit ET les murs meublés")):
        if v.get(cle):
            h.append("<figure class='large'><img src='%s' alt=''><figcaption>%s</figcaption></figure>" % (v[cle], nom))
    h.append("</div></main></body></html>")
    open(os.path.join(ICI, "planche.html"), "w").write("\n".join(h))
    print("planche.html écrite")


if __name__ == "__main__":
    main()
