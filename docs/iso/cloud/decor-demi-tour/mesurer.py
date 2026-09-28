#!/usr/bin/env python3
"""Le jumeau par le demi-tour, à l'image — les mesures et la planche.

Lit les prises de `tools/photo_demi_tour.gd` (deux séances : `avant`, la base 8ad6495 ; `apres`, la branche), et pour
chaque scène (pochoirs, cadres, tuyaux), dans chaque MOITIÉ de l'écran scindé (J1 à gauche, J2 à droite, J2 au demi-tour
de J1, lacet 45° B) :
    - le décor   = pixels qui changent entre A (le décor) et B (le décor retiré), au même instant ;
    - le bruit   = pixels qui changent entre A et A' (le décor remis) : 0 attendu, le jeu est figé ;
    - plus clair = pixels de A plus clairs que B de 2/255 ou plus sur un canal (le décor n'éclaircit jamais) ;
    - le noir    = scène `<nom>_noir`, torches éteintes : pixels noirs (0, 0, 0) de B qui ne le sont plus en A ou en A'.

    python3 docs/iso/cloud/decor-demi-tour/mesurer.py            # SOURCE : le user:// du jeu, dossier demi-tour
Écrit mesures.json, img/*.jpg et planche.html à côté de ce script.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.environ.get("DT_SOURCE", os.path.expanduser("~/.local/share/godot/app_userdata/Candela 2D/demi-tour"))
SEANCES = ["avant", "apres"]
SCENES = ["pochoirs", "cadres", "tuyaux"]
LEGENDES = {
    "pochoirs": "Pochoirs — J1 devant « ZONE 1 » (8, 23), J2 devant la place jumelle (23, 8)",
    "cadres": "Sol marqué — J1 devant le cadre du « DEATHMATCH » nord (15,5, 6), J2 devant le jumeau (15,5, 25)",
    "tuyaux": "Tuyaux — J1 devant la face sud du mur d'enceinte nord, J2 devant la face nord du mur sud",
}


def charger(seance, nom):
    chemin = os.path.join(SOURCE, seance, nom + ".png")
    if not os.path.exists(chemin):
        return None
    return np.asarray(Image.open(chemin).convert("RGB")).astype(np.int16)


def moities(x):
    w = x.shape[1] // 2
    return {"j1": x[:, :w], "j2": x[:, w:2 * w]}


def change(a, b):
    return np.abs(a - b).max(-1) > 0


def noirs_allumes(a, b):
    noir_b = b.max(-1) == 0
    return int((noir_b & (a.max(-1) > 0)).sum()), int(noir_b.sum())


def jpeg(x, nom, echelle=0.5):
    os.makedirs(os.path.join(ICI, "img"), exist_ok=True)
    img = Image.fromarray(np.clip(x, 0, 255).astype(np.uint8))
    if echelle != 1:
        img = img.resize((int(img.width * echelle), int(img.height * echelle)), Image.LANCZOS)
    chemin = os.path.join("img", nom + ".jpg")
    img.save(os.path.join(ICI, chemin), quality=85)
    return chemin


def carte_du_decor(a, b):
    """Le décor seul, en rouge sur l'image B assombrie : où A diffère de B."""
    fond = (b * 0.35).astype(np.int16)
    m = change(a, b)
    fond[m] = [255, 60, 40]
    return fond


