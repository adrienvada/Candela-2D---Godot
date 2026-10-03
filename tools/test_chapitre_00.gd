## La garde du CHAPITRE 0 — chantier SOLO, étape S7 : chaque salle enseigne ce qu'elle dit.
##
## Le moteur (S6) sait lire un chapitre ; cette suite juge le CONTENU livré dans `res://assets/solo/chapitre_00/`. Elle ne regarde pas
## si les fichiers sont bien formés (le validateur le fait : le chapitre se charge sans un défaut) mais si chaque salle fait ce que la
## ROADMAP lui demande — « une seule chose nouvelle par salle, que la salle rend NÉCESSAIRE plutôt que de l'expliquer ».
## Tout est MESURÉ sur les données, avec les mêmes fonctions que le jeu :
##
##   • les chemins de `NavigationBot` (un PNJ qu'on n'atteint pas à pied, un couloir d'une tuile) ;
##   • le modèle de vue du bot (`PerceptionBot`), qui ne voit jamais plus que la lumière : « ce PNJ est sous la lampe », « ce PNJ voit
##     ce joueur », « le pilier le cache » sont ses réponses, pas des distances écrites à la main ;
##   • la portée de la torche du Parasite (`PorteeEcran.portee_au_bord`, 468 px), la portée libre d'une fusée (450 px), le rayon de son halo,
##     le chargeur du Parasite (lu dans `game_state.gd`) et les dégâts de son arme.
##
## Salle par salle : 0.1 le PNJ est dans la flaque et en ligne de vue du départ ; 0.2 aucune lampe ne l'éclaire, le pilier le cache ;
## 0.3 plus de tirs nécessaires que de balles dans un chargeur ; 0.4 un mur bas entre chaque PNJ et le départ, et le contourner est plus
## long que l'enjamber ; 0.5 (une grande salle, 36 à 48 cases) aucun PNJ à portée de torche du chemin du centre avec 90 px de marge, chacun au halo
## d'une fusée lancée depuis ce chemin, deux au halo d'UNE seule, aucune fusée pour les trois (ils sont répartis), et ce qu'il faut de fusées tient
## dans la réserve du Parasite (1) et sa recharge (60 s) ; 0.6 le plus
## court chemin passe par les flaques et par elles seules on est vu, un détour existe qui les évite ; 0.7 chaque tir est vu d'un autre PNJ et
## un abri existe ; 0.8 aucune lampe, des PNJ qui n'entendent que, loin ; 0.9 les quatre sortes de PNJ, lampes, recoins et murets ; 0.10 un
## duel en miroir. Et partout : tout PNJ atteignable à pied, aucune ronde, aucun couloir d'une tuile, une seule pièce.
##
## **Sabotée salle par salle** (une garde « enseigne » ne se croit qu'après l'avoir vue rougir) — la liste est dans la ROADMAP, S7. Pour
## saboter sans toucher aux fichiers livrés : `-- --dossier=<chemin absolu d'une copie du chapitre>`.
##
## Lancer : godot --headless --path . --script res://tools/test_chapitre_00.gd
extends SceneTree

const Format := preload("res://aventure_format.gd")
const Profil := preload("res://profil_bot.gd")
const Nav := preload("res://navigation_bot.gd")
const Percep := preload("res://perception_bot.gd")
const Murs := preload("res://murs_bas.gd")
const Portee := preload("res://portee_ecran.gd")
const Iso := preload("res://camera_iso.gd")
const PlafT := preload("res://plafonnier.gd")
const Arme := preload("res://weapon_data.gd")
const Codec := preload("res://map_codec.gd")
const FuseeMod := preload("res://fusee_modele.gd")

const DOSSIER_LIVRE := "res://assets/solo/chapitre_00"

## Les PNJ de chaque salle, selon la table de la ROADMAP : le nombre, et les profils (dans l'ordre des fichiers).
const NB_PNJ := [1, 1, 3, 2, 3, 1, 3, 2, 6, 1]

## La marge qu'on exige sur toute distance « hors de portée » : une case. Un PNJ à 5 px de la limite de la torche n'est pas hors de portée,
## il est à la limite — et le moindre arrondi de la physique le ramène dedans.
const MARGE_PX := 20.0
## Le côté d'une salle, en cases : 16 à 24 (une salle d'initiation, la ROADMAP) sauf celles qui annoncent une autre mesure, ci-dessous. Chaque
## exception dit POURQUOI, et toute salle reste dans ce que le format sait écrire (`MapCodec.MAX_GRID`, 128). Décision d'Adrien du 2026-10-03 :
## « toute liberté sur la taille des cartes : elles peuvent être bien plus grandes que les cartes du duel » — la taille d'une salle
## d'aventure n'est plus bornée par celle d'un duel, elle l'est par ce qu'elle enseigne.
const COTE_MIN := 16
const COTE_MAX := 24
## 0.5, « La fusée » : de 36 à 48. Le bas tient à la torche : le chemin du centre doit laisser, de chaque côté, sa portée (13,4 cases) plus la
## marge (2), soit 31 cases, plus la ceinture — sous 36 les PNJ retombent dans un angle. Le haut tient au jeu : au-delà, ce n'est que de la marche.
## 0.10, l'arène du boss : exactement 32 (l'écran scindé d'un duel, la ROADMAP la tranche).
const COTES_PAR_SALLE := {4: [36, 48], 9: [32, 32]}

## 0.5 — la marge de torche exigée entre un PNJ et toute case du chemin, en px de centre à centre. Elle n'est pas de 150 : une fusée vole 450 px
## et son halo (de modèle) en éclaire 132, soit 582 de portée de lancer pour 468 de torche — 114 au mieux, d'un lancer exact. À 70, le couple
## que montre une seule fusée garde de quoi viser (`FENETRE_VISEE_MIN`).
const MARGE_FUSEE_PX := 90.0
## 0.5 — répartis : deux PNJ à 3 cases l'un de l'autre au moins ; les deux plus éloignés à 8 cases au moins (l'ancienne salle : 2 et 2).
const ECART_MIN_CASES := 3.0
const ECART_MAX_MIN_CASES := 8.0
## 0.5 — jusqu'où la torche « suit » : un PNJ à moins de 10 cases d'un PNJ qu'on est allé tuer se montre au bord du faisceau (on tue de 3 cases).
const CHAINE_CASES := 10.0
## 0.5 — la tolérance de visée (en degrés, au modèle de vue conservateur) d'un lancer qui montre le couple. À 450 px, un degré fait 8 px.
const FENETRE_VISEE_MIN := 3

var _failures := 0
var _verifications := 0
var _niveaux: Array = []
var _portee_torche := 0.0
var _portee_fusee := 0.0
var _rayon_halo_fusee := 0.0
var _chargeur := 0
var _stock_fusees := 0
var _periode_fusee := 0.0
var _vitesse_joueur := 0.0
var _duree_halo_fusee := 0.0
var _hauteur := 0.0
var _hauteur_lampe := 0.0


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
	print("=== LE CHAPITRE 0 — L'INITIATION (S7) ===")
	var dossier := DOSSIER_LIVRE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dossier="):
			dossier = a.substr(10)
	_les_mesures_du_jeu()
	if not _le_chapitre_se_charge(dossier):
		print("\n=== %d vérifications, %d échec(s) ===" % [_verifications, _failures])
		print("CRIS ATTENDUS: 0")
		quit(1)
		return
	_partout()
	_salle_1()
	_salle_2()
	_salle_3()
	_salle_4()
	_salle_5()
	_salle_6()
	_salle_7()
	_salle_8()
	_salle_9()
	_salle_10()
	print("\n=== %d vérifications, %d échec(s) ===" % [_verifications, _failures])
	print("CRIS ATTENDUS: 0")
	quit(1 if _failures > 0 else 0)


