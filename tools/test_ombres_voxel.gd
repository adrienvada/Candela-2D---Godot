## OMBRES, OM2 — l'étoile d'un corps à la forme de son CORPS VOXEL (Q82, décision d'Adrien du 2026-10-05 : « Oui »).
##
##   • **la forme**, pour les dix classes (`VoxelCatalogue.etoile_d_ombre`) : 32 rayons, une aire signée positive (celle que le
##     culling d'OM1 attend), pas de pointe d'arme devant le corps (« l'arme portée sans pointe au sol »), les bras sur les côtés,
##     le gadget — et la bouteille des classes qui la portent — derrière ;
##   • **la garde de dérive** : les rectangles que l'étoile échantillonne sont ceux des boîtes d'un VRAI `VoxelCorps`, vues de
##     dessus, au repos (le patron de `test_lampe_modele`) — un squelette qui change sans l'étoile la fait rougir ;
##   • **le cercle provisoire** de `Player._ready` n'écrase plus l'étoile d'un corps équipé avant d'entrer dans l'arbre ;
##   • **l'ombre de contact des figurants** (les PNJ de l'aventure), en vue iso : la même que celle de J1 et J2, sur le sol de
##     chaque vue, à la force de leur opacité dans la vue.
## Ce que l'étoile fait à l'image se voit au banc des ombres (`tools/planche_ombres.gd`).
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_ombres_voxel.gd
extends SceneTree

const Format := preload("res://aventure_format.gd")
const Progression := preload("res://aventure_progression.gd")
const ESSAI := "res://tools/aventure_essai"
const SOLO_DE_LA_SUITE := "user://test_ombres_voxel_solo.cfg"
const PH_JEU := 1
const TUILE := 35.0

var _failures := 0
var _verifications := 0
var main: Node = null


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
	print("=== OMBRES, OM2 : L'ÉTOILE À LA FORME DU CORPS VOXEL ===")
	await process_frame
	_la_forme()
	await _la_garde_de_derive()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	await _le_cercle_provisoire()
	await _le_contact_des_figurants()
	_sortir()


# ---------------------------------------------------------------------------
# LA FORME
# ---------------------------------------------------------------------------

func _la_forme() -> void:
	print("\n--- La forme, pour les dix classes ---")
	var detail := ""
	var toutes := true
	var distinctes := {}
	for slug in VoxelCatalogue.slugs():
		var e := VoxelCatalogue.etoile_d_ombre(slug)
		var s := VoxelCatalogue.fiche(slug)
		var echelle: float = s["echelle"]
		# Les côtés : le bord du bras, `l_torse / 2 + l_bras`, le long de ±y.
		var cote := (float(s["largeur_torse"]) * echelle * 0.5 + float(s["largeur_bras"]) * echelle) * TUILE
		# L'avant : la tête ou le torse, jamais la main (`avant_main`, où l'arme commence).
		var avant := maxf(float(s["cote_tete"]), float(s["profondeur_torse"])) * echelle * 0.5 * TUILE
		var main_px := float(s["avant_main"]) * TUILE
		var ok := e.size() == VoxelCatalogue.RAYONS_ETOILE and not Geometry2D.is_polygon_clockwise(e) \
			and absf(e[0].x - avant) < 0.01 and e[0].x < main_px - 3.0 \
			and absf(e[8].y - cote) < 0.01 and absf(e[24].y + cote) < 0.01 \
			and e[16].x < -avant
		for p in e:
			ok = ok and p.length() >= VoxelCatalogue.RAYON_ETOILE_MIN - 0.001
		if not ok:
			toutes = false
			detail += "%s (avant %.1f, côté %.1f, arrière %.1f) " % [slug, e[0].x, e[8].y, e[16].x]
		distinctes[str(e)] = true
	_check("dix étoiles de 32 rayons, d'aire signée positive ; devant, la tête ou le torse (5 à 6 px) et pas la main (10,5 px) : "
		+ "aucune pointe d'arme ; sur les côtés, le bord des bras ; derrière, le gadget ou la bouteille", toutes, detail)
	_check("des classes au gabarit différent ont des étoiles différentes (%d formes pour dix classes)" % distinctes.size(),
		distinctes.size() >= 5)
	_check("une classe inconnue rend une étoile vide, sans cri", VoxelCatalogue.etoile_d_ombre("inconnue").is_empty())
	_check("l'étoile se met en cache : le même tableau à chaque appel",
		VoxelCatalogue.etoile_d_ombre("fusil") == VoxelCatalogue.etoile_d_ombre("fusil"))
	# La bouteille compte, lue sur la classe : le Parasite la porte, l'Illusionniste non — et la forme ne dépend pas de la tenue.
	var avec := VoxelCatalogue.rectangles_au_sol(VoxelCatalogue.fiche("pistolet")).size()
	var sans := VoxelCatalogue.rectangles_au_sol(VoxelCatalogue.fiche("fusil")).size()
	_check("la bouteille est un rectangle de plus pour les classes qui la portent (%d contre %d)" % [avec, sans], avec == sans + 1)


