## V1b-N1 — « le préchauffage de la suie et de la poussière est-il inopérant ? » — mesure CPU headless (audit M, 2026-10-05).
## INSTRUMENT TEMPORAIRE, jamais commité.
##
## Le vrai jeu monté (main.tscn, vue iso par défaut), une manche locale, J1 et J2 immobiles ; on pose, par le vrai geste du jeu
## (`GameState._do_spawn_gadget`, le chemin du RPC), le gadget `--slug` (poussiere | cartouche_suie) plusieurs fois de suite, chaque
## nuage vivant jusqu'à sa mort naturelle (7,5 s / 9 s de jeu) avant la pose suivante — comme le fait une manche (recharge de 60 s).
## À chaque pose : le coût de l'appel, les durées des 40 images qui suivent (horloge murale entre deux `process_frame`), la taille
## des caches `_aplats` / `_reliefs`, la mémoire statique, et si la texture source était encore en cache AVANT la pose.
##
##   --slug=poussiere|cartouche_suie  --classe=pompe|fumiste  --poses=4
##   --tenue=1   ÉMULE LE CORRECTIF (une ligne) : les deux textures sources sont tenues vivantes pendant toute la mesure, et leurs
##               aplat / relief sont calculés UNE fois (ce que ferait `prechauffer()` avec une variable statique) avant les poses
##   --double=1  en fin de série, J1 pose, puis J2 pose le même gadget pendant que celui de J1 vit (texture partagée : doit toucher)
##   --iso=1|0   (1 par défaut)
##
## godot --headless --path . --fixed-fps 60 --script res://tools/mesure_nuage.gd -- --no-eos --slug=poussiere --classe=pompe
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


