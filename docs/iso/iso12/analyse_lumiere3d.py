"""ISO12, lot 0 — l'analyse du banc de la lumière 3D bridée.

Usage : python3 analyse_lumiere3d.py JOURNAL_DU_BANC DOSSIER_DES_CAPTURES DOSSIER_DE_SORTIE

1. **Relevés** : un tableau des lignes `BANC_LUMIERE3D prise=…` (médiane, 1 % bas, pire image, appels, lumières 3D).
2. **Preuve** « ni plus ni moins que la 2D » (session cloud, 22:15 puis 22:48), pour chaque visée et chaque réglage de la
   rétrodiffusion, sur la paire prise normale / prise masque (blanc là où L2D > 0), tous les pixels, PIL seul :
   - ROUGE, une VIOLATION : lumineux dans la normale (luminance > SEUIL_LUMINEUX) alors que le masque est noir. Il en faut 0.
     La ligne de séparation de l'écran scindé (±4 px au centre) est comptée à part, jamais retirée en silence.
   - BLEU, un MANQUE : éclairé en 2D (masque blanc) et noir dans la normale (luminance ≤ SEUIL_NOIR). Il en faut moins de
     1 % des pixels éclairés en 2D. Les prises à rétrodiffusion coupée montrent ce qu'elle répare.
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
paires = {}
for p in preuves:
    cle = (p["carte"], p["visee"], p.get("retro", "1"))
    paires.setdefault(cle, {})[p["masque"]] = p["fichier"]
rouges_total = 0
manques = []
print("\nPREUVE — ROUGE : lumineux hors du masque L2D > 0 ; BLEU : éclairé en 2D, noir en 3D")
for (carte, visee, retro), fichiers in sorted(paires.items()):
    etiquette = "%s visée %s, rétrodiffusion %s" % (carte, visee, "oui" if retro == "1" else "non")
    if "0" not in fichiers or "1" not in fichiers:
        print("  %s : paire incomplète" % etiquette)
        continue
    normale = Image.open(os.path.join(captures, fichiers["0"])).convert("RGB")
    masque = Image.open(os.path.join(captures, fichiers["1"])).convert("L")
    fichier_ref = references.get((carte, visee))
    reference = Image.open(os.path.join(captures, fichier_ref)).convert("RGB") if fichier_ref else None
    w, h = normale.size
    pn = normale.load()
    pm = masque.load()
    pr = reference.load() if reference is not None else None
    rouges = separation = eclaires = bleus = 0
    for y in range(h):
        for x in range(w):
            lum = luminance(pn[x, y])
            visible_2d = pr is not None and luminance(pr[x, y]) > SEUIL_VISIBLE
            if pm[x, y] < SEUIL_MASQUE and not visible_2d:
                if lum > SEUIL_LUMINEUX:
                    if abs(x - w // 2) <= 4:
                        separation += 1
                    else:
                        rouges += 1
            elif visible_2d if pr is not None else pm[x, y] >= SEUIL_MASQUE:
                eclaires += 1
                if lum <= SEUIL_NOIR:
                    bleus += 1
    rouges_total += rouges
    part = 100.0 * bleus / eclaires if eclaires else 0.0
    manques.append((part, etiquette, retro))
    print("  %s : ROUGE %d (%d sur la séparation) ; BLEU %d sur %d px éclairés en 2D = %.2f %% %s"
          % (etiquette, rouges, separation, bleus, eclaires, part, "OK" if part < 1.0 else "AU-DESSUS DE 1 %"))
print("MESURE preuve : %d violation(s) rouges au total" % rouges_total)
for retro in ("1", "0"):
    parts = [m for m in manques if m[2] == retro]
    if parts:
        pire = max(parts)
        print("MESURE preuve inverse, rétrodiffusion %s : pire manque %.2f %% (%s)"
              % ("oui" if retro == "1" else "non", pire[0], pire[1]))

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
print("\nrecadrages dans", sortie)
