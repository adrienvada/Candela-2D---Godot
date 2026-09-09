class_name MenuComicPanel
extends Control

## Étape 4 — Mise en scène narrative & Découpage en cases dynamiques.
##
## Traite chaque panneau de menu comme une case de bande dessinée (Roman Graphique Brutaliste) :
## 1. Cadre d'encre franc aux bords tranchants (encrage noir brut, angles vifs, coins d'imprimerie).
## 2. Découpage en cases dynamique (« Comic Panel Reveal ») : ouverture au massicot,
##    volet d'encre franc et tracé net du cadre lors des transitions d'écran.
## 3. Interaction dynamique avec la torche : ombre portée projetée à l'opposé du faisceau
##    et liseré spéculaire (rim-light) modulé sur les tranches qui font face à la lumière,
##    donnant l'impression d'une plaque d'impression physique en relief devant l'arène.
##
## Zéro blocage d'input : mouse_filter = MOUSE_FILTER_IGNORE en permanence.

const Charte := preload("res://charte.gd")

## Épaisseur du trait d'encrage principal
const EPAISSEUR_CADRE := 2.0
## Longueur des repères d'onglet/massicot aux 4 coins
const TAILLE_ONGLET := 8.0
## Portée d'influence de la torche sur le liseré (en pixels)
const PORTEE_TORCHE := 450.0
## Distance maximale d'ombre portée (en pixels)
const MAX_OMBRE_OFFSET := 14.0

## Éléments de style
var _border_color_base := Charte.LINE
var _border_color_highlight := Charte.AMBRE
var _corner_marks: bool = true

## État de la transition (« Comic Panel Reveal »)
var _reveal_progress: float = 1.0
var _reveal_direction: float = 1.0
var _reveal_tween: Tween

## État de la torche pour le relief physique
var _torch_pos_global: Vector2 = Vector2(-9999, -9999)
var _has_torch: bool = false
var _shadow_offset: Vector2 = Vector2(0, 4)
var _rim_intensities: Dictionary = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}

## Référence optionnelle vers un StyleBoxFlat associé pour synchroniser l'ombre système
var _target_stylebox: StyleBoxFlat = null

func _init() -> void:
	name = "MenuComicPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Associe un StyleBoxFlat (ex: le fond de PanelContainer) pour synchroniser son ombre portée native
func associer_stylebox(style: StyleBoxFlat) -> void:
	_target_stylebox = style
	if _target_stylebox != null:
		_target_stylebox.shadow_color = Color(0.0, 0.0, 0.0, 0.70)
		_target_stylebox.shadow_size = 12
		_target_stylebox.shadow_offset = _shadow_offset

## Déclenche le « Comic Panel Reveal » : découpe de la case au massicot d'encre
func reveler(direction: float = 1.0, duree: float = Charte.D_MOYEN) -> void:
	arret_immediat()
	_reveal_direction = 1.0 if direction >= 0.0 else -1.0
	_reveal_progress = 0.0
	
	_reveal_tween = create_tween()
	_reveal_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	var appliquer := func(p: float) -> void:
		_reveal_progress = p
		queue_redraw()
	
	# Transition vive et tranchante via la courbe d'ENTRÉE de la charte
	Charte.animer_via(_reveal_tween, appliquer, 0.0, 1.0, duree, Charte.Courbe.ENTREE)
	_reveal_tween.finished.connect(func() -> void:
		_reveal_progress = 1.0
		queue_redraw()
	)

## Interruption immédiate garantissant la réactivité manette/clavier instantanée
func arret_immediat() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null
	_reveal_progress = 1.0
	queue_redraw()

