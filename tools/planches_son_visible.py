#!/usr/bin/env python3
"""Compose les planches et la vidéo du son rendu visible depuis ce que le banc a écrit.

Chantier SON VISIBLE (0.8.0, Adrien, 2026-09-29 : « il faudrait que les liserés s'animent en
fonction du son »). Adrien juge sur image : le banc (`tools/banc_son_visible.gd`, sous Xvfb)
écrit des captures brutes et `vies.json` ; ce script en fait ce qu'on regarde.

    xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 \\
        --script res://tools/banc_son_visible.gd -- --sortie=/dossier/du/banc --led-murs-fige=0.3
    xvfb-run ... -- --sortie=/dossier/du/banc --seulement=video      # les images de la vidéo
    python3 tools/planches_son_visible.py /dossier/du/banc /dossier/de/sortie [--video]

Ce qu'il écrit, dans le dossier de sortie (jamais dans le dépôt) :

- `vie_<scénario>.png` — huit instants d'un même liseré (le demi-écran où il vit, sans le HUD),
  chacun avec son âge, sa présence, sa largeur et son niveau perçu, et dessous la courbe de sa
  vie : présence (0–1) et largeur (°) en fonction du temps, les huit instants repérés ;
- `fusillade_avant_apres.png` et `fusillade_detail.png` — les mêmes sons figés en mélange
  normal puis en mélange additif (Q52), avec ce que l'addition change en chiffres ;
- `liseres_seuls_melange_contre_addition.png` — un liseré seul sur un aplat noir, une lueur et
  un béton éclairé, dans les deux mélanges ;
- avec `--video` : `vie_des_liseres.mp4` (60 images par seconde, vitesse réelle) et
  `vie_des_liseres_quart_de_vitesse.mp4` ; l'arène est figée, seul le liseré vit.

Sans autre dépendance que Pillow et numpy ; la vidéo veut `imageio_ffmpeg` (son ffmpeg).
"""
import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

BANC = sys.argv[1]
SORTIE = sys.argv[2]
AVEC_VIDEO = "--video" in sys.argv
os.makedirs(SORTIE, exist_ok=True)

POLICE = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
POLICE_GRAS = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FOND = (14, 14, 17)
TEXTE = (232, 232, 228)
DISCRET = (150, 150, 146)
GRILLE = (52, 52, 58)
COULEUR_ALPHA = (244, 196, 92)
COULEUR_LARGEUR = (110, 190, 230)
COULEUR_NIVEAU = (170, 170, 170)


def police(taille, gras=False):
    return ImageFont.truetype(POLICE_GRAS if gras else POLICE, taille)


def texte_coupe(d, texte, f, largeur_max):
    """Coupe un texte en lignes qui tiennent dans `largeur_max` pixels."""
    mots = texte.split(" ")
    lignes = []
    courante = ""
    for m in mots:
        essai = (courante + " " + m).strip()
        if d.textlength(essai, font=f) <= largeur_max:
            courante = essai
        else:
            lignes.append(courante)
            courante = m
    if courante:
        lignes.append(courante)
    return lignes


