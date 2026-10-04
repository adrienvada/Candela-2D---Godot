## Ce que mesurent EN PLUS les gardes des chapitres 7 à 9 — chantier SOLO, étape S8, lot 2.
##
## `outils_chapitre.gd` (le lot 1) sait charger un chapitre et vérifier ce qui vaut partout : tailles, PNJ, plafonniers, rondes, zones, départ à l'abri. Les chapitres 7 à 9
## ajoutent des PNJ LIBRES — qui n'ont ni trajet ni rectangle, donc rien de ce que le lot 1 mesure pour eux — et des salles bien plus grandes que celles d'un duel. Ce fichier
## porte ce dont leurs gardes ont besoin, une fois : la lumière d'une salle (quelles cases les lampes éclairent, où sont les ombres, le noir), les îlots de mur, les distances
## à pied, et `libres_partout`, ce que vaut un PNJ libre dans CHAQUE salle (il part loin du joueur, hors de toute lampe, le joueur est à l'abri où qu'il se tienne).
##
## Aucune mesure n'est recopiée du jeu : tout passe par `OutilsChapitre` (le modèle de vue du bot, `NavigationBot`, les portées de l'ouïe réelle).

const Nav := preload("res://navigation_bot.gd")
const Percep := preload("res://perception_bot.gd")
const Profil := preload("res://profil_bot.gd")
const Codec := preload("res://map_codec.gd")

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


# ---------------------------------------------------------------------------
# LA LUMIÈRE D'UNE SALLE
# ---------------------------------------------------------------------------

## Le rayon, en px, jusqu'où le modèle de vue du bot tient une case pour éclairée par une lampe : la tache retenue (60 % du rayon de la texture) et le bord du corps.
static func rayon_clair(lampe: Dictionary) -> float:
	return float(lampe["rayon_px"]) * Percep.FRACTION_PLAFONNIER + Percep.RAYON_CORPS


## Les cases praticables qu'une lampe de la salle éclaire (le modèle de vue du bot : le rayon, et aucun mur entre la lampe et le corps).
static func claires(o, c: Dictionary) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in (c["nav"] as Nav).cases_praticables():
		if o.eclaire_par_lampe(c, Nav.centre_de_la_case(cc)):
			sortie.append(cc)
	return sortie


## Les cases praticables qu'AUCUNE lampe n'éclaire : le noir.
static func sombres(o, c: Dictionary) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in (c["nav"] as Nav).cases_praticables():
		if not o.eclaire_par_lampe(c, Nav.centre_de_la_case(cc)):
			sortie.append(cc)
	return sortie


## Les cases à l'intérieur de la tache d'une lampe (au sens du rayon) qu'un mur lui cache : l'ombre qu'un pilier jette dans sa propre flaque.
static func ombres_de_la_lampe(o, c: Dictionary, lampe: Dictionary) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	var r := rayon_clair(lampe)
	for cc in (c["nav"] as Nav).cases_praticables():
		var pos := Nav.centre_de_la_case(cc)
		if pos.distance_to(lampe["pos"]) <= r and not o.eclaire_par_cette_lampe(c, lampe, pos):
			sortie.append(cc)
	return sortie


## Le segment `a → b`, échantillonné tous les 8 px : traverse-t-il une case éclairée ?
static func segment_en_lumiere(o, c: Dictionary, a: Vector2, b: Vector2) -> bool:
	var n := maxi(2, int(a.distance_to(b) / 8.0))
	for k in range(n + 1):
		if o.eclaire_par_lampe(c, a.lerp(b, float(k) / float(n))):
			return true
	return false


# ---------------------------------------------------------------------------
# LES CASES, LES COMPOSANTES, LES ÎLOTS
# ---------------------------------------------------------------------------

## Les morceaux connexes (4 voisins) d'un ensemble de cases.
static func composantes(cases: Array[Vector2i]) -> Array:
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
			for d in DIRS:
				if reste.has(cc + d):
					reste.erase(cc + d)
					pile.append(cc + d)
		sortie.append(morceau)
	return sortie


