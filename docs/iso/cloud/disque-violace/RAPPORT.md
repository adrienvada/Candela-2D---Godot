# Le disque violacé de l'écran scindé — d'où il vient

Session cloud, branche `claude/cloud-disque-violace`, partie d'`origin/claude/cloud-ecart-11` (2a2c099), le 28/09/2026
(heure de Paris). Lancée par la session coordinatrice « CLOUD ISO UNRAILED ».

**État : en cours — plan posé.**

## Plan

1. **Reproduire** avec la commande du § 5 de l'évaluation 11 (`tools/photo_ecart.tscn --scenes=equite`), regarder la
   première image, mesurer le disque (position écran et monde, rayon, couleur) et s'il bouge d'une image à l'autre dans un
   même lancement (plusieurs prises espacées de quelques images) ou seulement d'un lancement à l'autre.
2. **Isoler le nœud qui le dessine** par élimination, sans rien changer au jeu : un outil de prise (héritier de
   `photo_ecart.gd`) qui, la scène posée et gelée, cache par moitiés les nœuds qui dessinent dans la vue de J1 (voile,
   lumières de J2, halos, particules, sprites, matériaux, présentation 3D) et reprend l'image à chaque fois. Première piste
   (non prouvée) : le voile d'éblouissement texturé.
3. **Expliquer** pourquoi il est chez J1 seul et pourquoi il change de place ; dire si cela tient au rendu llvmpipe et ce
   qu'il faudrait regarder sur le Mac.
4. **Proposer la correction** dans un commit séparé (cueillable sur `origin/integration-iso14`), avec une garde headless
   rouge avant / verte après et les images avant/après à 45° B et à 0°. Rien ne change par défaut sans l'accord d'Adrien.
