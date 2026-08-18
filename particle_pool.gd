extends Node2D
class_name ParticlePool

## Réserve de particules physiques réutilisables (sang, étincelles).
##
## Chaque impact allouait auparavant jusqu'à 25 RigidBody2D neufs, chacun avec
## sa CollisionShape2D, sa Polygon2D, son CanvasItemMaterial, sa PointLight2D,
## sa GradientTexture2D et son Tween — puis les détruisait tous. Une rafale de
## pompe dans un mur, c'était plusieurs centaines d'objets créés et libérés en
## quelques frames, avec des lumières à ombres portées par-dessus.
##
## Ici les nœuds sont pré-alloués une fois pour toutes et recyclés :
##  - aucune allocation en cours de partie,
##  - aucune ombre portée sur les lumières de particules,
##  - un plafond global d'actives, la plus ancienne étant recyclée d'abord.
##
## L'animation (rétrécissement + extinction) est faite dans _process sur un
## tableau plat plutôt que par un Tween par particule.

const CAPACITY := 240
const MAX_ACTIVE := 200

## Profils d'impact. Le rendu reste celui d'avant : chair lourde et amortie,
## étincelles vives et rebondissantes. S'y ajoutent la fumée de bouche (V4.13,
## grise, additive, dérive lente après le flash) et la poussière de faisceau
## (V5.5, grains ténus qui ne vivent que dans la lumière d'une torche).
enum Kind { BLOOD, SPARK, SMOKE, DUST }

## V4.11 — l'éclat : les gouttes de sang brillent fort leurs premiers instants
## (leur lumière déjà sans ombre est brièvement surmultipliée) puis retombent
## sur le fondu normal. Toucher, c'est voir — sur les deux écrans.
const BLOOD_FLASH_DURATION := 0.2
const BLOOD_FLASH_BOOST := 2.0

var _pool: Array[RigidBody2D] = []
var _free: Array[RigidBody2D] = []
## Actives dans l'ordre d'émission : le recyclage part toujours du début.
var _active: Array[Dictionary] = []

var _mat_mix: CanvasItemMaterial
var _mat_add: CanvasItemMaterial
var _phys_blood: PhysicsMaterial
var _phys_spark: PhysicsMaterial

func _ready() -> void:
	add_to_group("particle_pool")
	initialize()

## Pré-alloue la réserve. Séparé de _ready pour être exerçable hors arbre de
## scène (tests headless).
func initialize() -> void:
	if not _pool.is_empty(): return
	_build_shared_resources()
	for i in CAPACITY:
		var p := _make_particle()
		add_child(p)
		_pool.append(p)
		_free.append(p)

func _build_shared_resources() -> void:
	_mat_mix = CanvasItemMaterial.new()
	_mat_mix.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_mat_mix.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	_mat_add = CanvasItemMaterial.new()
	_mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_mat_add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	_phys_blood = PhysicsMaterial.new()
	_phys_blood.bounce = 0.2

	_phys_spark = PhysicsMaterial.new()
	_phys_spark.bounce = 0.6

func _make_particle() -> RigidBody2D:
	var rb := RigidBody2D.new()
	rb.z_index = 10
	rb.collision_layer = 0
	rb.collision_mask = MapGeometry.WALL_LAYER
	rb.gravity_scale = 0.0 # Top-down
	rb.freeze = true
	rb.hide()

	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	shape.shape = CircleShape2D.new()
	rb.add_child(shape)

	var poly := Polygon2D.new()
	poly.name = "Poly"
	rb.add_child(poly)

	var light := PointLight2D.new()
	light.name = "Light"
	# Ombres portées systématiquement désactivées : 25 lumières à ombres par
	# impact, c'était le poste de rendu le plus lourd du jeu.
	light.shadow_enabled = false
	light.range_item_cull_mask = 1 | 4
	rb.add_child(light)

	return rb

## Émet `amount` particules depuis `pos`. Retourne le nombre réellement émis
## (toujours `amount` : le plafond recycle, il ne refuse pas).
func emit(kind: int, pos: Vector2, color: Color, amount: int,
		speed_min: float, speed_max: float, base_dir: Vector2, spread_deg: float) -> int:
	var spread_rad := deg_to_rad(spread_deg)
	for i in amount:
		var rb := _acquire()
		if rb == null:
			return i
		_configure(rb, kind, pos, color)

		var spray_angle := base_dir.angle() + randf_range(-spread_rad / 2.0, spread_rad / 2.0)
		var speed := randf_range(speed_min, speed_max)
		rb.linear_velocity = Vector2(cos(spray_angle), sin(spray_angle)) * speed

		var lifetime: float
		match kind:
			Kind.BLOOD: lifetime = randf_range(1.5, 3.0)
			Kind.SMOKE: lifetime = randf_range(0.8, 1.4)
			Kind.DUST: lifetime = randf_range(0.9, 1.6)
			_: lifetime = randf_range(0.3, 0.8)
		_active.append({
			"rb": rb,
			"age": 0.0,
			"life": lifetime,
			"scale": rb.get_node("Poly").scale,
			"energy": (rb.get_node("Light") as PointLight2D).energy,
			"flash": BLOOD_FLASH_DURATION if kind == Kind.BLOOD else 0.0,
		})
	return amount

