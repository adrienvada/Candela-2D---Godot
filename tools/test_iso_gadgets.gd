## Gadgets et lumières en iso — chaque gadget fini en iso, et des sources de lumière qui ont une hauteur
## (brief de la session cloud du 2026-09-15, sur mandat d'Adrien).
##
## Ce que cette suite prouve, sans fenêtre :
##
## **La hauteur des sources** (étape 2) —
## - la règle de la hauteur : derrière un muret de 0,40 tuile, à D = 2 tuiles de la source, la zone
##   morte au sol vaut D × 0,40 / (h − 0,40) — 2,67 tuiles pour une source à 0,70, 0,73 pour une source
##   à 1,50 —, et elle est infinie pour une source au ras du sol (0,05) ; un corps debout n'est jamais
##   caché par une source qui dépasse le muret ; la jumelle GDScript suit le shader, ligne pour ligne ;
## - `poser_hauteur_source` pose la hauteur ET le bit d'ombre des murets qui va avec : une source basse
##   bute (ombre infinie par l'occluder), une source haute passe (zone finie par le shader) ; les murs
##   hauts restent dans tous les masques ;
## - la fusée : haute au lancer, redescendue à l'atterrissage, au sol à 0,15, en vol par-dessus les
##   murets puis y butant quand elle redescend sous eux ; braises et mine au ras du sol ;
## - les deux lightmaps (J1, J2) partagent le même monde 2D, donc les mêmes lumières et les mêmes
##   hauteurs, et reçoivent la hauteur des murets et le seuil « sans origine » chacune dans son repère ;
## - rien sur le fil : `Protocol.VERSION` reste 18.
##
## **Les volumes, les lueurs et les miroirs** (étapes 3 à 5), sur une vraie manche iso, gadgets posés par
## le VRAI chemin (`GameState._do_spawn_gadget`, sous les slugs du jeu) —
## - les dix gadgets ont leur présence iso : un voxel pour ce qui a un corps (la mine et l'ombre habitée
##   comprises, que les slugs du jeu privaient de voxel), un volume de couches pour les nuages et nappes,
##   à la hauteur du brief ; la lentille, les braises, l'éclair de la mine, la toile debout ;
## - la fusée : comète en vol (le cœur dessiné sort des lightmaps), fumée en volume et lueur posée, lueur
##   éteinte quand sa lumière l'est ;
## - chaque couche lit la lightmap de la caméra qui la dessine, sans gain, dessinée avant les corps ;
## - un corps dans la suie est effacé dans la vue d'en face (ISO2b lit l'opacité que le jeu pose) ;
## - **les images ne sont que des images** : les couper ne change aucune lumière 2D (énergie, hauteur,
##   masques), aucun capteur, aucun joueur, et rend à la lightmap les dessins qu'elles en avaient retirés.
##
## Ce qu'elle ne prouve pas : l'accord au PIXEL entre la règle et la lightmap, et la valeur éclairée d'une
## couche — le banc `tools/banc_iso_gadgets.gd` les mesure en vraie fenêtre.
extends SceneTree

const PLANCHER := 60
const SLUGS_VOXEL := ["mine_magnesium", "ombre_habitee", "torche_fantome", "voile", "gresillement", "leurre"]
const SLUGS_VOLUME := ["cartouche_suie", "poussiere", "nappe_braises", "poudre_contact"]
const CARTE := "res://tools/cartes/murs_bas_essai.json"

var _failures := 0
var _verifications := 0


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
	print("=== GADGETS ET LUMIÈRES EN ISO ===")
	await process_frame
	_la_regle_de_la_hauteur()
	_le_shader_suit_la_jumelle()
	_poser_la_hauteur()
	_les_uniformes()
	await _la_fusee()
	_braises_et_mine()
	var version = (load("res://protocol.gd") as GDScript).get_script_constant_map().get("VERSION")
	_check("Protocol.VERSION reste 18", version == 18, str(version))
	_les_shaders()
	_le_faisceau()
	await _les_deux_lightmaps()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	_sortir()


# ---------------------------------------------------------------------------
# ÉTAPE 2 — LA HAUTEUR DES SOURCES
# ---------------------------------------------------------------------------