## Les îlots : les morceaux de mur plein qui ne touchent pas la ceinture de la salle.
static func ilots(c: Dictionary) -> Array:
	var taille: Vector2i = c["taille"]
	var interieurs: Array[Vector2i] = []
	for cc in Codec.get_wall_cells(c["carte"]):
		if cc.x > 0 and cc.y > 0 and cc.x < taille.x - 1 and cc.y < taille.y - 1:
			interieurs.append(cc)
	var sortie: Array = []
	for m in composantes(interieurs):
		var touche := false
		for cc: Vector2i in m:
			for d in DIRS:
				var v: Vector2i = cc + d
				if v.x <= 0 or v.y <= 0 or v.x >= taille.x - 1 or v.y >= taille.y - 1:
					touche = true
		if not touche:
			sortie.append(m)
	return sortie


## Les cases de mur BAS de la salle.
static func murets(c: Dictionary) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in Codec.get_low_wall_cells(c["carte"]):
		sortie.append(cc)
	return sortie


## La longueur, en px, du plus court chemin à pied entre deux cases ; -1 s'il n'y en a pas.
static func distance_a_pied(o, c: Dictionary, a: Vector2i, b: Vector2i) -> float:
	var ch := (c["nav"] as Nav).chemin(a, b)
	return -1.0 if ch.is_empty() else o.longueur(ch)


## La part de `cases` qu'une position voit (ligne de vue debout, à moins de `rayon` px).
static func part_en_vue(o, c: Dictionary, pos: Vector2, cases: Array[Vector2i], rayon: float) -> float:
	var n := 0
	for cc in cases:
		var p := Nav.centre_de_la_case(cc)
		if p.distance_to(pos) <= rayon and o.ligne_de_vue(c, pos, p):
			n += 1
	return float(n) / float(maxi(cases.size(), 1))


## L'indice des PNJ de ce déplacement.
static func pnj_de(c: Dictionary, deplacement: int) -> Array[int]:
	var sortie: Array[int] = []
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil"].deplacement == deplacement:
			sortie.append(k)
	return sortie


# ---------------------------------------------------------------------------
# UN PNJ LIBRE, DANS CHAQUE SALLE
# ---------------------------------------------------------------------------

## Ce que vaut un PNJ LIBRE dans une salle, où qu'il aille : `distance_min` cases à pied du départ (ni nez à nez ni embuscade), et — puisqu'il peut se tenir partout — le
## départ n'est sous AUCUNE lampe : ce qui ne lui montre pas le joueur à sa case lui est caché depuis n'importe quelle case de la salle (le modèle de vue n'a de cible que
## par une lumière). Le test du lot 1 (`partout`) ne regarde que la case de naissance d'un PNJ ; pour un libre, c'est la salle entière.
static func libres_partout(o, c: Dictionary, nom: String, distance_min_cases: int) -> void:
	var libres := pnj_de(c, Profil.Deplacement.LIBRE)
	var nav: Nav = c["nav"]
	var plus_pres := INF
	for k in libres:
		var d := distance_a_pied(o, c, c["depart"], c["pnj"][k]["case"])
		plus_pres = minf(plus_pres, d)
	o._c("%s : %d PNJ libre(s), le plus proche à %.0f px à pied du départ (au moins %d cases)" % [nom, libres.size(), plus_pres, distance_min_cases],
		libres.is_empty() or plus_pres >= float(distance_min_cases) * 35.0)
	var sous: bool = o.sous_une_lampe(c, c["depart_pos"]) or o.eclaire_par_lampe(c, c["depart_pos"])
	o._c("%s : le départ n'est sous aucune lampe — un chasseur qui voit, où qu'il se tienne dans la salle, ne voit pas le joueur à sa case (torche éteinte)" % nom, not sous)
	var vu := ""
	for k in libres:
		if not c["pnj"][k]["profil"].voit:
			continue
		# Un échantillon de cases de la salle, vues comme postes d'observation : aucune ne révèle le joueur sans lumière.
		var cases := nav.cases_praticables()
		for i in range(0, cases.size(), maxi(1, cases.size() / 120)):
			var poste := Nav.centre_de_la_case(cases[i])
			if poste.distance_to(c["depart_pos"]) < 4.0 * 35.0:
				continue
			if o.voit(c, poste, c["depart_pos"], o.lumieres(c)):
				vu = str(cases[i])
				break
	o._c("%s : … vérifié : aucun poste de la salle (échantillon de 120 cases) ne voit le joueur à son départ avec les lampes de la salle" % nom, vu == "", vu)


