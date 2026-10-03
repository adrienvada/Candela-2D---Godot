## Les outils des gardes de chapitre — chantier SOLO, étape S8 : de quoi mesurer, sur les DONNÉES d'un chapitre, ce que ses salles enseignent.
##
## `test_chapitre_00.gd` porte ses outils dans son propre fichier (un chapitre, une garde). Les chapitres 1 à 3 en demandent les mêmes — le contexte
## d'une salle, le modèle de vue du bot, les chemins, la portée de la torche — et trois copies auraient dérivé : ils vivent ici, une fois. Chaque
## `test_chapitre_0N.gd` charge son chapitre par ici (`charger`), vérifie ce qui vaut PARTOUT (`partout` : tailles, PNJ, plafonniers, rondes, zones, boss,
## départ à l'abri) puis ne contient plus que les mesures de CHAQUE salle.
##
## Tout est mesuré avec les fonctions du jeu, jamais avec une distance recopiée :
##   • `NavigationBot` — « atteignable à pied », les chemins d'une ronde, la zone où l'on erre ;
##   • `PerceptionBot` — le modèle de vue du bot, qui ne voit jamais plus que la lumière (« ce PNJ est sous la lampe », « le pilier le cache »), et son
##     ouïe (`ecouter`, avec les niveaux et les portées RÉELS de l'audio : un pas debout, un pas accroupi, un tir, une douille) ;
##   • `PorteeEcran` — la portée de la torche du Parasite en vue unique (468 px) ; les salles se mesurent sur elle, comme au chapitre 0.
##
## Aucun autoload n'est nommé à la compilation (un script lancé en `--script` se compile avant eux) : l'audio se lit à l'exécution, par le nœud racine.

const Format := preload("res://aventure_format.gd")
const Profil := preload("res://profil_bot.gd")
const Nav := preload("res://navigation_bot.gd")
const Percep := preload("res://perception_bot.gd")
const Murs := preload("res://murs_bas.gd")
const Portee := preload("res://portee_ecran.gd")
const Iso := preload("res://camera_iso.gd")
const PlafT := preload("res://plafonnier.gd")
const Codec := preload("res://map_codec.gd")

## La marge qu'on exige sur toute distance « hors de portée » : une case.
const MARGE_PX := 20.0
## La vitesse de marche d'un PNJ de ronde : l'allure du catalogue (0,5) fois la vitesse du joueur (260 px/s, lue dans `player.gd`).
const ALLURE_RONDE := 0.5
const VITESSE_JOUEUR := 260.0
## Ce que chaque classe de gadget exige du profil du PNJ qui s'en sert : l'état où la règle de S9 le pose (`EquipementBot.GADGETS`). La suie et le
## leurre se posent EN COMBAT sur une cible vue — il faut VOIR ; la torche fantôme se pose EN ENQUÊTE sur un son — il faut ENTENDRE.
## **Lot 2 (chapitres 4 à 6)** : la poussière (`pompe`, en enquête ou en recherche, sur ce qu'on n'a PAS vu) et la poudre de contact (`sentinelle`, en enquête) demandent
## d'ENTENDRE ; la nappe de braises (`incendiaire`, en combat sur une cible vue) demande de VOIR.
const GADGET_EXIGE := {"fumiste": "voit", "fusil": "voit", "arbalete": "entend", "pompe": "entend", "incendiaire": "voit", "sentinelle": "entend"}
## Les classes des chapitres 7 à 9 (S8, lot 2), dans une table à part pour que chaque lot écrive ses lignes sans toucher à celles de l'autre. L'ombre habitée et le voile
## se posent « face à la torche de la cible, qu'on VOIT » (états enquête, recherche, combat / recherche, combat) ; la mine se pose en enquête ou en recherche sur une place
## qu'on n'a pas vue — il faut ENTENDRE (une enquête naît d'un son).
const GADGET_EXIGE_CHASSEURS := {"occulteur": "voit", "allumeur": "entend", "spectre": "voit"}

var check: Callable
var niveaux: Array = []
var portee_torche := 0.0
var hauteur := 0.0
var hauteur_lampe := 0.0
## Les portées d'écoute, en px, mesurées avec `PerceptionBot.ecouter` : jusqu'où un pas debout, un pas accroupi et un tir donnent une zone assez nette pour
## qu'un PNJ tire dessus (`ProfilBot.AUDACE_ZONE_PX`), et jusqu'où le pas debout s'entend du tout.
var portee_pas_debout_net := 0.0
var portee_pas_accroupi_net := 0.0
var portee_tir_net := 0.0
var portee_douille_nette := 0.0
var portee_pas_debout_totale := 0.0


