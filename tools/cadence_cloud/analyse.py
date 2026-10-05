#!/usr/bin/env python3
"""Lit le journal d'une prise du banc de cadence (lancée avec `--seuil-lent 1`, donc CHAQUE image datée) et rend le temps
d'image médian et le 1 % bas au sens du banc (hors des dix premières secondes de mesure), plus les contrôles qui décident si
la prise vaut : classe équipée, torches tenues, focus stable, erreurs de script ou de shader, porte stricte.

Une prise de SOLO (`--solo=<chapitre>.<salle>`, OM6 : `SCENE="--solo=8.9" prise.sh …`) se reconnaît à sa ligne « Solo : salle … » et
se juge autrement : pas de classe du pompe à tenir, mais la SALLE tenue en jeu sur toute la mesure (J1 vivant, aucune reprise), une
FUSILLADE (au moins un coup de PNJ pendant la mesure : sans elle la prise mesure une salle au repos, pas le pire cas annoncé), et aucun
« ✗ » dans le rapport — ni celui des interrupteurs de lumière (`--sans-ombres-2d`, `--sans-capteurs`, `--sans-halos-pnj`), qui disent
ce qu'ils ont vérifié à la fin. Le libellé de la charge (l'en-tête du RÉSULTAT) porte les drapeaux posés : ils sont rendus dans la ligne.

Usage : analyse.py <journal.log> [<journal.log> …]   — une ligne par prise, et `--json` pour la sortie machine.
"""
import json
import math
import os
import re
import statistics
import sys

RE_LENTE = re.compile(r"^\s*lente ([0-9.]+) ms à ([0-9.]+) s")


