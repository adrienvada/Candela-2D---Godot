# GAD — Gadgets des classes et fusée éclairante

Audit d'optimisation, dépôt `/home/user/Candela-2D---Godot`, commit `52a29c1` (0.8.3 + SOLO S12), 2026-10-04.
**Lecture seule. Godot n'a pas été lancé** : aucun chiffre de ce rapport n'est une mesure de cette session. Les mesures citées
viennent de la ROADMAP / de `docs/iso/` (M3, vue unique) et sont référencées ; tout le reste est **PROUVÉ** (lu dans le code) ou
**ESTIMÉ** (raisonnement, règle de pouce « un appel GDScript ≈ 0,3 à 1 µs » — jamais mesurée ici).

Périmètre lu en entier : `gadget_base/braises/gresillement/leurre/mine/ombre/poudre/poussiere/suie/torche_fantome/voile/volume/profile.gd`,
`telemetrie_gadgets.gd`, `fusee.gd`, `fusee_couleur.gd`, `fusee_modele.gd`, `class_data.gd`, `root_profile.gd`, `flare_profile.gd`,
`rank_loadout.gd`. Points d'appel lus : `game_state.gd` (pose, allumage, bascule, réserves, éblouissement, killcam, archive),
`player.gd` (`_process` l. 1259-1391, `_physics_process` l. 1694-2250), plus ce qu'ils appellent hors périmètre quand il le fallait
(`replay_system.gd`, `bullet.gd`, `charte.gd`, `etoile_de_corps.gd`, `light_textures.gd`, `weapon_data.gd`, `ui.gd` HUD des réserves,
`iso_volumes.gd` / `iso_nuage_voxel.gd` pour la projection iso des gadgets).

---

## 0. En bref

1. **Le CPU du domaine est léger.** Aucun gadget ne crée de particules, de `Timer`, d'`Area2D` ni de requête de zone (grep) ; aucun
   RPC par image ; la télémétrie est un jeu de compteurs en mémoire. Les coûts CPU par image se comptent en dizaines de µs, au plus
   quelques centaines (poudre pleine de traces, voile, suie allumée).
2. **Le coût qui compte est GPU, et c'est la fumée de la fusée** : 3,39 ms par fusée mesurés sur le M3 (couches, avant les voxels), dont
   2,66 ms pour le volume de fumée (ROADMAP l. 28266). Elle s'additionne fusée par fusée, sans plafond ni niveau de détail, et la forme
   actuelle (fumée en cubes, défaut depuis la 0.8.1) **n'a jamais été mesurée sur le M3**. Le Terrassier (poussière + 3 fusées, recharge
   18 s) est la classe la plus chère à dessiner ; un miroir Terrassier/Terrassier peut poser 8 fusées vivantes.
3. **Sept constats CPU / hoquet / sous-vues, mineurs, tous sans risque pour la simulation** : tweens à courbe de Bézier GDScript par trace
   de poudre (GAD-02), onde du voile recalculée à chaque image rendue (GAD-03), rayons de la suie à chaque pas (GAD-04), grille de cubes
   construite en GDScript au premier nuage (GAD-05), chauffe de shaders canvas incomplète (GAD-06), nappes braises/poudre en tracés coûteux
   en appels de dessin (GAD-07), et un `SubViewport` 256² en `UPDATE_ALWAYS` par vue pour chaque gadget debout et chaque fusée posée, même
   hors champ (GAD-12).
4. **Aucune fuite ni accumulation non bornée trouvée** (gadgets, fusées, nappes, traces, lumières, copies de killcam) — voir Q3.
5. **Trois points hors de mes fichiers, signalés pour les agents concernés** : le HUD des réserves ré-applique thème et styles à chaque
   image (GAD-08), l'archive de match écrit tout l'historique en synchrone à l'instant du dernier tir (GAD-10), et la projection iso
   des gadgets (ruban du voile, 16 lueurs des braises, ~30 poussées d'uniformes par fusée et par vue).

---

## 1. Réponses courtes aux six questions

**Q1 — Coût par image d'un gadget actif et de la fusée.**
Pas de particules, pas de `Timer`, pas d'`Area2D`, pas de `get_overlapping_*` (grep sur `gadget_*.gd`, `fusee*.gd` : seul `create_tween` dans
`gadget_poudre.gd:232`, `intersect_ray` dans `gadget_volume.gd:206` et `fusee.gd:420`). Tableau chiffré en §2.2-2.3 ; en résumé :
voile 0,05-0,15 ms/image (ESTIMÉ), poudre 0,1-1 ms/image avec 15-70 traces (ESTIMÉ), suie 0,015-0,2 ms/pas (ESTIMÉ), les sept autres
< 0,03 ms. Fusée : ~40-80 µs/pas côté script (ESTIMÉ) + ~30 poussées d'uniformes par vue côté iso (ESTIMÉ) ; son vrai coût est GPU
(**mesuré** : 3,39 ms/fusée, ROADMAP l. 28266 ; sa lumière 2D 0,09 ms et son ombre 0,09 ms — piste fermée, `docs/iso/iso12/mesure_fusee.md`).
Lumières : **toutes ombrées** (`shadow_enabled = true`, `SHADOW_FILTER_NONE`) — tableau §2.7. En vue iso (le défaut), chaque gadget « debout » (mine, ombre, torche
fantôme, voile, grésillement, leurre) et chaque fusée posée porte en plus **un `SubViewport` 256² en `UPDATE_ALWAYS` par vue** — son capteur de lumière (GAD-12). `_process` : un seul, celui du voile, qui tourne
**toute la vie du voile (= la manche entière, `duree_vie` 0)** ; aucun `_process`/`_physics_process` ne survit à la fin d'un effet
(`queue_free` à `MORTE` / fin de vie), hors le voile des copies de killcam (`gadget_base.gd:305-308` ne coupe que la physique).

**Q2 — Premier usage (hoquet au moment décisif).**
Préchauffé : volutes + shader du voile (`Fusee.prechauffer`, appelé par `rebuild_arena`, `game_state.gd:1565`), shader/aplats/reliefs/planches
réduites de la fumée en cubes (`IsoNuageVoxel.prechauffer`, `iso_volumes.gd:343`), étoile d'ombre du leurre (cache `Charte._ombres`, remplie à
l'équipement de la classe), masques de lumière (cache `LightTextures`), shader du corps adverse du leurre (`preload`, partagé avec `player.gd`).
**Non préchauffé** : grille de cubes de chaque nuage (GAD-05), shader canvas `nappe_fusee` et matériaux `incandescent` / `peint_lumineux`
(GAD-06), compilation du shader 3D `nuage_voxel_iso` (connu, ROADMAP l. 31300), `load()` du script puis des sprites de chaque gadget à sa
première pose (`game_state.gd:3796`, `gadget_base.gd:424-429`), `fusee_corps.png` (1456×720) au premier lancer (`fusee.gd:250-254`),
`WeaponData.image_torche()` (relecture GPU de 1024² au premier éblouissement par classe, `weapon_data.gd:288-299`).

**Q3 — Nettoyage.** Rien d'illimité : un gadget debout par joueur (remplacé par `queue_free`, `game_state.gd:3835-3837`) ; fusées 20 s ;
traces ≤ 72 par nappe, 8 s ; `bullet_container` purgé à chaque départ de manche (`game_state.gd:2073-2074`) ; copies de killcam libérées par
`_abort_killcam` → `_purger_gadgets_killcam` (toutes les sorties, `game_state.gd:4970-4983`). Toute lumière créée est enfant du gadget/de la
fusée ; l'étoile du leurre (`EtoileDeCorps`, un `CanvasLayer`) se détache dans `_exit_tree`. Seule lumière « orpheline » au sens du plafond de
15 par item : la torche fantôme à énergie 0 sous grésillement/suie, qui reste `enabled` (GAD-09, anecdotique).

**Q4 — Réplication.** Les nœuds de gadget ne sont pas répliqués (`gadget_base.gd:492-494`). Sept RPC événementiels, tous `reliable`
(`rpc_spawn_gadget`, `rpc_allumer_gadget`, `rpc_etat_gadget`, `rpc_detruire_gadget`, `rpc_spawn_fusee`, `rpc_eteindre_fusee`,
`rpc_stock_fusees`) ; l'état d'un gadget est une fonction pure de (graine, âge) → rien en continu. Le seul trafic continu qui touche aux
gadgets est la paire de bits `flare` / `gadget` du paquet d'entrée générique (`player.gd:1395`), non propre aux gadgets. Les tics de braises
(4 PV, 0,25 s) passent par `rpc_update_hp` reliable : ≤ 4 appels/s par blessé, indépendant des fps (corrigé en étape 28 lot A1).

**Q5 — Télémétrie.** `TelemetrieGadgets` n'écrit rien : dictionnaires d'entiers et de flottants incrémentés dans `pose / mort_de_gadget /
allumage / bascule / pv_perdus` (`telemetrie_gadgets.gd:176-239`), aucun fichier, aucun réseau. `resume()` est appelé une fois par match
(`game_state.gd:4741`). Le bloc voyage ensuite dans `MatchRecord.append_to_history`, **synchrone, à l'instant du dernier tir** — hors de mon
périmètre mais signalé (GAD-10).

