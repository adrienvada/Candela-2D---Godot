extends Node
class_name GameState

const SHADER_GHOST := preload("res://ghost_unshaded.gdshader")

## Un match = UNE manche de 5 minutes (BO1). Le format n'est pas en dur : il
## transite par MatchRecord.Format pour qu'un BO3/BO5 puisse s'ajouter sans
## refonte. Seul le BO1 est implémenté.
const MATCH_FORMAT := MatchRecord.Format.BO1

@export var round_time: float = MatchRecord.ROUND_DURATION

var time_left: float = MatchRecord.ROUND_DURATION
var round_active: bool = false
var sandbox_mode: bool = false
var game_over: bool = false
var _first_replay_frame: bool = false
var p1_ready_for_rematch: bool = false
var p2_ready_for_rematch: bool = false
# Bascule locale « prêt à rejouer ». État canonique : le libellé du bouton
# REJOUER n'en est qu'un reflet — l'ancienne logique comparait le texte du
# bouton, que la moindre reformulation aurait cassée en silence.
var local_ready_for_rematch: bool = false
var _hosted_weapon_1_idx: int = 0

# Score de session : nombre de matchs gagnés depuis le lancement de la série.
# Remis à zéro au retour au menu, pas entre deux matchs.
var p1_session_wins: int = 0
var p2_session_wins: int = 0

# Manches gagnées dans le match en cours. En BO1 elles retombent à zéro à
# chaque fin de match ; elles existent pour que les formats longs s'ajoutent
# sans toucher à la fin de manche.
var p1_round_wins: int = 0
var p2_round_wins: int = 0

# Réserve de particules d'impact, partagée par toutes les balles.
var particle_pool: ParticlePool
# Cible d'échauffement, visible en bac à sable uniquement.
var training_target: TrainingTarget

var p1: Player
var p2: Player

# Peer de l'unique client (0 si aucun). L'autorité réseau de P2 reste l'hôte,
# c'est donc cet id qui sert de garde pour tout ce qui vient du client.
var client_peer_id: int = 0

# Décompte de départ, joué à l'identique des deux côtés : il donne au client le
# temps de recevoir la manche et évite les départs décalés.
## Torche des fantômes pendant la killcam : moitié de l'intensité de jeu
## (2,5). À pleine puissance le halo passait par-dessus la balle, qui est le
## sujet même de la séquence — on regarde le tir, pas l'éclairage.
const KILLCAM_TORCH_ENERGY := 1.25

const COUNTDOWN_DURATION := 3.0
var countdown_left: float = 0.0

# [Client] Tirs rendus localement avant l'accord de l'hôte, horodatés pour être
# dédupliqués à l'arrivée de la balle officielle.
const PREDICTED_SHOT_TTL_MS := 1000
var _predicted_shots: Array[int] = []

# [Hôte] Historique des positions pour la compensation de latence. La fenêtre
# couvre le recul maximal avec de la marge, sans conserver davantage.
const POS_HISTORY_WINDOW := 0.4
const LAG_COMP_MAX := 0.2
var _pos_history: Array[Dictionary] = []

# Recalage du chronomètre : le client décrémente localement entre deux envois.
const TIME_SYNC_INTERVAL := 5.0
var _time_sync_accum: float = 0.0

# Échéance de connexion du client, à neutraliser dès que l'issue est connue.
var _join_deadline_active: bool = false

# Séquence de fin de manche : _do_end_round est une coroutine longue (attente du
# sang, killcam, arrêt sur image). Tout ce qui survient entretemps — nouvelle
# manche, déconnexion, retour au menu — incrémente le jeton, ce qui fait
# abandonner la coroutine en vol au lieu de la laisser écraser l'état neuf.
var _round_token: int = 0
var _end_sequence_active: bool = false

# Vrai entre le début d'un match EN LIGNE et son archivage. Décision actée :
# quitter un match en cours vaut forfait — le joueur resté gagne, celui qui part
# perd. Ce jeton dit qu'il reste un résultat à écrire, et il n'y en a qu'un :
# l'abandon emprunte plusieurs chemins de retour au menu, qui se croisent.
var _forfeit_pending: bool = false

