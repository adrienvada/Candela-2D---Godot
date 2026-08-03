## MapGallery — Galerie de sélection de cartes.
##
## Composant autonome et réutilisable : on l'ajoute n'importe où dans un arbre
## de Control, il se branche seul sur l'autoload MapData et se reconstruit à
## chaque changement de catalogue. Il ne connaît rien du menu qui l'héberge et
## communique uniquement par le signal `map_chosen`.
##
## Contenu : une grille défilante de tuiles 160×160 (miniature + nom + taille de
## grille + badge d'origine), une tuile « + Créer » qui ouvre l'éditeur, et une
## barre d'actions Importer / Partager / Supprimer.
##
## La navigation manette est assurée par le menu hôte : toutes les tuiles sont
## des Button focusables ordinaires, donc trouvées automatiquement par un
## résolveur de focus géométrique.

class_name MapGallery
extends Control

## Émis quand le joueur choisit une carte (la sélection est déjà appliquée à MapData).
signal map_chosen(map_id: String)
## Émis juste avant de basculer vers l'éditeur de cartes.
signal editor_requested

const TILE_SIZE := Vector2(160, 160)
const THUMB_PX := 96
const TILE_GAP := 16

const COLOR_P1 := Color(0.0, 0.94, 1.0)
const COLOR_P2 := Color(1.0, 0.0, 0.33)
const COLOR_DIM := Color(0.52, 0.55, 0.63)
const COLOR_OK := Color(0.35, 1.0, 0.6)
const COLOR_ERROR := Color(1.0, 0.35, 0.45)

## Délai avant qu'un « CONFIRMER ? » de suppression ne redevienne « SUPPRIMER ».
const DELETE_CONFIRM_DELAY := 3.0
const TOAST_DURATION := 2.4

var _scroll: ScrollContainer
var _grid: GridContainer
var _tile_group: ButtonGroup

var _btn_import: Button
var _btn_share: Button
var _btn_delete: Button
var _import_row: HBoxContainer
var _import_field: LineEdit
var _btn_import_ok: Button
var _btn_import_cancel: Button

var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween

var _empty_label: Label

## Tuiles de carte uniquement (la tuile « + Créer » n'en fait pas partie).
var _tiles: Array[Button] = []
var _tile_create: Button

## Styles partagés. `_style_selected` est animé, d'où une instance dédiée.
var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_selected: StyleBoxFlat

var _delete_armed: bool = false
var _delete_timer: float = 0.0
var _pulse: float = 0.0

# ---------------------------------------------------------------------------
# CONSTRUCTION
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Le menu peut s'afficher arbre en pause : la galerie doit rester vivante.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

	MapData.catalog_changed.connect(_on_catalog_changed)
	MapData.map_selected.connect(_on_map_selected)

	_rebuild_tiles()

func _build() -> void:
	_build_styles()

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	root.add_child(_build_header())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.resized.connect(_update_columns)
	root.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", TILE_GAP)
	_grid.add_theme_constant_override("v_separation", TILE_GAP)
	_scroll.add_child(_grid)

	_empty_label = Label.new()
	_empty_label.text = "Aucune carte pour l'instant — créez-en une."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", 14)
	_empty_label.add_theme_color_override("font_color", COLOR_DIM)
	_empty_label.hide()
	root.add_child(_empty_label)

	root.add_child(_build_import_row())
	root.add_child(_build_actions())
	root.add_child(_build_toast())

func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)

	var title := Label.new()
	title.text = "C A R T E S"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var hint := Label.new()
	hint.text = "La carte choisie reste active toute la session"
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", COLOR_DIM)
	header.add_child(hint)

	return header

func _build_import_row() -> Control:
	_import_row = HBoxContainer.new()
	_import_row.add_theme_constant_override("separation", 8)
	_import_row.hide()

	_import_field = LineEdit.new()
	_import_field.placeholder_text = "Collez un code CANDELA-…"
	_import_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_import_field.custom_minimum_size = Vector2(0, 40)
	_import_field.text_submitted.connect(func(_t: String) -> void: _confirm_import())
	_import_row.add_child(_import_field)

	_btn_import_ok = _make_action_button("VALIDER", COLOR_OK)
	_btn_import_ok.pressed.connect(_confirm_import)
	_import_row.add_child(_btn_import_ok)

	_btn_import_cancel = _make_action_button("ANNULER", COLOR_DIM)
	_btn_import_cancel.pressed.connect(_close_import)
	_import_row.add_child(_btn_import_cancel)

	return _import_row

