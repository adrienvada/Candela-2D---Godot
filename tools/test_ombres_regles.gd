## OMBRES, OM4 — les règles d'ombre « sans décision » (chantier OMBRES, 2026-10-04).
##
## Quatre défauts de l'audit du 2026-10-04 (`docs/ROADMAP.md`, « Chantier — les ombres et la lumière du solo (OM) », O9 à O11),
## corrigés sans toucher à une question d'Adrien, et gardés ici sans rien rendre — sur les objets vivants d'une vraie manche :
##   • **O9, le flash de bouche** : collé à un mur, il brûlait 28 px devant le corps, DANS le mur (une lumière posée dans un
##     occluder ne donne « ni ombre ni lumière mais du hasard »). Il recule comme la lampe (`Player._reculer_le_flash`), à
##     `RETRAIT_LAMPE` du mur ; loin des murs il reste au bout du canon. Le contrôle : à 28 px, ce flash-là tombait dans le mur.
##   • **O10, l'écho au sol du tir** (`ground_flash`) n'avait aucune ombre : collé à un mur, il éclairait le sol de l'autre côté.
##     Il porte le masque des lumières neutres (`CanauxLumiere.masque_ombre_neutre_pour_les_corps`), décor compris.
##   • **O10, la lumière de coup** (`hit_light`) était ombrée par les murs seuls (`1`) : sa portée (`1 | 4`) touche le capteur de
##     SOI des deux joueurs, dont le masque ne croisait pas `1` — un corps rougissait dans sa propre vue à travers un mur. Le masque
##     neutre : les deux capteurs de soi en reçoivent les murs, et aucune couche de corps n'y est (le blessé ne s'ombre pas). Le
##     contrôle : avec l'ancien masque, aucun des deux ne recevait d'ombre.
##   • **O11, la posture** : accroupi, la silhouette passe à ×0,8 ; l'étoile suit, et un changement d'arme accroupi la garde.
##   • **O11, la mort** : un corps mort ne fait plus d'ombre (étoile, disque de torse) et sa lueur (le halo de proximité)
##     s'éteint ; relevé, il retrouve les trois. En dernier : la mort ouvre la fin de manche.
##   • **OM3, l'enveloppe du recul** (O3) : la torche ne tire plus son énergie au hasard à chaque image pendant le recul ; elle
##     plonge au coup et remonte, fonction du seul temps de recul (`Player.energie_de_recul`). Sa forme, puis, sur J1 vivant, chaque
##     image du recul égale à l'enveloppe — ce qu'aucun tirage ne peut faire.
## Ce que ces règles changent À L'IMAGE se voit au banc des ombres (`tools/planche_ombres.gd`), sous Xvfb.
##
## Lancer : godot --headless --path . --script res://tools/test_ombres_regles.gd
extends SceneTree

var _failures := 0
var _verifications := 0
var _main: Node


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== OMBRES, OM4 : LE FLASH, L'ÉCHO, LA LUMIÈRE DE COUP, LA POSTURE ET LA MORT ===")
	await process_frame
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	_main.ui._intended_mode = _mode_local()
	_main._on_replay_requested()
	_check("la manche scindée démarre", await _depart_fini(_main))
	if _failures > 0:
		_sortir()
		return
	await _le_flash_au_mur()
	_l_echo_et_la_lumiere_de_coup()
	await _la_posture()
	await _le_recul()
	# En dernier : la mort ouvre la fin de manche, et une manche finie ne lit plus les entrées.
	await _la_mort()
	_sortir()


# ---------------------------------------------------------------------------
# O9 — LE FLASH DE BOUCHE
# ---------------------------------------------------------------------------

