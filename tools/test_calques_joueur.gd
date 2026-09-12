extends SceneTree

## Les calques d'écran d'un joueur suivent-ils le viewport qui le rend ?
##
## La vignette de dégâts et le flash de mort vivent dans un `CanvasLayer`. Un
## `CanvasLayer` s'attache au VIEWPORT de son parent, jamais au monde : enfant
## du joueur, donc de l'arène, donc de `SubViewport1`, il n'était dessiné que
## là — jamais pour J2 en écran scindé (sa vue est `SubViewport2`), jamais pour
## personne en vue unique (chantier R : les sous-vues sont arrêtées, la racine
## rend le duel). Adrien, le 2026-09-11 : « je ne l'ai pas vue ». Depuis
## toujours, en fait, et aucune suite ne le voyait : le photographe force le
## rendu par sous-vue.
##
## `GameState.accueillir_calque()` loge donc chaque calque là où son joueur est
## rendu, et `_accorder_rendu_aux_vues()` les reloge à chaque bascule. Cette
## suite joue les deux bascules et regarde le PARENT de chaque calque — c'est
## lui qui décide du viewport, donc de l'écran où la vignette apparaît.

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
	print("=== LES CALQUES D'ÉCRAN SUIVENT LE RENDU ===")
	await process_frame
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		_check("main.tscn se charge", false)
		_sortir()
		return
	var main: Node = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	if main.p1 == null or main.p2 == null:
		_check("les deux joueurs existent après le démarrage", false)
		_sortir()
		return
	var c1: Array = main.p1.calques_ecran
	var c2: Array = main.p2.calques_ecran
	_check("J1 déclare au moins un calque d'écran (la vignette)", c1.size() >= 1)
	_check("J2 déclare au moins un calque d'écran (la vignette)", c2.size() >= 1)
	if c1.is_empty() or c2.is_empty():
		_sortir()
		return

	# --- Écran scindé : chaque joueur dans SA sous-vue ---
	main.vp2.get_parent().show()
	main._accorder_rendu_aux_vues()
	await process_frame
	_check("scindé : le calque de J1 vit dans SubViewport1",
		c1[0].get_parent() == main.vp1, str(c1[0].get_parent()))
	_check("scindé : le calque de J2 vit dans SubViewport2 — pas dans celle de J1",
		c2[0].get_parent() == main.vp2, str(c2[0].get_parent()))

	# --- Vue unique : la racine rend J1, son calque la rejoint ---
	main.vp2.get_parent().hide()
	main._accorder_rendu_aux_vues()
	await process_frame
	if main._rendu_racine:
		_check("vue unique : le calque de J1 rejoint la racine, qui rend le duel",
			c1[0].get_parent() == main, str(c1[0].get_parent()))
	else:
		_check("vue unique : le rendu racine est actif", false,
			"rendu_racine_autorise = %s" % str(main.rendu_racine_autorise))

	# --- Retour : et il revient ---
	main.vp2.get_parent().show()
	main._accorder_rendu_aux_vues()
	await process_frame
	_check("retour au scindé : le calque de J1 revient dans SubViewport1",
		c1[0].get_parent() == main.vp1, str(c1[0].get_parent()))

	# Le flash de mort prend le même chemin : un calque posé après coup est
	# logé tout de suite au bon endroit.
	var neuf := CanvasLayer.new()
	neuf.name = "CalqueDEssai"
	main.p2._loger_calque(neuf)
	_check("un calque posé plus tard est logé au bon endroit (J2 → SubViewport2)",
		neuf.get_parent() == main.vp2, str(neuf.get_parent()))

	main.queue_free()
	_sortir()


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent")
		quit(0)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
		quit(1)