# [Hôte] Effets différés jusqu'à la fin de la séquence : la killcam de chaque
# machine a sa propre durée, le client peut donc être prêt — ou arriver — alors
# que l'hôte est encore au ralenti.
var _pending_client_start: bool = false
var _pending_p2_weapon_idx: int = -1

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
	_setup_particle_pool()
	_setup_training_target()
	
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
		client_peer_id = id
		p2.reset_network_input()
		# Arrivée pendant une killcam ou l'écran de fin : lancer la manche ici
		# couperait la séquence en cours des deux côtés.
		if _end_sequence_active:
			_pending_client_start = true
			return
		# La manche n'est PAS lancée ici : elle attend rpc_client_weapon. Partir
		# avant l'arrivée de ce paquet imposait le pistolet à P2 pour tout le
		# match — en BO1 aucun rematch ne vient rattraper le choix.

func _on_peer_disconnected(id: int):
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		# Avant toute remise à zéro : l'enregistrement lit les armes, le chrono et
		# le mode, que la suite de cette fonction efface.
		_archive_forfeit(0)
		if id == client_peer_id:
			client_peer_id = 0
		# Toute séquence de fin en vol devient caduque : sans ce jeton elle
		# reviendrait afficher un écran de victoire par-dessus l'attente.
		_round_token += 1
		_end_sequence_active = false
		_pending_client_start = false
		_pending_p2_weapon_idx = -1
		# Un départ interrompu en plein 3-2-1 laisserait countdown_left figé, donc
		# l'hôte immobile pour toujours dans son bac à sable.
		countdown_left = 0.0
		ui.set_countdown(0.0)
		ui.force_close_pause()
		_abort_killcam()
		_restore_viewports()
		# L'hôte simule P2 : sans purge il continuerait à courir sur la dernière
		# commande reçue.
		p2.reset_network_input()
		p2.velocity = Vector2.ZERO
		p2.is_sprinting = false
		p2.flashlight_on = false
		ui.show_dialog_message("Déconnexion", "Le Joueur 2 s'est déconnecté.")
		round_active = false
		sandbox_mode = true
		p2_ready_for_rematch = false
		# Un « ✓ PRÊT » resté armé attendrait un adversaire qui n'existe plus.
		p1_ready_for_rematch = false
		local_ready_for_rematch = false
		ui.btn_replay.text = "REJOUER"
		ui.btn_replay.remove_theme_color_override("font_color")
		p1_session_wins = 0
		p2_session_wins = 0
		p1_round_wins = 0
		p2_round_wins = 0
		p2.hide()
		p2.set_collision_layer_value(1, false)
		p2.set_collision_mask_value(1, false)
		_set_training_target_active(true)
		ui.show_waiting_for_opponent()
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


## Les nœuds ajoutés ici portent des noms EXPLICITES, et c'est une contrainte
## réseau, pas une coquetterie.
##
## Sans nom, Godot en fabrique un depuis un compteur global d'objets créés
## (« @CharacterBody2D@269 »), dont la valeur dépend de tout ce qui a été
## instancié avant — jusqu'au nombre de cartes dans la bibliothèque, la galerie
## construisant un panneau par carte. Deux machines aux bibliothèques
## différentes donnaient donc deux noms différents au même joueur.
##
## Or un RPC de scène ne se route que par le chemin du nœud : les commandes du
## client désignaient chez l'hôte un nœud inexistant et étaient jetées sans le
## moindre message — l'adversaire restait figé sur son apparition alors que le
## lien, le ping et les identifiants de pairs étaient tous parfaitement sains.
func _setup_players():
	p1 = player_scene.instantiate()
	p1.name = "Player1"
	p1.player_id = 0
	players_node.add_child(p1)

	p2 = player_scene.instantiate()
	p2.name = "Player2"
	p2.player_id = 1
	players_node.add_child(p2)

	# Cameras (Top Level so they can follow ghosts during replay)
	cam1 = Camera2D.new()
	cam1.name = "Camera1"
	cam1.custom_viewport = vp1
	players_node.add_child(cam1)

	cam2 = Camera2D.new()
	cam2.name = "Camera2"
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
		# L'hôte simule les deux joueurs : il garde l'autorité sur P1 ET P2, et
		# ne fait que consommer les inputs du client pour P2.
		p1.set_multiplayer_authority(1)
		p2.set_multiplayer_authority(1)

		_set_player_input_provider(p1, LocalInputProvider.new(), 0)
		_set_player_input_provider(p2, NetworkInputProvider.new(), 1)

		var peers = multiplayer.get_peers()
		client_peer_id = peers[0] if peers.size() > 0 else 0

	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		# Tout est répliqué depuis l'hôte ; le provider local de P2 ne sert plus
		# qu'à échantillonner les commandes envoyées via rpc_send_inputs.
		p1.set_multiplayer_authority(1)
		p2.set_multiplayer_authority(1)
		client_peer_id = 0

		_set_player_input_provider(p1, NetworkInputProvider.new(), 0)
		_set_player_input_provider(p2, LocalInputProvider.new(), 0)

