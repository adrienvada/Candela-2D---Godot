## Garde du cran « adversaire mobile » de l'entraînement — chantier SOLO, étape S1.
##
## Le vrai jeu, monté (vue iso allumée, comme un joueur), et le vrai `_on_training_requested()`, lancé par le geste que
## le joueur fait (l'entrée de l'écran d'entraînement, puis le lanceur). Ce que la suite prouve, carte livrée par carte
## livrée :
##
##   • le cran mobile cache la cible et remet J2 en jeu — visible, solide — piloté par un `BotInputProvider` nommé
##     `BotP2`, posé loin du joueur ;
##   • le bot AVANCE : en N secondes simulées il parcourt une distance au-dessus d'un seuil, par un vrai corps (36 px, un
##     nez, des murs qui glissent), sans jamais quitter le sol ;
##   • il n'est JAMAIS bloqué plus de T secondes ;
##   • il n'émet aucune balle, n'allume pas sa torche, ne tire ni ne recharge ;
##   • abattu, il revient au bout de ~2 s, avec toute sa vie, loin du joueur — et repart ;
##   • repasser à « cible immobile » rend la cible et recache J2, qui reprend son fournisseur local ;
##   • un match en écran scindé lancé APRÈS un entraînement mobile trouve J2 EXACTEMENT comme avant tout entraînement :
##     fournisseur local de J2, corps visible et solide, plein de vie, au point d'apparition ;
##   • le bot n'est pas un adversaire pour la règle du sang : les traces d'une même carte survivent au passage à lui.
##
## ⚠️ **Se lance à pas d'image fixe** (`--fixed-fps 60`, comme `test_iso_camera`) : une « seconde simulée » est alors
## soixante images, un pas de physique chacune. Sans lui, un Godot headless déroule les images bien plus vite que
## l'horloge et la physique ne ferait que quelques pas — la distance parcourue ne mesurerait plus rien. La suite
## refuse de conclure si l'horloge n'est pas fixe.
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_entrainement_bot.gd
extends SceneTree

const Nav := preload("res://navigation_bot.gd")
const Bot := preload("res://bot_input_provider.gd")

## Les secondes simulées par carte, et le seuil de distance parcourue. À l'allure de 0,7, un bot qui ne s'arrête jamais
## fait 182 px/s : 20 s ≈ 3 640 px. Le seuil est le TIERS de ce maximum — il tolère les contournements, les
## demi-tours et les glissements, mais pas un bot qui piétine ou reste figé.
const SECONDES := 20.0
const DISTANCE_MIN_PX := 1200.0
## « Bloqué » : moins de 10 px de déplacement pendant ce temps. Le bot détecte lui-même un blocage en 0,6 s et replanifie ;
## T est large, pour ne rougir que sur un vrai piégeage — un bot qui s'acharne contre un mur.
const T_BLOQUE_MAX := 3.0
const PAS := 1.0 / 60.0

