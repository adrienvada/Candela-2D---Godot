#!/usr/bin/env python3
"""LA PLANCHE DU RAYON DANS L'AIR (Q41, session cloud « faisceau-air », 2026-09-28).

Recopie dans <dossier> (docs/iso/cloud/faisceau-air) les neuf illustrations à faisceau (réduites, JPEG) et, pour chaque
lacet, les images de `preuve.py` ; écrit `planche.html`, autonome, images en chemins relatifs.

    python3 tools/faisceau_air/planche.py <dossier> "<étiquette>=<sortie de preuve.py>" [...]

Les textes de la planche sont dans `TEXTES` (json à côté du dossier, facultatif : `planche_textes.json`)."""
import html, json, os, shutil, sys
from PIL import Image

DOSSIER = sys.argv[1]
LACETS = [a.split("=", 1) for a in sys.argv[2:]]
ILLUS = ["accueil", "amical", "amical_ligne", "competitif", "creer_local", "ecran_scinde", "intro_allumage",
         "intro_dotation", "intro_prix"]
RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
os.makedirs(os.path.join(DOSSIER, "img"), exist_ok=True)
textes = {}
tj = os.path.join(DOSSIER, "planche_textes.json")
if os.path.exists(tj):
    textes = json.load(open(tj, encoding="utf-8"))


def ill(nom):
    dst = os.path.join(DOSSIER, "img", "ill_%s.jpg" % nom)
    if not os.path.exists(dst):
        im = Image.open(os.path.join(RACINE, "assets", "ui", "ill_%s.png" % nom)).convert("RGB")
        im.thumbnail((1024, 640))
        im.save(dst, quality=85)
    return "img/ill_%s.jpg" % nom


def img(src_dir, nom, etiq):
    src = os.path.join(src_dir, nom)
    if not os.path.exists(src):
        return None
    # Un nom de fichier sûr dans une URL : l'étiquette (« 45° B ») réduite à ses lettres et chiffres.
    sur = "".join(ch for ch in etiq if ch.isalnum())
    dst = os.path.join(DOSSIER, "img", "%s_%s" % (sur, nom))
    shutil.copyfile(src, dst)
    return "img/%s_%s" % (sur, nom)


def fig(src, legende, classe=""):
    if src is None:
        return ""
    return '<figure class="%s"><a href="%s"><img src="%s" alt="%s" loading="lazy"></a><figcaption>%s</figcaption></figure>' % (
        classe, src, src, html.escape(legende), legende)


h = []
h.append("""<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Faisceau dans l'air</title><style>
:root{--fond:#111;--texte:#e8e4dc;--trait:#333;--doux:#9a958c;--accent:#f0b35a}
@media (prefers-color-scheme: light){:root:not([data-theme="dark"]){--fond:#f6f4ef;--texte:#1c1b19;--trait:#d6d2c8;--doux:#6b675f;--accent:#a8661b}}
body{background:var(--fond);color:var(--texte);font:15px/1.5 system-ui,sans-serif;margin:0 auto;max-width:1400px;padding:16px}
h1{font-size:1.5em}h2{margin-top:2em;border-bottom:1px solid var(--trait);padding-bottom:.2em}
.grille{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:12px}
.deux{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:12px}
figure{margin:0}figure img{width:100%;height:auto;display:block;border:1px solid var(--trait);border-radius:4px;background:#000}
.loupe img{image-rendering:pixelated}figcaption{color:var(--doux);font-size:.9em;margin-top:4px}
table{border-collapse:collapse;font-size:.9em;margin:8px 0;display:block;overflow-x:auto}
td,th{border:1px solid var(--trait);padding:3px 8px;text-align:right}th{text-align:center}td:first-child{text-align:left}
.ok{color:#4caf50}.ko{color:#e53935}p.note{color:var(--doux)}
</style></head><body>""")
h.append("<h1>Le faisceau dans l'air (Q41) — à l'image</h1>")
h.append(textes.get("intro", ""))
h.append("<h2>Les neuf illustrations à faisceau</h2><div class='grille'>")
for n in ILLUS:
    h.append(fig(ill(n), "ill_%s" % n))
