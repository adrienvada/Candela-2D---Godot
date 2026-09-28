# Le masque de la fumée sous la barre des 3 % — rapport de la session cloud « masque-fumée-2 »

> Branche `claude/cloud-masque-fumee-2`, partie de `origin/claude/cloud-masque-fumee` (`b5af7b6`), 2026-09-28, de 02:02 à
> 03:30 (Paris). **État : fait côté cloud.** Deux formes de plus, chacune plus économe que le pochoir, éteintes par défaut,
> prouvées à l'image (0 fuite ; au pixel près égales au pochoir) ; leurs gardes headless ; la série du Mac avec la porte de
> l'ordre 432 DANS le lanceur, vérifiée à blanc et sur le vrai banc sous Xvfb. Suite complète verte. **Reste le chronomètre,
> qui ne se lit que sur le Mac.** Branche poussée ; pas de pull request.

## Pour Adrien, en cinq lignes

1. Le « pochoir » d'hier (la version la moins chère du masque de la fumée) était juste sous la barre ; j'ai écrit **deux
   versions encore plus économes**, chacune derrière son interrupteur, **éteintes** : le jeu par défaut ne change pas.
2. **V4** évite, sur à peu près 4 pixels de fumée sur 10, le calcul le plus lourd qui restait (la « pâte » du sol et la
   lecture de sa texture) : quand la lumière est franche, elle suffit à répondre, et la réponse est prouvée la même.
3. **V5** ajoute un juge taillé en disque au lieu d'un carré : un sixième de travail en moins pour lui, sans rien changer à
   l'image.
4. À l'image, les deux **ne salissent pas le noir** (0 pixel allumé dans le noir) et donnent **exactement l'image du
   pochoir**, à 45° comme à 0°, pour J1 et — c'est nouveau — **pour J2**, que j'ai posé à l'abri d'un mur pour qu'il voie
   la fumée sans en être ébloui.
5. **Je ne peux pas mesurer la vitesse ici** : la série de ton Mac est prête en une commande (environ 1 h 20, repos compris),
   avec la porte de qualité décidée cette nuit intégrée au lanceur ; elle dira si V4 ou V5 passent la barre.

## Ce qui a été fait, et pourquoi

| étape | fait | où |
|---|---|---|
| 1. lire ce qui reste cher dans le pochoir | écrit avant de coder (commit `d9c1eb5`) : tout le prix restant est dans le JUGE | § 1 |
| 2. compter | un compte du juge à l'image : fragments rastérisés, qui couvrent une couche, qui paient la pâte, qui lisent la matière ; et le GLSL généré | § 2 |
| 3. deux formes | V4 « la lumière d'abord » (`a1fddf5`), V5 « le juge ajusté » (`d9b82a8`), chacune avec sa garde | § 3 |
| 4. la preuve | J1 et J2, vue unique et écran scindé, 45° B et 0° ; la vue unique de J2 prouvée au pixel pour la première fois | § 4 |
| 5. la série du Mac | `tools/masque_fumee/serie_mac_2.sh` : M0, V3, V4, V5 en miroir, la porte de l'ordre 432 dedans | § 5 |

## 1. Ce qui reste cher dans le pochoir (lu dans le code et le GLSL, avant d'écrire une ligne)

Sous V3, les quatre couches ne portent plus le masque (1 966 instructions, le shader de la fumée d'avant, plus un test de
pochoir fait avant leur shader). **Tout le prix restant est dans le JUGE**, un plan par volume dessiné juste avant elles :

1. **Il rastérise un CARRÉ** de demi-côté rayon + hauteur. Chaque fragment du carré lance le programme du juge (≈ 4 200
   instructions, 23 lectures statiques : beaucoup de registres, donc peu de fragments en vol sur le GPU), paie `juge_couvre`
   (quatre disques) puis, hors d'eux, se jette. Un disque n'occupe que π/4 d'un carré, et la marge prise (la hauteur entière,
   35 px) dépasse la parallaxe réelle des couches (au plus 0,75 × 35 / tan 52° ≈ 20 px).