**Q6 — Pire cas.** Voir §2.8 : la combinaison la plus coûteuse n'est pas « voile + suie + fusée » (le Spectre n'a **aucune** fusée ; le voile
ne coûte que du CPU) mais **plusieurs fusées vivantes à l'écran, a fortiori avec la poussière du Terrassier** (336 px, la plus grosse masse
après la fusée). Mesuré : une fusée seule fait passer le 1 % bas de 84,8 à 70,1 hors chauffe (mesure_fusee.md, couches) ; la cible est 60.

---

## 2. Carte des chemins chauds

### 2.1 Quantités au pire cas

| Objet | Quantité simultanée | Source |
|---|---|---|
| Gadgets debout | **1 par joueur** (2 en duel ; 1 par PNJ en aventure, `_slot_du_gadget`) | `game_state.gd:3826-3837` |
| Durées de vie | voile, ombre, mine (avant allumage), grésillement, poudre : **manche entière** ; torche fantôme 16 s ; braises 10 s ; suie 9 s ; poussière 7,5 s ; leurre 18 s ; mine 1,6 s après allumage | `game_state.gd:5319-5349`, `gadget_mine.gd:51` |
| Recharge de pose | 60 s | `game_state.gd:3297` |
| Vie d'une fusée | **20 s** = 4 (plein feu, rouge long par défaut) + 8 + 3 + 5 | `fusee_modele.gd:35-57, 182-183` |
| Fusées par classe | pompe **3 / 18 s** ; allumeur 2 / 12 s ; incendiaire 2 / 60 s ; les autres 1 / 60 s ; spectre 0 | `game_state.gd:5129-5251` |
| Fusées vivantes en même temps | pompe : 3 puis une 4ᵉ à 18 s alors que la 1ʳᵉ vit jusqu'à 20 s ⇒ **4** ; miroir pompe/pompe ⇒ **8**. Salon d'attente / bac à sable libre : réserve jamais décomptée (`fusee_disponible`, `game_state.gd:3063-3064`), borne = 20 s / 0,6 s de désarmement ≈ **33** | `fusee_modele.gd:134`, ci-dessus |
| Traces de poudre | ≤ 72 par nappe (`MARQUES_MAX`), 8 s chacune, enfants de l'arène | `gadget_poudre.gd:55, 76` |
| Nœuds par gadget | voile 6 · ombre 4 · mine 3 (+1 lumière allumée) · braises 4-5 · suie/poussière 3 · torche fantôme 8 · leurre 8 (dont un `CanvasLayer`) · grésillement 3-4 · poudre 3 + jusqu'à 72 `Polygon2D` + 72 `Tween` | lu fichier par fichier |
| Nœuds par fusée | 9 (lumière, cœur, corps, 3 nappes, voile, voix audio) + côté iso : 1 `MultiMeshInstance3D` + 1 juge par vue, 1-2 halos | `fusee.gd:197-320`, `iso_volumes.gd:493-522` |

### 2.2 Par image rendue (`_process`, fps déplafonnés)

| Quoi | Où | Fréquence/quantité | Coût |
|---|---|---|---|
| Effacement des corps par fumée/poussière/suie | `player.gd:1319` → `GadgetBase.effacements_a` (`gadget_base.gd:625-636`) | par `Player` (2 + PNJ), 2 `get_nodes_in_group` + `occultation_pour` des membres | ESTIMÉ ≈ 3-6 µs par joueur |
| Piétinement des fusées | `game_state.gd:4088-4126` | 2× `bullet_container.get_children()` + `is Fusee` sur tous les enfants (balles comprises) | ESTIMÉ < 10 µs |
| Éblouissement (hôte) : sources fusées/gadgets, rayon de ligne de vue | `game_state.gd:2442-2539, 2551-2607, 2746-2818` | 1 `Dictionary` par source ; par paire source×cible : 1 rayon + parcours du groupe `gadgets` ; `facteur_de_lampe_a` (parcours + `has_method`) | ESTIMÉ 10-15 µs par paire proche ; 0,3 ms au pire (6 fusées + gadgets + torches) |
| Mine/braises, hôte | `game_state.gd:3551-3565` | `veut_s_allumer` + `appliquer_effets` par gadget | négligeable ; les braises accumulent (tics 0,25 s) |
| Réserves | `game_state.gd:3125-3154, 3763-3777` | `_accorder_fusees` : `FlareProfile.avancer` rend un `Array` neuf `[stock, acc]` par joueur et par image, **y compris réserve pleine** (`flare_profile.gd:66-71`, `recharge_active()` est vrai pour toutes les classes qui ont une fusée) ; `_maj_reserves_gadgets` : 2× `gadget_basculable_de` (parcours du groupe + `has_method`) | négligeable (< 5 µs) |
| **Onde du voile** | `gadget_voile.gd:147-162` | `_process` pendant toute la vie du voile : 17 points × 3 `sin`, tableau neuf, `Line2D.points =` (re-tessellation) | ESTIMÉ 40 µs script + 10-15 µs `Line2D` |
| **Tweens des traces de poudre** | `gadget_poudre.gd:232-237`, `charte.gd:1145-1152, 1205-1224` | 1 lambda GDScript + Newton de Bézier par trace vivante | ESTIMÉ 5-15 µs/trace |
| Projection iso (autre rapport) | `iso_volumes.gd:409-447` | duck-typing `"_atterrie" in noeud and "graine" in noeud` sur chaque enfant de `bullet_container` ; `_suivre_toile` (`ImmediateMesh` reconstruit, l. 1326-1339) ; `_suivre_braises` (RNG neuf + 16 halos, l. 604-624) ; `poser_fusee` (≈ 30 `set_shader_parameter` par vue, `iso_nuage_voxel.gd:648-676`) | ESTIMÉ 50-100 µs par objet suivi |
| **Capteurs de lumière des objets (iso)** | `miroirs_iso.gd:201-254`, `capteur_corps.gd:80-123` | 1 `SubViewport` 256² `UPDATE_ALWAYS` par vue et par gadget debout / fusée posée, mis à jour même hors champ (GAD-12) | mesuré ≤ 0,15 ms pour une fusée (résidu, `mesure_fusee.md`) ; ESTIMÉ 0,05-0,15 ms par objet et par vue |
| HUD des réserves (autre rapport) | `ui.gd:3128-3300` ×2 panneaux | thème + styles ré-appliqués (GAD-08) | ESTIMÉ 0,05-0,2 ms |
| Audio | `fusee.gd:385-396` | `annoncer_son_2d` toutes les 0,6 s par fusée posée | négligeable |

### 2.3 Par pas de physique (60 Hz — `physics_ticks_per_second` non surchargé dans `project.godot`)

| Quoi | Où | Coût |
|---|---|---|
| `GadgetBase._physics_process` | `gadget_base.gd:455-458` | `_age += delta` sur tous les gadgets : négligeable |
| Braises | `gadget_braises.gd:192-200` | 2 écritures (énergie de la lumière, alpha de la nappe) : négligeable |
| Poussière | `gadget_volume.gd:103-109` | 1 écriture d'alpha : négligeable |
| **Suie** | `gadget_volume.gd:103-114` → `_lumiere_entrante()` (l. 164-215) | jusqu'à **28 rayons** + ~10 allocations, 3 parcours de groupes : ESTIMÉ 15 µs (aucune lampe) à 0,05-0,2 ms (lampe braquée dessus) |
| Poudre | `gadget_poudre.gd:125-182` | `get_first_node_in_group` + 2 joueurs : ESTIMÉ ~10 µs (toute la manche) |
| Torche fantôme | `gadget_torche_fantome.gd:178-197, 233-249` | scan linéaire du plan de gestes (≤ ~25 entrées), `facteur_de_lampe_a`, `sin`, rotation d'un `StaticBody2D` portant 2 lumières : ESTIMÉ 20-40 µs |
| Leurre | `gadget_leurre.gd:260-278` | `effacements_a` + 2 tableaux littéraux : ESTIMÉ 10 µs |
| Grésillement | `gadget_gresillement.gd:114-144` | `facteur_de_lampe` appelé ≥ 6 fois par image par les autres systèmes ; `niveau_noir` recalculé à chaque appel (8 `_melange`) : ESTIMÉ 6-10 µs l'appel dans le rayon |
| Fusée posée | `fusee.gd:361-375, 650-831` | `_appliquer_age` : ~40 écritures de propriétés/uniformes, tableaux neufs (`masses`, `filtrer_sillage`, `vivants`), 5-8 `set_shader_parameter` : ESTIMÉ 40-80 µs |
| Fusée en vol | `fusee.gd:402-440` | 1 à 4 rayons + `poser_hauteur_source` : négligeable (≈ 0,5 s) |
| Chaque balle | `bullet.gd:347, 535-539` | `get_nodes_in_group("fusees")` + `is Fusee` + `occultation_pour`, **par balle et par pas** : ESTIMÉ 0,5 µs sans fusée, ~7 µs avec 6 |
| Torche des joueurs | `player.gd:2003-2004` | parcours du groupe `gadgets` + `facteur_de_lampe`, par joueur torche allumée |
| Enregistrement du rejeu | `replay_system.gd:196-241` | tous les enfants de `bullet_container` : `has_method("age_combustion")` puis `is_in_group` ; `etat_de_rejeu()` = 1 `Dictionary` de ~14 clés par gadget ; traces en tableau plat sans allocation par trace — **60 Hz fixe** |

### 2.4 Par événement

