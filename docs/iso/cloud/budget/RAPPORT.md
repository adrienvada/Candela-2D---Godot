# Le budget de rendu de ce qui arrive — rapport de la session cloud « budget »

> Branche `claude/cloud-budget`, partie de `origin/integration-iso14` (`18f5fdc`), 2026-09-27, de 01:10 à ~05:15 (Paris).
> **État : fait.** Instrument validé sur les deux chiffres connus, matrice complète (11 configurations × 2 lacets × 6 cartes
> × 2 vues, plus le pompe sous une fusée), décomposition du cas lourd. Suite complète : voir « Suite ».

## Pour Adrien, en cinq lignes

1. J'ai **compté** (pas mesuré la vitesse, impossible ici) ce que chaque nouveauté ajoute au travail de dessin : **aucune
   n'ajoute d'étape de rendu** (ni vue en plus, ni copie de l'écran, ni lumière à ombre en plus).
2. Les **personnages détaillés** sont la seule nouveauté qui ajoute vraiment des dessins : +12 par image en vue unique
   (+9 %), +24 en écran scindé.
3. Les **tuyaux** n'ajoutent qu'un dessin, mais **triplent le nombre de triangles** de la scène 3D : à essayer sur ton Mac
   en écran scindé.
4. Le **masque de la fumée** ne se voit pas du tout dans ces comptes, et c'est pourtant le seul qui a déjà fait tomber ton
   Mac sous 60 : **c'est lui à remesurer en premier**, avec sa nouvelle « bande ».
5. Le plus lourd du jeu reste l'**échange au pompe** : ses étincelles font les deux tiers des dessins, et l'écran scindé
   double tout ; tout ce qui s'ajoute s'empile là-dessus.

## Méthode

### Ce que le cloud peut dire, et ce qu'il ne peut pas

Le rendu du cloud est logiciel (Mesa llvmpipe) : le jeu y tourne à deux images par seconde, aucun temps n'y vaut rien, et
**aucun chiffre d'images par seconde de ce rapport n'est une mesure**. Ce qui ne dépend pas du GPU, en revanche, s'y compte
exactement : ce que le moteur SOUMET à chaque image. Appels de dessin, primitives, objets, vues rendues, copies d'écran,
lumières à ombre, mémoire vidéo allouée. Ce sont des coûts de processeur (préparation, pilote) et de géométrie ; ils ne disent
rien du coût par pixel d'un shader (l'éblouissement, le masque de la fumée, la matière des corps). Un ajout à « zéro appel »
peut donc coûter cher sur le Mac — et c'est précisément ce que ce rapport désigne à mesurer en premier.

### L'instrument (`tools/cloud_budget/`)

- `budget.gd` hérite du photographe sans le modifier. Une manche locale, les marionnettes, puis deux familles de scènes :
  - **les six cartes livrées** (Arène Standard, Cloître, Usine, Croisée, Bunker, Arène Circulaire) : J1 au centre de sa case
    d'apparition, J2 à 260 px dans le premier cap libre vers le point d'apparition de J2, torches allumées, chacun visant
    l'autre, au pistolet ; immobiles, sans tir. Douze images de chauffe, douze relevées, **la médiane** ;
  - **le pompe sous une fusée**, la mise en scène de `bench_framerate.gd --fusee` (le cas le plus lourd connu, ROADMAP :
    1 % bas 59 à 60 masque allumé, le 2026-09-26) : les deux au pompe à 150 px, qui se tirent dessus sans fin, une fusée en
    pleine braise entre eux, son âge entretenu. Sur l'Arène Standard (la sélection d'un `user://` neuf). 120 images relevées,
    **la moyenne** (voir « Le bruit »).
  - Chacune en **vue unique** puis en **écran scindé** ; un lancement par configuration et par lacet (**0° et 45°**, J2 en
    lacet B au 45°, le défaut du jeu).
- Il relève au total (`RenderingServer.get_rendering_info`) **et par vue** (`Viewport.get_render_info` sur la racine et chaque
  `SubViewport`, passes visible 3D / ombres 3D / canevas 2D). Il ne lit que les vues qui ont **rendu** à cette image : une
  sous-vue arrêtée garde les compteurs de sa dernière image, les lire doublerait un rendu qui n'a pas eu lieu.
