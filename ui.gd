## UI — HUD de match, menus et navigation deux joueurs.
##
## Navigation : plus aucune table de voisinage codée à la main. Les contrôles
## focusables sont découverts dans l'arbre du panneau actif, et le voisin dans
## une direction est calculé géométriquement (voir `_closest_in_direction`).
## Ajouter un bouton ne demande donc aucune mise à jour de navigation.
##
## Deux curseurs indépendants coexistent (J1 et J2 naviguent simultanément).
## Un contrôle peut être réservé à un joueur via la métadonnée `nav_owner`,
## et désigné comme point d'entrée du focus via `nav_seed`.

extends CanvasLayer
class_name UI

signal replay_requested
signal quit_requested
signal main_menu_requested

# ---------------------------------------------------------------------------
# CHARTE VISUELLE
# ---------------------------------------------------------------------------

const COLOR_P1 := Color(0.0, 0.94, 1.0)
const COLOR_P2 := Color(1.0, 0.0, 0.33)
const COLOR_GOLD := Color(1.0, 0.8, 0.0)
const COLOR_DIM := Color(0.52, 0.55, 0.63)
const COLOR_LINE := Color(0.19, 0.2, 0.25)
const COLOR_SURFACE := Color(0.05, 0.055, 0.075, 0.92)

## Espacements : tous multiples de 8.
const GAP_XS := 8
const GAP_S := 16
const GAP_M := 24
const GAP_L := 40

## Transitions d'onglet : court, juste assez pour lier deux écrans.
const TAB_FADE := 0.15
const TAB_SLIDE := 32.0

## Métadonnées de navigation posées sur les contrôles.
const META_NAV_OWNER := "nav_owner"
const META_NAV_SEED := "nav_seed"

const TAB_PLAY := "JEU"
const TAB_MAPS := "CARTES"
const TAB_CONTROLS := "CONTROLES"

# ---------------------------------------------------------------------------
# CLASSES INTERNES
# ---------------------------------------------------------------------------

class CircularCooldown extends Control:
	var progress: float = 1.0
	var color: Color = Color.WHITE

	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - 4.0
		draw_arc(center, radius, 0, TAU, 32, Color(0.2, 0.2, 0.2), 4.0, true)
		if progress > 0.0:
			draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + progress * TAU, 32, color, 4.0, true)

	func set_progress(p: float) -> void:
		if p != progress:
			progress = p
			queue_redraw()


## Liseré néon animé qui matérialise le focus d'un joueur.
## Il suit sa cible en douceur : le déplacement du curseur devient lisible même
## quand deux joueurs bougent en même temps.
class NeonFocusRing extends Panel:
	var neon: Color = Color.WHITE
	var target_rect: Rect2 = Rect2()

	var _style: StyleBoxFlat
	var _time: float = 0.0
	var _snap: bool = true

	func _init(tint: Color = Color.WHITE) -> void:
		neon = tint
		mouse_filter = Control.MOUSE_FILTER_IGNORE

		_style = StyleBoxFlat.new()
		_style.draw_center = false
		_style.set_border_width_all(3)
		_style.border_color = tint
		_style.set_corner_radius_all(10)
		_style.shadow_size = 10
		_style.shadow_color = Color(tint.r, tint.g, tint.b, 0.4)
		add_theme_stylebox_override("panel", _style)

	func _ready() -> void:
		set_as_top_level(true)

	## Définit la zone à encadrer. `snap` téléporte au lieu d'interpoler.
	func aim(rect: Rect2, snap: bool = false) -> void:
		target_rect = rect
		if snap:
			_snap = true

	func _process(delta: float) -> void:
		_time += delta
		var wave := 0.5 + 0.5 * sin(_time * 6.0)
		_style.border_color = neon.lerp(Color.WHITE, 0.45 * wave)
		_style.shadow_size = int(roundf(lerpf(6.0, 16.0, wave)))
		_style.shadow_color = Color(neon.r, neon.g, neon.b, 0.22 + 0.33 * wave)

		if _snap:
			_snap = false
			global_position = target_rect.position
			size = target_rect.size
			return

		var t := clampf(delta * 22.0, 0.0, 1.0)
		global_position = global_position.lerp(target_rect.position, t)
		size = size.lerp(target_rect.size, t)

# ---------------------------------------------------------------------------
# HUD DE MATCH
# ---------------------------------------------------------------------------

## Conteneur racine du HUD de match (jauges, chrono, indicateurs).
## Masqué hors match : sans ça les panneaux joueurs restent visibles
## derrière le menu, dans les coins que la fenêtre de menu ne couvre pas.
var match_hud: MarginContainer
var p1_panel: PanelContainer
var p2_panel: PanelContainer

var p1_hp: ProgressBar
var p1_hp_bg: ProgressBar
var p1_cd: CircularCooldown
var p1_cd_label: Label
var p1_torch: PanelContainer
var p1_dazzle: ColorRect

var p2_hp: ProgressBar
var p2_hp_bg: ProgressBar
var p2_cd: CircularCooldown
var p2_cd_label: Label
var p2_torch: PanelContainer
var p2_dazzle: ColorRect

var time_label: Label
var waiting_label: Label
var center_line: Panel
var network_status_label: Label

var p1_shake_time: float = 0.0
var p2_shake_time: float = 0.0
var shake_intensity: float = 10.0

var p1_target_hp: float = 100.0
var p2_target_hp: float = 100.0
var p1_bg_hp: float = 100.0
var p2_bg_hp: float = 100.0

# ---------------------------------------------------------------------------
# DIALOGUE MODAL
# ---------------------------------------------------------------------------

var dialog_panel: PanelContainer
var dialog_title: Label
var dialog_message: Label
var dialog_btn: Button
var _previous_focus: Control

# ---------------------------------------------------------------------------
# MENU
# ---------------------------------------------------------------------------

var game_over_panel: PanelContainer
var game_over_title: Label
var game_over_score: Label

var btn_tab_game: Button
var btn_tab_map: Button
var btn_tab_controls: Button
var tab_game_container: VBoxContainer
var tab_map_container: VBoxContainer
var tab_controls_container: VBoxContainer
var content_host: Control

var map_gallery: MapGallery
var map_card: Button
var map_card_thumb: TextureRect
var map_card_name: Label
var map_card_meta: Label

var p1_weapon_group: ButtonGroup
var p2_weapon_group: ButtonGroup
var p1_vbox: VBoxContainer
var p2_vbox: VBoxContainer
var weapon_hbox: HBoxContainer

var p1_btn1: Button
var p1_btn2: Button
var p1_btn3: Button
var p1_btn4: Button
var p2_btn1: Button
var p2_btn2: Button
var p2_btn3: Button
var p2_btn4: Button

var mode_vbox: VBoxContainer
var mode_group: ButtonGroup
var btn_mode_local: Button
var btn_mode_online: Button
var btn_mode_host: Button
var btn_mode_join: Button
var online_hbox: HBoxContainer
var lobby_status_label: Label
var ip_input: LineEdit

var pause_info_container: VBoxContainer
var pause_score_label: Label
var pause_time_label: Label

var btn_actions: HBoxContainer
var btn_resume: Button
var btn_replay: Button
var btn_main_menu: Button
var btn_quit: Button

var _controls_grid_buttons: Array = []
var _is_rebinding: bool = false
var _action_to_rebind: String = ""
var _button_to_update: Button = null

var debug_panel: PanelContainer
var fps_label: Label
var debug_mode_active: bool = false
var _f3_was_pressed: bool = false

var _is_main_menu: bool = true

# ---------------------------------------------------------------------------
# KILLCAM
# ---------------------------------------------------------------------------

var killcam_overlay: ColorRect
var killcam_container: Control
var killcam_label_shadow1: Label
var killcam_label_shadow2: Label
var killcam_timecode: Label
var killcam_label: Label
var _killcam_glitch_timer: float = 0.0

# ---------------------------------------------------------------------------
# NAVIGATION
# ---------------------------------------------------------------------------

var p1_focus: Control
var p2_focus: Control
var p1_cursor: NeonFocusRing
var p2_cursor: NeonFocusRing

var _current_tab: String = TAB_PLAY
var _active_tab: Control
var _tab_tween: Tween

# ===========================================================================
# CYCLE DE VIE
# ===========================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_disable_ui_joystick()
	_build_hud()
	_build_killcam()
	_build_menu()
	_build_dialog()
	_build_status_bar()
	_build_debug_panel()

	p1_cursor = NeonFocusRing.new(COLOR_P1)
	add_child(p1_cursor)
	p2_cursor = NeonFocusRing.new(COLOR_P2)
	add_child(p2_cursor)

	MapData.map_selected.connect(func(_id: String) -> void: _refresh_map_card())
	MapData.catalog_changed.connect(_refresh_map_card)
	_refresh_map_card()

	_wire_buttons(self)
	_switch_tab(TAB_PLAY, false)

## Le stick gauche pilote les curseurs joueurs : il ne doit pas déplacer en plus
## le focus natif de Godot, sous peine de double déplacement.
func _disable_ui_joystick() -> void:
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]:
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				if event is InputEventJoypadMotion:
					InputMap.action_erase_event(action, event)