func _build_actions() -> Control:
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)

	_btn_import = _make_action_button("IMPORTER UN CODE", COLOR_P1)
	_btn_import.pressed.connect(_open_import)
	actions.add_child(_btn_import)

	_btn_share = _make_action_button("PARTAGER", Color.WHITE)
	_btn_share.pressed.connect(_share_selected)
	actions.add_child(_btn_share)

	_btn_delete = _make_action_button("SUPPRIMER", COLOR_P2)
	_btn_delete.pressed.connect(_delete_selected)
	actions.add_child(_btn_delete)

	return actions

func _build_toast() -> Control:
	_toast_panel = PanelContainer.new()
	_toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast_panel.modulate.a = 0.0
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.96)
	style.set_border_width_all(1)
	style.border_color = Color(0.35, 0.38, 0.45)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_toast_panel.add_theme_stylebox_override("panel", style)

	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 13)
	_toast_panel.add_child(_toast_label)

	return _toast_panel

# ---------------------------------------------------------------------------
# STYLES
# ---------------------------------------------------------------------------

func _build_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.05, 0.055, 0.075, 0.92)
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = Color(0.18, 0.19, 0.24)
	_style_normal.set_corner_radius_all(10)
	_style_normal.content_margin_left = 8
	_style_normal.content_margin_right = 8
	_style_normal.content_margin_top = 8
	_style_normal.content_margin_bottom = 8

	_style_hover = _style_normal.duplicate() as StyleBoxFlat
	_style_hover.border_color = Color(0.55, 0.6, 0.7)
	_style_hover.bg_color = Color(0.08, 0.09, 0.12, 0.96)

	_style_selected = _style_normal.duplicate() as StyleBoxFlat
	_style_selected.border_color = COLOR_P1
	_style_selected.bg_color = Color(0.04, 0.1, 0.13, 0.96)
	_style_selected.shadow_color = Color(COLOR_P1.r, COLOR_P1.g, COLOR_P1.b, 0.35)
	_style_selected.shadow_size = 8

func _make_action_button(label: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_font_size_override("font_size", 14)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.055, 0.075, 0.92)
	normal.set_border_width_all(2)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = accent
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.3)
	pressed.border_color = Color.WHITE
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.border_color = Color(0.16, 0.17, 0.2)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color(0.32, 0.33, 0.38))

	btn.pressed.connect(_press_feedback.bind(btn))
	return btn

