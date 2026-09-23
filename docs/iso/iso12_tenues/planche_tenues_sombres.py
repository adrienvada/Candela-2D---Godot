#!/usr/bin/env python3
"""Planche des tenues sombres : pour trois classes (J2 vu de face), le gris d'aujourd'hui, V1, V2 et V3 au même instant, sous
la torche de J1, sous une fusée au pied du mur et dans le noir ; puis les dix corps au banc des corps, en gris et dans les
trois tenues. Loupes sans lissage.

Usage : planche_tenues.py <sortie.jpg> <dossier du banc des corps> <captures_tenues_<classe>>...
"""
import json, re, sys
from PIL import Image, ImageDraw, ImageFont

TENUES = [("gris", "gris d'aujourd'hui"), ("sombre1", "V1 · aussi visible"), ("sombre2", "V2 · vraiment sombre"),
          ("sombre3", "V3 · sombre, liseré")]
LUMIERES = [("tenues_torche", "torche de J1"), ("tenues_fusee", "fusée posée *"), ("tenues_noir", "noir")]
LIBELLES = {"pistolet": "Le Parasite", "fusil": "L'Illusionniste", "pompe": "Le Terrassier", "arbalete": "Le Braconnier",
            "fumiste": "Le Fumiste", "incendiaire": "L'Incendiaire", "sentinelle": "La Sentinelle",
            "occulteur": "L'Occulteur", "allumeur": "L'Allumeur", "spectre": "Le Spectre"}
SLUGS = ["pistolet", "fusil", "pompe", "arbalete", "fumiste", "incendiaire", "sentinelle", "occulteur", "allumeur", "spectre"]
DEMI, LOUPE = 44, 176
FOND, TEXTE, SOURD, AMBRE = (12, 12, 12), (225, 215, 195), (150, 140, 125), (230, 160, 70)
LIGNE = re.compile(r"BANC_LUMIERE3D tenue cadrage=(\S+) tenue=(\S+) camera=(-?\d+),(-?\d+) fichier=(\S+) ancres=(\{.*\})$")


def police(t):
    for c in ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try:
            return ImageFont.truetype(c, t)
        except OSError:
            pass
    return ImageFont.load_default()


def classe_de(dossier):
    return dossier.rstrip("/").split("captures_tenues_")[-1]


