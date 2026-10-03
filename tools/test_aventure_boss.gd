## La garde de S9b — chantier SOLO : l'intégration du moteur de l'aventure (S6) et du bot équipé (S9). Le vrai jeu monté, à pas d'image fixe.
##
## S6 et S9 ont été écrits en parallèle, chacun juste de son côté, et se sont croisés à trois endroits que cette suite garde :
##
##   • LES RÉSERVES DES PNJ : fusées, gadget, batterie et recharge d'une minute étaient indexés par `player_id`, que tous les PNJ partagent
##     (1) — donc la réserve de J2, semée sur la classe de J2. Chaque PNJ a maintenant la sienne (`GameState.inscrire_un_pnj`), semée sur SA
##     classe, remise à neuf quand la salle recommence ; le bot d'entraînement, lui, rééquipe à sa réapparition la classe qu'il porte ;
##   • L'ÉBLOUISSEMENT : la torche d'un PNJ éblouit le joueur, celle du joueur éblouit un PNJ (et leurs éclairs de tir), les PNJ ne s'éblouissent pas
##     entre eux ; et un bot ébloui voit MOINS — jamais plus — que le même bot aux yeux ouverts ;
##   • LES BOSS PAR CLASSE : `ProfilBot.boss(classe)` règle ce que l'arme demande, jamais ce que le bot perçoit (la garde courte du banc, `test_banc_bot`,
##     en vérifie les bornes ; celle-ci vérifie que le jeu monté le sert à SA classe).
##
## ⚠️ **Se lance à pas d'image fixe** (`--fixed-fps 60`) : les délais de la partie sont comptés en pas de physique.
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_aventure_boss.gd
extends SceneTree

const Format := preload("res://aventure_format.gd")
const Progression := preload("res://aventure_progression.gd")
const Percep := preload("res://perception_bot.gd")
const Brouillage_ := preload("res://brouillage.gd")

const ESSAI := "res://tools/aventure_essai"
const SOLO_DE_LA_SUITE := "user://test_aventure_boss_solo.cfg"

const PH_CARTON := 0
const PH_JEU := 1

var _failures := 0
var _verifications := 0

var main: Node = null
var ui: Node = null
var prog: AventureProgression = null
var chapitre: Dictionary = {}
var brut: Dictionary = {}


## Un fournisseur d'entrées dont la seule commande est la torche : le joueur « braque » sa lampe sans bouger.
class Torche extends InputProvider:
	## Où le joueur regarde : une consigne nulle ferait tourner le corps vers 0 rad (l'est), loin du PNJ qu'il éblouit.
	var visee := Vector2.LEFT

	func get_aim_direction(_player_global_pos: Vector2) -> Vector2:
		return visee

	func is_flashlight_pressed() -> bool:
		return true


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
	print("=== S9b : L'INTÉGRATION DU MOTEUR DE L'AVENTURE ET DU BOT ÉQUIPÉ ===")
	await process_frame
	var horloge_fixe := await _horloge_fixe()
	_check("l'horloge est fixe (--fixed-fps 60) : une image = un pas de physique", horloge_fixe,
		"lancer avec --fixed-fps 60 : sans lui les délais de la partie ne mesureraient rien")
	if not horloge_fixe:
		_sortir()
		return
	_effacer(SOLO_DE_LA_SUITE)
	root.get_node("GameSettings").mode_iso = false
	Format.racine = ESSAI
	Format.niveaux_attendus = 0
	Format.oublier_le_cache()
	chapitre = Format.charger_chapitre(ESSAI.path_join("chapitre_00"), 0)
	brut = Format.lire_chapitre(ESSAI.path_join("chapitre_00"))
	_check("le chapitre d'essai se charge", not chapitre.is_empty() and not brut.is_empty())
	if chapitre.is_empty() or brut.is_empty():
		_sortir()
		return
	prog = Progression.new(SOLO_DE_LA_SUITE)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	ui = main.ui
	ui.aventure_progression = prog
	main.archiver_les_matchs = false

	await _chacun_sa_reserve()
	await _un_boss_a_sa_classe()
	await _le_boss_est_regle_a_sa_classe()
	await _le_bot_d_entrainement_garde_sa_classe()
	await _l_eblouissement_des_pnj()
	await _le_bot_ebloui_voit_moins()

	_effacer(SOLO_DE_LA_SUITE)
	Format.racine = "res://assets/solo"
	Format.niveaux_attendus = Format.NIVEAUX_PAR_CHAPITRE
	Format.oublier_le_cache()
	main.queue_free()
	await _images(2)
	_sortir()


# ---------------------------------------------------------------------------
# LES SALLES DE LA SUITE
# ---------------------------------------------------------------------------

