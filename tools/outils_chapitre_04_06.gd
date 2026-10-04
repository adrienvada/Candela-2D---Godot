## Les outils des gardes des chapitres 4 à 6 — chantier SOLO, étape S8 (lot 2) : ce que `outils_chapitre.gd` ne donne pas, et que les trois chapitres suivants partagent.
##
## `OutilsChapitre` (le lot 1) fournit le contexte d'une salle, le modèle de vue du bot, les chemins, les rondes et les zones, ce que `partout()` vérifie dans chaque
## salle, le duel en miroir du boss. Les chapitres 4 (les zones ÉCOUTENT), 5 (les groupes) et 6 (les chasseurs, qui errent partout) ont besoin de quatre choses de plus, qui
## vivent ici, une fois :
##
##   • **l'ouïe d'un PNJ derrière les murs** — `rayon_entendu` / `net` rejouent `PerceptionBot.ecouter` avec le monde RÉEL de la salle (un mur étouffe : −5 dB, largeur
##     ×1,6), là où `OutilsChapitre` mesure des portées en terrain nu ;
##   • **les petits outils de zone** (portes, frontières, cases éclairées, part en vue) que `test_chapitre_03.gd` portait pour lui seul ;
##   • **la règle d'un gadget peut-elle se déclencher ?** (`peut_poser`) — la fenêtre de distance de `EquipementBot.GADGETS`, une case d'où le PNJ la tient, une ligne dégagée ;
##   • **la forme d'une salle** — le sol ouvert où un nuage tient (`cases_ouvertes`), les blocs pleins qu'on contourne (`blocs_interieurs` : un anneau = un bloc, des îlots = plusieurs).
##
## Un sous-type de `OutilsChapitre` : tout ce que les gardes du lot 1 y trouvent reste là, y compris `partout()`.

extends "res://tools/outils_chapitre.gd"

const Equipement := preload("res://equipement_bot.gd")

## Le gadget de chaque classe de ce lot : le slug de la classe (celui du manifeste) → le slug de la LIGNE de `EquipementBot.GADGETS`.
const GADGET_DE_LA_CLASSE := {"pompe": "poussiere", "incendiaire": "nappe_braises", "sentinelle": "poudre_contact"}

## Le nœud racine de l'arbre : l'audio est un autoload, lu à l'exécution (`_evenement`).
var racine: Node = null


func _init(un_check: Callable) -> void:
	super(un_check)


func mesures_du_jeu(r: Node) -> void:
	racine = r
	super(r)


# ---------------------------------------------------------------------------
# LES ZONES
# ---------------------------------------------------------------------------

func zones(c: Dictionary) -> Array[int]:
	return indices(c, Profil.Deplacement.ZONE)


## Les indices des PNJ de la salle qui ont ce déplacement.
func indices(c: Dictionary, deplacement: int) -> Array[int]:
	var sortie: Array[int] = []
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil"].deplacement == deplacement:
			sortie.append(k)
	return sortie


func rect(c: Dictionary, k: int) -> Rect2i:
	return c["pnj"][k]["zone"]


## Les cases de la zone `k` qu'une lampe de la salle éclaire (le modèle de vue).
func eclairees(c: Dictionary, k: int) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in (c["nav"] as Nav).cases_dans(rect(c, k)):
		if eclaire_par_lampe(c, Nav.centre_de_la_case(cc)):
			sortie.append(cc)
	return sortie


## Les « portes » d'une zone : ses cases dont un voisin (4 voisins) est praticable et HORS de la zone — là où l'on entre chez le gardien.
func portes(c: Dictionary, k: int) -> Array[Vector2i]:
	var nav: Nav = c["nav"]
	var zone := rect(c, k)
	var sortie: Array[Vector2i] = []
	for cc in nav.cases_dans(zone):
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var n := cc + d
			if nav.est_praticable(n) and not zone.has_point(n):
				sortie.append(cc)
				break
	return sortie


func dans_une_zone(c: Dictionary, cc: Vector2i) -> bool:
	for k in zones(c):
		if rect(c, k).has_point(cc):
			return true
	return false