var _failures := 0
var _verifications := 0


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
	print("=== L'ENTRAÎNEMENT À ADVERSAIRE MOBILE (S1) ===")
	await process_frame
	var horloge_fixe := await _horloge_fixe()
	_check("l'horloge est fixe (--fixed-fps 60) : une image = un pas de physique", horloge_fixe,
		"lancer avec --fixed-fps 60 : sans lui la physique ne ferait pas un pas par image")
	if not horloge_fixe:
		_sortir()
		return
	var reglages := root.get_node("GameSettings")
	var cartes := root.get_node("MapData")
	reglages.mode_iso = true
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	var ui: Node = main.ui

	# --- L'état d'AVANT tout entraînement : un match en écran scindé, lancé comme le joueur le lance.
	print("\n--- Le point de départ : un écran scindé, avant tout entraînement ---")
	cartes.select_map(cartes.DEFAULT_MAP_ID)
	main._on_main_menu_requested()
	await _images(2)
	main._on_replay_requested()
	await _images(3)
	_check("l'écran scindé démarre : manche active, hors entraînement", main.round_active and not main.training_mode)
	var avant := _etat_de_j2(main)
	_check("J2 est piloté par un fournisseur local (touches de J2)",
		avant["fournisseur"] == "LocalInputProvider" and avant["device"] == 1, str(avant))
	_check("… visible, solide, plein de vie, vivant", avant["visible"] and avant["calque"] and avant["masque"]
		and avant["hp"] == 100.0 and not avant["mort"], str(avant))
	main._on_main_menu_requested()
	await _images(3)

	# --- Chaque carte livrée : le cran mobile, lancé par le geste.
	var livrees: Array[Dictionary] = []
	for entree in cartes.list_maps():
		if String(entree["source"]) == "builtin":
			livrees.append(entree)
	_check("le catalogue livre plusieurs cartes", livrees.size() >= 5, str(livrees.size()))
	var premiere := true
	var tirs := 0
	for entree in livrees:
		var id := String(entree["id"])
		var nom := String(entree["name"])
		print("\n--- %s ---" % nom)
		_check("« %s » est choisie" % nom, cartes.select_map(id))
		ui.hub.push(ui.SCREEN_TRAINING)
		await _images(2)
		# Le geste : l'entrée « ADVERSAIRE MOBILE », puis le lanceur — pas un appel direct.
		ui._on_hub_action("cran_mobile")
		await _images(1)
		if premiere:
			_check("l'entrée « ADVERSAIRE MOBILE » porte la coche, l'autre non",
				_libelle_du_cran(ui, ui.CRAN_ADVERSAIRE_MOBILE).begins_with("✓")
				and not _libelle_du_cran(ui, ui.CRAN_CIBLE_IMMOBILE).begins_with("✓"),
				"%s / %s" % [_libelle_du_cran(ui, ui.CRAN_ADVERSAIRE_MOBILE), _libelle_du_cran(ui, ui.CRAN_CIBLE_IMMOBILE)])
		main.graine_du_bot = 2026
		ui._on_hub_action("entrainement")
		# Le lancement est synchrone : la place du bot se lit AVANT la moindre image, qui le ferait déjà marcher.
		var place_au_lancement: Vector2 = main.p2.global_position
		var apparition: Vector2 = main._get_spawn_position(1)
		await _images(3)
		_check("« %s » : au point d'apparition de J2 à l'instant du lancement" % nom,
			place_au_lancement.distance_to(apparition) < 1.0, "%s au lieu de %s" % [place_au_lancement, apparition])
		tirs += await _un_entrainement_mobile(main, entree, nom)
		premiere = false
		main._on_main_menu_requested()
		await _images(2)
	_check("aucun tir du bot sur toutes les cartes", tirs == 0, "%d images avec une balle ou une recharge" % tirs)

	# --- Le tunnel d'une tuile de l'Usine : le corps ne le passe pas, le bot ne s'y engage pas.
	print("\n--- Le tunnel d'une tuile de l'Usine ---")
	cartes.select_map("map_002")
	ui.hub.push(ui.SCREEN_TRAINING)
	await _images(2)
	ui._on_hub_action("cran_mobile")
	main.graine_du_bot = 11
	ui._on_hub_action("entrainement")
	await _images(3)
	await _le_corps_ne_passe_pas_une_case_etranglee(main)
	await _le_bot_contourne_le_tunnel(main)

	# --- La mort, la réapparition, loin du joueur.
	print("\n--- Abattu, il revient ---")
	cartes.select_map(CARTE_DE_LA_MORT)
	ui.hub.push(ui.SCREEN_TRAINING)
	await _images(2)
	ui._on_hub_action("cran_mobile")
	main.graine_du_bot = 7
	ui._on_hub_action("entrainement")
	await _images(3)
	await _la_mort_et_le_retour(main)

	# --- Le sang : le bot n'est pas un adversaire.
	print("\n--- Le bot n'est pas un adversaire pour la règle du sang ---")
	await _le_sang(main, ui, cartes)

	# --- Retour à la cible immobile.
	print("\n--- Retour à « cible immobile » ---")
	await _retour_a_la_cible(main, ui, cartes)

	# --- Après un entraînement mobile : écran scindé, comme avant.
	print("\n--- Après un entraînement mobile, l'écran scindé retrouve J2 comme avant ---")
	await _apres_le_mobile(main, ui, cartes, avant)

	cartes.select_map(cartes.DEFAULT_MAP_ID)
	_sortir()