## Un chapitre d'UNE salle : la salle 1 de l'essai (16 × 16, un plafonnier en (12, 8)), dont on remplace les PNJ. Un niveau fabriqué par la suite n'est pas
## passé au validateur de CHAPITRE (il refuserait un boss d'une autre classe que celle du chapitre) mais bien à celui du NIVEAU.
func _chapitre_de(pnj: Array, joueur: Dictionary = {}, boss: bool = false, niveau_depart: int = 0) -> Dictionary:
	var niveau: Dictionary = (brut["niveaux"][niveau_depart] as Dictionary).duplicate(true)
	niveau["pnj"] = pnj
	niveau["boss"] = boss
	if not joueur.is_empty():
		niveau["joueur"] = joueur
	var defauts := Format.valider_niveau(niveau)
	_check("(le niveau fabriqué par la suite est lui-même valide)", defauts.is_empty(), str(defauts))
	var c := chapitre.duplicate(true)
	c["niveaux"] = [Format.preparer_niveau(niveau)]
	c["niveaux"][0]["fichier"] = "fabrique.json"
	return c


func _demarrer(c: Dictionary) -> Node:
	main.graine_du_bot = 4242
	main.demarrer_l_aventure(c, 0, "pistolet", prog)
	await _images(3)
	var partie: Node = main.aventure
	await _jusqua(func() -> bool: return partie.phase == PH_JEU, 300)
	return partie


func _quitter() -> void:
	main._on_main_menu_requested()
	await _images(3)


func _classe_de(n: Object) -> String:
	if n == null or n.get_script() == null:
		return ""
	return String((n.get_script() as Script).get_global_name())


func _gadgets_du_jeu() -> Array:
	var sortie: Array = []
	for g in get_nodes_in_group("gadgets"):
		if is_instance_valid(g) and not g.is_queued_for_deletion():
			sortie.append(g)
	return sortie


# ---------------------------------------------------------------------------
# CHACUN SA RÉSERVE
# ---------------------------------------------------------------------------

