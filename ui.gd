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

var btn_controls: Button
var controls_panel: PanelContainer

var _is_rebinding: bool = false
var _action_to_rebind: String = ""
var _button_to_update: Button = null

var debug_panel: PanelContainer
var fps_label: Label
var debug_mode_active: bool = false
var _f3_was_pressed: bool = false

var killcam_overlay: ColorRect
var killcam_container: Control
var killcam_label_shadow1: Label
var killcam_label_shadow2: Label
var killcam_timecode: Label
var _killcam_glitch_timer: float = 0.0
var killcam_label: Label

var p1_shake_time: float = 0.0
var p2_shake_time: float = 0.0
var shake_intensity: float = 10.0

var p1_target_hp: float = 100.0
var p2_target_hp: float = 100.0
var p1_bg_hp: float = 100.0
var p2_bg_hp: float = 100.0

var btn_tab_game: Button
var btn_tab_controls: Button
var tab_game_container: VBoxContainer
var tab_controls_container: VBoxContainer
var btn_resume: Button
var _controls_grid_buttons: Array = []
var _is_main_menu: bool = true

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_disable_ui_joystick()
	_build_ui()
	_connect_buttons_audio(self)

func _connect_buttons_audio(node: Node):
	if node is Button:
		node.pressed.connect(func(): AudioManager.play_button_click())
	for child in node.get_children():
		_connect_buttons_audio(child)


