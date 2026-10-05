# 04 — LUM : lumières 2D, occlusion, vision, éblouissement, brouillage, voile

Commit audité : `52a29c1` (0.8.3 + SOLO S12). **Lecture seule, Godot non lancé.** Tout ce qui touche au comportement du
moteur (passes d'ombre, copie d'écran, compilation des shaders) est une lecture du code du jeu, de sa ROADMAP et de ma
connaissance du moteur : je le marque **ESTIMÉ** ou « lecture du moteur par mémoire ». Les chiffres qui viennent d'un calcul
sur les données du dépôt sont **PROUVÉS** et reproductibles : quatre petits scripts Python (aucun Godot) sont dans
`docs/audit_optimisation/lum/`
(`occluders.py` : occulteurs par carte, réplique de `merge_rects`/`trace_contours` ; `cookies.py` : boîte de l'alpha des cookies ;
`solo_ombres.py` + sa sortie `solo_ombres.out` : modèle de la passe d'ombre, formule du banc `4 × N × L` ;
`flou_repos.py` : balayage du flou du brouillage quand l'émetteur est le regardeur). Les chiffres de temps qui en dérivent sont des ORDRES DE GRANDEUR (voir le calibrage de LUM-03), jamais des mesures.

Fichiers lus en entier : `map_geometry.gd`, `light_textures.gd`, `vision.gd`, `canaux_lumiere.gd`, `eblouissement.gd`,
`brouillage.gd`, `brouillage_vue.gd`, `brouillage_flou.gdshader`, `voile_textures.gd`, `voile_eblouissement.gdshaderinc`
(+ les deux enveloppes), `effect_policy.gd`, `regard_duel.gd`, `plafonnier.gd`, `mur_led.gd`, `lumieres_iso.gd`,
`etoile_de_corps.gd`, `capteur_corps.gd`, `particle_pool.gd`. Lus par tronçons : `player.gd` (lumières, torche, tir, impact),
`game_state.gd` (éblouissement, brouillage, rendu des vues, killcam), `ui.gd` (voile, `update_hud`), `fusee.gd`, `gadget_*`,
`presentation_3d.gd`, `miroirs_iso.gd`, `weapon_data.gd`, `settings_manager.gd`, `project.godot`, ROADMAP (sections citées).

---

## 1. Carte des chemins chauds

### 1.1 Par image de rendu (fps déplafonnés — chaque ligne tourne 60 à 500 fois par seconde)

| où | ce qui tourne | quantité au pire cas d'un duel |
|---|---|---|
| `game_state.gd:2081 _process` → `_maj_brouillage()` (l.2094 → 5856) | `BrouillageVue.maj` : 2 `Object.get` dynamiques (`brouillage_vue.gd:183-186, 193`), `Brouillage.flou()` et `halo()` (un `Dictionary` chacun), 3 à 5 appels du projecteur iso, 5 `set_shader_parameter`, `rect_photocopie` | 1 appareil en vue unique, 2 en écran scindé — **actif en permanence torche allumée (LUM-01)** |
| `game_state.gd:2197 _maj_eblouissement` (2360-2407) | `_sources_eblouissantes()` (un `Dictionary` par torche/fusée/gadget, 2 `get_nodes_in_group`) × cibles ; `facteur_de_lampe_a` (un `get_nodes_in_group("gadgets")` par appel, 4 appels/img) ; échantillonnage de l'`Image` du cookie (`Vision.intensite_texture`) ; **le rayon physique (`PhysicsRayQueryParameters2D.create` + 2 `Array` + `intersect_ray`, l.2772-2812) seulement si l'intensité du cookie est > 0** | 2 torches : 4 couples source×cible, 0 à 2 rayons |
| `game_state.gd:2343 ui.update_hud` → `ui.gd:2531 _poser_voile` (+ l.8804, 8873, 8878-8885) | 1 ou 2 voiles : `set_shader_parameter` ×1 à ×5, `EffectPolicy.curseur()` ×3-4 (un `get_node_or_null` + `has_method` chacun), `aberration_debut()` ×3 (un appel `RenderingServer.shader_get_parameter_default` chacun, `ui.gd:2526`), `iso.angle_ecran` | 1 voile plein cadre en vue unique, 2 demi-écrans en scindé |
| `player.gd:1259 _process` ×2 (+ PNJ) | publication de l'état répliqué (hôte, l.1262-1268), **`GadgetBase.effacements_a()` (appelé l.1319 ; `gadget_base.gd:625` : 2 `get_nodes_in_group` — « fusees » et « gadgets » — et des appels dynamiques `occultation_pour` / `masque_le_corps` par membre, par joueur et par image)**, deux tableaux littéraux (`[visual, visual_dim, visual_reveal]`, `[visual_enemy_ptr, …]`) par image, `_couper_l_ombre` (gardée par `if coupee == _ombre_coupee`, aucun appel serveur tant que l'état ne change pas), `AudioManager.set_dazzle_level` (l.1376) | 2 joueurs en duel ; **en solo chaque PNJ (un `Player` complet) refait la boucle des gadgets** |
| `mur_led.gd:371 _process` | `regler()` : `energy`, `color`, `enabled` (3 appels serveur) | 1 lumière |
| `particle_pool.gd:286 _process` → `advance` (l.290) | par particule active (≤ `MAX_ACTIVE` = 200, pic observé 122 : ROADMAP 34216) : 2 `get_node` + une écriture d'`energy` sur une `PointLight2D` **jamais allumée** (LUM-11) | ~100 |
| GPU, par vue qui rend | passes d'ombre `4 × N × L` (§1.3), éclairage par fragment des items (quadrants de 560 px), voile plein cadre, copie d'écran du brouillage, `VoileEncre` 10 % noir, vignette de dégâts | voir LUM-01/02/03/12 |

### 1.2 Par tick physique

**`player.gd:1694 _physics_process`** — et non `_process`, contrairement à ce que laisse croire sa taille : toute la torche s'y trouve.
Bloc `if flashlight_on:` (l.1973 et suivantes) : `_rapprocher_la_lampe()` (l.1975 → l.1667 : **2 `intersect_ray` + 2
`PhysicsRayQueryParameters2D.create` + 2 `Dictionary` par joueur et par tick**), souffle de la torche (`FastNoiseLite`, `_energie_torche`),
`for gadget in get_tree().get_nodes_in_group("gadgets")` (l.2003, le minimum des `facteur_de_lampe`), énergie de rétrodiffusion, poussière
(toutes les 0,12 s) ; `Brouillage.opacite` (l.1912-1923, un `pow` par joueur et par tick). **Cadence : 60 Hz nominal** (`project.godot` ne
règle pas `physics_ticks_per_second`), pas la cadence du rendu — 4 rayons par tick dans un duel torches allumées, soit ~240 requêtes/s
quel que soit le nombre d'images.
`plafonnier.gd:261` (≤ 8 plafonniers/salle × 60 Hz : `get_nodes_in_group("players")` + 2 `Array` chacun, LUM-13) ;
`fusee.gd:361 → _appliquer_age` (2 `GameSettings.current_effect`, l.657 et 696, énergie/couleur/fumée) ;
`gadget_torche_fantome.gd:178` (`get_first_node_in_group("game_state")` + `facteur_de_lampe_a`, l.191-192, par tick et par torche
fantôme) ; `gadget_mine/braises._physics_process` ; `perception_bot_noeud.gd:_lumieres` (lecture seule des lumières, par bot et par tick —
domaine « bots »).

### 1.3 Inventaire des lumières (Q1)

Aucune `DirectionalLight2D`. Aucun filtre d'ombre autre que `NONE` en jeu (`shadow_filter_smooth` est donc sans objet) ;
`PCF5` n'existe que dans `menu_arene.gd:137`, que le hub n'instancie plus (`effect_policy.gd:118-121`). **`[rendering]` de
`project.godot` ne règle aucun paramètre d'ombre 2D** (`rendering/2d/shadow_atlas/size` reste à son défaut moteur, 2048 ; je ne
vois pas de levier de coût de ce côté — le coût est en appels de dessin, pas en texels). Les lumières 3D du miroir iso
(`lumieres_iso.gd`) sont **éteintes par défaut en jeu** : `presentation_3d.gd:263` `lumiere_3d := false`, `:270` `_lumiere_3d_voulue := false`,
`:283` `ombres_3d := false` ; `poser_lumiere_3d()` (l.1979) n'a **aucun appelant dans les scripts de la racine** (la seule occurrence, l.637, est
conditionnée par `_lumiere_3d_voulue`) — seuls les bancs de `tools/` l'allument (commentaire l.258-269 : « éteinte par défaut », GO réduit ISO12 du
2026-09-23). Code dormant tant qu'Adrien n'a pas tranché Q20 ; hors budget aujourd'hui, **à rouvrir si elle est allumée en vue unique** (elle
ajouterait alors une `Light3D` par `Light2D` du jeu, `LAMPES_MAX = 8`). Tous les filtres d'ombre du jeu sont `NONE` : le seul `PCF5` du dépôt est
`menu_arene.gd:137`, et le seul `shadow_enabled` posé en scène est celui de l'éditeur de cartes (`map_editor.tscn:66`).

