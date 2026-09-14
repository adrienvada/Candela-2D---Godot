## Suite de l'ACCROUPI — chantier MURS BAS, étape MB2 (2026-09-14).
## Lancer : godot --headless --path . res://tools/test_accroupi.tscn
##
## Une SCÈNE et non un `--script` : `player.gd` nomme des autoloads
## (`NetworkManager`, `AudioManager`), qu'un `--script` ne déclare pas.
##
## Ce qu'elle garde :
## - les touches par défaut (C, M, L3) et la BASCULE du fournisseur local ;
## - le bit de posture sur le fil, du fournisseur réseau au RPC de l'hôte ;
## - la vitesse ×0,25 et la silhouette ramassée, dans un vrai joueur qui marche ;
## - la posture de l'adversaire interpolé, la posture enregistrée pour la killcam ;
## - le pas étouffé : un écart de niveau et une portée réduite, rien d'autre.
extends Node

var _echecs := 0


func _ready() -> void:
	_lancer.call_deferred()


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_echecs += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _lancer() -> void:
	print("=== Test accroupi (MB2) ===")
	_test_touches()
	_test_bascule_locale()
	_test_fournisseur_reseau()
	var p1: Player = _joueur(0)
	var p2: Player = _joueur(1)
	await get_tree().physics_frame
	await _test_vitesse_et_silhouette(p1)
	_test_interpolation(p2)
	_test_rpc_hote(p2)
	_test_rejeu(p1, p2)
	_test_pas_etouffe()
	_test_nouvelle_manche(p1)
	_test_torche_bute(p1)
	_test_balle(p1, p2)
	await _test_enjambement(p1)
	_test_fusee_en_vol()
	if _echecs == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _echecs)
	get_tree().quit(1 if _echecs > 0 else 0)


func _joueur(id: int) -> Player:
	var p: Player = load("res://player.tscn").instantiate()
	p.name = "Joueur%d" % id
	p.player_id = id
	var fournisseur := NetworkInputProvider.new()
	fournisseur.name = "Entrees"
	p.add_child(fournisseur)
	p.input_provider = fournisseur
	p.global_position = Vector2(200 + 400 * id, 300)
	add_child(p)
	return p


# ── Touches ─────────────────────────────────────────────────────────────────

func _test_touches() -> void:
	print("\n[Touches par défaut]")
	for j: int in [1, 2]:
		var action := "p%d_accroupir" % j
		_check("%s existe" % action, InputMap.has_action(action))
		if not InputMap.has_action(action):
			continue
		var clavier := -1
		var manette := -1
		for evt in InputMap.action_get_events(action):
			if evt is InputEventKey:
				clavier = (evt as InputEventKey).physical_keycode
			elif evt is InputEventJoypadButton:
				manette = (evt as InputEventJoypadButton).button_index
		var attendue := KEY_C if j == 1 else KEY_M
		_check("%s : touche %s (position physique)" % [action, "C" if j == 1 else "M"],
			clavier == attendue, str(clavier))
		_check("%s : clic du stick gauche (L3)" % action, manette == JOY_BUTTON_LEFT_STICK, str(manette))


func _test_bascule_locale() -> void:
	print("\n[Bascule du fournisseur local]")
	var local := LocalInputProvider.new()
	local.device_id = 0
	_check("debout au départ", not local.is_crouch_pressed())
	Input.action_press("p1_accroupir")
	_check("un appui : accroupi", local.is_crouch_pressed())
	_check("touche tenue, second appel de la même image : toujours accroupi", local.is_crouch_pressed())
	Input.action_release("p1_accroupir")
	_check("touche lâchée : reste accroupi (bascule, pas maintien)", local.is_crouch_pressed())
	Input.action_press("p1_accroupir")
	_check("second appui : debout", not local.is_crouch_pressed())
	Input.action_release("p1_accroupir")
	Input.action_press("p1_accroupir")
	local.is_crouch_pressed()
	Input.action_release("p1_accroupir")
	local.reset_crouch_state()
	_check("nouvelle manche : la bascule est remise à debout", not local.is_crouch_pressed())
	local.free()
	var base := InputProvider.new()
	_check("un fournisseur quelconque est debout", not base.is_crouch_pressed())
	base.free()