const CARTE_DE_LA_MORT := "map_001"


## Soixante images font-elles soixante pas de physique ? C'est la définition de l'horloge fixe, et la seule qui se
## MESURE : `OS.get_cmdline_args()` ne dit pas si le moteur a pris l'option.
func _horloge_fixe() -> bool:
	var f0 := Engine.get_physics_frames()
	for _i in 60:
		await process_frame
	return absi(int(Engine.get_physics_frames() - f0) - 60) <= 1


func _libelle_du_cran(ui: Node, cran: int) -> String:
	var btn: Button = ui._entree_cran[cran]
	for rangee in btn.get_children():
		for enfant in rangee.get_children():
			if enfant is Label and String((enfant as Label).text) not in ["›", "—"]:
				return String((enfant as Label).text)
	return ""


## Ce qui décrit J2 « exactement » : de quoi le comparer d'un instant à l'autre.
func _etat_de_j2(main: Node) -> Dictionary:
	var p2 = main.p2
	var f = p2.input_provider
	return {
		"fournisseur": String(f.get_script().get_global_name()) if f != null else "",
		"device": int(f.get("device_id")) if f != null and f.get("device_id") != null else -1,
		"visible": p2.visible,
		"calque": p2.get_collision_layer_value(1),
		"masque": p2.get_collision_mask_value(1),
		"hp": p2.hp,
		"mort": p2.dead,
		"rotation": snappedf(p2.rotation, 0.001),
		"position": p2.global_position.snapped(Vector2(0.5, 0.5)),
		"arme": p2.current_weapon,
		"munitions": p2.current_ammo,
	}


