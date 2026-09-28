# L'écart aux illustrations, évaluation 11 — tout ce que la nuit sait faire, allumé ensemble

Session cloud, branche `claude/cloud-ecart-11`, partie d'`origin/claude/cloud-ecart-illustrations` (f4039a0), le
28/09/2026 entre ~02:30 et ~04:45 (heure de Paris). Lancée par la session coordinatrice « CLOUD ISO UNRAILED ». **Aucun
défaut du jeu ne change** : six fusions, l'outil de prise (`tools/photo_ecart.gd`), des scripts et des documents.

## Pour Adrien, en cinq lignes

1. Ouvre `planche.html` : pour chaque illustration, le dessin, puis le jeu tel qu'il est, avec les essais d'hier, et
   avec tout ce que la nuit a ajouté — au même instant, en grand et à la loupe.
2. La lampe est devenue crème : la lumière du jeu a maintenant la couleur de celle des dessins (sur « Amical », l'écart
   de couleur tombe de 99 à 13 ; sur l'écran scindé, de 116 à 35).
3. Ton propre personnage est devenu sombre comme dans les dessins (clarté 136 → 38 ; les dessins sont à 40-60), sur les
   trois cartes essayées.
4. Les murs meublés et le sol marqué se voient à peine à la taille du jeu. Et le sol marqué a un petit défaut à corriger
   avant de l'allumer : sur la Croisée, torches éteintes, il fait briller quelques points de l'arête d'un mur.
5. Ce qui reste loin ne se comblera pas par un essai : les dessins montrent une pénombre partout, vue à hauteur d'homme ;
   le jeu, vu de haut, ne montre que ce que la lumière touche. C'est la règle du jeu, et c'est voulu.

## 1. Les fusions

Dans l'ordre demandé, une par une, chacune dans son propre commit de fusion :

| branche | commit | conflits | résolution |
|---|---|---|---|
| `origin/integration-iso14` | a30a407 | aucun | — |
| `claude/cloud-corps-sombre` | 3c968da | `iso_materiaux.gd`, `voxel_catalogue.gd`, `tools/run_suites.sh` | voir ci-dessous |
| `claude/cloud-lampe-claire` | b1d25cb | `tools/run_suites.sh` | union des deux listes de bancs |
| `claude/cloud-murs-meubles` | 8a3bc44 | `tools/run_suites.sh` | union ; un `tools/photo_ecart.gd.uid` non suivi, engendré par mon import, gênait la fusion : même contenu (`uid://bf012auwltlev`) que celui de la branche, retiré puis repris d'elle |
| `claude/cloud-sol-marque` | 9e398d5 | `tools/run_suites.sh` | union |
| `claude/cloud-masque-fumee-2` | 03e1c3c | `tools/loupe.gd`, `tools/run_suites.sh`, `volume_masque.gdshaderinc.uid` | voir ci-dessous |

**`iso_materiaux.gd` (`accorder_corps`)** — HEAD (Q33, corps détaillé fusionné) ajoutait `accorder_passe_profondeur(materiau)`
après la variante `CORPS_DETAIL` et, sous la fonction, la fonction elle-même ; corps-sombre ajoutait après la même ligne le
bloc `CORPS_SOI_SOMBRE`. Les deux gardés, dans cet ordre : détail, sa passe de profondeur, puis soi-sombre. **Une ligne de
plus, à la résolution** : `accorder_passe_profondeur(materiau)` aussi après la variante `CORPS_SOI_SOMBRE`. Pourquoi : Q33
exige que la pré-passe de profondeur porte le MÊME programme que la couleur (sinon deux programmes, et une pièce entière
peut être effacée au bit près). Sans cet appel, `--corps-detaille` avec `--corps-soi-sombre` laisserait la profondeur sur
la variante `CORPS_DETAIL` seule pendant que la couleur passe à `CORPS_DETAIL` + `CORPS_SOI_SOMBRE` — précisément la
combinaison de « tout ». Sans méta de profondeur (drapeau de détail éteint), l'appel sort aussitôt : rien ne change par
défaut. ⚠️ C'est la seule ligne de code de jeu que cette session ait écrite ; elle n'existe que parce que les deux branches
se rencontrent ici — **à reporter à l'intégration**.

**`voxel_catalogue.gd`** — deux blocs de constantes et fonctions ajoutés au même endroit (Q33 `DETAIL_FUSION` /
`detail_fusionne`, Q39 `DRAPEAU_SOI_SOMBRE` / `soi_sombre_actif`) : les deux gardés, l'un après l'autre.

**`tools/run_suites.sh`** — chaque branche ajoute son banc à la même ligne : l'union ordonnée (celle de HEAD, puis les
nouveaux). Bancs ajoutés : `test_corps_soi_sombre`, `test_lampe_claire`, `test_iso_murs_meubles`, `test_sol_marque`,
`test_masque_formes`.

