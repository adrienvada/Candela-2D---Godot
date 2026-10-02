## La garde d'HONNÊTETÉ du bot — chantier SOLO, étape S2 : ce qu'il perçoit, jamais plus que la lumière et les sons.
##
## Adrien, 2026-10-02 : « l'adversaire doit être honnête : ne percevoir que les sons et la lumière, avec une précision plus
## ou moins bonne sur chaque son ». **Le modèle n'a le droit de se tromper que dans un sens : voir MOINS que la lumière,
## jamais plus.** Cette suite est la moitié HEADLESS de la preuve — des situations posées à la main, dont chacune dit ce que
## la lumière montrerait — ; l'autre moitié est `tools/banc_perception_bot.tscn`, en vraie fenêtre, qui confronte le modèle
## aux CAPTEURS réels et échoue s'il voit là où le capteur est noir.
##
## Ce que la suite vérifie, **sans monter le jeu** (`--script`, une carte fabriquée, des corps factices) :
##
##   • LES MURS — le parcours de grille case par case répond comme un test segment-rectangle sur les rectangles fusionnés de
##     `MapGeometry`, sur chaque carte livrée : il ne dit JAMAIS « dégagé » là où un rectangle coupe ; les murs bas suivent
##     la règle du jeu (`MursBas`) ;
##   • LE CADRE — le rectangle de la vue unique : sa taille, son décalage vers la visée, son orientation, ses constantes
##     relues sur `GameSettings` vivant ;
##   • LA VUE — cible dans le noir ; torche allumée avec un mur entre la lampe et le bot ; en ligne de vue et dans le
##     cadre ; hors du cadre ; dans le cône de la torche du bot, avec et sans mur, hors cône, hors portée ; éclair de tir,
##     fusée, halo de proximité ; murs bas, postures ; aveugle sous un gadget ;
##   • L'OUÏE — ses propres sons ne comptent pas ; un pas au-delà de sa portée, rien ; derrière un mur, un son est
##     étouffé ; la zone contient la vraie position et ne la centre jamais ; son rayon grandit avec la distance et derrière
##     un mur, et rétrécit avec la précision ; même graine, mêmes tirages ; la place exacte du son ne sort jamais ;
##   • LA MÉMOIRE — vue précise, ouïe en zone, une confiance qui s'efface, une trace vague qui n'efface pas une trace nette ;
##   • LE NŒUD — monté sur des corps factices : ses lumières, son aveuglement sous gadget, son abonnement au son, et
##     « un bot dans le noir, derrière un mur ou sourd n'apprend rien de la place de l'adversaire » ;
##   • LE PROFIL — sourd et aveugle par défaut, le cran mobile de S1 inchangé, et un fournisseur d'entrées dont `avancer()` et
##     `_decider()` ne LISENT jamais la perception (depuis S3, `_penser()` la lit — la garde en est `tools/test_bot_combat.gd`).
##
## **Sabotée famille par famille** (la règle du dépôt : une garde « jamais » ne se croit qu'après l'avoir vue rougir) — la
## liste est dans la ROADMAP, section SOLO, S2.
##
## Lancer : godot --headless --path . --script res://tools/test_bot_perception.gd
extends SceneTree

const Percep := preload("res://perception_bot.gd")
const Memoire := preload("res://memoire_bot.gd")
const Noeud := preload("res://perception_bot_noeud.gd")
const Profil := preload("res://profil_bot.gd")
const Bot := preload("res://bot_input_provider.gd")
const Nav := preload("res://navigation_bot.gd")
const Codec := preload("res://map_codec.gd")
const Geometrie := preload("res://map_geometry.gd")
const Murs := preload("res://murs_bas.gd")
const Son := preload("res://son_visible.gd")
const Portee := preload("res://portee_ecran.gd")
const Iso := preload("res://camera_iso.gd")

const TUILE := 35.0
const PAS := 1.0 / 60.0
## La lentille de la lampe : 16,1 px devant et 4,55 px à gauche (`Player.LENTILLE_LAMPE`).
const LENTILLE := Vector2(16.1, -4.55)

var _failures := 0
var _verifications := 0
var _monde: Dictionary = {}
var _data: Dictionary = {}
var _arme: WeaponData = null


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
	print("=== LE BOT PERÇOIT, HONNÊTEMENT (S2) ===")
	var statiques := _poser_les_statiques_du_jeu()
	_data = _carte()
	_monde = Percep.monde_de_la_carte(_data)
	_arme = WeaponData.new()
	_les_murs_sur_les_cartes_livrees()
	_les_murs_sur_la_carte_fabriquee()
	_le_cadre()
	_voir_les_lampes()
	_voir_le_cone_du_bot()
	_voir_les_disques()
	_voir_les_murs_bas()
	_voir_les_gadgets()
	_ouir()
	_la_memoire()
	await _l_occlusion_du_son_contre_le_moteur()
	await _le_noeud()
	await _le_profil_et_le_fournisseur()
	_restaurer_les_statiques(statiques)
	print("\n%d vérifications" % _verifications)
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# La mise en place
# ---------------------------------------------------------------------------

## Les portées des torches sont des statiques que `GameSettings.accorder_au_mode` pose au démarrage d'une manche : une suite
## en `--script` n'y passe pas, et un cookie sans portée de jeu ne serait pas celui qu'un joueur a. On pose celles du jeu
## (facteur 0,75, plancher ET plafond au bord le plus proche de la vue unique), puis on les rend.
func _poser_les_statiques_du_jeu() -> Array:
	var avant := [WeaponData.facteur_portee, WeaponData.portee_plancher, WeaponData.portee_plafond]
	var bord := Portee.portee_au_bord(Portee.VUE_UNIQUE, Percep.ZOOM_VUE_UNIQUE, Percep.DECALAGE_VISEE, Iso.TANGAGE_DEG)
	WeaponData.facteur_portee = 0.75
	WeaponData.portee_plancher = bord
	WeaponData.portee_plafond = bord
	return avant


func _restaurer_les_statiques(avant: Array) -> void:
	WeaponData.facteur_portee = avant[0]
	WeaponData.portee_plancher = avant[1]
	WeaponData.portee_plafond = avant[2]


## La carte des situations : 40 × 30 cases de sol (assez grand pour que le cadre de l'écran n'en mange pas toute la largeur),
## une paroi pleine en x = 26 (y de 8 à 21 : on la contourne par le haut ou le bas) et un mur BAS en x = 33 (y de 10 à 19).
func _carte() -> Dictionary:
	var d := Codec.new_map("perception", Vector2i(40, 30))
	var sol: Array[Vector2i] = []
	var murs: Array[Vector2i] = []
	var bas: Array[Vector2i] = []
	for y in 30:
		for x in 40:
			sol.append(Vector2i(x, y))
	for y in range(8, 22):
		murs.append(Vector2i(26, y))
	for y in range(10, 20):
		bas.append(Vector2i(33, y))
	d["floor"] = Codec.encode_runs(sol)
	d["walls"] = Codec.encode_runs(murs)
	d["low_walls"] = Codec.encode_runs(bas)
	return d


static func c(x: int, y: int) -> Vector2:
	return Vector2((float(x) + 0.5) * TUILE, (float(y) + 0.5) * TUILE)


func _bot(pos: Vector2, visee: Vector2 = Vector2.RIGHT, accroupi: bool = false) -> Dictionary:
	return {"position": pos, "visee": visee, "accroupi": accroupi, "id": 1}


func _cible(pos: Vector2, accroupi: bool = false) -> Dictionary:
	return {"position": pos, "accroupi": accroupi}


## La lampe d'un joueur qui est en `pos` et vise `visee` : la lentille, posée dans son repère.
func _lampe(pos: Vector2, visee: Vector2) -> Vector2:
	return pos + LENTILLE.rotated(visee.angle())


func _h(accroupi: bool = false) -> float:
	return Murs.hauteur_de_posture(accroupi)


func _voit(bot: Dictionary, cible: Dictionary, lumieres: Array, monde: Dictionary = {}) -> Dictionary:
	return Percep.voir(bot, cible, lumieres, _monde if monde.is_empty() else monde)


## Un point de l'écran du bot, `v` pixels dans les axes de l'écran (x à droite, y vers le bas), ramené au monde.
func _ecran(centre: Vector2, v: Vector2) -> Vector2:
	return centre + v.rotated(-deg_to_rad(Percep.LACET_DEFAUT))


# ---------------------------------------------------------------------------
# LES MURS
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


## Sur chaque carte livrée : le parcours de grille ne dit JAMAIS « dégagé » là où un rectangle fusionné coupe le segment
## (la vérité est calculée à part, sans passer par lui : `MursBas.coupe_un_mur_haut` sur `MapGeometry.rects_monde`).
## L'inverse — « coupé » là où aucun rectangle ne touche — se compte, et reste rarissime : un segment qui rase un coin.
func _les_murs_sur_les_cartes_livrees() -> void:
	print("\n[Les murs, sur chaque carte livrée]")
	var cartes := _cartes_livrees()
	_check("le catalogue livre plusieurs cartes", cartes.size() >= 5, str(cartes.size()))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261002
	for nom: String in cartes:
		var data: Dictionary = cartes[nom]
		var monde := Percep.monde_de_la_carte(data)
		var rects: Array = Geometrie.rects_monde(data, Geometrie.Kind.WALLS)
		var grille := Vector2(Codec.get_grid_size(data)) * TUILE
		var faux_degages := 0
		var faux_coupes := 0
		var coupes := 0
		var total := 4000
		for _i in total:
			var a := Vector2(rng.randf_range(0.0, grille.x), rng.randf_range(0.0, grille.y))
			var b := a + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10.0, 900.0)
			var vrai := Murs.coupe_un_mur_haut(a, b, rects)
			var modele := not Percep.segment_degage(a, b, monde)
			if vrai:
				coupes += 1
			if vrai and not modele:
				faux_degages += 1
			elif modele and not vrai:
				faux_coupes += 1
		_check("%s : jamais « dégagé » à travers un mur (%d segments dont %d coupés ; %d « coupés » à tort, des coins)"
			% [nom, total, coupes, faux_coupes], faux_degages == 0 and coupes > 0, "%d faux dégagés" % faux_degages)
		_check("%s : le parcours de grille ne coupe presque jamais à tort (moins d'un pour mille, des segments qui rasent un coin)"
			% nom, faux_coupes * 1000 <= total, "%d sur %d" % [faux_coupes, total])