func _la_regle_de_la_hauteur() -> void:
	print("\n[La règle de la hauteur, derrière un muret à D = 2 tuiles]")
	var T := MursBas.TUILE
	var h_mur := MursBas.hauteur_mur()
	var d := 2.0 * T
	# Le muret : de x = T à x = 2T (face de sortie à D = 2 tuiles), bien plus haut que large.
	var muret := Rect2(T, -3.0 * T, T, 6.0 * T)
	var murs := [muret]
	for cas in [[0.05, INF], [0.70, 2.0 * 0.40 / 0.30], [1.50, 2.0 * 0.40 / 1.10]]:
		var h: float = cas[0]
		var attendue: float = cas[1]
		var l := MursBasRendu.zone_morte_source(d, MursBas.en_pixels(h), h_mur, 0.0)
		if is_inf(attendue):
			_check("source à %.2f : zone morte infinie (elle bute sur le muret)" % h, is_inf(l), str(l))
			_check("source à %.2f : le sol reste noir à 30 tuiles derrière" % h,
				not MursBasRendu.eclaire_par_hauteur(Vector2.ZERO, Vector2(d + 30.0 * T, 0.0),
					MursBas.en_pixels(h), 0.0, murs, h_mur))
		else:
			_check("source à %.2f : zone morte de %.3f tuile (D × 0,40 / (h − 0,40))" % [h, attendue],
				absf(l / T - attendue) < 1e-4, "%.4f tuile" % (l / T))
			_check("source à %.2f : noir un pixel avant la fin de la zone, éclairé un pixel après" % h,
				not MursBasRendu.eclaire_par_hauteur(Vector2.ZERO, Vector2(d + l - 1.0, 0.0),
					MursBas.en_pixels(h), 0.0, murs, h_mur)
				and MursBasRendu.eclaire_par_hauteur(Vector2.ZERO, Vector2(d + l + 1.0, 0.0),
					MursBas.en_pixels(h), 0.0, murs, h_mur))
	var l70 := MursBasRendu.zone_morte_source(d, MursBas.en_pixels(0.70), h_mur, 0.0)
	var l70_loin := MursBasRendu.zone_morte_source(2.0 * d, MursBas.en_pixels(0.70), h_mur, 0.0)
	_check("la zone s'allonge avec la distance de la source au muret (doublée à 2D)",
		is_equal_approx(l70_loin, 2.0 * l70))
	_check("plus la source est haute, plus la zone est courte",
		MursBasRendu.zone_morte_source(d, MursBas.en_pixels(1.50), h_mur, 0.0) < l70)
	_check("un corps debout n'est jamais caché par une source qui dépasse le muret",
		MursBasRendu.zone_morte_source(d, MursBas.en_pixels(0.70), h_mur, MursBas.hauteur_de_posture(false)) == 0.0)
	var l_acc := MursBasRendu.zone_morte_source(d, MursBas.en_pixels(1.50), h_mur, MursBas.hauteur_de_posture(true))
	_check("un accroupi est caché moins loin que le sol (sa tête est plus près du rayon)",
		l_acc > 0.0 and l_acc < MursBasRendu.zone_morte_source(d, MursBas.en_pixels(1.50), h_mur, 0.0))
	_check("un rayon qui ne traverse aucun muret éclaire",
		MursBasRendu.eclaire_par_hauteur(Vector2.ZERO, Vector2(0.0, 10.0 * T), MursBas.en_pixels(0.05), 0.0, murs, h_mur))
	_check("derrière un mur haut, toute source est arrêtée (la règle des murs hauts ne change pas)",
		MursBas.coupe_un_mur_haut(Vector2.ZERO, Vector2(d + 30.0 * T, 0.0), murs))


