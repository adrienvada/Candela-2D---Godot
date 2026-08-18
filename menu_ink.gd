class_name MenuInk
extends Control

## M6 — L'encre coulée. Vague M, « la vitrine ».
##
## Un écran ne se contente plus d'arriver : il **s'imprime**. Depuis la hauteur
## exacte de l'entrée qu'on vient d'activer, un ménisque lumineux court le long
## de la colonne entrante ; devant lui les entrées sont encore éteintes, à son
## passage chacune s'allume.
##
## Rien n'« apparaît » : tout s'écrit, comme si la lumière était l'encre du menu.
## La continuité geste → écran rend la navigation charnelle, et l'œil lit la
## liste dans l'ordre où le jeu l'éclaire.
##
## ## Le front part du geste, et court des deux côtés
##
## Le point de départ est la ligne où le doigt vient d'appuyer, qui n'est
## presque jamais un bout de la colonne. Le front s'ouvre donc **en deux
## bords** qui s'écartent de là — la lumière du geste se répand, elle ne défile
## pas. Au retour, l'entrée activée est RETOUR, en bas : le front remonte
## presque tout seul, sans qu'on ait à le lui demander.
##
## ## Ce qui doit rester vrai même si l'effet est interrompu
##
## L'effet éteint des contrôles pour les rallumer. Une navigation rapide peut
## tuer le tween entre les deux, et un menu dont une entrée reste à alpha 0 est
## un menu cassé — pire que l'absence d'effet. `_restaurer()` est donc appelé
## avant chaque coulée, à la fin de chaque coulée, et à l'extinction de
## l'effet : à aucun moment une entrée éteinte n'est laissée sans un chemin qui
## la rallume.
##
## `modulate` uniquement, jamais `visible` ni `disabled` : les contrôles restent
## dans le parcours du résolveur de navigation dès la première image, et le
## curseur ne perd jamais sa cible.

## Durée de la coulée. Au-delà, le pouce agit avant la fin et l'effet devient
## une attente.
const DUREE := 0.22
## Épaisseur du trait, en pixels.
const TRAIT := 2.0
## Ce que le front éclaire au-delà de son bord : la frange qui donne le ménisque.
const FRANGE := 26.0
## Surbrillance d'une entrée au passage du front, avant retour à sa valeur.
const SURBRILLANCE := 0.6
## Part de la coulée pendant laquelle une entrée retombe à sa valeur normale.
const RETOMBEE := 0.28

var _intensite: float = 1.0
var _progres: float = 0.0
var _depart: float = 0.0
var _portee: float = 1.0
var _rect: Rect2 = Rect2()
var _accent: Color = Color.WHITE
## Les contrôles éteints par la coulée en cours, **avec l'alpha qu'ils avaient**.
##
## `modulate` n'appartient pas à cet effet : une entrée « PRÊT » grisée faute
## d'un second joueur est peinte à 0,45 par le même canal. Rendre 1,0 à tout le
## monde rallumerait ce bouton alors qu'il reste `disabled` — un contrôle qui a
## l'air disponible et ne répond pas. On rend donc ce qu'on a emprunté, jamais
## une valeur choisie d'avance.
var _touches: Array[Dictionary] = []
var _tween: Tween

func _init() -> void:
	name = "EncreCoulee"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	if _intensite <= 0.0:
		_arreter()