func _init(un_check: Callable) -> void:
	check = un_check


func _c(label: String, ok: bool, detail: String = "") -> void:
	check.call(label, ok, detail)


# ---------------------------------------------------------------------------
# LES MESURES DU JEU
# ---------------------------------------------------------------------------

## Les grandeurs du jeu dont les salles dépendent. `racine` : le nœud racine de l'arbre (l'audio est un autoload).
func mesures_du_jeu(racine: Node) -> void:
	print("\n--- Les mesures du jeu ---")
	portee_torche = Portee.portee_au_bord(Portee.VUE_UNIQUE, Percep.ZOOM_VUE_UNIQUE, Percep.DECALAGE_VISEE, Iso.TANGAGE_DEG)
	_c("la torche du Parasite porte jusqu'au bord de l'écran : 468 px (13,4 cases)", is_equal_approx(portee_torche, 468.0), str(portee_torche))
	hauteur = Murs.hauteur_de_posture(false)
	hauteur_lampe = Murs.en_pixels(PlafT.HAUTEUR_TUILES)
	_mesurer_l_ouie(racine)


## Un événement de `son_localise` avec les niveaux et les portées RÉELS de l'audio (ses tables, relues sur l'autoload vivant).
func _evenement(racine: Node, famille: String, pos: Vector2, accroupi: bool = false) -> Dictionary:
	var table: Dictionary = racine.get_node("AudioManager").get_script().get_script_constant_map()
	var diagonale := 1583.0
	var niveau := float(table["NIVEAU_RELATIF"].get(famille, 0.0))
	var portee_rel := 1.0
	if accroupi:
		niveau += float(table["PAS_ACCROUPI_DB"])
		portee_rel = float(table["PAS_ACCROUPI_PORTEE"])
	return {
		"cle": famille, "famille": famille, "pos": pos, "emetteur": 0, "niveau_db": niveau,
		"portee": diagonale * float(table["PORTEE_RELATIVE"].get(famille, 1.0)) * float(table["FACTEUR_PORTEE_DEFAUT"]) * portee_rel,
		"fumee_db": 0.0, "wet": 0.0, "diagonale": diagonale,
	}


## La plus grande distance, en px, à laquelle un son donne une zone de rayon au plus `AUDACE_ZONE_PX` (« assez net pour qu'un PNJ tire dessus ») —
## en terrain nu, sans mur. 0 : jamais. Par pas de 5 px.
func _portee_nette(racine: Node, famille: String, accroupi: bool) -> float:
	var monde := Percep.monde_de_la_carte(_carte_nue())
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bot := {"position": Vector2(100, 100), "id": 1, "accroupi": false, "visee": Vector2.RIGHT}
	var meilleure := 0.0
	for d in range(5, 1700, 5):
		var r := Percep.ecouter(_evenement(racine, famille, bot["position"] + Vector2(d, 0), accroupi), bot, monde, rng)
		if not r.is_empty() and float(r["rayon"]) <= Profil.AUDACE_ZONE_PX:
			meilleure = float(d)
	return meilleure


func _carte_nue() -> Dictionary:
	var sol: Array[Vector2i] = []
	for y in range(1, 59):
		for x in range(1, 59):
			sol.append(Vector2i(x, y))
	return {"version": 4, "grid_size": {"x": 60, "y": 60}, "floor": Codec.encode_runs(sol), "walls": "", "low_walls": ""}


