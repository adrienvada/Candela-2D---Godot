class_name MenuSkeleton
extends Control

## M13 — Les squelettes de lumière. Vague M, « la vitrine ».
##
## Pendant qu'un tableau attend le réseau, ses lignes montrent des barres
## fantômes qu'une bande de lumière inclinée balaie — une torche qui fouille des
## étagères dans le noir. À l'arrivée des données, chaque barre se fond dans son
## texte, la première ligne d'abord.
##
## ## Un seul nœud pour tout le tableau
##
## Les barres sont dessinées ici, pas semées dans les lignes. Trois raisons, dans
## l'ordre où elles comptent :
##
## - **le balayage est en phase** sur toutes les lignes, ce qui suppose une seule
##   diagonale, donc un seul quad ;
## - la mise en page n'a **qu'une source** : on lit le rectangle réel de chaque
##   cellule au moment de dessiner, au lieu de recopier les largeurs de colonnes
##   ici où elles finiraient par diverger ;
## - rien à ajouter dans le parcours du curseur — ce nœud ignore la souris et ne
##   prend jamais le focus, alors que soixante `ColorRect` semés dans les lignes
##   auraient tous été des candidats à écarter un par un.
##
## ## Ce qui se passe quand ça rate
##
## Le balayage s'arrête et les barres se posent en DIM statique. **L'absence
## n'est pas une panne** : un tableau qui continuerait à faire semblant de
## chercher ce qu'il ne trouvera pas mentirait sur son état.

const SHADER := preload("res://menu_skeleton.gdshader")

## Fondu d'une barre dans son texte.
const FONDU := 0.12
## Écart d'une ligne à la suivante.
const DECALAGE := 0.03
## Marge verticale rognée sur la cellule : une barre pleine hauteur ressemblerait
## à une sélection, pas à un texte absent.
const ROGNE := 5.0
## Rayon des coins.
const COIN := 3.0

var _materiau: ShaderMaterial
var _lignes: Array = []
var _intensite: float = 1.0
var _revelation: float = 0.0
var _fige: bool = false
var _tween: Tween

func _init() -> void:
	name = "SquelettesLumiere"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	# `top_level` pour deux raisons qui vont ensemble : les conteneurs de Godot
	# sautent leurs enfants top-level, donc on peut se poser dans la colonne du
	# tableau sans y prendre une place ni décaler quoi que ce soit ; et le
	# repère devient celui de l'écran, ce qui rend la conversion des rectangles
	# de cellules triviale et sans piège de parent intermédiaire.
	top_level = true
	position = Vector2.ZERO
	_materiau = ShaderMaterial.new()
	_materiau.shader = SHADER
	material = _materiau

func _ready() -> void:
	var vue := get_viewport()
	if vue != null:
		vue.size_changed.connect(_mesurer)
	_mesurer()

func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	_materiau.set_shader_parameter("intensite", _intensite)
	queue_redraw()

## Déclare les cellules à masquer, ligne par ligne : un tableau de tableaux de
## `Control`. On garde les nœuds et non leurs rectangles — la mise en page bouge
## avec la fenêtre, et un rectangle recopié serait faux au premier
## redimensionnement.
func suivre(lignes: Array) -> void:
	_lignes = lignes
	queue_redraw()

## Le tableau attend : les barres sont pleines et la torche balaie.
func attendre() -> void:
	_arreter()
	_fige = false
	_revelation = 0.0
	_materiau.set_shader_parameter("balayage", 1.0)
	visible = _intensite > 0.0 and not _lignes.is_empty()
	queue_redraw()

## L'attente a échoué : les barres se posent, la torche s'éteint.
func figer() -> void:
	_arreter()
	_fige = true
	_revelation = 0.0
	_materiau.set_shader_parameter("balayage", 0.0)
	visible = _intensite > 0.0 and not _lignes.is_empty()
	queue_redraw()

## Les données sont là : chaque barre se fond dans son texte, la première ligne
## d'abord. La récompense est petite et c'est voulu — elle ponctue une attente,
## elle ne la remplace pas.
func reveler() -> void:
	_arreter()
	_fige = false
	if not visible or _intensite <= 0.0:
		_poser()
		return
	var duree := FONDU + DECALAGE * maxf(float(_lignes.size()) - 1.0, 0.0)
	_tween = create_tween()
	_tween.tween_method(_poser_revelation, 0.0, 1.0, duree)
	_tween.finished.connect(_poser)

## Cache tout, sans animation. Pour les états qui n'ont jamais rien attendu.
func taire() -> void:
	_arreter()
	_poser()

func _poser() -> void:
	_revelation = 1.0
	visible = false
	queue_redraw()

func _poser_revelation(v: float) -> void:
	_revelation = v
	queue_redraw()

func _arreter() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

## La bande balaie l'écran entier, pas le seul tableau : c'est une torche qui
## passe, et une torche ne s'arrête pas au bord d'une étagère.
func _mesurer() -> void:
	var vue := get_viewport()
	if vue != null:
		size = vue.get_visible_rect().size
	_materiau.set_shader_parameter("taille", size)
	queue_redraw()

## Opacité d'une barre à cet instant : les lignes s'effacent l'une après l'autre.
func _opacite(index: int) -> float:
	if _revelation <= 0.0:
		return 1.0
	var duree := FONDU + DECALAGE * maxf(float(_lignes.size()) - 1.0, 0.0)
	var debut := DECALAGE * float(index)
	var part := (_revelation * duree - debut) / FONDU
	return 1.0 - clampf(part, 0.0, 1.0)

func _draw() -> void:
	if _intensite <= 0.0:
		return
	var teinte := MenuTheme.DIM if _fige else MenuTheme.LINE
	for i in _lignes.size():
		var opacite := _opacite(i) * _intensite
		if opacite <= 0.0:
			continue
		for cellule: Variant in _lignes[i]:
			var ctrl := cellule as Control
			if ctrl == null or not is_instance_valid(ctrl) or not ctrl.is_visible_in_tree():
				continue
			var zone := ctrl.get_global_rect()
			if zone.size.x <= 0.0 or zone.size.y <= ROGNE * 2.0:
				continue
			var locale := Rect2(zone.position - global_position, zone.size)
			locale = locale.grow_individual(0.0, -ROGNE, 0.0, -ROGNE)
			var c := teinte
			c.a = teinte.a * opacite
			draw_rect(locale, c)
			# Les coins : `draw_rect` n'en fait pas, et un angle vif ne ressemble
			# pas à du texte manquant, il ressemble à un bloc.
			draw_circle(locale.position + Vector2(COIN, COIN), COIN, c)
			draw_circle(Vector2(locale.end.x - COIN, locale.position.y + COIN), COIN, c)
			draw_circle(Vector2(locale.position.x + COIN, locale.end.y - COIN), COIN, c)
			draw_circle(locale.end - Vector2(COIN, COIN), COIN, c)