func _disable_ui_joystick():
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]:
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				if event is InputEventJoypadMotion:
					InputMap.action_erase_event(action, event)

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
		
	var f3_pressed = Input.is_physical_key_pressed(KEY_F3)
	if f3_pressed and not _f3_was_pressed:
		debug_mode_active = !debug_mode_active
		debug_panel.visible = debug_mode_active
	_f3_was_pressed = f3_pressed
	
	if debug_mode_active:
		fps_label.text = "DEBUG MODE | FPS: %d" % Engine.get_frames_per_second()
		
	if killcam_container and killcam_container.visible:
		var ms = Time.get_ticks_msec()
		var sec = (ms / 1000) % 60
		var mins = (ms / 60000) % 60
		var frames = Engine.get_frames_drawn() % 60
		
		if (ms / 500) % 2 == 0:
			killcam_timecode.text = "REC •\n%02d:%02d:%02d" % [mins, sec, frames]
			killcam_timecode.add_theme_color_override("font_color", Color(1, 0, 0, 0.8))
		else:
			killcam_timecode.text = "REC  \n%02d:%02d:%02d" % [mins, sec, frames]
			killcam_timecode.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		
		if killcam_overlay.material:
			killcam_overlay.material.set_shader_parameter("time", ms / 1000.0)
			
		_killcam_glitch_timer -= delta
		if _killcam_glitch_timer <= 0:
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
	p1_nav = {}
	p2_nav = {}
	
	var game_active = tab_game_container.visible
	var p1_down_tabs = p1_btn1 if game_active else (_controls_grid_buttons[0]["p1"] if _controls_grid_buttons.size() > 0 else null)
	var p2_down_tabs = p2_btn1 if game_active else (_controls_grid_buttons[0]["p2"] if _controls_grid_buttons.size() > 0 else null)
	
	# Game Tab
	p1_nav[p1_btn1] = {"up": btn_resume if btn_resume.visible else btn_replay, "right": p1_btn2, "down": btn_resume if btn_resume.visible else btn_replay}
	p1_nav[p1_btn2] = {"up": btn_quit, "left": p1_btn1, "right": p1_btn3, "down": btn_quit}
	p1_nav[p1_btn3] = {"up": btn_debug_light, "left": p1_btn2, "down": btn_debug_light}
	
	p2_nav[p2_btn1] = {"up": btn_resume if btn_resume.visible else btn_replay, "right": p2_btn2, "down": btn_resume if btn_resume.visible else btn_replay}
	p2_nav[p2_btn2] = {"up": btn_quit, "left": p2_btn1, "right": p2_btn3, "down": btn_quit}
	p2_nav[p2_btn3] = {"up": btn_debug_light, "left": p2_btn2, "down": btn_debug_light}
	
	# Bottom Buttons (Dynamic based on tab)
	var p1_up_resume = p1_btn1 if game_active else (_controls_grid_buttons.back()["p1"] if _controls_grid_buttons.size() > 0 else btn_tab_controls)
	var p1_up_quit = p1_btn2 if game_active else (_controls_grid_buttons.back()["p1"] if _controls_grid_buttons.size() > 0 else btn_tab_controls)
	var right_resume = btn_replay if btn_replay.visible else btn_quit
	var left_quit = btn_replay if btn_replay.visible else (btn_resume if btn_resume.visible else null)
	
	p1_nav[btn_resume] = {"up": p1_up_resume, "right": right_resume, "down": btn_debug_light}
	p1_nav[btn_replay] = {"up": p1_up_resume, "left": btn_resume if btn_resume.visible else null, "right": btn_quit, "down": btn_debug_light}
	p1_nav[btn_quit] = {"up": p1_up_quit, "left": left_quit, "down": btn_debug_light}
	p1_nav[btn_debug_light] = {"up": btn_quit}
	
	var p2_up_resume = p2_btn1 if game_active else (_controls_grid_buttons.back()["p2"] if _controls_grid_buttons.size() > 0 else btn_tab_controls)
	var p2_up_quit = p2_btn2 if game_active else (_controls_grid_buttons.back()["p2"] if _controls_grid_buttons.size() > 0 else btn_tab_controls)
	
	p2_nav[btn_resume] = {"up": p2_up_resume, "right": right_resume, "down": btn_debug_light}
	p2_nav[btn_replay] = {"up": p2_up_resume, "left": btn_resume if btn_resume.visible else null, "right": btn_quit, "down": btn_debug_light}
	p2_nav[btn_quit] = {"up": p2_up_quit, "left": left_quit, "down": btn_debug_light}
	p2_nav[btn_debug_light] = {"up": btn_quit}
	
	# Controls Tab
	var rows = _controls_grid_buttons.size()
	for i in range(rows):
		var p1_btn = _controls_grid_buttons[i]["p1"]
		var p2_btn = _controls_grid_buttons[i]["p2"]
		
		var p1_up = _controls_grid_buttons[rows-1]["p1"] if i == 0 else _controls_grid_buttons[i-1]["p1"]
		var p1_down = _controls_grid_buttons[i+1]["p1"] if i < rows - 1 else (btn_resume if btn_resume.visible else btn_replay)
		
		var p2_up = _controls_grid_buttons[rows-1]["p2"] if i == 0 else _controls_grid_buttons[i-1]["p2"]
		var p2_down = _controls_grid_buttons[i+1]["p2"] if i < rows - 1 else (btn_resume if btn_resume.visible else btn_replay)
		
		p1_nav[p1_btn] = {"up": p1_up, "down": p1_down}
		p2_nav[p2_btn] = {"up": p2_up, "down": p2_down}


func _create_weapon_btn(text: String, group: ButtonGroup, player_color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_group = group
	btn.custom_minimum_size = Vector2(140, 80)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pivot_offset = btn.custom_minimum_size / 2.0
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.2, 0.2, 0.2, 1.0)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.border_color = player_color.lerp(Color.WHITE, 0.5)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = player_color
	pressed_style.border_color = Color.WHITE
	pressed_style.border_width_left = 4
	pressed_style.border_width_right = 4
	pressed_style.border_width_top = 4
	pressed_style.border_width_bottom = 4
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	var focus_style = style.duplicate()
	focus_style.border_color = player_color
	btn.add_theme_stylebox_override("focus", focus_style)
	
	btn.toggled.connect(_on_weapon_toggled.bind(btn, player_color))
	return btn

