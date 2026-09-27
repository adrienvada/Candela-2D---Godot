#!/usr/bin/env python3
"""Le budget de rendu — la synthèse des journaux de `run_budget.sh` (session cloud, 2026-09-27).

    python3 tools/cloud_budget/synthese.py <dossier_des_journaux> [--reference=<config>] > tableau.md

Lit chaque ligne `BUDGET\t{json}` de chaque `*.log` du dossier et écrit, en Markdown :
  1. le tableau par configuration : appels de dessin, primitives, objets, vues rendues, copies d'écran, lumières à ombre,
     mémoire vidéo — médiane des six cartes (min–max) pour la famille `cartes`, la valeur pour le pompe sous une fusée ;
  2. les écarts de chaque configuration à la référence, carte par carte (la médiane, puis le pire) ;
  3. le détail par vue d'une scène (la racine, les sous-vues 2D et 3D, les capteurs), pour la référence et « tous ».
Chaque nombre d'une scène est la MÉDIANE des images relevées ; leur min et max sont dans le JSON.
"""
import glob
import json
import os
import statistics
import sys

CLES = [
    ("total.appels", "appels"),
    ("total.primitives", "primitives"),
    ("total.objets", "objets"),
    ("passes.vues_rendues", "vues rendues"),
    ("passes.copies_ecran", "copies d'écran"),
    ("lumieres.2d_ombre", "lum. 2D à ombre"),
    ("lumieres.3d", "lum. 3D"),
    ("mem.video_mo", "mém. vidéo (Mo)"),
]


def lire(dossier):
    releves = []
    for chemin in sorted(glob.glob(os.path.join(dossier, "*.log"))):
        with open(chemin, encoding="utf-8", errors="replace") as f:
            for ligne in f:
                if ligne.startswith("BUDGET\t"):
                    d = json.loads(ligne.split("\t", 1)[1])
                    d["_journal"] = os.path.basename(chemin)
                    releves.append(d)
    return releves


def med(d, cle):
    """La valeur d'une scène : la médiane de ses images, sauf au pompe sous une fusée où c'est la MOYENNE — ses appels vont
    du simple au triple d'une image à l'autre ; sur 120 images, la moyenne se reproduit d'un lancement à l'autre à ±1 %,
    la médiane non (18f5fdc contre la branche intégrée drapeaux éteints : 287,1 et 287,9)."""
    v = d["compteurs"].get(cle)
    if v is None:
        return None
    return v.get("moy", v["med"]) if d["famille"] == "pompe" else v["med"]


def fmt(x):
    if x is None:
        return "—"
    if isinstance(x, float) and not x.is_integer():
        return f"{x:.1f}"
    return str(int(x))


def ordre_des_configs(releves, reference):
    vus = []
    for d in releves:
        if d["config"] not in vus:
            vus.append(d["config"])
    if reference in vus:
        vus.remove(reference)
        vus.insert(0, reference)
    if "tous" in vus:
        vus.remove("tous")
        vus.append("tous")
    return vus