## Met à jour la position globale de la torche pour moduler le relief et l'ombrage
func set_torch_position_global(pos: Vector2) -> void:
	_torch_pos_global = pos
	_has_torch = true
	
	var r := get_global_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
		
	var centre := r.get_center()
	var delta := centre - pos
	var dist := delta.length()
	
	# 1. Calcul de l'ombre portée projetée (fuit la lumière de la lampe)
	if dist > 1.0:
		var dir := delta.normalized()
		var force := clampf(dist / PORTEE_TORCHE, 0.3, 1.2)
		_shadow_offset = dir * (MAX_OMBRE_OFFSET * force)
	else:
		_shadow_offset = Vector2(0, 2)
	
	if _target_stylebox != null:
		_target_stylebox.shadow_offset = _shadow_offset
	
	# 2. Modulation du liseré spéculaire (rim-light) sur chaque arête
	# Arête gauche
	var dist_left := absf(pos.x - r.position.x)
	var cote_left := 1.0 if pos.x < r.position.x else 0.2
	_rim_intensities["left"] = clampf((1.0 - dist_left / PORTEE_TORCHE) * cote_left, 0.0, 1.0)
	
	# Arête droite
	var dist_right := absf(pos.x - r.end.x)
	var cote_right := 1.0 if pos.x > r.end.x else 0.2
	_rim_intensities["right"] = clampf((1.0 - dist_right / PORTEE_TORCHE) * cote_right, 0.0, 1.0)
	
	# Arête haute
	var dist_top := absf(pos.y - r.position.y)
	var cote_top := 1.0 if pos.y < r.position.y else 0.2
	_rim_intensities["top"] = clampf((1.0 - dist_top / PORTEE_TORCHE) * cote_top, 0.0, 1.0)
	
	# Arête basse
	var dist_bottom := absf(pos.y - r.end.y)
	var cote_bottom := 1.0 if pos.y > r.end.y else 0.2
	_rim_intensities["bottom"] = clampf((1.0 - dist_bottom / PORTEE_TORCHE) * cote_bottom, 0.0, 1.0)
	
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	
	# --- A. Dessin du cadre d'encrage franc avec biseau spéculaire ---
	# Calcul des 4 arêtes avec teinte modulée par la torche
	var col_left := _border_color_base.lerp(_border_color_highlight, _rim_intensities["left"] * 0.85)
	var col_right := _border_color_base.lerp(_border_color_highlight, _rim_intensities["right"] * 0.85)
	var col_top := _border_color_base.lerp(_border_color_highlight, _rim_intensities["top"] * 0.85)
	var col_bottom := _border_color_base.lerp(_border_color_highlight, _rim_intensities["bottom"] * 0.85)
	
	# Arête gauche
	draw_line(Vector2(0, 0), Vector2(0, r.size.y), col_left, EPAISSEUR_CADRE)
	# Arête droite
	draw_line(Vector2(r.size.x, 0), Vector2(r.size.x, r.size.y), col_right, EPAISSEUR_CADRE)
	# Arête haute
	draw_line(Vector2(0, 0), Vector2(r.size.x, 0), col_top, EPAISSEUR_CADRE)
	# Arête basse
	draw_line(Vector2(0, r.size.y), Vector2(r.size.x, r.size.y), col_bottom, EPAISSEUR_CADRE)
	
	# Repères de massicot / coins d'encrage de BD brutale aux 4 angles
	if _corner_marks:
		var col_coin := Charte.ACIER
		col_coin.a = 0.65
		# Haut-gauche
		draw_line(Vector2(TAILLE_ONGLET, 0), Vector2(TAILLE_ONGLET, TAILLE_ONGLET), col_coin, 1.0)
		draw_line(Vector2(0, TAILLE_ONGLET), Vector2(TAILLE_ONGLET, TAILLE_ONGLET), col_coin, 1.0)
		# Haut-droite
		draw_line(Vector2(r.size.x - TAILLE_ONGLET, 0), Vector2(r.size.x - TAILLE_ONGLET, TAILLE_ONGLET), col_coin, 1.0)
		draw_line(Vector2(r.size.x, TAILLE_ONGLET), Vector2(r.size.x - TAILLE_ONGLET, TAILLE_ONGLET), col_coin, 1.0)
		# Bas-gauche
		draw_line(Vector2(TAILLE_ONGLET, r.size.y), Vector2(TAILLE_ONGLET, r.size.y - TAILLE_ONGLET), col_coin, 1.0)
		draw_line(Vector2(0, r.size.y - TAILLE_ONGLET), Vector2(TAILLE_ONGLET, r.size.y - TAILLE_ONGLET), col_coin, 1.0)
		# Bas-droite
		draw_line(Vector2(r.size.x - TAILLE_ONGLET, r.size.y), Vector2(r.size.x - TAILLE_ONGLET, r.size.y - TAILLE_ONGLET), col_coin, 1.0)
		draw_line(Vector2(r.size.x, r.size.y - TAILLE_ONGLET), Vector2(r.size.x - TAILLE_ONGLET, r.size.y - TAILLE_ONGLET), col_coin, 1.0)

	# --- B. Volet de transition d'encre (« Comic Panel Reveal ») ---
	if _reveal_progress < 1.0:
		var p := _reveal_progress
		# Découpe au massicot : le volet noir s'ouvre selon la direction
		if _reveal_direction >= 0.0:
			# Volet avançant de gauche à droite
			var cut_x := r.size.x * p
			# Zone encore masquée par l'encre noire brute
			if cut_x < r.size.x:
				var dark_rect := Rect2(cut_x, 0, r.size.x - cut_x, r.size.y)
				draw_rect(dark_rect, Charte.NOIR)
				# Lame du massicot / trait d'encre noir franc
				draw_line(Vector2(cut_x, 0), Vector2(cut_x, r.size.y), Charte.HALOGENE, 2.0)
				draw_line(Vector2(cut_x - 1.0, 0), Vector2(cut_x - 1.0, r.size.y), Charte.AMBRE, 1.0)
		else:
			# Volet avançant de droite à gauche (retour en arrière)
			var cut_x := r.size.x * (1.0 - p)
			if cut_x > 0.0:
				var dark_rect := Rect2(0, 0, cut_x, r.size.y)
				draw_rect(dark_rect, Charte.NOIR)
				draw_line(Vector2(cut_x, 0), Vector2(cut_x, r.size.y), Charte.HALOGENE, 2.0)
				draw_line(Vector2(cut_x + 1.0, 0), Vector2(cut_x + 1.0, r.size.y), Charte.AMBRE, 1.0)
