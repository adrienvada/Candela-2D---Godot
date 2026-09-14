## La géométrie de la vue isométrique (ISO1), et ce qu'elle coûte en équité.
##
## Sans rien rendre :
##   • une boîte par rectangle de `merge_rects`, sur les six cartes livrées, posée
##     exactement sur la collision que le jeu construit ; `build_meshes` déterministe ;
##   • le contrat des hauteurs avec le chantier des murs bas (constantes lues dans
##     `map_geometry.gd` dès qu'elles existent, `H_HAUT` locale sinon) ;
##   • **le test d'équité géométrique** : la bande de sol cachée derrière un mur, par des
##     valeurs connues ; les cases cachées carte par carte, calculées analytiquement
##     PUIS recomptées par lancer de rayons contre les boîtes réellement construites ;
##     la part cachée dans la moitié de chaque joueur. **Le tableau imprimé est celui
##     qu'Adrien lit au jalon H-ISO1 pour fixer `H_HAUT`** ;
##   • le crochet du jeu : `Presentation3D` naît sous la racine, jamais sous `Player*`
##     ni `GameState`, et la couche où partent les sprites n'est lue par aucun des
##     masques VIVANTS (`~4` / `~2`, `game_state.gd` fait foi, pas `main.tscn`).
##
## Lancer : godot --headless --path . --script res://tools/test_iso_geometrie.gd
extends SceneTree

const EPSILON := 0.001
const PLANCHER := 80
const TANGAGE := 52.0
## Les hauteurs du tableau, en tuiles : les trois du banc ISO0.b, le seuil du critère,
## et ce que « des murs hauts, très lisibles » pourrait vouloir dire.
const HAUTEURS := [0.3, 0.45, 0.65, 0.7, 1.0, 1.25, 1.5, 2.0]
## La hauteur des murs hauts tranchée par Adrien le 2026-09-14 (jalon H-ISO1).
const HAUTEUR_DECIDEE := 1.25

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
	print("=== LA GÉOMÉTRIE ISO ET SON ÉQUITÉ ===")
	await process_frame
	# `load` et non le nom de classe : une suite ne crée pas de dépendance de
	# compilation (« Pièges connus »).
	var Geo: GDScript = load("res://iso_geometrie.gd")
	var Proto: GDScript = load("res://tools/proto_iso.gd")
	var slugs: PackedStringArray = Proto.cartes_livrees()
	_check("six cartes livrées (%d)" % slugs.size(), slugs.size() == 6)
	var cartes := {}
	for slug in slugs:
		cartes[slug] = Proto.charger_carte_livree(slug)
		_check("%s se lit" % slug, not (cartes[slug] as Dictionary).is_empty())

	_boites(Geo, cartes)
	_hauteurs(Geo)
	_equite_valeurs_connues(Geo)
	_equite_par_lancer(Geo, cartes)
	_tableau(Geo, cartes)
	await _crochet_et_masques()

	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER],
		_verifications >= PLANCHER)
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------

