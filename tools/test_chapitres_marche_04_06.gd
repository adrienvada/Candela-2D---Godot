## La garde de MARCHE des chapitres 4 à 6 — chantier SOLO, étape S8 (lot 2) : les rondes, les zones et les chasseurs se parcourent pour de vrai, avec le vrai corps.
##
## Sur le modèle de `test_chapitres_marche.gd` (le lot 1, chapitres 1 à 3), que cette suite ne remplace pas et n'édite pas : l'autre session du lot écrit la sienne pour 7 à 9. Les gardes de
## contenu (`test_chapitre_04` à `06`) mesurent les DONNÉES avec les chemins de `NavigationBot` ; ici on monte le vrai jeu, on joue chaque salle de ronde, de zone ou de chasse à pas d'image
## fixe, PNJ désarmés et sourds-aveugles (ils marchent, ils ne réagissent à rien : seul le déplacement est mesuré), et on vérifie :
##
##   • RONDE — le PNJ passe, de son vrai corps, par CHACUN de ses points (à moins d'une case et demie), et il boucle : il repasse par son premier point ; jamais immobile plus de
##     trois secondes d'affilée ;
##   • ZONE — le PNJ ne sort pas de sa zone (son centre reste à moins d'un demi-corps du rectangle), il en visite une bonne part (au moins le cinquième de ses cases), et il n'est jamais
##     immobile plus de trois secondes d'affilée ;
##   • LIBRE — les neuf premières salles du chapitre 6 en portent : c'est la première fois que le vrai corps parcourt un chasseur dans une salle d'aventure (S1 l'avait fait
##     avec le bot de l'entraînement, sur les six cartes de duel). Le chasseur visite au moins le quart des cases qu'il peut rejoindre, ne reste jamais immobile plus de trois secondes,
##     et ne passe sur aucune case qui n'est pas du sol ;
##   • et, dans une même salle, deux PNJ de ronde ne se traversent jamais (au moins 20 px de centre à centre).
##
## Chaque salle est jouée une fois, avec la graine du jeu fixée : le résultat est le même à chaque lancement.
##
## ⚠️ **Se lance à pas d'image fixe** (`--fixed-fps 60`) : les temps de marche sont comptés en pas de physique, et la suite refuse de conclure sans cette horloge.
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_chapitres_marche_04_06.gd [-- --chapitre=5 --salle=6]
extends SceneTree

const Format := preload("res://aventure_format.gd")
const Progression := preload("res://aventure_progression.gd")
const Nav := preload("res://navigation_bot.gd")
const Profil := preload("res://profil_bot.gd")

const SOLO_DE_LA_SUITE := "user://test_chapitres_marche_04_06_solo.cfg"
const PH_JEU := 1

## Combien de secondes de jeu au plus par salle, et combien de tours de ronde on laisse au PNJ.
const DUREE_MAX_S := 45.0
const TOURS := 1.4
## Un PNJ « passe par un point » s'il s'en approche à moins de 1,5 case ; une immobilité tolérable : 3 s.
const RAYON_POINT_PX := 52.5
const IMMOBILE_MAX_S := 3.0
## Le cinquième des cases d'une zone, visitées en `DUREE_MAX_S`.
const PART_ZONE_VISITEE := 0.2
## … sans jamais exiger plus de cette quantité de cases (mesuré : de 41 à 89 cases visitées selon la zone).
const CASES_ZONE_MIN := 50.0
## Combien de cases DISTINCTES un chasseur visite au moins en `DUREE_LIBRE_S` (mesuré : de 110 à 216 selon la carte) : il erre sur TOUTE la carte.
const CASES_LIBRE_MIN := 80
## Combien de secondes de jeu on laisse à un chasseur (il a toute la carte à parcourir).
const DUREE_LIBRE_S := 45.0
## Deux corps de 36 px ne se chevauchent pas : au moins 20 px de centre à centre, par prudence (la physique les écarte).
const ECART_MIN_PX := 20.0

