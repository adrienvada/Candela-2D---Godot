extends Node2D
class_name Bullet

var weapon: WeaponData
var bounces_left: int = 0
var is_replay: bool = false

var source_player: Node2D
var direction: Vector2 = Vector2.ZERO
var distance_traveled: float = 0.0
var radius: float = 4.0

# Compensation de latence : quand `lag_target` est renseigné (tirs du client,
# arbitrés par l'hôte), ce joueur est testé contre `lag_center` — la position
# que le tireur voyait — et retiré du ShapeCast, qui ne connaît que le présent.
const PLAYER_BODY_RADIUS := 18.0
var lag_target: Player
var lag_center: Vector2 = Vector2.ZERO

var shape_cast: ShapeCast2D
var light: PointLight2D
var spawn_pos: Vector2

# Matériau additif non éclairé, identique pour toutes les balles.
static var _shared_additive: CanvasItemMaterial

static func _additive_material() -> CanvasItemMaterial:
	if _shared_additive == null:
		_shared_additive = CanvasItemMaterial.new()
		_shared_additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_shared_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _shared_additive

func _ready():
	z_index = 10
	# Add a dynamic point light to the bullet itself
	light = PointLight2D.new()
	light.name = "TrailLight"
	light.color = Color(1.0, 0.9, 0.5)
	light.energy = 50.0
	# Texture partagée : chaque balle en allouait une identique de 128×128, soit
	# cinq par volée de pompe.
	var grad_tex := LightTextures.radial_tight(128)
	light.texture = grad_tex
	light.shadow_enabled = true
	light.shadow_item_cull_mask = 1 | 4 # Casts shadows from walls(1) and players(4)
	light.range_item_cull_mask = 1 | 2 | 4 # Trail light illuminates players (2)
	add_child(light)
	
	var core = Line2D.new()
	core.name = "Core"
	core.width = 5.0
	# Bright molten metal yellow, HDR values for intense glow
	core.default_color = Color(2.5, 2.0, 0.5, 1.0)
	var mat := _additive_material()
	core.material = mat
	add_child(core)
	
	# Add a glowing aura Sprite2D so the glow is visible even over the darkened killcam overlay
	var aura = Sprite2D.new()
	aura.name = "Aura"
	aura.texture = grad_tex # Reuse the gradient texture from the light
	aura.modulate = Color(1.0, 0.9, 0.5, 0.6) # Match bullet color, slightly transparent
	aura.material = mat # Reuse the unshaded, additive material (mat is already BLEND_MODE_ADD)
	aura.scale = Vector2(1.5, 1.5) # Reduced scale to make it less thick
	add_child(aura)
	
	if weapon:
		bounces_left = weapon.max_bounces
		
		# Apply custom visual parameters
		core.default_color = weapon.bullet_color
		core.width = weapon.bullet_width
		
		if not weapon.emits_light:
			light.enabled = false
			aura.visible = false
			core.material = null # Use default shaded material
		else:
			light.energy = weapon.bullet_light_energy
	
	# ShapeCast for accurate collision
	shape_cast = ShapeCast2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape_cast.shape = circle
	shape_cast.target_position = Vector2.ZERO
	shape_cast.max_results = 1
	add_child(shape_cast)
	if source_player:
		shape_cast.add_exception(source_player)
	if lag_target:
		shape_cast.add_exception(lag_target)

	set_as_top_level(true)
	spawn_pos = global_position

func _physics_process(delta):
	if not weapon:
		queue_free()
		return
		
	var step = direction * weapon.bullet_speed * delta
	var travel_step = step.length()
	
	distance_traveled += travel_step
	if distance_traveled >= weapon.bullet_max_distance:
		_fade_and_destroy(global_position)
		return
		
	# Update shape cast for this frame's movement. target_position is in local space!
	shape_cast.target_position = Vector2(travel_step, 0)
	shape_cast.force_shapecast_update()

	# Cible compensée : test manuel segment/cercle, le ShapeCast ne la voit plus.
	# Un mur touché plus tôt sur le pas l'emporte toujours.
	if lag_target and is_instance_valid(lag_target) and (lag_target.hp > 0 or is_replay):
		var lag_dist := _circle_entry_distance(global_position, direction, travel_step,
			lag_center, PLAYER_BODY_RADIUS + radius)
		if lag_dist >= 0.0:
			var wall_first := shape_cast.is_colliding() \
				and global_position.distance_to(shape_cast.get_collision_point(0)) < lag_dist
			if not wall_first:
				_hit_player(lag_target, lag_center, global_position + direction * lag_dist)
				return

	if shape_cast.is_colliding():
		var collider = shape_cast.get_collider(0)
		var hit_point = shape_cast.get_collision_point(0)

		if collider is Player and (collider.hp > 0 or is_replay):
			_hit_player(collider, collider.global_position, hit_point)
			return
		elif collider is TrainingTarget:
			_hit_training_target(collider, hit_point)
			return
		else:
			_spawn_wall_effects(hit_point)
			
			if bounces_left > 0:
				bounces_left -= 1
				var normal = shape_cast.get_collision_normal(0)
				direction = direction.bounce(normal)
				rotation = direction.angle()
				global_position = hit_point + normal * (radius + 2.0)
				spawn_pos = global_position # Reset trail origin
				
				# Allow damaging the shooter after a bounce
				if weapon.damages_shooter:
					shape_cast.clear_exceptions()
					# La cible compensée reste testée à la main, rebond compris.
					if lag_target:
						shape_cast.add_exception(lag_target)
					
				return
			else:
				_fade_and_destroy(hit_point)
				return
		
	global_position += step
	
	# Stretch the light and core to form a long laser trail
	var dist_from_spawn = global_position.distance_to(spawn_pos)
	var trail_length = min(dist_from_spawn, 800.0)
	light.rotation = 0.0
	light.scale = Vector2(max(1.0, trail_length / 128.0), 0.15)
	light.position = -Vector2(trail_length / 2.0, 0)
	
	if has_node("Core"):
		get_node("Core").points = PackedVector2Array([Vector2.ZERO, Vector2(-trail_length, 0)])