func _chacun_sa_reserve() -> void:
	print("\n--- Deux PNJ, deux réserves : chacun la sienne, semée sur SA classe ---")
	var c := _chapitre_de([
		{"case": [4, 4], "orientation": 0, "profil": "immobile_sourd_aveugle", "classe": "spectre"},
		{"case": [4, 12], "orientation": 0, "profil": "immobile_sourd_aveugle", "classe": "pompe"},
	])
	var partie: Node = await _demarrer(c)
	var a: Node = partie.pnj[0]
	var b: Node = partie.pnj[1]
	var sa: int = a.slot_de_reserve()
	var sb: int = b.slot_de_reserve()
	_check("chaque PNJ a sa place de réserve, distincte de celles de J1 et J2 (2 et 3)", sa == 2 and sb == 3 and a.player_id == 1 and b.player_id == 1,
		"%d %d" % [sa, sb])
	_check("… J1 et J2 gardent les leurs (0 et 1) : le duel n'a pas changé", main.p1.slot_de_reserve() == 0 and main.p2.slot_de_reserve() == 1)
	_check("le Spectre PNJ n'a AUCUNE fusée (« la seule classe qui n'éclaire jamais »), le Terrassier PNJ en a trois",
		main.fusees_restantes(sa) == 0 and main.fusees_restantes(sb) == 3, "%d %d" % [main.fusees_restantes(sa), main.fusees_restantes(sb)])
	_check("… alors que J2 (le Parasite, caché) garde la sienne : une (la réserve d'un PNJ n'est pas celle de J2)", main.fusees_restantes(1) == 1,
		str(main.fusees_restantes(1)))
	_check("`fusee_disponible` suit la place : non pour le Spectre, oui pour le Terrassier", not main.fusee_disponible(sa) and main.fusee_disponible(sb))
	# Le Terrassier lance : sa réserve baisse, celle de J2 et celle de l'autre PNJ ne bougent pas.
	main.spawn_fusee(b, b.global_position + Vector2(30.0, 0.0), 0.0)
	await _images(2)
	_check("une fusée lancée par un PNJ entame SA réserve (3 → 2), pas celle de J2 ni celle de l'autre PNJ",
		main.fusees_restantes(sb) == 2 and main.fusees_restantes(1) == 1 and main.fusees_restantes(sa) == 0,
		"%d %d %d" % [main.fusees_restantes(sb), main.fusees_restantes(1), main.fusees_restantes(sa)])
	# Et un PNJ sans fusée n'en lance pas, même si J2 en a une.
	var avant_spectre: int = _fusees_dans_l_arene()
	main.spawn_fusee(a, a.global_position + Vector2(30.0, 0.0), 0.0)
	await _images(2)
	_check("le Spectre PNJ ne lance rien (sa réserve est vide) : aucune fusée de plus dans l'arène", _fusees_dans_l_arene() == avant_spectre)
	# Les gadgets : chacun pose le SIEN (la suie n'est pas le grésillement de J2), et ils coexistent.
	main.spawn_gadget(b, b.global_position + Vector2(10.0, 0.0), 0.0)
	await _images(2)
	var gadgets := _gadgets_du_jeu()
	_check("le Terrassier PNJ pose SA poussière (pas le grésillement de J2) : un gadget, de la classe du poseur",
		gadgets.size() == 1 and String(gadgets[0].slug) == "poussiere", str(gadgets.map(func(g): return String(g.slug))))
	# `classe_du_poseur` ne vient que de la CLASSE lue chez le poseur : le slug, lui, se déduit d'ailleurs,
	# et une classe lue chez J2 (le Parasite) passerait la ligne d'avant sans que rien ne rougisse.
	_check("… et la classe que le gadget emporte est celle de son poseur (le Terrassier), pas celle de J2",
		gadgets.size() == 1 and gadgets[0].classe_du_poseur == b.current_weapon and gadgets[0].classe_du_poseur != main.p2.current_weapon)
	_check("… il porte la place de son poseur (3) et le rôle d'adversaire (`poseur_id` 1, qui règle couches, ombres et sons)",
		gadgets.size() == 1 and gadgets[0].slot_reserve == 3 and gadgets[0].poseur_id == 1)
	_check("… SA recharge d'une minute court (place 3), pas celle de J2 ni celle de l'autre PNJ",
		main.attente_gadget(sb) > 50.0 and main.attente_gadget(1) == 0.0 and main.attente_gadget(sa) == 0.0,
		"%s %s %s" % [main.attente_gadget(sb), main.attente_gadget(1), main.attente_gadget(sa)])
	_check("… `gadget_disponible` suit la place : non pour le Terrassier (en recharge), oui pour J2 (rien posé) ; le Spectre PNJ a sa voile",
		not main.gadget_disponible(sb) and main.gadget_disponible(1) and main.gadget_disponible(sa))
	main.spawn_gadget(a, a.global_position + Vector2(10.0, 0.0), 0.0)
	await _images(2)
	var deux := _gadgets_du_jeu()
	var slugs: Array = deux.map(func(g): return String(g.slug))
	slugs.sort()
	_check("le Spectre PNJ pose SON voile sans retirer la poussière du Terrassier : deux gadgets debout (avant, un PNJ remplaçait celui de l'autre)",
		deux.size() == 2 and slugs == ["poussiere", "voile"], str(slugs))

	# La salle recommencée : des PNJ neufs, des réserves neuves.
	partie.recommencer_la_salle()
	await _images(3)
	await _jusqua(func() -> bool: return partie.phase == PH_JEU, 300)
	var a2: Node = partie.pnj[0]
	var b2: Node = partie.pnj[1]
	_check("la salle recommencée : les PNJ neufs retrouvent LEURS réserves pleines (0 et 3 fusées, gadgets disponibles, recharge à zéro)",
		main.fusees_restantes(a2.slot_de_reserve()) == 0 and main.fusees_restantes(b2.slot_de_reserve()) == 3
		and main.gadget_disponible(b2.slot_de_reserve()) and main.attente_gadget(b2.slot_de_reserve()) == 0.0
		and main.gadget_disponible(a2.slot_de_reserve()),
		"%d %d %s" % [main.fusees_restantes(a2.slot_de_reserve()), main.fusees_restantes(b2.slot_de_reserve()), main.attente_gadget(b2.slot_de_reserve())])
	_check("… et leurs places sont toujours 2 et 3 (les anciennes ont été rendues : les réserves n'ont pas grossi)",
		a2.slot_de_reserve() == 2 and b2.slot_de_reserve() == 3 and main._fusees_restantes.size() == 4 and main._batterie.size() == 4,
		str(main._fusees_restantes.size()))
	_check("… les gadgets de la manche d'avant sont partis avec elle", _gadgets_du_jeu().is_empty())
	await _quitter()
	_check("la sortie rend les places : les réserves reviennent à deux entrées (J1, J2)",
		main._fusees_restantes.size() == 2 and main._gadget_attente.size() == 2 and main._batterie.size() == 2 and main._pnj_slots.is_empty())


func _fusees_dans_l_arene() -> int:
	var n := 0
	for f in main.bullet_container.get_children():
		if _classe_de(f) == "Fusee":
			n += 1
	return n


# ---------------------------------------------------------------------------
# UN BOSS A SA CLASSE
# ---------------------------------------------------------------------------

