class_name ScreenAudio
extends HubScreen

## Écran « Audio » du hub : les quatre volumes du mixage, et de quoi les entendre.
##
## ## Ce que l'écran ne calcule pas
##
## Rien. La valeur d'un volume est une **amplitude linéaire** entre 0 et 1 ;
## `settings_manager.gd` la convertit en décibels au moment de l'appliquer, et
## sait déjà couper le bus plutôt que de lui envoyer moins l'infini. Un écran qui
## referait cette conversion — ou qui graduerait sa course en décibels — tasserait
## tout le changement perçu dans les derniers pourcents de la course : les trois
## premiers quarts du curseur ne serviraient à rien. Les pourcents affichés ici
## passent donc par `volume_to_percent()` et `percent_to_volume()`, jamais par un
## calcul local.
##
## ## Un volume se règle à l'oreille
##
## Chaque cran fait sonner **le bus concerné**, sinon le joueur déplace un
## curseur à l'aveugle et ne juge qu'un chiffre. Le son d'essai est choisi par
## bus (voir `_play_preview`) et limité par un délai de garde : sans lui, un
## glissement à la souris déclencherait une audition par cran traversé.
##
## ## Le zéro se dit, il ne se déduit pas
##
## À zéro, `settings_manager` coupe franchement le bus. « 0 % » laisserait croire
## à un résidu inaudible ; l'écran écrit « COUPÉ ». C'est la même information pour
## le mixage et pour le joueur.
##
## ## Manette : pourquoi des boutons de pas et pas un curseur focalisé
##
## Sur une liste verticale, la convention est que gauche/droite règle la valeur du
## curseur focalisé et que haut/bas change de ligne — c'est ce que fait un
## `HSlider` natif. Mais le menu de ce jeu n'utilise pas le focus natif de Godot :
## il porte **deux curseurs simultanés** résolus géométriquement dans `ui.gd`, et
## les événements de stick sont retirés des actions `ui_*` pour éviter un double
## déplacement. Un `HSlider` sous le curseur ne reçoit donc jamais ni le focus ni
## `ui_left`/`ui_right` : il serait inerte à la manette.
##
## L'écran expose donc la valeur par deux **boutons de pas** — les seuls contrôles
## que le résolveur sait viser et activer. Gauche/droite déplace le curseur entre
## « ‹ » et « › », haut/bas change de ligne, et activer règle d'un cran. Le
## `HSlider` reste, non focusable : il montre le niveau d'un coup d'œil et sert de
## poignée à la souris, sans jamais attirer un curseur qui ne pourrait pas le
## bouger.

const Charte := preload("res://charte.gd")
const MenuTheme := preload("res://menu_theme.gd")
const MenuWidgets := preload("res://menu_widgets.gd")
const Settings := preload("res://settings_manager.gd")

const ID_MASTER := "master"
const ID_MUSIC := "music"
const ID_SFX := "sfx"
const ID_SPEAKER := "speaker"

## Un volume par ligne : son bus, la propriété où `GameSettings` le retient, le
## setter qui l'applique et le sauvegarde, et la phrase qui dit ce qu'on règle.
const ROWS: Array[Dictionary] = [
	{
		"id": ID_MASTER, "label": "GÉNÉRAL", "bus": Settings.BUS_MASTER,
		"prop": "master_volume", "setter": "set_master_volume",
		"detail": "Tout le son du jeu passe par ici, les trois autres compris.",
	},
	{
		"id": ID_MUSIC, "label": "MUSIQUE", "bus": Settings.BUS_MUSIC,
		"prop": "music_volume", "setter": "set_music_volume",
		"detail": "La musique des menus et du match, filtrée quand une lampe s'allume.",
	},
	{
		"id": ID_SFX, "label": "EFFETS", "bus": Settings.BUS_SFX,
		"prop": "sfx_volume", "setter": "set_sfx_volume",
		"detail": "Tirs, pas, impacts. Dans le noir, c'est de l'information : "
			+ "à baisser en connaissance de cause.",
	},
	{
		"id": ID_SPEAKER, "label": "ANNONCEUR", "bus": Settings.BUS_SPEAKER,
		"prop": "speaker_volume", "setter": "set_speaker_volume",
		"detail": "La voix qui annonce le départ et l'issue du match.",
	},
]

## Course en pourcents d'amplitude. Le pas de 10 % fixe aussi le nombre
## d'activations pour traverser toute la course à la manette : dix, sans quoi
## couper le son deviendrait une corvée.
const SLIDER_MIN := 0.0
const SLIDER_MAX := 100.0
const SLIDER_STEP := 10.0
const SLIDER_WIDTH := 200.0

