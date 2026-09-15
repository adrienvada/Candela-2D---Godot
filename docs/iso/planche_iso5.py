#!/usr/bin/env python3
"""Planche d'ISO5 : la killcam dans la vue iso.

Usage : python3 docs/iso/planche_iso5.py [--captures DIR] [--journal FICHIER]

Lit les captures de `tools/banc_iso.gd --killcam` (commandes dans la ROADMAP, section ISO5) rangées dans
docs/iso/captures_iso5/, et leurs relevés (`releves_iso5.txt`), et compose docs/iso/planche_iso5.jpg :

- ligne 1 : la killcam iso par la vue de J1 (local, hôte), avec son voile ; gros plan sur les deux
  fantômes, sans voile ; la même région en vue de dessus (lumières éteintes, teinte de killcam, ×4) ;
- ligne 2 : la killcam iso par la vue de J2 (configuration du client) ; gros plan du voile forcé en
  négatif (la preuve qu'il relit la vue iso, corps compris) ; le noir absolu de la killcam iso (×8).

Les gros plans sont recadrés sur les boîtes des fantômes que le banc a relevées.

⚠️ Les captures « vue de dessus » et « noir » sont ÉCLAIRCIES pour la planche (gain en légende). Le
verdict est le chiffre du banc, jamais l'œil.

Dépendance : Pillow. Police, compression et vignettes : celles de planche_iso.py et planche_iso1.py.
"""
import argparse
import os
import re
import sys

from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
from planche_iso import compresser  # noqa: E402
from planche_iso1 import planche  # noqa: E402


def lire(journal):
    if not journal or not os.path.exists(journal):
        return ""
    return open(journal, encoding="utf-8", errors="replace").read()


def verdict(t, vue, controle):
    m = re.search(r"BANC_ISO killcam %s vue=%s verdict=([^—(\n]+)" % (controle, vue), t)
    return m.group(1).strip() if m else "relevé absent"


def boites(t, vue):
    ligne = next((l for l in t.split("\n") if "BANC_ISO killcam corps vue=%s " % vue in l), "")
    return [tuple(int(v) for v in m) for m in re.findall(r"\[P: \((\d+), (\d+)\), S: \((\d+), (\d+)\)\]", ligne)]


def gros_plan(c, source, cible, zones, image_entiere_si_absent=True):
    """Recadre `source` sur l'union des zones, avec une marge de deux fois leur taille."""
    chemin = os.path.join(c, source)
    if not os.path.exists(chemin) or not zones:
        return chemin if image_entiere_si_absent else None
    x0 = min(z[0] for z in zones)
    y0 = min(z[1] for z in zones)
    x1 = max(z[0] + z[2] for z in zones)
    y1 = max(z[1] + z[3] for z in zones)
    marge = 2 * max(max(z[2] for z in zones), max(z[3] for z in zones))
    im = Image.open(chemin).convert("RGB")
    boite = (max(0, x0 - marge), max(0, y0 - marge), min(im.width, x1 + marge), min(im.height, y1 + marge))
    sortie = os.path.join(c, cible)
    im.crop(boite).save(sortie)
    return sortie


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--captures", default=os.path.join(ICI, "captures_iso5"))
    p.add_argument("--journal", default="")
    p.add_argument("--max-ko", type=int, default=450)
    p.add_argument("--max-planche-ko", type=int, default=1400)
    a = p.parse_args()
    c = a.captures
    t = lire(a.journal or os.path.join(c, "releves_iso5.txt"))
    b1 = boites(t, "j1")
    b2 = boites(t, "j2")
    gp_j1 = gros_plan(c, "killcam_j1_sans_voile.png", "gros_plan_j1_sans_voile.png", b1)
    gp_plat = gros_plan(c, "killcam_j1_vue_de_dessus.png", "gros_plan_j1_vue_de_dessus.png", b1)
    gp_negatif = gros_plan(c, "killcam_j2_voile_negatif.png", "gros_plan_j2_voile_negatif.png", b2)
    for nom in sorted(os.listdir(c)):
        if nom.endswith(".png"):
            compresser(os.path.join(c, nom), os.path.join(c, nom), a.max_ko * 1024)
    etalon = re.search(r"BANC_ISO killcam etalon vue=j1 \(information[^)]*\) — (.+)", t)
    silhouette = "étalon absent"
    if etalon:
        noire = re.findall(r"(J\d), teinte noire : iso (\d+/\d+/\d+), vue de dessus (\d+/\d+/\d+)", etalon.group(1))
        silhouette = " · ".join("%s iso %s, 2D %s" % n for n in noire)
    general = {v: re.search(r"BANC_ISO killcam vue=%s verdict=(\S+ \S+)" % v, t) for v in ("j1", "j2")}
    cases = [
        (os.path.join(c, "killcam_j1.png"), "killcam iso, vue de J1 (local, hôte)",
         "%s · voile : %s" % (general["j1"].group(1) if general["j1"] else "relevé absent", verdict(t, "j1", "voile")), 1),
        (gp_j1, "gros plan, les deux fantômes portent les corps (sans voile)",
         "corps des fantômes : %s" % verdict(t, "j1", "corps"), 1),
        (gp_plat, "la même région en vue de dessus, lumières éteintes (×4)",
         "médianes, teinte noire : %s" % silhouette, 4),
        (os.path.join(c, "killcam_j2.png"), "killcam iso, vue de J2 (client)",
         "%s · voile : %s" % (general["j2"].group(1) if general["j2"] else "relevé absent", verdict(t, "j2", "voile")), 1),
        (gp_negatif, "voile forcé en négatif : il relit la vue iso, corps compris",
         "négatif de l'image avec corps, à 0,2 niveau près", 1),
        (os.path.join(c, "killcam_j2_noir.png"), "killcam iso, noir absolu (×8)", verdict(t, "j2", "noir"), 8),
    ]
    planche(cases, 3, "ISO5 — la killcam dans la vue iso",
            "Les fantômes portent les corps voxel · voile relu sur la vue iso · zoom en taille orthographique",
            os.path.join(ICI, "planche_iso5.jpg"), a.max_planche_ko)


if __name__ == "__main__":
    main()
