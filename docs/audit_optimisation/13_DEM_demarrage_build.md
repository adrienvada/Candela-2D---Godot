# Audit DEM — Démarrage, configuration du moteur, mémoire, build et assets

Dépôt `/home/user/Candela-2D---Godot`, commit `52a29c1` (0.8.3 + SOLO S12), audit du 2026-10-04.
Préfixe des constats : **DEM**. Lecture seule ; Godot n'a pas été lancé.

---

## 0. Méthode, limites, étiquettes

**Lu** (fichiers courts en entier, gros fichiers par les fonctions concernées) : `project.godot`, `export_presets.cfg`, `drapeaux_de_lancement.gd`, `.gitignore`,
`.github/workflows/{release,tests}.yml`, `patch_loader.gd`, `input_setup.gd`, `main.tscn`, `default_bus_layout.tres`, `menu_apercu.gd`, les `_ready`/`_init`/`_process`
des dix autoloads du jeu (`update_manager.gd`, `network_manager.gd`, `settings_manager.gd`, `audio_manager.gd`, `map_data.gd`, `matchmaking.gd`, `ranked_identity.gd`,
`replay_system.gd`…) et des dix autoloads EOSG (`runtime.gd`, `heos/hplatform.gd`, `hlog.gd`…), `addons/godot_ai/runtime/{game_helper,game_logger}.gd` et
`export/mcp_export_plugin.gd`. Par tronçons : `game_state.gd` (`_ready`, `rebuild_arena`, `_do_end_round`, `_archive_match_result`, `_accorder_rendu_aux_vues`),
`ui.gd` (`_ready`, `_build_menu`, `show_main_menu`, table `ILLUSTRATIONS`), `fusee.gd`, `iso_nuage_voxel.gd`, `iso_volumes.gd`, `intro_planches.gd`, `conditions_de_match.gd`,
`match_record.gd`, `update_installer.gd`, `update_manifest.gd`. ROADMAP : Phase 9 (l. 2320), « Décisions actées » (l. 2434), « prêt à l'essai » (l. 22331), et les passages cités par numéro de ligne.

**Ce qui sort du dépôt, et pourquoi — à lire avant le reste.** Pour répondre à « qu'est-ce qui part dans le build ? » par une preuve plutôt qu'une lecture de filtres,
j'ai lu **le paquet réellement publié** : la release GitHub publique `v0.8.3` (`Candela-windows.zip` 131 182 481 o, `Candela-macos.zip` 185 337 010 o).
Par requêtes HTTP `Range` : l'annuaire de chaque zip, puis l'entrée `Candela.pck` du zip Windows (84 Mo, 1,8 s de transfert), inflatée en mémoire, dont j'ai
lu l'annuaire (PCK format 4, Godot 4.7.1). Aucun Godot, aucune écriture hors `…/audit/dem_work/`. Cela fait passer plusieurs ESTIMÉ de la mission en PROUVÉ.
Les scripts (`liste_pck.py`, `scan_images.py`, `unref2.py`, `cmapcheck.py`) et les tables (`pck_files.json`, `images.tsv`, `dead_assets.json`) y sont restés.

**Étiquettes.** `[PROUVÉ]` = lu dans le code, dans le paquet publié ou dans un en-tête de fichier. `[ESTIMÉ]` = calcul ou ordre de grandeur, jamais mesuré.
`[NON VÉRIFIÉ]` = dépend de la source du moteur, que je n'ai pas. **Aucun coût en millisecondes de ce rapport n'est une mesure** : je n'ai pu ni lancer le jeu, ni
profiler. Les quantités en octets, elles, sont exactes.

**Chantiers en cours et recoupements.** J'ai lu `CONTEXTE_CHANTIERS_EN_COURS.md` : **aucun constat DEM ne relève du lot OM6 (ni d'OM3/OM4) du chantier OMBRES**, ni de l'audit des
lumières. DEM-08 (le hub rend deux fois le monde 2D) en est voisin sans en être : voir son « Statut ». Les rapports des autres domaines (01-12 et 14), ouverts après coup,
recoupent **dix de mes quatorze constats** — cinq doublons complets (DEM-03, 06, 08, 09, 14) et cinq recoupements partiels (DEM-04, 05, 07, 10, 11). Les quatre autres (**DEM-01, 02, 12, 13**)
sont propres à ce domaine : aucun autre auditeur n'a lu le paquet publié. La table de correspondance, avec les écarts de chiffres, est en **Annexe C**, pour que la consolidation
traite chaque défaut une seule fois.

---

## 1. Carte des chemins chauds (et de ce qui part dans le build)

### 1.1 Anatomie du build 0.8.3 [PROUVÉ]

