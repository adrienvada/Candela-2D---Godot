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

## Écrasement vertical de l'ombre. Une ombre portée n'est pas une copie
## translatée : elle est couchée.
##
## **Valait 0,34, calibré contre une fonte large.** L'enseigne est passée en
## Big Shoulders, ultra-condensée : à 0,34, la copie couchée n'avait plus assez
## d'encre pour se lire comme un mot — elle devenait un trait. Une même valeur
## d'écrasement ne dit pas la même chose selon la chasse de la fonte.
const ECRASEMENT := 0.55

## Cisaillement horizontal, en part de la hauteur. C'est lui qui couche l'ombre
## du côté opposé à la flamme.
const CISAILLEMENT := 1.6

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

	# L'ombre part des PIEDS DU MOT, pas d'une fraction du cadre.
	#
	# ⚠️ **Elle partait de `size.y * 0.72`** — 72 % de la hauteur du conteneur,
	# une valeur qui tombait juste tant que le titre était en fonte par défaut à
	# 60 px. La charte l'a passé en Big Shoulders à 68, dont les métriques n'ont
	# rien à voir : l'ombre s'est retrouvée AU-DESSUS du mot, et ne se lisait plus
	# comme une ombre mais comme une bavure d'affichage.
	#
	# C'est le motif de DA5.8 en un seul effet : la vague M a été calibrée contre
	# une typographie qui n'existe plus. Ancrée au rectangle réel de la cible,
	# elle suit désormais n'importe quelle fonte et n'importe quelle taille.
	var cadre := _cible.get_rect()
	var base := Vector2(
		cadre.position.x + (cadre.size.x - largeur) * 0.5,
		cadre.position.y + police.get_ascent(taille))

	# Cisaillement horizontal + écrasement vertical : une ombre projetée au sol
	# n'est pas une copie translatée, elle est couchée.
	draw_set_transform_matrix(Transform2D(
		Vector2(1.0, 0.0),
		Vector2(sin(angle) * CISAILLEMENT, ECRASEMENT),
		base))
	draw_string(police, Vector2.ZERO, _cible.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, taille, encre)
	draw_set_transform_matrix(Transform2D.IDENTITY)