## Une particule libre, en recyclant la plus ancienne active si le plafond est
## atteint. Null seulement si la réserve est vide ET rien n'est actif.
func _acquire() -> RigidBody2D:
	if _active.size() >= MAX_ACTIVE or _free.is_empty():
		if _active.is_empty():
			return null
		_retire(0)
	return _free.pop_back()

func _configure(rb: RigidBody2D, kind: int, pos: Vector2, color: Color) -> void:
	var poly := rb.get_node("Poly") as Polygon2D
	var light := rb.get_node("Light") as PointLight2D
	var circle := (rb.get_node("Shape") as CollisionShape2D).shape as CircleShape2D

	if kind == Kind.BLOOD:
		circle.radius = 2.0
		var s := randf_range(0.8, 3.5)
		poly.polygon = PackedVector2Array([
			Vector2(-2 * s, 0), Vector2(0, -2 * s), Vector2(2 * s, 0), Vector2(0, 2 * s)])
		poly.material = _mat_mix
		light.texture = LightTextures.radial(64)
		# V4.11 — l'éclat de l'impact : surmultipliée à l'émission, la lumière
		# retombe à 1.0 en BLOOD_FLASH_DURATION (voir advance()).
		light.energy = 1.0
		rb.linear_damp = randf_range(8.0, 15.0) # Turbulence : friction lourde
		rb.angular_velocity = randf_range(-40.0, 40.0)
		rb.physics_material_override = _phys_blood
	elif kind == Kind.SMOKE:
		# V4.13 — fumée de bouche : gros grain additif, sans lumière, qui
		# dérive puis s'éteint. La friction fait tout le travail de « nuage ».
		circle.radius = 1.0
		var s := randf_range(2.5, 4.5)
		poly.polygon = PackedVector2Array([
			Vector2(-2 * s, 0), Vector2(0, -2 * s), Vector2(2 * s, 0), Vector2(0, 2 * s)])
		poly.material = _mat_add
		light.texture = LightTextures.radial(32)
		light.energy = 0.0
		rb.linear_damp = randf_range(5.0, 7.0)
		rb.angular_velocity = randf_range(-6.0, 6.0)
		rb.physics_material_override = _phys_blood
	elif kind == Kind.DUST:
		# V5.5 — poussière de faisceau : grain ténu, additif, presque immobile.
		# Aucune lumière propre : il n'existe que révélé par la torche — et le
		# matériau additif le laisse deviner en fantôme dans le cône.
		circle.radius = 1.0
		var s := randf_range(0.5, 1.0)
		poly.polygon = PackedVector2Array([
			Vector2(-1 * s, 0), Vector2(0, -1 * s), Vector2(1 * s, 0), Vector2(0, 1 * s)])
		poly.material = _mat_add
		light.texture = LightTextures.radial(32)
		light.energy = 0.0
		rb.linear_damp = randf_range(2.0, 3.0)
		rb.angular_velocity = randf_range(-2.0, 2.0)
		rb.physics_material_override = _phys_blood
	else:
		circle.radius = 1.0
		poly.polygon = PackedVector2Array([
			Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0), Vector2(0, 1)])
		poly.material = _mat_add
		light.texture = LightTextures.radial(32)
		light.energy = 1.5
		rb.linear_damp = randf_range(1.0, 4.0) # Étincelles volatiles
		rb.angular_velocity = randf_range(-20.0, 20.0)
		rb.physics_material_override = _phys_spark

	poly.color = color
	poly.scale = Vector2.ONE
	poly.modulate.a = 1.0
	light.color = color

	rb.position = pos
	rb.rotation = 0.0
	rb.freeze = false
	rb.show()

## Remet la particule d'indice `idx` en réserve.
func _retire(idx: int) -> void:
	var entry: Dictionary = _active[idx]
	var rb: RigidBody2D = entry["rb"]
	_active.remove_at(idx)
	rb.freeze = true
	rb.linear_velocity = Vector2.ZERO
	rb.angular_velocity = 0.0
	rb.hide()
	_free.append(rb)

func _process(delta: float) -> void:
	advance(delta)

## Fait vieillir les particules actives et rend celles qui ont fini leur course.
func advance(delta: float) -> void:
	var i := 0
	while i < _active.size():
		var entry: Dictionary = _active[i]
		entry["age"] = float(entry["age"]) + delta
		var t: float = clampf(float(entry["age"]) / float(entry["life"]), 0.0, 1.0)
		if t >= 1.0:
			_retire(i)
			continue
		# TRANS_QUAD / EASE_IN, comme les tweens d'origine.
		var eased := 1.0 - t * t
		var rb: RigidBody2D = entry["rb"]
		(rb.get_node("Poly") as Polygon2D).scale = (entry["scale"] as Vector2) * eased
		var energie := float(entry["energy"]) * eased
		# V4.11 — l'éclat des premiers instants, décroissance linéaire.
		var flash: float = float(entry.get("flash", 0.0))
		if flash > 0.0:
			flash -= delta
			entry["flash"] = flash
			energie += float(entry["energy"]) * BLOOD_FLASH_BOOST * maxf(flash, 0.0) / BLOOD_FLASH_DURATION
		(rb.get_node("Light") as PointLight2D).energy = energie
		i += 1

## Renvoie tout en réserve (début de manche, retour au menu).
func clear_all() -> void:
	while not _active.is_empty():
		_retire(0)

func active_count() -> int:
	return _active.size()

func free_count() -> int:
	return _free.size()
