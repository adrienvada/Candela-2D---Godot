# Ce qui survit à un changement de carte ou à la fermeture d'un menu

Session cloud, branche `claude/cloud-restes`, partie d'`origin/integration-iso14` (a30a407), le 28/09/2026 à 09:20
(heure de Paris). Lancée par la session coordinatrice « CLOUD ISO UNRAILED ».

**Rapport en cours — plan de travail.**

## Plan

1. **Le sang d'une carte à l'autre** (« Peinture périmée », § 5.1).
   - Lire `blood_stain.gd`, les douilles, les impacts, et tout ce qui se pose au sol pendant un match, et qui les balaie.
   - Reproduire par les gestes du joueur, avec le banc `tools/photo_peinture_perimee.gd` : un vrai tir qui tue,
     l'écran de fin, CHANGER DE CARTE, REJOUER ; vue iso éteinte et allumée, écran scindé ; en ligne par le banc ENet.
   - Mesurer : combien de traces passent, où (dans un mur, sous une lumière), si elles se voient.
   - Proposer : balayer quand la CARTE change, garder à carte égale (revanche). Garde headless rouge avant / verte après.
2. **Les effets de menu qui débordent sur le match** (« Disque violacé », piège 5).
   - Lire en entier `menu_backdrop.gd`, `menu_watcher.gd`, et tout ce que `_set_focus` et l'interface allument.
   - À l'image, prises « écran », torches éteintes, écran scindé et vue unique, avec la correction de la torche du menu
     cueillie (b6f41a9, cd5b300) dans un worktree jetable : pixels allumés qui disparaissent quand on cache l'interface ;
     descente dans l'arbre (`tools/photo_disque.gd`) s'il y en a.
3. Chaque défaut établi : un commit séparé, cueillable à blanc sur `origin/integration-iso14` et
   `origin/claude/cloud-integration-blanc` ; la suite complète verte ; images avant/après ; classement.