func _on_weapon_toggled(toggled_on: bool, btn: Button, player_color: Color):
	if toggled_on:
		btn.add_theme_color_override("font_color", Color.BLACK)
		btn.add_theme_color_override("font_hover_pressed_color", Color.BLACK)
		btn.add_theme_color_override("font_focus_color", Color.BLACK)
		btn.add_theme_color_override("font_pressed_color", Color.BLACK)
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	else:
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_color_override("font_hover_pressed_color")
		btn.remove_theme_color_override("font_focus_color")
		btn.remove_theme_color_override("font_pressed_color")
		var tween = create_tween()
		tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)

func _style_tab_btn(btn: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover = style.duplicate()
	hover.border_color = Color.WHITE
	btn.add_theme_stylebox_override("hover", hover)
	
	var pressed = style.duplicate()
	pressed.bg_color = Color.WHITE
	pressed.border_color = Color.WHITE
	pressed.border_width_left = 4
	pressed.border_width_right = 4
	pressed.border_width_top = 4
	pressed.border_width_bottom = 4
	btn.add_theme_stylebox_override("pressed", pressed)
	
	var focus = style.duplicate()
	focus.border_color = Color(1.0, 0.8, 0.0) # Yellow focus
	btn.add_theme_stylebox_override("focus", focus)
	
	btn.toggled.connect(func(toggled_on):
		if toggled_on:
			btn.add_theme_color_override("font_color", Color.BLACK)
			btn.add_theme_color_override("font_hover_pressed_color", Color.BLACK)
			btn.add_theme_color_override("font_focus_color", Color.BLACK)
			btn.add_theme_color_override("font_pressed_color", Color.BLACK)
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_hover_pressed_color")
			btn.remove_theme_color_override("font_focus_color")
			btn.remove_theme_color_override("font_pressed_color")
	)

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
	killcam_overlay = ColorRect.new()
	killcam_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	killcam_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	killcam_overlay.hide()
	var killcam_shader = ShaderMaterial.new()
	var shader = Shader.new()
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
	killcam_shader.shader = shader
	killcam_overlay.material = killcam_shader
	# We DO NOT add killcam_overlay to ui here. GameState will take it and put it in the arena.
	
	killcam_container = Control.new()
	killcam_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	killcam_container.offset_top = 100
	killcam_container.hide()
	add_child(killcam_container)
	
	killcam_label_shadow1 = Label.new()
	killcam_label_shadow1.text = "KILLCAM"
	killcam_label_shadow1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	killcam_label_shadow1.add_theme_font_size_override("font_size", 48)
	killcam_label_shadow1.add_theme_color_override("font_color", Color(0, 1, 1, 0.5))
	killcam_label_shadow1.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	killcam_container.add_child(killcam_label_shadow1)
	
	killcam_label_shadow2 = Label.new()
	killcam_label_shadow2.text = "KILLCAM"
	killcam_label_shadow2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	killcam_label_shadow2.add_theme_font_size_override("font_size", 48)
	killcam_label_shadow2.add_theme_color_override("font_color", Color(1, 1, 0, 0.5))
	killcam_label_shadow2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	killcam_container.add_child(killcam_label_shadow2)

	killcam_label = Label.new()
	killcam_label.text = "KILLCAM"
	killcam_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	killcam_label.add_theme_font_size_override("font_size", 48)
	killcam_label.add_theme_color_override("font_color", Color(1, 0, 0))
	killcam_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	killcam_container.add_child(killcam_label)

	killcam_timecode = Label.new()
	killcam_timecode.add_theme_font_size_override("font_size", 24)
	killcam_timecode.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	killcam_timecode.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	killcam_timecode.offset_right = -40
	killcam_timecode.offset_top = 40
	killcam_timecode.hide()
	add_child(killcam_timecode)
	
	# Main Menu / Game Over Panel
	game_over_panel = PanelContainer.new()
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_panel.hide()
	add_child(game_over_panel)
	
	var go_bg = ColorRect.new()
	go_bg.color = Color(0, 0, 0, 0.95)
	game_over_panel.add_child(go_bg)
	
	var menu_vbox = VBoxContainer.new()
	menu_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_panel.add_child(menu_vbox)
	
	# Top Tabs
	var tabs_margin = MarginContainer.new()
	tabs_margin.add_theme_constant_override("margin_top", 40)
	tabs_margin.add_theme_constant_override("margin_bottom", 20)
	menu_vbox.add_child(tabs_margin)
	
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_hbox.add_theme_constant_override("separation", 20)
	tabs_margin.add_child(tabs_hbox)
	
	var tab_group = ButtonGroup.new()
	
	var l1_icon = TextureRect.new()
	if ResourceLoader.exists("res://assets/ui/prompts/l1.svg"):
		l1_icon.texture = load("res://assets/ui/prompts/l1.svg")
	l1_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	l1_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	l1_icon.custom_minimum_size = Vector2(26, 26)
	tabs_hbox.add_child(l1_icon)
	
	btn_tab_game = Button.new()
	btn_tab_game.text = "JEU"
	btn_tab_game.toggle_mode = true
	btn_tab_game.focus_mode = Control.FOCUS_NONE
	btn_tab_game.button_group = tab_group
	btn_tab_game.custom_minimum_size = Vector2(200, 50)
	btn_tab_game.add_theme_font_size_override("font_size", 24)
	_style_tab_btn(btn_tab_game)
	btn_tab_game.toggled.connect(func(pressed): if pressed: _switch_tab("JEU"))
	tabs_hbox.add_child(btn_tab_game)
	
	btn_tab_controls = Button.new()
	btn_tab_controls.text = "CONTRÔLES"
	btn_tab_controls.toggle_mode = true
	btn_tab_controls.focus_mode = Control.FOCUS_NONE
	btn_tab_controls.button_group = tab_group
	btn_tab_controls.custom_minimum_size = Vector2(200, 50)
	btn_tab_controls.add_theme_font_size_override("font_size", 24)
	_style_tab_btn(btn_tab_controls)
	btn_tab_controls.toggled.connect(func(pressed): if pressed: _switch_tab("CONTROLES"))
	tabs_hbox.add_child(btn_tab_controls)
	
	var r1_icon = TextureRect.new()
	if ResourceLoader.exists("res://assets/ui/prompts/r1.svg"):
		r1_icon.texture = load("res://assets/ui/prompts/r1.svg")
	r1_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	r1_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r1_icon.custom_minimum_size = Vector2(26, 26)
	tabs_hbox.add_child(r1_icon)
	
	# Container creation continues below...
	var content_margin = MarginContainer.new()
	content_margin.custom_minimum_size = Vector2(0, 350)
	menu_vbox.add_child(content_margin)
	
	# GAME TAB CONTENT
	tab_game_container = VBoxContainer.new()
	tab_game_container.add_theme_constant_override("separation", 20)
	tab_game_container.alignment = BoxContainer.ALIGNMENT_CENTER
	content_margin.add_child(tab_game_container)
	
	game_over_title = Label.new()
	game_over_title.text = "MATCH TERMINÉ"
	game_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_title.add_theme_font_size_override("font_size", 64)
	tab_game_container.add_child(game_over_title)
	
	game_over_score = Label.new()
	game_over_score.text = "SCORE: 0 - 0"
	game_over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_score.add_theme_font_size_override("font_size", 32)
	tab_game_container.add_child(game_over_score)
	
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
	
	tab_game_container.add_child(weapon_hbox)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	menu_vbox.add_child(spacer)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 30)
	menu_vbox.add_child(btn_hbox)
	
	btn_resume = Button.new()
	btn_resume.text = "REPRENDRE"
	btn_resume.custom_minimum_size = Vector2(200, 60)
	btn_resume.add_theme_font_size_override("font_size", 24)
	btn_resume.pressed.connect(_resume_game)
	btn_hbox.add_child(btn_resume)
	
	btn_replay = Button.new()
	btn_replay.text = "REJOUER"
	btn_replay.custom_minimum_size = Vector2(200, 60)
	btn_replay.add_theme_font_size_override("font_size", 24)
	btn_replay.pressed.connect(func(): get_tree().paused = false; replay_requested.emit())
	btn_hbox.add_child(btn_replay)
	
	btn_quit = Button.new()
	btn_quit.text = "QUITTER"
	btn_quit.custom_minimum_size = Vector2(200, 60)
	btn_quit.add_theme_font_size_override("font_size", 24)
	btn_quit.pressed.connect(func(): get_tree().paused = false; quit_requested.emit())
	btn_hbox.add_child(btn_quit)
	
	var debug_hbox = HBoxContainer.new()
	debug_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_vbox.add_child(debug_hbox)
	
	btn_debug_light = CheckButton.new()
	btn_debug_light.text = "Lumière Ambiante (Debug)"
	debug_hbox.add_child(btn_debug_light)
	
	# CONTROLS TAB CONTENT
	tab_controls_container = VBoxContainer.new()
	tab_controls_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_controls_container.add_theme_constant_override("separation", 20)
	tab_controls_container.hide()
	content_margin.add_child(tab_controls_container)
	
	var cp_title = Label.new()
	cp_title.text = "MAPPING MANETTE"
	cp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cp_title.add_theme_font_size_override("font_size", 32)
	cp_title.add_theme_color_override("font_color", Color(1, 0.8, 0))
	tab_controls_container.add_child(cp_title)
	
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tab_controls_container.add_child(grid)
	
	var bindable_actions = {
		"Tirer": ["p1_shoot", "p2_shoot"],
		"Torche": ["p1_torch", "p2_torch"],
		"Courir": ["p1_sprint", "p2_sprint"]
	}
	
	var hl = Label.new()
	hl.text = "ACTION"
	hl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	grid.add_child(hl)
	var hl1 = Label.new()
	hl1.text = "JOUEUR 1"
	hl1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl1.add_theme_color_override("font_color", Color(0, 0.94, 1.0))
	grid.add_child(hl1)
	var hl2 = Label.new()
	hl2.text = "JOUEUR 2"
	hl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl2.add_theme_color_override("font_color", Color(1.0, 0, 0.33))
	grid.add_child(hl2)
	
	# Build grid dynamically to easily reference them in navigation
	_controls_grid_buttons = []
	for action_name in bindable_actions.keys():
		var label = Label.new()
		label.text = action_name
		grid.add_child(label)
		
		var p1_action = bindable_actions[action_name][0]
		var p1_btn = Button.new()
		_apply_btn_info(p1_btn, _get_action_btn_info(p1_action))
		p1_btn.custom_minimum_size = Vector2(60, 60)
		
		var p1_container = CenterContainer.new()
		p1_container.add_child(p1_btn)
		p1_btn.pressed.connect(_on_rebind_btn_pressed.bind(p1_btn, p1_action))
		grid.add_child(p1_container)
		
		var p2_action = bindable_actions[action_name][1]
		var p2_btn = Button.new()
		_apply_btn_info(p2_btn, _get_action_btn_info(p2_action))
		p2_btn.custom_minimum_size = Vector2(60, 60)
		
		var p2_container = CenterContainer.new()
		p2_container.add_child(p2_btn)
		p2_btn.pressed.connect(_on_rebind_btn_pressed.bind(p2_btn, p2_action))
		grid.add_child(p2_container)
		
		_controls_grid_buttons.append({"p1": p1_btn, "p2": p2_btn})
	
	p1_cursor = _create_cursor(Color(0, 0.94, 1.0))
	add_child(p1_cursor)
	p2_cursor = _create_cursor(Color(1.0, 0, 0.33))
	add_child(p2_cursor)
	
	# Set initial tab and trigger visual update
	# This automatically calls _build_nav() and sets up focus inside _switch_tab()
	btn_tab_game.button_pressed = true
	_switch_tab("JEU")

