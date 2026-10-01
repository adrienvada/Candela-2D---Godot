## Chantier « Gadgets en volume », GV2 — LES NAPPES AU SOL EN VOXELS, À L'ESSAI (éteint par défaut).
##
## Adrien, Q70 (2026-09-30 : « oui ») : la suite, dans l'ordre proposé — « les nappes au sol : les braises en petits cubes
## rougeoyants qui scintillent, les traces de poudre en grains » ; ordonnée par la coordinatrice le 2026-10-01, « uniforme
## avec la fumée en cubes et ses volutes », et rien par défaut sans le mot d'Adrien.
##
## Ce que cette suite prouve, sans fenêtre, sur une vraie manche iso en écran scindé, nappes posées par le VRAI chemin
## (`GameState._do_spawn_gadget`), traces posées par la poudre elle-même (`_poser_marque`) :
##
## **Sans l'essai (le défaut)** — le jeu publié : les deux couches de chaque nappe, les seize lueurs des braises, les traces
## au sol ; aucun cube de nappe, aucun grain, le dessin des nappes et les traces dans la lightmap.
##
## **L'essai, variante « tas »** — chaque nappe est un tas bas de cubes FINS, une grille par vue (le calque et la lightmap de
## SA caméra) et son juge, dans la langue de la fumée : le même shader, le relief et l'encre du DESSIN d'origine (les
## volutes, Q73), une nappe qui ne coule pas (ni respiration ni dérive) et dont les colonnes ont leur grain ; sous lui, son
## dessin en APLAT FLOU (même taille, même alpha, ses traits fins fondus, sa lumière gardée). Les braises de la nappe sont
## des cubes du tas qui rougeoient : les MÊMES points que les seize lueurs (même graine, même suite de tirages), à leur
## éclat (la lumière de la nappe : éteinte, plus de braise), à l'âge du gadget. Plus de lueurs ni de couches.
## **Variante « braises »** — la nappe reste au sol (dessin, couches) ; ses braises SEULES sont des cubes, sans juge.
## **Les traces** — chaque trace qui luit devient trois grains (un `MultiMesh` sur le calque commun), de sa couleur à son
## éclat, posés sur le tas de poudre ou au sol ; la trace 2D sort de la lightmap tant que ses grains la portent et y revient
## quand l'essai s'éteint ; les traces de la killcam ont leurs grains, celles du présent cachées pendant le rejeu non.
## **Équité** — les deux vues reçoivent tous les mêmes réglages, au choix de leur vue près. **L'horloge** — l'âge du gadget,
## rejoué par la killcam (une copie de killcam à âge rejoué). **Rien du jeu ne change** — couper les images, ou l'essai, ne
## change aucune lumière 2D, aucun capteur, aucun joueur.
##
## Ce qu'elle ne prouve pas : le noir À L'ÉCRAN et le coût — le banc `tools/banc_gadgets_volume.gd` (`--mode=noir_nappes`,
## `--mode=cout_nappes`) les mesure en vraie fenêtre.
##
## Lancée DEUX fois par `run_suites.sh` : sans drapeau (le jeu publié, puis l'essai par la bascule des bancs) et sous
## `--nappes-voxels=braises` (l'essai lu au lancement).
extends SceneTree

const PLANCHER := 84
const PLANCHER_DRAPEAU := 77
const CARTE := "res://tools/cartes/murs_bas_essai.json"
const NAPPES := ["nappe_braises", "poudre_contact"]

var _failures := 0
var _verifications := 0
## Ce que le drapeau de la prise demande, lu comme le jeu le lit.
var _essai := false
var _variante := "tas"
## Les lueurs des braises du jeu publié, relevées sans l'essai pour une nappe posée en `_LIEU_BRAISES` : [x, z].
var _lueurs: Array = []


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
	for arg in DrapeauxDeLancement.arguments():
		if arg == IsoVolumes.DRAPEAU_NAPPES_VOXELS:
			_essai = true
		elif arg.begins_with(IsoVolumes.DRAPEAU_NAPPES_VOXELS + "="):
			_essai = true
			_variante = arg.get_slice("=", 1)
	print("=== LES NAPPES AU SOL EN VOXELS (GV2, à l'essai) — %s ===" % (("drapeau : variante « %s »" % _variante)
		if _essai else "sans drapeau"))
	await process_frame
	_le_drapeau()
	_les_reglages()
	_l_aplat_flou()
	await _dans_la_manche()
	_le_shader()
	var plancher := PLANCHER_DRAPEAU if _essai else PLANCHER
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, plancher], _verifications >= plancher)
	_sortir()


# ---------------------------------------------------------------------------
# LE DRAPEAU ET LES RÉGLAGES
# ---------------------------------------------------------------------------

