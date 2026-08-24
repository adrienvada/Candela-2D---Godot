class_name MenuTitle
extends Node

## M11 — Le titre incandescent. Vague M, « la vitrine ».
##
## Porte le matériau du titre et déclenche ce que le shader ne peut pas décider
## seul : quand le titre s'embrase, et de quelle température est le verdict.
##
## ## Ce que ce nœud fait et ne fait pas
##
## L'onde continue vit **dans le shader**, pilotée par `TIME` : elle ne coûte
## rien en GDScript et tourne sans qu'on la touche. Ce qui remonte ici, ce sont
## les trois choses que le GPU ignore — la largeur du bloc de texte, le moment de
## l'embrasement, et l'issue du match.
##
## ## Un seul point d'accord avec M10
##
## L'extinction des feux éteint le titre avec les autres surfaces, par son
## `modulate`. Le shader travaille **multiplicativement** sur la couleur qui lui
## arrive, `modulate` compris : les deux se composent au lieu de se battre. C'est
## la leçon du 2026-08-18, et c'est pour ça que l'embrasement ne pose jamais une
## couleur absolue.

const SHADER := preload("res://menu_title.gdshader")

## Montée de la braise au plein or.
const EMBRASEMENT := 0.35
## Le dépassement qui suit le front, et le temps qu'il met à mourir.
const DEPASSEMENT := 0.25
const DEPASSEMENT_CHUTE := 0.4
## La flambée de victoire : une fois, et brève.
const FLAMBEE := 0.55
## Ce qui reste de l'onde après une défaite : la braise basse.
const AMPLITUDE_DEFAITE := 0.5

var _materiau: ShaderMaterial
var _label: Label
var _intensite: float = 1.0
var _tween: Tween

func _init() -> void:
	name = "TitreIncandescent"
	_materiau = ShaderMaterial.new()
	_materiau.shader = SHADER
	_materiau.set_shader_parameter("intensite", 1.0)
	_materiau.set_shader_parameter("embrasement", 1.0)
	# Les deux teintes du shader viennent de la charte, et elles y sont
	# NORMALISÉES : le shader les emploie en facteur (`col * teinte`), donc une
	# couleur passée telle quelle assombrirait au lieu de teinter. Diviser par le
	# canal le plus fort garde la direction et rend la luminance.
	_materiau.set_shader_parameter("teinte_crete", _teinte(MenuTheme.LUMIERE, 1.0))
	# La victoire tire vers le vert « prêt » de la triade, à 30 % : c'est un
	# glacis sur l'or, pas un repeint. Au-delà, le titre cesse d'être doré.
	_materiau.set_shader_parameter("teinte_verdict", _teinte(MenuTheme.OK, 0.30))


## Une teinte MULTIPLICATIVE tirée d'une couleur de la charte.
##
## Normalisée sur son canal le plus fort — sans quoi `col * teinte` baisserait la
## luminance au lieu de la colorer — puis ramenée vers le blanc de `force`, qui
## dose l'écart. À `force = 0`, la teinte est neutre et n'a aucun effet.
static func _teinte(couleur: Color, force: float) -> Vector3:
	var pic := maxf(couleur.r, maxf(couleur.g, couleur.b))
	if pic <= 0.0:
		return Vector3.ONE
	var n := Vector3(couleur.r / pic, couleur.g / pic, couleur.b / pic)
	return Vector3.ONE.lerp(n, clampf(force, 0.0, 1.0))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Prend en charge le titre. Le suivi de largeur se branche ici : sans elle,
## l'onde se calerait sur une largeur fausse et se replierait au milieu du mot.
func adopter(label: Label) -> void:
	if label == null:
		return
	_label = label
	label.material = _materiau
	if not label.resized.is_connected(_mesurer):
		label.resized.connect(_mesurer)
	_mesurer()

func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	_materiau.set_shader_parameter("intensite", _intensite)
	if _intensite <= 0.0:
		_arreter()
		_materiau.set_shader_parameter("embrasement", 1.0)
		_materiau.set_shader_parameter("depassement", 0.0)
		_materiau.set_shader_parameter("flambee", 0.0)

## Le titre prend feu, de gauche à droite. À l'ouverture du menu.
func embraser() -> void:
	if _intensite <= 0.0 or _label == null:
		return
	_arreter()
	_mesurer()
	# Le verdict d'un match précédent ne doit pas colorer l'ouverture suivante.
	_materiau.set_shader_parameter("amplitude", 1.0)
	_materiau.set_shader_parameter("flambee", 0.0)
	_materiau.set_shader_parameter("embrasement", 0.0)
	_materiau.set_shader_parameter("depassement", DEPASSEMENT)
	_tween = _label.create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_poser_embrasement, 0.0, 1.0, EMBRASEMENT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_poser_depassement, DEPASSEMENT, 0.0, DEPASSEMENT_CHUTE) \
		.set_delay(EMBRASEMENT * 0.5)

## La température de l'issue, à l'écran de fin.
##
## La victoire flambe une fois vers le blanc-vert ; la défaite ne flambe pas et
## voit son onde tomber de moitié — la braise basse. C'est le même shader qui
## porte les deux : l'écran de fin est signé sans qu'un seul contrôle bouge.
func verdict(victoire: bool) -> void:
	if _intensite <= 0.0 or _label == null:
		return
	_arreter()
	_mesurer()
	_materiau.set_shader_parameter("embrasement", 1.0)
	_materiau.set_shader_parameter("depassement", 0.0)
	_materiau.set_shader_parameter("amplitude",
		1.0 if victoire else AMPLITUDE_DEFAITE)
	if not victoire:
		_materiau.set_shader_parameter("flambee", 0.0)
		return
	_tween = _label.create_tween()
	_tween.tween_method(_poser_flambee, 0.0, 1.0, 0.12)
	_tween.tween_method(_poser_flambee, 1.0, 0.0, FLAMBEE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _mesurer() -> void:
	if _label != null and is_instance_valid(_label):
		_materiau.set_shader_parameter("largeur", maxf(_label.size.x, 1.0))

func _arreter() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

func _poser_embrasement(v: float) -> void:
	_materiau.set_shader_parameter("embrasement", v)

func _poser_depassement(v: float) -> void:
	_materiau.set_shader_parameter("depassement", v)

func _poser_flambee(v: float) -> void:
	_materiau.set_shader_parameter("flambee", v)
