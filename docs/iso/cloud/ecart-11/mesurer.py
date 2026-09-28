#!/usr/bin/env python3
"""L'écart aux illustrations, évaluation 11 — les chiffres et les JPEG.

Lit les prises de `tools/photo_ecart.gd` (user://ecart11/{defaut,temoin,hier,tout}/<scene>.png, ou $ECART_SOURCE) et les
illustrations `assets/ui/ill_*.png`. Écrit `img/` (JPEG qualité 85) et `mesures.json`.

Les mesures de l'évaluation 10 (`../ecart-illustrations/mesurer.py`), reprises telles quelles, plus celles qui y étaient
faites à la main :
- par image : `eclaire` (part plus claire que 7,5/255 au canal maximal), `noir_strict`, `lum_moy`, `mediane`, `d9` (9e
  décile de luminance), `top1` (seuil du 1 % le plus clair) et `top1_rgb` (la couleur moyenne de ce 1 %), `teinte` ;
  luminance Rec. 709 des valeurs sRGB, 0..255 ;
- le corps du joueur local (scènes prises aussi « sans corps », au même instant gelé) : les pixels qui changent de plus de
  8/255 quand les corps 3D sont cachés, la composante connexe de J1 (en bas à gauche de J2 au lacet 45° B) ; sa couleur et
  sa luminance moyennes, son nombre de pixels ;
- entre deux lancements (témoin, hier, tout contre défaut) : pixels changés, plus clairs, plus sombres, noirs allumés ;
- l'écart à l'illustration : `emd` (distance moyenne entre les deux distributions de luminance, quantile à quantile — un
  seul nombre pour « trop sombre / trop clair »), l'écart de médiane, du 1 % le plus clair, et de sa couleur (distance RGB) ;
- l'équité (scène `equite`, écran scindé, J1 et J2 aux places symétriques par le centre du Cloître) : par moitié, les
  pixels de décor éclairés, de lumière (> 40), de corps ; et l'écart entre la moitié de J1 et celle de J2 tournée d'un
  demi-tour.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.normpath(os.path.join(ICI, "../../../.."))
sys.path.insert(0, os.path.join(RACINE, "docs/iso/cloud/ecart-illustrations"))
from analyse import ILLUSTRATIONS  # noqa: E402 — le choix de la scène par illustration, repris de l'évaluation 10

SOURCE = os.environ.get("ECART_SOURCE") or os.path.expanduser(
    os.path.join(os.environ.get("XDG_DATA_HOME", "~/.local/share"), "godot/app_userdata/Candela 2D/ecart11"))
LANCEMENTS = ["defaut", "temoin", "hier", "tout"]
SCENES = ["duel", "noir", "scinde", "equite", "sol", "mur", "arena", "zone", "croisee_duel", "croisee_noir",
          "bunker_duel", "bunker_noir", "impacts", "fusee1", "fusee2", "entrainement"]
AVEC_CORPS = ["duel", "croisee_duel", "bunker_duel", "equite"]
NOIRS = ["noir", "croisee_noir", "bunker_noir"]
SEUIL_NOIR = 7.5
SEUIL_CHANGE = 8
SEUIL_LUMIERE = 40.0
QUANTILES = np.linspace(0.005, 0.995, 199)


def lire(chemin):
    return np.asarray(Image.open(chemin).convert("RGB")).astype(np.float32)


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def stats(a):
    mx = a.max(axis=2)
    l = lum(a)
    ecl = mx > SEUIL_NOIR
    top1 = float(np.percentile(l, 99))
    haut = l >= top1
    sortie = {
        "eclaire": round(float(ecl.mean()), 4),
        "noir_strict": round(float((mx == 0).mean()), 4),
        "lum_moy": round(float(l.mean()), 2),
        "mediane": round(float(np.median(l)), 1),
        "d9": round(float(np.percentile(l, 90)), 1),
        "top1": round(top1, 1),
        "top1_rgb": [int(round(v)) for v in a[haut].mean(axis=0)],
        "quantiles": [round(float(q), 1) for q in np.quantile(l, QUANTILES)],
    }
    if ecl.any():
        teinte = a[ecl].mean(axis=0)
        sortie["lum_eclaire"] = round(float(l[ecl].mean()), 2)
        sortie["teinte"] = [int(round(v)) for v in teinte]
    return sortie


def ecart(a, b):
    """Ce qui change de a (défaut) à b."""
    d = np.abs(b - a).max(axis=2)
    la, lb = lum(a), lum(b)
    noirs = a.max(axis=2) <= SEUIL_NOIR
    return {
        "change": int((d > SEUIL_CHANGE).sum()),
        "plus_clair": int((lb - la > SEUIL_CHANGE).sum()),
        "plus_sombre": int((la - lb > SEUIL_CHANGE).sum()),
        "noir_allume": int((noirs & (b.max(axis=2) > SEUIL_NOIR)).sum()),
        "noir_strict_allume": int(((a.max(axis=2) == 0) & (b.max(axis=2) > 0)).sum()),
    }


def noir_trois(a, a2, b):
    """Prises A (défaut), A' (témoin), B (tout) : les pixels noirs dans A ET A' qui s'allument dans B, et, pour le bruit,
    ceux noirs dans A qui s'allument dans A'."""
    na = (a.max(axis=2) <= SEUIL_NOIR) & (a2.max(axis=2) <= SEUIL_NOIR)
    allumes = na & (b.max(axis=2) > SEUIL_NOIR)
    ys, xs = np.nonzero(allumes)
    sortie = {"noir_allume": int(allumes.sum()),
              "bruit": int(((a.max(axis=2) <= SEUIL_NOIR) & (a2.max(axis=2) > SEUIL_NOIR)).sum()),
              "max_allume": int(b.max(axis=2)[allumes].max()) if allumes.any() else 0}
    if allumes.any():
        sortie["boite"] = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
    return sortie


def masque_corps(avec, sans):
    return np.abs(avec - sans).max(axis=2) > SEUIL_CHANGE


def corps_local(avec, sans):
    """La composante de J1 parmi les pixels de corps : les deux plus grandes composantes (8-connexité, après une
    fermeture de 3 px), celle de plus grand (y − x) — J1 est en bas à gauche de J2 dans toutes les scènes de duel."""
    m = ndimage.binary_closing(masque_corps(avec, sans), iterations=3)
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if n == 0:
        return None
    tailles = ndimage.sum(m, lab, range(1, n + 1))
    grandes = [i + 1 for i in np.argsort(tailles)[::-1][:2] if tailles[i] >= 150]
    if not grandes:
        return None
    def rang(k):
        ys, xs = np.nonzero(lab == k)
        return ys.mean() - xs.mean()
    k = max(grandes, key=rang)
    zone = (lab == k) & masque_corps(avec, sans)
    px = avec[zone]
    ys, xs = np.nonzero(zone)
    return {"pixels": int(zone.sum()), "rgb": [int(round(v)) for v in px.mean(axis=0)],
            "lum": round(float(lum(px[None, ...])[0].mean()), 1),
            "lum_p90": round(float(np.percentile(lum(px[None, ...])[0], 90)), 1),
            "centre": [int(xs.mean()), int(ys.mean())], "autres_composantes": len(grandes) - 1}


def moities(a):
    """Les deux vues de l'écran scindé : la colonne du milieu de l'écran (le séparateur) est retirée, chaque moitié garde
    la même largeur."""
    h, w, _ = a.shape
    m = w // 2
    g = a[:, : m - 3]
    d = a[:, m + 3:]
    return g, d


def equite(avec, sans):
    """Au lacet B, la vue de J2 à la place symétrique est déjà dans le même sens que celle de J1 : les deux moitiés se
    comparent telles quelles, pixel à pixel. Le « disque » : la plus grande tache éclairée d'un seul côté (voir
    RAPPORT.md, défaut du défaut) — compté à part, puis retiré des comptes de décor."""
    sortie = {}
    ga, da = moities(avec)
    gs, ds = moities(sans)
    lg, ld = gs.max(axis=2) > SEUIL_NOIR, ds.max(axis=2) > SEUIL_NOIR
    disque = np.zeros_like(lg)
    for seul in (lg & ~ld, ld & ~lg):
        lab, n = ndimage.label(ndimage.binary_opening(seul, iterations=2))
        if n:
            tailles = ndimage.sum(seul, lab, range(1, n + 1))
            k = int(np.argmax(tailles)) + 1
            if tailles[k - 1] >= 2000:
                disque |= ndimage.binary_dilation(lab == k, iterations=3)
    for nom, x, y, l in (("j1", ga, gs, lg), ("j2", da, ds, ld)):
        sortie[nom] = {
            "decor_eclaire": int(l.sum()),
            "decor_hors_disque": int((l & ~disque).sum()),
            "decor_net": int((y.max(axis=2) > 16).sum()),
            "disque": int((l & disque).sum()),
            "lumiere": int((lum(y) > SEUIL_LUMIERE).sum()),
            "corps": int(masque_corps(x, y).sum()),
            "lum_moy": round(float(lum(x).mean()), 2),
        }
    sortie["moities_different"] = int((np.abs(gs - ds).max(axis=2) > SEUIL_CHANGE).sum())
    return sortie


def emd(q1, q2):
    return round(float(np.mean(np.abs(np.array(q1) - np.array(q2)))), 1)


def jpeg(img, sortie, largeur=None):
    if isinstance(img, str):
        img = Image.open(img).convert("RGB")
    elif isinstance(img, np.ndarray):
        img = Image.fromarray(img.astype(np.uint8))
    if largeur and img.width > largeur:
        img = img.resize((largeur, round(img.height * largeur / img.width)), Image.LANCZOS)
    img.save(sortie, quality=85, optimize=True)


def boite_loupe(a):
    """Le cadre 640×360 centré sur la lumière de la prise par défaut (règle de l'évaluation 10)."""
    l = lum(a)
    ys, xs = np.nonzero(l > 60)
    h, w = l.shape
    cx, cy = (float(xs.mean()), float(ys.mean())) if xs.size else (w / 2, h / 2)
    x0 = int(min(max(cx - 320, 0), w - 640))
    y0 = int(min(max(cy - 180, 0), h - 360))
    return (x0, y0, x0 + 640, y0 + 360)


def main():
    img_dir = os.path.join(ICI, "img")
    os.makedirs(img_dir, exist_ok=True)
    m = {"source": SOURCE, "illustrations": {}, "prises": {}, "corps": {}, "ecarts": {}, "noir": {}, "equite": {},
         "a_l_illustration": {}, "loupes": {}}
    ill_dir = os.path.join(RACINE, "assets/ui")
    for nom in sorted(f[:-4] for f in os.listdir(ill_dir) if f.startswith("ill_") and f.endswith(".png")):
        a = lire(os.path.join(ill_dir, nom + ".png"))
        m["illustrations"][nom] = stats(a)
        jpeg(os.path.join(ill_dir, nom + ".png"), os.path.join(img_dir, nom + ".jpg"), 1024)
    manquantes = []
    images = {}
    for scene in SCENES:
        for lanc in LANCEMENTS:
            chemin = os.path.join(SOURCE, lanc, scene + ".png")
            if not os.path.exists(chemin):
                manquantes.append(f"{lanc}/{scene}")
                continue
            a = lire(chemin)
            images[(lanc, scene)] = a
            m["prises"][f"{lanc}/{scene}"] = stats(a)
            if lanc != "temoin":
                jpeg(a, os.path.join(img_dir, f"jeu_{lanc}_{scene}.jpg"))
            sans = os.path.join(SOURCE, lanc, scene + "_sans_corps.png")
            if scene in AVEC_CORPS and os.path.exists(sans):
                s = lire(sans)
                if scene == "equite":
                    m["equite"][lanc] = equite(a, s)
                else:
                    m["corps"][f"{lanc}/{scene}"] = corps_local(a, s)
        if ("defaut", scene) in images:
            base = images[("defaut", scene)]
            if scene not in ("scinde", "equite"):
                boite = boite_loupe(base)
                m["loupes"][scene] = list(boite)
                for lanc in ("defaut", "hier", "tout"):
                    if (lanc, scene) in images:
                        img = Image.fromarray(images[(lanc, scene)].astype(np.uint8)).crop(boite)
                        jpeg(img.resize((1280, 720), Image.LANCZOS), os.path.join(img_dir, f"loupe_{lanc}_{scene}.jpg"))
            for lanc in ("temoin", "hier", "tout"):
                if (lanc, scene) in images:
                    m["ecarts"][f"{lanc}/{scene}"] = ecart(base, images[(lanc, scene)])
            if scene in NOIRS and ("temoin", scene) in images:
                for lanc in ("hier", "tout"):
                    if (lanc, scene) in images:
                        m["noir"][f"{lanc}/{scene}"] = noir_trois(base, images[("temoin", scene)], images[(lanc, scene)])
    # L'écart à l'illustration, pour chaque illustration qui a une scène.
    for ill in ILLUSTRATIONS:
        scene = ill.get("scene")
        s_ill = m["illustrations"].get(ill["nom"])
        if not scene or not s_ill:
            continue
        ligne = {"scene": scene}
        for lanc in ("defaut", "hier", "tout"):
            s = m["prises"].get(f"{lanc}/{scene}")
            if not s:
                continue
            ligne[lanc] = {
                "emd": emd(s_ill["quantiles"], s["quantiles"]),
                "mediane": round(s["mediane"] - s_ill["mediane"], 1),
                "top1": round(s["top1"] - s_ill["top1"], 1),
                "top1_rgb": round(float(np.linalg.norm(np.array(s["top1_rgb"]) - np.array(s_ill["top1_rgb"]))), 1),
            }
        m["a_l_illustration"][ill["nom"]] = ligne
    m["manquantes"] = manquantes
    with open(os.path.join(ICI, "mesures.json"), "w", encoding="utf-8") as f:
        json.dump(m, f, ensure_ascii=False, indent=1)
    print(f"{len(m['prises'])} prises, {len(manquantes)} manquantes : {manquantes}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