## Les cases praticables qui ne sont dans AUCUNE zone.
func hors_zones(c: Dictionary) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in (c["nav"] as Nav).cases_praticables():
		if not dans_une_zone(c, cc):
			sortie.append(cc)
	return sortie


## La part des cases d'une zone qu'une position voit (ligne de vue, à moins de `rayon` px).
func part_en_vue(c: Dictionary, pos: Vector2, k: int, rayon: float) -> float:
	var cases := (c["nav"] as Nav).cases_dans(rect(c, k))
	var n := 0
	for cc in cases:
		var p := Nav.centre_de_la_case(cc)
		if p.distance_to(pos) <= rayon and ligne_de_vue(c, pos, p):
			n += 1
	return float(n) / float(maxi(cases.size(), 1))


## Les morceaux (4 voisins) d'un ensemble de cases.
func composantes(cases: Array[Vector2i]) -> Array:
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


## Les cases d'un tour qu'une lampe de la salle éclaire.
func cases_eclairees(c: Dictionary, cases: Array[Vector2i]) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in cases:
		if eclaire_par_lampe(c, Nav.centre_de_la_case(cc)):
			sortie.append(cc)
	return sortie


func communes(a: Array[Vector2i], b: Array[Vector2i]) -> Array[Vector2i]:
	var dans_b := {}
	for cc in b:
		dans_b[cc] = true
	var sortie: Array[Vector2i] = []
	for cc in a:
		if dans_b.has(cc) and not sortie.has(cc):
			sortie.append(cc)
	return sortie


## Les places où le joueur peut faire du bruit pour un gardien de zone : les cases praticables hors de toute zone (une sur `pas`), en pixels.
func places_du_joueur(c: Dictionary, pas: int = 2) -> Array[Vector2]:
	var sortie: Array[Vector2] = []
	var cases := hors_zones(c)
	for i in range(0, cases.size(), pas):
		sortie.append(Nav.centre_de_la_case(cases[i]))
	return sortie


## Toutes les places où le joueur peut se tenir (les cases praticables, une sur `pas`), en pixels : il va où il veut, et sa torche ou ses tirs le font voir.
func toutes_les_places(c: Dictionary, pas: int = 3) -> Array[Vector2]:
	var sortie: Array[Vector2] = []
	var cases: Array[Vector2i] = (c["nav"] as Nav).cases_praticables()
	for i in range(0, cases.size(), pas):
		sortie.append(Nav.centre_de_la_case(cases[i]))
	return sortie


## La part des cases d'un tour (ou de toute liste de cases) qu'une position voit : ligne de vue, à moins de `rayon` px.
func part_des_cases_en_vue(c: Dictionary, pos: Vector2, cases: Array[Vector2i], rayon: float) -> float:
	var n := 0
	for cc in cases:
		var p := Nav.centre_de_la_case(cc)
		if p.distance_to(pos) <= rayon and ligne_de_vue(c, pos, p):
			n += 1
	return float(n) / float(maxi(cases.size(), 1))


## Le plus grand rayon de zone, en px, que donne un son de `famille` émis en `source` à un PNJ placé n'importe où parmi `cases` — `INF` si l'une d'elles ne l'entend pas du tout.
func pire_rayon(c: Dictionary, famille: String, source: Vector2, cases: Array[Vector2i], accroupi: bool = false) -> float:
	var pire := 0.0
	for cc in cases:
		pire = maxf(pire, rayon_entendu(c, famille, source, Nav.centre_de_la_case(cc), accroupi))
	return pire


## Les cases par où un PNJ peut passer : celles de sa zone qu'il rejoint sans en sortir, celles de son tour, ou — libre — toutes celles qu'il rejoint à pied.
func cases_du_pnj(c: Dictionary, k: int) -> Array[Vector2i]:
	var p: Dictionary = c["pnj"][k]
	match int(p["profil"].deplacement):
		Profil.Deplacement.ZONE:
			return cases_de_la_zone_atteignables(c, k)
		Profil.Deplacement.RONDE:
			return cases_du_tour(tour_de_la_ronde(c, k))
		Profil.Deplacement.LIBRE:
			var sortie: Array[Vector2i] = []
			sortie.assign((c["nav"] as Nav).cases_atteignables(p["case"]))
			return sortie
	var seule: Array[Vector2i] = [p["case"]]
	return seule


