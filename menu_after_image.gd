class_name MenuAfterImage
extends Control

## M2 — La rémanence rétinienne. Vague M, « la vitrine ».
##
## Quand le liseré saute d'une entrée à l'autre, l'ancienne position garde son
## image rémanente : le même contour arrondi, mais **dans la couleur
## complémentaire** — le curseur cyan laisse un fantôme braise, le rouge de J2 un
## fantôme d'eau verte — qui s'élargit de quelques pixels en s'éteignant.
##
## C'est exactement ce qu'une lumière vive imprime sur la rétine dans le noir :
## **le négatif, pas la traînée.** Un écho de même couleur serait un trail de
## particules, vu partout ; l'après-image négative naît du sujet même du jeu — un
## œil qui travaille dans l'obscurité — et n'a jamais servi en menu.
##
## ## Ce qui garantit que ça ne coûte rien
##
## Curseur immobile = **strictement rien à l'écran et aucun redessin**. Le tampon
## est circulaire et borné ; il ne contient que des rectangles et des couleurs,
## **jamais un contrôle vivant** — une entrée détruite pendant que son fantôme
## s'éteint ne peut donc rien casser.

## Durée de vie d'un fantôme. Au-delà, l'effet devient une traînée et cesse de
## ressembler à ce que fait un œil.
const DUREE := 0.35
## Élargissement du contour pendant l'extinction, en pixels. Une après-image ne
## rétrécit pas, elle se dilate en se diluant.
const DILATATION := 3.0
## Fantômes simultanés. Deux curseurs qui balaient vite en laissent peu : au-delà
## c'est du gribouillis, et le tampon borné évite d'y penser.
const MAX_FANTOMES := 8

var _fantomes: Array[Dictionary] = []
var _intensite: float = 1.0

func _init() -> void:
	name = "CoucheRemanence"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

## Réglage du joueur, de 0 (aucun fantôme) à 1.
func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	if _intensite <= 0.0:
		_fantomes.clear()
		set_process(false)
		queue_redraw()

## L'ancienne position vient d'être quittée. On ne garde que sa géométrie et sa
## teinte : le contrôle lui-même peut disparaître entre-temps.
func laisser(rect: Rect2, teinte: Color) -> void:
	if _intensite <= 0.0 or rect.size.x <= 0.0:
		return
	_fantomes.append({"rect": rect, "vie": DUREE, "teinte": _complementaire(teinte)})
	if _fantomes.size() > MAX_FANTOMES:
		_fantomes.remove_at(0)
	set_process(true)

## Le négatif, et rien d'autre. C'est ce choix qui distingue l'effet d'un trail.
func _complementaire(c: Color) -> Color:
	# Complémentaire de la couleur REÇUE : ce n'est pas une teinte de la charte,
	# c'est une opération sur celle du curseur. La règle « pas de valeur pure » ne
	# s'y applique pas — le 1.0 y est l'unité du calcul, pas du blanc.
	return Color(1.0 - c.r, 1.0 - c.g, 1.0 - c.b)

func _process(delta: float) -> void:
	var vivant := false
	for f in _fantomes:
		f["vie"] = float(f["vie"]) - delta
		if float(f["vie"]) > 0.0:
			vivant = true
	if not vivant:
		_fantomes.clear()
		# Rendre la main : un menu au repos ne doit rien consommer.
		set_process(false)
	queue_redraw()

func _draw() -> void:
	for f in _fantomes:
		var vie := float(f["vie"])
		if vie <= 0.0:
			continue
		var part := vie / DUREE
		var rect: Rect2 = f["rect"]
		var grandi := rect.grow(DILATATION * (1.0 - part))
		var teinte: Color = f["teinte"]
		teinte.a = part * part * 0.55 * _intensite
		draw_rect(grandi, teinte, false, 2.0)
