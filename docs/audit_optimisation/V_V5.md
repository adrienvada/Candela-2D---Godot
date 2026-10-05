# V5 — « Les enjeux à part » : vérification contradictoire (2026-10-04)

Contradicteur, lecture seule, Godot non lancé. Dépôt `52a29c1`. Outils : `sed`/`grep` ciblés, Python (`zlib`, `wave`) —
les deux scripts sont dans `audit/v5_work/` (`bombe_codec.py`, `stereo_sfx.py`, relançables). Rien n'a été écrit dans le dépôt.
Étiquettes : PROUVÉ = lu dans le code ou calculé hors jeu ; ESTIMÉ = raisonné ; « à mesurer » = personne ne sait.

| ID(s) | Verdict | Sévérité corrigée | Coût corrigé |
|---|---|---|---|
| CAR-07 | CONFIRMÉ (import, démarrage) ; CONFIRMÉ AVEC RÉSERVE (en ligne : hôte modifié requis) | MAJEUR (robustesse) | 134 215 040 cases, ≥ 3,2 Go ; ≈ 7–30 s par décodage ; 1–2 min à chaque lancement (autoload + vignette) ; ≥ 8 min à la pose de l'arène |
| AUD-07 | CONFIRMÉ | MINEUR pour le code ; décision d'équité de contenu à remonter à Adrien | sans objet (hors cadence) |
| AUD-01 | CONFIRMÉ AVEC RÉSERVE | MINEUR (MAJEUR si le micro-banc dépasse 1,5 ms) | 0 hors échange ; ≈ 0,1–0,25 ms échange léger ; ≈ 0,5–1,4 ms rafale de pistolet ; ≈ 0,7–2,6 ms pic de volée de pompe / rafale d'Occulteur, 0,3–0,5 s — ESTIMÉ ×2 |
| GAD-01 (≈ SHA-11, SHA-09) | CONFIRMÉ AVEC RÉSERVE, CONNU-OUVERT | MAJEUR (potentiel, non prouvé en voxel) | mesuré 3,39 ms/fusée en couches (M3) ; voxel ≈ 2 ms/fusée ESTIMÉ, jamais mesuré sur M3 |
| GAD-12 (= ISO-06 ; recoupe LUM-03) | DÉJÀ PRIS EN CHARGE (OM6, 1re puce) | MINEUR | ≤ 0,15 ms par objet et par vue (borne, un seul point mesuré) ; création 0,3–1 ms/objet ESTIMÉ, hors OM6 |
| AUD-04 | CONFIRMÉ sur le fait, RÉFUTÉ sur l'enjeu | ANECDOTIQUE | ≈ 0,6 Mo ; décodage QOA ×2 négligeable ; effet audible nul pour 37 des 40 |

---

## CAR-07 — `MapCodec.validate` ne borne ni les runs ni les cases

### 1. Le code

Ce que le « garde-fou anti-bombe de décompression à l'import » (CLAUDE.md) borne **exactement** — trois choses, pas plus :

```gdscript
# map_codec.gd:30 et :125 — (a) la taille du JSON DÉCOMPRESSÉ : 8 Mio
const MAX_DECOMPRESSED_BYTES := 8 << 20
var raw := compressed.decompress_dynamic(MAX_DECOMPRESSED_BYTES, FileAccess.COMPRESSION_GZIP)
# map_codec.gd:85-92 (decode_runs) — (b) la longueur d'UN run (≤ 128), ni leur nombre, ni leur somme
var length := int(parts[2])
if length <= 0 or length > MAX_GRID:
	continue
for i in range(length):
	cells.append(Vector2i(x + i, y))
# map_codec.gd:177 (validate) — (c) grid_size ∈ [8 ; 128]
# map_codec.gd:180 — le seul contrôle du sol
if not normalized.has("floor") or String(normalized["floor"]).is_empty():
```

Ne sont bornés ni le nombre de runs, ni la somme des longueurs (la grille déclarée ne filtre rien dans `decode_runs`), ni la longueur
de la chaîne `floor`/`walls`, ni les coordonnées, ni les clés inconnues du JSON (conservées par `validate`, qui renvoie `normalized`).
Le garde-fou est donc exact **pour ce qu'il dit** (octets décompressés) et muet sur l'amplification du RLE : 8 Mio de « 0,0,128; »
= 1 048 555 runs = 134 215 040 cases.

Le décodage est consommé par : `MapData._scan_dir` (map_data.gd:112-113, pour **compter**), `MapGeometry.build_grid` (map_geometry.gd:136-146,
trois familles à chaque appel), `MapData.apply_to_layers` (:419-432), `AudioManager.accorder_a_la_carte` (audio_manager.gd:1062),
`IsoGeometrie` (iso_geometrie.gd:313, 324), `ArenaDecor` (arena_decor.gd:227-228), et `MapThumbnail.render` (map_thumbnail.gd:70-75) qui redécode
**et peint chaque case** (`_paint_cell` → `fill_rect`, :125-129) à la construction de la galerie (map_gallery.gd:347 ← `_rebuild_tiles`, :97) et de la carte active (ui.gd:6529).

### 2. La fréquence : par quels chemins un code arrive

| Chemin | Chaîne d'appels | Quand | Exposé ? |
|---|---|---|---|
| Import galerie | `map_gallery.gd:545 _confirm_import` → `MapData.import_share_code` (map_data.gd:340) → `save_map` (236 ; `validate` :268, écrit le fichier :281) → `refresh_catalog` (63) → `_scan_dir` (112) | à l'import | **oui** — le champ est pré-rempli depuis le presse-papiers si le texte commence par `CANDELA-` (map_gallery.gd:530-539) ; le `LineEdit` n'a pas de `max_length` |
| Import éditeur | `map_editor.gd:1108 _on_import_confirmed` (appel :1113) → même chaîne | à l'import | oui |
| **Démarrage** | `MapData._ready` (map_data.gd:52-54, autoload, avant toute interface) → `refresh_catalog` → `_scan_dir(user://maps)` → `_read_map_file` (484-500, `validate`) → `get_floor_cells(data).size()` | **à chaque lancement** tant que le fichier est dans `user://maps/` | oui (persistant) |
| En ligne | hôte : `_host_map_code()` (game_state.gd:1919) → `rpc_start_round.rpc(w1, w2, _host_map_code(), _new_match_id())` (:1836) ; client : `@rpc("authority","call_local","reliable") rpc_start_round` (:1842) → `_adopt_host_map` (:1868) → `MapData.adopt_shared_map` (map_data.gd:471) → `_do_start_round` (:1859) → `rebuild_arena` (:1412 ; `accorder_a_la_carte` :1424, `apply_to_layers` :1492, `build_collisions` :1496) | à **chaque manche** | oui, si l'hôte envoie le code |
| Carte active locale | `select_map` → `rebuild_arena` | à chaque manche | oui |
| Cartes livrées / salles d'aventure | `assets/maps/*`, `assets/solo/chapitre_*` | — | non (106 cartes relevées : au plus 2 445 caractères, 322 runs par famille) |