**`tools/loupe.gd`** — deux entrées de plan ajoutées au même endroit du catalogue (`loupe-fusee-ages`,
`loupe-fusee-masque-formes`) : les deux gardées.

**`volume_masque.gdshaderinc.uid`** — les deux branches ont versionné le `.uid` que leur import avait engendré, chacune le
sien (`c2pnjjxp2pud3` contre `b8ss5sh1yu6dd`). Aucun fichier ne cite l'un ou l'autre (`grep` sur `.gd`, `.tscn`, `.tres`,
shaders) : j'ai gardé celui de HEAD (lampe-claire). Un seul `.uid` par fichier ; le choix est sans effet.

**Rien n'a été perdu — vérifié deux fois après les fusions** (piège du 2026-09-09) :
- les ancres (`func`, drapeaux `"--…"`, `#define`/`#include`) ajoutées par chaque branche depuis sa base, cherchées dans
  l'arbre fusionné : 33 (corps-sombre), 23 (lampe-claire), 204 (murs-meubles), 194 (sol-marque), 41 (masque-fumée), 134
  (écart d'hier) — **0 manquante** ;
- plus strict : TOUTES les lignes non vides ajoutées par chaque branche dans `.gd`, shaders, `.sh`, `.tscn` (678 à 4 265
  par branche) — **une seule absente par branche, la ligne de `run_suites.sh`**, remplacée par l'union, ce qui est voulu.

**Les gardes « drapeau éteint : rien ne change »** de chaque essai sont dans la suite et passent (`test_corps_soi_sombre`,
`test_lampe_claire`, `test_iso_murs_meubles`, `test_sol_marque`, `test_masque_formes`). **Au pixel aussi** : les prises
`defaut` de ce soir, comprimées comme celles de l'évaluation 10, en diffèrent de 322 pixels (> 16/255) au duel — le
niveau du bruit entre deux lancements (0 à 364 hier). Seul l'écran scindé bouge davantage, à cause du disque violacé
(§ 5), qui change de place d'un lancement à l'autre.

**Suite complète verte sur les fusions** (85c735c) : 145 bancs OK, « tout passe, sans erreur de script (647 s) », EXIT 0.
Et de nouveau sur l'état final (voir en bas).

Les deux corrections du photographe pour Xvfb (0c67705) étaient déjà dans la base (constaté par l'évaluation 10) : rien à
réappliquer.

## 2. Les prises

L'outil de l'évaluation 10, `tools/photo_ecart.gd`, avec trois ajouts (outil seulement) :
- **`croisee` et `bunker`** : la même mise en scène que `duel` (la règle du photographe, `_mise_en_scene_du_duel` : J1 à
  3,5 cases au sud d'un mur haut intérieur, J2 dans son cône), sur `map_003_la_croisee` et `map_004_le_bunker`, torches
  allumées puis éteintes, puis le Cloître reposé. Ces scènes viennent **avant** les impacts et la fusée : une fusée brûle
  ~20 s et survivrait au changement de carte ;
- **`equite`** : l'écran scindé, J1 et J2 aux places symétriques par le centre du Cloître (la carte l'est en x comme en y),
  torche vers le pilier central ;
- **la prise « sans corps »** : pour `duel`, `croisee_duel`, `bunker_duel` et `equite`, une seconde prise au MÊME instant
  gelé, les corps 3D cachés (`Presentation3D._corps`, présentation suspendue le temps de la prise, sinon `_suivre` les
  rallume) — la différence donne les pixels de corps. C'est ce qui mesure « ton corps » sans le faire à la main.

Quatre lancements (`lancer.sh`), même graine, `--fixed-fps 60`, 1920×1080, lacet 45° B, zoom ×1,5 (lus dans le journal :
« lacet de J1 : 45.0° · zoom caméra : 1.5 ») : `defaut`, `temoin`, `hier` (les neuf drapeaux de l'évaluation 10), `tout`
(les neuf + `--lampe-claire --corps-soi-sombre --murs-meubles-essai --sol-marque-essai --fumee-masque-pochoir`). ~15 min
chacun. **J'ai regardé la première image de chaque séance : aucune intro** (l'outil la congédie, `user://` neuf à part,
`XDG_DATA_HOME`). 20 images par lancement, aucune manquante.

## 3. Les chiffres

Luminance Rec. 709 des valeurs sRGB, 0..255. Tout est dans `mesures.json`.

### La lumière — ce qui a changé

| | 1 % le plus clair (Cloître, scènes à la lampe) | sa couleur |
|---|---|---|
| illustrations | 138 à 251 | crème, ≈ (220-250, 180-240, 110-220) |
| défaut | 119 à 126 | ocre (172, 144, 99) |
| hier | 117 à 125 | ocre, inchangée |
| **tout** | **170 à 197** (145 au duel, où J2 occupe le cône ; 126 aux impacts, peu de sol éclairé) | **crème (230, 206, 168)** |

### De combien l'écart s'est réduit, par illustration

« Couleur » : distance RGB entre la couleur du 1 % le plus clair du jeu et celle du dessin. « Distance » : écart moyen
entre les deux distributions de luminance, quantile à quantile (0 = mêmes clairs et mêmes sombres).

| illustration | scène | couleur défaut → hier → **tout** | 1 % clair, écart au dessin : défaut → **tout** | distance défaut → hier → tout |
|---|---|---|---|---|
| amical | zone | 99 → 99 → **13** | −60 → **+3** | 36,7 → 37,1 → 36,5 |
| ecran_scinde | scinde | 116 → 115 → **35** | −79 → **−11** | 47,7 → 48,0 → 47,1 |
| amical_ligne | mur | 147 → 148 → **38** | −100 → −53 | 39,2 → 39,6 → 38,9 |
| intro_seuil | arena | 111 → 111 → **40** | −78 → −20 | 39,5 → 39,9 → 39,1 |
| intro_prix | duel | 154 → 153 → **49** | −99 → −80 | 41,2 → 41,6 → 41,1 |
| accueil | arena | 76 → 77 → **50** | −46 → +12 | 25,5 → 25,8 → 25,5 |
| competitif | impacts | 77 → 80 → 53 | −29 → −22 | 27,6 → 27,9 → 27,9 |
| creer_local, rejoindre_local | sol | 97 → 96 → 66 | −66 → **−7** | 34,1 → 34,5 → 33,8 |
| intro_allumage | impacts | 176 → 179 → 97 | −116 → −109 | 45,9 → 46,3 → 45,9 |
| entrainement | entrainement | 159 → 163 → 132 | −113 → −129 | 46,5 → 46,7 → 46,7 |
| intro_extinction | noir | 56 → 57 → 60 | −23 → −38 | 7,2 → 6,9 → 6,9 |
| rejoindre_ligne | mur | 157 → 158 → 153 | −22 → +25 | 25,7 → 26,1 → 26,0 |
| **creer_ligne** | fusee1 | 38 → 32 → **62** | +68 → +86 | 21,9 → 22,0 → 23,3 |

**Lecture.** « Hier » ne rapprochait rien de mesurable (ses essais assombrissent : hachures, contours). « Tout » rapproche
nettement **la couleur et l'éclat de la lumière** sur dix des quatorze illustrations qui ont une scène. Trois n'en
profitent pas pour une bonne raison : `rejoindre_ligne` (sa lumière est bleue, celle d'un boîtier fixe),
`intro_extinction` (torches éteintes) et `entrainement` (le 1 % le plus clair y BAISSE parce que ton propre corps, clair,
en faisait partie dans cette scène peu éclairée — la lampe, elle, y est crème). **Une s'éloigne** : `creer_ligne`, la
fusée — la lampe crème blanchit le cône qui traverse la lumière rouge, là où le dessin est tout rouge.
**La distance globale ne bouge pas** (±1) : elle est faite de la pénombre (médiane des dessins 16-51, du jeu 0), que le
jeu ne doit pas montrer. Tout ce que les essais changent tient dans la lumière.

### Ton corps

| | Cloître | Croisée | Bunker |
|---|---|---|---|
| défaut | 136 (114, 140, 157), bleu glacier | 135 | 136 |
| hier | 101 (85, 104, 117) : encre et mannequin | 102 | 101 |
| **tout** | **38 (32, 39, 45)**, ardoise ; 10 % de ses pixels au-dessus de 102 (le liseré) | 38 | 38 |
| illustrations | ardoise sombre, ~40-60 (relevé de l'évaluation 10) | | |

### Ce que « tout » change, au pixel

Contre le défaut, au même instant : 26 000 à 96 000 pixels par scène hors fusée et écran scindé symétrique (« hier » :
10 000 à 35 000), à peu près autant de
plus clairs (la lampe) que de plus sombres (corps, encre, marques, meubles). Bruit entre deux lancements identiques :
15 à 911 pixels, sauf à la fusée (9 500 à 37 000 : la fumée) et à l'écran scindé (≈ 20 000 : le disque violacé, § 5).

## 4. Le noir, torches éteintes

A = défaut, A' = témoin, B = hier ou tout : un pixel compte s'il est noir (≤ 7,5 au canal max) dans A ET A' et s'allume
dans B.

| carte | hier | **tout** | bruit (A → A') | valeur max allumée par tout |
|---|---|---|---|---|
| Cloître | 0 | **2** | 13 | 11 |
| Croisée | 1 | **8** | 1 | **51** |
| Bunker | 24 | **34** | 37 | 43 |

**Au Cloître et au Bunker, rien au-dessus du bruit. À la Croisée, 8 pixels contre 1** — et au Bunker, sous le bruit,
les mêmes taches. Où et pourquoi (`img/noir_sol_marque.jpg`) : de petites taches jaunes de 2 à 5 pixels, sur le
liseré du sommet d'un mur haut, près d'un coin. **Isolées au drapeau** : une prise avec les neuf drapeaux d'hier plus
`--sol-marque-essai` seul les reproduit au pixel (49, 36, 14) ; avec `--murs-meubles-essai` seul, non. **Le mécanisme**
(lu dans le code, non prouvé par une prise dédiée) : le liseré du sommet lit la lumière du sol à 8 px devant son arête
(`mur_iso.gdshader:219`, `lire_lumiere_moyenne(… d_bord + pied …)`, `pied = 8`), en quatre points le long de l'arête, et
`lire_lumiere` **divise** cette lumière par la peinture du sol (ligne 136 : `l * ref / max(peinture, plancher)`). Une
marque sombre du sol marqué sous ce point gonfle donc la lecture : la faible lumière des LED, divisée par une peinture
presque noire, devient une tache à 51/255. Ce qui reste à établir : **comment une marque atteint ce point**. Le sol
marqué se tient à 12 px des murs (`arena_decor.gd:103`) et le liseré lit à 8 px de l'arête (±1,9 px le long d'elle) :
sur le papier, cela suffit. Soit une marque de la Croisée ou du Bunker vient plus près que prévu (la garde a surtout été
mesurée au Cloître), soit la texture de peinture, filtrée, porte le bord d'une marque jusqu'au point de lecture. Je ne
l'ai pas tranché. **Ce n'est pas une fuite du noir de l'éclairage** (c'est la
lumière des LED, réelle), **mais c'est une tache plus claire que la surface qui la porte, créée par une marque qui ne
devait qu'assombrir** : la règle des pochoirs est enfreinte. Signalé, pas corrigé (hors tâche). Pour le reproduire :

```bash
H="--faisceau --mannequin --pochoirs-essai --encre-essai --tuyaux-essai --corps-detaille --enseignes-essai --fusee-rouge-long --fusee-rouge-sang"
XDG_DATA_HOME=$PWD/.xdg xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/photo_ecart.tscn -- \
    --no-eos --led-murs-fige --sortie=user://ecart11/isole --scenes=croisee $H --sol-marque-essai
# puis croisee_noir.png aux pixels (1041, 305), (1046, 309) : ≈ (49, 36, 14) ; sans --sol-marque-essai : ≤ (4, 0, 0).
```

À la fusée (4 s), « tout » allume 939 pixels noirs, comme « hier » (939) : c'est le rouge long d'hier, déjà expliqué par
l'évaluation 10 (la lumière de la fusée, plus longtemps forte, porte plus loin) — pas une fuite.

## 5. L'équité — écran scindé, 45° B, `tout`

J1 en (8 cases, centre), J2 au point symétrique par le centre du Cloître. Au lacet B, la vue de J2 est déjà dans le même
sens que celle de J1 : les deux moitiés se comparent pixel à pixel, sans retournement (vérifié : décalage optimal nul).
Décor et lumière comptés sur la prise sans les corps.

| lancement | décor éclairé J1 / J2 | **hors disque**, J2 − J1 | lumière (> 40) J1 / J2 | corps J1 / J2 |
|---|---|---|---|---|
| défaut | 681 496 / 674 601 | +1,32 % | 109 523 / 108 339 (−1,1 %) | 1 778 / 1 774 |
| témoin | 692 378 / 675 234 | +1,24 % | 109 740 / 108 458 | 1 771 / 1 771 |
| hier | 689 304 / 671 626 | +1,17 % | 107 040 / 105 823 | 2 134 / 2 146 |
| **tout** | 687 655 / 669 929 | **+1,16 %** | 116 196 / 115 947 (**−0,2 %**) | 2 098 / 2 124 (+1,2 %) |

- **Les essais n'ajoutent aucune asymétrie mesurable.** L'écart de décor hors disque (+1,2 à +1,3 %, au profit de J2)
  est le même dans les quatre lancements, défaut compris : il est dans le jeu tel qu'il est (texture du sol et filets LED
  au seuil du noir, non symétriques au pixel). La lumière est plus égale avec « tout » qu'au défaut. Les corps : 26 pixels
  d'écart avec « tout », 12 avec « hier », 0 à 4 au défaut — à la limite du bruit ; à surveiller au Mac (le liseré suit
  la lumière réelle de chaque côté).
- **Le seul écart net, présent au défaut : le « disque violacé ».** Dans la moitié de J1 seulement, une lueur ronde et
  faible (≈ (19, 15, 19)), de 15 000 à 27 000 pixels, s'affiche **dans le vide ou sur le sommet noir d'un pilier**, et
  **change de place d'un lancement à l'autre** (au défaut : coin haut gauche ; au témoin et avec les essais : sur le
  pilier). L'évaluation 10 l'avait sur son image par défaut, sans le relever (en haut, au milieu de la moitié de J1).
  Elle allume du noir (≈ 19/255 > 7,5) pour J1 seul : **défaut d'équité du jeu par défaut, hors de cette tâche, signalé
  et non corrigé.** Cause non trouvée. Pour le reproduire :
  `xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/photo_ecart.tscn -- --no-eos
  --led-murs-fige --sortie=user://ecart11/disque --scenes=equite` puis regarder le quart haut gauche d'`equite.png`
  (`img/equite_disque.jpg` : ce qui est éclairé d'un seul côté).

## 6. La planche

`planche.html` : en tête, les cinq lignes et quatre paires (la lampe et le corps sur « Amical », le contre-jour sur « Le
prix », l'écran scindé, et « L'accueil » plein cadre pour ce qui ne se rapproche pas) ; le tableau de l'écart ; le noir ;
l'équité ; les deux autres cartes ; puis chaque illustration — le dessin, défaut, hier, tout, en 1:1 (clic) et en loupe
×2 au même cadre (le tiers de l'écran centré sur la lumière du défaut, règle de l'évaluation 10), avec un commentaire
(`commentaires.py`). Les tableaux thème par thème de l'évaluation 10 (`../ecart-illustrations/planche.html`) restent
valables pour « hier ». Vérifiée rendue à 1 400 et 420 px de large (aucun défilement horizontal).

## Ce qui reste loin des illustrations, et pourquoi

**Ce que les règles du jeu interdisent** (ne pas combler dans le duel) :
1. **La pénombre lisible partout** — médiane des dessins 16-51, du jeu 0. C'est elle qui fait la distance globale, que
   les essais ne bougent pas. Hors de la lumière, rien : c'est le jeu.
2. **Le plan à hauteur d'homme** — le personnage à 60-80 % de l'image, un plafond, un couloir qui s'enfonce. Vu de haut,
   chacun voit autant autour de soi. Les menus, l'intro, la killcam peuvent l'emprunter ; le duel non.
3. **Le clair posé sur du sombre sans lumière** — « ZONE 4 » blanc, marquages blancs, LED cyan, panneau ARENA clair. Le
   jeu les peint sombres (enseignes, pochoirs, sol marqué) ; c'est pourquoi on ne les voit qu'à la loupe.
4. **Les douilles semées d'avance** — une douille dit « on a tiré ici ». Seule exception honnête : l'entraînement.

**Ce qui manque encore** (compatible, pas fait) :
- **Le faisceau visible dans l'air** (9 illustrations) : `--faisceau` d'hier n'en garde que la perle du cœur chaud ; le
  rayon dans la poussière reste retiré (il salissait le noir). Décision d'Adrien.
- **Des lumières d'ambiance fixes et colorées** (cyan, rouge, vert, la torche bleue de J2) : chacune change le jeu.
  Décision d'Adrien.
- **La fusée rouge sombre et sa fumée noire** : la lampe crème éloigne même `creer_ligne` ; le rouge sang reste
  contredit (moins de visibilité sous une lumière partagée).
- **La lisibilité des meubles et des marques** à la taille du jeu : plus sombres que leur surface par règle, ils ne se
  lisent qu'à la loupe. Les rendre lisibles sans les éclaircir demanderait plus de contraste de forme (arêtes, ombres
  portées), pas de valeur.

## Pièges et défauts découverts, à reporter dans la feuille de route

1. **Le sol marqué éclaircit l'arête d'un mur** (§ 4) : `--sol-marque-essai` + `mur_iso.gdshader:136` (division par la
   peinture) + le liseré du sommet qui lit le long de l'arête (ligne 219). À corriger avant d'allumer l'essai : trouver
   la marque en cause (prise marque par marque) et l'écarter, ou exclure la peinture des marques de la lecture du liseré. Plus généralement : **toute
   peinture sombre du sol devient une lumière pour les lectures qui divisent par elle** — la règle « rien de plus clair
   que la surface » ne se vérifie pas sur la marque seule, mais sur tout ce qui LIT le sol.
2. **Le disque violacé de l'écran scindé** (§ 5) : présent au défaut, dans la moitié de J1 seulement, position
   variable d'un lancement à l'autre ; une lueur ≈ 19/255 là où tout devrait être noir.
3. **Fusion corps-sombre × Q33** : la ligne `accorder_passe_profondeur` après la variante `CORPS_SOI_SOMBRE`
   (`iso_materiaux.gd`, `accorder_corps`) n'existe dans aucune des deux branches ; l'intégration doit la reprendre, sinon
   `--corps-detaille --corps-soi-sombre` retombe dans le défaut de Q33 (deux programmes, une pièce effacée).
4. **`volume_masque.gdshaderinc.uid`** : versionné par deux branches avec deux valeurs ; toute intégration qui les réunit
   aura le même conflit (sans conséquence, en garder un).
5. **Un `.uid` engendré par l'import bloque une fusion** (`tools/photo_ecart.gd.uid` non suivi ici, suivi par la branche
   des murs meublés) : `git merge` refuse d'écraser un fichier non suivi. Vérifier qu'il est identique, le retirer,
   refusionner.
