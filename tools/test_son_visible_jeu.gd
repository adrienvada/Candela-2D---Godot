extends SceneTree

## Le son rendu visible, EN JEU : l'entonnoir d'`AudioManager`, `GameState` et les
## liserés des deux vues (chantier SON VISIBLE, 0.8.0, décisions d'Adrien du
## 2026-09-29). Le modèle seul est gardé par `test_son_visible.gd`.
##
## Ce qu'elle garde :
## - chaque famille dosée par l'audio a sa sorte ou se déclare muette, et les
##   ancres du modèle SONT les niveaux de l'audio (pas une copie qui dériverait) ;
## - l'entonnoir annonce chaque son au niveau que l'oreille reçoit — allure,
##   posture, duck sous le tir — même quand le pool n'a plus de voix ;
## - en écran scindé à 45° B, J1 voit les sons de J2 et jamais les siens, et
##   inversement ; **à situation miroir, les deux liserés sont identiques** —
##   largeur, force, et angle à l'écran, mesuré par la caméra de CHAQUE vue ;
## - rien pendant la killcam ni le décompte ; en vue unique, un seul liseré ;
## - la FORME D'ONDE (Adrien, 2026-09-29) : l'événement porte le fichier réellement joué
##   et le pitch final, chaque son que le jeu joue a son enveloppe (aucun repli), un tir
##   vit plus longtemps qu'un pas, la salle allonge le même son, les deux vues voient la
##   même animation, une source continue est plate et sa nouvelle annonce REMPLACE la
##   précédente ;
## - Q52 : la toile des liserés est en mélange ADDITIF.
##
## Lancer : godot --headless --path . --script res://tools/test_son_visible_jeu.gd

const SV := preload("res://son_visible.gd")

var _failures := 0
var _verifications := 0
var _recus: Array[Dictionary] = []


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _noter(evenement: Dictionary) -> void:
	_recus.append(evenement)


func _run() -> void:
	print("=== SON RENDU VISIBLE — EN JEU ===")
	await process_frame
	var audio := root.get_node("AudioManager")
	var consts: Dictionary = audio.get_script().get_script_constant_map()
	_couverture(consts)
	_ancres_liees(consts)
	_entonnoir(audio, consts)
	await _en_jeu(audio)
	_sortir()


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


# --- La table des sortes couvre l'audio ----------------------------------------------

func _couverture(consts: Dictionary) -> void:
	print("\n--- Chaque famille de l'audio a sa sorte ---")
	var familles := {}
	for fam in consts["NIVEAU_RELATIF"]:
		familles[String(fam)] = true
	for fam in consts["PORTEE_RELATIVE"]:
		familles[String(fam)] = true
	var orphelines: Array = []
	for fam in familles:
		if not (SV.CATEGORIE_DE_FAMILLE.has(fam) or SV.FAMILLES_MUETTES.has(fam)):
			orphelines.append(fam)
	_check("chaque famille dosée a sa sorte ou se déclare muette", orphelines.is_empty(), str(orphelines))
	var inconnues: Array = []
	for fam in SV.CATEGORIE_DE_FAMILLE:
		if not familles.has(String(fam)):
			inconnues.append(fam)
	_check("la table des sortes ne nomme que des familles de l'audio (une faute de frappe y serait muette)",
		inconnues.is_empty(), str(inconnues))


