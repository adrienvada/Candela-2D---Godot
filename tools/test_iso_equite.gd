## ISO14 — la bande cachée à tout lacet (`IsoGeometrie`), sur laquelle repose le banc d'équité.
##
## Sans rien rendre :
##   • la direction vers la caméra est celle de `CameraIso.transform_pour` à tout lacet (0, 45, 90, −45, 225) ;
##   • le parcours de grille (`traverser`) : cases, bornes, passage par un coin exact ;
##   • `point_cache` : caché à moins d'une bande devant un mur, visible au-delà, jamais derrière ;
##   • **LA GARDE (4)** : à lacet nul, `part_cachee_case` rend `longueur_cachee / tuile` pour CHAQUE case de sol
##     des six cartes, à 8 comme à 3 rayons — le calcul général ne change rien au chiffre d'aujourd'hui ;
##   • une case de mur isolée à 45° cache `bande × tuile × √2` de sol (deux faces vues), à 2 % près ;
##   • la cohérence que l'option B du banc suppose : sur La Croisée (symétrie centrale), la part cachée d'une
##     case à 45° égale celle de son image à 225°.
##   • le drapeau `--lacet=` / `--lacet-j2=` (étape 2) : éteint par défaut, 0° et A en ligne, ignoré hors débogage, les
##     trois options ; le regard et la killcam bornés dans les axes de la caméra tournée (identiques à 0°) ; la caméra 2D
##     tournée de −L, son haut d'écran égal à celui de l'écran iso.
##
## Lancer : godot --headless --path . --script res://tools/test_iso_equite.gd
extends SceneTree

