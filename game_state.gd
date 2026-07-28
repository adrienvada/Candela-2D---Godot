extends Node
class_name GameState

@export var round_time: float = 120.0

var time_left: float = 120.0
var round_active: bool = false
var game_over: bool = false
var _first_replay_frame: bool = false

var p1_kills: int = 0
var p2_kills: int = 0

var p1: Player
var p2: Player

var weapon_pistolet: WeaponData
var weapon_fusil: WeaponData
var weapon_pompe: WeaponData

@onready var ui = $UI
@onready var vp1 = $SplitScreen/ViewportContainer1/SubViewport1
@onready var vp2 = $SplitScreen/ViewportContainer2/SubViewport2
@onready var arena = $SplitScreen/ViewportContainer1/SubViewport1/Arena
@onready var players_node = $SplitScreen/ViewportContainer1/SubViewport1/Players
@onready var bullet_container = $SplitScreen/ViewportContainer1/SubViewport1/Bullets
@onready var spawn_p1 = $SplitScreen/ViewportContainer1/SubViewport1/Arena/SpawnPoints/P1Spawn
@onready var spawn_p2 = $SplitScreen/ViewportContainer1/SubViewport1/Arena/SpawnPoints/P2Spawn

@onready var player_scene = preload("res://player.tscn")
@onready var bullet_scene = preload("res://bullet.tscn")

var ghost_p1: Node2D
var ghost_p2: Node2D

var cam1: Camera2D
var cam2: Camera2D
var current_snap

var cam1_shake_time: float = 0.0
var cam2_shake_time: float = 0.0

func _ready():
	add_to_group("game_state")
	AudioManager.play_music("music_menu")

	
	weapon_pistolet = WeaponData.new()
	
	weapon_fusil = WeaponData.new()
	weapon_fusil.name = "Fusil"
	weapon_fusil.cooldown = 1.3
	weapon_fusil.bullet_speed = 15000.0
	weapon_fusil.bullet_max_distance = 15000.0
	weapon_fusil.damage_center = 50.0
	weapon_fusil.damage_edge = 25.0
	weapon_fusil.max_bounces = 2
	weapon_fusil.damages_shooter = true
	weapon_fusil.torch_angle_deg = 20.0
	weapon_fusil.torch_scale = 3.5
	
	weapon_pompe = WeaponData.new()
	weapon_pompe.name = "Pompe"
	weapon_pompe.cooldown = 1.2
	weapon_pompe.bullet_speed = 10000.0
	weapon_pompe.bullet_max_distance = 180.0
	weapon_pompe.damage_center = 20.0
	weapon_pompe.damage_edge = 15.0
	weapon_pompe.max_bounces = 0
	weapon_pompe.projectile_count = 5
	weapon_pompe.spread_angles_deg = [0.0, 20.0, -20.0, 60.0, -60.0]
	weapon_pompe.torch_angle_deg = 120.0
	weapon_pompe.torch_scale = 1.0
	
	ReplaySystem.replay_spawn_bullet.connect(_on_replay_spawn_bullet)
	ui.replay_requested.connect(_on_replay_requested)
	ui.quit_requested.connect(_on_quit_requested)
	
	ui.btn_debug_light.toggled.connect(_on_debug_light_toggled)
	
	# Set global clear color to black to fix gray areas
	RenderingServer.set_default_clear_color(Color.BLACK)
	
	# Share the world_2d for split screen
	vp2.world_2d = vp1.world_2d
	
	_setup_ambient_visuals()
	_setup_players()
	_setup_ghosts()
	
	# Setup Killcam Overlay to sit between background and players/bullets
	var killcam_bb = BackBufferCopy.new()
	killcam_bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	killcam_bb.z_index = 2
	killcam_bb.name = "KillcamBB"
	killcam_bb.hide()
	arena.add_child(killcam_bb)
	
	ui.killcam_overlay.z_index = 2
	ui.killcam_overlay.name = "KillcamOverlay"
	ui.killcam_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.killcam_overlay.size = Vector2(20000, 20000)
	ui.killcam_overlay.position = Vector2(-10000, -10000)
	arena.add_child(ui.killcam_overlay)
	
	ui.show_main_menu()

