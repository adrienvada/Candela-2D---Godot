## La garde du CHAPITRE 1 — chantier SOLO, étape S8 : chaque salle enseigne ce qu'elle dit.
##
## Le chapitre 1, « Les rondes », est écrit dans `res://assets/solo/chapitre_01/` (par `tools/fabrique_chapitre_01.gd`). Cette suite ne regarde pas si les
## fichiers sont bien formés (le validateur le fait) mais si chaque salle fait ce que le plan lui demande : les PNJ marchent, leurs trajets se répètent, on
## apprend à les lire, puis à choisir son moment. Tout est MESURÉ sur les données, avec les fonctions du jeu (`tools/outils_chapitre.gd` : les chemins de
## `NavigationBot`, le modèle de vue du bot, la portée de la torche du Parasite, l'ouïe réelle de l'audio).
##
## Partout (`OutilsChapitre.partout`) : la taille, les PNJ de chaque sorte, les plafonniers, les PNJ équipés (la classe du boss et sa suie, à partir de 1.7), chaque
## PNJ atteignable à pied, une seule pièce, aucun couloir d'une tuile, chaque ronde une BOUCLE praticable, le départ à l'abri. Puis, salle par salle : 1.1 la
## ronde repasse sous la lampe ; 1.2 deux rondes partagent des cases, sous les lampes, sans se toucher ; 1.3 aucune lampe, aucune case ne montre le tour entier à la
## torche ; 1.4 la ronde passe dans le champ d'un guetteur, et une case la voit sans être vue de lui ; 1.5 le passage de la lampe est vu d'elle tantôt, tantôt
## non, et assez longtemps pour le traverser ; 1.6 trois lampes en ligne, chaque ronde en traverse deux, la flaque du milieu est commune, un affût existe dans le
## noir ; 1.7 un U, un garde par bras, la suie ; 1.8 des murets, trois rondes, un poste qui en voit une ; 1.9 des colonnes, trois rondes, deux immobiles dans le noir ;
## 1.10 un duel en miroir.
##
## **Sabotée salle par salle** (une garde « enseigne » ne se croit qu'après l'avoir vue rougir) — la liste est dans la ROADMAP, S8. Pour saboter sans toucher aux
## fichiers livrés : `-- --dossier=<chemin absolu d'une copie du chapitre>`.
##
## Lancer : godot --headless --path . --script res://tools/test_chapitre_01.gd
extends SceneTree

const Outils := preload("res://tools/outils_chapitre.gd")
const Nav := preload("res://navigation_bot.gd")
const Profil := preload("res://profil_bot.gd")
const Codec := preload("res://map_codec.gd")

const DOSSIER_LIVRE := "res://assets/solo/chapitre_01"
const NUMERO := 1
const CLASSE := "fumiste"

