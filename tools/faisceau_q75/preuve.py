#!/usr/bin/env python3
"""Q75 À L'IMAGE (Adrien, 2026-09-30 20:17 : « A+d ») — le jugement et la planche du plan `loupe-faisceau-q75`
(`tools/loupe_faisceau_q75.gd`).

Pour chaque bloc (écran scindé : J1 à gauche, J2 à droite ; `fusee` en vue unique) :
- la scène tenue : les deux « avant » (av) et les deux « après » (ap) valent chacun leur jumeau à 1/255 près ;
- LE NOIR À L'ÉCRAN, AUCUNE FUITE : tout pixel noir (0, 0, 0) sans le rayon (s) l'est aussi après, et avant ; et, dans les
  vues qu'un voile d'éblouissement soulève (la torche du joueur tient le sien à 0,06 : aucun pixel n'y est à 0), le noir
  SOUS LE VOILE — les pixels au plancher de la vue sans rayon (canal le plus fort ≤ minimum + 1) — que le rayon ne doit pas
  toucher non plus (écart ≤ 1/255) ;
- ce que Q75 change, par vue : les pixels où le rayon d'avant ajoutait de la lumière et où celui d'après n'ajoute plus rien
  (coupés : la longueur, D), ceux où il en ajoute moins (atténués : le fondu), ceux qu'un volume tu par le juge d'avant
  retrouve (rendus : la fumée, A), et la lumière que le rayon ajoute encore (somme des luminances ajoutées, après / avant).
Pour le bloc `pixel` : les valeurs du pixel où le juge taillé s'écartait du disque de plus de 1/255, dans chaque mode.
Puis la planche : par classe et par lampe, la vue de J1 et celle de J2, avant, après et leur écart (×4).

    python3 tools/faisceau_q75/preuve.py <dossier des photos de la loupe> <dossier de sortie>

Code de sortie 1 si une fuite dans le noir est trouvée, ou si une scène n'a pas tenu.
"""
import glob
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ID = "loupe-faisceau-q75"
CLASSES = [("pompe", "le Terrassier", 192.0), ("sentinelle", "la Sentinelle", 499.2), ("arbalete", "le Braconnier", 672.0)]
LAMPES = [("j1", "lampe de J1"), ("j2", "lampe de J2")]
MODES_PIXEL = ["1b", "2j", "3n", "4n0", "5n1", "6n2", "7j30", "8b", "9ap", "10s"]
NOMS_PIXEL = {
    "1b": "juge en disque (B de l'allègement)", "2j": "juge taillé (J)", "3n": "sans juge, trois couches",
    "4n0": "sans juge, couche 0 (basse)", "5n1": "sans juge, couche 1", "6n2": "sans juge, couche 2 (haute)",
    "7j30": "juge taillé dilaté de 30 px", "8b": "juge en disque (encore)", "9ap": "après (A+D)", "10s": "sans rayon",
}


def charger(dossier):
    images = {}
    for f in glob.glob(os.path.join(dossier, "*-%s-*.png" % ID)):
        m = re.match(r"\d+-%s-(.+)-([0-9]+[a-z0-9]+)\.png$" % re.escape(ID), os.path.basename(f))
        if m:
            images.setdefault(m.group(1), {})[m.group(2)] = f
    return images


def lire(f):
    return np.asarray(Image.open(f).convert("RGB")).astype(np.int16)