- Il compte ce que les compteurs ne voient pas : les objets visibles dont le shader **déclare** la texture d'écran ou de
  profondeur (`#include` résolus, commentaires retirés : chacun fait copier l'écran, qu'il la lise ou non — ROADMAP, « Pièges
  connus », 2026-09-15), les `BackBufferCopy`, les lumières 2D et 3D allumées et celles qui portent une **ombre** (la passe
  d'ombre d'une lumière 2D n'entre pas dans le compteur d'appels).
- `run_budget.sh` enchaîne les lancements sous Xvfb (`--fixed-fps 60`) ; `synthese.py` monte les tableaux.

### La validation de l'instrument, sur les deux chiffres connus

| chiffre connu | qui | ce que l'instrument trouve | journal |
|---|---|---|---|
| tuyaux : passe visible des vues 3D **28 → 29** en vue unique, **50 → 52** en écran scindé (70ffafa) | l'agent des tuyaux | **28 → 29** et **50 → 52**, primitives 5 364 → 25 374 (lui : 5 372 → 25 387) | `journaux/validation_tuyaux_l0.log` |
| le détail des corps coûtait **44 appels** (deux Parasites, avant la fusion D3) | Beauté | à 97fa308 (D1, avant la fusion), Arène Standard : **88 → 132, +44** en vue unique ; +88 en écran scindé (chaque corps dans deux vues) | `journaux/validation_corps_97fa308_*.log` |

La famille `tuyaux` de `budget.gd` refait la mise en scène de `photo_tuyaux.gd` (Cloître, cadrage ×2,5, la face sud la plus
meublée) et cache le nœud des tuyaux dans le même lancement. Et un troisième contrôle, interne : **la somme des vues rendues
égale le total du serveur de rendu** (96 = 96 appels, 1 159 = 1 159 objets au premier essai) — aucune vue oubliée, aucune
comptée deux fois.

### Le bruit

Deux lancements de la même chose ne donnent pas exactement les mêmes comptes : 18f5fdc tel quel et la branche intégrée tous
drapeaux éteints diffèrent de **±3 appels par scène en vue unique, jusqu'à ±7 en écran scindé**, tout entiers dans la
lightmap 2D (deux ou trois petits objets transitoires, 2 à 6 primitives). Au pompe sous une fusée, les appels vont de 144 à 457
d'une image à l'autre ; sur 120 images la médiane bouge d'un lancement à l'autre, **la moyenne se reproduit à ±2 en vue unique
et ±8 en écran scindé** (287,1 contre 287,9 ; 612,6 contre 614,7). **Un écart plus petit que ce bruit n'est pas un écart.**

## Le tableau par configuration

Tableaux complets (les deux lacets, les deux vues, toutes les colonnes) : [`TABLEAUX.md`](TABLEAUX.md), régénérés par
`synthese.py` depuis `journaux/matrice/`. Ici, l'essentiel au **lacet 45° B** (le défaut du jeu) ; le 0° dit la même chose.

**Appels de dessin par image** — six cartes : médiane des six (min–max) ; pompe sous une fusée : moyenne de 120 images
(9e décile, maximum) :

| configuration | drapeau | vue unique, 6 cartes | vue unique, pompe + fusée | écran scindé, 6 cartes | écran scindé, pompe + fusée |
|---|---|---|---|---|---|
| **18f5fdc tel quel** | — | 137,5 (91–150) | 289 (p90 377, max 460) | 255 (176–284) | 618 (p90 734, max 804) |
| intégré, tout éteint (**référence**) | `--sans-fusee-coeur` | 135,5 (91–154) | 290 (p90 380, max 460) | 256 (176–282) | 612 (p90 730, max 792) |
| intégré, défaut (Q34 = C) | — | 136 (91–152) | 290 (p90 381, max 461) | 250 (176–288) | 617 (p90 736, max 794) |
| personnages détaillés | `--corps-detaille` | **148** (103–166) | 294 (p90 384, max 463) | **278** (200–312) | 633 (p90 748, max 876) |
| tuyaux | `--tuyaux-essai` | 135 (92–153) | 292 (p90 380, max 462) | 256 (178–288) | 619 (p90 742, max 794) |
| pochoirs | `--pochoirs-essai` | 136,5 (91–153) | 291 (p90 378, max 460) | 256 (176–288) | 616 (p90 736, max 868) |
| cœur chaud | `--faisceau` | 138,5 (93–156) | 292 (p90 382, max 463) | 259 (180–290) | 629 (p90 744, max 810) |
| mannequin | `--mannequin` | 136,5 (91–154) | 291 (p90 381, max 461) | 256 (176–284) | 620 (p90 736, max 804) |
| masque de la fumée | `--fumee-masque` | 137 (91–153) | 290 (p90 380, max 458) | 252 (176–286) | 619 (p90 736, max 798) |
| rouge long (Q35) | `--fusee-rouge-long` | 135 (91–153) | 291 (p90 381, max 456) | 254 (176–288) | 620 (p90 736, max 870) |
| **tous ensemble** | les sept | **151,5** (106–169) | **297** (p90 386, max 462) | **285** (206–314) | **637** (p90 748, max 816) |

