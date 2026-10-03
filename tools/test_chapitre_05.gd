## La garde du CHAPITRE 5 — chantier SOLO, étape S8 (lot 2) : chaque salle enseigne ce qu'elle dit.
##
## Le chapitre 5, « Les groupes », est écrit dans `res://assets/solo/chapitre_05/` (par `tools/fabrique_chapitre_05.gd`). Les PNJ ne sont plus seuls : rondes et zones se couvrent
## les unes les autres, un coup de feu les appelle ensemble. On apprend à défaire un groupe un à un : choisir qui tomber d'abord, en attirer un seul hors du groupe, passer là où
## un sol interdit ferme le chemin. Cette suite mesure sur les données ce que chaque salle impose, avec les fonctions du jeu (`tools/outils_chapitre.gd`,
## `tools/outils_chapitre_04_06.gd`) : le modèle de vue du bot, l'ouïe réelle d'un PNJ derrière les murs, les chemins de `NavigationBot`, la table des gadgets de S9.
##
## Partout (`OutilsChapitre.partout`) : taille, PNJ de chaque sorte, plafonniers, PNJ équipés (la classe du boss et sa nappe de braises, à partir de 5.7 — et un PNJ équipé VOIT, sans
## quoi la règle de la nappe, qui se pose en combat sur une cible vue, ne se déclencherait jamais), chaque PNJ atteignable à pied, une seule pièce, aucun couloir d'une tuile, chaque
## ronde une boucle, chaque zone assez grande, le départ à l'abri. Puis salle par salle : 5.1 deux gardiens qui se couvrent ; 5.2 une ronde qui passe sous un gardien, autour d'un
## bloc ; 5.3 trois gardiens à trois distances ; 5.4 un poste qui couvre une ronde mieux que l'autre ; 5.5 un bruit qui n'appelle qu'un seul gardien ; 5.6 un passage qu'une nappe
## ferme d'un mur à l'autre ; 5.7 la nappe peut se poser ; 5.8 une croix, quatre groupes, un poste au centre ; 5.9 trois groupes ; 5.10 un duel en miroir.
##
## Sabotée salle par salle — la liste est dans la ROADMAP, S8 (lot 2). Pour saboter sans toucher aux fichiers livrés : `-- --dossier=<chemin absolu d'une copie du chapitre>`.
##
## Lancer : godot --headless --path . --script res://tools/test_chapitre_05.gd
extends SceneTree

const Outils := preload("res://tools/outils_chapitre_04_06.gd")
const Nav := preload("res://navigation_bot.gd")
const Profil := preload("res://profil_bot.gd")
const Codec := preload("res://map_codec.gd")
const Braises := preload("res://gadget_braises.gd")

const DOSSIER_LIVRE := "res://assets/solo/chapitre_05"
const NUMERO := 5
const CLASSE := "incendiaire"

