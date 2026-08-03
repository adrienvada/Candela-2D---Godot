class_name LocalInputProvider
extends InputProvider

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
var action_sprint := ""

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
	action_sprint = prefix + "sprint"

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
	return Input.is_action_pressed(action_torch)

func is_sprint_pressed() -> bool:
	return Input.is_action_pressed(action_sprint)