func _ancres_liees(consts: Dictionary) -> void:
	print("\n--- Les ancres du modèle sont les niveaux de l'audio ---")
	var niv: Dictionary = consts["NIVEAU_RELATIF"]
	for fam in ["footstep", "footstep_a", "footstep_b"]:
		_check("l'ancre nette (10°) est le niveau du pas : %s" % fam,
			is_equal_approx(float(niv[fam]), SV.NIVEAU_NET_DB), str(niv[fam]))
	_check("l'ancre floue (180°) est le pas accroupi",
		is_equal_approx(SV.NIVEAU_NET_DB + float(consts["PAS_ACCROUPI_DB"]), SV.NIVEAU_FLOU_DB))
	_check("un mur coûte au liseré ce qu'il coûte à l'oreille",
		is_equal_approx(float(consts["OCCLUSION_PENTE_DB"]), SV.PERTE_OCCLUSION_DB))
	_check("le pas lent debout reste au-dessus du pas accroupi (Q47)",
		SV.PAS_LENT_DB > float(consts["PAS_ACCROUPI_DB"]))
	# La salle du liseré est le miroir de celle de l'audio : recopiée, donc gardée.
	_check("la plus petite salle du liseré est celle de l'audio",
		is_equal_approx(SV.ROOM_SIZE_MIN, float(consts["REVERB_ROOM_SIZE_MIN"])))
	_check("la plus grande aussi",
		is_equal_approx(SV.ROOM_SIZE_MAX, float(consts["REVERB_ROOM_SIZE_MAX"])))
	_check("l'amortissement de référence aussi",
		is_equal_approx(SV.DAMPING_REF, float(consts["REVERB_DAMPING_DEFAUT"])))
	# La fusée se lit à l'exécution : la nommer dans ce fichier la compilerait avant les
	# autoloads (`NetworkManager` est introuvable à ce moment-là).
	var fusee: Dictionary = (load("res://fusee.gd") as GDScript).get_script_constant_map()
	_check("la période d'une source continue est celle que la fusée annonce",
		is_equal_approx(SV.PERIODE_CONTINU_DEFAUT, float(consts["PERIODE_ANNONCE_CONTINUE"]))
		and is_equal_approx(SV.PERIODE_CONTINU_DEFAUT, float(fusee["PERIODE_ANNONCE_COMBUSTION"])))


# --- L'entonnoir annonce ce que l'oreille reçoit ----------------------------------------

func _dernier() -> Dictionary:
	return _recus[_recus.size() - 1] if not _recus.is_empty() else {}


