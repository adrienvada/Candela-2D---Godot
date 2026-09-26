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
	_le_masque_de_la_fumee()
	_les_parametres_existent()
	_le_coeur_de_la_fusee()
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
	# 2026-09-23 — le lissage reçoit désormais le point central déjà lu (`brute`) au lieu de le relire : la
	# signature a changé, l'intention de cette garde n'a pas bougé. On vérifie donc EN PLUS que `brute`
	# est elle-même lue avec `deux` — sans quoi la couche pourrait prendre la lightmap de l'autre joueur
	# par cette nouvelle porte. 2026-09-25 — `rayon` devient `nuage_rayon` (la variante masquée inclut l'usure, dont une
	# locale s'appelle `rayon`) : même garde, nom seul changé.
	_check("une couche lit la lightmap de la caméra qui la dessine (J1 ou J2)",
		texte.contains("bool deux = lightmap_de_j2(CAMERA_VISIBLE_LAYERS);")
		and texte.contains("lightmap_pateuse(px, px, aa, deux)")
		and texte.contains("vec3 brute = lire_lightmap(px, deux);")
		and texte.contains("lire_lightmap_lissee(px, max(nuage_rayon * lissage_rayon, 1.0), deux, brute)")
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
## ISO13, lot E — le drapeau `--faisceau`, réduit au cœur chaud à la lampe : le rayon dans l'air s'est
## arrêté (parallaxe des couches en hauteur, noir absolu, décision d'Adrien du 2026-09-15 ; voir
## `iso_volumes.gd`). La garde qui compte est la troisième : **aucune couche** sur le chemin du drapeau.
## Une densité remise à zéro dessinerait encore — elle poserait des couches, coûterait, et une réécriture
## pourrait les rallumer sans que rien ne rougisse. Ici, une couche rajoutée rougit.
func _le_faisceau() -> void:
	print("\n[Le drapeau du faisceau — lot E, le cœur seul]")
	var v := IsoVolumes.new()
	_check("le drapeau du faisceau est éteint par défaut", not bool(v.get("faisceaux_actifs")))
	v.free()
	var texte := FileAccess.get_file_as_string("res://iso_volumes.gd")
	var debut := texte.find("func _suivre_faisceau(")
	var fin := texte.find("\nfunc ", debut + 1)
	var corps := texte.substr(debut, fin - debut) if debut >= 0 and fin > debut else ""
	_check("la fonction du drapeau existe", not corps.is_empty())
	_check("le drapeau ne pose AUCUNE couche : le rayon est arrêté, pas mis à zéro",
		not corps.is_empty() and not corps.contains("_couches(") and not corps.contains("_poser_couches("))
	_check("il pose le cœur chaud à la lampe", corps.contains("_poser_halo("))
	_check("le cœur s'éteint avec la lampe", corps.contains("not lampe.enabled or lampe.energy <= 0.0"))
	_check("le drapeau se lit sur les arguments UTILISATEUR (après --)",
		texte.contains("for arg in OS.get_cmdline_user_args():"))
	_check("le drapeau dit ce qu'il allume (la preuve qu'il a porté)",
		texte.contains("[faisceau] allumé — le cœur chaud seul"))



## ISO13, Q31 voie A — le masque de la fumée, allumé par défaut (`--sans-fumee-masque` l'éteint). Éteint, le jeu compile le
## shader des volumes d'avant ; allumé, chaque couche passe à la variante FUMEE_MASQUE, dont le seul ajout est de TAIRE la
## couche (jamais de l'éclaircir) là où ce que le pixel montre s'affiche noir.
func _le_masque_de_la_fumee() -> void:
	print("\n[Le masque de la fumée — Q31, voie A]")
	var v := IsoVolumes.new()
	# ALLUMÉ PAR DÉFAUT depuis le 2026-09-25 (Q31, Adrien : le noir d'abord, au prix de 3 % au plus).
	_check("le masque est ALLUMÉ par défaut (Q31) ; --sans-fumee-masque l'éteint",
		bool(v.get("masque_fumee")) and FileAccess.get_file_as_string("res://iso_volumes.gd").contains(
			"elif arg == DRAPEAU_SANS_MASQUE_FUMEE:\n\t\t\tmasque_fumee = false"))
	v.set("masque_fumee", false)
	var eteint: ShaderMaterial = v.call("_materiau_volume")
	_check("éteint, la couche garde le shader des volumes d'avant", eteint.shader == IsoVolumes.SHADER_VOLUME)
	v.set("masque_fumee", true)
	var allume: ShaderMaterial = v.call("_materiau_volume")
	_check("allumé, la couche passe à la variante FUMEE_MASQUE",
		allume.shader != IsoVolumes.SHADER_VOLUME and allume.shader.code.contains("#define FUMEE_MASQUE\n"))
	_check("une seule variante pour toutes les couches (compilée une fois)",
		(v.call("_materiau_volume") as ShaderMaterial).shader == allume.shader)
	_check("la variante est retenue pour recevoir les lightmaps", v.get("_shader_masque") == allume.shader)
	# La variante est un Shader NEUF, sans chemin : un banc qui reconnaît les couches par `==` ou par `resource_path` la
	# saute en silence (piège du 2026-09-25). Les deux qui le faisaient la reconnaissent à son #define.
	_check("les bancs reconnaissent la variante masquée (loupe, banc de la beauté)",
		allume.shader.resource_path == ""
		and FileAccess.get_file_as_string("res://tools/loupe.gd").contains('sh.code.contains("#define FUMEE_MASQUE\\n")')
		and FileAccess.get_file_as_string("res://tools/banc_iso_beaute.gd").contains('sh.code.contains("#define FUMEE_MASQUE\\n")'))
	# La bascule des bancs, sur place : la même couche passe d'un shader à l'autre, sans être recréée.
	v.set("_suivis", {"essai": {"mats": [eteint, allume], "noeuds": [], "retires": []}})
	v.call("poser_masque_fumee", false)
	_check("la bascule éteint le masque sur les couches déjà posées",
		eteint.shader == IsoVolumes.SHADER_VOLUME and allume.shader == IsoVolumes.SHADER_VOLUME)
	v.call("poser_masque_fumee", true)
	_check("la bascule rallume le masque sur les mêmes couches",
		eteint.shader == v.get("_shader_masque") and allume.shader == v.get("_shader_masque")
		and eteint.shader.code.contains("#define FUMEE_MASQUE\n"))
	v.set("_suivis", {})
	v.free()
	var code := IsoVolumes.SHADER_VOLUME.code
	# Le bloc du FRAGMENT qui tait la couche : celui qui appelle le masque (un premier `#ifdef FUMEE_MASQUE`, plus haut, ne
	# déclare que l'include ; un second, en tête du fragment, ne prend que les dérivées).
	var debut := code.rfind("#ifdef FUMEE_MASQUE", code.find("masque_montre_noir(monde"))
	var fin := code.find("#endif", debut)
	var bloc := code.substr(debut, fin - debut) if debut >= 0 and fin > debut else ""
	_check("le masque vit sous #ifdef, pas derrière un uniforme : éteint, rien de plus à exécuter", not bloc.is_empty())
	var decl := code.substr(code.find("#ifdef FUMEE_MASQUE"), 200)
	_check("ce que le pixel montre n'est compilé que dans la variante (l'include sous #ifdef, avant le fragment)",
		decl.contains('#include "res://volume_masque.gdshaderinc"') and code.find("#ifdef FUMEE_MASQUE") < code.find("void fragment()"))
	_check("il ne fait que TAIRE la couche : aucune écriture de couleur ni d'opacité dans le bloc",
		bloc.contains("discard;") and not bloc.contains("ALBEDO") and not bloc.contains("ALPHA") and not bloc.contains("a ="))
	_check("il juge ce que le pixel MONTRE, le long du rayon de vue (caméra orthographique)",
		bloc.contains("masque_montre_noir(monde, -INV_VIEW_MATRIX[2].xyz, deux,"))
	# V1e — le masque lit dans une branche, où les dérivées implicites ne sont pas définies : il reçoit le pas d'un pixel
	# d'écran TIRÉ DE LA CAMÉRA (orthographique), calculé dans le bloc, après le discard — plus aucun dFdx dans la fumée
	# (V1c et V1d en prenaient deux en tête du fragment, sur tous les fragments : +0,43 ms avec le reste).
	_check("les dérivées du masque sont tirées de la caméra, après le discard ; aucun dFdx/dFdy dans la fumée",
		bloc.contains("INV_VIEW_MATRIX[0].xyz * (2.0 / (VIEWPORT_SIZE.x * PROJECTION_MATRIX[0][0]))")
		and bloc.contains("INV_VIEW_MATRIX[1].xyz * (2.0 / (VIEWPORT_SIZE.y * PROJECTION_MATRIX[1][1]))")
		and not _sans_commentaires(code).contains("dFd")
		and not _sans_commentaires(FileAccess.get_file_as_string("res://volume_masque.gdshaderinc")).contains("dFd"))
	# La taille des matières, constante dans le masque (`TAILLE_MATIERE`) : la même que celle des textures du sol et du mur.
	var tex_sol := load("res://assets/iso/sol.png") as Texture2D
	var tex_face := load("res://assets/iso/face_mur.png") as Texture2D
	_check("les deux matières font 512 px, la taille que le masque tient pour constante (niveau de mipmap)",
		tex_sol != null and tex_face != null and tex_sol.get_width() == 512 and tex_sol.get_height() == 512
		and tex_face.get_width() == 512 and tex_face.get_height() == 512
		and FileAccess.get_file_as_string("res://volume_masque.gdshaderinc").contains("const vec2 TAILLE_MATIERE = vec2(512.0);")
		and IsoMateriaux.TEXTURE_SOL == tex_sol and IsoMateriaux.TEXTURE_FACE_MUR == tex_face)
	var inc := FileAccess.get_file_as_string("res://volume_masque.gdshaderinc")
	_check("l'include n'écrit ni couleur ni opacité", not inc.is_empty() and not inc.contains("ALBEDO") and not inc.contains("ALPHA"))
	_check("le rayon est prolongé jusqu'au sol et traverse la grille CASE PAR CASE, frontière par frontière",
		inc.contains("float t_sol = monde.y / max(-vue.y, 1e-3);") and inc.contains("for (int i = 0; i < 4; i++) {")
		and inc.contains("float s_fin = min(min(prochain.x, prochain.y), 1.0);"))
	_check("quatre cases suffisent : aucune couche ne monte au-dessus d'une tuile (son rayon parcourt moins d'une case)",
		float(IsoVolumes.VOLUME_FUSEE["hauteur"]) <= 1.0 and IsoVolumes.VOLUMES.values().all(
			func(v: Dictionary) -> bool: return float(v["hauteur"]) <= 1.0))
	_check("« noir à l'écran » = TOUS les canaux écrits sous le point noir de la sortie 3D (8/255, rampes du 25/09)",
		inc.contains("const float POINT_NOIR_ECRIT = 8.0 / 255.0;") and inc.contains("return max(c.r, max(c.g, c.b)) < POINT_NOIR_ECRIT;")
		and not inc.contains("pate_vers_affiche(pate_c)") and not inc.contains("sol_facteur_min"))
	_check("le SOL se juge sur la couleur que sol_iso ÉCRIT, et une FACE sur celle que mur_iso écrit",
		inc.contains("return sol_montre_noir(p_sol, deux, aa_sol, px_monde_sol, g_x, g_y);")
		and inc.contains("return ecran_noir(face_ecrite(monde + vue * (t_sol * s), n, deux, aa_sol, haut, px_monde_sol));")
		and inc.contains("vec3 c = pate_facteur(lightmap_pateuse_lue(brute, motif, aa), matiere * contact);")
		and inc.contains("return mur_temperature_de(c, brute);"))
	_check("le dessus d'un mur haut est noir strict ; celui d'un muret, la pâte de sa case puis la température",
		inc.contains("if (haut >= mur_haut_px - 0.5) {") and inc.contains("ecran_noir(mur_temperature_de(pate(l, lum, style, q.xz"))
	_check("un point du sol tombé dans une case de mur (le pied exact d'un mur) juge la face de cette frontière",
		inc.contains("return ecran_noir(face_ecrite(vec3(p_sol.x, 0.0, p_sol.y), n, deux, aa_sol, o_fin.r > 0.5 ? mur_haut_px : muret_px,\n\t\t\tpx_monde_sol));"))
	# V1c — une couche qui DÉMARRE dans la case d'un mur n'y passe la profondeur que sur sa surface : on juge la surface par
	# où le rayon, remonté vers la caméra, sort de la case — plus jamais « caché » d'office (21 pixels perdus, y = 605).
	_check("une couche qui démarre dans un mur juge la surface par où le rayon y est entré (face ou dessus), pas « caché »",
		inc.contains("if (s_haut >= max(s_face.x, s_face.y)) {")
		and inc.contains("return dessus_montre_noir(monde + vue * (t_sol * s_haut), haut, deux, aa_sol);")
		and inc.contains("return ecran_noir(face_ecrite(monde + vue * (t_sol * (par_x ? s_face.x : s_face.y)), n_face, deux,")
		and not inc.contains("// La couche est DANS le mur : le mur la cache, rien à montrer."))
	# V1c — chaque surface jugée prend les dérivées qu'elle prend elle-même : la face, `fwidth(motif)` et `fwidth(monde)` ;
	# le sol, `fwidth(px)` ; les mipmaps par `textureGrad` (dans une branche, `texture()` n'a pas de dérivées définies).
	var mur_face := FileAccess.get_file_as_string("res://mur_iso.gdshader")
	# V1f — l'écart DÉCLARÉ de la face (session cloud, 2026-09-25 19:58) : l'aa et px_monde du sol, la matière au niveau 0,
	# là où le mur prend les siens par fwidth. Le sol, lui, garde son niveau de mipmap exact (λ dans la bande).
	_check("la face : l'écart déclaré (V1f) — aa et px_monde du sol, matière au niveau 0 ; le sol garde λ",
		mur_face.contains("float aa = clamp((fwidth(motif.x) + fwidth(motif.y)) / 6.0, 0.02, 0.5);")
		and inc.contains("vec3 face_ecrite(vec3 e, vec2 n, bool deux, float aa, float haut, float px_monde) {")
		and inc.contains("float matiere = mix(1.0, textureLod(texture_face, motif / periode_face_px, 0.0).r, force_matiere);")
		and inc.contains("return max(0.0, log2(max(length(g_x * TAILLE_MATIERE), length(g_y * TAILLE_MATIERE))));")
		and not inc.contains("texture(sol_texture_sol") and not inc.contains("textureGrad("))
	_check("le sol : aa et px_monde de sol_iso (fwidth de son point), tirés des mêmes dérivées",
		FileAccess.get_file_as_string("res://sol_iso.gdshader").contains("float aa = clamp((fwidth(px.x) + fwidth(px.y)) / 6.0, 0.02, 0.5);")
		and FileAccess.get_file_as_string("res://sol_iso.gdshader").contains("float px_monde = max(fwidth(px.x), fwidth(px.y));")
		and inc.contains("float aa_sol = clamp((abs(g_x.x) + abs(g_y.x) + abs(g_x.y) + abs(g_y.y)) / 6.0, 0.02, 0.5);")
		and inc.contains("float px_monde_sol = max(abs(g_x.x) + abs(g_y.x), abs(g_x.y) + abs(g_y.y));"))
	_check("la dérivée d'un point du plan touché : le rayon voisin, décalé, ramené le long de la vue",
		inc.contains("return d - vue * (dot(d, n3) / dot(vue, n3));"))
	# LE SOL, RECOPIÉ de `sol_iso.gdshader` : chaque ligne de son fragment qui fait la couleur se retrouve dans `sol_ecrit`,
	# au préfixe `sol_` près des réglages que la couche porte sous un autre nom.
	var sol_src := FileAccess.get_file_as_string("res://sol_iso.gdshader")
	var corps_sol := _fonction_glsl(inc, "vec3 sol_ecrit(vec2 px, bool deux, float aa, float px_monde, vec2 g_x, vec2 g_y) {")
	# La matière : le seul écart de lecture, déclaré — `textureGrad` avec les dérivées du sol, là où le sol lit `texture()`
	# hors de tout branchement (V1c : dans une branche, le niveau de mipmap n'est pas défini).
	_check("la matière du sol : la même texture, la même adresse, les dérivées du sol (textureGrad)",
		sol_src.contains("float matiere = mix(1.0, texture(texture_sol, px / periode_sol_px).r, force_matiere);")
		and corps_sol.contains("float matiere = mix(1.0, textureLod(sol_texture_sol, px / sol_periode_sol_px,\n\t\tniveau_mip(g_x / sol_periode_sol_px, g_y / sol_periode_sol_px)).r, sol_force_matiere);"))
	var lignes_sol := ["vec2 px_lu = px + glisse * dalles;", "vec2 dans_dalle = abs(fract(px / dalle_px) - 0.5) * dalle_px;",
		"float au_bord = dalle_px * 0.5 - max(dans_dalle.x, dans_dalle.y);",
		"float joint = dalles * pate_trait_de_bord(au_bord, max(joint_dalle_px, px_monde), px_monde);",
		"float dalle = mix(1.0, joint_dalle_reste, joint);", "c = pate_facteur(c, matiere * dalle);",
		"if (temperature_seuil_haut <= 0.0) {", "c = pate_temperature(c, temperature);",
		"} else if (neutre_avant_pate > 0.5) {",
		"c = pate_temperature_graduee_neutre(c, temperature, temperature_seuil_bas, temperature_seuil_haut,",
		"c = pate_temperature_graduee(c, temperature, temperature_seuil_bas, temperature_seuil_haut);",
		"c = pate_facteur(c, contact_des_corps(px));"]
	var manque_sol: Array = []
	for ligne: String in lignes_sol:
		var chez_nous := ligne
		for nom: String in ["texture_sol", "periode_sol_px", "force_matiere", "joint_dalle_reste", "joint_dalle_px", "dalle_px",
				"temperature_seuil_bas", "temperature_seuil_haut", "neutre_avant_pate", "temperature"]:
			chez_nous = RegEx.create_from_string("(?<![A-Za-z_])" + nom + "(?![A-Za-z_])").sub(chez_nous, "sol_" + nom, true)
		if not sol_src.contains(ligne) or not corps_sol.contains(chez_nous):
			manque_sol.append(ligne)
	_check("les %d lignes du sol sont celles de sol_iso.gdshader (au préfixe sol_ près)" % lignes_sol.size(),
		manque_sol.is_empty(), str(manque_sol))
	_check("la neutralité se lit sur la lumière déjà lue, à la même adresse que le sol (une lecture de moins)",
		sol_src.contains("vec3 brute = lire_lightmap(px_lu, deux);") and corps_sol.contains("vec3 lu = lire_lightmap(px_lu, deux);")
		and corps_sol.contains("vec3 brute = lu;"))
	_check("V1b : le sol exact ne se calcule que dans la bande — noir sûr sous 1/1,4 du point noir, visible sûr au-dessus",
		inc.contains("const float SOL_HAUSSE_MAX = 1.4;")
		and inc.contains("if (max(c.r, max(c.g, c.b)) * SOL_HAUSSE_MAX < POINT_NOIR_ECRIT) {")
		and inc.contains("float plancher_sol = (1.0 - sol_force_matiere) * dalle * contact_des_corps(px);")
		and inc.contains("plancher_sol *= mix(1.0, USURE_SOL_PLUS_SOMBRE, usure * smoothstep(USURE_SEUILS.x, USURE_SEUILS.y, pate_luminance(c)));")
		and inc.contains("if (pate_luminance(c) * plancher_sol >= POINT_NOIR_ECRIT) {")
		and inc.contains("return ecran_noir(sol_ecrit(px, deux, aa, px_monde, g_x, g_y));"))
	# V1c — LES COUTURES : à moins de SOL_COUTURE_PX d'un saut du sol (bord de tuile, `marge` de part et d'autre ; les
	# cellules de 6 px de l'usure d'essai), les deux côtés sont jugés et le noir l'emporte (16 pixels de fuite sans elles).
	_check("V1c : aux coutures du sol (bord de tuile, marges, cellules de l'usure), les deux côtés jugés, le noir l'emporte",
		inc.contains("const float SOL_COUTURE_PX = 0.008;")
		and inc.contains("float c = min(min(d, tuile_px - d), min(abs(d - marge), abs(d - (tuile_px - marge))));")
		and sol_src.contains("float marge = joint_2d_px + 0.5;") and sol_src.contains("vec2 glisse = step(dans_tuile, vec2(marge)) * marge - step(vec2(tuile_px - marge), dans_tuile) * marge;")
		and FileAccess.get_file_as_string("res://iso_usure.gdshaderinc").contains("vec2 cellule = floor(px / 6.0);")
		and inc.contains("float u = mod(x, 6.0);")
		and inc.contains("return sol_montre_noir_au_point(px + e, deux, aa, px_monde, g_x, g_y)\n\t\t|| sol_montre_noir_au_point(px - e, deux, aa, px_monde, g_x, g_y)"))
	_check("le contact des corps : la même fonction au caractère près que dans sol_iso.gdshader",
		_fonction_glsl(inc, "float contact_des_corps(vec2 p) {") != ""
		and _fonction_glsl(inc, "float contact_des_corps(vec2 p) {") == _fonction_glsl(sol_src, "float contact_des_corps(vec2 p) {"))
	_check("le ton du damier vaut 1 (TON_EXPOSANT à 0) : la couche peut s'en passer", IsoMateriaux.TON_EXPOSANT == 0.0)
	# L'USURE, EN PARITÉ avec le sol (Q30) : la même variante, le même interrupteur, les mêmes lignes.
	var sans_usure: Shader = IsoVolumes.variante_masque(false)
	var avec_usure: Shader = IsoVolumes.variante_masque(true)
	_check("parité : sans usure, la variante masquée ne porte pas USURE_ESSAI ; avec, elle la porte (et reste masquée)",
		sans_usure.code.contains("#define FUMEE_MASQUE\n") and not sans_usure.code.contains("#define USURE_ESSAI\n")
		and avec_usure.code.contains("#define FUMEE_MASQUE\n") and avec_usure.code.contains("#define USURE_ESSAI\n"))
	var vol_src := FileAccess.get_file_as_string("res://iso_volumes.gd")
	var mat_src := FileAccess.get_file_as_string("res://iso_materiaux.gd")
	_check("parité : la fumée lit l'interrupteur même du sol et des murs (IsoMateriaux.usure_essai_active)",
		vol_src.contains("mat.shader = variante_masque(IsoMateriaux.usure_essai_active())")
		and mat_src.contains("if usure_essai_active():\n\t\tposer_usure_essai(materiau, true)"))
	var usure_src := FileAccess.get_file_as_string("res://iso_usure.gdshaderinc")
	var ligne_usure := "c = pate_facteur(c, usure_poids(c, usure_sol(px, usure_mur_pres(px), px_monde)));"
	_check("l'usure du sol : la ligne de sol_iso, à sa place (après la température, avant le contact)",
		sol_src.contains(ligne_usure) and corps_sol.contains(ligne_usure)
		and corps_sol.find(ligne_usure) > corps_sol.find("pate_temperature_graduee(c, sol_temperature")
		and corps_sol.find(ligne_usure) < corps_sol.find("c = pate_facteur(c, contact_des_corps(px));"))
	_check("la proximité des murs : la fonction de iso_usure au caractère près",
		_fonction_glsl(inc, "float usure_mur_pres(vec2 px) {") != ""
		and _fonction_glsl(inc, "float usure_mur_pres(vec2 px) {") == _fonction_glsl(usure_src, "float usure_mur_pres(vec2 px) {"))
	_check("le plus sombre de l'usure au sol est bien 0,45 (gravats) — le grain ne descend pas sous 0,84",
		inc.contains("const float USURE_SOL_PLUS_SOMBRE = 0.45;") and usure_src.contains("f = min(f, mix(1.0, 0.45, max(eclat, 0.5 * ombre)));")
		and usure_src.contains("float f = 1.0 - 0.16 * mur_pres * pate_bruit(px / 6.0);"))
	_check("l'usure d'une face : l'appel de mur_iso, sur le point montré",
		FileAccess.get_file_as_string("res://mur_iso.gdshader").contains("c = pate_facteur(c, usure_poids(c, usure_face(monde.xz, n, tangente, hauteur_face, taille.y, px_monde)));")
		and inc.contains("c = pate_facteur(c, usure_poids(c, usure_face(e.xz, n, tangente, e.y, haut, px_monde)));"))
	var manque_reglages: Array = []
	for nom: String in IsoVolumes.PARAMETRES_DU_SOL:
		if RegEx.create_from_string("uniform [A-Za-z0-9_]+ " + nom + "\\b").search(sol_src) == null \
				or RegEx.create_from_string("uniform [A-Za-z0-9_]+ " + String(IsoVolumes.PARAMETRES_DU_SOL[nom]) + "\\b").search(inc) == null:
			manque_reglages.append(nom)
	var mur_src := FileAccess.get_file_as_string("res://mur_iso.gdshader")
	for nom: String in IsoVolumes.TEMPERATURE_DU_MUR:
		if RegEx.create_from_string("uniform [A-Za-z0-9_]+ " + nom + "\\b").search(mur_src) == null \
				or RegEx.create_from_string("uniform [A-Za-z0-9_]+ " + String(IsoVolumes.TEMPERATURE_DU_MUR[nom]) + "\\b").search(inc) == null:
			manque_reglages.append("mur:" + nom)
	for nom: String in IsoVolumes.CONTACT_PAR_IMAGE:
		if RegEx.create_from_string("uniform [A-Za-z0-9_]+ " + nom + "\\b").search(inc) == null:
			manque_reglages.append("image:" + nom)
	_check("les réglages recopiés du sol et du mur sont des uniformes des deux côtés", manque_reglages.is_empty(),
		str(manque_reglages))
	# Le glissement de la lecture du sol, RECOPIÉ de `sol_iso.gdshader` : les mêmes trois lignes.
	var sol_code := FileAccess.get_file_as_string("res://sol_iso.gdshader")
	var glissement := ["vec2 dans_tuile = fract(p", "float marge = joint_2d_px + 0.5;",
		"vec2 glisse = step(dans_tuile, vec2(marge)) * marge - step(vec2(tuile_px - marge), dans_tuile) * marge;"]
	var glisse_ok := true
	for ligne: String in glissement:
		glisse_ok = glisse_ok and inc.contains(ligne) and sol_code.contains(ligne)
	_check("le sol se lit où sol_iso.gdshader le lit : glissé vers le centre de la tuile près d'un joint",
		glisse_ok and inc.contains("vec3 lu = lire_lightmap(px_lu, deux);") and inc.contains("vec2 px_lu = px + glisse * dalles;")
		and sol_code.contains("vec2 px_lu = px + glisse * dalles;"))
	# Les cinq fonctions du mur, RECOPIÉES : elles ne doivent pas diverger de `mur_iso.gdshader`.
	var mur_code := FileAccess.get_file_as_string("res://mur_iso.gdshader")
	for sig in ["vec3 lire_etalon(vec2 px) {", "vec3 lire_lumiere(vec2 px, bool deux, vec3 ref, float plancher) {",
			"vec3 lire_lumiere_moyenne(vec2 p, vec2 le_long, bool deux, vec3 ref, float plancher) {",
			"vec3 lightmap_pateuse_lue(vec3 c, vec2 motif, float aa) {", "vec2 occupe(vec2 px) {"]:
		_check("« %s » : la même au caractère près que dans mur_iso.gdshader" % sig.trim_suffix(" {"),
			_fonction_glsl(inc, sig) != "" and _fonction_glsl(inc, sig) == _fonction_glsl(mur_code, sig))
	# Les réglages recopiés du mur existent des deux côtés, sous le même nom (sinon la copie est muette).
	var manquants: Array = []
	for nom: String in IsoVolumes.PARAMETRES_DU_MUR:
		var motif := RegEx.create_from_string("uniform [A-Za-z0-9_]+ " + nom + "\\b")
		if motif.search(mur_code) == null or motif.search(inc) == null:
			manquants.append(nom)
	_check("les %d réglages recopiés du mur sont des uniformes du mur ET de l'include" % IsoVolumes.PARAMETRES_DU_MUR.size(),
		manquants.is_empty(), str(manquants))
	var texte := FileAccess.get_file_as_string("res://iso_volumes.gd")
	var pousse := texte.substr(texte.find("func _pousser_lightmaps("), 600)
	_check("les lightmaps vont AUSSI à la variante masquée (sans elles, la couche lit la texture par défaut et s'éclaire)",
		pousse.contains("s == SHADER_VOLUME or (s != null and s == _shader_masque)"))
	_check("le drapeau dit ce qu'il allume, lu sur la variante posée (la preuve qu'il a porté)",
		texte.contains("[fumée masque] allumé — variante FUMEE_MASQUE posée"))


## Le corps d'une fonction GLSL, de sa signature à l'accolade fermante en début de ligne ; "" si absente.
func _fonction_glsl(code: String, signature: String) -> String:
	var debut := code.find(signature)
	if debut < 0:
		return ""
	var fin := code.find("\n}\n", debut)
	return code.substr(debut, fin + 3 - debut) if fin > debut else ""


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


## ESSAI (session cloud, 2026-09-25 21:41) — le cœur de la fusée posée, éteint par défaut : le choix d'ISO3 et d'ISO4 (le
## voxel remplace le cœur, sans émettre) reste le jeu tant qu'Adrien n'a pas tranché. L'essai reprend le cœur de la comète.
func _le_coeur_de_la_fusee() -> void:
	print("\n[Le cœur de la fusée posée — essai]")
	var v := IsoVolumes.new()
	var src := FileAccess.get_file_as_string("res://iso_volumes.gd")
	_check("l'essai est éteint par défaut (coeur_fusee = 0) : le voxel remplace le cœur, comme ISO3/ISO4 l'ont voulu",
		int(v.get("coeur_fusee")) == 0)
	_check("le cœur ne se pose que si l'essai est allumé",
		src.contains("\tif coeur_fusee > 0:\n\t\t_suivre_coeur_fusee(f, lumiere, energie, relative, vus)"))
	_check("le cœur posé est celui de la comète : 10 px, à bord franc, de la couleur de la lumière",
		is_equal_approx(IsoVolumes.TAILLE_COEUR_FUSEE, 10.0) and src.contains("_poser_halo(e, 0, p, 10.0, couleur, eclat, 1)")
		and src.contains("TAILLE_COEUR_FUSEE,\n\t\tcouleur, maxf(clampf(energie / 0.8, 0.0, 1.5) * opacite, opacite), 1)")
		and IsoVolumes.HAUTEUR_COEUR_FUSEE_PX > (VoxelObjet.FUSEE_BRAISE_Y0 + VoxelObjet.FUSEE_BRAISE.y) * IsoVolumes.TUILE)
	# Parité avec la 2D (session cloud, 21:54) : l'éclat ne tombe jamais sous l'opacité du point de braise 2D — au résidu, la
	# formule de la comète (énergie / 0,8 × opacité) l'effaçait (0,02) là où la 2D le montre encore.
	_check("l'éclat du cœur ne tombe jamais sous l'opacité du cœur 2D (lisible au résidu, comme en 2D)",
		src.contains("var opacite := coeur.modulate.a if coeur != null else 1.0"))
	_check("le presque-blanc ne vient qu'au plein feu et revient au rouge avec l'énergie",
		src.contains("couleur = couleur.lerp(COULEUR_COEUR_BLANC, smoothstep(0.6, 0.95, relative))")
		and src.contains("if coeur_fusee >= 2:"))
	v.free()


## 2026-09-25 — `set_shader_parameter` sur un nom qu'aucun uniforme ne porte ne dit RIEN : ni erreur, ni avertissement,
## la valeur est perdue. Le renommage des uniformes du nuage (`centre`, `rayon`, `angle`, `coeur`, `graine` → `nuage_*`,
## que l'usure incluse dans la variante masquée déclare aussi en locales) l'aurait laissé passer en silence. Chaque nom
## posé EN DUR par `iso_volumes.gd` sur un matériau de fumée doit être un uniforme du shader qui le reçoit.
func _les_parametres_existent() -> void:
	print("\n[Chaque paramètre posé sur la fumée existe dans son shader]")
	var src := FileAccess.get_file_as_string("res://iso_volumes.gd")
	var volume := IsoVolumes.SHADER_VOLUME
	var masque: Shader = IsoVolumes.variante_masque(true)
	var manque: Array = []
	var vus := 0
	for f: Array in [["_suivre_toile", volume], ["_materiau_volume", volume], ["_poser_couches", volume],
			["_recopier_le_mur", masque]]:
		var corps := _fonction_gd(src, String(f[0]))
		if corps.is_empty():
			manque.append("fonction introuvable : " + String(f[0]))
			continue
		for m in RegEx.create_from_string('set_shader_parameter\\("([A-Za-z_0-9]+)"').search_all(corps):
			vus += 1
			if not _a_l_uniforme(f[1] as Shader, m.get_string(1)):
				manque.append("%s : %s" % [f[0], m.get_string(1)])
	# Les lightmaps, posées par nom calculé sur les couches (et sur la variante masquée) : les noms réels.
	for nom in ["lumiere_1", "lumiere_2", "canevas_1_x", "canevas_1_y", "canevas_1_o", "canevas_2_x", "canevas_2_y",
			"canevas_2_o", "taille_1", "taille_2", "style"]:
		vus += 1
		if not _a_l_uniforme(volume, nom) or not _a_l_uniforme(masque, nom):
			manque.append("_pousser_lightmaps : " + nom)
	_check("les %d paramètres posés en dur sur la fumée sont des uniformes de leur shader" % vus,
		vus >= 20 and manque.is_empty(), str(manque))


## Un code GLSL sans ses commentaires de ligne : une garde qui interdit un appel ne doit pas rougir sur le commentaire qui
## raconte pourquoi il a été retiré.
func _sans_commentaires(code: String) -> String:
	return RegEx.create_from_string("//[^\\n]*").sub(code, "", true)


## Le corps d'une fonction GDScript de premier niveau, jusqu'à la suivante.
func _fonction_gd(code: String, nom: String) -> String:
	var debut := code.find("\nfunc %s(" % nom)
	if debut < 0:
		return ""
	var fin := code.find("\nfunc ", debut + 1)
	var fin_statique := code.find("\nstatic func ", debut + 1)
	if fin_statique >= 0 and (fin < 0 or fin_statique < fin):
		fin = fin_statique
	return code.substr(debut, (fin if fin > 0 else code.length()) - debut)


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
