#!/usr/bin/env python3
"""Pose les TEMPÉRAMENTS des PNJ dans les salles de l'aventure — chantier SOLO, S12 (2026-10-04).

Adrien, sur SOLO-Q11 (« où poser les tempéraments ? ») : « Répartis-les toi-même ». La table ci-dessous dit, salle par salle, quel PNJ
reçoit quel caractère (`ProfilBot.NOMS_TEMPERAMENT`). Le script l'APPLIQUE aux fichiers de `assets/solo/` : il pose la clé « temperament »
sur les PNJ de la table et la retire de tout autre PNJ — la table est la seule vérité, et un second passage ne change rien.

Pourquoi un passage À PART des fabriques (`tools/fabrique_chapitre_NN.gd`) : la répartition est un choix transversal (un caractère par
thème, à travers dix chapitres), qui se relit d'un coup d'œil ici et se perdrait dans dix fichiers. **Une fabrique relancée réécrit ses
salles sans tempérament : relancer ce script après elle.**

Les règles de la répartition :
  • aucun tempérament dans l'initiation (chapitre 0), ni dans les trois premières salles d'un chapitre — elles enseignent sa chose nouvelle ;
  • jamais sur un boss ni sur un PNJ sourd et aveugle (le validateur le refuse) ;
  • un caractère qui sert le thème : des GUETTEURS sur les postes fixes, des EMBUSQUÉS dans le noir, des TRAQUEURS chez ceux qui écoutent
    et chez les chasseurs, des PEUREUX dans les groupes ;
  • au plus deux par salle avant la salle pleine.

Le format est celui des fabriques (`JSON.stringify(données, "  ")`, clés triées) : vérifié identique, octet pour octet, sur les cent salles.

Usage : python3 tools/poser_temperaments.py [--verifier]   (--verifier : n'écrit rien, rend 1 si un fichier diffère de la table)
"""
import json
import os
import sys

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "solo")

# (chapitre, numéro de salle — de 1 —) : { indice du PNJ dans le fichier : tempérament }
TABLE = {
    # Chapitre 1 — Les rondes. Le poste qui regarde passer les rondes devient un guetteur : sa lampe dit où il veille.
    (1, 4): {1: "guetteur"},
    (1, 8): {3: "guetteur"},
    (1, 9): {0: "guetteur"},
    # Chapitre 2 — Les rondes écoutent. Une oreille qui ne lâche pas.
    (2, 8): {3: "traqueur"},
    (2, 9): {3: "traqueur", 4: "embusque"},
    # Chapitre 3 — Les zones. Le noir cache celui qui attend ; le poste avancé éclaire.
    (3, 4): {1: "embusque"},
    (3, 6): {0: "guetteur"},
    (3, 9): {0: "embusque", 4: "guetteur"},
    # Chapitre 4 — Les zones écoutent.
    (4, 6): {2: "traqueur"},
    (4, 7): {3: "guetteur"},
    (4, 9): {1: "traqueur", 2: "embusque"},
    # Chapitre 5 — Les groupes. Celui qui reste seul fuit : séparer un groupe a un prix pour lui.
    (5, 5): {2: "peureux"},
    (5, 8): {2: "guetteur", 4: "peureux"},
    (5, 9): {0: "embusque", 2: "peureux"},
    # Chapitre 6 — Les chasseurs.
    (6, 4): {1: "embusque"},
    (6, 6): {1: "traqueur"},
    (6, 8): {0: "traqueur"},
    (6, 9): {1: "peureux", 3: "traqueur"},
    # Chapitre 7 — Les chasseurs vifs.
    (7, 5): {2: "guetteur"},
    (7, 6): {0: "embusque"},
    (7, 8): {2: "traqueur"},
    (7, 9): {0: "traqueur", 3: "peureux"},
    # Chapitre 8 — Les grandes salles. Des lampes qui veillent sur les places, des embusqués dans les ailes sombres.
    (8, 1): {0: "guetteur", 1: "guetteur"},
    (8, 3): {2: "peureux"},
    (8, 5): {0: "guetteur", 1: "embusque"},
    (8, 7): {3: "traqueur", 4: "embusque"},
    (8, 8): {0: "guetteur", 4: "traqueur"},
    (8, 9): {0: "guetteur", 1: "embusque", 6: "traqueur"},
    # Chapitre 9 — L'élite.
    (9, 5): {1: "embusque"},
    (9, 6): {0: "guetteur"},
    (9, 8): {2: "peureux"},
    (9, 9): {0: "guetteur", 2: "embusque", 4: "traqueur"},
}

NOMS = {"guetteur", "traqueur", "peureux", "embusque"}


def _fichier(chapitre: int, numero: int) -> str:
    dossier = os.path.join(RACINE, "chapitre_%02d" % chapitre)
    manifeste = json.load(open(os.path.join(dossier, "chapitre.json"), encoding="utf-8"))
    return os.path.join(dossier, manifeste["niveaux"][numero - 1])


def _ecrire(chemin: str, donnees: dict) -> str:
    return json.dumps(donnees, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def main() -> int:
    verifier = "--verifier" in sys.argv
    differents = []
    for chapitre in range(0, 10):
        dossier = os.path.join(RACINE, "chapitre_%02d" % chapitre)
        if not os.path.isdir(dossier):
            continue
        manifeste = json.load(open(os.path.join(dossier, "chapitre.json"), encoding="utf-8"))
        for numero in range(1, len(manifeste["niveaux"]) + 1):
            chemin = _fichier(chapitre, numero)
            brut = open(chemin, encoding="utf-8").read()
            niveau = json.loads(brut)
            voulu = TABLE.get((chapitre, numero), {})
            for i, pnj in enumerate(niveau.get("pnj", [])):
                t = voulu.get(i)
                if t is not None:
                    if t not in NOMS:
                        raise SystemExit("tempérament inconnu « %s » (%d.%d, PNJ %d)" % (t, chapitre, numero, i))
                    if pnj["profil"] == "boss" or pnj["profil"].endswith("sourd_aveugle"):
                        raise SystemExit("%d.%d, PNJ %d : un %s n'a pas de tempérament" % (chapitre, numero, i, pnj["profil"]))
                    pnj["temperament"] = t
                else:
                    pnj.pop("temperament", None)
            for i in voulu:
                if i >= len(niveau.get("pnj", [])):
                    raise SystemExit("%d.%d : pas de PNJ %d" % (chapitre, numero, i))
            neuf = _ecrire(chemin, niveau)
            if neuf != brut:
                differents.append("%d.%d" % (chapitre, numero))
                if not verifier:
                    open(chemin, "w", encoding="utf-8").write(neuf)
    if verifier:
        print("salles qui diffèrent de la table : %s" % (", ".join(differents) if differents else "aucune"))
        return 1 if differents else 0
    print("%d salle(s) réécrite(s) : %s" % (len(differents), ", ".join(differents) if differents else "aucune"))
    print("%d tempérament(s) posé(s) dans %d salle(s)" % (sum(len(v) for v in TABLE.values()), len(TABLE)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