func _entonnoir(audio: Node, consts: Dictionary) -> void:
	print("\n--- L'entonnoir annonce chaque son localisé ---")
	audio.son_localise.connect(_noter)
	var pos := Vector2(300, 300)

	_recus.clear()
	var voix: AudioStreamPlayer2D = audio.play_footstep(pos, Vector2i(0, 0), false, 1.0, 1)
	_check("un pas s'annonce, une fois", _recus.size() == 1, str(_recus.size()))
	var ev := _dernier()
	if not ev.is_empty():
		_check("… sous la famille du damier", ["footstep_a", "footstep"].has(String(ev["famille"])), String(ev["famille"]))
		_check("… avec son émetteur", int(ev["emetteur"]) == 1)
		_check("… au niveau du pas de course", is_equal_approx(float(ev["niveau_db"]), SV.NIVEAU_NET_DB),
			str(ev["niveau_db"]))
		_check("… à la portée de sa famille",
			is_equal_approx(float(ev["portee"]), audio.portee_courante(String(ev["famille"]))))
		if voix != null:
			_check("la voix joue au niveau annoncé (ni mur ni fumée ici)",
				is_equal_approx(voix.volume_db, float(ev["niveau_db"])), "%s / %s" % [voix.volume_db, ev["niveau_db"]])
			_check("la voix porte à la portée annoncée", is_equal_approx(voix.max_distance, float(ev["portee"])))
			# La forme d'onde : le fichier RÉELLEMENT joué et le pitch FINAL de la voix.
			_check("l'événement porte le fichier réellement joué (%s)" % String(ev["chemin"]).get_file(),
				String(ev["chemin"]) == voix.stream.resource_path and String(ev["chemin"]).begins_with("res://assets/audio/sfx/footstep_"),
				str(ev["chemin"]))
			_check("… et le pitch final de la voix (%.3f)" % float(ev["pitch"]),
				is_equal_approx(float(ev["pitch"]), voix.pitch_scale), "%s / %s" % [ev["pitch"], voix.pitch_scale])
			_check("… ce fichier a son enveloppe", not SV.forme_d_onde(String(ev["chemin"])).is_empty())
		var salle: Dictionary = audio.reverb_courante()
		_check("l'événement porte la salle : wet, room_size, damping",
			is_equal_approx(float(ev["wet"]), float(salle["wet"])) and is_equal_approx(float(ev["room_size"]), float(salle["room_size"]))
			and is_equal_approx(float(ev["damping"]), float(salle["damping"])))
		_check("… et ne dit pas « continu » : un pas n'est pas une boucle", not bool(ev["continu"]))

	_recus.clear()
	var bas: AudioStreamPlayer2D = audio.play_footstep(pos, Vector2i(1, 0), true, 1.0, 1)
	ev = _dernier()
	_check("le pas accroupi s'annonce au niveau accroupi",
		not ev.is_empty() and is_equal_approx(float(ev["niveau_db"]), SV.NIVEAU_FLOU_DB), str(ev.get("niveau_db")))
	_check("… et à la moitié de sa portée",
		not ev.is_empty() and is_equal_approx(float(ev["portee"]),
			audio.portee_courante(String(ev["famille"])) * float(consts["PAS_ACCROUPI_PORTEE"])))
	if bas != null and not ev.is_empty():
		_check("la voix accroupie joue ce qui est annoncé (MB2 inchangé)",
			is_equal_approx(bas.volume_db, float(ev["niveau_db"])) and is_equal_approx(bas.max_distance, float(ev["portee"])))

	_recus.clear()
	audio.play_footstep(pos, Vector2i(0, 0), false, 0.5, 1)
	ev = _dernier()
	_check("le pas à mi-stick s'annonce plus bas (Q47)",
		not ev.is_empty() and is_equal_approx(float(ev["niveau_db"]), SV.NIVEAU_NET_DB + SV.ecart_allure_db(0.5)),
		str(ev.get("niveau_db")))
	_recus.clear()
	audio.play_footstep(pos, Vector2i(0, 0), true, 0.2, 1)
	ev = _dernier()
	_check("accroupi, l'allure n'ajoute rien : la posture est déjà le minimum",
		not ev.is_empty() and is_equal_approx(float(ev["niveau_db"]), SV.NIVEAU_FLOU_DB))

	_recus.clear()
	audio.play_percuteur("pistolet", pos, 0)
	ev = _dernier()
	_check("le percuteur s'annonce, avec son émetteur",
		not ev.is_empty() and String(ev["famille"]) == "weapon_dry" and int(ev["emetteur"]) == 0)

	_recus.clear()
	var tir: AudioStreamPlayer2D = audio.play_weapon_shot("pistolet", pos, 0)
	ev = _dernier()
	_check("le tir s'annonce au plus fort", not ev.is_empty() and String(ev["famille"]) == "shoot"
		and is_equal_approx(float(ev["niveau_db"]), SV.NIVEAU_FORT_DB))
	if tir != null and not ev.is_empty():
		_check("le tir porte le fichier de SA variante tirée au sort (%s)" % String(ev["chemin"]).get_file(),
			String(ev["chemin"]) == tir.stream.resource_path
			and String(ev["chemin"]).begins_with("res://assets/audio/weapons/weapon_pistolet_"))
		_check("… et son pitch (tiré à ±4 %%) : %.3f" % float(ev["pitch"]),
			is_equal_approx(float(ev["pitch"]), tir.pitch_scale) and absf(float(ev["pitch"]) - 1.0) <= 0.04 + 0.0001)
	# Une CLÉ passe par le dictionnaire des sons : c'est le chemin du fichier qui est annoncé.
	_recus.clear()
	var touche: AudioStreamPlayer2D = audio.play_sfx_2d("hit_center", pos, 1.0, 0.0, "SFX", 1)
	ev = _dernier()
	_check("une clé (« hit_center ») s'annonce sous le chemin du fichier qu'elle désigne",
		not ev.is_empty() and String(ev["chemin"]) == String(consts["SOUNDS"]["hit_center"])
		and (touche == null or String(ev["chemin"]) == touche.stream.resource_path), str(ev.get("chemin")))

	# Tout ce que le jeu joue en positionnel a son enveloppe : un repli ne se produit pas en silence.
	_chaque_son_a_son_enveloppe(audio)
	_recus.clear()
	audio.play_footstep(pos, Vector2i(0, 0), false, 1.0, 1)
	ev = _dernier()
	_check("le pas juste après un tir s'annonce au niveau que l'oreille entend (duck V4.15)",
		not ev.is_empty() and is_equal_approx(float(ev["niveau_db"]),
			SV.NIVEAU_NET_DB + float(consts["DUCK_TIR_DB"])), str(ev.get("niveau_db")))

	_recus.clear()
	audio.annoncer_son_2d("fusee_combustion", pos)
	ev = _dernier()
	_check("la combustion (voix dédiée) s'annonce par sa propre porte",
		not ev.is_empty() and String(ev["famille"]) == "fusee_combustion" and int(ev["emetteur"]) == -1
		and is_equal_approx(float(ev["niveau_db"]), float(consts["NIVEAU_RELATIF"]["fusee_combustion"])))
	_check("… comme une source CONTINUE, à la période de la combustion",
		not ev.is_empty() and bool(ev["continu"]) and is_equal_approx(float(ev["periode"]), 0.6))
	_recus.clear()
	audio.annoncer_son_2d("fusee_combustion", pos, -1, 0.0, 1.0, 0.45, 4242)
	ev = _dernier()
	_check("… dont l'appelant dit la période et l'identité",
		not ev.is_empty() and is_equal_approx(float(ev["periode"]), 0.45) and int(ev["source"]) == 4242)
	# La fusée elle-même, hors de l'arbre : sa combustion s'annonce sous SON identité et à SA période
	# (deux fusées allumées ensemble restent deux liserés ; une seule se remplace elle-même).
	var fusee: Node2D = (load("res://fusee.gd") as GDScript).new()
	fusee.position = pos
	var braise := AudioStreamPlayer2D.new()
	braise.stream = audio.get_audio_stream("fusee_combustion")
	root.add_child(braise)
	braise.play()
	fusee._combustion = braise
	_recus.clear()
	fusee._annoncer_combustion(0.001)
	ev = _dernier()
	var fusee_consts: Dictionary = (fusee.get_script() as GDScript).get_script_constant_map()
	_check("la fusée annonce sa combustion en source continue, à sa période, sous SON identité",
		not ev.is_empty() and bool(ev["continu"]) and int(ev["source"]) == fusee.get_instance_id()
		and is_equal_approx(float(ev["periode"]), float(fusee_consts["PERIODE_ANNONCE_COMBUSTION"])),
		str(ev))
	fusee.free()
	braise.queue_free()

	# Pool plein de sons plus prioritaires : le pas n'a pas de voix, mais il a eu lieu.
	for i in 16:
		audio.play_sfx_2d("hit_center", pos)
	_recus.clear()
	var sans_voix: AudioStreamPlayer2D = audio.play_footstep(pos, Vector2i(0, 0), false, 1.0, 1)
	if sans_voix == null:
		_check("pool plein : le pas sans voix s'annonce quand même", _recus.size() == 1)
		_check("… avec son fichier et son pitch : la forme d'onde ne dépend pas de la voix",
			_recus.size() == 1 and String(_recus[0]["chemin"]) != "" and float(_recus[0]["pitch"]) > 0.9)
	else:
		print("  (pool jamais plein ici : le cas « sans voix » n'a pas pu être joué)")
	audio.son_localise.disconnect(_noter)


