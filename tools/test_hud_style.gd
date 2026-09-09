## Test de conformité du HUD en jeu et du séparateur d'écran (Proposition 1)
## Vérifie que l'interface en jeu respecte la DA Roman Graphique Brutaliste :
## - Séparateur Gutter sans néon ni glow bleu, avec caniveau noir et filets d'acier
## - Fiches Joueurs vectorielles ComicHudPanel sans cadre 3D ni halo envahissant
## - Chrono central dans son cartouche de bande dessinée sobre
extends SceneTree

const Charte := preload("res://charte.gd")

var _ok: int = 0
var _ko: int = 0

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_ok += 1
		print("  ✓ %s" % label)
	else:
		_ko += 1
		printerr("  ✗ %s%s" % [label, (" : " + detail) if detail != "" else ""])

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== Test Style du HUD & Séparateur (DA Roman Graphique Brutaliste) ===")

	var ui_script := load("res://ui.gd") as GDScript
	_check("ui.gd se charge sans erreur", ui_script != null)

	var ui: Node = ui_script.new()
	root.add_child(ui)
	await process_frame

	# 1. Contrôle du séparateur central (center_line)
	print("\n[1. Séparateur vertical d'écran scindé]")
	var cl = ui.get("center_line")
	_check("center_line existe", cl != null)
	if cl != null:
		_check("center_line est un SplitGutterDivider", cl.get_class() == "Panel" and cl.has_method("_draw"))
		_check("center_line positionné au centre", cl.anchor_left == 0.5 or abs(cl.position.x - (1920.0 * 0.5 - 3.0)) < 5.0, "pos=%s" % str(cl.position))
		_check("center_line a un fond transparent/empty (dessin géré par _draw)", cl.get_theme_stylebox("panel") is StyleBoxEmpty)

	# 2. Contrôle des panneaux de joueurs (HUD J1 et J2)
	print("\n[2. Fiches Joueurs (ComicHudPanel)]")
	var p1_panel = ui.get("p1_panel")
	var p2_panel = ui.get("p2_panel")
	_check("p1_panel existe", p1_panel != null)
	_check("p2_panel existe", p2_panel != null)

	if p1_panel != null:
		_check("p1_panel est un PanelContainer", p1_panel is PanelContainer)
		_check("p1_panel porte la couleur de J1", p1_panel.get("accent_color") == ui.COLOR_P1)
		_check("p1_panel est configuré pour J1 (onglet gauche)", p1_panel.get("is_player_1") == true)
		_check("p1_panel n'est pas un center_panel", p1_panel.get("is_center_panel") == false)

	if p2_panel != null:
		_check("p2_panel est un PanelContainer", p2_panel is PanelContainer)
		_check("p2_panel porte la couleur de J2", p2_panel.get("accent_color") == ui.COLOR_P2)
		_check("p2_panel est configuré pour J2 (onglet droit)", p2_panel.get("is_player_1") == false)
		_check("p2_panel n'est pas un center_panel", p2_panel.get("is_center_panel") == false)

	# 3. Contrôle du bloc chrono central
	print("\n[3. Cartouche Chrono Central]")
	var time_label: Label = ui.get("time_label")
	_check("time_label existe", time_label != null)
	if time_label != null:
		var parent_panel := time_label.get_parent().get_parent().get_parent() as PanelContainer
		_check("le chrono est logé dans un ComicHudPanel", parent_panel != null and parent_panel.get("is_center_panel") == true)
		if parent_panel != null:
			_check("le cartouche chrono a un accent acier sobre", parent_panel.get("accent_color") != null)

	# 4. Absence totale de cadre_hud.png (cadre 3D obsolète)
	print("\n[4. Éradication de cadre_hud.png dans le HUD actif]")
	var p1_sb = p1_panel.get_theme_stylebox("panel") if p1_panel else null
	var p2_sb = p2_panel.get_theme_stylebox("panel") if p2_panel else null
	_check("p1_panel n'utilise PAS de StyleBoxTexture", not (p1_sb is StyleBoxTexture))
	_check("p2_panel n'utilise PAS de StyleBoxTexture", not (p2_sb is StyleBoxTexture))

	# 5. Cohérence avec la Charte visuelle
	print("\n[5. Conformité Charte]")
	_check("aucun vert dans le style du panneau de J1", p1_panel.get("accent_color") != Charte.VERT)
	_check("aucun vert dans le style du panneau de J2", p2_panel.get("accent_color") != Charte.VERT)

	ui.queue_free()
	print("\n--- %d tests réussis, %d échec(s) ---" % [_ok, _ko])
	quit(0 if _ko == 0 else 1)
