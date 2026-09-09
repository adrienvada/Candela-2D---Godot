class_name IntroPlanches
extends CanvasLayer

## DA6.6 — l'intro en six planches de bande dessinée.
##
## Un homme arrive dans un lieu souterrain sans qu'on sache pourquoi, s'équipe,
## allume sa torche, et découvre que le faisceau qui lui montre l'adversaire
## dessine son ombre sur le mur. Le storyboard complet est dans
## `docs/INTRO_PLANCHES.md` ; ce fichier ne fait que le jouer.
##
## ## Trois choix qui ne se devinent pas
##
## **Aucun système neuf.** Le cadre d'encre est `menu_comic_panel.gd`, la percée
## des hautes lumières est `menu_artwork.gdshader`, les poussières de faisceau
## sont `menu_particles_ambiance.gd` — tous écrits pour les menus, tous réemployés
## tels quels. Les six planches n'ajoutent que douze lignes de dictionnaire dans
## `menu_artwork.gd` et six dans `menu_particles_ambiance.gd` : **zéro
## `EffectMode` neuf.** Un effet taillé pour six images vues quinze secondes
## serait du code que personne ne rejuge jamais.
##
## **L'intro s'éclaire, elle ne se regarde pas.** Le curseur pilote `torch_pos`
## du shader, exactement comme dans le hub : chaque planche s'ouvre presque noire
## et se lit là où le joueur passe le faisceau. Le verbe du jeu — *éclairer pour
## voir* — s'apprend avant le premier match, sans une ligne de tutoriel.
##
## **Elle se passe à la moindre touche, et elle ne se rejoue pas toute seule.**
## Une intro non passable contredit « immédiat, intuitif, addictif » ; une intro
## qui revient à chaque lancement est pire. `GameSettings.intro_vue` retient
## qu'elle a été jouée, et le menu peut la redemander.
##
## ⚠️ **`process_mode` vaut ALWAYS et la couche est au-dessus de l'interface.**
## Sans le premier, une pause posée par autre chose gèlerait la séquence sans
## rien dire ; sans le second, le HUD de `ui.gd` (lui aussi un `CanvasLayer`)
## passerait par-dessus les planches.

signal terminee

const Charte := preload("res://charte.gd")

## La couche : au-dessus de `ui.gd`, qui vit en couche 1 par défaut.
const COUCHE := 128

## Durée d'affichage d'une planche, fondu compris. Six planches font donc ~15 s
## — voir `docs/INTRO_PLANCHES.md`, section « Cadence et règles ».
const DUREE_PLANCHE := 2.5

## Le fondu d'entrée d'une planche. Court : c'est une coupe de bande dessinée,
## pas un fondu de cinéma.
const DUREE_FONDU := 0.45

## Les six planches, dans l'ordre. Le texte gravé n'apparaît que sur deux
## d'entre elles : le jeu n'a pas de lore écrit, et une intro bavarde lui en
## inventerait un.
const PLANCHES: Array[Dictionary] = [
	{"image": "res://assets/ui/ill_intro_descente.png", "texte": ""},
	{"image": "res://assets/ui/ill_intro_seuil.png", "texte": ""},
	{"image": "res://assets/ui/ill_intro_dotation.png", "texte": ""},
	{"image": "res://assets/ui/ill_intro_allumage.png", "texte": ""},
	{"image": "res://assets/ui/ill_intro_prix.png", "texte": "VOIR SANS ÊTRE VU."},
	{"image": "res://assets/ui/ill_intro_extinction.png", "texte": "TUER SANS ÊTRE TUÉ."},
]

var _fond: ColorRect
var _image: TextureRect
var _cadre: MenuComicPanel
var _particules: MenuParticlesAmbiance
var _lettrage: Label
var _indice: Label

var _index := -1
var _reste := 0.0
var _temps := 0.0
var _en_cours := false
var _fondu: Tween

## Vrai si les six planches sont présentes sur le disque.
##
## Existe pour que le jeu démarre normalement chez qui n'a pas encore les images
## — une installation sans elles doit ouvrir sur le menu, pas sur un écran noir
## de quinze secondes. Le contrôle porte sur TOUTES les planches : une séquence
## amputée raconterait autre chose que ce qui a été écrit.
static func disponible() -> bool:
	for planche in PLANCHES:
		if not ResourceLoader.exists(String(planche.get("image", ""))):
			return false
	return true

func _init() -> void:
	name = "IntroPlanches"
	layer = COUCHE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construire()
	set_process(false)

func _construire() -> void:
	_fond = ColorRect.new()
	_fond.name = "Fond"
	_fond.color = Charte.NOIR
	_fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fond)

	_image = TextureRect.new()
	_image.name = "Planche"
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# COVER et non SCALE : les planches sont en 16:10 et l'écran ne l'est pas.
	# Étirer déformerait un dessin ; couvrir en perd les bords, ce qui est le
	# moindre mal — le storyboard cadre exprès son sujet loin des bords.
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.material = _fabriquer_materiau()
	_image.modulate.a = 0.0
	add_child(_image)

	_particules = MenuParticlesAmbiance.new()
	_particules.name = "ParticulesIntro"
	_particules.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_particules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particules)

	_cadre = MenuComicPanel.new()
	add_child(_cadre)

	_lettrage = Label.new()
	_lettrage.name = "Lettrage"
	_lettrage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lettrage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lettrage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lettrage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lettrage.add_theme_color_override("font_color", Charte.HALOGENE)
	_lettrage.add_theme_font_size_override("font_size", 56)
	_lettrage.modulate.a = 0.0
	add_child(_lettrage)

	# L'indice de sortie est permanent : un joueur qui veut passer doit le savoir
	# à la première seconde, pas à la quinzième.
	_indice = Label.new()
	_indice.name = "IndicePasser"
	_indice.text = "UNE TOUCHE POUR PASSER"
	_indice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_indice.offset_left = -360.0
	_indice.offset_top = -56.0
	_indice.offset_right = -Charte.GAP_L
	_indice.offset_bottom = -Charte.GAP_L
	_indice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_indice.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_indice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indice.add_theme_color_override("font_color", Charte.DIM)
	_indice.add_theme_font_size_override("font_size", 14)
	add_child(_indice)

