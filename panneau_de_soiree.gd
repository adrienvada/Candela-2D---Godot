class_name PanneauDeSoiree
extends CanvasLayer

## DA6.3 / DA6.4 — la carte de fin de soirée telle qu'on la rencontre.
##
## `CarteDeSoiree` compose, `Exporteur` écrit un fichier ; ce fichier-ci est le
## moment : quand la carte apparaît, comment on la congédie, et ce qui se passe
## quand on demande à la garder.
##
## ## Quand elle apparaît, et surtout quand elle n'apparaît PAS
##
## Au retour au menu, après trois matchs (`BilanDeSoiree.SEUIL_MATCHS`), **une
## seule fois par séance**. C'est la partie la plus importante de la fiche et
## celle qu'on rate le plus facilement : le retour au menu arrive après CHAQUE
## match. Une carte qui se repose à chaque fois cesse d'être une fin de soirée
## pour devenir un écran de plus à congédier — et la quatrième fois, on ne la
## lit plus.
##
## `_deja_vue` est donc porté par l'appelant (`game_state`), pas par ce panneau :
## le panneau meurt à chaque fermeture, il ne peut rien se rappeler.
##
## ## Deux touches, pas de boutons
##
## Le jeu a un système de navigation à deux curseurs, des liserés, des styles
## d'entrée. Y brancher deux boutons demandait de faire entrer cette carte dans
## le hub des menus — donc dans `ui.gd`, donc dans le domaine d'une autre
## session, pour deux actions qui ne survivent pas à l'écran. `ui_accept` et
## `ui_cancel` sont des actions du moteur : elles existent toujours, elles sont
## déjà câblées à la manette, et elles ne demandent aucun focus.

const Charte := preload("res://charte.gd")

const COUCHE := 97
const D_ENTREE := 0.40
const D_SORTIE := 0.24

## Le temps que le chemin du fichier reste lisible après un export.
const D_CONFIRMATION := 6.0

var _bilan: Dictionary = {}
var _carte: CarteDeSoiree
var _confirmation: Label
var _ferme := false
var _exporte := false


static func poser(parent: Node, bilan: Dictionary) -> PanneauDeSoiree:
	var couche := PanneauDeSoiree.new()
	couche.name = "PanneauDeSoiree"
	couche.layer = COUCHE
	couche._bilan = bilan
	parent.add_child(couche)
	couche._composer()
	return couche


func _composer() -> void:
	var fond := ColorRect.new()
	fond.color = Charte.NOIR
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fond)

	# La carte garde son format PORTRAIT à l'écran, centrée sur un fond plein.
	# L'étirer à la fenêtre en ferait une page de menu ; la garder en 4:5 fait
	# qu'on voit à l'écran EXACTEMENT l'image qu'on va exporter — ce qui est la
	# seule façon honnête de proposer « garder l'image ».
	var hote := Control.new()
	hote.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hote)

	var ecran := _ecran()
	var h: float = clampf(ecran.y * 0.88, 320.0, 1350.0)
	var taille := Vector2(h * float(CarteDeSoiree.TAILLE_EXPORT.x)
		/ float(CarteDeSoiree.TAILLE_EXPORT.y), h)

	_carte = CarteDeSoiree.composer(_bilan, taille)
	# ⚠️ **Pas de `set_anchors_preset(PRESET_CENTER)` ICI.** Le préréglage pose
	# les ancres à 0,5 — puis la position s'ajoute par-dessus, et la carte part
	# d'une demi-fenêtre vers le bas à droite, à moitié hors cadre. On garde les
	# ancres en haut à gauche et on centre à la main : une seule des deux
	# mécaniques, jamais les deux.
	_carte.position = ((ecran - taille) * 0.5).floor()
	hote.add_child(_carte)

	_confirmation = Label.new()
	_confirmation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirmation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirmation.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_confirmation.offset_bottom = -Charte.GAP_M
	_confirmation.offset_top = -Charte.GAP_L
	Charte.appareil(_confirmation, Charte.T_MENTION)
	_confirmation.add_theme_color_override("font_color", Charte.ETAT_OK)
	_confirmation.modulate.a = 0.0
	hote.add_child(_confirmation)

	fond.modulate.a = 0.0
	hote.modulate.a = 0.0
	var tw := create_tween()
	Charte.animer(tw, fond, "modulate:a", 0.0, 1.0, D_ENTREE, Charte.Courbe.SORTIE)
	tw.parallel()
	Charte.animer(tw, hote, "modulate:a", 0.0, 1.0, D_ENTREE, Charte.Courbe.SORTIE)
	set_process_unhandled_input(true)