func _on_debug_light_toggled(toggled_on: bool):
	var mod = arena.get_node_or_null("CanvasModulate")
	if mod:
		mod.color = Color(0.3, 0.3, 0.3) if toggled_on else Color(0, 0, 0)

func _setup_ambient_visuals():
	# Generate checkerboard texture for the Ground
	var img = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	var c1 = Color(0.02, 0.02, 0.02)
	var c2 = Color(0.06, 0.06, 0.06)
	for y in range(64):
		for x in range(64):
			if (x < 32 and y < 32) or (x >= 32 and y >= 32):
				img.set_pixel(x, y, c1)
			else:
				img.set_pixel(x, y, c2)
	var grid_tex = ImageTexture.create_from_image(img)
	
	if arena.has_node("Ground"):
		var g = arena.get_node("Ground")
		g.texture = grid_tex
		g.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		
	if arena.has_node("StaticGeometry/Obstacle1/ColorRect"):
		arena.get_node("StaticGeometry/Obstacle1/ColorRect").color = Color.BLACK
		
	# Draw white lines on all occluders so they catch the light
	for child in arena.get_node("StaticGeometry").get_children():
		if child is StaticBody2D:
			for shape in child.get_children():
				if shape is LightOccluder2D:
					var poly = shape.occluder.polygon
					var line = Line2D.new()
					var pts = Array(poly)
					if pts.size() > 0:
						pts.append(pts[0]) # Close loop
					line.points = pts
					line.width = 4.0
					line.default_color = Color.WHITE
					child.add_child(line)
		
	var visuals = []
	_find_visuals(arena, visuals)
	for v in visuals:
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		
		var v1 = v.duplicate()
		v1.visibility_layer = 2 # P1 Viewport
		v1.light_mask = 1 | 16 # Torch (1) + P1 Ambient (16)
		v1.material = mat
		v.get_parent().add_child(v1)
		
		var v2 = v.duplicate()
		v2.visibility_layer = 4 # P2 Viewport
		v2.light_mask = 1 | 32 # Torch (1) + P2 Ambient (32)
		v2.material = mat
		v.get_parent().add_child(v2)

func _find_visuals(node: Node, list: Array):
	if (node is ColorRect or node is Sprite2D or node is Polygon2D or node is TextureRect or node is Line2D) and not node.is_in_group("players"):
		list.append(node)
	for c in node.get_children():
		_find_visuals(c, list)

func _setup_players():
	p1 = player_scene.instantiate()
	p1.player_id = 0
	players_node.add_child(p1)
	
	p2 = player_scene.instantiate()
	p2.player_id = 1
	players_node.add_child(p2)
	
	# Cameras (Top Level so they can follow ghosts during replay)
	cam1 = Camera2D.new()
	cam1.custom_viewport = vp1
	players_node.add_child(cam1)
	
	cam2 = Camera2D.new()
	cam2.custom_viewport = vp2
	players_node.add_child(cam2)
	
	# Restrict viewports so they don't see each other's private layers
	vp1.canvas_cull_mask = ~4 # Hide layer 3 (value 4) which belongs to P2
	vp2.canvas_cull_mask = ~2 # Hide layer 2 (value 2) which belongs to P1