def graphe(d, boite, vie, instants=None, curseur=None, titre=True):
    """Trace présence et largeur d'une vie dans `boite` = (x0, y0, x1, y1)."""
    x0, y0, x1, y1 = boite
    marge_g, marge_d, marge_h, marge_b = 52, 56, 50, 26
    gx0, gy0, gx1, gy1 = x0 + marge_g, y0 + marge_h, x1 - marge_d, y1 - marge_b
    courbe = vie["courbe"]
    duree = float(vie["duree"])
    f = police(15)
    d.rectangle((x0, y0, x1, y1), fill=(20, 20, 24))
    # Grille et axes
    for k in range(0, 6):
        y = gy1 - (gy1 - gy0) * k / 5.0
        d.line((gx0, y, gx1, y), fill=GRILLE, width=1)
        d.text((gx0 - 8, y - 8), "%.1f" % (k / 5.0), font=f, fill=COULEUR_ALPHA, anchor="ra")
        d.text((gx1 + 8, y - 8), "%d°" % (k * 36), font=f, fill=COULEUR_LARGEUR, anchor="la")
    pas_t = 0.1 if duree > 0.4 else 0.05
    t = 0.0
    while t <= duree + 1e-6:
        x = gx0 + (gx1 - gx0) * t / duree
        d.line((x, gy0, x, gy1), fill=GRILLE, width=1)
        d.text((x, gy1 + 4), "%.2f" % t, font=f, fill=DISCRET, anchor="ma")
        t += pas_t

    def xy(t_, v, vmax):
        return (gx0 + (gx1 - gx0) * t_ / duree, gy1 - (gy1 - gy0) * min(max(v / vmax, 0.0), 1.0))

    # Largeur, puis présence (par-dessus)
    pts_l = [xy(c[0], c[2], 180.0) for c in courbe]
    pts_a = [xy(c[0], c[1], 1.0) for c in courbe]
    if len(pts_l) > 1:
        d.line(pts_l, fill=COULEUR_LARGEUR, width=2)
    if len(pts_a) > 1:
        d.line(pts_a, fill=COULEUR_ALPHA, width=3)
    if instants:
        for i, ins in enumerate(instants):
            x, _ = xy(float(ins["age"]), 0.0, 1.0)
            d.line((x, gy0, x, gy1), fill=(200, 200, 200), width=1)
            d.ellipse((x - 10, gy0 - 22, x + 10, gy0 - 2), fill=(232, 232, 228))
            d.text((x, gy0 - 12), str(i + 1), font=police(14, True), fill=(10, 10, 10), anchor="mm")
    if curseur is not None:
        x, _ = xy(curseur, 0.0, 1.0)
        d.line((x, gy0, x, gy1), fill=(255, 255, 255), width=2)
        # Le point sur chaque courbe à cet instant
        proche = min(courbe, key=lambda c: abs(c[0] - curseur))
        for (val, vmax, coul) in ((proche[1], 1.0, COULEUR_ALPHA), (proche[2], 180.0, COULEUR_LARGEUR)):
            px, py = xy(curseur, val, vmax)
            d.ellipse((px - 5, py - 5, px + 5, py + 5), fill=coul, outline=(0, 0, 0))
    if titre:
        d.text((gx0, y0 + 3), "présence (opacité, 0–1)", font=f, fill=COULEUR_ALPHA)
        d.text((gx0 + 220, y0 + 3), "largeur (°)", font=f, fill=COULEUR_LARGEUR)
        d.text((gx0 + 320, y0 + 3), "temps en s depuis le départ du son", font=f, fill=DISCRET)


def planche_vie(vie):
    """Une planche : huit instants d'un même liseré + la courbe de sa vie."""
    inst = vie["instants"]
    largeur_tuile, hauteur_tuile = 480, 540
    marge, gap, legende_h = 12, 6, 44
    W = marge * 2 + 4 * largeur_tuile + 3 * gap
    entete = 104
    graphe_h = 300
    H = entete + 2 * (hauteur_tuile + legende_h) + graphe_h + marge * 3
    im = Image.new("RGB", (W, H), FOND)
    d = ImageDraw.Draw(im)
    d.text((marge, 10), vie["nom"].replace("_", " ").upper(), font=police(26, True), fill=TEXTE)
    lignes = texte_coupe(d, vie["legende"], police(19), W - 2 * marge)
    for i, l in enumerate(lignes):
        d.text((marge, 46 + 24 * i), l, font=police(19), fill=DISCRET)
    d.text((marge, 46 + 24 * len(lignes)),
           "durée du liseré %.2f s · présence au pic %.2f · largeur au pic %.1f° · salle : %s"
           % (vie["duree"], vie["pic_alpha"], vie["largeur_pic"], vie["salle"]), font=police(17), fill=TEXTE)
    for i, ins in enumerate(inst):
        col, lig = i % 4, i // 4
        x = marge + col * (largeur_tuile + gap)
        y = entete + lig * (hauteur_tuile + legende_h + gap)
        frame = Image.open(os.path.join(BANC, ins["image"])).convert("RGB")
        recadre = frame.crop((960, 0, 1920, 1080)).resize((largeur_tuile, hauteur_tuile), Image.LANCZOS)
        im.paste(recadre, (x, y))
        d.rectangle((x, y, x + largeur_tuile - 1, y + hauteur_tuile - 1), outline=(70, 70, 76))
        d.ellipse((x + 8, y + 8, x + 34, y + 34), fill=(232, 232, 228))
        d.text((x + 21, y + 21), str(i + 1), font=police(17, True), fill=(10, 10, 10), anchor="mm")
        d.text((x + 6, y + hauteur_tuile + 6),
               "t = %.3f s · présence %.2f · %.0f° · %.1f dB" % (ins["age"], ins["alpha"], ins["largeur"], ins["niveau"]),
               font=police(16), fill=TEXTE)
    gy = entete + 2 * (hauteur_tuile + legende_h + gap) + marge
    graphe(d, (marge, gy, W - marge, gy + graphe_h), vie, instants=inst)
    chemin = os.path.join(SORTIE, "vie_%s.png" % vie["nom"])
    im.save(chemin)
    print("planche", chemin, im.size)
    return chemin


