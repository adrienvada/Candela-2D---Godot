extends Node2D
class_name KillShockwave

## V2.4 — Onde de choc du kill.
##
## Au kill, un double anneau lumineux part du corps de la victime et traverse
## l'arène : un front blanc-doré vif doublé d'un halo rouge intérieur. Le
## POURQUOI : dans un jeu où la seule information est la lumière, le kill est
## le seul événement autorisé à illuminer toute l'arène — l'onde ponctue
## l'instant décisif et le rend lisible depuis n'importe où, sur les deux
## écrans (zone franche : la manche est finie, le budget perf est libre).
##
## Instancié par GameState : position posée sur la victime, ajouté à l'arène.
## Autonome — il s'anime, se redessine et se libère tout seul.
##
## Aucune PointLight2D : sous gl_compatibility une grande lumière ponctuelle
## recalculerait les ombres de toute l'arène ; le dessin additif non éclairé
## donne le même « flash » sans toucher au pipeline lumière. Corollaire
## assumé : l'onde traverse les murs — c'est une ponctuation, pas une source
## d'information tactique (le duel est déjà tranché).

## Durée totale et portée du front. 1200 px couvrent l'arène entière depuis
## n'importe quel point : l'onde meurt hors champ, jamais visible en train de
## « s'arrêter ».
const DURATION := 0.4
const MAX_RADIUS := 1200.0

## ~96 segments : cercle lisse même à pleine taille, coût de tracé trivial.
## draw_arc compte des POINTS : n segments = n + 1 points, le dernier venant
## refermer l'anneau sur le premier.
const SEGMENTS := 96

## Le front s'amincit en avançant : épais et brutal au départ, filiforme à
## l'arrivée — l'énergie se dilue avec la distance.
const WIDTH_START := 16.0
const WIDTH_END := 2.0

## Anneau intérieur : il traîne à 92 % du rayon, plus large et plus faible —
## un halo rouge qui épaissit le front doré sans le concurrencer.
const INNER_RADIUS_RATIO := 0.92
const INNER_WIDTH_RATIO := 1.75
const INNER_ALPHA := 0.4

## Composantes sur-unitaires comme le Core des balles (bullet.gd) : en blend
## additif elles saturent vers le blanc au départ — c'est le « vif » voulu —
## et l'alpha mourant ramène naturellement la teinte dorée sous-jacente.
const OUTER_COLOR := Color(1.8, 1.5, 0.8)
const INNER_COLOR := Color(1.0, 0.12, 0.08)

var _age := 0.0

# Matériau additif non éclairé, identique pour toutes les ondes (même idiome
# que Bullet._additive_material : partagé en static, jamais ré-alloué).
static var _shared_additive: CanvasItemMaterial

static func _additive_material() -> CanvasItemMaterial:
	if _shared_additive == null:
		_shared_additive = CanvasItemMaterial.new()
		_shared_additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_shared_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _shared_additive

func _ready() -> void:
	# Au-dessus des joueurs (10) et des chiffres de dégâts (100) : l'onde EST
	# l'événement, rien ne doit la recouvrir.
	z_index = 150
	material = _additive_material()
	# visibility_layer et light_mask restent aux valeurs par défaut : l'onde
	# doit être vue des DEUX viewports (elle n'appartient à aucun joueur), et
	# le matériau unshaded ignore de toute façon les lumières.
	queue_redraw()

func _process(delta: float) -> void:
	# _process et non _physics_process : effet purement visuel, autant le lier
	# à la cadence de rendu (les fps sont déplafonnés).
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_age / DURATION, 0.0, 1.0)
	# Ease-out cubique sur le rayon : le front jaillit du corps puis décélère,
	# comme une détonation — un rayon linéaire paraîtrait mécanique.
	var inv := 1.0 - t
	var radius := MAX_RADIUS * (1.0 - inv * inv * inv)
	if radius < 1.0:
		return # Toute première frame : rien à tracer.

	var width := lerpf(WIDTH_START, WIDTH_END, t)
	var alpha := inv # Extinction linéaire : simple, prévisible, jamais de résidu.

	# Halo rouge d'abord : dessiné SOUS le front doré pour que celui-ci reste
	# la lecture dominante là où les deux se chevauchent.
	var inner_radius := radius * INNER_RADIUS_RATIO
	if inner_radius >= 1.0:
		var inner_color := INNER_COLOR
		inner_color.a = INNER_ALPHA * alpha
		draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, SEGMENTS + 1,
			inner_color, width * INNER_WIDTH_RATIO, true)

	var outer_color := OUTER_COLOR
	outer_color.a = alpha
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, SEGMENTS + 1, outer_color, width, true)