| Événement | Chaîne | Remarque |
|---|---|---|
| Pose | `spawn_gadget` → `point_de_pose_libre` → `_gabarit_bloquant` (`load` + `script.new()` + `free()` — `game_state.gd:3504-3514`) → `rpc_spawn_gadget` → `_do_spawn_gadget` : `load(script)`, `script.new()`, `_ready` monte formes/occluder/visuel/repère, parcours du groupe pour remplacer l'ancien | quelques centaines de µs (ESTIMÉ) ; 1ʳᵉ fois : compilation du script + chargement des PNG |
| Lancer de fusée | `spawn_fusee` → `rpc_spawn_fusee` → `Fusee.new()` + `_ready` (9 nœuds, 2 `ShaderMaterial`, `AudioStreamPlayer2D`, son de lancer) | ESTIMÉ 0,3-0,8 ms ; 1ʳᵉ fois : `load(fusee_corps.png)` |
| Atterrissage | `_atterrir` : masque d'ombre, hauteur, empreinte, son ; puis l'allumage change `texture_scale` de la lumière **à chaque pas pendant 3 s** (`_poser_empreinte`, `fusee.gd:866-872`, Q58) | |
| Allumage de mine | `rpc_allumer_gadget` → `allumer()` → `_monter_flamme()` : 1 `PointLight2D` ombrée de 520 px | µs côté script |
| Mort d'un gadget | `detruire()` → signal → `_sur_gadget_detruit` → `rpc_detruire_gadget` (hôte) | |
| Début de killcam | fusées vivantes libérées puis **recréées** par `Fusee.new()` + `_ready` ; gadgets masqués (pas libérés) + une copie par gadget de l'instantané ; traces en pool | ESTIMÉ 0,5-1 ms par objet, sur une seule image |
| Dernier tir du match | `_do_end_round` → `_archive_match_result` → `MatchRecord.append_to_history` | voir GAD-10 |

### 2.5 Chargement / premier usage — voir Q2 et GAD-05, GAD-06, GAD-11

### 2.5 bis Fichiers du périmètre sans chemin chaud

`class_data.gd` (données ; deux `ResourceLoader.exists` froids dans `assets_presents`), `root_profile.gd` (arithmétique pure, `facteur()` lu seulement pendant un root, `player.gd:1785-1786`), `rank_loadout.gd`
(tableaux de sélection, menus et `game_state.gd:5394-5414`, jamais par image), `gadget_profile.gd` (ressource de données ; `chemin_sprite_de` formate une chaîne à la pose), `fusee_couleur.gd` (un `Color.lerp` par pas
de fusée, `fusee.gd:662`) : rien à signaler.


### 2.6 Réseau et télémétrie — voir Q4, Q5

### 2.7 Inventaire des lumières (toutes `PointLight2D`, toutes ombrées dures)

| Source | Lumières | Empreinte | Masques | Durée | Réf. |
|---|---|---|---|---|---|
| Fusée | 1 « Halo » : `shadow_enabled`, `SHADOW_FILTER_NONE`, `enabled = energie > 0.005` | 160 px en vol, 440 px posée, **936 px à l'allumage (Q58, 1 s tenue puis retour à 3 s)** | ombre `1` (+ murets posée), éclaire `1|2|4` | 20 s | `fusee.gd:210-228, 677-678` |
| Braises | 1 « Lueur » | 340 px (RAYON × 5) | ombre `1|murets`, éclaire `1|2|4` | 10 s | `gadget_braises.gd:226-243` |
| Mine | 1 « Embrasement » (créée à l'allumage) | 520 px, énergie 6 | idem | 1,6 s | `gadget_mine.gd:220-240` |
| Torche fantôme | 2 : « Faisceau » (cookie de classe, `echelle_torche()`) + « Halo » | faisceau ≈ portée de torche (468 px, Q76) ; halo 256 px | ombre `1|2|4|8` / `1` | 16 s | `gadget_torche_fantome.gd:121-175` |
| Leurre, voile, ombre | aucune lumière ; occluders (étoile 32 sommets + disque 16 pour le leurre) | | | | |

Mesuré (M3, 2026-09-23) : retirer la lumière d'une fusée rend 0,09 ms, retirer son ombre 0,09 ms, ses lueurs 0,00 (`docs/iso/iso12/mesure_fusee.md`,
« D — NE PAS TOUCHER »). Ne pas rouvrir cette piste.

### 2.8 Pire cas — classement des combinaisons (ESTIMÉ sauf mention)

| Rang | Combinaison | Pourquoi | Ordre de grandeur |
|---|---|---|---|
| 1 | **2 à 4 fusées à l'écran** (pompe : 3-4 ; allumeur ; miroir) | volume de fumée = remplissage, additif ; 2D nappes + voile = 0,69 ms CPU de rendu par fusée (non établi en temps d'image) | 3,39 ms/fusée mesuré (couches) ⇒ ≈ 7-14 ms pour 2-4 si additif |
| 2 | **Terrassier** : poussière (336 px) + ses fusées | la poussière est le 2ᵉ plus gros nuage ; llvmpipe, voxels : fusée +78 ms, suie +37, poussière +29 sur ~500 | |
| 3 | Sentinelle : poudre + 72 traces (CPU tweens + 72 `Polygon2D`, 2 appels de dessin par trace en écran scindé) | seul gadget dont le coût croît avec l'activité adverse | 0,1-1 ms CPU + 72-144 appels de dessin |
| 4 | Incendiaire : braises (38 appels de dessin en écran scindé, 19 en vue unique) + 2 fusées | | |
| 5 | Spectre ×2 voiles / Fumiste ×2 suies | CPU seulement | 0,1-0,3 ms |

---

## 3. Constats

### GAD-01 — La fumée de la fusée domine le domaine, s'additionne fusée par fusée, et sa forme actuelle n'a jamais été mesurée sur le M3

**Où** : `fusee.gd:262-295` (nappes + voile), `fusee_modele.gd:108-113` (`RAYON_FUMEE 200`, `NAPPES_PAR_DEFAUT 3`, `FUMEE_GONFLE 1,25`),
`game_state.gd:5145 / 5187 / 5234` (stocks), `iso_volumes.gd:493-522, 1570-1583`, `iso_nuage_voxel.gd:648-676`.

**Constat** :
```gdscript
# fusee.gd:262-267
var nb_nappes := FuseeModele.NAPPES_PAR_DEFAUT          # 3 ; 2 en écran scindé
...
# game_state.gd:5145 / 5234
weapon_pompe.fusees = _fusees(3, 18.0)
allumeur.fusees = _fusees(2, 12.0)
```
Aucun plafond ni niveau de détail selon le nombre de fusées vivantes ou visibles. Chaque fusée = 4 sprites 2D (le voile exécute jusqu'à
3 + 16 + 2 + 6 itérations par pixel, `fumee_fusee.gdshader:67, 99, 112, 125`) rendus dans la lightmap, **plus** un nuage de cubes par vue et son
juge dans la projection iso, **plus** les poussées d'uniformes de `poser_fusee` à chaque image et chaque vue — y compris pour une fusée hors champ
(le GPU la rejette par frustum, le CPU non : `_suivre_fusee_en_voxels` n'a aucun test de visibilité).

**Coût** :
- PROUVÉ (mesure, M3, vue unique, `2f06b1b`, **couches** — avant GV1bis) : une fusée = **3,39 ms/image**, dont volume iso 2,66 ms (78 %), nappes+voile 2D
  0,69 ms de CPU de rendu (Δ d'image non établi), lumière 0,09, ombre 0,09, lueurs 0,00 ; 1 % bas hors chauffe 84,8 → 70,1 (`mesure_fusee.md`,
  ROADMAP l. 28258-28299).
- PROUVÉ (cloud, llvmpipe, écran scindé, voxels « volutes ») : surface couverte × 0,40 des couches ; temps d'image ×0,92 (fusée), ×1,0 (suie),
  ×0,96 (poussière) (`docs/iso/gadgets_volume/releves_gv1bis_cout.txt`, ROADMAP l. 31399-31429). **« Non mesuré sur le Mac »** (ROADMAP l. 2455, 31299-31302).
- ESTIMÉ : si le coût est additif, deux fusées à l'écran amènent le 1 % bas du banc vers 59 fps et trois sous 55 (extrapolation de +2,5 ms de 1 % bas
  par fusée, mesurée avec UNE fusée et des couches). Les voxels ont réduit la surface de 60 % ; ce que cela vaut au M3 est inconnu (les sommets de
  18 272 cubes, « ce que le cloud ne peut pas dire »).
- ESTIMÉ : poussées d'uniformes iso ≈ 60-100 µs par fusée et par vue et par image ; `_appliquer_age` ≈ 40-80 µs par pas.

**Proposition** (dans cet ordre) :
1. **Mesurer d'abord** : ajouter au banc un `--fusees=N` (le banc pose aujourd'hui UNE `FuseeBanc`, `tools/bench_framerate.gd:1068-1075`) et relever
   N = 1…4, voxels contre `--fumee-couches`, vue unique, M3, protocole en miroir. Sans ce chiffre, le reste est spéculatif.
2. **Sans effet visuel, CPU seul** : ne pas pousser les uniformes (`poser_fusee`, voile, nappes) d'une fusée dont le disque de fumée est hors de la
   zone caméra + marge ; les repousser à la première image où elle y rentre. Aucune incidence sur `occultation_pour` (la règle de jeu).