func _switch_tab(tab_name: String):
	if tab_name == "JEU":
		btn_tab_game.button_pressed = true
		tab_game_container.show()
		tab_controls_container.hide()
		# Synchronize both players to the new tab
		if not p1_nav.has(p1_focus) or p1_focus == null or p1_focus.get_parent() != tab_game_container and p1_focus.get_parent().get_parent() != tab_game_container and p1_focus.get_parent().get_parent().get_parent() != tab_game_container:
			p1_focus = p1_btn1
		if not p2_nav.has(p2_focus) or p2_focus == null or p2_focus.get_parent() != tab_game_container and p2_focus.get_parent().get_parent() != tab_game_container and p2_focus.get_parent().get_parent().get_parent() != tab_game_container:
			p2_focus = p2_btn1
	else:
		btn_tab_controls.button_pressed = true
		tab_game_container.hide()
		tab_controls_container.show()
		# Synchronize both players to the new tab
		if _controls_grid_buttons.size() > 0:
			p1_focus = _controls_grid_buttons[0]["p1"]
			p2_focus = _controls_grid_buttons[0]["p2"]
			
	_build_nav()

func _resume_game():
	get_tree().paused = false
	game_over_panel.hide()

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

func _apply_btn_info(btn: Button, info: Dictionary):
	if info.get("icon", "") != "":
		var path_svg = "res://assets/ui/prompts/" + info["icon"]
		
		if ResourceLoader.exists(path_svg):
			var tex = load(path_svg)
			btn.icon = tex
			btn.text = ""
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true
			return
	btn.icon = null
	btn.text = info.get("text", "")

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