## Impact joueur. `center` est le point de référence pour l'atténuation : la
## position réelle du joueur, ou celle remontée dans le temps quand le tir est
## compensé.
func _hit_player(target: Player, center: Vector2, hit_point: Vector2) -> void:
	# Damage falloff based on the perpendicular distance from the bullet's path to the player's center
	var player_radius := 15.0 # 15.0 * 1.0 (scale)
	var to_player := center - global_position
	var dist_to_axis: float = abs(to_player.cross(direction))
	var normalized_dist := clampf(dist_to_axis / player_radius, 0.0, 1.0)

	# Linear falloff based on weapon damage
	var opp_hit_damage := floorf(lerpf(weapon.damage_center, weapon.damage_edge, normalized_dist))

	# Kill probable, jugé sur les HP visibles localement : exact chez l'hôte,
	# prédictif chez le client — purement cosmétique dans les deux cas.
	var lethal := not is_replay and (target.hp - opp_hit_damage) <= 0.0
	if not is_replay:
		# V2.9 — distance à l'axe du DERNIER impact simulé ici : c'est celui
		# qui tue dans le cas courant, et chaque nouvel impact écrase le
		# précédent — un kill prédit puis démenti par l'hôte ne peut pas
		# laisser traîner une valeur périmée (constat de revue).
		target.last_fatal_perp = dist_to_axis
	if lethal:
		_flare_trail()

	if not is_replay:
		target.take_damage(opp_hit_damage, source_player)

	_spawn_hit_effects(hit_point)
	if not is_replay:
		_spawn_damage_number(hit_point, int(opp_hit_damage))
	_fade_and_destroy(hit_point)

## Impact sur la cible d'échauffement : mêmes effets qu'un mur, plus le chiffre
## de dégâts, calculé comme sur un joueur pour que l'entraînement soit lisible.
func _hit_training_target(target: TrainingTarget, hit_point: Vector2) -> void:
	var to_target := target.global_position - global_position
	var dist_to_axis: float = abs(to_target.cross(direction))
	var normalized_dist := clampf(dist_to_axis / TrainingTarget.RADIUS, 0.0, 1.0)
	var dmg := int(floorf(lerpf(weapon.damage_center, weapon.damage_edge, normalized_dist)))

	if not is_replay:
		target.register_training_hit(dmg)
	_spawn_wall_effects(hit_point)
	if not is_replay:
		_spawn_damage_number(hit_point, dmg)
	_fade_and_destroy(hit_point)

## Distance parcourue le long du pas avant d'entrer dans le cercle, -1 s'il
## n'est pas atteint pendant ce pas.
static func _circle_entry_distance(origin: Vector2, dir: Vector2, length: float,
		center: Vector2, r: float) -> float:
	var to_center := center - origin
	var proj := to_center.dot(dir)
	var perp_sq := to_center.length_squared() - proj * proj
	var r_sq := r * r
	if perp_sq > r_sq:
		return -1.0
	var half := sqrt(r_sq - perp_sq)
	var entry := proj - half
	if entry < 0.0:
		# Déjà dans le cercle au départ du pas : impact immédiat, sauf si le
		# cercle est entièrement derrière.
		if proj + half < 0.0:
			return -1.0
		entry = 0.0
	if entry > length:
		return -1.0
	return entry

## V2.6 — Le trait du tir fatal sur-expose : largeur et énergie triplées,
## fondu ralenti pour que le gel de l'instant fatal (V2.1) fige une image
## incandescente. L'arbalète, sans lumière par design, ne gagne que la largeur.
const LETHAL_FADE_DURATION := 0.35
var _fade_duration := 0.08

func _flare_trail() -> void:
	_fade_duration = LETHAL_FADE_DURATION
	if light.enabled:
		light.energy *= 3.0
	if has_node("Core"):
		var core: Line2D = get_node("Core")
		core.width *= 3.0
	if has_node("Aura") and get_node("Aura").visible:
		get_node("Aura").modulate.a = 1.0

