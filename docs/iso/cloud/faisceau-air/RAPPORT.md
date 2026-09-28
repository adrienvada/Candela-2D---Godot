# Le faisceau visible dans l'air, sans salir le noir (Q41) — rapport de la session cloud « faisceau-air »

> Branche `claude/cloud-faisceau-air`, partie de `origin/claude/cloud-masque-fumee` (`b5af7b6`), 2026-09-28, à partir de
> 02:10 (Paris). **État : fait côté cloud.** Un essai derrière `--faisceau-air`, ÉTEINT par défaut ; sa garde ; les prises à
> 45° B et à 0°, en vue unique et en écran scindé ; la question d'équité à l'image ; la planche. **Rien ne change par
> défaut.** La cadence reste à mesurer sur le Mac.

## Pour Adrien, en cinq lignes

1. **Le rayon peut revenir sans salir le noir** : dans toutes mes prises, il n'allume **aucun** pixel noir. Il reste sous la
   hauteur des murets et ne montre jamais plus de lumière que le sol n'en reçoit.
2. **Mais il ne ressemble pas aux illustrations.** Là-bas, le faisceau est une lame de lumière plus claire que tout le reste.
   Ici, avec tes règles, il ne peut être qu'**un voile qui ternit la tache de lumière** : le cœur du cône s'assombrit
   (de 14 à 19 sur 255 à la densité essayée), les dalles claires et sombres se rapprochent, des stries suivent la visée ; au
   bord du cône, il ne change presque rien (moins d'un sur 255).
3. **Il ne dit rien de plus à l'adversaire** : on ne le voit que par-dessus le sol déjà éclairé par la lampe, jamais à côté.
   Qui voit la tache voit déjà d'où vient la lumière et où elle va.
4. **Je ne te conseille pas de le rouvrir tel quel** : il se lit, mais comme de la brume grise sur ta lumière, pas comme
   un faisceau. Un vrai faisceau lumineux demanderait d'ajouter de la lumière dans l'air, ce que la règle « rien de plus
   clair que le sol » interdit aujourd'hui. C'est à toi de dire si cette règle peut bouger pour le faisceau.
5. **Sa vitesse n'est pas mesurée** : il ajoute un juge et trois couches par lampe allumée (comptés ci-dessous) ; seul ton
   Mac dira ce que ça coûte.

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
   mot pour mot : `_suivre_faisceau` ne pose toujours aucune couche. Le rayon vit dans `_suivre_faisceau_air`, que seul le
   nouveau drapeau appelle. Les deux se combinent.
2. **Les couches sous les murets** : 0,12 / 0,24 / 0,36 tuile (au lieu de 0,15 / 0,30 / 0,45), toutes sous 0,40. Gardé par
   la suite, dans la constante ET sur les nœuds posés.
3. **Le masque pochoir, TOUJOURS, pour le rayon seul** : ses couches portent la forme pochoir (compacte, bande resserrée,
   stencil) et leur juge, quel que soit l'état du masque de la fumée (éteint par défaut depuis le 26/09). La fumée n'en est
   pas touchée (son shader reste celui que ses propres drapeaux décident) et la bascule des bancs (`poser_masque_fumee`)
   saute le rayon. La variante imposée ne touche pas `_shader_masque`, qui nomme la variante de la FUMÉE et que ses
   filtres reconnaissent ; `_formes_posees` suffit (et la recopie du contact des corps, par image, s'ouvre aussi quand
   seules des formes imposées sont posées).
4. **La densité, cherchée à l'image** : `--faisceau-air=<densité>` la force ; la constante vaut 0,45 (la plus forte du
   24/09), retenue pour la planche.

**La règle « rien de plus clair que la surface qui le porte »**, appliquée à un rayon dans l'air : la couche ne montre que
la lightmap lue sous elle, passée dans la même pâte, sans gain. Vérifié à l'image : le plus clair du rayon ne dépasse jamais
le plus clair du sol du même cône sans lui (§ 3).

## 2. Le code

