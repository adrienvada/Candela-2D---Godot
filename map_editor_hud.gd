## MapEditorHUD — Interface de l'éditeur de cartes.
##
## Toute l'interface est construite par code : l'éditeur reste une scène nue,
## et l'habillage suit l'identité néon du jeu (blanc et cyan sur noir profond).
##
## Le HUD ne décide de rien. Il expose des signaux, affiche ce qu'on lui donne,
## et laisse `map_editor.gd` arbitrer. Seule exception assumée : il grise
## lui-même les boutons Sauvegarder et Tester tant que la carte est injouable,
## à partir du résultat de `MapCodec.check_playable()` qu'on lui transmet.

class_name MapEditorHUD
extends CanvasLayer

const Charte := preload("res://charte.gd")

## Un bouton d'action a été actionné. Voir les constantes ACTION_*.
signal action_requested(action: StringName)
## L'utilisateur a validé le nom de sauvegarde.
signal save_confirmed(map_name: String)
## L'utilisateur a validé un code de partage à importer.
signal import_confirmed(code: String)
## Une étape a été choisie directement dans la barre du haut.
signal step_selected(index: int)
## Une fenêtre modale s'est ouverte ou fermée : l'édition doit se figer.
signal modal_state_changed(open: bool)

const ACTION_BRUSH: StringName = &"brush"
const ACTION_UNDO: StringName = &"undo"
const ACTION_REDO: StringName = &"redo"
const ACTION_AUTO_WALLS: StringName = &"auto_walls"
const ACTION_MIRROR_H: StringName = &"mirror_h"
const ACTION_MIRROR_V: StringName = &"mirror_v"
const ACTION_MIRROR_D: StringName = &"mirror_d"
const ACTION_MIRROR_AD: StringName = &"mirror_ad"
const ACTION_ROTATE_180: StringName = &"rotate_180"
const ACTION_GRID_WIDER: StringName = &"grid_wider"
const ACTION_GRID_NARROWER: StringName = &"grid_narrower"
const ACTION_GRID_TALLER: StringName = &"grid_taller"
const ACTION_GRID_SHORTER: StringName = &"grid_shorter"
const ACTION_LIGHT: StringName = &"light"
const ACTION_FRAME: StringName = &"frame"
const ACTION_CLEAR: StringName = &"clear"
const ACTION_NEW: StringName = &"new"
const ACTION_SHARE: StringName = &"share"
const ACTION_IMPORT: StringName = &"import"
const ACTION_SAVE: StringName = &"save"
const ACTION_TEST: StringName = &"test"
const ACTION_BACK: StringName = &"back"

enum Toast { INFO, SUCCESS, WARN, ERROR }

# --- Palette néon -----------------------------------------------------------
const COL_PANEL := Color(Charte.SURFACE * 0.7, 0.93)
const COL_PANEL_SOFT := Color(Charte.SURFACE * 1.3, 0.95)
const COL_BORDER := Color(Charte.BLEU, 0.28)
const COL_TEXT := Charte.HALOGENE
const COL_DIM := Charte.DIM
const COL_OK := Charte.ETAT_OK
const COL_WARN := Charte.ETAT_ATTENTION
const COL_ERROR := Charte.ETAT_FAUTE
const COL_ACCENT := Charte.BLEU

const PANEL_WIDTH := 380.0
const TOAST_LIFETIME := 2.6

# --- Nœuds ------------------------------------------------------------------
var root: Control = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _step_bar: HBoxContainer = null
var _step_buttons: Array[Button] = []
var _step_colours: Array[Color] = []
var _tool_label: Label = null
var _verdict_label: Label = null
var _checks_box: VBoxContainer = null
var _reason_label: Label = null
var _history_label: Label = null
var _toast_box: VBoxContainer = null
var _prompt_pad: Label = null
var _prompt_key: Label = null
var _sandbox_banner: PanelContainer = null

var _btn_save: Button = null
var _btn_test: Button = null
var _btn_undo: Button = null
var _btn_redo: Button = null
var _btn_light: Button = null

