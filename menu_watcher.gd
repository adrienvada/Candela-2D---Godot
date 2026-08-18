class_name MenuWatcher
extends Control

## M3 — Le regard du noir. Vague M, « la vitrine ».
##
## Après un long moment sans que rien ne bouge, **deux reflets minuscules**
## apparaissent quelque part dans les marges : deux yeux qui accrochent une
## lumière lointaine. Ils montent à peine au-dessus du seuil de perception,
## clignent une fois, et disparaissent. Jamais deux fois au même endroit ; le
## moindre geste les efface.
##
## « L'obscurité qui regarde », littéralement : le menu au repos a un pouls, et
## l'adversaire existe déjà avant le match. L'effet vise le « je l'ai vu ou j'ai
## rêvé ? » — celui qui fait revenir vérifier, et qu'on montre à quelqu'un.
##
## Purement visuel, et c'est honnête : les sons d'interface n'existent pas encore,
## celui-ci n'attend aucun asset.

## Silence exigé avant qu'ils osent. Assez long pour qu'un joueur qui navigue ne
## les voie jamais — ils appartiennent au menu qu'on laisse ouvert.
const ATTENTE := 25.0
## Durée de vie complète, montée et clignement compris.
const VIE := 2.5
## Écart entre les deux yeux, en pixels. Un visage, pas deux lucioles.
const ECART := 11.0

var _repos: float = 0.0
var _vie: float = 0.0
var _pos := Vector2.ZERO
var _intensite: float = 1.0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "RegardDuNoir"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.randomize()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	if _intensite <= 0.0:
		_vie = 0.0
		queue_redraw()

## Le joueur a bougé : le noir referme les yeux, et le compte repart.
func reveiller() -> void:
	_repos = 0.0
	if _vie > 0.0:
		_vie = 0.0
		queue_redraw()

func _process(delta: float) -> void:
	if _intensite <= 0.0 or not is_visible_in_tree():
		return
	if _vie > 0.0:
		_vie = maxf(0.0, _vie - delta)
		queue_redraw()
		return
	_repos += delta
	if _repos < ATTENTE:
		return
	_repos = 0.0
	# Dans les marges, jamais au centre : les panneaux y sont, et deux yeux posés
	# sur un texte seraient une décoration, pas une présence.
	var marge := size.x * 0.12
	_pos = Vector2(
		_rng.randf_range(marge * 0.3, marge) if _rng.randf() < 0.5 \
			else _rng.randf_range(size.x - marge, size.x - marge * 0.3),
		_rng.randf_range(size.y * 0.25, size.y * 0.85))
	_vie = VIE
	queue_redraw()

func _draw() -> void:
	if _vie <= 0.0 or _intensite <= 0.0:
		return
	var part := _vie / VIE
	# Montée rapide, longue tenue, extinction — et un clignement au milieu, les
	# deux yeux ensemble : c'est la synchronie qui fait le vivant.
	var alpha := (1.0 - part) / 0.16 if part > 0.84 else part / 0.84
	if absf(part - 0.5) < 0.02:
		alpha = 0.0
	var c := Color(1.0, 0.36, 0.45, clampf(alpha, 0.0, 1.0) * 0.5 * _intensite)
	for cote in [-1.0, 1.0]:
		var centre := _pos + Vector2(ECART * 0.5 * cote, 0.0)
		for i in 3:
			var d := c
			d.a = c.a * (1.0 - float(i) / 3.0)
			draw_circle(centre, 1.4 + float(i) * 1.1, d)
