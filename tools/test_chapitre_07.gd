## La garde du CHAPITRE 7 — chantier SOLO, étape S8 (lot 2) : chaque salle enseigne ce qu'elle dit.
##
## Le chapitre 7, « Les chasseurs vifs », est écrit dans `res://assets/solo/chapitre_07/` (par `tools/fabrique_chapitre_07.gd`). Les PNJ sont LIBRES — ils voient, ils entendent,
## ils réagissent comme le boss des premiers chapitres (`libre_voit_entend_normal`) et ils viennent chercher le joueur ; chaque salle est une suite de petits duels. Cette suite
## mesure sur les données ce que chaque salle impose, avec les fonctions du jeu (`tools/outils_chapitre.gd`, et `tools/outils_chasseurs.gd` pour ce que les PNJ libres et la
## lumière demandent en plus : les flaques, les ombres, le noir, les îlots).
##
## Partout : taille, PNJ de chaque sorte, plafonniers, PNJ équipés (la classe du boss, l'ombre habitée, à partir de 7.7 — un chasseur équipé VOIT, sans quoi la règle de l'ombre
## habitée, qui se pose face à une torche qu'on voit, ne se déclencherait jamais), chaque PNJ atteignable à pied, une seule pièce, aucun couloir d'une tuile, et — pour un PNJ
## libre, qui peut se tenir partout — le départ hors de toute lampe et à bonne distance. Puis salle par salle : 7.1 une petite arène, deux lampes à part ; 7.2 deux chambres, une
## porte, le joueur entre les deux ; 7.3 aucune lampe : la torche et le bruit trahissent ; 7.4 cinq flaques en quinconce, du noir entre elles ; 7.5 un poste éclairé au fond d'une
## niche couvre le hall ; 7.6 les ombres que jettent les colonnes dans une flaque ; 7.7 des îlots, trois chasseurs équipés ; 7.8 un labyrinthe de murets, on voit par-dessus et on ne
## passe pas ; 7.9 la meute, quatre chasseurs des quatre côtés ; 7.10 un duel en miroir.
##
## Sabotée salle par salle — la liste est dans la ROADMAP, S8 lot 2. Pour saboter sans toucher aux fichiers livrés : `-- --dossier=<chemin absolu d'une copie du chapitre>`.
##
## Lancer : godot --headless --path . --script res://tools/test_chapitre_07.gd
extends SceneTree

const Outils := preload("res://tools/outils_chapitre.gd")
const Chass := preload("res://tools/outils_chasseurs.gd")
const Nav := preload("res://navigation_bot.gd")
const Profil := preload("res://profil_bot.gd")
const Codec := preload("res://map_codec.gd")
const Percep := preload("res://perception_bot.gd")
const Equip := preload("res://equipement_bot.gd")

const DOSSIER_LIVRE := "res://assets/solo/chapitre_07"
const NUMERO := 7
const CLASSE := "occulteur"
const GADGET := "ombre_habitee"
const CH := "libre_voit_entend_normal"