# --- Modales ----------------------------------------------------------------
var _modal_root: Control = null
var _save_panel: PanelContainer = null
var _import_panel: PanelContainer = null
var _name_edit: LineEdit = null
var _code_edit: LineEdit = null
var _map_list: ItemList = null
var _collision_label: Label = null
var _dialog_error: Label = null
var _save_button: Button = null

var _map_names: PackedStringArray = []
var _builtin_names: PackedStringArray = []
var _checks_signature: String = ""
var _playable: bool = false
var _sandbox: bool = false

# ---------------------------------------------------------------------------
# CONSTRUCTION
# ---------------------------------------------------------------------------

func _ready() -> void:
	layer = 10

	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_header()
	_build_step_bar()
	_build_side_panel()
	_build_prompt_bar()
	_build_toast_box()
	_build_sandbox_banner()
	_build_modals()

func _build_header() -> void:
	var panel := _make_panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 28.0
	panel.offset_top = 24.0
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Charte.GAP_XXS)
	panel.add_child(box)

	_title_label = _make_label("ÉDITEUR DE CARTE", Charte.T_TITRE, COL_TEXT)
	box.add_child(_title_label)

	_subtitle_label = _make_label("grille 32×32", Charte.T_APPUI, COL_DIM)
	box.add_child(_subtitle_label)

	_tool_label = _make_label("Pinceau", Charte.T_COURANT, COL_ACCENT)
	box.add_child(_tool_label)

func _build_step_bar() -> void:
	var wrapper := _make_panel()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	wrapper.offset_top = 24.0
	wrapper.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(wrapper)

	_step_bar = HBoxContainer.new()
	_step_bar.add_theme_constant_override("separation", Charte.GAP_XS)
	wrapper.add_child(_step_bar)

## Crée les pastilles d'étape. L'éditeur possède les libellés et les couleurs.
func build_steps(labels: PackedStringArray, colours: Array[Color]) -> void:
	for child in _step_bar.get_children():
		_step_bar.remove_child(child)
		child.queue_free()
	_step_buttons.clear()

	for i in labels.size():
		var button := Button.new()
		button.text = labels[i]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", Charte.T_APPUI)
		button.custom_minimum_size = Vector2(150, 42)
		var index := i
		button.pressed.connect(func() -> void: step_selected.emit(index))
		_step_bar.add_child(button)
		_step_buttons.append(button)
		_style_step_button(button, colours[i] if i < colours.size() else COL_ACCENT, false)

	_step_colours = colours

func _build_side_panel() -> void:
	# Le panneau est borné en bas et défilant : ajouter un outil ne doit jamais
	# pousser « SAUVEGARDER » sous la barre d'aide.
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	outer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	outer.offset_left = -PANEL_WIDTH - 28.0
	outer.offset_right = -28.0
	outer.offset_top = 24.0
	outer.offset_bottom = -96.0
	outer.add_theme_constant_override("separation", Charte.GAP_XS)
	root.add_child(outer)

	# Validation et outils défilent ; les actions primaires restent ancrées.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	outer.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", Charte.GAP_XS)
	scroll.add_child(column)

	column.add_child(_build_validation_panel())
	column.add_child(_build_tools_panel())

	outer.add_child(_build_actions_panel())

func _build_validation_panel() -> PanelContainer:
	var panel := _make_panel()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Charte.GAP_XS)
	panel.add_child(box)

	box.add_child(_make_label("VALIDATION", Charte.T_MENTION, COL_DIM))

	_verdict_label = _make_label("—", Charte.T_APPUI, COL_WARN)
	box.add_child(_verdict_label)

	_checks_box = VBoxContainer.new()
	_checks_box.add_theme_constant_override("separation", Charte.GAP_XXS)
	box.add_child(_checks_box)

	_reason_label = _make_label("", Charte.T_COURANT, COL_ERROR)
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_label.custom_minimum_size = Vector2(PANEL_WIDTH - 34.0, 0)
	box.add_child(_reason_label)

	return panel

var _btn_brush: Button
var _btn_mirror_d: Button
var _btn_mirror_ad: Button
var _grid_label: Label