## Branche le son et l'à-coup d'échelle sur tous les boutons du menu.
## La galerie est exclue : elle gère ses propres retours, y compris sur les
## tuiles créées dynamiquement après ce parcours.
func _wire_buttons(node: Node) -> void:
	if node is MapGallery:
		return
	var btn := node as BaseButton
	if btn != null:
		btn.pressed.connect(_on_any_button_pressed.bind(btn))
	for child in node.get_children():
		_wire_buttons(child)

func _on_any_button_pressed(btn: BaseButton) -> void:
	AudioManager.play_button_click()
	_pulse_press(btn)

## Petit à-coup d'échelle : retour visuel immédiat sur chaque appui.
func _pulse_press(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.pivot_offset = control.size / 2.0
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(0.94, 0.94), 0.06)
	tween.tween_property(control, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ===========================================================================
# BOUCLE
# ===========================================================================

func _process(delta: float) -> void:
	_update_network_status()
	_update_focus_rings()
	_update_health_trails(delta)
	_update_shake(delta)
	_update_debug(delta)
	_update_killcam(delta)

func _update_network_status() -> void:
	var mode_str := "[LOCAL]"
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		mode_str = "[ONLINE_HOST]"
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		mode_str = "[ONLINE_CLIENT]"

	var conn_str := "Déconnecté"
	network_status_label.add_theme_color_override("font_color", Color.RED)
	if multiplayer.has_multiplayer_peer():
		var status := multiplayer.multiplayer_peer.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			conn_str = "Connecté (Peers: %d)" % multiplayer.get_peers().size()
			network_status_label.add_theme_color_override("font_color", Color.GREEN)
		elif status == MultiplayerPeer.CONNECTION_CONNECTING:
			conn_str = "En attente (Connexion...)"
			network_status_label.add_theme_color_override("font_color", Color.YELLOW)

	var gs := get_tree().get_first_node_in_group("game_state")
	var situation := "Menu"
	if gs:
		if gs.sandbox_mode:
			situation = "Sandbox (Attente J2)"
		elif gs.round_active:
			situation = "Match en cours"
		elif gs.game_over:
			situation = "Attente Rematch"
		elif ReplaySystem.playing_back:
			situation = "Killcam"

	network_status_label.text = "%s | %s | %s" % [mode_str, conn_str, situation]

## Place les deux liserés de focus. Un curseur dont la cible a disparu est
## réamorcé plutôt que masqué : le joueur n'est jamais bloqué.
func _update_focus_rings() -> void:
	if game_over_panel == null or p1_cursor == null or p2_cursor == null:
		return

	var menu_open := game_over_panel.visible or (dialog_panel != null and dialog_panel.visible)
	if not menu_open:
		p1_cursor.hide()
		p2_cursor.hide()
		return

	if not _is_focus_usable(p1_focus):
		_seed_focus(0)
	if not _is_focus_usable(p2_focus):
		_seed_focus(1)

	# En ligne, chaque machine ne pilote que son propre curseur.
	var show_p1 := true
	var show_p2 := true
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		show_p1 = false
	elif NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST:
		show_p2 = false
	elif _is_main_menu and btn_mode_local != null and not btn_mode_local.button_pressed:
		show_p2 = false

	if show_p1 and _is_focus_usable(p1_focus):
		if not p1_cursor.visible:
			p1_cursor.show()
			p1_cursor.aim(p1_focus.get_global_rect(), true)
		else:
			p1_cursor.aim(p1_focus.get_global_rect())
	else:
		p1_cursor.hide()

	if show_p2 and _is_focus_usable(p2_focus):
		var rect := p2_focus.get_global_rect()
		# Les deux joueurs sur la même cible : on décale J2 pour que les deux
		# liserés restent lisibles.
		if p1_focus == p2_focus and p1_cursor.visible:
			rect = rect.grow(4.0)
		if not p2_cursor.visible:
			p2_cursor.show()
			p2_cursor.aim(rect, true)
		else:
			p2_cursor.aim(rect)
	else:
		p2_cursor.hide()

func _update_health_trails(delta: float) -> void:
	if p1_bg_hp > p1_target_hp:
		p1_bg_hp = maxf(p1_target_hp, p1_bg_hp - 30.0 * delta)
		p1_hp_bg.value = p1_bg_hp
	elif p1_bg_hp < p1_target_hp:
		p1_bg_hp = p1_target_hp
		p1_hp_bg.value = p1_bg_hp

	if p2_bg_hp > p2_target_hp:
		p2_bg_hp = maxf(p2_target_hp, p2_bg_hp - 30.0 * delta)
		p2_hp_bg.value = p2_bg_hp
	elif p2_bg_hp < p2_target_hp:
		p2_bg_hp = p2_target_hp
		p2_hp_bg.value = p2_bg_hp

func _update_shake(delta: float) -> void:
	if p1_shake_time > 0.0:
		p1_shake_time -= delta
		p1_panel.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
	else:
		p1_panel.position = Vector2.ZERO

	if p2_shake_time > 0.0:
		p2_shake_time -= delta
		p2_panel.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
	else:
		p2_panel.position = Vector2.ZERO

func _update_debug(_delta: float) -> void:
	var f3_pressed := Input.is_physical_key_pressed(KEY_F3)
	if f3_pressed and not _f3_was_pressed:
		debug_mode_active = not debug_mode_active
		debug_panel.visible = debug_mode_active
	_f3_was_pressed = f3_pressed

	if debug_mode_active:
		fps_label.text = "DEBUG | FPS %d | Cartes %d" % [
			Engine.get_frames_per_second(), MapData.list_maps().size(),
		]

func _update_killcam(delta: float) -> void:
	if killcam_container == null or not killcam_container.visible:
		return

	var ms := Time.get_ticks_msec()
	var sec := (ms / 1000) % 60
	var mins := (ms / 60000) % 60
	var frames := Engine.get_frames_drawn() % 60

	if (ms / 500) % 2 == 0:
		killcam_timecode.text = "REC •\n%02d:%02d:%02d" % [mins, sec, frames]
		killcam_timecode.add_theme_color_override("font_color", Color(1, 0, 0, 0.8))
	else:
		killcam_timecode.text = "REC  \n%02d:%02d:%02d" % [mins, sec, frames]
		killcam_timecode.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))

	if killcam_overlay.material:
		killcam_overlay.material.set_shader_parameter("time", ms / 1000.0)

	_killcam_glitch_timer -= delta
	if _killcam_glitch_timer <= 0.0:
		if randf() > 0.8:
			killcam_label_shadow1.position = Vector2(randf_range(-10, 10), randf_range(-5, 5))
			killcam_label_shadow2.position = Vector2(randf_range(-10, 10), randf_range(-5, 5))
			killcam_label.position = Vector2(randf_range(-3, 3), 0)
			_killcam_glitch_timer = randf_range(0.05, 0.1)
		else:
			killcam_label_shadow1.position = Vector2(-3, 0)
			killcam_label_shadow2.position = Vector2(3, 0)
			killcam_label.position = Vector2.ZERO
			_killcam_glitch_timer = randf_range(0.1, 0.3)
		killcam_label.modulate.a = 0.8 + 0.2 * sin(ms * 0.01)

# ===========================================================================
# NAVIGATION — RÉSOLVEUR GÉOMÉTRIQUE
# ===========================================================================
#
# Choix d'implémentation : un résolveur maison plutôt que focus_neighbor_*.
#   • Le focus natif de Godot est unique par viewport ; le jeu a deux curseurs
#     simultanés, il est donc inutilisable tel quel.
#   • La galerie de cartes est une grille dont le nombre de colonnes dépend de
#     la largeur de la fenêtre et dont le contenu change à chaque import : tout
#     câblage explicite serait à refaire en permanence.
# Le résolveur ne lit que la position à l'écran des contrôles visibles : il
# s'adapte donc automatiquement à n'importe quelle disposition.

## Contrôles focusables offerts à un joueur dans l'état courant du menu.
func _nav_candidates(player: int) -> Array[Control]:
	var out: Array[Control] = []
	if dialog_panel != null and dialog_panel.visible:
		if dialog_btn != null:
			out.append(dialog_btn)
		return out
	if _active_tab != null:
		_collect_focusables(_active_tab, player, out)
	if btn_actions != null:
		_collect_focusables(btn_actions, player, out)
	return out

func _collect_focusables(node: Node, player: int, out: Array[Control]) -> void:
	var control := node as Control
	if control != null:
		if not control.visible:
			return
		if control.focus_mode != Control.FOCUS_NONE:
			var owner_id := int(control.get_meta(META_NAV_OWNER, -1))
			var reserved := owner_id >= 0 and owner_id != player
			var btn := control as BaseButton
			var locked := btn != null and btn.disabled
			if not reserved and not locked:
				out.append(control)
			# Un contrôle focusable n'héberge jamais d'autre contrôle focusable.
			return
	for child in node.get_children():
		_collect_focusables(child, player, out)

