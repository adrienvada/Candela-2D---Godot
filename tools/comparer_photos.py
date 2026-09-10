#!/usr/bin/env python3
"""Compose un rendu AVANT / APRÈS à partir de deux séances du photographe.

Refonte roman graphique des effets en jeu (2026-09-10). Adrien juge chaque lot
sur une image, pas sur une description : ce script prend deux dossiers écrits
par `tools/run_photos.sh --sortie=...` et produit, pour chaque plan présent des
deux côtés, une image côte à côte (avant à gauche, après à droite), plus une
planche HTML et une planche PNG de tout le lot.

    python3 tools/comparer_photos.py AVANT APRES SORTIE [--plans id1,id2] [--zoom 2]

`AVANT` et `APRES` sont les dossiers `user://...` réels (imprimés par
`run_photos.sh`). `--plans` restreint aux identifiants donnés (sans le rang
`NN-`). `--zoom` recadre chaque image sur son centre, agrandi d'autant — un
effet de 60 px sur 1920 ne se juge pas en vignette.

Une image de 1920 de large est réduite de moitié par défaut dans la planche PNG ;
les côte à côte individuels restent à pleine taille.

⚠️ Le script mesure aussi ce qui a changé : la part de pixels dont la luminance
diffère de plus de 8/255 entre les deux prises. Deux prises du même état ne sont
jamais identiques (particules, grain) — une différence sous 2 % dit « rien n'a
changé », pas « le lot est raté ».
"""
import argparse
import os
import sys
from PIL import Image, ImageDraw, ImageChops

ETIQ_H = 22


def _lister(dossier):
    """{identifiant: chemin} pour un dossier de séance (familles en sous-dossiers)."""
    out = {}
    for racine, _dirs, fichiers in os.walk(dossier):
        for f in fichiers:
            if not f.endswith(".png"):
                continue
            nom = f[:-4]
            # `NN-identifiant` → `identifiant` ; les découpes portent un suffixe
            # `_carre` / `_vertical` qu'on ignore.
            if "_" in nom and nom.rsplit("_", 1)[1] in ("carre", "vertical"):
                continue
            ident = nom.split("-", 1)[1] if "-" in nom else nom
            out[ident] = os.path.join(racine, f)
    return out


def _recadrer(im, zoom):
    if zoom <= 1.0:
        return im
    w, h = im.size
    cw, ch = int(w / zoom), int(h / zoom)
    x0, y0 = (w - cw) // 2, (h - ch) // 2
    return im.crop((x0, y0, x0 + cw, y0 + ch)).resize((w, h), Image.LANCZOS)


def _ecart(a, b):
    """Part des pixels dont la luminance diffère de plus de 8/255."""
    la, lb = a.convert("L"), b.convert("L")
    if la.size != lb.size:
        lb = lb.resize(la.size)
    diff = ImageChops.difference(la, lb).point(lambda v: 255 if v > 8 else 0)
    hist = diff.histogram()
    return hist[255] / float(la.size[0] * la.size[1])


def _cote_a_cote(a, b, titre, ecart):
    w, h = a.size
    if b.size != a.size:
        b = b.resize(a.size)
    out = Image.new("RGB", (w * 2 + 8, h + ETIQ_H), (24, 24, 24))
    out.paste(a, (0, ETIQ_H))
    out.paste(b, (w + 8, ETIQ_H))
    d = ImageDraw.Draw(out)
    d.text((6, 4), "AVANT — " + titre, fill=(230, 230, 230))
    d.text((w + 14, 4), "APRÈS — " + titre + "   (%.1f %% de pixels changés)" % (100.0 * ecart),
           fill=(230, 230, 230))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("avant")
    ap.add_argument("apres")
    ap.add_argument("sortie")
    ap.add_argument("--plans", default="")
    ap.add_argument("--zoom", type=float, default=1.0)
    ap.add_argument("--reduction", type=float, default=0.5,
                    help="facteur appliqué aux vignettes de la planche PNG")
    args = ap.parse_args()

    av, ap_ = _lister(args.avant), _lister(args.apres)
    voulus = [p for p in args.plans.split(",") if p] or sorted(set(av) & set(ap_))
    manquants = [p for p in voulus if p not in av or p not in ap_]
    if manquants:
        print("absents d'un des deux côtés : " + ", ".join(manquants), file=sys.stderr)
    voulus = [p for p in voulus if p in av and p in ap_]
    if not voulus:
        print("aucun plan commun", file=sys.stderr)
        return 1

    os.makedirs(args.sortie, exist_ok=True)
    paires = []
    lignes = []
    for ident in voulus:
        a = _recadrer(Image.open(av[ident]).convert("RGB"), args.zoom)
        b = _recadrer(Image.open(ap_[ident]).convert("RGB"), args.zoom)
        e = _ecart(a, b)
        img = _cote_a_cote(a, b, ident, e)
        chemin = os.path.join(args.sortie, "%s.png" % ident)
        img.save(chemin)
        paires.append((ident, img, e))
        lignes.append("%-20s %5.1f %% de pixels changés" % (ident, 100.0 * e))
        print(lignes[-1])

    # La planche PNG : une paire par ligne, réduite.
    r = args.reduction
    vignettes = [(i, im.resize((int(im.width * r), int(im.height * r)), Image.LANCZOS))
                 for i, im, _e in paires]
    largeur = max(v.width for _i, v in vignettes)
    hauteur = sum(v.height + 6 for _i, v in vignettes)
    planche = Image.new("RGB", (largeur, hauteur), (24, 24, 24))
    y = 0
    for _i, v in vignettes:
        planche.paste(v, (0, y))
        y += v.height + 6
    planche.save(os.path.join(args.sortie, "planche.png"))

    with open(os.path.join(args.sortie, "planche.html"), "w", encoding="utf-8") as f:
        f.write("<!doctype html><meta charset='utf-8'><title>Avant / après</title>"
                "<style>body{background:#181818;color:#ddd;font-family:sans-serif;margin:16px}"
                "img{max-width:100%%}h2{margin:24px 0 4px}</style><h1>Avant / après</h1>"
                "<p>zoom %.1f — à gauche l'état d'origine, à droite le lot.</p>" % args.zoom)
        for ident, _im, e in paires:
            f.write("<h2>%s <small>(%.1f %% de pixels changés)</small></h2><img src='%s.png'>"
                    % (ident, 100.0 * e, ident))
    with open(os.path.join(args.sortie, "ecarts.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lignes) + "\n")
    print("→ " + os.path.join(args.sortie, "planche.html"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
