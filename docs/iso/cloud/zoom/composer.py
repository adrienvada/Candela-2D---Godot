#!/usr/bin/env python3
"""Q15 — compose les livrables du zoom du duel à partir des prises et du journal de `tools/banc_zoom_q15.tscn`.

    python3 docs/iso/cloud/zoom/composer.py --captures <dossier du banc> --journal <journal du banc>

Écrit dans docs/iso/cloud/zoom/ : les prises en JPEG (qualité 85), un schéma « jusqu'où voit un joueur » par carte,
et `chiffres.md` (les tableaux repris dans RAPPORT.md). Aucune dépendance au jeu : les chiffres viennent des lignes
`BANC_ZOOM` (vraie caméra iso pour J1, formules du jeu pour J2 en vue unique), et la taille du corps est relevée
AUSSI sur l'image (la silhouette de soi de J1, toujours dessinée en bleu).
"""
import argparse
import json
import math
import os
import re

from PIL import Image, ImageDraw, ImageFont

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(os.path.join(ICI, "..", "..", "..", ".."))
CARTES = {
    "cloitre": ("assets/maps/map_001_le_cloitre.json", "Le Cloître"),
    "croisee": ("assets/maps/map_003_la_croisee.json", "La Croisée"),
}
ZOOMS = [1.25, 1.5, 1.75, 2.0]
COULEURS = {1.25: (90, 200, 120), 1.5: (240, 240, 240), 1.75: (240, 160, 60), 2.0: (230, 70, 70)}
DEVANT_V = 540.0 + 162.0
DEVANT_H = 960.0 + 162.0 / math.sin(math.radians(52.0))
LARGEUR_ISO = 1920.0 * math.sin(math.radians(52.0))  # 1513 px de monde au zoom 1, profondeur 1080


def lire_journal(chemin):
    scenes, prises, classes, reglages = {}, [], {}, ""
    for ligne in open(chemin, encoding="utf-8", errors="replace"):
        ligne = ligne.strip()
        if ligne.startswith("BANC_ZOOM reglages"):
            reglages = ligne
        elif ligne.startswith("BANC_ZOOM classe"):
            m = re.search(r"nom=(\S+) torch_scale=([\d.]+) demi_angle=([\d.]+) portee_px=([\d.]+)", ligne)
            classes[m.group(1)] = (float(m.group(2)), float(m.group(3)), float(m.group(4)))
        elif ligne.startswith("BANC_ZOOM scene"):
            carte = re.search(r"carte=(\w+)", ligne).group(1)
            v = lambda k: tuple(float(x) for x in re.search(k + r"=\(([-\d.e]+), ([-\d.e]+)\)", ligne).groups())
            scenes[carte] = {"j1": v("j1"), "v1": v("visee_j1"), "j2": v("j2"), "v2": v("visee_j2"),
                             "portee": float(re.search(r"portee=([\d.]+)", ligne).group(1)),
                             "demi_angle": float(re.search(r"demi_angle=([\d.]+)", ligne).group(1))}
        elif ligne.startswith("BANC_ZOOM prise"):
            tete, *joueurs = ligne.split(" | ")
            p = dict(re.findall(r"(\w+)=(\S+)", tete))
            p["zoom"] = float(p["zoom"])
            for j in joueurs:
                pid = j.split()[0]
                d = dict(re.findall(r"(\w+)=(\S+)", j))
                d["_brut"] = j
                d["coins"] = [tuple(float(a) for a in c.split(";")) for c in d["coins"].strip("[]").split(",")]
                p[pid] = d
            prises.append(p)
    return reglages, classes, scenes, prises


def murs(carte):
    d = json.load(open(os.path.join(RACINE, CARTES[carte][0])))
    t = float(d.get("tile_size", 35))
    rects = []
    for run in d["walls"].strip(";").split(";"):
        x, y, n = (int(a) for a in run.split(","))
        rects.append((x * t, y * t, (x + n) * t, (y + 1) * t))
    return rects, (d["grid_size"]["x"] * t, d["grid_size"]["y"] * t)


def silhouette(img, pied):
    """La silhouette de soi de J1 (bleue) autour de son pied à l'écran : sa boîte, en pixels de l'image."""
    px = img.load()
    x0, y0 = int(pied[0]), int(pied[1])
    boite = None
    for y in range(max(0, y0 - 200), min(img.height, y0 + 80)):
        for x in range(max(0, x0 - 120), min(img.width, x0 + 120)):
            r, g, b = px[x, y][:3]
            if b > 100 and b > r + 30 and g > r + 10:
                boite = (x, y, x + 1, y + 1) if boite is None else (
                    min(boite[0], x), min(boite[1], y), max(boite[2], x + 1), max(boite[3], y + 1))
    return boite


