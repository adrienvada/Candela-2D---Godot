class_name InputProvider
extends Node

func get_movement_vector() -> Vector2:
	return Vector2.ZERO

func get_aim_direction(_player_global_pos: Vector2) -> Vector2:
	return Vector2.ZERO

func is_shoot_pressed() -> bool:
	return false

func is_flashlight_pressed() -> bool:
	return false

func is_sprint_pressed() -> bool:
	return false
