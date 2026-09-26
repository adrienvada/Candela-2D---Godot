"""La planche des tuyaux en essai (`--tuyaux-essai`) : les prises de `tools/photo_tuyaux.gd`, recadrées SANS
rééchantillonnage, à côté de l'illustration qui sert de cible.

Quatre séances de la planche, chacune un seul lancement, jeu en pause entre ses prises (même instant) :
  final_l0_bord, final_l45_bord : torche en biais de 28° sur la face — le bord de l'ombre y coupe les tuyaux ;
  final_l0_face, final_l45_face : torche droit sur la face — la face entière sous la lampe.
Chaque séance donne A1 (avec), S (sans, le nœud caché), N1 (avec, torches éteintes), M (l'emprise des tuyaux en blanc) et la
ligne REPERES (les coins du pilier projetés, pour tracer son contour là où il est noir).

Usage : python3 planche_tuyaux.py <dossier user:// du jeu> <journaux> <dépôt> <sortie>"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

USER, JOURNAUX, DEPOT, SORTIE = sys.argv[1:5]
TUILE = (540, 300)
CADRES = {  # (gauche, haut) du recadrage de 540 × 300 dans la prise de 1280 × 720
    "l0_bord": (470, 10), "l45_bord": (560, 60), "l0_face": (500, 20), "l45_face": (610, 90),
}


def police(taille, grasse=False):
    for chemin in ["/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if grasse else ""),
                   "/System/Library/Fonts/Supplemental/Arial.ttf"]:
        try:
            return ImageFont.truetype(chemin, taille)
        except OSError:
            pass
    return ImageFont.load_default()


def prise(seance, cle):
    lacet = 45 if "l45" in seance else 0
    return Image.open(os.path.join(USER, "final_%s" % seance, "tuyaux_lacet%d_%s.png" % (lacet, cle))).convert("RGB")


def recadre(img, seance):
    x, y = CADRES[seance]
    return img.crop((x, y, x + TUILE[0], y + TUILE[1]))


def reperes(seance):
    for ligne in open(os.path.join(JOURNAUX, "final_%s.log" % seance), errors="replace"):
        if ligne.startswith("REPERES"):
            nombres = [tuple(float(v) for v in p.split(",")) for p in ligne.split()[1:]]
            return nombres  # 4 coins × (sol, arête)
    return []


def contour(img, seance):
    """Le contour du pilier (projeté par la caméra de la prise), en gris, sur l'image de l'emprise."""
    p = reperes(seance)
    if len(p) != 8:
        return img
    x0, y0 = CADRES[seance]
    d = ImageDraw.Draw(img)
    sol = [(p[2 * k][0] - x0, p[2 * k][1] - y0) for k in range(4)]
    haut = [(p[2 * k + 1][0] - x0, p[2 * k + 1][1] - y0) for k in range(4)]
    for k in range(4):
        d.line([sol[k], sol[(k + 1) % 4]], fill=(120, 120, 120), width=1)
        d.line([haut[k], haut[(k + 1) % 4]], fill=(120, 120, 120), width=1)
        d.line([sol[k], haut[k]], fill=(120, 120, 120), width=1)
    return img


def mesures(seance):
    lignes = []
    for ligne in open(os.path.join(JOURNAUX, "final_%s.log" % seance), errors="replace"):
        if ligne.startswith("MESURE"):
            lignes.append(ligne.strip())
    return lignes


MARGE = 10
ETIQUETTE = 26
largeur = 4 * TUILE[0] + 5 * MARGE
rangs = [("0° de lacet — torche en biais : le bord de l'ombre coupe les tuyaux", "l0_bord"),
         ("45° de lacet — deux faces du pilier, même mise en scène", "l45_bord")]
hauteur_cible = 338
hauteur = 70 + hauteur_cible + MARGE + 4 * (ETIQUETTE + TUILE[1] + MARGE) + 40
# Le détail : 180 × 100 px de la prise autour des tuyaux sous la lampe, agrandis ×3 au plus proche voisin.
DETAILS = {"l0_face": (570, 195), "l45_face": (635, 235)}
planche = Image.new("RGB", (largeur, hauteur), (18, 18, 18))
d = ImageDraw.Draw(planche)
titre, texte, petit = police(26, True), police(17), police(15)
d.text((MARGE, 16), "Tuyaux et câbles des murs, en essai (--tuyaux-essai) — Cloître, pilier 3 × 3, zoom ×2,5",
       font=titre, fill=(235, 225, 205))
cible = Image.open(os.path.join(DEPOT, "assets/ui/ill_entrainement.png")).convert("RGB")
cible = cible.resize((int(cible.width * hauteur_cible / cible.height), hauteur_cible), Image.LANCZOS)
planche.paste(cible, (MARGE, 60))
legende = [
    "À gauche, la cible : l'illustration de l'entraînement (câbles qui pendent, conduites).",
    "Chaque rang : une seule séance, jeu en pause — les prises sont du MÊME instant.",
    "  avec · sans (nœud des tuyaux caché) · torches éteintes, avec · emprise des tuyaux (blanc)",
    "  et le contour du pilier projeté (gris), là où la face est noire.",
    "Recadrages de 540 × 300 px d'une prise 1280 × 720, sans rééchantillonnage.",
    "",
    "Le noir : les tuyaux n'ont aucune lumière à eux. Chaque pixel relit la lumière du pixel",
    "de face qu'il recouvre (mêmes fonctions que mur_iso) et la multiplie par un facteur",
    "plafonné par la matière la plus sombre d'une face : jamais plus clair que la face.",
]
for k, l in enumerate(legende):
    d.text((cible.width + 3 * MARGE, 64 + 22 * k), l, font=texte, fill=(210, 205, 195))
y = 60 + hauteur_cible + MARGE
colonnes = ["avec les tuyaux", "sans (même instant)", "torches éteintes, avec", "emprise des tuyaux + pilier"]
for libelle, seance in rangs:
    d.text((MARGE, y + 3), libelle, font=texte, fill=(235, 225, 205))
    y += ETIQUETTE
    tuiles = [recadre(prise(seance, "A1"), seance), recadre(prise(seance, "S"), seance),
              recadre(prise(seance, "N1"), seance), contour(recadre(prise(seance, "M"), seance), seance)]
    for k, t in enumerate(tuiles):
        planche.paste(t, (MARGE + k * (TUILE[0] + MARGE), y))
        d.text((MARGE + k * (TUILE[0] + MARGE) + 6, y + 4), colonnes[k], font=petit, fill=(160, 155, 145))
    y += TUILE[1] + MARGE
d.text((MARGE, y + 3), "La face entière sous la lampe (torche droit sur la face) : 0° avec · 0° sans · 45° avec · 45° sans",
       font=texte, fill=(235, 225, 205))
y += ETIQUETTE
for k, (seance, cle) in enumerate([("l0_face", "A1"), ("l0_face", "S"), ("l45_face", "A1"), ("l45_face", "S")]):
    planche.paste(recadre(prise(seance, cle), seance), (MARGE + k * (TUILE[0] + MARGE), y))
y += TUILE[1] + MARGE
d.text((MARGE, y + 3), "Le détail, ×3 au plus proche voisin : 0° avec · 0° sans · 45° avec · 45° sans", font=texte,
       fill=(235, 225, 205))
y += ETIQUETTE
for k, (seance, cle) in enumerate([("l0_face", "A1"), ("l0_face", "S"), ("l45_face", "A1"), ("l45_face", "S")]):
    x0, y0 = DETAILS[seance]
    detail = prise(seance, cle).crop((x0, y0, x0 + 180, y0 + 100)).resize(TUILE, Image.NEAREST)
    planche.paste(detail, (MARGE + k * (TUILE[0] + MARGE), y))
y += TUILE[1] + MARGE
d.text((MARGE, y + 6), "Rendu logiciel (llvmpipe, conteneur du cloud) : vaut pour la forme et pour le noir, pas pour la cadence.",
       font=petit, fill=(150, 145, 135))
planche.save(SORTIE, quality=90)

# Les tuiles une à une, et les mesures des quatre séances.
dossier = os.path.dirname(SORTIE)
for seance in CADRES:
    for cle, nom in [("A1", "avec"), ("S", "sans"), ("N1", "torches_eteintes"), ("M", "emprise")]:
        if "face" in seance and cle in ("N1", "M"):
            continue
        t = recadre(prise(seance, cle), seance)
        if cle == "M":
            t = contour(t, seance)
        t.save(os.path.join(dossier, "%s_%s.png" % (seance.replace("l0", "lacet0").replace("l45", "lacet45"), nom)))
with open(os.path.join(dossier, "mesures.txt"), "w") as f:
    for seance in CADRES:
        f.write("# %s\n" % seance)
        for l in mesures(seance):
            f.write(l + "\n")
print("planche : %s (%d × %d)" % (SORTIE, planche.width, planche.height))