func _build_tools_panel() -> PanelContainer:
	var panel := _make_panel()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Charte.GAP_XS)
	panel.add_child(box)

	box.add_child(_make_label("OUTILS", Charte.T_MENTION, COL_DIM))

	# Le pinceau est le réglage le plus structurant : en tête de panneau.
	# Libellé et icône arrivent par `set_brush()` : le HUD ne connaît pas le
	# mode par défaut, et n'a aucune raison de le deviner.
	_btn_brush = _make_button("PINCEAU", ACTION_BRUSH)
	_btn_brush.custom_minimum_size = Vector2(0, 46)
	box.add_child(_btn_brush)

	# Auto-mur : le gain de temps le plus spectaculaire de l'éditeur, donc
	# pleine largeur et couleur d'accentuation.
	var auto_walls := _make_button("AUTO-MUR   (ceinture le sol)",
		ACTION_AUTO_WALLS)
	auto_walls.custom_minimum_size = Vector2(0, 52)
	_style_button(auto_walls, COL_ACCENT, true)
	box.add_child(auto_walls)

	box.add_child(_make_label("SYMÉTRIE", Charte.T_MENTION, COL_DIM))

	var mirrors := HBoxContainer.new()
	mirrors.add_theme_constant_override("separation", Charte.GAP_XS)
	box.add_child(mirrors)
	mirrors.add_child(_make_button("H", ACTION_MIRROR_H, true))
	mirrors.add_child(_make_button("V", ACTION_MIRROR_V, true))
	mirrors.add_child(_make_button("180°", ACTION_ROTATE_180, true))

	# Les diagonales exigent une grille carrée : on les désactive sinon, avec
	# une infobulle qui dit pourquoi plutôt que de laisser un bouton muet.
	#
	# ⚠️ **Les deux flèches restent dans le libellé** alors que les icônes disent
	# déjà l'axe — seule redondance conservée du panneau. Sans elles, une icône
	# absente laisserait deux boutons voisins lisant tous deux « DIAGONALE » :
	# le repli texte doit rester DISCRIMINANT, sinon ce n'est pas un repli.
	var diagonals := HBoxContainer.new()
	diagonals.add_theme_constant_override("separation", Charte.GAP_XS)
	box.add_child(diagonals)
	_btn_mirror_d = _make_button("DIAGONALE ↘", ACTION_MIRROR_D, true)
	_btn_mirror_ad = _make_button("DIAGONALE ↗", ACTION_MIRROR_AD, true)
	diagonals.add_child(_btn_mirror_d)
	diagonals.add_child(_btn_mirror_ad)

	box.add_child(_make_separator())

	_grid_label = _make_label("TAILLE DE LA GRILLE", Charte.T_MENTION, COL_DIM)
	box.add_child(_grid_label)

	var width_row := HBoxContainer.new()
	width_row.add_theme_constant_override("separation", Charte.GAP_XS)
	box.add_child(width_row)
	width_row.add_child(_make_button("−  LARGEUR", ACTION_GRID_NARROWER, true))
	width_row.add_child(_make_button("+  LARGEUR", ACTION_GRID_WIDER, true))

	var height_row := HBoxContainer.new()
	height_row.add_theme_constant_override("separation", Charte.GAP_XS)
	box.add_child(height_row)
	height_row.add_child(_make_button("−  HAUTEUR", ACTION_GRID_SHORTER, true))
	height_row.add_child(_make_button("+  HAUTEUR", ACTION_GRID_TALLER, true))

	box.add_child(_make_separator())

	var history := HBoxContainer.new()
	history.add_theme_constant_override("separation", Charte.GAP_XS)
	box.add_child(history)
	_btn_undo = _make_button("ANNULER", ACTION_UNDO, true)
	_btn_redo = _make_button("RÉTABLIR", ACTION_REDO, true)
	history.add_child(_btn_undo)
	history.add_child(_btn_redo)

	_history_label = _make_label("Historique vide", Charte.T_MENTION, COL_DIM)
	box.add_child(_history_label)

	var view := HBoxContainer.new()
	view.add_theme_constant_override("separation", Charte.GAP_XS)
	box.add_child(view)
	_btn_light = _make_button("APERÇU LUMIÈRE", ACTION_LIGHT, true)
	view.add_child(_btn_light)
	view.add_child(_make_button("VOIR TOUTE LA CARTE", ACTION_FRAME, true))

	box.add_child(_make_separator())

	var share := HBoxContainer.new()
	share.add_theme_constant_override("separation", Charte.GAP_XS)
	box.add_child(share)
	share.add_child(_make_button("PARTAGER", ACTION_SHARE, true))
	share.add_child(_make_button("IMPORTER", ACTION_IMPORT, true))

	var reset := HBoxContainer.new()
	reset.add_theme_constant_override("separation", Charte.GAP_XS)
	box.add_child(reset)
	reset.add_child(_make_button("NOUVELLE", ACTION_NEW, true))
	reset.add_child(_make_button("TOUT VIDER", ACTION_CLEAR, true))

	return panel