func _le_drapeau() -> void:
	print("\n[Le drapeau : l'essai éteint par défaut]")
	var v := IsoVolumes.new()
	_check("l'état lu au lancement est celui que demande le drapeau de la prise (essai %s, « %s »)" % [str(_essai), _variante],
		v.nappes_voxel == _essai and v.variante_nappes == (_variante if _essai else IsoNuageVoxel.VARIANTE_NAPPES_PAR_DEFAUT),
		"%s / %s" % [str(v.nappes_voxel), v.variante_nappes])
	if not _essai:
		_check("SANS drapeau, les nappes sont celles du jeu publié : rien ne devient le défaut sans le mot d'Adrien",
			not v.nappes_voxel)
	v.free()
	var src := FileAccess.get_file_as_string("res://iso_volumes.gd")
	_check("le drapeau se lit par la porte commune des drapeaux (avant comme après --)",
		src.contains("for arg in DrapeauxDeLancement.arguments():")
		and src.contains("\t\telif arg == DRAPEAU_NAPPES_VOXELS:\n\t\t\tnappes_voxel = true")
		and src.contains("\t\telif arg.begins_with(DRAPEAU_NAPPES_VOXELS + \"=\"):"))
	_check("le jeu dit ce qu'il dessine, dans les deux états (une prise prouve son bras par le journal)",
		src.contains("[nappes voxel] à l'essai, variante « %s »")
		and src.contains("[nappes voxel] éteintes (%s pour l'essai) — les couches et les lueurs d'avant"))
	var gadget := _fonction_gd(src, "_suivre_gadget")
	_check("le chemin des nappes en voxels n'est atteint QUE sous l'essai",
		gadget.contains("\tvar nappe := nappes_voxel and IsoNuageVoxel.est_nappe(slug)\n")
		and gadget.contains("\telif nappe and variante_nappes == \"tas\":\n\t\t_suivre_nappe_en_voxels(g, slug, vus, false)\n")
		and gadget.contains("\t\t\tif not nappe:\n\t\t\t\t_suivre_braises(g, vus)\n\t\t\telif variante_nappes == \"braises\":\n\t\t\t\t_suivre_nappe_en_voxels(g, slug, vus, true)\n")
		and src.count("_suivre_nappe_en_voxels(") == 3)
	_check("… et les grains des traces aussi", _fonction_gd(src, "suivre").contains(
		"\t\tif nappes_voxel:\n\t\t\t_suivre_traces(main, arene, vus)\n") and src.count("_suivre_traces(") == 2)
	_check("… et son préchauffage aussi", _fonction_gd(src, "_init").contains(
		"\tif nappes_voxel:\n\t\tprint(\"[nappes voxel] à l'essai") and _fonction_gd(src, "_init").count(
		"IsoNuageVoxel.prechauffer_nappes()") == 1)


func _les_reglages() -> void:
	print("\n[Les réglages des nappes]")
	_check("deux nappes, deux variantes (« tas », « braises »), « tas » par défaut de l'essai",
		IsoNuageVoxel.NAPPES.keys() == NAPPES and IsoNuageVoxel.VARIANTES_NAPPES == ["tas", "braises"]
		and IsoNuageVoxel.VARIANTE_NAPPES_PAR_DEFAUT == "tas")
	_check("une nappe n'est pas un nuage (les deux tables sont disjointes), et toutes deux ont un volume de couches au jeu publié",
		NAPPES.all(func(n): return (IsoNuageVoxel.est_nappe(n) and not IsoNuageVoxel.NUAGES.has(n)
			and IsoVolumes.VOLUMES.has(n))) and not IsoNuageVoxel.est_nappe("cartouche_suie"))
	_check("des cubes FINS (un huitième de tuile), quelle que soit la taille de la fumée",
		NAPPES.all(func(n): return (is_equal_approx(IsoNuageVoxel.voxel_de(n, "gros"), IsoVolumes.TUILE / 8.0)
			and is_equal_approx(IsoNuageVoxel.voxel_de(n, "fin"), IsoVolumes.TUILE / 8.0)))
		and is_equal_approx(IsoNuageVoxel.voxel_de("cartouche_suie", "gros"), IsoVolumes.TUILE / 4.0))
	var b: Dictionary = IsoNuageVoxel.NAPPES["nappe_braises"]
	var po: Dictionary = IsoNuageVoxel.NAPPES["poudre_contact"]
	_check("des tas BAS : les braises d'un quart de tuile (deux rangées de cubes), la poudre d'un huitième (une rangée)",
		IsoNuageVoxel.rangees(float(b["hauteur"]) * IsoVolumes.TUILE, IsoVolumes.TUILE / 8.0) == 2
		and IsoNuageVoxel.rangees(float(po["hauteur"]) * IsoVolumes.TUILE, IsoVolumes.TUILE / 8.0) == 1)
	_check("de la MATIÈRE, pas un voile : des cubes pleins ; le rayon de la grille couvre l'image de la nappe (68 et 110 px)",
		float(b["alpha"]) == 1.0 and float(po["alpha"]) == 1.0 and float(b["rayon_max"]) >= 68.0
		and float(po["rayon_max"]) >= 110.0)
	_check("autant de braises que de lueurs à remplacer", IsoNuageVoxel.BRAISES_MAX == IsoVolumes.POINTS_BRAISES)
	var mb := IsoNuageVoxel.materiau("nappe_braises", 0, IsoVolumes.TUILE / 8.0, float(b["hauteur"]) * IsoVolumes.TUILE, -2)
	var mp := IsoNuageVoxel.materiau("poudre_contact", 1, IsoVolumes.TUILE / 8.0, float(po["hauteur"]) * IsoVolumes.TUILE, -2)
	var ms := IsoNuageVoxel.materiau("cartouche_suie", 0, IsoVolumes.TUILE / 4.0, 28.0, -2)
	_check("une nappe ne coule pas (ni respiration ni dérive du dessin) et ses colonnes ont leur grain ; un nuage, si",
		float(mb.get_shader_parameter("respiration")) == 0.0 and float(mb.get_shader_parameter("derive_dessin")) == 0.0
		and is_equal_approx(float(mb.get_shader_parameter("grain")), float(b["grain"]))
		and is_equal_approx(float(mp.get_shader_parameter("grain")), float(po["grain"]))
		and float(ms.get_shader_parameter("respiration")) == 1.0 and float(ms.get_shader_parameter("grain")) == 0.0
		and is_equal_approx(float(ms.get_shader_parameter("derive_dessin")), IsoNuageVoxel.DERIVE_DESSIN))
	# La température : une nappe est un dessin AU SOL, le jeu publié la montre par le sol — sa température graduée (ISO7b) ;
	# un nuage garde la sienne, celle des couches (la teinte chaude partout, seuils nuls).
	var beaute := IsoMateriaux.beaute_active()
	var graduee := func(m: ShaderMaterial) -> bool:
		return is_equal_approx(float(m.get_shader_parameter("temperature")), IsoMateriaux.TEMPERATURE_GRADUEE if beaute else 0.0) \
			and is_equal_approx(float(m.get_shader_parameter("temperature_seuil_bas")), IsoMateriaux.TEMPERATURE_SEUIL_BAS) \
			and is_equal_approx(float(m.get_shader_parameter("temperature_seuil_haut")),
				IsoMateriaux.TEMPERATURE_SEUIL_HAUT if beaute else 0.0)
	_check("une nappe prend la température GRADUÉE du sol (ISO7b) ; un nuage garde celle des couches",
		graduee.call(mb) and graduee.call(mp)
		and is_equal_approx(float(ms.get_shader_parameter("temperature")), IsoMateriaux.TEMPERATURE if beaute else 0.0)
		and float(ms.get_shader_parameter("temperature_seuil_bas")) == 0.0
		and float(ms.get_shader_parameter("temperature_seuil_haut")) == 0.0)
	_check("une nappe a l'encre et le relief de la fumée (les volutes, Q73 ; le relief du dessin), le même plancher",
		int(mb.get_shader_parameter("encre_style")) == int(IsoNuageVoxel.ENCRES["volutes"])
		and int(mb.get_shader_parameter("relief_style")) == int(IsoNuageVoxel.RELIEFS["dessin"])
		and is_equal_approx(float(mb.get_shader_parameter("trait_plancher")), IsoMateriaux.ENCRE_PLANCHER_AFFICHE)
		and mb.shader == ms.shader)