h.append("</div>")
for etiq, src in LACETS:
    m = json.load(open(os.path.join(src, "%smesures.json" % ""), encoding="utf-8")) if os.path.exists(
        os.path.join(src, "mesures.json")) else {}
    h.append("<h2>%s</h2>" % html.escape(etiq))
    h.append(textes.get("lacet_" + etiq, ""))
    h.append("<table><tr><th>bloc</th><th>prise</th><th>pixels noirs (A)</th><th>fuite</th><th>B−A médiane</th><th>p90</th>"
             "<th>max</th><th>cœur du cône : B−A</th><th>bord du cône : B−A</th><th>max rayon / max sol</th></tr>")
    for bloc, r in m.items():
        for b, pr in r["prises"].items():
            mil = "%s (sol %s)" % (pr["coeur"]["B-A"], pr["coeur"]["A"]) if "coeur" in pr else "—"
            bord = "%s (sol %s)" % (pr["bord_image"]["B-A"], pr["bord_image"]["A"]) if "bord_image" in pr else "—"
            h.append("<tr><td>%s</td><td>%s</td><td>%d</td><td class='%s'>%d</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td>"
                     "<td>%s</td><td>%s / %s</td></tr>" % (bloc, b, r["pixels_noirs_A"], "ok" if pr["fuite"] == 0 else "ko",
                     pr["fuite"], pr.get("gain_median", "—"), pr.get("gain_p90", "—"), pr.get("gain_max", "—"), mil, bord,
                     pr.get("max_B_rayon", "—"), pr.get("max_A_cone", "—")))
    h.append("</table>")
    for bloc, titre in [("adv", "Le rayon ADVERSE vu de J1 (lampe de J2 seule, J1 lampe éteinte)"),
                        ("sien", "Son propre rayon (lampe de J1 seule, voile d'éblouissement compris)"),
                        ("s1", "Écran scindé, la lampe de J1 seule (J1 à gauche, J2 à droite)"),
                        ("s2", "Écran scindé, la lampe de J2 seule"),
                        ("eq-est", "Équité : J2 derrière le pilier, lampe vers l'est — ce que voit J1"),
                        ("eq-sud-ouest", "Équité : J2 derrière le pilier, lampe vers le sud-ouest — ce que voit J1")]:
        if bloc not in m:
            continue
        h.append("<h3>%s</h3>" % titre)
        h.append(textes.get("%s_%s" % (etiq, bloc), ""))
        h.append("<div class='deux'>")
        h.append(fig(img(src, "%s_a.jpg" % bloc, etiq), "sans le rayon (A)"))
        h.append(fig(img(src, "%s_b.jpg" % bloc, etiq), "avec le rayon (B, densité par défaut)"))
        h.append(fig(img(src, "%s_b_diffx8.jpg" % bloc, etiq), "B − A, ×8 : ce que le rayon change"))
        h.append(fig(img(src, "%s_b_noir.jpg" % bloc, etiq), "le noir : rouge = un pixel noir dans toutes les A que B allume ; "
                     "gris = non noir dans les A ; bleu = instable"))
        for j in [1, 2]:
            for v in [0, 1]:
                a = img(src, "%s_a_loupe_J%d_v%d.jpg" % (bloc, j, v), etiq)
                b = img(src, "%s_b_loupe_J%d_v%d.jpg" % (bloc, j, v), etiq)
                if a and b:
                    h.append(fig(a, "loupe ×3, milieu du cône de J%d, vue %d — sans" % (j, v + 1), "loupe"))
                    h.append(fig(b, "loupe ×3, même endroit — avec", "loupe"))
        for d in (["b15", "b30", "b45", "b80"] if bloc == "adv" else []):
            x = img(src, "%s_%s.jpg" % (bloc, d), etiq)
            if x:
                h.append(fig(x, "densité 0,%s" % d[1:]))
        h.append("</div>")
h.append(textes.get("fin", ""))
h.append("</body></html>")
open(os.path.join(DOSSIER, "planche.html"), "w", encoding="utf-8").write("\n".join(h))
print("planche écrite :", os.path.join(DOSSIER, "planche.html"))