## Un entraînement mobile sur une carte : les états de départ, puis 20 s de marche surveillée. Rend le nombre d'images
## où une balle existait ou où le bot rechargeait.
func _un_entrainement_mobile(main: Node, entree: Dictionary, nom: String) -> int:
	var p1 = main.p1
	var p2 = main.p2
	var nav := Nav.depuis_carte(entree["data"])
	_check("« %s » : entraînement armé, sans manche" % nom,
		main.training_mode and main.sandbox_mode and not main.round_active)
	_check("« %s » : la cible est cachée, inerte, sans collision" % nom,
		not main.training_target.visible and main.training_target.process_mode == Node.PROCESS_MODE_DISABLED
		and not main.training_target.get_collision_layer_value(1))
	_check("« %s » : J2 est en jeu — visible et solide" % nom,
		p2.visible and p2.get_collision_layer_value(1) and p2.get_collision_mask_value(1))
	var bot = p2.get_node_or_null("BotP2")
	_check("« %s » : J2 est piloté par un BotInputProvider nommé BotP2" % nom,
		bot != null and bot is Bot and p2.input_provider == bot, str(p2.input_provider))
	_check("« %s » : P1 garde son fournisseur local" % nom, p1.input_provider is LocalInputProvider)
	_check("« %s » : le bot est sur une case praticable" % nom,
		nav.est_praticable(Nav.case_du_monde(p2.global_position)), str(p2.global_position))
	var distance_depart: float = p1.global_position.distance_to(p2.global_position)
	_check("« %s » : posé loin du joueur (%.0f px, au moins 6 cases)" % [nom, distance_depart], distance_depart >= 6.0 * 35.0)
	_check("« %s » : sa torche est éteinte, sa classe est celle par défaut" % nom,
		not p2.flashlight_on and p2.current_weapon == main.weapon_for_index(0))

	# Vingt secondes de marche, surveillées image par image.
	var distance := 0.0
	var depart_pos: Vector2 = p2.global_position
	var precedent := depart_pos
	var hors_sol := 0
	var images_en_marche := 0
	var tirs := 0
	var torche := 0
	var ref_pos := depart_pos
	var ref_t := 0.0
	var pire_blocage := 0.0
	var t := 0.0
	var vu_hors_sol := ""
	for _i in int(round(SECONDES / PAS)):
		await process_frame
		t += PAS
		var pos: Vector2 = p2.global_position
		var pas := pos.distance_to(precedent)
		if pas < 100.0:
			distance += pas
		precedent = pos
		if not nav.est_libre(Nav.case_du_monde(pos)):
			hors_sol += 1
			if vu_hors_sol == "":
				vu_hors_sol = "%s (case %s)" % [pos, Nav.case_du_monde(pos)]
		if bot.get_movement_vector() != Vector2.ZERO:
			images_en_marche += 1
		if main.bullet_container.get_child_count() > 0 or p2.is_reloading \
				or p2.current_ammo != p2.current_weapon.max_ammo:
			tirs += 1
		if p2.flashlight_on:
			torche += 1
		if pos.distance_to(ref_pos) > 10.0:
			ref_pos = pos
			ref_t = t
		pire_blocage = maxf(pire_blocage, t - ref_t)
	var seuil_images := int(0.8 * SECONDES / PAS)
	_check("« %s » : %.0f px parcourus en %.0f s simulées (seuil %.0f)" % [nom, distance, SECONDES, DISTANCE_MIN_PX],
		distance >= DISTANCE_MIN_PX, "%.0f px" % distance)
	_check("« %s » : il a reçu une consigne de marche presque tout le temps (%d images sur %d)" % [nom, images_en_marche, int(SECONDES / PAS)],
		images_en_marche >= seuil_images)
	_check("« %s » : le centre du corps n'a jamais quitté une case libre" % nom, hors_sol == 0,
		"%d images hors sol, la première en %s" % [hors_sol, vu_hors_sol])
	_check("« %s » : jamais bloqué plus de %.0f s (pire : %.2f s)" % [nom, T_BLOQUE_MAX, pire_blocage],
		pire_blocage <= T_BLOQUE_MAX, "%.2f s" % pire_blocage)
	_check("« %s » : torche éteinte du début à la fin" % nom, torche == 0)
	_check("« %s » : le bot a une cible en cours" % nom, bot.cible_courante().x >= 0)
	print("    · %s : %.0f px, pire blocage %.2f s, %d blocages détectés par le bot" % [nom, distance, pire_blocage, bot.blocages_total])
	return tirs


## La PRÉMISSE de `navigation_bot.gd` : une case libre prise en étau entre deux solides opposés est infranchissable pour le
## vrai corps du joueur (36 px de large, des tuiles de 35). Si elle cessait d'être vraie — un corps plus étroit, un
## élargissement des tuiles —, le bot s'interdirait des passages pour rien, et cette garde le dit : elle rougit quand le
## corps PASSE. Chaque case étranglée de l'Usine : le joueur (P1, vrai corps, vraie physique) pousse 1,5 s vers elle.
func _le_corps_ne_passe_pas_une_case_etranglee(main: Node) -> void:
	var nav := Nav.depuis_carte(root.get_node("MapData").get_selected())
	var p = main.p1
	var essais := 0
	var passes := 0
	var pire := 0.0
	for y in nav.taille.y:
		for x in nav.taille.x:
			var c := Vector2i(x, y)
			if not nav.est_libre(c) or nav.est_praticable(c):
				continue
			var vertical := not nav.est_libre(c + Vector2i.LEFT) and not nav.est_libre(c + Vector2i.RIGHT)
			var dir := Vector2.DOWN if vertical else Vector2.RIGHT
			p.global_position = Nav.centre_de_la_case(c) - dir * 70.0
			p.rotation = dir.angle()
			for _i in 3:
				await physics_frame
			var depart: Vector2 = p.global_position
			for _i in 90:
				p.velocity = dir * 260.0
				p.move_and_slide()
				await physics_frame
			var avance: float = (p.global_position - depart).dot(dir)
			pire = maxf(pire, avance)
			essais += 1
			if avance > 100.0:
				passes += 1
	_check("l'Usine a des cases libres étranglées à éprouver (%d)" % essais, essais >= 8)
	_check("le vrai corps ne passe aucune d'elles (il avance de %.0f px au plus, sur 390 possibles)" % pire, passes == 0,
		"%d cases franchies" % passes)
	p.global_position = main._get_spawn_position(0)
	p.velocity = Vector2.ZERO
	await _images(2)


