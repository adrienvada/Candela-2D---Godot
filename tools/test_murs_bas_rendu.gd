## Test headless de la zone morte au rendu — chantier MURS BAS, étape MB3c.
##
## Ce qui se vérifie sans fenêtre : que `MursBasRendu` porte aux matériaux les
## bons murs (rentrés, en écran, triés au champ, plafonnés) et les bonnes
## longueurs ; que les shaders qui doivent suivre la règle l'incluent ; que seule
## la lampe sans point d'origine porte la hauteur qui l'en exempte.
##
## Ce qui ne se vérifie qu'en fenêtre — que le PIXEL suive `MursBas.franchit` —
## est au banc `tools/banc_murs_bas.tscn`.
##
## Lancer : godot --headless --path . --script res://tools/test_murs_bas_rendu.gd
extends SceneTree

var _failures := 0


func _init() -> void:
	print("=== Test zone morte au rendu (MB3c) ===")
	_test_longueurs()
	_test_murs_rentres_en_ecran()
	_test_champ_et_plafond()
	_test_poser()
	_test_shaders_incluent_la_regle()
	_test_hauteur_des_lampes()
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  — " + detail) if detail != "" else "")


const ECRAN := Rect2(0, 0, 1920, 1080)


func _test_longueurs() -> void:
	print("\n[Longueurs de zone morte, en pixels d'écran]")
	var h_mur := MursBas.hauteur_mur()  # déjà en pixels
	var attendu_sol := MursBas.longueur_zone_morte(h_mur, 0.0, MursBas.ANGLE_FRANCHISSEMENT)
	var attendu_acc := MursBas.longueur_zone_morte(h_mur,
		MursBas.en_pixels(MursBas.HAUTEUR_ACCROUPI), MursBas.ANGLE_FRANCHISSEMENT)
	var u := MursBasRendu.uniformes_de_vue(Transform2D.IDENTITY, [], ECRAN)
	_check("sol : la longueur de la règle", is_equal_approx(u["l_sol"], attendu_sol),
		"%f / %f" % [u["l_sol"], attendu_sol])
	_check("accroupi : la longueur de la règle", is_equal_approx(u["l_accroupi"], attendu_acc))
	_check("valeurs de H-MB0 : ~58 px au sol, ~44 px accroupi",
		absf(u["l_sol"] - 58.0) < 1.0 and absf(u["l_accroupi"] - 44.0) < 1.0,
		"%.1f / %.1f" % [u["l_sol"], u["l_accroupi"]])
	var zoom := MursBasRendu.uniformes_de_vue(Transform2D.IDENTITY.scaled(Vector2(2, 2)), [], ECRAN)
	_check("un zoom ×2 double les longueurs (la géométrie est invariante par similitude)",
		is_equal_approx(zoom["l_sol"], attendu_sol * 2.0) and is_equal_approx(zoom["l_accroupi"], attendu_acc * 2.0))


func _test_murs_rentres_en_ecran() -> void:
	print("\n[Murs rentrés comme leurs occluders, en écran]")
	var r := MapGeometry.OCCLUDER_INSET
	var u := MursBasRendu.uniformes_de_vue(Transform2D.IDENTITY, [Rect2(0, 0, 35, 70)], ECRAN)
	var m: Vector4 = (u["murs"] as PackedVector4Array)[0]
	_check("un mur, rentré de OCCLUDER_INSET", u["nb"] == 1 and m == Vector4(r, r, 35 - r, 70 - r), str(m))
	_check("le tableau fait toujours MURS_MAX (taille de l'uniforme)",
		(u["murs"] as PackedVector4Array).size() == MursBasRendu.MURS_MAX)
	# Caméra : zoom 2 puis décalage — l'ordre de `get_canvas_transform()`.
	var xf := Transform2D(0.0, Vector2(2, 2), 0.0, Vector2(100, -50))
	u = MursBasRendu.uniformes_de_vue(xf, [Rect2(0, 0, 35, 70)], ECRAN)
	m = (u["murs"] as PackedVector4Array)[0]
	var a := xf * Vector2(r, r)
	var b := xf * Vector2(35 - r, 70 - r)
	_check("transformé par la vue", m == Vector4(a.x, a.y, b.x, b.y), "%s / %s %s" % [m, a, b])
	# Un miroir renverse les coins : le rectangle doit rester (min, max).
	var miroir := Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2(500, 0))
	u = MursBasRendu.uniformes_de_vue(miroir, [Rect2(0, 0, 35, 70)], ECRAN)
	m = (u["murs"] as PackedVector4Array)[0]
	_check("coins remis dans l'ordre (xmin < xmax)", m.x < m.z and m.y < m.w, str(m))


func _test_champ_et_plafond() -> void:
	print("\n[Champ de la vue et plafond de l'uniforme]")
	var u := MursBasRendu.uniformes_de_vue(Transform2D.IDENTITY,
		[Rect2(5000, 5000, 35, 35), Rect2(100, 100, 35, 35)], ECRAN)
	_check("un mur loin hors de l'écran n'est pas envoyé", u["nb"] == 1)
	# Un mur hors de l'écran, mais dont la zone morte y tombe : il compte.
	u = MursBasRendu.uniformes_de_vue(Transform2D.IDENTITY, [Rect2(-60, 500, 35, 35)], ECRAN)
	_check("un mur juste hors de l'écran, à moins d'une zone morte, est envoyé", u["nb"] == 1)
	var nombreux: Array = []
	for i in 70:
		nombreux.append(Rect2(i * 20.0, 10.0, 10.0, 10.0))
	u = MursBasRendu.uniformes_de_vue(Transform2D.IDENTITY, nombreux, ECRAN)
	_check("au-delà de MURS_MAX : plafonné, et le débordement compté",
		u["nb"] == MursBasRendu.MURS_MAX and u["debordement"] == 70 - MursBasRendu.MURS_MAX,
		"%d / %d" % [u["nb"], u["debordement"]])
	var essai := _carte_essai()
	var murs := MapGeometry.rects_monde(essai, MapGeometry.Kind.LOW_WALLS)
	_check("la carte d'essai tient dans l'uniforme, même vue en entier",
		murs.size() > 0 and murs.size() <= MursBasRendu.MURS_MAX, str(murs.size()))