| fichier | quoi |
|---|---|
| `iso_volumes.gd` | `DRAPEAU_FAISCEAU_AIR`, `VOLUME_FAISCEAU_AIR` (0,36 tuile, 3 couches, 0,45), `CLE_FAISCEAU_AIR`, `faisceau_air`, `densite_faisceau_air`, `_suivre_faisceau_air`, `densite_du_faisceau_air` ; `_couches(e, n, forme)` et `_materiau_volume(forme)` pour une forme imposée ; `_poser_forme_imposee` ; le juge posé aussi pour une entrée à forme imposée ; `poser_masque_fumee` saute le rayon |
| `tools/test_iso_gadgets.gd` | `_le_faisceau_air_dans_le_texte` et `_le_faisceau_air_en_iso` (le vrai chemin, lampe de J1 tenue comme le banc la tient) |
| `tools/loupe_faisceau_air.gd`, `tools/loupe.gd` | le plan `loupe-faisceau-air` du photographe |
| `tools/faisceau_air/preuve.py`, `planche.py` | le jugement des prises, la planche |

**La garde** (`godot --headless --path . --script res://tools/test_iso_gadgets.gd`, 178 vérifications, verte) : le
drapeau éteint par défaut ; sur le vrai chemin, lampe de J1 allumée, **drapeau éteint : aucune couche posée** ; allumé :
trois couches, la plus haute à 12,6 px < 14,0 px (les murets), la texture de la lampe, le pochoir sur les couches et le juge
qui l'écrit, les lightmaps des deux vues, la bascule du masque de la fumée sans effet sur le rayon ; la lampe éteinte, le
rayon part. **Preuve par mutation** : `suivre()` qui pose le rayon sans le drapeau (`if faisceau_air:` → `if true:`) fait
rougir deux contrôles (« seul le drapeau l'appelle », « drapeau ÉTEINT, lampe allumée : aucune couche posée »).

## 3. Les preuves à l'image

**La mise en scène** (`loupe-faisceau-air`) : le Cloître, J1 à 3,5 tuiles au sud du pilier, J2 à 3 tuiles à l'ouest de J1 ;
LED des murs figées (`--led-murs-fige`), aucune fusée, aucun gadget ; **une seule lampe allumée par bloc**, la respiration
de la torche figée ; la scène tenue jusqu'à ce que les caméras, les éblouissements et l'énergie des lampes ne bougent plus
au bit près (trente pas de suite ; tenue dans les six blocs, en 35 à 154 pas) ; la caméra de J1 posée. Dans chaque bloc, le
rayon basculé sur place : **A (sans rayon) cinq fois** — deux avant, une au milieu, deux après — et **B** aux densités 0,15,
0,30, 0,45, 0,80. Critère écrit d'avance (`preuve.py`) : là où les cinq A sont noires (0,0,0), chaque B l'est ; les pixels
où les A diffèrent entre elles (dilatés d'un pixel) sont l'ensemble instable, exclu et compté.

### 3a. Le noir — 45° B (lacet J1 45°, J2 regarde depuis le côté opposé)

| bloc | ce qu'on juge | pixels noirs dans les A (le zéro n'est pas vide) | fuite à 0,15 / 0,30 / 0,45 / 0,80 |
|---|---|---|---|
| `adv` | le rayon de J2 vu par J1 (vue unique, J1 lampe éteinte) | 904 820 | **0 / 0 / 0 / 0** |
| `s1` | écran scindé, lampe de J1 : la moitié de J2 | 526 053 (tous chez J2) | **0** (0,45) |
| `s2` | écran scindé, lampe de J2 : la moitié de J1 | 272 532 (tous chez J1) | **0** (0,45) |
| `eq-est`, `eq-sud-ouest` | J2 au nord du pilier, lampe allumée, J1 lampe éteinte | 899 407, 924 486 | **0**, **0** (0,45) |
| `sien` | son propre rayon (vue unique, lampe de J1) | **0** : le voile d'éblouissement de sa propre torche (0,06) relève tout l'écran | non jugeable au noir |

**0° (lacet 0, J2 en A)** : voir § 3a bis (ajouté à la fin de la séance).

Le propre rayon d'un joueur ne peut pas se juger au noir : sa torche l'éblouit à 0,06 et le voile soulève tout son écran
(aucun pixel noir, ni avec ni sans le rayon). C'est pour cela que le rayon est jugé **vu de l'autre** : en vue unique (J1
voit le rayon de J2) et en écran scindé, où la moitié non éblouie voit le rayon de l'autre (J2 voit celui de J1 en `s1`,
J1 voit celui de J2 en `s2`) — les deux sens, donc.

