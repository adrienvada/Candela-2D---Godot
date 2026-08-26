## MapEditor — Éditeur de cartes de Candela.
##
## Principes d'ergonomie retenus :
##   • Un seul geste par action. On maintient, on glisse, on relâche. Plus
##     aucune validation en deux temps.
##   • Souris et manette en permanence, sans bascule de mode : le curseur suit
##     la dernière entrée utilisée.
##   • Rien ne se perd. Chaque geste est une transaction annulable (100 crans),
##     et une carte injouable ne peut être ni sauvegardée ni testée.
##   • La grille, sa taille, ses limites de caméra viennent des données de la
##     carte — plus aucune constante 20×20 en dur.
##
## Correspondance des touches : voir _setup_inputs() et la barre d'aide du HUD.
##
## Le fichier ne possède que sa scène. Les actions manette sont déclarées
## localement (InputMap) faute de pouvoir écrire dans input_setup.gd.

extends Node2D

const Charte := preload("res://charte.gd")

## Étapes d'édition, dans l'ordre de la barre du haut.
enum EditorStep { FLOOR, WALLS, SPAWN_P1, SPAWN_P2 }
## Outil courant, déduit des modificateurs maintenus.
enum Brush { FREE, RECT, FILL }
## Dernier périphérique utilisé — décide qui pilote le curseur.
enum Pointer { PAD, MOUSE }

signal step_changed(step: EditorStep)
signal map_saved(map_id: String)
signal sandbox_toggled(active: bool)

const STEP_LABELS: Array[String] = [
	"SOL", "MURS", "APPARITION J1", "APPARITION J2",
]
const STEP_COLOURS: Array[Color] = [
	Charte.VERT,       # SOL — la diode « disponible »
	Charte.HALOGENE,   # MURS — la lumière qui les révèle
	Charte.BLEU,       # J1
	Charte.ROUGE,      # J2
]

## Pas de redimensionnement de la grille, en cases par appui.
const GRID_STEP := 2
## Taille des cartes créées depuis l'éditeur.
const NEW_MAP_GRID := Vector2i(32, 32)
## Répétition du curseur à la manette : premier délai, puis cadence variable.
const MOVE_DELAY_FIRST := 0.20
const MOVE_DELAY_SLOW := 0.15
const MOVE_DELAY_FAST := 0.045
## Seuil de basculement d'une direction au stick.
const MOVE_THRESHOLD := 0.45
## Nombre maximal d'animations de pose simultanées.
const MAX_POPS := 90
## Cadence maximale du panneau de validation.
const VALIDATION_INTERVAL := 0.15
## Au-delà, on ne surligne plus les zones orphelines (coût de dessin).
const MAX_ORPHAN_HIGHLIGHT := 600
## Délai pendant lequel un second « retour » quitte sans sauvegarder.
const BACK_CONFIRM_DELAY := 3.0
## Chemin du module de géométrie livré par un autre chantier.
const GEOMETRY_SCRIPT := "res://map_geometry.gd"

## Actions déclarées localement. À consolider dans input_setup.gd le jour où
## ce fichier appartiendra au même chantier.
const EDITOR_ACTIONS: Array[String] = [
	"editor_move_up", "editor_move_down", "editor_move_left", "editor_move_right",
	"editor_pan_up", "editor_pan_down", "editor_pan_left", "editor_pan_right",
	"editor_draw", "editor_erase", "editor_mod_rect", "editor_mod_fill",
	"editor_step_prev", "editor_step_next", "editor_undo",
	"editor_save", "editor_test", "editor_back", "editor_light", "editor_frame",
	"editor_brush",
]

# ---------------------------------------------------------------------------
# NŒUDS
# ---------------------------------------------------------------------------

@onready var camera: MapEditorCamera = $Camera2D
@onready var floor_layer: TileMapLayer = $TileMap/FloorLayer
@onready var walls_layer: TileMapLayer = $TileMap/WallsLayer
@onready var grid_backdrop: Node2D = $GridBackdrop
@onready var preview_layer: Node2D = $PreviewLayer
@onready var effects_layer: Node2D = $EffectsLayer
@onready var cursor: Node2D = $GridCursor
@onready var cursor_light: PointLight2D = $CursorLight
@onready var spawn_points: Node2D = $SpawnPoints
@onready var p1_spawn: Marker2D = $SpawnPoints/P1Spawn
@onready var p2_spawn: Marker2D = $SpawnPoints/P2Spawn
@onready var sandbox_layer: Node2D = $SandboxLayer
@onready var ambient: CanvasModulate = $CanvasModulate
@onready var hud: MapEditorHUD = $EditorHUD

# ---------------------------------------------------------------------------
# ÉTAT
# ---------------------------------------------------------------------------

var tools := MapEditorTools.new()

var current_step: EditorStep = EditorStep.FLOOR
var grid_pos := Vector2i.ZERO
var grid_size := NEW_MAP_GRID

## Métadonnées de la carte en cours (id, nom, taille…). Le contenu, lui, vit
## dans les calques : c'est MapData.extract_from_layers() qui les réunit.
var _map_meta: Dictionary = {}
var _map_source: String = ""
var _cached_data: Dictionary = {}
var _validation: Dictionary = {"ok": false, "checks": []}
var _orphan_cells: Array[Vector2i] = []
var _dirty: bool = false

var _pointer: Pointer = Pointer.MOUSE
var _move_cooldown: float = 0.0
var _move_primed: bool = false
var _pulse: float = 0.0

var _stroke_active: bool = false
var _stroke_painting: bool = true
## Pinceau choisi de façon persistante. Le rectangle est le défaut : tracer
## une salle en deux points évite de peindre le sol case par case.
var _brush_mode: Brush = Brush.RECT
var _stroke_brush: Brush = Brush.FREE
var _stroke_anchor := Vector2i.ZERO
var _stroke_last := Vector2i.ZERO

var _dragging_view: bool = false
var _modal_open: bool = false
var _sandbox_active: bool = false
var _light_preview: bool = false
var _light_warning_shown: bool = false

var _validation_dirty: bool = true
var _validation_timer: float = 0.0
var _back_armed_until: float = 0.0
var _tool_hint_cache: String = ""

var _add_material: CanvasItemMaterial = null
var _test_player: Node2D = null
var _light_geometry: Node2D = null

# ---------------------------------------------------------------------------
# CYCLE DE VIE
# ---------------------------------------------------------------------------

