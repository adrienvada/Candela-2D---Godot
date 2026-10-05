# SHA — Shaders : coût GPU (audit d'optimisation, 2026-10-05, commit `52a29c1`)

Lecture seule. Aucun Godot lancé, aucune mesure : **tout chiffre de temps ci-dessous est ESTIMÉ**, sauf ceux repris de la
ROADMAP ou de `docs/MURS_BAS.md` avec leur numéro de ligne (marqués MESURÉ-ROADMAP). Ce qui est **PROUVÉ** l'est par lecture
du code (extraits cités). Les numéros de ligne du code et de la ROADMAP cités ont été relus contre le dépôt avant remise.

## 0. Cadre de calcul et limites

- **Surfaces** : fenêtre 2560x1440 = 3,69 Mpx (ROADMAP l. 2925, 17160) ; lightmap « 1080p » = 2,07 Mpx (l. 24376) ; vue 3D en
  MSAA 4x (`presentation_3d.gd:118-123`, coût mesuré +0,09 à +0,21 ms). **Pilote GL du Mac** : `project.godot` ne fixe aucun
  `rendering/gl_compatibility/driver.*` ; `docs/ETUDE_ISO.md:193` dit « OpenGL 3.3 natif (ANGLE-over-Metal abandonné) » ;
  `conditions_de_match.gd:168` enregistre `get_current_rendering_driver_name()` dans l'historique des matchs (la valeur réelle
  se lit là). Conséquence : GLSL 330 core, qualificateurs de précision ignorés.
- **Part éclairée** : sol 27,3 %, faces de mur 58,4 % (ROADMAP l. 26096). C'est la mesure du banc d'ISO7b sur sa zone d'étude
  (Le Cloître, torches allumées) : un ordre de grandeur, la part sur l'écran entier n'a pas été relevée (elle est vraisemblablement plus basse).
  **La part de l'écran occupée par le sol, les dessus et les faces de murs n'est pas mesurée** : hypothèses de travail, sol
  2,2 à 3,7 Mpx (selon que le GPU élimine ou non le sur-dessin), faces de murs ≈ 0,3 Mpx, dessus ≈ 1,1 Mpx.
- **Unité « ALU-éq »** (modèle de classement, pas un temps) : une opération ALU = 1 ; une transcendante (`sin`, `log2`,
  `exp2`, `sqrt`) = 4 ; une lecture de texture = 8 ; donc un `pow` scalaire = 9 et un `pow` vec3 = 27. Le code qui ne dépend
  que d'uniformes est **supposé hissé** (exécuté une fois par dessin : préambule d'ombreur des GPU Apple, supposé et non
  vérifié ici) ; sinon le voile d'éblouissement pèse environ +70 % (§ 1.1).
- **Étalonnage ms/G : deux ancres seulement, qui divergent d'un facteur 2 à 3.** (i) `docs/MURS_BAS.md:535-547`
  (2560x1440, écran scindé, torche allumée) : 40 murets = 8,69 ms contre 4,47 ms (carte d'essai), soit +4,2 ms pour ≈ 4 G
  ALU-éq (40 tours x ≈ 16 ALU-éq x ≈ 6 M couples fragment-lumière, ESTIMÉ) : ≈ 1 G/ms. (ii) ROADMAP l. 28420 : l'usure avant
  le levier 1 = +0,67 ms pour ≈ 1,1 à 1,8 G ALU-éq (ESTIMÉ) : ≈ 1,6 à 2,7 G/ms. **Lecture prudente : 1 G ALU-éq économisé =
  0,4 à 1 ms** sur le M3, si la passe est bornée par l'ALU et non par la bande passante.
- Les trois shaders `*_eclaire` (lumière 3D) ne sont **jamais allumés en jeu** : `poser_lumiere_3d` n'est appelé par aucun
  script de jeu de la racine (seul `presentation_3d.gd:637` le rappelle, derrière `_lumiere_3d_voulue` que seule cette
  fonction pose) ; ses appelants sont `tools/banc_lumiere3d.gd`, `banc_lumieres.gd`, `bench_framerate.gd`,
  `photographe.gd`, `test_lampe_modele.gd`. Ils sont exclus des classements.

---

## 1. Carte des chemins chauds

### 1.1 Par image — un duel iso en vue unique (le cas en ligne), torche allumée, 2560x1440

| Rang | Passe | Shader (variante par défaut) | Pixels / image | Lectures de texture / px | Transcendantes / px | Poids ALU-éq / image (ESTIMÉ) | Notes |
|---|---|---|---|---|---|---|---|
| 1 | sol 3D | `sol_iso` + `USURE_ESSAI` (défaut depuis Q30) | 2,2 à 3,7 Mpx | 4 (noir) à 9 (éclairé) | 41 (noir) à 55 | **1,8 à 3,1 G** (≈ 690 par pixel noir, ≈ 1 190 par pixel éclairé) | un pixel NOIR coûte 58 % d'un pixel éclairé |
| 2 | UI plein cadre | `voile_eblouissement_calme` | 3,69 Mpx | 12 | 3 (+55 `sin`/`cos` d'uniformes si non hissés) | **1,1 G** (1,9 G si non hissé), ≈ 300 par pixel | actif tant que la torche est allumée (niveau 0,06) |
| 3 | lightmap 2D | `murs_bas_sol` (`light()`) | 2,07 Mpx x 3 à 5 lumières | 2 par lumière | 1 `sqrt` par lumière | **0,4 à 0,7 G** dont 0,15 à 0,3 G de zone morte | nombre de lumières par pixel non compté |
| 4 | murs 3D | `mur_iso` + `USURE_ESSAI` | faces ≈ 0,3 + dessus ≈ 1,1 Mpx | 12 (faces) / 3 (dessus) | 35 à 55 + boucle d'impacts (faces) | **≈ 0,6 G** (faces ≈ 1 100 noir / 1 500 éclairé, dessus ≈ 180) | `usure_face` payée aussi sur le noir |
| 5 | rayon 3D | `volume_iso` (3 couches `FAISCEAU_LUMINEUX` + juge) x 2 lampes | ≈ 0,5 Mpx | ≈ 6 (11 éclairé) | 12 (couche) / 15 (juge) | **≈ 0,3 G** | déjà allégé par le chantier 0.8.0 |
| 6 | UI plein cadre | `damage_vignette` (alpha 0 au repos) | 3,69 Mpx | 0 | 1 (`sqrt`) | **≈ 0,1 G** (≈ 28 par pixel) | rien n'est visible : SHA-06 |
| 7 | UI plein cadre | `ColorRect` « VoileEncre » 10 % (sans shader) | 3,69 Mpx | 0 | 0 | un mélange, pas d'ALU | choix de direction artistique (`ui.gd:2578-2587`) |
| 8 | corps 3D | `corps_iso` + `corps_iso_profondeur` (x 9 à 14 boîtes) | ≈ 0,03 Mpx | 1 | ≈ 40 | ≈ 0,02 G | le coût est en appels de dessin (95 en vue unique, ROADMAP l. 26091) |
| 9 | lueurs, quads | `halo_iso`, `quad_iso`, `quad_iso_additif` | < 0,02 Mpx | 0-1 | 0 | négligeable | |
| + | une fusée posée | `nuage_voxel_iso` x 2 (peau + juge) | ≈ 0,6 M de fragments par vue au banc cloud, dont ≈ 0,42 M de juge (l. 31265, 31282) | | | à multiplier avec la surface de la vue (non mesuré à 1440p) | + ≈ 110 000 sommets par vue (SHA-11) |

Total des passes de plein cadre et de sol/murs : **≈ 4,3 à 6,7 G ALU-éq**. Les corrections proposées (SHA-03 option 1, 04, 05,
06, 08a) visent **≈ 1,8 à 2,7 G**, soit environ 40 % de ce budget fragment estimé, dont 1,0 à 1,6 G pour SHA-04 seul.
Au taux de 0,4 à 1 ms par G : **≈ 0,7 à 2,7 ms par image, ESTIMÉ**, à confirmer par un A/B sur le banc de cadence avant
d'engager le lot. Ancrage mesuré sur le voile : copie d'écran + voile plein contre voile calme = 0,53 ms/image à 2560x1440
(ROADMAP l. 26533-26535) ; le voile calme seul n'a jamais été isolé (`tools/loupe.gd:1542` ne compare que ces deux bras).

### 1.2 Par événement — premiers dessins (compilation du programme GL) et rafales

| Événement (la 1re fois du processus) | Programmes GL qui compilent à cet instant | Préchauffé ? |
|---|---|---|
| 1re manche iso | `sol_iso`+USURE, `mur_iso`+USURE, `corps_iso`, `corps_iso_profondeur`, `quad_iso`, `damage_vignette`, `player_*_light`, `murs_bas_*`, `capteur_*`, voile calme | non (masqué ou non par le décompte : non vérifié) |
| **1er allumage de torche** (joueur ou PNJ) | `volume_iso` couche (FAISCEAU_LUMINEUX), `volume_iso` juge, `halo_iso` (lentille) + **10 `Shader.new()`** (SHA-02) | **non** |
| 1er tir | `quad_iso_additif` (traçante, aura) | non |
| 1re touche | `blood_shader` (programme canvas éclairé) | non |
| 1re fusée posée | `nuage_voxel_iso` variante `NUAGE_FUSEE`, juge de nuage, `halo_iso_melange` ; `nappe_fusee` | `fumee_fusee` seul (`fusee.gd:343-358`) |
| 1er nuage de gadget (suie, poussière) | `nuage_voxel_iso` (base), juge de nuage | non (données seulement : `iso_nuage_voxel.gd:306-323`) |
| 1re nappe (braises, poudre) / 1re toile | `volume_iso` forme 5 / forme 2 | non |
| 1er éblouissement >= 0,12 | `voile_eblouissement` plein + copie plein cadre | non |
| 1er brouillage | `brouillage_flou` | non |
| 1re mort | `death_flash`, puis `killcam_overlay`, `ghost_unshaded` | non (commentaire trompeur) |

### 1.3 Chargement / démarrage
- Une cinquantaine de `preload`/`load` de `.gdshader` à l'ouverture des scripts (carte en Annexe A) : analyse et préprocesseur
  d'`#include` **synchrones**. Dont 7 shaders morts en production, préchargés par `presentation_3d.gd:107-117` (SHA-12).
- `IsoNuageVoxel.prechauffer()` (`iso_nuage_voxel.gd:306`) et `prechauffer_nappes()` (l. 616) préparent shader, aplats, reliefs
  et planches au lancement — bien — mais pas le programme GL (l. 301-305 le disent).

### 1.4 Hors chemin chaud
Menus (`menu_*`, 9 fichiers), bancs (`pate_*_iso`, `*_eclaire`, `corps_grossier_iso`), essais éteints (`grain_iso`,
`corps_iso_contour`). Le voile de menu se retire du dessin à intensité nulle (`menu_veil.gd:43-45`).

---

## 2. Réponses aux sept questions de la mission

**Q1 — Coût par fragment.** *Aucune marche de rayon dans `nuage_voxel_iso`* : un `MultiMesh` de cubes
(`iso_nuage_voxel.gd:404-429`), le travail est dans le **sommet**. Les « boucles » : `voile_fbm` 3 octaves
(`nuage_voxel_iso.gdshader:261-270`, 12 `sin`), `trous[16]`/`masses[2]`/`tunnels[6]` (`:288-312`, bornes `if (i < nb_*)`),
`lumiere_lissee` 8 prises (`:431-438`), `braise_de` 16 (`:443-455`). Les seules boucles de marche du dépôt sont le DDA de 4 pas du
juge (`volume_masque_compact.gdshaderinc:197`) et `juge_couvre` (`:278`, 4 tours). `discard` : `volume_iso` (5 sites dans le
source, 4 par variante : l. 138, 162, 184, 193/223), `corps_iso` (l. 231, 306), `corps_iso_profondeur` (l. 36),
`halo_iso.gdshaderinc` (l. 52, 61), `brouillage_flou` (l. 85) ; **aucun** dans `sol_iso`, `mur_iso`, `nuage_voxel_iso`.
Classement par coût x surface : § 1.1 ; constats SHA-03, 04, 05, 06.

**Q2 — `light()` dans les shaders canvas** (exécuté par lumière qui couvre le fragment ; ≤ 16 lumières par objet : ESTIMÉ du
moteur, non relu dans ce dépôt) :

| Shader | Où | Surface | Corps de `light()` |
|---|---|---|---|
| `murs_bas_sol` | `CustomFloor_P1/P2` (`game_state.gd:1512-1516`) | **tout le sol de la lightmap de la vue, 2,07 Mpx** | `mb_dans_la_zone_morte` + le défaut du moteur |
| `murs_bas_decor` | `ArenaDecor_P1/P2` (`game_state.gd:1551`) | marques peintes | idem |
| `player_rim_light` | `visual`, `visual_ptr` (`player.gd:773-774, 782-783`) | ≈ 50x50 px | zone morte + aplat |
| `player_enemy_light` | `visual_enemy` (`player.gd:777-780`), leurre (`gadget_leurre.gd:215`) | ≈ 50x50 px | zone morte + x4 plafonné |
| `capteur_local` / `capteur_adverse` | disque de rayon 18 px dans une sous-vue 256x256 à zoom 2 (`capteur_corps.gd:62-65,100,119`) : 2 en vue unique, 4 en scindé, +1 par figurant | ≈ 4 000 px chacun | miroirs des deux précédents |
| `blood_shader` | une tache (≤ 120 + copies J2, `blood_stain.gd:320`) | ≈ 100-200 px | `LIGHT_COLOR x COLOR` (sans `LIGHT_ENERGY`) |
| `capteur_objet` | disque de gadget/fusée posés | | pas de `light()` : défaut du moteur |

La zone morte (`murs_bas_zone.gdshaderinc:96-138`) boucle sur `mb_nb_murs` ≤ 64 par (fragment, lumière) : **MESURÉ-ROADMAP
l. 30046-30048 / `docs/MURS_BAS.md:535-547` : 40 murets à l'écran = +4 ms** ; la carte d'essai (5 murs) et « aucun mur » ne se
distinguent pas du bruit. Aucune des 6 cartes de duel livrées n'a de muret (`"low_walls": ""` ou clé absente, relevé dans
`assets/maps/*.json`) ; **18 des 100 niveaux d'aventure en ont : médiane 3 rectangles fusionnés, 10 pour `chapitre_04/niveau_08`,
37 pour `chapitre_09/niveau_07`, 44 pour `chapitre_07/niveau_08`** (recalcul par la fusion gloutonne de `map_geometry.gd:202-266`).
→ SHA-08.

**Q3 — Lectures d'écran et copies.** Au repos : **0 par image** (le voile calme ne déclare pas `hint_screen_texture` ; `_voile_bb`,
`KillcamBB`, `CopieEcran` sont masqués : `ui.gd:2620-2624`, `game_state.gd:635-640`, `brouillage_vue.gd:66-72`).
Éblouissement >= 0,12 : **1 copie plein cadre** + 3 lectures par pixel. Brouillage : 1 copie `COPY_MODE_RECT` par vue brouillée +
17 lectures par pixel sur l'ellipse. Killcam : 1 copie plein cadre + 5 lectures par pixel. Pire cas en direct : éblouissement +
brouillage = 2 copies. Shaders qui déclarent l'écran (grep complet) : `brouillage_flou:44`, `killcam_overlay:20`,
`voile_eblouissement.gdshaderinc:245`, `menu_glass:40`, `menu_veil:21`, `pate_ecran_iso:13`, `distorsion_eblouissement:6`
(orphelin). **Deux demandent des mipmaps d'écran sans s'en servir : SHA-07.**

