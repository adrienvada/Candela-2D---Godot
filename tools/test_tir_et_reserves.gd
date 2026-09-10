extends SceneTree

## Les règles du 2026-09-10, éprouvées sur le VRAI joueur — pas sur la donnée.
##
## Adrien, après un essai en entraînement : le Parasite tirait en rafale, lançait
## des fusées sans fin, et l'entraînement le gardait prisonnier du Parasite. Ce
## fichier tient ce qui a été corrigé :
##
##   • le tir SEMI-AUTOMATIQUE — un appui, un tir ; l'Occulteur seul tire en
##     boucle détente tenue ;
##   • l'HYSTÉRÉSIS de la gâchette, sans laquelle le semi-automatique
##     redoublerait chaque tremblement autour du seuil ;
##   • l'ÉCONOMIE DES FUSÉES à l'entraînement, et la recharge d'une minute des
##     sept classes qui ne rechargeaient pas ;
##   • le FIL à dix classes — `_get_weapon_idx` ne codait que quatre armes.
##
## ⚠️ **Fichier séparé de `test_classes.gd`, et ce n'est pas un rangement.** Une
## autre session réécrit la partie interface de celui-là le même jour. Deux diffs
## dans un même fichier se percutent à la fusion ; deux fichiers, jamais.
##
## Lancer : godot --headless --path . --script res://tools/test_tir_et_reserves.gd

const _IP = preload("res://input_provider.gd")

## Une détente qu'on tient ou qu'on lâche à la main. Elle court-circuite
## l'hystérésis, qui a son propre contrôle : ici on éprouve le VERROU de player.gd.
class Detente extends _IP:
	var tire := false
	func get_movement_vector() -> Vector2: return Vector2.ZERO
	func get_aim_direction(_p: Vector2) -> Vector2: return Vector2.RIGHT
	func is_shoot_pressed() -> bool: return tire
	func is_flashlight_pressed() -> bool: return false
	func is_flare_pressed() -> bool: return false
	func is_reload_pressed() -> bool: return false
	func is_gadget_pressed() -> bool: return false

var _echecs := 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ " + label)
	else:
		_echecs += 1
		printerr("  ✗ %s%s" % [label, ("  → " + detail) if detail != "" else ""])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== TIR ET RÉSERVES (2026-09-10) ===")
	var gs: Node = load("res://main.tscn").instantiate()
	root.add_child(gs)
	await process_frame
	await process_frame
	await _test_semi_automatique(gs)
	_test_ordre_du_verrou()
	_test_hysteresis()
	_test_periodes(gs)
	_test_economie_entrainement(gs)
	_test_fil_a_dix(gs)
	gs.queue_free()
	await process_frame
	if _echecs == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _echecs)
	quit(1 if _echecs > 0 else 0)


func _index_de(gs: Node, slug: String) -> int:
	for i in range(10):
		if String(gs.weapon_for_index(i).slug()) == slug:
			return i
	return -1


func _preparer(gs: Node, idx: int, d: Detente) -> void:
	gs.round_active = true
	gs.sandbox_mode = false
	gs.training_mode = false
	gs.countdown_left = 0.0
	gs.ui._is_main_menu = false
	gs.p2.global_position = Vector2(4000.0, 4000.0)
	gs.p1.input_provider = d
	gs.p1.equip_weapon(gs.weapon_for_index(idx))
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p1.shoot_cooldown = 0.0
	gs.p1.is_reloading = false
	d.tire = false
	# Une image détente relâchée : le verrou est levé, comme au début d'un vrai appui.
	await physics_frame


func _tirs_pendant(gs: Node, images: int) -> int:
	var avant: int = gs.p1.current_ammo
	for i in range(images):
		await physics_frame
	return avant - int(gs.p1.current_ammo)


