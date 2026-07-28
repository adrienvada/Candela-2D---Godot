extends Node

# Cartographie des clés de sons vers leurs chemin d'accès


const SOUNDS: Dictionary = {
	"shoot": "res://assets/audio/sfx/weapon_shoot.wav",
	"footstep": "res://assets/audio/sfx/footstep.wav",
	"wall_impact": "res://assets/audio/sfx/wall_impact.wav",
	"flesh_impact": "res://assets/audio/sfx/flesh_impact.wav",
	"button_click": "res://assets/audio/sfx/button_click.wav",
	"heartbeat": "res://assets/audio/sfx/heartbeat.wav",
	"music_menu": "res://assets/audio/music/music_menu.ogg",
	"music_match": "res://assets/audio/music/music_match.ogg",
	"music_victory": "res://assets/audio/music/music_victory.ogg",
	"spk_fight": "res://assets/audio/speaker/spk_fight.wav",
	"spk_p1_wins": "res://assets/audio/speaker/spk_p1_wins.wav",
	"spk_p2_wins": "res://assets/audio/speaker/spk_p2_wins.wav",
	"spk_draw": "res://assets/audio/speaker/spk_draw.wav"
}

const SFX_POOL_SIZE: int = 16

var sfx_players: Array[AudioStreamPlayer] = []
var sfx_players_2d: Array[AudioStreamPlayer2D] = []
var sfx_index: int = 0
var sfx_2d_index: int = 0

var music_player_a: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var active_music_player: AudioStreamPlayer
var current_music_key: String = ""
var music_tween: Tween

var speaker_player: AudioStreamPlayer
var heartbeat_player: AudioStreamPlayer
var heartbeat_tween: Tween
var low_health_players: Dictionary = {}

