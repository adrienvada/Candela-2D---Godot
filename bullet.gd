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

func _ready():
	z_index = 10
	# Add a dynamic point light to the bullet itself
	light = PointLight2D.new()
	light.name = "TrailLight"
	light.color = Color(1.0, 0.9, 0.5)
	light.energy = 50.0
	var grad = Gradient.new()
	grad.set_color(0, Color(1,1,1,1))
	grad.set_color(1, Color(0,0,0,1))
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	grad_tex.width = 128
	grad_tex.height = 128
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
	var mat = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
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

	if not is_replay:
		target.take_damage(opp_hit_damage, source_player)

	_spawn_hit_effects(hit_point)
	if not is_replay:
		_spawn_damage_number(hit_point, int(opp_hit_damage))
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
	tween.tween_property(light, "energy", 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if has_node("Core"):
		tween.tween_property(get_node("Core"), "modulate:a", 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if has_node("Aura"):
		tween.tween_property(get_node("Aura"), "modulate:a", 0.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)

func _spawn_blood_particles(pos: Vector2, color: Color, amount: int, speed_min: float, speed_max: float, base_dir: Vector2, spread_deg: float):
	for i in range(amount):
		var rb = RigidBody2D.new()
		rb.z_index = 10
		# Only collide with walls (Layer 1)
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.gravity_scale = 0.0 # Top-down
		
		# Turbulence: heavy friction for meat chunks
		rb.linear_damp = randf_range(8.0, 15.0)
		rb.angular_velocity = randf_range(-40.0, 40.0)
		
		var phys_mat = PhysicsMaterial.new()
		phys_mat.bounce = 0.2
		rb.physics_material_override = phys_mat
		
		# Tiny physical collision
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 2.0
		shape.shape = circle
		rb.add_child(shape)
		
		# Visual core (Meat chunk sizes)
		var poly = Polygon2D.new()
		var s = randf_range(0.8, 3.5)
		poly.polygon = PackedVector2Array([Vector2(-2*s,0), Vector2(0,-2*s), Vector2(2*s,0), Vector2(0,2*s)])
		poly.color = color
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		poly.material = mat
		rb.add_child(poly)
		
		# Emissive light!
		var light = PointLight2D.new()
		var grad = GradientTexture2D.new()
		grad.fill = GradientTexture2D.FILL_RADIAL
		grad.fill_from = Vector2(0.5, 0.5)
		grad.fill_to = Vector2(1, 0.5)
		var g = Gradient.new()
		g.set_color(0, color)
		var c_end = color
		c_end.a = 0.0
		g.set_color(1, c_end)
		grad.gradient = g
		grad.width = 64
		grad.height = 64
		light.texture = grad
		light.energy = 1.0
		light.shadow_enabled = false
		light.range_item_cull_mask = 1 | 4
		rb.add_child(light)
		
		# Velocity and trajectory
		rb.position = pos
		var spread_rad = deg_to_rad(spread_deg)
		var spray_angle = base_dir.angle() + randf_range(-spread_rad/2.0, spread_rad/2.0)
		var speed = randf_range(speed_min, speed_max)
		rb.linear_velocity = Vector2(cos(spray_angle), sin(spray_angle)) * speed
		
		get_parent().add_child(rb)
		
		# Fade out and self-destruct
		var lifetime = randf_range(1.5, 3.0)
		var tw = rb.create_tween()
		tw.tween_property(poly, "scale", Vector2.ZERO, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(light, "energy", 0.0, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(rb.queue_free)

func _spawn_spark_particles(pos: Vector2, color: Color, amount: int, speed_min: float, speed_max: float, base_dir: Vector2, spread_deg: float):
	for i in range(amount):
		var rb = RigidBody2D.new()
		rb.z_index = 10
		# Only collide with walls (Layer 1)
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.gravity_scale = 0.0 # Top-down
		
		# Volatile sparks: low friction, high bounce
		rb.linear_damp = randf_range(1.0, 4.0)
		rb.angular_velocity = randf_range(-20.0, 20.0)
		
		var phys_mat = PhysicsMaterial.new()
		phys_mat.bounce = 0.6
		rb.physics_material_override = phys_mat
		
		# Tiny physical collision
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 1.0
		shape.shape = circle
		rb.add_child(shape)
		
		# Visual core (Small sparks)
		var poly = Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-1,0), Vector2(0,-1), Vector2(1,0), Vector2(0,1)])
		poly.color = color
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		poly.material = mat
		rb.add_child(poly)
		
		# Emissive light!
		var light = PointLight2D.new()
		var grad = GradientTexture2D.new()
		grad.fill = GradientTexture2D.FILL_RADIAL
		grad.fill_from = Vector2(0.5, 0.5)
		grad.fill_to = Vector2(1, 0.5)
		var g = Gradient.new()
		g.set_color(0, color)
		var c_end = color
		c_end.a = 0.0
		g.set_color(1, c_end)
		grad.gradient = g
		grad.width = 32
		grad.height = 32
		light.texture = grad
		light.energy = 1.5
		light.shadow_enabled = true
		light.shadow_item_cull_mask = 1
		light.range_item_cull_mask = 1 | 2 | 4 # Sparks illuminate players (2)
		rb.add_child(light)
		
		# Velocity and trajectory
		rb.position = pos
		var spread_rad = deg_to_rad(spread_deg)
		var spray_angle = base_dir.angle() + randf_range(-spread_rad/2.0, spread_rad/2.0)
		var speed = randf_range(speed_min, speed_max)
		rb.linear_velocity = Vector2(cos(spray_angle), sin(spray_angle)) * speed
		
		get_parent().add_child(rb)
		
		# Fade out and self-destruct (shorter lifetime for sparks)
		var lifetime = randf_range(0.3, 0.8)
		var tw = rb.create_tween()
		tw.tween_property(poly, "scale", Vector2.ZERO, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(light, "energy", 0.0, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(rb.queue_free)

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
	settings.font_size = 36 if amount >= 40 else 24
	settings.font_color = Color(1.0, 0.2, 0.2) if amount >= 40 else Color(1.0, 0.7, 0.2)
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