func _ready() -> void:
	var tileset := CandelaTileSet.create_tileset()
	floor_layer.tile_set = tileset
	walls_layer.tile_set = tileset

	_add_material = CanvasItemMaterial.new()
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_setup_inputs()
	_setup_cursor_light()

	tools.setup(floor_layer, walls_layer, grid_size)
	tools.cells_touched.connect(_on_cells_touched)
	tools.spawn_moved.connect(_on_spawn_moved)
	tools.history_changed.connect(_on_history_changed)
	tools.map_changed.connect(_on_map_changed)

	grid_backdrop.draw.connect(_on_grid_draw)
	preview_layer.draw.connect(_on_preview_draw)
	cursor.draw.connect(_on_cursor_draw)

	hud.build_steps(STEP_LABELS, STEP_COLOURS)
	hud.action_requested.connect(_on_action_requested)
	hud.save_confirmed.connect(_on_save_confirmed)
	hud.import_confirmed.connect(_on_import_confirmed)
	hud.step_selected.connect(_on_step_selected)
	hud.modal_state_changed.connect(_on_modal_state_changed)

	# On reprend la carte sélectionnée : ouvrir l'éditeur ne doit jamais
	# effacer silencieusement ce sur quoi le joueur travaillait.
	var start := MapData.get_selected()
	_load_map(start if not start.is_empty() else MapCodec.new_map(
		MapData.suggest_unique_name("Nouvelle carte"), NEW_MAP_GRID))