**Q4 — Uniformes par image, `instance uniform`, regroupement.** ≈ 270 à 290 `set_shader_parameter` par image dans un duel de
base (deux torches), ≈ 400 avec une fusée (SHA-09). **Aucun `instance uniform` dans les shaders** (grep) ; rien ne le justifie
(les couches du rayon diffèrent de quelques scalaires mais restent des dessins distincts ; le support de `instance uniform` en
`gl_compatibility` n'a pas été vérifié ici). Matériaux : toutes les boîtes de mur partagent **un** matériau
(`presentation_3d.gd:2194`, `IsoGeometrie.build_meshes`), les trois nappes de la fusée un seul (`fusee.gd:265-273`), les ondes de
mort un seul statique (`kill_shockwave.gd:51-62`) — bien. Exceptions : un `ShaderMaterial.new()` par tache de sang (≤ 120) et deux
par balle (SHA-14). Le 3D de `gl_compatibility` n'instancie pas automatiquement : chaque `MeshInstance3D` est un dessin
(≈ 95 appels de dessin par image en vue unique, ROADMAP l. 26091) ; hors périmètre du shader.

**Q5 — Compilation.** Tableau § 1.2 ; **seul préchauffage GL du dépôt : `Fusee.prechauffer()`** (un quad 2D invisible, une
image, `fusee.gd:343-358`) — il ne couvre pas `nappe_fusee`. Aucun shader 3D n'est dessiné d'avance. Programmes spatial : ≈ 15
(sol, mur, corps, profondeur, quad x2, halo x2, volume x5, nuage x2) ; canvas : ≈ 17 sources, plus les variantes que le moteur
ajoute lui-même au premier usage (éclairage 2D avec ombres, etc. : non quantifié). → SHA-01, SHA-02.

**Q6 — Code mort, doublons.** SHA-12. Hors production : `distorsion_eblouissement` (orphelin, ROADMAP l. 22506-22508),
les trois `*_eclaire` + `iso_relief` + `lumieres_iso.gd`, `pate_ecran_iso`, `pate_vue_iso`, `corps_grossier_iso`,
`corps_profondeur_iso`. **Doublons exacts, vérifiés par `diff` hors commentaires** : `corps_profondeur_iso` = `corps_iso_profondeur` ;
`capteur_local` = `player_rim_light` + `render_mode light_only` ; `capteur_adverse` = `player_enemy_light` + `light_only` ;
`murs_bas_decor` = `murs_bas_sol` moins `render_mode blend_add`.

**Q7 — Pièges `gl_compatibility` / macOS.** OpenGL 3.3 natif (`docs/ETUDE_ISO.md:193`) : compilation paresseuse et synchrone du
pilote (SHA-01) ; hash `fract(sin())` non portable (SHA-13) ; `filter_linear_mipmap` sur l'écran (SHA-07). Vérifiés sans objet :
tableaux d'uniformes (`mb_murs[64]` = 1 Ko, `usure_impacts[48]` = 768 o, `trous[16]`, `braises[16]`, `tunnels_*[6]` : UBO std140,
pas de 16 octets, chaque matériau très en dessous des 16 Ko garantis) ; indexation dynamique et bornes de boucle non
constantes (permises) ; dérivées et `texture()` hors branchement (respectés et documentés : ROADMAP l. 4010, `sol_iso.gdshader:132`,
`volume_iso.gdshader:146-148`) ; `nuage_voxel_iso` : 12 `varying` / 25 flottants (7 vec4 bien tassés, 12 au pire, pour 15
garantis), 6 samplers distincts lus au sommet (`nappe_1..3`, `masque`, `lumiere_1/2`) pour 16 garantis ; `varying flat` supporté.
Un piège déjà payé : deux `varying` de plus décalaient les interpolants (`corps_iso.gdshader:314`).

---

## 3. Constats

### SHA-01 — Aucun préchauffage des programmes GL en 3D ni dans la plupart des shaders canvas : le premier allumage de torche, le premier tir, la première touche, la première fusée, le premier éblouissement fort et la première mort compilent à l'instant même

**Où** : `fusee.gd:338-358` (seul préchauffage GL du dépôt) ; `iso_volumes.gd:686-713` ; `iso_nuage_voxel.gd:301-323, 616-631` ;
`player.gd:320,1814` ; commentaires qui confondent charger et compiler : `death_flash.gdshader:18-19`, `blood_stain.gd:30-31`,
`capteur_corps.gd:66`.

