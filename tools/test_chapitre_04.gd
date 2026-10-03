## La garde du CHAPITRE 4 — chantier SOLO, étape S8 (lot 2) : chaque salle enseigne ce qu'elle dit.
##
## Le chapitre 4, « Les zones écoutent », est écrit dans `res://assets/solo/chapitre_04/` (par `tools/fabrique_chapitre_04.gd`). Les gardiens du chapitre 3 voyaient chez eux ;
## ceux-ci ENTENDENT : un bruit les fait converger vers la frontière de leur zone, et l'on apprend à s'approcher accroupi, à placer son bruit, à passer entre deux zones sans se
## faire entendre. Cette suite mesure sur les données ce que chaque salle impose, avec les fonctions du jeu (`tools/outils_chapitre.gd`, `tools/outils_chapitre_04_06.gd`) —
## dont l'OUÏE réelle d'un PNJ DERRIÈRE LES MURS : `PerceptionBot.ecouter` sur le monde de la salle, avec les niveaux et les portées de l'audio.
##
## Partout (`OutilsChapitre.partout`) : taille, PNJ de chaque sorte, plafonniers, PNJ équipés (la classe du boss et sa poussière, à partir de 4.7 — et un gardien équipé ENTEND,
## sans quoi la règle de la poussière, qui se pose en enquête ou en recherche sur un son, ne se déclencherait jamais), chaque PNJ atteignable à pied, une seule pièce, aucun
## couloir d'une tuile, chaque zone contient son PNJ et assez de cases pour errer, chaque ronde une boucle, le départ à l'abri. Puis salle par salle : 4.1 un pas debout s'entend
## de la porte, un pas accroupi non, et un poste de tir accroupi existe ; 4.2 un pas n'appelle que la pièce d'à côté, un tir les trois ; 4.3 un chemin où un pas accroupi n'est
## jamais entendu net, et où un pas debout l'est ; 4.4 des zones moitié claires, moitié noires, où l'on est vu et où l'on n'est qu'entendu ; 4.5 un L, une silhouette à l'angle,
## un poste d'où l'on voit les deux frontières ; 4.6 du sol ouvert où un nuage tient ; 4.7 une cour, un guetteur, trois ailes, la poussière peut se poser ; 4.8 des zones emboîtées
## et des murets qu'on franchit alors que les gardiens les contournent ; 4.9 un tir appelle les cinq ; 4.10 un duel en miroir.
##
## Sabotée salle par salle — la liste est dans la ROADMAP, S8 (lot 2). Pour saboter sans toucher aux fichiers livrés : `-- --dossier=<chemin absolu d'une copie du chapitre>`.
##
## Lancer : godot --headless --path . --script res://tools/test_chapitre_04.gd
extends SceneTree

const Outils := preload("res://tools/outils_chapitre_04_06.gd")
const Nav := preload("res://navigation_bot.gd")
const Profil := preload("res://profil_bot.gd")
const Codec := preload("res://map_codec.gd")
const Percep := preload("res://perception_bot.gd")

const DOSSIER_LIVRE := "res://assets/solo/chapitre_04"
const NUMERO := 4
const CLASSE := "pompe"

