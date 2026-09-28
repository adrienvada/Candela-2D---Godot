#!/usr/bin/env python3
"""Le sol marqué — les mesures, sur les prises de `tools/photo_sol_marque.gd`, et les images de la planche.

Chaque scène a trois prises au même instant, jeu en pause : A (les marques), B (retirées), A' (remises).
    - l'essai     = A − B ;
    - le bruit    = A − A' (doit être nul : même instant, même décor) ;
    - « jamais plus clair » : aucun canal de A au-dessus de B (le seuil d'arrondi, 1/255, est compté à part) ;
    - le noir     = scène `noir` (torches éteintes) : aucun pixel noir de B ne s'allume en A ni en A' ;
    - la symétrie = scène `scinde` : l'assombrissement dans la vue de J1 (moitié gauche) et dans celle de J2 (moitié
                    droite, lacet B, devant le jumeau du même tas) ;
    - le contraste = scènes `contraste*` : le corps de J2 (masque : J2 présent − J2 absent, marques retirées) contre
                    l'anneau de sol autour de lui, sur sol marqué (A) et nu (B).

    SOL_SOURCE="<dossier user://sol-marque>" python3 docs/iso/cloud/sol-marque/mesurer.py
Écrit `mesures.json` et `img/` à côté de ce script. Luminance Rec. 709 des valeurs sRGB, 0..255.
"""
import json, os, sys
import numpy as np
from PIL import Image, ImageFilter

ICI = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.environ.get("SOL_SOURCE",
                        os.path.expanduser("~/.local/share/godot/app_userdata/Candela 2D/sol-marque"))
IMG = os.path.join(ICI, "img")
ILL = os.path.join(ICI, "..", "ecart-illustrations", "img")
FAMILLES = ["gravats", "eclats", "chaine", "cadre", "bande", "lettres"]
# L'illustration de chaque famille, et le cadre (1024×640) où elle montre ce que la famille imite.
ILLUSTRATIONS = {
    "gravats": ("amical", (330, 430, 720, 640), "le tas de gravats au pied du pilier"),
    "eclats": ("intro_prix", (560, 430, 1024, 640), "les éclats épars du couloir (douilles et sang écartés)"),
    "chaine": ("creer_local", (690, 470, 1024, 640), "les chaînes au sol"),
    "cadre": ("creer_local", (100, 420, 820, 640), "les cadres de bandes autour des mots peints"),
    "bande": ("creer_local", (380, 430, 850, 600), "les bandes de marquage (blanches : le jeu les peint sombres)"),
    "lettres": ("creer_local", (120, 470, 480, 610), "les lettres au pochoir"),
}


def charger(seance, nom):
    chemin = os.path.join(SOURCE, seance, nom + ".png")
    if not os.path.exists(chemin):
        return None
    return np.asarray(Image.open(chemin).convert("RGB")).astype(np.int16)


def lum(x):
    return 0.2126 * x[..., 0] + 0.7152 * x[..., 1] + 0.0722 * x[..., 2]


def ecart(a, b):
    """A contre B : combien de pixels changent, s'assombrissent, s'éclaircissent (et de combien)."""
    d = a - b
    change = np.abs(d).max(-1) > 0
    plus_clair_canal = d.max(-1)
    return {
        "pixels_changes": int(change.sum()),
        "plus_sombres": int((lum(a) - lum(b) < -0.5).sum()),
        "plus_clairs_1": int((plus_clair_canal == 1).sum()),     # un canal à +1/255 : l'arrondi
        "plus_clairs_2": int((plus_clair_canal >= 2).sum()),     # au-delà : un vrai éclaircissement
        "eclaircissement_max": int(max(0, plus_clair_canal.max())),
        "assombrissement_moyen": round(float(-(lum(a) - lum(b))[change].mean()), 2) if change.any() else 0.0,
        "assombrissement_somme": round(float(np.clip(lum(b) - lum(a), 0, None).sum()), 1),
    }


def noirs_allumes(a, b):
    """Les pixels noirs (0, 0, 0) de B qui ne le sont plus en A."""
    noir_b = (b.max(-1) == 0)
    return int((noir_b & (a.max(-1) > 0)).sum()), int(noir_b.sum())


def centre_lumiere(b):
    l = lum(b)
    ys, xs = np.nonzero(l > 60)
    if len(xs) == 0:
        return b.shape[1] // 2, b.shape[0] // 2
    return int(np.median(xs)), int(np.median(ys))


