class_name MenuApercu
extends Control

## L'aperçu d'un mode, dans le cadre de droite.
##
## **Ce qui remplace le fond d'arène, et pourquoi c'est mieux.** Le cadre a
## d'abord porté la carte du prochain match, révélée par une torche qui dérivait.
## Adrien l'a écartée après trois passes, et le motif de l'abandon vaut plus que
## l'effet : *ce n'est pas ce qu'on veut voir en choisissant un mode.* Une arène
## vide dit où l'on jouera ; elle ne dit pas **à quoi ça ressemble d'y jouer**.
##
## Chaque entrée montre donc le mode **tel qu'il est une fois lancé** — écran
## scindé pour le duel local, écran seul pour le duel en ligne, la cible pour
## l'entraînement.
##
## ## Ce sont de VRAIES captures, et c'est la décision
##
## Aucune de ces images n'est générée. Elles sortent de `tools/fabrique_apercus.gd`,
## qui monte une vraie partie et la photographie. **Une illustration d'un mode de
## jeu est une promesse ; une capture est un constat** — et le jour où le jeu
## change, une illustration ment sans prévenir alors qu'une capture se recuit.
##
## C'est le même raisonnement que pour la vignette de carte : le plan de l'arène
## n'est pas dessiné, il est rendu.
##
## ## Ce que ce nœud ne fait pas
##
## Il ne connaît **aucun mode**, aucun écran, aucun identifiant. On lui donne un
## chemin d'image, il la montre ou il se tait. Le rattachement entre un écran et
## son aperçu vit dans `ui.gd`, avec le reste de la table des écrans — mettre
## cette table ici obligerait ce fichier à savoir ce qu'est le jeu.

const Charte := preload("res://charte.gd")

var _image: TextureRect
var _absent: Label


func _init(chemin: String = "") -> void:
	name = "PanneauApercu"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Le cadre est large ; sans plancher, un `Control` nu ne réserve rien et
	# l'aperçu se réduit à un trait. Défaut déjà payé par la galerie de cartes.
	custom_minimum_size = Vector2(0, 300)

	_image = TextureRect.new()
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ⚠️ `EXPAND_KEEP_SIZE` est le défaut et impose la taille de la texture comme
	# taille minimale du contrôle : une capture de 1280 px pousserait le cadre
	# hors de l'écran. Piège payé par DA1 le 2026-08-24.
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# `KEEP_ASPECT_COVERED` et non `SCALE` : une capture de jeu déformée se
	# reconnaît immédiatement, et c'est le défaut le plus visible qu'on puisse
	# poser sur une image censée montrer le jeu tel qu'il est.
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.clip_contents = true
	add_child(_image)

	# Règle du dépôt — câbler, taire, diagnostiquer : une capture pas encore cuite
	# ne casse rien et ne se tait pas non plus. Elle le DIT, ici, plutôt que de
	# laisser un rectangle noir qu'on prendrait pour un défaut d'affichage.
	_absent = Label.new()
	_absent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_absent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_absent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Charte.appareil(_absent, Charte.T_MENTION)
	_absent.add_theme_color_override("font_color", Charte.LINE)
	_absent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_absent.hide()
	add_child(_absent)

	if chemin != "":
		poser(chemin)


## Pose une capture. Chemin vide ou fichier absent : le panneau le dit.
func poser(chemin: String) -> void:
	if chemin != "" and ResourceLoader.exists(chemin):
		_image.texture = load(chemin)
		_image.show()
		_absent.hide()
		return
	_image.texture = null
	_image.hide()
	_absent.text = "Aperçu à cuire — ./tools/run_apercus.sh"
	_absent.show()


## La capture actuellement posée, ou `null`. Les bancs le lisent : une image
## absente et une image noire se ressemblent trop pour qu'on les distingue à
## l'œil, et c'est précisément ce qu'un contrôle doit trancher.
func texture() -> Texture2D:
	return _image.texture
