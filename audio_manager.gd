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
	"spk_draw": "res://assets/audio/speaker/spk_draw.wav",
	# Déjà attendu par le manifeste (V3.2) : `play_sfx` rend null sur une
	# ressource absente, la clé se câble donc avant le fichier et reste muette
	# sans erreur — plutôt qu'un bouche-trou qu'on finirait par prendre pour une
	# intention.
	"ui_ready_ping": "res://assets/audio/sfx/ui_ready_ping.wav"
}

## Le tempo du jeu, en un seul endroit.
##
## Les stems, le pouls haptique et la vignette battante battent tous à 170 —
## mais chacun le réécrivait chez lui (`player.gd` porte encore ses propres 170
## et 85). Un tempo recopié est un tempo qui dérive : le jour où il change, ce
## qui bat encore à l'ancien ne se signale pas, il se contente d'être à côté.
const BPM: float = 170.0
const PERIODE_BEAT: float = 60.0 / BPM

const SFX_POOL_SIZE: int = 16

## V4.16 — priorité d'un son dans le pool. Plus haut, mieux protégé.
##
## Le pool tournait en **anneau** : le dix-septième son écrasait le premier, quel
## qu'il soit. Or les pas sont de loin la source la plus bavarde — un toutes les
## ~0,3 s et par joueur, donc six à sept par seconde à deux. Dans une fusillade,
## où s'ajoutent les tirs et les impacts de mur, ce sont eux qui reviennent le
## plus souvent voler une voix. Ils pouvaient couper net le claquement de chair
## d'un coup au but : **le son qui ne raconte rien coupait le son qui raconte.**
##
## Le classement suit ce que le son APPREND au joueur, pas son volume. Toucher
## quelqu'un est l'information la plus chère du jeu — c'est la seule confirmation
## qu'on obtient dans le noir. Un pas n'apprend qu'une présence, déjà donnée par
## le suivant.
const SFX_PRIORITE: Dictionary = {
	"footstep": 0,
	"wall_impact": 1,
	"button_click": 1,
	"ui_ready_ping": 1,
	"shoot": 2,
	"flesh_impact": 3,
}
## Un son inconnu du barème — ou joué depuis un flux et non depuis une clé — se
## place au-dessus des pas et en dessous du récit. Le défaut ne doit privilégier
## personne, mais il ne doit pas non plus laisser un son anonyme couper un kill.
const SFX_PRIORITE_DEFAUT: int = 2

## V4.15 — les pas s'effacent sous le coup de feu.
##
## Un tir sature déjà l'attention ; les pas qui continuent dessous ne s'entendent
## pas et volent des voix. Six décibels suffisent à les faire reculer sans les
## faire disparaître — on doit encore savoir que l'autre bouge.
const DUCK_TIR_DB: float = -6.0
const DUCK_TIR_S: float = 0.3

var sfx_players: Array[AudioStreamPlayer] = []
var sfx_players_2d: Array[AudioStreamPlayer2D] = []
## Dernière voix servie de chaque pool. Ce n'est plus un pointeur d'anneau depuis
## que l'attribution est arbitrée par priorité — la valeur n'est plus lue pour
## décider, seulement pour observer.
var sfx_index: int = 0
var sfx_2d_index: int = 0
## Priorité et instant de départ de chaque voix des deux pools, pour arbitrer un
## vol de voix. Dimensionnés dans `_ready()`, en même temps que les pools.
var _sfx_prio: PackedInt32Array = PackedInt32Array()
var _sfx_debut: PackedFloat64Array = PackedFloat64Array()
var _sfx_prio_2d: PackedInt32Array = PackedInt32Array()
var _sfx_debut_2d: PackedFloat64Array = PackedFloat64Array()
## Instant du dernier coup de feu, en secondes depuis le lancement.
var _dernier_tir: float = -1000.0

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
	_sfx_prio.resize(SFX_POOL_SIZE)
	_sfx_debut.resize(SFX_POOL_SIZE)
		
	# Pool d'AudioStreamPlayer2D pour SFX 2D positionnels
	for i in range(SFX_POOL_SIZE):
		var p2d := AudioStreamPlayer2D.new()
		p2d.bus = "SFX"
		p2d.max_distance = 2000.0
		add_child(p2d)
		sfx_players_2d.append(p2d)
	_sfx_prio_2d.resize(SFX_POOL_SIZE)
	_sfx_debut_2d.resize(SFX_POOL_SIZE)
		
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

