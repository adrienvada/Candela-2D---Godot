## La garde de MARCHE des chapitres 7 à 9 — chantier SOLO, étape S8 (lot 2) : les PNJ libres, les rondes et les zones se parcourent pour de vrai, avec le vrai corps.
##
## `test_chapitres_marche` (le lot 1) joue chaque salle de ronde ou de zone des chapitres 1 à 3 : une ronde passe de son vrai corps par chacun de ses points et boucle, une zone n'est
## jamais quittée. Les chapitres 7 à 9 ajoutent ce que ce banc n'avait pas : des PNJ LIBRES (tout le chapitre 7, et des chasseurs dans les chapitres 8 et 9), et des salles de 100 × 80
## cases, des rondes de 100 cases et plus, des goulets de quatre cases et un passage de deux. Cette suite RÉUTILISE celle du lot 1 (elle en hérite : `_check`, les images, l'horloge
## fixe, la sortie) et n'en change que ce qu'il faut — `_run` (les chapitres 7 à 9), `_jouer` (les PNJ libres marchent aussi) et `_juger` (ce qu'on exige d'un PNJ libre).
## Le lot 1 n'est pas touché.
##
## Les PNJ sont désarmés et sourds-aveugles (`agit`, `tire`, `voit`, `entend` à faux) : ils marchent, ils ne réagissent à rien — c'est le déplacement qu'on mesure.
##
##   • RONDE et ZONE — comme au lot 1 : chaque point, la boucle, la zone jamais quittée, visitée pour un cinquième au moins ;
##   • LIBRE — le PNJ ne reste jamais immobile plus de trois secondes ; il parcourt au moins 60 % de la distance qu'une marche libre à son allure donne ; il ne sort jamais du sol
##     (la case sous son centre est libre à chaque image) ; il visite au moins 60 cases distinctes ; **dans une salle qui a un goulet ou un passage étroit (8.4, 8.7, 8.10, 9.10), il
##     le franchit** (le PNJ libre n'a pas de point d'arrivée : on le mesure par les cases où il passe) ;
##   • et, dans une même salle, deux rondes ne se traversent pas (au moins 20 px de centre à centre) ; deux PNJ libres non plus (un corps de 36 px : au moins 10 px).
##
## Chaque salle est jouée une fois, la graine du jeu fixée (`graine_du_bot`) : le résultat est le même à chaque lancement.
##
## ⚠️ **Se lance à pas d'image fixe** (`--fixed-fps 60`).
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_chapitres_marche_07_09.gd [-- --chapitre=8 --salle=4]
extends "res://tools/test_chapitres_marche.gd"

const SOLO_07_09 := "user://test_chapitres_marche_07_09_solo.cfg"
const DUREE_LIBRE_S := 30.0
## Une marche libre à l'allure du PNJ de ses chemins : au moins cette part de la distance qu'elle donne à vitesse pleine (les virages, les arrivées et l'anti-blocage en mangent).
const PART_DISTANCE_LIBRE := 0.6
const CASES_LIBRE_MIN := 60
const ECART_LIBRES_MIN_PX := 10.0

## Les salles où le PNJ libre doit franchir un passage étroit : [chapitre, numéro de salle, axe, colonne ou rangée de la cloison]. `axe` : « x » (cloison verticale à cette colonne)
## ou « y » (une cloison horizontale à cette rangée). Le passage est franchi quand le PNJ a été vu des deux côtés de la cloison. Une seule cloison par salle : un PNJ libre n'a pas de
## point d'arrivée, et exiger qu'il aille au-delà de la seconde en 30 s serait exiger du hasard (8.4 en a deux ; les portes du bunker n'ont pas de PNJ libre).
const PASSAGES := [
	[7, 2, "x", 17],
	[8, 4, "y", 33],
	[8, 10, "x", 15],
	[9, 10, "x", 12],
]