func _le_flash_au_mur() -> void:
	print("\n--- O9 : le flash de bouche recule devant un mur, comme la lampe ---")
	var j1: Node2D = _main.p1
	var espace := j1.get_world_2d().direct_space_state
	var mur := _mur_le_plus_proche(j1.global_position)
	_check("un mur de la carte est trouvé autour de J1", not mur.is_empty())
	if mur.is_empty():
		return
	var dir: Vector2 = mur["direction"]
	var face: Vector2 = mur["point"]
	# Le corps collé au mur : son centre à 20 px de la face (le rayon du corps est 18).
	j1.global_position = face - dir * 20.0
	j1.global_rotation = dir.angle()
	_tenir_la_visee(j1, dir)
	for i in 3:
		await physics_frame
	_check("le contrôle : à 28 px devant ce corps, l'ancien flash tombait DANS le mur",
		_mur_entre(espace, j1, j1.global_position, j1.global_position + dir * float(j1.FLASH_AVANCEE)))
	j1.trigger_shoot_visuals()
	var flash: PointLight2D = j1.muzzle_flash
	var place := flash.position.x
	_check("collé au mur, le flash recule à %.1f px devant le corps (au plus 20 − %.0f)" % [place, j1.RETRAIT_LAMPE],
		place <= 20.0 - float(j1.RETRAIT_LAMPE) + 0.5 and place >= 4.0 and is_zero_approx(flash.position.y))
	_check("et il est du côté du corps : aucun mur entre le centre du corps et le flash",
		not _mur_entre(espace, j1, j1.global_position, flash.global_position))
	# Loin de tout mur : au bout du canon, comme avant.
	var libre := _point_libre(j1)
	_check("un point de sol libre de tout mur à 60 px est trouvé", libre != Vector2.INF)
	if libre == Vector2.INF:
		return
	j1.global_position = libre
	for i in 3:
		await physics_frame
	j1.trigger_shoot_visuals()
	_check("loin des murs, le flash reste au bout du canon (%.1f px)" % flash.position.x,
		is_equal_approx(flash.position.x, float(j1.FLASH_AVANCEE)))


# ---------------------------------------------------------------------------
# O10 — L'ÉCHO AU SOL ET LA LUMIÈRE DE COUP
# ---------------------------------------------------------------------------

func _l_echo_et_la_lumiere_de_coup() -> void:
	print("\n--- O10 : l'écho au sol et la lumière de coup portent le masque des lumières neutres ---")
	var neutre := CanauxLumiere.masque_ombre_neutre_pour_les_corps()
	var j1: Node2D = _main.p1
	var avant := _lumieres_enfants(j1)
	j1.trigger_shoot_visuals()
	var echo: PointLight2D = null
	for l in _lumieres_enfants(j1):
		if not avant.has(l) and (l as PointLight2D).range_item_cull_mask == 1:
			echo = l
	_check("un tir pose son écho au sol (une lumière neuve du décor seul)", echo != null)
	if echo != null:
		_check("l'écho au sol a des ombres, au masque des lumières neutres (%d)" % echo.shadow_item_cull_mask,
			echo.shadow_enabled and echo.shadow_item_cull_mask == neutre)
		_check("donc les murs le coupent au sol (le décor reçoit ses ombres)",
			(CanauxLumiere.DECOR & echo.shadow_item_cull_mask) != 0)
	var j2: Node2D = _main.p2
	var avant_j2 := _lumieres_enfants(j2)
	j2.rpc_update_hp(float(j2.hp) - 5.0, 0, 0)
	var coup: PointLight2D = null
	for l in _lumieres_enfants(j2):
		if not avant_j2.has(l) and ((l as PointLight2D).range_item_cull_mask & CanauxLumiere.JOUEUR_LOCAL) != 0:
			coup = l
	_check("un coup reçu pose la lumière de coup (portée décor et corps de soi)", coup != null)
	if coup == null:
		return
	_check("la lumière de coup a des ombres, au masque des lumières neutres (%d)" % coup.shadow_item_cull_mask,
		coup.shadow_enabled and coup.shadow_item_cull_mask == neutre)
	for id in 2:
		_check("le capteur de soi de J%d en reçoit les ombres — un mur entre le blessé et lui l'arrête" % (id + 1),
			(CanauxLumiere.masque_de_soi(id) & coup.shadow_item_cull_mask) != 0)
		_check("et aucune couche du corps ni du torse de J%d n'y est : le blessé ne s'ombre pas lui-même" % (id + 1),
			(coup.shadow_item_cull_mask & (CanauxLumiere.couche_ombre_corps(id) | CanauxLumiere.couche_ombre_torse(id))) == 0)
	_check("le contrôle : avec l'ancien masque (1), AUCUN capteur de soi ne recevait d'ombre de cette lumière",
		(CanauxLumiere.masque_de_soi(0) & 1) == 0 and (CanauxLumiere.masque_de_soi(1) & 1) == 0)
	j2.hp = 100.0


