extends Node2D
class_name KillShockwave

const Charte := preload("res://charte.gd")

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

## Le front s'amincit en avançant : épais et brutal au départ, fin à
## l'arrivée — l'énergie se dilue avec la distance.
const WIDTH_START := 14.0
const WIDTH_END := 3.0

## Refonte roman graphique, lot 7 (2026-09-10) : UN anneau, franc, blanc
## halogène — plus de halo rouge intérieur ni de doré sur-exposé. La version
## d'origine superposait deux anneaux additifs qui saturaient vers le blanc
## au départ puis ramenaient l'or : une lueur d'objectif. Un trait d'encre
## n'a qu'une valeur et un bord ; il s'efface d'un coup, il ne fond pas.
## Le trait reste plein jusqu'à cette fraction de sa vie, puis disparaît.
const PLEIN_JUSQUA := 0.72
const RING_COLOR := Charte.HALOGENE

var _age := 0.0

# Matériau non éclairé en mélange NORMAL, identique pour toutes les ondes
# (partagé en static, jamais ré-alloué). Plus d'additif : un trait d'encre se
# pose par-dessus la lumière, il ne s'y ajoute pas — en additif, l'anneau
# blanchissait le sol éclairé et disparaissait sur le flash de mort.
static var _shared_material: CanvasItemMaterial

static func _materiau() -> CanvasItemMaterial:
	if _shared_material == null:
		_shared_material = CanvasItemMaterial.new()
		_shared_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		_shared_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	return _shared_material

func _ready() -> void:
	# Au-dessus des joueurs (10) et des chiffres de dégâts (100) : l'onde EST
	# l'événement, rien ne doit la recouvrir.
	z_index = 150
	material = _materiau()
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
	if radius < 1.0 or t >= PLEIN_JUSQUA:
		return # Toute première frame, ou trait déjà effacé : rien à tracer.
	var width := lerpf(WIDTH_START, WIDTH_END, t)
	# Sans anticrénelage : le bord est franc, comme celui d'un trait de plume.
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, SEGMENTS + 1, RING_COLOR, width, false)
