## La garde du CHAPITRE 3 — chantier SOLO, étape S8 : chaque salle enseigne ce qu'elle dit.
##
## Le chapitre 3, « Les zones », est écrit dans `res://assets/solo/chapitre_03/` (par `tools/fabrique_chapitre_03.gd`). Plus de trajet à lire : chaque gardien erre dans une ZONE, un
## rectangle de cases qui contient sa case de départ, va voir d'où vient un bruit, et ne sort pas de chez lui. Cette suite mesure sur les données ce que chaque salle impose, avec les
## fonctions du jeu (`tools/outils_chapitre.gd` : `NavigationBot`, le modèle de vue du bot, la portée de la torche, l'ouïe réelle de l'audio).
##
## Partout (`OutilsChapitre.partout`) : taille, PNJ de chaque sorte, plafonniers, PNJ équipés (la classe du boss et sa torche fantôme, à partir de 3.7 — et un gardien équipé ENTEND, sans
## quoi la règle de la torche fantôme, qui se pose en enquête sur un son, ne se déclencherait jamais), chaque PNJ atteignable à pied, une seule pièce, aucun couloir d'une tuile, chaque
## zone contient son PNJ et assez de cases pour errer (au moins 16, toutes atteignables sans sortir de la zone), chaque ronde une boucle, le départ à l'abri. Puis salle par salle : 3.1 une
## pièce, une seule porte, une lampe qui n'en éclaire qu'une part ; 3.2 le joueur part hors de la zone, un chemin sort de la zone, la zone s'arrête au seuil ; 3.3 deux zones voisines,
## le couloir n'est dans aucune ; 3.4 aucune lampe : sans torche, aucun gardien ne voit rien, et la torche trahit ; 3.5 la ronde traverse les deux zones ; 3.6 le poste voit une bonne part
## des zones, devant elles ; 3.7 la lampe est au fond, le joueur au bout opposé, les gardiens entre les deux ; 3.8 le damier, quatre portes ; 3.9 quatre zones, une ronde entre elles ;
## 3.10 un duel en miroir.
##
## Sabotée salle par salle — la liste est dans la ROADMAP, S8. Pour saboter sans toucher aux fichiers livrés : `-- --dossier=<chemin absolu d'une copie du chapitre>`.
##
## Lancer : godot --headless --path . --script res://tools/test_chapitre_03.gd
extends SceneTree

const Outils := preload("res://tools/outils_chapitre.gd")
const Nav := preload("res://navigation_bot.gd")
const Profil := preload("res://profil_bot.gd")
const Codec := preload("res://map_codec.gd")
const Percep := preload("res://perception_bot.gd")

const DOSSIER_LIVRE := "res://assets/solo/chapitre_03"
const NUMERO := 3
const CLASSE := "arbalete"

const TABLE := [
	{"pnj": {"zone_voit_facile": 1}, "lampes": 1, "equipes": 0, "cotes": [20, 32]},
	{"pnj": {"zone_voit_facile": 1}, "lampes": 1, "equipes": 0, "cotes": [16, 36]},
	{"pnj": {"zone_voit_facile": 2}, "lampes": 2, "equipes": 0, "cotes": [16, 40]},
	{"pnj": {"zone_voit_facile": 2}, "lampes": 0, "equipes": 0, "cotes": [20, 32]},
	{"pnj": {"zone_voit_facile": 2, "ronde_voit_lent": 1}, "lampes": 2, "equipes": 0, "cotes": [20, 36]},
	{"pnj": {"immobile_voit_facile": 1, "zone_voit_facile": 2}, "lampes": 2, "equipes": 0, "cotes": [20, 36]},
	{"pnj": {"zone_voit_entend_facile": 3}, "lampes": 1, "equipes": 3, "cotes": [16, 50]},
	{"pnj": {"zone_voit_entend_facile": 4}, "lampes": 2, "equipes": 4, "cotes": [20, 32]},
	{"pnj": {"zone_voit_entend_facile": 4, "ronde_voit_entend_facile": 1}, "lampes": 3, "equipes": 5, "cotes": [34, 48]},
	{"pnj": {"boss": 1}, "lampes": 2, "equipes": 0, "cotes": [32, 32]},
]

