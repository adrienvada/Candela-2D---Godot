## La garde du CHAPITRE 2 — chantier SOLO, étape S8 : chaque salle enseigne ce qu'elle dit.
##
## Le chapitre 2, « Les rondes écoutent », est écrit dans `res://assets/solo/chapitre_02/` (par `tools/fabrique_chapitre_02.gd`). Ses rondes ENTENDENT : marcher, tirer,
## recharger devient un risque, et on apprend à se faire oublier — rester immobile, s'accroupir — puis à faire diversion. Cette suite mesure sur les données ce que chaque
## salle impose, avec les fonctions du jeu (`tools/outils_chapitre.gd`) — dont l'OUÏE réelle d'un PNJ : `PerceptionBot.ecouter` avec les niveaux et les portées de l'audio.
##
## Les portées d'écoute, mesurées au lancement : un pas debout donne une zone assez nette pour qu'un PNJ tire dessus (`ProfilBot.AUDACE_ZONE_PX`) jusqu'à ~495 px ; un pas
## ACCROUPI jusqu'à ~100 px seulement ; un tir jusqu'à ~1 200 px ; une douille jusqu'à ~250 px. Les salles se mesurent sur ces chiffres, jamais sur des distances écrites.
##
## Partout (`OutilsChapitre.partout`) : taille, PNJ de chaque sorte, plafonniers, PNJ équipés (la classe du boss et son leurre, à partir de 2.7), chaque PNJ atteignable à
## pied, une seule pièce, aucun couloir d'une tuile, chaque ronde une BOUCLE praticable, le départ à l'abri. Puis salle par salle : 2.1 un pas debout s'entend de partout, un
## pas accroupi pas, et une zone d'ombre existe où l'on passe en s'accroupissant ; 2.2 sol nu, tout s'entend ; 2.3 deux recoins que les murs isolent du trajet ; 2.4 deux
## salles reliées, la ronde qui voit sous les lampes, celle qui entend dans le noir ; 2.5 un T, les ailes noires ; 2.6 un tir tiré de loin s'entend des deux rondes et la
## galerie offre un poste hors de leur vue ; 2.7 des piliers, le leurre peut se poser ; 2.8 quatre tours qui se recouvrent ; 2.9 la salle pleine ; 2.10 un duel en miroir.
##
## Sabotée salle par salle — la liste est dans la ROADMAP, S8. Pour saboter sans toucher aux fichiers livrés : `-- --dossier=<chemin absolu d'une copie du chapitre>`.
##
## Lancer : godot --headless --path . --script res://tools/test_chapitre_02.gd
extends SceneTree

const Outils := preload("res://tools/outils_chapitre.gd")
const Nav := preload("res://navigation_bot.gd")
const Profil := preload("res://profil_bot.gd")
const Codec := preload("res://map_codec.gd")

const DOSSIER_LIVRE := "res://assets/solo/chapitre_02"
const NUMERO := 2
const CLASSE := "fusil"