func _le_shader_suit_la_jumelle() -> void:
	print("\n[Le shader porte la même règle que sa jumelle]")
	var inc := FileAccess.get_file_as_string("res://murs_bas_zone.gdshaderinc")
	_check("la hauteur choisit la règle : 0 celle du jeu, une hauteur réelle celle de la source",
		inc.contains("bool par_hauteur = source.z > 0.0;"))
	_check("au ras du muret ou plus bas, le shader laisse faire l'occluder",
		inc.contains("if (source.z <= mb_h_mur || mb_h_cible >= mb_h_mur)"))
	_check("le rapport de la règle : (h_mur − c) / (h − h_mur)",
		inc.contains("k = (mb_h_mur - mb_h_cible) / (source.z - mb_h_mur);"))
	_check("la zone vaut D × k, D la distance de la source à la sortie du muret",
		inc.contains("float zone = par_hauteur ? t * longueur * k : mb_zone_morte;"))
	_check("la règle du jeu reste la bande constante de MB3c pour une lampe sans hauteur",
		inc.contains("} else if (mb_zone_morte <= 0.0) {"))


func _poser_la_hauteur() -> void:
	print("\n[poser_hauteur_source : la hauteur et le masque, ensemble]")
	var bit := CanauxLumiere.COUCHE_OMBRE_MUR_BAS
	var basse := PointLight2D.new()
	basse.shadow_item_cull_mask = 1 | 2
	MursBasRendu.poser_hauteur_source(basse, 0.05)
	_check("au ras du sol : hauteur de 1,75 px, et elle bute sur les murets",
		is_equal_approx(basse.height, 1.75) and (basse.shadow_item_cull_mask & bit) != 0)
	_check("les autres bits du masque sont gardés", (basse.shadow_item_cull_mask & (1 | 2)) == (1 | 2))
	var haute := PointLight2D.new()
	haute.shadow_item_cull_mask = 1 | bit
	MursBasRendu.poser_hauteur_source(haute, 0.70)
	_check("à hauteur de torse : 24,5 px, et elle passe par-dessus (le bit retiré)",
		is_equal_approx(haute.height, 24.5) and (haute.shadow_item_cull_mask & bit) == 0)
	_check("les murs hauts l'arrêtent toujours", (haute.shadow_item_cull_mask & 1) != 0)
	var au_ras := PointLight2D.new()
	MursBasRendu.poser_hauteur_source(au_ras, MursBas.HAUTEUR_MUR_BAS)
	_check("pile à la hauteur du muret : elle bute (comme `MursBas.franchit`)", (au_ras.shadow_item_cull_mask & bit) != 0)
	_check("la hauteur se relit en tuiles", is_equal_approx(MursBasRendu.hauteur_source(haute), 0.70))
	var led := PointLight2D.new()
	led.height = MursBasRendu.HAUTEUR_SANS_ORIGINE
	_check("le bandeau LED se relit « sans origine » (-1), une lampe neuve « règle du jeu » (0)",
		MursBasRendu.hauteur_source(led) == -1.0 and MursBasRendu.hauteur_source(PointLight2D.new()) == 0.0)
	for l in [basse, haute, au_ras, led]:
		l.free()


func _les_uniformes() -> void:
	print("\n[Les uniformes de la hauteur, dans l'écran de chaque vue]")
	var u := MursBasRendu.uniformes_de_vue(Transform2D.IDENTITY.scaled(Vector2(2, 2)), [], Rect2(0, 0, 1920, 1080))
	_check("la hauteur des murets suit l'échelle de la vue (×2)", is_equal_approx(u["h_mur"], MursBas.hauteur_mur() * 2.0))
	_check("le seuil « sans origine » aussi, à la moitié de la marque",
		is_equal_approx(u["z_sans_origine"], MursBasRendu.HAUTEUR_SANS_ORIGINE))
	var sol := MursBasRendu.materiau_sol()
	MursBasRendu.poser_sol(sol, u)
	_check("le sol reçoit une cible à hauteur 0", float(sol.get_shader_parameter("mb_h_cible")) == 0.0
		and is_equal_approx(float(sol.get_shader_parameter("mb_h_mur")), u["h_mur"]))
	var corps := MursBasRendu.materiau_sol()
	MursBasRendu.poser_corps(corps, u, Vector2.ZERO, true)
	var h_acc := float(corps.get_shader_parameter("mb_h_cible"))
	MursBasRendu.poser_corps(corps, u, Vector2.ZERO, false)
	_check("un corps reçoit la hauteur de sa posture (accroupi, puis debout)",
		is_equal_approx(h_acc, u["h_accroupi"]) and is_equal_approx(float(corps.get_shader_parameter("mb_h_cible")), u["h_debout"]))


