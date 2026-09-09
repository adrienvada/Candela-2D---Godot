class_name LocalInputProvider
extends InputProvider

## p1_torch/p2_torch est une gâchette analogique (L2), pas un bouton — voir
## `input_setup.gd`. Un vrai bouton mécanique à deux crans monnaie cette
## profondeur : un appui léger n'éclaire que tenu, un appui À FOND clique et
## reste enclenché jusqu'au clic suivant. En dessous, seule la zone morte de
## l'Input Map (0.2, posée par `input_setup.gd`) filtre — c'est le premier
## cran. Une manette qui n'a que des boutons (rebind au clavier exclu, voir
## `_test_chaque_bloc_n_accepte_que_son_appareil`) ne connaît que 0 ou 1 : elle
## saute donc directement au second cran, ce qui est le comportement voulu
## d'un bouton qui n'a pas de course.
const TORCH_CRAN_FOND := 0.9

## Vrai tant que le cran plein reste enclenché : la torche reste allumée
## gâchette relâchée, jusqu'au prochain appui à fond qui la débascule.
var _torch_enclenchee := false
## Profondeur à l'image précédente, pour ne détecter que le FRONT montant du
## cran plein — sans lui, un appui tenu à fond re-basculerait à chaque image.
var _torch_etait_a_fond := false

@export var device_id: int = 0 :
	set(val):
		device_id = val
		_setup_inputs()

var action_up := ""
var action_down := ""
var action_left := ""
var action_right := ""
var action_aim_up := ""
var action_aim_down := ""
var action_aim_left := ""
var action_aim_right := ""
var action_shoot := ""
var action_torch := ""
var action_flare := ""
var action_reload := ""

func _ready() -> void:
	_setup_inputs()

func _setup_inputs() -> void:
	var prefix = "p1_" if device_id == 0 else "p2_"
	action_up = prefix + "move_up"
	action_down = prefix + "move_down"
	action_left = prefix + "move_left"
	action_right = prefix + "move_right"
	
	action_aim_up = prefix + "aim_up"
	action_aim_down = prefix + "aim_down"
	action_aim_left = prefix + "aim_left"
	action_aim_right = prefix + "aim_right"
	
	action_shoot = prefix + "shoot"
	action_torch = prefix + "torch"
	action_flare = prefix + "lance_fusee"
	action_reload = prefix + "reload"

func get_movement_vector() -> Vector2:
	return Input.get_vector(action_left, action_right, action_up, action_down)

func get_aim_direction(player_global_pos: Vector2) -> Vector2:
	var aim_dir := Input.get_vector(action_aim_left, action_aim_right, action_aim_up, action_aim_down)
	# Fallback to mouse aiming for P1 if no gamepad stick input is detected
	if aim_dir.length() < 0.1 and device_id == 0:
		var viewport = get_viewport()
		if viewport:
			var m_pos = viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
			aim_dir = player_global_pos.direction_to(m_pos)
	return aim_dir

func is_shoot_pressed() -> bool:
	return Input.is_action_pressed(action_shoot)

func is_flashlight_pressed() -> bool:
	var profondeur := Input.get_action_strength(action_torch)
	var a_fond := profondeur >= TORCH_CRAN_FOND
	if a_fond and not _torch_etait_a_fond:
		_torch_enclenchee = not _torch_enclenchee
	_torch_etait_a_fond = a_fond
	# `profondeur > 0.0` : la zone morte de l'action est déjà passée par
	# `get_action_strength`, donc équivalent à l'ancien `is_action_pressed` —
	# c'est le premier cran, qui n'ajoute rien au clic tant qu'il dure.
	return _torch_enclenchee or profondeur > 0.0

## Appelé à chaque nouvelle manche (voir `Player.reset_flashlight_latch()`) :
## un clic laissé enclenché avant la mort ne doit pas rallumer la torche tout
## seul au spawn suivant, sans qu'aucune gâchette n'ait bougé cette manche-là.
func reset_flashlight_state() -> void:
	_torch_enclenchee = false
	_torch_etait_a_fond = false

func is_flare_pressed() -> bool:
	return Input.is_action_pressed(action_flare)

func is_reload_pressed() -> bool:
	return Input.is_action_pressed(action_reload)
