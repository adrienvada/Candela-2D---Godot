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
## La pâte d'interface — habillage iso (2026-09-15). **Préchargée**, comme tout
## shader du dépôt : compilée à la volée, elle le serait à l'ouverture du premier
## panneau, c'est-à-dire pile quand le joueur regarde.
const SHADER_PATE := preload("res://menu_pate.gdshader")

## Le matériau PARTAGÉ de la pâte : une seule instance pour tous les panneaux.
## Deux panneaux au même matériau peuvent être dessinés d'un même appel ; un
## matériau par panneau les séparerait tous.
static var _pate: ShaderMaterial = null


## Le matériau de la pâte, construit au premier appel.
##
## ⚠️ **La texture manquante CRIE.** `menu_pate.gdshader` déclare son grain en
## `hint_default_white` : sans fichier, chaque panneau s'éclaircirait
## uniformément sans une erreur — le repli muet que le voile d'éblouissement a
## déjà coûté. `tools/test_habillage.gd` vérifie en plus que le paramètre est posé.
static func materiau_pate() -> ShaderMaterial:
	if _pate != null:
		return _pate
	_pate = ShaderMaterial.new()
	_pate.shader = SHADER_PATE
	_pate.set_shader_parameter("echelle", Charte.PATE_GRAIN_ECHELLE)
	_pate.set_shader_parameter("force", Charte.PATE_GRAIN_FORCE)
	if ResourceLoader.exists(Charte.CHEMIN_PATE_GRAIN):
		_pate.set_shader_parameter("grain", load(Charte.CHEMIN_PATE_GRAIN))
	else:
		push_error("pâte d'interface : grain absent — %s" % Charte.CHEMIN_PATE_GRAIN)
	return _pate


## Pose la pâte sur un nœud d'interface : sa plaque (StyleBox ou `_draw`) prend
## le grain de lavis, ses enfants restent nets.
static func poser_pate(noeud: CanvasItem) -> void:
	if noeud != null:
		noeud.material = materiau_pate()


static var _pochoir: ShaderMaterial = null


## Le matériau du POCHOIR : la pâte, appuyée (`Charte.PATE_POCHOIR_FORCE`), pour ce
## qui est tamponné. Partagé lui aussi. Posé sur un libellé, le grain passe sur les
## lettres — voulu ici, évité partout ailleurs (`empater()` saute les boutons à
## texte propre).
static func materiau_pochoir() -> ShaderMaterial:
	if _pochoir != null:
		return _pochoir
	_pochoir = materiau_pate().duplicate() as ShaderMaterial
	_pochoir.set_shader_parameter("force", Charte.PATE_POCHOIR_FORCE)
	return _pochoir


static func poser_pochoir(noeud: CanvasItem) -> void:
	if noeud != null:
		noeud.material = materiau_pochoir()


## Les plaques qui prennent la pâte : l'aplat de leur style de repos.
const _STYLES_DE_PLAQUE := ["panel", "normal"]


