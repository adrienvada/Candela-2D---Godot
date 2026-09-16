"""ISO12, lot 0 — la planche aux cadrages de la loupe (demande de la session cloud, 23:42).

Usage : python3 planche_lumiere3d.py JOURNAL_DU_BANC DOSSIER_DES_CAPTURES DOSSIER_DE_SORTIE

Pour chaque carte, en VUE UNIQUE : une ligne par cadrage (bord du cône, pied du mur ou pilier, corps de J1, corps de J2, sol,
fusée posée, puis les corps de J1 et J2 agrandis ×4 au plus proche voisin), une colonne par variante (lumière éteinte =
référence 2D, 3D sans ombres, 3D avec ombres pâte (a), pâte (b), pâte (c), les trois brides de gradient, contact non,
rétrodiffusion non), chaque case un recadrage 800×450 de la capture pleine fenêtre, centré sur l'ancre que le banc a projetée à
l'écran. Puis une ligne ÉCRAN SCINDÉ : la capture entière de la même variante, réduite.
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
        and p["retro"] == "true" and p["atlas"] == "2048" and _bride(p) == "05" and _econ(p)),
    ("pate_b", "ombres, pâte (b)", lambda p: p["ombres"] == "true" and p["pate"] == "b" and p["contact"] == "true"
        and p["bride"].startswith("(0.0, 0.05") and _econ(p)),
    ("pate_c", "ombres, pâte (c)", lambda p: p["ombres"] == "true" and p["pate"] == "c" and p["contact"] == "true"
        and p["bride"].startswith("(0.0, 0.05") and _econ(p)),
    ("bride030", "bride (0 ; 0,3)", lambda p: p["ombres"] == "true" and p["pate"] == "a" and p["contact"] == "true"
        and _bride(p) == "30" and _econ(p)),
    ("bride060", "bride (0 ; 0,6)", lambda p: p["ombres"] == "true" and p["pate"] == "a" and p["contact"] == "true"
        and _bride(p) == "60" and _econ(p)),
    ("brideident", "bride identité", lambda p: p["ombres"] == "true" and p["pate"] == "a" and p["contact"] == "true"
        and _bride(p) == "identite" and _econ(p)),
    ("contact0", "contact non", lambda p: p["ombres"] == "true" and p["pate"] == "a" and p["contact"] == "false"
        and _bride(p) == "05" and _econ(p)),
    ("retro0", "rétrodiffusion non", lambda p: p.get("retro") == "false"),
]
## Une ligne par ancre ; `x4` agrandit quatre fois au plus proche voisin, pour juger un corps au pixel.
CADRAGES = [("bord_cone", "bord du cône", 1), ("pied_mur", "pied du mur / pilier", 1), ("j1", "corps J1", 1),
            ("j2", "corps J2", 1), ("sol", "sol", 1), ("fusee", "fusée posée", 1),
            ("j1", "corps J1 ×4", 4), ("j2", "corps J2 ×4", 4)]
L, H = 800, 450
PETIT = (320, 180)


## Le nom de la bride d'une prise, RAMENÉ À UNE SEULE ÉCRITURE. `bride_nom` fait foi ; le repli sur le vecteur ne sert qu'aux
## journaux d'avant le lot 0 ter, où la bride identité s'imprimait comme la (0 ; 0,05) — indistinguables, donc jamais départagées.
##
## ⚠️ Deux écritures coexistent dans le banc : `_id_variante` met la bride sur DEUX chiffres (05, 30, 60) et `BRIDES_GRADIENT`
## sur TROIS (005, 030, 060). Comparer à l'une quand l'arrivée porte l'autre ne lève rien du tout — la colonne manque, sans un
## mot. C'est ce qui a sorti les planches des cadrages sans leur colonne « 3D avec ombres ».
def _bride(p):
    nom = p.get("bride_nom", "")
    if nom:
        return {"005": "05", "030": "30", "060": "60"}.get(nom, nom)
    v = p.get("bride", "")
    if v.startswith("(0.0, 0.05"):
        return "05"
    if v.startswith("(0.0, 0.3"):
        return "30"
    if v.startswith("(0.0, 0.6"):
        return "60"
    return v


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
    d.text((6, 6), "ISO12 lot 0 ter — %s, cadrages de la loupe (vue unique), puis l'écran scindé" % carte, fill=(230, 180, 90))
    for c, (cle, titre, _t) in enumerate(VARIANTES):
        d.text((170 + c * PETIT[0] + 4, 24), titre, fill=(200, 200, 200))
    for r, (ancre, nom, zoom) in enumerate(CADRAGES + [("__scinde", "écran scindé", 1)]):
        y = 40 + r * (PETIT[1] + 4)
        d.text((6, y + PETIT[1] // 2), nom, fill=(200, 200, 200))
        for c, (cle, _titre, _t) in enumerate(VARIANTES):
            vue = "scinde" if ancre == "__scinde" else "unique"
            p = choix.get((cle, vue))
            # Un cadrage tourné en écran scindé SEULEMENT (ceux du lot 0 ter : l'adversaire vu par J1 et par lui-même sur la
            # même image) n'a pas de prise en vue unique. Sans ce repli, toutes ses lignes d'ancre — la loupe ×4 sur le corps
            # comprise — disparaissent sans une erreur.
            if p is None and vue == "unique":
                p = choix.get((cle, "scinde"))
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
                # ×4 : on coupe quatre fois plus petit autour de la même ancre, puis on agrandit au plus proche voisin — le
                # pixel reste un carré, c'est tout l'intérêt pour juger un corps.
                l, h = L // zoom, H // zoom
                x0 = min(max(0, xy[0] - l // 2), img.size[0] - l)
                y0 = min(max(0, xy[1] - h // 2), img.size[1] - h)
                case = img.crop((x0, y0, x0 + l, y0 + h))
                if zoom > 1:
                    case = case.resize((L, H), Image.NEAREST)
                nom_png = "%s__%s%s__%s.png" % (carte, ancre, "_x%d" % zoom if zoom > 1 else "", cle)
            case.save(os.path.join(sortie, nom_png))
            liste.append(nom_png)
            planche.paste(case.resize(PETIT, Image.LANCZOS), (170 + c * PETIT[0], y))
    planche.save(os.path.join(sortie, "planche_%s.jpg" % carte), quality=90)
    print("planche", carte, planche.size, "; variantes trouvées :", sorted(k for k in choix))
print(len(liste), "PNG pour la galerie dans", sortie)