func _les_murs_sur_la_carte_fabriquee() -> void:
	print("\n[Les murs, sur la carte fabriquée]")
	var a := c(20, 15)
	_check("sans mur entre deux points, la ligne est dégagée", Percep.segment_degage(a, c(23, 15), _monde))
	_check("la paroi pleine coupe le segment qui la traverse", not Percep.segment_degage(a, c(30, 15), _monde))
	_check("on la contourne par le haut", Percep.segment_degage(c(20, 5), c(30, 5), _monde))
	_check("un point de départ DANS un mur coupe", not Percep.segment_degage(c(26, 15), c(23, 15), _monde))
	_check("un point d'arrivée DANS un mur coupe", not Percep.segment_degage(c(23, 15), c(26, 15), _monde))
	# Un segment qui passe EXACTEMENT par un coin de mur : du côté du noir.
	var coin := Vector2(26.0 * TUILE, 8.0 * TUILE)
	_check("un segment par le coin d'un mur le coupe (du côté du noir)",
		not Percep.segment_degage(coin + Vector2(-70, 70), coin + Vector2(70, -70), _monde))
	_check("le vide hors de la grille n'est pas un mur : la lumière y file",
		Percep.segment_degage(Vector2(-300, 100), Vector2(-50, 120), _monde))
	_check("le segment nul est dégagé en terrain libre", Percep.segment_degage(a, a, _monde))
	# Les murs BAS : la règle du jeu, par `MursBas`, ni plus ni moins.
	var bas := c(33, 15)
	var debout_a_debout := Percep.ligne_de_vue(bas + Vector2(-100, 0), bas + Vector2(100, 0), _h(), _h(), _monde)
	_check("debout, on voit une tête debout par-dessus un mur bas", debout_a_debout)
	_check("un mur bas ne coupe pas la grille des murs HAUTS", Percep.segment_degage(bas + Vector2(-100, 0), bas + Vector2(100, 0), _monde))
	_check("la lumière d'un accroupi bute sur le mur bas",
		not Percep.ligne_de_vue(bas + Vector2(-100, 0), bas + Vector2(100, 0), _h(true), _h(), _monde))
	# Le même calcul que la règle du jeu, point pour point : on la rappelle sans passer par le modèle.
	var rects_bas: Array = _monde["murs_bas"]
	var accord := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i in 300:
		var p := Vector2(rng.randf_range(900.0, 1300.0), rng.randf_range(300.0, 750.0))
		var q := Vector2(rng.randf_range(900.0, 1300.0), rng.randf_range(300.0, 750.0))
		var h1 := _h(rng.randf() < 0.5)
		var h2 := _h(rng.randf() < 0.5)
		if Percep.ligne_de_vue(p, q, h1, h2, _monde) != (Percep.segment_degage(p, q, _monde) and Murs.franchit_regle(p, q, h1, h2, rects_bas)):
			accord = false
	_check("la ligne de vue = murs hauts ET la règle des murs bas du jeu, sur 300 tirages", accord)


# ---------------------------------------------------------------------------
# LE CADRE
# ---------------------------------------------------------------------------

func _le_cadre() -> void:
	print("\n[Le cadre de l'écran]")
	# Les constantes recopiées valent celles du jeu vivant : une copie qu'aucun contrôle ne relie à l'original dérive.
	var reglages: Node = root.get_node("GameSettings")
	var table: Dictionary = reglages.get_script().get_script_constant_map()
	_check("le zoom de la vue unique est celui de GameSettings (%.2f)" % float(table["ZOOM_VUE_UNIQUE"]),
		is_equal_approx(Percep.ZOOM_VUE_UNIQUE, float(table["ZOOM_VUE_UNIQUE"])))
	_check("le décalage vers la visée est celui de GameSettings (%.2f)" % float(table["DECALAGE_VISEE_DEFAUT"]),
		is_equal_approx(Percep.DECALAGE_VISEE, float(table["DECALAGE_VISEE_DEFAUT"])))
	_check("le lacet est celui de GameSettings (%.0f°)" % float(table["LACET_DEFAUT"]),
		is_equal_approx(Percep.LACET_DEFAUT, float(table["LACET_DEFAUT"])))
	var centre := c(20, 15)
	var cadre := Percep.cadre_de_vue(centre, Vector2.RIGHT)
	var demi: Vector2 = cadre["demi"]
	_check("la vue unique à ×1,5 montre un demi-rectangle de 504,3 × 360 px", absf(demi.x - 504.3) < 0.2 and absf(demi.y - 360.0) < 0.01,
		str(demi))
	_check("le centre du cadre est avancé de 15 % de la profondeur vers la visée (108 px)",
		(cadre["centre"] as Vector2).distance_to(centre + Vector2(108.0, 0.0)) < 0.01, str(cadre["centre"]))
	_check("sans visée, le cadre est centré sur le joueur",
		(Percep.cadre_de_vue(centre, Vector2.ZERO)["centre"] as Vector2).is_equal_approx(centre))
	var vers_visee := Percep.cadre_de_vue(centre, Vector2.RIGHT)
	var vers_oppose := Percep.cadre_de_vue(centre, Vector2.LEFT)
	_check("viser de l'autre côté avance le cadre de l'autre côté",
		(vers_visee["centre"] as Vector2).x > centre.x and (vers_oppose["centre"] as Vector2).x < centre.x)
	# Les bords, dans les axes de l'écran (tournés du lacet).
	var cg: Vector2 = vers_visee["centre"]
	_check("le milieu du cadre est dedans", Percep.dans_le_cadre(cg, vers_visee))
	_check("30 px sous le bord haut de l'écran : dedans", Percep.dans_le_cadre(_ecran(cg, Vector2(0.0, -(demi.y - 30.0))), vers_visee))
	_check("30 px au-delà du bord haut de l'écran : dehors", not Percep.dans_le_cadre(_ecran(cg, Vector2(0.0, -(demi.y + 30.0))), vers_visee))
	_check("30 px sous le bord bas de l'écran : dedans", Percep.dans_le_cadre(_ecran(cg, Vector2(0.0, demi.y - 30.0)), vers_visee))
	_check("30 px au-delà du bord bas de l'écran : dehors", not Percep.dans_le_cadre(_ecran(cg, Vector2(0.0, demi.y + 30.0)), vers_visee))
	_check("30 px sous le bord droit de l'écran : dedans", Percep.dans_le_cadre(_ecran(cg, Vector2(demi.x - 30.0, 0.0)), vers_visee))
	_check("30 px au-delà du bord droit de l'écran : dehors", not Percep.dans_le_cadre(_ecran(cg, Vector2(demi.x + 30.0, 0.0)), vers_visee))
	_check("30 px au-delà du bord gauche de l'écran : dehors", not Percep.dans_le_cadre(_ecran(cg, Vector2(-(demi.x + 30.0), 0.0)), vers_visee))
	_check("la marge resserre le cadre : un point à 10 px du bord n'y est plus avec 18 px de marge",
		Percep.dans_le_cadre(_ecran(cg, Vector2(0.0, demi.y - 10.0)), vers_visee)
		and not Percep.dans_le_cadre(_ecran(cg, Vector2(0.0, demi.y - 10.0)), vers_visee, Percep.RAYON_CORPS))
	# Le lacet tourne le cadre : le même point du monde est dedans à 0° et dehors à 90° (la demi-largeur de l'écran est de
	# 504,3, sa demi-profondeur de 360 : un quart de tour échange les deux).
	var a0 := Percep.cadre_de_vue(centre, Vector2.ZERO, {"lacet": 0.0})
	var a90 := Percep.cadre_de_vue(centre, Vector2.ZERO, {"lacet": 90.0})
	var point_large := centre + Vector2(450.0, 0.0)
	_check("le lacet tourne le cadre : un point à 450 px à droite du joueur est dedans à 0° (demi-largeur 504) et dehors à 90° (demi-profondeur 360)",
		Percep.dans_le_cadre(point_large, a0) and not Percep.dans_le_cadre(point_large, a90))
	# Un décalage lissé que la caméra n'a pas encore atteint : le cadre suit LA CAMÉRA, pas la visée.
	var en_retard := Percep.cadre_de_vue(centre, Vector2.RIGHT, {"decalage_lisse": Vector2.ZERO})
	_check("un décalage lissé nul laisse le cadre sur le joueur (la caméra n'a pas encore bougé)",
		(en_retard["centre"] as Vector2).is_equal_approx(centre))
	# Le cadre est borné au rectangle de la vue : jamais plus que ce qu'un joueur voit — la moitié de la profondeur d'écran
	# plus le décalage au plus, dans la direction qu'il vise.
	_check("le bord le plus lointain du cadre est à 504,3 + 108 px du joueur dans la direction de la visée",
		Percep.dans_le_cadre(_ecran(centre + Vector2(108.0, 0.0), Vector2(demi.x - 1.0, 0.0)), vers_visee))