## Le bot, sur le vrai corps, ne s'engage pas dans le tunnel : sa ronde relie les deux bouts du tunnel de la rangée 11 (des
## cases (12, 11) et (19, 11)), il fait donc le tour par les salles du haut ou du bas — et ARRIVE.
func _le_bot_contourne_le_tunnel(main: Node) -> void:
	var p2 = main.p2
	var bot = p2.get_node("BotP2")
	var nav := Nav.depuis_carte(root.get_node("MapData").get_selected())
	var profil := ProfilBot.new()
	profil.deplacement = ProfilBot.Deplacement.RONDE
	var a := Vector2i(12, 11)
	var b := Vector2i(19, 11)
	var points: Array[Vector2i] = [a, b]
	profil.points_ronde = points
	profil.allure = 0.7
	bot.configurer(profil, nav, 1)
	p2.global_position = Nav.centre_de_la_case(a)
	p2.velocity = Vector2.ZERO
	p2.reset_step_tracker()
	await _images(3)
	var dans_le_tunnel := 0
	var arrivee := -1.0
	var ref_pos: Vector2 = p2.global_position
	var ref_t := 0.0
	var pire := 0.0
	var t := 0.0
	for _i in int(round(20.0 / PAS)):
		await process_frame
		t += PAS
		var c := Nav.case_du_monde(p2.global_position)
		if c.y == 11 and c.x >= 14 and c.x <= 17:
			dans_le_tunnel += 1
		if arrivee < 0.0 and p2.global_position.distance_to(Nav.centre_de_la_case(b)) < 20.0:
			arrivee = t
		if p2.global_position.distance_to(ref_pos) > 10.0:
			ref_pos = p2.global_position
			ref_t = t
		pire = maxf(pire, t - ref_t)
	_check("le bot ne met jamais le pied dans le tunnel d'une tuile (%d images)" % dans_le_tunnel, dans_le_tunnel == 0)
	_check("il arrive de l'autre côté en faisant le tour (%.1f s)" % arrivee, arrivee > 0.0 and arrivee < 15.0, "%.1f s" % arrivee)
	_check("sans être bloqué plus de %.0f s (pire : %.2f s)" % [T_BLOQUE_MAX, pire], pire <= T_BLOQUE_MAX)


