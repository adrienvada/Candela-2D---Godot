#!/usr/bin/env python3
"""L'ALLÈGEMENT DE LA 0.8.0, À L'IMAGE : le rayon dans l'air en carrés (A) et taillé à son cône (B) donnent-ils la même image ?
Et que change l'OPTION du juge taillé (J) ?

Lit les prises du plan `loupe-faisceau-taille` (tools/loupe_faisceau_taille.gd) — dans chaque bloc, A B A B A J S prises dans
le même lancement, jeu en pause — et rend, bloc par bloc (sien, adv, deux, s1, s2, fusee, eq) :
  1. LE BRUIT : les pixels où les trois A diffèrent entre elles (la scène qui bouge). Critère : zéro, sinon le bloc ne se juge
     pas (et on dit combien) ;
  2. LA DIFFÉRENCE : chaque B contre ses deux A voisines — le nombre de pixels qui diffèrent, l'écart le plus grand (/255, sur
     le canal le plus touché), séparés SOUS LA LUMIÈRE (A non noire) et DANS LE NOIR (A noire), et par moitié en écran scindé
     (J1 à gauche, J2 à droite). Critère écrit d'avance : **aucun écart au-delà de 1/255** — l'arrondi de l'interpolation,
     qui suit les triangles (une même position du monde, interpolée sur un autre triangle, peut tomber à 1/255 près) — et
     **aucun pixel noir qui s'allume** ;
  3. L'OPTION J (juge taillé), mesurée, jamais jugée : ses pixels changés contre A (hors de l'arrondi), leur écart, et combien
     valent alors exactement l'image SANS le rayon (S) — le juge qui ne tait plus ce qui n'est pas à lui ;
  4. LA PLANCHE : pour chaque bloc, A | B | |B − A| × 32 (rouge : un pixel qui diffère) | J | |J − A| × 32, en JPEG, et la
     planche entière.

    python3 tools/faisceau_taille/preuve.py <dossier des prises> <sortie> [--largeur-planche 1600]

Sort 1 si une B s'écarte de plus de 1/255 d'une A voisine, allume un noir, ou si un bloc attendu manque ou bouge. numpy et
Pillow requis."""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

D, S = sys.argv[1], sys.argv[2]
LARGEUR = int(sys.argv[sys.argv.index("--largeur-planche") + 1]) if "--largeur-planche" in sys.argv else 1600
ID = "loupe-faisceau-taille"
BLOCS = ["sien", "adv", "deux", "s1", "s2", "fusee", "eq"]
ARRONDI = 1
os.makedirs(S, exist_ok=True)


def police(taille=13):
    """Une police qui écrit les accents (celle de Pillow par défaut ne les écrit pas) : DejaVu (Linux), Arial (Mac)."""
    for chemin in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/System/Library/Fonts/Supplemental/Arial.ttf",
                   "/Library/Fonts/Arial Unicode.ttf"):
        if os.path.exists(chemin):
            return ImageFont.truetype(chemin, taille)
    return ImageFont.load_default(size=taille)


POLICE = police()


def lire(bloc, suffixe):
    f = sorted(glob.glob(os.path.join(D, "*%s-%s-%s.png" % (ID, bloc, suffixe))))
    return np.asarray(Image.open(f[-1]).convert("RGB")).astype(np.int16) if f else None


def comparer(b, a, noir, moities):
    """Pixels qui diffèrent et écart le plus grand, partout, sous la lumière, dans le noir, par moitié."""
    diff = np.abs(b - a).max(axis=2)
    change = diff > 0
    r = {"pixels": int(change.sum()), "ecart_max": int(diff.max()),
         "au_dela_arrondi": int((diff > ARRONDI).sum()),
         "noirs_allumes": int((noir & np.any(b > 0, axis=2)).sum()),
         "lumiere": int((change & ~noir).sum()), "noir": int((change & noir).sum()),
         "lumiere_ecart_max": int(diff[~noir].max()) if (~noir).any() else 0,
         "noir_ecart_max": int(diff[noir].max()) if noir.any() else 0}
    for nom, sl in moities:
        r[nom] = int(change[:, sl].sum())
    return r, diff


