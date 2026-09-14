#!/usr/bin/env python3
"""Planches d'ISO1 : les quatre pâtes, le noir absolu, et les hauteurs de murs.

Usage : python3 docs/iso/planche_iso1.py [--captures DIR] [--journal FICHIER]

Lit les captures écrites par `tools/banc_iso.gd --jeu` dans docs/iso/captures_iso1/ (les
commandes sont dans la ROADMAP, section ISO1), les compresse sur place sous --max-ko et
compose :

- docs/iso/planche_pate.jpg : « Le cloître », torche allumée, un flash, rendu DANS LE MOTEUR
  en pâtes A, B, C, D et brute ; puis, pour chaque pâte, la capture « lumières éteintes »
  et la valeur maximale relevée par le banc (lue dans --journal), et la vue de dessus
  lumières éteintes pour comparer ;
- docs/iso/planche_iso1.jpg : « default » et « Le cloître » à 52°, murs à 0,65 et 1,0 tuile.

⚠️ Les captures « noir » sont ÉCLAIRCIES pour la planche (×8, légende à l'appui) : noires,
elles ne montreraient rien. Le verdict est le chiffre du banc, jamais l'œil.

Dépendance : Pillow. Police et compression : celles de planche_iso.py.
"""
import argparse
import os
import re
import sys

from PIL import Image, ImageDraw

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
from planche_iso import police, compresser, ENCRE, PAPIER, AMBRE, MUET  # noqa: E402

VIGNETTE = (640, 360)
BANDEAU, LEGENDE, MARGE = 70, 44, 6
NOMS_PATES = {
    "A": "A — gravure à l'encre",
    "B": "B — ligne claire",
    "C": "C — trame et encre décalée",
    "D": "D — lavis et pochoir",
    "brute": "brute — la lightmap sans pâte",
}


