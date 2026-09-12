class_name ScreenEffects
extends HubScreen

## Écran « Effets » du hub : deux contrôles, et tout le reste replié.
##
## ## Ce qu'il y avait avant, et pourquoi ça ne tenait pas
##
## Trente-quatre curseurs à la file, engendrés par la table, chacun avec sa
## phrase et son plancher. Chaque ligne se justifiait ; l'ensemble était
## illisible. Adrien, le 2026-09-12 : *« pour l'instant on a mis systématiquement
## quasiment tous les réglages possibles dans le menu »*. Le défaut n'était pas
## dans une ligne, il était dans le nombre — et un menu de réglages qu'on ne
## traverse pas est un menu où personne ne règle rien.
##
## ## Ce que l'écran montre maintenant
##
## - **un interrupteur** pour les quinze effets de menu, ensemble. Ils ne se
##   voient jamais en match et n'apprennent rien de personne : le seul choix
##   réel est « j'en veux ou je n'en veux pas » ;
## - **quatre niveaux** pour les sept effets de confort du match — nul, faible,
##   moyen, élevé. C'est la granularité d'une décision d'accessibilité, pas
##   celle d'un étalonnage ;
## - **les paramètres avancés**, repliés, où chaque effet réglable garde son
##   curseur au pourcent. Rien n'est perdu, tout est rangé.
##
## Et **les douze effets du monde ne sont plus là du tout**. Ils ne sont pas
## grisés, ni bridés, ni repoussés dans l'avancé : ils ont cessé d'être des
## réglages (voir `effect_policy.gd`). Un écran qui les montrerait verrouillés
## ferait passer une règle de jeu pour une option refusée.
##
## ## Le piège que les deux contrôles simples introduisent
##
## Ils écrivent dans les mêmes préférences que les curseurs de l'avancé — il n'y
## a qu'une source de vérité, et c'est ce qui évite qu'un réglage fin soit
## silencieusement écrasé par un résumé. La contrepartie est qu'un réglage fin
## peut ne correspondre à **aucun** des quatre niveaux : l'écran l'affiche alors
## comme « personnalisé », aucun bouton allumé. **Arrondir au niveau le plus
## proche serait pire que de ne rien dire** — ça effacerait le choix à la simple
## ouverture de l'écran, sans que rien ne le signale.

const Charte := preload("res://charte.gd")
const MenuTheme := preload("res://menu_theme.gd")
const MenuWidgets := preload("res://menu_widgets.gd")

## Course des curseurs de l'avancé. Le pas de 5 % évite qu'un réglage se joue au
## pixel et rend la course franchissable au stick en une vingtaine de crans.
const SLIDER_MIN := 0.0
const SLIDER_MAX := 100.0
const SLIDER_STEP := 5.0
const SLIDER_WIDTH := 240.0

## ⚠️ **Les quatre niveaux se partagent la largeur, ils ne la réclament pas.**
##
## Premier jet : quatre boutons de 132 px dans un `HFlowContainer`. Vu à l'écran
## (photographe, plan `reglages`) : ils se **replient sur deux lignes** — trois
## puis « ÉLEVÉ » tout seul en dessous. Le hub pose l'écran dans une colonne de
## lecture large de `Charte.MESURE` signes, soit ~515 px ici, et 4 × 132 + 3
## gouttières n'y tient pas.
##
## Quatre niveaux sur deux lignes ne se lisent plus comme une échelle : c'est
## toute la raison d'être du contrôle qui disparaît. Une largeur plus petite
## aurait marché **à cette taille de fonte et pas à la suivante** ; les boutons
## se partagent donc la place (`SIZE_EXPAND_FILL` dans une `HBoxContainer`), avec
## un plancher assez bas pour que la rangée tienne jusqu'à ~300 px de colonne.
const NIVEAU_MIN := Vector2(72, 44)
const LARGEUR_BASCULE := Vector2(216, 44)

const AVANCE_REPLIE := "PARAMÈTRES AVANCÉS  ▸"
const AVANCE_DEPLIE := "PARAMÈTRES AVANCÉS  ▾"

## Écrit par les tests, qui construisent l'écran sans autoload. En jeu, il reste
## nul et l'écran s'adresse à `/root/GameSettings`.
var settings_override: Node = null

