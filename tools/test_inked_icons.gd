## Test headless des assets d encre, rivets et tampons de verdict (Étape 3)
##
## Valide :
## 1. La présence et le chargement des 16 SVGs de prompts manette brutaux.
## 2. Le composant MenuRivetsOverlay (styles tôles, rivets, chevrons).
## 3. Le composant MenuTamponVerdict (presets VICTOIRE/DÉFAITE/FATAL, écrasement mécanique).
##
## Lancer : godot --headless --path . --script res://tools/test_inked_icons.gd
extends SceneTree

const Charte := preload("res://charte.gd")
const MenuRivetsOverlay := preload("res://menu_rivets_overlay.gd")
const MenuTamponVerdict := preload("res://menu_tampon_verdict.gd")

const PROMPT_NAMES := [
	"circle", "cross", "square", "triangle",
	"dpad_up", "dpad_down", "dpad_left", "dpad_right",
	"l1", "l2", "l3",
	"r1", "r2", "r3",
	"share", "options"
]

var _failures: int = 0

func _init() -> void:
	print("=== Test des assets d encre & tampons (Étape 3) ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_test_svg_prompts()
	_test_rivets_overlay()
	await _test_tampon_verdict()

	if _failures == 0:
		print("\n✓ Tous les tests des assets d encre et tampons passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _test_svg_prompts() -> void:
	print("\n[1. Validation des 16 Prompts Manette SVGs]")
	for p_name in PROMPT_NAMES:
		var path := "res://assets/ui/prompts/%s.svg" % p_name
		var tex = load(path)
		_check("Prompt %s.svg chargé comme Texture2D" % p_name, tex != null and tex is Texture2D, path)
		if tex is Texture2D:
			_check("Prompt %s.svg a des dimensions valides (>0)" % p_name, tex.get_width() > 0 and tex.get_height() > 0)

func _test_rivets_overlay() -> void:
	print("\n[2. Composant MenuRivetsOverlay]")
	var overlay := MenuRivetsOverlay.new()
	overlay.size = Vector2(300, 200)
	root.add_child(overlay)

	_check("MenuRivetsOverlay instancié", overlay != null)
	_check("Style par défaut RIVETS_SEULS", overlay.style == MenuRivetsOverlay.Style.RIVETS_SEULS)

	# Tester les styles
	overlay.style = MenuRivetsOverlay.Style.TOLE_COMPLETE
	_check("Passage au style TOLE_COMPLETE", overlay.style == MenuRivetsOverlay.Style.TOLE_COMPLETE)

	overlay.style = MenuRivetsOverlay.Style.CHEVRONS_HAUT
	_check("Passage au style CHEVRONS_HAUT", overlay.style == MenuRivetsOverlay.Style.CHEVRONS_HAUT)

	overlay.style = MenuRivetsOverlay.Style.CHEVRONS_GAUCHE
	_check("Passage au style CHEVRONS_GAUCHE", overlay.style == MenuRivetsOverlay.Style.CHEVRONS_GAUCHE)

	# Forcer le redessin
	overlay.queue_redraw()
	overlay.queue_free()

func _test_tampon_verdict() -> void:
	print("\n[3. Composant MenuTamponVerdict]")
	var v_victoire := MenuTamponVerdict.creer_victoire()
	root.add_child(v_victoire)
	v_victoire.size = Vector2(240, 70)
	_check("Tampon VICTOIRE créé", v_victoire.texte == "VICTOIRE" and v_victoire.couleur_encre == Charte.AMBRE)

	var v_defaite := MenuTamponVerdict.creer_defaite()
	_check("Tampon DÉFAITE créé", v_defaite.texte == "DÉFAITE" and v_defaite.couleur_encre == Charte.ROUGE)

	var v_fatal := MenuTamponVerdict.creer_fatal()
	_check("Tampon FATAL créé", v_fatal.texte == "FATAL" and v_fatal.couleur_encre == Charte.CARMIN)

	await process_frame
	# Test frappe mécanique et signal
	var state := {"recue": false}
	v_victoire.frappe_terminee.connect(func() -> void:
		state["recue"] = true
	)
	v_victoire.frapper(0.05)

	# Attendre que le tween se termine via les frames du SceneTree
	for _i in range(60):
		await process_frame
		if state["recue"]:
			break

	_check("Signal frappe_terminee émis après écrasement", state["recue"])

	v_victoire.queue_free()
	v_defaite.free()
	v_fatal.free()