2. **Sur chaque pixel couvert**, la question entière, une fois : le parcours de la grille des murs (2 à 3 lectures, une
   boucle), puis pour le sol (≈ 94 % des pixels) : une lecture de la lightmap, **la pâte du lavis** (deux bruits, huit
   hachages à `sin`, trois `smoothstep`), le contact des corps, la certitude « noir sûr » ; puis, bande resserrée oblige,
   **la matière du sol** (`textureLod` et son niveau de mipmap : deux `length`, un `log2`) avant la certitude « visible
   sûr » ; enfin la bande (≈ 3 %), le sol exact.
3. **Une face de mur** (≈ 6 %) : 11 lectures, la pâte — rare, laissée telle quelle.
4. **La couleur des couches** (neuf lectures de la lightmap lissée, la pâte, la température) est le prix de la fumée
   elle-même, payé aussi par M0 : hors de la tâche.

Ce qui ne dépend que du pixel est déjà mis en commun par le pochoir (une question par pixel au lieu de 3,7). Ce qui restait
à gagner : (a) les fragments du juge qui ne servent à rien ; (b) le travail par pixel couvert là où il ne peut pas changer la
réponse — la pâte et la matière, payées même sous une lumière franche.

## 2. Les comptes (sans chronomètre)

La scène de la preuve (plan `loupe-fusee-masque-formes`, étendu) : Cloître, la fusée seule à 5 s, torches éteintes, caméra
posée, LED figées, fenêtre 1920×1080, rendu logiciel. Fumée de **212 px de rayon** (juge : carré de 495 px de côté ;
disque ajusté de 477 px de diamètre). **Le compte du juge** : les couches coupées, sol et murs peints en noir, le juge écrit
50/255 là où il est rastérisé, là où il couvre une couche, là où il répond « noir » ; et, par différence de deux prises (le
point remplacé par « noir » puis par « visible »), les pixels couverts qui paient la pâte et ceux qui lisent la matière.

