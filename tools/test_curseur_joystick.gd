## Test de la navigation manette : D-Pad case par case et Joystick curseur virtuel
##
## Vérifie :
## 1. La navigation discrète case par case au D-Pad (flèches) sans curseur virtuel.
## 2. L'apparition et le déplacement fluide du curseur virtuel lors de l'utilisation du joystick.
## 3. La détection de survol des boutons par le curseur virtuel.
## 4. La disparition immédiate du curseur virtuel dès qu'on reprend la navigation aux flèches / au D-Pad.
## 5. L'activation des boutons sous le curseur.

extends SceneTree

var _ok := 0
var _ko := 0
var _ui: Node


func _check(condition: bool, quoi: String) -> void:
	if condition:
		_ok += 1
	else:
		_ko += 1
		printerr("  ✗ %s" % quoi)


func _test_dpad_navigation_case_par_case() -> void:
	_ui.call("show_main_menu")
	await process_frame
	await process_frame

	var curseur_virtuel: Control = _ui.get("_joystick_cursor")
	_check(curseur_virtuel != null, "le curseur virtuel de joystick n'est pas instancié")
	_check(not bool(_ui.get("_joystick_cursor_active")), "le curseur joystick est actif au démarrage du menu")
	_check(curseur_virtuel != null and not curseur_virtuel.visible, "le curseur virtuel est visible au repos")

	var focus_initial: Control = _ui.get("p1_focus")
	_check(focus_initial != null, "aucun focus initial J1 au menu")

	# Simulation d'un appui D-pad BAS
	var ev := InputEventAction.new()
	ev.action = "p1_menu_down"
	ev.pressed = true
	_ui.call("_input", ev)
	await process_frame

	var focus_apres: Control = _ui.get("p1_focus")
	_check(focus_apres != null and focus_apres != focus_initial,
		"l'appui D-pad BAS n'a pas déplacé le focus case par case")
	_check(not bool(_ui.get("_joystick_cursor_active")),
		"le D-pad a activé le curseur virtuel par erreur")
	_check(curseur_virtuel != null and not curseur_virtuel.visible,
		"le curseur virtuel est devenu visible suite à une navigation D-pad")


func _test_joystick_apparition_et_survol() -> void:
	_ui.call("show_main_menu")
	await process_frame
	await process_frame

	var curseur_virtuel: Control = _ui.get("_joystick_cursor")

	# Activation manuelle / simulation de stick dans _update_joystick_cursor
	_ui.set("_joystick_cursor_active", true)
	if curseur_virtuel != null:
		curseur_virtuel.visible = true

	var candidates: Array = _ui.call("_nav_candidates", 0)
	_check(candidates.size() >= 2, "pas assez de candidats de navigation pour tester le survol")
	if candidates.size() < 2:
		return

	var cible: Control = candidates[1] as Control
	var centre_cible: Vector2 = cible.get_global_rect().get_center()

	_ui.set("_joystick_cursor_pos", centre_cible)
	if curseur_virtuel != null:
		curseur_virtuel.call("aim", centre_cible)

	_ui.call("_actualiser_survol_curseur_joystick", centre_cible)
	await process_frame

	var focus_actuel: Control = _ui.get("p1_focus")
	_check(focus_actuel == cible, "le survol du curseur virtuel n'a pas mis à jour le focus sur l'élément visé")


func _test_bascule_vers_dpad_fait_disparaitre_curseur() -> void:
	_ui.call("show_main_menu")
	await process_frame
	await process_frame

	var curseur_virtuel: Control = _ui.get("_joystick_cursor")
	_ui.set("_joystick_cursor_active", true)
	if curseur_virtuel != null:
		curseur_virtuel.visible = true

	_check(bool(_ui.get("_joystick_cursor_active")), "le curseur virtuel n'est pas actif avant bascule")
	_check(curseur_virtuel != null and curseur_virtuel.visible, "le curseur virtuel n'est pas visible avant bascule")

	# Le joueur presse une flèche D-Pad HAUT
	var ev := InputEventAction.new()
	ev.action = "p1_menu_up"
	ev.pressed = true
	_ui.call("_input", ev)
	await process_frame

	_check(not bool(_ui.get("_joystick_cursor_active")),
		"le curseur virtuel est resté actif après un appui D-pad")
	_check(curseur_virtuel != null and not curseur_virtuel.visible,
		"le curseur virtuel est resté visible après un appui D-pad")


func _test_activation_au_clic_joystick() -> void:
	_ui.call("show_main_menu")
	await process_frame
	await process_frame

	var candidates: Array = _ui.call("_nav_candidates", 0)
	_check(not candidates.is_empty(), "aucun candidat de navigation pour tester l'activation")
	if candidates.is_empty():
		return

	var btn: BaseButton = candidates[0] as BaseButton
	_check(btn != null, "le premier candidat n'est pas un bouton")
	if btn == null:
		return

	var active := [false]
	btn.pressed.connect(func() -> void:
		active[0] = true
	)

	_ui.set("_joystick_cursor_active", true)
	_ui.call("_set_focus", 0, btn)

	var ev := InputEventAction.new()
	ev.action = "p1_menu_select"
	ev.pressed = true
	_ui.call("_input", ev)
	await process_frame

	_check(active[0], "p1_menu_select n'a pas déclenché le bouton visé par le curseur")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Navigation manette : D-Pad et Joystick ===")
	await process_frame
	var scene: PackedScene = load("res://ui.tscn")
	if scene == null:
		printerr("✗ ui.tscn introuvable")
		quit(1)
		return

	_ui = scene.instantiate()
	_ui.name = "UI"
	root.add_child(_ui)
	await process_frame
	await process_frame

	await _test_dpad_navigation_case_par_case()
	await _test_joystick_apparition_et_survol()
	await _test_bascule_vers_dpad_fait_disparaitre_curseur()
	await _test_activation_au_clic_joystick()

	print("--- %d contrôles, %d échec(s) ---" % [_ok + _ko, _ko])
	root.remove_child(_ui)
	_ui.free()
	quit(1 if _ko > 0 else 0)
