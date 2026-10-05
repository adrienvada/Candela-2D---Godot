extends SceneTree

## Le banc d'images du chantier des lumières de la 0.8.0 (L1 portée, L2 la lampe du modèle, L3 le point lumineux), de Q76
## (la portée au bord le plus proche : `--plans=q76`, avant/après basculés sur place) et de Q58 (la fusée qui illumine loin
## à l'allumage : `--plans=q58`, six âges, avant/après basculés sur place, la lightmap lue).
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
## Q76 — les classes de la famille `q76` (`--q76-classes=pompe,arbalete` pour n'en refaire qu'une partie).
var _classes_q76: PackedStringArray = ["pompe", "sentinelle", "arbalete"]
## Q76 — vrai pendant la famille `q76` (et `q58`, qui le reprend) : l'écran nu (ni voile d'éblouissement, ni HUD, ni
## particules) et l'éblouissement laissé à son régime (`_plans_q76`).
var _q76_ecran_nu := false


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
		elif a.begins_with("--q76-classes="):
			_classes_q76 = a.trim_prefix("--q76-classes=").split(",")
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
	if _familles.has("classes"):
		await _plans_classes(0)
	if _familles.has("classes-j2"):
		await _plans_classes(1)
	if _familles.has("l2"):
		await _plans_l2()
	if _familles.has("l3"):
		await _plans_l3()
	if _familles.has("quinze"):
		await _plan_quinze()
	if _familles.has("cadence"):
		await _plan_cadence()
	if _familles.has("q76"):
		await _plans_q76()
	if _familles.has("q58"):
		await _plans_q58()
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
	if _q76_ecran_nu:
		_q76_montrer(false)
	for k in 2:
		var j: Node2D = _main.p1 if k == 0 else _main.p2
		j.global_position = _pos[k]
		_pantins[k].visee = _visee[k]
		_pantins[k].torche = _torche[k]
		_pantins[k].accroupi = _accroupi[k]
		var action := "p%d_torch" % (k + 1)
		if _torche[k]:
			Input.action_press(action)
		else:
			Input.action_release(action)
		if not _q76_ecran_nu:
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
		if _q76_ecran_nu:
			o.append_array([snappedf(float(_main.p1.dazzle_amount), 0.0001), snappedf(float(_main.p2.dazzle_amount), 0.0001)])
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
		var part := "J%d %s portée %.0f px, bord à %.0f px, faisceau au bord %.3f" % [pid + 1, arme.slug(),
			arme.portee_torche(), bord, arme.lumiere_axiale(minf(bord, arme.portee_torche() - 1.0))]
		if _q76_ecran_nu:
			part += ", éblouissement %.3f" % float(j.dazzle_amount)
		parts.append(part)
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
	# Option B : tout multiplier, pour que la plus courte (le Terrassier, torch_scale 1,0) atteigne le bord. Depuis Q76 le
	# jeu pose aussi un PLAFOND (`portee_plafond`) : levé le temps des options, rendu à la fin.
	var plafond: Variant = wd.get("portee_plafond")
	if plafond != null:
		wd.set("portee_plafond", INF)
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
	if plafond != null:
		wd.set("portee_plafond", plafond)
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


# --- L2 : la lampe du modèle ---------------------------------------------------------------------------------------

## Vue unique, J1 seul allumé, dans quatre visées : d'où part la lumière, près du corps. Chaque prise imprime où est
## J1 à l'écran (`LUMIERES ecran J1 x y`), pour recadrer la loupe.
func _plans_l2() -> void:
	var t := MursBas.TUILE
	await _unique()
	_classe(0, "pistolet")
	for v in [["l2_droite", Vector2(1.0, 0.0)], ["l2_bas", Vector2(0.0, 1.0)], ["l2_haut", Vector2(0.0, -1.0)],
			["l2_gauche_bas", Vector2(-1.0, 0.6)]]:
		_poser(_libre, _libre + Vector2(-8.0 * t, 5.0 * t), _au_sol(0, v[1]), _au_sol(1, Vector2(0.0, 1.0)), true, false)
		await _photo(String(v[0]), "vue unique, J1 pistolet vise %s de l'écran : d'où part la lumière" % str(v[1]))
		var proj: Callable = _pres.projecteur_ecran(0) if _pres != null else Callable()
		if proj.is_valid():
			var e: Vector2 = proj.call(_main.p1.global_position)
			print("LUMIERES ecran J1 %s %.0f %.0f" % [v[0], e.x, e.y])
	await _scinde()


