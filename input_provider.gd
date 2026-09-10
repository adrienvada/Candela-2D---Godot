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

## Remise à zéro de l'état propre à la torche (le cran plein d'un bouton
## mécanique à deux crans, pour les fournisseurs qui en gardent un). No-op par
## défaut : seul `LocalInputProvider` a une mémoire à effacer.
func reset_flashlight_state() -> void:
	pass

## Le verrou du cran plein : vrai quand la torche reste allumée gâchette
## relâchée. Lu par le HUD, qui le dessine en cadenas sur l'icône de torche.
##
## ⚠️ **Un état de GESTE, pas de jeu** : il ne se réplique pas. Un fournisseur
## réseau répond donc toujours faux, et c'est voulu — l'adversaire n'a pas à
## savoir comment l'autre tient sa torche, seulement si elle est allumée.
func is_flashlight_locked() -> bool:
	return false

func is_flare_pressed() -> bool:
	return false

func is_reload_pressed() -> bool:
	return false

## Le gadget de la classe — chantier CLASSES, étape 4.
func is_gadget_pressed() -> bool:
	return false