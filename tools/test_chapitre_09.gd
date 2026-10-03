## La garde du CHAPITRE 9 — chantier SOLO, étape S8 (lot 2) : chaque salle enseigne ce qu'elle dit.
##
## Le chapitre 9, « L'élite », est écrit dans `res://assets/solo/chapitre_09/` (par `tools/fabrique_chapitre_09.gd`). Peu d'ennemis, mais les meilleurs : des chasseurs libres de
## niveau DIFFICILE (`libre_voit_entend_difficile`), seuls, par deux ou par trois, des gardes et un poste quand la salle s'agrandit. Chaque salle est un duel difficile ou deux.
## Cette suite mesure sur les données ce que chaque salle impose, avec les fonctions du jeu (`tools/outils_chapitre.gd`, `tools/outils_chasseurs.gd`).
##
## Partout : taille, PNJ de chaque sorte, plafonniers, PNJ équipés (la classe du boss, le voile, à partir de 9.7 — un PNJ équipé VOIT : le voile se pose face à une torche qu'on voit),
## chaque PNJ atteignable à pied, une seule pièce, aucun couloir d'une tuile, chaque zone assez vaste, le départ à l'abri, et — pour un PNJ libre — le départ hors de toute lampe et à
## bonne distance. Aussi : **une élite est bien plus vive qu'un chasseur normal** (rafale, délai de réaction, comparés au catalogue du chapitre 7). Puis salle par salle : 9.1 une
## arène à quatre blocs ; 9.2 aucune lampe ; 9.3 une flaque au centre que la ligne droite traverse et que le noir contourne ; 9.4 deux élites qui partent du fond ; 9.5 trois voiles
## qui coupent la lumière des lampes ; 9.6 un poste au fond d'une niche, deux gardes devant ; 9.7 un labyrinthe de cloisons pleines percées de fenêtres basses ; 9.8 trois élites des
## trois côtés ; 9.9 une carte immense, quatre coins occupés ; 9.10 un duel en miroir, quatre voiles et un passage de deux cases.
##
## Sabotée salle par salle — la liste est dans la ROADMAP, S8 lot 2. Pour saboter sans toucher aux fichiers livrés : `-- --dossier=<chemin absolu d'une copie du chapitre>`.
##
## Lancer : godot --headless --path . --script res://tools/test_chapitre_09.gd
extends SceneTree

const Outils := preload("res://tools/outils_chapitre.gd")
const Chass := preload("res://tools/outils_chasseurs.gd")
const Nav := preload("res://navigation_bot.gd")
const Profil := preload("res://profil_bot.gd")
const Codec := preload("res://map_codec.gd")
const Percep := preload("res://perception_bot.gd")
const Equip := preload("res://equipement_bot.gd")

const DOSSIER_LIVRE := "res://assets/solo/chapitre_09"
const NUMERO := 9
const CLASSE := "spectre"
const GADGET := "voile"
const EL := "libre_voit_entend_difficile"
const ZON := "zone_voit_entend_normal"
const POSTE := "immobile_voit_entend_difficile"

