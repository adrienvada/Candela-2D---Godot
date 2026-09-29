extends SceneTree

## Le banc d'images du chantier des lumières de la 0.8.0 (L1 portée, L2 la lampe du modèle, L3 le point lumineux).
##
## Monte une vraie partie (vue iso, 45° B), en écran scindé puis en vue unique, pose les deux joueurs et leur visée
## par des marionnettes (le fournisseur d'entrées du jeu, comme le photographe), tient la scène jusqu'à ce que les
## caméras ne bougent plus, et photographie la fenêtre. Adrien juge sur image : c'est pour lui.
##
## ⚠️ Écrit pour tourner AUSSI sur l'arbre d'avant le chantier (les images « avant ») : tout ce qui n'existait pas avant
## se lit par le script (`_statique`), jamais par son nom.
##
## Exige une VRAIE fenêtre (sous Linux : `xvfb-run`). Ne rejoint aucune suite.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 \
##       --script res://tools/banc_lumieres.gd -- --sortie=/chemin/absolu [--plans=l1,l2,l3] [--led-murs-fige]
##
## Chaque plan écrit `<sortie>/<nom>.png` et une ligne dans `<sortie>/plans.txt` ; les mesures s'impriment
## (`LUMIERES <plan> …`).

var _sortie := "user://lumieres"
var _familles: PackedStringArray = ["l1"]
var _main: Node
var _pres: Node
var _plans: PackedStringArray = []
var _pantins: Array = []
## Ce que `_tenir` impose à chaque image : positions, visées (monde), lampes.
var _pos := [Vector2.ZERO, Vector2.ZERO]
var _visee := [Vector2.RIGHT, Vector2.LEFT]
var _torche := [true, true]
var _accroupi := [false, false]
var _libre := Vector2.ZERO


