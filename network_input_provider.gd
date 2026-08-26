class_name NetworkInputProvider
extends InputProvider

# Stocke l'état des commandes sous forme d'une structure légère mise à jour par paquets/RPC
var current_movement := Vector2.ZERO
var current_aim := Vector2.ZERO
var shoot_pressed := false
var flashlight_pressed := false

func get_movement_vector() -> Vector2:
	return current_movement

func get_aim_direction(_player_global_pos: Vector2) -> Vector2:
	return current_aim

func is_shoot_pressed() -> bool:
	return shoot_pressed

func is_flashlight_pressed() -> bool:
	return flashlight_pressed

## Alimenté par les paquets d'input du client, consommé par la simulation hôte.
func update_input_state(movement: Vector2, aim: Vector2, shoot: bool, flashlight: bool) -> void:
	current_movement = movement
	current_aim = aim
	shoot_pressed = shoot
	flashlight_pressed = flashlight

## Remet les commandes au neutre : le dernier paquet reçu ne doit pas survivre
## à la déconnexion de son émetteur.
func reset_input_state() -> void:
	current_movement = Vector2.ZERO
	current_aim = Vector2.ZERO
	shoot_pressed = false
	flashlight_pressed = false
