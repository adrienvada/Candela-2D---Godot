extends Node

func _ready():
	_setup_all_inputs()

func _setup_all_inputs():
	# Ensure actions exist
	var actions = [
		"p1_move_up", "p1_move_down", "p1_move_left", "p1_move_right",
		"p1_aim_up", "p1_aim_down", "p1_aim_left", "p1_aim_right",
		"p1_shoot", "p1_torch", "p1_skip_killcam",
		"p1_weapon_prev", "p1_weapon_next", "p1_menu_select",
		"p1_menu_up", "p1_menu_down", "p1_menu_left", "p1_menu_right",
		"p1_menu_prev_tab", "p1_menu_next_tab",
		"p2_move_up", "p2_move_down", "p2_move_left", "p2_move_right",
		"p2_aim_up", "p2_aim_down", "p2_aim_left", "p2_aim_right",
		"p2_shoot", "p2_torch", "p2_skip_killcam",
		"p2_weapon_prev", "p2_weapon_next", "p2_menu_select",
		"p2_menu_up", "p2_menu_down", "p2_menu_left", "p2_menu_right",
		"p2_menu_prev_tab", "p2_menu_next_tab",
		"sys_pause"
	]
	
	for a in actions:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			InputMap.action_set_deadzone(a, 0.2)
			
	# Keyboard Escape for pause
	var esc = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	InputMap.action_add_event("sys_pause", esc)
	
	# Helper for joy axis
	var add_joy_axis = func(action: String, device: int, axis: int, val: float):
		var ev = InputEventJoypadMotion.new()
		ev.device = device
		ev.axis = axis
		ev.axis_value = val
		InputMap.action_add_event(action, ev)
		
	# Helper for joy button
	var add_joy_btn = func(action: String, device: int, btn: int):
		var ev = InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = btn
		InputMap.action_add_event(action, ev)

	# Get actual connected joypad IDs
	var pads = Input.get_connected_joypads()
	print("Connected joypads: ", pads)
	for pad in pads:
		print("Joypad ", pad, ": ", Input.get_joy_name(pad))
		
	var p1_device = pads[0] if pads.size() > 0 else 0
	var p2_device = pads[1] if pads.size() > 1 else 1
	
	print("Assigning Device ", p1_device, " to Player 1")
	print("Assigning Device ", p2_device, " to Player 2")

	# P1
	add_joy_axis.call("p1_move_left", p1_device, JOY_AXIS_LEFT_X, -1.0)
	add_joy_axis.call("p1_move_right", p1_device, JOY_AXIS_LEFT_X, 1.0)
	add_joy_axis.call("p1_move_up", p1_device, JOY_AXIS_LEFT_Y, -1.0)
	add_joy_axis.call("p1_move_down", p1_device, JOY_AXIS_LEFT_Y, 1.0)
	
	add_joy_axis.call("p1_aim_left", p1_device, JOY_AXIS_RIGHT_X, -1.0)
	add_joy_axis.call("p1_aim_right", p1_device, JOY_AXIS_RIGHT_X, 1.0)
	add_joy_axis.call("p1_aim_up", p1_device, JOY_AXIS_RIGHT_Y, -1.0)
	add_joy_axis.call("p1_aim_down", p1_device, JOY_AXIS_RIGHT_Y, 1.0)
	
	# L2 = Torche, R1 = Tir
	add_joy_btn.call("p1_shoot", p1_device, JOY_BUTTON_RIGHT_SHOULDER) # R1
	add_joy_axis.call("p1_torch", p1_device, JOY_AXIS_TRIGGER_LEFT, 1.0) # L2
	
	# Carré : libre. Il portait « Courir » jusqu'à la suppression du sprint
	# (2026-08-26) ; la liaison est partie sans son commentaire, qui a continué
	# d'annoncer une ligne absente. Avec Triangle, c'est l'un des deux boutons
	# de face que le JEU n'utilise pas — l'éditeur de cartes, lui, les prend
	# tous les deux (Effacer et Tester).
	
	# Croix = Sélectionner menu
	add_joy_btn.call("p1_menu_select", p1_device, JOY_BUTTON_A) # Croix
	
	# L1 / R1 = Changer d'onglet
	add_joy_btn.call("p1_menu_prev_tab", p1_device, JOY_BUTTON_LEFT_SHOULDER) # L1
	add_joy_btn.call("p1_menu_next_tab", p1_device, JOY_BUTTON_RIGHT_SHOULDER) # R1
	
	# Rond = Passer killcam
	add_joy_btn.call("p1_skip_killcam", p1_device, JOY_BUTTON_B) # Rond
	
	# D-pad Gauche/Droite = Changer d'arme (Debug mode only, checked in game_state)
	add_joy_btn.call("p1_weapon_prev", p1_device, JOY_BUTTON_DPAD_LEFT)
	add_joy_btn.call("p1_weapon_next", p1_device, JOY_BUTTON_DPAD_RIGHT)
	
	# Menu Navigation
	add_joy_btn.call("p1_menu_up", p1_device, JOY_BUTTON_DPAD_UP)
	add_joy_btn.call("p1_menu_down", p1_device, JOY_BUTTON_DPAD_DOWN)
	add_joy_btn.call("p1_menu_left", p1_device, JOY_BUTTON_DPAD_LEFT)
	add_joy_btn.call("p1_menu_right", p1_device, JOY_BUTTON_DPAD_RIGHT)
	
	add_joy_axis.call("p1_menu_up", p1_device, JOY_AXIS_LEFT_Y, -1.0)
	add_joy_axis.call("p1_menu_down", p1_device, JOY_AXIS_LEFT_Y, 1.0)
	add_joy_axis.call("p1_menu_left", p1_device, JOY_AXIS_LEFT_X, -1.0)
	add_joy_axis.call("p1_menu_right", p1_device, JOY_AXIS_LEFT_X, 1.0)
	
	# P2
	add_joy_axis.call("p2_move_left", p2_device, JOY_AXIS_LEFT_X, -1.0)
	add_joy_axis.call("p2_move_right", p2_device, JOY_AXIS_LEFT_X, 1.0)
	add_joy_axis.call("p2_move_up", p2_device, JOY_AXIS_LEFT_Y, -1.0)
	add_joy_axis.call("p2_move_down", p2_device, JOY_AXIS_LEFT_Y, 1.0)
	
	add_joy_axis.call("p2_aim_left", p2_device, JOY_AXIS_RIGHT_X, -1.0)
	add_joy_axis.call("p2_aim_right", p2_device, JOY_AXIS_RIGHT_X, 1.0)
	add_joy_axis.call("p2_aim_up", p2_device, JOY_AXIS_RIGHT_Y, -1.0)
	add_joy_axis.call("p2_aim_down", p2_device, JOY_AXIS_RIGHT_Y, 1.0)
	
	# L2 = Torche, R1 = Tir
	add_joy_btn.call("p2_shoot", p2_device, JOY_BUTTON_RIGHT_SHOULDER) # R1
	add_joy_axis.call("p2_torch", p2_device, JOY_AXIS_TRIGGER_LEFT, 1.0) # L2
	
	# Carré : libre. Il portait « Courir » jusqu'à la suppression du sprint
	# (2026-08-26) ; la liaison est partie sans son commentaire, qui a continué
	# d'annoncer une ligne absente. Avec Triangle, c'est l'un des deux boutons
	# de face que le JEU n'utilise pas — l'éditeur de cartes, lui, les prend
	# tous les deux (Effacer et Tester).
	
	# Croix = Sélectionner menu
	add_joy_btn.call("p2_menu_select", p2_device, JOY_BUTTON_A) # Croix
	
	# L1 / R1 = Changer d'onglet
	add_joy_btn.call("p2_menu_prev_tab", p2_device, JOY_BUTTON_LEFT_SHOULDER) # L1
	add_joy_btn.call("p2_menu_next_tab", p2_device, JOY_BUTTON_RIGHT_SHOULDER) # R1
	
	# Rond = Passer killcam
	add_joy_btn.call("p2_skip_killcam", p2_device, JOY_BUTTON_B) # Rond
	
	# D-pad Gauche/Droite = Changer d'arme
	add_joy_btn.call("p2_weapon_prev", p2_device, JOY_BUTTON_DPAD_LEFT)
	add_joy_btn.call("p2_weapon_next", p2_device, JOY_BUTTON_DPAD_RIGHT)

	# Menu Navigation
	add_joy_btn.call("p2_menu_up", p2_device, JOY_BUTTON_DPAD_UP)
	add_joy_btn.call("p2_menu_down", p2_device, JOY_BUTTON_DPAD_DOWN)
	add_joy_btn.call("p2_menu_left", p2_device, JOY_BUTTON_DPAD_LEFT)
	add_joy_btn.call("p2_menu_right", p2_device, JOY_BUTTON_DPAD_RIGHT)
	
	add_joy_axis.call("p2_menu_up", p2_device, JOY_AXIS_LEFT_Y, -1.0)
	add_joy_axis.call("p2_menu_down", p2_device, JOY_AXIS_LEFT_Y, 1.0)
	add_joy_axis.call("p2_menu_left", p2_device, JOY_AXIS_LEFT_X, -1.0)
	add_joy_axis.call("p2_menu_right", p2_device, JOY_AXIS_LEFT_X, 1.0)
	
	# Start / Menu button for pause
	add_joy_btn.call("sys_pause", p1_device, JOY_BUTTON_START)
	add_joy_btn.call("sys_pause", p2_device, JOY_BUTTON_START)