### 3b. La densité : ce qui se lit, et comment

Mesurée sur l'image, parmi les pixels que le rayon change et que le sol éclaire (A ≥ 8/255) : le **cœur** est le quart le
plus clair du sol sans rayon, le **bord** le quart le plus sombre. B − A sur le canal le plus fort, en /255.

| 45° B | densité | cœur du cône (sol ≈ 135/255) | bord du cône (sol ≈ 30/255) | pixels changés | le plus clair : rayon / sol |
|---|---|---|---|---|---|
| `adv` (J2 vu de J1) | 0,15 | **−6,0** | +0,4 | 55 616 | 229 / 230 |
| | 0,30 | **−10,4** | +0,6 | 65 631 | 229 / 230 |
| | 0,45 | **−14,0** | +0,8 | 71 014 | 229 / 230 |
| | 0,80 | **−20,8** | +1,1 | 77 827 | 229 / 230 |
| `s1` (J1 vu des deux moitiés) | 0,45 | −18,6 | +0,9 | 105 229 | 230 / 255 |
| `s2` (J2 vu des deux moitiés) | 0,45 | −15,9 | +0,9 | 97 575 | 230 / 242 |
| `sien` (J1, voile compris) | 0,45 | −20,9 | +0,8 | 26 905 | 229 / 231 |

**Ce que ça veut dire** : le rayon se lit, dès 0,30, mais **comme un voile qui assombrit la tache de lumière**, pas comme
une lumière. Les dalles claires du cône foncent, les dalles sombres s'éclaircissent un peu (médiane de B − A entre −1 et 0,
90e centile +1 à +2), et des stries parallèles à la visée apparaissent (les trois disques de couches, décalés en hauteur,
vus par la caméra inclinée). Au bord du cône, là où le sol est déjà sombre, il ne change presque rien (< 1,3/255).

**Pourquoi, par construction** : une couche montre la lightmap LISSÉE sous elle (moyenne sur 18 % du rayon, soit ~55 px
pour une torche), passée dans la pâte, **sans la matière du sol** ; elle se mélange au sol avec son opacité. Le sol, lui,
montre la lightmap nette × sa matière (dalles, joints, taches). Mélanger les deux ramène donc le sol vers la moyenne de la
lumière : ce qui est plus clair que la moyenne fonce, ce qui est plus sombre s'éclaircit — jamais au-delà de la lumière
elle-même. Un faisceau comme ceux des illustrations, plus clair que le sol qu'il traverse, demande d'**ajouter** de la
lumière dans l'air ; la règle « rien de plus clair que la surface qui le porte » l'interdit. Aucune densité ne changera
ce sens : de 0,15 à 0,80, le cœur ne fait que foncer davantage.

