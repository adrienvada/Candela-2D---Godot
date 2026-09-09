## Test headless de la réinitialisation du transport réseau dans l'UI.
##
## Vérifie que la navigation vers les écrans d'appariement en ligne (amical et classé)
## ou l'appel à _start_search() restaure bien le transport NetworkManager.Transport.EOS,
## même si le joueur est passé préalablement par un salon en réseau local (ENet).
##
## Lancer : godot --headless --path . --script res://tools/test_ui_transport_reset.gd -- --no-eos
extends SceneTree

var _failures: int = 0

func _init() -> void:
	print("=== Test de la réinitialisation du transport UI ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame

	var net = root.get_node_or_null(^"/root/NetworkManager")
	if net == null:
		_check("NetworkManager présent", false, "autoload introuvable")
		quit(1)
		return

	var ui_scene: PackedScene = load("res://main.tscn")
	if ui_scene == null:
		_check("main.tscn charge", false)
		quit(1)
		return

	var main = ui_scene.instantiate()
	root.add_child(main)
	await process_frame

	var ui = main.get_node_or_null("UI")
	if ui == null:
		_check("Noeud UI présent", false)
		quit(1)
		return

	var transports = net.get_script().get_script_constant_map()["Transport"]

	# 1. Simuler l'entrée dans un salon local (Rejoindre)
	ui._on_hub_screen_changed(ui.SCREEN_LOCAL_JOIN)
	_check("L'écran local_join passe le transport à ENET",
		net.transport == transports["ENET"],
		"transport = %s" % net.transport)

	# 2. Revenir au menu et naviguer vers "1v1 amical"
	ui._on_hub_screen_changed(ui.SCREEN_FRIENDLY)
	_check("La navigation vers 1v1 amical restaure le transport EOS",
		net.transport == transports["EOS"],
		"transport = %s" % net.transport)

	# 3. Simuler à nouveau un passage par salon local hôte
	ui._on_hub_screen_changed(ui.SCREEN_LOCAL_HOST)
	_check("L'écran local_host passe le transport à ENET",
		net.transport == transports["ENET"],
		"transport = %s" % net.transport)

	# 4. Revenir au menu et naviguer vers "1v1 compétitif"
	ui._on_hub_screen_changed(ui.SCREEN_RANKED)
	_check("La navigation vers 1v1 compétitif restaure le transport EOS",
		net.transport == transports["EOS"],
		"transport = %s" % net.transport)

	# 5. Tester _start_search avec un transport résiduel forcé
	net.transport = transports["ENET"]
	# On appelle _start_search() : même si le matchmaker refuse pour d'autres raisons,
	# le transport doit être remis à EOS immédiatement.
	ui._start_search()
	_check("_start_search() force le rétablissement du transport EOS",
		net.transport == transports["EOS"],
		"transport = %s" % net.transport)

	root.remove_child(main)
	main.free()

	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, (" : " + detail) if detail != "" else "")
