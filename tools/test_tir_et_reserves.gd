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
const _GG = preload("res://gadget_gresillement.gd")

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

## Chaque libellé de réserve produit par le vrai code, et sa largeur.
var _largeurs: Array = []


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
	await _test_recharge_des_gadgets(gs)
	await _test_batterie(gs)
	await _test_torche_noire(gs)
	_test_largeur_des_libelles(gs)
	_test_hud_du_client()
	_test_destruction_autoritaire()
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
	# ⚠️ **On RESTAURE le fournisseur d'origine, on ne le vide jamais.** Le premier
	# jet le remettait à `null` en fin de section : chaque image de physique
	# suivante appelait `get_movement_vector()` sur rien — trois erreurs de script,
	# et pourtant tous les contrôles verts. En jeu le fournisseur n'est jamais nul ;
	# c'était le banc qui le rendait tel, et le lot complet l'aurait refusé.
	var fournisseur = gs.p1.input_provider
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
	gs.p1.input_provider = fournisseur


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
	_maj_hud(gs)
	var txt: String = gs.ui.p1_reserves["fusees"].text
	_check("vide, le bandeau dit ZÉRO — pas le tiret du Spectre", txt == "FUSÉES 0", txt)

	gs._accorder_fusees(1.5)
	_check("à une minute, elle revient", gs.fusees_restantes(0) == 1,
		str(gs.fusees_restantes(0)))
	_maj_hud(gs)
	txt = gs.ui.p1_reserves["fusees"].text
	_check("réserve pleine : le compte seul, ni tiret ni décompte", txt == "FUSÉES 1", txt)

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
	_maj_hud(gs)
	txt = gs.ui.p1_reserves["fusees"].text
	_check("et son bandeau garde le tiret — « n'en a jamais »", txt == "FUSÉES —", txt)

	# Le Terrassier, deux fusées sur trois, rechargeant : le compte, puis le décompte.
	gs.p1.equip_weapon(gs.weapon_for_index(_index_de(gs, "pompe")))
	gs._accorder_fusees(0.0)
	gs.rpc_stock_fusees(0, 2)
	_maj_hud(gs)
	txt = gs.ui.p1_reserves["fusees"].text
	_check("réserve entamée : le compte", txt == "FUSÉES 2", txt)

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


# ═══════════════════════════════════════════════════════════════════════════
# LE LOT GADGETS — décisions d'Adrien du 2026-09-10
# ═══════════════════════════════════════════════════════════════════════════

func _gadgets_de(gs: Node, pid: int) -> Array:
	var r := []
	for g in gs.get_tree().get_nodes_in_group("gadgets"):
		if is_instance_valid(g) and not g.is_queued_for_deletion() and g.poseur_id == pid:
			r.append(g)
	return r


func _vider(gs: Node) -> void:
	for c in gs.bullet_container.get_children():
		c.free()


func _test_recharge_des_gadgets(gs: Node) -> void:
	print("\n[Une minute de recharge pour tous les gadgets]")
	gs.round_active = false
	gs.sandbox_mode = true
	gs.training_mode = true
	# Le voile du Spectre : un gadget SANS durée de vie, le cas qui accumulerait.
	gs.p1.equip_weapon(gs.weapon_for_index(_index_de(gs, "spectre")))
	gs._gadget_attente.fill(0.0)
	_vider(gs)
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p1.rotation = 0.0
	_check("à l'entraînement, le premier gadget se pose", gs.gadget_disponible(0))
	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame
	var poses := _gadgets_de(gs, 0)
	_check("il est posé", poses.size() == 1, str(poses.size()))
	var premier: Vector2 = poses[0].global_position if poses.size() == 1 else Vector2.ZERO
	_check("et le suivant attend — l'entraînement compte aussi les gadgets",
		not gs.gadget_disponible(0))
	_maj_hud(gs)
	var lg: String = gs.ui.p1_reserves["gadget"].text
	var tg: String = _titre_gadget(gs)
	_check("le titre dit la recharge, en secondes", tg.begins_with("RECHARGE") and tg.ends_with("s"), tg)
	_check("et la valeur garde le nom du gadget", lg == "VOILE", lg)
	gs._maj_reserves_gadgets(59.0)
	_check("à 59 s, toujours pas", not gs.gadget_disponible(0),
		"%.1f s restantes" % gs.attente_gadget(0))
	gs._maj_reserves_gadgets(1.5)
	_check("à une minute, il revient", gs.gadget_disponible(0))

	# ⚠️ Un gadget debout par joueur : reposer DÉPLACE le voile, n'en ajoute pas un.
	gs.p1.global_position = Vector2(600.0, 400.0)
	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame
	await process_frame
	var debout := _gadgets_de(gs, 0)
	_check("reposer déplace le gadget au lieu d'en ajouter un", debout.size() == 1,
		str(debout.size()))
	if debout.size() == 1:
		_check("et c'est bien le nouveau qui reste",
			debout[0].global_position.distance_to(premier) > 50.0,
			"%s puis %s" % [premier, debout[0].global_position])

	# Le reste du bac à sable garde sa gratuité, comme pour les fusées.
	gs.training_mode = false
	_check("hors entraînement, le bac à sable ne rationne pas", gs.gadget_disponible(0))
	gs.sandbox_mode = false
	_vider(gs)