## Choisit la voix qu'un nouveau son doit prendre, ou -1 s'il doit être renoncé.
##
## **Pure à dessein** : aucun nœud, aucune horloge, rien de l'état du serveur
## audio. C'est ce qui la rend vérifiable en headless, où le pilote audio est
## muet et où `AudioStreamPlayer.playing` ne dit pas la vérité — un arbitrage
## qu'on ne peut pas tester est un arbitrage dont on découvre les défauts à
## l'oreille, en match, une fois.
##
## Trois règles, dans cet ordre :
##
## 1. **Une voix libre d'abord**, toujours : ne voler que sous contrainte.
## 2. Sinon, prendre la **moins prioritaire** ; à égalité, la plus ancienne —
##    c'est le comportement d'anneau d'origine, mais confiné à une même classe.
## 3. **Ne jamais voler plus important que soi.** Si toutes les voix comptent
##    plus que le son entrant, il est renoncé. Un pas perdu ne s'entend pas ;
##    un coup au but coupé en deux, si.
static func choisir_voix(occupees: Array[bool], priorites: PackedInt32Array,
		debuts: PackedFloat64Array, priorite: int) -> int:
	var pire := -1
	var pire_prio := 0
	var pire_debut := 0.0
	for i in occupees.size():
		if not occupees[i]:
			return i
		var p: int = priorites[i] if i < priorites.size() else SFX_PRIORITE_DEFAUT
		var d: float = debuts[i] if i < debuts.size() else 0.0
		if pire < 0 or p < pire_prio or (p == pire_prio and d < pire_debut):
			pire = i
			pire_prio = p
			pire_debut = d
	if pire < 0 or pire_prio > priorite:
		return -1
	return pire

## La priorité d'un son, d'après sa clé. Un flux passé directement n'en a pas.
static func priorite_de(stream_or_key: Variant) -> int:
	if stream_or_key is String:
		return int(SFX_PRIORITE.get(stream_or_key, SFX_PRIORITE_DEFAUT))
	return SFX_PRIORITE_DEFAUT

func _occupations(pool: Array) -> Array[bool]:
	var occupees: Array[bool] = []
	for p in pool:
		occupees.append(bool((p as Node).get("playing")))
	return occupees

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
		
	var prio := priorite_de(stream_or_key)
	var voie := choisir_voix(_occupations(sfx_players), _sfx_prio, _sfx_debut, prio)
	if voie < 0:
		return null
	var maintenant := Time.get_ticks_msec() / 1000.0
	_sfx_prio[voie] = prio
	_sfx_debut[voie] = maintenant
	sfx_index = voie
	var player = sfx_players[voie]
	
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
		
	var maintenant := Time.get_ticks_msec() / 1000.0
	# V4.15 — un tir vient de partir : les pas reculent de six décibels. Le coup
	# de feu sature déjà l'attention, et les pas qui continuent dessous ne
	# s'entendent pas tout en volant des voix. On les efface, on ne les coupe pas :
	# savoir que l'autre bouge reste une information du jeu.
	var volume_final := volume_db
	if stream_or_key is String:
		if stream_or_key == "shoot":
			_dernier_tir = maintenant
		elif stream_or_key == "footstep" and maintenant - _dernier_tir < DUCK_TIR_S:
			volume_final += DUCK_TIR_DB
	
	var prio := priorite_de(stream_or_key)
	var voie := choisir_voix(_occupations(sfx_players_2d), _sfx_prio_2d, _sfx_debut_2d, prio)
	if voie < 0:
		return null
	_sfx_prio_2d[voie] = prio
	_sfx_debut_2d[voie] = maintenant
	sfx_2d_index = voie
	var player = sfx_players_2d[voie]
	
	player.global_position = pos
	player.stream = stream
	player.pitch_scale = final_pitch
	player.volume_db = volume_final
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
