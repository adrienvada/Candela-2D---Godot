#!/usr/bin/env python3
"""LA PLANCHE DU MASQUE DE LA FUMÉE ET DE SES FORMES (session cloud « masque-fumée », 2026-09-27).

À partir des prises du plan `loupe-fusee-masque-formes` (un ou plusieurs lancements), écrit dans <sortie> des JPEG
(qualité 85) recadrés autour de la fusée, et `planche.html` qui les montre :
  - le NOIR SALI : pour la fumée sans masque (B), le masque de Gadgets (C) et chaque forme (C1 à C3), la carte des pixels
    noirs dans A (torches éteintes, fumée coupée) — ROUGE s'ils sont allumés par la fumée, gris foncé s'ils restent noirs,
    et le sol éclairé en gris clair ;
  - la FUMÉE ÉCLAIRÉE : la prise elle-même (gain ×3 pour voir les bas niveaux), et l'écart au masque de Gadgets au pixel
    (MAGENTA : un pixel qui diffère).

    python3 tools/masque_fumee/planche.py <sortie> <nom>=<dossier des prises> [<nom>=<dossier> …]

Pillow requis."""
import glob, html, os, re, sys
from PIL import Image

SORTIE = sys.argv[1]
os.makedirs(SORTIE, exist_ok=True)
ID = "loupe-fusee-masque-formes"
BOITE = (1000, 130, 1920, 730)
FORMES = [("b", "Fumée sans masque (le jeu par défaut)"), ("c", "Masque de Gadgets (--fumee-masque)"),
          ("c1", "Forme compacte (--fumee-masque-compact)"), ("c2", "Bande resserrée (--fumee-masque-resserre)"),
          ("c3", "Pochoir (--fumee-masque-pochoir)"),
          # Session cloud « masque-fumée-2 » (2026-09-28), quand le plan les a prises.
          ("c4", "V4, la lumière d'abord (--fumee-masque-lumiere)"), ("c5", "V5, le juge ajusté (--fumee-masque-ajuste)")]


def charger(dossier, k):
    tout = glob.glob(os.path.join(dossier, "*%s-%s.png" % (ID, k)))
    return Image.open(tout[0]).convert("RGB") if tout else None


def carte_noir(a, x, boite):
    a, x = a.crop(boite), x.crop(boite)
    out = Image.new("RGB", a.size)
    pa, px, po = a.load(), x.load(), out.load()
    rouges = 0
    for j in range(a.size[1]):
        for i in range(a.size[0]):
            if max(pa[i, j]) == 0:
                if max(px[i, j]) > 0:
                    po[i, j] = (255, 30, 30)
                    rouges += 1
                else:
                    po[i, j] = (25, 25, 25)
            else:
                g = 90 + min(120, max(pa[i, j]))
                po[i, j] = (g, g, g)
    return out, rouges


def gain(x, boite, k=3):
    return x.crop(boite).point(lambda v: min(255, v * k))


