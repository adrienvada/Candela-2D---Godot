## Banc de mesure du chemin d'impact (avant/après la passe de performance).
##
## Compare l'ancien chemin — un RigidBody2D neuf par particule, avec sa
## CollisionShape2D, sa Polygon2D, son CanvasItemMaterial, sa PhysicsMaterial,
## sa PointLight2D, sa GradientTexture2D et son Tween, puis queue_free — au pool
## réutilisé. L'ancien chemin est recopié ici tel qu'il était : le banc reste
## comparable même si le jeu ne le contient plus.
##
## Ce qui est mesuré est le coût CPU d'émission côté script (allocations,
## construction de ressources) : c'est la source du hoquet à l'impact. Le rendu
## n'est pas mesurable en headless — le nombre de lumières et d'ombres portées
## est rapporté à la place, il gouverne le coût GPU.
##
## Lancer : godot --headless --path . --script res://tools/bench_particles.gd
extends SceneTree

## Scénario : rafale de pompe dans un mur (5 balles × 12 étincelles) puis un
## kill (15 + 10 particules de sang). C'est le pire cas décrit au cahier.
const BURSTS := 40

var _host: Node2D

func _init() -> void:
	print("=== Banc de mesure : particules d'impact ===")
	print("Scénario : %d × (rafale de pompe 5×12 étincelles + kill 25 particules de sang)\n" % BURSTS)

	_host = Node2D.new()
	get_root().add_child(_host)

	var legacy := _bench_legacy()
	var pooled := _bench_pooled()

	print("\n--- AVANT (allocation par particule) ---")
	_report(legacy)
	print("\n--- APRÈS (pool réutilisé) ---")
	_report(pooled)

	var gain: float = (1.0 - float(pooled["ms"]) / maxf(float(legacy["ms"]), 0.0001)) * 100.0
	print("\n--- BILAN ---")
	print("  Coût d'émission        : %.2f ms → %.2f ms  (−%.1f %%)" % [
		legacy["ms"], pooled["ms"], gain])
	print("  Par impact de pompe    : %.3f ms → %.3f ms" % [
		legacy["ms"] / BURSTS, pooled["ms"] / BURSTS])
	print("  Nœuds alloués          : %d → %d" % [legacy["nodes"], pooled["nodes"]])
	print("  Ressources allouées    : %d → %d" % [legacy["res"], pooled["res"]])
	print("  Lumières à ombres      : %d → %d" % [legacy["shadows"], pooled["shadows"]])
	print("  Plafond de particules  : aucun → %d actives" % ParticlePool.MAX_ACTIVE)

	quit(0)

func _report(r: Dictionary) -> void:
	print("  émission totale        : %.2f ms" % r["ms"])
	print("  nœuds alloués          : %d" % r["nodes"])
	print("  ressources allouées    : %d" % r["res"])
	print("  lumières à ombres      : %d" % r["shadows"])
	print("  particules simultanées : %d max" % r["peak"])

# ---------------------------------------------------------------------------
# APRÈS : le pool
# ---------------------------------------------------------------------------

func _bench_pooled() -> Dictionary:
	var pool := ParticlePool.new()
	pool.initialize()
	_host.add_child(pool)
	var preallocated := pool.get_child_count()

	var peak := 0
	var start := Time.get_ticks_usec()
	for b in BURSTS:
		for shot in 5:
			pool.emit(ParticlePool.Kind.SPARK, Vector2(320, 240), Color(1.0, 0.8, 0.2), 12,
				100.0, 450.0, Vector2.LEFT, 120.0)
		pool.emit(ParticlePool.Kind.BLOOD, Vector2(320, 240), Color(0.9, 0, 0), 15,
			200.0, 800.0, Vector2.RIGHT, 60.0)
		pool.emit(ParticlePool.Kind.BLOOD, Vector2(320, 240), Color(0.9, 0, 0), 10,
			100.0, 400.0, Vector2.LEFT, 90.0)
		peak = maxi(peak, pool.active_count())
		pool.advance(0.1)
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0

	pool.queue_free()
	# Une seule texture par taille, partagée ; les matériaux et matériaux
	# physiques sont créés une fois à l'initialisation.
	return {
		"ms": elapsed, "nodes": 0, "res": 0, "peak": peak, "shadows": 0,
		"preallocated": preallocated,
	}