func _la_fusee() -> void:
	print("\n[La fusée : haute au lancer, au sol à 0,15]")
	var Fusee: GDScript = load("res://fusee.gd")
	var bit := CanauxLumiere.COUCHE_OMBRE_MUR_BAS
	_check("au lancer, 1,5 tuile ; posée, 0", is_equal_approx(Fusee.hauteur_de_vol(1.0), 1.5) and Fusee.hauteur_de_vol(0.0) == 0.0)
	var croissante := true
	var precedente := -1.0
	for i in 11:
		var h: float = Fusee.hauteur_de_vol(i / 10.0)
		croissante = croissante and h > precedente
		precedente = h
	_check("la hauteur ne remonte jamais en perdant de l'élan", croissante)
	_check("elle passe sous le muret avant de se poser (élan < 0,15)",
		Fusee.hauteur_de_vol(0.14) <= MursBas.HAUTEUR_MUR_BAS and Fusee.hauteur_de_vol(0.15) > MursBas.HAUTEUR_MUR_BAS)
	var f: Node2D = Fusee.new()
	f.set("depart", Vector2(100, 100))
	f.set("direction", Vector2.RIGHT)
	root.add_child(f)
	await process_frame
	var lueur := f.get_node("Halo") as PointLight2D
	_check("en vol, sa lumière est haute et passe par-dessus les murets",
		f.hauteur_source() > 1.0 and (lueur.shadow_item_cull_mask & bit) == 0, "%.2f" % f.hauteur_source())
	f.forcer_age(1.0)
	_check("posée, à 0,15 tuile, elle bute sur les murets",
		is_equal_approx(f.hauteur_source(), MursBasRendu.HAUTEUR_FUSEE_AU_SOL) and (lueur.shadow_item_cull_mask & bit) != 0)
	_check("posée, les murs hauts l'arrêtent toujours", (lueur.shadow_item_cull_mask & 1) != 0)
	f.queue_free()
	await process_frame


func _braises_et_mine() -> void:
	print("\n[Braises et mine : au ras du sol]")
	for chemin in ["res://gadget_braises.gd", "res://gadget_mine.gd"]:
		_check("%s déclare sa hauteur au ras du sol" % chemin.get_file(),
			FileAccess.get_file_as_string(chemin).contains(
				"MursBasRendu.poser_hauteur_source(_lumiere, MursBasRendu.HAUTEUR_AU_RAS_DU_SOL)"))


func _les_deux_lightmaps() -> void:
	print("\n[Les deux lightmaps : les mêmes lumières, chacune dans son repère]")
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
	_check("les lightmaps de J1 et J2 rendent le même monde 2D — les mêmes lumières, les mêmes hauteurs",
		main.vp1.world_2d == main.vp2.world_2d)
	main._pousser_zone_morte()
	for pid in 2:
		var vp: SubViewport = main.vp1 if pid == 0 else main.vp2
		var xf: Transform2D = vp.get_final_transform() * vp.get_canvas_transform()
		var u: Dictionary = MursBasRendu.uniformes_de_vue(xf * (main.arena as Node2D).global_transform,
			main.murs_bas, Rect2(Vector2.ZERO, Vector2(vp.size)))
		var mats: Array = main._materiaux_zone_morte[pid]
		var justes := 0
		for m in mats:
			var sm := m as ShaderMaterial
			if is_equal_approx(float(sm.get_shader_parameter("mb_h_mur")), float(u["h_mur"])) \
					and is_equal_approx(float(sm.get_shader_parameter("mb_z_sans_origine")), float(u["z_sans_origine"])) \
					and float(sm.get_shader_parameter("mb_h_cible")) == 0.0:
				justes += 1
		_check("J%d : le sol et le décor de sa lightmap reçoivent la hauteur des murets dans son repère" % (pid + 1),
			not mats.is_empty() and justes == mats.size(), "%d/%d" % [justes, mats.size()])
	if p != null:
		var poses: Dictionary = await _les_gadgets_en_iso(main, p)
		await _la_fusee_en_iso(main, p)
		await _des_images_seulement(main, p, poses)
		await _l_effacement_dans_la_suie(main, p)
	reglages.mode_iso = false
	main.queue_free()
	await process_frame