def main():
    mesures = {}
    for s in SEANCES:
        for nom in SCENES:
            a, b, a2 = charger(s, nom + "_A"), charger(s, nom + "_B"), charger(s, nom + "_A2")
            if a is None or b is None or a2 is None:
                print(f"  ! {s}/{nom} : prises absentes", file=sys.stderr)
                continue
            m = {}
            for j, (ma, mb, ma2) in {k: (moities(a)[k], moities(b)[k], moities(a2)[k]) for k in ("j1", "j2")}.items():
                m[j] = {
                    "decor": int(change(ma, mb).sum()),
                    "bruit": int(change(ma, ma2).sum()),
                    "plus_clair": int(((ma - mb).max(-1) >= 2).sum()),
                }
            na, nb, na2 = charger(s, nom + "_noir_A"), charger(s, nom + "_noir_B"), charger(s, nom + "_noir_A2")
            if na is not None and nb is not None and na2 is not None:
                for j in ("j1", "j2"):
                    x, y, z = moities(na)[j], moities(nb)[j], moities(na2)[j]
                    n_a, n_b = noirs_allumes(x, y)
                    n_a2, _ = noirs_allumes(z, y)
                    m[j]["noirs_de_B"] = n_b
                    m[j]["noirs_allumes_A"] = n_a
                    m[j]["noirs_allumes_A2"] = n_a2
                    m[j]["noir_decor"] = int(change(x, y).sum())
            w = a.shape[1] // 2
            for j, sl in (("j1", slice(0, w)), ("j2", slice(w, 2 * w))):
                m[j]["img_A"] = jpeg(a[:, sl], f"{s}_{nom}_{j}_A")
                m[j]["img_carte"] = jpeg(carte_du_decor(a[:, sl], b[:, sl]), f"{s}_{nom}_{j}_carte")
            mesures.setdefault(s, {})[nom] = m
            print(f"{s:6s} {nom:9s} J1 décor {m['j1']['decor']:6d} px · J2 décor {m['j2']['decor']:6d} px · "
                  f"bruit {m['j1']['bruit']}/{m['j2']['bruit']} · plus clair {m['j1']['plus_clair']}/{m['j2']['plus_clair']}"
                  + (f" · noir allumé J1 {m['j1']['noirs_allumes_A']}/{m['j1']['noirs_allumes_A2']}"
                     f" J2 {m['j2']['noirs_allumes_A']}/{m['j2']['noirs_allumes_A2']}"
                     f" (sur {m['j1']['noirs_de_B']}+{m['j2']['noirs_de_B']})" if "noirs_de_B" in m["j1"] else ""))
    with open(os.path.join(ICI, "mesures.json"), "w", encoding="utf-8") as f:
        json.dump(mesures, f, ensure_ascii=False, indent=1)
    planche(mesures)


def planche(mesures):
    lignes = []
    for nom in SCENES:
        lignes.append(f"<h2>{LEGENDES[nom]}</h2>")
        for s in SEANCES:
            m = mesures.get(s, {}).get(nom)
            if m is None:
                continue
            titre = "Avant (la base, 8ad6495)" if s == "avant" else "Après (cette branche)"
            cellules = []
            for j, qui in (("j1", "J1 (moitié gauche)"), ("j2", "J2 (moitié droite, au demi-tour)")):
                d = m[j]
                noir = (f"torches éteintes : {d['noirs_allumes_A']} / {d['noirs_allumes_A2']} pixel(s) noir(s) allumé(s)"
                        if "noirs_de_B" in d else "")
                cellules.append(
                    f"<figure><img src='{d['img_A']}' alt='{s} {nom} {j}'><img src='{d['img_carte']}' alt='décor'>"
                    f"<figcaption><b>{qui}</b> — <b>{d['decor']}</b> pixels de décor · bruit {d['bruit']} · "
                    f"plus clair {d['plus_clair']}<br>{noir}</figcaption></figure>")
            lignes.append(f"<h3>{titre}</h3><div class='rang'>{''.join(cellules)}</div>")
    html = f"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Décor demi-tour</title>
<style>
:root {{ --fond: #f6f5f2; --texte: #1d1c1a; --doux: #5c5a55; }}
@media (prefers-color-scheme: dark) {{ :root {{ --fond: #151513; --texte: #ecebe7; --doux: #a5a39c; }} }}
body {{ background: var(--fond); color: var(--texte); font: 15px/1.45 system-ui, sans-serif; margin: 0 auto;
  max-width: 1400px; padding: 16px; }}
h1 {{ font-size: 1.5rem; }} h2 {{ font-size: 1.15rem; margin-top: 2.2rem; }} h3 {{ font-size: 1rem; color: var(--doux); }}
.rang {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 12px; }}
figure {{ margin: 0; }} img {{ width: 100%; display: block; margin-bottom: 4px; }}
figcaption {{ font-size: 0.85rem; color: var(--doux); }}
</style></head><body>
<h1>Le jumeau par le demi-tour — avant / après</h1>
<p>Écran scindé, lacet 45° B (le défaut). J2 est posé au <b>demi-tour</b> de J1 et vise à l'opposé : il regarde, depuis le
côté opposé, la place jumelle de celle que regarde J1. Pour chaque moitié : la prise (le décor posé), puis le décor seul en
rouge (les pixels qui changent quand on le retire, au même instant). Un décor équitable montre autant de rouge des deux
côtés. Rendu logiciel du cloud : les images valent pour le noir, les couleurs et les comptes, pas pour la cadence.</p>
{''.join(lignes)}
</body></html>
"""
    with open(os.path.join(ICI, "planche.html"), "w", encoding="utf-8") as f:
        f.write(html)


main()