3. **Compromis visuel à trancher par Adrien, ne pas faire seul** : au-delà de 2 fumées à l'écran, rendre les plus anciennes à une résolution de cube
   plus grossière ou avec moins de nappes 2D. La règle de jeu (la cachette) ne change pas ; mais cela touche la lisibilité de la lumière et l'identité
   « cubes à encre ». Le déclencheur doit dépendre d'un état partagé (nombre de fusées vivantes), jamais de la caméra locale, pour que J1 et J2 voient
   la même chose.

**Gain attendu** : (1) aucun, c'est le chiffre qui décide. (2) CPU : ≈ 0,1 ms par fusée hors champ (ESTIMÉ). (3) à mesurer ; l'ordre de grandeur de la
cible est 1-2 ms par fumée dégradée (ESTIMÉ à partir des 2,66 ms de volume).

**Risque** : (2) nul. (3) lisibilité de la cachette et identité visuelle ; équité si le déclencheur est local.

**Effort** : (1) S-M (un drapeau de banc), (2) S, (3) M.

**Sévérité** : **MAJEUR** (potentiel) — seul poste du domaine capable, à lui seul, de franchir le budget de 16,7 ms ; non prouvé sous sa forme actuelle.

**Statut ROADMAP** : **CONNU-OUVERT** — mesure l. 28258-28299 ; limite « non mesuré sur le Mac » l. 2455, 31299-31302, 31445-31447 ; les économies A/B/C de
`mesure_fusee.md` visaient les couches et n'ont jamais été appliquées (« aucune appliquée ») ; α/β (lectures de texture) valent pour le chemin `--fumee-couches`
seulement.

**Comment le vérifier** : `godot --path . res://tools/bench_framerate.tscn -- --fusee --vue-unique --classe=pompe --seconds 60` avec/sans
`--fusee-sans-volume`, `--fusee-sans-fumee2d`, `--fumee-couches` ; `tools/banc_gadgets_volume.tscn -- --mode=cout` (surface, appels, primitives) ;
moniteurs `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `TIME_PROCESS` ; F3 pour le décompte de lumières.

---

### GAD-02 — Poudre de contact : un `Tween` et une courbe de Bézier évaluée en GDScript par trace, à chaque image rendue (jusqu'à 72 par nappe)

**Où** : `gadget_poudre.gd:216-245` (en particulier l. 232-240), `charte.gd:1112-1115, 1145-1152, 1195-1224`.

**Constat** :
```gdscript
# gadget_poudre.gd:232-240
var fondu := m.create_tween()
Charte.animer(fondu, m, "modulate:a", m.modulate.a, 0.0, DUREE_LUEUR, Charte.Courbe.EXTINCTION)
fondu.tween_callback(m.queue_free)
_marques = _marques.filter(func(n): return is_instance_valid(n))
# charte.gd:1149-1152
var appliquer := func(t: float) -> void:
    if is_instance_valid(objet):
        objet.set_indexed(chemin, interpoler(depart, arrivee, quelle, t))
return tween.tween_method(appliquer, 0.0, 1.0, duree)
```
`tween_method` appelle la lambda **à chaque image rendue** (Tween en `IDLE`, fps déplafonnés) ; `interpoler → courbe → _bezier_y` résout x → t par Newton
(6 passes au plus, deux appels de fonction GDScript par passe). Simulé hors Godot : 3 à 4 passes, soit ~7-9 appels de `_bezier_axe/_bezier_pente`, jamais de repli
par bissection. Une trace vit 8 s ; une nappe en pose une tous les 26 px de trajet d'un joueur (≈ 10/s à 260 px/s), plafonnée à 72.

**Coût** : PROUVÉ — un tween + ~12 appels GDScript par trace vivante et par image rendue. ESTIMÉ — 5 à 15 µs par trace et par image : traversée simple
≈ 15 traces ⇒ 0,1-0,2 ms ; combat dans la nappe ≈ 72 ⇒ 0,35-1,1 ms par image, **proportionnel aux fps** (à 240 fps, 4× plus d'évaluations par seconde de jeu).
Borne mesurée, la seule : le banc `--gadgets` (torche fantôme + poudre entretenue à 72 traces, torches ÉTEINTES) a donné 49 puis 48 images/s à deux relevés de 30 s enchaînés, « compatible avec tout écart de presque zéro à 0,85 ms » pour les DEUX gadgets
(ROADMAP l. 20338-20353) : ce qui place la poudre dans le bas de la fourchette ci-dessus, 5-10 µs par trace. S'ajoutent, côté rendu : 72 `Polygon2D` additifs = 72 appels de dessin par lightmap (144 en écran scindé), documentés par GV2 (voir GAD-07).

**Proposition** : un seul conducteur pour toutes les traces, au lieu d'un tween chacune. Les traces survivent à la nappe (enfants de l'arène) : le conducteur
vit donc dans l'arène (un nœud `TracesDePoudre` ou un accumulateur statique appelé depuis `GameState._process`), garde `t0` et `a0` par trace, lit
l'alpha dans une **table de la courbe `EXTINCTION` précalculée une fois** (≈ 128 entrées, interpolation linéaire, erreur < 1/255) et ne met à jour qu'à 30 Hz
(un fondu de 8 s). Variante minimale : `Charte.courbe_tabulee(quelle, t)` utilisable par tous les `tween_method` du jeu (50+ sites `Charte.animer`, dont
`bullet.gd` et `player.gd`) sans toucher à `Charte.courbe`, que `tools/test_charte.gd` compare à `TRANS_EXPO/EASE_OUT`.

**Gain attendu** : −0,1 à −1 ms/image selon le nombre de traces (ESTIMÉ) ; à 60 fps, −900 à −4 300 appels de lambda par seconde pour 15 à 72 traces.

**Risque** : visuel nul si la table est fine ; simulation nulle (traces locales, jamais répliquées, « une trace ne décide de rien », `gadget_poudre.gd:65-66`) ; le
rejeu lit `modulate.a` (`replay_system.gd:232`) — inchangé. Déterminisme des bancs : `bench_framerate --gadgets` entretient 72 traces et sert justement de mesure.
Attention `tools/test_rejeu.gd`, `test_classes.gd`, `test_tir_et_reserves.gd`, `test_nappes_voxel.gd` qui lisent les traces par le groupe `traces_de_poudre`.

**Effort** : S (table + conducteur) ; M si l'on généralise à `Charte`.

**Sévérité** : MINEUR (borne haute ~1 ms avec 72 traces ; typique 0,1-0,3 ms).

**Statut ROADMAP** : **NOUVEAU** pour le coût des tweens (le choix `tween_method` est expliqué l. 12257-12262 sans mention du coût à population). Les appels de dessin des traces : CONNU-OUVERT (GV2, l. 31573-31582).

**Comment le vérifier** : `bench_framerate.tscn -- --gadgets` contre le banc de base, protocole en miroir (`ROADMAP` l. 20346-20353) ; profileur de l'éditeur sur la lambda de
`Charte.animer` ; compter les tweens vivants (`get_tree().get_processed_tweens()`).

---

### GAD-03 — Voile : l'onde est recalculée et la `Line2D` re-tessellée à chaque image rendue, toute la manche, et le ruban iso est reconstruit à chaque image

**Où** : `gadget_voile.gd:147-162`, `iso_volumes.gd:1306-1339`.

**Constat** :
```gdscript
# gadget_voile.gd
func _process(delta: float) -> void:
    _temps += delta
    _secousse *= exp(-AMORTI_SECOUSSE * delta)
    _onduler()
func _onduler() -> void:
    ...
    var points := PackedVector2Array()
    points.resize(POINTS_TOILE)                     # 17
    for i in POINTS_TOILE:
        ...
        points[i] = Vector2(lerpf(-DEMI_LONGUEUR, DEMI_LONGUEUR, u), decalage(u, _temps, _secousse))
    _toile.points = points                           # → queue_redraw + re-tessellation
