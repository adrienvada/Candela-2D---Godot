extends CanvasLayer
class_name UI

signal replay_requested
signal quit_requested

class CircularCooldown extends Control:
	var progress: float = 1.0
	var color: Color = Color.WHITE
	func _draw():
		var center = size / 2.0
		var radius = min(size.x, size.y) / 2.0 - 4.0
		# Background ring
		draw_arc(center, radius, 0, TAU, 32, Color(0.2, 0.2, 0.2), 4.0, true)
		# Foreground ring
		if progress > 0.0:
			draw_arc(center, radius, -PI/2, -PI/2 + progress * TAU, 32, color, 4.0, true)
	
	func set_progress(p: float):
		if p != progress:
			progress = p
			queue_redraw()

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
var center_line: Panel


var game_over_panel: PanelContainer
var game_over_title: Label
var game_over_score: Label
var btn_replay: Button
var p1_weapon_group: ButtonGroup
var p2_weapon_group: ButtonGroup

var btn_quit: Button
var p1_btn1: Button
var p1_btn2: Button
var p1_btn3: Button
var p2_btn1: Button
var p2_btn2: Button
var p2_btn3: Button

var p1_focus: Control
var p2_focus: Control
var p1_cursor: Panel
var p2_cursor: Panel

var btn_debug_light: CheckButton

var p1_nav: Dictionary = {}
var p2_nav: Dictionary = {}

var killcam_label: Label

var p1_shake_time: float = 0.0
var p2_shake_time: float = 0.0
var shake_intensity: float = 10.0

var p1_target_hp: float = 100.0
var p2_target_hp: float = 100.0
var p1_bg_hp: float = 100.0
var p2_bg_hp: float = 100.0

func _ready():
	_build_ui()

func _process(delta):
	if game_over_panel:
		p1_cursor.visible = game_over_panel.visible
		p2_cursor.visible = game_over_panel.visible
		
		if game_over_panel.visible:
			if p1_focus:
				p1_cursor.global_position = p1_focus.global_position
				p1_cursor.size = p1_focus.size
			if p2_focus:
				p2_cursor.global_position = p2_focus.global_position
				p2_cursor.size = p2_focus.size

	# Handle HP Background trailing
	if p1_bg_hp > p1_target_hp:
		p1_bg_hp = max(p1_target_hp, p1_bg_hp - 30.0 * delta)
		p1_hp_bg.value = p1_bg_hp
	elif p1_bg_hp < p1_target_hp:
		p1_bg_hp = p1_target_hp
		p1_hp_bg.value = p1_bg_hp
	
	if p2_bg_hp > p2_target_hp:
		p2_bg_hp = max(p2_target_hp, p2_bg_hp - 30.0 * delta)
		p2_hp_bg.value = p2_bg_hp
	elif p2_bg_hp < p2_target_hp:
		p2_bg_hp = p2_target_hp
		p2_hp_bg.value = p2_bg_hp
		
	# Handle Shake
	if p1_shake_time > 0:
		p1_shake_time -= delta
		p1_panel.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
	else:
		p1_panel.position = Vector2.ZERO
		
	if p2_shake_time > 0:
		p2_shake_time -= delta
		p2_panel.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
	else:
		p2_panel.position = Vector2.ZERO

func _create_glow_panel(color: Color) -> PanelContainer:
	var p = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = color
	style.shadow_size = 15
	p.add_theme_stylebox_override("panel", style)
	return p

func _create_health_bars(color: Color) -> Dictionary:
	var container = MarginContainer.new()
	container.custom_minimum_size = Vector2(0, 12)
	
	var bg_bar = ProgressBar.new()
	bg_bar.max_value = 100
	bg_bar.value = 100
	bg_bar.show_percentage = false
	bg_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	bg_bar.add_theme_stylebox_override("background", bg_style)
	
	var bg_fill = StyleBoxFlat.new()
	bg_fill.bg_color = Color(0.8, 0.0, 0.2) # Red trail
	bg_fill.corner_radius_top_left = 6
	bg_fill.corner_radius_top_right = 6
	bg_fill.corner_radius_bottom_left = 6
	bg_fill.corner_radius_bottom_right = 6
	bg_bar.add_theme_stylebox_override("fill", bg_fill)
	
	var fg_bar = ProgressBar.new()
	fg_bar.max_value = 100
	fg_bar.value = 100
	fg_bar.show_percentage = false
	fg_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var fg_empty = StyleBoxEmpty.new()
	fg_bar.add_theme_stylebox_override("background", fg_empty)
	
	var fg_fill = StyleBoxFlat.new()
	fg_fill.bg_color = color
	fg_fill.corner_radius_top_left = 6
	fg_fill.corner_radius_top_right = 6
	fg_fill.corner_radius_bottom_left = 6
	fg_fill.corner_radius_bottom_right = 6
	fg_fill.shadow_color = color
	fg_fill.shadow_size = 8
	fg_bar.add_theme_stylebox_override("fill", fg_fill)
	
	container.add_child(bg_bar)
	container.add_child(fg_bar)
	
	return {"container": container, "fg": fg_bar, "bg": bg_bar}