func _test_batterie(gs: Node) -> void:
	print("\n[Le grésillement en batterie]")
	gs.round_active = false
	gs.sandbox_mode = true
	gs.training_mode = true
	gs.p1.equip_weapon(gs.weapon_for_index(0))
	gs._gadget_attente.fill(0.0)
	gs._batterie.fill(1.0)
	_vider(gs)
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p1.rotation = 0.0
	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame
	var b = gs.gadget_basculable_de(0)
	_check("la bobine posée est basculable", b != null)
	if b == null:
		gs.sandbox_mode = false
		gs.training_mode = false
		return
	_check("posée, elle est allumée", b.actif)
	_maj_hud(gs)
	var tb: String = _titre_gadget(gs)
	_check("le titre dit qu'elle est allumée, et sa batterie",
		tb.contains("ALLUMÉ") and tb.contains("%"), tb)
	_check("et la valeur garde son nom", String(gs.ui.p1_reserves["gadget"].text) == "GRÉSILLEMENT",
		String(gs.ui.p1_reserves["gadget"].text))

	# Allumée, la batterie se vide en quatorze secondes.
	gs._maj_reserves_gadgets(7.0)
	_check("allumée sept secondes, la batterie est à moitié",
		absf(gs.batterie(0) - 0.5) < 0.02, "%.3f" % gs.batterie(0))

	# L'interrupteur : éteinte, elle se remplit.
	gs.basculer_gadget(gs.p1)
	_check("un appui l'éteint", not b.actif)
	_maj_hud(gs)
	tb = _titre_gadget(gs)
	_check("et le titre le dit", tb.contains("ÉTEINT"), tb)
	gs._maj_reserves_gadgets(30.0)
	_check("éteinte trente secondes, elle regagne la moitié",
		absf(gs.batterie(0) - 1.0) < 0.02, "%.3f" % gs.batterie(0))
	gs.basculer_gadget(gs.p1)
	_check("un second appui la rallume", b.actif)

	# À vide, elle s'éteint d'elle-même — et c'est l'hôte seul qui le décide.
	gs._maj_reserves_gadgets(14.5)
	_check("batterie vide, elle s'éteint d'elle-même", not b.actif)
	_check("et la batterie est à zéro", gs.batterie(0) <= 0.0001, "%.4f" % gs.batterie(0))
	_maj_hud(gs)
	tb = _titre_gadget(gs)
	_check("sous le seuil, le titre dit qu'elle CHARGE — pas qu'elle est éteinte et rallumable",
		tb.begins_with("CHARGE"), tb)

	# Sous le seuil, pas de rallumage : pas de clignotement sur un fil de charge.
	gs.basculer_gadget(gs.p1)
	_check("sous le seuil, un appui ne la rallume pas", not b.actif)
	gs._maj_reserves_gadgets(_GG.SEUIL_RALLUMAGE * _GG.RECHARGE_BATTERIE + 0.5)
	gs.basculer_gadget(gs.p1)
	_check("au-dessus du seuil, elle se rallume", b.actif)

	# L'interrupteur ne consomme PAS la recharge de pose : il n'occupe pas les mains.
	gs.basculer_gadget(gs.p1)
	_check("basculer ne remet pas le minuteur de pose en route",
		gs.attente_gadget(0) <= _GG.DUREE_ACTIVE_MAX + 60.0)

	# ⚠️ Elle RESTE AU SOL : éteinte, elle survit à ses quatorze secondes d'avant.
	# Trois relecteurs sur quatre ont trouvé qu'elle mourait à 14 s, allumée ou non.
	b._age = 30.0
	await physics_frame
	_check("éteinte, la bobine survit bien au-delà de quatorze secondes",
		is_instance_valid(b) and not b.is_queued_for_deletion())

	# Détruite par une balle, elle attend la recharge de POSE — et le titre le dit.
	gs._gadget_attente[0] = 45.0
	b.free()
	_maj_hud(gs)
	tb = _titre_gadget(gs)
	_check("bobine détruite : le titre compte la recharge de pose", tb.begins_with("RECHARGE"), tb)
	gs.sandbox_mode = false
	gs.training_mode = false
	_vider(gs)


