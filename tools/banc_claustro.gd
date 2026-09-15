## Banc des variantes de la caméra serrée — FENÊTRÉ (chantier ISO, étape ISO8, étape 1).
##
## Brief `briefs/iso8_claustro.md` de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED » (2026-09-15, 12:25),
## sur mandat d'Adrien de 12:20 : « Si tu juges qu'il faut changer les proportions, zoomer dans le jeu,
## réduire la taille des cônes de lumière pour le rendre plus claustrophobique, n'hésite pas. »
##
## **Aucun réglage par défaut n'est choisi ici.** Le banc photographie la même scène sous chaque variante ;
## la session cloud choisit sur image (planche `docs/iso/planche_iso8_variantes.jpg`), puis l'étape 2 fixe
## le défaut. Rien n'est écrit dans `settings.cfg`, rien dans les données de classe : les variantes sont posées
## sur les objets en mémoire le temps d'une prise, puis rendues.
##
## ## Les variantes
##
## - **zoom** ×1,0 (témoin), ×1,5, ×1,8, ×2,2 — posé sur `cam1` et `cam2` à chaque image. La vue iso suit le
##   `canvas_transform` de la vue regardée, zoom compris (ISO1 : taille orthographique = hauteur 2D / zoom ×
##   sin θ) : elle se serre d'elle-même.
## - **portée** `torch_scale` 1,6 (témoin), 1,2, 1,0 — portée de 410, 307 et 256 px (`portee_torche()`).
## - **demi-angle** 35° (témoin, le pistolet) et 30° : **le cookie du Fumiste**, cuit à 30° par la même
##   chaîne que celui du pistolet (`tools/fabrique_cookies.gd`, planche `bis04`). Recuire la planche sans les
##   curseurs exacts de `bis04` changerait la texture EN PLUS de l'angle, et la comparaison ne dirait plus
##   ce qu'elle mesure. Pris au zoom ×1,8 seulement, pour les trois portées.
##
## ## La scène
##
## - **Carte d'essai des murs bas** (`tools/cartes/murs_bas_essai.json`) : elle n'a aucun mur haut
##   intérieur. J1 à 3,5 tuiles de la face sud de la bordure nord, visée au nord ; J2 au sud du muret
##   horizontal le plus au nord, dos à J1 (la scène du photographe d'ISO6).
## - **Le Cloître** (`assets/maps/map_001_le_cloitre.json`, 48 cases de murs hauts intérieurs) : J1 à
##   3,5 tuiles au sud du plus large mur haut intérieur dont les deux côtés sont dégagés, visée au nord ; J2
##   à 1,2 tuile au nord du même mur, dos à lui — le mur coupe leur ligne (vérifié par un rayon).
## - Les deux joueurs tiennent leur torche (un fournisseur d'entrées du banc), sont replacés et gardés en vie
##   à chaque image ; interface cachée. Vue unique (J1 regardé), puis écran scindé.
##
## Relevés : une ligne `BANC_CLAUSTRO …` par prise (zoom, portée, demi-angle, taille de la lightmap, appels de
## dessin, vue iso tenue) ; captures `<carte>_<vue>_z<zoom>_t<portée>[_a30].png` dans `--captures`.
##
## Lancer (vraie fenêtre, chien de garde à la main — pas de `timeout` sur ce Mac) :
##   godot --path . res://tools/banc_claustro.tscn -- --captures <dossier absolu>
extends Node

const CARTES := [
	{"nom": "murs_bas", "chemin": "res://tools/cartes/murs_bas_essai.json"},
	{"nom": "cloitre", "chemin": "res://assets/maps/map_001_le_cloitre.json"},
]
const ZOOMS := [1.0, 1.5, 1.8, 2.2]
const TORCHES := [1.6, 1.2, 1.0]
const ZOOM_ANGLE := 1.8
const ANGLE_ETROIT := {"cookie": "fumiste", "demi_angle": 30.0}
const TAILLE := Vector2i(1920, 1080)
const IMAGES_DE_REPOS := 24