func _setup_ghosts():
	var unshaded_shader = Shader.new()
	unshaded_shader.code = """
shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float d = distance(UV, vec2(0.5));
	float rim = smoothstep(0.42, 0.48, d);
	float boost = mix(0.1, 4.0, rim); // Slightly brighter center so they are visible
	COLOR = vec4(COLOR.rgb * boost, COLOR.a);
}
"""
	var unshaded_mat = ShaderMaterial.new()
	unshaded_mat.shader = unshaded_shader
	
	ghost_p1 = Node2D.new()
	ghost_p1.z_index = 10
	var g1_vis = p1.get_node("VisualColored").duplicate()
	g1_vis.material = unshaded_mat
	g1_vis.color.a = 0.5
	g1_vis.visibility_layer = 1 # Force visible to all cameras
	ghost_p1.add_child(g1_vis)
	var l1 = p1.get_node("Flashlight").duplicate()
	l1.name = "Light"
	ghost_p1.add_child(l1)
	var f1 = p1.get_node("MuzzleFlash").duplicate()
	f1.name = "Flash"
	ghost_p1.add_child(f1)
	players_node.add_child(ghost_p1)
	ghost_p1.hide()
	
	ghost_p2 = Node2D.new()
	ghost_p2.z_index = 10
	var g2_vis = p2.get_node("VisualColored").duplicate()
	g2_vis.material = unshaded_mat
	g2_vis.color.a = 0.5
	g2_vis.visibility_layer = 1 # Force visible to all cameras
	ghost_p2.add_child(g2_vis)
	var l2 = p2.get_node("Flashlight").duplicate()
	l2.name = "Light"
	ghost_p2.add_child(l2)
	var f2 = p2.get_node("MuzzleFlash").duplicate()
	f2.name = "Flash"
	ghost_p2.add_child(f2)
	players_node.add_child(ghost_p2)
	ghost_p2.hide()

func _start_round():
	AudioManager.reset_low_health()
	AudioManager.play_music("music_match")
	AudioManager.play_speaker("spk_fight")
	
	p1.show_all_visuals()
	p2.show_all_visuals()

	p1.hp = 100.0
	p2.hp = 100.0
	p1.dead = false
	p2.dead = false
	
	var w1_idx = 0
	if ui.p1_weapon_group.get_pressed_button():
		w1_idx = ui.p1_weapon_group.get_pressed_button().get_index()
	var w1 = weapon_pompe if w1_idx == 2 else (weapon_fusil if w1_idx == 1 else weapon_pistolet)
	
	var w2_idx = 0
	if ui.p2_weapon_group.get_pressed_button():
		w2_idx = ui.p2_weapon_group.get_pressed_button().get_index()
	var w2 = weapon_pompe if w2_idx == 2 else (weapon_fusil if w2_idx == 1 else weapon_pistolet)
	
	p1.equip_weapon(w1)
	p2.equip_weapon(w2)
	
	p1.get_node("VisualColored").show()
	p1.get_node("VisualDim").show()
	p1.get_node("VisualReveal").show()
	p2.get_node("VisualColored").show()
	p2.get_node("VisualDim").show()
	p2.get_node("VisualReveal").show()
	
	p1.global_position = spawn_p1.global_position if spawn_p1 else Vector2(200, 200)
	p2.global_position = spawn_p2.global_position if spawn_p2 else Vector2(1200, 1200)
	p1.rotation = 0
	p2.rotation = PI
	time_left = round_time
	round_active = true
	game_over = false
	Engine.time_scale = 1.0
	ghost_p1.hide()
	ghost_p2.hide()
	for c in bullet_container.get_children():
		c.queue_free()
	ReplaySystem.start_recording()
	
	ui.game_over_score.text = "KILLS : %d - %d" % [p1_kills, p2_kills]

