## La garde du CHAPITRE 8 — chantier SOLO, étape S8 (lot 2) : chaque salle enseigne ce qu'elle dit, et chaque grande salle EST grande.
##
## Le chapitre 8, « Les grandes salles », est écrit dans `res://assets/solo/chapitre_08/` (par `tools/fabrique_chapitre_08.gd`). Des salles bien plus vastes qu'une carte de duel
## (Adrien, 2026-10-03 : « toute liberté sur la taille ») où se mêlent des postes, des rondes, des zones et des chasseurs libres, sous beaucoup de plafonniers. Cette suite mesure
## sur les données ce que chaque salle impose, avec les fonctions du jeu (`tools/outils_chapitre.gd`, et `tools/outils_chasseurs.gd` : la lumière, les ombres, les îlots, les
## bandes de cloison). **« Grande » se mesure** : l'aire de chaque salle est comparée à celle de la plus grande carte de duel livrée (lue dans `res://assets/maps/`), jamais à un
## chiffre recopié.
##
## Partout : taille, PNJ de chaque sorte, plafonniers, PNJ équipés (la classe du boss, la mine au magnésium, à partir de 8.7 — un PNJ équipé ENTEND, la mine se pose en enquête
## sur une place qu'on n'a pas vue), chaque PNJ atteignable à pied, une seule pièce, aucun couloir d'une tuile, chaque ronde une boucle, chaque zone assez vaste, le départ à l'abri.
## Puis salle par salle : 8.1 la place éclairée, deux tours qui ne se touchent pas, le couloir d'ombre du milieu ; 8.2 un H, une aile gardée de chaque côté, le pont dans le noir ;
## 8.3 une galerie de 90 cases, sept lampes, trois tours ; 8.4 trois chambres et deux goulets éclairés ; 8.5 vingt machines, deux postes qui regardent les allées, trois rondes
## de même tour ; 8.6 une cour éclairée, une galerie noire qui fait le tour ; 8.7 six salles noires autour d'un couloir ; 8.8 seize blocs et leurs rues, deux tours de même longueur ;
## 8.9 quatre halls, huit lampes, la plus grande salle du jeu — et la plupart de ses lampes éteintes au départ ; 8.10 un duel en miroir de part et d'autre d'un goulet.
##
## Sabotée salle par salle — la liste est dans la ROADMAP, S8 lot 2. Pour saboter sans toucher aux fichiers livrés : `-- --dossier=<chemin absolu d'une copie du chapitre>`.
##
## Lancer : godot --headless --path . --script res://tools/test_chapitre_08.gd
extends SceneTree

const Outils := preload("res://tools/outils_chapitre.gd")
const Chass := preload("res://tools/outils_chasseurs.gd")
const Nav := preload("res://navigation_bot.gd")
const Profil := preload("res://profil_bot.gd")
const Codec := preload("res://map_codec.gd")
const Percep := preload("res://perception_bot.gd")
const Equip := preload("res://equipement_bot.gd")
const PlafT := preload("res://plafonnier.gd")

const DOSSIER_LIVRE := "res://assets/solo/chapitre_08"
const NUMERO := 8
const CLASSE := "allumeur"
const GADGET := "mine_magnesium"
const IMM := "immobile_voit_entend_normal"
const RON := "ronde_voit_entend_normal"
const ZON := "zone_voit_entend_normal"
const LIB := "libre_voit_entend_normal"

