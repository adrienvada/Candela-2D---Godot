## La garde de la PARTIE d'aventure — chantier SOLO, étape S6 : le vrai jeu monté, à pas d'image fixe.
##
## `tools/test_aventure_format.gd` juge les fichiers sans partie ; celle-ci monte `main.tscn` (vue iso allumée, comme un joueur) et
## joue le chapitre d'essai (`tools/aventure_essai/`, trois salles dont un boss) par le chemin que le jeu emprunte :
##
##   • UNE SALLE SE CHARGE : l'arène vient de la carte du niveau, les plafonniers sont posés (`Plafonnier_<i>`), le joueur est à sa
##     case et tourné où le niveau le dit, les PNJ sont de vrais `Player` nommés `PNJ_<i>`, pilotés chacun par un `BotInputProvider`
##     (`BotPNJ_<i>`) au profil du catalogue, une seule vue, l'oreille sur le joueur ; le carton fige tout le monde ;
##   • LES PNJ SONT HONNÊTES ET SOLIDAIRES : la perception de chacun vise le joueur humain et jamais un autre PNJ ; ils ne se blessent
##     pas entre eux, et leurs balles traversent leurs voisins ;
##   • LA VUE ISO LES MONTRE TOUS : un corps voxel, un capteur de lumière et une couche chacun — et le duel est rendu comme avant (aucun
##     figurant, aucun corps de plus, aucun capteur de plus) ;
##   • LA BOUCLE : tous les PNJ morts (par appel direct ou par balles) enchaînent la salle suivante ; mourir recommence LA SALLE, PNJ
##     remis à leur départ, carte et plafonniers inchangés ; finir le boss termine le chapitre, débloque sa classe, l'écrit dans la
##     progression et ramène à l'écran de l'aventure ;
##   • ON LA QUITTE PROPREMENT : retour au menu, entraînement, duel — PNJ, plafonniers et carton partent, la carte du joueur est
##     rendue, et l'entraînement comme l'écran scindé qui suivent sont intacts ;
##   • L'ÉCRAN : l'entrée « AVENTURE », ses chapitres (à venir, fermés, ouverts), ses salles, le râtelier verrouillé d'après la
##     progression solo, le lanceur.
##
## ⚠️ **Se lance à pas d'image fixe** (`--fixed-fps 60`) : les délais de la partie sont comptés en pas de physique, et la suite refuse de
## conclure sans cette horloge. La progression de la suite vit dans un fichier à elle (`user://test_aventure_partie_solo.cfg`) : le
## `user://solo.cfg` du joueur n'est jamais ouvert en écriture (la suite le vérifie).
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_aventure_partie.gd
extends SceneTree

const Format := preload("res://aventure_format.gd")
const Progression := preload("res://aventure_progression.gd")

const ESSAI := "res://tools/aventure_essai"
const SOLO_DE_LA_SUITE := "user://test_aventure_partie_solo.cfg"
const TEMP := "user://test_aventure_partie"

## Les phases de `AventurePartie.Phase`, en entiers : cette suite ne nomme AUCUNE classe qui dépende d'un autoload (`Player`,
## `Presentation3D`, `AventurePartie`) — le script d'une suite se compile avant que les autoloads n'existent (piège du 2026-08-18) —
## et les atteint à l'exécution. Une garde compare ces entiers à l'énumération du jeu.
const PH_CARTON := 0
const PH_JEU := 1
const PH_GAGNEE := 2
const PH_ABATTU := 3
const PH_FINI := 4

var _failures := 0
var _verifications := 0
## Les `push_error` que la suite provoque exprès (`_les_refus`) : déclarés en fin de sortie, le lanceur exige l'égalité.
var _cris_voulus := 0

var main: Node = null
var ui: Node = null
var prog: AventureProgression = null
var chapitre: Dictionary = {}


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
	print("=== LA PARTIE D'AVENTURE (S6) ===")
	await process_frame
	var horloge_fixe := await _horloge_fixe()
	_check("l'horloge est fixe (--fixed-fps 60) : une image = un pas de physique", horloge_fixe,
		"lancer avec --fixed-fps 60 : sans lui les délais de la partie ne mesureraient rien")
	if not horloge_fixe:
		_sortir()
		return
	var solo_du_joueur_avant := FileAccess.file_exists(Progression.CHEMIN_PAR_DEFAUT)
	var md5_avant := FileAccess.get_md5(Progression.CHEMIN_PAR_DEFAUT) if solo_du_joueur_avant else ""
	_effacer(SOLO_DE_LA_SUITE)

	root.get_node("GameSettings").mode_iso = true
	Format.racine = ESSAI
	Format.niveaux_attendus = 0
	Format.oublier_le_cache()
	chapitre = Format.charger_chapitre(ESSAI.path_join("chapitre_00"), 0)
	_check("le chapitre d'essai se charge", not chapitre.is_empty())
	if chapitre.is_empty():
		_sortir()
		return
	prog = Progression.new(SOLO_DE_LA_SUITE)

	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	ui = main.ui
	ui.aventure_progression = prog
	main.archiver_les_matchs = false

	await _le_duel_est_rendu_comme_avant()
	await _les_refus()
	await _une_salle_se_charge()
	await _les_pnj_sont_honnetes_et_solidaires()
	await _un_pnj_equipe_se_sert_de_son_gadget()
	await _la_vue_iso_les_montre_tous()
	await _la_boucle()
	await _on_la_quitte_proprement()
	await _l_ecran()

	_check("`user://solo.cfg` du joueur n'a JAMAIS été ouvert en écriture par la suite", FileAccess.file_exists(Progression.CHEMIN_PAR_DEFAUT) == solo_du_joueur_avant
		and (not solo_du_joueur_avant or FileAccess.get_md5(Progression.CHEMIN_PAR_DEFAUT) == md5_avant))
	_effacer(SOLO_DE_LA_SUITE)
	_supprimer(TEMP)
	Format.racine = "res://assets/solo"
	Format.niveaux_attendus = Format.NIVEAUX_PAR_CHAPITRE
	Format.oublier_le_cache()
	main.queue_free()
	await _images(2)
	_sortir()


# ---------------------------------------------------------------------------
# LE DUEL, RENDU COMME AVANT
# ---------------------------------------------------------------------------

## `Presentation3D` à l'exécution : la classe dépend d'autoloads, que le script de la suite ne peut pas nommer à la compilation.
func _classe_pres() -> GDScript:
	return load("res://presentation_3d.gd") as GDScript


## Une constante de `Presentation3D`, lue sur son script.
func _const(nom: String) -> Variant:
	return _classe_pres().get_script_constant_map()[nom]


func _la_presentation() -> Node:
	return _classe_pres().instance()


func _le_duel_est_rendu_comme_avant() -> void:
	print("\n--- Le duel : aucun figurant, rien de plus qu'avant ---")
	root.get_node("MapData").select_map("default")
	main._on_main_menu_requested()
	await _images(2)
	main._on_replay_requested()
	await _images(6)
	var pres := _la_presentation()
	_check("l'écran scindé démarre (manche active, hors entraînement), la vue iso est allumée", main.round_active and not main.training_mode
		and pres != null and pres._actif)
	if pres == null:
		return
	_check("DEUX corps seulement : J1 et J2 (aucun corps de pool, aucun figurant)", pres._corps.size() == 2 and pres._voxels.size() == 2
		and pres._mat_corps.size() == 2 and pres._etats_corps.size() == 2 and pres._figurants.is_empty(), str(pres._corps.size()))
	_check("les capteurs sont les QUATRE d'avant (2 vues × 2 corps), aucun capteur de figurant",
		pres._capteurs.size() == 2 and (pres._capteurs[0] as Array).size() == 2 and (pres._capteurs[1] as Array).size() == 2
		and pres._capteurs_figurants.is_empty() and _compte_capteurs(pres) == 4, str(_compte_capteurs(pres)))
	_check("`GameState.figurants` est vide en duel", main.figurants.is_empty() and main.aventure == null)
	_check("les couches des capteurs de J1 et J2 sont celles d'avant (8, 16, 32, 64)", [pres.couche_capteur(0, 0), pres.couche_capteur(0, 1),
		pres.couche_capteur(1, 0), pres.couche_capteur(1, 1)] == [8, 16, 32, 64])
	_check("les masques des capteurs sont ceux d'avant (132, 18, 34, 268)", [pres.masque_capteur(0, 0), pres.masque_capteur(0, 1),
		pres.masque_capteur(1, 0), pres.masque_capteur(1, 1)] == [132, 18, 34, 268], str([pres.masque_capteur(0, 0), pres.masque_capteur(0, 1),
		pres.masque_capteur(1, 0), pres.masque_capteur(1, 1)]))
	_check("J1 et J2 sont rendus (corps visibles), leurs capteurs tournent", pres._corps[0].visible and pres._corps[1].visible)
	_check("les masques des lightmaps sont ceux du jeu, hors couches des capteurs et des figurants",
		main.vp1.canvas_cull_mask == ((~4 & 0xFFFFFFFF) & ~int(_const("COUCHES_HORS_LIGHTMAP")))
		and main.vp2.canvas_cull_mask == ((~2 & 0xFFFFFFFF) & ~int(_const("COUCHES_HORS_LIGHTMAP"))))
	main._on_main_menu_requested()
	await _images(2)