func _process(delta: float) -> void:
	_pulse += delta
	cursor.queue_redraw()
	preview_layer.queue_redraw()

	if _validation_dirty:
		_validation_timer -= delta
		if _validation_timer <= 0.0:
			_run_validation()

	if _modal_open:
		if Input.is_action_just_pressed("ui_cancel"):
			hud.close_dialog()
		return

	if _sandbox_active:
		_process_sandbox(delta)
		return

	# Sécurité : un glisser de caméra ne doit pas rester coincé si le bouton
	# a été relâché hors de la fenêtre.
	if _dragging_view and not (Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
			or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_dragging_view = false

	_process_pad_cursor(delta)
	_process_camera(delta)
	_process_painting()
	_process_commands()
	_refresh_tool_hint()

# ---------------------------------------------------------------------------
# ENTRÉES — DÉCLARATION
# ---------------------------------------------------------------------------

## Déclare toutes les actions de l'éditeur. Idempotent : les événements sont
## purgés avant d'être réécrits, un retour dans l'éditeur ne les empile pas.
func _setup_inputs() -> void:
	var pads := Input.get_connected_joypads()
	var device := int(pads[0]) if pads.size() > 0 else 0

	for action in EDITOR_ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		InputMap.action_set_deadzone(action, 0.22)

	var add_axis := func(action: String, axis: int, value: float) -> void:
		var event := InputEventJoypadMotion.new()
		event.device = device
		event.axis = axis
		event.axis_value = value
		InputMap.action_add_event(action, event)

	var add_button := func(action: String, button: int) -> void:
		var event := InputEventJoypadButton.new()
		event.device = device
		event.button_index = button
		InputMap.action_add_event(action, event)

	var add_key := func(action: String, keycode: Key) -> void:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)

	var add_mouse := func(action: String, button: MouseButton) -> void:
		var event := InputEventMouseButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)

	# --- Curseur : stick gauche, croix directionnelle, flèches, WASD ---
	add_axis.call("editor_move_left", JOY_AXIS_LEFT_X, -1.0)
	add_axis.call("editor_move_right", JOY_AXIS_LEFT_X, 1.0)
	add_axis.call("editor_move_up", JOY_AXIS_LEFT_Y, -1.0)
	add_axis.call("editor_move_down", JOY_AXIS_LEFT_Y, 1.0)
	add_button.call("editor_move_left", JOY_BUTTON_DPAD_LEFT)
	add_button.call("editor_move_right", JOY_BUTTON_DPAD_RIGHT)
	add_button.call("editor_move_up", JOY_BUTTON_DPAD_UP)
	add_button.call("editor_move_down", JOY_BUTTON_DPAD_DOWN)
	add_key.call("editor_move_left", KEY_LEFT)
	add_key.call("editor_move_right", KEY_RIGHT)
	add_key.call("editor_move_up", KEY_UP)
	add_key.call("editor_move_down", KEY_DOWN)
	add_key.call("editor_move_left", KEY_A)
	add_key.call("editor_move_right", KEY_D)
	add_key.call("editor_move_up", KEY_W)
	add_key.call("editor_move_down", KEY_S)

	# --- Changement de pinceau (rectangle / libre / pot) ---
	add_key.call("editor_brush", KEY_B)

	# --- Caméra : stick droit ---
	add_axis.call("editor_pan_left", JOY_AXIS_RIGHT_X, -1.0)
	add_axis.call("editor_pan_right", JOY_AXIS_RIGHT_X, 1.0)
	add_axis.call("editor_pan_up", JOY_AXIS_RIGHT_Y, -1.0)
	add_axis.call("editor_pan_down", JOY_AXIS_RIGHT_Y, 1.0)

	# --- Dessin : croix / clic gauche, carré / clic droit ---
	add_button.call("editor_draw", JOY_BUTTON_A)
	add_mouse.call("editor_draw", MOUSE_BUTTON_LEFT)
	add_button.call("editor_erase", JOY_BUTTON_X)
	add_mouse.call("editor_erase", MOUSE_BUTTON_RIGHT)

	# --- Modificateurs analogiques : L2 rectangle, R2 pot (et zoom seuls) ---
	add_axis.call("editor_mod_rect", JOY_AXIS_TRIGGER_LEFT, 1.0)
	add_axis.call("editor_mod_fill", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	InputMap.action_set_deadzone("editor_mod_rect", 0.12)
	InputMap.action_set_deadzone("editor_mod_fill", 0.12)

	# --- Commandes ---
	add_button.call("editor_step_prev", JOY_BUTTON_LEFT_SHOULDER)
	add_button.call("editor_step_next", JOY_BUTTON_RIGHT_SHOULDER)
	add_button.call("editor_undo", JOY_BUTTON_BACK)
	add_button.call("editor_save", JOY_BUTTON_START)
	add_button.call("editor_test", JOY_BUTTON_Y)
	add_button.call("editor_back", JOY_BUTTON_B)
	add_button.call("editor_light", JOY_BUTTON_RIGHT_STICK)
	add_button.call("editor_frame", JOY_BUTTON_LEFT_STICK)

	# Les raccourcis clavier à modificateur (Ctrl+Z, Ctrl+S, Maj+Tab…) sont
	# traités dans _unhandled_key_input : l'InputMap ne distingue pas
	# suffisamment les combinaisons pour les exprimer proprement ici.

func _setup_cursor_light() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 512
	texture.height = 512

	cursor_light.texture = texture
	cursor_light.texture_scale = 1.4
	cursor_light.energy = 1.9
	cursor_light.color = Charte.HALOGENE
	cursor_light.shadow_enabled = true
	cursor_light.enabled = false

# ---------------------------------------------------------------------------
# ENTRÉES — SOURIS ET CLAVIER
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _modal_open or _sandbox_active:
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_pointer = Pointer.MOUSE
		if _dragging_view:
			camera.pan_by(-motion.relative / camera.get_zoom_level())
		else:
			_set_cursor_cell(_cell_under_mouse())
		return

	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		match click.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				camera.zoom_towards(1.0, get_global_mouse_position())
			MOUSE_BUTTON_WHEEL_DOWN:
				camera.zoom_towards(-1.0, get_global_mouse_position())
			MOUSE_BUTTON_MIDDLE:
				_dragging_view = click.pressed
			MOUSE_BUTTON_LEFT:
				_pointer = Pointer.MOUSE
				# Espace + glisser : déplacement de caméra, jamais du dessin.
				if Input.is_key_pressed(KEY_SPACE):
					_dragging_view = click.pressed
				elif click.pressed:
					_set_cursor_cell(_cell_under_mouse())
			MOUSE_BUTTON_RIGHT:
				_pointer = Pointer.MOUSE
				if click.pressed:
					_set_cursor_cell(_cell_under_mouse())

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	# Échap : d'abord fermer ce qui est ouvert, seulement ensuite quitter.
	if key.keycode == KEY_ESCAPE:
		if hud.is_modal_open():
			hud.close_dialog()
		elif _sandbox_active:
			_toggle_sandbox()
		else:
			_go_back()
		get_viewport().set_input_as_handled()
		return

	if _modal_open:
		return

	var command := key.ctrl_pressed or key.meta_pressed

	if command and key.keycode == KEY_Z:
		_do_redo() if key.shift_pressed else _do_undo()
	elif command and key.keycode == KEY_Y:
		_do_redo()
	elif command and key.keycode == KEY_S:
		_open_save_dialog()
	elif command and key.keycode == KEY_C:
		_copy_share_code()
	elif command and key.keycode == KEY_V:
		hud.open_import_dialog()
	elif key.keycode == KEY_TAB:
		_change_step(-1 if key.shift_pressed else 1)
	elif key.keycode == KEY_L:
		_toggle_light_preview()
	elif key.keycode == KEY_F:
		camera.frame_all()
	elif key.keycode == KEY_F5:
		_toggle_sandbox()
	else:
		return

	get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# ENTRÉES — SCRUTATION
# ---------------------------------------------------------------------------

func _process_pad_cursor(delta: float) -> void:
	var axis := Vector2(
		Input.get_action_strength("editor_move_right")
			- Input.get_action_strength("editor_move_left"),
		Input.get_action_strength("editor_move_down")
			- Input.get_action_strength("editor_move_up"))

	if axis.length() < 0.25:
		_move_cooldown = 0.0
		_move_primed = false
		return

	_pointer = Pointer.PAD
	_move_cooldown -= delta
	if _move_cooldown > 0.0:
		return

	var step := Vector2i.ZERO
	if absf(axis.x) > MOVE_THRESHOLD:
		step.x = 1 if axis.x > 0.0 else -1
	if absf(axis.y) > MOVE_THRESHOLD:
		step.y = 1 if axis.y > 0.0 else -1
	if step == Vector2i.ZERO:
		return

	_set_cursor_cell(grid_pos + step)

	# Plus le stick est poussé, plus le curseur file : on balaie vite une
	# grande zone sans perdre la précision au carreau près.
	if _move_primed:
		_move_cooldown = lerpf(MOVE_DELAY_SLOW, MOVE_DELAY_FAST,
			clampf(axis.length(), 0.0, 1.0))
	else:
		_move_cooldown = MOVE_DELAY_FIRST
		_move_primed = true

func _process_camera(delta: float) -> void:
	var pan := Vector2(
		Input.get_action_strength("editor_pan_right")
			- Input.get_action_strength("editor_pan_left"),
		Input.get_action_strength("editor_pan_down")
			- Input.get_action_strength("editor_pan_up"))

	if pan.length() > 0.2:
		camera.pan_with_stick(pan, delta)
	elif _pointer == Pointer.PAD or _stroke_active:
		camera.follow_cursor(_cell_centre(grid_pos), delta)

	# Gâchettes : zoom tant qu'on ne dessine pas. En cours de tracé, elles
	# redeviennent les modificateurs rectangle et pot de peinture.
	if not _stroke_active:
		var zoom_axis := Input.get_action_strength("editor_mod_fill") \
			- Input.get_action_strength("editor_mod_rect")
		if absf(zoom_axis) > 0.15:
			camera.zoom_by(zoom_axis * MapEditorCamera.ZOOM_PAD_RATE * delta)

func _process_painting() -> void:
	var wants_paint := Input.is_action_pressed("editor_draw")
	var wants_erase := Input.is_action_pressed("editor_erase")

	if _stroke_active:
		if _stroke_painting and wants_paint:
			_continue_stroke()
		elif not _stroke_painting and wants_erase:
			_continue_stroke()
		else:
			_finish_stroke()
		return

	if _dragging_view or Input.is_key_pressed(KEY_SPACE):
		return
	if _pointer == Pointer.MOUSE and _pointer_over_ui():
		return

	if wants_paint:
		_begin_stroke(true)
	elif wants_erase:
		_begin_stroke(false)

func _process_commands() -> void:
	# Select maintenu transforme R1 en « rétablir » : on n'enchaîne donc pas
	# de changement d'étape dans ce cas.
	var redo_held := Input.is_action_pressed("editor_undo")

	if Input.is_action_just_pressed("editor_step_next") and not redo_held:
		_change_step(1)
	if Input.is_action_just_pressed("editor_step_prev") and not redo_held:
		_change_step(-1)

	if Input.is_action_just_pressed("editor_undo"):
		if Input.is_action_pressed("editor_step_next"):
			_do_redo()
		else:
			_do_undo()

	if Input.is_action_just_pressed("editor_save"):
		_open_save_dialog()
	if Input.is_action_just_pressed("editor_test"):
		_toggle_sandbox()
	if Input.is_action_just_pressed("editor_back"):
		_go_back()
	if Input.is_action_just_pressed("editor_light"):
		_toggle_light_preview()
	if Input.is_action_just_pressed("editor_frame"):
		camera.frame_all()
	if Input.is_action_just_pressed("editor_brush"):
		_cycle_brush()

func _process_sandbox(_delta: float) -> void:
	if Input.is_action_just_pressed("editor_back") \
			or Input.is_action_just_pressed("editor_test"):
		_toggle_sandbox()
		return
	if _test_player != null and is_instance_valid(_test_player):
		camera.center_on(_test_player.global_position)

## Vrai si le pointeur survole un panneau du HUD : on ne peint pas à travers
## l'interface.
func _pointer_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null

func _is_rect_modifier() -> bool:
	return Input.is_action_pressed("editor_mod_rect") or Input.is_key_pressed(KEY_SHIFT)

func _is_fill_modifier() -> bool:
	return Input.is_action_pressed("editor_mod_fill") \
		or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)