**L'écart de chaque ajout à la référence, carte par carte** (médiane des six cartes ; lacet 0° / 45°), et ce qui ne bouge
jamais :

| ajout | Δ appels, vue unique | Δ appels, écran scindé | Δ primitives par vue 3D | vues, copies d'écran, lumières à ombre | lecture |
|---|---|---|---|---|---|
| personnages détaillés | **+12 / +12** | **+24 / +25** | +528 | inchangées | 6 appels par corps détaillé (Parasite), dans chaque vue qui le voit ; au pompe, +4 à +5 (kit plus petit) |
| tuyaux | +1 / +0,5 | +1 / +2 | **+13 800** (jusqu'à **+20 000** ; ×3) | inchangées | un seul maillage, mais le plus lourd de la scène 3D |
| cœur chaud | +1,5 / +2 | +3 / +7 | +2 par appel | inchangées | exactement +2 appels par vue 3D : un quad par torche (vérifié vue par vue) |
| pochoirs | 0 | 0 | 0 | inchangées | cuits dans le décor : rien par image (même constat que l'agent des pochoirs, 93 / 93) |
| mannequin | 0 | 0 | 0 | inchangées | tout dans le shader des corps |
| masque de la fumée (+ la bande) | 0 | 0 | 0 | **aucune copie d'écran** | tout dans le shader des volumes : **invisible aux compteurs** |
| Q34 = C (le point de braise) | 0 | 0 | 0 | inchangées | un halo de plus sous la fusée, sous le bruit |
| Q35 (rouge long) | 0 | 0 | 0 | inchangées | des durées ; voir « Non prouvé » |
| **tous ensemble** | **+15 / +15** | **+30 / +31** | +14 300 (×3) | inchangées | la somme des parties : corps + tuyaux + cœur chaud, rien de plus |

Tout ce qui est à 0 l'est **au bruit près** (±3 par scène, ±7 en écran scindé). Aucun ajout ne change le nombre de vues
rendues (4 en vue unique, 9 en écran scindé, 5 et 11 sous la fusée), ni les copies d'écran déclarées (2 et 4), ni les
lumières 2D à ombre (6 ; 10,9 et 8,4 en moyenne sous le feu), ni la mémoire vidéo au-delà de ±4 Mo (380 à 392 Mo en vue
unique, 309 à 322 en écran scindé).

## Où va le budget aujourd'hui (la référence, lacet 45°)

**Vue unique, six cartes, ~135 appels** : la lightmap 2D de J1 (1920×1080, le monde 2D que la 3D projette) 17 à 73 selon
la carte, la passe 3D de la racine 47 à 54, le 2D de la racine (interface, voile, brouillage) 25, les deux capteurs des
corps (256×256) 1 chacun. **Écran scindé, ~256** : les deux lightmaps (958×1080), les deux vues iso (3D + 3 appels de
calques chacune), quatre capteurs, la racine 26.

**Le pompe sous une fusée, décomposé** (vue unique, 45°, moyenne de 120 images ; un lancement par geste retiré,
`journaux/decomposition/`) :

| scène | vue unique | écran scindé | lightmap J1, 2D |
|---|---|---|---|
| complète (tir, fusée, torches) | **290** (p90 379) | **620** (p90 738) | 200 |
| sans tir | 110 (p90 116) | 211 | 30 |
| sans fusée | 276 | 592 | 196 |
| sans torches | 275 | 573 | 191 |
| rien de tout ça | 78 | 136 | 14 |

**Le tir fait 62 % de la charge en vue unique, 66 % en écran scindé.** Le recensement (`--recensement`,
`journaux/recensement_pompe_l45.log`) dit qui : sous le feu, **97 à 155 étincelles du `ParticlePool`** vivent dans le monde
2D de la lightmap, chacune un `RigidBody2D` avec son `Polygon2D` et sa `PointLight2D` (éteinte pour la plupart : 12 lumières
allumées en moyenne), et ce monde est dessiné **une fois par lightmap** — deux fois en écran scindé. La fusée coûte 14 appels,
les torches 15. Et le 1 % bas se joue sur les **salves** : la moyenne est à 290, le 9e décile à 380, le maximum à 460.

## Les trois plus gros contributeurs

Parmi ce qui arrive :

1. **Les personnages détaillés** — le seul ajout qui multiplie les appels : +12 par vue (+9 % de la vue unique), +24 en
   écran scindé, +528 primitives par vue ; et, invisible ici, la branche `CORPS_DETAIL` du shader des corps et sa pré-passe
   de profondeur, par pixel de corps.
2. **Les tuyaux** — +1 appel, mais **+13 800 primitives par vue 3D** (jusqu'à +20 000 sur la pire carte ; +40 000 en écran
   scindé) : la géométrie 3D triple. Un coût de sommets, que le GPU à tuiles du Mac paie à chaque vue.
3. **Le masque de la fumée** — zéro appel, zéro copie, et pourtant le seul ajout **déjà mesuré sous la cible** sur le Mac
   (règle 278 échouée, 1 % bas 59 à 60, ~+2 ms ; ROADMAP, ordre 416). Il est premier des risques et dernier des comptes :
   c'est exactement le cas que ce rapport ne peut pas voir.

Et le contributeur qui les domine tous, **déjà là** : les étincelles du pompe (≈180 appels sur 290 sous le feu, ≈410 sur
620 en écran scindé). Tout ajout qui passerait par le monde 2D de la lightmap s'y multiplierait par le nombre de lightmaps.

## Ce qu'il faut mesurer d'abord sur le Mac, dans l'ordre

Toutes au banc de cadence (`bench_framerate.gd`, pompe sous une fusée, `--fusee`, séries en miroir, règle 278), au 45° B :

1. **Le masque de la fumée avec la bande** (`--fumee-masque`, vue unique) contre la référence. La bande (`3155395`) est
   arrivée après la mesure qui a échoué ; elle change le coût par pixel, que rien ici ne voit. C'est le seul ajout dont on
   sait qu'il peut faire tomber le 1 % bas sous 60, et la réponse décide Q31. Si elle échoue encore, la série qui tranche
   l'hypothèse de la copie de l'usure (masque allumé contre éteint, les deux `--sans-usure`) suit.
2. **Tous ensemble sans le masque** (`--corps-detaille --tuyaux-essai --pochoirs-essai --faisceau --mannequin
   --fusee-rouge-long`, vue unique) contre la référence : l'empilement réel de ce qui attend. Compté ici : +7 appels en
   moyenne sous le feu, +10 400 primitives. Si le 1 % bas tient, le reste de la liste ne sert qu'à répartir.
3. **Les personnages détaillés seuls** (`--corps-detaille`), vue unique puis **écran scindé** : le seul ajout qui ajoute
   des appels dans chaque vue, plus un coût de shader par pixel de corps, et celui qui doit devenir le défaut (Q33).
4. **Les tuyaux seuls** (`--tuyaux-essai`) en **écran scindé**, sur l'Usine ou la Croisée (les pires cartes : +40 000
   primitives) : le seul coût de géométrie de la liste.
5. Le reste (cœur chaud, mannequin, pochoirs, Q34, Q35) seulement si la mesure 2 montre un prix que 3 et 4 n'expliquent
   pas : ensemble, ils ne comptent que +2 appels par vue 3D.

Et une mesure qui manque au dossier : **l'écran scindé sous le feu**, pour la référence elle-même. 620 appels en moyenne,
738 au 9e décile — le double de la vue unique — et aucun chiffre de cadence dans la ROADMAP pour ce cas.

## Les fusions, et comment les conflits ont été tranchés

Trois branches fusionnées DANS `claude/cloud-budget`, jamais l'inverse :

- `origin/iso12-corps` (`f38e5f7`) — un conflit dans `docs/ROADMAP.md` : la date d'en-tête (la plus récente gardée) et deux
  pièges connus ajoutés au même endroit (les deux gardés).
- `origin/iso11-menus` (`3155395`) — deux conflits. **`iso_volumes.gd`** : les deux côtés réécrivaient les défauts. Le
  masque de la fumée reste **éteint** (côté `integration-iso14`, ordre 416, postérieur à `iso11-menus` qui l'allumait
  encore) ; le cœur de la fusée passe à 2 (côté `iso11-menus`, Q34 = C, décision d'Adrien). Les deux commentaires gardés,
  chacun avec sa variable. `docs/ROADMAP.md` : le piège du glissement en diagonale gardé.
- `origin/claude/cloud-tuyaux` (`70ffafa`) — un conflit dans `docs/ROADMAP.md` : deux sections ISO13 au même endroit
  (Q33 et les tuyaux), les deux gardées.
- Les corrections du photographe sous Xvfb (`0c67705`) appliquées en commit à part.

Contrôle : la branche intégrée tous drapeaux éteints rend les mêmes comptes que 18f5fdc tel quel, au bruit près (tableau
ci-dessus) — aucun des trois ne coûte quoi que ce soit tant que son drapeau est éteint.

## Pièges découverts (à reporter dans la feuille de route)

- **Une sous-vue arrêtée garde les compteurs de sa dernière image.** `Viewport.get_render_info` sur une `SubViewport` en
  `UPDATE_DISABLED` répond ce qu'elle a rendu la dernière fois qu'elle a rendu. Sommer toutes les vues compterait deux fois
  les lightmaps et les vues iso de l'écran scindé après un retour en vue unique. Règle : ne lire que les vues qui ont rendu,
  et le **prouver** par la somme (elle doit égaler `RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`).
- **Zéro appel n'est pas gratuit.** Le masque de la fumée ne change aucun compte (ni appel, ni primitive, ni copie d'écran)
  et coûte ~2 ms sur le Mac. Un budget compté dit ce qui s'ajoute au processeur et à la géométrie ; le coût par pixel ne se
  voit qu'au banc de cadence.
- **Au pompe, la médiane ment d'un lancement à l'autre ; la moyenne sur 120 images tient** (287,1 contre 287,9). Les appels
  vont de 144 à 460 d'une image à l'autre, au rythme des salves ; et c'est le haut de cette distribution qui fait le 1 % bas.
- **Un Godot lancé sur un script qui ne compile pas ne se ferme jamais.** Il imprime l'erreur et attend. Un lancement fantôme
  a tourné une heure et demie à côté de la matrice. `run_budget.sh` a désormais un plafond (`timeout`).
- **`pgrep -f motif` dans une boucle d'attente se trouve lui-même** dès que la ligne de commande de la boucle contient le
  motif : attente infinie. Attendre sur un fichier (le nombre de lignes « code » écrites), jamais sur `pgrep`.
- **Sous llvmpipe, lancer en parallèle n'accélère rien** : chaque Godot prend ~3,5 cœurs sur 4 ; trois lancements
  simultanés durent trois fois plus longtemps chacun.

## Signalé, hors de ma tâche (non corrigé)

- `miroirs_iso.gd:237` — le capteur d'objet de la vue 1 prend un nom automatique (`@SubViewport@1466`, qui change à chaque
  lancement) quand on passe de la vue unique à l'écran scindé avec une fusée posée : le nouveau capteur naît pendant que
  l'ancien, de même nom (`CapteurObjetVue1_<objet>`), n'est pas encore libéré. Sans effet sur le rendu (aucun RPC ne passe
  par lui). Reproduire : `budget.tscn -- --scenes=pompe` puis lire la vue `Presentation3D/@SubViewport@…` du relevé
  `scinde`.