## Chaque point d'entrée du jeu s'annonce sous un fichier que la table d'enveloppes connaît.
## Sinon le liseré retombe sur la durée par sorte — sans une erreur, et on jugerait « la forme
## d'onde » sur un son qui ne l'a pas. (Le lien de la table aux WAV, lui, est gardé par
## `test_enveloppes_sons.gd`.)
func _chaque_son_a_son_enveloppe(audio: Node) -> void:
	print("\n--- Chaque son que le jeu joue a son enveloppe ---")
	var pos := Vector2(300, 300)
	var jeux: Array = [
		["pas (damier A)", func(): audio.play_footstep(pos, Vector2i(0, 0), false, 1.0, 1)],
		["pas (damier B)", func(): audio.play_footstep(pos, Vector2i(1, 0), false, 1.0, 1)],
		["pas accroupi", func(): audio.play_footstep(pos, Vector2i(0, 0), true, 1.0, 1)],
		["frôlement", func(): audio.play_wall_brush(pos, 1)],
		["enjambement", func(): audio.play_enjambement(pos, 1)],
		["ricochet", func(): audio.play_ricochet(pos)],
		["douille", func(): audio.play_shell(pos, 1)],
		["impact de mur", func(): audio.play_wall_impact(pos)],
		["coup au centre", func(): audio.play_hit(pos, 0.1, 1)],
		["coup au bord", func(): audio.play_hit(pos, 0.9, 1)],
		["souffle coupé", func(): audio.play_breath_hit(pos, 1)],
		["carreau", func(): audio.play_bolt_flight(pos, 1)],
		["combustion", func(): audio.annoncer_son_2d("fusee_combustion", pos)],
	]
	for slug in ["pistolet", "fusil", "pompe", "arbalete"]:
		jeux.append(["tir (%s)" % slug, func(): audio.play_weapon_shot(slug, pos, 1)])
		jeux.append(["percuteur (%s)" % slug, func(): audio.play_percuteur(slug, pos, 1)])
		jeux.append(["rechargement (%s)" % slug, func(): audio.play_weapon_reload(slug, pos, 1)])
	for cle in ["fusee_lancer", "fusee_atterrit", "fusee_rebond", "fusee_eteinte"]:
		jeux.append([cle, func(): audio.play_sfx_2d_random_pitch(cle, pos)])
	var sans: Array = []
	var essais := 0
	for jeu in jeux:
		# Les variantes se tirent au hasard : plusieurs essais pour les voir passer.
		for i in 6:
			_recus.clear()
			(jeu[1] as Callable).call()
			essais += 1
			var ev := _dernier()
			if ev.is_empty() or String(ev["chemin"]) == "" or SV.forme_d_onde(String(ev["chemin"])).is_empty():
				sans.append("%s → %s" % [jeu[0], ev.get("chemin", "aucun événement")])
				break
	_check("chacun des %d points d'entrée annonce un fichier connu de la table (%d essais)" % [jeux.size(), essais],
		sans.is_empty(), str(sans))