func _process(delta):
	if round_active:
		time_left -= delta
		if time_left <= 0:
			time_left = 0
			_end_round(-1)
			
		_check_dazzle(delta)
		
		# Cameras track live players
		cam1.global_position = p1.global_position
		cam2.global_position = p2.global_position
		
	if cam1_shake_time > 0:
		cam1_shake_time -= delta
		cam1.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 15.0
	else:
		cam1.offset = Vector2.ZERO
		
	if cam2_shake_time > 0:
		cam2_shake_time -= delta
		cam2.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 15.0
	else:
		cam2.offset = Vector2.ZERO
		
	if ReplaySystem.recording:
		ReplaySystem.record_frame(p1, p2, bullet_container)
			
	if ReplaySystem.playing_back:
		current_snap = ReplaySystem.get_next_frame(delta)
		if current_snap:
			ghost_p1.show()
			ghost_p2.show()
			p1.hide_all_visuals()
			p2.hide_all_visuals()
			
			ghost_p1.global_position = current_snap.p1_pos
			ghost_p1.rotation = current_snap.p1_rot
			ghost_p1.visible = current_snap.p1_visible
			ghost_p1.get_node("Light").enabled = current_snap.p1_light
			ghost_p1.get_node("Flash").enabled = current_snap.p1_flash > 0.0
			ghost_p1.get_node("Flash").energy = current_snap.p1_flash
			if current_snap.p1_weapon:
				ghost_p1.get_node("Light").texture = current_snap.p1_weapon.get_torch_texture()
				ghost_p1.get_node("Light").texture_scale = current_snap.p1_weapon.torch_scale
			
			ghost_p2.global_position = current_snap.p2_pos
			ghost_p2.rotation = current_snap.p2_rot
			ghost_p2.visible = current_snap.p2_visible
			ghost_p2.get_node("Light").enabled = current_snap.p2_light
			ghost_p2.get_node("Flash").enabled = current_snap.p2_flash > 0.0
			ghost_p2.get_node("Flash").energy = current_snap.p2_flash
			if current_snap.p2_weapon:
				ghost_p2.get_node("Light").texture = current_snap.p2_weapon.get_torch_texture()
				ghost_p2.get_node("Light").texture_scale = current_snap.p2_weapon.torch_scale
			
			# Sync real players physical positions for accurate replay collisions
			p1.global_position = current_snap.p1_pos
			p1.rotation = current_snap.p1_rot
			p2.global_position = current_snap.p2_pos
			p2.rotation = current_snap.p2_rot
			
			# Dynamic Camera Zoom & Tracking
			# Cinematic smooth tracking throughout the entire killcam
			var unscaled_delta = delta / Engine.time_scale if Engine.time_scale > 0 else delta
			var midpoint = (ghost_p1.global_position + ghost_p2.global_position) / 2.0
			var viewport_size = get_viewport().get_visible_rect().size
			var margin = 250.0 # Larger margin so players are visible and not hidden by UI
			
			var dx = max(abs(ghost_p1.global_position.x - ghost_p2.global_position.x), 200.0)
			var dy = max(abs(ghost_p1.global_position.y - ghost_p2.global_position.y), 200.0)
			
			# Only apply extreme cinematic zoom during bullet time!
			var target_zoom_val = 1.0
			var target_pos = midpoint
			
			if Engine.time_scale < 0.9:
				# We are in bullet time! Zoom in hard.
				var zoom_x = viewport_size.x / (dx + margin * 2)
				var zoom_y = viewport_size.y / (dy + margin * 2)
				target_zoom_val = clamp(min(zoom_x, zoom_y), 1.2, 2.8) # Push zoom further
			else:
				# Normal playback: stay zoomed out to see the action
				var zoom_x = viewport_size.x / (dx + margin * 2.5)
				var zoom_y = viewport_size.y / (dy + margin * 2.5)
				target_zoom_val = clamp(min(zoom_x, zoom_y), 0.7, 1.3)
				
			var target_zoom = Vector2(target_zoom_val, target_zoom_val)
			
			if _first_replay_frame:
				cam1.global_position = target_pos
				cam1.zoom = target_zoom
				_first_replay_frame = false
			else:
				# Exponential smoothing prevents overshoot and jumping when delta scales wildly in bullet time
				var lerp_speed = 3.0 if Engine.time_scale >= 0.9 else 6.0
				var weight = 1.0 - exp(-lerp_speed * unscaled_delta)
				cam1.global_position = cam1.global_position.lerp(target_pos, weight)
				cam1.zoom = cam1.zoom.lerp(target_zoom, weight)
			
		# Allow skipping killcam
		if Input.is_action_just_pressed("p1_skip_killcam") or Input.is_action_just_pressed("p2_skip_killcam"):
			ReplaySystem.playing_back = false
			Engine.time_scale = 1.0
			
	ui.update_hud(p1, p2, time_left)

func _check_dazzle(delta: float):
	var space = p1.get_world_2d().direct_space_state
	
	if p1.flashlight_on:
		var p1_to_p2 = p1.global_position.direction_to(p2.global_position)
		if p1.global_transform.x.dot(p1_to_p2) > 0.866:
			var q = PhysicsRayQueryParameters2D.create(p1.global_position, p2.global_position)
			q.exclude = [p1.get_rid()]
			var res = space.intersect_ray(q)
			if res and res.collider == p2:
				p2.apply_dazzle(0.5 * delta)
				
	if p2.flashlight_on:
		var p2_to_p1 = p2.global_position.direction_to(p1.global_position)
		if p2.global_transform.x.dot(p2_to_p1) > 0.866:
			var q = PhysicsRayQueryParameters2D.create(p2.global_position, p1.global_position)
			q.exclude = [p2.get_rid()]
			var res = space.intersect_ray(q)
			if res and res.collider == p1:
				p1.apply_dazzle(0.5 * delta)

