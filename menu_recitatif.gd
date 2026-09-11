class_name MenuRecitatif
extends PanelContainer
## Le RÉCITATIF — la case de texte d'une planche de bande dessinée, pour
## nommer l'écran du menu (Adrien, 2026-09-11 : « partons sur la 4 »).
##
## ## Ce qu'il remplace, et pourquoi
##
## Chaque écran du hub portait un titre en IMAGE (`assets/ui/titres/`) :
## quinze lettrages générés, dorés, biseautés, tramés, chacun composé à sa
## façon, peints à 1 300 px et affichés à 48 — vingt-sept fois réduits, le
## biseau devenait de la boue dorée, et le tout parlait une autre langue que
## le menu (Oxanium fin, aplats, filets d'un pixel). C'était le dernier
## élément « généré » d'une interface passée à l'encre.
##
## ## Ce que c'est
##
## Le code le plus lisible du roman graphique, et il n'existait nulle part
## dans le menu : un rectangle à bord d'encre, fond papier, capitales noires
## dans la fonte d'enseigne. Un seul système pour les quinze écrans, aucune
## image. Le papier est l'halogène de la charte — « tout blanc cassé » —, le
## bord et les lettres son noir. Une ombre portée franche, comme les panneaux
## de `menu_widgets.gd` : elle ne se voit que là où la case déborde sur autre
## chose que le noir, et c'est bien ainsi.

const Charte := preload("res://charte.gd")

## Le papier : l'halogène, seul blanc de la charte.
const PAPIER := Charte.HALOGENE
## L'épaisseur du bord d'encre, en pixels.
const BORD := 3
## La taille des capitales. 26 : deux points sous `T_TITRE` + 1, pour que
## « 1V1 ÉCRANS SCINDÉS » tienne sur une ligne dans la colonne de 430 px.
const TAILLE := 26

var _label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = PAPIER
	style.set_border_width_all(BORD)
	style.border_color = Charte.NOIR
	style.set_corner_radius_all(0)
	style.shadow_size = 0
	style.shadow_offset = Vector2(5, 5)
	style.shadow_color = Color(Charte.NOIR, 0.9)
	style.content_margin_left = Charte.GAP_S
	style.content_margin_right = Charte.GAP_S
	style.content_margin_top = Charte.GAP_XXS
	style.content_margin_bottom = Charte.GAP_XXS
	add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.name = "Texte"
	Charte.enseigne(_label, TAILLE)
	_label.add_theme_color_override("font_color", Charte.NOIR)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


## Le nom de l'écran, en capitales.
func poser(texte: String) -> void:
	_label.text = texte.to_upper()


func texte() -> String:
	return _label.text
