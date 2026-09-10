## Test headless du bandeau LED des murs (prototype, `mur_led.gd`) : profil et
## cuisson de la texture, repère monde, respiration, et pose dans une arène.
## Lancer : godot --headless --path . --script res://tools/test_mur_led.gd
extends SceneTree

const T := MurLed.TEXELS_PAR_CASE

var _failures: int = 0

func _init() -> void:
	print("=== Test MurLed ===")

	_test_profil()
	_test_bande_autour_d_un_mur()
	_test_exactitude()
	_test_repere_monde()
	_test_respiration()
	_test_tempo_musique()
	_test_pose()
	_test_intensite_par_la_couleur()
	_test_shaders_lisent_l_energie()

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

## Grille carrée de `n` cases, murs aux positions données.
func _grille(n: int, murs: Array[Vector2i]) -> Array:
	var out: Array = []
	for ix in n:
		var colonne: Array[bool] = []
		colonne.resize(n)
		for iy in n:
			colonne[iy] = Vector2i(ix, iy) in murs
		out.append(colonne)
	return out

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

func _test_profil() -> void:
	print("\n— Profil")
	_check("RAYON = ceil(PORTEE) : la cuisson voit tout mur qui compte",
		MurLed.RAYON == int(ceil(MurLed.PORTEE)))
	_check("retenu contre la face", is_equal_approx(MurLed.profil(0.0), MurLed.FACE))
	_check("sommet au retrait", is_equal_approx(MurLed.profil(MurLed.RETRAIT), 1.0))
	_check("éteint à la portée", MurLed.profil(MurLed.PORTEE) == 0.0)
	var decroit := true
	var d := MurLed.RETRAIT
	while d < MurLed.PORTEE:
		if MurLed.profil(d + 0.01) > MurLed.profil(d):
			decroit = false
		d += 0.01
	_check("décroît du retrait à la portée", decroit)

func _test_bande_autour_d_un_mur() -> void:
	print("\n— Bande autour d'un mur isolé")
	var img := MurLed.cuire(_grille(7, [Vector2i(3, 3)]))
	_check("taille = cases × texels", img.get_size() == Vector2i(7 * T, 7 * T),
		str(img.get_size()))
	var milieu := T / 2
	var gauche := _alpha(img, 2, 3, T - 2, milieu)
	var droite := _alpha(img, 4, 3, 1, milieu)
	_check("symétrique gauche/droite", absf(gauche - droite) < 0.01,
		"%.3f / %.3f" % [gauche, droite])
	_check("éclaire encore à une case du mur", _alpha(img, 2, 3, 0, milieu) > 0.0)
	_check("nulle au-delà de la portée", _alpha(img, 0, 3, 0, milieu) == 0.0)
	_check("nulle loin des murs", _alpha(img, 0, 0, milieu, milieu) == 0.0)
	var debord := _alpha(img, 3, 3, 0, milieu)
	_check("déborde sur le liseré, retenu", debord > 0.0 and debord <= MurLed.FACE + 0.001,
		"%.3f" % debord)
	_check("cœur du mur éteint", _alpha(img, 3, 3, milieu, milieu) == 0.0)

## La texture doit valoir le profil de la distance au mur le plus proche,
## texel par texel : ce contrôle attrape une couture entre deux motifs comme un
## voisinage trop court. Calculé ici en force brute, sur TOUS les murs.
func _test_exactitude() -> void:
	print("\n— Exactitude (force brute)")
	var fixtures := {
		"L et pilier": _grille(9, [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
			Vector2i(1, 2), Vector2i(1, 3), Vector2i(6, 5), Vector2i(6, 6), Vector2i(4, 7)]),
	}
	var data := _carte_livree()
	_check("carte livrée lue", not data.is_empty())
	if not data.is_empty():
		fixtures["carte livrée"] = MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
	for nom in fixtures:
		var murs: Array = fixtures[nom]
		var liste: Array[Vector2] = []
		for ix in murs.size():
			for iy in (murs[ix] as Array).size():
				if murs[ix][iy]:
					liste.append(Vector2(ix, iy))
		var debut := Time.get_ticks_msec()
		var img := MurLed.cuire(murs)
		print("    %s : cuisson %d ms pour %s px" % [nom, Time.get_ticks_msec() - debut, img.get_size()])
		# Un texel sur 5 sur la carte livrée : la force brute y coûterait sinon
		# plusieurs secondes.
		var pas := 1 if murs.size() < 20 else 5
		var pire := 0.0
		for x in range(0, img.get_width(), pas):
			for y in range(0, img.get_height(), pas):
				var case := Vector2i(x / T, y / T)
				if murs[case.x][case.y]:
					continue
				var p := Vector2((x + 0.5) / T, (y + 0.5) / T)
				var d := INF
				for m in liste:
					d = minf(d, MurLed.distance_case(p - m, Vector2.ZERO))
				# Tolérance : quantification 8 bits de l'alpha.
				pire = maxf(pire, absf(img.get_pixel(x, y).a - MurLed.profil(d)))
		_check("%s : texture = profil(distance)" % nom, pire < 0.01, "écart %.4f" % pire)