const TABLE := [
	{"pnj": {IMM: 2, RON: 2}, "lampes": 6, "equipes": 0, "cotes": [48, 60]},
	{"pnj": {ZON: 2, RON: 2}, "lampes": 4, "equipes": 0, "cotes": [44, 64]},
	{"pnj": {RON: 3}, "lampes": 7, "equipes": 0, "cotes": [22, 90]},
	{"pnj": {ZON: 2, LIB: 1}, "lampes": 3, "equipes": 0, "cotes": [50, 56]},
	{"pnj": {IMM: 2, RON: 3}, "lampes": 5, "equipes": 0, "cotes": [48, 72]},
	{"pnj": {ZON: 2, LIB: 2}, "lampes": 4, "equipes": 0, "cotes": [60, 60]},
	{"pnj": {ZON: 3, "immobile_entend_normal": 2}, "lampes": 2, "equipes": 3, "cotes": [46, 54]},
	{"pnj": {IMM: 2, RON: 2, LIB: 2}, "lampes": 6, "equipes": 4, "cotes": [64, 80]},
	{"pnj": {IMM: 2, ZON: 2, RON: 2, "libre_voit_entend_difficile": 1}, "lampes": 8, "equipes": 5, "cotes": [80, 100]},
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
	print("=== LE CHAPITRE 8 — LES GRANDES SALLES (S8, lot 2) ===")
	var dossier := DOSSIER_LIVRE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="):
			dossier = a.substr(10)
	o = Outils.new(Callable(self, "_check"))
	o.mesures_du_jeu(root)
	if not o.charger(dossier, NUMERO, "Les grandes salles", CLASSE, 10):
		print("\n=== %d vérifications, %d échec(s) ===" % [_verifications, _failures])
		print("CRIS ATTENDUS: 0")
		quit(1)
		return
	o.partout(NUMERO, CLASSE, TABLE)
	_grandes()
	print("\n--- Partout : un PNJ libre part loin du joueur, hors de toute lampe ---")
	for i in 10:
		Chass.libres_partout(o, o.ctx(i), "8.%d" % (i + 1), 25 if i == 9 else 10)
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
	_boss()
	print("\n=== %d vérifications, %d échec(s) ===" % [_verifications, _failures])
	print("CRIS ATTENDUS: 0")
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# DE PETITS OUTILS DE SALLE
# ---------------------------------------------------------------------------

func _de(c: Dictionary, d: int) -> Array[int]:
	return Chass.pnj_de(c, d)


func _flaques_a_part(c: Dictionary) -> bool:
	var ls: Array = c["lampes"]
	for i in ls.size():
		for j in range(i + 1, ls.size()):
			if (ls[i]["pos"] as Vector2).distance_to(ls[j]["pos"]) <= Chass.rayon_clair(ls[i]) + Chass.rayon_clair(ls[j]):
				return false
	return true


## La règle de la mine peut-elle se déclencher chez ce PNJ ? Une case où il se tient (`cases`), une place à 250-450 px (la fenêtre de la règle, lue dans `EquipementBot.GADGETS`)
## en ligne dégagée.
func _regle_possible(c: Dictionary, cases: Array[Vector2i]) -> bool:
	var fenetre: Array = Equip.GADGETS[GADGET]["distance"]
	var cibles := (c["nav"] as Nav).cases_praticables()
	for i in range(0, cases.size(), maxi(1, cases.size() / 40)):
		var a := Nav.centre_de_la_case(cases[i])
		for j in range(0, cibles.size(), maxi(1, cibles.size() / 80)):
			var b := Nav.centre_de_la_case(cibles[j])
			var d := a.distance_to(b)
			if d >= float(fenetre[0]) and d <= float(fenetre[1]) and Percep.segment_degage(a, b, c["monde"]):
				return true
	return false


func _lampes_a_part_du_depart(c: Dictionary, cases: float) -> bool:
	for l: Dictionary in c["lampes"]:
		if (l["pos"] as Vector2).distance_to(c["depart_pos"]) < cases * 35.0:
			return false
	return true


## Chaque PNJ du profil donné est-il équipé ?
func _tous_equipes(c: Dictionary, ks: Array[int]) -> bool:
	for k in ks:
		if not c["pnj"][k]["equipe"]:
			return false
	return not ks.is_empty()


# ---------------------------------------------------------------------------
# LES SALLES SONT GRANDES
# ---------------------------------------------------------------------------

func _grandes() -> void:
	print("\n--- Les salles sont GRANDES : comparées à la plus grande carte de duel livrée ---")
	var duel := Chass.aire_du_plus_grand_duel()
	_check("la plus grande carte de duel livrée mesure %d cases (32 × 32 au plus) : la mesure de comparaison" % duel, duel >= 900 and duel <= 1100)
	var grandes := 0
	var plus_grande := 0
	for i in 9:
		var c := o.ctx(i)
		var a := Chass.aire(c)
		plus_grande = maxi(plus_grande, a)
		_check("8.%d : %d × %d = %d cases, au moins 1,5 fois la plus grande carte de duel (%d)" % [i + 1, c["taille"].x, c["taille"].y, a, int(1.5 * duel)], float(a) >= 1.5 * float(duel))
		if float(a) >= 2.5 * float(duel):
			grandes += 1
	_check("%d salles sur 9 couvrent au moins deux fois et demie la plus grande carte de duel (au moins 6)" % grandes, grandes >= 6)
	_check("la plus grande fait %d cases : au moins sept fois la plus grande carte de duel" % plus_grande, plus_grande >= 7 * duel)
	var aires: Array[int] = []
	for i in 9:
		aires.append(Chass.aire(o.ctx(i)))
	_check("la dernière salle avant le boss, 8.9, est la plus grande du chapitre", aires[8] == plus_grande and aires.count(plus_grande) == 1)


# ---------------------------------------------------------------------------
# 8.1 — La place
# ---------------------------------------------------------------------------

func _salle_1() -> void:
	print("\n--- 8.1 La place : traverser une grande salle éclairée ---")
	var c := o.ctx(0)
	var nav: Nav = c["nav"]
	var postes := _de(c, Profil.Deplacement.IMMOBILE)
	var rondes := _de(c, Profil.Deplacement.RONDE)
	_check("deux postes et deux rondes, tous aux réflexes NORMAUX, qui voient et entendent", postes.size() == 2 and rondes.size() == 2)
	_check("six lampes aux flaques à part", (c["lampes"] as Array).size() == 6 and _flaques_a_part(c))
	for l: Dictionary in c["lampes"]:
		var n := 0
		for cc in Chass.claires(o, c):
			if Nav.centre_de_la_case(cc).distance_to(l["pos"]) <= Chass.rayon_clair(l):
				n += 1
		_check("la lampe %s éclaire une vraie flaque : %d cases (au moins 25)" % [str(l["case"]), n], n >= 25)
	for k in postes:
		_check("le poste %d est sous une lampe : on le voit de loin, il voit ce qui est éclairé" % (k + 1), o.eclaire_par_lampe(c, c["pnj"][k]["pos"]))
	var t0 := o.tour_de_la_ronde(c, rondes[0])
	var t1 := o.tour_de_la_ronde(c, rondes[1])
	_check("deux tours de MÊME longueur : %d et %d cases (les rondes de longueurs inégales finissent par se frôler)" % [t0.size(), t1.size()], t0.size() == t1.size() and t0.size() >= 80)
	var ecart := Chass.ecart_entre(t0, t1)
	_check("… et qui ne se touchent jamais : %.0f px entre les deux tours (au moins 8 cases)" % ecart, ecart >= 8.0 * 35.0)
	_check("… et chaque tour passe sous des lampes : %d et %d cases éclairées (au moins 8)" % [Chass.combien_claires(o, c, o.cases_du_tour(t0)), Chass.combien_claires(o, c, o.cases_du_tour(t1))],
		Chass.combien_claires(o, c, o.cases_du_tour(t0)) >= 8 and Chass.combien_claires(o, c, o.cases_du_tour(t1)) >= 8)
	# Le couloir d'ombre du milieu : le départ, en bas, rejoint le haut de la salle sans traverser une flaque.
	var sombres := Chass.sombres(o, c)
	var morceau: Array = []
	for m in Chass.composantes(sombres):
		if (m as Array).has(c["depart"]):
			morceau = m
	var monte := false
	for cc: Vector2i in morceau:
		monte = monte or cc.y <= 4
	_check("le départ rejoint le haut de la salle par le noir seul : un morceau d'ombre de %d cases monte jusqu'à la rangée 4" % morceau.size(), monte)
	var part := float(Chass.claires(o, c).size()) / float(nav.cases_praticables().size())
	_check("la lumière tient %.0f %% de la place (de 5 à 25 %%)" % (100.0 * part), part >= 0.05 and part <= 0.25)
	_check("un bassin bas au milieu (%d cases de mur bas) : on le voit par-dessus, on le contourne" % Chass.murets(c).size(), Chass.murets(c).size() >= 30)
	_check("le départ est loin des tours : %.0f px de la plus proche (plus de 6 cases)" % minf(o.distance_au_tour(c["depart_pos"], t0), o.distance_au_tour(c["depart_pos"], t1)),
		minf(o.distance_au_tour(c["depart_pos"], t0), o.distance_au_tour(c["depart_pos"], t1)) > 6.0 * 35.0)
	_check("les deux tours ne se croisent jamais, simulés à vitesse constante : %.0f px au plus près (au moins 300)" % o.ecart_minimal_des_rondes(c, rondes), o.ecart_minimal_des_rondes(c, rondes) >= 300.0)


# ---------------------------------------------------------------------------
# 8.2 — Les ailes
# ---------------------------------------------------------------------------

func _salle_2() -> void:
	print("\n--- 8.2 Les ailes : un H, un garde et une ronde par aile ---")
	var c := o.ctx(1)
	var nav: Nav = c["nav"]
	var zs := _de(c, Profil.Deplacement.ZONE)
	var rs := _de(c, Profil.Deplacement.RONDE)
	var cases := nav.cases_praticables()
	var rect_total := float(Chass.aire(c))
	_check("un bâtiment en H : le sol ne couvre que %.0f %% du rectangle (moins de 75 %%)" % (100.0 * float(cases.size()) / rect_total), float(cases.size()) < 0.75 * rect_total)
	# Les colonnes du pont : peu de cases praticables par colonne ; les ailes en ont beaucoup.
	var par_colonne := {}
	for cc in cases:
		par_colonne[cc.x] = int(par_colonne.get(cc.x, 0)) + 1
	var pont := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return int(par_colonne[cc.x]) < 20)
	var ailes := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return int(par_colonne[cc.x]) >= 20)
	var morceaux := Chass.composantes(ailes)
	_check("deux ailes, séparées : %d morceaux de sol de plus de 20 cases par colonne, de %s cases" % [morceaux.size(), str([(morceaux[0] as Array).size(), (morceaux[1] as Array).size()]) if morceaux.size() >= 2 else "?"],
		morceaux.size() == 2 and (morceaux[0] as Array).size() >= 800 and (morceaux[1] as Array).size() >= 800)
	_check("le pont qui les relie : %d cases (de 150 à 250), et il est dans le noir : %d éclairées" % [pont.size(), Chass.combien_claires(o, c, pont)], pont.size() >= 150 and pont.size() <= 250 and Chass.combien_claires(o, c, pont) == 0)
	_check("le joueur part dans le pont", pont.has(c["depart"]))
	# Une aile : un garde (zone), une ronde, deux lampes.
	for a in 2:
		var aile: Array = morceaux[a]
		var ses_zones := 0
		var ses_rondes := 0
		var ses_lampes := 0
		for k in zs:
			ses_zones += 1 if aile.has(c["pnj"][k]["case"]) else 0
		for k in rs:
			ses_rondes += 1 if aile.has(c["pnj"][k]["case"]) else 0
		for l: Dictionary in c["lampes"]:
			ses_lampes += 1 if aile.has(l["case"]) else 0
		_check("l'aile %d : un garde, une ronde, deux lampes (%d, %d, %d)" % [a + 1, ses_zones, ses_rondes, ses_lampes], ses_zones == 1 and ses_rondes == 1 and ses_lampes == 2)
	var t0 := o.tour_de_la_ronde(c, rs[0])
	var t1 := o.tour_de_la_ronde(c, rs[1])
	_check("deux tours de même longueur (%d et %d cases), chacun dans son aile, qui ne se touchent jamais (%.0f px)" % [t0.size(), t1.size(), Chass.ecart_entre(t0, t1)],
		t0.size() == t1.size() and Chass.ecart_entre(t0, t1) >= 8.0 * 35.0)
	for k in zs:
		var zone: Rect2i = c["pnj"][k]["zone"]
		var plus_haut_tour := 1000
		for r in rs:
			for cc in o.tour_de_la_ronde(c, r):
				if zone.position.x <= cc.x and cc.x < zone.end.x:
					plus_haut_tour = mini(plus_haut_tour, cc.y)
		_check("la zone du garde %d (%s) est au nord de la ronde de son aile (la zone finit à la rangée %d, la ronde commence à la rangée %d)" % [k + 1, str(zone), zone.end.y - 1, plus_haut_tour], zone.end.y <= plus_haut_tour)
		_check("… la zone est vaste : %d cases praticables (au moins 250)" % nav.cases_dans(zone).size(), nav.cases_dans(zone).size() >= 250)
	_check("quatre lampes aux flaques à part", (c["lampes"] as Array).size() == 4 and _flaques_a_part(c))