## Actions primaires, hors de la zone défilante : sauvegarder, tester et
## revenir doivent rester atteignables quel que soit le nombre d'outils.
func _build_actions_panel() -> PanelContainer:
	var panel := _make_panel()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Charte.GAP_XS)
	panel.add_child(box)

	# ⚠️ **`💾` était le sixième emoji du dépôt**, et DA4.19 avait déclaré la
	# chasse terminée sur cinq. Il part comme les autres, icône ou non : le garder
	# « en attendant » laisserait le défaut qu'on corrige. SAUVEGARDER, TESTER et
	# RETOUR n'ont pas encore d'icône dessinée — voir `MenuIcones.SANS_ICONE`.
	_btn_save = _make_button("SAUVEGARDER", ACTION_SAVE)
	_btn_save.custom_minimum_size = Vector2(0, 52)
	_style_button(_btn_save, COL_OK, true)
	box.add_child(_btn_save)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", Charte.GAP_XS)
	box.add_child(bottom)
	_btn_test = _make_button("TESTER", ACTION_TEST, true)
	bottom.add_child(_btn_test)
	bottom.add_child(_make_button("RETOUR", ACTION_BACK, true))

	return panel

func _build_prompt_bar() -> void:
	var panel := _make_panel()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_bottom = -20.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Charte.GAP_XXS)
	panel.add_child(box)

	_prompt_pad = _make_label(
		"MANETTE   ✕ tracer (2 coins) · ☐ effacer · L2 bascule libre/rectangle"
		+ " · R2 pot · L1/R1 étape · stick droit caméra · Select annuler · Start sauver",
		Charte.T_MENTION, COL_DIM)
	_prompt_pad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_prompt_pad)

	_prompt_key = _make_label(
		"SOURIS   glisser pour tracer un rectangle · clic droit effacer · B change de pinceau"
		+ " · Maj bascule libre · Ctrl+clic pot · molette zoom · clic molette ou Espace caméra"
		+ " · Ctrl+Z annuler · Tab étape · Ctrl+S sauver",
		Charte.T_MENTION, COL_DIM)
	_prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_prompt_key)

func _build_toast_box() -> void:
	# Bas droite : jamais au centre, où les messages masqueraient le dessin.
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_box.offset_right = -28.0
	_toast_box.offset_bottom = -120.0
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.add_theme_constant_override("separation", Charte.GAP_XS)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_box)

