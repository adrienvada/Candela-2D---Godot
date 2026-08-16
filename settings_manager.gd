extends Node
## Préférences persistées du joueur : vsync, plafond d'images par seconde,
## résolution et remappage des touches.
##
## Norme du jeu compétitif : vsync désactivé, aucun plafond par défaut — voir
## la décision « Images par seconde déplafonnées » dans docs/ROADMAP.md.
##
## Cet autoload est déclaré APRÈS InputSetup dans project.godot, et c'est ce qui
## rend le remappage persistant possible : les liaisons enregistrées s'appliquent
## par-dessus les liaisons par défaut, jamais l'inverse.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_VIDEO := "video"
const SECTION_DISPLAY := "display"
const SECTION_INPUT := "input"

## 0 = déplafonné.
const FPS_CAPS: Array[int] = [0, 60, 120, 144, 240]

## Les trois modes proposés par le menu : fenêtré 1280, fenêtré 1920, plein
## écran.
const RESOLUTION_COUNT := 3

var vsync_enabled := false
var fps_cap := 0
var resolution_index := 0

## action -> description sérialisable de l'événement de manette assigné.
var _bindings: Dictionary = {}

## Une résolution n'est appliquée au démarrage que si elle a été choisie une
## fois : sans ça, une installation neuve verrait sa fenêtre recentrée d'office.
var _has_saved_resolution := false

func _ready() -> void:
	_load()
	_apply_video()
	if _has_saved_resolution:
		_apply_resolution()
	_apply_bindings()

# ---------------------------------------------------------------------------
# API publique
# ---------------------------------------------------------------------------

func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	_apply_video()
	_save()

func set_fps_cap(cap: int) -> void:
	fps_cap = cap if FPS_CAPS.has(cap) else 0
	_apply_video()
	_save()

func set_resolution(index: int) -> void:
	resolution_index = index if index >= 0 and index < RESOLUTION_COUNT else 0
	_has_saved_resolution = true
	_apply_resolution()
	_save()

## Enregistre la liaison choisie pour une action. L'événement a déjà été posé
## dans l'InputMap par l'appelant ; on ne fait que le retenir pour le prochain
## lancement.
func set_binding(action: String, event: InputEvent) -> void:
	var desc := _event_to_dict(event)
	if desc.is_empty():
		return
	_bindings[action] = desc
	_save()

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------

func _apply_video() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = fps_cap

func _apply_resolution() -> void:
	match resolution_index:
		0: _apply_windowed(Vector2i(1280, 720))
		1: _apply_windowed(Vector2i(1920, 1080))
		2:
			# N'active le plein écran que sur le jeu final exporté : en débogage
			# il masquerait l'éditeur et la console.
			if not OS.is_debug_build():
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _apply_windowed(size: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	var screen_size := DisplayServer.screen_get_size()
	if screen_size.x > 0 and screen_size.y > 0:
		DisplayServer.window_set_position((screen_size - size) / 2)

func _apply_bindings() -> void:
	for action in _bindings:
		var name := String(action)
		if not InputMap.has_action(name):
			continue
		_erase_joypad_events(name)
		var event := _event_from_dict(_bindings[action])
		if event != null:
			InputMap.action_add_event(name, event)

## Ne retire que les événements de manette : le clavier et la souris définis
## dans project.godot doivent survivre au remappage, sinon rebinder une action
## à la manette la rendrait injouable au clavier.
func _erase_joypad_events(action: String) -> void:
	for ev in InputMap.action_get_events(action):
		var is_trigger := ev is InputEventJoypadMotion \
			and ((ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_LEFT
				or (ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT)
		if ev is InputEventJoypadButton or is_trigger:
			InputMap.action_erase_event(action, ev)

# ---------------------------------------------------------------------------
# Sérialisation des liaisons
# ---------------------------------------------------------------------------

## Seuls les deux types produits par le remappage sont représentés : bouton de
## manette et gâchette analogique.
static func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventJoypadButton:
		var btn := event as InputEventJoypadButton
		return {"type": "button", "code": btn.button_index, "device": btn.device}
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return {
			"type": "axis", "code": motion.axis,
			"value": motion.axis_value, "device": motion.device,
		}
	return {}

## Un fichier de préférences trafiqué ou issu d'une version antérieure ne doit
## pas empêcher le jeu de démarrer : une description illisible est ignorée.
static func _event_from_dict(desc: Variant) -> InputEvent:
	if not desc is Dictionary:
		return null
	var d: Dictionary = desc
	match String(d.get("type", "")):
		"button":
			var btn := InputEventJoypadButton.new()
			btn.button_index = int(d.get("code", 0))
			btn.device = int(d.get("device", 0))
			return btn
		"axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(d.get("code", 0))
			motion.axis_value = float(d.get("value", 1.0))
			motion.device = int(d.get("device", 0))
			return motion
	return null

# ---------------------------------------------------------------------------
# Persistance
# ---------------------------------------------------------------------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return

	vsync_enabled = cfg.get_value(SECTION_VIDEO, "vsync_enabled", false)
	var loaded_cap: int = cfg.get_value(SECTION_VIDEO, "fps_cap", 0)
	fps_cap = loaded_cap if FPS_CAPS.has(loaded_cap) else 0

	if cfg.has_section_key(SECTION_DISPLAY, "resolution_index"):
		var idx: int = cfg.get_value(SECTION_DISPLAY, "resolution_index", 0)
		resolution_index = idx if idx >= 0 and idx < RESOLUTION_COUNT else 0
		_has_saved_resolution = true

	if cfg.has_section(SECTION_INPUT):
		for action in cfg.get_section_keys(SECTION_INPUT):
			var desc: Variant = cfg.get_value(SECTION_INPUT, action, {})
			if desc is Dictionary and not (desc as Dictionary).is_empty():
				_bindings[action] = desc

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_VIDEO, "vsync_enabled", vsync_enabled)
	cfg.set_value(SECTION_VIDEO, "fps_cap", fps_cap)
	if _has_saved_resolution:
		cfg.set_value(SECTION_DISPLAY, "resolution_index", resolution_index)
	for action in _bindings:
		cfg.set_value(SECTION_INPUT, String(action), _bindings[action])
	cfg.save(SETTINGS_PATH)