**Constat** :
```gdscript
# iso_volumes.gd:694-702 — rien n'existe tant que la torche est éteinte ; couches, juge et variantes naissent au 1er allumage
if lampe == null or not lampe.enabled or lampe.energy <= 0.0 or lampe.texture == null:
	return
...
var e := _entree(j, "faisceau_air", vus, CLE_FAISCEAU_AIR)
_couches(e, int(VOLUME_FAISCEAU_AIR["couches"]), FORME_POCHOIR, true)
```
```gdscript
# player.gd:320 / 1814 — la torche part ÉTEINTE et suit un bouton : son premier allumage est un choix du joueur (ou du PNJ)
var flashlight_on: bool = false
flashlight_on = input_provider.is_flashlight_pressed()
```
```gdscript
# iso_nuage_voxel.gd:301-305 — l'aveu : le shader n'est pas compilé ici
## ... Le shader, lui, se COMPILE à son premier dessin, dans le pilote : ce coût-là n'est pas pris ici ...
```
Et `death_flash.gdshader:18-19` : « Ressource préchargée : compilée au démarrage, la première mort ne déclenche plus de
compilation à chaud », `blood_stain.gd:30-31` : « Shader préchargé en const : une compilation à la volée provoquerait un
hoquet » — **faux pour le programme GL** : `preload` charge et analyse le texte du shader, le pilote compile au premier DESSIN
(ROADMAP l. 22509-22513, audit PE3.5 : « seule `Fusee.prechauffer()` dessine d'avance. Une chauffe générale est un pas séparé »).
Aucun autre préchauffage dans le code de jeu (grep `prechauff|préchauff|chauffe|warm` sur les `*.gd` de la racine).

**Coût** : mécanisme PROUVÉ. Durée : **143 à 150 ms par sorte de lampe au premier allumage, MESURÉ-ROADMAP l. 27613-27622**
(« les hoquets de 143 à 150 ms sont des COMPILATIONS au premier allumage d'une sorte de lampe », que la chauffe par couverture du
banc fait tomber à 16-40 ms) ; chaque relevé étant un processus neuf, le hoquet revient à chaque lancement.
Les programmes de ce constat sont gros (`volume_iso` : 1 584 lignes sources avec ses includes, avant préprocesseur ; `nuage_voxel_iso` :
1 138) : à prévoir **plusieurs images de 100 à 300 ms** (ESTIMÉ) au premier allumage de la torche de la session (deux programmes : couche et juge), au premier
tir, à la première touche, à la première fusée (nuage + halo + nappe). Sur 18 000 images d'un BO1 de 5 minutes le 1 % bas n'en
bouge presque pas ; le tort est ailleurs : une image figée à 150 ms **au moment décisif**, sur la machine de celui qui voit l'autre
allumer.

**Proposition** : une chauffe générale pendant le décompte de la première manche, à côté de `Fusee.prechauffer`
(`game_state.gd:1565`) ou juste après `_scene.visible = true` (`presentation_3d.gd:634`), qui **dessine une fois chaque programme de
la liste § 1.2** :
- 3D : un `MeshInstance3D` de 1 px dans le champ de la caméra de la vue locale (calques 3D de `presentation_3d.gd:169-171`), par
  matériau réel (rayon : couche + juge ; nuage x2 ; halo x2 ; `quad_iso_additif`) — « un objet hors champ ne compile rien »
  (`tools/bench_framerate.gd:724-725`) — avec des uniformes qui donnent un alpha de sortie nul ou un fragment jeté ; le juge du
  pochoir ne doit rien écrire dans le pochoir (il se jette) ;
- 2D : un sprite de 1 px par shader canvas (tache, nappe, flash de mort, vignette, voile plein, brouillage, killcam, fantôme),
  dessiné dans la vue qui utilisera le shader (la lightmap, sous une vraie lumière, pour les shaders éclairés : le moteur compile
  sans doute une variante par état d'éclairage, ESTIMÉ ; la racine/UI pour les autres), avec le shader réel et des uniformes à alpha
  de sortie nul — comme `Fusee.prechauffer` (`alpha_globale = 0`, `fusee.gd:355`) —, de sorte qu'aucune lumière ne se peint ; le
  moteur saute sans doute un item d'alpha effectif très bas, d'où le `modulate` laissé à 1 (ESTIMÉ, `RendererCanvasCull`, à
  vérifier) ;
- une garde headless qui liste les `.gdshader` référencés par le jeu et échoue si l'un n'est ni dans la liste de chauffe ni dans une
  liste d'exclusions (menus, bancs) : aucune suite ne rougit aujourd'hui si une chauffe manque.

**Gain attendu** : supprime les images de 100-300 ms aux moments décisifs ; rend inutile `--chauffe-couverture` côté bancs.
**Risque** : faible — le dessin de chauffe ne doit rien écrire (alpha de sortie nul, pochoir non touché : une lumière de chauffe
visible trahirait une position, c'est une question d'équité) et ne pas allumer de vraie `Light2D` ; tomber avant tout gel de
killcam. **Effort** : M.
**Sévérité** : **MAJEUR**. **Statut ROADMAP** : CONNU-OUVERT (l. 22509-22513 ; 27613-27622 ; limite de preuve reconnue
l. 31299-31302, 31445-31447, 31598-31600). **Comment le vérifier** : `tools/banc_pics.tscn` (date les images lentes : « des pics
groupés au début sont une compilation », l. 22512) et `tools/bench_framerate.tscn --seuil-lent 25` : lancer sans chauffe, allumer la
torche à t = 5 s, lire la pire image ; recommencer avec la chauffe.

---

### SHA-02 — Les variantes de `volume_iso` sont fabriquées à l'exécution, au premier allumage, par une chaîne de dix `Shader.new()` dont huit ne sont jamais dessinés à ce moment-là

**Où** : `iso_materiaux.gd:118-129` (`variante_definie`) ; `iso_volumes.gd:1790-1798` (`_poser_forme_imposee`), `1851-1861`
(`variante_masque`, `variante_forme`), `2016-2024` (`_variante_juge_de`, `variante_juge`) ; `DEFINES_FORMES` l. 229-232 ;
sol et mur : `iso_materiaux.gd:182-184` (au montage de la scène, sans conséquence).

**Constat** :
```gdscript
var v := Shader.new()
v.code = code.substr(0, fin) + "\n#define %s\n" % nom + code.substr(fin)
```
Chaque `#define` ajoute un `Shader` neuf (analyse + préprocesseur d'`#include` de 1 584 lignes sources). Au premier
`_couches(..., FORME_POCHOIR, true)` : FUMEE_MASQUE, USURE_ESSAI, MASQUE_COMPACT, MASQUE_RESSERRE, MASQUE_POCHOIR,
FAISCEAU_LUMINEUX (6) pour la couche ; puis, pour son juge (`forme_masque` vaut 5 par défaut, l. 159), MASQUE_LUMIERE,
MASQUE_AJUSTE, MASQUE_POCHOIR_JUGE, FAISCEAU_LUMINEUX_JUGE (4) : **10 objets `Shader`**, si aucune nappe ni aucun nuage n'a été posé
avant (le cache `_variantes` est statique). Deux seulement sont dessinés ; les autres sont des étapes intermédiaires.

**Coût** : PROUVÉ (structure) ; CPU synchrone ESTIMÉ à 10-30 ms au premier allumage (non mesuré) ; la compilation GL est SHA-01.
**Proposition** : construire toutes les variantes une seule fois au chargement (à côté de `IsoNuageVoxel.prechauffer()`,
`iso_volumes.gd:343`), ou les écrire en `.gdshader` statiques dont l'en-tête porte les `#define`. **Gain** : retire ce coût CPU
du premier allumage. **Risque** : nul pour l'image (mêmes sources) ; garder le piège « une variante n'est pas le même shader pour
qui filtre par identité » (ROADMAP l. 4086-4092 ; `_pousser_lightmaps` filtre par `_formes_posees`, `iso_volumes.gd:2090`).
**Effort** : S. **Sévérité** : MINEUR. **Statut ROADMAP** : NOUVEAU. **Vérifier** : `Time.get_ticks_usec()` autour du premier
`_couches` (journal), ou `banc_pics`.

---

### SHA-03 — Le voile d'éblouissement « calme » dessine un shader de 12 lectures de texture sur toute la fenêtre à chaque image où la torche est allumée, pour un résultat de 2 à 4/255

**Où** : `ui.gd:2436-2451` (le rect reste visible), `2543-2545` (choix calme/plein), `2553`, `2626-2633` (le voile couvre la
fenêtre) ; `voile_eblouissement.gdshaderinc:307-310` (`niveau <= 0.001` sinon tout), `335-347`, `356`, `363-374` (lueurs),
`378-401` (flares), `406-428` (fantômes), `434-438` (grain).

**Constat** : la rétrodiffusion de sa propre torche tient `dazzle_amount` à 0,06 en permanence (ROADMAP l. 4308, 26516-26517 ; « le
voile d'éblouissement vit en permanence dès qu'une torche est allumée », l. 26541-26542). Le voile calme prend alors la branche complète
(défauts `lueurs_n` = 2, `flares_n` = 5, `fantomes_n` = 5, `voile_eblouissement.gdshaderinc:142,159,211` ; `ui.gd` ne les touche pas) :
```glsl
ajout += texture(lueur_tex, uv).r * lueurs_intensite / fi;                       // x 2   (l. 373)
ajout += texture(flare_tex, uv).r * flares_intensite * sc;                       // x 5   (l. 400), avec cos/sin(-ang) par traînée
ajout += texture(fantome_tex, uv).r * fantomes_intensite * (...) / sqrt(fi);     // x 5   (l. 426-427)
```
soit **12 lectures** + un `pow` + deux racines par pixel, plus ≈ 55 `sin`/`cos` qui ne dépendent que d'uniformes. À 0,06 le résultat
est `teinte x alpha` ≈ 2 à 4/255 (ROADMAP l. 30744-30745 : « le noir SOUS LE VOILE ... 2 à 4/255 »).
**Les trois textures sont noires sur tout leur pourtour par contrat** (`voile_eblouissement.gdshaderinc:132-138`, `repeat_disable`).

**Coût** : surface PROUVÉE (une seule moitié visible en vue unique, `ui.gd:8870-8871`, donc la fenêtre entière : 3,69 Mpx) ; poids
ESTIMÉ ≈ 300 ALU-éq par pixel si les trigonométries d'uniformes sont hissées (**≈ 1,1 G/image, 44 M de lectures**), ≈ 520 sinon
(1,9 G). Ancrage MESURÉ : copie + voile plein contre voile calme = 0,53 ms (l. 26533) ; **le voile calme seul n'a jamais été
isolé**.

**Proposition** (par ordre croissant d'effort ; 1 et 2 laissent l'image identique) :
1. *Ne lire que dans la texture* : avec les valeurs par défaut et une vue 16/9, un calcul géométrique donne, hors de [0,1]² :
   ≈ 15 % des pixels pour les lueurs (carré de demi-côté 1,0 à 2,1 sur un écran de 3,56 x 2 en demi-hauteurs), ≈ 50 % pour les
   flares (rectangle tourné 1,4 x pente x 0,66 de demi-côtés), ≈ 95 % pour les fantômes (carré de demi-côté 0,2 à 0,33) — soit
   **≈ 63 % des 12 lectures** (ESTIMÉ). Un test `if (all(inside))` avant chaque `texture()` (les trois samplers sont en
   `filter_linear` sans mipmap : aucune dérivée requise) rend le même résultat ; pour les fantômes, le test se pose avant la
   rotation (`dot(q,q) > 2 taille²`). Économie ≈ 7,6 lectures x ≈ 15 ALU-éq = **≈ 0,4 à 0,5 G** ;
2. *Sortir les calculs d'uniformes du fragment* : `rel`, `vers`, `co/si/pente/sc` de chaque traînée, `ech/centre` de chaque lueur,
   `gc/gs/taille` de chaque fantôme, une fois par image en GDScript (`temps` y est déjà), en `vec3[]` (le projet évite `vec4[]` par
   prudence, `fumee_fusee.gdshader:33-36`) : **0 si le pilote hisse déjà, ≈ 0,8 G sinon** ;
3. *Résolution décorrélée* : lavis + lueurs + flares + fantômes sont des images lisses ; les rendre dans une `SubViewport` de
   640x360 (30 Hz sous `aberration_debut`), puis un quad plein cadre ne lit que cette texture et pose le grain par pixel :
   ≈ −85 % (**≈ 0,9 à 1,6 G**), à valider par Adrien sur `tools/banc_voile.tscn` ;
4. *(décision de direction artistique, change l'image de 1-2/255)* sous `aberration_debut`, ne dessiner que le lavis : voir
   Questions ouvertes n° 4.

**Gain attendu** : ESTIMÉ 0,4 à 0,5 G (option 1) soit ≈ 0,2 à 0,5 ms ; jusqu'à ≈ 1 ms avec l'option 3. **Risque** : visuel nul
pour 1 ; 2 change des arrondis au 7e chiffre ; 3 adoucit légèrement les bords des fantômes. Le voile est une information
d'éblouissement : **ne jamais le cacher** (`visible = false` redistribue la mise en page de l'`HBoxContainer` et blanchit la moitié de
l'autre joueur, `ui.gd:2436-2451`, attrapé par `planche_eblouissement`). **Effort** : S (1), S-M (2), M (3).
**Sévérité** : **MAJEUR (ESTIMÉ)**. **Statut ROADMAP** : NOUVEAU (la copie au repos est DÉJÀ-TRANCHÉE : l. 26514-26536).
**Comment le vérifier** : plan `loupe-cout-voile` (`tools/loupe.gd:107,289,1516-1542`) avec un troisième bras « voile masqué » ;
`bench_framerate.tscn` vue unique torche allumée, A/B ; image identique à 0 pixel pour 1 et 2.

---

### SHA-04 — Le sol et les faces de mur exécutent toute leur chaîne d'habillage sur des pixels dont la lightmap vaut 0 (la majorité du sol, ≈ 40 % des faces)

**Où** : `sol_iso.gdshader:81-99, 127-169` ; `mur_iso.gdshader:172-283` (usure l. 268) ; `iso_pate.gdshaderinc:93-106`
(`pate_facteur`), `115-125` ; `iso_usure.gdshaderinc:44-104` (`usure_face`), `112-115`, `138-161` (`usure_sol`).

**Constat** : `lightmap_pateuse_sol` rend `vec3(0.0)` dès que `l <= 0` (`sol_iso.gdshader:86-89`), mais **le fragment continue** :
```glsl
c = lightmap_pateuse_sol(px_lu, px, aa, deux);                                   // = 0 sur le noir          (l. 147)
c = pate_facteur(c, matiere * dalle);                                            // 6 pow = 12 transcendantes (l. 150)
...                                                                              // température : relit la lightmap (l. 154-162)
c = pate_facteur(c, usure_poids(c, usure_sol(px, usure_mur_pres(px), px_monde))); // 5 sin + 1 fetch + 12 transc. (l. 165)
c = pate_facteur(c, contact_des_corps(px));                                      // 2 sqrt + 12 transcendantes (l. 167)
ALBEDO = c;
```
et `mur_iso.gdshader:268` évalue `usure_face` (17 `sin` au moins + boucle d'impacts jusqu'à 48 tours avec `length`, `atan`, `pow`) **avant** de
savoir que `c` est nul : les arguments d'une fonction sont évalués d'abord. Or toute la chaîne est multiplicative ou renvoie `c`
si `l <= 0` : « 0 reste 0 » (`iso_pate.gdshaderinc:93`, 113 ; `iso_usure.gdshaderinc:8-10` ; `pate_temperature_graduee_neutre`
renvoie `c` si `l <= 0`, l. 194-196). Le masque de fumée le fait déjà : `volume_masque_compact.gdshaderinc:116-118`
(`if (l <= 0.0) { return true; }`).

**Coût** : structure PROUVÉE ; ESTIMÉ (recomptage ligne à ligne) : un pixel de sol NOIR ≈ 690 ALU-éq (dont 41 transcendantes), un
pixel éclairé ≈ 1 190 ; un pixel de face noire ≈ 1 100, éclairé ≈ 1 500. Avec une sortie anticipée, un pixel noir tombe à ≈ 130
(prélude + une lecture de lightmap). Économie : sol ≈ 560 x 73 % x (2,2 à 3,7 Mpx) = **0,9 à 1,5 G**, faces ≈ 770 x 42 % x 0,3 Mpx =
**0,1 G** ; soit **≈ 1,0 à 1,6 G** (le quart du budget fragment estimé), ≈ 0,4 à 1,6 ms. La part éclairée (27 %, 58 %) est celle de
la zone du banc : sur l'écran entier il y a plus de noir, donc plus à gagner.

**Proposition** (image **strictement identique** pour 1 et 2 : 0 → 0 est exact) :
1. *Sortie anticipée sur couleur nulle* : après `c = lightmap_pateuse_sol(...)`, `if (max(c.r, max(c.g, c.b)) <= 0.0) { ALBEDO = vec3(0.0); } else { ...le
   code actuel... }`. `aa`, `px_monde` et la lecture de `texture_sol` restent AVANT (dérivées) ; le dépôt n'emploie jamais `return;` dans un
   `fragment()` (le voile enveloppe déjà son corps dans un `else`, `voile_eblouissement.gdshaderinc:308-310`). Même motif sur `mur_iso`
   (face : après `c = lightmap_pateuse_lue(brute, motif, aa)`, l. 229). La lumière est spatialement cohérente : peu de divergence
   dans un groupe de threads ;
2. *Garder `usure_face` et `usure_sol` par la luminance* : n'évaluer que si `pate_luminance(c) > USURE_SEUILS.x` (sous 12/255,
   `usure_poids` vaut exactement 1 : `iso_usure.gdshaderinc:110-115`) ;
3. *Fusionner les facteurs* : `pate_facteur` coûte ≈ 106 ALU-éq (12 transcendantes) et le sol en appelle trois, les murs jusqu'à
   trois ; un seul produit `matiere x dalle x usure x contact` appliqué en un aller-retour sRGB économise ≈ 210 ALU-éq par pixel
   éclairé (≈ 0,15 à 0,2 G) — **pas au bit près** (écart d'arrondi 1e-7, qui peut basculer d'un niveau ≲ 0,05 % des pixels, ESTIMÉ) :
   à valider contre les gardes.

**Gain attendu** : voir Coût. **Risque** : nul pour l'image (1, 2) ; garde `tools/test_banc.gd:325-372` — elle exige que **chaque
ligne du fragment de `sol_iso`/`mur_iso` se retrouve dans `sol_iso_eclaire`/`mur_iso_eclaire`** : retouche miroir obligatoire (ou
suppression des forks, SHA-12) ; `tools/test_iso_beaute.gd` n'admet sur la couleur d'un mur que des `c = pate_facteur(c, ...)`
(ROADMAP l. 28415-28417) ; `volume_masque*.gdshaderinc` recopient la couleur du sol (`sol_ecrit`) : aucune retouche pour 1-2
(même couleur), parité à revérifier pour 3. **Effort** : S-M. **Sévérité** : **MAJEUR (ESTIMÉ)**. **Statut ROADMAP** : NOUVEAU
pour 1 et 3 ; la boucle d'impacts est CONNU-OUVERT (l. 28413-28414, 28444-28445 : « les leviers suivants ... pas encore »).
**Comment le vérifier** : `tools/banc_iso_beaute.gd` et `tools/test_iso_usure.gd` (0 pixel de différence, au même instant dans un seul
processus : l. 28439-28442), puis `bench_framerate.tscn` vue unique torche allumée en miroir.

---

### SHA-05 — Le sol lit cinq fois la lightmap pour rien sous la pâte par défaut (lavis)

**Où** : `sol_iso.gdshader:90-98` ; `iso_lightmap.gdshaderinc:74-90` (même motif dans `lightmap_pateuse`) ; `iso_pate.gdshaderinc:255-318`.

**Constat** :
```glsl
float lx_0 = pate_luminance(lire_lightmap(p - dx, deux) * ton_du_sol(p - dx));   // x 4 (l. 92-95)
float decalee = pate_luminance(lire_lightmap(p + vec2(3.0, 2.0), deux) * ton_du_sol(p + vec2(3.0, 2.0)));   // l. 97
return pate(c, l, style, motif, pente, decalee, aa);                              // l. 98
```
`pate()` ne lit `pente` que pour GRAVURE et LIGNE_CLAIRE (l. 269, 288) et `lumiere_decalee` que pour TRAME (l. 297) ; **le lavis (D,
défaut acté, H-ISO1) n'utilise ni l'un ni l'autre** (l. 300-317). Ces lectures sont déjà passées derrière le `l <= 0` : seul
le sol éclairé les paie. Le style est un uniforme que le compilateur de Godot ne connaît pas ; le compilateur du pilote pourrait en
sortir certaines (non vérifiable ici) — d'où l'A/B. Les touches 1-4 et F2 qui changent la pâte sont réservées au débogage
(`presentation_3d.gd:2259`).

**Coût** : PROUVÉ ; ESTIMÉ : 5 x (lecture 25 + `ton_du_sol` 13 + luminance 3 + décalage) ≈ 215 ALU-éq par pixel de sol éclairé, soit
**≈ 0,13 à 0,21 G** (27 % de 2,2 à 3,7 Mpx). **Proposition** : `if (style != PATE_LAVIS) { ...les cinq lectures... }` (branche uniforme,
sans divergence), `pente = vec2(0.0)` et `decalee = l` sinon. **Gain attendu** : ≈ 0,05 à 0,2 ms. **Risque** : nul pour l'image ;
même retouche dans `sol_iso_eclaire` (garde `test_banc.gd:330-331` : les fonctions doivent y rester identiques) et
`lightmap_pateuse` (dessus de muret). **Effort** : S. **Sévérité** : MINEUR. **Statut ROADMAP** : NOUVEAU. **Comment le vérifier** : A/B
du banc de cadence ; image identique (0 pixel).

---

### SHA-06 — La vignette de dégâts est un `ColorRect` plein cadre dessiné à chaque image avec un alpha de 0

**Où** : `player.gd:795-810` ; `damage_vignette.gdshader:20-33`.

**Constat** :
```gdscript
var vignette_rect = ColorRect.new()
vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
...
ui_layer.add_child(vignette_rect)          # visible, jamais masqué
```
```glsl
COLOR.a = vignette_color.a * zone * h * step(0.03, intensity);   // l. 32 : 0 hors coup et hors pouls sous 30 PV
```
Aucun code ne pose `visible` sur ce rect (grep `vignette_rect` : l. 795-810 seulement). L'intensité n'est > 0 que 0,6 s après un coup et
en pouls sous 30 PV (`player.gd:1294-1301, 2859-2869`). Un item sans alpha visible est dessiné quand même : le moteur ne sait pas ce que
le shader écrit.

**Coût** : PROUVÉ ; ESTIMÉ : 3,69 Mpx x ≈ 28 ALU-éq (une `sqrt`, une division, `fract`, trois `step`) + un mélange plein cadre par
image ≈ **0,1 G**, soit ≤ 0,1 ms. **Proposition** : `vignette_rect.visible = false` à la création ; `true` aux trois endroits qui écrivent
`intensity` (coup, pouls, extinction), `false` dans le callback de fin du `Tween`. **Gain attendu** : 0,05 à 0,1 ms de façon certaine.
**Risque** : nul (hors des 0,6 s d'affichage, le résultat est déjà transparent) ; aucune suite ne lit sa visibilité (grep sur
`tools/`). **Effort** : S. **Sévérité** : MINEUR. **Statut ROADMAP** : NOUVEAU. **Comment le vérifier** : compteur d'objets dessinés /
A-B sur le banc de cadence.

---

### SHA-07 — Le voile plein et la killcam demandent un tampon d'écran avec mipmaps, qu'ils n'échantillonnent qu'au niveau 0

**Où** : `voile_eblouissement.gdshaderinc:245` ; `killcam_overlay.gdshader:20` (lectures l. 52, 58-61) ; `distorsion_eblouissement.gdshader:6`
(orphelin).

**Constat** :
```glsl
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
...
float r = texture(screen_texture, SCREEN_UV + decalage).r;   // décalage ≪ 1 texel de gradient : niveau 0
```
Les quatre autres lecteurs d'écran utilisent `filter_linear` (`menu_glass.gdshader:40`, `menu_veil.gdshader:21`,
`brouillage_flou.gdshader:44`, `pate_ecran_iso.gdshader:13`). **À ma connaissance du moteur** (non vérifiable dans ce dépôt), un filtre
`*_mipmap` sur `hint_screen_texture` fait générer la chaîne de mips du tampon copié à chaque image où l'item est dessiné. Aucune
occurrence de ce sujet dans la ROADMAP ni dans `docs/*.md` (grep).

**Coût** : le choix du filtre est PROUVÉ ; l'effet est ESTIMÉ : la copie plein cadre coûte déjà 0,53 ms MESURÉS avec le voile plein
(l. 26533) ; une chaîne de mips ajoute au moins un passage de réduction par niveau. Ne concerne que les éblouissements forts et la
killcam (jamais au repos). **Proposition** : `filter_linear` dans les deux fichiers (image identique : les prises sont à ≈ 1 texel
de gradient). **Gain attendu** : inconnu, à mesurer (ESTIMÉ 0,1 à 0,3 ms pendant l'événement). **Risque** : nul. **Effort** : S.
**Sévérité** : MINEUR. **Statut ROADMAP** : NOUVEAU. **Comment le vérifier** : plan `loupe-cout-voile` forcé à 1,0, A/B des deux
filtres ; image à 0 pixel d'écart.

---

### SHA-08 — La zone morte des murets s'exécute dans `light()` du sol sur toutes les cartes, y compris les six cartes de duel livrées qui n'ont aucun muret ; et elle coûte +4 ms à 40 murets

**Où** : `murs_bas_sol.gdshader:12-19` ; `murs_bas_zone.gdshaderinc:96-138` ; `murs_bas_rendu.gd:101-104` ;
`game_state.gd:1497, 1512, 1544-1553, 5979-5986`.

**Constat** :
```glsl
void light() {
	if (mb_dans_la_zone_morte(LIGHT_POSITION, LIGHT_VERTEX)) { LIGHT = vec4(0.0); }
	else { LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * LIGHT_ENERGY, LIGHT_COLOR.a); }   // = le défaut du moteur (l'en-tête le dit)
}
```
Pour une torche (`source.z = 0`), la fonction calcule `length(cible - src)` et la borne, puis boucle sur `mb_nb_murs` : **0 tour** sur les
six cartes livrées, mais le prologue (≈ 25 ALU-éq) tourne pour chaque couple (fragment, lumière) du sol. `game_state.gd:5982-5985`
sait déjà que `murs_bas.is_empty()` (il ne pousse alors qu'une fois). À l'autre bout, la boucle (sortie anticipée exacte par mur,
l. 123-127) coûte ∝ nombre de murets à l'écran : **MESURÉ-ROADMAP l. 30046-30048 et `docs/MURS_BAS.md:535-547` : « aucun mur »
5,19 ms (4,07 au meilleur tour) contre 4,30 ms avec l'ancien matériau — dans le bruit —, 5 murs 4,47 ms, 40 murs 8,69 ms** (2560x1440,
écran scindé, « ordre de grandeur, pas un relevé au protocole »). 18 niveaux d'aventure sur 100 ont des murets, jusqu'à 44 rectangles
(Q2) ; `chapitre_07/niveau_08` a 244 cases de muret sur 1 036.

**Coût** : (a) sans muret, ESTIMÉ 0,15 à 0,3 G (≈ 0,15 ms au plus), que la mesure de MB3c ne distingue pas du bruit ; (b) à 37-44
murets, MESURÉ ≈ +4 ms en écran scindé 1440p (vue unique : non mesuré, même surface de lightmap).

**Proposition** : (a) quand `murs_bas.is_empty()` (à `rebuild_arena`, `game_state.gd:1512` et `1551`), poser le `CanvasItemMaterial`
additif d'avant MB3c au lieu de `MursBasRendu.materiau_sol()` (et `materiau_decor()`) : image identique (en-tête de
`murs_bas_sol.gdshader` : « 0/255 d'écart avec l'ancien matériau hors zone ») ; `_materiaux_zone_morte` ne reçoit que des
`ShaderMaterial` (`game_state.gd:1547`), la liste reste vide et la poussée s'arrête. (b) avec murets nombreux : une structure qui
évite de tester les 64 murs à chaque couple — une petite texture de buckets (un texel par cellule de 64 px, ≤ 4 indices de murs)
lue en 1 fetch ; **un simple masque de proximité (comme `usure_proximite`, `iso_materiaux.gd:466`) aide peu sur les labyrinthes
denses** (presque tout le sol y est à moins de L, 44 à 58 px, d'un muret). Effort L, à concevoir.

**Gain attendu** : (a) ≤ 0,15 ms, non démontré ; (b) jusqu'à 2-3 ms sur les deux niveaux d'aventure à plus de 30 rectangles.
**Risque** : (a) nul pour l'image ; `tools/banc_murs_bas.gd:111,252` lit `CustomFloor_P%d` (sur la carte d'essai, qui a des murets :
inchangé) ; `test_murs_bas_rendu.gd` appelle directement `MursBasRendu.materiau_sol()` (l. 107, 126), non touché. (b) l'équité des
murets est une règle de jeu (« un même angle ») : toute retouche se prouve par `tools/banc_murs_bas.tscn` à 0/255. **Effort** : S (a),
L (b). **Sévérité** : MINEUR pour (a) ; (b) MAJEUR sur ces 2 niveaux. **Statut ROADMAP** : (b) CONNU-OUVERT (l. 30046-30048 : « loin de
la cible ») ; (a) NOUVEAU. **Comment le vérifier** : `tools/banc_murs_bas.tscn` (40 murets) ; banc de cadence sur `map_001` avec/sans
le matériau ; recharger `chapitre_07/niveau_08`.

---

### SHA-09 — ≈ 270 à 290 poussées d'uniformes et ≈ 100 chaînes formatées par image, dont une majorité de constantes

**Où** : `presentation_3d.gd:799-824, 886-901` ; `iso_volumes.gd:854-866, 1908-1927, 2085-2125` ; `iso_nuage_voxel.gd:519-522, 648-676` ;
`iso_materiaux.gd:83-84` ; `ui.gd:2526-2528, 2543, 8881`.

**Constat** (PROUVÉ par lecture ; décompte pour un duel de base, vue unique, deux torches) :

| Site | Appels / image | Dont constants |
|---|---|---|
| `Presentation3D._suivre` : `style` x5, `canevas_N_{x,y,o}`+`taille_N` x5 matériaux (l. 799-824), `centre` et `opacite_N`/`silhouette_N` des corps (l. 886-901), contact | ≈ 45-50 (≈ 65-85 en scindé) | `style` (5) |
| `IsoVolumes._pousser_lightmaps` (l. 2119-2125) : 8 matériaux x 6 (`lumiere_N`, 3 canevas, `taille`, `style`) | 48 | `style`, `lumiere_N` |
| même fonction : contact (2 noms) et usure (2 noms) recopiés par matériau, avec `get_shader_parameter` (l. 2104-2110) | ≈ 64 | usure |
| `_poser_couches` : 9 pushes x 3 couches x 2 lampes | 54 | `masque`, `avec_masque`, `nuage_angle` |
| `_poser_longueur` (`fondu_air` constant), `_poser_juge`, `_tailler_faisceau_air` | ≈ 20 | `fondu_air` |
| lentilles et éclats (halos) | ≈ 30 | couleur, orientation |
| `ui._poser_voile` | 5 + `RenderingServer.shader_get_parameter_default` (l. 2527) x 2-3 par image | `aberration_debut` |
| par nuage et par vue : `poser_style` (2), `poser_fusee`/`poser_gadget` (≈ 16 + `get_shader_parameter` x15), juge (3) | ≈ 36 par nuage-vue | `encre_style`, `relief_style` |

Plus un formatage `"canevas_%d_x" % n` à chaque appel, des tableaux typés reconstruits (`_materiaux()` x3-4 par image), et
`IsoNuageVoxel.poser_style` → `IsoMateriaux.beaute_active()` → `DrapeauxDeLancement.arguments()` qui **concatène deux
`PackedStringArray` à chaque appel** (`iso_materiaux.gd:83-84`).

**Coût** : ESTIMÉ 0,1 à 0,4 ms de CPU par image (≈ 0,5 µs l'appel + la remise à jour du bloc d'uniformes de chaque matériau sali,
une fois par image, différée par le moteur). **Proposition** : (1) ne pousser `style` et `lumiere_N` qu'au changement ; poser `fondu_air`,
`masque`, `avec_masque` une fois ; mettre en cache `beaute_active()` et `aberration_debut()` (`static var`) ; (2) option L : des
**uniformes globaux** (`global uniform`, `RenderingServer.global_shader_parameter_set`) pour `canevas_N_*`, `taille_N`, `style`,
`lumiere_N` — une poussée au lieu de ≈ 100 et plus aucune divergence possible entre matériaux ; touche ≈ 40 déclarations et les
suites qui relisent `get_shader_parameter`. **Gain** : ≈ 0,1 à 0,2 ms CPU (1), un peu plus avec (2). **Risque** : (1) nul ; (2) élevé
en nombre de gardes. **Effort** : S (1) / L (2). **Sévérité** : MINEUR. **Statut ROADMAP** : NOUVEAU (même réflexe déjà appliqué à la
fusée : `fusee.gd:289-293`). **Comment le vérifier** : un compteur d'appels dans un bench ; profileur du débogueur sur
`Presentation3D._process` et `IsoVolumes.suivre`.

---

### SHA-10 — Une face de mur lit 12 textures dont 8 pour une moyenne le long de la face, dont la raison d'être (les hachures du pied) a disparu

**Où** : `mur_iso.gdshader:95-143, 194-195, 228` ; `iso_materiaux.gd:362-369` ; `mur_encre.gd:51`.

**Constat** : `lire_lumiere_moyenne` = 4 x (lightmap + peinture) = 8 lectures, posées pour effacer les rayures des hachures d'encre du
pied des murs (ROADMAP l. 26068-26074 : « quatre lectures moyennées le long du mur sur une période de hachure ») ; depuis ISO10-1b le
pied est un lavis (`mur_encre.gd:51` : « un LAVIS, plus une bande de hachures »). Deux autres lectures (`lire_etalon`, des constantes de
la carte) sont refaites **par fragment**, y compris sur les ≈ 1,1 Mpx de dessus de murs hauts, noirs (l. 193-195). `lambert_plancher` à 1,0
(`iso_materiaux.gd:376`) laisse le Lambert éteint : ses 4 lectures ne tournent pas.

**Coût** : ESTIMÉ ≈ 0,3 Mpx x 8 + 1,4 Mpx x 2 ≈ 5 M de lectures, ≈ 0,02 à 0,05 ms. **Proposition** : (a) les étalons en uniformes (lus une
fois à `accorder_peinture`) ou déplacés dans les branches qui les utilisent ; (b) tester une ou deux prises au lieu de quatre —
**change légèrement l'image** : à Adrien et au banc (`banc_iso_beaute`). **Gain** : ANECDOTIQUE à MINEUR. **Effort** : S.
**Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : NOUVEAU.

---

### SHA-11 — Nuages de voxels : chaque sommet recalcule l'état de sa cellule (2 `cube_de` par défaut), à ≈ 110 000 sommets par vue et par fusée

**Où** : `nuage_voxel_iso.gdshader:409-426, 460-497, 501-562, 564-647` ; `iso_nuage_voxel.gd:388-400, 434-463` ; `iso_volumes.gd:1677-1680`.

**Constat** : la maille d'un cube a 12 sommets (3 faces x 4, `iso_nuage_voxel.gd:446-454`) ; **chacun** exécute `cube_de(c)` (`bouffees` =
fbm de 12 `sin` pour la fusée, avant la sortie rapide par hauteur, l. 469 puis 477 ; puis `densite_2d` → `voile_alpha`, 12 `sin` +
boucles, + 3 nappes), puis `cube_de(voisin)` (l. 584), puis `lumiere_lissee` (9 lectures) et `pate()`. Avec l'encre par défaut « volutes »
(`encre_style` = 2, `iso_nuage_voxel.gd:93`), la branche `encre_style == 1` (l. 640) n'est pas prise : 2 `cube_de` par sommet ; l'encre « arêtes »
(essai) en ajoute deux (`aretes_de` → `voisin_de`, l. 533-553). Grilles (calcul exact du code) : fusée ≈ 9 136 cellules par vue (= 109 632 sommets ; les « 18 272 cubes » de la ROADMAP
l. 31281 pour deux vues), poussière 2 176, suie 1 124. Le juge est la plus grosse part de la surface : « 842 803 fragments sur 1 193 452
pour la fusée » (l. 31282).

**Coût** : ESTIMÉ ≈ 500 ALU-éq par sommet en moyenne (≈ 1 300 pour un sommet plein, ≈ 120 pour une cellule vide) → ≈ 0,05 à 0,1 G par vue et par
fusée : **négligeable sur le M3**, à surveiller sur GPU intégré bas de gamme et avec plusieurs fusées. Le cloud (llvmpipe) ne peut pas le
dire (l. 31299-31302). Les fragments du juge croissent avec l'aire de la vue : le banc cloud ne rappelle pas sa résolution, à 1440p en
vue unique ils sont plus nombreux (non mesuré). **Proposition** : (i) resserrer le disque du juge — la ROADMAP la nomme « la prochaine
économie, non faite » (l. 31282-31283) : le rayon vaut `rayon x 1,05 + voxel + 0,13 x haut + 3` puis `+ haut` à l'échelle
(`iso_volumes.gd:1677-1680`) ; (ii) si une mesure sur GPU faible le justifie, précalculer l'état des cellules dans une texture R16F
une fois par image et par nuage (un passage de 60x60 pixels) que le sommet lit en 1 fetch. **Risque** : élevé (équité du noir,
pochoir) pour peu de gain sur la machine de référence. **Effort** : M (i), L (ii). **Sévérité** : MINEUR. **Statut ROADMAP** :
CONNU-OUVERT (l. 31282-31283, 31299-31302).

---

### SHA-12 — Sept shaders, un script de 410 lignes et un orphelin sont préchargés ou compilés pour rien en production, et leurs forks imposent des retouches miroir aux gardes

**Où** : `presentation_3d.gd:107-117` (`SHADER_SOL_ECLAIRE`, `SHADER_MUR_ECLAIRE`, `SHADER_CORPS_ECLAIRE`, `SHADER_PATE_ECRAN`,
`SHADER_PATE_VUE`, `SHADER_CORPS`, `SHADER_CORPS_PROFONDEUR`) ; `lumieres_iso.gd` ; `distorsion_eblouissement.gdshader` ;
`tools/test_banc.gd:325-372`.

**Constat** : `poser_lumiere_3d` n'est appelé par aucun script de jeu (§ 0) ; `variante_pate_3d` reste à 0 (`presentation_3d.gd:274`) ;
`--corps-grossiers` est un drapeau de débogage (l. 1917). Ce lot : `sol_iso_eclaire` 391 + `mur_iso_eclaire` 418 + `corps_iso_eclaire` 418 +
`iso_relief` 307 + `pate_ecran_iso` 22 + `pate_vue_iso` 16 + `corps_grossier_iso` 126 + `corps_profondeur_iso` 37 (**code identique**
à `corps_iso_profondeur`, diff hors commentaires) + `lumieres_iso.gd` 410 ≈ **2 150 lignes**. `distorsion_eblouissement.gdshader`
n'est référencé nulle part (ROADMAP l. 22506-22508). Doublons de `light()` : `capteur_*` = `player_*_light` + `light_only`,
`murs_bas_decor` = `murs_bas_sol` − `blend_add`.

**Coût** : analyse au démarrage ≈ 1-3 ms par shader (ESTIMÉ) ; surtout un coût de maintenance : toute retouche de `sol_iso`/`mur_iso`
(SHA-04, 05) doit être recopiée dans un fork que personne ne joue — la garde `test_banc.gd:325-372` l'exige ligne à ligne. **Proposition** :
déplacer les forks et leur script dans `tools/` (ou les charger par `load()` dans les seuls bancs) ; supprimer
`distorsion_eblouissement` ; mettre les `light()` communs dans un `.gdshaderinc`. **Gain** : démarrage ≈ −10 à −20 ms ; fin de la
dérive miroir. **Risque** : les bancs (`banc_lumiere3d`, `bench_framerate`, `photographe`) passent par `Presentation3D` : à rediriger.
**Effort** : S. **Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : CONNU-OUVERT pour l'orphelin (l. 22506-22508) ; NOUVEAU pour les forks.

---

### SHA-13 — Le hash `fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453)` coûte un `sin` par prise et n'est pas reproductible d'un GPU à l'autre

**Où** : `iso_pate.gdshaderinc:46-48` ; `fumee_fusee.gdshader:49-51` ; `nuage_voxel_iso.gdshader:246-248` ; alternative déjà dans le
dépôt : `menu_hatch.gdshader:67-71` (hash de Hoskins sans `sin`).

**Constat** : un bruit de valeur = 4 hash = 4 `sin` ; le lavis de la pâte en fait 2 par pixel éclairé (8 `sin`), l'usure 5 par pixel de sol et 17 et plus
par pixel de face, le nuage plusieurs dizaines par sommet (12 `sin` par fbm, deux fbm par `cube_de`). Avec un argument de l'ordre de 10^4 à 10^5 (coordonnées du monde), `sin` en simple précision dépend de la réduction
d'argument du GPU, puis est amplifié x43 758 : **les motifs diffèrent entre Apple, Intel, AMD et NVIDIA** (ESTIMÉ ; non vérifiable
ici). Conséquences : l'usure, le grain du lavis et la forme des cubes d'un nuage ne sont pas les mêmes sur deux machines ; les règles
de jeu, elles, viennent du modèle CPU (`occultation_pour`) : **aucune règle n'est touchée**. **Proposition** : un hash arithmétique
(Hoskins) à la place : retire 10 à 17 transcendantes par pixel de sol éclairé et rend les motifs portables. **Risque** : **l'image
change** (autres motifs de bruit) : à valider par Adrien sur planche ; les miroirs CPU (`iso_pate.gd`) sont à refaire. **Effort** : M.
**Sévérité** : MINEUR. **Statut ROADMAP** : NOUVEAU. **Comment le vérifier** : deux machines (Apple et autre), même prise `loupe`,
comparer la tache d'usure en un point.