func _run() -> void:
	print("=== LA MARCHE DES PNJ LIBRES, DES RONDES ET DES ZONES (S8, lot 2), LE VRAI CORPS ===")
	await process_frame
	var horloge_fixe := await _horloge_fixe()
	_check("l'horloge est fixe (--fixed-fps 60) : une image = un pas de physique", horloge_fixe, "lancer avec --fixed-fps 60")
	if not horloge_fixe:
		_sortir()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chapitre="):
			_seulement_chapitre = int(a.substr(11))
		if a.begins_with("--salle="):
			_seulement_salle = int(a.substr(8)) - 1
		if a.begins_with("--duree="):
			_duree_max = float(a.substr(8))
	_effacer(SOLO_07_09)
	root.get_node("GameSettings").mode_iso = false
	prog = Progression.new(SOLO_07_09)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	ui = main.ui
	ui.aventure_progression = prog
	main.archiver_les_matchs = false
	Format.oublier_le_cache()
	for chap in [7, 8, 9]:
		if _seulement_chapitre >= 0 and chap != _seulement_chapitre:
			continue
		var chapitre := Format.charger_chapitre("res://assets/solo/chapitre_%02d" % chap)
		_check("le chapitre %d se charge" % chap, not chapitre.is_empty())
		if chapitre.is_empty():
			continue
		for c in chap:
			prog.terminer_chapitre(c)
		for i in (chapitre["niveaux"] as Array).size():
			if _seulement_salle >= 0 and i != _seulement_salle:
				continue
			await _jouer(chap, chapitre, i)
	_effacer(SOLO_07_09)
	main.queue_free()
	await _images(2)
	_sortir()


# ---------------------------------------------------------------------------
# UNE SALLE
# ---------------------------------------------------------------------------

func _jouer(chap: int, chapitre: Dictionary, i: int) -> void:
	var nom := "%d.%d" % [chap, i + 1]
	for k in i:
		prog.reussir_niveau(chap, k)
	main.graine_du_bot = 4242
	main.demarrer_l_aventure(chapitre, i, "pistolet", prog)
	await _images(3)
	var partie: Node = main.aventure
	var niveau: Dictionary = chapitre["niveaux"][i]
	if partie == null:
		_check("%s : la salle se pose" % nom, false)
		return
	await _jusqua(func() -> bool: return partie.phase == PH_JEU, 400)
	main.p1.hp = 100000.0
	var nav := Nav.depuis_carte(niveau["carte"])
	var marcheurs: Array = []
	var duree := 0.0
	for k in partie.pnj.size():
		var entree: Dictionary = niveau["pnj"][k]
		var pnj: Node = partie.pnj[k]
		var bot := pnj.input_provider as BotInputProvider
		var allure_du_profil: float = bot.profil.allure   # lue AVANT tout : c'est l'allure du catalogue, celle qu'on exige du corps
		bot.profil.agit = false
		bot.profil.tire = false
		bot.profil.voit = false
		bot.profil.entend = false
		var d: int = bot.profil.deplacement
		if d == Profil.Deplacement.IMMOBILE:
			continue
		var m := {"k": k, "pnj": pnj, "entree": entree, "deplacement": d, "visites": {}, "retours": 0, "loin_du_depart": false, "immobile": 0.0, "immobile_max": 0.0,
			"derniere": pnj.global_position, "cases": {}, "hors_zone": 0.0, "dernier_point": -1, "distance": 0.0, "sur_le_vide": 0, "allure": allure_du_profil, "cote": {}}
		marcheurs.append(m)
		if d == Profil.Deplacement.RONDE:
			var longueur := 0.0
			var pts: Array = entree["ronde"]
			for j in pts.size():
				longueur += float(nav.chemin(pts[j], pts[(j + 1) % pts.size()]).size() - 1)
			duree = maxf(duree, longueur * 35.0 / (Profil.pnj_nomme(String(entree["profil_nom"])).allure * 260.0) * TOURS + 2.0)
		elif d == Profil.Deplacement.LIBRE:
			duree = maxf(duree, DUREE_LIBRE_S)
	if marcheurs.is_empty():
		return
	duree = clampf(maxf(duree, 20.0), 20.0, _duree_max)
	if _duree_max > DUREE_MAX_S:
		duree = _duree_max
	var ecart_rondes := INF
	var ecart_libres := INF
	var images := int(duree * 60.0)
	for _t in images:
		await physics_frame
		for m in marcheurs:
			_suivre(m, 1.0 / 60.0)
			var cc := Nav.case_du_monde((m["pnj"] as Node2D).global_position)
			if not nav.est_libre(cc):
				m["sur_le_vide"] = int(m["sur_le_vide"]) + 1
		for a in marcheurs.size():
			for b in range(a + 1, marcheurs.size()):
				var d := (marcheurs[a]["pnj"] as Node2D).global_position.distance_to((marcheurs[b]["pnj"] as Node2D).global_position)
				if int(marcheurs[a]["deplacement"]) == Profil.Deplacement.RONDE and int(marcheurs[b]["deplacement"]) == Profil.Deplacement.RONDE:
					ecart_rondes = minf(ecart_rondes, d)
				elif int(marcheurs[a]["deplacement"]) == Profil.Deplacement.LIBRE and int(marcheurs[b]["deplacement"]) == Profil.Deplacement.LIBRE:
					ecart_libres = minf(ecart_libres, d)
	for m in marcheurs:
		_juger(nom, m, niveau)
		_passages(nom, chap, i + 1, m, niveau)
	if ecart_rondes < INF:
		_check("%s : deux rondes ne se traversent jamais (écart minimal %.0f px, au moins %.0f)" % [nom, ecart_rondes, ECART_MIN_PX], ecart_rondes >= ECART_MIN_PX)
	if ecart_libres < INF:
		_check("%s : deux PNJ libres ne se traversent jamais (écart minimal %.0f px, au moins %.0f)" % [nom, ecart_libres, ECART_LIBRES_MIN_PX], ecart_libres >= ECART_LIBRES_MIN_PX)
	main._on_main_menu_requested()
	await _images(3)