func _on_rebind_btn_pressed(btn: Button, action: String):
	if _is_rebinding: return
	_is_rebinding = true
	_action_to_rebind = action
	_button_to_update = btn
	btn.text = "Appuyez..."
	btn.icon = null
	btn.add_theme_color_override("font_color", Color(1, 1, 0))

func _input(event):
	if _is_rebinding:
		var valid_event = false
		var new_ev = null
		var display_info = {}
		
		if event is InputEventJoypadButton and event.is_pressed():
			valid_event = true
			new_ev = InputEventJoypadButton.new()
			new_ev.button_index = event.button_index
			display_info = _get_joypad_btn_info(event.button_index)
			
		elif event is InputEventJoypadMotion and event.axis_value > 0.5:
			if event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT:
				valid_event = true
				new_ev = InputEventJoypadMotion.new()
				new_ev.axis = event.axis
				new_ev.axis_value = 1.0
				display_info = {"text": "Gâchette L2", "icon": "l2.svg"} if event.axis == JOY_AXIS_TRIGGER_LEFT else {"text": "Gâchette R2", "icon": "r2.svg"}
		
		if valid_event:
			var old_events = InputMap.action_get_events(_action_to_rebind)
			for ev in old_events:
				if ev is InputEventJoypadButton or (ev is InputEventJoypadMotion and (ev.axis == JOY_AXIS_TRIGGER_LEFT or ev.axis == JOY_AXIS_TRIGGER_RIGHT)):
					InputMap.action_erase_event(_action_to_rebind, ev)
			
			var target_device = 0
			if old_events.size() > 0:
				target_device = old_events[0].device
			new_ev.device = target_device
			InputMap.action_add_event(_action_to_rebind, new_ev)
			
			_apply_btn_info(_button_to_update, display_info)
			_button_to_update.remove_theme_color_override("font_color")
			_is_rebinding = false
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("sys_pause"):
		if not _is_main_menu and not game_over_panel.visible:
			# Pause game
			get_tree().paused = true
			btn_resume.show()
			btn_replay.hide()
			game_over_title.text = "PAUSE"
			game_over_title.add_theme_color_override("font_color", Color(1, 1, 1))
			game_over_score.text = ""
			game_over_panel.show()
			_switch_tab("JEU")
			_build_nav()
			get_viewport().set_input_as_handled()
			return
		elif game_over_panel.visible and btn_resume.visible:
			# Unpause game
			_resume_game()
			get_viewport().set_input_as_handled()
			return

	if not game_over_panel.visible: return
	
	# Tab switching
	if event.is_action_pressed("p1_menu_prev_tab") or event.is_action_pressed("p2_menu_prev_tab"):
		if tab_controls_container.visible:
			_switch_tab("JEU")
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("p1_menu_next_tab") or event.is_action_pressed("p2_menu_next_tab"):
		if tab_game_container.visible:
			_switch_tab("CONTROLES")
		get_viewport().set_input_as_handled()
		return
	
	if p1_nav.has(p1_focus):
		if event.is_action_pressed("p1_menu_right") and p1_nav[p1_focus].has("right") and p1_nav[p1_focus]["right"] != null:
			p1_focus = p1_nav[p1_focus]["right"]
		elif event.is_action_pressed("p1_menu_left") and p1_nav[p1_focus].has("left") and p1_nav[p1_focus]["left"] != null:
			p1_focus = p1_nav[p1_focus]["left"]
		elif event.is_action_pressed("p1_menu_up") and p1_nav[p1_focus].has("up") and p1_nav[p1_focus]["up"] != null:
			p1_focus = p1_nav[p1_focus]["up"]
		elif event.is_action_pressed("p1_menu_down") and p1_nav[p1_focus].has("down") and p1_nav[p1_focus]["down"] != null:
			p1_focus = p1_nav[p1_focus]["down"]
		elif event.is_action_pressed("p1_menu_select"):
			p1_focus.pressed.emit()
			if p1_focus.toggle_mode:
				if p1_focus.button_group != null:
					p1_focus.button_pressed = true
				else:
					p1_focus.button_pressed = not p1_focus.button_pressed
				p1_focus.toggled.emit(p1_focus.button_pressed)
		
	if p2_nav.has(p2_focus):
		if event.is_action_pressed("p2_menu_right") and p2_nav[p2_focus].has("right") and p2_nav[p2_focus]["right"] != null:
			p2_focus = p2_nav[p2_focus]["right"]
		elif event.is_action_pressed("p2_menu_left") and p2_nav[p2_focus].has("left") and p2_nav[p2_focus]["left"] != null:
			p2_focus = p2_nav[p2_focus]["left"]
		elif event.is_action_pressed("p2_menu_up") and p2_nav[p2_focus].has("up") and p2_nav[p2_focus]["up"] != null:
			p2_focus = p2_nav[p2_focus]["up"]
		elif event.is_action_pressed("p2_menu_down") and p2_nav[p2_focus].has("down") and p2_nav[p2_focus]["down"] != null:
			p2_focus = p2_nav[p2_focus]["down"]
		elif event.is_action_pressed("p2_menu_select"):
			p2_focus.pressed.emit()
			if p2_focus.toggle_mode:
				if p2_focus.button_group != null:
					p2_focus.button_pressed = true
				else:
					p2_focus.button_pressed = not p2_focus.button_pressed
				p2_focus.toggled.emit(p2_focus.button_pressed)

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
	_is_main_menu = true
	btn_resume.hide()
	btn_replay.show()
	_switch_tab("JEU")
	game_over_panel.show()
	game_over_title.text = "CANDELA 2D"
	game_over_title.add_theme_color_override("font_color", Color(1, 0.8, 0))
	game_over_score.text = "PRÊT À JOUER ?"
	btn_replay.text = "JOUER"
	_build_nav()

func show_game_over(winner_id: int):
	_is_main_menu = false
	btn_resume.hide()
	btn_replay.show()
	_switch_tab("JEU")
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
	_build_nav()

func hide_game_over():
	_is_main_menu = false
	game_over_panel.hide()

func show_killcam():
	killcam_overlay.show()
	killcam_container.show()
	killcam_timecode.show()
	if get_node_or_null("../SplitScreen/ViewportContainer1/SubViewport1/Arena/KillcamBB"):
		get_node("../SplitScreen/ViewportContainer1/SubViewport1/Arena/KillcamBB").show()
	
func hide_killcam():
	killcam_overlay.hide()
	killcam_container.hide()
	killcam_timecode.hide()
	if get_node_or_null("../SplitScreen/ViewportContainer1/SubViewport1/Arena/KillcamBB"):
		get_node("../SplitScreen/ViewportContainer1/SubViewport1/Arena/KillcamBB").hide()

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
