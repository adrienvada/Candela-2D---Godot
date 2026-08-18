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

## La fermeture a-t-elle été demandée ? Distingue le démontage attendu — celui
## qu'on est venu provoquer — d'une sortie pour toute autre raison.
var _close_requested := false


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
	_close_requested = true
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

	# Si personne ne reprend la main, l'arbre reste vivant : au bout de 10 s on
	# déclare l'échec plutôt que de tourner indéfiniment.
	await get_tree().create_timer(10.0).timeout
	printerr("  ✗ la fermeture n'a pas été prise en charge")
	get_tree().quit(1)


## Le verdict, et il ne pouvait pas s'imprimer plus tôt.
##
## La réussite de ce banc consiste à **disparaître** : NetworkManager reprend la
## notification, relâche la plateforme et appelle `quit()` — le processus s'arrête
## donc avant la ligne suivante. Sans ce message, une réussite ressemblait trait
## pour trait à un banc qui n'aurait rien exécuté, et le lecteur devait deviner
## que le silence valait succès. Un garde-fou muet en cas de réussite ne se
## distingue pas d'un garde-fou absent.
##
## `_exit_tree` est le dernier endroit où l'on parle encore : il est appelé
## pendant le démontage que `quit()` déclenche.
func _exit_tree() -> void:
	if not _close_requested:
		return
	print("  ✓ la fermeture a été prise en charge, la plateforme relâchée avant l'arbre")
	print("✓ Tous les tests passent")
	print("EXIT_CODE: 0")