func _compte_capteurs(pres: Node) -> int:
	var n := 0
	for id in 2:
		for j in (pres._capteurs[id] as Array).size():
			if pres._capteurs[id][j] != null:
				n += 1
	return n


# ---------------------------------------------------------------------------
# CE QUE LE MOTEUR REFUSE DE LANCER (trois cris voulus : `CRIS ATTENDUS: 3`)
# ---------------------------------------------------------------------------

func _les_refus() -> void:
	print("\n--- Le moteur refuse ce que l'écran refuserait ---")
	var neuve := Progression.new(TEMP.path_join("refus.cfg"))
	DirAccess.make_dir_recursive_absolute(TEMP)
	_check("une salle FERMÉE ne se lance pas (la 2 d'un chapitre où rien n'est réussi) — et le crie", not main.demarrer_l_aventure(chapitre, 1, "pistolet", neuve)
		and main.aventure == null and main.figurants.is_empty() and get_nodes_in_group("plafonniers").is_empty())
	_check("une classe autre que celle que le chapitre PRÊTE ne se lance pas — et le crie", not main.demarrer_l_aventure(chapitre, 0, "fumiste", neuve)
		and main.aventure == null)
	var libre := chapitre.duplicate(true)
	libre["classe_imposee"] = ""
	_check("une classe NON débloquée, dans un chapitre qui n'impose rien, ne se lance pas — et le crie", not main.demarrer_l_aventure(libre, 0, "fumiste", neuve)
		and main.aventure == null)
	_check("… et rien n'a été posé : pas de carton, pas de PNJ, la carte du joueur intacte", main.get_node_or_null("CartonAventure") == null
		and _noms_des_pnj_du_groupe().is_empty() and root.get_node("MapData").selected_map_id != "aventure")
	_cris_voulus = 3


# ---------------------------------------------------------------------------
# UNE SALLE SE CHARGE
# ---------------------------------------------------------------------------

func _une_salle_se_charge() -> void:
	print("\n--- Une salle se charge ---")
	var carte_avant: String = root.get_node("MapData").selected_map_id
	var ok: bool = main.demarrer_l_aventure(chapitre, 0, "pistolet", prog)
	_check("`demarrer_l_aventure` pose la première salle", ok and main.aventure != null)
	await _images(3)
	var partie: Node = main.aventure
	_check("c'est un entraînement qui ne compte pas : hors manche, bac à sable, une seule vue", not main.round_active and main.sandbox_mode
		and main.training_mode and main.vp1.get_parent().visible and not main.vp2.get_parent().visible)
	_check("la carte active est celle du NIVEAU (identifiant d'aventure), pas une carte du catalogue",
		root.get_node("MapData").selected_map_id == "aventure" and MapCodec.get_grid_size(root.get_node("MapData").get_selected()) == Vector2i(16, 16))
	_check("le joueur est à sa case (3, 8), tourné vers l'est, plein de vie, classe Parasite", main.p1.global_position.distance_to(
		NavigationBot.centre_de_la_case(Vector2i(3, 8))) < 1.0 and absf(main.p1.rotation) < 0.01 and main.p1.hp == 100.0 and not main.p1.dead
		and String(main.p1.current_weapon.slug()) == "pistolet", str(main.p1.global_position))
	_check("J2 n'a aucun rôle : caché, sans collision", not main.p2.visible and not main.p2.get_collision_layer_value(1)
		and not main.p2.get_collision_mask_value(1))
	_check("l'arène porte son conteneur de plafonniers, un plafonnier `Plafonnier_0` à la case (12, 8)",
		main.arena.get_node_or_null("Plafonniers") != null and main.arena.get_node_or_null("Plafonniers/Plafonnier_0") != null
		and (main.arena.get_node("Plafonniers/Plafonnier_0") as Node2D).global_position.is_equal_approx(NavigationBot.centre_de_la_case(Vector2i(12, 8))))
	_check("le groupe des plafonniers compte un plafonnier", get_nodes_in_group("plafonniers").size() == 1)
	_check("UN PNJ, `PNJ_0`, un vrai `Player` de `player_id` 1 marqué `est_pnj`", partie.pnj.size() == 1 and partie.pnj[0].name == "PNJ_0"
		and partie.pnj[0].get_script().get_global_name() == &"Player" and partie.pnj[0].player_id == 1 and partie.pnj[0].est_pnj)
	var pnj: Node = partie.pnj[0]
	_check("il est dans le groupe `players` et sous les joueurs de la scène", pnj.is_in_group("players") and pnj.get_parent() == main.players_node)
	_check("piloté par un `BotInputProvider` nommé `BotPNJ_0`, au profil sourd et aveugle immobile", _classe_de(pnj.input_provider) == "BotInputProvider"
		and pnj.input_provider.name == "BotPNJ_0" and not (pnj.input_provider as BotInputProvider).profil.voit
		and (pnj.input_provider as BotInputProvider).profil.deplacement == ProfilBot.Deplacement.IMMOBILE)
	_check("à sa case (12, 8), tourné vers l'ouest, plein de vie", pnj.global_position.distance_to(NavigationBot.centre_de_la_case(Vector2i(12, 8))) < 1.0
		and absf(absf(pnj.rotation) - PI) < 0.01 and pnj.hp == 100.0)
	_check("il est solide et visible (un vrai corps)", pnj.visible and pnj.get_collision_layer_value(1) and pnj.get_collision_mask_value(1))
	var ecoutes: Array = main.p1.find_children("*", "AudioListener2D", true, false)
	_check("l'oreille est posée sur le joueur (un `AudioListener2D` actif sous J1)", not ecoutes.is_empty() and (ecoutes[0] as AudioListener2D).is_current())
	_check("le HUD dit la salle (« 0.1 · SOUS LA LAMPE »)", ui.time_label.text == "0.1 · Sous la lampe", ui.time_label.text)
	# Le carton.
	_check("le carton couvre l'écran et dit le chapitre, le titre et la phrase d'intention", partie.phase == PH_CARTON
		and partie._carton.visible and partie._carton.texte()["titre"] == "Sous la lampe"
		and partie._carton.texte()["entete"].begins_with("CHAPITRE 0") and partie._carton.texte()["phrase"].begins_with("Une silhouette immobile"),
		str(partie._carton.texte()))
	_check("le carton est un nœud NOMMÉ (`CartonAventure`)", partie._carton.name == "CartonAventure" and partie._carton.get_parent() == main)
	_check("pendant le carton le monde est figé (`countdown_left` > 0), comme au décompte d'une manche", main.countdown_left > 0.0)
	var pos_avant: Vector2 = main.p1.global_position
	Input.action_press("p1_move_right")
	await _images(30)
	Input.action_release("p1_move_right")
	_check("… et le joueur ne bouge pas même s'il appuie sur une touche", main.p1.global_position.distance_to(pos_avant) < 0.5)
	await _jusqua(func() -> bool: return partie.phase == PH_JEU, 200)
	_check("le carton se retire au bout de `DUREE_CARTON` : on joue, le monde repart", partie.phase == PH_JEU
		and main.countdown_left == 0.0 and not partie._carton.visible)
	Input.action_press("p1_move_right")
	await _images(30)
	Input.action_release("p1_move_right")
	_check("… et le joueur, lui, bouge de nouveau", main.p1.global_position.x > pos_avant.x + 20.0, str(main.p1.global_position))
	# Rien de classé.
	_check("rien de classé ni d'archivé : aucun forfait, aucun identifiant de match, aucune ligne dans le journal", not main._forfeit_pending
		and main._match_id == "" and main.game_over == false)
	# Quitter rend la carte.
	main._on_main_menu_requested()
	await _images(2)
	_check("quitter vers le menu rend la carte que le joueur avait choisie", root.get_node("MapData").selected_map_id == carte_avant
		and main.aventure == null, "%s ≠ %s" % [root.get_node("MapData").selected_map_id, carte_avant])