## L'aplat FLOU d'une nappe : même taille, même alpha au pixel près ; ses traits fins fondus (presque plus d'encre sous 0,04
## de luminance là où il est opaque) ; sa lumière gardée (la clarté moyenne du dessin, à 10 % près).
func _l_aplat_flou() -> void:
	print("\n[L'aplat flou : la lumière du dessin sans ses traits]")
	for nom: String in NAPPES:
		var origine: Texture2D = load("res://assets/sprites/gadget_%s.png" % nom)
		var flou := IsoNuageVoxel.aplat_flou(origine)
		var o := origine.get_image()
		var f := flou.get_image() if flou != null else null
		if f == null:
			_check("« %s » : un aplat flou" % nom, false)
			continue
		o.convert(Image.FORMAT_RGBA8)
		f.convert(Image.FORMAT_RGBA8)
		var dob := o.get_data()
		var dfl := f.get_data()
		var meme_alpha := o.get_size() == f.get_size()
		var encre_o := 0
		var encre_f := 0
		var opaques := 0
		var lum_o := 0.0
		var lum_f := 0.0
		for k in range(0, mini(dob.size(), dfl.size()), 4):
			if dob[k + 3] != dfl[k + 3]:
				meme_alpha = false
			if dob[k + 3] >= 128:
				opaques += 1
				var lo := (0.2126 * dob[k] + 0.7152 * dob[k + 1] + 0.0722 * dob[k + 2]) / 255.0
				var lf := (0.2126 * dfl[k] + 0.7152 * dfl[k + 1] + 0.0722 * dfl[k + 2]) / 255.0
				lum_o += lo
				lum_f += lf
				if lo < IsoNuageVoxel.ENCRE_LUM_BAS:
					encre_o += 1
				if lf < IsoNuageVoxel.ENCRE_LUM_BAS:
					encre_f += 1
		_check("« %s » : l'aplat flou a la taille et l'alpha du dessin, au pixel près" % nom, meme_alpha and flou != origine)
		_check("« %s » : ses traits fins sont fondus (encre sous 0,04 : %d → %d pixels opaques sur %d)" % [nom, encre_o, encre_f,
			opaques], encre_o > 0 and encre_f * 20 < encre_o)
		_check("« %s » : sa lumière est gardée (clarté moyenne %.3f → %.3f)" % [nom, lum_o / maxf(1.0, opaques),
			lum_f / maxf(1.0, opaques)], absf(lum_f - lum_o) <= 0.1 * lum_o)
		_check("« %s » : un aplat par texture et par processus (le cache se clé sur la texture)" % nom,
			IsoNuageVoxel.aplat_flou(origine) == flou)


# ---------------------------------------------------------------------------
# LA MANCHE
# ---------------------------------------------------------------------------

func _dans_la_manche() -> void:
	var reglages := root.get_node("GameSettings")
	var json := JSON.new()
	var lu: Dictionary = MapCodec.validate(json.data as Dictionary) \
		if json.parse(FileAccess.get_file_as_string(CARTE)) == OK else {}
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.ui._intended_mode = _mode_local()
	reglages.mode_iso = true
	main._on_replay_requested()
	_check("la manche iso démarre", await _depart_fini(main))
	root.get_node("MapData").current_map_data = lu.get("data", {})
	main.rebuild_arena()
	for i in 4:
		await process_frame
	var p := root.get_node_or_null("Presentation3D")
	_check("la vue iso est allumée en écran scindé", p != null and bool(p.get("_actif")) and bool(p.get("_scinde")))
	if p == null:
		return
	var volumes: IsoVolumes = (p.get("_miroirs") as Node).get("volumes")
	var lieu: Vector2 = main.p2.global_position + Vector2(-160.0, 0.0)
	var braises := await _poser(main, 1, lieu, "nappe_braises", 9800)
	var poudre := await _poser(main, 0, main.p1.global_position + Vector2(170.0, 0.0), "poudre_contact", 9801)
	_check("les deux nappes posées par le vrai chemin", braises != null and poudre != null)
	if braises == null or poudre == null:
		return
	braises.set_physics_process(false)
	# La poudre figée : elle ne relève plus les pas (un joueur posé dedans y laisserait des traces de plus).
	poudre.set_physics_process(false)
	await _des_traces(main, poudre)
	if not _essai:
		await _sans_l_essai(main, p, volumes, braises, poudre)
		volumes.poser_nappes_voxel(true, "tas")
		p.call("_suivre")
		await process_frame
	if volumes.variante_nappes == "tas":
		await _le_tas(main, p, volumes, braises, poudre)
		volumes.poser_nappes_voxel(true, "braises")
		p.call("_suivre")
		await process_frame
		await _les_braises_seules(main, p, volumes, braises, poudre)
	else:
		await _les_braises_seules(main, p, volumes, braises, poudre)
		volumes.poser_nappes_voxel(true, "tas")
		p.call("_suivre")
		await process_frame
		await _le_tas(main, p, volumes, braises, poudre)
	await _la_killcam(main, p, volumes, braises, poudre)
	await _des_images_seulement(main, p, volumes, braises, poudre)
	reglages.mode_iso = false
	main.queue_free()
	await process_frame