class Pantin extends InputProvider:
	var visee := Vector2.RIGHT
	var torche := false
	var accroupi := false

	func get_movement_vector() -> Vector2:
		return Vector2.ZERO

	func get_aim_direction(_pos: Vector2) -> Vector2:
		return visee

	func is_shoot_pressed() -> bool:
		return false

	func is_flashlight_pressed() -> bool:
		return torche

	func is_flare_pressed() -> bool:
		return false

	func is_reload_pressed() -> bool:
		return false

	func is_crouch_pressed() -> bool:
		return accroupi


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			_sortie = a.trim_prefix("--sortie=")
		elif a.begins_with("--plans="):
			_familles = a.trim_prefix("--plans=").split(",")
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_sortie)
	await process_frame
	# Sous Xvfb sans gestionnaire de fenêtres, la fenêtre peut rester en 1280×720 (« Pièges connus », 2026-09-28).
	if root.size != Vector2i(1920, 1080):
		root.size = Vector2i(1920, 1080)
		await process_frame
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	var reseau := root.get_node("NetworkManager")
	_main.ui._intended_mode = int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])
	_main._on_replay_requested()
	if not await _depart_fini():
		printerr("la manche n'a pas démarré")
		quit(1)
		return
	_pres = root.get_node_or_null("Presentation3D")
	for j in 2:
		var pantin := Pantin.new()
		pantin.name = "PantinBanc%d" % (j + 1)
		_main._set_player_input_provider(_main.p1 if j == 0 else _main.p2, pantin)
		_pantins.append(pantin)
	_libre = _trouver_libre(_main._carte_px.get_center())
	print("LUMIERES fenetre %s ; carte %s ; libre %s ; plancher %s ; zoom %.2f" % [str(root.size),
		str(_main._carte_px), str(_libre), str(_statique("res://weapon_data.gd", "portee_plancher")),
		float(root.get_node("GameSettings").zoom_duel)])
	if _familles.has("l1"):
		await _plans_l1()
	if _familles.has("l1-options"):
		await _plans_l1_options()
	if _familles.has("quinze"):
		await _plan_quinze()
	if _familles.has("cadence"):
		await _plan_cadence()
	var f := FileAccess.open(_sortie.path_join("plans.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_plans) + "\n")
	print("banc_lumieres : %d plans dans %s" % [_plans.size(), _sortie])
	for j in 2:
		Input.action_release("p%d_torch" % (j + 1))
	quit(0)


func _depart_fini() -> bool:
	var fin := Time.get_ticks_msec() + 8000
	while not (_main.round_active and _main.countdown_left > 0.0):
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	_main.countdown_left = 0.001
	while _main.countdown_left > 0.0:
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	return true


## Une valeur statique d'un script, ou `null` si elle n'existe pas (arbre d'avant).
func _statique(chemin: String, nom: String) -> Variant:
	var s := load(chemin) as GDScript
	return s.get(nom) if s != null else null


## Un point sans mur dans un rayon de 30 px, en spirale autour de `depart`.
func _trouver_libre(depart: Vector2) -> Vector2:
	var espace: PhysicsDirectSpaceState2D = (_main.p1 as Node2D).get_world_2d().direct_space_state
	var cercle := CircleShape2D.new()
	cercle.radius = 30.0
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = cercle
	q.collision_mask = MapGeometry.WALL_LAYER
	for r in range(0, 600, 20):
		for k in 16:
			var p := depart + Vector2.RIGHT.rotated(TAU * float(k) / 16.0) * float(r)
			q.transform = Transform2D(0.0, p)
			if espace.intersect_shape(q, 1).is_empty():
				return p
			if r == 0:
				break
	return depart


## La visée MONDE qui se lit `ecran` à l'écran du joueur `pid` (x à droite, y en bas).
func _au_sol(pid: int, ecran: Vector2) -> Vector2:
	return CameraIso.stick_au_sol(ecran.normalized(), float(_main.lacet_de_la_vue(pid)))


func _poser(pos1: Vector2, pos2: Vector2, visee1: Vector2, visee2: Vector2, torche1 := true, torche2 := true) -> void:
	_pos = [pos1, pos2]
	_visee = [visee1.normalized(), visee2.normalized()]
	_torche = [torche1, torche2]


func _classe(pid: int, slug: String) -> void:
	for c in _main._classes:
		if c.slug() == slug:
			(_main.p1 if pid == 0 else _main.p2).equip_weapon(c)
			return


func _tenir_une_image() -> void:
	for k in 2:
		var j: Node2D = _main.p1 if k == 0 else _main.p2
		j.global_position = _pos[k]
		j.set("_torch_breath_t", 0.0)
		_pantins[k].visee = _visee[k]
		_pantins[k].torche = _torche[k]
		_pantins[k].accroupi = _accroupi[k]
		var action := "p%d_torch" % (k + 1)
		if _torche[k]:
			Input.action_press(action)
		else:
			Input.action_release(action)
		j.set("dazzle_amount", 0.0)


## Tient la scène jusqu'à ce que les deux caméras et les lampes ne bougent plus (trente images de suite).
func _tenir() -> void:
	var reperes := []
	var tenues := 0
	var images := 0
	while tenues < 30 and images < 900:
		_tenir_une_image()
		await physics_frame
		await process_frame
		images += 1
		var o := [(_main.vp1 as SubViewport).canvas_transform.origin, (_main.vp2 as SubViewport).canvas_transform.origin,
			(_main.p1.get_node(^"Flashlight") as PointLight2D).energy, (_main.p2.get_node(^"Flashlight") as PointLight2D).energy,
			snappedf(float(_main.p1.rotation), 0.0001), snappedf(float(_main.p2.rotation), 0.0001)]
		tenues = tenues + 1 if o == reperes else 0
		reperes = o
	if tenues < 30:
		print("LUMIERES ⚠️ scène ENCORE EN MOUVEMENT après %d images" % images)


func _photo(nom: String, legende: String) -> void:
	await _tenir()
	_tenir_une_image()
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(_sortie.path_join(nom + ".png"))
	var mesures := _mesures()
	_plans.append("%s\t%s\t%s" % [nom, legende, mesures])
	print("LUMIERES %s — %s | %s" % [nom, legende, mesures])


## Pour chaque vue rendue : la portée de la lampe du joueur regardé, la distance au bord de l'écran dans sa visée,
## et ce que le faisceau verse encore sur l'axe au bord (0-1, `lumiere_axiale`).
func _mesures() -> String:
	var parts: PackedStringArray = []
	for pid in 2:
		if _pres == null or not _pres.has_method("projecteur_ecran"):
			continue
		var proj: Callable = _pres.projecteur_ecran(pid)
		var ecran: Viewport = _pres.viewport_ecran(pid)
		if not proj.is_valid() or ecran == null:
			continue
		var j: Node2D = _main.p1 if pid == 0 else _main.p2
		var arme: WeaponData = j.current_weapon
		var taille := ecran.get_visible_rect().size
		var p := j.global_position
		var u := Vector2.RIGHT.rotated(j.rotation)
		var s0: Vector2 = proj.call(p)
		var d: Vector2 = proj.call(p + u * 100.0) - s0
		var k := INF
		for axe in 2:
			if absf(d[axe]) > 1e-6:
				k = minf(k, ((taille[axe] if d[axe] > 0.0 else 0.0) - s0[axe]) / d[axe])
		var bord := 100.0 * k
		parts.append("J%d %s portée %.0f px, bord à %.0f px, faisceau au bord %.3f" % [pid + 1, arme.slug(),
			arme.portee_torche(), bord, arme.lumiere_axiale(minf(bord, arme.portee_torche() - 1.0))])
	return " ; ".join(parts)


func _scinde() -> void:
	_main.vp2.get_parent().show()
	_main.ui.center_line.show()
	_main._accorder_rendu_aux_vues()
	_main.ui.disposer_hud()
	for i in 4:
		await process_frame


func _unique() -> void:
	_main.vp2.get_parent().hide()
	_main.ui.center_line.hide()
	_main._accorder_rendu_aux_vues()
	_main.ui.disposer_hud(true)
	for i in 4:
		await process_frame


# --- L1 : la portée -------------------------------------------------------------------------------------------

func _plans_l1() -> void:
	var t := MursBas.TUILE
	# Écran scindé : le Terrassier (la portée la plus courte, 192 px avant) et le pistolet, chacun vers un coin de SON
	# écran — J1 vers le haut à droite, J2 vers le bas à gauche. J2 à six tuiles, hors du cône de J1.
	await _scinde()
	_classe(0, "pompe")
	_classe(1, "pistolet")
	_poser(_libre, _libre + Vector2(-6.0 * t, 3.0 * t), _au_sol(0, Vector2(1.0, -0.56)), _au_sol(1, Vector2(-1.0, 0.56)))
	await _photo("l1_01_scinde_coins", "écran scindé, 45° B : J1 Terrassier vers le coin haut-droit de son écran, J2 pistolet vers le coin bas-gauche du sien")
	_poser(_libre, _libre + Vector2(-6.0 * t, 3.0 * t), _au_sol(0, Vector2(0.0, -1.0)), _au_sol(1, Vector2(0.0, -1.0)))
	await _photo("l1_02_scinde_haut", "écran scindé : les deux visent le HAUT de leur écran (dos à la caméra)")
	# Vue unique : le Terrassier vers le coin, puis la Sentinelle (499 px avant) vers la droite.
	await _unique()
	_poser(_libre, _libre + Vector2(-8.0 * t, 5.0 * t), _au_sol(0, Vector2(1.0, -0.56)), _au_sol(1, Vector2(0.0, 1.0)), true, false)
	await _photo("l1_03_unique_coin", "vue unique (en ligne, entraînement) : J1 Terrassier vers le coin haut-droit")
	_classe(0, "sentinelle")
	_poser(_libre, _libre + Vector2(-8.0 * t, 5.0 * t), _au_sol(0, Vector2(1.0, 0.0)), _au_sol(1, Vector2(0.0, 1.0)), true, false)
	await _photo("l1_04_unique_droite", "vue unique : J1 Sentinelle (la portée longue) vers la droite de l'écran")
	_classe(0, "pompe")
	_poser(_libre, _libre + Vector2(-8.0 * t, 5.0 * t), _au_sol(0, Vector2(-0.3, 1.0)), _au_sol(1, Vector2(0.0, 1.0)), true, false)
	await _photo("l1_05_unique_bas", "vue unique : J1 Terrassier vers le bas de l'écran (vers la caméra)")
	await _scinde()


## Les options que la règle ouvre (questions à Adrien), sur l'arbre d'après seulement.
func _plans_l1_options() -> void:
	var wd := load("res://weapon_data.gd") as GDScript
	if wd.get("portee_plancher") == null:
		print("LUMIERES options : arbre d'avant, rien à montrer")
		return
	var t := MursBas.TUILE
	var plancher: float = wd.get("portee_plancher")
	var facteur: float = wd.get("facteur_portee")
	# Option A (retenue) : l'arbalète, pour la comparer à elle-même sous l'option B.
	await _unique()
	_classe(0, "arbalete")
	_poser(_libre, _libre + Vector2(-8.0 * t, 5.0 * t), _au_sol(0, Vector2(1.0, -0.56)), _au_sol(1, Vector2(0.0, 1.0)), true, false)
	await _photo("l1_option_a_arbalete", "OPTION A (le plancher, retenue) : l'arbalète porte à %.0f px"
		% (_main.p1.current_weapon as WeaponData).portee_torche())
	# Option B : tout multiplier, pour que la plus courte (le Terrassier, torch_scale 1,0) atteigne le bord.
	wd.set("portee_plancher", 0.0)
	wd.set("facteur_portee", plancher / (WeaponData.TAILLE_COOKIE_REFERENCE * 0.5 * 1.0))
	for pid in 2:
		var j: Node2D = _main.p1 if pid == 0 else _main.p2
		j.equip_weapon(j.current_weapon)
	_classe(0, "arbalete")
	_poser(_libre, _libre + Vector2(-8.0 * t, 5.0 * t), _au_sol(0, Vector2(1.0, -0.56)), _au_sol(1, Vector2(0.0, 1.0)), true, false)
	await _photo("l1_option_b_arbalete", "OPTION B (tout multiplier ×%.2f) : l'arbalète porte à %.0f px, plus de trois écrans"
		% [float(wd.get("facteur_portee")), (_main.p1.current_weapon as WeaponData).portee_torche()])
	_classe(0, "pompe")
	await _photo("l1_option_b_pompe", "OPTION B : le Terrassier atteint juste le coin (même image que l'option A pour lui)")
	# Option « par mode » : en écran scindé, la portée de la vue scindée (plus étroite).
	wd.set("facteur_portee", facteur)
	var pe := load("res://portee_ecran.gd") as GDScript
	wd.set("portee_plancher", pe.portee_minimale(Vector2(957.0, 1080.0), float(root.get_node("GameSettings").zoom_duel),
		float(root.get_node("GameSettings").decalage_visee), CameraIso.TANGAGE_DEG))
	await _scinde()
	_classe(0, "pompe")
	_classe(1, "pistolet")
	_poser(_libre, _libre + Vector2(-6.0 * t, 3.0 * t), _au_sol(0, Vector2(1.0, -0.56)), _au_sol(1, Vector2(-1.0, 0.56)))
	await _photo("l1_option_par_mode_scinde", "OPTION « par mode » : en écran scindé, la portée de la vue scindée (%.0f px au lieu de %.0f)"
		% [float(wd.get("portee_plancher")), plancher])
	wd.set("portee_plancher", plancher)
	for pid in 2:
		var j: Node2D = _main.p1 if pid == 0 else _main.p2
		j.equip_weapon(j.current_weapon)


# --- Le plafond des quinze lumières par item ---------------------------------------------------------------------

## Godot n'applique jamais plus de QUINZE lumières à un même `CanvasItem`, tout ou rien, et un quadrant de sol
## (`TileMapLayer`, 16 tuiles = 560 px) est un item (« Pièges connus », 2026-09-10). Une torche plus longue a un
## rectangle plus grand : elle entre dans plus de quadrants. Le recensement compte, par quadrant, les `Light2D`
## allumées et visibles dont le rectangle (texture × échelle, tourné) le touche — la méthode de la ROADMAP — dans
## une scène chargée : écran scindé, deux torches, une fusée posée plein feu entre les joueurs, et un tir de J1.
const QUADRANT := 560.0


func _plan_quinze() -> void:
	var t := MursBas.TUILE
	await _scinde()
	_classe(0, "pompe")
	_classe(1, "pistolet")
	var j2 := _libre + Vector2(5.0 * t, 2.0 * t)
	_poser(_libre, j2, (j2 - _libre), (_libre - j2))
	await _tenir()
	var centre := (_libre + j2) * 0.5 + Vector2(0.0, 1.5 * t)
	_main._do_spawn_fusee(0, centre, 0.0, 4242)
	for i in 3:
		_tenir_une_image()
		await process_frame
	for c in _main.bullet_container.get_children():
		if "_atterrie" in c and "graine" in c:
			c.global_position = centre
			c.call("forcer_age", 0.5)
	for i in 20:
		_tenir_une_image()
		await physics_frame
	# Le flash de tir de J1, par le chemin du jeu (le tween le rallume à l'énergie de l'arme).
	_main.p1.trigger_shoot_visuals()
	await process_frame
	var par_quadrant := {}
	var actives := 0
	var familles := {}
	for l in _main.find_children("*", "Light2D", true, false):
		var lum := l as Light2D
		if not lum.enabled or not lum.is_visible_in_tree():
			continue
		actives += 1
		var nom := String(lum.name).rstrip("0123456789").trim_suffix("@")
		familles[nom] = int(familles.get(nom, 0)) + 1
		var r := _rect_monde(lum)
		for qx in range(floori(r.position.x / QUADRANT), floori(r.end.x / QUADRANT) + 1):
			for qy in range(floori(r.position.y / QUADRANT), floori(r.end.y / QUADRANT) + 1):
				var cle := Vector2i(qx, qy)
				par_quadrant[cle] = int(par_quadrant.get(cle, 0)) + 1
	var pire := 0
	for cle in par_quadrant:
		pire = maxi(pire, int(par_quadrant[cle]))
	var detail: PackedStringArray = []
	var cles := par_quadrant.keys()
	cles.sort()
	for cle in cles:
		detail.append("%s:%d" % [str(cle), par_quadrant[cle]])
	print("LUMIERES quinze : %d lumières actives ; par quadrant de 560 px, au plus %d — %s" % [actives, pire,
		" ".join(detail)])
	print("LUMIERES quinze familles : %s" % str(familles))
	var img := root.get_texture().get_image()
	img.save_png(_sortie.path_join("quinze_scene.png"))
	_plans.append("quinze_scene\tla scène du recensement (fusée plein feu, deux torches, un flash)\t%d actives, au plus %d par quadrant"
		% [actives, pire])


## Le rectangle monde d'une `PointLight2D` : sa texture à son échelle, centrée sur la lampe (plus son décalage), tournée.
func _rect_monde(l: Light2D) -> Rect2:
	var p := l as PointLight2D
	if p == null or p.texture == null:
		return Rect2(l.global_position, Vector2.ZERO)
	var demi := Vector2(p.texture.get_size()) * p.texture_scale * 0.5
	var xf := p.global_transform
	var r := Rect2(xf * (p.offset - demi), Vector2.ZERO)
	for coin in [Vector2(demi.x, -demi.y), Vector2(-demi.x, demi.y), demi]:
		r = r.expand(xf * (p.offset + coin))
	return r


# --- La cadence relative (Mesa, sous Xvfb) ------------------------------------------------------------------------

## Le coût RELATIF, avant/après, sur une scène tenue : deux torches allumées, les joueurs face à face en diagonale.
## Sous Xvfb le rendu est logiciel (llvmpipe) : les millisecondes ne disent rien du Mac, leur RAPPORT dit ce que le
## changement ajoute au travail de rendu. La médiane des temps d'image sur `IMAGES_CADENCE` images, après stabilisation.
const IMAGES_CADENCE := 90


func _plan_cadence() -> void:
	var t := MursBas.TUILE
	# `--banc-sans-lumiere3d` : les lumières 3D miroir coupées (vue unique), pour répartir le coût.
	if OS.get_cmdline_user_args().has("--banc-sans-lumiere3d") and _pres != null:
		_pres.set("_lumiere_3d_voulue", false)
		_pres.call("poser_lumiere_3d", false)
		print("LUMIERES cadence : lumières 3D coupées")
	for mode in ["scindé", "vue unique"]:
		if mode == "scindé":
			await _scinde()
		else:
			await _unique()
		_classe(0, "pompe")
		_classe(1, "pistolet")
		var j2 := _libre + Vector2(6.0 * t, 3.0 * t)
		_poser(_libre, j2, _au_sol(0, Vector2(1.0, -0.56)), _au_sol(1, Vector2(1.0, -0.56)))
		await _tenir()
		var durees: Array[float] = []
		var avant := Time.get_ticks_usec()
		for i in IMAGES_CADENCE:
			_tenir_une_image()
			await process_frame
			var maintenant := Time.get_ticks_usec()
			durees.append(float(maintenant - avant) / 1000.0)
			avant = maintenant
		durees.sort()
		print("LUMIERES cadence %s : médiane %.1f ms, 10e centile %.1f ms, 90e centile %.1f ms (%d images)" % [mode,
			durees[durees.size() / 2], durees[durees.size() / 10], durees[durees.size() * 9 / 10], durees.size()])
	await _scinde()