# ---------------------------------------------------------------------------
# LES PNJ : HONNÊTES ET SOLIDAIRES
# ---------------------------------------------------------------------------

## Un chapitre à UNE salle de trois PNJ qui voient et tirent, fabriqué pour la suite (des rondes et des PNJ sourds ne perçoivent rien).
func _chapitre_de_trois_pnj_qui_voient() -> Dictionary:
	var lu := Format.lire_chapitre(ESSAI.path_join("chapitre_00"))
	var niveau: Dictionary = (lu["niveaux"][0] as Dictionary).duplicate(true)
	niveau["pnj"] = [
		{"case": [8, 4], "orientation": 90, "profil": "immobile_voit_entend_lent"},
		{"case": [8, 7], "orientation": 180, "profil": "immobile_voit_entend_lent"},
		{"case": [8, 11], "orientation": 270, "profil": "immobile_voit_lent"},
	]
	var defauts := Format.valider_niveau(niveau)
	_check("(le niveau de trois PNJ de la suite est lui-même valide)", defauts.is_empty(), str(defauts))
	var c := chapitre.duplicate(true)
	c["niveaux"] = [Format.preparer_niveau(niveau)]
	c["niveaux"][0]["fichier"] = "trois_pnj.json"
	return c


func _les_pnj_sont_honnetes_et_solidaires() -> void:
	print("\n--- Les PNJ ne visent que le joueur, et ne se blessent pas entre eux ---")
	var c := _chapitre_de_trois_pnj_qui_voient()
	main.demarrer_l_aventure(c, 0, "pistolet", prog)
	await _images(3)
	var partie: Node = main.aventure
	await _jusqua(func() -> bool: return partie.phase == PH_JEU, 200)
	_check("trois PNJ nommés `PNJ_0`, `PNJ_1`, `PNJ_2`", partie.pnj.size() == 3 and str(partie.pnj[0].name) == "PNJ_0"
		and str(partie.pnj[1].name) == "PNJ_1" and str(partie.pnj[2].name) == "PNJ_2")
	var tous_percoivent := true
	for p in partie.pnj:
		tous_percoivent = tous_percoivent and (p.input_provider as BotInputProvider).perception != null
	_check("chacun monte sa perception (ils voient et entendent)", tous_percoivent)
	# La perception d'un PNJ vise le joueur — jamais un autre PNJ.
	var vise_le_joueur := true
	for p in partie.pnj:
		vise_le_joueur = vise_le_joueur and (p.input_provider as BotInputProvider).perception._adversaire() == main.p1
	_check("la perception de CHAQUE PNJ vise le joueur humain", vise_le_joueur)
	main.p1.hide()
	var vise_un_pnj := false
	for p in partie.pnj:
		var cible = (p.input_provider as BotInputProvider).perception._adversaire()
		vise_un_pnj = vise_un_pnj or (cible != null and cible != main.p1)
	main.p1.show()
	_check("le joueur caché, aucun PNJ ne prend un AUTRE PNJ pour adversaire (la perception ne vise jamais un PNJ)", not vise_un_pnj)
	main.p1.dead = true
	var cible_du_mort = (partie.pnj[0].input_provider as BotInputProvider).perception._adversaire()
	main.p1.dead = false
	_check("le joueur mort : le PNJ n'a plus d'adversaire (et non le voisin)", cible_du_mort == null)
	# Ils ne se blessent pas entre eux : l'appel direct… (Les trois PNJ voient et tirent : on les désarme pour la suite, sans quoi l'un d'eux
	# abattrait le joueur au milieu des mesures et la salle recommencerait — des PNJ libérés, une suite qui lit des nœuds morts.)
	for p in partie.pnj:
		(p.input_provider as BotInputProvider).profil.tire = false
	var a: Node = partie.pnj[0]
	var b: Node = partie.pnj[1]
	b.take_damage(50.0, a)
	_check("un PNJ ne blesse pas un PNJ (`take_damage` d'un coup de son voisin)", b.hp == 100.0, str(b.hp))
	b.take_damage(30.0, main.p1)
	_check("… mais le joueur, lui, le blesse (30 points)", b.hp == 70.0, str(b.hp))
	b.hp = 100.0
	# … et la balle : elle traverse. Alignés sur une ligne, un mur au bout.
	a.global_position = NavigationBot.centre_de_la_case(Vector2i(4, 4))
	b.global_position = NavigationBot.centre_de_la_case(Vector2i(7, 4))
	partie.pnj[2].global_position = NavigationBot.centre_de_la_case(Vector2i(12, 4))
	await _images(2)
	var tireur_pos: Vector2 = a.global_position + Vector2(30.0, 0.0)
	main.spawn_bullet(a, tireur_pos, 0.0, a.current_weapon)
	var passee := false
	var balle: Node = null
	for _i in 90:
		await process_frame
		if balle == null:
			for enfant in main.bullet_container.get_children():
				if _classe_de(enfant) == "Bullet":
					balle = enfant
					break
		if balle != null and is_instance_valid(balle) and (balle as Node2D).global_position.x > b.global_position.x + 40.0:
			passee = true
			break
		if balle != null and not is_instance_valid(balle):
			break
	_check("la balle d'un PNJ TRAVERSE le PNJ voisin (elle a dépassé son corps)", passee)
	_check("… sans le toucher : vie intacte", b.hp == 100.0 and partie.pnj[2].hp == 100.0, "%s %s" % [b.hp, partie.pnj[2].hp])
	# Le joueur, lui, est touché par la balle d'un PNJ (la règle ne protège que les PNJ).
	main.p1.global_position = a.global_position + Vector2(0, 0)
	main.p1.global_position = NavigationBot.centre_de_la_case(Vector2i(10, 4))
	await _images(2)
	var hp_avant: float = main.p1.hp
	main.spawn_bullet(a, a.global_position + Vector2(30.0, 0.0), 0.0, a.current_weapon)
	await _images(60)
	_check("la balle d'un PNJ touche, elle, le joueur (le fusil d'un PNJ n'est pas désarmé)", main.p1.hp < hp_avant or main.p1.dead, "%s → %s" % [hp_avant, main.p1.hp])
	main._on_main_menu_requested()
	await _images(2)


# ---------------------------------------------------------------------------
# UN PNJ ÉQUIPÉ (« equipe », S8)
# ---------------------------------------------------------------------------

func _gadgets_du_jeu() -> Array:
	var sortie: Array = []
	for g in get_nodes_in_group("gadgets"):
		if is_instance_valid(g) and not g.is_queued_for_deletion():
			sortie.append(g)
	return sortie