## Les deux joueurs tiennent leur torche, ne bougent pas, visent où le banc le dit.
class Pantin extends InputProvider:
	var visee := Vector2.UP

	func get_movement_vector() -> Vector2:
		return Vector2.ZERO

	func get_aim_direction(_pos: Vector2) -> Vector2:
		return visee

	func is_shoot_pressed() -> bool:
		return false

	func is_flashlight_pressed() -> bool:
		return true

	func is_flare_pressed() -> bool:
		return false

	func is_reload_pressed() -> bool:
		return false


var _main: Node
var _ui: Node
var _dossier := ""
var _pantins: Array = []
var _zoom := 1.0
var _scene := {}
var _armes := {}
var _echecs := 0
var _prises := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--captures")
	if i < 0 or i + 1 >= args.size():
		printerr("✗ banc_claustro : --captures <dossier absolu> est obligatoire")
		get_tree().quit(2)
		return
	var refus := RenduCommun.refus_headless()
	if refus != "":
		printerr("✗ banc_claustro : ", refus)
		get_tree().quit(2)
		return
	_dossier = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_dossier)
	# Pour cette exécution seulement : rien ne s'écrit dans settings.cfg, et l'intro ne joue pas par-dessus
	# le duel (piège « un foyer isolé est un joueur neuf »).
	GameSettings.pilotage_externe = true
	GameSettings.intro_vue = true
	GameSettings.mode_iso = true
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().size = TAILLE
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	AudioServer.set_bus_mute(0, true)

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node("UI")
	_main.archiver_les_matchs = false
	_ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active and _main.countdown_left <= 0.0, 20.0):
		_echouer("la manche n'a pas démarré")
		_finir()
		return
	for j in [_main.p1, _main.p2]:
		var pantin := Pantin.new()
		pantin.name = "PantinDuBancClaustro"
		_main._set_player_input_provider(j, pantin)
		_pantins.append(pantin)
	_ui.visible = false
	print("=== Banc des variantes de la caméra serrée (ISO8, étape 1) ===")
	for carte in CARTES:
		await _une_carte(carte)
	_finir()


func _une_carte(carte: Dictionary) -> void:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(String(carte["chemin"]))) != OK or not (json.data is Dictionary):
		_echouer("carte illisible : %s" % carte["chemin"])
		return
	var data: Dictionary = MapCodec.validate(json.data as Dictionary)["data"]
	MapData.current_map_data = data
	_main.rebuild_arena()
	await _images(6)
	_scene = _mise_en_scene(data)
	if _scene.is_empty():
		_echouer("%s : aucune mise en scène (mur haut, sol dégagé des deux côtés)" % carte["nom"])
		return
	print("BANC_CLAUSTRO scene carte=%s j1=%s visee_j1=%s j2=%s visee_j2=%s (%s)" % [carte["nom"], str(_scene["p1"]),
		str(_scene["v1"]), str(_scene["p2"]), str(_scene["v2"]), _scene["mur"]])
	for vue in ["unique", "scinde"]:
		_poser_la_vue(vue == "scinde")
		for z in ZOOMS:
			for t in TORCHES:
				await _prendre(String(carte["nom"]), vue, z, t, false)
		for t in TORCHES:
			await _prendre(String(carte["nom"]), vue, ZOOM_ANGLE, t, true)
	_rendre_les_armes()