def luminance(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def juger_bloc(nom, fichiers, scinde, lignes):
    av1, ap2, av3, ap4, s5 = [lire(fichiers[k]) for k in ["1av", "2ap", "3av", "4ap", "5s"]]
    ok = True
    tenue_av = int(np.abs(av1 - av3).max())
    tenue_ap = int(np.abs(ap2 - ap4).max())
    if tenue_av > 1 or tenue_ap > 1:
        ok = False
    lignes.append("## %s — scène tenue : avant contre avant %d/255, après contre après %d/255%s" % (
        nom, tenue_av, tenue_ap, "" if ok else "  ✗ LA SCÈNE A BOUGÉ"))
    h, w = s5.shape[:2]
    vues = [("J1", slice(0, w // 2)), ("J2", slice(w // 2, w))] if scinde else [("vue unique", slice(0, w))]
    fuites = 0
    rendus = {}
    for qui, cols in vues:
        s = s5[:, cols]
        av = av1[:, cols]
        ap = ap2[:, cols]
        noir = (s == 0).all(axis=2)
        fuite_ap = int((noir & ~(ap == 0).all(axis=2)).sum())
        fuite_av = int((noir & ~(av == 0).all(axis=2)).sum())
        fort = s.max(axis=2)
        plancher = fort <= int(fort.min()) + 1
        voile_ap = int((plancher & (np.abs(ap - s).max(axis=2) > 1)).sum())
        voile_av = int((plancher & (np.abs(av - s).max(axis=2) > 1)).sum())
        fuites += fuite_ap + voile_ap
        ajout_av = np.clip(luminance(av) - luminance(s), 0, None)
        ajout_ap = np.clip(luminance(ap) - luminance(s), 0, None)
        touche_av = np.abs(av - s).max(axis=2) > 1
        touche_ap = np.abs(ap - s).max(axis=2) > 1
        ecart = np.abs(ap - av).max(axis=2) > 1
        coupe = ecart & touche_av & ~touche_ap & ((av - s).max(axis=2) > 1)
        rendu = ecart & ~touche_ap & ((av - s).min(axis=2) < -1)
        attenue = ecart & touche_ap & ((av - ap).max(axis=2) > 1) & ((ap - av).max(axis=2) <= 1)
        autres = ecart & ~coupe & ~rendu & ~attenue
        rendus[qui] = (int(rendu.sum()), int((s - av)[rendu].max()) if rendu.any() else 0)
        lignes.append(
            "   %s : noir sans rayon %d px, fuites après %d, avant %d ; noir sous le voile (plancher %d/255) %d px, touchés "
            "après %d, avant %d ; le rayon touche %d px avant, %d après — %d coupés (la longueur), %d atténués (le fondu), "
            "%d rendus à l'image sans rayon (un volume que le juge d'avant taisait, jusqu'à %d/255), %d autres ; lumière "
            "ajoutée après / avant %.3f (%.0f / %.0f)" % (
                qui, int(noir.sum()), fuite_ap, fuite_av, int(fort.min()), int(plancher.sum()), voile_ap, voile_av,
                int(touche_av.sum()), int(touche_ap.sum()), int(coupe.sum()), int(attenue.sum()), rendus[qui][0],
                rendus[qui][1], int(autres.sum()), float(ajout_ap.sum()) / max(float(ajout_av.sum()), 1e-9),
                float(ajout_ap.sum()), float(ajout_av.sum())))
    if fuites:
        ok = False
        lignes.append("   ✗ %d pixel(s) noir(s) allumé(s) par le rayon d'après" % fuites)
    return ok, (av1, ap2, s5)


def bout_du_rayon(blocs, sortie):
    """Le bout du rayon, agrandi : pour chaque classe, la vue du porteur (lampe de J1 : la vue de J1), avant, après, sans
    rayon, recadrés autour des pixels que le fondu atténue (là où le rayon d'après s'éteint), ×1,5."""
    rangs = []
    for slug, libelle, longueur in CLASSES:
        nom = "%s-j1" % slug
        if nom not in blocs:
            continue
        av, ap, s = blocs[nom]
        w = av.shape[1] // 2
        av, ap, s = av[:, :w], ap[:, :w], s[:, :w]
        touche_ap = np.abs(ap - s).max(axis=2) > 1
        attenue = touche_ap & ((av - ap).max(axis=2) > 1)
        ys, xs = np.nonzero(attenue)
        if len(xs) == 0:
            continue
        cy, cx = int(np.median(ys)), int(np.median(xs))
        hh, ww = 150, 200
        y0 = min(max(cy - hh, 0), av.shape[0] - 2 * hh)
        x0 = min(max(cx - ww, 0), w - 2 * ww)
        crops = [Image.fromarray(np.clip(a[y0:y0 + 2 * hh, x0:x0 + 2 * ww], 0, 255).astype(np.uint8)).resize(
            (3 * ww, 3 * hh), Image.LANCZOS) for a in (av, ap, s)]
        rangs.append(("%s (0.7.1 : %.0f px) — vue de J1, sous sa torche : le bout du rayon, ×1,5" % (libelle, longueur),
                      crops))
    if not rangs:
        return None
    f_titre = police(18)
    f_petit = police(14)
    larg = rangs[0][1][0].width
    haut = rangs[0][1][0].height
    toile = Image.new("RGB", (larg * 3, 30 + len(rangs) * (26 + haut)), (24, 24, 24))
    dessin = ImageDraw.Draw(toile)
    for k, c in enumerate(["avant (34370f74)", "après (A+D)", "sans rayon"]):
        dessin.text((k * larg + 8, 6), c, fill=(230, 230, 230), font=f_titre)
    y = 30
    for titre, crops in rangs:
        dessin.text((8, y + 4), titre, fill=(255, 210, 120), font=f_petit)
        y += 26
        for k, c in enumerate(crops):
            toile.paste(c, (k * larg, y))
        y += haut
    chemin = os.path.join(sortie, "planche_q75_bout.jpg")
    toile.save(chemin, quality=90)
    return chemin


def juger_pixel(fichiers, lignes):
    im = {k: lire(fichiers[k]) for k in MODES_PIXEL if k in fichiers}
    if "1b" not in im or "2j" not in im:
        lignes.append("## pixel — images manquantes")
        return
    b, j, s = im["1b"], im["2j"], im.get("10s")
    lignes.append("## pixel — le juge taillé contre le disque (rayon long, le Terrassier, lampe de J1, écran scindé)")
    lignes.append("   la scène tenue : disque contre disque %d/255" % int(np.abs(b - im["8b"]).max()) if "8b" in im else "")
    d = np.abs(j - b).max(axis=2)
    ys, xs = np.nonzero(d > 1)
    lignes.append("   pixels où le juge taillé s'écarte du disque de plus de 1/255 : %d %s" % (
        len(xs), list(zip(xs.tolist(), ys.tolist()))[:10]))
    for nom_a, nom_b in [("7j30", "2j"), ("3n", "2j"), ("3n", "1b")]:
        if nom_a in im:
            dd = np.abs(im[nom_a] - im[nom_b]).max(axis=2)
            lignes.append("   %s contre %s : %d pixel(s) au-delà de 1/255 (au plus %d)" % (
                NOMS_PIXEL[nom_a], NOMS_PIXEL[nom_b], int((dd > 1).sum()), int(dd.max())))
    if s is not None:
        noir = (s == 0).all(axis=2)
        for k in ["1b", "2j", "3n", "9ap"]:
            if k in im:
                lignes.append("   noir sans rayon %d px ; %s en allume %d" % (
                    int(noir.sum()), NOMS_PIXEL[k], int((noir & ~(im[k] == 0).all(axis=2)).sum())))
    for x, y in list(zip(xs.tolist(), ys.tolist()))[:4]:
        lignes.append("   pixel (%d, %d), vue de J%d :" % (x, y, 1 if x < b.shape[1] // 2 else 2))
        for k in MODES_PIXEL:
            if k in im:
                lignes.append("      %-38s %s" % (NOMS_PIXEL[k], im[k][y, x].tolist()))
        for k in ["1b", "2j", "3n", "7j30"]:
            if k in im:
                lignes.append("      voisinage 5×5 (canal max), %-24s %s" % (NOMS_PIXEL[k][:24], [
                    [int(im[k][yy, xx].max()) for xx in range(x - 2, x + 3)] for yy in range(y - 2, y + 3)]))


def cellule(a, largeur):
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    return img.resize((largeur, int(img.height * largeur / img.width)), Image.LANCZOS)


def police(taille):
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(f):
            return ImageFont.truetype(f, taille)
    return ImageFont.load_default()


def planche(blocs, sortie):
    largeur = 320
    rangs = []
    for slug, libelle, longueur in CLASSES:
        for lampe, lib_lampe in LAMPES:
            nom = "%s-%s" % (slug, lampe)
            if nom not in blocs:
                continue
            av, ap, _s = blocs[nom]
            w = av.shape[1]
            cells = []
            for cols in [slice(0, w // 2), slice(w // 2, w)]:
                cells += [cellule(av[:, cols], largeur), cellule(ap[:, cols], largeur),
                          cellule(np.abs(ap[:, cols] - av[:, cols]) * 4, largeur)]
            titre = "%s (0.7.1 : %.0f px ; portée 728 px) — %s : J1 %s, J2 %s" % (
                libelle, longueur, lib_lampe, "sous sa torche" if lampe == "j1" else "dans le noir",
                "dans le noir" if lampe == "j1" else "sous sa torche")
            rangs.append((titre, cells))
    if "fusee" in blocs:
        av, ap, _s = blocs["fusee"]
        rangs.append(("Une fusée entre les joueurs, vue unique, le Terrassier, les deux lampes — la fumée hors du cône (A)",
                      [cellule(av, largeur * 2), cellule(ap, largeur * 2), cellule(np.abs(ap - av) * 4, largeur * 2)]))
    f_titre = police(18)
    f_petit = police(14)
    haut_titre = 26
    entete = 30
    hauteur = entete + sum(haut_titre + max(c.height for c in cells) for _t, cells in rangs)
    toile = Image.new("RGB", (largeur * 6, hauteur), (24, 24, 24))
    dessin = ImageDraw.Draw(toile)
    colonnes = ["J1 avant (34370f74)", "J1 après (A+D)", "J1 écart ×4", "J2 avant (34370f74)", "J2 après (A+D)",
                "J2 écart ×4"]
    for k, c in enumerate(colonnes):
        dessin.text((k * largeur + 8, 6), c, fill=(230, 230, 230), font=f_titre)
    y = entete
    for titre, cells in rangs:
        dessin.text((8, y + 4), titre, fill=(255, 210, 120), font=f_petit)
        y += haut_titre
        x = 0
        for c in cells:
            toile.paste(c, (x, y))
            x += c.width
        y += max(c.height for c in cells)
    toile.save(sortie, quality=90)
    return sortie


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    dossier, sortie = sys.argv[1], sys.argv[2]
    os.makedirs(sortie, exist_ok=True)
    images = charger(dossier)
    lignes = ["# Q75 à l'image — %s" % dossier]
    ok = True
    blocs = {}
    for nom in sorted(images):
        if nom == "pixel":
            continue
        fichiers = images[nom]
        if not all(k in fichiers for k in ["1av", "2ap", "3av", "4ap", "5s"]):
            lignes.append("## %s — prises manquantes : %s" % (nom, sorted(fichiers)))
            ok = False
            continue
        bon, trio = juger_bloc(nom, fichiers, nom != "fusee", lignes)
        ok = ok and bon
        blocs[nom] = trio
    if "pixel" in images:
        juger_pixel(images["pixel"], lignes)
    chemin = planche(blocs, os.path.join(sortie, "planche_q75.jpg"))
    lignes.append("planche : %s" % chemin)
    lignes.append("le bout du rayon : %s" % bout_du_rayon(blocs, sortie))
    lignes.append("VERDICT : %s" % ("✓ aucune fuite dans le noir, scènes tenues" if ok else "✗ voir ci-dessus"))
    texte = "\n".join(lignes)
    print(texte)
    with open(os.path.join(sortie, "preuve.txt"), "w") as f:
        f.write(texte + "\n")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