def planches_vues(vies):
    return [planche_vie(v) for v in vies]


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def charge(nom):
    return np.asarray(Image.open(os.path.join(BANC, nom + ".png")).convert("RGB")).astype(int)


def fusillade(prefixe="fusillade", titre="la fusillade du plan 7 (éparpillée autour de J1)"):
    """Les mêmes sons figés en mélange normal puis additif, côte à côte, avec ce que ça change en chiffres."""
    a = os.path.join(BANC, "%s_melange.png" % prefixe)
    b = os.path.join(BANC, "%s_addition.png" % prefixe)
    if not (os.path.exists(a) and os.path.exists(b)):
        return
    m = Image.open(a).convert("RGB")
    ad = Image.open(b).convert("RGB")
    W, H = 1920, 540 + 150
    im = Image.new("RGB", (W, H), FOND)
    d = ImageDraw.Draw(im)
    im.paste(m.resize((960, 540), Image.LANCZOS), (0, 60))
    im.paste(ad.resize((960, 540), Image.LANCZOS), (960, 60))
    d.text((10, 8), "AVANT — mélange normal (les liserés se recouvrent)", font=police(24, True), fill=TEXTE)
    d.text((970, 8), "APRÈS — addition (Q52 : les couleurs s'additionnent, vers le blanc)", font=police(24, True), fill=TEXTE)
    d.line((960, 60, 960, 600), fill=(90, 90, 96), width=2)
    d.text((10, 608), titre, font=police(20, True), fill=COULEUR_ALPHA)
    # Les chiffres : ce que le liseré change dans chaque image.
    fond_p = os.path.join(BANC, "fusillade_fond.png")
    texte = ""
    ma, aa = charge("%s_melange" % prefixe), charge("%s_addition" % prefixe)
    if os.path.exists(fond_p):
        f = charge("fusillade_fond")
        touche = (np.abs(ma - f).max(axis=2) > 2) | (np.abs(aa - f).max(axis=2) > 2)

        def stats(x):
            t = touche
            blanc = ((x.min(axis=2) >= 190) & t).sum()
            sat = np.where(x.max(axis=2) > 0, (x.max(axis=2) - x.min(axis=2)) / np.maximum(x.max(axis=2), 1), 0)[t].mean()
            return lum(x)[t].mean(), sat, int(blanc), int(t.sum())
        lm, sm, bm, n = stats(ma)
        la, sa, ba, _ = stats(aa)
        texte = ("%d pixels de liseré · luminance moyenne %.0f → %.0f · saturation moyenne %.2f → %.2f · pixels quasi blancs %d → %d"
                 % (n, lm, la, sm, sa, bm, ba))
    d.text((10, 640), texte, font=police(19), fill=DISCRET)
    chemin = os.path.join(SORTIE, "%s_avant_apres.png" % prefixe)
    im.save(chemin)
    print("planche", chemin, texte)
    # Le détail : la fenêtre de 640×480 où l'addition change le plus l'image.
    diff = np.abs(aa - ma).sum(axis=2).astype(np.float64)
    ii = np.pad(diff, ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    meilleur, pos = -1.0, (0, 0)
    for y in range(0, 1080 - 480 + 1, 20):
        for x in range(0, 1920 - 640 + 1, 20):
            v = ii[y + 480, x + 640] - ii[y, x + 640] - ii[y + 480, x] + ii[y, x]
            if v > meilleur:
                meilleur, pos = v, (x, y)
    x, y = pos
    det = Image.new("RGB", (1300, 540), FOND)
    dd = ImageDraw.Draw(det)
    dd.text((10, 6), "DÉTAIL — là où les liserés se recouvrent le plus (fenêtre 640×480, à taille réelle)", font=police(20, True), fill=TEXTE)
    for k, (nom, label) in enumerate((("%s_melange" % prefixe, "mélange normal"), ("%s_addition" % prefixe, "addition"))):
        crop = Image.open(os.path.join(BANC, nom + ".png")).convert("RGB").crop((x, y, x + 640, y + 480))
        det.paste(crop, (10 + k * 650, 44))
        dd.text((14 + k * 650, 44 + 486), label, font=police(18), fill=TEXTE)
    det.save(os.path.join(SORTIE, "%s_detail.png" % prefixe))


CAS_SOLO = [("tir", "un coup de pistolet à 520 px"), ("pas_accroupi", "un pas accroupi à 110 px"),
            ("coin", "un pas derrière un mur, plein coin haut-droit (250 px)")]
FONDS_SOLO = [("arene", "arène telle quelle"), ("noir", "aplat NOIR"), ("lueur", "lueur (3 %)"),
              ("eclaire", "béton éclairé (13 %)")]


def solo_images(nom, fond):
    """Le fond seul, le mélange, l'addition d'un cas du banc, et le masque des pixels « de liseré ».

    Un pixel de liseré diffère du fond seul de plus de 2/255 dans l'un des deux mélanges, dans la
    moitié droite de l'écran, ET son fond est l'aplat lui-même (à 8/255 près) : le tireté de visée, un
    mur, le corps de J1 en sont exclus — sans quoi leur pixel le plus clair serait pris pour le cœur
    du liseré (c'est arrivé au premier jet du tableau : un « cœur » de 83 pris sur le tireté, à 62).
    """
    f = charge("solo_%s_%s_fond" % (nom, fond))
    m = charge("solo_%s_%s_melange" % (nom, fond))
    a = charge("solo_%s_%s_addition" % (nom, fond))
    droite = np.zeros(f.shape[:2], bool)
    droite[:, 960:] = True
    plat = np.abs(f - f[100, 1800]).max(axis=2) <= 8
    touche = ((np.abs(m - f).max(axis=2) > 2) | (np.abs(a - f).max(axis=2) > 2)) & droite & plat
    return f, m, a, touche


def coeur_rgb(x, touche):
    """Le pixel le plus clair du liseré, en (r, g, b)."""
    l = np.where(touche, lum(x), -1)
    y, x_ = np.unravel_index(np.argmax(l), l.shape)
    return tuple(int(v) for v in x[y, x_])


def fenetre_solo(nom, l, h):
    """Où poser une fenêtre l×h (1 pixel pour 1 pixel) pour y voir le liseré : celle, dans la moitié
    droite de l'écran, où la somme de ce que le liseré ajoute au fond est maximale, tous fonds confondus."""
    poids = np.zeros((1080, 1920))
    for fond, _ in FONDS_SOLO:
        if not os.path.exists(os.path.join(BANC, "solo_%s_%s_melange.png" % (nom, fond))):
            continue
        f, m, a, touche = solo_images(nom, fond)
        poids += np.clip(lum(m) - lum(f), 0, None) * touche
    ii = np.pad(poids, ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    meilleur, pos = -1.0, (1920 - l, 0)
    for y in range(0, 1080 - h + 1, 10):
        for x in range(960, 1920 - l + 1, 10):
            v = ii[y + h, x + l] - ii[y, x + l] - ii[y + h, x] + ii[y, x]
            if v > meilleur:
                meilleur, pos = v, (x, y)
    return pos


def solo():
    """Un liseré seul : l'arène, un aplat noir, une lueur, un béton éclairé — mélange puis addition.

    Chaque tuile est une fenêtre de 450×360 prise TELLE QUELLE (sans réduction : un liseré de 6 px à
    16 % d'opacité ne survit pas à un rééchantillonnage), posée là où le liseré se trouve ; sa légende
    donne le pixel le plus clair du liseré dans cette image.
    """
    if not os.path.exists(os.path.join(BANC, "solo_tir_noir_melange.png")):
        return
    tuile_l, tuile_h = 450, 360
    marge = 12
    W = marge * 2 + 4 * tuile_l + 3 * 6
    H = 60 + len(CAS_SOLO) * (2 * (tuile_h + 26) + 44) + marge
    im = Image.new("RGB", (W, H), FOND)
    d = ImageDraw.Draw(im)
    d.text((marge, 10), "UN LISERÉ SEUL — mélange normal (haut) contre addition (bas), pixels d'origine", font=police(24, True), fill=TEXTE)
    y = 56
    for nom, legende in CAS_SOLO:
        if not os.path.exists(os.path.join(BANC, "solo_%s_noir_melange.png" % nom)):
            continue
        d.text((marge, y), legende, font=police(20, True), fill=COULEUR_ALPHA)
        y += 32
        fx0, fy0 = fenetre_solo(nom, tuile_l, tuile_h)
        for additif in ("melange", "addition"):
            for col, (fond, nom_fond) in enumerate(FONDS_SOLO):
                img = Image.open(os.path.join(BANC, "solo_%s_%s_%s.png" % (nom, fond, additif))).convert("RGB")
                im.paste(img.crop((fx0, fy0, fx0 + tuile_l, fy0 + tuile_h)), (marge + col * (tuile_l + 6), y))
                f, m, a, touche = solo_images(nom, fond)
                c = coeur_rgb(m if additif == "melange" else a, touche) if touche.any() else (0, 0, 0)
                d.text((marge + col * (tuile_l + 6) + 6, y + tuile_h + 3),
                       "%s · %s · cœur (%d,%d,%d)" % (nom_fond, "mélange" if additif == "melange" else "ADDITION", *c),
                       font=police(16), fill=TEXTE)
            y += tuile_h + 26
        y += 18
    chemin = os.path.join(SORTIE, "liseres_seuls_melange_contre_addition.png")
    im.crop((0, 0, W, min(H, y + marge))).save(chemin)
    print("planche", chemin, im.size)
    chiffres_solo()


def chiffres_solo():
    """Ce que l'addition change à un liseré SEUL, en chiffres : `liseres_seuls_chiffres.txt`."""
    lignes = ["Ce que l'addition change à un liseré seul (banc sous Xvfb, moitié droite de l'écran, HUD retiré).",
              "Un pixel « de liseré » est un pixel qui diffère du fond seul de plus de 2/255 dans l'un des deux mélanges,",
              "ET dont le fond est l'aplat lui-même (à 8/255 près) : le tireté de visée, un mur, le corps de J1 en sont exclus,",
              "sans quoi leur pixel le plus clair serait pris pour le cœur du liseré (c'est arrivé au premier jet du tableau).",
              ""]
    entete = "%-13s %-8s %-10s | %-17s | %-17s | %-9s | %-12s | %s" % (
        "son", "fond", "fond RGB", "cœur mélange", "cœur addition", "saturés", "Δ lum moyen", "|add − mél| max (fond noir pur)")
    lignes.append(entete)
    for nom, _ in CAS_SOLO:
        for fond, _n in FONDS_SOLO:
            if not os.path.exists(os.path.join(BANC, "solo_%s_%s_addition.png" % (nom, fond))):
                continue
            f, m, a, touche = solo_images(nom, fond)
            if not touche.any():
                continue

            def sat(x):
                return int(((x.max(axis=2) >= 255) & touche).sum())
            noir_pur = touche & (f.max(axis=2) < 4)
            ecart_noir = int(np.abs(a - m)[noir_pur].max()) if noir_pur.any() else -1
            lignes.append("%-13s %-8s %-10s | %-17s | %-17s | %4d/%-4d | %+6.1f       | %s" % (
                nom, fond, "(%d,%d,%d)" % tuple(int(v) for v in f[100, 1800]),
                "(%d,%d,%d)" % coeur_rgb(m, touche), "(%d,%d,%d)" % coeur_rgb(a, touche), sat(m), sat(a),
                (lum(a) - lum(m))[touche].mean(), ("%d sur %d px" % (ecart_noir, int(noir_pur.sum()))) if ecart_noir >= 0 else "—"))
    texte = "\n".join(lignes) + "\n"
    open(os.path.join(SORTIE, "liseres_seuls_chiffres.txt"), "w", encoding="utf-8").write(texte)
    print(texte)


def video(vies):
    """Une vidéo à 60 images par seconde : l'arène figée, le liseré qui vit, sa courbe dessous."""
    ffmpeg = subprocess.check_output([sys.executable, "-c",
                                      "import imageio_ffmpeg; print(imageio_ffmpeg.get_ffmpeg_exe())"]).decode().strip()
    dossier_images = os.path.join(SORTIE, "_images_video")
    os.makedirs(dossier_images, exist_ok=True)
    n_total = 0
    W, H = 1280, 900
    for vie in vies:
        rep = os.path.join(BANC, "video_" + vie["nom"])
        if not os.path.isdir(rep):
            continue
        fichiers = sorted(f for f in os.listdir(rep) if f.endswith(".png"))
        # Un titre de 1,2 s pour lire de quoi il s'agit.
        titre = Image.new("RGB", (W, H), FOND)
        d = ImageDraw.Draw(titre)
        d.text((W // 2, 300), vie["nom"].replace("_", " ").upper(), font=police(46, True), fill=TEXTE, anchor="mm")
        for i, l in enumerate(texte_coupe(d, vie["legende"], police(26), W - 160)):
            d.text((W // 2, 380 + 36 * i), l, font=police(26), fill=DISCRET, anchor="mm")
        d.text((W // 2, 560), "l'arène est figée, seul le liseré vit — vitesse réelle, 60 images par seconde", font=police(20), fill=DISCRET, anchor="mm")
        for k in range(72):
            titre.save(os.path.join(dossier_images, "v_%05d.png" % n_total))
            n_total += 1
        for k, nom in enumerate(fichiers):
            frame = Image.open(os.path.join(rep, nom)).convert("RGB")
            im = Image.new("RGB", (W, H), FOND)
            im.paste(frame, (0, 0))
            d = ImageDraw.Draw(im)
            t = k / 60.0
            # L'état à cet instant, lu dans la courbe du banc.
            proche = min(vie["courbe"], key=lambda c: abs(c[0] - t)) if vie["courbe"] else None
            etat = ""
            if proche is not None and abs(proche[0] - t) < 0.02:
                etat = "présence %.2f · largeur %.0f° · niveau perçu %.1f dB" % (proche[1], proche[2], proche[4])
            d.text((14, 728), "%s   t = %.2f s   %s" % (vie["nom"].replace("_", " "), t, etat), font=police(20, True), fill=TEXTE)
            graphe(d, (10, 758, W - 10, H - 8), vie, curseur=t, titre=False)
            im.save(os.path.join(dossier_images, "v_%05d.png" % n_total))
            n_total += 1
        # Un temps mort de 0,4 s pour reprendre son souffle.
        for k in range(24):
            vide = Image.new("RGB", (W, H), FOND)
            vide.save(os.path.join(dossier_images, "v_%05d.png" % n_total))
            n_total += 1
    if n_total == 0:
        return
    mp4 = os.path.join(SORTIE, "vie_des_liseres.mp4")
    subprocess.check_call([ffmpeg, "-y", "-loglevel", "error", "-framerate", "60", "-i",
                           os.path.join(dossier_images, "v_%05d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
                           "-crf", "18", mp4])
    print("vidéo", mp4, "%d images" % n_total)
    # Le même au quart de vitesse (chaque image tenue quatre fois) pour regarder image par image.
    lent = os.path.join(SORTIE, "vie_des_liseres_quart_de_vitesse.mp4")
    subprocess.check_call([ffmpeg, "-y", "-loglevel", "error", "-framerate", "15", "-i",
                           os.path.join(dossier_images, "v_%05d.png"), "-r", "60", "-c:v", "libx264", "-pix_fmt", "yuv420p",
                           "-crf", "18", lent])
    print("vidéo", lent)


if __name__ == "__main__":
    vies_json = os.path.join(BANC, "vies.json")
    vies = json.load(open(vies_json)) if os.path.exists(vies_json) else []
    planches_vues(vies)
    fusillade()
    fusillade("fusillade_dense", "une fusillade DENSE : un tir, cinq impacts, deux ricochets, un coup au but, tous dans un secteur de 40°")
    solo()
    if AVEC_VIDEO:
        video(vies)