## Voisin le plus proche dans une direction.
## `strict` impose un cône à 45° ; un second passage l'élargit pour ne jamais
## laisser un curseur bloqué dans un coin de l'écran.
func _closest_in_direction(from: Control, dir: Vector2,
		candidates: Array[Control], strict: bool) -> Control:
	var from_rect := from.get_global_rect()
	var origin := from_rect.get_center()
	var perp := Vector2(dir.y, -dir.x)
	var horizontal := absf(dir.x) > 0.5

	var best: Control = null
	var best_score := INF

	for candidate in candidates:
		if candidate == from:
			continue
		var rect := candidate.get_global_rect()
		var delta := rect.get_center() - origin
		var along := delta.dot(dir)
		if along <= 1.0:
			continue
		var side := absf(delta.dot(perp))
		if strict and side >= along:
			continue

		# Écart perpendiculaire réel entre les deux rectangles : deux contrôles
		# de la même colonne ont un écart nul, donc la priorité absolue.
		var gap := 0.0
		if horizontal:
			gap = maxf(0.0, maxf(from_rect.position.y - rect.end.y, rect.position.y - from_rect.end.y))
		else:
			gap = maxf(0.0, maxf(from_rect.position.x - rect.end.x, rect.position.x - from_rect.end.x))

		var score := along + gap * 4.0 + side * 0.25
		if score < best_score:
			best_score = score
			best = candidate

	return best

func _navigate(player: int, dir: Vector2) -> void:
	var from := p1_focus if player == 0 else p2_focus
	if not _is_focus_usable(from):
		_seed_focus(player)
		return

	var candidates := _nav_candidates(player)
	var next := _closest_in_direction(from, dir, candidates, true)
	if next == null:
		next = _closest_in_direction(from, dir, candidates, false)
	if next == null:
		return
	_set_focus(player, next)

func _set_focus(player: int, control: Control, snap: bool = false) -> void:
	if control == null:
		return
	if player == 0:
		p1_focus = control
		if p1_cursor != null:
			p1_cursor.aim(control.get_global_rect(), snap)
	else:
		p2_focus = control
		if p2_cursor != null:
			p2_cursor.aim(control.get_global_rect(), snap)

	if map_gallery != null and map_gallery.is_ancestor_of(control):
		map_gallery.reveal(control)

func _is_focus_usable(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	if not control.is_visible_in_tree():
		return false
	var btn := control as BaseButton
	if btn != null and btn.disabled:
		return false
	return true

## Point d'entrée du focus pour un joueur, par ordre de priorité :
## métadonnée `nav_seed`, carte sélectionnée dans la galerie, puis le contrôle
## le plus en haut à gauche.
func _seed_focus(player: int) -> void:
	var candidates := _nav_candidates(player)
	if candidates.is_empty():
		if player == 0:
			p1_focus = null
		else:
			p2_focus = null
		return

	for candidate in candidates:
		if int(candidate.get_meta(META_NAV_SEED, -1)) == player:
			_set_focus(player, candidate, true)
			return

	if _active_tab == tab_map_container and map_gallery != null:
		var tile := map_gallery.selected_tile()
		if tile != null and candidates.has(tile):
			_set_focus(player, tile, true)
			return

	candidates.sort_custom(func(a: Control, b: Control) -> bool:
		var ra := a.get_global_rect().position
		var rb := b.get_global_rect().position
		if absf(ra.y - rb.y) > 4.0:
			return ra.y < rb.y
		return ra.x < rb.x
	)
	_set_focus(player, candidates[0], true)

## Déclenche le contrôle sous le curseur d'un joueur.
func _activate(player: int) -> void:
	var target := p1_focus if player == 0 else p2_focus
	if not _is_focus_usable(target):
		return

	var line_edit := target as LineEdit
	if line_edit != null:
		line_edit.grab_focus()
		return

	var btn := target as BaseButton
	if btn == null:
		return

	if btn.toggle_mode:
		if btn.button_group != null:
			btn.button_pressed = true
		else:
			btn.button_pressed = not btn.button_pressed
	# Le son et l'à-coup d'échelle sont branchés sur `pressed` (voir _wire_buttons).
	btn.pressed.emit()

# ===========================================================================
# CONSTRUCTION — HUD
# ===========================================================================

func _build_hud() -> void:
	var scanline := ColorRect.new()
	scanline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanline.color = Color(0, 0, 0, 0.1)
	scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scanline)

	center_line = Panel.new()
	center_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center_line.size = Vector2(4, 2000)
	center_line.position = Vector2(-2, 0)
	var line_style := StyleBoxFlat.new()
	line_style.bg_color = Color(COLOR_P1.r, COLOR_P1.g, COLOR_P1.b, 0.8)
	line_style.shadow_color = Color(COLOR_P1.r, COLOR_P1.g, COLOR_P1.b, 0.5)
	line_style.shadow_size = 20
	center_line.add_theme_stylebox_override("panel", line_style)
	add_child(center_line)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", GAP_M)
	margin.add_theme_constant_override("margin_left", GAP_M)
	margin.add_theme_constant_override("margin_right", GAP_M)
	margin.add_theme_constant_override("margin_bottom", GAP_M)
	add_child(margin)
	match_hud = margin

	var hbox := HBoxContainer.new()
	margin.add_child(hbox)

	hbox.add_child(_build_player_hud(0))
	hbox.add_child(_build_center_hud())
	hbox.add_child(_build_player_hud(1))

	var dazzle_hbox := HBoxContainer.new()
	dazzle_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dazzle_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dazzle_hbox.add_theme_constant_override("separation", 0)
	add_child(dazzle_hbox)

	p1_dazzle = ColorRect.new()
	p1_dazzle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p1_dazzle.color = Color(1, 1, 1, 0)
	p1_dazzle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dazzle_hbox.add_child(p1_dazzle)

	p2_dazzle = ColorRect.new()
	p2_dazzle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p2_dazzle.color = Color(1, 1, 1, 0)
	p2_dazzle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dazzle_hbox.add_child(p2_dazzle)

func _build_player_hud(player: int) -> Control:
	var tint := COLOR_P1 if player == 0 else COLOR_P2

	var wrapper := Control.new()
	wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if player == 0 else Control.SIZE_SHRINK_END
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wrapper.custom_minimum_size = Vector2(352, 152)

	var panel := _create_glow_panel(tint)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_top", GAP_S)
	inner.add_theme_constant_override("margin_left", GAP_M)
	inner.add_theme_constant_override("margin_right", GAP_M)
	inner.add_theme_constant_override("margin_bottom", GAP_S)
	panel.add_child(inner)

	var hud := VBoxContainer.new()
	hud.add_theme_constant_override("separation", 10)
	inner.add_child(hud)

	var header := HBoxContainer.new()
	hud.add_child(header)

	var name_label := Label.new()
	name_label.text = "JOUEUR 1" if player == 0 else "JOUEUR 2"
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", tint)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if player == 1:
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(name_label)

	var hp_label := Label.new()
	hp_label.text = "SANTÉ"
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_label.add_theme_color_override("font_color", COLOR_DIM)
	hud.add_child(hp_label)

	var bars := _create_health_bars(tint)
	hud.add_child(bars["container"])

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", GAP_S)
	hud.add_child(bottom)

	var weapon := _create_weapon_indicator(tint)
	var torch := _create_torch_indicator()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if player == 0:
		bottom.add_child(weapon["container"])
		bottom.add_child(spacer)
		bottom.add_child(torch)
		p1_panel = panel
		p1_hp = bars["fg"]
		p1_hp_bg = bars["bg"]
		p1_cd = weapon["circle"]
		p1_cd_label = weapon["label"]
		p1_torch = torch
	else:
		bottom.add_child(torch)
		bottom.add_child(spacer)
		bottom.add_child(weapon["container"])
		p2_panel = panel
		p2_hp = bars["fg"]
		p2_hp_bg = bars["bg"]
		p2_cd = weapon["circle"]
		p2_cd_label = weapon["label"]
		p2_torch = torch

	return wrapper

func _build_center_hud() -> Control:
	var center_hud := VBoxContainer.new()
	center_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hud.alignment = BoxContainer.ALIGNMENT_BEGIN

	var panel := _create_glow_panel(Color(0.3, 0.3, 0.3))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(208, 0)
	center_hud.add_child(panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_top", GAP_XS)
	inner.add_theme_constant_override("margin_left", GAP_S)
	inner.add_theme_constant_override("margin_right", GAP_S)
	inner.add_theme_constant_override("margin_bottom", GAP_XS)
	panel.add_child(inner)

	var vbox := VBoxContainer.new()
	inner.add_child(vbox)

	var title := Label.new()
	title.text = "CANDELA 2D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(title)

	time_label = Label.new()
	time_label.text = "02:00"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 36)
	vbox.add_child(time_label)

	waiting_label = Label.new()
	waiting_label.text = "EN ATTENTE DU JOUEUR 2..."
	waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waiting_label.add_theme_font_size_override("font_size", 24)
	waiting_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.2))
	waiting_label.hide()
	vbox.add_child(waiting_label)

	return center_hud