## Deux PNJ du MÊME profil (`immobile_voit_lent`) et de la MÊME classe (le Fumiste), l'un avec la clé « equipe », l'autre sans. Le joueur se tient sous le
## plafonnier, les deux le voient ; touchés tous deux (la règle de la suie : « il vient d'être touché »), seul l'équipé pose sa suie — avec SA réserve.
func _un_pnj_equipe_se_sert_de_son_gadget() -> void:
	print("\n--- Un PNJ équipé se sert du gadget de sa classe, son voisin identique mais sans la clé non ---")
	var lu := Format.lire_chapitre(ESSAI.path_join("chapitre_00"))
	var niveau: Dictionary = (lu["niveaux"][0] as Dictionary).duplicate(true)
	niveau["pnj"] = [
		{"case": [4, 6], "orientation": 0, "profil": "immobile_voit_lent", "classe": "fumiste", "equipe": true},
		{"case": [4, 10], "orientation": 0, "profil": "immobile_voit_lent", "classe": "fumiste"},
	]
	var defauts := Format.valider_niveau(niveau)
	_check("(le niveau de deux PNJ équipé / non équipé est lui-même valide)", defauts.is_empty(), str(defauts))
	var c := chapitre.duplicate(true)
	c["niveaux"] = [Format.preparer_niveau(niveau)]
	c["niveaux"][0]["fichier"] = "equipe.json"
	main.graine_du_bot = 4242
	main.demarrer_l_aventure(c, 0, "pistolet", prog)
	await _images(3)
	var partie: Node = main.aventure
	await _jusqua(func() -> bool: return partie.phase == PH_JEU, 300)
	var a: Node = partie.pnj[0]
	var b: Node = partie.pnj[1]
	var bot_a := a.input_provider as BotInputProvider
	var bot_b := b.input_provider as BotInputProvider
	_check("l'équipé porte le Fumiste et se sert de son gadget ; son voisin porte le Fumiste et ne s'en sert pas",
		String(a.current_weapon.slug()) == "fumiste" and String(b.current_weapon.slug()) == "fumiste"
		and bot_a.profil.utilise_le_gadget and not bot_b.profil.utilise_le_gadget and not bot_b.profil.est_equipe())
	_check("… les deux ont leur réserve (places 2 et 3), le gadget disponible",
		a.slot_de_reserve() == 2 and b.slot_de_reserve() == 3 and main.gadget_disponible(2) and main.gadget_disponible(3))
	main.p1.hp = 100000.0
	main.p1.global_position = NavigationBot.centre_de_la_case(Vector2i(11, 8))
	main.p1.rotation = PI
	await _images(2)
	var touches := false
	var a_pose := false
	for _i in 900:
		main.p1.hp = 100000.0
		await process_frame
		if not touches and bot_a.etat == BotInputProvider.Etat.COMBAT and bot_b.etat == BotInputProvider.Etat.COMBAT:
			# « Il vient d'être touché » : le bot lit SA vie, comme un joueur lit sa barre.
			a.hp = a.hp - 5.0
			b.hp = b.hp - 5.0
			touches = true
		for g in _gadgets_du_jeu():
			if String(g.slug) == "cartouche_suie":
				a_pose = true
		if a_pose:
			break
	_check("les deux PNJ voient le joueur sous le plafonnier et se battent (état COMBAT)", touches)
	_check("l'équipé POSE sa suie (la règle du Fumiste, lue sur SA réserve)", a_pose)
	await _images(60)
	var suies: Array = []
	for g in _gadgets_du_jeu():
		if String(g.slug) == "cartouche_suie":
			suies.append(g)
	_check("… une seule suie dans l'arène, posée par l'équipé (place 2) et pas par son voisin (place 3 intacte)",
		suies.size() == 1 and suies[0].slot_reserve == 2 and main.gadget_disponible(3) and bot_b.gadgets_poses == 0 and bot_a.gadgets_poses >= 1,
		"suies %d, poses a %d b %d" % [suies.size(), bot_a.gadgets_poses, bot_b.gadgets_poses])
	main._on_main_menu_requested()
	await _images(2)


# ---------------------------------------------------------------------------
# LA VUE ISO LES MONTRE TOUS
# ---------------------------------------------------------------------------

func _la_vue_iso_les_montre_tous() -> void:
	print("\n--- La vue iso rend tous les PNJ ---")
	var c := _chapitre_de_trois_pnj_qui_voient()
	# Cinq PNJ, pour que le pool grandisse au-delà de ce que J1 et J2 occupent.
	var niveau: Dictionary = c["niveaux"][0]
	niveau["pnj"].append({"case": Vector2i(10, 3), "rotation": PI, "profil_nom": "immobile_sourd_aveugle", "classe": "pistolet", "ronde": [] as Array[Vector2i], "zone": Rect2i()})
	niveau["pnj"].append({"case": Vector2i(10, 12), "rotation": PI, "profil_nom": "immobile_sourd_aveugle", "classe": "pistolet", "ronde": [] as Array[Vector2i], "zone": Rect2i()})
	main.demarrer_l_aventure(c, 0, "pistolet", prog)
	await _images(6)
	var pres := _la_presentation()
	var partie: Node = main.aventure
	_check("la vue iso est allumée, en vue unique", pres != null and pres._actif and not pres._scinde)
	if pres == null:
		return
	_check("cinq figurants suivent `GameState.figurants`", pres._figurants.size() == 5 and main.figurants.size() == 5, str(pres._figurants.size()))
	_check("le pool compte 2 + 5 corps (J1, J2, cinq figurants), chacun nommé `Corps<n>`", pres._corps.size() == 7 and pres._voxels.size() == 7
		and pres._mat_corps.size() == 7 and pres._etats_corps.size() == 7 and pres._corps[6].name == "Corps7" and pres._corps[2].name == "Corps3",
		str(pres._corps.size()))
	var tous_montres := true
	var tous_a_leur_place := true
	var tous_voxel := true
	for k in 5:
		var j := 2 + k
		tous_montres = tous_montres and pres._corps[j].visible
		var voxel: Node3D = pres._voxels[j]
		tous_voxel = tous_voxel and voxel.slug() != "" and voxel.get_child_count() > 0
		var attendu: Vector2 = partie.pnj[k].global_position
		var pos := Vector2(voxel.position.x, voxel.position.z) * float(CandelaTileSet.TILE_SIZE.x)
		tous_a_leur_place = tous_a_leur_place and pos.distance_to(attendu) < 1.0
	_check("TOUS les PNJ ont un corps iso VISIBLE", tous_montres)
	_check("… un vrai corps voxel (une classe, des pièces)", tous_voxel)
	_check("… posé à la place de son PNJ", tous_a_leur_place)
	var capteurs_ok := true
	var couches: Array[int] = []
	for k in 5:
		var cap = pres._capteurs_figurants[k]
		capteurs_ok = capteurs_ok and cap != null and is_instance_valid(cap) and cap.get("proprietaire") == partie.pnj[k]
		capteurs_ok = capteurs_ok and cap.couche() == pres.couche_capteur(0, 2 + k)
		capteurs_ok = capteurs_ok and cap.masque_lumiere() == pres.masque_capteur(0, 1)
		couches.append(cap.couche())
	_check("chaque figurant a SON capteur, à sa couche, au masque de l'adversaire de J1 (comme J2)", capteurs_ok)
	var distinctes := true
	var union := 0
	for cc in couches:
		distinctes = distinctes and (cc & (cc - 1)) == 0 and (union & cc) == 0 and (cc & (1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 | 256 | 512)) == 0
		union |= cc
	_check("les couches des cinq capteurs sont distinctes, à un bit, hors du jeu, des capteurs d'avant et de la peinture", distinctes, str(couches))
	_check("… et hors des lightmaps (le masque de la vue ne les lit pas : aucun disque blanc au sol)", (main.vp1.canvas_cull_mask & union) == 0
		and (main.vp2.canvas_cull_mask & union) == 0 and (int(_const("COUCHES_HORS_LIGHTMAP")) & union) == union)
	_check("les noms des capteurs sont uniques et explicites (`CapteurVue1Corps3`…)", pres.get_node_or_null("CapteurVue1Corps3") != null
		and pres.get_node_or_null("CapteurVue1Corps7") != null)
	var sprites_caches := true
	for p in partie.pnj:
		for nom in _const("APPUIS_JOUEUR"):
			var noeud := p.get(nom) as CanvasItem
			if noeud != null and noeud.visibility_layer != _const("COUCHE_HORS_VUE"):
				sprites_caches = false
	_check("les sprites 2D des PNJ sont hors des lightmaps (sinon chacun se dessinerait deux fois : debout en voxel et à plat au sol)", sprites_caches)
	_check("le matériau de chaque corps lit le capteur de sa vue (`capteur_1`)", (pres._mat_corps[2] as ShaderMaterial).get_shader_parameter("capteur_1") == pres._capteurs_figurants[0].get_texture())
	# Un PNJ abattu n'a plus de corps.
	await _jusqua(func() -> bool: return partie.phase == PH_JEU, 200)
	partie.pnj[1].take_damage(999.0, main.p1)
	await _images(4)
	_check("un PNJ abattu n'a plus de corps iso (il ne se montre pas, il ne bloque rien)", not pres._corps[3].visible and pres._corps[2].visible
		and not partie.pnj[1].visible and not partie.pnj[1].get_collision_layer_value(1))
	# Un PNJ qui marche : son corps le suit.
	main._on_main_menu_requested()
	await _images(3)
	_check("quitter vide `GameState.figurants` : la présentation n'en garde aucun", main.figurants.is_empty() and pres._figurants.is_empty()
		and pres._capteurs_figurants.is_empty())
	var corps_caches := true
	for j in range(2, pres._corps.size()):
		corps_caches = corps_caches and not pres._corps[j].is_visible_in_tree()
	_check("les corps du pool, que personne ne porte plus, ne se montrent pas (le pool reste, il ne se détruit pas)", pres._corps.size() == 7 and corps_caches)
	var capteurs_restants := 0
	for n in pres.get_children():
		if _classe_de(n) == "CapteurCorps" and int(n.get("corps_id")) >= 2:
			capteurs_restants += 1
	_check("aucun capteur de figurant ne reste dans l'arbre", capteurs_restants == 0, str(capteurs_restants))


