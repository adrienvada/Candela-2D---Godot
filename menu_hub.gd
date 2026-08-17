class_name MenuHub
extends Control

## Hub de navigation en deux panneaux — Phase 5, structure B.
##
## À gauche la liste des entrées, à droite ce que l'entrée sous le curseur
## raconte. Ce n'est pas une décoration : cela permet à une entrée de **montrer
## une information sans faire descendre d'un cran**. « Top 10 » n'ouvre pas un
## sous-menu, il remplit le panneau de droite. Un menu qui obligerait à entrer
## puis à ressortir pour lire trois lignes ferait payer un aller-retour pour une
## consultation.
##
## Trois natures d'entrée, et la différence se voit à l'œil :
##
## - **destination** — porte un chevron, descend d'un cran ;
## - **information** — pas de chevron, remplit le panneau de droite ;
## - **action** — pas de chevron, émet un signal (lancer, quitter).
##
## Une entrée peut être **indisponible** : elle reste visible, grisée, et le
## panneau de droite dit pourquoi. La masquer laisserait croire qu'elle n'existe
## pas ; la retirer du parcours du curseur ferait douter du bouton d'à côté.
##
## ## Le retour est un bouton, pas un rappel de touche
##
## La version précédente affichait « ÉCHAP · RETOUR » sans que rien ne soit
## cliquable — et sans que la touche fasse quoi que ce soit. Un libellé qui
## annonce une commande inexistante est pire qu'une absence de libellé. Le retour
## est donc une entrée comme les autres, en bas de chaque liste, atteignable au
## curseur et à la souris ; la touche le double, elle ne le remplace pas.

## Émis après chaque changement d'écran, retours compris.
signal screen_changed(id: String)
## Tentative de retour depuis l'accueil. À l'appelant d'en décider.
signal back_at_root()
## Une entrée d'action a été activée.
signal action_requested(action: String)
## Ce que l'entrée sous le curseur raconte. L'en-tête du jeu l'affiche : c'est le
## seul endroit où le regard passe déjà.
signal detail_changed(title: String, text: String)

const ROOT := "accueil"

## Racine de chaque écran : c'est elle qu'on montre et qu'on cache.
var _roots: Dictionary = {}
## Colonne de gauche de chaque écran, à remplir par l'appelant.
var _lists: Dictionary = {}
## Panneau de droite par défaut de chaque écran.
var _asides: Dictionary = {}
var _titles: Dictionary = {}

## Chemin courant. Jamais vide : `ROOT` en est le fond.
var _stack: PackedStringArray = PackedStringArray([ROOT])

var _title_label: Label
var _detail_host: VBoxContainer
var _detail_title: Label
var _detail_text: RichTextLabel
var _tween: Tween

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var columns := HBoxContainer.new()
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	columns.add_theme_constant_override("separation", MenuTheme.GAP_L)
	add_child(columns)

	# --- Colonne de gauche : le titre et les écrans empilés -------------------
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_theme_constant_override("separation", MenuTheme.GAP_S)
	columns.add_child(left)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", MenuTheme.GOLD)
	left.add_child(_title_label)

	# Les racines d'écran sont ancrées en plein cadre pour pouvoir glisser
	# latéralement sans perturber la mise en page.
	var host := Control.new()
	host.custom_minimum_size = Vector2(0, 420)
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.clip_contents = true
	left.add_child(host)
	_host = host

	# --- Colonne de droite : ce que l'entrée sous le curseur raconte ----------
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = MenuTheme.SURFACE
	style.set_border_width_all(1)
	style.border_color = MenuTheme.LINE
	style.set_corner_radius_all(12)
	style.content_margin_left = MenuTheme.GAP_M
	style.content_margin_right = MenuTheme.GAP_M
	style.content_margin_top = MenuTheme.GAP_M
	style.content_margin_bottom = MenuTheme.GAP_M
	right.add_theme_stylebox_override("panel", style)
	columns.add_child(right)

	# Aligné en haut : un contenu centré verticalement saute d'un écran à l'autre
	# selon sa hauteur, et le regard doit le rattraper à chaque fois.
	_detail_host = VBoxContainer.new()
	_detail_host.alignment = BoxContainer.ALIGNMENT_BEGIN
	_detail_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_detail_host.add_theme_constant_override("separation", MenuTheme.GAP_S)
	right.add_child(_detail_host)

	# Le panneau de droite ne porte plus la description : elle est montée dans
	# l'en-tête du jeu, sous le titre, à la place d'un « PRÊT À JOUER ? » qui ne
	# disait rien. Lire l'explication d'une entrée ne devrait pas demander de
	# traverser l'écran du regard.
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 20)
	_detail_title.add_theme_color_override("font_color", MenuTheme.P1)
	_detail_title.hide()
	_detail_host.add_child(_detail_title)

	_detail_text = RichTextLabel.new()
	_detail_text.bbcode_enabled = true
	_detail_text.fit_content = true
	_detail_text.add_theme_font_size_override("normal_font_size", 15)
	_detail_text.add_theme_color_override("default_color", MenuTheme.DIM)
	_detail_text.hide()
	_detail_host.add_child(_detail_text)

