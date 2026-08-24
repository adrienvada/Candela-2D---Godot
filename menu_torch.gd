class_name MenuTorch
extends Control

## M9 — La torche du curseur. Vague M, « la vitrine ».
##
## Le liseré cesse d'être un cadre : il porte une **flaque de lumière** qui le
## suit en traînant de quelques pixels, comme une lampe portée à la main.
##
## C'est le geste fondateur du lot, et il est diégétique : dans un jeu où la
## lumière est la seule information, **regarder le menu, c'est déjà jouer**.
## L'entrée sous le curseur est pleinement éclairée, ses voisines reçoivent une
## retombée décroissante — une hiérarchie magnétique obtenue sans rien écrire.
##
## À chaque activation, la flaque palpite une fois. Tant que les sons d'interface
## manquent, c'est la seule conséquence sensible d'un appui.
##
## ## Le noir reste noir
##
## L'alpha crête est volontairement infime. Cette lumière ne doit **rien**
## révéler qu'on ne voyait pas : elle accompagne, elle n'éclaire pas. Un menu
## dont le fond s'éclaircirait trahirait le sujet du jeu.

## Rayon de la flaque, en pixels.
const RAYON := 250.0
## Alpha au centre. Cinq centièmes : au-delà, le fond cesse d'être noir.
##
## Le commentaire disait « trois » et la valeur en portait cinq — un écart sans
## conséquence, sauf le jour où quelqu'un se fie au commentaire pour juger la
## marge. Vérifié sous la charte : la luminance ajoutée à la crête vaut
## `luminance(P1) × ALPHA × 0,35 ≈ 0,011`, soit moins du tiers du plafond que le
## fond s'impose à lui-même (`LUM_MAX = 0,035` dans `menu_backdrop.gdshader`).
## Les deux effets tiennent donc le même contrat, ce qu'aucun des deux ne disait.
const ALPHA := 0.05
## Retard de la lampe sur le curseur. C'est lui qui donne le poids d'une main.
const TRAINE := 9.0
## Palpitation d'appui : surcroît, puis retombée.
const PULSE := 0.6
const PULSE_CHUTE := 0.18

var _cibles := {}
var _positions := {}
var _pulse: float = 0.0
var _intensite: float = 1.0

func _init() -> void:
	name = "TorcheCurseur"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	if _intensite <= 0.0:
		_cibles.clear()
		_positions.clear()
		set_process(false)
		queue_redraw()

## Où le curseur d'un joueur se trouve, et de quelle couleur il brûle.
## `null` éteint la torche de ce joueur — hors menu, il n'y a pas de lampe.
func viser(joueur: int, centre: Variant, teinte: Color) -> void:
	if _intensite <= 0.0:
		return
	if centre == null:
		_cibles.erase(joueur)
		return
	_cibles[joueur] = {"pos": centre as Vector2, "teinte": teinte}
	if not _positions.has(joueur):
		_positions[joueur] = centre as Vector2
	set_process(true)

## Le geste vient d'engager quelque chose : la flamme monte d'un coup.
func palpiter() -> void:
	if _intensite <= 0.0:
		return
	_pulse = 1.0
	set_process(true)

func _process(delta: float) -> void:
	# Lerp exponentiel, indépendant de la cadence : le jeu tourne déplafonné, et
	# un lissage par image donnerait une traîne différente à 60 et à 240 images.
	var k := 1.0 - exp(-TRAINE * delta)
	var bouge := false
	for joueur in _cibles.keys():
		var voulu: Vector2 = _cibles[joueur]["pos"]
		var pos: Vector2 = _positions[joueur]
		if pos.distance_squared_to(voulu) > 0.25:
			_positions[joueur] = pos.lerp(voulu, k)
			bouge = true
		else:
			_positions[joueur] = voulu
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta / PULSE_CHUTE)
		bouge = true
	if not bouge:
		# Lampe posée, flamme retombée : plus rien ne change, donc plus rien à
		# redessiner. Un menu au repos ne doit rien consommer — c'est la règle
		# commune de tous les effets de la vitrine, et une lampe qui suit un
		# curseur immobile serait la seule à y déroger.
		set_process(false)
		return
	queue_redraw()

func _draw() -> void:
	if _intensite <= 0.0:
		return
	var force := ALPHA * _intensite * (1.0 + PULSE * _pulse)
	for joueur in _positions.keys():
		if not _cibles.has(joueur):
			continue
		var centre: Vector2 = _positions[joueur]
		var teinte: Color = _cibles[joueur]["teinte"]
		# Une flaque douce, en anneaux concentriques : `draw_circle` ne dégrade pas,
		# mais dix cercles empilés à alpha décroissant donnent un dégradé propre
		# sans texture ni shader — et le rendu `gl_compatibility` n'en demande pas
		# davantage pour cinq centièmes d'alpha.
		for i in 10:
			var part := 1.0 - float(i) / 10.0
			var c := teinte
			c.a = force * part * part * 0.35
			draw_circle(centre, RAYON * (1.0 - part * 0.92), c)
