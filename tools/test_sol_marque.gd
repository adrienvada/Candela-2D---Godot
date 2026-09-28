## ISO14 — le sol marqué des illustrations (`--sol-marque-essai`, éteint ; essai de la session cloud « sol marqué »,
## 2026-09-28).
##
## Ce que la suite prouve, sans fenêtre :
## - **le drapeau** : éteint par défaut ; sans lui, aucune carte ne porte une marque de plus, et la bascule des bancs
##   (`poser_marques`) pose puis retire la table ;
## - **l'équité** : sur chaque carte livrée, chaque marque a son jumeau par la symétrie de la carte (relue dans son fichier,
##   pas supposée) — même famille, même paramètre, même graine, centre et angle transformés, motif retourné pour le miroir ;
##   ou, pour une famille symétrique par construction (cadre, bande, lettres), elle se tient sur l'axe. ET, hors cadres,
##   son jumeau par le DEMI-TOUR : à 45° B, J2 regarde depuis le côté opposé, il voit au demi-tour de ce que voit J1. La
##   garde rougit sur une marque décalée d'une demi-case, sur un jumeau qui a oublié de se retourner, et sur une table
##   fermée par le miroir seul ;
## - **la place** : chaque marque sur le sol libre, à 12 px au moins de tout mur (la face iso lit sa lumière 12 px devant
##   elle) et à trois cases au moins de chaque départ ;
## - **la peinture** : noire à demi, partout (jamais plus clair que le sol, noire dans le noir) ;
## - **la lisibilité** : aucune famille interdite (douilles, sang, flèches), aucun mot du jeu (« ZONE », « ARENA »,
##   « DEATHMATCH » : ce sont les pochoirs), aucun chiffre de départ seul (« 1 », « 2 ») ;
## - **le coût** : aucun shader ne connaît les marques, elles vivent dans le décor cuit.
##
## Ce qu'elle ne prouve pas : l'image, ni « rien ne change au bit » (headless ne rastérise rien). Ces deux-là se prouvent
## sous une vraie fenêtre : `tools/photo_sol_marque.gd` et `docs/iso/cloud/sol-marque/RAPPORT.md`.
##
## Lancer : godot --headless --path . --script res://tools/test_sol_marque.gd
extends SceneTree

const PLANCHER := 22
const TUILE := 35.0
## La place en travers de chaque famille : la demi-emprise locale (le long de l'angle, en travers), en pixels, que le dessin
## ne doit jamais dépasser. Écrite ici à la main, pas relue dans le décor : c'est la promesse, le dessin la tient.
const DEGAGEMENT_MUR := 12.0

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
	print("=== ISO14 — LE SOL MARQUÉ DES ILLUSTRATIONS ===")
	await process_frame
	var cartes := _cartes()
	await _le_drapeau(cartes)
	_l_equite(cartes)
	_la_place(cartes)
	_la_peinture()
	_la_lisibilite()
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
	_check("--sol-marque-essai n'est pas sur la ligne de commande de la suite", not ArenaDecor.sol_marque_actif())
	var vides := true
	for id in cartes:
		var decor := (preload("res://arena_decor.gd") as GDScript).new() as Node2D
		decor.setup(cartes[id])
		vides = vides and (decor.get("_marques") as Array).is_empty()
		decor.free()
	_check("drapeau éteint : aucune marque de plus, sur aucune carte (%d)" % cartes.size(), vides and cartes.size() >= 6)
	var cl := (preload("res://arena_decor.gd") as GDScript).new() as Node2D
	cl.setup(cartes["map_001"])
	await cl.poser_marques(true)
	var poses := (cl.get("_marques") as Array).size()
	await cl.poser_marques(false)
	_check("poser_marques pose la table de la carte (%d) puis la retire (%d)" % [poses, (cl.get("_marques") as Array).size()],
		poses == (ArenaDecor.SOL_MARQUE_ESSAI["map_001"] as Array).size() and (cl.get("_marques") as Array).is_empty())
	cl.free()
	_check("chaque carte livrée a sa table de marques",
		cartes.keys().all(func(id): return ArenaDecor.SOL_MARQUE_ESSAI.has(id)))