func _mesurer_l_ouie(racine: Node) -> void:
	portee_pas_debout_net = _portee_nette(racine, "footstep", false)
	portee_pas_accroupi_net = _portee_nette(racine, "footstep", true)
	portee_tir_net = _portee_nette(racine, "shoot", false)
	portee_douille_nette = _portee_nette(racine, "shell", false)
	# Le pas debout, entendu du tout : tant que `ecouter` rend quelque chose.
	var monde := Percep.monde_de_la_carte(_carte_nue())
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bot := {"position": Vector2(100, 100), "id": 1, "accroupi": false, "visee": Vector2.RIGHT}
	for d in range(5, 1700, 5):
		if not Percep.ecouter(_evenement(racine, "footstep", bot["position"] + Vector2(d, 0)), bot, monde, rng).is_empty():
			portee_pas_debout_totale = float(d)
	_c("l'ouïe d'un PNJ : un pas debout donne une zone nette (≤ %d px) jusqu'à %.0f px, un pas accroupi jusqu'à %.0f px seulement" % [int(Profil.AUDACE_ZONE_PX), portee_pas_debout_net, portee_pas_accroupi_net],
		portee_pas_debout_net > 300.0 and portee_pas_accroupi_net < 0.5 * portee_pas_debout_net and portee_pas_accroupi_net > 0.0,
		"%s %s" % [portee_pas_debout_net, portee_pas_accroupi_net])
	_c("… un tir donne une zone nette jusqu'à %.0f px, une douille jusqu'à %.0f px ; le pas debout s'entend jusqu'à %.0f px" % [portee_tir_net, portee_douille_nette, portee_pas_debout_totale],
		portee_tir_net > portee_pas_debout_net and portee_douille_nette > 0.0 and portee_pas_debout_totale > portee_pas_debout_net)


# ---------------------------------------------------------------------------
# LE CHAPITRE SE CHARGE
# ---------------------------------------------------------------------------

## Charge le chapitre et vérifie ce qu'on lui doit : sans un défaut du validateur, le bon numéro, le bon titre, la classe qu'il débloque, aucune classe imposée,
## le boss dernier et à sa classe, un titre et une phrase d'intention par salle. Rend faux si rien n'est jouable.
func charger(dossier: String, numero: int, titre: String, classe: String, nombre: int) -> bool:
	print("\n--- Le chapitre %d se charge sans un défaut ---" % numero)
	var lu := Format.lire_chapitre(dossier)
	_c("les fichiers se lisent (manifeste et %d salles)" % nombre, bool(lu["ok"]), str(lu["erreurs"]))
	var defauts := Format.valider_chapitre(lu["manifeste"], lu["niveaux"], nombre) if bool(lu["ok"]) else ["illisible"]
	_c("le validateur ne trouve AUCUN défaut (%d salles exigées)" % nombre, defauts.is_empty(), str(defauts))
	if not defauts.is_empty():
		return false
	var chapitre := Format.charger_chapitre(dossier, nombre)
	_c("`charger_chapitre` rend le chapitre prêt à jouer", not chapitre.is_empty())
	if chapitre.is_empty():
		return false
	niveaux = chapitre["niveaux"]
	_c("%d salles, numéro %d, « %s »" % [nombre, numero, titre], niveaux.size() == nombre and int(chapitre["numero"]) == numero and chapitre["titre"] == titre)
	_c("le chapitre débloque « %s » et n'en impose aucune (le joueur choisit parmi ses classes)" % classe,
		chapitre["classe_debloquee"] == classe and chapitre["classe_imposee"] == "")
	var boss_seul := true
	for i in niveaux.size():
		boss_seul = boss_seul and (bool(niveaux[i]["boss"]) == (i == niveaux.size() - 1))
	_c("le boss est la dernière salle, et elle seule", boss_seul)
	for i in niveaux.size():
		var n: Dictionary = niveaux[i]
		_c("%d.%d porte un titre et une phrase d'intention d'une ligne (≤ 120 signes, sans « ! »)" % [numero, i + 1],
			String(n["titre"]).strip_edges() != "" and String(n["intention"]).strip_edges() != "" and String(n["intention"]).length() <= 120
			and not String(n["intention"]).contains("!") and not String(n["intention"]).contains("\n"), String(n["intention"]))
	return true


# ---------------------------------------------------------------------------
# LE CONTEXTE D'UNE SALLE, ET CE QU'ON Y MESURE
# ---------------------------------------------------------------------------