# ---------------------------------------------------------------------------
# O11 — LA POSTURE, LA MORT
# ---------------------------------------------------------------------------

func _la_posture() -> void:
	print("\n--- O11 : l'étoile suit la posture ---")
	var j1: Node2D = _main.p1
	var occ: LightOccluder2D = j1.etoile()
	# Par l'entrée, comme en jeu : la simulation repose la posture à chaque pas depuis `is_crouch_pressed()` — un
	# `poser_posture(true)` direct serait défait au pas suivant.
	var pantin := Pantin.new()
	pantin.accroupi = true
	_main._set_player_input_provider(j1, pantin)
	for i in 3:
		await physics_frame
	_check("le pantin accroupit J1", j1.accroupi)
	var e: float = float(j1.ECHELLE_SILHOUETTE_ACCROUPIE)
	_check("accroupi, l'étoile passe à ×%.2f, comme la silhouette (%s)" % [e, str(occ.scale)],
		occ.scale.is_equal_approx(Vector2.ONE * e) and occ.scale.is_equal_approx(j1.visual.scale))
	_check("et elle reste à cette échelle dans le monde, sa canvas suivant le corps (%s)" % str(occ.global_scale),
		occ.global_scale.is_equal_approx(Vector2.ONE * e))
	j1.equip_weapon(_main.weapon_for_index(2))
	_check("un changement d'arme accroupi garde l'échelle de la posture", j1.etoile().scale.is_equal_approx(Vector2.ONE * e))
	pantin.accroupi = false
	for i in 3:
		await physics_frame
	_check("debout, elle revient à ×1", j1.etoile().scale.is_equal_approx(Vector2.ONE)
		and j1.etoile().global_scale.is_equal_approx(Vector2.ONE))
	j1.equip_weapon(_main.weapon_for_index(0))


func _la_mort() -> void:
	print("\n--- O11 : un corps mort ne fait plus d'ombre, et sa lueur s'éteint ; relevé, il retrouve les trois ---")
	var j2: Node2D = _main.p2
	var torse := j2.get_node_or_null("OccluderTorse") as LightOccluder2D
	_check("vivant : l'étoile, le disque de torse et la lueur sont là",
		j2.etoile().visible and torse != null and torse.visible and j2.ambient_light.enabled)
	j2.die(_main.p1)
	for i in 3:
		await process_frame
	# Ce qui est RENDU, et non le seul drapeau du nœud : l'étoile vit dans SA canvas, et un corps caché (l'aventure cache ses
	# PNJ abattus, `AventurePartie._ranger_les_morts`) l'emmène avec lui. En duel, rien ne cache le mort : sans la règle, son
	# étoile et sa lueur restaient au sol toute la fin de manche.
	_check("en duel, le corps du mort reste dans l'arbre visible : seule la règle d'ombre peut retirer son ombre",
		j2.is_visible_in_tree())
	_check("mort : ni étoile, ni disque de torse — ni drapeau, ni rendu",
		not j2.etoile().visible and not torse.visible and not j2.etoile().is_visible_in_tree() and not torse.is_visible_in_tree())
	_check("mort : la lueur de proximité est éteinte", not j2.ambient_light.enabled)
	# Relevé comme le fait `_do_start_round` (les visuels avant la vie) : la règle se lit sur `dead`, pas sur l'ordre des gestes.
	j2.show_all_visuals()
	j2.hp = 100.0
	j2.dead = false
	for i in 3:
		await process_frame
	_check("relevé : l'étoile, le disque de torse et la lueur reviennent",
		j2.etoile().visible and torse.visible and j2.ambient_light.enabled)


