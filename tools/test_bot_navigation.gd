## Garde du déplacement du bot — chantier SOLO, étape S1.
##
## Ce que la suite vérifie, **sans monter le jeu** (`--script`, aucune scène, aucune physique) :
##
##   • sur CHAQUE carte livrée de `assets/maps/` : les cases que le bot juge libres sont exactement celles
##     que la collision laisse libres (le sol, moins les murs, moins les murs bas — dérivées ICI des listes de
##     cases de la carte, pas de `MapGeometry`, pour qu'une dérive de l'un ou de l'autre se voie) ;
##   • des chemins entre cases praticables tirées au hasard ne traversent JAMAIS une case solide ni un mur bas,
##     ne rasent aucun coin (une diagonale exige ses deux cases orthogonales libres) et ne passent par aucune
##     case étranglée (un couloir d'une tuile, plus étroit que le corps de 36 px du joueur) ;
##   • sur une carte fabriquée, les cas qu'aucune carte livrée ne pose : deux moitiés séparées par un mur, un
##     mur bas à contourner, un couloir d'une tuile ;
##   • RONDE cycle dans l'ordre ; ZONE ne sort jamais de son rectangle — cibles, chemins et positions simulées ;
##     LIBRE ne vise que des cases qu'on peut rejoindre ; même graine = même suite de cibles ;
##   • le bot ne commande que de la marche : jamais tir, fusée, gadget, recharge, accroupi, enjambement ; sa
##     torche suit son profil et vaut « éteinte » par défaut ;
##   • l'anti-blocage : un corps qui ne bouge pas malgré la commande fait replanifier, puis changer de cible.
##
## Le corps simulé est un POINT MATÉRIEL qui avance de `commande × vitesse × delta` : c'est ce qui permet de
## prouver les chemins et les consignes sans moteur physique. Ce que fait le vrai corps (36 px, un nez de
## 28 px, des murs qui glissent) est l'affaire de `test_entrainement_bot`, en scène.
##
## Lancer : godot --headless --path . --script res://tools/test_bot_navigation.gd
extends SceneTree

const Nav := preload("res://navigation_bot.gd")
const Codec := preload("res://map_codec.gd")
const Profil := preload("res://profil_bot.gd")
const Bot := preload("res://bot_input_provider.gd")

const PAS := 1.0 / 60.0
const VITESSE := 260.0
const TUILE := 35.0

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
	print("=== LE BOT SE DÉPLACE (S1) ===")
	var cartes := _cartes_livrees()
	_check("le catalogue livre plusieurs cartes", cartes.size() >= 5, str(cartes.size()))
	for nom: String in cartes:
		_sur_une_carte(nom, cartes[nom])
	_sur_une_carte_fabriquee()
	_ronde()
	_zone()
	_libre()
	_immobile_et_commandes()
	_anti_blocage()
	_profil()
	print("\n%d vérifications" % _verifications)
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# Les cartes
# ---------------------------------------------------------------------------

func _cartes_livrees() -> Dictionary:
	var sortie := {}
	var dossier := DirAccess.open("res://assets/maps")
	if dossier == null:
		return sortie
	var fichiers := Array(dossier.get_files())
	fichiers.sort()
	for f: String in fichiers:
		if not f.ends_with(".json"):
			continue
		var fichier := FileAccess.open("res://assets/maps/" + f, FileAccess.READ)
		var json := JSON.new()
		if json.parse(fichier.get_as_text()) != OK:
			continue
		var r: Dictionary = Codec.validate(json.data as Dictionary)
		if r["ok"]:
			sortie[f] = r["data"]
	return sortie