func _test_fournisseur_reseau() -> void:
	print("\n[Fournisseur réseau]")
	var r := NetworkInputProvider.new()
	r.update_input_state(Vector2.ZERO, Vector2.ZERO, false, false, false, false, false, true)
	_check("le bit reçu devient la posture", r.is_crouch_pressed())
	r.update_input_state(Vector2.ZERO, Vector2.ZERO, false, false, false)
	_check("un paquet sans bit : debout (défaut)", not r.is_crouch_pressed())
	r.update_input_state(Vector2.ZERO, Vector2.ZERO, false, false, false, false, false, true)
	r.reset_input_state()
	_check("déconnexion : debout", not r.is_crouch_pressed())
	r.free()


# ── Le joueur ────────────────────────────────────────────────────────────────

## Distance parcourue en `n` pas de physique, commandes données.
func _marcher(p: Player, accroupi: bool, n: int) -> float:
	var f := p.input_provider as NetworkInputProvider
	f.update_input_state(Vector2.RIGHT, Vector2.RIGHT, false, false, false, false, false, accroupi)
	# Deux pas pour que la posture et l'allure soient établies avant la mesure.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var depart := p.global_position
	for k in n:
		await get_tree().physics_frame
	var d := p.global_position.distance_to(depart)
	f.update_input_state(Vector2.ZERO, Vector2.ZERO, false, false, false, false, false, accroupi)
	await get_tree().physics_frame
	return d


func _test_vitesse_et_silhouette(p: Player) -> void:
	print("\n[Vitesse et silhouette]")
	var debout := await _marcher(p, false, 30)
	_check("debout : le joueur avance", debout > 50.0, "%.1f px" % debout)
	_check("debout : silhouette pleine", p.visual.scale == Vector2.ONE, str(p.visual.scale))
	var bas := await _marcher(p, true, 30)
	_check("accroupi : la posture est posée", p.accroupi)
	var ratio := bas / maxf(debout, 0.001)
	_check("accroupi : ×%.2f de la vitesse debout" % Player.FACTEUR_VITESSE_ACCROUPI,
		absf(ratio - Player.FACTEUR_VITESSE_ACCROUPI) < 0.03, "ratio %.3f (%.1f / %.1f px)" % [ratio, bas, debout])
	var e := Player.ECHELLE_SILHOUETTE_ACCROUPIE
	_check("accroupi : les cinq vues du corps ramassées",
		p.visual.scale == Vector2.ONE * e and p.visual_dim.scale == Vector2.ONE * e
		and p.visual_reveal.scale == Vector2.ONE * e and p.visual_enemy.scale == Vector2.ONE * e
		and p.visual_reveal_enemy.scale == Vector2.ONE * e, str(p.visual.scale))
	_check("la zone de touche ne change pas en MB2 (balles à deux hauteurs : MB3)",
		p.scale == Vector2.ONE)
	await _marcher(p, false, 2)
	_check("relevé : silhouette pleine", not p.accroupi and p.visual.scale == Vector2.ONE)


func _test_interpolation(p: Player) -> void:
	print("\n[Adversaire interpolé]")
	var maintenant := Time.get_ticks_msec() / 1000.0
	p.set("_net_snapshots", [{"t": maintenant - 5.0, "pos": p.global_position, "rot": 0.0,
		"torch": false, "accroupi": true}] as Array[Dictionary])
	p.call("_apply_remote_interpolation")
	_check("un instantané accroupi rend l'adversaire accroupi", p.accroupi)
	_check("… et sa silhouette ramassée",
		p.visual_enemy.scale == Vector2.ONE * Player.ECHELLE_SILHOUETTE_ACCROUPIE)
	p.set("_net_snapshots", [{"t": maintenant - 5.0, "pos": p.global_position, "rot": 0.0,
		"torch": false}] as Array[Dictionary])
	p.call("_apply_remote_interpolation")
	_check("un instantané d'avant MB2 (sans posture) : debout", not p.accroupi)


class FauxEtat extends Node:
	var client_peer_id := 0