**La symétrie** : le rayon de J2 vu de J1 (`adv`, −14,0 au cœur) et celui de J1 vu de J2 (`s1`, −18,6 ; la moitié de J2
seule n'a pas été isolée) ont le même signe, la même allure et zéro fuite ; l'écart tient au sol sous chaque cône (J1 et J2
ne visent pas le même carrelage). Le code est le même pour les deux (une couche lit la lightmap de la caméra qui la dessine,
gardé par la suite) ; la symétrie au pixel près n'est pas prouvée (voir « non prouvé »).

### 3c. Le bruit des prises

- **La poussière de faisceau du jeu (V5.5)** : un grain clair de quelques pixels, posé au hasard dans le cône par
  `player.gd`, apparaît dans certaines prises (ex. 42 → 192/255 en `adv-b15` à (800, 269), ailleurs en `b30`, absent
  ensuite). Ce n'est pas le rayon : à 0,15 d'opacité, un mélange ne peut pas monter 42 au-delà de 74. Il explique les
  « max » isolés de B − A (156, 109, 86). Il ne tombe jamais sur le noir (il est dans le cône).
- **La vue éblouie** (sa propre lampe allumée) varie d'une prise à l'autre sur toute la moitié : 367 000 à 1 278 000
  pixels instables en `s1`, `s2`, `sien` — les moitiés non éblouies, elles, tiennent.

## 4. L'équité : un rayon dans l'air dit-il où l'on vise ?

**La question** : un faisceau visible dans l'air dit-il à l'adversaire où l'on vise, au-delà de ce que dit déjà la tache
de lumière au sol ?

**La réponse, par construction et à l'image : non.** Le rayon ne se dessine que là où ce que le pixel montre derrière lui
est déjà éclairé (le masque pochoir) ; il ne peut donc apparaître que **par-dessus la tache de lumière**, jamais à côté.
Mesuré : dans les deux prises d'équité (J2 au nord du pilier, lampe allumée vers l'est puis vers le sud-ouest, J1 lampe
éteinte), **0 pixel noir allumé** sur 899 407 et 924 486 ; le rayon change 75 000 à 79 000 pixels, tous dans la tache.
Qui voit la tache voit déjà d'où part la lumière (la pointe du cône est à la lampe) et où elle va (l'axe du cône). Le rayon
y ajoute des stries parallèles à la visée : **la même information, redite**, pas une nouvelle.

Ce qu'il n'ajoute pas, et qu'un rayon *sans* masque ajouterait : de la lumière au-dessus d'un sol noir (derrière un mur,
dans l'ombre d'un pilier, au-delà d'un muret) — ce qui dessinerait la lampe d'un joueur qu'on ne voit pas. Le 24/09, c'était
150 à 310 pixels ; ici, 0. Et parce que ses couches restent sous les murets, il ne dépasse pas d'un muret plus que le sol.

**Ce que l'image ne montre pas bien** : à 45° B, le pilier ne cache pas le corps de J2 à la caméra de J1 (J2, dans le noir
mais au bord de sa propre lumière, se devine au coin du pilier dans les A comme dans les B) : la prise dit « J2 dans le noir,
lampe allumée », pas « J2 derrière un mur ». Cela ne change pas la réponse : la règle est tenue pixel par pixel, où que soit
J2.

## 5. Les comptes de dessin (outil de la session Budget)

Voir § 5 bis (ajouté à la fin du relevé).

## 6. La planche