# ---------------------------------------------------------------------------
# LES MESURES DU JEU : ce que les salles doivent respecter
# ---------------------------------------------------------------------------

func _les_mesures_du_jeu() -> void:
	print("\n--- Les mesures du jeu ---")
	_portee_torche = Portee.portee_au_bord(Portee.VUE_UNIQUE, Percep.ZOOM_VUE_UNIQUE, Percep.DECALAGE_VISEE, Iso.TANGAGE_DEG)
	_check("la torche du Parasite porte jusqu'au bord de l'écran : 468 px (13,4 cases)", is_equal_approx(_portee_torche, 468.0), str(_portee_torche))
	_portee_fusee = float(FuseeMod.portee_libre())
	# L'empreinte du halo d'une fusée posée est écrite dans `fusee.gd` (`EMPREINTE_LUMIERE`) : lue là, car ce fichier nomme des autoloads
	# et ne se précharge pas sous `--script`.
	var re_fusee := RegEx.create_from_string("const EMPREINTE_LUMIERE\\s*:=\\s*([0-9.]+)")
	var m_fusee := re_fusee.search(FileAccess.get_file_as_string("res://fusee.gd"))
	_rayon_halo_fusee = (m_fusee.get_string(1).to_float() if m_fusee != null else 0.0) * 0.5
	_check("une fusée vole 450 px et s'allume avec un halo de 220 px de rayon", is_equal_approx(_portee_fusee, 450.0) and is_equal_approx(_rayon_halo_fusee, 220.0),
		"%s %s" % [_portee_fusee, _rayon_halo_fusee])
	# Le chargeur du Parasite est écrit dans `game_state.gd` (`weapon_pistolet.max_ammo = N`) : on le lit LÀ, jamais recopié ici.
	var texte := FileAccess.get_file_as_string("res://game_state.gd")
	var re := RegEx.create_from_string("weapon_pistolet\\.max_ammo\\s*=\\s*(\\d+)")
	var m := re.search(texte)
	_chargeur = int(m.get_string(1)) if m != null else 0
	_check("le chargeur du Parasite se lit dans game_state.gd (6 balles)", _chargeur == 6, str(_chargeur))
	# Sa réserve de fusées et la recharge, lues LÀ aussi : `weapon_pistolet.fusees = _fusees(stock, PERIODE_RECHARGE_FUSEE)`.
	var m_stock := RegEx.create_from_string("weapon_pistolet\\.fusees\\s*=\\s*_fusees\\((\\d+),\\s*PERIODE_RECHARGE_FUSEE\\)").search(texte)
	var m_periode := RegEx.create_from_string("const PERIODE_RECHARGE_FUSEE\\s*:=\\s*([0-9.]+)").search(texte)
	_stock_fusees = int(m_stock.get_string(1)) if m_stock != null else 0
	_periode_fusee = m_periode.get_string(1).to_float() if m_periode != null else 0.0
	_check("le Parasite part avec 1 fusée, qui revient en 60 s (game_state.gd)", _stock_fusees == 1 and is_equal_approx(_periode_fusee, 60.0), "%d, %s" % [_stock_fusees, _periode_fusee])
	var m_vitesse := RegEx.create_from_string("@export var speed: float = ([0-9.]+)").search(FileAccess.get_file_as_string("res://player.gd"))
	_vitesse_joueur = m_vitesse.get_string(1).to_float() if m_vitesse != null else 0.0
	_check("le joueur marche à 260 px/s (player.gd)", is_equal_approx(_vitesse_joueur, 260.0), str(_vitesse_joueur))
	_duree_halo_fusee = FuseeMod.duree_plein_feu + FuseeMod.duree_braise
	_check("posée, une fusée éclaire de plein feu puis de braise : au moins 10 s avant l'agonie", _duree_halo_fusee >= 10.0, str(_duree_halo_fusee))
	_hauteur = Murs.hauteur_de_posture(false)
	_hauteur_lampe = Murs.en_pixels(PlafT.HAUTEUR_TUILES)


func _le_chapitre_se_charge(dossier: String) -> bool:
	print("\n--- Le chapitre se charge sans un défaut ---")
	var lu := Format.lire_chapitre(dossier)
	_check("les onze fichiers se lisent", bool(lu["ok"]), str(lu["erreurs"]))
	var defauts := Format.valider_chapitre(lu["manifeste"], lu["niveaux"], 10) if bool(lu["ok"]) else ["illisible"]
	_check("le validateur ne trouve AUCUN défaut (dix salles exigées)", defauts.is_empty(), str(defauts))
	if not defauts.is_empty():
		return false
	var chapitre := Format.charger_chapitre(dossier, 10)
	_check("`charger_chapitre` rend le chapitre prêt à jouer", not chapitre.is_empty())
	if chapitre.is_empty():
		return false
	_niveaux = chapitre["niveaux"]
	_check("dix salles, numéro 0, « L'initiation »", _niveaux.size() == 10 and int(chapitre["numero"]) == 0 and chapitre["titre"] == "L'initiation")
	_check("la classe débloquée et prêtée est le Parasite (« pistolet »)", chapitre["classe_debloquee"] == "pistolet" and chapitre["classe_imposee"] == "pistolet")
	var boss_seul := true
	for i in _niveaux.size():
		boss_seul = boss_seul and (bool(_niveaux[i]["boss"]) == (i == _niveaux.size() - 1))
	_check("le boss est la dixième salle, et elle seule", boss_seul)
	for i in _niveaux.size():
		var n: Dictionary = _niveaux[i]
		_check("0.%d porte un titre et une phrase d'intention d'une ligne (≤ 120 signes, sans « ! »)" % (i + 1),
			String(n["titre"]).strip_edges() != "" and String(n["intention"]).strip_edges() != "" and String(n["intention"]).length() <= 120
			and not String(n["intention"]).contains("!") and not String(n["intention"]).contains("\n"), String(n["intention"]))
	return true


# ---------------------------------------------------------------------------
# LES OUTILS : le contexte d'une salle, et les mesures qu'on y fait
# ---------------------------------------------------------------------------

## Tout ce qu'une salle donne à mesurer : sa navigation, son monde de vue, ses lampes, ses PNJ, le départ du joueur.
func _ctx(i: int) -> Dictionary:
	var n: Dictionary = _niveaux[i]
	var carte: Dictionary = n["carte"]
	var lampes: Array = []
	for p: Dictionary in n["plafonniers"]:
		var rayon_px: float = float(p.get("rayon", PlafT.RAYON_PAR_DEFAUT)) * PlafT.TUILE_PX
		var pos := Nav.centre_de_la_case(p["case"])
		lampes.append({"pos": pos, "rayon_px": rayon_px,
			"lumiere": Percep.lumiere_disque("plafonnier", pos, rayon_px * Percep.FRACTION_PLAFONNIER, _hauteur_lampe, true)})
	var pnj: Array = []
	for p: Dictionary in n["pnj"]:
		var profil := Format.profil_du_pnj(p)
		pnj.append({"case": p["case"], "pos": Nav.centre_de_la_case(p["case"]), "profil_nom": p["profil_nom"], "profil": profil,
			"classe": p["classe"], "ronde": p["ronde"], "zone": p["zone"]})
	return {
		"n": n, "carte": carte, "nav": Nav.depuis_carte(carte), "monde": Percep.monde_de_la_carte(carte),
		"depart": n["joueur"]["case"], "depart_pos": Nav.centre_de_la_case(n["joueur"]["case"]),
		"lampes": lampes, "pnj": pnj, "taille": Codec.get_grid_size(carte),
	}