# --- L3 : le point lumineux -----------------------------------------------------------------------------------------

## Écran scindé à 45° B, J1 seul allumé, dans huit visées (de l'écran de J1) : le point basculé SUR PLACE, éteint puis
## allumé, même scène. Pour chaque vue, ce que le point ajoute à l'écran autour de la lentille (le plus fort écart de
## luminance, /255, dans un carré de 9 px autour d'elle) : `LUMIERES l3 <plan> vue J1 … vue J2 …`. Dans la vue de J1, la
## lentille lui fait face quand il vise vers le BAS de son écran ; dans celle de J2 (caméra à l'opposé), quand J1 vise vers
## le HAUT de l'écran de J1.
func _plans_l3() -> void:
	var miroirs: Object = _pres.get("_miroirs") if _pres != null else null
	var volumes: Object = miroirs.get("volumes") if miroirs != null else null
	if volumes == null or not ("point_lumineux" in volumes):
		print("LUMIERES l3 : pas de point lumineux dans cet arbre")
		return
	var t := MursBas.TUILE
	await _scinde()
	_classe(0, "pistolet")
	_classe(1, "pistolet")
	var noms := ["haut", "haut_droite", "droite", "bas_droite", "bas", "bas_gauche", "gauche", "haut_gauche"]
	for k in 8:
		var ecran := Vector2.UP.rotated(TAU * float(k) / 8.0)
		_poser(_libre, _libre + Vector2(-5.0 * t, 4.0 * t), _au_sol(0, ecran), _au_sol(1, Vector2(0.0, 1.0)), true, false)
		volumes.set("point_lumineux", false)
		await _tenir()
		await RenderingServer.frame_post_draw
		var sans := root.get_texture().get_image()
		volumes.set("point_lumineux", true)
		for i in 3:
			_tenir_une_image()
			await process_frame
		await RenderingServer.frame_post_draw
		var avec := root.get_texture().get_image()
		# Le bruit de fond : le corps voxel respire d'une image à l'autre. Une seconde prise sans le point, après,
		# mesure ce que la scène change seule autour de la lentille.
		volumes.set("point_lumineux", false)
		for i in 3:
			_tenir_une_image()
			await process_frame
		await RenderingServer.frame_post_draw
		var sans2 := root.get_texture().get_image()
		volumes.set("point_lumineux", true)
		var nom := "l3_%d_%s" % [k, noms[k]]
		avec.save_png(_sortie.path_join(nom + ".png"))
		sans.save_png(_sortie.path_join(nom + "_sans.png"))
		var mesures: PackedStringArray = []
		for pid in 2:
			var ou := _lentille_a_l_ecran(pid)
			var ajout := _ajout(sans, avec, ou, 4)
			var bruit := maxf(_ajout(sans, sans2, ou, 4), _ajout(sans2, sans, ou, 4))
			mesures.append("vue J%d lentille (%.0f, %.0f) +%.0f/255 (bruit de fond %.0f)" % [pid + 1, ou.x, ou.y, ajout, bruit])
		var ligne := " ; ".join(mesures)
		_plans.append("%s\tJ1 vise %s de SON écran, point allumé (l'image `_sans` : éteint sur place)\t%s" % [nom, noms[k], ligne])
		print("LUMIERES l3 %s J1 vise %s | %s" % [nom, noms[k], ligne])
	volumes.set("point_lumineux", true)


## La lentille de J1 (bout du fût voxel), en pixels de la FENÊTRE, dans la vue du joueur `pid`.
func _lentille_a_l_ecran(pid: int) -> Vector2:
	var corps: Node3D = _pres.get("_voxels")[0]
	var pointe: Dictionary = corps.call("pointe_torche")
	var cam: CameraIso = _pres.call("_camera_de", pid)
	var ecran: Viewport = _pres.viewport_ecran(pid)
	if pointe.is_empty() or cam == null or ecran == null:
		return Vector2(-1, -1)
	var p: Vector3 = pointe["position"]
	var taille := ecran.get_visible_rect().size
	var cadre: Rect2 = _pres.call("_cadre", pid)
	var e := cam.vers_ecran(Vector2(p.x, p.z), taille, p.y)
	return cadre.position + e * cadre.size / taille