const TABLE := [
	{"pnj": {EL: 1}, "lampes": 2, "equipes": 0, "cotes": [24, 24]},
	{"pnj": {EL: 1}, "lampes": 0, "equipes": 0, "cotes": [28, 28]},
	{"pnj": {EL: 1}, "lampes": 1, "equipes": 0, "cotes": [26, 26]},
	{"pnj": {EL: 2}, "lampes": 2, "equipes": 0, "cotes": [28, 36]},
	{"pnj": {EL: 1, ZON: 1}, "lampes": 2, "equipes": 0, "cotes": [26, 34]},
	{"pnj": {POSTE: 1, ZON: 2}, "lampes": 3, "equipes": 0, "cotes": [24, 38]},
	{"pnj": {EL: 2}, "lampes": 2, "equipes": 2, "cotes": [31, 40]},
	{"pnj": {EL: 3}, "lampes": 4, "equipes": 3, "cotes": [40, 56]},
	{"pnj": {POSTE: 1, ZON: 2, EL: 2}, "lampes": 5, "equipes": 4, "cotes": [48, 64]},
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
	print("=== LE CHAPITRE 9 — L'ÉLITE (S8, lot 2) ===")
	var dossier := DOSSIER_LIVRE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="):
			dossier = a.substr(10)
	o = Outils.new(Callable(self, "_check"))
	o.mesures_du_jeu(root)
	if not o.charger(dossier, NUMERO, "L'élite", CLASSE, 10):
		print("\n=== %d vérifications, %d échec(s) ===" % [_verifications, _failures])
		print("CRIS ATTENDUS: 0")
		quit(1)
		return
	o.partout(NUMERO, CLASSE, TABLE)
	print("\n--- Partout : un PNJ libre part loin du joueur, hors de toute lampe ---")
	for i in 10:
		Chass.libres_partout(o, o.ctx(i), "9.%d" % (i + 1), 25 if i == 9 else 12)
	_elites()
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

func _de(c: Dictionary, d: int) -> Array[int]:
	return Chass.pnj_de(c, d)


func _flaques_a_part(c: Dictionary) -> bool:
	var ls: Array = c["lampes"]
	for i in ls.size():
		for j in range(i + 1, ls.size()):
			if (ls[i]["pos"] as Vector2).distance_to(ls[j]["pos"]) <= Chass.rayon_clair(ls[i]) + Chass.rayon_clair(ls[j]):
				return false
	return true


## La règle du voile peut-elle se déclencher ? Une case où le PNJ se tient, une place à la distance de la règle (`EquipementBot.GADGETS`) en ligne dégagée.
func _regle_possible(c: Dictionary, cases: Array[Vector2i]) -> bool:
	var fenetre: Array = Equip.GADGETS[GADGET]["distance"]
	var cibles := (c["nav"] as Nav).cases_praticables()
	for i in range(0, cases.size(), maxi(1, cases.size() / 40)):
		var a := Nav.centre_de_la_case(cases[i])
		for j in range(0, cibles.size(), maxi(1, cibles.size() / 80)):
			var b := Nav.centre_de_la_case(cibles[j])
			var d := a.distance_to(b)
			if d >= float(fenetre[0]) and d <= float(fenetre[1]) and Percep.segment_degage(a, b, c["monde"]):
				return true
	return false


func _cases_du_pnj(c: Dictionary, k: int) -> Array[Vector2i]:
	var d: int = c["pnj"][k]["profil"].deplacement
	if d == Profil.Deplacement.RONDE:
		return o.cases_du_tour(o.tour_de_la_ronde(c, k))
	if d == Profil.Deplacement.ZONE:
		return o.cases_de_la_zone_atteignables(c, k)
	return (c["nav"] as Nav).cases_praticables()


func _tous_equipes(c: Dictionary, ks: Array[int]) -> bool:
	for k in ks:
		if not c["pnj"][k]["equipe"]:
			return false
	return not ks.is_empty()


## Le plus petit écart, en px, entre les places de départ d'une liste de PNJ.
func _plus_serres(c: Dictionary, ks: Array[int]) -> float:
	var m := INF
	for i in ks.size():
		for j in range(i + 1, ks.size()):
			m = minf(m, (c["pnj"][ks[i]]["pos"] as Vector2).distance_to(c["pnj"][ks[j]]["pos"]))
	return m


## La plus petite distance à pied du joueur à l'un de ces PNJ.
func _plus_proche_a_pied(c: Dictionary, ks: Array[int]) -> float:
	var m := INF
	for k in ks:
		m = minf(m, Chass.distance_a_pied(o, c, c["depart"], c["pnj"][k]["case"]))
	return m


# ---------------------------------------------------------------------------
# UNE ÉLITE EST UN ADVERSAIRE DIFFICILE
# ---------------------------------------------------------------------------

func _elites() -> void:
	print("\n--- Une élite est bien plus vive qu'un chasseur normal ---")
	var normal := Profil.pnj_nomme("libre_voit_entend_normal")
	var elite := Profil.pnj_nomme(EL)
	_check("l'élite tire des rafales plus longues que le chasseur du chapitre 7 (%d coups contre %d)" % [elite.tirs_par_rafale, normal.tirs_par_rafale], elite.tirs_par_rafale > normal.tirs_par_rafale)
	_check("… réagit plus vite (%.3f s contre %.3f s) et vise plus vite (%.1f rad/s contre %.1f)" % [elite.delai_reaction, normal.delai_reaction, elite.vitesse_visee, normal.vitesse_visee],
		elite.delai_reaction < normal.delai_reaction and elite.vitesse_visee > normal.vitesse_visee)
	_check("sans la clé « equipe », l'élite n'a aucun outil, comme tout PNJ du catalogue (ni gadget, ni fusée, ni torche tactique)", not elite.utilise_le_gadget and not elite.lance_des_fusees and not elite.torche_tactique)
	var equipee := Profil.pnj_nomme(EL)
	Profil.equiper_un_pnj(equipee, Profil.palier_du_nom(EL))
	_check("équipée : le gadget de sa classe, la torche tactique, la posture accroupie et les fusées d'un bot DIFFICILE, ses réflexes inchangés (%.3f s)" % equipee.delai_reaction,
		equipee.utilise_le_gadget and equipee.torche_tactique and equipee.lance_des_fusees and equipee.accroupi_pres_du_son_px > 0.0 and is_equal_approx(equipee.delai_reaction, elite.delai_reaction))


# ---------------------------------------------------------------------------
# 9.1 — L'élite
# ---------------------------------------------------------------------------

func _salle_1() -> void:
	print("\n--- 9.1 L'élite : un duel difficile dans une arène ---")
	var c := o.ctx(0)
	var k := _de(c, Profil.Deplacement.LIBRE)[0]
	var p: Dictionary = c["pnj"][k]
	var ilots := Chass.ilots(c)
	_check("quatre blocs de 3 × 3 autour du centre : %d îlots de %s cases" % [ilots.size(), str([(ilots[0] as Array).size()]) if ilots.size() > 0 else "?"], ilots.size() == 4 and (ilots[0] as Array).size() == 9)
	_check("deux lampes aux flaques à part, aucune sous le joueur ni sous l'élite", (c["lampes"] as Array).size() == 2 and _flaques_a_part(c) and not o.eclaire_par_lampe(c, c["depart_pos"]) and not o.eclaire_par_lampe(c, p["pos"]))
	for l: Dictionary in c["lampes"]:
		var n := 0
		for cc in Chass.claires(o, c):
			if Nav.centre_de_la_case(cc).distance_to(l["pos"]) <= Chass.rayon_clair(l):
				n += 1
		_check("la lampe %s éclaire une vraie flaque : %d cases (au moins 12)" % [str(l["case"]), n], n >= 12)
	var d := Chass.distance_a_pied(o, c, c["depart"], p["case"])
	_check("l'élite part à %.0f px à pied du joueur (plus de 16 cases)" % d, d >= 16.0 * 35.0)
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
	_check("autour du départ (6 cases) : %d cases à couvert de l'élite et %d en vue d'elle (au moins 10 de chaque)" % [abri, vu], abri >= 10 and vu >= 10)


# ---------------------------------------------------------------------------
# 9.2 — Le noir
# ---------------------------------------------------------------------------

func _salle_2() -> void:
	print("\n--- 9.2 Le noir : aucune lampe, et tout s'entend ---")
	var c := o.ctx(1)
	var nav: Nav = c["nav"]
	var k := _de(c, Profil.Deplacement.LIBRE)[0]
	_check("aucun plafonnier : toute la salle est dans le noir", (c["lampes"] as Array).is_empty())
	_check("des piliers : %d îlots (au moins 5)" % Chass.ilots(c).size(), Chass.ilots(c).size() >= 5)
	var vu_dans_le_noir := 0
	var examinees := 0
	var trahi := 0
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
				trahi += 1
	_check("torche éteinte, un joueur debout n'est vu de nulle part : %d paires examinées, %d trahies" % [examinees, vu_dans_le_noir], examinees >= 500 and vu_dans_le_noir == 0)
	_check("… mais une torche allumée le trahit : %d paires sur %d" % [trahi, examinees], trahi >= 100)
	var taille: Vector2i = c["taille"]
	var diagonale := Vector2(taille.x, taille.y).length() * 35.0
	_check("un pas debout s'entend de partout : la diagonale (%.0f px) est sous la portée du pas debout (%.0f px)" % [diagonale, o.portee_pas_debout_totale], diagonale < o.portee_pas_debout_totale)
	var loin := 0
	for cc in cases:
		if Nav.centre_de_la_case(cc).distance_to(c["pnj"][k]["pos"]) > o.portee_pas_accroupi_net + 2.0 * 35.0:
			loin += 1
	_check("… un pas accroupi seulement de tout près (%.0f px) : %d %% de la salle est hors de sa portée de l'élite (au moins 90 %%)" % [o.portee_pas_accroupi_net, int(100.0 * loin / cases.size())], float(loin) >= 0.9 * float(cases.size()))
	_check("une douille s'entend de %.0f px : on ne tire pas sans se faire entendre" % o.portee_douille_nette, o.portee_douille_nette > 0.0)


# ---------------------------------------------------------------------------
# 9.3 — La flaque
# ---------------------------------------------------------------------------

func _salle_3() -> void:
	print("\n--- 9.3 La flaque : la ligne droite traverse la lumière, le noir tourne autour ---")
	var c := o.ctx(2)
	var taille: Vector2i = c["taille"]
	var k := _de(c, Profil.Deplacement.LIBRE)[0]
	var p: Dictionary = c["pnj"][k]
	var l: Dictionary = c["lampes"][0]
	_check("une seule lampe, au centre de l'arène : %s pour une salle de %d × %d" % [str(l["case"]), taille.x, taille.y], l["case"] == Vector2i(taille.x / 2, taille.y / 2))
	var claires := Chass.claires(o, c)
	_check("une flaque de %d cases (au moins 40), qui n'est qu'une part de l'arène (moins de 15 %%)" % claires.size(), claires.size() >= 40 and float(claires.size()) < 0.15 * float(taille.x * taille.y))
	_check("la ligne droite du joueur à l'élite traverse la flaque : qui va tout droit se montre", Chass.segment_en_lumiere(o, c, c["depart_pos"], p["pos"]))
	var morceau: Array = []
	for m in Chass.composantes(Chass.sombres(o, c)):
		if (m as Array).has(c["depart"]):
			morceau = m
	_check("mais le noir tourne autour : le joueur et l'élite sont dans le MÊME morceau d'ombre (%d cases)" % morceau.size(), morceau.has(p["case"]))
	var dark := float(morceau.size()) / float(maxi(Chass.sombres(o, c).size(), 1))
	_check("… un anneau d'ombre d'un seul tenant (%.0f %% du noir de la salle, au moins 95 %%)" % (100.0 * dark), dark >= 0.95)
	_check("quatre colonnes aux coins : %d îlots (4)" % Chass.ilots(c).size(), Chass.ilots(c).size() == 4)
	_check("le départ est dans le noir, à %.0f px de la lampe (plus de 7 cases)" % (l["pos"] as Vector2).distance_to(c["depart_pos"]), not o.eclaire_par_lampe(c, c["depart_pos"]) and (l["pos"] as Vector2).distance_to(c["depart_pos"]) > 7.0 * 35.0)


# ---------------------------------------------------------------------------
# 9.4 — Le binôme d'élite
# ---------------------------------------------------------------------------

func _salle_4() -> void:
	print("\n--- 9.4 Le binôme d'élite : deux à la fois ---")
	var c := o.ctx(3)
	var ks := _de(c, Profil.Deplacement.LIBRE)
	var taille: Vector2i = c["taille"]
	_check("deux élites", ks.size() == 2)
	_check("des îlots : %d blocs (au moins 6)" % Chass.ilots(c).size(), Chass.ilots(c).size() >= 6)
	_check("deux lampes aux flaques à part, aucune sous le joueur", (c["lampes"] as Array).size() == 2 and _flaques_a_part(c) and not o.eclaire_par_lampe(c, c["depart_pos"]))
	var du_fond := true
	for k in ks:
		du_fond = du_fond and c["pnj"][k]["case"].x * 3 >= 2 * taille.x
	_check("elles partent du fond de la salle : le dernier tiers à l'est", du_fond)
	var ecart := _plus_serres(c, ks)
	_check("à %.0f px l'une de l'autre (de 8 à 20 cases) : ensemble, pas empilées" % ecart, ecart >= 8.0 * 35.0 and ecart <= 20.0 * 35.0)
	var proche := _plus_proche_a_pied(c, ks)
	_check("la plus proche part à %.0f px à pied du joueur (plus de 25 cases)" % proche, proche >= 25.0 * 35.0)
	var sous := false
	for k in ks:
		sous = sous or o.eclaire_par_lampe(c, c["pnj"][k]["pos"])
	_check("aucune ne naît sous une lampe : elles se lèvent dans le noir", not sous)


# ---------------------------------------------------------------------------
# 9.5 — Le voile
# ---------------------------------------------------------------------------

func _salle_5() -> void:
	print("\n--- 9.5 Le voile : des murs minces qui coupent la lumière ---")
	var c := o.ctx(4)
	var nav: Nav = c["nav"]
	var ilots := Chass.ilots(c)
	var minces := 0
	for m in ilots:
		var x0 := 1000
		var x1 := -1
		var y0 := 1000
		var y1 := -1
		for cc: Vector2i in m:
			x0 = mini(x0, cc.x)
			x1 = maxi(x1, cc.x)
			y0 = mini(y0, cc.y)
			y1 = maxi(y1, cc.y)
		if (x1 == x0 or y1 == y0) and (m as Array).size() >= 7:
			minces += 1
	_check("trois voiles : %d murs d'UNE case d'épaisseur et d'au moins 7 cases de long (sur %d îlots)" % [minces, ilots.size()], minces == 3 and ilots.size() == 3)
	_check("deux lampes aux flaques à part", (c["lampes"] as Array).size() == 2 and _flaques_a_part(c))
	for l: Dictionary in c["lampes"]:
		var ombres := Chass.ombres_de_la_lampe(o, c, l)
		var plus_pres := INF
		for m in ilots:
			for cc: Vector2i in m:
				plus_pres = minf(plus_pres, Nav.centre_de_la_case(cc).distance_to(l["pos"]))
		_check("la lampe %s est à %.0f px d'un voile (moins de 4 cases) : il lui cache %d cases de sa propre flaque (au moins 8)" % [str(l["case"]), plus_pres, ombres.size()], plus_pres <= 4.0 * 35.0 and ombres.size() >= 8)
	var zs := _de(c, Profil.Deplacement.ZONE)
	var els := _de(c, Profil.Deplacement.LIBRE)
	_check("une élite libre et un garde en zone, aux réflexes NORMAUX, qui ne sont pas équipés", zs.size() == 1 and els.size() == 1 and not c["pnj"][zs[0]]["equipe"] and not c["pnj"][els[0]]["equipe"])
	var zone: Rect2i = c["pnj"][zs[0]]["zone"]
	var dedans := nav.cases_dans(zone)
	_check("le garde erre dans un coin que le troisième voile ferme : sa zone %s, %d cases" % [str(zone), dedans.size()], dedans.size() >= 60)
	_check("… et ce coin est dans le noir : %d cases de sa zone éclairées" % Chass.combien_claires(o, c, dedans), Chass.combien_claires(o, c, dedans) == 0)
	var tout_droit_coupe := true
	for m in ilots:
		var proche_de_la_zone := false
		for cc: Vector2i in m:
			proche_de_la_zone = proche_de_la_zone or (zone.grow(3).has_point(cc))
		if proche_de_la_zone:
			tout_droit_coupe = tout_droit_coupe and (m as Array).size() >= 7
	_check("un voile touche la zone du garde (à 3 cases) : la lumière d'une lampe ne l'y suit pas", tout_droit_coupe)
	_check("le départ est dans le noir, loin des deux lampes", not o.eclaire_par_lampe(c, c["depart_pos"]) and not o.sous_une_lampe(c, c["depart_pos"]))


# ---------------------------------------------------------------------------
# 9.6 — La garde d'élite
# ---------------------------------------------------------------------------

func _salle_6() -> void:
	print("\n--- 9.6 La garde d'élite : un poste difficile, couvert par deux gardes ---")
	var c := o.ctx(5)
	var nav: Nav = c["nav"]
	var postes := _de(c, Profil.Deplacement.IMMOBILE)
	var zs := _de(c, Profil.Deplacement.ZONE)
	var s: Dictionary = c["pnj"][postes[0]]
	_check("un poste de niveau DIFFICILE, immobile, qui voit et entend ; deux gardes de niveau NORMAL en zone", s["profil_nom"] == POSTE and zs.size() == 2)
	_check("le poste est sous une lampe : on le voit de loin, il voit ce qui est éclairé", o.eclaire_par_lampe(c, s["pos"]))
	var niche := false
	var murs := {}
	for m in Codec.get_wall_cells(c["carte"]):
		murs[m] = true
	var haut := false
	var bas := false
	for k in range(1, 4):
		haut = haut or murs.has(s["case"] + Vector2i(0, -k))
		bas = bas or murs.has(s["case"] + Vector2i(0, k))
	niche = haut and bas
	_check("le poste est dans une niche : un mur au-dessus et au-dessous, à trois cases au plus", niche)
	var entre := true
	var disjointes := not (c["pnj"][zs[0]]["zone"] as Rect2i).intersects(c["pnj"][zs[1]]["zone"])
	for k in zs:
		var z: Rect2i = c["pnj"][k]["zone"]
		entre = entre and z.position.x > c["depart"].x and z.end.x - 1 < s["case"].x
		_check("la zone du garde %d (%s) est ENTRE le joueur et le poste, %d cases" % [k + 1, str(z), nav.cases_dans(z).size()], z.position.x > c["depart"].x and z.end.x - 1 < s["case"].x and nav.cases_dans(z).size() >= 100)
		var part := Chass.part_en_vue(o, c, s["pos"], nav.cases_dans(z), 24.0 * 35.0)
		_check("le poste couvre la zone %d : %.0f %% de ses cases sont dans son champ (ligne de vue, 24 cases ; au moins 25 %%)" % [k + 1, 100.0 * part], part >= 0.25)
		_check("… la zone est éclairée : le garde s'y voit, et il voit ce qui s'y montre (%d cases éclairées, au moins 10)" % Chass.combien_claires(o, c, nav.cases_dans(z)), Chass.combien_claires(o, c, nav.cases_dans(z)) >= 10)
	_check("deux zones disjointes, de part et d'autre de l'axe, devant le poste", entre and disjointes)
	_check("trois lampes aux flaques à part", (c["lampes"] as Array).size() == 3 and _flaques_a_part(c))
	var d := Chass.distance_a_pied(o, c, c["depart"], s["case"])
	_check("le poste tient le fond : à %.0f px à pied du départ (plus de 28 cases)" % d, d >= 28.0 * 35.0)
	_check("les gardes et le poste ne sont pas équipés (« seuls les PNJ qui bougent le sont », et pas avant 9.7)", not c["pnj"][zs[0]]["equipe"] and not c["pnj"][zs[1]]["equipe"] and not s["equipe"])


# ---------------------------------------------------------------------------
# 9.7 — Le dédale
# ---------------------------------------------------------------------------

func _salle_7() -> void:
	print("\n--- 9.7 Le dédale : des cloisons pleines, des fenêtres basses ---")
	var c := o.ctx(6)
	var nav: Nav = c["nav"]
	var ks := _de(c, Profil.Deplacement.LIBRE)
	var murets := Chass.murets(c)
	_check("des cloisons pleines : %d cases de mur plein à l'intérieur (au moins 200)" % o.murs_interieurs(c), o.murs_interieurs(c) >= 200)
	_check("percées de fenêtres basses : %d cases de mur bas (de 20 à 120)" % murets.size(), murets.size() >= 20 and murets.size() <= 120)
	_check("deux élites équipées du Spectre, libres", ks.size() == 2 and _tous_equipes(c, ks))
	for k in ks:
		var d := Chass.distance_a_pied(o, c, c["depart"], c["pnj"][k]["case"])
		var droit: float = (c["depart_pos"] as Vector2).distance_to(c["pnj"][k]["pos"])
		_check("élite %d : %.0f px à pied pour %.0f px en ligne droite (×%.1f, au moins ×2) : on tourne" % [k + 1, d, droit, d / droit], d >= 2.0 * droit)
	var cases := nav.cases_praticables()
	var en_vue := 0
	var paires := 0
	for i in range(0, cases.size(), 11):
		var a := Nav.centre_de_la_case(cases[i])
		for j in range(i + 5, cases.size(), 23):
			var b := Nav.centre_de_la_case(cases[j])
			var d := a.distance_to(b)
			if d < 3.0 * 35.0 or d > 9.0 * 35.0:
				continue
			paires += 1
			if o.ligne_de_vue(c, a, b):
				en_vue += 1
	_check("les cloisons coupent la vue : seules %d paires de cases proches sur %d sont en ligne de vue (moins de 40 %%, au moins 5 %% : les fenêtres)" % [en_vue, paires],
		paires >= 100 and float(en_vue) < 0.4 * float(paires) and float(en_vue) >= 0.05 * float(paires))
	_check("deux lampes aux flaques à part, aucune sous le départ", (c["lampes"] as Array).size() == 2 and _flaques_a_part(c) and not o.eclaire_par_lampe(c, c["depart_pos"]))
	for k in ks:
		_check("élite %d : la règle du voile peut se déclencher (une place à 150-400 px en ligne dégagée)" % (k + 1), _regle_possible(c, cases))


# ---------------------------------------------------------------------------
# 9.8 — La meute d'élite
# ---------------------------------------------------------------------------

func _salle_8() -> void:
	print("\n--- 9.8 La meute d'élite : trois à la fois, de trois côtés ---")
	var c := o.ctx(7)
	var ks := _de(c, Profil.Deplacement.LIBRE)
	var duel := Chass.aire_du_plus_grand_duel()
	_check("%d cases : plus de deux fois la plus grande carte de duel (%d)" % [Chass.aire(c), duel], Chass.aire(c) >= 2 * duel)
	var ilots := Chass.ilots(c)
	_check("neuf blocs de 20 cases : %d îlots" % ilots.size(), ilots.size() == 9 and (ilots[0] as Array).size() == 20)
	_check("trois élites équipées du Spectre, libres", ks.size() == 3 and _tous_equipes(c, ks))
	var ecart := _plus_serres(c, ks)
	_check("une meute et non un tas : au moins 15 cases entre deux élites (%.0f px)" % ecart, ecart >= 15.0 * 35.0)
	var proche := _plus_proche_a_pied(c, ks)
	_check("la plus proche part à %.0f px à pied du joueur (plus de 28 cases)" % proche, proche >= 28.0 * 35.0)
	var taille: Vector2i = c["taille"]
	var cotes := {}
	for k in ks:
		var p: Vector2i = c["pnj"][k]["case"]
		cotes[Vector2i(0 if p.x < taille.x / 2 else 1, 0 if p.y < taille.y / 3 else (1 if p.y < 2 * taille.y / 3 else 2))] = true
	_check("elles partent de trois côtés différents (%d)" % cotes.size(), cotes.size() == 3)
	_check("quatre lampes aux flaques à part, aucune sous le joueur ni sous une élite", (c["lampes"] as Array).size() == 4 and _flaques_a_part(c) and not o.eclaire_par_lampe(c, c["depart_pos"]))
	var sous := false
	for k in ks:
		sous = sous or o.eclaire_par_lampe(c, c["pnj"][k]["pos"])
	_check("aucune élite ne naît sous une lampe", not sous)
	for k in ks:
		_check("élite %d : la règle du voile peut se déclencher" % (k + 1), _regle_possible(c, (c["nav"] as Nav).cases_praticables()))


# ---------------------------------------------------------------------------
# 9.9 — La salle pleine
# ---------------------------------------------------------------------------

func _salle_9() -> void:
	print("\n--- 9.9 La salle pleine : la dernière avant le Spectre ---")
	var c := o.ctx(8)
	var taille: Vector2i = c["taille"]
	var duel := Chass.aire_du_plus_grand_duel()
	var plus_grande := true
	for i in 8:
		plus_grande = plus_grande and Chass.aire(c) > Chass.aire(o.ctx(i))
	_check("%d × %d = %d cases : %.1f fois la plus grande carte de duel, et la plus grande du chapitre" % [taille.x, taille.y, Chass.aire(c), float(Chass.aire(c)) / float(duel)], plus_grande and float(Chass.aire(c)) >= 2.5 * float(duel))
	_check("douze blocs de 20 cases : %d îlots" % Chass.ilots(c).size(), Chass.ilots(c).size() == 12)
	var postes := _de(c, Profil.Deplacement.IMMOBILE)
	var zones := _de(c, Profil.Deplacement.ZONE)
	var els := _de(c, Profil.Deplacement.LIBRE)
	_check("un poste difficile, deux gardes en zone, deux élites", postes.size() == 1 and zones.size() == 2 and els.size() == 2)
	_check("tout ce qui bouge porte le voile : les deux gardes et les deux élites ; le poste, non", _tous_equipes(c, zones) and _tous_equipes(c, els) and not c["pnj"][postes[0]]["equipe"])
	# Quatre coins occupés : les deux gardes et les deux élites, chacun dans un coin différent.
	var coins := {}
	for k in zones + els:
		var p: Vector2i = c["pnj"][k]["case"]
		coins[Vector2i(0 if p.x < taille.x / 2 else 1, 0 if p.y < taille.y / 2 else 1)] = true
	_check("les quatre coins sont occupés, un chacun (%d coins)" % coins.size(), coins.size() == 4)
	var coin_du_joueur: Vector2i = Vector2i(0 if c["depart"].x < taille.x / 2 else 1, 0 if c["depart"].y < taille.y / 2 else 1)
	_check("le joueur part au milieu du bord ouest, entre les deux coins de l'ouest", c["depart"].x <= 3 and absi(c["depart"].y - taille.y / 2) <= 3 and coin_du_joueur.x == 0)
	for k in zones:
		var z: Rect2i = c["pnj"][k]["zone"]
		_check("garde %d : une zone de coin %s de %d cases (au moins 200), loin du départ" % [k + 1, str(z), (c["nav"] as Nav).cases_dans(z).size()], (c["nav"] as Nav).cases_dans(z).size() >= 200 and not z.has_point(c["depart"]))
	var pos_poste: Dictionary = c["pnj"][postes[0]]
	_check("le poste est tout au nord, au milieu (rangée %d, colonne %d) et sous une lampe" % [pos_poste["case"].y, pos_poste["case"].x], pos_poste["case"].y <= 6 and absi(pos_poste["case"].x - taille.x / 2) <= 4 and o.eclaire_par_lampe(c, pos_poste["pos"]))
	_check("cinq lampes aux flaques à part, aucune sous le joueur", (c["lampes"] as Array).size() == 5 and _flaques_a_part(c) and not o.eclaire_par_lampe(c, c["depart_pos"]))
	var ecart := _plus_serres(c, els)
	_check("les deux élites partent à %.0f px l'une de l'autre (plus de 40 cases) : aux deux bouts de la carte" % ecart, ecart >= 40.0 * 35.0)
	for k in zones + els:
		_check("PNJ %d : la règle du voile peut se déclencher" % (k + 1), _regle_possible(c, _cases_du_pnj(c, k)))


# ---------------------------------------------------------------------------
# 9.10 — le Spectre
# ---------------------------------------------------------------------------

func _boss() -> void:
	print("\n--- 9.10 Le Spectre : le boss de ce chapitre ---")
	var c := o.ctx(9)
	var nav: Nav = c["nav"]
	var p: Dictionary = c["pnj"][0]
	_check("le boss est le profil `boss` réglé au Spectre", p["profil"].voit and p["profil"].entend and p["profil"].tire)
	var ilots := Chass.ilots(c)
	var voiles := 0
	for m in ilots:
		var xs := {}
		for cc: Vector2i in m:
			xs[cc.x] = true
		if xs.size() == 1 and (m as Array).size() >= 7:
			voiles += 1
	_check("quatre voiles : des murs d'une case d'épaisseur et de 7 cases de long (%d, sur %d îlots)" % [voiles, ilots.size()], voiles == 4)
	for l: Dictionary in c["lampes"]:
		var ombres := Chass.ombres_de_la_lampe(o, c, l)
		_check("la lampe %s : le voile lui cache %d cases de sa flaque (au moins 8)" % [str(l["case"]), ombres.size()], ombres.size() >= 8)
	var taille: Vector2i = c["taille"]
	var colonne := -1
	for cc in Codec.get_wall_cells(c["carte"]):
		if cc.x > 2 and cc.x < taille.x / 2 - 1 and cc.y == 8:
			colonne = cc.x
	_check("le passage sur l'axe : deux cases libres au milieu de chaque voile, entre deux murs (colonne %d)" % colonne,
		colonne > 0 and nav.est_praticable(Vector2i(colonne, taille.y / 2 - 1)) and nav.est_praticable(Vector2i(colonne, taille.y / 2)) and not nav.est_libre(Vector2i(colonne, taille.y / 2 - 2)) and not nav.est_libre(Vector2i(colonne, taille.y / 2 + 1)))
	_check("des colonnes aux angles et en haut et en bas : %d îlots au total (au moins 8)" % ilots.size(), ilots.size() >= 8)