var _failures := 0
var _verifications := 0
var o: Outils = null


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
	print("=== LE CHAPITRE 3 — LES ZONES (S8) ===")
	var dossier := DOSSIER_LIVRE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="):
			dossier = a.substr(10)
	o = Outils.new(Callable(self, "_check"))
	o.mesures_du_jeu(root)
	if not o.charger(dossier, NUMERO, "Les zones", CLASSE, 10):
		print("\n=== %d vérifications, %d échec(s) ===" % [_verifications, _failures])
		print("CRIS ATTENDUS: 0")
		quit(1)
		return
	o.partout(NUMERO, CLASSE, TABLE)
	_salle_1()
	_salle_2()
	_salle_3()
	_salle_4()
	_salle_5()
	_salle_6()
	_salle_7()
	_salle_8()
	_salle_9()
	o.salle_du_boss(9, NUMERO, CLASSE)
	print("\n=== %d vérifications, %d échec(s) ===" % [_verifications, _failures])
	print("CRIS ATTENDUS: 0")
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# DE PETITS OUTILS DE SALLE
# ---------------------------------------------------------------------------

func _zones(c: Dictionary) -> Array[int]:
	var sortie: Array[int] = []
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil"].deplacement == Profil.Deplacement.ZONE:
			sortie.append(k)
	return sortie


func _rect(c: Dictionary, k: int) -> Rect2i:
	return c["pnj"][k]["zone"]


## Les cases de la zone `k` qu'une lampe de la salle éclaire (le modèle de vue).
func _eclairees(c: Dictionary, k: int) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in (c["nav"] as Nav).cases_dans(_rect(c, k)):
		if o.eclaire_par_lampe(c, Nav.centre_de_la_case(cc)):
			sortie.append(cc)
	return sortie


## Les « portes » d'une zone : ses cases dont un voisin (4 voisins) est praticable et HORS de la zone — là où l'on entre chez le gardien.
func _portes(c: Dictionary, k: int) -> Array[Vector2i]:
	var nav: Nav = c["nav"]
	var zone := _rect(c, k)
	var sortie: Array[Vector2i] = []
	for cc in nav.cases_dans(zone):
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var n := cc + d
			if nav.est_praticable(n) and not zone.has_point(n):
				sortie.append(cc)
				break
	return sortie


func _dans_une_zone(c: Dictionary, cc: Vector2i) -> bool:
	for k in _zones(c):
		if _rect(c, k).has_point(cc):
			return true
	return false


## Les cases praticables qui ne sont dans AUCUNE zone.
func _hors_zones(c: Dictionary) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in (c["nav"] as Nav).cases_praticables():
		if not _dans_une_zone(c, cc):
			sortie.append(cc)
	return sortie


## La part des cases d'une zone qu'une position voit (ligne de vue, à moins de `rayon` px).
func _part_en_vue(c: Dictionary, pos: Vector2, k: int, rayon: float) -> float:
	var cases := (c["nav"] as Nav).cases_dans(_rect(c, k))
	var n := 0
	for cc in cases:
		var p := Nav.centre_de_la_case(cc)
		if p.distance_to(pos) <= rayon and o.ligne_de_vue(c, pos, p):
			n += 1
	return float(n) / float(maxi(cases.size(), 1))


func _composantes(cases: Array[Vector2i]) -> Array:
	var reste := {}
	for cc in cases:
		reste[cc] = true
	var sortie: Array = []
	for depart in cases:
		if not reste.has(depart):
			continue
		var morceau: Array[Vector2i] = []
		var pile: Array[Vector2i] = [depart]
		reste.erase(depart)
		while not pile.is_empty():
			var cc: Vector2i = pile.pop_back()
			morceau.append(cc)
			for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
				if reste.has(cc + d):
					reste.erase(cc + d)
					pile.append(cc + d)
		sortie.append(morceau)
	return sortie


# ---------------------------------------------------------------------------
# 3.1 — Une pièce gardée
# ---------------------------------------------------------------------------

