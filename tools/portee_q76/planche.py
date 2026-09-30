#!/usr/bin/env python3
"""Q76 À L'IMAGE (Adrien, 2026-09-30 vers 22:58 : « En fait diminuons la portée des lampe au maximum visible par le joueur en
hauteur et largeur (le minimum des deux) ») — le jugement et la planche de la famille `q76` de `tools/banc_lumieres.gd`.

Chaque scène a trois photos au même cadrage : AVANT (la règle de L1, la portée au coin), APRÈS (Q76, au bord le plus proche),
et SANS TORCHE (le noir de référence). Pour chacune, par vue rendue :
- LE NOIR INTACT : aucun pixel noir (0, 0, 0) d'avant n'est allumé après loin de la lumière d'avant — la portée ne fait
  que raccourcir, mais le cookie, remis à une autre échelle, déplace ce qu'il dessine près de la lampe : le bord crénelé
  du cône bouge d'une fraction de texel, et la silhouette des corps, qui respirent, d'un pixel (les pixels allumés à 3 px
  au plus de la lumière d'avant : « au bord »), et la rampe du cookie au pied du cône se rapproche de l'émetteur dans le
  rapport des portées (celle du Braconnier, alpha de 20 à 72/255 sur ses 17 premiers texels, avance de 8,6 px de monde :
  les pixels allumés à 3 à 8 px de la lumière d'avant, « décalés par l'échelle », listés un à un). Plus loin que 8 px,
  c'est une fuite. Le banc met l'écran à nu pour ces photos — ni voile d'éblouissement, ni HUD, ni poussière du
  faisceau (voir `_plans_q76`) : une vue sans aucun pixel noir est donc une erreur du banc, pas un noir à juger ;
- ce qui s'éclaircit : les pixels plus clairs après qu'avant de plus de 1/255, à plus de 8 px de la lumière d'avant (pour
  information : une portée plus courte n'a rien à éclaircir si loin) ;
- jusqu'où la torche éclaire : la ligne la plus haute (et la colonne la plus à droite) où elle ajoute encore de la lumière au
  noir de référence, avant et après ;
- les mesures du banc (`_mesures`) : la portée, le bord dans la visée, ce que le faisceau verse encore au bord et
  l'éblouissement, pour J1 et J2 ;
- J1 = J2 : par classe, la vue unique de J1 et celle de J2, visée vers le haut — mesures et étendue.
Puis la planche : avant, après, sans torche et |après − avant| × 3, scène par scène.

    python3 tools/portee_q76/planche.py <dossier du banc> <dossier de sortie>

Code de sortie 1 si un pixel noir s'allume à plus de 8 px de la lumière d'avant, si une vue n'a aucun noir, ou si J1 ≠ J2.
"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SEUIL = 3  # un pixel « éclairé par la torche » : l'image avec torche dépasse le noir de référence de plus de 3/255


def lire(chemin):
    return np.asarray(Image.open(chemin).convert("RGB")).astype(np.int16)


def police(taille):
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(f):
            return ImageFont.truetype(f, taille)
    return ImageFont.load_default()


def plans(dossier):
    lignes = {}
    with open(os.path.join(dossier, "plans.txt")) as f:
        for l in f:
            bouts = l.rstrip("\n").split("\t")
            if len(bouts) >= 2 and bouts[0].startswith("q76_"):
                lignes[bouts[0]] = (bouts[1], bouts[2] if len(bouts) > 2 else "")
    return lignes


def dilate(masque, r):
    """Le masque élargi de `r` pixels dans toutes les directions (sans scipy)."""
    out = masque.copy()
    h, w = masque.shape
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            decale = np.zeros_like(masque)
            decale[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = \
                masque[max(-dy, 0):h + min(-dy, 0), max(-dx, 0):w + min(-dx, 0)]
            out |= decale
    return out


def etendue(avec, sans):
    """(ligne la plus haute, colonne la plus à droite, pixels) où la torche ajoute plus de SEUIL au noir de référence."""
    ajout = (avec - sans).max(axis=2) > SEUIL
    ys, xs = np.nonzero(ajout)
    if len(ys) == 0:
        return (-1, -1, 0)
    return (int(ys.min()), int(xs.max()), int(ajout.sum()))


def mesures_par_joueur(texte):
    """{1: (portée, bord, faisceau au bord), 2: …} lus dans la ligne de mesures du banc."""
    out = {}
    for m in re.finditer(r"J(\d) \S+ portée (\d+) px, bord à (\d+|inf) px, faisceau au bord ([0-9.]+)"
                         r"(?:, éblouissement ([0-9.]+))?", texte):
        out[int(m.group(1))] = (float(m.group(2)), float(m.group(3)) if m.group(3) != "inf" else float("inf"),
                                float(m.group(4)), float(m.group(5)) if m.group(5) else float("nan"))
    return out


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    dossier, sortie = sys.argv[1], sys.argv[2]
    os.makedirs(sortie, exist_ok=True)
    tout = plans(dossier)
    # Dans l'ordre de la lecture : le Terrassier, la Sentinelle, le Braconnier ; la vue unique de J1 puis celle de J2 (visée
    # vers le haut), la vue unique de J1 vers le coin, puis l'écran scindé.
    ordre_classes = ["pompe", "sentinelle", "arbalete"]
    ordre_plans = ["unique_j1_haut", "unique_j2_haut", "unique_j1_coin", "scinde_haut"]

    def rang(scene):
        bouts = scene.split("_", 2)
        classe, plan = bouts[1], bouts[2] if len(bouts) > 2 else ""
        return (ordre_classes.index(classe) if classe in ordre_classes else 99,
                ordre_plans.index(plan) if plan in ordre_plans else 99, scene)

    scenes = sorted({re.sub(r"_(1avant|2apres|3noir)$", "", n) for n in tout}, key=rang)
    lignes = ["# Q76 à l'image — la famille `q76` de `tools/banc_lumieres.gd` (dossier « %s »), jugée par "
              "`tools/portee_q76/planche.py`" % os.path.basename(os.path.normpath(dossier))]
    ok = True
    rangs = []
    etendues = {}
    for scene in scenes:
        noms = [scene + s for s in ["_1avant", "_2apres", "_3noir"]]
        if not all(n in tout for n in noms):
            lignes.append("## %s — photos manquantes" % scene)
            ok = False
            continue
        av, ap, noir = [lire(os.path.join(dossier, n + ".png")) for n in noms]
        h, w = av.shape[:2]
        scinde = "scinde" in scene
        vues = [("J1", slice(0, w // 2)), ("J2", slice(w // 2, w))] if scinde else [
            ("J2" if "_j2_" in scene else "J1", slice(0, w))]
        lignes.append("## %s — %s" % (scene, tout[noms[0]][0].split(" — ")[0]))
        for qui, cols in vues:
            a, p, n = av[:, cols], ap[:, cols], noir[:, cols]
            # La lumière d'avant, élargie de 3 px (le bord du cône) et de 8 px (ce que l'échelle déplace au pied du cône).
            lumiere_avant = (a - n).max(axis=2) > SEUIL
            bord = dilate(lumiere_avant, 3)
            bord8 = dilate(lumiere_avant, 8)
            noirs_avant = (a == 0).all(axis=2)
            allumes = noirs_avant & ~(p == 0).all(axis=2)
            fuites = int((allumes & ~bord8).sum())
            au_bord = int((allumes & bord).sum())
            max_bord = int(p[allumes & bord].max()) if au_bord else 0
            decales = allumes & bord8 & ~bord
            if fuites:
                ok = False
            if not noirs_avant.any():
                ok = False
                lignes.append("   ✗ %s : aucun pixel noir avant — le voile n'est pas masqué ?" % qui)
            plus = ((p - a).max(axis=2) > 1) & ~bord8
            max_plus = int((p - a)[plus].max()) if plus.any() else 0
            e_av = etendue(a, n)
            e_ap = etendue(p, n)
            etendues[(scene, qui)] = (e_av, e_ap)
            lignes.append(
                "   %s : noirs avant %d px, allumés après : %d au bord (au plus %d/255), %d décalés par l'échelle, "
                "%d fuites ; éclaircis après loin de la lumière d'avant %d px (au plus +%d/255) ; la torche éclaire %d px "
                "avant, %d après ; ligne la plus haute éclairée : %d avant, %d après (0 = le bord du haut) ; colonne la plus "
                "à droite : %d avant, %d après (sur %d)" % (
                    qui, int(noirs_avant.sum()), au_bord, max_bord, int(decales.sum()), fuites, int(plus.sum()), max_plus,
                    e_av[2], e_ap[2], e_av[0], e_ap[0], e_av[1], e_ap[1], a.shape[1]))
            if decales.any():
                ys, xs = np.nonzero(decales)
                x0 = cols.start or 0
                lignes.append("      décalés par l'échelle : %s" % ", ".join(
                    "(%d, %d) %s" % (int(x) + x0, int(y), "/".join(str(int(c)) for c in p[y, x]))
                    for y, x in zip(ys, xs)))
        for n in noms[:2]:
            m = mesures_par_joueur(tout[n][1])
            lignes.append("   %s : %s" % ("avant" if n.endswith("avant") else "après", " ; ".join(
                "J%d portée %.0f, bord %.0f, au bord %.3f, éblouissement %.3f" % (k, v[0], v[1], v[2], v[3])
                for k, v in sorted(m.items()))))
        m_av, m_ap = mesures_par_joueur(tout[noms[0]][1]), mesures_par_joueur(tout[noms[1]][1])
        chiffres = " ; ".join("J%d : bord dans la visée à %.0f px, le faisceau y verse %s avant, %s après" % (
            k, m_ap[k][1], ("%.3f" % m_av[k][2]).replace(".", ","), ("%.3f" % m_ap[k][2]).replace(".", ","))
            for k in sorted(m_ap) if k in m_av)
        rangs.append((scene, "%s — %s" % (tout[noms[0]][0].split(" — ")[0], chiffres), av, ap, noir))
    # J1 = J2 : la vue unique de chacun, visée vers le haut, même classe, même point de la carte.
    lignes.append("## J1 = J2 — vue unique (×1,5), visée vers le haut, chacun à la même place")
    for scene in scenes:
        if not scene.endswith("_unique_j1_haut"):
            continue
        jumelle = scene.replace("_j1_", "_j2_")
        if (scene, "J1") not in etendues or (jumelle, "J2") not in etendues:
            continue
        m1 = mesures_par_joueur(tout[scene + "_2apres"][1]).get(1)
        m2 = mesures_par_joueur(tout[jumelle + "_2apres"][1]).get(2)
        e1, e2 = etendues[(scene, "J1")][1], etendues[(jumelle, "J2")][1]
        pareil = m1 is not None and m2 is not None and m1[:3] == m2[:3]
        if not pareil:
            ok = False
        lignes.append("   %s : après, J1 portée %s, bord %s, au bord %s — J2 portée %s, bord %s, au bord %s %s ; ligne la plus "
                      "haute éclairée J1 %d, J2 %d ; la torche éclaire J1 %d px, J2 %d px" % (
                          scene.split("_")[1], *(("%.0f" % m1[0], "%.0f" % m1[1], "%.3f" % m1[2]) if m1 else ("?",) * 3),
                          *(("%.0f" % m2[0], "%.0f" % m2[1], "%.3f" % m2[2]) if m2 else ("?",) * 3),
                          "✓" if pareil else "✗", e1[0], e2[0], e1[2], e2[2]))
    # La planche : une ligne par scène — avant, après, sans torche, |après − avant| × 3.
    largeur = 480
    f_titre = police(18)
    f_petit = police(14)
    cellules = []
    for scene, titre, av, ap, noir in rangs:
        ims = [av, ap, noir, np.abs(ap - av) * 3]
        cells = []
        for im in ims:
            img = Image.fromarray(np.clip(im, 0, 255).astype(np.uint8))
            cells.append(img.resize((largeur, int(img.height * largeur / img.width)), Image.LANCZOS))
        cellules.append((titre, cells))
    if cellules:
        haut = cellules[0][1][0].height
        toile = Image.new("RGB", (largeur * 4, 30 + len(cellules) * (26 + haut)), (24, 24, 24))
        d = ImageDraw.Draw(toile)
        for k, c in enumerate(["AVANT — L1, la portée au coin (728 px)", "APRÈS — Q76, au bord le plus proche (468 px)",
                               "sans torche", "|après − avant| × 3"]):
            d.text((k * largeur + 8, 6), c, fill=(230, 230, 230), font=f_titre)
        y = 30
        for titre, cells in cellules:
            d.text((8, y + 4), titre, fill=(255, 210, 120), font=f_petit)
            y += 26
            for k, c in enumerate(cells):
                toile.paste(c, (k * largeur, y))
            y += haut
        chemin = os.path.join(sortie, "planche_q76.jpg")
        toile.save(chemin, quality=88)
        lignes.append("planche : planche_q76.jpg")
    lignes.append("VERDICT : %s" % ("✓ aucun pixel noir allumé loin de la lumière d'avant ; J1 = J2" if ok
                                      else "✗ voir ci-dessus"))
    texte = "\n".join(lignes)
    print(texte)
    with open(os.path.join(sortie, "preuve.txt"), "w") as f:
        f.write(texte + "\n")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
