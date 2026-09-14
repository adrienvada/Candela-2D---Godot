# Murs bas et accroupi — note de conception (étape MB0)

> Chantier **murs bas et accroupi**, vue de dessus, sur `main`. Né du jalon H15 de la
> vue isométrique (2026-09-14), mais c'est du gameplay : il vaut quel que soit l'aspect
> final du jeu, et il **précède** ISO1, qui extrudera cette géométrie.
>
> Étape MB0, session « Murs bas Opus », 2026-09-14. Rien du jeu n'est modifié :
> `tools/murs_bas_geometrie.gd`, `tools/proto_murs_bas.{tscn,gd,gdshader}`,
> `tools/test_murs_bas.gd`, cette note. MB1 à MB3 ne commencent pas sans un mot d'Adrien.

## Les règles d'Adrien (2026-09-14), mot pour mot

- Un mur bas arrête la lumière mais laisse voir une tête debout.
- Un accroupi derrière un mur bas n'est pas éclairé depuis l'autre côté, mais il l'est
  par une lumière venue de son côté.
- Balles et lumière debout franchissent le mur bas selon **un même angle** : un
  accroupi loin derrière redevient visible et touchable.
- On enjambe un mur bas avec « croix », lentement et en faisant du bruit.
- La torche d'un accroupi bute sur le mur.
- L'accroupi ralentit fortement, étouffe les pas, et se lit à sa silhouette plus une
  marque HUD pour soi.

Et les deux règles qui priment : **noir absolu**, **équité hôte-autoritaire** (ce qui
se voit est ce qui se paie).

---

## 1. La géométrie

Un rayon — de lumière ou de balle — tiré par une source **plus haute que le mur**
passe par-dessus et redescend derrière lui selon l'angle `α`. À la distance `x` de la
face de sortie, **mesurée le long du rayon**, il est à la hauteur `h − x · tan α`. D'où,
pour une cible de hauteur `c` :

    L(c) = (h_bas − c) / tan α        (0 si c ≥ h_bas)

| Ce qui est derrière le mur | Hauteur `c` | Caché sur | Aux valeurs proposées |
|---|---|---|---|
| le sol | 0 | `L_sol = h_bas / tan α` | **2,99 tuiles** (105 px) |
| un accroupi | `h_accroupi` | `L_accroupi = (h_bas − h_accroupi) / tan α` | **1,49 tuile** (52 px) |
| une tête debout | `h_debout ≥ h_bas` | 0 | jamais cachée |

Trois conséquences qui se lisent dans la formule :

- **`L` ne dépend pas de la distance entre la source et le mur.** C'est ce que « un
  même angle » veut dire. Un modèle physique (source à hauteur `H`, cible à `c`, zone
  `d · (h − c)/(H − h)` — la formule de la section ISO de la ROADMAP) ferait varier la
  bande avec la distance du tireur : illisible, et un joueur ne voit pas `d`. La règle
  d'Adrien choisit la bande constante ; le prototype l'applique.
- **Une source qui ne dépasse pas le mur ne franchit jamais**, à aucune distance :
  c'est « la torche d'un accroupi bute ». La hauteur d'une source est celle de la
  posture de son porteur (`h_debout` ou `h_accroupi`) : pas de cinquième constante.
- **Plusieurs murs bas sur un même rayon** : caché s'il existe UN mur traversé dont la
  sortie est à moins de `L` de la cible. L'ordre des murs n'y change rien (vérifié).

Une seule fonction décide : `franchit(source, cible, h_source, h_cible, murs_bas, h_bas, α)`
dans `tools/murs_bas_geometrie.gd`. `visible()` y ajoute les murs hauts, qui arrêtent
tout. **La lumière (shader) et la balle (`resoudre_tir`) l'interrogent toutes les
deux.**

### Les valeurs proposées, et pourquoi