6. **Au lacet B, les deux vues de l'écran scindé sont dans le même sens** pour deux joueurs symétriques par le centre :
   pour les comparer, ne PAS retourner la moitié de J2 (ma première mesure l'avait fait : 686 000 pixels « différents »
   au lieu de 72 000).
7. **« Le 1 % le plus clair » d'une scène peu éclairée contient le corps du joueur** : un corps assombri le fait baisser
   même quand la lampe s'éclaircit (entraînement). Mesurer la lampe sur le sol du cône, pas sur l'image entière.

## Pour tout refaire

```bash
git fetch origin claude/cloud-ecart-11 && git checkout claude/cloud-ecart-11
godot --headless --path . --import                       # la première fois
pip install pillow numpy scipy                            # pour les mesures
# Les quatre lancements (~15 min chacun sous llvmpipe), les mesures, la planche :
XDG_DATA_HOME=$PWD/.xdg GODOT=/usr/local/bin/godot ./docs/iso/cloud/ecart-11/lancer.sh
# Seulement certains lancements :
SEULS="hier tout" XDG_DATA_HOME=$PWD/.xdg GODOT=/usr/local/bin/godot ./docs/iso/cloud/ecart-11/lancer.sh
# Mesures, vignettes et planche seules, sur des prises existantes (user://ecart11 ou $ECART_SOURCE) :
XDG_DATA_HOME=$PWD/.xdg python3 docs/iso/cloud/ecart-11/mesurer.py
XDG_DATA_HOME=$PWD/.xdg python3 docs/iso/cloud/ecart-11/vignettes.py
python3 docs/iso/cloud/ecart-11/planche.py
# La suite complète :
GODOT=/usr/local/bin/godot ./tools/run_suites.sh
```