func _build_sandbox_banner() -> void:
	_sandbox_banner = _make_panel(Color(Charte.CARMIN * 0.6, 0.92))
	_sandbox_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_sandbox_banner.offset_top = 24.0
	_sandbox_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sandbox_banner.hide()
	root.add_child(_sandbox_banner)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Charte.GAP_XXS)
	_sandbox_banner.add_child(box)

	var title := _make_label("●  MODE TEST", Charte.T_TITRE, Charte.ROUGE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var hint := _make_label(
		"Rond ou Échap pour revenir à l'édition — votre carte est conservée",
		Charte.T_COURANT, COL_TEXT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

# ---------------------------------------------------------------------------
# MODALES
# ---------------------------------------------------------------------------

func _build_modals() -> void:
	_modal_root = Control.new()
	_modal_root.name = "Modales"
	_modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_root.hide()
	root.add_child(_modal_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(Charte.NOIR, 0.72)
	_modal_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_root.add_child(center)

	_save_panel = _build_save_panel()
	center.add_child(_save_panel)

	_import_panel = _build_import_panel()
	center.add_child(_import_panel)

func _build_save_panel() -> PanelContainer:
	var panel := _make_panel(COL_PANEL_SOFT)
	panel.custom_minimum_size = Vector2(720, 0)
	panel.hide()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Charte.GAP_XS)
	panel.add_child(box)

	box.add_child(_make_label("SAUVEGARDER LA CARTE", Charte.T_TITRE, COL_TEXT))
	box.add_child(_make_label("Nom de la carte", Charte.T_MENTION, COL_DIM))

	_name_edit = LineEdit.new()
	_name_edit.add_theme_font_size_override("font_size", Charte.T_APPUI)
	_name_edit.custom_minimum_size = Vector2(0, 48)
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _emit_save())
	box.add_child(_name_edit)

	_collision_label = _make_label("", Charte.T_COURANT, COL_WARN)
	box.add_child(_collision_label)

	box.add_child(_make_separator())
	box.add_child(_make_label("Cartes existantes — cliquez pour reprendre un nom",
		Charte.T_MENTION, COL_DIM))

	_map_list = ItemList.new()
	_map_list.custom_minimum_size = Vector2(0, 230)
	_map_list.add_theme_font_size_override("font_size", Charte.T_COURANT)
	_map_list.item_selected.connect(_on_map_list_selected)
	box.add_child(_map_list)

	_dialog_error = _make_label("", Charte.T_COURANT, COL_ERROR)
	_dialog_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_error.custom_minimum_size = Vector2(680, 0)
	box.add_child(_dialog_error)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", Charte.GAP_XS)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)

	var cancel := _make_dialog_button("ANNULER", COL_DIM)
	cancel.pressed.connect(close_dialog)
	buttons.add_child(cancel)

	_save_button = _make_dialog_button("SAUVEGARDER", COL_OK)
	_save_button.pressed.connect(_emit_save)
	buttons.add_child(_save_button)

	return panel

func _build_import_panel() -> PanelContainer:
	var panel := _make_panel(COL_PANEL_SOFT)
	panel.custom_minimum_size = Vector2(720, 0)
	panel.hide()

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Charte.GAP_XS)
	panel.add_child(box)

	box.add_child(_make_label("IMPORTER UNE CARTE", Charte.T_TITRE, COL_TEXT))
	box.add_child(_make_label("Collez un code commençant par CANDELA-",
		Charte.T_MENTION, COL_DIM))

	_code_edit = LineEdit.new()
	_code_edit.add_theme_font_size_override("font_size", Charte.T_APPUI)
	_code_edit.custom_minimum_size = Vector2(680, 48)
	_code_edit.placeholder_text = "CANDELA-…"
	_code_edit.text_submitted.connect(func(_t: String) -> void: _emit_import())
	box.add_child(_code_edit)

	var paste := _make_dialog_button("COLLER DEPUIS LE PRESSE-PAPIER", COL_ACCENT)
	paste.pressed.connect(func() -> void:
		_code_edit.text = DisplayServer.clipboard_get().strip_edges()
	)
	box.add_child(paste)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", Charte.GAP_XS)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(buttons)

	var cancel := _make_dialog_button("ANNULER", COL_DIM)
	cancel.pressed.connect(close_dialog)
	buttons.add_child(cancel)

	var confirm := _make_dialog_button("IMPORTER", COL_OK)
	confirm.pressed.connect(_emit_import)
	buttons.add_child(confirm)

	return panel

## Ouvre le dialogue de sauvegarde. `maps` provient de MapData.list_maps().
func open_save_dialog(suggested: String, maps: Array[Dictionary]) -> void:
	_map_names.clear()
	_builtin_names.clear()
	_map_list.clear()

	for entry in maps:
		var map_name := String(entry.get("name", ""))
		var builtin := String(entry.get("source", "")) == "builtin"
		var size: Vector2i = entry.get("grid_size", Vector2i(20, 20))
		_map_names.append(map_name)
		if builtin:
			_builtin_names.append(map_name)
		var suffix := "  ·  livrée (nom réservé)" if builtin else "  ·  %d tuiles" % int(entry.get("floor_count", 0))
		_map_list.add_item("%s   [%d×%d]%s" % [map_name, size.x, size.y, suffix])
		if builtin:
			_map_list.set_item_custom_fg_color(_map_list.item_count - 1, COL_DIM)

	_dialog_error.text = ""
	_name_edit.text = suggested
	_on_name_changed(suggested)

	_import_panel.hide()
	_save_panel.show()
	_open_modal()
	_name_edit.grab_focus()
	_name_edit.select_all()

