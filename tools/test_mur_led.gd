## Test headless du bandeau LED des murs (prototype, `mur_led.gd`) : cuisson de
## la texture, repère monde, respiration, et pose dans une arène.
## Lancer : godot --headless --path . --script res://tools/test_mur_led.gd
extends SceneTree

const T := MurLed.TEXELS_PAR_CASE

var _failures: int = 0

func _init() -> void:
	print("=== Test MurLed ===")

	_test_bande_autour_d_un_mur()
	_test_continuite_carte_livree()
	_test_repere_monde()
	_test_respiration()
	_test_tempo_musique()
	_test_pose()

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
		printerr("  ✗ ", label, ("  → " + detail) if detail != "" else "")

## Grille 5×5 portant un seul mur, au centre.
func _grille_un_mur() -> Array:
	var murs: Array = []
	for ix in 5:
		var colonne: Array[bool] = []
		colonne.resize(5)
		for iy in 5:
			colonne[iy] = ix == 2 and iy == 2
		murs.append(colonne)
	return murs

func _carte_livree() -> Dictionary:
	var file := FileAccess.open("res://assets/maps/default.json", FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data

func _alpha(img: Image, cx: int, cy: int, u: int, v: int) -> float:
	return img.get_pixel(cx * T + u, cy * T + v).a

func _test_bande_autour_d_un_mur() -> void:
	print("\n— Bande autour d'un mur isolé")
	var img := MurLed.cuire(_grille_un_mur())
	_check("taille = cases × texels", img.get_size() == Vector2i(5 * T, 5 * T),
		str(img.get_size()))
	var milieu := T / 2
	var face_gauche := _alpha(img, 1, 2, T - 1, milieu)
	var face_droite := _alpha(img, 3, 2, 0, milieu)
	_check("forte contre la face du mur", face_gauche > 0.85, "%.3f" % face_gauche)
	_check("symétrique gauche/droite", absf(face_gauche - face_droite) < 0.001,
		"%.3f / %.3f" % [face_gauche, face_droite])
	_check("nulle à une case du mur", _alpha(img, 0, 2, T - 1, milieu) == 0.0)
	_check("nulle loin des murs", _alpha(img, 0, 0, milieu, milieu) == 0.0)
	_check("déborde sur le liseré", _alpha(img, 2, 2, 0, milieu) > 0.3,
		"%.3f" % _alpha(img, 2, 2, 0, milieu))
	_check("cœur du mur éteint", _alpha(img, 2, 2, milieu, milieu) == 0.0)
	var decroit := _alpha(img, 1, 2, T - 1, milieu) > _alpha(img, 1, 2, T / 2, milieu) \
		and _alpha(img, 1, 2, T / 2, milieu) > _alpha(img, 1, 2, 0, milieu)
	_check("décroît en s'éloignant du mur", decroit)

## Aucune couture aux bords de case, côté ouvert : la bande se raccorde d'un
## motif à l'autre. La pente maximale du profil (1 - d/PORTEE)² est 2/PORTEE par
## case, soit 2/(PORTEE × T) par texel ; une couture la dépasserait.
func _test_continuite_carte_livree() -> void:
	print("\n— Continuité sur la carte livrée")
	var data := _carte_livree()
	_check("carte livrée lue", not data.is_empty())
	if data.is_empty():
		return
	var murs := MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
	var debut := Time.get_ticks_msec()
	var img := MurLed.cuire(murs)
	print("    cuisson : %d ms pour %s px" % [Time.get_ticks_msec() - debut, img.get_size()])
	var pente_max := 2.0 / (MurLed.PORTEE * T) + 0.02
	var pire := 0.0
	var allumes := 0
	for x in img.get_width():
		for y in img.get_height():
			var ici_mur: bool = murs[x / T][y / T]
			var a := img.get_pixel(x, y).a
			if a > 0.0:
				allumes += 1
			if ici_mur:
				continue
			if x + 1 < img.get_width() and not murs[(x + 1) / T][y / T]:
				pire = maxf(pire, absf(img.get_pixel(x + 1, y).a - a))
			if y + 1 < img.get_height() and not murs[x / T][(y + 1) / T]:
				pire = maxf(pire, absf(img.get_pixel(x, y + 1).a - a))
	_check("des texels allumés", allumes > 0)
	_check("aucune couture côté ouvert", pire <= pente_max,
		"saut de %.3f pour %.3f permis" % [pire, pente_max])

func _test_repere_monde() -> void:
	print("\n— Repère monde")
	var tuile := Vector2(CandelaTileSet.TILE_SIZE)
	var zone := MurLed.rect_monde(_grille_un_mur(), tuile)
	_check("l'indice (0, 0) est la cellule (-1, -1)",
		zone.position == -tuile * MapGeometry.BORDER, str(zone.position))
	_check("couvre toute la grille", zone.size == tuile * 5, str(zone.size))

func _test_respiration() -> void:
	print("\n— Respiration")
	var p := MurLed.PERIODE
	_check("éteinte au départ de la manche", MurLed.energie(0.0) < 0.0001)
	_check("sommet à mi-période", absf(MurLed.energie(p * 0.5) - MurLed.PIC) < 0.0001)
	_check("périodique", absf(MurLed.energie(1.3) - MurLed.energie(1.3 + p)) < 0.0001)
	_check("le creux s'attarde", MurLed.energie(p * 0.25) < MurLed.PIC * 0.5)
	_check("lente (≥ 4 s)", p >= 4.0, "%.2f s" % p)

## La période est dérivée d'une copie du tempo : vérifier qu'elle suit l'original.
func _test_tempo_musique() -> void:
	print("\n— Tempo de la musique")
	var source := FileAccess.get_file_as_string("res://audio_manager.gd")
	var motif := RegEx.create_from_string("const BPM: float = ([0-9.]+)")
	var trouve := motif.search(source)
	_check("BPM lu dans audio_manager.gd", trouve != null)
	if trouve:
		_check("BPM_MUSIQUE = AudioManager.BPM",
			float(trouve.get_string(1)) == MurLed.BPM_MUSIQUE, trouve.get_string(1))

func _test_pose() -> void:
	print("\n— Pose dans une arène")
	var data := _carte_livree()
	if data.is_empty():
		return
	var arene := Node2D.new()
	var led := MurLed.poser(data, arene, Callable())
	_check("posée en build debug", led != null)
	if led == null:
		arene.free()
		return
	var murs := MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
	var zone := MurLed.rect_monde(murs, Vector2(CandelaTileSet.TILE_SIZE))
	_check("centrée sur la grille", led.position.is_equal_approx(zone.get_center()))
	var largeur := led.texture.get_width() * led.texture_scale
	_check("texture à l'échelle de la grille", is_equal_approx(largeur, zone.size.x),
		"%.1f / %.1f" % [largeur, zone.size.x])
	_check("sans drapeau : éteinte, pas seulement à zéro", not led.enabled)
	_check("aucune ombre", not led.shadow_enabled)
	_check("éclaire décor, adversaire et joueur local", led.range_item_cull_mask == 7)
	MurLed.poser(data, arene, Callable())
	var n := 0
	for enfant in arene.get_children():
		if enfant is MurLed:
			n += 1
	_check("un rematch remplace, n'empile pas", n == 1, "%d bandeaux" % n)
	arene.free()
