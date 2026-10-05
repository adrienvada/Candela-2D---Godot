## Preuve indépendante du matériel pour « le plancher d'auto-éblouissement » (audit M, demande de V8 § 1.4) — INSTRUMENT TEMPORAIRE.
##
## Le vrai jeu monté en headless (iso, vue unique, manche locale), torche de J1 allumée, J1 et J2 au repos : l'état de l'appareil de brouillage
## de la vue (`_flou`, `_copie`, `_halo` de chaque `BrouillageVue`), du voile d'éblouissement (visibilité, modulation, shader, niveau), le niveau
## d'éblouissement de J1 et de J2, puis le décompte de ce qui, dans l'arbre, DEMANDE à l'écran d'être relu : `BackBufferCopy` visibles et
## `CanvasItem` visibles dont le shader lit `hint_screen_texture`. Ce sont des FAITS DE GRAPHE : ils ne dépendent ni du GPU ni du pilote, et
## c'est ce qui coupe une passe de rendu sur un GPU à tuiles (le Mac) que llvmpipe ne montre pas.
##
## godot --headless --path <arbre> --fixed-fps 60 --script res://tools/preuve_flou.gd -- --no-eos [--iso=1|0] [--sans-torche=1]
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


func _lit_l_ecran(n: CanvasItem) -> bool:
	var m: Material = n.material
	if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
		return (m as ShaderMaterial).shader.code.contains("hint_screen_texture")
	return false


func _visible_vraiment(n: CanvasItem) -> bool:
	# visible dans l'arbre ET modulation au-dessus du seuil où le moteur écarte l'item du dessin
	return n.is_visible_in_tree() and n.modulate.a >= 0.007 and n.self_modulate.a >= 0.007


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
	if iso:
		var cls: GDScript = load("res://presentation_3d.gd") as GDScript
		for _i in 300:
			await process_frame
			var pres: Node = cls.call("instance")
			if pres != null and bool(pres.get("_actif")):
				break
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	# Les torches par la GÂCHETTE, comme le banc de cadence du projet (`BenchFramerate.tenir_la_torche`) : `Input.action_press` sur l'action du
	# fournisseur d'entrées, que le pas de physique suivant lit comme un doigt. Les joueurs gardent leur physique (c'est elle qui pose
	# `dazzle_amount` : la rétrodiffusion de la propre torche, 0,06) ; personne n'appuie sur un déplacement, ils restent immobiles.
	if String(_o.get("sans-torche", "0")) != "1":
		for p: Node2D in [p1, p2]:
			var fournisseur: Variant = p.get("input_provider")
			if fournisseur != null and "action_torch" in fournisseur and InputMap.has_action(String(fournisseur.action_torch)):
				Input.action_press(String(fournisseur.action_torch), LocalInputProvider.TORCH_CRAN_FOND * 0.5)
	for _i in 180:
		await process_frame
	print("=== PREUVE DU PLANCHER D'AUTO-ÉBLOUISSEMENT — %s, vue unique, repos, torche de J1 %s ===" % ["iso" if iso else "vue de dessus",
		"éteinte" if String(_o.get("sans-torche", "0")) == "1" else "allumée"])
	print("  J1 : flashlight_on=%s dazzle_amount=%.4f · J2 : flashlight_on=%s dazzle_amount=%.4f" % [str(p1.get("flashlight_on")), float(p1.get("dazzle_amount")),
		str(p2.get("flashlight_on")), float(p2.get("dazzle_amount"))])
	# ── l'appareil de brouillage de chaque vue
	var nb_vue := 0
	for nd in root.find_children("*", "Node", true, false):
		var sc: Script = nd.get_script()
		if sc != null and String(sc.resource_path).ends_with("brouillage_vue.gd"):
			nb_vue += 1
			var flou: ColorRect = nd.get("_flou")
			var copie: BackBufferCopy = nd.get("_copie")
			var halo: TextureRect = nd.get("_halo")
			var mat: ShaderMaterial = nd.get("_mat_flou")
			print("  BrouillageVue %s : _flou.visible=%s · _copie.visible=%s · _halo.visible=%s · force=%s rayon_noyau=%s · dans l'arbre : flou %s copie %s halo %s" % [
				str(nd.get_path()).right(60), str(flou.visible), str(copie.visible), str(halo.visible),
				str(mat.get_shader_parameter("force")), str(mat.get_shader_parameter("rayon_noyau")),
				str(flou.is_visible_in_tree()), str(copie.is_visible_in_tree()), str(halo.is_visible_in_tree())])
	print("  appareils de brouillage trouvés : %d" % nb_vue)
	# ── le voile d'éblouissement
	for nd in root.find_children("*", "ColorRect", true, false):
		if nd.has_meta("voile_plein") or nd.has_meta("voile_calme"):
			var cr := nd as ColorRect
			var mat2: ShaderMaterial = cr.material as ShaderMaterial
			var calme: ShaderMaterial = cr.get_meta("voile_calme", null)
			print("  Voile %s : visible=%s modulate.a=%.2f · matériau %s · niveau=%s · dessiné vraiment=%s" % [str(cr.get_path()).right(48), str(cr.visible), cr.modulate.a,
				"CALME" if mat2 == calme else "PLEIN", str(mat2.get_shader_parameter("niveau")) if mat2 != null else "—", str(_visible_vraiment(cr))])
	# ── ce qui demande à l'écran d'être relu
	var copies := 0
	var liseurs := 0
	var noms_copies := PackedStringArray()
	var noms_liseurs := PackedStringArray()
	for nd in root.find_children("*", "BackBufferCopy", true, false):
		if (nd as CanvasItem).is_visible_in_tree():
			copies += 1
			noms_copies.append(str(nd.get_path()).get_file())
	for nd in root.find_children("*", "CanvasItem", true, false):
		var ci := nd as CanvasItem
		if _lit_l_ecran(ci) and _visible_vraiment(ci):
			liseurs += 1
			noms_liseurs.append(str(ci.get_path()).get_file())
	print("  BackBufferCopy visibles dans l'arbre : %d %s" % [copies, str(noms_copies)])
	print("  CanvasItem VISIBLES (modulation ≥ 0,007) dont le shader lit `hint_screen_texture` : %d %s" % [liseurs, str(noms_liseurs)])
	quit(0)
