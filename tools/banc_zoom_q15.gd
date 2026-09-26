## Banc du zoom du duel, Q15 — FENÊTRÉ (session cloud « zoom », 2026-09-27).
##
## La seule question encore ouverte d'Adrien sur la caméra : garder ×1,5 (le défaut depuis ISO11, L3) ou un autre
## cadrage. Il veut juger sur image. **Ce banc ne change rien au jeu** : il pose le zoom sur `GameSettings` et sur
## les deux caméras 2D le temps d'une prise, comme `banc_claustro.gd`, et laisse le JEU placer ses caméras
## (`GameState._suivre_du_regard` : regard décalé vers la visée de 0,15 de la hauteur visible, bornes de la carte,
## lacet 45° option B). La portée des torches reste celle du jeu (facteur global ×0,75) : le zoom n'y touche pas.
##
## ## La scène, par carte
##
## J1 visée vers le HAUT de son écran (au lacet 45°, le monde tourné de −45°) : l'axe court de l'écran, le cas le
## moins favorable ; à la place où son cône est le plus dégagé (`_mise_en_scene`). J2 **au bord du cône** de J1 : à
## 0,8 de la portée du pistolet, à 15° à l'intérieur du demi-angle (le cookie s'éteint avant son demi-angle nominal
## et s'effile vers sa pointe : à 0,9 et 6° en dedans, J2 tombait dans le noir), sol libre et ligne de vue dégagée. J2 regarde
## de côté (perpendiculaire à la ligne J1 → J2) : sa torche ne touche pas J1.
##
## ## Par zoom (×1,25, ×1,5, ×1,75, ×2,0)
##
## ⚠️ **Le bandeau LED des murs (`MurLed`) respire toutes les 8,5 s** et, au sommet, éclaire le sol jusqu'à 157 px de
## chaque mur : la moitié d'une carte meublée. Pris au fil de l'eau, deux zooms tombaient à deux phases différentes et
## ne se comparaient plus (relevé par `--serie` : luminance moyenne ×4 en quatre secondes, rien d'autre ne bougeant).
## Le banc le FIGE (`MurLed._fige`, le levier de `--led-murs-fige`) : au creux (éteint) pour les prises comparées,
## au sommet pour une prise de plus en vue unique. Rendu à la respiration à la fin.
##
## - vue unique 1920×1080, interface cachée (le corps se mesure ensuite sur l'image, par la silhouette de soi de J1,
##   toujours dessinée : une différence d'images avec et sans J2 ne marche pas, la flamme des torches vacille) ;
## - écran scindé au même instant ;
## - les relevés, une ligne `BANC_ZOOM …` : empreinte au sol de la caméra iso de chaque joueur (quatre coins, en
##   pixels du monde), part de la carte visible, distance visible devant / derrière / sur les côtés, corps projeté,
##   torche projetée, qui a l'autre à l'écran. L'empreinte de J1 est celle de la VRAIE caméra iso ; celle de J2,
##   dont la caméra n'existe pas en vue unique, est recalculée par les mêmes formules (`RegardDuel`,
##   `CameraIso.transform_pour`) comme sur son propre écran 1920×1080 en ligne — et la même formule appliquée à
##   J1 est comparée à la vraie caméra (écart imprimé).
##
## Lancer (vraie fenêtre ; sous Xvfb, `--fixed-fps 60` : les attentes sont comptées en images de jeu) :
##   godot --fixed-fps 60 --path . res://tools/banc_zoom_q15.tscn -- --captures <dossier absolu>
extends Node

const CARTES := [
	{"nom": "cloitre", "chemin": "res://assets/maps/map_001_le_cloitre.json"},
	{"nom": "croisee", "chemin": "res://assets/maps/map_003_la_croisee.json"},
]
const ZOOMS := [1.25, 1.5, 1.75, 2.0]
const TAILLE := Vector2i(1920, 1080)
## Le regard se lisse sur ~120 ms (`RegardDuel.lisser`) : 90 images de jeu pour qu'il ait fini son chemin.
const IMAGES_DE_REPOS := 90
## Le corps, tel que la présentation iso le dimensionne (`Presentation3D`).
const RAYON_CORPS := 14.0
const HAUTEUR_CORPS := 35.0