var _context_label: Label
## L'interrupteur des quinze effets de menu, et la ligne qui dit son état.
var _bouton_menus: Button
var _etat_menus: Label
## Les quatre niveaux du confort, dans l'ordre d'`EffectPolicy.NIVEAUX`.
var _boutons_niveau: Array[Button] = []
var _etat_confort: Label
## Le bouton qui déplie, et ce qu'il déplie.
var _bouton_avance: Button
var _avance: VBoxContainer
var _first_control: Control
## identifiant -> { "panel", "slider", "value", "notice", "minus", "plus" }
var _rows: Dictionary = {}
## Vrai pendant `refresh()` : les curseurs qu'on repositionne émettent
## `value_changed` comme si le joueur les avait bougés. Sans ce garde-fou, un
## simple affichage réécrirait la préférence qu'il est venu montrer.
var _applying: bool = false

func screen_title() -> String:
	return "Effets"

func focus_seed() -> Control:
	return _first_control

# ---------------------------------------------------------------------------
# CONSTRUCTION
# ---------------------------------------------------------------------------

func build(body: VBoxContainer) -> void:
	if body == null or not _rows.is_empty():
		return

	_context_label = Label.new()
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Charte.appareil(_context_label, MenuTheme.T_MENTION)
	_context_label.add_theme_color_override("font_color", MenuTheme.DIM)
	_context_label.text = EffectPolicy.context_line()
	body.add_child(_context_label)

	# Tout défile ensemble — résumé compris. Déplier l'avancé rallonge la page
	# de vingt-deux lignes : une zone de défilement qui ne contiendrait QUE
	# l'avancé laisserait le résumé pousser le reste hors du cadre.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 480.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	var colonne := VBoxContainer.new()
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_theme_constant_override("separation", MenuTheme.GAP_S)
	scroll.add_child(colonne)

	colonne.add_child(_build_bloc_menus())
	colonne.add_child(_build_bloc_confort())
	colonne.add_child(_build_bouton_avance())
	_avance = _build_avance()
	colonne.add_child(_avance)

	refresh()

## Les quinze effets de menu, derrière un seul bouton.
func _build_bloc_menus() -> Control:
	var colonne := _bloc(EffectPolicy.Family.MENUS)

	_bouton_menus = MenuWidgets.make_button("", MenuTheme.P1, false,
		MenuTheme.T_COURANT, LARGEUR_BASCULE)
	_bouton_menus.name = "BasculeMenus"
	_bouton_menus.pressed.connect(_basculer_menus)
	colonne.add_child(_rangee([_bouton_menus]))

	_etat_menus = _mention()
	colonne.add_child(_etat_menus)

	_first_control = _bouton_menus
	return colonne

## Les sept effets de confort, en quatre niveaux.
func _build_bloc_confort() -> Control:
	var colonne := _bloc(EffectPolicy.Family.CONFORT)

	# Un `ButtonGroup` tient l'exclusivité à notre place — et il accepte qu'AUCUN
	# bouton ne soit enfoncé, ce qui est exactement l'état « personnalisé ».
	var groupe := ButtonGroup.new()
	var echelle := HBoxContainer.new()
	echelle.add_theme_constant_override("separation", MenuTheme.GAP_XS)
	echelle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boutons_niveau.clear()
	for i in EffectPolicy.NIVEAUX.size():
		var btn := MenuWidgets.make_choice_button(EffectPolicy.NOMS_NIVEAUX[i],
			MenuTheme.P1, groupe, MenuTheme.T_COURANT, NIVEAU_MIN)
		btn.name = "Niveau%d" % i
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_poser_niveau.bind(i))
		_boutons_niveau.append(btn)
		echelle.add_child(btn)
	colonne.add_child(echelle)

	_etat_confort = _mention()
	colonne.add_child(_etat_confort)
	return colonne

func _build_bouton_avance() -> Control:
	_bouton_avance = MenuWidgets.make_button(AVANCE_REPLIE, MenuTheme.GOLD, false,
		MenuTheme.T_COURANT, Vector2(280, 44))
	_bouton_avance.name = "BasculeAvance"
	_bouton_avance.pressed.connect(_basculer_avance)
	return _rangee([_bouton_avance])

## Un curseur par effet réglable, groupé par famille. Engendré par la table :
## ajouter un effet ne se voit pas ici, et c'est la seule façon que la liste ne
## prenne pas de retard sur le jeu à chaque vague de game feel.
func _build_avance() -> VBoxContainer:
	var liste := VBoxContainer.new()
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.add_theme_constant_override("separation", MenuTheme.GAP_S)
	# `hidden` et non `modulate` : un panneau replié ne doit pas seulement être
	# invisible, il doit être hors d'atteinte des deux curseurs — sinon on
	# traverse vingt-deux lignes qu'on ne voit pas.
	liste.visible = false

	for famille in [EffectPolicy.Family.MENUS, EffectPolicy.Family.CONFORT]:
		var groupe := VBoxContainer.new()
		groupe.add_theme_constant_override("separation", MenuTheme.GAP_XXS)
		var titre := Label.new()
		titre.text = EffectPolicy.family_label(famille).to_upper()
		Charte.enseigne(titre, MenuTheme.T_MENTION)
		titre.add_theme_color_override("font_color", MenuTheme.GOLD)
		groupe.add_child(titre)
		for id in EffectPolicy.ids_of_family(famille):
			groupe.add_child(_build_row(String(id)))
		liste.add_child(groupe)

	return liste

