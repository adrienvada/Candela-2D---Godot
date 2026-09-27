#!/usr/bin/env python3
"""Les essais éteints, sur image — mesures et planche.

Lit les prises de `tools/photo_essais.gd` (un dossier par lancement : temoin1, temoin2, et un par essai), compare chaque
essai aux DEUX témoins, écrit les JPEG, `mesures.json` et `planche.html` dans ce dossier.

    python3 docs/iso/cloud/essais/mesurer.py [dossier des prises]

Par défaut, le dossier des prises est `~/.local/share/godot/app_userdata/Candela 2D/essais`.

Les chiffres, par scène (duel, sol, mur) et par état des torches (allumées, éteintes) :
- « changés » : pixels où l'essai diffère du témoin 1 ;
- « noirs allumés » : pixels à 0 dans les DEUX témoins et au-dessus de 0 avec l'essai (strict), et la même chose au seuil
  de 7,5/255 (un canal à 8 ou plus) — le noir absolu ;
- « plus clairs » : pixels où l'essai dépasse de plus de 2/255 le plus clair des deux témoins (canal le plus fort) — la
  règle des pochoirs, « rien de plus clair que la surface qui le porte » : sans l'essai, ce pixel montre la surface.
Chaque chiffre est donné HORS de la zone des corps et DANS elle. La zone des corps : là où les deux témoins diffèrent
entre eux (la respiration des corps bat sur l'horloge murale, `presentation_3d.gd`, `etat_du_corps`), élargie de
`MARGE_CORPS` pixels. Hors de cette zone, deux lancements témoins rendent la même image au pixel près : un écart y est
l'essai. Dans la zone, il se mêle au souffle des corps et ne prouve rien seul.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
PRISES = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/.local/share/godot/app_userdata/Candela 2D/essais")
RACINE = os.path.abspath(os.path.join(ICI, "..", "..", "..", ".."))
ILLUS = os.path.join(RACINE, "assets", "ui")
IMG = os.path.join(ICI, "img")
MARGE_CORPS = 40
SCENES = ["duel", "sol", "mur", "scinde"]
ETATS = ["allumees", "eteintes"]
QUALITE = 85

# id, drapeau, titre, scènes montrées, illustrations cibles, ce que c'est (réglage lu dans le code)
ESSAIS = [
    ("faisceau", "--faisceau", "Le cœur chaud à la lampe", ["duel", "scinde"], ["ill_intro_allumage", "ill_accueil"],
     "Une lueur posée à la lampe même de chaque torche allumée (iso_volumes.gd, _suivre_faisceau), de la couleur de "
     "la lumière, sans rayon."),
    ("mannequin", "--mannequin", "Le mannequin", ["duel", "scinde"], ["ill_ecran_scinde", "ill_accueil"],
     "Les corps en segments articulés, le côté de la lumière contrasté (MANNEQUIN_CONTRASTE 0,4, report 1,6) et un "
     "contour (voxel_catalogue.gd)."),
    ("pochoirs", "--pochoirs-essai", "Les pochoirs au sol", ["sol", "scinde"], ["ill_creer_local"],
     "« ZONE n » et « DEATHMATCH » peints au sol, symétriques par carte ; une peinture sombre : le sol × 0,55 sous la "
     "lettre (arena_decor.gd, POCHOIR_PEINTURE alpha 0,45)."),
    ("encre", "--encre-essai", "L'encre : hachures, arêtes, contour de 1 px", ["duel", "mur", "scinde"],
     ["ill_ecran_scinde", "ill_accueil"],
     "Hachures dans la pénombre (HACHURES_ESSAI 0,7) sur le sol, les murs et les corps ; arêtes des murs à 2,4 px et "
     "plus noires (reste 0,12) ; contour des personnages de 1 px du monde, soit 1,5 px d'écran au zoom ×1,5 "
     "(iso_materiaux.gd, CONTOUR_PX_ESSAI 1,0 ; voxel_corps.gd l'applique sous ce seul drapeau)."),
    ("tuyaux", "--tuyaux-essai", "Les tuyaux et câbles des murs", ["mur", "duel", "scinde"], ["ill_entrainement"],
     "Conduites cerclées de colliers, descentes et câbles sur les faces de mur (tuyaux_iso.gd), relisant la lumière "
     "de la face qu'ils recouvrent à l'écran ; fusionné depuis origin/claude/cloud-tuyaux (70ffafa)."),
    ("tuyaux_pres", "--tuyaux-essai --zoom-photo=4.5", "Les tuyaux de près (caméra ×4,5, trois fois le zoom du duel)",
     ["mur"], ["ill_entrainement"],
     "Le même essai rendu de près (un vrai rendu, pas un agrandissement), comparé au même instant sans les tuyaux."),
    ("corps", "--corps-detaille", "Les personnages détaillés", ["duel", "scinde"], ["ill_ecran_scinde", "ill_accueil"],
     "Accessoires modelés (bandoulière, cartouches, plaques…) et matière peinte, pour les dix classes "
     "(voxel_catalogue.gd, CLASSES_DETAILLEES) ; fusionné depuis origin/iso12-corps (f38e5f7)."),
]


def lire(dossier, cle):
    chemin = os.path.join(PRISES, dossier, cle + ".png")
    if not os.path.exists(chemin):
        return None
    return np.asarray(Image.open(chemin).convert("RGB")).astype(np.int16)


def dilater(masque, r):
    """Élargit un masque booléen d'un carré de côté 2r+1 (somme cumulée, sans scipy)."""
    m = masque.astype(np.int32)
    c = np.pad(m, ((r + 1, r), (r + 1, r))).cumsum(0).cumsum(1)
    s = c[2 * r + 1:, 2 * r + 1:] - c[:-2 * r - 1, 2 * r + 1:] - c[2 * r + 1:, :-2 * r - 1] + c[:-2 * r - 1, :-2 * r - 1]
    return s > 0