const PLANCHER := 25

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
	print("=== LA BANDE CACHÉE À TOUT LACET ===")
	await process_frame
	# `load` et non le nom de classe : une suite ne crée pas de dépendance de compilation.
	var Geo: GDScript = load("res://iso_geometrie.gd")
	var Cam: GDScript = load("res://camera_iso.gd")
	var Proto: GDScript = load("res://tools/proto_iso.gd")
	var tuile := float(CandelaTileSet.TILE_SIZE.y)
	var bande: float = Geo.bande_masquee_px(Geo.hauteur_mur_haut() * tuile, 52.0)

	print("\n--- La direction vers la caméra ---")
	for lacet: float in [0.0, 45.0, 90.0, -45.0, 225.0]:
		var t: Transform3D = Cam.transform_pour(Transform2D.IDENTITY, Vector2(1920, 1080), 52.0, lacet)
		var z := Vector2(t.basis.z.x, t.basis.z.z).normalized()
		var d: Vector2 = Geo.vers_camera(lacet)
		_check("lacet %s° : vers_camera = base.z au sol" % lacet, d.distance_to(z) < 1e-6, "%s contre %s" % [d, z])
	_check("lacet 0° : la caméra est au sud (0, 1)", (Geo.vers_camera(0.0) as Vector2).distance_to(Vector2(0, 1)) < 1e-9)

	print("\n--- Le parcours de grille ---")
	var p: Array = Geo.traverser(Vector2(1, 1), Vector2(1, 0), 100.0, tuile)
	_check("horizontal : trois cases (0,0) (1,0) (2,0)", p.size() == 3 and p[0][0] == Vector2i(0, 0)
		and p[1][0] == Vector2i(1, 0) and p[2][0] == Vector2i(2, 0), str(p))
	_check("horizontal : bornes 34 et 69, fin à 100", p.size() == 3 and absf(float(p[0][2]) - 34.0) < 1e-9
		and absf(float(p[1][2]) - 69.0) < 1e-9 and absf(float(p[2][2]) - 100.0) < 1e-9, str(p))
	var diag: Array = Geo.traverser(Vector2(17.5, 17.5), Vector2(1, 1).normalized(), 60.0, tuile)
	_check("diagonale par un coin exact : (0,0) puis (1,1), sans case voisine", diag.size() == 2
		and diag[0][0] == Vector2i(0, 0) and diag[1][0] == Vector2i(1, 1), str(diag))
	var arriere: Array = Geo.traverser(Vector2(50, 50), Vector2(-1, 0), 40.0, tuile)
	_check("vers la gauche : (1,1) puis (0,1)", arriere.size() == 2 and arriere[0][0] == Vector2i(1, 1)
		and arriere[1][0] == Vector2i(0, 1), str(arriere))

	print("\n--- Un point caché devant un mur ---")
	var un_mur := {Vector2i(5, 5): true}
	var sud := Vector2(0, 1)
	_check("à 10 px au nord du mur, caméra au sud : caché",
		Geo.point_cache(Vector2(5.5 * tuile, 5.0 * tuile - 10.0), sud, un_mur, bande, tuile))
	_check("à une bande + 1 px au nord : visible",
		not Geo.point_cache(Vector2(5.5 * tuile, 5.0 * tuile - bande - 1.0), sud, un_mur, bande, tuile))
	_check("à 10 px au SUD du mur (côté caméra) : visible",
		not Geo.point_cache(Vector2(5.5 * tuile, 6.0 * tuile + 10.0), sud, un_mur, bande, tuile))
	var d45: Vector2 = Geo.vers_camera(45.0)
	_check("45° : à 10 px au nord-ouest du coin, sur la diagonale : caché",
		Geo.point_cache(Vector2(5.0, 5.0) * tuile - d45 * 10.0, d45, un_mur, bande, tuile))

	print("\n--- La garde (4) : à lacet nul, le chiffre d'aujourd'hui ---")
	var slugs: PackedStringArray = Proto.cartes_livrees()
	_check("six cartes livrées (%d)" % slugs.size(), slugs.size() == 6)
	var cartes := {}
	for slug in slugs:
		cartes[slug] = Proto.charger_carte_livree(slug)
		var data: Dictionary = cartes[slug]
		var murs := {}
		for c in MapCodec.get_wall_cells(data):
			murs[c] = true
		var cases := 0
		var ecart_max := 0.0
		var ecart_max_3 := 0.0
		for c in MapCodec.get_floor_cells(data):
			if murs.has(c):
				continue
			cases += 1
			var attendu: float = Geo.longueur_cachee(c, murs, bande, tuile) / tuile
			var r8: Vector2 = Geo.part_cachee_case(c, sud, murs, bande, tuile, 8)
			var r3: Vector2 = Geo.part_cachee_case(c, sud, murs, bande, tuile, 3)
			ecart_max = maxf(ecart_max, absf(r8.x - attendu))
			ecart_max_3 = maxf(ecart_max_3, absf(r3.x - attendu))
		# 1e-6 : simple précision des `Vector2` (voir la garde (4) du banc) ; `%e` n'existe pas en GDScript.
		_check("%s : %d cases, part_cachee_case = longueur_cachee / tuile (écart max %s à 8 rayons, %s à 3)"
			% [slug, cases, String.num_scientific(ecart_max), String.num_scientific(ecart_max_3)],
			cases > 0 and ecart_max < 1e-6 and ecart_max_3 < 1e-6)

	print("\n--- Deux faces vues à 45° ---")
	var aire := 0.0
	for x in range(0, 11):
		for y in range(0, 11):
			if Vector2i(x, y) != Vector2i(5, 5):
				aire += float((Geo.part_cachee_case(Vector2i(x, y), d45, un_mur, bande, tuile) as Vector2).x) * tuile * tuile
	var attendue := bande * tuile * sqrt(2.0)
	_check("une case de mur isolée cache bande × tuile × √2 = %.0f px² (mesuré %.0f)" % [attendue, aire],
		absf(aire - attendue) / attendue < 0.02)
	var aire0 := 0.0
	for x in range(0, 11):
		for y in range(0, 11):
			if Vector2i(x, y) != Vector2i(5, 5):
				aire0 += float((Geo.part_cachee_case(Vector2i(x, y), sud, un_mur, bande, tuile) as Vector2).x) * tuile * tuile
	_check("à 0° elle cache bande × tuile = %.0f px² (mesuré %.0f)" % [bande * tuile, aire0],
		absf(aire0 - bande * tuile) < 1e-2)

	print("\n--- L'option B sur une carte à symétrie centrale ---")
	var croisee: Dictionary = cartes.get("map_003_la_croisee", {})
	_check("La Croisée se lit", not croisee.is_empty())
	if not croisee.is_empty():
		var grille := MapCodec.get_grid_size(croisee)
		var murs := {}
		for c in MapCodec.get_wall_cells(croisee):
			murs[c] = true
		var d225: Vector2 = Geo.vers_camera(225.0)
		var ecart := 0.0
		for c in MapCodec.get_floor_cells(croisee):
			if murs.has(c):
				continue
			var image := Vector2i(grille.x - 1 - c.x, grille.y - 1 - c.y)
			var a: float = (Geo.part_cachee_case(c, d45, murs, bande, tuile) as Vector2).x
			var b: float = (Geo.part_cachee_case(image, d225, murs, bande, tuile) as Vector2).x
			ecart = maxf(ecart, absf(a - b))
		_check("part d'une case à 45° = part de son image centrale à 225° (écart max %s)" % String.num_scientific(ecart),
			ecart < 1e-5)

	_drapeau_lacet(Geo)

	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


