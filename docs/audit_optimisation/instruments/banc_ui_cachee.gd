## « Ce qui calcule sans qu'on le voie » — mesure CPU headless (audit M, protocole de V_V2 § 4, version réduite) — INSTRUMENT TEMPORAIRE,
## jamais commité.
##
## Une manche locale (vue unique, bras « en ligne » : panneau de J2 caché), à pas fixe. Trois temps :
##   A. COMPTEURS — pendant 300 images, le nombre de `theme_changed` reçus par chaque Control sous l'UI ; les nœuds notifiés à presque
##      chaque image ; l'état de `is_processing()` de la galerie, des deux anneaux et du bandeau ; puis, après un retour au hub,
##      `vp1/vp2.render_target_update_mode` (B7) ;
##   B. TEMPS — des blocs de 300 images (après 120 d'échauffement), arms alternés en miroir : T0 témoin ; T2 galerie en sommeil
##      (`set_process(false)`) ; T3 anneaux et bandeau en sommeil ; X « un `update_hud` de plus par image » (le coût marginal du HUD
##      complet) ; X1 « un `update_hud(p1, null, …)` de plus » (le HUD de J1 seul) ; temps = écart d'horloge murale entre deux `process_frame` ;
##   C. MICRO — `Presentation3D._process` appelé 2 000 fois de suite (µs par appel).
##
## godot --headless --path . --fixed-fps 60 --script res://tools/banc_ui_cachee.gd -- --no-eos [--iso=0] [--blocs=4]
extends SceneTree

var _o: Dictionary = {}
var _main: Node = null
var _ui: Node = null
var _n: Dictionary = {}


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


func _brancher(noeud: Node) -> void:
	if noeud is Control:
		var chemin := str(noeud.get_path())
		(noeud as Control).theme_changed.connect(func() -> void: _n[chemin] = int(_n.get(chemin, 0)) + 1)
	for e in noeud.get_children():
		_brancher(e)


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
	var iso := String(_o.get("iso", "1")) != "0"
	root.get_node("GameSettings").mode_iso = iso
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	for _i in 3:
		await process_frame
	_ui = _main.ui
	var modes: Dictionary = (root.get_node("NetworkManager").get_script() as Script).get_script_constant_map()["GameMode"]
	_ui._intended_mode = int(modes["LOCAL_SPLITSCREEN"])
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
	_ui.center_line.hide()
	_main._accorder_rendu_aux_vues()
	_ui.hide_game_over()
	_ui.disposer_hud(false)
	_ui.hud_panneau_p2.visible = false
	var p1: Node = _main.p1
	var p2: Node = _main.p2
	for p: Node in [p1, p2]:
		p.set_physics_process(false)
		p.set("velocity", Vector2.ZERO)
	print("=== CE QUI CALCULE SANS QU'ON LE VOIE — %s, vue unique, bras « en ligne » ===" % ("iso" if iso else "vue de dessus"))
	for _i in 120:
		await process_frame
	# ── A. compteurs
	print("--- A. états ---")
	print("  galerie : is_processing=%s visible_in_tree=%s · p1_cursor %s · p2_cursor %s · match_banner %s" % [str(_ui.map_gallery.is_processing()),
		str(_ui.map_gallery.is_visible_in_tree()), str(_ui.p1_cursor.is_processing()), str(_ui.p2_cursor.is_processing()), str(_ui.match_banner.is_processing())])
	_brancher(_ui)
	var cartes: int = _ui.map_gallery.get_child_count()
	for _i in 300:
		await process_frame
	var lignes: Array = []
	for chemin in _n:
		if int(_n[chemin]) >= 30:
			lignes.append([int(_n[chemin]), chemin])
	lignes.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	print("--- A. theme_changed reçus en 300 images, par Control (≥ 30 ; au total %d nœuds notifiés) ---" % _n.size())
	var total := 0
	for chemin in _n:
		total += int(_n[chemin])
	print("  notifications au total : %d en 300 images, soit %.1f par image" % [total, total / 300.0])
	for k in mini(30, lignes.size()):
		print("  %4d × %s" % [lignes[k][0], String(lignes[k][1]).right(90)])
	_n.clear()
	# ── B. temps : arms alternés en miroir
	var temps := float(_o.get("blocs", "4"))
	var arms := ["T0", "T2", "T3", "X", "X1"]
	var par_arm := {}
	for a in arms:
		par_arm[a] = []
	var cycle: Array = []
	for r in int(temps):
		var ordre := arms.duplicate()
		if r % 2 == 1:
			ordre.reverse()
		cycle.append_array(ordre)
	var tl := 200.0
	var pres_cls: GDScript = load("res://presentation_3d.gd") as GDScript
	for arm in cycle:
		# remise à neuf
		_ui.map_gallery.set_process(true)
		_ui.p1_cursor.set_process(true)
		_ui.p2_cursor.set_process(true)
		_ui.match_banner.set_process(true)
		if arm == "T2":
			_ui.map_gallery.set_process(false)
		elif arm == "T3":
			_ui.p1_cursor.set_process(false)
			_ui.p2_cursor.set_process(false)
			_ui.match_banner.set_process(false)
		for _i in 20:
			await process_frame
		var t_prec := Time.get_ticks_usec()
		var bloc: Array[float] = []
		for _i in 300:
			await process_frame
			if arm == "X":
				_ui.update_hud(p1, p2, tl, true)
			elif arm == "X1":
				_ui.update_hud(p1, null, tl, true)
			var t := Time.get_ticks_usec()
			bloc.append((t - t_prec) / 1000.0)
			t_prec = t
		(par_arm[arm] as Array).append(_moy(bloc))
	print("--- B. temps d'une image (ms, horloge murale), moyennes de blocs de 300 images, %d blocs par arm en miroir ---" % int(temps))
	var t0: float = _moy(par_arm["T0"])
	for a in arms:
		var v: Array = par_arm[a]
		var s := PackedStringArray()
		for x in v:
			s.append("%.3f" % x)
		print("  %-3s moyenne %.3f ms · médiane des blocs %.3f · écart au témoin %+.3f ms   [blocs : %s]" % [a, _moy(v), _med(v), _moy(v) - t0, " ".join(s)])
	print("  lecture : X − T0 = le coût d'UN `update_hud` complet de plus par image ; X1 − T0 = celui du seul HUD de J1 ; T2 − T0 et T3 − T0 négatifs = ce que le sommeil rend")
	print("  la galerie compte %d enfants (cartes + gabarit) ; les 6 cartes livrées sont dans MapData.list_maps()" % cartes)
	# ── C. micro : Presentation3D._process ×2000
	var pres: Node = pres_cls.call("instance")
	if pres != null:
		var t_a := Time.get_ticks_usec()
		for _i in 2000:
			pres._process(0.0167)
		var us := (Time.get_ticks_usec() - t_a) / 2000.0
		print("--- C. Presentation3D._process : %.1f µs par appel (2 000 appels de suite) ---" % us)
	# ── A (suite). le hub : vp1 / vp2
	_main._on_main_menu_requested()
	for _i in 6:
		await process_frame
	var m1 := int(_main.vp1.render_target_update_mode)
	var m2 := int(_main.vp2.render_target_update_mode)
	print("--- A. au hub (après `_on_main_menu_requested`) : vp1.render_target_update_mode=%d vp2=%d (0 DISABLED, 4 ALWAYS) ---" % [m1, m2])
	quit(0)