func _boites(Geo: GDScript, cartes: Dictionary) -> void:
	print("\n--- Une boîte par rectangle, sur la collision du jeu ---")
	for slug in cartes:
		var data: Dictionary = cartes[slug]
		var rects: Array = MapGeometry.merge_rects(MapGeometry.build_grid(data, MapGeometry.Kind.WALLS))
		var attendu := rects.size()
		for sorte in Geo.sortes_de_murs():
			if sorte[2] != "MurHaut":
				attendu += MapGeometry.merge_rects(MapGeometry.build_grid(data, sorte[0])).size()
		var murs: Node3D = Geo.build_meshes(data, null)
		_check("%s : autant de boîtes que de rectangles (%d)" % [slug, attendu],
			murs.get_child_count() == attendu and attendu > 0, "%d boîtes" % murs.get_child_count())

		# La référence n'est pas IsoGeometrie : ce sont les formes que le JEU pose.
		var hote := Node2D.new()
		MapGeometry.build_collisions(data, hote)
		var formes := hote.get_node("%s/Murs" % MapGeometry.BODY_NAME).get_children() \
			.filter(func(n): return n is CollisionShape2D)
		var decalees := 0
		var hauteur_px: float = Geo.hauteur_mur_haut() * CandelaTileSet.TILE_SIZE.y
		for i in mini(formes.size(), murs.get_child_count()):
			var forme: CollisionShape2D = formes[i]
			var boite := murs.get_child(i) as MeshInstance3D
			if Vector2(boite.position.x, boite.position.z).distance_to(forme.position) > EPSILON \
					or Vector2(boite.scale.x, boite.scale.z).distance_to((forme.shape as RectangleShape2D).size) > EPSILON \
					or absf(boite.scale.y - hauteur_px) > EPSILON \
					or absf(boite.position.y - hauteur_px * 0.5) > EPSILON:
				decalees += 1
		_check("%s : chaque boîte recouvre la collision du jeu, posée au sol, à H_haut" % slug,
			decalees == 0 and formes.size() == rects.size(), "%d décalée(s)" % decalees)
		hote.free()

		var bis: Node3D = Geo.build_meshes(data, null)
		var identiques := bis.get_child_count() == murs.get_child_count()
		for i in mini(bis.get_child_count(), murs.get_child_count()):
			var a := murs.get_child(i) as Node3D
			var b := bis.get_child(i) as Node3D
			identiques = identiques and a.name == b.name and a.transform.is_equal_approx(b.transform)
		_check("%s : build_meshes est déterministe (noms et transformations)" % slug, identiques)
		murs.free()
		bis.free()


func _hauteurs(Geo: GDScript) -> void:
	print("\n--- Le contrat des hauteurs avec le chantier des murs bas ---")
	var constantes := (load("res://map_geometry.gd") as Script).get_script_constant_map()
	if constantes.has("HAUTEUR_MUR_HAUT"):
		_check("HAUTEUR_MUR_HAUT existe : elle est lue dans map_geometry.gd",
			absf(Geo.hauteur_mur_haut() - float(constantes["HAUTEUR_MUR_HAUT"])) < EPSILON
			and Geo.source_des_hauteurs() == "map_geometry.gd")
	else:
		_check("pas encore de HAUTEUR_MUR_HAUT : la constante locale H_HAUT fait foi (%s)"
			% str(Geo.H_HAUT), absf(Geo.hauteur_mur_haut() - Geo.H_HAUT) < EPSILON
			and Geo.source_des_hauteurs().begins_with("H_HAUT"))
	var a_des_bas: bool = MapGeometry.Kind.has("LOW_WALLS")
	var sortes: Array = Geo.sortes_de_murs()
	_check("les murs bas sont extrudés si et seulement si Kind.LOW_WALLS existe",
		(sortes.size() == 2) == a_des_bas, "%d sorte(s), LOW_WALLS=%s" % [sortes.size(), a_des_bas])
	print("  Hauteur des murs hauts : %s tuile (%s)" % [str(Geo.hauteur_mur_haut()), Geo.source_des_hauteurs()])


func _equite_valeurs_connues(Geo: GDScript) -> void:
	print("\n--- La bande cachée, par des valeurs calculées à la main ---")
	# tan 52° = 1,279942 ; une tuile = 35 px.
	for cas in [[1.0, 27.345], [0.45, 12.305], [0.65, 17.774], [2.0, 54.690]]:
		var bande: float = Geo.bande_masquee_px(cas[0] * 35.0, TANGAGE)
		_check("mur de %s tuile à 52° : %.2f px cachés (attendu %.2f)" % [str(cas[0]), bande, cas[1]],
			absf(bande - cas[1]) < 0.01)
	_check("à 90° un mur ne cache rien", Geo.bande_masquee_px(35.0, 90.0) < 1e-6)
	_check("disque d'un corps collé : rien de caché sans bande",
		absf(Geo.part_de_corps_colle_cachee(0.0)) < EPSILON)
	_check("disque d'un corps collé : moitié à une bande d'un rayon",
		absf(Geo.part_de_corps_colle_cachee(18.0) - 0.5) < EPSILON)
	_check("disque d'un corps collé : tout à une bande d'un diamètre",
		absf(Geo.part_de_corps_colle_cachee(36.0) - 1.0) < EPSILON)
	var haut: float = Geo.hauteur_mur_haut()
	var bande_haut: float = Geo.bande_masquee_px(haut * 35.0, TANGAGE)
	# Adrien a tranché 1,25 tuile le 2026-09-14 (jalon H-ISO1), au-delà du critère de 18 px,
	# en connaissance de cause. Ce contrôle épingle SA décision : une autre hauteur en service
	# — une constante changée ou perdue à une fusion — doit se voir, pas passer en silence.
	_check("la hauteur en service est celle d'Adrien : %s tuile (bande de %.1f px, critère de l'étude %.0f px dépassé et assumé)"
		% [str(haut), bande_haut, Geo.BANDE_MAX_PX], absf(haut - HAUTEUR_DECIDEE) < EPSILON)