def main(a):
    if len(a) < 3:
        print(__doc__); return 2
    sortie, banc, dossiers = a[0], a[1], a[2:]
    marge = 14
    bloc_l = len(TENUES) * (LOUPE + 4)
    largeur = max(marge * 2 + 2 * bloc_l + 3 * 40, 1900)
    blocs = []
    for d in dossiers:
        prises = {}
        for l in open(d + "/journal.log", encoding="utf-8", errors="replace"):
            m = LIGNE.search(l.strip())
            if m:
                prises[(m.group(1), m.group(2))] = (m.group(5), json.loads(m.group(6)), (int(m.group(3)), int(m.group(4))))
        blocs.append((classe_de(d), d, prises))
    # Mise en page : une ligne par classe et par lumière ; à gauche J2 de face, à droite J1 de dos.
    hauteur = 110 + len(blocs) * (36 + len(LUMIERES) * (LOUPE + 26)) + 40 + 4 * 520 + 60
    planche = Image.new("RGB", (largeur, hauteur), FOND)
    d = ImageDraw.Draw(planche)
    d.text((marge, 12), "Tenues sombres — le gris d'aujourd'hui, V1, V2, V3, au même instant", fill=AMBRE, font=police(28))
    d.text((marge, 50), "la 2D du jeu, Le Cloître, 1920×1080, bandeau de LED coupé ; l'adversaire (J2) de face puis de dos, "
           "dans la vue de J1 ; loupes ×2 sans lissage", fill=TEXTE, font=police(15))
    d.text((marge, 70), "* sous la fusée, J1 est ébloui (0,69 à 0,85) et le jeu efface le corps adverse (opacité 0) : même image dans toutes les "
           "tenues — la règle de l'éblouissement, pas la tenue", fill=SOURD, font=police(14))
    y = 100
    for slug, dossier, prises in blocs:
        d.text((marge, y), "%s (%s) — de face  ·  de dos" % (LIBELLES.get(slug, slug), slug), fill=AMBRE, font=police(20))
        y += 36
        for k, (t, _) in enumerate(TENUES):
            for bloc in range(2):
                d.text((marge + 120 + bloc * (bloc_l + 40) + k * (LOUPE + 4), y - 2), TENUES[k][1], fill=SOURD, font=police(13))
        y += 18
        for cad, nom in LUMIERES:
            d.text((marge, y + LOUPE // 2 - 8), nom, fill=TEXTE, font=police(14))
            cams = set()
            for k, (t, _) in enumerate(TENUES):
                for bloc, suffixe in enumerate(["", "_dos"]):
                    p = prises.get((cad + suffixe, t))
                    if p is None:
                        continue
                    cams.add(p[2])
                    im = Image.open("%s/%s" % (dossier, p[0])).convert("RGB")
                    x0, y0 = p[1]["j2"]
                    c = im.crop((x0 - DEMI, y0 - DEMI, x0 + DEMI, y0 + DEMI)).resize((LOUPE, LOUPE), Image.NEAREST)
                    planche.paste(c, (marge + 120 + bloc * (bloc_l + 40) + k * (LOUPE + 4), y))
            if len(cams) > 1:
                raise SystemExit("%s %s : la caméra a bougé entre les tenues %s" % (slug, cad, cams))
            y += LOUPE + 8
        y += 10
    # Les dix corps au banc des corps, à 0,8 : chaque corps recadré sur sa boîte (grille du banc, 5 × 2), ×3 sans lissage.
    d.text((marge, y), "Les dix corps au banc des corps (lumière 0,8, temps figé), dans l'ordre du catalogue", fill=AMBRE, font=police(20))
    y += 34
    g = Image.open("%s/corps_0.8_gris.png" % banc).convert("RGB")
    v = Image.open("%s/corps_0.8_sombre2.png" % banc).convert("RGB")
    pg, pv = g.load(), v.load()
    W, H = g.size
    pts = [(x, yy) for yy in range(0, H, 2) for x in range(0, W, 2) if max(abs(pg[x, yy][i] - pv[x, yy][i]) for i in range(3)) > 3]
    xs = sorted(p[0] for p in pts); ys = sorted(p[1] for p in pts)
    bx = {}
    for x, yy in pts:
        c = min(4, int((x - xs[0]) * 5 / (xs[-1] - xs[0] + 1))); r = min(1, int((yy - ys[0]) * 2 / (ys[-1] - ys[0] + 1)))
        q = bx.setdefault(r * 5 + c, [W, H, 0, 0])
        q[0], q[1], q[2], q[3] = min(q[0], x), min(q[1], yy), max(q[2], x), max(q[3], yy)
    cote = max(max(q[2] - q[0], q[3] - q[1]) for q in bx.values()) + 12
    case = min(170, (largeur - 2 * marge - 130) // 10 - 4)
    for i, s_ in enumerate(SLUGS):
        d.text((marge + 130 + i * (case + 4), y), LIBELLES[s_], fill=SOURD, font=police(12))
    y += 18
    for t, nom in TENUES:
        im = Image.open("%s/corps_0.8_%s.png" % (banc, t)).convert("RGB")
        for i in range(10):
            q = bx[i]
            cx, cy = (q[0] + q[2]) // 2, (q[1] + q[3]) // 2
            c = im.crop((cx - cote // 2, cy - cote // 2, cx + cote // 2, cy + cote // 2)).resize((case, case), Image.NEAREST)
            planche.paste(c, (marge + 130 + i * (case + 4), y))
        d.text((marge, y + case // 2 - 8), nom, fill=TEXTE, font=police(14))
        y += case + 6
    planche = planche.crop((0, 0, largeur, y + 10))
    planche.save(sortie, "JPEG", quality=88)
    print("planche %dx%d → %s" % (planche.width, planche.height, sortie))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