func _lumieres(ctx: Dictionary) -> Array:
	var sortie: Array = []
	for l: Dictionary in ctx["lampes"]:
		sortie.append(l["lumiere"])
	return sortie


## Le modèle de vue dit-il qu'une lampe de la salle éclaire un corps debout en `pos` ?
func _eclaire_par_lampe(ctx: Dictionary, pos: Vector2) -> bool:
	for l: Dictionary in ctx["lampes"]:
		if Percep.eclaire(l["lumiere"], pos, _hauteur, ctx["monde"]):
			return true
	return false


## La flaque au sens LARGE : tout ce qui est à moins d'un rayon de texture (plus un corps) d'une lampe, murs ou non. Ce qu'on exige quand
## on dit « aucune lampe ne l'éclaire » : le modèle voit MOINS que la lumière, et une garde qui s'en contenterait serait trop douce.
func _sous_une_lampe(ctx: Dictionary, pos: Vector2) -> bool:
	for l: Dictionary in ctx["lampes"]:
		if pos.distance_to(l["pos"]) <= float(l["rayon_px"]) + Percep.RAYON_CORPS:
			return true
	return false


func _ligne_de_vue(ctx: Dictionary, a: Vector2, b: Vector2) -> bool:
	return Percep.ligne_de_vue(a, b, _hauteur, _hauteur, ctx["monde"])


## `observateur` voit-il un joueur debout en `cible`, compte tenu des `lumieres` ? Le modèle de vue du bot, avec son cadre d'écran.
func _voit(ctx: Dictionary, observateur: Vector2, cible: Vector2, lumieres: Array) -> bool:
	var bot := {"position": observateur, "visee": (cible - observateur).normalized(), "accroupi": false}
	var c := {"position": cible, "accroupi": false}
	return bool(Percep.voir(bot, c, lumieres, ctx["monde"])["vu"])


func _longueur(chemin: Array) -> float:
	var total := 0.0
	for k in range(1, chemin.size()):
		total += Nav.centre_de_la_case(chemin[k]).distance_to(Nav.centre_de_la_case(chemin[k - 1]))
	return total


## Les cases de mur BAS que traverse le segment `a → b` (échantillonné tous les 4 px).
func _murs_bas_traverses(ctx: Dictionary, a: Vector2, b: Vector2) -> Array[Vector2i]:
	var bas := {}
	for c in Codec.get_low_wall_cells(ctx["carte"]):
		bas[c] = true
	var sortie: Array[Vector2i] = []
	var d := a.distance_to(b)
	var pas := maxi(1, int(d / 4.0))
	for k in range(pas + 1):
		var c := Nav.case_du_monde(a.lerp(b, float(k) / float(pas)))
		if bas.has(c) and not sortie.has(c):
			sortie.append(c)
	return sortie


## Le flash d'un tir en `pos` : la lumière que voit un PNJ qui a une ligne de vue sur le tireur.
func _eclair(pos: Vector2) -> Dictionary:
	return Percep.lumiere_disque("eclair", pos, 32.0 * Percep.FRACTION_DISQUE, _hauteur)


func _cases_du_cote(ctx: Dictionary) -> Array[Vector2i]:
	return ctx["nav"].cases_atteignables(ctx["depart"])


# ---------------------------------------------------------------------------
# PARTOUT
# ---------------------------------------------------------------------------

func _partout() -> void:
	print("\n--- Partout : atteignable à pied, immobile, une pièce, aucun couloir d'une tuile ---")
	for i in _niveaux.size():
		var ctx := _ctx(i)
		var nav: Nav = ctx["nav"]
		var nom := "0.%d" % (i + 1)
		var taille: Vector2i = ctx["taille"]
		var cotes: Array = COTES_PAR_SALLE.get(i, [COTE_MIN, COTE_MAX])
		_check("%s : une salle de %d à %d cases de côté%s" % [nom, cotes[0], cotes[1], " (une mesure annoncée, pas celle d'une salle d'initiation)" if COTES_PAR_SALLE.has(i) else ""],
			taille.x >= cotes[0] and taille.y >= cotes[0] and taille.x <= cotes[1] and taille.y <= cotes[1], str(taille))
		_check("%s : et dans ce que le format sait écrire (au plus %d)" % [nom, Codec.MAX_GRID], taille.x <= Codec.MAX_GRID and taille.y <= Codec.MAX_GRID, str(taille))
		_check("%s : %d PNJ (la table de la ROADMAP)" % [nom, NB_PNJ[i]], (ctx["pnj"] as Array).size() == NB_PNJ[i], str((ctx["pnj"] as Array).size()))
		var atteignables := _cases_du_cote(ctx)
		var tous := true
		var detail := ""
		for p: Dictionary in ctx["pnj"]:
			var ok: bool = atteignables.has(p["case"]) and not nav.chemin(ctx["depart"], p["case"]).is_empty()
			tous = tous and ok
			if not ok:
				detail += " %s" % str(p["case"])
		_check("%s : chaque PNJ est atteignable à pied depuis le départ (chemins de NavigationBot)" % nom, tous, "inatteignables :" + detail)
		_check("%s : une seule pièce — toute case praticable est atteignable depuis le départ" % nom,
			atteignables.size() == nav.cases_praticables().size(), "%d sur %d" % [atteignables.size(), nav.cases_praticables().size()])
		var etranglees: Array[Vector2i] = []
		for y in taille.y:
			for x in taille.x:
				var c := Vector2i(x, y)
				if nav.est_libre(c) and not nav.est_praticable(c):
					etranglees.append(c)
		_check("%s : aucun couloir d'une tuile (le corps fait 36 px, la tuile 35)" % nom, etranglees.is_empty(), str(etranglees.slice(0, 6)))
		var sans_ronde := true
		for p: Dictionary in ctx["pnj"]:
			var immobile: bool = p["profil"].deplacement == Profil.Deplacement.IMMOBILE or p["profil_nom"] == "boss"
			sans_ronde = sans_ronde and immobile and (p["ronde"] as Array).is_empty() and (p["zone"] as Rect2i).size == Vector2i.ZERO
			if p["profil_nom"] != "boss":
				sans_ronde = sans_ronde and p["profil"].deplacement != Profil.Deplacement.RONDE
		_check("%s : aucune ronde (« non, pas de rondes » — Adrien) : tous les PNJ sont immobiles, hors le boss" % nom, sans_ronde)
		_check("%s : le joueur part d'une case praticable, qu'aucun PNJ n'occupe" % nom,
			nav.est_praticable(ctx["depart"]) and not _pnj_sur(ctx, ctx["depart"]))


func _pnj_sur(ctx: Dictionary, c: Vector2i) -> bool:
	for p: Dictionary in ctx["pnj"]:
		if p["case"] == c:
			return true
	return false