# ---------------------------------------------------------------------------
# LA GARDE DE DÉRIVE
# ---------------------------------------------------------------------------

## Les rectangles de l'étoile sont-ils ceux des boîtes d'un vrai corps ? Chaque boîte d'un `VoxelCorps` construit au repos — sauf
## l'arme et la torche — vue de dessus, dans le repère (avant, droite), doit être l'un d'eux, et réciproquement.
func _la_garde_de_derive() -> void:
	print("\n--- La garde de dérive : les boîtes d'un vrai corps voxel, vues de dessus ---")
	var VoxelCorps: GDScript = load("res://voxel_corps.gd")
	var ecarts := ""
	var toutes := true
	for slug in VoxelCatalogue.slugs():
		var corps: Node3D = VoxelCorps.new()
		root.add_child(corps)
		if not corps.construire(slug):
			toutes = false
			ecarts += "%s (construction) " % slug
			corps.queue_free()
			continue
		await process_frame
		# Le repère LOCAL du corps : le nœud lui-même peut être tourné (il l'est d'un demi-tour à la construction).
		var vers_local: Transform3D = corps.global_transform.affine_inverse()
		var reelles: Array[Rect2] = []
		for b in corps.boites():
			var inst: MeshInstance3D = b
			var parent := String(inst.get_parent().name)
			if parent == "Arme" or parent == "Torche":
				continue
			var demi: Vector3 = (inst.mesh as BoxMesh).size * 0.5
			var mini := Vector2(INF, INF)
			var maxi := Vector2(-INF, -INF)
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						var c: Vector3 = vers_local * (inst.global_transform * Vector3(demi.x * sx, demi.y * sy, demi.z * sz))
						var q := Vector2(-c.z, c.x)
						mini = Vector2(minf(mini.x, q.x), minf(mini.y, q.y))
						maxi = Vector2(maxf(maxi.x, q.x), maxf(maxi.y, q.y))
			reelles.append(Rect2(mini, maxi - mini))
		var catalogue := VoxelCatalogue.rectangles_au_sol(VoxelCatalogue.fiche(slug))
		var memes := reelles.size() == catalogue.size()
		for r in reelles:
			var trouve := false
			for c in catalogue:
				# 0,01 tuile (0,35 px) : le gadget de certaines classes a un geste au repos (`VoxelCorps._geste_gadget`), qui fait
				# varier sa boîte de quelques millièmes de tuile — un squelette qui change, lui, se compte en centièmes.
				trouve = trouve or (r.position.distance_to(c.position) < 0.01 and r.size.distance_to(c.size) < 0.01)
			memes = memes and trouve
		if not memes:
			toutes = false
			ecarts += "%s (%d boîtes, %d rectangles) " % [slug, reelles.size(), catalogue.size()]
		corps.queue_free()
		await process_frame
	_check("pour les dix classes, les rectangles de l'étoile sont exactement les boîtes du corps au repos (sans arme ni torche)",
		toutes, ecarts)
	var vc := (VoxelCorps as GDScript).get_script_constant_map()
	_check("l'angle des bras au repos est celui du corps voxel (%.2f rad)" % VoxelCatalogue.GARDE_BRAS_REPOS,
		is_equal_approx(float(vc["GARDE_BRAS"]), VoxelCatalogue.GARDE_BRAS_REPOS))