## Cinq traces, faites comme la poudre les fait (`nouvelle_trace`, le groupe, l'arène — chargée à l'exécution : la nommer
## ferait compiler la classe sous `--script` avant les autoloads, « Pièges connus ») mais SANS leur fondu, pour que leur
## éclat tienne le temps des contrôles : trois dans la nappe, deux au-dehors (des pieds poudrés, plus pâles).
func _des_traces(main: Node, poudre: Node2D) -> void:
	var modele: GDScript = load("res://gadget_poudre.gd")
	for k in 5:
		var m: Polygon2D = modele.call("nouvelle_trace")
		m.global_position = poudre.global_position + Vector2(-60.0 + 30.0 * float(k), 20.0) if k < 3 \
			else poudre.global_position + Vector2(140.0 + 30.0 * float(k - 3), 20.0)
		m.rotation = 0.3 * float(k)
		m.modulate.a = 0.5 if k < 3 else 0.25
		m.add_to_group("traces_de_poudre")
		main.arena.add_child(m)
	await process_frame
	await process_frame


func _traces_vivantes() -> Array:
	return get_nodes_in_group("traces_de_poudre").filter(func(t): return (t as CanvasItem).is_visible_in_tree())


func _sans_l_essai(main: Node, p: Node, volumes: IsoVolumes, braises: Node2D, poudre: Node2D) -> void:
	print("\n[Sans l'essai : les nappes du jeu publié]")
	p.call("_suivre")
	var eb: Dictionary = volumes.suivi_de(braises)
	var ep: Dictionary = volumes.suivi_de(poudre)
	var lueurs: Dictionary = volumes.suivi_de(braises, 1)
	_check("la nappe de braises : ses deux couches, et ses seize lueurs", not eb.is_empty() and eb["genre"] == "volume"
		and (eb["noeuds"] as Array).size() == 2 and not lueurs.is_empty() and lueurs["genre"] == "braises"
		and (lueurs["noeuds"] as Array).size() == IsoVolumes.POINTS_BRAISES)
	_check("la poudre : ses deux couches", not ep.is_empty() and ep["genre"] == "volume" and (ep["noeuds"] as Array).size() == 2)
	_check("aucun cube de nappe, aucun grain", _noeuds_de_nappes(p).is_empty()
		and p.find_children("GrainsPoudre", "MultiMeshInstance3D", true, false).is_empty())
	_check("les nappes gardent leur dessin, et les traces sont dans la lightmap",
		(braises.get_node(^"Visuel") as Sprite2D).texture == load("res://assets/sprites/gadget_nappe_braises.png")
		and (poudre.get_node(^"Visuel") as Sprite2D).texture == load("res://assets/sprites/gadget_poudre_contact.png")
		and _traces_vivantes().size() == 5 and _traces_vivantes().all(
			func(t): return (t as CanvasItem).visibility_layer != Presentation3D.COUCHE_HORS_VUE))
	_lueurs = []
	if not lueurs.is_empty():
		for n in lueurs["noeuds"]:
			_lueurs.append(Vector2((n as Node3D).position.x, (n as Node3D).position.z))


