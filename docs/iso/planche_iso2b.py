#!/usr/bin/env python3
"""Planche d'ISO2b : l'effacement des corps iso et la silhouette de soi.

Usage : python3 docs/iso/planche_iso2b.py [--captures DIR] [--journal FICHIER]

Lit les captures écrites par `tools/banc_iso.gd` dans docs/iso/captures_iso2b/ (commandes dans la
ROADMAP, section ISO2b) et le journal du banc, et compose docs/iso/planche_iso2b.jpg :

- ligne 1 : l'effacement — le corps iso de J2 dans la vue de J1, éclairé, à l'opacité forcée à 1,
  forcée à 0, puis retiré du rendu ; à 0, la vue doit montrer ce qu'elle montre sans lui ;
- ligne 2 : la silhouette de soi — lightmaps noires, vue unique puis écran scindé (×8) : chacun voit
  son corps à la moitié de sa couleur, jamais celui de l'autre ; puis la scène torche de J1 ;
- ligne 3 : l'étalon du fondu — le sprite de J2 en vue de dessus forcé à 1 puis à 0,5, et le corps
  iso à 0,5 : le contraste contre le décor, rapporté à celui à opacité 1, doit valoir 0,50 des deux
  côtés.

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
    """nom de lancement → texte de sa section (« ===== nom — hh:mm:ss » … « ===== nom rc=N »)."""
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


def cherche(motif, texte, defaut="relevé absent"):
    m = re.search(motif, texte or "")
    return m if m else None


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--captures", default=os.path.join(ICI, "captures_iso2b"))
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

    fondu_iso = cherche(r"BANC_ISO fondu rendu=iso .*contraste_a_1=(\d+) contraste_a_0.5=(\d+) rapport=([\d.]+)", s.get("effacement"))
    eff = cherche(r"ecart_a_0=(\d+) \(tolérance (\d+)\) ecart_a_1=(\d+) \(visible dès (\d+)\)", s.get("effacement"))
    verdict = cherche(r"BANC_ISO effacement rendu=iso verdict=([^\n]+)", s.get("effacement"))
    v = verdict.group(1) if verdict else "relevé absent"
    cases.append((os.path.join(c, "effacement_a1.png"), "iso : J2 éclairé chez J1, opacité 1",
                  ("écart au décor seul : %s (visible dès %s)" % (eff.group(3), eff.group(4))) if eff else "relevé absent", 1))
    cases.append((os.path.join(c, "effacement_a0.png"), "iso : le même, opacité 0",
                  ("%s · écart au décor seul : %s (tolérance %s)" % (v, eff.group(1), eff.group(2))) if eff else v, 1))
    cases.append((os.path.join(c, "effacement_retire.png"), "iso : le même, corps retiré du rendu",
                  "le décor seul, référence de l'écart", 1))

    for vue, titre in (("noir_unique", "vue unique"), ("noir_scinde", "écran scindé")):
        sil = cherche(r"BANC_ISO silhouette verdict=([^(]+)\(([^)]*)\)", s.get(vue))
        detail = ("%s · %s" % (sil.group(1).strip(), sil.group(2))) if sil else "relevé absent"
        cases.append((os.path.join(c, "%s_lightmap_noire.png" % vue), "%s, lightmaps noires (×8)" % titre, detail, 8))
    cases.append((os.path.join(c, "torche_j1.png"), "écran scindé iso, torche de J1 seule",
                  "sa silhouette colore son propre corps, chez soi seulement", 1))

    fondu_base = cherche(r"BANC_ISO fondu rendu=base .*contraste_a_1=(\d+) contraste_a_0.5=(\d+) rapport=([\d.]+)", s.get("fondu_base"))
    cases.append((os.path.join(c, "fondu_base_a1.png"), "étalon : vue de dessus, sprite de J2 à 1",
                  ("contraste contre le décor : %s" % fondu_base.group(1)) if fondu_base else "relevé absent", 1))
    cases.append((os.path.join(c, "fondu_base_a05.png"), "étalon : vue de dessus, sprite à 0,5",
                  ("contraste %s · rapport %s (attendu 0,50)" % (fondu_base.group(2), fondu_base.group(3))) if fondu_base else "relevé absent", 1))
    cases.append((os.path.join(c, "effacement_a05.png"), "étalon : iso, corps à 0,5",
                  ("contraste %s · rapport %s (attendu 0,50)" % (fondu_iso.group(2), fondu_iso.group(3))) if fondu_iso else "relevé absent", 1))

    planche(cases, 3, "ISO2b — l'effacement des corps et la silhouette de soi",
            "Écran scindé iso · pâte D · le corps se fond dans le décor, jamais ne noircit",
            os.path.join(ICI, "planche_iso2b.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