**Oui, la carte passe sur le fil** : « par valeur », jamais par identifiant (ROADMAP l. 2025-2030 et l. 2474). Seul l'hôte (`authority`) peut
émettre `rpc_start_round` : un client ne peut pas imposer un code à l'hôte. Le transport EOS est natif (non lisible ici) ; mais un code légitime
de ~1,6 k caractères dépasse déjà le paquet EOS de 1 170 octets, donc la fragmentation existe — la tenue d'un RPC de 16 Ko n'est pas vérifiée, elle est probable.

**Scénario d'attaque, pas à pas** (calculé : `v5_work/bombe_codec.py`)
1. Fabriquer un JSON de 8 388 590 octets : `{"version":4,"id":…,"grid_size":{"x":32,"y":32},"floor":"0,0,128;0,0,128;…(1 048 555 fois)","walls":"","low_walls":"","spawn_p1":…,"spawn_p2":…}`.
2. gzip : **12 369 octets**, base64 : **16 492 caractères** (+ `CANDELA-`), ratio 678:1 — l'ordre de grandeur de l'auditeur (« ~16 Ko ») tient.
3. La victime colle le code (champ pré-rempli depuis le presse-papiers). `from_share_code` : base64 → 12 Ko → `decompress_dynamic(8 Mio)` accepte (8 388 590 < 8 388 608) → `JSON.parse` d'une chaîne de 8 Mo (rapide) → `validate()` **rend ok** : grille 32×32, sol non vide, deux apparitions.
4. `save_map` valide une seconde fois, écrit un fichier de ~8 Mo dans `user://maps/`, puis `refresh_catalog()` → `_scan_dir` → `get_floor_cells(data).size()` : **134 M `Vector2i`** (Variant de 24 octets dans un `Array[Vector2i]`) ⇒ ≥ 3,2 Go résidents (la capacité double : jusqu'à 4 Gio réservés), 7–30 s de GDScript. Le jeu est figé pendant l'import.
5. **Chaque lancement suivant** : `MapData._ready` refait 4. avant même qu'une fenêtre existe, puis la construction de l'interface (`MapGallery._ready` → `_rebuild_tiles` → `MapThumbnail.render_fit`) redécode la carte et **peint ses 134 M cases une à une** : le démarrage devient une affaire de minutes, deux passes de 3,2 Go. Aucune interface ne permet de supprimer la carte : il faut effacer `user://maps/<nom>.json` à la main (macOS : `~/Library/Application Support/Godot/app_userdata/Candela 2D/maps/`).
6. Si la carte est jouée (ou reçue d'un hôte) : `rebuild_arena` → ≥ 20 `build_grid` (CAR-03) × 3 familles ; chacun redécode puis parcourt 134 M cases (filtre de grille, puis `floor_set[cell] = true` pour chaque case dans la grille). Ordre de grandeur : plusieurs minutes (≥ 8 min ESTIMÉ), mémoire à chaque passage.
7. En ligne, un hôte **modifié** envoie ce code dans `rpc_start_round` à chaque manche. Un hôte légitime qui porterait la bombe se figerait lui-même à son propre démarrage (étape 5) : le vecteur en ligne exige un client modifié ou un fichier jamais scanné. Le client figé cesse de répondre ; ESTIMÉ (délais du transport non vérifiés) : le lien finit par expirer, et le commentaire de `_refuse_match_on_map` (game_state.gd:1880-1882) rappelle qu'un pair qui disparaît laisse l'hôte « finir par lui compter la victoire » — de quoi faire perdre un adversaire par gel. Rien n'est écrit sur le disque du client dans ce cas (`adopt_shared_map` n'enregistre pas).

### 3. Le coût

- PROUVÉ (arithmétique hors jeu) : 134 215 040 cases ; 3,22 Go à 24 octets (1,07 Go même à 8 octets). La borne de 8 Mio plafonne ~16 cases par caractère.
- ESTIMÉ : le corps de `decode_runs` coûte ≈ 50–200 ns par case (appel validé `append` + construction `Vector2i` + itération) ⇒ **7–30 s** par décodage (le « 15–30 s » de l'auditeur est le haut de la fourchette ; sur M3 plutôt le bas). `build_grid` ajoute, par case, le filtre de grille et l'insertion de dictionnaire : ordre de la minute **par appel** ; × ≥ 20 appels à la pose de l'arène. Au **lancement** : le décodage de l'autoload (7–30 s) puis la vignette (un second décodage + 134 M `Rect2i`/`fill_rect` ≈ 0,2–0,4 µs chacun, soit +30–60 s) : plutôt **1 à 2 minutes** que les « 15–30 s » du rapport CAR.
- Mémoire : un seul tableau vivant à la fois, libéré au retour de `.size()` ; pas de fuite, mais un pic de ≥ 3,2 Go. Sur un Mac de 8 Go, soit swap massif, soit arrêt par le système — figer est plus probable que planter (l'allocation réussit).

### 4. Les invariants

- `MapCodec.VERSION` ne bouge pas ⇒ l'empreinte du fil (`test_protocole`) non plus. Les bornes ne touchent aucun format.
- Marge : plus grosse famille relevée = 2 445 caractères / 322 runs (assets/solo/chapitre_08/niveau_09.json) ; bornes proposées 131 072 caractères / 16 384 runs = 50 fois. Pire carte d'éditeur (damier 128×128) : 8 192 runs ≈ 82 000 caractères, sous la borne.
- **Correctif de l'auditeur : insuffisant tel quel.** `MAX_RUNS = 16 384` laisse passer 16 384 × « 0,0,128 » = 2,1 M cases par famille, redécodées ≥ 20 fois par arène : une trentaine de secondes de gel, plus de bombe mais un gel quand même. **La vraie borne est sur les cases** (somme des longueurs ≤ `MAX_GRID × MAX_GRID`, ou arrêt de `decode_runs` à `4 × MAX_GRID²` = 65 536) ; l'encodeur (`encode_runs`) dédoublonne, donc une carte légitime ne dépasse jamais `gx × gy` cases par famille.
- `validate()` suffit à fermer **les trois entrées** (import, fichier au démarrage via `_read_map_file` :500, hôte via `from_share_code`) : une bombe déjà sur disque serait rejetée avec le `push_warning` « carte illisible » de `_scan_dir` — ce qui **guérit** le gel au démarrage sans que le joueur supprime quoi que ce soit.
- La validation doit venir **après** les migrations (v2 → v3 transforme un tableau en chaîne) ; la migration v2 elle-même encode jusqu'à ~600 000 cellules `{x,y}` d'un JSON de 8 Mio (`sort_custom` : quelques secondes) — borner `out[key].size()` avant `encode_runs` si l'on veut tout fermer.
- Autre trou de la même famille, **à vérifier à chaud** (je ne lance pas Godot) : `String(normalized["floor"])` (:180) est un constructeur appliqué à un `Variant` ; avec `"floor": 5` ou un dictionnaire, il pourrait lever une erreur de script (ROADMAP l. 9206 : « vérifier le type avant de lire »). Le contrôle de type du correctif le couvre.
- Ce que le correctif ne ferme pas : une carte **légale mais lourde** (damier 128×128 = 8 192 occulteurs, 8 192 collisions) reste possible. C'est un autre plafond (rectangles fusionnés), à décider avec Adrien (les salles d'aventure vont jusqu'à 113 occulteurs).

### 5. Le statut

NOUVEAU. Voisins : ROADMAP l. 2067 (« Garde-fou anti-bombe de 8 Mo », quatrième cause d'échec listée de l'adoption) et l. 9206 (typer avant de lire). `tools/test_map_codec.gd:266-271` teste la bombe de **décompression** seulement (8 Mio + 4 096 octets d'espaces) : il ne voit pas l'amplification du RLE.

### 6. Le verdict

**CONFIRMÉ.** MAJEUR (robustesse) : une collée suffit, l'effet est persistant et sans issue dans l'interface ; hors cadence. En ligne : CONFIRMÉ AVEC RÉSERVE (hôte modifié).

**Correctif minimal** (S, ~20 lignes + 1 test) dans `validate()`, après migration : pour chacune des trois clés, `typeof == TYPE_STRING`, `length() <= 131072`, puis (sur une chaîne déjà bornée) `count(";") <= 16384` **et** somme des longueurs de runs ≤ `MAX_GRID × MAX_GRID` (lecture du 3e champ, sans `Vector2i`) ; sinon `_fail("Carte trop complexe")`. En défense en profondeur, `decode_runs` s'arrête à `4 × MAX_GRID²` cases. Le `count_cells` pour `_scan_dir` est une optimisation à part.

**Preuve dans le cloud** (headless, jamais la vraie bombe) : dans `tools/test_map_codec.gd`, un code de **20 000 runs** « 0,0,128 » (2,56 M cases, ≈ 61 Mo, ~0,3 s) — avant correctif `validate(...).ok == true` (la suite rougit : le trou est documenté), après `ok == false` en < 50 ms. Mesurer en plus `Performance.get_monitor(Performance.MEMORY_STATIC)` avant/après un `decode_runs` de ce code : ≈ 61 Mo ⇒ confirme 24 octets/case. `tools/test_carte_partagee.gd` : `adopt_shared_map(code_lourd)` doit rendre une erreur non vide, et `_refuse_match_on_map` est le chemin propre déjà en place.

---

## AUD-07 — six classes sur dix muettes (recharge, clic à vide) et invisibles au bord de l'écran adverse

### 1. Le code

```gdscript
# audio_manager.gd:1796-1801 — le TIR a un repli (voulu, commenté l. 1783-1787)
func play_weapon_shot(slug, pos, emetteur := -1, audible_partout := false):
	var chemin := chemin_tir(slug, randi_range(1, VARIANTES_TIR))
	if get_audio_stream(chemin) == null:
		return play_sfx_2d_random_pitch("shoot", pos, 0.92, 1.08, 0.0, BUS_SFX, emetteur, facteur, audible_partout)
# audio_manager.gd:1930-1934 — la RECHARGE n'en a pas
var cle := "weapon_reload_" + slug
if get_audio_stream(cle) == null:
	return null
# audio_manager.gd:1971-1972 puis 1590-1593 — le CLIC À VIDE : null AVANT _annoncer() (appelé l. 1632)
func play_percuteur(slug, pos, emetteur := -1):
	return play_sfx_2d(chemin_percuteur(slug), pos, 1.0, 0.0, BUS_SFX, emetteur)
func play_sfx_2d(...):
	var stream = get_audio_stream(stream_or_key)
	if not stream:
		return null
```

Le slug passé est `current_weapon.slug()` = `torch_cookie` de la classe (player.gd:2265, 2269, 2289, 2692 ; game_state.gd:5275 `c.torch_cookie = slug  # une seule clé : cookie, sprite, sons, icône`).
Pour un slug sans fichier, `get_audio_stream` rend `null` (`ResourceLoader.exists` faux, repli `.ogg` faux).

### 2. La fréquence

À chaque tir, chaque recharge (player.gd:1250, 2097), chaque pression de gâchette sur chargeur vide (`_clic_a_vide`, :2286-2289), côté hôte comme côté client (le bruit de corps de l'hôte est répliqué, `rpc_bruit_de_corps` :2258-2260 : silence **symétrique** des deux côtés, donc pas de désynchronisation).

### 3. Ce que l'adversaire entend et voit (fichiers de `assets/audio/weapons/`, listés ; durées de `enveloppes_sons.gd`)

| Classe (slug) | Tir | Recharge (`reload_time`) | Clic à vide | Douille |
|---|---|---|---|---|
| Parasite (`pistolet`) | 4 prises propres (0,45–0,71 s) | propre, 0,85 s (2,2 s) | propre, 0,12 s | générique |
| Illusionniste (`fusil`) | 4 prises (0,53–0,88 s) | propre, 1,10 s (3,5 s) | propre, 0,28 s | générique |
| Terrassier (`pompe`) | 4 prises (0,88–1,59 s) | propre, 1,00 s (5,6 s) | propre, 0,24 s | générique |
| Braconnier (`arbalete`) | 4 prises (0,35–0,44 s) | propre, 0,95 s (4,5 s) | propre, 0,10 s | aucune (pas de douille) |
| Fumiste, Incendiaire, Sentinelle, Occulteur, Allumeur, Spectre (`fumiste`, `incendiaire`, `sentinelle`, `occulteur`, `allumeur`, `spectre`) | **`weapon_shoot.wav` générique** (0,71 s, pitch ±8 %), identique pour les six : audible, liseré dessiné (famille `shoot`) | **rien** (2,8 / 3,2 / 4,0 / 2,6 / 2,4 / 2,6 s) | **rien** | générique |

Aucun fichier `weapon_<slug>_NN.wav`, `weapon_dry_<slug>.wav` ni `weapon_reload_<slug>.wav` pour les six (listage de `assets/audio/weapons/` : seuls `arbalete`, `fusil`, `pistolet`, `pompe`).
Conséquences, toutes PROUVÉES par lecture : (a) la **fenêtre de vulnérabilité** de la recharge ne se trahit pour 6 classes sur 10 ni à l'oreille ni au liseré ; (b) le clic à vide, que Q54 (ROADMAP l. 2478, « oui on le rend audible ») a voulu « événement du monde », n'existe pas pour elles ; (c) on ne distingue plus les six classes à l'oreille (un seul son de tir) alors que les quatre autres s'identifient à leur arme.
Précision utile : la désignation « muettes ET invisibles » est exacte pour la recharge et le clic ; **le tir, lui, a un repli** (audible, visible).

### 4. Les invariants / garde-fous

- Aucune suite ne garde : `tools/test_musique.gd:231, 637, 683, 761` ne boucle que sur `["pistolet","fusil","pompe","arbalete"]` ; `ClassData.assets_presents()` (class_data.gd:106) ne contrôle que cookie et sprite.
- La règle du dépôt « câbler, taire, diagnostiquer » (audio_manager.gd:87-88) dit que **l'absence de fichier est un silence voulu en attendant la livraison** : ce peut être une livraison en retard plutôt qu'un choix. Rien ne le tranche (la ROADMAP ne parle des assets manquants des six classes que pour le cookie et le sprite, l. 18720-18725).
- Un repli en code (recharge/clic à vide génériques) **change l'équilibre** (il ferait fuir la fenêtre de recharge pour 10 classes sur 10) : c'est le choix d'Adrien, pas un correctif de performance.
- Autre incohérence à lui signaler : le Spectre (« Pistolet silencieux », zéro flash) tire avec le son générique à plein niveau (`NIVEAU_RELATIF["shoot"] = 0 dB`, portée 0,85).

### 5. Le statut

NOUVEAU (recherches ROADMAP `weapon_dry`, `weapon_reload`, « six classes » : aucune trace de décision sur le son des six).

### 6. Le verdict

**CONFIRMÉ.** Sévérité : MINEUR côté code (rien à optimiser, aucun risque de désynchronisation) ; **à remonter à Adrien comme question d'équité de contenu** (asymétrie d'information selon la classe choisie, déblocage cumulatif donc choix libre en classé). Ne pas corriger sans lui.
**Preuve dans le cloud** : test headless « un événement par classe » — brancher `AudioManager.son_localise`, appeler `play_weapon_reload(slug, …)` et `play_percuteur(slug, …)` pour les dix slugs de `GameState._classes`, compter les événements : 1 pour quatre classes, 0 pour six. À l'inverse, `play_weapon_shot` doit en émettre un pour les dix (le repli tient).

---

## AUD-01 — le liseré reconstruit sa géométrie à chaque image, trace par trace

### 1. Le code (vérifié, les numéros sont exacts)

```gdscript
# son_visible_vue.gd:212-222 — tant qu'une trace vit, un redessin complet à chaque image rendue
func _process(delta):
	…
	for i in range(_traces.size() - 1, -1, -1): … age += delta …
	if _traces.is_empty(): set_process(false)
	_toile.queue_redraw()
# son_visible_vue.gd:250-288 — par trace
var etat := SonVisible.etat(t, float(t["age"]))                       # 1 Dictionary de 6 clés
var b := SonVisible.bande(origine, angle, etat["largeur"], cadre, …)  # 1 Dictionary + 4 Packed* + 1 Array[float] trié
var points := PackedVector2Array(); var couleurs := PackedColorArray(); var indices := PackedInt32Array()
for i in n:      …  6 append dont 3 Color(couleur, a) …
for i in n - 1:  indices.append_array([a, a+1, s, a+1, s+1, s, a+1, a+2, s+1, a+2, s+2, s+1])   # un littéral Array de 12 entiers PAR SEGMENT
RenderingServer.canvas_item_add_triangle_array(toile_rid, indices, points, couleurs)             # un polygone moteur PAR TRACE
# son_visible.gd:717-746 (bande) — n = max(2, ceil(largeur/3°)) ; par échantillon point_du_bord() (:690) + profil() (:373) + 3 append
```

Allocations par trace et par image : ~11 fixes **+ (n − 1) littéraux `Array`** — l'auditeur compte « ~10 » : c'est le fixe ; les littéraux de 12 entiers, un par segment (jusqu'à 60), sont la plus grosse part des allocations. Échantillons par trace : `n + 1` (+ ≤ 4 coins) : 5 à 10°, 16 à 45°, 31 à 90°, 43 à 125°, ~61 à 180°.

### 2. La fréquence : défaut ? appelants ? combien de traces ?

- **Dessiné par défaut : oui.** `son_visible_actif` (game_state.gd:365) n'est faux qu'avec `--sans-son-visible` **en build de débogage** ; en release il est toujours vrai ; aucun réglage joueur (Q51, ROADMAP l. 2478). Hors traces vivantes : `set_process(false)` et `_dessiner` sort sur `_traces.is_empty()` — coût nul.
- Chaîne : `AudioManager.play_sfx_2d` → `_annoncer` (audio_manager.gd:1632, **avant** le choix de voix : un son sans voix libre trace quand même) → signal `son_localise` → `GameState._sur_son_localise` (game_state.gd:6194 ; trois rayons d'occultation par vue, seulement en image de physique) → `SonVisibleVue.recevoir` (:150). Seules les vues **rendues** ont un appareil actif (en vue unique, l'autre est vidée).
- Qui trace pour la vue V : tout son localisé dont l'émetteur n'est pas V et à plus de 24 px — donc pas, tirs, douilles, frôlements, rechargements de l'adversaire ; **et les impacts/ricochets de tout le monde** (`play_wall_impact(pos)` et `play_ricochet(pos)` n'ont **pas** de paramètre `emetteur` ; `play_hit` en a un, mais `bullet.gd:461, 674` ne le passent pas : -1), y compris ceux des balles de V lui-même. Un Terrassier tire 5 plombs (`spread_angles_deg` = [0, ±20, ±60], game_state.gd:553) : jusqu'à 5 impacts par volée.
- Durées de vie (ROADMAP l. 30232-30239, calculées sur les fichiers) : tir de pistolet 0,40–0,73 s, fusil 0,48–0,82, pompe 0,68–1,23, **impact de mur 0,19–0,47 s** (sa bande passe de 11° à 125° en 0,3 s dans la salle par défaut, 164° en 0,4 s dans un hangar), pas de course 0,20–0,23 s, pas accroupi 0,15–0,18 s.

**Combien de traces au pire cas d'un échange** (compté à partir des cadences — `cooldown` et chargeur, game_state.gd:516-570 et 5165-5243 — et des durées ci-dessus ; ESTIMÉ à ± 3 traces) :

| Situation (vue de V, duel) | Composition | Traces vivantes |
|---|---|---|
| échange léger | 2 pas + 1 tir | 3–4 |
| rafale de pistolet adverse (6 coups en 0,8 s) | ~4 tirs + 2 douilles + 4 impacts + 1–2 pas | 10–12 |
| le scénario « fusillade » du propre banc d'images (`banc_son_visible.gd:312`) | 1 tir, 5 impacts, 2 ricochets, 1 coup au but, 2 pas | **11** |
| volée de pompe contre volée de pompe | 1 tir + 1 douille + 10 impacts (5 + 5) + 1 pas | 13 (jusqu'à ~20 si deux volées se chevauchent) |
| rafale d'Occulteur (8 coups en 0,72 s, cooldown 0,09) + riposte | ~7 tirs + 5 douilles + 8 impacts + 1 pas | **20–24**, ≈ 0,3 s |
| plafond dur `TRACES_MAX` | | 48 par vue (hors d'atteinte en duel ; atteignable en salle de solo où les tirs de PNJ portent ×3 et ne sont jamais étouffés — non évalué) |

### 3. Le coût — et la donnée du coordinateur

**La mesure de la ROADMAP ne tranche pas ce coût.**
- « La vie d'un liseré se calcule en 0,02 à 0,08 ms par événement […] ; elle se relit en 5 µs par trace et par image » (ROADMAP l. 30287-30288) : « elle » est la **vie** — c'est `SonVisible.etat()` (un `Dictionary`, deux `_lire`, `presence_de`, deux `pow`). Ce n'est ni `bande()` ni l'assemblage de `_dessiner()`, qui coûtent **par échantillon**. Appliquer 5 µs « par trace » donnerait 0,055 ms pour 11 traces, 0,11 ms pour 22, 0,24 ms pour 48 : c'est le coût de la seule lecture de la vie, soit 10 à 25 fois moins que le dessin complet des mêmes traces (tableau ci-dessous). La ROADMAP ne dit pas si ces 5 µs sont mesurés ou calculés.
- La ligne « son visible : +4,0 ms, bruit » (l. 30506, série `decomp1`) ne dit rien du dessin : la ROADMAP note elle-même, pour cette série, **« aucun liseré dessiné »** (l. 30467-30468, 2466) ; et à ~515 ms l'image sous llvmpipe, le bruit (± 1,5 %) vaut ± 8 ms : un coût CPU de 1–2 ms y serait de toute façon invisible. La l. 31015 citée par le lecteur R8 est le tableau du coût de la bouffée de Q58 (fusée), pas du liseré.

**Mon estimation** (ESTIMÉ, par comptage d'opérations ; calibrée sur deux points du dépôt : 5 µs pour `etat()` ≈ 65 opérations riches en dictionnaires, et `fusee.gd:339`, 8,5 ms pour 49 152 itérations d'une boucle de ~26 opérations dont ~14 appels natifs ≈ 0,17 µs/itération, soit ~7 ns/opération sur la machine de la revue, non précisée) :
- par échantillon (un rayon) : `bande` ≈ 120 opérations (dont `point_du_bord` ≈ 50, `profil` ≈ 25) + `_dessiner` ≈ 65 (6 `append`, 3 `Color()`, un littéral `Array` de 12 entiers + conversion) ⇒ **≈ 1,5 µs (M3) à ≈ 5 µs (cœur x86 du conteneur)** — l'auditeur annonce 3–8 µs : même ordre, ma borne basse est plus basse ;
- par trace : fixe ≈ 10–15 µs (`etat`, 7–11 allocations, un polygone moteur) + échantillons ⇒ trace nette de 10° : 20–40 µs ; à 45° : 35–95 µs ; impact à 125° : 75–230 µs ; 180° : 100–320 µs.

| Situation | Échantillons Σ (estimés) | Coût par image |
|---|---|---|
| échange léger (3–4 traces) | ~40 | 0,1–0,25 ms |
| rafale de pistolet (10–12) | ~230 | **0,5–1,4 ms** |
| volée de pompe contre pompe (13) | ~350 | 0,7–1,9 ms |
| rafale d'Occulteur (22) | ~460 | 0,9–2,6 ms |
| hors échange | 0 | **0** |

… seulement pendant ~0,3–0,5 s après chaque salve, 0 le reste du temps. La plage de l'auditeur (« 0,1 à 1 ms dans un échange dense ») est juste pour le pistolet et un peu basse pour la pompe et l'Occulteur, où les impacts élargis (125°) pèsent le plus. **Côté moteur** : un polygone par trace ⇒ T appels de dessin par image au lieu d'un ; en compatibilité chaque `canvas_item_add_triangle_array` crée ses tampons GL, libérés au redessin suivant (connaissance du moteur, non mesuré). Les événements eux-mêmes (`_sur_son_localise`, `vie_de` 0,02–0,08 ms, trois rayons) restent négligeables : quelques dixièmes de ms par seconde.

Pourquoi cela compte malgré tout : ce sont précisément les images d'échange qui font le « 1 % bas ».

### 4. Les invariants

- **Pixel-identique** : fusionner toutes les traces en un seul `canvas_item_add_triangle_array` (mélange additif, donc commutatif, sommets et couleurs inchangés) ; remplacer le littéral `[a, a+1, …]` par un motif d'indices pré-calculé (`static var`) ou écrit par index ; `bande()` jumelle qui remplit des tableaux de l'appelant. Les suites `test_son_visible` (354) et `test_son_visible_jeu` (96) testent le modèle (`traces()`, angles, vie) et l'équité miroir (J1 à +d / J2 à −d voient le même liseré) : elles ne lisent pas ce chemin de dessin — à vérifier par `grep` avant de toucher `bande()` (ne pas en changer le défaut `pas_deg = 3.0`).
- **Change des pixels** (à juger sur images par Adrien, `tools/banc_son_visible.gd`) : pas angulaire adaptatif (≥ 6° au-delà de 60°) — à passer **depuis `_dessiner`**, pas par le défaut de `bande()` ; plafond d'échantillons par image.
- Équité : le liseré est calculé de la même façon dans les deux vues ; aucun changement ne doit dépendre de la caméra locale. Le fil et les bancs déterministes ne sont pas touchés (affichage pur).

### 5. Le statut

NOUVEAU. Contexte : ROADMAP l. 30287-30288 (coût de la vie seule), l. 2466 et 30467-30468 (« aucun liseré dessiné » dans les séries de la 0.8.0), l. 30183-30186 (ligne « Son visible » du banc : `recus_compte`). Non couvert par OM6.

### 6. Le verdict

**CONFIRMÉ AVEC RÉSERVE.** Le mécanisme est PROUVÉ (le code reconstruit tout, à chaque image, trace par trace, par défaut) ; le chiffre ne l'est pas. Sévérité : **MINEUR** — coût nul hors échange, ≈ 0,5–1,5 ms pendant une demi-seconde après une salve dense. L'auditeur plaçait la frontière MINEUR/MAJEUR à 0,3 ms en échange dense ; mon estimation (0,5–1,4 ms) est au-dessus, ce qui plaiderait pour MAJEUR. Je retiens MINEUR parce que la fenêtre est de 0,3–0,5 s par salve (zéro ailleurs) et que mon incertitude est de ×2 ; la mesure tranchera (MAJEUR si le micro-banc dépasse ~1,5 ms en échange dense).
**Correctif minimal** : un seul `canvas_item_add_triangle_array` par image + motif d'indices partagé (pixel-identique, effort M) ; puis, seulement si la mesure le justifie, le pas adaptatif (S, à juger sur images).
**Preuve dans le cloud** : micro-banc headless (le rendu factice ignore `canvas_item_add_*`, ce qui isole la part GDScript) — instancier `son_visible_vue.gd` dans un arbre, un `Node2D` pour regardeur, injecter via `recevoir()` des événements synthétiques donnant 3, 11, 22 traces de largeurs 10°/45°/125°/180°, chronométrer 1 000 appels de `_dessiner()` (`Time.get_ticks_usec`), imprimer µs/trace et µs/échantillon, plus Σ échantillons par image et Σ littéraux `Array`. Compteur indépendant du matériel : appels de dessin (`RENDER_TOTAL_DRAW_CALLS_IN_FRAME`) pendant le scénario « fusillade » du banc : T → 1 après le correctif. La série llvmpipe de `tools/cadence_cloud/` ne peut pas voir 1–2 ms (image de 300–600 ms, bruit ± 8 ms) : ne pas s'y fier pour ce poste.

---

## GAD-01 — la fumée de la fusée (≈ SHA-11, SHA-09 pour la partie CPU)

### 1. Le code (vérifié)

- `fusee.gd:262-295` : trois nappes (deux en écran scindé) et un voile 2D par fusée, rendus dans la lightmap ; `fusee_modele.gd:108-113` : `RAYON_FUMEE 200`, `NAPPES_PAR_DEFAUT 3`, `FUMEE_GONFLE 1,25`.
- `iso_volumes.gd:493-504` : `_suivre_fusee` → `_suivre_fusee_en_voxels(f, vus)` (:1570-1583) **sans test de visibilité** ; pour chaque vue, `IsoNuageVoxel.poser_fusee(m, …)` (iso_nuage_voxel.gd:648-676) pousse ≈ 16 `set_shader_parameter` + 15 `get_shader_parameter` + un `PackedVector3Array`. `fumee_voxel := true` par défaut (iso_volumes.gd:175) ; `--fumee-couches` rend l'ancien chemin.
- Aucun plafond ni niveau de détail sur le nombre de nuages (recherche de « plafond/max/lod » dans `iso_volumes.gd` et `iso_nuage_voxel.gd` : seuls les plafonds de longueur du faisceau).

### 2. La fréquence

Une fumée existe de l'atterrissage à la fin du résidu : 20 s de vie (plein feu 4 s + braise 8 s + agonie 3 s + résidu 5 s, `fusee_modele.gd:35-57`) ; par image et par vue rendue. Stocks de fusées par classe (game_state.gd:5129-5251) : pistolet 1, fusil 1, **pompe 3** (recharge 18 s), arbalète 1, fumiste 1, **incendiaire 2**, sentinelle 1, occulteur 1, **allumeur 2** (12 s), spectre 0 ; recharge 60 s pour les autres. Donc, en duel : **N = 1–2 fusées vivantes en pratique** (une par joueur), 3–5 avec Terrassier/Incendiaire/Allumeur au début d'une manche.

### 3. Le coût — ce que les passages de la ROADMAP établissent, et ce qui n'a jamais été fait

- **l. 28258-28299 (M3, vue unique, `2f06b1b`, fumée en COUCHES)** : une fusée = **3,39 ms/image**, dont volume de fumée iso 2,66 ms (78 %), nappes + voile 2D 0,69–0,76 ms, lumière 2D 0,09, ombre 0,09, lueurs 0,00, résidu 0,15 ms (capteur + voxel de la fusée compris) ; trois pistes « fermées » (passe d'ombre, lumière, lueurs) ; 1 % bas hors chauffe 84,8 → 70,1. Les deux économies chiffrées (« jeter avant de lire » ≈ 0,57 ms, « réutiliser la lecture centrale » ≈ 0,27 ms) visent `volume_iso.gdshader` — **qui n'est plus le chemin par défaut** depuis la 0.8.1 : elles sont caduques, sauf sous `--fumee-couches`. « Aucune appliquée » est donc devenu sans objet.
- **l. 2455 (0.8.1)** : « Non mesuré sur le Mac : la fumée en cubes coûtait 7 à 9 % de temps en moins que les couches dans le cloud (GV1bis), l'allumage de la fusée 2 % de plus pendant ses 3 s (Q58) ».
- **l. 31299-31302 et 31445-31447** : « Ce que le cloud ne peut pas dire » (temps d'image sous le pilote d'Apple, sommets des cubes, hoquet de la première compilation) — écrit comme « la limite de la preuve, pas une étape demandée ». Et depuis le 2026-09-30 (l. 2467) plus aucune mesure sur le Mac d'Adrien.
- Chiffres du cloud (releves_gv1bis_cout.txt) : surface couverte ×0,40 vs couches (fusée : 563 450 fragments en J1 + 602 967 en J2 contre 1 398 150 + 1 500 695 ; **9 136 cubes par vue**, 18 272 pour deux), temps llvmpipe ×0,92 ; SHA-11 : ≈ 110 000 sommets par vue et par fusée, ≈ 0,2 % du GPU d'un M3 (ESTIMÉ, négligeable) ; le « juge » du nuage est la plus grosse part des fragments (842 803 sur 1 193 452).

**Estimation de la forme voxel sur M3** (ESTIMÉ, fragile — dérivée de deux mesures, pas mesurée) : volume 2,66 ms × 0,40 de surface ≈ 1,1 ms, + nappes/voile 2D ≈ 0,7 ms, + lumière/ombre 0,18 ms, + capteur/voxel 0,15 ms, + CPU d'uniformes ≈ 0,02–0,05 ms ⇒ **≈ 2 ms par fusée, ± 50 %**. Si le coût s'additionne : N = 2 ≈ 4 ms (1 % bas ≈ 63 fps à partir des 11,8 ms de la base à 84,8 fps), N = 3 ≈ 6 ms (≈ 56 fps, sous la cible) ; en couches la même arithmétique donne 70,1 fps à N = 1, ≈ 60 à N = 2 (+2,5 ms de 1 % bas par fusée). ⚠️ Cette base (2026-09-23) précède les ajouts de la 0.8.0 (le candidat, avant l'allègement, mesurait 1 % bas 46–47 sous une fusée, l. 30467) : la marge réelle d'aujourd'hui est inconnue. Correction à l'auditeur : « poussées d'uniformes 60–100 µs par fusée et par vue » est trop haut ; SHA-09 compte ≈ 0,5 µs par appel, soit **≈ 15–40 µs** — le gain CPU de « ne pas pousser hors champ » est ≈ 0,02–0,05 ms par fusée, pas 0,1.

### 4. Les invariants

- Toute dégradation doit dépendre d'un état **partagé** (nombre de fusées vivantes), jamais de la caméra locale : sinon J1 et J2 ne voient pas la même cachette ; `occultation_pour` (la règle) lit l'état 2D, pas les uniformes. La lisibilité de la lumière et « les cubes à encre » (Q73 volutes) sont de l'identité : décision d'Adrien.
- Ne pas pousser les uniformes d'une fusée hors cadre : sans risque (pas d'incidence sur le jeu) à condition de les repousser avant sa rentrée à l'écran (marge) ; `test_fumee_voxel` garde l'image.
- Le hoquet du premier nuage (grille de cubes bâtie en GDScript, shader compilé au premier dessin) est un autre constat (GAD-05, GEO-04, SHA-01) : ne pas le confondre.

### 5. Le statut

CONNU-OUVERT : mesure de la forme en couches faite (l. 28258-28299) ; forme voxel mesurée **seulement** en relatif dans le cloud (l. 31399-31429) ; limite « non mesuré sur le Mac » écrite (l. 2455, 31299-31302, 31445-31447) ; aucune étape ne la reprend. Non couvert par OM6 (qui traite lumières, capteurs, murs).

### 6. Le verdict — ce qui reste réellement à faire

**CONFIRMÉ AVEC RÉSERVE.** MAJEUR (potentiel) : le plus gros coût **identifié** par objet du jeu, additif par fusée ; mais **non prouvé sous la forme voxel** et plausiblement tenu pour N ≤ 2. Ce qui reste, dans l'ordre, et uniquement dans le cloud (plus aucune mesure Mac) :
1. **La série N = 1…3 qui n'a jamais existé** : `bench_framerate.gd` ne pose qu'une `FuseeBanc` (:1068-1075) ; ajouter `--fusees=N` (positions distinctes, âge tenu). Compteurs indépendants du matériel : fragments, primitives et appels de dessin par `banc_gadgets_volume.tscn -- --mode=cout` avec N nuages (attendu : ≈ N × 0,56 M fragments par vue, + recouvrement) ; relatif llvmpipe voxels contre `--fumee-couches`, miroir A B B A, pour l'additivité — pas des ms Mac.
2. **Le CPU headless** : chronométrer `IsoVolumes._suivre_fusee_en_voxels` + `Fusee._appliquer_age` pour N fusées sur 1 000 images (`Time.get_ticks_usec`) ; ça tranche les « 15–40 µs » contre « 60–100 µs ».
3. **Seulement si 1. montre > ~1,5–2 ms par fusée supplémentaire** : le plafond / niveau de détail (décision d'Adrien, déclencheur partagé) ; la poussée d'uniformes hors cadre est un geste S sans effet visuel, à faire avec 2.
Sévérité : MAJEUR conditionnel à N ≥ 3 ; la décision d'agir ne peut pas être prise sans 1.

---

## GAD-12 — capteurs de lumière des objets posés (= ISO-06 ; recoupe LUM-03)

### 1. Le code (vérifié)

```gdscript
# capteur_corps.gd:88-91
c.size = Vector2i(TAILLE, TAILLE)                       # 256
c.canvas_cull_mask = couche
c.render_target_update_mode = SubViewport.UPDATE_ALWAYS
# miroirs_iso.gd:227-246 — un capteur PAR VUE de `vues` pour chaque objet miroité (mine, ombre, torche fantôme, voile, grésillement, leurre, fusée posée)
for id in vues: … var c := CapteurCorps.creer(id, 0, main.vp1.world_2d, couche_objets(id), masque, …)
# miroirs_iso.gd:264-287 — _poser ne fait que cacher le disque : (c as CapteurCorps).suivre(pos, noeud.is_visible_in_tree())
# presentation_3d.gd:1198-1199 — le garde de distance, posé pour les seuls figurants (PORTEE_CAPTEUR_FIGURANT_PX = 1300, :161)
(capteur as CapteurCorps).render_target_update_mode = SubViewport.UPDATE_ALWAYS if proche else SubViewport.UPDATE_DISABLED
```

### 2. La fréquence

Par image rendue, tant que l'objet existe ; au plus **un gadget debout par joueur + les fusées posées** (donc 0–4 en pratique, ≤ 8 au plafond) × 1 vue (vue unique) ou 2 (écran scindé). Aucun arrêt hors cadre.

### 3. Le coût

Une passe de 256² par objet et par vue : changement de cible + rassemblement des lumières dont le rectangle croise la fenêtre de 128 px (la règle du moteur : l'ombre de ces lumières est recalculée sans qu'un élément la reçoive). Seule mesure : le **résidu de 0,15 ms** pour UNE fusée, capteur **et** voxel compris (mesure_fusee.md, M3). ESTIMÉ ≤ 0,05–0,15 ms par objet et par vue ⇒ 0,1–0,4 ms avec 2–4 objets. ISO-06 dit ≤ 0,3 ms ; LUM-03 le range dans la passe d'ombre quadratique des salles. Création (second point de GAD-12) : sous-vue, caméra, polygone de 32 sommets, matériau, `rapprocher_tout` dans l'image de la pose / de l'atterrissage / de la copie de killcam : ESTIMÉ 0,3–1 ms par capteur, non mesuré.

### 4. Les invariants

Noir absolu et équité de lecture : un capteur arrêté garde sa dernière valeur ; il doit être réarmé **avant** que l'objet n'entre à l'écran. Gardes : `tools/banc_iso.gd --canaux`, `test_ombre_propre`, `test_iso_vues`, `test_iso_gadgets`. Deux faits à ajouter à OM6 : (a) avec `UPDATE_WHEN_VISIBLE`, un `SubViewport` n'est mis à jour que si sa texture a été **échantillonnée à l'image précédente** (connaissance du moteur, à vérifier au banc) : à l'entrée d'un objet dans le cadre il y a donc une image de retard sur une valeur périmée — à prendre en compte, ou préférer le garde de distance (1 300 px) qui réarme d'avance ; (b) le garde du cas killcam (objets recréés, `is_replay`).

### 5. Le statut

**DÉJÀ PRIS EN CHARGE** : OM6, première puce — « les capteurs en `UPDATE_WHEN_VISIBLE` (ceux des joueurs et des figurants dans `presentation_3d.gd`, **ceux des objets dans `miroirs_iso.gd`**) » (ROADMAP de la branche OMBRES, section OM6 ; `CONTEXTE_CHANTIERS_EN_COURS.md`). Doublon exact : ISO-06 (« capteurs d'objets jamais arrêtés hors écran », même proposition de garde de distance). Recoupe LUM-03, qui cite `miroirs_iso.gd:241` dans sa passe d'ombre `4 × N × L` répétée dans chaque capteur. Ce que le chantier OMBRES n'écrit pas : le coût de **création** des capteurs (pas de pool).

### 6. Le verdict

**DÉJÀ PRIS EN CHARGE.** MINEUR. À ne pas proposer comme neuf ; l'audit n'y touche pas (fichiers d'une autre session). Apport à OM6 : le décompte (objets × vues), les deux risques du 4., et le compteur de preuve : nombre de `CapteurCorps` en `UPDATE_ALWAYS` par scénario (groupe `EtoileDeCorps.GROUPE_CAPTEURS`) et `RenderingServer.viewport_get_measured_render_time_cpu` par capteur sous Xvfb/llvmpipe (doit tomber à 0 pour les capteurs hors cadre). Une mine posée à 1 500 px du joueur est le cas d'essai.

---

## AUD-04 — « 40 sons positionnels importés en stéréo »

### 1. Le code / les fichiers

Comptes par `grep` ciblé sur les `.import` : `sfx/` **4 mono / 60 stéréo** ; `weapons/` **20 mono / 4 stéréo**.
- Mono : `flesh_impact`, `footstep`, `wall_impact`, `weapon_shoot` ; les 16 tirs et 4 clics à vide d'armes.
- Stéréo positionnels : la liste de l'auditeur est exacte (40 : `ambience` ×8, `bolt_flight`, `breath_hit` ×6, `footstep_a/b` ×8, `fusee_*` ×5, `hit_center/edge`, `ricochet` ×3, `shell` ×4, `wall_brush` ×3) — et il y en a **46** : s'y ajoutent `torch_on/off` (positionnels pour les PNJ) et les **4 `weapon_reload_*`** de `weapons/` (importés stéréo, joués en positionnel). Les 18 autres stéréo de `sfx/` sont de l'interface (non positionnels).
- Toutes à 48 kHz, 16 bits (`stereo_sfx.py`).

### 2. La fréquence

Un son positionnel par événement (pas, tir, impact…) : voix du pool de 16 ; les stéréo en occupent les plus nombreuses (pas, douilles, frôlements).

### 3. Ce que la stéréo change réellement — **les sources, mesurées** (`v5_work/stereo_sfx.py`)

Sur les 40 de la liste : **29 ont L et R strictement identiques** (`ambience` ×8, `bolt_flight`, `breath_hit_06`, `footstep` ×8, `fusee_atterrit/eteinte/combustion`, `hit_center/edge`, `shell_01-03`, `wall_brush` ×3) ; **8 sont presque identiques** (rapport d'énergie côté / milieu < 0,001, soit < −30 dB : `breath_hit_01-05`, `fusee_lancer`, `fusee_rebond`, `shell_04`) ; **3 seulement** ont un vrai écart : `ricochet_01` −20 dB, `ricochet_02` −17,6 dB, `ricochet_03` −28,8 dB. Hors liste : `weapon_reload_arbalete.wav` est un **vrai stéréo** (côté/milieu 0,74), les trois autres recharges sont en double mono.
Dans Godot 4.7, pour un `AudioStreamPlayer2D` le panoramique est un gain par canal de sortie appliqué au signal du flux : avec L = R, un flux stéréo se joue **exactement** comme le mono (même gain gauche et droite que le mixeur applique au mono dupliqué) ; avec L ≠ R, la différence entre canaux survit au panoramique et élargit la source — c'est le « dilue le panoramique » de la ROADMAP, vrai uniquement pour les fichiers dont les canaux diffèrent. (Mécanisme de mixage : connaissance du moteur, non relue dans ses sources ici ; si le moteur sommait les canaux avant de panoter, la stéréo ne changerait rien du tout — dans les deux cas le résultat est identique pour 37 des 40.)
Coût de l'import stéréo : mémoire QOA ≈ 3,2 bit/échantillon/canal ⇒ ≈ 34 s de sons positionnels (46 fichiers) ≈ 1,3 Mo en stéréo contre ≈ 0,65 Mo en mono : **≈ 0,65 Mo** ; décodage ×2 d'un flux QOA (le mixeur travaille de toute façon en `AudioFrame` stéréo) : négligeable.

### 4. Les invariants

`enveloppes_sons.py` calcule l'enveloppe du liseré sur les **sources** (empreinte SHA-256, `test_enveloppes_sons`) : un changement de `.import` ne la touche pas. `force/mono=true` sur un double mono est l'identité ; sur `ricochet_*` (−18 à −29 dB de côté) et `weapon_reload_arbalete` (vrai stéréo, somme en mono = timbre et niveau qui bougent) il faut repasser au banc (`tools/banc_audio.tscn`, `banc_mixage`) avant de les inclure.

### 5. Le statut

Principe DÉJÀ-TRANCHÉ (ROADMAP l. 11166-11169 et 15456-15458 : tirs « forcés en mono à l'import »). L'écart (livraisons du 2026-08-27 et suivantes restées en stéréo) est NOUVEAU, mais **sans effet de localisation mesurable** pour 37 des 40.

### 6. Le verdict

**CONFIRMÉ sur le fait, RÉFUTÉ sur l'enjeu** : la localisation n'est pas diluée, parce que les fichiers sont du double mono. ANECDOTIQUE (≈ 0,65 Mo, aucun effet audible). **Correctif minimal** si l'on veut aligner l'import sur le principe : `force/mono=true` sur les 29 + 8 fichiers de la liste dont les canaux sont (quasi) identiques — effet nul à l'oreille, gain mémoire — et décider au banc pour les 3 ricochets et la recharge d'arbalète. Pas de priorité.
**Preuve** : `python3 audit/v5_work/stereo_sfx.py` (déjà fait) ; A/B au banc audio pour les 4 fichiers à vrai stéréo.
