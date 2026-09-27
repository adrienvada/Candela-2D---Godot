# Un masque de la fumée qui ne coûte pas 2,4 ms — rapport de la session cloud « masque-fumée »

> Branche `claude/cloud-masque-fumee`, partie de `origin/integration-iso14` (`60e5c6d`), 2026-09-27, à partir de 06:08
> (Paris). **État : fait côté cloud.** Trois formes moins chères du masque, éteintes par défaut, prouvées à l'image
> (0 fuite, et hors du corps de J1 qui frémit, 0 pixel d'écart au masque de Gadgets) ; la cause du prix établie par des
> comptes ; la série pour le Mac prête. **Reste le chronomètre, qui ne se lit que sur le Mac.**

## Pour Adrien, en cinq lignes

1. **J'ai trouvé pourquoi le masque de la fumée coûte si cher depuis les murs abîmés** : pour 4 pixels de fumée sur 10, il
   refait tout le calcul du sol (usure comprise) pour savoir s'il est noir, parce que son raccourci était trop prudent.
   Sans les murs abîmés, c'était 1 sur 10.
2. J'ai écrit **trois versions moins chères** du même masque, chacune derrière son propre interrupteur, **éteintes** : le
   jeu par défaut ne change pas d'un octet (vérifié dans le code que la carte graphique reçoit).
3. **Les trois donnent la même image que le masque d'aujourd'hui** (0 pixel de différence hors du joueur qui respire) et
   **ne salissent pas le noir** : 0 pixel allumé dans le noir, pour J1 comme pour J2, en vue unique et en écran scindé.
4. La plus prometteuse, le **« pochoir »**, pose la question une fois par pixel au lieu de près de quatre (une par couche
   de fumée), et ne refait le calcul du sol que pour 3 % des pixels au lieu de 41 % : sur le papier, beaucoup moins de
   travail — mais seul ton Mac dira combien de millisecondes.
5. **Je ne peux pas mesurer la vitesse ici** : une série de vingt-cinq minutes sur ton Mac est prête, en une commande ;
   elle dira laquelle passe sous la barre des 3 %.

## Ce qui a été fait, et pourquoi

| étape | fait | où |
|---|---|---|
| 1. lire le masque et son histoire | ce qu'il calcule, pour quels pixels, avec quelles textures et boucles (ci-dessous, écrit avant de coder) | § 1 |
| 2. compter sans chronomètre | appels et passes (outil Budget), fragments de fumée et sur-dessin (une prise qui les compte), fragments qui paient le calcul exact (deux prises qui les isolent), taille du GLSL généré | § 2 |
| 3. variantes | compacte, bande resserrée, pochoir — trois drapeaux, éteints, chacun ajoute une idée à la précédente | § 3 |
| 4. série pour le Mac | `tools/masque_fumee/serie_mac.sh`, cinq bras, quatre blocs en miroir | § 4 |

## 1. Ce que le masque calcule (lu dans le code avant d'en écrire une ligne)

Fichiers : `volume_iso.gdshader` (la couche), `volume_masque.gdshaderinc` (le masque), `iso_usure.gdshaderinc` (l'usure,
recopiée sous `USURE_ESSAI`), `iso_volumes.gd` (qui pose la variante et recopie à chaque image le contact des corps et les
impacts de l'usure). Histoire : `b8c1b49` (Gadgets, V1f, le 25/09), `b126c38` (la preuve dans le dépôt), `ef758bd` (Iso 1,
la bande des faces, le 27/09).

**Pour quels pixels.** Une fusée posée, ce sont **quatre couches** horizontales (`VOLUME_FUSEE` : hauteur 1 tuile, 4
couches), des disques de rayon `rayon_fumee` × (1 − 0,22 f), chacune dessinée en transparence. Un fragment de couche paie
d'abord l'opacité (le disque, un bruit de 4 hachages) ; hors du disque ou sous 0,003 d'opacité, il est jeté. **Le masque
tourne sur chaque fragment qui a survécu, de chaque couche** — un pixel sous les quatre couches le paie quatre fois — puis,
s'il n'a pas jeté le fragment, la couleur de la couche (neuf lectures de la lightmap lissée, la pâte, la température).

**Ce qu'il calcule, par fragment** (`masque_montre_noir`) :
1. le rayon de vue (caméra orthographique) prolongé de la couche jusqu'au sol, qui traverse **la grille des murs case par
   case** : une boucle de 4 tours au plus, une lecture de `grille_murs` par tour (1 à 2 tours en pratique : une couche
   monte au plus à une tuile), plus une lecture pour la case d'arrivée ;
2. la surface rencontrée d'abord, jugée **comme son propre shader l'écrit** :
   - **le sol** (`sol_montre_noir`) : une lecture de la lightmap, la pâte du lavis (deux bruits = 8 hachages avec `sin`),
     le contact des corps (une boucle de 2), puis deux certitudes (noir sûr ; visible sûr) ; entre les deux (la **bande**),
     le sol exact `sol_ecrit` (une lecture de lightmap de plus, la matière en `textureLod`, la pâte encore, la température,
     l'usure du sol exacte avec une lecture de `usure_proximite`, trois `pate_facteur` à six `pow` chacun). Et **aux
     coutures** (à moins de 0,008 px d'un joint de tuile, d'une marge ou d'une cellule d'usure), le tout **quatre fois** ;
   - **une face de mur** (`face_montre_noir`) : **11 lectures de texture** (2 étalons de peinture, 4 × lightmap + peinture
     à son pied, la matière de la face), la pâte, la température ; avec l'usure, deux certitudes et, dans la bande
     seulement, `usure_face` (5 bruits, la fissure de travée, une boucle de jusqu'à **48 impacts** avec `atan` et `pow`) ;
   - **le dessus d'un mur** : noir strict (mur haut) ou une lecture de lightmap et la pâte (muret).

**Textures lues par le masque** : `grille_murs`, `lumiere_1|2` (la lightmap), `peinture`, `texture_face`,
`sol_texture_sol`, `usure_proximite` — six échantillonneurs de plus que la couche sans masque (`masque`, `lumiere_1|2`).

**Ce qu'il fait de plus que la fumée sans lui** : à l'exécution, par fragment survivant, 2 à 3 lectures de la grille, puis
1 lecture et une pâte (sol hors bande et hors couture) ou 11 lectures et une pâte (face) ; plus le sol exact dans la bande.
Et dans le **code**, beaucoup plus : un compilateur GLSL recopie une fonction à chaque appel, et le masque appelle
`sol_montre_noir_au_point` **cinq** fois, `face_montre_noir` **trois** fois, `dessus_montre_noir` deux.

**Ce que la bande d'Iso 1 a changé, et pourquoi elle ne pouvait pas rendre grand-chose** : elle retire l'usure exacte des
faces hors de leur bande — du travail qui ne s'exécute que sur les pixels de fumée devant une face (6 % des fragments, § 2).
Elle n'a touché ni au nombre de fragments masqués, ni à la bande du SOL, ni à la taille du code.

## 2. Les comptes (sans chronomètre)

Tout se compte sur la scène de la preuve de Gadgets (`loupe-fusee-masque-preuve`, reprise à l'identique par le plan
`loupe-fusee-masque-formes`) : Cloître, la fusée seule à 5 s, torches éteintes, caméra posée, LED figées à leur sommet,
**lacet 45° B**, usure au défaut, fenêtre 1920×1080, rendu logiciel (llvmpipe). Ce n'est pas le pompe du banc de cadence :
c'est la même fumée (quatre couches, même rayon), sans les tirs.

### 2a. Appels de dessin, passes, copies d'écran, sous-vues (outil de la session Budget)

L'outil de la session Budget (`origin/claude/cloud-budget`, `tools/cloud_budget/`, repris le temps du relevé et non
commité ici), sa scène du **pompe sous une fusée** (Arène Standard, 120 images, la moyenne), lacet 45° B :

| configuration | appels, vue unique | appels, écran scindé | vues rendues | copies d'écran | lumières 2D à ombre |
|---|---|---|---|---|---|
| M0, masque éteint | 290,2 | 620,6 | 5 / 11 | 2 / 4 | 10,9 / 8,4 |
| M1, `--fumee-masque` | 290,1 | 618,2 | 5 / 11 | 2 / 4 | 10,9 / 8,4 |
| V3, `--fumee-masque-pochoir` | 291,0 | 623,8 | 5 / 11 | 2 / 4 | 10,9 / 8,4 |

Au bruit près (± 2 appels en vue unique, ± 8 en écran scindé, mesuré par la session Budget), **le masque n'ajoute rien que
ces compteurs voient** (comme la session Budget l'avait trouvé), et le pochoir **un appel par volume et par vue** (le juge),
rien d'autre : ni vue, ni copie d'écran, ni ombre. Le prix du masque est donc **par pixel** — ce que comptent les § 2b et 2c.

### 2b. Les fragments de fumée, et ce que le masque en fait

Une prise où chaque fragment de fumée qui passe l'opacité écrit 50/255 en mélange additif, sol et murs peints en noir :
l'écran montre combien de couches recouvrent chaque pixel. Puis le même compte avec le masque de Gadgets, et deux fois
avec son calcul exact remplacé par « noir » puis par « visible » : leur différence compte les fragments qui entrent dans
une bande. (Trois lancements, au fragment près ; `tools/masque_fumee/formes.py`.)

| | avec l'usure (le défaut) | sans l'usure (`--sans-usure`) |
|---|---|---|
| pixels couverts par la fumée | 279 325 (243 683 sous les 4 couches) | idem |
| **fragments de fumée** (sur-dessin compris) | **1 045 958** — 3,74 par pixel couvert | idem |
| … dont devant une face / un dessus / le sol | 66 307 (6,3 %) / 154 / 979 478 | idem |
| … dont la couleur se verrait (un canal au-dessus du point noir) | 1 033 528 (98,8 %) | idem |
| gardés par le masque | 994 957 (95,1 %) | 994 985 |
| **qui entrent dans une bande et paient le calcul exact** | **430 891 (41,2 %)** | **122 109 (11,7 %)** |
| … avec la bande resserrée (forme 2) | 33 996 (3,3 %) | 25 293 (2,4 %) |

À **0°** (`--lacet=0 --lacet-j2=A`, même carte, la fusée posée ailleurs par la même règle) : 1 098 578 fragments, 42,4 % dans
une bande avec le masque de Gadgets, 4,0 % avec la bande resserrée. Le 45° n'est donc pas ce qui élargit la bande : l'usure
l'est.

**Le fait principal** : la certitude « visible sûr » du sol prend la matière à son PLANCHER (1 − force : la tache la plus
sombre de la texture), puis, avec l'usure, le poids d'usure le plus sombre (× 0,45). Si prudent que **la bande couvre presque
tout le sol faiblement éclairé** : 41 % des fragments de fumée y refont le sol entier. Sans l'usure, 12 %. Une forme qui
se TAISAIT dans la bande (essayée, rejetée : voir § 3) perdait ainsi **77 220 pixels** de fumée sur un sol visible.

### 2c. Le code que Godot génère (GLSL capturé par Mesa, compté en SPIR-V)

Mesa écrit chaque programme que Godot lui donne à compiler (`MESA_SHADER_CAPTURE_PATH`), après le préprocesseur de Godot ;
`tools/masque_fumee/compter_glsl.py` en compile le fragment de la fumée (glslangValidator), l'optimise (`spirv-opt -O` :
inlining, code mort) et compte. Même spécialisation (passe de base, non éclairé) pour toutes les lignes.
⚠️ Godot garde un cache de programmes compilés (`user://shader_cache`) : un programme déjà en cache n'est pas recompilé,
donc pas capturé — le vider avant chaque capture.

| fragment de la fumée | instructions optimisées | lectures de texture (statiques) | branchements | boucles |
|---|---|---|---|---|
| sans masque (M0 ; et les couches du pochoir) | 1 964 | 17 | 92 | 1 |
| masque de Gadgets, sans usure | 12 423 | 93 | 596 | 12 |
| **masque de Gadgets, avec usure (M1)** | **14 649** | **98** | 659 | 15 |
| forme compacte, avec usure | 6 079 | 42 | 288 | 6 |
| bande resserrée, avec usure | 5 759 | 40 | 274 | 6 |
| pochoir : le juge, avec usure | 4 242 | 23 | 190 | 6 |
| pochoir : les couches | 1 966 | 17 | 92 | 1 |

Avant inlining, le masque de Gadgets pèse ~24 200 instructions, dont **13 000 pour les cinq copies du sol** (les
coutures) et 8 200 pour les trois copies de la face. **Et les GLSL de M0 et de M1 capturés sur ma branche sont identiques,
octet pour octet, à ceux capturés sur la base** (`60e5c6d`) : le jeu par défaut et `--fumee-masque` n'ont pas changé.

### 2c bis. Le travail d'un fragment, chemin par chemin (lu dans le code, pondéré par les comptes du § 2b)

| | lectures de texture | tours de boucle | calcul lourd |
|---|---|---|---|
| la couleur de la couche (toutes formes) | 9 (la lightmap lissée : le point + 8 autour) | lissage 8 | pâte (8 hachages à `sin`), température |
| masque : le parcours | 2 à 3 (`grille_murs`) | 1 à 2 (4 au plus) | — |
| masque : le sol hors bande (≈ 55 % des fragments) | 1 | contact 2 | pâte (8 `sin`) |
| masque : le sol DANS la bande (41 % avec usure, 12 % sans) | 1 + 3 | contact 2 × 2 | pâte × 2, température (3 `pow`), usure du sol (≈ 8 hachages, un éclat), 3 `pate_facteur` (18 `pow`) |
| masque : une couture (≈ 0,5 % des fragments) | × 4 | 4 | × 4 |
| masque : une face (6,3 %) | 11 | — | pâte, température ; dans sa bande, l'usure d'une face (jusqu'à 48 impacts, `atan`, `pow`) |

En moyenne, un fragment de fumée lit ~9 textures sans masque et ~15 avec (+ 65 %), et fait, dans 41 % des cas, deux fois la
pâte et une vingtaine de `pow` de plus. Le pochoir fait tout le travail du masque une fois par PIXEL couvert (279 325) au
lieu d'une fois par FRAGMENT (1 045 958), et la bande resserrée n'en envoie que 3 % au calcul exact.

### 2d. L'estimation qui explique le mieux 2,4 ms

Le prix est **par fragment**, multiplié par le **sur-dessin** : chaque pixel de fumée paie le masque 3,7 fois. Sur la scène
comptée (1080p), c'est 1,05 million d'exécutions du masque par image ; en vue unique le jeu est rastérisé à la résolution
de la **fenêtre** (ROADMAP, chantier R : 3,6 fois plus de pixels qu'en 1080p sur le Mac), donc de l'ordre de **3 à 4
millions** sur le Mac. Ce qui a fait passer le prix de +0,28 ms (V1f, 25/09, **sans** usure) à +2,0 / +2,4 ms (état intégré,
**avec** usure) :
- **la bande du sol, élargie par l'usure** : 12 % → 41 % des fragments refont le sol entier (lightmap, matière, pâte,
  température, usure du sol, trois `pate_facteur` — de l'ordre de 25 `pow` et 15 `sin` de plus). Et ces fragments ne sont
  pas regroupés : la bande suit le bruit du lavis, donc presque chaque groupe de 32 fragments (SIMD) en contient, et **le
  groupe entier paie le chemin long**. En pratique, bien plus que 41 % du travail passe par là ;
- **la taille du code** : 14 649 instructions contre 1 964 (×7,5), 98 lectures statiques. Plus de registres par fragment,
  donc moins de fragments en vol sur le GPU : tous les fragments de fumée ralentissent, même ceux qui sortent tôt ;
- l'usure des faces (la bande d'Iso 1) ne touche que 6 % des fragments : elle ne pouvait pas rendre grand-chose, et n'a
  rien rendu.

**Ce qui reste incertain** : la part de chacune des deux causes (un compilateur Apple n'est pas `spirv-opt`, et la
divergence réelle dépend de la forme des groupes du GPU) ; la taille de la fenêtre au moment des séries d'Iso 1 ; et que le
GPU soit bien le goulot au 1 % bas. **La série du § 4 les sépare** : M1 → V1 isole la taille du code, V1 → V2 la bande du
sol, V2 → V3 le sur-dessin.

## 3. Les formes moins chères

Trois drapeaux (`IsoVolumes.FORMES_MASQUE`), **éteints par défaut**. Chacun allume le masque et AJOUTE une idée à la
précédente. Aucun ne change la règle de Gadgets (« la couche se tait là où ce que le pixel montre s'affiche noir »), ni ses
certitudes, ni le point noir : seulement combien de fois, et avec combien de code, on la calcule. Code :
`volume_masque_compact.gdshaderinc` (inclus sous `MASQUE_COMPACT` seulement) ; `volume_iso.gdshader` (l'appel, et le
pochoir) ; `iso_volumes.gd` (drapeaux, variantes, juge). Garde : `tools/test_masque_formes.gd` (48 vérifications).

| forme | drapeau | ce qu'elle retire du compte du § 2 | écart au masque de Gadgets (hors corps de J1) | fuite |
|---|---|---|---|---|
| V1 compacte | `--fumee-masque-compact` | le code : 14 649 → 6 079 instructions ; le travail exécuté est le même | **0 pixel** | 0 |
| V2 bande resserrée | `--fumee-masque-resserre` | + le calcul exact : 430 891 → 33 996 fragments ; 5 759 instructions | **0 pixel** | 0 |
| V3 pochoir | `--fumee-masque-pochoir` | + le sur-dessin : ~1,05 M exécutions → ~0,28 M (une par pixel couvert) ; couches à 1 966 instructions | **0 pixel** | 0 |

Les mêmes verdicts **à 45° B et à 0°** (deux lancements chacun), **avec et sans usure**. Deux prises du masque de Gadgets
diffèrent entre elles de 85 à 223 pixels, tous au pied de J1 (son corps frémit, son contact au sol avec lui) : c'est le
bruit de la scène, et les formes n'en ajoutent aucun ailleurs. Là où il reste un écart hors de cet ensemble, la fumée n'y
change rien (A = B) : c'est le décor qui a bougé, pas le masque (2 pixels, une fois).

**En écran scindé** (le pochoir y vit dans DEUX sous-vues, chacune avec son tampon de pochoir) :
- **J1 (sa sous-vue)** : 0 fuite, et le pochoir est égal au masque de Gadgets au pixel près (4 096 pixels de fumée tus par
  les deux, les mêmes) — le pochoir marche dans une sous-vue, pas seulement dans la racine ;
- **J2 (l'autre sous-vue, lacet B, qui regarde depuis le côté opposé)** : le pochoir tait la fumée sur 3 503 pixels, le
  masque de Gadgets sur 3 478, **3 270 en commun** ; le reste est le bruit de SA vue, que je n'ai pas su tenir : proche de la
  fusée, J2 en est ébloui (0,105), et son voile et son flou animés font différer deux prises identiques jusqu'à 226/255 ; sa
  vue n'a alors aucun pixel noir. La seconde sous-vue a donc bien son pochoir, et le juge lit bien la lumière de J2 ;
  l'égalité AU PIXEL chez J2 n'est pas prouvée (voir « non prouvé »).
- À 0°, un pixel à 1/255 « fuit » chez J1 — avec le masque de Gadgets comme avec le pochoir, là où la fumée sans masque est
  noire elle aussi, ses voisins éclairés ayant varié de 1 à 2/255 à cet instant : la lumière a bougé entre les prises.

- **V1, la forme compacte.** Le parcours NOMME la surface rencontrée (sol, face ou dessus) au lieu de la juger sur place,
  et chacune n'est jugée qu'à un seul endroit ; les côtés d'une couture passent par une boucle à nombre de tours variable
  (1 ou 4), qu'un compilateur ne peut pas dérouler en quatre copies. Mêmes expressions, même ordre (garde : chaque ligne de
  calcul du parcours de Gadgets est dans le compact, hors les six qui deviennent la cible).
- **V2, la bande du sol resserrée.** La certitude « visible sûr » lit la matière EXACTE (la même lecture que `sol_ecrit` :
  même texture, même adresse, même niveau de mipmap) au lieu de son plancher. Elle reste une borne prouvée — chaque facteur
  garde au moins sa part (`pate_facteur(x, f) ≥ f·x`), la température garde la luminance (elle la renormalise), l'usure et
  son poids sont pris du côté sombre (le poids lu sur la pâte, plus claire que le sol qu'elle précède) — donc la réponse ne
  change pas ; seule la bande rétrécit. Et dans la bande, le sol exact reprend la lightmap et la pâte déjà calculées au lieu
  de les refaire (`sol_ecrit_depuis`, dont la fin est gardée ligne à ligne contre `sol_ecrit`).
- **V3, le pochoir.** Le rayon de vue d'un pixel est une seule droite (caméra orthographique) : les quatre couches y voient
  la MÊME surface derrière elles. Un **juge** par volume — un plan à la hauteur de la plus haute couche, dessiné juste
  avant elles (`PRIORITE_JUGE`) — pose la question une fois par pixel et écrit 1 dans le **pochoir** (stencil) où la
  réponse est « noir », sans rien peindre ; les couches, compilées sans masque, portent `stencil_mode read,
  compare_not_equal, 1` : le test du pochoir se fait avant leur shader, un fragment refusé ne coûte rien. Vérifié dans le
  cloud avant de bâtir : le stencil marche en `gl_compatibility` 4.7, et il est remis à zéro à chaque image. Personne
  d'autre dans le projet ne s'en sert. Le juge couvre le disque de chaque couche vu depuis sa hauteur (carré de demi-côté
  rayon + hauteur, valable tant que le tangage dépasse 45° ; gardé). Coût ajouté : un appel de dessin par volume et par vue.
  Le ruban (la toile du voile), que le masque de Gadgets ne masque jamais, ne passe pas sous le pochoir.

**Les pistes jugées et non suivies :**
- **« la couleur d'abord »** (le masque seulement là où la couleur de la couche se verrait) : essayée ; même écran, mais
  98,8 % des fragments de cette scène ont une couleur visible — elle ne retirait que 1,2 % du travail. Retirée.
- **« se taire dans la bande »** (plus aucun calcul exact) : essayée ; **échoue la preuve** (77 220 pixels de fumée perdus
  sur un sol visible, écart jusqu'à 74/255). Retirée. C'est elle qui a montré la largeur de la bande.
- **lire la lightmap au lieu de recalculer** : le masque lit déjà la lightmap ; ce qu'il recalcule, c'est ce que le sol en
  FAIT (pâte, matière, usure). La règle « lumière brute » a été mesurée fausse par Gadgets le 25/09 (11 750 pixels fautifs).
- **une résolution réduite** : il faudrait une passe de plus (une sous-vue), ce que la session Budget désigne comme le coût
  le plus sûr, et un rééchantillonnage au bord du noir (une fuite possible). Le pochoir fait mieux sans passe de plus.

## 4. La série pour le Mac

Une commande, vingt-cinq minutes, au calme (verrou du Mac pris, aucun Godot ouvert, fenêtre de silence annoncée) :

```bash
mkdir /tmp/candela-mac.lock
./tools/masque_fumee/serie_mac.sh /tmp/serie-masque-fumee      # SECONDES=60 par défaut
rmdir /tmp/candela-mac.lock
# Essai à blanc de la mécanique, sans Godot : ESSAI_A_BLANC=1 ./tools/masque_fumee/serie_mac.sh /tmp/essai
```

Chaque prise est le banc de la règle 278 :
`Godot --log-file /tmp/candela-serie-masque.log --path . res://tools/bench_framerate.tscn -- --seconds 60 --max-fps 0
--fusee --vue-unique --classe=pompe <drapeau>`.

| bras | drapeau | ce que la prise doit imprimer (sinon elle est refusée et la série s'arrête) |
|---|---|---|
| M0 | *(aucun)* | `[fumée masque] éteint` |
| M1 | `--fumee-masque` | `[fumée masque] forme : celle de Gadgets` |
| V1 | `--fumee-masque-compact` | `[fumée masque] forme : compacte (MASQUE_COMPACT)` |
| V2 | `--fumee-masque-resserre` | `[fumée masque] forme : compacte, bande resserrée (MASQUE_COMPACT, MASQUE_RESSERRE)` |
| V3 | `--fumee-masque-pochoir` | `[fumée masque] forme : pochoir, compacte, bande resserrée (MASQUE_COMPACT, MASQUE_RESSERRE, MASQUE_POCHOIR)` |

Et pour toutes : `Rendu : iso lacet 45° B`, `[usure] allumée`, aucune `SHADER ERROR` ni `SCRIPT ERROR`.
**Ordre** : une chauffe M0 non comptée, puis `M0 M1 V1 V2 V3 | V3 V2 V1 M1 M0 | M0 M1 V1 V2 V3 | V3 V2 V1 M1 M0` — même
position moyenne pour chaque bras (10,5), quatre prises chacun. **Verdict imprimé** : série VALIDE si les quatre M0 tiennent
dans 5 % ; un bras PASSE si sa médiane des médianes ≥ 0,970 × M0 et son 1 % bas médian (hors 10 s) ≥ 60.

## Les images

`planche.html` (dans ce dossier, autonome, images en chemins relatifs) : pour la fumée sans masque, le masque de Gadgets et
chaque forme — la carte du NOIR SALI (rouge : un pixel noir sans fumée qu'elle allume ; gris clair : le sol éclairé),
l'image elle-même (gain ×3 : la fumée éclairée), et l'écart au masque de Gadgets (magenta, quelques pixels au pied de J1) ;
à 45° B (`45B_*.jpg`) et à 0° (`0A_*.jpg`) ; et l'écran scindé, J1 à gauche, J2 à droite (`*_s-b_noir.jpg`,
`*_s-c3_noir.jpg` : la moitié de J2 n'a aucun pixel noir, il est ébloui). Sans masque, la couronne rouge ; avec le masque
de Gadgets et avec chaque forme, aucune.

## Refaire

```bash
# Godot 4.7 (Linux), Xvfb ; une fois : godot --headless --path . --import
# Les prises (vue unique 45° B, écran scindé, compte des fragments) ; vider le cache de shaders pour capturer le GLSL :
rm -rf ~/.local/share/godot/app_userdata/Candela\ 2D/shader_cache
MESA_SHADER_CAPTURE_PATH=/tmp/cap GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" \
  env GODOT=/usr/local/bin/godot ./tools/run_photos.sh --plan=loupe-fusee-masque-formes --led-murs-fige
# (à 0° : ajouter --lacet=0 --lacet-j2=A ; sans usure : --sans-usure)
python3 tools/masque_fumee/formes.py ~/.local/share/godot/app_userdata/Candela\ 2D/photos/loupe
python3 tools/masque_fumee/compter_glsl.py /tmp/cap          # apt-get install glslang-tools spirv-tools
python3 tools/masque_fumee/planche.py docs/iso/cloud/masque-fumee "45° B=<dossier des prises>" "0° A=<dossier à 0°>"
# La garde headless, et la suite :
godot --headless --path . --script res://tools/test_masque_formes.gd
GODOT=/usr/local/bin/godot ./tools/run_suites.sh
```

⚠️ Un `user://` neuf joue l'INTRO par-dessus la scène au premier lancement : ma première prise l'a photographiée (piège
connu). Le drapeau « intro vue » s'écrit dès le premier lancement ; la seconde prise était bonne. Toujours regarder la
première image.

## Ce que je n'ai PAS pu prouver

- **Le temps.** Aucune de ces formes n'est mesurée : rien ici ne dit qu'elle passe la règle 278. Seule la série du Mac le
  dira. Les comptes disent où est le travail, pas combien il coûte sur un GPU Apple.
- **Que le compilateur d'Apple profite de la forme compacte** comme `spirv-opt` : il inline sans doute pareil, mais il peut
  aussi dérouler la boucle des coutures ; ce qu'il en fait ne se voit que par la mesure.
- **Le pochoir sur le Mac** : le stencil marche en `gl_compatibility` 4.7 sous Mesa, dans la vue unique et dans les
  deux sous-vues de l'écran scindé ; je n'ai pas pu le voir sous le pilote d'Apple (OpenGL sur Metal). Une prise
  `loupe-fusee-masque-formes` sur le Mac le montrerait en quelques minutes (`python3 tools/masque_fumee/formes.py` sur ses
  images).
- **L'égalité au pixel dans la vue de J2 en écran scindé** : J2, ébloui par la fusée dans cette mise en scène, a une vue
  voilée et animée ; le pochoir y tait la fumée comme Gadgets (3 270 pixels communs sur ~3 500) sans égalité prouvée au
  pixel. Pour la prouver : une mise en scène où J2 voit la fusée sans en être ébloui. En vue unique (la racine), la vue
  prouvée est celle de J1 ; le code de J2 est le même (le juge lit la lightmap de la caméra qui le dessine, comme les
  couches et le masque de Gadgets).
- **Les gadgets** (suie, poussière, nappes) sous le pochoir : couverts par la même règle (un juge par volume, disque par
  couche), pas photographiés — la scène de preuve n'a que la fusée.
- **La scène du banc** (le pompe, ses étincelles) : mes comptes sont sur la scène de la preuve (même fumée, sans les tirs).

## Pièges découverts (à reporter dans la feuille de route)

1. **La certitude « visible sûr » du sol est si prudente qu'avec l'usure, 41 % des fragments de fumée refont le sol
   entier** (12 % sans usure). C'est la cause la plus probable du saut de prix du masque avec l'usure ; la bande des faces ne
   touchait que 6 % des fragments. Une borne de sûreté se juge aussi à la PART du travail qu'elle laisse passer.
2. **Un compilateur GLSL recopie chaque fonction à chaque appel** : le masque de Gadgets pesait 7,5 fois le code de la
   fumée, dont plus de la moitié pour cinq copies du même sol. Compter le code que Godot génère (Mesa le capture) avant de
   croire qu'une branche rarement prise ne coûte rien.
3. **Le cache de shaders de Godot cache les programmes à Mesa** : `MESA_SHADER_CAPTURE_PATH` ne voit que ce qui est
   compilé pendant le lancement ; vider `user://shader_cache` avant.
4. **Godot n'émet que les fonctions appelées, mais tous les uniformes** : un GLSL capturé se reconnaît à ses uniformes.
5. **`bool(null)` plante** : `get_shader_parameter` d'un paramètre jamais posé rend `null` (attrapé par la garde headless
   du pochoir). Comparer à `true`.
6. **Deux prises du même masque diffèrent déjà de ~90 pixels** au pied de J1 (le corps frémit, son contact au sol avec
   lui) : un écart au pixel entre deux variantes se juge HORS de cet ensemble instable, ou contre une seconde prise de la
   référence.
7. **Le stencil marche en `gl_compatibility` 4.7** (`stencil_mode`), et il est vidé à chaque image : un outil de plus
   pour faire une seule fois par pixel ce qu'un empilement de couches fait N fois.