## Le titre et la règle d'une famille, au-dessus de son contrôle.
func _bloc(famille: int) -> VBoxContainer:
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", MenuTheme.GAP_XXS)

	var titre := Label.new()
	titre.text = EffectPolicy.family_label(famille).to_upper()
	Charte.enseigne(titre, MenuTheme.T_APPUI)
	titre.add_theme_color_override("font_color", MenuTheme.GOLD)
	colonne.add_child(titre)

	var regle := Label.new()
	regle.text = EffectPolicy.family_rule(famille)
	regle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Charte.appareil(regle, MenuTheme.T_MENTION)
	regle.add_theme_color_override("font_color", MenuTheme.DIM)
	colonne.add_child(regle)

	return colonne

## Les boutons d'un réglage, côte à côte et repliés si la largeur manque.
func _rangee(boutons: Array) -> HFlowContainer:
	var rangee := HFlowContainer.new()
	rangee.add_theme_constant_override("h_separation", MenuTheme.GAP_XS)
	rangee.add_theme_constant_override("v_separation", MenuTheme.GAP_XS)
	for b in boutons:
		rangee.add_child(b as Control)
	return rangee

func _mention() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Charte.appareil(label, MenuTheme.T_MENTION)
	label.add_theme_color_override("font_color", MenuTheme.DIM)
	return label