## Le plus fort écart de luminance (/255) entre deux images dans un carré de demi-côté `r` autour de `ou`.
func _ajout(sans: Image, avec: Image, ou: Vector2, r: int) -> float:
	var m := 0.0
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var x := int(ou.x) + dx
			var y := int(ou.y) + dy
			if x < 0 or y < 0 or x >= avec.get_width() or y >= avec.get_height():
				continue
			m = maxf(m, (avec.get_pixel(x, y).get_luminance() - sans.get_pixel(x, y).get_luminance()) * 255.0)
	return m


# --- L1bis : un faisceau par classe ----------------------------------------------------------------------------------

## Vue unique du joueur `pid` (J1 à 45°, J2 à 225° : l'équité), sa lampe SEULE allumée, visée vers le coin haut-droit de SON
## écran, pour chacune des dix classes. `classe_<slug>_j<n>.png` ; l'ouverture et la portée s'impriment.
func _plans_classes(pid: int) -> void:
	var t := MursBas.TUILE
	var autre := 1 - pid
	# La vue de ce joueur seul, comme en ligne (l'hôte voit J1, le client J2).
	(_main.vp1 if pid == 0 else _main.vp2).get_parent().show()
	(_main.vp2 if pid == 0 else _main.vp1).get_parent().hide()
	_main.ui.center_line.hide()
	_main._accorder_rendu_aux_vues()
	_main.ui.disposer_hud(true)
	for i in 4:
		await process_frame
	for c in _main._classes:
		(_main.p1 if pid == 0 else _main.p2).equip_weapon(c)
		var ici := _libre
		var loin := _libre + Vector2(-9.0 * t, 6.0 * t)
		var visee := _au_sol(pid, Vector2(1.0, -0.56))
		if pid == 0:
			_poser(ici, loin, visee, Vector2.DOWN, true, false)
		else:
			_poser(loin, ici, Vector2.DOWN, visee, false, true)
		var nom := "classe_%s_j%d" % [c.slug(), pid + 1]
		await _photo(nom, "%s (J%d, lacet %.0f°) : ouverture %.1f°, portée %.0f px" % [c.libelle if "libelle" in c else c.slug(),
			pid + 1, float(_main.lacet_de_la_vue(pid)), c.torch_angle_deg * 2.0, c.portee_torche()])
	await _scinde()


# --- Q76 : la portée au bord le plus proche ---------------------------------------------------------------------