## Un pas de mesure : celui du lot 1, plus ce que demande un PNJ libre (la distance parcourue, de quel côté d'une cloison il a été).
func _suivre(m: Dictionary, dt: float) -> void:
	var pnj: Node2D = m["pnj"]
	var avant: Vector2 = m["derniere"]
	if int(m["deplacement"]) == Profil.Deplacement.LIBRE:
		(m["cases"] as Dictionary)[Nav.case_du_monde(pnj.global_position)] = true
		m["distance"] = float(m["distance"]) + pnj.global_position.distance_to(avant)
		var cc := Nav.case_du_monde(pnj.global_position)
		(m["cote"] as Dictionary)["x%d" % cc.x] = true
		(m["cote"] as Dictionary)["y%d" % cc.y] = true
		if pnj.global_position.distance_to(avant) < 0.3:
			m["immobile"] = float(m["immobile"]) + dt
			m["immobile_max"] = maxf(float(m["immobile_max"]), float(m["immobile"]))
		else:
			m["immobile"] = 0.0
		m["derniere"] = pnj.global_position
		return
	super._suivre(m, dt)


func _juger(nom: String, m: Dictionary, niveau: Dictionary) -> void:
	if int(m["deplacement"]) == Profil.Deplacement.ZONE:
		_juger_une_zone(nom, m, niveau)
		return
	if int(m["deplacement"]) != Profil.Deplacement.LIBRE:
		super._juger(nom, m, niveau)
		return
	var etiquette := "%s, PNJ %d (%s)" % [nom, int(m["k"]) + 1, m["entree"]["profil_nom"]]
	var duree := float(int(DUREE_LIBRE_S * 60.0)) / 60.0
	_check("%s : jamais immobile plus de %.0f s d'affilée (pire : %.1f s)" % [etiquette, IMMOBILE_MAX_S, float(m["immobile_max"])], float(m["immobile_max"]) <= IMMOBILE_MAX_S)
	var vitesse := float(m["allure"]) * 260.0
	var attendue := vitesse * duree * PART_DISTANCE_LIBRE
	_check("%s : marche pour de bon : %.0f px parcourus en %.0f s, au moins %.0f (%.0f %% de la vitesse pleine)" % [etiquette, float(m["distance"]), duree, attendue, 100.0 * PART_DISTANCE_LIBRE], float(m["distance"]) >= attendue)
	_check("%s : visite au moins %d cases distinctes (%d)" % [etiquette, CASES_LIBRE_MIN, (m["cases"] as Dictionary).size()], (m["cases"] as Dictionary).size() >= CASES_LIBRE_MIN)
	_check("%s : ne sort jamais du sol : la case sous son centre est libre à chaque image (%d images dans le mur)" % [etiquette, int(m["sur_le_vide"])], int(m["sur_le_vide"]) == 0)


