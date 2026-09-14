#!/usr/bin/env python3
"""Planche d'ISO3a : les corps voxel des dix classes dans la vue iso du duel.

Usage : python3 docs/iso/planche_iso3a.py [--captures DIR] [--journal FICHIER]

Lit les captures écrites par `tools/banc_iso.gd` dans docs/iso/captures_iso3a/ (commandes dans la
ROADMAP, section ISO3a) et le journal du banc, et compose docs/iso/planche_iso3a.jpg :

- ligne 1 : un duel en écran scindé iso, torche de J1 seule puis torche de J2 seule — les corps voxel
  modelés par la lumière 2D, chacun dans la vue de l'autre ;
- ligne 2 : l'effacement du corps de J2 chez J1 — opacité 1, 0,5 et 0 ;
- ligne 3 : le noir absolu et la silhouette de soi — lightmaps noires, vue unique puis écran scindé
  (×8), et le corps retiré du rendu, référence de l'effacement.

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


def sections(journal):
    out = {}
    if not journal or not os.path.exists(journal):
        return out
    nom, lignes = None, []
    for l in open(journal, encoding="utf-8", errors="replace").read().split("\n"):
        m = re.match(r"===== (\S+) — ", l)
        if m:
            nom, lignes = m.group(1), []
            continue
        if nom and l.startswith("===== %s rc=" % nom):
            out[nom] = "\n".join(lignes)
            nom = None
            continue
        if nom:
            lignes.append(l)
    return out


def cherche(motif, texte):
    return re.search(motif, texte or "")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--captures", default=os.path.join(ICI, "captures_iso3a"))
    p.add_argument("--journal", default="")
    p.add_argument("--max-ko", type=int, default=450)
    p.add_argument("--max-planche-ko", type=int, default=1400)
    a = p.parse_args()
    c = a.captures
    for nom in sorted(os.listdir(c)):
        if nom.endswith(".png"):
            compresser(os.path.join(c, nom), os.path.join(c, nom), a.max_ko * 1024)
    s = sections(a.journal)
    cases = []

    for qui in ("j1", "j2"):
        v = cherche(r"BANC_ISO corps verdict=([^\n]+)", s.get("torche_%s" % qui))
        cases.append((os.path.join(c, "torche_%s.png" % qui), "écran scindé iso, torche de %s seule" % qui.upper(),
                      ("corps voxel · %s" % v.group(1)) if v else "relevé absent", 1))
    f = cherche(r"contraste_a_1=(\d+) contraste_a_0.5=(\d+) rapport=([\d.]+) rapport_median=([\d.]+)", s.get("effacement"))
    cases.append((os.path.join(c, "effacement_a1.png"), "effacement : J2 chez J1, opacité 1",
                  ("contraste contre le décor : %s" % f.group(1)) if f else "relevé absent", 1))

    e = cherche(r"ecart_a_0=(\d+) \(tolérance (\d+)\)", s.get("effacement"))
    cases.append((os.path.join(c, "effacement_a05.png"), "le même, opacité 0,5",
                  ("rapport %s, médian %s (attendu 0,50)" % (f.group(3), f.group(4))) if f else "relevé absent", 1))
    cases.append((os.path.join(c, "effacement_a0.png"), "le même, opacité 0",
                  ("écart au décor seul : %s (tolérance %s)" % (e.group(1), e.group(2))) if e else "relevé absent", 1))
    cases.append((os.path.join(c, "effacement_retire.png"), "le même, corps retiré du rendu",
                  "le décor seul, référence de l'écart", 1))

    for vue, titre in (("noir_unique", "vue unique"), ("noir_scinde", "écran scindé")):
        sil = cherche(r"BANC_ISO silhouette verdict=([^(]+)\(([^)]*)\)", s.get(vue))
        noir = cherche(r"BANC_ISO noir pate=\w+ vue=\w+ verdict=([^(]+)", s.get(vue))
        detail = "%s · %s" % (noir.group(1).strip() if noir else "noir absent", sil.group(1).strip() if sil else "silhouette absente")
        cases.append((os.path.join(c, "%s_lightmap_noire.png" % vue), "%s, lightmaps noires (×8)" % titre, detail, 8))
    cases.append((os.path.join(c, "noir_scinde.png"), "écran scindé, lumières éteintes (×8)",
                  "sa silhouette chez soi, rien de l'autre", 8))

    planche(cases, 3, "ISO3a — les corps voxel dans la vue iso",
            "Écran scindé iso · pâte D · dix classes, capteur par fragment, effacement, silhouette de soi",
            os.path.join(ICI, "planche_iso3a.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
