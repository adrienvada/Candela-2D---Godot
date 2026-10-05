# Audit CAR — Cartes, éditeur, replay et archivage

Dépôt `/home/user/Candela-2D---Godot`, commit `52a29c1` (0.8.3 + SOLO S12). Lecture seule : aucun fichier du dépôt
touché, Godot jamais lancé. Deux scripts Python de COMPTAGE (ports fidèles de `decode_runs` / `build_grid` /
`merge_rects`) sont dans ce dossier : `port_geom.py` (cartes livrées), `port_solo.py` (100 niveaux d'aventure).

**Convention.** PROUVÉ = lu dans le code ou compté par le port Python. ESTIMÉ = ordre de grandeur raisonné, **jamais
mesuré** (je ne peux pas lancer Godot). Pour étalonner les durées GDScript, la seule mesure du dépôt qui s'y prête est la
cuisson LED : 83 ms pour 272² texels en deux passes (ROADMAP l. 22739), soit ≈ 0,3-0,4 µs par élément de boucle simple sur
la machine d'Adrien. Mes estimations valent ±2×.

Contexte de budget : la ROADMAP chiffre la marge de cadence à **139 µs par image** (l. 20352 et 22095), et le plancher de
bruit du banc à ~0,25 ms de médiane (l. 34151). Un coût de quelques dizaines de µs par image n'est donc ni négligeable ni
mesurable au banc de cadence : il se vérifie par instrumentation.

---

## 1. Carte des chemins chauds

### 1.1 Ce qui tourne, et à quel rythme

| Rythme | Chemin | Où | Ordre de grandeur |
|---|---|---|---|
| **Par image rendue, toute la session** | `MapGallery._process` : `sin`, `lerp`, écriture d'un `StyleBox` partagé par toutes les tuiles | `map_gallery.gd:608-621` | tourne même cachée, même en match (CAR-01) ; N = 6 cartes livrées + cartes perso |
| Par image rendue, en manche | `GameState._process` → `ReplaySystem.record_frame(…, delta)` | `game_state.gd:2220-2221`, `replay_system.gd:122` | appel à chaque image (jusqu'à 490/s) ; à cadence libre sortie anticipée 8 fois sur 9, à 60 fps chaque appel enregistre (accumulateur, l. 124-130) |
| **60 Hz fixe, en manche** | enregistrement complet d'un `Snapshot` | `replay_system.gd:132-260` | 1 objet + 2 `Array` + 1 `PackedFloat32Array` ; +1 `Dictionary` par gadget debout (≤ 2) et par fusée ; boucles O(événements) (CAR-02) |
| Par image rendue, pendant la killcam (≈ 6-7 s par match, après 1,5 s de sang et 0,15 s de gel) | `get_next_frame` → `_melanger`, puis application aux fantômes | `replay_system.gd:452-661`, `game_state.gd:2223-2316` | 1 `Snapshot.new()` + copies de `Dictionary` (fusées, gadgets) + ~20 `get_node` par image ; événementiel, pas du régime |
| Éditeur seulement, par image | `MapEditor._process` : 2 `queue_redraw`, scrutation des entrées | `map_editor.gd:192-221` | curseur + aperçu redessinés ; jusqu'à 600 `draw_rect` d'orphelines (CAR-10) |
| Éditeur, ≤ 6,7 Hz tant qu'on peint | `_run_validation` | `map_editor.gd:1027-1038` | 3 `encode_runs` (tri par lambda) + ~10 `decode_runs` + BFS (CAR-09) |
| **Par départ de manche** (match, revanche, entraînement, salle d'aventure ET chaque réessai après mort) | `rebuild_arena` | `game_state.gd:1412` (appelée de `_do_start_round` :1948 ; `_ready` :628) | 20 `build_grid`, ~65 `decode_runs`, atlas régénéré, 6 duplications de calques, cuisson du décor (CAR-03, 05, 06) |
| **Par coup fatal** | `_archive_match_result` → `MatchRecord.append_to_history` | `game_state.gd:4460` → `4733-4774` ; `match_record.gd:247` | lecture + parse + stringify + écriture du journal entier (CAR-04) |
| À l'accusé du serveur (tout match en ligne) | `RankedIdentity._settle_front` → `MatchRecord.mark_reported` | `ranked_identity.gd:345-350`, `match_record.gd:232` | idem, une seconde fois |
| Au lancement de l'UI | `MapGallery._ready` → `_rebuild_tiles` ; `ScreenHistory.build` → `refresh` | `map_gallery.gd:97,284` ; `screen_history.gd:119,154-159` | N miniatures 256² peintes en GDScript ; 2 `load_history` |
| À chaque `catalog_changed` | `_on_catalog_changed` | `map_gallery.gd:478-481` | vide le cache, détruit et reconstruit toutes les tuiles (CAR-08) |

Rien d'autre ne tourne par image dans mon périmètre : `ReplaySystem` n'a pas de `_process` (autoload inerte hors
`record_frame`/`get_next_frame`), `MapData`, `MapCodec`, `MapGeometry`, `MapThumbnail` et `MatchRecord` sont des appels
d'événement.

### 1.2 Quantités au pire cas

| Quantité | Valeur | Source |
|---|---|---|
| Rectangles de murs, cartes de duel livrées | 4 (Standard) à 11 (Usine, Croisée, Bunker) ; 4 fosses ; 0 mur bas | `port_geom.py` |
| Nœuds de `MapCollisions` (racine + 3 corps + 2 par rect de mur ou mur bas + 1 par fosse) | 16 (Standard), 26, 26, 30, 30, 30 | `port_geom.py` |
| Occluders (LightOccluder2D) en duel | 4 (Standard) ; 9 à 11 ailleurs — **la cible du plan (< 20) est tenue** (`docs/PLAN_EDITEUR_CARTES.md:275`) | `port_geom.py` |
| Salles d'aventure (100 niveaux) | nœuds : médiane 28, max 234 (ch. 9 niv. 7 : 76 murs + 37 murs bas + 4 fosses) ; occluders : médiane 10, max 113 ; 18 niveaux ont des murs bas (max 44) | `port_solo.py` |
| Plus grande salle | ch. 8 niv. 9 : 100×80, 8 364 cases avec bordure, 7 148 cellules de sol, 852 de murs, 242 + 322 runs | `port_solo.py` |
| Pire cas théorique d'une carte joueur | damier de murs 128×128 : ≈ 8 200 rectangles ⇒ ≈ 16 400 nœuds et autant de ressources (`merge_rects` ne fusionne rien) | calcul |
| Poids des cartes livrées | 6,1 Ko pour les six (0,87 à 1,15 Ko chacune) ; 222 Ko pour les 110 fichiers d'aventure (100 niveaux + 10 chapitres, max 7,6 Ko) | `stat` |
| Tampon de rejeu | 450 instantanés = 7,5 s, **indépendant de la durée du match** | `replay_system.gd:26` |
| Journal des matchs | plafonné à 200 entrées ; ≈ 1,9 Ko pretty-printé par entrée (simulation du schéma v6, 1,56 Ko en compact) ⇒ **≈ 0,38 Mo** plein ; fichier réel non vu | `match_record.gd:93` |

Détail des six cartes livrées (`assets/maps/`, comptes de `port_geom.py`) :

| Carte | Grille | Cases de sol | Cases de mur | Runs sol / murs | Rects de murs | Nœuds `MapCollisions` | Taille |
|---|---|---|---|---|---|---|---|
| Arène Standard (`default`) | 32×32 | 676 | 348 | 26 / 58 | 4 | 16 | 911 o |
| Arène Circulaire | 24×24 | 356 | 220 | 28 / 52 | 9 | 26 | 867 o |
| Le Cloître | 30×30 | 528 | 372 | 42 / 72 | 9 | 26 | 1 149 o |
| L'Usine (v4) | 32×26 | 456 | 376 | 42 / 68 | 11 | 30 | 1 118 o |
| La Croisée | 28×28 | 424 | 360 | 40 / 68 | 11 | 30 | 1 084 o |
| Le Bunker | 26×26 | 364 | 312 | 36 / 62 | 11 | 30 | 1 006 o |

### 1.3 Réponses aux six questions de la mission

**Q1 — `rebuild_arena` et la géométrie.**
- *Fusion de rectangles* : `merge_rects` (`map_geometry.gd:202-249`) est linéaire en nombre de cases. Chaque case est
  visitée une fois par la double boucle ; la descente d'un ruban coûte au plus la largeur du rectangle absorbé plus une
  rangée d'échec par rectangle. Elle ne minimise pas le nombre de rectangles (glouton ligne par ligne) mais en donne 4 à
  11 sur les cartes de duel.
- *Nœuds produits* : voir 1.2 (16 à 30 en duel, 234 au pire des salles livrées).
- *Fréquence* : une fois à `GameState._ready` (:628), puis à chaque `_do_start_round` (:1948) : match, revanche,
  entraînement (:1011), chaque salle d'aventure **et chaque réessai** (`aventure_poser_la_salle` →
  :1275). En BO1, une manche par match. Jamais pendant une manche. **Le mode test F5 de l'éditeur n'appelle pas
  `rebuild_arena`** : `_enter_sandbox` (`map_editor.gd:1192-1216`) fait une seule `build_collisions` (3 `build_grid`) +
  `_current_data()` (3 `encode_runs`) + `player.tscn.instantiate()`, et l'aperçu lumière (L) refait `build_collisions` à
  chaque geste validé (`_on_map_changed`, :805-809) — par geste, pas par image.
- *Hoquet au départ de manche* : très probablement oui (ESTIMÉ, jamais mesuré), réparti sur 3 à 5 images : `rebuild_arena` (même image), puis l'image suivante
  pour `Presentation3D._construire_les_murs` (`presentation_3d.gd:2188`) et la cuisson du décor (deux images + une lecture
  GPU). Les images qui suivent `rebuild_arena` tombent **après** `_conditions.commencer()` (`game_state.gd:2012`) : elles
  entrent dans le 1 % bas archivé et dans F6. Voir CAR-03, CAR-05, CAR-06.

**Q2 — Replay.**
- *Structure* : un `Snapshot` (classe interne, `RefCounted`, ~22 champs typés pour LES DEUX joueurs : positions,
  rotations, PV, visibilité, lampe, flash, arme, lampe rendue, posture) par 1/60 s. **Pas de Dictionary par joueur ni
  par image.** Dictionaries seulement pour les fusées (4 clés) et les gadgets (13+ clés, `gadget_base.gd:752`), un par
  objet debout et par instantané. Les traces de poudre sont aplaties dans un `PackedFloat32Array`
  (`replay_system.gd:225-241`, sans allocation par trace).
- *Tampon* : un `Array` borné à `max_snapshots = 450`, purgé par `pop_front()` — pas un anneau. Mémoire ≈ 0,35 à
  1,5 Mo (ESTIMÉ), **constante sur 5 minutes**. Les événements de tir (`bullet_events`) sont des `Dictionary` à 6 clés,
  un par TIR (pas par projectile), purgés avec le tampon.
- *Coût d'enregistrement* : ESTIMÉ 15-25 µs par instantané hors tir, 40-90 µs en rafale soutenue (CAR-02).
- *Relecture* : killcam seulement ; une `Snapshot.new()` + copies de dictionnaires par image rendue ; négligeable face
  à ce que la killcam affiche (ghosts, lumières). Les copies de gadgets sont créées une fois puis `rejouer(d)`
  (`game_state.gd:3923-3943`).

**Q3 — Archivage.** Le journal est plafonné (`HISTORY_MAX = 200`, `match_record.gd:93`), donc **sans croissance non
bornée**. En revanche le fichier ENTIER est relu, analysé, ré-écrit (pretty-print `"\t"`) à chaque `append_to_history` et à
chaque `mark_reported`, **sur le fil principal**, et le premier appel tombe dans l'image du coup fatal
(`game_state.gd:4460`, avant l'`await frame_post_draw` de :4515). Voir CAR-04.

**Q4 — Galerie et miniatures.** Pas de SubViewport : une `Image` RGBA8 de 256² remplie par `fill_rect` natif, une case à
la fois depuis GDScript (`map_thumbnail.gd:64-81`), `ImageTexture.create_from_image`, **synchrone**. La génération a lieu à
la construction de l'UI (`MapGallery._ready` → `_rebuild_tiles`, pas à l'ouverture de la galerie) et à chaque
`catalog_changed`. Cache `static var` indexé `id@échelle`, non borné, invalidé uniquement par la galerie vivante :
**défaut de cache** (CAR-08).

**Q5 — Éditeur.** La grille de fond n'est PAS redessinée à chaque image : `_on_grid_draw` (un seul
`draw_multiline_colors`) ne repasse qu'à `_load_map` et `_resize_grid` (`map_editor.gd:958, 1004`). Par image : le
curseur et la couche d'aperçu (`:194-195`). F5 ne reconstruit pas l'arène (voir Q1).

**Q6 — Codec.** Froid, une ligne : `JSON.stringify` + `compress(GZIP)` + base64 à l'export, l'inverse à l'import, borné à
8 Mo décompressés. **Surprise** : la borne ne protège pas contre l'amplification du RLE (CAR-07).

---

## 2. Constats

### CAR-01 — La galerie de cartes se traite à chaque image, même cachée, pendant tous les matchs

**Où.** `map_gallery.gd:91` (mode), `:608-621` (`_process`), `:321-325` (style partagé), `menu_widgets.gd:532-541`
(`reteindre`), `menu_hub.gd:405-410` (`register_panel` → `content.hide()`), `ui.gd:4542-4549` (création).

**Constat.**
```gdscript
# map_gallery.gd:91
process_mode = Node.PROCESS_MODE_ALWAYS
# map_gallery.gd:608
func _process(delta: float) -> void:
	_pulse += delta
	if _style_selected != null:
		var wave := 0.5 + 0.5 * sin(_pulse * 4.0)
		MenuWidgets.reteindre(_style_selected, COLOR_P1.lerp(Charte.HALOGENE, 0.4 * wave))
```
`reteindre` écrit `border_color` (aplat) ou `modulate_color` (habillage voxel, le défaut) : un setter de ressource émet
`changed`, et la valeur change à chaque image (sinusoïde). `_style_selected` est UNE instance posée en override « pressed » et
« hover_pressed » sur CHAQUE tuile (`:324-325`) ; un override de thème est connecté à `changed`, donc chaque tuile reçoit une
notification de thème et un `queue_redraw` différé à chaque image. La galerie est construite une fois, au lancement de l'UI
(`ui.gd:4542`), enregistrée comme panneau du hub puis cachée (`menu_hub.gd:408`), mais ni la visibilité ni rien d'autre ne
coupe `_process` : aucun `set_process(false)`, et `PROCESS_MODE_ALWAYS` l'emporte sur tout parent désactivé. Elle tourne de
l'écran-titre à la fermeture du jeu, matchs et killcams compris. Le dépôt sait déjà faire : `MenuArene` coupe son
traitement hors vue (`menu_arene.gd:152, 208-212`), `MenuWatcher` « s'endort » hors menu (`ui.gd:1473-1481`).

**Coût.** PROUVÉ : `_process` s'exécute à chaque image, caché. ESTIMÉ : ~3 µs de GDScript + 5-10 µs par tuile de
notification de thème, soit **35-70 µs par image avec les 6 cartes livrées, 150-300 µs avec ~30 cartes perso**. Par
rapport à la marge de 139 µs/image (l. 22095), c'est l'ordre de grandeur d'un poste entier. Le détail du coût par tuile
dépend du moteur 4.7 (à confirmer au profileur) ; si le moteur court-circuitait la notification pour un nœud caché, il
resterait le `_process` lui-même, et le correctif est le même.

**Proposition.** Sur le patron de `menu_arene.gd:152, 208-212` :
```gdscript
visibility_changed.connect(_sur_visibilite)   # dans _ready, puis un appel direct
func _sur_visibilite() -> void:
	set_process(is_visible_in_tree())
	if not is_visible_in_tree():
		_disarm_delete()                       # le minuteur de confirmation vit dans _process
```

**Gain attendu.** Tout le coût hors galerie ouverte, soit en pratique 100 % du coût en match : 0,04 à 0,3 ms/image.

**Risque.** Gameplay, équité, réseau : aucun. Visuel : la respiration reprend à la phase courante à la réouverture
(invisible). Bancs : aucun lien avec la simulation.

**Effort.** S.

**Sévérité.** MINEUR (ESTIMÉ ; à reclasser MAJEUR si la mesure dépasse ~100 µs/image).

**Statut ROADMAP.** NOUVEAU. Le principe est acté — « les effets de la vitrine coupent tous leur traitement au repos, par
conception » (l. 34297) — et la respiration de teinte de la tuile est une décision visuelle (halo retiré, teinte gardée,
l. 22318) ; personne n'a éteint son traitement hors vue.

**Comment le vérifier.** Instrumenter `_process` (`Time.get_ticks_usec` cumulé sur 600 images en duel) ou le profileur de
Godot par nœud. `bench_framerate` ne tranchera pas (effet < plancher de bruit de 0,25 ms, l. 34151). Garde à ajouter à
`tools/test_vitrine_menus.gd` : « galerie cachée ⇒ `not is_processing()` ; visible ⇒ `is_processing()` ».

---

### CAR-02 — Rejeu : à chaque instantané une fois le tampon plein, deux passes sur les événements, un `Array` neuf et un `pop_front()` sur 450 éléments

**Où.** `replay_system.gd:243-260` (purge), `:157, :191` (`get_node`), `:196-216` (enfants), `:225-241` (traces) ;
`gadget_base.gd:752` (`etat_de_rejeu`).

**Constat.**
```gdscript
snapshots.append(snap)                       # :243
if snapshots.size() > max_snapshots:         # :244, vrai 7,5 s après le début de la manche, puis à chaque appel
	snapshots.pop_front()                    # :245
	…
	for ev in bullet_events:                 # :254
		ev.frame -= 1
	var new_events = []                      # :256
	for ev in bullet_events:
		if ev.frame >= 0:
			new_events.append(ev)
	bullet_events = new_events
```
À 60 Hz, de la 8ᵉ seconde à la fin de la manche : `Array.pop_front()` (documenté O(n) par le moteur) sur 450 éléments
dont chacun est une référence d'objet, deux passes sur `bullet_events` avec lecture et écriture de clé de `Dictionary` par
événement, et un `Array` neuf. `bullet_events` garde tous les tirs des 7,5 dernières secondes des deux joueurs, un par
TIR (`game_state.gd:4198`) ; cadence maximale 11 tirs/s (Occulteur, `game_state.gd:5208`) ⇒ jusqu'à 83 par tireur.
Autour : `p.get_node("MuzzleFlash")` appelé deux fois par joueur (:157, :191), `get_children()` + `has_method` +
`is_in_group` par enfant (:197-216), un `Dictionary` de 13+ clés par gadget debout et par instantané.

**Coût.** PROUVÉ : les boucles et l'allocation existent à chaque instantané plein. ESTIMÉ : 15-25 µs par instantané hors
tir ; + ~0,35 µs par événement et par instantané (≈ 30 µs avec 80 événements) ; + 5-15 µs de `pop_front`. En rafale
soutenue : 40-90 µs × 60 /s ≈ 2,5-5 ms par seconde de CPU, soit 0,25-0,55 % d'une image à 60 fps, **30 à 65 % de la marge
de 139 µs**. Mémoire : non concernée (bornée, ≈ 0,35-1,5 Mo).

**Proposition.**
(a) Indices **absolus** pour les événements : un compteur `_purges` incrémenté à chaque `pop_front` ; `ev.frame` n'est plus
décrémenté ; les lecteurs lisent `ev.frame - _purges` (`index_du_tir_fatal` :337-349, `get_next_frame` :549-558, le repli de
`slow_mo_start_frame` :149-152 et :183-186) ; la purge d'événements se fait par la tête
(`while not bullet_events.is_empty() and bullet_events[0].frame < _purges`). Supprime les deux boucles et l'allocation.
`impact_frame` et `slow_mo_start_frame` restent relatifs (décrément O(1) inchangé).
(b) Garder les deux `MuzzleFlash` dans une variable locale.
(c) Mesurer `pop_front` avant d'y toucher ; si > 5 µs, anneau avec indice de tête (plus invasif : tous les `snapshots[i]`).

**Gain attendu.** ~30-60 µs par instantané en rafale ; 5-15 µs sinon.

**Risque.** La killcam est l'un des endroits les plus piégés du dépôt (Pièges connus l. 9290-9345 : `impact_frame` collé au
plafond, `_impact_seen`) ; la sémantique relative de `impact_frame` / `slow_mo_start_frame` doit rester intacte, et le
tampon doit rester dimensionné en TEMPS (l. 9058-9070). Aucun effet réseau ni déterminisme (enregistrement local).

