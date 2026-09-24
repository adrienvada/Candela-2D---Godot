## ISO3a — les corps voxel des dix classes dans la vue iso du duel (brief long d'Adrien, 2026-09-14).
##
## Les corps de la vue iso ne sont plus des cylindres : ce sont les `VoxelCorps` du chantier ISO
## Corps (branche `iso-corps`, vague 2), un par joueur, choisi par sa classe, partagé par les deux
## caméras de l'écran scindé et relu par chacune avec ses propres uniformes (capteur, opacité,
## silhouette), exactement comme le corps grossier d'ISO2 et d'ISO2b.
##
## Ce que cette suite prouve, sans fenêtre :
## - un corps voxel par joueur, de sa classe, à l'échelle des pixels de la scène iso, posé et orienté
##   comme le joueur, avec ses neuf boîtes et leur passe de profondeur ;
## - les matériaux du corps sont ceux que la présentation pilote : les capteurs des deux vues liés,
##   l'opacité et la silhouette posées par vue depuis les sprites ;
## - les états du corps déduits du joueur (marche, tir, touché, mort), accroupi et enjambement à zéro
##   jusqu'à ISO3b ;
## - un changement de classe reconstruit le corps et relie ses nouveaux matériaux ;
## - aucune `Light3D`, aucun nœud 3D sous le jeu, les masques réels ~4/~2 inchangés ;
## - la simulation identique pas pour pas avec et sans corps voxel.
##
## Ce qu'elle ne prouve pas : le rendu au pixel (noir absolu, plafond, effacement, silhouette) — le
## banc `tools/banc_iso.gd` le prouve en vraie fenêtre.
extends SceneTree

const PLANCHER := 46
const PAS_SIMULES := 120

