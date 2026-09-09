class_name MenuTamponVerdict
extends Control

## Composant d'interface « Roman Graphique Brutaliste » — Tampon encreur de verdict.
##
## Écrase un verdict (« VICTOIRE », « DÉFAITE », « FATAL ») comme un tampon officiel
## d'arène clandestine sous presse mécanique :
## - Double encadrement d'encre (cadre extérieur 3px, cadre intérieur 1px).
## - Inclinaison de frappe manuelle calibrée (-1.2° / +1.2°).
## - Animation d'écrasement mécanique au tampon (scale 1.35 -> 1.0 avec rebond sec).

const Charte := preload("res://charte.gd")

signal frappe_terminee()

@export var texte: String = "VICTOIRE":
	set(v):
		texte = v
		if _label != null:
			_label.text = texte
		queue_redraw()

@export var couleur_encre: Color = Charte.AMBRE:
	set(v):
		couleur_encre = v
		if _label != null:
			_label.add_theme_color_override("font_color", couleur_encre)
		queue_redraw()

@export var inclinaison_deg: float = -1.2:
	set(v):
		inclinaison_deg = v
		rotation_degrees = inclinaison_deg

@export var taille_police: int = Charte.T_VERDICT:
	set(v):
		taille_police = v
		if _label != null:
			Charte.enseigne(_label, taille_police, Charte.POIDS_ENSEIGNE)
		queue_redraw()

var _label: Label
var _tween: Tween

func _init(p_texte: String = "VICTOIRE", p_couleur: Color = Charte.AMBRE, p_angle: float = -1.2) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texte = p_texte
	couleur_encre = p_couleur
	inclinaison_deg = p_angle
	rotation_degrees = inclinaison_deg

func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)

	_label = Label.new()
	_label.text = texte
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Charte.enseigne(_label, taille_police, Charte.POIDS_ENSEIGNE)
	_label.add_theme_color_override("font_color", couleur_encre)
	add_child(_label)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 10.0 or h <= 10.0:
		return

	# Double encadrement officiel de tampon d'encre
	var r_ext := Rect2(2, 2, w - 4, h - 4)
	# 1. Ombre d'encre portée décalée
	draw_rect(Rect2(r_ext.position + Vector2(3, 3), r_ext.size), Color(0, 0, 0, 0.90), false, 3.0)
	# 2. Cadre extérieur épais (trait d'encre sous presse)
	draw_rect(r_ext, couleur_encre, false, 3.0)

	# 3. Cadre intérieur plus fin
	var r_int := Rect2(7, 7, w - 14, h - 14)
	draw_rect(r_int, couleur_encre, false, 1.2)

	# 4. Rivets / coins de tampon
	var coin_s := 4.0
	draw_rect(Rect2(r_int.position, Vector2(coin_s, coin_s)), couleur_encre)
	draw_rect(Rect2(r_int.position + Vector2(r_int.size.x - coin_s, 0), Vector2(coin_s, coin_s)), couleur_encre)
	draw_rect(Rect2(r_int.position + Vector2(0, r_int.size.y - coin_s), Vector2(coin_s, coin_s)), couleur_encre)
	draw_rect(Rect2(r_int.position + r_int.size - Vector2(coin_s, coin_s), Vector2(coin_s, coin_s)), couleur_encre)

## Anime l'écrasement mécanique du tampon sous presse
func frapper(duree: float = 0.35) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	pivot_offset = size * 0.5
	scale = Vector2(1.38, 1.38)
	modulate.a = 0.0

	_tween = create_tween().set_parallel(true)
	# Apparition vive
	Charte.animer(_tween, self, "modulate:a", 0.0, 1.0, duree * 0.4, Charte.Courbe.ENTREE)
	# Écrasement mécanique sous presse avec rebond franc
	Charte.animer(_tween, self, "scale", Vector2(1.38, 1.38), Vector2(1.0, 1.0), duree, Charte.Courbe.REBOND)

	# Sonorisation d'impact d'encre
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop != null and main_loop.root != null:
		var audio = main_loop.root.get_node_or_null("AudioManager")
		if audio != null and audio.has_method("play_sfx"):
			audio.play_sfx("menu_action")

	_tween.finished.connect(func() -> void:
		frappe_terminee.emit()
	, CONNECT_ONE_SHOT)

## Préréglage pour VICTOIRE
static func creer_victoire() -> Control:
	var inst = load("res://menu_tampon_verdict.gd").new("VICTOIRE", Charte.AMBRE, -1.2)
	return inst

## Préréglage pour DÉFAITE
static func creer_defaite() -> Control:
	var inst = load("res://menu_tampon_verdict.gd").new("DÉFAITE", Charte.ROUGE, 1.2)
	return inst

## Préréglage pour FATAL
static func creer_fatal() -> Control:
	var inst = load("res://menu_tampon_verdict.gd").new("FATAL", Charte.CARMIN, -1.0)
	return inst