func _create_weapon_indicator(color: Color) -> Dictionary:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 15)
	
	var circle_container = MarginContainer.new()
	circle_container.custom_minimum_size = Vector2(40, 40)
	
	var circle = CircularCooldown.new()
	circle.color = color
	circle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	circle_container.add_child(circle)
	
	var label = Label.new()
	label.text = "PRÊT"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	circle_container.add_child(label)
	
	var title = Label.new()
	title.text = "ARME"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	
	container.add_child(circle_container)
	container.add_child(title)
	
	return {"container": container, "circle": circle, "label": label}

func _create_torch_indicator() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)
	
	var icon = Label.new()
	icon.text = "🔦"
	icon.add_theme_font_size_override("font_size", 12)
	hbox.add_child(icon)
	
	var label = Label.new()
	label.text = "TORCHE"
	label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(label)
	
	_set_torch_style(panel, false, Color.WHITE)
	return panel

func _set_torch_style(panel: PanelContainer, active: bool, player_color: Color):
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	
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
	
	var hbox = panel.get_child(0).get_child(0)
	var label = hbox.get_child(1)
	if active:
		label.add_theme_color_override("font_color", Color.WHITE)
	else:
		label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))


func _create_cursor(color: Color) -> Panel:
	var p = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0,0,0,0)
	style.border_color = color
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.draw_center = false
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_as_top_level(true)
	return p

func _build_nav():
	p1_nav = {
		p1_btn1: {"right": p1_btn2, "down": btn_replay},
		p1_btn2: {"left": p1_btn1, "right": p1_btn3, "down": btn_quit},
		p1_btn3: {"left": p1_btn2, "down": btn_quit},
		btn_replay: {"up": p1_btn1, "right": btn_quit, "down": btn_debug_light},
		btn_quit: {"up": p1_btn2, "left": btn_replay, "down": btn_debug_light},
		btn_debug_light: {"up": btn_replay}
	}
	p2_nav = {
		p2_btn1: {"right": p2_btn2, "down": btn_replay},
		p2_btn2: {"left": p2_btn1, "right": p2_btn3, "down": btn_quit},
		p2_btn3: {"left": p2_btn2, "down": btn_quit},
		btn_replay: {"up": p2_btn1, "right": btn_quit, "down": btn_debug_light},
		btn_quit: {"up": p2_btn2, "left": btn_replay, "down": btn_debug_light},
		btn_debug_light: {"up": btn_quit}
	}