func _salle_1() -> void:
	print("\n--- 3.1 Une pièce gardée : un PNJ qui erre sans trajet ---")
	var c := o.ctx(0)
	var k := _zones(c)[0]
	var zone := _rect(c, k)
	var cases := (c["nav"] as Nav).cases_dans(zone)
	_check("un gardien qui voit, aux réflexes FACILES, dans une zone (pas de trajet : aucun point de ronde), et un plafonnier",
		c["pnj"][k]["profil_nom"] == "zone_voit_facile" and (c["pnj"][k]["ronde"] as Array).is_empty() and (c["lampes"] as Array).size() == 1)
	_check("la zone est une pièce : %d cases praticables (au moins 100), assez pour y errer sans repasser par les mêmes" % cases.size(), cases.size() >= 100)
	var portes := _portes(c, k)
	_check("la pièce n'a qu'UNE porte : %d cases de la zone ouvrent sur l'extérieur, en un seul morceau (de 3 à 6)" % portes.size(), portes.size() >= 3 and portes.size() <= 6 and _composantes(portes).size() == 1)
	_check("le joueur part hors de la pièce, et il y a un chemin jusqu'au gardien : %d cases" % (c["nav"] as Nav).chemin(c["depart"], c["pnj"][k]["case"]).size(),
		not zone.has_point(c["depart"]) and not (c["nav"] as Nav).chemin(c["depart"], c["pnj"][k]["case"]).is_empty())
	var claires := _eclairees(c, k)
	_check("la lampe est dans la pièce et n'en éclaire qu'une part : %d cases éclairées sur %d (au moins 10, moins de la moitié)" % [claires.size(), cases.size()],
		zone.has_point(c["lampes"][0]["case"]) and claires.size() >= 10 and claires.size() * 2 < cases.size())
	var vues := 0
	for cc in cases:
		if o.ligne_de_vue(c, c["depart_pos"], Nav.centre_de_la_case(cc)):
			vues += 1
	_check("de l'entrée on voit par la porte une part de la pièce : %d cases en ligne de vue (au moins 10)" % vues, vues >= 10)


# ---------------------------------------------------------------------------
# 3.2 — La frontière
# ---------------------------------------------------------------------------

func _salle_2() -> void:
	print("\n--- 3.2 La frontière : il ne suit pas hors de sa zone ---")
	var c := o.ctx(1)
	var nav: Nav = c["nav"]
	var k := _zones(c)[0]
	var zone := _rect(c, k)
	var p: Dictionary = c["pnj"][k]
	_check("le joueur part dans la seconde pièce, HORS de la zone du gardien", not zone.has_point(c["depart"]) and zone.has_point(p["case"]))
	var chemin := nav.chemin(p["case"], c["depart"])
	var dehors := 0
	for cc in chemin:
		if not zone.has_point(cc):
			dehors += 1
	_check("un chemin sort de la zone : du gardien au départ, %d cases sur %d sont hors de la zone (au moins 10)" % [dehors, chemin.size()], dehors >= 10)
	var portes := _portes(c, k)
	_check("la zone s'arrête au seuil : une seule porte (%d cases), dont les cases ouvertes sont dans la zone et les cases d'en face dehors" % portes.size(),
		portes.size() >= 3 and portes.size() <= 6 and _composantes(portes).size() == 1)
	var atteignables := o.cases_de_la_zone_atteignables(c, k)
	var sort := false
	for cc in atteignables:
		sort = sort or not zone.has_point(cc)
	_check("le gardien ne quitte pas sa zone : les %d cases qu'il rejoint en restant dans la zone sont toutes dedans" % atteignables.size(), not sort and atteignables.size() >= 100)
	# On le voit, on est vu de lui de loin : depuis chez soi, par la porte, on voit la zone.
	var vues := 0
	for cc in nav.cases_dans(zone):
		if o.ligne_de_vue(c, c["depart_pos"], Nav.centre_de_la_case(cc)):
			vues += 1
	_check("on voit sa zone de chez soi, par la porte : %d cases en ligne de vue (au moins 20) — on y tire sans y entrer" % vues, vues >= 20)
	_check("la lampe est dans la zone, et le joueur, loin d'elle, dans le noir (%.0f px)" % c["depart_pos"].distance_to(c["lampes"][0]["pos"]),
		zone.has_point(c["lampes"][0]["case"]) and not o.sous_une_lampe(c, c["depart_pos"]))


# ---------------------------------------------------------------------------
# 3.3 — Deux pièces
# ---------------------------------------------------------------------------