## La vérification indépendante : pour chaque case de sol, des points recomptés par un
## lancer de rayon vers la caméra contre les BOÎTES construites — pas contre la grille,
## pas par la formule de `longueur_cachee()`.
func _equite_par_lancer(Geo: GDScript, cartes: Dictionary) -> void:
	print("\n--- Les cases cachées, recomptées par lancer de rayons sur les boîtes ---")
	var tuile := 35.0
	for slug in cartes:
		var data: Dictionary = cartes[slug]
		var murs_cases := {}
		for c in MapCodec.get_wall_cells(data):
			murs_cases[c] = true
		for h in [0.65, 1.0, 1.5]:
			var boites := _boites_a_la_hauteur(Geo, data, h * tuile)
			var bande: float = Geo.bande_masquee_px(h * tuile, TANGAGE)
			var desaccords := 0
			var caches := 0
			var echantillons := 0
			var desaccords_nord := 0
			for cell in MapCodec.get_floor_cells(data):
				if murs_cases.has(cell):
					continue
				var cache: float = Geo.longueur_cachee(cell, murs_cases, bande, tuile)
				for fy in [0.1, 0.35, 0.6, 0.85, 0.97]:
					var y_local: float = fy * tuile
					# Loin de la frontière analytique : un point posé dessus ne départage rien.
					if absf(y_local - (tuile - cache)) < 0.5:
						continue
					var point := Vector2((cell.x + 0.5) * tuile, cell.y * tuile + y_local)
					var analytique := y_local > tuile - cache
					echantillons += 1
					if analytique:
						caches += 1
					if _cache_par_lancer(point, boites, TANGAGE, 1.0) != analytique:
						desaccords += 1
					# La caméra retournée (au nord) doit, elle, se tromper : preuve que le
					# lancer voit l'orientation des murs.
					if _cache_par_lancer(point, boites, TANGAGE, -1.0) != analytique:
						desaccords_nord += 1
			_check("%s, murs %s t : %d points, %d cachés, le lancer confirme chacun"
				% [slug, str(h), echantillons, caches], desaccords == 0 and caches > 0,
				"%d désaccord(s)" % desaccords)
			_check("%s, murs %s t : la même analyse, caméra au nord, se trompe" % [slug, str(h)],
				desaccords_nord > 0)


func _boites_a_la_hauteur(Geo: GDScript, data: Dictionary, hauteur_px: float) -> Array[AABB]:
	var murs: Node3D = Geo.build_meshes(data, null)
	var out: Array[AABB] = []
	for b in murs.get_children():
		var boite := b as Node3D
		var taille := Vector3(boite.scale.x, hauteur_px, boite.scale.z)
		var centre := Vector3(boite.position.x, hauteur_px * 0.5, boite.position.z)
		out.append(AABB(centre - taille * 0.5, taille))
	murs.free()
	return out


## Un point de sol est caché si le rayon qui en part vers la caméra traverse une boîte.
## `sens` +1 : la caméra au sud (lacet nul, `CameraIso`) ; −1 : au nord.
func _cache_par_lancer(point: Vector2, boites: Array[AABB], tangage: float, sens: float) -> bool:
	var dir := Vector3(0.0, sin(deg_to_rad(tangage)), sens * cos(deg_to_rad(tangage)))
	var origine := Vector3(point.x, 0.0, point.y)
	for boite in boites:
		if origine.x <= boite.position.x or origine.x >= boite.end.x:
			continue
		var t0 := 1e-4
		var t1 := boite.end.y / dir.y
		var tz_a := (boite.position.z - origine.z) / dir.z
		var tz_b := (boite.end.z - origine.z) / dir.z
		t0 = maxf(t0, minf(tz_a, tz_b))
		t1 = minf(t1, maxf(tz_a, tz_b))
		if t0 < t1:
			return true
	return false


