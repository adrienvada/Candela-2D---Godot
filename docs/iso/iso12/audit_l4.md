# ISO12 — AUDIT DE L4 EN MODE A, avant toute ligne de code (2026-09-23)

Les fusées, les flashs de tir, les braises, la mine et les lampes des gadgets sous la lumière 3D
bridée, **sans ombres portées** (mode A, celui du GO réduit). Même méthode que l'audit L1 d'Iso 1 :
ce que le brief demande, ce qui existe déjà, ce qui manque, et ce qui doit se mesurer avant d'être
codé. Lu sur `f49c627` (tête d'Iso 1 après L1).

## 1. Ce que le brief demande

Que chacune de ces sources éclaire la scène 3D comme sa Light2D éclaire la vue de dessus : même
position, même hauteur, même couleur, même extinction — « ni plus, ni moins que la 2D ». En mode A,
aucune ombre portée : `ombres_3d` est éteint, donc tout l'arbitrage d'ombres (omni, torches seules,
vue unique) est hors sujet pour L4.

## 2. Ce qui existe DÉJÀ — et c'est l'essentiel

**Le miroir couvre les cinq sources depuis le lot 0.** La liste fermée de `lumieres_iso.gd` contient
déjà le halo des fusées, la lueur des braises, l'embrasement de la mine, le faisceau de la torche
fantôme, son halo de rétrodiffusion, et le flash de tir de chaque joueur (plus leurs doubles de
killcam). **Aucune source de gadget ne manque** : le recensement du 2026-09-23 l'a confirmé en
lisant les onze fichiers `gadget_*.gd` — seuls braises, mine et torche fantôme portent une lampe,
le « repère » d'un gadget étant un `Line2D` non éclairé.

**La v27 leur donne le relief**, comme aux torches, par le même dénominateur normalisé.

**Et les quatre correctifs L4 du 2026-09-23 sont déjà appliqués** (écrits par Gadgets, posés par
Iso 1 dans `f49c627`) : portée 3D en sphère (`sqrt(rayon² + h²) × 1,15`), ε par lampe
(`min(h/portée, ε global)`), flash de tir sans ombre, et l'interrupteur d'énergies neutres.

## 3. La question que L1 a soulevée, vérifiée pour les omni : PAS DE COUTURE

L1 a montré que le vrai défaut des torches n'était pas le miroir mais sa COUVERTURE : hors du cône
3D, aucune lampe n'éclaire, la garde du relief rend R = 1, et sur une face le relief SAUTE au bord
du cône — une couture tracée par la 3D là où la 2D éclaire d'un trait. D'où le plancher de cône
porté de 45° à 75°.

**La même vérification, faite pour les cinq sources de L4, ne trouve aucune couture** — parce que le
correctif de portée de ce matin la prévenait sans qu'on l'ait cherchée. Pire point : le bord du
disque 2D, en haut d'un mur haut (1,25 tuile = 43,75 px).

| source | h (px) | rayon 2D | portée 3D | pire distance | marge |
|---|---|---|---|---|---|
| flash de tir (bout de l'arme voxel) | 21,0 | 32 | 44,0 | 39,3 | **+4,8** |
| flash de tir (repli debout) | 35,0 | 32 | 54,5 | 33,2 | +21,4 |
| fusée en vol (au lancer) | 52,5 | 80 | 110,0 | 80,5 | +29,6 |
| fusée posée | 5,25 | 220 | 253,1 | 223,3 | +29,7 |
| braises | 1,75 | 170 | 195,5 | 175,1 | +20,4 |
| mine | 1,75 | 260 | 299,0 | 263,4 | +35,6 |
| halo de la torche fantôme | 21,0 | 128 | 149,2 | 130,0 | +19,2 |

Toutes couvertes, murets compris (marges de +11 à +39 px).

## 4. Ce qui MANQUE

**(a) Aucune garde ne protège cette couverture.** L1 a laissé `tools/test_iso_torches3d.gd`
(174 lignes) pour que le cône des dix classes ne puisse plus se découvrir en silence. **Rien
d'équivalent n'existe pour les omni** : un changement d'empreinte 2D (`EMPREINTE_LUMIERE`,
`RAYON × 5`, `EMPREINTE_FLASH`…) ou de hauteur de source rouvrirait la couture sans que rien ne
rougisse. C'est le principal livrable de L4, et il est bon marché.

**(b) La marge du flash est fine : +4,8 px sur 44.** Et elle dépend de la hauteur du BOUT DE L'ARME,
qui bouge : `VoxelCorps` baisse le canon de 52° quand le joueur enjambe (`ANGLE_ARME_BAISSEE`). À
calculer sur les postures extrêmes avant de conclure, pas sur la posture de repos.

**(c) Les poids n'ont jamais été rejugés depuis la v27.** `energie_par_type` donne 52 aux omni de
gadget contre 3,6 aux torches ; depuis la v27 ce n'est plus une luminosité mais un POIDS entre
lampes dans la moyenne pondérée. La ROADMAP le parque explicitement (« elles seront rejugées une
fois le relief en place ») et L1 le confirme en notant que l'élargissement du cône change « le POIDS
de la torche face aux autres lampes ». **C'est la seule question de L4 qui puisse changer l'image**,
et elle se juge sur une planche, pas sur un chiffre.

**(d) Les preuves rouge et bleu n'ont jamais tourné avec des braises, une mine ou une torche fantôme
à l'écran.** Mes lueurs additives (comète, lueur posée, tapis de braises, lentille, éclair de mine)
ne passent ni par la bride ni par le relief : elles recopient l'énergie d'une lumière 2D, ce qui est
légitime, mais l'instrument de preuve peut les compter comme du rouge. Si L4 fait rougir la preuve,
c'est peut-être là, et ce ne sera pas la lumière 3D.

**(e) La fumée reste plate** (option (a), arbitrée par la session cloud le 2026-09-23) : le volume
iso recopie la lightmap et ne prend pas le relief. À juger sur planche, pas à coder.

## 5. Ce qu'il faut MESURER avant de coder

1. **La couverture aux postures extrêmes** (flash, canon baissé) — calcul hors machine, comme L1.
2. **Les poids**, sur une planche : une fusée et une torche qui se rencontrent, `energie_par_type`
   telle quelle contre toutes les énergies à 1,0 (l'interrupteur existe déjà : `--energies-neutres`).
   La question est de savoir si le triangle du cône revient là où une fusée l'écrase.
3. **Les preuves rouge et bleu**, avec braises, mine et torche fantôme en scène, sur les deux cartes.
4. **La cadence**, en mode A, avec une mine à l'embrasement et deux fusées : le pire cas d'omni du
   jeu, jamais mesuré. ⚠️ Sur machine calme et **hors des cinq premières secondes** : le banc mesure
   dans sa propre chauffe (voir `mesure_fusee.md`).

## 6. Ce que L4 toucherait

`lumieres_iso.gd` (poids, marges de couverture), une suite neuve `tools/test_iso_omnis3d.gd`, et
`tools/banc_lumiere3d.gd` pour les cadrages de preuve. **Pas** `iso_volumes.gd` ni les shaders de
volume, tant que la fumée reste plate. Croisement avec Iso 1 : les deux premiers fichiers sont les
siens ; la suite neuve est à moi.