func _le_tas(main: Node, p: Node, volumes: IsoVolumes, braises: Node2D, poudre: Node2D) -> void:
	print("\n[L'essai, variante « tas » : les nappes en tas de cubes fins]")
	p.call("_suivre")
	await process_frame
	p.call("_suivre")
	for g: Node2D in [braises, poudre]:
		var slug := String(g.get("slug"))
		var e: Dictionary = volumes.suivi_de(g)
		var ok: bool = not e.is_empty() and e["genre"] == "nuage_voxel" and (e["noeuds"] as Array).size() == 2
		_check("« %s » : une grille de cubes PAR VUE et son juge, à la place de ses couches" % slug, ok
			and (e["noeuds"] as Array).all(func(n): return n is MultiMeshInstance3D) and e.get("juge") != null
			and (e["juge"] as Node3D).visible)
		if not ok:
			continue
		var voxel := IsoVolumes.TUILE / 8.0
		var hauteur := float(IsoNuageVoxel.NAPPES[slug]["hauteur"]) * IsoVolumes.TUILE
		for k in 2:
			var mmi := e["noeuds"][k] as MultiMeshInstance3D
			var mat := e["mats"][k] as ShaderMaterial
			var calque := Presentation3D.CALQUE_VUE_1 if k == 0 else Presentation3D.CALQUE_VUE_2
			var cam: Variant = p.call("_camera_de", k)
			var cote := IsoNuageVoxel.cote_camera(-(cam as Camera3D).global_transform.basis.z) if cam is Camera3D \
				else Vector2i(9, 9)
			_check("« %s », vue de J%d : sur le calque de SA caméra, SA lightmap, SA grille de cubes fins, avant les corps"
				% [slug, k + 1], mmi.layers == calque and bool(mat.get_shader_parameter("vue_deux")) == (k == 1)
				and mmi.multimesh == IsoNuageVoxel.grille(slug, hauteur, voxel, cote)
				and mat.render_priority == IsoVolumes.PRIORITE_VOLUME and is_equal_approx(float(e["voxel"]), voxel))
		var visuel := g.get_node(^"Visuel") as Sprite2D
		var origine: Texture2D = load("res://assets/sprites/gadget_%s.png" % slug)
		var m0 := e["mats"][0] as ShaderMaterial
		var m1 := e["mats"][1] as ShaderMaterial
		var lumineuse := bool(IsoNuageVoxel.NAPPES[slug]["lumineuse"])
		if lumineuse:
			_check("« %s » : peinte lumineuse, elle GARDE son dessin sous ses cubes, lu au pied de chaque colonne sans lissage"
				% slug, visuel.texture == origine and not e.has("aplat")
				and float((e["mats"][0] as ShaderMaterial).get_shader_parameter("lissage_px")) == IsoNuageVoxel.LISSAGE_LUMINEUSE)
		else:
			_check("« %s » : sous les cubes, son dessin en APLAT FLOU (la lumière lissée, comme la fumée)" % slug,
				visuel.texture == IsoNuageVoxel.aplat_flou(origine) and e.get("texture_origine") == origine
				and float((e["mats"][0] as ShaderMaterial).get_shader_parameter("lissage_px")) > IsoNuageVoxel.LISSAGE_LUMINEUSE)
		_check("« %s » : la forme, le relief et l'encre viennent du DESSIN d'origine, à son centre" % slug,
			m0.get_shader_parameter("masque") == IsoNuageVoxel.relief(origine)
			and (m0.get_shader_parameter("nuage_centre") as Vector2).is_equal_approx(g.global_position))

		var ecarts := _ecarts_entre_vues(m0, m1)
		_check("« %s » : ÉQUITÉ — les deux vues reçoivent les mêmes réglages, au choix de leur vue près" % slug,
			ecarts.is_empty(), str(ecarts))
		_check("« %s » : l'horloge est l'âge du gadget (%.3f s), la même dans les deux vues" % [slug, float(g.call("age"))],
			is_equal_approx(float(m0.get_shader_parameter("age")), float(g.call("age")))
			and m0.get_shader_parameter("age") == m1.get_shader_parameter("age"))
	# Les braises : des cubes du tas, aux points des lueurs.
	var eb: Dictionary = volumes.suivi_de(braises)
	if eb.is_empty():
		return
	var mb := eb["mats"][0] as ShaderMaterial
	var points: Array = volumes.braises_de(braises)
	var tableau: PackedVector4Array = mb.get_shader_parameter("braises")
	_check("les seize braises sont dans le tas (« tas » : aucune variante au sol), plus aucune lueur",
		int(mb.get_shader_parameter("nb_braises")) == IsoVolumes.POINTS_BRAISES
		and not bool(mb.get_shader_parameter("seulement_braises")) and volumes.suivi_de(braises, 1).is_empty())
	var memes := points.size() == IsoVolumes.POINTS_BRAISES and tableau.size() >= points.size()
	for k in mini(points.size(), tableau.size()):
		if not tableau[k].is_equal_approx(points[k]):
			memes = false
	_check("les points posés sont ceux que tire la nappe (`braises_de`)", memes)
	if not _lueurs.is_empty():
		var aux_lueurs := _lueurs.size() == points.size()
		for k in mini(_lueurs.size(), points.size()):
			if not (_lueurs[k] as Vector2).is_equal_approx(Vector2((points[k] as Vector4).x, (points[k] as Vector4).y)):
				aux_lueurs = false
		_check("… et ce sont les points des seize lueurs du jeu publié (même graine, même suite de tirages)", aux_lueurs)
	_check("leur couleur est l'ambre des lueurs, TEL QUEL (ce shader écrit sa couleur telle qu'elle s'affiche)",
		(mb.get_shader_parameter("braises_couleur") as Vector3).is_equal_approx(
			Vector3(Charte.AMBRE.r, Charte.AMBRE.g, Charte.AMBRE.b)))
	_check("leur éclat est celui des lueurs : la lumière de la nappe (%.3f) sous son opacité" % volumes.eclat_des_braises(
		braises), is_equal_approx(float(mb.get_shader_parameter("braises_eclat")), volumes.eclat_des_braises(braises))
		and volumes.eclat_des_braises(braises) > 0.3)
	# Noir : la lumière de la nappe coupée, plus de braise.
	var lueur := braises.get_node(^"Lueur") as Light2D
	lueur.enabled = false
	p.call("_suivre")
	_check("lumière de la nappe éteinte, braises éteintes (éclat 0)", float(mb.get_shader_parameter("braises_eclat")) == 0.0)
	lueur.enabled = true
	p.call("_suivre")
	var ep: Dictionary = volumes.suivi_de(poudre)
	_check("la poudre n'a pas de braises", not ep.is_empty()
		and int((ep["mats"][0] as ShaderMaterial).get_shader_parameter("nb_braises")) == 0)
	await _les_grains(main, p, volumes, poudre, true)


func _les_braises_seules(main: Node, p: Node, volumes: IsoVolumes, braises: Node2D, poudre: Node2D) -> void:
	print("\n[L'essai, variante « braises » : les nappes au sol, leurs braises seules en cubes]")
	p.call("_suivre")
	await process_frame
	p.call("_suivre")
	var eb: Dictionary = volumes.suivi_de(braises)
	var bc: Dictionary = volumes.suivi_de(braises, 1)
	var ep: Dictionary = volumes.suivi_de(poudre)
	_check("la nappe de braises garde ses couches et son dessin", not eb.is_empty() and eb["genre"] == "volume"
		and (braises.get_node(^"Visuel") as Sprite2D).texture == load("res://assets/sprites/gadget_nappe_braises.png"))
	var ok: bool = not bc.is_empty() and bc["genre"] == "nuage_voxel" and (bc["mats"] as Array).size() == 2
	_check("ses braises sont des cubes (une grille par vue, sous la clé de ses lueurs), sans juge", ok
		and (bc["mats"] as Array).all(func(m): return (bool((m as ShaderMaterial).get_shader_parameter("seulement_braises"))
			and int((m as ShaderMaterial).get_shader_parameter("nb_braises")) == IsoVolumes.POINTS_BRAISES))
		and (bc.get("juge") == null or not (bc["juge"] as Node3D).visible))
	if ok:
		_check("ÉQUITÉ des braises : les deux vues reçoivent les mêmes réglages", _ecarts_entre_vues(bc["mats"][0],
			bc["mats"][1]).is_empty(), str(_ecarts_entre_vues(bc["mats"][0], bc["mats"][1])))
	_check("la poudre garde ses couches et son dessin", not ep.is_empty() and ep["genre"] == "volume"
		and (poudre.get_node(^"Visuel") as Sprite2D).texture == load("res://assets/sprites/gadget_poudre_contact.png"))
	await _les_grains(main, p, volumes, poudre, false)