func _test_rpc_hote(p2: Player) -> void:
	print("\n[Le bit sur le fil, côté hôte]")
	var mode_avant = NetworkManager.current_mode
	var etat := FauxEtat.new()
	etat.add_to_group("game_state")
	add_child(etat)
	NetworkManager.current_mode = NetworkManager.GameMode.ONLINE_HOST
	# Tout se joue dans cet appel synchrone : aucun pas de physique ne voit l'état
	# factice, qui n'a pas d'interface à lire.
	p2.call("rpc_send_inputs", 100000, Vector2.ZERO, Vector2.ZERO, false, false, false, false, false, true)
	var f := p2.input_provider as NetworkInputProvider
	_check("l'hôte reçoit la posture voulue du client", f.is_crouch_pressed())
	p2.call("rpc_send_inputs", 100001, Vector2.ZERO, Vector2.ZERO, false, false, false, false, false, false)
	_check("… et la relève", not f.is_crouch_pressed())
	NetworkManager.current_mode = mode_avant
	remove_child(etat)
	etat.free()
	var methode := {}
	for m in p2.get_method_list():
		if m["name"] == "rpc_send_inputs":
			methode = m
	var args: Array = methode.get("args", [])
	_check("rpc_send_inputs porte la posture puis l'enjambement en derniers arguments",
		args.size() == 10 and String(args[8]["name"]) == "crouch"
		and String(args[9]["name"]) == "climb", str(args.size()))


func _test_rejeu(p1: Player, p2: Player) -> void:
	print("\n[Killcam]")
	ReplaySystem.start_recording()
	p1.poser_posture(true)
	p2.poser_posture(false)
	ReplaySystem.record_frame(p1, p2, null)
	var snaps: Array = ReplaySystem.snapshots
	_check("une image enregistrée", snaps.size() == 1, str(snaps.size()))
	if snaps.size() == 1:
		_check("la posture de chaque joueur est enregistrée",
			snaps[0].p1_accroupi and not snaps[0].p2_accroupi)
	ReplaySystem.stop_recording()
	ReplaySystem.start_recording()
	ReplaySystem.stop_recording()
	p1.poser_posture(false)


func _test_pas_etouffe() -> void:
	print("\n[Pas étouffé]")
	var pos := Vector2(5000, 5000)
	var debout := AudioManager.play_footstep(pos, Vector2i(2, 2), false)
	_check("un pas debout se joue", debout != null)
	if debout == null:
		return
	var niveau_debout := debout.volume_db
	var portee_debout := debout.max_distance
	var bas := AudioManager.play_footstep(pos, Vector2i(2, 2), true)
	_check("un pas accroupi se joue", bas != null)
	if bas == null:
		return
	_check("accroupi : %.0f dB sous le pas debout" % -AudioManager.PAS_ACCROUPI_DB,
		absf(bas.volume_db - (niveau_debout + AudioManager.PAS_ACCROUPI_DB)) < 0.01,
		"%.2f contre %.2f" % [bas.volume_db, niveau_debout])
	_check("accroupi : portée ×%.2f" % AudioManager.PAS_ACCROUPI_PORTEE,
		absf(bas.max_distance - portee_debout * AudioManager.PAS_ACCROUPI_PORTEE) < 0.01,
		"%.1f contre %.1f" % [bas.max_distance, portee_debout])
	_check("témoin : l'écart est un étouffement, pas un silence", bas.volume_db > -80.0)


func _test_nouvelle_manche(p: Player) -> void:
	print("\n[Nouvelle manche]")
	var f := p.input_provider as NetworkInputProvider
	f.update_input_state(Vector2.ZERO, Vector2.ZERO, false, false, false, false, false, true)
	p.poser_posture(true)
	p.reset_posture()
	_check("chaque manche commence debout", not p.accroupi and p.visual.scale == Vector2.ONE)


# ── MB3a : la torche qui bute, la balle à deux hauteurs ─────────────────────

func _test_torche_bute(p: Player) -> void:
	print("\n[La torche d'un accroupi bute (MB3a)]")
	var bit := CanauxLumiere.COUCHE_OMBRE_MUR_BAS
	p.poser_posture(false)
	var debout := true
	for l: Light2D in [p.flashlight, p.body_light, p.ambient_light, p.muzzle_flash]:
		debout = debout and (l.shadow_item_cull_mask & bit) == 0
	_check("debout : aucune lumière portée ne lit les murs bas", debout)
	var avant: int = p.flashlight.shadow_item_cull_mask
	p.poser_posture(true)
	var bas := true
	for l: Light2D in [p.flashlight, p.body_light, p.ambient_light, p.muzzle_flash]:
		bas = bas and (l.shadow_item_cull_mask & bit) != 0
	_check("accroupi : les quatre lumières portées lisent les murs bas", bas)
	_check("accroupi : les autres couches d'ombre de la torche sont intactes",
		(p.flashlight.shadow_item_cull_mask & ~bit) == (avant & ~bit))
	p.poser_posture(false)
	_check("relevé : la torche passe à nouveau par-dessus",
		(p.flashlight.shadow_item_cull_mask & bit) == 0 and p.flashlight.shadow_item_cull_mask == avant)