| Constante (tuiles) | Proposée | Pourquoi |
|---|---|---|
| `HAUTEUR_MUR_HAUT` | **1,25** | Plus haut qu'une tête : « ne laissent rien passer » se lit aussi en iso. N'entre dans aucun calcul 2D (un mur haut arrête tout). |
| `HAUTEUR_MUR_BAS` | **0,5** | Un demi-corps debout : en iso (52°), la bande cachée par la boîte n'est que de 0,39 tuile (14 px), sous le rayon d'un corps (18 px). |
| `HAUTEUR_ACCROUPI` | **0,25** | La moitié du mur : c'est ce rapport qui fixe `L_sol / L_accroupi = 2`. |
| `HAUTEUR_DEBOUT` | **1,0** | Au-dessus du mur bas, donc tête jamais cachée ; source debout au-dessus du mur. |
| `ANGLE_FRANCHISSEMENT` | **9,5°** | Le chiffre qui donne les deux longueurs ci-dessous. **Ce n'est pas le tangage de la caméra** (52°). |
| vitesse accroupie | **×0,45 = 117 px/s** | « Fortement » : moins de la moitié. Traverser l'arène standard accroupi prend plus de 2 fois plus longtemps. |
| enjambement | **×0,25 = 65 px/s** | « Lentement » : ~1,1 s pour un mur d'une tuile d'épaisseur, corps compris. |

**`L_accroupi` ≈ 1,5 tuile** : collé au mur (le corps accroupi fait 26 px de diamètre),
on est caché ; reculer de deux tuiles, c'est se montrer à qui est debout de l'autre
côté. La cachette existe, mais elle se paie en mobilité. **`L_sol` ≈ 3 tuiles** : une
bande d'ombre derrière chaque mur bas, de largeur constante — c'est **elle** qui dit
« mur bas » dans le noir, là où un mur haut projette une ombre qui ne finit pas. Plus
large, elle avale un couloir ; plus étroite, elle ne se voit plus.

Les cinq valeurs se règlent à chaud dans le prototype (touches `1` à `8`), chaque
changement imprimé avec les deux longueurs qui en résultent.

---

## 2. Chaque règle dans la simulation

| Règle | Collision | Lumière | Balle | État répliqué | Rejeu / killcam | Son | HUD |
|---|---|---|---|---|---|---|---|
| Mur bas arrête la lumière, pas la tête | mur bas **solide** pour les corps | sol : zone morte `L_sol` ; tête debout : rien | passe au-dessus d'un debout | — | — | — | — |
| Accroupi caché de l'autre côté, vu du sien | — | corps accroupi : zone morte `L_accroupi`, jugée **en son centre** | idem, même fonction, même centre | **posture** | posture enregistrée à 60 Hz | — | — |
| Même angle, accroupi loin redevient visible | — | au-delà de `L` : éclairé | au-delà de `L` : touché | posture à l'instant compensé | idem | — | — |
| Enjamber avec « croix » | traversée du mur bas, **65 px/s** | l'enjambeur est **debout** | ne tire pas (proposition § 6) | **enjambement** (bit) | bit enregistré | bruit d'enjambement | — |
| Torche accroupie bute | — | occluder **plein** du mur bas, sur son bit, dans le masque des lumières basses | canon accroupi : la balle s'arrête sur le mur bas | posture | — | — | — |
| Accroupi ralentit, étouffe, se lit | — | silhouette plus petite et ronde | rayon de corps 13 au lieu de 18 | posture | silhouette rejouée | pas **−22 dB / portée 0,30** (debout −13 / 0,60) | marque « accroupi », **pour soi seul** |