func _setup_ghosts():
	var unshaded_mat = ShaderMaterial.new()
	unshaded_mat.shader = SHADER_GHOST
	
	ghost_p1 = Node2D.new()
	ghost_p1.name = "GhostP1"
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
	ghost_p2.name = "GhostP2"
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



## Réserve de particules. Placée hors de l'arène et hors du conteneur de
## balles : ces deux nœuds sont purgés à chaque manche et au retour au menu.
func _setup_particle_pool() -> void:
	particle_pool = ParticlePool.new()
	particle_pool.name = "ParticlePool"
	arena.get_parent().add_child(particle_pool)

func _setup_training_target() -> void:
	training_target = TrainingTarget.new()
	training_target.name = "TrainingTarget"
	arena.get_parent().add_child(training_target)
	training_target.hide()
	training_target.process_mode = Node.PROCESS_MODE_DISABLED

## Affiche ou masque la cible d'échauffement. Elle n'existe qu'en bac à sable —
## en manche, elle bloquerait les balles.
func _set_training_target_active(active: bool) -> void:
	if not is_instance_valid(training_target): return
	training_target.visible = active
	training_target.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	training_target.set_collision_layer_value(1, active)
	training_target.reset_damage()
	if active:
		training_target.global_position = _training_target_position()

## Place la cible sur du sol libre devant l'apparition de J1. Chercher une case
## valide plutôt que d'appliquer un décalage fixe : sur une carte custom, le
## décalage tomberait dans un mur ou dans une fosse.
func _training_target_position() -> Vector2:
	var origin := _get_spawn_position(0)
	var floor_layer := arena.get_node_or_null("CustomFloor") as TileMapLayer
	var walls_layer := arena.get_node_or_null("CustomWalls") as TileMapLayer
	if floor_layer == null or walls_layer == null:
		return origin + Vector2(160, 0)

	for radius in [4, 3, 5, 6, 2]:
		for i in 12:
			var ang := (i / 12.0) * TAU
			var offset := Vector2(cos(ang), sin(ang)) * float(radius) * float(CandelaTileSet.TILE_SIZE.x)
			var cell := floor_layer.local_to_map(floor_layer.to_local(origin + offset))
			if floor_layer.get_cell_source_id(cell) == -1: continue
			if walls_layer.get_cell_source_id(cell) != -1: continue
			return floor_layer.to_global(floor_layer.map_to_local(cell))

	return origin + Vector2(140, 0)

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
			ui.time_label.text = MatchRecord.format_clock(round_time)
			_set_training_target_active(true)
			ui.show_waiting_for_opponent()
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
	# Toute séquence de fin encore en vol doit lâcher la main ici.
	_round_token += 1
	_end_sequence_active = false
	_pending_client_start = false
	_pending_p2_weapon_idx = -1
	_abort_killcam()
	ui.force_close_pause()

	# Reconstruit l'arène à chaque manche : c'est ce qui rend effectif un
	# changement de carte depuis le menu, sans redémarrer le jeu.
	rebuild_arena()
	sandbox_mode = false
	# Un vrai match en ligne commence ici, et ici seulement : l'hôte resté seul
	# n'atteint jamais ce point, il repart en bac à sable plus haut. À partir de
	# maintenant, partir coûte le match.
	_forfeit_pending = NetworkManager.current_mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_set_training_target_active(false)
	if is_instance_valid(particle_pool):
		particle_pool.clear_all()
	p2.show()
	p2.set_collision_layer_value(1, true)
	p2.set_collision_mask_value(1, true)
	ui.waiting_label.hide()
	ui.hide_game_over()
	local_ready_for_rematch = false
	ui.btn_replay.text = "REJOUER"
	ui.btn_replay.remove_theme_color_override("font_color")
	game_over = false
	_restore_viewports()
	ui.hide_killcam()
	AudioManager.set_in_match(true)
	AudioManager.reset_low_health()
	AudioManager.play_music("music_match")

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
	# Départ figé des deux côtés : le décompte absorbe le trajet de rpc_start_round.
	countdown_left = COUNTDOWN_DURATION
	ui.set_countdown(countdown_left)
	_time_sync_accum = 0.0
	_predicted_shots.clear()
	_pos_history.clear()
	ghost_p1.hide()
	ghost_p2.hide()
	for c in bullet_container.get_children():
		c.queue_free()
	ReplaySystem.start_recording()
	
	ui.game_over_score.text = "SESSION : %d - %d" % [p1_session_wins, p2_session_wins]