func _create_weapon_btn(text: String, group: ButtonGroup, player_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_group = group
	btn.custom_minimum_size = Vector2(140, 80)
	btn.add_theme_font_size_override("font_size", 20)
	
	# Initial style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.2, 0.2, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)
	
	var pressed_style = style.duplicate()
	pressed_style.border_color = player_color
	pressed_style.shadow_color = player_color
	pressed_style.shadow_size = 5
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus", pressed_style)
	
	btn.toggled.connect(_on_weapon_toggled.bind(btn, text, player_color))
	return btn

func _on_weapon_toggled(toggled_on: bool, btn: Button, default_text: String, player_color: Color):
	if toggled_on:
		btn.text = default_text + "\n[ ✓ ]"
		btn.add_theme_color_override("font_color", player_color)
	else:
		btn.text = default_text
		btn.remove_theme_color_override("font_color")

func _build_ui():
	# Scanline Overlay
	var scanline = ColorRect.new()
	scanline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanline.color = Color(0, 0, 0, 0.1)
	scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scanline)
	
	# Center Glowing Line
	center_line = Panel.new()
	center_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center_line.size = Vector2(4, 2000)
	center_line.position = Vector2(-2, 0)
	var line_style = StyleBoxFlat.new()
	line_style.bg_color = Color(0, 0.94, 1.0, 0.8)
	line_style.shadow_color = Color(0, 0.94, 1.0, 0.5)
	line_style.shadow_size = 20
	center_line.add_theme_stylebox_override("panel", line_style)
	add_child(center_line)
	
	# Margin Container
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	# P1 HUD Container (wrapper for shake)
	var p1_wrapper = Control.new()
	p1_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p1_wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p1_wrapper.custom_minimum_size = Vector2(350, 150)
	hbox.add_child(p1_wrapper)
	
	p1_panel = _create_glow_panel(Color(0, 0.94, 1.0))
	p1_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p1_wrapper.add_child(p1_panel)
	
	var p1_margin = MarginContainer.new()
	p1_margin.add_theme_constant_override("margin_top", 15)
	p1_margin.add_theme_constant_override("margin_left", 20)
	p1_margin.add_theme_constant_override("margin_right", 20)
	p1_margin.add_theme_constant_override("margin_bottom", 15)
	p1_panel.add_child(p1_margin)
	
	var p1_hud = VBoxContainer.new()
	p1_hud.add_theme_constant_override("separation", 10)
	p1_margin.add_child(p1_hud)
	
	var p1_header = HBoxContainer.new()
	p1_hud.add_child(p1_header)
	
	var p1_name = Label.new()
	p1_name.text = "JOUEUR 1"
	p1_name.add_theme_font_size_override("font_size", 24)
	p1_name.add_theme_color_override("font_color", Color(0, 0.94, 1.0))
	p1_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p1_header.add_child(p1_name)
	
	var p1_hp_label = Label.new()
	p1_hp_label.text = "SANTÉ"
	p1_hp_label.add_theme_font_size_override("font_size", 12)
	p1_hp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	p1_hud.add_child(p1_hp_label)
	
	var p1_bars = _create_health_bars(Color(0, 0.94, 1.0))
	p1_hud.add_child(p1_bars["container"])
	p1_hp = p1_bars["fg"]
	p1_hp_bg = p1_bars["bg"]
	
	var p1_bottom = HBoxContainer.new()
	p1_bottom.add_theme_constant_override("separation", 20)
	p1_hud.add_child(p1_bottom)
	
	var p1_wp = _create_weapon_indicator(Color(0, 0.94, 1.0))
	p1_bottom.add_child(p1_wp["container"])
	p1_cd = p1_wp["circle"]
	p1_cd_label = p1_wp["label"]
	
	var p1_spacer = Control.new()
	p1_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p1_bottom.add_child(p1_spacer)
	
	p1_torch = _create_torch_indicator()
	p1_bottom.add_child(p1_torch)
	
	# Center HUD
	var center_hud = VBoxContainer.new()
	center_hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_hud.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_child(center_hud)
	
	var center_panel = _create_glow_panel(Color(0.3, 0.3, 0.3))
	center_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_panel.custom_minimum_size = Vector2(200, 0)
	center_hud.add_child(center_panel)
	
	var center_margin = MarginContainer.new()
	center_margin.add_theme_constant_override("margin_top", 10)
	center_margin.add_theme_constant_override("margin_left", 15)
	center_margin.add_theme_constant_override("margin_right", 15)
	center_margin.add_theme_constant_override("margin_bottom", 10)
	center_panel.add_child(center_margin)
	
	var center_vbox = VBoxContainer.new()
	center_margin.add_child(center_vbox)
	
	var title = Label.new()
	title.text = "CANDELA 2D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0))
	center_vbox.add_child(title)
	
	time_label = Label.new()
	time_label.text = "02:00"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 36)
	center_vbox.add_child(time_label)
	
	# P2 HUD Container (wrapper for shake)
	var p2_wrapper = Control.new()
	p2_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_END
	p2_wrapper.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p2_wrapper.custom_minimum_size = Vector2(350, 150)
	hbox.add_child(p2_wrapper)
	
	p2_panel = _create_glow_panel(Color(1.0, 0, 0.33))
	p2_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p2_wrapper.add_child(p2_panel)
	
	var p2_margin = MarginContainer.new()
	p2_margin.add_theme_constant_override("margin_top", 15)
	p2_margin.add_theme_constant_override("margin_left", 20)
	p2_margin.add_theme_constant_override("margin_right", 20)
	p2_margin.add_theme_constant_override("margin_bottom", 15)
	p2_panel.add_child(p2_margin)
	
	var p2_hud = VBoxContainer.new()
	p2_hud.add_theme_constant_override("separation", 10)
	p2_margin.add_child(p2_hud)
	
	var p2_header = HBoxContainer.new()
	p2_hud.add_child(p2_header)
	
	var p2_name = Label.new()
	p2_name.text = "JOUEUR 2"
	p2_name.add_theme_font_size_override("font_size", 24)
	p2_name.add_theme_color_override("font_color", Color(1.0, 0, 0.33))
	p2_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p2_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p2_header.add_child(p2_name)
	
	var p2_hp_label = Label.new()
	p2_hp_label.text = "SANTÉ"
	p2_hp_label.add_theme_font_size_override("font_size", 12)
	p2_hp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	p2_hud.add_child(p2_hp_label)
	
	var p2_bars = _create_health_bars(Color(1.0, 0, 0.33))
	p2_hud.add_child(p2_bars["container"])
	p2_hp = p2_bars["fg"]
	p2_hp_bg = p2_bars["bg"]
	
	var p2_bottom = HBoxContainer.new()
	p2_bottom.add_theme_constant_override("separation", 20)
	p2_hud.add_child(p2_bottom)
	
	p2_torch = _create_torch_indicator()
	p2_bottom.add_child(p2_torch)
	
	var p2_spacer = Control.new()
	p2_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p2_bottom.add_child(p2_spacer)
	
	var p2_wp = _create_weapon_indicator(Color(1.0, 0, 0.33))
	p2_bottom.add_child(p2_wp["container"])
	p2_cd = p2_wp["circle"]
	p2_cd_label = p2_wp["label"]
	
	# Dazzle Overlays
	var dazzle_hbox = HBoxContainer.new()
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
	
	# Resolution Menu
	var res_btn = OptionButton.new()
	res_btn.add_item("Fenêtré 1280x720", 0)
	res_btn.add_item("Fenêtré 1920x1080", 1)
	res_btn.add_item("Plein Écran", 2)
	res_btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	res_btn.offset_left = -160
	res_btn.offset_top = 10
	res_btn.offset_right = -10
	res_btn.offset_bottom = 40
	res_btn.item_selected.connect(_on_res_selected)
	add_child(res_btn)
	
	# Killcam Overlay
	killcam_label = Label.new()
	killcam_label.text = "KILLCAM"
	killcam_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	killcam_label.add_theme_font_size_override("font_size", 48)
	killcam_label.add_theme_color_override("font_color", Color(1, 0, 0))
	killcam_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	killcam_label.offset_top = 100
	killcam_label.hide()
	add_child(killcam_label)
	
	# Game Over Panel
	game_over_panel = PanelContainer.new()
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_panel.hide()
	add_child(game_over_panel)
	
	var go_bg = ColorRect.new()
	go_bg.color = Color(0, 0, 0, 0.8)
	game_over_panel.add_child(go_bg)
	
	var go_center = CenterContainer.new()
	game_over_panel.add_child(go_center)
	
	var go_vbox = VBoxContainer.new()
	go_vbox.add_theme_constant_override("separation", 20)
	go_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	go_center.add_child(go_vbox)
	
	game_over_title = Label.new()
	game_over_title.text = "MATCH TERMINÉ"
	game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_title.add_theme_font_size_override("font_size", 64)
	go_vbox.add_child(game_over_title)
	
	game_over_score = Label.new()
	game_over_score.text = "SCORE: 0 - 0"
	game_over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_score.add_theme_font_size_override("font_size", 32)
	go_vbox.add_child(game_over_score)
	
	var weapon_hbox = HBoxContainer.new()
	weapon_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	weapon_hbox.add_theme_constant_override("separation", 50)
	
	var p1_vbox = VBoxContainer.new()
	var l1 = Label.new()
	l1.text = "Arme Joueur 1"
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l1.add_theme_color_override("font_color", Color(0, 0.94, 1.0))
	
	p1_weapon_group = ButtonGroup.new()
	p1_btn1 = _create_weapon_btn("🔫 Pistolet", p1_weapon_group, Color(0, 0.94, 1.0))
	p1_btn2 = _create_weapon_btn("💥 Fusil", p1_weapon_group, Color(0, 0.94, 1.0))
	p1_btn3 = _create_weapon_btn("☄️ Pompe", p1_weapon_group, Color(0, 0.94, 1.0))
	p1_btn1.button_pressed = true
	
	var p1_hbox = HBoxContainer.new()
	p1_hbox.add_child(p1_btn1)
	p1_hbox.add_child(p1_btn2)
	p1_hbox.add_child(p1_btn3)
	
	p1_vbox.add_child(l1)
	p1_vbox.add_child(p1_hbox)
	weapon_hbox.add_child(p1_vbox)
	
	var p2_vbox = VBoxContainer.new()
	var l2 = Label.new()
	l2.text = "Arme Joueur 2"
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.add_theme_color_override("font_color", Color(1.0, 0, 0.33))
	
	p2_weapon_group = ButtonGroup.new()
	p2_btn1 = _create_weapon_btn("🔫 Pistolet", p2_weapon_group, Color(1.0, 0, 0.33))
	p2_btn2 = _create_weapon_btn("💥 Fusil", p2_weapon_group, Color(1.0, 0, 0.33))
	p2_btn3 = _create_weapon_btn("☄️ Pompe", p2_weapon_group, Color(1.0, 0, 0.33))
	p2_btn1.button_pressed = true
	
	var p2_hbox = HBoxContainer.new()
	p2_hbox.add_child(p2_btn1)
	p2_hbox.add_child(p2_btn2)
	p2_hbox.add_child(p2_btn3)
	
	p2_vbox.add_child(l2)
	p2_vbox.add_child(p2_hbox)
	weapon_hbox.add_child(p2_vbox)
	
	go_vbox.add_child(weapon_hbox)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	go_vbox.add_child(spacer)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 30)
	go_vbox.add_child(btn_hbox)
	
	btn_replay = Button.new()
	btn_replay.text = "REJOUER"
	btn_replay.custom_minimum_size = Vector2(200, 60)
	btn_replay.add_theme_font_size_override("font_size", 24)
	btn_replay.pressed.connect(func(): replay_requested.emit())
	btn_hbox.add_child(btn_replay)
	
	btn_quit = Button.new()
	btn_quit.text = "QUITTER"
	btn_quit.custom_minimum_size = Vector2(200, 60)
	btn_quit.add_theme_font_size_override("font_size", 24)
	btn_quit.pressed.connect(func(): quit_requested.emit())
	btn_hbox.add_child(btn_quit)
	
	var debug_hbox = HBoxContainer.new()
	debug_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	go_vbox.add_child(debug_hbox)
	
	btn_debug_light = CheckButton.new()
	btn_debug_light.text = "Lumière Ambiante (Debug)"
	debug_hbox.add_child(btn_debug_light)
	
	p1_cursor = _create_cursor(Color(0, 0.94, 1.0))
	add_child(p1_cursor)
	p2_cursor = _create_cursor(Color(1.0, 0, 0.33))
	add_child(p2_cursor)
	
	_build_nav()
	p1_focus = p1_btn1
	p2_focus = p2_btn1