func _fade_and_destroy(hit_point: Vector2):
	set_physics_process(false)
	var final_step = hit_point - global_position
	var dist = final_step.length()
	
	# Keep the trail length that was built up, properly bounded
	var dist_from_spawn = hit_point.distance_to(spawn_pos)
	var trail_length = min(dist_from_spawn, 800.0)
	global_position = hit_point
	light.rotation = 0.0
	light.scale = Vector2(max(1.0, trail_length / 128.0), 0.15)
	light.position = -Vector2(trail_length / 2.0, 0)
	
	if has_node("Core"):
		get_node("Core").points = PackedVector2Array([Vector2.ZERO, Vector2(-trail_length, 0)])
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(light, "energy", 0.0, _fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if has_node("Core"):
		tween.tween_property(get_node("Core"), "modulate:a", 0.0, _fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if has_node("Aura"):
		tween.tween_property(get_node("Aura"), "modulate:a", 0.0, _fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)

## Le pool est créé par GameState ; sans lui (tests headless isolés) les impacts
## restent silencieux plutôt que de retomber sur l'ancien chemin allouant.
func _particle_pool() -> ParticlePool:
	return get_tree().get_first_node_in_group("particle_pool") as ParticlePool

func _spawn_blood_particles(pos: Vector2, color: Color, amount: int, speed_min: float, speed_max: float, base_dir: Vector2, spread_deg: float):
	var pool := _particle_pool()
	if pool == null: return
	pool.emit(ParticlePool.Kind.BLOOD, pos, color, amount, speed_min, speed_max, base_dir, spread_deg)

func _spawn_spark_particles(pos: Vector2, color: Color, amount: int, speed_min: float, speed_max: float, base_dir: Vector2, spread_deg: float):
	var pool := _particle_pool()
	if pool == null: return
	pool.emit(ParticlePool.Kind.SPARK, pos, color, amount, speed_min, speed_max, base_dir, spread_deg)

func _spawn_hit_effects(pos: Vector2):
	AudioManager.play_sfx_2d_random_pitch("flesh_impact", pos, 0.92, 1.08)
	# Pure blood red
	var blood_color = Color(0.9, 0.0, 0.0)
	# Exit wound: large splatter forward
	_spawn_blood_particles(pos, blood_color, 15, 200.0, 800.0, direction, 60.0)
	# Entry wound: smaller splatter backward (bouncing off the shooter or walls behind)
	_spawn_blood_particles(pos, blood_color, 10, 100.0, 400.0, -direction, 90.0)
	
	# Permanent floor stain
	var gs = get_tree().get_first_node_in_group("game_state")
	if gs and gs.arena:
		var arena = gs.arena
		var stain = Node2D.new()
		stain.set_script(preload("res://blood_stain.gd"))
		arena.add_child(stain)
		stain.setup(pos, direction)

func _spawn_wall_effects(pos: Vector2):
	AudioManager.play_sfx_2d_random_pitch("wall_impact", pos, 0.92, 1.08)
	# Sparks bounce BACKWARDS from the wall
	_spawn_spark_particles(pos, Color(1.0, 0.8, 0.2), 12, 100.0, 450.0, -direction, 120.0)


func _spawn_damage_number(pos: Vector2, amount: int):
	var lbl = Label.new()
	lbl.text = str(amount)
	
	var settings = LabelSettings.new()
	# V4.5 — le poids du chiffre EST l'information : taille proportionnelle aux
	# dégâts (20 px pour un effleurement, 44 px pour un carreau d'arbalète), or
	# au seuil des gros coups — 50, un demi-joueur.
	settings.font_size = int(lerpf(20.0, 44.0, clampf(amount / 80.0, 0.0, 1.0)))
	if amount >= 50:
		settings.font_color = Color(1.0, 0.85, 0.2)
	elif amount >= 40:
		settings.font_color = Color(1.0, 0.2, 0.2)
	else:
		settings.font_color = Color(1.0, 0.7, 0.2)
	settings.outline_size = 8
	settings.outline_color = Color.BLACK
	settings.shadow_size = 4
	settings.shadow_color = Color(0, 0, 0, 0.6)
	settings.shadow_offset = Vector2(2, 2)
	
	lbl.label_settings = settings
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	lbl.custom_minimum_size = Vector2(200, 100)
	lbl.position = pos - Vector2(100, 50)
	lbl.pivot_offset = Vector2(100, 50)
	lbl.z_index = 100
	
	var mat = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	lbl.material = mat
	
	get_parent().add_child(lbl)
	
	var tw = lbl.create_tween().set_parallel(true)
	lbl.scale = Vector2.ZERO
	tw.tween_property(lbl, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_delay(0.2)
	
	var float_offset = Vector2(randf_range(-30, 30), -70 - randf_range(0, 30))
	tw.tween_property(lbl, "position", lbl.position + float_offset, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)