# ---------------------------------------------------------------------------
# ÉTAPES 3 À 5 — LES VOLUMES, LES LUEURS, LES MIROIRS
# ---------------------------------------------------------------------------

func _les_shaders() -> void:
	print("\n[Les shaders des volumes et des lueurs]")
	var volume := load("res://volume_iso.gdshader") as Shader
	_check("volume_iso compile et lit les lightmaps des deux joueurs",
		volume != null and _a_l_uniforme(volume, "lumiere_1") and _a_l_uniforme(volume, "lumiere_2")
		and _a_l_uniforme(volume, "densite") and _a_l_uniforme(volume, "masque"))
	var texte := FileAccess.get_file_as_string("res://volume_iso.gdshader")
	# ISO10, 1c — une couche de nuage lit désormais la lumière MOYENNÉE (`lire_lightmap_lissee`), le ruban la lumière
	# nette : ce qui compte ici n'est pas la forme de la lecture, c'est que TOUTES les lectures prennent la lightmap de
	# la caméra qui dessine (`deux`), jamais celle de l'autre joueur.
	_check("une couche lit la lightmap de la caméra qui la dessine (J1 ou J2)",
		texte.contains("bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);")
		and texte.contains("lightmap_pateuse(px, px, aa, deux)")
		and texte.contains("lire_lightmap_lissee(px, max(rayon * lissage_rayon, 1.0), deux)")
		and texte.contains("s += lire_lightmap(p + vec2(cos(t), sin(t)) * r, deux);"))
	_check("une couche recopie la lightmap sans gain : 0 sans lumière, jamais plus claire",
		texte.contains("ALBEDO = c;") and texte.contains("unshaded"))
	_check("aucune couche n'écrit la profondeur (elle ne cache pas ce qui est derrière elle)",
		texte.contains("depth_draw_never"))
	var halo := load("res://halo_iso.gdshader") as Shader
	_check("halo_iso compile", halo != null and _a_l_uniforme(halo, "intensite"))
	for chemin in ["res://volume_iso.gdshader", "res://halo_iso.gdshader", "res://iso_volumes.gd"]:
		var s := FileAccess.get_file_as_string(chemin)
		_check("%s : aucune Light3D, aucune lumière versée" % chemin.get_file(),
			not s.contains("Light3D.new") and not s.contains("OmniLight3D") and not s.contains("SpotLight3D"))


func _les_gadgets_en_iso(main: Node, p: Node) -> Dictionary:
	print("\n[Les dix gadgets, posés par le vrai chemin, ont leur présence iso]")
	var miroirs: Node = p.get("_miroirs")
	var volumes: IsoVolumes = miroirs.get("volumes")
	var poses := {}
	# ⚠️ Un joueur n'a qu'un gadget posé à la fois : chaque pose remplace la précédente. Chaque gadget se
	# juge donc juste après SA pose ; la torche fantôme vient en dernier, pour rester en vie ensuite.
	var ordre: Array = SLUGS_VOXEL.filter(func(s): return s != "torche_fantome") + SLUGS_VOLUME + ["torche_fantome"]
	for i in ordre.size():
		var slug: String = ordre[i]
		var g := await _poser(main, 0, main.p1.global_position + Vector2(110.0, 0.0), slug, 9200 + i)
		poses[slug] = g
		_check("« %s » est posé par le vrai chemin" % slug, g != null)
		if g == null:
			continue
		if SLUGS_VOXEL.has(slug):
			_check("« %s » reçoit son voxel sous le slug du jeu" % slug, miroirs.miroir_de(g) != null)
		if SLUGS_VOLUME.has(slug):
			_le_volume(main, volumes, g, slug)
		match slug:
			"nappe_braises":
				var e: Dictionary = volumes.suivi_de(g, 1)
				_check("la nappe de braises porte son tapis de %d points" % IsoVolumes.POINTS_BRAISES,
					not e.is_empty() and e["genre"] == "braises" and (e["noeuds"] as Array).size() == IsoVolumes.POINTS_BRAISES)
			"mine_magnesium":
				var e: Dictionary = volumes.suivi_de(g, 1)
				_check("la mine non déclenchée n'a aucune lueur (aucun témoin lumineux)",
					not e.is_empty() and (e["noeuds"] as Array).all(func(n): return not (n as Node3D).visible))
			"voile":
				var e: Dictionary = volumes.suivi_de(g, 2)
				var toile: MeshInstance3D = e["noeuds"][0] if not e.is_empty() else null
				_check("la toile du voile est debout, à la hauteur de ses piquets",
					toile != null and (toile.mesh as ImmediateMesh).get_surface_count() == 1
					and is_equal_approx((toile.mesh as ImmediateMesh).get_aabb().end.y, IsoVolumes.HAUTEUR_TOILE * IsoVolumes.TUILE))
			"torche_fantome":
				var e: Dictionary = volumes.suivi_de(g, 1)
				var lentille := g.get_node_or_null(^"Lentille") as CanvasItem
				_check("la lentille de la torche fantôme se lève, et son dessin sort des lightmaps",
					not e.is_empty() and e["genre"] == "lentille" and lentille != null
					and lentille.visibility_layer == Presentation3D.COUCHE_HORS_VUE)
	return poses


