extends Node2D

## Banc d'essai et aperçu : Matière & décors de l'arène
## Roman Graphique Brutaliste & Hangar Clandestin
##
## Commandes :
## - ZQSD / Flèches : Déplacer le joueur / la torche
## - Souris : Viser
## - Clic gauche / Espace : Tirer (éjection de douilles)
## - R : Recharger (éjection de douille d'atelier)
## - 1 / 2 / 3 : Changer d'arme (Pistolet / Fusil / Pompe)
## - Échap : Quitter

const Charte := preload("res://charte.gd")
const CandelaTileSetScript := preload("res://candela_tileset.gd")
const BulletCasingScript := preload("res://bullet_casing.gd")
const ArenaDecorScript := preload("res://arena_decor.gd")

var _weapons := ["pistolet", "fusil", "pompe"]
var _curr_weapon_idx := 0

var _camera: Camera2D
var _porteur: CharacterBody2D
var _torche: PointLight2D
var _label_info: Label
var _arena_node: Node2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Charte.NOIR)
	_monter_scene()


func _monter_scene() -> void:
	var mod := CanvasModulate.new()
	mod.color = Charte.NOIR
	add_child(mod)

	_arena_node = Node2D.new()
	_arena_node.name = "Arena"
	add_child(_arena_node)

	# Charger une carte d'atelier avec fosse (L'Usine ou Arène Circulaire)
	var map_path := "res://assets/maps/map_002_l_usine.json"
	var file := FileAccess.open(map_path, FileAccess.READ)
	var map_data: Dictionary = {}
	if file != null:
		var json := JSON.new()
		json.parse(file.get_as_text())
		file.close()
		map_data = json.data as Dictionary

	var tileset := CandelaTileSetScript.create_tileset()

	var floor_layer := TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.tile_set = tileset
	floor_layer.z_index = -1
	_arena_node.add_child(floor_layer)

	var walls_layer := TileMapLayer.new()
	walls_layer.name = "WallsLayer"
	walls_layer.tile_set = tileset
	walls_layer.z_index = 0
	var wall_mat := CanvasItemMaterial.new()
	wall_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	walls_layer.material = wall_mat
	_arena_node.add_child(walls_layer)

	MapData.apply_to_layers(floor_layer, walls_layer, null, map_data)
	MapGeometry.build_collisions(map_data, _arena_node)

	# Habillage d'atelier (chevrons, pochoirs, fûts)
	ArenaDecorScript.build(map_data, _arena_node)

	# Porteur avec torche
	_porteur = CharacterBody2D.new()
	_porteur.position = Vector2(250, 450)
	_arena_node.add_child(_porteur)

	_torche = PointLight2D.new()
	_torche.color = Charte.HALOGENE
	_torche.energy = 2.0
	_torche.shadow_enabled = true
	_torche.shadow_item_cull_mask = 1
	_torche.range_item_cull_mask = 1 | 2 | 16
	_torche.texture = LightTextures.masque("res://assets/torche/cookie_pistolet.png")
	if _torche.texture == null:
		_torche.texture = LightTextures.radial(256)
	_torche.texture_scale = 2.5
	_porteur.add_child(_torche)

	_camera = Camera2D.new()
	_camera.zoom = Vector2(1.5, 1.5)
	_porteur.add_child(_camera)

	# Interface d'information
	var canvas := CanvasLayer.new()
	add_child(canvas)

	_label_info = Label.new()
	_label_info.position = Vector2(20, 20)
	var settings := LabelSettings.new()
	settings.font = Charte.police_ui(Charte.POIDS_APPUI)
	settings.font_color = Charte.HALOGENE
	_label_info.label_settings = settings
	_update_label()
	canvas.add_child(_label_info)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_1:
			_curr_weapon_idx = 0
			_update_label()
		elif event.keycode == KEY_2:
			_curr_weapon_idx = 1
			_update_label()
		elif event.keycode == KEY_3:
			_curr_weapon_idx = 2
			_update_label()
		elif event.keycode == KEY_SPACE:
			_tirer()
		elif event.keycode == KEY_R:
			_recharger()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tirer()


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		move.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		move.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1

	if move != Vector2.ZERO:
		_porteur.velocity = move.normalized() * 220.0
		_porteur.move_and_slide()

	var mouse_pos := get_global_mouse_position()
	_porteur.rotation = (_porteur.global_position).angle_to_point(mouse_pos)


func _tirer() -> void:
	var slug: String = _weapons[_curr_weapon_idx]
	var shoot_dir := Vector2.from_angle(_porteur.rotation)
	BulletCasingScript.eject(_arena_node, _porteur.global_position, shoot_dir, slug)


func _recharger() -> void:
	var slug: String = _weapons[_curr_weapon_idx]
	var shoot_dir := Vector2.from_angle(_porteur.rotation)
	BulletCasingScript.eject(_arena_node, _porteur.global_position, shoot_dir, slug)


func _update_label() -> void:
	var slug: String = _weapons[_curr_weapon_idx]
	_label_info.text = "CANDELA 2D — APERÇU MATIÈRE & DÉCORS (DA BRUTALISTE)\nArme active : %s\nTir : Clic gauche / Espace | Recharge : R | Armes : 1, 2, 3 | Quitter : Échap" % slug.to_upper()