# ---------------------------------------------------------------------------
# LE CERCLE PROVISOIRE
# ---------------------------------------------------------------------------

## Un corps équipé AVANT d'entrer dans l'arbre : `_ready` l'équipe (et pose son étoile), puis posait le cercle provisoire de 18 px
## par-dessus — qui restait jusqu'au changement d'arme suivant.
func _le_cercle_provisoire() -> void:
	print("\n--- Le cercle provisoire de `_ready` n'écrase plus l'étoile ---")
	var k := -1
	for i in 10:
		var w = main.weapon_for_index(i)
		if w != null and w.has_method("slug") and String(w.slug()) == "pompe":
			k = i
	_check("(la classe « pompe » existe)", k >= 0)
	if k < 0:
		return
	var j: Node2D = (load("res://player.tscn") as PackedScene).instantiate()
	j.name = "CorpsDeLaSuite"
	j.set("player_id", 1)
	j.set("current_weapon", main.weapon_for_index(k))
	main.add_child(j)
	await _images(2)
	var occ: LightOccluder2D = j.call("etoile")
	var attendue := VoxelCatalogue.etoile_d_ombre("pompe")
	_check("équipé avant d'entrer dans l'arbre, il garde l'étoile de sa classe (%d sommets), pas le cercle de 16"
		% (occ.occluder.polygon.size() if occ != null and occ.occluder != null else -1),
		occ != null and occ.occluder != null and occ.occluder.polygon == attendue)
	j.queue_free()
	await _images(2)


# ---------------------------------------------------------------------------
# L'OMBRE DE CONTACT DES FIGURANTS
# ---------------------------------------------------------------------------

