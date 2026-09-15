## Banc de la lumière 3D bridée — FENÊTRÉ (chantier ISO12, lot 0).
##
## Brief `briefs/iso12_lumiere3d.md` de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED » (2026-09-15, 22:0x), plan-delta
## accepté à 22:15. Adrien, 22:0x : « Ok pour ISO12, enchaîne avec les lumières 3D. » **Aucun réglage n'est choisi ici** :
## le banc photographie et mesure chaque variante ; la session cloud tranche sur image et sur chiffres.
##
## ## La scène
## Carte d'essai des murs bas, puis Le Cloître (la mise en scène de `banc_claustro.gd`). J1 au pistolet, J2 au Braconnier
## (5°), torches tenues ; une fusée posée dans le cône de J1 (`forcer_age`) ; un flash de tir de J1 rejoué toutes les
## `PERIODE_FLASH_S` ; les corps voxel ; vue unique puis écran scindé. Fenêtre 2560×1440 au premier plan.
##
## ## Ce qui est relevé, une ligne `BANC_LUMIERE3D` par prise
## - **cadence** : `IMAGES_MESUREES` images après `IMAGES_DE_REPOS`, `ConditionsDeMatch.statistiques` (médiane, 1 % bas,
##   pire image), appels de dessin médians, lumières 3D allumées, plafond `max_lights_per_object` du projet ;
## - **image** : une capture pleine fenêtre par prise, et les positions à l'écran des ancres de la loupe (J1, J2, bord du
##   cône, pied du mur, fusée) pour les recadrages (`analyse_lumiere3d.py`) ;
## - **preuve** : sous huit visées et dans les deux vues, une prise normale et une prise `masque_preuve` (blanc là où
##   L2D > 0) ; l'analyse compte les pixels lumineux hors du masque — il en faut zéro ;
## - **silhouette de soi** : torches éteintes, flash coupé, fusée retirée, écran scindé — la silhouette de J1 doit se voir
##   dans sa vue et pas dans celle de J2.
##
## Lancer (vraie fenêtre, chien de garde à la main — pas de `timeout` sur ce Mac) :
##   godot --path . res://tools/banc_lumiere3d.tscn -- --captures <dossier absolu> [--rapide]
## `--rapide` : une carte, vue unique, ombres oui/non seulement (la vérification du montage).
## `--energies torche:30,fusee:50,…` : les constantes d'énergie par type de source (`lumieres_iso.gd`), pour la calibration —
## les mêmes pour les deux joueurs et les deux vues ; un type absent garde sa valeur.
extends Node

