extends Node

## La planche de contact — une image par état du jeu, et rien d'autre.
##
## **Elle n'affirme rien, et c'est délibéré.** Une automatisation vérifie ce
## qu'on a pensé à vérifier ; l'œil voit ce à quoi personne n'avait pensé. Les
## deux défauts visuels du 2026-08-18/19 — un cadre de menu entièrement noir, un
## joueur planté en bas de l'écran — sautent aux yeux sur une planche et
## n'auraient été attrapés par aucune assertion écrite d'avance.
##
## Elle ne peut donc pas pourrir : pas d'image de référence, pas de seuil, pas de
## tolérance à élargir. Rien à maintenir, donc rien qui se périme.
##
## **Ce qu'elle change vraiment, c'est le COÛT DE REGARDER.** Le défaut n'était
## pas que personne ne pouvait voir : c'est que voir demandait de lancer le jeu,
## de naviguer, et de penser à regarder. Quand regarder coûte vingt secondes, on
## regarde.
##
## Lancer : godot --path . res://tools/planche_contact.tscn
## Les images sortent dans `user://planche/`, dont le chemin réel est imprimé à
## la fin — c'est celui-là qu'on ouvre.

const Commun := preload("res://tools/rendu_commun.gd")

## Laissé au jeu entre deux états : les effets de la vitrine s'installent, les
## fondus se terminent, les shaders se compilent. Trop court, on photographie une
## transition et la planche ment sur l'état qu'elle annonce.
const REPOS := 0.6

var _main: Node
var _ui: Node
var _n := 0
var _dossier := "user://planche"

func _ready() -> void:
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la planche de contact ne peut pas travailler ici : ", refus)
		printerr("  Lancer SANS --headless : godot --path . res://tools/planche_contact.tscn")
		_sortir(1)
		return

	print("=== Planche de contact ===")
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")

	var manquants: Array[String] = Commun.preconditions_manquantes(_ui, _main)
	if not manquants.is_empty():
		printerr("✗ la planche ne peut pas démarrer — le jeu a changé sous elle :")
		for m in manquants:
			printerr("    · ", m)
		_sortir(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	for f in _anciennes():
		DirAccess.remove_absolute(f)

	await _menus()
	await _entrainement()

	print("\n%d images écrites dans :\n  %s" % [_n, ProjectSettings.globalize_path(_dossier)])
	print("Ouvrez le dossier et regardez-les. C'est tout ce qu'on vous demande.")
	_sortir(0)


## Les écrans de menu, y compris le cadre de droite — celui qui était noir.
func _menus() -> void:
	_ui.show_main_menu()
	await _poser("01-menu-accueil")

	# On traverse par `push()` comme le ferait un joueur, plutôt qu'en montrant
	# les racines à la main : un écran atteint autrement n'est pas dans l'état où
	# on le verra jamais.
	#
	# **Les écrans de salon et d'appariement sont écartés, et ce n'est pas un
	# oubli.** Y entrer EST la décision de mode : `_on_hub_screen_changed` y écrit
	# le transport et l'intention réseau, et la planche ouvrirait de vrais salons
	# EOS en passant. Un outil d'observation ne doit rien produire dans le monde.
	# Le cadre de droite — celui qui était noir — se voit de toute façon sur
	# n'importe quel écran.
	var ecrans := {
		_ui.SCREEN_LOCAL: "02-salon-local",
		_ui.SCREEN_CUSTOM: "03-personnalisation",
	}
	for id: String in ecrans.keys():
		if _ui.hub.has_screen(id):
			_ui.hub.reset()
			_ui.hub.push(id)
			await _poser(String(ecrans[id]))

	# Les rubriques de réglage vivent dans le cadre de droite et ne descendent
	# plus : c'est là que le verre fumé et le voile s'appliquent, donc là que le
	# noir s'était installé.
	if _ui.hub.has_screen(_ui.SCREEN_CUSTOM):
		_ui.hub.reset()
		_ui.hub.push(_ui.SCREEN_CUSTOM)
		var liste = _ui.hub.list_of(_ui.SCREEN_CUSTOM)
		if liste != null:
			var i := 0
			for enfant in liste.get_children():
				var btn := enfant as Button
				if btn == null or btn.disabled:
					continue
				i += 1
				# Le survol suffit : depuis la refonte, une rubrique remplit le
				# cadre de droite sans qu'on l'active.
				btn.grab_focus()
				await _poser("04-%d-reglages" % i)


## L'entraînement : un seul joueur, une seule vue, et la caméra sur lui.
func _entrainement() -> void:
	if not _main.has_method("_on_training_requested"):
		return
	_main._on_training_requested()
	await _poser("10-entrainement")
	# Le joueur bouge : c'est le seul moyen de voir si la caméra le suit, et
	# c'est exactement ce qui manquait le 2026-08-19.
	if "p1" in _main and _main.p1 != null:
		_main.p1.global_position += Vector2(260.0, 180.0)
	await _poser("11-entrainement-apres-deplacement")


func _poser(nom: String) -> void:
	var fin := Time.get_ticks_msec() + int(REPOS * 1000.0)
	while Time.get_ticks_msec() < fin:
		await get_tree().process_frame
	var img: Image = await Commun.capturer(get_tree())
	if img == null:
		# Le rendu n'est pas venu dans le budget : presque toujours une fenêtre
		# passée à l'arrière-plan, que macOS bride. On le DIT et on continue —
		# une planche incomplète reste utile, une planche qui pend ne l'est pas.
		printerr("  ✗ %s : aucune image (fenêtre au premier plan ?)" % nom)
		return
	var chemin := "%s/%s.png" % [_dossier, nom]
	img.save_png(chemin)
	_n += 1
	print("  · %s" % nom)


func _anciennes() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(_dossier)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".png"):
			out.append(ProjectSettings.globalize_path("%s/%s" % [_dossier, f]))
	return out


## Sortir par la porte du jeu : `main.tscn` instancie les autoloads EOS, et
## quitter sec ré-entre dans `EOS_Platform_Tick()` — segfault documenté.
func _sortir(code: int) -> void:
	var reseau := get_node_or_null(^"/root/NetworkManager")
	if reseau != null and reseau.has_method("quit_game"):
		reseau.quit_game(code)
		return
	get_tree().quit(code)