func _le_contact_des_figurants() -> void:
	print("\n--- L'ombre de contact des figurants, en vue iso ---")
	for chemin in ["res://sol_iso.gdshader", "res://sol_iso_eclaire.gdshader", "res://volume_masque.gdshaderinc"]:
		var code := FileAccess.get_file_as_string(chemin)
		_check("%s porte le tableau des figurants et sa boucle" % chemin.get_file(),
			code.contains("uniform vec3 contact_figurants[%d];" % 8) and code.contains("for (int k = 0; k < contact_nb_figurants; k++)"))
	var p3d := (load("res://presentation_3d.gd") as GDScript).get_script_constant_map()
	_check("le tableau a une place par figurant possible (%d)" % int(p3d["FIGURANTS_MAX"]),
		int(p3d["CONTACTS_FIGURANTS_MAX"]) == int(p3d["FIGURANTS_MAX"]) and int(p3d["FIGURANTS_MAX"]) == 8)
	var vol := (load("res://iso_volumes.gd") as GDScript).get_script_constant_map()
	_check("les volumes le recopient à chaque image, comme le contact des joueurs",
		(vol["CONTACT_PAR_IMAGE"] as Array).has("contact_figurants") and (vol["CONTACT_PAR_IMAGE"] as Array).has("contact_nb_figurants"))
	# Une vraie salle, en iso : trois PNJ.
	var fichier := ProjectSettings.globalize_path(SOLO_DE_LA_SUITE)
	if FileAccess.file_exists(SOLO_DE_LA_SUITE):
		DirAccess.remove_absolute(fichier)
	root.get_node("GameSettings").mode_iso = true
	Format.racine = ESSAI
	Format.niveaux_attendus = 0
	Format.oublier_le_cache()
	var chapitre := Format.charger_chapitre(ESSAI.path_join("chapitre_00"), 0)
	var brut := Format.lire_chapitre(ESSAI.path_join("chapitre_00"))
	if chapitre.is_empty() or brut.is_empty():
		_check("(le chapitre d'essai se charge)", false)
		return
	var niveau: Dictionary = (brut["niveaux"][0] as Dictionary).duplicate(true)
	niveau["pnj"] = [{"case": [8, 5], "orientation": 0, "profil": "immobile_sourd_aveugle", "classe": "fusil"},
		{"case": [8, 8], "orientation": 0, "profil": "immobile_sourd_aveugle", "classe": "pompe"},
		{"case": [8, 11], "orientation": 0, "profil": "immobile_sourd_aveugle", "classe": "spectre"}]
	niveau["boss"] = false
	var c := chapitre.duplicate(true)
	c["niveaux"] = [Format.preparer_niveau(niveau)]
	c["niveaux"][0]["fichier"] = "fabrique.json"
	main.ui.aventure_progression = Progression.new(SOLO_DE_LA_SUITE)
	main.archiver_les_matchs = false
	main.graine_du_bot = 4242
	main.demarrer_l_aventure(c, 0, "pistolet", main.ui.aventure_progression)
	await _images(3)
	var partie: Node = main.aventure
	var fin := 300
	while partie != null and partie.phase != PH_JEU and fin > 0:
		await process_frame
		fin -= 1
	await _images(3)
	var pres: Node = (load("res://presentation_3d.gd") as GDScript).call("instance")
	_check("(la vue iso est montée, trois PNJ dans la salle)", pres != null and partie != null and (partie.pnj as Array).size() == 3)
	if pres == null or partie == null or (partie.pnj as Array).size() != 3:
		return
	var mats: Array = pres.get("_mat_sols")
	var juste := not mats.is_empty()
	var detail := ""
	for m: ShaderMaterial in mats:
		var n := _nb_contacts(m)
		var t := _contacts(m)
		juste = juste and n == 3
		for k in 3:
			var pnj: Node2D = partie.pnj[k]
			var attendue := float((load("res://presentation_3d.gd") as GDScript).call("opacite_du_corps", pnj, false))
			var ok := k < n and Vector2(t[k].x, t[k].y).distance_to(pnj.global_position) < 0.01 and absf(t[k].z - attendue) < 0.001
			juste = juste and ok
			if not ok:
				detail += "%s : %s contre %s/%.3f ; " % [pnj.name, str(t[k]) if k < n else "absent", str(pnj.global_position), attendue]
	_check("sur le sol de chaque vue, les trois PNJ ont leur ombre de contact, à leur pied, à la force de leur opacité", juste, detail)
	# Un PNJ caché n'en pose plus.
	(partie.pnj[1] as Node2D).visible = false
	await _images(2)
	_check("un PNJ caché n'en pose plus (deux ombres)", _nb_contacts(mats[0]) == 2)
	(partie.pnj[1] as Node2D).visible = true
	await _images(2)
	# Un PNJ qui éblouit J1 s'efface à ses yeux (Q81) : son ombre de contact pâlit avec lui — elle ne le trahit pas.
	var eblouisseur: Node2D = partie.pnj[0]
	main.p1.apply_dazzle(1.0, eblouisseur)
	await _images(3)
	var o_ebl := float((load("res://presentation_3d.gd") as GDScript).call("opacite_du_corps", eblouisseur, false))
	var t_ebl := _contacts(mats[0])
	var trouve := false
	for k in _nb_contacts(mats[0]):
		if Vector2(t_ebl[k].x, t_ebl[k].y).distance_to(eblouisseur.global_position) < 0.01:
			trouve = absf(t_ebl[k].z - o_ebl) < 0.001
	_check("le PNJ qui éblouit J1 s'efface à ses yeux (%.3f) : son ombre de contact n'a plus que cette force" % o_ebl,
		o_ebl < 0.5 and trouve)
	main.p1.dazzle_amount = 0.0
	main._on_main_menu_requested()
	await _images(3)
	root.get_node("GameSettings").mode_iso = false


## Le nombre d'ombres de contact de figurants qu'un sol a reçues — 0 si on ne les lui a jamais posées : un uniforme jamais écrit
## se lit `null`, et `int(null)` est une erreur de script qui arrêterait la fonction avant ses contrôles (vu par un sabotage).
func _nb_contacts(m: ShaderMaterial) -> int:
	var brut: Variant = m.get_shader_parameter("contact_nb_figurants")
	return int(brut) if brut != null else 0


func _contacts(m: ShaderMaterial) -> PackedVector3Array:
	var brut: Variant = m.get_shader_parameter("contact_figurants")
	return brut if brut is PackedVector3Array else PackedVector3Array()


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