**Un corps se juge en son centre, pour la lumière comme pour la balle.** Le sol se juge
pixel par pixel (c'est un décor), un corps en entier ou pas du tout : sinon un
accroupi à cheval sur la limite serait à moitié visible et entièrement intouchable, ou
l'inverse — deux vérités. Le shader reçoit donc le centre du corps en uniforme.

---

## 3. Le point dur : une ombre finie en 2D — trois pistes, départagées au pixel

Un `LightOccluder2D` projette une ombre infinie. Et un `CanvasItem` reçoit l'ombre d'une
lumière **en entier ou pas du tout** : `shadow_item_cull_mask` filtre les occluders ET
les sprites qui reçoivent l'ombre (Pièges connus, 2026-09-14). On ne peut donc pas dire
nativement « ce corps subit les murs hauts mais pas les murs bas ».

Le prototype rend une scène fixe, lit l'écran, et compare point par point à
`visible()` — la vérité qui fait payer la balle. **Mesuré le 2026-09-14** (fenêtre
2560×1440, premier plan, quatre scènes, ~4 000 points de sol et 8 centres de corps) :

| Piste | Principe | Sol | Corps | Verdict |
|---|---|---|---|---|
| **A — natif** | murs bas = occluders sur leur bit, dans le masque de toute lumière | 97,0 % | **5/8** | deux vérités |
| **B — polygones finis** | zone morte calculée depuis la torche, posée en occluder | 96,9 % | **5/8** | deux vérités |
| **C — analytique** | zone morte calculée dans `light()`, murs bas en uniformes | **100 %** (4 007/4 007) | **8/8** | **une vérité — retenue** |

- **A** : ombre infinie derrière le mur, donc l'accroupi à `L + 12` reste noir (règle 3
  cassée) ; et pour que la tête debout reste visible, le corps debout ne doit recevoir
  l'ombre de rien — il est alors **éclairé derrière un mur haut** et sous une torche
  accroupie qui devrait buter. Trois écarts de corps sur huit, mesurés.
- **B** : exactement les mêmes écarts que A. **Un occluder de profondeur finie projette
  une ombre infinie** : sa fin n'existe pas pour la carte d'ombre. Et même finie, elle
  aurait deux défauts : les occluders sont communs à toutes les lumières (le polygone
  calculé pour une torche ombre toutes les autres), et le corps debout garde le problème
  de A.
- **B′ — trois lumières** (une sans murs bas, une avec, une soustractive sur les fins
  de zone) : écartée **avant d'être écrite**. La décomposition `T + L_mur − L_fin` ne
  sait ombrer que derrière le PREMIER mur d'un rayon ; derrière un second mur en série,
  le sol reste éclairé (`tools/test_murs_bas.gd`, « deux murs bas sur le même rayon »,
  garde le cas). Et elle triple les lumières d'un jeu déjà proche du plafond de quinze
  par item.
- **C** : les murs hauts gardent leurs occluders natifs ; les murs bas n'ont d'occluder
  que pour les lumières **basses** (torche accroupie) ; la zone morte des lumières hautes
  est calculée par le matériau qui reçoit la lumière, depuis `LIGHT_POSITION` et
  `LIGHT_VERTEX` (espace écran), avec la même méthode des dalles que la géométrie. Les
  corps sont tous ombrés normalement par les murs hauts. **Une seule vérité.**

### Ce que coûte C

Mesuré dans le prototype, une torche plein écran, cadence déplafonnée pour la mesure
(au premier passage, le plafond de 120 donnait 8,33 ms dans les huit configurations et
cachait tout), **ordre de grandeur, pas un relevé au protocole** :

Trois passages, 240 images chacun, à quelques minutes d'écart :

| Arêtes de murs bas (rectangles) | 0 (0) | 12 (3) | 40 (10) | 160 (40) |
|---|---|---|---|---|
| Appels de dessin, A et C | 14 | 17 | 24 | 54 |
| Image médiane, A | 1,71 / 1,67 / — ms | 1,90 / 1,85 / 1,68 ms | 1,84 / 2,97 / 1,83 ms | 3,11 / 2,96 / 3,26 ms |
| Image médiane, C | 1,76 / 1,81 / 2,98 ms | 1,88 / 2,07 / 1,94 ms | 2,77 / 2,74 / 2,70 ms | 4,32 / 6,81 / 4,38 ms |