# ---------------------------------------------------------------------------
# L'OUÏE, DERRIÈRE LES MURS
# ---------------------------------------------------------------------------

## Le rayon de la zone qu'un PNJ en `auditeur` tire d'un son de `famille` émis en `source` — avec les murs de la salle (`PerceptionBot.ecouter` sur le monde réel) —,
## ou `INF` s'il ne l'entend pas du tout. `accroupi` : un pas accroupi.
func rayon_entendu(c: Dictionary, famille: String, source: Vector2, auditeur: Vector2, accroupi: bool = false) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bot := {"position": auditeur, "id": 1, "accroupi": false, "visee": Vector2.RIGHT}
	var r := Percep.ecouter(_evenement(racine, famille, source, accroupi), bot, c["monde"], rng)
	return INF if r.is_empty() else float(r["rayon"])


## Le son est-il entendu NET (assez pour qu'un PNJ tire sur la zone : `ProfilBot.AUDACE_ZONE_PX`) ?
func net(c: Dictionary, famille: String, source: Vector2, auditeur: Vector2, accroupi: bool = false) -> bool:
	return rayon_entendu(c, famille, source, auditeur, accroupi) <= Profil.AUDACE_ZONE_PX


## Le son est-il entendu, si peu que ce soit ?
func entendu(c: Dictionary, famille: String, source: Vector2, auditeur: Vector2, accroupi: bool = false) -> bool:
	return rayon_entendu(c, famille, source, auditeur, accroupi) < INF


## La plus petite distance, en px, à partir de laquelle un pas ACCROUPI n'est plus entendu net, majorée d'un corps et d'une case : « à l'abri ».
func abri_accroupi() -> float:
	return portee_pas_accroupi_net + MARGE_PX + 18.0


## Un son de `famille` émis en `source` est-il entendu NET d'un PNJ placé n'importe où parmi `cases` ? (`tous` : de toutes ; sinon : d'au moins une.)
func net_de_toutes(c: Dictionary, famille: String, source: Vector2, cases: Array[Vector2i], accroupi: bool = false) -> bool:
	for cc in cases:
		if not net(c, famille, source, Nav.centre_de_la_case(cc), accroupi):
			return false
	return true


func net_d_au_moins_une(c: Dictionary, famille: String, source: Vector2, cases: Array[Vector2i], accroupi: bool = false) -> bool:
	for cc in cases:
		if net(c, famille, source, Nav.centre_de_la_case(cc), accroupi):
			return true
	return false


## Combien de cases de `cases` entendent NET le son (un pas, un tir…) émis en `source`.
func combien_entendent_net(c: Dictionary, famille: String, source: Vector2, cases: Array[Vector2i], accroupi: bool = false) -> int:
	var n := 0
	for cc in cases:
		if net(c, famille, source, Nav.centre_de_la_case(cc), accroupi):
			n += 1
	return n


# ---------------------------------------------------------------------------
# LE GADGET PEUT-IL SE POSER ?
# ---------------------------------------------------------------------------

## La règle du gadget de la classe (`EquipementBot.GADGETS[slug]`) a-t-elle SA place dans la salle ? Il faut une case que le PNJ `k` peut tenir (`cases_du_pnj`) et une
## des `cibles` (des places du monde, en px) à une distance de la fenêtre de la règle, avec une ligne DÉGAGÉE jusqu'à elle — le bot ne plante pas un gadget dans une paroi.
## Rend la case trouvée, ou `(-1, -1)`. La fenêtre est LUE dans la table du jeu : jamais recopiée ici.
func peut_poser(c: Dictionary, k: int, classe: String, cibles: Array[Vector2]) -> Vector2i:
	var regle: Dictionary = Equipement.GADGETS[GADGET_DE_LA_CLASSE[classe]]
	var fenetre: Array = regle["distance"]
	for cc in cases_du_pnj(c, k):
		var pos := Nav.centre_de_la_case(cc)
		for cible in cibles:
			var d := pos.distance_to(cible)
			if d >= float(fenetre[0]) and d <= float(fenetre[1]) and Percep.segment_degage(pos, cible, c["monde"]):
				return cc
	return Vector2i(-1, -1)


