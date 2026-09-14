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
dans `murs_bas.gd`, classe `MursBas` (née `tools/murs_bas_geometrie.gd` en MB0, entrée dans
le jeu en MB3a). `visible()` y ajoute les murs hauts, qui arrêtent
tout. **La lumière (shader) et la balle (`resoudre_tir`) l'interrogent toutes les
deux.**

### ✅ Les valeurs fixées par Adrien au prototype — H-MB0, 2026-09-14, 18 h 50

Réglées à chaud pendant sa partie, relues dans ses dernières lignes `REGLAGE` :

| Constante | Proposée | **Fixée** | Ce que ça donne |
|---|---|---|---|
| `HAUTEUR_MUR_BAS` | 0,5 | **0,40** | — |
| `HAUTEUR_ACCROUPI` | 0,25 | **0,10** | — |
| `HAUTEUR_DEBOUT` | 1,0 | **1,00** (inchangée) | — |
| `ANGLE_FRANCHISSEMENT` | 9,5° | **13,5°** | — |
| `L_sol` | 2,99 tuiles | **1,67 tuile** (58 px) | la bande d'ombre derrière le mur |
| `L_accroupi` | 1,49 tuile | **1,25 tuile** (44 px) | la cachette |
| vitesse accroupie | ×0,45 | **×0,25** (65 px/s) | — |
| `HAUTEUR_MUR_HAUT` | 1,25 | **1,25** — non réglable au prototype, reste la proposition | — |

**Ce que le parcours de réglage dit, plus que les chiffres.** Adrien a d'abord abaissé le
mur jusqu'à 0,30, puis l'a remonté à 0,40 ; il a creusé l'accroupi jusqu'à 0,05 avant de
revenir à 0,10 ; il a monté l'angle jusqu'à 18° puis l'a redescendu à 13,5° ; et il a
essayé l'accroupi à ×0,10 avant de s'arrêter à ×0,25. Le résultat garde une cachette
proche de la proposition (1,25 tuile au lieu de 1,5), mais **divise par deux la bande
d'ombre au sol** (1,67 au lieu de 3). Le rapport entre les deux passe de 2 à 1,33.

**Trois conséquences, dont deux tranchées par Adrien le même soir :**

1. **L'accroupi va aussi vite que l'enjambement** : 65 px/s tous les deux. ✅ **Égalité
   assumée** (Adrien) : enjamber ne coûte pas plus que marcher accroupi,
   `FACTEUR_ENJAMBEMENT` reste à 0,25.
2. **La bande d'ombre ne suffit plus à dire « mur bas »** : à 1,67 tuile, elle dépasse à
   peine la cachette. Le dessin du mur bas porte donc davantage la lisibilité. ✅ **Dessin
   gardé tel que proposé** (§ 6.4) : hachures, invisible dans le noir, pas de LED.
3. **Un accroupi de 0,10 tuile, c'est 3,5 px de haut** si ISO1 et ISO3 extrudent cette
   constante telle quelle : un corps presque plat en vue iso. Le contrat dit « une seule
   source » ; il faudra peut-être séparer la hauteur de JEU de celle du VOXEL. Question pour
   la session ISO, pas bloquante pour MB1.

### Les valeurs proposées avant H-MB0, et pourquoi (historique)

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

En MB0 ces noms existaient déjà dans `tools/murs_bas_geometrie.gd` ; MB1 les a déménagés
dans `map_geometry.gd`, et la règle — devenue `murs_bas.gd`, classe `MursBas`, en MB3a — les
lit de là.

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

## 9. MB1 — le mur bas entre dans la carte (ouverte par Adrien le 2026-09-14)

### Le monde de MB1 : tout le monde est debout

Tant que la posture n'existe pas (MB2), personne n'est plus bas qu'un mur bas. La règle
d'Adrien donne alors, sans approximation : **un mur bas arrête les corps, et ni la
lumière ni les balles** — un rayon debout passe par-dessus, et la zone morte qu'il laisse
derrière (MB3) ne cache que ce qui est accroupi, c'est-à-dire personne. MB1 n'a donc rien
à tricher ni rien à désactiver : il livre exactement la règle, dans un monde où `L = 0`
pour tous. Ce qui manque encore n'est pas faux, c'est absent : on ne peut pas encore
enjamber (on contourne), ni s'accroupir.