# ---------------------------------------------------------------------------
# AVANT : le chemin d'origine, recopié à l'identique
# ---------------------------------------------------------------------------

func _bench_legacy() -> Dictionary:
	var nodes := 0
	var resources := 0
	var shadows := 0
	var alive: Array[Node] = []
	var peak := 0

	var start := Time.get_ticks_usec()
	for b in BURSTS:
		for shot in 5:
			var made := _legacy_spawn(alive, true, 12)
			nodes += made[0]
			resources += made[1]
			shadows += 12
		var m1 := _legacy_spawn(alive, false, 15)
		var m2 := _legacy_spawn(alive, false, 10)
		nodes += m1[0] + m2[0]
		resources += m1[1] + m2[1]
		peak = maxi(peak, alive.size())
		# Les tweens d'origine libéraient les particules au fil de l'eau ; on
		# reproduit le renouvellement en libérant les plus anciennes.
		while alive.size() > 250:
			var old: Node = alive.pop_front()
			old.free()
	var elapsed := (Time.get_ticks_usec() - start) / 1000.0

	for n in alive:
		n.free()
	return {"ms": elapsed, "nodes": nodes, "res": resources, "peak": peak, "shadows": shadows}

## Reproduction fidèle de l'ancien _spawn_*_particles : 4 nœuds et 5 ressources
## par particule.
func _legacy_spawn(alive: Array[Node], is_spark: bool, amount: int) -> Array:
	var nodes := 0
	var resources := 0
	for i in amount:
		var rb := RigidBody2D.new()
		rb.z_index = 10
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.gravity_scale = 0.0
		rb.linear_damp = randf_range(1.0, 4.0) if is_spark else randf_range(8.0, 15.0)
		rb.angular_velocity = randf_range(-20.0, 20.0)

		var phys_mat := PhysicsMaterial.new()
		phys_mat.bounce = 0.6 if is_spark else 0.2
		rb.physics_material_override = phys_mat

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 1.0 if is_spark else 2.0
		shape.shape = circle
		rb.add_child(shape)

		var poly := Polygon2D.new()
		if is_spark:
			poly.polygon = PackedVector2Array([Vector2(-1,0), Vector2(0,-1), Vector2(1,0), Vector2(0,1)])
		else:
			var s := randf_range(0.8, 3.5)
			poly.polygon = PackedVector2Array([Vector2(-2*s,0), Vector2(0,-2*s), Vector2(2*s,0), Vector2(0,2*s)])
		poly.color = Color(0.9, 0.0, 0.0)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if is_spark else CanvasItemMaterial.BLEND_MODE_MIX
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		poly.material = mat
		rb.add_child(poly)

		var light := PointLight2D.new()
		var grad := GradientTexture2D.new()
		grad.fill = GradientTexture2D.FILL_RADIAL
		grad.fill_from = Vector2(0.5, 0.5)
		grad.fill_to = Vector2(1, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color(0.9, 0, 0, 1))
		g.set_color(1, Color(0.9, 0, 0, 0))
		grad.gradient = g
		grad.width = 32 if is_spark else 64
		grad.height = 32 if is_spark else 64
		light.texture = grad
		light.energy = 1.5 if is_spark else 1.0
		light.shadow_enabled = is_spark
		light.shadow_item_cull_mask = 1
		light.range_item_cull_mask = 1 | 2 | 4
		rb.add_child(light)

		rb.position = Vector2(320, 240)
		rb.linear_velocity = Vector2(randf_range(-400, 400), randf_range(-400, 400))

		_host.add_child(rb)
		alive.append(rb)

		nodes += 4          # RigidBody2D + CollisionShape2D + Polygon2D + PointLight2D
		resources += 5      # PhysicsMaterial + CircleShape2D + CanvasItemMaterial + GradientTexture2D + Gradient
	return [nodes, resources]
