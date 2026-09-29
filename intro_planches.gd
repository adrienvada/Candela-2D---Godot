class_name IntroPlanches
extends CanvasLayer

## L'intro v2, récit A « Qui allume se montre » (choisi par Adrien le 2026-09-28,
## refait le 2026-09-29 : « les animations ne sont pas réalistes, pas cohérentes »).
##
## Un mannequin allume sa torche pour chercher l'autre, et c'est ce qui le perd :
## la règle du jeu en dix-sept plans, quatre mots gravés et le titre. Storyboard,
## sources et fabrication : `docs/INTRO_PLANCHES.md`.
##
## ## Un film, pas des planches
##
## L'intro est UN fichier, `intro_a.ogv` (Theora + Vorbis), image ET son, monté
## par `tools/monter_intro.py`. Pourquoi pas dix-sept vidéos enchaînées : les
## coupes tombent sur les mesures de la musique (170 BPM), et la musique traverse
## les plans. Deux lecteurs qui se relaient perdent une image à chaque raccord et
## décalent le son ; un seul film ne peut pas se désynchroniser de lui-même.
##
## Le film porte donc sa propre bande son : pendant qu'il joue, la musique du jeu
## est SUSPENDUE (`AudioManager.suspendre_musique`), puis reprend où elle était.
##
## ## Le repli
##
## `PLANS` décrit le même découpage que le film. Il sert quand le film manque (une
## installation amputée, un format que la plateforme ne lit pas) : une image par
## plan (`assets/ui/intro/`, tirée du film par le monteur, textes et titre
## compris) défile en coupes franches à la même cadence. Muet : la musique du jeu
## continue. `tools/test_intro_planches.gd` vérifie que les deux découpages sont
## d'accord.
##
## ## Ce qui n'a pas changé
##
## - **N'importe quelle touche la passe**, bouton de souris ou de manette compris ;
##   **un mouvement de souris, non**.
## - Jouée une fois (`GameSettings.intro_vue`, posé au DÉMARRAGE par GameState),
##   rejouable depuis l'accueil. Le nom du nœud (`IntroPlanches`) et le signal
##   `terminee` sont lus ailleurs (GameState, bancs).

signal terminee

const Charte := preload("res://charte.gd")

## La couche : au-dessus de `ui.gd`, qui vit en couche 1 par défaut.
const COUCHE := 128

## Une mesure de la musique du jeu : 170 BPM, quatre temps.
const MESURE := 60.0 / 170.0 * 4.0

## Le film, image et son.
const FILM := "res://assets/video/intro/intro_a.ogv"

## Le découpage, dans l'ordre. `mesures` : la durée ; `image` : l'image de repli
## (vide = noir). Les quatre mots et le titre sont des plans comme les autres.
## ⚠️ Le même que `PLANS` dans `tools/monter_intro.py` — la suite le vérifie.
const PLANS: Array[Dictionary] = [
	{"nom": "noir", "mesures": 1, "image": ""},
	{"nom": "le pouce", "mesures": 1, "image": "res://assets/ui/intro/intro_a_p02.jpg"},
	{"nom": "le couloir", "mesures": 2, "image": "res://assets/ui/intro/intro_a_p03.jpg"},
	{"nom": "VOIR", "mesures": 1, "image": "res://assets/ui/intro/intro_a_p04.jpg"},
	{"nom": "le pilier", "mesures": 2, "image": "res://assets/ui/intro/intro_a_p05.jpg"},
	{"nom": "la tête", "mesures": 1, "image": "res://assets/ui/intro/intro_a_p06.jpg"},
	{"nom": "le chasseur", "mesures": 1, "image": "res://assets/ui/intro/intro_a_p07.jpg"},
	{"nom": "SANS ÊTRE VU.", "mesures": 1, "image": "res://assets/ui/intro/intro_a_p08.jpg"},
	{"nom": "la main", "mesures": 1, "image": "res://assets/ui/intro/intro_a_p09.jpg"},
	{"nom": "le pilier, vu par J1", "mesures": 1, "image": "res://assets/ui/intro/intro_a_p10.jpg"},
	{"nom": "la sortie", "mesures": 2, "image": "res://assets/ui/intro/intro_a_p11.jpg"},
	{"nom": "TUER", "mesures": 1, "image": "res://assets/ui/intro/intro_a_p12.jpg"},
	{"nom": "la main s'ouvre", "mesures": 1, "image": "res://assets/ui/intro/intro_a_p13.jpg"},
	{"nom": "la torche roule", "mesures": 2, "image": "res://assets/ui/intro/intro_a_p14.jpg"},
	{"nom": "le pied", "mesures": 1, "image": "res://assets/ui/intro/intro_a_p15.jpg"},
	{"nom": "SANS ÊTRE TUÉ.", "mesures": 2, "image": "res://assets/ui/intro/intro_a_p16.jpg"},
	{"nom": "CANDELA", "mesures": 4, "image": "res://assets/ui/intro/intro_a_p17.jpg"},
]

## Marge avant de rendre la main si le film ne signale jamais sa fin.
const MARGE_FIN := 1.5

## Outil et bancs : ignorer le film et jouer le repli.
var sans_film := false