# ---------------------------------------------------------------------------
# VOIR : la lampe de la cible
# ---------------------------------------------------------------------------

func _voir_les_lampes() -> void:
	print("\n[Voir : la cible dans le noir, et sa lampe]")
	var bot := _bot(c(20, 15))
	var clair := c(23, 15)
	var derriere := c(30, 15)
	var visee_cible := Vector2.LEFT

	# 1. Dans le noir : aucune lumière, hors de tout cône → rien. Torche éteinte.
	var r := _voit(bot, _cible(clair), [])
	_check("dans le noir, torche éteinte, hors de tout cône : le bot ne voit rien", not r["vu"] and (r["par"] as Array).is_empty())
	# Le noir ne s'achète pas : une lumière lointaine qui n'atteint pas la cible ne change rien.
	var loin := Percep.lumiere_disque("fusee_loin", c(5, 5), 90.0, 5.0)
	_check("une lumière qui n'atteint pas la cible ne la révèle pas", not _voit(bot, _cible(clair), [loin])["vu"])

	# 2. Torche allumée, mur plein entre la lampe et le bot → rien.
	var lampe_derriere := Percep.lumiere_lampe("lampe_de_la_cible", _lampe(derriere, visee_cible), _h())
	r = _voit(bot, _cible(derriere), [lampe_derriere])
	_check("sa torche est allumée, mais une paroi pleine est entre sa lampe et le bot : rien n'est vu", not r["vu"])
	_check("… alors que le corps est bien dans le cadre (c'est le mur, pas le cadre)", r["dans_le_cadre"])

	# 3. Torche allumée, en ligne de vue, dans le cadre → vu.
	var lampe := Percep.lumiere_lampe("lampe_de_la_cible", _lampe(clair, visee_cible), _h())
	r = _voit(bot, _cible(clair), [lampe])
	_check("sa torche est allumée, en ligne de vue et dans le cadre : le bot le voit", r["vu"] and (r["par"] as Array) == ["lampe_de_la_cible"], str(r))
	_check("ce qu'il voit est la LAMPE, à 17 px du centre du corps (pas la place exacte)",
		(r["position"] as Vector2).is_equal_approx(_lampe(clair, visee_cible)) and (r["position"] as Vector2).distance_to(clair) < 20.0)

	# 4. Hors du cadre : la lampe est allumée, la ligne dégagée, l'écran ne la montre pas.
	var cadre := Percep.cadre_de_vue(bot["position"], bot["visee"])
	var demi: Vector2 = cadre["demi"]
	var hors := _ecran(cadre["centre"], Vector2(0.0, -(demi.y + 60.0)))
	var lampe_hors := Percep.lumiere_lampe("lampe_de_la_cible", _lampe(hors, visee_cible), _h())
	_check("(la ligne de vue est bien dégagée jusqu'au point hors cadre)", Percep.ligne_de_vue(bot["position"], hors, _h(), _h(), _monde))
	r = _voit(bot, _cible(hors), [lampe_hors])
	_check("sa lampe brûle, la ligne est dégagée, mais le point est hors du cadre de l'écran : rien", not r["vu"] and not r["dans_le_cadre"], str(r))
	var dedans := _ecran(cadre["centre"], Vector2(0.0, -(demi.y - 60.0)))
	var lampe_dedans := Percep.lumiere_lampe("lampe_de_la_cible", _lampe(dedans, visee_cible), _h())
	_check("le même point 120 px plus près, dans le cadre : vu", _voit(bot, _cible(dedans), [lampe_dedans])["vu"])

	# 5. Le cadre suit la visée : viser de l'autre côté déplace le bord.
	# (Sur la carte sans paroi : seul le cadre est en cause.) Le point est au bas de l'écran du bot qui vise à l'est ; en visant
	# à l'ouest, la caméra recule de 216 px vers l'ouest — vers le HAUT de l'écran, à 45° — et ce point sort par le bas.
	var libre := Percep.monde_de_la_carte(_carte_sans_mur())
	var bot_oppose := _bot(c(20, 15), Vector2.LEFT)
	var pres_du_bord := _ecran((Percep.cadre_de_vue(c(20, 15), Vector2.RIGHT)["centre"] as Vector2), Vector2(0.0, demi.y - 30.0))
	var lampe_pres := Percep.lumiere_lampe("lampe_de_la_cible", _lampe(pres_du_bord, visee_cible), _h())
	_check("en visant du côté de la cible, elle est dans le cadre",
		Percep.voir(bot, _cible(pres_du_bord), [lampe_pres], libre)["vu"])
	_check("en visant à l'opposé, la caméra recule et la même cible sort du cadre",
		not Percep.voir(bot_oppose, _cible(pres_du_bord), [lampe_pres], libre)["vu"])

	# 6. La lampe est une lumière CONNUE parmi d'autres : plusieurs entrées, la liste décide.
	r = _voit(bot, _cible(clair), [loin, lampe])
	_check("une liste de plusieurs lumières : seules celles qui révèlent la cible sont nommées", (r["par"] as Array) == ["lampe_de_la_cible"])


# ---------------------------------------------------------------------------
# VOIR : le cône de la torche du bot
# ---------------------------------------------------------------------------

func _voir_le_cone_du_bot() -> void:
	print("\n[Voir : le cône de la torche du bot]")
	var pos := c(20, 15)
	var bot := _bot(pos)
	var origine := _lampe(pos, Vector2.RIGHT)
	var cone := Percep.lumiere_cone("torche_du_bot", origine, Vector2.RIGHT, _h(), _arme)
	var portee := _arme.portee_torche()
	_check("(la portée de la torche du Parasite est celle du jeu : le bord le plus proche de la vue unique)", absf(portee - 468.0) < 1.0, str(portee))

	var devant := c(23, 15)
	var r := _voit(bot, _cible(devant), [cone])
	_check("la cible est dans le cône de la torche du bot, sans mur : vue", r["vu"] and (r["par"] as Array) == ["torche_du_bot"], str(r))
	_check("… et c'est le corps éclairé qu'on voit, à sa place (précis)", (r["position"] as Vector2).is_equal_approx(devant))
	_check("la même cible, torche éteinte (aucun cône dans la liste) : rien", not _voit(bot, _cible(devant), [])["vu"])

	# Avec un mur : le cône est dans l'axe, à 350 px — dans la portée —, mais la paroi pleine est entre les deux.
	var derriere := c(30, 15)
	_check("(la cible derrière la paroi est dans la portée et dans l'axe)", pos.distance_to(derriere) < portee)
	r = _voit(bot, _cible(derriere), [cone])
	_check("dans le cône de la torche mais derrière une paroi pleine : rien", not r["vu"], str(r))
	# La même cible, sans la paroi (on retire le mur de la carte) : vue — le mur est donc bien la seule raison.
	var sans_mur := Percep.monde_de_la_carte(_carte_sans_mur())
	_check("la même cible, la paroi retirée : vue (le mur était la seule raison)", Percep.voir(bot, _cible(derriere), [cone], sans_mur)["vu"])

	# Hors du cône : de côté.
	var de_cote := c(23, 20)
	_check("hors du cône (à 55° de l'axe) : rien", not _voit(bot, _cible(de_cote), [cone])["vu"])
	# Juste dans le cône, juste hors du cône : le demi-angle du Parasite est 20,34°.
	var d := 140.0
	var dans := origine + Vector2.from_angle(deg_to_rad(10.0)) * d
	var hors_cone := origine + Vector2.from_angle(deg_to_rad(38.0)) * d
	_check("à 10° de l'axe : vue", _voit(bot, _cible(dans), [cone])["vu"])
	_check("à 38° de l'axe, bien hors du demi-angle de 20,34° : rien", not _voit(bot, _cible(hors_cone), [cone])["vu"])
	# Hors de portée.
	var trop_loin := origine + Vector2.RIGHT * (portee + 60.0)
	var sans_paroi := Percep.monde_de_la_carte(_carte_sans_mur())
	_check("hors de la portée de la torche (468 px + 60) : rien", not Percep.voir(bot, _cible(trop_loin), [cone], sans_paroi)["vu"])
	_check("à 80 % de la portée : vue", Percep.voir(bot, _cible(origine + Vector2.RIGHT * portee * 0.8), [cone], sans_paroi)["vu"])
	# Derrière le bot.
	_check("derrière le bot : rien", not _voit(bot, _cible(c(17, 15)), [cone])["vu"])
	# Le cône analytique (une arme sans cookie) ne voit pas plus loin que sa portée non plus.
	var analytique := Percep.lumiere_cone("cone_analytique", origine, Vector2.RIGHT, _h(), null, 300.0, deg_to_rad(20.0))
	_check("le cône analytique : dans la portée, vu", Percep.voir(bot, _cible(origine + Vector2.RIGHT * 200.0), [analytique], sans_paroi)["vu"])
	_check("le cône analytique : au-delà de la portée, rien", not Percep.voir(bot, _cible(origine + Vector2.RIGHT * 340.0), [analytique], sans_paroi)["vu"])
	# La lumière doit atteindre le corps ENTIER sans mur : un mur qui coupe le point de bord seul ne suffit pas à voir.
	_check("la valeur de cookie du modèle est celle de `WeaponData.lumiere_recue`, point pour point",
		is_equal_approx(Percep.intensite_cone(cone, dans), _arme.lumiere_recue(Vector2.RIGHT, origine, dans)))


