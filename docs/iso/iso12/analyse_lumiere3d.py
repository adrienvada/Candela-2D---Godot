"""ISO12, lot 0 — l'analyse du banc de la lumière 3D bridée.

Usage : python3 analyse_lumiere3d.py JOURNAL_DU_BANC DOSSIER_DES_CAPTURES DOSSIER_DE_SORTIE

1. **Relevés** : un tableau des lignes `BANC_LUMIERE3D prise=…` (médiane, 1 % bas, pire image, appels, lumières 3D).
2. **Preuve** « ni plus ni moins que la 2D » (session cloud, 22:15, 22:48, puis 00:25), pour chaque visée, chaque bride et
   chaque réglage de la rétrodiffusion, sur la paire prise normale / prise masque (blanc là où L2D > 0), tous les pixels,
   PIL seul :
   - ROUGE, une VIOLATION : lumineux dans la normale (luminance > SEUIL_LUMINEUX) alors que le masque est noir. Il en faut 0.
     La ligne de séparation de l'écran scindé (±4 px au centre) est comptée à part, jamais retirée en silence.
   - BLEU, un MANQUE : éclairé en 2D (masque blanc) et noir dans la normale (luminance ≤ SEUIL_NOIR). Il en faut moins de
     1 % des pixels éclairés en 2D. Les prises à rétrodiffusion coupée montrent ce qu'elle répare.
   - **INTENSITÉ** (lot 0 ter) : le support ne suffit pas, la 3D montrait PLUS que la 2D là où elle montrait le même
     support. Les deux luminances normalisées sur leur maximum du cadrage : les pixels où la 3D dépasse 1,5 fois la 2D
     doivent rester sous 1 % des pixels éclairés en 2D, et le rapport des moyennes dans la zone éclairée en 2D doit valoir
     1,0 ± 0,1. Ce rapport est aussi le réglage de la bride identité.
   - **L'ENCRE hors du compte bleu**, mesurée et non décrétée, et EN DEUX NIVEAUX : la référence 2D est reprise une fois
     `MurEncre` caché (le liseré du pied des faces), une fois `MurEncre` ET le décor cachés. Un pixel est de l'encre là où
     les références diffèrent. Le second niveau est un MAJORANT — le décor porte le hachurage des murets, mais aussi les
     marquages de l'arène. Le bleu sans aucune exclusion est imprimé à côté : rien ne disparaît dans un masque.
3. **Silhouette de soi** : dans la capture `…_silhouette`, la luminance moyenne d'un carré de 40 px autour de J1 dans sa
   vue (`j1`) et dans celle de J2 (`j1_vue2`) : la première doit dépasser la seconde.
4. **Recadrages de la loupe** : 800×450 autour de chaque ancre, pour la planche.
"""
import json
import os
import re
import sys

from PIL import Image

journal, captures, sortie = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(sortie, exist_ok=True)
SEUIL_LUMINEUX = 6
SEUIL_MASQUE = 2
SEUIL_NOIR = 2
## Un pixel est VISIBLE dans la référence 2D au-dessus de cette luminance (sur 255) : la frange que la 2D laisse noire à l'œil
## ne compte pas comme un manque.
SEUIL_VISIBLE = 8
## Un pixel est de l'ENCRE là où la référence 2D et la référence sans encre diffèrent d'au moins autant (sur 255).
SEUIL_ENCRE = 4
## Le seuil d'intensité : la 3D normalisée ne doit pas dépasser ce multiple de la 2D normalisée (session cloud, 00:25).
FACTEUR_INTENSITE = 1.5
lignes = open(journal, encoding="utf-8", errors="replace").read().splitlines()


def champs(ligne):
    d = {}
    tete = ligne.split(" ancres=")[0]
    for m in re.finditer(r"(\w+)=(\S+)", tete):
        d[m.group(1)] = m.group(2)
    a = ligne.find(" ancres=")
    if a >= 0:
        try:
            d["ancres"] = json.loads(ligne[a + len(" ancres="):])
        except json.JSONDecodeError:
            d["ancres"] = {}
    return d


def luminance(px):
    r, g, b = px[:3]
    return (299 * r + 587 * g + 114 * b) // 1000


# --- 1. relevés ---
prises = [champs(l) for l in lignes if l.startswith("BANC_LUMIERE3D prise=")]
print("RELEVÉS")
print("%-78s %6s %6s %6s %6s %7s %4s" % ("prise", "méd", "1%bas", "pire", "appels", "gpu_ms", "lum"))
for p in prises:
    print("%-78s %6s %6s %6s %6s %7s %4s" % (p.get("prise", "?"), p.get("fps_median", "?"), p.get("fps_1pc_bas", "?"),
                                              p.get("pire_ms", "?"), p.get("appels", "?"), p.get("gpu_ms", "?"),
                                              p.get("lumieres3d", "?")))