## Un solide, dérivé des listes de cases de la carte — SANS passer par `MapGeometry` ni par le bot. Une case est
## libre quand elle porte du sol et ni mur ni mur bas ; tout le reste, hors grille compris, est solide.
class Verite:
	var sol := {}
	var mur := {}
	var bas := {}
	var taille := Vector2i.ZERO

	func _init(data: Dictionary) -> void:
		var codec := preload("res://map_codec.gd")
		taille = codec.get_grid_size(data)
		for c in codec.get_floor_cells(data):
			sol[c] = true
		for c in codec.get_wall_cells(data):
			mur[c] = true
		for c in codec.get_low_wall_cells(data):
			bas[c] = true

	func libre(c: Vector2i) -> bool:
		return sol.has(c) and not mur.has(c) and not bas.has(c) \
			and c.x >= 0 and c.y >= 0 and c.x < taille.x and c.y < taille.y

	func etranglee(c: Vector2i) -> bool:
		return (not libre(c + Vector2i.LEFT) and not libre(c + Vector2i.RIGHT)) \
			or (not libre(c + Vector2i.UP) and not libre(c + Vector2i.DOWN))


func _sur_une_carte(nom: String, data: Dictionary) -> void:
	print("\n--- %s ---" % nom)
	var v := Verite.new(data)
	var nav := Nav.depuis_carte(data)

	# (a) Mêmes cases libres que la collision.
	var desaccords := 0
	var premier := ""
	var bas_vus := 0
	for cy in v.taille.y:
		for cx in v.taille.x:
			var c := Vector2i(cx, cy)
			if v.bas.has(c):
				bas_vus += 1
			if nav.est_libre(c) != v.libre(c):
				desaccords += 1
				if premier == "":
					premier = str(c)
			if nav.est_praticable(c) != (v.libre(c) and not v.etranglee(c)):
				desaccords += 1
				if premier == "":
					premier = str(c)
	_check("les cases libres et praticables sont celles de la carte (sol − murs − murs bas)",
		desaccords == 0, "%d désaccords, la première en %s" % [desaccords, premier])
	_check("hors grille, rien n'est libre",
		not nav.est_libre(Vector2i(-1, 0)) and not nav.est_libre(v.taille) and not nav.est_praticable(Vector2i(-5, -5)))
	var s1 := Codec.get_spawn(data, 0)
	var s2 := Codec.get_spawn(data, 1)
	_check("les deux apparitions sont praticables", nav.est_praticable(s1) and nav.est_praticable(s2))
	_check("une route relie les deux apparitions", not nav.chemin(s1, s2).is_empty())

	# (b) Des chemins tirés au hasard, vérifiés contre la vérité de la carte.
	_chemins_au_hasard(nom, v, nav, 20261002)

	# (c) Les extrémités non praticables ne donnent aucun chemin.
	var solide := Vector2i(-1, -1)
	for cy in v.taille.y:
		for cx in v.taille.x:
			if not v.libre(Vector2i(cx, cy)):
				solide = Vector2i(cx, cy)
	_check("un chemin vers une case solide est vide", nav.chemin(s1, solide).is_empty())

	# (d) Aucune carte livrée ne porte de mur bas (vérifié au `grep`, 2026-10-02) : la garde « jamais un mur bas »
	# serait vide sur elles. On pose donc des murs bas ÉPARS sur la carte livrée — une case de sol sur neuf, hors
	# apparitions — et on rejoue la même vérification : les chemins doivent les contourner.
	var variante := data.duplicate(true)
	var semes: Array[Vector2i] = []
	for c in Codec.get_floor_cells(data):
		if not v.mur.has(c) and c != s1 and c != s2 and (c.x * 7 + c.y * 13) % 9 == 0:
			semes.append(c)
	variante["low_walls"] = Codec.encode_runs(semes)
	var vv := Verite.new(variante)
	var nav_v := Nav.depuis_carte(variante)
	_check("« %s » + %d murs bas semés : le bot les juge solides" % [nom, semes.size()],
		semes.size() >= 10 and nav_v.est_libre(semes[0]) == false and nav.est_libre(semes[0]) == true, str(semes.size()))
	_chemins_au_hasard(nom + " + murs bas", vv, nav_v, 31337)