func _process(delta):
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		_record_position_history()

	if round_active:
		if countdown_left > 0.0:
			countdown_left = maxf(0.0, countdown_left - delta)
			ui.set_countdown(countdown_left)
			if countdown_left <= 0.0:
				AudioManager.play_speaker("spk_fight")
				# Le décompte du client a démarré un demi aller-retour plus tard :
				# on recale son chronomètre dès le départ plutôt que d'attendre
				# le prochain envoi périodique.
				if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
					rpc_sync_time.rpc(time_left)
		else:
			time_left -= delta
			if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
				_time_sync_accum += delta
				if _time_sync_accum >= TIME_SYNC_INTERVAL:
					_time_sync_accum = 0.0
					rpc_sync_time.rpc(time_left)
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
		ReplaySystem.record_frame(p1, p2, bullet_container, delta)
			
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
			ghost_p1.get_node("Light").energy = KILLCAM_TORCH_ENERGY
			ghost_p1.get_node("Flash").enabled = current_snap.p1_flash > 0.0
			ghost_p1.get_node("Flash").energy = current_snap.p1_flash
			if current_snap.p1_weapon:
				ghost_p1.get_node("Light").texture = current_snap.p1_weapon.get_torch_texture()
				ghost_p1.get_node("Light").texture_scale = current_snap.p1_weapon.torch_scale
			
			ghost_p2.global_position = current_snap.p2_pos
			ghost_p2.rotation = current_snap.p2_rot
			ghost_p2.visible = current_snap.p2_visible
			ghost_p2.get_node("Light").enabled = current_snap.p2_light
			ghost_p2.get_node("Light").energy = KILLCAM_TORCH_ENERGY
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
	# Le rayon suit la lumière, pas le déplacement : il ne teste donc que les
	# murs et les joueurs (couche 1). Une fosse laisse passer le faisceau, on
	# peut éblouir son adversaire par-dessus un gouffre.
	var light_mask := MapGeometry.WALL_LAYER

	if p1.flashlight_on:
		var p1_to_p2 = p1.global_position.direction_to(p2.global_position)
		if p1.global_transform.x.dot(p1_to_p2) > 0.866:
			var q = PhysicsRayQueryParameters2D.create(
				p1.global_position, p2.global_position, light_mask)
			q.exclude = [p1.get_rid()]
			var res = space.intersect_ray(q)
			if res and res.collider == p2:
				p2.apply_dazzle(0.5 * delta)

	if p2.flashlight_on:
		var p2_to_p1 = p2.global_position.direction_to(p1.global_position)
		if p2.global_transform.x.dot(p2_to_p1) > 0.866:
			var q = PhysicsRayQueryParameters2D.create(
				p2.global_position, p1.global_position, light_mask)
			q.exclude = [p2.get_rid()]
			var res = space.intersect_ray(q)
			if res and res.collider == p1:
				p1.apply_dazzle(0.5 * delta)

func _get_weapon_idx(w: WeaponData) -> int:
	if w == weapon_arbalete: return 3
	if w == weapon_pompe: return 2
	if w == weapon_fusil: return 1
	return 0

@rpc("authority", "call_local", "reliable")
func rpc_spawn_bullet(shooter_id: int, pos: Vector2, rot: float, weapon_idx: int):
	var shooter = p1 if shooter_id == 0 else p2
	var weapon = weapon_arbalete if weapon_idx == 3 else (weapon_pompe if weapon_idx == 2 else (weapon_fusil if weapon_idx == 1 else weapon_pistolet))
	# Tir déjà rendu par la prédiction locale : seul l'enregistrement killcam
	# reste à faire, sur la trajectoire arbitrée par l'hôte.
	var already_shown := shooter_id == 1 and _consume_predicted_shot()
	_do_spawn_bullet(shooter, pos, rot, weapon, not already_shown)

func spawn_bullet(shooter: Node2D, pos: Vector2, rot: float, weapon: WeaponData):
	if not round_active and not sandbox_mode: return

	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		# Le client rend son propre tir sans attendre l'hôte, qui reste seul
		# juge des dégâts et de la cadence réelle.
		if shooter == p2:
			_predicted_shots.append(Time.get_ticks_msec())
			_do_spawn_bullet(shooter, pos, rot, weapon, true, false)
		return

	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		var w_idx = _get_weapon_idx(weapon)
		rpc_spawn_bullet.rpc(shooter.player_id, pos, rot, w_idx)
	else:
		_do_spawn_bullet(shooter, pos, rot, weapon)