func _test_balle(tireur: Player, cible: Player) -> void:
	print("\n[La balle à deux hauteurs (MB3a)]")
	var mur := Rect2(Vector2(0, 0), Vector2(6, 1) * MursBas.TUILE)
	var l := MursBas.longueur_zone_morte(MursBas.hauteur_mur(), MursBas.hauteur_de_posture(true),
		MapGeometry.ANGLE_FRANCHISSEMENT)
	for accroupi_tireur: bool in [false, true]:
		var b: Bullet = load("res://bullet.tscn").instantiate()
		b.weapon = WeaponData.new()
		b.source_player = tireur
		b.hauteur_tir = MursBas.hauteur_de_posture(accroupi_tireur)
		b.murs_bas = [mur]
		b.global_position = Vector2(mur.get_center().x, -100.0)
		b.direction = Vector2.DOWN
		add_child(b)
		b.set_physics_process(false)
		var masque_bas := (b.shape_cast.collision_mask & MapGeometry.LOW_WALL_LAYER) != 0
		if accroupi_tireur:
			_check("canon accroupi : la balle voit les murs bas comme des murs", masque_bas)
		else:
			_check("canon debout : la balle ne voit pas les murs bas", not masque_bas)
			_check("… elle passe au-dessus d'un accroupi dans la zone morte",
				not b._franchit_vers(Vector2(mur.get_center().x, mur.end.y + l - 3.0),
					MursBas.hauteur_de_posture(true)))
			_check("… et touche un accroupi au-delà",
				b._franchit_vers(Vector2(mur.get_center().x, mur.end.y + l + 3.0),
					MursBas.hauteur_de_posture(true)))
			_check("… et touche un debout collé au mur",
				b._franchit_vers(Vector2(mur.get_center().x, mur.end.y + 2.0),
					MursBas.hauteur_de_posture(false)))
			b.murs_bas = []
			_check("témoin : sans murs bas, tout est touché",
				b._franchit_vers(Vector2(mur.get_center().x, mur.end.y + 2.0),
					MursBas.hauteur_de_posture(true)))
		b.queue_free()
	_check("la cible reste en vie : aucun tir n'a été simulé", cible.hp > 0)


# ── MB3b : l'enjambement ────────────────────────────────────────────────────