def cle_scene(d):
    return (d["famille"], d["scene"], d["vue"], int(round(d["lacet"])))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    reference = "defaut"
    for a in sys.argv[1:]:
        if a.startswith("--reference="):
            reference = a.split("=", 1)[1]
    releves = lire(args[0])
    configs = ordre_des_configs(releves, reference)
    par = {}
    for d in releves:
        par[(d["config"],) + cle_scene(d)] = d
    lacets = sorted({int(round(d["lacet"])) for d in releves})

    print("## Tableau par configuration\n")
    print("Six cartes livrées : médiane des six (min–max) ; chaque carte vaut la médiane de ses 12 images. Pompe sous une fusée"
          " (Arène Standard) : la moyenne de ses 120 images.\n")
    for vue, titre in [("unique", "Vue unique"), ("scinde", "Écran scindé")]:
        for lacet in lacets:
            print(f"### {titre}, lacet {lacet}°\n")
            entete = "| configuration | scène | " + " | ".join(n for _, n in CLES) + " |"
            print(entete)
            print("|" + "---|" * (len(CLES) + 2))
            for c in configs:
                cartes = [d for k, d in par.items() if k[0] == c and k[1] == "carte" and k[3] == vue and k[4] == lacet]
                if cartes:
                    cellules = []
                    for cle, _ in CLES:
                        vals = [med(d, cle) for d in cartes if med(d, cle) is not None]
                        if not vals:
                            cellules.append("—")
                            continue
                        m = statistics.median(vals)
                        cellules.append(f"{fmt(m)} ({fmt(min(vals))}–{fmt(max(vals))})" if min(vals) != max(vals) else fmt(m))
                    print(f"| {c} | 6 cartes | " + " | ".join(cellules) + " |")
                pompes = [d for k, d in par.items() if k[0] == c and k[1] == "pompe" and k[3] == vue and k[4] == lacet]
                for d in pompes:
                    # Le 1 % bas se joue sur les pires images (les salves) : l'appel de dessin moyen, puis son 9e décile et
                    # son maximum.
                    a = d["compteurs"]["total.appels"]
                    cellules = [f"{fmt(med(d, 'total.appels'))} (p90 {a['p90']}, max {a['max']})"]
                    cellules += [fmt(med(d, cle)) for cle, _ in CLES[1:]]
                    print(f"| {c} | pompe + fusée | " + " | ".join(cellules) + " |")
            print()

    print("## Écarts à la référence « %s »\n" % reference)
    print("Carte par carte (même carte, même vue, même lacet), la configuration moins la référence : médiane des six cartes"
          " [pire carte] ; pompe sous une fusée à part.\n")
    for vue, titre in [("unique", "vue unique"), ("scinde", "écran scindé")]:
        print(f"### {titre}\n")
        print("| configuration | lacet | Δ appels, cartes | Δ appels, pompe | Δ primitives, cartes | Δ primitives, pompe | Δ copies d'écran | Δ lum. à ombre | Δ vues rendues |")
        print("|---|---|---|---|---|---|---|---|---|")
        for c in configs:
            if c == reference:
                continue
            for lacet in lacets:
                def deltas(famille, cle):
                    out = []
                    for k, d in par.items():
                        if k[0] != c or k[1] != famille or k[3] != vue or k[4] != lacet:
                            continue
                        r = par.get((reference,) + k[1:])
                        if r is None or med(d, cle) is None or med(r, cle) is None:
                            continue
                        out.append(med(d, cle) - med(r, cle))
                    return out

                def cel(vals):
                    if not vals:
                        return "—"
                    m = statistics.median(vals)
                    pire = max(vals, key=abs)
                    m, pire = round(m, 1), round(pire, 1)
                    return f"{m:+g} [{pire:+g}]" if pire != m else f"{m:+g}"

                print(f"| {c} | {lacet}° | {cel(deltas('carte', 'total.appels'))} | {cel(deltas('pompe', 'total.appels'))} | "
                      f"{cel(deltas('carte', 'total.primitives'))} | {cel(deltas('pompe', 'total.primitives'))} | "
                      f"{cel(deltas('carte', 'passes.copies_ecran') + deltas('pompe', 'passes.copies_ecran'))} | "
                      f"{cel(deltas('carte', 'lumieres.2d_ombre') + deltas('pompe', 'lumieres.2d_ombre'))} | "
                      f"{cel(deltas('carte', 'passes.vues_rendues') + deltas('pompe', 'passes.vues_rendues'))} |")
        print()

    print("## Détail par vue — pompe sous une fusée\n")
    print("Appels de dessin par vue rendue et par passe (visible 3D / ombres 3D / canevas 2D), médiane des images.\n")
    for c in [x for x in (reference, "tous") if x in configs]:
        for vue in ("unique", "scinde"):
            for lacet in lacets:
                ds = [d for k, d in par.items() if k[0] == c and k[1] == "pompe" and k[3] == vue and k[4] == lacet]
                if not ds:
                    continue
                d = ds[0]
                print(f"**{c}, {vue}, {lacet}°** — total {fmt(med(d, 'total.appels'))} ; copies d'écran : "
                      f"{', '.join(d['passes']['copies_ecran']) or 'aucune'}\n")
                print("| vue | taille | visible | ombres | canevas |")
                print("|---|---|---|---|---|")
                for v in d["passes"]["vues"]:
                    if not v.get("rendue"):
                        continue
                    nom = v["vue"]
                    cellules = []
                    for p in ("visible", "ombres", "canevas"):
                        x = d["compteurs"].get(f"vue.{nom}.{p}.appels")
                        cellules.append(fmt(None if x is None else x["med"]))
                    print(f"| {nom} | {v['taille'][0]}×{v['taille'][1]} | " + " | ".join(cellules) + " |")
                print()


if __name__ == "__main__":
    main()