| lumière | créée par | nb. (duel) | ombre/filtre | empreinte monde (carré) → `texture_scale` | portée `range_item_cull_mask` / ombre `shadow_item_cull_mask` | allumée |
|---|---|---|---|---|---|---|
| `Flashlight` (torche) | `player.tscn`, `player.gd:812-849`, `weapon.echelle_torche()` | 1/joueur | ON / NONE | cookie 1024², **936 × 936** (portée 468 px, Q76 : ROADMAP 30331, même valeur pour les dix classes et pour les deux modes) | `1\|2\|4` / `1\|2\|couche du corps adverse` (+64 accroupi, `poser_posture`) | torche allumée (+ fondu) |
| `BodyLight` (rétrodiffusion) | `player.gd:853-894` | 1/joueur | ON / NONE | 256², `poser()` → échelle 1 | `2\|4` / `1\|2\|torse×2\|récepteur` | torche allumée |
| `ambient_light` (halo de proximité) | `player.gd:901-917` | 1/joueur | ON / NONE | 150², échelle 1 | canal de vue `16`/`32` / `DECOR\|ENNEMI\|corps d'en face` | **toujours** (jamais éteinte) |
| `MuzzleFlash` | `player.gd:940-947, 2612` | 1/joueur | ON / NONE (défaut) | 64² (frame 256² × 0,25) | `1\|2` / `1\|couche adverse` | 0,1 s par tir |
| `ground_flash` (écho au sol) | `player.gd:2722-2731` | **1 neuve par tir** | OFF | 130² | `1` | 0,12 s |
| `hit_light` | `player.gd:2909-2932` (`rpc_update_hp`) | **1 neuve par coup reçu** | ON / NONE | 400² | `1\|4` / `1` | 1 s |
| `Halo` de fusée | `fusee.gd:210-228` | stock 1 à 3 par joueur | ON / NONE | 160² en vol ; **936² à l'allumage → 440²** posée | `1\|2\|4` / `1` (+64 posée) | ~20 s |
| `Lueur` des braises | `gadget_braises.gd:227-243` | par gadget | ON / NONE | 340² | `1\|2\|4` / `1\|64` | durée du gadget |
| `Embrasement` de la mine | `gadget_mine.gd:221-240` (créé à l'allumage) | par mine | ON / NONE | 520², énergie 6 | `1\|2\|4` / `1\|64` | 1,6 s |
| `Faisceau` + `Halo` de la torche fantôme | `gadget_torche_fantome.gd:129-175` | 2 par gadget | ON / NONE | cookie × `echelle_torche()` (936²) + 256² | `1\|2\|4` / `1\|2\|4\|8` et `1` | durée du gadget |
| `MurLed` | `mur_led.gd:170-194` | 1 par carte | OFF | texture ≤ 512², **couvre la carte entière** (~1 190² pour 34 cases) | `1` | respire (`enabled` si k > 0,004) |
| `Halo` de plafonnier (solo) | `plafonnier.gd:240-257` | 0 à 8 par salle (moyenne 2,2) | ON / NONE | 2 × rayon : 245 à 630 | `1\|2\|4` / `1\|2\|128\|256` | proximité du joueur, hystérésis |
| `Light` de 240 particules | `particle_pool.gd:126-132` | 240 nœuds | OFF | — | **jamais `enabled`** (LUM-11) | jamais |
| doubles de killcam | `game_state.gd:1689-1730` (`duplicate()`) | 2 + 2 | ON / NONE | = torche, = flash | = torche, = flash | killcam seulement |

Plus quatre lumières à ombre par PNJ en solo (un PNJ est un `Player` complet, `aventure_partie.gd:175-207`, `player_id = 1`).
**Pire cas simultané d'un duel** : 6 lumières à ombre permanentes (torche, rétro, halo × 2) + MurLed (sans ombre) ; en ajoutant
2 flashs, 1 à 3 `hit_light`, jusqu'à 6 fusées (stock 3 + 3 pour deux Terrassiers) et 4 lumières de gadget, ~20 lumières à ombre
(8 à 10 en jeu courant). Plafond moteur de 15 lumières par item (ROADMAP 5332) : jamais atteint en duel ; **atteignable en
solo** (jusqu'à 8 torches de corps + 8 plafonniers + MurLed sur un même quadrant), voir Questions ouvertes.

**Lesquelles pourraient se passer d'ombre ou de portée sans perte de lisibilité ?** Aucune, à information égale : chacune de
ces ombres est une règle (« un mur arrête la lumière », « le dos du porteur reste dans le noir », « le sang n'éclaire pas à
travers un mur ») et les portées sont des règles de jeu (Q76). Le gisement n'est pas dans les réglages d'une lumière mais dans
**combien de fois** elle est calculée (LUM-03) et **quelle surface carrée** on lui réserve (LUM-04).

### 1.4 Occulteurs (Q2)

`map_geometry.gd:335-365` : un `LightOccluder2D` par rectangle fusionné, 4 sommets (`_build_rect_occluder`), `closed = true`,
`cull_mode` laissé à `CULL_DISABLED` (correct : le mur occulte des deux côtés, l.367-371 ; un cull unilatéral n'économiserait
aucun appel de dessin), retrait de 3 px (`OCCLUDER_INSET`). Les fosses n'en produisent pas ; les murs bas en produisent sur la
couche d'ombre 64, que les lumières debout ne lisent pas (elles itèrent dessus sans les dessiner).

| carte (PROUVÉ, `lum/occluders.py`) | cases de mur | **occulteurs (rects)** | sommets | si contours (`trace_contours`) : boucles / sommets |
|---|---|---|---|---|
| `default` | 348 | **4** | 16 | 2 / 8 |
| `arene_circulaire` | 220 | **9** | 36 | 3 / 28 |
| `map_001_le_cloitre` | 372 | **9** | 36 | 7 / 28 |
| `map_002_l_usine` | 376 | **11** | 44 | 9 / 36 |
| `map_003_la_croisee` | 360 | **11** | 44 | 7 / 36 |
| `map_004_le_bunker` | 312 | **11** | 44 | 5 / 28 |
| solo, 100 salles | — | médiane 9, **max 76** (`chapitre_09/niveau_07`, + 37 rects de murs bas) ; 61 (`chapitre_08/niveau_09`, 100×80, 8 plafonniers, 7 PNJ) | max 304 | médiane 6, max 52 |

À ces occulteurs de mur s'ajoutent, par corps, une étoile de 32 sommets (`Charte.ombre_de_silhouette`, l.1034-1069) et un disque de
torse de 16 sommets (`ombre_de_torse`, l.1090) — **96 sommets pour deux joueurs, plus que tous les murs d'une carte de duel** — et
16 sommets par gadget (`gadget_base.gd:387`). Mais ce qui coûte est le **nombre d'instances**, pas de sommets : chaque lampe à
ombre redessine les instances retenues, 4 fois (4 passes angulaires de la carte d'ombre 1D — à ne pas confondre avec les quadrants de 560 px des tuiles) — `tools/bench_framerate.gd:833`
(« 4 × N × lampes ») et `tools/compte_occulteurs.gd:3-15`, qui précise que N se trie contre le **rectangle englobant de toutes les
lampes à ombre du viewport**. Mesure existante : 0,09 ms pour la passe d'ombre de la lampe de la fusée, à 8 occulteurs, « dans le bruit de leurs propres passes (0,35) » (ROADMAP 28270 ; `compte_occulteurs.gd:22-25`). Le projet la tient pour une
borne haute ; **ce n'est pas une borne rigoureuse** — le bruit de la mesure (0,35 ms) dépasse l'effet (0,09 ms). Je m'en sers comme **calibrage** : 0,09 ms / 32 dessins (4 × 8) ≈ 2,8 µs par dessin d'ombre si cette lampe
n'était dessinée que dans un viewport (≈ 2,8/V µs si elle l'était dans V viewports). Tous les temps de ce rapport qui en dérivent sont des ordres de grandeur sous cette réserve, jamais des mesures.

**La fusion gloutonne est-elle optimale pour l'occlusion ?** Elle est exacte pour la physique et presque minimale en rectangles ;
pour l'occlusion seules les arêtes comptent, et les contours en demandent moins : −18 à −67 % d'instances de mur selon la carte de duel (55 rects → 33 boucles pour les six, −40 %),
soit −13 à −46 % du N total retenu par une lampe (les 4 occulteurs de corps restent) ; −36 % sur l'ensemble du solo (1 106 rects → 711 boucles), −33 % sur la salle la plus chargée (76 → 51) ; ils suppriment les 6 px de fente entre rectangles voisins que le commentaire
`map_geometry.gd:262-268` reconnaît (« liseré de lumière au raccord »). Voir LUM-08.

### 1.5 Événements (Q3)

| événement | lumières | pool ? | remarque |
|---|---|---|---|
| tir | `MuzzleFlash` réutilisé (`enabled` + tween + 2 `LightTextures.poser`) ; **`ground_flash` = `PointLight2D.new()` + `add_child` + tween + `queue_free`** (l.2722-2731) | non | 3 tweens/tir ; sans ombre ; ESTIMÉ ~10-20 µs, négligeable même à 10 tirs/s |
| coup reçu | **`hit_light` neuve à ombre par appel de `rpc_update_hp`**, c.-à-d. **par plomb** (`bullet.gd:424` → `take_damage` → `rpc_update_hp`) ; gardée par ROADMAP 2506 | non | pompe à bout portant : 3 plombs touchent (0° et ±20° à ≲ 50 px) → 3 lumières identiques empilées 1 s (LUM-10) |
| mine | `Embrasement` créé à l'allumage (`gadget_mine.gd:158, 221`) | non | une fois par mine |
| fusée, braises, torche fantôme | créées avec le gadget | non | une fois par gadget |
| impact de mur, sang, étincelles, balle | **aucune lumière** depuis 2026-09-10/15 (ROADMAP 2506, 2508, 2532, 5332) | — | le pool garde 240 nœuds `Light` morts (LUM-11) |

**Hoquet à la première lumière ombrée ?** Je n'en vois pas de cause dans le code : les halos de proximité sont ombrés et allumés dès
la première image d'une manche, donc l'atlas d'ombre et les variantes de shader « éclairé » sont, à ma lecture du moteur (de mémoire), payés pendant le décompte, pas
au premier tir. Ce que je trouve à la place, ce sont des premiers usages qui tombent pile sur l'action (LUM-05, LUM-07).

### 1.6 Passes plein écran inactives (Q4)

| passe | nœuds éteints à l'inactif ? | état torche allumée |
|---|---|---|
| copie plein cadre du voile (`_voile_bb`, `ui.gd:2620`) | **oui** : `visible = niveau ≥ aberration_debut / curseur` (`ui.gd:8878-8885`) | éteinte tant que < 0,12 |
| voile `VoileP1/P2` | **non, par décision** : `ui.gd:2436-2451` (il doit rester visible, `HBoxContainer`) ; au repos total le shader sort `vec4(0)` (uniform `niveau ≤ 0.001`) | **torche allumée : `niveau` = 0,06, le corps complet du shader tourne en plein cadre (LUM-02)** |
| flou + `BackBufferCopy` + halo du brouillage | `eteindre()` OK hors manche | **torche allumée : allumés, pour un effet < 1/255 (LUM-01)** |
| vignette de dégâts (`player.gd:795-810`) | **non** : le `ColorRect` plein cadre reste visible à alpha 0 | dessinée à chaque image (LUM-12) |
| `VoileEncre` (10 % noir, `ui.gd:2582`) | par conception (aplat constant) | dessiné |

Résolution et échantillons : le flou du brouillage fait **17 prélèvements** par fragment (1 + 8 + 8, `brouillage_flou.gdshader:106-111`) à
la résolution du framebuffer du viewport où il vit (fenêtre en vue unique : jusqu'à 2560×1440 sur le Mac de test), sur une ellipse
bornée à 988 × 380 unités canevas à saturation ; la copie est `COPY_MODE_RECT` (bonne décision : 0,375 Mpx au lieu de 3,69 selon
`brouillage_vue.gd:12-15`). Le voile fait **12 lectures de texture** (2 lueurs + 5 flares + 5 fantômes), un lavis (`pow` sur `length(d)`) et un grain `hash21` par fragment,
plein cadre (`voile_eblouissement.gdshaderinc:362-436`) ; les ~40 à 55 `sin/cos` écrits dans les boucles ne dépendent que d'uniformes (rien de `UV` ni de `FRAGCOORD`), donc un compilateur ou le préambule
du GPU peut les hisser hors du pixel — non vérifié, je ne les compte pas dans le coût sûr. Fréquence : chaque image.

### 1.7 `effect_policy.gd` (Q5)

Il n'y a **aucun niveau de qualité au sens de la performance**. `NIVEAUX = [0, 0,35, 0,70, 1]` (NUL/FAIBLE/MOYEN/ÉLEVÉ,
l.70-71) ne règlent que la famille CONFORT (secousse, recul, vignette de dégâts, flash de mort, tremblements, grain de killcam,
vibration) : ils multiplient une intensité, ils ne retirent ni nœud, ni passe, ni lumière — la vignette à NUL reste un quad plein
cadre à alpha 0 (LUM-12). La famille MENUS a un interrupteur qui, lui, éteint les nœuds (`menu_veil.gd:45` `visible = v > 0.0`) — mais
hors manche. La famille MONDE (flash de tir, trait de balle, poussière, éblouissement, aberration, fusée : tout ce qui coûte en
match) **ne se règle pas, par décision d'équité** (`effect_policy.gd:23-36`). Les seuls leviers de coût livrés sont ailleurs :
`iso_lightmap` (`1080p`/`plein`, `settings_manager.gd:223`), `fps_cap`, `vsync`. Conséquence : toute économie sur les lumières ou sur
l'éblouissement doit être **identique pour tous et automatique**, jamais un réglage du joueur (Questions ouvertes).

---

## 2. Constats

### LUM-01 — Le flou du brouillage, sa copie d'écran et son halo sont allumés en permanence dès qu'une torche brûle

**Où** `brouillage_vue.gd:227-231` ; `brouillage.gd:323, 605, 655` ; `eblouissement.gd:174` ; `game_state.gd:2573, 2405-2406, 5884` ;
`presentation_3d.gd:409-413` ; intention contredite : `brouillage_vue.gd:145-148`.

**Constat**
```gdscript
# brouillage_vue.gd:227-231
var f := Brouillage.flou(dazzle)
var rayon_flou := float(f["rayon"])
var force := float(f["force"])
_flou.visible = rayon_flou > 2.0 and force > 0.001
_copie.visible = _flou.visible          # un BackBufferCopy visible recopie à chaque image
```
```gdscript
# brouillage_vue.gd:145-148 — l'intention
## ... Un `BackBufferCopy` visible recopie à chaque image ... le laisser allumé hors éblouissement ferait payer l'effet en
## permanence, alors qu'il ne sert que quelques secondes par manche.
```
Mais `Eblouissement.RETRODIFFUSION = 0,06` (l.174) tient `dazzle_amount` à 0,06 **dès que le joueur allume sa torche** (cas « de soi »,
`game_state.gd:2573`). Dose = 0,06 × `GAIN` 2 = 0,12 → `rayon_flou` = 190 × 0,12 = **22,8 px** (> 2,0) et `force` = 0,12 (> 0,001) : le
test est vrai pour tout éblouissement > 0,0053. Le gagnant du plafond est alors soi-même (`source_eblouissante = gagnante[cible]`,
`game_state.gd:2405-2406`), donc `emetteur == regardeur` : l'ellipse se centre à 23,7 px devant soi, **dans le trou d'exclusion**
(44-104 px, `brouillage.gd:356-357`). **Balayage numérique de la formule du shader** (`lum/flou_repos.py`, émetteur = regardeur, dazzle = 0,06, pas de 0,5 px) :
le noyau (34 px × k) et le trou d'exclusion sont en pixels d'APPAREIL (`SCREEN_PIXEL_SIZE`), l'ellipse en unités de CANEVAS ; le résultat dépend donc de la fenêtre :

| fenêtre (échelle appareil/canevas) | noyau de flou maximal | couverture maximale |
|---|---|---|
| 1920 × 1080 (1,0) | **0,26 px** | **4,5 %** |
| 2560 × 1440 (1,33, résolution de la mesure ISO10) | 0,92 px | 44 % |
| échelle 2 (écran Retina plein cadre) | 2,5 px | 100 % |

Dans les trois cas, la zone touchée est un lopin d'une soixantaine de pixels devant le joueur, juste au-delà du trou d'exclusion : aucun contour n'y devient illisible, mais **ce n'est strictement nul qu'en 1080p**.
Le halo (`rayon > 1.0` → 18 px, alpha 0,084) est lui aussi allumé. En vue unique l'appareil vit sous `_main` (`presentation_3d.gd:409-413`), c'est-à-dire que `CoucheFlou` s'attache à
la **fenêtre** : la copie prend le framebuffer de la fenêtre.

**Coût** — PROUVÉ (lecture + calcul) : une `BackBufferCopy` visible, un `ColorRect` à shader 17 prélèvements (~4 000 fragments) et un
`TextureRect` par vue regardée, **à chaque image où une torche brûle**, soit l'essentiel d'un match. ESTIMÉ : sur un GPU à tuiles (M3),
une copie d'écran en cours de passe force la fin puis la reprise de la passe de rendu courante, quel que soit le rect copié (lecture du
moteur par mémoire). La seule mesure disponible est celle d'ISO10 1a — copie plein cadre + voile plein = **0,53 ms/img** à 2560×1440
(ROADMAP 26533, 14,35 contre 13,82 ms) — qui borne le coût ; **non mesuré pour la copie `RECT` seule**.

**Proposition** Dans `BrouillageVue.maj()`, ne pas allumer flou et copie quand `emetteur == regardeur` **et** `dazzle <= Eblouissement.RETRODIFFUSION × 1,05`
(0,063 ; le dazzle d'une torche seule vaut exactement `RETRODIFFUSION × gain_taille × facteur_de_lampe ≤ 0,06`). Au-delà (pic de flash de tir, fusée aux pieds, faisceau adverse : `emetteur != regardeur`)
le comportement reste celui d'aujourd'hui. Lors de la décrue après un éblouissement, le flou disparaît en passant sous 0,063 (saut de ≤ 0,35 px à 1080p, ≤ 1,1 px à 1,33). `eblouissement.gd` n'a aucune dépendance : `preload` possible. Ne pas toucher au halo (il change
l'image : voir Questions ouvertes, C).

**Gain attendu** ESTIMÉ 0,1 à 0,5 ms par image torche allumée (borne haute = la mesure ci-dessus). Soit 0,6 à 3 % d'un budget de 16,7 ms (60 images/s) : peu, mais le jeu passe la cible « 1 % bas ≥ 60 » de deux images par seconde seulement (CLAUDE.md), et ce coût est payé à chaque image.

**Risque** Visuel : à 1080p l'écart est ≤ ~2/255 en un point ; à 2560 × 1440 et au-delà, la proposition **retire** un adoucissement de ≤ 1 px (jusqu'à 2,5 px à l'échelle 2) dans un lopin d'une soixantaine de pixels
devant le joueur — probablement un effet de bord jamais voulu (calibré en 1080p, où il est nul), mais c'est un changement d'image à faire valider (Questions ouvertes C). Équité : aucun (le seuil lit la valeur répliquée,
identique des deux côtés ; l'effet qu'on retire n'a aucune lisibilité). Bancs : `tools/banc_voile.gd:757-760` pose le mode de copie après `maj` — à vérifier ; `test_brouillage` ne lit pas la visibilité.

**Effort** S. **Sévérité** MAJEUR (permanent, retirable, contredit une intention écrite). **Statut ROADMAP** NOUVEAU — ISO10 1a (ROADMAP 4305-4317,
26521-26537) n'a traité que `_voile_bb` ; la rétrodiffusion à 0,06 est connue (3616, 26517) mais pas pour le brouillage.

**Comment le vérifier** `tools/bench_framerate.tscn` avec un drapeau neuf `--sans-brouillage-repos` (appeler `BrouillageVue.eteindre()` à chaque image
après `maj`, patron `_poser_les_drapeaux_de_la_fusee`, `bench_framerate.gd:844`), torche tenue (`tenir_la_torche`, l.1615), séquence C A A C de 60 s hors
transitoire, `--temps-par-vue` (l.156) ; compter les passes de rendu par image dans la capture Metal d'Xcode. `test_brouillage`, `banc_brouillage`.

---

### LUM-02 — Le voile « calme » exécute son shader complet sur toute la fenêtre dès qu'une torche brûle

**Où** `voile_eblouissement.gdshaderinc:307-310, 362-428` ; `ui.gd:2543-2554, 2436-2451, 8870-8873`.

**Constat** À 0,06, `_poser_voile` choisit le matériau calme (`niveau × curseur < aberration_debut = 0,12`), ce qui a supprimé la copie d'écran
(ISO10 1a) — mais le fragment, lui, ne sort tôt que sous 0,001 :
```glsl
// voile_eblouissement.gdshaderinc:307-310, 362-364, 378-379, 406-407
void fragment() {
	if (niveau <= 0.001) { COLOR = vec4(0.0); } else {
	    ...
		for (int i = 0; i < 4; i++) { if (i >= lueurs_n) { break; } ... ajout += texture(lueur_tex, uv).r ...   // lueurs_n = 2
		for (int i = 0; i < 8; i++) { if (i >= flares_n) { break; } ... cos(-ang) sin(-ang) ... texture(flare_tex, uv) // flares_n = 5
		for (int i = 0; i < 6; i++) { if (i >= fantomes_n) { break; } ... cos(ga) sin(ga) ... texture(fantome_tex, uv) // fantomes_n = 5
```
`ui.gd` ne surcharge aucun de ces nombres (aucune occurrence de `lueurs_n`, `flares_n` ni `fantomes_n` dans `ui.gd`) : **12 lectures de texture par pixel de la fenêtre**, plus le lavis, le grain `hash21` (l.432-437,
actif dès `grain_force > 0.001`) et le mélange alpha — pour une couche dont l'alpha vaut au plus `clamp(a) × niveau` = 0,06 × ~1,5 (« tout l'écran soulevé de 2 à 4/255 », ROADMAP 3616 ; jusqu'à ~14/255 au croisement
des flares au centre). Les ~40 à 55 `sin/cos` des boucles ne dépendent que d'uniformes : leur coût par pixel dépend du compilateur (hissés ou non), je ne le compte pas. Le `ColorRect` est visible
par décision (`ui.gd:2436-2451`, piège de l'`HBoxContainer`) ; en vue unique `VoileP1` occupe toute la largeur.

**Coût** PROUVÉ : le chemin complet s'exécute à chaque image torche allumée sur toute la fenêtre (~0,9 Mpx à 1280×720, 2,1 Mpx à 1920×1080, 3,7 Mpx à 2560×1440). ESTIMÉ : 0,1 à 0,5 ms sur le M3 à 2560×1440
(12 lectures de petites textures × 3,7 Mpx ≈ 44 M lectures de texels, plus le mélange d'une couche plein cadre) — fourchette large, car elle repose sur le débit de lecture de texture que je ne connais pas pour cette machine.
**Non mesuré** : ISO10 1a a mesuré le delta plein-contre-calme, copie d'écran comprise (0,53 ms, ROADMAP 26533), pas calme-contre-rien. C'est le piège de ROADMAP 4258 (« un coût derrière un uniforme ne se voit dans aucune
comparaison de shaders » : ici `niveau`, un uniforme, décide si le lavis, les lueurs, les flares et les fantômes s'exécutent). **Règle de décision** : si la mesure donne moins de ~0,15 ms, abandonner ou déclasser en MINEUR.

**Proposition** (1) Mesurer d'abord : forcer `p1_dazzle.visible = false` torche allumée. (2) Si > 0,3 ms : tant que `niveau × curseur < 0,08`, rendre le voile calme dans un
`SubViewport` au quart de résolution (480×270) étiré en `TextureRect` — son contenu est lisse (lueurs, flares et fantômes sont des textures à variation lente ; le
grain `FRAGCOORD` est invisible à ce niveau : 0,015 × 0,06 × 255 < 0,3/255), l'écart attendu est ≤ 1/255. (3) Alternative qui **change** l'image : réduire
`lueurs_n/flares_n/fantomes_n` sous 0,08 — décision d'Adrien, et pas un réglage joueur (MONDE).

**Gain attendu** ESTIMÉ 0,1 à 0,5 ms/img torche allumée (à confirmer par (1)). **Risque** Visuel ≤ 1/255 pour (2), à juger au `banc_voile` ; coût d'une passe de viewport de plus
(ordre de 0,05 ms à cette taille). **Effort** S pour mesurer, M pour (2). **Sévérité** MAJEUR (à confirmer). **Statut ROADMAP** NOUVEAU (ROADMAP 4305-4317 / 26521-26537
traitent la copie, pas le corps du shader ; 4258 est le piège pertinent).

**Comment le vérifier** `tools/banc_voile.tscn` pour l'image ; cadence : drapeau `--sans-voile-repos` au banc (cacher `p1_dazzle` quand `niveau < aberration_debut`), C A A C, torche tenue.

---

### LUM-03 — La passe d'ombre 2D vaut `4 × N × L` par viewport, se répète dans chaque capteur de corps, et n'a jamais été mesurée sur les salles de l'aventure

**Où** `tools/bench_framerate.gd:767-841` (formule `4 × N × lampes`) ; `tools/compte_occulteurs.gd:3-15, 22-25` ; `capteur_corps.gd:84-105, 137-140` (SubViewport 256², `UPDATE_ALWAYS`,
monde partagé) ; `presentation_3d.gd:1095-1105, 1161-1170, 1185-1200, 809-810` ; `miroirs_iso.gd:241` (un capteur par objet posé et par vue) ; `aventure_partie.gd:175-207` ;
`plafonnier.gd:240-257` ; `game_state.gd:1289` (`p2.hide()` en solo).

**Constat** (i) Chaque viewport qui rend le monde (lightmap, **chaque capteur de corps**, chaque capteur d'objet posé) refait, pour toutes les lampes à ombre dont le rect carré
croise son champ, 4 passes sur les occulteurs triés contre le rectangle **englobant** de ces lampes. (ii) Une torche (rect 936²) recouvre la fenêtre de 128 px de n'importe quel capteur situé dans un carré de ±532 px autour d'elle (468 + 64),
alors que son cône n'éclaire que 3 à 13 % de son carré. (iii) Le coût est donc **quadratique en nombre de corps** : chaque PNJ ajoute 3 lampes à ombre ET 1 capteur qui voit les lampes de tous les autres.
(iv) En solo `p2` est caché (`game_state.gd:1289`) mais son capteur reste `UPDATE_ALWAYS` : `_suivre` ne gèle un capteur que si la VUE est gelée
(`gelee := vue.render_target_update_mode == UPDATE_DISABLED`, `presentation_3d.gd:803-810`), jamais parce que son corps est caché, et `CapteurCorps.suivre()`
continue de le centrer sur `p2.global_position` (`capteur_corps.gd:137-140`). Ce que ce viewport coûte dépend de l'endroit où `p2` reste parqué (sa case de départ du duel,
qui peut être hors de la salle ou dedans) : **il n'est pas dans le modèle ci-dessous**, qui ne compte en solo que le capteur de J1 et ceux des PNJ.

Mesure existante (ROADMAP 27698, 28270-28308, `compte_occulteurs.gd:22-24`) : 0,09 ms pour la lampe de la fusée à 8 occulteurs (dans un bruit de 0,35 ms), « 80 dessins d'ombre par image, dont 64 pour rien », ~0,14 ms —
**avec deux halos et sans torche, sur une carte à 9 occulteurs**, et la conclusion écrite « à relever sur une carte plus chargée (le coût suit le nombre d'occulteurs) ». Le chantier SOLO a été livré
« sans aucun relevé de cadence » (ROADMAP 2449 ; `plafonnier.gd:34-44` : « livré NON MESURÉ »). Le banc ne charge aucune salle d'aventure.

**Coût — modèle PROUVÉ en entrées, ESTIMÉ en sortie** (`lum/solo_ombres.py`, relancé et sortie gardée dans `lum/solo_ombres.out` : toutes les torches allumées — pire cas —, murs hauts seulement,
champ de la lightmap 1280 × 720 unités de monde, rect englobant des lampes à ombre en vue, capteurs de 128 × 128 pour J1 et pour chaque PNJ à ≤ 1 300 px comme `PORTEE_CAPTEUR_FIGURANT_PX`).
**Base de caméra** : le tableau ci-dessous prend, pour la part « lightmap », la **pire** de quelques positions (sur le joueur, à mi-chemin de chaque PNJ, sur chaque PNJ) — une enveloppe,
pas une image donnée ; les comparaisons avant/après des propositions 2 et 4 (plus bas) sont, elles, à **caméra sur le joueur** (base : médiane 796, p90 3 060, max 6 816 pour le
gating ; médiane 960, p90 3 225, max 7 008 pour les cookies, torches orientées au hasard) :

| scène | dessins d'ombre par image (lightmap + capteurs) | au calibrage de 2,8 µs/dessin |
|---|---|---|
| duel, 6 cartes livrées, J1/J2 à 10 cases | **392 à 840** (lightmap 168-360) | 1,1 à 2,4 ms |
| solo, médiane des 100 salles | **1 212** | 3,4 ms |
| solo, p90 | **3 496** | 9,8 ms |
| solo, pire (`chapitre_00/niveau_09` : 6 PNJ + 3 plafonniers) | **7 296** (24 lampes en vue de la lightmap) | 20 ms |

2,8 µs/dessin est un **calibrage incertain** (0,09 ms / 32 dessins, mesure noyée dans un bruit de 0,35 ms : la vraie valeur peut être plus basse comme plus haute), mais le rapport solo/duel (×3 à ×9) ne dépend pas de lui, et c'est lui qui compte. Hypothèses fortes : tous
les PNJ torche allumée simultanément (profils « sourd/aveugle » probablement en partie éteints) ; la fusion en rect englobant est la lecture du moteur de `compte_occulteurs.gd`.

**Propositions**, de la plus sûre à la plus lourde :
1. **Mesurer** : option du banc pour charger une salle (`--salle=ch.niveau`), recensement `_recenser_les_ombres_2d` existant, `--temps-par-vue`, drapeau neuf `--sans-ombres2d`
   (`shadow_enabled = false` sur toutes les `PointLight2D`, reposé après création).
2. **Capteurs de PNJ à l'écran, pas à 1 300 px** : n'activer le capteur d'un figurant que si son corps est dans le champ de la caméra + marge (`CameraIso.rect_couvert` existe,
   `presentation_3d.gd:825`) ; et passer en `UPDATE_DISABLED` le capteur de `p2` quand `p2` est caché (solo, entraînement). Modèle, **pour le seul gating des figurants** (champ + 100 px au lieu de
   1 300 px, caméra sur le joueur) : **−19 % de dessins en moyenne** (médiane 796 → 606, p90 3 060 → 1 896, max 6 816 → 5 568). Le gain du capteur de `p2` n'est pas chiffré (voir (iv)).
3. **Contours à la place des rectangles** (LUM-08) : −36 % d'instances de mur en solo, −13 à −46 % du N retenu en duel.
4. **Rogner les cookies de torche** (LUM-04) : modèle −33 à −49 % en duel, −50 % en solo.
5. **Rattacher la canvas d'une lampe aux seuls viewports qu'elle éclaire** (patron `EtoileDeCorps`, `RenderingServer.viewport_attach_canvas`, ROADMAP 3849) au lieu du recouvrement de rects : effort L.

**Gain attendu** ESTIMÉ, de l'ordre de la moitié des temps du tableau si l'on cumule 3 et 4 (qui se multiplient, ils ne s'additionnent pas) : ≈ 0,5 à 1,2 ms en duel, ≈ 1,7 ms à la médiane
du solo et ≈ 5 ms au p90 — **à condition que le coût réel d'un dessin d'ombre soit proche du calibrage de 2,8 µs, ce qu'aucune mesure n'a établi** ; s'il est dix fois plus bas, ce constat tombe
sous le seuil de 0,3 ms que le projet s'est fixé (ROADMAP 28303). C'est pourquoi la proposition 1 (mesurer) passe avant toutes les autres. **Risque** (2) : apparition du corps 3D au bord
d'écran (marge + hystérésis) ; (5) fragile. Déterminisme des bancs : aucun (rendu local). **Effort** S (1, 2), M (3), L (4, 5). **Sévérité** MAJEUR (risque, non mesuré).
**Statut ROADMAP** CONNU-OUVERT : 28303 (« halos privés … rangé sans code », seuil 0,3 ms), 2449 (solo sans relevé), 3849 (canvas par vue). Le modèle chiffré est NOUVEAU.

**Comment le vérifier** `bench_framerate` (recensement imprimé à l'ouverture, l.479), `--temps-par-vue`, `tools/compte_occulteurs.gd` étendu à `assets/solo/**` ; Instruments (Metal System Trace) pour le temps CPU du pilote.

---

### LUM-04 — Le rect carré de chaque torche (936 × 936) est vide à plus de 75 % ; le rogner réduirait de moitié la passe d'ombre modélisée

**Où** `weapon_data.gd:265-272` (`echelle_torche`), `light_textures.gd:96-103`, cookies `assets/torche/cookie_*.png` (1024², `compress/mode=0` lossless) ; consommateurs de `texture.get_width() × texture_scale`
comme rayon centré : `iso_volumes.gd:717-718`, `mannequin_iso.gd:125`, `perception_bot_noeud.gd:281-284`, `presentation_3d.gd:2076, 2143, 2174`, `lumieres_iso.gd:296-297`, `vision.gd:151-155`.

**Constat** (PROUVÉ, `lum/cookies.py`, décodage direct des PNG) : sur les dix cookies de classe, **tout l'alpha non nul est dans la moitié avant** (x ≥ 512 sur 1024, « recul derrière la lampe = 0 % »)
et sa boîte englobante ne couvre que **7,1 % (arbalète) à 24,0 % (pompe)** du carré (alpha ≥ 1/255 ; 3,1 à 20,7 % à ≥ 8/255) — moyenne 13,9 %. Le moteur trie lumières, items et occulteurs sur
`texture × échelle` (le recensement du banc modélise exactement cela, `bench_framerate.gd:788-790`) : la lampe est donc dans la liste de 7 quadrants de sol en moyenne (carré 936² contre quadrants de 560 px) alors que sa boîte réelle en toucherait 2,3 à 3,3,
et elle recouvre donc le plus souvent à tort la fenêtre d'un capteur (la boîte du cône n'est que 7 à 24 % du carré).

**Coût** Modèle (`lum/solo_ombres.py`, rect rogné = boîte du cookie du pistolet 511 × 336 texels orientée comme la torche, 12 orientations tirées) : dessins d'ombre par image
**duel : −33 à −49 % selon la carte** (ex. Cloître 728 → 455) ; **solo : médiane 960 → 505, p90 3 225 → 1 291, max 7 008 → 2 782 (−50 % en moyenne)**. S'y ajoutent les boucles de lumières par
fragment des items (non chiffrées). ESTIMÉ (modèle, orientations aléatoires).

**Proposition** Cuire des cookies rognés à la boîte de l'alpha (outil `tools/concentrer_cookies.gd` existe pour le resserrage), les poser avec `PointLight2D.offset = (largeur_monde/2, 0)` pour que la lampe reste à
l'origine de l'ombre (que `offset` ne déplace que la texture et laisse l'origine de l'ombre au nœud est ma lecture de la documentation de `PointLight2D`, de mémoire : à confirmer avant tout travail), et remplacer partout `texture.get_width() × texture_scale × 0,5` par `weapon.portee_torche()` (déjà l'unique vérité de la portée) et `Vision.intensite_texture` par une version qui connaît le décalage.

**Gain attendu** Voir ci-dessus : le plus gros levier structurel de ce domaine, sur la passe d'ombre ET l'éclairage par fragment. **Risque** Élevé en surface : six consommateurs supposent la texture centrée ;
l'éblouissement lit le cookie (équité : doit coller au pixel) ; le faisceau visible dans l'air (Q41) lit l'enveloppe du cookie. Gardes qui rougiraient : `test_vision`, `test_torches`, `test_lumieres`,
`test_iso_torches3d`, `test_portee_ecran`, `test_allegement_faisceau`. **Effort** L. **Sévérité** MAJEUR (potentiel). **Statut ROADMAP** NOUVEAU pour le rognage des cookies. Voisins : la ROADMAP 5338-5340 et 5378 nomme `rendering_quadrant_size` comme levier « à chiffrer au `bench_framerate` »
(non fait) ; 8047 est le piège « la résolution d'une texture de lumière décide de sa PORTÉE » (règle : `texture_scale = torch_scale × 512 / width`, « une propriété d'implémentation ne doit jamais décider
d'une grandeur de jeu ») : un cookie rogné change de largeur ET de forme (non carré), or `echelle_torche()` ne lit que `tex.get_width()` (`weapon_data.gd:265-272`) — elle, `light_textures.gd:96-103` et la liste
de consommateurs ci-dessus sont à réécrire ensemble ; Q76 (30331) fixe la portée de 468 px, que le rognage ne doit pas toucher.

**Comment le vérifier** Mesurer d'abord (LUM-03 n°1) : si la passe d'ombre pèse < 0,3 ms en duel, ne pas le faire. Puis A/B image : `tools/banc_lumieres.gd`, `loupe_*`, écart au pixel sur le cône ; éblouissement : `planche_eblouissement`.

---

### LUM-05 — Les shaders du flou et du voile, et la copie d'écran, ne sont préchauffés nulle part : un hoquet au premier allumage de torche (certain) et au premier éblouissement (à établir)

**Où** `ui.gd:67-69, 2453, 2464, 2543-2545` ; `brouillage_vue.gd:43, 66-79, 230-231` ; `game_state.gd:5859` ; seul préchauffage du dépôt : `game_state.gd:1565 Fusee.prechauffer(arena)` (`fusee.gd:343-358`).

**Constat** `Fusee.prechauffer` dessine d'avance le shader de la FUMÉE de fusée (`VOILE_SHADER`, `fusee.gd:353-356`), pas ceux du dispositif d'éblouissement. Pour ces derniers :
- `SHADER_FLOU` — **certain** : `_flou.visible = false` à la construction (`brouillage_vue.gd:77`) et ne devient vrai que dans `maj()`, que `_maj_brouillage` n'appelle que pendant une manche (`actif := round_active and …`, `game_state.gd:5859`).
  Première compilation, première allocation du back-buffer et de la `BackBufferCopy` : **au premier allumage de torche de la session** (LUM-01 allume le flou dès ce moment), après le décompte, pendant le jeu.
- `SHADER_VOILE` (plein) — **à établir** : c'est le matériau INITIAL des deux voiles (`ui.gd:2453`) ; le calme n'est posé que par `_poser_voile`, à chaque `update_hud` (l.2543-2545). Si `update_hud` passe avant la première image où le rect est dessiné,
  le plein n'est compilé qu'au premier éblouissement ≥ 0,12 (pile sur l'action) ; sinon il l'est au démarrage (sans conséquence) — et le calme est alors le shader qui se compile tard. Je ne peux pas trancher sans exécuter.
Le commentaire de ROADMAP 16523 (« le shader est préchargé … compilé à la volée, il produirait un hoquet pile sur l'action décisive ») confond charger et compiler : un `preload` charge la ressource, **le programme GL se compile au premier dessin**
(ROADMAP 22510, PE3.5 : « seule `Fusee.prechauffer()` dessine d'avance. Une chauffe générale est un pas séparé »).

**Coût** ESTIMÉ, non mesuré pour ces shaders : un hoquet unique par processus. Les compilations mesurées sur ce Mac pour des matériaux 3D éclairés valent **143 à 150 ms** (ROADMAP 27616) ; le voile est un programme de 463 lignes avec boucles,
le flou un programme court. Le hoquet du flou tombe sur le premier allumage de torche, c.-à-d. le début de l'action.

**Proposition** Étendre `Fusee.prechauffer` (ou un pas « chauffe générale » de PE3.5) : pendant `rebuild_arena`, dessiner une image un `ColorRect` de 1 px par shader (`SHADER_FLOU`, `SHADER_VOILE`, `SHADER_VOILE_CALME`, niveau 0 — la compilation
ne dépend pas de la branche) et rendre visible une `BackBufferCopy` de 1 px — dans le **même parent** que les vrais (fenêtre en vue unique, sous-vue 3D en scindé), puis `queue_free` à l'image suivante.

**Gain attendu** Un hoquet unique de l'ordre de la centaine de ms supprimé (ESTIMÉ). **Risque** Nul pour le jeu ; le préchauffage doit utiliser la même variante (même primitive, même viewport). **Effort** S.
**Sévérité** MINEUR (une fois par processus, mais pile sur l'action). **Statut ROADMAP** CONNU-OUVERT (22510 : la chauffe générale est « un pas séparé » non fait) ; les shaders précis sont nouveaux.

**Comment le vérifier** `tools/bench_framerate.tscn --seuil-lent 25` (ISO12, `bench_framerate.gd:147,313` ; dater toute image lente) : une image lente groupée au premier allumage de torche daté est une compilation (règle de ROADMAP 22513) ; la
même prise avec le flou masqué (`--sans-brouillage-repos` de LUM-01) doit la faire disparaître.

---

### LUM-06 — La texture d'écran du voile plein est déclarée avec mipmaps

**Où** `voile_eblouissement.gdshaderinc:245` (lue l.452-454).

**Constat**
```glsl
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
...
float r = texture(screen_texture, SCREEN_UV + decalage).r;   // décalage ≤ 0,018 UV, gradient quasi nul
```
`filter_linear_mipmap` demande au moteur de générer la chaîne de mipmaps du back-buffer copié (lecture du moteur par mémoire, à confirmer). L'aberration lit à ~1 texel par pixel : le LOD choisi est 0, les niveaux
supérieurs ne servent à rien. (`brouillage_flou` déclare, lui, `filter_linear`.)

**Coût** ESTIMÉ : une génération de mipmaps plein cadre par image pendant les épisodes d'éblouissement ≥ 0,12 (ordre ≤ 0,2 ms à 2560×1440) — événementiel mais exactement dans les instants qui font le 1 % bas.
**Proposition** Passer à `filter_linear`. **Gain** ESTIMÉ ≤ 0,2 ms pendant l'éblouissement. **Risque** Image identique (LOD 0) ; à confirmer par comparaison au pixel au `banc_voile`. **Effort** S. **Sévérité** MINEUR.
**Statut** NOUVEAU. **Vérifier** `banc_voile` en comparant à `main` ; `--temps-par-vue` pendant un éblouissement tenu.

---

### LUM-07 — Le premier calcul d'éblouissement de chaque classe relit le cookie 1024² depuis le GPU, au premier allumage de torche

**Où** `weapon_data.gd:288-299` (`image_torche`), `:322-323` (`lumiere_recue`), `game_state.gd:2707` ; garde-fou voisin : `weapon_data.gd:104-106`.

**Constat** `image_torche()` appelle `tex.get_image()` à son premier appel ; le commentaire de la ligne 104 dit lui-même que `get_image()` « rapatrie depuis le GPU ». Le premier appel arrive dans
`_lumiere_du_faisceau`, à la première image où une torche de cette classe est allumée — pas à `equip_weapon`. Cache ensuite correct (`_torch_image`).

**Coût** ESTIMÉ : une lecture GPU synchrone de 4 Mo (1024² RGBA8), 1 à 4 ms, davantage si le GPU a du travail en file car la lecture l'attend ; une fois par classe et par processus, au premier allumage de torche de cette classe — donc pendant la manche. **Proposition** Appeler `weapon.image_torche()` dans `Player.equip_weapon` (`player.gd:1210`, ou au
décompte). **Gain** un hoquet de quelques ms supprimé. **Risque** nul (même appel, plus tôt ; la texture est déjà créée). **Effort** S. **Sévérité** MINEUR. **Statut** NOUVEAU (la checklist « `get_image()` à un
moment décisif »). **Vérifier** `--seuil-lent` autour du premier allumage daté.

---

### LUM-08 — Murs : des contours à la place des rectangles réduiraient les instances d'occulteur et supprimeraient les fentes

**Où** `map_geometry.gd:262-268, 335-365, 418-452` (`trace_contours` existe, « non utilisé par `build_collisions()` pour l'instant »).

**Constat** Voir le tableau du §1.4 : 4 à 11 rects sur les cartes de duel (2 à 9 boucles), jusqu'à 76 en solo (51 boucles). Coût `4 × N × L` par viewport (LUM-03) : le gain porte sur N. Duel : 55 rects → 33 boucles (−40 %), soit −13 à −46 % du N total retenu par une lampe ; solo : 1 106 rects → 711 boucles (−36 %, médiane 9 → 6).
Bénéfice annexe : les rects voisins laissent entre leurs occulteurs une fente de 6 px (3 + 3 px d'`OCCLUDER_INSET`) qui peut laisser filer un liseré de lumière au travers d'un mur quand la torche est alignée avec la couture (aveu
du commentaire l.262-268) — c'est aussi une question d'**équité** (lumière visible à travers un mur).

**Coût** PROUVÉ en instances ; ESTIMÉ en temps, au calibrage de 2,8 µs par dessin de LUM-03 : de l'ordre de 0,15 à 0,9 ms en duel (−55 à −336 dessins sur 392 à 840), vraisemblablement plusieurs fois moins ; davantage en solo lourd. **Proposition** Générer un occulteur par boucle de `trace_contours`, polygone décalé de 3 px vers la masse (`Geometry2D.offset_polygon`,
trous décalés vers l'extérieur), même couche d'ombre ; garder les rectangles pour la collision. **Risque** Moyen : le retrait de 3 px (qui évite l'auto-ombre des faces de mur) doit être reproduit par un décalage de polygone (−3 px sur les contours extérieurs, +3 px sur les trous), y compris pour un mur d'une case
(retrait plafonné au quart de la dimension, `_build_rect_occluder` l.381-385) et aux coins — `test_map_geometry`, `test_ombre_propre`, `banc_lumieres`, planches du Cloître. **Effort** M. **Sévérité** MINEUR en duel (plus en solo lourd : LUM-03).
**Statut ROADMAP** CONNU-OUVERT : `map_geometry.gd:262-268` (« la bascule se fera après validation visuelle, la géométrie est déjà prête ») n'a pas eu lieu ; rien dans la ROADMAP sur son coût. **Vérifier** `tools/compte_occulteurs.gd`, `test_map_geometry`, A/B image.

---

### LUM-09 — Les halos de proximité (et ceux des PNJ) paient des passes d'ombre là où ils n'éclairent rien, et gonflent le rect englobant pour toutes les autres lampes

**Où** `player.gd:901-917` ; `canaux_lumiere.gd:180-181` ; `perception_bot_noeud.gd:316` (le bot lit `ambient_light.enabled` et `.energy`).

**Constat** Connu pour le duel : 64 passes sur 80 pour rien, ~0,14 ms, rangé sans code (ROADMAP 27698, 28303). Ce qui s'y ajoute : (a) en **solo**, chaque PNJ est `player_id = 1` : son halo (canal 32) n'éclaire aucun objet de la vue de J1
(les copies de sol `_P2` sont sur la couche 4, hors masque de `vp1`) — N PNJ = N halos inutiles, chacun ombré dans chaque viewport dont il croise le champ ; (b) un halo inutile placé à la périphérie **agrandit le rect englobant**
des lampes à ombre et donc N pour *toutes* les lampes du viewport (`compte_occulteurs.gd:9-12`).

**Coût** ESTIMÉ, faible en duel (0,14 ms mesuré), à reprendre en solo avec LUM-03. **Proposition** Pour les PNJ : `ambient_light.shadow_enabled = false` (image identique en vue unique solo : le halo n'éclaire rien ; **ne pas** le désactiver,
le modèle de vue du bot le lit). Pour le duel : rattacher la canvas du halo de J1 à la seule lightmap de J1 et au capteur de J2 (patron `EtoileDeCorps`). **Risque** : un halo qui éclairerait un jour la vue adverse perdrait son ombre sans
alerte — `test_halo_proximite` doit couvrir le cas PNJ. **Effort** S (PNJ) / M (duel). **Sévérité** MINEUR. **Statut** DÉJÀ-TRANCHÉ pour le duel (28303 : sous le seuil de 0,3 ms), NOUVEAU pour le solo.

---

### LUM-10 — Une `hit_light` à ombre par plomb touché (jusqu'à 3 empilées par volée de pompe) ; `ground_flash` instanciée à chaque tir

**Où** `player.gd:2875-2932` (`rpc_update_hp`, `@rpc("authority", "call_local", "reliable")` : exécuté chez les deux pairs, création de la lumière l.2909-2932), `bullet.gd:424` (`target.take_damage` par plomb) ;
`game_state.gd:552-553` (`projectile_count = 5`, `spread_angles_deg = [0, 20, -20, 60, -60]`, portée 180 px) ; `player.gd:2722-2731` (`ground_flash`).

**Constat**
```gdscript
# player.gd:2909-2919, 2932 — sans condition, à chaque appel
var hit_light = PointLight2D.new()
LightTextures.poser(hit_light, LightTextures.ECLAT, 400.0)
hit_light.energy = 2.0 * EffectPolicy.curseur("lumiere_impact")
hit_light.shadow_enabled = true
hit_light.shadow_item_cull_mask = 1
hit_light.range_item_cull_mask = 1 | 4
add_child(hit_light)           # ... tween d'énergie sur 1 s, puis queue_free
```
Une volée du Terrassier lance 5 plombs ; à bout portant (≲ 50 px : `d · sin 20° ≤ 18 px`, rayon du corps `bullet.gd:30`) ceux de 0° et de ±20° touchent, soit **jusqu'à 3 appels de `rpc_update_hp` dans la
même image et donc 3 lumières ombrées strictement identiques (même parent, même position, même tween) empilées pendant une seconde**. Elles s'additionnent : une seule d'énergie ×3 donne la même image.
`ground_flash` est une instanciation par tir (sans ombre, 0,12 s : négligeable).

**Coût** ESTIMÉ, au même calibrage de 2,8 µs par dessin que LUM-03 : chaque `hit_light` ajoute `4 × N` dessins d'ombre (N ≈ 7 à 15 sur les cartes de duel) dans chaque viewport qu'elle croise (lightmap, capteur
de la victime, capteur de l'autre corps s'il est à moins de ~264 px : 200 px de demi-empreinte + 64 px de demi-fenêtre) ; les deux lumières en trop valent donc de l'ordre de 170 à 360 dessins par image pendant la seconde qui suit un tir au contact, soit de l'ordre de **0,5 à 1 ms
au calibrage** (vraisemblablement moins ; le calibrage lui-même est incertain). Événement rare, mais exactement sur le coup au but.

**Proposition** Regrouper les coups d'une même image par victime : si une `hit_light` a été créée dans cette image (`Engine.get_process_frames()`), additionner son énergie et ne pas en créer une seconde. Image
strictement identique pour des coups de la même image ; ne pas regrouper des coups d'images différentes (la première lumière a déjà décru). **Risque** Nul pour l'image dans ce cas ; le plafond de 15 lumières par item joue
en faveur du regroupement. **Effort** S. **Sévérité** MINEUR.
**Statut ROADMAP** DÉJÀ-TRANCHÉ pour le principe : ROADMAP 2506 (2026-09-15) garde `ground_flash` et `hit_light` — la seconde « ne s'allume qu'une fois par coup reçu » et « n'était pas allumée en nombre au relevé »,
relevé fait sur une rafale de pistolet. NOUVEAU pour l'empilement par plomb : la prémisse « une fois par coup » est fausse pour une volée de pompe.
**Comment le vérifier** Recensement par viewport de `bench_framerate` (l.767-841) après un tir de pompe au contact (`banc_balle_sans_lumiere.gd` sait déjà poser une rafale) ; `--seuil-lent` pour dater une image lente
sur le coup au but.

---

### LUM-11 — Le pool de particules porte 240 `PointLight2D` qui ne sont jamais allumées

**Où** `particle_pool.gd:126-132` (création), `:198, 216, 242, 260` (`enabled = false` dans les quatre genres), `:162` et `:177` (à chaque émission d'une particule : lecture de l'énergie, `_configure`), `:303` (**à chaque image et pour chaque particule active** : écriture d'`energy`, après `get_node("Poly")` l.302 et `get_node("Light")` l.303).

**Constat** Depuis le retrait des lumières de sang, de poussière, de fumée et d'étincelles (ROADMAP 2532, 5332, 2506), aucune branche n'allume `Light`. Le pool continue de la créer (240 nœuds), de lui poser une texture à chaque `_configure` et d'écrire
`energy` pour chaque particule active à chaque image, après deux `get_node` (`"Poly"`, `"Light"`).

**Coût** PROUVÉ en travail inutile ; ESTIMÉ ~0,05 ms/img au pic (≈ 100 particules × un `get_node` + une écriture serveur). **Proposition** Retirer le nœud `Light` et ses lectures. **Risque** deux gardes à adapter :
`tools/test_arena_lighting.gd:110`, `tools/test_match_format.gd:214`. **Effort** S. **Sévérité** ANECDOTIQUE. **Statut** NOUVEAU (domaine « particules » : à transmettre).

---

### LUM-12 — Deux quads plein écran sont dessinés à alpha 0 : vignette de dégâts, et (par conception) l'encre

**Où** `player.gd:795-810` (`vignette_rect`), `damage_vignette.gdshader:30-33` ; `ui.gd:2582-2587` (`VoileEncre`).

**Constat** La vignette est un `ColorRect` PRESET_FULL_RECT dont `visible` n'est jamais écrit (`vignette_rect` n'est repris nulle part après l.810 ; seul `vignette_mat` reçoit `intensity`, l.1294-1300 et 2859-2868) et dont le shader écrit `alpha × step(0.03, intensity)` : à zéro, un quad de la fenêtre entière est rasterisé et mélangé pour rien. Elle est construite pour tout `Player`, PNJ compris, mais sa `visibility_layer` est la couche privée du joueur (`2 if player_id == 0 else 4`, l.799) : celles de l'adversaire et des PNJ (`player_id = 1`) sont rejetées par le `canvas_cull_mask` de la vue regardée et ne dessinent rien — **un seul quad plein cadre par vue**, celui du joueur regardé. `VoileEncre` (10 % noir) est un aplat
constant voulu. **Coût** ESTIMÉ 0,03 à 0,1 ms chacun à 2560×1440. **Proposition** Vignette : `visible = intensity ≥ 0,03`, posé là où `intensity` est écrite (l.1296, 1300, 2864, 2868) — `vignette_rect` doit devenir une variable membre (quelques lignes). **Risque** nul (le shader sort déjà alpha 0 sous 0,03). **Effort** S. **Sévérité** ANECDOTIQUE.
**Statut** NOUVEAU (domaine UI/joueur).

---

### LUM-13 — Micro-coûts par image du voile, du brouillage, de l'éblouissement et des plafonniers

**Où et constat (PROUVÉ, tous négligeables isolément — une ligne chacun, à ne traiter que groupés)** :
- `ui.gd:2526-2528` `aberration_debut()` interroge `RenderingServer.shader_get_parameter_default` à chaque appel, 3 fois par image (`_poser_voile` ×2 via l.2543, `update_hud` l.8878) : une valeur constante.
- `EffectPolicy.curseur("eblouissement")` ×3-4 par image (`effect_policy.gd:345-352` : `Engine.get_main_loop`, `get_node_or_null(^"GameSettings")`, `has_method`, puis `current_effect` → `clamp_value`) ; pour un effet du
  MONDE la réponse est la constante `DEFAULT`. ⚠️ **Les sites d'appel doivent rester dans le texte** : le commentaire de `curseur()` dit que `tools/test_curseurs_branches.gd` les y cherche — l'économie se fait DANS `curseur()` (référence
  de `GameSettings` gardée), jamais en retirant l'appel.
- `Brouillage.flou()` / `halo()` construisent un `Dictionary` à chaque appel (`brouillage_vue.gd:227, 266`), même sans éblouissement.
- `game_state.gd:2672-2673` (et 2587-2588, 2573-2574) : `facteur_de_lampe_a()` — un `get_nodes_in_group("gadgets")` puis `has_method` + `facteur_de_lampe` par membre — est évalué comme ARGUMENT de `_lumiere_du_faisceau`, donc pour
  **chaque couple source × cible**, même quand le faisceau n'atteint pas la cible (la lecture du cookie n'a lieu qu'à l'intérieur). 4 fois par image en duel ; **3N + 1 en solo à N PNJ (22 pour 7 PNJ)**, les couples PNJ→PNJ étant
  écartés plus tôt (`_plafond_de_source`, l.2551+).
- `plafonnier.gd:261-275` : `get_nodes_in_group("players")` + deux `Array` par plafonnier et par tick (≤ 8 × 60 Hz).
- `regard_duel.gd:48` : un littéral de 3 `Vector2` alloué par appel quand le lacet est non nul (45° en ligne), 1 à 2 caméras par image.
- Démarrage (froid) : `VoileTextures.toutes()` (cache statique, une seule fabrication) écrit ~164 000 pixels en GDScript (`ui.gd:2457` ← `_forger_voile`, appelé pour `VoileP1`/`VoileP2` l.2632-2633), ESTIMÉ 30 à 65 ms une fois
  (extrapolé des 0,17 µs/pixel mesurés pour les volutes, `fusee.gd:339-342`, ici plus cher par pixel : `pow` ×2-3 et `length()`) ; `Brouillage.texture_halo()` fabrique deux `GradientTexture2D` 512² identiques (un par appareil,
  `brouillage_vue.gd:91`).

**Proposition** Variable statique pour `aberration_debut` ; `GameSettings` mis en référence dans `EffectPolicy` ; `facteur_de_lampe_a` calculé seulement si le cookie donne une intensité non nulle (à l'intérieur de `_lumiere_du_faisceau`) ; un `static var` pour la texture du halo ;
un seul nœud qui publie les positions des joueurs aux plafonniers. **Gain** ESTIMÉ < 0,05 ms/img cumulés en duel, un peu plus en solo lourd (non mesuré). **Effort** S. **Sévérité** ANECDOTIQUE. **Statut** NOUVEAU.

---

## 3. Ce qui est déjà bien fait

1. **Filtre d'ombre `NONE` partout en jeu** (le moins cher) et aucune `DirectionalLight2D` ; le PCF5 n'existe que dans un menu mort. Aucune lumière créée à l'image.
2. **Les lumières décoratives ont été retirées avec méthode** : balle, étincelles, sang, poussière, fumée n'éclairent plus (ROADMAP 2506, 2508, 2532, 5332) ; `enabled = false` et non `energy = 0` (piège des 15 lumières par item).
3. **`LightTextures.poser()` est la porte de `texture_scale` des lumières PEINTES** (rétrodiffusion, halo, flash, éclat ; `test_lumieres` exige qu'aucun fichier de jeu n'y écrive directement) : une empreinte en unités de monde, indépendante de la résolution cuite ; textures partagées en cache. Les torches, elles, dérivent leur échelle de `portee_torche()` via `echelle_torche()` (`player.gd:1229`) : une seule vérité pour la portée.
4. **MurLed = UNE lumière sans ombre pour toute la carte**, texture cuite une fois par carte et mise en cache (`mur_led.gd:128-133, 208-213`), au lieu de N lumières le long des murs.
5. **Le voile a deux shaders** (plein/calme) pour ne pas payer `hint_screen_texture` au repos, et la copie plein cadre suit le seuil (`ui.gd:8878-8885`) ; la copie du brouillage est bornée à l'ellipse en texels de framebuffer (`rect_photocopie`) — 0,375 Mpx au lieu de 3,69.
6. **Rendu coupé pour ce que personne ne regarde** : vue cachée → `UPDATE_DISABLED` (`_accorder_rendu_aux_vues`), capteurs de figurants coupés hors de portée (`presentation_3d.gd:1198`), plafonniers allumés par proximité avec hystérésis, peinture iso en `UPDATE_ONCE`, lumière 3D éteinte par défaut avec ses ombres.
7. **La passe d'ombre a été mesurée et ses limites écrites** (0,09 ms/lampe, 80/64 dessins, seuil de 0,3 ms, outil `compte_occulteurs.gd`, recensement par viewport dans le banc) : c'est ce qui rend LUM-03 vérifiable plutôt que spéculatif.
8. **Modèles purs et indépendants de la cadence** : `Eblouissement.integrer` est linéaire, `Vision` lit le cookie au lieu de recopier sa formule, `Brouillage` n'a aucune dépendance (testable en `--script`), l'`Image` du cookie est mise en cache (pas de `get_image()` par image).

---

## 4. Questions ouvertes

**A. Mesures que seul le Mac peut donner** (toutes en A/B C A A C, torche tenue, 60 s hors transitoire, avec `--temps-par-vue`) : (1) LUM-01 : flou + copie éteints au repos ; (2) LUM-02 : voile caché au repos ; (3) LUM-03 : une salle
lourde de l'aventure (`chapitre_00/niveau_09`, `chapitre_09/niveau_07`, `chapitre_08/niveau_09`) avec et sans `shadow_enabled` ; (4) le coût réel d'un dessin d'ombre (le calibrage de 2,8 µs vient d'une mesure de 0,09 ms noyée dans un bruit de 0,35 ms, ROADMAP 28270).

**B. Le solo a-t-il la même cible que le duel (« 1 % bas ≥ 60 ») ?** Si oui, LUM-03 est le premier chantier ; sinon, un budget par salle (nombre de corps éclairés simultanément) suffirait.

**C. Le halo d'éblouissement sur soi est-il voulu ?** Quand `source_eblouissante` est soi (rétrodiffusion), `BrouillageVue` pose le halo sur le regardeur (alpha 0,084, ~21/255 au pic) ; et pendant un pic de flash de tir *reçu avec sa propre torche allumée*, le flou et le halo se
centrent aussi sur soi, non sur le tireur (le flash n'est pas une « source » de `_sources_eblouissantes`). Question de rendu, pas de coût ; elle conditionne la forme du correctif de LUM-01. **Et le flou de repos lui-même** : nul en 1080p, il devient un adoucissement de ≤ 1 px dans un lopin devant le joueur à 2560 × 1440 (≤ 2,5 px à l'échelle 2, voir LUM-01) parce que son noyau est en pixels d'appareil. L'intention écrite (`brouillage_vue.gd:145-148` : « ne sert que quelques secondes par manche ») plaide pour le retirer, mais c'est un changement d'image : à valider par Adrien, sur sa fenêtre réelle.

**D. Contours pour les occulteurs (LUM-08)** : gain de coût modeste en duel, mais fait disparaître la fente de lumière entre rectangles — décision d'équité qui revient à Adrien.

**E. Cookies rognés (LUM-04)** : refonte mécanique mais large (six consommateurs, équité de l'éblouissement). À ne lancer qu'après la mesure A.3, et seulement si la passe d'ombre dépasse le seuil de 0,3 ms.

**F. Plafond de 15 lumières par item en solo** : jusqu'à 8 corps de 936 px + 8 plafonniers + MurLed peuvent croiser un même quadrant de 560 px ; au-delà de 15 le moteur jette les plus récentes **sans erreur** (ROADMAP 5332). Une salle à 7 PNJ torche allumée peut donc trancher net un halo de plafonnier.
À vérifier avec le recensement par quadrant (`--plans=quinze` de `banc_lumieres`).

**G. Équité** : aucune économie sur l'éblouissement, le voile ou les lumières ne doit être un réglage du joueur (famille MONDE) ; tout palier de qualité ajouté doit être automatique et identique pour les deux joueurs.

**H. Pistes laissées de côté faute de preuve** : `rendering_quadrant_size` plus petit (ROADMAP 5338-5340 et 5378, « à chiffrer au bench_framerate ») réduirait la quantification des listes de lumières par item (ESTIMÉ : à alignement aléatoire,
un carré de 936 px touche (1 + 936/560)² ≈ 7,1 quadrants de 560 px, soit ≈ 2,2 Mpx de fragments évalués pour 0,88 Mpx de rect de lumière, avant découpage par l'écran) au prix de
plus d'appels de dessin — à tenter après LUM-04 ; `rendering/2d/shadow_atlas/size` laissé à 2048 (aucun levier de coût attendu).

**Notes de transmission** (hors de mon domaine, ou à recouper avec l'agent concerné) :
- LUM-11 (particules), LUM-12 (UI / joueur) et la gestion des capteurs iso (LUM-03 n°2) relèvent d'autres domaines.
- `player.gd:1259 _process` (par IMAGE) : `GadgetBase.effacements_a()` (l.1319 → `gadget_base.gd:625`) fait deux `get_nodes_in_group` et des appels dynamiques par joueur, **PNJ compris en solo** ; plus des tableaux
  littéraux alloués par image (`[visual, visual_dim, visual_reveal]`, `[visual_enemy_ptr, …]`).
- `player.gd:1694 _physics_process` (par TICK, 60 Hz nominal) : `_rapprocher_la_lampe()` (l.1975, 2 rayons) et la boucle `get_nodes_in_group("gadgets")` (l.2003) — hors budget, mais ils s'ajoutent aux autres requêtes de rayon du tick.
- `player.gd:2916` et `ui.gd:2549` : les commentaires « Curseur MONDE (plancher 0,4 / 0,8 en classé) » sont périmés — les planchers ont été retirés le 2026-09-12 (`effect_policy.gd:25-36`). Documentaire.
- `rpc_update_hp` est un RPC fiable en `call_local` : une volée de pompe au contact en déclenche jusqu'à 3 dans la même image (domaine réseau ; voir LUM-10).