- **Le shader n'ajoute aucun appel de dessin** : les appels suivent le nombre de
  polygones dessinés, pareils en A et en C.
- **À 10 rectangles, il coûte de l'ordre de 0,9 ms** par lumière plein écran (C − A :
  +0,93, −0,23, +0,87 ms) — du même ordre que le bruit du prototype, qui fait varier A
  seul de 1,83 à 2,97 ms. **À 40 rectangles, il se voit à chaque passage** : +1,2, +3,9,
  +1,1 ms (le second porte un 1 % bas de 25 fps, donc au moins un accroc). Le temps GPU n'est pas mesurable ici
  (`viewport_get_measured_render_time_gpu` rend 0 en `gl_compatibility`) : le chiffre sort
  de la durée d'image, sur une machine où d'autres sessions travaillent.
- **C'est le risque de MB3**, pas un détail : le coût est `lumières × pixels reçus ×
  rectangles`, et le jeu a par joueur torche, rétrodiffusion, halo, flash, plus fusées,
  mines, braises. Trois parades, à mesurer au banc `tools/banc_murs_bas.tscn` avant de
  choisir : (1) ne pousser au matériau que les murs bas proches de la vue (le shader
  boucle sur `nb_murs`, pas sur 64) ; (2) ne donner le shader qu'aux receveurs qui en ont
  besoin — les copies de sol et les sprites de corps, jamais les murs, le décor, le HUD ;
  (3) une texture de données en grille si une carte dépasse une vingtaine de rectangles
  bas après fusion.

### ⚠️ Deux écarts de 3 px qui existaient avant ce chantier

Les occluders du jeu sont rentrés de 3 px (`MapGeometry.OCCLUDER_INSET`), la collision
non. Pour la **lumière**, la vérité est donc le rectangle rentré ; pour la **balle**, la
tuile entière. Le contrôle d'accord de C a d'abord relevé 12 puis 4 écarts de sol, tous
des rayons rasant un coin à moins de 3 px (mur haut, puis bout de mur bas sous une torche
accroupie) ; ils ont disparu quand la vérité de la lumière a pris le rectangle rentré.
**Le même écart existe aujourd'hui dans le jeu entre le faisceau et la balle aux coins
des murs.** Hors périmètre : signalé, pas corrigé. MB3 doit décider si la balle rase
l'occluder ou la tuile — et le dire dans le test d'équité.

---

## 4. Ce que MB1 à MB3 touchent, et à qui le demander

Le partage se fait **par fichier** (`docs/JOURNAL_SESSIONS.md`). La table de ce journal
est datée : vérifier qui tient quoi le jour où l'étape s'ouvre (`ListAgents`).

| Étape | Fichier | Ce qu'on y fait | Tenants connus au 2026-09-14 |
|---|---|---|---|
| MB1 | `map_codec.gd` | format **v4** : une cellule « mur bas », import v3 et codes de partage inchangés, garde-fou de décompression conservé | libre ; `Protocol.WIRE_WITNESS` lit la version du codec → l'empreinte bouge |
| MB1 | `map_geometry.gd` | `Kind.LOW_WALLS`, ses rectangles fusionnés, sa couche de collision, ses occluders sur leur bit ; **les quatre hauteurs et l'angle** | lu par ISO1 (`iso-geometrie`) : **contrat § 5** |
| MB1 | `map_editor*.gd`, `map_thumbnail.gd`, `map_gallery.gd` | pinceau, HUD, vignette, dessin | `map_gallery.gd` au domaine « menus » |
| MB1 | `canaux_lumiere.gd` | la couche d'ombre `MUR_BAS` (un bit libre de la seconde famille ; aujourd'hui 1, 2, 4-8 corps, 16-32 torses) | chantier CLASSES l'a créé |
| MB2 | `input_setup.gd`, `liaisons.gd` | `p1_accroupir` / `p2_accroupir`, clavier et manette, menu de liaisons | ordre `InputSetup` avant `GameSettings` à respecter |
| MB2 | `input_provider.gd`, `local_input_provider.gd`, `network_input_provider.gd` | `is_crouch_pressed()` | session « Allumage torche » a touché les deux premiers |
| MB2 | `player.gd` | posture prédite, corrigée, vitesse, silhouette, rayon | domaine « game feel » ; **chantier CLASSES** y écrit |
| MB2 | `protocol.gd`, `tools/test_protocole.gd` | **`VERSION` 17 → 18** | CLASSES (partagé) ; ISO9 le montera aussi |
| MB2 | `game_state.gd` | état de l'hôte, compensation de latence (posture dans l'historique) | **`iso-pilote`** le tient dans le plan ISO ; CLASSES |
| MB2 | `replay_system.gd` | posture et enjambement dans `record_frame` | killcam : CLASSES lot F |
| MB2 | `audio_manager.gd`, `tools/banc_audio.tscn` | pas accroupis, bruit d'enjambement | DA3 / game feel |
| MB2 | `ui.gd` (bloc HUD) | marque « accroupi » pour soi | **`iso-pilote`** ; CLASSES |
| MB3 | `bullet.gd` | balistique à deux hauteurs par `franchit()` | game feel ; CLASSES (`obstacle_avant`) |
| MB3 | matériaux de sol et de corps (`*.gdshader`, `arena_decor.gd`, `mur_encre.gd`) | le test de zone morte dans `light()` | game feel ; « Refonte graphique » |
| MB3 | `eblouissement.gd`, `game_state.gd:_ligne_de_vue_depuis` | éblouissement par-dessus un mur bas | CLASSES (repris) |
| MB3 | `mur_led.gd` | le bandeau LED des murs bas (§ 6) | chantier bandeau LED |

---

## 5. Le contrat avec ISO1

ISO1 extrude `merge_rects(build_grid(data, Kind.WALLS))` en boîtes de hauteur `H_haut`,
et extrudera `Kind.LOW_WALLS` en boîtes de hauteur `H_bas` dès que l'énumération
existera. Donc, **au moment de MB1** :

- l'énumération s'appelle **`MapGeometry.Kind.LOW_WALLS`** ;
- les hauteurs vivent en **un seul endroit**, `map_geometry.gd`, en constantes exprimées
  en **tuiles** : `HAUTEUR_MUR_HAUT`, `HAUTEUR_MUR_BAS`, `HAUTEUR_ACCROUPI`,
  `HAUTEUR_DEBOUT` — plus `ANGLE_FRANCHISSEMENT`, qui n'est pas une hauteur mais vit à
  côté pour la même raison ;
- **rien d'autre de l'interface de `map_geometry.gd` ne change de forme** : les ajouts
  sont des ajouts, `build_grid(data, Kind.WALLS)` rend la même chose qu'aujourd'hui ;
- aucune fusion dans `iso-geometrie` : quand `main` portera MB1, la session ISO1 fusionne
  `main` elle-même.

En MB0 ces noms existent déjà, avec ces valeurs, dans `tools/murs_bas_geometrie.gd` ; MB1
les déménage, et `murs_bas_geometrie.gd` les lira de là.

---

## 6. Les questions ouvertes d'ISO0.b — une proposition chacune

1. **Éblouissement par-dessus un mur bas.** L'œil est à la hauteur de la posture. Un
   debout ébloui par une torche debout de l'autre côté d'un mur bas : **oui, plein
   coefficient** (les têtes se voient). Un accroupi dans la zone morte : **pas ébloui**
   (il ne voit pas la lampe, et elle ne le voit pas). Une torche accroupie : **n'éblouit
   jamais au travers** (elle bute). Soit : `_ligne_de_vue_depuis` appelle `franchit()`
   avec `h_cible = hauteur de l'œil`. Aucun nouveau coefficient.