func _test_repere_monde() -> void:
	print("\n— Repère monde")
	var tuile := Vector2(CandelaTileSet.TILE_SIZE)
	var zone := MurLed.rect_monde(_grille(5, [Vector2i(2, 2)]), tuile)
	_check("l'indice (0, 0) est la cellule (-1, -1)",
		zone.position == -tuile * MapGeometry.BORDER, str(zone.position))
	_check("couvre toute la grille", zone.size == tuile * 5, str(zone.size))

func _test_respiration() -> void:
	print("\n— Respiration")
	var p := MurLed.PERIODE
	_check("au creux au départ de la manche", MurLed.souffle(0.0) < 0.0001)
	_check("sommet à mi-période", absf(MurLed.souffle(p * 0.5) - 1.0) < 0.0001)
	_check("périodique", absf(MurLed.souffle(1.3) - MurLed.souffle(1.3 + p)) < 0.0001)
	_check("le creux s'attarde", MurLed.souffle(p * 0.25) < 0.5)
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

## Garde du défaut vu par Adrien au premier essai : dosée par l'énergie, la bande
## allumait le liseré et l'adversaire d'un coup, parce que leurs shaders ignorent
## `LIGHT_ENERGY`. L'énergie doit rester à 1 et la couleur porter la respiration.
func _test_intensite_par_la_couleur() -> void:
	print("\n— L'intensité passe par la couleur")
	var led := MurLed.new()
	led.regler(1.0)
	var sommet := led.color
	_check("énergie fixe au sommet", led.energy == 1.0)
	led.regler(0.5)
	_check("énergie fixe à mi-souffle", led.energy == 1.0)
	_check("couleur divisée par deux à mi-souffle",
		is_equal_approx(led.color.r, sommet.r * 0.5) and is_equal_approx(led.color.b, sommet.b * 0.5),
		"%s / %s" % [led.color, sommet])
	_check("alpha de la couleur intact (sinon l'atténuation serait au carré)",
		led.color.a == 1.0)
	_check("allumée à mi-souffle", led.enabled)
	led.regler(0.0)
	_check("éteinte au creux, pas laissée à zéro", not led.enabled)
	led.free()

## Shaders dont le `light()` n'applique pas encore `LIGHT_ENERGY`, connus et
## signalés (ROADMAP, Pièges connus, *Deux shaders ignorent LIGHT_ENERGY*) :
## hors du correctif décidé par Adrien le 2026-09-10, qui ne portait que sur le
## liseré des murs et le corps adverse. En retirer un quand il est corrigé ; en
## AJOUTER un demande de dire pourquoi.
const LIGHT_SANS_ENERGIE := ["player_rim_light.gdshader", "blood_shader.gdshader",
	"player_enemy_light.gdshader"]

## Garde du correctif décidé par Adrien le 2026-09-10 : un `light()` propre qui
## lit `LIGHT_COLOR` doit appliquer `LIGHT_ENERGY`. Les masques de lumière du
## jeu sont blancs, la forme est dans l'alpha : l'intensité n'existe QUE dans
## l'énergie. Sans elle, toute lampe dont on anime l'énergie (fondu, panne,
## souffle, multiplicateur de classe) s'allume ou s'éteint d'un bloc.
func _test_shaders_lisent_l_energie() -> void:
	print("\n— Les shaders à light() propre lisent l'énergie")
	var corps := RegEx.create_from_string("void light\\(\\)[\\s\\S]*")
	var dossier := DirAccess.open("res://")
	for fichier in dossier.get_files():
		if not fichier.ends_with(".gdshader"):
			continue
		var source := FileAccess.get_file_as_string("res://" + fichier)
		var trouve := corps.search(source)
		if trouve == null:
			continue
		var lit_energie := trouve.get_string().contains("LIGHT_ENERGY")
		if fichier in LIGHT_SANS_ENERGIE:
			_check("%s : exception connue, toujours sans énergie" % fichier, not lit_energie,
				"corrigé ? le retirer de LIGHT_SANS_ENERGIE")
		else:
			_check("%s : light() applique LIGHT_ENERGY" % fichier, lit_energie)
	# Le liseré se normalise sur la torche nominale : elle doit garder l'aspect
	# validé, et c'est le chiffre de player.gd qui fait foi.
	var shimmer := FileAccess.get_file_as_string("res://shimmer_murs.gdshader")
	var ref := RegEx.create_from_string("const float ENERGIE_REFERENCE = ([0-9.]+);").search(shimmer)
	var torche := RegEx.create_from_string("flashlight\\.energy = ([0-9.]+)").search(
		FileAccess.get_file_as_string("res://player.gd"))
	_check("ENERGIE_REFERENCE lue dans shimmer_murs", ref != null)
	_check("énergie nominale de la torche lue dans player.gd", torche != null)
	if ref and torche:
		_check("ENERGIE_REFERENCE = énergie nominale de la torche",
			float(ref.get_string(1)) == float(torche.get_string(1)),
			"%s / %s" % [ref.get_string(1), torche.get_string(1)])