## La carte fabriquée sans sa paroi pleine : pour vérifier que c'est bien elle qui coupe.
func _carte_sans_mur() -> Dictionary:
	var d := _carte()
	d["walls"] = ""
	return d


# ---------------------------------------------------------------------------
# VOIR : les disques (éclair, fusée, halo, plafonnier à venir)
# ---------------------------------------------------------------------------

func _voir_les_disques() -> void:
	print("\n[Voir : l'éclair d'un tir, la fusée, le halo]")
	var bot := _bot(c(20, 15))
	var clair := c(23, 15)
	var derriere := c(30, 15)

	# L'éclair d'un tir de la cible : à son canon, rayon 32 px × 0,6.
	var canon := derriere + Vector2(28.0, 0.0)
	var eclair_derriere := Percep.lumiere_disque("eclair_de_la_cible", derriere + Vector2(-28.0, 0.0), 32.0 * Percep.FRACTION_DISQUE, _h())
	var r := _voit(bot, _cible(derriere), [eclair_derriere])
	_check("l'éclair d'un tir derrière une paroi : le bot ne le voit pas", not r["vu"], str(r))
	var eclair_clair := Percep.lumiere_disque("eclair_de_la_cible", clair + Vector2(-28.0, 0.0), 32.0 * Percep.FRACTION_DISQUE, _h())
	r = _voit(bot, _cible(clair), [eclair_clair])
	_check("le même éclair en ligne de vue : le bot voit le tireur, à sa place", r["vu"] and (r["position"] as Vector2).is_equal_approx(clair), str(r))
	_check("l'éclair ne révèle que ce qu'il touche : un tireur à 200 px de la tache n'est pas vu",
		not _voit(bot, _cible(clair + Vector2(0, 200)), [eclair_clair])["vu"])
	_check("(le canon est bien un point à 28 px du centre du tireur)", canon.distance_to(derriere) == 28.0)

	# La fusée posée : une tache de 440 px d'empreinte à plein feu (rayon 220), à hauteur du sol.
	var tuile := TUILE
	var h_sol := Noeud.HAUTEUR_FUSEE_AU_SOL_TUILES * tuile
	var fusee := Percep.lumiere_disque("fusee", c(23, 12), 220.0 * Percep.FRACTION_DISQUE, h_sol)
	_check("une fusée posée éclaire la cible à 105 px d'elle : vue", _voit(bot, _cible(clair), [fusee])["vu"])
	_check("… et pas une cible à 240 px d'elle, hors de la tache", not _voit(bot, _cible(c(23, 21)), [fusee])["vu"])
	var fusee_derriere := Percep.lumiere_disque("fusee", c(29, 15), 220.0 * Percep.FRACTION_DISQUE, h_sol)
	_check("une fusée de l'autre côté de la paroi n'éclaire pas la cible de ce côté-ci : rien", not _voit(bot, _cible(c(25, 15)), [fusee_derriere])["vu"])
	_check("… mais éclaire la cible qui est de son côté, si le bot la voit : rien non plus (la paroi est entre le bot et elle)",
		not _voit(bot, _cible(c(28, 15)), [fusee_derriere])["vu"])
	# Le bot qui regarde la scène de l'autre côté de la paroi par le haut de la carte voit ce que la fusée éclaire.
	var haut := _bot(c(29, 5), Vector2.DOWN)
	_check("vu du côté de la fusée, le même corps éclairé est vu", _voit(haut, _cible(c(28, 15)), [fusee_derriere])["vu"])

	# Le halo de proximité du bot : ma lueur éclaire l'ennemi collé à moi (75 px de rayon, 0,6 retenu).
	var halo := Percep.lumiere_disque("halo_du_bot", bot["position"], 75.0 * Percep.FRACTION_DISQUE, _h())
	_check("le halo de proximité révèle un adversaire collé au bot (à 40 px)", _voit(bot, _cible(bot["position"] + Vector2(40, 0)), [halo])["vu"])
	_check("… pas un adversaire à 120 px", not _voit(bot, _cible(bot["position"] + Vector2(120, 0)), [halo])["vu"])

	# Un plafonnier à venir (S5) : un disque posé, indestructible, de la même liste — rien d'autre à changer.
	var plafonnier := Percep.lumiere_disque("plafonnier", c(23, 15), 150.0, 175.0)
	_check("la liste accueille un plafonnier sans refonte : la cible sous sa flaque est vue", _voit(bot, _cible(clair), [plafonnier])["vu"])
	_check("… et hors de sa flaque, non", not _voit(bot, _cible(c(23, 25)), [plafonnier])["vu"])
	# Un plafonnier est un disque comme un autre pour les murs : la paroi coupe sa lumière.
	var plafonnier_mur := Percep.lumiere_disque("plafonnier", c(28, 15), 150.0, 175.0)
	_check("la paroi coupe la flaque d'un plafonnier : rien", not _voit(bot, _cible(c(25, 15)), [plafonnier_mur])["vu"])


# ---------------------------------------------------------------------------
# VOIR : les murs bas et les postures
# ---------------------------------------------------------------------------

func _voir_les_murs_bas() -> void:
	print("\n[Voir : les murs bas et les postures]")
	# Un mur bas en x = 33 (y de 10 à 19), de 1155 à 1190 px ; la lumière le rentre de 3 px (sortie à 1187).
	# La zone morte derrière lui : 1,25 tuile (44 px) pour un corps accroupi, 1,67 tuile (58 px) pour le sol.
	var source_x := c(30, 15).x
	var y := c(30, 15).y
	var debout := _bot(Vector2(source_x, y))
	var bas_a_droite := 33.0 * TUILE + TUILE
	var tete_debout := Vector2(bas_a_droite + 20.0, y)
	var accroupi_pres := Vector2(bas_a_droite + 20.0, y)
	var accroupi_loin := Vector2(bas_a_droite + 70.0, y)
	var lampe_debout := Percep.lumiere_lampe("lampe_de_la_cible", tete_debout + LENTILLE, _h())
	_check("debout, on voit une tête debout par-dessus un mur bas, collée à lui", _voit(debout, _cible(tete_debout), [lampe_debout])["vu"])
	var lampe_accroupie := Percep.lumiere_lampe("lampe_de_la_cible", accroupi_pres + LENTILLE, _h(true))
	_check("un accroupi collé derrière le mur bas (dans la zone morte de 44 px) n'est pas vu d'un joueur debout",
		not _voit(debout, _cible(accroupi_pres, true), [lampe_accroupie])["vu"])
	var lampe_loin := Percep.lumiere_lampe("lampe_de_la_cible", accroupi_loin + LENTILLE, _h(true))
	_check("le même accroupi 70 px derrière, hors de la zone morte : vu (la règle de l'« angle commun »)",
		_voit(debout, _cible(accroupi_loin, true), [lampe_loin])["vu"])
	# Un bot accroupi voit bas : sa ligne de vue bute sur le mur bas, même vers une tête debout.
	var accroupi := _bot(Vector2(source_x, y), Vector2.RIGHT, true)
	_check("un bot ACCROUPI derrière un mur bas ne voit pas par-dessus : rien, même d'une tête debout",
		not _voit(accroupi, _cible(tete_debout), [lampe_debout])["vu"])
	# Une fusée au sol bute sur le mur bas (elle brûle plus bas que lui) : elle n'éclaire pas ce qu'il cache.
	var h_sol := Noeud.HAUTEUR_FUSEE_AU_SOL_TUILES * TUILE
	var fusee_devant := Percep.lumiere_disque("fusee", Vector2(source_x + 40.0, y), 200.0, h_sol)
	_check("une fusée posée AU SOL, d'un côté d'un mur bas, n'éclaire pas la cible de l'autre côté (elle bute)",
		not Percep.eclaire(fusee_devant, Vector2(bas_a_droite + 20.0, y), _h(), _monde))
	var fusee_haute := Percep.lumiere_disque("fusee_en_vol", Vector2(source_x + 40.0, y), 200.0, 1.5 * TUILE)
	_check("la même fusée EN L'AIR (au lancer, 1,5 tuile) passe par-dessus le mur bas : elle éclaire une tête debout",
		Percep.eclaire(fusee_haute, Vector2(bas_a_droite + 20.0, y), _h(), _monde))
	# Du côté de la source, un mur bas ne coupe rien : il n'est pas entre la source et la cible.
	_check("du même côté d'un mur bas, la fusée au sol éclaire normalement",
		Percep.eclaire(fusee_devant, Vector2(source_x + 70.0, y), _h(), _monde))


# ---------------------------------------------------------------------------
# VOIR : l'aveuglement sous un gadget
# ---------------------------------------------------------------------------

func _voir_les_gadgets() -> void:
	print("\n[Voir : aveugle quand le monde ne sait pas être modélisé]")
	var bot := _bot(c(20, 15))
	var clair := c(23, 15)
	var lampe := Percep.lumiere_lampe("lampe_de_la_cible", _lampe(clair, Vector2.LEFT), _h())
	var aveugle := _monde.duplicate()
	aveugle["aveugle"] = true
	_check("sous un gadget qui bouche ou étouffe la lumière (`aveugle`), la lampe, en ligne de vue, ne se voit plus",
		not Percep.voir(bot, _cible(clair), [lampe], aveugle)["vu"])
	_check("le monde sans gadget : vue", _voit(bot, _cible(clair), [lampe])["vu"])
	_check("la carte, par défaut, n'est pas aveugle", not bool(_monde["aveugle"]))