## Fait couler l'encre dans `colonne`, depuis la hauteur globale `depart_y`.
##
## `depart_y` négatif veut dire « on ne sait pas d'où » — cela arrive au premier
## affichage et après un `reset()`. Le front part alors du haut, ce qui est le
## sens de lecture et ne demande aucune exception ailleurs.
func couler(colonne: Control, depart_y: float, accent: Color) -> void:
	_arreter()
	if _intensite <= 0.0 or colonne == null or not is_instance_valid(colonne):
		return
	var zone := colonne.get_global_rect()
	if zone.size.y <= 0.0:
		return
	_rect = Rect2(zone.position - global_position, zone.size)
	_accent = accent
	_depart = (depart_y - global_position.y) if depart_y >= 0.0 else _rect.position.y
	_depart = clampf(_depart, _rect.position.y, _rect.end.y)
	# La portée est la plus grande distance que le front ait à parcourir depuis
	# son départ : c'est elle qui garantit que la dernière entrée s'allume
	# exactement à la fin, où que le doigt ait appuyé.
	_portee = maxf(_depart - _rect.position.y, _rect.end.y - _depart) + FRANGE
	if _portee <= 0.0:
		return

	for enfant in colonne.get_children():
		var ctrl := enfant as Control
		if ctrl != null:
			_touches.append({"ctrl": ctrl, "origine": ctrl.modulate.a})
			ctrl.modulate.a = 0.0

	_progres = 0.0
	_tween = create_tween()
	_tween.tween_method(_avancer, 0.0, 1.0, DUREE * (0.6 + 0.4 * _intensite))
	_tween.finished.connect(_restaurer)

func _avancer(t: float) -> void:
	_progres = t
	var front := _portee * t
	for touche in _touches:
		var ctrl: Control = touche["ctrl"]
		if not is_instance_valid(ctrl):
			continue
		# La valeur d'arrivée est celle qu'on a empruntée : une entrée grisée
		# s'allume jusqu'à SON gris, pas jusqu'au plein.
		var origine: float = touche["origine"]
		var centre := ctrl.position.y + ctrl.size.y * 0.5 + _rect.position.y
		var distance := absf(centre - _depart)
		# Combien de front a dépassé cette entrée, ramené sur la retombée.
		var passe := (front - distance) / maxf(_portee * RETOMBEE, 1.0)
		if passe <= 0.0:
			ctrl.modulate.a = 0.0
		elif passe >= 1.0:
			ctrl.modulate.a = origine
		else:
			# Le pic de surbrillance est de la lumière en trop, donc de l'alpha
			# au-delà de sa valeur : Godot le borne au rendu, et l'entrée paraît
			# blanchir une fraction de seconde avant de se poser.
			ctrl.modulate.a = origine * (1.0
				+ SURBRILLANCE * _intensite * sin(passe * PI))
	queue_redraw()

func _arreter() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_restaurer()

func _restaurer() -> void:
	for touche in _touches:
		var ctrl: Control = touche["ctrl"]
		if is_instance_valid(ctrl):
			ctrl.modulate.a = touche["origine"]
	_touches.clear()
	_progres = 0.0
	queue_redraw()

func _draw() -> void:
	if _intensite <= 0.0 or _progres <= 0.0 or _progres >= 1.0:
		return
	var front := _portee * _progres
	# Le trait s'efface sur la fin : un ménisque qui disparaîtrait d'un coup au
	# bord de la colonne se lirait comme un défaut d'affichage.
	var reste := 1.0 - smoothstep(0.75, 1.0, _progres)
	for sens: float in [-1.0, 1.0]:
		var y: float = _depart + front * sens
		if y < _rect.position.y - FRANGE or y > _rect.end.y + FRANGE:
			continue
		# Faux HDR : un cœur blanc étroit sur un fût large et sourd teinté à
		# l'accent. C'est la technique déjà imposée au laser du jeu, et la seule
		# qui donne une impression de sur-luminosité sous `gl_compatibility`.
		for i in 4:
			var part := float(i) / 4.0
			var c := _accent
			c.a = 0.16 * (1.0 - part) * _intensite * reste
			draw_rect(Rect2(_rect.position.x, y - FRANGE * part * 0.5,
				_rect.size.x, maxf(FRANGE * part, TRAIT)), c)
		var coeur := Color(1.0, 1.0, 1.0, 0.75 * _intensite * reste)
		draw_rect(Rect2(_rect.position.x, y - TRAIT * 0.5, _rect.size.x, TRAIT), coeur)
