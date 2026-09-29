#!/usr/bin/env python3
"""Le point de braise de la fusée, à chaque âge : mesures et planches (Adrien, 2026-09-29 : « Le point rouge : oui, dans la 0.8.0 »).

Lit, pour chaque PASSAGE (un dossier écrit par `tools/planche_braise.gd`), son `journal.json` et ses recadrages PNG — trois par âge et par
vue : `apres` (le point tel que le code le dessine), `sans` (le même instant sans le point), `ancien` (l'ancien point, additif, dans la
couleur de la lumière, reconstitué à l'image) — et écrit, dans le dossier de sortie :
- `mesures.json` : pour chaque passage, chaque prise et chaque vue, la couleur mesurée du point, sa luminance, sa teinte et sa
  saturation, celles de l'ancien point et du sol autour, et les grandeurs analytiques du journal (énergie et couleur de la lumière) ;
- `planche_<vue>_<joueur>_brief.png` : les âges de la demande (1,5 / 2,5 / 3 / 3,5 / 5 / 8 / 16 s), le plein feu de 4 s puis celui de 2 s,
  l'ancien point orange, AVANT et APRÈS côte à côte, avec sous chaque case la couleur mesurée, sa luminance, et celle de l'ancien ;
- `planche_<vue>_<joueur>_fin_de_vie.png` : le creux et le sursaut de l'agonie, puis le résidu jusqu'à 19 s ;
- `planche_scinde_J1_J2.png` : les deux vues de l'écran scindé côte à côte, avant et après ;
- `courbe_<vue>_<joueur>[_zoom].png` : la luminance du point selon l'âge ; et `tableau.md`, le tableau des chiffres.

## Comment on mesure

Le point est mesuré LÀ OÙ IL EST, et non comme « le pixel le plus lumineux » (sur un sol orange, ce peut être le sol) : les pixels qui
diffèrent d'au moins 8/255 entre la prise AVEC et la prise SANS le point, dans `RAYON` px de sa position projetée, sont le point ; sa
couleur est la MÉDIANE, canal par canal, des 9 qui diffèrent le plus (le cœur du disque : là, le point couvre, sa couleur est la sienne).
La luminance est celle de Rec. 709 lue sur les valeurs affichées (0,2126 R + 0,7152 V + 0,0722 B, sur 0-255) : c'est la mesure qui
donne « 3,6 fois moins lumineux » entre (82, 55, 26) et (39, 10, 12), au résidu. Teinte et saturation : HSV. « Rouge » : teinte de 350° à
15°, saturation d'au moins 0,6 (le critère de Q34 = C). L'ancien point est mesuré de la même façon, sur SA prise (additif : sa couleur est
celle du sol PLUS la sienne, comme au jeu).

## Usage
  python3 mesurer.py --passage avant_unique1=DOSSIER --passage apres_unique1=DOSSIER [--passage avant_scinde=... --passage apres_scinde=...]
                     --sortie DOSSIER
Les noms de passage sont `<moment>_<vue>` (`avant_unique1`, `apres_scinde`…) : une planche compare les deux moments d'une vue.
"""
import argparse
import colorsys
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAYON = 10          # px de la vue autour du point projeté
SEUIL = 8           # écart minimal (max des canaux) entre `apres` et `sans`
N_CENTRE = 9        # les pixels qui diffèrent le plus
ANNEAU = (13, 24)   # le sol autour du point (pour le lire sans le point)
FOND = (20, 20, 20)
TEXTE = (225, 225, 225)
DISCRET = (140, 140, 140)
VERT = (150, 230, 150)
ROUGE_TXT = (240, 130, 130)
JAUNE = (235, 200, 120)
POLICE = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
POLICE_GRASSE = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
# Au-dessus de cette énergie, l'éclat du point est déjà plein : le rouge ne porte pas plus (la règle est bornée par lui).
SEUIL_DU_ROUGE_PLEIN = 0.6
AGES_DE_LA_DEMANDE = [1.5, 2.5, 3.0, 3.5, 5.0, 8.0, 16.0]
AGES_FIN_DE_VIE = [12.25, 12.83, 15.5, 16.0, 17.0, 18.0, 19.0]


def police(taille, gras=False):
    try:
        return ImageFont.truetype(POLICE_GRASSE if gras else POLICE, taille)
    except OSError:
        return ImageFont.load_default()