### Ce qui est livré

| Pièce | Ce qu'elle fait |
|---|---|
| `map_codec.gd` **v4** | clé `low_walls` en runs ; `migrate_v3_to_v4` (liste vide) ; une v3 — fichier ou code de partage — s'importe telle quelle ; `get_low_wall_cells` ; refus propre si `low_walls` n'est pas une chaîne ; on n'apparaît pas sur un mur bas, mais un mur bas ne coupe pas une zone (on l'enjambe) ; garde-fou de décompression inchangé et testé |
| `map_geometry.gd` | `Kind.LOW_WALLS` ajouté **après** `WALLS` et `PITS` ; les **quatre hauteurs et l'angle** en constantes (contrat ISO1) ; `LOW_WALL_LAYER = 16` dans `PLAYER_MASK`, **absent de `BULLET_MASK`** ; troisième corps `MursBas` dans `build_collisions`, ses occluders sur `CanauxLumiere.COUCHE_OMBRE_MUR_BAS = 64` ; une case de mur haut l'emporte ; une case de mur bas n'est jamais une fosse |
| `canaux_lumiere.gd` | `COUCHE_OMBRE_MUR_BAS` : le bit qu'une lumière **basse** activera (MB2-MB3). Aucune ne le porte en MB1 |
| `candela_tileset.gd` | la tuile `LOW_WALL_ATLAS` (1, 1) : hachures diagonales sur noir — en fondu additif, rien ne se voit sans lumière |
| `mur_encre.gd` | le contour des murs bas, **2 px** au lieu de 3, sans hachures au pied |
| `map_thumbnail.gd` | les murs bas entre le sol et les murs, dans une couleur intermédiaire |
| `map_data.gd` | `extract_from_layers` / `apply_to_layers` gagnent un calque de murs bas **optionnel, en dernier** : un appelant d'avant les murs bas ne perd rien |
| `game_state.gd` (`rebuild_arena`) | le calque `CustomLowWalls`, ses deux copies par vue, sa purge |
| éditeur (`map_editor.gd`, `map_editor_tools.gd`) | l'étape **« MURS BAS »** entre MURS et APPARITION J1 ; poser un mur haut efface le mur bas de la case et inversement, **dans la même transaction** (annuler rend les deux) ; miroir, rétrécissement et « tout effacer » les couvrent |
| `protocol.gd` | **`VERSION` 17 → 18** et nouveau témoin : le codec de carte fait partie du fil |
| `tools/cartes/murs_bas_essai.json` | la carte d'essai : l'arène standard et cinq murets (22 cases). **Hors** des cartes livrées, en lecture seule |

### Pourquoi `Protocol.VERSION` monte en MB1 et pas en MB2

Le prompt le plaçait en MB2 (la posture sur le fil). Mais `tools/test_protocole.gd` lit
la version du codec de carte dans l'empreinte du fil, et une carte voyage d'un jeu à
l'autre (étape 8.8) : un jeu v17 refuserait une carte v4. La v17 est publiée ; le numéro
monte donc dès que le codec change. MB2 cumulera sous 18 tant qu'aucun tag ne l'aura figé.

### Jouer la carte d'essai

Dans la galerie de cartes, **coller ce code de partage** (MB1, 2026-09-14) :

    CANDELA-H4sIAAAAAAAAE1WRzW7TQBSFX8WaFUhTNPfY4/hnRRHLbiisI7cx1JKbVLZDgKoSD8ET8iTcmXu6IIn05eRaJ9+deXbDeXs4La5zHx6G4zaNS3Hz5dNtcf3+tnhzcy1vnXf3yzhs42F/3u71OQTUV6G5CuVniV2MXQl95ut8yi2lLz3qvvSVIRpqw87QGFqDBFJIkGwSVgm7hGXCNmGdsA/sA/vAPrAP7AP7wD6wD6lPV/q2TIf9Ov0aXffsfjjd813w7qd9efFuOui+QV93+tbn59NlfxnmedWf1aXxsdfVWi8J6ZMpJBKrtEzVJ9M0TxQSpO7VN8k56l8ch0e1cR/XdZiKv7//FI/nZS3uhlVn69NwOe6fhLY1ZaXOspyCU8T/x9s0j9y1zKPv47JOp6PrqpRe1wo++BK9uhpg0Evv0WYEvfgcqhyihZhDbaHOYWdhl0NjocmhtdDmoEeVU2Y+PotiEYywSBExE6GKmItQRsxGqCPmIxQSMxIqiTkJpcSsQCuYFWgFswKtYFagFcwKtIJZgVYwK9AKZgVawaxAK5hVOvN8/ryVMl2Le/kH3v2BedUDAAA=

