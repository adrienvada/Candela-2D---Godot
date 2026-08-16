extends Node
## Préférences persistées du joueur : vsync, plafond d'images par seconde,
## résolution, volumes audio et remappage des touches.
##
## Norme du jeu compétitif : vsync désactivé, aucun plafond par défaut — voir
## la décision « Images par seconde déplafonnées » dans docs/ROADMAP.md.
##
## Cet autoload est déclaré APRÈS InputSetup dans project.godot, et c'est ce qui
## rend le remappage persistant possible : les liaisons enregistrées s'appliquent
## par-dessus les liaisons par défaut, jamais l'inverse.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_VIDEO := "video"
const SECTION_DISPLAY := "display"
const SECTION_INPUT := "input"
const SECTION_AUDIO := "audio"

## 0 = déplafonné.
const FPS_CAPS: Array[int] = [0, 60, 120, 144, 240]

## Les trois modes proposés par le menu : fenêtré 1280, fenêtré 1920, plein
## écran.
const RESOLUTION_COUNT := 3

## Noms exacts des bus de `default_bus_layout.tres`, tels qu'`audio_manager.gd`
## les adresse. Toute divergence se traduit par un index -1, traité comme une
## absence et non comme une erreur : voir `_apply_bus_volume()`.
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_SPEAKER := "Speaker"

## Les volumes sont mémorisés en **amplitude linéaire** (0 = muet, 1 = le niveau
## nominal du bus tel qu'il est mixé dans `default_bus_layout.tres`). C'est ce
## que doit exposer un curseur : brancher un curseur droit sur des décibels
## rend le réglage inutilisable, tout le changement perçu se tassant dans les
## derniers pourcents de la course. La conversion se fait à l'application.
const VOLUME_MIN := 0.0
const VOLUME_MAX := 1.0
const VOLUME_DEFAULT := 1.0

## `linear_to_db(0)` vaut moins l'infini, valeur qu'`AudioServer` ne doit jamais
## recevoir : elle contamine le mixage au lieu de le taire. En dessous du seuil,
## on coupe franchement (mute) et on plafonne les décibels à ce plancher.
const SILENCE_DB := -80.0
## Équivalent linéaire de SILENCE_DB : plus personne n'entend rien en dessous.
const SILENCE_LINEAR := 0.0001

var vsync_enabled := false
var fps_cap := 0
var resolution_index := 0

var master_volume := VOLUME_DEFAULT
var music_volume := VOLUME_DEFAULT
var sfx_volume := VOLUME_DEFAULT
var speaker_volume := VOLUME_DEFAULT

## action -> description sérialisable de l'événement de manette assigné.
var _bindings: Dictionary = {}

## Une résolution n'est appliquée au démarrage que si elle a été choisie une
## fois : sans ça, une installation neuve verrait sa fenêtre recentrée d'office.
var _has_saved_resolution := false

## Variable, et non constante, pour une seule raison : les tests headless
## partagent le `user://` du jeu installé. Sans ce point de dérivation, la
## moindre suite qui appelle un `set_*` réécrirait les préférences réelles
## d'un joueur avec les valeurs par défaut du test.
var _settings_path := SETTINGS_PATH

func _ready() -> void:
	_load()
	_apply_video()
	if _has_saved_resolution:
		_apply_resolution()
	# Les bus existent dès le chargement de la disposition audio, bien avant les
	# autoloads : aucune dépendance à l'ordre de démarrage d'AudioManager ici.
	_apply_audio()
	_apply_bindings()

# ---------------------------------------------------------------------------
# API publique
# ---------------------------------------------------------------------------

func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	_apply_video()
	_save()

func set_fps_cap(cap: int) -> void:
	fps_cap = cap if FPS_CAPS.has(cap) else 0
	_apply_video()
	_save()

func set_resolution(index: int) -> void:
	resolution_index = index if index >= 0 and index < RESOLUTION_COUNT else 0
	_has_saved_resolution = true
	_apply_resolution()
	_save()