| | 45° B | 0° |
|---|---|---|
| fragments de fumée des couches (sur-dessin compris ; le prix de M0, inchangé) | 1 045 943 | 1 098 569 |
| **juge du pochoir (V3, V4) : fragments rastérisés** | **432 287** | **482 786** |
| … qui couvrent une couche et posent la question | 297 721 (68,9 %) | 324 190 (67,1 %) |
| … rastérisés pour rien (hors de tout disque) | 134 566 | 158 596 |
| **juge ajusté (V5) : fragments rastérisés** | **357 326** (−17,3 %) | **384 627** (−20,3 %) |
| … rastérisés pour rien | 59 613 | 60 455 |
| **pixels couverts qui paient la PÂTE du sol : V3** | **272 174** (91,4 %) | **301 232** (92,9 %) |
| … V4 (la lumière d'abord) | **165 923** (55,7 %) : −39 % | **185 082** (57,1 %) : −39 % |
| **pixels couverts qui lisent la MATIÈRE du sol : V3** | **257 417** (86,5 %) | **277 089** (85,5 %) |
| … V4 | **154 611** (51,9 %) : −40 % | **170 794** (52,7 %) : −38 % |
| pixels où le juge écrit « noir » au pochoir : V3 / V4 / V5 | 18 016 / 18 030 / 18 012 | 28 280 / 28 280 / 28 289 |
| … pixels qui diffèrent de V3, hors du corps de J1 | V4 : 0 · V5 : 0 | V4 : 0 · V5 : 0 |

Les écarts du pochoir écrit entre formes (quelques dizaines de pixels) sont tous au pied de J1, dont le corps frémit d'une prise
à l'autre et son contact au sol avec lui ; hors de lui, **V4 et V5 écrivent le pochoir aux mêmes pixels que V3**.

**Le GLSL généré** (Mesa, `MESA_SHADER_CAPTURE_PATH`, compté par `compter_glsl.py`, spirv-opt -O ; même spécialisation) :

| fragment | instructions optimisées | lectures (statiques) | branchements | boucles |
|---|---|---|---|---|
| couches du pochoir (V3, V4, V5) | 1 966 | 17 | 92 | 1 |
| juge V3 | 4 242 | 23 | 190 | 6 |
| juge V4 (et V5) | 4 373 (+3 %) | 23 | 197 | 7 |

Les couches de V4 ont le GLSL de celles de V3 à une ligne près (la constante `BORNE_MARGE`, déclarée, jamais lue). **V5 n'a
fait compiler aucun programme** : Godot a reconnu le code de V4 (MASQUE_AJUSTE n'en ajoute pas), la preuve que son juge est
celui de V4, texte pour texte. Le prix de V4 dans le code : un chemin court de plus, 131 instructions statiques, devant un
chemin long qui n'est plus parcouru que par ~56 % des pixels.

**Où va le gain, en ordre de grandeur (sans chronomètre)** : V4 retire, sur ~40 % des pixels couverts, la pâte (deux bruits,
huit `sin`) et une lecture de texture avec son niveau de mipmap — le gros du travail du juge sur un sol hors bande ; V5 retire
~17 % des fragments du juge, les moins chers (ils se jettent après quatre tests de disque), mais chacun lançait le programme
entier. Ni l'un ni l'autre ne touche les couches, donc le prix de la fumée elle-même.

## 3. Les deux formes

Deux drapeaux de plus dans `IsoVolumes.FORMES_MASQUE`, **éteints par défaut**. Chacune ajoute une idée à la précédente
(V4 = pochoir + MASQUE_LUMIERE ; V5 = V4 + MASQUE_AJUSTE) ; les couches restent celles de V3 ; seul le juge change.

### V4 — « la lumière d'abord » (`--fumee-masque-lumiere`)

Le lavis (`pate()`, style D, celui du jeu) ne dépend du bruit que par ses trois seuils `e_i = s_i + k_i·b` (`b` dans
[0 ; 1[, `k_i` > 0) et par son grain (facteur dans [0,82 ; 1[) ; son lavage `mix(lu, luminance(lu), 0,35) / max(l, 0,25)`
n'en dépend pas — son canal le plus fort vaut (0,65·max(lu) + 0,35·l) / max(l ; 0,25), sa luminance l / max(l ; 0,25). Les
seuils pris à b = 0 donnent donc la pâte la **plus claire possible** (chaque `smoothstep` décroît quand son seuil monte),
grain à 1 ; pris à b = 1, la **plus sombre**, grain à 0,82. D'où deux bornes, sur la lumière lue seule, AVANT la pâte et la
matière :
- **noir à coup sûr** si le canal le plus fort de la pâte la plus claire × 1,4 reste sous le point noir (8/255) : celui de la
  vraie pâte aussi, et la certitude de Gadgets aurait dit « noir » ;
- **visible à coup sûr** si la luminance de la pâte la plus sombre × le plancher de Gadgets (matière à 1 − force, joint et
  contact calculés exactement, usure la plus sombre × 0,45) atteint le point noir : la certitude de la bande resserrée (matière
  exacte ≥ 1 − force, usure lue ≥ usure la plus sombre) aurait dit « visible » — et jamais « noir » avant, les deux
  certitudes s'excluant (luminance ≤ canal le plus fort, plancher ≤ 1).
Sinon, le calcul de V3, inchangé. **Même réponse au pixel, par construction** ; une marge relative de 1e-4 envoie au calcul
d'avant ce qu'un arrondi pourrait faire basculer. Seulement pour le lavis, et sans l'encre d'essai (ses hachures ne se
bornent pas ici). Garde : les lignes du lavis sont celles de la borne, la borne est placée avant la pâte et la matière, et,
**rejouée en 40 000 points sur la pâte du processeur** (`IsoPate`, le miroir formule pour formule, lumières neutres et
rouges saturées, usure allumée ou non, joint et contact), elle ne contredit jamais la certitude exacte.

### V5 — « le juge ajusté » (`--fumee-masque-ajuste`)

Le disque d'une couche de hauteur h, vu depuis le juge (hauteur H), est décalé de (H − h) / tan(tangage), moins que H − h tant
que le tangage dépasse 45° (52° ; gardé). Tout pixel où une couche peut dessiner tient donc dans le disque de rayon
max(r_i + H − h_i) = r + 0,75·H autour du centre. Le juge devient un **polygone de seize côtés circonscrit à ce disque** au
lieu du carré de demi-côté r + H. MASQUE_AJUSTE n'ajoute **aucun code GLSL** : il nomme la variante, pour qu'une prise
prouve son bras par ce que le jeu imprime. Garde : le polygone contient le disque de chaque couche ; il est plus petit que
le carré ; revenu à la forme 4, le juge reprend le carré.

### Les pistes jugées et non suivies

- **Sauter le parcours des murs quand aucun mur n'est à portée du volume** (un uniforme posé par le processeur, la grille
  relue une fois) : écrit, exact, gardé… puis **retiré avant le commit de V5**. Dans la scène de preuve comme dans celle du
  banc du Mac (`[fumée masque] juge ajusté en (303, 578) : un mur à portée`, relevé sous Xvfb), un mur est toujours à portée
  d'une fumée de fusée (212 px de rayon) : il n'aurait été ni vu à l'image, ni mesuré.
- **Sortir plus tôt des fragments presque transparents** : faux. Une fumée qui n'ajoute que 1/255 suffit à faire franchir le
  point noir à un sol écrit à 7/255 (7 + 1 = 8 → affiché 1) : sauter la question là serait une fuite.
- **Ne masquer que la couche la plus basse et dériver les autres** : le pochoir fait déjà mieux (une question par pixel).
- **Le masque à résolution réduite** : une passe de plus (une sous-vue) et un rééchantillonnage au bord du noir (fuite
  possible) — rejeté pour les mêmes raisons que la session précédente.
- **Un juge en deux temps** (un petit programme qui tranche par les bornes et écrit une valeur de pochoir, puis le gros
  programme seulement là où le pochoir est resté à 0) : c'est l'idée qui promettait le plus (le gros programme, et ses
  registres, seulement sur la moitié des pixels), mais son gain repose sur un test de pochoir fait AVANT un shader qui jette
  des fragments et ÉCRIT le pochoir — ce que les pilotes font ou non (sur le GPU d'Apple, derrière OpenGL, je ne sais pas),
  et ni le cloud ni un compte ne le disent. Laissée pour une série qui pourrait la trancher.

## 4. La preuve à l'image

Plan `loupe-fusee-masque-formes`, étendu (C4, C5 ; S-C4, S-C5 en écran scindé ; la vue unique de J2 ; le compte du juge),
jugé par `tools/masque_fumee/formes.py`. Deux lancements : **45° B** et **0°** (`--lacet=0 --lacet-j2=A`), usure au défaut.

| | 45° B | 0° |
|---|---|---|
| **vue unique, J1** (critères de Gadgets, `preuve_masque_fumee.py`) | V4 et V5 PASSENT : 0 fuite ; 1 perte au sol, à une frontière noir/non-noir (la même que Gadgets et V3) ; **0 pixel d'écart au masque de Gadgets hors de l'ensemble instable** | V4 et V5 PASSENT : 0 fuite, 0 perte, 0 écart hors de l'ensemble instable |
| **écran scindé, J1** | 0 fuite ; **0 pixel d'écart au pochoir** ni à Gadgets, hors de la zone du corps de J1 (16 937 pixels exclus, voir plus bas) | 0 fuite ; 0 écart au pochoir, 0 à Gadgets |
| **vue unique, J2** (posé à l'abri d'un mur, éblouissement 0) | 0 fuite : les **6 135** pixels noirs que la fumée sans masque salit, tous tus par V4 et V5 (et par V3, et par Gadgets) ; **0 pixel d'écart au pochoir** ; 1 pixel d'écart à Gadgets, commun aux trois pochoirs (voir plus bas) | **SANS VERDICT** : sa vue est relevée de 1/255 partout (aucun pixel noir) et ses quatre A diffèrent jusqu'à 58/255 |
| écran scindé, J2 (ébloui : 0,105) | aucun pixel noir, voile animé : sans égalité au pixel, comme hier | idem |

- **La zone du corps de J1 en écran scindé.** Aux deux lancements à 45° B, des pixels changent au pied de J1 d'une prise à
  l'autre (rectangle 311-511 × 581-651 de sa moitié), pour TOUTES les formes — le pochoir V3 d'hier y a montré 2 « fuites »,
  V4 0, V5 16 dans le dernier lancement ; V4 13 et V5 0 dans le précédent. Aucune n'est reproductible. En vue unique, la carte
  des murs retire le corps de J1 ; en écran scindé, rien ne le faisait. Sous le pochoir, un pixel vaut A (couches retirées) ou
  B (dessinées), jamais autre chose : là où une prise sous pochoir montre une valeur qui n'est ni A ni B (jusqu'au double de B
  ici), la scène a bougé pendant cette prise. `formes.py` retire ces pixels élargis de 12 px, les compte et le dit.
- **Le pixel (934, 843) de la vue de J2** : un sol éclairé (57/255) où Gadgets tait une partie des couches d'un pixel
  (couture), le pochoir toutes ou aucune ; les trois pochoirs y montrent la fumée, identiques entre eux. Pas une fuite.
- **Éteintes, rien ne change** : garde headless (68 vérifications) — sans drapeau le masque est éteint et la couche garde le
  shader d'avant ; `--fumee-masque` seul, le masque de Gadgets sans aucun #define de forme ; le code gardé pour ces deux cas
  ne contient rien des formes. Et les prises A, B, C d'aujourd'hui passent la preuve de Gadgets comme hier.

**La vue unique de J2, prouvée au pixel pour la première fois.** En écran scindé, J2, proche de la fusée, en est ébloui :
son voile et son flou animés font différer deux prises identiques (session précédente : jusqu'à 226/255). L'éblouissement
de proximité exige une LIGNE DE VUE vers la source (`GameState._plafond_de_source`) ; la caméra iso, elle, voit par-dessus
les murs. Le plan pose donc J2 **à l'abri d'un mur**, à 260-420 px de la fusée, n'y retient qu'une place où son
éblouissement retombe **exactement** à 0, et montre sa vue seule (lacet B : il regarde depuis le côté opposé).

## 5. La série pour le Mac

```bash
mkdir /tmp/candela-mac.lock
./tools/masque_fumee/serie_mac_2.sh /tmp/serie-masque-fumee-2     # SECONDES=60 par défaut, environ 1 h 20
rmdir /tmp/candela-mac.lock
```

Quatre bras — **M0** (aucun drapeau), **V3** `--fumee-masque-pochoir`, **V4** `--fumee-masque-lumiere`, **V5**
`--fumee-masque-ajuste` — chacun prouvé par la ligne `[fumée masque] …` que le jeu imprime ; ordre en miroir
`M0 V3 V4 V5 | V5 V4 V3 M0 | M0 V3 V4 V5 | V5 V4 V3 M0` (position moyenne 8,5 pour chaque bras), plus une chauffe M0.
Chaque prise : `Godot --log-file /tmp/candela-serie-masque-2.log --path . res://tools/bench_framerate.tscn -- --seconds 60
--max-fps 0 --fusee --vue-unique --classe=pompe <drapeau>`.

**La porte de l'ordre 432, dans le lanceur** (ce qu'Iso 1 a dû ajouter à la main au lanceur précédent) :

| règle | comment le lanceur la tient |
|---|---|
| 20 min de repos complet avant la série | `REPOS_INITIAL=1200` : rien n'est lancé ; la charge est relevée et résumée (Claude Helper : médiane, max, premier et dernier tiers, par processus) |
| 90 s sans Godot avant chaque prise | `REPOS_PRISE=90` ; l'attente recommence si un Godot apparaît |
| la porte ne juge que la fenêtre mesurée | un guet date l'apparition de « Mesure sur » (après les 30 s de chauffe du banc) et de « FPS médian » ; seuls les échantillons entre les deux comptent ; le MAXIMUM, pas la moyenne |
| tout étranger > 20 % : prise refusée | `top -l 2` (seconde passe seulement), noms comparés par préfixe ; ne comptent pas : Godot, WindowServer, top, kernel_task (réglable : `EXCLUS`) |
| Claude Helper admis sous 30 %, relevé à chaque prise | tous ses processus sommés échantillon par échantillon ; médiane et max imprimés à chaque prise et dans le verdict ; au-dessus de 30 %, prise refusée |
| une prise refusée se refait à sa place, jusqu'à quatre fois | l'ordre en miroir ne bouge pas ; à la cinquième refusée, série arrêtée sans verdict |
| équilibre des bras à 2 points | la médiane de la charge de Claude Helper de chaque bras à 2 points au plus de celle de M0, sinon SANS VERDICT |

Verdict (règle 278) : **VALIDE** si les quatre M0 tiennent dans 5 % et les bras sont équilibrés ; un bras **PASSE** si sa
médiane des médianes ≥ 0,970 × M0 et son 1 % bas médian (hors 10 s) ≥ 60. Une faute de montage (erreur de shader, ligne
d'état absente, vue ou usure fausses, quelqu'un devant le Mac) arrête la série sans la refaire.

**Vérifié dans le cloud** (la mécanique, pas la cadence) :
- **à blanc** (`ESSAI_A_BLANC=1 FAUX_HELPER=6 FAUX_ETRANGER=4`, ni Godot ni top, charges tirées au hasard) : les seize prises
  et la chauffe ; une dizaine de refus (Claude Helper au-dessus de 30 %, un indexeur au-dessus de 20 %), chacun refait à sa place, jusqu'à
  trois reprises ; le verdict imprimé, dont « SANS VERDICT : la charge de Claude Helper diffère de plus de 2 points entre
  bras » quand le hasard l'a voulu. Et avec `FAUX_HELPER=100` : cinq refus de la même prise, **série arrêtée sans verdict** ;
- **sur le vrai banc sous Xvfb** (`ESSAI_CLOUD=1 ORDRE_COURT="M0 V3 V4 V5" SECONDES=5`, charges simulées) : les quatre bras
  lancent `bench_framerate.tscn --fusee --vue-unique --classe=pompe`, chacun imprime SA ligne d'état (`[fumée masque] éteint`,
  `… forme : pochoir…`, `… lumière d'abord…`, `… juge ajusté…`), `Rendu : iso lacet 45° B`, `[usure] allumée`, aucune erreur
  de shader ni de script (le GPU logiciel compile V4 et V5) ; le guet voit « Mesure sur » puis « FPS médian », la porte juge
  14 à 15 échantillons de cette fenêtre-là ; trois refus simulés, refaits à leur place. Les cadences de cet essai (8 images/s,
  5 s) ne valent rien.
- **Ce que le cloud ne peut pas vérifier** : `top` sous macOS (son format, les noms tronqués de Claude Helper) ; le lanceur
  reprend la lecture de `top -l 2` du lanceur précédent, qui a tourné sur le Mac, et y ajoute l'horodatage de chaque
  échantillon.

## Les images et les relevés

Relevés bruts, dans ce dossier : `preuve_45B.txt` et `preuve_0A.txt` (la sortie entière de `formes.py` sur les deux
lancements), `glsl.txt` (celle de `compter_glsl.py`), `essai_cloud_serie.txt` (l'essai du lanceur sur le vrai banc). La suite
complète : `--- tout passe, sans erreur de script (639s) ---`, sur l'état de ces commits.


`planche.html` (dans ce dossier, autonome, images en chemins relatifs) : pour la fumée sans masque, le masque de Gadgets, le
pochoir, V4 et V5 — la carte du NOIR SALI (rouge : un pixel noir sans fumée qu'elle allume ; gris clair : le sol éclairé),
l'image (gain ×3), l'écart au masque de Gadgets (magenta) ; à 45° B (`45B_*.jpg`) et à 0° (`0A_*.jpg`) ; l'écran scindé ;
et la vue unique de J2 (`*_j2-*`).

## Refaire

```bash
# Godot 4.7 (Linux), Xvfb, Pillow ; une fois : godot --headless --path . --import
# Un user:// neuf joue l'INTRO par-dessus la première prise : lancer une fois pour rien, ou recopier un user:// qui l'a vue.
GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" \
  env GODOT=/usr/local/bin/godot ./tools/run_photos.sh --plan=loupe-fusee-masque-formes --led-murs-fige
# À 0° : ajouter --lacet=0 --lacet-j2=A (deux séances en parallèle : un XDG_DATA_HOME à chacune, recopié d'un user:// qui a vu l'intro)
python3 tools/masque_fumee/formes.py ~/.local/share/godot/app_userdata/Candela\ 2D/photos/loupe
# Le GLSL : vider user://shader_cache, lancer la séance avec MESA_SHADER_CAPTURE_PATH=/tmp/cap, puis
python3 tools/masque_fumee/compter_glsl.py /tmp/cap          # apt-get install glslang-tools spirv-tools
python3 tools/masque_fumee/planche.py docs/iso/cloud/masque-fumee-2 "45° B=<prises à 45° B>" "0° A=<prises à 0°>"
# Les gardes et la suite :
godot --headless --path . --script res://tools/test_masque_formes.gd
GODOT=/usr/local/bin/godot ./tools/run_suites.sh
# Le lanceur du Mac, sans le Mac :
ESSAI_A_BLANC=1 FAUX_HELPER=6 FAUX_ETRANGER=4 ./tools/masque_fumee/serie_mac_2.sh /tmp/essai
ESSAI_CLOUD=1 ORDRE_COURT="M0 V3 V4 V5" SECONDES=5 GODOT=godot xvfb-run -a -s "-screen 0 1920x1080x24" \
  ./tools/masque_fumee/serie_mac_2.sh /tmp/essai-cloud
```

⚠️ Toujours regarder la première image d'une séance : la mienne, au premier lancement, était l'intro (piège connu).

## Ce que je n'ai PAS pu prouver

- **Le temps.** Aucune forme n'est mesurée : rien ici ne dit que V4 ou V5 passent la règle 278. Les comptes disent où est le
  travail retiré, pas combien de millisecondes il valait sur le GPU d'Apple.
- **Que le compilateur d'Apple ne perde pas V4 dans la taille du code** : V4 ajoute au juge un chemin court devant le long ;
  le programme compilé est un peu plus gros (§ 2), et s'il pèse plus en registres, les fragments courts n'en profitent pas
  autant que le compte le dit.
- **V4 dans une scène éclairée par les torches** : la scène de preuve a les torches éteintes (la lumière y est surtout celle,
  rouge, de la fusée, où la luminance est basse) ; au banc du Mac, où les torches sont allumées, la part tranchée par la
  lumière seule devrait être plus grande — non compté.
- **La vue unique de J2 à 0°** : posé à l'abri, éblouissement exactement 0, sa vue est pourtant relevée de 1/255 partout,
  coins hors carte compris, et varie d'une prise à l'autre (jusqu'à 58/255) ; la cause n'est pas trouvée (ce n'est pas
  l'éblouissement). À 45° B, J2 est prouvé ; à 0°, non.
- **L'écran scindé de J2** reste sans égalité au pixel (il y est ébloui, comme hier) ; ce qui vaut pour sa vue est prouvé en
  vue unique.
- **Les gadgets** (suie, poussière, nappes) sous V4 et V5 : même règle, pas photographiés.

## Pièges découverts (à reporter dans la feuille de route)

1. **Sous le pochoir, un pixel vaut A ou B, jamais autre chose** (le juge ne peint rien ; il retire toutes les couches d'un
   pixel, ou aucune). Une valeur qui n'est ni A ni B dit que la SCÈNE a bougé entre les prises (au pied de J1, qui frémit :
   jusqu'au double de B) : c'est un critère exact pour séparer le décor du masque, là où la carte des murs (qui retire le corps
   de J1 en vue unique) n'existe pas — en écran scindé, dans la vue de J2.
2. **« Éblouissement 0,0000 » n'est pas 0** : à quatre décimales, un reste d'éblouissement relevait toute la vue de J2 de
   1/255 (aucun pixel noir, les coins hors carte compris) et vidait le test du noir. Exiger 0 exactement.
3. **La caméra iso voit par-dessus les murs, l'éblouissement non** : un joueur à l'abri d'un mur voit une fusée sans en être
   ébloui. C'est ce qui rend sa vue comparable au pixel d'une prise à l'autre.
4. **`rsync` n'existe pas dans le conteneur du cloud** : une copie d'arbre par `rsync` échouait en silence et la séance
   lancée derrière `&` ne partait pas ; `tar -c | tar -x`.
5. **Deux séances du photographe en parallèle écrivent le même `user://photos`** : donner à la seconde son propre
   `XDG_DATA_HOME`, recopié d'un `user://` qui a déjà vu l'intro.
6. **Un GDScript tapé sur un tableau non typé** (`for r in [260.0, …]`, puis `var q := … * r`) ne se compile pas (« Cannot
   infer the type ») et le photographe entier tombe sans prise : vérifier qu'un outil se CHARGE (un `load()` headless) avant
   de lancer une séance de quarante minutes.
