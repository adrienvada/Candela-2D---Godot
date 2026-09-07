extends SceneTree

const MenuArtwork := preload("res://menu_artwork.gd")
const MenuHub := preload("res://menu_hub.gd")

## Suite de tests pour les artworks de menu, les POI, les embrasements et les effets vivants.

var _failures: int = 0

func _init() -> void:
	print("=== TestMenuArtworks ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_test_pois()
	_test_effects()
	_test_flame_colors()
	_test_shader_load()
	await _test_hub_artworks()
	
	if _failures == 0:
		print("✓ Tous les tests d'artworks passent")
	else:
		printerr("✗ %d échec(s) dans TestMenuArtworks" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, (" — " + detail) if detail != "" else "")

func _test_pois() -> void:
	for cle: String in MenuArtwork.POIS.keys():
		var poi: Vector2 = MenuArtwork.poi_pour(cle)
		_check("POI dans [0, 1] : " + cle, poi.x >= 0.0 and poi.x <= 1.0 and poi.y >= 0.0 and poi.y <= 1.0, str(poi))

func _test_effects() -> void:
	for cle: String in MenuArtwork.EFFECTS.keys():
		var effet: int = MenuArtwork.effet_pour(cle)
		_check("Effet valide [0, 13] : " + cle, effet >= 0 and effet <= 13, str(effet))

func _test_flame_colors() -> void:
	for cle: String in MenuArtwork.POIS.keys():
		var col: Color = MenuArtwork.couleur_flamme_pour(cle)
		_check("Couleur flamme valide : " + cle, col.r > 0.0 and col.a > 0.0, str(col))

func _test_shader_load() -> void:
	var shader := load("res://menu_artwork.gdshader") as Shader
	_check("menu_artwork.gdshader charge", shader != null)
	if shader != null:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("effect_mode", 1)
		mat.set_shader_parameter("reveal_progress", 0.5)
		mat.set_shader_parameter("poi_pos", Vector2(0.66, 0.72))
		mat.set_shader_parameter("ambient_exposure", 0.28)
		_check("Parametres du shader appliques", true)

func _test_hub_artworks() -> void:
	var hub := MenuHub.new()
	_check("MenuHub s'instancie", hub != null)
	if hub != null:
		root.add_child(hub)
		hub.add_screen(MenuHub.ROOT, "Candela 2D")
		hub.reset()
		await process_frame
		hub.show_panel("ill_accueil")
		hub.show_panel("ill_competitif")
		hub.show_panel("ill_entrainement")
		hub.set_torch_position_global(Vector2(400, 300))
		hub._process(0.016)
		_check("MenuHub process et show_panel sans crash", true)
		root.remove_child(hub)
		hub.free()
		await process_frame
