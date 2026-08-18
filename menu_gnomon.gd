class_name MenuGnomon
extends Control

## M1 — Le cadran de titre. Vague M, « la vitrine ».
##
## Derrière le titre du jeu, une ombre portée du mot lui-même : une copie noire,
## cisaillée et écrasée, projetée par une flamme hors champ. **L'angle de
## projection avance d'environ 6° par minute passée au menu.**
##
## Imperceptible en direct, flagrant au retour d'un match : le titre est un
## gnomon, le menu un cadran solaire. C'est une récompense d'attention pure —
## « tiens, l'ombre a bougé » — et cela installe l'idée qu'un monde éclaire ce
## menu depuis quelque part, ce qui est exactement le sujet du jeu.
##
## ## Pourquoi un `Timer` et pas `_process`
##
## Une ombre qui tourne de 6° par **minute** n'a rien à redessiner soixante fois
## par seconde : à 240 images, ce serait 14 400 dessins pour un déplacement que
## l'œil ne perçoit pas. Un redessin par seconde suffit et se voit tout autant.
##
## L'effet vit **hors du flux de mise en page** : ancré en plein cadre derrière
## le `Label`, il ne pousse rien et ne rétrécit rien.

## Degrés parcourus par minute passée au menu. Assez lent pour qu'un joueur ne
## puisse pas le voir bouger en le fixant, assez rapide pour qu'un match de cinq
## minutes le déplace visiblement.
const DEGRES_PAR_MINUTE := 6.0

## Angle de départ, en degrés depuis la verticale. La flamme est en haut à
## gauche : l'ombre part donc vers le bas à droite, comme un matin.
const ANGLE_INITIAL := -35.0

var _cible: Label
var _intensite: float = 1.0
var _ecoule: float = 0.0
var _horloge: Timer

func _init(cible: Label) -> void:
	name = "OmbreTitre"
	_cible = cible
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	# Le menu tourne parfois arbre en pause : un cadran gelé mentirait sur le
	# temps passé, ce qui est précisément ce qu'il mesure.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_horloge = Timer.new()
	_horloge.wait_time = 1.0
	_horloge.process_mode = Node.PROCESS_MODE_ALWAYS
	_horloge.timeout.connect(_avancer)
	add_child(_horloge)
	_horloge.start()

func _avancer() -> void:
	if not is_visible_in_tree() or _intensite <= 0.0:
		return
	_ecoule += 1.0
	queue_redraw()

## Réglage du joueur, de 0 (aucune ombre) à 1.
func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if _cible == null or _intensite <= 0.0 or _cible.text.is_empty():
		return
	var police := _cible.get_theme_font("font")
	var taille := _cible.get_theme_font_size("font_size")
	if police == null:
		return

	# L'ombre emprunte la couleur du titre pour son voile, mais assombrie : à
	# l'écran de fin, VICTOIRE et DÉFAITE projettent la leur, dans leur teinte.
	var teinte: Color = _cible.get_theme_color("font_color")
	var encre := Color(teinte.r * 0.25, teinte.g * 0.25, teinte.b * 0.25,
		0.45 * _intensite)

	var angle := deg_to_rad(ANGLE_INITIAL + _ecoule / 60.0 * DEGRES_PAR_MINUTE)
	var largeur := police.get_string_size(_cible.text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, taille).x
	var base := Vector2((size.x - largeur) * 0.5, size.y * 0.72)

	# Cisaillement horizontal + écrasement vertical : une ombre projetée au sol
	# n'est pas une copie translatée, elle est couchée.
	draw_set_transform_matrix(Transform2D(
		Vector2(1.0, 0.0),
		Vector2(sin(angle) * 1.6, 0.34),
		base))
	draw_string(police, Vector2.ZERO, _cible.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, taille, encre)
	draw_set_transform_matrix(Transform2D.IDENTITY)
