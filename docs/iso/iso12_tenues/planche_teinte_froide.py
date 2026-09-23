#!/usr/bin/env python3
"""Planche de la teinte froide : trois classes, de face et de dos sous la torche de J1, le gris d'aujourd'hui, V1 olive, puis
V1, V2 et V3 en teinte froide, au même instant ; puis les dix corps au banc des corps (gris, V1 olive, V1, V2, V3 froides).
La fusée et le noir ne changent pas par construction : sous la fusée l'éblouissement efface l'adversaire, et le noir est noir.

Usage : planche_froide.py <sortie.jpg> <banc des corps olive> <banc des corps froide> <captures_froide_<classe>>...
"""
import json, re, sys
from PIL import Image, ImageDraw, ImageFont

COLS = [("gris", "gris d'aujourd'hui"), ("sombre1_olive", "V1 olive"), ("sombre1", "V1 froide"), ("sombre2", "V2 froide"),
        ("sombre3", "V3 froide")]
LIBELLES = {"pistolet": "Le Parasite", "fusil": "L'Illusionniste", "pompe": "Le Terrassier", "arbalete": "Le Braconnier",
            "fumiste": "Le Fumiste", "incendiaire": "L'Incendiaire", "sentinelle": "La Sentinelle",
            "occulteur": "L'Occulteur", "allumeur": "L'Allumeur", "spectre": "Le Spectre"}
SLUGS = list(LIBELLES)
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


def main(a):
    if len(a) < 4:
        print(__doc__); return 2
    sortie, banc_o, banc_f, dossiers = a[0], a[1], a[2], a[3:]
    marge, gauche = 14, 110
    largeur = marge * 2 + gauche + 10 * 174
    hauteur = 120 + len(dossiers) * (2 * (LOUPE + 8) + 60) + 5 * 180 + 80
    planche = Image.new("RGB", (largeur, hauteur), FOND)
    d = ImageDraw.Draw(planche)
    d.text((marge, 12), "Teinte froide — la même clarté que l'olive, plus loin de l'ocre du sol", fill=AMBRE, font=police(28))
    d.text((marge, 50), "la 2D du jeu, Le Cloître, 1920×1080, bandeau de LED coupé ; l'adversaire (J2) de face puis de dos sous la torche "
           "de J1, les cinq tenues au même instant ; loupes ×2 sans lissage", fill=TEXTE, font=police(15))
    d.text((marge, 72), "La fusée et le noir ne changent pas par construction : sous la fusée, l'éblouissement de J1 efface l'adversaire "
           "dans toutes les tenues ; dans le noir, il est noir.", fill=SOURD, font=police(14))
    y = 104
    for dossier in dossiers:
        slug = dossier.rstrip("/").split("captures_froide_")[-1]
        prises = {}
        for l in open(dossier + "/journal.log", encoding="utf-8", errors="replace"):
            m = LIGNE.search(l.strip())
            if m:
                prises[(m.group(1), m.group(2))] = (m.group(5), json.loads(m.group(6)), (int(m.group(3)), int(m.group(4))))
        d.text((marge, y), "%s (%s)" % (LIBELLES.get(slug, slug), slug), fill=AMBRE, font=police(20))
        y += 30
        for k, (_, nom) in enumerate(COLS):
            d.text((marge + gauche + k * (LOUPE + 4), y), nom, fill=SOURD, font=police(13))
        y += 18
        for cad, nom in [("tenues_torche", "de face"), ("tenues_torche_dos", "de dos")]:
            d.text((marge, y + LOUPE // 2 - 8), nom, fill=TEXTE, font=police(14))
            cams = set()
            for k, (t, _) in enumerate(COLS):
                p = prises.get((cad, t))
                if p is None:
                    raise SystemExit("%s : prise %s %s absente" % (slug, cad, t))
                cams.add(p[2])
                im = Image.open("%s/%s" % (dossier, p[0])).convert("RGB")
                x0, y0 = p[1]["j2"]
                planche.paste(im.crop((x0 - DEMI, y0 - DEMI, x0 + DEMI, y0 + DEMI)).resize((LOUPE, LOUPE), Image.NEAREST),
                              (marge + gauche + k * (LOUPE + 4), y))
            if len(cams) > 1:
                raise SystemExit("%s %s : la caméra a bougé entre les tenues %s" % (slug, cad, cams))
            y += LOUPE + 8
        y += 12
    d.text((marge, y), "Les dix corps au banc des corps (lumière 0,8, temps figé), dans l'ordre du catalogue", fill=AMBRE, font=police(20))
    y += 34
    g = Image.open("%s/corps_0.8_gris.png" % banc_f).convert("RGB"); v = Image.open("%s/corps_0.8_sombre2.png" % banc_f).convert("RGB")
    pg, pv = g.load(), v.load(); W, H = g.size
    pts = [(x, yy) for yy in range(0, H, 2) for x in range(0, W, 2) if max(abs(pg[x, yy][i] - pv[x, yy][i]) for i in range(3)) > 3]
    xs = sorted(p[0] for p in pts); ys = sorted(p[1] for p in pts)
    bx = {}
    for x, yy in pts:
        c = min(4, int((x - xs[0]) * 5 / (xs[-1] - xs[0] + 1))); r = min(1, int((yy - ys[0]) * 2 / (ys[-1] - ys[0] + 1)))
        q = bx.setdefault(r * 5 + c, [W, H, 0, 0]); q[0], q[1], q[2], q[3] = min(q[0], x), min(q[1], yy), max(q[2], x), max(q[3], yy)
    cote = max(max(q[2] - q[0], q[3] - q[1]) for q in bx.values()) + 12
    case = 170
    for i, s_ in enumerate(SLUGS):
        d.text((marge + gauche + i * (case + 4), y), LIBELLES[s_], fill=SOURD, font=police(12))
    y += 18
    for fichier, nom in [(banc_f + "/corps_0.8_gris.png", "gris d'aujourd'hui"), (banc_o + "/corps_0.8_sombre1.png", "V1 olive"),
                         (banc_f + "/corps_0.8_sombre1.png", "V1 froide"), (banc_f + "/corps_0.8_sombre2.png", "V2 froide"),
                         (banc_f + "/corps_0.8_sombre3.png", "V3 froide")]:
        im = Image.open(fichier).convert("RGB")
        for i in range(10):
            q = bx[i]; cx, cy = (q[0] + q[2]) // 2, (q[1] + q[3]) // 2
            planche.paste(im.crop((cx - cote // 2, cy - cote // 2, cx + cote // 2, cy + cote // 2)).resize((case, case), Image.NEAREST),
                          (marge + gauche + i * (case + 4), y))
        d.text((marge, y + case // 2 - 8), nom, fill=TEXTE, font=police(14))
        y += case + 6
    planche = planche.crop((0, 0, largeur, y + 10))
    planche.save(sortie, "JPEG", quality=88)
    print("planche %dx%d → %s" % (planche.width, planche.height, sortie))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