# ---------------------------------------------------------------------------
# 0.1 — Le premier pas
# ---------------------------------------------------------------------------

func _salle_1() -> void:
	print("\n--- 0.1 Le premier pas : se déplacer, viser, tirer ---")
	var ctx := _ctx(0)
	var p: Dictionary = ctx["pnj"][0]
	_check("un plafonnier, un PNJ sourd et aveugle, rien d'autre", (ctx["lampes"] as Array).size() == 1 and p["profil_nom"] == "immobile_sourd_aveugle")
	_check("le PNJ est dans la flaque (le modèle de vue : la lampe éclaire son corps)", _eclaire_par_lampe(ctx, p["pos"]))
	_check("… et en ligne de vue du départ", _ligne_de_vue(ctx, ctx["depart_pos"], p["pos"]))
	_check("… donc vu dès l'entrée par un joueur qui n'a pas même sa torche (le modèle de vue du joueur au départ)",
		_voit(ctx, ctx["depart_pos"], p["pos"], _lumieres(ctx)))
	# « Rien d'autre » : le seul mur est la ceinture, aucun muret.
	var taille: Vector2i = ctx["taille"]
	var interieurs := 0
	for c in Codec.get_wall_cells(ctx["carte"]):
		if c.x > 0 and c.y > 0 and c.x < taille.x - 1 and c.y < taille.y - 1:
			interieurs += 1
	_check("rien d'autre : aucun mur ni muret dans la salle", interieurs == 0 and Codec.get_low_wall_cells(ctx["carte"]).is_empty(), str(interieurs))
	var d_cases: float = ctx["depart_pos"].distance_to(p["pos"]) / 35.0
	print("    mesure : le PNJ est à %.1f cases du départ, à %.1f px de sa lampe" % [d_cases, p["pos"].distance_to(ctx["lampes"][0]["pos"])])


# ---------------------------------------------------------------------------
# 0.2 — La torche
# ---------------------------------------------------------------------------

func _salle_2() -> void:
	print("\n--- 0.2 La torche : la torche révèle ---")
	var ctx := _ctx(1)
	var p: Dictionary = ctx["pnj"][0]
	_check("un PNJ sourd et aveugle", p["profil_nom"] == "immobile_sourd_aveugle" and (ctx["pnj"] as Array).size() == 1)
	_check("le PNJ n'est sous AUCUN plafonnier (hors d'un rayon de texture plus un corps de chacun)", not _sous_une_lampe(ctx, p["pos"]))
	_check("… et le modèle de vue ne l'y voit pas non plus", not _eclaire_par_lampe(ctx, p["pos"]))
	_check("le départ ne le voit pas : la ligne de vue est coupée", not _ligne_de_vue(ctx, ctx["depart_pos"], p["pos"]))
	_check("… et rien ne le montre au départ (même sous les lampes de la salle)", not _voit(ctx, ctx["depart_pos"], p["pos"], _lumieres(ctx)))
	# Le pilier est la SEULE chose qui le cache : sans les murs de l'intérieur, la ligne est libre.
	var carte_nue: Dictionary = (ctx["carte"] as Dictionary).duplicate(true)
	var taille: Vector2i = ctx["taille"]
	var ceinture: Array[Vector2i] = []
	for y in taille.y:
		for x in taille.x:
			if x == 0 or y == 0 or x == taille.x - 1 or y == taille.y - 1:
				ceinture.append(Vector2i(x, y))
	carte_nue["walls"] = Codec.encode_runs(ceinture)
	var monde_nu: Dictionary = Percep.monde_de_la_carte(carte_nue)
	_check("c'est le pilier qui le cache : sans lui, la ligne de vue est libre",
		Percep.ligne_de_vue(ctx["depart_pos"], p["pos"], _hauteur, _hauteur, monde_nu))
	# On peut pourtant le trouver : une case d'où la torche l'atteint (à portée, en ligne de vue).
	var trouvable := false
	for c in _cases_du_cote(ctx):
		var pos := Nav.centre_de_la_case(c)
		if pos.distance_to(p["pos"]) <= _portee_torche - MARGE_PX and _ligne_de_vue(ctx, pos, p["pos"]):
			trouvable = true
			break
	_check("la torche peut l'atteindre : une case praticable à portée et en ligne de vue existe", trouvable)
	var plus_pres := INF
	for l: Dictionary in ctx["lampes"]:
		plus_pres = minf(plus_pres, p["pos"].distance_to(l["pos"]) - float(l["rayon_px"]))
	print("    mesure : la lampe la plus proche du PNJ le manque de %.0f px (plus un corps de %.0f)" % [plus_pres, Percep.RAYON_CORPS])


# ---------------------------------------------------------------------------
# 0.3 — Fouiller
# ---------------------------------------------------------------------------

func _salle_3() -> void:
	print("\n--- 0.3 Fouiller : chercher méthodiquement, recharger ---")
	var ctx := _ctx(2)
	var pnj: Array = ctx["pnj"]
	var arme := Arme.new()
	# Un tir qui touche à mi-chemin du centre et du bord : l'atténuation de `Bullet._hit_player` (floor de la moyenne).
	var degat_moyen := floorf(lerpf(arme.damage_center, arme.damage_edge, 0.5))
	var vie := 100.0
	var par_pnj_moyen := int(ceil(vie / degat_moyen))
	var par_pnj_parfait := int(ceil(vie / arme.damage_center))
	var tirs := par_pnj_moyen * pnj.size()
	_check("%d PNJ sourds et aveugles, une lampe" % pnj.size(), pnj.size() == 3 and (ctx["lampes"] as Array).size() == 1)
	_check("il faut plus de tirs que de balles dans un chargeur : %d PNJ × %d tirs (un coup de %.0f) = %d > %d" % [pnj.size(), par_pnj_moyen, degat_moyen, tirs, _chargeur],
		tirs > _chargeur)
	_check("… et même au mieux (tout au centre, %d tirs chacun), le chargeur ne laisse AUCUNE marge : %d ≥ %d" % [par_pnj_parfait, par_pnj_parfait * pnj.size(), _chargeur],
		par_pnj_parfait * pnj.size() >= _chargeur)
	var tous_sourds := true
	var dans_le_noir := true
	var hors_portee := true
	var min_ecart := INF
	for a in pnj.size():
		var p: Dictionary = pnj[a]
		tous_sourds = tous_sourds and p["profil_nom"] == "immobile_sourd_aveugle"
		dans_le_noir = dans_le_noir and not _sous_une_lampe(ctx, p["pos"]) and not _eclaire_par_lampe(ctx, p["pos"])
		hors_portee = hors_portee and p["pos"].distance_to(ctx["depart_pos"]) > _portee_torche + MARGE_PX
		for b in range(a + 1, pnj.size()):
			min_ecart = minf(min_ecart, p["pos"].distance_to(pnj[b]["pos"]))
	_check("tous sourds et aveugles", tous_sourds)
	_check("tous dans le noir : la lampe n'éclaire aucun d'eux — il faut les chercher", dans_le_noir)
	_check("aucun n'est à portée de torche du départ : on ne les trouve pas sans bouger", hors_portee)
	_check("dispersés : au moins 12 cases entre deux PNJ (mesuré : %.1f)" % (min_ecart / 35.0), min_ecart >= 12.0 * 35.0)
	var cache := 0
	for p: Dictionary in pnj:
		if not _ligne_de_vue(ctx, ctx["depart_pos"], p["pos"]) or p["pos"].distance_to(ctx["depart_pos"]) > _portee_torche:
			cache += 1
	_check("aucun n'est trouvable du départ : %d sur 3 hors de vue ou hors de portée" % cache, cache == 3)
	# Les recoins : chaque PNJ est isolé des deux autres par un mur.
	var isoles := 0
	for a in pnj.size():
		var vu_d_un_autre := false
		for b in pnj.size():
			if a != b and _ligne_de_vue(ctx, pnj[a]["pos"], pnj[b]["pos"]) and pnj[a]["pos"].distance_to(pnj[b]["pos"]) <= _portee_torche:
				vu_d_un_autre = true
		if not vu_d_un_autre:
			isoles += 1
	_check("chacun tient un recoin : aucun n'est en vue d'un autre à portée de torche (%d sur 3)" % isoles, isoles == 3)


