class_name MenuHub
extends Control

## Ossature de navigation du menu — Phase 5, structure B.
##
## Un accueil de grandes destinations, chacune un écran entier avec son retour.
## Cette classe ne connaît **aucun** contenu : elle sait empiler des écrans,
## revenir, et n'afficher que le courant. Ce que chaque écran raconte est rempli
## par l'appelant, à l'étape 3.
##
## ## Pourquoi une pile et non un parent déclaré
##
## Un écran peut s'atteindre par deux chemins — la galerie de cartes s'ouvre
## depuis la préparation locale comme depuis le salon en ligne. Un parent fixe
## renverrait alors le joueur au mauvais endroit, ce qui est le genre de défaut
## qu'on ne voit qu'en jeu et qu'on met longtemps à croire. La pile renvoie
## toujours d'où l'on vient.
##
## ## Ce que l'ossature garantit
##
## - L'accueil est le fond de pile et ne peut pas en être retiré.
## - Un seul corps d'écran est visible à la fois ; les autres sont cachés, donc
##   hors d'atteinte du curseur (voir `_collect_focusables` côté `ui.gd`).
## - Empiler l'écran courant ne fait rien : sans cela, un double appui sur une
##   entrée obligerait à deux retours pour un seul aller.

## Émis après chaque changement d'écran, y compris les retours.
signal screen_changed(id: String)
## Émis quand on tente de revenir depuis l'accueil. À l'appelant de décider ce
## que ça veut dire — quitter le jeu, ou rien.
signal back_at_root()

const ROOT := "accueil"

## Corps de chaque écran, par identifiant.
var _bodies: Dictionary = {}
## Titre de chaque écran, par identifiant.
var _titles: Dictionary = {}
## Chemin courant. `[ROOT]` au minimum, jamais vide.
var _stack: PackedStringArray = PackedStringArray([ROOT])

var _title_label: Label
var _back_hint: Label
var _content: Control
var _tween: Tween

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = MenuTheme.BACKDROP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_top", MenuTheme.GAP_L)
	outer.add_theme_constant_override("margin_bottom", MenuTheme.GAP_L)
	outer.add_theme_constant_override("margin_left", MenuTheme.GAP_L + MenuTheme.GAP_S)
	outer.add_theme_constant_override("margin_right", MenuTheme.GAP_L + MenuTheme.GAP_S)
	add_child(outer)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", MenuTheme.GAP_M)
	outer.add_child(root_box)

	root_box.add_child(_build_header())

	# Les corps sont ancrés en plein cadre pour pouvoir glisser latéralement sans
	# perturber la mise en page — même procédé que les onglets qu'ils remplacent.
	_content = Control.new()
	_content.custom_minimum_size = Vector2(0, 440)
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	root_box.add_child(_content)

func _build_header() -> Control:
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", MenuTheme.GAP_XS)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 46)
	_title_label.add_theme_color_override("font_color", MenuTheme.GOLD)
	header.add_child(_title_label)

	# Le retour n'est pas un bouton : c'est un rappel de touche. Un bouton
	# « Retour » à parcourir au curseur coûterait un déplacement à chaque écran,
	# alors que le geste existe déjà sous le pouce.
	_back_hint = Label.new()
	_back_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_hint.add_theme_font_size_override("font_size", 14)
	_back_hint.add_theme_color_override("font_color", MenuTheme.DIM)
	_back_hint.hide()
	header.add_child(_back_hint)

	return header

# ---------------------------------------------------------------------------
# DÉCLARATION DES ÉCRANS
# ---------------------------------------------------------------------------

## Déclare un écran et rend son corps, à remplir par l'appelant.
##
## Redéclarer un identifiant existant rend le corps déjà créé plutôt que d'en
## empiler un second : c'est ce qui permet à l'étape 3 de remplir les écrans en
## plusieurs passes sans les dupliquer.
func add_screen(id: String, title: String) -> VBoxContainer:
	_titles[id] = title
	if _bodies.has(id):
		return _bodies[id]

	var body := VBoxContainer.new()
	body.name = "Screen_" + id
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", MenuTheme.GAP_M)
	body.hide()
	_content.add_child(body)
	_bodies[id] = body
	return body