## Les grains des traces : trois par trace qui luit, de sa couleur à son éclat, sur le tas de poudre (« tas ») ou au sol ; la
## trace 2D hors de la lightmap tant que ses grains la portent.
func _les_grains(main: Node, p: Node, volumes: IsoVolumes, poudre: Node2D, tas: bool) -> void:
	p.call("_suivre")
	var traces := _traces_vivantes()
	var e: Dictionary = volumes.suivi_de(main.arena, IsoVolumes.CLE_GRAINS)
	var ok: bool = not e.is_empty() and e["genre"] == "grains" and (e["noeuds"] as Array).size() == 1
	_check("les traces en GRAINS : un seul maillage, sur le calque commun (les deux joueurs voient les traces)", ok
		and (e["noeuds"][0] as MultiMeshInstance3D).layers == IsoVolumes.CALQUE and (e["noeuds"][0] as Node3D).visible)
	if not ok:
		return
	var mm := (e["noeuds"][0] as MultiMeshInstance3D).multimesh
	# Le tampon posé (seize flottants par grain : la transformation en lignes, puis la couleur), tel que l'entrée le garde.
	var tampon: PackedFloat32Array = e.get("tampon", PackedFloat32Array())
	_check("trois grains par trace qui luit (%d traces)" % traces.size(), traces.size() == 5
		and int(e.get("grains", -1)) == IsoVolumes.GRAINS_PAR_TRACE * traces.size()
		and mm.visible_instance_count == int(e.get("grains", -1)) and tampon.size() >= 16 * int(e.get("grains", 0)))
	var couleurs_justes := true
	var hauteurs_justes := true
	var haut_tas := float(IsoNuageVoxel.NAPPES["poudre_contact"]["hauteur"]) * IsoVolumes.TUILE
	for i in traces.size():
		var t := traces[i] as Polygon2D
		var dedans := t.global_position.distance_to(poudre.global_position) <= float(poudre.get("rayon"))
		for j in IsoVolumes.GRAINS_PAR_TRACE:
			var k := (i * IsoVolumes.GRAINS_PAR_TRACE + j) * 16
			if k + 15 >= tampon.size():
				couleurs_justes = false
				hauteurs_justes = false
				continue
			var c := Color(tampon[k + 12], tampon[k + 13], tampon[k + 14], tampon[k + 15])
			if not (Color(c.r, c.g, c.b).is_equal_approx(Color(t.color.r, t.color.g, t.color.b))
					and is_equal_approx(c.a, Presentation3D.opacite_rendue(t))):
				couleurs_justes = false
			var y := tampon[k + 7]
			var attendu := (haut_tas if (tas and dedans) else IsoVolumes.PLANCHER_PX) + 0.5 * IsoVolumes.GRAIN_HAUT_PX
			if not is_equal_approx(y, attendu):
				hauteurs_justes = false
	_check("chaque grain luit de la couleur de sa trace, à son éclat rendu (son fondu, la charge des pieds)", couleurs_justes)
	_check("posés %s" % ("sur le tas de poudre dans la nappe, au sol au-dehors" if tas else "au sol (la poudre y reste)"),
		hauteurs_justes)
	_check("la trace 2D sort de la lightmap tant que ses grains la portent", traces.all(
		func(t): return (t as CanvasItem).visibility_layer == Presentation3D.COUCHE_HORS_VUE))


## LA KILLCAM : une copie de la nappe de braises (`GameState._copie_de_gadget`) à un âge rejoué a son tas, à cet âge, et ses
## braises aux mêmes points ; les traces que la killcam rejoue ont leurs grains, celles du présent (cachées) non.
func _la_killcam(main: Node, p: Node, volumes: IsoVolumes, braises: Node2D, poudre: Node2D) -> void:
	print("\n[La killcam]")
	var d: Dictionary = braises.call("etat_de_rejeu")
	d["nom"] = "NappeKillcam"
	d["age"] = 3.25
	var copie: Node2D = main.call("_copie_de_gadget", d)
	if copie == null:
		_check("la killcam copie la nappe de braises", false)
		return
	copie.call("rejouer", d)
	copie.set_physics_process(false)
	await process_frame
	await process_frame
	var e: Dictionary = volumes.suivi_de(copie, 1 if volumes.variante_nappes == "braises" else 0)
	_check("une copie de killcam (âge rejoué 3,25 s) a ses cubes, à l'âge REJOUÉ dans les deux vues", not e.is_empty()
		and e["genre"] == "nuage_voxel" and (e["mats"] as Array).size() == 2 and (e["mats"] as Array).all(
			func(m): return is_equal_approx(float((m as ShaderMaterial).get_shader_parameter("age")), 3.25)))
	_check("… et ses braises aux mêmes points que l'original (la graine est sa position)",
		volumes.braises_de(copie) == volumes.braises_de(braises))
	copie.queue_free()
	# Les traces : le présent caché, le passé rejoué.
	var presentes := _traces_vivantes()
	for t in presentes:
		(t as CanvasItem).visible = false
	main.call("_maj_traces_killcam", PackedFloat32Array([poudre.global_position.x, poudre.global_position.y, 0.0, 0.4,
		poudre.global_position.x + 30.0, poudre.global_position.y, 0.5, 0.2]))
	await process_frame
	p.call("_suivre")
	var eg: Dictionary = volumes.suivi_de(main.arena, IsoVolumes.CLE_GRAINS)
	var tampon: PackedFloat32Array = eg.get("tampon", PackedFloat32Array())
	_check("les deux traces de la killcam ont leurs grains, les cinq du présent (cachées) non", not eg.is_empty()
		and int(eg.get("grains", -1)) == 2 * IsoVolumes.GRAINS_PAR_TRACE and tampon.size() >= 16 * 6
		and is_equal_approx(tampon[15], 0.4) and is_equal_approx(tampon[3 * 16 + 15], 0.2))
	main.call("_purger_gadgets_killcam")
	for t in presentes:
		if is_instance_valid(t):
			(t as CanvasItem).visible = true
	await process_frame
	p.call("_suivre")