var _host: Control

# ---------------------------------------------------------------------------
# DÉCLARATION
# ---------------------------------------------------------------------------

## Déclare un écran et rend sa colonne de gauche, à remplir par l'appelant.
##
## Attention : `body_of()` rend la **racine** de l'écran — celle qu'on montre et
## qu'on cache — et non cette colonne. Les deux sont distinctes depuis le passage
## en deux panneaux.
func add_screen(id: String, title: String) -> VBoxContainer:
	_titles[id] = title
	if _lists.has(id):
		return _lists[id]

	var root := HBoxContainer.new()
	root.name = "Screen_" + id
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.hide()
	_host.add_child(root)

	var list := VBoxContainer.new()
	list.alignment = BoxContainer.ALIGNMENT_BEGIN
	list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", MenuTheme.GAP_XS)
	root.add_child(list)

	_roots[id] = root
	_lists[id] = list
	return list

## Panneau de droite montré quand aucune entrée n'a de contenu propre.
func set_aside(id: String, title: String, text: String) -> void:
	_asides[id] = {"titre": title, "texte": text}

func has_screen(id: String) -> bool:
	return _lists.has(id)

func body_of(id: String) -> Control:
	return _roots.get(id, null)

func list_of(id: String) -> VBoxContainer:
	return _lists.get(id, null)

# ---------------------------------------------------------------------------
# NAVIGATION
# ---------------------------------------------------------------------------

func current_id() -> String:
	return _stack[_stack.size() - 1]

func depth() -> int:
	return _stack.size() - 1

func push(id: String) -> bool:
	if not _lists.has(id) or id == current_id():
		return false
	_stack.append(id)
	_apply(1.0)
	return true

func back() -> bool:
	if _stack.size() <= 1:
		back_at_root.emit()
		return false
	_stack.remove_at(_stack.size() - 1)
	_apply(-1.0)
	return true

func reset() -> void:
	_stack = PackedStringArray([ROOT])
	_apply(0.0)

func _apply(direction: float) -> void:
	var id := current_id()
	for key in _roots.keys():
		var root: Control = _roots[key]
		if root != null and key != id:
			root.hide()

	var target: Control = _roots.get(id, null)
	if target == null:
		return
	target.show()

	_title_label.text = String(_titles.get(id, id)).to_upper()
	_show_aside(id)

	if direction != 0.0:
		_slide(target, direction)
	else:
		_reset_transform(target)

	screen_changed.emit(id)

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
# PANNEAU DE DROITE
# ---------------------------------------------------------------------------

## Contenu par défaut de l'écran courant : ce qu'on lit quand rien n'est survolé.
func _show_aside(id: String) -> void:
	var a: Variant = _asides.get(id, null)
	if a is Dictionary:
		show_detail(String((a as Dictionary)["titre"]), String((a as Dictionary)["texte"]))
	else:
		show_detail(String(_titles.get(id, "")), "")