# ---------------------------------------------------------------------------
# LA BOUCLE
# ---------------------------------------------------------------------------

func _la_boucle() -> void:
	print("\n--- La boucle : salle gagnée, salle suivante, mort, boss ---")
	_effacer(SOLO_DE_LA_SUITE)
	prog = Progression.new(SOLO_DE_LA_SUITE)
	ui.aventure_progression = prog
	main.graine_du_bot = 4242
	main.demarrer_l_aventure(chapitre, 0, "pistolet", prog)
	await _images(3)
	var partie: Node = main.aventure
	var signaux: Array = []
	partie.salle_gagnee.connect(func(c: int, i: int) -> void: signaux.append("gagnee %d.%d" % [c, i]))
	partie.salle_recommencee.connect(func(c: int, i: int) -> void: signaux.append("recommencee %d.%d" % [c, i]))
	partie.chapitre_termine.connect(func(c: int) -> void: signaux.append("fini %d" % c))
	await _jusqua(func() -> bool: return partie.phase == PH_JEU, 200)

	# --- Salle 1 : abattue AUX BALLES (un vrai tir de J1, vers le PNJ immobile).
	main.p1.global_position = NavigationBot.centre_de_la_case(Vector2i(8, 8))
	main.p1.rotation = 0.0
	await _images(2)
	var pnj: Node = partie.pnj[0]
	var salves := 0
	while not pnj.dead and salves < 12:
		main.spawn_bullet(main.p1, main.p1.global_position + Vector2(30.0, 0.0), 0.0, main.p1.current_weapon)
		salves += 1
		await _images(24)
	_check("le PNJ de la salle 1 est abattu par les balles du joueur", pnj.dead, "%d salves" % salves)
	await _images(2)
	_check("un PNJ abattu sort du jeu : caché, sans collision", not pnj.visible and not pnj.get_collision_layer_value(1))
	_check("tant que le dernier PNJ vient de tomber, la salle est GAGNÉE (délai : on voit la salle vide)", partie.phase == PH_GAGNEE
		and partie.index == 0)
	await _jusqua(func() -> bool: return partie.index == 1, 200)
	_check("puis la salle SUIVANTE se charge (index 1) : sa carte (18 × 14), son carton, deux PNJ", partie.index == 1
		and MapCodec.get_grid_size(root.get_node("MapData").get_selected()) == Vector2i(18, 14) and partie.phase == PH_CARTON
		and partie.pnj.size() == 2 and partie._carton.texte()["titre"] == "La ronde")
	_check("… la salle 1 est notée réussie dans la progression, et la 2 est ouverte", prog.niveau_reussi(0, 0) and prog.niveau_ouvert(0, 1)
		and not prog.niveau_ouvert(0, 2) and signaux == ["gagnee 0.0"], str(signaux))
	_check("… les plafonniers de la salle 1 ont disparu (la salle 2 n'en a pas) : le conteneur est vide, le groupe aussi",
		get_nodes_in_group("plafonniers").is_empty() and (main.arena.get_node_or_null("Plafonniers") == null
		or main.arena.get_node("Plafonniers").get_child_count() == 0))
	_check("… le joueur est à la case de départ de la salle 2, plein de vie", main.p1.global_position.distance_to(NavigationBot.centre_de_la_case(Vector2i(2, 7))) < 1.0
		and main.p1.hp == 100.0)
	var p_ronde: Node = partie.pnj[0]
	var p_zone: Node = partie.pnj[1]
	await _images(3)
	var pool_cache := true
	for j in range(4, _la_presentation()._corps.size()):
		pool_cache = pool_cache and not _la_presentation()._corps[j].visible
	_check("le pool de la salle d'avant (7 corps) n'en montre que deux : les corps 4 à 6, que personne ne porte, sont cachés", _la_presentation()._corps.size() == 7
		and pool_cache and _la_presentation()._corps[2].visible and _la_presentation()._corps[3].visible)
	_check("les deux PNJ de la salle 2 : une ronde et une zone, aux cases du niveau", (p_ronde.input_provider as BotInputProvider).profil.deplacement == ProfilBot.Deplacement.RONDE
		and (p_zone.input_provider as BotInputProvider).profil.deplacement == ProfilBot.Deplacement.ZONE
		and p_ronde.global_position.distance_to(NavigationBot.centre_de_la_case(Vector2i(14, 3))) < 1.0)
	await _jusqua(func() -> bool: return partie.phase == PH_JEU, 200)
	# --- La ronde marche, dans le vrai jeu.
	var depart: Vector2 = p_ronde.global_position
	await _images(120)
	_check("le PNJ de ronde MARCHE (deux secondes simulées)", p_ronde.global_position.distance_to(depart) > 40.0, str(p_ronde.global_position.distance_to(depart)))
	var corps_iso: Node3D = _la_presentation()._corps[2]
	var voxel: Node3D = _la_presentation()._voxels[2]
	_check("… et son corps iso le suit (posé à sa place d'cette image)", Vector2(voxel.position.x, voxel.position.z).distance_to(
		p_ronde.global_position / float(CandelaTileSet.TILE_SIZE.x)) < 0.05 and corps_iso.visible)

	# --- Mourir recommence LA SALLE (la 2), PNJ remis à leur départ.
	var carte_2: Dictionary = root.get_node("MapData").get_selected().duplicate(true)
	var anciens: Array[int] = [partie.pnj[0].get_instance_id(), partie.pnj[1].get_instance_id()]
	p_zone.take_damage(999.0, main.p1)
	await _images(3)
	_check("(un des deux PNJ est tombé avant la mort du joueur)", p_zone.dead and not p_ronde.dead)
	main.p1.take_damage(999.0, p_ronde)
	await _images(3)
	_check("le joueur mort : la salle n'est ni gagnée ni passée, on attend avant de recommencer", partie.phase == PH_ABATTU
		and partie.index == 1 and partie.morts == 1)
	_check("… et rien n'est noté réussi pour la salle 2", not prog.niveau_reussi(0, 1))
	await _jusqua(func() -> bool: return partie.essais == 2, 300)
	_check("la salle est RECOMMENCÉE : même index, deuxième essai, carton", partie.index == 1 and partie.essais == 2 and partie.phase == PH_CARTON
		and partie._carton.texte()["entete"].contains("ESSAI 2"), str(partie._carton.texte()))
	var nouveaux: Array[int] = [partie.pnj[0].get_instance_id(), partie.pnj[1].get_instance_id()]
	_check("les PNJ sont des corps NEUFS (aucun ancien nœud), tous deux vivants, pleins de vie", nouveaux[0] != anciens[0] and nouveaux[1] != anciens[1]
		and not partie.pnj[0].dead and not partie.pnj[1].dead and partie.pnj[0].hp == 100.0 and partie.pnj[1].hp == 100.0 and partie.pnj[1].visible
		and partie.pnj[1].get_collision_layer_value(1))
	_check("… remis à leur DÉPART (la ronde à son premier point, la zone à sa case)", partie.pnj[0].global_position.distance_to(NavigationBot.centre_de_la_case(Vector2i(14, 3))) < 1.0
		and partie.pnj[1].global_position.distance_to(NavigationBot.centre_de_la_case(Vector2i(12, 9))) < 1.0)
	_check("… la carte est inchangée (le même dictionnaire)", root.get_node("MapData").get_selected() == carte_2)
	_check("… le joueur est revenu à sa case, vivant, plein de vie, ses munitions pleines", not main.p1.dead and main.p1.hp == 100.0
		and main.p1.global_position.distance_to(NavigationBot.centre_de_la_case(Vector2i(2, 7))) < 1.0
		and main.p1.current_ammo == main.p1.current_weapon.max_ammo)
	_check("… le signal « salle recommencée » est parti, pas celui d'une salle gagnée", signaux == ["gagnee 0.0", "recommencee 0.1"], str(signaux))
	_check("… il n'y a AUCUN PNJ de l'essai d'avant dans l'arbre (ni dans le groupe `players`) : deux PNJ, `PNJ_0` et `PNJ_1`",
		_memes(_noms_des_pnj_du_groupe(), ["PNJ_0", "PNJ_1"]), str(_noms_des_pnj_du_groupe()))
	await _jusqua(func() -> bool: return partie.phase == PH_JEU, 200)

	# --- Salle 2 gagnée (appel direct), salle 3 : le boss.
	for p in partie.pnj.duplicate():
		p.take_damage(999.0, main.p1)
	await _jusqua(func() -> bool: return partie.index == 2, 300)
	_check("la salle 3, le BOSS : sa carte (20 × 20), son carton, UN PNJ, deux plafonniers", partie.index == 2
		and MapCodec.get_grid_size(root.get_node("MapData").get_selected()) == Vector2i(20, 20) and partie.pnj.size() == 1
		and get_nodes_in_group("plafonniers").size() == 2 and partie._carton.texte()["entete"].contains("BOSS"), str(partie._carton.texte()))
	var boss: Node = partie.pnj[0]
	var bot := boss.input_provider as BotInputProvider
	var norm := ProfilBot.boss()
	_check("le boss porte le profil `ProfilBot.boss()` (voit, entend, tire, NORMAL) et la classe du chapitre (le Parasite)",
		bot.profil.voit and bot.profil.entend and bot.profil.tire and is_equal_approx(bot.profil.delai_reaction, norm.delai_reaction)
		and bot.profil.deplacement == ProfilBot.Deplacement.LIBRE and String(boss.current_weapon.slug()) == "pistolet")
	_check("le chapitre n'est pas fini, la classe n'est pas gagnée", not prog.chapitre_termine(0) and prog.classes_debloquees().is_empty())
	await _jusqua(func() -> bool: return partie.phase == PH_JEU, 200)
	boss.take_damage(999.0, main.p1)
	await _jusqua(func() -> bool: return partie.phase == PH_FINI, 300)
	_check("le boss tombé : le CHAPITRE est fini", partie.chapitre_fini and prog.chapitre_termine(0) and prog.niveau_reussi(0, 2), str(prog.niveaux_reussis(0)))
	_check("la classe du chapitre est DÉBLOQUÉE (le Parasite), ni plus ni moins", _memes(prog.classes_debloquees(), ["pistolet"]), str(prog.classes_debloquees()))
	var relue := Progression.new(SOLO_DE_LA_SUITE)
	_check("… et c'est ÉCRIT dans le fichier de progression (relu d'un autre objet)", relue.chapitre_termine(0) and relue.niveaux_reussis(0).size() == 3
		and relue.classe_debloquee("pistolet") and not relue.classe_debloquee("fumiste"))
	_check("le carton de fin dit le chapitre terminé et la classe gagnée", partie._carton.visible and partie._carton.texte()["entete"].contains("TERMINÉ")
		and partie._carton.texte()["phrase"].contains("Le Parasite"), str(partie._carton.texte()))
	_check("les signaux : salle 1 gagnée, salle 2 recommencée puis gagnée, salle 3 gagnée, chapitre fini",
		signaux == ["gagnee 0.0", "recommencee 0.1", "gagnee 0.1", "gagnee 0.2", "fini 0"], str(signaux))
	await _jusqua(func() -> bool: return main.aventure == null, 300)
	_check("à la fin du carton : retour à l'écran de l'AVENTURE (le hub, au menu), la partie démontée", main.aventure == null and ui._is_main_menu
		and ui.hub.current_id() == ui.SCREEN_AVENTURE, "%s %s" % [str(main.aventure), ui.hub.current_id()])
	await _images(3)
	_check("… PNJ, plafonniers et carton partis", main.figurants.is_empty() and get_nodes_in_group("plafonniers").is_empty()
		and _noms_des_pnj_du_groupe().is_empty() and main.get_node_or_null("CartonAventure") == null and main.get_node_or_null("Aventure") == null)
	_check("… et la carte du joueur est rendue", root.get_node("MapData").selected_map_id != "aventure")