const TABLE := [
	{"pnj": {"ronde_entend_lent": 1}, "lampes": 1, "equipes": 0, "cotes": [16, 32]},
	{"pnj": {"ronde_entend_lent": 2}, "lampes": 0, "equipes": 0, "cotes": [16, 28]},
	{"pnj": {"ronde_entend_lent": 2}, "lampes": 1, "equipes": 0, "cotes": [20, 32]},
	{"pnj": {"ronde_voit_lent": 1, "ronde_entend_lent": 1}, "lampes": 2, "equipes": 0, "cotes": [16, 36]},
	{"pnj": {"ronde_voit_entend_lent": 1}, "lampes": 1, "equipes": 0, "cotes": [16, 32]},
	{"pnj": {"ronde_voit_entend_lent": 2, "immobile_sourd_aveugle": 1}, "lampes": 1, "equipes": 0, "cotes": [16, 40]},
	{"pnj": {"ronde_voit_entend_facile": 2}, "lampes": 2, "equipes": 2, "cotes": [20, 32]},
	{"pnj": {"ronde_voit_entend_lent": 4}, "lampes": 2, "equipes": 4, "cotes": [24, 32]},
	{"pnj": {"ronde_voit_entend_facile": 3, "immobile_entend_lent": 2}, "lampes": 3, "equipes": 3, "cotes": [28, 48]},
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
	print("=== LE CHAPITRE 2 — LES RONDES ÉCOUTENT (S8) ===")
	var dossier := DOSSIER_LIVRE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="):
			dossier = a.substr(10)
	o = Outils.new(Callable(self, "_check"))
	o.mesures_du_jeu(root)
	if not o.charger(dossier, NUMERO, "Les rondes écoutent", CLASSE, 10):
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

## Le rayon, en px, au-delà duquel un pas ACCROUPI ne donne plus une zone assez nette pour qu'un PNJ tire dessus, majoré d'un corps : à cette distance du trajet on est « à l'abri ».
func _abri_accroupi() -> float:
	return o.portee_pas_accroupi_net + Outils.MARGE_PX + 18.0


## Les tours de toutes les rondes de la salle, leurs cases réunies.
func _tous_les_tours(c: Dictionary) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil"].deplacement == Profil.Deplacement.RONDE:
			sortie.append_array(o.tour_de_la_ronde(c, k))
	return sortie


func _indices(c: Dictionary, deplacement: int) -> Array[int]:
	var sortie: Array[int] = []
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil"].deplacement == deplacement:
			sortie.append(k)
	return sortie


func _cases_eclairees(c: Dictionary, tour: Array[Vector2i]) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in tour:
		if o.eclaire_par_lampe(c, Nav.centre_de_la_case(cc)):
			sortie.append(cc)
	return sortie


func _communes(a: Array[Vector2i], b: Array[Vector2i]) -> Array[Vector2i]:
	var dans_b := {}
	for cc in b:
		dans_b[cc] = true
	var sortie: Array[Vector2i] = []
	for cc in a:
		if dans_b.has(cc) and not sortie.has(cc):
			sortie.append(cc)
	return sortie


## La part des cases d'un tour qu'une position voit (ligne de vue) — l'ouïe d'un mur est la même : ce qu'il coupe, il l'étouffe.
func _part_en_vue(c: Dictionary, pos: Vector2, tour: Array[Vector2i]) -> float:
	var n := 0
	for cc in tour:
		if o.ligne_de_vue(c, pos, Nav.centre_de_la_case(cc)):
			n += 1
	return float(n) / float(maxi(tour.size(), 1))


## Les cases de mur plein STRICTEMENT à l'intérieur du rectangle des points d'une ronde.
func _bloc_encercle(c: Dictionary, k: int) -> int:
	var x0 := 999
	var y0 := 999
	var x1 := -1
	var y1 := -1
	for pt: Vector2i in c["pnj"][k]["ronde"]:
		x0 = mini(x0, pt.x)
		y0 = mini(y0, pt.y)
		x1 = maxi(x1, pt.x)
		y1 = maxi(y1, pt.y)
	var n := 0
	for cc in Codec.get_wall_cells(c["carte"]):
		if cc.x > x0 and cc.x < x1 and cc.y > y0 and cc.y < y1:
			n += 1
	return n


## Les composantes (4 voisins) d'un ensemble de cases.
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
# 2.1 — Une ronde qui écoute
# ---------------------------------------------------------------------------

func _salle_1() -> void:
	print("\n--- 2.1 Une ronde qui écoute : s'accroupir sur son passage ---")
	var c := o.ctx(0)
	var nav: Nav = c["nav"]
	var p: Dictionary = c["pnj"][0]
	var tour := o.tour_de_la_ronde(c, 0)
	_check("une ronde qui n'ENTEND que (elle ne voit pas), qui tire, et un plafonnier", p["profil"].entend and not p["profil"].voit and p["profil"].tire and (c["lampes"] as Array).size() == 1)
	_check("elle fait le tour d'un bloc : au moins 40 cases de mur plein à l'intérieur de son rectangle (%d)" % _bloc_encercle(c, 0), _bloc_encercle(c, 0) >= 40)
	# Debout, un pas s'entend net de partout : on ne passe pas.
	var plus_loin := 0.0
	var surs: Array[Vector2i] = []
	for cc in nav.cases_praticables():
		var d := o.distance_au_tour(Nav.centre_de_la_case(cc), tour)
		plus_loin = maxf(plus_loin, d)
		if d > _abri_accroupi():
			surs.append(cc)
	_check("un pas DEBOUT s'entend net de partout : la case la plus éloignée du trajet en est à %.0f px, moins que la portée nette d'un pas (%.0f px)" % [plus_loin, o.portee_pas_debout_net],
		plus_loin <= o.portee_pas_debout_net)
	# Accroupi, il existe des cases à l'abri : plus loin du trajet que la portée nette d'un pas accroupi.
	_check("… mais un pas ACCROUPI ne s'entend net que jusqu'à %.0f px : %d cases du sol sont plus loin du trajet que cela (au moins 40)" % [o.portee_pas_accroupi_net, surs.size()], surs.size() >= 40)
	_check("le joueur part dans cette zone d'abri : %.0f px du trajet (plus de %.0f)" % [o.distance_au_tour(c["depart_pos"], tour), _abri_accroupi()], o.distance_au_tour(c["depart_pos"], tour) > _abri_accroupi())
	# Et pour l'atteindre, il faut passer sur son trajet : le tour sépare l'abri de l'extérieur — le bloc central est plus près du trajet que l'abri.
	var eclairees := _cases_eclairees(c, tour)
	_check("la lampe éclaire le trajet (%d cases du tour) : la ronde y passe, visible, sans voir" % eclairees.size(), eclairees.size() >= 3)
	print("    mesure : un tour de %d cases en %.1f s ; abri à plus de %.0f px" % [tour.size(), o.periode_de_la_ronde(tour), _abri_accroupi()])


# ---------------------------------------------------------------------------
# 2.2 — Le pas de trop
# ---------------------------------------------------------------------------

func _salle_2() -> void:
	print("\n--- 2.2 Le pas de trop : un pas, une douille, et elle se retourne ---")
	var c := o.ctx(1)
	var nav: Nav = c["nav"]
	var bas := Codec.get_low_wall_cells(c["carte"])
	_check("une salle nue : aucun plafonnier, aucun mur ni muret à l'intérieur (rien n'étouffe un pas)", (c["lampes"] as Array).is_empty() and o.murs_interieurs(c) == 0 and bas.is_empty())
	var rondes := _indices(c, Profil.Deplacement.RONDE)
	var t0 := o.tour_de_la_ronde(c, rondes[0])
	var t1 := o.tour_de_la_ronde(c, rondes[1])
	_check("deux rondes qui n'entendent que, aux tours distincts (aucune case commune)", rondes.size() == 2 and _communes(t0, t1).is_empty() and c["pnj"][0]["profil"].entend and not c["pnj"][0]["profil"].voit)
	var plus_loin_pas := 0.0
	var plus_loin_tir := 0.0
	var couvert_douille := 0
	var sol := nav.cases_praticables()
	for cc in sol:
		var pos := Nav.centre_de_la_case(cc)
		var d_min := minf(o.distance_au_tour(pos, t0), o.distance_au_tour(pos, t1))
		plus_loin_pas = maxf(plus_loin_pas, d_min)
		# Un tir s'entend de CHACUNE des deux rondes, où qu'elles soient sur leur tour.
		for t in [t0, t1]:
			for tc: Vector2i in t:
				plus_loin_tir = maxf(plus_loin_tir, Nav.centre_de_la_case(tc).distance_to(pos))
		if d_min <= o.portee_douille_nette:
			couvert_douille += 1
	_check("un pas debout est entendu net, de partout, par au moins une ronde : la case la plus éloignée des deux trajets en est à %.0f px (portée nette : %.0f)" % [plus_loin_pas, o.portee_pas_debout_net], plus_loin_pas <= o.portee_pas_debout_net)
	_check("un tir est entendu net des DEUX rondes, de partout, où qu'elles soient sur leur tour : au plus %.0f px (portée nette d'un tir : %.0f)" % [plus_loin_tir, o.portee_tir_net], plus_loin_tir <= o.portee_tir_net)
	_check("une douille, plus discrète, est entendue net par une ronde sur %d %% du sol (au moins un tiers)" % [100 * couvert_douille / sol.size()], 3 * couvert_douille >= sol.size())
	var surs := 0
	for cc in sol:
		var pos := Nav.centre_de_la_case(cc)
		if minf(o.distance_au_tour(pos, t0), o.distance_au_tour(pos, t1)) > _abri_accroupi():
			surs += 1
	_check("accroupi, on a pourtant de quoi passer : %d cases à plus de %.0f px des deux trajets (au moins 20), et le joueur part sur l'une d'elles" % [surs, _abri_accroupi()],
		surs >= 20 and minf(o.distance_au_tour(c["depart_pos"], t0), o.distance_au_tour(c["depart_pos"], t1)) > _abri_accroupi())


# ---------------------------------------------------------------------------
# 2.3 — Attendre
# ---------------------------------------------------------------------------

func _salle_3() -> void:
	print("\n--- 2.3 Attendre : laisser passer une ronde à l'arrêt ---")
	var c := o.ctx(2)
	var nav: Nav = c["nav"]
	var tours: Array[Vector2i] = _tous_les_tours(c)
	# Les recoins : des cases dans le noir, assez loin du trajet, qui ne voient presque rien du tour (les murs étouffent le pas).
	var recoin: Array[Vector2i] = []
	for cc in nav.cases_praticables():
		var pos := Nav.centre_de_la_case(cc)
		if o.sous_une_lampe(c, pos) or o.distance_au_tour(pos, tours) < 2.5 * 35.0:
			continue
		if _part_en_vue(c, pos, tours) < 0.25:
			recoin.append(cc)
	var morceaux := _composantes(recoin)
	var grands: Array = []
	for m in morceaux:
		if (m as Array).size() >= 8:
			grands.append(m)
	_check("deux recoins sombres : au moins deux ensembles de 8 cases dans le noir, à 2,5 cases au moins du trajet, qui voient moins d'un quart du tour (%d ensembles)" % grands.size(), grands.size() >= 2)
	var etendue := 0.0
	if grands.size() >= 2:
		var xs: Array[float] = []
		for m in grands:
			var s := 0.0
			for cc: Vector2i in m:
				s += float(cc.x)
			xs.append(s / float((m as Array).size()))
		xs.sort()
		etendue = xs[xs.size() - 1] - xs[0]
	_check("… et ces recoins sont éloignés l'un de l'autre : %.0f cases entre les plus distants (au moins 15)" % etendue, etendue >= 15.0)
	var eclaire_recoin := false
	for m in grands:
		for cc: Vector2i in m:
			eclaire_recoin = eclaire_recoin or o.eclaire_par_lampe(c, Nav.centre_de_la_case(cc))
	_check("aucun recoin n'est éclairé par la lampe (qui éclaire le hall du milieu)", not eclaire_recoin and o.eclaire_par_lampe(c, c["lampes"][0]["pos"]))
	_check("le hall est entre les deux trajets : le joueur part au milieu (%.0f px du trajet le plus proche)" % o.distance_au_tour(c["depart_pos"], tours), o.distance_au_tour(c["depart_pos"], tours) >= 2.5 * 35.0)
	var plus_pres := INF
	for m in grands:
		for cc: Vector2i in m:
			plus_pres = minf(plus_pres, o.distance_au_tour(Nav.centre_de_la_case(cc), tours))
	_check("la ronde passe tout près du recoin (%.0f px de la case la plus proche) : rester immobile, c'est la laisser passer" % plus_pres, plus_pres <= 4.0 * 35.0)


# ---------------------------------------------------------------------------
# 2.4 — Le bruit et la lumière
# ---------------------------------------------------------------------------

func _salle_4() -> void:
	print("\n--- 2.4 Le bruit et la lumière : une ronde voit, l'autre entend ---")
	var c := o.ctx(3)
	var nav: Nav = c["nav"]
	var voit := -1
	var entend := -1
	for k in (c["pnj"] as Array).size():
		var pr: ProfilBot = c["pnj"][k]["profil"]
		if pr.voit and not pr.entend:
			voit = k
		elif pr.entend and not pr.voit:
			entend = k
	_check("une ronde qui voit sans entendre, une qui entend sans voir", voit >= 0 and entend >= 0)
	var tv := o.tour_de_la_ronde(c, voit)
	var te := o.tour_de_la_ronde(c, entend)
	var max_v := 0
	var min_e := 999
	for cc in tv:
		max_v = maxi(max_v, cc.x)
	for cc in te:
		min_e = mini(min_e, cc.x)
	_check("deux salles : le tour de la ronde qui voit reste à l'ouest (x ≤ %d), celui de la ronde qui entend à l'est (x ≥ %d)" % [max_v, min_e], max_v < min_e)
	# La porte : dans la colonne de la cloison, quelques cases praticables seulement.
	var colonne := (max_v + min_e) / 2
	var porte := 0
	var taille: Vector2i = c["taille"]
	for y in taille.y:
		if nav.est_praticable(Vector2i(colonne, y)):
			porte += 1
	_check("les deux salles se rejoignent par une porte : %d cases praticables dans la colonne x = %d de la cloison (de 3 à 6)" % [porte, colonne], porte >= 3 and porte <= 6)
	var eclairees_v := _cases_eclairees(c, tv)
	var eclairees_e := _cases_eclairees(c, te)
	_check("les deux lampes sont dans la salle qui voit : %d cases de son tour éclairées (au moins 6) — et aucune de celui de la ronde qui entend (%d)" % [eclairees_v.size(), eclairees_e.size()],
		eclairees_v.size() >= 6 and eclairees_e.is_empty())
	var lampes_ouest := true
	for l: Dictionary in c["lampes"]:
		lampes_ouest = lampes_ouest and (l["case"] as Vector2i).x < colonne
	_check("… chaque lampe éclaire le tour de la ronde qui voit", lampes_ouest and (c["lampes"] as Array).size() == 2)
	# Du seuil, on voit les deux salles : le départ est dans la porte, il regarde les deux tours.
	var vue_v := _part_en_vue(c, c["depart_pos"], tv)
	var vue_e := _part_en_vue(c, c["depart_pos"], te)
	_check("du seuil de la porte on voit une part des deux tours (%.0f %% et %.0f %%, au moins 10 %%)" % [100.0 * vue_v, 100.0 * vue_e], vue_v >= 0.1 and vue_e >= 0.1)
	# La cloison coupe la vue entre les deux tours, hors de la porte.
	var se_voient := 0
	for a in tv:
		for b in te:
			if o.ligne_de_vue(c, Nav.centre_de_la_case(a), Nav.centre_de_la_case(b)):
				se_voient += 1
	_check("la cloison sépare les deux rondes : %d couples de cases se voient, sur %d" % [se_voient, tv.size() * te.size()], se_voient * 4 < tv.size() * te.size())


# ---------------------------------------------------------------------------
# 2.5 — Les deux sens
# ---------------------------------------------------------------------------

func _salle_5() -> void:
	print("\n--- 2.5 Les deux sens : une ronde qui voit et entend ---")
	var c := o.ctx(4)
	var nav: Nav = c["nav"]
	var p: Dictionary = c["pnj"][0]
	var tour := o.tour_de_la_ronde(c, 0)
	var taille: Vector2i = c["taille"]
	_check("une ronde qui voit ET entend, et tire", p["profil"].voit and p["profil"].entend and p["profil"].tire)
	var sol := nav.cases_praticables().size()
	_check("une salle en T : le sol occupe moins de 70 %% du rectangle (%d cases sur %d)" % [sol, (taille.x - 2) * (taille.y - 2)], float(sol) < 0.7 * float((taille.x - 2) * (taille.y - 2)))
	var haut := 999
	var bas := -1
	for cc in tour:
		haut = mini(haut, cc.y)
		bas = maxi(bas, cc.y)
	_check("son tour va de la barre à la queue du T : de la ligne %d à la ligne %d (la barre : jusqu'à 7, la queue : à partir de 10)" % [haut, bas], haut <= 5 and bas >= 10)
	var eclairees := _cases_eclairees(c, tour)
	var dans_la_queue := true
	for cc in eclairees:
		dans_la_queue = dans_la_queue and cc.y >= 8
	_check("la lampe éclaire la queue (%d cases du tour) et pas la barre" % eclairees.size(), eclairees.size() >= 3 and dans_la_queue)
	# Les ailes : noires, et assez loin du trajet pour qu'un pas accroupi n'y soit pas entendu. Le noir ne suffit pas, le silence non plus : il faut les deux.
	var ailes := 0
	for cc in nav.cases_praticables():
		var pos := Nav.centre_de_la_case(cc)
		if cc.y <= 7 and (cc.x <= 10 or cc.x >= 19) and not o.sous_une_lampe(c, pos) and o.distance_au_tour(pos, tour) > _abri_accroupi():
			ailes += 1
	_check("les ailes de la barre sont des abris, dans le noir ET hors de portée d'un pas accroupi : %d cases (au moins 25)" % ailes, ailes >= 25)
	_check("le joueur part dans une aile : %.0f px du trajet" % o.distance_au_tour(c["depart_pos"], tour), o.distance_au_tour(c["depart_pos"], tour) > _abri_accroupi() and c["depart"].y <= 7)


# ---------------------------------------------------------------------------
# 2.6 — La diversion
# ---------------------------------------------------------------------------

func _salle_6() -> void:
	print("\n--- 2.6 La diversion : tirer ailleurs pour déplacer une ronde ---")
	var c := o.ctx(5)
	var nav: Nav = c["nav"]
	var rondes := _indices(c, Profil.Deplacement.RONDE)
	var cible := -1
	for k in (c["pnj"] as Array).size():
		if not rondes.has(k):
			cible = k
	var s: Dictionary = c["pnj"][cible]
	_check("deux rondes qui voient et entendent, une silhouette immobile sourde et aveugle", rondes.size() == 2 and s["profil_nom"] == "immobile_sourd_aveugle")
	var bas := Codec.get_low_wall_cells(c["carte"])
	_check("une galerie à murets : au moins 15 cases de mur bas (%d)" % bas.size(), bas.size() >= 15)
	var tours: Array[Vector2i] = _tous_les_tours(c)
	# La silhouette est gardée : chaque ronde la voit d'un point de son tour (elle est sous la lampe), à moins de 8 cases.
	for k in rondes:
		var gardee := 0
		for cc in o.tour_de_la_ronde(c, k):
			var pos := Nav.centre_de_la_case(cc)
			if pos.distance_to(s["pos"]) <= 8.0 * 35.0 and o.ligne_de_vue(c, pos, s["pos"]):
				gardee += 1
		_check("la ronde %d veille sur elle : %d cases de son tour la voient à moins de 8 cases (au moins 8)" % [k + 1, gardee], gardee >= 8)
	_check("la silhouette est sous la lampe : on la voit de loin, sans torche", o.eclaire_par_lampe(c, s["pos"]))
	# La diversion : une case de la galerie, dans le noir, d'où aucune case des tours n'est en vue, loin de la silhouette, d'où un tir s'entend net des deux rondes.
	var meilleure := Vector2i(-1, -1)
	var distance_cible := 0.0
	for cc in nav.cases_atteignables(c["depart"]):
		var pos := Nav.centre_de_la_case(cc)
		if o.sous_une_lampe(c, pos) or pos.distance_to(s["pos"]) < 14.0 * 35.0:
			continue
		if _part_en_vue(c, pos, tours) > 0.3:
			continue
		var net := true
		for tc in tours:
			net = net and Nav.centre_de_la_case(tc).distance_to(pos) <= o.portee_tir_net
		if net:
			meilleure = cc
			distance_cible = pos.distance_to(s["pos"])
			break
	_check("une case de diversion : dans le noir, qui voit moins d'un tiers des deux tours, à plus de 14 cases de la silhouette, d'où un tir s'entend net des deux rondes (%s, %.0f px)" % [str(meilleure), distance_cible], meilleure.x >= 0)
	# … et la silhouette n'est entendue ni vue de cette case : on ne la tue pas d'où l'on fait diversion.
	if meilleure.x >= 0:
		_check("… d'où l'on ne voit pas la silhouette à la torche (trop loin : %.0f px, la torche porte %.0f)" % [distance_cible, o.portee_torche], distance_cible > o.portee_torche)


# ---------------------------------------------------------------------------
# 2.7 — Le leurre
# ---------------------------------------------------------------------------

func _salle_7() -> void:
	print("\n--- 2.7 Le leurre : une silhouette qui ne bouge pas n'est peut-être personne ---")
	var c := o.ctx(6)
	var rondes := _indices(c, Profil.Deplacement.RONDE)
	_check("une salle à piliers : au moins 5 piliers de 4 cases (%d cases de mur plein à l'intérieur)" % o.murs_interieurs(c), o.murs_interieurs(c) >= 20)
	for p: Dictionary in c["pnj"]:
		_check("%s porte l'Illusionniste et son leurre (palier FACILE : voit, entend, tire)" % p["profil_nom"], p["classe"] == CLASSE and p["equipe"] and p["profil"].voit and p["profil"].entend and p["profil"].tire)
	# Le leurre se pose en COMBAT sur une cible VUE, à 160-600 px (la règle de l'Illusionniste, `EquipementBot.GADGETS`) : un point du tour d'où un point éclairé se voit à cette distance.
	for k in rondes:
		var tour := o.tour_de_la_ronde(c, k)
		var peut := false
		for cc in tour:
			var pos := Nav.centre_de_la_case(cc)
			for l: Dictionary in c["lampes"]:
				var d: float = pos.distance_to(l["pos"])
				if d >= 160.0 and d <= 600.0 and o.ligne_de_vue(c, pos, l["pos"]) and o.voit(c, pos, l["pos"], o.lumieres(c)):
					peut = true
		_check("ronde %d : un point de son tour d'où elle voit la flaque à 160-600 px — la règle du leurre peut se déclencher" % (k + 1), peut)
	var eclairees := 0
	for k in rondes:
		eclairees += _cases_eclairees(c, o.tour_de_la_ronde(c, k)).size()
	_check("deux lampes sur les trajets : %d cases de tour éclairées (au moins 6)" % eclairees, eclairees >= 6)
	_check("les deux rondes ne se touchent jamais : %.0f px d'écart au plus près (au moins 40)" % o.ecart_minimal_des_rondes(c, rondes), o.ecart_minimal_des_rondes(c, rondes) >= 40.0)


# ---------------------------------------------------------------------------
# 2.8 — Le quartier
# ---------------------------------------------------------------------------

func _salle_8() -> void:
	print("\n--- 2.8 Le quartier : quatre rondes qui se recouvrent ---")
	var c := o.ctx(7)
	var nav: Nav = c["nav"]
	var taille: Vector2i = c["taille"]
	var sol := nav.cases_praticables().size()
	_check("une croix de couloirs : le sol occupe moins de 80 %% du rectangle (%d cases sur %d)" % [sol, (taille.x - 2) * (taille.y - 2)], float(sol) < 0.8 * float((taille.x - 2) * (taille.y - 2)))
	var rondes := _indices(c, Profil.Deplacement.RONDE)
	var tours: Array = []
	for k in rondes:
		tours.append(o.tour_de_la_ronde(c, k))
	_check("quatre rondes, équipées de l'Illusionniste", rondes.size() == 4)
	# Chaque tour recouvre au moins deux autres ; le graphe de recouvrement est d'un seul tenant.
	var voisins: Array = []
	for a in 4:
		var v: Array[int] = []
		for b in 4:
			if a != b and not _communes(tours[a], tours[b]).is_empty():
				v.append(b)
		voisins.append(v)
		_check("la ronde %d recouvre au moins deux autres tours (%s)" % [a + 1, str(v)], v.size() >= 2)
	var vus := {0: true}
	var file: Array[int] = [0]
	while not file.is_empty():
		var a: int = file.pop_back()
		for b: int in voisins[a]:
			if not vus.has(b):
				vus[b] = true
				file.append(b)
	_check("les quatre tours forment un seul quartier : chacun est relié aux autres par des cases communes", vus.size() == 4)
	var ecart := o.ecart_minimal_des_rondes(c, rondes)
	_check("elles se croisent sans se toucher : %.0f px d'écart au plus près (au moins 40)" % ecart, ecart >= 40.0)
	# Les lampes éclairent le carrefour : une case commune à deux tours au moins.
	var eclairees_communes := 0
	for a in 4:
		for b in range(a + 1, 4):
			eclairees_communes += _cases_eclairees(c, _communes(tours[a], tours[b])).size()
	_check("un croisement au moins se fait sous une lampe (%d case(s) communes éclairées)" % eclairees_communes, eclairees_communes >= 1)


# ---------------------------------------------------------------------------
# 2.9 — La salle pleine
# ---------------------------------------------------------------------------

func _salle_9() -> void:
	print("\n--- 2.9 La salle pleine : rondes et postes, tous à l'écoute ---")
	var c := o.ctx(8)
	var rondes := _indices(c, Profil.Deplacement.RONDE)
	var postes: Array[int] = []
	for k in (c["pnj"] as Array).size():
		if not rondes.has(k):
			postes.append(k)
	_check("trois rondes équipées du leurre, deux postes immobiles qui n'entendent que", rondes.size() == 3 and postes.size() == 2)
	_check("une grande salle à colonnes : au moins 5 piliers de 4 cases (%d)" % o.murs_interieurs(c), o.murs_interieurs(c) >= 20)
	var tours: Array = []
	for k in rondes:
		tours.append(o.tour_de_la_ronde(c, k))
	var distincts := true
	for a in 3:
		for b in range(a + 1, 3):
			distincts = distincts and _communes(tours[a], tours[b]).is_empty()
	_check("trois tours distincts, qui ne partagent aucune case", distincts)
	_check("les trois rondes ne se touchent jamais : %.0f px d'écart au plus près (au moins 40)" % o.ecart_minimal_des_rondes(c, rondes), o.ecart_minimal_des_rondes(c, rondes) >= 40.0)
	for k in postes:
		var s: Dictionary = c["pnj"][k]
		_check("le poste %d est dans le noir et loin du départ (%.0f px, plus que la torche) : on l'entend avant de le voir" % [k + 1, s["pos"].distance_to(c["depart_pos"])],
			not o.sous_une_lampe(c, s["pos"]) and s["pos"].distance_to(c["depart_pos"]) > o.portee_torche + Outils.MARGE_PX and s["profil"].entend and not s["profil"].voit)
	var eclairees := 0
	for t in tours:
		eclairees += _cases_eclairees(c, t).size()
	_check("trois plafonniers sur les trajets : %d cases de tour éclairées en tout (au moins 6)" % eclairees, eclairees >= 6)
	# Le départ est dans la portée d'un tir de tous : se battre ici appelle tout le monde.
	var tout_entend := true
	for t in tours:
		for tc: Vector2i in t:
			tout_entend = tout_entend and Nav.centre_de_la_case(tc).distance_to(c["depart_pos"]) <= o.portee_tir_net
	for k in postes:
		tout_entend = tout_entend and c["pnj"][k]["pos"].distance_to(c["depart_pos"]) <= o.portee_tir_net
	_check("un tir tiré du départ est entendu net de TOUS (rondes et postes, où qu'ils soient) : se battre ici appelle tout le monde", tout_entend)