## Sons d'essai. `button_click` sert de mire neutre : c'est le seul son court du
## dépôt qu'on peut router sur n'importe quel bus sans qu'il raconte autre chose
## que son niveau.
const PREVIEW_NEUTRAL := "button_click"
## Le tir est le son de référence du duel — c'est lui qu'on règle vraiment quand
## on touche aux effets.
const PREVIEW_SFX := "shoot"
## Voix de l'annonceur. Les fichiers `res://assets/audio/speaker/` ne sont pas
## encore dans le dépôt : `_play_preview` retombe alors sur la mire.
const PREVIEW_SPEAKER := "spk_fight"

## Mot affiché à zéro. « 0 % » se lit comme un niveau très bas ; le bus, lui, est
## coupé net.
const MUTED_TEXT := "COUPÉ"

## Écrits par les tests, qui construisent l'écran sans autoload. En jeu ils
## restent nuls et l'écran s'adresse à `/root/GameSettings` et `/root/AudioManager`.
var settings_override: Node = null
var audio_override: Node = null

## Délai de garde entre deux auditions d'un même bus. Assez court pour qu'un
## glissement reste sonore de bout en bout, assez long pour ne pas empiler une
## audition par pixel parcouru. Variable pour que les tests le fixent.
var preview_cooldown_ms: int = 150

var _list: VBoxContainer
## identifiant -> { "panel", "slider", "value", "notice", "minus", "plus" }
var _rows: Dictionary = {}
var _first_control: Button
## identifiant -> date de la dernière audition, en millisecondes.
var _last_preview_ms: Dictionary = {}
## Vrai pendant `refresh()` : repositionner un curseur émet `value_changed`
## comme si le joueur l'avait bougé. Sans ce garde-fou, le simple fait d'ouvrir
## l'écran réécrirait — et resauvegarderait — les quatre préférences.
var _applying: bool = false

func screen_title() -> String:
	return "Audio"

func focus_seed() -> Control:
	return _first_control

# ---------------------------------------------------------------------------
# TABLE
# ---------------------------------------------------------------------------

## Description d'une ligne, ou un dictionnaire vide si l'identifiant est inconnu.
## Statique : une suite doit pouvoir lire la table sans construire d'écran.
static func spec_of(id: String) -> Dictionary:
	for row in ROWS:
		if String(row["id"]) == id:
			return row
	return {}

static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for row in ROWS:
		out.append(String(row["id"]))
	return out

# ---------------------------------------------------------------------------
# CONSTRUCTION
# ---------------------------------------------------------------------------

func build(body: VBoxContainer) -> void:
	if body == null or not _rows.is_empty():
		return

	var intro := Label.new()
	intro.text = "Chaque cran fait sonner le bus qu'il règle : un volume se juge à l'oreille."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", MenuTheme.T_COURANT)
	intro.add_theme_color_override("font_color", MenuTheme.DIM)
	body.add_child(intro)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", MenuTheme.GAP_S)
	body.add_child(_list)

	for spec in ROWS:
		_list.add_child(_build_row(spec))

	refresh()

func _build_row(spec: Dictionary) -> Control:
	var id := String(spec["id"])

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
	line.add_theme_constant_override("separation", MenuTheme.GAP_XS)
	column.add_child(line)

	var name_label := Label.new()
	name_label.text = String(spec["label"])
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Charte.appareil(name_label, MenuTheme.T_COURANT)
	line.add_child(name_label)

	var minus := _step_button("‹", id, -1)
	line.add_child(minus)

	# Non focusable, et c'est délibéré : le curseur de menu ne doit jamais se
	# poser sur un contrôle qu'il ne sait pas actionner. La souris, elle, garde
	# le glissement — `Slider` traite la souris sans avoir le focus.
	var slider := MenuWidgets.make_slider(SLIDER_MIN, SLIDER_MAX, SLIDER_STEP, SLIDER_WIDTH, MenuTheme.P1)
	slider.name = "Slider_" + id
	line.add_child(slider)

	var plus := _step_button("›", id, 1)
	line.add_child(plus)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(78, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Charte.appareil(value_label, MenuTheme.T_COURANT)
	line.add_child(value_label)

	var notice := Label.new()
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Charte.appareil(notice, MenuTheme.T_MENTION)
	notice.add_theme_color_override("font_color", MenuTheme.DIM)
	column.add_child(notice)

	slider.value_changed.connect(_on_slider_changed.bind(id))
	# Le délai de garde peut avaler le dernier cran d'un glissement rapide : le
	# relâchement rejoue la valeur retenue, pour que ce soit bien elle qu'on ait
	# entendue en dernier.
	slider.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			_preview(id, true))

	# Un bouton de pas est petit : c'est la ligne entière qui s'allume, sans quoi
	# on perd de vue ce qu'on règle dès qu'on regarde le chiffre.
	for btn in [minus, plus]:
		btn.focus_entered.connect(func() -> void:
			panel.add_theme_stylebox_override("panel", _row_style(true)))
		btn.focus_exited.connect(func() -> void:
			panel.add_theme_stylebox_override("panel", _row_style(false)))

	if _first_control == null:
		_first_control = minus

	_rows[id] = {
		"panel": panel, "slider": slider, "value": value_label,
		"notice": notice, "minus": minus, "plus": plus,
	}
	return panel

