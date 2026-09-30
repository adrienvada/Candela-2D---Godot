#!/usr/bin/env python3
"""Planches du chantier « Gadgets en volume » (GV0 et GV1).

Usage :
    python3 docs/iso/gadgets_volume/planche_gv.py --avant DIR --nuages DIR --noir DIR [--sortie DIR]

Lit les vignettes et les relevés de `tools/banc_gadgets_volume.gd` (un dossier par mode) et compose, dans
`docs/iso/gadgets_volume/` par défaut :

- planche_gv0_gadgets.jpg — les dix gadgets TELS QU'ILS SONT (34666f25), la mine dormante puis embrasée : pour chacun, la
  vue de J1 et la vue de J2 sous la torche de J1, puis dans le noir (toutes les lumières éteintes) ;
- planche_gv0_fusee.jpg — la fusée en vol, au plein feu, en braise, au résidu, en panache, même disposition ;
- planche_gv1_<nuage>.jpg — suie, poussière, fumée de fusée : à chaque instant de leur vie, sous la lampe puis dans le noir,
  les couches d'aujourd'hui, les voxels gros (1/4 de tuile) et fins (1/8), vus de J1 puis de J2 — cadrage identique, la
  MÊME image de jeu pour les trois rendus ;
- planche_gv1_detail.jpg — une région de chaque nuage sans réduction (la matière des cubes) ;
- planche_gv1_noir.jpg — la preuve du noir à l'écran : sans les cubes, avec, masque coupé, et la carte des fuites.

⚠️ Une vignette noire est affichée telle quelle : un noir tenu est un carré noir. Le verdict est le chiffre du banc.
Dépendance : Pillow.
"""
import argparse
import os
import re

from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
FOND = (16, 16, 18)
ENCRE = (236, 228, 210)
GRIS = (150, 146, 138)
ROUGE = (230, 80, 70)

GADGETS = [
    ("mine_magnesium", "Mine au magnésium (dormante)"),
    ("mine_embrasee", "Mine au magnésium (embrasée)"),
    ("ombre_habitee", "Ombre habitée"),
    ("torche_fantome", "Torche fantôme"),
    ("voile", "Voile"),
    ("gresillement", "Grésillement"),
    ("leurre", "Leurre"),
    ("nappe_braises", "Nappe de braises"),
    ("poudre_contact", "Poudre de contact (traces de J1)"),
    ("cartouche_suie", "Cartouche de suie (2 s)"),
    ("poussiere", "Poussière (2 s)"),
]
FUSEE = [
    ("fusee_vol", "Fusée en vol (comète à 1,2 tuile)"),
    ("fusee_plein_feu", "Fusée posée, plein feu (1 s)"),
    ("fusee_braise", "Fusée posée, braise (6 s)"),
    ("fusee_residu", "Fusée posée, résidu (17 s)"),
    ("fusee_panache", "Fusée éteinte, panache (0,6 s)"),
]


def police(taille, gras=False):
    for chemin in ["/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if gras else ""),
                   "/System/Library/Fonts/Supplemental/Arial.ttf"]:
        if os.path.exists(chemin):
            return ImageFont.truetype(chemin, taille)
    return ImageFont.load_default()