# ---------------------------------------------------------------------------
# DES SALLES QUI SE DÉCOUPENT : bandes de mur, pièces, tours
# ---------------------------------------------------------------------------

## Les rangées de l'INTÉRIEUR de la salle dont au moins `part` des cases sont du mur plein : une cloison horizontale (percée de ses portes).
static func rangees_de_cloison(c: Dictionary, part: float = 0.85) -> Array[int]:
	var taille: Vector2i = c["taille"]
	var murs := {}
	for m in Codec.get_wall_cells(c["carte"]):
		murs[m] = true
	var sortie: Array[int] = []
	for y in range(1, taille.y - 1):
		var n := 0
		for x in range(1, taille.x - 1):
			if murs.has(Vector2i(x, y)):
				n += 1
		if float(n) >= part * float(taille.x - 2):
			sortie.append(y)
	return sortie


## Les cases praticables de la salle que le prédicat `garder` (Callable : Vector2i → bool) retient.
static func cases_ou(c: Dictionary, garder: Callable) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in (c["nav"] as Nav).cases_praticables():
		if garder.call(cc):
			sortie.append(cc)
	return sortie


## La plus courte distance, en px, entre deux ensembles de cases (centre à centre).
static func ecart_entre(a: Array[Vector2i], b: Array[Vector2i]) -> float:
	var d := INF
	for x in a:
		for y in b:
			d = minf(d, Nav.centre_de_la_case(x).distance_to(Nav.centre_de_la_case(y)))
	return d


## Le rectangle (en cases) qui contient les points d'une ronde.
static func boite_de_la_ronde(c: Dictionary, k: int) -> Rect2i:
	var pts: Array = c["pnj"][k]["ronde"]
	var r := Rect2i(pts[0], Vector2i.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


## Combien d'îlots ont leur centre dans le rectangle `boite` : ce qu'une ronde entoure.
static func ilots_dans(c: Dictionary, boite: Rect2i) -> int:
	var n := 0
	for m in ilots(c):
		var s := Vector2.ZERO
		for cc: Vector2i in m:
			s += Vector2(cc)
		s /= float((m as Array).size())
		if boite.has_point(Vector2i(int(s.x), int(s.y))):
			n += 1
	return n


## Combien de cases de `cases` une lampe quelconque de la salle éclaire.
static func combien_claires(o, c: Dictionary, cases: Array[Vector2i]) -> int:
	var n := 0
	for cc in cases:
		if o.eclaire_par_lampe(c, Nav.centre_de_la_case(cc)):
			n += 1
	return n


## L'aire d'une salle en cases (largeur × hauteur de la grille).
static func aire(c: Dictionary) -> int:
	var t: Vector2i = c["taille"]
	return t.x * t.y


## La plus grande aire, en cases, d'une carte de DUEL livrée (`res://assets/maps/*.json`) : la mesure à laquelle on compare « grande ».
static func aire_du_plus_grand_duel() -> int:
	var plus := 0
	var d := DirAccess.open("res://assets/maps")
	if d == null:
		return 0
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/" + f))
		if j is Dictionary and (j as Dictionary).has("grid_size"):
			var g: Dictionary = j["grid_size"]
			plus = maxi(plus, int(g["x"]) * int(g["y"]))
	return plus
