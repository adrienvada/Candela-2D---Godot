## MapEditorCamera — Caméra de l'éditeur de cartes.
##
## Trois comportements qui, ensemble, produisent la sensation de fluidité :
##   • lissage de position permanent (le cadrage « suit » au lieu de sauter) ;
##   • zoom borné, centré sur le point visé (molette ou gâchettes) ;
##   • défilement automatique quand le curseur d'édition approche du bord.
##
## Les limites sont calées sur la grille de la carte. Elles sont désactivées
## automatiquement sur un axe où la vue est plus large que la grille : sans
## cela, Godot plaquerait la carte contre un bord au lieu de la centrer.

class_name MapEditorCamera
extends Camera2D

## Bornes de zoom demandées par le design. 0.5 = vue large, 3.0 = très proche.
const ZOOM_MIN := 0.5
const ZOOM_MAX := 3.0
## Facteur multiplicatif d'un cran de molette.
const ZOOM_STEP := 1.14
## Crans par seconde quand une gâchette est maintenue.
const ZOOM_PAD_RATE := 6.0
## Vitesse de déplacement au stick droit, en pixels monde par seconde.
const PAN_PAD_SPEED := 1100.0
## Fraction de la vue considérée comme « bord » pour le défilement automatique.
const EDGE_MARGIN_RATIO := 0.16
## Rattrapage du bord : plus c'est haut, plus la caméra colle au curseur.
const EDGE_CATCH_UP := 12.0
## Marge autour de la grille, en tuiles.
const BOUNDS_PADDING_TILES := 2.0
## Au-delà, les limites d'un axe sont désactivées (la vue déborde la grille).
const LIMIT_DISABLED := 10_000_000

## Rectangle monde de la grille, marge comprise.
var _bounds := Rect2(Vector2.ZERO, Vector2(1120, 1120))
## Position visée. Camera2D lisse le rendu vers cette valeur.
var _target := Vector2.ZERO
var _zoom_level := 1.0

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	ignore_rotation = true
	limit_smoothed = true
	process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	make_current()

func _process(_delta: float) -> void:
	position = _clamp_to_bounds(_target)

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------

## Cale la caméra sur une grille. À rappeler à chaque changement de carte.
func configure(grid_size: Vector2i, tile_size: Vector2i) -> void:
	var world := _compute_bounds(grid_size, tile_size)

	set_zoom_level(fit_zoom())
	_target = world.get_center()
	position = _target
	reset_smoothing()

## Recalcule les limites sans toucher au cadrage courant.
## Utilisé pendant un redimensionnement de grille : agrandir la carte ne doit
## pas arracher la vue de l'endroit où l'on était en train de travailler.
func update_bounds(grid_size: Vector2i, tile_size: Vector2i) -> void:
	_compute_bounds(grid_size, tile_size)
	_apply_limits()

func _compute_bounds(grid_size: Vector2i, tile_size: Vector2i) -> Rect2:
	var padding := float(maxi(tile_size.x, tile_size.y)) * BOUNDS_PADDING_TILES
	var world := Rect2(Vector2.ZERO, Vector2(grid_size * tile_size))
	_bounds = world.grow(padding)
	return world

## Zoom qui fait tenir toute la grille à l'écran, dans les bornes autorisées.
func fit_zoom() -> float:
	var viewport := get_viewport_rect().size
	if _bounds.size.x <= 0.0 or _bounds.size.y <= 0.0:
		return 1.0
	var fit := minf(viewport.x / _bounds.size.x, viewport.y / _bounds.size.y)
	return clampf(fit, ZOOM_MIN, ZOOM_MAX)

## Recadre sur l'ensemble de la carte.
func frame_all() -> void:
	set_zoom_level(fit_zoom())
	_target = _bounds.get_center()

# ---------------------------------------------------------------------------
# ZOOM
# ---------------------------------------------------------------------------

func get_zoom_level() -> float:
	return _zoom_level