## Tout ce qu'une salle donne à mesurer : sa navigation, son monde de vue, ses lampes, ses PNJ, le départ du joueur.
func ctx(i: int) -> Dictionary:
	var n: Dictionary = niveaux[i]
	var carte: Dictionary = n["carte"]
	var lampes: Array = []
	for p: Dictionary in n["plafonniers"]:
		var rayon_px: float = float(p.get("rayon", PlafT.RAYON_PAR_DEFAUT)) * PlafT.TUILE_PX
		var pos := Nav.centre_de_la_case(p["case"])
		lampes.append({"pos": pos, "rayon_px": rayon_px, "case": p["case"],
			"lumiere": Percep.lumiere_disque("plafonnier", pos, rayon_px * Percep.FRACTION_PLAFONNIER, hauteur_lampe, true)})
	var pnj: Array = []
	for p: Dictionary in n["pnj"]:
		pnj.append({"case": p["case"], "pos": Nav.centre_de_la_case(p["case"]), "profil_nom": p["profil_nom"], "profil": Format.profil_du_pnj(p),
			"classe": p["classe"], "equipe": bool(p["equipe"]), "ronde": p["ronde"], "zone": p["zone"], "rotation": p["rotation"]})
	return {
		"n": n, "carte": carte, "nav": Nav.depuis_carte(carte), "monde": Percep.monde_de_la_carte(carte),
		"depart": n["joueur"]["case"], "depart_pos": Nav.centre_de_la_case(n["joueur"]["case"]),
		"lampes": lampes, "pnj": pnj, "taille": Codec.get_grid_size(carte),
	}


func lumieres(c: Dictionary) -> Array:
	var sortie: Array = []
	for l: Dictionary in c["lampes"]:
		sortie.append(l["lumiere"])
	return sortie


## Le modèle de vue dit-il qu'une lampe de la salle éclaire un corps debout en `pos` ?
func eclaire_par_lampe(c: Dictionary, pos: Vector2) -> bool:
	for l: Dictionary in c["lampes"]:
		if Percep.eclaire(l["lumiere"], pos, hauteur, c["monde"]):
			return true
	return false


## Cette lampe-là éclaire-t-elle un corps debout en `pos` ?
func eclaire_par_cette_lampe(c: Dictionary, lampe: Dictionary, pos: Vector2) -> bool:
	return Percep.eclaire(lampe["lumiere"], pos, hauteur, c["monde"])


## La flaque au sens LARGE : tout ce qui est à moins d'un rayon de texture (plus un corps) d'une lampe, murs ou non.
func sous_une_lampe(c: Dictionary, pos: Vector2) -> bool:
	for l: Dictionary in c["lampes"]:
		if pos.distance_to(l["pos"]) <= float(l["rayon_px"]) + Percep.RAYON_CORPS:
			return true
	return false


func ligne_de_vue(c: Dictionary, a: Vector2, b: Vector2) -> bool:
	return Percep.ligne_de_vue(a, b, hauteur, hauteur, c["monde"])


## `observateur` voit-il un joueur debout en `cible`, compte tenu des `lumieres` ? Le modèle de vue du bot, avec son cadre d'écran.
func voit(c: Dictionary, observateur: Vector2, cible: Vector2, des_lumieres: Array) -> bool:
	var bot := {"position": observateur, "visee": (cible - observateur).normalized(), "accroupi": false}
	var corps := {"position": cible, "accroupi": false}
	return bool(Percep.voir(bot, corps, des_lumieres, c["monde"])["vu"])


func longueur(chemin: Array) -> float:
	var total := 0.0
	for k in range(1, chemin.size()):
		total += Nav.centre_de_la_case(chemin[k]).distance_to(Nav.centre_de_la_case(chemin[k - 1]))
	return total


## Les cases de mur BAS que traverse le segment `a → b` (échantillonné tous les 4 px).
func murs_bas_traverses(c: Dictionary, a: Vector2, b: Vector2) -> Array[Vector2i]:
	var bas := {}
	for cc in Codec.get_low_wall_cells(c["carte"]):
		bas[cc] = true
	var sortie: Array[Vector2i] = []
	var d := a.distance_to(b)
	var pas := maxi(1, int(d / 4.0))
	for k in range(pas + 1):
		var cc := Nav.case_du_monde(a.lerp(b, float(k) / float(pas)))
		if bas.has(cc) and not sortie.has(cc):
			sortie.append(cc)
	return sortie


## Le nombre de cases de mur plein à l'INTÉRIEUR de la salle (hors la ceinture).
func murs_interieurs(c: Dictionary) -> int:
	var taille: Vector2i = c["taille"]
	var n := 0
	for cc in Codec.get_wall_cells(c["carte"]):
		if cc.x > 0 and cc.y > 0 and cc.x < taille.x - 1 and cc.y < taille.y - 1:
			n += 1
	return n


# ---------------------------------------------------------------------------
# LES RONDES ET LES ZONES
# ---------------------------------------------------------------------------

