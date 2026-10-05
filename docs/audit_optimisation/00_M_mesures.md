# Mission M — Mesures (audit d'optimisation de Candela 2D, 2026-10-04)

Rapport écrit au fil de l'eau : chaque étape ajoute sa section dès qu'elle est finie.
Arbre mesuré : worktree `<worktree de mesure>`, commit `52a29c1` (0.8.3 + SOLO S12), **aucun fichier suivi modifié** ; les instruments de mesure sont des fichiers NON SUIVIS ajoutés sous `tools/` (`mesure_*.gd`, `sonde_*.gd`, `banc_image_impact.gd`, `banc_ui_cachee.gd`, `micro_*.gd`, `preuve_flou.gd`, `variantes_reflexion.gd`), jamais commités ; les variantes « retouchées » vivent dans des arbres de liens symboliques à part (`scratchpad/arbres/`, avec leur `.diff`), jamais dans le worktree.
Scripts et journaux de mesure : `<scratchpad>/mesures/` (chaque mesure : étiquette `.log` + `.meta` = commande exacte, début, fin, charge). Machine : conteneur de 4 vCPU Xeon 2,8 GHz sans GPU (section 0) ; **sous llvmpipe, seuls les RAPPORTS entre variantes d'une même série ont un sens ; le Mac M3 (GPU à tuiles) n'est pas représenté.**

## Résumé (chiffres clés et ce qui reste non mesuré)