func _un_boss_a_sa_classe() -> void:
	print("\n--- Un boss Fumiste : les fusées et le gadget du Fumiste, qu'il pose lui-même, et qu'il retrouve à la reprise ---")
	# L'arène du boss (essai, niveau 3) : le joueur sous le plafonnier de l'ouest, le boss en face à 350 px, face à lui.
	var niveau3: Dictionary = (brut["niveaux"][2] as Dictionary).duplicate(true)
	var pnj_boss: Dictionary = (niveau3["pnj"][0] as Dictionary).duplicate(true)
	pnj_boss["classe"] = "fumiste"
	var c := _chapitre_de([pnj_boss], {"case": [6, 10], "orientation": 0}, true, 2)
	var partie: Node = await _demarrer(c)
	var boss: Node = partie.pnj[0]
	var s: int = boss.slot_de_reserve()
	var bot: BotInputProvider = boss.input_provider as BotInputProvider
	_check("le boss porte la classe du niveau : le Fumiste (« Le Fumiste »), au profil de boss", String(boss.current_weapon.slug()) == "fumiste"
		and bot.profil.tire and bot.profil.voit and bot.profil.utilise_le_gadget)
	_check("il a SA réserve : la place 2, une fusée (celle du Fumiste), un gadget disponible", s == 2 and main.fusees_restantes(s) == 1 and main.gadget_disponible(s))
	main.p1.hp = 100000.0
	main.p1.global_position = NavigationBot.centre_de_la_case(Vector2i(6, 10))
	main.p1.rotation = 0.0
	await _images(2)
	var a_pose := false
	var touche := false
	for _i in 600:
		main.p1.hp = 100000.0
		await process_frame
		if bot.etat == BotInputProvider.Etat.COMBAT and bool(bot.perception.derniere_vue.get("vu", false)) and not touche:
			# Le bot lit SA vie, comme un joueur lit sa barre : « il vient d'être touché » est une condition de la règle de la suie.
			boss.hp = boss.hp - 5.0
			touche = true
		for g in _gadgets_du_jeu():
			if String(g.slug) == "cartouche_suie":
				a_pose = true
		if a_pose:
			break
	_check("le boss voit le joueur sous le plafonnier et se bat (état COMBAT)", touche)
	_check("le boss POSE sa suie — la règle de SA classe, lue sur SA réserve (la place 2)", a_pose)
	await _images(20)
	_check("… et le bot SAIT qu'il l'a posée : il lit SA réserve (la place 2, en recharge), pas celle de J2 (disponible) — sans quoi il ne compterait pas sa pose",
		bot.gadgets_poses == 1 and int(bot.poses_par_gadget.get("cartouche_suie", 0)) == 1, "poses %d" % bot.gadgets_poses)
	var suie := _gadgets_du_jeu()
	_check("… posée par lui : la place de réserve 2, le rôle 1, et J2 n'a rien posé (sa recharge est intacte)",
		suie.size() == 1 and suie[0].slot_reserve == 2 and suie[0].poseur_id == 1 and main.attente_gadget(1) == 0.0 and main.attente_gadget(2) > 50.0,
		"%s" % [main.attente_gadget(2)])
	# Il vide sa fusée : sa réserve baisse à zéro, la salle recommencée la lui rend.
	main.spawn_fusee(boss, boss.global_position + Vector2(30.0, 0.0), PI)
	await _images(2)
	_check("sa fusée lancée : sa réserve tombe à 0 (celle de J2 reste à 1)", main.fusees_restantes(s) == 0 and main.fusees_restantes(1) == 1,
		"%d %d" % [main.fusees_restantes(s), main.fusees_restantes(1)])
	partie.recommencer_la_salle()
	await _images(3)
	await _jusqua(func() -> bool: return partie.phase == PH_JEU, 300)
	var boss2: Node = partie.pnj[0]
	_check("la salle recommencée : un boss NEUF, au Fumiste, avec sa fusée et son gadget — comme au premier essai",
		boss2 != boss and String(boss2.current_weapon.slug()) == "fumiste" and main.fusees_restantes(boss2.slot_de_reserve()) == 1
		and main.gadget_disponible(boss2.slot_de_reserve()) and _gadgets_du_jeu().is_empty())
	await _quitter()