## Une ligne par salle : les PNJ par profil, les plafonniers, les PNJ équipés, le côté (min, max).
const TABLE := [
	{"pnj": {"ronde_sourd_aveugle": 1}, "lampes": 1, "equipes": 0, "cotes": [16, 24]},
	{"pnj": {"ronde_sourd_aveugle": 2}, "lampes": 2, "equipes": 0, "cotes": [20, 28]},
	{"pnj": {"ronde_sourd_aveugle": 1}, "lampes": 0, "equipes": 0, "cotes": [20, 36]},
	{"pnj": {"ronde_sourd_aveugle": 1, "immobile_voit_lent": 1}, "lampes": 1, "equipes": 0, "cotes": [16, 24]},
	{"pnj": {"ronde_voit_lent": 1}, "lampes": 1, "equipes": 0, "cotes": [16, 36]},
	{"pnj": {"ronde_voit_lent": 2}, "lampes": 3, "equipes": 0, "cotes": [14, 40]},
	{"pnj": {"ronde_voit_lent": 2}, "lampes": 1, "equipes": 2, "cotes": [20, 28]},
	{"pnj": {"ronde_voit_lent": 3, "immobile_voit_lent": 1}, "lampes": 2, "equipes": 3, "cotes": [20, 32]},
	{"pnj": {"ronde_voit_lent": 3, "immobile_sourd_aveugle": 2}, "lampes": 3, "equipes": 3, "cotes": [28, 48]},
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
	print("=== LE CHAPITRE 1 — LES RONDES (S8) ===")
	var dossier := DOSSIER_LIVRE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="):
			dossier = a.substr(10)
	o = Outils.new(Callable(self, "_check"))
	o.mesures_du_jeu(root)
	if not o.charger(dossier, NUMERO, "Les rondes", CLASSE, 10):
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

## Les cases d'un tour qu'une lampe éclaire (le modèle de vue).
func _cases_eclairees(c: Dictionary, tour: Array[Vector2i]) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in tour:
		if o.eclaire_par_lampe(c, Nav.centre_de_la_case(cc)):
			sortie.append(cc)
	return sortie


## Les cases communes à deux tours.
func _communes(a: Array[Vector2i], b: Array[Vector2i]) -> Array[Vector2i]:
	var dans_b := {}
	for cc in b:
		dans_b[cc] = true
	var sortie: Array[Vector2i] = []
	for cc in a:
		if dans_b.has(cc) and not sortie.has(cc):
			sortie.append(cc)
	return sortie


## Le nombre de cases de mur plein STRICTEMENT à l'intérieur du rectangle que dessinent les points d'une ronde : le « bloc » dont elle fait le tour.
func _bloc_encercle(c: Dictionary, k: int) -> int:
	var pts: Array = c["pnj"][k]["ronde"]
	var x0 := 999
	var y0 := 999
	var x1 := -1
	var y1 := -1
	for pt: Vector2i in pts:
		x0 = mini(x0, pt.x)
		y0 = mini(y0, pt.y)
		x1 = maxi(x1, pt.x)
		y1 = maxi(y1, pt.y)
	var n := 0
	for cc in Codec.get_wall_cells(c["carte"]):
		if cc.x > x0 and cc.x < x1 and cc.y > y0 and cc.y < y1:
			n += 1
	return n


# ---------------------------------------------------------------------------
# 1.1 — Une ronde
# ---------------------------------------------------------------------------

func _salle_1() -> void:
	print("\n--- 1.1 Une ronde : lire un trajet qui se répète ---")
	var c := o.ctx(0)
	var p: Dictionary = c["pnj"][0]
	var tour := o.tour_de_la_ronde(c, 0)
	var eclairees := _cases_eclairees(c, tour)
	_check("une ronde sourde et aveugle, un plafonnier, rien d'autre qui bouge", p["profil_nom"] == "ronde_sourd_aveugle" and (c["lampes"] as Array).size() == 1)
	_check("elle fait le tour d'un bloc : au moins 40 cases de mur plein à l'intérieur de son rectangle (%d)" % _bloc_encercle(c, 0), _bloc_encercle(c, 0) >= 40)
	_check("elle repasse sous la lampe à chaque tour : %d cases du tour sont éclairées (au moins 3)" % eclairees.size(), eclairees.size() >= 3)
	_check("… et la plus grande part du tour reste dans le noir : %d cases sur %d éclairées (moins d'un quart)" % [eclairees.size(), tour.size()], eclairees.size() * 4 < tour.size())
	var distance := o.distance_au_tour(c["depart_pos"], tour)
	_check("le joueur part à l'écart du trajet : %.0f px de la case la plus proche (au moins 2 cases)" % distance, distance >= 2.0 * 35.0)
	print("    mesure : un tour de %d cases en %.1f s ; la lampe en éclaire %d" % [tour.size(), o.periode_de_la_ronde(tour), eclairees.size()])


# ---------------------------------------------------------------------------
# 1.2 — Le croisement
# ---------------------------------------------------------------------------

func _salle_2() -> void:
	print("\n--- 1.2 Le croisement : deux trajets qui se croisent ---")
	var c := o.ctx(1)
	var t0 := o.tour_de_la_ronde(c, 0)
	var t1 := o.tour_de_la_ronde(c, 1)
	var communes := _communes(t0, t1)
	_check("deux rondes sourdes et aveugles, deux plafonniers", (c["pnj"] as Array).size() == 2 and (c["lampes"] as Array).size() == 2)
	_check("deux trajets DIFFÉRENTS : chacun a des cases que l'autre n'a pas (%d et %d cases, %d communes)" % [t0.size(), t1.size(), communes.size()],
		communes.size() < t0.size() and communes.size() < t1.size())
	_check("ils se croisent : au moins une case commune aux deux tours (%d)" % communes.size(), communes.size() >= 1)
	var eclairees := _cases_eclairees(c, communes)
	_check("… et un croisement au moins se fait sous une lampe : %d case(s) communes éclairées" % eclairees.size(), eclairees.size() >= 1)
	var ecart := o.ecart_minimal_des_rondes(c, [0, 1])
	_check("ils se croisent sans se toucher : les deux PNJ ne passent jamais à moins de 40 px l'un de l'autre sur un tour (%.0f px)" % ecart, ecart >= 40.0)
	# Une croix : le sol est loin de remplir son rectangle.
	var taille: Vector2i = c["taille"]
	var sol: int = (c["nav"] as Nav).cases_praticables().size()
	_check("une salle en croix : le sol occupe moins de 85 %% du rectangle (%d cases sur %d)" % [sol, (taille.x - 2) * (taille.y - 2)], float(sol) < 0.85 * float((taille.x - 2) * (taille.y - 2)))
	var distance := minf(o.distance_au_tour(c["depart_pos"], t0), o.distance_au_tour(c["depart_pos"], t1))
	_check("le joueur part à l'écart des deux trajets : %.0f px (au moins 2 cases)" % distance, distance >= 2.0 * 35.0)


# ---------------------------------------------------------------------------
# 1.3 — La ronde dans le noir
# ---------------------------------------------------------------------------

func _salle_3() -> void:
	print("\n--- 1.3 La ronde dans le noir : la suivre à l'oreille et à la torche ---")
	var c := o.ctx(2)
	var nav: Nav = c["nav"]
	var tour := o.tour_de_la_ronde(c, 0)
	var distincts := o.cases_du_tour(tour)
	_check("aucun plafonnier : le trajet entier est dans le noir", (c["lampes"] as Array).is_empty())
	# La meilleure case d'où la torche voit le tour : portée de torche, ligne de vue. Aucune n'en montre plus que la moitié : il faut la suivre.
	var meilleure := 0
	var ou := Vector2i(-1, -1)
	for cc in nav.cases_praticables():
		var pos := Nav.centre_de_la_case(cc)
		var vues := 0
		for t in distincts:
			var pt := Nav.centre_de_la_case(t)
			if pos.distance_to(pt) <= o.portee_torche - Outils.MARGE_PX and o.ligne_de_vue(c, pos, pt):
				vues += 1
		if vues > meilleure:
			meilleure = vues
			ou = cc
	var part := float(meilleure) / float(distincts.size())
	_check("aucune case ne montre à la torche plus de la moitié du tour : au mieux %d cases sur %d (%.0f %%, depuis %s)" % [meilleure, distincts.size(), 100.0 * part, str(ou)], part <= 0.5)
	_check("… et pourtant elle se voit : une case montre au moins 20 cases du tour (%d)" % meilleure, meilleure >= 20)
	# À l'oreille : un grand tour, qui passe à portée d'un pas de tout le sol — on l'entend d'où qu'on se tienne.
	var plus_loin := 0.0
	for cc in nav.cases_praticables():
		plus_loin = maxf(plus_loin, o.distance_au_tour(Nav.centre_de_la_case(cc), tour))
	_check("on l'entend d'où qu'on soit : la case la plus éloignée du trajet en est à %.0f px, moins que la portée d'un pas (%.0f px)" % [plus_loin, o.portee_pas_debout_totale], plus_loin < o.portee_pas_debout_totale)
	_check("un grand tour : au moins 60 cases (%d)" % tour.size(), tour.size() >= 60)
	print("    mesure : un tour de %d cases en %.1f s" % [tour.size(), o.periode_de_la_ronde(tour)])


# ---------------------------------------------------------------------------
# 1.4 — Le guetteur
# ---------------------------------------------------------------------------

func _salle_4() -> void:
	print("\n--- 1.4 Le guetteur : une ronde passe devant un immobile qui voit ---")
	var c := o.ctx(3)
	var nav: Nav = c["nav"]
	var ronde := -1
	var guetteur := -1
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil"].deplacement == Profil.Deplacement.RONDE:
			ronde = k
		else:
			guetteur = k
	var g: Dictionary = c["pnj"][guetteur]
	var tour := o.tour_de_la_ronde(c, ronde)
	_check("une ronde sourde et aveugle, un guetteur immobile qui voit, aux réflexes lents, un plafonnier",
		g["profil_nom"] == "immobile_voit_lent" and g["profil"].voit and g["profil"].tire and (c["lampes"] as Array).size() == 1)
	_check("le guetteur est sous la lampe : on le voit sans torche, il ne voit que ce qui est éclairé", o.eclaire_par_lampe(c, g["pos"]))
	# La ronde passe devant lui : une partie du tour est dans son champ (ligne de vue, moins de 8 cases).
	var devant := 0
	for cc in tour:
		var pos := Nav.centre_de_la_case(cc)
		if pos.distance_to(g["pos"]) <= 8.0 * 35.0 and o.ligne_de_vue(c, g["pos"], pos):
			devant += 1
	_check("la ronde passe devant lui : %d cases du tour sont dans son champ (ligne de vue, moins de 8 cases) — au moins 4" % devant, devant >= 4)
	# … et une autre partie lui est cachée (le pilier).
	var caches := 0
	for cc in tour:
		if not o.ligne_de_vue(c, g["pos"], Nav.centre_de_la_case(cc)):
			caches += 1
	_check("… et une partie du tour lui est CACHÉE par le pilier : %d cases sur %d (au moins un quart)" % [caches, tour.size()], caches * 4 >= tour.size())
	# Un affût : une case dans le noir d'où l'on voit la ronde à la torche, sans que le guetteur voie cette case.
	var affut := Vector2i(-1, -1)
	for cc in nav.cases_atteignables(c["depart"]):
		var pos := Nav.centre_de_la_case(cc)
		if o.sous_une_lampe(c, pos) or o.ligne_de_vue(c, g["pos"], pos):
			continue
		for t in tour:
			var pt := Nav.centre_de_la_case(t)
			if pos.distance_to(pt) <= o.portee_torche - Outils.MARGE_PX and o.ligne_de_vue(c, pos, pt) and not o.ligne_de_vue(c, g["pos"], pt):
				affut = cc
				break
		if affut.x >= 0:
			break
	_check("un affût : une case dans le noir, que le guetteur ne voit pas, d'où l'on voit à la torche un point de la ronde qu'il ne voit pas non plus (%s)" % str(affut), affut.x >= 0)


# ---------------------------------------------------------------------------
# 1.5 — Elle regarde
# ---------------------------------------------------------------------------

func _salle_5() -> void:
	print("\n--- 1.5 Elle regarde : traverser le champ d'une ronde au bon moment ---")
	var c := o.ctx(4)
	var p: Dictionary = c["pnj"][0]
	var tour := o.tour_de_la_ronde(c, 0)
	var lampe: Dictionary = c["lampes"][0]
	_check("une ronde qui VOIT, aux réflexes lents, et un plafonnier", p["profil_nom"] == "ronde_voit_lent" and p["profil"].voit and (c["lampes"] as Array).size() == 1)
	# Deux couloirs parallèles : la cloison est un grand bloc de mur au milieu.
	_check("deux couloirs parallèles : une cloison d'au moins 60 cases de mur plein au milieu (%d)" % _bloc_encercle(c, 0), _bloc_encercle(c, 0) >= 60)
	# Le passage est la flaque : la lampe y est, éclairée, et le joueur n'y est pas encore.
	var x: Vector2 = lampe["pos"]
	var vue: Array[bool] = []
	for cc in tour:
		vue.append(o.voit(c, Nav.centre_de_la_case(cc), x, o.lumieres(c)))
	var n_vue := 0
	for v in vue:
		if v:
			n_vue += 1
	# La plus longue série de cases du tour d'où le passage n'est PAS vu : le temps qu'on a pour le traverser.
	var serie := 0
	var courante := 0
	for k in vue.size() * 2:
		if not vue[k % vue.size()]:
			courante += 1
			serie = maxi(serie, mini(courante, vue.size()))
		else:
			courante = 0
	var temps := float(serie) * 35.0 / (Outils.ALLURE_RONDE * Outils.VITESSE_JOUEUR)
	_check("elle voit le passage éclairé d'une partie de son tour (%d cases sur %d) : traverser n'est pas toujours permis" % [n_vue, tour.size()], n_vue >= 6)
	_check("… et pas de tout son tour : elle en est aveugle sur %d cases d'affilée, soit %.1f s (au moins 2,5 s pour traverser)" % [serie, temps], temps >= 2.5 and serie < tour.size())
	_check("le passage se traverse en moins de temps qu'elle n'en laisse : 5 cases à 260 px/s = %.1f s" % (5.0 * 35.0 / Outils.VITESSE_JOUEUR), 5.0 * 35.0 / Outils.VITESSE_JOUEUR < temps)
	var distance := o.distance_au_tour(c["depart_pos"], tour)
	_check("le départ est à l'écart du trajet : %.0f px (au moins 2 cases)" % distance, distance >= 2.0 * 35.0)


# ---------------------------------------------------------------------------
# 1.6 — Sous la lumière
# ---------------------------------------------------------------------------

func _salle_6() -> void:
	print("\n--- 1.6 Sous la lumière : les rondes traversent les plafonniers, les attendre là ---")
	var c := o.ctx(5)
	var nav: Nav = c["nav"]
	var lampes: Array = c["lampes"]
	# Une enfilade : trois lampes sur une même ligne, du même écart.
	var ys := {}
	for l: Dictionary in lampes:
		ys[(l["case"] as Vector2i).y] = true
	_check("trois plafonniers en enfilade : sur une même ligne (y = %s)" % str(ys.keys()), lampes.size() == 3 and ys.size() == 1)
	var tours: Array = [o.tour_de_la_ronde(c, 0), o.tour_de_la_ronde(c, 1)]
	var pools: Array = []   # pour chaque ronde, les lampes (indices) qu'elle traverse
	for k in 2:
		var traversees: Array[int] = []
		for j in lampes.size():
			for cc in (tours[k] as Array[Vector2i]):
				if o.eclaire_par_cette_lampe(c, lampes[j], Nav.centre_de_la_case(cc)):
					traversees.append(j)
					break
		pools.append(traversees)
		_check("la ronde %d traverse au moins DEUX flaques (%s)" % [k + 1, str(traversees)], traversees.size() >= 2)
	var communes: Array[int] = []
	for j in lampes.size():
		if (pools[0] as Array).has(j) and (pools[1] as Array).has(j):
			communes.append(j)
	_check("une flaque est commune aux deux rondes : on les y attend toutes les deux (%s)" % str(communes), not communes.is_empty())
	var ecart := o.ecart_minimal_des_rondes(c, [0, 1])
	_check("les deux rondes ne se touchent jamais : %.0f px d'écart au plus près (au moins 40)" % ecart, ecart >= 40.0)
	# Un affût : dans le noir, une case d'où l'on voit une case éclairée du tour, que le PNJ posé sur cette case ne voit pas (il ne voit que ce qui est éclairé).
	for k in 2:
		var affut := Vector2i(-1, -1)
		var vise := Vector2i(-1, -1)
		for t in o.cases_du_tour(tours[k]):
			var pt := Nav.centre_de_la_case(t)
			if not o.eclaire_par_lampe(c, pt):
				continue
			for cc in nav.cases_atteignables(c["depart"]):
				var pos := Nav.centre_de_la_case(cc)
				if o.sous_une_lampe(c, pos) or pos.distance_to(pt) > 8.0 * 35.0 or not o.ligne_de_vue(c, pos, pt):
					continue
				if not o.voit(c, pt, pos, o.lumieres(c)):
					affut = cc
					vise = t
					break
			if affut.x >= 0:
				break
		_check("ronde %d : un affût dans le noir (%s) d'où l'on voit à moins de 8 cases un point éclairé de son tour (%s), sans qu'elle voie l'affût" % [k + 1, str(affut), str(vise)], affut.x >= 0)


# ---------------------------------------------------------------------------
# 1.7 — La suie
# ---------------------------------------------------------------------------

func _salle_7() -> void:
	print("\n--- 1.7 La suie : une fumée bouche la vue, la sienne aussi ---")
	var c := o.ctx(6)
	var nav: Nav = c["nav"]
	var taille: Vector2i = c["taille"]
	var sol := nav.cases_praticables().size()
	_check("une salle en U : le sol occupe moins de 70 %% du rectangle (%d cases sur %d)" % [sol, (taille.x - 2) * (taille.y - 2)], float(sol) < 0.7 * float((taille.x - 2) * (taille.y - 2)))
	var t0 := o.tour_de_la_ronde(c, 0)
	var t1 := o.tour_de_la_ronde(c, 1)
	_check("deux gardes équipés du Fumiste (la clé « equipe », la classe du boss), un par bras : leurs tours ne partagent aucune case", _communes(t0, t1).is_empty() and (c["pnj"][0]["equipe"] and c["pnj"][1]["equipe"]))
	# Les deux bras ne se voient pas : la cloison du U coupe toute ligne de vue entre les deux tours, dans la partie haute.
	var se_voient := 0
	for a in t0:
		for b in t1:
			if a.y <= 12 and b.y <= 12 and o.ligne_de_vue(c, Nav.centre_de_la_case(a), Nav.centre_de_la_case(b)):
				se_voient += 1
	_check("dans les bras, les deux gardes ne se voient pas (le U les sépare) : %d couples de cases en ligne de vue" % se_voient, se_voient == 0)
	# Le fond du U est éclairé, et les deux gardes le voient tour à tour : c'est là qu'on se bat, et qu'on est enfumé.
	var lampe: Dictionary = c["lampes"][0]
	var fond: Vector2 = lampe["pos"]
	for k in 2:
		var vu := false
		for cc in o.tour_de_la_ronde(c, k):
			vu = vu or o.voit(c, Nav.centre_de_la_case(cc), fond, o.lumieres(c))
		_check("le garde %d voit le fond du U sous la lampe, d'un point de son tour" % (k + 1), vu)
	_check("le fond du U est dans le noir hors de la flaque : le départ n'est pas éclairé (%.0f px de la lampe)" % c["depart_pos"].distance_to(fond), not o.sous_une_lampe(c, c["depart_pos"]))
	# La distance de pose de la suie : elle se pose à 120-400 px de la cible : le fond du U le permet.
	var dans_la_fenetre := false
	for cc in o.tour_de_la_ronde(c, 0):
		var d: float = Nav.centre_de_la_case(cc).distance_to(fond)
		dans_la_fenetre = dans_la_fenetre or (d >= 120.0 and d <= 400.0)
	_check("… à une distance de la lampe (120 à 400 px) où la règle du Fumiste pose sa suie", dans_la_fenetre)


# ---------------------------------------------------------------------------
# 1.8 — La garde
# ---------------------------------------------------------------------------

func _salle_8() -> void:
	print("\n--- 1.8 La garde : plusieurs rondes et un poste fixe ---")
	var c := o.ctx(7)
	var nav: Nav = c["nav"]
	var bas := Codec.get_low_wall_cells(c["carte"])
	_check("une cour à murets : au moins 20 cases de mur bas (%d), et des piliers (%d cases de mur plein à l'intérieur)" % [bas.size(), o.murs_interieurs(c)], bas.size() >= 20 and o.murs_interieurs(c) >= 20)
	var rondes: Array[int] = []
	var poste := -1
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil"].deplacement == Profil.Deplacement.RONDE:
			rondes.append(k)
		else:
			poste = k
	_check("trois rondes équipées du Fumiste, un poste qui ne bouge pas", rondes.size() == 3 and poste >= 0 and c["pnj"][poste]["profil_nom"] == "immobile_voit_lent")
	# Trois tours distincts, chacun autour d'un pilier.
	var tours: Array = []
	for k in rondes:
		tours.append(o.tour_de_la_ronde(c, k))
	var distincts := true
	for a in 3:
		for b in range(a + 1, 3):
			distincts = distincts and _communes(tours[a], tours[b]).size() < 6
	_check("trois tours distincts (aucune paire n'en partage plus de 5 cases)", distincts)
	var autour := true
	for k in rondes:
		autour = autour and _bloc_encercle(c, k) >= 9
	_check("chaque ronde fait le tour d'un pilier (au moins 9 cases de mur à l'intérieur de son rectangle)", autour)
	# Le poste regarde : il voit une partie d'au moins deux tours (ligne de vue, moins de 12 cases).
	var g: Dictionary = c["pnj"][poste]
	var vus := 0
	for t in tours:
		var n := 0
		for cc: Vector2i in t:
			var pos := Nav.centre_de_la_case(cc)
			if pos.distance_to(g["pos"]) <= 12.0 * 35.0 and o.ligne_de_vue(c, g["pos"], pos):
				n += 1
		if n >= 3:
			vus += 1
	_check("le poste voit des cases d'au moins deux des trois tours (%d tours en partie dans son champ)" % vus, vus >= 2)
	_check("le poste est éclairé par une lampe : il se voit de loin", o.eclaire_par_lampe(c, g["pos"]))
	# Les murets : un mur bas sur la ligne droite entre le poste et le départ (il couvre qui s'accroupit).
	var traverses := o.murs_bas_traverses(c, c["depart_pos"], g["pos"])
	_check("un muret entre le départ et le poste : on peut s'y accroupir (%d mur(s) bas sur la ligne droite)" % traverses.size(), not traverses.is_empty())
	_check("une salle d'un seul tenant, malgré les murets (les murets laissent des passages)", nav.cases_atteignables(c["depart"]).size() == nav.cases_praticables().size())


# ---------------------------------------------------------------------------
# 1.9 — La salle pleine
# ---------------------------------------------------------------------------

func _salle_9() -> void:
	print("\n--- 1.9 La salle pleine : toutes les rondes à la fois ---")
	var c := o.ctx(8)
	var rondes: Array[int] = []
	var sourds: Array[int] = []
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil"].deplacement == Profil.Deplacement.RONDE:
			rondes.append(k)
		else:
			sourds.append(k)
	_check("trois rondes équipées du Fumiste et deux silhouettes immobiles sourdes et aveugles", rondes.size() == 3 and sourds.size() == 2)
	# Une grande salle à colonnes : au moins cinq piliers de 4 cases.
	_check("une grande salle à colonnes : au moins 5 piliers de 4 cases (%d cases de mur plein à l'intérieur)" % o.murs_interieurs(c), o.murs_interieurs(c) >= 20)
	# Trois tours distincts.
	var tours: Array = []
	for k in rondes:
		tours.append(o.tour_de_la_ronde(c, k))
	var distincts := true
	for a in 3:
		for b in range(a + 1, 3):
			distincts = distincts and _communes(tours[a], tours[b]).is_empty()
	_check("trois tours distincts, qui ne partagent aucune case", distincts)
	var ecart := o.ecart_minimal_des_rondes(c, rondes)
	_check("les trois rondes ne se touchent jamais : %.0f px d'écart au plus près (au moins 40)" % ecart, ecart >= 40.0)
	# Les immobiles : dans le noir, et hors de la vue de la torche du départ.
	for k in sourds:
		var s: Dictionary = c["pnj"][k]
		_check("l'immobile %d est dans le noir (aucune lampe ne l'éclaire) et loin du départ (%.0f px, plus que la torche)" % [k + 1, s["pos"].distance_to(c["depart_pos"])],
			not o.sous_une_lampe(c, s["pos"]) and s["pos"].distance_to(c["depart_pos"]) > o.portee_torche + Outils.MARGE_PX)
	var eclairees := 0
	for t in tours:
		eclairees += _cases_eclairees(c, t).size()
	_check("trois plafonniers sur les trajets : %d cases de tour éclairées en tout (au moins 6)" % eclairees, eclairees >= 6)
	var vastes := true
	for t in tours:
		vastes = vastes and (t as Array).size() >= 30
	_check("de grands tours : au moins 30 cases chacun", vastes)
