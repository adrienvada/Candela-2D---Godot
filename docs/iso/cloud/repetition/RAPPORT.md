# Répétition du test d'Adrien — session cloud `claude/cloud-repetition`

> **En cours.** Base : `origin/integration-iso14` à `18f5fdc`. Début 2026-09-27 vers 01:10 (Paris).

## Ce que le jeu fait VRAIMENT par défaut sur `18f5fdc` (lu dans le code, puis vu à l'exécution)

| Réglage | Valeur par défaut | Où c'est décidé | Vu à l'exécution |
|---|---|---|---|
| Vue | **isométrique** (tangage 52°) ; la vue de dessus seulement avec `--2d` ou le réglage « VUE DE DESSUS (DÉBOGAGE) » (build de débogage) | `settings_manager.gd:101` (`mode_iso := true`), `iso_applique` l. 323 ; `camera_iso.gd:19` | `[iso] vue isométrique allumée : écran scindé … tangage 52.0°, murs 1.25 tuile, pâte D — lavis et pochoir, lightmap 1080p` |
| Lacet | **45°, option B** : J1 à 45°, J2 à 225° (+180°), en local ET en ligne (imposé en ligne) | `settings_manager.gd:152-153`, `lacet_du_duel` l. 372, `lacet_du_joueur` l. 379 | `mode_rendu=iso lacet 45° B, lacet J1=45 J2=225` |
| Zoom du duel | **×1,5** (en ligne imposé ; en local, sauf zoom enregistré au réglage de débogage) | `settings_manager.gd:129`, `valeurs_du_duel` l. 411 | `zoom=1.50` |
| Décalage du regard vers la visée | **0,15** de la hauteur visible | `settings_manager.gd:132` | `décalage=0.15` |
| Portée des torches | **×0,75** | `settings_manager.gd:141` | — |
| Murs abîmés (usure) | **allumés** ; `--sans-usure` les éteint | `iso_materiaux.gd:165-173` (`usure_active`) | `[usure] allumée — variante USURE_ESSAI posée` |
| Masque de la fumée | **éteint** ; `--fumee-masque` l'allume | `iso_volumes.gd:96`, lecture l. 136-141 | `[fumée masque] éteint (le défaut depuis le 2026-09-26 …)` |
| Beauté (matériaux ISO7) | allumée ; `--sans-beaute` l'éteint | `iso_materiaux.gd:83` | — |
| Bandeau LED des murs | allumé ; `--sans-led-murs` l'éteint ; F7 bascule (build de débogage seulement) | `mur_led.gd:139-151`, l. 375 | — |
| Pâte | **D, lavis et pochoir** | `presentation_3d.gd:179` | `pâte D — lavis et pochoir` |
| Lightmap iso | **1080p** | `settings_manager.gd:185` | `lightmap 1080p` |
| Drapeaux éteints par défaut | `--mannequin`, `--corps=portraits`, `--corps=sombre[2,3]`, `--corps-detaille`, `--corps-grossiers`, `--encre-essai`, `--pochoirs-essai`, `--faisceau`, `--fusee-coeur`, `--fusee-coeur-blanc`, `--fumee-masque`, `--led-murs-fige`, `--teinte=`, `--charte=`, `--pate` | `voxel_catalogue.gd`, `iso_materiaux.gd`, `arena_decor.gd`, `iso_volumes.gd`, `mur_led.gd`, `presentation_3d.gd`, `charte.gd` | — |
| Protocole | `Protocol.VERSION` = 18 | `protocol.gd` | — |

⚠️ **Deux familles de drapeaux, deux façons de les lire** — voir le défaut D1 plus bas.

(Suite du rapport à venir : parcours, relevé de console, défauts classés.)
