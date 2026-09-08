## Test headless de la mise en scène narrative & découpage en cases dynamiques (Étape 4)
##
## Valide :
## 1. L'instanciation, le tracé et les états du MenuComicPanel.
## 2. Le « Comic Panel Reveal » (volet d'encre massicot, progression, interruption).
## 3. L'interaction dynamique avec la torche (ombre portée opposée au faisceau, biseau spéculaire).
## 4. L'intégration dans MenuHub (cases gauche/droite, réactivité, retours).
## 5. Le câblage des sonorités d'interface (presse, tampon, massicot, refus).
##
## Lancer : godot --headless --path . --script res://tools/test_comic_panel.gd
extends SceneTree

const Charte := preload("res://charte.gd")
const AM := preload("res://audio_manager.gd")
const MenuComicPanel := preload("res://menu_comic_panel.gd")

var _failures: int = 0
var _hub: MenuHub
var _comic: MenuComicPanel

func _init() -> void:
	print("=== Test Comic Panel Reveal & Scénographie Dynamique ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_test_comic_panel_bases()
	await _test_comic_panel_reveal()
	_test_interaction_torche()
	_test_hub_integration()
	_test_sound_triggers()

	if _failures == 0:
		print("\n✓ Tous les tests Comic Panel passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

# ---------------------------------------------------------------------------
# 1. BASES DU COMIC PANEL
# ---------------------------------------------------------------------------
func _test_comic_panel_bases() -> void:
	print("\n[1. Bases du Comic Panel]")
	var panel := MenuComicPanel.new()
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(400, 300)
	
	_check("mouse_filter est IGNORE pour ne jamais bloquer l'input",
		panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("reveal_progress commence à 1.0 au repos",
		is_equal_approx(panel._reveal_progress, 1.0))
	
	var style := StyleBoxFlat.new()
	panel.associer_stylebox(style)
	_check("l'ombre portée est activée sur le stylebox associé",
		style.shadow_size > 0 and style.shadow_color.a > 0.0)
	
	panel.queue_free()

# ---------------------------------------------------------------------------
# 2. COMIC PANEL REVEAL (TRANSITION EN CASE DE BD)
# ---------------------------------------------------------------------------
func _test_comic_panel_reveal() -> void:
	print("\n[2. Comic Panel Reveal — Volet d'encre & Massicot]")
	var panel := MenuComicPanel.new()
	root.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(400, 300)
	
	panel.reveler(1.0, 0.18)
	_check("la révélation réinitialise le progrès à 0.0",
		is_equal_approx(panel._reveal_progress, 0.0))
	_check("la direction positive est retenue",
		panel._reveal_direction > 0.0)
	
	# Interruption immédiate (cas d'un appui rapide manette/clavier)
	panel.arret_immediat()
	_check("arret_immediat rétablit instantanément le panneau à 1.0",
		is_equal_approx(panel._reveal_progress, 1.0))
	
	# Révélation en sens inverse (retour)
	panel.reveler(-1.0, 0.18)
	_check("la direction négative est retenue sur un retour",
		panel._reveal_direction < 0.0)
	panel.arret_immediat()
	
	panel.queue_free()

# ---------------------------------------------------------------------------
# 3. INTERACTION DYNAMIQUE DE LA TORCHE
# ---------------------------------------------------------------------------
func _test_interaction_torche() -> void:
	print("\n[3. Interaction Torche — Ombrage projeté & Liseré spéculaire]")
	var panel := MenuComicPanel.new()
	root.add_child(panel)
	panel.global_position = Vector2(200, 200)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(400, 300)
	var style := StyleBoxFlat.new()
	panel.associer_stylebox(style)
	
	# Torche placée en haut à gauche du panneau (ex: (50, 50))
	# Le centre du panneau est en (400, 350)
	# L'ombre doit être projetée vers le bas et la droite (vecteur positif en X et Y)
	panel.set_torch_position_global(Vector2(50, 50))
	
	_check("l'ombre projetée fuit le faisceau de la torche vers la droite",
		panel._shadow_offset.x > 0.0, str(panel._shadow_offset))
	_check("l'ombre projetée fuit le faisceau de la torche vers le bas",
		panel._shadow_offset.y > 0.0, str(panel._shadow_offset))
	_check("le stylebox reçoit l'offset d'ombre calculé",
		style.shadow_offset == panel._shadow_offset)
	
	# Le liseré gauche et haut fait face à la torche -> rim_intensity plus forte
	_check("l'arête gauche prend le faisceau en direct",
		panel._rim_intensities["left"] > panel._rim_intensities["right"],
		"gauche: %f, droite: %f" % [panel._rim_intensities["left"], panel._rim_intensities["right"]])
	_check("l'arête haute prend le faisceau en direct",
		panel._rim_intensities["top"] > panel._rim_intensities["bottom"],
		"haut: %f, bas: %f" % [panel._rim_intensities["top"], panel._rim_intensities["bottom"]])
	
	# Torche déplacée de l'autre côté (en bas à droite)
	panel.set_torch_position_global(Vector2(800, 700))
	_check("l'ombre s'inverse vers le haut-gauche",
		panel._shadow_offset.x < 0.0 and panel._shadow_offset.y < 0.0,
		str(panel._shadow_offset))
	_check("l'arête droite reçoit maintenant la lueur spéculaire",
		panel._rim_intensities["right"] > panel._rim_intensities["left"])
	
	panel.queue_free()

# ---------------------------------------------------------------------------
# 4. INTÉGRATION DANS MENUHUB
# ---------------------------------------------------------------------------
func _test_hub_integration() -> void:
	print("\n[4. Intégration dans MenuHub]")
	var hub := MenuHub.new()
	root.add_child(hub)
	hub.add_screen(MenuHub.ROOT, "Accueil")
	hub.add_screen("options", "Options")
	hub.reset()
	
	_check("le hub possède sa case de BD gauche",
		hub.left_comic() != null and hub.left_comic() is MenuComicPanel)
	_check("le hub possède sa case de BD droite",
		hub.right_comic() != null and hub.right_comic() is MenuComicPanel)
	
	# Navigation vers un écran
	hub.push("options")
	_check("l'écran options est actif",
		hub.current_id() == "options")
	
	# Retour
	hub.back()
	_check("le retour ramène à l'accueil",
		hub.current_id() == MenuHub.ROOT)
	
	# Retour à la racine (déclenche le refus)
	var refus_vu := [false]
	hub.back_at_root.connect(func() -> void: refus_vu[0] = true)
	_check("retour à la racine est refusé",
		not hub.back())
	_check("signal back_at_root émis", refus_vu[0])
	
	# Position torche relayée aux deux cases
	hub.set_torch_position_global(Vector2(100, 100))
	_check("la case gauche a reçu la torche",
		hub.left_comic()._has_torch)
	_check("la case droite a reçu la torche",
		hub.right_comic()._has_torch)
	
	hub.queue_free()

# ---------------------------------------------------------------------------
# 5. DÉCLENCHEURS SONORES ROMAN GRAPHIQUE BRUTALISTE
# ---------------------------------------------------------------------------
func _test_sound_triggers() -> void:
	print("\n[5. Sound Design — Presse, Tampon, Massicot, Refus]")
	_check("ui_presse est déclarée dans SOUNDS",
		AM.SOUNDS.has("ui_presse"))
	_check("ui_tampon est déclarée dans SOUNDS",
		AM.SOUNDS.has("ui_tampon"))
	_check("ui_massicot est déclarée dans SOUNDS",
		AM.SOUNDS.has("ui_massicot"))
	_check("ui_refus est déclarée dans SOUNDS",
		AM.SOUNDS.has("ui_refus"))
	
	_check("ui_presse a une priorité définie dans le barème",
		AM.priorite_de("ui_presse") == 1)
	_check("ui_tampon a une priorité définie dans le barème",
		AM.priorite_de("ui_tampon") == 1)
	_check("ui_massicot a une priorité définie dans le barème",
		AM.priorite_de("ui_massicot") == 1)
	_check("ui_refus a une priorité définie dans le barème",
		AM.priorite_de("ui_refus") == 1)