var _failures := 0
var _verifications := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ %s" % label)
	else:
		_failures += 1
		printerr("  ✗ %s%s" % [label, ("  → " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== ISO3a — LES CORPS VOXEL DANS LA VUE ISO ===")
	await process_frame
	var reglages := root.get_node("GameSettings")
	var Pres: GDScript = load("res://presentation_3d.gd")
	_check("sans classe, le corps dessiné est une classe du catalogue (repli de RENDU, jamais de statistique)",
		VoxelCatalogue.slugs().has(Pres.slug_du_corps(null)), Pres.slug_du_corps(null))
	_la_zone_de_touche()

	# ISO6 — l'iso est le défaut : la vue de dessus du témoin se demande AVANT de monter `Main`, dont
	# le premier `rebuild_arena()` accroche sinon la présentation.
	reglages.mode_iso = false
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var vp1: SubViewport = main.vp1
	var vp2: SubViewport = main.vp2

	# --- Le témoin : une partie scindée, vue de dessus, sans aucun corps voxel -------
	main.ui._intended_mode = _mode_local()
	main._on_replay_requested()
	_check("la manche scindée démarre", await _depart_fini(main))
	var temoin: Dictionary = await _jouer(main)
	_check("sans iso, aucun corps voxel dans l'arbre", root.find_children("*", "VoxelCorps", true, false).is_empty())

	# --- La vue iso, corps voxel -------------------------------------------------
	reglages.mode_iso = true
	_check("la manche iso démarre", await _nouvelle_manche(main))
	await process_frame
	await process_frame
	var p := root.get_node_or_null("Presentation3D")
	_check("la vue iso est allumée en écran scindé, corps voxel en service",
		p != null and bool(p.get("_actif")) and bool(p.get("_scinde")) and bool(p.get("corps_voxel")))
	if p == null:
		_sortir()
		return
	_les_corps(main, p)
	_les_etats(main, p)
	await _la_classe_changee(main, p)
	_rien_de_plus(main, p, vp1, vp2)

	var avec: Dictionary = await _jouer(main)
	_check("avec corps voxel, la partie a tenu ses %d pas" % PAS_SIMULES, (avec["etats"] as Array).size() == PAS_SIMULES)
	_check("simulation identique pas pour pas, avec et sans corps voxel",
		_ecarts(temoin["etats"], avec["etats"]) == 0, _premier_ecart(temoin["etats"], avec["etats"]))

	reglages.mode_iso = false
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	_sortir()


## E2 — les corps épais (vague 4 d'ISO Corps) et la zone de touche, qu'Adrien garde à 18 px (2026-09-15).
## Le corps visible SEUL de chaque classe doit tenir dans la zone de touche ; l'arme, elle, peut dépasser
## (information). Les trois constantes qui disent cette zone restent d'accord — lues dans le TEXTE des
## scripts : `Bullet` et `GadgetLeurre` nomment des autoloads, et une suite `extends SceneTree` ne peut pas
## les compiler (piège d'ISO4).
func _la_zone_de_touche() -> void:
	print("\n--- Les corps épais tiennent dans la zone de touche (18 px, décision d'Adrien) ---")
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	var zone := MursBas.RAYON_CORPS
	for chemin_constante in [["res://bullet.gd", "const PLAYER_BODY_RADIUS := "], ["res://gadget_leurre.gd", "const RAYON_CORPS := "]]:
		var texte := FileAccess.get_file_as_string(chemin_constante[0])
		var i := texte.find(chemin_constante[1])
		var valeur := texte.substr(i + String(chemin_constante[1]).length()).get_slice("\n", 0).to_float() if i >= 0 else -1.0
		_check("%s garde la zone de touche des corps (%s px)" % [String(chemin_constante[0]).get_file(), str(valeur)],
			is_equal_approx(valeur, zone), "%s contre %s" % [str(valeur), str(zone)])
	var ancre := Node3D.new()
	root.add_child(ancre)
	var pire_corps := 0.0
	var pire_total := 0.0
	var classe_pire := ""
	var dedans := 0
	for slug in VoxelCatalogue.slugs():
		var corps := VoxelCorps.new()
		ancre.add_child(corps)
		corps.construire(slug)
		corps.poser({"position": Vector2.ZERO, "visee": Vector2.RIGHT, "vitesse": Vector2.ZERO, "t": 0.0})
		var seul := corps.rayon_empreinte(true) * tuile
		var total := corps.rayon_empreinte(false) * tuile
		if seul <= zone:
			dedans += 1
		else:
			printerr("    %s : corps seul %.1f px, au-delà de %.1f" % [slug, seul, zone])
		if seul > pire_corps:
			pire_corps = seul
			classe_pire = slug
		pire_total = maxf(pire_total, total)
		corps.free()
	ancre.free()
	_check("le corps épais seul de chaque classe tient dans la zone de touche (%d/%d, pire %.1f px, %s)"
		% [dedans, VoxelCatalogue.slugs().size(), pire_corps, classe_pire], dedans == VoxelCatalogue.slugs().size())
	print("    (information) corps + arme + torche, pire cas debout : %.1f px — l'arme dépasse la zone de touche, et ne se touche pas" % pire_total)


func _les_corps(main: Node, p: Node) -> void:
	print("\n--- Un corps voxel par joueur, de sa classe, lié à ses capteurs ---")
	p._suivre()
	var voxels: Array = p.get("_voxels")
	var mats: Array = p.get("_mat_corps")
	var profs: Array = p.get("_mat_profondeur")
	var capteurs: Array = p.capteurs()
	var joueurs: Array = [main.p1, main.p2]
	var tuile := float(CandelaTileSet.TILE_SIZE.x)
	_check("deux corps voxel, un par joueur", voxels.size() == 2 and root.find_children("*", "VoxelCorps", true, false).size() == 2)
	# ⚠️ Le porteur de torche restait noir chez l'autre tant que le corps lisait le disque à sa propre
	# distance du centre (banc ISO3a) : la lecture au bord doit rester dans le shader, pas seulement l'uniform.
	var code := ((mats[0] as ShaderMaterial).shader as Shader).code if mats.size() == 2 and mats[0] is ShaderMaterial else ""
	_check("le shader du corps lit le disque au rayon lu, dans la direction du fragment (lecture_au_bord)",
		code.contains("mix(r0, rayon_lu_px, lecture_au_bord) / r0"))
	for j in 2:
		var voxel := voxels[j] as VoxelCorps
		var joueur: Node2D = joueurs[j]
		var ancre := voxel.get_parent() as Node3D
		_check("J%d : sous SceneIso/Corps%d, ancre à l'échelle d'une tuile (%s px)" % [j + 1, j + 1, str(tuile)],
			ancre != null and ancre.name == "Corps%d" % (j + 1) and ancre.scale.is_equal_approx(Vector3.ONE * tuile)
			and ancre.position == Vector3.ZERO)
		# Mis à jour le 2026-09-24 (décision d'Adrien : V3 froide par défaut) : la tenue du jeu ajoute la bouteille du portrait
		# aux six classes qui la portent — neuf boîtes, ou dix.
		var boites := 10 if VoxelCatalogue.tenue() != "" and bool(VoxelCatalogue.PORTRAITS[voxel.slug()]["bouteille"]) else 9
		_check("J%d : le corps de sa classe (%s), %d boîtes" % [j + 1, voxel.slug(), boites],
			voxel.slug() == p.slug_du_corps(joueur) and voxel.nombre_de_boites() == boites)
		var pos := voxel.global_position
		_check("J%d : posé à sa position, en pixels de monde" % (j + 1),
			absf(pos.x - joueur.global_position.x) < 0.05 and absf(pos.z - joueur.global_position.y) < 0.05
			and absf(pos.y) < 0.05, "%s contre %s" % [str(pos), str(joueur.global_position)])
		var avant := -voxel.global_transform.basis.z.normalized()
		var visee := Vector3(cos(joueur.rotation), 0.0, sin(joueur.rotation))
		_check("J%d : tourné comme sa visée" % (j + 1), avant.dot(visee) > 0.999, "%s contre %s" % [str(avant), str(visee)])
		var sommet := voxel.sommet_tete()
		_check("J%d : à hauteur de corps en pixels (sommet de la tête à %.1f px)" % [j + 1, sommet], sommet > 15.0 and sommet < 70.0)
		var mat := mats[j] as ShaderMaterial
		_check("J%d : la présentation pilote les matériaux du corps voxel (couleur et profondeur)" % (j + 1),
			mat == voxel.materiau() and profs[j] == voxel.materiau_profondeur())
		_check("J%d : capteur actif, pixels_par_unite à l'identité (la scène est déjà en pixels)" % (j + 1),
			bool(mat.get_shader_parameter("capteur_actif")) and is_equal_approx(float(mat.get_shader_parameter("pixels_par_unite")), 1.0))
		var lies := 0
		for id in 2:
			var c = capteurs[id][j]
			if c != null and mat.get_shader_parameter("capteur_%d" % (id + 1)) == (c as CapteurCorps).get_texture():
				lies += 1
		_check("J%d : les capteurs des deux vues sont liés au corps" % (j + 1), lies == 2, "%d/2" % lies)
		_check("J%d : le corps lit la lumière au bord du disque, dans la direction de chaque fragment (le croissant du sprite)" % (j + 1),
			is_equal_approx(float(mat.get_shader_parameter("lecture_au_bord")), 1.0))
		_check("J%d : centre de lecture du capteur à sa position" % (j + 1),
			(mat.get_shader_parameter("centre") as Vector2).distance_to(joueur.global_position) < 0.01)
		var par_vue := 0
		for vue_id in 2:
			var o := float(mat.get_shader_parameter("opacite_%d" % (vue_id + 1)))
			var sil = mat.get_shader_parameter("silhouette_%d" % (vue_id + 1))
			var o_prof := float((profs[j] as ShaderMaterial).get_shader_parameter("opacite_%d" % (vue_id + 1)))
			if absf(o - p.opacite_du_corps(joueur, vue_id == j)) < 0.001 and absf(o_prof - o) < 0.001 \
					and sil is Color and absf((sil as Color).a - p.silhouette_du_corps(joueur, vue_id == j).a) < 0.001:
				par_vue += 1
		_check("J%d : opacité et silhouette posées par vue depuis les sprites, sur les deux passes" % (j + 1), par_vue == 2, "%d/2" % par_vue)
		var doubles := 0
		for b in voxel.boites():
			var d := (b as Node).get_node_or_null("BoiteProfondeur") as MeshInstance3D
			if d != null and d.material_override == voxel.materiau_profondeur() and (b as VisualInstance3D).layers == 1:
				doubles += 1
		# Mis à jour le 2026-09-24 (V3 froide par défaut) : la bouteille a sa passe de profondeur comme les autres boîtes — neuf
		# ou dix selon la classe, jamais un compte fixe.
		_check("J%d : chaque boîte a sa passe de profondeur, sur le calque commun" % (j + 1),
			doubles == voxel.nombre_de_boites() and voxel.materiau_profondeur().render_priority < voxel.materiau().render_priority,
			"%d/%d" % [doubles, voxel.nombre_de_boites()])


func _les_etats(main: Node, p: Node) -> void:
	print("\n--- Les états du corps, déduits du joueur ---")
	var j2: Node2D = main.p2
	var sauve := {"velocity": j2.get("velocity"), "hp": j2.get("hp"), "shoot_cooldown": j2.get("shoot_cooldown"),
		"dead": j2.get("dead"), "flashlight_on": j2.get("flashlight_on")}
	var e: Dictionary = p.etat_du_corps(1, j2)
	_check("au repos : ni tir, ni touché, ni mort ; accroupi et enjambement à zéro (ISO3b)",
		not bool(e["tir"]) and not bool(e["touche"]) and not bool(e["mort"]) and not bool(e["accroupi"])
		and is_zero_approx(float(e["enjambe"])))
	_check("la position et la visée sont celles du joueur",
		(e["position"] as Vector2) == j2.global_position
		and (e["visee"] as Vector2).is_equal_approx(Vector2(cos(j2.rotation), sin(j2.rotation))))
	j2.set("velocity", Vector2(120.0, 0.0))
	_check("la vitesse est celle du joueur (marche)", (p.etat_du_corps(1, j2)["vitesse"] as Vector2) == Vector2(120.0, 0.0))
	j2.set("flashlight_on", not bool(sauve["flashlight_on"]))
	_check("la torche suit celle du joueur", bool(p.etat_du_corps(1, j2)["torche"]) == bool(j2.get("flashlight_on")))
	j2.set("shoot_cooldown", float(sauve["shoot_cooldown"]) + 0.5)
	_check("un temps de recharge qui repart : le corps tire", bool(p.etat_du_corps(1, j2)["tir"]))
	j2.set("hp", float(sauve["hp"]) - 10.0)
	_check("des points de vie qui baissent : le corps est touché", bool(p.etat_du_corps(1, j2)["touche"]))
	j2.set("dead", true)
	var em: Dictionary = p.etat_du_corps(1, j2)
	_check("mort : le corps le sait, et son temps repart de zéro", bool(em["mort"]) and float(em["t"]) < 0.5, "t=%.3f" % float(em["t"]))
	for k in sauve:
		j2.set(k, sauve[k])
	p.etat_du_corps(1, j2)


func _la_classe_changee(main: Node, p: Node) -> void:
	print("\n--- Une autre classe : un autre corps, relié ---")
	var j2: Node2D = main.p2
	var arme_avant = j2.get("current_weapon")
	var avant: String = p.slug_du_corps(j2)
	var autre: Variant = null
	for i in range(20):
		var c = main.weapon_for_index(i)
		if c is ClassData and String((c as ClassData).slug()) != avant and VoxelCatalogue.slugs().has(String((c as ClassData).slug())):
			autre = c
			break
	_check("une autre classe existe au catalogue du jeu", autre != null)
	if autre == null:
		return
	j2.equip_weapon(autre)
	p._suivre()
	var voxel := (p.get("_voxels") as Array)[1] as VoxelCorps
	var mat := (p.get("_mat_corps") as Array)[1] as ShaderMaterial
	var capteurs: Array = p.capteurs()
	_check("le corps est reconstruit dans la nouvelle classe (%s → %s)" % [avant, voxel.slug()],
		voxel.slug() == String((autre as ClassData).slug()))
	_check("ses nouveaux matériaux sont pilotés, capteurs reliés",
		mat == voxel.materiau() and (p.get("_mat_profondeur") as Array)[1] == voxel.materiau_profondeur()
		and capteurs[0][1] != null and mat.get_shader_parameter("capteur_1") == (capteurs[0][1] as CapteurCorps).get_texture()
		and capteurs[1][1] != null and mat.get_shader_parameter("capteur_2") == (capteurs[1][1] as CapteurCorps).get_texture()
		and bool(mat.get_shader_parameter("capteur_actif")))
	if arme_avant != null:
		j2.equip_weapon(arme_avant)
	p._suivre()
	await process_frame


func _rien_de_plus(main: Node, p: Node, vp1: SubViewport, vp2: SubViewport) -> void:
	print("\n--- Rien de plus : pas de lumière 3D, pas de 3D sous le jeu, masques inchangés ---")
	_check("aucune Light3D dans l'arbre", root.find_children("*", "Light3D", true, false).is_empty())
	_check("aucun nœud 3D sous GameState ni sous Player*", _noeuds_3d_sous(main) == 0)
	var couches := int(p.get("COUCHES_HORS_LIGHTMAP"))
	_check("lightmap de J1 : masque réel ~4, sans les couches des capteurs",
		vp1.canvas_cull_mask == ((~4 & 0xFFFFFFFF) & ~couches), str(vp1.canvas_cull_mask))
	_check("lightmap de J2 : masque réel ~2, sans les couches des capteurs",
		vp2.canvas_cull_mask == ((~2 & 0xFFFFFFFF) & ~couches), str(vp2.canvas_cull_mask))


# --- Aides reprises de tools/test_iso_vues.gd ---------------------------------------------

func _jouer(main: Node) -> Dictionary:
	# ⚠️ Toute partie commence au DÉBUT d'un pas de physique ; visée au stick, ni torche ni tir :
	# voir `tools/test_iso_vues.gd`, d'où cette partie est reprise telle quelle.
	await physics_frame
	var p1: Node2D = main.p1
	var p2: Node2D = main.p2
	p1.global_position = main._get_spawn_position(0)
	p2.global_position = main._get_spawn_position(1)
	p1.rotation = 0.0
	p2.rotation = PI
	p1.set("velocity", Vector2.ZERO)
	p2.set("velocity", Vector2.ZERO)
	var etats: Array = []
	Input.action_press("p1_aim_up")
	Input.action_press("p2_aim_down")
	for pas in PAS_SIMULES:
		Input.action_press("p1_move_right" if pas < PAS_SIMULES / 2 else "p1_move_down")
		Input.action_press("p2_move_left" if pas < PAS_SIMULES / 2 else "p2_move_up")
		if pas == PAS_SIMULES / 2:
			Input.action_release("p1_move_right")
			Input.action_release("p2_move_left")
		await physics_frame
		etats.append([p1.global_position, snappedf(p1.rotation, 1e-6), p1.hp, p1.flashlight_on,
			p2.global_position, snappedf(p2.rotation, 1e-6), p2.hp])
	for action in ["p1_move_right", "p1_move_down", "p2_move_left", "p2_move_up", "p1_aim_up", "p2_aim_down"]:
		Input.action_release(action)
	return {"etats": etats}


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


func _nouvelle_manche(main: Node) -> bool:
	main._start_round()
	return await _depart_fini(main)


func _ecarts(a: Array, b: Array) -> int:
	var n := absi(a.size() - b.size())
	for i in mini(a.size(), b.size()):
		if str(a[i]) != str(b[i]):
			n += 1
	return n


func _premier_ecart(a: Array, b: Array) -> String:
	for i in mini(a.size(), b.size()):
		if str(a[i]) != str(b[i]):
			return "pas %d : %s ≠ %s" % [i, str(a[i]), str(b[i])]
	return "tailles %d / %d" % [a.size(), b.size()] if a.size() != b.size() else "aucun"


func _mode_local() -> int:
	var reseau := root.get_node("NetworkManager")
	return int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])


func _noeuds_3d_sous(main: Node) -> int:
	var n := 0
	var noeuds: Array[Node] = [main]
	while not noeuds.is_empty():
		var x: Node = noeuds.pop_back()
		if x is Node3D:
			n += 1
		noeuds.append_array(x.get_children())
	return n


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