func _tableau(Geo: GDScript, cartes: Dictionary) -> void:
	print("\n=== TABLEAU D'ÉQUITÉ — tangage 52°, lacet 0°, caméra au sud ===")
	print("Critère de l'étude : bande < 18 px (rayon d'un corps). Un corps d'une tuile de haut,")
	print("collé derrière un mur, disparaît en entier au-delà de %.1f tuiles de mur."
		% ((35.0 + 2.0 * 18.0 * tan(deg_to_rad(TANGAGE))) / 35.0))
	print("")
	print("EQUITE | mur (t) | bande (px) | critère | disque d'un corps collé caché")
	for h in HAUTEURS:
		var bande: float = Geo.bande_masquee_px(h * 35.0, TANGAGE)
		print("EQUITE | %7s | %10.1f | %7s | %5.0f %%" % [str(h), bande,
			"tenu" if bande < Geo.BANDE_MAX_PX else "DÉPASSÉ", Geo.part_de_corps_colle_cachee(bande) * 100.0])
	print("")
	print("EQUITE | carte                | mur (t) | cases touchées | cases invisibles | sol caché | moitié J1 | moitié J2 | écart")
	var ecarts_symetriques := 0
	for slug in cartes:
		var data: Dictionary = cartes[slug]
		for h in HAUTEURS:
			var r: Dictionary = Geo.analyser_equite(data, h, TANGAGE)
			print("EQUITE | %-20s | %7s | %6d / %-5d | %16d | %8.1f %% | %8.1f %% | %8.1f %% | %+5.1f pts"
				% [slug.left(20), str(h), r["cases_touchees"], r["cases_sol"], r["cases_invisibles"],
				r["part_sol"] * 100.0, r["part_j1"] * 100.0, r["part_j2"] * 100.0,
				(r["part_j1"] - r["part_j2"]) * 100.0])
		# Le miroir gauche-droite ne change rien pour une caméra au sud : le calcul ne
		# doit pas dépendre de l'ordre des colonnes.
		var miroir := _miroir_x(data)
		var a: Dictionary = Geo.analyser_equite(data, 1.0, TANGAGE)
		var b: Dictionary = Geo.analyser_equite(miroir, 1.0, TANGAGE)
		if absf(a["part_sol"] - b["part_sol"]) < 1e-9 and a["cases_touchees"] == b["cases_touchees"]:
			ecarts_symetriques += 1
	_check("le miroir gauche-droite d'une carte cache exactement la même aire (6 cartes)",
		ecarts_symetriques == cartes.size(), "%d / %d" % [ecarts_symetriques, cartes.size()])
	# Des cases invisibles n'apparaissent qu'au-delà de 1,28 tuile : à une tuile, aucune.
	var invisibles_a_un := 0
	var invisibles_a_deux := 0
	for slug in cartes:
		invisibles_a_un += int(Geo.analyser_equite(cartes[slug], 1.0, TANGAGE)["cases_invisibles"])
		invisibles_a_deux += int(Geo.analyser_equite(cartes[slug], 2.0, TANGAGE)["cases_invisibles"])
	_check("aucune case entièrement invisible à une tuile de mur", invisibles_a_un == 0)
	# Ce qui protège encore le jeu à la hauteur décidée : pas de case de sol que la caméra
	# ne montre jamais. Au-delà de 1,28 tuile, chaque case au nord d'un mur le deviendrait.
	var invisibles_en_service := 0
	for slug in cartes:
		invisibles_en_service += int(Geo.analyser_equite(cartes[slug], Geo.hauteur_mur_haut(), TANGAGE)["cases_invisibles"])
	_check("à la hauteur en service (%s t), aucune case de sol entièrement invisible sur les six cartes"
		% str(Geo.hauteur_mur_haut()), invisibles_en_service == 0, "%d" % invisibles_en_service)
	_check("des cases entièrement invisibles à deux tuiles (%d)" % invisibles_a_deux, invisibles_a_deux > 0)