## Pose un gadget par `GameState._do_spawn_gadget` et rend le nœud neuf, trois images plus tard.
func _poser(main: Node, pid: int, pos: Vector2, slug: String, numero: int) -> Node2D:
	var avant: Array = main.bullet_container.get_children()
	main._do_spawn_gadget(pid, pos, 0.0, slug, numero)
	var neuf: Node2D = null
	for n in main.bullet_container.get_children():
		if not avant.has(n) and "slug" in n and String(n.get("slug")) == slug:
			neuf = n
	for k in 3:
		await process_frame
	return neuf if is_instance_valid(neuf) else null


func _le_volume(main: Node, volumes: IsoVolumes, g: Node, slug: String) -> void:
	var e: Dictionary = volumes.suivi_de(g)
	var spec: Dictionary = IsoVolumes.VOLUMES[slug]
	var n := int(spec["couches"])
	var ok: bool = not e.is_empty() and e["genre"] == "volume" and (e["noeuds"] as Array).size() == n
	_check("« %s » est un volume de %d couches" % [slug, n], ok)
	if not ok:
		return
	var haut := (e["noeuds"][n - 1] as Node3D).position.y
	_check("« %s » monte à %.2f tuile" % [slug, float(spec["hauteur"])],
		absf(haut - maxf(IsoVolumes.PLANCHER_PX, float(spec["hauteur"]) * IsoVolumes.TUILE)) < 0.01, "%.2f px" % haut)
	var mat: ShaderMaterial = e["mats"][0]
	_check("« %s » : ses couches passent avant les corps et lisent la lightmap de J1" % slug,
		mat.render_priority == IsoVolumes.PRIORITE_VOLUME and mat.render_priority < 0
		and mat.get_shader_parameter("lumiere_1") == main.vp1.get_texture()
		and (mat.get_shader_parameter("canevas_1_x") as Vector2).is_equal_approx(main.vp1.canvas_transform.x))