func _test_semi_automatique(gs: Node) -> void:
	print("\n[Un appui, un tir — l'Occulteur seul tire en boucle]")
	var d := Detente.new()

	# Le Parasite, détente tenue une seconde entière : six fois son cooldown.
	await _preparer(gs, 0, d)
	d.tire = true
	var n := await _tirs_pendant(gs, 60)
	_check("le Parasite, détente tenue une seconde, ne tire qu'UNE fois",
		n == 1, "%d tirs" % n)

	# Relâcher puis réappuyer : un second tir, sans rien attendre d'autre que le cooldown.
	d.tire = false
	await physics_frame
	d.tire = true
	n = await _tirs_pendant(gs, 20)
	_check("relâcher puis réappuyer tire de nouveau", n == 1, "%d tirs" % n)

	# Un appui pris PENDANT le cooldown n'est pas perdu : il part à son terme.
	await _preparer(gs, 0, d)
	d.tire = true
	await physics_frame
	d.tire = false
	await physics_frame
	d.tire = true
	n = await _tirs_pendant(gs, 20)
	_check("un appui pris pendant le cooldown part à son terme",
		n == 1, "%d tir(s) après le premier" % n)

	# L'Occulteur, détente tenue une demi-seconde : il tire en boucle.
	var oc := _index_de(gs, "occulteur")
	await _preparer(gs, oc, d)
	d.tire = true
	n = await _tirs_pendant(gs, 30)
	_check("l'Occulteur, détente tenue, tire en boucle", n >= 3, "%d tirs" % n)

	# Et il est le SEUL : un second drapeau oublié à vrai passerait inaperçu.
	var auto: Array[String] = []
	for i in range(10):
		if gs.weapon_for_index(i).automatique:
			auto.append(String(gs.weapon_for_index(i).slug()))
	_check("une seule classe est automatique, et c'est l'Occulteur",
		auto.size() == 1 and auto[0] == "occulteur", str(auto))

	# Le lien dans le seul sens qui vaille : s'immobiliser après la rafale
	# suppose une arme qui tire en rafale.
	var incoherentes: Array[String] = []
	for i in range(10):
		var c = gs.weapon_for_index(i)
		if c.root != null and c.root.apres_rafale and not c.automatique:
			incoherentes.append(String(c.slug()))
	_check("toute arme au root « après rafale » est automatique",
		incoherentes.is_empty(), str(incoherentes))
	gs.p1.input_provider = null


## ⚠️ Deux défauts de conception que le contre-examen a trouvés AVANT le code,
## et qu'un contrôle de comportement ne verrait qu'avec un décompte monté : on
## les tient par l'ordre du texte.
func _test_ordre_du_verrou() -> void:
	print("\n[Le verrou se lève avant les sorties anticipées]")
	var src := FileAccess.get_file_as_string("res://player.gd")
	var levee := src.find("_tir_consomme = false")
	var decompte := src.find("state.countdown_left > 0.0")
	_check("le verrou se lève AVANT la sortie du décompte",
		levee >= 0 and decompte >= 0 and levee < decompte,
		"levée à %d, décompte à %d" % [levee, decompte])
	var ligne := src.substr(maxi(0, src.rfind("\n", levee)), 140)
	_check("et il se lève aussi menu pause ouvert — ce que voit l'hôte",
		ligne.contains("menu_open"), ligne.strip_edges())


func _test_hysteresis() -> void:
	print("\n[L'hystérésis de la gâchette]")
	var LIP = load("res://local_input_provider.gd")
	var lip = LIP.new()
	lip.set("action_shoot", "p1_shoot")
	var act := "p1_shoot"
	var seuil := InputMap.action_get_deadzone(act)
	var rearme: float = minf(LIP.TIR_REARME, seuil)
	_check("le réarmement est plus bas que le seuil d'appui",
		rearme < seuil, "réarme %.2f, seuil %.2f" % [rearme, seuil])
	var entre := (rearme + seuil) * 0.5

	Input.action_press(act, 0.95)
	var a: bool = lip.is_shoot_pressed()
	Input.action_press(act, entre)
	var b: bool = lip.is_shoot_pressed()
	Input.action_press(act, rearme * 0.4)
	var c: bool = lip.is_shoot_pressed()
	Input.action_press(act, entre)
	var d: bool = lip.is_shoot_pressed()
	Input.action_press(act, 0.95)
	var e: bool = lip.is_shoot_pressed()
	Input.action_release(act)

	_check("une course franche arme la détente", a)
	_check("redescendue ENTRE les deux seuils, elle reste tenue", b)
	_check("sous le seuil de réarmement, elle se relâche", not c)
	_check("remontée entre les deux seuils, elle ne se réarme PAS — c'est tout l'objet", not d)
	_check("une nouvelle course franche la réarme", e)
	if lip is Node:
		lip.free()