## Q76 (Adrien, 2026-09-30 vers 22:58 : « En fait diminuons la portée des lampe au maximum visible par le joueur en hauteur
## et largeur (le minimum des deux) » ; vers 23:08 : « Ok, même portée en écran scindé ») — AVANT (la règle de L1 : le coin,
## 728 px) contre APRÈS (le bord le plus proche, 468 px), basculés SUR PLACE à cadrage identique (les bornes posées par
## `GameSettings.bornes_de_portee`, les lampes rééquipées), puis sans torche (le noir de référence). Pour le Terrassier, la
## Sentinelle et le Braconnier : la vue unique de J1 (×1,5), visée vers le haut de son écran puis vers le coin haut-droit ;
## la vue unique de J2 (celle du client en ligne), vers le haut du sien ; l'écran scindé (×1,25), les deux vers le haut du
## leur. `_mesures` imprime, par vue, la portée, le bord dans la visée, ce que le faisceau verse encore au bord et
## l'éblouissement du joueur. Jugé et mis en planche par `tools/portee_q76/planche.py`.
##
## ⚠️ **L'écran est mis à nu pour ces photos** (`_q76_montrer`) — ni voile d'éblouissement, ni HUD, ni particules — et
## l'éblouissement laissé à son régime au lieu d'être remis à zéro à chaque image. Trois choses que la portée ne touche
## pas, et qui bougent d'une photo à l'autre (« Pièges connus », 2026-09-30, « Une scène tenue… bouge encore ») :
## - le VOILE : la rétrodiffusion de sa propre torche le tient à 0,06 quelle que soit la portée (`Eblouissement.gain_taille`
##   vaut 1, `EXPOSANT_TAILLE` = 0 ; les mesures impriment le niveau, avant et après) ; mais il soulève toute la vue de 2 à
##   6/255 — plus aucun pixel noir à juger —, il respire avec son propre temps et, remis à zéro par `_tenir`, il remontait à
##   chaque image d'une fraction qui dépendait de la cadence : la première passe a vu des milliers de pixels « touchés » ;
## - le HUD : le chronomètre tourne entre l'avant et l'après, et ses chiffres passaient pour la lumière la plus haute de
##   l'écran (ligne 54) ;
## - la POUSSIÈRE du faisceau (`player.gd`, V5.5) : un grain semé au hasard à 40-240 px de la lampe, qui dérive — un point de
##   2 × 2 pixels, ici ou là, d'une photo à l'autre.
## Nu, le noir se juge à 0 dans toutes les vues, et la vue de J1 se compare à celle de J2 (dont le banc n'affiche pas le
## voile en vue unique : `ui.update_hud` tient J1 pour le joueur local).
func _plans_q76() -> void:
	var reglages := root.get_node("GameSettings")
	if not reglages.has_method("bornes_de_portee"):
		print("LUMIERES q76 : arbre d'avant Q76, rien à montrer")
		return
	_q76_ecran_nu = true
	var t := MursBas.TUILE
	var loin := _libre + Vector2(-9.0 * t, 6.0 * t)
	for slug: String in _classes_q76:
		_classe(0, slug)
		_classe(1, slug)
		await _q76_vue(0)
		for visee: Array in [["haut", Vector2(0.0, -1.0)], ["coin", Vector2(1.0, -0.56)]]:
			_poser(_libre, loin, _au_sol(0, visee[1]), Vector2.DOWN, true, false)
			await _q76_trio("q76_%s_unique_j1_%s" % [slug, visee[0]],
				"%s, vue unique de J1 (×1,5), visée vers le %s de l'écran" % [slug, visee[0]])
		await _q76_vue(1)
		_poser(loin, _libre, Vector2.DOWN, _au_sol(1, Vector2(0.0, -1.0)), false, true)
		await _q76_trio("q76_%s_unique_j2_haut" % slug, "%s, vue unique de J2 (×1,5), visée vers le haut de l'écran" % slug)
		await _q76_vue(-1)
		_poser(_libre, _libre + Vector2(-6.0 * t, 3.0 * t), _au_sol(0, Vector2(0.0, -1.0)), _au_sol(1, Vector2(0.0, -1.0)))
		await _q76_trio("q76_%s_scinde_haut" % slug, "%s, écran scindé (×1,25), les deux visent le haut de leur écran" % slug)
	_q76_regle(false)
	_q76_ecran_nu = false
	_q76_montrer(true)
	await _q76_vue(-1)


## Q76 — l'écran nu (`montrer` faux) : le voile d'éblouissement, le HUD et les particules cachés ; `montrer` les rend.
func _q76_montrer(montrer: bool) -> void:
	(_main.ui.p1_dazzle.get_parent() as CanvasItem).visible = montrer
	if _main.ui.match_hud != null:
		(_main.ui.match_hud as CanvasItem).visible = montrer
	var pool := get_first_node_in_group("particle_pool") as CanvasItem
	if pool != null:
		pool.visible = montrer


## La vue du joueur `pid` seule (0 ou 1), au zoom de la vue unique, comme en ligne ; ou l'écran scindé (−1), au sien.
func _q76_vue(pid: int) -> void:
	var reglages := root.get_node("GameSettings")
	(_main.vp1.get_parent() as Control).visible = pid != 1
	(_main.vp2.get_parent() as Control).visible = pid != 0
	_main.ui.center_line.visible = pid < 0
	_main._accorder_rendu_aux_vues()
	_main.ui.disposer_hud(pid >= 0)
	reglages.accorder_au_mode(false, pid < 0)
	for cam: Camera2D in [_main.cam1, _main.cam2]:
		cam.zoom = Vector2.ONE * float(reglages.zoom_duel)
	for i in 4:
		await process_frame