func _la_fusee_en_iso(main: Node, p: Node) -> void:
	print("\n[La fusée en iso : comète, fumée, lueur]")
	var miroirs: Node = p.get("_miroirs")
	var volumes: IsoVolumes = miroirs.get("volumes")
	var f: Node2D = (load("res://fusee.gd") as GDScript).new()
	f.set("depart", main.p1.global_position + Vector2(0.0, 160.0))
	f.set("direction", Vector2.RIGHT)
	f.set("joueurs", [main.p1, main.p2])
	main.bullet_container.add_child(f)
	for k in 2:
		await process_frame
	var e: Dictionary = volumes.suivi_de(f)
	var coeur := f.get_node("Coeur") as CanvasItem
	_check("en vol, c'est une comète, et son cœur dessiné sort des lightmaps",
		not e.is_empty() and e["genre"] == "comete" and coeur.visibility_layer == Presentation3D.COUCHE_HORS_VUE)
	if not e.is_empty():
		var y := (e["noeuds"][0] as Node3D).position.y
		_check("la comète brûle à la hauteur de sa lumière", absf(y - float(f.call("hauteur_source")) * IsoVolumes.TUILE) < 2.0,
			"%.1f px pour %.2f tuile" % [y, float(f.call("hauteur_source"))])
	f.call("forcer_age", 1.0)
	for k in 3:
		await process_frame
	_check("posée, elle a son voxel, qui tient son cœur hors des lightmaps",
		miroirs.miroir_de(f) != null and coeur.visibility_layer == Presentation3D.COUCHE_HORS_VUE)
	var fumee: Dictionary = volumes.suivi_de(f)
	_check("posée, sa fumée est un volume de %d couches" % int(IsoVolumes.VOLUME_FUSEE["couches"]),
		float(f.call("alpha_fumee")) <= 0.0 or (not fumee.is_empty() and fumee["genre"] == "fumee"),
		"alpha %.2f" % float(f.call("alpha_fumee")))
	var lueur: Dictionary = volumes.suivi_de(f, 1)
	_check("posée et allumée, sa lueur basse brûle",
		not lueur.is_empty() and (lueur["noeuds"][0] as Node3D).visible)
	f.call("eteindre")
	# L'extinction coupe la lumière dans `_physics_process` : on attend des PAS, pas des images.
	for k in 3:
		await physics_frame
	await process_frame
	await process_frame
	lueur = volumes.suivi_de(f, 1)
	_check("éteinte, sa lueur l'est aussi (noir absolu)",
		not lueur.is_empty() and not (lueur["noeuds"][0] as Node3D).visible)
	f.queue_free()
	await process_frame


func _l_effacement_dans_la_suie(main: Node, p: Node) -> void:
	print("\n[Un corps dans la suie s'efface, comme en vue de dessus]")
	# Sa propre suie, à ses pieds : c'est pour l'AUTRE qu'elle masque le corps.
	var suie := await _poser(main, 1, main.p2.global_position, "cartouche_suie", 9300)
	_check("J2 pose sa suie à ses pieds", suie != null and suie.global_position.distance_to(main.p2.global_position) < 40.0)
	# La suie monte sur 12 % de sa vie (9 s) : on attend qu'elle soit pleine.
	for k in 90:
		await physics_frame
	await process_frame
	# ⚠️ **Pas le sprite relu ici** : `visual_enemy.modulate.a` a deux écrivains (la suie dans `_process`,
	# le brouillage dans `_physics_process`), et un pas de physique passé depuis l'image l'a déjà réécrit
	# (« Une propriété à deux écrivains se lit là où le rendu la lit », Pièges connus). La vérité est la
	# règle du jeu elle-même : pour l'autre, `1 − max(occultation, masque)` (`player.gd`).
	var eff: Vector2 = GadgetBase.effacements_a(main.get_tree(), main.p2.global_position)
	var o_jeu := 1.0 - maxf(eff.x, eff.y)
	var voxels: Array = p.get("_voxels")
	var o_iso := 1.0
	if voxels.size() > 1 and voxels[1] is VoxelCorps:
		o_iso = float((voxels[1] as VoxelCorps).materiau().get_shader_parameter("opacite_1"))
	var corps: Array = p.get("_corps")
	var etat := "jeu %.2f, iso %.2f — manche %s, J2 visible %s/%s, sprite ennemi a=%.2f, occultation de la suie %.2f, masque %s, corps iso visible %s" % [
		o_jeu, o_iso, str(main.round_active), str(main.p2.visible), str(main.p2.visual.visible),
		main.p2.visual_enemy.modulate.a if main.p2.visual_enemy != null else -1.0,
		float(suie.call("occultation_pour", main.p2.global_position)) if is_instance_valid(suie) else -1.0,
		str(GadgetBase.effacements_a(main.get_tree(), main.p2.global_position)),
		str((corps[1] as Node3D).visible) if corps.size() > 1 else "?"]
	_check("dans la vue de J1, le corps voxel de J2 pris dans la suie est effacé comme son sprite (%.2f)" % o_iso,
		o_jeu < 0.2 and is_equal_approx(o_iso, o_jeu), etat)