def luma(rgb):
    """Luminance de Rec. 709 sur des valeurs affichées 0-255."""
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def hsv(rgb):
    h, s, v = colorsys.rgb_to_hsv(*(np.clip(np.array(rgb, dtype=float), 0, 255) / 255.0))
    return h * 360.0, s, v


def est_rouge(rgb):
    h, s, _ = hsv(rgb)
    return (h >= 350.0 or h <= 15.0) and s >= 0.6


def charger(chemin):
    return np.array(Image.open(chemin).convert("RGB")).astype(int)


def virgule(x, nd=1):
    return ("%.*f" % (nd, x)).replace(".", ",")


def fmt_rgb(c):
    return "(%d, %d, %d)" % tuple(c) if c else "absent"


# ---------------------------------------------------------------------------
# Les mesures
# ---------------------------------------------------------------------------

def mesurer_couleur(a, s, centre):
    """La couleur du point dans `a` (avec), comparée à `s` (sans), autour de `centre` = (x, y) dans le recadrage."""
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    r = np.hypot(xx - centre[0], yy - centre[1])
    diff = np.abs(a - s).max(axis=2)
    masque = (diff >= SEUIL) & (r <= RAYON)
    hors = int(((diff >= SEUIL) & (r > RAYON)).sum())
    n = int(masque.sum())
    if n == 0:
        return {"pixels": 0, "hors": hors}
    ys, xs = np.nonzero(masque)
    ordre = np.argsort(-diff[ys, xs])[:N_CENTRE]
    couleur = np.median(a[ys[ordre], xs[ordre]], axis=0).round().astype(int).tolist()
    sous = s[ys[ordre], xs[ordre]].mean(axis=0).round().astype(int).tolist()
    anneau = (r >= ANNEAU[0]) & (r <= ANNEAU[1])
    sol = np.median(s[anneau], axis=0).round().astype(int).tolist()
    h, sat, val = hsv(couleur)
    return {"pixels": n, "hors": hors, "couleur": couleur, "luminance": round(luma(couleur), 2),
            "teinte": round(h, 1), "saturation": round(sat, 3), "valeur": round(val, 3), "rouge": bool(est_rouge(couleur)),
            "sous_le_point": sous, "luminance_sous_le_point": round(luma(sous), 2),
            "sol": sol, "luminance_sol": round(luma(sol), 2)}


def analytique(prise):
    """Ce que dit le journal : la lumière, et l'ancien point seul sur le noir (calculés, pas mesurés)."""
    e = float(prise["energie"])
    y_lumiere = luma([255.0 * min(e, 1.0) * c for c in prise["couleur_lumiere"]]) if prise.get("lumiere_active") else 0.0
    a = prise.get("ancien", {})
    y_ancien = 0.0
    if a:
        k = min(float(a["intensite"]), 1.0)
        y_ancien = luma([255.0 * k * c for c in a["couleur"][:3]])
    p = prise.get("point", {})
    y_point = luma([255.0 * c for c in p["couleur"][:3]]) if p and p.get("intensite", 0.0) > 0.0 else 0.0
    return {"luminance_lumiere": round(y_lumiere, 2), "luminance_ancien_seul": round(y_ancien, 2),
            "luminance_point_calculee": round(y_point, 2)}


def mesurer_passage(dossier):
    journal = json.load(open(os.path.join(dossier, "journal.json"), encoding="utf-8"))
    sortie = []
    for prise in journal["prises"]:
        m = {k: prise[k] for k in ("variante", "age_demande", "age_lu", "nom", "acte", "energie", "couleur_lumiere",
                                   "energie_relative", "opacite_coeur", "alpha_fumee", "duree_plein_feu", "eblouissement",
                                   "glissement_px", "point", "ancien")}
        m["analytique"] = analytique(prise)
        m["vues"] = {}
        for cle, v in prise["vues"].items():
            ox, oy = v["origine_du_recadrage"]
            centre = (v["point"][0] - ox, v["point"][1] - oy)
            base = os.path.join(dossier, "%s_%s_" % (prise["nom"], cle))
            a = charger(base + "apres.png")
            s = charger(base + "sans.png")
            mv = {"centre": [round(centre[0], 2), round(centre[1], 2)], "apres": mesurer_couleur(a, s, centre)}
            if os.path.exists(base + "ancien.png"):
                mv["ancien"] = mesurer_couleur(charger(base + "ancien.png"), s, centre)
            m["vues"][cle] = mv
        sortie.append(m)
    return {"commit": journal.get("commit"), "vue": journal.get("vue"), "fenetre": journal.get("fenetre"),
            "zoom": journal.get("zoom"), "carte": journal.get("carte"), "dossier": dossier, "prises": sortie}