## La symétrie d'une carte, relue dans son fichier (la règle de `test_pochoirs.gd`).
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


func _angle_egal(a: float, b: float, periode: float) -> bool:
	var d := fposmod(a - b, periode)
	return d < 0.001 or d > periode - 0.001


## Les marques sans jumeau par la symétrie `sym` d'une grille `g`.
func _orphelins(table: Array, g: Vector2i, sym: String) -> Array:
	var orphelins := []
	for p in table:
		var c: Vector2 = p[1]
		var image := Vector2(g.x - 1 - c.x, c.y) if sym == "miroir" else Vector2(g.x - 1 - c.x, g.y - 1 - c.y)
		var angle := -float(p[2]) if sym == "miroir" else float(p[2]) + 180.0
		var symetrique := ArenaDecor.SOL_MARQUE_SYMETRIQUES.has(String(p[0]))
		# Le motif tiré au hasard se retourne par le miroir, pas par le demi-tour.
		var miroir_attendu: bool = (not bool(p[5])) if sym == "miroir" else bool(p[5])
		var trouve := false
		for q in table:
			if String(q[0]) != String(p[0]) or q[3] != p[3] or int(q[4]) != int(p[4]):
				continue
			if not Vector2(q[1]).is_equal_approx(image):
				continue
			if symetrique:
				# Symétrique par construction : l'angle à un demi-tour près (les lettres restent lisibles), pas de retournement.
				trouve = trouve or (_angle_egal(float(q[2]), angle, 180.0) and not bool(q[5]))
			else:
				trouve = trouve or (_angle_egal(float(q[2]), angle, 360.0) and bool(q[5]) == miroir_attendu)
		if not trouve:
			orphelins.append("%s %s" % [p[0], p[1]])
	return orphelins


func _l_equite(cartes: Dictionary) -> void:
	print("— l'équité : chaque marque a son jumeau par la symétrie de la carte")
	var total := 0
	for id in cartes:
		var d: Dictionary = cartes[id]
		var sym := _symetrie(d)
		# L'Usine n'a pas de symétrie exacte (son bloc central est décalé d'une case) : ses marques suivent le miroir.
		var sym_marques := sym if sym != "" else "miroir"
		var table: Array = ArenaDecor.SOL_MARQUE_ESSAI.get(id, [])
		total += table.size()
		var orphelins := _orphelins(table, MapCodec.get_grid_size(d), sym_marques)
		_check("%s (%s, symétrie %s) : %d marques, chacune a son jumeau" % [String(d.get("name", id)), id,
			sym if sym != "" else "aucune exacte — miroir", table.size()], orphelins.is_empty() and table.size() >= 12,
			str(orphelins))
		# À 45° B, J2 voit au DEMI-TOUR de ce que voit J1 : la table (hors cadres, qui suivent les pochoirs) doit aussi
		# être fermée par le demi-tour, même sur une carte en miroir.
		var hors_cadres := table.filter(func(p): return String(p[0]) != "cadre")
		var sans_demi_tour := _orphelins(hors_cadres, MapCodec.get_grid_size(d), "demi_tour")
		_check("%s : chaque marque (hors cadres) a aussi son jumeau par le demi-tour — ce que J2 voit à 45° B" \
			% String(d.get("name", id)), sans_demi_tour.is_empty(), str(sans_demi_tour.slice(0, 4)))
	print("  (%d marques en tout)" % total)
	var g := MapCodec.get_grid_size(cartes["map_001"])
	var faux: Array = (ArenaDecor.SOL_MARQUE_ESSAI["map_001"] as Array).duplicate(true)
	faux[0] = [faux[0][0], Vector2(faux[0][1]) + Vector2(0.5, 0.0), faux[0][2], faux[0][3], faux[0][4], faux[0][5]]
	_check("la garde rougit sur une marque décalée d'une demi-case", not _orphelins(faux, g, "miroir").is_empty())
	var oubli: Array = (ArenaDecor.SOL_MARQUE_ESSAI["map_001"] as Array).duplicate(true)
	for i in oubli.size():
		if bool(oubli[i][5]):
			oubli[i] = [oubli[i][0], oubli[i][1], oubli[i][2], oubli[i][3], oubli[i][4], false]
			break
	_check("la garde rougit sur un jumeau qui ne se retourne pas (le même tas, pas son image)",
		not _orphelins(oubli, g, "miroir").is_empty())
	# Une table fermée par le miroir seul (la première version de l'essai) : le demi-tour la rougit.
	var miroir_seul := (ArenaDecor.SOL_MARQUE_ESSAI["map_001"] as Array).filter(
		func(p): return String(p[0]) != "cadre" and Vector2(p[1]).y < 14.5)
	_check("la garde rougit sur une table fermée par le miroir seul (le jumeau de J2 caché derrière son pilier)",
		not _orphelins(miroir_seul, g, "demi_tour").is_empty())