func _prendre(carte: String, vue: String, zoom: float, torche: float, etroit: bool) -> void:
	_zoom = zoom
	_armer(torche, etroit)
	for k in IMAGES_DE_REPOS:
		_tenir()
		await get_tree().process_frame
	_tenir()
	DisplayServer.window_move_to_foreground()
	var img: Image = await RenduCommun.capturer(get_tree(), 15000)
	if img == null:
		_echouer("%s %s z%.1f t%.1f : aucune image rendue en 15 s (fenêtre au second plan ?)" % [carte, vue, zoom, torche])
		return
	var nom := "%s_%s_z%.1f_t%.1f%s.png" % [carte, vue, zoom, torche, "_a30" if etroit else ""]
	img.save_png(_dossier.path_join(nom))
	_prises += 1
	var p := Presentation3D.instance()
	var iso_tenue := p != null and bool(p.get("_actif")) and bool(p.get("_scinde")) == (vue == "scinde")
	if not iso_tenue:
		_echouer("%s : la vue iso ne tient pas la configuration %s" % [nom, vue])
	var arme = _main.p1.get("current_weapon")
	var vp1: SubViewport = _main.vp1
	print("BANC_CLAUSTRO carte=%s vue=%s zoom=%.1f torche=%.1f demi_angle=%.0f portee_px=%.0f lightmap=%dx%d fenetre=%dx%d appels=%d iso=%s fichier=%s"
		% [carte, vue, zoom, torche, float(arme.torch_angle_deg), float(arme.portee_torche()), vp1.size.x, vp1.size.y,
		DisplayServer.window_get_size().x, DisplayServer.window_get_size().y,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"tenue" if iso_tenue else "ROMPUE", nom])


## Les joueurs replacés, leur visée reposée, gardés en vie ; le zoom posé sur les deux caméras — à CHAQUE
## image : le jeu replace ses caméras sur les joueurs, et un coup reçu dézoome brièvement (V4.6).
func _tenir() -> void:
	for pid in 2:
		var j: Node2D = _main.p1 if pid == 0 else _main.p2
		if not is_instance_valid(j):
			continue
		j.global_position = _scene["p%d" % (pid + 1)]
		j.set("velocity", Vector2.ZERO)
		(_pantins[pid] as Pantin).visee = _scene["v%d" % (pid + 1)]
		if not bool(j.get("dead")):
			j.set("hp", 100.0)
	for cam in [_main.cam1, _main.cam2]:
		if is_instance_valid(cam):
			(cam as Camera2D).zoom = Vector2(_zoom, _zoom)


## La portée et l'ouverture posées sur l'arme de chaque joueur ET sur sa lampe (`equip_weapon` recopie
## texture et échelle une fois ; rééquiper remettrait les munitions). Les valeurs d'origine sont gardées et
## rendues par `_rendre_les_armes`.
func _armer(torche: float, etroit: bool) -> void:
	for j in [_main.p1, _main.p2]:
		if not is_instance_valid(j):
			continue
		var w = j.get("current_weapon")
		if w == null:
			continue
		var id := (w as Object).get_instance_id()
		if not _armes.has(id):
			_armes[id] = {"arme": w, "torch_scale": w.torch_scale, "torch_angle_deg": w.torch_angle_deg,
				"torch_cookie": w.torch_cookie}
		var s: Dictionary = _armes[id]
		w.torch_scale = torche
		w.torch_cookie = String(ANGLE_ETROIT["cookie"]) if etroit else String(s["torch_cookie"])
		w.torch_angle_deg = float(ANGLE_ETROIT["demi_angle"]) if etroit else float(s["torch_angle_deg"])
		w.set("_torch_texture", null)
		w.set("_torch_image", null)
	for j in [_main.p1, _main.p2]:
		if not is_instance_valid(j):
			continue
		var w = j.get("current_weapon")
		var lampe := j.get("flashlight") as PointLight2D
		if w != null and lampe != null:
			lampe.texture = w.get_torch_texture()
			lampe.texture_scale = w.echelle_torche()


func _rendre_les_armes() -> void:
	for id in _armes:
		var s: Dictionary = _armes[id]
		var w = s["arme"]
		w.torch_scale = s["torch_scale"]
		w.torch_angle_deg = s["torch_angle_deg"]
		w.torch_cookie = s["torch_cookie"]
		w.set("_torch_texture", null)
		w.set("_torch_image", null)
	_armes.clear()
	for j in [_main.p1, _main.p2]:
		if is_instance_valid(j) and j.get("current_weapon") != null:
			var lampe := j.get("flashlight") as PointLight2D
			lampe.texture = j.current_weapon.get_torch_texture()
			lampe.texture_scale = j.current_weapon.echelle_torche()


