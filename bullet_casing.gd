class_name BulletCasing
extends Node2D

## Douille de balle persistante d'atelier (DA Roman Graphique Brutaliste).
##
## Éjectée au tir ou au rechargement (pistolet, fusil, pompe), elle roule et glisse
## au sol avec une légère inertie physique puis s'immobilise.
## Dès l'arrêt complet, tout calcul de process est coupé (coût CPU nul).
##
## Persistance identique aux taches de sang (blood_stain.gd) :
## - Survie entre les manches d'un match.
## - Plafond persistant (MAX_CASINGS) avec éviction de la doyenne.
## - Support de l'écran scindé (copie P2 aux masques dédiés).

const Charte := preload("res://charte.gd")

## Plafond de douilles simultanées (la copie J2 ne compte pas).
## static var pour permettre aux tests d'abaisser le seuil.
static var MAX_CASINGS := 120

## Rang global strictement croissant sur la session pour l'éviction FIFO.
static var _next_order := 0

const FRICTION := 320.0
const ANGULAR_FRICTION := 24.0

var weapon_slug: String = "pistolet"
var velocity: Vector2 = Vector2.ZERO
var angular_velocity: float = 0.0
var at_rest: bool = false
var _order: int = 0
var _p2_copy: Node2D = null


## Éjecte une douille dans l'arène.
static func eject(arena: Node, spawn_pos: Vector2, shoot_dir: Vector2,
		slug: String = "pistolet") -> BulletCasing:
	if arena == null:
		return null
	var casing: Node2D = (preload("res://bullet_casing.gd") as GDScript).new()
	casing.setup(spawn_pos, shoot_dir, slug)
	arena.add_child(casing)
	return casing


func setup(pos: Vector2, shoot_dir: Vector2, slug: String) -> void:
	position = pos
	weapon_slug = slug
	z_index = 0 # Posé sur les dalles de sol

	# Viewport J1 (2) : torche (1) + ambiance J1 (16)
	visibility_layer = 2
	light_mask = 1 | 16

	# Angle d'éjection latéral / arrière (vers la droite du tireur en majorité)
	var cote := 1.0 if randf() > 0.25 else -1.0
	var eject_angle := shoot_dir.angle() + cote * randf_range(PI * 0.35, PI * 0.65)
	var speed := randf_range(70.0, 150.0)
	velocity = Vector2.from_angle(eject_angle) * speed
	angular_velocity = randf_range(-16.0, 16.0)
	rotation = randf() * TAU
	at_rest = false
	set_process(true)
	queue_redraw()


func _ready() -> void:
	if is_in_group("casing_p2"):
		return

	_order = _next_order
	_next_order += 1

	while get_tree().get_nodes_in_group("bullet_casing").size() >= MAX_CASINGS:
		_evict_oldest()

	add_to_group("bullet_casing")
	call_deferred("_create_p2_duplicate")


func _process(delta: float) -> void:
	if at_rest:
		return

	position += velocity * delta
	rotation += angular_velocity * delta

	velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	angular_velocity = move_toward(angular_velocity, 0.0, ANGULAR_FRICTION * delta)

	if velocity.length_squared() < 4.0 and absf(angular_velocity) < 0.1:
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		at_rest = true
		set_process(false) # Désactivation complète du process au repos


func _draw() -> void:
	# Dessin vectoriel contrasté Roman Graphique Brutaliste
	match weapon_slug:
		"fusil":
			# Étui de fusil allongé avec collet et culot
			# Culot sombre
			draw_rect(Rect2(-2.5, -0.9, 0.8, 1.8), Charte.LINE)
			# Corps laiton
			draw_rect(Rect2(-1.7, -0.9, 3.2, 1.8), Charte.AMBRE)
			# Reflet halogène sur le haut du cylindre
			draw_line(Vector2(-1.7, -0.6), Vector2(1.5, -0.6), Charte.HALOGENE * 0.85, 0.5)
			# Collet resserré
			draw_rect(Rect2(1.5, -0.6, 1.0, 1.2), Charte.AMBRE.lerp(Charte.LINE, 0.3))
		"pompe":
			# Cartouche de calibre 12 : culot laiton doré + corps sombre/carmin
			# Culot laiton
			draw_rect(Rect2(-2.2, -1.2, 1.2, 2.4), Charte.AMBRE)
			# Corps de cartouche
			var corps_color := Charte.CARMIN.lerp(Charte.NOIR, 0.3)
			draw_rect(Rect2(-1.0, -1.2, 3.2, 2.4), corps_color)
			# Liseré d'ouverture
			draw_line(Vector2(2.2, -1.2), Vector2(2.2, 1.2), Charte.LINE, 0.6)
		_:
			# Pistolet / standard : douille 9mm compacte
			# Culot
			draw_rect(Rect2(-1.8, -0.9, 0.6, 1.8), Charte.LINE)
			# Douille laiton
			draw_rect(Rect2(-1.2, -0.9, 3.0, 1.8), Charte.AMBRE)
			# Reflet supérieur
			draw_line(Vector2(-1.2, -0.6), Vector2(1.8, -0.6), Charte.HALOGENE * 0.85, 0.5)


func _evict_oldest() -> void:
	var oldest = null
	for casing in get_tree().get_nodes_in_group("bullet_casing"):
		if oldest == null or casing._order < oldest._order:
			oldest = casing
	if oldest != null:
		oldest.release()


func release() -> void:
	remove_from_group("bullet_casing")
	if is_instance_valid(_p2_copy):
		_p2_copy.queue_free()
	queue_free()


func _create_p2_duplicate() -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	if get_parent() and not is_in_group("casing_p2"):
		var copy := duplicate() as Node2D
		copy.remove_from_group("bullet_casing")
		copy.add_to_group("casing_p2")
		copy.visibility_layer = 4 # Viewport J2
		copy.light_mask = 1 | 32  # Torche + ambiance J2
		copy.weapon_slug = weapon_slug
		copy.velocity = velocity
		copy.angular_velocity = angular_velocity
		copy.at_rest = at_rest
		copy.set_process(not at_rest)
		copy.queue_redraw()
		get_parent().add_child(copy)
		_p2_copy = copy