## Pinceau effectif : le mode choisi de façon persistante, qu'un modificateur
## maintenu peut ponctuellement remplacer.
##
## Le rectangle est le mode par défaut sur le sol et les murs : délimiter une
## salle en deux points est bien moins laborieux que de peindre case par case.
## Le maintien reste disponible pour basculer sans changer de mode.
func _current_brush() -> Brush:
	if _is_fill_modifier():
		return Brush.FILL
	if _is_rect_modifier():
		return Brush.RECT if _brush_mode != Brush.RECT else Brush.FREE
	return _brush_mode

## Passe au pinceau suivant (rectangle → libre → pot → rectangle).
func _cycle_brush() -> void:
	match _brush_mode:
		Brush.RECT: _brush_mode = Brush.FREE
		Brush.FREE: _brush_mode = Brush.FILL
		_: _brush_mode = Brush.RECT
	hud.show_toast(_brush_label(_brush_mode), MapEditorHUD.Toast.INFO)
	hud.set_brush(_brush_button_label(), _brush_mode == Brush.RECT)
	_refresh_tool_hint(true)
	cursor.queue_redraw()

## Libellé compact pour le bouton du panneau d'outils.
func _brush_button_label() -> String:
	match _brush_mode:
		Brush.RECT: return "▭  PINCEAU : RECTANGLE"
		Brush.FILL: return "◆  PINCEAU : POT"
		_: return "✎  PINCEAU : LIBRE"

func _brush_label(brush: Brush) -> String:
	match brush:
		Brush.RECT: return "Pinceau : RECTANGLE"
		Brush.FILL: return "Pinceau : POT DE PEINTURE"
		_: return "Pinceau : LIBRE"

# ---------------------------------------------------------------------------
# GESTES DE DESSIN
# ---------------------------------------------------------------------------

func _begin_stroke(painting: bool) -> void:
	_stroke_active = true
	_stroke_painting = painting
	_stroke_brush = _current_brush()
	_stroke_anchor = grid_pos
	_stroke_last = grid_pos

	match _stroke_brush:
		Brush.RECT:
			# Rien n'est écrit avant le relâchement : on montre l'aperçu.
			pass
		Brush.FILL:
			tools.begin("Pot de peinture")
			var filled := _apply_at(grid_pos, painting, true)
			_close_transaction("%d carreaux remplis" % filled,
				MapEditorHUD.Toast.SUCCESS if filled > 0 else MapEditorHUD.Toast.WARN,
				"Région déjà dans cet état")
		_:
			tools.begin("Pinceau" if painting else "Gomme")
			_apply_at(grid_pos, painting, false)

func _continue_stroke() -> void:
	if _stroke_brush != Brush.FREE:
		return
	if grid_pos == _stroke_last:
		return

	if _is_spawn_step():
		tools.set_spawn(_spawn_index(), grid_pos if _stroke_painting
			else MapEditorTools.NO_CELL)
	else:
		# Segment plein entre les deux positions : une trainée rapide ne doit
		# jamais laisser de trous.
		tools.draw_line(_layer_for_step(), _stroke_last, grid_pos, _stroke_painting)

	_stroke_last = grid_pos

func _finish_stroke() -> void:
	if _stroke_brush == Brush.RECT:
		tools.begin("Rectangle" if _stroke_painting else "Rectangle (gomme)")
		var count := 0
		if _is_spawn_step():
			count = _apply_at(grid_pos, _stroke_painting, false)
		else:
			count = tools.draw_rect(_layer_for_step(), _stroke_anchor, grid_pos,
				_stroke_painting)
		var verb := "peints" if _stroke_painting else "effacés"
		_close_transaction("%d carreaux %s" % [count, verb],
			MapEditorHUD.Toast.INFO, "")
	else:
		_close_transaction("", MapEditorHUD.Toast.INFO, "")

	_stroke_active = false
	preview_layer.queue_redraw()

func _abort_stroke() -> void:
	if not _stroke_active:
		return
	tools.abort()
	_stroke_active = false
	preview_layer.queue_redraw()

## Écrit une cellule (ou déplace une apparition) selon l'étape courante.
## Retourne le nombre de cases réellement modifiées.
func _apply_at(cell: Vector2i, painting: bool, fill: bool) -> int:
	if _is_spawn_step():
		var target := cell if painting else MapEditorTools.NO_CELL
		return 1 if tools.set_spawn(_spawn_index(), target) else 0
	if fill:
		return tools.flood_fill(_layer_for_step(), cell, painting)
	return 1 if tools.draw_cell(_layer_for_step(), cell, painting) else 0

## Ferme la transaction ouverte. `message` n'est annoncé que si quelque chose
## a bougé ; `empty_message`, lui, explique pourquoi rien n'a changé.
func _close_transaction(message: String, kind: MapEditorHUD.Toast,
		empty_message: String) -> void:
	if not tools.is_open():
		return
	if tools.commit():
		if not message.is_empty():
			hud.show_toast(message, kind)
	elif not empty_message.is_empty():
		hud.show_toast(empty_message, MapEditorHUD.Toast.WARN)

# ---------------------------------------------------------------------------
# CURSEUR & ÉTAPES
# ---------------------------------------------------------------------------

func _set_cursor_cell(cell: Vector2i) -> void:
	var clamped := Vector2i(
		clampi(cell.x, 0, grid_size.x - 1),
		clampi(cell.y, 0, grid_size.y - 1))
	if clamped == grid_pos:
		return
	grid_pos = clamped
	_update_cursor()

func _update_cursor() -> void:
	var centre := _cell_centre(grid_pos)
	cursor.global_position = centre
	cursor_light.global_position = centre
	cursor.queue_redraw()

func _cell_centre(cell: Vector2i) -> Vector2:
	return floor_layer.to_global(floor_layer.map_to_local(cell))

func _cell_under_mouse() -> Vector2i:
	return floor_layer.local_to_map(floor_layer.to_local(get_global_mouse_position()))

func _change_step(direction: int) -> void:
	_abort_stroke()
	var count := STEP_LABELS.size()
	current_step = ((int(current_step) + direction + count) % count) as EditorStep
	hud.set_step(int(current_step), _step_colour())
	_refresh_tool_hint(true)
	step_changed.emit(current_step)

func _on_step_selected(index: int) -> void:
	_abort_stroke()
	current_step = index as EditorStep
	hud.set_step(index, _step_colour())
	_refresh_tool_hint(true)
	step_changed.emit(current_step)

func _step_colour() -> Color:
	return STEP_COLOURS[int(current_step)]

func _is_spawn_step() -> bool:
	return current_step == EditorStep.SPAWN_P1 or current_step == EditorStep.SPAWN_P2