class Pantin extends InputProvider:
	var visee := Vector2.UP
	var torche := true

	func get_movement_vector() -> Vector2:
		return Vector2.ZERO

	func get_aim_direction(_pos: Vector2) -> Vector2:
		return visee

	func is_shoot_pressed() -> bool:
		return false

	func is_flashlight_pressed() -> bool:
		return torche

	func is_flare_pressed() -> bool:
		return false

	func is_reload_pressed() -> bool:
		return false


var _main: Node
var _ui: Node
var _dossier := ""
var _pantins: Array = []
var _zoom := 1.5
var _scene := {}
var _echecs := 0
var _prises := 0
var _carte := Rect2()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--captures")
	if i < 0 or i + 1 >= args.size():
		printerr("✗ banc_zoom_q15 : --captures <dossier absolu> est obligatoire")
		get_tree().quit(2)
		return
	var refus := RenduCommun.refus_headless()
	if refus != "":
		printerr("✗ banc_zoom_q15 : ", refus)
		get_tree().quit(2)
		return
	_dossier = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_dossier)
	GameSettings.pilotage_externe = true
	GameSettings.intro_vue = true
	GameSettings.mode_iso = true
	DisplayServer.window_set_size(TAILLE)
	# Sous Xvfb sans gestionnaire de fenêtres, la vue ne suit pas la fenêtre (correction du photographe, 0c67705).
	get_window().size = TAILLE
	AudioServer.set_bus_mute(0, true)

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node("UI")
	_main.archiver_les_matchs = false
	_ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active and _main.countdown_left <= 0.0, 3000):
		_echouer("la manche n'a pas démarré")
		_finir()
		return
	for j in [_main.p1, _main.p2]:
		var pantin := Pantin.new()
		pantin.name = "PantinDuBancZoom"
		_main._set_player_input_provider(j, pantin)
		_pantins.append(pantin)
	_ui.visible = false
	print("=== Banc du zoom du duel (Q15) ===")
	print("BANC_ZOOM reglages lacet_j1=%.0f lacet_j2=%.0f option=%s decalage=%.2f facteur_portee=%.2f fenetre=%s vue=%s"
		% [GameSettings.lacet_de(0), GameSettings.lacet_de(1), GameSettings.option_lacet, GameSettings.decalage_visee,
		WeaponData.facteur_portee, str(DisplayServer.window_get_size()), str(get_window().size)])
	for nom in ["weapon_pistolet", "weapon_fusil", "weapon_pompe", "weapon_arbalete"]:
		var w = _main.get(nom)
		if w != null:
			print("BANC_ZOOM classe %s nom=%s torch_scale=%.2f demi_angle=%.1f portee_px=%.1f"
				% [nom, str(w.name), float(w.torch_scale), float(w.torch_angle_deg), float(w.portee_torche())])
	if args.has("--serie"):
		await _serie()
		_finir()
		return
	for carte in CARTES:
		await _une_carte(carte)
	_finir()


## `--serie` : diagnostic. Le Cloître à ×1,5, vue unique, douze prises espacées de 20 images, sans rien changer
## entre elles : la luminance moyenne de l'image et l'éblouissement des deux joueurs à chaque prise.
func _serie() -> void:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(String(CARTES[0]["chemin"])))
	MapData.current_map_data = MapCodec.validate(json.data as Dictionary)["data"]
	_main.rebuild_arena()
	await _images(6)
	_carte = Rect2(Vector2.ZERO, Vector2(MapCodec.get_grid_size(MapData.current_map_data)) * 35.0)
	_scene = _mise_en_scene(MapData.current_map_data)
	_zoom = 1.5
	GameSettings.zoom_duel = 1.5
	_poser_la_vue(false)
	for n in 12:
		for k in 20:
			_tenir()
			await get_tree().process_frame
		var img: Image = await RenduCommun.capturer(get_tree(), 60000)
		img.save_png(_dossier.path_join("serie_%02d.png" % n))
		_prises += 1
		print("BANC_ZOOM serie n=%d image=%d luminance=%.4f eblouissement_j1=%.3f eblouissement_j2=%.3f" % [n,
			Engine.get_process_frames(), RenduCommun.luminance_moyenne(img, Rect2i(Vector2i.ZERO, img.get_size())),
			float(_main.p1.dazzle_amount), float(_main.p2.dazzle_amount)])
		if n == 0 or n == 11:
			_inventaire(get_tree().root, "")