## `spawn_nodes` à faux : la balle a déjà été rendue par la prédiction client,
## on ne garde que l'enregistrement. `record` à faux : balle prédite, elle sera
## enregistrée quand le tir officiel arrivera.
func _do_spawn_bullet(shooter: Node2D, pos: Vector2, rot: float, weapon: WeaponData,
		spawn_nodes: bool = true, record: bool = true):
	if not round_active and not sandbox_mode: return
	var count = weapon.projectile_count if weapon else 1
	var angles = weapon.spread_angles_deg if weapon else [0.0]

	# Les tirs du client sont arbitrés sur ce qu'il voyait : son adversaire est
	# testé à sa position d'alors. Calculé une fois pour toute la volée, le vol
	# d'une balle durant quelques dizaines de millisecondes.
	var lag_center := Vector2.ZERO
	var lag_compensated := spawn_nodes \
		and NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST \
		and shooter == p2
	if lag_compensated:
		lag_center = _rewound_position(p1, _lag_comp_delay())

	for i in range(count):
		var ang_offset = deg_to_rad(angles[i]) if i < angles.size() else 0.0
		var final_rot = rot + ang_offset

		if spawn_nodes:
			var b = bullet_scene.instantiate()
			b.global_position = pos
			b.rotation = final_rot
			b.direction = Vector2(cos(final_rot), sin(final_rot))
			b.source_player = shooter
			if weapon:
				b.weapon = weapon
			if lag_compensated:
				b.lag_target = p1
				b.lag_center = lag_center
			bullet_container.add_child(b)

		if record and ReplaySystem.recording:
			ReplaySystem.record_bullet_fired(shooter.player_id, pos, final_rot, weapon)

	if not spawn_nodes: return

	if shooter == p1:
		cam1_shake_time = 0.1
	elif shooter == p2:
		cam2_shake_time = 0.1

	if shooter.has_method("trigger_shoot_visuals"):
		shooter.trigger_shoot_visuals()

## [Client] Un tir officiel correspond-il à une balle déjà prédite ? Les
## prédictions non confirmées (paquet d'input perdu, tir refusé par l'hôte)
## expirent d'elles-mêmes pour ne pas décaler la file.
func _consume_predicted_shot() -> bool:
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT: return false
	var now := Time.get_ticks_msec()
	while not _predicted_shots.is_empty() and now - _predicted_shots[0] > PREDICTED_SHOT_TTL_MS:
		_predicted_shots.remove_at(0)
	if _predicted_shots.is_empty(): return false
	_predicted_shots.remove_at(0)
	return true

## [Hôte] Archive la position des deux joueurs pour la compensation de latence.
func _record_position_history() -> void:
	if not is_instance_valid(p1) or not is_instance_valid(p2): return
	var now := Time.get_ticks_msec() / 1000.0
	_pos_history.append({"t": now, "p1": p1.global_position, "p2": p2.global_position})
	while _pos_history.size() > 1 and now - _pos_history[0]["t"] > POS_HISTORY_WINDOW:
		_pos_history.remove_at(0)

## [Hôte] Position d'un joueur telle qu'elle était il y a `back` secondes.
func _rewound_position(player: Player, back: float) -> Vector2:
	if _pos_history.is_empty(): return player.global_position
	var key := "p1" if player == p1 else "p2"
	var t := Time.get_ticks_msec() / 1000.0 - back
	if t >= float(_pos_history[-1]["t"]): return player.global_position
	if t <= float(_pos_history[0]["t"]): return _pos_history[0][key]
	for i in range(_pos_history.size() - 1):
		var a: Dictionary = _pos_history[i]
		var b: Dictionary = _pos_history[i + 1]
		if t <= float(b["t"]):
			var span: float = float(b["t"]) - float(a["t"])
			var w: float = 0.0 if span <= 0.0001 else (t - float(a["t"])) / span
			return (a[key] as Vector2).lerp(b[key], w)
	return player.global_position

## Recul appliqué aux tirs du client : ce qu'il voyait était en retard d'un
## demi aller-retour, plus le retard d'interpolation de son adversaire.
func _lag_comp_delay() -> float:
	return clampf(NetworkManager.rtt_ms / 2000.0 + Player.INTERP_DELAY, 0.0, LAG_COMP_MAX)