const TABLE := [
	{"pnj": {CH: 1}, "lampes": 2, "equipes": 0, "cotes": [18, 24]},
	{"pnj": {CH: 2}, "lampes": 2, "equipes": 0, "cotes": [18, 40]},
	{"pnj": {CH: 2}, "lampes": 0, "equipes": 0, "cotes": [24, 34]},
	{"pnj": {CH: 2}, "lampes": 5, "equipes": 0, "cotes": [28, 34]},
	{"pnj": {CH: 2, "immobile_voit_entend_normal": 1}, "lampes": 3, "equipes": 0, "cotes": [22, 40]},
	{"pnj": {CH: 2}, "lampes": 2, "equipes": 0, "cotes": [20, 40]},
	{"pnj": {CH: 3}, "lampes": 3, "equipes": 3, "cotes": [30, 44]},
	{"pnj": {CH: 3}, "lampes": 2, "equipes": 3, "cotes": [28, 40]},
	{"pnj": {CH: 4}, "lampes": 4, "equipes": 4, "cotes": [36, 54]},
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
	print("=== LE CHAPITRE 7 — LES CHASSEURS VIFS (S8, lot 2) ===")
	var dossier := DOSSIER_LIVRE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="):
			dossier = a.substr(10)
	o = Outils.new(Callable(self, "_check"))
	o.mesures_du_jeu(root)
	if not o.charger(dossier, NUMERO, "Les chasseurs vifs", CLASSE, 10):
		print("\n=== %d vérifications, %d échec(s) ===" % [_verifications, _failures])
		print("CRIS ATTENDUS: 0")
		quit(1)
		return
	o.partout(NUMERO, CLASSE, TABLE)
	print("\n--- Partout : un PNJ libre part loin du joueur, hors de toute lampe ---")
	for i in 10:
		Chass.libres_partout(o, o.ctx(i), "7.%d" % (i + 1), 25 if i == 9 else 10)
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

func _libres(c: Dictionary) -> Array[int]:
	return Chass.pnj_de(c, Profil.Deplacement.LIBRE)


## Deux flaques « à part » : le rayon clair de l'une n'atteint pas celui de l'autre.
func _flaques_a_part(c: Dictionary) -> bool:
	var ls: Array = c["lampes"]
	for i in ls.size():
		for j in range(i + 1, ls.size()):
			if (ls[i]["pos"] as Vector2).distance_to(ls[j]["pos"]) <= Chass.rayon_clair(ls[i]) + Chass.rayon_clair(ls[j]):
				return false
	return true


## La règle de l'ombre habitée peut-elle se déclencher chez ce PNJ ? Une case où il peut se tenir, et une place à la distance de la règle (`EquipementBot.GADGETS`) en ligne
## dégagée — la place qu'il vise, celle où il a vu la torche de sa cible.
func _regle_possible(c: Dictionary, cases: Array[Vector2i]) -> bool:
	var fenetre: Array = Equip.GADGETS[GADGET]["distance"]
	var cibles := (c["nav"] as Nav).cases_praticables()
	for i in range(0, cases.size(), maxi(1, cases.size() / 40)):
		var a := Nav.centre_de_la_case(cases[i])
		for j in range(0, cibles.size(), maxi(1, cibles.size() / 60)):
			var b := Nav.centre_de_la_case(cibles[j])
			var d := a.distance_to(b)
			if d >= float(fenetre[0]) and d <= float(fenetre[1]) and Percep.segment_degage(a, b, c["monde"]):
				return true
	return false


## Le point `k` de la salle `c` tient-il au moins `n` cases de mur dans une des quatre directions, à moins de `d` cases ?
func _mur_a(c: Dictionary, cc: Vector2i, dir: Vector2i, d: int) -> bool:
	var murs := {}
	for m in Codec.get_wall_cells(c["carte"]):
		murs[m] = true
	for k in range(1, d + 1):
		if murs.has(cc + dir * k):
			return true
	return false


# ---------------------------------------------------------------------------
# 7.1 — Le duelliste
# ---------------------------------------------------------------------------

func _salle_1() -> void:
	print("\n--- 7.1 Le duelliste : un chasseur libre, une petite arène ---")
	var c := o.ctx(0)
	var k := _libres(c)[0]
	var p: Dictionary = c["pnj"][k]
	_check("un seul chasseur, libre : ni ronde ni zone, il ne tient pas sa place", (p["ronde"] as Array).is_empty() and (p["zone"] as Rect2i).size == Vector2i.ZERO and p["profil"].voit and p["profil"].entend and p["profil"].tire)
	var taille: Vector2i = c["taille"]
	_check("une petite arène : %d × %d cases, comme un duel (au plus 24 de côté)" % [taille.x, taille.y], taille.x <= 24 and taille.y <= 24)
	_check("des colonnes pour se couvrir : %d cases de mur plein à l'intérieur (de 12 à 30)" % o.murs_interieurs(c), o.murs_interieurs(c) >= 12 and o.murs_interieurs(c) <= 30)
	_check("deux lampes dont les flaques se tiennent à part", (c["lampes"] as Array).size() == 2 and _flaques_a_part(c))
	for l: Dictionary in c["lampes"]:
		var n := 0
		for cc in Chass.claires(o, c):
			if Nav.centre_de_la_case(cc).distance_to(l["pos"]) <= Chass.rayon_clair(l):
				n += 1
		_check("la lampe %s éclaire une vraie flaque : %d cases (au moins 12)" % [str(l["case"]), n], n >= 12)
	_check("ni le joueur ni le chasseur ne partent sous une lampe : le duel s'ouvre dans le noir", not o.eclaire_par_lampe(c, c["depart_pos"]) and not o.eclaire_par_lampe(c, p["pos"]))
	var d := Chass.distance_a_pied(o, c, c["depart"], p["case"])
	_check("le chasseur part à %.0f px à pied du joueur (plus de 14 cases) : ni nez à nez ni embuscade" % d, d >= 14.0 * 35.0)
	# De la couverture et de l'espace découvert, autour du départ.
	var abri := 0
	var vu := 0
	for cc in (c["nav"] as Nav).cases_praticables():
		var pos := Nav.centre_de_la_case(cc)
		if pos.distance_to(c["depart_pos"]) > 6.0 * 35.0:
			continue
		if o.ligne_de_vue(c, p["pos"], pos):
			vu += 1
		else:
			abri += 1
	_check("autour du départ (6 cases) : %d cases à couvert du chasseur et %d en vue de lui (au moins 10 de chaque)" % [abri, vu], abri >= 10 and vu >= 10)


# ---------------------------------------------------------------------------
# 7.2 — Deux duels
# ---------------------------------------------------------------------------

## Les colonnes de la salle où le mur de séparation passe (au moins 60 % de leurs cases intérieures sont du mur plein).
func _colonnes_de_cloison(c: Dictionary) -> Array[int]:
	var taille: Vector2i = c["taille"]
	var murs := {}
	for m in Codec.get_wall_cells(c["carte"]):
		murs[m] = true
	var sortie: Array[int] = []
	for x in range(1, taille.x - 1):
		var n := 0
		for y in range(1, taille.y - 1):
			if murs.has(Vector2i(x, y)):
				n += 1
		if float(n) >= 0.6 * float(taille.y - 2):
			sortie.append(x)
	return sortie


func _salle_2() -> void:
	print("\n--- 7.2 Deux duels : deux chambres, une porte, le joueur entre les deux ---")
	var c := o.ctx(1)
	var nav: Nav = c["nav"]
	var ks := _libres(c)
	var cols := _colonnes_de_cloison(c)
	_check("une cloison de 2 cases de large coupe la salle en deux (colonnes %s)" % str(cols), cols.size() == 2 and cols[1] == cols[0] + 1)
	var porte: Array[Vector2i] = []
	for cc in nav.cases_praticables():
		if cc.x in cols:
			porte.append(cc)
	_check("… percée d'une porte de 4 cases : %d cases praticables dans la cloison (8 : 4 de haut, 2 de profondeur)" % porte.size(), porte.size() == 8 and Chass.composantes(porte).size() == 1)
	# Les deux chambres : les cases de part et d'autre de la cloison.
	var ouest: Array[Vector2i] = []
	var est: Array[Vector2i] = []
	for cc in nav.cases_praticables():
		if cc.x < cols[0]:
			ouest.append(cc)
		elif cc.x > cols[1]:
			est.append(cc)
	var n_ouest := 0
	var n_est := 0
	for k in ks:
		n_ouest += 1 if (c["pnj"][k]["case"] as Vector2i).x < cols[0] else 0
		n_est += 1 if (c["pnj"][k]["case"] as Vector2i).x > cols[1] else 0
	_check("deux chasseurs, un dans chaque chambre (%d à l'ouest, %d à l'est)" % [n_ouest, n_est], ks.size() == 2 and n_ouest == 1 and n_est == 1)
	var l_ouest := 0
	var l_est := 0
	for l: Dictionary in c["lampes"]:
		l_ouest += 1 if (l["case"] as Vector2i).x < cols[0] else 0
		l_est += 1 if (l["case"] as Vector2i).x > cols[1] else 0
	_check("une lampe dans chaque chambre, aucune dans la cloison", l_ouest == 1 and l_est == 1)
	_check("deux chambres de même taille (%d et %d cases, à 10 %% près) : deux duels pareils" % [ouest.size(), est.size()], absf(float(ouest.size() - est.size())) <= 0.1 * float(ouest.size()))
	_check("le joueur part dans l'embrasure de la porte, hors de toute lampe : %s" % str(c["depart"]), c["depart"].x in cols and not o.eclaire_par_lampe(c, c["depart_pos"]))
	var a: Vector2 = c["pnj"][ks[0]]["pos"]
	var b: Vector2 = c["pnj"][ks[1]]["pos"]
	_check("la cloison cache un chasseur à l'autre : pas de ligne de vue entre leurs places de départ", not o.ligne_de_vue(c, a, b))
	for k in ks:
		var d := Chass.distance_a_pied(o, c, c["depart"], c["pnj"][k]["case"])
		_check("le chasseur %d est à %.0f px à pied de l'embrasure (plus de 12 cases)" % [k + 1, d], d >= 12.0 * 35.0)
	# Un tir à la porte s'entend des deux chambres : enchaîner sans se faire voir, c'est ne pas se montrer, pas ne pas faire de bruit.
	_check("un tir tiré de la porte s'entend net de partout dans la salle (portée nette %.0f px)" % o.portee_tir_net, (c["depart_pos"] as Vector2).distance_to(Vector2(float(c["taille"].x), float(c["taille"].y)) * 35.0) < o.portee_tir_net)


# ---------------------------------------------------------------------------
# 7.3 — Le noir complet
# ---------------------------------------------------------------------------

func _salle_3() -> void:
	print("\n--- 7.3 Le noir complet : aucune lampe, ni de quoi voir ni de quoi se cacher que ses pas ---")
	var c := o.ctx(2)
	var nav: Nav = c["nav"]
	var ks := _libres(c)
	_check("aucun plafonnier : toute la salle est dans le noir", (c["lampes"] as Array).is_empty())
	_check("des piliers : %d îlots de mur plein (au moins 6)" % Chass.ilots(c).size(), Chass.ilots(c).size() >= 6)
	var vu_dans_le_noir := 0
	var examinees := 0
	var trahi_par_la_torche := 0
	for k in ks:
		var cases := nav.cases_praticables()
		for i in range(0, cases.size(), 3):
			var pos := Nav.centre_de_la_case(cases[i])
			for j in range(0, cases.size(), 7):
				var cible := Nav.centre_de_la_case(cases[j])
				if pos.distance_to(cible) > 14.0 * 35.0 or not o.ligne_de_vue(c, pos, cible):
					continue
				examinees += 1
				if o.voit(c, pos, cible, []):
					vu_dans_le_noir += 1
				if o.voit(c, pos, cible, [Percep.lumiere_lampe("lampe", cible, o.hauteur)]):
					trahi_par_la_torche += 1
	_check("torche éteinte, un joueur debout n'est vu d'AUCUN chasseur, de nulle part : %d paires examinées, %d trahies" % [examinees, vu_dans_le_noir], examinees >= 500 and vu_dans_le_noir == 0)
	_check("… mais une torche allumée le trahit : %d paires sur %d où le chasseur voit sa lampe" % [trahi_par_la_torche, examinees], trahi_par_la_torche >= 100)
	# Le bruit : un pas debout s'entend de toute la salle, un pas accroupi de tout près.
	var taille: Vector2i = c["taille"]
	var diagonale := Vector2(taille.x, taille.y).length() * 35.0
	_check("un pas debout s'entend de partout : la diagonale de la salle (%.0f px) est sous la portée du pas debout (%.0f px)" % [diagonale, o.portee_pas_debout_totale], diagonale < o.portee_pas_debout_totale)
	var loin := 0
	var toutes := nav.cases_praticables()
	for cc in toutes:
		if Nav.centre_de_la_case(cc).distance_to(c["pnj"][ks[0]]["pos"]) > o.portee_pas_accroupi_net + 2.0 * 35.0:
			loin += 1
	_check("un pas accroupi ne s'entend que de tout près (%.0f px) : %d %% de la salle est hors de sa portée du chasseur 1 (au moins 90 %%)" % [o.portee_pas_accroupi_net, int(100.0 * loin / toutes.size())], float(loin) >= 0.9 * float(toutes.size()))
	_check("deux chasseurs, loin du départ et loin l'un de l'autre", ks.size() == 2 and (c["pnj"][ks[0]]["pos"] as Vector2).distance_to(c["pnj"][ks[1]]["pos"]) > 10.0 * 35.0)


# ---------------------------------------------------------------------------
# 7.4 — La lumière piège
# ---------------------------------------------------------------------------

func _salle_4() -> void:
	print("\n--- 7.4 La lumière piège : cinq flaques, du noir entre elles ---")
	var c := o.ctx(3)
	var nav: Nav = c["nav"]
	var ks := _libres(c)
	_check("cinq lampes, leurs flaques à part", (c["lampes"] as Array).size() == 5 and _flaques_a_part(c))
	var claires := Chass.claires(o, c)
	var sombres := Chass.sombres(o, c)
	var part := float(claires.size()) / float(nav.cases_praticables().size())
	_check("la lumière tient %.0f %% des cases (de 12 à 45 %%) : assez pour qu'on s'y trahisse, pas assez pour qu'on n'ait que cela" % (100.0 * part), part >= 0.12 and part <= 0.45)
	var mains := Chass.composantes(sombres)
	var plus_grand := 0
	var le_noir: Array[Vector2i] = []
	for m in mains:
		if (m as Array).size() > plus_grand:
			plus_grand = (m as Array).size()
			le_noir.assign(m)
	_check("le noir est d'un seul tenant : un morceau de %d cases sur %d (au moins 90 %%)" % [plus_grand, sombres.size()], float(plus_grand) >= 0.9 * float(sombres.size()))
	var noir := {}
	for cc in le_noir:
		noir[cc] = true
	var tous_dans_le_noir := noir.has(c["depart"])
	for k in ks:
		tous_dans_le_noir = tous_dans_le_noir and noir.has(c["pnj"][k]["case"])
	_check("le joueur et les deux chasseurs partent dans ce noir-là : on peut s'y croiser sans traverser une flaque", tous_dans_le_noir)
	for k in ks:
		_check("la ligne droite du joueur au chasseur %d traverse une flaque : qui va tout droit se montre" % (k + 1), Chass.segment_en_lumiere(o, c, c["depart_pos"], c["pnj"][k]["pos"]))
	var loin := true
	for l: Dictionary in c["lampes"]:
		loin = loin and (l["pos"] as Vector2).distance_to(c["depart_pos"]) >= 8.0 * 35.0
	_check("aucune lampe à moins de 8 cases du départ", loin)
	# Une flaque trahit AUSSI le chasseur : un chasseur debout au centre d'une flaque est vu d'un joueur à la torche éteinte — la lumière est celle de la salle.
	var l0: Dictionary = c["lampes"][2]
	var poste := (l0["pos"] as Vector2) + Vector2(5.0 * 35.0, 0.0)
	var voit_le_chasseur := o.ligne_de_vue(c, poste, l0["pos"]) and o.voit(c, poste, l0["pos"], o.lumieres(c))
	_check("un corps debout au centre d'une flaque est vu de loin d'un regard à la torche éteinte : la lumière trahit les deux camps", voit_le_chasseur)


# ---------------------------------------------------------------------------
# 7.5 — Le poste et la meute
# ---------------------------------------------------------------------------

func _salle_5() -> void:
	print("\n--- 7.5 Le poste et la meute : couvrir ses arrières ---")
	var c := o.ctx(4)
	var nav: Nav = c["nav"]
	var ks := _libres(c)
	var poste := Chass.pnj_de(c, Profil.Deplacement.IMMOBILE)
	_check("deux chasseurs libres et un poste qui voit et entend, aux réflexes NORMAUX", ks.size() == 2 and poste.size() == 1 and c["pnj"][poste[0]]["profil_nom"] == "immobile_voit_entend_normal")
	var s: Dictionary = c["pnj"][poste[0]]
	_check("le poste est sous une lampe : on le voit de loin, il voit ce qui est éclairé", o.eclaire_par_lampe(c, s["pos"]))
	var d_poste := Chass.distance_a_pied(o, c, c["depart"], s["case"])
	_check("il tient le fond : à %.0f px à pied du départ (plus de 25 cases)" % d_poste, d_poste >= 25.0 * 35.0)
	var devant := true
	for k in ks:
		devant = devant and c["pnj"][k]["pos"].x < s["pos"].x and c["pnj"][k]["pos"].x > c["depart_pos"].x
	_check("les deux chasseurs sont ENTRE le joueur et le poste : les tuer, c'est s'avancer vers lui", devant)
	var niche := _mur_a(c, s["case"], Vector2i.UP, 3) and _mur_a(c, s["case"], Vector2i.DOWN, 3)
	_check("le poste est dans une niche : un mur au-dessus et au-dessous de lui, à trois cases au plus", niche)
	var claires := Chass.claires(o, c)
	var part := Chass.part_en_vue(o, c, s["pos"], claires, 22.0 * 35.0)
	_check("il voit %.0f %% des cases éclairées du hall (au moins 35 %%) : traverser une flaque sous son regard, c'est se montrer" % (100.0 * part), part >= 0.35)
	_check("trois lampes aux flaques à part", (c["lampes"] as Array).size() == 3 and _flaques_a_part(c))
	_check("des colonnes : %d cases de mur plein à l'intérieur (au moins 20)" % o.murs_interieurs(c), o.murs_interieurs(c) >= 20)
	var dark_pres_du_poste := 0
	for cc in nav.cases_praticables():
		var pos := Nav.centre_de_la_case(cc)
		if pos.distance_to(s["pos"]) <= 14.0 * 35.0 and not o.eclaire_par_lampe(c, pos) and o.ligne_de_vue(c, s["pos"], pos):
			dark_pres_du_poste += 1
	_check("mais le noir existe aussi sous son regard : %d cases à moins de 14 cases de lui qu'il voit sans qu'elles soient éclairées (au moins 20) : il n'y voit rien" % dark_pres_du_poste, dark_pres_du_poste >= 20)


# ---------------------------------------------------------------------------
# 7.6 — L'ombre
# ---------------------------------------------------------------------------

func _salle_6() -> void:
	print("\n--- 7.6 L'ombre : les colonnes jettent une ombre dans la flaque ---")
	var c := o.ctx(5)
	_check("huit colonnes de 2 × 2 : %d îlots de 4 cases" % Chass.ilots(c).size(), Chass.ilots(c).size() == 8)
	_check("deux lampes aux flaques à part, grandes (rayon 8 cases de texture)", (c["lampes"] as Array).size() == 2 and _flaques_a_part(c) and float(c["lampes"][0]["rayon_px"]) >= 8.0 * 35.0)
	for l: Dictionary in c["lampes"]:
		var ombres := Chass.ombres_de_la_lampe(o, c, l)
		_check("la lampe %s : %d cases dans sa flaque qu'une colonne lui cache (au moins 10)" % [str(l["case"]), ombres.size()], ombres.size() >= 10)
		# L'asymétrie : de l'ombre on voit la flaque, de la flaque on ne voit pas l'ombre.
		var paires := 0
		for s_cc in ombres:
			var s_pos := Nav.centre_de_la_case(s_cc)
			for cc in Chass.claires(o, c):
				var p := Nav.centre_de_la_case(cc)
				if p.distance_to(s_pos) <= 6.0 * 35.0 and o.ligne_de_vue(c, s_pos, p):
					paires += 1
					break
		_check("… et de %d de ces cases d'ombre on voit une case éclairée (ligne de vue, 6 cases) : on y guette sans être vu — l'ombre est un affût" % paires, paires >= 8)
	var ks := _libres(c)
	_check("deux chasseurs libres, loin du départ", ks.size() == 2)
	_check("le départ est dans le noir, loin des deux lampes", not o.eclaire_par_lampe(c, c["depart_pos"]) and not o.sous_une_lampe(c, c["depart_pos"]))


# ---------------------------------------------------------------------------
# 7.7 — Trois chasseurs
# ---------------------------------------------------------------------------

func _salle_7() -> void:
	print("\n--- 7.7 Trois chasseurs : des îlots, un terrain à choisir ---")
	var c := o.ctx(6)
	var ks := _libres(c)
	var ilots := Chass.ilots(c)
	var gros := 0
	for m in ilots:
		gros += 1 if (m as Array).size() >= 9 else 0
	_check("des îlots : %d blocs de mur plein, dont %d d'au moins 9 cases (au moins 7 et 7)" % [ilots.size(), gros], ilots.size() >= 7 and gros >= 7)
	_check("trois chasseurs équipés de l'Occulteur, libres", ks.size() == 3 and c["pnj"][ks[0]]["equipe"] and c["pnj"][ks[1]]["equipe"] and c["pnj"][ks[2]]["equipe"])
	# Trois chasseurs, trois endroits : un par tiers de la hauteur.
	var tiers := {}
	for k in ks:
		tiers[int((c["pnj"][k]["case"] as Vector2i).y * 3 / c["taille"].y)] = true
	_check("ils partent de trois tiers différents de la salle (%d)" % tiers.size(), tiers.size() == 3)
	_check("trois lampes aux flaques à part, aucune sous le départ", (c["lampes"] as Array).size() == 3 and _flaques_a_part(c) and not o.eclaire_par_lampe(c, c["depart_pos"]))
	var claires := Chass.claires(o, c)
	var sombres := Chass.sombres(o, c)
	_check("un terrain à choisir : %d cases éclairées, %d dans le noir (au moins 40 et 500)" % [claires.size(), sombres.size()], claires.size() >= 40 and sombres.size() >= 500)
	for k in ks:
		_check("chasseur %d : la règle de l'ombre habitée peut se déclencher — une place où il se tient, une autre à 150-450 px en ligne dégagée" % (k + 1), _regle_possible(c, (c["nav"] as Nav).cases_praticables()))
	var couvert := 0
	for cc in (c["nav"] as Nav).cases_praticables():
		# Une case « à couvert » : un îlot à une case, à l'ouest ou à l'est — on s'y adosse.
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _mur_a(c, cc, d, 1):
				couvert += 1
				break
	_check("on peut s'adosser : %d cases touchent un mur (au moins 100)" % couvert, couvert >= 100)


# ---------------------------------------------------------------------------
# 7.8 — Le dédale
# ---------------------------------------------------------------------------

func _salle_8() -> void:
	print("\n--- 7.8 Le dédale : un labyrinthe de murets ---")
	var c := o.ctx(7)
	var nav: Nav = c["nav"]
	var ks := _libres(c)
	var murets := Chass.murets(c)
	_check("des murets : %d cases de mur bas (au moins 80), la cloison du labyrinthe" % murets.size(), murets.size() >= 80)
	_check("rien que des murets : aucun mur plein à l'intérieur (%d), la ceinture seule coupe la vue" % o.murs_interieurs(c), o.murs_interieurs(c) == 0)
	_check("trois chasseurs équipés, libres", ks.size() == 3 and c["pnj"][ks[0]]["equipe"] and c["pnj"][ks[1]]["equipe"] and c["pnj"][ks[2]]["equipe"])
	# Un chemin tortueux : du départ à chaque chasseur, bien plus long que la ligne droite.
	for k in ks:
		var d := Chass.distance_a_pied(o, c, c["depart"], c["pnj"][k]["case"])
		var droit: float = (c["depart_pos"] as Vector2).distance_to(c["pnj"][k]["pos"])
		_check("chasseur %d : %.0f px à pied pour %.0f px à vol d'oiseau (×%.1f, au moins ×1,8) : on tourne" % [k + 1, d, droit, d / droit], d >= 1.8 * droit)
	# On voit par-dessus, on ne passe pas : des paires de cases proches, en ligne de vue, mais dont le chemin à pied est bien plus long.
	var cases := nav.cases_praticables()
	var en_vue := 0
	var coupees := 0
	var paires := 0
	for i in range(0, cases.size(), 11):
		var a := Nav.centre_de_la_case(cases[i])
		for j in range(i + 5, cases.size(), 23):
			var b := Nav.centre_de_la_case(cases[j])
			var d := a.distance_to(b)
			if d < 3.0 * 35.0 or d > 9.0 * 35.0:
				continue
			paires += 1
			if not o.ligne_de_vue(c, a, b):
				continue
			en_vue += 1
			var chemin := nav.chemin(cases[i], cases[j])
			if not chemin.is_empty() and o.longueur(chemin) >= 1.6 * d:
				coupees += 1
	_check("on voit par-dessus : %d paires de cases proches sur %d sont en ligne de vue (au moins 50 %%)" % [en_vue, paires], paires >= 100 and float(en_vue) >= 0.5 * float(paires))
	_check("… et on n'y passe pas : %d de ces paires en vue demandent un chemin d'au moins 1,6 fois la ligne droite (au moins 20 %%)" % coupees, float(coupees) >= 0.2 * float(maxi(en_vue, 1)))
	_check("deux lampes, aux flaques à part, au milieu du labyrinthe", (c["lampes"] as Array).size() == 2 and _flaques_a_part(c) and not o.eclaire_par_lampe(c, c["depart_pos"]))
	for k in ks:
		_check("chasseur %d : la règle de l'ombre habitée peut se déclencher" % (k + 1), _regle_possible(c, nav.cases_praticables()))


# ---------------------------------------------------------------------------
# 7.9 — La salle pleine
# ---------------------------------------------------------------------------

func _salle_9() -> void:
	print("\n--- 7.9 La salle pleine : quatre chasseurs, des quatre côtés ---")
	var c := o.ctx(8)
	var ks := _libres(c)
	var taille: Vector2i = c["taille"]
	_check("une grande carte : %d × %d cases (au moins 36 × 36 pour 50 × 36 de côté)" % [taille.x, taille.y], taille.x * taille.y >= 1500)
	_check("quatre chasseurs équipés de l'Occulteur, libres", ks.size() == 4 and c["pnj"][ks[0]]["equipe"] and c["pnj"][ks[1]]["equipe"] and c["pnj"][ks[2]]["equipe"] and c["pnj"][ks[3]]["equipe"])
	var serres := false
	var plus_serre := INF
	for i in ks.size():
		for j in range(i + 1, ks.size()):
			var d: float = (c["pnj"][ks[i]]["pos"] as Vector2).distance_to(c["pnj"][ks[j]]["pos"])
			plus_serre = minf(plus_serre, d)
	serres = plus_serre < 15.0 * 35.0
	_check("une meute et non un tas : les chasseurs partent à %.0f px au moins les uns des autres (15 cases)" % plus_serre, not serres)
	var depart_d := INF
	for k in ks:
		depart_d = minf(depart_d, (c["pnj"][k]["pos"] as Vector2).distance_to(c["depart_pos"]))
	_check("le plus proche part à %.0f px du joueur (plus de 20 cases)" % depart_d, depart_d >= 20.0 * 35.0)
	_check("des colonnes en quinconce : %d îlots (au moins 17)" % Chass.ilots(c).size(), Chass.ilots(c).size() >= 17)
	_check("quatre lampes aux flaques à part, aucune sous le départ, aucune sous un chasseur", (c["lampes"] as Array).size() == 4 and _flaques_a_part(c) and not o.eclaire_par_lampe(c, c["depart_pos"]))
	var sous := false
	for k in ks:
		sous = sous or o.eclaire_par_lampe(c, c["pnj"][k]["pos"])
	_check("aucun chasseur ne naît sous une lampe : la meute se lève dans le noir", not sous)
	var secteurs := {}
	for k in ks:
		var p: Vector2i = c["pnj"][k]["case"]
		secteurs[Vector2i(0 if p.x < taille.x / 2 else 1, 0 if p.y < taille.y / 2 else 1)] = true
	_check("ils partent d'au moins trois quarts différents de la salle (%d)" % secteurs.size(), secteurs.size() >= 3)
	for k in ks:
		_check("chasseur %d : la règle de l'ombre habitée peut se déclencher" % (k + 1), _regle_possible(c, (c["nav"] as Nav).cases_praticables()))


# ---------------------------------------------------------------------------
# 7.10 — l'Occulteur
# ---------------------------------------------------------------------------

func _boss() -> void:
	print("\n--- 7.10 L'Occulteur : le boss de ce chapitre ---")
	var c := o.ctx(9)
	var p: Dictionary = c["pnj"][0]
	_check("le boss est le profil `boss` réglé à l'Occulteur : de la vie en plus (`REGLAGES_BOSS`)", p["profil"].vie > 100.0)
	_check("des colonnes autour du centre et un bloc au milieu : au moins 8 cases de mur plein de plus que la ceinture (%d)" % o.murs_interieurs(c), o.murs_interieurs(c) >= 20)
	_check("deux lampes, de part et d'autre du centre", (c["lampes"] as Array).size() == 2)
