# Le budget de rendu de ce qui arrive — rapport de la session cloud « budget »

> Branche `claude/cloud-budget`, partie de `origin/integration-iso14` (`18f5fdc`). Ouvert le 2026-09-27 à 01:10 (Paris).
> **État : plan posé, travail en cours.** Ce fichier sera complété au fil des commits.

## Le plan

Le cloud ne mesure pas la cadence (rendu llvmpipe). Il **compte** : appels de dessin, primitives, objets, mémoire
vidéo, par vue, plus les passes (sous-vues actives, copies d'écran). Le but est de dire d'avance quelle nouveauté
risque de faire tomber le 1 % bas sous 60 et dans quel ordre la mesurer sur le Mac.

1. **Outillage** : Godot 4.7 officiel, Xvfb, corrections du photographe (`0c67705`) appliquées en commit à part.
2. **Instrument** `tools/cloud_budget/` (nouveaux fichiers seulement) : hérite du photographe, joue une manche
   figée, relève par vue (`RenderingServer.viewport_get_render_info` sur chaque sous-vue et la racine) et au total,
   sur N images, et compte les passes (sous-vues dont la mise à jour est active, objets visibles dont le shader
   déclare `hint_screen_texture`).
3. **Validation de l'instrument** sur deux chiffres connus : les tuyaux (28 → 29 appels en vue unique, 50 → 52 en
   écran scindé, sur `70ffafa`) et Beauté (le détail des corps : 44 appels sur 93).
4. **Fusions dans cette branche** : `origin/iso12-corps` (`f38e5f7`), `origin/iso11-menus` (`3155395`),
   `origin/claude/cloud-tuyaux` (`70ffafa`). Conflits : les deux côtés gardés, décrits ici.
5. **Matrice** : 18f5fdc tel quel ; chaque ajout seul ; tous ensemble — × vue unique / écran scindé × 0° / 45°
   × six cartes livrées ; plus le cas lourd connu (fusil à pompe sous une fusée).
6. **Rapport** : tableau par configuration, trois plus gros contributeurs, liste ordonnée des mesures à faire
   d'abord sur le Mac, ce qui n'a pas pu être prouvé, commandes pour tout refaire.
