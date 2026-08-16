extends Node

# Cartographie des sons vers leurs chemins d'accès
const SOUNDS: Dictionary = {
	"shoot": "res://assets/audio/sfx/weapon_shoot.wav",
	"footstep": "res://assets/audio/sfx/footstep.wav",
	"wall_impact": "res://assets/audio/sfx/wall_impact.wav",
	"flesh_impact": "res://assets/audio/sfx/flesh_impact.wav",
	"button_click": "res://assets/audio/sfx/button_click.wav",
	"music_menu": "res://assets/audio/music/music_menu.ogg",
	"music_match": "res://assets/audio/music/music_match.ogg",
	"music_victory": "res://assets/audio/music/music_victory.ogg",
	"music_interactive": "res://assets/audio/music/main_stream_interactive.tres",
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

# Lecteur musique unique (AudioStreamPlayer supportant nativement AudioStreamInteractive !)
var music_player: AudioStreamPlayer
var filter_tween: Tween

var speaker_player: AudioStreamPlayer
var heartbeat_tween: Tween

var low_health_players: Dictionary = {}
var player_torches: Dictionary = {}
var is_in_match: bool = false

var _stream_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Pool d'AudioStreamPlayer pour SFX globaux & UI
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)
		
	# Pool d'AudioStreamPlayer2D pour SFX 2D positionnels
	for i in range(SFX_POOL_SIZE):
		var p2d := AudioStreamPlayer2D.new()
		p2d.bus = "SFX"
		p2d.max_distance = 2000.0
		add_child(p2d)
		sfx_players_2d.append(p2d)
		
	# AudioStreamPlayer unique pour la musique
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	# Pré-chargement de la ressource interactive si présente
	var interactive_path := "res://assets/audio/music/main_stream_interactive.tres"
	if ResourceLoader.exists(interactive_path):
		var res = load(interactive_path)
		if res is AudioStreamInteractive:
			music_player.stream = res
			# Recherche du clip "match" (Logique Verticale)
			for i in range(res.clip_count):
				if res.get_clip_name(i) == "match":
					var clip_stream = res.get_clip_stream(i)
					if clip_stream is AudioStreamSynchronized:
						match_sync_stream = clip_stream
					break
		elif res is AudioStream:
			music_player.stream = res
			
	# Assurer la présence de l'effet LowPassFilter sur le bus Music
	_ensure_music_lowpass_effect()
	
	# AudioStreamPlayer pour l'annonceur / speaker
	speaker_player = AudioStreamPlayer.new()
	speaker_player.bus = "Speaker"
	add_child(speaker_player)

# --- SECURITE : GARANTIE DU FILTRE PASS-BAS SUR LE BUS MUSIC ---
func _ensure_music_lowpass_effect() -> AudioEffectFilter:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx == -1:
		return null
		
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var effect = AudioServer.get_bus_effect(bus_idx, i) as AudioEffectFilter
		if effect:
			AudioServer.set_bus_effect_enabled(bus_idx, i, true)
			return effect
			
	return null

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
		var alt_path: String = ""
		if path.ends_with(".ogg"):
			alt_path = path.left(-4) + ".wav"
		elif path.ends_with(".wav"):
			alt_path = path.left(-4) + ".ogg"
			
		if alt_path != "" and ResourceLoader.exists(alt_path):
			path = alt_path
		else:
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
		
	# --- BULLET TIME / KILLCAM AUDIO ---
	# Si la scène est au ralenti (Engine.time_scale < 1.0), tous les effets sonores
	# s'adaptent dynamiquement à l'échelle de temps de la scène (ralentis avec l'action).
	var final_pitch = pitch_scale
	if Engine.time_scale < 1.0:
		final_pitch *= clamp(Engine.time_scale, 0.05, 1.0)
		
	var player = sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % SFX_POOL_SIZE
	
	player.stream = stream
	player.pitch_scale = final_pitch
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
		
	# --- BULLET TIME / KILLCAM AUDIO ---
	# Si la scène est au ralenti (Engine.time_scale < 1.0), tous les effets sonores
	# s'adaptent dynamiquement à l'échelle de temps de la scène (ralentis avec l'action).
	var final_pitch = pitch_scale
	if Engine.time_scale < 1.0:
		final_pitch *= clamp(Engine.time_scale, 0.05, 1.0)
		
	var player = sfx_players_2d[sfx_2d_index]
	sfx_2d_index = (sfx_2d_index + 1) % SFX_POOL_SIZE
	
	player.global_position = pos
	player.stream = stream
	player.pitch_scale = final_pitch
	player.volume_db = volume_db
	player.bus = bus_name
	player.play()
	return player

func play_sfx_2d_random_pitch(stream_or_key: Variant, pos: Vector2, min_pitch: float = 0.92, max_pitch: float = 1.08, volume_db: float = 0.0, bus_name: String = "SFX") -> AudioStreamPlayer2D:
	var pitch = randf_range(min_pitch, max_pitch)
	return play_sfx_2d(stream_or_key, pos, pitch, volume_db, bus_name)