## Empâte un sous-arbre : toute plaque qui dessine un aplat reçoit la pâte.
##
## **Un passage, et non un appel par site** : le menu construit ses panneaux en
## une centaine d'endroits, et un appel oublié ferait un panneau lisse au milieu
## des autres — le défaut qu'on ne voit qu'en capture. Rend le nombre de nœuds
## empâtés, pour que le banc puisse le compter.
##
## Ce qui est SAUTÉ, et pourquoi :
## - **un nœud qui porte déjà un matériau** : c'est le verre de M14 (cadre de
##   droite, rangées `Row_`) ou un effet de vitrine. Un nœud n'a qu'un matériau ;
##   l'écraser éteindrait l'effet sans une erreur. D'où l'ordre : ce passage se
##   fait APRÈS `MenuGlass.vitrer*()` ;
## - **un bouton qui porte son propre texte** (`Button.text` non vide) : le texte
##   d'un bouton est dessiné par le bouton lui-même, donc sous son matériau, et le
##   grain passerait sur les lettres. Les entrées du hub, dont le libellé est un
##   `Label` enfant, sont empâtées ;
## - **un style qui n'est pas un aplat** (`StyleBoxEmpty`, texture) : il n'y a rien
##   à grainer, et un matériau posé sur rien sépare quand même les lots de dessin.
static func empater(racine: Node) -> int:
	var n := 0
	if racine is Control:
		var c := racine as Control
		var bouton_a_texte := c is Button and (c as Button).text != ""
		if c.material == null and not bouton_a_texte:
			for nom: String in _STYLES_DE_PLAQUE:
				if c.has_theme_stylebox_override(nom) \
						and c.get_theme_stylebox(nom) is StyleBoxFlat:
					c.material = materiau_pate()
					n += 1
					break
	for enfant in racine.get_children():
		n += empater(enfant)
	return n

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
const SHADOW_COLOR_DEFAULT := Color(Charte.NOIR, 0.95)
const SHADOW_COLOR_PANEL := MenuTheme.OMBRE

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
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.90) if primary else MenuTheme.SURFACE
	normal.set_border_width_all(BORDER_WIDTH_CONTROL)
	normal.border_color = accent if primary else (MenuTheme.LINE if accent == MenuTheme.ACCENT else Color(accent.r, accent.g, accent.b, 0.60))
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
	hover.border_color = MenuTheme.LUMIERE
	hover.bg_color = MenuTheme.LUMIERE if (primary or accent == MenuTheme.ACCENT) else accent
	hover.shadow_size = 0
	hover.shadow_offset = SHADOW_OFFSET_BUTTON
	hover.shadow_color = SHADOW_COLOR_DEFAULT
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	# --- Style pressé / enfoncé (enfoncement mécanique de la plaque) ---
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = hover.bg_color
	pressed.border_color = MenuTheme.LUMIERE
	pressed.shadow_size = 0
	pressed.shadow_offset = SHADOW_OFFSET_PRESSED
	pressed.shadow_color = SHADOW_COLOR_DEFAULT
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)

	# --- Style désactivé ---
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(MenuTheme.SURFACE.r, MenuTheme.SURFACE.g, MenuTheme.SURFACE.b, 0.5)
	disabled.border_color = MenuTheme.LINE
	disabled.shadow_size = 0
	disabled.shadow_offset = Vector2.ZERO
	btn.add_theme_stylebox_override("disabled", disabled)

	# Couleurs de texte
	if primary:
		btn.add_theme_color_override("font_color", MenuTheme.TEXTE_SUR_PAPIER)
	else:
		btn.add_theme_color_override("font_color", accent if accent != MenuTheme.ACCENT else MenuTheme.LUMIERE)

	btn.add_theme_color_override("font_hover_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_focus_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_pressed_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_hover_pressed_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_disabled_color", MenuTheme.DIM * 0.70)
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
	normal.bg_color = MenuTheme.SURFACE
	normal.set_border_width_all(BORDER_WIDTH_CONTROL)
	normal.border_color = MenuTheme.LINE
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
	hover.border_color = MenuTheme.LUMIERE
	hover.bg_color = accent if accent != MenuTheme.ACCENT else MenuTheme.LUMIERE
	hover.shadow_size = 0
	hover.shadow_offset = SHADOW_OFFSET_BUTTON
	hover.shadow_color = SHADOW_COLOR_DEFAULT
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_color = MenuTheme.LUMIERE
	pressed.bg_color = accent if accent != MenuTheme.ACCENT else MenuTheme.LUMIERE
	pressed.shadow_size = 0
	pressed.shadow_offset = SHADOW_OFFSET_PRESSED
	pressed.shadow_color = SHADOW_COLOR_DEFAULT
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(MenuTheme.SURFACE.r, MenuTheme.SURFACE.g, MenuTheme.SURFACE.b, 0.5)
	disabled.border_color = MenuTheme.LINE * 0.7
	disabled.shadow_size = 0
	disabled.shadow_offset = Vector2.ZERO
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", MenuTheme.DIM)
	btn.add_theme_color_override("font_hover_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_focus_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_pressed_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_hover_pressed_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_disabled_color", MenuTheme.DIM * 0.6)

	return btn


