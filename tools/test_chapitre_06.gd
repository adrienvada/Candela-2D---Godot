## La garde du CHAPITRE 6 — chantier SOLO, étape S8 (lot 2) : chaque salle enseigne ce qu'elle dit.
##
## Le chapitre 6, « Les chasseurs », est écrit dans `res://assets/solo/chapitre_06/` (par `tools/fabrique_chapitre_06.gd`). Les PNJ ne gardent plus rien : ils errent sur toute la carte
## (`libre_…`), vous cherchent, et se souviennent de l'endroit où ils vous ont vu (`delai_oubli`). On apprend à rompre une poursuite, à les attendre à un seuil éclairé, à ne pas faire
## de bruit, à ne pas s'engager dans un couloir qu'une poudre remplit. Cette suite mesure sur les données ce que chaque salle impose, avec les fonctions du jeu
## (`tools/outils_chapitre.gd`, `tools/outils_chapitre_04_06.gd`) : le modèle de vue du bot, l'ouïe réelle d'un PNJ derrière les murs, les chemins de `NavigationBot`.
##
## Partout (`OutilsChapitre.partout`) : taille, PNJ de chaque sorte, plafonniers, PNJ équipés (la classe du boss et sa poudre de contact, à partir de 6.7 — et un chasseur équipé
## ENTEND, sans quoi la règle de la poudre, qui se pose en enquête sur un son, ne se déclencherait jamais), chaque PNJ atteignable à pied, une seule pièce, aucun couloir d'une tuile, chaque
## zone assez grande, le départ à l'abri. Puis salle par salle : 6.1 une boucle sans cul-de-sac ; 6.2 deux boucles, l'une claire, l'autre noire, où l'on se cache ; 6.3 des îlots, deux chasseurs
## de deux côtés ; 6.4 trois seuils éclairés, une salle noire ; 6.5 un sol nu où un pas debout s'entend de presque partout ; 6.6 des couloirs que la poudre remplit ; 6.7 des gardiens
## vers qui fuir ; 6.8 un chasseur vif ; 6.9 une meute ; 6.10 un duel en miroir.
##
## Sabotée salle par salle — la liste est dans la ROADMAP, S8 (lot 2). Pour saboter sans toucher aux fichiers livrés : `-- --dossier=<chemin absolu d'une copie du chapitre>`.
##
## Lancer : godot --headless --path . --script res://tools/test_chapitre_06.gd
extends SceneTree

const Outils := preload("res://tools/outils_chapitre_04_06.gd")
const Nav := preload("res://navigation_bot.gd")
const Profil := preload("res://profil_bot.gd")
const Codec := preload("res://map_codec.gd")
const Poudre := preload("res://gadget_poudre.gd")

const DOSSIER_LIVRE := "res://assets/solo/chapitre_06"
const NUMERO := 6
const CLASSE := "sentinelle"

