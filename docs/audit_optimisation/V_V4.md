# V4 — Vérification contradictoire : le départ de manche et le solo

Commit `52a29c1` (0.8.3 + SOLO S12). Rôle : contradicteur. **Lecture seule, Godot non lancé.** Constats vérifiés :
ETA-04, CAR-03, CAR-05, CAR-06, GEO-02, GEO-03, BOT-04 (la famille « `rebuild_arena` »), puis BOT-01, BOT-03, BOT-05, BOT-02, BOT-09.
Rapports d'origine : `06_ETA_game_state.md`, `14_CAR_cartes_replay.md`, `02_GEO_geometrie.md`, `12_BOT_bot_solo.md`.
Scripts de recompte : `audit/v4/recompte_V4.py` (sortie : `audit/v4/recompte_V4.sortie.txt`).

---

## 0. Méthode, étalons, limites

**Ce qui est PROUVÉ ici** : ce que le code fait, qui l'appelle et à quel rythme (relu ligne à ligne, appelants remontés jusqu'à
l'événement source) ; tout nombre d'appels, de cellules ou de pixels (recomptés par un port Python fidèle de `decode_runs`,
`build_grid`, `build_solid_grid`, `NavigationBot._construire/_fabriquer_astar`, et des tailles d'images de `image_proximite_usure`).
**Ce qui est ESTIMÉ** : toute durée. Je n'ai pas pu en mesurer une seule (consigne : Godot interdit). Mon modèle de coût est calé sur
les **deux seules mesures GDScript du dépôt** :

| Étalon | Source | Lecture |
|---|---|---|
| 3 × 16 384 `set_pixel`, boucle à ~9 appels natifs = 8,5 ms | `fusee.gd:338-340` | ≈ 0,17 µs par itération, soit ≈ 15-20 ns par appel natif (Mac M3) |
| cuisson LED 272² en deux passes = 83 ms | ROADMAP l.22739 | ≈ 10-15 ns par opération GDScript simple sur tableaux typés |

Coûts unitaires retenus (M3, ×1,5 à ×3 sur un portable de testeur) : opération simple 10-20 ns ; appel d'une fonction GDScript statique
100-150 ns ; `Vector2i(...)` 25-30 ns ; `Dictionary.has/[]=` à clé `Vector2i` 50-100 ns ; `est_libre()` ≈ 0,35 µs ; `Image.blend_rect`
natif 5-25 ns par pixel (**hypothèse, c'est la plus fragile : à mesurer**). Ce modèle donne des durées **environ deux fois plus basses**
que celles des auditeurs pour le GDScript pur (CAR-03, BOT-03), 3 à 5 fois plus basses pour BOT-05, dans la partie basse de leur fourchette pour BOT-01, et du même ordre pour le natif (GEO-02). Il vaut ±2× :
j'écris « à mesurer » partout où une décision en dépend.

**Ce que je n'ai pas vérifié** (moteur, non lisible ici) : le coût réel de `Image.blend_rect/convert/resize` en 4.7, la
synchronisation GPU d'un `get_image()` sur Metal, l'ordre « mise en file puis exécution locale » d'un RPC `call_local` et le moment
du vidage du paquet par le transport (§ 7).

---

## 1. Verdicts

| ID(s) | Verdict | Sévérité corrigée | Coût corrigé (ESTIMÉ sauf mention) | Statut |
|---|---|---|---|---|
| **ETA-04** (parapluie) | CONFIRMÉ AVEC RÉSERVE | MINEUR | GDScript + nœuds ≈ 15-40 ms, **+ 0,05-0,3 s d'image d'usure (GEO-02, absente du chiffre d'ETA)**, + 2-10 ms de relecture du décor ; ×1 par départ | NOUVEAU |
| **CAR-03 + GEO-03 (build_grid) + BOT-04** | CONFIRMÉ AVEC RÉSERVE | MINEUR (ANECDOTIQUE en duel) | 20 `build_grid` PROUVÉS (37 en salle 8.9) ; 0,5-0,9 ms l'un en 32×32, 4-5 ms en 100×80 : ≈ 10-18 ms par départ de duel, ≈ 150-200 ms en 8.9 | NOUVEAU |
| **GEO-02** | CONFIRMÉ | MINEUR (MAJEUR si > 0,5 s se mesure sur les 10 salles ≥ 3 Mpx) | 8 passes sur 7,7-12,7 Mpx (PROUVÉ) : 0,05-0,3 s par départ de duel ; 0,4-2,3 s en 8.9 | NOUVEAU (écart d'intention l.28423) |
| **CAR-05 + GEO-03 (décor)** | CONFIRMÉ | ANECDOTIQUE en duel, MINEUR ≥ 3 Mpx | 1 relecture GPU de 5,7 Mo (duel) à 41 Mo (8.9) par départ : 2-10 ms / 15-40 ms | NOUVEAU (écart d'intention) |
| **CAR-06 + GEO-03 (tileset)** | CONFIRMÉ | ANECDOTIQUE | 4 900 `set_pixel` ≈ 1 ms | NOUVEAU |
| **BOT-01** | CONFIRMÉ | MINEUR | ≈ 0,7-1,6 s une fois par session (877 k appels `est_libre`, 66 % dans l'A* jeté) | NOUVEAU |
| **BOT-09** | CONFIRMÉ | MINEUR | gèle 0,1-0,35 s (salle médiane), 0,4-1,5 s (salles 8.x), jusqu'à ≈ 2,7 s (8.9) sur une image figée, à chaque entrée et chaque réessai | NOUVEAU |
| **BOT-03** | CONFIRMÉ | ANECDOTIQUE (MINEUR en 8.x) | ≈ 0,3 ms (médiane, 596 cases) à ≈ 3 ms (8.9, 7 148 cases) par repli | NOUVEAU |
| **BOT-05** | CONFIRMÉ AVEC RÉSERVE (latent) | ANECDOTIQUE | 5-70 µs par pas dans le cas courant ; 0,3-1,1 ms si la trace tombe à 14-22 cases du sol | NOUVEAU |
| **BOT-02** | CONFIRMÉ AVEC RÉSERVE | ANECDOTIQUE (MINEUR en 8.8/8.9) | ≈ 15-50 µs par PNJ et par pas ; 42 µs/pas médiane des 100 salles, 273 µs en 8.9 | CONNU-OUVERT (coût) / NOUVEAU (proposition) |

Aucun des dix constats ne recoupe le lot OM6 : **aucun « DÉJÀ PRIS EN CHARGE »**. Seul recoupement de fichier : `map_geometry.gd` et
`presentation_3d.gd` (§ 5).

**GEO-03** (rapport GEO) est un recoupement de trois pièces jugées ailleurs : `build_grid` ×20 (V4-B), décor cuit (V4-D), tileset (V4-E). Sa sévérité propre (ANECDOTIQUE, MINEUR pour le pic mémoire des grandes cartes) est confirmée ;
son coût (≈ 20-40 ms : tileset 1-2, `build_grid` 10-15, décor 5-15) est **cohérent avec mon modèle (≈ 14-30 ms)** — c'est CAR-03 (1,2-1,5 ms par `build_grid`) et BOT-04 (8 ms en 8.9) qui sont deux fois trop hauts, pas GEO ; sa proposition de plafonner la cuisson
du décor est refusée (V4-D, point e). **ETA-04** n'est pas un défaut de plus : c'est le parapluie des cinq autres (V4-A), jugé pour ses affirmations propres (masquage, 1 % bas, total).

**Corrections aux auditeurs, en bref** (détails dans les blocs) :
1. ETA-04 dit le départ de manche « masqué par le décompte, hors du 1 % bas » : **faux pour la part `Presentation3D`** (donc GEO-02),
   qui est la première durée relevée par `ConditionsDeMatch` ; vrai pour la part synchrone de `rebuild_arena`. Et son total (30-60 ms)
   oublie la plus grosse pièce, GEO-02.
2. BOT-04 compte 4 `build_grid` côté arène : **il y en a 20** (37 au total en 8.9, pas 21). La part « navigation + perception » est 17 sur 37, pas 17 sur 21.
3. Durées GDScript de CAR-03, BOT-03, BOT-05 : surestimées d'un facteur 2 à 5 selon mon calibrage (les comptes, eux, sont exacts) ; BOT-01 : fourchette ramenée de 0,6-2,5 s à 0,7-1,6 s.
4. BOT-01 : l'A* paresseux retire ≈ 45 % du travail, pas 30-35 %.

---

## 2. La famille « départ de manche » : trois questions

### 2.1 Combien de fois `rebuild_arena()` est-il appelé ?

Deux appelants en production (`grep rebuild_arena *.gd`), les autres sont des bancs et des tests :

| Appelant | Déclencheur | Fréquence |
|---|---|---|
| `GameState._ready` `game_state.gd:628` | montage de `main.tscn` (lancement, retour de l'éditeur de cartes) | 1 par montage, derrière l'intro |
| `_do_start_round` `:1948` | tout départ de manche | 1 par appel |

`_do_start_round` est appelé par : `_start_round` `:1840` (écran scindé), `rpc_start_round` `:1859` (`call_local` : **hôte et client, chacun une fois**),
`_on_training_requested` `:1011` (entraînement), `aventure_poser_la_salle` `:1275` (aventure).

- **Par match** : 1 (format BO1 seul implémenté ; `MatchRecord.Format` porte BO3/BO5 mais `game_state.gd:295` dit « un BO3 devra… » : si un BO3 arrive, ×3).
- **Par revanche** : 1 de plus. **Par lancement d'entraînement** : 1.
- **Aventure** : 1 par entrée de salle, 1 par salle suivante (`_salle_suivante` → `_poser_la_salle` `aventure_partie.gd:333`) et **1 par réessai après mort**
  (`recommencer_la_salle` `:320` → `_poser_la_salle`). Confirmé : « au réessai » oui, c'est la boucle la plus fréquente du solo (la ROADMAP l.33725-33726 classe 7.9, 8.9 et 9.8 « très dures voire injouables »).
- **Jamais** par image, jamais pendant une manche. Côté client en ligne, `MapData.adopt_shared_map` fabrique un `Dictionary` neuf à chaque manche
  (identité différente, contenu identique ; `select_map` et `poser_carte_d_aventure` font de même avec `duplicate(true)`) : tout cache doit être indexé sur le **contenu**, pas sur l'objet.

### 2.2 Où tombe le travail : masqué, ou dans une image visible ?

Il n'existe **aucun rideau de chargement** entre le clic et l'arène (`grep -i rideau *.gd` : uniquement l'habillage des menus, `Charte.PATE_RIDEAU`).

**Duel (local, hôte, client)** — chronologie, ordre des nœuds vérifié (`Presentation3D` est ajoutée sous la racine en différé,
`presentation_3d.gd:370`, donc **après** `Main` dans l'arbre, et elle pose `process_priority = 10000` dans son `_ready` `:463` : son `_process` suit celui de `GameState` dans tous les cas).
`ui.hide_game_over()` (`game_state.gd:1961`, après `rebuild_arena`) remet `_is_main_menu` à faux (`ui.gd:9281`) : la garde « pas sous les menus » de `_vues_a_projeter` (`presentation_3d.gd:556-563`) est levée dès l'image N, donc la construction des murs a lieu dans cette image :

| Instant | Ce que l'écran montre | Travail | Dans le relevé `ConditionsDeMatch` ? |
|---|---|---|---|
| Image N, phase d'entrée (clic, ou paquet reçu au `poll`) | l'écran du clic (menu, salon, écran de fin) | `_do_start_round` : `rebuild_arena` **S0** (GDScript + nœuds, ≈ 15-40 ms) ; `_conditions.commencer()` `:2012` ; décompte armé `:2028` | non : avant le premier échantillon |
| Image N, `GameState._process` | idem | **premier échantillon** `echantillonner()` `:2083` (pose seulement `_dernier_tic_usec`) | — |
| Image N, `Presentation3D._process` `:516-518` | idem | `_construire_les_murs` + `_poser_peinture` : **S**, dont GEO-02 (0,05-0,3 s) | **oui** : c'est la durée entre l'échantillon N et N+1, la première relevée |
| Image N+1 | l'arène, décompte « 3 » | `ArenaDecor._cuire` reprend (SubViewport 1190², `frame_post_draw`, `get_image()`) ; `delta` de N+1 = S0 + S + image | oui |
| 3 s (10 s en classé) | décompte | images ordinaires | oui |

- Selon que la vue iso était éteinte sous le salon (`_is_main_menu` vrai : `_eteindre`, `presentation_3d.gd:497-503`) ou restée allumée, `Presentation3D` fait `_allumer` (vues, lightmaps, capteurs, murs, peinture, `:575-634`) ou seulement
  `_construire_les_murs` + `_poser_peinture` : dans les deux cas dans l'image N ; le premier cas est plus lourd (non chiffré ici, hors liste).
- Le décompte **perd** S0 + S : `countdown_left` est décrémenté par `delta` (`:2122`), qui contient les arrêts. Le « 3 » dure donc ≈ 2,7 s.
- Les arrêts S0 et S sont tous deux **sur l'écran du clic**, pas sous le décompte : l'écran d'avant reste figé, puis l'arène apparaît.
- **Ce que le relevé compte** : S (donc GEO-02) est la première durée relevée, en plus d'être un à-coup de départ. Elle fixe le `pire_image_ms`
  de chaque match et alourdit le 1 % bas des matchs courts : pour un match de 60 s à 100 i/s (6 300 images, 63 « lentes »), une image de 250 ms parmi des
  lentes à 20 ms fait passer le 1 % bas de ≈ 50 à ≈ 42 i/s (ESTIMÉ ; −4 % sur un match de 5 min). Au-delà de `TROU_S` = 0,5 s elle est comptée comme « trou »
  et sortie des durées : sur une machine lente le biais disparaît, et c'est le `trous` du résumé qui le porte. Le banc `bench_framerate` n'est pas touché (échauffement de 12 s).
  CAR-05 avait raison (« comptés dans le 1 % bas archivé ») ; ETA-04 avait tort (« hors du 1 % bas »).

**Aventure (entrée, suivante, réessai)** : tout se passe dans une seule image — `_poser_la_salle` (arène, plafonniers, `NavigationBot`, PNJ) dans le
`_physics_process` de `AventurePartie`, puis `Presentation3D._process` dans la même image — **avant** que `_carton.montrer()` (dernière ligne de `_poser_la_salle`,
`aventure_partie.gd:168`) ne soit rendu. Le joueur voit l'image figée (menu, ou la vue de sa mort) pendant tout le gel, puis le carton. Seuls les à-coups d'après (décor
cuit, première grille de zone) tombent sous le carton opaque. Rien ne masque la construction : c'est BOT-09.

### 2.3 Ce qu'une mémoïsation par CONTENU de carte économiserait

Estimations (M3, ESTIMÉ ; à ×1,5-3 chez un testeur). « Cachable » = résultat fonction du seul contenu de la carte, identique à la revanche / au réessai.

| Poste (appels PROUVÉS) | Duel 32×32, revanche | Salle 8.9, réessai | Où il se loge |
|---|---|---|---|
| 20 `build_grid` (+ 17 en 8.9 : 3 `NavigationBot`, 14 perceptions) | 10-18 ms | 150-200 ms | `map_geometry.gd` |
| 6 (13 en 8.9) `merge_rects`, 2 `trace_contours` | 3-5 ms | 15-20 ms | `map_geometry.gd`, `mur_encre.gd` |
| 4 `image_grille`, `sol_de`, `hash([murs, sol])` | 1-2 ms | 8-12 ms | `iso_materiaux.gd`, `mur_led.gd` |
| **`image_proximite_usure`** | **50-300 ms** | **0,4-2,3 s** | `iso_materiaux.gd` |
| `create_tileset` | ≈ 1 ms | ≈ 1 ms | `candela_tileset.gd` |
| décor : `_analyser_carte` + cuisson + `get_image` | 3-11 ms | 20-50 ms | `arena_decor.gd` |
| `NavigationBot` (construire + A*) | — | ≈ 37 ms (+ 22-45 ms de numérotation au premier repli) | `navigation_bot.gd` |
| **Reste non cachable** (nœuds, `set_cell`, 6 duplications, murs iso, `PeintureIso`, PNJ) | 10-25 ms | 100-200 ms | — |
| **Total sans cache** | **≈ 0,08-0,36 s** | **≈ 0,75-2,8 s** | |
| **Total avec tous les caches** | ≈ 12-30 ms | ≈ 0,15-0,25 s | |

Ce que rapporte chaque étage, à lui seul :
- la mémoïsation de **géométrie** seule (CAR-03, lignes 1-2) : −13 à −23 ms en duel (**≈ 5-15 % du départ**), −165 à −220 ms en 8.9 (≈ 10-30 %) ;
- **GEO-02 seul** : −50 à −300 ms en duel (**≈ 65-85 %**), −0,4 à −2,3 s en 8.9 (≈ 55-80 %) ;
- le **décor** : −3 à −11 ms (duel), invisible (sous le décompte) ;
- **les trois ensemble** : ≈ −90 % en duel, ≈ −85 % en 8.9. Le réessai en 8.9 passerait d'un gel de 1-3 s à ≈ 0,2 s.

**Conclusion de cadrage** : la mémoïsation de `map_geometry.gd` (CAR-03), celle que le brief désigne, **n'est pas la pièce qui rapporte** en duel ; c'est GEO-02, qui vit
dans `iso_materiaux.gd`, fichier qu'aucun lot d'OMBRES ne cite (OM3 peut en toucher le miroir de la pâte, `:533+`, loin de `image_proximite_usure`, `:466`). Le cache de géométrie compte surtout dans les grandes salles du solo
(37 constructions) et parce qu'il absorbe BOT-04 gratuitement.

---

## 3. Blocs par constat

### V4-A — ETA-04 : `rebuild_arena` reconstruit et re-cuit tout à chaque départ

**Verdict : CONFIRMÉ AVEC RÉSERVE. Sévérité : MINEUR. Statut : NOUVEAU.**

**1. Le code.** Conforme à la description. `rebuild_arena` (`game_state.gd:1412-1572`) : purge des 16 nœuds nommés `:1452-1460`, `create_tileset()` `:1462`,
`MapData.apply_to_layers` `:1492`, `MapGeometry.build_collisions` `:1496`, `rects_monde` `:1497`, `MurLed.poser` `:1503`, 6 × `_duplicate_layer_for_player` `:1513-1518`,
`ArenaDecor.build` `:1538`, `MurEncre.build` `:1558`, `Presentation3D.accrocher` `:1572`. Les trois comptes d'ETA tiennent (10 `build_grid` côté `rebuild_arena`, ~37 décodages RLE,
6 duplications). Mais ETA-04 s'arrête à `rebuild_arena` : le crochet pose `_reconstruire = true` (`presentation_3d.gd:372`) et le `_process` de la présentation refait
**tout de suite** les murs et la peinture :
```gdscript
# presentation_3d.gd:516-518 — à chaque rebuild_arena, même carte ou non
if _reconstruire:
    _construire_les_murs()
    _poser_peinture()
# :2194-2203 (extrait) — 10 build_grid de plus, et GEO-02
_murs = IsoGeometrie.build_meshes(data, _mat_mur)
IsoMateriaux.accorder_grille(_mat_mur, data)
if _usure:   # vrai par défaut : `usure_active` = pas de --sans-usure (iso_materiaux.gd:170-172)
    var proximite := ImageTexture.create_from_image(IsoMateriaux.image_proximite_usure(data))
    for m in _mat_sols:    # 2 sols, un par vue (presentation_3d.gd:1893-1897)
        IsoMateriaux.accorder_grille(m, data)
```

**2. La fréquence.** § 2.1 : une fois par départ, jamais par image, jamais en manche.

**3. Le coût.** Total synchrone d'un départ de duel standard ≈ 15-40 ms de GDScript et de nœuds (ETA : 30-60 ms, environ 1,5 à 2 fois trop haut pour cette seule part), **plus GEO-02 (0,05-0,3 s)**, plus la cuisson du décor (CAR-05).
ETA-04 a donc raison que ce n'est « pas du jeu », mais son total est faux par défaut d'un facteur 2 à 6 et sa phrase « hors du 1 % bas » est fausse (§ 2.2).
Pas de chiffre dans la ROADMAP (aucune mesure de `rebuild_arena` : confirmé par grep).

**4. Invariants.** (a) `rebuild_arena` éteint les torches et laisse l'action « appuyée » (ROADMAP l.26057) : toute option « sauter `rebuild_arena` si la même carte »
(ETA-04.4) est **refusée** — couplages trop nombreux. (b) « Les murs ET la peinture, toujours ensemble » (`presentation_3d.gd:509-515`, rapport peinture-perimee 2026-09-28) :
un cache d'image de proximité ou de grille ne touche pas cette règle ; **mettre en cache `_poser_peinture` la romprait** (ses copies sont des enfants de l'arène reconstruite). (c) ETA-04.5
(ne pas construire les copies J2 hors écran scindé) : **refusé**, l'écran scindé se rejoint sans reconstruire. (d) Tests qui épinglent ce code : `test_arena_build`, `test_traces_carte`, `test_traces_rencontre`,
`test_iso_usure` (texte de `presentation_3d.gd`), `test_arena_matter` (texte de `arena_decor.gd`), `test_mur_led`, `test_iso_peinture_carte`.

**5. Statut.** NOUVEAU. Précédent à citer : la LED est déjà mise en cache « une fois par carte » exactement pour cette raison (`mur_led.gd:128-132`, ROADMAP l.22739-22742).

**6. Correctif minimal et preuve cloud.** Dans l'ordre de rapport : GEO-02 (V4-C), puis la mémoïsation exacte de `build_grid` (V4-B), puis `create_tileset` (V4-E), puis le cache de décor (V4-D).
Preuve : un test headless `test_depart_de_manche` qui appelle `rebuild_arena()` deux fois dans le même processus et compare des **compteurs** (constructions de grille : 20 → 3 puis 0 ;
passes `blend_rect` : 8 → 0 ; octets relus au GPU) — indépendants du matériel ; et un chronomètre `Time.get_ticks_usec()` autour de chaque sous-étape (CPU natif et GDScript : valable headless).

---

### V4-B — CAR-03 + GEO-03 (build_grid ×20) + BOT-04 + ETA-04.1 : la même carte re-décodée 20 fois

**Verdict : CONFIRMÉ AVEC RÉSERVE (comptes exacts, durées ×2 trop hautes). Sévérité : MINEUR (ANECDOTIQUE en duel). Statut : NOUVEAU.**

**1. Le code.** `build_grid` (`map_geometry.gd:128-172`) décode **les trois** chaînes RLE et remplit **trois** ensembles à chaque appel, quel que soit `kind`, puis parcourt (L+2)(H+2) cases :
```gdscript
var floor_set := {} ; for cell in MapCodec.get_floor_cells(data): ... floor_set[cell] = true
var wall_set  := {} ; for cell in MapCodec.get_wall_cells(data):  ...
var low_set   := {} ; for cell in MapCodec.get_low_wall_cells(data): ...
for ix in width: ... for iy in height:  var cell := Vector2i(ix - BORDER, iy - BORDER); match kind: ...
```
Recompté, appelant par appelant, pour un duel iso par défaut (LED allumée, usure allumée) :

| # | Appelant | `build_grid` |
|---|---|---|
| 1-3 | `build_collisions` `map_geometry.gd:290,300,309` | 3 |
| 4 | `rects_monde` `game_state.gd:1497` → `map_geometry.gd:325` | 1 |
| 5-8 | `MurLed.poser` `mur_led.gd:166` + `build_solid_grid` `:167` (3) | 4 |
| 9-10 | `MurEncre.setup` `mur_encre.gd:92-93` → `:103` | 2 |
| 11-12 | `IsoGeometrie.build_meshes` → `rects_px` `iso_geometrie.gd:106` (2 sortes) | 2 |
| 13-14 | `accorder_grille(_mat_mur)` → `image_grille` `iso_materiaux.gd:440,442` | 2 |
| 15-16 | `image_proximite_usure` → `image_grille` `:467` | 2 |
| 17-20 | `accorder_grille` × 2 sols → `image_grille` | 4 |
| | **Total** | **20** (14 avec `--sans-usure`) |

Autour : `apply_to_layers` décode 4 fois (`map_data.gd:419,421,425,432`), `ArenaDecor._analyser_carte` 2 fois (`arena_decor.gd:227-228`), `AudioManager.accorder_a_la_carte` 1 fois **pour compter**
(`audio_manager.gd:1062`) : ≈ 67 décodages. **En aventure** s'ajoutent `NavigationBot.depuis_carte` (3, `aventure_partie.gd:176`) et **2 par PNJ qui voit ou entend**
(`bot_input_provider.gd:332` → `perception_bot_noeud.gd:77` → `perception_bot.gd:164,166`) : **salle 8.9 = 20 + 3 + 14 = 37 `build_grid` et 13 `merge_rects`**.
**Erreur de BOT-04** : « 4 `build_grid` côté arène » (`game_state.gd:1496-1497` seul) ; le total qu'il donne (21) est donc faux, et la part « navigation + perception » est 17/37 (46 %), pas 17/21.

**2. La fréquence.** § 2.1 : un seul départ à chaque fois ; donc les 20 (37) constructions se paient ensemble, pas en régime.

**3. Le coût.** PROUVÉ : les comptes. ESTIMÉ (modèle § 0) : ≈ 0,5-0,9 ms par `build_grid` en 32×32 (1 156 cases, 1 024 cellules décodées) — CAR donne 1,2-1,5 ms ; ≈ 4-5 ms en 100×80
(8 364 cases, 8 000 cellules) — CAR 9-12 ms, BOT 8 ms. Soit **10-18 ms par départ de duel**, **150-200 ms en 8.9** (×2 sur machine lente). Les 3 commentaires « une fois par carte »
(`presentation_3d.gd:2199`, `arena_decor.gd:22`, ROADMAP l.28721) sont vrais par construction d'arène, pas par carte : écart d'intention, pas défaut fonctionnel.

**4. Invariants.** Vérification d'aliasing demandée par CAR-03, **faite** : tous les consommateurs de `build_grid` / `rects_monde` lisent seulement — `merge_rects` (`:202-249`), `build_solid_grid` (copie dans `out`),
`MurLed.sol_de` (copie) et `texture_pour` (`hash`, `cuire` en lecture), `trace_contours` (`:418-452`), `image_grille`, `IsoGeometrie.rects_px`, `NavigationBot._solide`
(`navigation_bot.gd:84,99`), `PerceptionBot.mur_a` (`perception_bot.gd:175-184`), `MursBas.forme_de_lumiere` (nouveau tableau), `game_state.murs_bas` (lecture). Aucun test trouvé qui écrive dans le retour de `build_grid`
(`grep` de `tools/` : les `murs[c] = true` sont des Dictionary construits à la main). Le dictionnaire `monde` de la perception, lui, **doit rester copié par nœud** (`aveugle`, `obstacles`, `ebloui` sont réécrits à chaque pas,
`perception_bot_noeud.gd:226-242,171`) : copie **superficielle** suffit.
Deux pièges propres au cache :
- **clé exacte, pas `hash()`** : CAR-03 propose `hash([grid_size, floor, walls, low_walls])` (32 bits). Une collision rendrait à un pair la géométrie d'une autre carte **sans erreur** — la classe de défaut que le projet a déjà payée
  (« deux joueurs sur deux terrains différents », `game_state.gd:1848-1853,1888-1890`). Un `Dictionary` à clé `String` (concaténation des quatre champs bruts) compare l'égalité : exact. `data.hash()` sert déjà de clé d'empreinte de rencontre (`game_state.gd:1365`) ;
  l'y ajouter comme premier niveau est sans risque, mais la clé de géométrie reste le texte.
- **borner** : l'éditeur change de contenu à chaque geste ; un cache de 2 entrées (dernière carte jouée + courante), pas un cache qui grandit.
`make_read_only()` sur le tableau extérieur **et** sur chaque colonne (il ne descend pas) : tout écrivain futur échoue bruyamment dans `run_suites.sh` au lieu de corrompre une carte partagée.

**5. Statut.** NOUVEAU, et **hors OM6** : OM6 (« murs par contours ») touche la production des occulteurs (`build_collisions` / `_fill_body`, `map_geometry.gd:269-365`), pas `build_grid`. Voir § 5.

**6. Correctif minimal et preuve cloud.** Un seul geste d'une quinzaine de lignes, **en tête de `build_grid`** (`:128`) et de `build_solid_grid` (dérivée des trois grilles mémoïsées) : clé exacte,
2 entrées, colonnes en lecture seule. Il absorbe d'un coup CAR-03, la partie géométrie de GEO-03, **BOT-04 en entier** (la perception et la navigation appellent la même fonction) et ETA-04.1. Variante locale à BOT-04
si on refuse de toucher `map_geometry.gd` : un `monde_de_vue()` construit une fois par `NavigationBot` et copié superficiellement par nœud (`perception_bot_noeud.gd:77`) — en 8.9, les 14 constructions de perception deviennent 2.
Variante secondaire (BOT-04.b) : ne décoder que les ensembles lus par `kind` (`WALLS` ne lit que `wall_set`) : −⅔ du travail par appel, mais dans le fichier d'OM6 et inutile une fois le cache posé.
Preuve : compteur statique de constructions (`test_arena_build` : 2 manches → ≤ 3 puis +0) ; micro-banc headless `build_grid` ×100 sur `default` et sur `chapitre_08/niveau_09` avant/après ; suites `test_map_geometry`,
`test_arena_build`, `test_mur_led`, `test_iso_geometrie`, `test_bot_perception`, `test_aventure_partie`.

---

### V4-C — GEO-02 : `image_proximite_usure`, la plus grosse pièce du départ

**Verdict : CONFIRMÉ. Sévérité : MINEUR (à reclasser MAJEUR sur les 10 salles ≥ 3 Mpx si la mesure dépasse 0,5 s). Statut : NOUVEAU — écart d'intention : la ROADMAP l.28423 écrit « préparée une fois par carte », le code la refait à chaque construction des murs.**

**1. Le code.** Conforme (`iso_materiaux.gd:466-502`) :
```gdscript
var plein := Image.create_empty(cases.x + 2, cases.y + 2, false, Image.FORMAT_RGBA8) ; ... moitie ...
for x in cases.x: for y in cases.y: ... plein.set_pixel / moitie.set_pixel     # GDScript, 1 156 itérations (std)
plein.resize(grande.x, grande.y, Image.INTERPOLATE_NEAREST) ; moitie.resize(...)  # 2 resize RGBA8
var sortie := Image.create_empty(grande.x, grande.y, false, Image.FORMAT_RGBA8) ; sortie.fill(...)
for d in [Vector2i(14, 0), ...]: _decaler_sur(sortie, moitie, d, grande)           # 4 blend_rect plein cadre
for d in [Vector2i(5, 0), ...]:  _decaler_sur(sortie, plein, d, grande)            # 4 de plus
sortie = sortie.get_region(...) ; sortie.convert(Image.FORMAT_R8)
```
Appelé à chaque `_construire_les_murs` (`presentation_3d.gd:2200`) sous `_usure` (vrai par défaut). Seule référence au nom dans la ROADMAP : l.28424.

**2. La fréquence.** Un appel par départ (§ 2.1). Ne dépend que du contenu de la carte (`image_grille(data)` + constantes).

**3. Le coût.** PROUVÉ — pixels visités (script) : 7,7 à 12,7 Mpx pour les six cartes livrées (huit passes sur 0,96-1,59 Mpx ; 38-48 % de pixels à mélanger), **85,6 Mpx en 8.9**, plus `convert` (1 passe), 2 `resize`
(5,7 Mo chacun), 3 images RGBA8 + 1 région (≈ 25 Mo transitoires en duel, ≈ 165 Mo en 8.9). ESTIMÉ à 5-25 ns/pixel pour `blend_rect` (lecture/mélange/écriture par `Color`, hypothèse à vérifier) :
**0,05-0,3 s par départ de duel**, **0,4-2,3 s en 8.9** (10 salles ≥ 3 Mpx sur 100 ; médiane des salles 1,27 Mpx). Même ordre que GEO, que je suis. C'est **la majeure partie du départ de duel** (≈ 45-90 % selon la vitesse réelle de `blend_rect`,
≈ 75 % au centre de la fourchette) et du gel d'entrée de salle (≈ 45-85 % en 8.9).
La seule valeur chiffrée du dépôt sur ce levier est une cadence (+0,67 ms par image, ROADMAP l.28420) : la construction n'a jamais été chronométrée. La décision d'Adrien « les murs abîmés par défaut » (Q30 = A, ROADMAP l.2493)
a été prise sur la foi de « proximité préparée une fois par carte » : la prémisse tient pour le coût par image, pas pour le départ de manche.

**4. Invariants.** (a) Le correctif A de GEO (remplir en R8 des rectangles décalés par `fill_rect`) est **exact par construction** : l'union des copies décalées d'une union de rectangles est l'union des copies décalées de
chaque rectangle ; valeurs 0 / 128 / 255 écrites dans l'ordre « loin » puis « près » = le `max` actuel. La preuve existe : `test_iso_usure.gd:200-231` (36 000 points sur six cartes, rouge à 8 px). Piège : l'union est celle de
`maxf(r, g) > 0,5` (murs hauts **et** murets) plus l'anneau extérieur d'une case (`plein.fill(1)` hors de la grille) ; la fusion se fait donc sur la grille murs ∪ murets bordée, pas sur `Kind.WALLS` seul.
(b) Garde de texte : `test_iso_usure.gd:238` exige `IsoMateriaux.image_proximite_usure(data)` **dans `presentation_3d.gd`** — le correctif doit rester **dans** `image_proximite_usure`, sans changer ce texte.
(c) Aucun tirage aléatoire, aucun effet sur le bot, le réseau ou la lisibilité de la lumière. (d) OM6 ne cite ni `iso_materiaux.gd` ni cette fonction.

**5. Statut.** NOUVEAU.

**6. Correctif minimal et preuve cloud.** **A**, dans `image_proximite_usure` seule : construire directement en `FORMAT_R8` par `fill_rect` sur les rectangles fusionnés (`merge_rects` de la grille murs ∪ murets), 8 décalages par rectangle ;
S/M, ≈ 40 lignes, de l'ordre de 5-15 ms (30-60 ms en 8.9, ESTIMÉ). Il corrige aussi le premier départ et chaque **nouvelle** salle, ce qu'un cache B (mémo par contenu, S) ne fait pas ; B devient superflu. Option C de GEO
(un seul `image_grille` pour les trois matériaux) : ≈ 2-5 ms, à prendre au passage.
Preuve : micro-banc headless dans `test_iso_usure.gd` (CPU natif : valable sans fenêtre) :
```gdscript
var t := Time.get_ticks_usec(); var img := IsoMateriaux.image_proximite_usure(d); print((Time.get_ticks_usec() - t) / 1000.0)
```
sur les six cartes + `chapitre_08/niveau_09` ; **égalité octet à octet** `ancienne.get_data() == nouvelle.get_data()` sur les mêmes sept cartes (avant de supprimer l'ancienne) ; les 36 000 points existants. Le cloud (Xeon 2,8 GHz) sera 1,5-2× plus lent que le M3 : comparer avant/après sur la même machine.

---

### V4-D — CAR-05 + GEO-03 (décor) + ETA-04.3 : le décor re-cuit et relu au GPU

**Verdict : CONFIRMÉ. Sévérité : ANECDOTIQUE en duel, MINEUR sur les salles ≥ 3 Mpx. Statut : NOUVEAU — écart d'intention (`arena_decor.gd:22` « UNE texture par carte » ; ROADMAP l.22327, 28717, 33870).**

**1. Le code.** Conforme (`arena_decor.gd:169-215`) : `_ready` lance `_cuire()` pour tout original ; `await process_frame` ; `SubViewport` de `(grille+2)×35` px en `UPDATE_ALWAYS` ; `await RenderingServer.frame_post_draw` ;
`vue.get_texture().get_image()` ; `ImageTexture.create_from_image(img)`. `build()` (`:114-131`) crée une instance neuve à chaque appel ; aucune statique (contrairement à `MurLed._cache_texture`, `mur_led.gd:131-132`).
Tailles : 32×32 → 1 190² = 5,7 Mo ; 100×80 → 3 570×2 870 = 41 Mo (cible + `Image` + texture ≈ 120 Mo transitoires) ; 128×128 → 83 Mo.
```gdscript
# arena_decor.gd:169-171, 183-190, 202-210 (extraits) — rien n'est gardé d'une manche à l'autre
func _ready() -> void:
    if not _est_copie:
        _cuire()
...
await get_tree().process_frame
var vue := SubViewport.new()
vue.size = Vector2i(_cadre.size)                         # (grille + 2) × 35 px, aucun plafond
vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
...
await RenderingServer.frame_post_draw
var img: Image = vue.get_texture().get_image()           # relecture GPU → CPU
_cuit = ImageTexture.create_from_image(img)              # ré-envoi
```

**2. La fréquence.** Un par départ (§ 2.1) ; l'attente est de **deux images** (`process_frame` puis `frame_post_draw`), c'est-à-dire dans les images N+1/N+2.

**3. Le coût.** ESTIMÉ : 2-10 ms (duel) et 15-40 ms (8.9), dont l'essentiel est une **synchronisation GPU** (`glReadPixels`) plus la copie et le re-téléversement ; plus `_analyser_carte` (≈ 1 ms ; ≈ 5-10 ms en 8.9, 7 148 sols × 4 voisins × 2 recherches).
Tombe dans le décompte (duel) ou sous le carton (aventure) : **invisible**, mais **relevé** par `ConditionsDeMatch` (images N+1/N+2). Impact sur le 1 % bas : négligeable (quelques ms sur 2-3 images). Je ne peux pas confirmer le « 2-5 ms » de CAR : à mesurer sur le Mac, pas dans le cloud.

**4. Invariants.** (a) `build()` **duplique le nœud enfants compris** : la cuisson attend une image pour que les copies n'héritent pas d'un peintre sans décor (ROADMAP l.22327). Un cache pose `_cuit` **avant** `_duplicate_for_player`
(`:152-166` recopie déjà `copy._cuit = _cuit`) et saute `_cuire` quand `_cuit` est posé. (b) `PeintureIso` recopie `_cuit` dès qu'il diffère (`peinture_iso.gd:191-195`) et à `_ready` (`_copier` recopie les variables de script) : compatible.
(c) La clé doit contenir `pochoirs_actifs()` et, sous pochoirs, l'`id` de la carte (`POCHOIRS_ESSAI` est indexée par `id`, `arena_decor.gd:91`) ; `poser_pochoirs()` invalide. (d) Garde `test_arena_matter.gd:187-195` :
« en headless, pas de cuisson : texture nulle » (`decor._cuit == null`) — un cache vide en headless la respecte. (e) **Plafonner la cuisson** (GEO-03 « `COTE_MAX` ») : à ne pas faire sans Adrien — réduit la définition des chevrons sur les cartes de 116 cases et plus (jusqu'à 4 550 px contre 4 096) ; la peinture, elle, est déjà plafonnée.

**5. Statut.** NOUVEAU.

**6. Correctif minimal et preuve cloud.** Un cache statique à une entrée (clé exacte de contenu + pochoirs → `ImageTexture`), rempli en fin de `_cuire`, lu dans `build()` ; S/M, ≈ 25 lignes. À faire **après** V4-B/C : il ne rapporte
rien de visible en duel. Alternative rejetée : garder la `ViewportTexture` sans relecture (la texture d'un viewport libéré devient invalide ; `PeintureIso` et les copies la partageraient).
Preuve : compteur d'octets relus (`get_image` = 0 à la deuxième manche) et `Performance.RENDER_TEXTURE_MEM_USED` avant/après une revanche sous Xvfb + llvmpipe ; **la synchronisation GPU n'est pas reproductible sous llvmpipe** (logiciel, pas de file de commandes) : seuls les octets le sont.

---

### V4-E — CAR-06 + GEO-03 (tileset) + ETA-04.2 : l'atlas constant régénéré

**Verdict : CONFIRMÉ. Sévérité : ANECDOTIQUE. Statut : NOUVEAU.**

**1. Le code.** `candela_tileset.gd:69-98` : `Image.create_empty(70,70)`, `_generer_dalle_encre` × 2 (1 225 `set_pixel` + 289 pores avec `_hachage` + 1-2 fissures chacun), `_generer_mur_atelier` (1 225), `_generer_mur_bas` (1 225), `ImageTexture`, `TileSet` et
`TileSetAtlasSource` neufs. Déterministe (graines 101 et 203). Appelé à chaque `rebuild_arena` (`game_state.gd:1462`) et une fois par l'éditeur (`map_editor.gd:154`).
```gdscript
# candela_tileset.gd:69-98 (extraits) — le résultat est constant
static func create_tileset() -> TileSet:
    var ts := TileSet.new()
    var img := Image.create_empty(TILE_SIZE.x * 2, TILE_SIZE.y * 2, false, Image.FORMAT_RGBA8)
    _generer_dalle_encre(img, 0, SOL_DESSIN_A, 101)
    _generer_dalle_encre(img, TILE_SIZE.y, SOL_DESSIN_B, 203)
    _generer_mur_atelier(img, TILE_SIZE.x, 0)
    _generer_mur_bas(img, TILE_SIZE.x, TILE_SIZE.y)
    var tex := ImageTexture.create_from_image(img)
    ...
# :115-118 — 1 225 `set_pixel` par dalle, quatre dalles
for y in range(TILE_SIZE.y):
    for x in range(TILE_SIZE.x):
        img.set_pixel(x, oy + y, joint if bord else aplat)
```

**2. La fréquence.** Un par départ.

**3. Le coût.** PROUVÉ : ≈ 4 950 `set_pixel` + ≈ 640 `_hachage`. ESTIMÉ **≈ 1 ms** (0,1-0,2 µs par `set_pixel` d'après l'étalon de `fusee.gd`), pas 1,5-3 ms.

**4. Invariants.** Aucun utilisateur ne mute le `TileSet` rendu (`grep create_tileset` : `game_state.gd:1462`, `map_editor.gd:154`, et des tests qui lisent `get_source(0)` ; `apercu_matiere.gd:323-330` construit **son propre** `TileSet`). Les trois calques d'une manche le partagent déjà.
`test_arena_lighting.gd:65-68` ne lit que l'absence de `creer_materiau_mur` et de `walls_layer.material =`. Une `static var` de ressource existe déjà ailleurs (`MurLed._cache_texture`, `Fusee._cache_textures`).

**5. Statut.** NOUVEAU.

**6. Correctif minimal et preuve cloud.** `static var _tileset: TileSet` ; `create_tileset()` le rend s'il est valide (3 lignes). Preuve : micro-banc `create_tileset()` ×100 headless ; `test_arena_build`, `test_arena_lighting`, `test_arena_matter`, `test_editor_tools`.

---

### V4-F — BOT-01 : première ouverture de l'écran Aventure

**Verdict : CONFIRMÉ. Sévérité : MINEUR (le rapport disait MAJEUR). Statut : NOUVEAU (`chapitres_livres` n'apparaît nulle part dans la ROADMAP : grep).**

**1. Le code.** Conforme. Déclencheur : `hub.push(SCREEN_AVENTURE)` émet `screen_changed` **dans le gestionnaire du clic** (`menu_hub.gd:547`) → `ui._on_hub_screen_changed` (`ui.gd:5873`) → ligne 5924 `_rafraichir_l_aventure()` → `:5422` `AventureFormat.chapitres_livres()`.
Premier appel de la session (ni `ui._ready`, ni `_refresh_weapon_locks` n'y passent hors contexte aventure : `ui.gd:1374,5996`, `_contexte_aventure` faux ; `grep chapitres_livres *.gd` : seuls `ui.gd` et `aventure_format.gd`) : 10 × `charger_chapitre` (`aventure_format.gd:504`) → `valider_chapitre` → 100 × `valider_niveau`, dont :
```gdscript
# aventure_format.gd:219-221 — une NavigationBot COMPLÈTE par salle, jetée ensuite
var lue := _carte_normalisee(niveau, e)
if not lue.is_empty(): navigation = NavigationT.depuis_carte(lue)
# navigation_bot.gd:84-91
_solide = Geometrie.build_solid_grid(data)          # 3 build_grid
... boucle est_libre/_etranglee sur chaque case ...
_astar = _fabriquer_astar(Rect2i())                 # boucle est_praticable + _pres_d_un_mur (jusqu'à 8 est_libre) sur chaque case
```
La validation n'appelle jamais `chemin()` : `grep` de `_astar`, `.chemin(` hors `navigation_bot.gd` → rien dans `aventure_format.gd` (elle appelle `est_praticable`, `est_libre`, `cases_atteignables`, `taille`).

**2. La fréquence.** Une fois par processus (`_cache` statique `aventure_format.gd:123,491`), au premier clic sur « Aventure » depuis Solo. La transition du hub (un `Tween` créé juste avant l'émission, `menu_hub.gd:_slide`) est ensuite consommée d'un coup par le `delta` de ≈ 1 s de l'image suivante : le joueur voit un clic, un blocage, puis l'écran déjà ouvert.

**3. Le coût — recompté (script).** 100 salles ; **123 951 cases de grille** (Σ(L+2)(H+2) ✓) ; 87 656 sols, 23 135 murs, 789 murets ; 12 065 runs RLE ; 86 867 cases praticables ; **300 `build_grid` (3 par salle) = 334 740 cellules décodées et insérées + 371 853 itérations de double boucle** ;
**876 774 appels `est_libre` : 295 424 dans `_construire` (3,4 par case praticable) et 581 350 dans `_fabriquer_astar` (6,7 par case praticable) — 66 % dans l'A* que la validation ne lit pas** ; 32 salles ont une ronde (numérotation des composantes avec tri, ≈ 0,1-0,2 s en tout).
Modèle : `_construire` 133 ms + A* 285 ms + `build_solid_grid` 188 ms + `check_playable` 18 ms = **0,62 s** (calibré M3) à 1,37 s (×2,2), plus les composantes : **≈ 0,7-1,6 s**. Dans la fourchette basse de l'auteur (0,6-2,5 s) ; je ne retiens pas 2,5 s.
Répartition : A* ≈ 45 % (l'auteur : 33 %), `build_solid_grid` ≈ 30 %, boucle `_construire` ≈ 21 %.
Sévérité : un gel de 0,7 à 1,6 s, **unique**, dans un menu, hors partie — le plus long gel *certain* du périmètre, mais il n'atteint ni un duel ni l'action : MINEUR. À reclasser MAJEUR si le script de BOT-01 (« Comment le vérifier ») le mesure > 2 s sur le Mac.

**4. Invariants.** (a) L'A* paresseux ne change aucune sortie ; `NavigationBot` est lu par `test_bot_navigation`, `test_bot_equipement`, `test_chapitre_*` via `chemin()` (qui le fabrique au premier appel). (b) Option 2 (charger par chapitre) change le contrat de `chapitres_livres()` :
six appels dans `ui.gd` (`5422,5494,5513,5533,5563,5583`) et `test_aventure_format.gd:608-634` (qui compte les chapitres livrés et leurs « cris »). (c) `MapCodec.validate` tire `randi()` global pour chaque carte sans `id` (`map_codec.gd:187-188` ; les 100 cartes n'en ont pas) :
déplacer ou retarder la validation déplace ≈ 100 tirages du flux global — sans effet sur les bancs (ils le reseedent par image), et **jamais dans un fil**. (d) Option 4 (ne pas valider à l'exécution d'un export) : décision d'Adrien ; contre : « Une salle mal écrite doit se VOIR » (`aventure_format.gd:10-16`).

**5. Statut.** NOUVEAU.

**6. Correctif minimal et preuve cloud.** **Option 1, A* paresseux** : `_construire` ne construit plus `_astar` ; `chemin()` le fabrique au premier appel (≈ 10 lignes) → **−45 %** (≈ −0,3 à −0,7 s) et déplace ≈ 26 ms (8.9) vers le premier pas du bot, sous le carton. Puis, si l'on veut que le clic ne fige plus, **option 3** (une salle par image,
`await get_tree().process_frame`, dès l'écran Solo) : masque le gel entier. Preuve : script de BOT-01 en headless (`godot --headless --path . --script …`) ; **compteurs indépendants du matériel** : `_fabriquer_astar` appelé 100 → 0 fois, `est_libre` 877 k → 295 k ; l'égalité `JSON.stringify(chapitres_livres())` avant/après ;
`test_aventure_format`, `test_chapitre_00…09`, `test_aventure_partie`.

---

### V4-G — BOT-09 : le carton est montré après la construction

**Verdict : CONFIRMÉ. Sévérité : MINEUR. Statut : NOUVEAU (écart d'intention : `aventure_carton.gd:6-7` « pendant que la salle suivante se construit derrière lui »).**

**1. Le code.** Conforme (`aventure_partie.gd:154-172`) : `_retirer_les_pnj` → `jeu.aventure_poser_la_salle` (arène) → `Plafonnier.poser` → `_creer_les_pnj` → HUD → **`_carton.montrer(...)` en dernier** → `jeu.countdown_left = DUREE_CARTON`.
Appelée depuis `demarrer` (`:131`, clic), `_salle_suivante` (`:333`) et `recommencer_la_salle` (`:320`) — ces deux-là dans `_physics_process`. `Presentation3D._process` (GEO-02 et le reste des murs) suit **dans la même image** (§ 2.2).
Le carton est opaque dès `montrer` (`regler(1.0)`, `visible = true`, `aventure_carton.gd:72-78`) : placé un pas plus tôt, il recouvrirait bien le gel.
```gdscript
# aventure_partie.gd:154-172 (extraits)
func _poser_la_salle() -> bool:
    var n := niveau()
    _retirer_les_pnj()
    ...
    if not bool(jeu.aventure_poser_la_salle(n, _index_de_classe(classe_slug), etiquette)):   # → _do_start_round → rebuild_arena
        return false
    Plafonnier.poser(jeu.arena, n["plafonniers"])
    _creer_les_pnj(n)                                  # NavigationBot + N × (Player, bot, monde de perception)
    jeu.figurants = pnj
    _hud.entrer_dans_la_salle(int(chapitre["numero"]), index + 1, pnj.size(), jeu.p1)
    phase = Phase.CARTON
    _t = 0.0
    ...
    _carton.montrer("CHAPITRE %d  ·  SALLE %d / %d%s" % [...], String(n["titre"]), String(n["intention"]))   # EN DERNIER
    jeu.countdown_left = DUREE_CARTON
    return true
```

**2. La fréquence.** À chaque entrée, chaque salle suivante, chaque réessai.

**3. Le coût.** Durée du gel = S0 + nav + PNJ + S (Presentation3D). Salle médiane (1,27 Mpx, 2-3 PNJ) : ≈ 0,1-0,35 s ; salles 8.x (≥ 3 Mpx) : ≈ 0,4-1,5 s ; 8.9 : ≈ 0,75-2,8 s (GEO-02 en fait ≈ 45-85 %). BOT-09 ne chiffrait pas la partie Presentation3D (« quelques dizaines à plusieurs centaines de ms »).
Ce que voit le joueur : l'image figée de sa mort (déjà immobile depuis 1,8 s) ou le menu, puis le carton. Le rattrapage de Godot (jusqu'à 8 pas de physique dans l'image suivante) raccourcit le carton de ≤ 0,13 s : « sans effet » est inexact mais négligeable.
Adrien a déjà jugé un défaut équivalent sur le carton de fin (ROADMAP l.3816 : « je vois subrepticement le menu avant l'affichage du carton ») : un recouvrement se juge à ce que l'œil voit, image par image.

**4. Invariants.** (a) `test_aventure_partie` suppose une salle prête et le carton visible au retour de `demarrer()` / `recommencer_la_salle()` (`test_aventure_partie.gd:239-244,639-683`) : garder ces appels publics synchrones, ajouter le report seulement dans le chemin
de `_physics_process`. (b) `countdown_left` doit rester positif entre le carton et la construction (il fige joueur et PNJ). (c) Pas de tirage : `_rng.randi()` de `_creer_les_pnj` (un par PNJ, dans l'ordre) inchangé. (d) Le temps du carton (`_t`, 2,4 s) se décale d'un pas : aucun banc de difficulté ne passe par l'aventure.
(e) Un seul pas de physique ne garantit pas une image rendue entre les deux (deux pas dans une même image si elle dure > 33 ms) : attendre `get_tree().process_frame` puis `RenderingServer.frame_post_draw` est plus sûr que « le `_physics_process` suivant ».

**5. Statut.** NOUVEAU.

**6. Correctif minimal et preuve cloud.** Dans `_salle_suivante` et `recommencer_la_salle` : montrer le carton du niveau à venir (titre déjà connu dans `chapitre["niveaux"]`), poser `countdown_left`, passer en phase `CONSTRUCTION`, construire après une image rendue (S). Il masque, il ne raccourcit rien : **le gain réel vient de GEO-02**, qui ramène le gel de 8.9 sous 0,3 s.
Preuve : une garde dans `test_aventure_partie` qui relève, à l'entrée de la construction, `_carton.visible`, `_fond.modulate.a == 1` et qu'au moins une image s'est écoulée depuis `montrer` ; la méthode d'Adrien/ROADMAP l.3816 (juger image par image, `--fixed-fps 60` sous Xvfb) ; chronomètre autour de `_poser_la_salle`.

---

### V4-H — BOT-03 : `case_de_repli` balaie toute la composante

**Verdict : CONFIRMÉ. Sévérité : ANECDOTIQUE (MINEUR en salles 8.x). Statut : NOUVEAU.**

**1. Le code.** Conforme (`equipement_bot.gd:135-146`) : `for c in navigation.cases_atteignables(ici)` avec `Navigation.centre_de_la_case(c)` (appel statique + trois `Vector2`), puis `if d < fenetre.x or d > fenetre.y: continue` ; la fenêtre est de 105-260 px (latéral) ou 175-350 px (recul), soit ≤ 11 cases de rayon (≤ 529 cases) contre la composante entière.
```gdscript
# equipement_bot.gd:135-146 (annoté)
for c in navigation.cases_atteignables(ici):          # toute la composante : jusqu'à 7 148 cases en 8.9
    var centre := Navigation.centre_de_la_case(c)
    var vers := centre - position
    var d := vers.length()
    if d < fenetre.x or d > fenetre.y:                # la quasi-totalité est rejetée ici
        continue
    if absf(axe.angle_to(vers)) < angle_min:
        continue
    if Percep.segment_degage(menace, centre, monde):  # un parcours de grille par candidate restante
        ouvertes.append(c)
    else:
        cachees.append(c)
```

**2. La fréquence.** Appelé par `_planifier_un_repli` (`bot_input_provider.gd:1019-1037`) : (a) fin de rafale (`:903-907`) pour les profils à `repli_apres_tir_s > 0` — **NORMAL (0,6 s) et DIFFICILE (0,3 s) équipés seulement** (`profil_bot.gd:453,458`) et les boss dont le réglage le donne (`REGLAGES_BOSS`, `:690-702` : 3 s pour certains, 0 pour la pompe) —, (b) après une mine (RECUL, `:1011` ; la suie, `:1014`, passe par `case_praticable_proche`, pas par `case_de_repli`), (c) peur (RECUL, `:719`). Par PNJ engagé : ≈ un par rafale (0,5-1,5 par seconde). Pas à chaque pas.

**3. Le coût.** PROUVÉ : O(composante) par repli. Taille des salles (script) : cases praticables **médiane 596**, 21 salles > 1 000, 7 salles > 2 000, **un seul maximum à 7 148** (8.9). ESTIMÉ ≈ 0,45 µs par case rejetée → **≈ 0,3 ms (médiane), ≈ 1 ms (1 000-2 000), ≈ 3,2 ms (8.9)** par repli,
soit la moitié de l'auteur (1 ms pour 1 200 cases, 5 ms pour 7 000). Un pic ponctuel, d'un à trois replis par seconde en combat : ANECDOTIQUE sauf 8.8/8.9 où il s'ajoute à des images déjà chargées (8.9 : cinq PNJ équipés, `repli` après rafale).
Le premier appel de la visite paie aussi la numérotation des composantes (BOT-06, hors mission : 22-45 ms en 8.9) — c'est lui, pas la boucle, le vrai pic.

**4. Invariants.** Exact seulement si **(i) l'ordre y-puis-x** de `cases_atteignables` est conservé (les listes `cachees` / `ouvertes` sont des sous-suites de cet ordre ; `rng.randi_range(0, g.size() - 1)` en dépend), **(ii)** la fenêtre couvre `ceil(fenetre.y / 35) + 1` cases, **(iii)** l'appartenance à la composante de `ici` est conservée
(`_composante_de`, remplie au premier `cases_atteignables`) et la liste vide si `ici` n'est pas praticable. **Aucune empreinte md5 ne couvre ce chemin** (`flux_commandes_bot.gd:205-222` éteint `repli_apres_tir_s`) : il faut relever d'abord des empreintes de profils équipés sur `52a29c1`
(§ 5 du rapport BOT : l'option `-- --empreintes` de `test_bot_equipement.gd`). Gardes de texte : `test_bot_equipement` interdit toute lecture de l'adversaire dans `equipement_bot.gd` (une fenêtre autour de `ici` n'en lit aucune).

**5. Statut.** NOUVEAU.

**6. Correctif minimal et preuve cloud.** Parcourir la fenêtre carrée autour de `ici` dans le même ordre (y puis x) en filtrant par `_composante_de` (≈ 12 lignes, `equipement_bot.gd` + un accesseur `NavigationBot.meme_composante`). À ne faire qu'**après** les empreintes. Preuve : micro-banc headless de `Equip.case_de_repli` dans `c08/n09` et dans une salle de ~600 cases ; **égalité** du retour **et de `rng.state`** avant/après sur 1 000 appels à graine fixe ; `test_bot_equipement`, `test_aventure_boss`.

---

### V4-I — BOT-05 : fonctions pures recalculées

**Verdict : CONFIRMÉ AVEC RÉSERVE (latent). Sévérité : ANECDOTIQUE. Statut : NOUVEAU.**

**1. Le code.** Conforme. (a) `_suivre_la_memoire` appelle à **chaque pas** en ENQUÊTE/RECHERCHE `navigation.case_praticable_proche(Navigation.case_du_monde(perception.memoire.position))` (`bot_input_provider.gd:855-856`, appelée par `avancer` `:389-390`) ;
`case_praticable_proche` rend `case` aussitôt si elle est praticable (`navigation_bot.gd:228-229`), sinon balaie des anneaux avec `(2r+1)²` itérations dont seules `8r` servent (`:231-244`). (b) `cases_dans(rect)` parcourt `_cases` entier (`:119-124`) à chaque `prochaine_cible` de ZONE (`:491`).
(c) `_decider` n'a pas de temporisation après échec : 2 tours × 8 essais = 16 `prochaine_cible` par pas si aucun chemin (`:396-398,434-447`).
```gdscript
# bot_input_provider.gd:855-856 — à CHAQUE pas en ENQUÊTE / RECHERCHE
var maintenant := perception.maintenant()
var but := navigation.case_praticable_proche(Navigation.case_du_monde(perception.memoire.position))
# navigation_bot.gd:231-241 — (2r+1)² itérations par anneau, dont 8r servent
for r in range(1, rayon_max + 1):
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if maxi(absi(dx), absi(dy)) != r:
                continue
            var c := case + Vector2i(dx, dy)
            if est_praticable(c) and Vector2(dx, dy).length() < meilleure_d: ...
# perception_bot.gd:552-555 — la mémoire d'un son : un centre décalé jusqu'à 0,8 × le rayon de la zone
var rayon := maxf(distance * sin(deg_to_rad(largeur * 0.5)) / maxf(precision, 0.05), RAYON_ZONE_MIN)
var ecart := rayon * DECENTRAGE * lerpf(DECENTRAGE_MIN, 1.0, sqrt(rng.randf()))
var centre := source + Vector2.from_angle(rng.randf() * TAU) * ecart
```

**2. La fréquence.** (a) seulement quand la mémoire est une trace **hors du sol praticable**. La mémoire d'un SON est le centre d'une zone décalé jusqu'à `0,8 × rayon` (`perception_bot.gd:552-555` ; `rayon = distance × sin(largeur/2) / précision`) : un tir (largeur 10-20°) donne 2-4 cases d'écart ; un pas lointain
(largeur large) jusqu'à 14-27 cases. La trace dure 6-12 s (`delai_oubli`). Une trace de vue est sur du sol : O(1). (b)(c) : une fois par jambe de patrouille de ZONE (81 PNJ sur 255) ; (c) seulement dans l'état d'échec.

**3. Le coût.** PROUVÉ : le code. ESTIMÉ (≈ 70 ns par itération d'anneau, 4 appels natifs) : Σ(2r+1)² donne 164 itérations pour r = 4 (≈ 11 µs), 968 pour r = 8 (≈ 70 µs), 4 494 pour r = 14 (≈ **0,3 ms**), 16 214 pour r = 22 (≈ **1,1 ms**) — l'auteur annonce 1,6 ms et 5 ms, **3 à 5 fois trop haut**.
`cases_dans` : ≈ 60 ns par case → 0,4 ms (7 000 cases), 0,04 ms (médiane) ; l'auteur : 2 ms. L'état d'échec permanent est **latent** (rien dans les 100 salles ne l'établit ; l'auteur le dit) : le coût d'un échec est surtout celui des 16 A* natifs, pas de `cases_dans`.

**4. Invariants.** (a)(b)(c) exacts, sans tirage : (a) mémoïser `but` tant que `memoire.position` ne change pas ; (b) itérer les seules cases de l'anneau **dans le même ordre** (dy croissant, dx croissant) — l'égalité `<` stricte de `meilleure_d` départage alors comme avant ; (c) mémoïser `cases_dans(rect)` par `Rect2i` (`_tirer` ne modifie pas le tableau, `:499-508`)
ou, mieux, itérer les cellules du rectangle en ordre de lecture et tester `est_praticable` (même ordre que le filtre de `_cases`, coût O(zone)). (d) **temporiser `_decider` change les tirages de `_rng` : à refuser sans recalibrage**. Garde de texte : `avancer()` et `_decider()` ne doivent pas contenir « perception » (`test_bot_perception.gd:1085-1091`) — (a) vit dans `_suivre_la_memoire`, qui en a le droit.

**5. Statut.** NOUVEAU.

**6. Correctif minimal et preuve cloud.** (a) seul : 3 lignes, exact. Le reste n'a pas de gain à mesurer tant que le banc solo d'OM6 n'a pas dit que le bot pèse. Preuve : micro-banc avec une trace de son placée hors carte (`position = Vector2(-2000, -2000)`) ; `test_bot_navigation` (même graine, mêmes 60 cibles), `test_chapitres_marche*`, `test_bot_perception`.

---

### V4-J — BOT-02 : `_voir` complet pour des PNJ qui ne peuvent rien voir

**Verdict : CONFIRMÉ AVEC RÉSERVE. Sévérité : ANECDOTIQUE (MINEUR en 8.8/8.9). Statut : CONNU-OUVERT pour le coût (ROADMAP l.31850…33729) ; NOUVEAU pour la proposition.**

**1. Le code.** Conforme. `PerceptionBotNoeud._physics_process` appelle `_voir` à chaque pas si `profil.voit` (`:153-154`) : `cadre_de_vue`, `_lire_les_gadgets`, `_adversaire`, `_lumieres` (cône, halos, éclairs, `get_nodes_in_group("fusees")`, **`_plafonniers()` : un `get_node_or_null("Halo")` et une lumière par plafonnier**), puis `voir()`.
**La prémisse d'exactitude est vraie** : `voir()` (`perception_bot.gd:448-490`) ne remplit `par` que par une LAMPE **dans le cadre** (`dans_le_cadre(o, cadre)`) ou par `corps_atteint = corps_dans_le_cadre and ligne_de_vue(...)` ; hors cadre, `corps_atteint` est faux au premier terme et `voir()` rend `{"vu": false, "dans_le_cadre": false, "par": [], "position": ZERO}`.
`voir()` lui-même est donc **bon marché hors cadre** : le coût inutile est la construction de la liste de lumières et des quatre balayages de groupes, pas le parcours de grille.
```gdscript
# perception_bot_noeud.gd:167-181 (extrait) — avant de savoir si la cible est dans le cadre
_cadre = Percep.cadre_de_vue(bot["position"], bot["visee"], reglages)
_lire_les_gadgets()                         # get_nodes_in_group("gadgets")
...
var adversaire := _adversaire()             # get_nodes_in_group("players")
var lumieres := _lumieres(adversaire)       # ≈ 9 + P conteneurs ; "fusees" et "plafonniers" relus
...
derniere_vue = Percep.voir(bot, cible, lumieres, monde, reglages)
# perception_bot.gd:458-474 (extraits) — hors cadre, aucune des deux branches ne produit de `par`
var corps_dans_le_cadre := dans_le_cadre(pos, cadre, RAYON_CORPS)
var corps_atteint := corps_dans_le_cadre and ligne_de_vue(oeil, pos, h_oeil, h_c, monde)
for l in lumieres:
    if genre == Genre.LAMPE:
        if dans_le_cadre(o, cadre) and ligne_de_vue(oeil, o, h_oeil, float(l["hauteur"]), monde): ...
    elif corps_atteint and eclaire(l, pos, h_c, monde): ...
```

**2. La fréquence.** À chaque pas de physique, par PNJ qui voit (215 des 255 PNJ livrés). Le cadre (1 009 × 720 px tourné) couvre ≈ 7 % d'une carte 100×80 mais toute une salle de 20×20 : la sortie anticipée ne sert que les grandes salles.

**3. Le coût.** Modèle : ≈ 15 µs fixes + 3 µs par plafonnier, par PNJ qui voit et par pas (cône, 2-3 disques, groupes, `cadre_de_vue` ×2). Sur les 100 salles (script) : **42 µs par pas à la médiane, 120 µs au 90ᵉ centile, 273 µs en 8.9** (7 PNJ, 8 plafonniers) — soit 0,25 % à 1,6 % d'une image de 16,7 ms ;
avec les constantes plus hautes de l'auteur (25-60 µs/PNJ) jusqu'à ≈ 0,5 ms en 8.9. Gain de la sortie anticipée : ≈ 60-70 % de cela (estimation de l'auteur : la cible est hors cadre la plupart du temps) dans les cinq grandes salles, ≈ 0 ailleurs : **≤ 0,1-0,2 ms par pas, dans cinq salles sur cent**.

**4. Invariants.** Exact si (i) `_decalage_lisse = Regard.lisser(...)` est toujours exécuté (état à chaque pas), (ii) la sortie anticipée relit la lampe de l'adversaire avec **les mêmes gardes que `_lampe_brule`** (`get()` rend `null` sur une propriété absente, `bool(null)` lève : ROADMAP l.3344-3347), (iii) la même marge `RAYON_CORPS` que `voir()`.
`noms_des_lumieres` est lu par `test_plafonniers.gd:689-736`, `test_bot_perception.gd:911,1039`, `test_bot_combat.gd:1430`, `banc_perception_bot.gd:407` : une sortie anticipée qui ne le met pas à jour fait rougir ces suites. Doublon logique (la règle « dans le cadre » existerait à deux endroits) : le piège de dérive que le projet connaît.
Le cliché partagé par pas (BOT-02.2) doit garder `gadgets` et `fusees` par PNJ (un PNJ qui lance une fusée pendant son pas est vu par les suivants). **La perception ne doit être ni ralentie ni fusionnée dans `_penser`** (matrice 80/55/30).

**5. Statut.** CONNU-OUVERT (coût non mesuré, ROADMAP l.33729) / NOUVEAU (proposition). Le banc de cadence solo qui le mesurerait est inscrit à OM6 : s'y associer.

**6. Correctif minimal et preuve cloud.** Ne rien faire avant la mesure de la question Q1 de BOT : `TIME_PHYSICS_PROCESS` moyenné sur 600 pas headless (`--fixed-fps 60`) en 8.9 avec 0, 3, 7 PNJ. Si > 1 ms de différence : la seule pièce sûre et bon marché est de **construire une fois par pas, partagée, la liste des disques de plafonniers**
(l'état d'un plafonnier ne change qu'à son propre `_physics_process`), pas la sortie anticipée. Preuve : `banc_bot_difficulte --duels=4 --trace --brut=avant.json` puis `apres.json`, diff des traces ; `test_bot_perception`, `test_plafonniers`, `test_bot_combat`, `test_aventure_partie`.

---

## 4. Déterminisme des bancs : ce que chaque correctif change

| Correctif | Tirages aléatoires | Ordre de parcours / de listes | Verdict |
|---|---|---|---|
| Mémo `build_grid` / `rects_monde` (V4-B) | aucun | valeurs et ordre identiques (`merge_rects` balaie dans un ordre fixe) | neutre |
| `image_proximite_usure` en `fill_rect` (V4-C), cache de décor, tileset | aucun | sans objet (rendu) | neutre |
| A* paresseux (BOT-01.1) | aucun | identique | neutre |
| Validation par chapitre / en fond (BOT-01.2-3) | déplace ≈ 100 tirages du `randi()` **global** (`generate_id`) | — | sans effet sur les bancs (reseed par image) ; **jamais dans un fil** |
| Carton un pas plus tôt (BOT-09) | aucun (`_rng.randi()` de `_creer_les_pnj` : même nombre, même ordre) | décale le temps du carton d'un pas | neutre pour le bot ; suites d'aventure à garder synchrones |
| Fenêtre de repli (BOT-03) | **la taille de `cachees` / `ouvertes` pilote `randi_range(0, g.size() - 1)`** : exact seulement si l'ordre y-puis-x et l'appartenance à la composante sont conservés | **à préserver** | exact sous conditions ; **aucune empreinte** → les relever d'abord |
| Mémo de `but`, anneau seul, `cases_dans` (BOT-05 a-c) | aucun | anneau : même ordre dy puis dx | exact |
| Temporiser `_decider` (BOT-05 d) | **change les tirages de `_rng` dans l'état d'échec** | — | **à refuser** sans recalibrage |
| Sortie anticipée de `_voir` (BOT-02.1) | aucun | ordre des lumières inchangé (la première lumière vue donne `res["position"]`) | exact sous conditions |

Équité en ligne : aucun de ces correctifs ne touche au fil, aux RPC, aux nœuds nommés ni à la lumière ; la géométrie de collision / d'occlusion reste produite par les mêmes rectangles (le mémo ne change pas une valeur).

---

## 5. Coordination avec le chantier OMBRES (`candela-2d-godot-d4`, branche `claude/determined-pasteur-mtrws1`)

- **Aucun constat de cette mission n'est « DÉJÀ PRIS EN CHARGE »** : OM6 = capteurs `UPDATE_WHEN_VISIBLE`, halos sans récepteur, `hit_light`, occulteurs de murs par contours, banc de cadence solo. Rien du départ de manche.
- **`map_geometry.gd`** : OM6 touche la production des occulteurs (`build_collisions` / `_fill_body`, `:269-365`) ; le mémo de V4-B tient dans l'en-tête de `build_grid` (`:128-135`) et `build_solid_grid` (`:176-190`) — **hunks distincts, mais même fichier**. Selon `CLAUDE.md`, ne **jamais** fusionner dans leur branche : leur dire, par message (`SendMessage`),
  qu'une mémoïsation de `build_grid` / `rects_monde` est proposée et qu'elle est orthogonale. **Synergie à leur offrir** : `MurEncre` appelle déjà `trace_contours(build_grid(...))` deux fois par départ (`mur_encre.gd:103-106`) ; si OM6 branche les occulteurs sur les contours, un `trace_contours` mémoïsé par contenu servira les deux.
- **`iso_materiaux.gd`** : aucun lot d'OMBRES ne le cite ; OM3 (pâte D, Q83) pourrait en toucher le miroir CPU des shaders (`:533+`), loin de `image_proximite_usure` (`:466-509`).
- **`presentation_3d.gd`** : OM6 y touche les capteurs (`:809-810`, `:1199`) ; V4-C ne modifie que `iso_materiaux.gd` (le texte de `presentation_3d.gd` doit même rester intact, garde `test_iso_usure.gd:238`). Le seul changement possible dans `presentation_3d.gd` est le partage d'un `image_grille` entre les trois matériaux (option C), `:2196-2203`.
- **Le banc de cadence solo (OM6)** est le véhicule de mesure de BOT-02/03/05 : s'y associer plutôt que le refaire.

---

## 6. Ordre de travail recommandé

1. **GEO-02** (iso_materiaux.gd, S/M, hors OM6) — la majeure partie du départ (≈ 45-90 %) ; exact par construction ; preuve existante.
2. **BOT-01.1 A* paresseux** (S) — −45 % du seul gel certain du solo.
3. **Mémo exact de `build_grid`** (S, une quinzaine de lignes ; message à `candela-2d-godot-d4` d'abord) — absorbe CAR-03, BOT-04, GEO-03.
4. **`create_tileset` statique** (3 lignes).
5. **BOT-09** (S) — une fois GEO-02 posé, le gel d'entrée de salle tombe sous ≈ 0,3 s ; le carton plus tôt devient de l'hygiène.
6. **Cache du décor** (S/M), **BOT-03** (après empreintes), **BOT-05 (a)** : à la demande de la mesure.
7. **BOT-02** : seulement si le banc solo le réclame.

Ce qui est déjà bien fait et à ne pas casser : la LED est déjà mise en cache par contenu (`mur_led.gd:128-132`), précédent à suivre ; `ArenaDecor` et `MurEncre` partagent leurs tableaux avec leurs copies (`:158-163`, `:120-121`) au lieu de les recalculer ;
`_empreinte_de_la_rencontre` clé déjà sur le contenu (`game_state.gd:1354-1365`) ; une seule `NavigationBot` par salle pour tous les PNJ (`aventure_partie.gd:176`) ; la grille d'A* de zone est mise en cache par rectangle (`navigation_bot.gd:166-171`).

---

## 7. Vu en chemin, hors liste (à vérifier, non prouvé)

1. **Un départ de manche en ligne pourrait donner à l'hôte une avance égale à S0 + S + latence.** Le décompte de chaque pair part de **l'image qui a traité l'ordre** (le `delta` de l'image suivante contient S0 + S), et l'hôte ne vide son paquet qu'au `poll` de l'image d'après, **si** le transport ne le part qu'au `poll`
   (ENet : oui probablement ; EOS : inconnu). Dans ce cas l'invité part plus tard que l'hôte de ≈ S0 + S + latence, soit 0,1-0,4 s de plus que la seule latence (ESTIMÉ avec S0 + S de ce rapport). GEO-02 + le mémo ramèneraient l'écart vers la latence. **Non prouvé** (ordre « mise en file puis exécution locale » d'un RPC `call_local` et moment du vidage non lus dans le moteur) ;
   à vérifier avec deux instances ENet en boucle locale et des horodatages (`tools/test_online_match.tscn`). Le départ anticipé du classé (`rpc_countdown_launch`) est un autre chemin : non examiné.
2. **`NavigationBot` est une fonction pure de la carte** : on pourrait la garder d'un essai à l'autre (≈ 37 ms + numérotation sur 8.9 par réessai) ; gain secondaire, après le mémo.
3. **BOT-03 et BOT-06 se cumulent** : le premier repli d'une visite de salle paie la numérotation des composantes (tri GDScript) en plein combat ; BOT-06 (hors mission) est le vrai pic, pas la boucle.
4. **`ArenaDecor._analyser_carte`** (`:218-316`) refait à chaque départ ≈ 4 voisins × 2 recherches par case de sol : ≈ 1 ms (duel), 5-10 ms (8.9) ; cachable avec le décor, non listé par les auditeurs.

---

## 8. Mesures à demander à l'agent de cadence (une ligne chacune)

1. `Time.get_ticks_usec()` autour de `IsoMateriaux.image_proximite_usure(d)` sur les six cartes + `c08/n09` (headless) — décide GEO-02 (MINEUR / MAJEUR).
2. Le script de BOT-01 (`chapitres_livres()`), avant et après l'A* paresseux.
3. `build_grid` ×100 sur `default` et `c08/n09` (headless) — départage 0,5-0,9 ms (mon modèle) de 1,2-1,5 ms (CAR).
4. `_poser_la_salle` + `Presentation3D._process` chronométrés en 8.9 (durée du gel de BOT-09).
5. `Performance.TIME_PHYSICS_PROCESS` moyen sur 600 pas avec 0 / 3 / 7 PNJ en 8.9 — BOT-02 (question Q1).
6. Premier `ConditionsDeMatch.resume()["pire_image_ms"]` d'un match local sous Xvfb : doit égaler S de GEO-02 avant correctif.

---

## Annexe — Recompte (extrait de `audit/v4/recompte_V4.sortie.txt`)

```
BOT-01 : salles 100 ; cases de grille (L+2)(H+2) 123,951 ; sol/mur/mur bas 87,656 / 23,135 / 789 ; runs RLE 12,065 ; praticables 86,867
est_libre : _construire 295,424 + _fabriquer_astar 581,350 = 876,774 (66 % dans l'A*)
build_grid de validation : 300 ; cellules décodées+insérées 334,740 ; salles avec ronde 32
modèle : rapide 624 ms / lent 1 373 ms (hors composantes)
BOT-03 : praticables par salle : médiane 596 ; > 1000 : 21 ; > 2000 : 7 ; max 7148
BOT-02 : µs par pas : médiane 42, p90 120, max 273
GEO-02 : default 1,59 Mpx (8 passes : 12,7), cloître 1,42, usine 1,32, croisée 1,25, bunker 1,10, circulaire 0,96 ; solo 8.9 10,70 Mpx (85,6) ;
         100 salles : médiane 1,27 Mpx, 10 salles ≥ 3 Mpx
CAR-03 : duel 20 build_grid (14 avec --sans-usure) ; salle 8.9 : 20 + 3 + 2×7 = 37
```