def ecart(c, x, boite):
    c, x = c.crop(boite), x.crop(boite)
    out = x.point(lambda v: v // 3)
    pc, px, po = c.load(), x.load(), out.load()
    n = 0
    for j in range(c.size[1]):
        for i in range(c.size[0]):
            if pc[i, j] != px[i, j]:
                po[i, j] = (255, 0, 255)
                n += 1
    return out, n


sections = []
for paire in sys.argv[2:]:
    nom, dossier = paire.split("=", 1)
    fichier = re.sub(r"[^A-Za-z0-9]", "", nom) or "prises"   # le titre peut porter « 45° B », pas un nom de fichier
    a = charger(dossier, "a")
    if a is None:
        sys.exit("✗ %s : aucune prise A dans %s" % (nom, dossier))
    c = charger(dossier, "c")
    lignes = []
    for k, titre in FORMES:
        x = charger(dossier, k)
        if x is None:
            continue
        carte, rouges = carte_noir(a, x, BOITE)
        f1 = "%s_%s_noir.jpg" % (fichier, k)
        carte.save(os.path.join(SORTIE, f1), quality=85)
        f2 = "%s_%s_image.jpg" % (fichier, k)
        gain(x, BOITE).save(os.path.join(SORTIE, f2), quality=85)
        cellule3, n = "", 0
        if k not in ("b", "c") and c is not None:
            e, n = ecart(c, x, BOITE)
            f3 = "%s_%s_ecart.jpg" % (fichier, k)
            e.save(os.path.join(SORTIE, f3), quality=85)
            cellule3 = '<figure><img src="%s"><figcaption>écart au masque de Gadgets : %d pixels (magenta)</figcaption></figure>' % (f3, n)
        lignes.append('<h3>%s</h3><div class="rang"><figure><img src="%s"><figcaption>noir sali : %d pixels rouges</figcaption>'
                      '</figure><figure><img src="%s"><figcaption>l\'image (gain ×3)</figcaption></figure>%s</div>'
                      % (html.escape(titre), f1, rouges, f2, cellule3))
    # L'écran scindé, s'il a été pris : J1 à gauche, J2 à droite, le pochoir contre A.
    sa, s3, sb = charger(dossier, "s-a"), charger(dossier, "s-c3"), charger(dossier, "s-b")
    if sa is not None and s3 is not None:
        for k, img, titre in (("s-b", sb, "Écran scindé, fumée sans masque"), ("s-c3", s3, "Écran scindé, pochoir"),
                              ("s-c4", charger(dossier, "s-c4"), "Écran scindé, V4"),
                              ("s-c5", charger(dossier, "s-c5"), "Écran scindé, V5")):
            if img is None:
                continue
            carte, rouges = carte_noir(sa, img, (0, 0, sa.size[0], sa.size[1]))
            f = "%s_%s_noir.jpg" % (fichier, k)
            carte.resize((sa.size[0] // 2, sa.size[1] // 2)).save(os.path.join(SORTIE, f), quality=85)
            lignes.append('<h3>%s (J1 à gauche, J2 à droite)</h3><div class="rang"><figure class="large"><img src="%s">'
                          '<figcaption>noir sali : %d pixels rouges</figcaption></figure></div>' % (titre, f, rouges))
    # La vue unique de J2 (session « masque-fumée-2 ») : J2 à l'abri d'un mur, non ébloui ; image entière, réduite de moitié.
    ja, jc = charger(dossier, "j2-a"), charger(dossier, "j2-c")
    if ja is not None and jc is not None:
        tout = (0, 0, ja.size[0], ja.size[1])
        for k, titre in (("j2-b", "Vue unique de J2, fumée sans masque"), ("j2-c", "Vue unique de J2, masque de Gadgets"),
                         ("j2-c3", "Vue unique de J2, pochoir"), ("j2-c4", "Vue unique de J2, V4"),
                         ("j2-c5", "Vue unique de J2, V5")):
            x = charger(dossier, k)
            if x is None:
                continue
            carte, rouges = carte_noir(ja, x, tout)
            f1 = "%s_%s_noir.jpg" % (fichier, k)
            carte.resize((ja.size[0] // 2, ja.size[1] // 2)).save(os.path.join(SORTIE, f1), quality=85)
            f2 = "%s_%s_image.jpg" % (fichier, k)
            gain(x, tout).resize((ja.size[0] // 2, ja.size[1] // 2)).save(os.path.join(SORTIE, f2), quality=85)
            cellule3 = ""
            if k not in ("j2-b", "j2-c"):
                e, n = ecart(jc, x, tout)
                f3 = "%s_%s_ecart.jpg" % (fichier, k)
                e.resize((ja.size[0] // 2, ja.size[1] // 2)).save(os.path.join(SORTIE, f3), quality=85)
                cellule3 = '<figure><img src="%s"><figcaption>écart au masque de Gadgets : %d pixels (magenta)</figcaption></figure>' % (f3, n)
            lignes.append('<h3>%s</h3><div class="rang"><figure><img src="%s"><figcaption>noir sali : %d pixels rouges</figcaption>'
                          '</figure><figure><img src="%s"><figcaption>l\'image (gain ×3)</figcaption></figure>%s</div>'
                          % (html.escape(titre), f1, rouges, f2, cellule3))
    sections.append('<section><h2>%s</h2>%s</section>' % (html.escape(nom), "".join(lignes)))

open(os.path.join(SORTIE, "planche.html"), "w").write('''<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Masque de la fumée</title>
<style>
:root { --fond: #111; --texte: #ddd; --doux: #999; }
body { background: var(--fond); color: var(--texte); font: 15px/1.45 system-ui, sans-serif; margin: 0 16px 40px; }
h1 { font-size: 22px; } h2 { margin-top: 36px; border-bottom: 1px solid #333; } h3 { font-size: 15px; margin: 18px 0 6px; }
.rang { display: flex; flex-wrap: wrap; gap: 10px; }
figure { margin: 0; flex: 1 1 280px; max-width: 460px; } figure.large { max-width: 960px; flex-basis: 100%; }
img { width: 100%; height: auto; display: block; border: 1px solid #333; }
figcaption { color: var(--doux); font-size: 13px; }
p { max-width: 900px; }
</style></head><body>
<h1>Le masque de la fumée et ses formes moins chères</h1>
<p>Sessions cloud « masque-fumée » (27/09/2026, formes C1 à C3) et « masque-fumée-2 » (28/09/2026, V4, V5 et la vue
unique de J2, posé à l'abri d'un mur pour n'être pas ébloui). Torches éteintes, la fusée seule, caméra posée, LED figées : A sans fumée,
puis la même fumée sans masque, avec le masque de Gadgets, avec chaque forme. <b>Noir sali</b> : en rouge, les pixels noirs
sans fumée qu'elle allume ; en gris clair, le sol éclairé. <b>Écart</b> : en magenta, les pixels qui diffèrent du masque de
Gadgets (au pied de J1, le corps frémit d'une prise à l'autre : deux prises de Gadgets y diffèrent autant). Rendu logiciel du
cloud : vaut pour le noir et les comptes, pas pour la cadence.</p>
%s
</body></html>
'''.replace("%s", "".join(sections)))
print("planche écrite :", os.path.join(SORTIE, "planche.html"))