## Volume général (bus Master). Attendu entre 0 et 1 ; toute valeur hors bornes
## est écrêtée plutôt que refusée, un curseur mal calibré ne doit pas pouvoir
## fabriquer un niveau que le mixage ne sait pas rendre.
func set_master_volume(linear: float) -> void:
	master_volume = clamp_volume(linear)
	_apply_bus_volume(BUS_MASTER, master_volume)
	_save()

func set_music_volume(linear: float) -> void:
	music_volume = clamp_volume(linear)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	_save()

func set_sfx_volume(linear: float) -> void:
	sfx_volume = clamp_volume(linear)
	_apply_bus_volume(BUS_SFX, sfx_volume)
	_save()

## Voix de l'annonceur (bus Speaker), séparée des effets : elle porte de
## l'information de match, on doit pouvoir la garder audible sans le reste.
func set_speaker_volume(linear: float) -> void:
	speaker_volume = clamp_volume(linear)
	_apply_bus_volume(BUS_SPEAKER, speaker_volume)
	_save()

static func clamp_volume(linear: float) -> float:
	return clampf(linear, VOLUME_MIN, VOLUME_MAX)

## Conversion à destination d'AudioServer. Le zéro n'est pas converti : il rend
## le plancher, jamais moins l'infini.
static func volume_to_db(linear: float) -> float:
	var v := clamp_volume(linear)
	if v <= SILENCE_LINEAR:
		return SILENCE_DB
	return linear_to_db(v)

## Réciproque de `volume_to_db()`, exacte aux deux extrémités : le plancher
## redonne un silence franc et non un résidu inaudible mais non nul.
static func db_to_volume(db: float) -> float:
	if db <= SILENCE_DB:
		return VOLUME_MIN
	return clamp_volume(db_to_linear(db))

## Confort pour les curseurs gradués de 0 à 100 : l'échelle affichée reste
## linéaire, seule la conversion en décibels ne l'est pas.
static func volume_to_percent(linear: float) -> int:
	return int(round(clamp_volume(linear) * 100.0))

static func percent_to_volume(percent: int) -> float:
	return clamp_volume(float(percent) / 100.0)

## Enregistre la liaison choisie pour une action. L'événement a déjà été posé
## dans l'InputMap par l'appelant ; on ne fait que le retenir pour le prochain
## lancement.
func set_binding(action: String, event: InputEvent) -> void:
	var desc := _event_to_dict(event)
	if desc.is_empty():
		return
	_bindings[action] = desc
	_save()

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------

func _apply_video() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = fps_cap

func _apply_audio() -> void:
	_apply_bus_volume(BUS_MASTER, master_volume)
	_apply_bus_volume(BUS_MUSIC, music_volume)
	_apply_bus_volume(BUS_SFX, sfx_volume)
	_apply_bus_volume(BUS_SPEAKER, speaker_volume)

## Un bus renommé ou une disposition audio remplacée rend un index -1. Le cas se
## traverse en silence : un réglage de confort n'a aucune raison d'empêcher le
## jeu de démarrer, et les autres bus doivent quand même recevoir leur niveau.
static func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var v := clamp_volume(linear)
	# Le mute double le plancher en décibels : à zéro le joueur veut un silence
	# franc, pas un -80 dB qu'un casque poussé laisserait encore deviner.
	AudioServer.set_bus_mute(idx, v <= SILENCE_LINEAR)
	AudioServer.set_bus_volume_db(idx, volume_to_db(v))

func _apply_resolution() -> void:
	match resolution_index:
		0: _apply_windowed(Vector2i(1280, 720))
		1: _apply_windowed(Vector2i(1920, 1080))
		2:
			# N'active le plein écran que sur le jeu final exporté : en débogage
			# il masquerait l'éditeur et la console.
			if not OS.is_debug_build():
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _apply_windowed(size: Vector2i) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	var screen_size := DisplayServer.screen_get_size()
	if screen_size.x > 0 and screen_size.y > 0:
		DisplayServer.window_set_position((screen_size - size) / 2)

func _apply_bindings() -> void:
	for action in _bindings:
		var name := String(action)
		if not InputMap.has_action(name):
			continue
		_erase_joypad_events(name)
		var event := _event_from_dict(_bindings[action])
		if event != null:
			InputMap.action_add_event(name, event)

