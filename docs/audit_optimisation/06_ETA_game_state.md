# ETA — Orchestration du match : `game_state.gd`, killcam, relevés

Audit d'optimisation en **lecture seule**, commit `52a29c1` (0.8.3 + SOLO S12). Godot n'a pas été lancé : **aucun chiffre de coût n'est mesuré**.
Chaque coût est marqué **PROUVÉ** (le code le fait, sans ambiguïté), **ESTIMÉ** (ordre de grandeur tiré du code et du comportement connu du moteur) ou **NON MESURÉ**, et chaque constat dit comment le mesurer.

Lus en entier : `game_state.gd` (6 552 l.), `prediction_tir.gd`, `releve_balistique.gd`, `killcam_cadrage.gd`, `estampe_de_kill.gd`, `main.tscn`.
Lus pour suivre les appels (hors périmètre, cités quand ils portent un constat) : `replay_system.gd`, `match_record.gd`, `conditions_de_match.gd`, `ranked_identity.gd` (report_match), `bullet.gd`, `bullet_casing.gd`, `blood_stain.gd`/`wall_impact.gd` (plafonds), `particle_pool.gd`, `candela_tileset.gd`, `map_geometry.gd`, `map_data.gd`, `mur_led.gd`, `mur_encre.gd`, `arena_decor.gd`, `murs_bas_rendu.gd`, `brouillage_vue.gd`, `weapon_data.gd`, `vision.gd`, `eblouissement.gd`, `kill_shockwave.gd`, `affiche_de_fin.gd`, `ui.gd` (`update_hud` et ses sous-fonctions), `killcam_overlay.gdshader`, `death_flash.gdshader`.
ROADMAP interrogée : « Famille 4.1 » (l. 2640 : c'est le chantier *reconnexion*, sans rapport avec la cadence), « D'où viennent les millisecondes du duel » (l. 34076), « Pièges connus » (grep game_state / killcam / hoquet / rebuild_arena), et les passages sur le premier rejeu (l. 20390, 21416) et les compilations au premier allumage (l. 27615-27622).

---

## 0. À retenir

1. **`GameState` n'a ni `_physics_process` ni `_input`** : tout son travail récurrent est dans `_process` (`game_state.gd:2081-2345`), à la cadence du rendu (fps déplafonnés). Hors HUD, je l'estime à **40-90 µs par image** en duel (hôte, deux torches allumées, sans gadget), soit < 1 % d'une image à 100 i/s — **sous le plancher de bruit des relevés (~0,25 ms de médiane, ROADMAP l. 34151)**. Aucune micro-optimisation de ce fichier ne se verrait au banc de cadence.
2. **Le seul poste par image qui puisse peser est le HUD**, que `_process` appelle sans condition (`ui.update_hud`, `game_state.gd:2342-2345`) et qui repose ≥ 16 overrides de thème par image (ETA-03, hors périmètre mais appelé d'ici).
3. **Les vrais risques sont des hoquets aux moments décisifs**, et le banc les exclut par construction (échauffement de 12 s, relevé de manche arrêté à la mort : ROADMAP l. 27710-27714, `conditions_de_match.gd:31-34`). Deux candidats MAJEURS : l'**archivage de fin de match fait sur l'image du kill** (ETA-01) et les **coûts à froid du premier kill / premier rejeu** (ETA-02, « n'est pas tranché », l. 21416).
4. **Le départ de manche refait et re-cuit toute l'arène à chaque manche** (ETA-04), sans cache par carte, dont une **relecture GPU du décor** (`get_image()`) en carré de la taille de la carte (de 5,7 Mo à 83 Mo). Masqué par le décompte de 3 s, mais jamais mesuré.
5. **Rien ne grandit sans borne** (§ 1.6) : traces 120/120/90, historique de compensation 0,4 s, rejeu 450 instantanés, journal 200 entrées, tampons de killcam purgés par `_abort_killcam`.
6. **Tous les RPC de `game_state.gd` sont événementiels et fiables** ; le seul périodique est `rpc_sync_time` (5 s). Le plus coûteux à la réception est `rpc_start_round` côté client (ETA-04).

---

## 1. Carte des chemins chauds

### 1.1 Par image rendue — `GameState._process` (`game_state.gd:2081-2345`)

Quantités de référence : duel, hôte ou local, deux torches allumées, aucun gadget ni fusée, une seule vue affichée. Les « µs » sont **ESTIMÉS**.

| # | Bloc | Où | Quand | Allocations / requêtes | Coût | Piste |
|---|---|---|---|---|---|---|
| 1 | `_conditions.echantillonner` | 2083 ; `conditions_de_match.gd:86-98` | chaque image, manche en cours | 0 allocation (`append` amorti sur 2 `PackedFloat32Array`) | < 1 µs | — |
| 2 | `signaler_arene` | 2086-2089 | chaque image | une comparaison ; `_apply_video` seulement au changement | ~0 | — |
| 3 | `_record_position_history` | 2091-2092 ; 4266-4274 | **hôte seul, chaque image rendue, lobby compris** | 1 Dictionary de 5 clés + `remove_at(0)` | ~2 µs | ETA-09 |
| 4 | `_maj_brouillage` | 2094 ; 5856-5884 ; `brouillage_vue.gd:189-282` | chaque image (1 vue en vue unique, 2 en écran scindé) | 2 Dictionary (`Brouillage.flou`/`halo`), 3-4 `get()` dynamiques, 0-2 `projecteur.call` **avant** de savoir si l'éblouissement est nul | 5-10 µs par vue | ETA-10 |
| 5 | `_maj_adversaire_mobile` | 2095 ; 1123-1136 | chaque image | garde | ~0 | — |
| 6 | bloc manche : décompte, chrono, `rpc_sync_time` /5 s, `_update_music_intensity` | 2097-2165 ; 2899-2907 | manche active | `set_music_intensity` sort tôt (`audio_manager.gd:2208`) | ~1 µs | — |
| 7 | `_suivre_du_regard` | 2179-2180 ; 445-460 ; 473-475 | chaque image hors killcam, **2 caméras dont celle de la vue non rendue** | 0 allocation ; écrit `ignore_rotation` ET `rotation` des deux `Camera2D` à chaque image | 6-12 µs | ETA-10 |
| 8 | `_maj_extinction_fusees` | 2189-2190 ; 4088-4126 | manche ou bac à sable, hôte/local | 2 × `bullet_container.get_children()` (copie de tableau) + `is Fusee` par enfant | 3-6 µs | ETA-10 |
| 9 | **`_maj_eblouissement`** | 2197 ; 2360-2406, 2442-2539, 2551-2830 | hôte/local, chaque image, **même hors manche** (seul le client sort : 2361) | ~35-45 petites allocations (2 Array de joueurs, 2 Dictionary `gagnante`/`plafond`, 1 Dictionary de 5 clés par torche, tableaux de groupe), 6 parcours de groupe (2 + 4 de `facteur_de_lampe_a`), **0-2 rayons** (seulement si la cible est dans le cône : 2707-2712) | 15-40 µs (+10-20 µs par rayon) ; aventure : N² paires légères + 2N lourdes, N ≤ 10 | ETA-06 |
| 10 | `_maj_gadgets` | 2198 ; 3551-3565 | hôte/local | `[p1, p2]` + 1 parcours de groupe + 2 appels par gadget | 2-4 µs | ETA-06 |
| 11 | `_accorder_fusees` | 2199 ; 3125-3154 | chaque image, 2 + N places | `FlareProfile.avancer()` rend un `Array(2)` par place (`flare_profile.gd:66-84`) | ~2 µs | ETA-10 |
| 12 | `_maj_reserves_gadgets` | 2200 ; 3763-3777 | chaque image, **les deux pairs** | 2 × `gadget_basculable_de` = 2 parcours de groupe | 2-4 µs | ETA-06 |
| 13 | recul / secousse de caméra | 2203-2218 | chaque image | 2 `move_toward`, 2 écritures de `cam.offset` | ~2 µs | — |
| 14 | `ReplaySystem.record_frame` | 2220-2221 ; `replay_system.gd:122-260` | **60 Hz** (accumulateur), toute la manche | 1 `Snapshot` (28 champs), 4 `get_node("MuzzleFlash")`, `get_children()` + `has_method`/`is_in_group` par enfant, 1 Array de groupe, 2 boucles sur `bullet_events` à plein tampon | 20-30 µs par échantillon (1,2-1,8 ms/s) | ETA-09 |
| 15 | bloc rejeu | 2223-2315 | killcam seulement (3-7 s) | par image : 1 `Snapshot`, `duplicate()` de Dictionary par fusée/gadget, ~16 `get_node("…")`, 2 Array temporaires, 4 écritures de `shadow_item_cull_mask`, `_maj_fusees_killcam` parcourt `bullet_container` | 20-40 µs | ETA-10 |
| 16 | **`ui.update_hud`** | 2342-2345 ; `ui.gd:8748-8930, 3128-3280, 3369-3490` | **chaque image, menus et killcam compris** | ≈ 8 overrides de thème par joueur et par image (styles, couleurs de police), 2 `find_child` récursifs par joueur, chaînes formatées | **100-400 µs** (non mesuré) | ETA-03 |
| 17 | `_pousser_zone_morte` (signal `frame_pre_draw`) | 498 ; 5979-6010 ; `murs_bas_rendu.gd:128-187` | chaque image dessinée, **seulement si la carte a des murs bas** (aucune des 6 cartes livrées) | 2 vues × (`uniformes_de_vue` : Dictionary + `PackedVector4Array(64)` ; 4 matériaux × 8 `set_shader_parameter`) | 100-180 µs (~20 murs bas) | ETA-07 |

Lecture : les lignes 1-15 totalisent **40-90 µs** (plus 20-30 µs aux images où `record_frame` se déclenche). Les lignes 16 et 17 sont les seules qui puissent dépasser 0,1 ms.

### 1.2 Par tick physique — néant dans ce fichier

`grep` : aucun `_physics_process`, `_input`, `_unhandled_input`, `_draw`, `set_process(false)`. Conséquence : **des requêtes de physique (rayons de l'éblouissement) partent de `_process`**, à la cadence du rendu — donc 5× plus souvent à 300 i/s qu'au pas de 60 Hz, et avec un résultat qui dépend de la machine (ROADMAP l. 4514, « Signalé, non corrigé »). Les gestes qui naissent d'un tick (tir, fusée, gadget) appellent `GameState` depuis `Player._physics_process`.

### 1.3 Par événement

| Événement | Où | Travail synchrone | ESTIMÉ |
|---|---|---|---|
| **Tir** (`_do_spawn_bullet`) | 4157-4250 | par plomb : `bullet_scene.instantiate()` puis `_ready()` crée `Line2D` + `Sprite2D` + `ShapeCast2D` + `CircleShape2D` (`bullet.gd:90-156`) ; 1 douille persistante (`BulletCasing.eject`, 4218) + sa copie P2 différée ; `_flash_de_tir` (au plus 1 rayon, et seulement si l'adversaire est à moins de 600 px : `PORTEE_FLASH`, 2840-2876) ; 2 boucles (`bullet_container`, groupe `gadgets`, 4242-4250) ; secousse caméra | 150-250 µs par tir ; pompe : 5 plombs = 4× plus |
| **Pose de gadget** | 3348-3383 ; 3782-3873 | `_point_de_pose` (1 rayon) ; `_reculer_hors_des_corps` : jusqu'à 49 × `_gene_un_corps` ; `_gabarit_bloquant` = `load()` + `script.new()` + `free()` **à chaque tentative** ; puis `load(chemin)` + `new()` + `add_child` ; 1 parcours de groupe | 0,1-1,5 ms ; 1re pose d'un script : compilation (ETA-05) |
| **Lancer de fusée** | 3193-3243 | `Fusee.new()` + `add_child` ; shader et textures de volutes déjà chauffés (`Fusee.prechauffer`, 1565) | quelques dizaines de µs |
| **Mort / fin de manche** (`_do_end_round`) | 4426-4640 | **archivage complet avant le premier `await`** (ETA-01) ; flash de mort, sons de fin à froid (ETA-02) ; `await frame_post_draw` ; gel 150 ms ; onde de choc (sans shader) ; attente 1,5 s | ETA-01 |
| **Killcam** | 4558-4592, 2223-2315 | `show_killcam`, relevé (`ReleveBalistique.new()`), lecture des instantanés ; **balles rejouées instanciées une par une** (`_on_replay_spawn_bullet`, 4382) ; copies de fusées (`Fusee.new()`) et de gadgets (`modele.new()`) construites à la demande ; **les fantômes de joueurs sont pré-bâtis** (`_setup_ghosts`, 1689-1725) | ETA-02 pour le premier |
| **Estampe + affiche de fin** | 4936-4945 ; 4678-4700 | ~15 contrôles + 2 tweens (estampe) ; `load()` d'une image 1920×1080 sans perte (affiche) | ETA-02 |
| **Départ de manche** (`_do_start_round`) | 1926-2079 | `rebuild_arena` (1412-1572) + `queue_free` des balles + équipement des armes + `start_recording` | ETA-04 |
| **Retour au menu** | 6357-6478 | purge de l'arène, `_peut_etre_la_soiree` (relit tout le journal, une fois par séance, 4719-4727) | froid |

### 1.4 Quantités au pire cas d'un duel

- Corps : 2 joueurs (jusqu'à **10** en aventure : `Presentation3D.FIGURANTS_MAX = 8`, `presentation_3d.gd:155`).
- Cadence de tir : cooldown de 0,09 s (Occulteur) à 0,45 s (Pompe), `game_state.gd:5208` / `541` ; pistolet 0,16 s (`weapon_data.gd:8`) → jusqu'à ~11 tirs/s pour un joueur.
- Fusées : stock de 1 par défaut et par joueur (Spectre 0, Allumeur 2, Terrassier 3, rechargeables : `game_state.gd:2916-2922`, `flare_profile.gd:33`), chacune vit 20 s (`fusee_modele.gd:27-56`). Gadgets : 1 debout par joueur (`_do_spawn_gadget` libère l'ancien, 3835-3837).
- Persistants (plafonnés, avec copie J2) : 120 douilles, 120 taches, 90 éclats → jusqu'à **660 nœuds** (330 + copies). Réserve de particules : 240 corps × 4 nœuds = **960 nœuds** pré-alloués (`particle_pool.gd:22,81-84,108-134`).
- Instantanés de rejeu : 450 (`replay_system.gd:26`). Historique de compensation : 0,4 s × fps = 24 (60 i/s) à 200 (500 i/s) entrées.
- Géométrie d'une carte livrée : 24×24 à 32×32 cases de 35 px ; maximum admis 128×128 (`map_codec.gd:27`).

### 1.5 Les moments décisifs (question 3)

| Moment | Ce qui est fait de façon synchrone | Constat |
|---|---|---|
| Début de manche | `rebuild_arena` : tileset régénéré, ~10 `build_grid` / ~37 décodages RLE, 6 duplications de calques, collisions + occluders, décor cuit puis **relu au GPU**, encre des murs ; sur le client, `rpc_start_round` ajoute décodage + validation du code de carte | ETA-04 (masqué par le décompte de 3 s / 10 s en classé) |
| Premier allumage de torche, premier tir, première pose | `WeaponData.image_torche()` (relecture GPU), `load()` de scripts de gadget, masques de balle, sons chargés à la 1re lecture | ETA-05 |
| Première mort (même image que la fin de match) | flash de mort (shader), bandeau FATAL (glyphes), sons de fin ; **+ archivage ETA-01** | ETA-01, ETA-02 |
| Début de killcam | `killcam_overlay.gdshader` (5 lectures d'écran, mipmaps) sur un `ColorRect` de 20 000² + `BackBufferCopy` plein viewport ; matériau des fantômes ; copies de fusées/gadgets ; `ReleveBalistique` (glyphes) | ETA-02 |
| Fin de killcam / affiche | tampon (1024×340, petit) ; **affiche : `load()` d'un JPG 1920×1080 `compress/mode=0` + mipmaps** | ETA-02 |
| Fin de match | `_archive_match_result` : tri de N durées + 1 à 2 boucles GDScript, relecture + réécriture du journal entier, `report_match` ; plus tard `mark_reported` (2e lecture+écriture) | ETA-01 |

### 1.6 Ce qui grandit pendant une manche ou une soirée (question 4) — rien sans borne

| Structure | Borne | Purge |
|---|---|---|
| `_pos_history` | 0,4 s de temps réel (`POS_HISTORY_WINDOW`, 252-273) | `clear()` à 2049 et 6395 |
| `_predicted_shots` (client) | TTL = 2,5 × RTT, borné [0,5 s ; 3 s] (`prediction_tir.gd:28-33`) ; **purgé seulement à l'arrivée d'une balle officielle** (4258) | `clear()` à 2048, 4470, 6394 |
| `ReplaySystem.snapshots`, `bullet_events` | 450 ; `bullet_events` élagué à chaque échantillon plein (`replay_system.gd:244-260`) | `start_recording` |
| `ConditionsDeMatch._durees` / `_rtt` | N images de la manche (≤ 90 000 floats = 360 Ko par tableau à 300 i/s) | remplacés à `commencer` (2012) |
| Journal de matchs | `HISTORY_MAX = 200` (`match_record.gd:93`) | `cap()` |
| Douilles / taches / éclats | 120 / 120 / 90, éviction FIFO (`bullet_casing.gd:19`, `blood_stain.gd:37`, `wall_impact.gd:45`) ; ni `_process` (taches, éclats) ni traitement au repos (douilles, 95) | balayage si la rencontre change (1382-1397) |
| Tampons de killcam (`_fusees_killcam`, `_gadgets_killcam`, `_traces_killcam`, `_gadgets_masques`) | par rejeu | `_abort_killcam` → `_purger_gadgets_killcam` (4970-4983) |
| `_telemetrie` | compteurs (`telemetrie_gadgets.gd:134-155`) | `commencer` |
| Tweens, minuteurs | auto-terminants | — |
| Connexions de signaux | 1 par gadget (`g.detruit.connect`, 3854), libérée avec lui ; `son_localise` gardé par `is_connected` (6169) | — |
| `MapThumbnail._cache` | une entrée par (id de carte, échelle) | `clear_cache` au changement de catalogue |
| Conteneur « Plafonniers » (aventure) | `rebuild_arena` ne le purge pas — **CONNU** (ROADMAP l. 32601, 32779), contourné par `Plafonnier.poser` idempotente | — |

### 1.7 RPC reçus (question 5)

Tous `@rpc(... "reliable")`, aucun par image. Volume : voir l'agent réseau.

| RPC | Sens | Fréquence | Traitement à la réception |
|---|---|---|---|
| `rpc_start_round` (1842) | hôte → tous, call_local | 1 / manche | **client** : `MapData.adopt_shared_map` (base64 + gzip ≤ 8 Mo + JSON + `validate` avec `duplicate(true)`, + signal `map_selected` → carte du salon) puis `_do_start_round` complet (ETA-04). Hôte : `_host_map_code()` ré-encode la carte (JSON + gzip + base64) à chaque manche (919-922, 1836) |
| `rpc_spawn_bullet` (4128) | hôte → tous, call_local | par tir | `weapon_for_index`, `_consume_predicted_shot` (client : purge + scan de quelques entrées), `_do_spawn_bullet` (ETA-08) |
| `rpc_end_round` (4422) | hôte → tous, call_local | 1 / manche | `_do_end_round` : ETA-01, ETA-02 — **les deux pairs archivent et écrivent le journal** |
| `rpc_sync_time` (4314) | hôte → client | /5 s | une affectation |
| `rpc_spawn_fusee`, `rpc_stock_fusees`, `rpc_eteindre_fusee` | hôte → tous | rares | `Fusee.new()` ; affectations ; scan de `bullet_container` |
| `rpc_spawn_gadget`, `rpc_allumer_gadget`, `rpc_etat_gadget`, `rpc_detruire_gadget` | hôte → tous | rares | `load()` du script + `new()` + `add_child` (ETA-05) ; `get_node_or_null(NodePath(nom))` |
| `rpc_client_weapon`, `rpc_client_ready`, `rpc_client_unready`, `rpc_countdown_*`, `rpc_host_ready`, `rpc_map_refused` | lobby | rares | écritures de libellés UI, `_check_rematch_start` |

Remarque : le tir, la pose de gadget et les messages de lobby partagent le même canal fiable ordonné : une perte retarde tout ce qui suit (périmètre réseau).

### 1.8 Réponses courtes aux cinq questions

1. **Par image** : § 1.1. **Par tick** : rien. Candidats à l'événement / basse fréquence / cache : l'éblouissement (tick fixe), les parcours de groupe (cache par image), les overrides de thème du HUD (sur changement), la zone morte (vue rendue seule), l'historique de compensation (tick physique).
2. **Balles et effets** : instanciation par plomb, sans pool (ETA-08) ; particules en réserve pré-allouée (bien) ; traces plafonnées (bien). **Historique** : `Array[Dictionary]`, un élément **par image rendue** sur l'hôte, fenêtre de 0,4 s en temps ; rembobinage par **balayage linéaire** depuis le plus ancien, une fois par volée du client, avec la posture par un second balayage (ETA-09).
3. **Moments décisifs** : § 1.5 ; la killcam n'instancie **pas** les joueurs (fantômes pré-bâtis) ni de scène « rejouée » : elle instancie les **balles rejouées**, les **copies de fusées et de gadgets** et le relevé.
4. **Croissance** : § 1.6 — rien sans borne.
5. **RPC** : § 1.7.

---

## 2. Constats

| ID | Sévérité | Quoi | Statut ROADMAP |
|---|---|---|---|
| ETA-01 | MAJEUR | archivage de fin de match (tri, journal JSON entier, rapport) sur l'image du kill | NOUVEAU |
| ETA-02 | MAJEUR | premier kill / premier rejeu : compilations et chargements à froid | CONNU-OUVERT (l. 20390, 21416) |
| ETA-03 | MAJEUR (à confirmer) | HUD rappelé à chaque image, ≥ 16 overrides de thème | NOUVEAU |
| ETA-04 | MINEUR | `rebuild_arena` refait et re-cuit tout à chaque manche | NOUVEAU |
| ETA-05 | MINEUR | « premières fois » à froid en duel (image de torche, script de gadget) | NOUVEAU |
| ETA-06 | MINEUR | éblouissement / gadgets / fusées recalculés par image rendue | CONNU-OUVERT pour la cadence (l. 4514) |
| ETA-07 | MINEUR | zone morte des murs bas poussée pour les deux vues, chaque image | NOUVEAU |
| ETA-08 | MINEUR | tir : instanciation non poolée (balles, douilles) | NOUVEAU |
| ETA-09 | ANECDOTIQUE | tampons temporels (compensation de latence, rejeu) | NOUVEAU |
| ETA-10 | ANECDOTIQUE | petits coûts par image | NOUVEAU |

### ETA-01 — L'archivage de fin de match s'exécute sur l'image du kill, avant le gel

**Titre** : statistiques triées, relecture + réécriture complète du journal JSON et rapport au classement, tous synchrones, dans l'image où la balle fatale touche.

**Où** : `game_state.gd:4460` (appel), `:4512-4515` (premier `await`), `:4733-4774` (`_archive_match_result`) ; `conditions_de_match.gd:101-146` ; `match_record.gd:247-285` ; `ranked_identity.gd:274-285` et `:345-350` (`mark_reported`).

**Constat** :
```gdscript
# game_state.gd:4444-4462 (_do_end_round) — BO1 : match_over est toujours vrai
var match_over := winner_id == -1 or MatchRecord.is_match_over(MATCH_FORMAT, p1_round_wins, p2_round_wins)
if match_over:
    ...
    _archive_match_result(winner_id)        # <- avant tout await
# ... 50 lignes plus bas, 4512-4515 : le premier await
await RenderingServer.frame_post_draw
```
```gdscript
# game_state.gd:4740, 4770-4774
var conditions := _conditions.resume()
...
if archiver_les_matchs:
    MatchRecord.append_to_history(record)
_report_to_ranking(winner_id, forfeit, conditions, gadgets)
```
```gdscript
# conditions_de_match.gd:128-138 — N = images rendues de la manche
var triees := durees.duplicate()
triees.sort()
var total := 0.0
for v in triees:          # boucle GDScript sur N floats ; 113 : même chose sur _rtt
    total += v
```
```gdscript
# match_record.gd:247-263
var history := load_history(path)            # FileAccess + JSON.parse_string du journal ENTIER
history.append(record)
history = cap(history, HISTORY_MAX)          # 200
...
file.store_string(JSON.stringify(history, "\t"))   # tout le journal, indenté (clés triées par défaut)
```
Le client fait la même chose à l'arrivée de `rpc_end_round` ; pour tout match en ligne rapporté (identité prête), la réponse du serveur (200 ou 4xx : `ranked_identity.gd:513-531`) déclenche `_settle_front` → `MatchRecord.mark_reported` (`:350`) : **une seconde lecture + écriture complète** du journal, à une image quelconque de la killcam ou de l'écran de fin.

**Coût** :
- *Quand* : une fois par match chez chaque pair, sur l'image du kill (hôte : tick physique de la balle ; client : arrivée du paquet). **PROUVÉ** par lecture : rien n'est différé, l'ordre est archive → `await frame_post_draw`. Le flash de mort (ETA-02) tombe sur la même image.
- *Combien* : **ESTIMÉ, NON MESURÉ**. (a) `resume()` : un tri + 1 à 2 boucles GDScript sur N valeurs ; N = 11 000 (duel de 90 s à 120 i/s), 36 000 (5 min à 120 i/s), 90 000 (5 min à 300 i/s) → de 1 à ~20 ms. (b) journal : une entrée type fait ≈ 1,9 Ko tabulée (reconstituée hors Godot sur une structure équivalente), soit ≈ 375 Ko à 200 entrées ; le coût de `JSON.parse_string` + `JSON.stringify(…, "\t")` + écriture de ce volume n'a jamais été mesuré dans Godot : fourchette honnête **2-6 ms avec ~20 entrées, 10-100 ms au plafond de 200**. Le journal d'un joueur assidu atteint le plafond.
- Rien dans la ROADMAP ne chiffre ce coût (recherche `append_to_history`, `match_history.json`, `HISTORY_MAX` : l. 5009-5015 décrit le plafond, pas le temps).

**Proposition** (par ordre croissant d'effort) :
1. **Différer l'écriture, pas la construction** : construire `record` tout de suite (valeurs de l'instant, `dernier_enregistrement` posé, `_forfeit_pending = false` déjà fait en 4735) et reporter `append_to_history` + `_report_to_ranking` après `await RenderingServer.frame_post_draw` — l'arrêt sur image de 150 ms (`KILL_FREEZE_DURATION`) absorbe alors le coût.
2. Tri hors du fil principal : copier `_durees` à `arreter()`, lancer `statistiques()` dans un `WorkerThreadPool`, n'attendre le résultat qu'à l'écriture (≥ 150 ms plus tard). Ou statistiques en flux (histogramme à pas de 0,1 ms) — **compromis à signaler à Adrien** : `conditions_de_match.gd:25-29` exige « les mêmes définitions que le banc, définition pour définition ».
3. Ne plus relire le journal à chaque match : garder `history` en mémoire (statique) et n'y ajouter qu'une entrée ; réécrire l'ensemble sans indentation, ou passer en JSON-lignes (ajout en fin de fichier) — **changement de format** du journal (rejeu `tools/test_rejeu_journal.gd`).

**Gain attendu** : retire de l'image du kill ~10-40 ms (ESTIMÉ, fourchette 3-120). Aucun effet sur la cadence moyenne.

**Risque** : intégrité du journal et du rapport classé (ordre archive → `mark_reported`, course avec une déconnexion : `_archive_forfeit` est gardé par `_forfeit_pending`, mis à faux à 4735 ; ne pas le déplacer) ; thread : `MatchRecord` lit/écrit le même fichier depuis `mark_reported` (sérialiser). Tests : `test_rejeu_journal`, `test_conditions_de_match`, `test_match_format`, `test_online_match`.

**Effort** : S (1), M (2-3). **Sévérité** : **MAJEUR** (sous réserve de la mesure ci-dessous). **Statut ROADMAP** : NOUVEAU.

**Comment le vérifier** : sans lancer le jeu, un script `--script` (ces deux classes n'ont aucune dépendance d'autoload : voir `tools/test_conditions_de_match.gd`, `tools/test_rejeu_journal.gd`) qui fabrique 200 enregistrements puis chronomètre (`Time.get_ticks_usec`) `MatchRecord.append_to_history(rec, "user://bench.json")` et `ConditionsDeMatch.statistiques(PackedFloat32Array de 36 000 valeurs)`. Dans le jeu : accumulateur autour de 4740 et 4771 + un duel jusqu'au kill avec `user://match_history.json` rempli (copie du vrai fichier d'Adrien). `pire_image_ms` du journal ne le voit pas (le relevé s'arrête à la mort).

---

### ETA-02 — Premier kill / premier rejeu : compilations et chargements à froid sur le chemin du kill (le « hoquet au premier rejeu » reste ouvert)

**Titre** : tout ce que la mort, la killcam et l'écran de fin utilisent pour la première fois se paie à ce moment-là.

**Où** : `game_state.gd:6, 634-647, 1689-1725, 2226-2259, 4331-4353, 4558-4590` ; `ui.gd:15, 3813-3841, 9310-9328` ; `killcam_overlay.gdshader:20, 52-61` ; `player.gd:6-11, 2987-2993` ; `death_flash.gdshader:18` ; `estampe_de_kill.gd:126-149, 241` ; `affiche_de_fin.gd:476-490` ; `audio_manager.gd:1479-1505`.

**Constat** (ce qui est créé ou chargé à la première utilisation) :
- `SHADER_KILLCAM` : 96 lignes, **5 lectures de `hint_screen_texture` en `filter_linear_mipmap`** (lignes 52-61), posé sur un `ColorRect` de **20 000 × 20 000** (`game_state.gd:644-647`) + un `BackBufferCopy` plein viewport (`635-640`) ; rien ne les dessine avant `ui.show_killcam()` (4567).
- `SHADER_GHOST` (`const` à `game_state.gd:6`, matériau à 1690-1692) : premier dessin à `ghost_p1.show()` (2227).
- `SHADER_DEATH_FLASH` (matériau créé dans `die()`, `player.gd:2987-2993`) : premier dessin à l'image du kill — **la même que ETA-01**.
- Glyphes d'enseigne (FATAL, tampon `KILL — mm:ss`, relevé, affiche) : rasterisés à la première occurrence de chaque taille.
- `affiche_de_fin.gd:482` : `load("res://assets/ui/fin_victoire.jpg")` — **1920×1080, `compress/mode=0` (sans perte), mipmaps** (`.import`) : décodage + téléversement de ~8-11 Mo, synchrones, au moment où l'affiche se pose. (Le cadre du tampon, 1024×340, est petit.)
- Copies de fusées et de gadgets du rejeu : `Fusee.new()` / `modele.new()` + `_ready()` au premier instantané où ils existent (3890-3897, 3957-3978).
- Sons de fin / acouphène / annonceur : `get_audio_stream` charge à la première lecture (`audio_manager.gd:1503`), aucun préchargement (hors périmètre : audio).

**Hypothèse sur le moteur (NON vérifiée ici)** : sous `gl_compatibility`, un `Shader` « préchargé » n'est compilé en programme GL qu'à son **premier dessin**. Indices : (1) le code le sait pour la fusée — `Fusee.prechauffer` (`fusee.gd:338-358`) dessine « un quad invisible une image » pour payer hors action « la compilation du shader du voile » ; (2) la ROADMAP mesure sur le Mac des **hoquets de 143 à 150 ms qui sont des compilations au premier allumage d'une sorte de lampe** (l. 27615-27622, lampes 3D de l'essai iso) ; (3) à l'inverse `death_flash.gdshader:18-19` affirme « Ressource préchargée : compilée au démarrage, la première mort ne déclenche plus de compilation à chaud », ce que `Fusee.prechauffer` contredit — une des deux idées est fausse.

**Coût** : **NON MESURÉ** — la ROADMAP le dit en toutes lettres (« le hoquet au premier rejeu n'est pas tranché : ni la capture ni le photographe ne mesurent un temps d'image », l. 21416-21417 ; question posée aussi l. 20390). Le banc de cadence ne peut pas le voir : échauffement de 12 s, relevé arrêté à la mort. Ordre de grandeur plausible (ESTIMÉ) : quelques ms à quelques dizaines de ms par shader compilé ; 20-50 ms pour le décodage de l'affiche.

**Proposition** :
1. **Mesurer d'abord** : première puis deuxième mort dans le même processus (la différence est le coût à froid).
2. **Une table de chauffe unique**, payée pendant le décompte (ou à l'ouverture du menu) : dessiner une fois chaque matériau du kill — killcam (avec son grain), fantôme, flash de mort, vignette, voile d'éblouissement, flou de brouillage — sur un quad de 1 px dans un `SubViewport` **isolé** (World2D propre, `UPDATE_ONCE`, libéré 2 images après), sur le modèle de `Fusee.prechauffer`. Jamais dans l'arène (noir absolu).
3. `ResourceLoader.load_threaded_request` pour `fin_victoire.jpg` / `fin_defaite.jpg` au début de la killcam (1,5 s + 3-7 s de rejeu disponibles) ; même chose pour les sons de fin.
4. Corriger le commentaire de `death_flash.gdshader:18-19` une fois la mesure faite.

**Gain attendu** : supprime l'à-coup du premier kill de chaque session ; aucun effet sur le régime.

**Risque** : gameplay nul. Une chauffe mal isolée peut afficher un pixel ou s'exécuter dans une autre variante de rendu que le jeu (ROADMAP l. 27617-27619 : « chaque vue a SES matériaux »). VRAM : négligeable.

**Effort** : M. **Sévérité** : **MAJEUR** (sous réserve de la mesure). **Statut ROADMAP** : **CONNU-OUVERT** (l. 20390, 21416 ; doctrine « préchargé » l. 16523-16524, 18295-18296, qui ne couvre pas la compilation).

**Comment le vérifier** : `tools/photographe.gd` (plan `killcam`) ou `tools/banc_bot_duel.gd` avec un journal des images lentes (`bench_framerate.gd --seuil-lent 25` date déjà toute image lente et imprime ses « événements ») ; deux kills de suite dans la même exécution, **fenêtre au premier plan** ; comparer l'image la plus lente du premier rejeu à celle du second. Suites utiles : `test_killcam_calme`, `test_releve_balistique`, `test_iso_killcam`, `test_fusee_killcam`.

---

### ETA-03 — `_process` rappelle le HUD à chaque image (menus et killcam compris) et le HUD repose ≥ 16 overrides de thème par image

**Titre** : `ui.update_hud` est appelé sans condition ; les cartouches (torche, fusées, gadget) réécrivent leur style et la couleur de leur libellé même quand rien n'a changé.

**Où** : `game_state.gd:2342-2345` (appel) ; `ui.gd:8801-8803, 8844-8846` (`_set_torch_style`, `_marquer_accroupi`, `_maj_reserves`), `:3168-3169, 3246-3247, 3271` (couleurs de libellés, `_set_gadget_style`), `:3375-3385` (voxel, défaut : `Charte.habillage_par_argument` rend `voxel`, `charte.gd:470-488`), `:3406-3413` et `:3459-3486` (habillage « pâte » : **`StyleBoxFlat.new()` par image**), `:2963, 3382, 3417` (`find_child` récursifs).

**Constat** :
```gdscript
# ui.gd:3375-3385 — _set_torch_style, appelé pour chaque joueur à chaque image
panel.add_theme_stylebox_override("panel", _plaques_de_cartouche(panel, active, player_color))
var hb := panel.get_child(0).get_child(0)
var lb := hb.get_child(1) as Label
lb.add_theme_color_override("font_color", COLOR_LUMIERE if active else Charte.PATE_TEXTE_SECOND)
var v := panel.find_child("Verrou", true, false) as Control      # recherche récursive par nom
```
Même schéma pour `_set_flare_style` / `_set_gadget_style` (→ `_habiller_la_reserve`, 3438-3450) et pour `lbl_f` / `lbl_g` dans `_maj_reserves` (3168, 3246). Le commentaire de `ui.gd:8908-8909` l'énonce déjà pour le chrono — « poser un override de thème à chaque frame coûte pour rien » —, mais pas pour ces sites.

**Coût** : **ESTIMÉ, NON MESURÉ**. Chaque `add_theme_*_override` déclenche `NOTIFICATION_THEME_CHANGED` sur le contrôle (invalidation du cache de thème, `update_minimum_size`, redessin) **même pour la valeur déjà posée** (comportement du moteur, non vérifié ici). Comptage statique : par joueur, 3 styles + 5 couleurs de police + 2 `find_child` ; deux joueurs (le bloc de J2 est mis à jour même quand sa vue n'est pas affichée) ⇒ **≥ 16 notifications par image**. À 5-25 µs pièce : **~80-400 µs par image**, soit 0,8-4 % d'une image à 100 i/s — **le plus gros suspect par image de ce chemin, plus que tout ETA-06 réuni**. Il tourne aussi en menu (`match_hud.hide()`, `ui.gd:9003-9004`, ne l'arrête pas), en killcam et sur l'écran de fin.

**Proposition** : (côté `game_state.gd`, S) n'appeler `update_hud` que lorsque le HUD de match est affiché (`ui.match_hud.visible`) — manche, bac à sable, séquence de fin si utile — et jamais en menu ; (côté `ui.gd`, M, **hors périmètre : à porter par l'agent UI**) mémoriser le dernier état de chaque cartouche (`actif`, `teinte`, `verrouillé`) et ne poser style / couleur / `find_child` qu'au changement, comme `_teindre_chrono` (8908-8922) le fait déjà.

**Gain attendu** : jusqu'à 0,1-0,4 ms par image en duel (ESTIMÉ), le tout en menu / killcam.

**Risque** : HUD périmé si un état est sauté (`p1_target_hp`, secousses, voile) ; suites d'interface (`test_hud*`, `test_screen_*`). Gagner sur le 1 % bas demande de mesurer d'abord : la marge est de ~0,5 ms (relevé d'Adrien « de deux images par seconde » au-dessus de 60, `CLAUDE.md`).

**Effort** : S (gating) + M (cache d'état). **Sévérité** : **MAJEUR** (hypothèse à confirmer par une mesure d'une minute ; le comptage des appels, lui, est PROUVÉ par lecture). **Statut ROADMAP** : NOUVEAU.

**Comment le vérifier** : accumulateur `Time.get_ticks_usec()` autour de `ui.update_hud` (2342-2345) pendant 10 s de duel et 10 s de menu ; ou `Performance.get_monitor(Performance.TIME_PROCESS)` avec et sans l'appel. Comparer `--charte=pate` / défaut `voxel`.

---

### ETA-04 — `rebuild_arena()` reconstruit et re-cuit toute l'arène à chaque manche, même pour la même carte (dont une relecture GPU du décor)

**Titre** : aucun cache par carte ; le coût suit le CARRÉ de la taille de la carte pour le décor.

**Où** : `game_state.gd:1412-1572` (appelée par `_do_start_round`, 1948) ; `candela_tileset.gd:69-98` ; `map_geometry.gd:128-172, 269-314, 321-328` ; `mur_led.gd:166-167` ; `mur_encre.gd:88-111` ; `arena_decor.gd:114-131, 176-215` ; `map_data.gd:409-446` ; `audio_manager.gd:1056-1064`.

**Constat** (comptage statique des appels sur la même `data`) :
- **10 appels à `MapGeometry.build_grid`** (chacun : 3 décodages RLE + 3 Dictionary + une grille de (côté+2·BORDER)² cases) : 3 dans `build_collisions` (1496), 1 dans `rects_monde` (1497), 4 dans `MurLed.poser` (1503 → `mur_led.gd:166-167` : `build_grid` + `build_solid_grid`, qui en fait 3), 2 dans `MurEncre.setup` (1558 → `mur_encre.gd:92-93`). Soit **~37 décodages RLE** avec `apply_to_layers` (4), `accorder_a_la_carte` (1) et `ArenaDecor._analyser_carte` (2), plus 4 `merge_rects`, 2 `trace_contours`.
- `CandelaTileSet.create_tileset()` (1462) régénère l'atlas 70×70 en GDScript (≈ 4 900 `set_pixel`, ~600 hachages) et un nouveau `TileSet` + `ImageTexture` **à chaque manche** ; le résultat est constant.
- 6 × `layer.duplicate()` (1513-1518), `ArenaDecor` et `MurEncre` doublés par vue (`_duplicate_for_player` ×2) : **les copies J2 sont construites aussi en vue unique**, où elles ne sont jamais affichées.
- **Le décor est cuit puis relu au GPU à chaque manche** :
```gdscript
# arena_decor.gd:176-215 (_cuire, lancé par _ready de chaque nouvelle instance)
await get_tree().process_frame
var vue := SubViewport.new();  vue.size = Vector2i(_cadre.size)     # (grille+2) × 35 px
...
await RenderingServer.frame_post_draw
var img: Image = vue.get_texture().get_image()                       # relecture GPU synchrone
_cuit = ImageTexture.create_from_image(img)                          # puis re-téléversement
```
  `MurLed` a son cache (`mur_led.gd:131-132, 210-213`, clé = grille) ; **le décor n'en a aucun** : l'en-tête (« cuit en une texture par carte », `arena_decor.gd:22`) est vrai par *instance*, et `build()` en crée une neuve à chaque appel. Tailles : 32×32 → 1 190² = **5,7 Mo lus + 5,7 Mo téléversés** ; 26×26 → 3,8 Mo ; **128×128 (maximum admis) → 4 550² = 83 Mo** lus puis re-téléversés, par manche.
- Côté client, tout ceci s'exécute dans l'image où arrive `rpc_start_round`, précédé du décodage du code de carte (§ 1.7).

**Coût** : **ESTIMÉ 30-60 ms** par départ de manche pour une carte livrée (≈ 6 ms de décodages, 6 ms de remplissage de grilles, 3 ms de contours, 2 ms de tileset, 2-3 ms de `set_cell`, ~4 ms de ~400 nœuds de collision/occlusion, 5-10 ms de dessin de l'encre des deux copies, 3-10 ms de cuisson + relecture du décor), étalés sur 3 images ; sur l'hôte **et** le client, à chaque revanche. **NON MESURÉ** — la ROADMAP ne contient aucune mesure du départ de manche (recherche `rebuild_arena` : aucun chiffre). Masqué par le décompte (3 s ; 10 s en classé) : **pas visible dans le duel, et hors du 1 % bas** — d'où MINEUR. Reste un gaspillage permanent, et un coût quadratique sur les grandes cartes joueur.

**Proposition** :
1. **Mémoïser `build_grid(data, kind)`** par `data.hash()` (déjà calculé par `_empreinte_de_la_rencontre`, `game_state.gd:1354-1365`) ou par un compteur de génération de `MapData` : 10 → 3 constructions. (S)
2. `static var` pour `create_tileset()` (résultat constant). (S)
3. **Cache statique du décor cuit**, clé = hash de la carte + drapeau pochoirs, comme `MurLed` : plus aucune relecture GPU aux revanches. (M)
4. À terme, court-circuit « même carte que la manche précédente » : ne remettre à neuf que le dynamique (les traces sont déjà conservées exprès, 1382-1397). (L)
5. Option à arbitrer : ne pas construire les copies J2 hors écran scindé (interdit alors de repasser en scindé sans reconstruire).

**Gain attendu** : −20 à −50 ms par départ de manche (ESTIMÉ), et −2 × (5,7 à 83) Mo de trafic GPU par manche.

**Risque** : états remis à zéro *par* la reconstruction (« `rebuild_arena` éteint les torches », ROADMAP l. 26057 ; `Presentation3D.accrocher` pose `_reconstruire`, 1572) ; invalidation si une carte change sans changer de `id` ; suites `test_arena_build`, `test_traces_carte`, `test_traces_rencontre`, photographe, bancs iso.

**Effort** : S (1-2), M (3), L (4). **Sévérité** : MINEUR. **Statut ROADMAP** : NOUVEAU (l. 22739-22742 documente le cache de la LED « une fois par carte » ; l. 33870 annonce « le décor cuit en une texture par carte » sans cache inter-manches).

**Comment le vérifier** : `Time.get_ticks_usec()` autour des sous-étapes 1462 / 1492 / 1496-1497 / 1503 / 1513-1518 / 1538 / 1558, **deux manches de suite dans le même processus** (froid / chaud) ; `Performance.TIME_PROCESS` des 3 images qui suivent ; carte 32×32 puis 128×128 pour la loi en carré. Non-régression : `tools/test_arena_build.gd`.

---

### ETA-05 — Chargements et lectures GPU à froid en plein duel : image de la torche, script de gadget, masques de balle (et sons)

**Titre** : « premières fois » synchrones sur l'action (premier allumage, premier tir, première pose).

**Où** : `weapon_data.gd:288-299, 322-323` ← `vision.gd:130-155` ← `game_state.gd:2672, 2707-2711` ; `game_state.gd:3796, 3504-3514, 5319-5349` ; `bullet.gd:88, 104` ← `light_textures.gd:65-76` ; `audio_manager.gd:1479-1505`.

**Constat** :
```gdscript
# weapon_data.gd:288-299
func image_torche() -> Image:
    if _torch_image != null: return _torch_image
    var tex := get_torch_texture()
    ...
    var img := tex.get_image()                 # relecture GPU, synchrone (la doc Godot la déconseille en boucle)
    if img != null and img.is_compressed(): img.decompress()
    _torch_image = img
```
`_lumiere_du_faisceau` (2699-2718) appelle `arme.lumiere_recue(...)` → `image_torche()` **avant** de savoir si la cible est dans le cône (le test de cône est dans `Vision.intensite_texture`, après l'accès à l'image) : la lecture a donc lieu dès la première image où une torche est allumée en face d'un joueur « en jeu », pour chaque classe, **une fois par `ClassData`** (le catalogue est reconstruit à chaque montage de `main.tscn`, 592). Cookies 1 024² RGBA8 = 4 Mo. Hôte et local seulement (le client sort de `_maj_eblouissement`, 2361).
- `_do_spawn_gadget` : `var script: GDScript = load(chemin)` (3796) — `IMPLEMENTATIONS` ne contient que des chemins (5319-5349), jamais de `preload`. Un script déjà chargé parce qu'un autre script le **nomme** (`GadgetMine`, `GadgetGresillement`, `GadgetPoudre` dans `game_state.gd` ; `GadgetSuie`/`GadgetVolume` dans `player.gd` ; `GadgetLeurre` dans `miroirs_iso.gd`/`murs_bas.gd`) revient du cache ; **`GadgetOmbre`, `GadgetBraises`, `GadgetPoussiere` ne sont nommés par aucun autre script** (et `GadgetTorcheFantome` seulement par `voxel_catalogue_objets.gd`) : leur **compilation tombe à la 1re pose**, chez l'hôte comme chez le client (`rpc_spawn_gadget`). `_gabarit_bloquant` (3504-3514) refait `load()` (caché) + `script.new()` + `free()` **à chaque tentative de pose** d'un gadget qui arrête les joueurs.
- `bullet.gd:88, 104` : `LightTextures.masque(...)` charge la traînée et la traçante au premier tir (petites textures : 256×12).
- Les flux sonores se chargent à la première lecture (aucun préchargement) : même famille, pour l'agent audio.

**Coût** : **ESTIMÉ, NON MESURÉ** : 1-10 ms pour une relecture GPU de 4 Mo (synchronise le GPU) ; 1-5 ms pour compiler un script de gadget ; sous 1 ms pour les masques. Une fois par classe et par processus — mais à un moment que le joueur ressent (premier appui sur la torche, première pose).

**Proposition** : pendant le décompte, dans `_do_start_round` juste après `equip_weapon` (1985-1986) : appeler `image_torche()` des deux armes ; `ResourceLoader.load_threaded_request` sur `IMPLEMENTATIONS[slug].script` des classes en jeu ; `LightTextures.masque` des deux textures de balle dans `rebuild_arena`. Mettre `_torch_image` en cache statique par slug de cookie plutôt que par instance.

**Gain attendu** : supprime 3-4 petits à-coups « première fois » par session.

**Risque** : nul pour le jeu ; `image_torche()` doit rester l'image *projetée* (ne pas la reconstruire autrement — ROADMAP l. 8024-8036 sur les appuis périmés).

**Effort** : S. **Sévérité** : MINEUR. **Statut ROADMAP** : NOUVEAU.

**Comment le vérifier** : accumulateur autour de 2672 (la 1re image doit ressortir) ; pour le gadget, autour de 3796 ; `bench_framerate.gd --seuil-lent 10` daté contre le premier allumage. Suites : `test_vision`, `test_eblouissement`, `test_classes`.

---

### ETA-06 — Éblouissement, gadgets, fusées : tout est recalculé à chaque image rendue (≈ 40 allocations, ~10 parcours de groupe)

**Titre** : travail à la cadence du rendu, avec allocations et parcours de groupe répétés ; la dépendance à la cadence est connue et ouverte.

**Où** : `game_state.gd:2197-2200` ; `2360-2406` (`_maj_eblouissement`), `2442-2539` (`_sources_eblouissantes`), `2551-2607`, `2620-2673`, `2679-2684` (`facteur_de_lampe_a`), `2746-2830` (`_ligne_de_vue_depuis`), `3551-3565`, `3618-3624` (`gadget_basculable_de`), `3763-3777`.

**Constat** :
- Parcours de `get_tree().get_nodes_in_group("gadgets")` par image, hôte, deux torches allumées, sans gadget : `_sources_eblouissantes` 1 (+1 pour `"fusees"`), `facteur_de_lampe_a` **4** (2 cas « soi » + 2 paires croisées — l'argument est évalué *avant* le test de cône, 2672-2673), `_maj_gadgets` 1, `_maj_reserves_gadgets` 2 ⇒ **8 dans `game_state.gd`** (+1 sur `"fusees"`) ; `_ligne_de_vue_depuis` (2790) en ajoute 1 **par rayon**. S'y ajoutent hors fichier **2 par image** dans `ui.gd:3205` (`_maj_reserves`, un par joueur) et **1 par tick et par torche allumée** dans `player.gd:2003` (`_physics_process`, `facteur_de_lampe`). Total ≈ **10-11 par image**, tous à vide dans le cas courant.
- Par image aussi : `_joueurs_en_lice()` deux fois (2 Array), `gagnante := {}` / `plafond := {}` (2391-2392), un Dictionary de 5 clés par torche (2446-2455) ou par gadget (2523-2538), `PhysicsRayQueryParameters2D.create` + 2 Array + le Dictionary de résultat **par rayon** (2772-2812) — rayons seulement si la cible est dans le cône (2707-2712), donc rares : bon point.
- Ne dépend pas de `round_active` : tourne en menu (fonction 2197 non gardée ; seul le client sort).
- **Aventure** (SOLO S9b) : `_joueurs_en_lice()` rend jusqu'à 10 corps (`FIGURANTS_MAX = 8`) ⇒ N² paires, dont 2N « lourdes » (joueur↔PNJ : math du cône + parcours de groupe + rayon éventuel) et N² légères (deux `get("est_pnj")` dynamiques, 2561).
- `GameState` n'a pas de `_physics_process` : ces rayons sont tirés depuis `_process`, donc 5× plus souvent à 300 i/s qu'à 60 Hz.

**Coût** : **ESTIMÉ** 15-40 µs par image au duel (+10-20 µs par rayon), 100-200 µs en aventure à 8 PNJ ; 0,2-0,5 % d'une image à 100 i/s, 1-2 % à 300 i/s. La ROADMAP donne une échelle : « 200 sources × 2 cibles coûteraient ~1,3 ms par image » (commentaire de `game_state.gd:2431-2432`, à l'époque du budget de 139 µs), soit ~3 µs par paire.

**Proposition** :
1. **Un seul parcours de groupe par image** (`_gadgets_de_l_image`, rempli à la première demande de l'image, `Engine.get_process_frames()`), ou un registre tenu par `GadgetBase` ; mêmes valeurs pour `ui.gd` / `player.gd`. (S)
2. Sortie anticipée de `_maj_eblouissement` quand aucune source n'existe (aucune torche allumée, aucune fusée posée, aucun gadget éblouissant) **et** que les deux `dazzle_amount` valent 0 ; `PhysicsRayQueryParameters2D` réutilisé. (S)
3. **Pas fixe** : passer l'éblouissement dans un `_physics_process` (60 Hz, `delta` du pas). Règle *aussi* la dépendance à la cadence (« deux parties scriptées identiques divergent… une pénalité de jeu dépend de la cadence de la machine », ROADMAP l. 4514-4523, **signalé non corrigé**). (M)

**Gain attendu** : −20 à −50 µs par image (duel), ×N en aventure ; surtout le déterminisme (3).

**Risque** : (3) quantifie la réponse à 16,7 ms et touche la simulation : à valider par Adrien ; suites qui comparent des parties pas à pas (`test_iso_vues`, `test_online_match`, `banc_iso`) ; l'équité ne change pas (l'hôte seul arbitre, valeur répliquée `net_dazzle`). (1) : un gadget posé dans l'image est absent jusqu'à la suivante (acceptable pour l'éblouissement ; pas pour une pose).

**Effort** : S (1-2), M (3). **Sévérité** : MINEUR. **Statut ROADMAP** : **CONNU-OUVERT** pour la dépendance à la cadence (l. 4514) ; NOUVEAU pour le coût.

**Comment le vérifier** : accumulateur autour de 2189-2200 ; compter les appels de `get_nodes_in_group` (compteur temporaire) ; `tools/test_eblouissement.gd`, `tools/test_tir_et_reserves.gd`, `tools/test_fusee_eteinte.gd` pour la non-régression.

---

### ETA-07 — Zone morte des murs bas : poussée à chaque image pour les deux vues, même celle qu'on ne regarde pas

**Titre** : `_pousser_zone_morte` recalcule et repose tous les uniformes chaque image dessinée, sur les cartes à murs bas.

**Où** : `game_state.gd:498` (connexion à `frame_pre_draw`), `5979-6010` ; `murs_bas_rendu.gd:128-187`.

**Constat** :
```gdscript
# game_state.gd:5986-6010 — pour pid in 2 : (vue 0, vue 1), chaque image dessinée
var rendu: Node = _viewport_du_monde(pid)                         # 2 appels à Presentation3D.parent_ecran
var ecran := cible.get_final_transform() * cible.get_canvas_transform()
var u := MursBasRendu.uniformes_de_vue(ecran * arena.global_transform, murs_bas, Rect2(Vector2.ZERO, taille))
for m in _materiaux_zone_morte[pid]: MursBasRendu.poser_sol(m, u)         # 8 set_shader_parameter chacun
...poser_corps(moi.visual.material, ...) ; poser_corps(autre.visual_enemy.material, ...)
```
`uniformes_de_vue` boucle sur tous les murs bas (transforme, teste l'intersection, `append`) puis `tableau.resize(64)` et rend un Dictionary de 12 clés ; `_poser` fait 8 `set_shader_parameter` dont le `PackedVector4Array(64)` (1 Ko copié). Par image : 2 vues × (1 + 1 + 2 matériaux) × 8 = **64 `set_shader_parameter`**. En vue unique, la moitié (la vue non rendue : ses matériaux J2 de sol, de décor et les corps) est calculée pour rien. `if murs_bas.is_empty()` sort après la première poussée (5982-5985) : **coût nul sur les 6 cartes livrées** (aucune n'a de murs bas : contrôlé sur `assets/maps/*.json`) — il ne concerne que les cartes de joueurs, dont l'éditeur est une fonction mise en avant.

**Coût** : **ESTIMÉ 100-180 µs par image** pour une carte de ~20 murs bas (≈ 64 appels × 0,3-0,8 µs + 2 × 20-40 µs de `uniformes_de_vue`), dont ~50 % sur la vue non rendue. NON MESURÉ.

**Proposition** : ne traiter que la vue rendue (`_rendu_racine` / conteneur visible, déjà connus de `_accorder_rendu_aux_vues`) ; ne reposer les uniformes d'une vue que si sa transformation d'écran ou les positions des deux joueurs ont changé ; hisser `tableau.resize(64)` hors boucle (tableau réutilisé).

**Gain attendu** : −50 à −100 µs par image sur les cartes à murs bas.

**Risque** : visuel — la zone morte doit rester exacte à l'image près (`tools/test_murs_bas_rendu.gd`, `tools/banc_murs_bas.tscn`) ; au changement de vue (iso ↔ scindé) il faut repousser les uniformes.

**Effort** : S-M. **Sévérité** : MINEUR. **Statut ROADMAP** : NOUVEAU.

**Comment le vérifier** : charger une carte perso à 20 murs bas (éditeur), accumulateur autour de `_pousser_zone_morte` ; `tools/banc_murs_bas.tscn`.

---

### ETA-08 — Tir : instanciation non poolée (4 nœuds + 1 ressource par balle, ×5 au pompe), douille persistante et copie J2 différée

**Titre** : chaque plomb construit son arbre de nœuds ; chaque douille construit deux nœuds et parcourt 120 voisines au plafond.

**Où** : `game_state.gd:4157-4250` (4182 `bullet_scene.instantiate()`, 4218 `BulletCasingScript.eject`, 4242-4250) ; `bullet.gd:75-175, 353-357` ; `bullet_casing.gd:36-79, 138-170`.

**Constat** :
- `bullet.tscn` (6 lignes) ne contient que le script ; `Bullet._ready()` crée `Line2D` (`Core`) + `Sprite2D` (`Aura`) + `ShapeCast2D` + `CircleShape2D` à chaque instance. Le pompe tire 5 plombs dans la même image (`projectile_count = 5`, `game_state.gd:552`) : ~20 nœuds + 5 formes en un tick. À chaque tick physique, chaque balle réécrit `core.points = PackedVector2Array([...])` (une allocation) et fait `has_node("Core")` + `get_node("Core")` (`bullet.gd:356-357`) — pour l'auditeur des balles.
- `BulletCasing._ready()` (67-78) : `get_tree().get_nodes_in_group("bullet_casing")` (copie jusqu'à 120 nœuds) ; **au plafond (120), à chaque tir** : `_evict_oldest()` reparcourt le groupe en GDScript (138-144). Puis `call_deferred("_create_p2_duplicate")` → `duplicate()` d'un second nœud (154-170), **même en vue unique**.
- Plus par volée : 2 boucles (`bullet_container.get_children()` pour la diffusion de fumée, `get_nodes_in_group("gadgets")`, 4242-4250), `_flash_de_tir` (1 rayon).
- À l'impact (`bullet.gd:672-699`) : 2 `BloodStain` (nœuds + `set_script`), des particules (pool, bien), et un `Label` + `LabelSettings` + tween par chiffre de dégâts (`_spawn_damage_number`, 732-810).

**Coût** : **ESTIMÉ 150-250 µs par tir** (≈ 40-80 µs par balle, 60-90 µs la douille), jusqu'à 400 µs au pompe ; à 6-11 tirs/s : 1-3 ms/s, soit 0,1-0,3 % du CPU. Fait de ce poste un MINEUR : ni hoquet ni coût de régime visible.

**Proposition** : réserve de balles (même patron que `ParticlePool` : pré-allouée, `Line2D`/`Sprite2D`/`ShapeCast2D` conservés, état remis à zéro) ; douilles : compteur d'éviction O(1) (file FIFO au lieu de `get_nodes_in_group`) ; ne créer la copie P2 que si la vue de J2 est affichée (même arbitrage que ETA-04.5).

**Gain attendu** : −100 à −200 µs par tir ; moins de churn mémoire.

**Risque** : une balle poolée doit tout réinitialiser (`is_replay`, `lag_target`, exceptions du `ShapeCast2D`, tween de fondu en cours) ; les balles rejouées (`_on_replay_spawn_bullet`) ont des réglages propres. Les balles ne sont pas des cibles de RPC : le nommage explicite n'est pas en jeu.

**Effort** : M. **Sévérité** : MINEUR. **Statut ROADMAP** : NOUVEAU (le pool de *particules* est DÉJÀ-TRANCHÉ ; la lumière de la balle a été supprimée le 2026-09-15, `bullet.gd:77-85`).

**Comment le vérifier** : `tools/banc_balle_sans_lumiere.tscn`, `Performance.OBJECT_NODE_COUNT` / `OBJECT_COUNT` avant et après une rafale de pompe ; accumulateur autour de 4157-4250.

---

### ETA-09 — Tampons temporels : historique de compensation de latence par image rendue, enregistrement du rejeu à 60 Hz

**Titre** : un Dictionary par image rendue (au lieu d'un échantillon par tick physique) ; un `Snapshot` complet par échantillon de rejeu.

**Où** : `game_state.gd:4266-4305, 4175-4176, 2091-2092` ; `replay_system.gd:122-260`.

**Constat** (réponse à la question 2) :
- **Stockage** : `_pos_history: Array[Dictionary]`, un `{"t","p1","p2","a1","a2"}` ajouté **à chaque `_process` de l'hôte** (lobby compris), élagué par `while … now − t > 0,4` → `remove_at(0)`. Longueur = 0,4 × fps : 24 (60 i/s), 58 (144), 120 (300), 200 (500). Les positions ne changent qu'aux ticks physiques : à 300 i/s, 4 échantillons sur 5 sont des doublons.
- **Rembobinage** (une fois par volée du client, 4173-4176) : `_rewound_position` balaie *linéairement* depuis le plus ancien jusqu'à l'instant visé (`float(b["t"])`, 3-4 lectures de Dictionary par pas), puis `_rewound_posture` fait un second balayage ; `_lag_comp_delay()` est évalué deux fois. ≈ 60 µs par tir du client à 300 i/s, ~25 µs à 60 i/s (ESTIMÉ).
- **Rejeu** : `record_frame` construit un `Snapshot` (28 champs) à 60 Hz toute la manche, fait `p.get_node("MuzzleFlash")` ×4, `has_method("age_combustion")` + `is_in_group("gadgets")` par enfant de `Bullets`, et, **dès que le tampon est plein (450)**, deux boucles sur `bullet_events` + un nouvel Array à chaque échantillon (254-260).
- À noter (hors perf) : `_record_accum -= RECORD_PERIOD` ne s'exécute qu'une fois par image (`replay_system.gd:130`) ; sous 60 i/s soutenus, un seul échantillon par image est écrit et `playback_index += delta * 60` (541) rejoue trop vite — la phrase « la killcam identique partout » (l. 11-21) n'est vraie qu'à ≥ 60 i/s. Signalé, non corrigé.

**Coût** : **ESTIMÉ** 2 µs par image (historique), 20-30 µs par échantillon de rejeu (1,2-1,8 ms/s). Négligeable.

**Proposition** : échantillonner l'historique au tick physique (24 entrées fixes) dans trois tableaux parallèles (`PackedVector2Array` ×2, `PackedByteArray`) avec recherche dichotomique ; pour le rejeu : `@onready` des `MuzzleFlash`, enregistrer `bullet_events` dans un tableau parallèle à base d'indices absolus (plus de ré-indexation à chaque échantillon).

**Gain attendu** : ~2 µs par image, ~50 µs par tir du client, ~10 µs par échantillon. Cosmétique côté CPU ; cohérence côté simulation (rembobiner au pas où la position a réellement changé).

**Risque** : équité de la compensation — rembobiner à l'échantillon de tick plutôt qu'à l'image décale l'instant visé d'au plus 1 tick ; `test_rejeu`, `test_online_match`.

**Effort** : S-M. **Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : NOUVEAU (la leçon des 492 fps expliquant les 60 Hz est DÉJÀ-TRANCHÉE, `replay_system.gd:11-21`).

**Comment le vérifier** : `tools/test_rejeu.gd`, `tools/test_prediction_tir.gd` ; accumulateur autour de `record_frame`.

---

### ETA-10 — Petites choses par image, à régler en passant (une ligne chacune)

- `_maj_brouillage` / `BrouillageVue.maj` (`brouillage_vue.gd:189-230`) calcule l'axe (`get()` dynamiques, `projecteur.call` ×2 pour une source dirigée) avant de savoir que `Brouillage.flou(dazzle)` est nul : tester `dazzle <= 0,001` en tête et appeler `eteindre()` (5-10 µs par image).
- `_suivre_du_regard` met à jour la caméra de la vue **non rendue** et réécrit `ignore_rotation`/`rotation` à chaque image (445-460, 473-475) : ne poser qu'au changement de lacet (6-12 µs).
- `_maj_extinction_fusees` copie `bullet_container.get_children()` deux fois par image (4100) : sortir tôt tant qu'aucune `Fusee` n'existe (compteur tenu par `_do_spawn_fusee`).
- Rejeu : ~16 `get_node("Light"/"Flash"/"VisualColored")` par image + 2 Array temporaires (`[[ghost_p1, …], …]`, `["Light", "Flash"]`) + 4 écritures de `shadow_item_cull_mask` (2226-2276) : mettre les références en cache à `_setup_ghosts` ; `_maj_fusees_killcam` reparcourt `bullet_container` à chaque image (3881) pour des `queue_free()` déjà demandés.
- `_gabarit_bloquant` : `load()` + `new()` + `free()` à chaque tentative de pose (3504-3514) : mémoïser le gabarit par slug (aussi dans ETA-05).
- `_accorder_fusees` : `FlareProfile.avancer()` alloue un `Array(2)` par place et par image (`flare_profile.gd:66-84`) : renvoyer deux valeurs par champs.
- `ReplaySystem.record_frame` : le `print("[REPLAY] …")` à la mort vide le journal (`run/flush_stdout_on_print`) : une fois par kill, négligeable.
- `camera_hit_kick` crée un tween par coup reçu (`game_state.gd:422-431`) ; deux coups en < 0,16 s se disputent `cam.zoom` (fonctionnel, signalé).

**Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : NOUVEAU. **Gain** : quelques µs par image chacune.

---

## 3. Ce qui est déjà bien fait (à ne pas casser)

1. **Enregistrement du rejeu à cadence fixe, tampon dimensionné en temps** (`replay_system.gd:11-26`, 60 Hz, 450 = 7,5 s) : la leçon des 492 i/s (killcam tronquée à 0,9 s) est tenue. Même logique pour l'historique de compensation (`POS_HISTORY_WINDOW`, 0,4 s de temps réel, `game_state.gd:252`).
2. **Killcam économe** : les fantômes de joueurs sont pré-bâtis une fois (`_setup_ghosts`, 1689-1725) ; le cadrage est calculé UNE fois (`killcam_cadrage.gd:59-65`, appliqué 2287-2303) ; le relevé ne se redessine que quand sa progression change (`releve_balistique.gd:140-145`, garde `is_equal_approx`) ; l'estampe est construite une fois avec deux tweens (`estampe_de_kill.gd:169-200`) ; les traces de poudre du rejeu réutilisent un pool de `Polygon2D` (`game_state.gd:4008-4021`) ; tout est purgé par la sortie unique `_abort_killcam` (4970-4983).
3. **Rien ne grandit sans borne** : douilles 120, taches 120, éclats 90 avec éviction FIFO ; les taches et éclats n'ont aucun `_process`, les douilles coupent le leur au repos (`bullet_casing.gd:95`) ; journal plafonné à 200 ; `_predicted_shots` borné par un TTL qui suit le RTT (`prediction_tir.gd`).
4. **L'éblouissement ne tire un rayon que si la cible est dans le cône** (2707-2712) ; le flash de tir de même (`pic > 0` avant la ligne de vue, 2866-2869) ; le client ne calcule ni éblouissement, ni réserves, ni extinction (2361, 3126, 3552, 4089) — il reçoit des valeurs répliquées.
5. **Les RPC de `game_state.gd` sont tous événementiels** ; une seule horloge périodique, toutes les 5 s (`TIME_SYNC_INTERVAL`, 267) ; `rpc_start_round` ne porte la carte qu'une fois par manche.
6. **Rendu** : la vue non regardée voit son `render_target_update_mode` coupé (5918-5924), le duel se rend dans la racine en vue unique (`_rendre_dans_la_racine`, 6233-6269) ; le brouillage s'éteint hors manche et cache son `BackBufferCopy` (5864-5866, `brouillage_vue.gd:149-155`).
7. **Caches payés hors action** : `Fusee.prechauffer` (`fusee.gd:343`, textures de volutes en cache statique) ; texture LED des murs mise en cache par clé de grille (`mur_led.gd:210-213`) ; `LightTextures.masque` mémoïsé ; **`ParticlePool` pré-alloué** (240 corps, aucune allocation en partie, `particle_pool.gd:14-17`).
8. **`ConditionsDeMatch` n'alloue rien par image** (`PackedFloat32Array.append`, `Time.get_ticks_usec`) et ses statistiques reprennent celles du banc définition pour définition (`conditions_de_match.gd:25-29`).

---

## 4. Questions ouvertes

1. **Mesure (1 ligne chacune, à confier à l'agent de cadence)** : durée de `_conditions.resume()` et de `MatchRecord.append_to_history` à l'image du kill, journal de 200 entrées, manche de 5 min (ETA-01) ; durée de `ui.update_hud` en duel et en menu (ETA-03) ; première puis deuxième mort dans un même processus, fenêtre au premier plan (ETA-02) ; `rebuild_arena` par sous-étape, froid/chaud, 32² puis 128² (ETA-04).
2. **Aucune mesure existante ne voit les transitoires d'une session réelle** : le banc écarte les 5-12 premières secondes (ROADMAP l. 27710-27714), s'arrête à la mort, et la ROADMAP reconnaît qu'un 1 % bas d'une vingtaine d'images est décidé par quelques hoquets (l. 7318). Faut-il un relevé « première minute d'une session froide, du lancement à la fin du premier match » ?
3. **Adrien** : l'éblouissement à pas fixe (ETA-06.3) quantifie sa réponse à 16,7 ms mais règle la dépendance à la cadence (l. 4514) ; acceptable ? Et l'ordre d'archivage (ETA-01) : avant ou après l'image du kill ?
4. **Adrien / agent iso** : en vue unique, faut-il construire et garder les copies J2 (calques, décor, encre, douilles, taches, éclats) ? Le prix d'un « non » : plus de retour à l'écran scindé sans reconstruire l'arène.
5. **Hors périmètre, signalé** : (a) en menu, `vp1`/`vp2` restent en `UPDATE_ALWAYS` (`main.tscn:35,52` ; `_on_main_menu_requested`, 6464-6466) derrière un menu probablement opaque — plafonné à 120 i/s (`settings_manager.gd:250`), hors cible, mais chauffe et batterie ; (b) `Presentation3D._reconstruire` (posé par `rebuild_arena`, 1572) refait la vue iso à chaque manche — à chiffrer par l'agent iso ; (c) sons chargés à froid (audio) ; (d) `bullet.gd` réalloue un `PackedVector2Array` par balle et par tick ; (e) l'enregistrement du rejeu sous 60 i/s (ETA-09).
6. **Le 1 % bas tient de justesse** (« de deux images par seconde », `CLAUDE.md`) : ETA-03 est le seul constat par image qui puisse se compter en dixièmes de ms ; les autres postes par image (ETA-06 à ETA-10) sont sous le plancher de bruit et ne justifient une intervention que pour l'hygiène ou le déterminisme.
