## Test headless du shader de trames, hachures & sérigraphie (Étape 2)
##
## Valide :
## 1. La compilation et le chargement de menu_hatch.gdshader.
## 2. L'instanciation de MenuHatchRect et l'injection de ses paramètres GPU.
## 3. Les différents modes de motif (Single, Cross, Halftone, Rotring).
## 4. L'usine de widgets MenuWidgets (make_hatch_rect, make_hatch_panel, make_hatch_modal).
##
## Lancer : godot --headless --path . --script res://tools/test_hatch_shader.gd
extends SceneTree

const Charte := preload("res://charte.gd")
const MenuHatchRect := preload("res://menu_hatch_rect.gd")
const MenuWidgets := preload("res://menu_widgets.gd")

var _failures: int = 0

func _init() -> void:
	print("=== Test du shader de trames & hachures (Étape 2) ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_test_shader_load()
	_test_hatch_rect_instantiation()
	_test_pattern_modes()
	_test_alert_mode()
	_test_menu_widgets_integration()

	if _failures == 0:
		print("\n✓ Tous les tests de trames et hachures passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _test_shader_load() -> void:
	print("\n[1. Chargement du Shader]")
	var sh: Shader = load("res://menu_hatch.gdshader") as Shader
	_check("menu_hatch.gdshader existe et se charge", sh != null)

func _test_hatch_rect_instantiation() -> void:
	print("\n[2. Instanciation de MenuHatchRect]")
	var rect := MenuHatchRect.new()
	root.add_child(rect)
	rect.size = Vector2(200, 150)
	
	_check("le matériau est bien un ShaderMaterial", rect.material is ShaderMaterial)
	var sm := rect.get_shader_material()
	_check("get_shader_material() renvoie le matériau", sm != null)
	
	rect.spacing = 16.0
	_check("paramètre spacing mis à jour", is_equal_approx(sm.get_shader_parameter("spacing"), 16.0))
	
	rect.density = 0.7
	_check("paramètre density mis à jour", is_equal_approx(sm.get_shader_parameter("density"), 0.7))
	
	root.remove_child(rect)
	rect.free()

func _test_pattern_modes() -> void:
	print("\n[3. Modes de motif]")
	var rect := MenuHatchRect.new()
	root.add_child(rect)
	
	rect.apply_preset_inactive()
	_check("preset inactive applique le mode CROSS", rect.pattern_mode == MenuHatchRect.PatternMode.CROSS)
	
	rect.apply_preset_halftone()
	_check("preset halftone applique le mode HALFTONE", rect.pattern_mode == MenuHatchRect.PatternMode.HALFTONE)
	
	rect.apply_preset_rotring_panel()
	_check("preset rotring applique border_width", rect.border_width > 0.0)
	
	root.remove_child(rect)
	rect.free()

func _test_alert_mode() -> void:
	print("\n[4. Mode alerte dynamique]")
	var rect := MenuHatchRect.new()
	root.add_child(rect)
	
	rect.set_alert(true, Charte.ROUGE, 3.0)
	_check("set_alert(true) active alert_pulse", rect.alert_pulse > 0.0)
	_check("set_alert(true) configure la vitesse", rect.speed > 0.0)
	
	rect.set_alert(false)
	_check("set_alert(false) éteint alert_pulse", is_zero_approx(rect.alert_pulse))
	
	root.remove_child(rect)
	rect.free()

func _test_menu_widgets_integration() -> void:
	print("\n[5. Intégration MenuWidgets]")
	var panel := MenuWidgets.make_hatch_panel()
	root.add_child(panel)
	_check("make_hatch_panel renvoie un PanelContainer", panel != null)
	
	var found_hatch := false
	for child in panel.get_children():
		if child is MenuHatchRect:
			found_hatch = true
			break
	_check("le panneau contient bien un MenuHatchRect en enfant", found_hatch)
	
	var modal := MenuWidgets.make_hatch_modal()
	root.add_child(modal)
	_check("make_hatch_modal renvoie un PanelContainer", modal != null)
	
	root.remove_child(panel)
	panel.free()
	root.remove_child(modal)
	modal.free()