func _salle_3() -> void:
	print("\n--- 3.3 Deux pièces : deux zones voisines ---")
	var c := o.ctx(2)
	var zs := _zones(c)
	var a := _rect(c, zs[0])
	var b := _rect(c, zs[1])
	_check("deux zones disjointes, chacune avec son gardien et pas celui de l'autre", not a.intersects(b) and a.has_point(c["pnj"][zs[0]]["case"]) and b.has_point(c["pnj"][zs[1]]["case"])
		and not a.has_point(c["pnj"][zs[1]]["case"]) and not b.has_point(c["pnj"][zs[0]]["case"]))
	var ecart := maxi(b.position.x - a.end.x, a.position.x - b.end.x)
	_check("voisines : %d cases entre les deux zones (au plus 12)" % ecart, ecart >= 1 and ecart <= 12)
	var couloir := _hors_zones(c)
	_check("le couloir qui les sépare n'est dans aucune zone : %d cases praticables hors de toute zone (au moins 30)" % couloir.size(), couloir.size() >= 30)
	var chemin := (c["nav"] as Nav).chemin(c["pnj"][zs[0]]["case"], c["pnj"][zs[1]]["case"])
	var par_le_couloir := 0
	for cc in chemin:
		if not _dans_une_zone(c, cc):
			par_le_couloir += 1
	_check("pour aller de l'un à l'autre on traverse le couloir : %d cases du chemin hors des deux zones (au moins 8)" % par_le_couloir, par_le_couloir >= 8)
	var lampes_bien := true
	for i in 2:
		var dedans := 0
		for l: Dictionary in c["lampes"]:
			if _rect(c, zs[i]).has_point(l["case"]):
				dedans += 1
		lampes_bien = lampes_bien and dedans == 1
	_check("une lampe dans chaque zone, et le couloir est dans le noir", lampes_bien and not o.sous_une_lampe(c, c["depart_pos"]))
	_check("le joueur part dans le couloir, hors des deux zones : %s" % str(c["depart"]), not _dans_une_zone(c, c["depart"]))


# ---------------------------------------------------------------------------
# 3.4 — La zone sombre
# ---------------------------------------------------------------------------

func _salle_4() -> void:
	print("\n--- 3.4 La zone sombre : une zone sans plafonnier ---")
	var c := o.ctx(3)
	var nav: Nav = c["nav"]
	_check("aucun plafonnier : toute la salle est dans le noir", (c["lampes"] as Array).is_empty())
	_check("un sous-sol à colonnes : au moins 5 piliers de 4 cases (%d cases de mur plein à l'intérieur)" % o.murs_interieurs(c), o.murs_interieurs(c) >= 20)
	var zs := _zones(c)
	# Sans lumière, aucun gardien ne voit un joueur debout, torche éteinte : aucune case de la salle, vue de la moindre case de sa zone, ne le trahit.
	var vu_dans_le_noir := 0
	var examinees := 0
	var trahi_par_la_torche := 0
	for k in zs:
		var zc := nav.cases_dans(_rect(c, k))
		for i in range(0, zc.size(), 3):
			var pos := Nav.centre_de_la_case(zc[i])
			var cibles := nav.cases_praticables()
			for j in range(0, cibles.size(), 5):
				var cible := Nav.centre_de_la_case(cibles[j])
				if pos.distance_to(cible) > 14.0 * 35.0 or not o.ligne_de_vue(c, pos, cible):
					continue
				examinees += 1
				if o.voit(c, pos, cible, []):
					vu_dans_le_noir += 1
				# La torche allumée du joueur est une lampe : elle le trahit à cette distance.
				if o.voit(c, pos, cible, [Percep.lumiere_lampe("lampe", cible, o.hauteur)]):
					trahi_par_la_torche += 1
	_check("torche éteinte, un joueur debout n'est vu d'AUCUN gardien, de nulle part de sa zone : %d paires examinées, %d trahies" % [examinees, vu_dans_le_noir], examinees >= 500 and vu_dans_le_noir == 0)
	_check("… mais une torche allumée le trahit : %d paires sur %d où le gardien voit sa lampe" % [trahi_par_la_torche, examinees], trahi_par_la_torche >= 100)
	_check("deux zones disjointes qui ne contiennent pas le départ", not _rect(c, zs[0]).intersects(_rect(c, zs[1])) and not _dans_une_zone(c, c["depart"]))