# ---------------------------------------------------------------------------
# 0.4 — Les murs bas
# ---------------------------------------------------------------------------

func _salle_4() -> void:
	print("\n--- 0.4 Les murs bas : enjamber, s'accroupir derrière un muret ---")
	var ctx := _ctx(3)
	var nav: Nav = ctx["nav"]
	_check("deux PNJ sourds et aveugles, des murs bas, pas un mur plein dans la salle",
		(ctx["pnj"] as Array).size() == 2 and not Codec.get_low_wall_cells(ctx["carte"]).is_empty())
	var tous := true
	var detours := true
	var textes := ""
	for k in (ctx["pnj"] as Array).size():
		var p: Dictionary = ctx["pnj"][k]
		var traverses := _murs_bas_traverses(ctx, ctx["depart_pos"], p["pos"])
		var droit := _ligne_de_vue(ctx, ctx["depart_pos"], p["pos"])
		tous = tous and not traverses.is_empty() and Percep.segment_degage(ctx["depart_pos"], p["pos"], ctx["monde"])
		var chemin := nav.chemin(ctx["depart"], p["case"])
		var marche := _longueur(chemin)
		var vol: float = ctx["depart_pos"].distance_to(p["pos"])
		detours = detours and marche >= 1.5 * vol
		textes += "  PNJ %d : %d mur(s) bas sur la ligne, à pied %.0f px pour %.0f à vol d'oiseau (×%.1f)" % [k + 1, traverses.size(), marche, vol, marche / vol]
		_check("PNJ %d : un mur bas entre lui et le départ, et aucun mur plein (on le voit par-dessus)" % (k + 1),
			not traverses.is_empty() and Percep.segment_degage(ctx["depart_pos"], p["pos"], ctx["monde"]) and droit)
		_check("PNJ %d : le contourner à pied est au moins une fois et demie plus long que l'enjamber (le muret est un raccourci)" % (k + 1),
			marche >= 1.5 * vol, "×%.2f" % (marche / vol))
	print("   ", textes)
	_check("(récapitulatif) chaque PNJ est derrière un mur bas", tous)
	_check("(récapitulatif) chaque détour est long", detours)


# ---------------------------------------------------------------------------
# 0.5 — La fusée
# ---------------------------------------------------------------------------

## Tous les lancers possibles d'une fusée depuis une case du chemin : pour chaque case et chaque degré, la fusée vole `_portee_fusee` px en
## ligne droite (toujours la même distance : la vitesse de lancer est fixe) et se pose ; son halo éclaire quels PNJ, selon le modèle de vue ?
## Rend `[{case, degres, masque}]` — un bit par PNJ éclairé, dans l'ordre du chemin —, sans les lancers qui n'éclairent personne.
func _lancers_de_fusee(ctx: Dictionary, chemin: Array) -> Array:
	var nav: Nav = ctx["nav"]
	var sortie: Array = []
	for c: Vector2i in chemin:
		var origine := Nav.centre_de_la_case(c)
		for degres in range(0, 360, 1):
			var arrivee := origine + Vector2.from_angle(deg_to_rad(float(degres))) * _portee_fusee
			if not nav.est_libre(Nav.case_du_monde(arrivee)) or not Percep.segment_degage(origine, arrivee, ctx["monde"]):
				continue
			var halo := Percep.lumiere_disque("fusee", arrivee, _rayon_halo_fusee * Percep.FRACTION_DISQUE, 7.0)
			var masque := 0
			for k in (ctx["pnj"] as Array).size():
				if Percep.eclaire(halo, ctx["pnj"][k]["pos"], _hauteur, ctx["monde"]):
					masque |= 1 << k
			if masque != 0:
				sortie.append({"case": c, "degres": degres, "masque": masque})
	return sortie


func _n_fusees(n: int) -> String:
	return "impossible" if n < 0 else "%d fusée(s)" % n


func _bits(masque: int) -> int:
	var n := 0
	for k in 8:
		n += (masque >> k) & 1
	return n


## La fenêtre de visée d'un lancer qui éclaire AU MOINS `masque` : le plus long arc de degrés consécutifs, depuis une même case. C'est la
## tolérance du joueur au modèle de vue — conservateur : il tient un halo de 132 px là où le vrai en fait 220.
func _fenetre_de_visee(lancers: Array, masque: int) -> int:
	var meilleure := 0
	var courante := 0
	var case_courante := Vector2i(-1, -1)
	var dernier := -2
	for l: Dictionary in lancers:
		if (int(l["masque"]) & masque) != masque:
			continue
		if l["case"] == case_courante and int(l["degres"]) == dernier + 1:
			courante += 1
		else:
			courante = 1
			case_courante = l["case"]
		dernier = int(l["degres"])
		meilleure = maxi(meilleure, courante)
	return meilleure


## Les PNJ qu'on trouve À LA TORCHE en allant tuer ceux de `masque` : tout PNJ à moins de `CHAINE_CASES` d'un PNJ déjà trouvé, de proche en
## proche. Une dizaine de cases, parce qu'on tue de près (3 cases) et que la torche porte 13,4 : de là, le suivant est au bord du faisceau.
func _fermeture_a_la_torche(ctx: Dictionary, masque: int) -> int:
	var pnj: Array = ctx["pnj"]
	var trouve := masque
	var change := true
	while change:
		change = false
		for k in pnj.size():
			if (trouve >> k) & 1:
				continue
			for j in pnj.size():
				if (trouve >> j) & 1 and pnj[k]["pos"].distance_to(pnj[j]["pos"]) <= CHAINE_CASES * 35.0:
					trouve |= 1 << k
					change = true
					break
	return trouve


## Le moins de fusées qui montrent tous les PNJ, parmi les lancers possibles (au plus 3) ; `avec_torche` ajoute ce que la torche trouve de
## proche en proche après chaque fusée. -1 : impossible.
func _fusees_necessaires(ctx: Dictionary, lancers: Array, avec_torche: bool) -> int:
	var tout := (1 << (ctx["pnj"] as Array).size()) - 1
	var masques := {}
	for l: Dictionary in lancers:
		masques[int(l["masque"])] = true
	var liste: Array = masques.keys()
	var reunions: Array = [0]
	for n in range(1, 4):
		var suite := {}
		for r: int in reunions:
			for m: int in liste:
				suite[r | m] = true
		reunions = suite.keys()
		for r: int in reunions:
			if (_fermeture_a_la_torche(ctx, r) if avec_torche else r) == tout:
				return n
	return -1


