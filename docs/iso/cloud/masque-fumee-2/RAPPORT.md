# Le masque de la fumée sous la barre des 3 % — rapport de la session cloud « masque-fumée-2 »

> Branche `claude/cloud-masque-fumee-2`, partie de `origin/claude/cloud-masque-fumee` (`b5af7b6`), 2026-09-28, à partir de
> 02:02 (Paris). **État : en cours — le plan.**

## Le plan (écrit avant de coder)

La série interrompue du 27/09 (13 prises sur 20, sans verdict) place le pochoir (V3) à ≈ 0,963 de M0, juste sous 0,970.
Il faut une ou deux formes de plus, chacune plus économe que le pochoir, pour que la prochaine série ait de la marge.

### 1. Ce qui reste cher dans le pochoir (lu dans le code et le GLSL, avant d'écrire une ligne)

Sous V3, les quatre couches ne portent plus le masque (1 966 instructions, le shader de la fumée d'avant, plus un test de
pochoir fait AVANT leur shader). **Tout le prix restant est dans le JUGE** — un plan par volume, dessiné avant les couches :

1. **Il couvre un CARRÉ** de demi-côté rayon + hauteur, pour contenir les disques des quatre couches vus depuis sa
   hauteur, quelle que soit la caméra. Chaque fragment du carré lance le shader du juge (4 242 instructions, 23 lectures
   statiques : un gros programme, donc beaucoup de registres, donc peu de fragments en vol sur le GPU), paie `juge_couvre`
   (quatre disques) et, hors d'eux, se jette. Un disque inscrit n'occupe que π/4 du carré ; la parallaxe réelle des
   couches (au plus 0,75 × hauteur / tan 52°, ≈ 20 px) est bien moindre que la marge prise (la hauteur entière, 35 px).
   → à compter : combien de fragments du juge sont rastérisés pour rien.
2. **Sur chaque pixel couvert**, la question entière, une fois : le parcours de la grille (2 à 3 lectures de `grille_murs`,
   une boucle), puis, pour le sol (≈ 94 % des fragments) : une lecture de la lightmap, **la pâte du lavis** (deux bruits,
   huit hachages à `sin`, trois `smoothstep`), le contact des corps (une boucle de 2), la certitude « noir sûr » ;
   puis, V2 oblige, **la matière du sol lue** (`textureLod`, un calcul de niveau de mipmap avec deux `length` et un `log2`)
   AVANT la certitude « visible sûr » ; enfin la bande (≈ 3 %), le sol exact.
3. **La face d'un mur** (≈ 6 %) : 11 lectures, la pâte — rare, laissée telle quelle.
4. **Les couches** : leur couleur (neuf lectures de la lightmap lissée, la pâte, la température) est le prix de la fumée
   elle-même, payé aussi par M0 : hors de la tâche. Le pochoir en retire seulement les ~5 % qu'il tait.

Ce qui ne dépend que du pixel est donc DÉJÀ mis en commun par le pochoir (une question par pixel, pas quatre). Ce qu'il
reste à gagner est : (a) les fragments inutiles du juge, (b) le travail par pixel couvert — la pâte et la matière, payées
même là où la lumière brute suffit à trancher.

### 2. Les pistes, jugées

- **V4 — « la lumière brute d'abord »** (candidate) : la pâte du lavis est bornée SANS son bruit. Ses trois seuils
  `e_i = s_i + k_i·b` varient avec le bruit `b ∈ [0, 1]` ; pris à `b = 1` (le plus haut), ils donnent la pâte la plus
  sombre possible, à `b = 0` la plus claire ; le grain est dans [0,82 ; 1]. Deux certitudes sur la lumière lue seule :
  « noir sûr » si la pâte la plus claire possible × 1,4 reste sous le point noir ; « visible sûr » si la plus sombre ×
  le plancher (matière à 1 − force, joint, contact, usure la plus sombre) l'atteint. Ce sont des BORNES des certitudes de
  Gadgets : si l'une tranche, celle de Gadgets aurait tranché pareil ; sinon, on retombe sur le calcul de V3 inchangé.
  Même réponse au pixel, par construction ; plus ni pâte ni lecture de matière là où la lumière est franche.
- **V5 — « le juge ajusté »** (candidate) : le juge rastérise un disque (polygone circonscrit) de rayon + la parallaxe
  réelle bornée, au lieu du carré rayon + hauteur. À juger au compte : si les fragments perdus du juge pèsent peu, V5
  prendra plutôt le parcours de la grille sauté quand aucun mur n'est à portée du juge (un uniforme posé par le
  processeur, exact).
- *Ne masquer que la couche la plus basse et dériver les autres* : déjà fait mieux par le pochoir (une question par pixel).
- *Le masque à résolution réduite* : une passe de plus (une sous-vue) et un rééchantillonnage au bord du noir (fuite
  possible) — rejeté par la session précédente, pour les mêmes raisons.
- *Sortir plus tôt des fragments presque transparents* : à juger. Risque : une fumée « presque transparente » sur un sol
  écrit à 7/255 suffit à franchir le point noir (7 + 1 → 8 → affiché 1) ; sauter la question là serait une fuite.

### 3. La preuve, comme la session précédente

Plan `loupe-fusee-masque-formes` étendu à V4 et V5 : 0 pixel noir allumé par la fumée, écart au masque de Gadgets au pixel
hors de l'ensemble instable, 45° B et 0°, vue unique et écran scindé (J1, J2). Garde headless : éteinte, rien ne change.

### 4. La série du Mac

M0, V3, V4 (et V5), en miroir, avec la porte de l'ordre 432 DANS le lanceur ; essai à blanc dans le cloud.
