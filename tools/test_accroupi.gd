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
	_test_equite(p1, p2)
	_test_killcam()
	await _test_empreintes()
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
				not b._franchit_vers(Vector2(mur.get_center().x, mur.end.y + l - 6.0),
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


# ── MB3d : l'équité ─────────────────────────────────────────────────────────

## Les deux règles fondamentales, vues par la balle :
## 1. **Chacun paie pareil des deux côtés d'un muret** : le tir de J1 vers J2 et
##    son reflet de J2 vers J1, à travers le reflet du muret, rendent la même
##    décision, dans les quatre couples de postures.
## 2. **Ce qui se voit est ce qui se paie**, exactement. En MB3d, la balle lisait
##    la tuile ENTIÈRE et la lumière l'occluder RENTRÉ : une bande de 3 px où l'on
##    voyait un accroupi sans pouvoir le toucher. Adrien l'a jugée gênante après
##    H-MB1 : la règle de la balle lit désormais la forme de la lumière
##    (`MursBas.franchit_regle`). Ni « vu, pas touché », ni « touché, pas vu ».
func _test_equite(p1: Player, p2: Player) -> void:
	print("\n[L'équité des deux côtés d'un muret (MB3d)]")
	var mur := Rect2(Vector2(0, 0), Vector2(6, 1) * MursBas.TUILE)
	var reflet := Rect2(Vector2(0, -mur.end.y), mur.size)  # y → −y
	var x := mur.get_center().x
	var b: Bullet = load("res://bullet.tscn").instantiate()
	b.weapon = WeaponData.new()
	add_child(b)
	b.set_physics_process(false)

	var cas := 0
	var ecarts := []
	for tir_accroupi: bool in [false, true]:
		for cible_accroupie: bool in [false, true]:
			for d in range(0, 80, 2):
				var cible := Vector2(x + 0.37 * d, mur.end.y + d)
				var direct := _decision(b, p1, mur, Vector2(x, -90.0), cible, tir_accroupi, cible_accroupie)
				var miroir := _decision(b, p2, reflet, Vector2(x, 90.0), Vector2(cible.x, -cible.y),
					tir_accroupi, cible_accroupie)
				cas += 1
				if direct != miroir and ecarts.size() < 5:
					ecarts.append("tir %s cible %s d=%d" % [tir_accroupi, cible_accroupie, d])
	_check("J1 → J2 et son reflet J2 → J1 : même décision (%d cas)" % cas, ecarts.is_empty(), str(ecarts))

	# Vu contre payé, sur l'axe : torche et canon debout au nord, accroupi au sud.
	var source := Vector2(x, -90.0)
	var rentre := mur.grow(-MapGeometry.OCCLUDER_INSET)
	var h_debout := MursBas.hauteur_de_posture(false)
	var h_acc := MursBas.hauteur_de_posture(true)
	var vu_sans_touche: Array = []
	var touche_sans_vu := 0
	# Dès d = 0 : balle et lumière lisent la même forme, le centre posé sur le bord
	# de la tuile n'est plus un cas à part (en MB3d, il touchait sans être vu).
	for k in 900:
		var d := k / 10.0
		var cible := Vector2(x, mur.end.y + d)
		var paye := _decision(b, p1, mur, source, cible, false, true)
		var vu := MursBas.franchit(source, cible, h_debout, h_acc, [rentre], MursBas.hauteur_mur(),
			MursBas.ANGLE_FRANCHISSEMENT)
		if vu and not paye:
			vu_sans_touche.append(d)
		elif paye and not vu:
			touche_sans_vu += 1
	_check("jamais touché sans être vu", touche_sans_vu == 0, "%d points" % touche_sans_vu)
	# Décision d'Adrien après H-MB1 : la balle suit la forme de la lumière. La
	# bande de 3 px « vu, pas touché » mesurée en MB3d (de 40,8 à 43,7 px) a disparu.
	_check("aucune bande « vu, pas touché » : la balle lit la forme de la lumière",
		vu_sans_touche.is_empty(),
		"%d points, de %.1f à %.1f px" % [vu_sans_touche.size(),
			vu_sans_touche.min() if not vu_sans_touche.is_empty() else 0.0,
			vu_sans_touche.max() if not vu_sans_touche.is_empty() else 0.0])
	b.queue_free()


## Décision de la VRAIE balle (`Bullet._franchit_vers`) pour un tir de `source`
## vers `cible`, par `tireur`, à travers `mur`.
func _decision(b: Bullet, tireur: Player, mur: Rect2, source: Vector2, cible: Vector2,
		tir_accroupi: bool, cible_accroupie: bool) -> bool:
	b.source_player = tireur
	b.spawn_pos = source
	b.hauteur_tir = MursBas.hauteur_de_posture(tir_accroupi)
	b.murs_bas = [mur]
	return b._franchit_vers(cible, MursBas.hauteur_de_posture(cible_accroupie))


# ── MB3d : la killcam ───────────────────────────────────────────────────────

## La killcam rejoue la règle : balle rejouée avec murs et hauteur de canon au
## tir, joueurs posés dans leur posture d'alors (la balle la lit), lampes du
## fantôme accroupi qui butent. Le câblage de `game_state.gd` ne se monte pas ici
## sans une partie entière : il est vérifié au texte, comme `test_classes` le fait
## pour les signatures ; la mécanique d'émission l'est dans `test_rejeu`.
func _test_killcam() -> void:
	print("\n[La killcam rejoue la règle (MB3d)]")
	_check("masque d'ombre : accroupi, le bit des murs bas est posé",
		CanauxLumiere.masque_ombre_posture(1 | 4, true) == (1 | 4 | CanauxLumiere.COUCHE_OMBRE_MUR_BAS))
	_check("… debout, il est retiré sans toucher les autres",
		CanauxLumiere.masque_ombre_posture(1 | 4 | CanauxLumiere.COUCHE_OMBRE_MUR_BAS, false) == (1 | 4))
	var gs := FileAccess.get_file_as_string("res://game_state.gd")
	var debut := gs.find("func _on_replay_spawn_bullet")
	var corps := gs.substr(debut, gs.find("\nfunc ", debut + 10) - debut)
	# ⚠️ Des LIGNES entières, pas des sous-chaînes : au premier sabotage, la ligne
	# commentée « #… b.murs_bas = murs_bas » contenait encore la sous-chaîne, et le
	# contrôle restait vert.
	_check("balle rejouée : elle reçoit les murs bas", corps.contains("\n\tb.murs_bas = murs_bas\n"))
	_check("… et la hauteur du canon au tir",
		corps.contains("\n\tb.hauteur_tir = MursBas.hauteur_de_posture(ReplaySystem.tir_rejoue.get(\"accroupi\""))
	_check("le tir s'enregistre avec la posture du tireur",
		gs.contains("final_rot, weapon,\n\t\t\t\tshooter.get(\"accroupi\") == true)"))
	_check("les joueurs rejoués prennent leur posture d'alors",
		gs.contains("\n\t\t\tp1.poser_posture(current_snap.p1_accroupi)\n")
		and gs.contains("\n\t\t\tp2.poser_posture(current_snap.p2_accroupi)\n"))
	_check("les lampes du fantôme suivent sa posture",
		gs.contains("\n\t\t\t\t\t\tlampe.shadow_item_cull_mask = CanauxLumiere.masque_ombre_posture("))


## Une empreinte est une marque au sol : elle suit la zone morte de SA vue. Sans
## cela, la trace d'un accroupi derrière un muret s'allumait sous une torche venue
## de l'autre côté, sur un sol resté noir.
func _test_empreintes() -> void:
	print("\n[Les empreintes suivent la zone morte (MB3d)]")
	var arene := Node2D.new()
	add_child(arene)
	var mats := []
	for vue in [1, 2]:
		var decor := Node2D.new()
		decor.name = "ArenaDecor_P%d" % vue
		decor.material = MursBasRendu.materiau_decor()
		arene.add_child(decor)
		mats.append(decor.material)
	Footprint.spawn(arene, Vector2(50, 50), 0.0, 1)
	await get_tree().process_frame
	await get_tree().process_frame
	var vue1: Node = null
	var vue2: Node = null
	for n in arene.get_children():
		if n is Footprint:
			if n.is_in_group("footprint_p2"):
				vue2 = n
			else:
				vue1 = n
	_check("vue 1 : l'empreinte prend le matériau de zone morte de sa vue",
		vue1 != null and vue1.material == mats[0])
	_check("vue 2 : son duplicata prend celui de la vue 2",
		vue2 != null and vue2.material == mats[1])
	var nue := Node2D.new()
	add_child(nue)
	Footprint.spawn(nue, Vector2.ZERO, 0.0, 1)
	_check("sans décor : aucun matériau, l'éclairage d'avant",
		nue.get_child_count() > 0 and nue.get_child(0).material == null)
	arene.queue_free()
	nue.queue_free()


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

	# ISO11, L1 — « on ne doit pas pouvoir escalader un mur juste avec le joystick »
	# (Adrien, test 1). Canon tourné ailleurs, le disque du corps (18 px) s'arrête
	# contre le muret dans le cercle d'encombrement (28) : la règle d'avant le
	# croyait « déjà dessus » et le laissait passer sans le geste.
	for visee: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT]:
		p.global_position = Vector2(gauche - 60.0, 5.5 * MursBas.TUILE)
		p.rotation = visee.angle()
		for k in 3:
			await get_tree().physics_frame
		var x_max := p.global_position.x
		var vu_enjambe := false
		f.update_input_state(Vector2.RIGHT, visee, false, false, false)
		for k in 90:
			await get_tree().physics_frame
			x_max = maxf(x_max, p.global_position.x)
			vu_enjambe = vu_enjambe or p.enjambe
		_check("sans le geste, canon vers %s : le muret arrête le disque du corps" % visee,
			x_max < gauche - MursBas.RAYON_DEDANS and not vu_enjambe,
			"x max = %.1f, muret en %.0f, enjambe vu %s" % [x_max, gauche, vu_enjambe])
		_check("… et la collision des murets reste posée",
			(p.collision_mask & MapGeometry.LOW_WALL_LAYER) != 0)
	f.update_input_state(Vector2.ZERO, Vector2.RIGHT, false, false, false)
	p.global_position = Vector2(gauche - 60.0, 5.5 * MursBas.TUILE)
	p.rotation = 0.0
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

	# ISO11, L1 — dans l'autre sens, canon vers le haut : le geste suffit quelle
	# que soit la visée, et lâché une fois le corps sur la pierre, la traversée
	# continue (un corps rendu à la collision au milieu du muret serait éjecté).
	var bruit_retour := p.enjambements
	var lache_dessus := false
	var passe := false
	for k in 360:
		var tenu := p.global_position.x > droite
		f.update_input_state(Vector2.LEFT, Vector2.UP, false, false, false, false, false, false, tenu)
		await get_tree().physics_frame
		if not tenu and p.enjambe:
			lache_dessus = true
		if p.global_position.x < gauche - MursBas.RAYON_ENCOMBREMENT - 4.0:
			passe = true
			break
	f.update_input_state(Vector2.ZERO, Vector2.ZERO, false, false, false)
	await get_tree().physics_frame
	_check("canon vers le haut, geste tenu jusqu'à la pierre puis lâché : la traversée va au bout",
		passe and lache_dessus, "x = %.1f, lâché dessus %s" % [p.global_position.x, lache_dessus])
	_check("… un bruit d'enjambement de plus", p.enjambements == bruit_retour + 1,
		"%d" % (p.enjambements - bruit_retour))
	_check("… et la collision des murets revient", (p.collision_mask & MapGeometry.LOW_WALL_LAYER) != 0)

	# ISO11, L1 — le geste tenu en s'ÉLOIGNANT d'un muret n'ouvre rien.
	p.global_position = Vector2(gauche - 20.0, 5.5 * MursBas.TUILE)
	p.rotation = PI * 0.5
	await get_tree().physics_frame
	f.update_input_state(Vector2.LEFT, Vector2.DOWN, false, false, false, false, false, false, true)
	await get_tree().physics_frame
	_check("geste tenu en s'éloignant du muret : pas d'enjambement", not p.enjambe)
	f.update_input_state(Vector2.ZERO, Vector2.ZERO, false, false, false)
	p.enjambe = true
	p.reset_posture()
	_check("reset_posture oublie un enjambement commencé et rend la collision",
		not p.enjambe and (p.collision_mask & MapGeometry.LOW_WALL_LAYER) != 0)

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