---

### SHA-14 — Un `ShaderMaterial` neuf par tache de sang et deux par balle

**Où** : `blood_stain.gd:320-321` ; `miroirs_iso.gd:352-359, 389-398`.

**Constat** : toutes les taches utilisent le même shader sans paramètre (`blood_shader.gdshader`, `fragment()` vide) ; chaque `setup()`
crée sa matière (≤ 120 + copies J2). Chaque balle crée deux `MeshInstance3D` et deux `ShaderMaterial` qui ne diffèrent que par
`couleur`/`repetition`/`texture_quad`. **Coût** : ANECDOTIQUE (une allocation de matériau par événement ; les taches changent de texture
à presque chaque item, donc le lot casse de toute façon). **Proposition** : un matériau statique partagé pour les taches (`static var`,
comme `kill_shockwave.gd:51-62`) ; pour les balles, un pool de quads. **Gain** : négligeable. **Effort** : S. **Sévérité** :
ANECDOTIQUE. **Statut ROADMAP** : NOUVEAU.

---

## 3.bis Pistes déjà tranchées, mesurées ou refusées (ne pas rouvrir)

- **Rayon dans l'air** : couches en éventail (`faisceau_taille`), juge taillé (A), longueur de l'ancienne torche (D), portée au bord le
  plus proche (Q76) — faits et mesurés (rapport de cadence à la 0.7.1 : A+D 0,861 au vrai cadrage / 0,930 au cadrage du banc,
  l. 30777-30781 ; Q76 1,007 / 0,893, l. 30909-30912). **Un éventail d'un triangle par degré n'allège rien** (l. 3632-3642).