func _create_glow_panel(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	style.set_border_width_all(2)
	style.border_color = color
	style.set_corner_radius_all(12)
	style.shadow_color = color
	style.shadow_size = 15
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _create_health_bars(color: Color) -> Dictionary:
	var container := MarginContainer.new()
	container.custom_minimum_size = Vector2(0, 12)

	var bg_bar := ProgressBar.new()
	bg_bar.max_value = 100
	bg_bar.value = 100
	bg_bar.show_percentage = false
	bg_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	bg_style.set_corner_radius_all(6)
	bg_bar.add_theme_stylebox_override("background", bg_style)

	var bg_fill := StyleBoxFlat.new()
	bg_fill.bg_color = Color(0.8, 0.0, 0.2)
	bg_fill.set_corner_radius_all(6)
	bg_bar.add_theme_stylebox_override("fill", bg_fill)

	var fg_bar := ProgressBar.new()
	fg_bar.max_value = 100
	fg_bar.value = 100
	fg_bar.show_percentage = false
	fg_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fg_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())

	var fg_fill := StyleBoxFlat.new()
	fg_fill.bg_color = color
	fg_fill.set_corner_radius_all(6)
	fg_fill.shadow_color = color
	fg_fill.shadow_size = 8
	fg_bar.add_theme_stylebox_override("fill", fg_fill)

	container.add_child(bg_bar)
	container.add_child(fg_bar)

	return {"container": container, "fg": fg_bar, "bg": bg_bar}

func _create_weapon_indicator(color: Color) -> Dictionary:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", GAP_S)

	var circle_container := MarginContainer.new()
	circle_container.custom_minimum_size = Vector2(40, 40)

	var circle := CircularCooldown.new()
	circle.color = color
	circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	circle_container.add_child(circle)

	var label := Label.new()
	label.text = "PRÊT"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	circle_container.add_child(label)

	var title := Label.new()
	title.text = "ARME"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	container.add_child(circle_container)
	container.add_child(title)

	return {"container": container, "circle": circle, "label": label}

func _create_torch_indicator() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", GAP_XS)
	margin.add_child(hbox)

	var icon := Label.new()
	icon.text = "🔦"
	icon.add_theme_font_size_override("font_size", 12)
	hbox.add_child(icon)

	var label := Label.new()
	label.text = "TORCHE"
	label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(label)

	_set_torch_style(panel, false, Color.WHITE)
	return panel

func _set_torch_style(panel: PanelContainer, active: bool, player_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)

	if active:
		style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		style.border_color = player_color
		style.shadow_color = player_color
		style.shadow_size = 5
	else:
		style.bg_color = Color(0.05, 0.05, 0.05, 0.8)
		style.border_color = Color(0.2, 0.2, 0.2, 1.0)
		style.shadow_size = 0

	panel.add_theme_stylebox_override("panel", style)

	var hbox := panel.get_child(0).get_child(0)
	var label := hbox.get_child(1) as Label
	if active:
		label.add_theme_color_override("font_color", Color.WHITE)
	else:
		label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

# ===========================================================================
# CONSTRUCTION — ANNEXES
# ===========================================================================

func _build_status_bar() -> void:
	network_status_label = Label.new()
	network_status_label.z_index = 100
	network_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_status_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	network_status_label.add_theme_font_size_override("font_size", 14)
	network_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	network_status_label.add_theme_constant_override("outline_size", 4)

	var status_margin := MarginContainer.new()
	status_margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status_margin.add_theme_constant_override("margin_bottom", 10)
	status_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_margin.add_child(network_status_label)
	add_child(status_margin)

func _build_debug_panel() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	debug_panel.offset_left = GAP_S
	debug_panel.offset_top = GAP_S
	debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_panel.hide()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.set_border_width_all(1)
	style.border_color = COLOR_GOLD
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	debug_panel.add_theme_stylebox_override("panel", style)

	fps_label = Label.new()
	fps_label.text = "DEBUG"
	fps_label.add_theme_font_size_override("font_size", 13)
	fps_label.add_theme_color_override("font_color", COLOR_GOLD)
	debug_panel.add_child(fps_label)

	add_child(debug_panel)

func _build_dialog() -> void:
	dialog_panel = PanelContainer.new()
	dialog_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.97)
	style.set_border_width_all(2)
	style.border_color = COLOR_GOLD
	style.set_corner_radius_all(12)
	style.content_margin_left = GAP_L
	style.content_margin_right = GAP_L
	style.content_margin_top = GAP_M
	style.content_margin_bottom = GAP_M
	dialog_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", GAP_S)
	dialog_panel.add_child(vbox)

	dialog_title = Label.new()
	dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_title.add_theme_font_size_override("font_size", 24)
	dialog_title.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(dialog_title)

	dialog_message = Label.new()
	dialog_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_message.add_theme_font_size_override("font_size", 15)
	vbox.add_child(dialog_message)

	dialog_btn = _make_button("OK", COLOR_GOLD, true)
	dialog_btn.custom_minimum_size = Vector2(160, 48)
	dialog_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialog_btn.pressed.connect(_on_dialog_closed)
	vbox.add_child(dialog_btn)

	dialog_panel.hide()
	add_child(dialog_panel)