static func _quantile(a: Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var t := a.duplicate()
	t.sort()
	return float(t[clampi(int(floor(q * (t.size() - 1) + 0.5)), 0, t.size() - 1)])


static func _maxi(a: Array) -> float:
	var m := 0.0
	for x in a:
		m = maxf(m, float(x))
	return m


## Les durées (ms) de `n` images consécutives, mesurées entre deux émissions de `process_frame`.
func _frames(n: int) -> Array[float]:
	var out: Array[float] = []
	var t0 := Time.get_ticks_usec()
	for _i in n:
		await process_frame
		var t := Time.get_ticks_usec()
		out.append((t - t0) / 1000.0)
		t0 = t
	return out


func _chemin(slug: String) -> String:
	# `GadgetProfile.chemin_sprite_de(piece)` : « gadget_<piece>.png » ; la pièce de la suie est « cartouche_suie ».
	return "res://assets/sprites/gadget_%s.png" % slug


func _caches() -> String:
	return "_aplats=%d _reliefs=%d _planches=%d" % [IsoNuageVoxel._aplats.size(), IsoNuageVoxel._reliefs.size(), IsoNuageVoxel._planches.size()]


func _mem_mo() -> float:
	return Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0


func _nuages_3d(pres: Node) -> int:
	if pres == null:
		return 0
	return pres.find_children("NuageVoxel*", "MultiMeshInstance3D", true, false).size()


func _gadgets_vivants() -> int:
	var n := 0
	for g in get_nodes_in_group("gadgets"):
		if is_instance_valid(g) and not g.is_queued_for_deletion():
			n += 1
	return n


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
	var slug := String(_o.get("slug", "poussiere"))
	var classe := String(_o.get("classe", "pompe"))
	var poses := int(_o.get("poses", "4"))
	var tenue := String(_o.get("tenue", "0")) == "1"
	var iso := String(_o.get("iso", "1")) != "0"
	print("=== V1b-N1 — pose de « %s » (classe %s), %d poses, vue %s, textures sources %s ===" % [slug, classe, poses,
		"iso" if iso else "de dessus", "TENUES (correctif émulé)" if tenue else "non tenues (état du dépôt)"])
	root.get_node("GameSettings").mode_iso = iso
	var t_mont := Time.get_ticks_usec()
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	for _i in 3:
		await process_frame
	print("main.tscn monté en %.0f ms (headless, vue %s)" % [(Time.get_ticks_usec() - t_mont) / 1000.0, "iso" if iso else "de dessus"])
	var ui: Node = _main.ui
	var modes: Dictionary = (root.get_node("NetworkManager").get_script() as Script).get_script_constant_map()["GameMode"]
	ui._intended_mode = int(modes["LOCAL_SPLITSCREEN"])
	var idx := -1
	for i in _main.classes().size():
		if String(_main.classes()[i].slug()) == classe:
			idx = i
	if idx < 0:
		printerr("✗ classe introuvable : %s" % classe)
		quit(1)
		return
	ui.set_weapon_selection(0, idx)
	ui.set_weapon_selection(1, idx)
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
	var pres: Node = null
	if iso:
		var cls: GDScript = load("res://presentation_3d.gd") as GDScript
		for _i in 300:
			await process_frame
			pres = cls.call("instance")
			if pres != null and bool(pres.get("_actif")):
				break
		if pres == null or not bool(pres.get("_actif")):
			printerr("✗ la vue iso ne tient pas")
			quit(1)
			return
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	for p: Node2D in [p1, p2]:
		p.set_physics_process(false)
		p.set("velocity", Vector2.ZERO)
		p.set("dazzle_amount", 0.0)
	# ── 0. l'état après le montage (le préchauffage a tourné : `IsoVolumes._init` → `IsoNuageVoxel.prechauffer()`)
	print("--- 0. état après le montage ---")
	print("  IsoNuageVoxel : _prechauffe=%s · shader_charge=%s · %s" % [str(IsoNuageVoxel._prechauffe), str(IsoNuageVoxel.shader_charge()), _caches()])
	for nom in ["cartouche_suie", "poussiere"]:
		var c := _chemin(nom)
		print("  %s : ResourceLoader.has_cached = %s" % [c.get_file(), str(ResourceLoader.has_cached(c))])
	var tenues: Array = []
	if tenue:
		print("--- 0b. correctif émulé : textures tenues + aplat/relief calculés une fois ---")
		for nom in ["cartouche_suie", "poussiere"]:
			var t := load(_chemin(nom)) as Texture2D
			tenues.append(t)
			var a0 := Time.get_ticks_usec()
			IsoNuageVoxel.aplat(t)
			var a1 := Time.get_ticks_usec()
			IsoNuageVoxel.relief(t)
			var a2 := Time.get_ticks_usec()
			print("  %s %dx%d : aplat %.1f ms · relief %.1f ms (une fois, au lancement)" % [nom, t.get_width(), t.get_height(), (a1 - a0) / 1000.0, (a2 - a1) / 1000.0])
		print("  %s" % _caches())
	# ── 1. la base : images sans gadget
	for _i in 60:
		await process_frame
	var base: Array[float] = await _frames(180)
	var base_med := _quantile(base, 0.5)
	print("--- 1. base : 180 images sans gadget — moyenne %.2f ms · médiane %.2f · p99 %.2f · max %.2f ---" % [_moy(base), base_med, _quantile(base, 0.99), _maxi(base)])
	# ── 2. les poses successives
	var pos: Vector2 = p1.global_position + Vector2(140.0, 0.0)
	print("--- 2. poses successives de « %s » par J1 (chacune laissée vivre jusqu'à sa mort naturelle) ---" % slug)
	print("  colonnes : pose · appel (ms) · images suivantes d0..d5 (ms) · max des 40 · surcoût total sur 40 images (ms) · caches avant → après · mém. statique après la mort (Mo) · texture source en cache avant la pose · nuages 3D")
	var mem_morts: Array[float] = []
	var surcouts: Array[float] = []
	var appels: Array[float] = []
	var pics: Array[float] = []
	for k in poses:
		var en_cache := ResourceLoader.has_cached(_chemin(slug))
		var avant := _caches()
		var t0 := Time.get_ticks_usec()
		_main._do_spawn_gadget(0, pos, 0.0, slug, 9000 + k, 12345 + k)
		var t1 := Time.get_ticks_usec()
		var d: Array[float] = await _frames(40)
		var apres := _caches()
		var vivants := _gadgets_vivants()
		var nu := _nuages_3d(pres)
		var tot := 0.0
		for x in d:
			tot += maxf(0.0, float(x) - base_med)
		var d6 := PackedStringArray()
		for i in 6:
			d6.append("%.1f" % d[i])
		print("  pose %d : appel %.2f ms · d0..d5 = [%s] · max %.1f (à l'image %d) · surcoût 40 images %.1f ms · %s → %s · gadgets vivants %d · nuages 3D %d · texture en cache avant = %s" % [
			k + 1, (t1 - t0) / 1000.0, ", ".join(d6), _maxi(d), d.find(_maxi(d)), tot, avant, apres, vivants, nu, str(en_cache)])
		appels.append((t1 - t0) / 1000.0)
		pics.append(_maxi(d))
		surcouts.append(tot)
		# la mort naturelle (7,5 s / 9 s de jeu), puis un temps de repos : la mémoire se lit sans nuage vivant
		var m := 0
		while _gadgets_vivants() > 0 and m < 2000:
			await process_frame
			m += 1
		for _i in 40:
			await process_frame
		mem_morts.append(_mem_mo())
		print("    mort après %d images · nuages 3D restants %d · mém. statique %.2f Mo · %s" % [m, _nuages_3d(pres), _mem_mo(), _caches()])
	var diffs := PackedStringArray()
	for k in range(1, mem_morts.size()):
		diffs.append("%+.2f" % (mem_morts[k] - mem_morts[k - 1]))
	print("  mémoire statique, d'une pose à la suivante (Mo) : %s" % ", ".join(diffs))
	# ── 3. J1 puis J2, le même gadget, le premier encore vivant
	if String(_o.get("double", "0")) == "1":
		print("--- 3. J1 pose, 20 images plus tard J2 pose le même gadget (celui de J1 vit encore : la texture est la même instance) ---")
		var en_cache1 := ResourceLoader.has_cached(_chemin(slug))
		var ta := Time.get_ticks_usec()
		_main._do_spawn_gadget(0, pos, 0.0, slug, 9100, 777)
		var tb := Time.get_ticks_usec()
		var da: Array[float] = await _frames(20)
		print("  J1 : appel %.2f ms · max des 20 images suivantes %.1f ms · caches %s · texture en cache avant = %s" % [(tb - ta) / 1000.0, _maxi(da), _caches(), str(en_cache1)])
		var en_cache2 := ResourceLoader.has_cached(_chemin(slug))
		var tc := Time.get_ticks_usec()
		_main._do_spawn_gadget(1, p2.global_position + Vector2(-140.0, 0.0), 0.0, slug, 9101, 778)
		var td := Time.get_ticks_usec()
		var db: Array[float] = await _frames(40)
		var d6b := PackedStringArray()
		for i in 6:
			d6b.append("%.1f" % db[i])
		print("  J2 : appel %.2f ms · d0..d5 = [%s] · max des 40 images %.1f ms · caches %s · texture en cache avant = %s · gadgets vivants %d" % [
			(td - tc) / 1000.0, ", ".join(d6b), _maxi(db), _caches(), str(en_cache2), _gadgets_vivants()])
	# ── 4. le micro : le prix d'un MANQUE de cache (instance neuve) et d'une TOUCHE, sans le jeu autour
	print("--- 4. micro : aplat() et relief() sur une instance NEUVE de la texture (clé absente : le cas de chaque pose), puis sur la même (clé présente) ---")
	for nom in ["poussiere", "cartouche_suie"]:
		for rep in 3:
			var t := ResourceLoader.load(_chemin(nom), "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
			var a0 := Time.get_ticks_usec()
			IsoNuageVoxel.aplat(t)
			var a1 := Time.get_ticks_usec()
			IsoNuageVoxel.relief(t)
			var a2 := Time.get_ticks_usec()
			IsoNuageVoxel.aplat(t)
			IsoNuageVoxel.relief(t)
			var a3 := Time.get_ticks_usec()
			print("  %-15s %dx%d (%d px) essai %d : MANQUE aplat %.1f ms + relief %.1f ms = %.1f ms · TOUCHE aplat+relief %.4f ms" % [nom, t.get_width(), t.get_height(),
				t.get_width() * t.get_height(), rep + 1, (a1 - a0) / 1000.0, (a2 - a1) / 1000.0, (a2 - a0) / 1000.0, (a3 - a2) / 1000.0])
	print("=== fin ===")
	quit(0)
