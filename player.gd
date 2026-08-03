extends CharacterBody2D
class_name Player

@export var player_id: int = 0
@export var speed: float = 260.0
@export var input_provider: InputProvider

var current_weapon: WeaponData

var hp: float = 100.0
var ghost_hp: float = 100.0

var shoot_cooldown: float = 0.0
var tw_reveal: Tween
var dazzle_amount: float = 0.0

var shake_intensity: float = 0.0
var shake_decay: float = 5.0
var noise: FastNoiseLite
var shake_time: float = 0.0

var vignette_mat: ShaderMaterial

var flashlight_on: bool = false
var is_sprinting: bool = false
var dead: bool = false

# Numérotation des paquets d'input client→hôte. Le canal est unreliable :
# sans compteur, un paquet en retard réécraserait un état plus récent.
var _input_seq: int = 0
var _last_input_seq: int = -1

# La torche est répliquée, pas simulée, côté non-autoritaire : on détecte son
# changement ici pour que le son suive dans tous les modes.
var _torch_audio_state: bool = false

@onready var visual_dim = $VisualDim
@onready var visual_dim_ptr = $VisualDim/DirPointerDim
@onready var visual_reveal = $VisualReveal
@onready var visual_reveal_ptr = $VisualReveal/DirPointerReveal
@onready var visual = $VisualColored
@onready var visual_ptr = $VisualColored/DirPointer

var visual_enemy: Polygon2D
var visual_enemy_ptr: Polygon2D
var visual_reveal_enemy: Polygon2D
var visual_reveal_enemy_ptr: Polygon2D
@onready var flashlight = $Flashlight
var ambient_light: PointLight2D
@onready var body_light = $BodyLight
@onready var muzzle_flash = $MuzzleFlash
@onready var muzzle = $Muzzle

var aim_cast: RayCast2D
var aim_line: Line2D
@onready var shoot_sound = $ShootSound
@onready var hit_sound = $HitSound
var step_distance_accumulated: float = 0.0