func _miroir_x(data: Dictionary) -> Dictionary:
	var grille := MapCodec.get_grid_size(data)
	var sol: Array[Vector2i] = []
	for c in MapCodec.get_floor_cells(data):
		sol.append(Vector2i(grille.x - 1 - c.x, c.y))
	var murs: Array[Vector2i] = []
	for c in MapCodec.get_wall_cells(data):
		murs.append(Vector2i(grille.x - 1 - c.x, c.y))
	var s1 := MapCodec.get_spawn(data, 0)
	var s2 := MapCodec.get_spawn(data, 1)
	# Par la fabrique et l'encodeur du codec : le format n'est pas deviné ici.
	var carte := MapCodec.new_map("miroir", grille)
	carte["floor"] = MapCodec.encode_runs(sol)
	carte["walls"] = MapCodec.encode_runs(murs)
	carte["spawn_p1"] = {"x": grille.x - 1 - s1.x, "y": s1.y}
	carte["spawn_p2"] = {"x": grille.x - 1 - s2.x, "y": s2.y}
	return carte


func _crochet_et_masques() -> void:
	print("\n--- Le crochet du jeu, l'arbre et les masques vivants ---")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var reglages := root.get_node("GameSettings")
	var avant: bool = reglages.mode_iso
	reglages.mode_iso = true
	main._on_training_requested()
	await process_frame
	await process_frame
	await process_frame
	var p := root.get_node_or_null("Presentation3D")
	_check("le crochet de rebuild_arena a posé /root/Presentation3D", p != null)
	if p != null:
		_check("et son parent est la racine de l'arbre, pas GameState", p.get_parent() == root)
		_check("elle est allumée à l'entraînement (vue unique)", bool(p.get("_actif")))
	var sous_le_jeu := 0
	var noeuds: Array[Node] = [main]
	while not noeuds.is_empty():
		var n: Node = noeuds.pop_back()
		if n is Node3D:
			sous_le_jeu += 1
		noeuds.append_array(n.get_children())
	_check("aucun nœud 3D sous GameState ni sous Player*", sous_le_jeu == 0, "%d" % sous_le_jeu)
	var couche := int((load("res://presentation_3d.gd") as Script).get_script_constant_map()["COUCHE_HORS_VUE"])
	# ISO2 : pendant que la vue iso est allumée, les couches des capteurs de corps (une par
	# capteur) sortent des masques des lightmaps (sinon elles dessineraient un disque blanc
	# sous chaque corps).
	var capteurs := int((load("res://presentation_3d.gd") as Script).get_script_constant_map().get("COUCHES_CAPTEURS", 0))
	for paire in [[main.vp1, ~4], [main.vp2, ~2]]:
		var vue: SubViewport = paire[0]
		# Sur 32 bits : `~4` vaut -5 en GDScript, le masque se relit en entier non signé.
		_check("%s : masque vivant = ~%d, couches des capteurs à part (game_state.gd fait foi, pas main.tscn)" % [vue.name, ~paire[1]],
			(vue.canvas_cull_mask | capteurs) == (paire[1] & 0xFFFFFFFF), str(vue.canvas_cull_mask))
		_check("%s : la couche des sprites retirés (%d) n'y est pas lue" % [vue.name, couche],
			(vue.canvas_cull_mask & couche) == 0 and (vue.canvas_cull_mask & (2 | 4)) != 0)
	_check("la racine ne la lit pas non plus", (root.canvas_cull_mask & couche) == 0)
	var retires := 0
	for nom in p.APPUIS_JOUEUR if p != null else []:
		if (main.p1.get(nom) as CanvasItem).visibility_layer == couche:
			retires += 1
	_check("les dix sprites de corps de J1 sont sur cette couche (%d)" % retires, retires == 10)
	reglages.mode_iso = avant
	main.queue_free()
	await process_frame
	await process_frame