func _des_images_seulement(main: Node, p: Node, volumes: IsoVolumes, braises: Node2D, poudre: Node2D) -> void:
	print("\n[Les nappes en voxels ne sont que des images]")
	p.call("_suivre")
	var avant := _instantane(main)
	_check("il y a bien des cubes de nappes et des grains à couper", not _noeuds_de_nappes(p).is_empty()
		and not p.find_children("GrainsPoudre", "MultiMeshInstance3D", true, false).is_empty())
	volumes.images_actives = false
	p.call("_suivre")
	var sans := _instantane(main)
	_check("sans les images, les lumières 2D, les capteurs et les joueurs sont les mêmes",
		sans["lumieres"] == avant["lumieres"] and sans["capteurs"] == avant["capteurs"]
		and sans["joueurs"] == avant["joueurs"], _ecart(avant["lumieres"], sans["lumieres"]))
	_check("sans les images, les nappes reprennent leur dessin et les traces la lightmap",
		(poudre.get_node(^"Visuel") as Sprite2D).texture == load("res://assets/sprites/gadget_poudre_contact.png")
		and _traces_vivantes().all(func(t): return (t as CanvasItem).visibility_layer != Presentation3D.COUCHE_HORS_VUE))
	volumes.images_actives = true
	volumes.poser_nappes_voxel(true, "tas")
	p.call("_suivre")
	p.call("_suivre")
	# Les instantanés se prennent SANS image entre eux : le bandeau LED et les lampes vivent d'une image à l'autre.
	var essai := _instantane(main)
	# L'essai éteint (la bascule des bancs, et le défaut) : le jeu publié revient.
	volumes.poser_nappes_voxel(false)
	p.call("_suivre")
	var apres := _instantane(main)
	await process_frame
	var eb: Dictionary = volumes.suivi_de(braises)
	_check("l'essai éteint, les couches et les seize lueurs reviennent", not eb.is_empty() and eb["genre"] == "volume"
		and volumes.suivi_de(braises, 1).get("genre", "") == "braises")
	_check("… aucun cube de nappe ni grain ne reste", _noeuds_de_nappes(p).is_empty()
		and p.find_children("GrainsPoudre", "MultiMeshInstance3D", true, false).filter(
			func(n): return not (n as Node).is_queued_for_deletion()).is_empty())
	_check("… les nappes ont leur dessin, les traces leur lightmap",
		(braises.get_node(^"Visuel") as Sprite2D).texture == load("res://assets/sprites/gadget_nappe_braises.png")
		and (poudre.get_node(^"Visuel") as Sprite2D).texture == load("res://assets/sprites/gadget_poudre_contact.png")
		and _traces_vivantes().all(func(t): return (t as CanvasItem).visibility_layer != Presentation3D.COUCHE_HORS_VUE))
	_check("… et les lumières 2D, les capteurs et les joueurs n'ont pas bougé", apres["lumieres"] == essai["lumieres"]
		and apres["capteurs"] == essai["capteurs"] and apres["joueurs"] == essai["joueurs"],
		_ecart(essai["lumieres"], apres["lumieres"]))
	var miroirs: Node = p.get("_miroirs")
	_check("le registre des dessins retirés oublie les traces mortes (`oublier_les_disparus`)",
		miroirs != null and miroirs.has_method("oublier_les_disparus"))


# ---------------------------------------------------------------------------
# LE SHADER
# ---------------------------------------------------------------------------