func _setup_editor_inputs(device: int):
	var actions = [
		"editor_move_up", "editor_move_down", "editor_move_left", "editor_move_right",
		"editor_draw", "editor_clear", "editor_back",
		"editor_step_prev", "editor_step_next",
		"editor_export", "editor_import", "editor_test"
	]
	
	for a in actions:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			InputMap.action_set_deadzone(a, 0.2)
			
	var add_joy_axis = func(action: String, dev: int, axis: int, val: float):
		var ev = InputEventJoypadMotion.new()
		ev.device = dev
		ev.axis = axis
		ev.axis_value = val
		InputMap.action_add_event(action, ev)
		
	var add_joy_btn = func(action: String, dev: int, btn: int):
		var ev = InputEventJoypadButton.new()
		ev.device = dev
		ev.button_index = btn
		InputMap.action_add_event(action, ev)
		
	# Move (Stick + D-Pad)
	add_joy_axis.call("editor_move_up", device, JOY_AXIS_LEFT_Y, -1.0)
	add_joy_axis.call("editor_move_down", device, JOY_AXIS_LEFT_Y, 1.0)
	add_joy_axis.call("editor_move_left", device, JOY_AXIS_LEFT_X, -1.0)
	add_joy_axis.call("editor_move_right", device, JOY_AXIS_LEFT_X, 1.0)
	add_joy_btn.call("editor_move_up", device, JOY_BUTTON_DPAD_UP)
	add_joy_btn.call("editor_move_down", device, JOY_BUTTON_DPAD_DOWN)
	add_joy_btn.call("editor_move_left", device, JOY_BUTTON_DPAD_LEFT)
	add_joy_btn.call("editor_move_right", device, JOY_BUTTON_DPAD_RIGHT)
	
	# Actions
	add_joy_btn.call("editor_draw", device, JOY_BUTTON_A)        # Croix PS / A Xbox = Peindre
	add_joy_btn.call("editor_clear", device, JOY_BUTTON_X)       # Carré PS / X Xbox = Effacer
	add_joy_btn.call("editor_back", device, JOY_BUTTON_B)        # Rond / B = Retour menu
	add_joy_btn.call("editor_step_prev", device, JOY_BUTTON_LEFT_SHOULDER)
	add_joy_btn.call("editor_step_next", device, JOY_BUTTON_RIGHT_SHOULDER)
	add_joy_btn.call("editor_export", device, JOY_BUTTON_START)
	add_joy_btn.call("editor_import", device, JOY_BUTTON_BACK)
	add_joy_btn.call("editor_test", device, JOY_BUTTON_Y)
	
	# Keyboard fallback for back
	var esc = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	InputMap.action_add_event("editor_back", esc)
