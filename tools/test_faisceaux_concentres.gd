extends SceneTree

## Chantier des lumières de la 0.8.0, L1bis — les faisceaux plus concentrés (Adrien, 2026-09-29 : « le plus petit fait 10°
## et le plus grand 60° », en gardant les rapports d'angle au mieux — la loi de puissance, `WeaponData.ouverture_concentree`).
##
## Ce qu'elle garde :
## - la loi : les deux bornes exactes (10° et 60° d'ouverture), l'ordre des dix classes gardé, chaque rapport entre deux
##   classes élevé à la même puissance ;
## - le catalogue du jeu (les dix classes réelles) et la table des cookies (`tools/torches.gd`) disent l'image de l'ancien
##   angle par la loi ;
## - le demi-angle CUIT dans chaque cookie livré est celui du jeu (mesuré dans l'image, `Torches.demi_angle_cuit`) ;
## - l'éblouissement lit ce même faisceau : dans le cône resserré, il verse ; à 3° hors de lui, rien — là où l'ancien
##   cône éclairait encore ;
## - la lumière 3D miroir couvre toujours le cône (`CONE_EN_PLUS_DEG`, plancher de 75°).
##
## Lancer : godot --headless --path . --script res://tools/test_faisceaux_concentres.gd

const Torches := preload("res://tools/torches.gd")
const LumieresIsoT := preload("res://lumieres_iso.gd")

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
	print("=== LES FAISCEAUX CONCENTRÉS (L1bis) ===")
	await process_frame
	_loi()
	_table()
	await _catalogue()
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


func _loi() -> void:
	print("\n--- La loi ---")
	_check("le plus étroit reste à 10° d'ouverture", is_equal_approx(WeaponData.ouverture_concentree(10.0), 10.0))
	_check("le plus large passe de 120° à 60°", is_equal_approx(WeaponData.ouverture_concentree(120.0), 60.0))
	var k := log(6.0) / log(12.0)
	var a := WeaponData.ouverture_concentree(40.0)
	var b := WeaponData.ouverture_concentree(70.0)
	_check("chaque rapport entre deux classes est élevé à la même puissance (k = %.3f)" % k,
		is_equal_approx(b / a, pow(70.0 / 40.0, k)))


func _table() -> void:
	print("\n--- La table des cookies ---")
	for t in Torches.ARMES:
		var attendu := WeaponData.ouverture_concentree(2.0 * float(t["angle_avant"])) * 0.5
		_check("%s : demi-angle %.2f° = image de %.2f° par la loi (%.3f°)" % [t["fichier"], t["angle"], t["angle_avant"], attendu],
			absf(float(t["angle"]) - attendu) < 0.01)
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/torche/cookie_%s.png" % t["fichier"]))
		img.convert(Image.FORMAT_RGBA8)
		var cuit := Torches.demi_angle_cuit(img, 0.01)
		_check("%s : le cookie livré est cuit à %.2f° (mesuré dans l'image)" % [t["fichier"], cuit],
			absf(cuit - float(t["angle"])) <= 0.6)


func _catalogue() -> void:
	print("\n--- Le catalogue du jeu ---")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var classes: Array = main._classes
	_check("dix classes", classes.size() == 10, str(classes.size()))
	var par_fichier := {}
	for t in Torches.ARMES:
		par_fichier[t["fichier"]] = t
	var ouvertures: Array[float] = []
	var avant: Array[float] = []
	for c: WeaponData in classes:
		var t: Dictionary = par_fichier.get(c.slug(), {})
		if t.is_empty():
			_check("%s : dans la table des cookies" % c.slug(), false)
			continue
		_check("%s : le jeu dit %.2f°, la table aussi" % [c.slug(), c.torch_angle_deg], is_equal_approx(c.torch_angle_deg, float(t["angle"])))
		ouvertures.append(c.torch_angle_deg * 2.0)
		avant.append(float(t["angle_avant"]) * 2.0)
		# L'éblouissement lit le même faisceau : dans le cône, il verse ; 3° hors du cône resserré, plus rien.
		var d := minf(c.portee_torche() * 0.5, 300.0)
		var dedans := c.lumiere_recue(Vector2.RIGHT, Vector2.ZERO, Vector2.RIGHT.rotated(deg_to_rad(c.torch_angle_deg * 0.5)) * d)
		var dehors := c.lumiere_recue(Vector2.RIGHT, Vector2.ZERO, Vector2.RIGHT.rotated(deg_to_rad(c.torch_angle_deg + 3.0)) * d)
		_check("%s : l'éblouissement verse dans le cône (%.3f), rien à 3° hors de lui (%.3f)" % [c.slug(), dedans, dehors],
			dedans > 0.0 and dehors < 0.005)
		var spot := clampf(maxf(c.torch_angle_deg + LumieresIsoT.CONE_EN_PLUS_DEG, LumieresIsoT.CONE_PLANCHER_DEG), 1.0, 89.0)
		_check("%s : la lumière 3D couvre le cône (%.1f° ≥ %.2f°)" % [c.slug(), spot, c.torch_angle_deg], spot >= c.torch_angle_deg)
	ouvertures.sort()
	avant.sort()
	_check("les ouvertures vont de %.1f° à %.1f°" % [ouvertures.front(), ouvertures.back()],
		is_equal_approx(ouvertures.front(), 10.0) and absf(ouvertures.back() - 60.0) < 0.02)
	var ordre := true
	for c1: WeaponData in classes:
		for c2: WeaponData in classes:
			var t1: Dictionary = par_fichier[c1.slug()]
			var t2: Dictionary = par_fichier[c2.slug()]
			if float(t1["angle_avant"]) < float(t2["angle_avant"]):
				ordre = ordre and c1.torch_angle_deg < c2.torch_angle_deg
	_check("l'ordre des dix classes est gardé", ordre)
	main.queue_free()
