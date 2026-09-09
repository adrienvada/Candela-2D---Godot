## Test headless du bouton mécanique à deux crans de la torche —
## `LocalInputProvider.is_flashlight_pressed()`.
##
## Isolé de `input_setup.gd` : l'action et sa zone morte sont posées ici, à
## l'identique (0.2, voir `input_setup.gd`), pour ne pas dépendre de l'ordre de
## démarrage des autoloads en mode --script. Même prudence que
## `planche_eblouissement.gd` sur les bancs qui partagent leurs appuis avec ce
## qu'ils mesurent : une action absente du catalogue rendrait ce test aussi
## silencieusement faux que la mécanique qu'il vérifie.
##
## Lancer : godot --headless --path . --script res://tools/test_torche_bouton.gd
extends SceneTree

const ACTION := "torche_bouton_test"
const DEADZONE := 0.2

var _failures: int = 0
var _provider: LocalInputProvider

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== TORCHE : BOUTON MÉCANIQUE À DEUX CRANS ===")
	if not InputMap.has_action(ACTION):
		InputMap.add_action(ACTION)
		InputMap.action_set_deadzone(ACTION, DEADZONE)

	# Ni ajouté à l'arbre ni passé par `_setup_inputs()` : seul `action_torch`
	# nous intéresse, et le pointer directement sur l'action de test évite de
	# dépendre du catalogue p1_/p2_ de `input_setup.gd`.
	_provider = LocalInputProvider.new()
	_provider.action_torch = ACTION

	_test_appui_leger()
	_relacher()
	_test_clic_enclenche()
	_relacher()
	_test_second_clic_debascule()
	_relacher()
	_test_reset_efface_le_cran()

	_provider.free()
	quit(1 if _failures > 0 else 0)

func _relacher() -> void:
	Input.action_release(ACTION)
	# Laisse le FRONT retomber avant le test suivant, sans quoi son premier
	# appui à fond ne serait pas vu comme un nouveau front.
	_provider.is_flashlight_pressed()

func _test_appui_leger() -> void:
	print("\n[Premier cran : n'éclaire que tenu]")
	Input.action_press(ACTION, LocalInputProvider.TORCH_CRAN_FOND * 0.5)
	_check("un appui sous le seuil du clic éclaire",
		_provider.is_flashlight_pressed())
	Input.action_release(ACTION)
	_check("relâché, elle s'éteint aussitôt",
		not _provider.is_flashlight_pressed())

func _test_clic_enclenche() -> void:
	print("\n[Second cran : le clic reste enclenché]")
	Input.action_press(ACTION, 1.0)
	_check("un appui à fond éclaire", _provider.is_flashlight_pressed())
	Input.action_release(ACTION)
	_check("relâchée après un clic, elle reste allumée",
		_provider.is_flashlight_pressed())

func _test_second_clic_debascule() -> void:
	print("\n[Un second clic débascule]")
	# Le clic du test précédent est encore enclenché : c'est la propriété
	# vérifiée ici — la mémoire traverse les appuis relâchés entre-temps.
	Input.action_press(ACTION, 1.0)
	_check("gâchette à fond : elle éclaire, qu'elle enclenche ou débascule",
		_provider.is_flashlight_pressed())
	Input.action_release(ACTION)
	_check("le second clic à fond éteint ce que le premier avait enclenché",
		not _provider.is_flashlight_pressed())

func _test_reset_efface_le_cran() -> void:
	print("\n[reset_flashlight_state : hygiène de manche]")
	Input.action_press(ACTION, 1.0)
	_provider.is_flashlight_pressed() # enclenche
	Input.action_release(ACTION)
	_check("précondition : le clic est resté enclenché",
		_provider.is_flashlight_pressed())
	_provider.reset_flashlight_state()
	_check("après reset, plus rien n'éclaire sans nouvel appui",
		not _provider.is_flashlight_pressed())