## Le boss est réglé à SA classe, dans le vrai jeu : la table de `ProfilBot.REGLAGES_BOSS` arrive jusqu'au bot et jusqu'au corps.
func _le_boss_est_regle_a_sa_classe() -> void:
	print("\n--- Un boss est réglé à sa classe : ses réglages et sa vie arrivent jusqu'au bot et au corps ---")
	var niveau3: Dictionary = (brut["niveaux"][2] as Dictionary).duplicate(true)
	for classe in ["arbalete", "pompe", "pistolet"]:
		var pnj_boss: Dictionary = (niveau3["pnj"][0] as Dictionary).duplicate(true)
		pnj_boss["classe"] = classe
		var c := _chapitre_de([pnj_boss], {"case": [6, 10], "orientation": 0}, true, 2)
		var partie: Node = await _demarrer(c)
		var boss: Node = partie.pnj[0]
		var profil: ProfilBot = (boss.input_provider as BotInputProvider).profil
		var attendu := ProfilBot.boss(classe)
		main.p1.hp = 100000.0
		_check("« %s » : le profil du boss est celui de `boss(classe)` (délai %.2f s, rafale %d, engagement %.0f px, vie %.0f)" % [classe, attendu.delai_reaction,
			attendu.tirs_par_rafale, attendu.distance_engagement_px, attendu.vie],
			is_equal_approx(profil.delai_reaction, attendu.delai_reaction) and profil.tirs_par_rafale == attendu.tirs_par_rafale
			and is_equal_approx(profil.distance_engagement_px, attendu.distance_engagement_px) and is_equal_approx(profil.vie, attendu.vie))
		_check("« %s » : le corps du boss naît avec la vie du profil (%.0f)" % [classe, attendu.vie], is_equal_approx(boss.hp, attendu.vie), str(boss.hp))
		if attendu.vie > 100.0:
			boss.take_damage(100.0, main.p1)
			_check("… cent points de dégâts ne le tuent pas (il lui reste %.0f)" % boss.hp, not boss.dead and is_equal_approx(boss.hp, attendu.vie - 100.0))
			partie.recommencer_la_salle()
			await _images(3)
			await _jusqua(func() -> bool: return partie.phase == PH_JEU, 300)
			_check("… et la salle recommencée le rend à sa vie pleine (%.0f)" % attendu.vie, is_equal_approx(partie.pnj[0].hp, attendu.vie), str(partie.pnj[0].hp))
		await _quitter()
	# Un PNJ du catalogue a la vie d'un joueur.
	var c2 := _chapitre_de([{"case": [4, 8], "orientation": 0, "profil": "immobile_voit_lent"}])
	var partie2: Node = await _demarrer(c2)
	_check("un PNJ du catalogue a cent points de vie, comme un joueur", is_equal_approx(partie2.pnj[0].hp, 100.0))
	await _quitter()


# ---------------------------------------------------------------------------
# LE BOT D'ENTRAÎNEMENT GARDE SA CLASSE
# ---------------------------------------------------------------------------

func _le_bot_d_entrainement_garde_sa_classe() -> void:
	print("\n--- Le bot d'entraînement rééquipe, à sa réapparition, la classe qu'il porte ---")
	root.get_node("MapData").select_map("default")
	ui.hub.push(ui.SCREEN_TRAINING)
	await _images(2)
	ui._on_hub_action("cran_tireur")
	main.graine_du_bot = 4242
	ui._on_hub_action("entrainement")
	await _images(4)
	_check("au lancement, le bot d'entraînement porte le Parasite (index 0) — comme avant", main.training_mode and main.p2.current_weapon == main.weapon_for_index(0)
		and main._bot_p2 != null)
	var occulteur: Variant = main.weapon_for_index(7)
	main.p2.equip_weapon(occulteur)
	main.p2.current_ammo = 0
	main.p2.hp = 0.0
	main.p2.dead = true
	await _images(2)
	var rouvert := await _jusqua(func() -> bool: return not main.p2.dead, 400)
	_check("le bot abattu revient (2 s plus tard)", rouvert)
	_check("… avec la classe qu'il PORTAIT (l'Occulteur), et non l'index 0 en dur (le Parasite)", main.p2.current_weapon == occulteur,
		String(main.p2.current_weapon.slug()))
	_check("… munitions pleines, vie pleine", main.p2.current_ammo == occulteur.max_ammo and main.p2.hp == 100.0,
		"%d %s" % [main.p2.current_ammo, main.p2.hp])
	await _quitter()


# ---------------------------------------------------------------------------
# L'ÉBLOUISSEMENT DES PNJ
# ---------------------------------------------------------------------------