## La règle de la portée, posée sur place : le coin de L1 (`coin`) ou le bord le plus proche (Q76) ; les lampes rééquipées
## (l'échelle du cookie se relit à l'équipement).
func _q76_regle(coin: bool) -> void:
	var reglages := root.get_node("GameSettings")
	var b: Vector2 = reglages.bornes_de_portee(true, coin, float(reglages.zoom_de_la_vue_unique()),
		float(reglages.decalage_visee))
	var wd := load("res://weapon_data.gd") as GDScript
	wd.set("portee_plancher", b.x)
	wd.set("portee_plafond", b.y)
	for j: Node in [_main.p1, _main.p2]:
		j.equip_weapon(j.current_weapon)


## AVANT (le coin), APRÈS (le bord le plus proche), puis sans torche : trois photos au même cadrage.
func _q76_trio(nom: String, legende: String) -> void:
	var torches: Array = _torche.duplicate()
	_q76_regle(true)
	await _photo(nom + "_1avant", legende + " — AVANT (L1 : la portée au coin)")
	_q76_regle(false)
	await _photo(nom + "_2apres", legende + " — APRÈS (Q76 : la portée au bord le plus proche)")
	_torche = [false, false]
	await _photo(nom + "_3noir", legende + " — sans torche (le noir de référence)")
	_torche = torches


# --- Q58 : la fusée illumine loin à l'allumage ---------------------------------------------------------------------

## Q58 — les âges photographiés (secondes de combustion) : l'allumage, la tenue, le début et le milieu de la descente, la fin
## du plein feu, puis la braise.
const AGES_Q58 := [0.0, 0.5, 1.0, 2.0, 4.0, 6.0]
## Q58 — la fusée de la famille, posée par le vrai chemin (`_do_spawn_fusee`), puis tenue à l'âge voulu (`forcer_age`,
## physique coupée : rien ne la vieillit entre deux photos).
var _fusee_q58: Node2D = null
## Q58 — la portée d'allumage du jeu (`FuseeModele.rayon_allumage`), relue au début et rendue à la fin.
var _rayon_q58 := 0.0
## Q58 — la lightmap de chaque vue sans la lumière de la fusée (le noir de référence de l'âge en cours), par pid.
var _noirs_q58 := {}


## Q58 (Adrien, 2026-10-01 vers 09:10 : « Q58 : il faudrait qu'à l'allumage la fusée illumine loin effectivement ») — la fusée
## posée à six âges (0 ; 0,5 ; 1 ; 2 ; 4 s ; 6 s, la braise) : AVANT (la fusée de la 0.8.0 — `FuseeModele.rayon_allumage` à 0,
## ce que fait `--sans-fusee-allumage`) et APRÈS (Q58) basculés SUR PLACE, et sans sa lumière (le noir de référence), dans la
## vue unique de J1, celle de J2 (celle du client en ligne), puis l'écran scindé à 45° B. Torches éteintes : la fusée seule
## éclaire. Écran nu, comme pour Q76 (`_q76_ecran_nu` : ni voile — la fusée éblouit, autant avant qu'après —, ni HUD, ni
## particules). À chaque photo, `_q58_lightmap` lit la LIGHTMAP de chaque vue (le monde 2D vu de dessus, que la vue iso
## projette) contre celle du noir : jusqu'où la lumière de la fusée porte, et si un pixel qu'elle éclaire est DERRIÈRE un mur
## haut vu d'elle (un rayon de la fusée au point, contre les murs). Jugé et mis en planche par `tools/fusee_q58/planche.py`.
func _plans_q58() -> void:
	var modele := load("res://fusee_modele.gd") as GDScript
	if modele == null or modele.get("rayon_allumage") == null:
		print("LUMIERES q58 : arbre d'avant Q58, rien à montrer")
		return
	_rayon_q58 = float(modele.get("rayon_allumage"))
	print("LUMIERES q58 : portée d'allumage %.1f px, empreinte habituelle 440 px" % _rayon_q58)
	_q76_ecran_nu = true
	var t := MursBas.TUILE
	var loin := _libre + Vector2(-9.0 * t, 6.0 * t)
	for pid in [0, 1, -1]:
		await _q76_vue(pid)
		var reglages := root.get_node("GameSettings")
		# La fusée au centre de l'écran : la caméra avance de décalage × profondeur vers la visée.
		var avance := float(reglages.decalage_visee) * 1080.0 / maxf(float(reglages.zoom_duel), 0.01)
		var lieu: Vector2
		var scene: String
		if pid == 0:
			_poser(_libre, loin, _au_sol(0, Vector2(0.0, -1.0)), Vector2.DOWN, false, false)
			lieu = _trouver_libre(_libre + _au_sol(0, Vector2(0.0, -1.0)) * avance)
			scene = "unique_j1"
		elif pid == 1:
			_poser(loin, _libre, Vector2.DOWN, _au_sol(1, Vector2(0.0, -1.0)), false, false)
			lieu = _trouver_libre(_libre + _au_sol(1, Vector2(0.0, -1.0)) * avance)
			scene = "unique_j2"
		else:
			var j2 := _libre + Vector2(-6.0 * t, 3.0 * t)
			_poser(_libre, j2, _au_sol(0, Vector2(0.0, -1.0)), _au_sol(1, Vector2(0.0, -1.0)), false, false)
			lieu = _trouver_libre((_libre + j2) * 0.5)
			scene = "scinde"
		await _q58_poser_fusee(lieu)
		for age: float in AGES_Q58:
			await _q58_trio(pid, "q58_%s_%04d" % [scene, int(roundf(age * 1000.0))],
				"%s, la fusée posée à %.1f s" % [{0: "vue unique de J1 (×1,5)", 1: "vue unique de J2 (×1,5)",
					-1: "écran scindé (×1,25)"}[pid], age], age)
	modele.set("rayon_allumage", _rayon_q58)
	if _fusee_q58 != null and is_instance_valid(_fusee_q58):
		_fusee_q58.queue_free()
	_q76_ecran_nu = false
	_q76_montrer(true)
	await _q76_vue(-1)


