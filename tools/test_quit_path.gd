## Vérifie la sortie par la croix de la fenêtre.
##
## `auto_accept_quit` est désactivé dès qu'EOS est initialisé : c'est
## NetworkManager._notification qui doit reprendre la main, sans quoi le jeu
## deviendrait impossible à fermer autrement que par le menu. On rejoue ici la
## notification exactement comme l'engine la propage depuis la fenêtre racine.
##
## Lancer : godot --headless --path . res://tools/test_quit_path.tscn -- [--eos-ephemeral]
extends Node

const EOS_TIMEOUT := 30.0


func _ready() -> void:
	print("=== SORTIE PAR LA FENETRE ===")
	var main := preload("res://main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame

	var waited := 0.0
	while NetworkManager.eos_state == NetworkManager.EosState.INITIALIZING and waited < EOS_TIMEOUT:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	print("EOS: %s" % NetworkManager.eos_state_label())
	print("auto_accept_quit: %s (doit être faux si EOS est prêt)" % get_tree().auto_accept_quit)
	if NetworkManager.eos_state == NetworkManager.EosState.READY and get_tree().auto_accept_quit:
		printerr("  ✗ auto_accept_quit resté vrai : la plateforme serait libérée trop tard")
		get_tree().quit(1)
		return

	print("FENETRE: demande de fermeture")
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

	# Si personne ne reprend la main, l'arbre reste vivant : au bout de 10 s on
	# déclare l'échec plutôt que de tourner indéfiniment.
	await get_tree().create_timer(10.0).timeout
	printerr("  ✗ la fermeture n'a pas été prise en charge")
	get_tree().quit(1)
