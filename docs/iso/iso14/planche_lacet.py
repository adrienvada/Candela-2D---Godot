#!/usr/bin/env python3
"""Planche ISO14 — le lacet à 45°, à côté de l'illustration de l'entraînement : sur La Croisée et Le Cloître, l'écran
scindé du photographe (la vue de J1 à gauche, celle de J2 à droite, au même instant) à 0° (le jeu d'aujourd'hui), puis
à 45° en option B (J2 à + 180°) et en option C (J2 au miroir, −45°). Le verdict de chaque case est LU dans le journal
du banc d'équité (`tools/banc_equite.gd`), jamais recopié à la main.

Usage : planche_lacet.py <sortie.jpg> <dépôt> <dossier des prises> <journal du banc d'équité>
Le dossier des prises contient un sous-dossier par prise, `<slug>_<réglage>` (réglage : 0, 45B, 45C), sortie du
photographe (`--sortie=`), donc `<slug>_<réglage>/jeu/NN-ecran-scinde-duel.png` (plan `ecran-scinde-duel` : J1 face au mur haut, J2 derrière).
"""
import glob
import re
import sys
from PIL import Image, ImageDraw, ImageFont

FOND, TEXTE, SOURD, AMBRE, ROUGE, VERT = (12, 12, 12), (225, 215, 195), (150, 140, 125), (230, 160, 70), (220, 90, 70), \
    (120, 190, 120)
CARTES = [("map_003_la_croisee", "La Croisée"), ("map_001_le_cloitre", "Le Cloître")]
REGLAGES = [("0", 0, "A", "0° — le jeu d'aujourd'hui"), ("45B", 45, "B", "45°, option B — J2 à 225°"),
            ("45C", 45, "C", "45°, option C — J2 à −45°")]
LW = 900
LH = LW * 1080 // 1920
SECTION = re.compile(r"^=== (\S+) — ")
LIGNE = re.compile(r"^\s+(\d+)° ([ABC]) \(J1.*→ (.+)$")


def police(t):
    for c in ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try:
            return ImageFont.truetype(c, t)
        except OSError:
            pass
    return ImageFont.load_default()


def verdicts(journal):
    out, carte = {}, None
    for l in open(journal, encoding="utf-8", errors="replace"):
        m = SECTION.search(l)
        if m:
            carte = m.group(1)
            continue
        m = LIGNE.search(l.rstrip())
        if m and carte:
            out[(carte, int(m.group(1)), m.group(2))] = m.group(3).strip()
    return out


def main(a):
    sortie, depot, dossier, journal = a
    v = verdicts(journal)
    marge = 16
    largeur = marge * 4 + 3 * LW
    ill = Image.open("%s/assets/ui/ill_entrainement.png" % depot).convert("RGB")
    ill_l = LW
    ill = ill.resize((ill_l, int(ill.height * ill_l / ill.width)), Image.LANCZOS)
    hauteur = 100 + ill.height + 40 + len(CARTES) * (LH + 80) + 60
    planche = Image.new("RGB", (largeur, hauteur), FOND)
    d = ImageDraw.Draw(planche)
    d.text((marge, 14), "ISO14 · le lacet à 45° — chaque joueur depuis son côté", fill=AMBRE, font=police(30))
    d.text((marge, 56), "écran scindé du photographe : la vue de J1 à gauche, celle de J2 à droite, au même instant ; "
           "verdicts lus dans le banc d'équité (0 · a · b · e)", fill=TEXTE, font=police(16))
    planche.paste(ill, (marge, 90))
    d.text((marge + ill_l + marge, 96), "illustration de l'entraînement\n(la cible visuelle, ISO13)", fill=SOURD,
           font=police(16))
    y = 90 + ill.height + 30
    manquantes = []
    for slug, nom in CARTES:
        d.text((marge, y), nom, fill=AMBRE, font=police(22))
        y += 34
        for c, (cle, lacet, option, libelle) in enumerate(REGLAGES):
            xx = marge + c * (LW + marge)
            # Le photographe numérote ses prises (`01-ecran-scinde-duel.png`) : on cherche le plan, pas un nom exact.
            trouvees = sorted(glob.glob("%s/%s_%s/jeu/*ecran-scinde-duel.png" % (dossier, slug, cle)))
            chemin = trouvees[0] if trouvees else "%s/%s_%s/jeu/ecran-scinde-duel.png" % (dossier, slug, cle)
            try:
                im = Image.open(chemin).convert("RGB").resize((LW, LH), Image.LANCZOS)
                planche.paste(im, (xx, y + 22))
                dd = ImageDraw.Draw(planche)
                dd.text((xx + 8, y + 28), "J1", fill=TEXTE, font=police(14))
                dd.text((xx + LW // 2 + 8, y + 28), "J2", fill=TEXTE, font=police(14))
            except OSError:
                manquantes.append(chemin)
                d.rectangle((xx, y + 22, xx + LW, y + 22 + LH), outline=ROUGE)
                d.text((xx + 12, y + 40), "prise manquante", fill=ROUGE, font=police(16))
            verdict = v.get((slug, lacet, option), "verdict absent du journal")
            juste = verdict.startswith("ÉQUITABLE")
            d.text((xx, y), "%s · %s" % (libelle, verdict if juste else "NON ÉQUITABLE " + verdict.replace("NON", "").strip()),
                   fill=VERT if juste else ROUGE, font=police(15))
        y += LH + 46
    planche.save(sortie, quality=90)
    print("planche : %s (%d×%d)" % (sortie, largeur, hauteur))
    for m in manquantes:
        print("✗ prise manquante : %s" % m)
    return 1 if manquantes else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
