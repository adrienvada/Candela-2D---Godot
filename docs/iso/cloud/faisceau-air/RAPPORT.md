# Le faisceau visible dans l'air, sans salir le noir (Q41) — rapport de la session cloud « faisceau-air »

> Branche `claude/cloud-faisceau-air`, partie de `origin/claude/cloud-masque-fumee` (`b5af7b6`), 2026-09-28, à partir de
> 02:10 (Paris). **État : plan écrit, code en cours.** Rien ne change par défaut.

## 1. Ce que j'ai relu, et ce que j'en reprends (écrit AVANT de coder)

**Le code retiré.** `d8e928a` (ISO13, lot E, 24/09 01:04) posait le rayon par `_suivre_faisceau` dans `iso_volumes.gd` :
un volume ordinaire (`VOLUME_FAISCEAU` : hauteur 0,45 tuile, 3 couches, densité 0,08), centré sur la lampe, de rayon la
demi-largeur de la texture de la torche × son échelle, **masqué par la texture de la lampe elle-même** (`lampe.texture`,
tournée de `lampe.global_rotation`), densité × `energy / 2,5`. `4afbc3c` (02:14) l'a retiré, ne laissant sous `--faisceau`
que le cœur chaud à la lampe, et a réécrit la garde de `tools/test_iso_gadgets.gd` : **aucune couche** sur le chemin du
drapeau `--faisceau`.

**Pourquoi il a été retiré (mesures du 24/09, `docs/iso/iso13/plan_lots_d_e.md`)** : 1 à 3/255 de médiane dans le cône à
0,08 / 0,22 / 0,45 ; 150 à 310 pixels isolés allumés dans le noir dès 0,22 ; et une hauteur de 0,45 tuile, au-dessus des
murets (0,40), qui rendait à la lampe une hauteur que la décision d'Adrien du 2026-09-15 lui refuse.

**Ce qui a changé depuis** : la fuite dans le noir vient surtout du **lissage** de la lightmap lue par la couche, pas
seulement de la parallaxe (établi le 24/09 au soir) ; et le masque de la fumée sait taire une couche là où ce que le pixel
MONTRE derrière elle s'affiche noir — en particulier sa forme **pochoir** (`--fumee-masque-pochoir`, session
« masque-fumée », 27/09) : un juge par volume pose la question une fois par pixel et écrit le stencil ; les couches ne se
dessinent pas là.

**Ce que je reprends, tel quel :**
- la forme du rayon = **la texture de la lampe** (le cône ne peut pas diverger de la lumière, il suit l'arme et la portée) ;
- les couches ordinaires de `volume_iso.gdshader`, qui lisent la lightmap **de la caméra qui les dessine** (équité J1/J2,
  la couche ne montre que la lumière que ce joueur a le droit de voir) ;
- le grain de l'alpha animé par `age` comme poussière (pas de particule, pas d'objet de plus) ;
- la densité × `energy / 2,5` : la lampe éteinte ou en fondu, le rayon suit ;
- le drapeau lu dans `IsoVolumes._init()` sur les arguments utilisateur (porte au jeu, au banc, au photographe).

**Ce que je change, et pourquoi :**
1. **Un drapeau neuf, `--faisceau-air`**, distinct de `--faisceau` (le cœur chaud seul). La garde de `4afbc3c` reste vraie
   mot pour mot : `_suivre_faisceau` ne pose toujours aucune couche. Le rayon vit dans une fonction à lui, que seul le
   nouveau drapeau appelle.
2. **Les couches sous les murets** : les trois couches à 0,12 / 0,24 / 0,36 tuile (au lieu de 0,15 / 0,30 / 0,45), donc
   toutes sous 0,40. Gardé par la suite (la plus haute couche < `MapGeometry.HAUTEUR_MUR_BAS`).
3. **Le masque pochoir, TOUJOURS, pour le rayon seul** : ses couches portent la forme pochoir (compacte, bande resserrée,
   stencil) et leur juge, quel que soit l'état du masque de la fumée (éteint par défaut depuis le 26/09). La fumée n'en est
   pas touchée : son shader reste celui que ses propres drapeaux décident, et la bascule des bancs
   (`poser_masque_fumee`) ne touche pas au rayon. C'est la forme la moins chère des trois, et la seule qui ne paie la question
   qu'une fois par pixel.
4. **La densité, à chercher à l'image** : `--faisceau-air=<densité>` la force (comme `--faisceau=0.22` le faisait), pour la
   chercher au photographe sans recompiler ; la valeur retenue revient dans la constante. Je dirai de combien /255 le rayon
   change l'écran au milieu du cône et au bord.

**La règle « rien de plus clair que la surface qui le porte »**, telle que je l'applique à un rayon dans l'air : la couche ne
montre que la lightmap lue sous elle, passée dans la même pâte, sans gain ; je vérifie à l'image qu'aucun pixel du rayon ne
dépasse le plus clair du sol éclairé du même cône sans rayon.

## 2. Le plan

| étape | quoi | preuve |
|---|---|---|
| 2 | `--faisceau-air`, éteint ; couches sous 0,40 ; forme pochoir forcée ; densité réglable | garde de `test_iso_gadgets.gd` éteinte (aucune couche) et allumée (couches sous les murets, pochoir, texture de la lampe) ; suite complète verte |
| 3 | un plan du photographe, `loupe-faisceau-air` : toutes lumières éteintes sauf UNE lampe, LED figées, caméra posée ; A (sans rayon) plusieurs fois, B (rayon) à plusieurs densités ; J1 et J2 ; 45° B et 0° ; vue unique et écran scindé | 0 pixel noir dans toutes les A et allumé dans B ; la loupe contient du noir (le zéro n'est pas vide) ; densité au milieu et au bord du cône en /255 ; comptes de dessin (outil Budget) |
| 4 | l'équité : J2 hors de vue de J1, lampe allumée ; ce que voit J1 sans l'essai et avec | images côte à côte, et la différence |
| 5 | la planche : illustrations à faisceau / jeu sans / jeu avec, 1:1 et loupe ×3 | `planche.html` |

La cadence ne se mesure pas ici (rendu logiciel) : elle restera à mesurer sur le Mac, et je le dirai.
