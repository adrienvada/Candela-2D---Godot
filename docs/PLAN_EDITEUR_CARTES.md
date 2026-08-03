# Plan d'implémentation — Éditeur de cartes niveau pro

> Cible : **Godot 4.7** (`TileMapLayer`, `Parallax2D`, typed arrays, `@export_tool_button`).
> Aucune syntaxe Godot 3 (`yield`, `KinematicBody2D`, `TileMap.set_cellv`, `export var`, `onready var`) n'est admise.

---

## 0. État des lieux

| # | Problème | Fichier | Gravité |
|---|----------|---------|---------|
| 1 | Murs custom sans `LightOccluder2D` → la torche traverse les murs | `map_data.gd:138` | 🔴 bloquant |
| 2 | `TileMapLayer` absent de `_find_visuals()` → tuiles invisibles en split-screen | `game_state.gd:286` | 🔴 bloquant |
| 3 | Sauvegarde forcée sur le slot `"custom"` → écrase la carte précédente | `map_editor_gamepad.gd:310` | 🟠 |
| 4 | `MapData._ready()` adopte `custom.json` → arène par défaut injouable | `map_data.gd:27` | 🟠 |
| 5 | `load_map()` lit `user://` avant `res://` → un save nommé `default` masque la carte livrée | `map_data.gd:59` | 🟠 |
| 6 | `solid` = murs uniquement → on marche dans le vide hors du sol | `map_data.gd:151` | 🟠 |
| 7 | Arène construite une seule fois dans `_ready()` → changer de carte est sans effet | `game_state.gd:118` | 🟠 |
| 8 | 1 `StaticBody2D` par tuile (jusqu'à 400 corps) | `map_data.gd:154` | 🟡 perf |
| 9 | Pas d'undo, pas de souris, pas de zoom/pan, grille figée 20×20 | `map_editor_gamepad.gd` | 🟡 UX |
| 10 | Partage = JSON brut 16 Ko dans le presse-papier | `map_data.gd:250` | 🟡 UX |

---

## Phase 1 — Fondations données (`MapData` v3)

**Objectif : un format de carte nommé, versionné, compact et partageable.**

### 1.1 Format v3

```gdscript
{
  "version": 3,
  "id": "a3f2c1d0",             # généré une fois, immuable — identité de la carte
  "name": "Cathédrale",         # nom affiché, éditable
  "author": "",
  "created_utc": "2026-08-03T15:00:00Z",
  "grid_size": {"x": 32, "y": 32},
  "tile_size": 35,
  "floor": "3,2,14;3,3,14;...", # RLE : x,y,longueur (runs horizontaux)
  "walls": "2,2,16;...",
  "spawn_p1": {"x": 3, "y": 16},
  "spawn_p2": {"x": 28, "y": 16}
}
```

- **RLE horizontal** au lieu d'une liste de dicts : `default.json` passe de **16 637 octets à ~600**.
- Écrire `MapCodec` (`map_codec.gd`, `class_name MapCodec extends RefCounted`) : `encode_runs(cells: Array[Vector2i]) -> String` / `decode_runs(s: String) -> Array[Vector2i]`.
- **Migration v2 → v3** transparente à la lecture (`_migrate_v2(data)`), pour ne pas casser `custom.json` existant ni `assets/maps/default.json`.

### 1.2 Correction de la sauvegarde (problèmes 3, 4, 5)

Règles non négociables :

- `save_map()` prend un **nom obligatoire** et écrit dans `user://maps/<slug>.json`. `slug = name.to_lower().replace(" ", "_")` filtré sur `[a-z0-9_-]`.
- **`res://assets/maps/` est en lecture seule.** `save_map()` refuse tout slug entrant en collision avec une carte livrée et renvoie une erreur explicite (« Ce nom est réservé »).
- **Inverser la priorité de `load_map()`** : `res://assets/maps/` **d'abord**, `user://maps/` ensuite. Une carte livrée ne peut plus jamais être masquée.
- **Supprimer l'auto-adoption dans `_ready()`.** Remplacer par :
  ```gdscript
  var selected_map_id: String = DEFAULT_MAP_NAME   # persiste pour la session
  ```
  `_ready()` ne fait que peupler le catalogue, sans rien sélectionner d'autre que `default`.
- `save_map()` renvoie `Dictionary` `{ok: bool, error: String, path: String}` — plus de `bool` muet.

### 1.3 Catalogue & sélection de session

```gdscript
func list_maps() -> Array[Dictionary]   # [{id, name, source: "builtin"|"user", path, grid_size, tile_counts}]
func get_selected() -> Dictionary        # carte active pour le prochain match
func select_map(id: String) -> bool
func delete_map(id: String) -> bool      # user:// uniquement
func duplicate_map(id: String, new_name: String) -> String
```

`selected_map_id` vit dans l'autoload → **persiste toute la session**, remis à `default` uniquement au lancement.

### 1.4 Partage par code court

```gdscript
func to_share_code(data: Dictionary) -> String
# JSON.stringify → to_utf8_buffer() → compress(FileAccess.COMPRESSION_GZIP)
# → Marshalls.raw_to_base64() → "CANDELA-" + b64

func from_share_code(code: String) -> Dictionary  # {ok, data, error}
```

Une carte 32×32 pleine → **code d'environ 300–500 caractères**, collable dans un Discord. Import : validation stricte (version, bornes de grille, présence des spawns) avant adoption ; jamais de `JSON.parse` non vérifié appliqué directement.

**Livrables** : `map_data.gd` réécrit, `map_codec.gd` (nouveau), `assets/maps/default.json` re-généré en v3.

---

## Phase 2 — Collisions, occlusion et « seul le sol est praticable »

**Objectif : ce qui est dessiné est exactement ce qui bloque et ce qui projette une ombre.**

### 2.1 Grille de solidité

```gdscript
solid[x][y] == true  si  walls.has(cell)  OU  not floor.has(cell)
```

Le vide hors du sol devient un mur plein → impossible de sortir de la carte, sans avoir à dessiner une bordure à la main.

### 2.2 Fusion en rectangles (greedy meshing)

Remplacer les N `StaticBody2D` par **un seul `StaticBody2D`** portant M `CollisionShape2D` rectangulaires, M étant le résultat d'un greedy meshing (extension horizontale puis verticale sur la grille booléenne).

- Arène type : **~400 corps → ~15 rectangles**.
- `collision_layer = 1`, `collision_mask = 1` (inchangé, cohérent avec `bullet.gd:189`).

### 2.3 Occlusion lumineuse — le point critique

Pour chaque rectangle fusionné, ajouter un `LightOccluder2D` avec `OccluderPolygon2D` :

```gdscript
var occ := LightOccluder2D.new()
var poly := OccluderPolygon2D.new()
poly.polygon = PackedVector2Array([...])   # coins du rectangle
poly.cull_mode = OccluderPolygon2D.CULL_CLOCKWISE
occ.occluder = poly
occ.occluder_light_mask = 1 | 2 | 4        # doit couvrir les masques utilisés par player.gd:137-146
```

⚠️ **Piège à vérifier** : des occluders rectangulaires qui se touchent peuvent produire des coutures dans l'ombre. Si le rendu montre des artefacts, basculer sur un **tracé de contour** (marching squares sur la grille de solidité) produisant un polygone par région connexe — silhouette d'ombre parfaitement propre. Décider **après test visuel**, pas avant.

### 2.4 Split-screen (problème 2)

Ajouter `TileMapLayer` à `_find_visuals()` dans `game_state.gd`, **ou** — plus propre — dupliquer explicitement les deux `TileMapLayer` custom vers `visibility_layer = 2` (light_mask `1|16`) et `visibility_layer = 4` (light_mask `1|32`), en suivant le motif déjà en place à [game_state.gd:267-283](game_state.gd:267).

### 2.5 Reconstruction d'arène à la demande (problème 7)

Extraire de `_setup_ambient_visuals()` une fonction publique :

```gdscript
func rebuild_arena() -> void   # purge CustomFloor/CustomWalls/CustomWallBodies puis reconstruit
```

Appelée depuis `_do_start_round()` → changer de carte dans le menu prend effet immédiatement, y compris entre deux manches.

### 2.6 Réseau

Dans `_do_start_round()` côté hôte : envoyer le code partagé de la carte via RPC ; le client appelle `from_share_code()` puis `rebuild_arena()` avant le spawn. La sérialisation existe déjà (`get_map_json`), il manque juste le branchement dans le flux de manche.

**Livrables** : `map_data.gd` (build), `map_geometry.gd` (nouveau : greedy meshing + contours), patch `game_state.gd`.

---

## Phase 3 — Éditeur : fluidité et confort

**Objectif : donner envie de créer.**

### 3.1 Entrées doubles souris + manette

| Action | Manette | Clavier / Souris |
|---|---|---|
| Déplacer curseur | Stick / D-Pad | Souris (curseur suit la tuile survolée) |
| Peindre | Croix (maintien = trainée) | Clic gauche maintenu |
| Effacer | Carré (maintien) | Clic droit maintenu |
| Rectangle | L2 + Croix | Maj + clic |
| Pot de peinture | R2 + Croix | Ctrl + clic |
| Pan caméra | Stick droit | Clic molette / Espace + glisser |
| Zoom | L2 / R2 | Molette |
| Undo / Redo | Select / Select+R1 | Ctrl+Z / Ctrl+Maj+Z |

**Le maintien continu remplace le double-appui actuel** : la validation en deux temps est la principale cause de lourdeur ressentie.

### 3.2 Undo / Redo

Pile de commandes légère — chaque opération ne stocke que les cellules modifiées :

```gdscript
class CellEdit:
    var layer: StringName        # &"floor" | &"walls"
    var cell: Vector2i
    var before: Vector2i         # coord atlas, ou Vector2i(-1,-1) pour vide
    var after: Vector2i
```

Un coup de pinceau = une transaction = un `Array[CellEdit]`. Profondeur 100.

### 3.3 Caméra

`Camera2D` avec `position_smoothing_enabled = true`, `position_smoothing_speed = 8.0`, zoom borné `[0.5, 3.0]`, limites calées sur la grille. Le curseur pousse la caméra quand il approche du bord (edge-scroll). C'est ce qui produit la sensation de fluidité.

### 3.4 Outils

`FLOOR`, `WALLS`, `SPAWN_P1`, `SPAWN_P2` — conservés — plus :
- **Pot de peinture** (flood fill borné à la région connexe)
- **Auto-mur** : génère automatiquement les murs sur le pourtour du sol dessiné (un bouton, gain de temps énorme)
- **Miroir** : symétrie horizontale/verticale de la carte — les cartes de duel équilibrées se font en trois secondes

### 3.5 Validation en direct

Panneau permanent, mis à jour à chaque édition :

| Contrôle | Rendu |
|---|---|
| Sol présent (≥ 20 tuiles) | ✓ / ✗ |
| Spawn P1 posé et sur du sol | ✓ / ✗ |
| Spawn P2 posé et sur du sol | ✓ / ✗ |
| Les deux spawns communiquent (flood fill) | ✓ / ✗ |
| Distance entre spawns ≥ 10 tuiles | ⚠ conseil |

Sauvegarde et test bloqués tant qu'un ✗ subsiste, avec le motif affiché en clair. C'est ce qui rend l'outil **satisfaisant** : on ne peut pas produire une carte cassée.

### 3.6 Habillage visuel

Reprendre l'identité néon du jeu (`BLEND_MODE_ADD`, blanc sur noir, cf. `game_state.gd:248`) :
- Grille de fond en dégradé d'opacité vers les bords
- Curseur pulsant avec halo (déjà amorcé dans `_on_cursor_draw`)
- Tuiles posées avec un léger `Tween` de scale (`0.85 → 1.0`, `TRANS_BACK`, `EASE_OUT`) — le retour tactile qui fait « pro »
- Toasts repositionnés en bas à droite pour ne plus masquer la zone de dessin
- Aperçu d'éclairage temps réel : un `PointLight2D` suit le curseur avec les occluders actifs → **on voit les ombres pendant qu'on construit**

**Livrables** : `map_editor_gamepad.gd` scindé en `map_editor.gd` (orchestration) + `map_editor_tools.gd` (outils/undo) + `map_editor_camera.gd`, `map_editor_hud.gd` refondu, `map_editor.tscn` mis à jour.

---

## Phase 4 — Sauvegarde nommée, galerie et miniatures

### 4.1 Miniatures générées par le code

Pas de capture `SubViewport` (fragile, asynchrone). Rendu direct dans une `Image` depuis les données :

```gdscript
static func render_thumbnail(data: Dictionary, px_per_tile: int = 4) -> ImageTexture
# sol = gris sombre, murs = blanc, spawn P1 = bleu, spawn P2 = orange
```

Instantané, déterministe, jamais désynchronisé, aucun fichier à stocker. Mise en cache mémoire par `id`.

### 4.2 Dialogue de sauvegarde dans l'éditeur

`LineEdit` pour le nom + liste des cartes existantes + détection de collision (« Écraser *Cathédrale* ? »). `Start` ouvre le dialogue, plus de sauvegarde silencieuse sur un slot unique.

### 4.3 Galerie dans le menu principal (onglet MAP)

Remplacer les deux boutons actuels ([ui.gd:1353-1369](ui.gd:1353)) par :

```
┌─ CARTES ──────────────────────────────────┐
│ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐      │
│ │ [img]│ │ [img]│ │ [img]│ │  +   │      │
│ │Arène │ │Cathé.│ │Ruelle│ │Créer │      │
│ │livrée│ │ 32²  │ │ 24²  │ │      │      │
│ └──────┘ └──────┘ └──────┘ └──────┘      │
│   ● sélectionnée (liseré néon)            │
├───────────────────────────────────────────┤
│ [IMPORTER UN CODE]  [PARTAGER]  [SUPPR.]  │
└───────────────────────────────────────────┘
```

- `ScrollContainer` + `GridContainer`, cartes de 160×160 px
- Navigation manette intégrée au système `p1_nav`/`p2_nav` existant ([ui.gd:619](ui.gd:619))
- La sélection alimente `MapData.select_map(id)` → **conservée pour toute la session**
- « PARTAGER » copie le code court et affiche un toast de confirmation
- « IMPORTER » ouvre un `LineEdit` ; validation puis ajout à `user://maps/`
- Le bouton JOUER utilise la carte sélectionnée — l'arène par défaut redevient un choix normal parmi les autres

**Livrables** : `map_thumbnail.gd` (nouveau), `map_gallery.gd` (nouveau, composant `Control`), patch `ui.gd`.

---

## Phase 5 — Validation

1. **Tests unitaires** (`gdUnit4` si disponible, sinon script headless) : round-trip `MapCodec` encode/decode, migration v2→v3, greedy meshing (nombre de rects + couverture exacte), refus d'écriture sur un nom réservé.
2. **Tests d'intégration en jeu** — chacun doit être vérifié manette en main :
   - Les balles rebondissent sur les murs custom (`bullet.gd` masque 1)
   - La torche **ne traverse pas** les murs custom ← la validation la plus importante
   - Impossible de sortir de la zone de sol
   - Split-screen : les deux joueurs voient correctement les tuiles
   - Changer de carte au menu → prise en compte sans redémarrage
   - Sauvegarder une carte ne modifie **jamais** `assets/maps/default.json`
3. **Perf** : viser < 20 `CollisionShape2D` et < 20 occluders sur une carte 32×32, 60 fps stables en split-screen.

---

## Délégation aux sous-agents

Découpage par **propriété exclusive de fichiers** — aucun agent n'écrit dans un fichier détenu par un autre, donc exécution parallèle sans conflit.

| Agent | Périmètre | Fichiers détenus | Dépend de |
|---|---|---|---|
| **A — Données** | Phase 1 intégrale | `map_data.gd`, `map_codec.gd`, `assets/maps/default.json` | — |
| **B — Géométrie** | Phase 2.1→2.3 | `map_geometry.gd` | contrat d'API de A |
| **C — Intégration jeu** | Phase 2.4→2.6 | `game_state.gd` | A + B |
| **D — Éditeur** | Phase 3 | `map_editor*.gd`, `map_editor.tscn` | A |
| **E — UI / galerie** | Phase 4 | `map_thumbnail.gd`, `map_gallery.gd`, `ui.gd` | A |

**Ordonnancement :**

```
Vague 1 :  A  (seul — définit les contrats)
                    │
Vague 2 :  B ── D ── E     (parallèle, 3 agents)
                    │
Vague 3 :  C  (intègre B dans le jeu)
                    │
Vague 4 :  Validation Phase 5 (moi, manette en main)
```

**Contrat d'API figé à la fin de la vague 1** — publié dans ce document pour que B, D et E codent contre lui sans se lire mutuellement :

```gdscript
# MapData (autoload)
func list_maps() -> Array[Dictionary]
func get_selected() -> Dictionary
func select_map(id: String) -> bool
func save_map(data: Dictionary, name: String) -> Dictionary   # {ok, error, path}
func delete_map(id: String) -> bool
func to_share_code(data: Dictionary) -> String
func from_share_code(code: String) -> Dictionary              # {ok, data, error}
func extract_from_layers(floor: TileMapLayer, walls: TileMapLayer, spawns: Node2D) -> Dictionary
func apply_to_layers(floor: TileMapLayer, walls: TileMapLayer, spawns: Node2D, data: Dictionary) -> void

# MapGeometry (RefCounted statique)
static func build_solid_grid(data: Dictionary) -> Array          # Array[Array[bool]]
static func merge_rects(solid: Array) -> Array[Rect2i]
static func build_collisions(data: Dictionary, parent: Node) -> StaticBody2D   # corps + occluders
static func is_connected(data: Dictionary) -> bool                # flood fill entre spawns

# MapThumbnail (RefCounted statique)
static func render(data: Dictionary, px_per_tile: int = 4) -> ImageTexture
```

**Consignes communes à tous les agents** — à coller dans chaque prompt :

- Godot **4.7** exclusivement. Toute syntaxe Godot 3 est un échec de la tâche.
- Typage statique partout (`var x: int`, `-> void`, `Array[Vector2i]`).
- Commentaires et chaînes affichées **en français**, aligné sur le code existant.
- Ne jamais écrire dans un fichier détenu par un autre agent — signaler le besoin plutôt que patcher.
- Ne pas lancer le jeu ni modifier `project.godot` sans validation.

---

## Ordre d'exécution recommandé

Si tu veux un gain visible immédiatement plutôt que le plan complet, l'ordre par rapport valeur/effort est :

1. **Phase 2.3** (occluders) — répare la mécanique centrale, ~30 lignes
2. **Phase 1.2** (correctif sauvegarde) — arrête la destruction de données, ~40 lignes
3. **Phase 2.1** (sol praticable uniquement) — ~10 lignes
4. Puis 4 (galerie), 3 (confort éditeur), le reste
