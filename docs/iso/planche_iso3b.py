#!/usr/bin/env python3
"""Planche d'ISO3b : les murs bas dans la vue iso du duel — murets, zone morte, capteurs.

Usage : python3 docs/iso/planche_iso3b.py [--captures DIR] [--journal FICHIER]

Lit les captures écrites par `tools/banc_murs_bas.gd --iso --captures docs/iso/captures_iso3b` sur la
carte d'essai des murs bas (tools/cartes/murs_bas_essai.json), et le journal du banc, et compose
docs/iso/planche_iso3b.jpg :

- ligne 1 : l'écran scindé iso — J1 tient la torche au nord du long muret, J2 derrière : accroupi dans
  la zone morte (noir), accroupi au-delà (éclairé), debout dans la zone (éclairé : « un mur bas laisse
  voir une tête debout ») ;
- ligne 2 : la lightmap de J1, celle que la vue iso projette au sol — avec la règle, sans la règle, et
  avant la correction du viewport du monde (la zone morte poussée dans le repère de l'écran 3D) ;
- ligne 3 : le noir absolu des deux lightmaps (×8), et la vue unique iso.

⚠️ Les captures « noir » sont ÉCLAIRCIES pour la planche (×8, légende à l'appui). Le verdict est le
chiffre du banc, jamais l'œil.

Dépendance : Pillow. Police, compression et vignettes : celles de planche_iso.py et planche_iso1.py.
"""
import argparse
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
from planche_iso import compresser  # noqa: E402
from planche_iso1 import planche  # noqa: E402


def lire(journal):
    if not journal or not os.path.exists(journal):
        return ""
    return open(journal, encoding="utf-8", errors="replace").read()


def accord_sol(texte, vue, j, scene):
    m = re.search(r"ACCORD_SOL vue=%s joueur=%d scene=« %s » sol=(\d+)/(\d+) zone_morte=(\d+) allumes_par_la_regle=(\d+)"
                  % (vue, j, re.escape(scene)), texte)
    return ("sol %s/%s juste, %s points en zone morte, %s allumés par la règle" % m.groups()) if m else "relevé absent"


def accord_capteur(texte, vue, j, scene):
    m = re.search(r"ACCORD_CAPTEUR vue=%s joueur=%d scene=« %s » sans_regle=(\d+)/255 regle=(\d+)/255 attendu=(\S+)"
                  % (vue, j, re.escape(scene)), texte)
    return ("capteur %s/255 (sans la règle %s), attendu %s" % (m.group(2), m.group(1), m.group(3))) if m else "relevé absent"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--captures", default=os.path.join(ICI, "captures_iso3b"))
    p.add_argument("--journal", default="")
    p.add_argument("--max-ko", type=int, default=450)
    p.add_argument("--max-planche-ko", type=int, default=1400)
    a = p.parse_args()
    c = a.captures
    for nom in sorted(os.listdir(c)):
        if nom.endswith(".png"):
            compresser(os.path.join(c, nom), os.path.join(c, nom), a.max_ko * 1024)
    t = lire(a.journal)
    cases = []

    for scene, titre in (("accroupi a L-12", "J2 accroupi dans la zone morte"),
                         ("accroupi a L+12", "J2 accroupi au-delà de la zone"),
                         ("debout a L-12", "J2 debout dans la zone")):
        fichier = "ecran_scinde_j1_%s_regle_iso.png" % scene.replace(" ", "_")
        cases.append((os.path.join(c, fichier), "écran scindé iso — %s" % titre,
                      accord_capteur(t, "ecran_scinde", 1, scene), 1))

    cases.append((os.path.join(c, "ecran_scinde_j1_accroupi_a_L-12_regle.png"), "lightmap de J1, avec la règle",
                  accord_sol(t, "ecran_scinde", 1, "accroupi a L-12"), 1))
    cases.append((os.path.join(c, "ecran_scinde_j1_accroupi_a_L-12_sans_regle.png"), "lightmap de J1, sans la règle",
                  "le même instant, murs retirés des matériaux", 1))
    avant = re.search(r"AVANT (ACCORD_SOL vue=ecran_scinde joueur=1 scene=« accroupi a L-12 » sol=(\d+)/(\d+) zone_morte=(\d+) allumes_par_la_regle=(\d+))", t)
    cases.append((os.path.join(c, "avant_ecran_scinde_j1_accroupi_a_L-12_regle.png"),
                  "avant la correction : zone morte au repère de l'écran 3D",
                  ("sol %s/%s juste, %s allumés par la règle" % (avant.group(2), avant.group(3), avant.group(5)))
                  if avant else "relevé absent", 1))

    for vue in (1, 2):
        m = re.search(r"NOIR_ABSOLU vue=%d regle=(\d+)/255@\([^)]*\) ancien=(\d+)/255@\([^)]*\) regle_bis=(\d+)/255" % vue, t)
        cases.append((os.path.join(c, "noir_vue%d_regle.png" % vue), "lightmap de J%d, lumières éteintes (×8)" % vue,
                      ("max %s/255 avec la règle, %s sans" % (m.group(1), m.group(2))) if m else "relevé absent", 8))
    cases.append((os.path.join(c, "vue_unique_j1_accroupi_a_L-12_regle_iso.png"), "vue unique iso — J2 accroupi dans la zone",
                  accord_capteur(t, "vue_unique", 1, "accroupi a L-12"), 1))

    planche(cases, 3, "ISO3b — les murs bas dans la vue iso",
            "Carte d'essai des murs bas · murets à 0,40 tuile · zone morte dans la lightmap et sur les capteurs",
            os.path.join(ICI, "planche_iso3b.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