## Une zone : celle du lot 1, avec une exigence qui tient compte de sa taille. Le lot 1 demande le cinquième des cases d'une zone en 45 s ; une zone de 1 600 cases (8.9) est
## hors de portée d'un corps qui marche à 0,6 de la vitesse pleine (156 px/s, soit ~200 cases en 45 s), sans que le PNJ erre mal. On exige donc le plus petit de deux nombres : le
## cinquième des cases, ou `CASES_LIBRE_MIN` cases distinctes — « il ne reste pas dans un coin » — ; les zones des chapitres 3 (28 à 59 % mesurés) gardent, elles, leur cinquième.
func _juger_une_zone(nom: String, m: Dictionary, niveau: Dictionary) -> void:
	var entree: Dictionary = m["entree"]
	var etiquette := "%s, PNJ %d (%s)" % [nom, int(m["k"]) + 1, entree["profil_nom"]]
	_check("%s : jamais immobile plus de %.0f s d'affilée (pire : %.1f s)" % [etiquette, IMMOBILE_MAX_S, float(m["immobile_max"])], float(m["immobile_max"]) <= IMMOBILE_MAX_S)
	var zone: Rect2i = entree["zone"]
	var nav := Nav.depuis_carte(niveau["carte"])
	var dans := nav.cases_dans(zone).size()
	var visitees := 0
	for cc: Vector2i in (m["cases"] as Dictionary):
		if zone.has_point(cc):
			visitees += 1
	_check("%s : ne sort pas de sa zone (%.1f s dehors)" % [etiquette, float(m["hors_zone"])], float(m["hors_zone"]) < 0.2)
	var exige := minf(PART_ZONE_VISITEE * float(dans), float(CASES_LIBRE_MIN))
	_check("%s : visite une bonne part de sa zone : %d cases sur %d (au moins %d : le cinquième, plafonné à %d cases)" % [etiquette, visitees, dans, int(exige), CASES_LIBRE_MIN], float(visitees) >= exige, "%d/%d" % [visitees, dans])


## Dans une salle à cloison percée, le PNJ libre franchit-il le passage ? Les salles de `PASSAGES` : il a été vu des deux côtés de la cloison (son centre est passé d'un côté à l'autre).
func _passages(nom: String, chap: int, salle: int, m: Dictionary, niveau: Dictionary) -> void:
	if int(m["deplacement"]) != Profil.Deplacement.LIBRE:
		return
	var etiquette := "%s, PNJ %d" % [nom, int(m["k"]) + 1]
	for p: Array in PASSAGES:
		if int(p[0]) != chap or int(p[1]) != salle:
			continue
		var axe: String = p[2]
		var rang: int = p[3]
		var avant := false
		var apres := false
		for cle: String in m["cote"]:
			if cle.begins_with(axe):
				var v := int(cle.substr(1))
				avant = avant or v < rang
				apres = apres or v > rang + 1
		_check("%s : franchit la cloison %s = %d de son vrai corps (vu des deux côtés)" % [etiquette, axe, rang], avant and apres)
		return