**Effort.** M.

**Sévérité.** MINEUR.

**Statut ROADMAP.** NOUVEAU. Déjà tranché et à ne pas défaire : cadence fixe 60 Hz, 450 instantanés, traces sans
allocation par trace (`replay_system.gd:218-224`), `_melanger` unique.

**Comment le vérifier.** `tools/test_rejeu.gd` (invariants du tampon, des événements et de l'ancre d'impact, dans sa propre
instance), `test_killcam_calme.gd`, `test_rejeu_journal.gd`. Micro-banc headless (le rejeu n'a pas besoin de rendu) :
10 000 appels de `record_frame` avec de faux joueurs (patron de `test_rejeu.gd`) et 80 événements, chronométrés par
`Time.get_ticks_usec`.

---

### CAR-03 — `rebuild_arena` redécode et ré-échantillonne la même carte 20 fois à chaque départ de manche

**Où.** `game_state.gd:1412-1572` ; `map_geometry.gd:128-172` (`build_grid`), `:290, 300, 309` ; `mur_led.gd:166-167` ;
`mur_encre.gd:92-93, 103` ; `iso_geometrie.gd:83-106` ; `iso_materiaux.gd:439-451, 522-523` ;
`presentation_3d.gd:2194-2202` ; `audio_manager.gd:1062` ; `map_data.gd:419-432`.

**Constat.**
```gdscript
# map_geometry.gd:290-309 — trois grilles pour les trois familles
_fill_body(walls, merge_rects(build_grid(data, Kind.WALLS)), …)
_fill_body(pits,  merge_rects(build_grid(data, Kind.PITS)), …)
_fill_body(lows,  merge_rects(build_grid(data, Kind.LOW_WALLS)), …)
# game_state.gd:1497 — et une quatrième, la même que la troisième
murs_bas = MapGeometry.rects_monde(data, MapGeometry.Kind.LOW_WALLS)
```
Chaque `build_grid` décode TROIS chaînes RLE en `Array[Vector2i]`, remplit trois `Dictionary` à clés `Vector2i`, puis
parcourt (W+2)×(H+2) cases avec un `Vector2i` neuf, un `match` et 1 à 3 `has()` (`:135-170`). Dénombrement par départ de
manche en duel (iso par défaut, LED allumée, usure allumée par défaut — `iso_materiaux.gd:170-172`) :

| Appelant | `build_grid` |
|---|---|
| `build_collisions` (`map_geometry.gd:290, 300, 309`) | 3 |
| `rects_monde` (`game_state.gd:1497`) | 1 |
| `MurLed.poser` : `build_grid` + `build_solid_grid` (`mur_led.gd:166-167`) | 1 + 3 |
| `MurEncre.setup` : murs puis murs bas (`mur_encre.gd:92-93`) | 2 |
| `IsoGeometrie.build_meshes` : `rects_px` ×2 sortes (`iso_geometrie.gd:106`, `presentation_3d.gd:2194`) | 2 |
| `accorder_grille(_mat_mur)` → `image_grille` (`presentation_3d.gd:2196`) | 2 |
| usure : `image_proximite_usure` → `image_grille` (`:2200`) | 2 |
| usure : `accorder_grille` pour CHACUN des 2 sols (`:2201-2202`, `_mat_sols` = 2) | 4 |
| **Total** | **20** (14 avec `--sans-usure`) |

Autour : `apply_to_layers` décode 4 fois (`map_data.gd:419, 421, 425, 432`), `ArenaDecor._analyser_carte` 2 fois,
`AudioManager.accorder_a_la_carte` décode les murs **juste pour compter** (`audio_manager.gd:1062`), `image_grille` écrit
chaque case par `set_pixel` en GDScript (×4). En aventure s'ajoutent `NavigationBot.depuis_carte` (3 `build_grid`,
`aventure_partie.gd:176`) et, par PNJ qui voit ou entend, `PerceptionBot.monde_de_la_carte` (2, `bot_input_provider.gd:332`
→ `perception_bot_noeud.gd:77`) : jusqu'à 14 de plus à la salle 8.9 (7 PNJ). **Trois commentaires disent « une fois par
carte »** (`presentation_3d.gd:2199`, `arena_decor.gd:22`, ROADMAP l. 22327/28721) : le code le fait une fois par
construction d'arène, donc à chaque revanche et à chaque réessai.