Ou dessiner ses propres murets dans l'éditeur (F5), étape « MURS BAS ».

### Vérifié

Suites touchées vertes (codec, géométrie, éditeur, arène, protocole, bandeau LED, matière,
vision, carte partagée, murs bas) ; la géométrie vue rougir par sabotage de la priorité
mur haut / mur bas, puis remise. **Rendu en fenêtre** de la carte d'essai montée comme
`rebuild_arena` (calques en fondu additif, contour d'encre, collisions) : sous une torche,
les 6 cases de murs bas à portée sont éclairées ; torche éteinte, l'image 2560×1440 vaut
**0/255** partout.

## 10. MB2 — l'accroupi (ouverte par Adrien le 2026-09-14, 19 h 40)

### Les touches — choix d'Adrien

| | J1 | J2 | Manette |
|---|---|---|---|
| S'accroupir / se relever | **C** | **M** | **L3** (clic du stick gauche) |

**En bascule partout** : un appui pour se baisser, un pour se relever. Positions physiques,
comme toute l'Input Map. La ligne « S'accroupir » apparaît dans le menu de liaisons, et
`tools/test_liaisons.gd` la compte parmi les gestes de combat (aucun doublon permis).

### Le fil : une posture, pas un appui

`InputProvider.is_crouch_pressed()` rend la posture VOULUE. Le fournisseur local résout la
bascule sur le front montant de la touche (appelé deux fois par image, il ne compte le front
qu'une fois) ; le fournisseur réseau rend le bit reçu. `rpc_send_inputs` gagne ce bit en
neuvième argument. Conséquences :

- **rien à réconcilier** : l'hôte applique le bit, le client prédit le même depuis le même
  état ; un paquet perdu retarde la posture d'un paquet, il ne l'inverse jamais ;
- **l'adversaire** suit `net_accroupi` (répliqué à 30 Hz) sans interpolation — la posture
  de l'instantané le plus ancien des deux encadrants, comme la torche ;
- **`Protocol.VERSION` reste 18** (montée en MB1, aucun tag depuis) ; nouveau témoin.

### Dans la simulation

| Règle | Où | Valeur |
|---|---|---|
| Ralentit fortement | `player.gd`, après le root et l'éblouissement | `FACTEUR_VITESSE_ACCROUPI = 0,25` (65 px/s) |
| Silhouette basse et ramassée | `Player.poser_posture()` : les cinq vues du corps | `ECHELLE_SILHOUETTE_ACCROUPIE = 0,8` ; zone de touche et ombre inchangées |
| Étouffe les pas | `AudioManager.play_footstep(…, etouffe)` | −9 dB, portée ×0,5 — valeurs de départ, **à doser au banc audio** |
| Marque HUD pour soi | `ui.gd` : « ACCROUPI » dans le panneau de torche | jamais dans celui de l'adversaire |
| Compensation de latence | `_pos_history` porte la posture ; `_rewound_posture()` | pour la balistique de MB3 |
| Killcam | `ReplaySystem.Snapshot.p1/p2_accroupi`, silhouette des fantômes | 60 Hz |
| Chaque manche debout | `Player.reset_posture()` | — |

Un seul point d'écriture de la posture, `poser_posture()` : la vitesse lit `accroupi`, et la
silhouette suit au changement seulement. La silhouette ne peut donc pas dire autre chose que
la simulation.

### Vérifié

`tools/test_accroupi.tscn` (38 contrôles, scène : un vrai joueur qui marche) : les touches
par défaut, la bascule du fournisseur local (un front compté une fois par image), le bit
du fournisseur réseau, le RPC de l'hôte qui reçoit la posture et sa signature à neuf
arguments, le ratio de vitesse mesuré sur trente pas de physique (0,25 à 0,03 près), les
cinq vues ramassées et la zone de touche inchangée, l'adversaire interpolé (y compris un
instantané d'avant MB2, lu debout), l'image de killcam, le pas étouffé (écart de niveau et
portée) et la remise debout de manche. **Vue rougir** en retirant la ligne du ralentissement
(ratio 1,000), puis restaurée. `test_liaisons` (57 contrôles), `test_rejeu` (80),
`test_menus_finitions` (60, dont la marque HUD), `test_netcode` (83), `test_pool_sfx`,
`test_dosage_audio`, `test_marche` et `test_protocole` (nouveau témoin) verts.

### Ce que MB2 ne fait pas encore

Un accroupi n'est pas caché derrière un mur bas, sa torche ne bute pas, les balles ne
jugent pas sa hauteur, on n'enjambe pas. Tout cela est MB3, et MB2 en pose les appuis : la
posture est partout où la règle `franchit()` ira la chercher — simulation, fil, historique
de l'hôte, killcam.

## 11. MB3 — les échanges (ouverte par Adrien le 2026-09-14, 20 h 20)

Quatre sous-étapes : **MB3a** la règle en jeu, **MB3b** l'enjambement, **MB3c** la zone
morte au rendu et le banc de coût, **MB3d** l'équité, la killcam, les captures.

### L'enjambement — choix d'Adrien

**Tenir** Croix (manette), Espace (J1) ou point-virgule (J2) **en poussant vers le muret**.
Lâcher arrête avant de monter dessus : pas d'enjambement accidentel. (Adrien avait d'abord
coché « un appui lance l'enjambement complet », puis s'est corrigé.) Pendant la traversée :
debout, 65 px/s, pas de tir, un bruit d'enjambement.

### MB3a — la règle dans le jeu

| Règle | Où | Comment |
|---|---|---|
| Une seule règle | `murs_bas.gd`, classe `MursBas` (ex-`tools/murs_bas_geometrie.gd`) | `franchit_regle(source, cible, h_source, h_cible, murs)` avec les constantes de `map_geometry.gd` |
| Les murs de la manche | `MapGeometry.rects_monde(data, Kind.LOW_WALLS)` → `GameState.murs_bas` | recalculés à chaque `rebuild_arena`, comme la collision |
| Canon accroupi sous le mur | `bullet.gd`, `_ready` | `LOW_WALL_LAYER` ajouté au masque du `ShapeCast` si `hauteur_tir ≤ hauteur_mur` |
| Balle debout par-dessus | `bullet.gd`, `_franchit_vers()` avant chaque touche de joueur | survolé → exclu du `ShapeCast` pour le reste du vol |
| Cible compensée | `GameState._do_spawn_bullet` | `lag_hauteur` = posture remontée par `_rewound_posture` |
| Torche accroupie qui bute | `Player.poser_posture()` | `COUCHE_OMBRE_MUR_BAS` posée / retirée sur torche, rétrodiffusion, halo, flash |
| Lumières au sol | `gadget_mine.gd`, `gadget_braises.gd`, `fusee.gd` | le bit en permanence (fusée en vol : à confirmer) |
| Éblouissement | `GameState._ligne_de_vue_depuis` | œil à la hauteur de la cible, source à celle du porteur, sol sans porteur |

**Vérifié** : `tools/test_accroupi.tscn` (49 contrôles) — les quatre lumières portées
posent et retirent le bit sans toucher aux autres couches d'ombre ; une vraie balle
(`bullet.tscn`) voit les murs bas sous un canon accroupi, survole un accroupi dans la zone
morte, touche au-delà et touche un debout collé au mur ; vue rougir en neutralisant la règle.
`test_murs_bas` (93) : `franchit_regle` = `franchit` du prototype sur 80 cas, et
`rects_monde` en pixels de la carte. Lot complet vert, 113 OK.

Ce qui reste visuel en MB3a : la **zone morte au sol** et la **disparition d'un accroupi**
dans la zone morte ne sont pas encore rendues — la balle et l'éblouissement les appliquent
déjà, l'écran pas encore (MB3c). ⚠️ **C'est une asymétrie temporaire entre ce qui se voit et
ce qui se paie** : on peut voir un accroupi que la balle survole. Elle se referme en MB3c, et
H-MB1 ne se joue pas avant. ✅ **Refermée en MB3c** (voir plus bas).

### MB3b — l'enjambement

| | J1 | J2 | Manette |
|---|---|---|---|
| Enjamber (tenu, en poussant vers le muret) | **Espace** | **point-virgule** | **Croix** |

- **Le geste voyage tenu** : `InputProvider.is_climb_pressed()`, dixième argument de
  `rpc_send_inputs` (cumulé sous `Protocol.VERSION` 18).
- **La décision** (`Player._regler_enjambement`) : le corps chevauche un muret, OU pousse
  dessus en tenant le geste → la collision avec `LOW_WALL_LAYER` est coupée. Lâché avant d'y
  monter, elle revient et le muret arrête. Déjà dessus, la traversée continue : un corps
  dans un mur ne peut pas retrouver sa collision.
- **Pendant la traversée** : debout (la bascule d'accroupissement reprend après),
  `FACTEUR_VITESSE_ENJAMBEMENT = 0,25` (65 px/s), aucun tir.
- **Le bruit** : `AudioManager.play_enjambement`, le frôlement de mur à +6 dB et plus grave,
  joué à la montée sur le muret par `_guetter_enjambement` — pour TOUS les rôles, depuis la
  position, donc l'adversaire affiché s'entend comme le joueur simulé. Valeur de départ,
  à doser au banc audio.
- **Où sont les murets** : `MursBas.murs_de_la_manche`, registre posé par `rebuild_arena`.
- **Quel rayon** : `MursBas.RAYON_ENCOMBREMENT = 28` — la collision du joueur est une étoile
  dont le canon avance à 28. Décidé au rayon de touche (18), le premier essai ne voyait
  jamais la poussée : le canon heurtait le muret avant que la sonde n'atteigne la pierre.

**Vérifié** : `tools/test_accroupi.tscn` (60 contrôles) — touches, geste sur le fil, et un
vrai joueur face à un vrai muret : bloqué sans le geste, traversée en le tenant à 65 px/s,
un seul bruit, aucun tir, collision retrouvée après.

### ✅ Tranché par Adrien (2026-09-14, 21 h 10) — deux questions relevées pendant MB3

1. **Tirer trahit toujours** : un accroupi caché derrière un muret qui tire se révèle
   quand même (la silhouette révélée au tir ne dépend d'aucune lumière). Comportement
   actuel conservé, sans une ligne changée.
2. **Une fusée EN VOL éclaire par-dessus les murets** ; posée au sol, elle bute dessus
   (correction de la lecture de MB3a, qui la faisait buter toujours). Fait :
   `Fusee.masque_ombre(atterrie)`, posé à la construction (vol) puis aux trois façons de
   se poser — atterrissage, fusée de killcam, saut d'âge du banc.

Le détail de la première question, tel qu'il a été posé :

**La silhouette révélée au tir traverse-t-elle la zone morte ?** Quand un joueur tire, sa
silhouette s'allume pendant 2 s chez l'adversaire, **non éclairée** — elle ne dépend
d'aucune lumière, donc d'aucun mur (curseur « Silhouette révélée au tir », plancher 0,7 en
classé, `player.gd` après le flash). Un accroupi caché derrière un muret qui tire se
révèle donc entier, quel que soit le muret — alors que sa balle s'arrête sur la pierre et
que son flash bute dessus. Deux lectures, à trancher en effets perçus : (1) **tirer trahit
toujours**, même à l'abri — c'est le prix du tir, et la cachette ne dispense pas de le
payer ; (2) **un muret cache aussi l'éclair** d'un accroupi, et la révélation ne vaut que
pour qui la lumière aurait atteint. **Adrien a choisi (1).**

### MB3c — la zone morte dessinée à l'écran

La piste C du prototype, portée dans le vrai jeu. **L'asymétrie de MB3a est refermée** :
un accroupi que la balle survole n'est plus visible à l'écran.

| Quoi | Où | Comment |
|---|---|---|
| La règle en GLSL | `murs_bas_zone.gdshaderinc` (neuf, premier include du dépôt) | `mb_dans_la_zone_morte(LIGHT_POSITION, LIGHT_VERTEX)`, traduction de `MursBas.franchit`, avec une sortie anticipée exacte (plus loin que L du rectangle, un mur ne peut rien) |
| Le sol | `murs_bas_sol.gdshader`, posé sur `CustomFloor` avant sa duplication | `blend_add` + éclairage par défaut écrit tel quel : hors zone, le pixel est celui de l'ancien `CanvasItemMaterial` (mesuré 0/255 d'écart) |
| Le décor peint | `murs_bas_decor.gdshader`, posé sur `ArenaDecor_P1/P2` | mélange normal ; posé sur les COPIES, `duplicate()` partagerait le matériau |
| Les corps | `player_rim_light.gdshader` (soi), `player_enemy_light.gdshader` (l'adversaire) | jugés en leur centre ; L_accroupi si accroupi, 0 debout |
| Les uniformes | `murs_bas_rendu.gd` (classe `MursBasRendu`, sans autoload) | murs rentrés de `OCCLUDER_INSET`, en écran, triés au champ de la vue, plafonnés à 64 |
| La poussée | `GameState._pousser_zone_morte`, sur `RenderingServer.frame_pre_draw` | par vue, par la transformation du viewport qui la REND (`_viewport_du_joueur`) ; juste avant le dessin, quand caméras et joueurs ont fini de bouger |
| Le bandeau LED | `mur_led.gd` : `height = MursBasRendu.HAUTEUR_SANS_ORIGINE` | une lampe sans point d'origine (sa position est le centre de la carte) : le shader l'exempte |

**Ce que la règle ne couvre pas, à dessein** : le contour d'encre (`mur_encre.gd`) et le
dessus des murets sont à la hauteur du mur ou au-dessus — L = 0, toujours visibles ; les
murs hauts n'ont pas de zone morte. **Ce qu'elle ne couvre pas, et qui se signale** : les
marques posées au sol en cours de manche (taches, empreintes, douilles…) restent éclairées
dans la zone morte. Si une empreinte d'accroupi s'y lit, c'est une information — à regarder
en MB3d.

**Coût, au banc** (2560×1440, écran scindé, torche allumée, trois tours entrelacés,
médiane ; ordre de grandeur, pas un relevé au protocole) :

| Config | Image médiane |
|---|---|
| Ancien matériau | 4,30 ms |
| Règle, aucun mur | 5,19 ms (bruit : 4,07 au meilleur tour) |
| Carte d'essai (5 murs) | 4,47 ms |
| 40 murs à l'écran | 8,69 ms |

La carte d'essai ne se distingue pas du bruit ; **40 murets serrés à l'écran coûtent
~4 ms** — toujours loin de la cible (1 % bas ≥ 60). La poussée des uniformes : ~40 µs par
image. Appels de dessin inchangés (41 à 47 selon la scène).

**Vérifié** :
- `tools/test_murs_bas_rendu.gd` (neuve, au lot) : longueurs (58 / 44 px, doublées au zoom
  ×2), murs rentrés et transformés, coins remis en ordre sous miroir, tri au champ,
  plafond et débordement, uniformes posés, shaders qui incluent la règle et compilent,
  seule la LED porte une hauteur. Vue rougir en retirant le retrait.
- `tools/banc_murs_bas.tscn` (neuf, FENÊTRÉ) : le vrai `main.tscn` sur la carte d'essai,
  vue de J1 et de J2 en écran scindé puis vue unique (racine). Sol : **tous les points
  d'accord** (733 à 754 par scène, dont ~100 noircis par la règle), aucun allumé par la
  règle, 0/255 d'écart avec l'ancien matériau hors zone. Corps : accroupi à L − 12 noir,
  à L + 12 éclairé, debout éclairé. Noir absolu identique avec et sans la règle. **Vu
  rougir** en coupant la poussée : le sol perd exactement ses points de zone morte, le
  corps accroupi s'allume.

**Pièges payés au banc — tous du banc, aucun de la règle**, et chacun ressemblait à un
défaut de la règle :
1. **La caméra glisse** après une téléportation : attendre que la transformation écran soit
   stable, pas un nombre d'images.
2. **L'éblouissement de la scène précédente** : celui qui regarde s'était tenu dans la
   torche de l'autre ; sa vue sort floutée pendant la récupération — cône mou, muret et
   corps effacés. Deux passages ont accusé à tort la lampe, puis l'intention de torche.
3. **Le corps d'en face est sombre sous la torche** (ses propres occluders) : lu en son
   centre il est noir avec ou sans la règle. Le banc retire ses occluders.
4. **La ligne de visée et le viseur sont non éclairés**, dans l'axe du porteur, donc à
   travers la cible : ils passaient pour un corps éclairé dans une seule vue.
5. **`hauteur_mur()` est déjà en pixels** : la première suite l'y reconvertissait (2041 px).

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
