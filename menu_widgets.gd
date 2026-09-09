class_name MenuWidgets
extends RefCounted

## Usine de composants d'interface standardisés — Candela 2D.
##
## Centralise la création et le stylage de tous les contrôles interactifs
## (boutons, boutons de pas, panneaux, modales, sliders) pour garantir une
## cohérence visuelle absolue (coins, bordures, ombres, typographie) et un
## comportement manette / double-curseur irréprochable sur l'ensemble des menus.

## Direction artistique : Roman Graphique Brutaliste (arêtes vives, ombres portées
## franches d'encre noire, inversion de contraste franche au survol/focus).

const Charte := preload("res://charte.gd")
const MenuTheme := preload("res://menu_theme.gd")
const MenuHatchRect := preload("res://menu_hatch_rect.gd")

# --- Rayons de courbure standards (Roman Graphique Brutaliste : angles vifs) --
const CORNER_BUTTON := 0
const CORNER_PANEL := 0
const CORNER_BADGE := 0
const CORNER_STEP := 0

# --- Bordures & Ombres standards (Hard Drop Shadows d'encre noire) ------------
const BORDER_WIDTH_CONTROL := 2
const BORDER_WIDTH_PANEL := 2
const SHADOW_SIZE := 0
const SHADOW_OFFSET_BUTTON := Vector2(4, 4)
const SHADOW_OFFSET_PRESSED := Vector2(1, 1)
const SHADOW_OFFSET_PANEL := Vector2(5, 5)
const SHADOW_OFFSET_MODAL := Vector2(8, 8)
const SHADOW_COLOR_DEFAULT := Color(0.0, 0.0, 0.0, 0.95)
const SHADOW_COLOR_PANEL := Color(0.0, 0.0, 0.0, 0.90)

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
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.90) if primary else Charte.SURFACE
	normal.set_border_width_all(BORDER_WIDTH_CONTROL)
	normal.border_color = accent if primary else (Charte.LINE if accent == MenuTheme.ACCENT else Color(accent.r, accent.g, accent.b, 0.60))
	normal.set_corner_radius_all(CORNER_BUTTON)
	normal.shadow_size = 0
	normal.shadow_offset = SHADOW_OFFSET_BUTTON
	normal.shadow_color = SHADOW_COLOR_DEFAULT
	normal.content_margin_left = Charte.GAP_M if min_size.x > 180 else Charte.GAP_S
	normal.content_margin_right = Charte.GAP_M if min_size.x > 180 else Charte.GAP_S
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal)

	# --- Style survol & focus (inversion franche de contraste) ---
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Charte.HALOGENE
	hover.bg_color = Charte.HALOGENE if (primary or accent == MenuTheme.ACCENT) else accent
	hover.shadow_size = 0
	hover.shadow_offset = SHADOW_OFFSET_BUTTON
	hover.shadow_color = SHADOW_COLOR_DEFAULT
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	# --- Style pressé / enfoncé (enfoncement mécanique de la plaque) ---
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = hover.bg_color
	pressed.border_color = Charte.HALOGENE
	pressed.shadow_size = 0
	pressed.shadow_offset = SHADOW_OFFSET_PRESSED
	pressed.shadow_color = SHADOW_COLOR_DEFAULT
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)

	# --- Style désactivé ---
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(Charte.SURFACE.r, Charte.SURFACE.g, Charte.SURFACE.b, 0.5)
	disabled.border_color = Charte.LINE
	disabled.shadow_size = 0
	disabled.shadow_offset = Vector2.ZERO
	btn.add_theme_stylebox_override("disabled", disabled)

	# Couleurs de texte
	if primary:
		btn.add_theme_color_override("font_color", Charte.NOIR)
	else:
		btn.add_theme_color_override("font_color", accent if accent != MenuTheme.ACCENT else Charte.HALOGENE)

	btn.add_theme_color_override("font_hover_color", Charte.NOIR)
	btn.add_theme_color_override("font_focus_color", Charte.NOIR)
	btn.add_theme_color_override("font_pressed_color", Charte.NOIR)
	btn.add_theme_color_override("font_hover_pressed_color", Charte.NOIR)
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
	normal.shadow_size = 0
	normal.shadow_offset = SHADOW_OFFSET_BUTTON
	normal.shadow_color = SHADOW_COLOR_DEFAULT
	normal.content_margin_left = Charte.GAP_S
	normal.content_margin_right = Charte.GAP_S
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Charte.HALOGENE
	hover.bg_color = accent if accent != MenuTheme.ACCENT else Charte.HALOGENE
	hover.shadow_size = 0
	hover.shadow_offset = SHADOW_OFFSET_BUTTON
	hover.shadow_color = SHADOW_COLOR_DEFAULT
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_color = Charte.HALOGENE
	pressed.bg_color = accent if accent != MenuTheme.ACCENT else Charte.HALOGENE
	pressed.shadow_size = 0
	pressed.shadow_offset = SHADOW_OFFSET_PRESSED
	pressed.shadow_color = SHADOW_COLOR_DEFAULT
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(Charte.SURFACE.r, Charte.SURFACE.g, Charte.SURFACE.b, 0.5)
	disabled.border_color = Charte.LINE * 0.7
	disabled.shadow_size = 0
	disabled.shadow_offset = Vector2.ZERO
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", Charte.DIM)
	btn.add_theme_color_override("font_hover_color", Charte.NOIR)
	btn.add_theme_color_override("font_focus_color", Charte.NOIR)
	btn.add_theme_color_override("font_pressed_color", Charte.NOIR)
	btn.add_theme_color_override("font_hover_pressed_color", Charte.NOIR)
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
	normal.shadow_size = 0
	normal.shadow_offset = SHADOW_OFFSET_BUTTON
	normal.shadow_color = SHADOW_COLOR_DEFAULT
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Charte.HALOGENE
	hover.bg_color = Charte.HALOGENE
	hover.shadow_size = 0
	hover.shadow_offset = SHADOW_OFFSET_BUTTON
	hover.shadow_color = SHADOW_COLOR_DEFAULT
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Charte.HALOGENE
	pressed.border_color = Charte.HALOGENE
	pressed.shadow_size = 0
	pressed.shadow_offset = SHADOW_OFFSET_PRESSED
	pressed.shadow_color = SHADOW_COLOR_DEFAULT
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)

	btn.add_theme_color_override("font_color", Charte.HALOGENE)
	btn.add_theme_color_override("font_hover_color", Charte.NOIR)
	btn.add_theme_color_override("font_focus_color", Charte.NOIR)
	btn.add_theme_color_override("font_pressed_color", Charte.NOIR)
	btn.add_theme_color_override("font_hover_pressed_color", Charte.NOIR)

	return btn

