#!/usr/bin/env python3
"""Q39 — mesure les prises de `tools/photo_corps_sombre.gd` : le corps de soi aujourd'hui (silhouette de soi) et à l'essai
(`--corps-soi-sombre`), pris AU MÊME INSTANT (le jeu gelé, l'essai basculé en direct).

Pour chaque prise `<classe>_<scene>` : `defaut`, `essai`, `defaut2` (le défaut recapturé après l'essai : le bruit, qui doit
être nul), `sans1` (J1 caché : ce qu'il y a derrière lui), `sans2` (J2 caché).

- Le corps de J1 = les pixels où `defaut` ≠ `sans1` (l'empreinte du corps d'aujourd'hui ; l'essai garde la même géométrie et
  le même alpha). Même règle pour J2.
- Le noir absolu : les pixels que l'essai change HORS de l'empreinte du corps local (doivent être 0), et parmi eux ceux qui
  s'allument ; les pixels noirs du défaut qui s'allument hors du corps.
- La lisibilité : sur l'empreinte du corps, la luminance du corps (moyenne, 90e centile = le liseré), celle de ce qu'il cache
  (`sans1`), celle du sol autour (un anneau de 6 px hors de l'empreinte, sur `sans1`), et la part des pixels du corps qui se
  distinguent de ce qu'ils cachent d'au moins 10/255 (« lisibles »).
- L'écran scindé : la vue de J1 à gauche, celle de J2 à droite. Dans la vue de l'ADVERSAIRE, le corps de l'autre joueur doit
  être identique au pixel (compté), et l'essai ne change que le corps du joueur de cette vue.

Luminance Rec. 709 des valeurs sRGB, 0..255. Écrit `mesures.json` et, pour la planche, les recadrages JPEG dans `img/`.

    python3 mesurer.py <dossier des prises> [<dossier de sortie, défaut : ce dossier>]
"""
import json
import os
import sys

import numpy as np
from PIL import Image

SEUIL_LISIBLE = 10.0
ANNEAU = 6


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def charger(dossier, nom):
    chemin = os.path.join(dossier, nom + ".png")
    if not os.path.exists(chemin):
        return None
    return np.asarray(Image.open(chemin).convert("RGB")).astype(np.int16)


def differe(a, b):
    return np.abs(a - b).sum(axis=2) > 0


def dilater(m, r):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy > r * r:
                continue
            out |= np.roll(np.roll(m, dy, axis=0), dx, axis=1)
    return out


def lisibilite(x, derriere, m):
    """Le corps (dans l'image x) sur son empreinte m, contre ce qu'il cache (derriere) et le sol autour."""
    if m.sum() == 0:
        return {}
    lx = lum(x.astype(float))
    ld = lum(derriere.astype(float))
    anneau = dilater(m, ANNEAU) & ~m
    ecart = np.abs(lx[m] - ld[m])
    return {
        "pixels": int(m.sum()),
        "corps_moyenne": round(float(lx[m].mean()), 1),
        "corps_p90": round(float(np.percentile(lx[m], 90)), 1),
        "corps_max": round(float(lx[m].max()), 1),
        "derriere_moyenne": round(float(ld[m].mean()), 1),
        "sol_autour": round(float(ld[anneau].mean()), 1),
        "lisibles": int((ecart >= SEUIL_LISIBLE).sum()),
        "part_lisible": round(float((ecart >= SEUIL_LISIBLE).mean()), 3),
        "contraste_moyen": round(float(ecart.mean()), 1),
    }