func _l_eblouissement_des_pnj() -> void:
	print("\n--- La torche d'un PNJ éblouit le joueur, celle du joueur éblouit un PNJ ---")
	# Le joueur à l'est, le PNJ à l'ouest, face à face à 210 px : un faisceau de pistolet les relie.
	var c := _chapitre_de([{"case": [4, 8], "orientation": 0, "profil": "immobile_sourd_aveugle"}], {"case": [10, 8], "orientation": 180})
	var partie: Node = await _demarrer(c)
	var pnj: Node = partie.pnj[0]
	var profil: ProfilBot = (pnj.input_provider as BotInputProvider).profil
	main.p1.rotation = PI
	main.p1.hp = 100000.0
	await _images(30)
	_check("(au repos, personne n'est ébloui)", main.p1.dazzle_amount < 0.01 and pnj.dazzle_amount < 0.01,
		"%s %s" % [main.p1.dazzle_amount, pnj.dazzle_amount])

	# 1. La torche du PNJ éblouit le joueur.
	profil.torche_allumee = true
	await _images(90)
	_check("la torche d'un PNJ allumée, braquée sur le joueur, l'ÉBLOUIT (avant S9b : rien, les PNJ ne sont pas des sources)",
		pnj.flashlight_on and main.p1.dazzle_amount > 0.3, "torche %s, éblouissement %s" % [pnj.flashlight_on, main.p1.dazzle_amount])
	_check("… la source qui éblouit le joueur est CE PNJ (le voile penche vers lui)", main.p1.source_eblouissante == pnj)
	profil.torche_allumee = false
	await _images(90)
	_check("… la torche éteinte, le joueur retrouve ses yeux", main.p1.dazzle_amount < 0.05, str(main.p1.dazzle_amount))

	# 2. La torche du joueur éblouit le PNJ.
	var ancien: Node = main.p1.input_provider
	var lampe := Torche.new()
	main.p1.input_provider = lampe
	main.p1.add_child(lampe)
	await _images(90)
	_check("la torche du joueur allumée, braquée sur un PNJ, l'ÉBLOUIT (avant S9b : « la torche dans les yeux d'un PNJ ne fait rien »)",
		main.p1.flashlight_on and pnj.dazzle_amount > 0.3, "torche %s, éblouissement %s, cap %s, p1 %s, pnj %s, vu %s/%s, recu %s" % [main.p1.flashlight_on, pnj.dazzle_amount,
			main.p1.rotation, main.p1.global_position, pnj.global_position, main.p1.visible, pnj.visible,
			main._lumiere_recue(main.p1.get_world_2d().direct_space_state, main.p1, pnj)])
	_check("… et le joueur n'est pas ébloui par SA propre torche au-delà de la rétrodiffusion (0,06)", main.p1.dazzle_amount < 0.1, str(main.p1.dazzle_amount))
	main.p1.input_provider = ancien
	main.p1.remove_child(lampe)
	lampe.free()
	await _images(90)
	_check("… la torche éteinte, le PNJ retrouve ses yeux", pnj.dazzle_amount < 0.05, str(pnj.dazzle_amount))

	# 3. Les éclairs de tir.
	var avant_j: float = main.p1.dazzle_amount
	main.spawn_bullet(pnj, pnj.global_position + Vector2(30.0, 0.0), 0.0, pnj.current_weapon)
	_check("l'éclair d'un tir de PNJ éblouit le joueur (un pic, à l'instant)", main.p1.dazzle_amount > avant_j + 0.1, "%s → %s" % [avant_j, main.p1.dazzle_amount])
	await _images(60)
	var avant_p: float = pnj.dazzle_amount
	main.spawn_bullet(main.p1, main.p1.global_position + Vector2(-30.0, 0.0), PI, main.p1.current_weapon)
	_check("l'éclair d'un tir du joueur éblouit un PNJ", pnj.dazzle_amount > avant_p + 0.1, "%s → %s" % [avant_p, pnj.dazzle_amount])
	await _quitter()

	print("\n--- Les PNJ forment une équipe : ils ne s'éblouissent pas entre eux ---")
	var c2 := _chapitre_de([
		{"case": [3, 8], "orientation": 0, "profil": "immobile_sourd_aveugle"},
		{"case": [7, 8], "orientation": 180, "profil": "immobile_sourd_aveugle"},
	], {"case": [12, 3], "orientation": 90})
	var partie2: Node = await _demarrer(c2)
	var p_a: Node = partie2.pnj[0]
	var p_b: Node = partie2.pnj[1]
	((p_a.input_provider as BotInputProvider).profil).torche_allumee = true
	await _images(90)
	_check("un PNJ à la torche braquée sur un autre PNJ ne l'éblouit pas (une équipe : leurs balles se traversent déjà)",
		p_a.flashlight_on and p_b.dazzle_amount < 0.01, "%s" % p_b.dazzle_amount)
	main.spawn_bullet(p_a, p_a.global_position + Vector2(30.0, 0.0), 0.0, p_a.current_weapon)
	_check("… ni par l'éclair d'un tir", p_b.dazzle_amount < 0.01, str(p_b.dazzle_amount))
	await _quitter()

	print("\n--- Le duel n'a pas changé : J1 et J2 s'éblouissent comme avant ---")
	_check("(sans aventure, `figurants` est vide : `_joueurs_en_lice` rend J1 et J2, rien d'autre)", main.figurants.is_empty()
		and main._joueurs_en_lice() == [main.p1, main.p2])


# ---------------------------------------------------------------------------
# LE BOT ÉBLOUI VOIT MOINS
# ---------------------------------------------------------------------------

