extends Node2D

var _drops = []
var color = Color(0.5, 0.0, 0.0, 0.9) # Dark dried blood

func setup(base_pos: Vector2, direction: Vector2):
	position = base_pos
	z_index = -1 # Draw under players
	
	# Receive hit lights and ambient player lights
	# Corresponds to Layer 1 (1), Layer 5 (16), Layer 6 (32)
	light_mask = 1 | 16 | 32
	
	# Generate random splash drops along the trajectory
	var num_drops = randi_range(15, 30)
	
	# Central impact pool
	_drops.append({
		"pos": Vector2.ZERO,
		"radius": randf_range(4.0, 8.0)
	})
	
	# Directional splatter
	for i in range(num_drops):
		var dist = randf_range(5.0, 70.0)
		var angle = direction.angle() + randf_range(-PI/5, PI/5)
		
		# Narrower spread for drops that go further (looks more realistic)
		if dist > 30.0:
			angle = direction.angle() + randf_range(-PI/10, PI/10)
			
		var r = randf_range(1.0, 5.0) * (1.0 - (dist / 80.0))
		
		_drops.append({
			"pos": Vector2(cos(angle), sin(angle)) * dist,
			"radius": max(1.0, r)
		})
	
	queue_redraw()

func _draw():
	for d in _drops:
		draw_circle(d["pos"], d["radius"], color)