- Il reste, « sans changer l'image », de ne juger hors du cône que là où une fumée peut lire son pochoir (l. 30651-30654) : non fait,
  touche le juge partagé avec la fumée.
- Le masque de fumée par couche a été remplacé par le pochoir/juge (Q31, V5) : ne pas revenir à `masque_montre_noir` par couche.
- **Le voile au repos ne lit pas l'écran** (ISO10-1a, fait : l. 26514-26536, 4305-4317) ; **ne pas le cacher** (mise en page de
  l'`HBoxContainer`, `ui.gd:2436-2451`).
- `Shader.new()` à la volée dans l'action : proscrit (CLAUDE.md, `presentation_3d.gd:2233-2234`) — SHA-02 en est l'application aux
  variantes.
- MSAA 2D : proscrit ; le MSAA 3D x4 des vues iso est un choix mesuré (`presentation_3d.gd:118-123`).

## 3.ter Signalé hors périmètre (non corrigé)

- CPU : `presentation_3d.gd:2218` (`get_nodes_in_group("wall_impact")`, appelé depuis `_suivre_usure`, l. 522, à chaque image) et
  `iso_volumes.gd:1128` (`get_nodes_in_group("plafonniers")`) allouent un `Array` par image ; `IsoVolumes.suivre` parcourt aussi
  `arena.get_children()` et teste `get_script()` sur chacun, à chaque image (l. 427-429). Négligeable chacun, à regrouper par la mission
  ISO/GEO.