1. **Suites : VERT** (code 0, 1 748 s, 198 `OK`, 0 échec). **Import 39 s** depuis zéro ; **démarrage 5,7 s** jusqu'au premier menu en headless (3,9 s d'autoloads + scène principale, dont ≈ 2,7 s de compilation GDScript indivisible), ≈ 10,7 s à froid sous llvmpipe.
2. **V1b-N1 CONFIRMÉ** (la priorité) : chaque pose de **poussière coûte ≈ 95-105 ms** d'une seule image, **la suie ≈ 30-35 ms** (le préchauffage laisse mourir la texture dont il indexe ses caches) ; fuite 0,87 / 0,3 Mo par pose ; **le correctif d'une ligne, émulé : 3 ms**.
3. **CPU sans rendu (headless)** : PvP iso **3,8-4,9 ms/image** contre **2,2 en vue de dessus** (la couche iso double l'image CPU), duel contre le bot 5,8, solo ch. 0 / 7 / 8 : **7,2 / 10,0 / 11,4 ms** (p99 **20,9 ms** au ch. 8, au-dessus des 16,7 ms de la cible). **Aucune dérive** sur 5 minutes : plateaux à 990 traces, orphelins et RSS constants. Première image d'une manche : 450-530 ms.
4. **Rendu iso, vue unique (compteurs, llvmpipe)** : 188 appels de dessin, 1 403 objets, 61 556 primitives (91 % en 3D), 5,76 Mpx de surface cumulée (2,8 fois l'écran), 7 lampes à ombre pour 792 arêtes d'ombre par image dont 14 couples lampe-viewport « n'éclaire rien ».
5. **Plancher d'auto-éblouissement (Q81)** : torche allumée au repos = **1 `BackBufferCopy` + 1 ColorRect lisant l'écran + un halo, à chaque image** (PROUVÉ sans GPU) ; **les supprimer (A1) ne change rien sous llvmpipe** (−0,3 %, dans le bruit : attendu, la coupure de passe d'un GPU à tuiles n'y existe pas — son prix sur le M3 reste NON MESURÉ) ; **le voile « calme » coûte 13-16 % de l'image** (−46 à −51 ms sur 314) et disparaît à niveau 0.
6. **Arène rendue sous le menu du hub** : **un tiers de l'image du hub** sous llvmpipe (−56 ms sur 167 ; −72 % d'objets, −75 % de primitives, surface de rendu 4,14 → 2,07 Mpx).
7. **V3** : l'impact tombe dans l'image du tir ; mur 5 plombs +8,3 ms, contact sur un corps +18 ms (haut de l'enveloppe de V3), particules 35-43 % ; **V2** : HUD-02 retire 0,67 ms par image au repos (−32 %), la galerie cachée 0,25-0,35 ms, `Presentation3D._process` pèse 0,47 ms.
8. **Non mesuré** : le GPU à tuiles du M3 (prix réel d'une coupure de passe, du voile, des deux vues) ; 6b la fumée de fusée ; D1 l'atlas des lumières ; la décomposition générale (torches, faisceau, ombres 2D, capteurs…) ; trois configurations sur quatre de l'étape 5 ; l'attribution du coût du solo — **commandes en § 8**.

## 0. La machine

| | |
|---|---|
| Conteneur | Linux 6.18 (Firecracker), 4 vCPU `Intel(R) Xeon(R) Processor @ 2.80GHz`, 15 Go de RAM, pas de GPU |
| Rendu | Mesa 25.2.8 (`libgl1-mesa-dri`), llvmpipe sous Xvfb (`xvfb-run`, écran 1920x1080x24) |
| Godot | 4.7.1.stable.official.a13da4feb (le binaire de la CI, `Godot_v4.7.1-stable_linux.x86_64`) |
| Python | 3.11.15 |
| Charge au démarrage | load average 0,14 / 0,27 / 0,34 (machine au calme) |

## 1. Étape 1 — installation de Godot et import

- Téléchargement : `curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.x86_64.zip`
  (76 056 717 octets, **1,5 s**), `unzip` puis `chmod +x` ; `--version` -> `4.7.1.stable.official.a13da4feb`.
- Import : `cd <worktree> && Godot_v4.7.1-stable_linux.x86_64 --headless --path . --import`
  (script `mesures/import.sh`, journal `mesures/import.log`). **Durée : 39,2 s** (import depuis zéro, aucun dossier `.godot/`
  au départ ; `.godot/` pèse ensuite 80 Mo). Code de sortie 0. Charge avant : 0,14 ; après : 1,51 (le pic de l'import).
  486 étapes de (ré)import d'assets, 584 classes globales enregistrées.
- Bruit sur la sortie de l'import, à connaître : 21 lignes `ERROR`, toutes de PREMIÈRE passe — la police `Oxanium.ttf` ouverte
  avant d'être importée, et 12 `SCRIPT ERROR: Parse Error: Cannot infer the type of "local_user_id"` dans
  `addons/epic-online-services-godot/heos/hauth.gd` / `network_manager.gd` (l'extension EOS native n'est pas encore enregistrée
  au premier balayage). Le code de sortie reste 0, et `run_suites.sh` (étape 2) démarre ensuite sans erreur de script
  (voir plus bas).

## 2. Étape 2 — ligne de base : toutes les suites headless

- Commande (depuis le worktree, **seule**, sans tuyau, code de sortie lu) :
  `GODOT=<godot-bin>/Godot_v4.7.1-stable_linux.x86_64 ./tools/run_suites.sh > mesures/suites.log 2>&1 ; echo $?` (script `mesures/suites.sh`).
- **Verdict : VERT.** Code de sortie **0**, dernière ligne : `--- tout passe, sans erreur de script (1748s) ---`.
  198 lignes `OK` dans le journal (le contrôle de démarrage, 160 suites de la liste principale, 1 suite `--2d`, les runs nommés — `test_fumee_voxel_couches`,
  `test_fumee_voxel_drapeaux`, `test_nappes_voxel_braises`, `test_netcode`, `test_halo_proximite`, `test_accroupi`, `test_fin_de_match`, `test_entrainement`,
  `test_fenetre_de_choix`, `test_depart_apparie`, `test_eblouissement_en_jeu` — et les **neuf scénarios à deux instances** `duo_*`, tous jouables : aucun `REPORTÉ`),
  **0 `ÉCHEC`, 0 `SCRIPT ERROR`, 0 `push_error` non déclaré**. Aucune suite rouge : rien à citer.
- **Durée : 1 748,7 s (29 min 09 s)**, 23:41:45 → 00:10:53, machine partagée avec les agents de lecture (load average 1,13 au départ, 1,3 à 1,9 en cours, 1,51 à la fin ;
  PSI cpu `some avg60` 1,7 %). La CI GitHub annonce ~19 min 50 pour le même lot : ce conteneur (4 vCPU `Xeon @ 2,8 GHz`, sans GPU) est ~1,5 fois plus lent.
- Où va le temps (horodatage de chaque ligne du journal, résolution ~1 s ; `mesures/suites_chrono.txt`, `chrono_analyse.py`) :
  les ~142 premières suites (unitaires, menus, cartes, lumières, fusée, fumée) prennent ~11,7 min (≈ 5 s chacune en moyenne) ;
  puis les **suites de jeu monté à pas fixe** : `test_chapitres_marche_07_09` **144 s**, `test_chapitres_marche_04_06` **129 s**, `test_chapitres_marche` **90 s**,
  `test_banc_bot` **48 s**, `test_bot_equipement` 32 s, `test_aventure_partie` 24 s, `test_fin_de_match` 18 s, `test_eblouissement_en_jeu` 16 s ;
  enfin les **neuf `duo_*`** (deux processus ENet chacun, 17 à 35 s chacun) ≈ **4,9 min** à eux seuls (00:05:58 → 00:10:54). Les trois suites « marche » du solo
  (jouer les salles des chapitres 1 à 9 au vrai corps) pèsent ~6 min, soit 20 % du lot ; `PLAFOND_SUITE` y est de 600 / 420 s, rien ne s'en approche (plus lente : 144 s).
- Lecture : le lot n'est pas rouge ; son coût de 29 min vient du solo (SOLO S8, parties jouées image par image) et des duos réseau, pas des ~140 suites unitaires.

## 3. Étape 3 — démarrage (moteur, autoloads, scène principale)

Cinq lots de commandes, tous depuis le worktree, **foyer `HOME` isolé** à chaque lancement avec un `settings.cfg` de joueur existant (comme `prise.sh` : sans lui l'intro de premier lancement joue),
cache Mesa dédié (`MESA_SHADER_CACHE_DIR`, le premier lancement fenêtré est donc À FROID). Journaux et métadonnées (commande exacte, durée, charge) : `mesures/<étiquette>.{log,meta}` ; scripts `etape3.sh`, `etape3b.sh`.
Machine au calme : load average 0,4 à 0,7 avant chaque lancement headless, 1,4 à 2,0 autour des lancements Xvfb (le Xvfb précédent finit de mourir, `attendre_libre.sh` l'attend 20 s).

### 3.1 Marques du moteur — `--benchmark-file` (commande : `env HOME=<foyer> Godot_v4.7.1-stable_linux.x86_64 [--headless | xvfb-run -a -s "-screen 0 1920x1080x24" …] --path . --benchmark --benchmark-file <abs>.json --quit-after 5|40`)

Trois lancements chacun (ms ; médiane ; plages entre parenthèses). `Main::Start` = `Load Autoloads` + `Load Game`.

| Marque du moteur | headless | Xvfb + llvmpipe (lancements 2 et 3, Mesa à chaud) | Xvfb, lancement 1 (Mesa à froid) |
|---|---|---|---|
| `Main::Setup` | 22 (21-28) | 23 | 23 |
| `Servers` (affichage, rendu, audio) | 34 | **442** (427-442) | **4 827** (dont `Display` 4 257) |
| `Setup Window and Boot` | 34 | 79 | 127 |
| `Scene` (enregistrement des types) | 79 | 82 | 73 |
| `Main::Setup2` | 165 (162-233) | 688 (595-688) | **5 046** |
| **`Load Autoloads`** | **1 155** (1 129-1 158) | 1 144 (1 132-1 411) | 1 144 |
| **`Load Game`** (la scène principale `main.tscn`) | **2 706** (2 702-2 966) | 2 803 | 2 655 |
| `Main::Start` | **3 858** (3 836-4 124) | 3 988 | 3 800 |
| `Cleanup` (fin) | 162 | 271 | 224 |

- Le processus entier (`--quit-after 5`, headless) dure 5,87 à 6,33 s ; sous Xvfb (`--quit-after 40`, quarante images de l'intro/menu à ~140 ms chacune) 13,5 à 23,9 s.
- **Le démarrage à froid de Mesa coûte +4,4 s une fois** (création du contexte GL llvmpipe, `[Servers] Display` 4,26 s contre 0,25 s ensuite) : un artefact du conteneur, pas du jeu.
- Sur la sortie console : `Load Autoloads` + `Load Game` = 3,9 s, soit ~65 % du temps de démarrage headless (3,86 s sur 5,9 à 6,3 s) ; le moteur lui-même (Setup + Setup2) en prend ~0,2 s.

### 3.2 Chaque autoload — la « ferme » (`sonde/faire_ferme.py`)

Un projet fait de liens symboliques vers le worktree, dont le `project.godot` enveloppe chacun des 21 autoloads d'un script `extends "<l'original>"` qui imprime l'instant (µs depuis le démarrage du processus)
de son `_init` (fin du chargement du script + de l'instanciation) et de son `_ready`. Aucun fichier du jeu modifié. Cinq lancements headless (`--no-eos`), médiane ; `_init` = chargement/compilation du script ET de ce
qu'il charge pour la première fois, + son `_init`.

| Autoload (ordre de `project.godot`) | `_init` (ms) | `_ready` (ms) | Lecture |
|---|---|---|---|
| `PatchLoader` | 197,3 | 11,1 | **inclut ~190 ms de moteur avant le premier autoload** (Setup 22 + Setup2 165) : son coût propre ≈ 10 ms |
| `ReplaySystem` | 63,9 | 0,1 | |
| `InputSetup` | 20,5 | 0,3 | |
| **`AudioManager`** | **194,3** | 14,3 | script de 2 976 lignes + les `preload` de sons (importés) |
| `MapData` | 33,3 | 2,4 | |
| **`NetworkManager`** | **537,0** | 0,1 | **le plus lourd** : la compilation de `network_manager.gd` (1 183 l.) et du greffon EOS GDScript qu'il référence (les dix autoloads `EOSGRuntime`, `H*` qui suivent coûtent 0,1 à 14 ms chacun, leurs scripts sont déjà chargés) — payé MÊME en `--no-eos` : c'est de la compilation, pas de l'initialisation du SDK |
| `GameSettings` | 76,8 | 0,2 | |
| `UpdateManager` | 62,8 | 0,2 | |
| `_mcp_game_helper` | 81,1 | 0,1 | l'autoload du greffon éditeur `godot_ai`, resté dans le build (CONNU : ROADMAP l. 7661, 22576) ; son `_process` tourne à chaque image |
| `EOSGRuntime`, `HPlatform`, `HAuth`, `HAchievements`, `HFriends`, `HStats`, `HLeaderboards`, `HLobbies`, `HP2P`, `HSessions` | 1,5 / 0,1 / 0,1 / 14,5 / 4,0 / 8,0 / 6,3 / 0,2 / 0,1 / 9,8 (≈ 45 au total) | ≈ 0 | |
| `RankedIdentity` | 57,3 | 0,0 | |
| `Matchmaker` | 32,0 | 0,0 | |
| **Total des autoloads** | **1 401 − 197 = 1 204** (les `_init`) | 29 (les `_ready`) | cohérent avec la marque du moteur `Load Autoloads` = 1 155 ms |

Sous Xvfb (3 lancements) le tableau est le même à ±5 % (NetworkManager 540, AudioManager 195) ; seuls `PatchLoader` (570 : le moteur est plus long à monter sous llvmpipe) et les `_ready` (96 ms au total) changent.

### 3.3 La scène principale (`main.tscn`)

Chargée par le script de la ferme en trois temps (cinq lancements headless ; médiane ; Xvfb entre parenthèses) :
- `load("res://main.tscn")` : **2 747 ms** (2 815) — c'est la compilation GDScript de tout ce que la scène référence, pas la lecture d'un `.tscn` de trois lignes ;
- `instantiate()` : **1,0 ms** (14) ;
- `add_child()` — la cascade de tous les `_ready` (`GameState`, `UI` qui bâtit HUD et menus, joueurs, arène) : **1 180 ms** (1 217) ;
- première image : 315 ms (396 sous Xvfb) ; images 2 à 12 : 1,5 à 8,5 ms ; menu en régime : **8,33 ms** headless = le plafond de 120 i/s des menus (`GameSettings.PLAFOND_MENU`), pas un coût de calcul ; sous llvmpipe le menu rend à **143 ms l'image** (p99 199).
- Soit, du lancement à la première image du menu : **≈ 5,7 s en headless** (moteur + autoloads 1,43 s · `load main.tscn` 2,75 s · `_ready` en cascade 1,18 s · première image 0,32 s), ≈ 6,3 s sous Xvfb à chaud, **≈ 10,7 s à froid**.

**Où va la compilation de `main.tscn` (2,7 s).** Le coût d'un script ne s'isole pas : les scripts se référencent par `class_name` et forment un seul bloc fortement connexe. Chargés à la suite dans le même processus, le premier absorbe tout —
`ui.gd` en premier : 2 509 ms, puis `game_state.gd`, `player.gd`, `presentation_3d.gd`, `iso_volumes.gd`… à ~0 ms ; `game_state.gd` en premier : 2 649 ms ; `player.gd` en premier : 766 ms puis `ui.gd` 1 910 ms ; dépendances d'abord :
`bullet.gd` 906 ms, `game_state.gd` 1 726 ms, `bot_input_provider.gd` 173 ms (`mesures/ferme_scripts*.log`). Hors du bloc : `map_editor.gd` +186 ms et `screen_matchmaking.gd` +57 ms (chargés plus tard, par `load()`
paresseux, au premier usage — c'est déjà fait ainsi). Le dépôt compte 81 923 lignes de GDScript à la racine (171 fichiers) ; à ~2,6 s pour le bloc de démarrage, ce sont **de l'ordre de 30 ms par millier de lignes**.
**PROUVÉ** : 2,5 à 2,7 s de GDScript compilés au démarrage, indivisibles par script. **NON MESURÉ** : ce que coûterait le même chargement dans un build exporté (jetons binaires `.gdc`) — sur le Mac d'Adrien le moteur de scripts est le même, la compilation est du CPU pur.

**Ce qui coûte, par ordre :** `load main.tscn` 2,75 s (48 %) > `NetworkManager` + greffon EOS 0,54 s > `_ready` en cascade 1,18 s > `AudioManager` 0,21 s > `_mcp_game_helper` 0,08 s > `GameSettings` 0,08 s > le reste des autoloads < 0,07 s chacun.
Le démarrage n'est pas dans le chemin chaud d'un match, mais c'est le premier contact : 5,7 s avant le premier menu, dont 3 s de compilation de GDScript.

## 3bis. Mesure PRIORITAIRE — V1b-N1 : le préchauffage de la suie et de la poussière est inopérant — **CONFIRMÉ**

**Question (`audit/V_V1b.md` § 3.3, A4).** `IsoNuageVoxel.prechauffer()` charge les sprites de la suie et de la poussière dans une variable locale ; les caches `_aplats` / `_reliefs` sont indexés par `get_instance_id()` de
cette texture, qui meurt au retour. Le gadget charge ensuite SA propre instance (`GadgetBase._texture_de` → `load()`), les clés ratent, et les boucles GDScript par pixel (`aplat` : 1 boucle, `relief` : 3 boucles) tournent
à l'image où le nuage apparaît — à CHAQUE pose. Estimation de V1b : 0,1 à 0,3 s (poussière), 0,03 à 0,1 s (suie), « à mesurer ».

**Protocole.** Le vrai jeu monté en headless à pas fixe (`main.tscn`, vue **iso par défaut**, manche locale en vue unique, J1 et J2 immobiles), les deux joueurs de la classe du gadget (Terrassier `pompe` pour `poussiere`, Fumiste `fumiste`
pour `cartouche_suie`, afin que `duree_vie` soit celle du jeu : 7,5 s / 9 s). Le vrai geste : `GameState._do_spawn_gadget(0, pos, 0, slug, n, graine)` (le chemin du RPC). 4 poses successives de J1, chacune laissée vivre
jusqu'à sa mort naturelle (411 / 500 images) avant la suivante — comme une manche, où la recharge est de 60 s ; puis une 5e pose de J1 et, 20 images plus tard, une pose de J2 pendant que celle de J1 vit encore. Chronométrage
`Time.get_ticks_usec()` : l'appel `_do_spawn_gadget`, puis la durée de chacune des 40 images suivantes (écart entre deux émissions de `process_frame` : physique + `_process` + dessin factice + audio), contre la médiane de 180 images
sans gadget. Relevés à chaque pose : tailles de `IsoNuageVoxel._aplats` / `_reliefs`, `ResourceLoader.has_cached(<sprite>)` AVANT la pose, mémoire statique après la mort du nuage. En fin de course, un micro : `aplat()` + `relief()` sur
une instance NEUVE de la texture (`CACHE_MODE_IGNORE` : clé absente, le cas de chaque pose), puis sur la même (clé présente).
Variante « **correctif émulé** » (`--tenue=1`) : les deux textures sont tenues vivantes pendant toute la mesure et leurs `aplat`/`relief` calculés une fois avant les poses — exactement ce que ferait la ligne proposée par V1b
(`prechauffer()` rangeant les sources dans une variable statique). Aucun fichier du jeu n'est modifié : l'instrument est `tools/mesure_nuage.gd` (copie de `scratchpad/sonde/mesure_nuage.gd`, non commité).

**Commandes exactes** (depuis le worktree ; script `mesures/etape_nuage.sh`, journaux `mesures/nuage_*.{log,meta}`) :
`Godot_v4.7.1-stable_linux.x86_64 --headless --path . --fixed-fps 60 --script res://tools/mesure_nuage.gd -- --no-eos --slug=poussiere --classe=pompe --poses=4 --double=1 [--tenue=1]`
et `… --slug=cartouche_suie --classe=fumiste --poses=4 --double=1 [--tenue=1]`. Quatre lancements de **13 à 14 s** chacun, un seul Godot à la fois, machine au calme (load average 0,3 à 0,9 : 0,32 / 0,40 / 0,60 / 0,85 au départ des quatre).

**Résultat 1 — l'état du dépôt : le préchauffage ne sert à rien.** Après le montage (`prechauffer()` a tourné, `_prechauffe = true`) : `_aplats = 2`, `_reliefs = 2`, et **`ResourceLoader.has_cached` = `false` pour les deux sprites** : les
instances préchauffées sont mortes. Avant chacune des poses, la texture n'est pas en cache (`false` aux 5 poses de J1) ; après chaque pose, les deux dictionnaires **gagnent une entrée** (2 → 7 en 5 poses), preuve d'un MANQUE à chaque fois.

**Résultat 2 — le prix du manque (CPU pur : valable ici comme ordre de grandeur, pas d'effet du pilote graphique).** Médiane de l'image de base : 1,74 ms (poussière) / 1,61 ms (suie).

| | poussière (336², 112 896 px) | suie (184², 33 856 px) |
|---|---|---|
| **Micro — MANQUE** `aplat` + `relief` (3 essais × 2 lancements) | **7,2-7,6 + 83-90 = 91-98 ms** | **2,2-2,6 + 25-30 = 27,5-31,8 ms** |
| Micro — TOUCHE (clé présente) | 0,02 ms | 0,015 ms |
| Coût par itération (4 boucles × px = 451 584 / 135 424 itérations) | ≈ 0,20 µs | ≈ 0,21 µs |
| **En jeu, 1re image après la pose** (poses 2, 3, 4 ; image de base 1,7 ms) | **95,5 / 97,2 / 103,1 ms** (5e pose : 107 ms) | **36,4 / 30,8 / 30,9 ms** (5e pose : 30,8 ms) |
| Appel `_do_spawn_gadget` lui-même (poses 2-4) | 3,2-3,3 ms (le `load()` de la texture, neuve à chaque fois) | 1,5-1,9 ms |
| **Même chose, correctif émulé** (poses 2, 3, 4 ; image de base 1,9 / 1,8 ms) | **3,1 / 2,9 / 4,5 ms** (appel : 0,2-0,3 ms) | **2,2 / 2,3 / 2,5 ms** (appel : 0,2-0,3 ms) |
| Entrées de cache par pose | +1 `_aplats` +1 `_reliefs`, **+0,87 Mo** de mémoire statique | +1 / +1, **+0,25 à 0,36 Mo** |
| Idem, correctif émulé | 4 / 4 entrées, constantes ; +0,03 à 0,08 Mo (bruit) | 4 / 4, constantes ; 0,00 à +0,10 Mo |
| J2 pose pendant que le nuage de J1 vit (instance partagée, `has_cached = true`) | **4,1 ms** (touche, aucun à-coup) | **2,9 ms** |

**Lecture.**
- **Constat vrai, à l'échelle annoncée par V1b — par le bas de la fourchette.** Chaque pose de poussière coûte **≈ 95-105 ms** d'une seule image (6 images à 60 i/s, 12 à 120 i/s) et chaque pose de suie **≈ 30-35 ms**, sur ce conteneur
  (Xeon 2,8 GHz, GDScript monothread). L'ordre de grandeur de V1b (0,1-0,3 s ; 0,03-0,1 s) tient ; le bas de sa fourchette est le bon (≈ 0,2 µs par itération, pas 0,6).
  Le micro (91-98 / 27,5-31,8 ms) et l'à-coup en jeu (≈ 94-101 / 29-35 ms au-dessus de l'image de base) s'accordent, donc l'à-coup est bien ce calcul et rien d'autre.
- **Où il tombe** : l'image même où le nuage apparaît (`d0`, la première après l'appel : `IsoVolumes._suivre_gadget_en_voxels` appelle `aplat` puis `relief` à la première image où le gadget est suivi) — pile quand un
  joueur pose une fumée en plein duel. Il tombe **chez chaque pair** (chacun suit les gadgets des deux joueurs dans sa vue) : en ligne, **l'hôte** le paie à chaque pose de l'un ou l'autre, et sa simulation avec lui
  (hôte-autoritaire : l'arrêt de 0,1 s retarde l'état des deux joueurs). Il n'existe qu'en vue iso (défaut) : `IsoVolumes` ne tourne pas en `--2d`.
- **Sur le Mac d'Adrien** : GDScript est du CPU monothread pur ; un M3 le fait plus vite que ce Xeon (rapport non mesuré, ESTIMÉ 1,5 à 2) → **~50-70 ms (poussière), ~15-25 ms (suie)** par pose, soit encore 3 à 8 images perdues à 120 i/s.
- **Mémoire** : fuite lente confirmée, 0,87 Mo par pose de poussière et ~0,3 Mo par pose de suie, bornée par le nombre de poses (≤ 5 par joueur et par manche de 5 min : ≤ 4,4 Mo) — secondaire.
- **Le cache fonctionne par accident** quand les deux joueurs ont le même gadget vivant en même temps (la deuxième pose réutilise l'instance de la première : 4,1 ms) — un face-à-face Terrassier contre Terrassier posant dans les 7,5 s.
- **Le préchauffage est déjà payé** : le journal de démarrage dit `[fumée voxel] préchauffé en 184-308 ms` (une quinzaine de lancements headless ; 214-221 ms sous Xvfb) ; `aplat` + `relief` des deux dessins en prennent ≈ 120 ms (92 + 28) — du travail
  fait au lancement pour des clés mortes, puis refait à chaque pose. **Le correctif n'ajoute rien au démarrage** : il rend utile ce que `prechauffer()` calcule déjà (mesure « correctif émulé » : 92 + 28 ms une fois, 0b du journal).
- **Correctif émulé (une ligne) : l'à-coup disparaît** (3 ms au lieu de 100 ms, 2,3 ms au lieu de 31 ms ; les images suivantes sont à la base), le cache ne grossit plus (4 entrées constantes), la mémoire est stable.
  **Contraintes à respecter** (V1b § 3.3) : la suite `tools/test_fumee_voxel.gd` fige le texte de `iso_nuage_voxel.gd` (« aucun `preload(` et exactement un `load(CHEMIN_SHADER)` »), ce qui laisse libre une variable statique + `load(chemin)` dans `prechauffer()`.
- **Bonus — les « premières fois » de la même séquence** (journal `nuage_*_tenue.log`, pose 1 contre poses 2-4, correctif émulé donc sans N1) : la TOUTE première pose de chaque type de nuage du processus coûte en plus
  **≈ 80 ms (poussière : 83,5 ms contre 3 ms)** et **≈ 70 ms (suie : 17,0 + 57,6 ms sur deux images contre 2,3 ms)**, et l'appel lui-même ≈ 29-44 ms (compilation du script du gadget, premier `load()`) contre 0,2-0,3 ms ensuite.
  C'est la grille de cubes (`IsoNuageVoxel.grille`, construite à la première image où le nuage est suivi, jamais préchauffée — V1b § 3.3 « Quand ») — **l'attribution à la grille est la lecture de V1b, non isolée ici** ; que ce soit une première fois et une seule par processus est prouvé.
  La toute première pose d'un processus coûte donc, appel compris, **≈ 125 ms (poussière) et ≈ 105 ms (suie) hors N1** (correctif émulé : 43,8 + 83,5 ms ; 28,6 + 17,0 + 57,6 ms), et **≈ 200 ms et ≈ 130 ms avec N1** (état du dépôt : 31,6 + 168,4 ms ; 29,0 + 44,8 + 56,8 ms).

**Verdict : CONFIRMÉ, sévérité MAJEURE comme présumée** — un à-coup de ~0,1 s (poussière) / ~0,03 s (suie) sur l'action « poser une fumée », récurrent, évitable par une ligne, sans coût au démarrage. À l'échelle de l'audit, c'est un
à-coup unique par pose (≤ 5 par joueur et par manche), pas une cadence dégradée.
Limites : headless (le coût du moteur graphique de l'image, dont le dessin du nuage, n'est pas dans ces chiffres — ils sont donc un MINIMUM de l'à-coup réel ; en particulier `aplat` et `relief` commencent par `Texture2D.get_image()`, que le moteur factice sert depuis la mémoire et qu'un vrai pilote sert par une LECTURE DU GPU, un arrêt de synchronisation de plus, non mesuré ici) ; Mac M3 non représenté (CPU plus rapide : à-coup plus court qu'ici) ; 4 à 5 poses par cas, mais les poses 2-4 sont à ±4 % l'une de l'autre et le micro à ±3 %.

## 4. Étape 4 — coût CPU de la simulation SANS rendu, et dérive sur une manche de 5 minutes

**Méthode.** Le vrai jeu monté (iso par défaut), en `--headless` (serveur de rendu et audio factices) et **`--fixed-fps 60`** (un pas de physique par image, sans attente : sans lui, `OS::add_frame_delay` dort ~6,9 ms
par image en headless et le temps mesuré ne dit que ce sommeil — V2 § 4). **Le coût d'une image est l'écart d'horloge murale `Time.get_ticks_usec()` entre deux émissions de `process_frame`** (pas de physique + `_process` + appels différés +
dessin factice + audio) ; je le sépare en « pas de physique » (de `physics_frame` à `process_frame`) et « reste » (le complément). **Piège de mesure, payé puis confirmé par V2 dans les sources 4.7.1** : `Performance.TIME_PROCESS` et `TIME_PHYSICS_PROCESS`
ne sont rafraîchis qu'UNE fois par seconde et valent le MAXIMUM de la seconde écoulée (`main.cpp`, `if (frame > 1000000)`). Ma première mesure l'a montré (TIME_PROCESS 30 ms pour une image de 2,4 ms d'horloge) ; **toute colonne « TIME_* » ci-dessous est donc une
moyenne ou un centile de MAXIMA PAR SECONDE** (la pire image de chaque seconde, ≈ 2,5 à 3 fois l'image moyenne), jamais un coût par image ; elle ne sert qu'à lire la queue. Les relevés de ressources (nœuds, objets, orphelins, mémoire statique `MEMORY_STATIC`,
`VmRSS` lu dans `/proc/self/status` — lecture vérifiée vivante par un essai à +200 Mo —, traces au sol, particules, tampon de rejeu, lumières) sont pris tous les 5 s de jeu. Instruments (non commités, copiés dans `tools/` du worktree) : `sonde_mesures.gd`, `mesure_sim.gd`,
`mesure_banc.gd` ; sources : `scratchpad/sonde/`. **Ce que ces chiffres ne contiennent pas** : aucun appel de pilote graphique (le moteur de rendu est factice : les appels `RenderingServer` coûtent leur seul empaquetage), aucun GPU, aucun thread audio ; ils sont en revanche mesurés sur un Xeon 2,8 GHz
plus lent que le M3 pour GDScript monothread (rapport non mesuré : ESTIMÉ 1,5 à 2). Lire ces valeurs comme **le plancher CPU côté scripts**, à ne pas comparer en millisecondes à celles du Mac.

**Commandes exactes** (depuis le worktree, un seul Godot à la fois, journaux `mesures/sim_*.log`, JSON des paliers `mesures/sim_*.json`, provenance `mesures/sim_*.meta` ; scripts `etape4.sh`, `etape4b.sh`) :
- Charge de référence du projet : `Godot_v4.7.1-stable_linux.x86_64 --headless --path . --fixed-fps 60 res://tools/mesure_banc.tscn -- --no-eos --fusee --vue-unique --classe=pompe --zoom=1.5 --seconds 262 --sonde --sonde-depuis 30 --sonde-json <json>`
  (`mesure_banc` est une sous-classe de `tools/bench_framerate.gd` : même charge — deux joueurs scriptés, tirs, la fusée —, mêmes bornes ; 262 s = 30 s de chauffe + 232 s mesurées, la manche s'arrête à 300 s) ; variantes : sans `--vue-unique --zoom` (écran scindé), avec `--2d` (vue de dessus).
- Duel contre le bot (le vrai jeu, vrai bot NORMAL, J1 = le « joueur type honnête » de `banc_bot_duel.gd`, carte `default`, sans jamais remettre au calme) : `… --headless --path . --fixed-fps 60 --script res://tools/mesure_sim.gd -- --no-eos --scenario=bots --secondes=300 [--2d] --json=<json>`.
- Solo, l'aventure jouée au vrai corps (J1 joueur type + PNJ, PV du joueur et des PNJ remis au plein à chaque image pour que la salle dure) : `… --script res://tools/mesure_sim.gd -- --no-eos --scenario=solo --chapitre=N --salle=9 --secondes=180`
  (la salle 9 est l'avant-dernière : « La salle pleine » — chapitre 0 : 6 PNJ sur 24×24 cases ; chapitre 7 : 4 PNJ, 50×36 ; chapitre 8 : 7 PNJ, 100×80 ; la 10e est le boss).
- Au repos : `--scenario=repos --secondes=60` ; départ et mort : `--scenario=depart --secondes=8` / `--scenario=mort --secondes=25`.
Durées d'horloge : 44 à 128 s par scénario ; load average 1,0 à 1,7 pendant les lancements (un cœur pour Godot, le reste pour les agents de lecture de l'audit) — voir les `.meta`.

**Coût d'une image (ms, horloge murale ; les 30 premières secondes simulées sont exclues des statistiques ; `i/s` = 1000 / moyenne).**

| Scénario | images | moyenne | p50 | p99 | p99,9 | max | pas de physique moy / p99 | reste moy / p99 | i/s atteignables |
|---|---|---|---|---|---|---|---|---|---|
| Au repos (iso, rien ne se passe) | 3 599 | 1,94 | 1,78 | 4,35 | 8,77 | 9,4 | 0,14 / 0,29 | 1,80 / 3,86 | 516 |
| **PvP — banc du projet, vue unique iso, fusée** (prise 1) | 15 719 | **3,79** | 3,47 | 7,85 | 12,42 | 19,7 | non séparé (*) | non séparé (*) | 264 |
| idem (prise 2, avec séparation) | 15 719 | **4,26** | 3,96 | 8,76 | 12,57 | 38,6 | 0,72 / 1,51 | 3,54 / 7,38 | 235 |
| PvP écran scindé iso | 15 719 | 4,43 | 4,06 | 8,78 | 14,29 | 23,1 | (*) | (*) | 226 |
| PvP vue unique **vue de dessus** (`--2d`) | 15 719 | **2,17** | 1,98 | 4,82 | 9,50 | 13,4 | (*) | (*) | 461 |
| *Reprise en miroir A B B A (même commande, 2e lot, `etape4b.sh`) :* iso unique, prises a et b | 15 719 | **4,89 / 4,57** | 4,71 / 4,36 | 9,14 / 8,70 | 13,8 / 14,8 | 20,3 / 31,3 | 0,81 / 1,64 · 0,77 / 1,54 | 4,08 / 7,82 · 3,81 / 7,35 | 204 / 219 |
| idem vue de dessus `--2d`, prises a et b | 15 719 | **2,27 / 2,20** | 2,07 / 2,02 | 4,74 / 4,62 | 9,2 / 9,2 | 16,7 / 22,0 | 0,62 / 1,28 · 0,60 / 1,25 | 1,65 / 3,51 · 1,59 / 3,44 | 440 / 455 |
| idem écran scindé iso | 15 719 | 5,47 | 5,23 | 10,40 | 15,81 | 22,2 | 0,86 / 1,95 | 4,61 / 9,04 | 183 |
| idem iso unique **sans la fusée** | 15 719 | **3,93** | 3,66 | 7,88 | 12,20 | 26,6 | 0,65 / 1,34 | 3,28 / 6,65 | 254 |
| Duel contre le bot, iso (300 s) | 17 999 | **5,84** | 5,38 | 13,19 | 18,77 | 24,6 (+ 128,9 à l'image 0) | 1,27 / 5,97 | 4,57 / 10,13 | 171 |
| Duel contre le bot, `--2d` | 17 999 | 3,85 | 3,40 | 10,21 | 14,88 | 18,1 | 1,19 / 5,29 | 2,66 / 6,83 | 260 |
| Solo ch. 0, salle 9 (6 PNJ) | 10 799 | 7,15 | 6,75 | 14,50 | 20,66 | 33,4 (+ 114,8) | 1,86 / 6,30 | 5,29 / 10,22 | 140 |
| Solo ch. 7, salle 9 (4 PNJ, 50×36) | 10 799 | 10,02 | 9,48 | 18,79 | 23,01 | 29,7 (+ 109,3) | 3,33 / 8,68 | 6,68 / 12,19 | 100 |
| **Solo ch. 8, salle 9 (7 PNJ, 100×80)** | 10 799 | **11,43** | 10,82 | 20,90 | 31,63 | 64,9 (+ 109,4) | 4,08 / 11,07 | 7,35 / 13,01 | **88** |

(*) la séparation physique / reste n'était pas armée sur la première série des bancs (le moteur ne livre pas `--fixed-fps` dans `OS.get_cmdline_args()` : le test de l'instrument était faux) ; corrigé pour la prise 2 et les suivantes. Le « max » exclut l'image 0 (le départ de la manche : 110 à 130 ms) là où c'est écrit.
Les maxima isolés (20 à 65 ms, non reproductibles d'une prise à l'autre : 19,7 ms à 253 s dans la prise 1, 38,6 ms à 127 s dans la prise 2) viennent de la machine partagée (contention, vol de temps), pas du jeu : **ne lire que moyenne, médiane et p99**.
Bruit entre deux prises identiques (même commande) : 3,79 contre 4,26 ms, soit ±6 %.

Les moniteurs du moteur, pour mémoire, **moyenne et maximum de MAXIMA PAR SECONDE** (`TIME_PROCESS` / `TIME_PHYSICS_PROCESS`, ms) : PvP iso 9,7-10,0 / 18,6-20,1 et 3,1-3,3 / 8,8-33,7 ; duel contre le bot 11,6 / 18,1 et 7,4 / 16,3 ; solo ch. 0 / 7 / 8 : 12,1 / 25,3, 12,7 / 23,3, 13,8 / 40,1 et 7,7 / 22,7, 9,4 / 16,9, 13,0 / 61,0.
Physique 2D (compte, moyenne / max) : PvP 21 / 26 corps actifs, 27 / 34 paires ; duel contre le bot 67 / 202 corps (les particules à collision, pic aux salves), 28 / 370 paires ; solo ch. 8 : 125 / 207 corps, 124 / 210 paires.

**Lecture.**
1. **La couche iso coûte ≈ 1,6 à 2,6 ms de CPU par image — elle DOUBLE l'image CPU —, avant tout GPU.** À charge égale (même banc, même machine) : PvP 3,79 / 4,26 puis 4,89 / 4,57 ms en iso (4 prises, moyenne 4,38, ±12 % d'une prise à l'autre : la machine partagée) contre 2,17 / 2,27 / 2,20 ms en vue de dessus (3 prises, moyenne 2,21, ±2,5 %) : **+2,2 ms, rapport ≈ 2,0** ; duel contre le bot 5,84 contre 3,85 ms (+2,0 ms, rapport 1,5). C'est 35 à 50 % de l'image CPU en iso : `Presentation3D._process` seule en prend 0,47 (section 7.2), puis `IsoVolumes`, `MiroirsIso`, les poussées d'uniformes
   et de maillages, les capteurs de corps, la peinture iso (re-rendue 15,6 fois par seconde dans le duel contre le bot : 1 636 rendus en 105 s). **L'écran scindé ajoute 0,2 à 0,9 ms** (4,43 et 5,47 contre 4,38 en moyenne) : la seconde vue se suit mais n'est presque pas dessinée en headless. **La fusée coûte ≈ 0,8 ms de CPU par image** quand elle brûle (3,93 sans elle contre 4,73 avec — les deux prises iso du même lot ; 17 % de l'image, une prise sans fusée seulement : ±0,3 ms de bruit) : son volume voxel, ses lueurs et sa fumée sont des scripts avant d'être des pixels.
2. **Le plancher CPU du jeu en iso est de 1,8 à 1,9 ms par image « au repos »** (scène montée, personne ne bouge : 0,14 ms de physique, 1,80 ms de « reste »). Un duel scripté en prend 3,8 à 4,3 ; un vrai duel contre le bot 5,8 ; les salles de solo 7,2 à 11,4 ms.
   Rapporté au budget d'image : la cible du projet est un **1 % bas ≥ 60 i/s, c'est-à-dire un p99 d'image ≤ 16,7 ms** (ancienne cible : 120 i/s, 8,33 ms). **Le p99 de la salle 9 du chapitre 8 est de 20,9 ms et celui du chapitre 7 de 18,8 ms, sans aucun rendu, sur ce conteneur** : le CPU seul dépasse la cible sur ces deux salles
   (chapitre 0 : 14,5 ms ; duel contre le bot : 13,2 ms ; PvP : 7,9-8,8 ms). En moyenne, 11,4 ms par image au chapitre 8 (88 i/s atteignables, 137 % d'un budget à 120 i/s) et 10,0 ms au chapitre 7 (100 i/s). Sur le Mac, si GDScript y va 1,5 à 2 fois plus vite
   (ESTIMÉ, non mesuré), ce serait ≈ 5,7-7,6 ms de moyenne et ≈ 10-14 ms de p99 au chapitre 8 : sous la cible, mais sans marge pour un pilote ou un GPU lents, et loin d'être négligeable. Le coût suit ici la taille de la carte, pas le nombre de PNJ (24×24 : 7,15 ms avec 6 PNJ ; 50×36 : 10,0 ms avec 4 PNJ ; 100×80 : 11,4 ms avec 7 PNJ) : une corrélation à trois points, **non attribuée** (le banc à 0 / 3 / 7 PNJ est prêt : § 8) ; le pas de physique va de 1,9 à 4,1 ms, le reste de 5,3 à 7,4 ms.
   **Non attribué ici** : où va ce temps dans le solo (perception des PNJ, rayons, lumières, peinture iso de 39 Mo sur la carte 100×80). C'est le sujet d'un banc par soustraction, pas de cette mesure.
3. **65 à 85 % de l'image CPU est du `_process` / dessin factice / audio, le reste du pas de physique** (PvP : 0,72 ms de pas de physique contre 3,54 ms de reste, soit 83 % ; duel contre le bot : 1,27 contre 4,57, 78 % ; solo ch. 8 : 4,08 contre 7,35, 64 %) : l'effort de réduction le plus rentable est côté `_process` / UI / iso ; la physique pèse davantage dans le solo (PNJ, particules à collision).

### 4.1 Dérive sur une manche de 5 minutes — pas de fuite, des plateaux

Séries relevées toutes les 5 s de jeu (`sim_*.json`), pente par minute au sens des moindres carrés dès t = 30 s puis dès t = 120 s :

| Scénario | nœuds : t = 0 → 30 s → 120 s → fin | traces au sol (groupes) | mémoire statique (Mo) : t = 0 → 120 s → fin | RSS | orphelins |
|---|---|---|---|---|---|
| PvP iso (262 s) | 2 875 → 2 875 → 2 875 → 2 875 (plat) | 102 (plat, au plafond du banc) | 239,0 → 241,2 → 243,6 (**+1,1 Mo/min, linéaire**) | 401 Mo, **constant au ko près** | 9 (0 en écran scindé), inchangé depuis t = 0 |
| Duel contre le bot iso (300 s) | 2 749 → 3 250 → 3 779 → 3 749 | 0 → 472 → 988 → 989 (**plafond 990** atteint à ~100 s) | 228,2 → 249,6 → 249,4 (**plat dès 120 s : +0,1 Mo/min**) | 401 Mo (+1,6 ko/min) | 9 |
| Duel contre le bot `--2d` | 2 646 → 2 979 → 3 327 → 3 328 | 0 → 324 → 660 → 660 (plafond 660 : pas de copie iso) | 256,4 → 275,5 → 275,9 (+0,2 Mo/min) | 412 Mo | 9 |
| Solo ch. 0 s. 9 (180 s) | 3 194 → 3 582 → 4 148 → 4 187 | 0 → 385 → 951 → 990 | 229,7 → 243,8 → 243,8 (plat) | 396 Mo | 9 |
| Solo ch. 7 s. 9 (180 s) | 3 126 → 3 795 → 3 813 → 3 788 (plat dès t = 30 s) | 646 (plat) | 238,1 → 248,0 → 248,0 | 416 Mo | 9 |
| Solo ch. 8 s. 9 (180 s) | 3 456 → 3 577 → 4 453 → 4 439 | 0 → 106 → 988 → 989 | 260,3 → 274,6 → 274,6 (plat) | 401 Mo | 9 |

- **Aucune fuite de nœuds, d'objets ni d'orphelins.** Les compteurs montent jusqu'à un plafond de traces au sol (990 groupes en iso = (90 éclats + 120 taches + 120 douilles) × 3 copies — J1, J2 et la copie iso ; 660 en `--2d`) puis restent plats pendant les minutes suivantes ; les orphelins valent 9 de t = 0 à la fin dans tous les scénarios sauf l'écran scindé (0) : aucun orphelin n'est créé pendant une manche.
  Le tampon de rejeu reste à 450 instantanés, les particules ≤ 190, les lumières allumées ≤ 18, les balles ≤ 5.
- **Mémoire statique : plate une fois les plafonds atteints** (bots iso : 249,6 → 249,4 Mo de 120 à 290 s). La pente de +1,1 Mo/min du PvP est **très probablement un artefact des instruments** (ESTIMÉ par le décompte, non isolé) : les bancs rangent chacun 5 à 12 relevés par image (`_samples`, `_samples_t`, `_samples_us`, `_appels`… du banc du projet, plus les miens),
  soit ≈ 0,2 ko par image et ≈ 0,8 Mo par minute à 3 600 images par minute ; le PvP n'accumule rien d'autre (nœuds, traces et objets plats : +1,6 à +2 objets/min, +0,9 ressource/min, négligeables). Dans les scénarios sans le banc du projet, la pente après le plateau est ≤ 0,2 Mo/min (relevés de la sonde seule : ≈ 0,15 Mo/min).
  Au repos pendant 55 s : +0,3 Mo (la sonde seule).
- **RSS : 396 à 416 Mo, constant au ko près d'un bout à l'autre de chaque série** (hypothèse : l'allocateur réutilise la mémoire libérée au chargement — l'accroissement de 4 à 21 Mo de mémoire statique, montage compris, ne se voit pas dans le résident). La lecture est vivante (essai : 113 → 318 Mo après avoir touché 200 Mo).
- **Dérive du coût d'image : nulle en PvP** (moyennes par minute 4,57 / 3,99 / 4,50 / 4,23 / 4,50 ms, sans tendance ; 2D : 2,19 / 2,19 / 2,25 / 2,13 / 2,07), **un coût qui monte quand les traces s'accumulent dans les parties où l'on tire vraiment** : solo ch. 8, 9,7 ms (minute 1) → 11,5 → 11,6 ms (traces 106 → 989), solo ch. 0, 6,7 → 7,3 → 7,3 ms
  (385 → 990 traces) ; soit de l'ordre de 1 à 2 µs par groupe de traces et par image au plafond (**ESTIMÉ, non isolé** : le duel contre le bot n'a pas cette tendance — 5,5 / 6,1 / 6,2 / 5,4 / 5,8 — parce que le contenu du combat change d'une minute à l'autre). Le plafond fait que le coût cesse de monter ; il ne dit pas que les 990 groupes sont gratuits.

### 4.2 Les images singulières : le départ d'une manche, la mort, la fin de partie (`--scenario=depart|mort`, iso, écran scindé local → vue unique)

Trois lancements de `mort` et deux de `depart` (journaux `sim_mort_iso*.log`, `sim_depart_iso.log`) :

| Moment | Coût mesuré (ms) | Remarque |
|---|---|---|
| Le geste « rejouer » (appel synchrone, avant la 1re image) | 33 à 61 | arène rebâtie, vues montées |
| **1re image après le geste (départ de la manche)** | **450 à 532** (505 / 532 / 511 / 475 / 450) | puis 4,5-7,6 ms à l'image 1, 2,5-3,9 ms ensuite ; reproductible ; **hors compilation de shaders (headless)** |
| `take_damage` fatal (appel synchrone) | 11 à 16 | |
| Image du coup fatal (impact, fin de manche) | 17 à 27 | `manche = false` à l'image suivante |
| Début de la killcam (image 342-343) | 24 à 35 | |
| **Fin de partie : le panneau de fin apparaît (image 927)** | **86 / 121 / 394** | 394 ms à la première exécution (profil vierge : `match_history.json` n'existait pas), 86-121 ms aux suivantes ; **cause non isolée** (l'archivage — `MatchRecord.append_to_history` relit, complète et réécrit tout le journal en JSON —, la construction de l'écran de fin, des premières fois) ; c'est l'image où le joueur lit « victoire » |

La première image d'une manche (≈ 0,5 s) est de la même famille que les « premières fois » de V1b ; l'attribution fine n'est pas faite ici (aucun profileur de fonctions en headless) ; sous un vrai pilote graphique, la compilation des shaders s'ajoute.

## 5. Étape 5 — compteurs de rendu sous llvmpipe : UNE des quatre configurations mesurée (iso, vue unique)

**Ce qui est mesuré** : la configuration de référence du projet (`--fusee --vue-unique --classe=pompe --zoom=1.5`, iso par défaut, lightmap 1080p), par la sonde de rendu (`sonde_rendu.gd` : `RenderingServer.viewport_get_render_info` à chaque image mesurée, recensement des lumières et des viewports en fin de prise), dans les douze prises de la série P1 (6a ci-dessous) ;
commande : `GODOT=<godot> SCENE=mesure_banc scratchpad/cadence/serie_m.sh scratchpad/plans/p1.txt <dossier> p1` (la prise `p1_01_A`, première de la série, est citée ; les onze autres donnent les mêmes compteurs à ±0,1 %). Les compteurs de rendu ne dépendent pas du matériel (nombre d'appels, d'objets, de primitives, de viewports) : ce sont ceux que verrait le Mac, à la réserve du pilote.
**Non mesurées dans cette session (ordre de la coordination : une série de plus au plus)** : l'écran scindé iso, la vue de dessus en vue unique et la vue de dessus en écran scindé ; la commande qui les mesure est prête : `scratchpad/mesures/etape5.sh` (4 prises, `--sonde --temps-par-vue`, ≈ 9 min), puis `python3 scratchpad/cadence/analyse.py` sur chaque journal.

| compteur (médiane par image, iso, vue unique, 1920×1080) | valeur |
|---|---|
| appels de dessin | **188** (min 184, max 191) |
| objets | **1 403** (1 399-1 406) |
| primitives | **61 556** (61 548-61 562) |
| mémoire vidéo | 282 Mo (textures 267, tampons 15) |
| viewports (racine + SubViewport) | 9 recensés, **6 qui rendent**, **5,76 Mpx** de surface cumulée : racine 2,074 Mpx · lightmap `SubViewport1` (UPDATE_ALWAYS, 1920×1080) 2,074 · `PeintureIso` (1190², UPDATE_ONCE) 1,416 · 3 `CapteurCorps` (256²) 0,197 ; `SubViewport2` (958×1080), `VueIso1/2` (512²) : DISABLED |
| répartition des appels de dessin | racine (3D) 63 objets / 55 780 primitives / 63 appels · lightmap 2D `SubViewport1` : 1 113 objets / 4 518 primitives / 55 appels · `PeintureIso` 751 / 3 794 / 40 (re-rendue 6 fois en 110 s, 12 traces peintes) · chaque `CapteurCorps` 1 / 30 / 1 |
| lumières 2D | 254 `PointLight2D` dans l'arbre dont **8 allumées, 7 à ombre** (2 torches 936 px, 2 rétrodiffusions 256 px, 2 halos de proximité 150 px, le halo de la fusée 440 px, la LED des murs) ; 14 `LightOccluder2D` (176 sommets) |
| modèle de passes d'ombre du banc (« 4 × occulteurs × lampes à ombre », par viewport qui les dessine) | lightmap 168 · capteur J1 144 · capteur J2 144 · `PeintureIso` 168 · capteur de la fusée 168 = **792 arêtes d'ombre par image** |
| lampes qui « n'éclairent AUCUN objet de ce viewport » (recensement du banc) | **7 sur 7 dans `PeintureIso`**, 4 dans le capteur de la fusée, 1 dans chacun des deux capteurs de corps et dans la lightmap (14 couples lampe-viewport) : de la passe d'ombre calculée pour rien (constat LUM-03 de V8, ici compté par le banc lui-même) |
| image sous llvmpipe | 543 ms en moyenne (1,8 i/s) — **non transposable au Mac** ; le banc dit « Verdict 60 fps : NON TENU » : c'est le rendu logiciel, pas une mesure du jeu |

**Lecture.** Le rendu iso d'une vue unique, c'est **188 appels de dessin par image** (médiane globale ; par viewport, médianes NON additives — la peinture ne se rend que 6 fois en 110 s : 63 pour la 3D de la racine, 67 pour son interface, 55 pour la lightmap 2D, 40 pour la peinture) mais **61 556 primitives, dont 55 780 (91 %) dans la seule passe 3D de la racine** — les murs, le sol et les volumes —, pour **5,76 Mpx de surface de rendu cumulée par image (2,8 fois l'écran)**. Le nombre d'appels est modeste ; ce qui pèse sur un GPU à tuiles est la
surface (deux passes à la taille de l'écran, racine et lightmap, plus la peinture à 1,4 Mpx) et le nombre de coupures de passe (les `BackBufferCopy` : 2 visibles en fin de prise dans la charge de référence). Le coût des ombres (792 arêtes par image) n'est pas compté dans les appels de dessin (règle du moteur : une passe d'ombre se recalcule par viewport pour toute lampe à ombre qui le recoupe).

## 6. Étape 6 — décomposition de l'image sous llvmpipe (rapports entre variantes, `--physique 8`, miroir)

**Méthode du projet, reprise telle quelle** (`tools/cadence_cloud/` : `prise.sh`, `serie.sh`, `analyse.py`, `verdict.py`, `porte.py` ; mes copies dans `scratchpad/cadence/`, qui ajoutent seulement trois paramètres — le binaire, la scène du banc, les drapeaux de base — et la sonde de rendu) : Xvfb 1920×1080 + Mesa llvmpipe, `--physique 8` (sans lui l'image plafonne à 133,3 ms), **moyenne** et non médiane,
30 s de chauffe + 45 s de mesure, `--fusee --vue-unique --classe=pompe --zoom=1.5` (le banc `--vue-unique` joue au zoom de l'écran scindé ×1,25 : `--zoom=1.5` donne le cadrage d'une vraie vue unique), foyer isolé, cache Mesa conservé, **porte stricte** (une prise est refusée si un autre processus dépasse 20 % d'un cœur ou si un autre Godot/Xvfb tourne : elle est refaite, deux fois au plus),
ordre en MIROIR (A B C … C B A). Une prise = ~2 min ; une image coûte 300-600 ms sous llvmpipe : **seuls les RAPPORTS entre variantes d'une même série ont un sens ; rien ne dit ce que voit le M3 (GPU à tuiles, appels de pilote, `BackBufferCopy` qui coupe une passe) — d'où les compteurs indépendants du matériel.**
Un accident à ne pas répéter : une commande de ma part (`strings` sur le binaire de Godot) a tourné pendant la 2e prise de P1 ; la porte l'a refusée (`strings 60 %`) et la série l'a refaite — le dispositif de refus a donc fonctionné.

### 6a. Le plancher d'auto-éblouissement (Q81 de OMBRES ; précisions de V8 § 1.4)

**Constat de départ.** Torche allumée, un joueur au repos tient `dazzle_amount = 0,0600` (`Eblouissement.RETRODIFFUSION`, atteint en 48 ms) : la rétrodiffusion de sa PROPRE torche. Quatre éléments lisent ce niveau et se paient en permanence : **le flou, sa copie de tampon et le halo** (`BrouillageVue.maj` : `_flou`, `_copie`, `_halo` — tous trois passent par `Brouillage._dose`) et **le voile d'éblouissement** (`UI._poser_voile`). Variantes gelées (aucun fichier du dépôt modifié ; `arbres/*.diff`, calquées sur les points d'ancrage de V8 : `brouillage_vue.gd` ligne 193 et `ui.gd` ligne 2536, jamais `Player.dazzle_amount` que la pénalité de vitesse lit brut ; seuil 0,06 + 10⁻³) :
- **A1** — dans `BrouillageVue.maj`, un niveau ≤ 0,0601 vaut 0 : le flou, sa copie de tampon et le halo s'éteignent au repos ;
- **A2** — dans `UI._poser_voile`, un niveau ≤ 0,0601 vaut 0 ET le `ColorRect` du voile prend `modulate.a = 0` (le moteur écarte l'item du dessin : modulation < 0,007 ; le rectangle garde sa place dans le `HBoxContainer`, comme l'exige le commentaire de `_forger_voile`) — **la borne HAUTE du gain du voile** : le voile n'est plus dessiné du tout ;
- **A2q** — dans `UI._poser_voile`, un niveau ≤ 0,0601 vaut 0, **le voile reste dessiné** (le quad plein écran, shader calme à niveau 0) : la lecture de V8, « corps calme moins quad vide », c'est-à-dire ce que ferait le code si le plancher était simplement mis à zéro ;
- **A12** — A1 + A2.

**Preuve indépendante du matériel (headless ; `tools/preuve_flou.gd`, `mesures/preuve_*.log`).** Le vrai jeu monté (iso, vue unique), torches tenues par la gâchette (`Input.action_press`, comme le banc de cadence), au repos 3 s ; on relit l'état du graphe de scène :

| arbre | `dazzle_amount` J1 / J2 | `_flou` / `_copie` (BackBufferCopy) / `_halo` visibles | voile de J1 | `BackBufferCopy` visibles dans l'arbre | `CanvasItem` visibles qui lisent l'écran (texte `hint_screen_texture` ; le voile calme y figure par son texte) |
|---|---|---|---|---|---|
| **A (dépôt)** | 0,0600 / 0,0600 | **oui / oui / oui** (force 0,12, noyau 34 px) | dessiné, matériau CALME, niveau 0,06 | **1** (`CopieEcran`) | **2** (`VoileP1`, `Flou`) |
| A (dépôt), **torches éteintes** (témoin) | 0 / 0 | non / non / non | dessiné, CALME, niveau 0 | **0** | 1 (`VoileP1`) |
| **A1** | 0,0600 / 0,0600 | **non / non / non** | dessiné, CALME, niveau 0,06 | **0** | 1 (`VoileP1`) |
| A2 | 0,0600 / 0,0600 | oui / oui / oui | **non dessiné** (`modulate.a = 0`), niveau 0 | 1 | 1 (`Flou`) |
| A2q | 0,0600 / 0,0600 | oui / oui / oui | dessiné, CALME, niveau 0 | 1 | 2 |
| **A12** | 0,0600 / 0,0600 | non / non / non | non dessiné | **0** | **0** |

→ **Le constat est PROUVÉ sans GPU** : torche allumée au repos, le dépôt entretient **un `BackBufferCopy` (une copie de tampon d'écran en pleine passe) et un `CanvasItem` qui relit l'écran (`Flou`, un ColorRect à shader d'ellipse de 22,8 px de rayon autour de la torche) plus le halo, en permanence** ; **A1 les supprime et ramène l'état « torche allumée » à l'état « torche éteinte »** (tout à `non`, 0 copie), A12 ne laisse plus rien. Sur un GPU à tuiles
(le Mac), un `BackBufferCopy` au milieu d'une passe force une coupure de passe de rendu : **c'est ce coût, que llvmpipe ne montre pas, que cette preuve établit comme PRÉSENT à chaque image** ; son montant sur le M3 n'est pas mesurable ici. Le voile reste dessiné en A, A1 et A2q (le quad plein écran, calme) ; il ne disparaît qu'en A2/A12 (modulation 0), borne haute.
**Temps sous llvmpipe, 1re série (P1 : la charge de référence du projet, `--fusee --vue-unique --classe=pompe --zoom=1.5`, miroir A A12 A1 A2 A2q A2q A2 A1 A12 A ; commande de `serie_m.sh` ; 12 prises dont 2 refusées par la porte — `strings`, `git` d'autres processus — et refaites).**

| variante | prises (moyenne d'image, ms) | moyenne | écart à A |
|---|---|---|---|
| A (dépôt) | 543,8 / 555,6 | 549,7 | — |
| A12 (flou + voile) | 551,4 / 551,5 | 551,4 | +1,7 ms (+0,3 %) |
| A1 (flou seul) | 573,4 / 536,7 | 555,1 | +5,4 ms (+1,0 %) |
| A2 (voile non dessiné) | 530,7 / 546,8 | 538,7 | −10,9 ms (−2,0 %) |
| A2q (voile niveau 0, dessiné) | 528,4 / 543,4 | 535,9 | −13,8 ms (−2,5 %) |

Le bruit entre deux prises de la même variante est de 0,1 à 37 ms (±3 % : A 11,8 ; A1 36,7 ; A2 16,1 ; A2q 15,0) : **aucun écart n'est lisible** — comme V8 l'annonçait pour le flou (la coupure de passe d'un GPU à tuiles n'existe pas en rendu logiciel). **Mais ce banc n'est pas le bon : dans la charge de référence les deux joueurs se visent torches allumées et tirent en permanence, ils s'éblouissent donc EN PERMANENCE au-dessus du plancher** — le recensement de fin de prise le dit, identique dans les cinq arbres (`BackBufferCopy visibles : 2 (VoileBB, CopieEcran)`, flou visible) : les retouches, qui ne jouent que pour un niveau ≤ 0,0601, y servent peu. La série 6a-bis ci-dessous refait la mesure dans la scène qui porte le plancher.

**6a-bis. La scène qui porte le plancher — P1b (`--v-repos --M-sans-fusee`).** Variante par réflexion `--v-repos` (`variantes_reflexion.gd`) : à chaque pas de physique, **J2 est CACHÉ** (hors jeu, comme à l'entraînement : `GameState._en_jeu(j)` l'écarte de `_sources_eblouissantes()`, donc plus aucune torche adverse n'éblouit J1) et le délai de tir de J1 et de J2 est tenu haut (plus un tir, donc plus un flash) ; avec `--M-sans-fusee`
(plus de fusée), **la seule source d'éblouissement de J1 est sa PROPRE torche : 0,0600 constant** — c'est le plancher, nu. (Un premier essai où J1 et J2 se tournaient le dos ne neutralisait rien : l'éblouissement se calcule dans `GameState._process`, après le `_process` du banc qui re-vise ; ses 2 prises sont archivées dans `mesures/p1b_invalide/`.)
Commande : `GODOT=<godot> SCENE=mesure_banc scratchpad/cadence/serie_m.sh scratchpad/plans/p1b.txt scratchpad/mesures/p1b p1b` ; dix prises en miroir A A12 A1 A2 A2q A2q A2 A1 A12 A, 1 920×1080, 75 s chacune (30 s de chauffe + 45 s), **aucune refusée par la porte** (aucun processus étranger au-dessus de 18 % d'un cœur — c'est l'agent lui-même —, aucun autre Godot ; la charge approche 4 : llvmpipe occupe les quatre cœurs). La sonde compte, À CHAQUE IMAGE, les `BackBufferCopy` visibles et les `CanvasItem` visibles qui lisent l'écran.

| variante | prises (moyenne d'image, ms) | moyenne | **écart à A** | `BackBufferCopy` visibles par image | lecteurs d'écran visibles par image (texte `hint_screen_texture`) | appels de dessin |
|---|---|---|---|---|---|---|
| **A (dépôt)** | 307,8 / 320,8 | **314,3** | — | **1,00** (`CopieEcran`) | **2,00** (`VoileP1` calme, `Flou`) | 127 |
| **A1** (flou + copie + halo à 0) | 310,5 / 316,2 | 313,4 | **−0,9 ms (−0,3 %)** : nul | **0,00** | 1,00 | 125 |
| **A2** (voile à 0, non dessiné) | 260,3 / 265,7 | 263,0 | **−51,3 ms (−16,3 %)** | 1,00 | 1,00 | 127 |
| **A2q** (voile à 0, le quad reste dessiné) | 270,3 / 265,8 | 268,0 | **−46,3 ms (−14,7 %)** | 1,00 | 2,00 | 128 |
| **A12** (tout) | 260,4 / 281,5 | 271,0 | **−43,3 ms (−13,8 %)** | **0,00** | **0,00** | 125 |

**Lecture.**
1. **Les compteurs en fenêtre retrouvent à l'unité ceux de la preuve headless** (A : une copie et deux lecteurs d'écran en permanence ; A1 : plus de copie ; A12 : plus rien) — **le plancher d'auto-éblouissement entretient, torche allumée, une copie de tampon d'écran, un ColorRect qui relit l'écran et un halo à CHAQUE image**, et A1/A12 les suppriment (−2 appels de dessin : le flou et le halo). C'est la preuve indépendante du matériel que V8 demandait ; son coût sur le M3 (coupure de passe) n'est pas mesurable ici.
2. **Le flou, sa copie et son halo (A1) ne coûtent RIEN sous llvmpipe : −0,9 ms sur 314 (−0,3 %), bien dans le bruit** (±2 % entre prises d'une même variante : A 307,8 / 320,8) — exactement ce que V8 annonçait : en rendu logiciel la copie est un `memcpy` et la coupure de passe n'existe pas. **Ce zéro n'infirme pas LUM-01 ; il ne la confirme pas non plus : le coût de la copie sur le GPU à tuiles du Mac est NON MESURÉ.**
3. **Le voile « calme » (A2, A2q) coûte, lui, 13 à 16 % de l'image sous llvmpipe** : −51,3 ms (voile non dessiné) et −46,3 ms (voile dessiné à niveau 0) sur 314. **Presque tout le gain est dans le corps du shader calme à 0,06, pas dans le quad** : poser le niveau à 0 en laissant le quad plein écran (A2q, la lecture de V8, « corps calme moins quad vide ») retire 46 ms ; ne plus dessiner le quad (A2) en retire 5 de plus (dans le bruit ; et le compteur d'appels de dessin ne baisse pas pour A2 : 127 / 127 contre 128 / 127 pour A, alors que le moteur est censé écarter un item de modulation < 0,007 — l'écart A2 / A2q est donc sans conséquence pour la lecture). Cohérent avec SHA-03 (V8) : le voile calme exécute son corps complet sur toute la fenêtre, torche allumée, et le shader sort vite à niveau 0. Sous llvmpipe (ALU par fragment sur CPU, 2,07 Mpx) c'est ≈ 22 ns par fragment.
4. **Transposition au Mac : le RAPPORT n'est pas celui du M3.** Un GPU récent exécute 2 Mpx de fragments simples en une fraction de milliseconde ; les 13-16 % de llvmpipe sont un fait de rendu logiciel. **Ce qui est établi** : (i) le coût existe et vient du corps du shader au niveau de repos ; (ii) il disparaît à niveau 0 sans changer le quad ; (iii) mettre le plancher à 0 pour le voile ne modifie ni la vitesse, ni la visée (le patch est dans `UI._poser_voile`, pas dans `Player.dazzle_amount`). **Ce qui ne l'est pas** : son montant sur le M3.
5. **Contraintes (V8 § 1.4)** : le hoquet de première compilation du flou (LUM-05) se déplacerait du premier allumage de torche au premier éblouissement réel ; chez le client, l'ancrage de repos du flou sur l'adversaire disparaît (D2) ; `test_classes._test_ancrage_des_effets` lit le texte de `brouillage_vue.gd` et de `game_state.gd` (ne pas y toucher) ; le plancher valait exactement 0,0600, seuil posé à 0,0601.
6. **Dans la charge de référence (P1, 1re série), le gain est de −2 % et non significatif** : les deux joueurs s'y éblouissent en permanence au-dessus du plancher, le voile y est « plein » et la retouche ne joue pas. **Le gain réel dépend donc de la part du temps passée au plancher** — l'état de tout joueur qui n'est pas dans le faisceau adverse — et il est borné par ces −13 à −16 % (rendu logiciel).

### 6c. L'arène rendue sous le menu du hub (V2 B7 / MEN-04 ; `game_state.gd` ~5905 et ~6464 : vp1/vp2 en UPDATE_ALWAYS derrière le rideau) — P4

**Variante** `--v-sans-arene-menu` (`variantes_reflexion.gd`) : à chaque image, `vp1` et `vp2` (les deux `SubViewport` qui rendent l'arène) en `UPDATE_DISABLED` — ce que ferait le jeu s'il les arrêtait quand le hub est ouvert. **Banc** : le banc des menus du projet (`bench_framerate.gd --menus` : le hub ouvert, ses neuf effets de vitrine actifs, un curseur qui parcourt les entrées sans jamais s'arrêter et change d'écran toutes les 1,2 s), analysé par ses propres chiffres (`ANALYSE_HUB=1`, ma copie d'`analyse.py` : ce banc ne date pas les images). 30 s de chauffe + 30 s de mesure, 1 920×1080, miroir A B B A A B B A, 8 prises, aucune refusée.
Commande : `ANALYSE_HUB=1 BASE_ARGS="--menus" SECONDES=30 GODOT=<godot> SCENE=mesure_banc scratchpad/cadence/serie_m.sh scratchpad/plans/p4.txt scratchpad/mesures/p4 p4`.

| | prises (moyenne d'image, ms) | moyenne | appels de dessin | objets | primitives | viewports qui rendent / surface | mémoire vidéo |
|---|---|---|---|---|---|---|---|
| **A (dépôt) : l'arène rendue sous le menu** | 163,6 / 167,6 / 172,0 / 165,4 (6,0 i/s) | **167,2** | **112-113** | **2 176-2 209** | **10 342-10 446** | **3 / 4,14 Mpx** (racine 2,07 + vp1 + vp2) | 204,8 Mo |
| **B : vp1 / vp2 en UPDATE_DISABLED** | 111,9 / 112,7 / 107,9 / 111,1 (9,0 i/s) | **110,9** | **73-75** | **597-664** | **2 554-2 716** | **1 / 2,07 Mpx** | 188,7 Mo |
| **écart** | | **−56,3 ms (−33,7 %)**, soit ×1,51 en cadence | −39 (−35 %) | −1 540 (−72 %) | −7 800 (−75 %) | −2 viewports, −2,07 Mpx | −16 Mo |

**Lecture.**
1. **Confirmé : au hub, `vp1.render_target_update_mode = vp2 = UPDATE_ALWAYS`** (état relevé en headless, 7.2 A, et en fenêtre) — l'arène 2D, ses ~1 500 objets et ses ~7 800 primitives, est rendue à chaque image derrière le menu, **moitié gauche et moitié droite**, puis recouverte.
2. **Sous llvmpipe c'est le tiers de l'image du hub (−56 ms sur 167)** ; l'écart (56 ms) vaut 7 à 12 fois la dispersion entre prises d'une même variante (A : 163,6-172,0, soit 8,4 ms ; B : 107,9-112,7, soit 4,8 ms). Les compteurs, eux, ne dépendent pas du matériel : **−72 % d'objets, −75 % de primitives, la moitié de la surface de rendu** (4,14 → 2,07 Mpx), −16 Mo de mémoire vidéo (les deux cibles de rendu des moitiés).
3. **Transposition au Mac : le rapport n'est pas celui du M3**, mais l'existence et l'échelle du travail le sont : deux passes de rendu de ≈ 1 Mpx chacune, avec leurs textures de lightmap, pour une scène recouverte à 96 % (le rideau). V2 chiffrait ce poste à ≈ 3 ms au menu (ESTIMÉ, B7) ; **non mesuré sur GPU à tuiles**.
4. **Contraintes à régler avant de couper** (non mesurées) : l'arène derrière le rideau cesserait de se mettre à jour (le 4 % qui reste visible serait une image figée — décision d'aspect pour Adrien) ; le retour du hub au jeu doit rallumer les deux viewports dans la même image (`_accorder_rendu_aux_vues`) ; le banc des menus cycle sur les écrans « accueil, local, amical, classe, custom » (`MEN-09` : identifiants éventuellement périmés — `hub.reset()` en repli — le banc ne le dit pas) ; ce banc n'a ni manche ni classe.

### 6b et 6d — NON MESURÉES (6b : la fumée de la fusée ; 6d : D1, l'atlas des textures de lumière)

Sur ordre de la coordination (une seule série de plus après 6a). Leurs plans et leurs variantes sont prêts ; la commande de chacune et ce que sa lecture dirait sont au § 8. Côté CPU, la fusée est déjà mesurée : ≈ 0,8 ms par image (étape 4).

## 7. Bancs CPU ciblés (headless, `--fixed-fps 60`) — V3 « l'image d'impact », V2 « ce qui calcule sans qu'on le voie »

Même méthode et mêmes réserves que l'étape 4 (rendu et audio factices, horloge murale entre deux images, pas de GPU, Xeon 2,8 GHz plus lent que le M3 : **les rapports comptent, les millisecondes ne se comparent pas à celles du Mac**).
Instruments (non commités, copiés dans `tools/` du worktree, sources dans `scratchpad/sonde/`) : `banc_image_impact.gd`, `banc_ui_cachee.gd`, `micro_particules.gd` ; scripts `etape_v3v2.sh`, `etape_h1.sh` ; journaux `mesures/v3_*.log`, `v2_*.log`, `v2h1_*.log`, `micro_particules_*.log`.

### 7.1 V3 — l'image d'impact d'une volée de pompe (`audit/V_V3.md` § 5)

**Montage.** Le protocole de V3 : `main.tscn` monté en iso (vue unique) ou en vue de dessus, deux joueurs au pompe, J1 et J2 immobiles ; **le tir est lancé depuis la passe de physique d'un nœud assistant posé après `main`** (`Player.shoot()`, le vrai geste : douille, flash, plombs,
rejeu), comme `Player._physics_process` le fait en jeu — `Engine.is_in_physics_frame()` y est vrai, donc les rayons d'occlusion sonores partent comme en jeu. Une volée par seconde de jeu, 10 de chauffe (imprimées à part, jetées) puis 40 mesurées. Coût d'une image = écart d'horloge entre deux `physics_frame`
(physique des nœuds + pas du serveur de physique + `_process` + dessin factice + audio). **Fond** local de chaque volée = médiane des images tir+12 à tir+54 ; **surcoût** = image − fond, médiane / p90 / max sur les 40 volées. Murs : un `StaticBody2D` sur la couche des murs à D px du canon ; corps : J2 posé à D px,
**vie portée à 10⁹ à chaque volée** (une volée de contact tuerait J2 et ferait finir la manche). Auto-contrôle de chaque prise : particules, sons, nœuds et traces créés dans l'image du tir et dans l'image d'impact (il doit retrouver 12 × plombs étincelles ou 25 × touches gouttes).
Commande : `Godot_v4.7.1-stable_linux.x86_64 --headless --path . --fixed-fps 60 --script res://tools/banc_image_impact.gd -- --no-eos --scenario=mur|corps|vide --distance=<px> [--iso=0] [--sans=particules|liseres|rayons] [--plafond=1]` ; 17 prises de 14 à 26 s, load average 0,4 à 1,2.

**Résultats (iso sauf mention).** Tous les chiffres sont des **millisecondes de surcoût sur l'image où le tir part** ; l'image d'impact est la MÊME image (voir 1.).

| Cas | fond | surcoût de l'image du tir : médiane / p90 / max | cumulé sur les 10 images [tir, tir+9] (médiane / p90) | auto-contrôle : particules, sons dans l'image |
|---|---|---|---|---|
| tir dans le vide (aucun obstacle à moins de 400 px) | 2,07 | **+0,64** / +1,87 / +2,9 | +3,5 / +10,1 | 0, 0 |
| mur à 165 px du canon (**1 plomb** touche) | 2,19 | **+3,16** / +4,92 / +9,8 | +13,1 / +22,9 | +12, +1 |
| mur à 120 px (**3 plombs**) | 2,74 | **+5,76** / +8,09 / +12,0 | +15,4 / +24,5 | +36, +3 |
| mur à 40 px (**5 plombs**), prise a puis prise b | 3,33 / 2,97 | **+8,60** / +12,9 / +17,2 puis **+8,01** / +9,5 / +14,8 | +21,6 / +31,9 puis +19,1 / +29,8 | +60, +5 |
| corps, centre de J2 à 168 px du canon (1 touche) | 3,09 | **+5,08** / +8,08 / +10,9 | +13,4 / +24,4 | +25, +2 |
| corps, centre à 93 px (1 touche) | 2,76 | **+4,93** / +10,2 / +16,0 | +12,6 / +26,3 | +25, +2 |
| corps, centre à 68 px (1 touche) | 3,18 | **+5,25** / +7,02 / +11,4 | +13,9 / +20,4 | +25, +2 |
| corps, centre à 42 px (**3 touches**) | 5,41 | **+12,4** / +17,5 / +24,2 | +30,2 / +54,3 | +70, +6 |
| corps, centre à 30 px (**5 touches**, contact) | 5,92 | **+18,0** / +20,1 / +30,1 | +28,5 / +42,8 | +22 (*), +10 |
| **vue de dessus** : mur à 40 px (5 plombs) | 2,16 | **+6,74** / +9,89 / +12,7 | +18,5 / +30,2 | +60, +5 |
| vue de dessus : corps (1 touche) | 1,83 | **+4,00** / +6,21 / +9,1 | +9,0 / +14,7 | +25, +2 |
| mur à 40 px **sans particules** (`emit` rendu silencieux) | 2,15 | **+5,43** / +8,49 / +12,7 | +11,6 / +21,8 | 0, +5 |
| mur à 40 px **sans liserés** (`son_localise` déconnecté) | 2,76 | **+7,36** / +10,2 / +14,4 | +16,7 / +30,5 | +60, +5 |
| mur à 40 px **sans rayons d'occlusion** (`occlusion_active = false`) | 2,87 | **+8,67** / +13,4 / +16,3 | +20,0 / +30,1 | +60, +5 |
| mur à 40 px **aux plafonds de traces abaissés à 8** | 2,80 | **+9,53** / +12,4 / +16,4 | +21,8 / +38,5 | +60, +5 |
| corps (1 touche) aux plafonds abaissés à 8 | 2,83 | **+6,42** / +8,66 / +10,1 | +16,6 / +31,0 | +25, +2 |

(*) à ce contact le pool de particules est saturé (voir 6.) : le solde net est écrasé par le recyclage.

**Lecture.**
1. **L'image d'impact est l'image du tir** (question 2 de V3 § 1.5 et § 6) : sur 17 prises et ≈ 600 volées, l'effet (particules, sons, traces) naît dans la même image que `shoot()` (« tir + 0 » dans 100 % des volées où l'impact est repéré). Le mécanisme n'est pas isolé (les plombs sont traités dans la passe où ils naissent, ou leur `_ready` teste le premier pas) ; le banc dit ce que le jeu fait.
   **Les §§ 4.1/4.2 (impact) et 4.4 (tir) de V3 s'ADDITIONNENT donc dans une seule image.**
2. **Les multiplicités de V3 sont confirmées** : 5 / 3 / 1 plombs touchent un mur à 40 / 120 / 165 px (60 / 36 / 12 étincelles, 5 / 3 / 1 sons) ; sur un corps, 5 / 3 / 1 touches à 30 / 42 / 68 px et au-delà (sons ÷ 2 = touches ; 25 gouttes par touche). Les seuils exacts en px dépendent de la référence de D (canon ou centre du tireur) : ceux de V3 (54 et 93 px) se retrouvent à ≈ 25 px près.
3. **Les coûts mesurés sont au HAUT de l'enveloppe de V3 (§ 4, impact + tir)** : mur 1 plomb 3,2 ms (enveloppe 1,4-3,1), 3 plombs 5,8 (2,6-6,0), 5 plombs 8,0-8,6 (3,7-8,8) ; corps 1 touche 4,9-5,3 (2,3-5,5), 3 touches 12,4 (5,3-13,1), 5 touches 18,0 (8,2-20,7). Le tir seul, sans impact : +0,64 ms (V3 : 0,8-1,7, sous le bas). Ce conteneur étant plus lent que le M3, la même enveloppe y ferait ≈ la moitié :
   **ordre de grandeur de V3 confirmé, et son diagnostic (« aucun poste n'explique à lui seul une image à 16 ms ; c'est leur coïncidence ») aussi : un seul plomb de mur coûte 3 ms, une volée de contact sur un corps 18 ms — de l'ordre de la différence entre le fond (2-3 ms) et un 1 % bas de 13-16 ms.**
4. **L'image d'impact n'est que 40 % de la volée : la queue compte** — +1,4 à +2,6 ms à l'image suivante, puis ≈ +1 ms par image pendant 6 à 9 images (avance des particules, copies différées, fondus) : le cumul sur dix images (+19 à +22 ms pour 5 plombs au mur) vaut 2,3 fois l'image d'impact.
5. **Attribution par soustraction (5 plombs au mur, iso ; référence +8,3 ms = moyenne des prises a et b ; cumulé +20,4)** : les particules pèsent **−2,9 ms (35 %)** à l'image du tir et **−8,8 ms (43 %)** sur dix images ; les liserés du « son visible » **−0,9 ms (11 %)** (≈ 0,18 ms par son, 5 sons ; −3,7 ms cumulés) ; les rayons d'occlusion **≈ 0** (+0,4, dans le bruit) ; la couche iso **−1,6 ms (19 %)** (la même volée en vue de dessus : +6,7 ms ; `nœuds +15` contre `+0` : copies de peinture) ;
   les plafonds de traces atteints **+1,2 ms (+14 %)** (éviction de la plus ancienne à chaque trace : l'estimation de V3 était +0,5-1,25). Reste ≈ 3,9 ms (47 %) non attribués : `WallImpact` ×5 et leurs copies J2, sons, plombs et fondus, corps neufs (la variante « sans traces » n'a pas été faite). Bruit : deux prises identiques (mur 40 px) donnent +8,60 et +8,01 (±4 %), le cumulé +21,6 et +19,1 (±6 %) ; le fond varie de 2,1 à 3,3 ms d'une prise à l'autre (traces accumulées, machine).
6. **Le coût par particule — micro-banc `micro_particules.gd`** (N particules émises à la main, médianes de 5 tours ; headless, iso) :

| particule | émission (µs par particule émise) | `advance()` (µs par particule active et par image, mesuré en appelant `advance(0)`) | coût PERMANENT d'une image tant qu'elles vivent (µs par particule active et par image : advance + corps rigides + reste) |
|---|---|---|---|
| sang (N = 25 / 50 / 100 / 200) | 24 / 21 / 24 / 20 | 4,6 / 4,9 / 5,1 / 5,6 | 10 / 10 / 14 / 14 |
| étincelle (N = 25 / 50 / 100 / 200) | 34 / 28 / 23 / 24 | 2,1 / 2,2 / 1,9 / 1,8 | 13 / 13 / 19 / 17 (borne basse : une part meurt dans la fenêtre) |

   → **JOU-01 (20-50 µs à l'émission) confirmé par le bas (20-34 µs) ; JOU-04 (`advance` : `Charte.courbe` + deux `get_node` par particule et par image) confirmé, 5 µs pour le sang ; mais le coût PERMANENT est 2 à 3 fois l'`advance`** (10-14 µs : les `RigidBody2D` de la réserve — 240 nœuds, dont chacun porte une lumière — coûtent leur intégration physique et leurs notifications tant que la goutte vit : 1,5 à 3 s pour le sang).
   Conséquence : **200 gouttes actives (plafond `MAX_ACTIVE`) coûtent ≈ 2,8 ms par image en continu** ; le fond de la volée de contact (5,9 ms contre 2,8-3,2 pour 1 touche) le montre. À ce plafond, chaque émission recycle la plus ancienne (`_retire(0)` : `Array.remove_at(0)`), ce qui explique en partie que la volée de contact atteigne +18 ms. Un duel à bout portant au pompe passe donc par des images à +18 ms suivies de 1,5 à 3 s à +2-3 ms.

**Verdict V3 : l'ordre de grandeur et la thèse tiennent ; trois précisions** — (i) l'impact et le tir tombent dans la MÊME image (V3 les additionnait sous condition) ; (ii) l'estimation de V3 est confirmée au HAUT de sa fourchette sur ce conteneur ; (iii) le coût permanent des particules vivantes (10-14 µs chacune, jusqu'à 2,8 ms à 200 actives) n'était pas dans le décompte de l'image d'impact et pèse autant que l'impact lui-même sur la durée de la volée. Limites : headless (le GPU des 60 étincelles, 25 gouttes et de leurs lumières n'y est pas), 40 volées par cas, un seul poste (x86).

### 7.2 V2 — ce qui calcule sans qu'on le voie (`audit/V_V2.md` § 4)

**Montage** (`banc_ui_cachee.gd`, protocole de V2 § 4, version réduite) : une manche locale en vue unique, bras « en ligne » (`disposer_hud(false)` : le panneau de J2 caché), à pas fixe, 120 images de chauffe puis :
A. **compteurs** — le signal `theme_changed` branché sur chaque `Control` de l'UI pendant 300 images ; l'état de `is_processing()` de la galerie, des deux anneaux de curseur et du bandeau ; `vp1/vp2.render_target_update_mode` après un retour au hub ;
B. **temps** — blocs de 300 images (20 de remise à neuf), cinq bras en miroir (ordre inversé un bloc sur deux) ×4 : T0 témoin ; T2 galerie en sommeil (`set_process(false)`) ; T3 anneaux et bandeau en sommeil ; X « un `update_hud` complet de plus par image » ; X1 « un `update_hud` de J1 seul de plus » ; coût = écart d'horloge entre deux `process_frame` ;
C. **micro** — `Presentation3D._process` appelé 2 000 fois de suite.
Commande : `Godot_v4.7.1-stable_linux.x86_64 --headless --path . --fixed-fps 60 --script res://tools/banc_ui_cachee.gd -- --no-eos --iso=1|0 --blocs=4` ; prises de 16 à 24 s.

**A. États et compteurs (déterministes, indépendants du matériel).**
- **`galerie.is_processing() = true` alors que `visible_in_tree() = false`** ; `p1_cursor`, `p2_cursor`, `match_banner` : `is_processing() = true` aussi (HUD-03/CAR-01, HUD-06/MEN-02 : confirmés).
- **23,0 notifications `theme_changed` par image** (6 900 en 300 images, 21 `Control` notifiés), identiques en iso et en vue de dessus : **2 `Label` à 2 par image** (le doublon de `lbl_f` annoncé par V2), **19 nœuds à 1 par image** — les écritures du HUD (7 par joueur dont celles du panneau de J2 CACHÉ, plus le statut réseau : 15 en tout, le chiffre de V2), **les 6 tuiles `Button` de la galerie cachée**, et 2 `Panel` plein écran.
- **Au hub (après `_on_main_menu_requested`) : `vp1.render_target_update_mode = 4` et `vp2 = 4` (UPDATE_ALWAYS)** : l'arène 2D reste rendue sous le menu (B7 / MEN-04 : confirmé ; son coût GPU se mesure sous llvmpipe, section 6c).

**B. Temps — la scène « repos » (rien ne se passe) : l'image de base T0 vaut 1,95 à 2,16 ms en iso et 1,22 ms en vue de dessus.** Moyennes de 4 blocs de 300 images (écart au témoin du même lancement, ms) :

| Bras | iso (prise 1) | iso (prises 2 et 3, arbre A du tableau D) | vue de dessus | lecture |
|---|---|---|---|---|
| T0 témoin | 1,95 | 2,16 / 2,03 | 1,22 | |
| **T2 galerie en sommeil** | **−0,24** | −0,27 / −0,39 | **−0,26** | **la galerie cachée coûte 0,24-0,39 ms par image** (V2 B3 : 0,11-0,30) |
| T3 anneaux + bandeau en sommeil | +0,01 | −0,03 / −0,17 | −0,12 | 0 à 0,17 ms : dans le bruit en iso (V2 B5 : 0,02-0,045) |
| **X un `update_hud` de plus** | **+0,64** | +0,77 / +0,64 | **+0,81** | un appel complet de `update_hud` : 0,64-0,81 ms |
| X1 `update_hud` de J1 seul | +0,48 | +0,57 / +0,50 | +0,64 | |
| **X − X1** (le bloc de J2 CACHÉ) | **0,16** | 0,20 / 0,14 | 0,18 | le panneau caché coûte presque autant que le visible (V2 F6 : « un Label caché se refaçonne à chaque notification ») |

**C. `Presentation3D._process` : 487 / 505 / 430 / 458 / 474 µs par appel (2 000 appels de suite ; moyenne 0,47 ms)** — soit **la moitié à deux tiers de l'écart entre l'image de repos en iso (1,95-2,16 ms) et en vue de dessus (1,22 ms)** : 0,47 sur 0,73-0,94 ms. C'est le plus gros poste scripté de la couche iso au repos ; V2 chiffrait seulement les poussées d'uniformes (B10 : 0,10-0,35 ms) et `_decrire` (B11 : 0,015-0,035 ms).

**D. Avant / après de la retouche gelée « HUD-02, lecture avant écriture » (`arbres/H1`, `H1.diff`)** — les huit sites par image de V2 B1 (`ui.gd` 1652, 1737, 3168, 3246, 3375, 3380, 3439, 3446) passent par `_couleur_si_change` / `_style_si_change` (écriture seulement si la valeur diffère de celle que la surcharge porte déjà), exactement le correctif minimal de V2. Même banc, deux arbres, en miroir A H1 H1 A (`etape_h1.sh`) :

| | A (dépôt) prise 1 / prise 2 | H1 (retouché) prise 1 / prise 2 | écart |
|---|---|---|---|
| notifications `theme_changed` par image | 23,0 / 23,0 | **8,0 / 8,0** | **−15 par image** (les 15 écritures de V2 ; restent les 6 tuiles de la galerie et 2 `Panel`) |
| **image de repos T0 (ms)** | 2,16 / 2,03 | **1,43 / 1,40** | **−0,67 ms (−32 %)** |
| T2 galerie en sommeil (écart au témoin) | −0,27 / −0,39 | −0,32 / −0,15 | la galerie coûte toujours ≈ 0,25-0,3 ms |
| X un `update_hud` de plus (écart au témoin) | +0,77 / +0,64 | +0,44 / +0,34 | un appel complet vaut moitié moins |

→ **HUD-02 retire ≈ 0,67 ms par image dans la scène de repos (32 % de l'image), au HAUT de la fourchette de V2 (B1 : 0,17-0,63 ms, plancher 0,15)** — le chiffre « X » sous-estime le gain parce qu'un second appel dans la même image partage le travail différé (relayout, tri) du premier ; l'écart de l'image entière est le bon.
**Somme récupérable mesurée sur la scène de repos : HUD-02 0,67 + galerie 0,25-0,35 + curseurs/bandeau 0-0,1 ≈ 0,9-1,1 ms sur 2,1 ms (≈ 45-50 %)** ; sur l'image d'un vrai duel (3,8 à 5,8 ms de CPU, étape 4), ≈ 17-25 %. V2 centrait son total (B1-B6 + B10-B11) à 0,9 ms : **confirmé à l'ordre de grandeur, par le haut** (conteneur plus lent que le Mac : la moitié environ au M3).

**Verdict V2 : tous les mécanismes sont CONFIRMÉS** (galerie qui traite cachée, 15 écritures de thème par image dont celles du panneau de J2 caché, doublon de `lbl_f`, vp1/vp2 en UPDATE_ALWAYS au hub) **et leur coût mesuré tient dans la fourchette de V2, à son sommet**. Réserves : scène de repos (aucun combat) ; headless (le dessin du HUD, côté GPU, n'y est pas : les chiffres ci-dessus sont le seul côté script, borne basse) ; T3 est sous le plancher de bruit en iso (±0,1 ms) ; la retouche H1 n'a pas été jouée contre la suite de tests (`test_tir_et_reserves`, `test_habillage` lisent le texte de `ui.gd` : V2 § B1 4.).

## 8. Ce qui n'a PAS été mesuré, et la commande qui le mesurerait

Sur ordre de la coordination (une seule série de plus après 6a : ce fut 6c), les mesures suivantes n'ont **pas** été lancées. Les instruments et les plans sont prêts dans `scratchpad/` (`SP=/tmp/claude-0/-home-user-Candela-2D---Godot/7ff0bf4a-bff5-52d4-8682-f6c15d6916d8/scratchpad`, non commités) ; les séries llvmpipe se lancent **depuis le worktree**, **une à la fois** (la porte refuse une prise bruitée et la refait) :
`cd <worktree de mesure> && GODOT=$SP/godot-bin/Godot_v4.7.1-stable_linux.x86_64 SCENE=mesure_banc $SP/cadence/serie_m.sh $SP/plans/<plan>.txt $SP/mesures/<dossier> <nom>` puis `python3 $SP/cadence/tableau.py $SP/mesures/<dossier> <nom> A`.

| Non mesuré | Commande (plan) | Durée | Ce que la lecture dira |
|---|---|---|---|
| **6b — la fusée éclairante et sa fumée**, avec / sans, puis morceau par morceau | `<plan> = p2.txt`, dossier `p2` (13 prises en miroir : A, sans fusée, sans volume voxel, sans ombre 2D, sans fumée 2D, sans lumière 2D) | ≈ 30 min | l'écart A − sans-fusée sous llvmpipe, réparti entre ses morceaux. **Côté CPU c'est déjà mesuré : ≈ 0,8 ms par image** (étape 4) |
| **6d — D1 de V8 : l'atlas des textures de lumière reconstruit en entier à chaque texture inédite** (`FLASH[1]`, `FLASH[2]` posées par chaque tir, tenues par aucune lumière) | `d1.txt`, dossier `d1` (8 prises : A0, bascule, bascule tenue, tient). Variantes déjà codées dans `variantes_reflexion.gd` : `--v-bascule-flash`, `--v-bascule-flash-tenu`, `--v-tient-flash` | ≈ 20 min | bascule − bascule tenue = le prix d'UNE reconstruction par image sous llvmpipe ; tient − A0 = l'effet des vrais tirs du banc |
| **Étape 5, trois configurations sur quatre** : écran scindé iso, vue de dessus unique, vue de dessus scindée | `$SP/mesures/etape5.sh` (4 prises avec `--sonde --temps-par-vue`) | ≈ 9 min | les compteurs de rendu (appels, objets, primitives, viewports, ombres) de chacune, à comparer à la section 5 |
| **Décomposition générale de l'image sous llvmpipe** : torches et vue de dessus (le coût GPU de la couche iso), faisceau d'air, portée à l'écran, ombres 2D, capteurs de corps, son visible, LED des murs, halos de proximité, rétrodiffusion | `p3.txt` (6 prises), `b1.txt` (10), `b2.txt` (12) | ≈ 18 + 30 + 33 min | la table de décomposition de l'étape 6 : écart à A et rapport en cadence par poste (la partie « voile » est faite, 6a) |
| **Attribution du coût CPU du solo** (PNJ ou carte ? V4, question 1 de BOT : 0, 3, 7 PNJ en 8.9) | headless : `godot --headless --path . --fixed-fps 60 --script res://tools/mesure_sim.gd -- --no-eos --scenario=solo --chapitre=8 --salle=9 --secondes=60 --pnj=0` (puis `3`, `7`) | 3 × 1 min | ce qui, des 11,4 ms par image de la salle 9 du chapitre 8, vient des PNJ |
| **`IsoMateriaux.image_proximite_usure`** (V4 : 0,05-0,3 s estimés par départ de duel, 0,4-2,3 s en 8.9) | headless : `godot --headless --path . --script res://tools/micro_usure.gd -- --no-eos --salles=8:9,7:9,0:9,8:5` | 10 s | la part de la première image d'une manche (450-532 ms mesurées, non attribuées) qui vient de cette construction |

**Non mesurable dans ce conteneur (aucune de ces limites n'a de commande cloud)** : tout ce qui dépend du **GPU à tuiles du M3** — le prix d'une coupure de passe par `BackBufferCopy` (6a ne prouve que sa PRÉSENCE), le coût réel du voile, des deux vues, des particules et des lumières ; la compilation des shaders au premier dessin ; la lecture GPU de `Texture2D.get_image()` dans le chemin de N1 (le moteur factice la sert depuis la mémoire) ; le thread audio ; le coût d'un export (binaire `.gdc`, jetons) contre le source ; la vitesse relative du M3 pour GDScript (ESTIMÉ 1,5 à 2 fois ce Xeon, jamais mesuré) ; l'attribution fine des « premières fois » (1re image d'une manche 450-532 ms, écran de fin 86-394 ms : aucun profileur de fonctions en headless) ; le réseau (un seul Godot à la fois).