def prise_de(mesures, variante, age):
    """La prise (variante, âge) — après 12 s les deux variantes sont dans le même état : celle de `long` sert aux deux."""
    for p in mesures["prises"]:
        if p["variante"] == variante and abs(p["age_demande"] - age) < 1e-6:
            return p
    if variante == "court" and age >= 12.0:
        for p in mesures["prises"]:
            if p["variante"] == "long" and abs(p["age_demande"] - age) < 1e-6:
                return p
    return None


def ligne(prise, cle):
    """Une ligne de texte lisible pour la console."""
    v = prise["vues"].get(cle)
    if not v or "couleur" not in v["apres"]:
        return "%-14s %s absent" % (prise["nom"], cle)
    a = v["apres"]
    o = v.get("ancien", {})
    return "%-14s %-9s E=%.3f  point %-16s Y=%6.1f  %5.1f° sat %.2f %-9s ancien %-16s Y=%6.1f  sol Y=%5.1f" % (
        prise["nom"], prise["acte"], prise["energie"], fmt_rgb(a["couleur"]), a["luminance"], a["teinte"], a["saturation"],
        "rouge" if a["rouge"] else "PAS ROUGE", fmt_rgb(o.get("couleur")), o.get("luminance", float("nan")), a["luminance_sol"])


# ---------------------------------------------------------------------------
# Les planches
# ---------------------------------------------------------------------------

def texte(d, xy, s, taille=12, couleur=TEXTE, gras=False):
    d.text(xy, s, font=police(taille, gras), fill=couleur)


def taille_qui_tient(d, s, largeur, taille, gras):
    """La plus grande taille de police, au plus `taille`, pour laquelle `s` tient dans `largeur` px (au moins 9)."""
    while taille > 9 and d.textlength(s, font=police(taille, gras)) > largeur:
        taille -= 1
    return taille


def recadre(chemin, centre, demi=24, facteur=4):
    im = Image.open(chemin).convert("RGB")
    x, y = int(round(centre[0])), int(round(centre[1]))
    x0 = min(max(x - demi, 0), im.width - 2 * demi)
    y0 = min(max(y - demi, 0), im.height - 2 * demi)
    return im.crop((x0, y0, x0 + 2 * demi, y0 + 2 * demi)).resize((2 * demi * facteur, 2 * demi * facteur), Image.NEAREST)


class Source:
    """Où lire une case : un passage, le recadrage (`apres` ou `ancien`), et la mesure correspondante."""

    def __init__(self, tout, dossiers, passage, mode):
        self.mesures = tout[passage]
        self.dossier = dossiers[passage]
        self.mode = mode  # « apres » : le point du jeu ; « ancien » : l'ancien point reconstitué

    def case(self, variante, age, cle):
        p = prise_de(self.mesures, variante, age)
        if p is None:
            return None
        v = p["vues"].get(cle)
        if v is None:
            return None
        chemin = os.path.join(self.dossier, "%s_%s_%s.png" % (p["nom"], cle, self.mode))
        if not os.path.exists(chemin):
            return None
        return {"prise": p, "centre": v["centre"], "chemin": chemin, "mesure": v.get(self.mode)}