const TABLE := [
	{"pnj": {"zone_voit_entend_facile": 2}, "lampes": 1, "equipes": 0, "cotes": [16, 40]},
	{"pnj": {"zone_voit_entend_facile": 1, "ronde_voit_entend_facile": 1}, "lampes": 2, "equipes": 0, "cotes": [18, 36]},
	{"pnj": {"zone_voit_entend_facile": 3}, "lampes": 2, "equipes": 0, "cotes": [20, 40]},
	{"pnj": {"ronde_voit_entend_facile": 2, "immobile_voit_normal": 1}, "lampes": 2, "equipes": 0, "cotes": [16, 44]},
	{"pnj": {"zone_voit_entend_facile": 3}, "lampes": 2, "equipes": 0, "cotes": [18, 44]},
	{"pnj": {"zone_voit_entend_facile": 2, "ronde_voit_entend_facile": 1}, "lampes": 3, "equipes": 0, "cotes": [18, 48]},
	{"pnj": {"zone_voit_entend_normal": 2}, "lampes": 2, "equipes": 2, "cotes": [20, 40]},
	{"pnj": {"zone_voit_entend_facile": 2, "immobile_voit_entend_normal": 1, "ronde_voit_entend_facile": 2}, "lampes": 3, "equipes": 4, "cotes": [30, 36]},
	{"pnj": {"zone_voit_entend_facile": 3, "ronde_voit_entend_normal": 2}, "lampes": 4, "equipes": 5, "cotes": [34, 48]},
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
	print("=== LE CHAPITRE 5 — LES GROUPES (S8, lot 2) ===")
	var dossier := DOSSIER_LIVRE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="):
			dossier = a.substr(10)
	o = Outils.new(Callable(self, "_check"))
	o.mesures_du_jeu(root)
	if not o.charger(dossier, NUMERO, "Les groupes", CLASSE, 10):
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

## Les cases praticables communes à deux zones.
func _recouvrement(c: Dictionary, a: int, b: int) -> Array[Vector2i]:
	var nav: Nav = c["nav"]
	var dans_b := {}
	for cc in nav.cases_dans(o.rect(c, b)):
		dans_b[cc] = true
	var sortie: Array[Vector2i] = []
	for cc in nav.cases_dans(o.rect(c, a)):
		if dans_b.has(cc):
			sortie.append(cc)
	return sortie


## Les indices des PNJ de la salle, par nom de profil.
func _par_nom(c: Dictionary, nom: String) -> Array[int]:
	var sortie: Array[int] = []
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil_nom"] == nom:
			sortie.append(k)
	return sortie


## Les cases d'un tour qui sont dans la zone `rect`.
func _du_tour_dans(tour: Array[Vector2i], rect: Rect2i) -> int:
	var n := 0
	for cc in tour:
		if rect.has_point(cc):
			n += 1
	return n


## Deux listes de cases, la plus courte distance (px) entre l'une et l'autre.
func _distance_entre(a: Array[Vector2i], b: Array[Vector2i]) -> float:
	var d := INF
	for ca in a:
		for cb in b:
			d = minf(d, Nav.centre_de_la_case(ca).distance_to(Nav.centre_de_la_case(cb)))
	return d


func _bien_equipes(c: Dictionary, indices: Array) -> bool:
	var cibles := o.toutes_les_places(c)
	var tous := true
	for k in indices:
		tous = tous and o.peut_poser(c, k, CLASSE, cibles).x >= 0
	return tous


# ---------------------------------------------------------------------------
# 5.1 — Le binôme
# ---------------------------------------------------------------------------

func _salle_1() -> void:
	print("\n--- 5.1 Le binôme : deux PNJ qui se voient ---")
	var c := o.ctx(0)
	var zs := o.zones(c)
	var a: Dictionary = c["pnj"][zs[0]]
	var b: Dictionary = c["pnj"][zs[1]]
	_check("deux gardiens qui voient et entendent, aux réflexes FACILES, chacun dans sa zone", a["profil"].voit and a["profil"].entend and b["profil"].voit and b["profil"].entend
		and o.rect(c, zs[0]).has_point(a["case"]) and o.rect(c, zs[1]).has_point(b["case"]) and not o.rect(c, zs[0]).has_point(b["case"]) and not o.rect(c, zs[1]).has_point(a["case"]))
	var commun := _recouvrement(c, zs[0], zs[1])
	_check("leurs deux zones SE RECOUVRENT : %d cases praticables communes (au moins 40) — ce que l'un garde, l'autre le garde aussi" % commun.size(), commun.size() >= 40)
	_check("de là où il naît, chacun voit l'autre (ligne de vue libre, %.0f px)" % a["pos"].distance_to(b["pos"]), o.ligne_de_vue(c, a["pos"], b["pos"]))
	var lampe: Dictionary = c["lampes"][0]
	_check("la lampe est dans les DEUX zones : elle éclaire le recouvrement", o.rect(c, zs[0]).has_point(lampe["case"]) and o.rect(c, zs[1]).has_point(lampe["case"]))
	# Une case éclairée du recouvrement, vue par les deux gardiens depuis leur place : qui s'y montre est vu des deux.
	var vue_des_deux := 0
	for cc in commun:
		var pos := Nav.centre_de_la_case(cc)
		if o.eclaire_par_lampe(c, pos) and o.voit(c, a["pos"], pos, o.lumieres(c)) and o.voit(c, b["pos"], pos, o.lumieres(c)):
			vue_des_deux += 1
	_check("%d cases éclairées du recouvrement sont VUES des deux gardiens à la fois, depuis leur place (au moins 8)" % vue_des_deux, vue_des_deux >= 8)
	_check("une cloison de 16 cases au milieu, percée d'une ouverture de 8 : %d cases de mur plein à l'intérieur" % o.murs_interieurs(c), o.murs_interieurs(c) == 16)
	_check("le joueur part dans un coin, loin de la flaque (%.0f px de la lampe)" % c["depart_pos"].distance_to(lampe["pos"]), not o.sous_une_lampe(c, c["depart_pos"]))


# ---------------------------------------------------------------------------
# 5.2 — Ronde et escorte
# ---------------------------------------------------------------------------

func _salle_2() -> void:
	print("\n--- 5.2 Ronde et escorte : une ronde suivie d'un gardien ---")
	var c := o.ctx(1)
	var z := o.zones(c)[0]
	var r := o.indices(c, Profil.Deplacement.RONDE)[0]
	var tour := o.tour_de_la_ronde(c, r)
	var blocs := o.blocs_interieurs(c)
	_check("un couloir en BOUCLE : un seul bloc de mur plein à l'intérieur, que le couloir contourne (%d bloc(s), %d cases)" % [blocs.size(), (blocs[0] as Array).size() if not blocs.is_empty() else 0],
		blocs.size() == 1 and (blocs[0] as Array).size() >= 100)
	_check("une ronde qui fait le TOUR du bloc : %d cases (au moins 60), %.1f s" % [tour.size(), o.periode_de_la_ronde(tour)], tour.size() >= 60)
	var dedans := _du_tour_dans(tour, o.rect(c, z))
	_check("le gardien tient l'angle nord-est, que la ronde traverse : %d cases du tour dans sa zone (au moins 15)" % dedans, dedans >= 15 and o.rect(c, z).has_point(c["pnj"][z]["case"]))
	_check("… mais la plus grande part du tour est hors de sa zone : %d cases sur %d (au moins la moitié)" % [tour.size() - dedans, tour.size()], (tour.size() - dedans) * 2 >= tour.size())
	_check("le gardien naît à moins de 8 cases du tour : il escorte", o.distance_au_tour(c["pnj"][z]["pos"], tour) <= 8.0 * 35.0)
	var claires := o.cases_eclairees(c, tour)
	_check("deux lampes sur le tour : %d cases du tour sont éclairées (au moins 8), dont %d dans la zone du gardien" % [claires.size(), _du_tour_dans(claires, o.rect(c, z))],
		(c["lampes"] as Array).size() == 2 and claires.size() >= 8 and _du_tour_dans(claires, o.rect(c, z)) >= 3)
	var distance := o.distance_au_tour(c["depart_pos"], tour)
	_check("le joueur part dans une niche creusée dans le bloc, dans le noir, à %.0f px du tour (plus de 4 cases)" % distance,
		not o.sous_une_lampe(c, c["depart_pos"]) and distance > 4.0 * 35.0 and not o.rect(c, z).has_point(c["depart"]))


# ---------------------------------------------------------------------------
# 5.3 — Le premier tir
# ---------------------------------------------------------------------------

func _salle_3() -> void:
	print("\n--- 5.3 Le premier tir : choisir qui tomber d'abord ---")
	var c := o.ctx(2)
	var zs := o.zones(c)
	_check("trois gardiens qui voient et entendent, chacun dans sa zone", zs.size() == 3 and o.rect(c, zs[0]).has_point(c["pnj"][zs[0]]["case"]) and o.rect(c, zs[1]).has_point(c["pnj"][zs[1]]["case"])
		and o.rect(c, zs[2]).has_point(c["pnj"][zs[2]]["case"]))
	var communs := _recouvrement(c, zs[0], zs[1]).size()
	_check("au moins deux zones se recouvrent (%d cases) : une partie du sol est gardée par deux" % communs, communs >= 40)
	var voisins := 0
	for i in 3:
		for j in range(i + 1, 3):
			if o.ligne_de_vue(c, c["pnj"][zs[i]]["pos"], c["pnj"][zs[j]]["pos"]):
				voisins += 1
	_check("ils se voient, de là où ils naissent : %d paires sur 3 en ligne de vue (au moins 2 : chacun en voit un autre, aucun n'est isolé)" % voisins, voisins >= 2)
	# Trois distances du départ, assez écartées pour qu'il y ait un « premier ».
	var ds: Array[float] = []
	for k in zs:
		ds.append(float(c["pnj"][k]["pos"].distance_to(c["depart_pos"])))
	ds.sort()
	_check("trois distances du départ : %.0f, %.0f, %.0f px — au moins 3 cases d'écart entre deux gardiens voisins" % [ds[0], ds[1], ds[2]], ds[1] - ds[0] >= 3.0 * 35.0 and ds[2] - ds[1] >= 3.0 * 35.0)
	var sous_lampe := 0
	for k in zs:
		if o.eclaire_par_lampe(c, c["pnj"][k]["pos"]):
			sous_lampe += 1
	_check("deux gardiens sont sous une lampe, le troisième dans le noir : on choisit (%d sous une lampe)" % sous_lampe, sous_lampe == 2)
	var plus_pres := -1
	var d_min := INF
	for k in zs:
		if c["pnj"][k]["pos"].distance_to(c["depart_pos"]) < d_min:
			d_min = c["pnj"][k]["pos"].distance_to(c["depart_pos"])
			plus_pres = k
	_check("le plus proche du départ est sous la lampe : on le voit, il vous voit (s'il y a de la lumière)", o.eclaire_par_lampe(c, c["pnj"][plus_pres]["pos"]))
	_check("une salle ouverte : trois piliers seulement (%d cases de mur plein à l'intérieur)" % o.murs_interieurs(c), o.murs_interieurs(c) == 12)
	# Un tir du départ est entendu NET des trois : on ne tire pas en silence.
	var nets := true
	for k in zs:
		var seul: Array[Vector2i] = [c["pnj"][k]["case"]]
		nets = nets and o.net_de_toutes(c, "shoot", c["depart_pos"], seul, false)
	_check("un tir du départ est entendu NET des trois gardiens, là où ils naissent", nets)


# ---------------------------------------------------------------------------
# 5.4 — La couverture
# ---------------------------------------------------------------------------

func _salle_4() -> void:
	print("\n--- 5.4 La couverture : un immobile couvre une ronde ---")
	var c := o.ctx(3)
	var rs := o.indices(c, Profil.Deplacement.RONDE)
	var poste := _par_nom(c, "immobile_voit_normal")[0]
	var s: Dictionary = c["pnj"][poste]
	var t0 := o.tour_de_la_ronde(c, rs[0])
	var t1 := o.tour_de_la_ronde(c, rs[1])
	_check("deux rondes de même longueur (%d et %d cases), qui ne se partagent aucune case" % [t0.size(), t1.size()], t0.size() == t1.size() and o.communes(t0, t1).is_empty() and t0.size() >= 30)
	_check("elles ne se frôlent jamais : écart minimal %.0f px (au moins 100)" % o.ecart_minimal_des_rondes(c, rs), o.ecart_minimal_des_rondes(c, rs) >= 100.0)
	_check("un poste immobile, qui voit, aux réflexes NORMAUX (plus vifs que le reste) ; il garde le Parasite et n'a aucun outil", s["profil"].voit and s["profil"].delai_reaction < c["pnj"][rs[0]]["profil"].delai_reaction and not s["equipe"])
	_check("il tient le bout de la galerie, sous une lampe : on le voit de loin", s["pos"].x > 30.0 * 35.0 and o.eclaire_par_lampe(c, s["pos"]))
	var p0 := o.part_des_cases_en_vue(c, s["pos"], t0, 18.0 * 35.0)
	var p1 := o.part_des_cases_en_vue(c, s["pos"], t1, 18.0 * 35.0)
	# La ronde la plus proche du poste est la seconde ; la première lui est cachée par les blocs.
	var proche := rs[1] if o.distance_au_tour(s["pos"], t1) < o.distance_au_tour(s["pos"], t0) else rs[0]
	_check("il couvre la ronde la plus proche mieux que l'autre : %.0f %% et %.0f %% de leurs tours en ligne de vue, à moins de 18 cases" % [100.0 * p1, 100.0 * p0], proche == rs[1] and p1 >= p0 + 0.2 and p1 >= 0.35)
	var morts_proche := t1.size() - roundi(p1 * t1.size())
	_check("… et chaque tour a ses angles morts : %d cases de la seconde, %d de la première hors de sa vue (au moins 10)" % [morts_proche, t0.size() - roundi(p0 * t0.size())], morts_proche >= 10 and t0.size() - roundi(p0 * t0.size()) >= 10)
	_check("une lampe au milieu de la galerie éclaire un bout de chaque tour (%d et %d cases)" % [o.cases_eclairees(c, t0).size(), o.cases_eclairees(c, t1).size()], o.cases_eclairees(c, t0).size() >= 3 and o.cases_eclairees(c, t1).size() >= 3)
	_check("le joueur part à l'ouest, loin du poste (%.0f px)" % c["depart_pos"].distance_to(s["pos"]), c["depart_pos"].distance_to(s["pos"]) > 30.0 * 35.0)


# ---------------------------------------------------------------------------
# 5.5 — Séparer
# ---------------------------------------------------------------------------

func _salle_5() -> void:
	print("\n--- 5.5 Séparer : attirer un seul PNJ hors du groupe ---")
	var c := o.ctx(4)
	var nav: Nav = c["nav"]
	var zs := o.zones(c)
	var a: Dictionary = c["pnj"][zs[0]]
	var b: Dictionary = c["pnj"][zs[1]]
	var lui: Dictionary = c["pnj"][zs[2]]
	_check("trois gardiens : deux dans la grande salle, un dans la petite", a["pos"].x < 24.0 * 35.0 and b["pos"].x < 24.0 * 35.0 and lui["pos"].x > 26.0 * 35.0)
	_check("les deux premiers se couvrent : zones qui se recouvrent (%d cases), et ils se voient de là où ils naissent" % _recouvrement(c, zs[0], zs[1]).size(), _recouvrement(c, zs[0], zs[1]).size() >= 40 and o.ligne_de_vue(c, a["pos"], b["pos"]))
	_check("la zone du troisième mord sur la grande salle par la porte (%d cases communes avec la deuxième)" % _recouvrement(c, zs[1], zs[2]).size(), _recouvrement(c, zs[1], zs[2]).size() >= 20)
	_check("… mais il est seul chez lui : de là où il naît, il ne voit ni l'un ni l'autre (une cloison entre eux)", not o.ligne_de_vue(c, lui["pos"], a["pos"]) and not o.ligne_de_vue(c, lui["pos"], b["pos"]))
	# Une case d'où un pas debout n'est entendu net que du troisième.
	var appat := Vector2i(-1, -1)
	for cc in nav.cases_praticables():
		var pos := Nav.centre_de_la_case(cc)
		if o.net(c, "footstep", pos, lui["pos"], false) and not o.net(c, "footstep", pos, a["pos"], false) and not o.net(c, "footstep", pos, b["pos"], false):
			appat = cc
			break
	_check("un bruit à lui seul : en %s, un pas debout est entendu NET du troisième gardien, et ni de l'un ni de l'autre des deux premiers" % str(appat), appat.x >= 0)
	var tous_entendent_le_tir := true
	for k in zs:
		tous_entendent_le_tir = tous_entendent_le_tir and o.entendu(c, "shoot", Nav.centre_de_la_case(appat), c["pnj"][k]["pos"], false)
	_check("… tandis qu'un tir au même endroit s'entend des trois : on l'attire au pas, pas au feu", appat.x >= 0 and tous_entendent_le_tir)
	_check("deux lampes dans la grande salle, la petite est dans le noir", (c["lampes"] as Array).size() == 2 and not o.eclaire_par_lampe(c, lui["pos"]))


# ---------------------------------------------------------------------------
# 5.6 — Le passage brûlant
# ---------------------------------------------------------------------------

func _salle_6() -> void:
	print("\n--- 5.6 Le passage brûlant : un sol interdit qui ferme un chemin ---")
	var c := o.ctx(5)
	var nav: Nav = c["nav"]
	var passage: Array[Vector2i] = []
	for cc in nav.cases_praticables():
		if cc.x >= 15 and cc.x <= 29:
			passage.append(cc)
	var largeur := passage.size() / 15
	_check("un seul passage entre les deux halls : %d cases praticables entre les deux, 15 de long sur %d de large" % [passage.size(), largeur], passage.size() == 45 and largeur == 3)
	var diametre := 2.0 * Braises.RAYON
	_check("la nappe de braises (%.0f px de diamètre) ferme le passage (%.0f px) d'un mur à l'autre" % [diametre, largeur * 35.0], float(largeur) * 35.0 <= diametre)
	_check("… et ce n'est pas un trou : le passage fait 15 cases de long, une nappe n'en couvre que %.1f" % (diametre / 35.0), passage.size() / largeur >= 3.0 * diametre / 35.0)
	var zs := o.zones(c)
	var r := o.indices(c, Profil.Deplacement.RONDE)[0]
	_check("deux gardiens, un par hall, deux zones disjointes qui ne touchent pas le passage", zs.size() == 2 and not o.rect(c, zs[0]).intersects(o.rect(c, zs[1])) and o.rect(c, zs[0]).end.x <= 15 and o.rect(c, zs[1]).position.x >= 30)
	var tour := o.tour_de_la_ronde(c, r)
	var traversees := 0
	for cc in tour:
		if cc.x >= 15 and cc.x <= 29 and cc.y >= 8 and cc.y <= 10:
			traversees += 1
	_check("la ronde traverse le passage dans un sens, puis dans l'autre : %d cases du tour dedans (au moins 25), sur %d de tour" % [traversees, tour.size()], traversees >= 25 and tour.size() >= 60)
	var eclairees := 0
	for cc in passage:
		if o.eclaire_par_lampe(c, Nav.centre_de_la_case(cc)):
			eclairees += 1
	_check("une lampe dans le passage : %d cases éclairées sur 45 (au moins 8) — on s'y voit, on s'y bat" % eclairees, eclairees >= 8)
	_check("le joueur part dans le hall de l'ouest, hors de toute zone", not o.dans_une_zone(c, c["depart"]) and c["depart"].x < 15)
	_check("deux halls fermés : un mur plein de 15 × 7 de chaque côté du passage (%d cases de mur à l'intérieur)" % o.murs_interieurs(c), o.murs_interieurs(c) == 15 * 13)


# ---------------------------------------------------------------------------
# 5.7 — Le groupe vif
# ---------------------------------------------------------------------------

func _salle_7() -> void:
	print("\n--- 5.7 Le groupe vif : des réflexes normaux, la nappe de braises ---")
	var c := o.ctx(6)
	var zs := o.zones(c)
	var a: Dictionary = c["pnj"][zs[0]]
	_check("deux gardiens aux réflexes NORMAUX, qui voient et entendent, plus vifs que les FACILES des salles d'avant", a["profil"].delai_reaction <= 0.27 and a["profil"].delai_reaction < Profil.pnj_nomme("zone_voit_entend_facile").delai_reaction
		and a["profil_nom"] == "zone_voit_entend_normal")
	_check("deux zones qui se recouvrent (%d cases communes, au moins 60) : un seul groupe" % _recouvrement(c, zs[0], zs[1]).size(), _recouvrement(c, zs[0], zs[1]).size() >= 60)
	_check("une salle à colonnes : %d cases de mur plein à l'intérieur (au moins 36), des angles où tirer, des lignes de fuite" % o.murs_interieurs(c), o.murs_interieurs(c) >= 36)
	_check("deux lampes, au centre, au pied de la colonne du milieu : le recouvrement est éclairé", (c["lampes"] as Array).size() == 2 and o.rect(c, zs[0]).has_point(c["lampes"][0]["case"]) and o.rect(c, zs[1]).has_point(c["lampes"][1]["case"]))
	_check("le joueur part au sud, hors des deux zones, dans le noir", not o.dans_une_zone(c, c["depart"]) and not o.sous_une_lampe(c, c["depart_pos"]))
	# La règle de la nappe (`EquipementBot.GADGETS["nappe_braises"]`) : en combat sur une cible vue, 150-420 px, une ligne dégagée.
	var cibles := o.toutes_les_places(c)
	for k in zs:
		var cc := o.peut_poser(c, k, CLASSE, cibles)
		_check("gardien %d : une case de sa zone d'où la nappe se pose à 150-420 px d'une cible, ligne dégagée — la règle de l'Incendiaire peut se déclencher (%s)" % [k + 1, str(cc)], cc.x >= 0)
	# La cible doit être VUE : le recouvrement éclairé, que chacun voit de sa place, est une cible possible.
	var cible_vue := false
	for cc in _recouvrement(c, zs[0], zs[1]):
		var pos := Nav.centre_de_la_case(cc)
		if o.eclaire_par_lampe(c, pos) and o.voit(c, a["pos"], pos, o.lumieres(c)):
			cible_vue = true
	_check("et une cible VUE existe : une case éclairée du recouvrement que le premier gardien voit de sa place", cible_vue)


# ---------------------------------------------------------------------------
# 5.8 — Le carrefour
# ---------------------------------------------------------------------------

func _salle_8() -> void:
	print("\n--- 5.8 Le carrefour : des groupes sur quatre branches ---")
	var c := o.ctx(7)
	var nav: Nav = c["nav"]
	var taille: Vector2i = c["taille"]
	var sol := nav.cases_praticables().size()
	_check("une croix : le sol ne remplit que %d %% du rectangle (moins de 70 %%)" % (100 * sol / ((taille.x - 2) * (taille.y - 2))), 100 * sol < 70 * (taille.x - 2) * (taille.y - 2))
	var zs := o.zones(c)
	var rs := o.indices(c, Profil.Deplacement.RONDE)
	var poste := _par_nom(c, "immobile_voit_entend_normal")[0]
	var s: Dictionary = c["pnj"][poste]
	_check("quatre branches : deux zones (nord, sud) et deux rondes (ouest, est), et au centre un poste qui voit et entend, aux réflexes NORMAUX, sans outil", zs.size() == 2 and rs.size() == 2 and s["profil"].voit and s["profil"].entend and not s["equipe"])
	_check("les deux zones sont disjointes, hors du centre : le nord et le sud", not o.rect(c, zs[0]).intersects(o.rect(c, zs[1])) and o.rect(c, zs[0]).position.y < o.rect(c, zs[1]).position.y)
	var t0 := o.tour_de_la_ronde(c, rs[0])
	var t1 := o.tour_de_la_ronde(c, rs[1])
	_check("deux rondes de même longueur (%d cases), l'une à l'ouest, l'autre à l'est, sans case commune" % t0.size(), t0.size() == t1.size() and t0.size() >= 24 and o.communes(t0, t1).is_empty())
	_check("… et à plus de 8 cases l'une de l'autre : %.0f px" % _distance_entre(o.cases_du_tour(t0), o.cases_du_tour(t1)), _distance_entre(o.cases_du_tour(t0), o.cases_du_tour(t1)) >= 8.0 * 35.0)
	_check("elles ne se frôlent jamais : écart minimal %.0f px (au moins 200)" % o.ecart_minimal_des_rondes(c, rs), o.ecart_minimal_des_rondes(c, rs) >= 200.0)
	# Le poste voit une part de chacune des quatre branches.
	var parts: Array[float] = []
	for k in zs:
		parts.append(o.part_en_vue(c, s["pos"], k, 18.0 * 35.0))
	parts.append(o.part_des_cases_en_vue(c, s["pos"], t0, 18.0 * 35.0))
	parts.append(o.part_des_cases_en_vue(c, s["pos"], t1, 18.0 * 35.0))
	var ok_parts := true
	for p in parts:
		ok_parts = ok_parts and p >= 0.25
	_check("le poste du centre voit au moins le quart de chacune des quatre branches (%.0f %%, %.0f %%, %.0f %%, %.0f %%)" % [100 * parts[0], 100 * parts[1], 100 * parts[2], 100 * parts[3]], ok_parts)
	_check("le poste est sous la lampe du centre ; les deux rondes passent chacune sous une lampe", o.eclaire_par_lampe(c, s["pos"]) and o.cases_eclairees(c, t0).size() >= 3 and o.cases_eclairees(c, t1).size() >= 3)
	_check("le joueur part au bout du bras sud, hors des zones", not o.dans_une_zone(c, c["depart"]) and c["depart"].y >= 29)
	_check("pour chacun des quatre équipés, une case d'où la nappe se pose à 150-420 px d'une cible, ligne dégagée", _bien_equipes(c, zs + rs))


# ---------------------------------------------------------------------------
# 5.9 — La salle pleine
# ---------------------------------------------------------------------------

func _salle_9() -> void:
	print("\n--- 5.9 La salle pleine : trois groupes ---")
	var c := o.ctx(8)
	var nav: Nav = c["nav"]
	var zs := o.zones(c)
	var rs := o.indices(c, Profil.Deplacement.RONDE)
	_check("trois gardiens équipés et deux rondes aux réflexes NORMAUX, équipées", zs.size() == 3 and rs.size() == 2 and c["pnj"][rs[0]]["profil_nom"] == "ronde_voit_entend_normal")
	var disjointes := not o.rect(c, zs[0]).intersects(o.rect(c, zs[1])) and not o.rect(c, zs[1]).intersects(o.rect(c, zs[2])) and not o.rect(c, zs[0]).intersects(o.rect(c, zs[2]))
	var vastes := true
	for k in zs:
		vastes = vastes and nav.cases_dans(o.rect(c, k)).size() >= 150
	_check("trois zones disjointes, de plus de 150 cases chacune", disjointes and vastes)
	var t0 := o.tour_de_la_ronde(c, rs[0])
	var t1 := o.tour_de_la_ronde(c, rs[1])
	_check("deux rondes de même longueur (%d cases, %.1f s), sans case commune, à plus de 12 cases l'une de l'autre" % [t0.size(), o.periode_de_la_ronde(t0)],
		t0.size() == t1.size() and t0.size() >= 40 and o.communes(t0, t1).is_empty() and _distance_entre(o.cases_du_tour(t0), o.cases_du_tour(t1)) >= 12.0 * 35.0)
	_check("elles ne se frôlent jamais : écart minimal %.0f px (au moins 400)" % o.ecart_minimal_des_rondes(c, rs), o.ecart_minimal_des_rondes(c, rs) >= 400.0)
	# Trois groupes : une ronde passe dans chacune des deux zones du nord ; la zone du sud est seule.
	var d0 := _du_tour_dans(t0, o.rect(c, zs[0]))
	var d1 := _du_tour_dans(t1, o.rect(c, zs[1]))
	_check("groupe 1 : la ronde de l'ouest passe dans la zone nord-ouest (%d cases, au moins 20) ; groupe 2 : celle de l'est dans la zone nord-est (%d)" % [d0, d1], d0 >= 20 and d1 >= 20)
	var seul := _distance_entre(nav.cases_dans(o.rect(c, zs[2])), o.cases_du_tour(t0 + t1))
	_check("groupe 3 : le gardien du sud est seul — aucune ronde à moins de 5 cases de sa zone (%.0f px)" % seul, seul >= 5.0 * 35.0 and _du_tour_dans(t0, o.rect(c, zs[2])) == 0 and _du_tour_dans(t1, o.rect(c, zs[2])) == 0)
	_check("quatre plafonniers : un par zone, un au centre de la halle (%d lampes)" % (c["lampes"] as Array).size(), (c["lampes"] as Array).size() == 4)
	_check("le joueur part au sud-ouest, hors de toute zone, loin des tours (%.0f px)" % o.distance_au_tour(c["depart_pos"], t0), not o.dans_une_zone(c, c["depart"]) and o.distance_au_tour(c["depart_pos"], t0) > 10.0 * 35.0)
	_check("pour chacun des cinq équipés, une case d'où la nappe se pose à 150-420 px d'une cible, ligne dégagée", _bien_equipes(c, zs + rs))