## L'attente de qui voudrait la seconde fusée : une période de recharge, moins ce qu'il a marché entre les deux lancers. Le parcours est
## celui qui ATTEND LE PLUS : lancer d'une case du chemin sur le couple, marcher jusqu'au PNJ le plus proche, puis jusqu'à la case du chemin
## d'où l'on montre le reste — le plus court de chaque marche, sans compter ni les tirs ni la visée. Rend `{attente, marche}` en secondes.
func _attente_au_pire(ctx: Dictionary, lancers: Array, masque_couple: int) -> Dictionary:
	var nav: Nav = ctx["nav"]
	var pnj: Array = ctx["pnj"]
	var reste := ((1 << pnj.size()) - 1) & ~masque_couple
	var cases_du_couple: Array[Vector2i] = []
	var cases_du_reste: Array[Vector2i] = []
	for l: Dictionary in lancers:
		if (int(l["masque"]) & masque_couple) == masque_couple and not cases_du_couple.has(l["case"]):
			cases_du_couple.append(l["case"])
		if (int(l["masque"]) & reste) == reste and not cases_du_reste.has(l["case"]):
			cases_du_reste.append(l["case"])
	var meilleur := INF
	for k in pnj.size():
		if not (masque_couple >> k) & 1:
			continue
		var aller := INF
		for c in cases_du_couple:
			aller = minf(aller, _longueur(nav.chemin(c, pnj[k]["case"])))
		var retour := INF
		for c in cases_du_reste:
			retour = minf(retour, _longueur(nav.chemin(pnj[k]["case"], c)))
		meilleur = minf(meilleur, aller + retour)
	var marche := meilleur / _vitesse_joueur if meilleur < INF else 0.0
	return {"attente": maxf(0.0, _periode_fusee - marche), "marche": marche}


func _salle_5() -> void:
	print("\n--- 0.5 La fusée : éclairer loin ---")
	var ctx := _ctx(4)
	var nav: Nav = ctx["nav"]
	var taille: Vector2i = ctx["taille"]
	var pnj: Array = ctx["pnj"]
	_check("trois PNJ sourds et aveugles, AUCUN plafonnier", pnj.size() == 3 and (ctx["lampes"] as Array).is_empty())
	var centre := nav.case_praticable_proche(Vector2i(taille.x / 2, taille.y / 2))
	var chemin := nav.chemin(ctx["depart"], centre)
	_check("le chemin le plus court du départ au centre %s existe (%d cases)" % [str(centre), chemin.size()], not chemin.is_empty())
	# La marge se compte centre à centre, de la case du chemin au PNJ. Le corps du PNJ (18 px) et la demi-case du joueur (17) en rognent 35 :
	# la marge réelle est la moitié. Elle ne peut pas monter beaucoup : une fusée vole 450 px et son halo de modèle en éclaire 132, soit 582 px
	# de portée de lancer contre 468 de torche — 114 px au mieux, et seulement d'un lancer exact. À 70, le couple garde 28 px de tolérance.
	var plus_pres := INF
	for p: Dictionary in pnj:
		for c in chemin:
			plus_pres = minf(plus_pres, Nav.centre_de_la_case(c).distance_to(p["pos"]))
	_check("aucun PNJ n'est à portée de torche d'une case du chemin, avec %.0f px de marge (%.0f + %.0f) : le plus proche en est à %.0f px"
		% [MARGE_FUSEE_PX, _portee_torche, MARGE_FUSEE_PX, plus_pres], plus_pres >= _portee_torche + MARGE_FUSEE_PX)
	# Répartis : ni collés, ni dans un même coin.
	var ecart_min := INF
	var ecart_max := 0.0
	for i in pnj.size():
		for j in range(i + 1, pnj.size()):
			var d: float = pnj[i]["pos"].distance_to(pnj[j]["pos"]) / 35.0
			ecart_min = minf(ecart_min, d)
			ecart_max = maxf(ecart_max, d)
	_check("répartis : deux PNJ ne sont jamais à moins de %.0f cases l'un de l'autre (le plus serré : %.1f)" % [ECART_MIN_CASES, ecart_min], ecart_min >= ECART_MIN_CASES)
	_check("… et les deux plus éloignés le sont de %.0f cases au moins (%.1f) : ce n'est pas un groupe" % [ECART_MAX_MIN_CASES, ecart_max], ecart_max >= ECART_MAX_MIN_CASES)
	var coins := [Vector2(1, 1), Vector2(taille.x - 2, 1), Vector2(1, taille.y - 2), Vector2(taille.x - 2, taille.y - 2)]
	var coin_plein := false
	for coin: Vector2 in coins:
		var n_proches := 0
		for p: Dictionary in pnj:
			if (Vector2(p["case"]) - coin).length() <= 10.0:
				n_proches += 1
		coin_plein = coin_plein or n_proches == pnj.size()
	_check("aucun coin de la salle ne tient les trois PNJ à moins de 10 cases (le défaut de la salle d'avant : un angle)", not coin_plein)
	# Les fusées.
	var lancers := _lancers_de_fusee(ctx, chemin)
	for k in pnj.size():
		var fenetre := _fenetre_de_visee(lancers, 1 << k)
		_check("le PNJ %d est montré par une fusée lancée d'une case du chemin (fenêtre de visée : %d°)" % [k + 1, fenetre], fenetre > 0)
	var meilleur_masque := 0
	for l: Dictionary in lancers:
		if _bits(int(l["masque"])) > _bits(meilleur_masque):
			meilleur_masque = int(l["masque"])
	var fenetre_couple := _fenetre_de_visee(lancers, meilleur_masque)
	_check("une seule fusée en montre %d à la fois (fenêtre de visée : %d°, au moins %d° exigés)" % [_bits(meilleur_masque), fenetre_couple, FENETRE_VISEE_MIN],
		_bits(meilleur_masque) >= 2 and fenetre_couple >= FENETRE_VISEE_MIN)
	var strict := _fusees_necessaires(ctx, lancers, false)
	var a_la_torche := _fusees_necessaires(ctx, lancers, true)
	_check("aucune fusée ne les montre tous les trois : il en faut %s pour tous, si la torche ne trouvait rien (répartis, pas groupés)" % _n_fusees(strict), strict >= 2)
	# La réserve et la recharge : le Parasite part avec `_stock_fusees` fusée(s) et en regagne une par `_periode_fusee` s.
	_check("la salle ne demande jamais plus d'une recharge : %s pour une réserve de %d" % [_n_fusees(strict), _stock_fusees], strict >= 1 and strict <= _stock_fusees + 1)
	_check("… et ne FAIT PAS attendre : la torche trouvant de proche en proche (au plus %d cases d'un PNJ trouvé), %s suffisent — la réserve de départ n'est pas dépassée"
		% [CHAINE_CASES, _n_fusees(a_la_torche)], a_la_torche >= 1 and a_la_torche <= _stock_fusees)
	var attente := _attente_au_pire(ctx, lancers, meilleur_masque)
	_check("qui voudrait pourtant la seconde fusée attend %.0f s au pire (%.0f s de recharge moins %.1f s de marche entre les deux lancers), jamais plus d'une période"
		% [attente["attente"], _periode_fusee, attente["marche"]], float(attente["attente"]) <= _periode_fusee)
	print("    mesure : posée, une fusée éclaire %.0f s (plein feu %.0f s, braise %.0f s) ; à l'allumage son halo porte 1 s aussi loin que la torche"
		% [_duree_halo_fusee, FuseeMod.duree_plein_feu, FuseeMod.duree_braise])


