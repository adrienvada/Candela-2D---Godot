class_name MenuPasserby
extends Control

const Charte := preload("res://charte.gd")

## M4 — Quelqu'un derrière la vitre. Vague M, « la vitrine ».
##
## De loin en loin, une lueur floue et lente traverse l'écran **derrière** les
## panneaux translucides et devant le fond : une torche portée par quelqu'un qui
## marche de l'autre côté d'un verre dépoli. Étouffée sous les panneaux, révélée
## dans les gouttières entre les colonnes — la parallaxe se fait toute seule.
##
## Rarement, un éclat bref accompagne le passage : un coup de feu étouffé vu à
## travers le mur.
##
## Cela matérialise l'adversaire **avant** le match : le noir du menu est habité.
## Et cela donne enfin un sens visible à la translucidité des panneaux, décision
## de thème jusqu'ici invisible.
##
## Jamais métronomique : un intervalle régulier ferait un décor, pas une présence.

const ATTENTE_MIN := 25.0
const ATTENTE_MAX := 45.0
## Traversée complète. Lente : quelqu'un qui marche, pas qui passe en courant.
const TRAVERSEE := 3.5
## Une fois sur trois environ, le passage s'accompagne d'un éclat.
const CHANCE_ECLAT := 0.33
const RAYON := 190.0

var _attente: float = 0.0
var _t: float = -1.0
var _depart := Vector2.ZERO
var _arrivee := Vector2.ZERO
var _eclat_a: float = -1.0
var _intensite: float = 1.0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "PassantVitre"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_replanifier()

func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	if _intensite <= 0.0:
		_t = -1.0
		queue_redraw()

func _replanifier() -> void:
	_attente = _rng.randf_range(ATTENTE_MIN, ATTENTE_MAX)
	_t = -1.0
	_eclat_a = -1.0

func _process(delta: float) -> void:
	if _intensite <= 0.0 or not is_visible_in_tree():
		return
	if _t < 0.0:
		_attente -= delta
		if _attente > 0.0:
			return
		# Trajet oblique, jamais le même : le sens, la hauteur et la pente
		# changent à chaque passage.
		var vers_droite := _rng.randf() < 0.5
		var y0 := _rng.randf_range(size.y * 0.15, size.y * 0.8)
		_depart = Vector2(-RAYON if vers_droite else size.x + RAYON, y0)
		_arrivee = Vector2(size.x + RAYON if vers_droite else -RAYON,
			y0 + _rng.randf_range(-size.y * 0.25, size.y * 0.25))
		_eclat_a = _rng.randf_range(0.3, 0.7) if _rng.randf() < CHANCE_ECLAT else -1.0
		_t = 0.0
		return

	_t += delta / TRAVERSEE
	if _t >= 1.0:
		_replanifier()
	queue_redraw()

func _draw() -> void:
	if _t < 0.0 or _intensite <= 0.0:
		return
	var p := _depart.lerp(_arrivee, _t)
	# Une lueur derrière un verre dépoli n'a pas de bord : uniquement des couches
	# très faibles, très larges.
	for i in 8:
		var part := 1.0 - float(i) / 8.0
		var c := Color(Charte.ROUGE, 0.075 * _intensite * part * part)
		draw_circle(p, RAYON * (1.0 - part * 0.85), c)

	# L'éclat : bref, plus blanc, et il ne dure pas. C'est un coup de feu vu à
	# travers un mur, pas un phare.
	if _eclat_a > 0.0 and absf(_t - _eclat_a) < 0.05:
		var vif := 1.0 - absf(_t - _eclat_a) / 0.05
		for i in 4:
			var part := 1.0 - float(i) / 4.0
			var c := Color(Charte.HALOGENE, 0.16 * _intensite * vif * part)
			draw_circle(p, RAYON * 0.55 * (1.0 - part * 0.7), c)