# ---------------------------------------------------------------------------
# OUÏR
# ---------------------------------------------------------------------------

## Un événement `son_localise`, avec les niveaux et les portées RÉELS de l'audio du jeu (ses tables, relues sur l'autoload
## vivant) — jamais des nombres de la suite.
func _evenement(famille: String, pos: Vector2, emetteur: int = 0, fumee_db: float = 0.0) -> Dictionary:
	var audio: Node = root.get_node("AudioManager")
	var table: Dictionary = audio.get_script().get_script_constant_map()
	var diagonale := 1583.0
	return {
		"cle": famille, "famille": famille, "pos": pos, "emetteur": emetteur,
		"niveau_db": float(table["NIVEAU_RELATIF"].get(famille, 0.0)),
		"portee": diagonale * float(table["PORTEE_RELATIVE"].get(famille, 1.0)) * float(table["FACTEUR_PORTEE_DEFAUT"]),
		"fumee_db": fumee_db, "wet": 0.0, "diagonale": diagonale,
	}


func _ouir() -> void:
	print("\n[L'ouïe]")
	var bot := {"position": c(20, 15), "id": 1, "accroupi": false, "visee": Vector2.RIGHT}
	var rng := RandomNumberGenerator.new()
	rng.seed = 99

	# Ses propres sons, la salle, et la portée.
	var pas_a_100 := _evenement("footstep", c(20, 15) + Vector2(100, 0), 0)
	_check("un pas de l'adversaire à 100 px est entendu", not Percep.ecouter(pas_a_100, bot, _monde, rng).is_empty())
	var pas_propre := _evenement("footstep", c(20, 15) + Vector2(100, 0), 1)
	_check("ses PROPRES sons ne comptent pas (émetteur = lui)", Percep.ecouter(pas_propre, bot, _monde, rng).is_empty())
	var pas_du_monde := _evenement("footstep", c(20, 15) + Vector2(100, 0), -1)
	_check("un son du monde (émetteur -1) est entendu", not Percep.ecouter(pas_du_monde, bot, _monde, rng).is_empty())
	_check("la salle (ambiance), muette pour le liseré, l'est pour le bot", Percep.ecouter(_evenement("ambience", c(21, 15), -1), bot, _monde, rng).is_empty())
	_check("le clic de torche (muet) n'est pas une information non plus", Percep.ecouter(_evenement("torch_on", c(21, 15), 0), bot, _monde, rng).is_empty())
	var pas_loin := _evenement("footstep", c(20, 15) + Vector2(3000, 0), 0)
	_check("un pas au-delà de sa portée (%.0f px) : rien" % float(pas_loin["portee"]), Percep.ecouter(pas_loin, bot, _monde, rng).is_empty())
	var pas_au_bord := _evenement("footstep", c(20, 15) + Vector2(-float(pas_a_100["portee"]) - 10.0, 0), 0)
	_check("juste au-delà de sa portée : rien", Percep.ecouter(pas_au_bord, bot, _monde, rng).is_empty())
	var tir_loin := _evenement("shoot", c(20, 15) + Vector2(-1500, 0), 0)
	_check("un tir porte plus loin qu'un pas : entendu à 1 500 px, là où un pas ne l'est plus",
		not Percep.ecouter(tir_loin, bot, _monde, rng).is_empty() and Percep.ecouter(_evenement("footstep", c(20, 15) + Vector2(-1750, 0), 0), bot, _monde, rng).is_empty())

	# La zone : elle contient la vraie position avec la bonne probabilité (toujours), ne la centre jamais.
	var n := 3000
	var dedans := 0
	var ecart_min := INF
	var rayon_vu := 0.0
	var vrai := pas_a_100["pos"] as Vector2
	for i in n:
		var z := Percep.ecouter(pas_a_100, bot, _monde, rng)
		var r := float(z["rayon"])
		rayon_vu = r
		var d: float = (z["centre"] as Vector2).distance_to(vrai)
		if d <= r:
			dedans += 1
		ecart_min = minf(ecart_min, d / r)
	_check("un pas entendu : la zone contient la vraie position dans 100 %% des %d tirages (%d)" % [n, dedans], dedans == n)
	_check("… et ne la centre jamais : le centre est toujours à plus de 7 %% du rayon de la vérité (minimum vu %.3f)" % ecart_min,
		ecart_min >= 0.07)
	_check("… le bot ne reçoit pas la position exacte : aucune clé de la zone ne la porte",
		not Percep.ecouter(pas_a_100, bot, _monde, rng).has("pos") and not Percep.ecouter(pas_a_100, bot, _monde, rng).has("position"))
	var decentrage_moyen := 0.0
	for i in n:
		var z2 := Percep.ecouter(pas_a_100, bot, _monde, rng)
		decentrage_moyen += (z2["centre"] as Vector2).distance_to(vrai) / float(z2["rayon"])
	decentrage_moyen /= float(n)
	_check("le décentrage est réparti, pas fixe : en moyenne entre 30 et 65 %% du rayon (%.2f)" % decentrage_moyen, decentrage_moyen > 0.3 and decentrage_moyen < 0.65)
	_check("le rayon d'un pas à 100 px reste d'un corps ou deux (le plancher, %.0f px)" % rayon_vu, rayon_vu >= Percep.RAYON_ZONE_MIN and rayon_vu < 80.0)

	# Le rayon grandit avec la distance — pour un pas et pour un tir.
	for famille in ["footstep", "shoot", "shell"]:
		var rayons: Array[float] = []
		var distances: Array[float] = [150.0, 400.0, 800.0, 1200.0]
		for dist in distances:
			var ev := _evenement(famille, c(20, 15) + Vector2(-dist, 0), 0)
			if dist >= float(ev["portee"]):
				continue
			rayons.append(float(Percep.ecouter(ev, bot, _monde, rng)["rayon"]))
		var croit := rayons.size() >= 2
		for k in range(1, rayons.size()):
			if rayons[k] < rayons[k - 1] - 0.001:
				croit = false
		_check("%s : le rayon de la zone ne diminue jamais avec la distance, et finit plus large qu'il n'a commencé (%s)" % [famille, str(rayons)],
			croit and rayons[rayons.size() - 1] > rayons[0] * 1.2)
	# La famille compte : un tir se situe mieux qu'un pas, à distance égale.
	var tir_800 := Percep.ecouter(_evenement("shoot", c(20, 15) + Vector2(-800, 0), 0), bot, _monde, rng)
	var pas_800 := Percep.ecouter(_evenement("footstep", c(20, 15) + Vector2(-800, 0), 0), bot, _monde, rng)
	var douille_800 := Percep.ecouter(_evenement("shell", c(20, 15) + Vector2(-800, 0), 0), bot, _monde, rng)
	_check("à 800 px, un tir se situe mieux qu'un pas (zone de %.0f px contre %.0f)" % [float(tir_800["rayon"]), float(pas_800["rayon"])],
		float(tir_800["rayon"]) < float(pas_800["rayon"]))
	_check("… et mieux qu'une douille (%.0f px)" % float(douille_800["rayon"]), float(tir_800["rayon"]) < float(douille_800["rayon"]))
	# Le tir reste net partout (largeur 10°), le pas se brouille à bout de portée.
	_check("un tir tout près et à 1 500 px : la même largeur, la plus fine du jeu (10°)",
		is_equal_approx(float(Percep.ecouter(_evenement("shoot", c(20, 15) + Vector2(-200, 0), 0), bot, _monde, rng)["largeur"]), Son.LARGEUR_MIN_DEG)
		and float(Percep.ecouter(tir_loin, bot, _monde, rng)["largeur"]) < 12.0)

	# Un mur étouffe — et la zone s'élargit. Source de l'autre côté de la paroi pleine.
	var de_l_autre_cote := c(30, 15)
	var sans_mur := Percep.monde_de_la_carte(_carte_sans_mur())
	var pas_mur := _evenement("footstep", de_l_autre_cote, 0)
	var libre := Percep.ecouter(pas_mur, bot, sans_mur, rng)
	var etouffe := Percep.ecouter(pas_mur, bot, _monde, rng)
	_check("derrière une paroi pleine, le son est étouffé : la part occultée est 1 (contre 0 sans paroi)",
		is_equal_approx(float(etouffe["occultation"]), 1.0) and is_equal_approx(float(libre["occultation"]), 0.0), str([etouffe["occultation"], libre["occultation"]]))
	_check("… son niveau perçu baisse de 5 dB (le prix d'un mur, celui de l'audio)",
		is_equal_approx(float(libre["niveau_percu"]) - float(etouffe["niveau_percu"]), 5.0), str([libre["niveau_percu"], etouffe["niveau_percu"]]))
	_check("… et sa zone s'élargit : %.0f px contre %.0f sans mur" % [float(etouffe["rayon"]), float(libre["rayon"])],
		float(etouffe["rayon"]) > float(libre["rayon"]) * 1.2)
	_check("l'occlusion est calculée depuis la place du BOT : le même son, le bot de l'autre côté de la paroi, n'est plus étouffé",
		is_equal_approx(float(Percep.ecouter(pas_mur, {"position": c(29, 15) + Vector2(0, 0), "id": 1}, _monde, rng)["occultation"]), 0.0))
	_check("un son plus proche que 48 px n'est jamais occulté (« un son à bout portant ne peut pas être occulté »)",
		Percep.part_occultee(c(25, 15), c(25, 15) + Vector2(40, 0), _monde) == 0.0)
	var fumee := Percep.ecouter(_evenement("footstep", c(30, 5), 0, -3.0), bot, _monde, rng)
	var sans_fumee := Percep.ecouter(_evenement("footstep", c(30, 5), 0, 0.0), bot, _monde, rng)
	_check("la fumée au point source (−3 dB) baisse le niveau perçu et élargit la zone",
		float(fumee["niveau_percu"]) < float(sans_fumee["niveau_percu"]) and float(fumee["rayon"]) >= float(sans_fumee["rayon"]))

	# La précision de l'oreille resserre la zone : à 800 px, le facteur 2 divise le rayon par deux.
	var ev_800 := _evenement("footstep", c(20, 15) + Vector2(-800, 0), 0)
	var r1 := float(Percep.ecouter(ev_800, bot, _monde, rng, 1.0)["rayon"])
	var r2 := float(Percep.ecouter(ev_800, bot, _monde, rng, 2.0)["rayon"])
	var rm := float(Percep.ecouter(ev_800, bot, _monde, rng, 0.5)["rayon"])
	_check("une oreille deux fois plus précise donne une zone moitié moindre (%.0f → %.0f px)" % [r1, r2], absf(r2 - r1 * 0.5) < 0.01)
	_check("… une oreille deux fois moins précise la double (%.0f px)" % rm, absf(rm - r1 * 2.0) < 0.01)
	var jamais_exact := true
	for i in 200:
		var zp := Percep.ecouter(pas_a_100, bot, _monde, rng, 4.0)
		if float(zp["rayon"]) < Percep.RAYON_ZONE_MIN or (zp["centre"] as Vector2).is_equal_approx(pas_a_100["pos"]):
			jamais_exact = false
	_check("quelle que soit la précision (×4), le rayon ne descend pas sous le plancher et le centre n'est jamais la vérité", jamais_exact)

	# Même graine, mêmes tirages ; une autre graine, d'autres.
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	var d2 := RandomNumberGenerator.new()
	a.seed = 5
	b.seed = 5
	d2.seed = 6
	var meme := true
	var autre := false
	for i in 50:
		var za := Percep.ecouter(ev_800, bot, _monde, a)
		var zb := Percep.ecouter(ev_800, bot, _monde, b)
		var zd := Percep.ecouter(ev_800, bot, _monde, d2)
		if not (za["centre"] as Vector2).is_equal_approx(zb["centre"]) or not is_equal_approx(float(za["rayon"]), float(zb["rayon"])):
			meme = false
		if not (za["centre"] as Vector2).is_equal_approx(zd["centre"]):
			autre = true
	_check("même graine, mêmes tirages (50 zones identiques)", meme)
	_check("une autre graine, d'autres tirages", autre)

	# Rien d'inventé : sans événement valable, rien.
	_check("un événement sans portée ne s'entend pas", Percep.ecouter({"famille": "footstep", "pos": c(21, 15), "emetteur": 0, "niveau_db": -13.0}, bot, _monde, rng).is_empty())
	_check("un son trop faible pour être perçu (sous le seuil) ne s'entend pas",
		Percep.ecouter({"famille": "footstep", "pos": c(21, 15), "emetteur": 0, "niveau_db": -40.0, "portee": 1700.0}, bot, _monde, rng).is_empty())