## Le tour d'une ronde, case par case : le chemin de `NavigationBot` d'un point au suivant, le dernier ramenant au premier. Vide si un tronçon manque.
## Sans doublon consécutif ; la dernière case est celle d'avant le premier point.
func tour_de_la_ronde(c: Dictionary, k: int) -> Array[Vector2i]:
	var nav: Nav = c["nav"]
	var pts: Array = c["pnj"][k]["ronde"]
	var tour: Array[Vector2i] = []
	for j in pts.size():
		var a: Vector2i = pts[j]
		var b: Vector2i = pts[(j + 1) % pts.size()]
		var ch := nav.chemin(a, b)
		if ch.is_empty():
			return []
		for m in range(0, ch.size() - 1):
			tour.append(ch[m])
	return tour


## Les cases distinctes d'un tour.
func cases_du_tour(tour: Array[Vector2i]) -> Array[Vector2i]:
	var vu := {}
	var sortie: Array[Vector2i] = []
	for cc in tour:
		if not vu.has(cc):
			vu[cc] = true
			sortie.append(cc)
	return sortie


## La période d'une ronde, en secondes : la longueur du tour, à la vitesse d'un PNJ de ronde.
func periode_de_la_ronde(tour: Array[Vector2i]) -> float:
	var total := 0.0
	for j in tour.size():
		total += Nav.centre_de_la_case(tour[j]).distance_to(Nav.centre_de_la_case(tour[(j + 1) % tour.size()]))
	return total / (ALLURE_RONDE * VITESSE_JOUEUR)


## La place d'un PNJ de ronde à l'instant `t` (secondes), parti de son premier point : la ligne brisée des centres de case, parcourue à vitesse constante.
func place_sur_le_tour(tour: Array[Vector2i], t: float) -> Vector2:
	var reste := t * ALLURE_RONDE * VITESSE_JOUEUR
	var n := tour.size()
	var j := 0
	while true:
		var a := Nav.centre_de_la_case(tour[j % n])
		var b := Nav.centre_de_la_case(tour[(j + 1) % n])
		var d := a.distance_to(b)
		if reste <= d:
			return a.lerp(b, reste / d if d > 0.0 else 0.0)
		reste -= d
		j += 1
		if j > 100000:
			return a
	return Vector2.ZERO


## La plus courte distance entre deux PNJ de ronde (ou plus), sur une période commune, à vitesse constante : ils se croisent sans se toucher si elle dépasse
## le diamètre d'un corps (36 px).
func ecart_minimal_des_rondes(c: Dictionary, ks: Array) -> float:
	var tours: Array = []
	var duree := 0.0
	for k in ks:
		var tour := tour_de_la_ronde(c, k)
		tours.append(tour)
		duree = maxf(duree, periode_de_la_ronde(tour))
	var meilleur := INF
	var t := 0.0
	while t <= duree * 2.0:
		for a in tours.size():
			for b in range(a + 1, tours.size()):
				meilleur = minf(meilleur, place_sur_le_tour(tours[a], t).distance_to(place_sur_le_tour(tours[b], t)))
		t += 0.05
	return meilleur


## Les cases praticables d'une zone qu'on atteint EN RESTANT dans la zone, depuis la case du PNJ (la même règle que le bot : son chemin ne sort pas).
func cases_de_la_zone_atteignables(c: Dictionary, k: int) -> Array[Vector2i]:
	var nav: Nav = c["nav"]
	var zone: Rect2i = c["pnj"][k]["zone"]
	var depart: Vector2i = c["pnj"][k]["case"]
	var vu := {depart: true}
	var file: Array[Vector2i] = [depart]
	var tete := 0
	while tete < file.size():
		var cc := file[tete]
		tete += 1
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var s := cc + d
			if zone.has_point(s) and nav.est_praticable(s) and not vu.has(s):
				vu[s] = true
				file.append(s)
	return file


## Une case est-elle à moins de `rayon_px` d'une case du tour ?
func proche_du_tour(pos: Vector2, tour: Array[Vector2i], rayon_px: float) -> bool:
	for cc in tour:
		if Nav.centre_de_la_case(cc).distance_to(pos) <= rayon_px:
			return true
	return false


## La plus courte distance d'une position à une case du tour.
func distance_au_tour(pos: Vector2, tour: Array[Vector2i]) -> float:
	var d := INF
	for cc in tour:
		d = minf(d, Nav.centre_de_la_case(cc).distance_to(pos))
	return d


# ---------------------------------------------------------------------------
# PARTOUT : ce qui vaut pour chaque salle du chapitre
# ---------------------------------------------------------------------------

