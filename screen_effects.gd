class_name ScreenEffects
extends HubScreen

## Écran « Effets » du hub : un curseur par effet, sa famille, et sa contrainte
## écrite à côté.
##
## L'écran ne décide rien. Il affiche `EffectPolicy` et écrit dans `GameSettings`
## ce que le joueur choisit. Toute la liste est engendrée par la table : ajouter
## un effet ne se voit pas ici, et c'est la seule façon que la liste ne prenne
## pas de retard sur le jeu à chaque vague de game feel.
##
## ## Montrer la limite plutôt que la masquer
##
## Un curseur bridé s'arrête visiblement à son plancher, et la ligne en dessous
## dit pourquoi. L'autre solution — masquer les effets non réglables, ou laisser
## le curseur descendre puis remonter tout seul — produit exactement la même
## impression qu'un défaut, et c'est ainsi qu'on reçoit un mail « le réglage des
## particules ne marche pas ».
##
## ## Le contexte
##
## Les planchers ne valent qu'en classé. L'écran ne le devine pas — il ne touche
## pas au réseau, contrat de `HubScreen` — il l'apprend par
## `set_ranked_context()`. Tant que personne ne le lui a dit, il affiche la règle
## **la plus stricte** : un écran qui promettrait un zéro que le match refusera
## ensuite serait un mensonge plus coûteux qu'un minimum affiché en trop.

## Course des curseurs. Le pas de 5 % évite qu'un réglage se joue au pixel et
## rend la course franchissable au stick en une vingtaine de crans.
const SLIDER_MIN := 0.0
const SLIDER_MAX := 100.0
const SLIDER_STEP := 5.0
const SLIDER_WIDTH := 280.0

## Écrit par les tests, qui construisent l'écran sans autoload. En jeu, il reste
## nul et l'écran s'adresse à `/root/GameSettings`.
var settings_override: Node = null

var _ranked: bool = true
var _list: VBoxContainer
var _context_label: Label
## identifiant -> { "panel", "slider", "value", "notice" }
var _rows: Dictionary = {}
var _first_slider: HSlider
## Vrai pendant `refresh()` : les curseurs qu'on repositionne émettent
## `value_changed` comme si le joueur les avait bougés. Sans ce garde-fou, un
## simple affichage en classé réécrirait la préférence brute au plancher, et le
## réglage pris en écran partagé serait perdu au premier passage sur l'écran.
var _applying: bool = false

func screen_title() -> String:
	return "Effets"

func focus_seed() -> Control:
	return _first_slider

## Dit à l'écran s'il parle d'un match classé. Idempotent : le rappeler avec la
## même valeur ne coûte qu'un rafraîchissement.
func set_ranked_context(ranked: bool) -> void:
	_ranked = ranked
	refresh()

func is_ranked_context() -> bool:
	return _ranked

# ---------------------------------------------------------------------------
# CONSTRUCTION
# ---------------------------------------------------------------------------

func build(body: VBoxContainer) -> void:
	if body == null or not _rows.is_empty():
		return

	_context_label = Label.new()
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context_label.add_theme_font_size_override("font_size", MenuTheme.T_COURANT)
	body.add_child(_context_label)

	# La table est plus haute que le corps d'un écran de hub, et elle grandira.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", MenuTheme.GAP_S)
	scroll.add_child(_list)

	# L'ordre des familles est celui de la règle : ce qui est libre d'abord, ce
	# qui est contraint ensuite. Un joueur venu couper une secousse n'a pas à
	# traverser neuf planchers pour la trouver.
	for family in [EffectPolicy.Family.CONFORT, EffectPolicy.Family.MONDE]:
		_list.add_child(_build_family_header(family))
		for id in EffectPolicy.ids_of_family(family):
			_list.add_child(_build_row(id))

	refresh()