## Bouton pas-à-pas compact (« ‹ » ou « › ») pour la navigation manette sur sliders.
static func make_step_button(symbol: String, min_size: Vector2 = Vector2(36, 32)) -> Button:
	var btn := Button.new()
	btn.text = symbol
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size = min_size

	Charte.appareil(btn, Charte.T_COURANT, Charte.POIDS_APPUI)

	var normal := StyleBoxFlat.new()
	normal.bg_color = MenuTheme.SURFACE
	normal.set_border_width_all(BORDER_WIDTH_CONTROL)
	normal.border_color = MenuTheme.LINE
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
	hover.border_color = MenuTheme.LUMIERE
	hover.bg_color = MenuTheme.LUMIERE
	hover.shadow_size = 0
	hover.shadow_offset = SHADOW_OFFSET_BUTTON
	hover.shadow_color = SHADOW_COLOR_DEFAULT
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = MenuTheme.LUMIERE
	pressed.border_color = MenuTheme.LUMIERE
	pressed.shadow_size = 0
	pressed.shadow_offset = SHADOW_OFFSET_PRESSED
	pressed.shadow_color = SHADOW_COLOR_DEFAULT
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)

	btn.add_theme_color_override("font_color", MenuTheme.LUMIERE)
	btn.add_theme_color_override("font_hover_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_focus_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_pressed_color", MenuTheme.TEXTE_SUR_PAPIER)
	btn.add_theme_color_override("font_hover_pressed_color", MenuTheme.TEXTE_SUR_PAPIER)

	return btn

# =============================================================================
# SLIDERS & RÉGLAGES
# =============================================================================

## Style pour le rail d'un HSlider.
static func slider_track_style(color: Color = MenuTheme.LINE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(0)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


## Style pour la zone remplie d'un HSlider.
static func slider_fill_style(color: Color = MenuTheme.FILAMENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(0)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


## Crée un HSlider stylé (non focusable pour réserver la manette aux boutons ‹ ›).
static func make_slider(min_val: float, max_val: float, step: float,
		width: float = 200.0, accent: Color = MenuTheme.FILAMENT) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.custom_minimum_size = Vector2(width, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.add_theme_stylebox_override("slider", slider_track_style())
	slider.add_theme_stylebox_override("grabber_area", slider_fill_style(accent))
	slider.add_theme_stylebox_override("grabber_area_highlight", slider_fill_style(MenuTheme.LUMIERE))
	return slider

# =============================================================================
# PANNEAUX, CADRES & MODALES
# =============================================================================

## StyleBox standardisé pour un panneau ou une rangée de réglage.
static func make_panel_style(accent: Color = MenuTheme.LINE,
		corner_radius: int = CORNER_PANEL,
		border_width: int = BORDER_WIDTH_PANEL,
		bg_color: Color = MenuTheme.SURFACE) -> StyleBoxFlat:
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
	box.bg_color = Color(MenuTheme.SURFACE.r, MenuTheme.SURFACE.g, MenuTheme.SURFACE.b, 0.97)
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
	box.bg_color = MenuTheme.SURFACE
	box.set_border_width_all(BORDER_WIDTH_CONTROL)
	box.border_color = MenuTheme.LUMIERE if focused else MenuTheme.LINE
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
		accent: Color = MenuTheme.LINE) -> MenuHatchRect:
	var h := MenuHatchRect.new()
	h.pattern_mode = preset
	h.color_ink = MenuTheme.SURFACE
	h.color_line = accent
	return h


## Crée un panneau texturé de hachures (fond inactif, encart technique ou case de BD).
static func make_hatch_panel(accent: Color = MenuTheme.LINE,
		pattern_mode: int = MenuHatchRect.PatternMode.CROSS,
		density: float = 0.35) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := make_panel_style(accent, CORNER_PANEL, BORDER_WIDTH_PANEL, Color(MenuTheme.SURFACE.r, MenuTheme.SURFACE.g, MenuTheme.SURFACE.b, 0.40))
	panel.add_theme_stylebox_override("panel", style)

	var hatch := MenuHatchRect.new()
	hatch.pattern_mode = pattern_mode
	hatch.color_ink = Color(MenuTheme.SURFACE.r, MenuTheme.SURFACE.g, MenuTheme.SURFACE.b, 0.90)
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
	hatch.color_ink = Color(MenuTheme.SURFACE.r, MenuTheme.SURFACE.g, MenuTheme.SURFACE.b, 0.96)
	hatch.color_line = Color(accent.r, accent.g, accent.b, 0.15)
	hatch.spacing = 14.0
	hatch.density = 0.25
	hatch.roughness = 0.10
	hatch.border_width = 0.0
	hatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hatch.show_behind_parent = true
	panel.add_child(hatch)

	return panel
