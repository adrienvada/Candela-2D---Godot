# Les lumières de la 0.8.0 — rapport de la session cloud « Lumières 0.8.0 »

> Branche `claude/lumieres-080`, partie de `claude/unrailed-isometric-feasibility-44klgh` (`2386906`), 2026-09-29.
> Décisions d'Adrien (29/09) : « Je veux augmenter la portée de chaque lumière. Il faudrait que la source de chaque lumière
> soit attachée au modèle 3D de chaque personnage avec un point lumineux là où la source part » ; **Q45** « ça doit au moins
> aller au bout de l'écran de chaque joueur » ; **Q46** le point lumineux visible seulement si la source l'est (« si son
> corps est devant, on ne voit pas le point lumineux »). Trois étapes, dans l'ordre, chacune prouvée avant la suivante.
> **État : L1 faite** (ce commit) ; L2 et L3 suivent sur la même branche.

## Pour Adrien, en cinq lignes

1. **Ta torche va maintenant jusqu'au bord de ton écran**, dans toutes les directions, pour les dix classes, en écran scindé
   comme en vue unique, J1 comme J2. La portée se calcule depuis le cadrage : si le zoom passe à ×1,25 (Q15), elle suit
   toute seule (728 px aujourd'hui, 873 px à ×1,25).
2. **Toutes les classes portent donc aussi loin** (728 px ; elles allaient de 192 à 672) : leur différence tient désormais
   à l'ouverture du cône, à sa luminosité et à sa matière, plus à sa longueur. C'est le choix le plus prudent ; l'autre
   (tout allonger dans la même proportion) est en image plus bas — **question 1**.
3. **L'éblouissement porte aussi loin que la lumière** (il lit le même faisceau) : un Terrassier peut maintenant éblouir
   à 700 px au lieu de 190.
4. **Au bout de l'écran, la lumière est faible** (le faisceau s'éteint en douceur vers sa portée) : au coin, 5 % de sa
   force ; en haut ou en bas de l'écran, un tiers — **question 5**.
5. **Le coût est réel et doit se mesurer sur ton Mac** : sous le rendu logiciel du cloud, une image coûte 1,5 fois plus en
   écran scindé et 1,85 fois plus en vue unique. Le cloud ne dit pas ce que ça fait au 1 % bas de ton Mac.

## L1 — la portée atteint au moins le bord de l'écran

### Ce qui a changé

| fichier | quoi |
|---|---|
| `portee_ecran.gd` (neuf) | `PorteeEcran` : la distance au bord de l'écran dans une direction de visée, et la plus petite portée qui l'atteint partout (le coin). Calcul pur. |
| `weapon_data.gd` | `portee_plancher` (statique) : `portee_torche()` = max(portée de la classe, plancher) ; `echelle_torche()` se DÉRIVE de `portee_torche()` — un seul endroit dit jusqu'où la torche porte. |
| `settings_manager.gd` | `accorder_au_mode` pose le plancher depuis le cadrage qui s'applique ; `portee_ecran_du_duel` (toujours vrai en ligne) ; `--sans-portee-ecran` (débogage, hors ligne) rend le jeu d'avant. |
| `tools/test_portee_ecran.gd` (neuf, dans `run_suites.sh`) | les gardes, § « Preuves » |
| `tools/test_iso_camera.gd` | ses gardes du facteur ISO8 isolées du plancher (plancher à 0 le temps de la garde), et la conséquence du plancher gardée |
| `tools/banc_lumieres.gd` (neuf) | le banc d'images, du recensement et de la cadence |

### La géométrie

La caméra iso garde la profondeur de la vue 2D : au sol, elle montre un rectangle de `D = 1080 / zoom` de profondeur et
`D × sin 52° × largeur / hauteur` de large, dans les axes de l'écran, avancé vers la visée de `0,15 × D`. Dans la direction
`u` de la visée (au sol, axes de la caméra), le bord est à `min(demi-largeur / |u.x|, demi-profondeur / |u.y|) + 0,15 × D` ;
le pire cas est le coin. Le lacet ne change aucune distance : J1 à 45° et J2 à 225° ont le même rectangle, tourné.