func spawn_bullet(shooter: Node2D, pos: Vector2, rot: float, weapon: WeaponData):
	if not round_active: return
	var count = weapon.projectile_count if weapon else 1
	var angles = weapon.spread_angles_deg if weapon else [0.0]
	
	for i in range(count):
		var ang_offset = deg_to_rad(angles[i]) if i < angles.size() else 0.0
		var final_rot = rot + ang_offset
		
		var b = bullet_scene.instantiate()
		b.global_position = pos
		b.rotation = final_rot
		b.direction = Vector2(cos(final_rot), sin(final_rot))
		b.source_player = shooter
		if weapon:
			b.weapon = weapon
		bullet_container.add_child(b)
		
		if ReplaySystem.recording:
			ReplaySystem.record_bullet_fired(shooter.player_id, pos, final_rot, weapon)
			
	if shooter == p1:
		cam1_shake_time = 0.1
	elif shooter == p2:
		cam2_shake_time = 0.1

func _on_replay_spawn_bullet(shooter_id: int, pos: Vector2, rot: float, weapon: WeaponData):
	var b = bullet_scene.instantiate()
	b.is_replay = true
	b.global_position = pos
	b.rotation = rot
	b.direction = Vector2(cos(rot), sin(rot))
	var shooter = p1 if shooter_id == 0 else p2
	b.source_player = shooter
	if weapon:
		b.weapon = weapon
	bullet_container.add_child(b)

func player_died(dead_id: int, _killer_id: int):
	if not round_active: return
	
	if dead_id == 0:
		p2_kills += 1
		_end_round(1)
	elif dead_id == 1:
		p1_kills += 1
		_end_round(0)

func _end_round(winner_id: int):
	round_active = false
	AudioManager.play_music("music_victory")
	if winner_id == 0:
		AudioManager.play_speaker("spk_p1_wins")
	elif winner_id == 1:
		AudioManager.play_speaker("spk_p2_wins")
	else:
		AudioManager.play_speaker("spk_draw")

	
	if winner_id != -1:
		# Wait 1.5 seconds to capture blood physics and reaction!
		await get_tree().create_timer(1.5).timeout
		
	ReplaySystem.stop_recording()
	
	if winner_id != -1:
		# Enter Fullscreen Killcam mode
		var mod = arena.get_node_or_null("CanvasModulate")
		if mod:
			mod.color = Color(0.3, 0.3, 0.3)
		
		vp2.get_parent().hide()
		ui.center_line.hide()
		ui.show_killcam()
		
		_first_replay_frame = true
		ReplaySystem.start_playback()
		
		# Wait for replay to finish or be skipped
		while ReplaySystem.playing_back:
			await get_tree().process_frame
			
		# Hide killcam UI but KEEP the freeze frame
		ui.hide_killcam()
		
		# DO NOT restore split screen or reset cameras here!
		# It freezes the screen perfectly on the death frame behind the menu.
		
	game_over = true
	ui.show_game_over(winner_id)
	ui.game_over_score.text = "KILLS : %d - %d" % [p1_kills, p2_kills]

func _on_replay_requested():
	game_over = false
	ui.hide_game_over()
	
	# NOW we restore split screen and reset cameras for the new round
	vp2.get_parent().show()
	ui.center_line.show()
	cam1.zoom = Vector2(1.0, 1.0)
	cam2.zoom = Vector2(1.0, 1.0)
	cam1.global_position = p1.global_position
	cam2.global_position = p2.global_position
	
	var mod = arena.get_node_or_null("CanvasModulate")
	if mod:
		mod.color = Color(0.3, 0.3, 0.3) if ui.btn_debug_light.button_pressed else Color(0, 0, 0)
	
	_start_round()

func _on_quit_requested():
	get_tree().quit()