var _video: VideoStreamPlayer
var _image: TextureRect
var _indice: Label

var _en_cours := false
var _avec_film := false
var _musique_suspendue := false
var _index := -1
var _reste := 0.0
var _ecoule := 0.0
var _zoom: Tween


## La durée du film, en secondes : la somme des mesures.
static func duree_totale() -> float:
	var mesures := 0
	for plan in PLANS:
		mesures += int(plan.get("mesures", 0))
	return mesures * MESURE


## Vrai si l'intro a de quoi jouer : le film, ou toutes les images de repli.
## Une installation qui n'a ni l'un ni les autres ouvre sur le menu, jamais sur
## vingt-cinq secondes de noir.
static func disponible() -> bool:
	return ResourceLoader.exists(FILM) or repli_complet()


## Vrai si toutes les images de repli sont présentes.
static func repli_complet() -> bool:
	for plan in PLANS:
		var chemin := String(plan.get("image", ""))
		if chemin != "" and not ResourceLoader.exists(chemin):
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
	var fond := ColorRect.new()
	fond.name = "Fond"
	fond.color = Charte.NOIR
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fond)

	# Le film est en 16:9. Une fenêtre d'un autre format le reçoit entier, entre
	# deux bandes noires, plutôt qu'étiré : un mannequin déformé serait le premier
	# défaut que l'intro montre.
	var cadre := AspectRatioContainer.new()
	cadre.name = "Cadre16x9"
	cadre.ratio = 16.0 / 9.0
	cadre.stretch_mode = AspectRatioContainer.STRETCH_FIT
	cadre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cadre)

	var scene := Control.new()
	scene.name = "Scene"
	scene.clip_contents = true
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(scene)

	_image = TextureRect.new()
	_image.name = "ImageRepli"
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.hide()
	scene.add_child(_image)

	_video = VideoStreamPlayer.new()
	_video.name = "Film"
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video.expand = true
	_video.loop = false
	_video.volume_db = 0.0
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.hide()
	_video.finished.connect(_terminer)
	scene.add_child(_video)

	# Indice permanent de sortie immédiate, hors du cadre 16:9.
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
	_indice.add_theme_color_override("font_color", Charte.PATE_TEXTE_SECOND)
	_indice.add_theme_font_size_override("font_size", Charte.T_COURANT)
	add_child(_indice)


# ---------------------------------------------------------------------------
# Déroulé
# ---------------------------------------------------------------------------

## Joue l'intro : le film s'il est là, sinon le repli.
func jouer() -> void:
	if _en_cours:
		return
	_en_cours = true
	_ecoule = 0.0
	_index = -1
	show()
	set_process(true)

	var flux: VideoStream = null
	if not sans_film and ResourceLoader.exists(FILM):
		flux = load(FILM) as VideoStream
	_avec_film = flux != null
	if _avec_film:
		_suspendre_musique(true)
		_video.stream = flux
		_video.show()
		_video.play()
	else:
		_plan_suivant()


## Vrai si la séquence est en cours de lecture.
func en_cours() -> bool:
	return _en_cours


## Vrai si c'est le film qui joue, faux pour le repli.
func joue_le_film() -> bool:
	return _en_cours and _avec_film


## Le plan en cours du repli (0 = le premier), -1 hors repli.
func plan_courant() -> int:
	return _index if _en_cours and not _avec_film else -1


func _plan_suivant() -> void:
	_index += 1
	if _index >= PLANS.size():
		_terminer()
		return
	var plan: Dictionary = PLANS[_index]
	_reste = int(plan.get("mesures", 1)) * MESURE

	# Coupes franches : c'est le montage du film, et c'est sur les temps.
	var chemin := String(plan.get("image", ""))
	_image.visible = chemin != "" and ResourceLoader.exists(chemin)
	if _image.visible:
		_image.texture = load(chemin) as Texture2D
		_image.pivot_offset = _image.size * 0.5
		_image.scale = Vector2.ONE
		if _zoom != null and _zoom.is_valid():
			_zoom.kill()
		_zoom = create_tween()
		_zoom.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_zoom.tween_property(_image, "scale", Vector2(1.05, 1.05), _reste)


func _process(delta: float) -> void:
	if not _en_cours:
		return
	_ecoule += delta
	if _avec_film:
		# `finished` suffit d'ordinaire ; cette borne rend la main si un flux
		# illisible ne le signale jamais.
		if _ecoule > duree_totale() + MARGE_FIN:
			_terminer()
		return
	_reste -= delta
	if _reste <= 0.0:
		_plan_suivant()


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
	if _zoom != null and _zoom.is_valid():
		_zoom.kill()
	_video.stop()
	_video.hide()
	_suspendre_musique(false)
	hide()
	terminee.emit()


## La musique du jeu se tait pendant le film, qui porte la sienne.
func _suspendre_musique(suspendre: bool) -> void:
	if suspendre == _musique_suspendue:
		return
	# Sous `--script`, les autoloads n'existent pas : l'intro joue sans eux.
	var am := _audio_manager()
	if am == null:
		return
	am.suspendre_musique(suspendre)
	_musique_suspendue = suspendre


func _audio_manager() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AudioManager")
