class_name NetworkInputProvider
extends InputProvider

# Stocke l'état des commandes sous forme d'une structure légère mise à jour par paquets/RPC
var current_movement := Vector2.ZERO
var current_aim := Vector2.ZERO
var shoot_pressed := false
var flashlight_pressed := false
var sprint_pressed := false

func get_movement_vector() -> Vector2:
	return current_movement

func get_aim_direction(_player_global_pos: Vector2) -> Vector2:
	return current_aim

func is_shoot_pressed() -> bool:
	return shoot_pressed

func is_flashlight_pressed() -> bool:
	return flashlight_pressed

func is_sprint_pressed() -> bool:
	return sprint_pressed

# Méthode pour recevoir les updates (préparation pour la Phase 2)
func update_input_state(movement: Vector2, aim: Vector2, shoot: bool, flashlight: bool, sprint: bool) -> void:
	current_movement = movement
	current_aim = aim
	shoot_pressed = shoot
	flashlight_pressed = flashlight
	sprint_pressed = sprint