func _le_shader() -> void:
	print("\n[Le shader : les nappes et les grains]")
	var nuage := FileAccess.get_file_as_string(IsoNuageVoxel.CHEMIN_SHADER)
	var sans := _sans_commentaires(nuage)
	_check("les uniformes des nappes existent (respiration, grain, braises, leur éclat, leur couleur, la variante)",
		["respiration", "grain", "seulement_braises", "nb_braises", "braises", "braises_eclat", "braises_couleur"].all(
			func(u): return _a_l_uniforme(IsoNuageVoxel.shader(false), u)))
	_check("une braise scintille à l'ÂGE du nuage, comme les lueurs (0,65 + 0,35 sin(âge × vitesse + phase)) — jamais TIME",
		sans.contains("e = max(e, 0.65 + 0.35 * sin(age * braises[k].w + braises[k].z));") and not sans.contains("TIME"))
	_check("son cube tend VERS l'ambre (en mélange : jamais au-delà), à l'éclat de la lumière de la nappe, et n'a pas de trait",
		sans.contains("ALBEDO = mix(ALBEDO, braises_couleur, clamp(v_braise * BRAISE_GAIN, 0.0, 1.0));")
		and sans.contains("v_braise = b > 0.0 ? braises_eclat * b : 0.0;")
		and sans.contains("ALBEDO = mix(v_couleur, v_encre, v_braise > 0.0 ? 0.0 : trait);"))
	_check("le grain d'une colonne est tiré de sa CASE (la même pour les deux vues et les deux machines), après la borne du sommet",
		sans.contains("float hasard = grain > 0.0 ? 1.0 - grain * pate_hash(floor(c.xz / max(voxel_px, 0.001)) + vec2(7.1, 3.3)) : 1.0;")
		and sans.contains("float sommet = nuage_hauteur_px * clamp(d2 * bosse, 0.0, 1.0) * vie * hasard;"))

	_check("la température d'un cube passe par les seuils du matériau (gradués pour une nappe, nuls pour un nuage)",
		sans.contains("col = pate_temperature_graduee_neutre(col, temperature, temperature_seuil_bas, temperature_seuil_haut,")
		and _a_l_uniforme(IsoNuageVoxel.shader(false), "temperature_seuil_bas")
		and _a_l_uniforme(IsoNuageVoxel.shader(false), "temperature_seuil_haut"))
	_check("une nappe ne respire pas (la respiration pondérée)",
		sans.contains("rho *= mix(1.0, 0.88 + 0.24 * (0.5 + 0.5 * sin(age * 1.3 + h * 6.2831853)), respiration);"))
	var grain := FileAccess.get_file_as_string("res://grain_iso.gdshader")
	var gs := _sans_commentaires(grain)
	_check("le grain : non éclairé, ADDITIF (une lueur, comme la trace), profondeur lue jamais écrite, sans TIME",
		gs.contains("render_mode unshaded, cull_back, blend_add, depth_draw_never, shadows_disabled, fog_disabled;")
		and not gs.contains("TIME") and not gs.contains("LIGHT"))
	_check("le grain n'ajoute que la couleur de sa trace × son éclat × le modelé de la face (≤ 1)",
		gs.contains("v_couleur = COLOR.rgb * clamp(COLOR.a, 0.0, 1.0) * face;")
		and gs.contains("face = cote > 0.3 ? 0.62 : (cote < -0.3 ? 0.8 : 0.71);"))


# ---------------------------------------------------------------------------
# OUTILS
# ---------------------------------------------------------------------------

func _poser(main: Node, pid: int, pos: Vector2, slug: String, numero: int) -> Node2D:
	var avant: Array = main.bullet_container.get_children()
	main._do_spawn_gadget(pid, pos, 0.0, slug, numero)
	var neuf: Node2D = null
	for n in main.bullet_container.get_children():
		if not avant.has(n) and "slug" in n and String(n.get("slug")) == slug:
			neuf = n
	var catalogue: Dictionary = main.get_script().get_script_constant_map()["IMPLEMENTATIONS"]
	if neuf != null and catalogue.has(slug):
		neuf.set("duree_vie", float((catalogue[slug] as Dictionary).get("duree_vie", 0.0)))
	for k in 3:
		await process_frame
	return neuf if is_instance_valid(neuf) else null


## Les grilles de cubes des nappes, vivantes sous la présentation.
func _noeuds_de_nappes(p: Node) -> Array:
	var volumes: Node = (p.get("_miroirs") as Node).get("volumes")
	var out := []
	for e: Dictionary in (volumes.get("_suivis") as Dictionary).values():
		var src: Object = (e["source"] as WeakRef).get_ref()
		if e["genre"] == "nuage_voxel" and src != null and "slug" in src and IsoNuageVoxel.est_nappe(String(src.get("slug"))):
			for n in e["noeuds"]:
				if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
					out.append(n)
	return out


func _ecarts_entre_vues(a: ShaderMaterial, b: ShaderMaterial) -> Array:
	var out := []
	for u in a.shader.get_shader_uniform_list():
		var nom := String(u["name"])
		if nom == "vue_deux":
			continue
		if a.get_shader_parameter(nom) != b.get_shader_parameter(nom):
			out.append(nom)
	if a.shader != b.shader:
		out.append("shader")
	return out


func _instantane(main: Node) -> Dictionary:
	var lumieres := {}
	for n in main.find_children("*", "Light2D", true, false):
		var l := n as Light2D
		lumieres[str(main.get_path_to(l))] = [l.enabled, snappedf(l.energy, 0.0001), l.height,
			l.shadow_item_cull_mask, l.range_item_cull_mask, l.color, l.shadow_enabled]
	var capteurs := {}
	for c in main.get_tree().root.find_children("Capteur*", "SubViewport", true, false):
		capteurs[c.name] = (c as SubViewport).canvas_cull_mask
	var joueurs := []
	for j in [main.p1, main.p2]:
		joueurs.append([j.global_position, j.rotation, j.get("hp")])
	return {"lumieres": lumieres, "capteurs": capteurs, "joueurs": joueurs}


static func _ecart(a: Dictionary, b: Dictionary) -> String:
	for k in a:
		if not b.has(k) or b[k] != a[k]:
			return "%s : %s → %s" % [k, str(a[k]), str(b.get(k))]
	return ""


func _fonction_gd(code: String, nom: String, statique := false) -> String:
	var debut := code.find(("\nstatic func %s(" if statique else "\nfunc %s(") % nom)
	if debut < 0:
		return ""
	var fin := code.length()
	for marque in ["\nfunc ", "\nstatic func ", "\nconst ", "\n## "]:
		var k := code.find(marque, debut + 1)
		if k > 0 and k < fin:
			fin = k
	return code.substr(debut, fin - debut)


func _sans_commentaires(code: String) -> String:
	return RegEx.create_from_string("//[^\\n]*").sub(code, "", true)


func _a_l_uniforme(shader: Shader, nom: String) -> bool:
	if shader == null:
		return false
	for u in shader.get_shader_uniform_list():
		if u["name"] == nom:
			return true
	return false


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


func _mode_local() -> int:
	var reseau := root.get_node("NetworkManager")
	return int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
