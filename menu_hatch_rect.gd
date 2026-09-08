class_name MenuHatchRect
extends ColorRect

## Composant d'interface réutilisable pour trames d'encrage, hachures & sérigraphie.
##
## Étape 2 de la refonte « Roman Graphique Brutaliste » de Candela 2D.
## Encapsule le shader `menu_hatch.gdshader` pour offrir :
## - Trames de hachures à 45° manuelles et hachures croisées.
## - Trames de demi-teinte de sérigraphie (halftone dots).
## - Bordures physiques aux aspérités de plume / Rotring sur papier canson.
## - Modes d'alerte pulsation / défilement pour barres et cartouches HUD critiques.
## - Synchronisation automatique de la taille du rectangle avec le GPU.

const Charte := preload("res://charte.gd")
const SHADER_HATCH := preload("res://menu_hatch.gdshader")

enum PatternMode {
	SINGLE_45 = 0,
	CROSS = 1,
	HALFTONE = 2,
	ROTRING = 3,
}

var _mat: ShaderMaterial

# --- Propriétés exposées ---
var pattern_mode: int = PatternMode.SINGLE_45:
	set(v):
		pattern_mode = v
		_update_param("pattern_mode", pattern_mode)

var spacing: float = 10.0:
	set(v):
		spacing = v
		_update_param("spacing", spacing)

var line_width: float = 1.6:
	set(v):
		line_width = v
		_update_param("line_width", line_width)

var angle_deg: float = 45.0:
	set(v):
		angle_deg = v
		_update_param("angle_deg", angle_deg)

var density: float = 0.5:
	set(v):
		density = v
		_update_param("density", density)

var color_ink: Color = Charte.NOIR:
	set(v):
		color_ink = v
		_update_param("color_ink", color_ink)

var color_line: Color = Charte.LINE:
	set(v):
		color_line = v
		_update_param("color_line", color_line)

var roughness: float = 0.0:
	set(v):
		roughness = v
		_update_param("roughness", roughness)

var grain_intensity: float = 0.035:
	set(v):
		grain_intensity = v
		_update_param("grain_intensity", grain_intensity)

var alpha_mix: float = 1.0:
	set(v):
		alpha_mix = v
		_update_param("alpha_mix", alpha_mix)

var border_width: float = 0.0:
	set(v):
		border_width = v
		_update_param("border_width", border_width)

var border_color: Color = Charte.LINE:
	set(v):
		border_color = v
		_update_param("border_color", border_color)

var border_roughness: float = 0.4:
	set(v):
		border_roughness = v
		_update_param("border_roughness", border_roughness)

var alert_pulse: float = 0.0:
	set(v):
		alert_pulse = v
		_update_param("alert_pulse", alert_pulse)

var speed: float = 0.0:
	set(v):
		speed = v
		_update_param("speed", speed)

var use_local_coords: bool = true:
	set(v):
		use_local_coords = v
		_update_param("use_local_coords", use_local_coords)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_material()

func _ready() -> void:
	_init_material()
	_sync_all_params()
	resized.connect(_on_resized)
	_sync_size()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_size()

func _init_material() -> void:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER_HATCH
		material = _mat

func _update_param(param_name: String, val: Variant) -> void:
	if _mat != null:
		_mat.set_shader_parameter(param_name, val)

func _sync_size() -> void:
	if _mat != null:
		var s := size
		if s.x <= 0.0 or s.y <= 0.0:
			s = custom_minimum_size
		if s.x <= 0.0:
			s.x = 100.0
		if s.y <= 0.0:
			s.y = 100.0
		_mat.set_shader_parameter("rect_size", s)

func _on_resized() -> void:
	_sync_size()

func _sync_all_params() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("pattern_mode", pattern_mode)
	_mat.set_shader_parameter("spacing", spacing)
	_mat.set_shader_parameter("line_width", line_width)
	_mat.set_shader_parameter("angle_deg", angle_deg)
	_mat.set_shader_parameter("density", density)
	_mat.set_shader_parameter("color_ink", color_ink)
	_mat.set_shader_parameter("color_line", color_line)
	_mat.set_shader_parameter("roughness", roughness)
	_mat.set_shader_parameter("grain_intensity", grain_intensity)
	_mat.set_shader_parameter("alpha_mix", alpha_mix)
	_mat.set_shader_parameter("border_width", border_width)
	_mat.set_shader_parameter("border_color", border_color)
	_mat.set_shader_parameter("border_roughness", border_roughness)
	_mat.set_shader_parameter("alert_pulse", alert_pulse)
	_mat.set_shader_parameter("speed", speed)
	_mat.set_shader_parameter("use_local_coords", use_local_coords)
	_sync_size()

## Renvoie le ShaderMaterial instancié
func get_shader_material() -> ShaderMaterial:
	_init_material()
	return _mat

# =============================================================================
# PRÉRÉGLAGES RAPIDES CONFORMES À LA CHARTE
# =============================================================================

## Configure pour un fond de panneau inactif ou désactivé
func apply_preset_inactive(accent: Color = Charte.LINE) -> void:
	pattern_mode = PatternMode.CROSS
	color_ink = Charte.SURFACE
	color_line = accent
	density = 0.35
	spacing = 12.0
	line_width = 1.4
	roughness = 0.20
	border_width = 0.0
	alert_pulse = 0.0
	speed = 0.0

## Configure pour une trame de demi-teinte (halftone sérigraphique)
func apply_preset_halftone(ink: Color = Charte.NOIR, dots: Color = Charte.LINE,
		dot_spacing: float = 8.0, dot_density: float = 0.5) -> void:
	pattern_mode = PatternMode.HALFTONE
	color_ink = ink
	color_line = dots
	spacing = dot_spacing
	density = dot_density
	roughness = 0.15
	border_width = 0.0
	alert_pulse = 0.0
	speed = 0.0

## Configure un cadre avec bordure au trait de plume / Rotring
func apply_preset_rotring_panel(accent: Color = Charte.LINE,
		b_width: float = 2.0, rough: float = 0.45) -> void:
	border_width = b_width
	border_color = accent
	border_roughness = rough

## Active ou désactive le mode d'alerte critique (santé faible ou munitions épuisées)
func set_alert(active: bool, alert_color: Color = Charte.AMBRE, pulse_speed: float = 2.0) -> void:
	if active:
		pattern_mode = PatternMode.SINGLE_45
		color_line = alert_color
		spacing = 9.0
		line_width = 2.2
		alert_pulse = 1.0
		speed = pulse_speed
		roughness = 0.25
	else:
		alert_pulse = 0.0
		speed = 0.0
		line_width = 1.6
		roughness = 0.0
