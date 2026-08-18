class_name MenuEngraver
extends Control

## M7 — Le code gravé par impacts. Vague M, « la vitrine ».
##
## Le code de salon à 6 caractères ne s'imprime pas : il se **frappe**. Chaque
## caractère apparaît blanc incandescent puis refroidit vers l'or, décalé de
## 70 ms, avec une secousse d'un pixel vers le bas et deux ou trois étincelles
## qui chutent et meurent au point d'impact — six balles qui gravent le code
## dans le mur.
##
## Le code de salon est l'objet social du jeu : c'est celui qu'on lit à voix
## haute à un ami. Il apparaissait sans cérémonie. Le graver en fait un petit
## événement à chaque ouverture de salon, dans le langage exact du monde —
## l'impact qui marque la matière, le métal qui refroidit — et le
## refroidissement blanc → or atterrit précisément sur la sémantique « or = à
## lire » du thème.
##
## ## Six cases de largeur fixe
##
## Chaque caractère a sa case, dimensionnée une fois pour toutes. Le gabarit
## occupe donc exactement la même place avec un code, sans code, et pendant la
## gravure : rien ne bouge autour, et le bouton COPIER ne se déplace jamais sous
## le doigt qui le vise.
##
## ## La gravure ne rejoue pas au repeint
##
## `set_code()` est appelé par tout ce qui rafraîchit le bloc salon, c'est-à-dire
## souvent et pour des raisons sans rapport. Seul un **changement** de chaîne
## déclenche l'animation ; sinon le code se regraverait à chaque signal réseau,
## et l'événement perdrait tout son poids.

## Nombre de cases. Le code de salon en fait six, le code de récupération aussi.
const CASES := 6
## Décalage d'un impact au suivant.
const DECALAGE := 0.07
## Durée du refroidissement blanc → or.
const REFROID := 0.5
## Amplitude de la secousse, en pixels.
const SECOUSSE := 1.0
## Durée de vie d'une étincelle.
const VIE_ETINCELLE := 0.3
const ETINCELLES_MIN := 2
const ETINCELLES_MAX := 3
## Placeholder d'une case vide.
const VIDE := "—"

var _intensite: float = 1.0
var _labels: Array[Label] = []
var _check: Label
var _sparks: Control
var _code: String = ""
var _t: float = -1.0
var _etincelles: Array[Dictionary] = []
var _alea := RandomNumberGenerator.new()

func _init() -> void:
	name = "GravureCode"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alea.randomize()

	var boite := HBoxContainer.new()
	boite.name = "Cases"
	boite.alignment = BoxContainer.ALIGNMENT_CENTER
	boite.add_theme_constant_override("separation", 2)
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boite)

	for i in CASES:
		var lbl := Label.new()
		lbl.name = "CodeChar%d" % i
		lbl.text = VIDE
		# Largeur fixe : un « I » et un « W » occupent la même case, donc le code
		# ne change pas de longueur selon les lettres tirées.
		lbl.custom_minimum_size = Vector2(26, 38)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 30)
		lbl.add_theme_color_override("font_color", MenuTheme.GOLD)
		# Hors parcours du curseur : ce sont des caractères, pas des contrôles.
		lbl.focus_mode = Control.FOCUS_NONE
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boite.add_child(lbl)
		_labels.append(lbl)

	# La coche de copie a sa propre case : la coller au code obligerait à
	# reconstruire les six caractères pour l'afficher, donc à les regraver.
	_check = Label.new()
	_check.name = "Coche"
	_check.custom_minimum_size = Vector2(24, 38)
	_check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_check.add_theme_font_size_override("font_size", 22)
	_check.add_theme_color_override("font_color", MenuTheme.GOLD)
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boite.add_child(_check)

	# Les étincelles se dessinent APRÈS les caractères : un enfant dessiné par le
	# parent passerait dessous, et une étincelle derrière le chiffre qu'elle vient
	# de frapper ne se voit pas.
	_sparks = Control.new()
	_sparks.name = "Etincelles"
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sparks.draw.connect(_dessiner_etincelles)
	add_child(_sparks)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func set_intensite(valeur: float) -> void:
	_intensite = clampf(valeur, 0.0, 1.0)
	if _intensite <= 0.0:
		_finir()