func _spawn_index() -> int:
	return 0 if current_step == EditorStep.SPAWN_P1 else 1

func _layer_for_step() -> StringName:
	return MapEditorTools.LAYER_WALLS if current_step == EditorStep.WALLS \
		else MapEditorTools.LAYER_FLOOR

## Ligne d'état : outil courant et modificateur maintenu.
func _refresh_tool_hint(force: bool = false) -> void:
	var brush := _stroke_brush if _stroke_active else _current_brush()
	var tool_name := "Pinceau"
	match brush:
		Brush.RECT:
			tool_name = "Rectangle"
		Brush.FILL:
			tool_name = "Pot de peinture"

	if _is_spawn_step():
		tool_name = "Placement"

	var hint := "%s  ·  %s" % [tool_name, STEP_LABELS[int(current_step)]]
	if force or hint != _tool_hint_cache:
		_tool_hint_cache = hint
		hud.set_tool_hint(hint)

# ---------------------------------------------------------------------------
# RÉACTIONS AUX OUTILS
# ---------------------------------------------------------------------------

func _on_cells_touched(cells: Array[Vector2i], layer: StringName, painting: bool) -> void:
	_request_validation()

	var colour := Charte.ROUGE
	if painting:
		colour = STEP_COLOURS[1] if layer == MapEditorTools.LAYER_WALLS else STEP_COLOURS[0]

	# Le retour tactile compte plus que l'exhaustivité : sur un grand
	# remplissage, on échantillonne au lieu de saturer la scène.
	var budget := MAX_POPS - effects_layer.get_child_count()
	if budget <= 0:
		return
	var stride := maxi(1, ceili(float(cells.size()) / float(budget)))
	for i in range(0, cells.size(), stride):
		_spawn_tile_pop(cells[i], colour)

func _on_spawn_moved(index: int, cell: Vector2i) -> void:
	var marker := p1_spawn if index == 0 else p2_spawn
	if cell == MapEditorTools.NO_CELL:
		marker.global_position = Vector2(-1000, -1000)
	else:
		marker.global_position = _cell_centre(cell)
	_request_validation()

func _on_history_changed() -> void:
	hud.set_history(tools.can_undo(), tools.can_redo(), tools.peek_undo_label())

func _on_map_changed() -> void:
	_dirty = true
	_request_validation()
	if _light_preview:
		_rebuild_light_geometry()

## Animation de pose : c'est ce petit ressort qui donne la sensation d'outil
## fini. Échelle 0,85 → 1,0 en TRANS_BACK / EASE_OUT.
func _spawn_tile_pop(cell: Vector2i, colour: Color) -> void:
	var half := Vector2(CandelaTileSet.TILE_SIZE) * 0.5
	var quad := Polygon2D.new()
	quad.polygon = PackedVector2Array([
		-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y),
	])
	quad.color = Color(colour.r, colour.g, colour.b, 0.55)
	quad.material = _add_material
	quad.position = _cell_centre(cell)
	quad.scale = Vector2(0.85, 0.85)
	effects_layer.add_child(quad)

	var tween := quad.create_tween()
	tween.set_parallel(true)
	# DA4.13 — le déclic de l'éditeur est le même que celui d'une tuile de
	# galerie ou du décompte. Les départs se lisent sur le `quad` plutôt que
	# d'être recopiés : `Charte.animer()` fige la valeur à l'appel, donc juste
	# après les deux lignes qui viennent de la poser.
	Charte.animer(tween, quad, "scale", quad.scale, Vector2.ONE,
		Charte.D_LONG, Charte.Courbe.REBOND)
	Charte.animer(tween, quad, "modulate:a", quad.modulate.a, 0.0,
		Charte.D_LONG, Charte.Courbe.SORTIE)
	tween.chain().tween_callback(quad.queue_free)

# ---------------------------------------------------------------------------
# ACTIONS DU HUD
# ---------------------------------------------------------------------------

func _on_action_requested(action: StringName) -> void:
	match action:
		MapEditorHUD.ACTION_BRUSH:
			_cycle_brush()
		MapEditorHUD.ACTION_UNDO:
			_do_undo()
		MapEditorHUD.ACTION_REDO:
			_do_redo()
		MapEditorHUD.ACTION_AUTO_WALLS:
			_auto_walls()
		MapEditorHUD.ACTION_MIRROR_H:
			_mirror(MapEditorTools.Symmetry.HORIZONTAL)
		MapEditorHUD.ACTION_MIRROR_V:
			_mirror(MapEditorTools.Symmetry.VERTICAL)
		MapEditorHUD.ACTION_MIRROR_D:
			_mirror(MapEditorTools.Symmetry.DIAGONAL)
		MapEditorHUD.ACTION_MIRROR_AD:
			_mirror(MapEditorTools.Symmetry.ANTI_DIAGONAL)
		MapEditorHUD.ACTION_ROTATE_180:
			_mirror(MapEditorTools.Symmetry.ROTATE_180)
		MapEditorHUD.ACTION_GRID_WIDER:
			_resize_grid(Vector2i(GRID_STEP, 0))
		MapEditorHUD.ACTION_GRID_NARROWER:
			_resize_grid(Vector2i(-GRID_STEP, 0))
		MapEditorHUD.ACTION_GRID_TALLER:
			_resize_grid(Vector2i(0, GRID_STEP))
		MapEditorHUD.ACTION_GRID_SHORTER:
			_resize_grid(Vector2i(0, -GRID_STEP))
		MapEditorHUD.ACTION_LIGHT:
			_toggle_light_preview()
		MapEditorHUD.ACTION_FRAME:
			camera.frame_all()
		MapEditorHUD.ACTION_CLEAR:
			_clear_all()
		MapEditorHUD.ACTION_NEW:
			_new_map()
		MapEditorHUD.ACTION_SHARE:
			_copy_share_code()
		MapEditorHUD.ACTION_IMPORT:
			hud.open_import_dialog()
		MapEditorHUD.ACTION_SAVE:
			_open_save_dialog()
		MapEditorHUD.ACTION_TEST:
			_toggle_sandbox()
		MapEditorHUD.ACTION_BACK:
			_go_back()

func _on_modal_state_changed(open: bool) -> void:
	_modal_open = open
	if open:
		_abort_stroke()

func _do_undo() -> void:
	var label := tools.undo()
	if label.is_empty():
		hud.show_toast("Rien à annuler", MapEditorHUD.Toast.WARN)
	else:
		hud.show_toast("Annulé : %s" % label, MapEditorHUD.Toast.INFO)

func _do_redo() -> void:
	var label := tools.redo()
	if label.is_empty():
		hud.show_toast("Rien à rétablir", MapEditorHUD.Toast.WARN)
	else:
		hud.show_toast("Rétabli : %s" % label, MapEditorHUD.Toast.INFO)