| zoom | vue unique : haut / droite / coin | écran scindé : coin |
|---|---|---|
| ×1,5 (aujourd'hui) | 468 / 612 / **728 px** | 546 px |
| ×1,25 (Q15, à l'essai) | 562 / 735 / **873 px** | 656 px |

### Ce que la règle a demandé de choisir — le plus prudent, et les questions

Le plancher retenu est **le coin de la vue unique**, appliqué **à toutes les torches, dans tous les modes**, sans toucher
aux classes qui portaient déjà plus loin (aucune aujourd'hui). Portées d'avant : pistolet 307, fusil 346, Terrassier (pompe)
192, arbalète 672, Fumiste 288, Incendiaire 269, Sentinelle 499, Occulteur 250, Allumeur 230, Spectre 269 — toutes à
**728** au zoom d'aujourd'hui. Les doubles de killcam et la torche fantôme (qui lisent la même échelle) suivent.

![L1 avant/après, vue unique, coin](l1_03_unique_coin.jpg)
![L1 avant/après, écran scindé, coins](l1_01_scinde_coins.jpg)
![L1 avant/après, écran scindé, vers le haut](l1_02_scinde_haut.jpg)
![L1 avant/après, vue unique, Sentinelle vers la droite](l1_04_unique_droite.jpg)
![L1 avant/après, vue unique, vers la caméra](l1_05_unique_bas.jpg)

**Les options non retenues, en image :**

![Option B](l1_options_b.jpg)
![Par mode](l1_options_par_mode.jpg)

### Les gardes et les mesures

- **`tools/test_portee_ecran.gd`** (39 vérifications) : la formule (le coin couvre les 720 directions ; la vue unique couvre
  l'écran scindé ; la portée suit le zoom dans le rapport des zooms) ; la règle (allumée par défaut, toujours en ligne,
  `--sans-portee-ecran` en débogage seulement, plancher dérivé des constantes du duel en ligne) ; les dix classes (portée =
  max(propre, plancher), et le cookie l'étale jusque-là) ; **EN JEU, sur les vraies caméras iso** : écran scindé à 45° B (J1
  et J2), ×1,5 puis ×1,25, et vue unique, huit visées × dix classes — la lumière posée (`texture_scale` × cookie) va au
  moins jusqu'au point du sol où la visée sort de l'écran (marge la plus courte : 213 px en scindé, 49 px en vue unique), et
  la formule dit cette distance **à 0,00 px** près.
- **Le piège trouvé en route** : la première garde donnait à la formule la direction de visée lue À L'ÉCRAN, raccourcie en
  profondeur de sin 52°, et la croyait fausse de 26 px (consigné aux « Pièges connus »).
- **Quinze lumières par item** (`--plans=quinze` : écran scindé, deux torches, une fusée posée plein feu, un tir) : 10
  lumières actives avant comme après ; **au plus 10 par quadrant de 560 px avant comme après** — la carte n'a que quatre
  quadrants et tout s'y recouvrait déjà ; les quadrants éloignés passent de 1 à 3 lumières (les deux torches y entrent).
  Une torche de 728 px a un rectangle de 1 455 px : elle touche jusqu'à 3 × 3 quadrants au lieu d'un ou deux. **Sur une
  grande carte, chaque torche ajoute donc une lumière à des quadrants qu'elle ne touchait pas** : +2 (les deux torches), +3
  avec une torche fantôme. Le plafond de 15 reste loin dans les scènes mesurées ; une gerbe d'étincelles d'impact (12
  lumières) près d'une fusée, loin des joueurs, est le cas à surveiller (« Pièges connus », 2026-09-10).
- **La cadence, relative, sous Mesa** (Xvfb, rendu logiciel llvmpipe ; `--plans=cadence` : deux torches allumées, joueurs
  face à face en diagonale, médiane de 90 images, trois séries alternées) :

  | | avant | après L1 | rapport |
  |---|---|---|---|
  | écran scindé | 448 / 433 / 459 ms | 661 / 669 / 675 ms | **× 1,50** |
  | vue unique | 342 / 318 / 334 ms | 609 / 603 / 626 ms | **× 1,85** |

  Sous rendu logiciel, le coût suit la surface éclairée et dessinée ; ces rapports ne disent rien du 1 % bas du Mac, ils
  disent que **le changement n'est pas gratuit**. **À mesurer sur le Mac** (`bench_framerate`, série courte, la cible est
  « 1 % bas ≥ 60 » et le jeu la passait de deux images par seconde). La répartition (faisceau visible de Q41, lumières 3D
  miroir) suit, au § « Coût ».

## Questions pour Adrien

1. **Plancher ou facteur ?** Retenu : le plancher — toutes les torches vont au moins au bord (728 px), aucune ne va plus
   loin : **l'écart de portée entre les classes disparaît**. L'autre voie : tout allonger dans la même proportion (×2,84)
   pour que la plus courte (le Terrassier) atteigne le bord — l'écart est gardé, mais l'arbalète porte à 2 547 px (plus de
   trois écrans) et chaque torche coûte bien plus (image « Option B »).
2. **Une portée pour tous les modes, ou une par mode ?** Retenu : une seule, celle de la vue unique (728 px), aussi en écran
   scindé, où l'écran est plus étroit (546 px suffiraient). Une portée par mode ferait jouer l'écran scindé autrement que
   le jeu en ligne — la portée est une règle (l'éblouissement la lit), pas un cadrage.
3. **La torche seule, ou toutes les lumières ?** Retenu : la torche (et ce qui la copie : killcam, torche fantôme). Les
   autres gardent leur taille : la fusée posée (halo de 220 px de rayon), le flash de tir (32 px), le halo de
   rétrodiffusion (128 px). « Aller au bout de l'écran » n'a pas de direction pour une lumière ronde posée au sol : faut-il
   que le halo d'une fusée remplisse l'écran ?
4. **Près d'un bord de carte**, la caméra s'arrête et le joueur peut viser un bord d'écran plus lointain (jusqu'à toute la
   largeur, ~940 px) : la règle ne le couvre pas. Le couvrir demanderait la diagonale entière de l'écran (~1 240 px).
5. **Jusqu'où « aller au bout » ?** Le faisceau s'éteint en douceur vers sa portée : au coin de l'écran il ne verse plus
   que 5 % de sa force, un tiers en haut ou en bas. Si « au bout » veut dire « bien visible au bord », il faut une portée
   plus longue encore ou un cookie qui garde sa force plus loin.
6. **Le coût** : à mesurer sur le Mac avant de publier.