func _build_family_header(family: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", MenuTheme.GAP_XXS)

	var title := Label.new()
	title.text = EffectPolicy.family_label(family).to_upper()
	title.add_theme_font_size_override("font_size", MenuTheme.T_APPUI)
	title.add_theme_color_override("font_color", MenuTheme.GOLD)
	box.add_child(title)

	var rule := Label.new()
	rule.text = EffectPolicy.family_rule(family)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.add_theme_font_size_override("font_size", MenuTheme.T_MENTION)
	rule.add_theme_color_override("font_color", MenuTheme.DIM)
	box.add_child(rule)

	return box

func _build_row(id: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Row_" + id
	panel.add_theme_stylebox_override("panel", _row_style(false))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", MenuTheme.GAP_XS)
	margin.add_theme_constant_override("margin_bottom", MenuTheme.GAP_XS)
	margin.add_theme_constant_override("margin_left", MenuTheme.GAP_S)
	margin.add_theme_constant_override("margin_right", MenuTheme.GAP_S)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", MenuTheme.GAP_XXS)
	margin.add_child(column)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", MenuTheme.GAP_S)
	column.add_child(line)

	var name_label := Label.new()
	name_label.text = EffectPolicy.label_of(id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", MenuTheme.T_COURANT)
	line.add_child(name_label)

	var slider := HSlider.new()
	slider.name = "Slider_" + id
	slider.min_value = SLIDER_MIN
	slider.max_value = SLIDER_MAX
	slider.step = SLIDER_STEP
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.add_theme_stylebox_override("slider", _track_style())
	slider.add_theme_stylebox_override("grabber_area", _fill_style())
	slider.add_theme_stylebox_override("grabber_area_highlight", _fill_style())
	line.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(64, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", MenuTheme.T_COURANT)
	line.add_child(value_label)

	var notice := Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.add_theme_font_size_override("font_size", MenuTheme.T_MENTION)
	notice.add_theme_color_override("font_color", MenuTheme.DIM)
	column.add_child(notice)

	slider.value_changed.connect(_on_slider_changed.bind(id))
	# Un curseur n'a pas de cadre de focus dans le thème par défaut : c'est la
	# ligne entière qui s'allume, sans quoi on perd le curseur de vue au stick.
	slider.focus_entered.connect(func() -> void:
		panel.add_theme_stylebox_override("panel", _row_style(true)))
	slider.focus_exited.connect(func() -> void:
		panel.add_theme_stylebox_override("panel", _row_style(false)))

	if _first_slider == null:
		_first_slider = slider

	_rows[id] = {"panel": panel, "slider": slider, "value": value_label, "notice": notice}
	return panel

func _row_style(focused: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = MenuTheme.SURFACE
	box.set_border_width_all(2)
	box.border_color = MenuTheme.P1 if focused else MenuTheme.LINE
	box.set_corner_radius_all(10)
	return box

func _track_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = MenuTheme.LINE
	box.set_corner_radius_all(3)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box

func _fill_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = MenuTheme.P1
	box.set_corner_radius_all(3)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box

# ---------------------------------------------------------------------------
# AFFICHAGE
# ---------------------------------------------------------------------------

## Idempotent, et sans effet sur un écran jamais construit : le hub appelle
## `refresh()` avant le premier affichage comme après.
func refresh() -> void:
	if _rows.is_empty():
		return
	_applying = true
	_context_label.text = EffectPolicy.context_line(_ranked)
	_context_label.add_theme_color_override("font_color",
		MenuTheme.GOLD if _ranked else MenuTheme.DIM)
	for id in _rows:
		_refresh_row(String(id))
	_applying = false

func _refresh_row(id: String) -> void:
	var row: Dictionary = _rows[id]
	var slider: HSlider = row["slider"]
	var value_label: Label = row["value"]
	var notice: Label = row["notice"]

	var stored := _stored_intensity(id)
	var applied := EffectPolicy.clamp_value(id, stored, _ranked)
	var floor_percent := EffectPolicy.intensity_to_percent(EffectPolicy.floor_of(id, _ranked))

	# La course s'arrête au plancher : la limite se heurte, elle ne se devine pas.
	slider.min_value = float(floor_percent)
	slider.value = float(EffectPolicy.intensity_to_percent(applied))

	value_label.text = "%d %%" % EffectPolicy.intensity_to_percent(applied)
	# Préférence relevée par le contexte : le joueur avait choisi plus bas, et
	# doit voir que ce n'est pas son réglage qui s'affiche en ce moment. Hors de
	# ce cas on retire la surcharge plutôt que d'écrire une couleur de plus : le
	# blanc du thème n'a pas à être recopié ici.
	if applied > stored + 0.0001:
		value_label.add_theme_color_override("font_color", MenuTheme.WARN)
	else:
		value_label.remove_theme_color_override("font_color")

	notice.text = EffectPolicy.constraint_line(id, _ranked)
	notice.add_theme_color_override("font_color",
		MenuTheme.WARN if EffectPolicy.is_capped(id, _ranked) else MenuTheme.DIM)

func _on_slider_changed(percent: float, id: String) -> void:
	if _applying:
		return
	var settings := _settings()
	if settings != null:
		settings.set_effect(id, EffectPolicy.percent_to_intensity(int(percent)))
	_applying = true
	_refresh_row(id)
	_applying = false

# ---------------------------------------------------------------------------
# ACCÈS AUX PRÉFÉRENCES
# ---------------------------------------------------------------------------
#
# L'écran doit se construire seul, sans hub et sans autoload — c'est le contrat
# de `HubScreen`, et c'est ce qui le rend exerçable en test. Sans préférences
# accessibles il montre la table telle qu'elle est écrite, ce qui reste juste.

func _settings() -> Node:
	if settings_override != null:
		return settings_override
	if not is_inside_tree():
		return null
	return get_node_or_null(^"/root/GameSettings")

func _stored_intensity(id: String) -> float:
	var settings := _settings()
	if settings == null:
		return EffectPolicy.DEFAULT
	return float(settings.get_effect(id))