func _auto_walls() -> void:
	tools.begin("Auto-mur")
	var placed := tools.auto_walls()
	_close_transaction("Auto-mur : %d murs posés" % placed,
		MapEditorHUD.Toast.SUCCESS,
		"Dessinez du sol avant de le ceinturer")

const SYMMETRY_LABELS := {
	MapEditorTools.Symmetry.HORIZONTAL: "Miroir horizontal",
	MapEditorTools.Symmetry.VERTICAL: "Miroir vertical",
	MapEditorTools.Symmetry.DIAGONAL: "Symétrie diagonale ↘",
	MapEditorTools.Symmetry.ANTI_DIAGONAL: "Symétrie diagonale ↗",
	MapEditorTools.Symmetry.ROTATE_180: "Rotation 180°",
}

func _mirror(axis: MapEditorTools.Symmetry) -> void:
	if not tools.supports_symmetry(axis):
		hud.show_toast("Grille carrée requise pour une symétrie diagonale",
			MapEditorHUD.Toast.WARN)
		return

	var label: String = SYMMETRY_LABELS.get(axis, "Symétrie")
	tools.begin(label)
	var added := tools.mirror(axis)
	_close_transaction("%s appliquée (%d carreaux)" % [label, added],
		MapEditorHUD.Toast.SUCCESS,
		"La carte est déjà symétrique sur cet axe")

## Agrandit ou rétrécit la grille de GRID_STEP cases sur un axe.
func _resize_grid(delta: Vector2i) -> void:
	var target := grid_size + delta
	if target.x < MapCodec.MIN_GRID or target.y < MapCodec.MIN_GRID:
		hud.show_toast("Taille minimale atteinte (%d)" % MapCodec.MIN_GRID,
			MapEditorHUD.Toast.WARN)
		return
	if target.x > MapCodec.MAX_GRID or target.y > MapCodec.MAX_GRID:
		hud.show_toast("Taille maximale atteinte (%d)" % MapCodec.MAX_GRID,
			MapEditorHUD.Toast.WARN)
		return

	tools.begin("Redimensionnement %d×%d" % [target.x, target.y])
	var removed := tools.resize_grid(target)
	grid_size = target
	_map_meta["grid_size"] = {"x": target.x, "y": target.y}

	# Les limites suivent la nouvelle étendue, mais le cadrage reste où il est :
	# agrandir la carte ne doit pas arracher la vue de la zone en cours d'édition.
	camera.update_bounds(grid_size, CandelaTileSet.TILE_SIZE)
	grid_pos = Vector2i(
		clampi(grid_pos.x, 0, grid_size.x - 1),
		clampi(grid_pos.y, 0, grid_size.y - 1))
	grid_backdrop.queue_redraw()
	hud.set_grid_state(grid_size)

	var message := "Grille %d×%d" % [target.x, target.y]
	if removed > 0:
		message += " — %d carreaux hors limites effacés" % removed
	_close_transaction(message,
		MapEditorHUD.Toast.WARN if removed > 0 else MapEditorHUD.Toast.SUCCESS,
		message)

func _clear_all() -> void:
	tools.begin("Tout vider")
	var removed := tools.clear_all()
	_close_transaction("Carte vidée (%d carreaux) — Ctrl+Z pour annuler" % removed,
		MapEditorHUD.Toast.WARN,
		"La carte est déjà vide")

func _new_map() -> void:
	_load_map(MapCodec.new_map(
		MapData.suggest_unique_name("Nouvelle carte"), NEW_MAP_GRID))
	hud.show_toast("Nouvelle carte %d×%d" % [NEW_MAP_GRID.x, NEW_MAP_GRID.y],
		MapEditorHUD.Toast.INFO)

# ---------------------------------------------------------------------------
# CHARGEMENT / VALIDATION
# ---------------------------------------------------------------------------

func _load_map(data: Dictionary) -> void:
	_abort_stroke()
	_map_meta = data.duplicate(true)
	grid_size = MapCodec.get_grid_size(_map_meta)

	var entry := MapData.get_map(String(_map_meta.get("id", "")))
	_map_source = String(entry.get("source", "")) if not entry.is_empty() else ""

	MapData.apply_to_layers(floor_layer, walls_layer, spawn_points, _map_meta)
	tools.setup(floor_layer, walls_layer, grid_size)
	tools.reset(grid_size, MapCodec.get_spawn(_map_meta, 0),
		MapCodec.get_spawn(_map_meta, 1))

	grid_pos = Vector2i(grid_size.x / 2, grid_size.y / 2)
	camera.configure(grid_size, CandelaTileSet.TILE_SIZE)
	hud.set_grid_state(grid_size)
	_update_cursor()

	_dirty = false
	grid_backdrop.queue_redraw()
	hud.set_map_name(String(_map_meta.get("name", "Carte sans nom")))
	hud.set_step(int(current_step), _step_colour())
	_refresh_tool_hint(true)
	_on_history_changed()
	_run_validation()

func _request_validation() -> void:
	if not _validation_dirty:
		_validation_dirty = true
		_validation_timer = VALIDATION_INTERVAL

## Extrait les données courantes des calques. C'est la seule vérité : les
## calques d'édition font foi, les métadonnées ne portent que l'identité.
func _current_data() -> Dictionary:
	return MapData.extract_from_layers(floor_layer, walls_layer, spawn_points, _map_meta)

func _run_validation() -> void:
	_validation_dirty = false
	_cached_data = _current_data()
	_validation = MapCodec.check_playable(_cached_data)

	hud.set_validation(_validation)
	hud.set_grid_info(grid_size,
		MapCodec.get_floor_cells(_cached_data).size(),
		MapCodec.get_wall_cells(_cached_data).size())

	_refresh_orphans()
	preview_layer.queue_redraw()

## Cases de sol qu'aucun joueur ne peut atteindre depuis l'apparition J1.
## Les surligner évite de livrer une carte coupée en deux sans s'en rendre compte.
func _refresh_orphans() -> void:
	_orphan_cells.clear()
	var reachable := MapCodec.get_reachable_cells(_cached_data)
	if reachable.is_empty():
		return

	var walls := {}
	for cell in MapCodec.get_wall_cells(_cached_data):
		walls[cell] = true

	for cell in MapCodec.get_floor_cells(_cached_data):
		if reachable.has(cell) or walls.has(cell):
			continue
		_orphan_cells.append(cell)
		if _orphan_cells.size() >= MAX_ORPHAN_HIGHLIGHT:
			return

# ---------------------------------------------------------------------------
# SAUVEGARDE & PARTAGE
# ---------------------------------------------------------------------------