## Diagnostic : chaque lumière allumée de l'arbre, et chaque `CanvasModulate` / environnement 3D.
func _inventaire(noeud: Node, chemin: String) -> void:
	for enfant in noeud.get_children():
		var c := chemin + "/" + String(enfant.name)
		if enfant is Light2D and (enfant as Light2D).enabled and (enfant as Light2D).is_visible_in_tree():
			var l := enfant as Light2D
			print("BANC_ZOOM lumiere2d %s energie=%.3f couleur=%s pos=%s" % [c, l.energy, str(l.color),
				str((l as Node2D).global_position.round())])
		elif enfant is Light3D and (enfant as Light3D).visible:
			print("BANC_ZOOM lumiere3d %s energie=%.3f" % [c, (enfant as Light3D).light_energy])
		elif enfant is CanvasModulate:
			print("BANC_ZOOM modulate %s couleur=%s visible=%s" % [c, str((enfant as CanvasModulate).color),
				str((enfant as CanvasModulate).visible)])
		elif enfant is WorldEnvironment and (enfant as WorldEnvironment).environment != null:
			var e := (enfant as WorldEnvironment).environment
			print("BANC_ZOOM environnement %s ambiant=%s energie=%.3f source=%d" % [c, str(e.ambient_light_color),
				e.ambient_light_energy, e.ambient_light_source])
		_inventaire(enfant, c)


func _une_carte(carte: Dictionary) -> void:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(String(carte["chemin"]))) != OK or not (json.data is Dictionary):
		_echouer("carte illisible : %s" % carte["chemin"])
		return
	var data: Dictionary = MapCodec.validate(json.data as Dictionary)["data"]
	MapData.current_map_data = data
	_main.rebuild_arena()
	await _images(6)
	var tuile := float(CandelaTileSet.TILE_SIZE.y)
	_carte = Rect2(Vector2.ZERO, Vector2(MapCodec.get_grid_size(data)) * tuile)
	_scene = _mise_en_scene(data)
	if _scene.is_empty():
		_echouer("%s : aucune mise en scène" % carte["nom"])
		return
	print("BANC_ZOOM scene cone_degage=%.3f carte=%s grille=%s carte_px=%s carte_jeu_px=%s j1=%s visee_j1=%s j2=%s visee_j2=%s portee=%.1f demi_angle=%.1f"
		% [float(_scene["cone_degage"]), carte["nom"], str(MapCodec.get_grid_size(data)), str(_carte), str(_main._carte_px), str(_scene["p1"]),
		str(_scene["v1"]), str(_scene["p2"]), str(_scene["v2"]), _portee(), _demi_angle()])
	for z in ZOOMS:
		_zoom = z
		GameSettings.zoom_duel = z
		_poser_la_vue(false)
		MurLed._fige = 0.0
		await _prendre(String(carte["nom"]), "unique", z)
		MurLed._fige = 1.0
		await _prendre(String(carte["nom"]), "unique-sommet", z, 20)
		MurLed._fige = 0.0
		_poser_la_vue(true)
		await _prendre(String(carte["nom"]), "scinde", z)
	_poser_la_vue(false)
	MurLed._fige = -1.0
	GameSettings.zoom_duel = GameSettings.ZOOM_DUEL_DEFAUT