# ---------------------------------------------------------------------------
# 8.3 — La galerie des lampes
# ---------------------------------------------------------------------------

func _salle_3() -> void:
	print("\n--- 8.3 La galerie des lampes : un couloir de flaques ---")
	var c := o.ctx(2)
	var taille: Vector2i = c["taille"]
	var rs := _de(c, Profil.Deplacement.RONDE)
	_check("une galerie : %d cases de long pour %d de large (au moins 80 de long, trois fois plus long que large)" % [taille.x, taille.y], taille.x >= 80 and taille.x >= 3 * taille.y)
	_check("sept lampes aux flaques à part, rangées sur deux files (nord et sud) et une au centre", (c["lampes"] as Array).size() == 7 and _flaques_a_part(c))
	var tours: Array = []
	for k in rs:
		tours.append(o.tour_de_la_ronde(c, k))
	_check("trois tours de même longueur : %d, %d et %d cases" % [tours[0].size(), tours[1].size(), tours[2].size()], tours[0].size() == tours[1].size() and tours[1].size() == tours[2].size() and tours[0].size() >= 60)
	var ok_tiers := true
	for i in 3:
		for cc: Vector2i in tours[i]:
			ok_tiers = ok_tiers and cc.x * 3 / taille.x == i
	_check("chaque tour reste dans son tiers de la galerie : les trois tiers sont gardés, sans recouvrement", ok_tiers)
	var ecarts_ok := true
	var pire := INF
	for i in 3:
		for j in range(i + 1, 3):
			var e := Chass.ecart_entre(tours[i], tours[j])
			pire = minf(pire, e)
			ecarts_ok = ecarts_ok and e >= 3.0 * 35.0
	_check("les tours ne se touchent jamais : au plus près %.0f px (au moins 3 cases), et simulés à vitesse constante %.0f px (au moins 100)" % [pire, o.ecart_minimal_des_rondes(c, rs)], ecarts_ok and o.ecart_minimal_des_rondes(c, rs) >= 100.0)
	for i in 3:
		_check("la ronde %d passe dans des flaques : %d cases éclairées de son tour (au moins 8)" % [i + 1, Chass.combien_claires(o, c, o.cases_du_tour(tours[i]))], Chass.combien_claires(o, c, o.cases_du_tour(tours[i])) >= 8)
	# La bande du milieu : sombre sur la plus grande part de la longueur, fermée au centre par la septième lampe.
	var bande := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return cc.y >= 8 and cc.y <= 13)
	var sombre := bande.size() - Chass.combien_claires(o, c, bande)
	_check("la bande du milieu (6 rangées) reste noire : %d cases sombres sur %d (au moins 80 %%)" % [sombre, bande.size()], float(sombre) >= 0.8 * float(bande.size()))
	var centre := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return cc.y >= 8 and cc.y <= 13 and cc.x >= taille.x / 2 - 4 and cc.x <= taille.x / 2 + 4)
	_check("… sauf au centre, où la septième lampe la ferme : %d cases de la bande y sont éclairées (au moins 20)" % Chass.combien_claires(o, c, centre), Chass.combien_claires(o, c, centre) >= 20)
	_check("le joueur part à l'extrémité ouest, dans le noir, à %.0f px de la première ronde (plus de 5 cases)" % o.distance_au_tour(c["depart_pos"], tours[0]), c["depart"].x <= 3 and not o.eclaire_par_lampe(c, c["depart_pos"]) and o.distance_au_tour(c["depart_pos"], tours[0]) > 5.0 * 35.0)


