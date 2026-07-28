extends Node2D

var _drops = []
var color = Color(0.5, 0.0, 0.0, 0.9) # Dark dried blood

func setup(base_pos: Vector2, direction: Vector2):
	position = base_pos
	z_index = 1 # Draw above ground (0), under killcam (2) and players (10)
	
	# P1 Viewport (2): torch (1) + P1 ambient (16)
	visibility_layer = 2
	light_mask = 1 | 16
	
	# Apply liquid blood shader
	material = ShaderMaterial.new()
	material.shader = preload("res://blood_shader.gdshader")
	
	# Generate random splash drops along the trajectory
	var num_drops = randi_range(15, 30)
	
	# Central impact pool
	_drops.append({
		"pos": Vector2.ZERO,
		"radius": randf_range(5.0, 10.0)
	})
	
	# Directional splatter
	for i in range(num_drops):
		var dist = randf_range(5.0, 70.0)
		var angle = direction.angle() + randf_range(-PI/5, PI/5)
		
		# Narrower spread for drops that go further
		if dist > 30.0:
			angle = direction.angle() + randf_range(-PI/10, PI/10)
			
		var r = randf_range(1.5, 6.0) * (1.0 - (dist / 80.0))
		
		_drops.append({
			"pos": Vector2(cos(angle), sin(angle)) * dist,
			"radius": max(1.0, r)
		})
	
	queue_redraw()

func _draw():
	# Draw red edge
	for d in _drops:
		draw_circle(d["pos"], d["radius"], Color(0.6, 0.0, 0.0, 0.8))
	# Draw dark glossy center
	for d in _drops:
		draw_circle(d["pos"], max(d["radius"] - 1.5, 0.0), Color(0.05, 0.0, 0.0, 0.95))

func _ready():
	call_deferred("_create_p2_duplicate")

func _create_p2_duplicate():
	if get_parent() and not is_in_group("blood_p2"):
		var stain_p2 = duplicate()
		stain_p2.add_to_group("blood_p2")
		stain_p2.visibility_layer = 4 # P2 Viewport
		stain_p2.light_mask = 1 | 32  # Torch (1) + P2 Ambient (32)
		get_parent().add_child(stain_p2)