func _prendre(carte: String, vue: String, zoom: float, repos := IMAGES_DE_REPOS) -> void:
	for k in repos:
		_tenir()
		await get_tree().process_frame
	_tenir()
	var img: Image = await RenduCommun.capturer(get_tree(), 60000)
	if img == null:
		_echouer("%s %s z%.2f : aucune image rendue" % [carte, vue, zoom])
		return
	var nom := "%s_%s_z%.2f.png" % [carte, vue, zoom]
	img.save_png(_dossier.path_join(nom))
	_prises += 1
	var p := Presentation3D.instance()
	var iso_tenue := p != null and bool(p.get("_actif")) and bool(p.get("_scinde")) == vue.begins_with("scinde")
	if not iso_tenue:
		_echouer("%s : la vue iso ne tient pas la configuration %s" % [nom, vue])
	_relever(carte, vue, zoom, nom, img.get_size())


func _relever(carte: String, vue: String, zoom: float, nom: String, taille_img: Vector2i) -> void:
	var p := Presentation3D.instance()
	var p1: Vector2 = _main.p1.global_position
	var p2: Vector2 = _main.p2.global_position
	var ligne := "BANC_ZOOM prise carte=%s vue=%s zoom=%.2f fichier=%s image=%dx%d cam2d_j1=%s cam2d_j2=%s" % [
		carte, vue, zoom, nom, taille_img.x, taille_img.y, str(_main.cam1.global_position.round()),
		str(_main.cam2.global_position.round())]
	for pid in 2:
		var cam: CameraIso = p.call("_camera_de", pid) if p != null else null
		var ecran: Viewport = p.viewport_ecran(pid) if p != null else null
		var taille_ecran: Vector2 = ecran.get_visible_rect().size if ecran != null else Vector2(TAILLE)
		var coins: Array[Vector2] = []
		var source := "camera"
		if cam != null:
			var aspect := taille_ecran.x / taille_ecran.y
			coins = CameraIso.coins_au_sol(cam.global_transform, cam.size, aspect)
		else:
			# J2 en vue unique : SON écran 1920×1080, comme en ligne, par les formules du jeu.
			source = "formule"
			taille_ecran = Vector2(TAILLE)
			coins = _empreinte_formule(pid, taille_ecran)
		var soi: Vector2 = p1 if pid == 0 else p2
		var autre: Vector2 = p2 if pid == 0 else p1
		var visee: Vector2 = _scene["v%d" % (pid + 1)]
		var poly := PackedVector2Array([coins[0], coins[1], coins[3], coins[2]])
		ligne += " | j%d source=%s ecran=%dx%d coins=%s aire_px2=%.0f part_carte=%.4f voit_autre=%s devant=%.0f derriere=%.0f gauche=%.0f droite=%.0f" % [
			pid + 1, source, taille_ecran.x, taille_ecran.y, _texte_coins(coins), _aire(poly), _part_de_la_carte(poly),
			str(Geometry2D.is_point_in_polygon(autre, poly)), _distance_au_bord(soi, visee, poly),
			_distance_au_bord(soi, -visee, poly), _distance_au_bord(soi, visee.rotated(-PI / 2.0), poly),
			_distance_au_bord(soi, visee.rotated(PI / 2.0), poly)]
		if pid == 0 and cam != null:
			var f := _empreinte_formule(0, taille_ecran)
			var ecart := 0.0
			for k in 4:
				ecart = maxf(ecart, f[k].distance_to(coins[k]))
			ligne += " ecart_formule_j1=%.1f" % ecart
		if cam != null:
			var corps := _corps_projete(cam, autre, taille_ecran)
			var bout: Vector2 = cam.vers_ecran(soi + visee * _portee(), taille_ecran)
			var pied: Vector2 = cam.vers_ecran(soi, taille_ecran)
			ligne += " corps_autre=%s corps_l=%.1f corps_h=%.1f torche_ecran_px=%.1f pied=%s bout=%s" % [
				str(corps.position.round()), corps.size.x, corps.size.y, pied.distance_to(bout), str(pied.round()),
				str(bout.round())]
	print(ligne)