- Les capteurs de corps (`capteur_corps.gd:88-90` : 256x256, `UPDATE_ALWAYS`) sont des passes de rendu complètes (2 en vue unique,
  4 en scindé, +1 par figurant et par objet) : coût fixe par passe sur GPU à tuiles, à voir avec la mission LUM.
- Les trois nappes de la fusée sont des textures de 1024x1024, 2048x2048 et 2048x2048, non compressées et **sans mipmaps**
  (`assets/sprites/fusee_volute*.png.import`, `mipmaps/generate=false`), dessinées à quelques centaines de pixels : ≈ 37 Mo de VRAM et
  lectures minifiées sans mip. Relève des assets (mission DEM).

---

## 4. Ce qui est déjà bien fait (à ne pas casser)

1. **Variantes par `#define`** plutôt que par uniforme : le programme par défaut ne contient pas le code des essais, et la règle « un
   coût derrière un uniforme ne se voit pas » est consignée (ROADMAP l. 4258-4269 ; `iso_pate.gdshaderinc:242-245`). Deux shaders
   pour le voile (`voile_eblouissement` / `_calme`) : un voile qui ne montre rien ne copie pas l'écran (0,53 ms rendus).
2. **L'opacité d'abord, la couleur ensuite**, `discard` avant toute lecture de lumière (`volume_iso.gdshader:151-185`) ; aucun `discard`
   dans le sol et les murs opaques.