const CARTES := [
	{"nom": "murs_bas", "chemin": "res://tools/cartes/murs_bas_essai.json"},
	{"nom": "cloitre", "chemin": "res://assets/maps/map_001_le_cloitre.json"},
]
const TAILLE := Vector2i(2560, 1440)
const IMAGES_DE_REPOS := 30
const IMAGES_MESUREES := 300
const PERIODE_FLASH_S := 0.5
const ATLAS := [1024, 2048, 4096]
const BRIDES := [Vector2(0.0, 0.05), Vector2(0.0, 0.2)]
const VISEES_PREUVE := 8


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
var _p: Presentation3D
var _dossier := ""
var _rapide := false
var _energies := {}
var _pantins: Array = []
var _scene := {}
var _fusee: Node2D = null
var _flash_t := 0.0
var _flash_actif := true
var _contact_rayon := -1.0
var _echecs := 0
var _prises := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--captures")
	if i < 0 or i + 1 >= args.size():
		printerr("✗ banc_lumiere3d : --captures <dossier absolu> est obligatoire")
		get_tree().quit(2)
		return
	var refus := RenduCommun.refus_headless()
	if refus != "":
		printerr("✗ banc_lumiere3d : ", refus)
		get_tree().quit(2)
		return
	_dossier = args[i + 1]
	_rapide = args.has("--rapide")
	var e := args.find("--energies")
	if e >= 0 and e + 1 < args.size():
		for paire in args[e + 1].split(","):
			var kv := paire.split(":")
			if kv.size() == 2 and kv[1].is_valid_float():
				_energies[kv[0].strip_edges()] = kv[1].to_float()
	DirAccess.make_dir_recursive_absolute(_dossier)
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
		pantin.name = "PantinDuBancLumiere3D"
		_main._set_player_input_provider(j, pantin)
		_pantins.append(pantin)
	_main.p1.equip_weapon(_main.weapon_pistolet)
	_main.p2.equip_weapon(_main.weapon_arbalete)
	_ui.visible = false
	_p = Presentation3D.instance()
	if _p == null:
		_echouer("pas de Presentation3D")
		_finir()
		return
	print("=== Banc de la lumière 3D bridée (ISO12, lot 0) — plafond max_lights_per_object=%s, énergies %s ===" \
		% [str(ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object", "?")), JSON.stringify(_energies)])
	for carte in (CARTES.slice(0, 1) if _rapide else CARTES):
		await _une_carte(carte)
	_finir()


func _process(delta: float) -> void:
	if _scene.is_empty() or not is_instance_valid(_main):
		return
	_tenir()
	_flash_t += delta
	if _flash_actif and _flash_t >= PERIODE_FLASH_S:
		_flash_t = 0.0
		if is_instance_valid(_main.p1):
			_main.p1.trigger_shoot_visuals()


func _une_carte(carte: Dictionary) -> void:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(String(carte["chemin"]))) != OK or not (json.data is Dictionary):
		_echouer("carte illisible : %s" % carte["chemin"])
		return
	var data: Dictionary = MapCodec.validate(json.data as Dictionary)["data"]
	MapData.current_map_data = data
	_main.rebuild_arena()
	await _images(8)
	_scene = _mise_en_scene(data)
	if _scene.is_empty():
		_echouer("%s : aucune mise en scène" % carte["nom"])
		return
	_poser_la_fusee()
	var nom := String(carte["nom"])
	var vues := ["unique"] if _rapide else ["unique", "scinde"]
	for vue in vues:
		_poser_la_vue(vue == "scinde")
		# La référence : la vue iso d'ISO11, lumière 3D éteinte.
		await _prendre(nom, vue, {"lumiere": false})
		await _prendre(nom, vue, {"lumiere": true, "ombres": false})
		for atlas in ([2048] if _rapide else ATLAS):
			await _prendre(nom, vue, {"lumiere": true, "ombres": true, "atlas": atlas})
		if _rapide:
			continue
		for b in BRIDES:
			for pate in [0, 1]:
				for contact in [true, false]:
					await _prendre(nom, vue, {"lumiere": true, "ombres": true, "atlas": 2048, "bride": b,
						"pate": pate, "contact": contact})
		# L'échelle des économies du brief, dans son ordre (session cloud, 22:48) : chacune chiffrée.
		await _prendre(nom, vue, {"lumiere": true, "ombres": true, "atlas": 1024, "omni": false})
		await _prendre(nom, vue, {"lumiere": true, "ombres": true, "atlas": 1024, "omni": false, "torches_seules": true})
		if vue == "scinde":
			await _prendre(nom, vue, {"lumiere": true, "ombres": true, "atlas": 2048, "vue_unique_seulement": true})
		await _prendre(nom, vue, {"lumiere": true, "ombres": true, "atlas": 2048, "retro": false})
	if not _rapide:
		await _la_preuve(nom)
		await _la_silhouette(nom)
	_retirer_la_fusee()
	_p.poser_lumiere_3d(false)


## Une variante : posée, reposée, mesurée, capturée.
func _prendre(carte: String, vue: String, v: Dictionary) -> void:
	_poser_la_variante(v)
	await _images(IMAGES_DE_REPOS)
	var durees := PackedFloat32Array()
	var appels: Array[int] = []
	for k in IMAGES_MESUREES:
		await RenderingServer.frame_post_draw
		durees.append(get_process_delta_time())
		appels.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	appels.sort()
	var s := ConditionsDeMatch.statistiques(durees)
	var id := _id_variante(carte, vue, v)
	var fichier := await _capturer(id)
	var lumieres := int(_p.get("_lumieres").call("allumees")) if _p.get("_lumieres") != null else 0
	print("BANC_LUMIERE3D prise=%s carte=%s vue=%s lumiere=%s ombres=%s atlas=%d bride=%s pate=%s contact=%s omni=%s torches_seules=%s ombres_vue_unique=%s retro=%s fps_median=%.1f fps_1pc_bas=%.1f pire_ms=%.1f appels=%d lumieres3d=%d fichier=%s ancres=%s"
		% [id, carte, vue, str(v.get("lumiere", false)), str(v.get("ombres", false)), int(v.get("atlas", 0)),
		str(v.get("bride", Vector2(0.0, 0.05))), "c" if int(v.get("pate", 0)) == 1 else "a",
		str(v.get("contact", true)), str(v.get("omni", true)), str(v.get("torches_seules", false)),
		str(v.get("vue_unique_seulement", false)), str(v.get("retro", true)),
		float(s["fps_median"]), float(s["fps_1pc_bas"]), float(s["pire_image_ms"]),
		appels[appels.size() / 2], lumieres, fichier, JSON.stringify(_ancres(vue == "scinde"))])


func _poser_la_variante(v: Dictionary) -> void:
	_p.bride = v.get("bride", Vector2(0.0, 0.05))
	_p.variante_pate_3d = int(v.get("pate", 0))
	_p.masque_preuve = int(v.get("masque", 0))
	_p.ombres_3d = bool(v.get("ombres", true))
	_p.atlas_ombres = int(v.get("atlas", 2048))
	_p.retrodiffusion_3d = bool(v.get("retro", true))
	_p.ombres_omni_3d = bool(v.get("omni", true))
	_p.ombres_torches_joueurs_seules_3d = bool(v.get("torches_seules", false))
	_p.ombres_vue_unique_seulement = bool(v.get("vue_unique_seulement", false))
	_p.poser_lumiere_3d(bool(v.get("lumiere", false)))
	if _energies.has("led"):
		_p.gain_led_3d = float(_energies["led"])
	var lumieres: Node = _p.get("_lumieres")
	if lumieres != null and not _energies.is_empty():
		var table: Dictionary = lumieres.get("energie_par_type")
		for type in _energies:
			table[type] = _energies[type]
	for m in _p.get("_mat_sols"):
		var mat := m as ShaderMaterial
		if _contact_rayon < 0.0:
			_contact_rayon = float(mat.get_shader_parameter("contact_corps_rayon_px"))
		mat.set_shader_parameter("contact_corps_rayon_px", _contact_rayon if bool(v.get("contact", true)) else 0.0)


## La preuve « visible en 3D ⊆ L2D > 0 » : huit visées, les deux vues, une prise normale et une prise masque chacune.
func _la_preuve(carte: String) -> void:
	_poser_la_vue(true)
	for k in VISEES_PREUVE:
		var angle := TAU * float(k) / float(VISEES_PREUVE)
		(_pantins[0] as Pantin).visee = Vector2.RIGHT.rotated(angle)
		(_pantins[1] as Pantin).visee = Vector2.RIGHT.rotated(angle + PI)
		_scene["v1"] = (_pantins[0] as Pantin).visee
		_scene["v2"] = (_pantins[1] as Pantin).visee
		# La preuve dans les deux sens, rétrodiffusion oui puis non (la seconde montre ce que la première répare).
		for retro in [true, false]:
			for masque in [0, 1]:
				_poser_la_variante({"lumiere": true, "ombres": true, "atlas": 2048, "masque": masque, "retro": retro})
				await _images(IMAGES_DE_REPOS)
				var id := "%s_preuve_v%d_retro%d_%s" % [carte, k, 1 if retro else 0, "masque" if masque == 1 else "normal"]
				var fichier := await _capturer(id)
				print("BANC_LUMIERE3D preuve carte=%s visee=%d retro=%d masque=%d fichier=%s"
					% [carte, k, 1 if retro else 0, masque, fichier])
	_scene["v1"] = Vector2.UP
	_scene["v2"] = Vector2.UP


## La silhouette de soi : noir complet (torches éteintes, flash coupé, fusée retirée), écran scindé.
func _la_silhouette(carte: String) -> void:
	_poser_la_vue(true)
	for pantin in _pantins:
		(pantin as Pantin).torche = false
	_flash_actif = false
	_retirer_la_fusee()
	_poser_la_variante({"lumiere": true, "ombres": true, "atlas": 2048})
	await _images(90)
	var fichier := await _capturer("%s_silhouette" % carte)
	print("BANC_LUMIERE3D silhouette carte=%s fichier=%s ancres=%s" % [carte, fichier, JSON.stringify(_ancres(true))])
	for pantin in _pantins:
		(pantin as Pantin).torche = true
	_flash_actif = true
	_poser_la_fusee()


## Les ancres de la loupe, en pixels de la fenêtre : J1, J2, le bord du cône de J1, le pied du mur devant J1, la fusée.
## Par vue regardée : `j1` dans la vue de J1, `j2_vue2` dans celle de J2 en écran scindé.
func _ancres(scinde: bool) -> Dictionary:
	var out := {}
	var arme: WeaponData = _main.p1.get("current_weapon")
	var devant := Vector2(_scene["v1"])
	var portee := arme.portee_torche() if arme != null else 300.0
	var demi := deg_to_rad(arme.torch_angle_deg if arme != null else 30.0)
	var points := {
		"j1": _main.p1.global_position,
		"j2": _main.p2.global_position,
		"bord_cone": _main.p1.global_position + devant.rotated(demi) * portee * 0.6,
		"pied_mur": _main.p1.global_position + devant * 3.2 * MursBas.TUILE,
	}
	if is_instance_valid(_fusee):
		points["fusee"] = _fusee.global_position
	for nom in points:
		out[nom] = _a_l_ecran(0, points[nom])
		if scinde:
			out[nom + "_vue2"] = _a_l_ecran(1, points[nom])
	return out


func _a_l_ecran(pid: int, monde: Vector2) -> Array:
	var projecteur: Callable = _p.projecteur_ecran(pid)
	var cadre: Rect2 = _p._cadre(pid)
	var local: Vector2 = projecteur.call(monde)
	var fenetre := Vector2(DisplayServer.window_get_size())
	var echelle := fenetre / Vector2(get_viewport().get_visible_rect().size)
	var p := (local + cadre.position) * echelle
	return [roundi(p.x), roundi(p.y)]


func _capturer(id: String) -> String:
	_tenir()
	DisplayServer.window_move_to_foreground()
	var img: Image = await RenduCommun.capturer(get_tree(), 15000)
	if img == null:
		_echouer("%s : aucune image rendue en 15 s (fenêtre au second plan ?)" % id)
		return ""
	var nom := id + ".png"
	img.save_png(_dossier.path_join(nom))
	_prises += 1
	return nom


func _id_variante(carte: String, vue: String, v: Dictionary) -> String:
	if not bool(v.get("lumiere", false)):
		return "%s_%s_reference2d" % [carte, vue]
	var b: Vector2 = v.get("bride", Vector2(0.0, 0.05))
	var suffixe := ""
	if not bool(v.get("omni", true)):
		suffixe += "_omni0"
	if bool(v.get("torches_seules", false)):
		suffixe += "_torchesseules"
	if bool(v.get("vue_unique_seulement", false)):
		suffixe += "_ombresvueunique"
	if not bool(v.get("retro", true)):
		suffixe += "_retro0"
	return "%s_%s_ombres%s_atlas%d_bride%02d_pate%s_contact%s%s" % [carte, vue, "1" if v.get("ombres", true) else "0",
		int(v.get("atlas", 2048)), roundi(b.y * 100.0), "c" if int(v.get("pate", 0)) == 1 else "a",
		"1" if v.get("contact", true) else "0", suffixe]


func _poser_la_fusee() -> void:
	_retirer_la_fusee()
	var lieu: Vector2 = _main.p1.global_position + Vector2(_scene["v1"]) * 2.2 * MursBas.TUILE \
		+ Vector2(_scene["v1"]).orthogonal() * 1.5 * MursBas.TUILE
	_fusee = (load("res://fusee.gd") as GDScript).new()
	_fusee.set("depart", lieu)
	_fusee.set("direction", Vector2.DOWN)
	_fusee.set("joueurs", [_main.p1, _main.p2])
	_main.bullet_container.add_child(_fusee)
	_fusee.set_physics_process(false)
	_fusee.global_position = lieu
	_fusee.call("forcer_age", 1.0)


func _retirer_la_fusee() -> void:
	if is_instance_valid(_fusee):
		_fusee.queue_free()
	_fusee = null


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


func _poser_la_vue(scinde: bool) -> void:
	var c2 := _main.vp2.get_parent() as Control
	if c2 != null:
		c2.visible = scinde
	_main._accorder_rendu_aux_vues()


## La mise en scène de `banc_claustro.gd`, reprise telle quelle.
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
			return {"p1": p1, "v1": Vector2.UP, "p2": p2, "v2": Vector2.UP}
	var muret := Rect2()
	for m in _main.murs_bas as Array:
		var rect := m as Rect2
		if rect.size.x > rect.size.y and (muret.size == Vector2.ZERO or rect.position.y < muret.position.y):
			muret = rect
	if interieurs.is_empty() and muret.size != Vector2.ZERO:
		return {"p1": Vector2(16.0 * t, 3.0 * t + 3.5 * t), "v1": Vector2.UP,
			"p2": Vector2(muret.get_center().x, muret.end.y + 32.0), "v2": Vector2.DOWN}
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
	if _p != null:
		_p.poser_lumiere_3d(false)
	print("BANC_LUMIERE3D VERDICT=%s prises=%d echecs=%d" % ["OK" if _echecs == 0 else "ECHEC", _prises, _echecs])
	get_tree().quit(0 if _echecs == 0 else 1)
