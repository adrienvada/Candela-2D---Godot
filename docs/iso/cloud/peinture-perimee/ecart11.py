#!/usr/bin/env python3
"""L'évaluation 11, en petit, avec la bonne peinture — ses chiffres de la Croisée et du Bunker refaits.

    python3 ecart11.py <racine d'un arbre de claude/cloud-ecart-11> <prises APRÈS> [<prises AVANT>]

Les prises sont celles de `tools/photo_ecart.gd` (évaluation 11, tel quel), `--scenes=croisee,bunker`, rangées par
lancement : <dossier>/{defaut,temoin,tout}/<scène>.png. Les mesures sont CELLES de l'évaluation 11 (`mesurer.py` de son
arbre, chargé tel quel : `stats`, `corps_local`, `noir_trois`) ; les anciens chiffres sont lus dans son `mesures.json`.
"""
import importlib.util
import json
import os
import sys

racine, apres = sys.argv[1], sys.argv[2]
avant = sys.argv[3] if len(sys.argv) > 3 else None
spec = importlib.util.spec_from_file_location("mesurer_e11", os.path.join(racine, "docs/iso/cloud/ecart-11/mesurer.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
anciens = json.load(open(os.path.join(racine, "docs/iso/cloud/ecart-11/mesures.json")))


def prise(dossier, lancement, scene):
    chemin = os.path.join(dossier, lancement, scene + ".png")
    return m.lire(chemin) if os.path.exists(chemin) else None


sortie = {}
for carte in ("croisee", "bunker"):
    for lancement in ("defaut", "tout"):
        duel = prise(apres, lancement, f"{carte}_duel")
        sans = prise(apres, lancement, f"{carte}_duel_sans_corps")
        if duel is None:
            continue
        st = m.stats(duel)
        corps = m.corps_local(duel, sans) if sans is not None else None
        ancien_st = anciens["prises"].get(lancement, {}).get(f"{carte}_duel", {})
        ancien_corps = anciens["corps"].get(f"{lancement}/{carte}_duel", {})
        sortie[f"{lancement}/{carte}_duel"] = {"top1": st["top1"], "top1_rgb": st["top1_rgb"], "corps": corps,
                                              "ancien_top1": ancien_st.get("top1"), "ancien_top1_rgb": ancien_st.get("top1_rgb"),
                                              "ancien_corps": ancien_corps}
        print(f"{carte:8s} {lancement:7s} 1 % le plus clair {st['top1']:6.1f} {st['top1_rgb']} (ancien {ancien_st.get('top1')} "
              f"{ancien_st.get('top1_rgb')}) · corps {corps['lum'] if corps else '?'} {corps['rgb'] if corps else ''} "
              f"{corps['pixels'] if corps else ''} px (ancien {ancien_corps.get('lum')} {ancien_corps.get('rgb')} "
              f"{ancien_corps.get('pixels')} px)")
    a, a2, b = (prise(apres, l, f"{carte}_noir") for l in ("defaut", "temoin", "tout"))
    if a is not None and a2 is not None and b is not None:
        n = m.noir_trois(a, a2, b)
        ancien = anciens["noir"].get(f"tout/{carte}_noir", {})
        sortie[f"tout/{carte}_noir"] = {**n, "ancien": ancien}
        print(f"{carte:8s} noir, tout contre défaut et témoin : {n['noir_allume']} allumés (max {n['max_allume']}), bruit "
              f"{n['bruit']} · ancien {ancien.get('noir_allume')} (max {ancien.get('max_allume')}), bruit {ancien.get('bruit')}")
    if avant is not None:
        for lancement in ("defaut", "tout"):
            x, y = prise(apres, lancement, f"{carte}_noir"), prise(avant, lancement, f"{carte}_noir")
            if x is None or y is None:
                continue
            e = m.ecart(x, y)
            sortie[f"peinture_perimee/{lancement}/{carte}_noir"] = e
            print(f"{carte:8s} noir, {lancement} : noirs APRÈS allumés AVANT (même lancement, peinture du Cloître) : "
                  f"{e['noir_allume']} ; pixels changés > 8 : {e['change']}")
json.dump(sortie, open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "ecart11.json"), "w"), indent=1,
          ensure_ascii=False)