# ---------------------------------------------------------------------------
# 3.5 — Zones et rondes
# ---------------------------------------------------------------------------

func _salle_5() -> void:
	print("\n--- 3.5 Zones et rondes : mélanger les deux lectures ---")
	var c := o.ctx(4)
	var zs := _zones(c)
	var ronde := -1
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil"].deplacement == Profil.Deplacement.RONDE:
			ronde = k
	var tour := o.tour_de_la_ronde(c, ronde)
	_check("deux gardiens en zone et une ronde qui voit, aux réflexes lents", zs.size() == 2 and ronde >= 0 and c["pnj"][ronde]["profil_nom"] == "ronde_voit_lent")
	_check("deux zones disjointes", not _rect(c, zs[0]).intersects(_rect(c, zs[1])))
	for i in 2:
		var dedans := 0
		for cc in tour:
			if _rect(c, zs[i]).has_point(cc):
				dedans += 1
		_check("la ronde passe dans la zone %d : %d cases de son tour y sont (au moins 4)" % [i + 1, dedans], dedans >= 4)
	var dehors := 0
	for cc in tour:
		if not _dans_une_zone(c, cc):
			dehors += 1
	_check("… mais la plus grande part du tour est hors des zones : %d cases sur %d (au moins la moitié)" % [dehors, tour.size()], dehors * 2 >= tour.size())
	for l: Dictionary in c["lampes"]:
		var sur_le_tour := false
		for cc in tour:
			sur_le_tour = sur_le_tour or (Nav.centre_de_la_case(cc).distance_to(l["pos"]) <= 70.0 and _dans_une_zone(c, cc))
		_check("la lampe %s éclaire le tour DANS une zone : ronde et gardien s'y croisent sous la lumière" % str(l["case"]), sur_le_tour)
	var distance := o.distance_au_tour(c["depart_pos"], tour)
	_check("le départ est hors des zones et à %.0f px du tour de la ronde (plus de 6 cases)" % distance, not _dans_une_zone(c, c["depart"]) and distance > 6.0 * 35.0)
	_check("un atelier : un bloc central, la ronde en fait le tour", o.murs_interieurs(c) >= 40)


# ---------------------------------------------------------------------------
# 3.6 — Le poste avancé
# ---------------------------------------------------------------------------

func _salle_6() -> void:
	print("\n--- 3.6 Le poste avancé : un immobile couvre une zone ---")
	var c := o.ctx(5)
	var zs := _zones(c)
	var poste := -1
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil"].deplacement == Profil.Deplacement.IMMOBILE:
			poste = k
	var s: Dictionary = c["pnj"][poste]
	_check("un poste immobile qui voit, aux réflexes FACILES, et deux gardiens en zone", s["profil_nom"] == "immobile_voit_facile" and zs.size() == 2)
	_check("un hall à colonnes : au moins 6 piliers de 4 cases (%d cases de mur plein à l'intérieur)" % o.murs_interieurs(c), o.murs_interieurs(c) >= 24)
	# Le poste est AVANCÉ : plus près du départ que toute case des zones.
	var plus_pres_zone := INF
	for k in zs:
		for cc in (c["nav"] as Nav).cases_dans(_rect(c, k)):
			plus_pres_zone = minf(plus_pres_zone, Nav.centre_de_la_case(cc).distance_to(c["depart_pos"]))
	_check("le poste est avancé : à %.0f px du départ, la zone la plus proche à %.0f px" % [s["pos"].distance_to(c["depart_pos"]), plus_pres_zone], s["pos"].distance_to(c["depart_pos"]) < plus_pres_zone)
	# Il couvre les zones : une bonne part de leurs cases sont dans son champ (ligne de vue, moins de 18 cases).
	for k in zs:
		var part := _part_en_vue(c, s["pos"], k, 18.0 * 35.0)
		_check("le poste couvre la zone %d : %.0f %% de ses cases sont dans son champ (ligne de vue, moins de 18 cases ; au moins 30 %%)" % [k, 100.0 * part], part >= 0.3)
	_check("le poste est sous la lampe : on le voit de loin, il ne voit que ce qui est éclairé", o.eclaire_par_lampe(c, s["pos"]))
	_check("une seconde lampe éclaire la voie du milieu, entre les deux zones (hors des deux)", not _dans_une_zone(c, Nav.case_du_monde(c["lampes"][1]["pos"])))
	_check("deux zones disjointes, qui ne contiennent pas le départ", not _rect(c, zs[0]).intersects(_rect(c, zs[1])) and not _dans_une_zone(c, c["depart"]))