func has_screen(id: String) -> bool:
	return _bodies.has(id)

func body_of(id: String) -> VBoxContainer:
	return _bodies.get(id, null)

# ---------------------------------------------------------------------------
# NAVIGATION
# ---------------------------------------------------------------------------

func current_id() -> String:
	return _stack[_stack.size() - 1]

## Profondeur courante : 0 à l'accueil.
func depth() -> int:
	return _stack.size() - 1

## Descend d'un cran. Sans effet si l'écran n'existe pas ou si on y est déjà.
func push(id: String) -> bool:
	if not _bodies.has(id) or id == current_id():
		return false
	_stack.append(id)
	_apply(1.0)
	return true

## Remonte d'un cran. Rend false à l'accueil, où il n'y a rien au-dessus —
## `back_at_root` est alors émis pour que l'appelant en décide.
func back() -> bool:
	if _stack.size() <= 1:
		back_at_root.emit()
		return false
	_stack.remove_at(_stack.size() - 1)
	_apply(-1.0)
	return true

## Retour direct à l'accueil, sans repasser par les écrans intermédiaires.
## Utilisé à l'ouverture du menu : on ne rouvre jamais un menu là où on l'avait
## laissé trois écrans plus bas.
func reset() -> void:
	_stack = PackedStringArray([ROOT])
	_apply(0.0)

func _apply(direction: float) -> void:
	var id := current_id()
	for key in _bodies.keys():
		var body: Control = _bodies[key]
		if body != null and key != id:
			body.hide()

	var target: Control = _bodies.get(id, null)
	if target == null:
		return
	target.show()

	_title_label.text = String(_titles.get(id, id)).to_upper()
	if depth() > 0:
		_back_hint.text = "ÉCHAP  ·  RETOUR"
		_back_hint.show()
	else:
		_back_hint.hide()

	if direction != 0.0:
		_slide(target, direction)
	else:
		_reset_transform(target)

	screen_changed.emit(id)

## Fondu court plus glissement dans le sens du déplacement : descendre pousse
## vers la gauche, remonter ramène depuis la gauche. Le sens fait sentir la
## profondeur sans qu'on ait à l'écrire à l'écran.
func _slide(body: Control, direction: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var offset := MenuTheme.SLIDE * direction
	body.modulate.a = 0.0
	body.offset_left = offset
	body.offset_right = offset

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(body, "modulate:a", 1.0, MenuTheme.FADE)
	_tween.tween_property(body, "offset_left", 0.0, MenuTheme.FADE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(body, "offset_right", 0.0, MenuTheme.FADE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _reset_transform(body: Control) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	body.modulate.a = 1.0
	body.offset_left = 0.0
	body.offset_right = 0.0

# ---------------------------------------------------------------------------
# ENTRÉES
# ---------------------------------------------------------------------------

## Grande entrée de destination : un titre, une ligne d'explication, un chevron.
##
## `target` vide produit une entrée d'action, que l'appelant branche lui-même sur
## `pressed`. C'est la différence entre « aller quelque part » et « faire quelque
## chose », et elle se voit : seules les destinations portent un chevron.
func make_entry(label: String, subtitle: String, target: String = "",
		accent: Color = MenuTheme.P1) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(460, 72)
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var normal := StyleBoxFlat.new()
	normal.bg_color = MenuTheme.SURFACE
	normal.set_border_width_all(2)
	normal.border_color = MenuTheme.LINE
	normal.set_corner_radius_all(12)
	normal.content_margin_left = MenuTheme.GAP_S
	normal.content_margin_right = MenuTheme.GAP_S
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = accent
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.08)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, MenuTheme.GAP_S)
	row.add_theme_constant_override("separation", MenuTheme.GAP_S)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)

	var title := Label.new()
	title.text = label
	title.add_theme_font_size_override("font_size", 22)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(title)

	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.add_theme_font_size_override("font_size", 13)
		sub.add_theme_color_override("font_color", MenuTheme.DIM)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(sub)

	if target != "":
		var chevron := Label.new()
		chevron.text = "›"
		chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chevron.add_theme_font_size_override("font_size", 26)
		chevron.add_theme_color_override("font_color", accent)
		chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chevron)

		btn.pressed.connect(func() -> void: push(target))

	return btn