func open_import_dialog() -> void:
	_code_edit.text = ""
	_save_panel.hide()
	_import_panel.show()
	_open_modal()
	_code_edit.grab_focus()

func close_dialog() -> void:
	if not _modal_root.visible:
		return
	_modal_root.hide()
	_save_panel.hide()
	_import_panel.hide()
	modal_state_changed.emit(false)

func is_modal_open() -> bool:
	return _modal_root != null and _modal_root.visible

## Affiche une erreur dans la modale ouverte sans la refermer.
func show_dialog_error(message: String) -> void:
	_dialog_error.text = "✗  " + message

func _open_modal() -> void:
	_modal_root.show()
	modal_state_changed.emit(true)

func _emit_save() -> void:
	save_confirmed.emit(_name_edit.text.strip_edges())

func _emit_import() -> void:
	import_confirmed.emit(_code_edit.text.strip_edges())

func _on_map_list_selected(index: int) -> void:
	if index < 0 or index >= _map_names.size():
		return
	_name_edit.text = _map_names[index]
	_on_name_changed(_name_edit.text)

func _on_name_changed(new_text: String) -> void:
	var clean := new_text.strip_edges()
	_dialog_error.text = ""

	if clean.is_empty():
		_collision_label.text = "Donnez un nom à votre carte."
		_collision_label.add_theme_color_override("font_color", COL_DIM)
		_save_button.disabled = true
		_save_button.text = "SAUVEGARDER"
		return

	_save_button.disabled = false

	for reserved in _builtin_names:
		if reserved.to_lower() == clean.to_lower():
			_collision_label.text = "« %s » est un nom réservé au jeu." % clean
			_collision_label.add_theme_color_override("font_color", COL_ERROR)
			_save_button.disabled = true
			return

	for existing in _map_names:
		if existing.to_lower() == clean.to_lower():
			_collision_label.text = "Une carte « %s » existe déjà." % existing
			_collision_label.add_theme_color_override("font_color", COL_WARN)
			_save_button.text = "ÉCRASER « %s » ?" % existing
			return

	_collision_label.text = "Nom disponible."
	_collision_label.add_theme_color_override("font_color", COL_OK)
	_save_button.text = "SAUVEGARDER"

# ---------------------------------------------------------------------------
# MISES À JOUR
# ---------------------------------------------------------------------------

func set_map_name(map_name: String) -> void:
	_title_label.text = map_name.to_upper()

func set_grid_info(grid_size: Vector2i, floor_count: int, wall_count: int) -> void:
	_subtitle_label.text = "grille %d×%d  ·  %d sol  ·  %d murs" % [
		grid_size.x, grid_size.y, floor_count, wall_count,
	]

func set_step(index: int, colour: Color) -> void:
	for i in _step_buttons.size():
		_style_step_button(_step_buttons[i],
			_step_colours[i] if i < _step_colours.size() else COL_ACCENT, i == index)
	_tool_label.add_theme_color_override("font_color", colour)

## Ligne d'état sous le titre : outil courant et modificateur actif.
func set_tool_hint(text: String) -> void:
	_tool_label.text = text

func set_history(can_undo: bool, can_redo: bool, undo_label: String) -> void:
	_btn_undo.disabled = not can_undo
	_btn_redo.disabled = not can_redo
	if can_undo:
		_history_label.text = "Annulable : %s" % undo_label
		_history_label.add_theme_color_override("font_color", COL_DIM)
	else:
		_history_label.text = "Historique vide"
		_history_label.add_theme_color_override("font_color", COL_DIM)