# ---------------------------------------------------------------------------
# OM3 — L'ENVELOPPE DU RECUL
# ---------------------------------------------------------------------------

func _le_recul() -> void:
	print("\n--- OM3 : la torche plonge au coup et remonte pendant le recul — une enveloppe, plus un tirage ---")
	var P: GDScript = load("res://player.gd")
	var creux: float = P.get_script_constant_map()["RECUL_CREUX"]
	var sortie: float = P.get_script_constant_map()["RECUL_SORTIE"]
	_check("au coup, le creux (%.2f)" % creux, is_equal_approx(P.energie_de_recul(0.0), creux))
	_check("à la fin du recul, la sortie (%.2f), d'où le souffle reprend" % sortie, is_equal_approx(P.energie_de_recul(1.0), sortie))
	var monte := true
	var somme := 0.0
	var avant: float = P.energie_de_recul(0.0)
	for i in 1001:
		var e: float = P.energie_de_recul(float(i) / 1000.0)
		monte = monte and e >= avant - 1e-9
		avant = e
		somme += e
	_check("elle ne fait que remonter", monte)
	_check("sa moyenne sur le recul est celle de l'ancien tirage (1,75 ; %.4f) : la lampe n'est ni plus sombre ni plus claire" % (
		somme / 1001.0), absf(somme / 1001.0 - 1.75) < 0.002)
	# Sur J1 vivant, torche tenue : le recul armé à la main (le tir lui-même passerait par l'arbitrage de l'hôte), puis lu à chaque
	# pas de physique — c'est là que la torche se règle, alors que le compteur de recul se décompte à l'image (`_process`). Chaque
	# énergie doit être celle de l'enveloppe pour le recul que CE pas a vu (`_recul_vu`), quelle que soit la cadence des images.
	var j1: Node2D = _main.p1
	var pantin := Pantin.new()
	pantin.torche = true
	pantin.visee = Vector2.RIGHT
	_main._set_player_input_provider(j1, pantin)
	for i in 4:
		await process_frame
	_check("la torche de J1 est allumée", bool(j1.flashlight_on))
	var duree: float = maxf(float(j1.current_weapon.cooldown), 0.15)
	j1.shoot_cooldown = duree
	await physics_frame
	await physics_frame
	var energies: Array[float] = []
	var ecart_max := 0.0
	var pas := 0
	var fin := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < fin:
		var vu: float = float(j1.get("_recul_vu"))
		if float(j1.shoot_cooldown) <= 0.0 or vu <= 0.0:
			break
		var e: float = float(j1.get("_energie_torche"))
		energies.append(e)
		var attendue: float = P.energie_de_recul(1.0 - vu / float(j1.get("_recul_duree")))
		ecart_max = maxf(ecart_max, absf(e - attendue))
		pas += 1
		await physics_frame
	_check("le recul a duré plusieurs pas (%d)" % pas, pas >= 3)
	_check("chaque pas du recul est l'enveloppe du recul qu'il a vu (écart max %.6f)" % ecart_max, pas >= 3 and ecart_max < 1e-5)
	_check("le premier pas plonge au creux (%.3f)" % (energies[0] if not energies.is_empty() else -1.0),
		not energies.is_empty() and energies[0] < creux + 0.1)
	var croissante := true
	for i in range(1, energies.size()):
		croissante = croissante and energies[i] >= energies[i - 1] - 1e-6
	_check("puis l'énergie ne fait que remonter, pas après pas", croissante)
	# Une fusée lancée en plein recul l'allonge (`maxf`) : l'enveloppe se réarme — la lampe replonge avec le geste.
	j1.shoot_cooldown = duree
	for i in 6:
		await physics_frame
	j1.shoot_cooldown = maxf(float(j1.shoot_cooldown), duree * 3.0)
	await physics_frame
	await physics_frame
	_check("un recul allongé en cours de route se réarme : la lampe replonge (%.3f)" % float(j1.get("_energie_torche")),
		float(j1.get("_energie_torche")) < creux + 0.1)
	j1.shoot_cooldown = 0.0
	pantin.torche = false