3. **Hygiène des copies d'écran** : `BackBufferCopy` masqués hors usage (`ui.gd:2620-2624`, `game_state.gd:635-640`), `COPY_MODE_RECT`
   pour le flou (`brouillage_vue.gd:70`), `death_flash` sans lecture d'écran (`death_flash.gdshader:6-10`).
4. **Le rayon taillé à son cône** et ses enveloppes calculées au décompte, jamais à l'image d'allumage (`iso_volumes.gd:688-693`) ;
   images dérivées du nuage préparées au lancement ; proximité des murs préparée une fois par carte (`presentation_3d.gd:2199-2203`,
   levier 1 de l'usure).
5. **Un matériau pour tous les murs, un pour les trois nappes, des constantes poussées une fois** (`fusee.gd:289-293` : « huit poussées
   par tick, dont cinq constantes »), matériau 2D statique partagé (`kill_shockwave.gd:51-62`).
6. **Nuages de voxels** : faces cachées écrasées dans le sommet (`nuage_voxel_iso.gdshader:571-604`), une grille partagée par type et
   par côté de caméra (`iso_nuage_voxel.gd:404-429`), ordre du peintre sans tri (énumération inversée selon le côté, l. 388-400), le
   juge à pochoir au lieu du masque par couche.
7. **Les dérivées et les lectures mipmappées sont prises hors branchement partout où c'est nécessaire**, avec le piège documenté
   (`sol_iso.gdshader:132`, `volume_iso.gdshader:146-148`, ROADMAP l. 4010).
8. **Gardes qui rendent une optimisation exacte prouvable à 0 pixel** : parité sol/mur ↔ masque de fumée, forks `*_eclaire`
   (`test_banc.gd:325-372`), usure (`test_iso_usure`), formes du masque ; `_pousser_zone_morte` ne repousse rien sans muret
   (`game_state.gd:5982-5985`) ; `menu_veil` se retire du dessin à intensité nulle.

---

## 5. Questions ouvertes (mesure, ou Adrien)

1. **Durée réelle d'une compilation sur le Mac** pour `volume_iso` (couche, juge) et `nuage_voxel_iso` : le chiffre de 143-150 ms vient des
   lampes éclairées d'ISO12. `banc_pics` + horodatage du premier `_couches` la donnent ; et ils disent si le pilote met les programmes
   en cache d'un lancement à l'autre (les relevés, un processus neuf chacun, suggèrent que non).
2. **Pilote GL réel du Mac** : champ `pilote` de `user://match_history.json` (`conditions_de_match.gd:168`). Il décide de SHA-01,
   SHA-07 et SHA-13.
3. **Part du temps de manche torche allumée** (le voile calme ne coûte que dans ce cas) et **coût isolé du voile calme** : ajouter un
   bras « voile masqué » au plan `loupe-cout-voile`. C'est la mesure qui calibre aussi le taux ms/G de § 0.
4. **Le voile à 2-4/255 au repos est-il voulu tel quel ?** (« aucun pixel n'y est à 0 », l. 30744) — c'est ce qui permet SHA-03 option 1
   sans changer l'image ; une décision de direction artistique pourrait aussi ne dessiner que le lavis sous `aberration_debut` (les
   lueurs, flares et fantômes y pèsent 1-2/255).
5. **Le coût de l'usure après le levier 1** : je n'ai trouvé aucune valeur isolée postérieure au 0,944 de la ROADMAP (l. 28420 ; la
   recherche « levier 1 » ne renvoie que l. 2493, 28420, 28439) ; l. 2490 ne donne que l'état intégré (usure + 45° B : médiane 80-82,
   1 % bas 69-76). À remesurer avant SHA-04 pour fixer le gain en ms.
6. **Les pâtes A, B, C** (gravure, ligne claire, trame) ne vivent plus qu'au débogage : les retirer du shader de production
   simplifierait `pate()` et SHA-05 ; décision d'Adrien (H-ISO1 a tranché D).
7. **Quatre prises moyennées sur les faces** (SHA-10) : sont-elles encore nécessaires depuis le lavis du pied ? Comparaison sur
   `banc_iso_beaute`.
8. **Portabilité du bruit** (SHA-13) : accepte-t-on que l'usure et les nuages diffèrent légèrement d'un GPU à l'autre (c'est le cas
   aujourd'hui) ou veut-on les rendre identiques ?