## Reflète le pinceau persistant dans le panneau d'outils.
##
## ⚠️ **`slug` et non un nom de fichier.** C'est le seul bouton dont l'icône ne
## se déduit pas de son action — `ACTION_BRUSH` désigne « changer de pinceau »,
## pas « le pinceau courant ». L'appelant connaît le mode ; il passe son slug, et
## `map_editor_hud.gd` continue d'ignorer où vivent les fichiers.
func set_brush(slug: String, label: String, highlight: bool) -> void:
	if is_instance_valid(_btn_brush):
		_btn_brush.text = label
		_style_button(_btn_brush, COL_ACCENT if highlight else COL_BORDER, highlight)
		MenuIcones.poser_outil(_btn_brush, slug, COL_TEXT)

## Affiche la taille de grille et verrouille les diagonales hors grille carrée.
func set_grid_state(size: Vector2i) -> void:
	var square := size.x == size.y
	if is_instance_valid(_grid_label):
		_grid_label.text = "TAILLE DE LA GRILLE   %d×%d" % [size.x, size.y]
	for button in [_btn_mirror_d, _btn_mirror_ad]:
		if not is_instance_valid(button):
			continue
		button.disabled = not square
		button.tooltip_text = "" if square \
			else "Les diagonales échangent largeur et hauteur : grille carrée requise."

func set_light_preview(active: bool) -> void:
	# L'icône de l'ampoule ne change pas : c'est le même bouton, dans deux
	# états. Ce sont le libellé et la couleur qui portent la bascule.
	_btn_light.text = "LUMIÈRE ACTIVE" if active else "APERÇU LUMIÈRE"
	_style_button(_btn_light, COL_ACCENT if active else COL_BORDER, active)

## Affiche le résultat de MapCodec.check_playable() et verrouille en
## conséquence la sauvegarde et le test.
func set_validation(result: Dictionary) -> void:
	var ok := bool(result.get("ok", false))
	var checks: Array = result.get("checks", [])
	_playable = ok

	var signature := "%s|" % ok
	for check in checks:
		signature += "%s%s;" % [check.get("label", ""), check.get("passed", false)]
	if signature != _checks_signature:
		_checks_signature = signature
		_rebuild_checks(checks)

	if ok:
		_verdict_label.text = "✓  CARTE JOUABLE"
		_verdict_label.add_theme_color_override("font_color", COL_OK)
		_reason_label.text = ""
	else:
		_verdict_label.text = "✗  CARTE INJOUABLE"
		_verdict_label.add_theme_color_override("font_color", COL_ERROR)
		_reason_label.text = "Sauvegarde et test bloqués : %s" % _first_blocking_reason(checks)

	_refresh_locks()

## Motif du blocage, en clair, pour l'afficher là où l'utilisateur regarde.
func first_blocking_reason(result: Dictionary) -> String:
	return _first_blocking_reason(result.get("checks", []))

func _first_blocking_reason(checks: Array) -> String:
	for check in checks:
		if bool(check.get("blocking", false)) and not bool(check.get("passed", false)):
			return String(check.get("label", "carte incomplète")).to_lower()
	return "carte incomplète"

func _rebuild_checks(checks: Array) -> void:
	for child in _checks_box.get_children():
		child.queue_free()

	for check in checks:
		var passed := bool(check.get("passed", false))
		var blocking := bool(check.get("blocking", true))

		var symbol := "✓"
		var colour := COL_OK
		if not passed:
			symbol = "✗" if blocking else "⚠"
			colour = COL_ERROR if blocking else COL_WARN

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", Charte.GAP_XS)

		var mark := _make_label(symbol, Charte.T_COURANT, colour)
		mark.custom_minimum_size = Vector2(24, 0)
		row.add_child(mark)

		var text := _make_label(String(check.get("label", "")), Charte.T_COURANT,
			COL_TEXT if passed else colour)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(PANEL_WIDTH - 70.0, 0)
		row.add_child(text)

		_checks_box.add_child(row)

func _refresh_locks() -> void:
	# Une carte cassée ne doit jamais pouvoir être enregistrée ni lancée.
	_btn_save.disabled = not _playable or _sandbox
	_btn_test.disabled = not _playable
	_style_button(_btn_save, COL_OK if _playable else COL_DIM, _playable)