## L'empreinte au sol de la caméra iso du joueur `pid`, recalculée comme le jeu la pose : centre par `RegardDuel`
## (décalage convergé), zoom et lacet du duel, taille `KEEP_HEIGHT` de `CameraIso.suivre`.
func _empreinte_formule(pid: int, ecran: Vector2) -> Array[Vector2]:
	var joueur: Vector2 = (_main.p1 if pid == 0 else _main.p2).global_position
	var visee: Vector2 = _scene["v%d" % (pid + 1)]
	var lacet := GameSettings.lacet_de(pid)
	var vue_px := Vector2(TAILLE)
	var dec := RegardDuel.decalage_vise(visee, GameSettings.decalage_visee, vue_px, _zoom)
	var centre := RegardDuel.centre_du_regard(joueur, dec, vue_px, _zoom, _main._carte_px,
		float(CandelaTileSet.TILE_SIZE.y), lacet)
	var base := Basis.from_euler(Vector3(deg_to_rad(-CameraIso.TANGAGE_DEG), deg_to_rad(lacet), 0.0), EULER_ORDER_YXZ)
	var t := Transform3D(base, Vector3(centre.x, 0.0, centre.y) + base.z * CameraIso.RECUL)
	var taille := CameraIso.taille_orthographique(CameraIso.TANGAGE_DEG, vue_px.y / _zoom)
	return CameraIso.coins_au_sol(t, taille, ecran.x / ecran.y)


func _corps_projete(cam: CameraIso, pied: Vector2, ecran: Vector2) -> Rect2:
	var r := Rect2()
	var premier := true
	for k in 16:
		var d := Vector2.RIGHT.rotated(TAU * k / 16.0) * RAYON_CORPS
		for h in [0.0, HAUTEUR_CORPS]:
			var s: Vector2 = cam.vers_ecran(pied + d, ecran, h)
			if premier:
				r = Rect2(s, Vector2.ZERO)
				premier = false
			else:
				r = r.expand(s)
	return r


func _texte_coins(coins: Array[Vector2]) -> String:
	var t: PackedStringArray = []
	for c in coins:
		t.append("%.0f;%.0f" % [c.x, c.y])
	return "[" + ",".join(t) + "]"


func _aire(poly: PackedVector2Array) -> float:
	var a := 0.0
	for k in poly.size():
		a += poly[k].cross(poly[(k + 1) % poly.size()])
	return absf(a) * 0.5


func _part_de_la_carte(poly: PackedVector2Array) -> float:
	var rect := PackedVector2Array([_carte.position, Vector2(_carte.end.x, _carte.position.y), _carte.end,
		Vector2(_carte.position.x, _carte.end.y)])
	var total := 0.0
	for morceau in Geometry2D.intersect_polygons(poly, rect):
		total += _aire(morceau)
	return total / (_carte.size.x * _carte.size.y)


## Du joueur jusqu'au bord de l'image, au sol, dans la direction `dir` (monde).
func _distance_au_bord(depuis: Vector2, dir: Vector2, poly: PackedVector2Array) -> float:
	var loin := depuis + dir.normalized() * 100000.0
	var mieux := INF
	for k in poly.size():
		var hit = Geometry2D.segment_intersects_segment(depuis, loin, poly[k], poly[(k + 1) % poly.size()])
		if hit != null:
			mieux = minf(mieux, depuis.distance_to(hit))
	return mieux if mieux < INF else -1.0


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


func _poser_la_vue(scinde: bool) -> void:
	var c2 := _main.vp2.get_parent() as Control
	if c2 != null:
		c2.visible = scinde
	_main._accorder_rendu_aux_vues()


func _portee() -> float:
	var w = _main.p1.get("current_weapon")
	return float(w.portee_torche()) if w != null else 307.0


func _demi_angle() -> float:
	var w = _main.p1.get("current_weapon")
	return float(w.torch_angle_deg) if w != null else 35.0


