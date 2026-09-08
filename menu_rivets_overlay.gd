class_name MenuRivetsOverlay
extends Control

## Décorateur graphique « Roman Graphique Brutaliste » — Tôles rivetées & Chevrons.
##
## Dessine sur les conteneurs (vignettes de cartes, profil, historique) :
## - Rivets d'acier aux coins (plaques blindées clandestines).
## - Bandes de chevrons d'avertissement diagonaux (noir d'encre / ambre ou acier).
## - Chanfreins et arêtes vives d'atelier.

const Charte := preload("res://charte.gd")

enum Style {
	RIVETS_SEULS = 0,
	CHEVRONS_HAUT = 1,
	CHEVRONS_GAUCHE = 2,
	TOLE_COMPLETE = 3,
}

@export var style: Style = Style.RIVETS_SEULS:
	set(v):
		style = v
		queue_redraw()

@export var rivet_size: float = 4.0:
	set(v):
		rivet_size = v
		queue_redraw()

@export var rivet_margin: float = 6.0:
	set(v):
		rivet_margin = v
		queue_redraw()

@export var chevrons_taille: float = 8.0:
	set(v):
		chevrons_taille = v
		queue_redraw()

@export var couleur_rivet: Color = Color(0.44, 0.48, 0.53):
	set(v):
		couleur_rivet = v
		queue_redraw()

@export var couleur_avertissement: Color = Color(0.96, 0.69, 0.24):
	set(v):
		couleur_avertissement = v
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	if anchor_right == 0.0 and anchor_bottom == 0.0 and size == Vector2.ZERO:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(func() -> void: queue_redraw())

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 10.0 or h <= 10.0:
		return

	# 1. Bandes de chevrons d'avertissement
	if style == Style.CHEVRONS_HAUT or style == Style.TOLE_COMPLETE:
		_draw_chevrons_h(Rect2(0, 0, w, chevrons_taille))
	if style == Style.CHEVRONS_GAUCHE or style == Style.TOLE_COMPLETE:
		_draw_chevrons_v(Rect2(0, 0, chevrons_taille, h))

	# 2. Rivets aux 4 coins (ou sur le pourtour)
	_draw_rivet(Vector2(rivet_margin, rivet_margin))
	_draw_rivet(Vector2(w - rivet_margin, rivet_margin))
	_draw_rivet(Vector2(w - rivet_margin, h - rivet_margin))
	_draw_rivet(Vector2(rivet_margin, h - rivet_margin))

	# Rivets médians si la pièce est large
	if w > 240.0:
		_draw_rivet(Vector2(w * 0.5, rivet_margin))
		_draw_rivet(Vector2(w * 0.5, h - rivet_margin))

func _draw_rivet(pos: Vector2) -> void:
	var s := rivet_size
	var r := Rect2(pos - Vector2(s * 0.5, s * 0.5), Vector2(s, s))
	# Ombre d'encre décalée
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.9))
	# Corps en acier riveté
	draw_rect(r, couleur_rivet)
	# Filet d'encre
	draw_rect(r, Color(0, 0, 0, 0.95), false, 1.0)
	# Reflet biseauté
	draw_line(r.position, r.position + Vector2(s * 0.5, 0), Charte.HALOGENE, 1.0)

func _draw_chevrons_h(rect: Rect2) -> void:
	var step := rect.size.y * 1.5
	draw_rect(rect, Charte.NOIR)
	var x := rect.position.x
	while x < rect.position.x + rect.size.x + step:
		var pts := PackedVector2Array([
			Vector2(x, rect.position.y),
			Vector2(x + step * 0.5, rect.position.y),
			Vector2(x, rect.position.y + rect.size.y),
			Vector2(x - step * 0.5, rect.position.y + rect.size.y),
		])
		draw_colored_polygon(pts, couleur_avertissement)
		x += step
	# Filet de séparation
	draw_line(Vector2(rect.position.x, rect.position.y + rect.size.y),
		Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y),
		Charte.NOIR, 1.5)

func _draw_chevrons_v(rect: Rect2) -> void:
	var step := rect.size.x * 1.5
	draw_rect(rect, Charte.NOIR)
	var y := rect.position.y
	while y < rect.position.y + rect.size.y + step:
		var pts := PackedVector2Array([
			Vector2(rect.position.x, y),
			Vector2(rect.position.x + rect.size.x, y + step * 0.5),
			Vector2(rect.position.x + rect.size.x, y + step),
			Vector2(rect.position.x, y + step * 0.5),
		])
		draw_colored_polygon(pts, couleur_avertissement)
		y += step
	# Filet de séparation
	draw_line(Vector2(rect.position.x + rect.size.x, rect.position.y),
		Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y),
		Charte.NOIR, 1.5)