## Petit à-coup d'échelle : retour visuel immédiat sur chaque appui.
func _press_feedback(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.pivot_offset = control.size / 2.0
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(0.94, 0.94), 0.06)
	tween.tween_property(control, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------------------
# TUILES
# ---------------------------------------------------------------------------

func _rebuild_tiles() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_tiles.clear()
	_tile_create = null
	_tile_group = ButtonGroup.new()

	var maps := MapData.list_maps()
	for entry in maps:
		var tile := _make_map_tile(entry)
		_grid.add_child(tile)
		_tiles.append(tile)

	_tile_create = _make_create_tile()
	_grid.add_child(_tile_create)

	_empty_label.visible = maps.is_empty()
	_update_columns()
	_sync_selection()
	_disarm_delete()

func _make_map_tile(entry: Dictionary) -> Button:
	var map_id := String(entry["id"])
	var source := String(entry["source"])
	var grid_size: Vector2i = entry["grid_size"]

	var tile := Button.new()
	tile.toggle_mode = true
	tile.button_group = _tile_group
	tile.custom_minimum_size = TILE_SIZE
	tile.focus_mode = Control.FOCUS_ALL
	tile.tooltip_text = "%s — %d×%d, %d murs" % [
		String(entry["name"]), grid_size.x, grid_size.y, int(entry["wall_count"]),
	]
	tile.set_meta("map_id", map_id)
	tile.set_meta("map_source", source)
	tile.add_theme_stylebox_override("normal", _style_normal)
	tile.add_theme_stylebox_override("focus", _style_normal)
	tile.add_theme_stylebox_override("hover", _style_hover)
	tile.add_theme_stylebox_override("pressed", _style_selected)
	tile.add_theme_stylebox_override("hover_pressed", _style_selected)
	tile.pressed.connect(_on_tile_pressed.bind(map_id))

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	tile.add_child(box)

	var thumb := TextureRect.new()
	thumb.texture = MapThumbnail.render_fit(entry["data"], THUMB_PX)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Pixels francs : une miniature de 80 px agrandie ne doit pas devenir floue.
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(thumb)

	var name_label := Label.new()
	name_label.text = String(entry["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var meta := Label.new()
	meta.text = "%d×%d" % [grid_size.x, grid_size.y]
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", COLOR_DIM)
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(meta)

	var badge := Label.new()
	badge.text = "OFFICIELLE" if source == "builtin" else "PERSO"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color",
		Color(1.0, 0.8, 0.0) if source == "builtin" else COLOR_P2)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(badge)

	return tile

func _make_create_tile() -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = TILE_SIZE
	tile.focus_mode = Control.FOCUS_ALL
	tile.tooltip_text = "Créer une nouvelle carte dans l'éditeur"

	var dashed := _style_normal.duplicate() as StyleBoxFlat
	dashed.bg_color = Color(0.03, 0.035, 0.05, 0.7)
	dashed.border_color = Color(0.35, 0.38, 0.45)
	tile.add_theme_stylebox_override("normal", dashed)
	tile.add_theme_stylebox_override("focus", dashed)

	var hover := dashed.duplicate() as StyleBoxFlat
	hover.border_color = Color(1.0, 0.8, 0.0)
	hover.bg_color = Color(0.1, 0.08, 0.02, 0.9)
	tile.add_theme_stylebox_override("hover", hover)
	tile.add_theme_stylebox_override("pressed", hover)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	tile.add_child(box)

	var plus := Label.new()
	plus.text = "+"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.add_theme_font_size_override("font_size", 48)
	plus.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(plus)

	var label := Label.new()
	label.text = "CRÉER"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	tile.pressed.connect(_open_editor)
	return tile

## Nombre de colonnes déduit de la largeur disponible : la grille suit la fenêtre.
func _update_columns() -> void:
	if _grid == null or _scroll == null:
		return
	var usable := _scroll.size.x
	if usable <= 0.0:
		return
	_grid.columns = maxi(1, floori(usable / (TILE_SIZE.x + float(TILE_GAP))))

# ---------------------------------------------------------------------------
# SÉLECTION
# ---------------------------------------------------------------------------

func _on_tile_pressed(map_id: String) -> void:
	_click_sound()
	_disarm_delete()
	for tile in _tiles:
		if String(tile.get_meta("map_id", "")) == map_id:
			_press_feedback(tile)
			break
	if MapData.select_map(map_id):
		map_chosen.emit(map_id)

func _on_map_selected(_map_id: String) -> void:
	_sync_selection()

func _on_catalog_changed() -> void:
	# Une carte ré-enregistrée garde son id : le cache doit être invalidé en bloc.
	MapThumbnail.clear_cache()
	_rebuild_tiles()

## Aligne l'état visuel des tuiles et des actions sur la sélection de MapData.
func _sync_selection() -> void:
	var selected := MapData.selected_map_id
	var found := false
	for tile in _tiles:
		var is_selected: bool = String(tile.get_meta("map_id", "")) == selected
		tile.set_pressed_no_signal(is_selected)
		if is_selected:
			found = true
	_btn_share.disabled = not found
	_btn_delete.disabled = not (found and _selected_source() == "user")
	if _btn_delete.disabled:
		_disarm_delete()

func _selected_entry() -> Dictionary:
	return MapData.get_map(MapData.selected_map_id)

func _selected_source() -> String:
	var entry := _selected_entry()
	return String(entry.get("source", "")) if not entry.is_empty() else ""

# ---------------------------------------------------------------------------
# ACTIONS
# ---------------------------------------------------------------------------

func _open_editor() -> void:
	_click_sound()
	editor_requested.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://map_editor.tscn")

func _share_selected() -> void:
	_click_sound()
	_disarm_delete()
	var entry := _selected_entry()
	if entry.is_empty():
		_toast("Aucune carte sélectionnée", COLOR_ERROR)
		return

	var code := MapData.to_share_code(entry["data"])
	if code.is_empty():
		_toast("Impossible de générer le code de partage", COLOR_ERROR)
		return

	DisplayServer.clipboard_set(code)
	_toast("Code de « %s » copié (%d caractères)" % [String(entry["name"]), code.length()], COLOR_OK)

func _open_import() -> void:
	_click_sound()
	_disarm_delete()
	_import_row.show()
	# Pratique : si le presse-papier contient déjà un code, on le pré-remplit.
	var clip := DisplayServer.clipboard_get()
	if clip.begins_with(MapCodec.SHARE_PREFIX):
		_import_field.text = clip
	_import_field.grab_focus()
	_import_field.caret_column = _import_field.text.length()

func _close_import() -> void:
	_import_field.text = ""
	_import_row.hide()

func _confirm_import() -> void:
	var code := _import_field.text.strip_edges()
	if code.is_empty():
		_toast("Collez d'abord un code de partage", COLOR_ERROR)
		return

	var result := MapData.import_share_code(code)
	if not result["ok"]:
		# L'erreur de MapCodec est déjà rédigée en clair pour le joueur.
		_toast("Import refusé : %s" % String(result["error"]), COLOR_ERROR)
		return

	_close_import()
	MapData.select_map(String(result["id"]))
	map_chosen.emit(String(result["id"]))
	_toast("« %s » importée et sélectionnée" % String(result["name"]), COLOR_OK)

func _delete_selected() -> void:
	_click_sound()
	var entry := _selected_entry()
	if entry.is_empty() or String(entry["source"]) != "user":
		_toast("Seules les cartes perso peuvent être supprimées", COLOR_ERROR)
		return

	# Confirmation en deux temps : plus direct qu'une modale, et compatible manette.
	if not _delete_armed:
		_delete_armed = true
		_delete_timer = DELETE_CONFIRM_DELAY
		_btn_delete.text = "CONFIRMER ?"
		_btn_delete.add_theme_color_override("font_color", COLOR_P2)
		return

	var map_name := String(entry["name"])
	_disarm_delete()
	if MapData.delete_map(String(entry["id"])):
		_toast("« %s » supprimée" % map_name, COLOR_OK)
	else:
		_toast("Suppression impossible", COLOR_ERROR)

func _disarm_delete() -> void:
	_delete_armed = false
	_delete_timer = 0.0
	if _btn_delete != null:
		_btn_delete.text = "SUPPRIMER"
		_btn_delete.remove_theme_color_override("font_color")

# ---------------------------------------------------------------------------
# RETOURS VISUELS
# ---------------------------------------------------------------------------

## Message éphémère en bas de la galerie.
func _toast(message: String, tint: Color) -> void:
	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", tint)

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(TOAST_DURATION)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.35)

func _process(delta: float) -> void:
	# Liseré néon animé sur la carte sélectionnée.
	_pulse += delta
	if _style_selected != null:
		var wave := 0.5 + 0.5 * sin(_pulse * 4.0)
		_style_selected.border_color = COLOR_P1.lerp(Color.WHITE, 0.4 * wave)
		_style_selected.shadow_size = int(roundf(lerpf(6.0, 14.0, wave)))
		_style_selected.shadow_color = Color(COLOR_P1.r, COLOR_P1.g, COLOR_P1.b, 0.2 + 0.3 * wave)

	if _delete_armed:
		_delete_timer -= delta
		if _delete_timer <= 0.0:
			_disarm_delete()

func _click_sound() -> void:
	# Autoload optionnel : la galerie doit rester utilisable hors du jeu complet.
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_button_click"):
		audio.play_button_click()

# ---------------------------------------------------------------------------
# API PUBLIQUE
# ---------------------------------------------------------------------------

## Fait défiler la galerie pour amener `control` dans le champ de vision.
## Sans effet si le contrôle n'appartient pas à la grille.
func reveal(control: Control) -> void:
	if control == null or _scroll == null or not is_ancestor_of(control):
		return
	var top := control.global_position.y - _grid.global_position.y
	var bottom := top + control.size.y
	var view := _scroll.size.y
	var offset := _scroll.scroll_vertical
	if top < float(offset):
		_scroll.scroll_vertical = int(top)
	elif bottom > float(offset) + view:
		_scroll.scroll_vertical = int(bottom - view)

## Première tuile de la galerie, point d'entrée naturel du focus manette.
func first_focusable() -> Control:
	if not _tiles.is_empty():
		return _tiles[0]
	return _tile_create

## Bouton correspondant à la carte actuellement sélectionnée, ou null.
func selected_tile() -> Control:
	for tile in _tiles:
		if String(tile.get_meta("map_id", "")) == MapData.selected_map_id:
			return tile
	return null
