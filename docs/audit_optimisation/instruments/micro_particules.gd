## Le coût d'une particule (audit M, vérification de V3 / JOU-01, JOU-03, JOU-04) — micro-banc CPU headless, INSTRUMENT TEMPORAIRE.
##
## Le vrai jeu monté (iso, vue unique), J1 et J2 immobiles, puis, pour N dans {0, 25, 50, 100, 200} particules de sang (ou d'étincelles,
## `--kind=spark`), répété `--tours` fois :
##   - le coût de l'APPEL `ParticlePool.emit(...)` (µs par particule émise) ;
##   - le coût de `ParticlePool.advance(0.0)` appelé à la main sur les N actives (µs par particule : la boucle GDScript avec `Charte.courbe`,
##     deux `get_node`, l'échelle et l'énergie de lumière) ;
##   - le coût PERMANENT d'une image tant que les N particules vivent (écart d'horloge entre deux `process_frame`, images 5 à 35 après
##     l'émission, moins le fond mesuré juste avant) : µs par particule ACTIVE et par image — advance + physique des corps rigides + le reste.
##
## godot --headless --path . --fixed-fps 60 --script res://tools/micro_particules.gd -- --no-eos [--kind=blood|spark] [--tours=5]
extends SceneTree

var _o: Dictionary = {}
var _main: Node = null


func _init() -> void:
	call_deferred("_run")


func _options() -> Dictionary:
	var o := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if not s.begins_with("--"):
			continue
		var i := s.find("=")
		if i < 0:
			o[s.substr(2)] = "1"
		else:
			o[s.substr(2, i - 2)] = s.substr(i + 1)
	return o


static func _moy(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / a.size()


static func _med(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var t := a.duplicate()
	t.sort()
	return float(t[t.size() / 2])


func _frames(n: int) -> Array[float]:
	var out: Array[float] = []
	var t0 := Time.get_ticks_usec()
	for _i in n:
		await process_frame
		var t := Time.get_ticks_usec()
		out.append((t - t0) / 1000.0)
		t0 = t
	return out


func _run() -> void:
	_o = _options()
	await process_frame
	var f0 := Engine.get_physics_frames()
	for _i in 30:
		await process_frame
	if absi(int(Engine.get_physics_frames() - f0) - 30) > 1:
		printerr("✗ l'horloge n'est pas fixe : lancer avec --fixed-fps 60")
		quit(1)
		return
	var kind_nom := String(_o.get("kind", "blood"))
	var tours := int(_o.get("tours", "5"))
	root.get_node("GameSettings").mode_iso = true
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	for _i in 3:
		await process_frame
	var ui: Node = _main.ui
	var modes: Dictionary = (root.get_node("NetworkManager").get_script() as Script).get_script_constant_map()["GameMode"]
	ui._intended_mode = int(modes["LOCAL_SPLITSCREEN"])
	_main._on_replay_requested()
	var n := 0
	while not (bool(_main.round_active) and float(_main.countdown_left) <= 0.0):
		await process_frame
		n += 1
		if n > 1200:
			printerr("✗ la manche n'a pas démarré")
			quit(1)
			return
	_main.vp2.get_parent().hide()
	_main.ui.center_line.hide()
	_main._accorder_rendu_aux_vues()
	var cls: GDScript = load("res://presentation_3d.gd") as GDScript
	var pres: Node = null
	for _i in 300:
		await process_frame
		pres = cls.call("instance")
		if pres != null and bool(pres.get("_actif")):
			break
	if pres == null or not bool(pres.get("_actif")):
		printerr("✗ la vue iso ne tient pas")
		quit(1)
		return
	for p: Node2D in [_main.p1, _main.p2]:
		p.set_physics_process(false)
		p.set("velocity", Vector2.ZERO)
		p.set("dazzle_amount", 0.0)
	var pool: Node = _main.particle_pool
	var kind: int = 0 if kind_nom == "blood" else 1
	var pos: Vector2 = (_main.p1 as Node2D).global_position + Vector2(0.0, 60.0)
	print("=== LE COÛT D'UNE PARTICULE — %s, %d tours, iso, headless ===" % [kind_nom, tours])
	print("  capacité de la réserve %d, plafond d'actives %d" % [int(pool.get_script().get_script_constant_map()["CAPACITY"]), int(pool.get_script().get_script_constant_map()["MAX_ACTIVE"])])
	var tailles := [0, 25, 50, 100, 200]
	var res := {}
	for tour in tours:
		for taille in tailles:
			pool.clear_all()
			for _i in 20:
				await process_frame
			var fond: Array[float] = await _frames(30)
			var fond_med := _med(fond)
			var t0 := Time.get_ticks_usec()
			if taille > 0:
				pool.emit(kind, pos, Color(0.6, 0.0, 0.0) if kind == 0 else Color(1.0, 0.8, 0.3), taille, 80.0, 260.0, Vector2.RIGHT, 360.0)
			var t1 := Time.get_ticks_usec()
			var actives: int = int(pool.active_count())
			var d: Array[float] = await _frames(36)
			var fenetre: Array[float] = d.slice(5, 36)
			# advance() à la main : N particules, delta 0 (rien ne vieillit, la boucle tourne en entier)
			var a0 := Time.get_ticks_usec()
			for _k in 50:
				pool.advance(0.0)
			var a1 := Time.get_ticks_usec()
			var cle := str(taille)
			if not res.has(cle):
				res[cle] = {"emit": [], "adv": [], "perm": [], "fond": [], "actives": []}
			(res[cle]["emit"] as Array).append((t1 - t0) / maxf(1.0, float(taille)))
			(res[cle]["adv"] as Array).append((a1 - a0) / 50.0 / maxf(1.0, float(actives)))
			(res[cle]["perm"] as Array).append((_moy(fenetre) - fond_med) * 1000.0 / maxf(1.0, float(actives)))
			(res[cle]["fond"] as Array).append(fond_med)
			(res[cle]["actives"] as Array).append(actives)
	print("  N émis · actives · fond (ms) · émission µs/particule · advance(0) µs/particule · PERMANENT µs/particule/image (images 5-35)  [médianes sur %d tours]" % tours)
	for taille in tailles:
		var r: Dictionary = res[str(taille)]
		print("  %3d · %3d · %.2f · %6.1f · %6.1f · %6.1f" % [taille, int(_med(r["actives"])), _med(r["fond"]), _med(r["emit"]), _med(r["adv"]), _med(r["perm"])])
	quit(0)