var _stream_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Initialisation du pool d'AudioStreamPlayer (globaux)
	for i in range(SFX_POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
		
	# Initialisation du pool d'AudioStreamPlayer2D (positionnels)
	for i in range(SFX_POOL_SIZE):
		var p2d = AudioStreamPlayer2D.new()
		p2d.bus = "SFX"
		p2d.max_distance = 2000.0
		add_child(p2d)
		sfx_players_2d.append(p2d)
		
	# Lecteurs musique pour le fondu enchaîné (crossfade)
	music_player_a = AudioStreamPlayer.new()
	music_player_a.bus = "Music"
	add_child(music_player_a)
	
	music_player_b = AudioStreamPlayer.new()
	music_player_b.bus = "Music"
	add_child(music_player_b)
	active_music_player = music_player_a
	
	# Lecteur speaker
	speaker_player = AudioStreamPlayer.new()
	speaker_player.bus = "Speaker"
	add_child(speaker_player)
	
	# Lecteur battement de cœur (santé basse)
	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.bus = "SFX"
	add_child(heartbeat_player)
	heartbeat_player.finished.connect(_on_heartbeat_finished)

# --- RECHERCHE ET CHARGEMENT SECURISE DE SONS ---
func get_audio_stream(stream_or_key: Variant) -> AudioStream:
	if stream_or_key is AudioStream:
		return stream_or_key
	if not stream_or_key is String:
		return null
		
	var key_str: String = stream_or_key
	var path: String = SOUNDS.get(key_str, key_str)
	
	if _stream_cache.has(path):
		return _stream_cache[path]
		
	if not ResourceLoader.exists(path):
		# Tente avec l'autre extension courante (.wav / .ogg)
		var alt_path: String = ""
		if path.ends_with(".ogg"):
			alt_path = path.left(-4) + ".wav"
		elif path.ends_with(".wav"):
			alt_path = path.left(-4) + ".ogg"
			
		if alt_path != "" and ResourceLoader.exists(alt_path):
			path = alt_path
		else:
			# Fichier non trouvé : ne crashe pas, évite l'erreur
			return null
			
	var stream = load(path) as AudioStream
	if stream:
		_stream_cache[path] = stream
	return stream

# --- JOUER DES SFX GLOBAUX ---
func play_sfx(stream_or_key: Variant, pitch_scale: float = 1.0, volume_db: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer:
	var stream = get_audio_stream(stream_or_key)
	if not stream:
		return null
		
	var player = sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % SFX_POOL_SIZE
	
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.bus = bus_name
	player.play()
	return player

func play_sfx_random_pitch(stream_or_key: Variant, min_pitch: float = 0.92, max_pitch: float = 1.08, volume_db: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer:
	var pitch = randf_range(min_pitch, max_pitch)
	return play_sfx(stream_or_key, pitch, volume_db, bus_name)

# --- JOUER DES SFX 2D POSITIONNELS ---
func play_sfx_2d(stream_or_key: Variant, pos: Vector2, pitch_scale: float = 1.0, volume_db: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer2D:
	var stream = get_audio_stream(stream_or_key)
	if not stream:
		return null
		
	var player = sfx_players_2d[sfx_2d_index]
	sfx_2d_index = (sfx_2d_index + 1) % SFX_POOL_SIZE
	
	player.global_position = pos
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db
	player.bus = bus_name
	player.play()
	return player

func play_sfx_2d_random_pitch(stream_or_key: Variant, pos: Vector2, min_pitch: float = 0.92, max_pitch: float = 1.08, volume_db: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer2D:
	var pitch = randf_range(min_pitch, max_pitch)
	return play_sfx_2d(stream_or_key, pos, pitch, volume_db, bus_name)

# --- GESTION MUSIQUE DYNAMIQUE & CROSSFADE ---
func play_music(stream_or_key: Variant, crossfade_duration: float = 1.0, volume_db: float = 0.0) -> void:
	var key_name = str(stream_or_key)
	if current_music_key == key_name and active_music_player and active_music_player.playing:
		return
		
	current_music_key = key_name
	var stream = get_audio_stream(stream_or_key)
	
	var incoming: AudioStreamPlayer = music_player_b if active_music_player == music_player_a else music_player_a
	var outgoing: AudioStreamPlayer = active_music_player
	active_music_player = incoming
	
	if music_tween and music_tween.is_valid():
		music_tween.kill()
		
	var has_incoming: bool = (stream != null)
	var has_outgoing: bool = (outgoing != null and outgoing.playing)
	
	if not has_incoming and not has_outgoing:
		current_music_key = ""
		return
		
	music_tween = create_tween().set_parallel(true)
	
	if has_incoming:
		incoming.stream = stream
		incoming.volume_db = -80.0
		incoming.play()
		music_tween.tween_property(incoming, "volume_db", volume_db, crossfade_duration)
	else:
		current_music_key = ""
		
	if has_outgoing:
		music_tween.tween_property(outgoing, "volume_db", -80.0, crossfade_duration)
		music_tween.chain().tween_callback(outgoing.stop)


# --- CONTROLE DU FILTRE PASS-BAS SUR LA MUSIQUE ---
func set_music_lowpass(enabled: bool) -> void:
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1 and AudioServer.get_bus_effect_count(bus_idx) > 0:
		AudioServer.set_bus_effect_enabled(bus_idx, 0, enabled)

# --- VOIX SPEAKER & UI ---
func play_speaker(stream_or_key: Variant, volume_db: float = 0.0) -> void:
	var stream = get_audio_stream(stream_or_key)
	if not stream:
		return
		
	if speaker_player.playing:
		speaker_player.stop()
		
	speaker_player.stream = stream
	speaker_player.volume_db = volume_db
	speaker_player.play()

func play_button_click(volume_db: float = 0.0) -> void:
	play_sfx("button_click", 1.0, volume_db)

# --- ETAT SANTE BASSE ---
func update_low_health(player_id: int, is_low: bool) -> void:
	low_health_players[player_id] = is_low
	_eval_low_health_state()

func reset_low_health() -> void:
	low_health_players.clear()
	_eval_low_health_state()

func _eval_low_health_state() -> void:
	var any_low: bool = false
	for pid in low_health_players:
		if low_health_players[pid]:
			any_low = true
			break
			
	if any_low:
		set_music_lowpass(true)
		var stream = get_audio_stream("heartbeat")
		if stream and not heartbeat_player.playing:
			heartbeat_player.stream = stream
			heartbeat_player.volume_db = 0.0
			heartbeat_player.play()
	else:
		set_music_lowpass(false)
		if heartbeat_player.playing:
			if heartbeat_tween and heartbeat_tween.is_valid():
				heartbeat_tween.kill()
			heartbeat_tween = create_tween()
			heartbeat_tween.tween_property(heartbeat_player, "volume_db", -80.0, 0.5)
			heartbeat_tween.tween_callback(heartbeat_player.stop)

func _on_heartbeat_finished() -> void:
	var any_low: bool = false
	for pid in low_health_players:
		if low_health_players[pid]:
			any_low = true
			break
			
	if any_low and heartbeat_player.stream:
		heartbeat_player.volume_db = 0.0
		heartbeat_player.play()