# ---------------------------------------------------------------------------
# 8.4 — Le magnésium
# ---------------------------------------------------------------------------

func _salle_4() -> void:
	print("\n--- 8.4 Le magnésium : trois chambres, deux goulets, une lampe au milieu de chacun ---")
	var c := o.ctx(3)
	var nav: Nav = c["nav"]
	var cloisons := Chass.rangees_de_cloison(c)
	_check("deux cloisons de deux rangées coupent la salle (rangées %s)" % str(cloisons), cloisons.size() == 4 and cloisons[1] == cloisons[0] + 1 and cloisons[3] == cloisons[2] + 1)
	var goulets := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return cc.y in cloisons)
	var morceaux := Chass.composantes(goulets)
	_check("deux goulets de quatre cases de large : %d morceaux de %s cases (8 chacun : 4 de large, 2 de profondeur)" % [morceaux.size(), str([(morceaux[0] as Array).size(), (morceaux[1] as Array).size()]) if morceaux.size() >= 2 else "?"],
		morceaux.size() == 2 and (morceaux[0] as Array).size() == 8 and (morceaux[1] as Array).size() == 8)
	var chambres := Chass.composantes(Chass.cases_ou(c, func(cc: Vector2i) -> bool: return not (cc.y in cloisons)))
	_check("trois chambres d'un seul tenant (%d), chacune de plus de 500 cases" % chambres.size(), chambres.size() == 3 and (chambres[0] as Array).size() >= 500 and (chambres[1] as Array).size() >= 500 and (chambres[2] as Array).size() >= 500)
	# Les goulets sont éclairés, et aux deux bouts opposés : on traverse chaque chambre en diagonale.
	var cx: Array[float] = []
	for m in morceaux:
		var s := 0.0
		for cc: Vector2i in m:
			s += float(cc.x)
		cx.append(s / float((m as Array).size()))
		_check("un goulet éclairé en entier : %d de ses %d cases sont sous une lampe" % [Chass.combien_claires(o, c, m), (m as Array).size()], Chass.combien_claires(o, c, m) == (m as Array).size())
	_check("aux deux bouts opposés de la salle : x = %.0f et %.0f (plus de 25 cases d'écart)" % [cx[0], cx[1]], absf(cx[0] - cx[1]) >= 25.0)
	for m in morceaux:
		var y0 := 1000
		var y1 := -1
		var x_milieu := 0.0
		for cc: Vector2i in m:
			y0 = mini(y0, cc.y)
			y1 = maxi(y1, cc.y)
			x_milieu += float(cc.x)
		x_milieu /= float((m as Array).size())
		var a := Vector2(x_milieu + 0.5, float(y0 - 6) + 0.5) * 35.0
		var b := Vector2(x_milieu + 0.5, float(y1 + 6) + 0.5) * 35.0
		_check("traverser tout droit le goulet (de 6 cases en deçà à 6 cases au-delà) se fait dans la lumière", Chass.segment_en_lumiere(o, c, a, b))
	var du_goulet_a_l_autre := Chass.distance_a_pied(o, c, Vector2i(int(cx[0]), cloisons[0]), Vector2i(int(cx[1]), cloisons[2]))
	_check("d'un goulet à l'autre il faut %.0f px de marche (plus de 35 cases)" % du_goulet_a_l_autre, du_goulet_a_l_autre >= 35.0 * 35.0)
	var zs := _de(c, Profil.Deplacement.ZONE)
	var libres := _de(c, Profil.Deplacement.LIBRE)
	var chambre_du_joueur: Array = []
	for m in chambres:
		if (m as Array).has(c["depart"]):
			chambre_du_joueur = m
	var gardes_dans_les_deux_autres := zs.size() == 2
	for k in zs:
		var sa_chambre: Array = []
		for m in chambres:
			if (m as Array).has(c["pnj"][k]["case"]):
				sa_chambre = m
		gardes_dans_les_deux_autres = gardes_dans_les_deux_autres and not sa_chambre.is_empty() and sa_chambre != chambre_du_joueur
		for cc in nav.cases_dans(c["pnj"][k]["zone"]):
			gardes_dans_les_deux_autres = gardes_dans_les_deux_autres and sa_chambre.has(cc)
	_check("un garde dans chacune des deux autres chambres, dont la zone ne sort pas de sa chambre ; aucun dans celle du joueur", gardes_dans_les_deux_autres and not chambre_du_joueur.is_empty())
	_check("le chasseur libre part dans la chambre du joueur, de l'autre côté : à %.0f px à pied (plus de 40 cases)" % Chass.distance_a_pied(o, c, c["depart"], c["pnj"][libres[0]]["case"]),
		chambre_du_joueur.has(c["pnj"][libres[0]]["case"]) and Chass.distance_a_pied(o, c, c["depart"], c["pnj"][libres[0]]["case"]) >= 40.0 * 35.0)
	_check("trois lampes aux flaques à part : deux dans les goulets, une au milieu de la chambre du haut", (c["lampes"] as Array).size() == 3 and _flaques_a_part(c))
	_check("des piliers pour se couvrir : %d îlots (au moins 10)" % Chass.ilots(c).size(), Chass.ilots(c).size() >= 10)


# ---------------------------------------------------------------------------
# 8.5 — L'usine
# ---------------------------------------------------------------------------