## Q58 — pose la fusée de la famille par le vrai chemin du jeu, à `lieu`, et la tient (physique coupée).
func _q58_poser_fusee(lieu: Vector2) -> void:
	if _fusee_q58 != null and is_instance_valid(_fusee_q58):
		_fusee_q58.queue_free()
		await process_frame
	_main._do_spawn_fusee(0, lieu, 0.0, 5858)
	await process_frame
	_fusee_q58 = _main.bullet_container.get_node_or_null(^"FuseeJ1_5858") as Node2D
	if _fusee_q58 == null:
		printerr("LUMIERES q58 : la fusée n'a pas été posée")
		return
	_fusee_q58.global_position = lieu
	_fusee_q58.call("forcer_age", 0.0)
	_fusee_q58.set_physics_process(false)
	# Le son du lancer se voit (le son rendu visible, Q52) : son liseré s'efface en quelques dixièmes de seconde — on le
	# laisse partir, sans quoi il tache le noir et l'avant du premier âge, et pas l'après (vu à la première passe).
	var fin := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < fin:
		_tenir_une_image()
		await process_frame


## Q58 — le noir (la lumière de la fusée éteinte), AVANT (l'allumage éteint), APRÈS (Q58) : trois photos au même cadrage, à
## l'âge `age`, la lightmap de chaque vue lue contre celle du noir.
func _q58_trio(pid: int, nom: String, legende: String, age: float) -> void:
	var modele := load("res://fusee_modele.gd") as GDScript
	modele.set("rayon_allumage", _rayon_q58)
	_fusee_q58.call("forcer_age", age)
	(_fusee_q58.get_node(^"Halo") as PointLight2D).enabled = false
	await _photo(nom + "_3noir", legende + " — sans sa lumière (le noir de référence)")
	_noirs_q58.clear()
	for v in _q58_vues(pid):
		_noirs_q58[v] = _q58_image_lightmap(v)
	modele.set("rayon_allumage", 0.0)
	_fusee_q58.call("forcer_age", age)
	await _photo(nom + "_1avant", legende + " — AVANT (la 0.8.0 : le halo de 440 px)")
	_q58_lightmap(pid, nom + "_1avant", age)
	modele.set("rayon_allumage", _rayon_q58)
	_fusee_q58.call("forcer_age", age)
	await _photo(nom + "_2apres", legende + " — APRÈS (Q58 : l'allumage)")
	_q58_lightmap(pid, nom + "_2apres", age)


## Les vues rendues : la vue `pid` seule, ou les deux en écran scindé.
func _q58_vues(pid: int) -> Array:
	return [0, 1] if pid < 0 else [pid]