**Coût.** Comptes PROUVÉS. Durée ESTIMÉE : ≈ 1,2-1,5 ms par `build_grid` sur l'arène standard (1 156 cases, 1 024
cellules décodées) ⇒ **≈ 25-40 ms par départ** avec les boucles voisines (`merge_rects` ×10, `image_grille`, `trace_contours`,
`sol_de`) ; ≈ 9-12 ms par `build_grid` sur la salle 8.9 (8 364 cases, 8 000 cellules) ⇒ **≈ 0,2-0,3 s par salle et par
réessai**, davantage avec les PNJ. Pas un coût de régime : un hoquet de départ, qui tombe en partie dans le 1 % bas
archivé (les images iso et décor suivent `_conditions.commencer()`, `game_state.gd:2012`).

**Proposition.** Mémoïser **par contenu** dans `MapGeometry` :
```gdscript
static var _memo_cle := 0
static var _memo := {}                         # Kind → grille ; Kind → rectangles
static func grille(data: Dictionary, kind: Kind) -> Array:
	var cle := hash([data.get("grid_size"), data.get("floor"), data.get("walls"), data.get("low_walls")])
	if cle != _memo_cle: _memo.clear(); _memo_cle = cle
	if not _memo.has(kind):
		var g := build_grid(data, kind)
		for colonne in g: (colonne as Array).make_read_only()   # `make_read_only` ne descend pas dans les sous-tableaux
		g.make_read_only()                     # attrape tout appelant qui muterait la grille partagée
		_memo[kind] = g
	return _memo[kind]
```
(le dépôt utilise déjà `data.hash()` pour l'empreinte de rencontre, `game_state.gd:1365`). Idem pour les rectangles fusionnés ;
`build_solid_grid` se déduit des trois grilles mémoïsées ; les 8 appelants passent de `build_grid` à `grille`. Mémoïser aussi
`decode_runs` par chaîne (rendre `.duplicate()`, natif), ou offrir `MapCodec.count_cells(encoded)` aux deux lecteurs qui
ne décodent que pour compter (`accorder_a_la_carte`, `_scan_dir`).

**Gain attendu.** De 20 à 3 constructions de grille (≈ −85 %) : ≈ −25 à −35 ms sur l'arène standard, ≈ −0,2 s sur la salle
8.9 et chaque réessai (ESTIMÉ). Option plus radicale, **non recommandée d'emblée** : sauter `rebuild_arena` quand la carte et
le mode sont inchangés — trop de couplages (peinture iso périmée, `presentation_3d.gd:509-514`, rapport peinture-perimee du 2026-09-28 ; nommage des nœuds).

**Risque.** Aliasing si un appelant mute une grille partagée : `mur_led.sol_de` copie, `merge_rects`, `trace_contours` et
`image_grille` ne font que lire ; à re-vérifier pour `navigation_bot.gd:84` et `perception_bot.gd:164` avant de leur donner la
version mémoïsée. L'éditeur change de contenu à chaque geste donc invalide le cache : sans conséquence. Déterminisme : mêmes
valeurs, même ordre. **Coordination** : `map_geometry.gd` est aussi la cible de l'allègement OM6 du chantier OMBRES (« occulteurs de
murs par contours », `trace_contours` non branché ; session `candela-2d-godot-d4`, branche `claude/determined-pasteur-mtrws1`,
CONTEXTE_CHANTIERS_EN_COURS.md §2) : la mémoïsation est orthogonale (un occulteur par contours consommerait aussi `build_grid`),
mais les deux touchent le même fichier — à dire à la session qui le tient plutôt qu'à fusionner (CLAUDE.md).