func _test_periodes(gs: Node) -> void:
	print("\n[Une fusée par minute pour les classes qui ne rechargeaient pas]")
	var commune: float = gs.PERIODE_RECHARGE_FUSEE
	_check("la période commune est d'une minute", is_equal_approx(commune, 60.0), str(commune))
	var sans_recharge: Array[String] = []
	for i in range(10):
		var c = gs.weapon_for_index(i)
		if c.fusees.stock > 0 and not c.fusees.recharge_active():
			sans_recharge.append(String(c.slug()))
	_check("toute classe qui porte une fusée la recharge — plus une n'est à sec pour la manche",
		sans_recharge.is_empty(), str(sans_recharge))
	for slug in ["pompe", "allumeur"]:
		var c = gs.weapon_for_index(_index_de(gs, slug))
		_check("%s garde une recharge plus rapide que la commune — c'est son identité" % slug,
			c.fusees.periode_recharge < commune, "%.1f s" % c.fusees.periode_recharge)
	var sp = gs.weapon_for_index(_index_de(gs, "spectre"))
	_check("le Spectre n'a aucune fusée et n'en regagnera jamais",
		sp.fusees.stock == 0 and not sp.fusees.recharge_active())
	_check("le Parasite n'en porte qu'une", gs.weapon_for_index(0).fusees.stock == 1)


func _test_economie_entrainement(gs: Node) -> void:
	print("\n[L'entraînement compte les fusées]")
	gs.round_active = false
	gs.sandbox_mode = true
	gs.training_mode = true
	gs.p1.equip_weapon(gs.weapon_for_index(0))
	gs._accorder_fusees(0.0)   # changement de classe : le stock s'amorce
	_check("le Parasite commence avec sa fusée", gs.fusees_restantes(0) == 1,
		str(gs.fusees_restantes(0)))
	_check("elle est disponible", gs.fusee_disponible(0))

	gs._do_spawn_fusee(0, Vector2(400.0, 400.0), 0.0, 4242)
	_check("la lancer la CONSOMME, même à l'entraînement",
		gs.fusees_restantes(0) == 0, str(gs.fusees_restantes(0)))
	_check("et il n'y en a plus à lancer", not gs.fusee_disponible(0))

	gs._accorder_fusees(59.0)
	_check("à 59 s, toujours rien", gs.fusees_restantes(0) == 0)
	gs.ui._maj_reserves(gs.ui.p1_reserves, 0)
	var txt: String = gs.ui.p1_reserves["fusees"].text
	_check("le bandeau dit le stock ET le plafond, et le décompte",
		txt.begins_with("FUSÉES 0/1") and txt.ends_with(" s"), txt)

	gs._accorder_fusees(1.5)
	_check("à une minute, elle revient", gs.fusees_restantes(0) == 1,
		str(gs.fusees_restantes(0)))
	gs.ui._maj_reserves(gs.ui.p1_reserves, 0)
	txt = gs.ui.p1_reserves["fusees"].text
	_check("réserve pleine : ni tiret ni décompte", txt == "FUSÉES 1/1", txt)

	# L'hôte qui attend seul est aussi en bac à sable, et il y garde sa gratuité.
	gs.training_mode = false
	var avant: int = gs.fusees_restantes(0)
	_check("hors entraînement, le bac à sable garde sa gratuité", gs.fusee_disponible(0))
	gs._do_spawn_fusee(0, Vector2(400.0, 400.0), 0.0, 4343)
	_check("et n'y consomme rien", gs.fusees_restantes(0) == avant,
		"%d → %d" % [avant, gs.fusees_restantes(0)])

	gs.training_mode = true
	gs.p1.equip_weapon(gs.weapon_for_index(_index_de(gs, "spectre")))
	gs._accorder_fusees(0.0)
	_check("le Spectre n'a rien à lancer, même à l'entraînement", not gs.fusee_disponible(0))
	gs.ui._maj_reserves(gs.ui.p1_reserves, 0)
	txt = gs.ui.p1_reserves["fusees"].text
	_check("et son bandeau garde le tiret — « n'en a jamais »", txt == "FUSÉES —", txt)

	gs.sandbox_mode = false
	gs.training_mode = false
	for f in gs.bullet_container.get_children():
		f.free()


func _test_fil_a_dix(gs: Node) -> void:
	print("\n[Le fil code les dix classes]")
	for i in range(10):
		var w = gs.weapon_for_index(i)
		_check("%s voyage sous l'index %d" % [String(w.slug()), i],
			gs._get_weapon_idx(w) == i, str(gs._get_weapon_idx(w)))
	var src := FileAccess.get_file_as_string("res://game_state.gd")
	_check("rpc_spawn_bullet décode par weapon_for_index, pas par une cascade de quatre",
		src.contains("var weapon := weapon_for_index(weapon_idx)"))