```
Le voile a `duree_vie = 0` (`game_state.gd:5320`) : cette boucle tourne **pendant toute la manche** (jusqu'à deux balles), sur les deux pairs, même `hide()`é par la
killcam et sur les copies de killcam (aucun `set_process(false)`, `gadget_base.gd:305-308`). Côté iso, `_suivre_toile` vide et refait un `ImmediateMesh` de 34 sommets
**à chaque image**, que la toile ait bougé ou non (`m.clear_surfaces()` puis `surface_begin … surface_end`).

**Coût** : PROUVÉ — travail à chaque image rendue, sans condition. ESTIMÉ — 40 µs de script + 10-15 µs de `Line2D` + 50 µs de ruban iso ≈ **0,05-0,15 ms par voile et par image** ;
amplitude visible : `ONDULATION 0,75 px`, `CREUX 1 px`, `SECOUSSE_MAX 0,75 px` sur une toile de 8 px (`gadget_voile.gd:54-65`), période 1,7 s.

**Proposition** : (a) n'avancer `_temps` et ne reconstruire les points qu'à 30 Hz (accumulateur), ou plus rarement (15 Hz) quand `_secousse < 0,01` ; (b) ne rien faire quand
le nœud n'est pas visible dans l'arbre (`is_visible_in_tree()` — masqué pendant la killcam) ; (c) côté iso, ne reconstruire le ruban que si l'onde a changé (compteur de version
posé par `_onduler`).

**Gain attendu** : −0,05 à −0,15 ms/image/voile à 60 fps, davantage à fps élevés (le coût suit les fps) ; ESTIMÉ.

**Risque** : aucun sur la simulation — la collision et l'occluder sont la bande droite (`gadget_voile.gd:20-29`, « personne ne compare deux écrans ») ; visuel : un pas d'onde de 33 ms
sur 0,75 px n'est pas lisible ; vérifier le contrôle de bornes de `tools/test_tir_et_reserves.gd` (somme des amplitudes ≤ `DEMI_EPAISSEUR`) — la fonction `decalage()` ne change pas.

**Effort** : S.

**Sévérité** : MINEUR.

**Statut ROADMAP** : **NOUVEAU**.

**Comment le vérifier** : poser un voile par `_do_spawn_gadget(…, "voile", …)` dans le banc (`--gadgets` n'en pose pas : torche fantôme + poudre seulement, `bench_framerate.gd:1076-1106`)
et comparer `Performance.TIME_PROCESS` avec/sans ; profileur de l'éditeur sur `GadgetVoile._process` et `IsoVolumes._suivre_toile`.

---

### GAD-04 — Suie : `_lumiere_entrante()` à chaque pas de physique, jusqu'à 28 rayons et une dizaine d'allocations, pour un nombre lissé en 0,1 s

**Où** : `gadget_volume.gd:103-114` (appel), `164-215` (fonction), `230-234` (`_points_de_lueur`).

**Constat** :
```gdscript
# gadget_volume.gd:110-111  (suie seulement : masque_le_corps())
_lueur = lerpf(_lueur, _lumiere_entrante(), 1.0 - exp(-LISSAGE_LUEUR * delta))   # LISSAGE_LUEUR = 10 /s
# 170-176, 188-206 : tableau `lampes` de tableaux, get_nodes_in_group("gadgets"), Array[RID] des corps,
# puis par lampe : _points_de_lueur() (7 Vector2, 6 rotated), 7× lumiere_recue(), et pour chaque point plus clair que k :
var q := PhysicsRayQueryParameters2D.create(origine, p, MapGeometry.WALL_LAYER)
q.exclude = corps
if espace.intersect_ray(q).is_empty(): ...
```
Lampes possibles : torche de J1, de J2, torches fantômes (≤ 2) ⇒ jusqu'à 4 lampes × 7 points ⇒ **28 rayons par pas** (si tous les points sont éclairés par le cône mais cachés derrière un mur). Un second
et un troisième parcours de groupes (`facteur_de_lampe_a`, `get_nodes_in_group("fusees")`).

**Coût** : PROUVÉ — travail à chaque pas de physique (60 Hz) tant que la suie existe (9 s par minute de recharge). ESTIMÉ — 15 µs sans lampe, 50-200 µs avec une lampe braquée dessus ; deux suies
(deux Fumistes) ⇒ ×2. Le résultat n'alimente qu'un nombre lissé (constante de temps 0,1 s) : purement visuel, aucune simulation ne le lit (`gadget_volume.gd:160-162`).

**Proposition** : échantillonner à ~20 Hz (accumulateur) et lisser entre deux échantillons ; hisser hors de la boucle ce qui est constant (les 7 décalages unitaires de `_points_de_lueur` en
`PackedVector2Array` constant, une `PhysicsRayQueryParameters2D` réutilisée, le tableau `corps`) ; sortie anticipée quand aucune lampe ne peut atteindre le disque (distance > portée de torche + rayon)
et qu'aucune fusée n'est à portée. `_lumiere_entrante()` elle-même reste telle quelle : `tools/test_tir_et_reserves.gd:1810-1853` l'appelle en direct.

Même pendant la killcam, la suie VIVANTE (masquée par `masquer_pour_rejeu`) continue d'exécuter `_lumiere_entrante` sur ses lampes vivantes : ce travail ne se voit pas (`est_masque_pour_rejeu()` existe, `gadget_base.gd:803`) — à court-circuiter en prenant garde que `_age` et le fondu continuent de courir (`game_state.gd:3917-3922` : le présent est masqué, pas figé ; `gadget_braises.gd:189-190` : « la nappe ne se fige plus chez l'hôte pendant la killcam »).

**Gain attendu** : −0,04 à −0,15 ms par pas pendant 9 s/min et par suie (ESTIMÉ).

**Risque** : latence d'allumage visuelle ≤ 50 ms de plus ; `_pouls` (flash de tir) non concerné ; aucune équité (local, cosmétique, calculé chez chaque pair depuis un état déjà répliqué).

**Effort** : S-M.

**Sévérité** : MINEUR.

**Statut ROADMAP** : **NOUVEAU** pour le coût ; l'approximation de portée de la lueur est CONNU-OUVERT (l. 30952, 31673).

**Comment le vérifier** : banc `--gadgets` étendu à `cartouche_suie` avec les torches allumées ; `Performance.TIME_PHYSICS_PROCESS` ; `tools/test_tir_et_reserves.gd`.

---

### GAD-05 — Premier nuage de cubes : la grille est construite en GDScript au moment où le premier nuage apparaît, hors du préchauffage

**Où** : `iso_nuage_voxel.gd:388-429` (`cellules`, `grille`) contre `iso_nuage_voxel.gd:306-323` (`prechauffer`), appelée par `iso_volumes.gd:1589-1628` (`_suivre_nuage_voxel`).

**Constat** :
```gdscript
static func grille(type, hauteur_px, voxel, cote) -> MultiMesh:
    var cle := "%s:%.3f:%d:%d,%d" % [type, voxel, rangs, cote.x, cote.y]
    if _grilles.has(cle): return _grilles[cle]
    var cells := cellules(rayon, rangs, voxel, cote)          # 2n × 2n × rangs itérations, Vector3 + length()
    ...
    for i in cells.size(): ... tampon[k + 11] = p.z            # 12 flottants par cube