func _input(event):
	if not game_over_panel.visible: return
	
	if event.is_action_pressed("p1_move_right") and p1_nav.has(p1_focus) and p1_nav[p1_focus].has("right"):
		p1_focus = p1_nav[p1_focus]["right"]
	elif event.is_action_pressed("p1_move_left") and p1_nav.has(p1_focus) and p1_nav[p1_focus].has("left"):
		p1_focus = p1_nav[p1_focus]["left"]
	elif event.is_action_pressed("p1_move_up") and p1_nav.has(p1_focus) and p1_nav[p1_focus].has("up"):
		p1_focus = p1_nav[p1_focus]["up"]
	elif event.is_action_pressed("p1_move_down") and p1_nav.has(p1_focus) and p1_nav[p1_focus].has("down"):
		p1_focus = p1_nav[p1_focus]["down"]
	elif event.is_action_pressed("p1_shoot"):
		p1_focus.pressed.emit()
		if p1_focus.toggle_mode: p1_focus.button_pressed = true
		
	if event.is_action_pressed("p2_move_right") and p2_nav.has(p2_focus) and p2_nav[p2_focus].has("right"):
		p2_focus = p2_nav[p2_focus]["right"]
	elif event.is_action_pressed("p2_move_left") and p2_nav.has(p2_focus) and p2_nav[p2_focus].has("left"):
		p2_focus = p2_nav[p2_focus]["left"]
	elif event.is_action_pressed("p2_move_up") and p2_nav.has(p2_focus) and p2_nav[p2_focus].has("up"):
		p2_focus = p2_nav[p2_focus]["up"]
	elif event.is_action_pressed("p2_move_down") and p2_nav.has(p2_focus) and p2_nav[p2_focus].has("down"):
		p2_focus = p2_nav[p2_focus]["down"]
	elif event.is_action_pressed("p2_shoot"):
		p2_focus.pressed.emit()
		if p2_focus.toggle_mode: p2_focus.button_pressed = true