## Tire 160 paires de cases praticables, trace leur chemin, et vérifie chacun contre la vérité de la carte.
func _chemins_au_hasard(nom: String, v: Verite, nav: Nav, graine: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var cases := nav.cases_praticables()
	var essais := 0
	var chemins_ok := 0
	var sans_chemin := 0
	var pire := ""
	var diag_total := 0
	var pas_total := 0
	var bas_traverses := 0
	for _i in 160:
		var a: Vector2i = cases[rng.randi_range(0, cases.size() - 1)]
		var b: Vector2i = cases[rng.randi_range(0, cases.size() - 1)]
		var ch := nav.chemin(a, b)
		essais += 1
		# Les semis de murs bas peuvent isoler une case : sans chemin n'est un défaut que si la composante les unit.
		if ch.is_empty() and not nav.cases_atteignables(a).has(b):
			sans_chemin += 1
			chemins_ok += 1
			continue
		var defaut := _defaut_du_chemin(v, a, b, ch)
		if defaut == "":
			chemins_ok += 1
			for k in range(1, ch.size()):
				pas_total += 1
				if ch[k].x != ch[k - 1].x and ch[k].y != ch[k - 1].y:
					diag_total += 1
		elif pire == "":
			pire = "%s → %s : %s" % [a, b, defaut]
		for c in ch:
			if v.bas.has(c):
				bas_traverses += 1
	_check("« %s » : %d chemins au hasard, aucun ne traverse un solide, un mur bas, un coin ni un couloir trop étroit" % [nom, essais],
		chemins_ok == essais and bas_traverses == 0, pire)
	_check("« %s » : les diagonales sont employées (la garde de coin n'est pas gagnée par leur absence)" % nom,
		diag_total > 0, "%d diagonales sur %d pas" % [diag_total, pas_total])
	# Garde de non-vacuité : sans elle, un graphe qui ne relierait rien passerait toutes les vérifications ci-dessus.
	# La moitié, pas « presque toutes » : des murs bas semés étranglent des couloirs et coupent parfois une carte.
	_check("« %s » : au moins la moitié des paires sont reliées (%d sans chemin sur %d)" % [nom, sans_chemin, essais],
		sans_chemin * 2 <= essais)


## Ce qui ne va pas dans un chemin, ou « » s'il est sain.
func _defaut_du_chemin(v: Verite, a: Vector2i, b: Vector2i, ch: Array[Vector2i]) -> String:
	if ch.is_empty():
		# Les cartes livrées n'ont qu'une composante : « aucun chemin » entre deux cases praticables est un défaut.
		return "aucun chemin"
	if ch[0] != a or ch[ch.size() - 1] != b:
		return "mauvaises extrémités %s … %s" % [ch[0], ch[ch.size() - 1]]
	for k in ch.size():
		var c := ch[k]
		if v.mur.has(c):
			return "traverse un mur en %s" % c
		if v.bas.has(c):
			return "traverse un mur bas en %s" % c
		if not v.libre(c):
			return "traverse une case solide en %s" % c
		if v.etranglee(c):
			return "traverse une case étranglée en %s" % c
		if k > 0:
			var d := c - ch[k - 1]
			if maxi(absi(d.x), absi(d.y)) != 1:
				return "saute de %s à %s" % [ch[k - 1], c]
			if d.x != 0 and d.y != 0:
				# Une diagonale ne rase un coin que si l'une de ses deux cases orthogonales est solide.
				if not v.libre(ch[k - 1] + Vector2i(d.x, 0)) or not v.libre(ch[k - 1] + Vector2i(0, d.y)):
					return "rase un coin entre %s et %s" % [ch[k - 1], c]
	return ""


## Une carte fabriquée : 14 × 10, deux salles de sol séparées par une cloison pleine, plus un couloir d'une tuile,
## un mur bas à contourner et un îlot fermé.
func _carte_fabriquee() -> Dictionary:
	var d := Codec.new_map("fabriquee", Vector2i(16, 12))
	var sol: Array[Vector2i] = []
	var murs: Array[Vector2i] = []
	var bas: Array[Vector2i] = []
	for y in 12:
		for x in 16:
			sol.append(Vector2i(x, y))
	# La cloison pleine x = 5, de haut en bas, sauf le couloir d'une tuile en y = 3 (donc libre, entre deux murs).
	for y in 12:
		if y != 3:
			murs.append(Vector2i(5, y))
	# Une paroi pleine x = 12 sur toute la hauteur, qui ISOLE la salle de droite : aucune porte.
	for y in 12:
		murs.append(Vector2i(12, y))
	# Dans la salle du milieu, un mur bas en x = 8, sauf une brèche de DEUX cases (y = 8 et 9) : une brèche d'une seule
	# serait un couloir d'une tuile, que le corps ne passe pas.
	for y in range(0, 12):
		if y != 8 and y != 9:
			bas.append(Vector2i(8, y))
	d["floor"] = Codec.encode_runs(sol)
	d["walls"] = Codec.encode_runs(murs)
	d["low_walls"] = Codec.encode_runs(bas)
	return d


func _sur_une_carte_fabriquee() -> void:
	print("\n--- Une carte fabriquée : cloisons, couloir, mur bas ---")
	var data := _carte_fabriquee()
	var v := Verite.new(data)
	var nav := Nav.depuis_carte(data)
	_check("la case du couloir d'une tuile est libre mais étranglée",
		nav.est_libre(Vector2i(5, 3)) and not nav.est_praticable(Vector2i(5, 3)))
	_check("la salle de gauche est coupée de celle du milieu : le couloir d'une tuile ne laisse pas passer un corps de 36 px",
		nav.chemin(Vector2i(2, 5), Vector2i(7, 5)).is_empty())
	_check("la salle de droite est isolée par une paroi pleine",
		nav.chemin(Vector2i(7, 5), Vector2i(14, 5)).is_empty())
	_check("deux cases coupées l'une de l'autre n'ont pas la même composante",
		not nav.cases_atteignables(Vector2i(2, 5)).has(Vector2i(7, 5)))
	var haut := nav.chemin(Vector2i(6, 1), Vector2i(9, 1))
	_check("le mur bas oblige à passer par sa brèche de deux cases, et le chemin existe", not haut.is_empty())
	var breche_d_une_case := _carte_fabriquee()
	var bas_une: Array[Vector2i] = []
	for y in 12:
		if y != 8:
			bas_une.append(Vector2i(8, y))
	breche_d_une_case["low_walls"] = Codec.encode_runs(bas_une)
	_check("… alors qu'une brèche d'UNE case dans le mur bas ne laisse pas passer le corps : plus de chemin",
		Nav.depuis_carte(breche_d_une_case).chemin(Vector2i(6, 1), Vector2i(9, 1)).is_empty())
	var bas_traverse := false
	var passe_par_la_breche := false
	for c in haut:
		if v.bas.has(c):
			bas_traverse = true
		if c.x == 8 and (c.y == 8 or c.y == 9):
			passe_par_la_breche = true
	_check("… sans jamais poser le pied sur le mur bas", not bas_traverse)
	_check("… en passant par la brèche (8, 8) ou (8, 9)", passe_par_la_breche)
	_check("un chemin sans mur bas serait court : celui-ci fait un détour de plus de 10 cases",
		haut.size() > 10, str(haut.size()))
	# Le sol de chaque case de ce chemin est sain.
	_check("ce chemin passe le contrôle des cases", _defaut_du_chemin(v, Vector2i(6, 1), Vector2i(9, 1), haut) == "")

	# La zone enferme les chemins : de (6,1) à (9,1) restreint au haut de la salle, la brèche est hors zone.
	var enferme := nav.chemin(Vector2i(6, 1), Vector2i(9, 1), Rect2i(6, 0, 4, 6))
	_check("une zone qui ne contient pas la brèche coupe le chemin", enferme.is_empty())
	var libre_dans := nav.chemin(Vector2i(6, 1), Vector2i(7, 6), Rect2i(6, 0, 2, 12))
	var tout_dedans := not libre_dans.is_empty()
	for c in libre_dans:
		if not Rect2i(6, 0, 2, 12).has_point(c):
			tout_dedans = false
	_check("un chemin enfermé dans une zone reste dans la zone", tout_dedans, str(libre_dans))

	var proche := nav.case_praticable_proche(Vector2i(5, 3))
	_check("la case praticable la plus proche d'une case étranglée est voisine et praticable",
		nav.est_praticable(proche) and maxi(absi(proche.x - 5), absi(proche.y - 3)) <= 2, str(proche))
	_check("les centres de case et leur retour au monde coïncident",
		Nav.case_du_monde(Nav.centre_de_la_case(Vector2i(7, 4))) == Vector2i(7, 4)
		and Nav.centre_de_la_case(Vector2i(0, 0)).is_equal_approx(Vector2(TUILE, TUILE) * 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var loin := nav.case_loin_de(Nav.centre_de_la_case(Vector2i(6, 1)), Vector2i(6, 1), rng, 0.1)
	_check("une case « loin » de (6, 1) est dans la même composante et nettement éloignée",
		nav.cases_atteignables(Vector2i(6, 1)).has(loin) and Vector2(loin - Vector2i(6, 1)).length() >= 6.0, str(loin))


# ---------------------------------------------------------------------------
# Les comportements
# ---------------------------------------------------------------------------

func _bot(profil: Profil, nav: Nav, graine: int) -> Bot:
	var b := Bot.new()
	b.configurer(profil, nav, graine)
	return b


## Fait avancer un point matériel de `secondes`, en rappelant `a_chaque_pas(position)` après chaque image.
func _simuler(b: Bot, depart: Vector2, secondes: float, a_chaque_pas: Callable) -> Vector2:
	var pos := depart
	for _i in int(round(secondes / PAS)):
		b.avancer(PAS, pos, VITESSE)
		pos += b.get_movement_vector() * VITESSE * PAS
		a_chaque_pas.call(pos)
	return pos


func _carte_de_reference() -> Dictionary:
	return _cartes_livrees()["default.json"]


func _ronde() -> void:
	print("\n--- RONDE : les points dans l'ordre, en boucle ---")
	var data := _carte_de_reference()
	var nav := Nav.depuis_carte(data)
	var p := Profil.new()
	p.deplacement = Profil.Deplacement.RONDE
	var points: Array[Vector2i] = [Vector2i(5, 5), Vector2i(20, 5), Vector2i(20, 20), Vector2i(5, 20)]
	p.points_ronde = points
	var b := _bot(p, nav, 1)
	var suite: Array[Vector2i] = []
	for _i in 9:
		suite.append(b.prochaine_cible(Vector2i(12, 12)))
	var attendu: Array[Vector2i] = []
	for i in 9:
		attendu.append(points[i % points.size()])
	_check("les cibles se suivent dans l'ordre des points, en boucle", suite == attendu, str(suite))

	# Et le bot les visite vraiment dans cet ordre : on note la cible à chaque changement.
	var b2 := _bot(p, nav, 1)
	var vus: Array[Vector2i] = []
	var dans_un_mur := [false]
	var v := Verite.new(data)
	_simuler(b2, Nav.centre_de_la_case(points[0]), 90.0, func(pos: Vector2) -> void:
		var c := b2.cible_courante()
		if c.x >= 0 and (vus.is_empty() or vus[vus.size() - 1] != c):
			vus.append(c)
		if not v.libre(Nav.case_du_monde(pos)):
			dans_un_mur[0] = true)
	var cycles_complets := vus.size() >= 8
	var ordre_ok := cycles_complets
	for i in vus.size():
		if vus[i] != points[(i + 1) % points.size()]:
			ordre_ok = false
	_check("en 90 s simulées le bot parcourt deux fois la ronde, dans l'ordre (%d visites)" % vus.size(),
		ordre_ok, str(vus))
	_check("… sans jamais entrer dans une case solide", not dans_un_mur[0])

	# Une ronde dont un point est un mur : le point est sauté, le bot ne se fige pas.
	var p2 := Profil.new()
	p2.deplacement = Profil.Deplacement.RONDE
	var mur := _premiere_case_solide(v)
	var avec_mur: Array[Vector2i] = [Vector2i(5, 5), mur, Vector2i(20, 5)]
	p2.points_ronde = avec_mur
	var b3 := _bot(p2, nav, 1)
	var vues: Array[Vector2i] = []
	for _i in 6:
		vues.append(b3.prochaine_cible(Vector2i(12, 12)))
	_check("un point de ronde sur un mur est sauté", not vues.has(mur) and vues.has(Vector2i(5, 5))
		and vues.has(Vector2i(20, 5)), str(vues))
	# Aucun point : pas de cible, pas d'erreur.
	var p3 := Profil.new()
	p3.deplacement = Profil.Deplacement.RONDE
	_check("une ronde sans point n'a pas de cible", _bot(p3, nav, 1).prochaine_cible(Vector2i(12, 12)).x < 0)


func _premiere_case_solide(v: Verite) -> Vector2i:
	for cy in v.taille.y:
		for cx in v.taille.x:
			if not v.libre(Vector2i(cx, cy)):
				return Vector2i(cx, cy)
	return Vector2i(-1, -1)


func _zone() -> void:
	print("\n--- ZONE : le rectangle, et rien d'autre ---")
	var data: Dictionary = _cartes_livrees()["map_001_le_cloitre.json"]
	var nav := Nav.depuis_carte(data)
	var v := Verite.new(data)
	# Un rectangle au milieu de la carte, assez grand pour contenir des cases libres.
	var zone := Rect2i(8, 8, 9, 7)
	var libres_dans := nav.cases_dans(zone)
	_check("la zone d'essai contient des cases praticables (%d)" % libres_dans.size(), libres_dans.size() >= 10)
	var p := Profil.new()
	p.deplacement = Profil.Deplacement.ZONE
	p.zone = zone
	var b := _bot(p, nav, 3)
	var hors := 0
	var impraticables := 0
	var distinctes := {}
	for _i in 300:
		var c := b.prochaine_cible(libres_dans[0])
		distinctes[c] = true
		if not zone.has_point(c):
			hors += 1
		if not nav.est_praticable(c):
			impraticables += 1
	_check("300 cibles tirées : aucune hors du rectangle", hors == 0, "%d hors zone" % hors)
	_check("… et toutes praticables", impraticables == 0)
	_check("… et variées (%d cases distinctes)" % distinctes.size(), distinctes.size() >= 10)

	# Le bot marche, et ni lui ni ses chemins n'en sortent — même départ hors zone : il y entre, puis y reste.
	var b2 := _bot(p, nav, 5)
	var pixels := Rect2(Vector2(zone.position) * TUILE, Vector2(zone.size) * TUILE)
	var sorti := [0]
	var chemins_hors := [0]
	var depart := Nav.centre_de_la_case(libres_dans[0])
	var fin := _simuler(b2, depart, 120.0, func(pos: Vector2) -> void:
		if not pixels.has_point(pos):
			sorti[0] += 1
		for c in b2.chemin_courant():
			if not zone.has_point(c):
				chemins_hors[0] += 1)
	_check("120 s simulées : la position ne sort jamais du rectangle", sorti[0] == 0, "%d images hors zone" % sorti[0])
	_check("… et aucun chemin ne passe par une case hors zone", chemins_hors[0] == 0)
	_check("… alors que le bot s'est bien déplacé", fin.distance_to(depart) > 0.0 and b2.cible_courante().x >= 0)
	_check("… en restant sur des cases libres", v.libre(Nav.case_du_monde(fin)))

	# Un départ HORS de la zone : le transit est permis (le chemin vient de l'extérieur), puis plus de sortie.
	var b3 := _bot(p, nav, 9)
	var dehors := Nav.centre_de_la_case(nav.case_praticable_proche(Vector2i(2, 2)))
	var dedans_apres := [0, 0]
	_simuler(b3, dehors, 90.0, func(pos: Vector2) -> void:
		if pixels.has_point(pos):
			dedans_apres[0] += 1
		elif dedans_apres[0] > 0:
			dedans_apres[1] += 1)
	_check("parti de l'extérieur, le bot rejoint la zone (%d images dedans)" % dedans_apres[0], dedans_apres[0] > 0)
	_check("… et une fois dedans, n'en ressort pas", dedans_apres[1] == 0, "%d images ressorties" % dedans_apres[1])

	# Un rectangle de taille nulle ne contraint rien : le profil se comporte en LIBRE, pas en statue.
	var p0 := Profil.new()
	p0.deplacement = Profil.Deplacement.ZONE
	var b0 := _bot(p0, nav, 3)
	var vues := {}
	for _i in 60:
		vues[b0.prochaine_cible(libres_dans[0])] = true
	_check("une ZONE sans rectangle choisit des cibles sur toute la carte (%d cases distinctes)" % vues.size(),
		vues.size() >= 10)


func _libre() -> void:
	print("\n--- LIBRE : toute la carte praticable, et la graine ---")
	var data: Dictionary = _cartes_livrees()["map_002_l_usine.json"]
	var nav := Nav.depuis_carte(data)
	var s1 := Codec.get_spawn(data, 0)
	var p := Profil.new()
	p.deplacement = Profil.Deplacement.LIBRE
	var a := _bot(p, nav, 12345)
	var b := _bot(p, nav, 12345)
	var c := _bot(p, nav, 54321)
	var suite_a: Array[Vector2i] = []
	var suite_b: Array[Vector2i] = []
	var suite_c: Array[Vector2i] = []
	for _i in 60:
		suite_a.append(a.prochaine_cible(s1))
		suite_b.append(b.prochaine_cible(s1))
		suite_c.append(c.prochaine_cible(s1))
	_check("même graine : exactement la même suite de 60 cibles", suite_a == suite_b)
	_check("une autre graine donne une autre suite (la garde discrimine)", suite_a != suite_c)
	var atteignables := nav.cases_atteignables(s1)
	var tous_atteignables := true
	for t in suite_a:
		if not atteignables.has(t):
			tous_atteignables = false
	_check("toutes les cibles sont des cases qu'on peut rejoindre à pied depuis l'apparition", tous_atteignables)
	var etalement := {}
	for t in suite_a:
		etalement[t] = true
	_check("… et elles couvrent la carte (%d cases distinctes sur 60 tirages)" % etalement.size(), etalement.size() >= 40)
	var proches := 0
	for t in suite_a:
		if Vector2(t - s1).length() < Bot.DISTANCE_MINIMALE_CASES:
			proches += 1
	_check("… et aucune n'est collée au point de départ", proches == 0, "%d trop proches" % proches)

	# Le bot marche, ne traverse rien, et change de cible quand il arrive.
	var v := Verite.new(data)
	var mur := [0]
	var cibles := {}
	var bot := _bot(p, nav, 77)
	var depart := Nav.centre_de_la_case(s1)
	var fin := _simuler(bot, depart, 120.0, func(pos: Vector2) -> void:
		if not v.libre(Nav.case_du_monde(pos)):
			mur[0] += 1
		cibles[bot.cible_courante()] = true)
	_check("120 s simulées sur l'Usine : jamais dans un solide", mur[0] == 0, "%d images" % mur[0])
	_check("… et plusieurs cibles atteintes (%d)" % cibles.size(), cibles.size() >= 5)
	_check("… le bot s'est bien éloigné de son point de départ", fin.distance_to(depart) > 100.0 or cibles.size() >= 5)
	# La consigne est de la longueur de l'allure.
	p.allure = 0.5
	var lent := _bot(p, nav, 77)
	lent.avancer(PAS, depart, VITESSE)
	_check("la commande a pour longueur l'allure du profil (0,5)",
		is_equal_approx(lent.get_movement_vector().length(), 0.5), str(lent.get_movement_vector().length()))
	_check("la visée est une direction unitaire", is_equal_approx(lent.get_aim_direction(depart).length(), 1.0))


func _immobile_et_commandes() -> void:
	print("\n--- IMMOBILE ne bouge pas ; le bot ne commande que de la marche ---")
	var data := _carte_de_reference()
	var nav := Nav.depuis_carte(data)
	var p := Profil.new()
	var b := _bot(p, nav, 1)
	var depart := Nav.centre_de_la_case(Codec.get_spawn(data, 1))
	var fin := _simuler(b, depart, 10.0, func(_pos: Vector2) -> void: pass)
	_check("IMMOBILE : aucune commande de mouvement en 10 s", fin == depart and b.get_movement_vector() == Vector2.ZERO)
	_check("IMMOBILE : aucune visée (le corps garde son orientation d'apparition)",
		b.get_aim_direction(depart) == Vector2.ZERO)

	# Un bot qui marche, puis toutes les commandes qu'il ne doit JAMAIS donner.
	p.deplacement = Profil.Deplacement.LIBRE
	var libre := _bot(p, nav, 1)
	# Des tableaux, pas des entiers : une lambda capture un entier PAR COPIE, et son `+= 1` ne se verrait jamais.
	var jamais := [0]
	var marche := [0]
	_simuler(libre, depart, 60.0, func(_pos: Vector2) -> void:
		if libre.get_movement_vector() != Vector2.ZERO:
			marche[0] += 1
		if libre.is_shoot_pressed() or libre.is_flare_pressed() or libre.is_gadget_pressed() \
				or libre.is_reload_pressed() or libre.is_crouch_pressed() or libre.is_climb_pressed() \
				or libre.is_flashlight_pressed() or libre.is_flashlight_locked():
			jamais[0] += 1)
	_check("en 60 s de marche (%d images en mouvement) : jamais tir, fusée, gadget, recharge, accroupi, enjambement ni torche" % marche[0],
		marche[0] > 600 and jamais[0] == 0, "%d images fautives" % jamais[0])
	_check("la torche est éteinte par défaut", not Profil.new().torche_allumee and not libre.is_flashlight_pressed())
	p.torche_allumee = true
	_check("… et allumée quand le profil le dit", libre.is_flashlight_pressed())
	_check("… sans que la torche donne un tir", not libre.is_shoot_pressed())


func _anti_blocage() -> void:
	print("\n--- L'anti-blocage : sans progrès, replanifier, puis changer de cible ---")
	var data := _carte_de_reference()
	var nav := Nav.depuis_carte(data)
	var p := Profil.new()
	p.deplacement = Profil.Deplacement.LIBRE
	var b := _bot(p, nav, 4)
	var pos := Nav.centre_de_la_case(Codec.get_spawn(data, 1))
	# Un corps coincé : la commande est donnée, la position ne change jamais.
	var cibles := {}
	for _i in int(round(8.0 / PAS)):
		b.avancer(PAS, pos, VITESSE)
		if b.cible_courante().x >= 0:
			cibles[b.cible_courante()] = true
	_check("8 s sans bouger : le bot a détecté le blocage (%d fois)" % b.blocages_total, b.blocages_total >= 4)
	_check("… et changé de cible (%d cibles essayées)" % cibles.size(), cibles.size() >= 2)
	# Un corps libre n'est jamais déclaré bloqué.
	var libre := _bot(p, nav, 4)
	_simuler(libre, Nav.centre_de_la_case(Codec.get_spawn(data, 1)), 60.0, func(_x: Vector2) -> void: pass)
	_check("un corps qui avance librement pendant 60 s n'est jamais déclaré bloqué", libre.blocages_total == 0,
		"%d blocages" % libre.blocages_total)


func _profil() -> void:
	print("\n--- Le profil ---")
	var p := Profil.new()
	_check("le profil par défaut est immobile, torche éteinte, à pleine allure",
		p.deplacement == Profil.Deplacement.IMMOBILE and not p.torche_allumee and is_equal_approx(p.allure, 1.0))
	var m := Profil.pour_entrainement_mobile()
	_check("le profil du cran « adversaire mobile » circule partout, torche éteinte",
		m.deplacement == Profil.Deplacement.LIBRE and not m.torche_allumee and m.allure > 0.0 and m.allure < 1.0)
	_check("les valeurs de l'énumération ne sont pas renumérotées (un profil sauvegardé les écrit en entiers)",
		Profil.Deplacement.IMMOBILE == 0 and Profil.Deplacement.RONDE == 1
		and Profil.Deplacement.ZONE == 2 and Profil.Deplacement.LIBRE == 3)