## La demi-emprise locale d'une marque : (le long de son angle, en travers), en pixels.
func _demi_emprise(p: Array, fonte: Font) -> Vector2:
	match String(p[0]):
		"gravats":
			return Vector2(float(p[3]) * TUILE * 0.5 + 4.0, 5.0)
		"eclats":
			return Vector2.ONE * (float(p[3]) * TUILE * 0.5 + 3.0)
		"chaine":
			return Vector2(float(p[3]) * TUILE * 0.5 + 4.0, 9.0)
		"cadre":
			return Vector2(p[3]) * TUILE * 0.5 + Vector2(2.0, 2.0)
		"bande":
			return Vector2(float(p[3]) * TUILE * 0.5, 2.0)
		"lettres":
			var t := fonte.get_string_size(String(p[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, ArenaDecor.MARQUE_LETTRES_FONTE)
			return t * 0.5 + Vector2(1.0, 1.0)
	return Vector2.ZERO


func _la_place(cartes: Dictionary) -> void:
	print("— la place : sur le sol libre, à 12 px des murs, loin des départs")
	var fonte: Font = Charte.police_display(Charte.POIDS_ENSEIGNE)
	if fonte == null:
		fonte = ThemeDB.fallback_font
	for id in cartes:
		var d: Dictionary = cartes[id]
		var g := MapCodec.get_grid_size(d)
		var sol := {}
		for c in MapCodec.get_floor_cells(d):
			sol[c] = true
		for c in MapCodec.get_wall_cells(d):
			sol.erase(c)
		var departs := [MapCodec.get_spawn(d, 0), MapCodec.get_spawn(d, 1)]
		var fautes := []
		for p in ArenaDecor.SOL_MARQUE_ESSAI.get(id, []):
			var demi := _demi_emprise(p, fonte)
			var a := deg_to_rad(float(p[2]))
			var boite := Vector2(demi.x * absf(cos(a)) + demi.y * absf(sin(a)), demi.x * absf(sin(a)) + demi.y * absf(cos(a)))
			var centre := (Vector2(p[1]) + Vector2(0.5, 0.5)) * TUILE
			# Toute case qui touche la boîte élargie de 12 px doit être du sol libre.
			var a0 := Vector2i(((centre - boite - Vector2.ONE * DEGAGEMENT_MUR) / TUILE).floor())
			var b0 := Vector2i(((centre + boite + Vector2.ONE * DEGAGEMENT_MUR) / TUILE).ceil()) - Vector2i.ONE
			for x in range(a0.x, b0.x + 1):
				for y in range(a0.y, b0.y + 1):
					if not sol.has(Vector2i(x, y)):
						fautes.append("%s %s à moins de 12 px du non-sol (%d, %d)" % [p[0], p[1], x, y])
			var a1 := Vector2i(((centre - boite) / TUILE).floor())
			var b1 := Vector2i(((centre + boite) / TUILE).floor())
			for x in range(a1.x, b1.x + 1):
				for y in range(a1.y, b1.y + 1):
					for s in departs:
						if maxi(absi(x - s.x), absi(y - s.y)) < 3:
							fautes.append("%s %s à moins de 3 cases du départ %s" % [p[0], p[1], s])
		_check("%s : chaque marque sur le sol libre, à 12 px des murs et à trois cases des départs" % String(d.get("name", id)),
			fautes.is_empty(), str(fautes.slice(0, 4)))


func _la_peinture() -> void:
	print("— la peinture : n'assombrit que")
	var noires := true
	for c in [ArenaDecor.MARQUE_CHAINE, ArenaDecor.MARQUE_BANDE, ArenaDecor.MARQUE_LETTRES]:
		noires = noires and c.r == 0.0 and c.g == 0.0 and c.b == 0.0 and c.a > 0.0 and c.a < 1.0
	for v in [ArenaDecor.MARQUE_GRAVATS_ALPHA, ArenaDecor.MARQUE_ECLATS_ALPHA]:
		noires = noires and v.x > 0.0 and v.y < 1.0 and v.x <= v.y
	_check("toutes les peintures sont noires et translucides (rgb 0, 0 < alpha < 1) : sur le sol, elles ne peuvent qu'assombrir",
		noires)
	var src := FileAccess.get_file_as_string("res://arena_decor.gd")
	var debut := src.find("func _dessiner_sol_marque(")
	var fin := src.find("## Bandes de sécurité en chevrons")
	var corps := src.substr(debut, fin - debut) if debut >= 0 and fin > debut else ""
	# Aucune couleur écrite dans le dessin qui ne soit du noir : chaque `Color(` du dessin commence par trois zéros.
	var regex := RegEx.create_from_string("Color\\(([^,]+),\\s*([^,]+),\\s*([^,]+),")
	var claires := []
	for r in regex.search_all(corps):
		if r.get_string(1).strip_edges() != "0.0" or r.get_string(2).strip_edges() != "0.0" \
				or r.get_string(3).strip_edges() != "0.0":
			claires.append(r.get_string())
	_check("le dessin des marques n'écrit aucune couleur autre que le noir", corps != "" and claires.is_empty(), str(claires))
	var shaders_propres := true
	for chemin in ["res://sol_iso.gdshader", "res://sol_iso_eclaire.gdshader", "res://mur_iso.gdshader", "res://mur_iso_eclaire.gdshader"]:
		var t := FileAccess.get_file_as_string(chemin).to_lower()
		shaders_propres = shaders_propres and not t.contains("marque") and not t.contains("gravat")
	_check("aucun shader de sol ni de mur ne connaît les marques : elles vivent dans la texture du décor, déjà lue", shaders_propres)
	_check("les marques se dessinent avec le décor cuit, une fois par carte (aucun dessin par image de plus)",
		src.contains("	_dessiner_sol_marque(sur)\n\t_dessiner_pochoirs_essai(sur)") \
			and src.contains("func _dessiner_direct(sur: CanvasItem) -> void:"))
	_check("le drapeau ne pose rien sans lui : les marques ne naissent que sous sol_marque_actif()",
		src.contains("	if sol_marque_actif():\n\t\t_lister_marques()") and src.count("_lister_marques()") == 3)
	_check("les copies par vue partagent la table (sinon J2 dessinerait un sol nu)", src.contains("	copy._marques = _marques"))


func _la_lisibilite() -> void:
	print("— la lisibilité : rien qui se confonde avec une information du jeu")
	var familles := {}
	var textes := []
	for id in ArenaDecor.SOL_MARQUE_ESSAI:
		for p in ArenaDecor.SOL_MARQUE_ESSAI[id]:
			familles[String(p[0])] = true
			if String(p[0]) == "lettres":
				textes.append(String(p[3]))
	var permises := ["gravats", "eclats", "chaine", "cadre", "bande", "lettres"]
	_check("seulement les familles relevées (%s) — ni douilles, ni sang, ni flèches" % ", ".join(familles.keys()),
		familles.keys().all(func(f): return permises.has(f)))
	var interdits := []
	for t in textes:
		var u := String(t).to_upper()
		if u.contains("ZONE") or u.contains("ARENA") or u.contains("DEATHMATCH") or u == "1" or u == "2" \
				or u == "01" or u == "02" or u.contains("→") or u.contains(">") or u.contains("<"):
			interdits.append(t)
	_check("aucune lettre ne répète un mot du jeu ni un chiffre de départ, aucune flèche (%s)" % ", ".join(textes),
		interdits.is_empty(), str(interdits))