# ---------------------------------------------------------------------------
# 3.7 — La lumière qui ment
# ---------------------------------------------------------------------------

func _salle_7() -> void:
	print("\n--- 3.7 La lumière qui ment : une lampe au loin n'est pas un joueur ---")
	var c := o.ctx(6)
	var taille: Vector2i = c["taille"]
	var zs := _zones(c)
	var lampe: Vector2 = c["lampes"][0]["pos"]
	_check("un long hangar : au moins 40 cases de long (%d)" % taille.x, taille.x >= 40)
	var d: float = c["depart_pos"].distance_to(lampe)
	_check("la lampe est tout au fond : à %.0f px du départ (plus de 25 cases)" % d, d > 25.0 * 35.0)
	_check("… et on la voit de là où l'on est : ligne de vue libre jusqu'à elle, bien au-delà de la torche (%.0f px)" % o.portee_torche, o.ligne_de_vue(c, c["depart_pos"], lampe) and d > o.portee_torche)
	# Trois zones qui se partagent la longueur, dans l'ordre, entre le départ et la lampe.
	var xs: Array[int] = []
	var entre := true
	for k in zs:
		xs.append((c["pnj"][k]["case"] as Vector2i).x)
		entre = entre and c["pnj"][k]["pos"].x > c["depart_pos"].x and c["pnj"][k]["pos"].x < lampe.x
	_check("trois gardiens (x = %s), tous ENTRE le joueur et la lampe : elle est derrière eux" % str(xs), zs.size() == 3 and entre)
	var disjointes := true
	for i in 3:
		for j in range(i + 1, 3):
			disjointes = disjointes and not _rect(c, zs[i]).intersects(_rect(c, zs[j]))
	_check("trois zones disjointes, rangées d'ouest en est ; le départ n'est dans aucune", disjointes and not _dans_une_zone(c, c["depart"]) and xs[0] < xs[1] and xs[1] < xs[2])
	_check("la lampe est dans la dernière zone (celle du gardien qui la garde)", _rect(c, zs[2]).has_point(c["lampes"][0]["case"]))
	# La règle de la torche fantôme (`EquipementBot.GADGETS`) : en enquête sur un son, la place visée à 250-450 px, une ligne dégagée — chaque gardien en a la place.
	for k in zs:
		var peut := false
		for cc in (c["nav"] as Nav).cases_dans(_rect(c, k)):
			var pos := Nav.centre_de_la_case(cc)
			for cible in [c["depart"], Vector2i(taille.x / 2, taille.y / 2)]:
				var dd: float = pos.distance_to(Nav.centre_de_la_case(cible))
				if dd >= 250.0 and dd <= 450.0 and Percep.segment_degage(pos, Nav.centre_de_la_case(cible), c["monde"]):
					peut = true
		_check("gardien %d : un point de sa zone d'où la torche fantôme se pose à 250-450 px d'un son, ligne dégagée — la règle du Braconnier peut se déclencher" % (k + 1), peut)


# ---------------------------------------------------------------------------
# 3.8 — Les quartiers
# ---------------------------------------------------------------------------

