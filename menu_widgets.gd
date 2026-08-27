class_name MenuWidgets
extends RefCounted

## Usine de composants d'interface standardisés — Candela 2D.
##
## Centralise la création et le stylage de tous les contrôles interactifs
## (boutons, boutons de pas, panneaux, modales, sliders) pour garantir une
## cohérence visuelle absolue (coins, bordures, ombres, typographie) et un
## comportement manette / double-curseur irréprochable sur l'ensemble des menus.

const Charte := preload("res://charte.gd")
const MenuTheme := preload("res://menu_theme.gd")

# --- Rayons de courbure standards -------------------------------------------
const CORNER_BUTTON := 10
const CORNER_PANEL := 12
const CORNER_BADGE := 8
const CORNER_STEP := 6

# --- Bordures & Ombres standards --------------------------------------------
const BORDER_WIDTH_CONTROL := 2
const BORDER_WIDTH_PANEL := 1
const SHADOW_SIZE := 8

# =============================================================================
# BOUTONS
# =============================================================================

## Crée un bouton standard conforme à la Charte.
## `primary` : bouton plein énergisé (action principale / engagement).
## `accent` : couleur de rôle (BLEU/J1, ROUGE/J2, ACIER/neutre, AMBRE/titres/or).
static func make_button(label: String, accent: Color = MenuTheme.ACCENT,
		primary: bool = false, font_size: int = Charte.T_COURANT,
		min_size: Vector2 = Vector2.ZERO) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_ALL
	if min_size != Vector2.ZERO:
		btn.custom_minimum_size = min_size

	Charte.appareil(btn, font_size, Charte.POIDS_APPUI if primary else Charte.POIDS_COURANT)

	# --- Style normal ---
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.85) if primary else Charte.SURFACE
	normal.set_border_width_all(BORDER_WIDTH_CONTROL)
	normal.border_color = accent if primary else (Charte.LINE if accent == MenuTheme.ACCENT else Color(accent.r, accent.g, accent.b, 0.45))
	normal.set_corner_radius_all(CORNER_BUTTON)
	normal.content_margin_left = Charte.GAP_M if min_size.x > 180 else Charte.GAP_S
	normal.content_margin_right = Charte.GAP_M if min_size.x > 180 else Charte.GAP_S
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal)

	# --- Style survol & focus (manette et souris partagent le même feedback) ---
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Charte.HALOGENE
	hover.bg_color = accent if primary else Color(accent.r, accent.g, accent.b, 0.16)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	hover.shadow_size = SHADOW_SIZE
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	# --- Style pressé / enfoncé ---
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = accent if primary else Color(accent.r, accent.g, accent.b, 0.32)
	pressed.border_color = Charte.HALOGENE
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)

	# --- Style désactivé ---
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(Charte.SURFACE.r, Charte.SURFACE.g, Charte.SURFACE.b, 0.5)
	disabled.border_color = Charte.LINE
	disabled.shadow_size = 0
	btn.add_theme_stylebox_override("disabled", disabled)

	# Couleurs de texte
	if primary:
		btn.add_theme_color_override("font_color", Charte.NOIR)
		btn.add_theme_color_override("font_hover_color", Charte.NOIR)
		btn.add_theme_color_override("font_pressed_color", Charte.NOIR)
		btn.add_theme_color_override("font_hover_pressed_color", Charte.NOIR)
		btn.add_theme_color_override("font_focus_color", Charte.NOIR)
	else:
		btn.add_theme_color_override("font_color", accent if accent != MenuTheme.ACCENT else Charte.HALOGENE)
		btn.add_theme_color_override("font_hover_color", Charte.HALOGENE)
		btn.add_theme_color_override("font_focus_color", Charte.HALOGENE)
		btn.add_theme_color_override("font_pressed_color", Charte.HALOGENE)

	btn.add_theme_color_override("font_disabled_color", Charte.DIM * 0.70)
	return btn


## Crée un bouton à bascule / sélection d'options (ex: sélection d'arme, résolution).
static func make_choice_button(label: String, accent: Color = MenuTheme.ACCENT,
		group: ButtonGroup = null, font_size: int = Charte.T_COURANT,
		min_size: Vector2 = Vector2(160, 48)) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.button_group = group
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size = min_size

	Charte.appareil(btn, font_size, Charte.POIDS_COURANT)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Charte.SURFACE
	normal.set_border_width_all(BORDER_WIDTH_CONTROL)
	normal.border_color = Charte.LINE
	normal.set_corner_radius_all(CORNER_BUTTON)
	normal.content_margin_left = Charte.GAP_S
	normal.content_margin_right = Charte.GAP_S
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Charte.HALOGENE
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	hover.shadow_size = SHADOW_SIZE
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_color = accent
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.28)
	pressed.shadow_color = Color(accent.r, accent.g, accent.b, 0.30)
	pressed.shadow_size = 6
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(Charte.SURFACE.r, Charte.SURFACE.g, Charte.SURFACE.b, 0.5)
	disabled.border_color = Charte.LINE * 0.7
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", Charte.DIM)
	btn.add_theme_color_override("font_pressed_color", Charte.HALOGENE)
	btn.add_theme_color_override("font_hover_color", Charte.HALOGENE)
	btn.add_theme_color_override("font_focus_color", Charte.HALOGENE)
	btn.add_theme_color_override("font_disabled_color", Charte.DIM * 0.6)

	return btn