func _build_killcam() -> void:
	killcam_overlay = ColorRect.new()
	killcam_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	killcam_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	killcam_overlay.hide()

	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float time = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float scanline = sin(uv.y * 800.0) * 0.04;
	float noise = fract(sin(dot(uv + time, vec2(12.9898, 78.233))) * 43758.5453);
	float r = texture(screen_texture, uv + vec2(0.003, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(0.003, 0.0)).b;
	vec3 col = vec3(r, g, b) + noise * 0.05 - scanline;
	col *= smoothstep(0.8, 0.2, distance(uv, vec2(0.5)) * 1.2);
	COLOR = vec4(col, 1.0);
}
"""
	material.shader = shader
	killcam_overlay.material = material
	# killcam_overlay n'est PAS ajouté ici : GameState le reparente dans l'arène.

	killcam_container = Control.new()
	killcam_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	killcam_container.offset_top = 100
	killcam_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	killcam_container.hide()
	add_child(killcam_container)

	killcam_label_shadow1 = _make_killcam_label(Color(0, 1, 1, 0.5))
	killcam_container.add_child(killcam_label_shadow1)
	killcam_label_shadow2 = _make_killcam_label(Color(1, 1, 0, 0.5))
	killcam_container.add_child(killcam_label_shadow2)
	killcam_label = _make_killcam_label(Color(1, 0, 0))
	killcam_container.add_child(killcam_label)

	killcam_timecode = Label.new()
	killcam_timecode.add_theme_font_size_override("font_size", 24)
	killcam_timecode.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	killcam_timecode.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	killcam_timecode.offset_right = -40
	killcam_timecode.offset_top = 40
	killcam_timecode.hide()
	add_child(killcam_timecode)

func _make_killcam_label(tint: Color) -> Label:
	var label := Label.new()
	label.text = "KILLCAM"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", tint)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return label

# ===========================================================================
# CONSTRUCTION — MENU
# ===========================================================================

func _build_menu() -> void:
	game_over_panel = PanelContainer.new()
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_panel.hide()
	add_child(game_over_panel)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.012, 0.02, 0.96)
	game_over_panel.add_child(backdrop)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_top", GAP_L)
	outer.add_theme_constant_override("margin_bottom", GAP_L)
	outer.add_theme_constant_override("margin_left", GAP_L + GAP_S)
	outer.add_theme_constant_override("margin_right", GAP_L + GAP_S)
	game_over_panel.add_child(outer)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", GAP_M)
	outer.add_child(root)

	root.add_child(_build_menu_header())
	root.add_child(_build_tab_bar())

	# Hôte des onglets : chaque page est ancrée en plein cadre, ce qui permet de
	# les faire glisser latéralement sans perturber la mise en page.
	content_host = Control.new()
	content_host.custom_minimum_size = Vector2(0, 440)
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_host.clip_contents = true
	root.add_child(content_host)

	tab_game_container = _make_tab_page()
	content_host.add_child(tab_game_container)
	_fill_play_tab()

	tab_map_container = _make_tab_page()
	content_host.add_child(tab_map_container)
	_fill_maps_tab()

	tab_controls_container = _make_tab_page()
	content_host.add_child(tab_controls_container)
	_fill_controls_tab()

	root.add_child(_build_actions_bar())

func _make_tab_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", GAP_M)
	page.hide()
	return page

func _build_menu_header() -> Control:
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", GAP_XS)

	game_over_title = Label.new()
	game_over_title.text = "CANDELA 2D"
	game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_title.add_theme_font_size_override("font_size", 60)
	game_over_title.add_theme_color_override("font_color", COLOR_GOLD)
	header.add_child(game_over_title)

	game_over_score = Label.new()
	game_over_score.text = "PRÊT À JOUER ?"
	game_over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_score.add_theme_font_size_override("font_size", 22)
	game_over_score.add_theme_color_override("font_color", COLOR_DIM)
	header.add_child(game_over_score)

	return header

func _build_tab_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", GAP_XS)

	bar.add_child(_make_shoulder_icon("l1.svg"))

	btn_tab_game = _make_tab_button("JOUER", TAB_PLAY)
	bar.add_child(btn_tab_game)
	btn_tab_map = _make_tab_button("CARTES", TAB_MAPS)
	bar.add_child(btn_tab_map)
	btn_tab_controls = _make_tab_button("CONTRÔLES", TAB_CONTROLS)
	bar.add_child(btn_tab_controls)

	bar.add_child(_make_shoulder_icon("r1.svg"))
	return bar

func _make_shoulder_icon(file_name: String) -> TextureRect:
	var icon := TextureRect.new()
	var path := "res://assets/ui/prompts/" + file_name
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(26, 26)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icon

## Onglet façon « soulignement » : pas de pavé plein, juste un trait néon sous
## le libellé actif. Aucun ButtonGroup — l'état est piloté par _switch_tab.
func _make_tab_button(label: String, tab_name: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(184, 48)
	btn.add_theme_font_size_override("font_size", 20)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_width_bottom = 2
	normal.border_color = COLOR_LINE
	normal.content_margin_left = GAP_M
	normal.content_margin_right = GAP_M
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(0.7, 0.72, 0.8)
	hover.bg_color = Color(1, 1, 1, 0.04)
	btn.add_theme_stylebox_override("hover", hover)

	var active := normal.duplicate() as StyleBoxFlat
	active.border_width_bottom = 3
	active.border_color = COLOR_P1
	active.bg_color = Color(COLOR_P1.r, COLOR_P1.g, COLOR_P1.b, 0.07)
	active.shadow_color = Color(COLOR_P1.r, COLOR_P1.g, COLOR_P1.b, 0.35)
	active.shadow_size = 6
	btn.add_theme_stylebox_override("pressed", active)
	btn.add_theme_stylebox_override("hover_pressed", active)

	btn.add_theme_color_override("font_color", COLOR_DIM)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_pressed_color", Color.WHITE)

	btn.pressed.connect(func() -> void: _switch_tab(tab_name))
	return btn

## Bouton générique du menu. `primary` remplit le fond avec la teinte donnée.
func _make_button(label: String, accent: Color, primary: bool = false) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 18)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.85) if primary else COLOR_SURFACE
	normal.set_border_width_all(2)
	normal.border_color = accent if primary else Color(accent.r, accent.g, accent.b, 0.4)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = GAP_M
	normal.content_margin_right = GAP_M
	normal.content_margin_top = 12
	normal.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color.WHITE
	hover.bg_color = accent if primary else Color(accent.r, accent.g, accent.b, 0.16)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	hover.shadow_size = 8
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = accent
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.06, 0.06, 0.08, 0.8)
	disabled.border_color = COLOR_LINE
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Color(0.32, 0.33, 0.38))

	if primary:
		btn.add_theme_color_override("font_color", Color.BLACK)
		btn.add_theme_color_override("font_hover_color", Color.BLACK)
		btn.add_theme_color_override("font_pressed_color", Color.BLACK)
		btn.add_theme_color_override("font_hover_pressed_color", Color.BLACK)
		btn.add_theme_color_override("font_focus_color", Color.BLACK)

	return btn

## Bouton à bascule d'un groupe de choix (mode de jeu, résolution…).
func _make_choice_button(label: String, accent: Color, group: ButtonGroup) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.button_group = group
	btn.custom_minimum_size = Vector2(200, 48)
	btn.add_theme_font_size_override("font_size", 16)

	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_SURFACE
	normal.set_border_width_all(2)
	normal.border_color = COLOR_LINE
	normal.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.1)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var active := normal.duplicate() as StyleBoxFlat
	active.bg_color = Color(accent.r, accent.g, accent.b, 0.9)
	active.border_color = Color.WHITE
	active.shadow_color = Color(accent.r, accent.g, accent.b, 0.4)
	active.shadow_size = 10
	btn.add_theme_stylebox_override("pressed", active)
	btn.add_theme_stylebox_override("hover_pressed", active)

	btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	btn.add_theme_color_override("font_hover_pressed_color", Color.BLACK)
	return btn

func _make_section_label(text: String, tint: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", tint)
	return label

# ---------------------------------------------------------------------------
# ONGLET JOUER
# ---------------------------------------------------------------------------

func _fill_play_tab() -> void:
	var center := CenterContainer.new()
	center.add_child(_build_map_card())
	tab_game_container.add_child(center)

	tab_game_container.add_child(_build_mode_block())
	tab_game_container.add_child(_build_weapon_block())
	tab_game_container.add_child(_build_pause_block())

## Carte sélectionnée, visible depuis l'onglet JOUER : on sait toujours sur quoi
## on s'apprête à jouer, et un appui mène droit à la galerie.
func _build_map_card() -> Control:
	map_card = Button.new()
	map_card.custom_minimum_size = Vector2(400, 104)
	map_card.tooltip_text = "Changer de carte"

	var normal := StyleBoxFlat.new()
	normal.bg_color = COLOR_SURFACE
	normal.set_border_width_all(2)
	normal.border_color = COLOR_LINE
	normal.set_corner_radius_all(12)
	map_card.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = COLOR_P1
	hover.bg_color = Color(COLOR_P1.r, COLOR_P1.g, COLOR_P1.b, 0.08)
	map_card.add_theme_stylebox_override("hover", hover)
	map_card.add_theme_stylebox_override("focus", hover)
	map_card.add_theme_stylebox_override("pressed", hover)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	row.add_theme_constant_override("separation", GAP_S)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_card.add_child(row)

	map_card_thumb = TextureRect.new()
	map_card_thumb.custom_minimum_size = Vector2(80, 80)
	map_card_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_card_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_card_thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_card_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(map_card_thumb)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)

	var kicker := Label.new()
	kicker.text = "CARTE"
	kicker.add_theme_font_size_override("font_size", 11)
	kicker.add_theme_color_override("font_color", COLOR_DIM)
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(kicker)

	map_card_name = Label.new()
	map_card_name.text = "—"
	map_card_name.add_theme_font_size_override("font_size", 22)
	map_card_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	map_card_name.clip_text = true
	map_card_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(map_card_name)

	map_card_meta = Label.new()
	map_card_meta.text = ""
	map_card_meta.add_theme_font_size_override("font_size", 12)
	map_card_meta.add_theme_color_override("font_color", COLOR_DIM)
	map_card_meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(map_card_meta)

	var chevron := Label.new()
	chevron.text = "CHANGER  ›"
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.add_theme_font_size_override("font_size", 13)
	chevron.add_theme_color_override("font_color", COLOR_P1)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chevron)

	map_card.pressed.connect(func() -> void: _switch_tab(TAB_MAPS))
	return map_card

func _refresh_map_card() -> void:
	if map_card == null:
		return
	var entry := MapData.get_map(MapData.selected_map_id)
	if entry.is_empty():
		map_card_name.text = "Aucune carte"
		map_card_meta.text = ""
		map_card_thumb.texture = null
		return

	var grid: Vector2i = entry["grid_size"]
	var origin := "Officielle" if String(entry["source"]) == "builtin" else "Perso"
	map_card_name.text = String(entry["name"])
	map_card_meta.text = "%d×%d  ·  %d murs  ·  %s" % [
		grid.x, grid.y, int(entry["wall_count"]), origin,
	]
	map_card_thumb.texture = MapThumbnail.render_fit(entry["data"], 80)

func _build_mode_block() -> Control:
	mode_vbox = VBoxContainer.new()
	mode_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_vbox.add_theme_constant_override("separation", GAP_XS)

	mode_group = ButtonGroup.new()
	var online_group := ButtonGroup.new()

	var mode_hbox := HBoxContainer.new()
	mode_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_hbox.add_theme_constant_override("separation", GAP_S)

	btn_mode_local = _make_choice_button("1V1 LOCAL", COLOR_P1, mode_group)
	btn_mode_local.button_pressed = true
	mode_hbox.add_child(btn_mode_local)

	btn_mode_online = _make_choice_button("1V1 EN LIGNE", COLOR_P1, mode_group)
	mode_hbox.add_child(btn_mode_online)
	mode_vbox.add_child(mode_hbox)

	online_hbox = HBoxContainer.new()
	online_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	online_hbox.add_theme_constant_override("separation", GAP_S)
	online_hbox.hide()

	btn_mode_host = _make_choice_button("CRÉER SALON", COLOR_GOLD, online_group)
	online_hbox.add_child(btn_mode_host)
	btn_mode_join = _make_choice_button("REJOINDRE", COLOR_GOLD, online_group)
	online_hbox.add_child(btn_mode_join)
	mode_vbox.add_child(online_hbox)

	lobby_status_label = Label.new()
	lobby_status_label.text = "Salon 1V1 | Statut : 1/2 Joueurs (En attente...)"
	lobby_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_status_label.add_theme_font_size_override("font_size", 13)
	lobby_status_label.add_theme_color_override("font_color", COLOR_GOLD)
	lobby_status_label.hide()
	mode_vbox.add_child(lobby_status_label)

	ip_input = LineEdit.new()
	ip_input.placeholder_text = "127.0.0.1"
	ip_input.text = "127.0.0.1"
	ip_input.custom_minimum_size = Vector2(216, 40)
	ip_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_input.hide()

	var ip_center := CenterContainer.new()
	ip_center.add_child(ip_input)
	mode_vbox.add_child(ip_center)

	btn_mode_local.toggled.connect(func(pressed: bool) -> void:
		if not pressed:
			return
		ip_input.hide()
		online_hbox.hide()
		lobby_status_label.hide()
		_update_weapon_panels_visibility()
		btn_replay.text = "LANCER LE MATCH"
	)

	btn_mode_online.toggled.connect(func(pressed: bool) -> void:
		if not pressed:
			return
		online_hbox.show()
		# Aucun sous-mode coché : on propose l'hébergement par défaut.
		if not btn_mode_host.button_pressed and not btn_mode_join.button_pressed:
			btn_mode_host.button_pressed = true
		else:
			_update_weapon_panels_visibility()
	)

	btn_mode_host.toggled.connect(func(pressed: bool) -> void:
		if not pressed or not btn_mode_online.button_pressed:
			return
		ip_input.hide()
		lobby_status_label.show()
		lobby_status_label.text = "Salon 1V1 | Statut : 1/2 Joueurs (En attente...)"
		btn_replay.text = "LANCER LE MATCH"
		_update_weapon_panels_visibility()
	)

	btn_mode_join.toggled.connect(func(pressed: bool) -> void:
		if not pressed or not btn_mode_online.button_pressed:
			return
		ip_input.show()
		lobby_status_label.show()
		lobby_status_label.text = "Salon 1V1 | Entrez l'IP de l'Hôte"
		btn_replay.text = "REJOINDRE LE SALON"
		_update_weapon_panels_visibility()
	)

	return mode_vbox

func _build_weapon_block() -> Control:
	weapon_hbox = HBoxContainer.new()
	weapon_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	weapon_hbox.add_theme_constant_override("separation", GAP_L + GAP_XS)

	p1_weapon_group = ButtonGroup.new()
	p2_weapon_group = ButtonGroup.new()

	p1_vbox = VBoxContainer.new()
	p1_vbox.add_theme_constant_override("separation", GAP_XS)
	p1_vbox.add_child(_make_section_label("ARME — JOUEUR 1", COLOR_P1))

	# Contrat : l'index de l'arme est l'index du bouton dans son conteneur.
	# Ce HBox ne doit donc contenir QUE les quatre boutons d'arme, dans l'ordre.
	var p1_row := HBoxContainer.new()
	p1_row.add_theme_constant_override("separation", GAP_XS)
	p1_btn1 = _create_weapon_btn("🔫 Pistolet", p1_weapon_group, COLOR_P1, 0)
	p1_btn2 = _create_weapon_btn("💥 Fusil", p1_weapon_group, COLOR_P1, 0)
	p1_btn3 = _create_weapon_btn("☄️ Pompe", p1_weapon_group, COLOR_P1, 0)
	p1_btn4 = _create_weapon_btn("🏹 Arbalète", p1_weapon_group, COLOR_P1, 0)
	p1_btn1.button_pressed = true
	p1_btn1.set_meta(META_NAV_SEED, 0)
	p1_row.add_child(p1_btn1)
	p1_row.add_child(p1_btn2)
	p1_row.add_child(p1_btn3)
	p1_row.add_child(p1_btn4)
	p1_vbox.add_child(p1_row)
	weapon_hbox.add_child(p1_vbox)

	p2_vbox = VBoxContainer.new()
	p2_vbox.add_theme_constant_override("separation", GAP_XS)
	p2_vbox.add_child(_make_section_label("ARME — JOUEUR 2", COLOR_P2))

	var p2_row := HBoxContainer.new()
	p2_row.add_theme_constant_override("separation", GAP_XS)
	p2_btn1 = _create_weapon_btn("🔫 Pistolet", p2_weapon_group, COLOR_P2, 1)
	p2_btn2 = _create_weapon_btn("💥 Fusil", p2_weapon_group, COLOR_P2, 1)
	p2_btn3 = _create_weapon_btn("☄️ Pompe", p2_weapon_group, COLOR_P2, 1)
	p2_btn4 = _create_weapon_btn("🏹 Arbalète", p2_weapon_group, COLOR_P2, 1)
	p2_btn1.button_pressed = true
	p2_btn1.set_meta(META_NAV_SEED, 1)
	p2_row.add_child(p2_btn1)
	p2_row.add_child(p2_btn2)
	p2_row.add_child(p2_btn3)
	p2_row.add_child(p2_btn4)
	p2_vbox.add_child(p2_row)
	weapon_hbox.add_child(p2_vbox)

	return weapon_hbox

## `nav_owner` réserve le bouton au joueur concerné : le curseur de J1 ne peut
## pas entrer dans la rangée de J2, et réciproquement.
func _create_weapon_btn(text: String, group: ButtonGroup, tint: Color, owner_id: int) -> Button:
	var btn := _make_choice_button(text, tint, group)
	btn.text = text
	btn.custom_minimum_size = Vector2(136, 80)
	btn.add_theme_font_size_override("font_size", 17)
	btn.set_meta(META_NAV_OWNER, owner_id)
	return btn

func _build_pause_block() -> Control:
	pause_info_container = VBoxContainer.new()
	pause_info_container.add_theme_constant_override("separation", GAP_S)
	pause_info_container.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_info_container.hide()

	pause_score_label = Label.new()
	pause_score_label.text = "SCORE: 0 - 0"
	pause_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_score_label.add_theme_font_size_override("font_size", 40)
	pause_info_container.add_child(pause_score_label)

	pause_time_label = Label.new()
	pause_time_label.text = "TEMPS: 00:00"
	pause_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_time_label.add_theme_font_size_override("font_size", 40)
	pause_info_container.add_child(pause_time_label)

	return pause_info_container

# ---------------------------------------------------------------------------
# ONGLET CARTES
# ---------------------------------------------------------------------------

func _fill_maps_tab() -> void:
	map_gallery = MapGallery.new()
	map_gallery.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_gallery.map_chosen.connect(_on_map_chosen)
	tab_map_container.add_child(map_gallery)

func _on_map_chosen(_map_id: String) -> void:
	_refresh_map_card()

# ---------------------------------------------------------------------------
# ONGLET CONTRÔLES
# ---------------------------------------------------------------------------

func _fill_controls_tab() -> void:
	tab_controls_container.add_child(_make_section_label("MAPPING MANETTE", COLOR_GOLD))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", GAP_L)
	grid.add_theme_constant_override("v_separation", GAP_XS)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tab_controls_container.add_child(grid)

	grid.add_child(_make_grid_header("ACTION", COLOR_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	grid.add_child(_make_grid_header("JOUEUR 1", COLOR_P1, HORIZONTAL_ALIGNMENT_CENTER))
	grid.add_child(_make_grid_header("JOUEUR 2", COLOR_P2, HORIZONTAL_ALIGNMENT_CENTER))

	var bindable_actions := {
		"Tirer": ["p1_shoot", "p2_shoot"],
		"Torche": ["p1_torch", "p2_torch"],
		"Courir": ["p1_sprint", "p2_sprint"],
	}

	_controls_grid_buttons = []
	for action_name in bindable_actions.keys():
		var label := Label.new()
		label.text = String(action_name)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		grid.add_child(label)

		var actions: Array = bindable_actions[action_name]
		var row := {}
		for player in 2:
			var btn := _make_rebind_button(String(actions[player]), player)
			if _controls_grid_buttons.is_empty():
				btn.set_meta(META_NAV_SEED, player)
			var holder := CenterContainer.new()
			holder.add_child(btn)
			grid.add_child(holder)
			row["p1" if player == 0 else "p2"] = btn
		_controls_grid_buttons.append(row)

	tab_controls_container.add_child(_build_display_block())

func _make_grid_header(text: String, tint: Color, align: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", tint)
	return label

func _make_rebind_button(action: String, player: int) -> Button:
	var btn := _make_button("", COLOR_P1 if player == 0 else COLOR_P2)
	btn.custom_minimum_size = Vector2(72, 64)
	btn.set_meta(META_NAV_OWNER, player)
	_apply_btn_info(btn, _get_action_btn_info(action))
	btn.pressed.connect(_on_rebind_btn_pressed.bind(btn, action))
	return btn

## Réglages d'affichage : trois bascules plutôt qu'un OptionButton, dont le
## popup est impraticable à la manette.
func _build_display_block() -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", GAP_XS)
	block.add_child(_make_section_label("AFFICHAGE", COLOR_GOLD))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", GAP_S)

	var group := ButtonGroup.new()
	var labels: Array[String] = ["FENÊTRÉ 1280", "FENÊTRÉ 1920", "PLEIN ÉCRAN"]
	for i in labels.size():
		var btn := _make_choice_button(labels[i], COLOR_GOLD, group)
		btn.custom_minimum_size = Vector2(184, 44)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_res_selected.bind(i))
		row.add_child(btn)

	block.add_child(row)
	return block

# ---------------------------------------------------------------------------
# BARRE D'ACTIONS
# ---------------------------------------------------------------------------

func _build_actions_bar() -> Control:
	btn_actions = HBoxContainer.new()
	btn_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_actions.add_theme_constant_override("separation", GAP_S)

	btn_resume = _make_button("REPRENDRE", COLOR_P1)
	btn_resume.custom_minimum_size = Vector2(208, 56)
	btn_resume.pressed.connect(_resume_game)
	btn_actions.add_child(btn_resume)

	btn_replay = _make_button("REJOUER", COLOR_P1, true)
	btn_replay.custom_minimum_size = Vector2(264, 56)
	btn_replay.add_theme_font_size_override("font_size", 22)
	btn_replay.pressed.connect(func() -> void:
		get_tree().paused = false
		replay_requested.emit()
	)
	btn_actions.add_child(btn_replay)

	btn_main_menu = _make_button("MENU PRINCIPAL", COLOR_DIM)
	btn_main_menu.custom_minimum_size = Vector2(240, 56)
	btn_main_menu.pressed.connect(func() -> void:
		get_tree().paused = false
		main_menu_requested.emit()
	)
	btn_actions.add_child(btn_main_menu)

	btn_quit = _make_button("QUITTER", COLOR_P2)
	btn_quit.custom_minimum_size = Vector2(184, 56)
	btn_quit.pressed.connect(func() -> void:
		get_tree().paused = false
		quit_requested.emit()
	)
	btn_actions.add_child(btn_quit)

	return btn_actions

# ===========================================================================
# ONGLETS
# ===========================================================================

func _tab_pages() -> Dictionary:
	return {
		TAB_PLAY: tab_game_container,
		TAB_MAPS: tab_map_container,
		TAB_CONTROLS: tab_controls_container,
	}

func _tab_buttons() -> Dictionary:
	return {
		TAB_PLAY: btn_tab_game,
		TAB_MAPS: btn_tab_map,
		TAB_CONTROLS: btn_tab_controls,
	}

## Onglets réellement accessibles : CARTES disparaît pendant une pause en match.
func _visible_tabs() -> Array[String]:
	var out: Array[String] = []
	var buttons := _tab_buttons()
	for tab_name in [TAB_PLAY, TAB_MAPS, TAB_CONTROLS]:
		var btn: Button = buttons[tab_name]
		if btn != null and btn.visible:
			out.append(String(tab_name))
	return out

func _switch_tab(tab_name: String, animate: bool = true) -> void:
	var available := _visible_tabs()
	if not available.has(tab_name):
		tab_name = TAB_PLAY

	var pages := _tab_pages()
	var target: VBoxContainer = pages[tab_name]
	if target == null:
		return

	var previous_index := available.find(_current_tab)
	var next_index := available.find(tab_name)
	var same_page := _active_tab == target and target.visible

	_current_tab = tab_name
	_active_tab = target

	var buttons := _tab_buttons()
	for key in buttons.keys():
		var btn: Button = buttons[key]
		if btn != null:
			btn.set_pressed_no_signal(key == tab_name)

	for key in pages.keys():
		var page: VBoxContainer = pages[key]
		if page != null and page != target:
			page.hide()
	target.show()

	if animate and not same_page:
		var direction := 1.0
		if previous_index >= 0 and next_index >= 0 and next_index < previous_index:
			direction = -1.0
		_play_tab_transition(target, direction)
	else:
		_reset_page_transform(target)

	_seed_focus(0)
	_seed_focus(1)

## Fondu + léger glissement latéral, dans le sens du déplacement entre onglets.
func _play_tab_transition(page: Control, direction: float) -> void:
	if _tab_tween != null and _tab_tween.is_valid():
		_tab_tween.kill()

	var offset := TAB_SLIDE * direction
	page.modulate.a = 0.0
	page.offset_left = offset
	page.offset_right = offset

	_tab_tween = create_tween()
	_tab_tween.set_parallel(true)
	_tab_tween.tween_property(page, "modulate:a", 1.0, TAB_FADE)
	_tab_tween.tween_property(page, "offset_left", 0.0, TAB_FADE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tab_tween.tween_property(page, "offset_right", 0.0, TAB_FADE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _reset_page_transform(page: Control) -> void:
	page.modulate.a = 1.0
	page.offset_left = 0.0
	page.offset_right = 0.0

func _cycle_tab(step: int) -> void:
	var available := _visible_tabs()
	if available.is_empty():
		return
	var index := available.find(_current_tab)
	if index < 0:
		index = 0
	var next := wrapi(index + step, 0, available.size())
	_switch_tab(available[next])

func _resume_game() -> void:
	get_tree().paused = false
	game_over_panel.hide()

func _update_weapon_panels_visibility() -> void:
	if btn_mode_local.button_pressed:
		p1_vbox.show()
		p2_vbox.show()
	else:
		if not _is_main_menu and NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
			p1_vbox.hide()
			p2_vbox.show()
		else:
			p1_vbox.show()
			p2_vbox.hide()

# ===========================================================================
# REMAPPAGE DES TOUCHES
# ===========================================================================

func _get_joypad_btn_info(btn_index: int) -> Dictionary:
	match btn_index:
		JOY_BUTTON_A: return {"text": "Croix (X)", "icon": "cross.svg"}
		JOY_BUTTON_B: return {"text": "Rond (O)", "icon": "circle.svg"}
		JOY_BUTTON_X: return {"text": "Carré", "icon": "square.svg"}
		JOY_BUTTON_Y: return {"text": "Triangle", "icon": "triangle.svg"}
		JOY_BUTTON_BACK: return {"text": "Share", "icon": "share.svg"}
		JOY_BUTTON_GUIDE: return {"text": "PS", "icon": "ps.svg"}
		JOY_BUTTON_START: return {"text": "Options", "icon": "options.svg"}
		JOY_BUTTON_LEFT_STICK: return {"text": "L3", "icon": "l3.svg"}
		JOY_BUTTON_RIGHT_STICK: return {"text": "R3", "icon": "r3.svg"}
		JOY_BUTTON_LEFT_SHOULDER: return {"text": "L1", "icon": "l1.svg"}
		JOY_BUTTON_RIGHT_SHOULDER: return {"text": "R1", "icon": "r1.svg"}
		JOY_BUTTON_DPAD_UP: return {"text": "Flèche Haut", "icon": "dpad_up.svg"}
		JOY_BUTTON_DPAD_DOWN: return {"text": "Flèche Bas", "icon": "dpad_down.svg"}
		JOY_BUTTON_DPAD_LEFT: return {"text": "Flèche Gauche", "icon": "dpad_left.svg"}
		JOY_BUTTON_DPAD_RIGHT: return {"text": "Flèche Droite", "icon": "dpad_right.svg"}
		JOY_BUTTON_MISC1: return {"text": "Touchpad", "icon": ""}
		_: return {"text": "Bouton " + str(btn_index), "icon": ""}

func _apply_btn_info(btn: Button, info: Dictionary) -> void:
	if String(info.get("icon", "")) != "":
		var path_svg := "res://assets/ui/prompts/" + String(info["icon"])
		if ResourceLoader.exists(path_svg):
			btn.icon = load(path_svg)
			btn.text = ""
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true
			return
	btn.icon = null
	btn.text = String(info.get("text", ""))

func _get_action_btn_info(action: String) -> Dictionary:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			return _get_joypad_btn_info(ev.button_index)
		elif ev is InputEventJoypadMotion:
			if ev.axis == JOY_AXIS_TRIGGER_LEFT:
				return {"text": "Gâchette L2", "icon": "l2.svg"}
			elif ev.axis == JOY_AXIS_TRIGGER_RIGHT:
				return {"text": "Gâchette R2", "icon": "r2.svg"}
			else:
				return {"text": "Axe " + str(ev.axis), "icon": ""}
	return {"text": "Non assigné", "icon": ""}

func _on_rebind_btn_pressed(btn: Button, action: String) -> void:
	if _is_rebinding:
		return
	_is_rebinding = true
	_action_to_rebind = action
	_button_to_update = btn
	btn.text = "Appuyez..."
	btn.icon = null
	btn.add_theme_color_override("font_color", COLOR_GOLD)

# ===========================================================================
# ENTRÉES
# ===========================================================================

func _input(event: InputEvent) -> void:
	# En ligne, la seconde manette locale ne pilote rien.
	if NetworkManager.current_mode != NetworkManager.GameMode.LOCAL_SPLITSCREEN:
		if event.is_action("p2_menu_right") or event.is_action("p2_menu_left") \
				or event.is_action("p2_menu_up") or event.is_action("p2_menu_down") \
				or event.is_action("p2_menu_select") or event.is_action("p2_menu_prev_tab") \
				or event.is_action("p2_menu_next_tab"):
			return

	if _is_rebinding:
		_handle_rebind_input(event)
		return

	if event.is_action_pressed("sys_pause"):
		if _handle_pause_input():
			return

	if not game_over_panel.visible:
		return

	if event.is_action_pressed("p1_menu_prev_tab") or event.is_action_pressed("p2_menu_prev_tab"):
		_cycle_tab(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("p1_menu_next_tab") or event.is_action_pressed("p2_menu_next_tab"):
		_cycle_tab(1)
		get_viewport().set_input_as_handled()
		return

	for player in 2:
		var prefix := "p1_menu_" if player == 0 else "p2_menu_"
		if event.is_action_pressed(prefix + "right"):
			_navigate(player, Vector2.RIGHT)
		elif event.is_action_pressed(prefix + "left"):
			_navigate(player, Vector2.LEFT)
		elif event.is_action_pressed(prefix + "up"):
			_navigate(player, Vector2.UP)
		elif event.is_action_pressed(prefix + "down"):
			_navigate(player, Vector2.DOWN)
		elif event.is_action_pressed(prefix + "select"):
			_activate(player)

func _handle_rebind_input(event: InputEvent) -> void:
	var new_event: InputEvent = null
	var display_info := {}

	if event is InputEventJoypadButton and event.is_pressed():
		var joy_btn := InputEventJoypadButton.new()
		joy_btn.button_index = (event as InputEventJoypadButton).button_index
		new_event = joy_btn
		display_info = _get_joypad_btn_info(joy_btn.button_index)
	elif event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis_value > 0.5:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_TRIGGER_LEFT or motion.axis == JOY_AXIS_TRIGGER_RIGHT:
			var joy_axis := InputEventJoypadMotion.new()
			joy_axis.axis = motion.axis
			joy_axis.axis_value = 1.0
			new_event = joy_axis
			display_info = {"text": "Gâchette L2", "icon": "l2.svg"} \
				if motion.axis == JOY_AXIS_TRIGGER_LEFT \
				else {"text": "Gâchette R2", "icon": "r2.svg"}

	if new_event == null:
		return

	var old_events := InputMap.action_get_events(_action_to_rebind)
	for ev in old_events:
		var is_trigger := ev is InputEventJoypadMotion \
			and ((ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_LEFT
				or (ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT)
		if ev is InputEventJoypadButton or is_trigger:
			InputMap.action_erase_event(_action_to_rebind, ev)

	new_event.device = old_events[0].device if old_events.size() > 0 else 0
	InputMap.action_add_event(_action_to_rebind, new_event)

	_apply_btn_info(_button_to_update, display_info)
	_button_to_update.remove_theme_color_override("font_color")
	_is_rebinding = false
	get_viewport().set_input_as_handled()

## Retourne true si l'événement de pause a été consommé.
func _handle_pause_input() -> bool:
	if not _is_main_menu and not game_over_panel.visible:
		get_tree().paused = true
		btn_resume.show()
		btn_replay.hide()
		btn_main_menu.show()
		game_over_title.text = "PAUSE"
		game_over_title.add_theme_color_override("font_color", Color.WHITE)
		game_over_score.text = ""

		weapon_hbox.hide()
		map_card.hide()
		mode_vbox.hide()
		pause_info_container.show()
		if is_instance_valid(btn_tab_map):
			btn_tab_map.hide()

		var gs := get_parent()
		if gs and gs is GameState:
			pause_score_label.text = "SCORE : %d - %d" % [gs.p1_kills, gs.p2_kills]
			var m := floori(gs.time_left) / 60
			var s := floori(gs.time_left) % 60
			pause_time_label.text = "TEMPS RESTANT : %02d:%02d" % [m, s]

		game_over_panel.show()
		_switch_tab(TAB_PLAY, false)
		get_viewport().set_input_as_handled()
		return true

	if game_over_panel.visible and btn_resume.visible:
		_resume_game()
		get_viewport().set_input_as_handled()
		return true

	return false

# ===========================================================================
# API PUBLIQUE — consommée par game_state.gd
# ===========================================================================

func update_hud(p1, p2, time_left: float) -> void:
	if p1:
		if p1.hp < p1_target_hp:
			p1_shake_time = 0.2
		p1_target_hp = p1.hp
		p1_hp.value = p1.hp

		var p1_max_cd = p1.current_weapon.cooldown if p1.current_weapon else 1.0
		p1_cd.set_progress(1.0 - (p1.shoot_cooldown / p1_max_cd))
		if p1.shoot_cooldown <= 0:
			p1_cd_label.text = "PRÊT"
		else:
			p1_cd_label.text = "%.1fs" % p1.shoot_cooldown

		_set_torch_style(p1_torch, p1.flashlight_on, COLOR_P1)
		p1_dazzle.color = Color(1, 1, 1, p1.dazzle_amount * 0.8)

	if p2:
		if p2.hp < p2_target_hp:
			p2_shake_time = 0.2
		p2_target_hp = p2.hp
		p2_hp.value = p2.hp

		var p2_max_cd = p2.current_weapon.cooldown if p2.current_weapon else 1.0
		p2_cd.set_progress(1.0 - (p2.shoot_cooldown / p2_max_cd))
		if p2.shoot_cooldown <= 0:
			p2_cd_label.text = "PRÊT"
		else:
			p2_cd_label.text = "%.1fs" % p2.shoot_cooldown

		_set_torch_style(p2_torch, p2.flashlight_on, COLOR_P2)
		p2_dazzle.color = Color(1, 1, 1, p2.dazzle_amount * 0.8)

	var m := floori(time_left) / 60
	var s := floori(time_left) % 60
	time_label.text = "%02d:%02d" % [m, s]

func show_main_menu() -> void:
	_is_main_menu = true
	if is_instance_valid(match_hud):
		match_hud.hide()
	btn_resume.hide()
	btn_replay.show()
	btn_main_menu.hide()
	btn_quit.show()

	weapon_hbox.show()
	map_card.show()
	if mode_vbox:
		mode_vbox.show()
	if pause_info_container:
		pause_info_container.hide()
	if is_instance_valid(btn_tab_map):
		btn_tab_map.show()

	_switch_tab(TAB_PLAY, false)
	game_over_panel.show()
	game_over_title.text = "CANDELA 2D"
	game_over_title.add_theme_color_override("font_color", COLOR_GOLD)
	game_over_score.text = "PRÊT À JOUER ?"

	if btn_mode_local.button_pressed:
		btn_replay.text = "JOUER"
	elif btn_mode_host.button_pressed:
		btn_replay.text = "LANCER LE MATCH"
	elif btn_mode_join.button_pressed:
		btn_replay.text = "REJOINDRE LE SALON"
	btn_replay.remove_theme_color_override("font_color")

	_refresh_map_card()

func show_game_over(winner_id: int) -> void:
	_is_main_menu = false
	if is_instance_valid(match_hud):
		match_hud.hide()
	btn_resume.hide()
	btn_replay.show()
	btn_main_menu.show()
	weapon_hbox.show()
	map_card.show()

	_update_weapon_panels_visibility()
	if mode_vbox:
		mode_vbox.hide()
	if pause_info_container:
		pause_info_container.hide()
	if is_instance_valid(btn_tab_map):
		btn_tab_map.show()

	_switch_tab(TAB_PLAY, false)
	game_over_panel.show()
	game_over_score.text = ""
	btn_replay.text = "REJOUER"

	if winner_id == 0:
		game_over_title.text = "JOUEUR 1 GAGNE LE MATCH"
		game_over_title.add_theme_color_override("font_color", COLOR_P1)
	elif winner_id == 1:
		game_over_title.text = "JOUEUR 2 GAGNE LE MATCH"
		game_over_title.add_theme_color_override("font_color", COLOR_P2)
	else:
		game_over_title.text = "ÉGALITÉ"
		game_over_title.add_theme_color_override("font_color", Color.WHITE)

	_refresh_map_card()

func hide_game_over() -> void:
	_is_main_menu = false
	game_over_panel.hide()
	# Retour au jeu : le HUD de match reprend sa place.
	if is_instance_valid(match_hud):
		match_hud.show()

func show_killcam() -> void:
	killcam_overlay.show()
	killcam_container.show()
	killcam_timecode.show()
	var bb := get_node_or_null("../SplitScreen/ViewportContainer1/SubViewport1/Arena/KillcamBB")
	if bb:
		bb.show()

func hide_killcam() -> void:
	killcam_overlay.hide()
	killcam_container.hide()
	killcam_timecode.hide()
	var bb := get_node_or_null("../SplitScreen/ViewportContainer1/SubViewport1/Arena/KillcamBB")
	if bb:
		bb.hide()

func set_split_screen_visible(is_visible: bool) -> void:
	center_line.visible = is_visible

## [UI] Affiche une boîte de dialogue modale au centre de l'écran.
func show_dialog_message(title: String, message: String) -> void:
	dialog_title.text = title
	dialog_message.text = message
	dialog_panel.show()
	_previous_focus = p1_focus
	_set_focus(0, dialog_btn, true)
	_set_focus(1, dialog_btn, true)

## [UI] Ferme la boîte de dialogue et restaure le focus.
func _on_dialog_closed() -> void:
	dialog_panel.hide()
	if _is_focus_usable(_previous_focus):
		_set_focus(0, _previous_focus, true)
		_set_focus(1, _previous_focus, true)
	else:
		_seed_focus(0)
		_seed_focus(1)
	_previous_focus = null

## [UI] Force la fermeture du menu pause s'il est ouvert, pour ne pas gêner la Killcam.
func force_close_pause() -> void:
	if pause_info_container.visible:
		pause_info_container.hide()
		weapon_hbox.hide()
		if NetworkManager.current_mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN:
			get_tree().paused = false

func _on_res_selected(index: int) -> void:
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1280, 720))
			_center_window()
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			_center_window()
		2:
			# N'active le plein écran que sur le jeu final exporté.
			if not OS.is_debug_build():
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _center_window() -> void:
	var screen_size := DisplayServer.screen_get_size()
	var win_size := DisplayServer.window_get_size()
	DisplayServer.window_set_position((screen_size - win_size) / 2)