func _step_button(text: String, id: String, direction: int) -> Button:
	var btn := MenuWidgets.make_step_button(text, Vector2(40, 30))
	btn.name = ("Moins_" if direction < 0 else "Plus_") + id
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func() -> void: nudge(id, direction))
	return btn

func _row_style(focused: bool) -> StyleBoxFlat:
	return MenuWidgets.make_panel_style(MenuTheme.P1 if focused else MenuTheme.LINE, MenuWidgets.CORNER_BUTTON, 2)

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
## `refresh()` avant le premier affichage comme après. L'état affiché est relu
## sur `GameSettings` à chaque fois — l'écran n'en garde aucune copie, sans quoi
## un volume changé ailleurs (ou remis par défaut) s'afficherait faux.
func refresh() -> void:
	if _rows.is_empty():
		return
	_applying = true
	for id in _rows:
		_refresh_row(String(id))
	_applying = false

func _refresh_row(id: String) -> void:
	var row: Dictionary = _rows[id]
	var percent := _stored_percent(id)

	(row["slider"] as HSlider).value = float(percent)

	var value_label: Label = row["value"]
	value_label.text = MUTED_TEXT if percent <= 0 else "%d %%" % percent
	# Le silence est un état voulu, pas une panne : l'orange des avertissements
	# le dit sans crier à l'erreur. Hors de ce cas on retire la surcharge plutôt
	# que de recopier le blanc du thème.
	if percent <= 0:
		value_label.add_theme_color_override("font_color", MenuTheme.WARN)
	else:
		value_label.remove_theme_color_override("font_color")

	# Un bus renommé ou une disposition audio remplacée rend un index -1. Le
	# réglage reste utilisable et retenu — il resservira si le bus revient — mais
	# l'écran doit dire pourquoi rien ne change à l'oreille, faute de quoi le
	# joueur conclut que le curseur est cassé.
	var notice: Label = row["notice"]
	var spec := spec_of(id)
	if has_bus(id):
		notice.text = String(spec["detail"])
		notice.add_theme_color_override("font_color", MenuTheme.DIM)
	else:
		notice.text = ("Bus « %s » absent de la disposition audio : le réglage est "
			+ "retenu, mais rien n'y passe pour l'instant.") % String(spec["bus"])
		notice.add_theme_color_override("font_color", MenuTheme.WARN)

func _on_slider_changed(percent: float, id: String) -> void:
	if _applying:
		return
	set_percent(id, int(round(percent)))

# ---------------------------------------------------------------------------
# RÉGLAGE
# ---------------------------------------------------------------------------

## Point de passage unique : curseur, boutons de pas et tests empruntent le même
## chemin, donc l'audition et l'écrêtage ne peuvent pas être oubliés d'un côté.
func set_percent(id: String, percent: int) -> void:
	var spec := spec_of(id)
	if spec.is_empty():
		return

	var target := clampi(percent, int(SLIDER_MIN), int(SLIDER_MAX))
	if target == _stored_percent(id):
		# En butée, ou valeur déjà retenue : rien à écrire — mais l'oreille a
		# quand même le droit de savoir où elle en est.
		_preview(id)
		return

	var settings := _settings()
	if settings != null and settings.has_method(String(spec["setter"])):
		settings.call(String(spec["setter"]), Settings.percent_to_volume(target))

	# Le hub peut régler un volume sur un écran jamais construit — au clavier,
	# avant le premier affichage. La préférence, elle, est déjà écrite.
	if _rows.has(id):
		_applying = true
		_refresh_row(id)
		_applying = false
	_preview(id)

## Un cran vers le haut ou vers le bas. Ce que font les deux boutons de la ligne,
## et ce que ferait une touche gauche/droite si le menu utilisait le focus natif.
func nudge(id: String, direction: int) -> void:
	if spec_of(id).is_empty():
		return
	set_percent(id, _stored_percent(id) + direction * int(SLIDER_STEP))

# ---------------------------------------------------------------------------
# LECTURE — l'écran ne retient rien, il relit
# ---------------------------------------------------------------------------