# ---------------------------------------------------------------------------
# 0.6 — Il regarde
# ---------------------------------------------------------------------------

func _salle_6() -> void:
	print("\n--- 0.6 Il regarde : la torche trahit ---")
	var ctx := _ctx(5)
	var nav: Nav = ctx["nav"]
	var p: Dictionary = ctx["pnj"][0]
	_check("un PNJ qui VOIT, aux réflexes très lents, et deux plafonniers", p["profil_nom"] == "immobile_voit_tres_lent" and p["profil"].voit
		and (ctx["lampes"] as Array).size() == 2)
	_check("le PNJ est éclairé par une lampe : le joueur le voit sans torche", _eclaire_par_lampe(ctx, p["pos"]))
	var chemin := nav.chemin(ctx["depart"], p["case"])
	var traverse: Array[bool] = [false, false]
	var vu_en_chemin := false
	for c in chemin:
		var pos := Nav.centre_de_la_case(c)
		for k in 2:
			if Percep.eclaire(ctx["lampes"][k]["lumiere"], pos, _hauteur, ctx["monde"]):
				traverse[k] = true
				if c != p["case"] and _voit(ctx, p["pos"], pos, _lumieres(ctx)):
					vu_en_chemin = true
	_check("le plus court chemin passe dans les DEUX flaques", traverse[0] and traverse[1], str(traverse))
	_check("… et le PNJ voit le joueur qui y passe (torche éteinte : la lampe suffit à le trahir)", vu_en_chemin)
	# Le détour : des cases hors de toute flaque, du départ jusqu'à une case d'où l'on voit le PNJ.
	var libre := {}
	for c in nav.cases_praticables():
		if not _sous_une_lampe(ctx, Nav.centre_de_la_case(c)):
			libre[c] = true
	var file: Array[Vector2i] = [ctx["depart"]]
	var vues := {ctx["depart"]: 0}
	var arrivee := Vector2i(-1, -1)
	var but_distance := _portee_torche - 3.0 * MARGE_PX
	var tete := 0
	while tete < file.size() and arrivee.x < 0:
		var c: Vector2i = file[tete]
		tete += 1
		var pos := Nav.centre_de_la_case(c)
		if pos.distance_to(p["pos"]) <= but_distance and _ligne_de_vue(ctx, pos, p["pos"]):
			arrivee = c
			break
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
			var s := c + d
			if libre.has(s) and not vues.has(s):
				vues[s] = int(vues[c]) + 1
				file.append(s)
	_check("un détour existe qui évite les flaques : une case dans le noir, à moins de %.0f px du PNJ et en ligne de vue (%s)" % [but_distance, str(arrivee)], arrivee.x >= 0)
	if arrivee.x >= 0:
		var pos_arrivee := Nav.centre_de_la_case(arrivee)
		_check("… où le PNJ NE voit PAS le joueur (aucune lumière sur lui : torche éteinte), alors qu'il le voit à la lampe", not _voit(ctx, p["pos"], pos_arrivee, _lumieres(ctx)))
		_check("… et où le joueur voit le PNJ, éclairé par sa lampe", _eclaire_par_lampe(ctx, p["pos"]) and _ligne_de_vue(ctx, pos_arrivee, p["pos"]))
		_check("… et le détour n'est pas un calvaire : %d cases contre %d en ligne droite" % [int(vues[arrivee]) + 1, chemin.size()], int(vues[arrivee]) + 1 <= int(2.0 * chemin.size()))
	# La torche trahit aussi : sa lampe se voit par une ligne de vue, flaque ou pas. Au bout du détour, torche éteinte le PNJ ne voit rien ;
	# torche allumée il voit le joueur — c'est la raison de s'approcher éteint.
	if arrivee.x >= 0:
		var pos_arrivee := Nav.centre_de_la_case(arrivee)
		var lampe_torche := Percep.lumiere_lampe("lampe", pos_arrivee, _hauteur)
		_check("la torche allumée trahit le joueur au bout du détour (le PNJ le voit à sa lampe), éteinte non",
			_voit(ctx, p["pos"], pos_arrivee, [lampe_torche]) and not _voit(ctx, p["pos"], pos_arrivee, []))


# ---------------------------------------------------------------------------
# 0.7 — L'éclair
# ---------------------------------------------------------------------------

func _salle_7() -> void:
	print("\n--- 0.7 L'éclair : le tir trahit ---")
	var ctx := _ctx(6)
	var nav: Nav = ctx["nav"]
	var pnj: Array = ctx["pnj"]
	var tous_voient := true
	var tous_eclaires := true
	for p: Dictionary in pnj:
		tous_voient = tous_voient and p["profil_nom"] == "immobile_voit_lent" and p["profil"].voit
		tous_eclaires = tous_eclaires and _eclaire_par_lampe(ctx, p["pos"])
	_check("trois PNJ qui voient et tirent, aux réflexes lents", pnj.size() == 3 and tous_voient)
	_check("chacun est éclairé par sa lampe : on les voit sans torche, donc sans se trahir", tous_eclaires)
	# La salle est en L : le rectangle englobant porte un grand bloc de mur, et les deux branches sont plus longues que larges.
	var taille: Vector2i = ctx["taille"]
	var sol := nav.cases_praticables().size()
	_check("une salle en L : le sol occupe moins de 70 %% du rectangle (%d cases sur %d)" % [sol, (taille.x - 2) * (taille.y - 2)], float(sol) < 0.7 * float((taille.x - 2) * (taille.y - 2)))
	var depart: Vector2 = ctx["depart_pos"]
	var nb_visibles := 0
	for p: Dictionary in pnj:
		if _ligne_de_vue(ctx, depart, p["pos"]):
			nb_visibles += 1
	_check("du départ on n'en voit pas trois à la fois (le coude en cache : %d en ligne de vue)" % nb_visibles, nb_visibles < 3)
	var atteignables := _cases_du_cote(ctx)
	for a in pnj.size():
		var x: Dictionary = pnj[a]
		var meilleur := Vector2i(-1, -1)
		var abri := Vector2i(-1, -1)
		for c in atteignables:
			var pos := Nav.centre_de_la_case(c)
			if _sous_une_lampe(ctx, pos) or pos.distance_to(x["pos"]) > _portee_torche - MARGE_PX or not _ligne_de_vue(ctx, pos, x["pos"]):
				continue
			var vu_par_un_autre := false
			for b in pnj.size():
				if b != a and _voit(ctx, pnj[b]["pos"], pos, [_eclair(pos)]):
					vu_par_un_autre = true
			if not vu_par_un_autre:
				continue
			# Un abri à six cases au plus, que ni l'un ni l'autre des PNJ restants ne regarde.
			for r in atteignables:
				var pr := Nav.centre_de_la_case(r)
				if pr.distance_to(pos) > 6.0 * 35.0 or _sous_une_lampe(ctx, pr):
					continue
				var cache := true
				for b in pnj.size():
					if b != a and _ligne_de_vue(ctx, pnj[b]["pos"], pr):
						cache = false
				if cache:
					abri = r
					break
			if abri.x >= 0:
				meilleur = c
				break
		_check("PNJ %d : une case d'où on le touche, où l'éclair du tir est vu d'un autre PNJ, et à six cases au plus un abri hors de leur vue (%s → %s)" % [a + 1, str(meilleur), str(abri)],
			meilleur.x >= 0 and abri.x >= 0)