| Fichier du zip Windows | Sur disque | Zippé | Remarque |
|---|---|---|---|
| `Candela.exe` (modèle d'export officiel 4.7.1) | 109,18 Mo | 38,12 Mo | tous modules du moteur |
| **`Candela.pck`** | **86,39 Mo** | **84,02 Mo** | **incompressible (97 %)** : seul le contenu compte |
| `EOSSDK-Win64-Shipping.dll` | 19,53 Mo | 8,18 Mo | une seule copie |
| `libeosg.windows…release.x86_64.dll`, `xaudio2_9redist.dll` | 1,15 + 0,85 Mo | 0,45 + 0,42 Mo | |
| **Total** | **217 Mo** | **131,18 Mo** | |

| Fichier du zip macOS (`Candela 2D.app`) | Sur disque | Zippé | Remarque |
|---|---|---|---|
| `Contents/MacOS/Candela 2D` (universel x86_64 + arm64) | 169,95 Mo | 59,58 Mo | |
| `Contents/Resources/Candela 2D.pck` | 88,15 Mo | 85,77 Mo | = PCK Windows + `build/macos/Candela 2D.app/Contents/Resources/icon.icns` (1,77 Mo, DEM-02) ; 1 808 entrées contre 1 807 |
| `Frameworks/libeosg…framework/libEOSSDK-Mac-Shipping.dylib` | 48,62 Mo | 18,73 Mo | celle que `libeosg` charge |
| **`Frameworks/libEOSSDK-Mac-Shipping.dylib`** | **48,62 Mo** | **18,76 Mo** | **doublon** (DEM-02) |
| `libeosg…`, `icon.icns` | 2,24 + 1,77 Mo | 0,73 + 1,76 Mo | |
| **Total** | **359 Mo** | **185,34 Mo** | |

Évolution : Windows 50 Mo / macOS 101 Mo à la Phase 9 (ROADMAP l. 2369, v0.2.x) ; 130,96 / 185,13 Mo à la 0.8.0 ; 131,18 / 185,34 Mo à la 0.8.3.
Les releases 0.8.x ne publient **que des bundles complets** (`manifeste.json` : deux paquets `"type": "bundle"`), donc chaque mise à jour retélécharge 131 ou 185 Mo.

Composition du `Candela.pck` Windows (1 807 entrées, 86,39 Mo) :

| Poste | Entrées | Taille | Part |
|---|---|---|---|
| Textures `.ctex` (WebP sans perte) | 361 | 66,25 Mo | 76,7 % |
| Film d'intro `assets/video/intro/intro_a.ogv` (Theora 1920×1080, 30 i/s) | 1 | 9,14 Mo | 10,6 % |
| Audio : 12 Ogg (3,29) + 96 WAV en QOA (`.sample`, 2,49) | 108 | 5,78 Mo | 6,7 % |
| Scripts `.gdc` (jetons binaires compressés) : 173 du jeu (1,46 Mo) + 160 d'addons (1,18 Mo) ; shaders 59 (0,44 Mo) | 333 + 59 | 2,64 + 0,44 Mo | 3,6 % |
| Cartes et salles solo `.json` | 116 | 0,23 Mo | |
| *dont* addons (déjà comptés ci-dessus) : `godot_ai` 1,04 Mo (280 entrées) + EOSG 0,16 Mo (41 entrées) | 321 | 1,19 Mo | 1,4 % |
| Polices, `.import`, `project.binary`, caches de classes | | ~0,4 Mo | |

**Preuves négatives, utiles pour la question 4 :** aucun `.md`, `.html`, `.sql`, `.ts`, `tools/`, `docs/`, `supabase/`, `preview_*.html` dans le PCK ;
`project.binary` liste exactement les 20 autoloads attendus et **ne contient pas `_mcp_game_helper`** ; les binaires EOSG des autres plateformes ne sont pas livrés
(chaque zip ne porte que les siens) ; seul `assets/sources/encre/` (le seul des 25 dossiers de `assets/sources/` sans `.gdignore`) fuit.

### 1.2 Ce qui tourne PAR IMAGE dans ce domaine

| Où | Quoi | Ordre de grandeur |
|---|---|---|
| `addons/epic-online-services-godot/runtime.gd:35` `EOSGRuntime._process` | `IEOS.tick()` natif, **même sans EOS configuré**. Budget SDK posé à la création de la plateforme : `hplatform.gd:107-112`, `floori(300 / max(Engine.max_fps, 60))` = **2 ms** (le plafond des menus vaut 120 à ce moment-là ; 5 ms si le joueur a réglé 60) | plafond 2 ms/image, typiquement quelques µs [ESTIMÉ] |
| `network_manager.gd:967` `_process` | hors ligne : `_remote_peer()` → 0 → `_reset_rtt()` (3 affectations) ; en ligne : un RPC `rpc_ping` par seconde | négligeable |
| `matchmaking.gd:239` `_process` → `tick()` | sortie immédiate si l'état n'est ni SEARCHING, FOUND ni AWAITING_ACCEPT | négligeable |
| `audio_manager.gd:2880` `_process` | deux gardes, `get_tree().root`, `get_viewport()`, `Engine.time_scale` | ~µs |
| `game_state.gd:2081` `_process` | `_conditions.echantillonner()` : un `append` de flottant par image (`conditions_de_match.gd:86-99`) | O(1) |
| `update_manager.gd:322` | éteint (`set_process(false)`) hors téléchargement | 0 |
| `_mcp_game_helper._process` (godot_ai) | **absent de l'export** [PROUVÉ] ; en lancement CLI/éditeur : `Time.get_ticks_msec`, `Engine.get_frames_drawn`, puis `return` si pas de débogueur | ~µs, dev seulement |
| `ui.gd:1456` `UI._process` → `_update_network_status()` | **unique chemin chaud trouvé hors du domaine** : voir DEM-14 | ~0,05 ms [ESTIMÉ] |

**Par tick physique** : aucun `_physics_process` dans les autoloads ni dans les addons (grep). **Par paquet** : seulement `rpc_ping`/`rpc_pong` à 1 Hz (`network_manager.gd:967-1000`) ; le reste du réseau est hors de ce domaine.

Aucun `print()` dans un chemin chaud (§1.6). Aucun `ProjectSettings.get_setting`, `OS.get_environment`, `DrapeauxDeLancement.arguments()` par image :
la vingtaine de sites de `DrapeauxDeLancement` sont soit lus une fois (`menu_artwork.gd:132`, `voxel_catalogue.gd:625`, `mur_led.gd:142`), soit à la création d'un matériau ou d'un nœud.

### 1.3 Ce qui tourne PAR ÉVÉNEMENT

| Événement | Travail synchrone | Réf. |
|---|---|---|
| Entrée/sortie d'arène | `GameSettings.signaler_arene` → `_apply_video()` : `window_set_vsync_mode` + `Engine.max_fps` | `settings_manager.gd:746-751` |
| Début de manche | `rebuild_arena()` : atlas de tuiles 70×70 px (~4 900 `set_pixel`), collisions + occluders, cuisson du décor dans un `SubViewport`, bandeau LED, `Presentation3D` reconstruit | `game_state.gd:1412-1580`, `candela_tileset.gd:69-100` |
| **Coup fatal** | `_archive_match_result` : tri + deux boucles GDScript sur toutes les images de la manche, lecture/analyse/écriture de l'historique (≤ 200 entrées), construction et envoi du rapport HTTP | `game_state.gd:4460` → DEM-06 |
| Première occurrence de `●` / `✓` / `▲▼◀▶` | repli sur une police système | DEM-07 |
| Mise à jour acceptée | SHA-256 de 131–185 Mo + `OS.execute` bloquant | DEM-10 |

### 1.4 Chaîne de démarrage — tout est synchrone sur le fil principal avant le premier écran

Aucun `Thread`, `WorkerThreadPool`, `load_threaded_request` dans le code du jeu (grep : seul `HTTPRequest.use_threads` de `update_manager.gd:144`).

| # | Étape | Coût connu / estimé |
|---|---|---|
| 1 | Moteur, ouverture du PCK (1 807 entrées), `project.binary`, splash `boot.png` 1920×1080 | non mesuré |
| 2 | 20 autoloads, dans l'ordre de `project.godot` ; compilation GDScript de ~82 000 lignes (171 scripts, 3,84 Mo de source) atteintes par les `preload` de `game_state.gd` (16), `presentation_3d.gd` (13), `ui.gd` (9)… ; `eos.gd` seul fait 4 568 lignes | [ESTIMÉ] quelques centaines de ms, jamais mesuré |
| 2a | `PatchLoader._init` (`patch_loader.gd:58-105`) : 2 `file_exists` ; **si un correctif est installé** : SHA-256 de tout le `.pck` à chaque démarrage (`:96`) | 0 aujourd'hui (aucun correctif publié) ; ~10 ms par 4 Mo sinon [ESTIMÉ] |
| 2b | `AudioManager._ready` (`audio_manager.gd:1392`) : 32 lecteurs + 2, charge `main_stream_interactive.tres` (→ 8+ flux Ogg parsés), limiteur, réverbération. **Les SFX ne sont PAS préchargés** : `get_audio_stream` fait `load()` au premier usage (`audio_manager.gd:1505`) | [ESTIMÉ] 20–60 ms ; ~96 chargements de 0,2–1 ms étalés sur les premières parties |
| 2c | `MapData._ready` (`map_data.gd:52`) : lit et décode (RLE) **chaque** carte de `assets/maps/` (6) et de `user://maps/` pour compter les cases | O(nombre de cartes) ; refait à chaque sauvegarde |
| 2d | `NetworkManager._ready` → `_init_eos_async` : attend **une** image, puis `EOS_Initialize` + `EOS_Platform_Create` **synchrones** (`hplatform.gd:74-124, 126-130, 163-167`) | [ESTIMÉ] 50–300 ms, tombe pendant la première seconde du film d'intro au premier lancement |
| 2e | `UpdateManager._ready` : dossier, `HTTPRequest`, nettoyage d'après-installation (3 `stat`) ; 3 s plus tard, `verifier()` (HTTP en fil dédié, signature RSA) | négligeable |
| 2f | `RankedIdentity._ready` (`ranked_identity.gd:130`) : `HTTPRequest` (sans `use_threads`), `_load_config()` (charge `supabase_config.gd`) ; identification HTTPS dès qu'EOS est prêt (`_start_when_eos_ready` `:163`, `_identify` `:195`) ; `Matchmaker._ready` (`matchmaking.gd:202`) : `_bind_backend()` | une requête HTTPS asynchrone ; sa poignée de main TLS tombe sur le fil principal [mécanisme moteur NON VÉRIFIÉ] ; quelques ms [ESTIMÉ] |
| 3 | `main.tscn` : `GameState` + `arena.tscn` + `ui.tscn` ; les deux `SubViewport` démarrent en `UPDATE_ALWAYS` | |
| 4 | `GameState._ready` (`game_state.gd:492`) : catalogue de classes, `rebuild_arena()`, `_setup_players/_ghosts/_particle_pool/_training_target`, **`Fusee.prechauffer`** (`:1565` → 3 textures de 1–4 Mpx), **`Presentation3D.accrocher`** puis `IsoNuageVoxel.prechauffer()` (`iso_volumes.gd:343` → `get_image()` + boucles GDScript) | ROADMAP l. 31324 : « 0,2 à 0,4 s » pour ce dernier |
| 5 | `UI._ready` (`ui.gd:1332`) : HUD, killcam, menu, pause, pick, dialogues, **16 illustrations décodées** (`ui.gd:4600`) | DEM-03 |
| 6 | Intro (premier lancement : film 1080p Theora décodé sur CPU) ou `show_main_menu()` ; musique | |

**1.4 bis — Autres travaux de démarrage, relevés par les rapports des autres domaines** (repris tels quels, **non re-vérifiés ici** : leurs titulaires les ont lus de près ; les durées sont celles de leurs rapports, toutes ESTIMÉES).

| Où | Quoi | Durée estimée par la source | Source |
|---|---|---|---|
| `ui.gd:2457` (`_forger_voile` ×2, `UI._ready`) | `VoileTextures.toutes()` écrit ≈ 164 000 pixels en GDScript (cache statique : une seule fabrication) | 30-65 ms | LUM-13 (04_LUM, puce « Démarrage (froid) ») |
| `presentation_3d.gd:107-114` | cinq shaders « lumière 3D / pâte écran » `preload`és pour un chemin éteint en jeu | ISO-12 : quelques ms à quelques dizaines de ms ; SHA-12 : −10 à −20 ms si retirés | ISO-12 (01_ISO) et SHA-12 (03_SHA, même constat : forks de shaders et `lumieres_iso.gd` préchargés pour rien en production) |
| `UI._ready` → `_build_menu` | ≈ 480 `add_child`, ≈ 230 `.new()`, de l'ordre du millier de nœuds ; 10 `get_image()` d'icônes d'arme ; miniatures de cartes peintes pixel à pixel en GDScript (`MapGallery._ready` → `_rebuild_tiles`) ; `ScreenHistory.build` → 2 `load_history` | 100-400 ms pour tout `UI._ready` (+ ≈ 10 ms de miniatures avec 6 cartes) | HUD-10 (09_HUD), CAR-08 (14_CAR) |
| `rebuild_arena()`, appelé par `GameState._ready` (`game_state.gd:628`) | décodage de la carte répété, atlas du tileset (≈ 4 900 `set_pixel`), décor cuit par `SubViewport` + `get_image()`, image d'usure — payés au lancement **et** à chaque manche | non chiffré au lancement | CAR-03, CAR-05, CAR-06, GEO-02, GEO-03 |

Ces lignes, ajoutées aux miennes (2 à 5), plaident pour DEM-05 : plusieurs postes de démarrage sont estimés par plusieurs auditeurs, et il n'existe **aucune** mesure du total.

**Le temps de démarrage total n'est ni mesuré, ni consigné nulle part** (ROADMAP : aucune occurrence ; `conditions_de_match.gd` ne le porte pas) → DEM-05.

### 1.5 Revue de `project.godot` et des préréglages d'export

| Réglage | Valeur [PROUVÉ] | Verdict |
|---|---|---|
| Moteur de rendu | `renderer/rendering_method="gl_compatibility"` (:176) | décision actée |
| `config/features` | `("4.7", "Forward Plus")` (:16) | balise périmée par rapport à (:176) ; sans effet d'exécution [NON VÉRIFIÉ côté éditeur] — DEM-13 |
| Pilote GL | aucune clé `rendering/gl_compatibility/driver*` ; `application/export_angle=0` (« Auto », `export_presets.cfg:48,313`) ; **aucune bibliothèque ANGLE dans les deux zips** → GL natif de l'OS | question ouverte (Q3) |
| `rendering_device/driver.windows="d3d12"` (:175) | sans objet sous gl_compatibility | inoffensif |
| vsync, `max_fps` | non posés dans `project.godot` ; `GameSettings` : vsync désactivé, plafond `fps_cap`=0 en arène, 120 aux menus, 30 hors focus (`settings_manager.gd:250-251, 723-728, 753-766`) | décision actée (déplafonnement) ; PE3.1 fait |
| `run/flush_stdout_on_print` | `true` (:39) | OK : 56 appels `print*` dans le code du jeu, aucun chaud (§1.6) |
| Physique | `physics_ticks_per_second`, `physics_jitter_fix`, `max_physics_steps_per_frame`, `physics_interpolation` : **non posés** (60 / 0,5 / 8 / off) ; interpolation faite à la main | défauts ; alias 60 Hz / 50–60 i/s à connaître (Q9) |
| `3d/physics_engine="Jolt Physics"` (:171) | **aucun nœud de physique 3D dans le jeu** (grep `Body3D|Area3D|RayCast3D|PhysicsServer3D` : 0 fichier) | DEM-13 |
| Modèle de threads | `rendering/driver/threads/thread_model` non posé (Single-Safe) ; aucun thread dans le jeu | aucun gain attendu à le changer |
| 2D : atlas d'ombres, tampon de lot | `rendering/2d/shadow_atlas/size`, `gl_compatibility/item_buffer_size` non posés (2048 / 16384) ; `shadow_filter = SHADOW_FILTER_NONE` sur toutes les lumières du jeu (`player.gd:815,856,912`, `fusee.gd:224`, `gadget_*`, `plafonnier.gd:253`) | rien de démontré à gagner |
| Atlas d'ombres 3D | `presentation_3d.gd:284` `atlas_ombres := 2048`, ombres 3D éteintes (`:283`) | rien à gagner tant qu'aucune lumière 3D ombrée (allocation paresseuse du moteur : NON VÉRIFIÉ) |
| Filtres de texture | défaut Linear ; aucun `texture_filter` global | RAS |
| Cache de shaders | pas de réglage projet propre à gl_compatibility [NON VÉRIFIÉ] ; `shader_baker/enabled=false` (:50, :294) sans objet sous GL à ma connaissance [NON VÉRIFIÉ] ; compilation au premier dessin documentée et traitée par préchauffages (PE3.5, l. 22503) | |
| `low_processor_usage_mode` | jamais utilisé | **à ne pas introduire** : le hub est animé par `TIME` dans des shaders (`menu_backdrop.gdshader`), le mode ne redessinerait pas sans événement |
| Export | `export_filter="all_resources"` (:12,:270,:341), `exclude_filter="tools/*"` seul (:11,:271,:342), `script_export_mode=2` | DEM-01 ; `script_export_mode` bon |
| macOS | `binary_format/architecture="universal"` (:32), `codesign/identity="-"` | Q5 |
| `textures/vram_compression/import_etc2_astc=true` (:177) | sans effet : 0 texture en VRAM-compressé | inoffensif |

### 1.6 `print()` et journal (question 2) [PROUVÉ]

Sur les 171 scripts de la racine, commentaires exclus : **56 appels** `print`/`printerr`/`print_rich`, **39** `push_warning`, **52** `push_error`. Répartition des `print` :
`network_manager.gd` 16 (connexion, une fois par lien), `iso_volumes.gd` 14 (onze au montage de la présentation, trois gardées par `_masque_annonce`
/ `_forme_imposee_annoncee`, `iso_volumes.gd:1772-1798`), `presentation_3d.gd` 4, `input_setup.gd` 4, `settings_manager.gd` 3 (drapeaux, build debug), `ranked_identity.gd` 3,
`iso_nuage_voxel.gd` 2, `peinture_iso.gd` 2, `replay_system.gd` 2 (`[REPLAY] Px died`, une fois par mort), et 1 chacun pour `audio_manager.gd` (F4), `fusee.gd`, `iso_materiaux.gd`, `mur_led.gd` (F7), `voxel_catalogue.gd`, `ui.gd` (recherche annulée).
**Zéro** dans `player.gd`, `bullet.gd`, `game_state.gd`.
Les `push_error` visent des défauts d'asset ou de données (`player.gd:996,1189`, `blood_stain.gd:406`…) ; les deux seuls appels situés dans une fonction jouée par image
(`game_state.gd:5997-5998`, `presentation_3d.gd:1127`) sont gardés par un drapeau « déjà signalé ». Ordre de grandeur : **~5 à 10 `print` par match**, pas un par image. Le coût du
`flush` à chaque `print` (une écriture de fichier) est donc sans conséquence. Le plugin Epic journalise au niveau WARN (`network_manager.gd:810`).
Restent hors de portée de la lecture : les erreurs **du moteur** en régime normal — voir Q8.

### 1.7 Mémoire résidente et mémoire « d'une soirée » (question 6)

Résident dès le menu, **VRAM estimée à partir des en-têtes de fichiers** [ESTIMÉ] (Apple Silicon : mémoire unifiée) :

| Poste | Taille | Libéré ? | Où |
|---|---|---|---|
| 16 illustrations du hub | **43,6 Mo (RGB8) – 58,2 Mo (RGBA8)** | jamais | `ui.gd:4600`, `menu_apercu.gd:83` — DEM-03 |
| 3 volutes de fusée (1024² + 2×2048²) | **37,8 Mo** | jamais (`Fusee._cache_textures` statique) | `fusee.gd:121,168-173` — DEM-04 |
| `face_mur.png`, `sol.png` (512², mips) | 2,8 Mo | jamais (`preload`) | `iso_materiaux.gd:28,32` |
| `fusee_corps.png` 1456×720 | 4,2 Mo | à la dernière fusée | `fusee.gd:250` |
| Icônes de classes/gadgets, portraits (à la demande) | ~4–8 Mo | jamais | `ui.gd:3259`, `menu_fiche_classe.gd:516` |
| Cookies de torche 1024² (un par classe équipée ; 12 fichiers) | 4,2 Mo par classe jouée, **jusqu'à ~42 Mo** | jamais (`WeaponData._torch_texture`, catalogue persistant) | `weapon_data.gd:231-239` |
| Audio : Ogg parsés en mémoire + 96 `.sample` QOA à l'usage | ~6 Mo | jamais (`_stream_cache`) | `audio_manager.gd:1390` |
| Cibles de rendu : 2 `SubViewport` de 957×1080 (8,3 Mo) + lightmaps iso | non estimé | selon vue | |

Ordre de grandeur : **≈ 90–110 Mo de textures permanentes à froid**, jusqu'à ≈ 150 Mo après avoir joué les dix classes, + cibles de rendu + moteur. **La mémoire n'est pas un problème de ce jeu** : aucune structure non bornée trouvée.
Caches statiques inventoriés (une vingtaine), tous à clés bornées (carte, type de nuage × voxel × côté de caméra, id de texture persistante, chemin) : `MapThumbnail._cache` (`id@px`),
`IsoNuageVoxel._grilles/_mailles/_aplats/_reliefs/_planches/_aplats_flous`, `IsoVolumes._enveloppes/_eventails`, `Charte._ombres`, `MenuIcones._recadrages`, `LightTextures._cache`,
`AventureFormat._cache`… Historique de matchs plafonné (`match_record.gd:93` `HISTORY_MAX=200`) ; tampon de rejeu à 450 images ; traces de manche à plafond par groupe
(`game_state.gd:1381` « les plafonds comptent les groupes »). Un tableau croît sans borne **pendant** une manche : `ConditionsDeMatch._durees` (4 octets par image, ~0,6 Mo
pour 5 min à 500 i/s) — remis à zéro à `commencer()`.
**Il manque une preuve par la mesure** : aucun banc ne rejoue N revanches en lisant `Performance.OBJECT_COUNT`, `OBJECT_ORPHAN_NODE_COUNT`, `MEMORY_STATIC`, `RENDER_VIDEO_MEM_USED`
(les seuls `get_rendering_info`/monitors vivent dans `bench_framerate.gd`, `banc_pics.gd`, `conditions_de_match.gd`). Voir Q2.
**Sur disque, en revanche, une fuite réelle** : DEM-10.

### 1.8 Statistiques d'import des assets (question 5) [PROUVÉ : 465 fichiers `.import` hors `sources/`, 339 images lues par en-tête]

| Sujet | Constat |
|---|---|
| Textures | **355 `CompressedTexture2D`, 355 en `compress/mode=0` (sans perte)** ; aucune lossy, aucune VRAM-compressée (donc `import_etc2_astc` et `texture_format/*` sans objet) ; `process/size_limit=0` partout (aucun plafond de taille) ; `fix_alpha_border=true` ; `detect_3d/compress_to=1` jamais déclenché. 339 images PNG/JPG = 67,1 Mo sur disque, 66,25 Mo de `.ctex` dans le PCK ; **374 Mo de VRAM si tout était résident** (ce n'est pas le cas : §1.7) |
| Mipmaps | 282 sans, **73 avec** : 38 icônes 128², 10 portraits 256², 2 textures iso 512² (sol et face de mur, vues en 3D : utiles), 2 « matière », 1 logo, 16 lettrages morts (DEM-01) et 4 fonds vivants (`fin_victoire`, `fin_defaite`, `fond_hub_iso`, `carte_soiree_fond`) dont les mips (+33 %, ≈ 9 Mo de VRAM si tous chargés) servent à la minification 1920 → 1280 de la fenêtre par défaut : **rien à reprocher** |
| Tailles disproportionnées à l'usage | `ill_intro_allumage.png` 2048×1280 pour un panneau de 1024 (DEM-03) ; `fusee_corps.png` 1456×720 pour 30 px (DEM-04) ; `fusee_volute_2/3.png` 2048² (16,8 Mo de VRAM chacune), les deux plus gros postes de VRAM statique (DEM-04) ; `titres/` 1,2–1,3 k px pour 48 px d'affichage (morts) |
| Sources JPEG | ré-encodées sans perte : ×4,1 (DEM-11) |
| Audio | 96 WAV, **96 en `compress/mode=2` (QOA)** ; 72 stéréo / 24 mono (`force/mono`) ; `force/max_rate=false` (44 100 Hz) ; 12 Ogg à 170 BPM (6 en boucle, 6 non). 17 Mo de sources → **5,78 Mo** dans le PCK. Les SFX positionnels stéréo (72) n'ont pas besoin de deux canaux : au mieux −1 Mo de PCK, sans intérêt |
| Vidéo | `intro_a.ogv` 9,14 Mo, Theora 1920×1080 à 30 i/s (≈ 35 s), joué au premier lancement puis à la demande ; décodage logiciel sur le fil principal [moteur NON VÉRIFIÉ] ; 16 images de repli en plus (DEM-11) |
| Polices | 2 TTF (0,26 Mo), `allow_system_fallback=true`, `preload=[]`, MSDF éteint (DEM-07) |

---

## 2. Constats

### DEM-01 — MAJEUR — 31,75 Mo (36,8 %) du PCK sont des images que le jeu ne lit jamais

**Où** : `export_presets.cfg:11` (+ `:271`, `:342`) `exclude_filter="tools/*"` ; `export_filter="all_resources"` (:12, :270, :341). Liste des 33 fichiers en annexe A.

**Constat** [PROUVÉ] :
```
exclude_filter="tools/*"          # le seul filtre, sur les trois préréglages
```
`all_resources` livre toute image importable qui n'est ni sous `tools/` ni sous un dossier porteur de `.gdignore`. Lu dans le `Candela.pck` v0.8.3 : 33 images **sans aucun lecteur**
dans le code du jeu (recherche hors commentaires de `*.gd *.tscn *.tres *.gdshader project.godot` : ni chemin littéral, ni motif `%s`, ni nom construit ; aucune référence `uid://`
côté `.gd`) y pèsent **31,75 Mo sur 86,39** :

| Groupe | Fichiers | Dans le PCK | Remarque |
|---|---|---|---|
| `assets/ui/titres/` | 17 | 13,41 Mo | lettrages remplacés par le « récitatif » le 2026-09-11 ; seuls des commentaires et `tools/test_menus_finitions.gd` les nomment |
| `assets/ui/fond_armes.png`, `fond_rangs.png`, `fond_telecharger.png` | 3 | 5,41 Mo | aucune mention nulle part |
| `assets/keyart/` (3 key arts) | 3 | 4,52 Mo | `KEY_ART = fond_hub_iso.jpg` (`ui.gd:3984`) ; `keyart_encre`/`rasants` sont cités en commentaire (`ui.gd:3972,3983`) |
| `assets/logos/Wordmark_candela.jpg`, `icone_bootsplash.jpg`, `icone.png` | 3 | 4,79 Mo | `charte.gd:552,560` lit `wordmark.png` et `icone_roman.png`, pas ceux-là |
| `assets/sources/encre/` (seul dossier de `sources/` **sans `.gdignore`**) | 5 | 3,15 Mo | des sources : seul `tools/apercu_traces.gd:105` en lit une |
| `assets/ui/icone_macos.png`, `icone_windows.png` | 2 | 0,48 Mo | faites pour la page de téléchargement (ROADMAP l. 15372), `application/icon=""` dans les préréglages |

Contrôle croisé : `tools/` est bien absent du PCK (le filtre `tools/*` fonctionne, récursivement), ainsi que `docs/`, `preview_*.html`, `supabase/`. Les 24 `.gdignore` de `assets/sources/*` et
`docs/iso/.gdignore` tiennent (90 + 91 Mo hors paquet).

**Coût** : poids de **chaque téléchargement initial et de chaque mise à jour** (bundles complets, PCK incompressible). Aucun coût d'exécution ni de mémoire : ces textures ne sont jamais chargées.

**Proposition** :
1. Sur les trois préréglages :
   `exclude_filter="tools/*, assets/ui/titres/*, assets/keyart/*, assets/ui/fond_armes.png, assets/ui/fond_rangs.png, assets/ui/fond_telecharger.png, assets/ui/icone_macos.png, assets/ui/icone_windows.png, assets/logos/Wordmark_candela.jpg, assets/logos/icone_bootsplash.jpg, assets/logos/icone.png, assets/sources/*, docs/*, supabase/*, build/*, addons/godot_ai/*"`.
   Les entrées qui nomment des images (de `assets/ui/titres/*` à `icone.png`) valent 28,6 Mo ; `assets/sources/*` ferme la fuite de `encre/` (3,15 Mo) et vaut ceinture pour tout futur dossier de sources sans `.gdignore` ; `docs/*`, `supabase/*`, `build/*` ne pèsent rien aujourd'hui (aucun type exportable n'y vit : vérifié) mais empêchent qu'un `.json` ou une image y déposés partent ; `addons/godot_ai/*` est DEM-12 (1,04 Mo). **Pas de `.gdignore` sur `encre/`** : `apercu_traces.gd:105` charge un de ses fichiers par `load()`.
2. Une garde de poids dans `release.yml` après l'export : `godot --export-pack` puis `python3 liste_pck.py Candela.pck --mort '*titre_*,*godot_ai*,*sources/*'` (code retour 1 s'il reste une entrée) et un plafond de taille. Étend la règle de la ROADMAP l. 4697-4700 (« toute image de documentation vit sous un `.gdignore` ») : *toute image que rien ne lit est exclue de l'export*.
3. Optionnel (−0,95 Mo) : `boot.png` et `icone_faisceaux.png` sont livrés **deux fois** (octets bruts, lus par les réglages du projet, et `.ctex` jamais lu) ; `importer="keep"` dans leur `.import` supprime le `.ctex`.

**Gain attendu** : PCK 86,39 → ≈ 54,6 Mo (−36,8 %). Zip Windows ≈ 131,2 → **≈ 100 Mo** ; zip macOS ≈ 185,3 → **≈ 154 Mo** (hors DEM-02).

**Risque** : quasi nul pour le jeu. Les outils qui lisent ces fichiers (`test_menus_finitions`, `apercu_traces`) tournent dans l'éditeur/CLI, pas depuis l'export. Vérifier que `config/icon` (`icone_faisceaux.png`) et `boot.png` ne sont pas exclus. Si Adrien tient à l'un d'eux (« leur suppression est sa décision »), l'exclusion de l'export n'oblige pas à le supprimer du dépôt.

**Effort** : S. **Sévérité** : MAJEUR (poids de chaque mise à jour pour tous les joueurs).

**Statut ROADMAP** : **CONNU-OUVERT** pour les orphelins pris un à un (l. 15265-15281 : trois assets « signalé, pas tranché » ; l. 22326 : `titre_*.png` « leur suppression est sa décision »), et PE3.4 (l. 22497) n'a filtré que `tools/*`. Le poids total dans le paquet, la fuite de `sources/encre/` et le lien avec la taille des mises à jour sont **NOUVEAUX**.

**Comment le vérifier** : ré-exporter ; `python3 liste_pck.py <pck>` (annexe B) ; `gh api repos/adrienvada/Candela-2D---Godot/releases` pour les tailles de zip ; suites headless inchangées.

---

### DEM-02 — MINEUR — macOS : `libEOSSDK-Mac-Shipping.dylib` embarquée deux fois (+18,8 Mo zippés) et `icon.icns` cuit dans le PCK (+1,8 Mo)

**Où** : `.github/workflows/release.yml:215-217` (avant `codesign --force --deep`) ; cause : `addons/epic-online-services-godot/eosg.gdextension` section `[dependencies]`, ligne `macos.release = {"bin/macos/libeosg.macos.template_release.framework/libEOSSDK-Mac-Shipping.dylib": ""}`.

**Constat** [PROUVÉ] : annuaire du zip macOS v0.8.3 :
```
Frameworks/libeosg.macos.template_release.framework/libEOSSDK-Mac-Shipping.dylib   z=18,73 Mo  u=48,62 Mo
Frameworks/libEOSSDK-Mac-Shipping.dylib                                           z=18,76 Mo  u=48,62 Mo
```
L'en-tête Mach-O de `libeosg.macos.template_release` (les deux architectures) déclare `LC_LOAD_DYLIB @loader_path/libEOSSDK-Mac-Shipping.dylib` : la copie utilisée est **celle du dossier du framework**. La copie à la racine de `Frameworks/` vient de la clause `[dependencies]` (cible `""`) et n'est référencée par personne. Le `export_plugin.gd:25` d'EOSG vise un chemin qui n'existe pas (`bin/macos/libEOSSDK-Mac-Shipping.dylib`, la bibliothèque est dans le framework) : sans effet. Côté Windows, la même clause ne duplique rien (une seule `EOSSDK-Win64-Shipping.dll`).

Deuxième trouvaille, même job : le `Candela 2D.pck` macOS contient **une entrée de plus** que le Windows — `build/macos/Candela 2D.app/Contents/Resources/icon.icns` (1,77 Mo) [PROUVÉ : comparaison des deux annuaires, tout le reste est identique à l'octet]. L'export écrit son `.app` **dans l'arbre du projet** (`build/macos/`, `release.yml:210-213`) ; l'icône générée y est indexée comme fichier « autre » (`.icns`) et ramassée par `all_resources`. En CI le dossier est vidé avant l'export, donc seul ce fichier fuit ; sur un poste de dev, un second export dans `build/` ramasserait en plus les restes du précédent (tout fichier d'une extension indexable par le moteur).

**Coût** : ≈ 10 % du zip macOS (dylib) + 1,8 Mo (icns), à chaque mise à jour et chaque installation. Aucun coût d'exécution.

**Proposition** : dans le job `exporter_macos` : (1) `touch build/.gdignore` après le `mkdir -p build/macos` (le moteur n'indexe plus rien sous `build/`, donc plus d'`icon.icns` dans le PCK — ou `build/*` dans `exclude_filter`) ; (2) entre l'export et `codesign --force --deep --sign -` : `rm -f "build/macos/Candela 2D.app/Contents/Frameworks/libEOSSDK-Mac-Shipping.dylib"`. (Alternative à (2) : retirer la ligne `macos.release` de `[dependencies]` dans l'addon — touche un fichier tiers, à refaire à chaque mise à jour du plugin.)

**Gain attendu** : zip macOS −18,76 Mo (dylib) −1,7 Mo (icns) ≈ **−20,5 Mo (−11 %)**, −48,6 Mo installés.

**Risque** : (1) nul. (2) **moyen, et silencieux si faux** — EOS passerait en « Epic : indisponible » sur Mac sans plantage. La preuve par `@loader_path` le rend improbable, mais une vérification fonctionnelle de une minute est obligatoire avant la première release : lancer l'app construite, lire « Epic : connecté » (`NetworkManager.eos_state_label`, `docs/PROTOCOLE_TEST_EOS.md`) ; `codesign --verify --deep --strict` est déjà dans le job.

**Effort** : S. **Sévérité** : MINEUR. **Statut ROADMAP** : **NOUVEAU**.

**Comment le vérifier** : lister le zip (`unzip -l`) ; lancer l'app ; la CI refait `codesign --verify`.

---

### DEM-03 — MINEUR — 16 illustrations du hub (43,6 à 58,2 Mo de VRAM) sont décodées au démarrage et retenues à vie

**Où** : `ui.gd:4599-4600` ; `menu_apercu.gd:77, 81-83` ; table `ui.gd:260-279` ; `menu_hub.gd:405-410`.

**Constat** [PROUVÉ] :
```gdscript
for cle: String in ILLUSTRATIONS.keys():
	hub.register_panel(cle, MenuApercu.new(String(ILLUSTRATIONS[cle])))
...
func _init(chemin: String = "") -> void:  ... if chemin != "": poser(chemin)
func poser(chemin: String) -> void:       if chemin != "" and ResourceLoader.exists(chemin): _image.texture = load(chemin)
func register_panel(key, content): ... _panels[key] = content; _detail_host.add_child(content)
```
18 clés → **16 fichiers distincts** (deux alias), tous décodés (WebP sans perte) et téléversés dans `UI._ready` (→ `_build_menu` `ui.gd:4201` → `_build_hub_screens` `ui.gd:4289`), avant le premier écran, puis tenus par les nœuds du hub pour toute la vie du processus.
Tailles d'après les en-têtes [ESTIMÉ en VRAM] : `fond_hub_iso.jpg` 1920×1071 + mips = 8,2 (RGB8) à 11,0 Mo (RGBA8) ; **`ill_intro_allumage.png` 2048×1280 = 7,9 à 10,5 Mo** ;
14 × 1024×640 = 27,5 à 36,7 Mo ; total 43,6 à 58,2 Mo (le pilote remplit probablement RGB en RGBA sous Metal/ANGLE).
`ill_intro_allumage.png` est quatre fois plus grosse que ses 14 sœurs alors que, depuis le retrait des planches d'intro (`docs/INTRO_PLANCHES.md`, « environ 17 Mo de moins dans chaque téléchargement. Sauf `ill_intro_allumage.png` »), elle ne sert plus que de panneau « rejouer l'intro » : reliquat du passage à 2048 × 1280 pour le plein écran (ROADMAP l. 2502).

**Coût** : mémoire permanente (43,6–58,2 Mo) ; temps de décodage au lancement [ESTIMÉ] 0,1–0,4 s (14 images de 0,65 Mpx + 2 de ~2–2,6 Mpx, sans mesure) ; 1,7 Mo de PCK pour le surdimensionnement.

**Proposition** :
- (a) *Démarrage* : `ResourceLoader.load_threaded_request` des 16 chemins après la première image (la mémoire reste, le lancement s'allège) — ou chargement paresseux au premier affichage.
- (b) *Mémoire* : ne garder que l'illustration courante et la suivante (re-décoder au retour) ; ou ne rien changer si la mesure (F6 `vram_mo`) montre que 50 Mo ne pèsent pas.
- (c) Ramener `ill_intro_allumage.png` à 1024×640 comme les autres : −7,9 à −10,5 Mo de VRAM, −1,7 Mo de PCK (à valider à l'œil, c'est le seul panneau de cette taille).

**Gain attendu** : (a) lancement −0,1 à −0,4 s [ESTIMÉ] ; (b) −44 à −58 Mo résidents ; (c) cf. ci-dessus.

**Risque** : feel du menu — le texte de `ui.gd:245-256` pose que l'image doit arriver **avant** le clic : un chargement paresseux au survol serait un hoquet de menu, d'où le fil dédié. Les bancs et le photographe lisent `MenuApercu.texture()` (`menu_apercu.gd:96`, `menu_hub.gd:806`) : une texture absente à la première image doit rester un cas géré. (c) : changement visuel à faire valider.

**Effort** : S pour (c), M pour (a)+(b). **Sévérité** : MINEUR.

**Statut ROADMAP** : **CONNU-OUVERT** (PE3 point 3, l. 22424-22427 « VRAM et temps de chargement » ; PE3.3, l. 22527, attend `vram_mo`/`textures_mo` avant toute décision d'import). Les chiffres et le mécanisme (chargement eager des panneaux) sont **NOUVEAUX**. **Recoupe** MEN-08 (10_MEN) et HUD-10 (09_HUD) : mêmes 16 fichiers, même mécanisme, mêmes ordres de grandeur (44-58 Mo) ; MEN-08 ajoute le déchargement à l'entrée en match. Ce que DEM-03 apporte en propre : le poids de ces illustrations dans le paquet (PCK) et dans chaque mise à jour.

**Comment le vérifier** : F6 au hub avant/après (`vram_mo`, `textures_mo` — « 0 » veut dire « non mesuré par ce pilote ») ; ligne de démarrage de DEM-05.

---

### DEM-04 — MINEUR — Le préchauffage de la fusée relit le GPU et boucle en GDScript au lancement, et retient 37,8 Mo

**Où** : `fusee.gd:343-345` (`prechauffer` → `_texture_volute`, `:154-173`) ; `iso_nuage_voxel.gd:268-295` (`planche`), `:306-326` (`prechauffer`) ; appelés par `game_state.gd:1565` puis `iso_volumes.gd:343` à la naissance de la présentation iso.

**Constat** [PROUVÉ] : au lancement, avant le premier écran, `Fusee.prechauffer` charge `fusee_volute.png` (1024², repli de la volute 1) + `fusee_volute_2.png` + `fusee_volute_3.png` (2048², 16,8 Mo chacune en RGBA8, sans mips) = **37,8 Mo**, tenues par un `static var` ; puis `IsoNuageVoxel.planche()` les rapatrie du GPU (`tex.get_image()`, `:275`), prémultiplie, réduit (`shrink_x2`) à 256 px, et repasse en GDScript sur 65 536 pixels par planche (`for k in range(0, d.size(), 4)`, `:289-295`) ; plus `aplat()`/`relief()` sur deux sprites de gadget (`:314-318`).

**Coût** : ROADMAP l. 31324-31326 : « une fois par processus, à la naissance de la présentation iso, en **0,2 à 0,4 s** » (mesure déclarée sans machine précisée ; le code imprime sa propre durée, `iso_nuage_voxel.gd:322`). Mémoire : 37,8 Mo jamais relâchés [ESTIMÉ].

**Proposition** : cuire les trois planches de 256 px **hors ligne** (`tools/`, même algorithme) en `fusee_volute_N_256.png`, et faire préférer le fichier cuit par `planche()` (repli : le calcul actuel) → plus de `get_image()` ni de boucle au lancement. Ne pas toucher aux 2048² (les nappes 2D les utilisent ; la ROADMAP l. 22331 « densité de texels » ferme la question de leur taille).

**Dans la même famille** : `fusee_corps.png` fait 1456×720 (4,2 Mo de VRAM, 0,21 Mo de PCK) pour un sprite dessiné à `EMPREINTE_CORPS = 30` px (`fusee.gd:51,256`) : 48× de minification sans mipmaps, donc du scintillement en mouvement en plus du poids. La ROADMAP (l. 22321) le laisse « intact, rien à encrer à cette taille » ; une version de 128 px à mipmaps règlerait poids et crénelage (jugement visuel à Adrien).

**Gain attendu** : lancement −0,2 à −0,4 s [ESTIMÉ, d'après la ROADMAP]. VRAM inchangée (−4,2 Mo avec `fusee_corps`).

**Risque** : identité visuelle de la fumée (la suite `test_fumee_voxel` la garde) ; le moment du préchauffage a été choisi pour éviter « un à-coup pile au moment où l'on pose la fumée » (`iso_nuage_voxel.gd:300-304`) : la cuisson hors ligne conserve ce bénéfice.

**Effort** : M. **Sévérité** : MINEUR. **Statut ROADMAP** : **DÉJÀ-TRANCHÉ** pour le coût (l. 31324-31326, payé au lancement à dessein) ; la cuisson hors ligne est **NOUVELLE**. **Recoupe** GAD-11 (07_GAD : mêmes quatre planches de fusée, ≈ 42 Mo de VRAM, `fusee_corps` 1456×720 pour un sprite de 30 px — leur chiffre est le mien) et, par la même fonction `prechauffer`, GAD-05, GEO-04 et ISO-09 (ce que le préchauffage **ne** couvre **pas** : grilles de cubes, programmes GL) — complémentaires, non redondants : eux regardent ce qui manque au préchauffage, DEM-04 ce qu'il coûte.

**Comment le vérifier** : la ligne `[fumée voxel] préchauffé en N ms` déjà imprimée ; DEM-05.

---

### DEM-05 — MINEUR — Le temps de démarrage n'est ni mesuré ni consigné

**Où** : `game_state.gd:492` (`_ready`), `ui.gd:1332`, `network_manager.gd:793` ; `conditions_de_match.gd:148-176` (`machine()`, dont `"pilote"` :168).

**Constat** [PROUVÉ] : aucun `Time.get_ticks_*` autour de `GameState._ready`, `UI._ready`, `rebuild_arena`, l'initialisation EOS ; `ConditionsDeMatch.machine()` (le bloc F6 et l'historique, envoyé avec le rapport de match) porte `vram_mo`, `textures_mo`, le pilote, la fréquence d'écran — **pas le temps de démarrage**. La ROADMAP n'en contient aucune mesure. Or la chaîne du §1.4 est entièrement synchrone, et ses maillons (DEM-03, DEM-04, EOS, compilation de ~82 000 lignes de GDScript) sont chiffrés au mieux par estimation.

**Coût** : pas un coût d'exécution — un angle mort. Sans le chiffre, on ne peut ni prioriser DEM-03/04 ni voir une régression au fil des versions.

**Proposition** : `Time.get_ticks_msec()` (ms depuis le démarrage du moteur) consigné à quatre points — entrée de `GameState._ready`, après `rebuild_arena()`, fin de `UI._ready`, première image après `show_main_menu()` — plus avant/après `HPlatform.setup_eos_async`. Une ligne `[démarrage] menu prêt à N ms (arène N, UI N, EOS N)` dans le journal (le flush de PE2.4 la garde même après un plantage) et une clé `demarrage_ms` dans `machine()` : les testeurs la renvoient déjà avec leurs rapports (PE2.3).

**Gain attendu** : une base chiffrée sur les machines des testeurs, Windows à GPU intégré compris (H12) ; aucune modification de comportement.

**Risque** : nul (journal). Garde : le schéma du rapport serveur passe par un tamis en liste blanche (`parseConditions`, ROADMAP l. 22472 PE2.3) : une clé de plus est ignorée sans dommage tant que le serveur n'est pas redéployé.

**Effort** : S. **Sévérité** : MINEUR. **Statut ROADMAP** : **NOUVEAU**. **Recoupe** HUD-10 (annexe A, point 4) et MEN-08 (« Vérifier ») qui demandent eux aussi de chronométrer `UI._ready` / `_build_hub_screens` : DEM-05 propose de le faire une fois pour tout le démarrage et de consigner le résultat.

**Comment le vérifier** : la ligne elle-même, première prise sur le Mac d'Adrien (un lancement) ; pas une mesure de cadence.

---

### DEM-06 — MINEUR — Au coup fatal : tri, boucles GDScript et E/S de l'historique dans la même image

**Où** : `game_state.gd:4435` (`_conditions.arreter()`), `:4460` (`_archive_match_result`), `:4733-4771` ; `conditions_de_match.gd:101-146, 148-176` ; `match_record.gd:247-263, 275-286`.

**Constat** [PROUVÉ] : `_do_end_round` appelle, à l'image même de la mort, avant la killcam :
```gdscript
var conditions := _conditions.resume()        # tri + 2 boucles GDScript sur TOUTES les images de la manche
...
MatchRecord.append_to_history(record)         # load_history() + JSON.parse + cap + JSON.stringify("\t") + écriture + renommage
_report_to_ranking(...)                       # corps JSON + HTTPRequest (TLS sur le fil principal, use_threads=false)
```
`statistiques()` fait `durees.duplicate()`, `.sort()`, puis `for v in triees: total += v` et une seconde boucle sur la queue lente ; `resume()` fait encore `for v in _rtt: somme += v; pic = maxf(pic, v)`. Ces boucles sont **O(images de la manche)** : 36 000 images (5 min à 120 i/s) à 150 000 (5 min à 500 i/s).
`_conditions.arreter()` précède l'appel : **ce travail tombe hors du relevé de cadence**, donc invisible dans F6 et dans l'historique.

**Coût** [ESTIMÉ, non mesuré] : `resume()` ≈ 5 ms (36 k images) à 25–35 ms (150 k images, en ligne) ; historique plein (200 entrées, ~300 Ko) ≈ 5–10 ms ; poignée de main TLS du rapport poursuivie dans les images suivantes (un `HTTPRequest` sans `use_threads` : mécanisme du moteur NON VÉRIFIÉ). Total plausible : **10 à 40 ms dans l'image du coup fatal**, qui est aussi celle du gel/ralenti de la killcam. Pas d'effet d'équité (chaque machine l'exécute pour elle-même).

**Proposition** : ne calculer que ce qui est nécessaire à la décision de fin de manche dans cette image ; différer `resume()` + `append_to_history` + rapport d'un délai court (`get_tree().create_timer(0.5)` ou `call_deferred` après le premier cadrage de killcam). Ou rendre `resume()` O(1) : cumuler `somme` et `pire` dans `echantillonner()` (déjà par image) et ne trier que la queue (ou un histogramme à pas fixe).

**Gain attendu** : retirer 10–40 ms de l'image du coup fatal [ESTIMÉ].

**Risque** : l'ordre importe — `_archive_forfeit` doit capturer le mode **avant** `disconnect_from_game()` (`game_state.gd:4861-4870`) ; `dernier_enregistrement` est lu par l'affiche de fin ; un report double du rapport au classement est le piège connu. Si on diffère, capturer les entrées (mode, ids, durée) tout de suite et ne différer que le calcul lourd. Les suites `test_rejeu_journal`, `test_classes` (schéma) et les gardes d'archivage sont à relancer.

**Effort** : S (différer) à M (O(1)). **Sévérité** : MINEUR. **Statut ROADMAP** : **NOUVEAU**. **Recoupe quatre autres constats** : ETA-01 (06_ETA, le titulaire naturel : il possède `_archive_match_result` ; MAJEUR sous réserve de mesure, 10-40 ms, fourchette 3-120), CAR-04 (14_CAR), GAD-10 (07_GAD) et MEN-12 (10_MEN). Mes 10-40 ms sont les leurs ; à traiter **une seule fois**, sous ETA-01. DEM-06 n'apporte aucun fait propre (ETA-01 et CAR-04 notent aussi le rapport HTTP et que `_conditions.arreter()` précède l'archive, donc que ce hoquet est hors de tout relevé de cadence) : en cas de fusion, garder ETA-01 (fourchettes, protocole de mesure sans lancer le jeu) et la proposition de CAR-04 (journal tenu en mémoire, écriture coalescée après le gel).

**Comment le vérifier** : `Time.get_ticks_usec()` avant/après `_archive_match_result`, imprimé une fois par match ; ou `Performance.TIME_PROCESS` à l'image `+0` de la mort.

---

### DEM-07 — MINEUR — Des glyphes absents de la police du jeu (`●`, `✓`, `▲▼◀▶`…) déclenchent un repli sur les polices système à la première occurrence

**Où** : `ui.gd:1736` (`ping_label.text = "● %d ms"`), `game_state.gd:5673` (`"✓ PRÊT"`), `liaisons.gd:94-97` (`▲ ▼ ◀ ▶`), `map_editor_hud.gd` (`✓ ✗ ⚠ ✕ ☐ ▸ ▾ ↗ ↘`) ; `assets/fonts/Oxanium.ttf.import:22`, `BigShouldersDisplay.ttf.import:22`.

**Constat** [PROUVÉ] : j'ai lu la table `cmap` des deux polices et croisé avec tous les littéraux non ASCII du code (67 caractères distincts) : 15 sont absents d'Oxanium (la police de thème, `project.godot:84`), dont `●` U+25CF absent **des deux** polices. Les deux `.import` ont `allow_system_fallback=true` et `preload=[]`. Le voyant de latence est affiché **à chaque image en ligne** (`_update_ping_label`, appelé par `UI._process`). Le mécanisme du repli (énumération/chargement d'une police système la première fois) est celui du moteur [NON VÉRIFIÉ dans sa source].

**Coût** [ESTIMÉ] : un à-coup unique de quelques dizaines de ms (jusqu'à ~100) à la première apparition du voyant de latence, c'est-à-dire dans le salon ou au début du premier match en ligne ; `✓ PRÊT` à la première revanche. Hors ligne : seulement les réglages de touches.

**Proposition** : remplacer `●` par `•` (U+2022, **présent dans les deux polices**, vérifié) — ou dessiner la pastille comme un `ColorRect` — ; idem `✓` par une coche dessinée ou un mot. Garde : étendre `tools/` d'un test qui échoue si un littéral de chaîne du jeu contient un caractère absent de la `cmap` de la police de thème (mon `cmapcheck.py` fait déjà cette vérification en 40 lignes).

**Gain attendu** : supprimer un à-coup unique de première utilisation en ligne [ESTIMÉ].

**Risque** : visuel (forme de la pastille) — à faire valider ; aucun risque de gameplay.

**Effort** : S. **Sévérité** : MINEUR. **Statut ROADMAP** : **NOUVEAU**. **Recoupe** HUD-09 (09_HUD) seulement par la famille « premières fois » (rastérisation des glyphes à la première apparition, icône de gadget) ; le **repli sur les polices système** pour les glyphes absents de la police du jeu n'est vu par aucun autre rapport (recherche de `allow_system_fallback`, « police système », `cmap` dans les rapports 01-12 et 14 : aucune occurrence).

**Comment le vérifier** : `Time.get_ticks_usec()` autour du premier `ping_label.text = …` ; ou comparer la pire image du lobby en ligne avant/après le remplacement.

---

### DEM-08 — MINEUR — Sous le hub, les deux `SubViewport` continuent de rendre le monde 2D à chaque image

**Où** : `game_state.gd:6464` (retour au menu : `vp1.get_parent().show(); vp2…show()`), `:5905-5924` (`_accorder_rendu_aux_vues`), `main.tscn` (`render_target_update_mode = 4`) ; `ui.tscn` (`UI` = `CanvasLayer` couche 10) ; `charte.gd:238` (rideau à 96 %).

**Constat** [PROUVÉ par lecture] : au hub, l'état est « écran scindé » (`current_mode = LOCAL_SPLITSCREEN`) : les deux conteneurs sont visibles, donc `_accorder_rendu_aux_vues` met `UPDATE_ALWAYS` aux deux vues (`vu = conteneur.visible and not _rendu_racine`). Aucun appel du dépôt ne met `UPDATE_DISABLED` « parce qu'on est au menu » (seulement : gel du kill `:4517`, vue masquée `:5923`). Par-dessus, le hub pose un rideau à **96 % d'opacité** (`Charte.PATE_RIDEAU`, alpha 0,96, `charte.gd:238` ; `ui.gd:4160-4161`) et l'illustration du hub ; le monde 2D, hors torches éteintes mais avec les deux halos de proximité des joueurs (voir plus bas), est presque le noir absolu du jeu : ce qui en transparaît est au plus 4 % d'un noir et de deux petites lueurs (la translucidité est voulue, `ui.gd:4226-4230`, mais c'est celle des panneaux, pas celle du monde). La ROADMAP le note sans le compter comme un coût : l. 24347 « le retour au menu remontre les deux vues ; sans garde, la vue iso s'y allumait en écran scindé derrière le hub » — la garde ne protège que l'iso ; et le « relevé des menus » (l. 34276-34291) décrit sa charge comme « la vitrine seule », sans isoler la part des deux vues 2D qui, d'après le code actuel, tournent aussi.

**Coût** [ESTIMÉ] : 2 × (957×1080 px, ~115 à 261 appels de dessin par vue d'après les relevés de la ROADMAP l. 22327, plus les lumières 2D des joueurs et la copie des textures dans la fenêtre) à 120 i/s, pendant tout le temps passé au hub, au salon et en attente d'appariement. Le relevé de 2026-08-18 donne 200 i/s médians soit **5 ms par image de hub** ; la part du monde n'y est pas isolée. Effet thermique plausible sur un portable (le départ de match se fait sur un GPU échauffé : la ROADMAP distingue déjà « Mac chaud » / « Mac froid », l. 27620-27622).

**Ce que les deux vues dessinent au hub** [PROUVÉ par lecture ; répond à la question que MEN-04 laisse ouverte, « je n'ai pas pu établir ce que contient l'arène à cet instant »] : `_on_main_menu_requested` purge l'arène sauf `Ground`, `StaticGeometry`, `SpawnPoints` et `KillcamOverlay` (`game_state.gd:6442-6448`), mais **remet les deux `Player` à leurs points d'apparition sans les sortir de l'arbre** (`:6413-6422`). Chaque `Player` porte un `ambient_light` **à ombre** (`shadow_enabled = true`, énergie 0,8, `player.gd:909-917`) que rien ne coupe : dans les scripts de la racine, seuls `player.gd:901-917` (création) et `:1601` (bit du masque d'ombre) le touchent — `enabled` et `visible` ne sont jamais écrits. Avec la règle du moteur relevée par l'audit des lumières (`CONTEXTE_CHANTIERS_EN_COURS.md` §1 : la carte d'ombre d'une lumière à ombres est recalculée **pour chaque viewport** que son rectangle touche, et ces passes n'apparaissent pas dans le compteur d'appels de dessin), cela fait, par lecture, **jusqu'à 2 halos × 2 vues = 4 passes d'ombre par image de hub**, en plus du sol et des murs. Leur prix dépend du nombre d'occulteurs de la carte (modèle `4 × N × L` par viewport de LUM-03) et **n'est pas chiffré ici**. Les torches, elles, sont éteintes au lancement (`flashlight_on = false`, `player.gd:320` ; après un match, non vérifié). La même chose vaut pendant le film d'intro et le `PowerOn` (MEN-04).

**Proposition** : mettre les deux vues en `UPDATE_DISABLED` tant que ni manche, ni entraînement, ni killcam, ni écran de fin n'ont besoin du monde (`en_arene` existe déjà : `game_state.gd:2086`), et les rallumer dans l'accord de rendu appelé au départ de manche.

**Gain attendu** : une part des ~5 ms d'une image de hub [ESTIMÉ, à isoler par la mesure ci-dessous] ; moins de chaleur avant les matchs.

**Risque** : moyen. `_accorder_rendu_aux_vues` est un point sensible de ce dépôt (pièges de l'oreille doublée, du rendu racine, de la killcam : ROADMAP l. 6590-6625) ; la première image après réactivation d'un `SubViewport` doit être vérifiée (texture périmée visible 1 image ?). Visuel : jusqu'à 4 % du monde transparaît aujourd'hui à travers le rideau — presque nul dans le noir du jeu, mais les deux halos de proximité sont de la lumière : à confirmer sur la planche de contact du photographe (`run_photos.sh`, plans de menus) que rien ne se devine, avant de les geler. `tools/test_rendu_racine.gd` contrôle les `update_mode` et devra être adapté. Le chantier appartient au propriétaire de `game_state.gd`.

**Effort** : M. **Sévérité** : MINEUR. **Statut ROADMAP** : **NOUVEAU** (décrit l. 24347, jamais chiffré ni remis en cause). **Recoupe** MEN-04 (10_MEN, qui le juge « candidat n° 1 du coût du menu ») et ISO-07 (01_ISO) : trois auditeurs, un seul défaut, trois estimations non mesurées (0,3-3 ms pour MEN-04, ~3 ms pour ISO-07, « une part des ~5 ms » ici). **Ne recoupe pas OM6** : le lot « alléger » du chantier OMBRES vise les capteurs, les halos sans récepteur et les murs **en manche** ; il en est voisin (si OM6 retire l'ombre du halo ambiant d'un joueur dont personne ne reçoit la lumière, le reliquat du hub baisse d'autant), d'où un point à coordonner avec la session OMBRES, non à trancher ici.

**Comment le vérifier** : `bench_framerate.tscn -- --menus` imprime déjà appels de dessin/objets/primitives par image : les lire tels quels, puis avec `vp1/vp2.render_target_update_mode = DISABLED` posé après `show_main_menu()` ; l'écart de médiane et de compteurs est la réponse. Aucune mesure de duel nécessaire (ni sur le Mac d'Adrien : le banc tourne en CLI). Réserve de MEN-09 : ce banc ne traverse plus les écrans du hub (identifiants périmés) — sans effet ici, puisqu'on compare le hub **au repos**. Preuve possible dans le cloud, sans le Mac : les compteurs d'appels de dessin et de primitives sont indépendants du matériel, et un temps CPU par image à pas fixe (`--fixed-fps 60`, `tools/cadence_cloud/`) donne l'ordre de grandeur relatif avant/après, sous llvmpipe.

---

### DEM-09 — MINEUR — Plafond des menus à 120 i/s quel que soit l'écran (un 60 Hz rend deux fois ce qu'il montre)

**Où** : `settings_manager.gd:250` `const PLAFOND_MENU := 120`, `:251`, `:753-759` `plafond_effectif()`.

**Constat** [PROUVÉ] : le plafond hors arène est une constante ; la fréquence réelle de l'écran n'est lue que pour le diagnostic (`conditions_de_match.gd:171`). Sur l'écran 60 Hz de référence (« MacBook M3, écran interne 60 Hz », ROADMAP l. 2466), le hub est rendu à 120 i/s avec la vsync coupée (`vsync_enabled := false`, `settings_manager.gd:68`) : une image sur deux n'est jamais montrée, et le déchirement est possible. La ROADMAP l. 22494 le dit elle-même : « ces deux nombres sont des **valeurs de départ**, pas des décisions ».

**Coût** [ESTIMÉ] : GPU/CPU du hub × 2 sur un écran 60 Hz.

**Proposition** : `PLAFOND_MENU = maxi(60, roundi(DisplayServer.screen_get_refresh_rate()))` (repli 120 si −1/NaN, `hz_fini` existe), relu à `NOTIFICATION_APPLICATION_FOCUS_IN` (changement d'écran). Ne **pas** basculer la vsync au passage hub → arène : changer le swap interval au départ du match risque un hoquet sur certains pilotes Windows.

**Gain attendu** : −50 % d'images rendues au hub sur un écran 60 Hz ; l'écran 120/144 Hz est mieux servi (la valeur 120 sous-échantillonne un 144).

**Risque** : aucun pour le jeu ; le ressenti du curseur de menu à 60 i/s sur écran 60 Hz est celui du système.

**Effort** : S. **Sévérité** : MINEUR. **Statut ROADMAP** : **CONNU-OUVERT** (PE3.1, l. 22487-22496, valeurs de départ). **Recoupe** MEN-05 (10_MEN) : même constat mot pour mot, même proposition ; MEN-05 y ajoute un palier d'inactivité à 30 i/s après ≈ 10 s sans geste, que DEM-09 ne propose pas (à instruire avec la décision d'Adrien sur la vsync au menu).

**Comment le vérifier** : F3 au hub (le banc `--menus` pose `pilotage_externe` et **n'applique pas** ce plafond : `settings_manager.gd:727`).

---

### DEM-10 — MINEUR — Mise à jour : l'archive téléchargée n'est jamais supprimée (131–185 Mo laissés par mise à jour), et SHA-256 + décompression bloquent le fil principal

**Où** : `update_manager.gd:273-279, 295-296, 308-312, 336-352` ; `update_manifest.gd:353-354` ; `update_installer.gd:179-198` (`_decompresser`), `:411-415` (`nettoyer_apres_installation`).

**Constat** [PROUVÉ] :
(1) `_archive := user://maj/candela-<version>.zip`. Les seuls `remove_absolute(_archive)` sont : avant de retélécharger **le même nom** (`:276-277`) et sur empreinte invalide (`:296`). Après un `installer()` réussi (bundle), ni `appliquer_bundle`, ni le script d'échange (`update_installer.gd` : seulement `rm -rf "$ANCIEN"`, `mv`), ni `nettoyer_apres_installation` (qui ne traite que `.ancien` et le dossier d'étape) ne touchent au zip. Il reste donc dans `user://maj/` **131 Mo (Windows) ou 185 Mo (macOS) par version installée**, pour toujours. Rien dans `docs/MISE_A_JOUR.md` ne le dit.
(2) `UpdateManifest.empreinte_fichier` = `FileAccess.get_sha256(chemin)` sur l'archive entière ; `_decompresser` = `OS.execute("/usr/bin/ditto"|"tar.exe", …, blocking=true)` : fil principal, fenêtre sans pompe d'événements pendant toute la durée.

**Coût** : (1) disque, 131–185 Mo par mise à jour chez chaque joueur. (2) [ESTIMÉ] hachage 0,3–1 s ; extraction 3–15 s (Windows : écran « ne répond pas » après 5 s) ; ∝ taille du bundle, donc multipliée par 2,6 (Windows) depuis la Phase 9 (50 → 131 Mo).

**Proposition** : (1) supprimer l'archive dès que `preparer_bundle` a réussi (le dossier d'étape porte tout), et balayer `user://maj/candela-*.zip` au démarrage dans `UpdateManager._ready` à côté de `nettoyer_apres_installation` (les correctifs `.pck` vivent dans `user://maj/correctifs`, à ne pas toucher) ; (2) hachage et décompression dans un `Thread`/`WorkerThreadPool` avec `await` sur un signal, ou `OS.execute_with_pipe` + sondage.

**Gain attendu** : (1) 131–185 Mo récupérés par mise à jour ; (2) interface vivante pendant l'installation.

**Risque** : le système de mise à jour est « ÉPROUVÉ SUR MACHINE RÉELLE » (Phase 9) et délicat : `tools/test_mise_a_jour.gd` (110 contrôles) doit passer, et un essai d'échange complet sur un poste réel reste le jalon. Supprimer l'archive avant l'échange n'a aucun effet sur celui-ci (le script utilise le dossier d'étape `_neuf`).

**Effort** : S pour (1), M pour (2). **Sévérité** : MINEUR. **Statut ROADMAP** : **NOUVEAU**. **Recoupe** RES-10 (08_RES) pour la seule partie « SHA-256 + extraction bloquants sur le fil principal » (RES-10 la juge ANECDOTIQUE : rare, volontaire, hors match, et propose le même fil de travail). Ce que RES-10 ne voit pas : l'archive jamais supprimée (131-185 Mo laissés à chaque mise à jour chez chaque joueur).

**Comment le vérifier** : `dir "%APPDATA%\Godot\app_userdata\Candela 2D\maj"` (Windows) ou `~/Library/Application Support/Godot/app_userdata/Candela 2D/maj` après une mise à jour ; `test_mise_a_jour`.

---

### DEM-11 — MINEUR — Les sources JPEG sont ré-encodées sans perte : ×4 en moyenne dans le PCK (et un repli d'intro de 6,9 Mo que rien n'exige)

**Où** : `assets/ui/fin_victoire.jpg.import:18` (`compress/mode=0`), idem `fin_defaite`, `fond_hub_iso`, `assets/ui/intro/intro_a_p02…p17.jpg.import` ; `intro_planches.gd:50-72, 105-115`.

**Constat** [PROUVÉ] : les 355 textures sont en `compress/mode=0` (sans perte), aucune en VRAM-compressé ni en lossy (96 WAV en `mode=2`/QOA, 12 Ogg). Pour les sources **JPEG vivantes** : 2,51 Mo de `.jpg` deviennent **10,31 Mo de `.ctex`** (×4,1) dans le PCK : `fin_victoire` 0,47 → 1,73 Mo, `fin_defaite` 0,24 → 0,90, `fond_hub_iso` 0,14 → 0,79, les 16 images de repli de l'intro 1,6 → 6,9 Mo. Un JPEG ré-encodé sans perte garde ses artefacts et perd sa compacité. Quant au **repli de l'intro** (seize `intro_a_pNN.jpg`, 6,9 Mo de PCK), il ne joue que « quand le film manque » (`intro_planches.gd:20-24`) ; le film Theora est lisible sur toutes les plateformes visées.

**Coût** : poids de téléchargement (≈ 7,8 Mo d'excédent) ; VRAM inchangée (le décodage donne la même image).

**Proposition** : `compress/mode=1` (lossy, qualité ≥ 0,9) sur les sources JPEG (`fin_*`, `fond_hub_iso`, `intro_a_p*`) → ≈ la taille du JPG ; et/ou exclure le repli d'intro de l'export (−6,9 Mo) si Adrien accepte qu'une installation sans film ouvre sur le menu (`disponible()` le gère déjà : « jamais vingt-cinq secondes de noir »).

**Gain attendu** : −6 à −7,8 Mo de PCK [ESTIMÉ].

**Risque** : visuel (WebP lossy sur de l'encre en traits : à juger sur `fin_*` et le hub) ; **ne pas** étendre aux PNG d'illustration (le WebP sans perte est déjà plus petit que leur PNG : 0,71–0,81 contre 1,0–1,1 Mo). C'est la nuance de PE3.3 (l. 22527) : une décision d'import, pas une retouche par fichier.

**Effort** : S. **Sévérité** : MINEUR. **Statut ROADMAP** : **NOUVEAU** (PE3 point 3, l. 22424, parle de VRAM, pas du poids du paquet). **Recoupe** MEN-07 (10_MEN) par le même fichier : `fin_victoire`/`fin_defaite` sont décodés sans perte avec mipmaps à CHAQUE fin de match (20-60 ms estimés) ; DEM-11 traite leur poids dans le paquet, MEN-07 leur décodage — les deux correctifs se composent (un `compress/mode=1` ne dispense pas de précharger). Voir aussi MEN-14 pour le film d'intro (1080p Theora, 9,1 Mo).

**Comment le vérifier** : `liste_pck.py` avant/après ; comparer à l'œil `fin_victoire` / `fond_hub_iso` au hub et à l'affiche de fin.

---

### DEM-12 — ANECDOTIQUE — `addons/godot_ai` voyage dans chaque build (1,04 Mo, 280 entrées) ; la ROADMAP se trompe sur son autoload

**Où** : `export_presets.cfg:11` ; `addons/godot_ai/export/mcp_export_plugin.gd:42-53` ; `docs/ROADMAP.md:7659-7661`.

**Constat** [PROUVÉ] : le plugin porte son propre `EditorExportPlugin` qui efface `autoload/_mcp_game_helper` des réglages cuits dans `project.binary` (lancé même en `--headless --export-*`, `plugin.gd:258-263`). Vérifié dans le `project.binary` publié (10 424 o) : 20 autoloads, **pas de `_mcp_game_helper`**. La ROADMAP écrit « son autoload `_mcp_game_helper` tourne dans le processus du jeu, mais il reste inerte sans débogueur branché » : faux pour l'export (il n'y est pas), vrai seulement pour les lancements CLI/éditeur. Le code reste dans le PCK (`addons/godot_ai/**`, 140 scripts + 140 `.remap`, 1,04 Mo).
Pour mémoire, dans un lancement CLI (`godot --path .`, bancs), l'autoload existe et `game_logger.gd:90-96` accumule chaque ligne de journal dans `_pending` que `game_helper.gd:158-165` ne vide **que si** `EngineDebugger.is_active()` : sans débogueur, la liste ne se vide jamais (quelques octets par ligne ; sans conséquence réelle vu §1.6).

**Proposition** : ajouter `addons/godot_ai/*` à `exclude_filter` (le commentaire du plugin, `mcp_export_plugin.gd:6-10`, prévoit exactement ce cas depuis que l'autoload est retiré de l'export) ; corriger la phrase de la ROADMAP.

**Gain attendu** : −1,04 Mo de PCK. **Risque** : nul tant que le plugin d'export est activé (`[editor_plugins]`, `project.godot:80`) ; si on le désactivait, l'autoload resterait déclaré et le jeu logguerait « Failed to instantiate an autoload » à chaque lancement.

**Effort** : S. **Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : **NOUVEAU** (corrige l. 7659).

**Comment le vérifier** : `liste_pck.py --mort '*godot_ai*'`.

---

### DEM-13 — ANECDOTIQUE — Réglages moteur laissés au défaut : Jolt 3D inutilisé, balise « Forward Plus » périmée, pilote GL jamais comparé

**Où** : `project.godot:16, 171, 175-177`.

**Constat** [PROUVÉ] : `3d/physics_engine="Jolt Physics"` alors que le jeu n'a aucun nœud de physique 3D (le monde 3D iso est du rendu pur) ; `config/features` annonce « Forward Plus » pour un projet gl_compatibility ; `rendering_device/driver.windows="d3d12"` n'a pas d'objet sous GL ; `textures/vram_compression/import_etc2_astc=true` n'a pas d'objet (0 texture VRAM-compressée). Le serveur 3D tourne à vide à chaque pas physique (60 Hz) [coût ESTIMÉ ~µs, négligeable].

**Proposition** : rien d'urgent. Si on touche à `project.godot` un jour : mettre `GodotPhysics3D`/« Dummy » après avoir lu `Performance.TIME_PHYSICS_PROCESS` ; régénérer `config/features`. Le vrai levier de cette ligne est la **question du pilote GL** (Q3), pas ces détails.

**Gain attendu** : ≈ 0. **Risque** : changer de moteur 3D peut perturber l'import (les `.import` ne dépendent pas du moteur physique). **Effort** : S. **Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : **NOUVEAU**.

**Comment le vérifier** : monitor `TIME_PHYSICS_PROCESS` avant/après sur un banc de 30 s.

---

### DEM-14 — ANECDOTIQUE — [hors domaine, trouvé en passant : à router vers l'agent UI/HUD] `UI._process` repose des surcharges de thème à chaque image

**Où** : `ui.gd:1451-1456` (`_process` → `_update_network_status()`), `:1635-1661`, `:1724-1738` (`_update_ping_label`).

**Constat** [PROUVÉ] : `_update_network_status()` tourne à chaque image, hors ligne comprise, et pose sans garde de changement `network_status_label.add_theme_color_override("font_color", tint)` (`:1652`) ; en ligne, `_update_ping_label()` refait en plus `ping_label.text = "● %d ms" % rtt` (une chaîne formatée), `add_theme_color_override` et `show()` (`:1736-1738`). `Label.text` ne fait rien si le texte est identique ; `add_theme_color_override`, lui, notifie un changement de thème à chaque appel (invalidation du cache de thème, nouveau façonnage du texte au dessin suivant) [mécanisme du moteur NON VÉRIFIÉ].

**Coût** : [ESTIMÉ] ~0,05 ms/image en ligne (deux libellés), quelques µs hors ligne ; à 300 i/s, 1,5 % d'un cœur.

**Proposition** : ne poser la couleur que si la teinte change (mémoriser la dernière `tint` par libellé) ; formater le texte seulement si `rtt` a changé.

**Gain attendu** : ~0,05 ms/image. **Risque** : nul. **Effort** : S. **Sévérité** : ANECDOTIQUE. **Statut ROADMAP** : **NOUVEAU**. **Doublon complet** de MEN-11 (10_MEN, qui cite le même `ping_label.text = "● %d ms"` + `add_theme_color_override`) et de la ligne 2a de la carte de 09_HUD (`_update_network_status`, ui.gd:1635-1661 et 1724-1738 : « 2 couleurs override/image »), puis de HUD-02, ETA-03 et GAD-08 pour la famille « surcharges de thème réécrites à chaque image » : à écarter au profit de HUD-02, titulaire du domaine.

**Comment le vérifier** : compter les `NOTIFICATION_THEME_CHANGED` d'un `ping_label` sur 10 s (une sous-classe de test), ou le moniteur `TIME_PROCESS` en ligne avant/après.

---

## 3. Ce qui est déjà bien fait

1. **Le filtre `tools/*` et les `.gdignore` fonctionnent** — vérifié sur le paquet publié : ni `tools/`, ni `docs/`, ni les 90 Mo de `assets/sources/*` (24 dossiers sur 25), ni les 91 Mo de `docs/iso`, ni `preview_*.html`, ni `supabase/` ne partent. Les binaires EOSG iOS/Android sont même hors du dépôt (`.gitignore:12-13`), et chaque zip ne porte que ses propres bibliothèques EOS.
2. **L'autoload du pont MCP est bel et bien retiré de l'export** par le plugin (`project.binary` : 20 autoloads attendus, pas de `_mcp_game_helper`) ; l'ordre des autoloads critiques (`PatchLoader` en tête, `GameSettings` après `InputSetup`) est gardé par un test (`tools/test_autoloads.gd`).
3. **L'audio est compact et en flux** : 96 WAV en QOA + 12 Ogg = 17 Mo sources → 5,78 Mo dans le PCK ; musique interactive à 4 couches en flux ; aucune décompression préalable.
4. **Les scripts sont livrés en jetons binaires compressés** (`script_export_mode=2`) : 82 000 lignes → 2,64 Mo.
5. **Aucun `print()` en chemin chaud**, drapeaux « déjà annoncé » sur les rapports de montage, `push_error` réservés aux défauts d'asset ; `run/flush_stdout_on_print=true` ne coûte donc rien (§1.6).
6. **Les caches de session sont tous bornés** (clé = carte, type, id de texture, chemin), l'historique de matchs plafonné à 200, le tampon de rejeu à 450 images, les traces plafonnées par groupe : aucun accroissement non borné trouvé en lisant le code.
7. **Les coûts de première utilisation sont payés avant l'action** (`Fusee.prechauffer`, `IsoNuageVoxel.prechauffer`, shaders du joueur préchargés) ; la doctrine « un `Shader.new()` à la volée compile au premier mort » est respectée.
8. **Le régime de cadence hors arène (PE3.1)** est là : plafonds de 120 (menus) et 30 (hors focus) ; jamais en arène ; les bancs désactivent le plafond via `pilotage_externe`. Les mises à jour partent en fil dédié (`use_threads = true`) avec `_process` éteint hors téléchargement.

---

## 4. Questions ouvertes — ce que seule une mesure, ou Adrien, peut trancher

- **Q1 — Temps de démarrage réel** (Mac, Windows à GPU intégré H12) et sa décomposition : DEM-05 donne l'outil ; EOS (`EOS_Initialize` + `EOS_Platform_Create` synchrones à l'image 2, pendant la première seconde du film d'intro) est le suspect n°1 à chiffrer, avant DEM-03/DEM-04.
- **Q2 — Mémoire d'une soirée** : un banc « N revanches de suite » lisant `OBJECT_COUNT`, `OBJECT_ORPHAN_NODE_COUNT`, `MEMORY_STATIC`, `RENDER_VIDEO_MEM_USED`, `RENDER_TEXTURE_MEM_USED` à chaque départ de manche (la lecture du code ne trouve pas de fuite, mais n'en est pas la preuve). Et F6 au hub pour fixer les ~90–110 Mo estimés.
- **Q3 — Pilote GL : natif contre ANGLE.** Aucun zip n'embarque ANGLE : macOS et Windows tournent sur le GL natif de l'OS (sur Windows, le pilote OpenGL des GPU Intel intégrés est le cas à surveiller : à confirmer par H12). Un essai se fait en une ligne (`--rendering-driver opengl3_angle`, si le binaire d'éditeur embarque ANGLE : NON VÉRIFIÉ), et F6 dit lequel tourne (`conditions_de_match.gd:168` « pilote »). Adrien a abandonné les mesures sur son Mac (ROADMAP l. 2467) et écarté « Metal » pour l'instant (l. 2487) : à proposer avec H12 sur un poste Windows, pas au Mac.
- **Q4 — Coût énergétique et thermique du déplafonnement** (décision actée, non contestée) : fps de 300–500 en arène légère (entraînement, salon), ventilateurs, et surtout *throttling* — un GPU échauffé avant le match rend le « 1 % bas ≥ 60 » plus dur (ROADMAP l. 27620-27622). Une question à Adrien, pas un constat : un plafond logiciel très haut (par exemple 240 ou 2 × la fréquence de l'écran) en arène garderait l'avantage de latence EOS (R5) sans la course à 500 i/s.
- **Q5 — macOS universel contre arm64 seul** : le binaire universel pèse 170 Mo (59,6 zippés) ; arm64 seul retirerait ≈ 30 Mo zippés [ESTIMÉ] mais exclurait les Mac Intel. Décision produit.
- **Q6 — Bundles complets contre patchs `.pck`** : le chemin « correctif léger » existe (Phase 9, ROADMAP l. 2335 « quatre mégaoctets ») mais les releases 0.8.x publient uniquement des bundles de 131/185 Mo (`manifeste.json`). Après DEM-01/02 : ≈ 100 / 134 Mo. Un `.pck` complet seul ferait encore ≈ 55 Mo ; un patch ne portant que les fichiers changés, quelques Mo (limites : pas de nouvel autoload, pas de moteur ni d'EOS, `patch_loader.gd:22-27`). Le moteur propose aussi des patchs à deltas (`patch_delta_encoding`, préréglages `:16-19`) [NON VÉRIFIÉ dans sa mise en œuvre].
- **Q7 — Garder le film (9,14 Mo) et son repli (6,9 Mo)** dans le paquet ? (DEM-11). Et la nuance de qualité JPEG → WebP lossy : jugement à l'œil d'Adrien.
- **Q8 — Les erreurs du moteur en régime normal** : chaque ligne d'erreur est écrite et vidée (`flush`) ; un `godot.log` après une soirée, trié (`sort | uniq -c | sort -rn | head`), montrerait immédiatement une erreur répétée à chaque image. Seul le journal d'une vraie machine le sait.
- **Q9 — Alias 60 Hz de physique contre 50–60 i/s** : à 50 i/s, une image sur cinq joue deux pas de physique (60 pas pour 50 images) : elles coûtent un pas de plus et sont candidates au 1 % bas. Lire `Engine.get_physics_frames()` par image (ou `TIME_PHYSICS_PROCESS`) sur un duel suffirait à voir si c'est lui.
- **Q10 — Compression VRAM des grands aplats** (BPTC/S3TC/ASTC) contre le sans-perte : décision d'import qui dépend de la direction artistique (traits d'encre) et du support BPTC/ASTC du pilote GL d'Apple [NON VÉRIFIÉ]. DEM-01 et DEM-03 en retirent d'abord l'essentiel sans toucher au rendu.
- **Q11 — Modèle d'export maison** : `Candela.exe` pèse 109 Mo (38 zippés), le binaire macOS 170 Mo (60 zippés) — le modèle officiel, tous modules. Retirer ceux que le jeu n'emploie pas (XR, navigation 3D, physique 3D, WebRTC/WebSocket, CSG, GridMap…) rendrait sans doute un quart à un tiers de ces binaires [ESTIMÉ, tailles de modules non vérifiées], au prix de compiler le moteur dans la CI pour trois plateformes à chaque version de Godot. Pas recommandé tant que DEM-01/02 ne sont pas faits ; à garder en tête si le poids des mises à jour devient un frein pour les testeurs.

---

## Annexe A — Les 33 images sans lecteur (octets dans le PCK / octets source)

```
ui/titres (17)   : tampon_fatal 0,05/0,06 · titre_accueil 1,03/0,84 · titre_amical_en_ligne 0,86/0,71 · titre_amical_local 0,79/0,71 · titre_en_ligne_amical 0,69/0,57
                   titre_en_ligne_competitif 0,73/0,61 · titre_entrainement 0,95/0,75 · titre_local_hote 0,62/0,45 · titre_local_invite 1,11/0,77 · titre_mise_a_jour 0,73/0,57
                   titre_personnalisation 1,42/1,33 · titre_salon_hote 0,62/0,45 · titre_salon_invite 1,11/0,77 · titre_salon_local 0,97/0,83
                   verdict_defaite 0,73/0,57 · verdict_egalite 0,10/0,08 · verdict_victoire 0,91/0,82                                     = 13,41 Mo
ui/ (5)          : fond_armes 1,96/3,14 · fond_rangs 1,97/3,08 · fond_telecharger 1,48/2,52 · icone_macos 0,22/0,33 · icone_windows 0,26/0,38      =  5,88 Mo
keyart/ (3)      : keyart_convergents 1,55/2,25 · keyart_encre 1,47/2,54 · keyart_rasants 1,49/2,18                                            =  4,52 Mo
logos/ (3)       : Wordmark_candela.jpg 2,23/1,57 · icone_bootsplash.jpg 1,95/1,23 · icone.png 0,61/0,96                                         =  4,79 Mo
sources/encre/(5): flash_amorce 0,50/0,76 · flash_dissipation 0,92/1,51 · flash_epanouissement 0,80/1,27 · impacts_encre 0,90/1,28
                   gadget_nappe_braises_source 0,03/0,04                                                                                         =  3,15 Mo
TOTAL 33 fichiers : 31,75 Mo dans le PCK (36,8 %), 35,95 Mo de sources
```
Méthode : `unref2.py` (recherche des chemins, motifs `%s`/`%d` et noms courts dans les seuls littéraux de chaîne hors commentaires de `*.gd`, plus `*.tscn *.tres *.gdshader project.godot`), puis recoupement avec les `.ctex` du PCK.
Un faux positif connu de l'outil : `assets/ui/intro/intro_a_p13.jpg` (apostrophe dans « la main s'ouvre » qui casse l'extraction de chaînes) — **lu**, donc exclu de la liste.

## Annexe B — Relire le paquet publié (aucun Godot)

```bash
URL=https://github.com/adrienvada/Candela-2D---Godot/releases/download/v0.8.3/Candela-windows.zip
SIZE=131182481 ; curl -sSL -r $((SIZE-262144))-$((SIZE-1)) -o tail.bin "$URL"     # annuaire du zip (GitHub refuse les « -N » : plage explicite)
# entrée Candela.pck : offset local 38539333, 84018641 octets deflate → inflater (zlib.decompressobj(-15)) → candela.pck
python3 liste_pck.py candela.pck --top 40 --mort '*titre_*,*godot_ai*,*sources/*'
```
(Les binaires de travail — PCK Windows et macOS inflatés, 340 Mo — ont été supprimés après analyse ; les commandes ci-dessus les reconstituent en quelques secondes. `mac_pck_entry.json` donne l'offset de l'entrée macOS : `61344331`, 85 772 921 o.)
`liste_pck.py` lit l'en-tête (112 o) et le répertoire de fin de fichier d'un `.pck` de format 4 (celui qu'écrit `godot --export-pack`), sans le charger en entier ; code retour 1 s'il reste une entrée interdite → prêt à servir de garde de CI.

## Annexe C — Recoupements avec les autres rapports de l'audit (pour la consolidation)

Établie après coup, en ouvrant les rapports 01 à 12 et 14. « Doublon complet » : même code, même défaut, même correctif. « Partiel » : un même fichier ou une même famille, mais
un angle ou un fait différent. Les identifiants cités sont ceux des rapports des autres domaines ; je n'ai rien changé dans leurs fichiers.

| DEM | Recoupe | Nature | Écarts de chiffres, et ce que DEM apporte en propre |
|---|---|---|---|
| DEM-01 | — | propre | Aucun autre rapport ne lit le paquet publié. 31,75 Mo de PCK pour 33 images sans lecteur. |
| DEM-02 | — | propre | Dylib EOS en double dans le `.app`, `icon.icns` cuit dans le PCK macOS. |
| DEM-03 | MEN-08 (10_MEN), HUD-10 (09_HUD) | **doublon complet** | Mêmes 16 fichiers, même `MenuApercu._init → load`. Leurs 44 et 58 Mo sont dans mes bornes 43,6-58,2 Mo. Durée de décodage au lancement : 0,3-0,8 s (MEN-08), 100-400 ms pour tout `UI._ready` (HUD-10), 0,1-0,4 s (DEM-03) — trois estimations, aucune mesure. Apport DEM : poids dans le PCK ; apport MEN-08 : déchargement à l'entrée en match. |
| DEM-04 | GAD-11 (07_GAD) ; GAD-05, GEO-04 (02_GEO), ISO-09 (01_ISO) | partiel | GAD-11 : mêmes planches, ≈ 42 Mo de VRAM = mes 37,8 Mo de volutes + 4,2 Mo de `fusee_corps`. Les trois autres décrivent ce que `prechauffer` ne couvre pas (grilles de cubes, programmes GL) ; DEM-04 décrit ce qu'il coûte (relecture GPU + boucles GDScript sur 3 × 65 536 px). |
| DEM-05 | HUD-10 (annexe A, point 4), MEN-08 (« Vérifier ») | partiel | Tous veulent chronométrer `UI._ready`. DEM-05 propose de consigner le démarrage entier, à chaque lancement, dans F6 et le journal. |
| DEM-06 | ETA-01 (06_ETA), CAR-04 (14_CAR), GAD-10 (07_GAD), MEN-12 (10_MEN) | **doublon complet** | Estimations : 10-40 ms (ETA-01 et DEM-06, ETA-01 donne la fourchette 3-120), 15-50 ms (CAR-04), « quelques ms » (MEN-12). Sévérités : MAJEUR sous réserve (ETA-01), MINEUR (CAR-04, DEM-06), ANECDOTIQUE (MEN-12) — à arbitrer par la vérification « le coup fatal ». |
| DEM-07 | HUD-09 (09_HUD) | partiel (même famille « premières fois ») | HUD-09 : rastérisation des glyphes à la première apparition. DEM-07 : glyphes **absents** des deux polices (`●` U+25CF, `✓`, `▲▼◀▶`) donc repli sur les polices du système — aucun autre rapport n'en parle. |
| DEM-08 | MEN-04 (10_MEN), ISO-07 (01_ISO) | **doublon complet** | Estimations : 0,3-3 ms (MEN-04), ~3 ms (ISO-07), « une part des ~5 ms » (DEM-08), aucune mesurée. Apport DEM : inventaire de ce que dessinent les deux vues au hub — dont **deux halos ambiants à ombre, jamais éteints, donc quatre passes d'ombre par image** (question que MEN-04 laisse ouverte) — et le lien avec la règle moteur de l'audit des lumières. |
| DEM-09 | MEN-05 (10_MEN) | **doublon complet** | MEN-05 ajoute un palier d'inactivité (30 i/s après ≈ 10 s sans geste). |
| DEM-10 | RES-10 (08_RES) | partiel | RES-10 : seulement le SHA-256 et l'extraction bloquants (ANECDOTIQUE : rare, volontaire). DEM-10 : en plus, l'archive de 131-185 Mo **jamais supprimée** de `user://maj/`. |
| DEM-11 | MEN-07 (10_MEN), MEN-14 (10_MEN) | partiel | MEN-07 : décodage synchrone de `fin_victoire`/`fin_defaite` à chaque fin de match. DEM-11 : leur poids (JPEG ré-encodé sans perte, ×4). Les deux correctifs se composent. |
| DEM-12 | — | propre | Corrige la ROADMAP l. 7659 (l'autoload `_mcp_game_helper` est bien retiré de l'export). |
| DEM-13 | — | propre | Les rapports 04, 07, 08 notent seulement que `physics_ticks_per_second` n'est pas surchargé (donc 60) : cohérent avec DEM-13. |
| DEM-14 | MEN-11 (10_MEN), HUD-02 (09_HUD, ligne 2a de sa carte), ETA-03, GAD-08 | **doublon complet** | Hors domaine, trouvé en passant. À écarter au profit de HUD-02. |

**Faits d'autres rapports qui touchent à mes preuves de vérification.**
(1) MEN-09 : le banc `--menus` de `bench_framerate` ne traverse plus les écrans du hub (identifiants périmés). Sans effet sur la comparaison de DEM-08 (hub au repos), mais
tout chiffre de traversée pris avec ce banc est sous-estimé. (2) LUM-03 : le modèle `4 × N × L` du coût d'ombre par viewport est celui auquel DEM-08 renvoie pour chiffrer les quatre passes
d'ombre du hub. (3) Aucun autre rapport ne contredit un fait de ce rapport ; les écarts relevés ci-dessus portent tous sur des estimations de durée non mesurées.