func _test_torche_noire(gs: Node) -> void:
	print("\n[Une torche éteinte par le grésillement n'éblouit plus]")
	gs.round_active = true
	gs.sandbox_mode = false
	gs.training_mode = false
	gs.countdown_left = 0.0
	gs.ui._is_main_menu = false
	_vider(gs)
	var parasite = gs.weapon_for_index(0)
	gs.p1.equip_weapon(parasite)
	gs.p2.equip_weapon(parasite)
	gs.p1.visible = true
	gs.p2.visible = true
	# ⚠️ **Une détente neutre qui vise DROIT DEVANT, pas le fournisseur réel.** Le
	# vrai fournisseur oriente J1 vers la SOURIS pendant les images qu'on attend :
	# relevé à −59°, J2 sortait du faisceau et la référence tombait à zéro — un
	# artefact de banc taillé exactement comme ce que ce contrôle veut prouver,
	# « la torche n'éblouit plus ». Trouvé en mesurant chaque maillon, pas en
	# devinant : les trois hypothèses d'avant étaient fausses.
	var fournisseur = gs.p1.input_provider
	gs.p1.input_provider = Detente.new()
	# J1 éclaire J2 de face, à courte portée, rien entre eux.
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p1.rotation = 0.0
	gs.p2.global_position = Vector2(520.0, 400.0)
	await physics_frame
	await physics_frame
	gs.p1.flashlight_on = true
	var espace = gs.p1.get_world_2d().direct_space_state
	var libre: float = gs._lumiere_recue(espace, gs.p1, gs.p2)
	_check("sans bobine, la torche éblouit", libre > 0.0, "%.4f" % libre)

	# Une bobine allumée au pied de J1, figée au centre d'un créneau de noir.
	var b = _GG.new()
	b.name = "BobineDeTest"
	b.poseur_id = 1
	b.global_position = gs.p1.global_position
	b.actif = true
	b.graine = 42
	gs.bullet_container.add_child(b)
	var t_noir := -1.0
	for i in 4000:
		var t: float = (float(i) + 0.5) * _GG.CRENEAU
		b._temps_actif = t
		if b.facteur_de_lampe(gs.p1.global_position) < 0.005:
			t_noir = t
			break
	_check("la bobine atteint le noir", t_noir >= 0.0)
	b._temps_actif = t_noir
	gs.p1.flashlight_on = true
	var noire: float = gs._lumiere_recue(espace, gs.p1, gs.p2)
	_check("au noir, la même torche n'éblouit plus du tout", is_zero_approx(noire),
		"%.4f" % noire)
	# Et ce qui revient des murs vers son porteur s'éteint avec elle.
	var src_soi := {"noeud": gs.p1, "porteur": gs.p1, "rayon": 1.0}
	var retro_noire: float = gs._plafond_de_source(espace, src_soi, gs.p1)
	# Éteinte, la bobine ne retire rien — exactement, pas « presque ».
	b.actif = false
	var rendue: float = gs._lumiere_recue(espace, gs.p1, gs.p2)
	_check("bobine éteinte, l'éblouissement revient exactement",
		is_equal_approx(rendue, libre), "%.4f contre %.4f" % [rendue, libre])
	var retro_libre: float = gs._plafond_de_source(espace, src_soi, gs.p1)
	_check("la rétrodiffusion d'une torche noire s'éteint aussi, puis revient",
		is_zero_approx(retro_noire) and retro_libre > 0.0,
		"%.4f puis %.4f" % [retro_noire, retro_libre])
	b.free()
	gs.p1.input_provider = fournisseur
	gs.round_active = false