func set_zoom_level(value: float) -> void:
	_zoom_level = clampf(value, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2.ONE * _zoom_level
	_apply_limits()

## Zoom relatif. `steps` positif rapproche, négatif éloigne.
func zoom_by(steps: float) -> void:
	set_zoom_level(_zoom_level * pow(ZOOM_STEP, steps))

## Zoom en conservant `anchor` (monde) sous le même point de l'écran.
## C'est ce qui rend la molette naturelle : on zoome là où on regarde.
func zoom_towards(steps: float, anchor: Vector2) -> void:
	var previous := _zoom_level
	zoom_by(steps)
	if is_equal_approx(previous, _zoom_level):
		return
	var ratio := previous / _zoom_level
	_target = anchor + (_target - anchor) * ratio

# ---------------------------------------------------------------------------
# DÉPLACEMENT
# ---------------------------------------------------------------------------

## Déplacement direct, en unités monde (glisser à la souris).
func pan_by(world_delta: Vector2) -> void:
	_target += world_delta

## Déplacement au stick droit.
func pan_with_stick(direction: Vector2, delta: float) -> void:
	if direction.is_zero_approx():
		return
	_target += direction * PAN_PAD_SPEED * delta / _zoom_level

func center_on(world_position: Vector2, instant: bool = false) -> void:
	_target = world_position
	if instant:
		position = _clamp_to_bounds(_target)
		reset_smoothing()

## Défilement automatique : pousse le cadrage dès que le curseur d'édition
## entre dans la marge de bord. Sans cela, dessiner près du bord oblige à
## déplacer la caméra à la main tous les deux carreaux.
func follow_cursor(world_position: Vector2, delta: float) -> void:
	var view := get_viewport_rect().size / _zoom_level
	var margin := view * EDGE_MARGIN_RATIO
	var safe := Rect2(_target - view * 0.5 + margin, view - margin * 2.0)

	var push := Vector2.ZERO
	if world_position.x < safe.position.x:
		push.x = world_position.x - safe.position.x
	elif world_position.x > safe.end.x:
		push.x = world_position.x - safe.end.x
	if world_position.y < safe.position.y:
		push.y = world_position.y - safe.position.y
	elif world_position.y > safe.end.y:
		push.y = world_position.y - safe.end.y

	if push.is_zero_approx():
		return
	_target += push * clampf(EDGE_CATCH_UP * delta, 0.0, 1.0)

# ---------------------------------------------------------------------------
# BORNES
# ---------------------------------------------------------------------------

## Rectangle monde actuellement visible.
func visible_world_rect() -> Rect2:
	var view := get_viewport_rect().size / _zoom_level
	return Rect2(position - view * 0.5, view)

func _clamp_to_bounds(point: Vector2) -> Vector2:
	var half := get_viewport_rect().size / _zoom_level * 0.5
	var out := point
	out.x = _clamp_axis(point.x, _bounds.position.x + half.x, _bounds.end.x - half.x,
		_bounds.get_center().x)
	out.y = _clamp_axis(point.y, _bounds.position.y + half.y, _bounds.end.y - half.y,
		_bounds.get_center().y)
	return out

func _clamp_axis(value: float, low: float, high: float, fallback: float) -> float:
	# La vue déborde la grille sur cet axe : on centre au lieu de coincer.
	if low > high:
		return fallback
	return clampf(value, low, high)

## Ajuste limit_* : actives tant que la grille est plus grande que la vue.
func _apply_limits() -> void:
	var view := get_viewport_rect().size / _zoom_level

	if view.x < _bounds.size.x:
		limit_left = int(_bounds.position.x)
		limit_right = int(_bounds.end.x)
	else:
		limit_left = -LIMIT_DISABLED
		limit_right = LIMIT_DISABLED

	if view.y < _bounds.size.y:
		limit_top = int(_bounds.position.y)
		limit_bottom = int(_bounds.end.y)
	else:
		limit_top = -LIMIT_DISABLED
		limit_bottom = LIMIT_DISABLED