## L'hôte est la seule horloge de manche : sans recalage les deux chronomètres
## dérivent (hoquets de rendu, pause) et la manche ne finit pas ensemble.
@rpc("authority", "call_remote", "reliable")
func rpc_sync_time(value: float) -> void:
	time_left = value

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
	# Une seconde fin arrivée pendant la première (mort simultanée, RPC en
	# double) recompterait le kill et relancerait la killcam.
	if _end_sequence_active: return
	_round_token += 1
	var token := _round_token
	_end_sequence_active = true

	# Manches gagnées dans le match en cours. En BO1 une seule suffit, mais le
	# décompte passe par le format : un BO3 n'aurait rien à changer ici.
	if winner_id == 0:
		p1_round_wins += 1
	elif winner_id == 1:
		p2_round_wins += 1

	var match_over := winner_id == -1 \
		or MatchRecord.is_match_over(MATCH_FORMAT, p1_round_wins, p2_round_wins)
	if match_over:
		# Le score cumulé est un score de SESSION (série de matchs), pas un score
		# de manches : il ne bouge qu'à la fin d'un match.
		if winner_id == 0:
			p1_session_wins += 1
		elif winner_id == 1:
			p2_session_wins += 1
		_archive_match_result(winner_id)
		p1_round_wins = 0
		p2_round_wins = 0

	round_active = false
	countdown_left = 0.0
	ui.set_countdown(0.0)
	# Le menu pause ne gèle plus rien en ligne : il resterait affiché par-dessus
	# la killcam, y compris sur une égalité.
	ui.force_close_pause()
	_predicted_shots.clear()
	AudioManager.set_in_match(false)
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
		if token != _round_token: return

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
			if token != _round_token: return

		# Le ralenti est global : quelle que soit la façon dont la lecture s'est
		# arrêtée, la vitesse normale doit être rétablie ici.
		Engine.time_scale = 1.0

		# Hide killcam UI but KEEP the freeze frame
		ui.hide_killcam()

		# Attendre 2 secondes supplémentaires sur l'arrêt sur image avant d'afficher le menu de fin
		await get_tree().create_timer(2.0).timeout
		if token != _round_token: return

		# DO NOT restore split screen or reset cameras here!
		# It freezes the screen perfectly on the death frame behind the menu.

	_end_sequence_active = false
	game_over = true
	# show_game_over remet le bouton sur « REJOUER » : l'état suit le libellé.
	local_ready_for_rematch = false
	ui.show_game_over(winner_id)
	ui.game_over_score.text = "SESSION : %d - %d" % [p1_session_wins, p2_session_wins]
	_apply_deferred_rematch()

## Archive le résultat du match dans user://. Fondation de l'envoi ELO à venir :
## chaque machine journalise le match qu'elle vient de jouer, y compris le
## client — il n'y a aucun échange réseau ici.
func _archive_match_result(winner_id: int, forfeit: bool = false) -> void:
	# Le match est résolu : plus rien à forfaire dessus.
	_forfeit_pending = false
	var record := MatchRecord.build(
		winner_id,
		round_time - time_left,
		p1.current_weapon.name if p1 and p1.current_weapon else "",
		p2.current_weapon.name if p2 and p2.current_weapon else "",
		MapData.selected_map_id,
		_mode_label(),
		MATCH_FORMAT,
		forfeit)
	MatchRecord.append_to_history(record)

## Archive un match gagné par abandon de l'adversaire.
##
## Le jeton `_forfeit_pending` est ce qui rend l'opération sûre : abandonner
## emprunte plusieurs chemins de retour au menu, qui se croisent — signal du
## transport, dialogue de déconnexion, bouton MENU PRINCIPAL — et sans lui le
## même match serait archivé deux ou trois fois.
##
## À appeler AVANT `NetworkManager.disconnect_from_game()` : celui-ci remet le
## mode en local, et l'enregistrement ne saurait plus dire s'il vient d'un hôte
## ou d'un client.
func _archive_forfeit(winner_id: int) -> void:
	if not _forfeit_pending:
		return
	_archive_match_result(winner_id, true)

## Indice du joueur incarné par CETTE machine, -1 hors ligne.
func _local_player_index() -> int:
	match NetworkManager.current_mode:
		NetworkManager.GameMode.ONLINE_HOST: return 0
		NetworkManager.GameMode.ONLINE_CLIENT: return 1
		_: return -1