## `table` : une ligne par salle — `pnj` (profil → combien), `lampes`, `equipes` (combien de PNJ portent la clé « equipe »), `cotes` ([min, max] du côté, en
## cases). `classe` : celle du chapitre (les PNJ équipés la portent ; les autres, la classe par défaut). `numero` : celui du chapitre.
func partout(numero: int, classe: String, table: Array) -> void:
	print("\n--- Partout : tailles, PNJ, plafonniers, atteignable à pied, une pièce, aucun couloir d'une tuile, rondes, zones, départ à l'abri ---")
	for i in niveaux.size():
		var c := ctx(i)
		var nav: Nav = c["nav"]
		var nom := "%d.%d" % [numero, i + 1]
		var ligne: Dictionary = table[i]
		var taille: Vector2i = c["taille"]
		var cotes: Array = ligne["cotes"]
		_c("%s : une salle de %d à %d cases de côté" % [nom, cotes[0], cotes[1]],
			taille.x >= cotes[0] and taille.y >= cotes[0] and taille.x <= cotes[1] and taille.y <= cotes[1], str(taille))
		_c("%s : et dans ce que le format sait écrire (au plus %d)" % [nom, Codec.MAX_GRID], taille.x <= Codec.MAX_GRID and taille.y <= Codec.MAX_GRID, str(taille))
		var compte := {}
		for p: Dictionary in c["pnj"]:
			compte[p["profil_nom"]] = int(compte.get(p["profil_nom"], 0)) + 1
		var attendu: Dictionary = ligne["pnj"]
		var total := 0
		for v in attendu.values():
			total += int(v)
		_c("%s : %d PNJ — %s" % [nom, total, str(attendu)], compte == attendu and (c["pnj"] as Array).size() <= Format.PNJ_MAX, str(compte))
		_c("%s : %d plafonnier(s)" % [nom, int(ligne["lampes"])], (c["lampes"] as Array).size() == int(ligne["lampes"]), str((c["lampes"] as Array).size()))
		# Les PNJ équipés portent la classe du chapitre ET un profil qui peut déclencher son gadget ; les autres, la classe par défaut.
		var equipes := 0
		var equipes_bien := true
		var autres_bien := true
		for p: Dictionary in c["pnj"]:
			if p["profil_nom"] == "boss":
				continue
			if p["equipe"]:
				equipes += 1
				var exige: String = _exige_de(classe)
				var peut: bool = (p["profil"].voit if exige == "voit" else p["profil"].entend) if exige != "" else false
				equipes_bien = equipes_bien and p["classe"] == classe and p["profil"].utilise_le_gadget and peut
			else:
				autres_bien = autres_bien and p["classe"] == Format.CLASSE_PAR_DEFAUT and not p["profil"].utilise_le_gadget
		_c("%s : %d PNJ équipé(s), à la classe « %s », dont le profil %s : la règle de son gadget peut se déclencher" % [nom, int(ligne["equipes"]), classe, _exige_de(classe) if _exige_de(classe) != "" else "?"],
			equipes == int(ligne["equipes"]) and equipes_bien)
		_c("%s : les autres PNJ gardent la classe par défaut et n'ont aucun outil" % nom, autres_bien)
		# L'accès : chaque PNJ à pied, une seule pièce, aucun couloir d'une tuile.
		var atteignables := nav.cases_atteignables(c["depart"])
		var tous := true
		var detail := ""
		for p: Dictionary in c["pnj"]:
			var ok: bool = atteignables.has(p["case"]) and not nav.chemin(c["depart"], p["case"]).is_empty()
			tous = tous and ok
			if not ok:
				detail += " %s" % str(p["case"])
		_c("%s : chaque PNJ est atteignable à pied depuis le départ (chemins de NavigationBot)" % nom, tous, "inatteignables :" + detail)
		_c("%s : une seule pièce — toute case praticable est atteignable depuis le départ" % nom,
			atteignables.size() == nav.cases_praticables().size(), "%d sur %d" % [atteignables.size(), nav.cases_praticables().size()])
		var etranglees: Array[Vector2i] = []
		for y in taille.y:
			for x in taille.x:
				var cc := Vector2i(x, y)
				if nav.est_libre(cc) and not nav.est_praticable(cc):
					etranglees.append(cc)
		_c("%s : aucun couloir d'une tuile (le corps fait 36 px, la tuile 35)" % nom, etranglees.is_empty(), str(etranglees.slice(0, 6)))
		_c("%s : le joueur part d'une case praticable, qu'aucun PNJ n'occupe" % nom, nav.est_praticable(c["depart"]) and not _pnj_sur(c, c["depart"]))
		_les_rondes(c, nom)
		_les_zones(c, nom)
		_depart_a_l_abri(c, nom)