func _salle_5() -> void:
	print("\n--- 8.5 L'usine : vingt machines, deux postes sur les allées, trois rondes autour de trois machines ---")
	var c := o.ctx(4)
	var postes := _de(c, Profil.Deplacement.IMMOBILE)
	var rondes := _de(c, Profil.Deplacement.RONDE)
	var ilots := Chass.ilots(c)
	var tailles := {}
	for m in ilots:
		tailles[(m as Array).size()] = true
	_check("vingt machines de 32 cases : %d îlots, de tailles %s" % [ilots.size(), str(tailles.keys())], ilots.size() == 20 and tailles.size() == 1 and tailles.has(32))
	for k in postes:
		var p: Dictionary = c["pnj"][k]
		_check("le poste %d est tout au nord (rangée %d) et sous une lampe : on le voit, il voit ce qui est éclairé" % [k + 1, p["case"].y], p["case"].y <= 4 and o.eclaire_par_lampe(c, p["pos"]))
		# Son allée : les cases à moins de 3 cases de sa colonne, sous la première rangée de machines.
		var allee := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return absi(cc.x - p["case"].x) <= 2 and cc.y >= 8)
		var vues := 0
		for cc in allee:
			if o.ligne_de_vue(c, p["pos"], Nav.centre_de_la_case(cc)):
				vues += 1
		_check("le poste %d regarde toute son allée : %d cases sur %d sont en ligne de vue (au moins 80 %%)" % [k + 1, vues, allee.size()], float(vues) >= 0.8 * float(allee.size()))
	var tours: Array = []
	for k in rondes:
		tours.append(o.tour_de_la_ronde(c, k))
	_check("trois tours de même longueur : %d, %d et %d cases" % [tours[0].size(), tours[1].size(), tours[2].size()], tours[0].size() == tours[1].size() and tours[1].size() == tours[2].size())
	var pire := INF
	for i in 3:
		for j in range(i + 1, 3):
			pire = minf(pire, Chass.ecart_entre(tours[i], tours[j]))
	_check("… qui ne se touchent jamais : %.0f px au plus près (au moins 8 cases)" % pire, pire >= 8.0 * 35.0)
	for i in 3:
		var boite := Chass.boite_de_la_ronde(c, rondes[i])
		_check("la ronde %d fait le tour d'UNE machine : %d machine(s) dans son rectangle" % [i + 1, Chass.ilots_dans(c, boite)], Chass.ilots_dans(c, boite) == 1)
		_check("… et passe sous une lampe : %d cases éclairées de son tour (au moins 4)" % Chass.combien_claires(o, c, o.cases_du_tour(tours[i])), Chass.combien_claires(o, c, o.cases_du_tour(tours[i])) >= 4)
	_check("cinq lampes aux flaques à part", (c["lampes"] as Array).size() == 5 and _flaques_a_part(c))
	_check("le départ est au sud, au milieu : à %.0f px de la ronde la plus proche (plus de 8 cases)" % minf(minf(o.distance_au_tour(c["depart_pos"], tours[0]), o.distance_au_tour(c["depart_pos"], tours[1])), o.distance_au_tour(c["depart_pos"], tours[2])),
		c["depart"].y >= c["taille"].y - 4 and minf(minf(o.distance_au_tour(c["depart_pos"], tours[0]), o.distance_au_tour(c["depart_pos"], tours[1])), o.distance_au_tour(c["depart_pos"], tours[2])) > 8.0 * 35.0)


# ---------------------------------------------------------------------------
# 8.6 — Le cloître
# ---------------------------------------------------------------------------

func _salle_6() -> void:
	print("\n--- 8.6 Le cloître : une cour éclairée, une galerie noire qui fait le tour ---")
	var c := o.ctx(5)
	var taille: Vector2i = c["taille"]
	var cour := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return cc.x >= 13 and cc.x <= taille.x - 14 and cc.y >= 13 and cc.y <= taille.y - 14)
	var galerie := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return cc.x <= 10 or cc.x >= taille.x - 11 or cc.y <= 10 or cc.y >= taille.y - 11)
	_check("une cour de %d cases et une galerie de %d cases" % [cour.size(), galerie.size()], cour.size() >= 1000 and galerie.size() >= 1800)
	var lit_cour := Chass.combien_claires(o, c, cour)
	_check("la cour est éclairée : %d cases sur %d (au moins 15 %%)" % [lit_cour, cour.size()], float(lit_cour) >= 0.15 * float(cour.size()))
	_check("la galerie reste noire : %d cases éclairées (au plus 2 %%)" % Chass.combien_claires(o, c, galerie), float(Chass.combien_claires(o, c, galerie)) <= 0.02 * float(galerie.size()))
	_check("quatre lampes, toutes dans la cour, aux flaques à part", (c["lampes"] as Array).size() == 4 and _flaques_a_part(c) and Chass.combien_claires(o, c, cour) > 0)
	var dans_la_cour := true
	for l: Dictionary in c["lampes"]:
		dans_la_cour = dans_la_cour and l["case"].x >= 13 and l["case"].x <= taille.x - 14 and l["case"].y >= 13 and l["case"].y <= taille.y - 14
	_check("… et chacune se tient dans la cour, pas dans l'arcade", dans_la_cour)
	_check("des arcades : %d piliers de 4 cases (au moins 24), des baies de quatre cases entre eux" % Chass.ilots(c).size(), Chass.ilots(c).size() >= 24)
	_check("la galerie fait le tour : un seul morceau de %d cases, un anneau qu'on parcourt sans fin" % galerie.size(), Chass.composantes(galerie).size() == 1)
	_check("la cour communique avec la galerie par les baies : on va du départ au milieu de la cour (%.0f px à pied)" % Chass.distance_a_pied(o, c, c["depart"], Vector2i(taille.x / 2, 20)),
		Chass.distance_a_pied(o, c, c["depart"], Vector2i(taille.x / 2, 20)) > 0.0)
	var zs := _de(c, Profil.Deplacement.ZONE)
	var libres := _de(c, Profil.Deplacement.LIBRE)
	var ok := zs.size() == 2
	for k in zs:
		var z: Rect2i = c["pnj"][k]["zone"]
		ok = ok and (z.size.x <= 12) and (z.size.y >= 50)
	_check("deux gardes, un dans chaque galerie latérale : des zones étroites et longues (au plus 12 de large, au moins 50 de long)", ok)
	var zone_a: Rect2i = c["pnj"][zs[0]]["zone"]
	var zone_b: Rect2i = c["pnj"][zs[1]]["zone"]
	_check("les deux zones sont aux deux côtés de la cour : l'une à l'ouest (x < %d), l'autre à l'est (x ≥ %d)" % [13, taille.x - 13], zone_a.end.x <= 13 and zone_b.position.x >= taille.x - 13)
	_check("deux chasseurs libres : l'un dans la galerie nord, l'autre dans la cour", libres.size() == 2 and ((c["pnj"][libres[0]]["case"].y <= 10 and cour.has(c["pnj"][libres[1]]["case"])) or (c["pnj"][libres[1]]["case"].y <= 10 and cour.has(c["pnj"][libres[0]]["case"]))))
	_check("le joueur part dans la galerie sud, dans le noir", c["depart"].y >= taille.y - 11 and not o.eclaire_par_lampe(c, c["depart_pos"]))
	_check("un bassin au milieu de la cour : %d cases de mur bas" % Chass.murets(c).size(), Chass.murets(c).size() >= 50)


