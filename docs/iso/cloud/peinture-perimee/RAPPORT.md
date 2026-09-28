# La peinture iso périmée — arrive-t-elle en vraie partie ? Et la correction

Session cloud, branche `claude/cloud-peinture-perimee`, partie d'`origin/integration-iso14` (a30a407), le 28/09/2026.
Lancée par la session coordinatrice « CLOUD ISO UNRAILED ». Rapport en cours d'écriture.

## Plan (écrit à 08:15, avant tout code)

Le défaut, établi par « Sol marqué (2) » : `presentation_3d.gd` `_process` refait les murs quand `rebuild_arena()` rappelle
le crochet vue allumée (`_reconstruire`), mais pas la peinture (`_poser_peinture`, posée par `_allumer` seulement). Les murs
de la nouvelle carte divisent alors leur lumière par la peinture de l'ancienne.

1. **Les chemins réels**, par le code d'abord (fichier et ligne) : chaque manche, la revanche, l'écran de fin de match (qui
   laisse `_is_main_menu` à faux et montre la carte du salon : peut-on y changer de carte puis REJOUER ?), le client en
   ligne qui adopte la carte de l'hôte (`rpc_start_round` → `_adopt_host_map`, vue déjà allumée ?), l'appariement,
   l'entraînement, l'éditeur de cartes, la killcam. Puis, à carte égale : les copies de la peinture survivent à leurs
   sources libérées — le décor, le sol, l'encre, le sang, les impacts ; que gardent-elles de périmé ?
2. **Reproduire** chaque chemin qui le permet sous Xvfb (un banc qui passe par les gestes du jeu, pas par un raccourci), et
   compter, torches éteintes, les pixels noirs allumés contre la même carte posée directement. Le salon en ligne : deux
   instances ENet locales si c'est faisable, sinon établi par le code. Classement : vraie partie / bancs seulement /
   impossible.
3. **La correction**, dans un commit à part qui ne touche que le correctif, cueillable à blanc sur `origin/integration-iso14`
   et `origin/claude/cloud-integration-blanc` (worktrees jetables) ; une garde headless rouge avant, verte après ; les
   prises avant/après ; le coût compté (travail et rendus au changement de carte). Non appliquée au jeu par défaut sans
   l'accord d'Adrien : elle est proposée sur cette branche.
4. **L'évaluation 11, en petit** : ses scènes `croisee` et `bunker` (`tools/photo_ecart.gd`), lancements `defaut` et `tout`,
   refaites dans un worktree d'`origin/claude/cloud-ecart-11` avec la correction cueillie ; les chiffres justes à côté des
   anciens, dans ce dossier.
5. La suite complète verte, puis ce rapport complet (cinq lignes pour Adrien en tête).
