## Test headless du bandeau LED des murs (prototype, `mur_led.gd`) : profil et
## cuisson de la texture, faces tournées vers le vide, repère monde,
## respiration, pose dans une arène, et les shaders dont la bande dépend.
## Lancer : godot --headless --path . --script res://tools/test_mur_led.gd
extends SceneTree

var _failures: int = 0

func _init() -> void:
	print("=== Test MurLed ===")

	_test_profil()
	_test_bande_autour_d_un_mur()
	_test_faces_vers_le_vide()
	_test_exactitude()
	_test_repere_monde()
	_test_respiration()
	_test_tempo_musique()
	_test_couleur()
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

## Le sol d'une grille sans vide : tout ce qui n'est pas mur.
func _sol_sans_vide(murs: Array) -> Array:
	var out: Array = []
	for colonne in murs:
		var c: Array[bool] = []
		for v in colonne:
			c.append(not v)
		out.append(c)
	return out

func _carte(fichier: String) -> Dictionary:
	var file := FileAccess.open("res://assets/maps/" + fichier, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data

## Alpha au point (cx + u, cy + v) de la grille, u et v en fraction de case.
func _alpha(img: Image, t: int, cx: int, cy: int, u: float, v: float) -> float:
	return img.get_pixel(int((cx + u) * t), int((cy + v) * t)).a

func _test_profil() -> void:
	print("\n— Profil")
	_check("retenu contre la face", is_equal_approx(MurLed.profil(0.0), MurLed.FACE))
	_check("sommet au retrait", is_equal_approx(MurLed.profil(MurLed.RETRAIT), 1.0))
	_check("éteint à la portée", MurLed.profil(MurLed.PORTEE) == 0.0)
	_check("portée triplée (4,5 cases, 2026-09-11)", is_equal_approx(MurLed.PORTEE, 4.5))
	var decroit := true
	var d := MurLed.RETRAIT
	while d < MurLed.PORTEE:
		if MurLed.profil(d + 0.01) > MurLed.profil(d):
			decroit = false
		d += 0.01
	_check("décroît du retrait à la portée", decroit)

func _test_bande_autour_d_un_mur() -> void:
	print("\n— Bande autour d'un mur isolé")
	var murs := _grille(13, [Vector2i(6, 6)])
	var img := MurLed.cuire(murs, _sol_sans_vide(murs))
	var t := MurLed.texels_par_case(13, 13)
	_check("taille = cases × texels", img.get_size() == Vector2i(13 * t, 13 * t),
		str(img.get_size()))
	var gauche := _alpha(img, t, 5, 6, 0.9, 0.5)
	var droite := _alpha(img, t, 7, 6, 0.1, 0.5)
	_check("symétrique gauche/droite", absf(gauche - droite) < 0.02,
		"%.3f / %.3f" % [gauche, droite])
	_check("éclaire encore à trois cases du mur", _alpha(img, t, 2, 6, 0.9, 0.5) > 0.0)
	_check("nulle au-delà de la portée", _alpha(img, t, 0, 6, 0.1, 0.5) == 0.0)
	_check("nulle loin des murs", _alpha(img, t, 0, 0, 0.5, 0.5) == 0.0)
	var debord := _alpha(img, t, 6, 6, 0.0, 0.5)
	_check("déborde sur le liseré, retenu", debord > 0.0 and debord <= MurLed.FACE + 0.001,
		"%.3f" % debord)
	_check("cœur du mur éteint", _alpha(img, t, 6, 6, 0.5, 0.5) == 0.0)

## Demande d'Adrien (2026-09-11) : « le mur d'enceinte intérieur doit luire »,
## pas l'extérieur. La face de l'enceinte qui donne sur le vide hors carte reste
## noire ; celle qui donne sur l'arène respire, comme tout obstacle. Au sommet,
## avant ce correctif, la face extérieure montait à 119/255 en jeu contre 24
## pour l'intérieure : le vide comptait pour de l'ouvert.
func _test_faces_vers_le_vide() -> void:
	print("\n— Faces tournées vers le vide : éteintes")
	# Grille de 11 : vide au bord (anneau 0), enceinte (anneau 1), sol dedans,
	# un pilier en (5, 5) et une fosse en (7, 7).
	var n := 11
	var murs: Array = []
	var sol: Array = []
	for x in n:
		var cm: Array[bool] = []
		var cs: Array[bool] = []
		cm.resize(n)
		cs.resize(n)
		for y in n:
			var vide := x == 0 or y == 0 or x == n - 1 or y == n - 1 or Vector2i(x, y) == Vector2i(7, 7)
			var mur := not vide and (x == 1 or y == 1 or x == n - 2 or y == n - 2 or Vector2i(x, y) == Vector2i(5, 5))
			cm[y] = mur
			cs[y] = not vide and not mur
		murs.append(cm)
		sol.append(cs)
	var img := MurLed.cuire(murs, sol)
	var t := MurLed.texels_par_case(n, n)
	_check("vide contre la face extérieure : noir", _alpha(img, t, 0, 5, 0.9, 0.5) == 0.0,
		"%.3f" % _alpha(img, t, 0, 5, 0.9, 0.5))
	_check("face extérieure de l'enceinte : noire", _alpha(img, t, 1, 5, 0.0, 0.5) == 0.0,
		"%.3f" % _alpha(img, t, 1, 5, 0.0, 0.5))
	_check("face intérieure de l'enceinte : le liseré respire",
		_alpha(img, t, 1, 5, 0.99, 0.5) > 0.0, "%.3f" % _alpha(img, t, 1, 5, 0.99, 0.5))
	_check("sol au pied de l'enceinte : éclairé", _alpha(img, t, 2, 5, 0.2, 0.5) > 0.5,
		"%.3f" % _alpha(img, t, 2, 5, 0.2, 0.5))
	_check("pilier : éclairé", _alpha(img, t, 4, 5, 0.9, 0.5) > 0.5)
	_check("fosse intérieure : noire", _alpha(img, t, 7, 7, 0.5, 0.5) == 0.0)
	for fichier in ["default.json", "map_001_le_cloitre.json"]:
		var data := _carte(fichier)
		if data.is_empty():
			_check("%s lue" % fichier, false)
			continue
		var m := MapGeometry.build_grid(data, MapGeometry.Kind.WALLS)
		var s := MurLed.sol_de(MapGeometry.build_solid_grid(data))
		var carte := MurLed.cuire(m, s)
		var tc := carte.get_width() / m.size()
		var allume_hors_sol := 0
		var allume_sol := 0
		for x in carte.get_width():
			for y in carte.get_height():
				if carte.get_pixel(x, y).a == 0.0:
					continue
				var c := Vector2i(x / tc, y / tc)
				if s[c.x][c.y]:
					allume_sol += 1
				elif not m[c.x][c.y]:
					allume_hors_sol += 1
		_check("%s : du sol allumé" % fichier, allume_sol > 0)
		_check("%s : rien d'allumé dans le vide" % fichier, allume_hors_sol == 0,
			"%d texels" % allume_hors_sol)

## La texture doit valoir le profil de la distance au mur le plus proche,
## calculée ici en force brute sur TOUS les murs — ce qui attrape une transformée
## fausse comme un voisinage trop court. Loin de la face, l'écart doit être
## minime ; dans la rampe du retrait (quelques pixels), la pente est trop forte
## pour une tolérance fine, on y vérifie seulement l'encadrement.
func _test_exactitude() -> void:
	print("\n— Exactitude (force brute)")
	var murs_l := _grille(20, [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(2, 3), Vector2i(2, 4), Vector2i(12, 10), Vector2i(12, 11),
		Vector2i(6, 15), Vector2i(17, 4)])
	var fixtures := {"L et piliers": [murs_l, _sol_sans_vide(murs_l)]}
	var data := _carte("default.json")
	_check("carte livrée lue", not data.is_empty())
	if not data.is_empty():
		fixtures["carte livrée"] = [MapGeometry.build_grid(data, MapGeometry.Kind.WALLS),
			MurLed.sol_de(MapGeometry.build_solid_grid(data))]
	for nom in fixtures:
		var murs: Array = fixtures[nom][0]
		var sol: Array = fixtures[nom][1]
		var liste: Array[Vector2] = []
		for ix in murs.size():
			for iy in (murs[ix] as Array).size():
				if murs[ix][iy]:
					liste.append(Vector2(ix, iy))
		var debut := Time.get_ticks_msec()
		var img := MurLed.cuire(murs, sol)
		print("    %s : cuisson %d ms pour %s px" % [nom, Time.get_ticks_msec() - debut, img.get_size()])
		var t := img.get_width() / murs.size()
		var pas := 1 if murs.size() <= 20 else 3
		var pire_loin := 0.0
		var hors_cadre := 0
		for x in range(0, img.get_width(), pas):
			for y in range(0, img.get_height(), pas):
				if not sol[x / t][y / t]:
					continue
				var p := Vector2((x + 0.5) / t, (y + 0.5) / t)
				var d := INF
				for m in liste:
					d = minf(d, MurLed.distance_case(p - m, Vector2.ZERO))
				var a := img.get_pixel(x, y).a
				if d > MurLed.RETRAIT + 1.0 / t:
					pire_loin = maxf(pire_loin, absf(a - MurLed.profil(d)))
				elif a < MurLed.FACE - 0.05 or a > 1.0:
					hors_cadre += 1
		_check("%s : loin de la face, texture = profil(distance)" % nom, pire_loin < 0.03,
			"écart %.4f" % pire_loin)
		_check("%s : dans la rampe, entre FACE et 1" % nom, hors_cadre == 0,
			"%d texels hors cadre" % hors_cadre)

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
	_check("six mesures de la musique (≈ 8,5 s, 2026-09-11)",
		is_equal_approx(p, 24.0 * 60.0 / MurLed.BPM_MUSIQUE), "%.2f s" % p)

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

## La bande éclaire le monde : elle en prend la famille chaude (charte), jamais
## le froid réservé à l'appareil.
func _test_couleur() -> void:
	print("\n— Couleur")
	_check("une couleur de la charte : l'ambre", MurLed.COULEUR == Charte.AMBRE)
	_check("chaude : rouge au-dessus du bleu", MurLed.COULEUR.r > MurLed.COULEUR.b)

func _test_pose() -> void:
	print("\n— Pose dans une arène")
	var data := _carte("default.json")
	_check("carte par défaut lue", not data.is_empty())
	if data.is_empty():
		return
	var arene := Node2D.new()
	var led := MurLed.poser(data, arene, Callable())
	_check("posée en build debug, carte par défaut comprise (face intérieure de l'enceinte)",
		led != null)
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
	var texture := led.texture
	var debut := Time.get_ticks_msec()
	var led2 := MurLed.poser(data, arene, Callable())
	_check("même carte : texture reprise du cache, pas recuite",
		led2.texture == texture, "%d ms" % (Time.get_ticks_msec() - debut))
	var autre_murs := _grille(9, [Vector2i(4, 4)])
	var autre := MurLed.texture_pour(autre_murs, _sol_sans_vide(autre_murs))
	_check("autre carte : autre texture", autre != texture)
	var n := 0
	for enfant in arene.get_children():
		if enfant is MurLed:
			n += 1
	_check("un rematch remplace, n'empile pas", n == 1, "%d bandeaux" % n)
	arene.free()

## Garde du défaut vu par Adrien au premier essai : dosée par l'énergie, la bande
## allumait le liseré et l'adversaire d'un coup, parce que leurs shaders
## ignoraient `LIGHT_ENERGY`. L'énergie reste à 1 et la couleur porte la
## respiration — deux shaders l'ignorent encore (voir LIGHT_SANS_ENERGIE).
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
const LIGHT_SANS_ENERGIE := ["player_rim_light.gdshader", "blood_shader.gdshader"]

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
	# Le liseré se normalise sur la vision de proximité (décision d'Adrien,
	# 2026-09-11) : le halo du joueur doit souligner le mur voisin comme avant,
	# et c'est le chiffre de player.gd qui fait foi. Si l'énergie du halo change,
	# la référence doit suivre — sinon le halo perd ou gagne du mur en silence.
	var shimmer := FileAccess.get_file_as_string("res://shimmer_murs.gdshader")
	var ref := RegEx.create_from_string("const float ENERGIE_REFERENCE = ([0-9.]+);").search(shimmer)
	var halo := RegEx.create_from_string("ambient_light\\.energy = ([0-9.]+)").search(
		FileAccess.get_file_as_string("res://player.gd"))
	_check("ENERGIE_REFERENCE lue dans shimmer_murs", ref != null)
	_check("énergie du halo de proximité lue dans player.gd", halo != null)
	if ref and halo:
		_check("ENERGIE_REFERENCE = énergie du halo de proximité",
			float(ref.get_string(1)) == float(halo.get_string(1)),
			"%s / %s" % [ref.get_string(1), halo.get_string(1)])