func _fabriquer_materiau() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := load("res://menu_artwork.gdshader") as Shader
	if shader == null:
		return mat
	mat.shader = shader
	# `mode_flou_total` à 0 : une planche d'intro est le sujet, pas un lit
	# d'ambiance derrière un panneau. C'est la seule différence de réglage avec
	# le fond du hub.
	mat.set_shader_parameter("mode_flou_total", 0.0)
	mat.set_shader_parameter("ambient_exposure", 0.28)
	mat.set_shader_parameter("torch_radius", 0.45)
	mat.set_shader_parameter("torch_intensity", 1.0)
	mat.set_shader_parameter("reveal_progress", 1.0)
	mat.set_shader_parameter("effect_strength", 1.0)
	return mat

# ---------------------------------------------------------------------------
# Déroulé
# ---------------------------------------------------------------------------

## Joue la séquence. Rend la main immédiatement : c'est `terminee` qui dit la fin.
func jouer() -> void:
	if _en_cours:
		return
	_en_cours = true
	_index = -1
	_temps = 0.0
	show()
	set_process(true)
	_planche_suivante()

## Vrai si la séquence est en train de se jouer.
func en_cours() -> bool:
	return _en_cours

func _planche_suivante() -> void:
	_index += 1
	if _index >= PLANCHES.size():
		_terminer()
		return

	var planche: Dictionary = PLANCHES[_index]
	var chemin := String(planche.get("image", ""))
	# Une planche absente ne doit pas figer l'intro sur un écran noir : on saute.
	# Le cas se produit chez qui n'a pas encore les images, pas chez un joueur.
	if not ResourceLoader.exists(chemin):
		push_warning("IntroPlanches : planche absente, sautée — " + chemin)
		_planche_suivante()
		return

	_image.texture = load(chemin) as Texture2D
	var cle := MenuArtwork.cle_canonique(chemin)
	var mat := _image.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("torch_pos", MenuArtwork.poi_pour(cle))
		mat.set_shader_parameter("effect_mode", MenuArtwork.effet_pour(cle))
	if _particules != null:
		_particules.definir_illustration(cle)

	_lettrage.text = String(planche.get("texte", ""))
	_reste = DUREE_PLANCHE

	if _fondu != null and _fondu.is_valid():
		_fondu.kill()
	_image.modulate.a = 0.0
	_lettrage.modulate.a = 0.0
	_fondu = create_tween()
	_fondu.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fondu.set_parallel(true)
	Charte.animer(_fondu, _image, "modulate:a", 0.0, 1.0, DUREE_FONDU, Charte.Courbe.ENTREE)
	if _lettrage.text != "":
		# Le lettrage entre APRÈS l'image : on lit d'abord ce que la case montre,
		# la phrase ne fait que nommer ce qu'on vient de comprendre.
		Charte.animer(_fondu, _lettrage, "modulate:a", 0.0, 1.0, DUREE_FONDU, Charte.Courbe.ENTREE) \
			.set_delay(DUREE_FONDU)
	if _cadre != null:
		_cadre.reveler(1.0, DUREE_FONDU)

func _process(delta: float) -> void:
	if not _en_cours:
		return
	_temps += delta
	var mat := _image.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("effect_time", _temps)
		# La torche suit le curseur, en coordonnées normalisées de l'écran —
		# le même geste que dans le hub, sur la même uniforme.
		var taille := get_viewport().get_visible_rect().size
		if taille.x > 0.0 and taille.y > 0.0:
			var souris := get_viewport().get_mouse_position()
			mat.set_shader_parameter("torch_pos", souris / taille)
	if _cadre != null:
		_cadre.set_torch_position_global(get_viewport().get_mouse_position())
	_reste -= delta
	if _reste <= 0.0:
		_planche_suivante()

## Toute touche, tout bouton de souris, tout bouton de manette passe l'intro.
##
## `_unhandled_input` et non `_input` : l'intro ne mange pas les événements que
## quelque chose d'autre aurait déjà traités. Et on filtre sur les APPUIS — un
## mouvement de souris ne doit pas passer une intro qu'on éclaire justement à la
## souris.
func _unhandled_input(event: InputEvent) -> void:
	if not _en_cours:
		return
	var appui := false
	if event is InputEventKey:
		appui = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		appui = event.pressed
	elif event is InputEventJoypadButton:
		appui = event.pressed
	if appui:
		get_viewport().set_input_as_handled()
		_terminer()

func _terminer() -> void:
	if not _en_cours:
		return
	_en_cours = false
	set_process(false)
	if _fondu != null and _fondu.is_valid():
		_fondu.kill()
	hide()
	terminee.emit()