# ---------------------------------------------------------------------------
# 8.7 — Le bunker
# ---------------------------------------------------------------------------

func _salle_7() -> void:
	print("\n--- 8.7 Le bunker : six salles noires autour d'un couloir ---")
	var c := o.ctx(6)
	var nav: Nav = c["nav"]
	var bandes := Chass.rangees_de_cloison(c, 0.7)
	_check("deux cloisons de deux rangées (rangées %s) ferment les salles sur le couloir" % str(bandes), bandes.size() == 4 and bandes[1] == bandes[0] + 1 and bandes[3] == bandes[2] + 1)
	if bandes.size() != 4:
		return
	var couloir := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return cc.y > bandes[1] and cc.y < bandes[2])
	var portes := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return cc.y in bandes)
	var morceaux_portes := Chass.composantes(portes)
	var larges := true
	for m in morceaux_portes:
		larges = larges and (m as Array).size() == 8
	_check("un couloir de %d cases, et six portes de quatre cases (%d morceaux de 8 cases : 4 de large, 2 de profondeur)" % [couloir.size(), morceaux_portes.size()], couloir.size() >= 250 and morceaux_portes.size() == 6 and larges)
	var salles := Chass.composantes(Chass.cases_ou(c, func(cc: Vector2i) -> bool: return cc.y < bandes[0] or cc.y > bandes[3]))
	var tailles: Array[int] = []
	for m in salles:
		tailles.append((m as Array).size())
	_check("six salles d'un seul tenant, chacune de plus de 250 cases (%s)" % str(tailles), salles.size() == 6 and tailles.min() >= 250)
	var dans_les_salles := 0
	for m in salles:
		dans_les_salles += Chass.combien_claires(o, c, m)
	_check("toutes les salles sont NOIRES : %d cases éclairées dans les six salles" % dans_les_salles, dans_les_salles == 0)
	_check("deux lampes, aux deux bouts du couloir : %d et %d cases du couloir éclairées (au moins 10), rien d'autre" % [Chass.combien_claires(o, c, couloir), Chass.combien_claires(o, c, portes)],
		(c["lampes"] as Array).size() == 2 and Chass.combien_claires(o, c, couloir) >= 10 and _flaques_a_part(c))
	var xs: Array[int] = []
	for l: Dictionary in c["lampes"]:
		xs.append(l["case"].x)
	_check("… aux deux extrémités du couloir (x = %s)" % str(xs), xs.min() <= 6 and xs.max() >= c["taille"].x - 7)
	# Qui est dans quelle salle.
	var occupee := {}
	var gardes := _de(c, Profil.Deplacement.ZONE)
	var postes := _de(c, Profil.Deplacement.IMMOBILE)
	for k in gardes + postes:
		for i in salles.size():
			if (salles[i] as Array).has(c["pnj"][k]["case"]):
				occupee[i] = int(occupee.get(i, 0)) + 1
	var tous_un := true
	for v in occupee.values():
		tous_un = tous_un and int(v) == 1
	_check("cinq PNJ dans cinq salles différentes, une par salle (%d salles occupées)" % occupee.size(), occupee.size() == 5 and tous_un)
	var depart_salle := -1
	for i in salles.size():
		if (salles[i] as Array).has(c["depart"]):
			depart_salle = i
	_check("le joueur part dans la sixième, la seule vide", depart_salle >= 0 and not occupee.has(depart_salle))
	for k in gardes:
		var z: Rect2i = c["pnj"][k]["zone"]
		var dedans := true
		var sa_salle: Array = []
		for s in salles:
			if (s as Array).has(c["pnj"][k]["case"]):
				sa_salle = s
		for cc in nav.cases_dans(z):
			dedans = dedans and sa_salle.has(cc)
		_check("le garde %d erre dans sa salle seule : sa zone %s n'en sort pas" % [k + 1, str(z)], dedans and nav.cases_dans(z).size() >= 200)
		_check("garde %d : la règle de la mine peut se déclencher depuis sa zone (une place à 250-450 px, ligne dégagée)" % (k + 1), _regle_possible(c, o.cases_de_la_zone_atteignables(c, k)))
	for k in postes:
		var p: Dictionary = c["pnj"][k]
		_check("le poste %d n'a que ses oreilles : il n'entend que, il ne voit pas, il tire" % (k + 1), (not p["profil"].voit) and p["profil"].entend and p["profil"].tire and p["profil_nom"] == "immobile_entend_normal")
		_check("… et il est dans le noir, au milieu d'une salle noire", not o.eclaire_par_lampe(c, p["pos"]))
	for k in postes:
		var p: Dictionary = c["pnj"][k]
		var d_porte := INF
		for cc in portes:
			d_porte = minf(d_porte, Nav.centre_de_la_case(cc).distance_to(p["pos"]))
		_check("poste %d : de la porte de sa salle il y a %.0f px — un pas debout s'y entend (portée nette %.0f px), un pas accroupi non (%.0f px) : on entre en s'accroupissant" % [k + 1, d_porte, o.portee_pas_debout_net, o.portee_pas_accroupi_net],
			d_porte <= o.portee_pas_debout_net + 2.0 * 35.0 and d_porte > 2.0 * o.portee_pas_accroupi_net)
	_check("des piliers dans chaque salle : %d îlots (au moins 6)" % Chass.ilots(c).size(), Chass.ilots(c).size() >= 6)


# ---------------------------------------------------------------------------
# 8.8 — Le quartier
# ---------------------------------------------------------------------------