def carte_de(diff):
    carte = np.clip(diff * 32, 0, 255).astype(np.uint8)
    carte = np.stack([carte, carte // 4, carte // 4], axis=2)
    carte[diff > 0] = (255, 0, 0)
    return carte


ok = True
rapport = {}
lignes_planche = []
for bloc in BLOCS:
    A = [lire(bloc, s) for s in ("1a", "3a", "5a")]
    B = [lire(bloc, s) for s in ("2b", "4b")]
    J = lire(bloc, "6j")
    sans = lire(bloc, "7s")
    if any(x is None for x in A + B):
        print("✗ %s : prises manquantes (A %s, B %s)" % (bloc, [x is not None for x in A], [x is not None for x in B]))
        ok = False
        continue
    h, w = A[0].shape[:2]
    noir = np.all(A[0] == 0, axis=2)
    moities = [("fenêtre", slice(0, w))] if bloc not in ("s1", "s2") else [("vue de J1 (gauche)", slice(0, w // 2)),
                                                                         ("vue de J2 (droite)", slice(w // 2, w))]
    bruit = np.zeros((h, w), bool)
    for a in A[1:]:
        bruit |= np.any(a != A[0], axis=2)
    r = {"noir_A": int(noir.sum()), "lumiere_A": int((~noir).sum()), "bruit_A": int(bruit.sum()), "B": {}}
    print("\n== %s : %d × %d ; A noire sur %d pixels, éclairée sur %d ; bruit entre les trois A : %d pixel(s)"
          % (bloc, w, h, r["noir_A"], r["lumiere_A"], r["bruit_A"]))
    if r["bruit_A"] > 0:
        print("   ✗ la scène a bougé entre les A : le bloc ne se juge pas")
        ok = False
    # Ce que le rayon lui-même ajoute (A contre la prise sans rayon) : le zéro de l'allègement n'a de sens que si le rayon se
    # voit dans le bloc.
    if sans is not None:
        apport = np.abs(A[0] - sans).max(axis=2)
        r["rayon_pixels"] = int((apport > 0).sum())
        r["rayon_max"] = int(apport.max())
        print("   le rayon lui-même (A contre la prise sans rayon) : %d pixel(s) changé(s), jusqu'à %d/255"
              % (r["rayon_pixels"], r["rayon_max"]))
        if r["rayon_pixels"] == 0 and bloc != "eq":
            # (`eq` : J2 caché derrière le pilier — que son rayon ne se voie pas de J1 est justement ce qu'on y attend.)
            print("   ✗ le rayon ne se voit pas dans ce bloc : le zéro ci-dessous serait vide")
            ok = False
    pire = None
    for i, b in enumerate(B):
        for j, a in enumerate([A[i], A[i + 1]]):
            c, diff = comparer(b, a, noir, moities)
            cle = "%db-%da" % (2 * i + 2, 2 * (i + j) + 1)
            r["B"][cle] = c
            bon = c["au_dela_arrondi"] == 0 and c["noirs_allumes"] == 0
            ok = ok and bon
            if pire is None or c["pixels"] > pire[0]["pixels"]:
                pire = (c, diff, b, a)
            print("   %s %s : %d pixel(s) à 1/255 (%.3f %% de l'image), %d au-delà ; écart max %d/255 — sous la lumière %d, "
                  "dans le noir %d, noirs allumés %d%s"
                  % ("✓" if bon else "✗", cle, c["pixels"] - c["au_dela_arrondi"], 100.0 * c["pixels"] / (h * w),
                     c["au_dela_arrondi"], c["ecart_max"], c["lumiere"], c["noir"], c["noirs_allumes"],
                     "".join(" ; %s %d" % (nom, c[nom]) for nom, _ in moities) if len(moities) > 1 else ""))
    # L'option : le juge taillé.
    tuiles_j = []
    if J is not None:
        cj, diffj = comparer(J, A[2], noir, moities)
        gros = diffj > ARRONDI
        r["J"] = cj
        if sans is not None and gros.any():
            egal_sans = np.all(J == sans, axis=2) & gros
            r["J"]["au_dela_egaux_sans_rayon"] = int(egal_sans.sum())
            r["J"]["au_dela_plus_clairs"] = int((gros & ((J - A[2]).sum(axis=2) > 0)).sum())
            ys, xs = np.nonzero(gros)
            r["J"]["boite"] = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
        print("   option J (juge taillé) contre A : %d pixel(s) au-delà de l'arrondi, écart max %d/255%s"
              % (cj["au_dela_arrondi"], cj["ecart_max"],
                 (" ; dont %d valent exactement l'image sans rayon, %d plus clairs qu'avec les carrés"
                  % (r["J"].get("au_dela_egaux_sans_rayon", 0), r["J"].get("au_dela_plus_clairs", 0))) if gros.any() else ""))
        tuiles_j = [Image.fromarray(J.astype(np.uint8)), Image.fromarray(carte_de(diffj))]
    rapport[bloc] = r
    # La planche du bloc : A | B | |B − A| × 32 | J | |J − A| × 32.
    c, diff, b, a = pire
    tuiles = [Image.fromarray(a.astype(np.uint8)), Image.fromarray(b.astype(np.uint8)), Image.fromarray(carte_de(diff))]
    tuiles += tuiles_j
    lw = LARGEUR // 5
    lh = int(round(h * lw / w))
    ligne = Image.new("RGB", (lw * 5, lh + 22), (18, 18, 18))
    for k, t in enumerate(tuiles):
        ligne.paste(t.resize((lw, lh), Image.LANCZOS), (k * lw, 22))
    d = ImageDraw.Draw(ligne)
    d.text((6, 4), "%s — A (carrés) | B (taillé, le défaut) | |B−A|×32 : %d px, max %d/255 | J (option : juge taillé) | "
           "|J−A|×32 : %d px au-delà de 1/255, max %d/255"
           % (bloc, c["pixels"], c["ecart_max"], r.get("J", {}).get("au_dela_arrondi", 0), r.get("J", {}).get("ecart_max", 0)),
           fill=(230, 230, 230), font=POLICE)
    ligne.save(os.path.join(S, "bloc_%s.jpg" % bloc), quality=86)
    lignes_planche.append(ligne)

if lignes_planche:
    H = sum(l.height for l in lignes_planche)
    planche = Image.new("RGB", (lignes_planche[0].width, H), (18, 18, 18))
    y = 0
    for l in lignes_planche:
        planche.paste(l, (0, y))
        y += l.height
    planche.save(os.path.join(S, "planche_avant_apres.jpg"), quality=86)
json.dump(rapport, open(os.path.join(S, "mesures.json"), "w"), ensure_ascii=False, indent=1)
print("\n%s" % ("✓ chaque B vaut ses A voisines à 1/255 près, aucun noir allumé, dans tous les blocs, scène immobile" if ok
                else "✗ au moins une B s'écarte de plus de 1/255 d'une A voisine, allume un noir, ou un bloc manque ou bouge"))
sys.exit(0 if ok else 1)
