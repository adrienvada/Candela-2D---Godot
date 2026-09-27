# Le budget de rendu de ce qui arrive — rapport de la session cloud « budget »

> Branche `claude/cloud-budget`, partie de `origin/integration-iso14` (`18f5fdc`). Ouvert le 2026-09-27 à 01:10 (Paris).
> **État : en cours** — l'instrument est validé, la matrice tourne. Ce fichier sera complété.

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