func _salle_8() -> void:
	print("\n--- 8.8 Le quartier : seize blocs, des rues, deux rondes de même tour ---")
	var c := o.ctx(7)
	var rondes := _de(c, Profil.Deplacement.RONDE)
	var postes := _de(c, Profil.Deplacement.IMMOBILE)
	var libres := _de(c, Profil.Deplacement.LIBRE)
	var ilots := Chass.ilots(c)
	var tailles := {}
	for m in ilots:
		tailles[(m as Array).size()] = true
	_check("seize blocs de 96 cases : %d îlots, de tailles %s" % [ilots.size(), str(tailles.keys())], ilots.size() == 16 and tailles.size() == 1 and tailles.has(96))
	_check("tout ce qui bouge porte la mine : les deux rondes et les deux chasseurs sont équipés, les postes non", _tous_equipes(c, rondes) and _tous_equipes(c, libres))
	var t0 := o.tour_de_la_ronde(c, rondes[0])
	var t1 := o.tour_de_la_ronde(c, rondes[1])
	_check("deux tours de MÊME longueur : %d et %d cases" % [t0.size(), t1.size()], t0.size() == t1.size() and t0.size() >= 60)
	_check("… qui ne se touchent jamais : %.0f px entre eux (au moins 8 cases)" % Chass.ecart_entre(t0, t1), Chass.ecart_entre(t0, t1) >= 8.0 * 35.0)
	for i in 2:
		_check("la ronde %d fait le tour d'UN bloc : %d bloc(s) dans son rectangle" % [i + 1, Chass.ilots_dans(c, Chass.boite_de_la_ronde(c, rondes[i]))], Chass.ilots_dans(c, Chass.boite_de_la_ronde(c, rondes[i])) == 1)
	_check("six lampes aux flaques à part", (c["lampes"] as Array).size() == 6 and _flaques_a_part(c))
	for k in postes:
		var p: Dictionary = c["pnj"][k]
		var rue := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return absi(cc.x - p["case"].x) <= 2 or absi(cc.y - p["case"].y) <= 2)
		var claires := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return o.eclaire_par_lampe(c, Nav.centre_de_la_case(cc)))
		var voit := Chass.part_en_vue(o, c, p["pos"], claires, 22.0 * 35.0)
		_check("le poste %d est sous une lampe, dans une rue : il voit %.0f %% des cases éclairées à 22 cases (au moins 8 %%)" % [k + 1, 100.0 * voit], o.eclaire_par_lampe(c, p["pos"]) and rue.size() > 0 and voit >= 0.08)
	var pire := INF
	for k in libres:
		pire = minf(pire, Chass.distance_a_pied(o, c, c["depart"], c["pnj"][k]["case"]))
	_check("les deux chasseurs partent aux deux coins du nord, à %.0f px à pied du joueur au moins (plus de 55 cases)" % pire, pire >= 55.0 * 35.0 and c["pnj"][libres[0]]["case"].y <= 6 and c["pnj"][libres[1]]["case"].y <= 6)
	var sombres := Chass.sombres(o, c)
	var morceau: Array = []
	for m in Chass.composantes(sombres):
		if (m as Array).has(c["depart"]):
			morceau = m
	_check("les rues forment un seul réseau d'ombre : le départ en tient %d cases sur %d sombres (au moins 90 %%)" % [morceau.size(), sombres.size()], float(morceau.size()) >= 0.9 * float(sombres.size()))
	for k in rondes + libres:
		_check("PNJ %d : la règle de la mine peut se déclencher" % (k + 1), _regle_possible(c, nav_cases(c, k)))


## Les cases où se tient un PNJ : son tour, sa zone, ou toute la salle.
func nav_cases(c: Dictionary, k: int) -> Array[Vector2i]:
	var p: Dictionary = c["pnj"][k]
	var d: int = p["profil"].deplacement
	if d == Profil.Deplacement.RONDE:
		return o.cases_du_tour(o.tour_de_la_ronde(c, k))
	if d == Profil.Deplacement.ZONE:
		return o.cases_de_la_zone_atteignables(c, k)
	return (c["nav"] as Nav).cases_praticables()


# ---------------------------------------------------------------------------
# 8.9 — La salle pleine
# ---------------------------------------------------------------------------