2. **Tir pendant l'enjambement.** **Refusé**, et la torche garde son état. L'enjambeur
   compte **debout** (visible, touchable, rayon 18) pendant les ~1,1 s de la traversée,
   à 65 px/s. C'est ce qui rend l'enjambement coûteux sans le rendre injouable ; tirer en
   enjambant ferait du mur bas un tremplin.
3. **Killcam.** Posture et enjambement enregistrés à 60 Hz (deux bits par image) ; les
   fantômes rejouent la **silhouette** accroupie et la zone morte avec la posture
   rejouée. **Pas de marque HUD** en killcam : elle est « pour soi », et la killcam montre
   le point de vue du mort.
4. **Dessin d'un mur bas en vue de dessus.** Comme un mur haut : **invisible dans le
   noir**, révélé par la lumière seulement. Sous la lumière : dessus **hachuré**, à 80 %
   de la valeur d'un mur haut, filament d'encre de 2 px au lieu de 3. **Et sa bande
   d'ombre finie** — 3 tuiles derrière lui, puis le sol se rallume — le distingue d'un mur
   haut sans aucun dessin de plus. **Pas de bandeau LED** sur un mur bas : c'est une
   lumière au ras du sol, qui éclairerait l'accroupi collé au mur — la cachette brillerait.
