"""ISO12, lot 0 — la planche aux cadrages de la loupe (demande de la session cloud, 23:42).

Usage : python3 planche_lumiere3d.py JOURNAL_DU_BANC DOSSIER_DES_CAPTURES DOSSIER_DE_SORTIE

Pour chaque carte, en VUE UNIQUE : une ligne par cadrage (bord du cône, pied du mur ou pilier, corps de J1, corps de J2, sol,
fusée posée), une colonne par variante (lumière éteinte = référence 2D, 3D sans ombres, 3D avec ombres pâte (a), pâte (b),
pâte (c), contact non, rétrodiffusion non), chaque case un recadrage 800×450 de la capture pleine fenêtre, centré sur l'ancre
que le banc a projetée à l'écran. Puis une ligne ÉCRAN SCINDÉ : la capture entière de la même variante, réduite.
Sorties : les recadrages et les écrans scindés en PNG, OCTET POUR OCTET tels que coupés (pour la galerie), et une planche
réduite par carte pour le coup d'œil. PIL seul.
"""
import json
import os
import re
import sys

from PIL import Image, ImageDraw

journal, captures, sortie = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(sortie, exist_ok=True)

VARIANTES = [
    ("reference2d", "lumière éteinte (2D)", lambda p: p["lumiere"] == "false"),
    ("ombres0", "3D sans ombres", lambda p: p["lumiere"] == "true" and p["ombres"] == "false"),
    ("pate_a", "ombres, pâte (a)", lambda p: p["ombres"] == "true" and p["pate"] == "a" and p["contact"] == "true"
        and p["retro"] == "true" and p["atlas"] == "2048" and p["bride"].startswith("(0.0, 0.05") and _econ(p)),
    ("pate_b", "ombres, pâte (b)", lambda p: p["ombres"] == "true" and p["pate"] == "b" and p["contact"] == "true"
        and p["bride"].startswith("(0.0, 0.05") and _econ(p)),
    ("pate_c", "ombres, pâte (c)", lambda p: p["ombres"] == "true" and p["pate"] == "c" and p["contact"] == "true"
        and p["bride"].startswith("(0.0, 0.05") and _econ(p)),
    ("contact0", "contact non", lambda p: p["ombres"] == "true" and p["pate"] == "a" and p["contact"] == "false"
        and p["bride"].startswith("(0.0, 0.05") and _econ(p)),
    ("retro0", "rétrodiffusion non", lambda p: p.get("retro") == "false"),
]
CADRAGES = [("bord_cone", "bord du cône"), ("pied_mur", "pied du mur / pilier"), ("j1", "corps J1"), ("j2", "corps J2"),
            ("sol", "sol"), ("fusee", "fusée posée")]
L, H = 800, 450
PETIT = (320, 180)


def _econ(p):
    return p.get("omni", "true") == "true" and p.get("torches_seules", "false") == "false" \
        and p.get("ombres_vue_unique", "false") == "false" and p.get("retro", "true") == "true"


def champs(ligne):
    d = {}
    for m in re.finditer(r"(\w+)=(\S+)", ligne.split(" ancres=")[0]):
        d[m.group(1)] = m.group(2)
    # la bride s'écrit « (0.0, 0.05) » : l'expression régulière la coupe à la virgule.
    b = re.search(r"bride=(\([^)]*\))", ligne)
    if b:
        d["bride"] = b.group(1)
    a = ligne.find(" ancres=")
    d["ancres"] = json.loads(ligne[a + len(" ancres="):]) if a >= 0 else {}
    return d


prises = [champs(l) for l in open(journal, encoding="utf-8", errors="replace") if l.startswith("BANC_LUMIERE3D prise=")]
liste = []
for carte in sorted({p["carte"] for p in prises}):
    choix = {}
    for cle, _titre, test in VARIANTES:
        for vue in ("unique", "scinde"):
            for p in prises:
                if p["carte"] == carte and p["vue"] == vue and test(p) and (cle, vue) not in choix:
                    choix[(cle, vue)] = p
    colonnes = len(VARIANTES)
    planche = Image.new("RGB", (colonnes * PETIT[0] + 170, (len(CADRAGES) + 1) * (PETIT[1] + 4) + 40), (12, 11, 10))
    d = ImageDraw.Draw(planche)
    d.text((6, 6), "ISO12 lot 0 — %s, cadrages de la loupe (vue unique), puis l'écran scindé" % carte, fill=(230, 180, 90))
    for c, (cle, titre, _t) in enumerate(VARIANTES):
        d.text((170 + c * PETIT[0] + 4, 24), titre, fill=(200, 200, 200))
    for r, (ancre, nom) in enumerate(CADRAGES + [("__scinde", "écran scindé")]):
        y = 40 + r * (PETIT[1] + 4)
        d.text((6, y + PETIT[1] // 2), nom, fill=(200, 200, 200))
        for c, (cle, _titre, _t) in enumerate(VARIANTES):
            vue = "scinde" if ancre == "__scinde" else "unique"
            p = choix.get((cle, vue))
            if p is None or not os.path.exists(os.path.join(captures, p["fichier"])):
                continue
            img = Image.open(os.path.join(captures, p["fichier"])).convert("RGB")
            if ancre == "__scinde":
                case = img
                nom_png = "%s__scinde__%s.png" % (carte, cle)
            else:
                xy = p["ancres"].get(ancre)
                if xy is None:
                    continue
                x0 = min(max(0, xy[0] - L // 2), img.size[0] - L)
                y0 = min(max(0, xy[1] - H // 2), img.size[1] - H)
                case = img.crop((x0, y0, x0 + L, y0 + H))
                nom_png = "%s__%s__%s.png" % (carte, ancre, cle)
            case.save(os.path.join(sortie, nom_png))
            liste.append(nom_png)
            planche.paste(case.resize(PETIT, Image.LANCZOS), (170 + c * PETIT[0], y))
    planche.save(os.path.join(sortie, "planche_%s.jpg" % carte), quality=90)
    print("planche", carte, planche.size, "; variantes trouvées :", sorted(k for k in choix))
print(len(liste), "PNG pour la galerie dans", sortie)
