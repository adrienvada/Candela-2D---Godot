extends Node
## Préférences persistées du joueur (vsync, plafond d'images par seconde).
## Norme du jeu compétitif : vsync désactivé, aucun plafond par défaut — voir
## la décision « Images par seconde déplafonnées » dans docs/ROADMAP.md.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "video"

## 0 = déplafonné.
const FPS_CAPS: Array[int] = [0, 60, 120, 144, 240]

var vsync_enabled := false
var fps_cap := 0

func _ready() -> void:
	_load()
	_apply()

func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	_apply()
	_save()

func set_fps_cap(cap: int) -> void:
	fps_cap = cap if FPS_CAPS.has(cap) else 0
	_apply()
	_save()

func _apply() -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = fps_cap

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	vsync_enabled = cfg.get_value(SECTION, "vsync_enabled", false)
	var loaded_cap: int = cfg.get_value(SECTION, "fps_cap", 0)
	fps_cap = loaded_cap if FPS_CAPS.has(loaded_cap) else 0

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "vsync_enabled", vsync_enabled)
	cfg.set_value(SECTION, "fps_cap", fps_cap)
	cfg.save(SETTINGS_PATH)