def analyser(chemin):
    texte = open(chemin, encoding="utf-8", errors="replace").read()
    lignes = texte.splitlines()
    dts, ts = [], []
    for l in lignes:
        m = RE_LENTE.match(l)
        if m:
            dts.append(float(m.group(1)))
            ts.append(float(m.group(2)))
    r = {"journal": os.path.basename(chemin), "images": len(dts)}
    refus = []
    if not dts:
        refus.append("aucune image datée")
    else:
        dts_tri = sorted(dts)
        r["mediane_ms"] = statistics.median(dts)
        r["moyenne_ms"] = sum(dts) / len(dts)
        regime = sorted(d for d, t in zip(dts, ts) if t >= 10.0)
        if regime:
            lents = max(1, int(round(len(regime) * 0.01)))
            pire = regime[-lents:]
            r["un_pc_bas_ms"] = sum(pire) / lents
            r["un_pc_bas_n"] = lents
            r["p95_ms"] = regime[min(len(regime) - 1, int(math.ceil(0.95 * len(regime))) - 1)]
        r["pire_ms"] = dts_tri[-1]
    # Le banc imprime aussi ses propres chiffres : ils doivent dire la même chose (contrôle de lecture).
    m = re.search(r"FPS médian\s*:\s*([0-9]+)", texte)
    r["fps_median_banc"] = int(m.group(1)) if m else None
    m = re.search(r"Images mesurées\s*:\s*([0-9]+) en ([0-9.]+) s", texte)
    if m:
        r["images_banc"] = int(m.group(1))
        if dts and int(m.group(1)) != len(dts):
            refus.append("images datées %d ≠ images du banc %s" % (len(dts), m.group(1)))
    else:
        refus.append("pas de RÉSULTAT")
    solo = re.search(r"^Solo\s+:\s+salle (\d+\.\d+)", texte, re.M)
    r["solo"] = solo.group(1) if solo else None
    if r["solo"] is None:
        m = re.search(r"Manche lancée — armes : (.*?) \(slugs (\w+) / (\w+)", texte)
        if not m or m.group(2) != "pompe" or m.group(3) != "pompe":
            refus.append("classe non tenue")
    else:
        # Le solo ne joue pas de manche : sa salle, sa fusillade, et ce que le banc a refusé lui-même.
        if not re.search(r"^\s+Salle\s+:\s+\S+ .* tenue en jeu sur toute la mesure", texte, re.M):
            refus.append("salle non tenue")
        m = re.search(r"Fusillade\s*:\s*(\d+) coups de PNJ pendant la mesure", texte)
        r["coups"] = int(m.group(1)) if m else 0
        if r["coups"] == 0:
            refus.append("aucune fusillade (aucun coup de PNJ pendant la mesure)")
        m = re.search(r"J1\s+: poste tenu .*?touché sur (\d+) pas de physique, (\d+) PV perdus", texte)
        r["pv_perdus"] = int(m.group(2)) if m else None
        for l in lignes:
            if re.match(r"^\s+✗ (SALLE|VUE ISO)", l):
                refus.append(l.strip()[:90])
    # Un interrupteur de lumière qui n'a pas tenu (duel comme solo) : « ✗ » sur sa ligne de fin.
    for l in lignes:
        if re.match(r"^\s+Interrupteurs\s+:.*✗", l):
            refus.append("interrupteur non tenu : " + l.split("✗", 1)[1].strip()[:80])
    m = re.search(r"=== RÉSULTAT \((.*)\) ===", texte)
    r["charge"] = m.group(1) if m else "?"
    m = re.search(r"\[((?:sans [^\],]+(?:, )?)+)\]", r["charge"])
    r["interrupteurs"] = m.group(1) if m else ""
    if "Torches          : allumées sur toute la mesure" not in texte:
        refus.append("torches non tenues")
    if "Focus            : stable au premier plan" not in texte:
        refus.append("focus non stable")
    for motif in ("SCRIPT ERROR", "SHADER ERROR", "Parse Error"):
        if motif in texte:
            refus.append(motif)
    m = re.search(r"J1 : zoom ×([0-9.]+)", texte)
    r["zoom"] = m.group(1) if m else "?"
    m = re.search(r"Rendu : ([^·\n]*)", texte)
    r["rendu"] = m.group(1).strip() if m else "?"
    r["faisceau_air"] = "allumé" if "[faisceau air] allumé" in texte else ("éteint" if "[faisceau air] éteint" in texte else "?")
    m = re.search(r"Son visible\s*:\s*(.*)", texte)
    r["son_visible"] = m.group(1).strip() if m else "?"
    m = re.search(r"Fenêtre\s*:\s*(\S+)", texte)
    r["fenetre"] = m.group(1) if m else "?"
    m = re.search(r"\[prise\] code (\d+) ; durée (\d+) s", texte)
    r["code"] = int(m.group(1)) if m else None
    if r["code"] not in (0, None):
        refus.append("code %s" % r["code"])
    porte = chemin[:-4] + ".porte.json" if chemin.endswith(".log") else chemin + ".porte.json"
    if os.path.exists(porte):
        p = json.load(open(porte))
        r["intrus"] = p["intrus"]
        r["charge_max"] = p.get("charge_max_1min")
        if p["intrus"]:
            noms = sorted({"%s %.0f %%" % (i["comm"], i["cpu"]) for i in p["intrus"]})
            refus.append("porte : " + ", ".join(noms[:4]))
        # Un Xvfb vu seulement à la dernière image est le NÔTRE, rattaché à init quand `xvfb-run` sort avant lui (porte d'avant
        # le 2026-09-30 15:30, qui ne gardait pas la mémoire de ses descendants) : pas un autre Godot.
        fin = p.get("fin", os.path.getmtime(porte))
        etrangers = [g for g in p.get("godots_etrangers", []) if not (g["comm"] == "Xvfb" and g["t"] >= fin - 2.5)]
        if etrangers:
            refus.append("un autre Godot a tourné pendant la prise : " + ", ".join(
                "%s (pid %d)" % (g["comm"], g["pid"]) for g in etrangers[:4]))
    else:
        refus.append("pas de porte")
    r["refus"] = refus
    r["valide"] = not refus
    return r


def ligne(r):
    if "mediane_ms" not in r:
        return "%-28s REFUSÉE (%s)" % (r["journal"], "; ".join(r["refus"]))
    # Ce qui distingue une prise d'une autre dans une série : la salle de solo et les interrupteurs posés (OM6).
    scene = ""
    if r.get("solo"):
        scene = " · solo %s%s · %d coups de PNJ" % (r["solo"], (" [" + r["interrupteurs"] + "]") if r.get("interrupteurs") else "", r.get("coups", 0))
    elif r.get("interrupteurs"):
        scene = " · [%s]" % r["interrupteurs"]
    return "%-28s %s médiane %.1f ms (%.2f i/s) · moyenne %.1f ms · 1 %% bas %.1f ms (%.2f i/s, %d img) · p95 %.1f · %d images · zoom ×%s · faisceau %s%s%s" % (
        r["journal"], "✓" if r["valide"] else "✗", r["mediane_ms"], 1000.0 / r["mediane_ms"], r["moyenne_ms"], r.get("un_pc_bas_ms", 0.0),
        1000.0 / r.get("un_pc_bas_ms", 1e9), r.get("un_pc_bas_n", 0), r.get("p95_ms", 0.0), r["images"], r["zoom"],
        r["faisceau_air"], scene, "" if r["valide"] else "  REFUS : " + "; ".join(r["refus"]))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--json"]
    res = [analyser(a) for a in args]
    if "--json" in sys.argv:
        print(json.dumps(res, ensure_ascii=False, indent=1))
    else:
        for r in res:
            print(ligne(r))
