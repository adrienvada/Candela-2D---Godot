## ISO13 — les pochoirs de l'illustration (`--pochoirs-essai`, éteints ; chantier d'ISO7 Beauté, 2026-09-25).
##
## Ce que la suite prouve, sans fenêtre :
## - **le drapeau** : éteint par défaut ; sans lui, aucune carte ne porte un pochoir de plus ;
## - **l'équité** : sur chaque carte livrée, chaque pochoir a son jumeau par la symétrie de la carte (miroir gauche-droite, ou
##   demi-tour pour la Croisée), « ZONE 1 » et « ZONE 2 » échangés, ou se tient sur l'axe — la symétrie elle-même est relue dans
##   le fichier de la carte, pas supposée ; et la garde rougit sur un pochoir décalé d'une demi-case ;
## - **la place** : chaque mot tient sur une plage de sol libre, à plus de trois cases de chaque départ ;
## - **la peinture** : noire à demi, elle n'assombrit que (jamais plus clair), et le noir reste noir.
##
## Ce qu'elle ne prouve pas : l'image. La planche (avec / sans, même instant, 0° et 45°) la mesure.
##
## Lancer : godot --headless --path . --script res://tools/test_pochoirs.gd
extends SceneTree

const PLANCHER := 12
const TUILE := 35.0

