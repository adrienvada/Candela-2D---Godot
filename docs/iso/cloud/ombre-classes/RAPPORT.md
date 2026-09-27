# L'équité du capteur entre les dix classes — la cause (session cloud ombre-classes, 2026-09-27)

> **État : en cours.** Ce fichier est d'abord le plan ; il sera complété au fil des commits.

## Le plan

1. Lire le code et l'histoire (ci-dessous, écrit AVANT de coder).
2. Un drapeau d'essai `--ombre-ronde[=R]`, éteint par défaut, lu en build de débogage seulement et jamais en ligne, qui
   rend à toutes les classes un occluder rond. Une garde headless : éteint, l'occluder de chaque classe est celui
   d'aujourd'hui, au sommet près.
3. La mesure : un héritier de `tools/planche_q33.gd`, le capteur de J2 pour les dix classes, à la place « bord 0,10 du
   Parasite » et à mi-distance, sans puis avec le drapeau, dans le même processus.
4. Le calcul géométrique : la part de l'anneau lu qui tombe dans l'ombre de son propre occluder, classe par classe.
5. La vue de dessus (`--2d`), si l'outil le permet en moins d'une heure.
6. Les trois voies pour Adrien (garder / le capteur ignore sa propre ombre / occluder rond), sans en choisir une.

## Ce que dit le code (lu le 2026-09-27 sur 84a7352)

- **Où le capteur lit.** `capteur_corps.gd` : une sous-vue 256×256 (128 px de monde) qui partage le `World2D` du duel et
  ne dessine qu'un disque blanc de rayon 18 sous le corps, en « lumière seule », avec le masque de lumière du sprite qu'il
  remplace (`masque_vue_adverse` pour le corps d'en face). Le corps 3D (`corps_iso.gdshader`) lit ce disque sur un
  anneau : `rayon_lu_px = min(RAYON_CORPS_PX + 1, 18 − 3) = 15` (`presentation_3d.gd:1108`, `RAYON_CORPS_PX = 14`),
  `lecture_au_bord = 1` : chaque fragment lit le point de l'anneau de 15 px dans SA direction. La planche Q33 moyenne
  ce même anneau.
- **Où l'ombre du corps tombe sur ce disque.** La torche de J1 porte dans ses ombres la couche d'occluder de J2
  (`player.gd:805`, `flashlight.shadow_item_cull_mask = 1 | 2 | COUCHE_OCCLUDER_ADVERSE`) ; ce masque filtre aussi ce qui
  REÇOIT l'ombre (piège de la ROADMAP, 2026-09-14), et le disque du capteur adverse porte le canal 2 : il la reçoit.
  Dans une Light2D, tout point plus loin de la lampe que le premier bord d'occluder sur son rayon est à l'ombre — y
  compris l'INTÉRIEUR de l'occluder. Le capteur n'est donc éclairé que sur la partie de l'anneau qui est DEVANT le bord
  de l'occluder de son propre corps, vu depuis la torche.
- **Où l'occluder prend la silhouette.** `player.gd:996` appelle `_accorder_occluder_a_la_silhouette(t_sil)` à chaque
  `equip_weapon()` ; la forme vient de `Charte.ombre_de_silhouette()` (`charte.gd:1034`) : une étoile de 32 rayons,
  chacun allant jusqu'au pixel le plus lointain d'alpha > 0,35 de `<arme>_silhouette.png`. Elle dépend donc de la
  largeur du corps de la classe ET de son arme.
- **La forme d'avant.** Avant `aa392a8` (2026-08-26), l'occluder était un cercle de 16 côtés, rayon 18
  (`player.gd`, `_ready`, toujours là comme « cercle PROVISOIRE » écrasé au premier `equip_weapon`), sur la couche 4 —
  que la torche ne portait PAS (`shadow_item_cull_mask = 1 | 2`). **Aucun corps n'ombrait donc la torche avant le
  2026-08-26** : l'occluder rond d'avant n'a jamais été vu sous une torche. Les deux changements (une couche par joueur
  pour que la torche ombre l'adversaire, et l'occluder en silhouette) sont arrivés dans le MÊME commit `aa392a8`, sur le
  verdict d'Adrien : « c'est nul, l'occlusion ne se fait pas selon le sprite ». La forme a déménagé dans `Charte` le
  2026-09-11 (`af237ac`, pour que le leurre fasse le même trou) : c'est cette date que cite la ROADMAP de Beauté, mais
  la décision est du 2026-08-26.
- **Conséquence prévisible, avant toute mesure.** Un cercle de rayon 18 sous la torche contiendrait tout l'anneau lu
  (15 px) : aucun point de l'anneau ne serait devant son bord, le capteur lirait ~0 pour les dix classes — égales, mais
  invisibles. Le drapeau prend donc un rayon : `--ombre-ronde` seul = 12, le disque du torse (`Charte.RAYON_TORSE`,
  déjà l'occluder de la rétrodiffusion), et `--ombre-ronde=18` = le cercle d'avant, mesuré pour le montrer.
- `Protocol.VERSION` = 18 (`protocol.gd:289`) ; il ne bougera pas : le drapeau ne touche que la forme d'un occluder
  visuel, local, jamais en ligne.