func update_hud(p1, p2, time_left: float):
	if p1:
		if p1.hp < p1_target_hp:
			p1_shake_time = 0.2
		p1_target_hp = p1.hp
		p1_hp.value = p1.hp
		
		var p1_max_cd = p1.current_weapon.cooldown if p1.current_weapon else 1.0
		var cd_val = 1.0 - (p1.shoot_cooldown / p1_max_cd)
		p1_cd.set_progress(cd_val)
		if p1.shoot_cooldown <= 0:
			p1_cd_label.text = "PRÊT"
		else:
			p1_cd_label.text = "%.1fs" % p1.shoot_cooldown
			
		_set_torch_style(p1_torch, p1.flashlight_on, Color(0, 0.94, 1.0))
		p1_dazzle.color = Color(1, 1, 1, p1.dazzle_amount * 0.8)
		
	if p2:
		if p2.hp < p2_target_hp:
			p2_shake_time = 0.2
		p2_target_hp = p2.hp
		p2_hp.value = p2.hp
		
		var p2_max_cd = p2.current_weapon.cooldown if p2.current_weapon else 1.0
		var cd_val = 1.0 - (p2.shoot_cooldown / p2_max_cd)
		p2_cd.set_progress(cd_val)
		if p2.shoot_cooldown <= 0:
			p2_cd_label.text = "PRÊT"
		else:
			p2_cd_label.text = "%.1fs" % p2.shoot_cooldown
			
		_set_torch_style(p2_torch, p2.flashlight_on, Color(1.0, 0, 0.33))
		p2_dazzle.color = Color(1, 1, 1, p2.dazzle_amount * 0.8)
		
	var m = floori(time_left) / 60
	var s = floori(time_left) % 60
	time_label.text = "%02d:%02d" % [m, s]