# --- 2. preuve, dans les deux sens ---
preuves = [champs(l) for l in lignes if l.startswith("BANC_LUMIERE3D preuve ")]
references = {}
for p in (champs(l) for l in lignes if l.startswith("BANC_LUMIERE3D preuve_reference ")):
    references[(p["carte"], p["visee"])] = p["fichier"]
# La seconde référence 2D, calques d'encre cachés : elle DÉFINIT le masque d'encre, elle ne le suppose pas.
encres = {}
for p in (champs(l) for l in lignes if l.startswith("BANC_LUMIERE3D preuve_encre ")):
    encres[(p["carte"], p["visee"])] = p["fichier"]
# Le second niveau : `MurEncre` ET le décor cachés. Majorant de l'encre, jamais l'encre.
decors = {}
for p in (champs(l) for l in lignes if l.startswith("BANC_LUMIERE3D preuve_decor ")):
    decors[(p["carte"], p["visee"])] = p["fichier"]
paires = {}
for p in preuves:
    cle = (p["carte"], p["visee"], p.get("retro", "1"), p.get("bride", "005"))
    paires.setdefault(cle, {})[p["masque"]] = p["fichier"]
rouges_total = 0
manques = []
intensites = []
rouges_ou = []
print("\nPREUVE — ROUGE : lumineux hors du masque L2D > 0 ; BLEU : éclairé en 2D, noir en 3D ; INTENSITÉ : 3D / 2D normalisées")
for (carte, visee, retro, bride), fichiers in sorted(paires.items()):
    etiquette = "%s visée %s, bride %s, rétrodiffusion %s" % (carte, visee, bride, "oui" if retro == "1" else "non")
    if "0" not in fichiers or "1" not in fichiers:
        print("  %s : paire incomplète" % etiquette)
        continue
    normale = Image.open(os.path.join(captures, fichiers["0"])).convert("RGB")
    masque = Image.open(os.path.join(captures, fichiers["1"])).convert("L")
    fichier_ref = references.get((carte, visee))
    reference = Image.open(os.path.join(captures, fichier_ref)).convert("RGB") if fichier_ref else None
    fichier_encre = encres.get((carte, visee))
    sans_encre = Image.open(os.path.join(captures, fichier_encre)).convert("RGB") if fichier_encre else None
    fichier_decor = decors.get((carte, visee))
    sans_decor = Image.open(os.path.join(captures, fichier_decor)).convert("RGB") if fichier_decor else None
    w, h = normale.size
    pn = normale.load()
    pm = masque.load()
    pr = reference.load() if reference is not None else None
    pe = sans_encre.load() if sans_encre is not None else None
    pd = sans_decor.load() if sans_decor is not None else None
    # Le maximum du cadrage, pour normaliser les deux luminances : `convert("L")` applique les mêmes poids 601-1 que
    # `luminance()`, donc les deux échelles sont comparables.
    max3d = max(1, normale.convert("L").getextrema()[1])
    max2d = max(1, reference.convert("L").getextrema()[1]) if reference is not None else 1
    rouges = separation = eclaires = bleus = bleus_encre = bleus_decor = intenses = 0
    somme3 = somme2 = 0.0
    positions = []
    for y in range(h):
        for x in range(w):
            lum = luminance(pn[x, y])
            lum2d = luminance(pr[x, y]) if pr is not None else 0
            visible_2d = pr is not None and lum2d > SEUIL_VISIBLE
            if pm[x, y] < SEUIL_MASQUE and not visible_2d:
                if lum > SEUIL_LUMINEUX:
                    if abs(x - w // 2) <= 4:
                        separation += 1
                    else:
                        rouges += 1
                        if len(positions) < 400:
                            positions.append((x, y, lum))
            elif visible_2d if pr is not None else pm[x, y] >= SEUIL_MASQUE:
                eclaires += 1
                if lum <= SEUIL_NOIR:
                    # L'encre : la référence et la référence sans encre diffèrent ici, donc ce pixel est un DESSIN et non
                    # une lumière. Deux niveaux, comptés à part, jamais retirés en silence.
                    bleus += 1
                    if pe is not None and abs(lum2d - luminance(pe[x, y])) >= SEUIL_ENCRE:
                        bleus_encre += 1
                    elif pd is not None and abs(lum2d - luminance(pd[x, y])) >= SEUIL_ENCRE:
                        bleus_decor += 1
                n3 = lum / max3d
                n2 = lum2d / max2d
                somme3 += n3
                somme2 += n2
                if n3 > FACTEUR_INTENSITE * n2:
                    intenses += 1
    rouges_total += rouges
    if positions:
        rouges_ou.append((etiquette, positions))
    part = 100.0 * bleus / eclaires if eclaires else 0.0
    part_hors_encre = 100.0 * (bleus - bleus_encre - bleus_decor) / eclaires if eclaires else 0.0
    part_encre = 100.0 * bleus_encre / eclaires if eclaires else 0.0
    part_decor = 100.0 * bleus_decor / eclaires if eclaires else 0.0
    part_intense = 100.0 * intenses / eclaires if eclaires else 0.0
    rapport = (somme3 / somme2) if somme2 > 0.0 else 0.0
    manques.append((part_hors_encre, etiquette, retro))
    intensites.append((part_intense, rapport, etiquette))
    print("  %s :\n    ROUGE %d (%d sur la séparation) ; BLEU %d = %.2f %% en tout ; hors encre %.2f %% %s"
          % (etiquette, rouges, separation, bleus, part, part_hors_encre,
             "OK" if part_hors_encre < 1.0 else "AU-DESSUS DE 1 %"))
    print("    dont liseré %d = %.2f %%, décor %d = %.2f %% (majorant) sur %d px éclairés"
          % (bleus_encre, part_encre, bleus_decor, part_decor, eclaires))
    print("    INTENSITÉ : %d px au-dessus de %.1f× = %.2f %% %s ; rapport moyen 3D/2D %.2f %s"
          % (intenses, FACTEUR_INTENSITE, part_intense, "OK" if part_intense < 1.0 else "AU-DESSUS DE 1 %",
             rapport, "OK" if abs(rapport - 1.0) <= 0.1 else "HORS DE 1,0 ± 0,1"))
print("MESURE preuve : %d violation(s) rouges au total" % rouges_total)
for retro in ("1", "0"):
    parts = [m for m in manques if m[2] == retro]
    if parts:
        pire = max(parts)
        print("MESURE preuve inverse (hors encre), rétrodiffusion %s : pire manque %.2f %% (%s)"
              % ("oui" if retro == "1" else "non", pire[0], pire[1]))
if intensites:
    pire_part = max(intensites)
    pire_rapport = max(intensites, key=lambda t: abs(t[1] - 1.0))
    print("MESURE intensité : pire part au-dessus de %.1f× = %.2f %% (%s)" % (FACTEUR_INTENSITE, pire_part[0], pire_part[2]))
    print("MESURE intensité : pire rapport moyen 3D/2D = %.2f (%s)" % (pire_rapport[1], pire_rapport[2]))
# Le rouge, PIXEL PAR PIXEL : « 87 pixels ne sont pas zéro ; trouve-les » (session cloud, 00:25).
for etiquette, positions in rouges_ou:
    xs = [p[0] for p in positions]
    ys = [p[1] for p in positions]
    print("ROUGE OÙ %s : %d px, x de %d à %d, y de %d à %d, luminance jusqu'à %d ; premiers %s"
          % (etiquette, len(positions), min(xs), max(xs), min(ys), max(ys), max(p[2] for p in positions),
             ", ".join("(%d,%d,%d)" % p for p in positions[:12])))

# --- 3. silhouette ---
print("\nSILHOUETTE DE SOI")
for p in (champs(l) for l in lignes if l.startswith("BANC_LUMIERE3D silhouette ")):
    img = Image.open(os.path.join(captures, p["fichier"])).convert("RGB")
    pi = img.load()
    a = p.get("ancres", {})

    def moyenne(xy):
        x0, y0 = xy
        s = n = 0
        for y in range(max(0, y0 - 20), min(img.size[1], y0 + 20)):
            for x in range(max(0, x0 - 20), min(img.size[0], x0 + 20)):
                s += luminance(pi[x, y])
                n += 1
        return s / max(n, 1)

    if "j1" in a and "j1_vue2" in a:
        sienne, autre = moyenne(a["j1"]), moyenne(a["j1_vue2"])
        print("  %s : J1 dans sa vue %.1f, dans celle de J2 %.1f → %s"
              % (p["carte"], sienne, autre, "OK" if sienne > autre + 2 else "À VOIR"))

# --- 4. recadrages ---
L, H = 800, 450
for p in prises:
    fichier = p.get("fichier", "")
    chemin = os.path.join(captures, fichier)
    if not fichier or not os.path.exists(chemin):
        continue
    img = Image.open(chemin).convert("RGB")
    for nom, xy in p.get("ancres", {}).items():
        x0 = min(max(0, xy[0] - L // 2), img.size[0] - L)
        y0 = min(max(0, xy[1] - H // 2), img.size[1] - H)
        img.crop((x0, y0, x0 + L, y0 + H)).save(os.path.join(sortie, "%s__%s.png" % (p["prise"], nom)))
        # ISO12 lot 0 ter — la colonne ×4 au plus proche voisin sur le CORPS : c'est là que se juge « l'adversaire dans mon
        # cône », et un corps de 60 px ne se juge pas à l'échelle de la planche (session cloud, 00:25).
        if nom.startswith("j1") or nom.startswith("j2"):
            l4, h4 = L // 4, H // 4
            a = min(max(0, xy[0] - l4 // 2), img.size[0] - l4)
            b = min(max(0, xy[1] - h4 // 2), img.size[1] - h4)
            img.crop((a, b, a + l4, b + h4)).resize((L, H), Image.NEAREST) \
                .save(os.path.join(sortie, "%s__%s_x4.png" % (p["prise"], nom)))
print("\nrecadrages dans", sortie)