# ---------------------------------------------------------------------------
# LA MÉMOIRE
# ---------------------------------------------------------------------------

func _la_memoire() -> void:
	print("\n[La mémoire]")
	var m := Memoire.new(6.0)
	_check("sans trace, le bot ne se souvient de rien", not m.connue(0.0) and m.confiance(0.0) == 0.0 and m.source == Memoire.Source.AUCUNE)
	m.noter_vue(Vector2(100, 200), 10.0)
	_check("une vue : position précise, rayon nul, confiance pleine à l'instant", m.position == Vector2(100, 200) and m.rayon == 0.0 and is_equal_approx(m.confiance(10.0), 1.0))
	_check("la confiance s'efface : la moitié au bout de la moitié du délai", is_equal_approx(m.confiance(13.0), 0.5))
	_check("… et zéro au bout du délai : la trace est oubliée", m.confiance(16.0) == 0.0 and not m.connue(16.0))
	_check("… elle ne revient pas (confiance bornée)", m.confiance(40.0) == 0.0)
	_check("l'âge de la trace court depuis son instant", is_equal_approx(m.age(12.5), 2.5))
	_check("le rayon de la trace GRANDIT avec l'âge (l'adversaire a pu bouger)", m.rayon_a(12.0) > m.rayon_a(10.0) and is_equal_approx(m.rayon_a(11.0), Memoire.CROISSANCE_PX_S))

	var o := Memoire.new(6.0)
	o.noter_son(Vector2(300, 300), 80.0, 5.0)
	_check("un son : une ZONE (centre et rayon), pas une position", o.source == Memoire.Source.OUIE and o.rayon == 80.0)
	o.noter_son(Vector2(500, 500), 40.0, 5.5)
	_check("un son plus net remplace la trace", o.position == Vector2(500, 500) and o.rayon == 40.0)
	o.noter_son(Vector2(900, 900), 200.0, 6.0)
	_check("un son plus VAGUE que la trace du moment ne la remplace pas", o.position == Vector2(500, 500))
	o.noter_son(Vector2(900, 900), 200.0, 8.5)
	_check("… mais remplace une trace qui s'est elle-même élargie avec l'âge (le rayon de 40 est passé à 220 en 3 s)", o.position == Vector2(900, 900))

	var v := Memoire.new(6.0)
	v.noter_vue(Vector2(1, 1), 0.0)
	v.noter_son(Vector2(2, 2), 60.0, 0.1)
	_check("un son vague après une vue toute fraîche ne l'efface pas", v.source == Memoire.Source.VUE and v.position == Vector2(1, 1))
	v.noter_son(Vector2(2, 2), 60.0, 7.0)
	_check("un son après l'oubli complet : il devient la trace", v.source == Memoire.Source.OUIE and v.position == Vector2(2, 2))
	v.noter_vue(Vector2(3, 3), 7.5)
	_check("une vue remplace toujours la trace", v.source == Memoire.Source.VUE and v.position == Vector2(3, 3) and v.rayon == 0.0)
	v.oublier()
	_check("oublier efface tout", not v.connue(7.5) and v.source == Memoire.Source.AUCUNE)
	_check("un délai d'oubli plus long garde la confiance plus longtemps",
		Memoire.new(20.0).confiance(0.0) == 0.0
		and _confiance_apres(20.0, 6.0) > _confiance_apres(6.0, 6.0))


func _confiance_apres(delai: float, age: float) -> float:
	var m := Memoire.new(delai)
	m.noter_vue(Vector2.ZERO, 0.0)
	return m.confiance(age)


# ---------------------------------------------------------------------------
# L'OCCLUSION DU SON, CONTRE LE MOTEUR
# ---------------------------------------------------------------------------

## `AudioManager.part_occultee_entre` pose trois rayons sur le vrai espace de physique : le modèle sans physique doit rendre la
## même part, source par source, sur une carte où les murs sont de vraies formes de collision.
func _l_occlusion_du_son_contre_le_moteur() -> void:
	print("\n[L'occlusion d'un son : le modèle contre les trois rayons de l'audio]")
	var audio: Node = root.get_node("AudioManager")
	var espace := PhysicsServer2D.space_create()
	PhysicsServer2D.space_set_active(espace, true)
	var corps := PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_mode(corps, PhysicsServer2D.BODY_MODE_STATIC)
	PhysicsServer2D.body_set_space(corps, espace)
	PhysicsServer2D.body_set_collision_layer(corps, Geometrie.WALL_LAYER)
	var formes: Array[RID] = []
	for r: Rect2 in Geometrie.rects_monde(_data, Geometrie.Kind.WALLS):
		var forme := PhysicsServer2D.rectangle_shape_create()
		PhysicsServer2D.shape_set_data(forme, r.size * 0.5)
		PhysicsServer2D.body_add_shape(corps, forme, Transform2D(0.0, r.get_center()))
		formes.append(forme)
	await physics_frame
	await physics_frame
	var etat := PhysicsServer2D.space_get_direct_state(espace)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var accords := 0
	var desaccords := 0
	var plus_prudents := 0
	var premier := ""
	for _i in 400:
		var a := Vector2(rng.randf_range(600.0, 1300.0), rng.randf_range(100.0, 950.0))
		var b := Vector2(rng.randf_range(600.0, 1300.0), rng.randf_range(100.0, 950.0))
		var moteur := float(audio.call("part_occultee_entre", etat, a, b))
		var modele := Percep.part_occultee(a, b, _monde)
		# Un rayon qui PART d'un mur : le moteur ne le voit pas (un rayon ne frappe pas la forme dont il sort), le modèle le
		# compte arrêté — du côté du noir, il étouffe davantage, jamais moins. Là seulement l'égalité devient une inégalité.
		var perp := (b - a).orthogonal().normalized() * Percep.OCCLUSION_ECART_LATERAL
		var part_d_un_mur := false
		for decalage in [Vector2.ZERO, perp, -perp]:
			for point in [a + decalage, b + decalage]:
				var cellule := Vector2i(floori(point.x / TUILE), floori(point.y / TUILE))
				if Percep.mur_a(_monde, cellule):
					part_d_un_mur = true
		if is_equal_approx(moteur, modele) or (part_d_un_mur and modele >= moteur - 0.001):
			accords += 1
			if part_d_un_mur and not is_equal_approx(moteur, modele):
				plus_prudents += 1
		else:
			desaccords += 1
			if premier == "":
				premier = "%s → %s : moteur %.2f, modèle %.2f" % [a, b, moteur, modele]
	for f in formes:
		PhysicsServer2D.free_rid(f)
	PhysicsServer2D.free_rid(corps)
	PhysicsServer2D.free_rid(espace)
	_check("la part occultée du modèle = celle du moteur audio sur 400 couples, hors rayons partis d'un mur (%d accords, dont %d où le modèle étouffe PLUS)"
		% [accords, plus_prudents], desaccords == 0, premier)
	_check("(la table des constantes audio est celle du modèle : 24 px d'écart, 48 px de seuil)",
		is_equal_approx(float(audio.get_script().get_script_constant_map()["OCCLUSION_ECART_LATERAL"]), Percep.OCCLUSION_ECART_LATERAL)
		and is_equal_approx(float(audio.get_script().get_script_constant_map()["OCCLUSION_DISTANCE_MIN"]), Percep.OCCLUSION_DISTANCE_MIN))