func _mode_label() -> String:
	match NetworkManager.current_mode:
		NetworkManager.GameMode.ONLINE_HOST: return "en_ligne_hote"
		NetworkManager.GameMode.ONLINE_CLIENT: return "en_ligne_client"
		_: return "local"

## Sortie inconditionnelle de la killcam. Le ralenti est un réglage global du
## moteur : l'oublier sur un chemin de sortie laisse tout le jeu à 3 % de sa
## vitesse, menus compris.
func _abort_killcam() -> void:
	ReplaySystem.playing_back = false
	Engine.time_scale = 1.0
	ui.hide_killcam()

## [Hôte] Rejoue ce qui a été reçu pendant la séquence de fin, une fois l'écran
## de fin affiché et l'état redevenu stable.
func _apply_deferred_rematch() -> void:
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST: return
	if _pending_p2_weapon_idx >= 0:
		_set_p2_weapon_button(_pending_p2_weapon_idx)
		_pending_p2_weapon_idx = -1
	if _pending_client_start:
		_pending_client_start = false
		if client_peer_id != 0:
			rpc_start_round.rpc(_hosted_weapon_1_idx, _local_p2_weapon_idx(), _host_map_code())
			return
	if p2_ready_for_rematch:
		_check_rematch_start()

## [Hôte] Arme choisie par le client, envoyée dès la connexion établie. C'est
## ce paquet, et non `peer_connected`, qui déclenche la première manche : il est
## le seul moment où l'hôte connaît le choix de P2.
@rpc("any_peer", "reliable")
func rpc_client_weapon(idx: int):
	if NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_HOST: return
	if client_peer_id == 0 or multiplayer.get_remote_sender_id() != client_peer_id: return
	# Le client n'émet ce paquet qu'à la connexion : le recevoir pendant une
	# manche (ou son décompte) ne peut être qu'une ré-émission illégitime —
	# l'accepter réinitialiserait le duel en cours.
	if round_active or countdown_left > 0.0: return
	_set_p2_weapon_button(idx)
	# Reçu en pleine killcam : on retient le choix, _apply_deferred_rematch
	# lancera la manche une fois l'écran de fin stable.
	if _end_sequence_active:
		_pending_p2_weapon_idx = idx
		_pending_client_start = true
		return
	rpc_start_round.rpc(_hosted_weapon_1_idx, idx, _host_map_code())

## Index de l'arme choisie par le joueur local pour P2 (client, ou écran partagé).
func _local_p2_weapon_idx() -> int:
	var pressed: BaseButton = ui.p2_weapon_group.get_pressed_button()
	return pressed.get_index() if pressed else 0

## Un index hors bornes ferait tomber l'hôte sur un paquet client malformé.
func _set_p2_weapon_button(idx: int) -> void:
	var buttons: Array = ui.p2_weapon_group.get_buttons()
	if idx < 0 or idx >= buttons.size(): return
	buttons[idx].button_pressed = true