func _noms_des_pnj_du_groupe() -> Array[String]:
	var noms: Array[String] = []
	for n in get_nodes_in_group("players"):
		if bool(n.get("est_pnj")):
			noms.append(String(n.name))
	noms.sort()
	return noms


# ---------------------------------------------------------------------------
# ON LA QUITTE PROPREMENT
# ---------------------------------------------------------------------------

func _on_la_quitte_proprement() -> void:
	print("\n--- On la quitte proprement : le menu, l'entraînement, le duel ---")
	var cartes := root.get_node("MapData")
	cartes.select_map("default")
	var carte_du_joueur: String = cartes.selected_map_id
	# Quitter par la pause (le geste « QUITTER LE MATCH »).
	main.demarrer_l_aventure(chapitre, 0, "pistolet", prog)
	await _images(5)
	_check("(une partie d'aventure tourne)", main.aventure != null and get_nodes_in_group("plafonniers").size() == 1 and main.figurants.size() == 1)
	main._on_quit_match_requested()
	# SANS attendre une image : un `queue_free()` n'agit qu'en fin d'image, et la purge de l'arène du retour au menu en aurait libéré
	# les plafonniers de toute façon. Ce que la partie démontée doit avoir fait, c'est les retirer TOUT DE SUITE (de l'arbre et du groupe).
	_check("quitter le match, à l'instant même : plafonniers et PNJ sortis de leurs groupes (avant la fin de l'image)",
		get_nodes_in_group("plafonniers").is_empty() and _noms_des_pnj_du_groupe().is_empty() and main.figurants.is_empty())
	await _images(3)
	_check("quitter le match : partie démontée, PNJ et plafonniers retirés, carton parti, carte rendue",
		main.aventure == null and main.figurants.is_empty() and get_nodes_in_group("plafonniers").is_empty() and _noms_des_pnj_du_groupe().is_empty()
		and main.get_node_or_null("CartonAventure") == null and cartes.selected_map_id == carte_du_joueur and ui._is_main_menu)
	_check("… et le conteneur des plafonniers n'est plus dans l'arène", main.arena.get_node_or_null("Plafonniers") == null)

	# De l'aventure à l'ENTRAÎNEMENT, sans passer par le menu : la ceinture de `_do_start_round`.
	main.demarrer_l_aventure(chapitre, 0, "pistolet", prog)
	await _images(5)
	main._on_training_requested()
	await _images(4)
	_check("de l'aventure à l'entraînement : la partie s'arrête, PNJ et plafonniers partent", main.aventure == null and main.figurants.is_empty()
		and get_nodes_in_group("plafonniers").is_empty() and _noms_des_pnj_du_groupe().is_empty() and main.training_mode)
	_check("… l'entraînement est celui d'avant : la cible est là (cran 1), J2 est caché, une seule vue, la carte du joueur",
		main.training_target.visible and not main.p2.visible and main.vp1.get_parent().visible and not main.vp2.get_parent().visible
		and cartes.selected_map_id == carte_du_joueur)
	main._on_main_menu_requested()
	await _images(3)

	# De l'aventure à un DUEL en écran scindé.
	main.demarrer_l_aventure(chapitre, 0, "pistolet", prog)
	await _images(5)
	main._on_replay_requested()
	await _images(5)
	_check("de l'aventure à l'écran scindé : la partie s'arrête, les deux vues, deux joueurs", main.aventure == null and main.round_active
		and not main.training_mode and main.vp1.get_parent().visible and main.vp2.get_parent().visible and main.figurants.is_empty()
		and get_nodes_in_group("plafonniers").is_empty())
	_check("… J2 est EXACTEMENT comme avant : fournisseur local (touches de J2), visible, solide, plein de vie",
		_classe_de(main.p2.input_provider) == "LocalInputProvider" and main.p2.input_provider.device_id == 1 and main.p2.visible
		and main.p2.get_collision_layer_value(1) and main.p2.get_collision_mask_value(1) and main.p2.hp == 100.0 and not main.p2.dead)
	_check("… le joueur 1 aussi : fournisseur local, aucun PNJ dans le groupe", _classe_de(main.p1.input_provider) == "LocalInputProvider" and _noms_des_pnj_du_groupe().is_empty())
	var pres := _la_presentation()
	_check("… la vue iso rend deux joueurs, et aucun figurant (le pool reste, caché)", pres._figurants.is_empty() and pres._capteurs_figurants.is_empty()
		and _compte_capteurs(pres) == 4)
	main._on_main_menu_requested()
	await _images(3)
	_check("quitter le duel : tout est comme avant", main.aventure == null and main.figurants.is_empty())

	# Et un ENTRAÎNEMENT lancé depuis l'écran, par le geste, juste après une aventure.
	ui.hub.push(ui.SCREEN_TRAINING)
	await _images(2)
	ui._on_hub_action("cran_cible")
	ui._on_hub_action("entrainement")
	await _images(4)
	_check("un entraînement lancé par le geste après une aventure : cible immobile, J2 caché, sans PNJ", main.training_mode and main.training_target.visible
		and not main.p2.visible and _noms_des_pnj_du_groupe().is_empty() and main.aventure == null)
	main._on_main_menu_requested()
	await _images(3)