func _settings() -> Node:
	if settings_override != null:
		return settings_override
	if not is_inside_tree():
		return null
	return get_node_or_null(^"/root/GameSettings")

## Amplitude linéaire retenue pour ce volume. Sans préférences accessibles —
## écran construit hors du jeu, autoload absent — c'est le niveau nominal qui
## s'affiche : la table telle qu'elle est livrée, ce qui reste juste.
func _stored_volume(id: String) -> float:
	var spec := spec_of(id)
	if spec.is_empty():
		return Settings.VOLUME_DEFAULT
	var settings := _settings()
	if settings == null:
		return Settings.VOLUME_DEFAULT
	var value: Variant = settings.get(String(spec["prop"]))
	if not (value is float or value is int):
		return Settings.VOLUME_DEFAULT
	return Settings.clamp_volume(float(value))

func _stored_percent(id: String) -> int:
	return Settings.volume_to_percent(_stored_volume(id))

## Niveau affiché sur la ligne, tel que le joueur le voit.
func percent_of(id: String) -> int:
	if not _rows.has(id):
		return _stored_percent(id)
	return int(round((_rows[id]["slider"] as HSlider).value))

func value_text(id: String) -> String:
	if not _rows.has(id):
		return ""
	return (_rows[id]["value"] as Label).text

func notice_text(id: String) -> String:
	if not _rows.has(id):
		return ""
	return (_rows[id]["notice"] as Label).text

func is_muted(id: String) -> bool:
	return _stored_percent(id) <= 0

func has_bus(id: String) -> bool:
	var spec := spec_of(id)
	if spec.is_empty():
		return false
	return AudioServer.get_bus_index(String(spec["bus"])) != -1

# ---------------------------------------------------------------------------
# AUDITION
# ---------------------------------------------------------------------------

func _audio() -> Node:
	if audio_override != null:
		return audio_override
	if not is_inside_tree():
		return null
	return get_node_or_null(^"/root/AudioManager")

## Fait entendre le bus qu'on vient de régler.
##
## `forced` saute le délai de garde : réservé à la fin d'un glissement, où c'est
## la valeur définitive qu'il faut avoir entendue en dernier.
func _preview(id: String, forced: bool = false) -> void:
	# À zéro il n'y a rien à écouter, et c'est justement le message : le mot
	# « coupé » dit ce que le silence dirait moins clairement.
	if _stored_percent(id) <= 0:
		return
	if not has_bus(id):
		return
	var audio := _audio()
	if audio == null or not audio.has_method("play_sfx"):
		return

	var now := Time.get_ticks_msec()
	if not forced and _last_preview_ms.has(id) \
			and now - int(_last_preview_ms[id]) < preview_cooldown_ms:
		return
	_last_preview_ms[id] = now
	_play_preview(audio, id)

## Un son par bus, choisi pour qu'on entende ce qu'on règle et non un son voisin
## qui passerait par un autre bus.
func _play_preview(audio: Node, id: String) -> void:
	match id:
		ID_MASTER:
			# Routée sur Master directement : le volume général doit rester
			# auditionnable même quand les effets sont à zéro.
			audio.play_sfx(PREVIEW_NEUTRAL, 1.0, 0.0, Settings.BUS_MASTER)
		ID_MUSIC:
			# La musique des menus tourne déjà pendant qu'on règle : elle EST
			# l'audition, et lui superposer un son ne ferait que la salir. La mire
			# ne sert qu'au cas où plus rien ne joue.
			if not _music_is_playing(audio):
				audio.play_sfx(PREVIEW_NEUTRAL, 1.0, 0.0, Settings.BUS_MUSIC)
		ID_SFX:
			audio.play_sfx(PREVIEW_SFX)
		ID_SPEAKER:
			# La voix de l'annonceur n'est pas encore dans le dépôt : `play_speaker`
			# y renoncerait en silence, et un curseur dont l'audition ne fait aucun
			# bruit ne se distingue pas d'un curseur cassé.
			if _has_stream(audio, PREVIEW_SPEAKER) and audio.has_method("play_speaker"):
				audio.play_speaker(PREVIEW_SPEAKER)
			else:
				audio.play_sfx(PREVIEW_NEUTRAL, 1.0, 0.0, Settings.BUS_SPEAKER)

func _music_is_playing(audio: Node) -> bool:
	var player: Variant = audio.get("music_player")
	if player == null:
		return false
	return bool((player as Object).get("playing"))

func _has_stream(audio: Node, key: String) -> bool:
	if not audio.has_method("get_audio_stream"):
		return false
	return audio.get_audio_stream(key) != null