9. **Les variantes internes du moteur** (éclairage 2D avec ombres, MSAA 3D, passes de profondeur) compilent aussi au premier usage :
   seule une mesure (`banc_pics`) dira si elles ajoutent un hoquet que la chauffe de SHA-01 devrait couvrir.

---

## Annexe A — Inventaire des 59 fichiers

Légende : *défaut* = actif dans un duel iso lancé sans drapeau ; *banc* = outils/débogage seulement ; surfaces ESTIMÉES à 2560x1440.
Nombres de lignes relevés par `wc -l` (total 7 975).

| Fichier | Lignes | Instancié par (fichier:ligne) | Quand | Combien | Surface / remarque |
|---|---|---|---|---|---|
| `sol_iso.gdshader` | 169 | `presentation_3d.gd:103,1895-1905` ; variante USURE `iso_materiaux.gd:184` | défaut | 2 matériaux, 1 visible en vue unique | 2,2-3,7 Mpx — SHA-04/05 |
| `mur_iso.gdshader` | 283 | `presentation_3d.gd:104,1887-1890` | défaut | 1 matériau pour toutes les boîtes (4-11 hautes par carte de duel ; jusqu'à 44 murets en aventure) | faces ≈ 0,3, dessus ≈ 1,1 Mpx — SHA-04/10 |
| `corps_iso.gdshader` | 341 | `voxel_corps.gd:81,283-284`, `voxel_objets.gd:74,135-136`, `presentation_3d.gd:110` | défaut | 1 par corps (2 joueurs + ≤ 8 figurants), 1 par objet posé | ≈ 0,03 Mpx par corps |
| `corps_iso_profondeur.gdshader` | 40 | `voxel_corps.gd:82,304-305`, `voxel_objets.gd:75,151-152`, `iso_materiaux.gd:279` | défaut | 1 par corps/objet, x 9-14 boîtes | idem |
| `corps_iso_contour.gdshader` | 47 | `voxel_corps.gd:84,370-371` | banc (`--encre-essai`) | 0 | |
| `corps_grossier_iso.gdshader` | 126 | `presentation_3d.gd:115,1917` | banc (`--corps-grossiers`) | 0 | SHA-12 |
| `corps_profondeur_iso.gdshader` | 37 | `presentation_3d.gd:117,1926` | banc | 0 | doublon exact de `corps_iso_profondeur` |
| `sol_iso_eclaire` / `mur_iso_eclaire` / `corps_iso_eclaire` | 391 / 418 / 418 | `presentation_3d.gd:107-109` | banc (lumière 3D) | 0 en jeu | SHA-12 |
| `volume_iso.gdshader` | 249 | `iso_volumes.gd:38,1743-1798,1888-1990` | défaut | rayon : 3 couches + 1 juge par lampe allumée ; nappes ; toile ; 5 variantes | ≈ 0,5 Mpx |
| `nuage_voxel_iso.gdshader` | 730 | `iso_nuage_voxel.gd:129-142`, `iso_volumes.gd:1589-1630` | défaut (gadgets, fusée) | 1 `MultiMeshInstance3D` par nuage et par vue + juge | SHA-11 |
| `halo_iso.gdshader` (+ `.gdshaderinc`) | 7 (+65) | `iso_volumes.gd:39,2027-2040` | défaut | lentille 2/joueur allumé, éclat, comète, braises (16/nappe), mine, plafonnier | < 0,01 Mpx |
| `halo_iso_melange.gdshader` | 8 | `iso_volumes.gd:41,515,548` | défaut (fusée posée) | 2 par fusée | idem |
| `quad_iso.gdshader` | 22 | `miroirs_iso.gd:27,389-398`, `iso_volumes.gd:42,1271` | défaut | viseur + ligne x 2 joueurs, onde de mort | petit |
| `quad_iso_additif.gdshader` | 17 | `miroirs_iso.gd:28,357-358` | défaut (tir) | 2 par balle | petit — SHA-14 |
| `grain_iso.gdshader` | 36 | `iso_volumes.gd:89,1481` | banc (`--nappes-voxels`) | 0 | |
| `pate_ecran_iso` / `pate_vue_iso` | 22 / 16 | `presentation_3d.gd:113-114,2098-2128` | banc (pâte 2) | 0 | SHA-12 |
| `murs_bas_sol.gdshader` | 19 | `murs_bas_rendu.gd:13,101`, `game_state.gd:1512` | défaut | 1 matériau par vue (copie du sol) | 2,07 Mpx x lumières — SHA-08 |
| `murs_bas_decor.gdshader` | 17 | `murs_bas_rendu.gd:14,107`, `game_state.gd:1551` | défaut | 1 par vue | marques peintes |
| `player_rim_light` / `player_enemy_light` | 27 / 27 | `player.gd:9-10,773-780`, `gadget_leurre.gd:51,215` | défaut | 1 matériau par joueur (+ leurre) | ≈ 50x50 px |
| `capteur_local` / `capteur_adverse` / `capteur_objet` | 29 / 36 / 11 | `capteur_corps.gd:67-68,119-120`, `miroirs_iso.gd:26,229-244` | défaut | 2 (vue unique) à 4 (scindé) + 2 par objet posé + figurants | disque 36 px dans 256x256 |
| `blood_shader.gdshader` | 22 | `blood_stain.gd:32,320-321` | défaut (après touche) | 1 par tache (≤ 120 + copies) | SHA-14 |
| `fumee_fusee.gdshader` | 143 | `fusee.gd:17,287-288,353-354` | défaut (fusée) | 1 voile par fusée | quad ≈ 400-500 px |
| `nappe_fusee.gdshader` | 39 | `fusee.gd:20,265-266` | défaut (fusée) | 1 matériau, 3 nappes (2 en scindé) | textures 1024² / 2048² / 2048² |
| `ghost_unshaded.gdshader` | 10 | `game_state.gd:6,1690-1691` | killcam | 2 fantômes | petit |
| `damage_vignette.gdshader` | 33 | `player.gd:11,801-802` | **défaut, en permanence** | 1 plein cadre par joueur regardé | 3,69 Mpx — SHA-06 |
| `death_flash.gdshader` | 33 | `player.gd:12,2987-2988` | mort (0,6 s) | 1 | plein cadre |
| `killcam_overlay.gdshader` | 96 | `ui.gd:15,3819-3820` | killcam | 1 (+ calque iso par vue) | plein cadre — SHA-07 |
| `voile_eblouissement.gdshader` (+ `.gdshaderinc`) | 7 (+463) | `ui.gd:67,2453` | défaut si éblouissement >= 0,12 | 1 par joueur regardé | plein cadre + copie — SHA-07 |
| `voile_eblouissement_calme.gdshader` | 9 | `ui.gd:69,2463-2464` | **défaut, torche allumée** | 1 par joueur regardé | 3,69 Mpx — SHA-03 |
| `distorsion_eblouissement.gdshader` | 33 | aucun | jamais | 0 | SHA-12 |
| `brouillage_flou.gdshader` | 162 | `brouillage_vue.gd:43,78-80` | défaut (brouillage) | 1 par vue | ellipse de l'émetteur |
| `menu_hatch.gdshader` | 220 | `menu_hatch_rect.gd:15,123` | menus + HUD (alerte PV) | menus ; 2 barres de vie | HUD ≈ 300x20 px |
| `menu_artwork` / `menu_bg_blur` | 222 / 42 | `menu_hub.gd:436-438`, `menu_artwork.gd` | menu | 1 fond plein écran | 9 prises par pixel même sans flou (menu) |
| `menu_backdrop` / `menu_glass` / `menu_pate` / `menu_skeleton` / `menu_title` / `menu_veil` | 146 / 120 / 36 / 60 / 93 / 77 | `menu_backdrop.gd:30`, `menu_glass.gd:32`, `menu_widgets.gd:20`, `menu_skeleton.gd:31`, `menu_title.gd:24`, `menu_veil.gd:19` | menus | un par panneau | non évalués en détail (hors duel) |
| `iso_pate` / `iso_lightmap` / `iso_usure` (`.gdshaderinc`) | 318 / 90 / 163 | inclus par sol, mur, corps, volume, nuage | défaut | | cœur du coût — SHA-04/05/13 |
| `iso_relief.gdshaderinc` | 307 | inclus par les `*_eclaire` | banc | | SHA-12 |
| `iso_corps_portrait` / `_mannequin` / `_detail` / `_soi_sombre` (`.gdshaderinc`) | 168 / 131 / 107 / 115 | `corps_iso.gdshader` | défaut / `#ifdef` | | portrait et mannequin sous uniforme (ROADMAP l. 4262-4269), detail et soi-sombre sous `#ifdef` |
| `murs_bas_zone.gdshaderinc` | 138 | inclus par `murs_bas_*`, `player_*_light`, `capteur_*` | défaut | | SHA-08 |
| `volume_masque` / `volume_masque_compact` (`.gdshaderinc`) | 475 / 289 | inclus par `volume_iso` (variantes `FUMEE_MASQUE`) | défaut | | copies gardées de sol/mur |
| `halo_iso.gdshaderinc` | 65 | inclus par `halo_iso*` | défaut | | |

## Annexe B — Pour mesurer (sans que j'aie lancé quoi que ce soit)

| Constat | Instrument existant |
|---|---|
| SHA-01 | `tools/banc_pics.tscn`, `tools/bench_framerate.tscn --seuil-lent 25`, `--chauffe-couverture` (bras témoin) |
| SHA-03 | `tools/loupe.gd` plan `loupe-cout-voile` (+ bras « masqué »), `tools/banc_voile.tscn` (réglage visuel) |
| SHA-04, 05, 10 | `tools/banc_iso_beaute.gd`, `tools/test_iso_usure.gd`, `tools/test_iso_beaute.gd`, `tools/test_banc.gd` (gardes), puis `bench_framerate.tscn` vue unique en miroir |
| SHA-06, 07 | `bench_framerate.tscn` A/B ; image identique via `loupe` |
| SHA-08 | `tools/banc_murs_bas.tscn` (40 murets), `tools/test_murs_bas_rendu.gd` |
| SHA-11 | `tools/banc_gadgets_volume.gd --mode=cout` (surface et appels), à refaire sur le Mac pour les sommets |
| SHA-09 | profileur du débogueur sur `Presentation3D._process` et `IsoVolumes.suivre` |