def jpeg(tab, nom, largeur=None):
    im = Image.fromarray(tab.astype(np.uint8))
    if largeur and im.width != largeur:
        im = im.resize((largeur, round(im.height * largeur / im.width)), Image.LANCZOS)
    im.save(os.path.join(IMG, nom), quality=QUALITE)
    return "img/" + nom


def loupe(tab, centre, facteur=3, taille=(1920, 1080)):
    """Recadre 1/facteur de l'image autour de `centre` et l'agrandit au plus proche voisin : les pixels du jeu, ×3."""
    w, h = taille[0] // facteur, taille[1] // facteur
    x = int(np.clip(centre[0] - w // 2, 0, tab.shape[1] - w))
    y = int(np.clip(centre[1] - h // 2, 0, tab.shape[0] - h))
    coupe = tab[y:y + h, x:x + w]
    return np.repeat(np.repeat(coupe, facteur, 0), facteur, 1), (x, y, w, h)


def compter(essai, t1, t2, zone):
    m_e, m1, m2 = essai.max(2), t1.max(2), t2.max(2)
    change = (np.abs(essai - t1).max(2) > 0)
    noir_strict = (m1 == 0) & (m2 == 0) & (m_e > 0)
    noir_seuil = (m1 <= 7) & (m2 <= 7) & (m_e > 7)
    exces = m_e - np.maximum(m1, m2)
    clair = exces > 2
    r = {}
    for nom, masque in [("hors_corps", ~zone), ("zone_corps", zone)]:
        r[nom] = {
            "changes": int((change & masque).sum()),
            "noirs_allumes_stricts": int((noir_strict & masque).sum()),
            "noirs_allumes_seuil": int((noir_seuil & masque).sum()),
            "plus_clairs": int((clair & masque).sum()),
            "exces_max": int(exces[masque].max()) if masque.any() else 0,
        }
    return r, change


def intra(avec, sans, avec2):
    """Le même processus, le même instant : l'essai contre son absence (`__sans`), et contre lui-même (`__avec2`, le bruit)."""
    m_a, m_s = avec.max(2), sans.max(2)
    exces = m_a - m_s
    emprise = np.abs(avec - sans).max(2) > 0
    r = {
        "changes": int(emprise.sum()),
        "bruit_avec_contre_avec2": int((np.abs(avec - avec2).max(2) > 0).sum()) if avec2 is not None else None,
        "noirs_allumes_stricts": int(((m_s == 0) & (m_a > 0)).sum()),
        "noirs_allumes_seuil": int(((m_s <= 7) & (m_a > 7)).sum()),
        "plus_clairs": int((exces > 2).sum()),
        "plus_clairs_1": int((exces > 0).sum()),
        "exces_max": int(exces.max()),
    }
    if emprise.any():
        r["emprise_lum_moy_avec"] = round(float(m_a[emprise].mean()), 1)
        r["emprise_lum_moy_sans"] = round(float(m_s[emprise].mean()), 1)
        r["emprise_plus_clairs_part"] = round(float((exces[emprise] > 2).mean()), 3)
        hist = np.histogram(exces[emprise & (exces > 2)], bins=[3, 9, 17, 33, 65, 256])[0]
        r["exces_histo_3_8_16_32_64_255"] = [int(h) for h in hist]
        # Dans la lumière de la torche (le mur caché au-dessus de 40/255) : le reflet (les 5 % les plus clairs du tuyau)
        # contre le mur caché, pixel à pixel et en répartition.
        lum = emprise & (m_s > 40)
        if lum.sum() > 50:
            r["lumiere_pixels"] = int(lum.sum())
            r["lumiere_avec_p50_p95_max"] = [int(np.percentile(m_a[lum], q)) for q in (50, 95)] + [int(m_a[lum].max())]
            r["lumiere_sans_p50_p95_max"] = [int(np.percentile(m_s[lum], q)) for q in (50, 95)] + [int(m_s[lum].max())]
            r["lumiere_plus_clairs"] = int((exces[lum] > 2).sum())
    return r, emprise, exces


def carte_exces(avec, emprise, exces):
    """L'image de l'essai en gris, l'emprise en bleu sombre, et en rouge les pixels plus clairs que sans lui (> 2/255)."""
    gris = avec.max(2)
    c = np.stack([gris, gris, gris], 2).astype(np.int16) // 2
    c[emprise] = [20, 40, 90]
    rouge = exces > 2
    c[rouge] = np.stack([np.clip(120 + exces[rouge] * 2, 0, 255), np.zeros(rouge.sum()), np.zeros(rouge.sum())], 1)
    return c


def main():
    os.makedirs(IMG, exist_ok=True)
    mesures = {"prises": PRISES, "scenes": {}, "essais": {}}
    temoins = {}
    zones = {}
    # La zone des corps et le bruit, par scène et état.
    for s in SCENES:
        for e in ETATS:
            cle = f"{s}_{e}"
            t1, t2 = lire("temoin1", cle), lire("temoin2", cle)
            if t1 is None or t2 is None:
                continue
            bruit = np.abs(t1 - t2).max(2) > 0
            zones[cle] = dilater(bruit, MARGE_CORPS)
            temoins[cle] = (t1, t2)
            ys, xs = np.nonzero(bruit)
            mesures["scenes"][cle] = {
                "bruit_pixels": int(bruit.sum()),
                "bruit_max": int(np.abs(t1 - t2).max()),
                "zone_corps_pixels": int(zones[cle].sum()),
                "boite_bruit": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())] if len(xs) else None,
                "t1_allumes": int((t1.max(2) > 0).sum()),
            }
    # Les témoins en JPEG (plein cadre).
    for cle, (t1, _) in temoins.items():
        jpeg(t1, f"temoin_{cle}.jpg")
    # Les illustrations cibles, en 1920 de large au plus.
    for ill in sorted({i for e in ESSAIS for i in e[4]}):
        src = os.path.join(ILLUS, ill + ".png")
        if os.path.exists(src):
            im = Image.open(src).convert("RGB")
            if im.width > 1920:
                im = im.resize((1920, round(im.height * 1920 / im.width)), Image.LANCZOS)
            im.save(os.path.join(IMG, ill + ".jpg"), quality=QUALITE)

    # Le bruit de la zone des corps : un TROISIÈME témoin, compté comme un essai contre les deux premiers.
    for cle in temoins:
        t3 = lire("temoin3", cle)
        if t3 is not None:
            t1, t2 = temoins[cle]
            mesures["scenes"][cle]["temoin3"] = compter(t3, t1, t2, zones[cle])[0]

    for ident, drapeau, titre, montrees, cibles, quoi in ESSAIS:
        m = {"drapeau": drapeau, "titre": titre, "quoi": quoi, "cibles": cibles, "montrees": montrees, "scenes": {}}
        # Le gros plan n'a pas de témoin à son cadrage : seule la comparaison au même instant vaut.
        entre_lancements = ident != "tuyaux_pres"
        for s in SCENES:
            for e in ETATS:
                cle = f"{s}_{e}"
                essai = lire(ident, cle)
                if essai is None or (entre_lancements and cle not in temoins):
                    continue
                entree = {}
                change = None
                if entre_lancements:
                    t1, t2 = temoins[cle]
                    entree["chiffres"], change = compter(essai, t1, t2, zones[cle])
                sans = lire(ident, cle + "__sans")
                r = emprise = exces = None
                if sans is not None:
                    r, emprise, exces = intra(essai, sans, lire(ident, cle + "__avec2"))
                    entree["intra"] = r
                if s in montrees:
                    entree["image"] = jpeg(essai, f"{ident}_{cle}.jpg")
                    ref = t1 if entre_lancements else sans
                    if not entre_lancements:
                        entree["image_temoin"] = entree["image_sans"] = jpeg(sans, f"{ident}_{cle}__sans.jpg")
                        # Le gros plan recadré ×2 sur les tuyaux dans la lumière.
                        vus = emprise & (sans.max(2) > 40)
                        ys, xs = np.nonzero(vus if vus.sum() > 50 else emprise)
                        c = (int(np.median(xs)), int(np.median(ys))) if len(xs) else (960, 540)
                        entree["loupe"] = jpeg(loupe(essai, c, 2)[0], f"{ident}_{cle}_loupe2.jpg")
                        entree["loupe_sans"] = jpeg(loupe(sans, c, 2)[0], f"{ident}_{cle}__sans_loupe2.jpg")
                    else:
                        # La loupe : centrée sur ce que l'essai change (au même instant s'il le peut, sinon contre le
                        # témoin), torches allumées ; la même pour éteint et allumé.
                        if e == "allumees" or s not in m.get("centre", {}):
                            base = emprise if emprise is not None and emprise.any() else change
                            # Là où l'essai se VOIT : les pixels changés dans la lumière, s'il y en a.
                            vus = base & (np.maximum(essai.max(2), ref.max(2)) > 40)
                            ys, xs = np.nonzero(vus if vus.sum() > 50 else base)
                            m.setdefault("centre", {})[s] = (int(np.median(xs)), int(np.median(ys))) if len(xs) else (960, 540)
                        centre = m["centre"][s]
                        l_e, boite = loupe(essai, centre)
                        entree["loupe"] = jpeg(l_e, f"{ident}_{cle}_loupe3.jpg")
                        entree["loupe_temoin"] = jpeg(loupe(ref, centre)[0], f"{ident}_{cle}_loupe3_temoin.jpg")
                        entree["boite_loupe"] = list(boite)
                        if sans is not None:
                            entree["image_sans"] = jpeg(sans, f"{ident}_{cle}__sans.jpg")
                            entree["loupe_sans"] = jpeg(loupe(sans, centre)[0], f"{ident}_{cle}__sans_loupe3.jpg")
                    if sans is not None and ident.startswith("tuyaux") and e == "allumees":
                        carte = carte_exces(essai, emprise, exces)
                        entree["carte_exces"] = jpeg(carte, f"{ident}_{cle}_carte.jpg")
                        if entre_lancements:
                            entree["carte_exces_loupe"] = jpeg(loupe(carte, m["centre"][s])[0],
                                                               f"{ident}_{cle}_carte_loupe3.jpg")
                m["scenes"][cle] = entree
        mesures["essais"][ident] = m

    with open(os.path.join(ICI, "mesures.json"), "w", encoding="utf-8") as f:
        json.dump(mesures, f, ensure_ascii=False, indent=1)
    for k, e in mesures["essais"].items():
        for c, v in e["scenes"].items():
            print(k, c, "hors corps", v.get("chiffres", {}).get("hors_corps"), "| zone", v.get("chiffres", {}).get("zone_corps"),
                  "| intra", v.get("intra"))


if __name__ == "__main__":
    main()