func _salle_8() -> void:
	print("\n--- 3.8 Les quartiers : quatre zones en damier ---")
	var c := o.ctx(7)
	var zs := _zones(c)
	_check("quatre gardiens, chacun dans sa zone", zs.size() == 4)
	var disjointes := true
	var un_seul := true
	for i in 4:
		var n := 0
		for k in zs:
			if _rect(c, zs[i]).has_point(c["pnj"][k]["case"]):
				n += 1
		un_seul = un_seul and n == 1
		for j in range(i + 1, 4):
			disjointes = disjointes and not _rect(c, zs[i]).intersects(_rect(c, zs[j]))
	_check("quatre zones disjointes, chacune avec UN seul gardien", disjointes and un_seul)
	# Un damier : deux rangées de deux, les zones des mêmes lignes à la même hauteur.
	var xs := {}
	var ys := {}
	for k in zs:
		xs[_rect(c, k).position.x] = true
		ys[_rect(c, k).position.y] = true
	_check("en damier : deux colonnes et deux rangées de zones (x : %s, y : %s)" % [str(xs.keys()), str(ys.keys())], xs.size() == 2 and ys.size() == 2)
	# Les lampes aux deux pièces opposées : deux zones éclairées, jamais voisines ; les deux autres sont noires.
	var eclairees: Array[int] = []
	for i in 4:
		if not _eclairees(c, zs[i]).is_empty():
			eclairees.append(i)
	var opposees := eclairees.size() == 2 and (_rect(c, zs[eclairees[0]]).position.x != _rect(c, zs[eclairees[1]]).position.x) and (_rect(c, zs[eclairees[0]]).position.y != _rect(c, zs[eclairees[1]]).position.y)
	_check("deux lampes, aux deux pièces OPPOSÉES du damier (zones éclairées : %s) ; les deux autres restent noires" % str(eclairees), opposees)
	# Quatre portes : les cases hors de toute zone forment quatre morceaux (les seuils), chacun de 6 cases ou plus.
	var seuils := _composantes(_hors_zones(c))
	var assez_larges := true
	for m in seuils:
		assez_larges = assez_larges and (m as Array).size() >= 6
	_check("quatre portes : %d seuils hors de toute zone, chacun d'au moins 6 cases" % seuils.size(), seuils.size() == 4 and assez_larges)
	for i in 4:
		_check("la zone %d a deux portes (%d cases ouvertes, en %d morceaux)" % [i + 1, _portes(c, zs[i]).size(), _composantes(_portes(c, zs[i])).size()], _composantes(_portes(c, zs[i])).size() == 2)
	_check("le joueur part dans un seuil, hors de toute zone", not _dans_une_zone(c, c["depart"]))


# ---------------------------------------------------------------------------
# 3.9 — La salle pleine
# ---------------------------------------------------------------------------

func _salle_9() -> void:
	print("\n--- 3.9 La salle pleine : toutes les zones à la fois ---")
	var c := o.ctx(8)
	var zs := _zones(c)
	var ronde := -1
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil"].deplacement == Profil.Deplacement.RONDE:
			ronde = k
	_check("quatre gardiens équipés du Braconnier, chacun sa zone, et une ronde équipée", zs.size() == 4 and ronde >= 0)
	var disjointes := true
	var vastes := true
	for i in 4:
		vastes = vastes and (c["nav"] as Nav).cases_dans(_rect(c, zs[i])).size() >= 150
		for j in range(i + 1, 4):
			disjointes = disjointes and not _rect(c, zs[i]).intersects(_rect(c, zs[j]))
	_check("quatre zones disjointes, de plus de 150 cases chacune", disjointes and vastes)
	var tour := o.tour_de_la_ronde(c, ronde)
	var dans := 0
	for cc in tour:
		if _dans_une_zone(c, cc):
			dans += 1
	_check("la ronde passe ENTRE les zones, dans la bande du milieu : aucune case de son tour dans une zone (%d)" % dans, dans == 0)
	_check("… un grand tour : %d cases (au moins 40), %.1f s" % [tour.size(), o.periode_de_la_ronde(tour)], tour.size() >= 40)
	_check("un grand entrepôt : des piliers, un bloc au milieu de la bande (%d cases de mur plein à l'intérieur)" % o.murs_interieurs(c), o.murs_interieurs(c) >= 32)
	_check("le joueur part entre les deux zones du sud, hors de toute zone, à %.0f px du tour" % o.distance_au_tour(c["depart_pos"], tour), not _dans_une_zone(c, c["depart"]))
	var eclairees := 0
	for l: Dictionary in c["lampes"]:
		var dans_zone := _dans_une_zone(c, l["case"])
		eclairees += 1 if dans_zone else 0
	_check("trois plafonniers : deux dans une zone, un sur le tour de la ronde (%d dans une zone)" % eclairees, (c["lampes"] as Array).size() == 3 and eclairees == 2)