def recadrer(x, cx, cy, w, h):
    x0 = int(np.clip(cx - w // 2, 0, x.shape[1] - w))
    y0 = int(np.clip(cy - h // 2, 0, x.shape[0] - h))
    return x[y0:y0 + h, x0:x0 + w], (x0, y0)


def jpeg(x, nom, echelle=1):
    im = Image.fromarray(np.clip(x, 0, 255).astype(np.uint8))
    if echelle != 1:
        im = im.resize((im.width * echelle, im.height * echelle), Image.NEAREST)
    im.save(os.path.join(IMG, nom + ".jpg"), quality=85)
    return "img/" + nom + ".jpg"


def les_images_d_une_famille(seance, fam, a, b, sortie):
    """1:1 (640×360 autour de la lumière) et loupe ×3 (213×120 autour de la marque la plus assombrie du 1:1)."""
    cx, cy = centre_lumiere(b)
    a1, (x0, y0) = recadrer(a, cx, cy, 640, 360)
    b1, _ = recadrer(b, cx, cy, 640, 360)
    d = np.clip(lum(b1) - lum(a1), 0, None)
    if d.sum() > 0:
        # Le centre de la loupe : là où l'assombrissement est le plus dense, lissé sur une fenêtre de 40 px.
        k = np.asarray(Image.fromarray(np.clip(d * 4, 0, 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(20)))
        ly, lx = np.unravel_index(np.argmax(k), k.shape)
    else:
        lx, ly = 320, 180
    a3, _ = recadrer(a1, lx, ly, 213, 120)
    b3, _ = recadrer(b1, lx, ly, 213, 120)
    sortie["jeu_sans"] = jpeg(b1, f"{seance}_{fam}_sans")
    sortie["jeu_avec"] = jpeg(a1, f"{seance}_{fam}_avec")
    sortie["loupe_sans"] = jpeg(b3, f"{seance}_{fam}_loupe_sans", 3)
    sortie["loupe_avec"] = jpeg(a3, f"{seance}_{fam}_loupe_avec", 3)
    sortie["cadre_1_1"] = [x0, y0, 640, 360]


def contraste(seance, nom):
    j2a, j2b = charger(seance, nom + "_j2_A"), charger(seance, nom + "_j2_B")
    va, vb = charger(seance, nom + "_vide_A"), charger(seance, nom + "_vide_B")
    if any(x is None for x in (j2a, j2b, va, vb)):
        return None
    # Le corps : ce que J2 change à l'image, marques retirées (seuil 8 en luminance), la plus grande tache.
    corps = np.abs(lum(j2b) - lum(vb)) > 8
    ys, xs = np.nonzero(corps)
    if len(xs) == 0:
        return {"corps_px": 0}
    cx, cy = int(np.median(xs)), int(np.median(ys))
    zone = np.zeros_like(corps)
    zone[max(0, cy - 80):cy + 80, max(0, cx - 80):cx + 80] = True
    corps &= zone
    m = Image.fromarray((corps * 255).astype(np.uint8))
    anneau = (np.asarray(m.filter(ImageFilter.MaxFilter(17))) > 0) & ~(np.asarray(m.filter(ImageFilter.MaxFilter(5))) > 0)
    res = {"corps_px": int(corps.sum()), "anneau_px": int(anneau.sum()), "centre": [cx, cy]}
    for cle, img, vide in (("marque", j2a, va), ("nu", j2b, vb)):
        lc, la = float(lum(img)[corps].mean()), float(lum(img)[anneau].mean())
        res[cle] = {"corps": round(lc, 2), "anneau": round(la, 2), "difference": round(lc - la, 2),
                    "michelson": round((lc - la) / max(lc + la, 1e-6), 3),
                    "anneau_sans_j2": round(float(lum(vide)[anneau].mean()), 2)}
    a1, _ = recadrer(j2a, cx, cy, 320, 180)
    b1, _ = recadrer(j2b, cx, cy, 320, 180)
    res["img_marque"] = jpeg(a1, f"{seance}_{nom}_marque", 2)
    res["img_nu"] = jpeg(b1, f"{seance}_{nom}_nu", 2)
    return res


def main():
    os.makedirs(IMG, exist_ok=True)
    mesures = {"source": SOURCE, "seances": {}}
    for seance in ("seul", "tous"):
        if not os.path.isdir(os.path.join(SOURCE, seance)):
            continue
        s = mesures["seances"].setdefault(seance, {})
        for nom in FAMILLES + ["noir", "scinde"]:
            a, b, a2 = charger(seance, nom + "_A"), charger(seance, nom + "_B"), charger(seance, nom + "_A2")
            if a is None or b is None or a2 is None:
                continue
            m = {"essai": ecart(a, b), "bruit": ecart(a, a2)}
            n_a, n_b = noirs_allumes(a, b)
            n_a2, _ = noirs_allumes(a2, b)
            m["noirs_de_B"] = n_b
            m["noirs_allumes_A"] = n_a
            m["noirs_allumes_A2"] = n_a2
            if nom in FAMILLES:
                les_images_d_une_famille(seance, nom, a, b, m)
            if nom == "scinde":
                w = a.shape[1] // 2
                m["j1"] = ecart(a[:, :w], b[:, :w])
                m["j2"] = ecart(a[:, w:], b[:, w:])
                # Dans le cône de chacun (le sol que SA torche éclaire, luminance > 40 sans les marques) : ce que chaque
                # joueur voit de la marque qu'il regarde. Et l'empreinte de l'essai d'une vue sur l'autre (J2 est au
                # demi-tour de J1 : les deux moitiés devraient montrer la même chose).
                dl = np.clip(lum(b) - lum(a), 0, None)
                for j, sl in (("j1", slice(0, w)), ("j2", slice(w, 2 * w))):
                    cone = lum(b)[:, sl] > 40
                    m[j + "_cone"] = {"pixels_cone": int(cone.sum()), "assombris": int((dl[:, sl][cone] > 0.5).sum()),
                                      "somme": round(float(dl[:, sl][cone].sum()), 1)}
                e1, e2 = dl[:, :w] > 0.5, dl[:, w:2 * w] > 0.5
                m["empreinte_iou"] = round(float((e1 & e2).sum()) / max(float((e1 | e2).sum()), 1.0), 3)
                m["img_avec"] = jpeg(a, f"{seance}_scinde_avec")
                m["img_sans"] = jpeg(b, f"{seance}_scinde_sans")
            if nom == "noir":
                m["img_avec"] = jpeg(a, f"{seance}_noir_avec")
            if nom == "gravats":
                m["img_plein_avec"] = jpeg(a, f"{seance}_gravats_plein_avec")
                m["img_plein_sans"] = jpeg(b, f"{seance}_gravats_plein_sans")
            s[nom] = m
        for nom in ("contraste4", "contraste7"):
            c = contraste(seance, nom)
            if c is not None:
                s[nom] = c
    for fam, (ill, boite, legende) in ILLUSTRATIONS.items():
        chemin = os.path.join(ILL, "ill_%s.jpg" % ill)
        if os.path.exists(chemin):
            Image.open(chemin).crop(boite).save(os.path.join(IMG, "ill_%s.jpg" % fam), quality=85)
    json.dump(mesures, open(os.path.join(ICI, "mesures.json"), "w"), indent=1, ensure_ascii=False)
    for seance, s in mesures["seances"].items():
        for nom, m in s.items():
            if "essai" in m:
                e, b = m["essai"], m["bruit"]
                print(f"{seance:5} {nom:8} essai {e['pixels_changes']:6} px ({e['plus_sombres']} plus sombres, "
                      f"{e['plus_clairs_1']} à +1, {e['plus_clairs_2']} à +2 ou plus) · bruit {b['pixels_changes']} · "
                      f"noirs allumés A {m['noirs_allumes_A']} A' {m['noirs_allumes_A2']} (sur {m['noirs_de_B']})")
            if nom == "scinde":
                print(f"      scinde J1 : {m['j1']['plus_sombres']} px, somme {m['j1']['assombrissement_somme']} · "
                      f"J2 : {m['j2']['plus_sombres']} px, somme {m['j2']['assombrissement_somme']}")
                print(f"      dans le cône : J1 {m['j1_cone']} · J2 {m['j2_cone']} · empreinte commune (IoU) {m['empreinte_iou']}")
            if nom.startswith("contraste") and "marque" in m:
                print(f"      {nom} corps {m['corps_px']} px · marqué : corps {m['marque']['corps']} anneau "
                      f"{m['marque']['anneau']} (Δ {m['marque']['difference']}) · nu : corps {m['nu']['corps']} anneau "
                      f"{m['nu']['anneau']} (Δ {m['nu']['difference']})")


main()
