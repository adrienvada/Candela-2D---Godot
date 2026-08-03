extends Node
class_name GameState

@export var round_time: float = 120.0

var time_left: float = 120.0
var round_active: bool = false
var sandbox_mode: bool = false
var game_over: bool = false
var _first_replay_frame: bool = false
var p1_ready_for_rematch: bool = false
var p2_ready_for_rematch: bool = false
var _hosted_weapon_1_idx: int = 0

var p1_kills: int = 0
var p2_kills: int = 0

var p1: Player
var p2: Player

var weapon_pistolet: WeaponData
var weapon_fusil: WeaponData
var weapon_pompe: WeaponData
var weapon_arbalete: WeaponData

@onready var ui = $UI
@onready var vp1 = $SplitScreen/ViewportContainer1/SubViewport1
@onready var vp2 = $SplitScreen/ViewportContainer2/SubViewport2
@onready var arena = $SplitScreen/ViewportContainer1/SubViewport1/Arena
@onready var players_node = $SplitScreen/ViewportContainer1/SubViewport1/Players
@onready var bullet_container = $SplitScreen/ViewportContainer1/SubViewport1/Bullets

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
	weapon_fusil.torch_angle_deg = 10.0
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
	weapon_pompe.torch_angle_deg = 60.0
	weapon_pompe.torch_scale = 1.0
	
	weapon_arbalete = WeaponData.new()
	weapon_arbalete.name = "Arbalète"
	weapon_arbalete.cooldown = 1.5
	weapon_arbalete.bullet_speed = 12000.0
	weapon_arbalete.bullet_max_distance = 10000.0
	weapon_arbalete.damage_center = 80.0
	weapon_arbalete.damage_edge = 80.0
	weapon_arbalete.max_bounces = 0
	weapon_arbalete.damages_shooter = false
	weapon_arbalete.emits_light = false
	weapon_arbalete.torch_angle_deg = 5.0 # Très fin
	weapon_arbalete.torch_scale = 3.5     # Aussi loin que le fusil
	weapon_arbalete.torch_brightness = 0.3 # Plus discret / moins lumineux
	
	weapon_arbalete.muzzle_flash_intensity = 0.1
	weapon_arbalete.muzzle_flash_duration = 0.05
	weapon_arbalete.backlight_multiplier = 0.1
	weapon_arbalete.movement_speed_while_reloading = 0.5
	weapon_arbalete.can_run_while_reloading = false
	weapon_arbalete.bullet_color = Color(0.7, 0.7, 0.7, 1.0)
	weapon_arbalete.bullet_width = 3.0
	weapon_arbalete.bullet_light_energy = 0.0
	
	ReplaySystem.replay_spawn_bullet.connect(_on_replay_spawn_bullet)
	ui.replay_requested.connect(_on_replay_requested)
	ui.quit_requested.connect(_on_quit_requested)
	ui.main_menu_requested.connect(_on_main_menu_requested)
	
	# Set global clear color to black to fix gray areas
	RenderingServer.set_default_clear_color(Color.BLACK)
	
	# Share the world_2d for split screen
	vp2.world_2d = vp1.world_2d
	
	NetworkManager.player_connected.connect(_on_peer_connected)
	NetworkManager.player_disconnected.connect(_on_peer_disconnected)
	NetworkManager.host_disconnected.connect(_on_host_disconnected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.connection_success.connect(_on_connection_success)
	
	rebuild_arena()
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

func _on_peer_connected(id: int):
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		p2.set_multiplayer_authority(id)
		# P2 vient d'arriver et n'a pas encore choisi : arme par défaut jusqu'au
		# prochain rematch, où son choix sera transmis.
		rpc_start_round.rpc(_hosted_weapon_1_idx, 0, _host_map_code())

func _on_peer_disconnected(id: int):
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		ui.show_dialog_message("Déconnexion", "Le Joueur 2 s'est déconnecté.")
		round_active = false
		sandbox_mode = true
		p2_ready_for_rematch = false
		p1_kills = 0
		p2_kills = 0
		p2.hide()
		p2.set_collision_layer_value(1, false)
		p2.set_collision_mask_value(1, false)
		ui.waiting_label.show()
		ui.time_label.text = "EN ATTENTE DU JOUEUR 2..."
		if game_over:
			ui.hide_game_over()
			game_over = false
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		_on_main_menu_requested()

func _on_debug_light_toggled(toggled_on: bool):
	var mod = arena.get_node_or_null("CanvasModulate")
	if mod:
		mod.color = Color(0.3, 0.3, 0.3) if toggled_on else Color(0, 0, 0)

## Construit l'arène depuis la carte sélectionnée.
##
## Tout passe par le pipeline JSON, y compris l'arène standard : le double
## chemin « géométrie codée en dur / carte custom » de la version précédente
## était la source des divergences (murs sans occluder, tuiles invisibles en
## écran partagé). Un seul chemin, donc un seul comportement à garantir.
##
## Appelable à volonté — chaque manche la rappelle, ce qui permet de changer
## de carte depuis le menu sans redémarrer la partie.
func rebuild_arena() -> void:
	var data: Dictionary = MapData.get_selected()
	if data.is_empty():
		push_error("GameState: aucune carte à charger")
		return

	# La géométrie historique de arena.tscn ne sert plus qu'à documenter le
	# format ; elle est neutralisée pour ne pas doubler la carte JSON.
	var static_geom := arena.get_node_or_null("StaticGeometry")
	if static_geom:
		static_geom.hide()
		static_geom.process_mode = Node.PROCESS_MODE_DISABLED
		for child in static_geom.get_children():
			if child is CollisionObject2D:
				child.process_mode = Node.PROCESS_MODE_DISABLED
	var ground := arena.get_node_or_null("Ground")
	if ground:
		ground.hide()

	# Purge de la construction précédente (rematch, changement de carte).
	for node_name in ["CustomFloor", "CustomWalls", "CustomFloor_P1", "CustomFloor_P2",
			"CustomWalls_P1", "CustomWalls_P2", "CustomWallBodies"]:
		var previous := arena.get_node_or_null(node_name)
		if previous:
			arena.remove_child(previous)
			previous.queue_free()

	var tileset := CandelaTileSet.create_tileset()

	var floor_layer := TileMapLayer.new()
	floor_layer.name = "CustomFloor"
	floor_layer.tile_set = tileset
	floor_layer.z_index = -1
	arena.add_child(floor_layer)

	var walls_layer := TileMapLayer.new()
	walls_layer.name = "CustomWalls"
	walls_layer.tile_set = tileset
	walls_layer.z_index = 0
	arena.add_child(walls_layer)

	var spawns := arena.get_node_or_null("SpawnPoints")
	if spawns == null:
		spawns = Node2D.new()
		spawns.name = "SpawnPoints"
		arena.add_child(spawns)
	_ensure_spawn_marker(spawns, "P1Spawn")
	_ensure_spawn_marker(spawns, "P2Spawn")

	MapData.apply_to_layers(floor_layer, walls_layer, spawns, data)

	# Collisions ET occluders produits ensemble à partir des mêmes rectangles.
	# Sans les occluders, la torche traverse les murs et le jeu perd son sujet.
	MapGeometry.build_collisions(data, arena)

	# Écran partagé : chaque joueur reçoit sa copie des calques, éclairée par
	# sa seule lumière ambiante. Sans ça, le halo d'un joueur révélerait sa
	# position sur l'écran de l'autre.
	_duplicate_layer_for_player(floor_layer, 2, 1 | 16)
	_duplicate_layer_for_player(floor_layer, 4, 1 | 32)
	_duplicate_layer_for_player(walls_layer, 2, 1 | 16)
	_duplicate_layer_for_player(walls_layer, 4, 1 | 32)

	# Rendu néon des murs (l'original reste visible des deux viewports).
	var wall_mat := CanvasItemMaterial.new()
	wall_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	walls_layer.material = wall_mat

## Duplique un calque pour un seul viewport, avec son masque de lumière propre.
func _duplicate_layer_for_player(layer: TileMapLayer, visibility: int, light_mask: int) -> void:
	var copy := layer.duplicate() as TileMapLayer
	copy.name = "%s_P%d" % [layer.name, 1 if visibility == 2 else 2]
	copy.visibility_layer = visibility
	copy.light_mask = light_mask
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	copy.material = mat
	arena.add_child(copy)

func _ensure_spawn_marker(spawns: Node2D, marker_name: String) -> void:
	if spawns.get_node_or_null(marker_name) == null:
		var marker := Marker2D.new()
		marker.name = marker_name
		spawns.add_child(marker)


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

func _set_player_input_provider(player: Player, provider: InputProvider, device: int = 0) -> void:
	if is_instance_valid(player.input_provider):
		player.input_provider.queue_free()
	if provider is LocalInputProvider:
		provider.device_id = device
	player.input_provider = provider
	player.add_child(provider)

func _apply_network_mode():
	if NetworkManager.current_mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN or not multiplayer.has_multiplayer_peer():
		p1.set_multiplayer_authority(1)
		p2.set_multiplayer_authority(1)
		
		_set_player_input_provider(p1, LocalInputProvider.new(), 0)
		_set_player_input_provider(p2, LocalInputProvider.new(), 1)
		
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		p1.set_multiplayer_authority(1)
		
		_set_player_input_provider(p1, LocalInputProvider.new(), 0)
		_set_player_input_provider(p2, NetworkInputProvider.new(), 1)
		
		# If a client is already connected, assign them.
		var peers = multiplayer.get_peers()
		if peers.size() > 0:
			p2.set_multiplayer_authority(peers[0])
		
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		p1.set_multiplayer_authority(1)
		p2.set_multiplayer_authority(multiplayer.get_unique_id())
		
		_set_player_input_provider(p1, NetworkInputProvider.new(), 0)
		_set_player_input_provider(p2, LocalInputProvider.new(), 0)

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



func _get_spawn_position(player_id: int) -> Vector2:
	var spawn_node_name := "P1Spawn" if player_id == 0 else "P2Spawn"

	if is_instance_valid(arena):
		var spawns = arena.get_node_or_null("SpawnPoints")
		if is_instance_valid(spawns):
			var node = spawns.get_node_or_null(spawn_node_name)
			# Un marqueur parqué hors écran signale une apparition non posée.
			if is_instance_valid(node) and node.global_position.x > -500.0:
				return node.global_position

		# Repli : on relit directement la carte plutôt que d'inventer une
		# position en dur, qui atterrirait probablement dans un mur.
		var layer := arena.get_node_or_null("CustomFloor") as TileMapLayer
		if is_instance_valid(layer):
			return MapData.get_spawn_world_position(player_id, layer)

	return Vector2(200, 200) if player_id == 0 else Vector2(800, 600)

func _start_round():
	var w1_idx = 0
	if ui.p1_weapon_group.get_pressed_button():
		w1_idx = ui.p1_weapon_group.get_pressed_button().get_index()
	var w2_idx = 0
	if ui.p2_weapon_group.get_pressed_button():
		w2_idx = ui.p2_weapon_group.get_pressed_button().get_index()

	_restore_viewports()
	p1.global_position = _get_spawn_position(0)
	p2.global_position = _get_spawn_position(1)
	p1.rotation = 0
	p2.rotation = PI
	p1.show_all_visuals()
	p2.show_all_visuals()
	p1.get_node("VisualColored").show()
	p1.get_node("VisualDim").show()
	p1.get_node("VisualReveal").show()
	p2.get_node("VisualColored").show()
	p2.get_node("VisualDim").show()
	p2.get_node("VisualReveal").show()
	cam1.global_position = p1.global_position
	cam2.global_position = p2.global_position

	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		if multiplayer.get_peers().size() == 0:
			round_active = false
			sandbox_mode = true
			ui.time_label.text = "02:00"
			ui.waiting_label.show()
			ui.hide_game_over()
			p2.hide()
			p2.set_collision_layer_value(1, false)
			p2.set_collision_mask_value(1, false)
			_hosted_weapon_1_idx = w1_idx
			return
		else:
			rpc_start_round.rpc(w1_idx, w2_idx, _host_map_code())
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return # Client ne démarre pas la logique locale
	else:
		_do_start_round(w1_idx, w2_idx)

@rpc("authority", "call_local", "reliable")
func rpc_start_round(w1_idx: int, w2_idx: int, map_code: String = ""):
	# Le client adopte la carte de l'hôte : sans ça les deux joueurs
	# s'affronteraient sur des géométries différentes.
	if map_code != "" and NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		var err := MapData.adopt_shared_map(map_code)
		if err != "":
			ui.show_dialog_message("Carte", "Carte de l'hôte illisible : " + err)
	_do_start_round(w1_idx, w2_idx)

## Code compact de la carte active, à joindre au démarrage de manche.
## Vide hors mode hôte : personne d'autre n'a autorité sur la carte.
func _host_map_code() -> String:
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		return MapData.get_map_share_code()
	return ""

func _do_start_round(w1_idx: int, w2_idx: int):
	# Reconstruit l'arène à chaque manche : c'est ce qui rend effectif un
	# changement de carte depuis le menu, sans redémarrer le jeu.
	rebuild_arena()
	sandbox_mode = false
	p2.show()
	p2.set_collision_layer_value(1, true)
	p2.set_collision_mask_value(1, true)
	ui.waiting_label.hide()
	ui.hide_game_over()
	ui.btn_replay.text = "REJOUER"
	ui.btn_replay.remove_theme_color_override("font_color")
	game_over = false
	_restore_viewports()
	ui.hide_killcam()
	AudioManager.set_in_match(true)
	AudioManager.reset_low_health()
	AudioManager.play_music("music_match")
	AudioManager.play_speaker("spk_fight")

	p1.show_all_visuals()
	p2.show_all_visuals()

	p1.hp = 100.0
	p2.hp = 100.0
	p1.dead = false
	p2.dead = false
	
	var w1 = weapon_arbalete if w1_idx == 3 else (weapon_pompe if w1_idx == 2 else (weapon_fusil if w1_idx == 1 else weapon_pistolet))
	var w2 = weapon_arbalete if w2_idx == 3 else (weapon_pompe if w2_idx == 2 else (weapon_fusil if w2_idx == 1 else weapon_pistolet))
	
	p1.equip_weapon(w1)
	p2.equip_weapon(w2)
	
	p1.get_node("VisualColored").show()
	p1.get_node("VisualDim").show()
	p1.get_node("VisualReveal").show()
	p2.get_node("VisualColored").show()
	p2.get_node("VisualDim").show()
	p2.get_node("VisualReveal").show()
	
	p1.global_position = _get_spawn_position(0)
	p2.global_position = _get_spawn_position(1)
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
			if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
				rpc_end_round.rpc(-1)
			elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
				pass
			else:
				_do_end_round(-1)

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
				cam2.global_position = target_pos
				cam2.zoom = target_zoom
				_first_replay_frame = false
			else:
				# Exponential smoothing prevents overshoot and jumping when delta scales wildly in bullet time
				var lerp_speed = 3.0 if Engine.time_scale >= 0.9 else 6.0
				var weight = 1.0 - exp(-lerp_speed * unscaled_delta)
				cam1.global_position = cam1.global_position.lerp(target_pos, weight)
				cam1.zoom = cam1.zoom.lerp(target_zoom, weight)
				cam2.global_position = cam2.global_position.lerp(target_pos, weight)
				cam2.zoom = cam2.zoom.lerp(target_zoom, weight)
			
		# Allow skipping killcam (Indépendant)
		if Input.is_action_just_pressed("p1_skip_killcam"):
			if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
				ReplaySystem.playing_back = false
				Engine.time_scale = 1.0
		if Input.is_action_just_pressed("p2_skip_killcam"):
			if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST:
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

func _get_weapon_idx(w: WeaponData) -> int:
	if w == weapon_arbalete: return 3
	if w == weapon_pompe: return 2
	if w == weapon_fusil: return 1
	return 0

@rpc("any_peer", "reliable")
func rpc_request_shoot(shooter_id: int, pos: Vector2, rot: float):
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST: return
	var sender = multiplayer.get_remote_sender_id()
	
	if shooter_id == 1 and sender == p2.get_multiplayer_authority():
		if p2.shoot_cooldown <= 0:
			var w_idx = _get_weapon_idx(p2.current_weapon)
			rpc_spawn_bullet.rpc(shooter_id, pos, rot, w_idx)

@rpc("authority", "call_local", "reliable")
func rpc_spawn_bullet(shooter_id: int, pos: Vector2, rot: float, weapon_idx: int):
	var shooter = p1 if shooter_id == 0 else p2
	var weapon = weapon_arbalete if weapon_idx == 3 else (weapon_pompe if weapon_idx == 2 else (weapon_fusil if weapon_idx == 1 else weapon_pistolet))
	_do_spawn_bullet(shooter, pos, rot, weapon)

func spawn_bullet(shooter: Node2D, pos: Vector2, rot: float, weapon: WeaponData):
	if not round_active and not sandbox_mode: return
	
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		rpc_id(1, "rpc_request_shoot", shooter.player_id, pos, rot)
		return
		
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		var w_idx = _get_weapon_idx(weapon)
		rpc_spawn_bullet.rpc(shooter.player_id, pos, rot, w_idx)
	else:
		_do_spawn_bullet(shooter, pos, rot, weapon)

func _do_spawn_bullet(shooter: Node2D, pos: Vector2, rot: float, weapon: WeaponData):
	if not round_active and not sandbox_mode: return
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
	
	if shooter.has_method("trigger_shoot_visuals"):
		shooter.trigger_shoot_visuals()

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
	
	# --- REPLAY / KILLCAM AUDIO ---
	# Joue le son du tir lors du rejeu d'une balle pendant la Killcam.
	# AudioManager applique automatiquement le ralenti dynamique basé sur Engine.time_scale (ex: 0.03x pendant le bullet time).
	AudioManager.play_sfx_2d_random_pitch("shoot", pos, 0.92, 1.08)

func player_died(dead_id: int, _killer_id: int):
	if not round_active: return
	
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		return
		
	var w = 1 if dead_id == 0 else 0
	
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		rpc_end_round.rpc(w)
	else:
		_do_end_round(w)

@rpc("authority", "call_local", "reliable")
func rpc_end_round(winner_id: int):
	_do_end_round(winner_id)

func _do_end_round(winner_id: int):
	if winner_id == 1:
		p2_kills += 1
	elif winner_id == 0:
		p1_kills += 1
	round_active = false
	AudioManager.set_in_match(false)
	AudioManager.play_music("music_victory")

	if winner_id == 0:
		AudioManager.play_speaker("spk_p1_wins")
	elif winner_id == 1:
		AudioManager.play_speaker("spk_p2_wins")
	else:
		AudioManager.play_speaker("spk_draw")

	
	if winner_id != -1:
		ui.force_close_pause() # Ferme la pause s'il est ouvert pour afficher la Killcam
		# Wait 1.5 seconds to capture blood physics and reaction!
		await get_tree().create_timer(1.5).timeout
		
	ReplaySystem.stop_recording()
	
	if winner_id != -1:
		# Enter Fullscreen Killcam mode
		var mod = arena.get_node_or_null("CanvasModulate")
		if mod:
			mod.color = Color(0.3, 0.3, 0.3)
		
		if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:
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
		
		# Attendre 2 secondes supplémentaires sur l'arrêt sur image avant d'afficher le menu de fin
		await get_tree().create_timer(2.0).timeout
		
		# DO NOT restore split screen or reset cameras here!
		# It freezes the screen perfectly on the death frame behind the menu.
		
	game_over = true
	ui.show_game_over(winner_id)
	ui.game_over_score.text = "KILLS : %d - %d" % [p1_kills, p2_kills]

func _on_replay_requested():
	if ui._is_main_menu:
		if ui.btn_mode_host.button_pressed:
			NetworkManager.host_game()
			_apply_network_mode()
			game_over = false
			ui.hide_game_over()
			_restore_viewports()
			_start_round()
		elif ui.btn_mode_join.button_pressed:
			NetworkManager.join_game(ui.ip_input.text)
			ui.network_status_label.text = "[ONLINE_CLIENT] | Connexion au serveur en cours..."
			ui.btn_replay.text = "Connexion au serveur en cours..."
			
			var timer = get_tree().create_timer(5.0)
			timer.timeout.connect(func():
				if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT and multiplayer.get_peers().size() == 0:
					_on_connection_failed()
			)
		else:
			NetworkManager.disconnect_from_game()
			_apply_network_mode()
			game_over = false
			ui.hide_game_over()
			_restore_viewports()
			_start_round()
	else:
		if ui.btn_replay.text == "✓ PRÊT":
			ui.btn_replay.text = "REJOUER"
			ui.btn_replay.remove_theme_color_override("font_color")
			if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
				rpc_id(1, "rpc_client_unready")
			elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
				p1_ready_for_rematch = false
				ui.time_label.text = "EN ATTENTE D'UN ADVERSAIRE..."
			return
			
		var w2_idx = 0
		if ui.p2_weapon_group.get_pressed_button():
			w2_idx = ui.p2_weapon_group.get_pressed_button().get_index()
			
		ui.btn_replay.text = "✓ PRÊT"
		ui.btn_replay.add_theme_color_override("font_color", Color.GREEN)
		
		if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
			rpc_id(1, "rpc_client_ready", w2_idx)
		elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
			p1_ready_for_rematch = true
			if ui.p1_weapon_group.get_pressed_button():
				_hosted_weapon_1_idx = ui.p1_weapon_group.get_pressed_button().get_index()
			_check_rematch_start()
		else:
			_start_round()

@rpc("any_peer", "reliable")
func rpc_client_ready(w2_idx: int):
	if multiplayer.get_remote_sender_id() == p2.get_multiplayer_authority():
		p2_ready_for_rematch = true
		ui.p2_weapon_group.get_buttons()[w2_idx].button_pressed = true
		_check_rematch_start()

func _check_rematch_start():
	if p1_ready_for_rematch and p2_ready_for_rematch:
		p1_ready_for_rematch = false
		p2_ready_for_rematch = false
		var w2_idx = 0
		if ui.p2_weapon_group.get_pressed_button():
			w2_idx = ui.p2_weapon_group.get_pressed_button().get_index()
		rpc_start_round.rpc(_hosted_weapon_1_idx, w2_idx, _host_map_code())
	elif not p1_ready_for_rematch:
		ui.time_label.text = "EN ATTENTE D'UN ADVERSAIRE..."

func _restore_viewports():
	if NetworkManager.current_mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		vp1.get_parent().show()
		vp2.get_parent().show()
		ui.center_line.show()
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		vp1.get_parent().show()
		vp2.get_parent().hide()
		ui.center_line.hide()
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		vp1.get_parent().hide()
		vp2.get_parent().show()
		ui.center_line.hide()
	cam1.zoom = Vector2(1.0, 1.0)
	cam2.zoom = Vector2(1.0, 1.0)
	cam1.global_position = p1.global_position
	cam2.global_position = p2.global_position
	var mod = arena.get_node_or_null("CanvasModulate")
	if mod:
		mod.color = Color(0, 0, 0)


func _on_main_menu_requested():
	NetworkManager.disconnect_from_game()
	
	round_active = false
	sandbox_mode = false
	game_over = true
	p1_ready_for_rematch = false
	p2_ready_for_rematch = false
	
	if ReplaySystem:
		ReplaySystem.stop_recording()
		ReplaySystem.playing_back = false
		
	for c in bullet_container.get_children():
		c.queue_free()
		
	if is_instance_valid(p1):
		p1.hp = 100.0
		p1.dead = false
		p1.global_position = _get_spawn_position(0)
	if is_instance_valid(p2):
		p2.hp = 100.0
		p2.dead = false
		p2.global_position = _get_spawn_position(1)
		
	p1_kills = 0
	p2_kills = 0
	
	# Purge les traces de sang et autres entités dynamiques de l'arène.
	# NB : "SpawnPoints" doit figurer ici — l'ancienne liste testait "SpawnP1"
	# et "SpawnP2", des noms qui n'existent pas, si bien qu'un retour au menu
	# détruisait définitivement les points d'apparition de arena.tscn.
	const ARENA_KEEP := ["Ground", "StaticGeometry", "SpawnPoints", "KillcamOverlay"]
	for child in arena.get_children():
		if child.name in ARENA_KEEP:
			continue
		if child is CanvasModulate or child is BackBufferCopy or child is Camera2D:
			continue
		child.queue_free()
	
	ui.show_main_menu()
	AudioManager.play_music("music_menu")

func _on_quit_requested():
	get_tree().quit()

## [Client Uniquement] Appelé quand l'hôte ferme le serveur ou plante.
func _on_host_disconnected():
	ui.show_dialog_message("Déconnexion", "L'hôte a fermé la partie. Retour au menu principal.")
	_on_main_menu_requested()

## [Client Uniquement] Intercepte un échec de connexion (timeout ou serveur plein).
func _on_connection_failed():
	ui.show_dialog_message("Erreur", "Impossible de se connecter au serveur (Timeout/IP invalide ou Serveur Plein).")
	_on_main_menu_requested()

## [Client Uniquement] Appelé quand la connexion au serveur réussit.
func _on_connection_success():
	_apply_network_mode()
	game_over = false
	ui.hide_game_over()
	_restore_viewports()
	_start_round()

@rpc("any_peer", "reliable")
func rpc_client_unready():
	if multiplayer.get_remote_sender_id() == p2.get_multiplayer_authority():
		p2_ready_for_rematch = false
		ui.time_label.text = "EN ATTENTE D'UN ADVERSAIRE..."