def cellule(im, d, x, y, case, ref_ancien):
    """Une case : le recadrage agrandi, la pastille de la couleur mesurée, puis les mesures."""
    taille = 192
    if case is None:
        texte(d, (x, y), "—", 14, DISCRET)
        return
    im.paste(recadre(case["chemin"], case["centre"]), (x, y))
    d.rectangle((x, y, x + taille - 1, y + taille - 1), outline=(70, 70, 70))
    m = case["mesure"]
    if not m or "couleur" not in m:
        texte(d, (x + 6, y + taille + 4), "point absent", 12, DISCRET)
        return
    c = tuple(m["couleur"])
    d.rectangle((x + 4, y + 4, x + 28, y + 28), fill=c, outline=(255, 255, 255))
    ly = y + taille + 4
    texte(d, (x, ly), fmt_rgb(c), 13, TEXTE, True)
    texte(d, (x, ly + 17), "Y = %s" % virgule(m["luminance"]), 13, TEXTE)
    couleur_teinte = VERT if m["rouge"] else (JAUNE if m["saturation"] < 0.15 else ROUGE_TXT)
    texte(d, (x, ly + 34), "%d°  sat. %s%s" % (round(m["teinte"]), virgule(m["saturation"], 2), "  rouge" if m["rouge"] else ""), 12, couleur_teinte)
    if ref_ancien is not None:
        rapport = m["luminance"] / ref_ancien if ref_ancien > 0 else float("inf")
        texte(d, (x, ly + 51), "ancien orange : Y = %s" % virgule(ref_ancien), 12, DISCRET)
        prise = case["prise"]
        if prise["acte"] == "PLEIN_FEU":
            texte(d, (x, ly + 67), "plein feu : presque blanc", 12, DISCRET)
        elif prise["energie"] >= SEUIL_DU_ROUGE_PLEIN:
            # La lumière (l'ambre × 1,2) est plus claire que ne peut l'être un rouge saturé : le point est à son éclat plein.
            texte(d, (x, ly + 67), "ce point / l'ancien : %s" % virgule(rapport, 2), 12, JAUNE)
            texte(d, (x, ly + 83), "au maximum de son rouge", 12, JAUNE)
        else:
            texte(d, (x, ly + 67), "ce point / l'ancien : %s" % virgule(rapport, 2), 12, VERT if rapport >= 1.0 else ROUGE_TXT)


def planche(nom, titre, colonnes, ages, sortie, sous_titre=""):
    """`colonnes` : liste de (variante, libellé, Source, cle_de_vue, Source_de_référence_de_l'ancien ou None)."""
    pas_x, pas_y = 212, 316
    marge_g, marge_h = 112, 100
    largeur = marge_g + pas_x * len(colonnes) + 10
    hauteur = marge_h + pas_y * len(ages) + 10
    im = Image.new("RGB", (largeur, hauteur), FOND)
    d = ImageDraw.Draw(im)
    texte(d, (12, 10), titre, taille_qui_tient(d, titre, largeur - 24, 18, True), TEXTE, True)
    if sous_titre:
        texte(d, (12, 36), sous_titre, taille_qui_tient(d, sous_titre, largeur - 24, 12, False), DISCRET)
    for i, (_, libelle, _, _, _) in enumerate(colonnes):
        for k, morceau in enumerate(libelle.split("\n")):
            texte(d, (marge_g + i * pas_x, 60 + 16 * k), morceau, 13 if k == 0 else 12, TEXTE if k == 0 else DISCRET, k == 0)
    for j, age in enumerate(ages):
        y = marge_h + j * pas_y
        texte(d, (10, y + 8), "%s s" % virgule(age, 1 if abs(age - round(age, 1)) < 1e-9 else 2), 20, TEXTE, True)
        premiere = None
        for i, (variante, libelle, source, cle, ref_source) in enumerate(colonnes):
            case = source.case(variante, age, cle)
            if case is not None and premiere is None:
                premiere = case
            ref = None
            if ref_source is not None:
                rc = ref_source.case(variante, age, cle)
                if rc is not None and rc["mesure"] and "luminance" in rc["mesure"]:
                    ref = rc["mesure"]["luminance"]
            cellule(im, d, marge_g + i * pas_x, y, case, ref)
        if premiere is not None:
            texte(d, (10, y + 40), premiere["prise"]["acte"].lower(), 12, DISCRET)
            texte(d, (10, y + 56), "E = %s" % virgule(premiere["prise"]["energie"], 2), 12, DISCRET)
    chemin = os.path.join(sortie, "planche_%s.png" % nom)
    im.save(chemin)
    print("écrit %s (%dx%d)" % (os.path.basename(chemin), largeur, hauteur))