func _q58_image_lightmap(v: int) -> Image:
	var vp := (_main.vp1 if v == 0 else _main.vp2) as SubViewport
	return vp.get_texture().get_image()


## Q58 — ce que la lumière de la fusée fait dans la LIGHTMAP de la vue `v` (le monde 2D vu de dessus, avant la projection
## iso), contre le noir de référence : les pixels qu'elle éclaire (plus de 3/255 au-dessus du noir, un sur deux dans chaque
## direction), le plus loin d'entre eux de la fusée, ceux qui sont au-delà du rayon attendu à cet âge
## (`FuseeModele.rayon_halo_a`), et ceux qui sont DERRIÈRE un mur haut vu de la fusée (un rayon de la fusée au point du
## monde, contre les murs ; les points DANS un mur — son dessus — sont laissés). Une ligne « LIGHTMAP » par vue dans
## `plans.txt`.
func _q58_lightmap(pid: int, nom: String, age: float) -> void:
	var modele := load("res://fusee_modele.gd") as GDScript
	var rayon := float(modele.call("rayon_halo_a", age, 220.0))
	var f := _fusee_q58.global_position
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var exclus: Array[RID] = [(_main.p1 as CollisionObject2D).get_rid(), (_main.p2 as CollisionObject2D).get_rid()]
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = MapGeometry.WALL_LAYER
	q.exclude = exclus
	for v in _q58_vues(pid):
		var vp := (_main.vp1 if v == 0 else _main.vp2) as SubViewport
		var image := _q58_image_lightmap(v)
		var noir: Image = _noirs_q58.get(v)
		if noir == null or noir.get_size() != image.get_size():
			_plans.append("LIGHTMAP\t%s\tJ%d\tnoir absent" % [nom, v + 1])
			continue
		var ct := vp.canvas_transform
		var logique := Vector2(vp.size_2d_override) if vp.size_2d_override != Vector2i.ZERO else Vector2(vp.size)
		var echelle := Vector2(image.get_size()) / logique
		var inv := ct.affine_inverse()
		var centre := (ct * f) * echelle
		var r_px := (maxf(rayon, 220.0) + 80.0) * ct.x.length() * echelle.x
		var x0 := maxi(0, int(centre.x - r_px))
		var x1 := mini(image.get_width() - 1, int(centre.x + r_px))
		var y0 := maxi(0, int(centre.y - r_px))
		var y1 := mini(image.get_height() - 1, int(centre.y + r_px))
		var eclaires := 0
		var plus_loin := 0.0
		var au_dela := 0
		var derriere := 0
		var exemples: PackedStringArray = []
		for y in range(y0, y1 + 1, 2):
			for x in range(x0, x1 + 1, 2):
				var a := image.get_pixel(x, y)
				var b := noir.get_pixel(x, y)
				if maxf(a.r - b.r, maxf(a.g - b.g, a.b - b.b)) * 255.0 <= 3.0:
					continue
				eclaires += 1
				var w: Vector2 = inv * (Vector2(x + 0.5, y + 0.5) / echelle)
				var d := w.distance_to(f)
				plus_loin = maxf(plus_loin, d)
				if d > rayon + 3.0:
					au_dela += 1
				if d < 12.0:
					continue
				q.position = w
				if not espace.intersect_point(q, 1).is_empty():
					continue
				var rq := PhysicsRayQueryParameters2D.create(f, w, MapGeometry.WALL_LAYER, exclus)
				var hit := espace.intersect_ray(rq)
				if not hit.is_empty() and f.distance_to(hit["position"]) < d - 3.0:
					derriere += 1
					if exemples.size() < 4:
						exemples.append("(%.0f, %.0f) à %.0f px, mur à %.0f" % [w.x, w.y, d, f.distance_to(hit["position"])])
		var ligne := "J%d : %d px de lightmap éclairés par la fusée (un sur deux), le plus loin à %.0f px (rayon attendu %.0f) ; au-delà %d ; derrière un mur haut %d%s" % [
			v + 1, eclaires, plus_loin, rayon, au_dela, derriere, (" — " + ", ".join(exemples)) if exemples.size() > 0 else ""]
		_plans.append("LIGHTMAP\t%s\t%s" % [nom, ligne])
		print("LUMIERES lightmap %s %s" % [nom, ligne])