## Bouton pas-à-pas compact (« ‹ » ou « › ») pour la navigation manette sur sliders.
static func make_step_button(symbol: String, min_size: Vector2 = Vector2(36, 32)) -> Button:
	var btn := Button.new()
	btn.text = symbol
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size = min_size

	Charte.appareil(btn, Charte.T_COURANT, Charte.POIDS_APPUI)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Charte.SURFACE
	normal.set_border_width_all(BORDER_WIDTH_CONTROL)
	normal.border_color = Charte.LINE
	normal.set_corner_radius_all(CORNER_STEP)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Charte.HALOGENE
	hover.bg_color = Color(Charte.ACIER.r, Charte.ACIER.g, Charte.ACIER.b, 0.20)
	hover.shadow_color = Color(Charte.ACIER.r, Charte.ACIER.g, Charte.ACIER.b, 0.35)
	hover.shadow_size = 4
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(Charte.ACIER.r, Charte.ACIER.g, Charte.ACIER.b, 0.40)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Charte.HALOGENE)
	btn.add_theme_color_override("font_hover_color", Charte.HALOGENE)
	btn.add_theme_color_override("font_focus_color", Charte.HALOGENE)

	return btn

# =============================================================================
# SLIDERS & RÉGLAGES
# =============================================================================

## Style pour le rail d'un HSlider.
static func slider_track_style(color: Color = Charte.LINE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(3)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


## Style pour la zone remplie d'un HSlider.
static func slider_fill_style(color: Color = Charte.ACIER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(3)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


## Crée un HSlider stylé (non focusable pour réserver la manette aux boutons ‹ ›).
static func make_slider(min_val: float, max_val: float, step: float,
		width: float = 200.0, accent: Color = Charte.ACIER) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.custom_minimum_size = Vector2(width, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.add_theme_stylebox_override("slider", slider_track_style())
	slider.add_theme_stylebox_override("grabber_area", slider_fill_style(accent))
	slider.add_theme_stylebox_override("grabber_area_highlight", slider_fill_style(Charte.HALOGENE))
	return slider

# =============================================================================
# PANNEAUX, CADRES & MODALES
# =============================================================================

## StyleBox standardisé pour un panneau ou une rangée de réglage.
static func make_panel_style(accent: Color = Charte.LINE,
		corner_radius: int = CORNER_PANEL,
		border_width: int = BORDER_WIDTH_PANEL,
		bg_color: Color = Charte.SURFACE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg_color
	box.set_border_width_all(border_width)
	box.border_color = accent
	box.set_corner_radius_all(corner_radius)
	box.content_margin_left = Charte.GAP_M
	box.content_margin_right = Charte.GAP_M
	box.content_margin_top = Charte.GAP_M
	box.content_margin_bottom = Charte.GAP_M
	return box


## StyleBox standardisé pour une fenêtre modale flottante (Choix d'arme, Dialogue).
static func make_modal_style(accent: Color = MenuTheme.ACCENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Charte.SURFACE.r, Charte.SURFACE.g, Charte.SURFACE.b, 0.97)
	box.set_border_width_all(BORDER_WIDTH_CONTROL)
	box.border_color = accent
	box.set_corner_radius_all(CORNER_PANEL)
	box.content_margin_left = Charte.GAP_L
	box.content_margin_right = Charte.GAP_L
	box.content_margin_top = Charte.GAP_M
	box.content_margin_bottom = Charte.GAP_M
	box.shadow_color = Color(0, 0, 0, 0.6)
	box.shadow_size = 16
	return box


## StyleBox pour un champ de saisie LineEdit.
static func make_line_edit_style(focused: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Charte.SURFACE
	box.set_border_width_all(BORDER_WIDTH_CONTROL)
	box.border_color = Charte.HALOGENE if focused else Charte.LINE
	box.set_corner_radius_all(CORNER_BUTTON)
	box.content_margin_left = Charte.GAP_S
	box.content_margin_right = Charte.GAP_S
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	if focused:
		box.shadow_color = Color(Charte.ACIER.r, Charte.ACIER.g, Charte.ACIER.b, 0.25)
		box.shadow_size = 6
	return box