func _on_replay_requested():
	if ui._is_main_menu:
		# Le mode lancé est celui qu'affiche le menu. Tester directement
		# « CRÉER SALON » ne suffit pas : ce bouton appartient à un autre groupe
		# que « 1V1 LOCAL / EN LIGNE » et reste coché après une partie en ligne,
		# si bien qu'un 1v1 local relançait un salon.
		var mode: NetworkManager.GameMode = ui.selected_network_mode()
		if mode == NetworkManager.GameMode.ONLINE_HOST:
			# Un hébergement refusé (Epic injoignable, port déjà pris) a déjà
			# ramené au menu : enchaîner sur la manche lancerait une partie
			# solo par-dessus l'écran d'erreur.
			if not NetworkManager.host_game():
				return
			_apply_network_mode()
			game_over = false
			ui.hide_game_over()
			_restore_viewports()
			_start_round()
		elif mode == NetworkManager.GameMode.ONLINE_CLIENT:
			if not NetworkManager.join_game(ui.lobby_join_text()):
				return
			ui.btn_replay.text = "Connexion au salon…"

			# L'échéance doit être neutralisée dès que l'issue est connue :
			# sinon elle renvoie au menu une partie déjà commencée.
			_join_deadline_active = true
			var timer = get_tree().create_timer(NetworkManager.join_timeout())
			timer.timeout.connect(func():
				if not _join_deadline_active:
					return
				_join_deadline_active = false
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
		if local_ready_for_rematch:
			local_ready_for_rematch = false
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

		local_ready_for_rematch = true
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
	if client_peer_id == 0 or multiplayer.get_remote_sender_id() != client_peer_id: return
	p2_ready_for_rematch = true
	# Le client a fini sa killcam avant l'hôte : on retient son intention, on
	# n'écrit ni son arme ni le libellé du chrono au milieu du ralenti.
	if _end_sequence_active:
		_pending_p2_weapon_idx = w2_idx
		return
	_set_p2_weapon_button(w2_idx)
	_check_rematch_start()

func _check_rematch_start():
	# Un départ pendant la séquence de fin couperait la killcam de l'hôte.
	if _end_sequence_active: return
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
	# Départ volontaire en plein match : c'est un abandon, et il se paie. Le
	# vainqueur est l'adversaire — celui qui reste. Archivé AVANT la déconnexion,
	# qui repasse le mode en local et rendrait l'enregistrement muet sur son
	# origine. Si un signal du transport est déjà passé par là, le jeton a été
	# consommé et cet appel ne fait rien.
	var local_idx := _local_player_index()
	if local_idx >= 0:
		_archive_forfeit(1 - local_idx)

	NetworkManager.disconnect_from_game()

	client_peer_id = 0
	_join_deadline_active = false
	countdown_left = 0.0
	ui.set_countdown(0.0)
	# Retour au menu depuis une killcam : sans ça le menu tourne au ralenti et
	# une séquence de fin en vol reviendrait afficher un écran de victoire.
	_round_token += 1
	_end_sequence_active = false
	_pending_client_start = false
	_pending_p2_weapon_idx = -1
	_abort_killcam()
	ui.force_close_pause()
	_predicted_shots.clear()
	_pos_history.clear()
	round_active = false
	sandbox_mode = false
	game_over = true
	p1_ready_for_rematch = false
	p2_ready_for_rematch = false
	local_ready_for_rematch = false
	
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
		
	# Le score de session ne survit pas au retour au menu : une nouvelle série
	# repart de 0 - 0.
	p1_session_wins = 0
	p2_session_wins = 0
	p1_round_wins = 0
	p2_round_wins = 0
	_set_training_target_active(false)
	if is_instance_valid(particle_pool):
		particle_pool.clear_all()

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
	# Quitter le jeu en plein match est un abandon comme un autre : il se paie.
	var local_idx := _local_player_index()
	if local_idx >= 0:
		_archive_forfeit(1 - local_idx)

	# quit() ne prend effet qu'en fin de frame : sortir depuis une killcam
	# étirerait ces dernières frames au ralenti.
	Engine.time_scale = 1.0
	# Passe par NetworkManager : la plateforme EOS doit être relâchée avant que
	# l'arbre se termine, sous peine de segfault à la fermeture.
	NetworkManager.quit_game()

## [Client Uniquement] Appelé quand l'hôte ferme le serveur ou plante.
func _on_host_disconnected():
	# L'hôte est parti en cours de match : le client encaisse la victoire.
	_archive_forfeit(1)
	ui.show_dialog_message("Déconnexion", "L'hôte a fermé la partie. Retour au menu principal.")
	_on_main_menu_requested()

## [Client Uniquement] Intercepte un échec de connexion (timeout ou serveur plein).
func _on_connection_failed():
	_join_deadline_active = false
	# Le transport sait pourquoi ça a échoué (code introuvable, Epic injoignable,
	# adresse morte) ; ce message générique ne sert que s'il n'a rien dit.
	var reason: String = NetworkManager.last_error
	if reason.is_empty():
		reason = "Impossible de rejoindre le salon (adresse injoignable ou salon complet)."
	ui.show_dialog_message("Erreur", reason)
	_on_main_menu_requested()

## [Client Uniquement] Appelé quand la connexion au serveur réussit.
func _on_connection_success():
	_join_deadline_active = false
	# Lu avant que l'écran de fin ne se referme, tant que le panneau du lobby
	# reflète encore le choix du joueur.
	var w2_idx := _local_p2_weapon_idx()
	_apply_network_mode()
	game_over = false
	ui.hide_game_over()
	_restore_viewports()
	_start_round()
	# L'hôte attend ce paquet pour lancer la manche avec la bonne arme.
	rpc_id(1, "rpc_client_weapon", w2_idx)

@rpc("any_peer", "reliable")
func rpc_client_unready():
	if client_peer_id == 0 or multiplayer.get_remote_sender_id() != client_peer_id: return
	p2_ready_for_rematch = false
	_pending_p2_weapon_idx = -1
	if not _end_sequence_active:
		ui.time_label.text = "EN ATTENTE D'UN ADVERSAIRE..."