# ---------------------------------------------------------------------------
# LA FORME D'UNE SALLE
# ---------------------------------------------------------------------------

## Les cases praticables dont TOUT le disque de `rayon_px` est du sol libre (ni mur plein, ni mur bas, ni vide) — là où un nuage de cette taille tient sans toucher une paroi.
func cases_ouvertes(c: Dictionary, rayon_px: float) -> Array[Vector2i]:
	var nav: Nav = c["nav"]
	var r_cases := int(ceil(rayon_px / 35.0)) + 1
	var sortie: Array[Vector2i] = []
	for cc in nav.cases_praticables():
		var centre := Nav.centre_de_la_case(cc)
		var ouvert := true
		for dy in range(-r_cases, r_cases + 1):
			for dx in range(-r_cases, r_cases + 1):
				var autre := cc + Vector2i(dx, dy)
				if Nav.centre_de_la_case(autre).distance_to(centre) <= rayon_px and not nav.est_libre(autre):
					ouvert = false
					break
			if not ouvert:
				break
		if ouvert:
			sortie.append(cc)
	return sortie


## Les blocs de mur plein INTÉRIEURS (ceux que la ceinture ne touche pas), en 8 voisins : un anneau de couloir en contourne un ; des îlots, plusieurs.
func blocs_interieurs(c: Dictionary) -> Array:
	var taille: Vector2i = c["taille"]
	var murs: Array[Vector2i] = []
	for cc in Codec.get_wall_cells(c["carte"]):
		murs.append(cc)
	var reste := {}
	for cc in murs:
		reste[cc] = true
	var sortie: Array = []
	for depart in murs:
		if not reste.has(depart):
			continue
		var morceau: Array[Vector2i] = []
		var pile: Array[Vector2i] = [depart]
		reste.erase(depart)
		var touche_la_ceinture := false
		while not pile.is_empty():
			var cc: Vector2i = pile.pop_back()
			morceau.append(cc)
			if cc.x == 0 or cc.y == 0 or cc.x == taille.x - 1 or cc.y == taille.y - 1:
				touche_la_ceinture = true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := cc + Vector2i(dx, dy)
					if reste.has(n):
						reste.erase(n)
						pile.append(n)
		if not touche_la_ceinture:
			sortie.append(morceau)
	return sortie


## Les cases praticables qui n'ont qu'UN voisin praticable (4 voisins) ou aucun : les culs-de-sac d'une case, où un chasseur se coincerait et où l'on serait pris.
func culs_de_sac(c: Dictionary) -> Array[Vector2i]:
	var nav: Nav = c["nav"]
	var sortie: Array[Vector2i] = []
	for cc in nav.cases_praticables():
		var voisins := 0
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			if nav.est_praticable(cc + d):
				voisins += 1
		if voisins < 2:
			sortie.append(cc)
	return sortie


## La longueur, en cases, de la suite de cases praticables qui passe par `cc` dans la direction `axe` (`Vector2i.RIGHT` : la rangée ; `Vector2i.DOWN` : la colonne).
func longueur_de_la_course(c: Dictionary, cc: Vector2i, axe: Vector2i) -> int:
	var nav: Nav = c["nav"]
	var n := 1
	var p := cc + axe
	while nav.est_praticable(p):
		n += 1
		p += axe
	p = cc - axe
	while nav.est_praticable(p):
		n += 1
		p -= axe
	return n


## Les cases de sol (praticables) qui ne sont pas dans le noir : l'une des lampes de la salle les éclaire.
func cases_claires(c: Dictionary) -> Array[Vector2i]:
	return cases_eclairees(c, (c["nav"] as Nav).cases_praticables())


## Combien de cases praticables de `cases` sont à plus de `px` de toute case de `autres`.
func distance_min_a(pos: Vector2, cases: Array[Vector2i]) -> float:
	var d := INF
	for cc in cases:
		d = minf(d, Nav.centre_de_la_case(cc).distance_to(pos))
	return d