# =============================================================================
# SLIDERS & RÉGLAGES
# =============================================================================

## Style pour le rail d'un HSlider.
static func slider_track_style(color: Color = Charte.LINE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(0)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


## Style pour la zone remplie d'un HSlider.
static func slider_fill_style(color: Color = Charte.ACIER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(0)
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
	box.shadow_size = 0
	box.shadow_offset = SHADOW_OFFSET_PANEL
	box.shadow_color = SHADOW_COLOR_PANEL
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
	box.shadow_size = 0
	box.shadow_offset = SHADOW_OFFSET_MODAL
	box.shadow_color = SHADOW_COLOR_DEFAULT
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
	box.shadow_size = 0
	if focused:
		box.shadow_offset = SHADOW_OFFSET_BUTTON
		box.shadow_color = SHADOW_COLOR_DEFAULT
	else:
		box.shadow_offset = Vector2.ZERO
	return box


# =============================================================================
# TRAMES D'ENCRAGE & HACHURES (« ROMAN GRAPHIQUE BRUTALISTE » - ÉTAPE 2)
# =============================================================================

## Crée une surface de trame / hachures autonome.
static func make_hatch_rect(preset: int = MenuHatchRect.PatternMode.CROSS,
		accent: Color = Charte.LINE) -> MenuHatchRect:
	var h := MenuHatchRect.new()
	h.pattern_mode = preset
	h.color_ink = Charte.SURFACE
	h.color_line = accent
	return h


## Crée un panneau texturé de hachures (fond inactif, encart technique ou case de BD).
static func make_hatch_panel(accent: Color = Charte.LINE,
		pattern_mode: int = MenuHatchRect.PatternMode.CROSS,
		density: float = 0.35) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := make_panel_style(accent, CORNER_PANEL, BORDER_WIDTH_PANEL, Color(Charte.SURFACE.r, Charte.SURFACE.g, Charte.SURFACE.b, 0.40))
	panel.add_theme_stylebox_override("panel", style)

	var hatch := MenuHatchRect.new()
	hatch.pattern_mode = pattern_mode
	hatch.color_ink = Color(Charte.SURFACE.r, Charte.SURFACE.g, Charte.SURFACE.b, 0.90)
	hatch.color_line = accent * 0.75
	hatch.spacing = 12.0
	hatch.density = density
	hatch.roughness = 0.20
	hatch.border_width = 0.0
	hatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hatch.show_behind_parent = true
	panel.add_child(hatch)

	return panel


## Crée une fenêtre modale habillée de trames d'encrage.
static func make_hatch_modal(accent: Color = MenuTheme.ACCENT) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := make_modal_style(accent)
	panel.add_theme_stylebox_override("panel", style)

	var hatch := MenuHatchRect.new()
	hatch.pattern_mode = MenuHatchRect.PatternMode.SINGLE_45
	hatch.color_ink = Color(Charte.SURFACE.r, Charte.SURFACE.g, Charte.SURFACE.b, 0.96)
	hatch.color_line = Color(accent.r, accent.g, accent.b, 0.15)
	hatch.spacing = 14.0
	hatch.density = 0.25
	hatch.roughness = 0.10
	hatch.border_width = 0.0
	hatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hatch.show_behind_parent = true
	panel.add_child(hatch)

	return panel
