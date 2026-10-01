#!/usr/bin/env python3
"""Q58 À L'IMAGE (Adrien, 2026-10-01 vers 09:10 : « Q58 : il faudrait qu'à l'allumage la fusée illumine loin effectivement »)
— le jugement et les planches de la famille `q58` de `tools/banc_lumieres.gd`.

Pour chaque vue (la vue unique de J1, celle de J2, l'écran scindé) et chaque âge de la fusée posée (0 ; 0,5 ; 1 ; 2 ; 4 s ;
6 s, la braise), trois photos au même cadrage : AVANT (la fusée de la 0.8.0, `--sans-fusee-allumage`), APRÈS (Q58) et le
noir de référence (la lumière de la fusée éteinte). Ce qui se juge :
- LE NOIR, dans la LIGHTMAP de chaque vue (le monde 2D vu de dessus, que la vue iso projette ; lignes « LIGHTMAP » du banc) :
  aucun pixel éclairé par la fusée au-delà du rayon attendu à cet âge (`FuseeModele.rayon_halo_a`), et AUCUN derrière un mur
  haut vu de la fusée (un rayon de la fusée au point, contre les murs) — avant comme après ;
- LA COURBE : à 4 s et à 6 s (l'allumage fini avant la braise), l'après vaut l'avant — la lightmap au pixel près (mêmes
  pixels éclairés, même portée), l'écran à 50 pixels près (un sprite qui respire, un bord crénelé) ; aux âges de
  l'allumage, l'après éclaire plus de pixels que l'avant ;
- J1 = J2 : la vue unique de J1 et celle de J2, au même âge : le même rayon attendu, et la lumière de la fusée ne passe le
  rayon ni chez l'un ni chez l'autre.
Puis une planche par vue : avant, après, sans sa lumière et |après − avant| × 3, âge par âge.

    python3 tools/fusee_q58/planche.py <dossier du banc> <dossier de sortie>

Code de sortie 1 si un pixel éclaire au-delà du rayon ou derrière un mur, si l'allumage déborde dans la braise, ou si une
photo manque.
"""
import os
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

SEUIL = 3  # un pixel « éclairé par la fusée » : la photo dépasse le noir de référence de plus de 3/255
SCENES = [("unique_j1", "la vue unique de J1 (×1,5)"), ("unique_j2", "la vue unique de J2 (×1,5)"),
          ("scinde", "l'écran scindé (×1,25), J1 à gauche, J2 à droite")]
AGES = [0, 500, 1000, 2000, 4000, 6000]


def lire(chemin):
    return np.asarray(Image.open(chemin).convert("RGB")).astype(np.int16)


def police(taille):
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(f):
            return ImageFont.truetype(f, taille)
    return ImageFont.load_default()


def lire_plans(dossier):
    photos, lightmaps = {}, {}
    with open(os.path.join(dossier, "plans.txt")) as f:
        for l in f:
            bouts = l.rstrip("\n").split("\t")
            if bouts[0] == "LIGHTMAP" and len(bouts) >= 3:
                lightmaps.setdefault(bouts[1], []).append(bouts[2])
            elif bouts[0].startswith("q58_") and len(bouts) >= 2:
                photos[bouts[0]] = bouts[1]
    return photos, lightmaps