**Effort.** M.

**Sévérité.** MINEUR en duel (hors action, au départ) ; MAJEUR pour les salles d'aventure ≥ 3 000 cases (chapitre 8).

**Statut ROADMAP.** NOUVEAU. Précédent traité ailleurs : la texture LED est mise en cache « une fois par carte »
(`mur_led.gd:131-132, 209-213`, l. 22739). Aucune mesure du temps de `rebuild_arena` dans la ROADMAP.

**Comment le vérifier.** Micro-banc headless (c'est du GDScript pur, sans rendu) : `MapGeometry.build_grid` ×100 sur
`assets/maps/default.json` et sur la carte de `assets/solo/chapitre_08/niveau_09.json`. En fenêtre : `Time.get_ticks_usec`
autour de chaque section de `rebuild_arena`. Garde d'équivalence : `test_map_geometry`, `test_arena_build`, `test_mur_led`,
`test_iso_geometrie`, `test_iso_murs_bas` ; compteur d'appels dans `test_arena_build` (« ≤ 3 `build_grid` par
construction »).

---

### CAR-04 — Fin de match : le journal entier est relu, ré-analysé et ré-écrit sur le fil principal, dans l'image du coup fatal (et une seconde fois à l'accusé du serveur)

**Où.** `game_state.gd:4460` (appel depuis `_do_end_round`), `:4740-4774` ; `match_record.gd:247-271, 275-285, 232-243` ;
`ranked_identity.gd:345-350, 513-516` ; `conditions_de_match.gd:122-146` ; `screen_history.gd:154-159`.