## Remplit le panneau de droite. Les entrées d'information passent par ici.
func show_detail(title: String, text: String) -> void:
	_detail_title.text = title
	_detail_text.text = text
	detail_changed.emit(title, text)

## Rend le panneau de droite pour qu'un appelant y installe un affichage riche
## (un tableau, une liste). À utiliser avec parcimonie : le texte suffit presque
## toujours, et un panneau qui se reconstruit à chaque déplacement du curseur
## scintille.
func detail_host() -> VBoxContainer:
	return _detail_host

# ---------------------------------------------------------------------------
# ENTRÉES
# ---------------------------------------------------------------------------

## Une entrée de la colonne de gauche.
##
## `target` non vide en fait une destination ; sinon `action` en fait une action ;
## sinon c'est une entrée d'information, qui ne fait que remplir la droite.
## `reason` non vide la rend indisponible : visible, grisée, et le panneau de
## droite dit pourquoi.
## `launcher` donne le style plein du bouton de lancement : c'est le geste qui
## engage une partie, et il doit se distinguer de tout ce qui n'engage rien.
func make_entry(label: String, detail: String, target: String = "",
		accent: Color = MenuTheme.P1, action: String = "",
		reason: String = "", launcher: bool = false) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 54)
	btn.focus_mode = Control.FOCUS_ALL
	btn.disabled = reason != ""

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.18) if launcher else MenuTheme.SURFACE
	normal.set_border_width_all(2 if launcher else 1)
	normal.border_color = accent if launcher else MenuTheme.LINE
	normal.set_corner_radius_all(10)
	normal.content_margin_left = MenuTheme.GAP_S
	normal.content_margin_right = MenuTheme.GAP_S
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("disabled", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = accent
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.09)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("pressed", hover)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, MenuTheme.GAP_S)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color",
		MenuTheme.DIM if btn.disabled else Color.WHITE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	# Le chevron distingue « on descend » de « ça s'affiche à droite ». Sans lui,
	# le joueur ne sait pas si activer l'entrée va le déplacer.
	if target != "" and not btn.disabled:
		var chevron := Label.new()
		chevron.text = "›"
		chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chevron.add_theme_font_size_override("font_size", 24)
		chevron.add_theme_color_override("font_color", accent)
		chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chevron)
	elif btn.disabled:
		var lock := Label.new()
		lock.text = "—"
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock.add_theme_font_size_override("font_size", 16)
		lock.add_theme_color_override("font_color", MenuTheme.DIM)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lock)

	# Le panneau de droite suit le curseur ET la souris : c'est le même geste de
	# « je regarde ceci », quel que soit le périphérique.
	var texte := reason if btn.disabled else detail
	var titre := label
	btn.focus_entered.connect(func() -> void: show_detail(titre, texte))
	btn.mouse_entered.connect(func() -> void: show_detail(titre, texte))

	if btn.disabled:
		return btn
	if target != "":
		btn.pressed.connect(func() -> void: push(target))
	elif action != "":
		btn.pressed.connect(func() -> void: action_requested.emit(action))
	else:
		# Entrée d'information : activer ne déplace rien, cela remet simplement le
		# panneau de droite sur son contenu.
		btn.pressed.connect(func() -> void: show_detail(titre, texte))
	return btn

## Ajoute le retour en bas d'une liste. À appeler pour **chaque** écran non
## racine : c'est la seule sortie garantie, souris comprise.
func add_back_entry(id: String) -> void:
	var list := list_of(id)
	if list == null:
		return
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, MenuTheme.GAP_XS)
	list.add_child(spacer)
	var btn := make_entry("‹  RETOUR", "Remonte d'un cran. La touche Échap fait la même chose.",
		"", MenuTheme.DIM)
	btn.pressed.connect(back)
	list.add_child(btn)