func _open_save_dialog() -> void:
	if not bool(_validation.get("ok", false)):
		hud.show_toast("Sauvegarde bloquée : %s"
			% hud.first_blocking_reason(_validation), MapEditorHUD.Toast.ERROR)
		return

	var base := String(_map_meta.get("name", "Nouvelle carte"))
	# Une carte utilisateur se réenregistre sous son propre nom ; une carte
	# livrée doit obligatoirement partir sous un nouveau nom.
	var suggested := base if _map_source == "user" else MapData.suggest_unique_name(base)
	hud.open_save_dialog(suggested, MapData.list_maps())

func _on_save_confirmed(map_name: String) -> void:
	if not bool(_validation.get("ok", false)):
		hud.show_dialog_error("Carte injouable : %s"
			% hud.first_blocking_reason(_validation))
		return

	var data := _current_data()
	var result := MapData.save_map(data, map_name)
	if not bool(result["ok"]):
		hud.show_dialog_error(String(result["error"]))
		return

	_map_meta = data
	_map_meta["name"] = map_name
	_map_meta["id"] = String(result["id"])
	_map_source = "user"
	_dirty = false

	hud.close_dialog()
	hud.set_map_name(map_name)
	hud.show_toast("Carte « %s » sauvegardée" % map_name, MapEditorHUD.Toast.SUCCESS)

	# La carte fraîchement écrite devient la carte active : on peut la jouer
	# depuis le menu sans autre manipulation.
	MapData.select_map(String(result["id"]))
	map_saved.emit(String(result["id"]))

func _copy_share_code() -> void:
	var code := MapData.to_share_code(_current_data())
	DisplayServer.clipboard_set(code)
	hud.show_toast("Code de partage copié (%d caractères)" % code.length(),
		MapEditorHUD.Toast.SUCCESS)

func _on_import_confirmed(code: String) -> void:
	if code.is_empty():
		hud.show_dialog_error("Collez d'abord un code de partage")
		return

	var result := MapData.import_share_code(code)
	if not bool(result["ok"]):
		hud.show_dialog_error(String(result["error"]))
		return

	hud.close_dialog()
	var entry := MapData.get_map(String(result["id"]))
	if not entry.is_empty():
		_load_map(entry["data"])
	hud.show_toast("Carte « %s » importée" % String(result["name"]),
		MapEditorHUD.Toast.SUCCESS)

# ---------------------------------------------------------------------------
# APERÇU D'ÉCLAIRAGE
# ---------------------------------------------------------------------------

func _toggle_light_preview() -> void:
	_light_preview = not _light_preview
	cursor_light.enabled = _light_preview
	ambient.color = Charte.NOIR.lerp(Charte.ACIER, 0.09) if _light_preview else Color.WHITE
	hud.set_light_preview(_light_preview)

	if _light_preview:
		_rebuild_light_geometry()
		if _light_geometry == null and not _light_warning_shown:
			_light_warning_shown = true
			hud.show_toast("Aperçu sans ombres : map_geometry.gd absent",
				MapEditorHUD.Toast.WARN)
	else:
		_clear_light_geometry()

func _rebuild_light_geometry() -> void:
	_clear_light_geometry()
	var host := Node2D.new()
	host.name = "LightGeometry"
	add_child(host)
	if _build_geometry(host):
		_light_geometry = host
	else:
		# Sans MapGeometry, on ne fabrique pas un millier de corps physiques
		# inutiles : l'aperçu se contente de la torche, sans ombres.
		host.queue_free()

func _clear_light_geometry() -> void:
	if _light_geometry != null and is_instance_valid(_light_geometry):
		_light_geometry.queue_free()
	_light_geometry = null

## Construit collisions et occluders. Retourne true si le module dédié
## MapGeometry a pris la main (donc avec occluders et ombres).
func _build_geometry(host: Node) -> bool:
	if ResourceLoader.exists(GEOMETRY_SCRIPT):
		var geometry := load(GEOMETRY_SCRIPT) as GDScript
		if geometry != null and geometry.has_method("build_collisions"):
			geometry.call("build_collisions", _current_data(), host)
			return true
	return false

# ---------------------------------------------------------------------------
# MODE TEST (SANDBOX)
# ---------------------------------------------------------------------------

func _toggle_sandbox() -> void:
	if not _sandbox_active and not bool(_validation.get("ok", false)):
		hud.show_toast("Test impossible : %s"
			% hud.first_blocking_reason(_validation), MapEditorHUD.Toast.ERROR)
		return

	_abort_stroke()
	_sandbox_active = not _sandbox_active

	if _sandbox_active:
		_enter_sandbox()
	else:
		_exit_sandbox()

	hud.set_sandbox_mode(_sandbox_active)
	sandbox_toggled.emit(_sandbox_active)

func _enter_sandbox() -> void:
	cursor.hide()
	preview_layer.hide()
	grid_backdrop.hide()
	cursor_light.enabled = false
	ambient.color = Charte.NOIR

	# La géométrie est reconstruite à chaque entrée : les murs ont pu changer.
	_clear_sandbox_content()
	if not _build_geometry(sandbox_layer):
		MapData.build_wall_collisions(walls_layer, sandbox_layer)

	_test_player = preload("res://player.tscn").instantiate()
	_test_player.set("player_id", 0)
	_test_player.set("hp", 99999.0)
	_test_player.set("ghost_hp", 99999.0)
	sandbox_layer.add_child(_test_player)

	var spawn := MapCodec.get_spawn(_cached_data, 0)
	_test_player.global_position = _cell_centre(spawn) if spawn.x >= 0 \
		else _cell_centre(grid_pos)

	sandbox_layer.show()
	camera.center_on(_test_player.global_position, true)
	hud.show_toast("Mode test — Rond ou Échap pour revenir", MapEditorHUD.Toast.INFO)

func _exit_sandbox() -> void:
	_clear_sandbox_content()
	sandbox_layer.hide()

	cursor.show()
	preview_layer.show()
	grid_backdrop.show()
	cursor_light.enabled = _light_preview
	ambient.color = Charte.NOIR.lerp(Charte.ACIER, 0.09) if _light_preview else Color.WHITE

	# L'édition reprend exactement là où elle s'était arrêtée.
	camera.center_on(_cell_centre(grid_pos), true)
	_update_cursor()
	hud.show_toast("Retour à l'édition", MapEditorHUD.Toast.INFO)

func _clear_sandbox_content() -> void:
	for child in sandbox_layer.get_children():
		sandbox_layer.remove_child(child)
		child.queue_free()
	_test_player = null

# ---------------------------------------------------------------------------
# NAVIGATION
# ---------------------------------------------------------------------------