def en_jpeg(src, dst):
    Image.open(src).convert("RGB").save(dst, "JPEG", quality=85, optimize=True)


def police(taille):
    for chemin in [os.path.join(RACINE, "assets/fonts/Oxanium.ttf"), "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(chemin):
            return ImageFont.truetype(chemin, taille)
    return ImageFont.load_default()


def schema(carte, scene, prises, classes, sortie):
    """Vue de dessus de la carte : les murs, le cône de J1 et la portée des classes, et l'empreinte au sol de
    l'écran de J1 à chaque zoom (la vraie caméra iso, lacet 45° : un losange dans le repère de la carte)."""
    rects, (lx, ly) = murs(carte)
    marge, echelle = 380.0, 0.62
    w, h = int((lx + 2 * marge) * echelle), int((ly + 2 * marge) * echelle)
    im = Image.new("RGB", (w, h + 70), (14, 14, 18))
    dr = ImageDraw.Draw(im, "RGBA")
    pt = police(15)
    P = lambda x, y: ((x + marge) * echelle, (y + marge) * echelle)
    dr.rectangle([*P(0, 0), *P(lx, ly)], fill=(34, 32, 30))
    for (a, b, c, d) in rects:
        dr.rectangle([*P(a, b), *P(c, d)], fill=(95, 88, 80))
    j1, v1, j2 = scene["j1"], scene["v1"], scene["j2"]
    # Portées des classes, en cercles pointillés autour de J1 ; le cône du pistolet plein.
    for nom, (_, _, portee) in sorted(classes.items(), key=lambda kv: kv[1][2]):
        r = portee * echelle
        cx, cy = P(*j1)
        for k in range(0, 360, 6):
            a0, a1 = math.radians(k), math.radians(k + 3)
            dr.line([cx + r * math.cos(a0), cy + r * math.sin(a0), cx + r * math.cos(a1), cy + r * math.sin(a1)],
                    fill=(200, 170, 110, 150), width=1)
        dr.text((cx + r * 0.72 + 3, cy + r * 0.69), "%s %.0f px" % (nom, portee), fill=(200, 170, 110), font=pt)
    ang = math.atan2(v1[1], v1[0])
    da = math.radians(scene["demi_angle"])
    cone = [P(*j1)] + [P(j1[0] + scene["portee"] * math.cos(ang + t), j1[1] + scene["portee"] * math.sin(ang + t))
                       for t in [da * (k / 10.0 - 1.0) for k in range(21)]]
    dr.polygon(cone, fill=(255, 200, 120, 70))
    for z in ZOOMS:
        pr = next((p for p in prises if p["carte"] == carte and p["vue"] == "unique" and abs(p["zoom"] - z) < 1e-3), None)
        if pr is None:
            continue
        c = pr["j1"]["coins"]  # haut-gauche, haut-droit, bas-gauche, bas-droit
        poly = [P(*c[0]), P(*c[1]), P(*c[3]), P(*c[2])]
        dr.polygon(poly, outline=COULEURS[z] + (255,), width=3 if z == 1.5 else 2)
    for pos, coul, nom in [(j1, (120, 170, 255), "J1"), (j2, (255, 120, 120), "J2")]:
        x, y = P(*pos)
        dr.ellipse([x - 6, y - 6, x + 6, y + 6], fill=coul)
        dr.text((x + 9, y - 9), nom, fill=coul, font=pt)
    x, y = P(*j1)
    dr.line([x, y, x + v1[0] * 60, y + v1[1] * 60], fill=(120, 170, 255), width=2)
    dr.text((10, h + 6), "%s, vue de dessus (nord en haut). Contours : le sol que montre l'écran 1920×1080 de J1 à chaque "
            "zoom (lacet 45°, regard décalé, bornes)." % CARTES[carte][1], fill=(220, 220, 220), font=pt)
    xx = 10
    for z in ZOOMS:
        dr.rectangle([xx, h + 34, xx + 18, h + 46], outline=COULEURS[z], width=2)
        dr.text((xx + 24, h + 34), "×%s%s" % (str(z).replace(".", ","), " (défaut)" if z == 1.5 else ""),
                fill=COULEURS[z], font=pt)
        xx += 140
    dr.text((xx + 10, h + 32), "cône plein : pistolet ; pointillés : portée de chaque classe", fill=(200, 170, 110), font=pt)
    im.save(sortie, "JPEG", quality=85, optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--captures", required=True)
    ap.add_argument("--journal", required=True)
    a = ap.parse_args()
    reglages, classes, scenes, prises = lire_journal(a.journal)
    lignes = ["<!-- généré par composer.py -->", "", "Réglages du banc : `%s`" % reglages, ""]
    corps_image = {}
    for p in prises:
        src = os.path.join(a.captures, p["fichier"])
        dst = os.path.join(ICI, p["fichier"].replace(".png", ".jpg"))
        if os.path.exists(src):
            en_jpeg(src, dst)
            if p["vue"] == "unique":
                pied = tuple(float(v) for v in re.search(r"pied=\(([-\d.]+), ([-\d.]+)\)", p["j1"]["_brut"]).groups())
                corps_image[(p["carte"], p["zoom"])] = silhouette(Image.open(src).convert("RGB"), pied)
    for carte, scene in scenes.items():
        schema(carte, scene, prises, classes, os.path.join(ICI, "schema_%s.jpg" % carte))
    # Les tableaux.
    lignes += ["| Zoom | Corps de J1 sur l'image, 1080 lignes (L × H, px) | Corps sur 1440 lignes (×4/3) | Zone de touche "
               "(disque de 18 px) à l'écran, 1080 lignes | Torche du pistolet à l'écran, visée verticale / horizontale | "
               "…en part de la demi-hauteur / de la demi-largeur | …en part de l'écran DEVANT J1 (702 / 1166 px) |",
               "|---|---|---|---|---|---|---|"]
    s52 = math.sin(math.radians(52))
    for z in ZOOMS:
        img = [corps_image.get((c, z)) for c in scenes]
        img = [(b[2] - b[0], b[3] - b[1]) for b in img if b]
        img_txt = " ; ".join("%d × %d" % b for b in img) or "—"
        grand = " ; ".join("%.0f × %.0f" % (b[0] * 4 / 3, b[1] * 4 / 3) for b in img) or "—"
        tv, th = 307.2 * z, 307.2 * z / s52
        lignes.append("| ×%s | %s | %s | %.0f × %.0f px | %.0f / %.0f px | %.0f %% / %.0f %% | %.0f %% / %.0f %% |" % (
            str(z).replace(".", ","), img_txt, grand, 36 * z / s52, 36 * z, tv, th, 100 * tv / 540, 100 * th / 960,
            100 * tv / DEVANT_V, 100 * th / DEVANT_H))
    lignes += ["", "Le regard décalé avance la caméra de 0,15 de la hauteur VISIBLE : à l'écran, c'est toujours 162 px, quel "
               "que soit le zoom. J1 se tient donc à 702 px du bord vers lequel il vise (visée verticale), à 1166 px en "
               "visée horizontale (162 / sin 52° = 206 px de décalage) — hors bornes de la carte. Le zoom grandit la "
               "torche, pas cet espace.", "",
               "| Classe | Portée (px de monde) | Zoom au-delà duquel le bout de la torche sort de l'écran : visée verticale / horizontale |",
               "|---|---|---|"]
    for nom, (_, demi, portee) in classes.items():
        lignes.append(("| %s | %.0f | ×%.2f / ×%.2f |" % (nom, portee, DEVANT_V / portee, DEVANT_H * s52 / portee))
                      .replace(".", ","))
    lignes += ["", "| Carte | Zoom | Part de la carte à l'écran de J1 / de J2 | J1 voit devant / derrière / à gauche / à droite "
               "(px de monde, jusqu'au bord de l'image) | J2 idem | J1 a J2 à l'écran | J2 a J1 à l'écran | Scindé : J1 / J2 ont l'autre |",
               "|---|---|---|---|---|---|---|---|"]
    for carte in scenes:
        for z in ZOOMS:
            u = next((p for p in prises if p["carte"] == carte and p["vue"] == "unique" and abs(p["zoom"] - z) < 1e-3), None)
            s = next((p for p in prises if p["carte"] == carte and p["vue"] == "scinde" and abs(p["zoom"] - z) < 1e-3), None)
            if u is None:
                continue
            f = lambda d: "%s / %s / %s / %s" % (d["devant"], d["derriere"], d["gauche"], d["droite"])
            oui = lambda v: "oui" if v == "true" else "**non**"
            lignes.append("| %s | ×%s | %.0f %% / %.0f %% | %s | %s | %s | %s | %s |" % (
                CARTES[carte][1], str(z).replace(".", ","), 100 * float(u["j1"]["part_carte"]),
                100 * float(u["j2"]["part_carte"]), f(u["j1"]), f(u["j2"]), oui(u["j1"]["voit_autre"]),
                oui(u["j2"]["voit_autre"]),
                "%s / %s" % (oui(s["j1"]["voit_autre"]), oui(s["j2"]["voit_autre"])) if s else "—"))
    lignes += ["", "Classes relevées : " + " ; ".join("%s %.0f px (demi-angle %.0f°)" % (n, v[2], v[1])
                                                    for n, v in classes.items())]
    open(os.path.join(ICI, "chiffres.md"), "w", encoding="utf-8").write("\n".join(lignes) + "\n")
    print("\n".join(lignes))


if __name__ == "__main__":
    main()