def courbe(nom, titre, series, sortie, x_min=0.0, x_max=20.0, y_max=250.0, actes=None, taille=(1100, 580)):
    """Une courbe `y = f(âge)` par série : (libellé, couleur, [(x, y), ...])."""
    w, h = taille
    im = Image.new("RGB", (w, h), FOND)
    d = ImageDraw.Draw(im)
    gauche, droite, haut, bas = 70, 20, 50, 100
    x0, x1, y0, y1 = gauche, w - droite, h - bas, haut

    def px(x):
        return x0 + (x - x_min) / (x_max - x_min) * (x1 - x0)

    def py(y):
        return y0 + y / y_max * (y1 - y0)

    texte(d, (12, 10), titre, 16, TEXTE, True)
    pas = 10 if y_max > 120 else 5
    pas = 25 if y_max > 200 else pas
    for k in range(0, int(y_max) + 1, pas):
        d.line((x0, py(k), x1, py(k)), fill=(45, 45, 45))
        texte(d, (x0 - 40, py(k) - 8), "%d" % k, 11, DISCRET)
    for xt in range(int(math.ceil(x_min)), int(x_max) + 1):
        d.line((px(xt), y0, px(xt), y1), fill=(35, 35, 35))
        texte(d, (px(xt) - 6, y0 + 6), "%d" % xt, 11, DISCRET)
    texte(d, (x1 - 60, y0 + 24), "âge (s)", 11, DISCRET)
    texte(d, (8, y1 - 24), "luminance (0-255)", 11, DISCRET)
    for bord, etiquette in (actes or []):
        if x_min <= bord <= x_max:
            d.line((px(bord), y0, px(bord), y1), fill=(90, 90, 90))
            texte(d, (px(bord) + 3, y1 - 6), etiquette, 10, DISCRET)
    for lib, couleur, pts in series:
        pts = [(x, y) for x, y in pts if x_min <= x <= x_max and y == y]
        if len(pts) >= 2:
            d.line([(px(x), py(min(y, y_max))) for x, y in pts], fill=couleur, width=2)
        for x, y in pts:
            d.ellipse((px(x) - 3, py(min(y, y_max)) - 3, px(x) + 3, py(min(y, y_max)) + 3), fill=couleur)
    for k, (lib, couleur, _) in enumerate(series):
        d.rectangle((x0 + 12, y0 + 30 + k * 16, x0 + 26, y0 + 40 + k * 16), fill=couleur)
        texte(d, (x0 + 32, y0 + 28 + k * 16), lib, 11, TEXTE)
    chemin = os.path.join(sortie, "courbe_%s.png" % nom)
    im.save(chemin)
    print("écrit %s" % os.path.basename(chemin))


def serie(source, cle, choix="luminance", variante="long"):
    pts = []
    for p in source.mesures["prises"]:
        if p["variante"] != variante:
            continue
        v = p["vues"].get(cle, {}).get(source.mode)
        if v and "couleur" in v:
            pts.append((p["age_lu"], v[choix]))
    return sorted(pts)


# ---------------------------------------------------------------------------
# Le tableau, et les contrôles de cohérence
# ---------------------------------------------------------------------------

def tableau(tout, vue, cle, avant, apres):
    """Le tableau Markdown : par variante et par âge, le point avant, après, l'ancien orange, la lumière."""
    lignes = ["| âge (s) | acte | énergie | avant : point (Y) | après : point (Y) | ancien orange (Y) | sa lumière (Y) | après / ancien | rouge après |",
              "|---|---|---|---|---|---|---|---|---|"]
    for variante in ("long", "court"):
        lignes.append("| **plein feu de %s s** | | | | | | | | |" % ("4" if variante == "long" else "2"))
        for age in AGES_DE_LA_DEMANDE + [a for a in AGES_FIN_DE_VIE if variante == "long"]:
            pa, pb = prise_de(tout[avant], variante, age), prise_de(tout[apres], variante, age)
            if pa is None or pb is None or cle not in pa["vues"] or cle not in pb["vues"]:
                continue
            ma, mb = pa["vues"][cle]["apres"], pb["vues"][cle]["apres"]
            mo = pa["vues"][cle].get("ancien", {})
            if "couleur" not in ma and "couleur" not in mb:
                continue
            fa = "%s (%s)" % (fmt_rgb(ma["couleur"]), virgule(ma["luminance"])) if "couleur" in ma else "invisible"
            fb = "%s (%s)" % (fmt_rgb(mb["couleur"]), virgule(mb["luminance"])) if "couleur" in mb else "invisible"
            fo = "%s (%s)" % (fmt_rgb(mo["couleur"]), virgule(mo["luminance"])) if "couleur" in mo else "—"
            rap = virgule(mb["luminance"] / mo["luminance"], 2) if "couleur" in mb and "couleur" in mo and mo["luminance"] > 0 else "—"
            lum = virgule(pa["analytique"]["luminance_lumiere"])
            lignes.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                virgule(age, 2 if age not in AGES_DE_LA_DEMANDE else 1), pa["acte"].lower(), virgule(pa["energie"], 3), fa, fb, fo, lum, rap,
                "oui" if mb.get("rouge") else "non"))
    return "\n".join(lignes)