# ---------------------------------------------------------------------------
# LE NŒUD, sur des corps factices
# ---------------------------------------------------------------------------

## Un joueur factice : juste ce que le nœud lit. Les lumières sont de vraies `PointLight2D`.
class FauxJoueur extends Node2D:
	var player_id := 0
	var accroupi := false
	var dead := false
	var speed := 260.0
	var current_weapon: WeaponData = null
	var flashlight := PointLight2D.new()
	var ambient_light := PointLight2D.new()
	var muzzle_flash := PointLight2D.new()

	func _init(id: int, arme: WeaponData) -> void:
		player_id = id
		current_weapon = arme
		name = "Faux%d" % id
		flashlight.enabled = false
		flashlight.energy = 2.5
		muzzle_flash.enabled = false
		ambient_light.enabled = true
		ambient_light.energy = 0.8
		for l in [flashlight, ambient_light, muzzle_flash]:
			add_child(l)
		LightTextures.poser(ambient_light, LightTextures.AMBIANTE, LightTextures.EMPREINTE_AMBIANTE)
		LightTextures.poser(muzzle_flash, LightTextures.FLASH[0], LightTextures.EMPREINTE_FLASH)

	func _ready() -> void:
		add_to_group("players")

	func allumer_la_torche(vers: Vector2) -> void:
		rotation = vers.angle()
		flashlight.position = Vector2(16.1, -4.55)
		flashlight.enabled = true
		flashlight.energy = 2.5


## Une fusée factice : l'interface que le nœud lit.
class FausseFusee extends Node2D:
	var allumee := true
	var energie := 1.0
	var halo := PointLight2D.new()

	func _init() -> void:
		halo.name = "Halo"
		add_child(halo)
		LightTextures.poser(halo, LightTextures.RETRODIFFUSION, 440.0)
		halo.enabled = true
		halo.energy = 3.0

	func _ready() -> void:
		add_to_group("fusees")

	func est_allumee_au_sol() -> bool:
		return allumee

	func energie_relative() -> float:
		return energie


## Un gadget factice qui bouche la lumière.
class FauxGadget extends Node2D:
	var occulte_la_lumiere := true

	func _ready() -> void:
		add_to_group("gadgets")


func _le_noeud() -> void:
	print("\n[Le nœud, sur des corps factices]")
	var scene := Node2D.new()
	scene.name = "ScenePerception"
	root.add_child(scene)
	var bot_corps := FauxJoueur.new(1, _arme)
	var adversaire := FauxJoueur.new(0, _arme)
	scene.add_child(bot_corps)
	scene.add_child(adversaire)
	bot_corps.global_position = c(20, 15)
	adversaire.global_position = c(23, 15)
	adversaire.rotation = PI

	var profil := Profil.new()
	profil.voit = true
	profil.entend = true
	var noeud := Noeud.new()
	noeud.configurer(profil, _data, bot_corps, 11)
	bot_corps.add_child(noeud)
	await physics_frame
	await physics_frame

	_check("le nœud pose ses lumières à la création : le halo du bot, au moins", noeud.noms_des_lumieres.has("halo_du_bot"), str(noeud.noms_des_lumieres))
	_check("la torche du bot éteinte et l'adversaire dans le noir, à 105 px : le halo de proximité (75 px × 0,6 = 45) ne l'atteint pas — rien n'est vu",
		not bool(noeud.derniere_vue["vu"]) and not noeud.memoire.connue(noeud._t))

	# Une lampe allumée en face : « la torche trahit ».
	adversaire.allumer_la_torche(Vector2.LEFT)
	await physics_frame
	await physics_frame
	_check("la lampe de l'adversaire s'allume, en ligne de vue : le bot le voit", bool(noeud.derniere_vue["vu"]) and (noeud.derniere_vue["par"] as Array).has("lampe_de_la_cible"), str(noeud.derniere_vue))
	_check("… et s'en souvient : une trace de VUE, confiance pleine", noeud.memoire.source == Memoire.Source.VUE and noeud.memoire.confiance(noeud._t) > 0.95)
	_check("… la place gardée est celle de la lampe (à moins de 20 px du corps), pas une position tirée du monde",
		noeud.memoire.position.distance_to(adversaire.global_position) < 20.0)
	# Elle s'éteint : la trace s'efface avec le temps.
	adversaire.flashlight.enabled = false
	var t0: float = noeud._t
	for i in 60:
		await physics_frame
	_check("sa lampe éteinte, le bot ne le voit plus", not bool(noeud.derniere_vue["vu"]))
	_check("… la trace qu'il en garde a vieilli (confiance entre 0 et 1 après une seconde)",
		noeud.memoire.confiance(noeud._t) < 1.0 and noeud.memoire.confiance(noeud._t) > 0.0 and noeud._t - t0 >= 0.9)

	# Mur entre eux : un bot derrière la paroi ne sait rien, torche allumée ou non.
	noeud.reinitialiser()
	adversaire.global_position = c(30, 15)
	adversaire.allumer_la_torche(Vector2.LEFT)
	for i in 6:
		await physics_frame
	_check("derrière la paroi pleine, la lampe allumée ne le trahit pas : le bot ne sait rien de lui",
		not bool(noeud.derniere_vue["vu"]) and not noeud.memoire.connue(noeud._t))
	# Un éclair de tir derrière la paroi : pas vu — mais le tir s'ENTEND.
	adversaire.flashlight.enabled = false
	adversaire.muzzle_flash.enabled = true
	adversaire.muzzle_flash.energy = 1.0
	adversaire.muzzle_flash.global_position = adversaire.global_position + Vector2(28, 0)
	for i in 4:
		await physics_frame
	_check("l'éclair de tir derrière une paroi : le bot ne le voit pas", not bool(noeud.derniere_vue["vu"]))
	var tir := _evenement("shoot", adversaire.global_position + Vector2(28, 0), 0)
	var avant: int = noeud.sons_entendus
	# Le VRAI signal de l'audio : le nœud s'y est abonné à sa création (`entend` vrai) et s'en désabonne en quittant l'arbre.
	var audio: Node = root.get_node("AudioManager")
	var abonnes_avant: int = audio.son_localise.get_connections().size()
	_check("le nœud est abonné à `AudioManager.son_localise`", noeud._abonne and abonnes_avant >= 1)
	audio.son_localise.emit(tir)
	_check("… et il entend ce que l'audio annonce : le tir émis par le VRAI signal lui parvient", noeud.sons_entendus == avant + 1)
	avant = noeud.sons_entendus
	noeud._sur_un_son(tir)
	_check("… mais le tir s'entend, étouffé : une zone, jamais la place", noeud.sons_entendus == avant + 1 and noeud.memoire.source == Memoire.Source.OUIE)
	_check("… et la zone gardée contient le tireur sans être sa place exacte",
		noeud.memoire.position.distance_to(tir["pos"]) <= noeud.memoire.rayon and not noeud.memoire.position.is_equal_approx(tir["pos"]))
	_check("… le nœud n'a gardé ni l'événement ni sa position (seulement la zone)",
		not noeud.zones_recentes.is_empty() and noeud.zones_recentes.all(func(z: Dictionary) -> bool: return not z.has("pos") and not z.has("position")))
	# Ses propres sons, sourd, mort.
	var propre := _evenement("footstep", bot_corps.global_position + Vector2(10, 0), 1)
	avant = noeud.sons_entendus
	noeud._sur_un_son(propre)
	_check("ses propres sons ne comptent pas, au niveau du nœud non plus", noeud.sons_entendus == avant)
	var sourd_profil := Profil.new()
	sourd_profil.voit = true
	var sourd := Noeud.new()
	sourd.configurer(sourd_profil, _data, bot_corps, 3)
	sourd._sur_un_son(tir)
	_check("un bot SOURD (`entend` faux) ne retient aucun son", sourd.sons_entendus == 0 and not sourd.memoire.connue(0.0))
	sourd.free()
	bot_corps.dead = true
	avant = noeud.sons_entendus
	noeud._sur_un_son(tir)
	_check("un bot mort n'entend rien", noeud.sons_entendus == avant)
	bot_corps.dead = false

	# La fusée posée : elle éclaire l'adversaire, que le bot voit si la ligne est dégagée.
	noeud.reinitialiser()
	adversaire.muzzle_flash.enabled = false
	adversaire.global_position = c(23, 12)
	var fusee := FausseFusee.new()
	scene.add_child(fusee)
	fusee.global_position = c(23, 14)
	for i in 6:
		await physics_frame
	_check("une fusée posée éclaire l'adversaire dans sa flaque : le bot le voit, par la fusée",
		bool(noeud.derniere_vue["vu"]) and (noeud.derniere_vue["par"] as Array).has("fusee"), str(noeud.derniere_vue))
	fusee.allumee = false
	for i in 4:
		await physics_frame
	_check("une fusée qui n'est plus allumée ne compte plus", not bool(noeud.derniere_vue["vu"]))
	fusee.allumee = true
	fusee.energie = 0.05
	for i in 4:
		await physics_frame
	_check("une fusée presque éteinte (énergie relative sous 0,1) ne compte pas", not bool(noeud.derniere_vue["vu"]))
	fusee.energie = 1.0

	# Un gadget qui bouche la lumière : le bot est aveugle, il entend toujours.
	var gadget := FauxGadget.new()
	scene.add_child(gadget)
	for i in 4:
		await physics_frame
	_check("sous un gadget qui bouche la lumière, le bot ne voit plus rien (il voit moins, jamais plus)", not bool(noeud.derniere_vue["vu"]) and bool(noeud.monde["aveugle"]))
	avant = noeud.sons_entendus
	noeud._sur_un_son(tir)
	_check("… mais il entend toujours", noeud.sons_entendus == avant + 1)
	gadget.free()
	for i in 4:
		await physics_frame
	_check("le gadget retiré, la vue revient", bool(noeud.derniere_vue["vu"]) and not bool(noeud.monde["aveugle"]))

	# L'adversaire hors jeu (la cible immobile masquée) : rien.
	adversaire.hide()
	for i in 4:
		await physics_frame
	_check("un adversaire masqué (hors jeu) n'existe pas pour le bot", not bool(noeud.derniere_vue["vu"]))
	adversaire.show()

	# La torche du bot : un cône, avec l'arme réelle.
	noeud.reinitialiser()
	fusee.free()
	adversaire.global_position = c(24, 15)
	bot_corps.rotation = 0.0
	bot_corps.flashlight.position = Vector2(16.1, -4.55)
	bot_corps.flashlight.enabled = true
	bot_corps.flashlight.energy = 2.5
	for i in 6:
		await physics_frame
	_check("la torche du bot allumée, l'adversaire dans le cône : vu, par la torche du bot",
		bool(noeud.derniere_vue["vu"]) and (noeud.derniere_vue["par"] as Array).has("torche_du_bot"), str(noeud.derniere_vue))
	bot_corps.flashlight.energy = 0.5
	for i in 4:
		await physics_frame
	_check("une torche presque éteinte (énergie sous 40 %) ne compte pas : le cône sort de la liste", not noeud.noms_des_lumieres.has("torche_du_bot"))
	bot_corps.flashlight.enabled = false
	bot_corps.flashlight.energy = 2.5

	# L'honnêteté de bout en bout : la mémoire ne contient la place de l'adversaire que si le modèle l'a VU ou ENTENDU.
	noeud.reinitialiser()
	adversaire.global_position = c(30, 5)
	adversaire.flashlight.enabled = false
	for i in 30:
		await physics_frame
	_check("un adversaire dans le noir, à l'écart, silencieux : la mémoire du bot est vide", not noeud.memoire.connue(noeud._t) and noeud.memoire.source == Memoire.Source.AUCUNE)
	scene.queue_free()
	await process_frame
	await process_frame
	_check("le nœud libéré se désabonne du signal de l'audio (plus aucun abonné de plus qu'avant lui)",
		audio.son_localise.get_connections().size() == abonnes_avant - 1, "%d abonnés avant, %d après" % [abonnes_avant,
			audio.son_localise.get_connections().size()])


