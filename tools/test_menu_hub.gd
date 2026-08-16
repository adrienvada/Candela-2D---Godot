## Test headless de l'ossature de navigation du hub — Phase 5, étape 2.
##
## L'ossature porte tout le risque de la refonte : si la pile se trompe d'un
## cran, le joueur atterrit au mauvais endroit, et c'est le genre de défaut qu'on
## met longtemps à croire parce qu'il ressemble à une erreur de manipulation.
## Elle est donc exercée seule, avant qu'un seul écran ne soit rempli.
##
## Lancer : godot --headless --path . --script res://tools/test_menu_hub.gd
extends SceneTree

var _failures: int = 0
var _hub: MenuHub

func _init() -> void:
	print("=== Test de l'ossature du hub ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame
	_hub = MenuHub.new()
	root.add_child(_hub)

	# L'arborescence cible de la structure B, réduite à ce qui se navigue.
	_hub.add_screen(MenuHub.ROOT, "Candela 2D")
	_hub.add_screen("mode", "Jouer")
	_hub.add_screen("prep", "1v1 local")
	_hub.add_screen("online", "1v1 en ligne")
	_hub.add_screen("salon", "Salon")
	_hub.add_screen("cartes", "Cartes")
	_hub.add_screen("options", "Options")
	_hub.add_screen("audio", "Options — audio")
	_hub.reset()
	await process_frame

	_test_depart()
	_test_descente()
	_test_retour()
	_test_racine()
	_test_visibilite()
	_test_deux_chemins()
	_test_reset()
	_test_ecran_inconnu()
	_test_signal()

	root.remove_child(_hub)
	_hub.free()

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
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

# ---------------------------------------------------------------------------

func _test_depart() -> void:
	print("\n[Départ]")
	_check("on démarre à l'accueil", _hub.current_id() == MenuHub.ROOT, _hub.current_id())
	_check("profondeur nulle", _hub.depth() == 0, str(_hub.depth()))

func _test_descente() -> void:
	print("\n[Descente]")
	_hub.reset()
	_check("Jouer accepte", _hub.push("mode"))
	_check("on y est", _hub.current_id() == "mode", _hub.current_id())
	_check("profondeur 1", _hub.depth() == 1, str(_hub.depth()))

	_check("1v1 en ligne accepte", _hub.push("online"))
	_check("Salon accepte", _hub.push("salon"))
	_check("profondeur 3", _hub.depth() == 3, str(_hub.depth()))

	# Sans ce refus, un double appui sur une entrée obligerait à deux retours
	# pour un seul aller — et le joueur croirait le bouton cassé.
	_check("réempiler l'écran courant ne fait rien", not _hub.push("salon"))
	_check("la profondeur n'a pas bougé", _hub.depth() == 3, str(_hub.depth()))

func _test_retour() -> void:
	print("\n[Retour]")
	_hub.reset()
	_hub.push("mode")
	_hub.push("online")
	_hub.push("salon")

	_check("le retour accepte", _hub.back())
	_check("il ramène d'un cran exactement", _hub.current_id() == "online", _hub.current_id())
	_hub.back()
	_check("puis au précédent", _hub.current_id() == "mode", _hub.current_id())
	_hub.back()
	_check("puis à l'accueil", _hub.current_id() == MenuHub.ROOT, _hub.current_id())

func _test_racine() -> void:
	print("\n[Fond de pile]")
	_hub.reset()
	var vu := [false]
	_hub.back_at_root.connect(func() -> void: vu[0] = true)

	_check("le retour à l'accueil est refusé", not _hub.back())
	_check("l'accueil est toujours là", _hub.current_id() == MenuHub.ROOT)
	_check("et il le signale à l'appelant", vu[0])

	# Dix retours de rang ne doivent pas vider la pile : `current_id` lit le
	# dernier élément et planterait sur une pile vide.
	for i in 10:
		_hub.back()
	_check("dix retours n'ont pas vidé la pile", _hub.current_id() == MenuHub.ROOT)

func _test_visibilite() -> void:
	print("\n[Un seul écran visible]")
	_hub.reset()
	_hub.push("mode")
	_hub.push("prep")

	var visibles: Array[String] = []
	for id in ["accueil", "mode", "prep", "online", "salon", "cartes", "options", "audio"]:
		var body := _hub.body_of(id)
		if body != null and body.visible:
			visibles.append(id)

	# Un corps caché est hors d'atteinte du curseur : c'est ce qui empêche la
	# navigation de sortir de l'écran courant.
	_check("exactement un corps est visible", visibles.size() == 1, str(visibles))
	_check("et c'est le courant", visibles.size() == 1 and visibles[0] == "prep", str(visibles))

## Le cas qui justifie une pile plutôt qu'un parent déclaré : la galerie de
## cartes s'ouvre depuis la préparation locale comme depuis le salon en ligne.
func _test_deux_chemins() -> void:
	print("\n[Un écran, deux chemins]")
	_hub.reset()
	_hub.push("mode")
	_hub.push("prep")
	_hub.push("cartes")
	_hub.back()
	_check("depuis la préparation locale, on y revient",
		_hub.current_id() == "prep", _hub.current_id())

	_hub.reset()
	_hub.push("mode")
	_hub.push("online")
	_hub.push("salon")
	_hub.push("cartes")
	_hub.back()
	_check("depuis le salon, on revient au salon",
		_hub.current_id() == "salon", _hub.current_id())

func _test_reset() -> void:
	print("\n[Réinitialisation]")
	_hub.push("mode")
	_hub.push("online")
	_hub.reset()
	_check("on est ramené à l'accueil", _hub.current_id() == MenuHub.ROOT)
	_check("la pile est à plat", _hub.depth() == 0, str(_hub.depth()))
	# Un menu rouvert doit repartir de l'accueil, jamais de l'écran où on l'avait
	# laissé trois crans plus bas.
	_check("le retour est de nouveau refusé", not _hub.back())

func _test_ecran_inconnu() -> void:
	print("\n[Écran inconnu]")
	_hub.reset()
	_check("empiler un identifiant qui n'existe pas est refusé",
		not _hub.push("ecran_qui_nexiste_pas"))
	_check("et ne déplace rien", _hub.current_id() == MenuHub.ROOT)
	_check("la profondeur reste nulle", _hub.depth() == 0, str(_hub.depth()))

func _test_signal() -> void:
	print("\n[Signal]")
	_hub.reset()
	var vus: Array[String] = []
	_hub.screen_changed.connect(func(id: String) -> void: vus.append(id))

	_hub.push("options")
	_hub.push("audio")
	_hub.back()

	_check("chaque changement est annoncé, retours compris",
		vus == ["options", "audio", "options"], str(vus))