Sur le Mac : `ENVELOPPE= GODOT=/Applications/Godot.app/Contents/MacOS/Godot ./docs/iso/cloud/ecart-11/lancer.sh`, la
fenêtre au premier plan.

## Ce que je n'ai PAS pu prouver

- **Aucune cadence.** Le cloud tourne à quelques images par seconde ; « tout » allume cinq essais de plus à la fois
  (murs meublés : des maillages ; lampe crème et corps sombre : des shaders) — leur coût ensemble se mesure au Mac.
- **L'éblouissement.** La lampe crème porte le 1 % le plus clair jusqu'à 190-210 ; ce que cela fait à l'œil d'un joueur
  qui regarde un adversaire dans son cône ne se juge pas ici.
- **Les couleurs** valent à ~1/255 du Mac (llvmpipe) ; **les gestes des corps** ne valent rien ici.
- **Le mécanisme du § 4** est lu dans le code et cohérent avec l'isolement au drapeau ; je n'ai prouvé ni quelle marque
  est en cause, ni comment elle atteint le point de lecture du liseré (il faudrait une prise marque par marque).
- **La cause du disque violacé** : non trouvée. Seulement son existence, sa couleur, sa taille et qu'il bouge.
- **L'écart de corps de 26 pixels en écran scindé avec « tout »** : au-dessus du bruit du défaut (0 à 4), sous 1,5 % ;
  je ne sais pas dire s'il vient du liseré (direction de la lumière de chaque côté) ou de l'arrondi.
- **La scène la plus proche reste un choix** (celui de l'évaluation 10, repris tel quel pour comparer) ; deux cartes de
  plus ne font pas toutes les cartes (l'Usine, l'arène circulaire ne sont pas prises).
- **« Écart réduit »** se mesure ici sur la couleur et l'éclat de la lumière et sur le corps ; la distance globale ne
  bouge pas, et aucune mesure ne dit « ressemble » à la place d'Adrien.

## État final

- Suite complète sur l'état final (après l'outil de prise) : voir la ligne suivante, mise à jour à la fin de la séance.