func show_main_menu():
	game_over_panel.show()
	game_over_title.text = "CANDELA 2D"
	game_over_title.add_theme_color_override("font_color", Color(1, 0.8, 0))
	game_over_score.text = "PRÊT À JOUER ?"
	btn_replay.text = "JOUER"

func show_game_over(winner_id: int):
	game_over_panel.show()
	game_over_score.text = ""
	btn_replay.text = "REJOUER"
	if winner_id == 0:
		game_over_title.text = "JOUEUR 1 GAGNE LE MATCH"
		game_over_title.add_theme_color_override("font_color", Color(0, 0.94, 1.0))
	elif winner_id == 1:
		game_over_title.text = "JOUEUR 2 GAGNE LE MATCH"
		game_over_title.add_theme_color_override("font_color", Color(1.0, 0, 0.33))
	else:
		game_over_title.text = "ÉGALITÉ"
		game_over_title.add_theme_color_override("font_color", Color.WHITE)

func hide_game_over():
	game_over_panel.hide()

func show_killcam():
	killcam_label.show()
	
func hide_killcam():
	killcam_label.hide()

func set_split_screen_visible(is_visible: bool):
	center_line.visible = is_visible

func _on_res_selected(index: int):
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1280, 720))
			var screen_size = DisplayServer.screen_get_size()
			var win_size = DisplayServer.window_get_size()
			DisplayServer.window_set_position((screen_size - win_size) / 2)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(Vector2i(1920, 1080))
			var screen_size = DisplayServer.screen_get_size()
			var win_size = DisplayServer.window_get_size()
			DisplayServer.window_set_position((screen_size - win_size) / 2)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