func _la_mort_et_le_retour(main: Node) -> void:
	var p1 = main.p1
	var p2 = main.p2
	var nav := Nav.depuis_carte(root.get_node("MapData").get_selected())
	# Quelques secondes de vie, puis un tir qui tue — par le chemin des balles, `take_damage`.
	for _i in 120:
		await process_frame
	# Le joueur se tient sur le point d'apparition de J2 : c'est là que le bot reviendrait si « loin du joueur »
	# n'était pas respecté (le repli naïf d'une réapparition est la place d'apparition), donc ce qui discrimine.
	p1.global_position = main._get_spawn_position(1)
	await _images(2)
	p2.take_damage(500.0, p1)
	await _images(2)
	_check("abattu, le bot est mort (vie 0, `dead`)", p2.dead and p2.hp == 0.0)
	_check("… et la manche n'est pas finie : il n'y en a pas (entraînement)", not main.round_active and main.training_mode)
	await _images(int(1.5 / PAS))
	_check("1,5 s plus tard, il est encore mort", p2.dead)
	await _images(int(0.8 / PAS))
	_check("2,3 s plus tard, il est revenu : vivant, plein de vie", not p2.dead and p2.hp == 100.0)
	_check("… visible, solide", p2.visible and p2.get_collision_layer_value(1) and p2.get_collision_mask_value(1))
	_check("… ses visuels que la mort avait cachés sont rendus (les siens, ceux de l'adversaire, leurs pointeurs)",
		p2.visual.visible and p2.visual_ptr.visible and p2.visual_dim.visible and p2.visual_dim_ptr.visible
		and p2.visual_reveal.visible and p2.visual_reveal_ptr.visible and p2.visual_enemy.visible
		and p2.visual_reveal_enemy.visible and p2.get_node("VisualColored").visible and p2.get_node("VisualReveal").visible)
	_check("… munitions pleines", p2.current_ammo == p2.current_weapon.max_ammo)
	var d_joueur: float = p1.global_position.distance_to(p2.global_position)
	var plus_loin := 0.0
	for c in nav.cases_atteignables(Nav.case_du_monde(p2.global_position)):
		plus_loin = maxf(plus_loin, Nav.centre_de_la_case(c).distance_to(p1.global_position))
	_check("… revenu loin du joueur : %.0f px, sur %.0f possibles" % [d_joueur, plus_loin], d_joueur >= 0.6 * plus_loin,
		"%.0f px contre un maximum de %.0f" % [d_joueur, plus_loin])
	_check("… sur une case praticable", nav.est_praticable(Nav.case_du_monde(p2.global_position)))
	var apres: Vector2 = p2.global_position
	await _images(int(2.0 / PAS))
	_check("… et il repart : %.0f px en 2 s" % p2.global_position.distance_to(apres), p2.global_position.distance_to(apres) > 60.0)
	# Il peut mourir plusieurs fois : un deuxième aller-retour.
	p2.take_damage(500.0, p1)
	await _images(int(2.3 / PAS))
	_check("abattu une seconde fois, il revient aussi", not p2.dead and p2.hp == 100.0)


func _le_sang(main: Node, ui: Node, cartes: Node) -> void:
	cartes.select_map(CARTE_DE_LA_MORT)
	ui._on_hub_action("cran_cible")
	main._on_training_requested()
	await _images(3)
	var flaque := Node2D.new()
	flaque.name = "FlaqueEssaiBot"
	flaque.set_script(preload("res://blood_stain.gd"))
	main.arena.add_child(flaque)
	flaque.setup(main.p1.global_position + Vector2(40, 0), Vector2.RIGHT, 0.0)
	await _images(3)
	var avant := _compter_le_sang(main)
	_check("du sang est posé à l'entraînement sur cible immobile", avant >= 1, str(avant))
	ui._on_hub_action("cran_mobile")
	main._on_training_requested()
	await _images(3)
	_check("passer au cran mobile sur la même carte garde le sang : le bot n'est personne",
		_compter_le_sang(main) == avant, "%d avant, %d après" % [avant, _compter_le_sang(main)])
	ui._on_hub_action("cran_cible")
	main._on_training_requested()
	await _images(3)
	_check("… et repasser à la cible aussi", _compter_le_sang(main) == avant)


func _compter_le_sang(main: Node) -> int:
	var n := 0
	for t in root.get_tree().get_nodes_in_group("blood_stain"):
		if t.get_parent() == main.arena:
			n += 1
	return n


