extends SceneTree

## Suite de tests headless : Matière & décors de l'arène
## (Roman Graphique Brutaliste & Hangar clandestin)
##
## Valide :
## 1. Génération des dalles de béton brut et texture d'atelier (CandelaTileSet).
## 2. Éjection, inertie physique, arrêt CPU et plafond persistant des douilles (BulletCasing).
## 3. Marquages au sol d'atelier (chevrons danger ambre/noir, pochoirs, équerres).
## 4. Habillage mobilier lourd (fûts, caisses, colonnes rivetées) et intégrité physique.
## 5. Règle absolue de la Charte : ZÉRO pixel vert dans l'arène.

const Charte := preload("res://charte.gd")
const CandelaTileSetScript := preload("res://candela_tileset.gd")
const BulletCasingScript := preload("res://bullet_casing.gd")
const ArenaDecorScript := preload("res://arena_decor.gd")
const ColonneAtelierScript := preload("res://colonne_atelier.gd")

var _ok := 0
var _ko := 0


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_ok += 1
		print("  ✓ %s" % label)
	else:
		_ko += 1
		printerr("  ✗ %s%s" % [label, "  → " + detail if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Test Matière & Décors de l'Arène (DA Brutaliste) ===")

	_test_dalles_beton_et_tileset()
	_test_douilles_atelier()
	_test_marquages_et_chevrons_danger()
	_test_habillage_obstacles()
	_test_regle_zero_vert()

	print("
--- %d tests réussis, %d échec(s) ---" % [_ok, _ko])
	quit(0 if _ko == 0 else 1)


func _test_dalles_beton_et_tileset() -> void:
	print("
[1. Sols de béton brut & CandelaTileSet]")
	var ts := CandelaTileSetScript.create_tileset()
	_check("TileSet créé avec succès", ts != null)
	_check("Taille de tuile conforme 35x35", ts.tile_size == Vector2i(35, 35))

	var source: TileSetAtlasSource = ts.get_source(0) as TileSetAtlasSource
	_check("Source atlas présente", source != null)
	_check("Tuile FLOOR_ATLAS_A existe", source.has_tile(CandelaTileSetScript.FLOOR_ATLAS_A))
	_check("Tuile FLOOR_ATLAS_B existe", source.has_tile(CandelaTileSetScript.FLOOR_ATLAS_B))
	_check("Tuile WALL_ATLAS existe", source.has_tile(CandelaTileSetScript.WALL_ATLAS))

	var tex := source.texture
	_check("Texture atlas présente", tex != null)
	var img := tex.get_image()
	_check("Atlas fait 70x70 px", img.get_width() == 70 and img.get_height() == 70)

	# Vérifier que les dalles ont du grain (écart de luminance / aspérités d'encre)
	var min_c := 1.0
	var max_c := 0.0
	for y in range(2, 33):
		for x in range(2, 33):
			var c := img.get_pixel(x, y).v
			min_c = minf(min_c, c)
			max_c = maxf(max_c, c)
	_check("Dalle de béton possède des micro-aspérités d'encre contrastée", (max_c - min_c) > 0.04,
		"delta=%.3f" % (max_c - min_c))

	# Refonte roman graphique (2026-09-11) : la tuile de mur est du noir pur sur
	# toute sa surface — le contour vit dans `mur_encre.gd`, autour de la MASSE,
	# et non plus sur les quatre côtés de chaque tuile (ce qui quadrillait les
	# murs épais). Le bord de la tuile doit donc être aussi noir que son centre.
	var border_pix := img.get_pixel(35, 0)
	_check("Mur : le bord de la tuile est noir (le contour vit dans MurEncre)",
		border_pix.v < 0.05, "v=%.3f" % border_pix.v)

	# Intérieur du mur reste très sombre (respect du fondu additif)
	var center_wall_pix := img.get_pixel(35 + 17, 17)
	_check("Intérieur du mur reste très sombre (noir)", center_wall_pix.v < 0.15,
		"v=%.3f" % center_wall_pix.v)


func _test_douilles_atelier() -> void:
	print("
[2. Douilles d'atelier persistantes]")
	var arena_root := Node2D.new()
	arena_root.name = "TestArena"
	arena_root.visibility_layer = 1
	arena_root.light_mask = 1
	root.add_child(arena_root)

	# 1. Éjection de douilles pour chaque arme
	var c_pistolet := BulletCasingScript.eject(arena_root, Vector2(100, 100), Vector2(1, 0), "pistolet")
	var c_fusil := BulletCasingScript.eject(arena_root, Vector2(100, 100), Vector2(1, 0), "fusil")
	var c_pompe := BulletCasingScript.eject(arena_root, Vector2(100, 100), Vector2(1, 0), "pompe")

	_check("Douille pistolet éjectée", c_pistolet != null)
	_check("Douille fusil éjectée", c_fusil != null)
	_check("Douille pompe éjectée", c_pompe != null)
	_check("Vélocité initiale d'éjection non nulle", c_pistolet.velocity.length() > 30.0)
	_check("Vélocité angulaire initiale non nulle", absf(c_pistolet.angular_velocity) > 0.1)

	# 2. Simulation de l'inertie et arrêt complet
	var dt := 0.05
	for step in 30:
		c_pistolet._process(dt)
	_check("Douille ralentit et s'immobilise au sol", c_pistolet.at_rest)
	_check("Process désactivé au repos (coût CPU nul)", not c_pistolet.is_processing())

	# 3. Test du plafond d'accumulation et éviction FIFO
	var initial_max := BulletCasingScript.MAX_CASINGS
	BulletCasingScript.MAX_CASINGS = 8

	# Nettoyage des douilles précédentes
	for n in root.get_tree().get_nodes_in_group("bullet_casing"):
		n.release()

	var casings: Array = []
	for i in range(12):
		var c := BulletCasingScript.eject(arena_root, Vector2(i * 10, 0), Vector2(1, 0), "pistolet")
		casings.append(c)

	var count_in_group := root.get_tree().get_nodes_in_group("bullet_casing").size()
	_check("Plafond MAX_CASINGS strictement respecté (8)", count_in_group == 8,
		"actuel=%d" % count_in_group)

	# Rétablissement
	BulletCasingScript.MAX_CASINGS = initial_max
	for n in root.get_tree().get_nodes_in_group("bullet_casing"):
		n.release()
	arena_root.queue_free()


func _load_default_map() -> Dictionary:
	var file := FileAccess.open("res://assets/maps/default.json", FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	return json.data as Dictionary


func _test_marquages_et_chevrons_danger() -> void:
	print("\n[3. Marquages au pochoir & bandes de danger chevrons]")
	var test_map := _load_default_map()
	_check("Carte par défaut chargée", not test_map.is_empty())

	var parent := Node2D.new()
	root.add_child(parent)

	var decor := ArenaDecorScript.build(test_map, parent)
	_check("ArenaDecor instancié", decor != null)
	_check("Bandes de danger détectées aux abords du vide", decor._danger_edges.size() > 0,
		"bords=%d" % decor._danger_edges.size())
	_check("Équerres d'angles détectées", decor._corner_brackets.size() > 0)
	_check("Pochoirs de spawn détectés (01 et 02)", decor._stencils.size() >= 2)

	# Duplications pour l'écran partagé
	var p1_decor := parent.get_node_or_null("ArenaDecor_P1") as Node2D
	var p2_decor := parent.get_node_or_null("ArenaDecor_P2") as Node2D
	_check("Copie P1 créée", p1_decor != null)
	_check("Copie P2 créée", p2_decor != null)
	_check("Masque de vue P1 conforme (2)", p1_decor.visibility_layer == 2)
	_check("Masque de lumière P1 conforme (1|16)", p1_decor.light_mask == (1 | 16))
	_check("Masque de vue P2 conforme (4)", p2_decor.visibility_layer == 4)
	_check("Masque de lumière P2 conforme (1|32)", p2_decor.light_mask == (1 | 32))

	parent.queue_free()
func _test_habillage_obstacles() -> void:
	print("
[4. Habillage des obstacles & Intégrité géométrique]")
	# Charger arena.tscn pour vérifier Obstacle1
	var arena_scene: PackedScene = load("res://arena.tscn")
	_check("arena.tscn charge sans erreur", arena_scene != null)

	var arena := arena_scene.instantiate()
	root.add_child(arena)

	var obs1 := arena.get_node_or_null("StaticGeometry/Obstacle1") as StaticBody2D
	_check("Obstacle1 présent dans StaticGeometry", obs1 != null)

	var col_shape := obs1.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_check("CollisionShape2D présent", col_shape != null)
	var circle := col_shape.shape as CircleShape2D
	_check("Rayon de collision strictement conservé (85.0)", circle.radius == 85.0)

	var occluder := obs1.get_node_or_null("LightOccluder2D") as LightOccluder2D
	_check("LightOccluder2D présent", occluder != null)
	_check("Polygone d'occlusion valide (32 sommets)", occluder.occluder.polygon.size() == 32)

	var habillage := obs1.get_node_or_null("Habillage") as Node2D
	_check("Habillage colonne d'atelier présent", habillage != null)
	_check("Rayon de l'habillage calé sur la collision (85.0)", habillage.rayon == 85.0)

	arena.queue_free()


func _test_regle_zero_vert() -> void:
	print("
[5. Règle absolue de la Charte : Zéro vert dans l'arène]")
	var ts := CandelaTileSetScript.create_tileset()
	var source: TileSetAtlasSource = ts.get_source(0) as TileSetAtlasSource
	var img := source.texture.get_image()

	var vert_trouve := false
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			# Détection pixel vert d'interface : G nettement supérieur à R et B avec saturation
			if c.g > 0.4 and c.g > c.r * 1.3 and c.g > c.b * 1.3:
				vert_trouve = true
				break
		if vert_trouve:
			break

	_check("Aucun pixel vert dans l'atlas des tuiles de l'arène", not vert_trouve)