def vignette(dossier, nom, cote):
    """La vignette `nom` réduite dans un carré de `cote`, sur fond ; une case rouge si elle manque."""
    chemin = os.path.join(dossier, nom + ".png")
    fond = Image.new("RGB", (cote, cote), FOND)
    if not os.path.exists(chemin):
        d = ImageDraw.Draw(fond)
        d.rectangle([0, 0, cote - 1, cote - 1], outline=ROUGE, width=3)
        d.text((8, 8), "absente :\n" + nom, fill=ROUGE, font=police(12))
        return fond
    im = Image.open(chemin).convert("RGB")
    im.thumbnail((cote, cote), Image.LANCZOS)
    fond.paste(im, ((cote - im.width) // 2, (cote - im.height) // 2))
    return fond


def releves(dossier, mode):
    chemin = os.path.join(dossier, "releves_%s.txt" % mode)
    if not os.path.exists(chemin):
        return []
    with open(chemin, encoding="utf-8") as f:
        return [l.strip() for l in f if l.strip()]


def champs(ligne):
    return dict(re.findall(r"(\w+)=([^\s|]+)", ligne))


def planche(titre, sous_titre, entetes, lignes, cote, fichier, legende_ligne=180):
    """`lignes` : [(libellé, [vignettes], [textes sous les vignettes])]."""
    marge, entete, bas = 10, 96, 22
    colonnes = len(entetes)
    largeur = legende_ligne + colonnes * (cote + marge) + marge
    hauteur = entete + len(lignes) * (cote + bas + marge) + marge
    p = Image.new("RGB", (largeur, hauteur), FOND)
    d = ImageDraw.Draw(p)
    d.text((marge, 10), titre, fill=ENCRE, font=police(24, True))
    # Le sous-titre, coupé à la largeur de la planche (sur deux lignes au plus).
    mots, lignes_st, ligne_st = sous_titre.split(" "), [], ""
    for m in mots:
        if d.textlength((ligne_st + " " + m).strip(), font=police(14)) > largeur - 2 * marge:
            lignes_st.append(ligne_st)
            ligne_st = m
        else:
            ligne_st = (ligne_st + " " + m).strip()
    lignes_st.append(ligne_st)
    d.text((marge, 42), "\n".join(lignes_st[:2]), fill=GRIS, font=police(14))
    for i, e in enumerate(entetes):
        d.text((legende_ligne + marge + i * (cote + marge), entete - 24), e, fill=ENCRE, font=police(14, True))
    for j, (libelle, ims, textes) in enumerate(lignes):
        y = entete + j * (cote + bas + marge)
        # Le libellé, coupé à la largeur de sa colonne (en pixels, pas en caractères).
        mots, ligne_txt, lignes_txt = libelle.split(" "), "", []
        for m in mots:
            if ligne_txt and d.textlength(ligne_txt + " " + m, font=police(15, True)) > legende_ligne - marge - 4:
                lignes_txt.append(ligne_txt)
                ligne_txt = m
            else:
                ligne_txt = (ligne_txt + " " + m).strip()
        lignes_txt.append(ligne_txt)
        d.text((marge, y + 6), "\n".join(lignes_txt), fill=ENCRE, font=police(15, True))
        for i, im in enumerate(ims):
            x = legende_ligne + marge + i * (cote + marge)
            p.paste(im, (x, y))
            if i < len(textes) and textes[i]:
                d.text((x + 2, y + cote + 3), textes[i], fill=GRIS, font=police(11))
    p.save(fichier, quality=84, optimize=True)
    print("écrit", fichier, p.size, "%.0f Ko" % (os.path.getsize(fichier) / 1024))


def gv0(dossier, sortie):
    stats = {}
    for l in releves(dossier, "avant"):
        c = champs(l)
        if "prise" in c:
            stats[(c["prise"], c["vue"])] = c
    entetes = ["J1 — sous la torche", "J2 — sous la torche", "J1 — dans le noir", "J2 — dans le noir"]
    for liste, nom, cote in [(GADGETS, "planche_gv0_gadgets.jpg", 230), (FUSEE, "planche_gv0_fusee.jpg", 300)]:
        lignes = []
        for slug, libelle in liste:
            ims, textes = [], []
            for lumiere, vue in [("lampe", 1), ("lampe", 2), ("noir", 1), ("noir", 2)]:
                ims.append(vignette(dossier, "avant_%s_%s_j%d" % (slug, lumiere, vue), cote))
                s = stats.get(("avant_" + slug, "J%d" % vue), {})
                textes.append(("max %s" % s.get("noir_max", "?")) if lumiere == "noir" else "")
            lignes.append((libelle, ims, textes))
        planche("GV0 — les gadgets tels qu'ils sont dans la vue iso (34666f25)",
                "Écran scindé, lacet 45° B : J1 à l'ouest, torche à 2,5 ; J2 au sud, torche éteinte. « Noir » : toutes les "
                "lumières éteintes (la silhouette de soi et les dessins lumineux restent, par dessein).",
                entetes, lignes, cote, os.path.join(sortie, nom))


# Les actes de la fusée, dans l'ordre de sa vie (le nom de la prise commence par son rang).
ACTES_FUSEE = {"plein_feu": "plein feu (1 s)", "braise": "braise (6 s)", "sillage": "sillage (J2 l'a traversée)",
               "residu": "résidu (17 s)", "panache": "panache, éteinte (0,5 s)"}


def libelle_instant(brut):
    """« 02.5 » → « 2,5 s » (suie, poussière) ; « 1_plein_feu » → « plein feu (1 s) » (fusée)."""
    try:
        return ("%.1f s" % float(brut)).replace(".", ",")
    except ValueError:
        acte = brut.split("_", 1)[1] if "_" in brut and brut[0].isdigit() else brut
        return ACTES_FUSEE.get(acte, acte.replace("_", " "))


def gv1(dossier, sortie):
    fichiers = sorted(f[:-4] for f in os.listdir(dossier) if f.startswith("gv1_") and f.endswith(".png"))
    prises = sorted({re.sub(r"_(lampe|noir)_(couches|gros|fin)_j[12]$", "", f) for f in fichiers})
    entetes = ["J1 AVANT (couches)", "J1 voxels gros", "J1 voxels fins", "J2 AVANT (couches)", "J2 voxels gros",
               "J2 voxels fins"]
    for nuage, titre, cote in [("cartouche_suie", "la suie du Fumiste", 250), ("poussiere", "la poussière du Terrassier", 250),
                               ("fusee", "la fumée de la fusée", 250)]:
        lignes = []
        for prise in [p for p in prises if p.startswith("gv1_" + nuage)]:
            instant = libelle_instant(prise.replace("gv1_%s_" % nuage, ""))
            for lumiere, mot in [("lampe", "sous la lampe"), ("noir", "dans le noir")]:
                ims = [vignette(dossier, "%s_%s_%s_j%d" % (prise, lumiere, rendu, vue), cote)
                       for vue in (1, 2) for rendu in ("couches", "gros", "fin")]
                lignes.append(("%s — %s" % (instant, mot), ims, []))
        if not lignes:
            continue
        planche("GV1 — %s : couches d'aujourd'hui contre voxels (à l'essai)" % titre,
                "La MÊME image de jeu pour les trois rendus (âge tenu). Voxels gros : 1/4 de tuile (8,75 px) ; fins : "
                "1/8 (4,4 px). Sous la lampe : torche de J1 (et la lumière propre du nuage) ; dans le noir : tout éteint.",
                entetes, lignes, cote, os.path.join(sortie, "planche_gv1_%s.jpg" % nuage))


# Le DÉTAIL, pixel pour pixel : à la taille des planches, un cube de 8,75 px de monde n'en fait plus que trois ou quatre,
# et l'œil ne juge plus la matière. Une région de chaque prise, sans réduction, pour un instant plein de chaque nuage.
# (nom de la prise, libellé, centre de la région en fraction de la vignette).
DETAILS = [("gv1_cartouche_suie_02.5", "suie, 2,5 s", (0.5, 0.5)), ("gv1_poussiere_02.0", "poussière, 2 s", (0.45, 0.55)),
           ("gv1_fusee_2_braise", "fusée, braise (6 s)", (0.62, 0.62))]


def detail(dossier, sortie, cote=300):
    lignes = []
    for prise, libelle, (fx, fy) in DETAILS:
        ims = []
        for vue in (1, 2):
            for rendu in ("couches", "gros", "fin"):
                chemin = os.path.join(dossier, "%s_lampe_%s_j%d.png" % (prise, rendu, vue))
                fond = Image.new("RGB", (cote, cote), FOND)
                if os.path.exists(chemin):
                    im = Image.open(chemin).convert("RGB")
                    x = max(0, min(im.width - cote, int(im.width * fx) - cote // 2))
                    y = max(0, min(im.height - cote, int(im.height * fy) - cote // 2))
                    fond.paste(im.crop((x, y, x + cote, y + cote)), (0, 0))
                ims.append(fond)
        lignes.append(("%s — sous la lampe, pixel pour pixel" % libelle, ims, []))
    planche("GV1 — le détail : la matière des cubes, sans réduction",
            "Une région de chaque prise à sa taille d'écran (écran scindé, 1920 × 1080), la même pour les trois rendus. "
            "Le jeu d'aujourd'hui à gauche de chaque vue, puis les voxels gros (1/4 de tuile) et fins (1/8).",
            ["J1 AVANT (couches)", "J1 voxels gros", "J1 voxels fins", "J2 AVANT (couches)", "J2 voxels gros",
             "J2 voxels fins"], lignes, cote, os.path.join(sortie, "planche_gv1_detail.jpg"))


def noir(dossier, sortie):
    """Une ligne par cas, par rendu (les couches d'aujourd'hui, référence ; les voxels gros et fins) et par vue."""
    stats = {}
    for l in releves(dossier, "noir"):
        if l.startswith("noir cas="):
            c = champs(l.split("|")[0])
            stats[(c["cas"], c["variante"], c["vue"])] = l
    cas = sorted({k[0] for k in stats})
    lignes = []
    cote = 230
    for c in cas:
        for v in ("couches", "gros", "fin"):
            for vue in (1, 2):
                l = stats.get((c, v, "J%d" % vue), "")
                if not l:
                    continue
                # Les champs AVANT le premier « | » : la suite de la ligne (masque coupé) répète « fuites= ».
                ch = champs(l.split("|")[0])
                m = re.search(r"masque_coupe: fuites=\d+ fuites_sup2=(\d+)", l)
                t = re.search(r"temoin: fuites_sup2=(\d+)", l)
                if v == "couches":
                    noms = ("sans", "avec", None, "fuites")
                    textes = ["noir dessous : %s px" % ch.get("noirs_dessous", "?"),
                              "fuites %s (%s > 2/255)" % (ch.get("fuites", "?"), ch.get("fuites_sup2", "?")), "",
                              "rouge = fuite, vert = noir tenu"]
                else:
                    noms = ("sans", "avec", "masque_coupe", "masque_coupe_fuites")
                    textes = ["noir dessous : %s px" % ch.get("noirs_dessous", "?"),
                              "FUITES %s (%s > 2/255)" % (ch.get("fuites", "?"), ch.get("fuites_sup2", "?")),
                              "masque coupé : %s > 2/255" % (m.group(1) if m else "?"),
                              "témoin : %s fuites vues" % (t.group(1) if t else "?")]
                ims = [vignette(dossier, "noir_%s_%s_%s_j%d" % (c, v, n, vue), cote) if n else
                       Image.new("RGB", (cote, cote), FOND) for n in noms]
                rendu = "couches (réf.)" if v == "couches" else "voxels %s" % v
                lignes.append(("%s, %s, J%d" % (c.replace("_", " "), rendu, vue), ims, textes))
    if lignes:
        planche("GV1 — le noir absolu À L'ÉCRAN : ce que les cubes allument de noir, contre les couches d'aujourd'hui",
                "A sans les images du nuage / B avec (masque pochoir) / B masque coupé / carte des fuites. Fuite : pixel "
                "stable (A = A'), noir (0/255) sans les images, sous leur emprise (le compteur), allumé avec. Témoin : des "
                "cubes qui s'allumeraient partout — le détecteur les voit. Corps cachés pendant la preuve. Référence : les "
                "couches du jeu.",
                ["sans les images", "avec (masque)", "masque coupé", "carte des fuites"], lignes, cote,
                os.path.join(sortie, "planche_gv1_noir.jpg"), legende_ligne=230)


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--avant")
    a.add_argument("--nuages")
    a.add_argument("--noir")
    a.add_argument("--sortie", default=ICI)
    args = a.parse_args()
    os.makedirs(args.sortie, exist_ok=True)
    if args.avant:
        gv0(args.avant, args.sortie)
    if args.nuages:
        gv1(args.nuages, args.sortie)
        detail(args.nuages, args.sortie)
    if args.noir:
        noir(args.noir, args.sortie)


if __name__ == "__main__":
    main()