# --- MUSIQUE INTERACTIVE & AUDIOSTREAMPLAYER ---
func play_music(stream_or_key: Variant) -> void:
	var clip_name := str(stream_or_key)
	if clip_name.begins_with("music_"):
		clip_name = clip_name.trim_prefix("music_")
		
	# Si un AudioStreamInteractive est chargé sur le music_player
	if music_player.stream is AudioStreamInteractive:
		if not music_player.playing:
			music_player.play()
		var playback = music_player.get_stream_playback()
		if playback and playback is AudioStreamPlaybackInteractive:
			playback.switch_to_clip_by_name(clip_name)
			return

	# Fallback : Chargement d'un fichier audio direct
	var stream = get_audio_stream(stream_or_key)
	if not stream:
		return
		
	if music_player.stream == stream and music_player.playing:
		return

	music_player.stream = stream
	music_player.play()

func switch_music_clip(clip_name: String) -> void:
	if music_player.stream is AudioStreamInteractive:
		if not music_player.playing:
			music_player.play()
		var playback = music_player.get_stream_playback()
		if playback and playback is AudioStreamPlaybackInteractive:
			playback.switch_to_clip_by_name(clip_name)
			return
	play_music(clip_name)

# --- LOGIQUE VERTICALE (INTENSITE DE MATCH) ---
var match_sync_stream: AudioStreamSynchronized = null
var music_intensity_tweens: Dictionary = {}
## Niveau courant : permet à GameState d'appeler set_music_intensity chaque
## frame sans relancer les tweens — seul un vrai changement déclenche le fondu.
var music_intensity: int = 0

func set_music_intensity(level: int) -> void:
	# level 0 : Base uniquement (-60db sur le reste)
	# level 1 : Base + Batterie (Stems 0 et 1)
	# level 2 : Base + Batterie + Arpège (Stems 0, 1, et 2)
	if level == music_intensity:
		return
	music_intensity = level
	if not match_sync_stream:
		return
		
	var target_vols = [-60.0, -60.0, -60.0]
	
	if level >= 0:
		target_vols[0] = 0.0 # Base active
	if level >= 1:
		target_vols[1] = 0.0 # Drums actifs
	if level >= 2:
		target_vols[2] = 0.0 # Arpège actif
		
	for i in range(min(3, match_sync_stream.stream_count)):
		if music_intensity_tweens.has(i) and music_intensity_tweens[i].is_valid():
			music_intensity_tweens[i].kill()
			
		var t = create_tween()
		music_intensity_tweens[i] = t
		var current_vol = match_sync_stream.get_sync_stream_volume(i)
		t.tween_method(
			func(v: float): match_sync_stream.set_sync_stream_volume(i, v),
			current_vol, target_vols[i], 1.0
		)

# --- GESTION DU FILTRE PASS-BAS ADDITIF (LAMPES & MATCH) ---
func set_in_match(in_match: bool) -> void:
	is_in_match = in_match
	player_torches.clear()
	# Chaque match repart au calme : l'intensité gagnée ne survit pas à la manche.
	set_music_intensity(0)
	if is_in_match:
		update_torch_cutoff()
	else:
		set_music_cutoff(20000.0, 1)

func set_player_torch(player_id: int, is_on: bool) -> void:
	player_torches[player_id] = is_on
	if is_in_match:
		update_torch_cutoff()

func update_torch_cutoff() -> void:
	var active_count := 0
	for pid in player_torches:
		if player_torches[pid]:
			active_count += 1
			
	# Base à 300Hz en match. Chaque lampe allumée ajoute +150Hz en 0.05s !
	var target_cutoff := 300.0 + (float(active_count) * 150.0)
	set_music_cutoff(target_cutoff, 0.1)

func set_music_cutoff(cutoff_hz: float, duration: float = 0.1) -> void:
	var filter = _ensure_music_lowpass_effect()
	if not filter:
		return
		
	if filter_tween and filter_tween.is_valid():
		filter_tween.kill()
		
	filter_tween = create_tween()
	filter_tween.tween_property(filter, "cutoff_hz", cutoff_hz, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# --- SPEAKER & UI ---
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

# --- ETAT SANTE BASSE (STEM MUSICAL SYNCHRONISE) ---
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
			
	if not match_sync_stream or match_sync_stream.stream_count <= 3:
		return

	if heartbeat_tween and heartbeat_tween.is_valid():
		heartbeat_tween.kill()
		
	heartbeat_tween = create_tween()
	var target_vol := 0.0 if any_low else -60.0
	var current_vol := match_sync_stream.get_sync_stream_volume(3)
	heartbeat_tween.tween_method(
		func(v: float): match_sync_stream.set_sync_stream_volume(3, v),
		current_vol, target_vol, 0.5
	)
