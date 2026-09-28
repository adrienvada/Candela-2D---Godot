#!/usr/bin/env python3
"""Les murs meublés en essai — les mesures au pixel et la planche.

Lit les prises de `tools/photo_murs_meubles.gd` (un dossier par lancement : `seul` = le seul drapeau des murs meublés,
`tous` = tous les essais de la nuit plus celui-ci) et le journal de chaque lancement (pour les lignes `CADRE`) ; écrit
`mesures.json`, les images JPEG de `img/` et `planche.html`.

    python3 docs/iso/cloud/murs-meubles/mesurer.py <dossier user://mm> <journal seul> [<journal tous>]

Conventions (celles des planches des enseignes et de l'écart) : luminance Rec. 709 des valeurs sRGB, 0..255.
- A, B, A2 : les murs meublés cachés, montrés, cachés de nouveau, au MÊME instant (jeu en pause) ; M leur emprise en blanc.
- « plus clair que sans » : lum(B) − lum(A) > 0,5 ; et, pour mémoire, un canal qui monte de plus de 2.
- « noir allumé » (torches éteintes) : max(A) = max(A2) = 0 et max(B) > 0 (strict) ; et au seuil 7,5/255.
- l'emprise : les pixels blancs de M (≥ 250 sur les trois canaux) qui ne le sont pas dans A.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(ICI, "img")
ILL = os.path.join(ICI, "..", "..", "..", "..", "assets", "ui")
FAMILLES = ["portes", "grilles", "boitiers", "faisceaux"]
# L'illustration de chaque famille et le cadre qui la montre (x0, y0, x1, y1 en fraction de l'image).
ILLUSTRATIONS = {
    "portes": ("ill_intro_seuil.png", (0.45, 0.24, 0.72, 0.88)),
    "grilles": ("ill_accueil.png", (0.72, 0.14, 0.99, 0.84)),
    "boitiers": ("ill_competitif.png", (0.03, 0.02, 0.33, 0.66)),
    "faisceaux": ("ill_rejoindre_ligne.png", (0.0, 0.14, 0.34, 0.76)),
}
NOMS = {"portes": "Les portes rivetées", "grilles": "Les grilles", "boitiers": "Les boîtiers électriques",
        "faisceaux": "Les faisceaux de câbles serrés"}


def charger(dossier, cle):
    chemin = os.path.join(dossier, cle + ".png")
    if not os.path.exists(chemin):
        return None
    return np.asarray(Image.open(chemin).convert("RGB")).astype(np.int16)


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def emprise(m, a):
    blanc_m = (m >= 250).all(axis=-1)
    blanc_a = (a >= 250).all(axis=-1)
    return blanc_m & ~blanc_a


def mesurer_serie(dossier, cle):
    a, b, a2, m = (charger(dossier, cle + s) for s in ("__A", "__B", "__A2", "__M"))
    if a is None or b is None or m is None:
        return None
    r = {}
    mask = emprise(m, a)
    r["emprise_px"] = int(mask.sum())
    if a2 is not None:
        r["bruit_A_A2_px"] = int((a != a2).any(axis=-1).sum())
    la, lb = lum(a), lum(b)
    change = (a != b).any(axis=-1)
    r["changes_px"] = int(change.sum())
    r["changes_hors_emprise_px"] = int((change & ~mask).sum())
    r["plus_clairs_lum_px"] = int((lb - la > 0.5).sum())
    r["plus_clairs_canal2_px"] = int(((b - a) > 2).any(axis=-1).sum())
    r["assombris_px"] = int((lb < la - 0.5).sum())
    noir_a = a.max(axis=-1) == 0
    if a2 is not None:
        noir_a &= a2.max(axis=-1) == 0
    r["noirs_A_px"] = int(noir_a.sum())
    r["noirs_allumes_strict_px"] = int((noir_a & (b.max(axis=-1) > 0)).sum())
    seuil = 7.5
    sombre_a = la <= seuil
    if a2 is not None:
        sombre_a &= lum(a2) <= seuil
    r["noirs_allumes_seuil_px"] = int((sombre_a & (lb > seuil)).sum())
    r["emprise_sur_noir_px"] = int((mask & noir_a).sum())
    r["emprise_sur_noir_allumes_px"] = int((mask & noir_a & (b.max(axis=-1) > 0)).sum())
    eclaires = mask & (la > 8)
    r["emprise_eclairee_px"] = int(eclaires.sum())
    if eclaires.any():
        rapport = lb[eclaires] / np.maximum(la[eclaires], 1e-6)
        r["rapport_B_sur_A_median"] = round(float(np.median(rapport)), 3)
        r["rapport_B_sur_A_max"] = round(float(rapport.max()), 3)
    r["pixels_allumes_B"] = int((b.max(axis=-1) > 0).sum())
    r["pixels_allumes_A"] = int((a.max(axis=-1) > 0).sum())
    return r


def cadres(journal):
    sortie = {}
    if not journal or not os.path.exists(journal):
        return sortie
    for ligne in open(journal, encoding="utf-8", errors="replace"):
        if ligne.startswith("CADRE "):
            _, fam, p0, p1 = ligne.split()
            x0, y0 = (float(v) for v in p0.split(","))
            x1, y1 = (float(v) for v in p1.split(","))
            sortie[fam] = (x0, y0, x1, y1)
    return sortie


def rognage(cadre, marge, taille, mini=(0, 0)):
    x0, y0, x1, y1 = cadre
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    w = max(x1 - x0 + 2 * marge, mini[0])
    h = max(y1 - y0 + 2 * marge, mini[1])
    x0 = int(max(0, min(taille[0] - w, cx - w / 2)))
    y0 = int(max(0, min(taille[1] - h, cy - h / 2)))
    return (x0, y0, int(x0 + w), int(y0 + h))


def jpeg(img, nom, qualite=85):
    os.makedirs(IMG, exist_ok=True)
    img.convert("RGB").save(os.path.join(IMG, nom), quality=qualite)
    return "img/" + nom


def symetrie(dossier):
    a, b, m = (charger(dossier, "sym" + s) for s in ("__A", "__B", "__M"))
    if m is None or a is None:
        return None
    mask = emprise(m, a)
    h, w = mask.shape
    g, d = mask[:, : w // 2], mask[:, w - w // 2:]
    # La ligne de séparation de l'écran scindé : les deux moitiés ont la même largeur à un pixel près.
    r = {"emprise_J1_px": int(g.sum()), "emprise_J2_px": int(d.sum()),
         "xor_px": int((g ^ d).sum()), "commun_px": int((g & d).sum())}
    # Le meilleur recalage à ±3 px (la ligne centrale peut décaler une moitié).
    meilleur = (r["xor_px"], 0, 0)
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            x = int((np.roll(np.roll(d, dx, axis=1), dy, axis=0) ^ g).sum())
            if x < meilleur[0]:
                meilleur = (x, dx, dy)
    r["xor_recale_px"], r["recalage_dx"], r["recalage_dy"] = meilleur
    lb = lum(b)
    r["lum_moy_emprise_J1"] = round(float(lb[:, : w // 2][g].mean()), 2) if g.any() else None
    r["lum_moy_emprise_J2"] = round(float(lb[:, w - w // 2:][d].mean()), 2) if d.any() else None
    return r


def main():
    racine = sys.argv[1]
    journal_seul = sys.argv[2] if len(sys.argv) > 2 else ""
    journal_tous = sys.argv[3] if len(sys.argv) > 3 else ""
    seul = os.path.join(racine, "seul")
    tous = os.path.join(racine, "tous")
    mesures = {"seul": {}, "tous": {}}
    cad = cadres(journal_seul)
    lignes = []
    for fam in FAMILLES:
        for etat in ("allumees", "eteintes"):
            r = mesurer_serie(seul, "%s_%s" % (fam, etat))
            if r is not None:
                mesures["seul"]["%s_%s" % (fam, etat)] = r
        if os.path.isdir(tous):
            for etat in ("allumees", "eteintes"):
                r = mesurer_serie(tous, "%s_%s" % (fam, etat))
                if r is not None:
                    mesures["tous"]["%s_%s" % (fam, etat)] = r
    mesures["seul"]["sym"] = symetrie(seul)
    for d, nom in ((seul, "seul"), (tous, "tous")):
        r = mesurer_serie(d, "ensemble") if os.path.isdir(d) else None
        if r is not None:
            mesures[nom]["ensemble"] = r
    json.dump(mesures, open(os.path.join(ICI, "mesures.json"), "w"), indent=1, ensure_ascii=False)

    # --- les images de la planche
    rangees = []
    for fam in FAMILLES:
        if fam not in cad:
            continue
        a = Image.open(os.path.join(seul, "%s_allumees__A.png" % fam))
        b = Image.open(os.path.join(seul, "%s_allumees__B.png" % fam))
        bn = Image.open(os.path.join(seul, "%s_eteintes__B.png" % fam))
        r1 = rognage(cad[fam], 40, a.size, (260, 200))
        r3 = rognage(cad[fam], 6, a.size)
        ill_nom, f = ILLUSTRATIONS[fam]
        ill = Image.open(os.path.join(ILL, ill_nom)).convert("RGB")
        W, H = ill.size
        ill = ill.crop((int(f[0] * W), int(f[1] * H), int(f[2] * W), int(f[3] * H)))
        ill.thumbnail((360, 360))
        loupe = lambda im: im.crop(r3).resize(((r3[2] - r3[0]) * 3, (r3[3] - r3[1]) * 3), Image.NEAREST)
        rangee = {
            "famille": fam, "nom": NOMS[fam], "illustration": ill_nom,
            "ill": jpeg(ill, "%s_illustration.jpg" % fam),
            "sans": jpeg(a.crop(r1), "%s_sans.jpg" % fam),
            "avec": jpeg(b.crop(r1), "%s_avec.jpg" % fam),
            "sans3": jpeg(loupe(a), "%s_sans_x3.jpg" % fam, 92),
            "avec3": jpeg(loupe(b), "%s_avec_x3.jpg" % fam, 92),
            "noir": jpeg(bn.crop(r1), "%s_eteintes_avec.jpg" % fam),
            "m": mesures["seul"].get("%s_allumees" % fam), "mn": mesures["seul"].get("%s_eteintes" % fam),
        }
        if os.path.isdir(tous) and os.path.exists(os.path.join(tous, "%s_allumees__B.png" % fam)):
            bt = Image.open(os.path.join(tous, "%s_allumees__B.png" % fam))
            rangee["tous"] = jpeg(bt.crop(r1), "%s_tous.jpg" % fam)
        rangees.append(rangee)
    vues = {}
    for d, nom in ((seul, "seul"), (tous, "tous")):
        for s in ("__A", "__B"):
            p = os.path.join(d, "ensemble%s.png" % s)
            if os.path.exists(p):
                im = Image.open(p)
                vues["%s%s" % (nom, s.lower())] = jpeg(im, "ensemble_%s%s.jpg" % (nom, s.lower()), 82)
    p = os.path.join(seul, "sym__B.png")
    if os.path.exists(p):
        vues["sym"] = jpeg(Image.open(p), "sym_ecran_scinde.jpg", 82)
    p = os.path.join(seul, "sym__M.png")
    if os.path.exists(p):
        vues["sym_m"] = jpeg(Image.open(p), "sym_emprise.jpg", 82)
    json.dump({"rangees": rangees, "vues": vues}, open(os.path.join(ICI, "planche.json"), "w"), indent=1,
              ensure_ascii=False)
    print(json.dumps(mesures, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