- `particle_pool.gd` — chaque étincelle est un objet 2D à part (`RigidBody2D` + `Polygon2D` + `PointLight2D`), jusqu'à 200
  actives ; sous le feu elles font ~62 % des appels de l'image. Ce n'est pas un défaut ; c'est le plus gros poste du budget,
  et celui qu'un chantier de cadence regarderait en premier (un seul maillage multiple pour toutes, par exemple). Non touché.

## Suite

SUITE_A_REMPLIR

## Ce que je n'ai PAS pu prouver

- **Aucune cadence.** Pas un chiffre d'images par seconde de ce rapport n'est une mesure ; le cloud ne tient que les comptes.
- **Aucun coût par pixel** : le masque et sa bande, le mannequin, la branche `CORPS_DETAIL`, le shader du cœur chaud, le
  halo de Q34. Tous sont à zéro ou presque dans les comptes et peuvent coûter cher sur le Mac.
- **Q35 (rouge long) n'est probablement pas exercé** : la scène du pompe tient l'âge de la fusée dans la braise, en boucle
  (la boucle du banc de cadence) ; ce que Q35 change — la durée du plein feu et du rouge — n'est peut-être jamais à l'écran.
  Son zéro ne vaut que pour ce que la scène montre.
- **Les copies d'écran sont des déclarations comptées, pas des copies observées.** En écran scindé, deux voiles
  d'éblouissement déclarent la texture d'écran sur la même racine : Godot en fait-il une copie ou deux ? Le compteur ne le
  dit pas. Et le voile compté est la variante qui LIT l'écran, parce que les deux joueurs se font face torche allumée (un
  duel) ; dos à dos, ce serait la variante calme.