const TABLE := [
	{"pnj": {"zone_entend_facile": 1}, "lampes": 1, "equipes": 0, "cotes": [16, 40]},
	{"pnj": {"zone_entend_facile": 3}, "lampes": 2, "equipes": 0, "cotes": [14, 44]},
	{"pnj": {"zone_entend_facile": 2}, "lampes": 1, "equipes": 0, "cotes": [16, 44]},
	{"pnj": {"zone_voit_entend_facile": 2}, "lampes": 2, "equipes": 0, "cotes": [16, 40]},
	{"pnj": {"zone_voit_entend_facile": 2, "immobile_sourd_aveugle": 1}, "lampes": 2, "equipes": 0, "cotes": [20, 40]},
	{"pnj": {"zone_voit_entend_facile": 3}, "lampes": 1, "equipes": 0, "cotes": [30, 50]},
	{"pnj": {"zone_voit_entend_facile": 3, "immobile_voit_entend_facile": 1}, "lampes": 3, "equipes": 3, "cotes": [28, 44]},
	{"pnj": {"zone_voit_entend_facile": 4}, "lampes": 2, "equipes": 4, "cotes": [20, 44]},
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
	print("=== LE CHAPITRE 4 — LES ZONES ÉCOUTENT (S8, lot 2) ===")
	var dossier := DOSSIER_LIVRE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="):
			dossier = a.substr(10)
	o = Outils.new(Callable(self, "_check"))
	o.mesures_du_jeu(root)
	if not o.charger(dossier, NUMERO, "Les zones écoutent", CLASSE, 10):
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

## Toutes les cases de toutes les zones, réunies.
func _cases_des_zones(c: Dictionary) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for k in o.zones(c):
		for cc in (c["nav"] as Nav).cases_dans(o.rect(c, k)):
			if not sortie.has(cc):
				sortie.append(cc)
	return sortie


## Une case sur `pas` (un échantillon, pour ne pas rejouer l'ouïe sur chaque case).
func _echantillon(cases: Array[Vector2i], pas: int) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for i in range(0, cases.size(), pas):
		sortie.append(cases[i])
	return sortie


## Un PNJ de la salle est-il à la place `cc` dans le noir (aucune lampe ne l'éclaire) ?
func _noir(c: Dictionary, cc: Vector2i) -> bool:
	return not o.eclaire_par_lampe(c, Nav.centre_de_la_case(cc))


# ---------------------------------------------------------------------------
# 4.1 — Une pièce qui écoute
# ---------------------------------------------------------------------------

func _salle_1() -> void:
	print("\n--- 4.1 Une pièce qui écoute : s'approcher accroupi ---")
	var c := o.ctx(0)
	var nav: Nav = c["nav"]
	var k := o.zones(c)[0]
	var s: Dictionary = c["pnj"][k]
	var zone := o.rect(c, k)
	var cases := nav.cases_dans(zone)
	_check("un gardien qui ENTEND et ne voit pas, aux réflexes FACILES, dans une zone sans trajet", s["profil_nom"] == "zone_entend_facile" and not s["profil"].voit and s["profil"].entend and (s["ronde"] as Array).is_empty())
	_check("la zone est une pièce : %d cases praticables (au moins 150), et le gardien y naît" % cases.size(), cases.size() >= 150 and zone.has_point(s["case"]))
	var portes := o.portes(c, k)
	_check("la pièce n'a qu'UNE porte : %d cases de la zone ouvrent sur l'extérieur, en un seul morceau (de 3 à 6)" % portes.size(), portes.size() >= 3 and portes.size() <= 6 and o.composantes(portes).size() == 1)
	_check("le joueur part hors de la pièce, dans le noir (lampe la plus proche à %.0f px)" % o.distance_min_a(c["depart_pos"], _cases_lampes(c)), not zone.has_point(c["depart"]) and not o.sous_une_lampe(c, c["depart_pos"]))
	# Debout, le gardien entend le départ NET ; accroupi, d'aucune case de sa zone.
	var echantillon := _echantillon(cases, 3)
	_check("DEBOUT, un pas du départ est entendu NET d'une case de la zone au moins (la porte est à %.0f px)" % o.distance_min_a(c["depart_pos"], cases),
		o.net_d_au_moins_une(c, "footstep", c["depart_pos"], echantillon, false))
	_check("ACCROUPI, un pas du départ n'est entendu net d'AUCUNE case de la zone", not o.net_d_au_moins_une(c, "footstep", c["depart_pos"], echantillon, true))
	# Un poste de tir accroupi : une case hors de la zone, dans le noir, d'où un pas accroupi n'est entendu net de nulle part dans la pièce, et d'où la torche porte sur une bonne part d'elle.
	var meilleur := Vector2i(-1, -1)
	var meilleure_part := 0.0
	for cc in nav.cases_praticables():
		if zone.has_point(cc) or not _noir(c, cc) or o.sous_une_lampe(c, Nav.centre_de_la_case(cc)):
			continue
		var pos := Nav.centre_de_la_case(cc)
		var part := o.part_en_vue(c, pos, k, o.portee_torche)
		if part <= meilleure_part:
			continue
		if o.net_d_au_moins_une(c, "footstep", pos, echantillon, true):
			continue
		meilleur = cc
		meilleure_part = part
	_check("un poste de tir accroupi existe : en %s, un pas accroupi n'est entendu net de nulle part dans la pièce, et la torche (%.0f px) éclaire %.0f %% de ses cases (au moins 20 %%)" % [str(meilleur), o.portee_torche, 100.0 * meilleure_part],
		meilleur.x >= 0 and meilleure_part >= 0.2)
	var claires := o.eclairees(c, k)
	_check("la lampe est dans la pièce et n'en éclaire qu'une part : %d cases (au moins 10, moins de la moitié)" % claires.size(), zone.has_point(c["lampes"][0]["case"]) and claires.size() >= 10 and claires.size() * 2 < cases.size())


func _cases_lampes(c: Dictionary) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for l: Dictionary in c["lampes"]:
		sortie.append(l["case"])
	return sortie


# ---------------------------------------------------------------------------
# 4.2 — Le réveil
# ---------------------------------------------------------------------------

func _salle_2() -> void:
	print("\n--- 4.2 Le réveil : un tir attire les zones voisines ---")
	var c := o.ctx(1)
	var nav: Nav = c["nav"]
	var zs := o.zones(c)
	_check("trois gardiens qui entendent, chacun dans sa zone, trois zones DISJOINTES rangées d'ouest en est", zs.size() == 3 and not o.rect(c, zs[0]).intersects(o.rect(c, zs[1])) and not o.rect(c, zs[1]).intersects(o.rect(c, zs[2]))
		and not o.rect(c, zs[0]).intersects(o.rect(c, zs[2])) and o.rect(c, zs[0]).position.x < o.rect(c, zs[1]).position.x and o.rect(c, zs[1]).position.x < o.rect(c, zs[2]).position.x)
	var chacun := true
	for k in zs:
		chacun = chacun and o.rect(c, k).has_point(c["pnj"][k]["case"])
	_check("chaque gardien naît dans sa zone", chacun)
	var hors := o.hors_zones(c)
	_check("les pièces se rejoignent par des PORTES hors de toute zone : %d cases hors zones, dont un couloir où le joueur part (%s)" % [hors.size(), str(c["depart"])],
		hors.has(c["depart"]) and hors.size() >= 60)
	_check("le joueur part dans le couloir, dans le noir", not o.sous_une_lampe(c, c["depart_pos"]))
	# Un tir du départ s'entend NET de toutes les cases de toutes les zones : on réveille tout le monde.
	var tout := _cases_des_zones(c)
	var pire_tir := o.pire_rayon(c, "shoot", c["depart_pos"], tout, false)
	var nets_tir := o.combien_entendent_net(c, "shoot", c["depart_pos"], tout, false)
	_check("un TIR tiré du départ est entendu de CHAQUE case des trois zones, murs compris, à %.0f px près au plus (au plus 125 %% de la zone d'audace), net de %d cases sur %d (au moins 90 %%)" % [pire_tir, nets_tir, tout.size()],
		pire_tir <= 1.25 * Profil.AUDACE_ZONE_PX and nets_tir * 10 >= tout.size() * 9)
	var tir_net_des_trois := true
	for k in zs:
		var seul: Array[Vector2i] = [c["pnj"][k]["case"]]
		tir_net_des_trois = tir_net_des_trois and o.net_de_toutes(c, "shoot", c["depart_pos"], seul, false)
	_check("… et net de chacun des trois gardiens là où il naît : un coup de feu les réveille tous", tir_net_des_trois)
	# Un pas debout n'est entendu net que de la pièce d'à côté : le gardien du milieu l'entend, ceux des bouts non.
	var milieu: Array[Vector2i] = [c["pnj"][zs[1]]["case"]]
	var bouts: Array[Vector2i] = [c["pnj"][zs[0]]["case"], c["pnj"][zs[2]]["case"]]
	_check("un PAS debout du départ est entendu net du gardien de la pièce d'en face", o.net_d_au_moins_une(c, "footstep", c["depart_pos"], milieu, false))
	_check("… et ni de l'un ni de l'autre des deux gardiens des bouts, là où ils naissent", not o.net_d_au_moins_une(c, "footstep", c["depart_pos"], bouts, false))
	# Chaque pièce est ouverte sur le couloir par sa porte, et sur sa voisine par une autre.
	var portes_ok := true
	for k in zs:
		portes_ok = portes_ok and o.composantes(o.portes(c, k)).size() >= 1
	_check("chaque pièce a sa porte sur le couloir", portes_ok)
	var lampes_dans_zone := 0
	for l: Dictionary in c["lampes"]:
		if o.dans_une_zone(c, l["case"]):
			lampes_dans_zone += 1
	_check("deux lampes, toutes deux dans des pièces (les bouts) ; la pièce du milieu et le couloir restent dans le noir", lampes_dans_zone == 2 and _noir(c, c["pnj"][zs[1]]["case"]))
	var chemin := nav.chemin(c["pnj"][zs[0]]["case"], c["pnj"][zs[2]]["case"])
	_check("d'un bout à l'autre, un chemin de %d cases : les pièces ne sont pas une salle unique" % chemin.size(), not chemin.is_empty() and chemin.size() >= 24)


# ---------------------------------------------------------------------------
# 4.3 — Le chemin silencieux
# ---------------------------------------------------------------------------

func _salle_3() -> void:
	print("\n--- 4.3 Le chemin silencieux : passer entre deux zones qui écoutent ---")
	var c := o.ctx(2)
	var nav: Nav = c["nav"]
	var zs := o.zones(c)
	_check("deux gardiens qui entendent, deux zones disjointes, longues (au moins 100 cases chacune)", zs.size() == 2 and not o.rect(c, zs[0]).intersects(o.rect(c, zs[1]))
		and nav.cases_dans(o.rect(c, zs[0])).size() >= 100 and nav.cases_dans(o.rect(c, zs[1])).size() >= 100)
	var hors := o.hors_zones(c)
	_check("entre les deux : un couloir hors de toute zone, de %d cases (au moins 150), où le joueur part" % hors.size(), hors.size() >= 150 and hors.has(c["depart"]))
	for k in zs:
		_check("la zone %d s'ouvre sur le couloir par deux portes (%d cases, en %d morceaux)" % [k + 1, o.portes(c, k).size(), o.composantes(o.portes(c, k)).size()], o.composantes(o.portes(c, k)).size() == 2)
	# Le chemin du bout ouest au bout est du couloir.
	var fin := Vector2i(36, 10)
	var chemin := nav.chemin(c["depart"], fin)
	_check("un chemin de %d cases du départ à l'autre bout du couloir" % chemin.size(), chemin.size() >= 30)
	var tout := _echantillon(_cases_des_zones(c), 3)
	var bruyant_debout := 0
	var bruyant_accroupi := 0
	for cc in chemin:
		var pos := Nav.centre_de_la_case(cc)
		if o.net_d_au_moins_une(c, "footstep", pos, tout, false):
			bruyant_debout += 1
		if o.net_d_au_moins_une(c, "footstep", pos, tout, true):
			bruyant_accroupi += 1
	_check("DEBOUT, un pas est entendu NET d'une case de zone depuis %d cases du chemin sur %d (au moins les deux tiers)" % [bruyant_debout, chemin.size()], bruyant_debout * 3 >= chemin.size() * 2)
	_check("ACCROUPI, un pas n'est entendu net de nulle part dans les zones, d'aucune case du chemin : %d cases bruyantes" % bruyant_accroupi, bruyant_accroupi == 0)
	_check("une lampe éclaire la pièce du nord ; le couloir reste dans le noir", (c["lampes"] as Array).size() == 1 and o.dans_une_zone(c, c["lampes"][0]["case"]) and not o.sous_une_lampe(c, c["depart_pos"]))
	# Le couloir est « étroit » au regard des pièces : bien plus long que large.
	_check("un couloir, pas une salle : 36 cases de long pour 6 de large", chemin.size() >= 30)


# ---------------------------------------------------------------------------
# 4.4 — Les deux sens
# ---------------------------------------------------------------------------

func _salle_4() -> void:
	print("\n--- 4.4 Les deux sens : des zones qui voient et entendent ---")
	var c := o.ctx(3)
	var nav: Nav = c["nav"]
	var zs := o.zones(c)
	_check("deux gardiens qui VOIENT et ENTENDENT, chacun dans sa zone, deux zones disjointes", zs.size() == 2 and not o.rect(c, zs[0]).intersects(o.rect(c, zs[1]))
		and c["pnj"][zs[0]]["profil"].voit and c["pnj"][zs[0]]["profil"].entend and c["pnj"][zs[1]]["profil"].voit and c["pnj"][zs[1]]["profil"].entend)
	_check("entre les deux salles, un palier : le joueur y part, hors de toute zone, dans le noir", not o.dans_une_zone(c, c["depart"]) and not o.sous_une_lampe(c, c["depart_pos"])
		and c["depart_pos"].x > o.rect(c, zs[0]).end.x * 35.0 and c["depart_pos"].x < o.rect(c, zs[1]).position.x * 35.0)
	for k in zs:
		var cases := nav.cases_dans(o.rect(c, k))
		var claires := o.eclairees(c, k)
		_check("zone %d : la lampe en éclaire %d cases sur %d (au moins 10, et moins de la moitié) : on y est vu, ou seulement entendu" % [k + 1, claires.size(), cases.size()], claires.size() >= 10 and claires.size() * 2 < cases.size())
		# Dans la flaque, le gardien VOIT un joueur debout (ligne de vue, torche éteinte) ; dans le noir, il ne le voit pas — mais il l'entend NET, de près.
		var vu_dans_la_flaque := false
		var pas_vu_dans_le_noir_mais_entendu := false
		var gardien: Vector2 = c["pnj"][k]["pos"]
		for cc in cases:
			var pos := Nav.centre_de_la_case(cc)
			if pos.distance_to(gardien) > 10.0 * 35.0 or not o.ligne_de_vue(c, gardien, pos):
				continue
			var vu := o.voit(c, gardien, pos, o.lumieres(c))
			if claires.has(cc) and vu:
				vu_dans_la_flaque = true
			if not claires.has(cc) and not vu and o.net(c, "footstep", pos, gardien, false):
				pas_vu_dans_le_noir_mais_entendu = true
		_check("zone %d : un joueur debout, dans la flaque, est VU du gardien (à moins de 10 cases, en ligne de vue)" % [k + 1], vu_dans_la_flaque)
		_check("zone %d : … et dans le noir, il n'est PAS vu, mais son pas est entendu net" % [k + 1], pas_vu_dans_le_noir_mais_entendu)
	var piliers := o.murs_interieurs(c)
	_check("le palier est un hall à deux piliers : %d cases de mur plein à l'intérieur de la salle, en plus des deux cloisons" % piliers, piliers >= 8)


# ---------------------------------------------------------------------------
# 4.5 — L'appât
# ---------------------------------------------------------------------------

func _salle_5() -> void:
	print("\n--- 4.5 L'appât : faire venir un gardien à sa frontière ---")
	var c := o.ctx(4)
	var nav: Nav = c["nav"]
	var zs := o.zones(c)
	var taille: Vector2i = c["taille"]
	var sol := nav.cases_praticables().size()
	_check("une salle en L : le sol ne remplit que %d %% du rectangle (moins de 80 %%)" % (100 * sol / (taille.x * taille.y)), 100 * sol < 80 * (taille.x - 2) * (taille.y - 2))
	_check("deux gardiens qui voient et entendent, dans les deux bras, deux zones disjointes", zs.size() == 2 and not o.rect(c, zs[0]).intersects(o.rect(c, zs[1])))
	var cible := -1
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil_nom"] == "immobile_sourd_aveugle":
			cible = k
	_check("à l'angle, une silhouette qui ne bouge pas, hors des deux zones", cible >= 0 and not o.dans_une_zone(c, c["pnj"][cible]["case"]))
	_check("… sous une lampe : on la voit de loin", o.eclaire_par_lampe(c, c["pnj"][cible]["pos"]))
	# Un tir sur elle, tiré de l'angle, s'entend NET des deux gardiens : c'est lui, l'appât — les gardiens viennent à leur frontière.
	var tous_entendent := true
	for k in zs:
		tous_entendent = tous_entendent and o.net(c, "shoot", c["pnj"][cible]["pos"], c["pnj"][k]["pos"], false)
	_check("un tir sur la silhouette s'entend NET des deux gardiens, là où ils naissent : tirer, c'est les appeler", tous_entendent)
	var pas_entendus := true
	for k in zs:
		pas_entendus = pas_entendus and not o.net(c, "footstep", c["pnj"][cible]["pos"], c["pnj"][k]["pos"], true)
	_check("… alors qu'un pas accroupi à l'angle n'est entendu net d'aucun : on s'y poste sans les appeler", pas_entendus)
	# Un poste d'où l'on voit les deux frontières : une case hors des zones, dans le noir, avec une ligne de vue vers une porte de chaque zone, à portée de torche.
	var poste := Vector2i(-1, -1)
	for cc in nav.cases_praticables():
		if o.dans_une_zone(c, cc) or o.sous_une_lampe(c, Nav.centre_de_la_case(cc)):
			continue
		var voit_les_deux := true
		for k in zs:
			var voit := false
			for porte in o.portes(c, k):
				var p := Nav.centre_de_la_case(porte)
				if p.distance_to(Nav.centre_de_la_case(cc)) <= o.portee_torche and o.ligne_de_vue(c, Nav.centre_de_la_case(cc), p):
					voit = true
					break
			voit_les_deux = voit_les_deux and voit
		if voit_les_deux:
			poste = cc
			break
	_check("un poste hors des zones, dans le noir, d'où l'on voit à la torche une case-frontière de CHACUNE des deux zones : %s" % str(poste), poste.x >= 0)
	# Un pas debout au poste est entendu des deux gardiens ; le bruit les fait venir à la frontière : la case de leur zone la plus proche du bruit est une porte.
	for k in zs:
		var plus_proche := Vector2i(-1, -1)
		var d_min := INF
		for cc in nav.cases_dans(o.rect(c, k)):
			var d := Nav.centre_de_la_case(cc).distance_to(Nav.centre_de_la_case(poste))
			if d < d_min:
				d_min = d
				plus_proche = cc
		_check("zone %d : un bruit au poste ramène le gardien à %s, sur sa frontière (%d cases-frontière)" % [k + 1, str(plus_proche), o.portes(c, k).size()], o.portes(c, k).has(plus_proche))
		var cases_zone: Array[Vector2i] = [c["pnj"][k]["case"]]
		_check("zone %d : le bruit d'un tir au poste est entendu du gardien" % [k + 1], o.entendu(c, "shoot", Nav.centre_de_la_case(poste), c["pnj"][k]["pos"], false) and not cases_zone.is_empty())


# ---------------------------------------------------------------------------
# 4.6 — La poussière
# ---------------------------------------------------------------------------

func _salle_6() -> void:
	print("\n--- 4.6 La poussière : un sol qui trouble la vue ---")
	var c := o.ctx(5)
	var nav: Nav = c["nav"]
	var zs := o.zones(c)
	var sol := nav.cases_praticables().size()
	_check("trois gardiens qui voient et entendent, trois zones disjointes de plus de 150 cases chacune", zs.size() == 3 and not o.rect(c, zs[0]).intersects(o.rect(c, zs[1])) and not o.rect(c, zs[1]).intersects(o.rect(c, zs[2]))
		and not o.rect(c, zs[0]).intersects(o.rect(c, zs[2])) and nav.cases_dans(o.rect(c, zs[0])).size() >= 150 and nav.cases_dans(o.rect(c, zs[1])).size() >= 150 and nav.cases_dans(o.rect(c, zs[2])).size() >= 150)
	_check("un sol ouvert : %d cases de mur plein à l'intérieur pour %d cases de sol (moins de 8 %%)" % [o.murs_interieurs(c), sol], o.murs_interieurs(c) * 100 < 8 * sol)
	# Le nuage de poussière (`GadgetPoussiere.RAYON`, 168 px) tient sans toucher un mur : un grand nombre de cases ont tout leur disque en sol libre.
	var rayon_nuage := 168.0
	var ouvertes := o.cases_ouvertes(c, rayon_nuage)
	_check("un nuage de poussière de %.0f px de rayon tient en %d points de la carrière sans toucher une paroi (au moins 18 %% du sol)" % [rayon_nuage, ouvertes.size()], ouvertes.size() * 100 >= 18 * sol)
	var claires := o.cases_claires(c)
	_check("un seul plafonnier : la carrière est presque noire (%d cases éclairées sur %d, moins de 15 %%)" % [claires.size(), sol], (c["lampes"] as Array).size() == 1 and claires.size() * 100 < 15 * sol)
	var loin := true
	for k in zs:
		loin = loin and c["pnj"][k]["pos"].distance_to(c["depart_pos"]) > 15.0 * 35.0
	_check("le joueur part au coin sud-ouest, à plus de 15 cases de chaque gardien", loin)
	var taille: Vector2i = c["taille"]
	var grande: bool = taille.x >= 40 and taille.y >= 28
	_check("une grande salle : %s" % str(c["taille"]), grande)


# ---------------------------------------------------------------------------
# 4.7 — Poste et zones
# ---------------------------------------------------------------------------

func _salle_7() -> void:
	print("\n--- 4.7 Poste et zones : un guetteur et trois gardiens ---")
	var c := o.ctx(6)
	var nav: Nav = c["nav"]
	var zs := o.zones(c)
	var poste := -1
	for k in (c["pnj"] as Array).size():
		if c["pnj"][k]["profil"].deplacement == Profil.Deplacement.IMMOBILE:
			poste = k
	var s: Dictionary = c["pnj"][poste]
	_check("un guetteur immobile qui voit et entend, aux réflexes FACILES (il garde le Parasite et n'a aucun outil), et trois gardiens équipés", s["profil_nom"] == "immobile_voit_entend_facile" and not s["equipe"] and zs.size() == 3)
	var disjointes := true
	for i in 3:
		for j in range(i + 1, 3):
			disjointes = disjointes and not o.rect(c, zs[i]).intersects(o.rect(c, zs[j]))
	_check("trois zones disjointes : l'aile ouest, l'aile est, le nord ; le départ n'est dans aucune", disjointes and not o.dans_une_zone(c, c["depart"]))
	_check("le guetteur est dans la cour, hors de toute zone, sous la lampe : on le voit de loin, il ne voit que ce qui est éclairé", not o.dans_une_zone(c, s["case"]) and o.eclaire_par_lampe(c, s["pos"]))
	var d: float = s["pos"].distance_to(c["depart_pos"])
	_check("on le voit du départ (ligne de vue libre), au-delà de la portée de la torche : %.0f px contre %.0f" % [d, o.portee_torche], o.ligne_de_vue(c, c["depart_pos"], s["pos"]) and d > o.portee_torche)
	var cour := 0
	for cc in o.hors_zones(c):
		if cc.x >= 12 and cc.x <= 27 and cc.y >= 7:
			cour += 1
	_check("une cour : %d cases hors des zones, entre les ailes (au moins 150)" % cour, cour >= 150)
	_check("chaque aile s'ouvre sur la cour par une porte", o.composantes(o.portes(c, zs[0])).size() >= 1 and o.composantes(o.portes(c, zs[1])).size() >= 1 and o.composantes(o.portes(c, zs[2])).size() >= 1)
	# La règle de la poussière : en enquête sur un son, à 200-380 px de la place visée qu'il n'a pas vue, ligne dégagée.
	var cibles := o.places_du_joueur(c)
	for k in zs:
		var cc := o.peut_poser(c, k, CLASSE, cibles)
		_check("gardien %d : une case de sa zone d'où la poussière se pose à 200-380 px d'un son, ligne dégagée — la règle du Terrassier peut se déclencher (%s)" % [k + 1, str(cc)], cc.x >= 0)


# ---------------------------------------------------------------------------
# 4.8 — Le dédale
# ---------------------------------------------------------------------------

func _salle_8() -> void:
	print("\n--- 4.8 Le dédale : des zones emboîtées ---")
	var c := o.ctx(7)
	var nav: Nav = c["nav"]
	var zs := o.zones(c)
	_check("quatre gardiens équipés, quatre zones", zs.size() == 4)
	var emboitees := 0
	for i in 4:
		for j in 4:
			if i != j and o.rect(c, zs[i]).encloses(o.rect(c, zs[j])) and o.rect(c, zs[i]) != o.rect(c, zs[j]):
				emboitees += 1
	_check("deux paires de zones EMBOÎTÉES : %d zones contenues dans une autre (exactement 2)" % emboitees, emboitees == 2)
	_check("… une de chaque côté de la cloison : la zone de l'ouest ne touche pas celle de l'est", not o.rect(c, zs[0]).intersects(o.rect(c, zs[2])))
	var contenus := true
	for i in [1, 3]:
		contenus = contenus and nav.cases_dans(o.rect(c, zs[i])).size() >= 100
	_check("les zones contenues restent des zones où errer : plus de 100 cases", contenus)
	var bas := Codec.get_low_wall_cells(c["carte"]).size()
	_check("un labyrinthe de murets : %d cases de mur bas (au moins 100) et une cloison pleine de 2 cases au milieu" % bas, bas >= 100 and o.murs_interieurs(c) >= 40)
	# Les gardiens contournent les murets : leur chemin jusqu'au joueur est bien plus long que la droite — et la droite, elle, traverse des murets que le joueur enjambe.
	var detours := 0
	var droites := 0
	for k in zs:
		var chemin := nav.chemin(c["pnj"][k]["case"], c["depart"])
		var droite: float = c["pnj"][k]["pos"].distance_to(c["depart_pos"])
		var longueur := o.longueur(chemin)
		if not chemin.is_empty() and longueur >= 1.4 * droite:
			detours += 1
		if (o.murs_bas_traverses(c, c["pnj"][k]["pos"], c["depart_pos"]) as Array).size() >= 1:
			droites += 1
	_check("pour au moins 3 gardiens sur 4, le chemin du gardien au joueur fait au moins 1,4 fois la droite (%d)" % detours, detours >= 3)
	_check("… et la droite traverse au moins un muret pour au moins 3 gardiens sur 4 (%d) : le joueur, lui, enjambe" % droites, droites >= 3)
	_check("le joueur part à la porte de la cloison, hors de toute zone", not o.dans_une_zone(c, c["depart"]) and not o.sous_une_lampe(c, c["depart_pos"]))


# ---------------------------------------------------------------------------
# 4.9 — La salle pleine
# ---------------------------------------------------------------------------

func _salle_9() -> void:
	print("\n--- 4.9 La salle pleine : tout le quartier à l'écoute ---")
	var c := o.ctx(8)
	var nav: Nav = c["nav"]
	var zs := o.zones(c)
	var ronde := o.indices(c, Profil.Deplacement.RONDE)[0]
	_check("quatre gardiens équipés, un par pièce d'angle, et une ronde équipée", zs.size() == 4)
	var disjointes := true
	var vastes := true
	var une_porte := true
	for i in 4:
		vastes = vastes and nav.cases_dans(o.rect(c, zs[i])).size() >= 150
		une_porte = une_porte and o.composantes(o.portes(c, zs[i])).size() == 1
		for j in range(i + 1, 4):
			disjointes = disjointes and not o.rect(c, zs[i]).intersects(o.rect(c, zs[j]))
	_check("quatre zones disjointes, de plus de 150 cases chacune, chacune ouverte par UNE porte", disjointes and vastes and une_porte)
	var tour := o.tour_de_la_ronde(c, ronde)
	var dans := 0
	for cc in tour:
		if o.dans_une_zone(c, cc):
			dans += 1
	_check("la ronde longe la place d'un bout à l'autre sans entrer dans une zone : %d cases (au moins 60), %d dans une zone" % [tour.size(), dans], tour.size() >= 60 and dans == 0)
	# Un tir du départ appelle les cinq : toutes les cases de toutes les zones, et tout le tour de la ronde, l'entendent net.
	var tout := _cases_des_zones(c)
	tout.append_array(cases_unique(tour))
	var pire := o.pire_rayon(c, "shoot", c["depart_pos"], tout, false)
	_check("un TIR tiré du départ est entendu de CHAQUE case des quatre zones et du tour, murs compris, à %.0f px près au plus (moins de 2 fois la zone d'audace) : se battre ici appelle tout le monde" % pire,
		pire <= 2.0 * Profil.AUDACE_ZONE_PX)
	var cibles := o.places_du_joueur(c)
	var tous := true
	for k in zs + [ronde]:
		tous = tous and o.peut_poser(c, k, CLASSE, cibles).x >= 0
	_check("pour chacun des cinq équipés, une case d'où la poussière se pose à 200-380 px d'un son, ligne dégagée", tous)
	var claires_en_zone := 0
	for l: Dictionary in c["lampes"]:
		claires_en_zone += 1 if o.dans_une_zone(c, l["case"]) else 0
	_check("trois plafonniers : deux dans une pièce, un sur la place, que la ronde longe (%d dans une pièce)" % claires_en_zone, (c["lampes"] as Array).size() == 3 and claires_en_zone == 2 and not _noir_tour(c, tour))
	_check("le joueur part au sud de la place, hors de toute zone", not o.dans_une_zone(c, c["depart"]))


func cases_unique(a: Array[Vector2i]) -> Array[Vector2i]:
	return o.cases_du_tour(a)


## Une lampe éclaire-t-elle au moins une case du tour ?
func _noir_tour(c: Dictionary, tour: Array[Vector2i]) -> bool:
	return o.cases_eclairees(c, tour).is_empty()