def vignette(chemin, eclaircir=1):
    im = Image.open(chemin).convert("RGB")
    if eclaircir != 1:
        im = im.point(lambda v: min(255, v * eclaircir))
    im.thumbnail(VIGNETTE, Image.LANCZOS)
    fond = Image.new("RGB", VIGNETTE, ENCRE)
    fond.paste(im, ((VIGNETTE[0] - im.width) // 2, (VIGNETTE[1] - im.height) // 2))
    return fond


def planche(cases, colonnes, titre, sous_titre, sortie, max_ko):
    lignes = (len(cases) + colonnes - 1) // colonnes
    largeur = colonnes * (VIGNETTE[0] + MARGE) + MARGE
    hauteur = BANDEAU + lignes * (VIGNETTE[1] + LEGENDE + MARGE) + MARGE
    toile = Image.new("RGB", (largeur, hauteur), ENCRE)
    d = ImageDraw.Draw(toile)
    d.text((MARGE * 2, 10), titre, font=police(28), fill=AMBRE)
    d.text((MARGE * 2, 44), sous_titre, font=police(16), fill=MUET)
    for i, (chemin, legende, detail, eclaircir) in enumerate(cases):
        x = MARGE + (i % colonnes) * (VIGNETTE[0] + MARGE)
        y = BANDEAU + (i // colonnes) * (VIGNETTE[1] + LEGENDE + MARGE)
        if chemin and os.path.exists(chemin):
            toile.paste(vignette(chemin, eclaircir), (x, y))
        else:
            d.text((x + 20, y + 160), "capture absente", font=police(20), fill=MUET)
        d.text((x + 4, y + VIGNETTE[1] + 3), legende, font=police(17), fill=PAPIER)
        d.text((x + 4, y + VIGNETTE[1] + 23), detail, font=police(14), fill=MUET)
    qualite = 88
    while True:
        toile.save(sortie, "JPEG", quality=qualite, optimize=True)
        if os.path.getsize(sortie) <= max_ko * 1024 or qualite <= 50:
            break
        qualite -= 6
    print("planche %s : %d×%d, %d Ko" % (sortie, largeur, hauteur, os.path.getsize(sortie) // 1024))


def releves_noir(journal):
    """pâte → (verdict, px hors support, max écran a, max écran b, max lightmap b) ; 'base' → max écran."""
    out = {}
    if not journal or not os.path.exists(journal):
        return out
    texte = open(journal, encoding="utf-8", errors="replace").read()
    for m in re.finditer(r"BANC_ISO noir pate=(\w+) verdict=([^(]+)\(a : (-?\d+) pixel\(s\) allumé\(s\) hors du support de la brute, écran max (\d+) ; b : écran (\d+) sur lightmap (\d+)\)", texte):
        out[m.group(1)] = (m.group(2).strip(), int(m.group(3)), int(m.group(4)), int(m.group(5)), int(m.group(6)))
    m = re.search(r"BANC_ISO noir-a rendu=base max_ecran=(\d+)", texte)
    if m:
        out["base"] = int(m.group(1))
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--captures", default=os.path.join(ICI, "captures_iso1"))
    p.add_argument("--journal", default="")
    p.add_argument("--max-ko", type=int, default=450)
    p.add_argument("--max-planche-ko", type=int, default=1400)
    a = p.parse_args()
    c = a.captures

    for nom in sorted(os.listdir(c)):
        if nom.endswith(".png"):
            compresser(os.path.join(c, nom), os.path.join(c, nom), a.max_ko * 1024)

    noir = releves_noir(a.journal)
    cases = []
    for lettre in ["A", "B", "C", "D", "brute"]:
        cases.append((os.path.join(c, "pate_%s.png" % lettre), NOMS_PATES[lettre],
                      "Le cloître · torche · un flash · 52° · murs 0,65 t", 1))
    cases.append((os.path.join(c, "noir_base.png"), "vue de dessus, lumières éteintes (×8)",
                  "max écran %s/255 — le résidu du jeu (viseur, liseré)" % noir.get("base", "?"), 8))
    for lettre in ["A", "B", "C", "D"]:
        r = noir.get(lettre)
        detail = ("%s · a : %d px hors support · b : écran %d/255" % (r[0], r[1], r[3])) if r else "relevé absent"
        cases.append((os.path.join(c, "noir_%s.png" % lettre), "%s, lumières éteintes (×8)" % lettre, detail, 8))
    for lettre in ["A", "B", "C", "D"]:
        r = noir.get(lettre)
        cases.append((os.path.join(c, "noir_%s_lightmap_noire.png" % lettre),
                      "%s, lightmap noire (×8)" % lettre,
                      ("écran max %d/255 — l'invariant de la pâte" % r[3]) if r else "relevé absent", 8))
    planche(cases, 3, "CANDELA — ISO1 : LES QUATRE PÂTES, ET LE NOIR ABSOLU",
            "Rendu dans le moteur par le chemin du jeu (banc_iso --jeu) · gl_compatibility · MacBook M3 · 2026-09-14",
            os.path.join(ICI, "planche_pate.jpg"), a.max_planche_ko)

    cases = []
    for carte, nom in [("default", "Arène standard"), ("map_001_le_cloitre", "Le cloître")]:
        for h in ["0.65", "1.0"]:
            cases.append((os.path.join(c, "iso1_%s_mur%s.png" % (carte, h)),
                          "%s · murs %s tuile" % (nom, h.replace(".", ",")),
                          "52° · lacet 0° · pâte A · un flash · sans HUD (le voile de J2 du banc le masquerait)", 1))
    planche(cases, 2, "CANDELA — ISO1 : LE DUEL EN VUE ISOMÉTRIQUE, DEUX HAUTEURS DE MURS",
            "0,65 tuile = 17,8 px cachés derrière un mur (critère < 18 px tenu) · 1,0 tuile = 27,3 px (dépassé)",
            os.path.join(ICI, "planche_iso1.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