func _le_bot_ebloui_voit_moins() -> void:
	print("\n--- Un bot ébloui perçoit moins : le corps s'efface, la lampe reste — jamais plus qu'aux yeux ouverts ---")
	_le_modele()
	# Dans le vrai jeu : le PNJ voit le joueur sous le plafonnier, puis ses yeux se ferment.
	var c := _chapitre_de([{"case": [6, 8], "orientation": 0, "profil": "immobile_voit_lent"}], {"case": [12, 8], "orientation": 180})
	var partie: Node = await _demarrer(c)
	var pnj: Node = partie.pnj[0]
	var bot: BotInputProvider = pnj.input_provider as BotInputProvider
	bot.profil.tire = false
	main.p1.hp = 100000.0
	var vu := await _jusqua(func() -> bool: return bool(bot.perception.derniere_vue.get("vu", false)), 300)
	_check("(le PNJ qui voit voit le joueur debout sous le plafonnier — la salle de la mesure est la bonne)", vu)
	pnj.dazzle_amount = 0.6
	bot.perception._voir(1.0 / 60.0)
	_check("ébloui (0,6), le même PNJ, à la même place, devant le même joueur sous la même lumière, NE LE VOIT PLUS",
		not bool(bot.perception.derniere_vue.get("vu", false)), str(bot.perception.derniere_vue))
	pnj.dazzle_amount = 0.0
	bot.perception._voir(1.0 / 60.0)
	_check("… les yeux rouverts, il le revoit", bool(bot.perception.derniere_vue.get("vu", false)))
	_check("… le nœud de perception lit SON éblouissement (`monde[\"ebloui\"]`), pas celui du joueur",
		is_equal_approx(float(bot.perception.monde.get("ebloui", -1.0)), 0.0))
	await _quitter()


## Le modèle pur : `PerceptionBot.voir` à éblouissements croissants, sur des scènes décrites en données.
func _le_modele() -> void:
	var monde := Percep.monde_de_la_carte(_carte_vide())
	var bot := {"position": Vector2(300, 300), "visee": Vector2.RIGHT, "accroupi": false}
	var cible := {"position": Vector2(420, 300), "accroupi": false}
	var disque := [Percep.lumiere_disque("fusee", Vector2(420, 300), 120.0, 0.0)]
	var lampe := [Percep.lumiere_lampe("lampe_de_la_cible", Vector2(437, 300), 52.0)]
	var seuil_vu := -1.0
	var monotone := true
	var dernier_vu := true
	for k in 21:
		var e := float(k) / 20.0
		monde["ebloui"] = e
		var vu := bool(Percep.voir(bot, cible, disque, monde)["vu"])
		if dernier_vu and not vu:
			seuil_vu = e
		monotone = monotone and (dernier_vu or not vu)
		dernier_vu = vu
	_check("(le modèle) à éblouissement nul, le corps éclairé par un disque est vu", true if _vu_a(0.0, bot, cible, disque, monde) else false)
	monde["ebloui"] = 0.0
	_check("(le modèle) plus l'éblouissement monte, MOINS le bot voit : jamais l'inverse (courbe monotone sur 21 niveaux)", monotone)
	_check("(le modèle) le corps disparaît quand l'opacité qu'un joueur lui verrait, au même niveau, passe sous le seuil (%.2f)" % Percep.OPACITE_MIN_CORPS,
		seuil_vu > 0.0 and seuil_vu <= 0.15 and Brouillage_.opacite(seuil_vu) < Percep.OPACITE_MIN_CORPS
		and Brouillage_.opacite(seuil_vu - 0.05) >= Percep.OPACITE_MIN_CORPS, "premier niveau aveugle : %s" % seuil_vu)
	_check("(le modèle) la lampe de la cible, elle, reste vue à n'importe quel éblouissement (le mode LAMPE : le corps s'efface, pas la source)",
		_vu_a(0.0, bot, cible, lampe, monde) and _vu_a(0.5, bot, cible, lampe, monde) and _vu_a(1.0, bot, cible, lampe, monde))
	# L'éclair d'un tir de la cible : un joueur ébloui voit encore le feu du canon. Le bot ébloui le voit comme une SOURCE — sa place, à la bouche de l'arme, jamais celle du corps.
	var eclair := [Percep.lumiere_disque("eclair_de_la_cible", Vector2(450, 300), 120.0, 0.0, false, true)]
	monde["ebloui"] = 0.0
	var ouvert_eclair: Dictionary = Percep.voir(bot, cible, eclair, monde)
	monde["ebloui"] = 0.6
	var ebloui_eclair: Dictionary = Percep.voir(bot, cible, eclair, monde)
	monde["ebloui"] = 0.0
	_check("(le modèle) aux yeux ouverts, l'éclair du tir de la cible révèle son CORPS (la place exacte)",
		bool(ouvert_eclair["vu"]) and (ouvert_eclair["position"] as Vector2).distance_to(cible["position"]) < 0.5)
	_check("(le modèle) ébloui, il voit encore l'éclair — mais seulement la place du FEU (la bouche de l'arme, à 30 px du corps), pas celle du corps",
		bool(ebloui_eclair["vu"]) and (ebloui_eclair["position"] as Vector2).distance_to(Vector2(450, 300)) < 0.5
		and (ebloui_eclair["position"] as Vector2).distance_to(cible["position"]) > 20.0, str(ebloui_eclair))
	_check("(le modèle) un éclair qui n'éclairerait pas le corps (trop loin) n'est pas vu non plus, ébloui ou non : jamais une vue de plus",
		not _vu_a(0.6, bot, cible, [Percep.lumiere_disque("eclair_de_la_cible", Vector2(900, 900), 100.0, 0.0, false, true)], monde)
		and not _vu_a(0.0, bot, cible, [Percep.lumiere_disque("eclair_de_la_cible", Vector2(900, 900), 100.0, 0.0, false, true)], monde))
	_check("(le modèle) à éblouissement donné, tout ce que voit un bot ébloui, le même bot aux yeux ouverts le voit aussi (sur 6 scènes × 11 niveaux)",
		_sous_ensemble(bot, cible, monde))
	_check("(le modèle) la rétrodiffusion de SA torche (0,06) ne lui ferme pas les yeux", Percep.corps_distinct(0.06))
	_check("(le modèle) un éblouissement absent de `monde` vaut zéro : un appelant qui l'ignore (une suite, un corps factice) voit comme avant",
		bool(Percep.voir(bot, cible, disque, Percep.monde_de_la_carte(_carte_vide()))["vu"]))