const TABLE := [
	{"pnj": {"libre_voit_facile": 1}, "lampes": 1, "equipes": 0, "cotes": [16, 30]},
	{"pnj": {"libre_voit_facile": 1}, "lampes": 1, "equipes": 0, "cotes": [16, 44]},
	{"pnj": {"libre_voit_facile": 2}, "lampes": 2, "equipes": 0, "cotes": [20, 44]},
	{"pnj": {"libre_voit_facile": 2}, "lampes": 2, "equipes": 0, "cotes": [20, 40]},
	{"pnj": {"libre_voit_entend_facile": 1}, "lampes": 1, "equipes": 0, "cotes": [14, 24]},
	{"pnj": {"libre_voit_entend_facile": 2}, "lampes": 2, "equipes": 0, "cotes": [24, 40]},
	{"pnj": {"zone_voit_entend_facile": 2, "libre_voit_entend_facile": 2}, "lampes": 3, "equipes": 4, "cotes": [28, 44]},
	{"pnj": {"libre_voit_entend_normal": 1, "libre_voit_facile": 1}, "lampes": 2, "equipes": 1, "cotes": [24, 44]},
	{"pnj": {"libre_voit_entend_facile": 3, "libre_voit_entend_normal": 1}, "lampes": 4, "equipes": 4, "cotes": [30, 48]},
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
	print("=== LE CHAPITRE 6 — LES CHASSEURS (S8, lot 2) ===")
	var dossier := DOSSIER_LIVRE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="):
			dossier = a.substr(10)
	o = Outils.new(Callable(self, "_check"))
	o.mesures_du_jeu(root)
	if not o.charger(dossier, NUMERO, "Les chasseurs", CLASSE, 10):
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

## Les chasseurs de la salle : les PNJ au déplacement libre.
func _chasseurs(c: Dictionary) -> Array[int]:
	return o.indices(c, Profil.Deplacement.LIBRE)


## Un chasseur de la salle n'a ni ronde ni zone, voit, et entend ou non.
func _est_un_chasseur(c: Dictionary, k: int) -> bool:
	var p: Dictionary = c["pnj"][k]
	return p["profil"].deplacement == Profil.Deplacement.LIBRE and (p["ronde"] as Array).is_empty() and (p["zone"] as Rect2i).size == Vector2i.ZERO and p["profil"].voit


## Les cases praticables à gauche (x < `x`) ou à droite de la ligne `x`.
func _cases_a_gauche(c: Dictionary, x: int) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in (c["nav"] as Nav).cases_praticables():
		if cc.x < x:
			sortie.append(cc)
	return sortie


func _cases_a_droite(c: Dictionary, x: int) -> Array[Vector2i]:
	var sortie: Array[Vector2i] = []
	for cc in (c["nav"] as Nav).cases_praticables():
		if cc.x > x:
			sortie.append(cc)
	return sortie


## Aucun chasseur ne voit le joueur à son départ, de là où il naît (ligne de vue libre) : le départ est un abri, et même un point d'où l'on ne le voit pas.
func _personne_ne_voit_le_depart(c: Dictionary) -> bool:
	for k in _chasseurs(c):
		if o.ligne_de_vue(c, c["pnj"][k]["pos"], c["depart_pos"]):
			return false
	return true


## Un pas debout du départ n'est entendu NET d'aucun chasseur là où il naît : le joueur n'est pas appelé dès la première seconde.
func _aucun_pas_net(c: Dictionary) -> bool:
	for k in _chasseurs(c):
		if o.net(c, "footstep", c["depart_pos"], c["pnj"][k]["pos"], false):
			return false
	return true


func _plus_pres_du_depart(c: Dictionary) -> float:
	var d := INF
	for k in _chasseurs(c):
		d = minf(d, float(c["pnj"][k]["pos"].distance_to(c["depart_pos"])))
	return d


func _ecart_des_chasseurs(c: Dictionary) -> float:
	var ks := _chasseurs(c)
	var d := INF
	for i in ks.size():
		for j in range(i + 1, ks.size()):
			d = minf(d, float(c["pnj"][ks[i]]["pos"].distance_to(c["pnj"][ks[j]]["pos"])))
	return d


func _equipes_ok(c: Dictionary, ks: Array) -> bool:
	var cibles := o.toutes_les_places(c)
	for k in ks:
		if o.peut_poser(c, k, CLASSE, cibles).x < 0:
			return false
	return true


# ---------------------------------------------------------------------------
# 6.1 — Le chasseur
# ---------------------------------------------------------------------------

func _salle_1() -> void:
	print("\n--- 6.1 Le chasseur : un PNJ qui vous cherche ---")
	var c := o.ctx(0)
	var k := _chasseurs(c)[0]
	var p: Dictionary = c["pnj"][k]
	_check("un chasseur : libre, sans ronde ni zone, qui VOIT (aux réflexes FACILES) et n'entend pas", _est_un_chasseur(c, k) and not p["profil"].entend and p["profil_nom"] == "libre_voit_facile")
	var blocs := o.blocs_interieurs(c)
	_check("une boucle : un seul bloc de mur plein, que le couloir contourne (%d bloc(s), %d cases)" % [blocs.size(), (blocs[0] as Array).size() if not blocs.is_empty() else 0], blocs.size() == 1 and (blocs[0] as Array).size() >= 60)
	var culs := o.culs_de_sac(c)
	_check("la boucle n'a pas de fond : aucun cul-de-sac (%d case(s) à un seul voisin)" % culs.size(), culs.is_empty())
	_check("il se souvient de ce qu'il a vu : un délai d'oubli de %.1f s (de 3 à 12), pas moins" % p["profil"].delai_oubli, p["profil"].delai_oubli >= 3.0 and p["profil"].delai_oubli <= 12.0)
	var claires := o.cases_claires(c)
	_check("une lampe sur la boucle éclaire %d cases (au moins 8) ; le joueur part loin d'elle, dans le noir" % claires.size(), claires.size() >= 8 and not o.sous_une_lampe(c, c["depart_pos"]))
	_check("le chasseur naît loin du départ (%.0f px, plus de 15 cases), et ne le voit pas : le bloc est entre eux" % c["depart_pos"].distance_to(p["pos"]),
		c["depart_pos"].distance_to(p["pos"]) > 15.0 * 35.0 and not o.ligne_de_vue(c, p["pos"], c["depart_pos"]))
	var chemin := (c["nav"] as Nav).chemin(p["case"], c["depart"])
	var droite: float = p["pos"].distance_to(c["depart_pos"])
	_check("le bloc est entre eux : de lui à vous, le chemin fait %.0f px pour %.0f px à vol d'oiseau (au moins 1,2 fois)" % [o.longueur(chemin), droite], not chemin.is_empty() and o.longueur(chemin) >= 1.2 * droite)
	_check("on peut le fuir longtemps : %d cases de couloir (au moins 150), tout autour du bloc" % (c["nav"] as Nav).cases_praticables().size(), (c["nav"] as Nav).cases_praticables().size() >= 150)


# ---------------------------------------------------------------------------
# 6.2 — Rompre
# ---------------------------------------------------------------------------

func _salle_2() -> void:
	print("\n--- 6.2 Rompre : disparaître de sa mémoire ---")
	var c := o.ctx(1)
	var nav: Nav = c["nav"]
	var k := _chasseurs(c)[0]
	var p: Dictionary = c["pnj"][k]
	_check("un chasseur qui voit (il n'entend pas), un seul plafonnier", _est_un_chasseur(c, k) and not p["profil"].entend and (c["lampes"] as Array).size() == 1)
	var blocs := o.blocs_interieurs(c)
	_check("DEUX boucles : deux blocs de mur plein, que les couloirs contournent (%d blocs)" % blocs.size(), blocs.size() == 2)
	var ouest := _cases_a_gauche(c, 19)
	var est := _cases_a_droite(c, 20)
	var porte: Array[Vector2i] = []
	for cc in nav.cases_praticables():
		if cc.x == 19 or cc.x == 20:
			porte.append(cc)
	_check("les deux boucles se rejoignent par UNE porte : %d cases dans la cloison, en un seul morceau (une porte de 4 cases)" % porte.size(), porte.size() == 8 and o.composantes(porte).size() == 1)
	var claires_ouest := o.cases_eclairees(c, ouest)
	var claires_est := o.cases_eclairees(c, est)
	_check("la boucle de l'ouest est éclairée (%d cases claires), celle de l'est est NOIRE (%d)" % [claires_ouest.size(), claires_est.size()], claires_ouest.size() >= 8 and claires_est.is_empty())
	_check("le chasseur et le joueur naissent à l'ouest", p["pos"].x < 19.0 * 35.0 and c["depart_pos"].x < 19.0 * 35.0 and not o.sous_une_lampe(c, c["depart_pos"]))
	# Une cachette : une case de la boucle noire qu'aucune case de la boucle claire ne voit — le chasseur n'y voit rien, et n'y est pas vu.
	var cachees := 0
	var cachette := Vector2i(-1, -1)
	for cc in est:
		var pos := Nav.centre_de_la_case(cc)
		var vue := false
		for i in range(0, ouest.size(), 2):
			if o.ligne_de_vue(c, Nav.centre_de_la_case(ouest[i]), pos):
				vue = true
				break
		if not vue:
			cachees += 1
			if cachette.x < 0 and nav.chemin(c["depart"], cc).size() >= 25:
				cachette = cc
	_check("%d cases de la boucle noire (sur %d) ne sont vues d'aucune case de la boucle claire (au moins 40 %%)" % [cachees, est.size()], cachees * 10 >= est.size() * 4)
	var chemin := nav.chemin(c["depart"], cachette) if cachette.x >= 0 else []
	var temps := float(chemin.size()) * 35.0 / Outils.VITESSE_JOUEUR
	_check("une cachette atteignable : en %s, à %d cases du départ (%.1f s de course), noire, d'où l'on attend que le délai d'oubli (%.1f s) passe" % [str(cachette), chemin.size(), temps, p["profil"].delai_oubli],
		cachette.x >= 0 and not o.eclaire_par_lampe(c, Nav.centre_de_la_case(cachette)))
	_check("un chasseur qui voit ne voit pas dans le noir : la torche éteinte, le joueur n'est vu d'aucune case de la boucle noire", _jamais_vu_dans_le_noir(c, est))


## Un joueur debout, torche éteinte, sur une case de `cases` (aucune lampe ne l'éclaire), est-il invisible depuis TOUT le sol praticable ?
func _jamais_vu_dans_le_noir(c: Dictionary, cases: Array[Vector2i]) -> bool:
	var tout := (c["nav"] as Nav).cases_praticables()
	for i in range(0, cases.size(), 5):
		var cible := Nav.centre_de_la_case(cases[i])
		for j in range(0, tout.size(), 7):
			var obs := Nav.centre_de_la_case(tout[j])
			if obs.distance_to(cible) <= 14.0 * 35.0 and o.ligne_de_vue(c, obs, cible) and o.voit(c, obs, cible, o.lumieres(c)):
				return false
	return true


# ---------------------------------------------------------------------------
# 6.3 — La meute
# ---------------------------------------------------------------------------

func _salle_3() -> void:
	print("\n--- 6.3 La meute : deux chasseurs ---")
	var c := o.ctx(2)
	var ks := _chasseurs(c)
	_check("deux chasseurs qui voient, aux réflexes FACILES", ks.size() == 2 and _est_un_chasseur(c, ks[0]) and _est_un_chasseur(c, ks[1]))
	var blocs := o.blocs_interieurs(c)
	var gros := 0
	for b in blocs:
		if (b as Array).size() >= 6:
			gros += 1
	_check("une carte à ÎLOTS : %d blocs de mur plein, de 6 cases au moins chacun (au moins 8)" % gros, gros >= 8 and blocs.size() == gros)
	_check("aucun cul-de-sac : on y tourne sans fin", o.culs_de_sac(c).is_empty())
	_check("les deux chasseurs naissent à plus de 20 cases l'un de l'autre (%.0f px)" % _ecart_des_chasseurs(c), _ecart_des_chasseurs(c) > 20.0 * 35.0)
	_check("… et chacun à plus de 20 cases du joueur (%.0f px au plus près)" % _plus_pres_du_depart(c), _plus_pres_du_depart(c) > 20.0 * 35.0)
	var claires := o.cases_claires(c)
	_check("deux lampes : %d cases éclairées (au moins 12), le départ est dans le noir" % claires.size(), (c["lampes"] as Array).size() == 2 and claires.size() >= 12 and not o.sous_une_lampe(c, c["depart_pos"]))
	# Ils viennent de deux côtés : le joueur est à peu près entre eux deux, ni l'un ni l'autre n'est dans le même quart de carte.
	var a: Vector2 = c["pnj"][ks[0]]["pos"] - c["depart_pos"]
	var b: Vector2 = c["pnj"][ks[1]]["pos"] - c["depart_pos"]
	_check("ils viennent de deux directions différentes : %.0f° entre les deux, vus du départ (au moins 30°)" % rad_to_deg(absf(a.angle_to(b))), rad_to_deg(absf(a.angle_to(b))) >= 30.0)


# ---------------------------------------------------------------------------
# 6.4 — L'embuscade
# ---------------------------------------------------------------------------

func _salle_4() -> void:
	print("\n--- 6.4 L'embuscade : les attendre sous un plafonnier ---")
	var c := o.ctx(3)
	var nav: Nav = c["nav"]
	var ks := _chasseurs(c)
	_check("deux chasseurs qui voient seulement, hors de la salle, qui rôdent dans le couloir qui en fait le tour", ks.size() == 2 and _est_un_chasseur(c, ks[0]) and _est_un_chasseur(c, ks[1])
		and not _dans_la_salle(c["pnj"][ks[0]]["case"]) and not _dans_la_salle(c["pnj"][ks[1]]["case"]))
	# Les entrées : les cases de la cloison (x = 8 ou 25, y = 5 ou 16, dans ses limites) qui sont du sol — des morceaux séparés, un par porte.
	var seuils: Array[Vector2i] = []
	for cc in nav.cases_praticables():
		var sur_la_cloison: bool = ((cc.x == 8 or cc.x == 25) and cc.y >= 5 and cc.y <= 16) or ((cc.y == 5 or cc.y == 16) and cc.x >= 8 and cc.x <= 25)
		if sur_la_cloison:
			seuils.append(cc)
	var portes := o.composantes(seuils)
	_check("TROIS entrées : %d portes dans la cloison de la salle" % portes.size(), portes.size() == 3)
	_check("le joueur part DANS la salle, dans le noir, et aucun chasseur ne le voit de là où il naît", _dans_la_salle(c["depart"]) and not o.sous_une_lampe(c, c["depart_pos"]) and _personne_ne_voit_le_depart(c))
	var tous_eclaires := true
	var tous_vus := true
	var invisible := true
	for porte in portes:
		var eclaires := 0
		var vue := false
		var cache := false
		for cc in porte:
			var pos := Nav.centre_de_la_case(cc)
			if o.eclaire_par_lampe(c, pos):
				eclaires += 1
				if o.ligne_de_vue(c, c["depart_pos"], pos):
					vue = true
				# Un chasseur posté sur ce seuil éclairé ne voit pas le joueur, dans le noir, torche éteinte.
				if not o.voit(c, pos, c["depart_pos"], o.lumieres(c)):
					cache = true
		tous_eclaires = tous_eclaires and eclaires >= 2
		tous_vus = tous_vus and vue
		invisible = invisible and cache
	_check("chaque seuil est éclairé (au moins 2 cases de chaque porte sous une lampe)", tous_eclaires)
	_check("… et du départ, dans le noir, on voit chacun des trois seuils éclairés (ligne de vue libre)", tous_vus)
	_check("… alors qu'un chasseur posté sur un seuil ne voit pas le joueur, dans le noir, torche éteinte : on les voit entrer, ils ne vous voient pas", invisible)
	var claires_dedans := 0
	var dedans := 0
	for cc in nav.cases_praticables():
		if _dans_la_salle(cc):
			dedans += 1
			if o.eclaire_par_lampe(c, Nav.centre_de_la_case(cc)):
				claires_dedans += 1
	_check("deux lampes, aux seuils : %d cases éclairées dans la salle sur %d (moins de 30 %%), le reste est noir" % [claires_dedans, dedans], (c["lampes"] as Array).size() == 2 and claires_dedans * 10 < dedans * 3 and claires_dedans >= 6)
	_check("le chasseur n'entend pas : le joueur y tire sans se trahir au bruit (il ne voit que ce qui s'éclaire)", not c["pnj"][ks[0]]["profil"].entend and not c["pnj"][ks[1]]["profil"].entend)


func _dans_la_salle(cc: Vector2i) -> bool:
	return cc.x >= 9 and cc.x <= 24 and cc.y >= 6 and cc.y <= 15


# ---------------------------------------------------------------------------
# 6.5 — Le chasseur qui écoute
# ---------------------------------------------------------------------------

func _salle_5() -> void:
	print("\n--- 6.5 Le chasseur qui écoute : il suit vos pas ---")
	var c := o.ctx(4)
	var nav: Nav = c["nav"]
	var k := _chasseurs(c)[0]
	var p: Dictionary = c["pnj"][k]
	_check("un chasseur qui VOIT et ENTEND, aux réflexes FACILES", _est_un_chasseur(c, k) and p["profil"].entend and p["profil_nom"] == "libre_voit_entend_facile")
	_check("un sol nu : aucun mur à l'intérieur, aucun muret (%d, %d)" % [o.murs_interieurs(c), Codec.get_low_wall_cells(c["carte"]).size()], o.murs_interieurs(c) == 0 and Codec.get_low_wall_cells(c["carte"]).is_empty())
	var cases := nav.cases_praticables()
	var echantillon: Array[Vector2i] = []
	for i in range(0, cases.size(), 3):
		echantillon.append(cases[i])
	var paires := 0
	var debout := 0
	var accroupi := 0
	var audible := 0
	for a in echantillon:
		for b in echantillon:
			if a == b:
				continue
			paires += 1
			var pa := Nav.centre_de_la_case(a)
			var pb := Nav.centre_de_la_case(b)
			if o.net(c, "footstep", pa, pb, false):
				debout += 1
			if o.net(c, "footstep", pa, pb, true):
				accroupi += 1
			if o.entendu(c, "footstep", pa, pb, false):
				audible += 1
	_check("un pas debout est entendu de TOUTE paire de places (%d sur %d) ; NET de %d %% d'entre elles (au moins 80 %%)" % [audible, paires, 100 * debout / paires], audible == paires and debout * 10 >= paires * 8)
	_check("accroupi, un pas n'est entendu net que de %d %% des paires (moins de 15 %%) : on se fait oublier" % [100 * accroupi / paires], accroupi * 100 < 15 * paires)
	var claires := o.cases_claires(c)
	_check("une lampe : %d cases éclairées sur %d (moins du quart) ; le joueur part dans le noir, à %.0f px du chasseur" % [claires.size(), cases.size(), c["depart_pos"].distance_to(p["pos"])], (c["lampes"] as Array).size() == 1 and claires.size() * 4 < cases.size() and claires.size() >= 8)


# ---------------------------------------------------------------------------
# 6.6 — La poudre
# ---------------------------------------------------------------------------

func _salle_6() -> void:
	print("\n--- 6.6 La poudre : un passage piégé ---")
	var c := o.ctx(5)
	var nav: Nav = c["nav"]
	var ks := _chasseurs(c)
	_check("deux chasseurs qui voient et entendent, aux réflexes FACILES (ils ne sont pas encore équipés)", ks.size() == 2 and _est_un_chasseur(c, ks[0]) and _est_un_chasseur(c, ks[1]) and c["pnj"][ks[0]]["profil"].entend and c["pnj"][ks[1]]["profil"].entend)
	# Des couloirs de 4 cases, qui se croisent : les cases dont les deux axes sont longs sont les carrefours, les autres sont des couloirs de quatre.
	var carrefours := 0
	var couloirs_de_quatre := 0
	var autres := 0
	for cc in nav.cases_praticables():
		var h := o.longueur_de_la_course(c, cc, Vector2i.RIGHT)
		var v := o.longueur_de_la_course(c, cc, Vector2i.DOWN)
		if h >= 10 and v >= 10:
			carrefours += 1
		elif minf(h, v) == 4.0:
			couloirs_de_quatre += 1
		else:
			autres += 1
	_check("QUATRE carrefours de 16 cases (%d cases dont les deux axes font au moins 10), et tout le reste est un couloir de 4 cases de large (%d ; %d autres)" % [carrefours, couloirs_de_quatre, autres], carrefours == 64 and autres == 0)
	var rayon := Poudre.RAYON
	_check("la poudre (%.0f px de large) remplit un couloir de 4 cases (%.0f px) d'un mur à l'autre : %.0f px de large contre %.0f" % [2.0 * rayon, 4.0 * 35.0, 2.0 * rayon, 4.0 * 35.0], 4.0 * 35.0 <= 2.0 * rayon)
	var ouvertes := o.cases_ouvertes(c, rayon)
	_check("… et nulle part ne tient un disque de poudre (%.0f px de rayon) sans toucher un mur : %d case(s) ouverte(s)" % [rayon, ouvertes.size()], ouvertes.is_empty())
	var blocs := o.blocs_interieurs(c)
	_check("un bloc plein au milieu, que les quatre couloirs contournent : une boucle de couloirs (%d bloc intérieur)" % blocs.size(), blocs.size() == 1)
	var claires := o.cases_claires(c)
	var dans_carrefour := 0
	for cc in claires:
		if o.longueur_de_la_course(c, cc, Vector2i.RIGHT) >= 10 and o.longueur_de_la_course(c, cc, Vector2i.DOWN) >= 10:
			dans_carrefour += 1
	_check("deux lampes à deux carrefours : %d cases claires, dont %d dans un carrefour (au moins 8)" % [claires.size(), dans_carrefour], (c["lampes"] as Array).size() == 2 and dans_carrefour >= 8)
	_check("le joueur part au bout d'un couloir, dans le noir ; les chasseurs naissent à plus de 15 cases (%.0f px) et ne le voient pas" % _plus_pres_du_depart(c), not o.sous_une_lampe(c, c["depart_pos"]) and _plus_pres_du_depart(c) > 15.0 * 35.0 and _personne_ne_voit_le_depart(c))


# ---------------------------------------------------------------------------
# 6.7 — Gardes et chasseurs
# ---------------------------------------------------------------------------

func _salle_7() -> void:
	print("\n--- 6.7 Gardes et chasseurs : fuir vers un poste fixe ---")
	var c := o.ctx(6)
	var nav: Nav = c["nav"]
	var zs := o.zones(c)
	var ks := _chasseurs(c)
	_check("deux gardiens de zone et deux chasseurs, tous équipés de la Sentinelle, tous VOIENT et ENTENDENT", zs.size() == 2 and ks.size() == 2 and c["pnj"][ks[0]]["profil"].entend and c["pnj"][ks[1]]["profil"].entend)
	_check("deux zones disjointes : deux salles, une par gardien, chacune s'ouvre sur un couloir par une seule porte", not o.rect(c, zs[0]).intersects(o.rect(c, zs[1])) and o.composantes(o.portes(c, zs[0])).size() == 1 and o.composantes(o.portes(c, zs[1])).size() == 1)
	_check("les chasseurs naissent HORS des salles, sur l'anneau, à plus de 25 cases l'un de l'autre (%.0f px)" % _ecart_des_chasseurs(c), not o.dans_une_zone(c, c["pnj"][ks[0]]["case"]) and not o.dans_une_zone(c, c["pnj"][ks[1]]["case"]) and _ecart_des_chasseurs(c) > 25.0 * 35.0)
	var blocs := o.blocs_interieurs(c)
	_check("un anneau de couloirs autour de quatre masses pleines, une cour au milieu (%d blocs intérieurs)" % blocs.size(), blocs.size() == 4)
	var cour := 0
	for cc in o.hors_zones(c):
		if cc.x >= 14 and cc.x <= 25 and cc.y >= 10 and cc.y <= 19:
			cour += 1
	_check("une cour de %d cases (120), où le joueur part, dans le noir, hors de toute zone" % cour, cour == 120 and not o.dans_une_zone(c, c["depart"]) and not o.sous_une_lampe(c, c["depart_pos"]) and c["depart"].x >= 14 and c["depart"].x <= 25 and c["depart"].y >= 10 and c["depart"].y <= 19)
	# Fuir vers un poste : de la cour, la porte de chaque salle est à moins de 25 cases de chemin.
	for k in zs:
		var plus_court := 9999
		for porte in o.portes(c, k):
			plus_court = mini(plus_court, nav.chemin(c["depart"], porte).size())
		_check("la porte de la salle %d est à %d cases de chemin du départ (au plus 25) : on y fuit" % [k + 1, plus_court], plus_court <= 25)
	var lampes_dans_zones := 0
	for l: Dictionary in c["lampes"]:
		lampes_dans_zones += 1 if o.dans_une_zone(c, l["case"]) else 0
	_check("trois lampes : une dans chaque salle, une dans le corridor du nord (%d dans une salle)" % lampes_dans_zones, (c["lampes"] as Array).size() == 3 and lampes_dans_zones == 2)
	_check("pour chacun des quatre équipés, une case d'où la poudre se pose à 200-450 px d'un son, ligne dégagée", _equipes_ok(c, zs + ks))


# ---------------------------------------------------------------------------
# 6.8 — La traque
# ---------------------------------------------------------------------------

func _salle_8() -> void:
	print("\n--- 6.8 La traque : un chasseur vif ---")
	var c := o.ctx(7)
	var nav: Nav = c["nav"]
	var normal := -1
	var lent := -1
	for k in _chasseurs(c):
		if c["pnj"][k]["profil_nom"] == "libre_voit_entend_normal":
			normal = k
		if c["pnj"][k]["profil_nom"] == "libre_voit_facile":
			lent = k
	_check("deux chasseurs : l'un voit et entend, aux réflexes NORMAUX, et porte la poudre ; l'autre voit seulement, plus lent, sans outil", normal >= 0 and lent >= 0 and c["pnj"][normal]["equipe"] and not c["pnj"][lent]["equipe"] and not c["pnj"][lent]["profil"].entend)
	var vif: float = c["pnj"][normal]["profil"].delai_reaction
	var lourd: float = c["pnj"][lent]["profil"].delai_reaction
	_check("il réagit plus vite que l'autre : %.2f s contre %.2f s, et il vise plus juste (%.1f° contre %.1f°)" % [vif, lourd, c["pnj"][normal]["profil"].erreur_visee_deg, c["pnj"][lent]["profil"].erreur_visee_deg],
		vif < lourd and c["pnj"][normal]["profil"].erreur_visee_deg < c["pnj"][lent]["profil"].erreur_visee_deg)
	var sol := nav.cases_praticables().size()
	_check("une carte ouverte : %d cases de mur plein à l'intérieur pour %d cases de sol (moins de 5 %%)" % [o.murs_interieurs(c), sol], o.murs_interieurs(c) * 100 < 5 * sol)
	var ouvertes := o.cases_ouvertes(c, 168.0)
	_check("un sol où l'on est vite vu : %d cases ont un disque de 168 px libre (au moins 10 %% du sol)" % ouvertes.size(), ouvertes.size() * 100 >= 10 * sol)
	_check("ils naissent à plus de 25 cases du joueur (%.0f px), hors de portée nette d'un pas debout du départ" % _plus_pres_du_depart(c), _plus_pres_du_depart(c) > 25.0 * 35.0 and _aucun_pas_net(c))
	var claires := o.cases_claires(c)
	_check("deux lampes seulement : %d cases claires (moins de 10 %% du sol) ; il faut courir dans le noir" % claires.size(), (c["lampes"] as Array).size() == 2 and claires.size() * 10 < sol and claires.size() >= 10)
	_check("le chasseur vif porte la Sentinelle : la poudre peut se poser", _equipes_ok(c, [normal]))


# ---------------------------------------------------------------------------
# 6.9 — La salle pleine
# ---------------------------------------------------------------------------

func _salle_9() -> void:
	print("\n--- 6.9 La salle pleine : toute une meute ---")
	var c := o.ctx(8)
	var ks := _chasseurs(c)
	var vifs := 0
	var tous_equipes := true
	for k in ks:
		if c["pnj"][k]["profil_nom"] == "libre_voit_entend_normal":
			vifs += 1
		tous_equipes = tous_equipes and c["pnj"][k]["equipe"] and c["pnj"][k]["profil"].entend
	_check("quatre chasseurs, tous équipés, qui voient et entendent : trois FACILES, un NORMAL (%d vif)" % vifs, ks.size() == 4 and vifs == 1 and tous_equipes)
	var blocs := o.blocs_interieurs(c)
	_check("une grande carte à îlots : %d blocs de mur plein (au moins 12)" % blocs.size(), blocs.size() >= 12 and o.culs_de_sac(c).is_empty())
	_check("les quatre naissent à plus de 18 cases du joueur (%.0f px au plus près), hors de portée nette d'un pas debout du départ" % _plus_pres_du_depart(c), _plus_pres_du_depart(c) > 18.0 * 35.0 and _aucun_pas_net(c))
	_check("… et à plus de 15 cases les uns des autres (%.0f px)" % _ecart_des_chasseurs(c), _ecart_des_chasseurs(c) > 15.0 * 35.0)
	_check("quatre plafonniers, le départ est dans le noir", (c["lampes"] as Array).size() == 4 and not o.sous_une_lampe(c, c["depart_pos"]))
	_check("pour chacun des quatre, une case d'où la poudre se pose à 200-450 px d'un son, ligne dégagée", _equipes_ok(c, ks))