## ISO14, étape 2 — `--lacet=45`, éteint par défaut, et ce qui tourne avec lui : les options, la règle en ligne, les
## bornes du regard et la boîte de la killcam dans les axes de la caméra, et la caméra 2D tournée de −L.
func _drapeau_lacet(Geo: GDScript) -> void:
	print("\n--- Le drapeau --lacet ---")
	var SM: GDScript = load("res://settings_manager.gd")
	# Q28 = A (Adrien, 2026-09-25) : 45° B par défaut, en ligne compris.
	_check("par défaut : 45°, option B (Q28)", float(SM.LACET_DEFAUT) == 45.0 and String(SM.OPTION_LACET_DEFAUT) == "B")
	_check("EN LIGNE : 45° et B quoi que disent les drapeaux", SM.lacet_du_duel(true, 0.0, "A") == [45.0, "B"]
		and SM.lacet_du_duel(true, 90.0, "C") == [45.0, "B"])
	_check("hors ligne : les valeurs locales", SM.lacet_du_duel(false, 0.0, "A") == [0.0, "A"])
	_check("option A : J2 au même lacet", float(SM.lacet_du_joueur(1, 45.0, "A")) == 45.0)
	_check("option B : J2 à + 180°", float(SM.lacet_du_joueur(1, 45.0, "B")) == 225.0)
	_check("option C : J2 au miroir, −L", float(SM.lacet_du_joueur(1, 45.0, "C")) == -45.0)
	_check("J1 garde le lacet dans toutes les options", float(SM.lacet_du_joueur(0, 45.0, "C")) == 45.0
		and float(SM.lacet_du_joueur(0, 45.0, "B")) == 45.0)
	_check("à 0° en A, 0 pour les deux", float(SM.lacet_du_joueur(0, 0.0, "A")) == 0.0
		and float(SM.lacet_du_joueur(1, 0.0, "A")) == 0.0)
	_check("--lacet=45 → 45", float(SM.lacet_applique(PackedStringArray(["--lacet=45"]))) == 45.0)
	_check("--lacet=270 → −90 (ramené)", absf(float(SM.lacet_applique(PackedStringArray(["--lacet=270"]))) + 90.0) < 1e-9)
	_check("--lacet illisible → le défaut, 45", float(SM.lacet_applique(PackedStringArray(["--lacet=abc"]))) == 45.0)
	_check("sans --lacet → 45", float(SM.lacet_applique(PackedStringArray([]))) == 45.0)
	_check("--lacet=0 → 0 (le retour au jeu d'avant Q28, avec --lacet-j2=A)",
		float(SM.lacet_applique(PackedStringArray(["--lacet=0"]))) == 0.0
		and String(SM.option_lacet_appliquee(PackedStringArray(["--lacet-j2=A"]))) == "A")
	_check("--lacet-j2=b → B", String(SM.option_lacet_appliquee(PackedStringArray(["--lacet-j2=b"]))) == "B")
	_check("sans --lacet-j2 → B", String(SM.option_lacet_appliquee(PackedStringArray([]))) == "B")
	_check("--lacet-j2 n'est pas lu comme --lacet", float(SM.lacet_applique(PackedStringArray(["--lacet-j2=A"]))) == 45.0)
	_check("hors build de débogage, les deux drapeaux sont ignorés",
		(SM.arguments_de_reglage(PackedStringArray(["--lacet=45", "--lacet-j2=B"]), false) as PackedStringArray).is_empty())

	print("\n--- Les axes de la caméra tournée ---")
	var carte := Rect2(0, 0, 1000, 500)
	var vue := Vector2(1920, 1080)
	var p := Vector2(0, 250)
	_check("regard à 0° : le calcul d'avant, à l'identique",
		RegardDuel.centre_du_regard(p, Vector2.ZERO, vue, 2.0, carte, 35.0, 0.0)
		== RegardDuel.centre_du_regard(p, Vector2.ZERO, vue, 2.0, carte, 35.0))
	var a0: Vector2 = RegardDuel.centre_du_regard(p, Vector2.ZERO, vue, 2.0, carte, 35.0, 0.0)
	_check("regard à 0° : la largeur de la vue (960) longe celle de la carte, x borné à 445", a0.is_equal_approx(Vector2(445, 250)),
		str(a0))
	var a90: Vector2 = RegardDuel.centre_du_regard(p, Vector2.ZERO, vue, 2.0, carte, 35.0, 90.0)
	_check("regard à 90° : la hauteur de la vue longe la largeur de la carte, x borné à 235", a90.distance_to(Vector2(235, 250)) < 1e-3,
		str(a90))
	var K: GDScript = load("res://killcam_cadrage.gd")
	var horiz := PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	var vert := PackedVector2Array([Vector2(0, 0), Vector2(0, 100)])
	_check("killcam à 0° : le calcul d'avant, à l'identique", K.cible(horiz, vue, 1.5, 0.0) == K.cible(horiz, vue, 1.5))
	var k90: Dictionary = K.cible(horiz, vue, 1.5, 90.0)
	var k0: Dictionary = K.cible(vert, vue, 1.5, 0.0)
	_check("killcam à 90° : un segment horizontal se cadre comme un vertical à 0°",
		absf(float(k90["zoom"]) - float(k0["zoom"])) < 1e-6, "%s contre %s" % [k90, k0])
	_check("killcam à 90° : le centre reste au milieu du segment", (k90["centre"] as Vector2).distance_to(Vector2(50, 0)) < 1e-3,
		str(k90))
	var GS: GDScript = load("res://game_state.gd")
	var cam := Camera2D.new()
	GS.orienter_camera_2d(cam, 0.0)
	_check("caméra 2D à 0° : ignore_rotation, rotation nulle", cam.ignore_rotation and cam.rotation == 0.0)
	GS.orienter_camera_2d(cam, 45.0)
	var haut := Vector2(0, -1).rotated(cam.rotation)
	_check("caméra 2D à 45° : son haut d'écran est le haut de l'écran iso, −vers_camera(45°)",
		not cam.ignore_rotation and haut.distance_to(-(Geo.vers_camera(45.0) as Vector2)) < 1e-6, str(haut))
	cam.free()