`planche.html` (dans ce dossier, autonome, images en chemins relatifs sous `img/`) : les neuf illustrations à faisceau
(accueil, amical, amical en ligne, compétitif, créer / rejoindre en local — la même image —, écran scindé, et trois
planches de l'intro : allumage, dotation, prix) ; puis, par lacet et par bloc, le jeu sans le rayon et avec, la différence
×8, la carte du noir (rouge : fuite — il n'y en a pas), les loupes ×3 au milieu du cône, et les quatre densités.

## Refaire

```bash
# Godot 4.7 (Linux), Xvfb ; une fois : godot --headless --path . --import ; pip install numpy pillow
# La garde :
godot --headless --path . --script res://tools/test_iso_gadgets.gd
# Les prises (≈ 25 min chacune sous llvmpipe) — 45° B, puis 0° :
GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" env GODOT=/usr/local/bin/godot \
  ./tools/run_photos.sh --plan=loupe-faisceau-air --led-murs-fige > r45.log 2>&1
cp ~/.local/share/godot/app_userdata/Candela\ 2D/photos/loupe/*.png photos45/
GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" env GODOT=/usr/local/bin/godot \
  ./tools/run_photos.sh --plan=loupe-faisceau-air --led-murs-fige --lacet=0 --lacet-j2=A > r0.log 2>&1
# Le jugement, puis la planche :
python3 tools/faisceau_air/preuve.py photos45 r45.log p45 45B_
python3 tools/faisceau_air/preuve.py photos0 r0.log p0 0A_
python3 tools/faisceau_air/planche.py docs/iso/cloud/faisceau-air "45° B=p45" "0° A=p0"
# Les comptes de dessin (outil de origin/claude/cloud-budget, tools/cloud_budget/, non commité ici) :
GODOT=/usr/local/bin/godot LACETS="45 0" SCENES=cartes ./tools/cloud_budget/run_budget.sh budget "defaut=" "air=--faisceau-air"
python3 tools/cloud_budget/synthese.py budget
# Sur le jeu : godot --path . -- --faisceau-air      (ou --faisceau-air=0.3 pour une autre densité)
```

⚠️ Toujours regarder la première image d'une séance (un `user://` neuf joue l'intro par-dessus) : ici, la séance est
partie d'un `user://` où l'intro était déjà vue ; première image vérifiée, c'était bien la scène.

## Ce que je n'ai PAS pu prouver

- **Le coût.** Le rayon ajoute, par lampe allumée, un juge et trois couches (§ 5) ; leur prix en millisecondes ne se lit
  que sur le Mac. Il faudrait la série en miroir du banc (pompe sous une fusée, `--faisceau-air` contre rien), avec la règle
  des 3 %.
- **Le rayon de celui qui le porte, jugé au noir** : son propre voile d'éblouissement ne laisse aucun pixel noir dans sa
  vue. Le même code est jugé vu de l'autre, dans les deux sens ; pas vu de soi.
- **La symétrie au pixel près** entre le rayon de J1 et celui de J2 : les deux ont zéro fuite et la même allure, mais ils
  ne sont pas posés sur le même sol ; une mise en scène en miroir de la carte le prouverait.
- **Un joueur caché derrière un mur** : à 45° B, le pilier ne cache pas J2 à la caméra de J1 ; la règle (rien hors de la
  tache) est prouvée, pas l'image « lampe d'un joueur invisible derrière un mur ».
- **Le stencil sous le pilote d'Apple** : il marche sous Mesa (déjà vu par la session « masque-fumée ») ; pas vérifié sur
  le Mac. Si le stencil ne marchait pas là-bas, le rayon y salirait le noir comme le 24/09 : une prise
  `loupe-faisceau-air` sur le Mac le dirait en une demi-heure.
- **Sur d'autres cartes, avec des murets, avec la fumée d'une fusée** : une seule carte (le Cloître, sans muret).
- **Le mouvement** : la lampe qui tourne, le joueur qui court — le cloud ne vaut pas pour les gestes.

## Pièges découverts (à reporter dans la feuille de route)

1. **Un rayon qui lit la lumière sous lui, sans gain, ne peut que TERNIR la tache qu'il couvre.** Mélangé au sol, il le
   ramène vers la moyenne lissée de la lumière : le cœur fonce (−14/255 à 0,45), le bord ne bouge pas. Un faisceau
   « comme l'illustration » (plus clair que son sol) est incompatible avec la règle « rien de plus clair que la surface qui
   le porte » : c'est la règle qu'il faudrait rouvrir, pas la densité.
2. **La respiration de la torche (±3 %, `TORCH_BREATH_AMP`) empêche une scène de se tenir** : une mise en scène qui attend
   l'immobilité de l'énergie des lampes attend pour toujours. Figer son horloge (`_torch_breath_t`) dans l'outil.
3. **Le cône éclairé est plus étroit que le demi-angle de l'arme** : un point posé à 85 % de `torch_angle_deg` tombe hors
   de la lumière (la texture de la lampe s'éteint avant). Lire le bord du cône sur l'image, pas sur l'angle.
4. **La poussière de faisceau du jeu (V5.5) pose des grains clairs au hasard** : deux prises « identiques » peuvent différer
   de plus de 100/255 sur quelques pixels du cône. Un écart isolé dans la lumière se vérifie sur plusieurs prises.
5. **Son propre rayon ne se juge pas au noir** : sa torche éblouit son porteur (0,06), et le voile relève toute sa vue.
   Juger une image de lampe depuis l'AUTRE joueur (vue unique de l'autre, ou la moitié non éblouie de l'écran scindé).