func _go_back() -> void:
	if _sandbox_active:
		_toggle_sandbox()
		return

	# Deux temps quand du travail n'est pas sauvegardé : on ne perd pas une
	# carte sur une pression malheureuse.
	var now := Time.get_ticks_msec() / 1000.0
	if _dirty and now > _back_armed_until:
		_back_armed_until = now + BACK_CONFIRM_DELAY
		hud.show_toast("Modifications non sauvegardées — appuyez à nouveau pour quitter",
			MapEditorHUD.Toast.WARN)
		return

	get_tree().change_scene_to_file("res://main.tscn")

# ---------------------------------------------------------------------------
# DESSIN — GRILLE DE FOND
# ---------------------------------------------------------------------------

## Grille statique : redessinée uniquement au chargement d'une carte.
## L'opacité décroît vers les bords, ce qui donne de la profondeur sans
## ajouter de vignette.
func _on_grid_draw() -> void:
	var tile := Vector2(CandelaTileSet.TILE_SIZE)
	var full := Vector2(grid_size) * tile
	var centre := full * 0.5

	var points := PackedVector2Array()
	var colours := PackedColorArray()

	for x in range(grid_size.x + 1):
		for y in range(grid_size.y):
			var a := Vector2(x * tile.x, y * tile.y)
			var b := Vector2(x * tile.x, (y + 1) * tile.y)
			points.append(a)
			points.append(b)
			colours.append(_grid_colour((a + b) * 0.5, centre, full, x % 4 == 0))

	for y in range(grid_size.y + 1):
		for x in range(grid_size.x):
			var a := Vector2(x * tile.x, y * tile.y)
			var b := Vector2((x + 1) * tile.x, y * tile.y)
			points.append(a)
			points.append(b)
			colours.append(_grid_colour((a + b) * 0.5, centre, full, y % 4 == 0))

	if not points.is_empty():
		grid_backdrop.draw_multiline_colors(points, colours, 1.0)

	# Contour de la zone jouable.
	grid_backdrop.draw_rect(Rect2(Vector2.ZERO, full),
		Color(Charte.BLEU, 0.35), false, 2.0)

func _grid_colour(point: Vector2, centre: Vector2, full: Vector2, major: bool) -> Color:
	var normalised := (point - centre) / maxf(1.0, minf(full.x, full.y) * 0.5)
	var edge := clampf(maxf(absf(normalised.x), absf(normalised.y)), 0.0, 1.0)
	var alpha := lerpf(0.26, 0.03, edge)
	if major:
		alpha *= 1.9
	return Color(Charte.BLEU, alpha)

# ---------------------------------------------------------------------------
# DESSIN — APERÇUS
# ---------------------------------------------------------------------------

func _on_preview_draw() -> void:
	var tile := Vector2(CandelaTileSet.TILE_SIZE)

	# Zones de sol coupées du reste de la carte.
	for cell in _orphan_cells:
		preview_layer.draw_rect(Rect2(Vector2(cell) * tile, tile),
			Color(Charte.AMBRE, 0.20), true)

	_draw_spawn_marker(0)
	_draw_spawn_marker(1)

	if _stroke_active and _stroke_brush == Brush.RECT:
		_draw_rect_preview(tile)

func _draw_rect_preview(tile: Vector2) -> void:
	var r_min := Vector2i(mini(_stroke_anchor.x, grid_pos.x),
		mini(_stroke_anchor.y, grid_pos.y))
	var r_max := Vector2i(maxi(_stroke_anchor.x, grid_pos.x),
		maxi(_stroke_anchor.y, grid_pos.y))
	var rect := Rect2(Vector2(r_min) * tile, Vector2(r_max - r_min + Vector2i.ONE) * tile)

	var pulse := sin(_pulse * 5.0) * 0.5 + 0.5
	var colour := _step_colour() if _stroke_painting else Charte.ROUGE

	preview_layer.draw_rect(rect,
		Color(colour.r, colour.g, colour.b, 0.14 + 0.08 * pulse), true)
	preview_layer.draw_rect(rect,
		Color(colour.r, colour.g, colour.b, 0.65 + 0.35 * pulse), false, 2.5)

	var size := r_max - r_min + Vector2i.ONE
	preview_layer.draw_string(ThemeDB.fallback_font,
		rect.position + Vector2(6, 20),
		"%d × %d  (%d)" % [size.x, size.y, size.x * size.y],
		HORIZONTAL_ALIGNMENT_LEFT, -1, Charte.T_COURANT, Color(Charte.HALOGENE, 0.92))

func _draw_spawn_marker(index: int) -> void:
	var cell := tools.get_spawn(index)
	if cell == MapEditorTools.NO_CELL:
		return

	var tile := Vector2(CandelaTileSet.TILE_SIZE)
	var centre := Vector2(cell) * tile + tile * 0.5
	var colour := STEP_COLOURS[2 + index]
	var pulse := sin(_pulse * 3.0 + index * PI) * 0.5 + 0.5

	preview_layer.draw_circle(centre, tile.x * 0.42,
		Color(colour.r, colour.g, colour.b, 0.18 + 0.08 * pulse))
	preview_layer.draw_arc(centre, tile.x * 0.42, 0.0, TAU, 32,
		Color(colour.r, colour.g, colour.b, 0.95), 2.5)
	preview_layer.draw_string(ThemeDB.fallback_font,
		centre + Vector2(-9, 6), "J%d" % (index + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, colour)

# ---------------------------------------------------------------------------
# DESSIN — CURSEUR
# ---------------------------------------------------------------------------

## Curseur pulsant avec halo. Il indique aussi l'outil actif : anneau simple
## pour le pinceau, carré pour le rectangle, double anneau pour le pot.
func _on_cursor_draw() -> void:
	var tile := Vector2(CandelaTileSet.TILE_SIZE)
	var radius := tile.x * 0.44
	var pulse := sin(_pulse * 4.0) * 0.5 + 0.5
	var colour := _step_colour()
	var brush := _stroke_brush if _stroke_active else _current_brush()

	if _stroke_active and not _stroke_painting:
		colour = Charte.ROUGE

	# Halo
	cursor.draw_circle(Vector2.ZERO, radius * (1.25 + 0.12 * pulse),
		Color(colour.r, colour.g, colour.b, 0.08 + 0.05 * pulse))

	match brush:
		Brush.RECT:
			var half := tile * 0.44
			cursor.draw_rect(Rect2(-half, half * 2.0),
				Color(colour.r, colour.g, colour.b, 0.85 + 0.15 * pulse), false, 2.5)
		Brush.FILL:
			cursor.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32,
				Color(colour.r, colour.g, colour.b, 0.9), 2.5)
			cursor.draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 24,
				Color(colour.r, colour.g, colour.b, 0.55 + 0.35 * pulse), 2.0)
		_:
			cursor.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32,
				Color(colour.r, colour.g, colour.b, 0.8 + 0.2 * pulse), 2.5)

	cursor.draw_circle(Vector2.ZERO, 2.5, Color(Charte.HALOGENE, 0.95))