**Constat.**
```gdscript
# match_record.gd:247
static func append_to_history(record: Dictionary, path: String = HISTORY_PATH) -> Array:
	var history := load_history(path)          # get_as_text + JSON.parse_string du fichier ENTIER
	history.append(record)
	history = cap(history, HISTORY_MAX)         # slice → copie
	return history if _write_history(history, path) else []   # JSON.stringify(history, "\t") + .tmp + rename
```
Le journal ne croît pas sans borne (200 entrées, écriture atomique, repli sur journal vide) — c'est bien. Mais c'est un
fichier pretty-printé de ≈ 0,38 Mo (simulation du schéma v6, `conditions.machine` et `gadgets` compris ; réel non vu) traversé en
entier à chaque match. L'appel est synchrone, en tête de `_do_end_round`, **avant** l'`await frame_post_draw` qui attend le
dessin de l'image d'impact (`:4515`). Dans la même chaîne, `_conditions.resume()` (`:4740`) copie, trie et boucle en GDScript sur
toutes les durées d'image de la manche (18 k valeurs à 60 fps, 147 k à 490 fps, `conditions_de_match.gd:128-146`). À l'accusé
du serveur, `_settle_front` appelle `mark_reported`, qui refait lecture + écriture complètes — **pour tout match en ligne**,
classé ou amical (`report_match` met tout en file). Autres lecteurs : `ScreenHistory.refresh` fait **deux** `load_history`
(`recent_report` + `session_summary`) à la construction de l'UI et à chaque entrée dans l'écran.

**Coût.** PROUVÉ : tout est synchrone sur le fil principal. ESTIMÉ : parse 5-15 ms + stringify 5-15 ms + écriture < 1 ms ≈
**10-30 ms**, plus 2-25 ms pour `conditions.resume()` selon les fps ⇒ **15-50 ms dans l'image du coup fatal**, puis 10-30 ms
à l'accusé (pendant le sang ou le gel). Un gel de 0,15 s suit (`KILL_FREEZE_DURATION`, `game_state.gd:236`) : probablement
peu visible, mais c'est l'instant le plus regardé du jeu, et `_conditions.arreter()` (`:4435`) précède l'archive, donc ce
hoquet n'est dans aucun relevé de cadence.