func _ready():
	z_index = 10
	scale = Vector2(1.0, 1.0)
	add_to_group("players")

	# Le joueur est arrêté par les murs (couche 1) ET par les fosses (couche 2).
	# Les balles, elles, ne testent que la couche 1 : on peut donc se tirer
	# dessus d'une rive à l'autre d'un gouffre.
	collision_mask = MapGeometry.PLAYER_MASK

	if not input_provider:
		var default_provider = LocalInputProvider.new()
		default_provider.device_id = player_id
		add_child(default_provider)
		input_provider = default_provider
		
	# Multiplayer Synchronizer
	var sync = MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSynchronizer"
	var rep_config = SceneReplicationConfig.new()
	rep_config.add_property(NodePath(".:global_position"))
	rep_config.add_property(NodePath(".:rotation"))
	rep_config.add_property(NodePath(".:flashlight_on"))
	# L'hôte est autorité sur les deux joueurs : la réplication va toujours
	# hôte→client, y compris pour les HP.
	rep_config.add_property(NodePath(".:hp"))
	sync.replication_config = rep_config
	add_child(sync)
	
	var p_color = Color(0, 0.94, 1.0) if player_id == 0 else Color(1.0, 0, 0.33)
	visual.color = p_color
	visual_ptr.color = p_color
	
	visual_dim.color = p_color
	visual_dim.color.a = 0.5
	visual_dim_ptr.color = p_color
	visual_dim_ptr.color.a = 0.5
	
	visual_reveal.color = p_color
	visual_reveal.color.a = 0.0
	visual_reveal_ptr.color = p_color
	visual_reveal_ptr.color.a = 0.0
	
	# Make the nose very thin
	var narrow_nose = PackedVector2Array([Vector2(18, -2), Vector2(18, 2), Vector2(28, 0)])
	visual_ptr.polygon = narrow_nose
	visual_dim_ptr.polygon = narrow_nose
	visual_reveal_ptr.polygon = narrow_nose
	
	# Create grayscale versions for the enemy screen
	visual_enemy = visual.duplicate()
	visual_enemy_ptr = visual_ptr.duplicate()
	visual_reveal_enemy = visual_reveal.duplicate()
	visual_reveal_enemy_ptr = visual_reveal_ptr.duplicate()
	
	var gray = Color(0.7, 0.7, 0.7)
	visual_enemy.color = gray
	visual_enemy_ptr.color = gray
	visual_reveal_enemy.color = gray
	visual_reveal_enemy_ptr.color = gray
	visual_reveal_enemy.color.a = 0.0
	visual_reveal_enemy_ptr.color.a = 0.0
	
	visual_enemy.name = "VisualEnemy"
	visual_enemy_ptr.name = "VisualEnemyPtr"
	visual_reveal_enemy.name = "VisualRevealEnemy"
	visual_reveal_enemy_ptr.name = "VisualRevealEnemyPtr"
	
	add_child(visual_enemy)
	add_child(visual_enemy_ptr)
	add_child(visual_reveal_enemy)
	add_child(visual_reveal_enemy_ptr)
	
	# Make the reveal silhouettes unshaded so they glow independently of shadows
	var unshaded_mat = CanvasItemMaterial.new()
	unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	visual_reveal.material = unshaded_mat
	visual_reveal_ptr.material = unshaded_mat
	visual_reveal_enemy.material = unshaded_mat
	visual_reveal_enemy_ptr.material = unshaded_mat
	
	# =========================================================================
	# ARCHITECTURE DES COUCHES DE LUMIÈRE & DE VISIBILITÉ (GODOT 2D)
	# -------------------------------------------------------------------------
	# - VISIBILITY_LAYER : Détermine sur quel Viewport le sprite est dessiné.
	#     * Viewport 1 (Joueur 1) lit la couche 2.
	#     * Viewport 2 (Joueur 2) lit la couche 4.
	#
	# - LIGHT_MASK : Détermine quelle couche de lumière affecte ce sprite.
	#     * Layer 1 (1) : Décor / Environnement (Murs, Sol).
	#     * Layer 2 (2) : Sprites Ennemis (`visual_enemy`, gris).
	#     * Layer 3 (4) : Sprites Joueurs Locaux (`visual`, cyan/magenta).
	# =========================================================================
	visual.light_mask = 4          # Layer 3 : Joueur local (Rétrodiffusion & Torche)
	visual_ptr.light_mask = 4      # Layer 3 : Joueur local
	visual_dim.light_mask = 1
	visual_dim_ptr.light_mask = 1
	visual_reveal.light_mask = 1
	visual_reveal_ptr.light_mask = 1
	visual_enemy.light_mask = 2    # Layer 2 : Sprite Ennemi (Rétrodiffusion, Torche, Sparks, Balles)
	visual_enemy_ptr.light_mask = 2# Layer 2 : Sprite Ennemi
	visual_reveal_enemy.light_mask = 1
	visual_reveal_enemy_ptr.light_mask = 1
	
	if player_id == 0:
		visual.visibility_layer = 2
		visual_ptr.visibility_layer = 2
		visual_reveal.visibility_layer = 2
		visual_reveal_ptr.visibility_layer = 2
		visual_dim.visibility_layer = 2
		visual_dim_ptr.visibility_layer = 2
		
		visual_enemy.visibility_layer = 4
		visual_enemy_ptr.visibility_layer = 4
		visual_reveal_enemy.visibility_layer = 4
		visual_reveal_enemy_ptr.visibility_layer = 4
	else:
		visual.visibility_layer = 4
		visual_ptr.visibility_layer = 4
		visual_reveal.visibility_layer = 4
		visual_reveal_ptr.visibility_layer = 4
		visual_dim.visibility_layer = 4
		visual_dim_ptr.visibility_layer = 4
		
		visual_enemy.visibility_layer = 2
		visual_enemy_ptr.visibility_layer = 2
		visual_reveal_enemy.visibility_layer = 2
		visual_reveal_enemy_ptr.visibility_layer = 2
		
	# In Godot, a Polygon2D MUST have a texture, otherwise UVs are optimized out and always (0,0) in shaders!
	var dummy_img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	dummy_img.fill(Color.WHITE)
	var dummy_tex = ImageTexture.create_from_image(dummy_img)
	
	visual.texture = dummy_tex
	visual_ptr.texture = dummy_tex
	visual_enemy.texture = dummy_tex
	visual_enemy_ptr.texture = dummy_tex
		
	# Calculate UVs so the rim light shader works correctly
	_calculate_uvs(visual)
	_calculate_uvs(visual_ptr)
	_calculate_uvs(visual_enemy)
	_calculate_uvs(visual_enemy_ptr)
		
	# Shader to boost lighting on the player's edges so they look like they have volume
	var light_boost_shader = Shader.new()
	light_boost_shader.code = """
shader_type canvas_item;
void light() {
	// UV center is (0.5, 0.5). We calculate distance to center.
	float d = distance(UV, vec2(0.5));
	// Rim is strictly confined to the extreme outer edge
	float rim = smoothstep(0.42, 0.48, d);
	// Center is dark (0.4), edge is brightly illuminated (4.0). This creates a solid 3D effect instead of a hollow ring!
	float boost = mix(0.4, 4.0, rim);
	LIGHT = vec4(LIGHT_COLOR.rgb * COLOR.rgb * boost, LIGHT_COLOR.a);
}
"""
	var light_boost_mat = ShaderMaterial.new()
	light_boost_mat.shader = light_boost_shader

	# Smooth shader for the enemy: renders capped base gray color when illuminated, pitch black in shadow.
	var enemy_shader = Shader.new()
	enemy_shader.code = """
shader_type canvas_item;
void light() {
	float light_val = max(max(LIGHT_COLOR.r, LIGHT_COLOR.g), LIGHT_COLOR.b);
	if (light_val > 0.001) {
		// Boost incoming light slightly so the enemy is uniformly gray anywhere in the torch cone,
		// but clamp to COLOR.rgb so it NEVER overexposes to white!
		vec3 lit = COLOR.rgb * (light_val * 4.0);
		LIGHT = vec4(min(lit, COLOR.rgb), LIGHT_COLOR.a);
	} else {
		LIGHT = vec4(0.0); // Pitch black in shadow / unlit
	}
}
"""
	var enemy_mat = ShaderMaterial.new()
	enemy_mat.shader = enemy_shader
	visual_enemy.material = enemy_mat
	visual_enemy_ptr.material = enemy_mat
	
	visual.material = light_boost_mat
	visual_ptr.material = light_boost_mat
		
	# Setup Camera Shake Noise
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 10.0 # Fast frequency for impact
	
	# Setup Damage Vignette UI
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	var vignette_rect = ColorRect.new()
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Use the correct visibility layer so it only shows on the player's own viewport
	vignette_rect.visibility_layer = 2 if player_id == 0 else 4
	
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 vignette_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float intensity = 0.0;
uniform float smoothness = 0.8;

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5));
	float v = smoothstep(0.5 - smoothness * 0.5, 0.5 + smoothness * 0.5, d);
	COLOR = vignette_color;
	COLOR.a = v * intensity;
}
	"""
	vignette_mat = ShaderMaterial.new()
	vignette_mat.shader = shader
	vignette_rect.material = vignette_mat
	ui_layer.add_child(vignette_rect)
	
	
	# Configuration de la Lampe Torche Principale (Faisceau Avant)
	flashlight.enabled = false
	flashlight.shadow_enabled = true
	flashlight.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	flashlight.shadow_item_cull_mask = 1 | 2 # Les murs (1) projettent des ombres sur les ennemis (2) sans auto-ombrage (4)
	flashlight.range_item_cull_mask = 1 | 2 | 4 # Éclaire les murs (1), les ennemis (2) et le joueur local (4)
	flashlight.energy = 2.5
	flashlight.offset = Vector2.ZERO
	flashlight.position = Vector2(30, 0)
	
	# Configuration de la Rétrodiffusion de Lentille (Halo autour du corps quand la torche est active)
	body_light.enabled = false
	body_light.shadow_enabled = true # Activé pour que les murs bloquent le rétroéclairage !
	body_light.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	body_light.shadow_item_cull_mask = 1 | 2 # Les murs (1) bloquent la rétrodiffusion vers les ennemis (2)
	body_light.range_item_cull_mask = 2 | 4  # Éclaire le joueur local (4) ET l'écran ennemi (2) quand en ligne de vue
	
	var b_grad = Gradient.new()
	b_grad.set_color(0, Color(1, 0.95, 0.8, 1.0))
	b_grad.set_color(1, Color(1, 0.95, 0.8, 0.0))
	var b_tex = GradientTexture2D.new()
	b_tex.gradient = b_grad
	b_tex.fill = GradientTexture2D.FILL_RADIAL
	b_tex.fill_from = Vector2(0.5, 0.5)
	b_tex.fill_to = Vector2(0.5, 0.0)
	b_tex.width = 256
	b_tex.height = 256
	body_light.texture = b_tex
	body_light.energy = 0.6
	body_light.position = Vector2(18, 0)
	
	if current_weapon:
		equip_weapon(current_weapon)
	else:
		equip_weapon(WeaponData.new())
	
	ambient_light = PointLight2D.new()
	var a_grad = Gradient.new()
	a_grad.set_color(0, Color(1, 1, 1, 1))
	a_grad.set_color(1, Color(1, 1, 1, 0))
	var a_tex = GradientTexture2D.new()
	a_tex.gradient = a_grad
	a_tex.fill = GradientTexture2D.FILL_RADIAL
	a_tex.fill_from = Vector2(0.5, 0.5)
	a_tex.fill_to = Vector2(0.5, 0.0)
	a_tex.width = 150
	a_tex.height = 150
	
	ambient_light.texture = a_tex
	ambient_light.energy = 0.8
	ambient_light.shadow_enabled = true
	ambient_light.shadow_filter = PointLight2D.SHADOW_FILTER_NONE
	if player_id == 0:
		ambient_light.range_item_cull_mask = 16
	else:
		ambient_light.range_item_cull_mask = 32
	add_child(ambient_light)
	
	# The main occluder is configured as a perfect circle on layer 3 (value 4).
	# This ensures it blocks the main flashlight (mask 1|4) and bullets.
	var pts = PackedVector2Array()
	for i in range(16):
		var ang = (i / 16.0) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * 18.0) # 18.0 is exactly the player radius
		
	if has_node("LightOccluder2D"):
		var main_occ = get_node("LightOccluder2D")
		main_occ.occluder.polygon = pts
		main_occ.occluder.cull_mode = OccluderPolygon2D.CULL_DISABLED
		main_occ.occluder_light_mask = 4 # Put player occluder on layer 3 (value 4)
		
	muzzle_flash.enabled = false
	muzzle_flash.shadow_enabled = true
	muzzle_flash.shadow_item_cull_mask = 1 | 4 # Casts shadows from walls(1) and players(4)
	muzzle_flash.range_item_cull_mask = 1 | 2 # Illuminates walls and players
	# Aim line setup
	aim_cast = RayCast2D.new()
	aim_cast.position = Vector2(28, 0)
	aim_cast.target_position = Vector2(2000, 0)
	aim_cast.collision_mask = 1
	add_child(aim_cast)
	aim_cast.add_exception(self)
	
	aim_line = Line2D.new()
	aim_line.width = 2.0
	aim_line.default_color = Color(1.0, 1.0, 1.0, 0.25)
	aim_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	
	var dash_img = Image.create_empty(16, 2, false, Image.FORMAT_RGBA8)
	dash_img.fill_rect(Rect2(0, 0, 8, 2), Color.WHITE)
	dash_img.fill_rect(Rect2(8, 0, 8, 2), Color.TRANSPARENT)
	var dash_tex = ImageTexture.create_from_image(dash_img)
	
	aim_line.texture = dash_tex
	aim_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	add_child(aim_line)
	
	if player_id == 0:
		aim_line.visibility_layer = 2
	else:
		aim_line.visibility_layer = 4
	var mf_grad = Gradient.new()
	mf_grad.set_color(0, Color.WHITE)
	var c_end = Color.WHITE
	c_end.a = 0.0
	mf_grad.set_color(1, c_end)
	var mf_tex = GradientTexture2D.new()
	mf_tex.gradient = mf_grad
	mf_tex.fill = GradientTexture2D.FILL_RADIAL
	mf_tex.fill_from = Vector2(0.5, 0.5)
	mf_tex.fill_to = Vector2(1, 0.5)
	mf_tex.width = 128
	mf_tex.height = 128
	
	muzzle_flash.texture = mf_tex
	muzzle_flash.texture_scale = 0.5
	muzzle_flash.color = Color(1.0, 0.8, 0.5)
	muzzle_flash.offset = Vector2.ZERO

func equip_weapon(weapon: WeaponData):
	current_weapon = weapon
	
	var tex = weapon.get_torch_texture()
	flashlight.texture = tex
	flashlight.texture_scale = weapon.torch_scale

func _process(delta):
	# Hors du bloc de simulation : côté client la torche est répliquée, et les
	# sorties anticipées de _physics_process ne doivent pas laisser le son bloqué.
	if flashlight_on != _torch_audio_state:
		_torch_audio_state = flashlight_on
		AudioManager.set_player_torch(player_id, flashlight_on)

	if dead: return

	if shoot_cooldown > 0:
		shoot_cooldown -= delta
		if shoot_cooldown <= 0:
			shoot_cooldown = 0
			# Play ready sound here if desired
	
	if dazzle_amount > 0:
		dazzle_amount = max(0, dazzle_amount - delta * 2.0)
		
	if shake_intensity > 0:
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
		if shake_intensity < 0.5:
			shake_intensity = 0.0
		
		# Find the camera on this player
		for c in get_children():
			if c is Camera2D:
				if shake_intensity > 0:
					c.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_intensity
				else:
					c.offset = Vector2.ZERO

## [Hôte] Reçoit les commandes du client. Seul le peer propriétaire de P2 est
## accepté : sans cette garde, n'importe quel peer pourrait piloter P2.
@rpc("any_peer", "unreliable")
func rpc_send_inputs(seq: int, mov: Vector2, aim: Vector2, shoot: bool, torch: bool, sprint: bool) -> void:
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST: return
	if player_id != 1: return
	var state = get_tree().get_first_node_in_group("game_state")
	if state == null or multiplayer.get_remote_sender_id() != state.client_peer_id: return
	# Paquet arrivé après un plus récent : on le jette plutôt que de reculer.
	if seq <= _last_input_seq: return
	_last_input_seq = seq
	input_provider.update_input_state(mov, aim, shoot, torch, sprint)

## [Hôte] Purge l'état d'input à la déconnexion : sinon P2 resterait figé sur
## la dernière commande reçue (course en cours, torche allumée…).
func reset_network_input() -> void:
	_last_input_seq = -1
	if input_provider and input_provider.has_method("reset_input_state"):
		input_provider.reset_input_state()

func _send_inputs_to_host() -> void:
	var mov := input_provider.get_movement_vector()
	var aim := input_provider.get_aim_direction(global_position)
	var sprint := input_provider.is_sprint_pressed() and mov.length() > 0.1
	_input_seq += 1
	rpc_id(1, "rpc_send_inputs", _input_seq, mov, aim,
		input_provider.is_shoot_pressed(), input_provider.is_flashlight_pressed(), sprint)

## [Serveur / Client] Gère la physique (Sandbox autorisé).
func _physics_process(delta):
	if dead: return
	
	var state = get_tree().get_first_node_in_group("game_state")
	if state and state.ui._is_main_menu and not state.sandbox_mode:
		velocity = Vector2.ZERO
		flashlight_on = false
		return
		
	# En ligne, le client ne simule plus rien : il émet ses commandes et affiche
	# l'état que l'hôte lui réplique (mouvement donc soumis à la latence).
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT and player_id == 1:
		_send_inputs_to_host()

	var can_move = true
	if NetworkManager.current_mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN and multiplayer.has_multiplayer_peer():
		can_move = is_multiplayer_authority()

	if state and not (state.round_active or state.sandbox_mode):
		if can_move:
			velocity = velocity.move_toward(Vector2.ZERO, 1500.0 * delta)
			if velocity != Vector2.ZERO:
				move_and_slide()
			flashlight_on = false
			flashlight.enabled = false
			body_light.enabled = false
		return
		
	if can_move:
		var input_dir = input_provider.get_movement_vector()
		is_sprinting = input_provider.is_sprint_pressed() and input_dir.length() > 0.1
		if shoot_cooldown > 0 and current_weapon and not current_weapon.can_run_while_reloading:
			is_sprinting = false
			
		var current_speed = speed * (2.0 if is_sprinting else 1.0)
		if shoot_cooldown > 0 and current_weapon:
			current_speed *= current_weapon.movement_speed_while_reloading
		if dazzle_amount > 0:
			current_speed *= lerp(1.0, 0.4, dazzle_amount)
			
		velocity = input_dir * current_speed
		if velocity != Vector2.ZERO:
			move_and_slide()
		
		if velocity.length() > 20.0:
			step_distance_accumulated += velocity.length() * delta
			var step_dist := 60.0 if is_sprinting else 45.0
			if step_distance_accumulated >= step_dist:
				step_distance_accumulated = 0.0
				var pitch_mult := 1.122 if is_sprinting else 1.0
				AudioManager.play_sfx_2d_random_pitch("footstep", global_position, pitch_mult * 0.95, pitch_mult * 1.05)
	
		var aim_dir = input_provider.get_aim_direction(global_position)
		if aim_dir.length() > 0.1:
			var target_angle = aim_dir.angle()
			var aim_lerp_speed = 18.0 * (1.0 - dazzle_amount * 0.6)
			rotation = lerp_angle(rotation, target_angle, min(1.0, delta * aim_lerp_speed))
			
		if is_sprinting:
			flashlight_on = false
		else:
			flashlight_on = input_provider.is_flashlight_pressed()

	# Visuals update for all clients
	flashlight.enabled = flashlight_on
	body_light.enabled = flashlight_on

	if flashlight_on:
		if shoot_cooldown > 0:
			flashlight.energy = randf_range(1.5, 2.0)
		else:
			flashlight.energy = lerp(flashlight.energy, 2.5, 8.0 * delta)
			
		if current_weapon:
			body_light.energy = (flashlight.energy / 2.5) * 0.6 * current_weapon.backlight_multiplier
		else:
			body_light.energy = (flashlight.energy / 2.5) * 0.6
	
	if aim_cast and aim_line:
		var end_pos = Vector2(2000, 0)
		if aim_cast.is_colliding():
			end_pos = to_local(aim_cast.get_collision_point())
		aim_line.points = PackedVector2Array([Vector2(28, 0), end_pos])
	
	# Le tir suit l'autorité de simulation : en ligne c'est l'hôte qui l'arbitre
	# pour les deux joueurs, cooldown compris.
	if can_move and input_provider.is_shoot_pressed() and shoot_cooldown <= 0 and not is_sprinting:
		shoot()

func shoot():
	shoot_cooldown = current_weapon.cooldown
	get_tree().call_group("game_state", "spawn_bullet", self, muzzle.global_position, rotation, current_weapon)

func trigger_shoot_visuals():
	add_camera_shake(15.0, 15.0)
	muzzle_flash.enabled = true
	var tw = create_tween()
	var flash_intensity = current_weapon.muzzle_flash_intensity if current_weapon else 1.0
	var flash_duration = current_weapon.muzzle_flash_duration if current_weapon else 0.1
	tw.tween_property(muzzle_flash, "energy", 0.0, flash_duration).from(flash_intensity)
	tw.tween_callback(func(): muzzle_flash.enabled = false)
	
	visual_reveal.color.a = 1.0
	visual_reveal_ptr.color.a = 1.0
	if tw_reveal and tw_reveal.is_valid():
		tw_reveal.kill()
		
	tw_reveal = create_tween().set_parallel(true)
	tw_reveal.tween_property(visual_reveal, "color:a", 0.0, 2.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw_reveal.tween_property(visual_reveal_ptr, "color:a", 0.0, 2.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	if has_node("VisualRevealEnemy"):
		var vre = get_node("VisualRevealEnemy")
		var vrep = get_node("VisualRevealEnemyPtr")
		vre.color = Color(1.0, 1.0, 1.0, 1.0) 
		vrep.color = Color(1.0, 1.0, 1.0, 1.0)
		tw_reveal.tween_property(vre, "color:a", 0.0, 2.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw_reveal.tween_property(vrep, "color:a", 0.0, 2.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	AudioManager.play_sfx_2d_random_pitch("shoot", muzzle.global_position, 0.92, 1.08)

func take_damage(amount: float, source_player: Node2D):
	if dead: return
	
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
		var new_hp = max(0.0, hp - amount)
		var sid = source_player.player_id if source_player else -1
		if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
			rpc_update_hp.rpc(new_hp, sid)
		else:
			rpc_update_hp(new_hp, sid)
			
	hit_sound.play()
	AudioManager.play_sfx_2d_random_pitch("flesh_impact", global_position, 0.92, 1.08)
	AudioManager.update_low_health(player_id, hp <= 30.0 and not dead)

	
	# Violent camera shake on hit
	add_camera_shake(35.0, 8.0)
	
	# Trigger damage vignette (flashes red screen edges)
	if vignette_mat:
		vignette_mat.set_shader_parameter("intensity", 1.5)
		var tw = create_tween()
		tw.tween_method(func(val): vignette_mat.set_shader_parameter("intensity", val), 1.5, 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

@rpc("authority", "call_local", "reliable")
func rpc_update_hp(new_hp: float, source_id: int):
	hp = new_hp
	if hp <= 0 and not dead:
		hp = 0
		var state = get_tree().get_first_node_in_group("game_state")
		var killer = null
		if state:
			killer = state.p1 if source_id == 0 else state.p2
		die(killer)
	# Dynamic red light illuminating the scene to sell the impact
	var hit_light = PointLight2D.new()
	var grad = GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1, 0.5)
	var g = Gradient.new()
	# Pure blood red light, not pink/magenta
	g.set_color(0, Color(0.9, 0.0, 0.0, 1.0))
	g.set_color(1, Color(0.9, 0.0, 0.0, 0.0))
	grad.gradient = g
	grad.width = 400
	grad.height = 400
	hit_light.texture = grad
	hit_light.energy = 2.0
	hit_light.shadow_enabled = true
	# Cast shadows from walls ONLY (mask 1). If we cast from players (mask 4), the player's own occluder blocks 100% of the light!
	hit_light.shadow_item_cull_mask = 1
	# Main blood light affects walls (1) and other stuff (4), but NOT players (2)
	hit_light.range_item_cull_mask = 1 | 4
	add_child(hit_light)
	
	var tw_l = create_tween()
	# Perfectly smooth, lingering fade out
	tw_l.tween_property(hit_light, "energy", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_l.tween_callback(hit_light.queue_free)

func die(killer: Node2D):
	if dead: return
	dead = true
	AudioManager.update_low_health(player_id, false)

	visual.visible = false
	visual_ptr.visible = false
	visual_dim.visible = false
	visual_dim_ptr.visible = false
	visual_reveal.visible = false
	visual_reveal_ptr.visible = false
	
	if has_node("VisualEnemy"):
		get_node("VisualEnemy").visible = false
		get_node("VisualEnemyPtr").visible = false
		get_node("VisualRevealEnemy").visible = false
		get_node("VisualRevealEnemyPtr").visible = false
	flashlight.enabled = false
	body_light.enabled = false
	
	# Satisfying Death Effect (Screen Flash + Chromatic Aberration)
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)
	
	var flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float flash_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float aberration_amount = 0.05;

void fragment() {
	float offset = aberration_amount * flash_intensity;
	float r = texture(screen_texture, SCREEN_UV + vec2(offset, 0.0)).r;
	float g = texture(screen_texture, SCREEN_UV).g;
	float b = texture(screen_texture, SCREEN_UV - vec2(offset, 0.0)).b;
	vec3 color = mix(vec3(r, g, b), vec3(1.0), flash_intensity);
	COLOR = vec4(color, 1.0);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("flash_intensity", 1.0)
	flash_rect.material = mat
	ui_layer.add_child(flash_rect)
	
	var tw = create_tween()
	tw.tween_method(func(val): mat.set_shader_parameter("flash_intensity", val), 1.0, 0.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ui_layer.queue_free)
	
	# Floating FATAL Text
	var lbl = Label.new()
	lbl.text = "FATAL"
	var settings = LabelSettings.new()
	settings.font_size = 72
	settings.font_color = Color(1.0, 0.0, 0.0)
	settings.outline_size = 12
	settings.outline_color = Color.BLACK
	lbl.label_settings = settings
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = global_position - Vector2(100, 100)
	lbl.z_index = 200
	
	var lbl_mat = CanvasItemMaterial.new()
	lbl_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	lbl.material = lbl_mat
	
	get_parent().add_child(lbl)
	
	var txt_tw = create_tween().set_parallel(true)
	lbl.scale = Vector2.ZERO
	lbl.pivot_offset = Vector2(100, 50)
	txt_tw.tween_property(lbl, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	txt_tw.tween_property(lbl, "position", lbl.position + Vector2(0, -100), 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	txt_tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(1.0)
	txt_tw.chain().tween_callback(lbl.queue_free)
	
	get_tree().call_group("game_state", "player_died", player_id, killer.player_id if killer else -1)

func add_camera_shake(intensity: float, decay: float = 5.0):
	if intensity > shake_intensity:
		shake_intensity = intensity
	shake_decay = decay

func apply_dazzle(amount: float):
	dazzle_amount = min(1.0, dazzle_amount + amount)

func _calculate_uvs(poly: Polygon2D):
	if poly.polygon.size() == 0: return
	var pts = poly.polygon
	var min_x = pts[0].x
	var max_x = pts[0].x
	var min_y = pts[0].y
	var max_y = pts[0].y
	for p in pts:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
		
	var w = max_x - min_x
	var h = max_y - min_y
	if w == 0: w = 1
	if h == 0: h = 1
	
	var uvs = PackedVector2Array()
	for p in pts:
		uvs.append(Vector2((p.x - min_x)/w, (p.y - min_y)/h))
	poly.uv = uvs

func hide_all_visuals():
	visual.hide()
	visual_ptr.hide()
	visual_dim.hide()
	visual_dim_ptr.hide()
	visual_reveal.hide()
	visual_reveal_ptr.hide()
	visual_enemy.hide()
	visual_enemy_ptr.hide()
	visual_reveal_enemy.hide()
	visual_reveal_enemy_ptr.hide()

func show_all_visuals():
	visual.show()
	visual_ptr.show()
	visual_dim.show()
	visual_dim_ptr.show()
	visual_reveal.show()
	visual_reveal_ptr.show()
	visual_enemy.show()
	visual_enemy_ptr.show()
	visual_reveal_enemy.show()
	visual_reveal_enemy_ptr.show()
