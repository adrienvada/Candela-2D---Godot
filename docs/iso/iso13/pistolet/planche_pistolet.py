"""La planche du pistolet détaillé, pour Adrien."""
import sys
from PIL import Image, ImageDraw, ImageFont
S = sys.argv[1]; SORTIE = sys.argv[2]
FOND, TEXTE, SOURD, AMBRE = (13, 12, 11), (228, 218, 200), (150, 140, 126), (230, 160, 70)
def police(t):
    for c in ["/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/Helvetica.ttc"]:
        try: return ImageFont.truetype(c, t)
        except OSError: pass
    return ImageFont.load_default()
J2 = (1177, 614)
COLS = [("sombre3_froide", "aujourd'hui (V3 froide)"), ("sombre3_froide_d", "détaillé"), ("sombre3_froide_dc1", "détaillé + contour 1 px"),
        ("sombre3_froide_c1", "contour 1 px seul")]
W = 4 * 470 + 50
P = Image.new("RGB", (W, 4200), FOND); d = ImageDraw.Draw(P)
d.text((20, 14), "Le Parasite (pistolet) détaillé, à l'essai — pour Adrien", fill=AMBRE, font=police(30))
d.text((20, 56), "--corps-detaille, éteint par défaut ; tenue du jeu (V3 froide, équité comprise) ; accessoires modelés (bandoulière et "
       "trois cartouches, étui, manomètres, robinet, tuyau, crosse) et matière peinte (marbrage, pores effacés à la taille du duel)",
       fill=TEXTE, font=police(16))
por = Image.open(S + "/pistolet/portrait_pistolet_v3froide.png").convert("RGB").resize((420, 420), Image.LANCZOS)
P.paste(por, (20, 90)); d.text((20, 516), "le portrait V3 froide (ISO Assets)", fill=SOURD, font=police(14))
x0 = 470
for i, l in enumerate(["À la taille du duel (fenêtre 2560 × 1440, 1:1) : le corps fait ~40 × 60 px — la forme se lit, le détail non.",
                       "Même lumière, même instant : le détail se montre et se cache par uniformes, sans reconstruire le corps.",
                       "Coût : 11 boîtes de plus par corps, 22 appels de dessin (couleur et profondeur), 264 triangles.",
                       "Silhouette du corps seul : 16,90 px avec comme sans (couloir 17,5, touche 18). Noir : 0/255.",
                       "Apparition (banc des corps) : 0,10 avec comme sans — pas plus tôt.",
                       "⚠ La matière peinte assombrit : à 0,15, 2 092 px visibles contre 2 422 (−14 %),",
                       "  soit 0,42 du gris — sous la bande d'équité (0,47). À recalibrer si on l'adopte.",
                       "J2 est dessiné à 0,648 d'opacité dans la vue de J1 : la règle d'éblouissement du jeu, pareille partout.",
                       "⚠ Défaut de l'essai : la bandoulière modelée déborde du torse d'un côté (banc des corps) ; sa longueur est à reprendre."]):
    d.text((x0, 100 + i * 30), l, fill=(208, 112, 74) if l.startswith("⚠") or l.startswith("  soit") else TEXTE, font=police(17))
y = 560
for cad, titre in [("pistolet", "Face à J1 (le dos vers la caméra : la bouteille, le robinet)"), ("pistolet_34", "Tourné de trois quarts")]:
    d.text((20, y), titre + " — 1:1", fill=AMBRE, font=police(19)); y += 30
    for k, (suf, nom) in enumerate(COLS):
        im = Image.open("%s/captures_pistolet/%s_%s.png" % (S, cad, suf)).convert("RGB")
        P.paste(im.crop((J2[0] - 230, J2[1] - 180, J2[0] + 230, J2[1] + 120)), (20 + k * 470, y + 22))
        d.text((20 + k * 470, y), nom, fill=SOURD, font=police(14))
    y += 22 + 300 + 20
    d.text((20, y), titre + " — ×4", fill=AMBRE, font=police(19)); y += 30
    for k, (suf, nom) in enumerate(COLS):
        im = Image.open("%s/captures_pistolet/%s_%s.png" % (S, cad, suf)).convert("RGB")
        P.paste(im.crop((J2[0] - 55, J2[1] - 75, J2[0] + 55, J2[1] + 25)).resize((440, 400), Image.NEAREST), (20 + k * 470, y))
    y += 420
d.text((20, y), "Au banc des corps, lumière 0,8, de face (la vue des menus et de la killcam rapprochée) — ×3 : aujourd'hui, détaillé",
       fill=AMBRE, font=police(19)); y += 30
for k, q in enumerate(["sans", "avec"]):
    im = Image.open("%s/bancs_pistolet/gros_%s.png" % (S, q)).convert("RGB")
    P.paste(im.crop((820, 350, 1100, 680)).resize((840, 990 // 1), Image.NEAREST) if False else im.crop((815, 350, 1110, 680)).resize((885, 990), Image.NEAREST), (20 + k * 920, y))
y += 1010
d.text((20, y), "La killcam (photographe, 2560 × 1440) — aujourd'hui, puis détaillé ; même mise en scène, deux parties : pas le même instant",
       fill=AMBRE, font=police(19)); y += 30
for k, q in enumerate(["aujourdhui", "detaille"]):
    im = Image.open("%s/photos_%s/01-killcam.png" % (S, q)).convert("RGB")
    P.paste(im.resize((920, 518), Image.LANCZOS), (20 + k * 930, y))
y += 530
P = P.crop((0, 0, W, y + 10)); P.save(SORTIE, quality=88); print(SORTIE, P.size)