func _test_enjambement(p: Player) -> void:
	print("\n[Enjamber un muret (MB3b)]")
	for j: int in [1, 2]:
		var action := "p%d_enjamber" % j
		var clavier := -1
		var manette := -1
		if InputMap.has_action(action):
			for evt in InputMap.action_get_events(action):
				if evt is InputEventKey:
					clavier = (evt as InputEventKey).physical_keycode
				elif evt is InputEventJoypadButton:
					manette = (evt as InputEventJoypadButton).button_index
		_check("%s : %s au clavier, Croix à la manette" % [action, "Espace" if j == 1 else "point-virgule"],
			clavier == (KEY_SPACE if j == 1 else KEY_SEMICOLON) and manette == JOY_BUTTON_A,
			"%d / %d" % [clavier, manette])
	var r := NetworkInputProvider.new()
	r.update_input_state(Vector2.ZERO, Vector2.ZERO, false, false, false, false, false, false, true)
	_check("le fournisseur réseau rend le geste d'enjamber", r.is_climb_pressed())
	r.reset_input_state()
	_check("… et l'oublie à la déconnexion", not r.is_climb_pressed())
	r.free()

	# Un vrai muret : une colonne de murs bas en x = 6, collision et règle.
	var carte := MapCodec.new_map("Muret", Vector2i(12, 12))
	var sol: Array[Vector2i] = []
	for y in 12:
		for x in 12:
			sol.append(Vector2i(x, y))
	carte["floor"] = MapCodec.encode_runs(sol)
	carte["low_walls"] = "6,0,1;6,1,1;6,2,1;6,3,1;6,4,1;6,5,1;6,6,1;6,7,1;6,8,1;6,9,1;6,10,1;6,11,1"
	var collisions := MapGeometry.build_collisions(carte, self)
	MursBas.murs_de_la_manche = MapGeometry.rects_monde(carte, MapGeometry.Kind.LOW_WALLS)
	var gauche := 6.0 * MursBas.TUILE
	var droite := 7.0 * MursBas.TUILE
	var f := p.input_provider as NetworkInputProvider
	p.poser_posture(false)
	p.global_position = Vector2(gauche - 60.0, 5.5 * MursBas.TUILE)
	for k in 3:
		await get_tree().physics_frame

	f.update_input_state(Vector2.RIGHT, Vector2.RIGHT, false, false, false)
	for k in 60:
		await get_tree().physics_frame
	_check("sans le geste, le muret arrête le corps", p.global_position.x < gauche,
		"x = %.1f, muret en %.0f" % [p.global_position.x, gauche])
	_check("… et on n'est pas en train d'enjamber", not p.enjambe)

	var avant_bruit := p.enjambements
	var munitions: int = p.current_ammo
	var vitesses := []
	var x_prec := p.global_position.x
	for k in 240:
		# Détente tenue tant que le corps est SUR le muret — hors du muret, un tir
		# partirait légitimement et ce contrôle ne dirait plus rien de l'enjambement.
		var sur_le_muret := p.global_position.x < droite + MursBas.RAYON_ENCOMBREMENT - 1.0
		f.update_input_state(Vector2.RIGHT, Vector2.RIGHT, sur_le_muret, false, false, false, false, false, true)
		await get_tree().physics_frame
		if p.enjambe:
			vitesses.append((p.global_position.x - x_prec) * Engine.physics_ticks_per_second)
		x_prec = p.global_position.x
		if p.global_position.x > droite + MursBas.RAYON_ENCOMBREMENT + 4.0:
			break
	f.update_input_state(Vector2.ZERO, Vector2.ZERO, false, false, false)
	await get_tree().physics_frame
	_check("en tenant le geste, le corps passe de l'autre côté", p.global_position.x > droite,
		"x = %.1f" % p.global_position.x)
	_check("un bruit d'enjambement, un seul", p.enjambements == avant_bruit + 1,
		"%d" % (p.enjambements - avant_bruit))
	var vitesse_max := 0.0
	for v: float in vitesses:
		vitesse_max = maxf(vitesse_max, v)
	var attendue := p.speed * Player.FACTEUR_VITESSE_ENJAMBEMENT
	_check("lentement : %.0f px/s pendant la traversée" % attendue,
		vitesses.size() > 0 and absf(vitesse_max - attendue) < attendue * 0.1,
		"max %.1f sur %d images" % [vitesse_max, vitesses.size()])
	_check("on ne tire pas en enjambant (détente tenue pendant toute la traversée)",
		p.current_ammo == munitions, "%d → %d" % [munitions, p.current_ammo])
	_check("la collision avec les murs bas revient une fois passé",
		(p.collision_mask & MapGeometry.LOW_WALL_LAYER) != 0)

	MursBas.murs_de_la_manche = []
	remove_child(collisions)
	collisions.free()


## Décision d'Adrien (21 h 10) : une fusée en vol éclaire par-dessus les murets,
## posée elle bute dessus. Les murs hauts l'arrêtent toujours.
func _test_fusee_en_vol() -> void:
	print("\n[La fusée : par-dessus en vol, bute au sol]")
	var bit := CanauxLumiere.COUCHE_OMBRE_MUR_BAS
	_check("en vol : la lueur passe au-dessus des murets", (Fusee.masque_ombre(false) & bit) == 0)
	_check("posée : la lueur bute sur les murets", (Fusee.masque_ombre(true) & bit) != 0)
	_check("dans les deux cas, les murs hauts l'arrêtent",
		(Fusee.masque_ombre(false) & 1) != 0 and (Fusee.masque_ombre(true) & 1) != 0)
	var src := FileAccess.get_file_as_string("res://fusee.gd")
	var poses := src.count("shadow_item_cull_mask = masque_ombre(true)")
	_check("les trois façons de se poser (vol, killcam, banc) passent au masque posé",
		poses == 3, "%d" % poses)