var _failures := 0
var _verifications := 0
var main: Node = null
var ui: Node = null
var prog: AventureProgression = null
var _seulement_chapitre := -1
var _seulement_salle := -1
## `-- --duree=<s>` : jouer chaque salle plus longtemps que `DUREE_MAX_S` (pour chercher une collision lente, pas pour la garde).
var _duree_max := DUREE_MAX_S


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
	print("=== LA MARCHE DES RONDES, DES ZONES ET DES CHASSEURS (S8, lot 2), LE VRAI CORPS ===")
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
	_effacer(SOLO_DE_LA_SUITE)
	root.get_node("GameSettings").mode_iso = false
	prog = Progression.new(SOLO_DE_LA_SUITE)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	ui = main.ui
	ui.aventure_progression = prog
	main.archiver_les_matchs = false
	Format.oublier_le_cache()
	for chap in [4, 5, 6]:
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
			var niveau: Dictionary = chapitre["niveaux"][i]
			if bool(niveau["boss"]):
				continue
			await _jouer(chap, chapitre, i)
	_effacer(SOLO_DE_LA_SUITE)
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
	# Désarmés et sourds-aveugles : ils marchent, ils ne réagissent à rien — c'est le déplacement qu'on mesure.
	var marcheurs: Array = []
	var duree := 0.0
	for k in partie.pnj.size():
		var entree: Dictionary = niveau["pnj"][k]
		var pnj: Node = partie.pnj[k]
		var bot := pnj.input_provider as BotInputProvider
		bot.profil.agit = false
		bot.profil.tire = false
		bot.profil.voit = false
		bot.profil.entend = false
		var d: int = bot.profil.deplacement
		if d != Profil.Deplacement.RONDE and d != Profil.Deplacement.ZONE and d != Profil.Deplacement.LIBRE:
			continue
		var m := {"k": k, "pnj": pnj, "entree": entree, "deplacement": d, "visites": {}, "retours": 0, "loin_du_depart": false, "immobile": 0.0, "immobile_max": 0.0,
			"derniere": pnj.global_position, "cases": {}, "hors_zone": 0.0, "dernier_point": -1}
		marcheurs.append(m)
		if d == Profil.Deplacement.LIBRE:
			duree = maxf(duree, DUREE_LIBRE_S)
		if d == Profil.Deplacement.ZONE:
			# Une grande zone (un dédale de murets : 4.8) demande plus de 20 s pour qu'on en voie une bonne part : un dixième de seconde par case, plafonné par `DUREE_MAX_S`.
			duree = maxf(duree, 0.1 * float(Nav.depuis_carte(niveau["carte"]).cases_dans(entree["zone"]).size()))
		if d == Profil.Deplacement.RONDE:
			var nav := Nav.depuis_carte(niveau["carte"])
			var longueur := 0.0
			var pts: Array = entree["ronde"]
			for j in pts.size():
				longueur += float(nav.chemin(pts[j], pts[(j + 1) % pts.size()]).size() - 1)
			duree = maxf(duree, longueur * 35.0 / (Profil.pnj_nomme(String(entree["profil_nom"])).allure * 260.0) * TOURS + 2.0)
	if marcheurs.is_empty():
		return
	duree = clampf(maxf(duree, 20.0), 20.0, _duree_max)
	if _duree_max > DUREE_MAX_S:
		duree = _duree_max
	var ecart_min := INF
	var images := int(duree * 60.0)
	for _t in images:
		await physics_frame
		for m in marcheurs:
			_suivre(m, 1.0 / 60.0)
		for a in marcheurs.size():
			for b in range(a + 1, marcheurs.size()):
				# Les rondes entre elles seulement : une ronde qui traverse la zone d'un gardien (5.9, 4.9, 3.5…) le croise PAR CONSTRUCTION, et les deux corps se touchent alors (35 px
				# mesurés en 5.9, sans qu'aucun des deux sorte de son trajet ni de sa zone). Ce que la garde exclut, c'est deux rondes qui se rattrapent.
				if int(marcheurs[a]["deplacement"]) == Profil.Deplacement.RONDE and int(marcheurs[b]["deplacement"]) == Profil.Deplacement.RONDE:
					ecart_min = minf(ecart_min, (marcheurs[a]["pnj"] as Node2D).global_position.distance_to((marcheurs[b]["pnj"] as Node2D).global_position))
	for m in marcheurs:
		_juger(nom, m, niveau)
	if marcheurs.size() >= 2:
		var rondes := 0
		for m in marcheurs:
			if int(m["deplacement"]) == Profil.Deplacement.RONDE:
				rondes += 1
		if rondes >= 2:
			_check("%s : deux rondes ne se traversent jamais (écart minimal %.0f px, au moins %.0f)" % [nom, ecart_min, ECART_MIN_PX], ecart_min >= ECART_MIN_PX)
	main._on_main_menu_requested()
	await _images(3)


## Un pas de mesure : où est le PNJ, par quels points il est passé, depuis combien de temps il ne bouge plus, quelles cases de sa zone il a visitées.
func _suivre(m: Dictionary, dt: float) -> void:
	var pnj: Node2D = m["pnj"]
	var pos := pnj.global_position
	if int(m["deplacement"]) == Profil.Deplacement.RONDE:
		var pts: Array = m["entree"]["ronde"]
		for j in pts.size():
			if pos.distance_to(Nav.centre_de_la_case(pts[j])) <= RAYON_POINT_PX:
				if not (m["visites"] as Dictionary).has(j):
					(m["visites"] as Dictionary)[j] = true
				if j == 0 and int(m["dernier_point"]) != 0 and (m["loin_du_depart"] as bool):
					m["retours"] = int(m["retours"]) + 1
				if j != 0:
					m["loin_du_depart"] = true
				m["dernier_point"] = j
	elif int(m["deplacement"]) == Profil.Deplacement.LIBRE:
		(m["cases"] as Dictionary)[Nav.case_du_monde(pos)] = true
	else:
		var zone: Rect2i = m["entree"]["zone"]
		var rect := Rect2(Vector2(zone.position) * 35.0 - Vector2(18, 18), Vector2(zone.size) * 35.0 + Vector2(36, 36))
		if not rect.has_point(pos):
			m["hors_zone"] = float(m["hors_zone"]) + dt
		(m["cases"] as Dictionary)[Nav.case_du_monde(pos)] = true
	if pos.distance_to(m["derniere"]) < 0.3:
		m["immobile"] = float(m["immobile"]) + dt
		m["immobile_max"] = maxf(float(m["immobile_max"]), float(m["immobile"]))
	else:
		m["immobile"] = 0.0
	m["derniere"] = pos