# ---------------------------------------------------------------------------
# OUTILS
# ---------------------------------------------------------------------------

func _lumieres_enfants(corps: Node) -> Array:
	var sortie := []
	for c in corps.get_children():
		if c is PointLight2D:
			sortie.append(c)
	return sortie


## Le mur le plus proche dans les quatre directions de la carte : {direction, point} (la face touchée), ou vide.
func _mur_le_plus_proche(depuis: Vector2) -> Dictionary:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var meilleur := {}
	var meilleure_d := INF
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var q := PhysicsRayQueryParameters2D.create(depuis, depuis + dir * 4000.0, 1)
		q.exclude = _corps()
		var coup := espace.intersect_ray(q)
		if coup.is_empty():
			continue
		var d := depuis.distance_to(coup["position"])
		if d < meilleure_d:
			meilleure_d = d
			meilleur = {"direction": dir, "point": coup["position"]}
	return meilleur


## Un point de la carte d'où aucun mur n'est à moins de 60 px, dans aucune direction.
func _point_libre(j1: Node2D) -> Vector2:
	var espace := j1.get_world_2d().direct_space_state
	for y in range(200, 1200, 35):
		for x in range(200, 1600, 35):
			var p := Vector2(x, y)
			var libre := true
			for k in 8:
				if _mur_entre(espace, j1, p, p + Vector2.from_angle(TAU * k / 8.0) * 60.0):
					libre = false
					break
			if libre:
				return p
	return Vector2.INF


func _mur_entre(espace: PhysicsDirectSpaceState2D, _j: Node2D, a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	q.exclude = _corps()
	return not espace.intersect_ray(q).is_empty()


func _corps() -> Array[RID]:
	return [(_main.p1 as CollisionObject2D).get_rid(), (_main.p2 as CollisionObject2D).get_rid()]


## La visée de J1 tenue : son fournisseur d'entrées la repose à chaque pas (souris, stick) ; un pantin qui vise `dir`.
func _tenir_la_visee(j1: Node2D, dir: Vector2) -> void:
	var pantin := Pantin.new()
	pantin.visee = dir
	_main._set_player_input_provider(j1, pantin)


class Pantin extends InputProvider:
	var visee := Vector2.RIGHT
	var accroupi := false
	var torche := false

	func get_movement_vector() -> Vector2:
		return Vector2.ZERO

	func get_aim_direction(_pos: Vector2) -> Vector2:
		return visee

	func is_crouch_pressed() -> bool:
		return accroupi

	func is_flashlight_pressed() -> bool:
		return torche


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _depart_fini(main: Node) -> bool:
	var fin := Time.get_ticks_msec() + 5000
	while not (main.round_active and main.countdown_left > 0.0):
		if Time.get_ticks_msec() > fin:
			printerr("    la manche n'a pas démarré (round_active=%s, décompte=%s)" % [main.round_active, main.countdown_left])
			return false
		await physics_frame
	main.countdown_left = 0.001
	while main.countdown_left > 0.0:
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	for i in 4:
		await physics_frame
	return main.round_active


## `NetworkManager.GameMode.LOCAL_SPLITSCREEN`, lu par l'arbre : nommer l'autoload dans une suite `--script` la ferait
## compiler avant qu'il existe (piège consigné).
func _mode_local() -> int:
	var reseau := root.get_node("NetworkManager")
	return int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])