def coherence(tout):
    """Les écarts maximaux qui disent si la mesure se répète : J1 contre J2, l'écran scindé contre la vue unique, avant contre après."""
    sorties = []

    def ecart(a, b):
        return max(abs(int(x) - int(y)) for x, y in zip(a, b))

    for moment in ("avant", "apres"):
        nom = moment + "_scinde"
        if nom in tout:
            pire = 0
            for p in tout[nom]["prises"]:
                v = p["vues"]
                if "J1" in v and "J2" in v and "couleur" in v["J1"]["apres"] and "couleur" in v["J2"]["apres"]:
                    pire = max(pire, ecart(v["J1"]["apres"]["couleur"], v["J2"]["apres"]["couleur"]))
            sorties.append("%s, écran scindé : la couleur du point dans la vue de J1 et dans celle de J2 ne diffère jamais de plus de %d/255" % (moment, pire))
    for moment in ("avant", "apres"):
        u, s = moment + "_unique1", moment + "_scinde"
        if u in tout and s in tout:
            pire = 0
            for p in tout[u]["prises"]:
                q = prise_de(tout[s], p["variante"], p["age_demande"])
                if q and "couleur" in p["vues"].get("J1", {}).get("apres", {}) and "couleur" in q["vues"].get("J1", {}).get("apres", {}):
                    pire = max(pire, ecart(p["vues"]["J1"]["apres"]["couleur"], q["vues"]["J1"]["apres"]["couleur"]))
            sorties.append("%s : vue unique (la fenêtre) contre écran scindé (la sous-vue) : au plus %d/255 d'écart sur la couleur du point" % (moment, pire))
    for vue in ("unique1", "scinde"):
        a, b = "avant_" + vue, "apres_" + vue
        if a in tout and b in tout:
            pire = 0
            n = 0
            for p in tout[a]["prises"]:
                q = prise_de(tout[b], p["variante"], p["age_demande"])
                if q is None:
                    continue
                for cle in p["vues"]:
                    ma, mb = p["vues"][cle].get("ancien", {}), q["vues"].get(cle, {}).get("ancien", {})
                    if "couleur" in ma and "couleur" in mb:
                        pire = max(pire, ecart(ma["couleur"], mb["couleur"]))
                        n += 1
            sorties.append("%s : l'ancien point, reconstitué dans les deux arbres, ne diffère jamais de plus de %d/255 (%d mesures) — la scène se répète" % (vue, pire, n))
    return sorties


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--passage", action="append", required=True, help="nom=DOSSIER (nom = <moment>_<vue>)")
    ap.add_argument("--sortie", required=True)
    args = ap.parse_args()
    os.makedirs(args.sortie, exist_ok=True)
    tout, dossiers = {}, {}
    for v in args.passage:
        nom, dossier = v.split("=", 1)
        dossiers[nom] = dossier
        tout[nom] = mesurer_passage(dossier)
        print("\n== %s : %d prises, fenêtre %s, vue %s, carte %s" % (nom, len(tout[nom]["prises"]), tout[nom]["fenetre"], tout[nom]["vue"], tout[nom]["carte"]))
        for p in tout[nom]["prises"]:
            for cle in p["vues"]:
                print(ligne(p, cle))
    with open(os.path.join(args.sortie, "mesures.json"), "w", encoding="utf-8") as f:
        json.dump(tout, f, ensure_ascii=False, indent=1)
    print("\nécrit mesures.json")

    md = []
    for vue in ("unique1", "scinde"):
        av, ap_ = "avant_" + vue, "apres_" + vue
        if av not in tout or ap_ not in tout:
            continue
        cles = ["J1"] if vue == "unique1" else ["J1", "J2"]
        for cle in cles:
            # Le tableau.
            md.append("### Vue %s, %s\n\n%s\n" % ("unique (la fenêtre, comme en ligne)" if vue == "unique1" else "de l'écran scindé", cle,
                                                   tableau(tout, vue, cle, av, ap_)))
            ancien = Source(tout, dossiers, av, "ancien")
            avant_ = Source(tout, dossiers, av, "apres")
            apres_ = Source(tout, dossiers, ap_, "apres")
            colonnes = []
            for variante, pre in (("long", "plein feu 4 s"), ("court", "plein feu 2 s")):
                colonnes += [(variante, pre + "\nl'ancien point orange", ancien, cle, None),
                             (variante, pre + "\navant (le point rouge d'hier)", avant_, cle, ancien),
                             (variante, pre + "\naprès (le point d'aujourd'hui)", apres_, cle, ancien)]
            planche("%s_%s_brief" % (vue, cle),
                    "Le point de braise de la fusée — vue %s, %s (45° B), 1920×1080, fusée posée, aucun éblouissement" % (
                        "unique" if vue == "unique1" else "de l'écran scindé", cle),
                    colonnes, AGES_DE_LA_DEMANDE, args.sortie,
                    "Sous chaque case : la couleur mesurée du point, sa luminance Y (Rec. 709, 0-255), sa teinte et sa saturation, et la luminance de l'ancien point orange au même âge.")
            planche("%s_%s_fin_de_vie" % (vue, cle),
                    "Fin de vie de la fusée — le creux et le sursaut de l'agonie, puis le résidu — vue %s, %s" % (
                        "unique" if vue == "unique1" else "de l'écran scindé", cle),
                    [("long", "fin de vie\nl'ancien point orange", ancien, cle, None), ("long", "fin de vie\navant", avant_, cle, ancien),
                     ("long", "fin de vie\naprès", apres_, cle, ancien)], AGES_FIN_DE_VIE, args.sortie)
            # Les courbes.
            lum = sorted((p["age_lu"], p["analytique"]["luminance_lumiere"]) for p in tout[av]["prises"] if p["variante"] == "long")
            series = [("l'ancien point orange (mesuré, sur le sol de la scène)", (240, 170, 60), serie(ancien, cle)),
                      ("avant : le point rouge (mesuré)", (230, 90, 90), serie(avant_, cle)),
                      ("après : le point rouge (mesuré)", (110, 220, 130), serie(apres_, cle)),
                      ("sa lumière : luma(couleur) × min(énergie, 1) (calculée)", (120, 170, 255), lum)]
            # Les bords des actes, ceux de la variante `long` (celle des séries) : le braise commence après son plein feu de 4 s.
            pf = next((p["duree_plein_feu"] for p in tout[av]["prises"] if p["variante"] == "long"), 4.0)
            nom_vue = "unique (la fenêtre)" if vue == "unique1" else "de l'écran scindé"
            courbe("%s_%s" % (vue, cle), "Luminance du point selon l'âge (plein feu de 4 s) — vue %s, %s" % (nom_vue, cle), series, args.sortie,
                   0.0, 20.0, 260.0, [(pf, "braise"), (12.0, "agonie"), (15.0, "résidu")])
            courbe("%s_%s_zoom" % (vue, cle), "Luminance du point, de l'agonie à la fin (12 à 20 s) — vue %s, %s" % (nom_vue, cle), series, args.sortie,
                   12.0, 20.0, 130.0, [(12.0, "agonie"), (15.0, "résidu")])
    # L'écran scindé, J1 et J2 côte à côte.
    if "avant_scinde" in tout and "apres_scinde" in tout:
        ancien = Source(tout, dossiers, "avant_scinde", "ancien")
        avant_ = Source(tout, dossiers, "avant_scinde", "apres")
        apres_ = Source(tout, dossiers, "apres_scinde", "apres")
        cols = [("long", "plein feu 4 s\navant, vue de J1", avant_, "J1", ancien), ("long", "plein feu 4 s\naprès, vue de J1", apres_, "J1", ancien),
                ("long", "plein feu 4 s\navant, vue de J2", avant_, "J2", ancien), ("long", "plein feu 4 s\naprès, vue de J2", apres_, "J2", ancien)]
        planche("scinde_J1_J2", "Écran scindé, 45° B : la fusée dans la vue de J1 (à 45°) et dans celle de J2 (à 225°) — avant et après", cols,
                AGES_DE_LA_DEMANDE + [12.25, 15.5, 17.0, 18.0], args.sortie)
    with open(os.path.join(args.sortie, "tableau.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(md))
    print("écrit tableau.md")
    print("\n=== Cohérence ===")
    for s in coherence(tout):
        print(" -", s)
    print()
    print("\n".join(md))


if __name__ == "__main__":
    main()
