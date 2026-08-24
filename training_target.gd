extends StaticBody2D
class_name TrainingTarget

const Charte := preload("res://charte.gd")

## Cible d'échauffement du bac à sable.
##
## Seul gameplay de l'attente : elle encaisse les tirs avec les effets d'impact
## existants et affiche les dégâts. Aucune vie, aucune destruction — elle est
## remise à sa place à chaque manche et se contente de compter.

const RADIUS := 22.0
## Au-delà, le cumul affiché repart de zéro : c'est un compteur de rafale, pas
## un score.
const RESET_DELAY := 3.0

var total_damage: int = 0

var _idle: float = 0.0
var _label: Label
var _ring: Node2D

func _ready() -> void:
	collision_layer = MapGeometry.WALL_LAYER
	collision_mask = 0
	z_index = 5

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

	# Éclairée comme un mur : elle n'apparaît que dans le faisceau, le bac à
	# sable garde l'ambiance du jeu.
	_ring = Node2D.new()
	_ring.light_mask = MapGeometry.WALL_LAYER
	_ring.set_script(preload("res://training_target_visual.gd"))
	add_child(_ring)

	# L'occluder évite que la cible soit un trou de lumière au milieu de l'arène.
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var ang := (i / 16.0) * TAU
		pts.append(Vector2(cos(ang), sin(ang)) * RADIUS)
	poly.polygon = pts
	poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
	occ.occluder = poly
	occ.occluder_light_mask = MapGeometry.WALL_LAYER
	add_child(occ)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(160, 30)
	_label.position = Vector2(-80, -70)
	_label.add_theme_font_size_override("font_size", Charte.T_APPUI)
	_label.add_theme_color_override("font_color", Charte.AMBRE)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Charte.NOIR)
	var lbl_mat := CanvasItemMaterial.new()
	lbl_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_label.material = lbl_mat
	_label.hide()
	add_child(_label)

func _process(delta: float) -> void:
	if total_damage <= 0:
		return
	_idle += delta
	if _idle >= RESET_DELAY:
		reset_damage()

## Enregistre un impact. Appelée par la balle, qui se charge des effets.
func register_training_hit(amount: int) -> void:
	total_damage += amount
	_idle = 0.0
	_label.text = "%d" % total_damage
	_label.show()

func reset_damage() -> void:
	total_damage = 0
	_idle = 0.0
	_label.hide()