## Pose le code. Chaîne vide = salon pas encore ouvert : les six cases affichent
## leur tiret, et rien ne se grave.
func set_code(code: String) -> void:
	var propre := code.strip_edges().to_upper()
	if propre == _code:
		return
	_code = propre
	_check.text = ""
	for i in CASES:
		_labels[i].text = propre.substr(i, 1) if i < propre.length() else VIDE
		_labels[i].position.y = 0.0
	if propre.is_empty() or _intensite <= 0.0:
		_finir()
		return
	_etincelles.clear()
	_t = 0.0
	set_process(true)

## Le code actuellement gravé. Les bancs le lisent : six Labels séparés n'ont
## plus de `.text` unique, et le leur recomposer à chaque appel serait un second
## endroit où la vérité pourrait diverger.
func code() -> String:
	return _code

## Le joueur vient de copier : la coche s'allume sans toucher au code.
func marquer_copie() -> void:
	_check.text = "✓"

func _finir() -> void:
	_t = -1.0
	_etincelles.clear()
	for lbl in _labels:
		lbl.position.y = 0.0
		lbl.add_theme_color_override("font_color", MenuTheme.GOLD)
	set_process(false)
	_sparks.queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var vivant := false

	for i in CASES:
		var lbl := _labels[i]
		var t := _t - float(i) * DECALAGE
		if t < 0.0:
			# Pas encore frappé : la case reste vide, et le caractère qu'elle
			# porte déjà n'est simplement pas montré.
			lbl.modulate.a = 0.0
			vivant = true
			continue
		lbl.modulate.a = 1.0
		if t < REFROID:
			vivant = true
			var part := t / REFROID
			# Le métal refroidit vite au début puis lentement : la courbe fait le
			# travail que ferait un dégradé, sans en dessiner un.
			lbl.add_theme_color_override("font_color",
				Color.WHITE.lerp(MenuTheme.GOLD, sqrt(part)))
			lbl.position.y = SECOUSSE * _intensite * (1.0 - part) * cos(part * PI * 3.0)
		else:
			lbl.add_theme_color_override("font_color", MenuTheme.GOLD)
			lbl.position.y = 0.0
		# L'impact naît à l'instant exact où le caractère apparaît.
		if t >= 0.0 and t - delta < 0.0:
			_frapper(i)

	for e in _etincelles:
		e["t"] += delta
		e["v"] = (e["v"] as Vector2) + Vector2(0.0, 620.0 * delta)
		e["p"] = (e["p"] as Vector2) + (e["v"] as Vector2) * delta
	_etincelles = _etincelles.filter(func(e): return float(e["t"]) < VIE_ETINCELLE)
	if not _etincelles.is_empty():
		vivant = true

	_sparks.queue_redraw()
	if not vivant:
		_finir()

func _frapper(index: int) -> void:
	var lbl := _labels[index]
	var centre := lbl.position + lbl.size * 0.5
	for _i in _alea.randi_range(ETINCELLES_MIN, ETINCELLES_MAX):
		_etincelles.append({
			"p": centre,
			"v": Vector2(_alea.randf_range(-70.0, 70.0), _alea.randf_range(-150.0, -60.0)),
			"t": 0.0,
		})

func _dessiner_etincelles() -> void:
	if _intensite <= 0.0:
		return
	for e in _etincelles:
		var mort := 1.0 - float(e["t"]) / VIE_ETINCELLE
		var c := Color.WHITE.lerp(MenuTheme.GOLD, 1.0 - mort)
		c.a = mort * _intensite
		_sparks.draw_circle(e["p"] as Vector2, 1.0 + mort, c)
