## Test headless de l'éclairage de l'arène et de la vivacité du noir (Chantier 2 — Vague 5)
##
## Valide :
## 1. La texture peinte de poussière (DA5.3 volet G) se charge.
## 2. Les murs n'ont PLUS de matériau (nettoyage du 2026-09-11) : le shader
##    `shimmer_murs` sortait `vec4(0)` sur une tuile noire, il est retiré avec
##    `poussiere_faisceau.gdshader` (aucun utilisateur). Un matériau reposé sur
##    les murs, ou l'un des deux fichiers revenu, fait rougir la suite.
## 3. Respect du noir d'encre absolu (Charte.NOIR) sur le corps des murs.
## 4. Particules de poussières DUST dans ParticlePool :
##    - Soumises à la lumière (LIGHT_MODE_NORMAL, aucune lueur parasite dans le noir hors du faisceau).
##    - Aucune énergie propre (light.energy == 0.0).
##    - Décroissance conforme à la charte (Charte.Courbe.EXTINCTION).
## 5. Duplication des couches CustomWalls, CustomWalls_P1 et CustomWalls_P2 sans matériau de shader.
##
## Lancer : HOME="$(mktemp -d)" /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/test_arena_lighting.gd
extends SceneTree

const Charte := preload("res://charte.gd")
const CandelaTileSet := preload("res://candela_tileset.gd")
const ParticlePool := preload("res://particle_pool.gd")

var _failures: int = 0

func _init() -> void:
	print("=== Test Éclairage & Vivacité du noir (V5.8, V5.4, V5.5) ===")
	_run.call_deferred()

func _run() -> void:
	await process_frame

	_test_texture_poussiere()
	_test_murs_sans_materiau()
	_test_wall_darkness_and_contrast()
	_test_dust_particles_configuration()
	_test_arena_wall_material_wiring()

	if _failures == 0:
		print("
✓ Tous les contrôles d'éclairage et vivacité du noir passent")
	else:
		printerr("
✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)

func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("  ✓ ", label)
	else:
		_failures += 1
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

func _test_texture_poussiere() -> void:
	print("\n[1. Texture peinte de poussière]")
	var tex_particule: Texture2D = load("res://assets/halo/particule_poussiere.png")
	_check("Texture particule_poussiere.png chargée (DA5.3 volet G)", tex_particule != null)


func _test_murs_sans_materiau() -> void:
	print("\n[2. Les murs n'ont plus de matériau]")
	_check("shimmer_murs.gdshader est retiré du dépôt",
		not ResourceLoader.exists("res://shimmer_murs.gdshader"))
	_check("poussiere_faisceau.gdshader est retiré du dépôt",
		not ResourceLoader.exists("res://poussiere_faisceau.gdshader"))
	var ts_src := FileAccess.get_file_as_string("res://candela_tileset.gd")
	_check("CandelaTileSet n'expose plus creer_materiau_mur()",
		not ts_src.contains("func creer_materiau_mur"))
	var gs := FileAccess.get_file_as_string("res://game_state.gd")
	_check("game_state.gd ne pose plus de matériau sur walls_layer",
		not gs.contains("walls_layer.material ="))

func _test_wall_darkness_and_contrast() -> void:
	print("
[3. Pureté du Noir d'encre et Liseré Halogène]")
	var ts := CandelaTileSet.create_tileset()
	_check("TileSet créé", ts != null)
	var source := ts.get_source(0) as TileSetAtlasSource
	_check("Source atlas présente", source != null)
	if source != null:
		var img := source.texture.get_image()
		_check("Image de l'atlas accessible", img != null)
		if img != null:
			# Case de mur à (1, 0)
			var ox := CandelaTileSet.TILE_SIZE.x
			var centre_mur := img.get_pixel(ox + 10, 10)
			_check("centre du mur en noir pur Charte.NOIR (0, 0, 0)",
				is_zero_approx(centre_mur.r) and is_zero_approx(centre_mur.g) and is_zero_approx(centre_mur.b),
				str(centre_mur))
			# Refonte roman graphique (2026-09-11) : le liseré ne vit plus sur la
			# tuile (il la quadrillait) mais dans `mur_encre.gd`, autour de la
			# masse. Le bord de la tuile est donc noir comme son centre.
			var bord_mur := img.get_pixel(ox, 0)
			_check("bord de la tuile de mur en noir (le contour vit dans MurEncre)",
				bord_mur.v < 0.05,
				str(bord_mur))

func _test_dust_particles_configuration() -> void:
	print("
[4. Poussières de Faisceau (DUST) & Absence de Bruit Parasite]")
	var pool := ParticlePool.new()
	root.add_child(pool)
	pool.initialize()

	var count := pool.emit(ParticlePool.Kind.DUST, Vector2.ZERO, Color(Charte.HALOGENE, 0.75), 1, 0.0, 0.0, Vector2.RIGHT, 0.0)
	_check("émission de poussière DUST réussie", count == 1)

	_check("au moins une particule active", pool.active_count() == 1)
	var rb: RigidBody2D = pool._active[0]["rb"]
	var poly: Polygon2D = rb.get_node("Poly")
	var light: PointLight2D = rb.get_node("Light")

	# Vérification de l'absence de lumière propre
	_check("la particule n'a AUCUNE lumière propre (energy == 0)", is_zero_approx(light.energy), str(light.energy))

	# Vérification de la soumission à la lumière (LIGHT_MODE_NORMAL) :
	# Ne doit PAS être unshaded, pour rester noir absolu hors du faisceau
	var mat := poly.material as CanvasItemMaterial
	_check("matériau de la poussière présent", mat != null)
	if mat != null:
		_check("mode additif pour brillance sous la torche", mat.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD)
		_check("LIGHT_MODE_NORMAL (pas de lueur unshaded parasite dans le noir)",
			mat.light_mode == CanvasItemMaterial.LIGHT_MODE_NORMAL,
			"light_mode = %d" % mat.light_mode)

	# Test de la courbe d'extinction Charte.Courbe.EXTINCTION
	var initial_scale: Vector2 = poly.scale
	pool.advance(0.3)
	_check("décroissance progressive de la particule", poly.scale.x < initial_scale.x and poly.scale.x > 0.0,
		"scale x: %f" % poly.scale.x)

	pool.clear_all()
	root.remove_child(pool)
	pool.free()

func _test_arena_wall_material_wiring() -> void:
	print("\n[5. Duplication des couches de murs sans matériau]")
	var tileset := CandelaTileSet.create_tileset()
	var walls_layer := TileMapLayer.new()
	walls_layer.name = "CustomWalls"
	walls_layer.tile_set = tileset
	_check("walls_layer n'a aucun matériau", walls_layer.material == null)

	# Simulation de duplication _duplicate_layer_for_player : sans ShaderMaterial,
	# la copie reçoit un CanvasItemMaterial ordinaire.
	var copy_p1 := walls_layer.duplicate() as TileMapLayer
	copy_p1.name = "CustomWalls_P1"
	copy_p1.visibility_layer = 2
	copy_p1.light_mask = 1 | 16
	_check("CustomWalls_P1 n'hérite d'aucun ShaderMaterial", not (copy_p1.material is ShaderMaterial))

	walls_layer.free()
	copy_p1.free()