# ---------------------------------------------------------------------------
# 0.8 — Il écoute
# ---------------------------------------------------------------------------

func _salle_8() -> void:
	print("\n--- 0.8 Il écoute : s'accroupir, avancer lentement ---")
	var ctx := _ctx(7)
	var nav: Nav = ctx["nav"]
	_check("aucun plafonnier : le sol nu", (ctx["lampes"] as Array).is_empty())
	var taille: Vector2i = ctx["taille"]
	var interieurs := 0
	for c in Codec.get_wall_cells(ctx["carte"]):
		if c.x > 0 and c.y > 0 and c.x < taille.x - 1 and c.y < taille.y - 1:
			interieurs += 1
	_check("sol nu : pas un mur, pas un muret à l'intérieur (rien n'étouffe les pas)", interieurs == 0 and Codec.get_low_wall_cells(ctx["carte"]).is_empty())
	var ouie := true
	var loin := true
	var longs := true
	for p: Dictionary in ctx["pnj"]:
		ouie = ouie and p["profil_nom"] == "immobile_entend_lent" and p["profil"].entend and not p["profil"].voit and p["profil"].tire
		loin = loin and p["pos"].distance_to(ctx["depart_pos"]) > _portee_torche + MARGE_PX
		longs = longs and nav.chemin(ctx["depart"], p["case"]).size() >= 12
	_check("deux PNJ qui n'ENTENDENT que (ils ne voient pas) et tirent, réflexes lents", (ctx["pnj"] as Array).size() == 2 and ouie)
	_check("loin du départ : plus que la portée de la torche (on les trouve à l'oreille avant de les voir), et douze cases de marche au moins", loin and longs)


# ---------------------------------------------------------------------------
# 0.9 — La salle pleine
# ---------------------------------------------------------------------------

func _salle_9() -> void:
	print("\n--- 0.9 La salle pleine : tout ce qui précède, à la fois ---")
	var ctx := _ctx(8)
	var sourds := 0
	var voit := 0
	var entend := 0
	var les_deux := 0
	for p: Dictionary in ctx["pnj"]:
		var v: bool = p["profil"].voit
		var e: bool = p["profil"].entend
		if not v and not e:
			sourds += 1
		elif v and e:
			les_deux += 1
		elif v:
			voit += 1
		else:
			entend += 1
	_check("six PNJ : 2 sourds et aveugles, 2 qui voient, 1 qui entend, 1 qui voit et entend (mesuré : %d / %d / %d / %d)" % [sourds, voit, entend, les_deux],
		(ctx["pnj"] as Array).size() == 6 and sourds == 2 and voit == 2 and entend == 1 and les_deux == 1)
	_check("au moins un PNJ de CHAQUE sorte", sourds >= 1 and voit >= 1 and entend >= 1 and les_deux >= 1)
	_check("des plafonniers (3), des murets, des murs pleins dans la salle",
		(ctx["lampes"] as Array).size() >= 2 and not Codec.get_low_wall_cells(ctx["carte"]).is_empty()
		and Codec.get_wall_cells(ctx["carte"]).size() > 4 * 23)
	var eclaires := 0
	var noirs_caches := 0
	var derriere_un_muret := 0
	for p: Dictionary in ctx["pnj"]:
		if _eclaire_par_lampe(ctx, p["pos"]):
			eclaires += 1
		elif not _ligne_de_vue(ctx, ctx["depart_pos"], p["pos"]) or p["pos"].distance_to(ctx["depart_pos"]) > _portee_torche:
			noirs_caches += 1
		if not _murs_bas_traverses(ctx, ctx["depart_pos"], p["pos"]).is_empty():
			derriere_un_muret += 1
	_check("des PNJ sous la lumière (%d), des recoins noirs hors d'atteinte du départ (%d), un PNJ derrière un muret (%d)" % [eclaires, noirs_caches, derriere_un_muret],
		eclaires >= 2 and noirs_caches >= 2 and derriere_un_muret >= 1)
	# Les recoins noirs : au moins un PNJ sourd et un qui entend y vivent (la leçon 0.2 et la 0.8 en même temps).
	var recoin_qui_entend := false
	for p: Dictionary in ctx["pnj"]:
		if p["profil"].entend and not p["profil"].voit and not _eclaire_par_lampe(ctx, p["pos"]) and (not _ligne_de_vue(ctx, ctx["depart_pos"], p["pos"]) or p["pos"].distance_to(ctx["depart_pos"]) > _portee_torche):
			recoin_qui_entend = true
	_check("celui qui n'entend que tient un recoin noir", recoin_qui_entend)


# ---------------------------------------------------------------------------
# 0.10 — Le Parasite
# ---------------------------------------------------------------------------

func _salle_10() -> void:
	print("\n--- 0.10 Le Parasite : le duel en miroir ---")
	var ctx := _ctx(9)
	var n: Dictionary = ctx["n"]
	var p: Dictionary = ctx["pnj"][0]
	_check("un seul PNJ, au profil « boss » et à la classe du chapitre (le Parasite)", (ctx["pnj"] as Array).size() == 1 and p["profil_nom"] == "boss" and p["classe"] == "pistolet" and bool(n["boss"]))
	_check("deux plafonniers", (ctx["lampes"] as Array).size() == 2)
	var taille: Vector2i = ctx["taille"]
	var miroir_x := func(c: Vector2i) -> Vector2i: return Vector2i(taille.x - 1 - c.x, c.y)
	var murs := {}
	for c in Codec.get_wall_cells(ctx["carte"]):
		murs[c] = true
	var bas := {}
	for c in Codec.get_low_wall_cells(ctx["carte"]):
		bas[c] = true
	var sym := true
	for c: Vector2i in murs:
		sym = sym and murs.has(miroir_x.call(c))
	for c: Vector2i in bas:
		sym = sym and bas.has(miroir_x.call(c))
	_check("l'arène est symétrique d'est en ouest (murs, murets)", sym)
	_check("le joueur et le boss se tiennent en miroir", miroir_x.call(ctx["depart"]) == p["case"])
	var l0: Vector2i = Nav.case_du_monde(ctx["lampes"][0]["pos"])
	var l1: Vector2i = Nav.case_du_monde(ctx["lampes"][1]["pos"])
	_check("les deux plafonniers se font face (la lampe de l'un est celle de l'autre vue dans un miroir)", miroir_x.call(l0) == l1)
	_check("les deux flaques se tiennent à part : la lampe d'un camp n'éclaire pas déjà l'autre",
		float((ctx["lampes"][0]["pos"] as Vector2).distance_to(ctx["lampes"][1]["pos"])) > float(ctx["lampes"][0]["rayon_px"]) + float(ctx["lampes"][1]["rayon_px"]))
	_check("le boss et le joueur ne se voient pas d'emblée sans lumière : ni l'un ni l'autre n'est sous une lampe",
		not _sous_une_lampe(ctx, ctx["depart_pos"]) and not _sous_une_lampe(ctx, p["pos"]))