func _juger(nom: String, m: Dictionary, niveau: Dictionary) -> void:
	var entree: Dictionary = m["entree"]
	var etiquette := "%s, PNJ %d (%s)" % [nom, int(m["k"]) + 1, entree["profil_nom"]]
	_check("%s : jamais immobile plus de %.0f s d'affilée (pire : %.1f s)" % [etiquette, IMMOBILE_MAX_S, float(m["immobile_max"])], float(m["immobile_max"]) <= IMMOBILE_MAX_S)
	if int(m["deplacement"]) == Profil.Deplacement.RONDE:
		var pts: Array = entree["ronde"]
		_check("%s : passe, de son vrai corps, par chacun de ses %d points (%d visités)" % [etiquette, pts.size(), (m["visites"] as Dictionary).size()], (m["visites"] as Dictionary).size() == pts.size())
		_check("%s : et boucle : il repasse par son premier point (%d retour(s))" % [etiquette, int(m["retours"])], int(m["retours"]) >= 1)
	elif int(m["deplacement"]) == Profil.Deplacement.LIBRE:
		var nav := Nav.depuis_carte(niveau["carte"])
		var rejoignables := nav.cases_atteignables(entree["case"])
		var visitees := 0
		var sur_du_sol := true
		var quarts_visites := {}
		var quarts_existants := {}
		var t: Vector2i = nav.taille
		for cc in rejoignables:
			quarts_existants[Vector2i(cc.x * 2 / t.x, cc.y * 2 / t.y)] = true
		for cc: Vector2i in (m["cases"] as Dictionary):
			if rejoignables.has(cc):
				visitees += 1
				quarts_visites[Vector2i(cc.x * 2 / t.x, cc.y * 2 / t.y)] = true
			elif not nav.est_libre(cc):
				sur_du_sol = false
		# Un chasseur erre sur TOUTE la carte : il ne reste pas dans un coin. Le nombre de cases qu'il visite en `DUREE_LIBRE_S` ne dépend que de sa vitesse (~230 cases de chemin) :
		# une fraction du sol n'a pas de sens sur une grande carte. Ce qui en a, c'est le nombre de cases DISTINCTES et les quarts de carte où il passe.
		_check("%s : erre sur toute la carte : %d cases distinctes (au moins %d), dans %d quart(s) de carte sur %d (tous)" % [etiquette, visitees, CASES_LIBRE_MIN, quarts_visites.size(), quarts_existants.size()],
			visitees >= CASES_LIBRE_MIN and quarts_visites.size() == quarts_existants.size(), "%d cases, %d/%d quarts" % [visitees, quarts_visites.size(), quarts_existants.size()])
		_check("%s : et ne passe que sur du sol (aucune case de mur, de mur bas ou de vide)" % etiquette, sur_du_sol)
	else:
		var zone: Rect2i = entree["zone"]
		var nav := Nav.depuis_carte(niveau["carte"])
		var dans := nav.cases_dans(zone).size()
		var visitees := 0
		for cc: Vector2i in (m["cases"] as Dictionary):
			if zone.has_point(cc):
				visitees += 1
		_check("%s : ne sort pas de sa zone (%.1f s dehors)" % [etiquette, float(m["hors_zone"])], float(m["hors_zone"]) < 0.2)
		# Un cinquième de la zone, mais jamais plus de `CASES_ZONE_MIN` cases : un gardien traverse ~4,5 cases par seconde, et un dédale de murets (4.8, 398 cases dans la plus grande zone) se
		# marche au lieu de se balayer — il y passe par les mêmes couloirs.
		var besoin := minf(PART_ZONE_VISITEE * float(dans), CASES_ZONE_MIN)
		_check("%s : visite une bonne part de sa zone : %d cases sur %d (au moins %d)" % [etiquette, visitees, dans, int(besoin)], float(visitees) >= besoin, "%d/%d" % [visitees, dans])


# ---------------------------------------------------------------------------
# OUTILS
# ---------------------------------------------------------------------------

func _horloge_fixe() -> bool:
	var f0 := Engine.get_physics_frames()
	for _i in 60:
		await process_frame
	return absi(int(Engine.get_physics_frames() - f0) - 60) <= 1


func _images(n: int) -> void:
	for _i in n:
		await process_frame


func _jusqua(cond: Callable, max_images: int) -> bool:
	for _i in max_images:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _effacer(chemin: String) -> void:
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(chemin)


func _sortir() -> void:
	print("\n%d vérifications" % _verifications)
	print("CRIS ATTENDUS: 0")
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