func is_playable() -> bool:
	return _playable

func set_sandbox_mode(active: bool) -> void:
	_sandbox = active
	_sandbox_banner.visible = active
	_step_bar.get_parent().visible = not active
	_prompt_pad.get_parent().get_parent().visible = not active
	_btn_test.text = "QUITTER LE TEST" if active else "TESTER"
	_refresh_locks()

# ---------------------------------------------------------------------------
# TOASTS
# ---------------------------------------------------------------------------

func show_toast(message: String, kind: Toast = Toast.INFO) -> void:
	var colour := COL_TEXT
	var prefix := ""
	match kind:
		Toast.SUCCESS:
			colour = COL_OK
			prefix = "✓  "
		Toast.WARN:
			colour = COL_WARN
			prefix = "⚠  "
		Toast.ERROR:
			colour = COL_ERROR
			prefix = "✗  "
		_:
			colour = COL_ACCENT

	var panel := _make_panel(Color(Charte.SURFACE, 0.94))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0

	var label := _make_label(prefix + message, Charte.T_APPUI, colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	_toast_box.add_child(panel)

	# Au-delà de quatre, les plus anciens disparaissent immédiatement.
	while _toast_box.get_child_count() > 4:
		_toast_box.get_child(0).queue_free()

	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, Charte.D_MOYEN)
	tween.tween_interval(TOAST_LIFETIME)
	tween.tween_property(panel, "modulate:a", 0.0, 0.45)
	tween.tween_callback(panel.queue_free)

# ---------------------------------------------------------------------------
# FABRIQUES DE STYLE
# ---------------------------------------------------------------------------

func _make_panel(background: Color = COL_PANEL) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = COL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(Charte.NOIR, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	return label

func _make_separator() -> HSeparator:
	var separator := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COL_BORDER
	style.content_margin_top = 1
	separator.add_theme_stylebox_override("separator", style)
	return separator

## Un bouton d'action, à la taille de la maison, icône posée si elle existe.
##
## ⚠️ **L'icône se déduit de l'action, et ce n'est pas une commodité.** La clé de
## `MenuIcones.PAR_OUTIL` EST la constante `ACTION_*` : aucun site d'appel n'a
## donc de nom de fichier à répéter, et il devient impossible d'en câbler un sur
## le mauvais bouton. Le seul cas qui déroge — le pinceau, dont l'icône dépend du
## mode et non de l'action — passe par `icone`, explicitement.
##
## **Plus de taille en paramètre.** Le panneau en portait sept (13 à 20) pour
## seize boutons ; la bible en prévoit une pour les libellés de bouton, et la
## primauté se dit déjà par la couleur et la hauteur. Une troisième voie pour la
## même chose ne hiérarchise pas, elle brouille.
func _make_button(text: String, action: StringName,
		expand: bool = false, icone: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", Charte.T_COURANT)
	button.custom_minimum_size = Vector2(0, 40)
	if expand:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: action_requested.emit(action))
	_style_button(button, COL_BORDER, false)
	MenuIcones.poser_outil(button, icone if icone != "" else String(action),
		COL_TEXT)
	return button

func _make_dialog_button(text: String, colour: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", Charte.T_APPUI)
	button.custom_minimum_size = Vector2(220, 52)
	_style_button(button, colour, true)
	return button

func _style_button(button: Button, tint: Color, strong: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(tint.r, tint.g, tint.b, 0.16 if strong else 0.06)
	normal.border_color = Color(tint.r, tint.g, tint.b, 0.85 if strong else 0.40)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.set_content_margin_all(8)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(tint.r, tint.g, tint.b, 0.30)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(tint.r, tint.g, tint.b, 0.46)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(Charte.SOL_A, 0.55)
	disabled.border_color = Color(Charte.LINE * 1.55, 0.45)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", COL_TEXT)
	button.add_theme_color_override("font_hover_color", Charte.HALOGENE)
	button.add_theme_color_override("font_disabled_color", COL_DIM)

func _style_step_button(button: Button, tint: Color, active: bool) -> void:
	_style_button(button, tint, active)
	button.add_theme_color_override("font_color", tint if active else COL_DIM)