func _test_poser() -> void:
	print("\n[Uniformes posés sur les matériaux]")
	var u := MursBasRendu.uniformes_de_vue(Transform2D.IDENTITY, [Rect2(0, 0, 35, 35)], ECRAN)
	var sol := MursBasRendu.materiau_sol()
	MursBasRendu.poser_sol(sol, u)
	_check("sol : longueur L_sol, jugé pixel par pixel",
		is_equal_approx(sol.get_shader_parameter("mb_zone_morte"), u["l_sol"])
		and sol.get_shader_parameter("mb_au_centre") == false
		and sol.get_shader_parameter("mb_nb_murs") == 1)
	var corps := ShaderMaterial.new()
	corps.shader = preload("res://player_enemy_light.gdshader")
	MursBasRendu.poser_corps(corps, u, Vector2(300, 200), true)
	_check("corps accroupi : L_accroupi, jugé en son centre",
		is_equal_approx(corps.get_shader_parameter("mb_zone_morte"), u["l_accroupi"])
		and corps.get_shader_parameter("mb_au_centre") == true
		and corps.get_shader_parameter("mb_centre") == Vector2(300, 200))
	MursBasRendu.poser_corps(corps, u, Vector2(300, 200), false)
	_check("corps debout : aucune zone (« un mur bas laisse voir une tête debout »)",
		corps.get_shader_parameter("mb_zone_morte") == 0.0)
	MursBasRendu.poser_sol(null, u)
	_check("matériau absent : rien ne casse", true)
	_check("deux matériaux de sol neufs sont distincts (un par vue)",
		MursBasRendu.materiau_sol() != MursBasRendu.materiau_sol())


func _test_shaders_incluent_la_regle() -> void:
	print("\n[Shaders qui portent la règle]")
	var include := "#include \"res://murs_bas_zone.gdshaderinc\""
	for chemin in ["res://murs_bas_sol.gdshader", "res://murs_bas_decor.gdshader",
			"res://player_rim_light.gdshader", "res://player_enemy_light.gdshader"]:
		var source := FileAccess.get_file_as_string(chemin)
		_check("%s inclut la zone morte" % chemin.get_file(),
			source.contains(include) and source.contains("mb_dans_la_zone_morte(LIGHT_POSITION, LIGHT_VERTEX)"))
	_check("le sol reste additif, comme le CanvasItemMaterial qu'il remplace",
		FileAccess.get_file_as_string("res://murs_bas_sol.gdshader").contains("render_mode blend_add"))
	_check("le décor reste en mélange normal",
		not FileAccess.get_file_as_string("res://murs_bas_decor.gdshader").contains("blend_add"))
	var inc := FileAccess.get_file_as_string("res://murs_bas_zone.gdshaderinc")
	_check("l'uniforme a la taille de MURS_MAX",
		inc.contains("uniform vec4 mb_murs[%d];" % MursBasRendu.MURS_MAX))
	_check("une lampe à hauteur non nulle est exemptée", inc.contains("source.z > 0.0"))
	for chemin in ["res://murs_bas_sol.gdshader", "res://murs_bas_decor.gdshader",
			"res://player_rim_light.gdshader", "res://player_enemy_light.gdshader"]:
		var s := load(chemin) as Shader
		_check("%s compile (uniformes de l'include visibles)" % chemin.get_file(),
			s != null and _a_l_uniforme(s, "mb_murs"))


func _test_hauteur_des_lampes() -> void:
	print("\n[Seule la lampe sans point d'origine porte une hauteur]")
	var arene := Node2D.new()
	var led := MurLed.poser(_carte_essai(), arene, Callable())
	_check("le bandeau LED porte HAUTEUR_SANS_ORIGINE",
		led != null and led.height == MursBasRendu.HAUTEUR_SANS_ORIGINE)
	arene.free()
	_check("une lampe neuve a une hauteur nulle (la règle s'applique)", PointLight2D.new().height == 0.0)
	# Toute AUTRE lampe qui poserait une hauteur sortirait de la règle sans bruit.
	var motif := RegEx.create_from_string("(?i)(light|lumiere|flash|halo|led)\\w*\\.height\\s*=")
	var coupables: Array = []
	for fichier in DirAccess.open("res://").get_files():
		if fichier.ends_with(".gd") and motif.search(FileAccess.get_file_as_string("res://" + fichier)) != null:
			coupables.append(fichier)
	_check("aucun autre script ne pose la hauteur d'une lampe", coupables == ["mur_led.gd"], str(coupables))
	for scene in ["res://player.tscn"]:
		_check("%s : aucune hauteur de lampe" % scene.get_file(),
			not FileAccess.get_file_as_string(scene).contains("height ="))


func _a_l_uniforme(shader: Shader, nom: String) -> bool:
	for u in shader.get_shader_uniform_list():
		if u["name"] == nom:
			return true
	return false


func _carte_essai() -> Dictionary:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string("res://tools/cartes/murs_bas_essai.json"))
	return MapCodec.validate(json.data as Dictionary)["data"]