5. **Hauteurs.** `h_bas` 0,5, `h_accroupi` 0,25, `h_debout` 1,0, `h_haut` 1,25 tuile ;
   `α` 9,5°, soit `L_sol` 3 tuiles et `L_accroupi` 1,5 tuile ; accroupi ×0,45 ;
   enjambement ×0,25 (§ 1).

---

## 7. Ce que MB0 a mesuré

Tout est rejouable : `proto_murs_bas.tscn -- --no-eos --auto` imprime les lignes
`NOIR_ABSOLU`, `ACCORD`, `COUT` puis sort.

- **Noir absolu** : toutes lumières éteintes, HUD, guide et traçante coupés, un corps
  debout et un accroupi en scène contre un mur bas — **max 0/255** sur l'image 2560×1440,
  pour les trois pistes.
- **Accord rendu / vérité** : § 3. Piste C, passage final : sol 4 007/4 007, corps 8/8,
  154 points écartés parce qu'à moins de 6 px d'une frontière de la vérité (la carte
  d'ombre y a sa propre résolution). Il a fallu trois passages : 12, puis 4, puis 2
  écarts, tous au retrait de 3 px des occluders (§ 3), aucun dans la règle.
- **Coût** : § 3.
- **Suite headless** `tools/test_murs_bas.gd` : 83 contrôles, vus rougir une fois
  (sabotage de la comparaison de zone morte dans `franchit()`), puis remis.

## 8. Lancer le prototype

    /Applications/Godot.app/Contents/MacOS/Godot --path "<worktree>" res://tools/proto_murs_bas.tscn -- --no-eos

| Touche | Effet |
|---|---|
| Z Q S D (W A S D en QWERTY) | déplacer l'acteur contrôlé |
| Tab | changer d'acteur : porteur de torche → cible debout → cible accroupie |
| C | accroupi / debout (l'acteur contrôlé) |
| Espace tenu | « croix » : enjamber le mur bas qu'on pousse |
| clic gauche | tir du porteur vers le curseur (résultat imprimé) |
| clic droit | poser l'acteur contrôlé sous le curseur |
| F | torche allumée / éteinte |
| 1 / 2 | `h_bas` − / + |
| 3 / 4 | `h_accroupi` − / + |
| 5 / 6 | `α` − / + |
| 7 / 8 | vitesse accroupie − / + |
| P | piste A / B / C |
| G | guide : bords des zones mortes attendues (bleu : sol, orange : accroupi) |
| N / V / M | contrôle du noir / de l'accord / mesure du coût |
| H | HUD |
| Échap | quitter |