# ---------------------------------------------------------------------------
# L'ÉCRAN DE L'AVENTURE
# ---------------------------------------------------------------------------

func _libelle(btn: Button) -> String:
	for rangee in btn.get_children():
		for enfant in rangee.get_children():
			if enfant is Label and String((enfant as Label).text) not in ["›", "—"]:
				return String((enfant as Label).text)
	return ""


func _l_ecran() -> void:
	print("\n--- L'écran de l'aventure ---")
	_effacer(SOLO_DE_LA_SUITE)
	prog = Progression.new(SOLO_DE_LA_SUITE)
	ui.aventure_progression = prog
	ui.hub.reset()
	await _images(2)
	_check("l'accueil du hub a une entrée « AVENTURE » qui mène à l'écran de l'aventure", _entree_de_l_accueil("AVENTURE") != null)
	ui.hub.push(ui.SCREEN_AVENTURE)
	await _images(3)
	_check("l'écran s'ouvre (`SCREEN_AVENTURE`), et ses salles ont leur écran (`SCREEN_AVENTURE_SALLES`)", ui.hub.current_id() == ui.SCREEN_AVENTURE
		and ui.hub.has_screen(ui.SCREEN_AVENTURE_SALLES))
	_check("onze entrées de chapitre, 0 à 10", ui._entrees_chapitres.size() == 11)
	_check("le chapitre 0, écrit, porte son titre ; la coche dit qu'il est pris", _libelle(ui._entrees_chapitres[0]).begins_with("✓ CHAPITRE 0 — L'INITIATION (ESSAI)"),
		_libelle(ui._entrees_chapitres[0]))
	_check("les chapitres 1 à 10, pas écrits, tiennent en UNE ligne « CHAPITRES 1 À 10 — À VENIR » (aucun contenu inventé : pas même un titre)",
		_libelle(ui._entrees_chapitres[1]) == "CHAPITRES 1 À 10 — À VENIR" and ui._entrees_chapitres[1].visible, _libelle(ui._entrees_chapitres[1]))
	var visibles_chapitres := 0
	for e in ui._entrees_chapitres:
		if e.visible:
			visibles_chapitres += 1
	_check("… les neuf autres lignes sont cachées : deux lignes de chapitre à l'écran, pas onze (le hub ne défile pas)", visibles_chapitres == 2, str(visibles_chapitres))
	# Un appui sur un chapitre à venir ne prend rien ; sur un chapitre ouvert il le prend et descend à ses salles.
	ui._on_hub_action("aventure_chapitre_1")
	_check("un appui sur « À VENIR » ne prend rien et ne descend pas", ui.aventure_chapitre == 0 and ui.hub.current_id() == ui.SCREEN_AVENTURE)
	ui._on_hub_action("aventure_chapitre_0")
	await _images(3)
	_check("un appui sur un chapitre OUVERT le prend et descend à l'écran de ses salles", ui.aventure_chapitre == 0
		and ui.hub.current_id() == ui.SCREEN_AVENTURE_SALLES)
	var visibles := 0
	for e in ui._entrees_niveaux:
		if e.visible:
			visibles += 1
	_check("trois salles visibles (celles du chapitre), les autres entrées cachées", visibles == 3)
	_check("la salle 1 est ouverte et prise, les salles 2 et 3 sont FERMÉES", _libelle(ui._entrees_niveaux[0]).begins_with("✓ SALLE 1 — SOUS LA LAMPE")
		and _libelle(ui._entrees_niveaux[1]).ends_with("(FERMÉE)") and _libelle(ui._entrees_niveaux[2]).contains("BOSS")
		and _libelle(ui._entrees_niveaux[2]).ends_with("(FERMÉE)"), "%s | %s | %s" % [_libelle(ui._entrees_niveaux[0]), _libelle(ui._entrees_niveaux[1]), _libelle(ui._entrees_niveaux[2])])
	ui._on_hub_action("aventure_niveau_2")
	_check("un appui sur une salle fermée ne prend rien", ui.aventure_niveau == 0)
	# Le râtelier : le chapitre 0 PRÊTE le Parasite — lui seul est libre.
	var libres: Array[String] = []
	for btn in ui.p1_weapon_buttons:
		if not btn.disabled:
			libres.append(String(ui._catalogue_classes()[int(btn.get_meta(ui.META_CLASSE_INDEX))].slug()))
	_check("au chapitre 0, le râtelier ne laisse libre que le Parasite (la classe prêtée)", _memes(libres, ["pistolet"]), str(libres))
	_check("la description de la salle est dans la colonne du salon, et l'affiche d'une autre carte n'y est pas", ui.lobby_status_label.visible
		and ui.lobby_status_label.text.contains("SOUS LA LAMPE") and ui.lobby_status_label.text.contains("Classe prêtée") and not ui.map_card.visible,
		ui.lobby_status_label.text)
	_check("le lanceur du cadre dit « LANCER LA SALLE » et lance l'aventure — sur l'écran des salles comme sur celui des chapitres",
		ui.panel_launch.visible and ui.panel_launch.text == "LANCER LA SALLE"
		and String(ui.panel_launch.get_meta(ui.META_LAUNCH_ACTION)) == "aventure" and not ui.panel_launch.disabled)
	ui.hub.back()
	await _images(2)
	_check("le retour des salles aux chapitres ne remet pas le choix à zéro", ui.hub.current_id() == ui.SCREEN_AVENTURE and ui.aventure_chapitre == 0)
	_check("… et le lanceur y est aussi", ui.panel_launch.visible and ui.panel_launch.text == "LANCER LA SALLE")
	# Réussir la salle 1 ouvre la 2 (et l'écran le dit à la réouverture, depuis l'accueil).
	prog.reussir_niveau(0, 0)
	ui.hub.back()
	await _images(2)
	ui.hub.push(ui.SCREEN_AVENTURE)
	await _images(3)
	ui._on_hub_action("aventure_chapitre_0")
	await _images(3)
	_check("après la salle 1 réussie : elle est « RÉUSSIE », la 2 est ouverte et proposée (le prochain à jouer)", _libelle(ui._entrees_niveaux[0]).ends_with("(RÉUSSIE)")
		and _libelle(ui._entrees_niveaux[1]).begins_with("✓ SALLE 2") and ui.aventure_niveau == 1, "%s | %s" % [_libelle(ui._entrees_niveaux[0]), _libelle(ui._entrees_niveaux[1])])
	ui._on_hub_action("aventure_niveau_0")
	_check("une salle réussie se REJOUE : un appui la reprend", ui.aventure_niveau == 0)
	ui._on_hub_action("aventure_niveau_1")
	# Le geste qui lance, par le lanceur du cadre, depuis l'écran des salles.
	var lancees := [0]
	ui.aventure_requested.connect(func() -> void: lancees[0] += 1)
	ui.panel_launch.pressed.emit()
	await _images(4)
	_check("le bouton du cadre LANCE l'aventure (signal, puis la partie, à la salle prise)", lancees[0] == 1 and main.aventure != null and main.aventure.index == 1
		and main.aventure.classe_slug == "pistolet" and main.training_mode)
	_check("la pause « QUITTER LE MATCH » ramènerait à l'écran d'où l'on est parti (celui des salles)", ui.match_origin_screen() == ui.SCREEN_AVENTURE_SALLES,
		ui.match_origin_screen())
	main._on_main_menu_requested()
	await _images(3)

	# --- Le choix libre de la classe : un chapitre qui n'en impose pas. Deux chapitres écrits dans un dossier à la suite (copie du chapitre d'essai).
	print("\n--- Le choix libre de la classe parmi les débloquées ---")
	_supprimer(TEMP)
	var racine := TEMP.path_join("racine")
	for n in [0, 1]:
		var d := racine.path_join("chapitre_%02d" % n)
		DirAccess.make_dir_recursive_absolute(d)
		var m: Dictionary = Format.lire_chapitre(ESSAI.path_join("chapitre_00"))["manifeste"].duplicate(true)
		m["numero"] = n
		m["titre"] = "Chapitre %d d'essai" % n
		m["classe_debloquee"] = Format.ORDRE_DES_CLASSES[n]
		if n == 1:
			m.erase("classe_imposee")
		_ecrire(d.path_join("chapitre.json"), m)
		for f in ["niveau_01.json", "niveau_02.json", "niveau_03.json"]:
			var niveau: Dictionary = Format.lire_chapitre(ESSAI.path_join("chapitre_00"))["niveaux"][int(f.substr(7, 2)) - 1].duplicate(true)
			if f == "niveau_03.json":
				niveau["pnj"][0]["classe"] = Format.ORDRE_DES_CLASSES[n]
			_ecrire(d.path_join(f), niveau)
	Format.racine = racine
	Format.oublier_le_cache()
	_effacer(SOLO_DE_LA_SUITE)
	prog = Progression.new(SOLO_DE_LA_SUITE)
	ui.aventure_progression = prog
	ui.aventure_chapitre = 0
	ui.aventure_niveau = 0
	ui.hub.reset()
	await _images(2)
	ui.hub.push(ui.SCREEN_AVENTURE)
	await _images(3)
	_check("deux chapitres écrits : « FERMÉ » pour le 1 tant que le 0 n'est pas fini, une ligne « À VENIR » pour 2 à 10", _libelle(ui._entrees_chapitres[1]).ends_with("(FERMÉ)")
		and _libelle(ui._entrees_chapitres[2]) == "CHAPITRES 2 À 10 — À VENIR" and not ui._entrees_chapitres[3].visible, _libelle(ui._entrees_chapitres[1]))
	ui._on_hub_action("aventure_chapitre_1")
	_check("un chapitre fermé ne se prend pas, et ne descend pas", ui.aventure_chapitre == 0 and ui.hub.current_id() == ui.SCREEN_AVENTURE)
	prog.reussir_niveau(0, 0)
	prog.reussir_niveau(0, 1)
	prog.reussir_niveau(0, 2)
	prog.terminer_chapitre(0)
	ui.hub.back()
	await _images(2)
	ui.hub.push(ui.SCREEN_AVENTURE)
	await _images(3)
	_check("le chapitre 0 fini : il est « TERMINÉ », le chapitre 1 est ouvert ET proposé (le premier ouvert non fini)", _libelle(ui._entrees_chapitres[0]).ends_with("(TERMINÉ)")
		and ui.aventure_chapitre == 1 and _libelle(ui._entrees_chapitres[1]).begins_with("✓ CHAPITRE 1"), "%s %d" % [_libelle(ui._entrees_chapitres[0]), ui.aventure_chapitre])
	var libres_1: Array[String] = []
	var verrouilles := 0
	for btn in ui.p1_weapon_buttons:
		var slug := String(ui._catalogue_classes()[int(btn.get_meta(ui.META_CLASSE_INDEX))].slug())
		if not btn.disabled:
			libres_1.append(slug)
		elif btn.tooltip_text.begins_with("Se gagne en finissant le chapitre"):
			verrouilles += 1
	_check("au chapitre 1 (qui n'impose rien) : le Parasite, gagné, est libre ; les neuf autres sont verrouillées, et disent où se gagner", libres_1.size() == 1
		and libres_1[0] == "pistolet" and verrouilles == 9, "%s %d" % [str(libres_1), verrouilles])
	var choix: Dictionary = ui.aventure_choix()
	_check("`aventure_choix()` rend le chapitre CHARGÉ, la salle prise et la classe jouée", choix.get("niveau", -1) == 0 and choix.get("classe", "") == "pistolet"
		and int(choix["chapitre"]["numero"]) == 1, str(choix.keys()))
	_check("… et note la classe choisie dans la progression (la prochaine ouverture la reproposera)", prog.classe_choisie() == "pistolet")
	# Finir le chapitre 1 débloque le Fumiste : on peut le choisir.
	for i in 3:
		prog.reussir_niveau(1, i)
	prog.terminer_chapitre(1)
	ui.hub.back()
	await _images(2)
	ui.hub.push(ui.SCREEN_AVENTURE)
	await _images(3)
	var fumiste_libre := false
	var fumiste_idx := -1
	for btn in ui.p1_weapon_buttons:
		var idx := int(btn.get_meta(ui.META_CLASSE_INDEX))
		if String(ui._catalogue_classes()[idx].slug()) == "fumiste":
			fumiste_libre = not btn.disabled
			fumiste_idx = idx
	_check("le chapitre 1 fini : le Fumiste est débloqué, son bouton est libre", fumiste_libre and prog.classe_debloquee("fumiste"))
	ui.set_weapon_selection(0, fumiste_idx)
	choix = ui.aventure_choix()
	_check("on peut CHOISIR le Fumiste : le choix le rend, et le note", choix.get("classe", "") == "fumiste" and prog.classe_choisie() == "fumiste")
	ui.panel_launch.pressed.emit()
	await _images(4)
	_check("lancée, la partie se joue dans la classe choisie (le Fumiste)", main.aventure != null and String(main.p1.current_weapon.slug()) == "fumiste")
	_check("… et le chapitre 1 ne prête rien : le Parasite n'est plus imposé", main.aventure.chapitre["classe_imposee"] == "")
	main._on_main_menu_requested()
	await _images(3)
	# Le chapitre 0, lui, se rejoue toujours dans le Parasite prêté — même avec le Fumiste en poche.
	ui.aventure_chapitre = 0
	ui._on_hub_action("aventure_chapitre_0")
	ui.set_weapon_selection(0, fumiste_idx)
	choix = ui.aventure_choix()
	_check("le chapitre 0 rejoué : la classe est le Parasite PRÊTÉ, quel que soit le choix du râtelier", choix.get("classe", "") == "pistolet")
	# Retour à la racine livrée.
	Format.racine = ESSAI
	Format.oublier_le_cache()