## J1 visée vers le haut de SON écran ; J2 au bord du cône, à 0,8 de la portée et 15° en dedans du demi-angle, sol
## libre et ligne de vue dégagée (murs hauts et murets). Les cartes livrées sont trop meublées pour qu'un cône
## entier de 307 px tienne sans mur : parmi les places possibles, on garde celle dont le cône est le plus dégagé
## (un rayon tous les 5°, la part de sa longueur avant le premier mur haut, comptée jusqu'à 95 %), puis la plus
## proche du centre.
func _mise_en_scene(data: Dictionary) -> Dictionary:
	var tuile := float(CandelaTileSet.TILE_SIZE.y)
	var grille := MapCodec.get_grid_size(data)
	var centre := _carte.get_center()
	var visee := Vector2.UP.rotated(-deg_to_rad(GameSettings.lacet_de(0)))
	var d := 0.8 * _portee()
	var angle := deg_to_rad(_demi_angle() - 15.0)
	var meilleur := {}
	var meilleur_score := -INF
	for gy in grille.y:
		for gx in grille.x:
			var p1 := (Vector2(gx, gy) + Vector2(0.5, 0.5)) * tuile
			if not _libre(p1):
				continue
			for signe in [1.0, -1.0]:
				var dir := visee.rotated(signe * angle)
				var p2 := p1 + dir * d
				if not _carte.has_point(p2) or not _libre(p2) or _mur_entre(p1, p2):
					continue
				# Un cône dégagé à 95 % au moins suffit ; entre ceux-là, le plus proche du centre.
				var score := minf(_cone_degage(p1, visee), 0.95) - p1.distance_to(centre) / 100000.0
				if score > meilleur_score:
					meilleur_score = score
					meilleur = {"p1": p1, "v1": visee, "p2": p2, "v2": dir.rotated(signe * PI / 2.0),
						"cone_degage": _cone_degage(p1, visee)}
	return meilleur


## La part du cône de J1 dégagée de murs hauts jusqu'à sa portée : un rayon tous les 5°, moyenne des longueurs
## libres rapportées à la portée (1,0 : aucun mur dans le cône).
func _cone_degage(p1: Vector2, visee: Vector2) -> float:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var n := int(_demi_angle() / 5.0)
	var total := 0.0
	for k in range(-n, n + 1):
		var bout := p1 + visee.rotated(deg_to_rad(5.0 * k)) * _portee()
		var q := PhysicsRayQueryParameters2D.create(p1, bout, MapGeometry.WALL_LAYER)
		q.exclude = [_main.p1.get_rid(), _main.p2.get_rid()]
		var hit := espace.intersect_ray(q)
		total += 1.0 if hit.is_empty() else p1.distance_to(hit["position"]) / _portee()
	return total / float(2 * n + 1)


func _libre(p: Vector2) -> bool:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var disque := CircleShape2D.new()
	disque.radius = 40.0
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = disque
	q.collision_mask = MapGeometry.WALL_LAYER
	q.transform = Transform2D(0.0, p)
	q.exclude = [_main.p1.get_rid(), _main.p2.get_rid()]
	if not espace.intersect_shape(q, 1).is_empty():
		return false
	# Ni sur un muret (les murs bas ne sont pas dans la couche des murs hauts).
	for m in _main.murs_bas as Array:
		if (m as Rect2).grow(20.0).has_point(p):
			return false
	return true


func _mur_entre(a: Vector2, b: Vector2) -> bool:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b, MapGeometry.WALL_LAYER)
	q.exclude = [_main.p1.get_rid(), _main.p2.get_rid()]
	if not espace.intersect_ray(q).is_empty():
		return true
	for m in _main.murs_bas as Array:
		if Geometry2D.segment_intersects_segment(a, b, (m as Rect2).position, (m as Rect2).end) != null \
				or Geometry2D.segment_intersects_segment(a, b, Vector2((m as Rect2).end.x, (m as Rect2).position.y),
				Vector2((m as Rect2).position.x, (m as Rect2).end.y)) != null:
			return true
	return false


func _images(n: int) -> void:
	for k in n:
		await RenderingServer.frame_post_draw


## Attente comptée en IMAGES (sous `--fixed-fps 60` au cloud, une image = 1/60 s de jeu, quelle que soit la montre).
func _attendre(condition: Callable, images: int) -> bool:
	for k in images:
		if condition.call():
			return true
		await get_tree().process_frame
	return false


func _echouer(raison: String) -> void:
	_echecs += 1
	printerr("  ✗ ", raison)


func _finir() -> void:
	print("BANC_ZOOM VERDICT=%s prises=%d echecs=%d" % ["OK" if _echecs == 0 else "ECHEC", _prises, _echecs])
	get_tree().quit(0 if _echecs == 0 else 1)
