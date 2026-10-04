class_name AventureCarton
extends CanvasLayer

## Le CARTON de l'aventure — chantier SOLO, S6 : ce que le joueur lit entre deux salles.
##
## Un fond noir, le numéro de la salle, son titre, sa phrase d'intention. Il couvre l'écran pendant que la salle suivante se
## construit derrière lui, et se retire en fondu sur son dernier instant. Il a été « le SEUL endroit où l'aventure parle » (S6 :
## « aucun texte pendant le jeu ») jusqu'au 2026-10-04 : depuis, `AventureHud` porte pendant le jeu les consignes de l'initiation
## (les touches, à la demande d'Adrien), le compteur des silhouettes et le tampon de la salle réussie.
##
## Il ne décide de rien : `AventurePartie` le montre, le règle (`regler`) et le retire. Il ne touche ni au temps ni au jeu — c'est
## `GameState.countdown_left` qui fige les joueurs pendant qu'il est là, comme un décompte de manche.
##
## Le nœud porte un nom (`CartonAventure`), comme tout nœud ajouté dynamiquement.

const Charte := preload("res://charte.gd")

## Au-dessus de l'interface (10), de l'estampe de kill (95 est plus haut : il n'y en a pas ici) et du brouillage (1).
const CALQUE := 90
## La part finale de la durée pendant laquelle le carton s'efface.
const PART_DU_FONDU := 0.2

var _fond: ColorRect
var _boite: VBoxContainer
var _entete: Label
var _titre: Label
var _phrase: Label


func _init() -> void:
	name = "CartonAventure"
	layer = CALQUE
	visible = false
	_fond = ColorRect.new()
	_fond.name = "Fond"
	_fond.color = Charte.NOIR
	_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fond)
	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	_boite = VBoxContainer.new()
	_boite.name = "Boite"
	_boite.alignment = BoxContainer.ALIGNMENT_CENTER
	_boite.add_theme_constant_override("separation", 18)
	_boite.custom_minimum_size = Vector2(900, 0)
	centre.add_child(_boite)
	_entete = _etiquette("Entete", Charte.T_APPUI, Charte.AMBRE, Charte.POIDS_APPUI)
	_titre = _etiquette("Titre", Charte.T_ENSEIGNE, Charte.HALOGENE, Charte.POIDS_ENSEIGNE)
	_phrase = _etiquette("Phrase", Charte.T_TITRE, Charte.PAPIER, Charte.POIDS_COURANT)
	_phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _etiquette(nom: String, taille: int, couleur: Color, poids: int) -> Label:
	var l := Label.new()
	l.name = nom
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var reglage := LabelSettings.new()
	reglage.font = Charte.police_display(poids)
	reglage.font_size = taille
	reglage.font_color = couleur
	l.label_settings = reglage
	_boite.add_child(l)
	return l


## Pose le texte du carton et le montre, opaque.
func montrer(entete: String, titre: String, phrase: String) -> void:
	_entete.text = entete
	_titre.text = titre
	_phrase.text = phrase
	_phrase.visible = phrase != ""
	regler(1.0)
	visible = true


func cacher() -> void:
	visible = false


## `restant` : la part de la durée du carton qu'il reste, de 1 (début) à 0 (fin). Il s'efface sur la dernière `PART_DU_FONDU`.
func regler(restant: float) -> void:
	var alpha := clampf(restant / PART_DU_FONDU, 0.0, 1.0)
	_fond.modulate.a = alpha
	_boite.modulate.a = alpha


## Ce qu'il dit, pour les suites.
func texte() -> Dictionary:
	return {"entete": _entete.text, "titre": _titre.text, "phrase": _phrase.text}