## Ne retire que les événements de manette : le clavier et la souris définis
## dans project.godot doivent survivre au remappage, sinon rebinder une action
## à la manette la rendrait injouable au clavier.
func _erase_joypad_events(action: String) -> void:
	for ev in InputMap.action_get_events(action):
		var is_trigger := ev is InputEventJoypadMotion \
			and ((ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_LEFT
				or (ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT)
		if ev is InputEventJoypadButton or is_trigger:
			InputMap.action_erase_event(action, ev)

# ---------------------------------------------------------------------------
# Sérialisation des liaisons
# ---------------------------------------------------------------------------

## Seuls les deux types produits par le remappage sont représentés : bouton de
## manette et gâchette analogique.
static func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventJoypadButton:
		var btn := event as InputEventJoypadButton
		return {"type": "button", "code": btn.button_index, "device": btn.device}
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return {
			"type": "axis", "code": motion.axis,
			"value": motion.axis_value, "device": motion.device,
		}
	return {}

## Un fichier de préférences trafiqué ou issu d'une version antérieure ne doit
## pas empêcher le jeu de démarrer : une description illisible est ignorée.
static func _event_from_dict(desc: Variant) -> InputEvent:
	if not desc is Dictionary:
		return null
	var d: Dictionary = desc
	match String(d.get("type", "")):
		"button":
			var btn := InputEventJoypadButton.new()
			btn.button_index = int(d.get("code", 0))
			btn.device = int(d.get("device", 0))
			return btn
		"axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(d.get("code", 0))
			motion.axis_value = float(d.get("value", 1.0))
			motion.device = int(d.get("device", 0))
			return motion
	return null

# ---------------------------------------------------------------------------
# Persistance
# ---------------------------------------------------------------------------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_settings_path) != OK:
		return

	vsync_enabled = cfg.get_value(SECTION_VIDEO, "vsync_enabled", false)
	var loaded_cap: int = cfg.get_value(SECTION_VIDEO, "fps_cap", 0)
	fps_cap = loaded_cap if FPS_CAPS.has(loaded_cap) else 0

	master_volume = _sanitize_volume(cfg.get_value(SECTION_AUDIO, "master", VOLUME_DEFAULT))
	music_volume = _sanitize_volume(cfg.get_value(SECTION_AUDIO, "music", VOLUME_DEFAULT))
	sfx_volume = _sanitize_volume(cfg.get_value(SECTION_AUDIO, "sfx", VOLUME_DEFAULT))
	speaker_volume = _sanitize_volume(cfg.get_value(SECTION_AUDIO, "speaker", VOLUME_DEFAULT))

	if cfg.has_section_key(SECTION_DISPLAY, "resolution_index"):
		var idx: int = cfg.get_value(SECTION_DISPLAY, "resolution_index", 0)
		resolution_index = idx if idx >= 0 and idx < RESOLUTION_COUNT else 0
		_has_saved_resolution = true

	if cfg.has_section(SECTION_INPUT):
		for action in cfg.get_section_keys(SECTION_INPUT):
			var desc: Variant = cfg.get_value(SECTION_INPUT, action, {})
			if desc is Dictionary and not (desc as Dictionary).is_empty():
				_bindings[action] = desc

## Un fichier trafiqué ou écrit par une version antérieure ne doit pas empêcher
## le jeu de démarrer : une valeur illisible retombe sur le niveau nominal.
static func _sanitize_volume(value: Variant) -> float:
	if not (value is float or value is int):
		return VOLUME_DEFAULT
	return clamp_volume(float(value))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_VIDEO, "vsync_enabled", vsync_enabled)
	cfg.set_value(SECTION_VIDEO, "fps_cap", fps_cap)
	if _has_saved_resolution:
		cfg.set_value(SECTION_DISPLAY, "resolution_index", resolution_index)
	cfg.set_value(SECTION_AUDIO, "master", master_volume)
	cfg.set_value(SECTION_AUDIO, "music", music_volume)
	cfg.set_value(SECTION_AUDIO, "sfx", sfx_volume)
	cfg.set_value(SECTION_AUDIO, "speaker", speaker_volume)
	for action in _bindings:
		cfg.set_value(SECTION_INPUT, String(action), _bindings[action])
	cfg.save(_settings_path)