## Ce que la règle du gadget de cette classe exige du profil du PNJ équipé : « voit » ou « entend » (`""` : classe inconnue).
func _exige_de(classe: String) -> String:
	return String(GADGET_EXIGE.get(classe, GADGET_EXIGE_CHASSEURS.get(classe, "")))


func _pnj_sur(c: Dictionary, cc: Vector2i) -> bool:
	for p: Dictionary in c["pnj"]:
		if p["case"] == cc:
			return true
	return false


## Chaque ronde est une boucle praticable : au moins trois points, tous praticables, atteignables, le PNJ naît sur le premier ; un chemin relie chaque point au
## suivant (le dernier au premier) ; le tour est assez long pour se lire, et assez court pour revenir.
func _les_rondes(c: Dictionary, nom: String) -> void:
	var nav: Nav = c["nav"]
	var pnj: Array = c["pnj"]
	for k in pnj.size():
		var p: Dictionary = pnj[k]
		var est_ronde: bool = p["profil"].deplacement == Profil.Deplacement.RONDE
		if not est_ronde:
			_c("%s : le PNJ %d (%s) n'a pas de ronde" % [nom, k + 1, p["profil_nom"]], (p["ronde"] as Array).is_empty())
			continue
		var pts: Array = p["ronde"]
		var distincts := {}
		var praticables := true
		var meme_piece := true
		for pt in pts:
			distincts[pt] = true
			praticables = praticables and nav.est_praticable(pt)
			meme_piece = meme_piece and nav.cases_atteignables(p["case"]).has(pt)
		var tour := tour_de_la_ronde(c, k)
		_c("%s : la ronde du PNJ %d : au moins 3 points distincts, tous praticables, tous atteignables, le PNJ naît sur le premier" % [nom, k + 1],
			pts.size() >= 3 and distincts.size() == pts.size() and praticables and meme_piece and p["case"] == pts[0], str(pts))
		_c("%s : … un chemin relie chaque point au suivant, le dernier au premier : une BOUCLE (%d cases, %.1f s par tour)" % [nom, tour.size(), periode_de_la_ronde(tour) if not tour.is_empty() else 0.0],
			not tour.is_empty())
		if not tour.is_empty():
			var periode := periode_de_la_ronde(tour)
			_c("%s : … assez longue pour se lire (au moins 20 cases) et assez courte pour revenir (de 6 à 40 s)" % nom, tour.size() >= 20 and periode >= 6.0 and periode <= 40.0,
				"%d cases, %.1f s" % [tour.size(), periode])


## Chaque zone contient son PNJ et laisse assez de cases pour errer : au moins 16, et on les atteint toutes sans sortir de la zone.
func _les_zones(c: Dictionary, nom: String) -> void:
	var nav: Nav = c["nav"]
	var pnj: Array = c["pnj"]
	for k in pnj.size():
		var p: Dictionary = pnj[k]
		if p["profil"].deplacement != Profil.Deplacement.ZONE:
			_c("%s : le PNJ %d (%s) n'a pas de zone" % [nom, k + 1, p["profil_nom"]], (p["zone"] as Rect2i).size == Vector2i.ZERO)
			continue
		var zone: Rect2i = p["zone"]
		var dedans := nav.cases_dans(zone)
		var atteignables := cases_de_la_zone_atteignables(c, k)
		_c("%s : la zone du PNJ %d %s contient son PNJ" % [nom, k + 1, str(zone)], zone.has_point(p["case"]))
		_c("%s : … assez de cases pour errer : %d praticables (au moins 16), et le PNJ les atteint toutes SANS sortir de la zone (%d)" % [nom, dedans.size(), atteignables.size()],
			dedans.size() >= 16 and atteignables.size() == dedans.size())