## La taille réelle de l'écran, disponible IMMÉDIATEMENT.
##
## ⚠️ **`Control.size` vaut zéro tant que la mise en page n'a pas eu lieu**, et
## une composition bâtie dans la foulée d'un `add_child()` la lit donc à zéro.
## Le repli « 1920×1080 » qui traînait ici marchait par coïncidence sur la
## fenêtre de développement et donnait des marges d'un tiers trop larges en
## 1280×720. Le viewport, lui, connaît sa taille avant tout le monde.
func _ecran() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(1920, 1080)


func _unhandled_input(evenement: InputEvent) -> void:
	if _ferme:
		return
	if evenement.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_garder()
		return
	# Tout le reste ferme : `ui_cancel`, une touche, un clic, un bouton de
	# manette. Une carte qu'on ne sait pas fermer est une carte qui enferme, et
	# elle arrive au moment où l'on vient de reposer la manette.
	var geste: bool = evenement.is_action_pressed("ui_cancel")
	geste = geste or (evenement is InputEventKey and evenement.pressed
		and not evenement.echo)
	geste = geste or (evenement is InputEventMouseButton and evenement.pressed)
	geste = geste or (evenement is InputEventJoypadButton and evenement.pressed)
	if geste:
		get_viewport().set_input_as_handled()
		fermer()


## DA6.4 — l'export. Une seule fois : deux appuis d'affilée sur la même carte
## écriraient deux fichiers identiques à une seconde près.
func _garder() -> void:
	if _exporte:
		return
	_exporte = true
	var bilan := _bilan
	var fabrique := func(taille: Vector2) -> Control:
		return CarteDeSoiree.composer(bilan, taille, true)
	var chemin: String = await Exporteur.png(self, fabrique,
		CarteDeSoiree.TAILLE_EXPORT, "candela-soiree")
	if _ferme:
		return
	if chemin == "":
		_confirmation.text = "L'IMAGE N'A PAS PU ÊTRE ÉCRITE"
		_confirmation.add_theme_color_override("font_color", Charte.ETAT_FAUTE)
		# Un échec ne se paie pas d'un verrou : on doit pouvoir réessayer.
		_exporte = false
	else:
		_confirmation.text = "IMAGE GARDÉE   ·   " + Exporteur.lisible(chemin)
		AudioManager.play_ui("ui_tampon")
	var tw := create_tween()
	Charte.animer(tw, _confirmation, "modulate:a", 0.0, 1.0, 0.25,
		Charte.Courbe.SORTIE)
	tw.tween_interval(D_CONFIRMATION)
	tw.tween_property(_confirmation, "modulate:a", 0.0, 0.4)


func fermer() -> void:
	if _ferme:
		return
	_ferme = true
	set_process_unhandled_input(false)
	var tw := create_tween()
	var premier := true
	for enfant in get_children():
		var c := enfant as CanvasItem
		if c == null:
			continue
		if not premier:
			tw.parallel()
		premier = false
		Charte.animer(tw, c, "modulate:a", c.modulate.a, 0.0, D_SORTIE,
			Charte.Courbe.ENTREE)
	tw.tween_callback(queue_free)