## Deux listes de mêmes éléments dans le même ordre, typées ou non.
func _memes(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


## Le nom de classe global d'un nœud (`""` s'il n'en a pas) : on ne nomme pas la classe, on lit son nom.
func _classe_de(n: Object) -> String:
	if n == null or n.get_script() == null:
		return ""
	return String((n.get_script() as Script).get_global_name())


func _entree_de_l_accueil(titre: String) -> Button:
	var liste: Control = ui.hub.list_of(ui.hub.ROOT)
	for e in liste.get_children():
		if e is Button and _libelle(e) == titre:
			return e
	return null


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


## Attend que la condition soit vraie, au plus `max_images` images : une suite qui attend sans fin est pire qu'une suite rouge.
func _jusqua(cond: Callable, max_images: int) -> bool:
	for _i in max_images:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _ecrire(chemin: String, donnees: Dictionary) -> void:
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(JSON.stringify(donnees))
	f.close()


func _effacer(chemin: String) -> void:
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(chemin)


func _supprimer(dossier: String) -> void:
	if not DirAccess.dir_exists_absolute(dossier):
		return
	for f in DirAccess.get_files_at(dossier):
		DirAccess.remove_absolute(dossier.path_join(f))
	for d in DirAccess.get_directories_at(dossier):
		_supprimer(dossier.path_join(d))
	DirAccess.remove_absolute(dossier)


func _sortir() -> void:
	print("\n%d vérifications" % _verifications)
	print("CRIS ATTENDUS: %d" % _cris_voulus)
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