## Le départ est un abri : aucun PNJ qui voit ne voit le joueur à sa case — pour un PNJ de ronde, en aucun point de son tour (torche éteinte, les lampes de la salle).
func _depart_a_l_abri(c: Dictionary, nom: String) -> void:
	var pnj: Array = c["pnj"]
	var vu_par := ""
	for k in pnj.size():
		var p: Dictionary = pnj[k]
		if not p["profil"].voit:
			continue
		var postes: Array[Vector2] = [p["pos"]]
		if p["profil"].deplacement == Profil.Deplacement.RONDE:
			postes.clear()
			for cc in tour_de_la_ronde(c, k):
				postes.append(Nav.centre_de_la_case(cc))
		elif p["profil"].deplacement == Profil.Deplacement.ZONE:
			postes.clear()
			for cc in cases_de_la_zone_atteignables(c, k):
				postes.append(Nav.centre_de_la_case(cc))
		for poste in postes:
			if voit(c, poste, c["depart_pos"], lumieres(c)):
				vu_par = "PNJ %d en %s" % [k + 1, str(Nav.case_du_monde(poste))]
				break
		if vu_par != "":
			break
	_c("%s : le départ est un abri — aucun PNJ qui voit ne voit le joueur à sa case, torche éteinte, où qu'il se tienne" % nom, vu_par == "", vu_par)


# ---------------------------------------------------------------------------
# LE BOSS : un duel en miroir
# ---------------------------------------------------------------------------

## La dernière salle : un seul PNJ, au profil « boss » et à la classe du chapitre, deux plafonniers, une arène de 32 × 32 symétrique d'est en ouest, le joueur
## et le boss en miroir, les deux lampes face à face, et personne sous une lampe au départ.
func salle_du_boss(i: int, numero: int, classe: String) -> void:
	print("\n--- %d.%d Le boss : le duel en miroir ---" % [numero, i + 1])
	var c := ctx(i)
	var n: Dictionary = c["n"]
	var p: Dictionary = c["pnj"][0]
	_c("un seul PNJ, au profil « boss » et à la classe du chapitre (« %s »)" % classe, (c["pnj"] as Array).size() == 1 and p["profil_nom"] == "boss" and p["classe"] == classe and bool(n["boss"]))
	_c("… dont le profil est celui du boss réglé à sa classe (`ProfilBot.boss(classe)`)", p["profil"].voit and p["profil"].entend and p["profil"].tire and p["profil"].utilise_le_gadget)
	_c("deux plafonniers", (c["lampes"] as Array).size() == 2)
	var taille: Vector2i = c["taille"]
	var miroir_x := func(cc: Vector2i) -> Vector2i: return Vector2i(taille.x - 1 - cc.x, cc.y)
	var miroir_y := func(cc: Vector2i) -> Vector2i: return Vector2i(cc.x, taille.y - 1 - cc.y)
	var murs := {}
	for cc in Codec.get_wall_cells(c["carte"]):
		murs[cc] = true
	var bas := {}
	for cc in Codec.get_low_wall_cells(c["carte"]):
		bas[cc] = true
	var sym_x := true
	var sym_y := true
	for cc: Vector2i in murs:
		sym_x = sym_x and murs.has(miroir_x.call(cc))
		sym_y = sym_y and murs.has(miroir_y.call(cc))
	for cc: Vector2i in bas:
		sym_x = sym_x and bas.has(miroir_x.call(cc))
		sym_y = sym_y and bas.has(miroir_y.call(cc))
	_c("l'arène est symétrique d'est en ouest (murs, murets)", sym_x)
	_c("… et du nord au sud", sym_y)
	_c("le joueur et le boss se tiennent en miroir", miroir_x.call(c["depart"]) == p["case"])
	var l0: Vector2i = Nav.case_du_monde(c["lampes"][0]["pos"])
	var l1: Vector2i = Nav.case_du_monde(c["lampes"][1]["pos"])
	_c("les deux plafonniers se font face (la lampe de l'un est celle de l'autre vue dans un miroir)", miroir_x.call(l0) == l1)
	_c("les deux flaques se tiennent à part : la lampe d'un camp n'éclaire pas déjà l'autre",
		float((c["lampes"][0]["pos"] as Vector2).distance_to(c["lampes"][1]["pos"])) > float(c["lampes"][0]["rayon_px"]) + float(c["lampes"][1]["rayon_px"]))
	_c("le boss et le joueur ne se voient pas d'emblée sans lumière : ni l'un ni l'autre n'est sous une lampe",
		not sous_une_lampe(c, c["depart_pos"]) and not sous_une_lampe(c, p["pos"]))
	_c("aucune ronde, aucune zone : le boss est le seul PNJ qui bouge partout (profil « boss », libre)", (p["ronde"] as Array).is_empty() and (p["zone"] as Rect2i).size == Vector2i.ZERO)