func _retour_a_la_cible(main: Node, ui: Node, cartes: Node) -> void:
	cartes.select_map(CARTE_DE_LA_MORT)
	ui._on_hub_action("cran_mobile")
	main._on_training_requested()
	await _images(3)
	_check("(mobile) le bot est là", main.p2.get_node_or_null("BotP2") != null and not main.training_target.visible)
	# Pendant que le bot marche, on change d'avis.
	await _images(60)
	ui._on_hub_action("cran_cible")
	_check("l'entrée « CIBLE IMMOBILE » porte la coche",
		_libelle_du_cran(ui, ui.CRAN_CIBLE_IMMOBILE).begins_with("✓")
		and not _libelle_du_cran(ui, ui.CRAN_ADVERSAIRE_MOBILE).begins_with("✓"))
	main._on_training_requested()
	await _images(3)
	_check("la cible est rendue : visible, active, solide, au point d'apparition de J2",
		main.training_target.visible and main.training_target.process_mode != Node.PROCESS_MODE_DISABLED
		and main.training_target.get_collision_layer_value(1)
		and main.training_target.global_position.distance_to(main._get_spawn_position(1)) < 1.0)
	_check("J2 est recaché, sans collision",
		not main.p2.visible and not main.p2.get_collision_layer_value(1) and not main.p2.get_collision_mask_value(1))
	_check("le bot a quitté J2 : plus de BotP2, fournisseur local de J2 rendu",
		main.p2.get_node_or_null("BotP2") == null and main.p2.input_provider is LocalInputProvider
		and int(main.p2.input_provider.device_id) == 1, str(main.p2.input_provider))
	_check("plus aucun bot dans l'arbre", _compter_les_bots() == 0, "%d" % _compter_les_bots())
	# La cible immobile, c'est inchangé : elle ne bouge pas, J2 non plus.
	var cible: Vector2 = main.training_target.global_position
	var j2: Vector2 = main.p2.global_position
	await _images(120)
	_check("deux secondes plus tard, ni la cible ni J2 n'ont bougé",
		main.training_target.global_position == cible and main.p2.global_position == j2)


func _compter_les_bots() -> int:
	var n := 0
	for noeud in _tous(root):
		if noeud is Bot and not noeud.is_queued_for_deletion():
			n += 1
	return n


func _tous(noeud: Node) -> Array[Node]:
	var sortie: Array[Node] = [noeud]
	for e in noeud.get_children():
		sortie.append_array(_tous(e))
	return sortie


func _apres_le_mobile(main: Node, ui: Node, cartes: Node, avant: Dictionary) -> void:
	cartes.select_map(cartes.DEFAULT_MAP_ID)
	ui._on_hub_action("cran_mobile")
	main._on_training_requested()
	await _images(120)
	_check("(mobile) le bot marche", main.p2.get_node_or_null("BotP2") != null)
	# (a) Par le menu principal, puis un écran scindé.
	main._on_main_menu_requested()
	await _images(3)
	_check("le retour au menu rend J2 à son fournisseur local, caché, sans collision",
		main.p2.get_node_or_null("BotP2") == null and main.p2.input_provider is LocalInputProvider
		and not main.p2.visible and not main.p2.get_collision_layer_value(1), str(main.p2.input_provider))
	_check("plus aucun bot dans l'arbre", _compter_les_bots() == 0)
	main._on_replay_requested()
	await _images(3)
	var apres := _etat_de_j2(main)
	_check("l'écran scindé démarre : manche active, hors entraînement", main.round_active and not main.training_mode)
	_check("J2 retrouve EXACTEMENT son état d'avant le premier entraînement", apres == avant,
		"avant %s\n      après %s" % [avant, apres])
	_check("P1 aussi a son fournisseur local (touches de J1)",
		main.p1.input_provider is LocalInputProvider and int(main.p1.input_provider.device_id) == 0)
	main._on_main_menu_requested()
	await _images(3)

	# (b) Sans repasser par le menu : un départ de manche direct (la ceinture de `_do_start_round`).
	ui._on_hub_action("cran_mobile")
	main._on_training_requested()
	await _images(60)
	_check("(mobile, de nouveau) le bot marche", main.p2.input_provider is Bot)
	main._do_start_round(0, 0)
	await _images(3)
	var direct := _etat_de_j2(main)
	_check("un départ de manche pris pendant l'entraînement mobile rend J2 à son fournisseur local",
		main.p2.get_node_or_null("BotP2") == null and direct["fournisseur"] == "LocalInputProvider" and direct["device"] == 1,
		str(direct))
	_check("… visible et solide, plein de vie", direct["visible"] and direct["calque"] and direct["masque"]
		and direct["hp"] == 100.0 and not direct["mort"])
	_check("… et les drapeaux du bot sont retombés", not main._adversaire_mobile and main._bot_p2 == null)
	main._on_main_menu_requested()
	await _images(3)


func _images(n: int) -> void:
	for _i in n:
		await process_frame


func _sortir() -> void:
	print("\n%d vérifications" % _verifications)
	if _failures == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