func _test_hud_du_client() -> void:
	print("\n[Le bandeau du client lit SES réserves, pas celles de l'hôte]")
	var src := FileAccess.get_file_as_string("res://ui.gd")
	_check("update_hud passe le JOUEUR à _maj_reserves, pas seulement un index",
		src.contains("_maj_reserves(p1_reserves, 0, p1)")
			and src.contains("_maj_reserves(p2_reserves, 1, p2)"))
	_check("les données suivent le joueur, la couleur suit le panneau",
		src.contains("var p: Node2D = qui if qui != null else"))


func _titre_gadget(gs: Node) -> String:
	var lg: Label = gs.ui.p1_reserves["gadget"]
	var titre: Label = lg.get_parent().get_node_or_null("Titre")
	return titre.text if titre != null else ""


func _maj_hud(gs: Node) -> void:
	gs.ui._maj_reserves(gs.ui.p1_reserves, 0)
	var res: Dictionary = gs.ui.p1_reserves
	_largeurs.append(["fusées", String(res["fusees"].text), float(res["fusees"].get_minimum_size().x)])
	_largeurs.append(["gadget", String(res["gadget"].text), float(res["gadget"].get_minimum_size().x)])
	var t: Label = res.get("gadget_titre", null)
	if t != null:
		_largeurs.append(["gadget", String(t.text), float(t.get_minimum_size().x)])


## ⚠️ **Le défaut que ce contrôle ferme a été trouvé par MESURE, avant d'être vu.**
## Un libellé de réserve ne coupe pas et ne passe pas à la ligne : il élargit sa
## cartouche, qui pousse le reste du HUD. Le 2026-09-10, « GRÉSILLEMENT ALLUMÉ ·
## 100 % » mesurait 178 px, plus que tout le bloc des réserves ; et en écran
## scindé le panneau de J2, calé à droite et grandissant vers la droite, poussait
## sa cartouche hors de l'écran. Aucune suite ne le voyait : un lot headless ne
## rend rien, et le texte était juste.
##
## ⚠️ **Une référence PAR CARTOUCHE**, chacune le plus long libellé qu'elle portait
## déjà, mesuré ici même avec la même police — jamais un nombre recopié, et sans
## tolérance. Un premier jet prenait une référence commune, celle du gadget : il
## laissait la cartouche des fusées grandir de 40 % sans rien dire.
func _test_largeur_des_libelles(gs: Node) -> void:
	print("\n[Aucun libellé de réserve n'élargit sa cartouche]")
	var res: Dictionary = gs.ui.p1_reserves
	var lf: Label = res["fusees"]
	var lg: Label = res["gadget"]
	var garde_f := lf.text
	var garde_g := lg.text
	lf.text = "FUSÉES —"
	var ref_f := lf.get_minimum_size().x
	lg.text = "%s —" % gs.ui._nom_court_gadget("gresillement", "")
	var ref_g := lg.get_minimum_size().x
	lf.text = garde_f
	lg.text = garde_g
	var refs := {"fusées": ref_f, "gadget": ref_g}
	var fautifs: Array[String] = []
	for e in _largeurs:
		if float(e[2]) > float(refs[e[0]]) + 0.5:
			fautifs.append("%s « %s » %.0f px > %.0f" % [e[0], e[1], e[2], refs[e[0]]])
	_check("aucun libellé n'est plus large que le plus long que sa cartouche portait déjà",
		fautifs.is_empty(), "; ".join(fautifs))
	_check("et la mesure a bien vu les pires cas", _largeurs.size() >= 24, str(_largeurs.size()))


func _test_destruction_autoritaire() -> void:
	print("\n[La destruction d'un gadget est autoritaire]")
	var b := FileAccess.get_file_as_string("res://bullet.gd")
	_check("le client n'encaisse plus : seul l'hôte blesse un gadget",
		b.contains("if not is_replay and NetworkManager.current_mode != NetworkManager.GameMode.ONLINE_CLIENT:\n\t\t\t\tgadget.encaisser("))
	var g := FileAccess.get_file_as_string("res://game_state.gd")
	_check("l'hôte ordonne le retrait au client", g.contains("func rpc_detruire_gadget(nom: String)"))
	_check("et il l'ordonne à CHAQUE mort de gadget, pas seulement sous les balles",
		g.contains("g.detruit.connect(_sur_gadget_detruit)"))
	_check("l'état initial d'une bobine vient de l'hôte, pas de la batterie locale",
		g.contains('g.set("actif", actif_initial)'))
