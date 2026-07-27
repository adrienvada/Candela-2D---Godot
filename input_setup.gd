extends Node

func _ready():
	_setup_all_inputs()

func _setup_all_inputs():
	# Ensure actions exist
	var actions = [
		"p1_move_up", "p1_move_down", "p1_move_left", "p1_move_right",
		"p1_aim_up", "p1_aim_down", "p1_aim_left", "p1_aim_right",
		"p1_shoot", "p1_torch", "p1_sprint",
		"p2_move_up", "p2_move_down", "p2_move_left", "p2_move_right",
		"p2_aim_up", "p2_aim_down", "p2_aim_left", "p2_aim_right",
		"p2_shoot", "p2_torch", "p2_sprint"
	]
	
	for a in actions:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			InputMap.action_set_deadzone(a, 0.2)
	
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
	
	add_joy_axis.call("p1_shoot", p1_device, JOY_AXIS_TRIGGER_RIGHT, 1.0) # RT
	add_joy_btn.call("p1_shoot", p1_device, JOY_BUTTON_RIGHT_SHOULDER) # RB
	
	add_joy_axis.call("p1_torch", p1_device, JOY_AXIS_TRIGGER_LEFT, 1.0) # LT
	add_joy_btn.call("p1_torch", p1_device, JOY_BUTTON_LEFT_SHOULDER) # LB
	
	add_joy_btn.call("p1_move_up", p1_device, JOY_BUTTON_DPAD_UP)
	add_joy_btn.call("p1_move_down", p1_device, JOY_BUTTON_DPAD_DOWN)
	add_joy_btn.call("p1_move_left", p1_device, JOY_BUTTON_DPAD_LEFT)
	add_joy_btn.call("p1_move_right", p1_device, JOY_BUTTON_DPAD_RIGHT)
	add_joy_btn.call("p1_shoot", p1_device, JOY_BUTTON_A) # Croix
	
	add_joy_btn.call("p1_sprint", p1_device, JOY_BUTTON_LEFT_STICK) # L3
	
	# P2
	add_joy_axis.call("p2_move_left", p2_device, JOY_AXIS_LEFT_X, -1.0)
	add_joy_axis.call("p2_move_right", p2_device, JOY_AXIS_LEFT_X, 1.0)
	add_joy_axis.call("p2_move_up", p2_device, JOY_AXIS_LEFT_Y, -1.0)
	add_joy_axis.call("p2_move_down", p2_device, JOY_AXIS_LEFT_Y, 1.0)
	
	add_joy_axis.call("p2_aim_left", p2_device, JOY_AXIS_RIGHT_X, -1.0)
	add_joy_axis.call("p2_aim_right", p2_device, JOY_AXIS_RIGHT_X, 1.0)
	add_joy_axis.call("p2_aim_up", p2_device, JOY_AXIS_RIGHT_Y, -1.0)
	add_joy_axis.call("p2_aim_down", p2_device, JOY_AXIS_RIGHT_Y, 1.0)
	
	add_joy_axis.call("p2_shoot", p2_device, JOY_AXIS_TRIGGER_RIGHT, 1.0) # RT
	add_joy_btn.call("p2_shoot", p2_device, JOY_BUTTON_RIGHT_SHOULDER) # RB
	
	add_joy_axis.call("p2_torch", p2_device, JOY_AXIS_TRIGGER_LEFT, 1.0) # LT
	add_joy_btn.call("p2_torch", p2_device, JOY_BUTTON_LEFT_SHOULDER) # LB
	
	add_joy_btn.call("p2_move_up", p2_device, JOY_BUTTON_DPAD_UP)
	add_joy_btn.call("p2_move_down", p2_device, JOY_BUTTON_DPAD_DOWN)
	add_joy_btn.call("p2_move_left", p2_device, JOY_BUTTON_DPAD_LEFT)
	add_joy_btn.call("p2_move_right", p2_device, JOY_BUTTON_DPAD_RIGHT)
	add_joy_btn.call("p2_shoot", p2_device, JOY_BUTTON_A) # Croix
	
	add_joy_btn.call("p2_sprint", p2_device, JOY_BUTTON_LEFT_STICK) # L3