```
`prechauffer()` charge le shader, les aplats, les reliefs et les planches réduites — son commentaire dit « pour qu'aucun ne se prépare au premier nuage » —, **mais ne construit aucune grille**. Elles se
bâtissent à la première fusée posée, à la première suie, à la première poussière, et de nouveau quand la caméra change de côté (un lacet de plus de 90°). Recompté hors Godot avec les constantes du jeu
(voxel « gros » 8,75 px, `RESSERRE 0,22`, rayons 250 / 92 / 168, hauteurs 1,0 / 0,8 / 0,4 tuile) : la fusée = **14 400 itérations de `cellules` pour 9 136 cubes par vue** (les « 18 272 » de la ROADMAP l. 31280 sont les deux
vues de l'écran scindé), la suie 1 728 itérations / 1 124 cubes, la poussière 3 528 / 2 176.

**Coût** : PROUVÉ — travail synchrone en GDScript sur le fil principal, la première fois, à l'image où la fusée s'allume (`_suivre_fusee_en_voxels` est appelé dès que `alpha_fumee > 0`). ESTIMÉ — 14 400 itérations de `cellules`
(un `Vector3`, un `Vector2.length()`, un `append`) + 9 136 de remplissage de tampon (6 écritures), soit **de l'ordre de 5 à 15 ms** pour la fusée (1 à 3 ms pour la suie et la poussière), doublé en écran scindé si les deux
caméras regardent de côtés différents (J1 à 45°, J2 à 225°) ; un seul hoquet par processus et par (type, côté).

**Proposition** : construire dans `prechauffer()` (déjà appelé à la naissance de la présentation iso, 0,2-0,4 s) les grilles des trois types pour le(s) côté(s) de caméra connu(s) de la vue (1 en vue unique, 2 en écran
scindé), ou étaler la construction sur quelques images au chargement ; ne garder la construction paresseuse que pour un changement de côté.

**Gain attendu** : supprime un hoquet unique de ~5-15 ms (jusqu'à ~30 en écran scindé) au premier allumage de fusée (ESTIMÉ, non mesuré).

**Risque** : aucun visuel ; ajoute ~10-20 ms au préchauffage hors match ; mémoire : 9 136 × 48 o ≈ 0,44 Mo par grille de fusée.

**Effort** : S.

**Sévérité** : MINEUR (hoquet unique, mais à un moment décisif : l'allumage).

**Statut ROADMAP** : **NOUVEAU** pour les grilles. La compilation GL du shader 3D au premier nuage est **CONNU-OUVERT** (l. 31300-31302 ; `iso_nuage_voxel.gd:300-304`).

**Comment le vérifier** : `Time.get_ticks_usec()` autour de `IsoNuageVoxel.grille` (la ligne « [fumée voxel] préchauffé en N ms » existe déjà) ; `bench_framerate … --seuil-lent 18` (le banc imprime les images lentes) en
ne chauffant pas la fusée avant le relevé.

---

### GAD-06 — Chauffe incomplète : seul le shader du voile est dessiné d'avance ; `nappe_fusee`, les matériaux canvas, le corps de la fusée et les sprites de gadget se chargent au premier usage

**Où** : `fusee.gd:343-358` (`prechauffer`), `fusee.gd:20, 265-281` (`NAPPE_SHADER`), `gadget_base.gd:719-738` (`materiau_incandescent`, `materiau_peint_lumineux`), `gadget_poudre.gd:204-213`.

**Constat** :
```gdscript
# fusee.gd:343-358 — ne dessine que VOILE_SHADER
mat.shader = VOILE_SHADER
mat.set_shader_parameter("alpha_globale", 0.0)
chauffe.material = mat
```
Les trois nappes (`NAPPE_SHADER`, `fwidth`) sont montées à `alpha 0` et ne s'affichent qu'au premier pas après l'atterrissage (`alpha_fumee_a(age > 0)`). Côté ressources : le corps de la fusée (`fusee_corps.png`, 1456×720 importé sans perte)
n'est chargé qu'au premier lancer (`fusee.gd:250-254`, `ResourceLoader.exists` puis `load`), et chaque sprite de gadget à sa première pose (`gadget_base.gd:424-429`) — alors que `prechauffer()` charge déjà les trois volutes. Les matériaux partagés
`CanvasItemMaterial` (additif non éclairé pour les traces de poudre ; mélange non éclairé pour la nappe de braises, la lentille, la suie, le repère) naissent à leur première utilisation. Le dépôt sait
que « un `preload` charge le shader, mais le programme GL se compile au premier DESSIN — seule `Fusee.prechauffer()` dessine d'avance » (ROADMAP l. 22509-22513).

**Coût** : PROUVÉ — aucun dessin d'avance de ces shaders/variantes, aucun chargement d'avance du corps ni des sprites. ESTIMÉ — une compilation de programme GL canvas est un hoquet de quelques ms à quelques dizaines de ms selon le pilote (Apple : inconnu, aucune
mesure faite) ; jusqu'à trois occurrences par processus (nappe de fusée, additif, mélange non éclairé), chacune au premier atterrissage / première trace / première nappe posée. Le décodage du corps de la fusée (~1 Mpx) : de l'ordre de 5 à 15 ms au premier lancer ;
la compilation du script d'un gadget : de l'ordre de 1 à 3 ms à sa première pose (ESTIMÉ, non mesuré).

**Proposition** : étendre `prechauffer()` avec un sprite hors champ par variante (même patron que le voile) : un sprite sous `NAPPE_SHADER`, un sous `materiau_incandescent()`, un sous `materiau_peint_lumineux()` ; y ajouter le `load()` de `fusee_corps.png` et
des dix sprites de gadget (de 0,5 Ko à 215 Ko : `gadget_poussiere.png` est le plus gros), et, si l'on veut aussi le script de chaque gadget, un `preload` dans `IMPLEMENTATIONS` à la place des chemins en chaîne (`game_state.gd:5319-5349`, `load` à la pose, l. 3796).
Vérifier d'abord au banc qu'ils produisent des hoquets groupés au début (c'est la méthode écrite en l. 22512-22513).

**Gain attendu** : supprime ≤ 3 hoquets uniques (ESTIMÉ, non mesuré).

**Risque** : nul ; un quad hors champ ou à alpha 0 pourrait ne pas être dessiné — le patron actuel (alpha 0 posé dans l'uniforme, pas sur le sprite) est à reprendre tel quel.

**Effort** : S.

**Sévérité** : MINEUR.

**Statut ROADMAP** : **CONNU-OUVERT** (l. 22509-22513 ; point 5 de PE3, l. 22431-22433 : « vérifier qu'aucun shader ne compile encore au premier usage en match »).

**Comment le vérifier** : `banc_pics` / `bench_framerate --seuil-lent 18` sur le Mac, sans chauffe ; PE3.2 (« des pics groupés au début sont une compilation, des pics étalés non »).

---

### GAD-07 — Nappes au sol (braises, poudre) : le chemin par défaut coûte beaucoup d'appels de dessin ; l'alternative chiffrée existe, éteinte, en attente de Q79/Q80

**Où** : `iso_volumes.gd:459-491, 604-624` (chemin par défaut), `iso_volumes.gd:1380-1414, 1422-1436, 1457-1554` (GV2, `nappes_voxel := false`, l. 184), `docs/iso/gadgets_volume/releves_gv2_cout.txt`.

**Constat** : par défaut, la nappe de braises = 2 couches + **16 lueurs** (`MeshInstance3D` + `ShaderMaterial` chacune) + un juge, par vue ; `_suivre_braises` instancie un `RandomNumberGenerator` neuf **à chaque image** pour retrouver
les mêmes 16 points (même graine : la position de la nappe) :
```gdscript
var rng := RandomNumberGenerator.new()
rng.seed = hash(Vector2i(g.global_position.round()))
for i in POINTS_BRAISES: ... _poser_halo(e, i, …)       # 3 set_shader_parameter chacun
```
La poudre : une trace = deux appels de dessin en écran scindé (un par lightmap). Relevés GV2 (écran scindé, 2 vues) : **braises +38 appels** (195 contre 157), « tas » **+4**, « braises » +8 ; poudre +6 appels
plus **24 pour douze traces** que l'essai « tas » retire (les traces deviennent un `MultiMesh` de grains).

**Coût** : PROUVÉ — appels de dessin (cloud, indépendants du pilote) ; temps d'image sous llvmpipe non discriminant (±12 ms). ESTIMÉ — CPU ≈ 0,1 ms/image pour les 16 lueurs (RNG + 48 poussées d'uniformes).

**Proposition** : (a) **sans toucher à l'image** : calculer une fois les 16 points (`braises_de(g)` existe déjà, l. 1422-1436) et ne recalculer par image que le scintillement ; (b) obtenir d'Adrien la réponse à Q79/Q80
(les nappes en voxels « tas » par défaut) : −34 appels pour les braises, −18 pour la poudre avec douze traces, au prix de +18 700 / +22 900 primitives (à mesurer sur Apple).

**Gain attendu** : (a) ≈ 0,05 ms/image (ESTIMÉ) ; (b) selon le pilote, à mesurer.

**Risque** : (a) nul ; (b) rendu des braises « plus vives » (Q80), poudre +4 % de clarté sous la lampe (l. 31595).

**Effort** : (a) S ; (b) déjà écrit, décision seulement.

**Sévérité** : MINEUR.

**Statut ROADMAP** : **CONNU-OUVERT** (l. 31573-31582 coûts ; l. 31603, 31641-31653 Q79/Q80).

**Comment le vérifier** : `tools/banc_gadgets_volume.tscn -- --mode=cout_nappes` ; appels de dessin via `Performance`.

---

### GAD-08 — (hors de mes fichiers) HUD des réserves : thème et styles ré-appliqués à chaque image pour quatre cartouches

**Où** : `ui.gd:3128-3300` (`_maj_reserves`, appelée par `update_hud`, `ui.gd:8803, 8846`, elle-même appelée à chaque `GameState._process`, `game_state.gd:2341-2345`), `ui.gd:3359-3366, 3438-3450, 3453-3520`.

**Constat** : l'habillage par défaut est « voxel » (`charte.gd:475-487`). À chaque image et pour chaque joueur, `_maj_reserves` écrit sans condition de changement : `lbl_f.add_theme_color_override` (l. 3168), `lbl_g.add_theme_color_override` (l. 3246),
`_set_flare_style` et `_set_gadget_style` → `_habiller_la_reserve` (l. 3438-3450) qui réécrit `panel.add_theme_stylebox_override("panel", …)` et `label.add_theme_color_override("font_color", …)` — soit **6 overrides par joueur, 12 par image**,
plus `gs.gadget_disponible` et `gs.gadget_basculable_de` (parcours du groupe `gadgets`, `has_method`). Les `StyleBox` du chemin voxel sont en cache (`_plaques_de_cartouche`, `ui.gd:3359-3366`) : c'est la ressource qui est ré-attachée, pas recréée.
Le chemin non défaut (`--charte=pate`) est pire : un `StyleBoxFlat` neuf par appel (`ui.gd:3459, 3497`) et deux `find_child(…, true, false)` récursifs par image (`ui.gd:3518, 3521`).

**Coût** : PROUVÉ — travail sans condition de changement. ESTIMÉ — à notre connaissance du moteur, `add_theme_*_override` ne compare pas à la valeur déjà posée et notifie `NOTIFICATION_THEME_CHANGED` (re-calcul du cache de thème, `update_minimum_size`, re-dessin ;
pour un `Label`, texte invalidé) : 0,05-0,2 ms/image pour les douze appels. **Non vérifié dans les sources du moteur ni mesuré** — c'est le point à confirmer en premier.

**Proposition** : à confier à l'agent HUD : n'écrire un override que si l'état (actif / teinte / texte) a changé (un `_dernier_etat` par cartouche, ou comparer à `get_theme_color` / `get_theme_stylebox`) ; remplacer `gadget_basculable_de` par une référence tenue par `GameState`.

**Gain attendu** : ≈ 0,05-0,2 ms/image (ESTIMÉ). **Risque** : nul si l'état est bien comparé (les tests `test_habillage` lisent ces styles). **Effort** : S. **Sévérité** : MINEUR. **Statut ROADMAP** : NOUVEAU.

**Comment le vérifier** : profileur de l'éditeur sur `UI._maj_reserves` ; compteur de `NOTIFICATION_THEME_CHANGED` sur un panneau.

---

### GAD-09 — Micro-coûts de parcours de groupes, d'enfants et d'uniformes sans court-circuit (regroupés)

Tous **ANECDOTIQUES** pris un par un (≈ 5-50 µs/image) ; regroupés parce qu'ils partagent la même correction : savoir en O(1) qu'il n'y a rien à faire.

| Site | Constat | Proposition |
|---|---|---|
| `fusee.gd:777-791` | `_maj_sillage_et_masses` pousse `nb_masses`, `masses`, `masse_rayon_uv` **à chaque pas** et réalloue un `PackedVector2Array`, alors que personne n'est dans la fumée dans le cas courant ; `filtrer_sillage` (l. 760) et `_maj_tunnels` (l. 800) allouent un `Array` neuf par pas. Le code sait déjà faire (`_trous_pousses`, `_tunnels_pousses`). | mémoriser les dernières valeurs poussées, comme pour les trous |
| `game_state.gd:4093-4105` | `_maj_extinction_fusees` : 2× `bullet_container.get_children()` à chaque image, balles comprises | parcourir le groupe `fusees` (0 à 8 nœuds) |
| `bullet.gd:347, 535-539` | `_maj_tunnel` → `_fumee_sous` → `get_nodes_in_group("fusees")` **par balle et par pas** | court-circuit `get_node_count_in_group("fusees") == 0` |
| `player.gd:1319` / `gadget_base.gd:625-636` | `effacements_a` : 2 `get_nodes_in_group` par joueur et par image (et par pas pour le leurre) | court-circuit si les deux groupes sont vides |
| `gadget_gresillement.gd:114-144` | `niveau_noir(_temps_actif)` recalculé à chaque appel de `facteur_de_lampe` (≥ 6 appels/image : 4 en éblouissement hôte + 2 par pas), alors qu'il ne dépend que de `_temps_actif`, qui ne change que dans `_physics_process` | mémoriser le niveau dans `_physics_process` ; résultat identique au bit |
| `game_state.gd:2679-2684, 2790` | `facteur_de_lampe_a` et le parcours du groupe de `_ligne_de_vue_depuis` refaits par paire source×cible | calculer une fois par source / une fois par image |
| `gadget_torche_fantome.gd:233-249` | `angle_relatif` rescanne `_plan` depuis 0 à chaque pas (≤ ~25 entrées) ; la lumière reste `enabled` à énergie 0 sous grésillement/suie (`gadget_torche_fantome.gd:193`) alors que la règle du dépôt dit « énergie zéro n'est pas éteinte » (ROADMAP l. 5332-5372) | curseur d'index monotone ; `enabled = energie > 0.005` comme la fusée (`fusee.gd:665`) |
| `game_state.gd:3763-3777` | `_maj_reserves_gadgets` : `gadget_basculable_de(pid)` ×2 par image | référence au gadget basculable tenue à la pose |
| `flare_profile.gd:66-71` / `game_state.gd:3150-3154` | `avancer()` alloue `[stock, 0.0]` à chaque image et par joueur quand la réserve est pleine (le cas courant), pour que l'appelant ne lise rien | tester `stock >= plafond_effectif()` avant l'appel |

**Gain attendu** : cumulé 0,02-0,1 ms/image (ESTIMÉ). **Risque** : nul (aucune de ces corrections ne change un résultat). **Effort** : S chacune. **Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : NOUVEAU
(sauf l'énergie zéro : DÉJÀ-TRANCHÉ pour les particules, l. 5372, non appliqué ici).

**Comment le vérifier** : profileur de l'éditeur ; `tools/test_tir_et_reserves.gd`, `test_classes.gd`, `test_rejeu.gd` couvrent les comportements.

---

### GAD-10 — (hors de mes fichiers) L'archive de match écrit tout l'historique en synchrone à l'instant du dernier tir ; le bloc de télémétrie des gadgets y pèse

**Où** : `game_state.gd:4426-4460` (`_do_end_round` → `_archive_match_result`), `game_state.gd:4733-4771`, `match_record.gd:93, 247-285`, `telemetrie_gadgets.gd:246-255`.

**Constat** : `append_to_history` relit tout le fichier (`FileAccess` + `JSON.parse_string`), ajoute, plafonne à `HISTORY_MAX = 200`, `JSON.stringify(history, "\t")`, écrit un `.tmp` et renomme — sur le fil principal, **dans la frame
du dernier tir** (avant la killcam). Le bloc `gadgets` ajoute ~2 × 13 clés par match (`COMPTEURS`+`CUMULS`, `version`, `fenetre_s`, `joueur_local`).

**Coût** : PROUVÉ — E/S synchrone une fois par match, au moment décisif. ESTIMÉ — 200 enregistrements indentés à la tabulation ≈ 0,3-0,6 Mo relus, parsés, ré-encodés et réécrits : quelques ms à une vingtaine de ms ; le bloc gadgets
y contribue pour ≈ 0,7 Ko indentés par match (≈ 40 % d'un enregistrement ? non vérifié). La télémétrie elle-même (compteurs) ne coûte rien.

**Proposition** : à confier à l'agent persistance/menus — différer l'écriture à la sortie de la killcam ou de l'écran de fin (la donnée est dans `dernier_enregistrement`), ou écrire en `append` ligne à ligne plutôt que réécrire l'historique.

**Gain attendu** : retire une E/S de quelques ms de la frame du tir fatal. **Risque** : perte du dernier match si le processus meurt entre le tir et l'écriture (la ROADMAP exige une écriture atomique, `match_record.gd:253-256`). **Effort** : S-M. **Sévérité** : ANECDOTIQUE
pour ce domaine. **Statut ROADMAP** : NOUVEAU.

**Comment le vérifier** : horodatage autour de `_archive_match_result` avec un historique plein.

---

### GAD-11 — Assets de la fusée importés sans perte et sans mipmaps : ≈ 41 Mo de VRAM, dont un corps de 1456×720 pour un sprite de 30 px

**Où** : `assets/sprites/fusee_corps.png` (1456×720), `fusee_volute.png` (1024²), `fusee_volute_2.png` et `_3.png` (2048²) — `compress/mode=0`, `mipmaps/generate=false` (leurs `.import`) ; `fusee.gd:51, 250-259` (`EMPREINTE_CORPS := 30.0`).

**Constat** : RGBA8 non compressé : 4,2 + 4,2 + 16,8 + 16,8 ≈ 42 Mo de VRAM pour les quatre planches de la fusée, sans mipmaps (le corps est minifié ×48, les volutes ×3-4). Le chargement des deux planches de 2048² (PNG de 3 Mo) est une
décompression CPU unique (au `rebuild_arena`, hors décisif). Le code garantit déjà « l'empreinte commande, jamais le fichier » (`fusee.gd:40-50`).

**Coût** : PROUVÉ — tailles et réglages d'import. ESTIMÉ — décompression 100-200 ms à la première arène, ~41 Mo résidents.

**Proposition** : réduire `fusee_corps.png` à 256-512 px de large et les volutes à 1024² (ou activer la compression VRAM + mipmaps) ; les planches sont des œuvres d'Adrien (filière Gemini) : **décision d'art**, pas de code. Aucune ligne de code à changer.

**Gain attendu** : −25 à −35 Mo de VRAM ; chargement −100 ms (ESTIMÉ). **Risque** : netteté à fort zoom (vérifier à la planche). **Effort** : S. **Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : **CONNU-OUVERT** (PE3 point 3, l. 22424-22427 :
« une décision d'import, pas une retouche par fichier » ; PE3.3 attend le relevé VRAM).

**Comment le vérifier** : champs `vram_mo` / `textures_mo` du diagnostic F6 (PE3.3).

---

### GAD-12 — Capteurs de lumière des objets posés : un `SubViewport` 256² par vue, rendu à chaque image même hors champ

**Où** : `miroirs_iso.gd:201-254` (création, l. 241-246) et `264-290` (`_poser`), `capteur_corps.gd:80-123` (l. 88-91), `voxel_catalogue_objets.gd:76-116` (les slugs miroités) ; le garde qui existe déjà pour les figurants : `presentation_3d.gd:161, 1198-1199`.

**Constat** :
```gdscript
# capteur_corps.gd:88-91
c.size = Vector2i(TAILLE, TAILLE)                       # 256
c.canvas_cull_mask = couche
c.render_target_update_mode = SubViewport.UPDATE_ALWAYS
# miroirs_iso.gd:241-246 — pour chaque vue `id` de chaque objet miroité
var c := CapteurCorps.creer(id, 0, main.vp1.world_2d, couche_objets(id), masque, noeud if slug == "leurre" else null)
# presentation_3d.gd:1198-1199 — le garde de distance des PNJ de l'aventure (jamais posé sur les objets)
capteur.render_target_update_mode = SubViewport.UPDATE_ALWAYS if proche else SubViewport.UPDATE_DISABLED
```
`MiroirsIso.suivre` crée un voxel + ses capteurs pour la mine, l'ombre habitée, la torche fantôme, le voile (piquets), le grésillement, le leurre et toute fusée posée ; `_poser` ne fait que `suivre(pos, noeud.is_visible_in_tree())`, c'est-à-dire cacher le
disque : la sous-vue, elle, continue de rendre. Mine, ombre et grésillement durent la manche entière. Le rassemblement des lumières d'une sous-vue **ne teste pas le masque de cull** (« 80 dessins d'ombre par image, dont 64 pour rien », `mesure_fusee.md`) : à notre connaissance du moteur, chaque capteur paie donc une passe d'ombre par lumière dont
le rectangle croise sa zone de 128 px, qu'elle éclaire son disque ou non (ESTIMÉ, non vérifié dans les sources du moteur).

**Coût** : PROUVÉ — (gadgets miroités debout + fusées posées) × vues sous-vues actives en permanence : jusqu'à (2 + F) en vue unique, le double en écran scindé. MESURÉ pour UNE fusée, vue unique, M3 : le résidu non expliqué par les six drapeaux est
0,15 ms et contient son capteur et son voxel (`mesure_fusee.md` : 3,25 expliqués sur 3,39) ; le gâchis des halos privés vaut ~0,14 ms (l. 28301-28308). ESTIMÉ : 0,05-0,15 ms par objet et par vue ⇒ 0,3-0,9 ms avec 2 gadgets + 4 fusées.
Aucun relevé n'isole les capteurs d'objets.

Second point, de même origine : la création. Chaque pose de gadget miroité, chaque atterrissage de fusée et chaque copie de killcam (les fusées sont recréées, `game_state.gd:3878-3898`) construisent leurs sous-vues **dans l'image même** : `SubViewport`
256² (cible de rendu), `Camera2D`, `Polygon2D` à 32 sommets, `ShaderMaterial`, `add_child`, et `EtoileDeCorps.rapprocher_tout` à l'entrée dans l'arbre (`capteur_corps.gd:126-129`). ESTIMÉ 0,3-1 ms par capteur (non mesuré), donc quelques ms au début d'une killcam
qui rejoue plusieurs objets. Un petit pool de capteurs (8) réutilisés évite création et libération.

**Proposition** : reprendre le garde des figurants : `UPDATE_DISABLED` quand l'objet est à plus de `PORTEE_CAPTEUR_FIGURANT_PX` (1 300 px) du joueur regardé, ou quand son nœud n'est pas visible dans l'arbre (gadget masqué par la killcam), `UPDATE_ALWAYS` sinon. Un objet hors cadre n'est pas dessiné par la 3D :
sa texture n'est pas lue. Au retour dans le cadre, le capteur se réarme avant que l'objet n'entre à l'écran (1 300 px ≈ 1,5 écran en vue unique).

**Gain attendu** : le coût de chaque capteur d'objet hors champ, soit ~0,05-0,15 ms par objet et par vue (ESTIMÉ) — les mines, ombres et grésillements posés ailleurs sur la carte, les fusées hors cadre ; en écran scindé, jusqu'à une sous-vue sur deux.

**Risque** : noir absolu et équité — un capteur arrêté garde sa dernière valeur ; il faut le réarmer assez tôt pour qu'aucun objet n'entre à l'écran avec une lumière périmée (le garde de 1 300 px est celui que la ROADMAP a déjà posé pour les corps, l. 32771, 33729).
Les gardes `tools/test_iso_gadgets.gd`, `test_iso_vues.gd` et `banc_iso.gd --canaux` tiennent l'équité des capteurs.

**Effort** : S-M.

**Sévérité** : MINEUR.

**Statut ROADMAP** : **NOUVEAU** pour les objets posés (le garde de distance n'existe que pour les figurants : `presentation_3d.gd:1198`, ROADMAP l. 32771).

**Comment le vérifier** : `bench_framerate.tscn -- --iso --vue-unique --gadgets` avec 6 objets posés hors cadre (la variante `--gadgets` n'en pose que deux) ; compter les `SubViewport` en `UPDATE_ALWAYS` (`get_tree().get_nodes_in_group("capteurs_de_corps")` filtré) ; appels de dessin via `Performance`.

---

## 4. Ce qui est déjà bien fait (à ne pas casser)

1. **Zéro trafic continu pour les gadgets** : nœuds non répliqués, sept RPC événementiels reliables, états dérivés de (graine, âge) — l'onde du grésillement (`_hasard`, entier explicite, pas `hash()`) et le plan de gestes de la torche fantôme
   sont des fonctions pures identiques chez les deux pairs.
2. **Brûlure par tics de 4 PV indépendants de la cadence** (`gadget_braises.gd:148-179`, accumulateur + `while`) : 8 RPC/s au pire sous deux nappes, contre ~1 000 d'appels à 480 fps avant l'étape 28 A1.
3. **Bornes partout** : un gadget debout par joueur, 72 traces, fusées de 20 s, purge de `bullet_container` à chaque manche, copies de killcam purgées par la seule porte `_abort_killcam`, tout nœud dynamique nommé explicitement (`GadgetJ%d_%d`, `FuseeJ%d_%d`).
4. **Préchauffage là où il compte déjà** : volutes + shader du voile au `rebuild_arena`, shader/aplats/reliefs/planches du nuage au lancement de la présentation iso, étoile d'ombre du leurre déjà dans le cache `Charte._ombres` (remplie à l'équipement du joueur), cookie de torche en `Image` mise en cache (`weapon_data.gd:288-299`).
5. **Écritures conditionnelles** : `_couper_l_ombre` n'écrit que sur changement (`player.gd:1157-1163`), `_poser_empreinte` aussi (`fusee.gd:866-872`), `_trous_pousses` / `_tunnels_pousses` évitent les poussées de shader inutiles, la lumière de la fusée passe `enabled = false` à énergie nulle (`fusee.gd:665`).
6. **Matériaux partagés** (`GadgetBase.materiau_incandescent/peint_lumineux`, `mat_nappe` commun aux trois nappes) et ombres **dures** (`SHADOW_FILTER_NONE`) sur toutes les lumières du domaine.
7. **Pistes déjà fermées par la mesure** : la lumière 2D de la fusée (0,09 ms), son ombre (0,09), ses lueurs (0,00) — « NE PAS TOUCHER » (`mesure_fusee.md`) ; les halos privés (~0,14 ms) ; le 1 % bas mesuré hors chauffe.
8. **Killcam sobre** : gadgets du présent masqués plutôt que libérés, copies sans physique (`set_physics_process(false)`), enregistrement des traces par un seul `resize` (`replay_system.gd:221-241`), jamais de rejeu des lumières vivantes.

---

## 5. Questions ouvertes (mesure ou Adrien)

1. **Mesure M3 de la fumée de fusée en voxels** (défaut depuis la 0.8.1) contre `--fumee-couches`, pour N = 1 à 4 fusées à l'écran, vue unique, protocole en miroir, fenêtre au premier plan (GAD-01). C'est la question qui pèse le plus.
2. **Coût CPU par image de chaque gadget** : le banc `--gadgets` ne pose que la torche fantôme et la poudre à 72 traces (`bench_framerate.gd:1076-1106`) ; voile, suie, braises, leurre et mine allumée n'ont aucun relevé. L'ordre de grandeur de ce rapport (≤ 1 ms au pire) est ESTIMÉ.
3. **Hoquets de premier usage** sur le Mac (`banc_pics` / `--seuil-lent 18`, sans chauffe) : grilles de cubes (GAD-05), `nappe_fusee` et matériaux canvas (GAD-06), shader 3D de nuage, `load()` du script et des sprites de chaque gadget à sa première pose, `fusee_corps.png`, relecture GPU du cookie (`image_torche`).
4. **Un plafond ou un niveau de détail de fumée** quand ≥ 3 fusées sont vivantes (GAD-01 option 3) : décision d'Adrien — elle touche la lisibilité de la lumière et l'identité visuelle, pas la règle de jeu.
5. **Q79 / Q80** (nappes de braises et de poudre en cubes par défaut) : ce sont aussi des décisions de coût (GAD-07).
6. **Décimer à 30 Hz** l'onde du voile et le fondu des traces : visuellement équivalent selon la lecture du code, à confirmer sur planche.
7. **Salon d'attente / bac à sable libre** : réserve de fusées jamais décomptée, jusqu'à ~33 fusées vivantes ; sans enjeu compétitif, mais un joueur qui s'y entraîne et en lance dix mesure une cadence qui n'existe pas en match.
8. **Capteurs d'objets (GAD-12)** : aucun relevé n'isole leur coût ; seul le résidu de 0,15 ms de la fusée le borne. Le garde de 1 300 px des figurants est-il la bonne portée pour les objets, et le noir absolu tolère-t-il une sous-vue arrêtée ?
9. **PNJ de l'aventure** : chaque PNJ a sa réserve et son gadget (`inscrire_un_pnj`) ; le pire cas du mode aventure (nombre de PNJ Terrassiers par salle) n'a pas été examiné.

---

## 6. Renvois aux autres domaines (rien d'écrit ici n'est à leur place)

- **Projection iso** (`iso_volumes.gd`, `iso_nuage_voxel.gd`, `miroirs_iso.gd`, `capteur_corps.gd`) : duck-typing sur tous les enfants de `bullet_container` à chaque image (`iso_volumes.gd:418-424`, `miroirs_iso.gd:151-165`), `_suivre_toile` (ruban), `_suivre_braises` (RNG), `poser_fusee` (~30 `set_shader_parameter` par vue et par image), capteurs d'objets (GAD-12), grilles de cubes (GAD-05).
- **Rejeu** (`replay_system.gd:196-241`) : parcours de tous les enfants de `bullet_container` à 60 Hz, `has_method` puis `is_in_group` sur chacun.
- **Éblouissement** (`game_state.gd:2360-2818`) : `Dictionary` par source à chaque image ; `WeaponData.image_torche()` (relecture GPU 1024² + cache) jamais préchauffée.
- **Balles** (`bullet.gd:347, 535-539`) : groupe `fusees` par balle et par pas.
- **HUD** (`ui.gd:3128-3300`) : GAD-08.
- **Persistance** (`match_record.gd`) : GAD-10.