var _echecs := 0
var _verifications := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	_verifications += 1
	if ok:
		print("  ✓ %s" % label)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [label, ("  → " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== ISO13 — LES POCHOIRS DE L'ILLUSTRATION ===")
	await process_frame
	var cartes := _cartes()
	await _le_drapeau(cartes)
	_l_equite(cartes)
	_la_place(cartes)
	_la_peinture()
	_check("assez de vérifications (%d ≥ %d)" % [_verifications, PLANCHER], _verifications >= PLANCHER)
	print("%d vérifications, %d échec(s)" % [_verifications, _echecs])
	quit(1 if _echecs > 0 else 0)


func _cartes() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://assets/maps"):
		if f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/" + f))
			if d is Dictionary:
				out[String(d.get("id", f))] = d
	return out


func _le_drapeau(cartes: Dictionary) -> void:
	print("— le drapeau")
	_check("--pochoirs-essai n'est pas sur la ligne de commande de la suite", not ArenaDecor.pochoirs_actifs())
	var vides := true
	for id in cartes:
		var decor := (preload("res://arena_decor.gd") as GDScript).new() as Node2D
		decor.setup(cartes[id])
		vides = vides and (decor.get("_pochoirs") as Array).is_empty()
		decor.free()
	_check("drapeau éteint : aucun pochoir de plus, sur aucune carte (%d)" % cartes.size(), vides and cartes.size() >= 6)
	# La bascule des bancs (même instant, même partie) : pose puis retire les pochoirs de la carte.
	var cl := (preload("res://arena_decor.gd") as GDScript).new() as Node2D
	cl.setup(cartes["map_001"])
	await cl.poser_pochoirs(true)
	var poses := (cl.get("_pochoirs") as Array).size()
	await cl.poser_pochoirs(false)
	_check("poser_pochoirs pose la table de la carte (%d) puis la retire (%d)" % [poses, (cl.get("_pochoirs") as Array).size()],
		poses == (ArenaDecor.POCHOIRS_ESSAI["map_001"] as Array).size() and (cl.get("_pochoirs") as Array).is_empty())
	cl.free()
	_check("chaque carte livrée a sa table de pochoirs",
		cartes.keys().all(func(id): return ArenaDecor.POCHOIRS_ESSAI.has(id)))


## La symétrie d'une carte, relue dans son fichier : « miroir » (x → W−1−x), « demi_tour » (x, y → W−1−x, H−1−y), ou "".
## Les départs doivent s'échanger par elle.
func _symetrie(d: Dictionary) -> String:
	var g := MapCodec.get_grid_size(d)
	var murs := {}
	for c in MapCodec.get_wall_cells(d):
		murs[c] = true
	var s1 := MapCodec.get_spawn(d, 0)
	var s2 := MapCodec.get_spawn(d, 1)
	for nom in ["miroir", "demi_tour"]:
		var t := func(c: Vector2i) -> Vector2i:
			return Vector2i(g.x - 1 - c.x, c.y) if nom == "miroir" else Vector2i(g.x - 1 - c.x, g.y - 1 - c.y)
		if t.call(s1) != s2:
			continue
		var ok := true
		for c in murs:
			if not murs.has(t.call(c)):
				ok = false
				break
		if ok:
			return nom
	return ""


func _jumeau(texte: String) -> String:
	return "ZONE 2" if texte == "ZONE 1" else ("ZONE 1" if texte == "ZONE 2" else texte)


## Les pochoirs sans jumeau par la symétrie `sym` d'une grille `g`, pour une table donnée.
func _orphelins(table: Array, g: Vector2i, sym: String) -> Array:
	var orphelins := []
	for p in table:
		var c: Vector2 = p[1]
		var image := Vector2(g.x - 1 - c.x, c.y) if sym == "miroir" else Vector2(g.x - 1 - c.x, g.y - 1 - c.y)
		var angle := fmod(float(p[2]) + (0.0 if sym == "miroir" else 180.0), 360.0)
		var trouve := false
		for q in table:
			if String(q[0]) == _jumeau(String(p[0])) and Vector2(q[1]).is_equal_approx(image) \
					and is_equal_approx(fmod(float(q[2]), 360.0), angle):
				trouve = true
			# Sur l'axe : son propre jumeau (le même mot, au même endroit).
			if String(q[0]) == String(p[0]) and q == p and Vector2(q[1]).is_equal_approx(image) and sym == "miroir":
				trouve = true
		if not trouve:
			orphelins.append("%s %s" % [p[0], p[1]])
	return orphelins


func _l_equite(cartes: Dictionary) -> void:
	print("— l'équité : chaque pochoir a son jumeau par la symétrie de la carte")
	for id in cartes:
		var d: Dictionary = cartes[id]
		var sym := _symetrie(d)
		# L'Usine n'a pas de symétrie exacte (son bloc central est décalé d'une case) : ses pochoirs suivent le miroir.
		var sym_pochoirs := sym if sym != "" else "miroir"
		var orphelins := _orphelins(ArenaDecor.POCHOIRS_ESSAI.get(id, []), MapCodec.get_grid_size(d), sym_pochoirs)
		_check("%s (%s, symétrie %s) : chaque pochoir a son jumeau" % [String(d.get("name", id)), id, sym if sym != "" else "aucune exacte — miroir"],
			orphelins.is_empty(), str(orphelins))
	# La garde rougit : un « DEATHMATCH » du Cloître décalé d'une demi-case perd son jumeau.
	var faux: Array = (ArenaDecor.POCHOIRS_ESSAI["map_001"] as Array).duplicate(true)
	faux[0] = ["DEATHMATCH", Vector2(15, 5), 0.0]
	_check("la garde rougit sur un pochoir décalé d'une demi-case de l'axe",
		not _orphelins(faux, MapCodec.get_grid_size(cartes["map_001"]), "miroir").is_empty())


func _la_place(cartes: Dictionary) -> void:
	print("— la place : sur le sol libre, loin des départs")
	var fonte: Font = Charte.police_display(Charte.POIDS_ENSEIGNE)
	if fonte == null:
		fonte = ThemeDB.fallback_font
	for id in cartes:
		var d: Dictionary = cartes[id]
		var sol := {}
		for c in MapCodec.get_floor_cells(d):
			sol[c] = true
		for c in MapCodec.get_wall_cells(d):
			sol.erase(c)
		var departs := [MapCodec.get_spawn(d, 0), MapCodec.get_spawn(d, 1)]
		var fautes := []
		for p in ArenaDecor.POCHOIRS_ESSAI.get(id, []):
			var taille := fonte.get_string_size(String(p[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, ArenaDecor.POCHOIR_TAILLE_FONTE)
			var centre := (Vector2(p[1]) + Vector2(0.5, 0.5)) * TUILE
			var tourne := absf(sin(deg_to_rad(float(p[2])))) > 0.5
			var demi := Vector2(taille.y, taille.x) * 0.5 if tourne else taille * 0.5
			var a := Vector2i(((centre - demi) / TUILE).floor())
			var b := Vector2i(((centre + demi) / TUILE).floor())
			for x in range(a.x, b.x + 1):
				for y in range(a.y, b.y + 1):
					if not sol.has(Vector2i(x, y)):
						fautes.append("%s hors du sol en (%d, %d)" % [p[0], x, y])
					for s in departs:
						if maxi(absi(x - s.x), absi(y - s.y)) < 3:
							fautes.append("%s à moins de 3 cases du départ %s" % [p[0], s])
		_check("%s : chaque mot sur le sol libre, à trois cases au moins des départs" % String(d.get("name", id)), fautes.is_empty(),
			str(fautes.slice(0, 4)))


func _la_peinture() -> void:
	print("— la peinture : n'assombrit que")
	var c: Color = ArenaDecor.POCHOIR_PEINTURE
	_check("noire à demi (rgb 0, alpha %.2f) : sur le sol, un mélange normal ne peut qu'assombrir, et le noir reste noir" % c.a,
		c.r == 0.0 and c.g == 0.0 and c.b == 0.0 and c.a > 0.0 and c.a < 1.0)
	# Le coût : aucun shader de sol ni de mur ne connaît les pochoirs — ils vivent dans la texture du décor, déjà lue.
	var shaders_propres := true
	for chemin in ["res://sol_iso.gdshader", "res://sol_iso_eclaire.gdshader", "res://mur_iso.gdshader", "res://mur_iso_eclaire.gdshader"]:
		shaders_propres = shaders_propres and not FileAccess.get_file_as_string(chemin).to_lower().contains("pochoir")
	_check("aucun shader de sol ni de mur ne connaît les pochoirs : les textures lues par le sol ne changent pas", shaders_propres)
	var src := FileAccess.get_file_as_string("res://arena_decor.gd")
	_check("les pochoirs se dessinent avec le décor cuit, une fois par carte (aucun dessin par image de plus)",
		src.contains("	_dessiner_pochoirs_essai(sur)") and src.contains("func _dessiner_direct(sur: CanvasItem) -> void:"))
	_check("le drapeau ne pose rien sans lui : les pochoirs ne naissent que sous pochoirs_actifs()",
		src.contains("	if pochoirs_actifs():\n\t\t_lister_pochoirs()"))