# ---------------------------------------------------------------------------
# LE PROFIL ET LE FOURNISSEUR
# ---------------------------------------------------------------------------

func _le_profil_et_le_fournisseur() -> void:
	print("\n[Le profil, et le fournisseur d'entrées]")
	var p := Profil.new()
	_check("un profil neuf est sourd et aveugle", not p.voit and not p.entend)
	_check("la précision auditive par défaut est 1 (le liseré du joueur) et le délai d'oubli 6 s", p.precision_auditive == 1.0 and p.delai_oubli == 6.0)
	var mobile := Profil.pour_entrainement_mobile()
	_check("le profil du cran « adversaire mobile » de S1 est inchangé : LIBRE, allure 0,7, torche éteinte, sourd et aveugle",
		mobile.deplacement == Profil.Deplacement.LIBRE and is_equal_approx(mobile.allure, 0.7) and not mobile.torche_allumee
		and not mobile.voit and not mobile.entend)

	# Chaque champ de perception est LU par du code (« un champ que personne ne lit… »).
	var noeud_txt := FileAccess.get_file_as_string("res://perception_bot_noeud.gd")
	var provider_txt := FileAccess.get_file_as_string("res://bot_input_provider.gd")
	var memo_txt := FileAccess.get_file_as_string("res://memoire_bot.gd")
	_check("`voit` est lu par le nœud", noeud_txt.contains("profil.voit"))
	_check("`entend` est lu par le nœud", noeud_txt.contains("profil.entend"))
	_check("`precision_auditive` est lue par le nœud", noeud_txt.contains("profil.precision_auditive"))
	_check("`delai_oubli` est lu à la création de la mémoire", noeud_txt.contains("profil.delai_oubli") and memo_txt.contains("delai_oubli"))
	_check("la hauteur d'une fusée posée recopiée dans le nœud est celle du rendu des murs bas",
		is_equal_approx(Noeud.HAUTEUR_FUSEE_AU_SOL_TUILES, float(load("res://murs_bas_rendu.gd").get_script_constant_map()["HAUTEUR_FUSEE_AU_SOL"])))

	# `avancer()` et `_decider()` n'utilisent JAMAIS la perception : ce que le bot fait de ce qu'il perçoit (S3) vit dans `_penser()`,
	# que seule la physique appelle — un profil qui n'agit pas (S1, S2) ne l'appelle pas du tout.
	var debut := provider_txt.find("func avancer(")
	var fin := provider_txt.find("\nfunc ", debut + 10)
	var corps_avancer := provider_txt.substr(debut, fin - debut)
	_check("`avancer()` ne lit rien de la perception (c'est `_penser()` qui la lit, depuis S3)", not corps_avancer.contains("perception"))
	var decide := provider_txt.find("func _decider(")
	var fin_d := provider_txt.find("\nfunc ", decide + 10)
	_check("`_decider()` non plus", not provider_txt.substr(decide, fin_d - decide).contains("perception"))

	# Monter le nœud ne change aucune cible du déplacement : même graine, mêmes cibles, avec ou sans perception.
	var data := _data
	var nav := Nav.depuis_carte(data)
	var sans := Bot.new()
	var avec := Bot.new()
	var profil_voyant := Profil.pour_entrainement_mobile()
	profil_voyant.voit = true
	profil_voyant.entend = true
	sans.configurer(Profil.pour_entrainement_mobile(), nav, 4242)
	avec.configurer(profil_voyant, nav, 4242)
	var corps_a := FauxJoueur.new(1, _arme)
	var corps_b := FauxJoueur.new(1, _arme)
	var scene := Node2D.new()
	root.add_child(scene)
	scene.add_child(corps_a)
	scene.add_child(corps_b)
	corps_a.add_child(sans)
	corps_b.add_child(avec)
	await process_frame
	var debogage_demande := DrapeauxDeLancement.present(Noeud.DRAPEAU_DEBOGAGE)
	if not debogage_demande:
		_check("un fournisseur au profil sourd et aveugle (S1) ne monte aucune perception", sans.perception == null)
	else:
		# Lancée sous `--perception-bot` : le drapeau monte le nœud même pour un bot sourd, sur une COPIE du profil qui voit et
		# entend — pour l'affichage seulement. Le profil du bot, lui, ne change pas.
		_check("sous `--perception-bot`, le fournisseur sourd monte quand même le nœud, sur une copie voyante du profil",
			sans.perception != null and sans.perception.profil != sans.profil and sans.perception.profil.voit
			and sans.perception.profil.entend and sans.perception.debogage)
		_check("… et le profil du bot reste sourd et aveugle", not sans.profil.voit and not sans.profil.entend)
	_check("un fournisseur dont le profil voit et entend en monte une, enfant de lui", avec.perception != null and avec.perception.get_parent() == avec)
	_check("… qui travaille sur le profil du bot et le corps qu'il pilote", avec.perception.profil == profil_voyant and avec.perception.corps == corps_b)
	var pos_a := c(10, 10)
	var pos_b := c(10, 10)
	var meme := true
	for i in 900:
		sans.avancer(PAS, pos_a)
		avec.avancer(PAS, pos_b)
		pos_a += sans.get_movement_vector() * 260.0 * PAS
		pos_b += avec.get_movement_vector() * 260.0 * PAS
		if not pos_a.is_equal_approx(pos_b):
			meme = false
			break
	_check("la perception montée ne change pas un pas du déplacement (même graine : 900 pas identiques)", meme, "%s contre %s" % [pos_a, pos_b])
	_check("le bot qui perçoit sans `agit` ne commande toujours que de la marche (ni tir, ni recharge, ni fusée)",
		not avec.is_shoot_pressed() and not avec.is_reload_pressed() and not avec.is_flare_pressed())
	avec.reinitialiser()
	_check("la réapparition (`reinitialiser`) efface la mémoire de la perception",
		not avec.perception.memoire.connue(0.0) and avec.perception.zones_recentes.is_empty())
	scene.queue_free()
	await process_frame