- **Les passes d'ombre des lumières 2D** : je compte les lumières qui portent une ombre (6 ; ~11 sous le feu), pas le coût de
  leur passe, qui n'entre pas dans le compteur d'appels.
- **Les pochoirs** : leur drapeau ne laisse aucune trace dans les comptes (cuits dans le décor) ; je n'ai pas vérifié à
  l'image qu'ils étaient posés dans ces lancements-ci.
- **La carte du banc de cadence sur le Mac** : j'ai pris l'Arène Standard (la sélection d'un `user://` neuf) ; le banc joue
  la carte sélectionnée sur le poste.
- **Le coût processeur des appels** : un appel de dessin ne coûte pas le même prix au pilote d'Apple et à Mesa.

## Les images

`captures/` : ce qui a été compté, au 45° B, pour la référence et pour « tous ensemble » — le Cloître et le pompe sous une
fusée, en vue unique et en écran scindé (JPEG, qualité 85, prises sous llvmpipe : valables pour ce qui est dessiné, pas
pour l'éclat).

## Tout refaire

```bash
# Outillage (une fois) : Godot 4.7 officiel en /usr/local/bin/godot, Xvfb, puis
godot --headless --path . --import

# La matrice : une configuration par argument, deux lacets (≈ 4,5 min par lancement, seul sous llvmpipe)
TOUS="--corps-detaille --tuyaux-essai --pochoirs-essai --faisceau --mannequin --fumee-masque --fusee-rouge-long"
./tools/cloud_budget/run_budget.sh /tmp/budget/m "eteint=--sans-fusee-coeur" "defaut=" "corps=--corps-detaille" \
    "tuyaux=--tuyaux-essai" "pochoirs=--pochoirs-essai" "faisceau=--faisceau" "mannequin=--mannequin" \
    "masque=--fumee-masque" "rouge-long=--fusee-rouge-long" "tous=$TOUS"
# 18f5fdc tel quel : un worktree à 18f5fdc, les corrections du photographe appliquées, tools/cloud_budget/ copié, puis
PROJET=/chemin/du/worktree ./tools/cloud_budget/run_budget.sh /tmp/budget/m "base18f5fdc="
python3 tools/cloud_budget/synthese.py /tmp/budget/m --reference=eteint > docs/iso/cloud/budget/TABLEAUX.md

# La décomposition du pompe
LACETS=45 SCENES=pompe ./tools/cloud_budget/run_budget.sh /tmp/budget/decomp "complet=--sans-fusee-coeur" \
    "sans-tir=--sans-fusee-coeur --pompe-sans-tir" "sans-fusee=--sans-fusee-coeur --pompe-sans-fusee" \
    "sans-torches=--sans-fusee-coeur --pompe-sans-torches" \
    "rien=--sans-fusee-coeur --pompe-sans-tir --pompe-sans-fusee --pompe-sans-torches"

# La validation sur les tuyaux (28 → 29, 50 → 52)
xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/cloud_budget/budget.tscn -- \
    --no-eos --lacet=0 --config=valid-tuyaux --scenes=tuyaux --tuyaux-essai
# La validation sur les corps (+44) : un worktree à 97fa308, même préparation, puis --scenes=cartes --cartes=default,
# avec et sans --corps-detaille.

# Le recensement de ce qui dessine, et les images
xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/cloud_budget/budget.tscn -- \
    --no-eos --lacet=45 --config=recensement --scenes=pompe --images-pompe=30 --recensement --sans-fusee-coeur
xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/cloud_budget/budget.tscn -- \
    --no-eos --lacet=45 --config=tous --scenes=cartes,pompe --cartes=map_001_le_cloitre --images-pompe=30 \
    --captures=/tmp/budget/captures $TOUS
```

## Les fichiers

- `tools/cloud_budget/budget.gd`, `budget.tscn` — l'instrument ; `run_budget.sh` — la matrice ; `synthese.py` — les tableaux.
- `docs/iso/cloud/budget/TABLEAUX.md` — tous les tableaux ; `journaux/` — les lignes `BUDGET` de chaque lancement
  (`matrice/`, `decomposition/`, validations, recensement), d'où `synthese.py` refait les tableaux à l'identique.
- `docs/iso/cloud/budget/captures/` — les images.