func _build_row(id: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Row_" + id
	panel.add_theme_stylebox_override("panel", MenuWidgets.make_panel_style(MenuTheme.LINE, MenuWidgets.CORNER_BUTTON, 2))

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
	line.add_theme_constant_override("separation", MenuTheme.GAP_XS)
	column.add_child(line)

	var name_label := Label.new()
	name_label.text = EffectPolicy.label_of(id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Charte.appareil(name_label, MenuTheme.T_COURANT)
	line.add_child(name_label)

	var minus := MenuWidgets.make_step_button("‹")
	line.add_child(minus)

	var slider := MenuWidgets.make_slider(SLIDER_MIN, SLIDER_MAX, SLIDER_STEP, SLIDER_WIDTH, MenuTheme.P1)
	slider.name = "Slider_" + id
	line.add_child(slider)

	var plus := MenuWidgets.make_step_button("›")
	line.add_child(plus)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(64, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Charte.appareil(value_label, MenuTheme.T_COURANT)
	line.add_child(value_label)

	var notice := Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Charte.appareil(notice, MenuTheme.T_MENTION)
	notice.add_theme_color_override("font_color", MenuTheme.DIM)
	notice.text = EffectPolicy.constraint_line(id)
	column.add_child(notice)

	slider.value_changed.connect(_on_slider_changed.bind(id))

	minus.pressed.connect(func() -> void:
		_step_slider(id, -SLIDER_STEP)
	)
	plus.pressed.connect(func() -> void:
		_step_slider(id, SLIDER_STEP)
	)

	# Éclairer la ligne au focus
	for btn in [minus, plus]:
		btn.focus_entered.connect(func() -> void:
			panel.add_theme_stylebox_override("panel", MenuWidgets.make_panel_style(MenuTheme.P1, MenuWidgets.CORNER_BUTTON, 2)))
		btn.focus_exited.connect(func() -> void:
			panel.add_theme_stylebox_override("panel", MenuWidgets.make_panel_style(MenuTheme.LINE, MenuWidgets.CORNER_BUTTON, 2)))

	_rows[id] = {
		"panel": panel,
		"slider": slider,
		"value": value_label,
		"notice": notice,
		"minus": minus,
		"plus": plus
	}
	return panel

func _step_slider(id: String, delta: float) -> void:
	if not _rows.has(id):
		return
	var slider: HSlider = _rows[id]["slider"]
	var nouv: float = clampf(slider.value + delta, slider.min_value, slider.max_value)
	if not is_equal_approx(nouv, slider.value):
		slider.value = nouv

# ---------------------------------------------------------------------------
# LES DEUX CONTRÔLES SIMPLES
# ---------------------------------------------------------------------------

## Un seul geste pour les quinze effets de menu.
##
## La règle est « tout éteindre, sauf si tout est déjà éteint » : depuis l'état
## personnalisé, un appui éteint donc au lieu de rallumer. C'est le sens de
## lecture d'un interrupteur — on l'actionne pour se débarrasser de quelque
## chose — et la ligne d'état l'annonce avant qu'on appuie.
func _basculer_menus() -> void:
	var allumer := _etat_menus_courant() == 0
	var cible := EffectPolicy.MAX if allumer else EffectPolicy.MIN
	var settings := _settings()
	if settings != null:
		for id in EffectPolicy.ids_of_family(EffectPolicy.Family.MENUS):
			settings.set_effect(String(id), cible)
	refresh()

## Aligne les sept effets de confort sur un niveau. Les curseurs de l'avancé
## suivent : c'est la même préférence qu'ils montrent.
func _poser_niveau(index: int) -> void:
	if index < 0 or index >= EffectPolicy.NIVEAUX.size():
		return
	var settings := _settings()
	if settings != null:
		for id in EffectPolicy.ids_of_family(EffectPolicy.Family.CONFORT):
			settings.set_effect(String(id), EffectPolicy.NIVEAUX[index])
	refresh()

func _basculer_avance() -> void:
	if _avance == null:
		return
	_avance.visible = not _avance.visible
	_bouton_avance.text = AVANCE_DEPLIE if _avance.visible else AVANCE_REPLIE

## -1 personnalisé, 0 tous éteints, 1 tous allumés.
func _etat_menus_courant() -> int:
	var tous_eteints := true
	var tous_allumes := true
	for id in EffectPolicy.ids_of_family(EffectPolicy.Family.MENUS):
		var v := _stored_intensity(String(id))
		if v > EffectPolicy.MIN:
			tous_eteints = false
		if absf(v - EffectPolicy.MAX) > EffectPolicy.TOLERANCE_NIVEAU:
			tous_allumes = false
	if tous_allumes:
		return 1
	if tous_eteints:
		return 0
	return -1

## Le niveau commun aux sept effets de confort, ou -1 s'ils divergent.
func _niveau_confort_courant() -> int:
	var valeurs: Array = []
	for id in EffectPolicy.ids_of_family(EffectPolicy.Family.CONFORT):
		valeurs.append(_stored_intensity(String(id)))
	return EffectPolicy.niveau_commun(valeurs)

# ---------------------------------------------------------------------------
# AFFICHAGE
# ---------------------------------------------------------------------------

## Idempotent, et sans effet sur un écran jamais construit : le hub appelle
## `refresh()` avant le premier affichage comme après.
func refresh() -> void:
	if _rows.is_empty():
		return
	_applying = true
	_refresh_menus()
	_refresh_confort()
	for id in _rows:
		_refresh_row(String(id))
	_applying = false

func _refresh_menus() -> void:
	match _etat_menus_courant():
		1:
			_bouton_menus.text = "ACTIVÉS"
			_etat_menus.text = "Les quinze sont allumés. Appuyer les éteint tous."
		0:
			_bouton_menus.text = "DÉSACTIVÉS"
			_etat_menus.text = "Les quinze sont éteints. Appuyer les rallume tous."
		_:
			_bouton_menus.text = "PERSONNALISÉS"
			_etat_menus.text = "Réglés un par un dans les paramètres avancés. " \
				+ "Appuyer les éteint tous."

func _refresh_confort() -> void:
	var niveau := _niveau_confort_courant()
	for i in _boutons_niveau.size():
		_boutons_niveau[i].button_pressed = (i == niveau)
	if niveau >= 0:
		_etat_confort.text = "Les sept effets de confort suivent ce niveau. " \
			+ "Chacun reste réglable seul dans les paramètres avancés."
	else:
		_etat_confort.text = "Personnalisé : vos effets ne tombent pas tous sur " \
			+ "le même niveau. En choisir un les aligne."

func _refresh_row(id: String) -> void:
	var row: Dictionary = _rows[id]
	var slider: HSlider = row["slider"]
	var value_label: Label = row["value"]

	var value := EffectPolicy.clamp_value(id, _stored_intensity(id))
	slider.value = float(EffectPolicy.intensity_to_percent(value))
	value_label.text = "%d %%" % EffectPolicy.intensity_to_percent(value)

func _on_slider_changed(percent: float, id: String) -> void:
	if _applying:
		return
	var settings := _settings()
	if settings != null:
		settings.set_effect(id, EffectPolicy.percent_to_intensity(int(percent)))
	# Un réglage fin peut faire sortir sa famille de tout niveau connu : les deux
	# résumés sont donc remis d'accord à chaque cran, jamais seulement à
	# l'ouverture de l'écran.
	_applying = true
	_refresh_menus()
	_refresh_confort()
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