func _vu_a(e: float, bot: Dictionary, cible: Dictionary, lumieres: Array, monde: Dictionary) -> bool:
	monde["ebloui"] = e
	var r: Dictionary = Percep.voir(bot, cible, lumieres, monde)
	monde["ebloui"] = 0.0
	return bool(r["vu"])


## Pour cinq scènes (un disque, une lampe, les deux, loin, derrière rien) et onze niveaux : `voir(ébloui)` est inclus dans `voir(yeux ouverts)` —
## vu, lumières qui l'ont révélé, et ce qui a été vu.
func _sous_ensemble(bot: Dictionary, cible: Dictionary, monde: Dictionary) -> bool:
	var scenes: Array = [
		[Percep.lumiere_disque("d", Vector2(420, 300), 120.0, 0.0)],
		[Percep.lumiere_lampe("l", Vector2(437, 300), 52.0)],
		[Percep.lumiere_disque("d", Vector2(420, 300), 120.0, 0.0), Percep.lumiere_lampe("l", Vector2(437, 300), 52.0)],
		[Percep.lumiere_disque("d", Vector2(900, 900), 100.0, 0.0)],
		[Percep.lumiere_disque("eclair_de_la_cible", Vector2(450, 300), 120.0, 0.0, false, true), Percep.lumiere_lampe("l", Vector2(437, 300), 52.0)],
		[],
	]
	var ok := true
	for lumieres in scenes:
		monde["ebloui"] = 0.0
		var ouvert: Dictionary = Percep.voir(bot, cible, lumieres, monde)
		for k in 11:
			monde["ebloui"] = float(k) / 10.0
			var ebloui: Dictionary = Percep.voir(bot, cible, lumieres, monde)
			if bool(ebloui["vu"]) and not bool(ouvert["vu"]):
				ok = false
			for nom in ebloui["par"]:
				if not (ouvert["par"] as Array).has(nom):
					ok = false
	monde["ebloui"] = 0.0
	return ok


## Une carte de sol nu, ceinte de murs : de quoi bâtir un monde pour le modèle.
func _carte_vide() -> Dictionary:
	var d := MapCodec.new_map("vide", Vector2i(24, 24))
	var sol: Array[Vector2i] = []
	var murs: Array[Vector2i] = []
	for y in 24:
		for x in 24:
			if x == 0 or y == 0 or x == 23 or y == 23:
				murs.append(Vector2i(x, y))
			else:
				sol.append(Vector2i(x, y))
	d["floor"] = MapCodec.encode_runs(sol)
	d["walls"] = MapCodec.encode_runs(murs)
	return d


# ---------------------------------------------------------------------------
# OUTILS
# ---------------------------------------------------------------------------

func _horloge_fixe() -> bool:
	var f0 := Engine.get_physics_frames()
	for _i in 60:
		await process_frame
	return absi(int(Engine.get_physics_frames() - f0) - 60) <= 1


func _images(n: int) -> void:
	for _i in n:
		await process_frame


func _jusqua(cond: Callable, max_images: int) -> bool:
	for _i in max_images:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _effacer(chemin: String) -> void:
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(chemin)


func _sortir() -> void:
	print("\n%d vérifications" % _verifications)
	print("CRIS ATTENDUS: 0")
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