**Proposition.** Tenir le journal en mémoire (`static var` par chemin) : `append_to_history` et `mark_reported` modifient le
tableau mémoire (instantané, et l'ordre entre les deux est garanti — important si l'accusé arrive avant l'écriture) et
demandent UNE écriture coalescée, différée après le gel (`call_deferred` + minuterie ; le fil de travail n'est pas
nécessaire pour un premier gain) ; `load_history` rend une copie du cache. **Ne différer que l'ÉCRITURE, pas la construction
de l'enregistrement** : la télémétrie des gadgets et les conditions doivent rester figées à l'instant du coup (commentaires de
`telemetrie_gadgets.gd`, deux pairs qui doivent s'accorder). Pour `resume()` : cumuler la somme des durées pendant la manche
(`echantillonner`) et ne boucler que sur le centile lent. Le JSON compact ne retire que ~19 % d'octets (simulation) : pas un levier.

**Gain attendu.** −10 à −30 ms dans l'image du coup fatal et dans la fenêtre d'accusé ; −5 à −20 ms avec la somme
incrémentale ; −1 lecture sur 2 au lancement de l'UI.

**Risque.** Perte de la dernière entrée si le processus s'arrête avant l'écriture différée : vidage obligatoire dans le chemin
d'arrêt propre (CLAUDE.md, « Arrêt propre ») et sur `NOTIFICATION_WM_CLOSE_REQUEST`. Les suites qui relisent le fichier juste
après l'archivage (`test_rejeu_journal`, `test_screen_historique`, `test_match_history_view`, `test_fin_de_match`) doivent
passer par le cache ou forcer le vidage. L'écriture `.tmp` + rename reste.

**Effort.** M.

**Sévérité.** MINEUR.

**Statut ROADMAP.** NOUVEAU. Déjà tranché : plafond de 200, écriture atomique, garde `archiver_les_matchs` (l. 5008-5050).
Aucune mention de la durée de l'écriture.

**Comment le vérifier.** Script headless qui écrit un journal de 200 entrées réalistes puis chronomètre
`append_to_history` (la sérialisation JSON ne dépend pas du rendu). En fenêtre : `Time.get_ticks_usec` autour de
`_archive_match_result` ; mesurer sur le VRAI `user://match_history.json` d'Adrien (je n'en connais pas la taille réelle).

---

### CAR-05 — `ArenaDecor` re-cuit sa texture (SubViewport + `get_image()` + ré-envoi) à chaque construction d'arène, alors que l'en-tête promet « par carte »

*(hors de ma liste de fichiers, trouvé en remontant `rebuild_arena` ; à croiser avec l'agent rendu/iso)*

**Où.** `arena_decor.gd:22-26` (promesse), `:114-131` (`build`), `:169-174` (`_ready`), `:176-211` (`_cuire`) ;
`game_state.gd:1452-1460, 1538`.

**Constat.**
```gdscript
# arena_decor.gd:169
func _ready() -> void:
	if not _est_copie:
		_cuire()
# :188  vue.size = Vector2i(_cadre.size)                    ← (grille + 2) × 35 px
# :206  var img: Image = vue.get_texture().get_image()      ← lecture GPU → CPU (synchronise le GPU)
# :210  _cuit = ImageTexture.create_from_image(img)         ← ré-envoi
```
`rebuild_arena` supprime les `ArenaDecor*` (`game_state.gd:1452-1460`) et en reconstruit un (`:1538`), dont le `_ready` relance la
cuisson. Aucun cache statique, contrairement à `MurLed._cache_texture` (`mur_led.gd:131-132`). Surface cuite : arène standard
1 190×1 190 px = 1,4 Mpx (5,7 Mo RGBA8) ; salle 8.9 : 3 570×2 870 = 10,2 Mpx (**41 Mo**), soit une cible de rendu + une image CPU
+ une texture, ≈ 120 Mo transitoires, à chaque départ et chaque réessai.

**Coût.** PROUVÉ : la cuisson est refaite à chaque construction. ESTIMÉ : le `get_image()` bloque sur le GPU puis copie :
2-5 ms (standard), 15-40 ms (8.9), sur la 2ᵉ ou 3ᵉ image du départ — après `_conditions.commencer()`, donc comptés dans le
1 % bas archivé.

**Proposition.** Un cache statique `{clé = hash(data) + pochoirs_actifs() → ImageTexture}` d'une carte, comme `MurLed` :
`build()` pose `_cuit` d'emblée sur l'original et les copies, `_cuire()` ne s'exécute que sur échec de cache.
`poser_pochoirs()` (banc) invalide. `PeintureIso` recopie déjà `_cuit` de la source quand il diffère
(`peinture_iso.gd:191-195`) : compatible.

**Gain attendu.** Supprime une lecture GPU et deux transferts à chaque revanche et chaque réessai sur la même carte :
≈ −2 à −5 ms (standard), ≈ −15 à −40 ms et ≈ −80 Mo de pic (8.9).

**Risque.** La texture devient partagée entre manches : ne jamais la libérer avec le nœud (elle est une `RefCounted`, donc
sûre tant que le cache la tient). Visuel inchangé.

**Effort.** S-M.

**Sévérité.** MINEUR (MAJEUR sur les grandes salles d'aventure, avec CAR-03).

**Statut ROADMAP.** NOUVEAU — **écart d'intention** : la ROADMAP et l'en-tête disent « une fois par carte » (l. 22327, 28721 ;
`arena_decor.gd:22`), le code fait une fois par construction.

**Comment le vérifier.** `Time.get_ticks_usec` entre `build()` et la pose de `_cuit` ; `Performance.RENDER_TEXTURE_MEM_USED`
avant/après une revanche. Les suites headless n'exercent que le dessin direct (`arena_decor.gd:177`).

---

### CAR-06 — `CandelaTileSet.create_tileset()` régénère à chaque manche un atlas qui ne change jamais (≈ 4 900 `set_pixel` en GDScript)

**Où.** `candela_tileset.gd:69-96` ; `game_state.gd:1462` (`map_editor.gd:154`, une fois).

**Constat.** Quatre tuiles de 35×35 peintes pixel par pixel : `_generer_dalle_encre` ×2 (1 225 `set_pixel` + 289 pores avec
`_hachage` + fissures chacune, graines fixes 101 et 203), `_generer_mur_atelier` (1 225), `_generer_mur_bas` (1 225), puis
`ImageTexture.create_from_image`, `TileSet` et `TileSetAtlasSource` neufs. Le résultat est déterministe (« identiques sur
toutes les machines ») et les trois calques de la manche le partagent déjà ; `_duplicate_layer_for_player` partage la ressource.

**Coût.** PROUVÉ : régénéré à chaque `rebuild_arena`. ESTIMÉ : 1,5-3 ms (4 900 appels natifs depuis GDScript ≈ 0,3 µs chacun
+ ~600 `_hachage`) et un téléversement de 70×70 px.

**Proposition.** `static var _tileset: TileSet` ; `create_tileset()` le rend s'il est valide.

**Gain attendu.** 1,5-3 ms par départ de manche.

**Risque.** Très faible : à vérifier qu'aucun appelant ne mute le `TileSet` (les outils et suites listés par `grep
create_tileset` ne font que l'assigner). Une statique est signalée « leaked at exit » en debug, sans effet.

**Effort.** S.

**Sévérité.** ANECDOTIQUE.

**Statut ROADMAP.** NOUVEAU.

**Comment le vérifier.** Micro-banc headless `create_tileset()` ×100 ; `test_arena_build`, `test_arena_lighting`,
`test_editor_tools`.

---

### CAR-07 — `MapCodec.validate` ne borne ni le nombre de runs ni le nombre de cases : un code de ~16 Ko demande 128 M de cases (≈ 3 Go) ; importé, il fige le démarrage à chaque lancement

*(hors cadence : robustesse et équité en ligne)*

**Où.** `map_codec.gd:73-94` (`decode_runs`), `:110-136` (`from_share_code`), `:144-192` (`validate`), `:30` (garde 8 Mo) ;
`map_data.gd:109-114` (`_scan_dir`), `:340-355` (import), `:471-478` (`adopt_shared_map`) ; `game_state.gd:1855, 1868-1871` ;
`audio_manager.gd:1062`.

**Constat.**
```gdscript
# map_codec.gd:85-92
var length := int(parts[2])
if length <= 0 or length > MAX_GRID:        # borne UN run (≤ 128)…
	continue
for i in range(length):
	cells.append(Vector2i(x + i, y))        # …mais ni le nombre de runs, ni la longueur de la chaîne
```
Le garde-fou porte sur la taille **décompressée** (8 Mo, `:30`) et la longueur d'un run. `validate()` ne vérifie ni que
`floor`/`walls`/`low_walls` sont des chaînes (`String(normalized["floor"]).is_empty()` seulement, `:180`), ni leur longueur, ni
le nombre de runs, ni les coordonnées. Un JSON de 7,6 Mo fait d'un million de runs « 0,0,128 » se comprime en **15 764
caractères** de code de partage (calcul Python, `port_*`) et se décode en **128 M de `Vector2i`** — des `Variant` de 24 octets
(un `Array[Vector2i]` typé stocke des `Variant`) ⇒ ≈ 3 Go, au moins 1 Go même à 8 octets par case (ESTIMÉ). Deux chemins : (1) *import* : `import_share_code` →
`save_map` écrit le fichier (validé sans décodage) puis `refresh_catalog()` → `_scan_dir` décode **pour compter**
(`get_floor_cells(data).size()`, `map_data.gd:112`) ; la même analyse se rejoue à **chaque démarrage** (`MapData._ready`) tant
que le fichier est dans `user://maps/` : le jeu se fige ou meurt avant d'avoir une interface où supprimer la carte. (2) *en
ligne* : le client adopte sans réserve le code de l'hôte (`rpc_start_round`, `game_state.gd:1855`) ; `rebuild_arena` →
`accorder_a_la_carte` décode les murs.

**Coût.** PROUVÉ par lecture et par l'arithmétique ci-dessus ; non exécuté. ESTIMÉ : 15-30 s de GDScript et ~3 Go transitoires
par décodage ; crash possible selon la RAM.

**Proposition.** Dans `validate()`, **avant tout décodage** et en refus propre (leçon l. 9206 : pas d'erreur de script sur
une donnée venue d'un JSON) :
```gdscript
const MAX_RLE_CHARS := 131072       # 128 rangées × 64 runs × 16 caractères
const MAX_RUNS := 16384
for cle in ["floor", "walls", "low_walls"]:
	var brut: Variant = normalized.get(cle, "")
	if typeof(brut) != TYPE_STRING or (brut as String).length() > MAX_RLE_CHARS \
			or (brut as String).count(";") > MAX_RUNS:
		return _fail("Carte trop complexe")
```
et dans `decode_runs` un arrêt à `MAX_GRID * MAX_GRID * 4` cases ; `MapCodec.count_cells(encoded)` (somme des longueurs, sans
`Vector2i`) pour `_scan_dir` et `accorder_a_la_carte`. Une carte légitime ≤ 128×128 ne dépasse pas 16 384 cases par famille.

**Gain attendu.** Mémoire bornée à ~1,5 Mo par famille ; démarrage : `_scan_dir` n'a plus à décoder pour compter.

**Risque.** Refuser une carte légitime : impossible sous ces bornes (les livrées font ≤ 1,2 Ko et 72 runs, les niveaux d'aventure
≤ 7,6 Ko). `MapCodec.VERSION` ne bouge pas, donc l'empreinte du fil (`test_protocole`) non plus.

**Effort.** S.

**Sévérité.** MAJEUR (robustesse, hors cadence).

**Statut ROADMAP.** NOUVEAU. Voisin : « vérifier le type avant de lire, sur toute donnée qui a traversé un JSON » (l. 9206) et
l'en-tête du codec (« toute entrée est traitée comme hostile », `map_codec.gd:107-109`).

**Comment le vérifier.** Ajouter à `tools/test_map_codec.gd` un code à 100 000 runs : `ok == false` en < 50 ms ;
`tools/test_carte_partagee.gd` pour l'adoption. Non exécuté ici.

---

### CAR-08 — Miniatures : le cache statique survit à l'éditeur et rend une vignette périmée ; tout est repeint à la construction de l'UI et à chaque changement de catalogue

**Où.** `map_thumbnail.gd:40, 52-58, 83-86, 108-114` ; `map_gallery.gd:94, 284-303, 347, 478-481, 508-512` ;
`ui.gd:1361-1363, 6529` ; `map_data.gd:262-264, 284` ; `map_editor.gd:1257`.

**Constat.**
```gdscript
# map_thumbnail.gd:52-58
var key := "%s@%d" % [map_id, scale_px]
if not map_id.is_empty() and _cache.has(key):
	var cached: ImageTexture = _cache[key]
	if is_instance_valid(cached):
		return cached
```
`_cache` est un `static var` : il survit aux changements de scène. Sa seule invalidation est `MapGallery._on_catalog_changed`
(`clear_cache()`), connecté dans le `_ready` de la galerie **vivante**. Or l'éditeur est une autre scène
(`change_scene_to_file`, `map_gallery.gd:512`) : la galerie y est libérée, `save_map` y émet `catalog_changed` sans abonné, et au
retour `main.tscn` est réinstancié. La nouvelle galerie reconstruit ses tuiles avec la clé `id@échelle` — inchangée, puisque
`save_map` conserve l'`id` d'une carte ré-enregistrée (`map_data.gd:262-264`). Résultat attendu : **la vignette de la carte
perso retouchée montre l'ANCIEN plan** (galerie et fiche de carte de `ui.gd:6529`) jusqu'à un `catalog_changed` avec galerie
vivante ou au redémarrage. `MapThumbnail.invalidate()` n'est appelé nulle part. Côté coût (froid) : N peintures de 256² (≈ 1 000
`fill_rect` + décodage, ESTIMÉ 1,5-2 ms chacune) à la construction de l'UI, puis tout repeint à chaque `catalog_changed` ; cache
non borné (256 Ko par carte et par échelle). Même famille, une ligne : `MapData.refresh_catalog` relit, parse, revalide (deux à trois
`duplicate(true)`) et décode deux fois CHAQUE fichier à chaque sauvegarde, suppression ou import (`map_data.gd:63-78, 90-124`), ≈ 0,3-1 ms par
carte (ESTIMÉ) : froid, sans importance tant que le catalogue reste à quelques dizaines de cartes.

**Coût.** Défaut PROUVÉ par lecture (non exécuté). Coût de cadence : nul (froid) ; ≈ 10 ms au lancement de l'UI avec 6 cartes,
linéaire ensuite.

**Proposition.** Clé = `id@échelle@hash(floor, walls, low_walls, spawns, grid_size)` (ou `data.hash()`), ce qui rend l'invalidation
inutile pour la correction ; borner à ~64 entrées ; `_on_catalog_changed` n'a plus à tout vider.

**Gain attendu.** Corrige la vignette périmée ; pas de gain de cadence.

**Risque.** Nul (cache pur).

**Effort.** S.

**Sévérité.** MINEUR.

**Statut ROADMAP.** NOUVEAU. Le cache « par `id` » est le plan d'origine (`docs/PLAN_EDITEUR_CARTES.md:231`) ; DA4.8
(l. 13915) ne le mentionne pas.

**Comment le vérifier.** Script headless : `render_fit(d, 256)`, modifier `d["floor"]`, `render_fit(d, 256)` — les textures doivent
différer. À la main : éditer une carte perso, sauvegarder, revenir au menu, ouvrir la galerie.

---

### CAR-09 — Éditeur : `encode_runs` trie par `sort_custom` + lambda, et la validation (≤ 6,7 Hz pendant qu'on peint) ré-encode 3 calques et décode ~10 fois

**Où.** `map_codec.gd:37-69` ; `map_data.gd:367-392` ; `map_editor.gd:192-200, 1016-1019, 1023-1057`.

**Constat.**
```gdscript
# map_codec.gd:41-46
var sorted_cells := cells.duplicate()
sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y: return a.y < b.y
	return a.x < b.x)
```
`get_used_cells()` rend les cases dans l'ordre d'insertion, pas trié ; le tri est nécessaire mais coûte un appel de lambda
GDScript par comparaison (n log n ≈ 6 400 pour 676 cases, ≈ 230 000 pour 16 384). `_run_validation` = `extract_from_layers`
(3 `encode_runs`) + `check_playable` (3 décodages) + `set_grid_info` (2 décodages **pour deux `.size()`**) +
`get_reachable_cells` (3 décodages + BFS) + `_refresh_orphans` (2 décodages), dès qu'un geste touche une cellule, au plus
toutes les 0,15 s (`VALIDATION_INTERVAL`).

**Coût.** PROUVÉ : structure. ESTIMÉ : 7-10 ms par passage sur 32×32 (≈ une image sur neuf dépasse 16 ms pendant qu'on peint),
~100-150 ms sur une grille 128×128 pleine (l'éditeur accepte jusqu'à `MAX_GRID = 128`).

**Proposition.** Trier des **clés entières** : `PackedInt64Array`, clé `((y + 32768) << 16) | (x + 32768)`, `sort()` natif,
puis les runs en un balayage (sortie identique, doublons ignorés comme aujourd'hui, coordonnées négatives couvertes par le
décalage) ; `MapCodec.count_cells()` pour `set_grid_info` ; réutiliser `_cached_data` pour F5 et le partage quand
`_validation_dirty` est faux.

**Gain attendu.** ×10 à ×50 sur `encode_runs` ; validation ≈ 2-3 ms sur 32×32, ≈ 10-15 ms sur 128×128 (ESTIMÉ).

**Risque.** Sortie à vérifier octet pour octet (`test_map_codec`, `test_editor_tools`). Éditeur seulement : aucun effet sur le
duel.

**Effort.** S.

**Sévérité.** MINEUR.

**Statut ROADMAP.** NOUVEAU.

**Comment le vérifier.** Micro-banc headless de `encode_runs` sur 676 et 16 384 cases, avant/après ; `tools/test_map_codec.gd`
pour l'identité de la sortie.

---

### CAR-10 — Éditeur : éléments statiques redessinés à chaque image ; historique d'annulation lourd en pire cas

**Où.** `map_editor.gd:192-195, 1309-1321` (`MAX_ORPHAN_HIGHLIGHT` :62) ; `map_editor_tools.gd:59-71, 234-236, 371-379`.

**Constat.** `_process` appelle `cursor.queue_redraw()` et `preview_layer.queue_redraw()` à chaque image ; `_on_preview_draw`
redessine jusqu'à 600 `draw_rect` d'orphelines (statiques), deux marqueurs (`draw_arc` 32 segments + `draw_string`) et l'aperçu
de rectangle — seuls les marqueurs pulsent. Côté historique : `apply_cell` crée une clé `"%s:%d:%d" % [...]` et un `CellEdit`
(`RefCounted`) **par case touchée** ; 100 transactions (`HISTORY_DEPTH`) conservées, un remplissage 128×128 (16 384 cases)
pèse de l'ordre de 4 Mo.

**Coût.** ESTIMÉ : 0,1-0,3 ms/image avec 600 orphelines (éditeur seulement) ; pire cas mémoire de l'annulation de l'ordre de la
centaine de Mo (100 remplissages complets, usage extrême).

**Proposition.** Orphelines dans un calque à part, redessiné seulement à `_refresh_orphans` ; `CellEdit` en tableaux plats
`PackedInt32Array` par transaction.

**Gain attendu.** Négligeable en pratique.

**Risque.** Nul pour le duel.

**Effort.** S-M.

**Sévérité.** ANECDOTIQUE.

**Statut ROADMAP.** NOUVEAU, partiellement DÉJÀ-TRANCHÉ : les plafonds (600 orphelines, 100 crans, 90 éclats) sont des choix de
l'auteur, `map_editor.gd:58-62`, `map_editor_tools.gd:42`.

**Comment le vérifier.** Moniteur `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` dans l'éditeur avec une carte à 600 orphelines ;
`test_editor_tools.gd` pour l'historique.

---

## 3. Ce qui est déjà bien fait (à ne pas casser)

1. **Collision et occlusion naissent des mêmes rectangles** (`map_geometry.gd:290-311`, `_fill_body`) et la fusion donne 4 à 11
   rectangles de murs sur les six cartes de duel, un seul `StaticBody2D` par famille. La cible du plan (< 20 formes et
   < 20 occluders sur 32×32, `docs/PLAN_EDITEUR_CARTES.md:275`) est tenue avec de la marge ; en aventure, 113 occluders au
   plus (ch. 9 niv. 7). La bordure d'une case en fosse et l'`OCCLUDER_INSET` sont des choix de lecture de la lumière : ne pas y toucher.
2. **Le rejeu est dimensionné en temps** (60 Hz fixe, 450 instantanés = 7,5 s), pas en images — la leçon des 492 fps y est
   payée — et sa mémoire est constante quelle que soit la durée du match. Un `Snapshot` typé plutôt qu'un Dictionary par
   joueur ; traces de poudre aplaties sans allocation par trace ; `_melanger` unique pour que le pré-tracé de la killcam ne perde rien.
3. **Le journal est plafonné, écrit de façon atomique** (`.tmp` + rename), retombe sur un journal vide s'il est abîmé, et ne
   peut pas être pollué par les outils de mise en scène (`archiver_les_matchs`). L'issue d'un match n'a qu'un seul calcul.
4. **Les miniatures sont peintes en `Image`** (aplats, `fill_rect` natif), sans SubViewport, sans fichier, à 256 px pour ne
   jamais être agrandies (DA4.8) : instantanées, déterministes et jamais désynchronisées du contenu.
5. **L'éditeur est économe pour ce qu'il dessine** : grille de fond dessinée une fois en un seul `draw_multiline_colors`,
   validation bornée à 150 ms avec reconstruction du panneau seulement quand la signature change (`map_editor_hud.gd:712-722`),
   éclats de pose plafonnés à 90, orphelines à 600, annulation à 100 crans. F5 ne reconstruit pas l'arène.
6. **Le codec a les bons réflexes de forme** : garde anti-bombe de décompression, type vérifié avant lecture pour `grid_size`,
   migrations v2 → v3 → v4, RLE compacte (6,1 Ko pour les six cartes livrées). CAR-07 ne demande qu'à étendre la même logique
   au nombre de runs.
7. **Le patron « se taire hors écran » existe déjà** (`MenuArene`, `MenuWatcher`) et le cache « une fois par carte » aussi
   (`MurLed`). Les corrections proposées ici l'étendent ; elles n'inventent rien.
8. **`rebuild_arena` nettoie proprement** ce qu'il reconstruit (`remove_child` puis `queue_free`, noms libérés, empreinte de
   rencontre par `data.hash()`), et les nœuds dynamiques portent des noms explicites.

---

## 4. Questions ouvertes

**À mesurer (ce que seule une mesure tranche)**
1. **Durée réelle de `rebuild_arena`**, section par section (`Time.get_ticks_usec` + `print`), sur le M3, pour l'arène
   standard et pour la salle 8.9 (100×80), avec et sans PNJ. Elle décide si CAR-03, CAR-05 et CAR-06 valent leur effort.
2. **Coût réel de `MapGallery._process`** (CAR-01) avec 6 puis ~30 cartes ; confirmer le mécanisme moteur (notification de thème
   par tuile).
3. **Taille réelle de `user://match_history.json`** d'Adrien (plein à 200 ?) et durée de `append_to_history` dessus (CAR-04) ;
   durée de `_conditions.resume()` à 60 et à 490 fps.
4. **Durée de `pop_front` sur 450 éléments** dans le contexte réel (CAR-02) avant de décider d'un anneau.

**À trancher (Adrien)**
5. **`MAX_GRID = 128` est-il voulu pour des cartes de duel** (16 384 cases par famille) ? Les bornes de CAR-07 s'en déduisent ;
   et quelle limite pour les salles d'aventure (100×80 livrée) ?
6. **Message de refus d'un code trop complexe** : l'afficher tel quel (« Carte trop complexe ») ?
7. **Journal : le garder en JSON lisible (tabulations) ?** Le compact ne retire que ~19 % des octets (CAR-04) ; la lisibilité humaine
   du fichier est-elle un objectif ?
8. **Écriture différée du journal** : acceptable de ne l'écrire qu'après le gel de 0,15 s, avec vidage à l'arrêt propre ?
9. **`ArenaDecor` « une fois par carte »** (l. 22327, 28721) : l'intention est-elle de le cuire une fois par carte et par
   session, pochoirs d'essai compris ?
10. **Définition de la mesure** : les 2-5 images de construction (iso + décor) tombent après `_conditions.commencer()` et pèsent
    dans le 1 % bas archivé et F6. Faut-il différer `commencer` de quelques images, comme `arreter()` précède la killcam ?

**Pointeurs vers d'autres domaines (constatés en passant, non creusés)**
- *Joueurs / balles* : `MursBas.chevauche_cercle` (`player.gd:1560-1563`, deux balayages par corps et par tick physique) et
  `MursBas.franchit` parcourent linéairement `MursBas.murs_de_la_manche` : 0 rectangle sur les six cartes de duel, jusqu'à 44
  dans les salles à murs bas (18 niveaux ; ch. 7 niv. 8 : 44, ch. 9 niv. 7 : 37), où se trouvent aussi des PNJ.
- *Lumières* : nombre d'occluders produits : 4 (Standard), 9-11 (autres duels), médiane 10 et max 113 en aventure
  (`port_solo.py`). Je ne donne que le nombre ; le coût par lumière est du ressort de l'agent lumières. Les occulteurs par
  contours (OM6) sont **CONNU-OUVERT, titulaire OMBRES** : voir §5 pour les chiffres que je peux leur apporter.
- *Iso* : `_construire_les_murs` et `_poser_peinture` repassent à chaque départ (`presentation_3d.gd:516-518`), avec les
  grilles de CAR-03.
- *Famille 4.1 (ROADMAP l. 2640)* : consultée, elle traite de la reconnexion pendant la killcam (tests), pas de coût ; seule
  donnée utile : la séquence de fin dure ~11 s (mort à T, killcam close vers T+11 s, l. 2672-2676).

---

## 5. Pour le chantier OMBRES (OM6, « murs par contours ») — chiffres que l'audit peut apporter

OM6 est **CONNU-OUVERT, titulaire chantier OMBRES** (CONTEXTE_CHANTIERS_EN_COURS.md §1-2) : je ne le re-propose pas, je donne le
chiffre qui lui manque. Port Python fidèle de `trace_contours` (`port_contours.py`, dans ce dossier ; comptage seulement),
comparé aux occluders actuels (un rectangle fusionné = un `LightOccluder2D` de 4 sommets) :

| Carte (murs hauts) | Occluders actuels | Sommets actuels | Contours | Sommets des contours |
|---|---|---|---|---|
| Arène Standard | 4 | 16 | 2 | 8 |
| Arène Circulaire | 9 | 36 | 3 | 28 |
| Le Cloître | 9 | 36 | 7 | 28 |
| L'Usine | 11 | 44 | 9 | 36 |
| La Croisée | 11 | 44 | 7 | 36 |
| Le Bunker | 11 | 44 | 5 | 28 |
| Aventure, médiane (murs hauts + bas) | 10 | 40 | 6 | 28 |
| Aventure, ch. 9 niv. 7 (max) | 113 | 452 | 88 | 412 |
| Aventure, ch. 8 niv. 9 (la plus grande salle) | 61 | 244 | 52 | 232 |
| Aventure, ch. 7 niv. 8 | 48 | 192 | 20 | 146 |

Lecture : sur les cartes de duel, les contours retirent **de 2 à 6 occluders et de 8 à 16 sommets** (−18 % à −50 % de sommets), en
valeur absolue quelques dizaines de sommets ; en aventure, la médiane passe de 40 à 28 sommets et les cas extrêmes (113 occluders)
de 452 à 412. L'ordre de grandeur de la géométrie d'ombre ne change donc pas sur ces cartes : le gain annoncé (20-40 % de dessins
d'ombre en moins) dépendra surtout de ce que le moteur facture par occluder (test de portée par lumière) plutôt que par sommet —
**à mesurer**, pas à supposer. Risque non vu : `trace_contours` suit le bord PLEIN des tuiles, alors que les occluders actuels sont
rentrés de `OCCLUDER_INSET` = 3 px pour que la face du mur reçoive la lumière (`map_geometry.gd:98, 380-396`). Passer aux contours
suppose de redécaler les polygones, faute de quoi les murs « retombent dans leur propre ombre » (commentaire de
`_build_rect_occluder`). Les cartes joueur peuvent, elles, avoir de nombreux piliers isolés (jusqu'à ≈ 8 200 occluders au pire),
où les contours ne gagnent rien : un damier reste un damier.

