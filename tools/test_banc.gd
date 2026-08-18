## Le banc de cadence peut-il encore démarrer ?
##
## **Il ne le pouvait plus depuis la refonte des menus, et personne ne le savait.**
## `bench_framerate.gd` lisait `_ui.btn_mode_local`, disparu quand les modes sont
## devenus des entrées du hub : il s'ouvrait, levait une erreur de script,
## n'entrait jamais dans le duel et restait ouvert sans rien mesurer. Découvert
## le 2026-08-18, à la minute où le chiffre était demandé.
##
## La cause n'est pas la ligne, c'est la couverture : **le banc ouvre une fenêtre,
## donc il ne peut être dans aucune suite headless** — et rien ne signalait sa
## péremption. Un outil de mesure hors couverture se périme en silence.
##
## Cette suite ne mesure rien et n'ouvre rien. Elle vérifie seulement que les
## appuis du banc sur le jeu existent encore. C'est peu, et c'est exactement ce
## qui manquait : le banc aurait échoué ici, en headless, le jour de la refonte —
## au lieu d'échouer une semaine plus tard devant quelqu'un qui attendait un
## résultat.
##
## Lancer : godot --headless --path . --script res://tools/test_banc.gd
extends SceneTree

var _failures: int = 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== LE BANC PEUT-IL DÉMARRER ===")
	await process_frame
	# `load` et non `preload` : le banc nomme `NetworkManager`, et un `preload` en
	# tête de fichier le compilerait AVANT que les autoloads existent. L'échec ne
	# s'arrête pas à lui — il se propage à tout ce qui dépend d'eux, et main.tscn
	# arrive alors sans ses scripts, donc « tout a disparu ». C'est la troisième
	# forme du même piège dans la journée : ce qui est chargé tôt est compilé tôt.
	var Banc: GDScript = load("res://tools/bench_framerate.gd")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ui: Node = main.get_node_or_null("UI")

	var manquants: Array[String] = Banc.preconditions_manquantes(ui, main)
	_check("tous les appuis du banc existent encore", manquants.is_empty(),
		"; ".join(manquants))

	# Le contre-test : la vérification doit savoir DÉTECTER une disparition,
	# sinon elle rendrait toujours une liste vide et passerait pour verte.
	var vides: Array[String] = Banc.preconditions_manquantes(null, null)
	_check("et elle sait dire quand ils manquent", not vides.is_empty())

	# Le MODE MENUS a ses propres appuis, et il est né avec eux — c'est la
	# consigne tirée de la panne du duel : un outil qu'aucune suite ne peut
	# exécuter doit au moins exposer ses hypothèses sous une forme qu'une suite
	# peut vérifier. Les deux listes sont séparées parce que les deux modes ne
	# touchent pas au même jeu : une liste commune se plaindrait de l'absence
	# d'une arme dans un banc qui n'en tire aucune.
	var manquants_menus: Array[String] = Banc.preconditions_menus(ui)
	_check("les appuis du mode menus existent encore", manquants_menus.is_empty(),
		"; ".join(manquants_menus))
	var vides_menus: Array[String] = Banc.preconditions_menus(null)
	_check("et le mode menus sait dire quand ils manquent",
		not vides_menus.is_empty())

	main.queue_free()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
