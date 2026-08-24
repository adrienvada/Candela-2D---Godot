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
	await _code_de_salon()
	await _ecrans_de_fin()
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
				# **`grab_focus()` NE SUFFIT PAS, et la planche l'ignorait.**
				#
				# Le cadre de droite ne se remplit pas au focus de Godot : il se
				# remplit par `MenuHub.reveal_entry()`, que `ui._set_focus()`
				# appelle. C'est le relais posé le 2026-08-18, quand on a
				# découvert que les curseurs maison ne déclenchent jamais
				# `focus_entered` — ils dessinent un liseré, ils n'appellent pas
				# `grab_focus()`.
				#
				# La planche empruntait donc un chemin QUE PERSONNE NE PREND, et
				# photographiait un cadre vide que le joueur ne voit jamais. Un
				# outil d'observation qui n'observe pas l'état réel est pire
				# qu'absent : il rassure sur ce qu'il n'a pas regardé.
				btn.grab_focus()
				if _ui.hub.has_method("reveal_entry"):
					_ui.hub.reveal_entry(btn)
				await _poser("04-%d-reglages" % i)


## Le code de salon, photographié SANS ouvrir de salon.
##
## **Il manquait à la planche, et l'exclusion des écrans de salon était bonne
## pour la mauvaise conclusion.** Y entrer est une décision de mode —
## `_on_hub_screen_changed` y écrit le transport et ouvrirait de vrais salons
## EOS. La règle « un outil d'observation ne produit rien dans le monde » tient
## donc pour l'écran. Mais le bloc de gravure, lui, est un `Control` autonome :
## aucun réseau, aucun autoload, il se construit et se grave tout seul. Ce qui
## était inobservable, ce n'était pas le code — c'était le chemin qu'on prenait
## pour l'atteindre.
##
## Trois états, parce que c'est là que se logent les défauts de ce bloc : les
## cases vides à l'ouverture, un code aux glyphes larges, un code aux glyphes
## étroits. **`tools/test_habillage.gd` mesure déjà que les deux derniers
## occupent la même largeur** ; ces images-ci disent ce qu'aucune mesure ne dit —
## si l'air entre les cases est juste, et si la fonte d'enseigne se lit à cette
## taille.
func _code_de_salon() -> void:
	# ⚠️ **Un `CanvasLayer`, et pas un `Control` posé dans l'arbre.** Premier jet :
	# un `ColorRect` ajouté après `_main`, donc « au-dessus » au sens de l'ordre
	# des enfants. Les trois images ont montré le **menu**, intact : `ui.gd` vit
	# dans un `CanvasLayer`, et un `CanvasLayer` passe devant tout ce qui n'en est
	# pas un, quel que soit l'ordre des frères. La planche a photographié quelque
	# chose de parfaitement lisible qui n'était pas le sujet — et sans ces images,
	# on aurait cru le bloc vérifié.
	var couche := CanvasLayer.new()
	couche.layer = 200
	add_child(couche)

	var cadre := ColorRect.new()
	cadre.color = Charte.BACKDROP
	cadre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	couche.add_child(cadre)

	var bloc := MenuEngraver.new()
	bloc.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bloc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bloc.grow_vertical = Control.GROW_DIRECTION_BOTH
	cadre.add_child(bloc)

	await _poser("05-code-de-salon-vide")
	# `WXYZW3` et `JT7JT7` : les deux extrêmes de chasse de l'alphabet des codes.
	# Si l'air des cases est mal réglé, c'est entre ces deux images que ça se voit.
	bloc.set_code("WXYZW3")
	await _poser("06-code-de-salon-large")
	bloc.set_code("JT7JT7")
	await _poser("07-code-de-salon-etroit")

	cadre.queue_free()
	await get_tree().process_frame


## Les trois verdicts.
##
## **Quatre des quinze effets de la vitrine ne vivent nulle part ailleurs**, et la
## planche ne les voyait pas : la température du verdict portée par le titre
## (M11) et l'ombre du cadran projetée par VICTOIRE / DÉFAITE / ÉGALITÉ (M1). On
## les a donc recalibrés à l'aveugle une fois — c'est-à-dire exactement ce que
## cet outil existe pour empêcher.
##
## `show_game_over` prend l'identifiant du vainqueur : 0, 1, ou -1 pour l'égalité.
## Aucun réseau, aucune manche : c'est un écran, on le montre.
func _ecrans_de_fin() -> void:
	if not _ui.has_method("show_game_over"):
		printerr("  ! UI.show_game_over() a disparu — les verdicts ne sont plus vus")
		return
	for cas in [[0, "20-verdict-victoire"], [1, "21-verdict-defaite"],
			[-1, "22-verdict-egalite"]]:
		_ui.show_game_over(int(cas[0]))
		await _poser(String(cas[1]))
	_ui.show_main_menu()


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