# --- En jeu : deux vues, deux joueurs -------------------------------------------------

func _mode_local() -> int:
	var reseau := root.get_node("NetworkManager")
	return int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])


func _depart_fini(main: Node) -> bool:
	var fin := Time.get_ticks_msec() + 5000
	while not (main.round_active and main.countdown_left > 0.0):
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	main.countdown_left = 0.001
	while main.countdown_left > 0.0:
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	return true


func _vider(vues: Array) -> void:
	for v in vues:
		v.vider()


## La forme d'onde vue de l'écran : les durées, la salle, l'équité des deux vues, la source
## continue, le mélange additif. Deux joueurs vivants, écran scindé.
func _forme_d_onde_en_jeu(audio: Node, main: Node, vues: Array) -> void:
	print("\n--- La forme d'onde, en jeu : deux vues ---")
	var p1: Node2D = main.p1
	var p2: Node2D = main.p2
	var a := p1.global_position
	p2.global_position = a + Vector2(600, 0)
	var loin := a + Vector2(300, 0)

	# Un tir vit plus longtemps qu'un pas : vrais fichiers, vrais pitchs, vraie salle.
	_vider(vues)
	audio.play_weapon_shot("pistolet", loin, 1)
	audio.play_footstep(loin, Vector2i(0, 0), false, 1.0, 1)
	var traces: Array = vues[0].traces()
	_check("J1 voit le tir ET le pas de J2", traces.size() == 2, str(traces.size()))
	if traces.size() == 2:
		var tir: Dictionary = traces[0]
		var pas: Dictionary = traces[1]
		_check("chacun est animé par son fichier (aucun repli)", not tir["vie"].is_empty() and not pas["vie"].is_empty())
		_check("un tir vit plus longtemps qu'un pas (%.2f s contre %.2f s)" % [tir["duree"], pas["duree"]],
			float(tir["duree"]) > 1.5 * float(pas["duree"]))
		_check("le pas est un bref coup sourd (%.2f s)" % float(pas["duree"]), float(pas["duree"]) < 0.4)
		_check("le tir dure autant que sa détonation (%.2f s)" % float(tir["duree"]), float(tir["duree"]) > 0.35)

	# La salle allonge le même son : même fichier, même pitch, deux salles.
	var chemin: String = audio.chemin_tir("pistolet", 1)
	var garde: Dictionary = audio.reverb_courante().duplicate()
	var durees := {}
	for nom in ["sas", "hangar"]:
		var grille := Vector2i(15, 15) if nom == "sas" else Vector2i(45, 45)
		audio.appliquer_reverb_carte(audio.calculer_reverb_carte(grille, CandelaTileSet.TILE_SIZE))
		_vider(vues)
		audio.play_sfx_2d(chemin, loin, 1.0, 0.0, "SFX", 1)
		durees[nom] = float(vues[0].traces()[0]["duree"]) if vues[0].traces_vivantes() == 1 else -1.0
	audio.appliquer_reverb_carte(garde)
	_check("le même tir dure plus dans le hangar que dans le sas (%.2f s contre %.2f s)" % [durees["hangar"], durees["sas"]],
		durees["sas"] > 0.0 and durees["hangar"] > durees["sas"] + 0.05)

	# Un même événement, la même animation dans les deux vues (J1 et J2, à 45° B).
	p2.global_position = a + Vector2(400, 0)
	var milieu := (a + p2.global_position) * 0.5
	_vider(vues)
	audio.play_weapon_shot("fusil", milieu, -1)
	if vues[0].traces_vivantes() == 1 and vues[1].traces_vivantes() == 1:
		var t1: Dictionary = vues[0].traces()[0]
		var t2: Dictionary = vues[1].traces()[0]
		_check("équité : le même son, la même vie (%d pas, %.2f s)" % [t1["vie"]["niveaux"].size(), t1["duree"]],
			t1["vie"]["niveaux"] == t2["vie"]["niveaux"] and t1["vie"]["diffus"] == t2["vie"]["diffus"]
			and is_equal_approx(float(t1["duree"]), float(t2["duree"])))
		var identiques := true
		var duree := float(t1["duree"])
		# Des âges pris sur SA durée : la variante de fusil tirée au sort va de 0,5 à 0,9 s.
		for age in [0.0, 0.25 * duree, 0.5 * duree, 0.75 * duree, duree - 0.02]:
			var e1 := SV.etat(t1, age)
			var e2 := SV.etat(t2, age)
			identiques = identiques and not e1.is_empty() and not e2.is_empty() \
				and is_equal_approx(float(e1["alpha"]), float(e2["alpha"])) \
				and is_equal_approx(float(e1["largeur"]), float(e2["largeur"]))
		_check("équité : à tout âge, même opacité et même largeur dans les deux vues", identiques)
	else:
		_check("un son du monde, à égale distance des deux joueurs, dessine dans les deux vues", false)

	# La combustion : plate, et chaque annonce REMPLACE la précédente de sa source.
	_vider(vues)
	var feu := a + Vector2(250, 0)
	audio.annoncer_son_2d("fusee_combustion", feu, -1, 0.0, 1.0, 0.6, 77)
	_check("la combustion dessine un liseré", vues[0].traces_vivantes() == 1)
	if vues[0].traces_vivantes() == 1:
		var f: Dictionary = vues[0].traces()[0]
		_check("… animé comme une source continue", bool(f["vie"].get("continu", false)))
		var a0 := float(SV.etat(f, 0.0)["alpha"])
		var plat := true
		for age in [0.2, 0.45, 0.6, 0.7]:
			var e := SV.etat(f, age)
			plat = plat and not e.is_empty() and absf(float(e["alpha"]) - a0) < 0.0001
		_check("… plat sur toute sa période (alpha %.2f)" % a0, plat and a0 > 0.1)
		vues[0]._process(0.5)
		audio.annoncer_son_2d("fusee_combustion", feu, -1, 0.0, 1.0, 0.6, 77)
		_check("l'annonce suivante de la même fusée REMPLACE la précédente (un seul liseré)", vues[0].traces_vivantes() == 1)
		_check("… et repart de zéro : pas de creux entre deux", float(vues[0].traces()[0]["age"]) < 0.001)
		audio.annoncer_son_2d("fusee_combustion", feu + Vector2(0, 90), -1, 0.0, 1.0, 0.6, 78)
		_check("une AUTRE fusée reste un autre liseré", vues[0].traces_vivantes() == 2)
		vues[0]._process(0.7)
		_check("tant qu'aucune annonce ne vient, le liseré vit un peu plus que la période (%d)" % vues[0].traces_vivantes(),
			vues[0].traces_vivantes() == 2)
		vues[0]._process(0.1)
		_check("… puis s'éteint : une fusée éteinte ne laisse pas de liseré", vues[0].traces_vivantes() == 0)

	# Q52 : les liserés s'ADDITIONNENT — la toile est en mélange additif.
	for i in vues.size():
		var toile: Control = vues[i]._toile
		var materiau := toile.material as CanvasItemMaterial
		_check("Q52 : la toile du liseré de J%d porte un mélange additif" % (i + 1),
			materiau != null and materiau.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and bool(vues[i].melange_additif()))
	vues[0].poser_melange(false)
	_check("… et `poser_melange(false)` rend le mélange normal (le banc d'images s'en sert)",
		not bool(vues[0].melange_additif()) and vues[0]._toile.material == null)
	vues[0].poser_melange(true)
	_check("… et le rétablit", bool(vues[0].melange_additif()))

	# Aucun son du jeu n'est tombé sur la durée par sorte.
	_check("aucun liseré n'est retombé sur la durée par sorte (J1 : %d, J2 : %d)" % [vues[0].repli_compte, vues[1].repli_compte],
		vues[0].repli_compte == 0 and vues[1].repli_compte == 0)
	_vider(vues)