func _salle_9() -> void:
	print("\n--- 8.9 La salle pleine : la plus grande salle du jeu ---")
	var c := o.ctx(8)
	var taille: Vector2i = c["taille"]
	var duel := Chass.aire_du_plus_grand_duel()
	_check("%d × %d cases : %d fois la plus grande carte de duel (au moins 7)" % [taille.x, taille.y, Chass.aire(c) / duel], Chass.aire(c) >= 7 * duel)
	var cloisons_h := Chass.rangees_de_cloison(c, 0.85)
	_check("une cloison horizontale de deux rangées coupe la salle en deux (rangées %s)" % str(cloisons_h), cloisons_h.size() == 2 and cloisons_h[1] == cloisons_h[0] + 1)
	# Les quatre halls : les cases hors des deux cloisons, coupées en quatre morceaux ; les portes sont les cases praticables des cloisons.
	var murs := {}
	for m in Codec.get_wall_cells(c["carte"]):
		murs[m] = true
	var col_v := -1
	for x in range(1, taille.x - 1):
		var n := 0
		for y in range(1, taille.y - 1):
			if murs.has(Vector2i(x, y)):
				n += 1
		if float(n) >= 0.8 * float(taille.y - 2):
			col_v = x
			break
	_check("et une cloison verticale (à la colonne %d) : quatre halls" % col_v, col_v > 0)
	var portes := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return cc.y in cloisons_h or cc.x == col_v or cc.x == col_v + 1)
	var morceaux_portes := Chass.composantes(portes)
	_check("quatre portes de six cases de large : %d morceaux de portes (12 cases chacun : 6 de large, 2 de profondeur)" % morceaux_portes.size(), morceaux_portes.size() == 4 and (morceaux_portes[0] as Array).size() == 12 and (morceaux_portes[1] as Array).size() == 12 and (morceaux_portes[2] as Array).size() == 12 and (morceaux_portes[3] as Array).size() == 12)
	var halls := Chass.composantes(Chass.cases_ou(c, func(cc: Vector2i) -> bool: return not (cc.y in cloisons_h) and cc.x != col_v and cc.x != col_v + 1))
	var grands := 0
	for h in halls:
		grands += 1 if (h as Array).size() >= 1200 else 0
	_check("quatre halls d'un seul tenant, chacun de plus de 1 200 cases (%d halls, %d grands)" % [halls.size(), grands], halls.size() == 4 and grands == 4)
	# Deux lampes par hall.
	var par_hall := []
	var deux_chacun := true
	for h in halls:
		var n := 0
		for l: Dictionary in c["lampes"]:
			n += 1 if (h as Array).has(l["case"]) else 0
		par_hall.append(n)
		deux_chacun = deux_chacun and n == 2
	_check("huit lampes aux flaques à part, deux par hall (%s)" % str(par_hall), (c["lampes"] as Array).size() == 8 and _flaques_a_part(c) and deux_chacun)
	# Qui est où.
	var postes := _de(c, Profil.Deplacement.IMMOBILE)
	var zones := _de(c, Profil.Deplacement.ZONE)
	var rondes := _de(c, Profil.Deplacement.RONDE)
	var libres := _de(c, Profil.Deplacement.LIBRE)
	var hall_de := func(cc: Vector2i) -> int:
		for i in halls.size():
			if (halls[i] as Array).has(cc):
				return i
		return -1
	var h_depart: int = hall_de.call(c["depart"])
	var h_postes: Array = []
	for k in postes:
		h_postes.append(hall_de.call(c["pnj"][k]["case"]))
	var h_rondes: Array = []
	for k in rondes:
		h_rondes.append(hall_de.call(c["pnj"][k]["case"]))
	var h_zones: Array = []
	for k in zones:
		h_zones.append(hall_de.call(c["pnj"][k]["case"]))
	var h_libre: int = hall_de.call(c["pnj"][libres[0]]["case"])
	_check("les deux postes dans le même hall (%s), les deux rondes dans un même autre (%s), les deux gardes dans deux halls différents (%s)" % [str(h_postes), str(h_rondes), str(h_zones)],
		h_postes[0] == h_postes[1] and h_rondes[0] == h_rondes[1] and h_postes[0] != h_rondes[0] and h_zones[0] != h_zones[1] and h_zones[0] >= 0 and h_zones[1] >= 0)
	_check("le joueur part dans un hall qui a SON garde, et ce n'est ni celui des postes ni celui des rondes (hall %d)" % h_depart, h_zones.has(h_depart) and h_depart != h_postes[0] and h_depart != h_rondes[0])
	_check("le chasseur de niveau DIFFICILE part dans le hall de l'autre garde, en diagonale du joueur : hall %d, à %.0f px à pied (plus de 90 cases)" % [h_libre, Chass.distance_a_pied(o, c, c["depart"], c["pnj"][libres[0]]["case"])],
		h_libre != h_depart and h_zones.has(h_libre) and Chass.distance_a_pied(o, c, c["depart"], c["pnj"][libres[0]]["case"]) >= 90.0 * 35.0)
	_check("tout ce qui bouge porte la mine : deux gardes, deux rondes, un chasseur", _tous_equipes(c, zones) and _tous_equipes(c, rondes) and _tous_equipes(c, libres))
	var t0 := o.tour_de_la_ronde(c, rondes[0])
	var t1 := o.tour_de_la_ronde(c, rondes[1])
	_check("deux tours de même longueur (%d et %d cases) qui ne se touchent jamais (%.0f px, au moins 3 cases)" % [t0.size(), t1.size(), Chass.ecart_entre(t0, t1)], t0.size() == t1.size() and Chass.ecart_entre(t0, t1) >= 3.0 * 35.0)
	_check("… et simulés à vitesse constante, ils restent à %.0f px l'un de l'autre au plus près (au moins 100)" % o.ecart_minimal_des_rondes(c, rondes), o.ecart_minimal_des_rondes(c, rondes) >= 100.0)
	for k in postes:
		_check("le poste %d est sous une lampe" % (k + 1), o.eclaire_par_lampe(c, c["pnj"][k]["pos"]))
	# L'allumage par proximité : au départ, la plupart des lampes sont éteintes (plus loin que leur rayon d'allumage de tout joueur).
	var eteintes := 0
	for l: Dictionary in c["lampes"]:
		if not PlafT.doit_etre_allume(false, l["pos"], l["rayon_px"], [c["depart_pos"]]):
			eteintes += 1
	_check("l'allumage par proximité : %d lampes sur 8 sont éteintes au départ (au moins 4) — la salle est plus vaste que ce qu'un écran en éclaire" % eteintes, eteintes >= 4)
	var sombres := Chass.sombres(o, c)
	var morceau: Array = []
	for m in Chass.composantes(sombres):
		if (m as Array).has(c["depart"]):
			morceau = m
	_check("le noir est d'un seul tenant : le départ en tient %d cases sur %d (au moins 90 %%)" % [morceau.size(), sombres.size()], float(morceau.size()) >= 0.9 * float(sombres.size()))
	for k in rondes + zones + libres:
		_check("PNJ %d : la règle de la mine peut se déclencher" % (k + 1), _regle_possible(c, nav_cases(c, k)))


# ---------------------------------------------------------------------------
# 8.10 — l'Allumeur
# ---------------------------------------------------------------------------

func _boss() -> void:
	print("\n--- 8.10 L'Allumeur : un duel de part et d'autre d'un goulet ---")
	var c := o.ctx(9)
	var p: Dictionary = c["pnj"][0]
	_check("le boss est le profil `boss` réglé à l'Allumeur : de la vie en plus (`REGLAGES_BOSS`)", p["profil"].vie > 100.0)
	var taille: Vector2i = c["taille"]
	var murs := {}
	for m in Codec.get_wall_cells(c["carte"]):
		murs[m] = true
	var colonnes: Array[int] = []
	for x in range(2, taille.x - 2):
		var n := 0
		for y in range(1, taille.y - 1):
			if murs.has(Vector2i(x, y)):
				n += 1
		if float(n) >= 0.7 * float(taille.y - 2):
			colonnes.append(x)
	_check("une cloison de deux colonnes coupe l'arène en deux (colonnes %s)" % str(colonnes), colonnes.size() == 2 and colonnes[1] == colonnes[0] + 1)
	var goulet := Chass.cases_ou(c, func(cc: Vector2i) -> bool: return cc.x in colonnes)
	_check("percée d'un goulet de quatre cases en son milieu : %d cases (8), au centre de la hauteur" % goulet.size(), goulet.size() == 8 and Chass.composantes(goulet).size() == 1)
	var ys: Array[int] = []
	for cc in goulet:
		ys.append(cc.y)
	_check("… centré : de la rangée %d à la rangée %d (symétrique du nord au sud)" % [ys.min(), ys.max()], ys.min() + ys.max() == taille.y - 1)
	_check("le joueur et le boss ne se voient pas d'emblée : la cloison coupe leur ligne de vue", not o.ligne_de_vue(c, c["depart_pos"], p["pos"]))
	_check("… et chacun est de son côté : le joueur à l'ouest de la cloison, le boss à l'est", c["depart"].x < colonnes[0] and p["case"].x > colonnes[1])
	var d := Chass.distance_a_pied(o, c, c["depart"], p["case"])
	var droit: float = (c["depart_pos"] as Vector2).distance_to(p["pos"])
	_check("il faut passer le goulet : %.0f px à pied pour %.0f px en ligne droite (au moins ×1,0 — l'axe est libre ; et la mine y est redoutable)" % [d, droit], d >= droit)
	var lumiere_du_goulet := Chass.combien_claires(o, c, goulet)
	_check("le goulet n'est PAS éclairé : les lampes sont chacune de leur côté, il se traverse dans le noir — la mine l'éclaire d'un coup (%d cases éclairées)" % lumiere_du_goulet, lumiere_du_goulet == 0)
	var murets := Chass.murets(c)
	_check("quatre murets bas encadrent le goulet (%d cases)" % murets.size(), murets.size() == 16)