def boite(m, marge, w, h, taille=None):
    ys, xs = np.nonzero(m)
    cx, cy = int((xs.min() + xs.max()) / 2), int((ys.min() + ys.max()) / 2)
    if taille is None:
        taille = (xs.max() - xs.min() + 2 * marge, ys.max() - ys.min() + 2 * marge)
    tw, th = taille
    x0 = min(max(cx - tw // 2, 0), w - tw)
    y0 = min(max(cy - th // 2, 0), h - th)
    return (x0, y0, x0 + tw, y0 + th)


def recadrer(dossier, nom, etat, cadre, facteur, sortie):
    im = Image.open(os.path.join(dossier, "%s_%s.png" % (nom, etat))).convert("RGB").crop(cadre)
    if facteur != 1:
        im = im.resize((im.width * facteur, im.height * facteur), Image.NEAREST)
    im.save(sortie, quality=85)


def mesurer(dossier, sortie):
    img = os.path.join(sortie, "img")
    os.makedirs(img, exist_ok=True)
    noms = sorted({f[: -len("_defaut.png")] for f in os.listdir(dossier) if f.endswith("_defaut.png")})
    resultats = {}
    for nom in noms:
        a, b, a2, s1, s2 = (charger(dossier, e) for e in
                            (nom + "_defaut", nom + "_essai", nom + "_defaut2", nom + "_sans1", nom + "_sans2"))
        if a is None or b is None or s1 is None:
            continue
        h, w, _ = a.shape
        r = {"taille": [w, h]}
        r["bruit_defaut_defaut2"] = int(differe(a, a2).sum()) if a2 is not None else None
        m1 = differe(a, s1)
        m2 = differe(a, s2) if s2 is not None else np.zeros_like(m1)
        change = differe(a, b)
        la, lb = lum(a.astype(float)), lum(b.astype(float))
        scinde = nom.endswith("_scinde")
        if not scinde:
            hors = change & ~m1
            r["essai_hors_du_corps"] = int(hors.sum())
            r["essai_allume_hors_du_corps"] = int((hors & (lb > la)).sum())
            r["noir_rallume_hors_du_corps"] = int((hors & (a.sum(axis=2) == 0) & (b.sum(axis=2) > 0)).sum())
            r["essai_dans_le_corps"] = int((change & m1).sum())
            r["aujourd_hui"] = lisibilite(a, s1, m1)
            r["essai"] = lisibilite(b, s1, m1)
            if m1.sum() > 0:
                cadre1 = boite(m1, 0, w, h, (480, 270))
                cadre3 = boite(m1, 0, w, h, (160, 120))
                for etat in ("defaut", "essai"):
                    recadrer(dossier, nom, etat, cadre1, 1, os.path.join(img, "%s_%s_1x.jpg" % (nom, etat)))
                    recadrer(dossier, nom, etat, cadre3, 3, os.path.join(img, "%s_%s_x3.jpg" % (nom, etat)))
        else:
            gauche = np.zeros_like(m1)
            gauche[:, : w // 2] = True
            droite = ~gauche
            # Vue de J1 (gauche) : J1 est « soi », J2 l'adversaire ; vue de J2 (droite) : l'inverse.
            r["vue_j1"] = {
                "essai_hors_du_corps_de_soi": int((change & gauche & ~m1).sum()),
                "adversaire_j2_pixels": int((m2 & gauche).sum()),
                "adversaire_j2_change": int((change & m2 & gauche & ~m1).sum()),
                "soi": {"aujourd_hui": lisibilite(a, s1, m1 & gauche), "essai": lisibilite(b, s1, m1 & gauche)},
            }
            r["vue_j2"] = {
                "essai_hors_du_corps_de_soi": int((change & droite & ~m2).sum()),
                "adversaire_j1_pixels": int((m1 & droite).sum()),
                "adversaire_j1_change": int((change & m1 & droite & ~m2).sum()),
                "soi": {"aujourd_hui": lisibilite(a, s2, m2 & droite), "essai": lisibilite(b, s2, m2 & droite)},
            }
            r["noir_rallume_hors_des_corps"] = int((change & ~m1 & ~m2 & (a.sum(axis=2) == 0) & (b.sum(axis=2) > 0)).sum())
            for cote, m in (("j1", m1 & gauche), ("j2", m2 & droite)):
                if m.sum() == 0:
                    continue
                cadre3 = boite(m, 0, w, h, (160, 120))
                for etat in ("defaut", "essai"):
                    recadrer(dossier, nom, etat, cadre3, 3, os.path.join(img, "%s_%s_%s_x3.jpg" % (nom, cote, etat)))
            # L'adversaire vu dans la vue d'en face : J1 dans la vue de J2, au pixel.
            if (m1 & droite).sum() > 0:
                cadre3 = boite(m1 & droite, 0, w, h, (160, 120))
                for etat in ("defaut", "essai"):
                    recadrer(dossier, nom, etat, cadre3, 3, os.path.join(img, "%s_j1_chez_j2_%s_x3.jpg" % (nom, etat)))
            for etat in ("defaut", "essai"):
                im = Image.open(os.path.join(dossier, "%s_%s.png" % (nom, etat))).convert("RGB")
                im.resize((960, 540), Image.LANCZOS).save(os.path.join(img, "%s_%s_ecran.jpg" % (nom, etat)), quality=85)
        resultats[nom] = r
        print(nom, json.dumps(r, ensure_ascii=False))
    with open(os.path.join(sortie, "mesures.json"), "w") as f:
        json.dump(resultats, f, indent=1, ensure_ascii=False)
    return resultats


if __name__ == "__main__":
    mesurer(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else os.path.dirname(os.path.abspath(__file__)))