func _poser_la_vue(scinde: bool) -> void:
	var c2 := _main.vp2.get_parent() as Control
	if c2 != null:
		c2.visible = scinde
	_main._accorder_rendu_aux_vues()


## La scène d'une carte : `{p1, v1, p2, v2, mur}`, ou vide si rien ne convient.
func _mise_en_scene(data: Dictionary) -> Dictionary:
	var tuile := Vector2(CandelaTileSet.TILE_SIZE)
	var t := tuile.y
	var grille := Vector2(MapCodec.get_grid_size(data)) * tuile
	var interieurs: Array[Rect2] = []
	for r in IsoGeometrie.rects_px(data, MapGeometry.Kind.WALLS, tuile):
		if r.position.x >= 3.0 * t - 0.5 and r.position.y >= 3.0 * t - 0.5 \
				and r.end.x <= grille.x - 3.0 * t + 0.5 and r.end.y <= grille.y - 3.0 * t + 0.5:
			interieurs.append(r)
	interieurs.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.size.x > b.size.x)
	for r in interieurs:
		if r.size.x < 2.0 * t:
			continue
		var p1 := Vector2(r.get_center().x, r.end.y + 3.5 * t)
		var p2 := Vector2(r.get_center().x, r.position.y - 1.2 * t)
		if _libre(p1) and _libre(p2) and _mur_entre(p1, p2):
			return {"p1": p1, "v1": Vector2.UP, "p2": p2, "v2": Vector2.UP,
				"mur": "mur haut intérieur %s" % str(r)}
	# Aucun mur haut intérieur (la carte d'essai) : la bordure nord et le muret le plus au nord.
	var muret := Rect2()
	for m in _main.murs_bas as Array:
		var rect := m as Rect2
		if rect.size.x > rect.size.y and (muret.size == Vector2.ZERO or rect.position.y < muret.position.y):
			muret = rect
	if interieurs.is_empty() and muret.size != Vector2.ZERO:
		return {"p1": Vector2(16.0 * t, 3.0 * t + 3.5 * t), "v1": Vector2.UP,
			"p2": Vector2(muret.get_center().x, muret.end.y + 32.0), "v2": Vector2.DOWN,
			"mur": "bordure nord, J2 derrière le muret %s" % str(muret)}
	return {}


func _libre(p: Vector2) -> bool:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var disque := CircleShape2D.new()
	disque.radius = 40.0
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = disque
	q.collision_mask = MapGeometry.WALL_LAYER
	q.transform = Transform2D(0.0, p)
	q.exclude = [_main.p1.get_rid(), _main.p2.get_rid()]
	return espace.intersect_shape(q, 1).is_empty()


func _mur_entre(a: Vector2, b: Vector2) -> bool:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b, MapGeometry.WALL_LAYER)
	q.exclude = [_main.p1.get_rid(), _main.p2.get_rid()]
	return not espace.intersect_ray(q).is_empty()


func _images(n: int) -> void:
	for k in n:
		await RenderingServer.frame_post_draw


func _attendre(condition: Callable, delai: float) -> bool:
	var fin := Time.get_ticks_msec() + int(delai * 1000.0)
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await get_tree().process_frame
	return false


func _echouer(raison: String) -> void:
	_echecs += 1
	printerr("  ✗ ", raison)


func _finir() -> void:
	if is_instance_valid(_main):
		_rendre_les_armes()
	print("BANC_CLAUSTRO VERDICT=%s prises=%d echecs=%d" % ["OK" if _echecs == 0 else "ECHEC", _prises, _echecs])
	get_tree().quit(0 if _echecs == 0 else 1)
