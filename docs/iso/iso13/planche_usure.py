#!/usr/bin/env python3
"""ISO13 lot C — la planche d'usure : sans / avec, au lacet 0 puis 45°, loupes sur la face et le sol, et trois mesures
au pixel entre « sans » et « avec » (même instant, même partie) :
  - noir reste noir : aucun pixel noir (≤ 2/255) de « sans » ne s'allume dans « avec » ;
  - jamais plus clair : aucun pixel plus clair de plus d'un niveau ;
  - J2 non caché : dans une boîte autour de J2, la part des pixels visibles (> 6/255) perdue — garde-fou 5 %.
Usage : planche_usure.py <sortie.jpg> <captures_planche_usure>"""
import json, re, sys
from PIL import Image, ImageDraw, ImageFont
LIGNE = re.compile(r"BANC_LUMIERE3D tenue cadrage=(\S+) tenue=(\S+) camera=(-?\d+),(-?\d+) fichier=(\S+) ancres=(\{.*\})$")
FOND, TEXTE, SOURD, AMBRE = (12, 12, 12), (225, 215, 195), (150, 140, 125), (230, 160, 70)


def police(t):
    for c in ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try:
            return ImageFont.truetype(c, t)
        except OSError:
            pass
    return ImageFont.load_default()


def lum(p):
    return max(p[:3])


def mesurer(sans, avec, j2):
    w, h = sans.size
    ps, pa = sans.load(), avec.load()
    allumes = plus_clairs = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            a, b = lum(ps[x, y]), lum(pa[x, y])
            if a <= 2 and b > 2:
                allumes += 1
            if b > a + 1:
                plus_clairs += 1
    x0, y0 = int(j2[0]) - 40, int(j2[1]) - 70
    vis_s = vis_a = 0
    for y in range(max(0, y0), min(h, y0 + 110)):
        for x in range(max(0, x0), min(w, x0 + 80)):
            vis_s += lum(ps[x, y]) > 6
            vis_a += lum(pa[x, y]) > 6
    perte = (vis_s - vis_a) / vis_s * 100.0 if vis_s else 0.0
    return allumes, plus_clairs, perte, vis_s


def main(a):
    sortie, dossier = a
    prises = {}
    for l in open(dossier + "/journal.log", encoding="utf-8", errors="replace"):
        m = LIGNE.search(l.strip())
        if m:
            prises[(m.group(1), m.group(2))] = (m.group(5), json.loads(m.group(6)))
    lignes = [("usure", "lacet 0° (le jeu)"), ("usure_lacet45", "lacet 45° (Q14)")]
    CW, CH, marge = 620, 420, 12
    hauteur = 90 + len(lignes) * (CH + 40 + 2 * 230 + 40) + 20
    planche = Image.new("RGB", (marge * 3 + 2 * CW, hauteur), FOND)
    d = ImageDraw.Draw(planche)
    d.text((marge, 10), "L'usure en essai — murs abîmés, sol jonché (ISO13, lot C)", fill=AMBRE, font=police(26))
    d.text((marge, 46), "la 2D du jeu à 1:1, torche de J1 ; J2 torche éteinte à une tuile de la face ; sept impacts posés "
           "comme le jeu les pose ; sans / avec au même instant", fill=TEXTE, font=police(14))
    y = 80
    rapport = []
    for cadrage, titre in lignes:
        if (cadrage, "sans") not in prises:
            continue
        fs, anc = prises[(cadrage, "sans")]
        fa, _ = prises[(cadrage, "avec")]
        sans = Image.open("%s/%s" % (dossier, fs.split("/")[-1])).convert("RGB")
        avec = Image.open("%s/%s" % (dossier, fa.split("/")[-1])).convert("RGB")
        allumes, clairs, perte, vis = mesurer(sans, avec, anc["j2"])
        rapport.append("%s : allumés %d, plus clairs %d, J2 perd %.1f %% de %d px visibles" % (titre, allumes, clairs, perte, vis))
        d.text((marge, y), "%s — noir allumé : %d px ; plus clair : %d px ; J2 : %+.1f %% de pixels visibles" %
               (titre, allumes, clairs, -perte), fill=(208, 112, 74) if (allumes or clairs or perte > 5) else TEXTE, font=police(15))
        y += 24
        cx, cy = anc["face"]
        for k, (img, nom) in enumerate([(sans, "sans"), (avec, "avec")]):
            box = (int(cx) - CW // 2, int(cy) - CH // 3, int(cx) + CW // 2, int(cy) + 2 * CH // 3)
            planche.paste(img.crop(box), (marge + k * (CW + marge), y))
            d.text((marge + k * (CW + marge) + 6, y + 4), nom, fill=SOURD, font=police(13))
        y += CH + 10
        for zone in ["face", "sol"]:
            zx, zy = anc[zone]
            for k, img in enumerate([sans, avec]):
                loupe = img.crop((int(zx) - 100, int(zy) - 36, int(zx) + 100, int(zy) + 36)).resize((600, 216), Image.NEAREST)
                planche.paste(loupe, (marge + k * (CW + marge), y))
            d.text((marge + 4, y + 2), "%s, loupe ×3" % zone, fill=SOURD, font=police(13))
            y += 230
        y += 30
    planche.save(sortie, quality=90)
    print("\n".join(rapport))
    print("planche →", sortie)


if __name__ == "__main__":
    main(sys.argv[1:])
