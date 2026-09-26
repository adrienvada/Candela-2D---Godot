#!/usr/bin/env python3
"""Q33 — analyse des prises de `tools/planche_q33.gd` : chiffres, découpes JPEG et planche HTML.

    python3 docs/iso/cloud/q33/analyse_q33.py "<dossier des prises>" docs/iso/cloud/q33

Pour chaque classe, scène (mi, b15, b10, noir, soi) et mode (d0 sans détail, d1 avec) :
- SILHOUETTE : les pixels où la prise `sil` (corps forcé en pleine lumière) diffère du sol seul (`vide`) de plus de
  2/255 sur un canal, dans une fenêtre autour du corps ;
- VISIBLES : les pixels de la silhouette dont la prise réelle n'est pas noire (un canal > 0) ;
- part visible = visibles / silhouette ;
- contour : pixels de la silhouette d0 absents de d1, et l'inverse ;
- noir absolu : à la scène `noir`, pixels non noirs dans la silhouette, et pixels de la prise réelle qui diffèrent du sol
  seul dans la fenêtre ;
- « triangles noirs » : à `mi`, pixels de la silhouette noirs en d1 et non noirs en d0 (et l'inverse).
Chiffres INDICATIFS : rendu logiciel (llvmpipe) ; l'étalonnage au seuil qui fait foi se fait sur le Mac.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

SRC, DST = sys.argv[1], sys.argv[2]
FEN = (140, 170)  # demi-largeur, demi-hauteur de la fenêtre de mesure autour du corps (pixels d'écran)
LOUPE = (60, 70)  # demi-fenêtre de la loupe ×3
JEU = (240, 135)  # demi-fenêtre « taille du jeu » (1:1, 480×270)
NOMS = {"pistolet": "Parasite", "fusil": "Illusionniste", "pompe": "Terrassier", "arbalete": "Braconnier",
        "occulteur": "Occulteur", "fumiste": "Fumiste", "incendiaire": "Incendiaire", "sentinelle": "Sentinelle",
        "allumeur": "Allumeur", "spectre": "Spectre"}
ORDRE = list(NOMS)
SCENES = ["mi", "b15", "b10", "noir", "soi"]

journal = json.load(open(os.path.join(SRC, "journal.json")))
prises = {p["fichier"]: p for p in journal["prises"]}
_cache = {}


def img(nom):
    if nom not in _cache:
        _cache[nom] = np.asarray(Image.open(os.path.join(SRC, nom)).convert("RGB")).astype(np.int16)
    return _cache[nom]


def fenetre(centre, demi, forme):
    x, y = int(round(centre[0])), int(round(centre[1]))
    x0, y0 = max(0, x - demi[0]), max(0, y - demi[1])
    x1, y1 = min(forme[1], x + demi[0]), min(forme[0], y + demi[1])
    return slice(y0, y1), slice(x0, x1)


def mesure(slug, scene, mode):
    base = f"{slug}_{scene}_d{mode}"
    reel, sil = base + "_reel.png", base + "_sil.png"
    if reel not in prises or sil not in prises:
        return None
    vide = f"vide_soi_{slug}_d{mode}.png" if scene == "soi" else f"vide_{scene}.png"
    R, S, V = img(reel), img(sil), img(vide)
    w = fenetre(prises[reel]["ecran"], FEN, R.shape)
    masque = (np.abs(S[w] - V[w]).max(axis=2) > 2)
    allume = R[w].max(axis=2) > 0
    n_sil = int(masque.sum())
    n_vis = int((masque & allume).sum())
    ys, xs = np.nonzero(masque)
    boite = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())] if n_sil else None
    return {"reel": reel, "sil": sil, "vide": vide, "fenetre": w, "masque": masque, "allume": allume,
            "n_sil": n_sil, "n_vis": n_vis, "part": (n_vis / n_sil) if n_sil else 0.0,
            "niveau": prises[reel]["niveau"], "diff_sol": int((np.abs(R[w] - V[w]).max(axis=2) > 0).sum()),
            "hors_sil_allume": int((allume & ~masque & (np.abs(R[w] - V[w]).max(axis=2) > 0)).sum()),
            # Noir absolu : pixels de la silhouette PLUS CLAIRS que le sol seul, et pixels allumés là où le sol est noir.
            "plus_clair": int((masque & (R[w].max(axis=2) > V[w].max(axis=2))).sum()),
            "allume_sur_noir": int((masque & allume & (V[w].max(axis=2) == 0)).sum()),
            "boite": boite, "ecran": prises[reel]["ecran"]}


def jpeg(tableau, chemin, echelle=1):
    im = Image.fromarray(tableau.astype(np.uint8))
    if echelle != 1:
        im = im.resize((im.width * echelle, im.height * echelle), Image.NEAREST)
    im.save(chemin, quality=85)


os.makedirs(os.path.join(DST, "img"), exist_ok=True)
res = {}
for slug in ORDRE:
    for scene in SCENES:
        m0, m1 = mesure(slug, scene, 0), mesure(slug, scene, 1)
        if m0 is None or m1 is None:
            continue
        d = {"d0": m0, "d1": m1}
        # Contour : même fenêtre (même position du corps dans les deux modes).
        d["sil_d0_seul"] = int((m0["masque"] & ~m1["masque"]).sum())
        d["sil_d1_seul"] = int((m1["masque"] & ~m0["masque"]).sum())
        R0, R1 = img(m0["reel"])[m0["fenetre"]], img(m1["reel"])[m1["fenetre"]]
        diff = np.abs(R0 - R1).max(axis=2)
        d["diff_n"] = int((diff > 0).sum())
        d["diff_max"] = int(diff.max())
        inter = m0["masque"] & m1["masque"]
        d["noir_d1_seul"] = int((inter & ~m1["allume"] & m0["allume"]).sum())
        d["noir_d0_seul"] = int((inter & ~m0["allume"] & m1["allume"]).sum())
        res[(slug, scene)] = d
        # Découpes : taille du jeu (1:1) et loupe ×3, d0 et d1.
        for mode, m in (("d0", m0), ("d1", m1)):
            R = img(m["reel"])
            jpeg(R[fenetre(m["ecran"], JEU, R.shape)], os.path.join(DST, "img", f"{slug}_{scene}_{mode}_jeu.jpg"))
            jpeg(R[fenetre(m["ecran"], LOUPE, R.shape)], os.path.join(DST, "img", f"{slug}_{scene}_{mode}_x3.jpg"), 3)
            if scene == "mi":
                jpeg(R, os.path.join(DST, "img", f"{slug}_{scene}_{mode}_plein.jpg"))
        # Contour : d0 seul en rouge, d1 seul en vert, commun en gris (loupe ×3).
        h, w_ = m0["masque"].shape
        c = np.zeros((h, w_, 3), np.uint8)
        c[inter] = (110, 110, 110)
        c[m0["masque"] & ~m1["masque"]] = (230, 40, 40)
        c[m1["masque"] & ~m0["masque"]] = (40, 230, 40)
        cy, cx = h // 2, w_ // 2
        jpeg(c[max(0, cy - LOUPE[1]):cy + LOUPE[1], max(0, cx - LOUPE[0]):cx + LOUPE[0]],
             os.path.join(DST, "img", f"{slug}_{scene}_contour_x3.jpg"), 3)

# Contrôle : deux prises `mi` du même mode, à la suite.
controle = {}
for slug in ORDRE:
    a, b = f"{slug}_mi_d0_reel.png", f"{slug}_mi_d0_ctl_reel.png"
    if a in prises and b in prises:
        w = fenetre(prises[a]["ecran"], FEN, img(a).shape)
        dd = np.abs(img(a)[w] - img(b)[w]).max(axis=2)
        de = np.abs(img(a) - img(b)).max(axis=2)
        controle[slug] = (int((dd > 0).sum()), int(dd.max()), int((de > 0).sum()))

# Illustrations cibles.
for nom in ["ill_ecran_scinde", "ill_accueil"]:
    src = f"assets/ui_illustrations/{nom}.png"
    if os.path.exists(src):
        im = Image.open(src).convert("RGB")
        im.thumbnail((1280, 1280))
        im.save(os.path.join(DST, "img", nom + ".jpg"), quality=85)

# Tableau texte + JSON.
lignes = []
chiffres = {}
for slug in ORDRE:
    for scene in SCENES:
        d = res.get((slug, scene))
        if d is None:
            continue
        m0, m1 = d["d0"], d["d1"]
        chiffres[f"{slug}/{scene}"] = {
            "niveau": round(m0["niveau"], 3), "sil_d0": m0["n_sil"], "sil_d1": m1["n_sil"],
            "vis_d0": m0["n_vis"], "vis_d1": m1["n_vis"], "part_d0": round(m0["part"], 3),
            "part_d1": round(m1["part"], 3), "sil_d0_seul": d["sil_d0_seul"], "sil_d1_seul": d["sil_d1_seul"],
            "diff_n": d["diff_n"], "diff_max": d["diff_max"], "noir_d1_seul": d["noir_d1_seul"],
            "noir_d0_seul": d["noir_d0_seul"], "hors_sil_d0": m0["hors_sil_allume"],
            "hors_sil_d1": m1["hors_sil_allume"], "plus_clair_d0": m0["plus_clair"], "plus_clair_d1": m1["plus_clair"],
            "sur_noir_d0": m0["allume_sur_noir"], "sur_noir_d1": m1["allume_sur_noir"], "boite_d0": m0["boite"], "boite_d1": m1["boite"]}
json.dump({"chiffres": chiffres, "controle": controle, "positions": journal["positions"], "commit": journal["commit"]},
          open(os.path.join(DST, "chiffres.json"), "w"), indent=1, ensure_ascii=False)


def f(x):
    return f"{x:.2f}".replace(".", ",")


out = ["| Classe | Scène | niveau | silhouette d0 → d1 | visibles d0 → d1 | part d0 → d1 | contour (d0 seul / d1 seul) "
       "| écart d0/d1 (px, max) | noir d1 seul / d0 seul | plus clair que le sol d0/d1 | allumé sur sol noir d0/d1 |",
       "|" + "---|" * 11]
for slug in ORDRE:
    for scene in SCENES:
        c = chiffres.get(f"{slug}/{scene}")
        if c is None:
            continue
        out.append(f"| {NOMS[slug]} | {scene} | {f(c['niveau'])} | {c['sil_d0']} → {c['sil_d1']} | {c['vis_d0']} → "
                   f"{c['vis_d1']} | {f(c['part_d0'])} → {f(c['part_d1'])} | {c['sil_d0_seul']} / {c['sil_d1_seul']} "
                   f"| {c['diff_n']}, {c['diff_max']} | {c['noir_d1_seul']} / {c['noir_d0_seul']} | {c['plus_clair_d0']} / "
                   f"{c['plus_clair_d1']} | {c['sur_noir_d0']} / {c['sur_noir_d1']} |")
open(os.path.join(DST, "tableau.md"), "w").write("\n".join(out) + "\n\n Contrôle (mi, d0 deux fois) : "
                                                  + ", ".join(f"{k} {v[0]} px autour du corps (max {v[1]}), {v[2]} sur l'image entière" for k, v in controle.items()) + "\n")

# Planche HTML autonome.
SC_TITRE = {"mi": "mi-distance", "b15": "bord, 0,15", "b10": "bord, 0,10 (seuil)", "noir": "hors lumière",
            "soi": "le joueur sous sa torche"}
h = ["<!doctype html><html lang=fr><head><meta charset=utf-8><meta name=viewport content='width=device-width'>",
     "<title>Q33 — personnages détaillés au duel</title><style>",
     "body{background:#111;color:#ddd;font:14px/1.4 system-ui,sans-serif;margin:16px}img{max-width:100%;display:block}",
     "h2{border-top:1px solid #444;padding-top:12px}.rang{display:flex;flex-wrap:wrap;gap:12px}",
     ".case{background:#1b1b1b;padding:8px}.paire{display:flex;gap:4px}.paire div{flex:1}small{color:#999}",
     "table{border-collapse:collapse}td,th{border:1px solid #333;padding:2px 6px;text-align:right}</style></head><body>",
     "<h1>Q33 — les personnages détaillés au duel, dix classes</h1>",
     f"<p>Commit {journal['commit']}. Rendu logiciel du cloud (llvmpipe) : chiffres <b>indicatifs</b> — l'étalonnage au "
     "seuil qui fait foi se fait sur le Mac. Dans chaque paire : à gauche <b>sans</b> détail (d0), à droite <b>avec</b> "
     "(d1), même instant, même cadrage (1920×1080, ×1,5, 45°). Contour : gris = commun, rouge = d0 seul, vert = d1 seul.</p>",
     "<h2>Les illustrations cibles</h2><div class=rang>",
     "<div class=case><img src='img/ill_ecran_scinde.jpg'><small>ill_ecran_scinde.png</small></div>",
     "<div class=case><img src='img/ill_accueil.jpg'><small>ill_accueil.png</small></div></div>"]
for slug in ORDRE:
    if (slug, "mi") not in res:
        continue
    h.append(f"<h2>{NOMS[slug]} <small>({slug})</small></h2>")
    h.append(f"<div class=paire><div><img src='img/{slug}_mi_d0_plein.jpg'><small>image entière, sans détail</small></div>"
             f"<div><img src='img/{slug}_mi_d1_plein.jpg'><small>image entière, avec détail</small></div></div>")
    h.append("<div class=rang>")
    for scene in SCENES:
        c = chiffres.get(f"{slug}/{scene}")
        if c is None:
            continue
        h.append(f"<div class=case><b>{SC_TITRE[scene]}</b> <small>capteur {f(c['niveau'])}</small>"
                 f"<div class=paire><div><img src='img/{slug}_{scene}_d0_jeu.jpg'></div>"
                 f"<div><img src='img/{slug}_{scene}_d1_jeu.jpg'></div></div><small>taille du jeu (1:1)</small>"
                 f"<div class=paire><div><img src='img/{slug}_{scene}_d0_x3.jpg'></div>"
                 f"<div><img src='img/{slug}_{scene}_d1_x3.jpg'></div><div><img src='img/{slug}_{scene}_contour_x3.jpg'>"
                 f"</div></div><small>loupe ×3 · contour</small><br><small>visibles {c['vis_d0']} → {c['vis_d1']} "
                 f"px sur {c['sil_d0']} → {c['sil_d1']} (part {f(c['part_d0'])} → {f(c['part_d1'])}) · contour "
                 f"{c['sil_d0_seul']} / {c['sil_d1_seul']} px · écart d0/d1 {c['diff_n']} px (max {c['diff_max']})"
                 + (f" · <b>hors lumière : plus clairs que le sol {c['plus_clair_d0']} / {c['plus_clair_d1']}, allumés sur sol noir "
                    f"{c['sur_noir_d0']} / {c['sur_noir_d1']}</b>" if scene == "noir" else "")
                 + "</small></div>")
    h.append("</div>")
h.append("<h2>Tableau</h2><table><tr><th>classe<th>scène<th>niveau<th>part d0<th>part d1<th>vis d0<th>vis d1"
         "<th>sil d0<th>sil d1<th>contour d0/d1 seul</tr>")
for k, c in chiffres.items():
    s, sc = k.split("/")
    h.append(f"<tr><td>{NOMS[s]}<td>{sc}<td>{f(c['niveau'])}<td>{f(c['part_d0'])}<td>{f(c['part_d1'])}<td>{c['vis_d0']}"
             f"<td>{c['vis_d1']}<td>{c['sil_d0']}<td>{c['sil_d1']}<td>{c['sil_d0_seul']} / {c['sil_d1_seul']}</tr>")
h.append("</table></body></html>")
open(os.path.join(DST, "planche.html"), "w").write("\n".join(h))
print("\n".join(out))
print("contrôle", controle)