def lire_lightmap(ligne):
    m = re.match(r"J(\d) : (\d+) px de lightmap éclairés par la fusée \(un sur deux\), le plus loin à (\d+) px "
                 r"\(rayon attendu (\d+)\) ; au-delà (\d+) ; derrière un mur haut (\d+)", ligne)
    if not m:
        return None
    return {"joueur": int(m.group(1)), "eclaires": int(m.group(2)), "plus_loin": int(m.group(3)),
            "rayon": int(m.group(4)), "au_dela": int(m.group(5)), "derriere": int(m.group(6))}


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    dossier, sortie = sys.argv[1], sys.argv[2]
    os.makedirs(sortie, exist_ok=True)
    photos, lightmaps = lire_plans(dossier)
    lignes = ["# Q58 à l'image — la famille `q58` de `tools/banc_lumieres.gd` (dossier « %s »), jugée par "
              "`tools/fusee_q58/planche.py`" % os.path.basename(os.path.normpath(dossier))]
    ok = True
    par_scene = {}
    for scene, titre in SCENES:
        lignes.append("## %s" % titre)
        rangs = []
        for age in AGES:
            base = "q58_%s_%04d" % (scene, age)
            noms = [base + s for s in ["_1avant", "_2apres", "_3noir"]]
            if not all(os.path.exists(os.path.join(dossier, n + ".png")) for n in noms):
                lignes.append("   %.1f s : photos manquantes" % (age / 1000.0))
                ok = False
                continue
            av, ap, noir = [lire(os.path.join(dossier, n + ".png")) for n in noms]
            ecl_av = int(((av - noir).max(axis=2) > SEUIL).sum())
            ecl_ap = int(((ap - noir).max(axis=2) > SEUIL).sum())
            diff = np.abs(ap - av).max(axis=2)
            ecart = int(diff.max())
            n_ecart = int((diff > 1).sum())
            lm = {}
            for cote in ["_1avant", "_2apres"]:
                for l in lightmaps.get(base + cote, []):
                    d = lire_lightmap(l)
                    if d is None:
                        lignes.append("   ✗ %.1f s %s : ligne de lightmap illisible — %s" % (age / 1000.0, cote, l[:120]))
                        ok = False
                        continue
                    lm[(cote, d["joueur"])] = d
                    if d["au_dela"] or d["derriere"]:
                        ok = False
            fini = age >= 4000
            if fini:
                pareils = all(lm.get(("_1avant", j), {}).get("eclaires") == lm.get(("_2apres", j), {}).get("eclaires")
                              and lm.get(("_1avant", j), {}).get("plus_loin") == lm.get(("_2apres", j), {}).get("plus_loin")
                              for j in {jj for (_, jj) in lm})
                if not pareils or n_ecart > 50:
                    ok = False
            if not fini and age < 3000 and ecl_ap <= ecl_av:
                ok = False
            details = " ; ".join(
                "J%d %s : %d px de lightmap, au plus loin %d px (rayon %d), au-delà %d, derrière un mur %d" % (
                    j, "avant" if cote == "_1avant" else "après", d["eclaires"], d["plus_loin"], d["rayon"],
                    d["au_dela"], d["derriere"]) for (cote, j), d in sorted(lm.items(), key=lambda kv: (kv[0][1], kv[0][0])))
            lignes.append("   %.1f s : à l'écran, la fusée éclaire %d px avant, %d après%s ; %s" % (
                age / 1000.0, ecl_av, ecl_ap,
                (" — l'après vaut l'avant (l'allumage est fini) : %d pixel(s) d'écran diffèrent de plus de 1/255, au plus "
                 "de %d" % (n_ecart, ecart)) if fini else "", details))
            par_scene.setdefault(scene, {})[age] = lm
            rangs.append(("%.1f s — avant %d px, après %d px à l'écran%s" % (
                age / 1000.0, ecl_av, ecl_ap, "" if not lm else " ; rayon attendu %d px" % max(
                    d["rayon"] for (c, _), d in lm.items() if c == "_2apres")), av, ap, noir))
        # La planche de la vue.
        if rangs:
            largeur = 480
            f_titre = police(18)
            f_petit = police(14)
            cellules = []
            for titre_rang, av, ap, noir in rangs:
                cells = []
                for im in [av, ap, noir, np.abs(ap - av) * 3]:
                    img = Image.fromarray(np.clip(im, 0, 255).astype(np.uint8))
                    cells.append(img.resize((largeur, int(img.height * largeur / img.width)), Image.LANCZOS))
                cellules.append((titre_rang, cells))
            haut = cellules[0][1][0].height
            toile = Image.new("RGB", (largeur * 4, 56 + len(cellules) * (26 + haut)), (24, 24, 24))
            d = ImageDraw.Draw(toile)
            d.text((8, 4), "Q58 — %s : la fusée posée, âge par âge" % titre, fill=(255, 210, 120), font=f_titre)
            for k, c in enumerate(["AVANT — la 0.8.0 (halo de 440 px)", "APRÈS — Q58 (l'allumage)", "sans sa lumière",
                                   "|après − avant| × 3"]):
                d.text((k * largeur + 8, 30), c, fill=(230, 230, 230), font=f_titre)
            y = 56
            for titre_rang, cells in cellules:
                d.text((8, y + 4), titre_rang, fill=(255, 210, 120), font=f_petit)
                y += 26
                for k, c in enumerate(cells):
                    toile.paste(c, (k * largeur, y))
                y += haut
            chemin = os.path.join(sortie, "planche_q58_%s.jpg" % scene)
            toile.save(chemin, quality=88)
            lignes.append("   planche : planche_q58_%s.jpg" % scene)
    # J1 = J2 : la vue unique de chacun, au même âge.
    lignes.append("## J1 = J2 — la vue unique de J1 et celle de J2, au même âge (lightmap, après)")
    for age in AGES:
        a = par_scene.get("unique_j1", {}).get(age, {}).get(("_2apres", 1))
        b = par_scene.get("unique_j2", {}).get(age, {}).get(("_2apres", 2))
        if a is None or b is None:
            lignes.append("   %.1f s : relevé manquant" % (age / 1000.0))
            ok = False
            continue
        pareil = a["rayon"] == b["rayon"] and a["au_dela"] == 0 and b["au_dela"] == 0
        if not pareil:
            ok = False
        lignes.append("   %.1f s : rayon attendu %d / %d px ; au plus loin %d / %d px ; éclairés %d / %d px de lightmap %s" % (
            age / 1000.0, a["rayon"], b["rayon"], a["plus_loin"], b["plus_loin"], a["eclaires"], b["eclaires"],
            "✓" if pareil else "✗"))
    lignes.append("VERDICT : %s" % ("✓ rien au-delà du rayon ni derrière un mur, l'allumage fini avant la braise, J1 = J2"
                                      if ok else "✗ voir ci-dessus"))
    texte = "\n".join(lignes)
    print(texte)
    with open(os.path.join(sortie, "preuve.txt"), "w") as f:
        f.write(texte + "\n")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