## Couper les images, puis les rendre : aucune valeur de jeu ne bouge.
## ISO13, lot E — le faisceau dans l'air. Trois garanties qui ne se voient pas à l'œil et qu'aucune
## planche ne montrerait : le drapeau est ÉTEINT par défaut ; le masque du rayon est la texture de la
## lampe elle-même (donc le cône ne peut pas diverger de la lumière) ; et le rayon passe par les
## couches ordinaires, qui lisent la lightmap — c'est ce qui lui interdit de rien révéler que le sol
## ne révèle déjà. Une réécriture qui remplacerait le masque par une forme à soi casserait la
## deuxième sans casser l'image, et personne ne le verrait.
func _le_faisceau() -> void:
	print("\n[Le faisceau dans l'air — lot E]")
	var v := IsoVolumes.new()
	_check("le drapeau du faisceau est éteint par défaut", not bool(v.get("faisceaux_actifs")))
	v.free()
	var texte := FileAccess.get_file_as_string("res://iso_volumes.gd")
	_check("le masque du rayon EST la texture de la lampe",
		texte.contains("lampe.texture, lampe.global_rotation"))
	_check("le rayon passe par les couches ordinaires (donc par la lightmap)",
		texte.contains("_couches(e, int(VOLUME_FAISCEAU[\"couches\"]))"))
	_check("le faisceau s'éteint avec la lampe",
		texte.contains("not lampe.enabled or lampe.energy <= 0.0"))
	_check("le drapeau se lit sur les arguments UTILISATEUR (après --)",
		texte.contains("OS.get_cmdline_user_args().has(DRAPEAU_FAISCEAU)"))


func _des_images_seulement(main: Node, p: Node, poses: Dictionary) -> void:
	print("\n[Les images ne sont que des images]")
	var miroirs: Node = p.get("_miroirs")
	var volumes: IsoVolumes = miroirs.get("volumes")
	# J2 pose une nappe de braises : un volume et des lueurs de plus à couper, à côté de la torche de J1.
	var braises := await _poser(main, 1, main.p2.global_position + Vector2(-110.0, 0.0), "nappe_braises", 9301)
	var avant := _instantane(main)
	_check("il y a bien des images à couper (%d)" % volumes.nombre_de_suivis(),
		braises != null and volumes.nombre_de_suivis() >= 3)
	volumes.images_actives = false
	p.call("_suivre")
	var sans := _instantane(main)
	_check("sans les images, plus rien n'est suivi", volumes.nombre_de_suivis() == 0)
	_check("sans les images, les lumières 2D sont les mêmes (énergie, hauteur, masques, couleur)",
		sans["lumieres"] == avant["lumieres"], _ecart(avant["lumieres"], sans["lumieres"]))
	_check("sans les images, les capteurs sont les mêmes", sans["capteurs"] == avant["capteurs"])
	_check("sans les images, les joueurs sont les mêmes", sans["joueurs"] == avant["joueurs"])
	var torche = poses.get("torche_fantome")
	var lentille: CanvasItem = (torche as Node).get_node_or_null(^"Lentille") as CanvasItem if is_instance_valid(torche) else null
	_check("sans les images, le dessin de la lentille est rendu à la lightmap",
		lentille != null and lentille.visibility_layer != Presentation3D.COUCHE_HORS_VUE)
	volumes.images_actives = true
	p.call("_suivre")
	var apres := _instantane(main)
	_check("les images rendues, les lumières 2D n'ont pas bougé", apres["lumieres"] == avant["lumieres"])
	_check("les images rendues, la lentille ressort des lightmaps",
		lentille != null and lentille.visibility_layer == Presentation3D.COUCHE_HORS_VUE)


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


func _a_l_uniforme(shader: Shader, nom: String) -> bool:
	for u in shader.get_shader_uniform_list():
		if u["name"] == nom:
			return true
	return false


# ---------------------------------------------------------------------------

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