func _en_jeu(audio: Node) -> void:
	print("\n--- En jeu : écran scindé à 45° B ---")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.ui._intended_mode = _mode_local()
	main._on_replay_requested()
	_check("la manche scindée démarre", await _depart_fini(main))
	await process_frame
	var vues: Array = main._sons_vues
	_check("deux liserés, un par vue", vues.size() == 2)
	if vues.size() != 2:
		return
	_check("scindé : les deux liserés sont dans l'arbre", vues[0].get_parent() != null and vues[1].get_parent() != null)
	_check("chaque liseré porte la couche de SON joueur",
		vues[0].get("couche_vue") == GadgetBase.couche_de_vue(0) and vues[1].get("couche_vue") == GadgetBase.couche_de_vue(1))
	var p1: Node2D = main.p1
	var p2: Node2D = main.p2
	var reglages := root.get_node("GameSettings")
	_check("le lacet de J2 est celui de J1 plus 180° (45° B)",
		is_equal_approx(fposmod(float(main.lacet_de_la_vue(1)) - float(main.lacet_de_la_vue(0)), 360.0), 180.0)
		or not bool(reglages.mode_iso))

	# Deux points miroir : J2 entend J1 à −d quand J1 entend J2 à +d.
	var a := p1.global_position
	p2.global_position = a + Vector2(180, -60)
	_vider(vues)
	audio.play_footstep(p2.global_position, Vector2i(0, 0), false, 1.0, 1)
	_check("J1 voit le pas de J2", vues[0].traces_vivantes() == 1, str(vues[0].traces_vivantes()))
	_check("J2 ne voit pas son propre pas", vues[1].traces_vivantes() == 0)
	audio.play_footstep(p1.global_position, Vector2i(0, 0), false, 1.0, 0)
	_check("J2 voit le pas de J1", vues[1].traces_vivantes() == 1, str(vues[1].traces_vivantes()))
	_check("J1 ne voit pas son propre pas", vues[0].traces_vivantes() == 1)
	if vues[0].traces_vivantes() == 1 and vues[1].traces_vivantes() == 1:
		var t1: Dictionary = vues[0].traces()[0]
		var t2: Dictionary = vues[1].traces()[0]
		_check("équité : même largeur (%.2f° / %.2f°)" % [t1["largeur"], t2["largeur"]],
			is_equal_approx(float(t1["largeur"]), float(t2["largeur"])))
		_check("équité : même force", is_equal_approx(float(t1["alpha"]), float(t2["alpha"])))
		_check("équité : à situation miroir, même angle à l'écran (%.2f° / %.2f°)"
			% [rad_to_deg(t1["angle"]), rad_to_deg(t2["angle"])],
			absf(angle_difference(float(t1["angle"]), float(t2["angle"]))) < 0.01)
		_check("le pas de course à 190 px reste précis (%.1f°)" % t1["largeur"], float(t1["largeur"]) < 60.0)
		_check("la couleur des pas", t1["couleur"] == SV.couleur(SV.Categorie.PAS))
		var pres := root.get_node_or_null("Presentation3D")
		if pres != null and bool(reglages.mode_iso):
			_check("J1 : l'angle est celui de SA caméra",
				absf(angle_difference(float(t1["angle"]), pres.angle_ecran(0, p1.global_position, p2.global_position))) < 0.01)
			_check("J2 : l'angle est celui de SA caméra",
				absf(angle_difference(float(t2["angle"]), pres.angle_ecran(1, p2.global_position, p1.global_position))) < 0.01)

	# Le tir de J1, à la bouche de son arme : jamais chez lui, chez l'autre en blanc chaud.
	_vider(vues)
	audio.play_weapon_shot("pistolet", p1.global_position + Vector2(40, 0), 0)
	_check("J1 ne voit pas son propre tir, même à 40 px de lui", vues[0].traces_vivantes() == 0)
	_check("J2 voit le tir de J1, en blanc chaud",
		vues[1].traces_vivantes() == 1 and vues[1].traces()[0]["couleur"] == SV.couleur(SV.Categorie.TIR))

	# Tout près, accroupi : un bruissement, presque sans direction.
	_vider(vues)
	p2.global_position = a + Vector2(40, 0)
	audio.play_footstep(p2.global_position, Vector2i(0, 0), true, 1.0, 1)
	if vues[0].traces_vivantes() == 1:
		var t: Dictionary = vues[0].traces()[0]
		_check("le pas accroupi tout près : très large (%.0f°) et très léger (%.2f)" % [t["largeur"], t["alpha"]],
			float(t["largeur"]) > 150.0 and float(t["alpha"]) < 0.2)
	else:
		_check("le pas accroupi tout près dessine un liseré", false)

	# Le dessin passe sans erreur (le lanceur rougit sur toute SCRIPT ERROR).
	audio.play_footstep(p2.global_position + Vector2(200, 200), Vector2i(0, 0), false, 1.0, 1)
	await process_frame
	await process_frame

	await _forme_d_onde_en_jeu(audio, main, vues)

	# S6 — les bruits de corps de l'hôte, tels que le client les reçoit.
	print("\n--- S6 : les bruits de corps de l'hôte arrivent chez le client ---")
	var reseau := root.get_node("NetworkManager")
	var modes: Dictionary = reseau.get_script().get_script_constant_map()["GameMode"]
	_check("l'hôte envoie les bruits de SON joueur, en ligne",
		p1.bruit_a_repliquer(int(modes["ONLINE_HOST"]), 0, true))
	_check("… jamais ceux du joueur du client (le client le prédit)",
		not p1.bruit_a_repliquer(int(modes["ONLINE_HOST"]), 1, true))
	_check("… jamais depuis le client",
		not p1.bruit_a_repliquer(int(modes["ONLINE_CLIENT"]), 0, true))
	_check("… jamais en écran partagé ni sans pair",
		not p1.bruit_a_repliquer(int(modes["LOCAL_SPLITSCREEN"]), 0, true)
		and not p1.bruit_a_repliquer(int(modes["ONLINE_HOST"]), 0, false))
	_vider(vues)
	p2.global_position = a + Vector2(180, -60)
	var genres: Dictionary = p1.get_script().get_script_constant_map()["BruitDeCorps"]
	p1.rpc_bruit_de_corps(int(genres["RECHARGE"]), "pistolet", a + Vector2(8, 0))
	_check("le rechargement de J1 reçu : J2 le voit, en acier",
		vues[1].traces_vivantes() == 1 and vues[1].traces()[0]["couleur"] == SV.couleur(SV.Categorie.RECHARGE))
	_check("… et J1 ne voit pas le sien", vues[0].traces_vivantes() == 0)
	p1.rpc_bruit_de_corps(int(genres["FROLEMENT"]), "", a)
	_check("le frôlement de J1 reçu : J2 le voit",
		vues[1].traces_vivantes() == 2 and vues[1].traces()[1]["couleur"] == SV.couleur(SV.Categorie.FROLEMENT))
	# Q54 — le clic à vide de l'hôte, relayé comme les autres bruits de corps.
	p1.rpc_bruit_de_corps(int(genres["PERCUTEUR"]), "pistolet", a + Vector2(20, 0))
	_check("le clic à vide de J1 reçu : J2 le voit (Q54)",
		vues[1].traces_vivantes() == 3 and vues[1].traces()[2]["couleur"] == SV.couleur(SV.Categorie.PERCUTEUR))

	# Fermé : décompte, puis killcam.
	_vider(vues)
	main.countdown_left = 1.0
	audio.play_footstep(p2.global_position, Vector2i(0, 0), false, 1.0, 1)
	_check("pendant le décompte : aucun liseré", vues[0].traces_vivantes() == 0)
	main.countdown_left = 0.0
	var rejeu := root.get_node("ReplaySystem")
	rejeu.playing_back = true
	audio.play_footstep(p2.global_position, Vector2i(0, 0), false, 1.0, 1)
	_check("pendant la killcam : aucun liseré", vues[0].traces_vivantes() == 0)
	rejeu.playing_back = false
	audio.play_footstep(p2.global_position, Vector2i(0, 0), false, 1.0, 1)
	_check("rouvert : le liseré revient", vues[0].traces_vivantes() == 1)
	rejeu.playing_back = true
	await process_frame
	_check("la killcam efface les liserés déjà là", vues[0].traces_vivantes() == 0)
	rejeu.playing_back = false

	# Vue unique : un seul liseré dans l'arbre, celui de J1.
	print("\n--- Vue unique ---")
	main.vp2.get_parent().hide()
	main._accorder_rendu_aux_vues()
	await process_frame
	_check("vue unique : le liseré de J1 est dans l'arbre", vues[0].get_parent() != null)
	_check("vue unique : celui de J2 est retiré", vues[1].get_parent() == null)
	_vider(vues)
	p2.global_position = a + Vector2(180, -60)
	audio.play_footstep(p2.global_position, Vector2i(0, 0), false, 1.0, 1)
	_check("vue unique : J1 voit toujours le pas de J2", vues[0].traces_vivantes() == 1)
	main.vp2.get_parent().show()
	main._accorder_rendu_aux_vues()
	await process_frame
