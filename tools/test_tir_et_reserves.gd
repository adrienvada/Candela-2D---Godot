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
##   • le FIL à dix classes — `_get_weapon_idx` ne codait que quatre armes ;
##   • le VOILE qui arrête les joueurs, et toujours pas les balles (étape 25) ;
##   • les IMAGES des gadgets, et le pied de la torche qui ne balaie pas (26) ;
##   • l'OMBRE HABITÉE qui arrête balles et regard par sa plaque, plus par un
##     disque, et le VOILE qui recule hors des corps à la pose (28) ;
##   • les REFUS de fusée et de gadget qui se sentent, et les JAUGES de recharge
##     sous les cartouches — l'attente de la fusée dite au client par l'hôte
##     (28, lot C).
##
## ⚠️ **Fichier séparé de `test_classes.gd`, et ce n'est pas un rangement.** Une
## autre session réécrit la partie interface de celui-là le même jour. Deux diffs
## dans un même fichier se percutent à la fusion ; deux fichiers, jamais.
##
## Lancer : godot --headless --path . --script res://tools/test_tir_et_reserves.gd

const _IP = preload("res://input_provider.gd")
const _GG = preload("res://gadget_gresillement.gd")
const _GV = preload("res://gadget_voile.gd")
const _GO = preload("res://gadget_ombre.gd")
const _GB = preload("res://gadget_base.gd")
const _GTF = preload("res://gadget_torche_fantome.gd")
const _MG = preload("res://map_geometry.gd")
## Sans dépendance à un autoload : son `curseur()` passe par l'arbre (lot C).
const _EP = preload("res://effect_policy.gd")

## Où J1 pose, dans les deux contrôles de l'étape 28 : la zone de 400 à 560 en x et
## de 250 à 560 en y doit être libre de murs — les témoins le vérifient.
const POSEUR := Vector2(400.0, 400.0)
## Là où un joueur ne gêne rien.
const _LOIN := Vector2(4000.0, 4000.0)

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

## Un joueur qui marche droit devant lui, et ne fait rien d'autre.
class Marcheur extends _IP:
	var direction := Vector2.ZERO
	func get_movement_vector() -> Vector2: return direction
	func get_aim_direction(_p: Vector2) -> Vector2: return Vector2.RIGHT
	func is_shoot_pressed() -> bool: return false
	func is_flashlight_pressed() -> bool: return false
	func is_flare_pressed() -> bool: return false
	func is_reload_pressed() -> bool: return false
	func is_gadget_pressed() -> bool: return false

## Un joueur qui tient sa touche de gadget, regard à droite, et ne fait rien d'autre.
class Poseur extends _IP:
	func get_movement_vector() -> Vector2: return Vector2.ZERO
	func get_aim_direction(_p: Vector2) -> Vector2: return Vector2.RIGHT
	func is_shoot_pressed() -> bool: return false
	func is_flashlight_pressed() -> bool: return false
	func is_flare_pressed() -> bool: return false
	func is_reload_pressed() -> bool: return false
	func is_gadget_pressed() -> bool: return true

## Les deux boutons du lot C — fusée et gadget —, tenus ou lâchés à la main, regard
## à droite, et rien d'autre (étape 28, lot C).
class Boutons extends _IP:
	var fusee := false
	var gadget := false
	func get_movement_vector() -> Vector2: return Vector2.ZERO
	func get_aim_direction(_p: Vector2) -> Vector2: return Vector2.RIGHT
	func is_shoot_pressed() -> bool: return false
	func is_flashlight_pressed() -> bool: return false
	func is_flare_pressed() -> bool: return fusee
	func is_reload_pressed() -> bool: return false
	func is_gadget_pressed() -> bool: return gadget

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
	await _test_refus_ressentis(gs)
	await _test_torche_noire(gs)
	# ⚠️ Le client AVANT la mesure des largeurs : ses lectures du bandeau passent par
	# `_maj_hud()`, et c'est la mesure des largeurs qui les juge.
	_test_hud_du_client(gs)
	await _test_secousse_de_cartouche(gs)
	_test_largeur_des_libelles(gs)
	_test_destruction_autoritaire()
	await _test_voile_bloquant(gs)
	await _test_ombre_plaque(gs)
	await _test_voile_hors_des_corps(gs)
	_test_sprites_des_gadgets(gs)
	await _test_diffus_intouchables(gs)
	await _test_suie_masque(gs)
	# ⚠️ En DERNIER : le vrai départ de manche pose l'arène, les armes et le décompte.
	_test_attente_au_depart_de_manche(gs)
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
	gs.rpc_stock_fusees(0, 2, 18.0)
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
	# Étape 28, point 7 — la jauge sous la cartouche part de zéro à la pose.
	var jauge: float = gs.ui.p1_reserves["panel_gadget"].fraction
	_check("la jauge de recharge part de zéro à la pose", jauge >= 0.0 and jauge < 0.01,
		"%.4f" % jauge)
	gs._maj_reserves_gadgets(59.0)
	_check("à 59 s, toujours pas", not gs.gadget_disponible(0),
		"%.1f s restantes" % gs.attente_gadget(0))
	gs._maj_reserves_gadgets(1.5)
	_check("à une minute, il revient", gs.gadget_disponible(0))
	_maj_hud(gs)
	jauge = gs.ui.p1_reserves["panel_gadget"].fraction
	_check("et la jauge disparaît : plus rien ne revient", jauge < 0.0, "%.4f" % jauge)

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
	# Le compte à rebours sur l'icône (Adrien, 2026-09-11) : batterie pleine,
	# quatorze secondes avant que la zone ne lâche.
	var dec: Label = gs.ui.p1_reserves["gadget_decompte"]
	_check("l'icône compte les secondes de batterie : 14 à la pose",
		dec.visible and dec.text == "14", "%s « %s »" % [dec.visible, dec.text])
	var ico: TextureRect = gs.ui.p1_reserves["gadget_icone"]
	_check("et l'icône porte l'image du gadget", ico.texture != null)
	# Étape 28, point 7 — la jauge dit le NIVEAU de la batterie DÈS LA POSE : pleine,
	# allumée, elle se consume. `batt < 1` seul la faisait surgir à l'image suivante.
	# ⚠️ La batterie remise à 1,0 EXACTEMENT, l'état de la pose : l'image attendue plus
	# haut l'a entamée d'un rien (0,999), et sur 0,999 la règle fautive passait aussi.
	gs._batterie[0] = 1.0
	_maj_hud(gs)
	var cart_b = gs.ui.p1_reserves["panel_gadget"]
	_check("la jauge dit la batterie dès la pose : pleine, et présente",
		is_equal_approx(cart_b.fraction, 1.0), "%.4f" % cart_b.fraction)
	# La fonction pure, sur les cas qui comptent.
	_check("le décompte : 7 à mi-batterie, 1 au dernier souffle, jamais 0 allumée",
		gs.ui.decompte_gadget(true, 0.5) == 7 and gs.ui.decompte_gadget(true, 0.001) == 1
			and gs.ui.decompte_gadget(true, 1.0) == 14,
		"%d / %d / %d" % [gs.ui.decompte_gadget(true, 0.5), gs.ui.decompte_gadget(true, 0.001),
			gs.ui.decompte_gadget(true, 1.0)])
	_check("sous le seuil, les secondes avant de pouvoir rallumer ; éteinte et prête, rien",
		gs.ui.decompte_gadget(false, 0.0) == int(ceil(_GG.SEUIL_RALLUMAGE * _GG.RECHARGE_BATTERIE))
			and gs.ui.decompte_gadget(false, 0.5) == -1,
		"%d / %d" % [gs.ui.decompte_gadget(false, 0.0), gs.ui.decompte_gadget(false, 0.5)])

	# Allumée, la batterie se vide en quatorze secondes.
	gs._maj_reserves_gadgets(7.0)
	_check("allumée sept secondes, la batterie est à moitié",
		absf(gs.batterie(0) - 0.5) < 0.02, "%.3f" % gs.batterie(0))
	_maj_hud(gs)
	_check("et l'icône compte 7 secondes", dec.visible and dec.text == "7", dec.text)
	_check("et la jauge est à moitié", absf(cart_b.fraction - 0.5) < 0.02,
		"%.4f" % cart_b.fraction)

	# L'interrupteur : éteinte, elle se remplit.
	gs.basculer_gadget(gs.p1)
	_check("un appui l'éteint", not b.actif)
	_maj_hud(gs)
	tb = _titre_gadget(gs)
	_check("et le titre le dit", tb.contains("ÉTEINT"), tb)
	_check("éteinte et rallumable, l'icône ne compte rien", not dec.visible, dec.text)
	gs._maj_reserves_gadgets(30.0)
	_check("éteinte trente secondes, elle regagne la moitié",
		absf(gs.batterie(0) - 1.0) < 0.02, "%.3f" % gs.batterie(0))
	# Une seconde de plus : la batterie touche le PLEIN — l'image attendue après la pose
	# l'avait entamée d'un rien, et 0,999 est encore « quelque chose qui bouge ».
	gs._maj_reserves_gadgets(1.0)
	_maj_hud(gs)
	_check("pleine et éteinte, rien ne bouge : la jauge disparaît",
		is_equal_approx(gs.batterie(0), 1.0) and cart_b.fraction < 0.0,
		"batterie %.4f, jauge %.4f" % [gs.batterie(0), cart_b.fraction])
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
	_check("et l'icône compte les secondes avant le rallumage",
		dec.visible and dec.text == str(int(ceil(_GG.SEUIL_RALLUMAGE * _GG.RECHARGE_BATTERIE))), dec.text)
	_check("vide et éteinte, elle se recharge : la jauge est là, à zéro",
		cart_b.fraction >= 0.0 and cart_b.fraction < 0.01, "%.4f" % cart_b.fraction)

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


func _test_hud_du_client(gs: Node) -> void:
	print("\n[Le bandeau du client lit SES réserves, pas celles de l'hôte]")
	var src := FileAccess.get_file_as_string("res://ui.gd")
	_check("update_hud passe le JOUEUR à _maj_reserves, pas seulement un index",
		src.contains("_maj_reserves(p1_reserves, 0, p1)")
			and src.contains("_maj_reserves(p2_reserves, 1, p2)"))
	_check("les données suivent le joueur, la couleur suit le panneau",
		src.contains("var p: Node2D = qui if qui != null else"))
	# Étape 28, lot C — et ce qu'il y lit, par le COMPORTEMENT : les jauges.
	_test_jauge_des_fusees(gs)
	_test_jauge_de_pose(gs)


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
	# ⚠️ **Et le compte à rebours n'élargit pas la cartouche** : le chiffre vit DANS
	# l'icône, qui n'est pas un conteneur. On mesure la MÊME cartouche, chiffre
	# caché puis affiché — la largeur, elle, suit légitimement le nom du gadget,
	# et un premier jet qui exigeait une largeur unique pour tous les états
	# comparait « VOILE » à « GRÉSILLEMENT ».
	var cart: Control = res.get("panel_gadget", null)
	var dec: Label = res.get("gadget_decompte", null)
	if cart != null and dec != null:
		var garde_v := dec.visible
		var garde_t := dec.text
		dec.visible = false
		var sans := cart.get_combined_minimum_size().x
		dec.text = "14"
		dec.visible = true
		var avec := cart.get_combined_minimum_size().x
		dec.text = "3"
		var avec_3 := cart.get_combined_minimum_size().x
		dec.visible = garde_v
		dec.text = garde_t
		_check("le compte à rebours n'élargit pas la cartouche",
			absf(avec - sans) <= 0.5 and absf(avec_3 - sans) <= 0.5,
			"%.1f px sans, %.1f avec « 14 », %.1f avec « 3 »" % [sans, avec, avec_3])
	_check("le compte à rebours est posé DANS l'icône, qui n'est pas un conteneur",
		dec != null and dec.get_parent() is TextureRect and not (dec.get_parent() is Container))
	# ⚠️ Étape 28, lot C — **ni la jauge ni le tremblement n'élargissent une
	# cartouche** : l'une est DESSINÉE hors de son rectangle, l'autre décale le contenu
	# après le tri. La même cartouche mesurée nue, puis jauge à moitié et secousse en
	# cours ; et un seul enfant, sans quoi un libellé « 42s » glissé dedans passerait.
	for cle in ["panel_fusees", "panel_gadget"]:
		var c = res.get(cle, null)
		if c == null or not c.has_method("poser_jauge"):
			_check("%s est une CartoucheReserve" % cle, false)
			continue
		var garde_fr: float = c.fraction
		var garde_se: float = c.secousse
		var garde_du: float = c._secousse_duree
		c.poser_jauge(-1.0)
		c.secousse = 0.0
		c._secousse_duree = 0.0
		var nu: Vector2 = c.get_combined_minimum_size()
		c.poser_jauge(0.5)
		c.secouer(0.2)
		var charge: Vector2 = c.get_combined_minimum_size()
		c.poser_jauge(garde_fr)
		c.secousse = garde_se
		c._secousse_duree = garde_du
		_check("%s : ni la jauge ni le tremblement ne l'élargissent" % cle,
			absf(charge.x - nu.x) <= 0.5 and absf(charge.y - nu.y) <= 0.5,
			"%s nue, %s avec" % [nu, charge])
		_check("%s : un seul enfant — la jauge est dessinée, pas un nœud" % cle,
			c.get_child_count() == 1, str(c.get_child_count()))


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


## Le voile du Spectre arrête les joueurs — décision d'Adrien, 2026-09-10 : « on
## ne peut pas passer au travers ». Éprouvé sur le VRAI joueur, qui marche.
func _test_voile_bloquant(gs: Node) -> void:
	print("\n[Le voile arrête les joueurs — et rien d'autre ne change]")

	# ── Les couches ─────────────────────────────────────────────────────────
	var bloquant: int = _MG.GADGET_BLOQUANT_LAYER
	_check("les gadgets bloquants ont leur couche, distincte des trois autres",
		not [_MG.WALL_LAYER, _MG.PIT_LAYER, _MG.GADGET_LAYER].has(bloquant)
			and (bloquant & (bloquant - 1)) == 0, str(bloquant))
	_check("le masque des joueurs la contient", (_MG.PLAYER_MASK & bloquant) != 0,
		str(_MG.PLAYER_MASK))
	# ⚠️ Le garde de l'étape 5 tient toujours : sans lui, les DIX gadgets
	# deviendraient des murs d'un coup, et le jeu resterait parfaitement jouable.
	_check("il ne contient toujours PAS la couche des gadgets",
		(_MG.PLAYER_MASK & _MG.GADGET_LAYER) == 0, str(_MG.PLAYER_MASK))

	# ── Un gadget sur dix ───────────────────────────────────────────────────
	var bloquants: Array[String] = []
	for slug in gs.IMPLEMENTATIONS:
		var g = load(String(gs.IMPLEMENTATIONS[slug]["script"])).new()
		if g.arrete_les_joueurs:
			bloquants.append(String(slug))
		g.free()
	_check("un seul gadget sur dix arrête les joueurs : le voile",
		gs.IMPLEMENTATIONS.size() == 10 and bloquants.size() == 1 and bloquants[0] == "voile",
		"%d gadgets, bloquants : %s" % [gs.IMPLEMENTATIONS.size(), bloquants])

	# ── Le vrai voile, posé par le vrai code ────────────────────────────────
	gs.round_active = true
	gs.sandbox_mode = true
	gs.training_mode = false
	gs.countdown_left = 0.0
	gs.ui._is_main_menu = false
	gs.p2.global_position = Vector2(4000.0, 4000.0)
	_vider(gs)
	await process_frame
	gs.p1.equip_weapon(gs.weapon_for_index(_index_de(gs, "spectre")))
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs.p1.rotation = 0.0
	gs.spawn_gadget(gs.p1, gs.p1.global_position, 0.0)
	await process_frame
	await physics_frame
	var voiles := _gadgets_de(gs, 0)
	_check("le voile est posé", voiles.size() == 1, str(voiles.size()))
	if voiles.size() != 1:
		return
	var v = voiles[0]
	_check("il porte la couche des gadgets bloquants",
		(v.collision_layer & bloquant) != 0, str(v.collision_layer))
	_check("et garde celle des gadgets : les balles le voient encore",
		(v.collision_layer & _MG.BULLET_MASK & _MG.GADGET_LAYER) != 0, str(v.collision_layer))
	_check("il n'est pas pour autant sur la couche des murs",
		(v.collision_layer & _MG.WALL_LAYER) == 0, str(v.collision_layer))
	_check("les balles le traversent toujours", not v.arrete_les_balles)

	# ── Sa forme : la bande de son ombre, plus un disque ────────────────────
	var bande := Vector2(_GV.DEMI_LONGUEUR, _GV.DEMI_EPAISSEUR) * 2.0
	var forme: CollisionShape2D = v.get_node_or_null("Forme")
	_check("sa collision est une bande, pas un disque",
		forme != null and forme.shape is RectangleShape2D
			and (forme.shape as RectangleShape2D).size.is_equal_approx(bande),
		str(forme.shape) if forme != null else "absente")
	var occ: LightOccluder2D = v.get_node_or_null("Occluder")
	var boite := Rect2()
	if occ != null and occ.occluder.polygon.size() > 0:
		boite = Rect2(occ.occluder.polygon[0], Vector2.ZERO)
		for p in occ.occluder.polygon:
			boite = boite.expand(p)
	_check("la même bande que son ombre, au pixel près",
		occ != null and boite.size.is_equal_approx(bande), str(boite))
	var espace: PhysicsDirectSpaceState2D = v.get_world_2d().direct_space_state
	var centre: Vector2 = v.global_position
	# Posé en travers d'un regard vers +x : la toile court le long de l'axe y.
	_check("à 30 px à côté de la toile il n'y a rien — le disque de 84 px n'existe plus",
		not _touche_le(espace, v, centre + Vector2(30.0, 0.0)))
	_check("sur la toile, à 60 px de son centre, il y a bien le voile",
		_touche_le(espace, v, centre + Vector2(0.0, 60.0)))

	# ── La toile ondule, et reste dans la bande ─────────────────────────────
	var toile: Line2D = v.get_node_or_null("Visuel")
	_check("la toile porte son image, étirée d'un piquet à l'autre",
		toile != null and toile.texture != null
			and toile.texture_mode == Line2D.LINE_TEXTURE_STRETCH)
	var piquet_g: Node2D = v.get_node_or_null("PiquetG")
	var piquet_d: Node2D = v.get_node_or_null("PiquetD")
	_check("les deux piquets sont plantés aux bouts de la toile",
		piquet_g != null and piquet_d != null
			and is_equal_approx(piquet_g.position.x, -_GV.DEMI_LONGUEUR)
			and is_equal_approx(piquet_d.position.x, _GV.DEMI_LONGUEUR))
	if toile != null:
		var avant := toile.points
		v._process(0.3)
		var apres := toile.points
		var bouge := false
		for i in avant.size():
			if absf(avant[i].y - apres[i].y) > 0.01:
				bouge = true
		_check("la toile ondule : ses points bougent", bouge)
		var dernier := apres.size() - 1
		_check("tenue aux piquets : ses deux bouts ne bougent jamais",
			absf(apres[0].y) < 1e-4 and absf(apres[dernier].y) < 1e-4
				and is_equal_approx(apres[0].x, -_GV.DEMI_LONGUEUR)
				and is_equal_approx(apres[dernier].x, _GV.DEMI_LONGUEUR),
			"%s … %s" % [apres[0], apres[dernier]])
	var pire := 0.0
	for iu in range(41):
		for it in range(120):
			pire = maxf(pire, absf(_GV.decalage(iu / 40.0, it * 0.037, _GV.SECOUSSE_MAX)))
	_check("l'onde, secousse comprise, ne sort jamais de la bande qui arrête",
		pire + _GV.LARGEUR_TOILE / 2.0 <= _GV.DEMI_EPAISSEUR + 1e-4,
		"%.2f + %.2f px pour %.2f" % [pire, _GV.LARGEUR_TOILE / 2.0, _GV.DEMI_EPAISSEUR])
	v.secouer()
	var s0: float = v._secousse
	v._process(1.0)
	_check("une balle la secoue, et le frisson s'éteint en une seconde",
		s0 > 0.0 and v._secousse < s0 * 0.05, "%.3f puis %.3f" % [s0, v._secousse])
	_check("la balle qui la traverse la secoue",
		FileAccess.get_file_as_string("res://bullet.gd").contains("gadget.secouer()"))

	# ── Et un joueur qui marche dessus s'y arrête ───────────────────────────
	var depart := centre + Vector2(70.0, 0.0)
	var arret: Vector2 = await _marcher(gs, depart, 90)
	_check("un joueur qui marche droit sur le voile s'y arrête",
		arret.x > centre.x + _GV.DEMI_EPAISSEUR,
		"parti de x = %.0f, arrêté à x = %.1f, toile à x = %.0f" % [depart.x, arret.x, centre.x])
	# ⚠️ Le TÉMOIN : le même pas, voile retiré, doit passer. Sans lui, un mur de la
	# carte au même endroit — ou un joueur qui ne marche pas — ferait passer le
	# contrôle ci-dessus pour une mauvaise raison.
	v.queue_free()
	await process_frame
	await physics_frame
	var libre: Vector2 = await _marcher(gs, depart, 90)
	_check("témoin : voile retiré, le même pas passe de l'autre côté",
		libre.x < centre.x - _GV.DEMI_EPAISSEUR, "arrêté à x = %.1f" % libre.x)
	gs.sandbox_mode = false
	gs.round_active = false


## Fait marcher J1 vers la gauche depuis `depart`, `images` pas de physique durant,
## et rend l'endroit où il s'est arrêté.
func _marcher(gs: Node, depart: Vector2, images: int) -> Vector2:
	var m := Marcheur.new()
	m.direction = Vector2.LEFT
	gs.p1.input_provider = m
	gs.p1.global_position = depart
	gs.p1.velocity = Vector2.ZERO
	for i in range(images):
		await physics_frame
	m.direction = Vector2.ZERO
	return gs.p1.global_position


func _touche_le(espace: PhysicsDirectSpaceState2D, cible: Node, point: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = point
	q.collision_mask = _MG.GADGET_LAYER
	for r in espace.intersect_point(q):
		if r["collider"] == cible:
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════════
# ÉTAPE 28, LOT B — formes et pose (2026-09-11)
# ═══════════════════════════════════════════════════════════════════════════

## Tire une vraie balle de J1 (`_do_spawn_bullet`) et rend l'endroit où elle a fini
## — ou celui où elle vole encore —, puis la RETIRE : une balle qui passe vole
## toujours, et toucherait le prochain corps posé sur sa ligne. `Vector2.INF` si
## aucune balle n'est née : l'appelant doit le refuser, INF passant tous les seuils.
##
## Échantillonnée en boucle, SANS lambda qui la capture (piège « Une lambda ne peut
## pas attendre la mort de ce qu'elle capture ») ; `_fade_and_destroy` la fige au
## point d'impact et coupe son pas de physique. Retrouvée par son SCRIPT, pas par son
## nom (piège « Godot renomme les homonymes »).
func _trajet_de_balle(gs: Node, depart: Vector2, rot: float) -> Vector2:
	var avant: Array = gs.bullet_container.get_children()
	gs._do_spawn_bullet(gs.p1, depart, rot, gs.p1.current_weapon)
	var balle: Node2D = null
	for c in gs.bullet_container.get_children():
		if not avant.has(c) and c.get_script() != null \
				and c.get_script().resource_path == "res://bullet.gd":
			balle = c
	if balle == null:
		return Vector2.INF
	var vu: Vector2 = balle.global_position
	for i in range(6):
		await physics_frame
		if not is_instance_valid(balle):
			break
		vu = balle.global_position
		if not balle.is_physics_processing():
			break
	if is_instance_valid(balle):
		balle.free()
	return vu


## Le gadget `g` chevauche-t-il `corps` ? Par une REQUÊTE D'ESPACE — un autre chemin
## que celui du jeu (`Shape2D.collide` sur les transformées) : les deux ne se
## trompent pas pareil. Sur la couche RÉELLE du corps, pas sur une couche supposée.
## À appeler DEUX `physics_frame` après le dernier déplacement du corps (piège « Un
## corps cinématique téléporté n'existe pour les requêtes qu'au pas suivant »).
func _chevauche(g: Node, corps: CollisionObject2D, decalage := Vector2.ZERO) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = (g.get_node("Forme") as CollisionShape2D).shape
	q.transform = Transform2D(g.global_rotation, g.global_position + decalage)
	q.collision_mask = corps.collision_layer
	q.collide_with_bodies = true
	for r in g.get_world_2d().direct_space_state.intersect_shape(q, 64):
		if r["collider"] == corps:
			return true
	return false


## Un mur provisoire, en travers du regard de J1, dont la face est à `face` px du
## poseur. Nommé, sous le nœud des joueurs — le même monde 2D, que `_point_de_pose`
## interroge. Deux pas de physique : un corps neuf n'est pas vu d'une requête avant.
func _mur_de_test(gs: Node, face: float) -> StaticBody2D:
	var mur := StaticBody2D.new()
	mur.name = "MurDeTest"
	mur.collision_layer = _MG.WALL_LAYER
	mur.collision_mask = 0
	var forme := CollisionShape2D.new()
	forme.name = "Forme"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10.0, 240.0)
	forme.shape = rect
	mur.add_child(forme)
	gs.p1.get_parent().add_child(mur)
	mur.global_position = POSEUR + Vector2(face + 5.0, 0.0)
	await physics_frame
	await physics_frame
	return mur


## Pose le gadget de `classe` depuis `POSEUR`, regard vers +x, J2 en `pos_j2`, par le
## vrai `spawn_gadget` de l'hôte ; rend l'unique gadget de J1, ou `null`.
##
## Les deux corps à rotation NULLE et à l'arrêt : le Marcheur ne fait que RAPPROCHER
## la rotation de sa visée, et un nez resté tourné vers le poseur fausserait le recul.
func _poser(gs: Node, classe: String, pos_j2: Vector2) -> Node:
	_vider(gs)
	gs._gadget_attente.fill(0.0)
	gs.p1.equip_weapon(gs.weapon_for_index(_index_de(gs, classe)))
	for j in [gs.p1, gs.p2]:
		j.rotation = 0.0
		j.velocity = Vector2.ZERO
	gs.p1.global_position = POSEUR
	gs.p2.global_position = pos_j2
	await physics_frame
	await physics_frame
	gs.spawn_gadget(gs.p1, POSEUR, 0.0)
	await process_frame
	var poses := _gadgets_de(gs, 0)
	return poses[0] if poses.size() == 1 else null


## L'ombre habitée arrête balles et regard par sa PLAQUE, la même que son ombre
## (étape 28, 2026-09-11). Sa collision était jusque-là le disque de 18 px du socle :
## une balle qui longeait la plaque à 10 px de son plan s'arrêtait sur du vide.
func _test_ombre_plaque(gs: Node) -> void:
	print("\n[L'ombre habitée arrête par sa plaque, plus par un disque]")
	# ⚠️ Le bac à sable, ici, sert à échapper à la recharge, et à rien d'autre (piège
	# « Un test qui force l'état ne voit pas l'état réel ») : ni la forme, ni la balle,
	# ni le regard ne lisent d'autre drapeau que la garde `round_active or
	# sandbox_mode`, qu'un vrai match passe aussi.
	gs.round_active = true
	gs.sandbox_mode = true
	gs.training_mode = false
	gs.countdown_left = 0.0
	gs.ui._is_main_menu = false
	gs.p2.global_position = _LOIN
	_vider(gs)
	await process_frame
	gs.p1.equip_weapon(gs.weapon_for_index(_index_de(gs, "occulteur")))
	gs.p1.global_position = POSEUR
	gs.p1.rotation = 0.0
	gs._gadget_attente.fill(0.0)
	gs.spawn_gadget(gs.p1, POSEUR, 0.0)
	await process_frame
	await physics_frame
	var ombres := _gadgets_de(gs, 0)
	_check("l'ombre habitée est posée", ombres.size() == 1, str(ombres.size()))
	if ombres.size() != 1:
		return
	var o = ombres[0]
	_check("à pleine portée : aucun mur ne l'a ramenée",
		o.global_position.is_equal_approx(POSEUR + Vector2(_GB.PORTEE_POSE, 0.0)),
		str(o.global_position))
	_check("l'Occulteur tire une balle à la fois",
		gs.p1.current_weapon.projectile_count == 1, str(gs.p1.current_weapon.projectile_count))
	# Les points de vie ne sont pas ce qu'on éprouve : les balles du contrôle ne
	# doivent pas la tuer.
	o.pv = 1000.0
	var c: Vector2 = o.global_position

	# ── Sa forme : la plaque de son ombre ───────────────────────────────────
	var plaque := Vector2(_GO.DEMI_TORSE, _GO.DEMI_EPAISSEUR) * 2.0
	var forme: CollisionShape2D = o.get_node_or_null("Forme")
	_check("sa collision est une plaque, plus un disque",
		forme != null and forme.shape is RectangleShape2D
			and (forme.shape as RectangleShape2D).size.is_equal_approx(plaque),
		str(forme.shape) if forme != null else "absente")
	var occ: LightOccluder2D = o.get_node_or_null("Occluder")
	var boite := Rect2()
	if occ != null and occ.occluder.polygon.size() > 0:
		boite = Rect2(occ.occluder.polygon[0], Vector2.ZERO)
		for p in occ.occluder.polygon:
			boite = boite.expand(p)
	_check("la même plaque que son ombre, au pixel près",
		occ != null and boite.size.is_equal_approx(plaque), str(boite))
	var espace: PhysicsDirectSpaceState2D = o.get_world_2d().direct_space_state
	# Posée en travers d'un regard vers +x : la longueur de la plaque court le long de
	# l'axe y, son épaisseur le long de x.
	_check("à 10 px de son plan il n'y a rien — le disque de 18 px n'existe plus",
		not _touche_le(espace, o, c + Vector2(10.0, 0.0)))
	_check("sur la plaque, à 15 px de son centre, il y a bien l'ombre",
		_touche_le(espace, o, c + Vector2(0.0, 15.0)))

	# ── La balle : J2 loin, pour qu'elle ne rencontre que ce qu'on éprouve ───
	gs.p2.global_position = _LOIN
	await physics_frame
	await physics_frame
	var longe: Vector2 = await _trajet_de_balle(gs, c + Vector2(10.0, -80.0), PI / 2.0)
	_check("une balle qui longe la plaque à 10 px de son plan passe",
		longe.is_finite() and longe.y > c.y + 22.0, "finie en %s, plaque en %s" % [longe, c])
	var tranche: Vector2 = await _trajet_de_balle(gs, c + Vector2(0.0, -80.0), PI / 2.0)
	_check("une balle qui la prend dans sa longueur s'y arrête",
		tranche.is_finite() and tranche.y > c.y - 30.0 and tranche.y < c.y,
		"finie en %s, plaque en %s" % [tranche, c])

	# ── Le regard : la collision suffit, sans `regard_par_la_forme` ─────────
	_check("J2 est en jeu", gs._en_jeu(gs.p2))
	_check("J2 est sur la couche 1 : le rayon d'éblouissement le rencontre",
		gs.p2.get_collision_layer_value(1))
	gs.p2.global_position = c + Vector2(10.0, 150.0)
	await physics_frame
	await physics_frame
	_check("le regard qui longe la plaque à 10 px passe",
		gs._ligne_de_vue_depuis(espace, c + Vector2(10.0, -150.0), gs.p2, RID()))
	gs.p2.global_position = c + Vector2(0.0, 150.0)
	await physics_frame
	await physics_frame
	_check("le regard qui la traverse est coupé",
		not gs._ligne_de_vue_depuis(espace, c + Vector2(0.0, -150.0), gs.p2, RID()))
	# ⚠️ Le TÉMOIN du contrôle négatif : la même ombre, qui n'arrête plus la lumière,
	# laisse passer le même regard. Sans lui, un J2 que le rayon ne verrait pas ferait
	# passer « coupé » pour une mauvaise raison.
	o.occulte_la_lumiere = false
	_check("témoin : ombre retirée du regard, le même regard passe",
		gs._ligne_de_vue_depuis(espace, c + Vector2(0.0, -150.0), gs.p2, RID()))
	o.occulte_la_lumiere = true

	# ── Le témoin de la balle : ombre retirée, la balle du centre passe ──────
	gs.p2.global_position = _LOIN
	await physics_frame
	await physics_frame
	o.queue_free()
	await process_frame
	await physics_frame
	_check("l'ombre est retirée", _gadgets_de(gs, 0).is_empty())
	var libre: Vector2 = await _trajet_de_balle(gs, c + Vector2(0.0, -80.0), PI / 2.0)
	_check("témoin : ombre retirée, la même balle passe — rien d'autre ne l'arrêtait",
		libre.is_finite() and libre.y > c.y + 22.0, "finie en %s" % libre)

	gs.p2.global_position = _LOIN
	gs.round_active = false
	gs.sandbox_mode = false
	_vider(gs)


## Un voile ne naît pas sur un corps : son point de pose RECULE vers le poseur
## (étape 28, 2026-09-11, Adrien : « on recule le point de pose »). Sans place, la
## pose est refusée et rien n'est armé.
func _test_voile_hors_des_corps(gs: Node) -> void:
	print("\n[Un voile ne naît pas sur un corps : il recule vers son poseur]")
	# ⚠️ Les drapeaux d'un VRAI match — ceux de `_preparer`, pas le bac à sable du test
	# précédent (piège « Un test qui force l'état ne voit pas l'état réel »). C'est en
	# match que le cas se pose : à l'entraînement J2 est masqué, hors du compte
	# (`_en_jeu`). Et hors bac à sable seulement, `gadget_disponible()` lit la
	# recharge : en bac à sable il rend toujours vrai, et « rien d'armé » serait vert
	# même si le refus armait tout.
	gs.round_active = true
	gs.sandbox_mode = false
	gs.training_mode = false
	gs.countdown_left = 0.0
	gs.ui._is_main_menu = false
	var fournisseur_j1 = gs.p1.input_provider
	var fournisseur_j2 = gs.p2.input_provider
	gs.p1.input_provider = Marcheur.new()
	gs.p2.input_provider = Marcheur.new()
	_check("J2 est en jeu : son corps compte", gs._en_jeu(gs.p2))
	_check("J2 est sur la couche 1", gs.p2.get_collision_layer_value(1))
	var mur: StaticBody2D = null

	# ── B1, le témoin : J2 hors de la bande ─────────────────────────────────
	var v = await _poser(gs, "spectre", POSEUR + Vector2(200.0, 30.0))
	_check("témoin : J2 hors de la bande, le voile naît à pleine portée — et aucun mur ne l'a ramené",
		v != null and v.global_position.is_equal_approx(POSEUR + Vector2(_GB.PORTEE_POSE, 0.0)),
		str(v.global_position) if v != null else "aucun voile")

	# ── B2-B4 : J2 dans la bande ─────────────────────────────────────────────
	# ⚠️ J2 est décalé de 30 px sur le côté, et c'est le point clé. Pile dans l'axe, il
	# arrêterait le rayon de `_point_de_pose` (les joueurs sont sur la couche des
	# murs) : l'ancien code poserait déjà plus près, et le recul passerait pour une
	# mauvaise raison.
	v = await _poser(gs, "spectre", POSEUR + Vector2(96.0, 30.0))
	_check("J2 dans la bande : le voile est posé quand même", v != null)
	if v != null:
		var d: float = v.global_position.x - POSEUR.x
		print("    recul : voile à d = %.1f px du poseur (70 attendu, calculé sur les polygones de player.tscn)" % d)
		_check("dans l'axe du regard", absf(v.global_position.y - POSEUR.y) < 0.01,
			str(v.global_position))
		_check("il a reculé vers son poseur", d < _GB.PORTEE_POSE - gs.PAS_RECUL_POSE,
			"%.1f px" % d)
		await physics_frame
		await physics_frame
		_check("il ne chevauche pas J2", not _chevauche(v, gs.p2))
		_check("ni son poseur", not _chevauche(v, gs.p1))
		_check("et n'a pas reculé plus que nécessaire : un pas plus loin, il mordrait J2",
			_chevauche(v, gs.p2, Vector2(gs.PAS_RECUL_POSE, 0.0)))

	# ── B5, le témoin du drapeau : l'ombre habitée ne recule pas ────────────
	var o = await _poser(gs, "occulteur", POSEUR + Vector2(96.0, 30.0))
	_check("témoin : l'ombre habitée, qui n'arrête pas les joueurs, ne recule pas",
		o != null and o.global_position.is_equal_approx(POSEUR + Vector2(_GB.PORTEE_POSE, 0.0)),
		str(o.global_position) if o != null else "aucune ombre")
	if o != null:
		await physics_frame
		await physics_frame
		_check("et elle chevauche bien J2 : c'est le drapeau qui décide",
			_chevauche(o, gs.p2))

	# ── B8 : SANS AUCUN MUR, J2 dans l'axe, à bout portant ───────────────────
	# ⚠️ Le rayon de `_point_de_pose` s'arrête sur lui (les joueurs sont sur la couche
	# des murs), et le recul ne cherche qu'en deçà : entre son dos et le nez du poseur,
	# la bande n'a pas la place. C'est le voile posé à bout portant sur l'adversaire
	# qu'on vise — mesuré à la correction du lot B, et la doc affirmait le contraire.
	var poses_avant: int = gs._gadgets_poses
	var par_avant: int = gs._gadgets_poses_par[0]
	v = await _poser(gs, "spectre", POSEUR + Vector2(55.0, 0.0))
	var arret: Vector2 = gs._point_de_pose(gs.p1, POSEUR, 0.0)
	_check("sans mur, J2 dans l'axe à 55 px : le rayon de pose s'arrête sur lui",
		arret.is_equal_approx(POSEUR + Vector2(31.0, 0.0)), str(arret))
	_check("et le voile est refusé : pas la place entre son dos et le nez du poseur",
		v == null, str(v.global_position) if v != null else "")
	_check("sans rien d'armé ni compté",
		gs.attente_gadget(0) == 0.0 and gs.gadget_disponible(0)
			and gs._gadgets_poses == poses_avant and gs._gadgets_poses_par[0] == par_avant,
		"attente %.1f s, %d → %d" % [gs.attente_gadget(0), poses_avant, gs._gadgets_poses])
	# Le TÉMOIN : 7 px plus loin, la bande tient entre les deux corps — ce qui refusait
	# à 55 px, c'était bien la place.
	v = await _poser(gs, "spectre", POSEUR + Vector2(62.0, 0.0))
	_check("témoin : J2 dans l'axe à 62 px, le voile tient entre les deux, en (436, 400)",
		v != null and v.global_position.is_equal_approx(POSEUR + Vector2(36.0, 0.0)),
		str(v.global_position) if v != null else "aucun voile")

	# ── B6 : aucune place — un mur à 36 px, le voile tomberait dans le nez ───
	mur = await _mur_de_test(gs, 36.0)
	poses_avant = gs._gadgets_poses
	par_avant = gs._gadgets_poses_par[0]
	v = await _poser(gs, "spectre", _LOIN)
	_check("un mur à 36 px : aucune place, aucun voile",
		v == null, str(v.global_position) if v != null else "")
	_check("et rien d'armé : pas de recharge", gs.attente_gadget(0) == 0.0,
		"%.1f s" % gs.attente_gadget(0))
	_check("le gadget reste disponible", gs.gadget_disponible(0))
	_check("ni numéro ni pose comptés",
		gs._gadgets_poses == poses_avant and gs._gadgets_poses_par[0] == par_avant,
		"%d → %d, %d → %d" % [poses_avant, gs._gadgets_poses, par_avant, gs._gadgets_poses_par[0]])

	# ── B6t, le témoin : le mur à 60 px laisse la place ─────────────────────
	mur.free()
	mur = await _mur_de_test(gs, 60.0)
	v = await _poser(gs, "spectre", _LOIN)
	_check("témoin : un mur à 60 px, le voile naît 6 px devant lui",
		v != null and v.global_position.is_equal_approx(POSEUR + Vector2(54.0, 0.0)),
		str(v.global_position) if v != null else "aucun voile")

	# ── B7 : par le VRAI joueur, qui appuie sur sa touche ────────────────────
	mur.free()
	mur = await _mur_de_test(gs, 36.0)
	_vider(gs)
	gs._gadget_attente.fill(0.0)
	gs.p1.equip_weapon(gs.weapon_for_index(_index_de(gs, "spectre")))
	gs.p1.global_position = POSEUR
	gs.p1.rotation = 0.0
	gs.p1.velocity = Vector2.ZERO
	gs.p1.input_provider = Marcheur.new()
	gs.p1.shoot_cooldown = 0.0
	# Une image touche relâchée : le front montant de l'appui suivant est neuf.
	await physics_frame
	poses_avant = gs._gadgets_poses
	par_avant = gs._gadgets_poses_par[0]
	gs.p1.input_provider = Poseur.new()
	# UN pas : à la reprise, le pas qui pose est terminé.
	await physics_frame
	# Le désarmement vaut 0,30 s et décroît au temps RÉEL (`_process`) : un seul pas
	# plus tard, il en reste presque tout — la marge ne dépend d'aucune cadence.
	_check("le vrai joueur a appuyé : il est désarmé", gs.p1.shoot_cooldown > 0.0,
		"%.3f s" % gs.p1.shoot_cooldown)
	await process_frame
	_check("mais aucun voile n'est né", _gadgets_de(gs, 0).is_empty(),
		str(_gadgets_de(gs, 0).size()))
	_check("et rien d'armé : ni recharge, ni pose comptée",
		gs.attente_gadget(0) == 0.0 and gs.gadget_disponible(0)
			and gs._gadgets_poses == poses_avant and gs._gadgets_poses_par[0] == par_avant,
		"attente %.1f s" % gs.attente_gadget(0))

	# ── B7t, le témoin : mur retiré, le même appui pose ─────────────────────
	mur.free()
	mur = null
	await physics_frame
	# ⚠️ Le désarmement du refus court encore : sans cette remise à zéro, la garde de
	# pose (`shoot_cooldown <= 0`) bloquerait le témoin pour une mauvaise raison.
	gs.p1.shoot_cooldown = 0.0
	gs.p1.input_provider = Marcheur.new()
	await physics_frame
	gs.p1.input_provider = Poseur.new()
	await physics_frame
	await process_frame
	var voiles := _gadgets_de(gs, 0)
	_check("témoin : mur retiré, le même appui pose le voile à pleine portée",
		voiles.size() == 1
			and voiles[0].global_position.is_equal_approx(POSEUR + Vector2(_GB.PORTEE_POSE, 0.0)),
		"%d voile(s)%s" % [voiles.size(),
			(" en " + str(voiles[0].global_position)) if voiles.size() == 1 else ""])

	# ── Nettoyage : J1 ne doit pas garder la touche tenue pour la suite ──────
	if mur != null and is_instance_valid(mur):
		mur.free()
	gs.p1.input_provider = fournisseur_j1
	gs.p2.input_provider = fournisseur_j2
	gs.p2.global_position = _LOIN
	gs._gadget_attente.fill(0.0)
	gs.round_active = false
	gs.sandbox_mode = false
	_vider(gs)


## Les images de jeu des gadgets — décision d'Adrien du 2026-09-10 : tous ceux qui
## peuvent en avoir une en ont une. Une exception, et elle est décidée : le LEURRE
## porte la silhouette de son poseur.
func _test_sprites_des_gadgets(gs: Node) -> void:
	print("\n[Les gadgets ont leurs images]")
	var attendus := {
		"voile": ["Visuel", "PiquetG", "PiquetD"],
		"ombre_habitee": ["Visuel"],
		"torche_fantome": ["Visuel", "Tete"],
		"mine_magnesium": ["Visuel"],
		"nappe_braises": ["Visuel"],
		"cartouche_suie": ["Visuel"],
		"poussiere": ["Visuel"],
		"gresillement": ["Visuel"],
		"poudre_contact": ["Visuel"],
	}
	var sans_image := ["leurre"]
	# ⚠️ Chaque gadget du catalogue doit être rangé d'un côté ou de l'autre : un
	# onzième gadget qui n'y serait pas échapperait à tout ce qui suit.
	var oublies: Array[String] = []
	for slug in gs.IMPLEMENTATIONS:
		if not attendus.has(slug) and not sans_image.has(slug):
			oublies.append(String(slug))
	_check("chaque gadget du catalogue a une image, ou une raison de ne pas en avoir",
		oublies.is_empty(), str(oublies))

	var manques: Array[String] = []
	for slug in attendus:
		var g = load(String(gs.IMPLEMENTATIONS[slug]["script"])).new()
		g._monter_visuel()
		for nom in attendus[slug]:
			var n = g.get_node_or_null(nom)
			if n == null or not ("texture" in n) or n.texture == null:
				manques.append("%s/%s" % [slug, nom])
		g.free()
	_check("les neuf gadgets portent leurs images, pièce par pièce", manques.is_empty(),
		str(manques))

	# ⚠️ La poudre : ses empreintes PEINTES sont un décor, ses MARQUES de pas sont
	# les vraies traces, et les secondes doivent passer par-dessus — sinon elle
	# mentirait sur la seule chose qu'elle sait. Éprouvé dans le VRAI jeu et en
	# profondeurs ABSOLUES : les marques vivent dans l'arène, la nappe dans le
	# gadget, et comparer leurs `z_index` relatifs ne veut rien dire. C'est ce
	# qu'un premier contrôle faisait, et il a laissé passer une nappe posée par-
	# dessus toutes les traces. (Le leurre n'est pas monté ici : sans poseur, il
	# crie, et c'est voulu.)
	gs.round_active = true
	gs.sandbox_mode = true
	_vider(gs)
	for i in range(10):
		var c = gs.weapon_for_index(i)
		if c.gadget != null and String(c.gadget.slug) == "poudre_contact":
			gs.p1.equip_weapon(c)
	gs._do_spawn_gadget(0, gs.p1.global_position + Vector2(150.0, 0.0), 0.0, "poudre_contact", 900)
	var poudres := _gadgets_de(gs, 0)
	if poudres.size() != 1:
		_check("la poudre est posée", false, str(poudres.size()))
	else:
		var poudre = poudres[0]
		poudre._poser_marque(poudre.global_position + Vector2(10.0, 0.0), Vector2.RIGHT)
		var nappe: CanvasItem = poudre.get_node_or_null("Visuel")
		var marque: CanvasItem = poudre._marques.back() if not poudre._marques.is_empty() else null
		var sol: CanvasItem = gs.arena.get_node_or_null("CustomFloor")
		var murs: CanvasItem = gs.arena.get_node_or_null("CustomWalls")
		var zn := _z_absolu(nappe) if nappe != null else 999
		var zm := _z_absolu(marque) if marque != null else -999
		var detail := "nappe %d, marque %d, sol %s, murs %s" % [zn, zm,
			str(_z_absolu(sol)) if sol != null else "?", str(_z_absolu(murs)) if murs != null else "?"]
		_check("les marques de pas passent par-dessus les empreintes peintes", zm > zn, detail)
		_check("la nappe reste sous les murs, qu'elle ne doit pas recouvrir",
			murs != null and zn < _z_absolu(murs), detail)
		# À égalité avec le sol, l'ordre de l'arbre tranche : le nœud des gadgets
		# doit venir APRÈS l'arène, sans quoi la nappe passerait sous le sol.
		# Et assez sombre pour que les traces se lisent : à pleine clarté, poudre et
		# marques saturaient ensemble au blanc sous la torche (écart mesuré : nul).
		_check("la nappe est assombrie au niveau mesuré, pas au-delà",
			nappe != null and poudre.ASSOMBRISSEMENT <= 0.25
				and is_equal_approx(nappe.modulate.r, poudre.ASSOMBRISSEMENT)
				and is_equal_approx(nappe.modulate.g, poudre.ASSOMBRISSEMENT)
				and is_equal_approx(nappe.modulate.b, poudre.ASSOMBRISSEMENT),
			str(nappe.modulate) if nappe != null else "absente")
		_check("et au-dessus du sol : même profondeur, mais dessinée après lui",
			sol != null and zn >= _z_absolu(sol)
				and gs.bullet_container.get_parent() == gs.arena.get_parent()
				and gs.bullet_container.get_index() > gs.arena.get_index(), detail)
	_vider(gs)
	gs.sandbox_mode = false
	gs.round_active = false

	# ── La torche fantôme : la tête balaie, le pied reste posé ──────────────
	# Plusieurs instants : le balayage humain marque des pauses, et un seul instant
	# pourrait tomber pile dans l'une d'elles.
	var t = _GTF.new()
	t._monter_visuel()
	t.graine = 12345
	t._angle_depart = 0.4
	t.rotation = 0.4
	var pied: Node2D = t.get_node_or_null("Visuel")
	var tete: Node2D = t.get_node_or_null("Tete")
	var a_tourne := false
	var pied_fixe := true
	for age in [0.3, 0.9, 1.7, 2.6, 3.4, 5.1, 7.3]:
		t._age = age
		t._physics_process(0.0)
		# 0,05 rad : au-dessus du seul tremblement (≈ 0,02), qu'un balayage cassé
		# garderait — à 0,01, il passait pour un balayage (trouvé en revue).
		if absf(angle_difference(t.rotation, 0.4)) > 0.05:
			a_tourne = true
		if pied == null or absf(angle_difference(t.rotation + pied.rotation, 0.4)) > 1e-4:
			pied_fixe = false
	_check("la tête balaie avec le faisceau",
		tete != null and is_zero_approx(tete.rotation) and a_tourne)
	_check("le pied, lui, reste posé : il ne tourne pas, à aucun instant", pied_fixe)
	t.free()


## La profondeur de dessin RÉELLE d'un nœud : ses `z_index` cumulés jusqu'au
## premier ancêtre qui ne se dit plus relatif.
func _z_absolu(n: CanvasItem) -> int:
	var z := 0
	var courant: Node = n
	while courant is CanvasItem:
		z += (courant as CanvasItem).z_index
		if not (courant as CanvasItem).z_as_relative:
			break
		courant = courant.get_parent()
	return z


## « Il ne faut pas pouvoir détruire un gadget gazeux ou diffus avec des balles. On
## ne peut donc pas détruire la fusée éclairante. » — Adrien, 2026-09-11.
func _test_diffus_intouchables(gs: Node) -> void:
	print("\n[Un gadget diffus ne se tue pas à la balle]")
	var attendus := ["cartouche_suie", "nappe_braises", "poudre_contact", "poussiere"]
	var intouchables: Array[String] = []
	for slug in gs.IMPLEMENTATIONS:
		var g = load(String(gs.IMPLEMENTATIONS[slug]["script"])).new()
		if not g.touche_par_les_balles:
			intouchables.append(String(slug))
		g.free()
	intouchables.sort()
	_check("les intouchables sont exactement les deux nuages et les deux nappes",
		intouchables.size() == attendus.size()
			and attendus.all(func(s): return intouchables.has(s)),
		str(intouchables))
	# ⚠️ Le drapeau n'agit qu'en sortant de la couche que voient les balles : on le
	# vérifie sur le gadget posé, après `_ready()`.
	var hors_couche: Array[String] = []
	for slug in attendus:
		var g = load(String(gs.IMPLEMENTATIONS[slug]["script"])).new()
		root.add_child(g)
		if (g.collision_layer & _MG.BULLET_MASK) == 0:
			hors_couche.append(slug)
		g.free()
	_check("et une balle ne les rencontre plus : hors de toute couche qu'elle voit",
		hors_couche.size() == attendus.size(), str(hors_couche))
	await process_frame
	# La fusée n'a jamais eu de forme : c'est un test géométrique de bullet.gd qui
	# l'éteignait. Il doit avoir disparu, avec sa constante.
	var balle := FileAccess.get_file_as_string("res://bullet.gd")
	# Le CODE seul, commentaires retirés, et TOUT moyen d'extinction interdit : un
	# commentaire citant l'ancien nom faisait rougir, et un appel direct à
	# `eteindre()` sous un autre nom passait (trouvé en revue, 2026-09-11).
	var code := ""
	for ligne in balle.split("\n"):
		code += ligne.get_slice("#", 0) + "\n"
	_check("la balle n'éteint plus la fusée : aucun moyen d'extinction dans son code",
		not code.contains("eteindre(") and not code.contains("extinction")
			and not code.contains("_fusee_touchee_ce_pas"))
	_check("et son rayon d'extinction par balle a disparu du modèle",
		not FileAccess.get_file_as_string("res://fusee_modele.gd").contains("EXTINCTION_RAYON_BALLE"))


## « Il faudrait qu'on ne me voie pas dans la fumée, non ? Si j'éclaire dans la
## fumée, ça illumine toute la fumée. » — Adrien, 2026-09-11.
func _test_suie_masque(gs: Node) -> void:
	print("\n[Dans la suie, on ne voit plus le corps]")
	var s = load(String(gs.IMPLEMENTATIONS["cartouche_suie"]["script"])).new()
	var p = load(String(gs.IMPLEMENTATIONS["poussiere"]["script"])).new()
	_check("la suie masque le corps, la poussière non", s.masque_le_corps() and not p.masque_le_corps())
	s.free()
	p.free()
	gs.round_active = true
	gs.sandbox_mode = true
	gs.training_mode = false
	_vider(gs)
	for i in range(10):
		var c = gs.weapon_for_index(i)
		if c.gadget != null and String(c.gadget.slug) == "cartouche_suie":
			gs.p1.equip_weapon(c)
	gs.p1.global_position = Vector2(400.0, 400.0)
	gs._do_spawn_gadget(0, Vector2(520.0, 400.0), 0.0, "cartouche_suie", 951)
	var suie = null
	for g in _gadgets_de(gs, 0):
		suie = g
	_check("la suie est posée", suie != null)
	if suie == null:
		gs.sandbox_mode = false
		gs.round_active = false
		return
	suie._age = suie.duree_vie * 0.5
	gs.p2.visible = true
	gs.p2.global_position = suie.global_position
	await process_frame
	await process_frame
	# ⚠️ `_process` forcé avant de lire : `visual_enemy.modulate.a` a deux écrivains,
	# le brouillage en physique puis la suie en `_process`, et le rendu voit le
	# second. Lire entre les deux dépendait du hasard des images (trouvé en revue).
	gs.p2._process(0.0)
	_check("au cœur de la suie, l'autre ne voit plus le corps",
		gs.p2.visual_enemy.modulate.a < 0.02, "%.3f" % gs.p2.visual_enemy.modulate.a)
	_check("ni son ombre", not gs.p2.get_node("LightOccluder2D").visible)
	_check("et soi, on s'y devine encore", gs.p2.visual.modulate.a >= 0.35,
		"%.3f" % gs.p2.visual.modulate.a)
	if gs.p2.visual_enemy_ptr != null:
		_check("ni son pointeur", gs.p2.visual_enemy_ptr.modulate.a < 0.02,
			"%.3f" % gs.p2.visual_enemy_ptr.modulate.a)
	# Un tir DANS la suie : l'éclat dessiné — non éclairé, au-dessus de la masse —
	# disait la position exacte du tireur (trouvé en revue).
	gs.p2.trigger_shoot_visuals()
	var eclat: Sprite2D = gs.p2._eclat_de_bouche()
	_check("un tir dans la suie n'y montre pas son éclat dessiné",
		not eclat.visible or eclat.modulate.a < 0.02, "%.3f" % eclat.modulate.a)
	_check("une lampe tenue dans la suie n'en ressort pas",
		gs.facteur_de_lampe_a(suie.global_position) < 0.05,
		"%.3f" % gs.facteur_de_lampe_a(suie.global_position))
	_check("hors du nuage, la lampe est entière",
		is_equal_approx(gs.facteur_de_lampe_a(suie.global_position + Vector2(400.0, 0.0)), 1.0))
	gs.p1.flashlight_on = false
	gs.p2.flashlight_on = true
	_check("une lampe allumée DANS le nuage l'allume en entier",
		is_equal_approx(suie._lumiere_entrante(), 1.0), "%.3f" % suie._lumiere_entrante())
	gs.p2.flashlight_on = false
	gs.p2.global_position = Vector2(4000.0, 4000.0)
	_check("dans le noir, le nuage ne s'allume pas", is_zero_approx(suie._lumiere_entrante()),
		"%.3f" % suie._lumiere_entrante())
	_check("et il n'est plus éclairé point par point : image non éclairée",
		suie._masse != null and suie._masse.material == GadgetBase.materiau_peint_lumineux())

	# ── Une lampe DEHORS, braquée sur le nuage, l'allume ; dos tourné, non ──────
	# Le geste qu'Adrien décrit — « si j'éclaire dans la fumée » —, que seuls les
	# deux cas triviaux (lampe dedans, aucune lampe) éprouvaient (trouvé en revue).
	gs.p2.global_position = suie.global_position - Vector2(150.0, 0.0)
	gs.p2.rotation = 0.0
	gs.p2.flashlight_on = true
	var dehors: float = suie._lumiere_entrante()
	_check("une lampe dehors, braquée sur le nuage, l'allume", dehors > 0.1, "%.3f" % dehors)
	gs.p2.rotation = PI
	_check("dos tourné, non", is_zero_approx(suie._lumiere_entrante()),
		"%.3f" % suie._lumiere_entrante())
	gs.p2.flashlight_on = false
	gs.p2.global_position = Vector2(4000.0, 4000.0)

	# ── La FAUSSE torche obéit à la même règle (trouvé en revue) ─────────────────
	# Sans elle, la suie distinguait la vraie torche de la fausse : l'une allumait
	# le nuage, l'autre non ; l'une s'y étouffait, l'autre en sortait.
	var classe_j2 = gs.p2.current_weapon
	for i in range(10):
		var c = gs.weapon_for_index(i)
		if c.gadget != null and String(c.gadget.slug) == "torche_fantome":
			gs.p2.equip_weapon(c)
	gs._do_spawn_gadget(1, suie.global_position - Vector2(150.0, 0.0), 0.0, "torche_fantome", 952)
	var fausse = null
	for g in _gadgets_de(gs, 1):
		fausse = g
	_check("la fausse torche est posée", fausse != null)
	if fausse != null:
		fausse.rotation = 0.0
		var par_elle: float = suie._lumiere_entrante()
		_check("braquée sur le nuage, elle l'allume comme une vraie", par_elle > 0.1,
			"%.3f" % par_elle)
		fausse.global_position = suie.global_position
		fausse._physics_process(0.0)
		_check("posée dedans, elle l'allume en entier",
			is_equal_approx(suie._lumiere_entrante(), 1.0), "%.3f" % suie._lumiere_entrante())
		_check("et sa lumière n'en ressort pas",
			fausse._lumiere != null and fausse._lumiere.energy < 0.15,
			"%.3f" % (fausse._lumiere.energy if fausse._lumiere != null else -1.0))
		fausse.queue_free()
	if classe_j2 != null:
		gs.p2.equip_weapon(classe_j2)
	await process_frame
	await process_frame
	_check("hors de la suie, l'ombre revient", gs.p2.get_node("LightOccluder2D").visible)
	gs.p2._process(0.0)
	if gs.p2.visual_enemy_ptr != null:
		_check("et le pointeur réapparaît — il restait invisible après la suie",
			gs.p2.visual_enemy_ptr.modulate.a > 0.5, "%.3f" % gs.p2.visual_enemy_ptr.modulate.a)
	# Par le vrai chemin d'un tir — `_do_spawn_bullet` —, pas en appelant le nuage :
	# retirer la boucle de game_state ne faisait rien échouer (trouvé en revue).
	suie._pouls = 0.0
	gs._do_spawn_bullet(gs.p2, suie.global_position, 0.0, gs.p2.current_weapon)
	_check("un tir parti de l'intérieur fait pulser tout le nuage", suie._pouls >= 1.0,
		"%.2f" % suie._pouls)
	suie._pouls = 0.0
	gs._do_spawn_bullet(gs.p2, suie.global_position + Vector2(600.0, 0.0), 0.0,
		gs.p2.current_weapon)
	_check("un tir parti d'ailleurs, non", suie._pouls < 0.5, "%.2f" % suie._pouls)
	_vider(gs)
	gs.sandbox_mode = false
	gs.round_active = false


# ═══════════════════════════════════════════════════════════════════════════
# ÉTAPE 28, LOT C — des refus qui se sentent, des jauges de recharge (2026-09-11)
# ═══════════════════════════════════════════════════════════════════════════

## L'autoload réseau, TOUJOURS par le nœud et ses modes par chaîne : une suite lancée
## en `--script` qui le nommerait à la compilation cesserait de compiler en entier
## (piège « Une mesure contaminée par des erreurs de script ressemble à une mesure »).
func _nm() -> Node:
	return root.get_node("NetworkManager")


func _mode(nom: String) -> int:
	return int(_nm().get_script().get_script_constant_map()["GameMode"][nom])


## Remet J1 à l'état d'avant un appui. Une image touches lâchées — fronts et verrous
## de simulation levés —, puis désarmement, refus, fronts bruts et accumulateur à
## zéro : un cas ne doit rien hériter du précédent (un lancer arme le désarmement, et
## un `shoot_cooldown` hérité bloquerait la pose du cas suivant). Rend la main en
## DÉBUT d'image, avant le pas des nœuds.
func _remettre(gs: Node, b: Boutons) -> void:
	b.fusee = false
	b.gadget = false
	await physics_frame
	await physics_frame
	var p = gs.p1
	p.shoot_cooldown = 0.0
	p.refus_fusee = 0.0
	p.refus_gadget = 0.0
	p._fusee_tenue = false
	p._gadget_tenu = false
	p.derniere_vibration = Vector3.ZERO
	gs._fusees_accumulateur[0] = 0.0


## Presse (ou non) les deux boutons pendant UN pas de physique, et rend la main après
## ce pas. Juste après `_remettre`, qui rend la main avant le pas des nœuds : c'est ce
## pas-là qui lit l'appui.
func _appuyer(b: Boutons, fusee: bool, gadget: bool) -> void:
	b.fusee = fusee
	b.gadget = gadget
	await physics_frame


## Point 5 — un appui de fusée ou de gadget refusé se SENT (`refus_*`, que le HUD
## recopie dans la cartouche), et seulement un refus. Par le VRAI joueur qui presse,
## dans l'état RÉEL de l'entraînement — `sandbox_mode` et `training_mode` vrais,
## `round_active` faux —, là où Adrien essaie les classes (piège « Un test qui force
## l'état ne voit pas l'état réel »). Chaque contrôle négatif a son témoin.
func _test_refus_ressentis(gs: Node) -> void:
	print("\n[Un refus de fusée ou de gadget se sent — et seulement un refus]")
	var fournisseur = gs.p1.input_provider
	var arme_j2 = gs.p2.current_weapon
	var b := Boutons.new()
	gs.round_active = false
	gs.sandbox_mode = true
	gs.training_mode = true
	gs.countdown_left = 0.0
	_vider(gs)
	gs._gadget_attente.fill(0.0)
	gs._batterie.fill(1.0)
	# Le Parasite : une fusée, et le grésillement — le seul gadget qui se rallume.
	gs.p1.equip_weapon(gs.weapon_for_index(0))
	gs.p1.input_provider = b
	gs.p1.global_position = POSEUR
	gs.p1.rotation = 0.0
	gs.p1.velocity = Vector2.ZERO
	gs.p2.global_position = _LOIN
	# Deux pas : un corps téléporté n'existe pour les requêtes de la pose qu'au pas
	# suivant (piège « Un corps cinématique téléporté… »).
	await physics_frame
	await physics_frame

	# ── (a) TÉMOIN : une fusée en réserve, l'appui la lance, rien ne tremble ────
	await _remettre(gs, b)
	gs.rpc_stock_fusees(0, 1, -1.0)
	await _appuyer(b, true, false)
	_check("témoin : une fusée en réserve, l'appui la lance",
		gs.fusees_restantes(0) == 0, str(gs.fusees_restantes(0)))
	_check("et rien ne tremble — l'état est lu AVANT le lancer, pas après",
		gs.p1.refus_fusee == 0.0, "%.3f" % gs.p1.refus_fusee)
	# La VIBRATION, par la prise d'essai de `_rumble` (revue du lot C) : les suites
	# n'ont pas de manette, et `_rumble` sort à sa première ligne hors d'un
	# `LocalInputProvider`. Elle note la DEMANDE avant tout filtre — ce qu'elle prouve,
	# c'est la demande, pas le moteur qui tourne. Ce témoin montre qu'elle voit bien
	# les demandes : celle du lancer, qui n'est pas celle d'un refus.
	var vib_refus := Vector3(gs.p1.RUMBLE_REFUS, 0.0, 0.05)
	var vib_lancer := Vector3(gs.p1.RUMBLE_FLARE_WEAK, gs.p1.RUMBLE_FLARE_STRONG, 0.18)
	_check("témoin : le lancer demande SA vibration, pas celle d'un refus",
		gs.p1.derniere_vibration.is_equal_approx(vib_lancer), str(gs.p1.derniere_vibration))

	# ── (b) Réserve vide : l'appui tremble ────────────────────────────────────
	await _remettre(gs, b)
	gs.rpc_stock_fusees(0, 0, 60.0)
	await _appuyer(b, true, false)
	_check("réserve vide : l'appui refusé fait trembler la cartouche des fusées",
		gs.p1.refus_fusee > 0.2, "%.3f" % gs.p1.refus_fusee)
	_check("et la manette vibre : la signature du refus est demandée",
		gs.p1.derniere_vibration.is_equal_approx(vib_refus), str(gs.p1.derniere_vibration))

	# ── (c) Tenu : un refus, pas un bourdonnement ─────────────────────────────
	for i in range(40):
		await physics_frame
	_check("bouton tenu 40 images : le refus se dit UNE fois, il ne se réarme pas",
		gs.p1.refus_fusee == 0.0, "%.3f" % gs.p1.refus_fusee)
	# Le témoin, par le seul relâchement — sans rien remettre à la main.
	b.fusee = false
	await physics_frame
	b.fusee = true
	await physics_frame
	_check("témoin : relâché puis repressé, il se dit de nouveau",
		gs.p1.refus_fusee > 0.2, "%.3f" % gs.p1.refus_fusee)

	# ── (d) Pendant le cooldown, l'appui ATTEND : ce n'est pas un refus ───────
	await _remettre(gs, b)
	gs.rpc_stock_fusees(0, 1, -1.0)
	gs.p1.shoot_cooldown = 0.5
	await _appuyer(b, true, false)
	_check("un appui pendant le cooldown n'est pas un refus : rien ne tremble",
		gs.p1.refus_fusee == 0.0, "%.3f" % gs.p1.refus_fusee)
	_check("et la fusée attend son terme, toujours en réserve",
		gs.fusees_restantes(0) == 1, str(gs.fusees_restantes(0)))
	_check("et aucune vibration n'est demandée", gs.p1.derniere_vibration == Vector3.ZERO,
		str(gs.p1.derniere_vibration))

	# ── (j) La manche finit pendant le refus : il s'éteint quand même ─────────
	# Revue du lot C : décompté APRÈS les gardes de manche, un refus armé dans les
	# 0,22 s qui précèdent la fin restait figé tout l'entre-manche — la cartouche
	# décalée, puis un tremblement au FIGHT sur un appui que personne n'avait fait.
	# L'état d'une manche finie : ni manche, ni bac à sable, hors du menu principal.
	await _remettre(gs, b)
	gs.rpc_stock_fusees(0, 0, 60.0)
	await _appuyer(b, true, false)
	b.fusee = false
	var arme_fin: float = gs.p1.refus_fusee
	var menu_avant: bool = gs.ui._is_main_menu
	gs.ui._is_main_menu = false
	gs.sandbox_mode = false
	for i in range(20):
		await physics_frame
	var apres_fin: float = gs.p1.refus_fusee
	# Et chez le MORT, qui sort plus tôt encore (`if dead: return`).
	gs.p1.refus_gadget = gs.p1.DUREE_REFUS
	gs.p1.dead = true
	for i in range(20):
		await physics_frame
	var apres_mort: float = gs.p1.refus_gadget
	gs.p1.dead = false
	gs.sandbox_mode = true
	gs.ui._is_main_menu = menu_avant
	_check("témoin : le refus était armé quand la manche a fini", arme_fin > 0.2,
		"%.3f" % arme_fin)
	_check("manche finie, le refus s'éteint quand même — il ne se fige pas jusqu'au FIGHT",
		apres_fin == 0.0, "%.3f après 20 images" % apres_fin)
	_check("et chez le mort aussi", apres_mort == 0.0, "%.3f après 20 images" % apres_mort)

	# ── (e) Recharge de pose : l'appui tremble ; témoin : prêt, il pose ──────
	await _remettre(gs, b)
	gs._gadget_attente[0] = 30.0
	await _appuyer(b, false, true)
	_check("gadget en recharge : l'appui refusé fait trembler sa cartouche",
		gs.p1.refus_gadget > 0.2, "%.3f" % gs.p1.refus_gadget)
	_check("et la manette vibre, de la même signature que la fusée refusée",
		gs.p1.derniere_vibration.is_equal_approx(vib_refus), str(gs.p1.derniere_vibration))
	_check("et rien n'est posé", _gadgets_de(gs, 0).is_empty(), str(_gadgets_de(gs, 0).size()))
	await _remettre(gs, b)
	gs._gadget_attente[0] = 0.0
	await _appuyer(b, false, true)
	var bobines := _gadgets_de(gs, 0)
	_check("témoin : prêt, le même appui pose la bobine", bobines.size() == 1,
		str(bobines.size()))
	_check("et rien ne tremble", gs.p1.refus_gadget == 0.0, "%.3f" % gs.p1.refus_gadget)
	var bob = gs.gadget_basculable_de(0)
	_check("la bobine posée est allumée", bob != null and bob.actif)
	if bob != null:
		# ── (f) Allumée batterie basse : l'EXTINCTION passe toujours ─────────
		await _remettre(gs, b)
		gs._batterie[0] = 0.02
		await _appuyer(b, false, true)
		_check("allumée sous le seuil, l'appui l'éteint — l'extinction n'a pas de seuil",
			not bob.actif)
		_check("et rien ne tremble : jugé sur l'état d'AVANT l'appui",
			gs.p1.refus_gadget == 0.0, "%.3f" % gs.p1.refus_gadget)

		# ── (g) Éteinte batterie vide : le RALLUMAGE refusé tremble ──────────
		await _remettre(gs, b)
		gs._batterie[0] = 0.0
		await _appuyer(b, false, true)
		_check("éteinte batterie vide : le rallumage refusé fait trembler",
			gs.p1.refus_gadget > 0.2, "%.3f" % gs.p1.refus_gadget)
		_check("et elle reste éteinte", not bob.actif)
		await _remettre(gs, b)
		gs._batterie[0] = 0.5
		await _appuyer(b, false, true)
		_check("témoin : batterie à moitié, le même appui la rallume", bob.actif)
		_check("et rien ne tremble", gs.p1.refus_gadget == 0.0, "%.3f" % gs.p1.refus_gadget)

	# ── (h) CHEZ QUI A PRESSÉ SEULEMENT ─────────────────────────────────────
	# Sans image : `_sentir_les_refus` appelé directement, le mode basculé autour des
	# seuls appels — sur le patron de `test_netcode`, mais par le nœud.
	var nm := _nm()
	var mode_avant = nm.current_mode
	gs.p2.equip_weapon(gs.weapon_for_index(0))
	gs.rpc_stock_fusees(0, 0, 60.0)
	gs.rpc_stock_fusees(1, 0, 60.0)
	for j in [gs.p1, gs.p2]:
		j.refus_fusee = 0.0
		j._fusee_tenue = false
		j.derniere_vibration = Vector3.ZERO
	nm.current_mode = _mode("ONLINE_HOST")
	gs.p2._sentir_les_refus(gs, true, false, true)   # le client, que l'hôte simule
	gs.p1._sentir_les_refus(gs, true, false, true)   # le joueur de l'hôte
	nm.current_mode = mode_avant
	_check("chez l'hôte, le refus du CLIENT ne tremble pas — il apprendrait qu'il a essayé",
		gs.p2.refus_fusee == 0.0, "%.3f" % gs.p2.refus_fusee)
	_check("témoin : le même refus, chez le joueur de l'hôte, tremble",
		gs.p1.refus_fusee > 0.2, "%.3f" % gs.p1.refus_fusee)
	# La vibration suit le même garde : demandée pour le joueur de l'hôte, pas pour le
	# client qu'il simule (dont le fournisseur, en vrai, n'est de toute façon pas local).
	_check("et ne vibre pas davantage pour le client ; témoin : pour le sien, si",
		gs.p2.derniere_vibration == Vector3.ZERO
			and gs.p1.derniere_vibration.is_equal_approx(vib_refus),
		"client %s, hôte %s" % [gs.p2.derniere_vibration, gs.p1.derniere_vibration])
	for j in [gs.p1, gs.p2]:
		j.refus_fusee = 0.0
		j._fusee_tenue = false
	nm.current_mode = _mode("ONLINE_CLIENT")
	gs.p1._sentir_les_refus(gs, true, false, true)   # l'hôte, chez le client
	gs.p2._sentir_les_refus(gs, true, false, true)   # le joueur du client
	nm.current_mode = mode_avant
	_check("chez le client, le refus de l'HÔTE ne tremble pas non plus",
		gs.p1.refus_fusee == 0.0, "%.3f" % gs.p1.refus_fusee)
	_check("témoin : le sien, oui", gs.p2.refus_fusee > 0.2, "%.3f" % gs.p2.refus_fusee)
	for j in [gs.p1, gs.p2]:
		j.refus_fusee = 0.0
		j._fusee_tenue = false
	nm.current_mode = _mode("LOCAL_SPLITSCREEN")
	gs.p2._sentir_les_refus(gs, true, false, true)
	nm.current_mode = mode_avant
	_check("en écran scindé, chacun sent le sien : J2 aussi", gs.p2.refus_fusee > 0.2,
		"%.3f" % gs.p2.refus_fusee)
	gs.p2.refus_fusee = 0.0

	# ── (i) Le voile SANS PLACE : senti chez qui pose, décidé chez l'hôte ────
	# Décision de l'orchestrateur, 2026-09-11 : la place reste à l'hôte (lot B) ; le
	# pré-contrôle local ne fait que DIRE le refus. La pose part quand même, et le
	# désarmement a lieu comme avant — c'est ce qui garde les deux pairs d'accord.
	gs.p1.equip_weapon(gs.weapon_for_index(_index_de(gs, "spectre")))
	_vider(gs)
	gs._gadget_attente.fill(0.0)
	var mur: StaticBody2D = await _mur_de_test(gs, 36.0)
	await _remettre(gs, b)
	await _appuyer(b, false, true)
	_check("un mur à 36 px, le voile n'a pas de place : l'appui tremble",
		gs.p1.refus_gadget > 0.2, "%.3f" % gs.p1.refus_gadget)
	_check("et vibre de la signature du refus — pas de celle d'une pose",
		gs.p1.derniere_vibration.is_equal_approx(vib_refus), str(gs.p1.derniere_vibration))
	_check("mais la pose est PARTIE : le joueur est désarmé, comme chez l'hôte",
		gs.p1.shoot_cooldown > 0.0, "%.3f s" % gs.p1.shoot_cooldown)
	_check("et l'hôte l'a refusée : aucun voile, rien d'armé",
		_gadgets_de(gs, 0).is_empty() and gs.attente_gadget(0) == 0.0,
		"%d voile(s), attente %.1f s" % [_gadgets_de(gs, 0).size(), gs.attente_gadget(0)])
	# Le garde « chez qui a pressé », sur ce chemin-ci aussi.
	gs.p1.refus_gadget = 0.0
	nm.current_mode = _mode("ONLINE_CLIENT")
	gs.p1._sentir_pose_sans_place(gs)
	nm.current_mode = mode_avant
	_check("chez un pair qui ne pilote pas ce joueur, le pré-contrôle ne tremble pas",
		gs.p1.refus_gadget == 0.0, "%.3f" % gs.p1.refus_gadget)
	gs.p1._sentir_pose_sans_place(gs)
	_check("témoin : chez qui le pilote, le même pré-contrôle tremble",
		gs.p1.refus_gadget > 0.2, "%.3f" % gs.p1.refus_gadget)
	# TÉMOIN du chemin entier : mur retiré, le même appui pose, et rien ne tremble.
	mur.free()
	await _remettre(gs, b)
	await _appuyer(b, false, true)
	var voiles := _gadgets_de(gs, 0)
	_check("témoin : mur retiré, le même appui pose le voile, et rien ne tremble",
		voiles.size() == 1 and gs.p1.refus_gadget == 0.0,
		"%d voile(s), refus %.3f" % [voiles.size(), gs.p1.refus_gadget])

	# ── Nettoyage ───────────────────────────────────────────────────────────
	b.fusee = false
	b.gadget = false
	await physics_frame
	gs.p1.input_provider = fournisseur
	gs.p1.refus_fusee = 0.0
	gs.p1.refus_gadget = 0.0
	gs.p1.shoot_cooldown = 0.0
	if arme_j2 != null:
		gs.p2.equip_weapon(arme_j2)
	gs._gadget_attente.fill(0.0)
	gs._batterie.fill(1.0)
	gs.sandbox_mode = false
	gs.training_mode = false
	_vider(gs)


## Point 5, côté HUD — le tremblement décale le CONTENU de la cartouche APRÈS le tri
## natif du conteneur, et le rend exactement à sa place ensuite. Sans image : la
## notification de tri est appelée à la main, le delta du headless n'y entre pas.
##
## ⚠️ L'attendu est calculé avec le curseur RÉEL « Tremblements de l'interface » :
## sous le `HOME` d'Adrien il vaut 0 (tous ses curseurs CONFORT le sont), et tout
## décalage y est nul — contrôlé tel quel, avec un avertissement. La référence reste
## `run_suites.sh`, sous un `HOME` neuf.
func _test_secousse_de_cartouche(gs: Node) -> void:
	print("\n[Le refus fait trembler le contenu de la cartouche, puis le rend en place]")
	var res: Dictionary = gs.ui.p1_reserves
	var c = res["panel_gadget"]
	_check("la cartouche du gadget est une CartoucheReserve", c.has_method("secouer"))
	if not c.has_method("secouer"):
		return
	var curseur: float = _EP.curseur("tremblement_interface")
	if curseur <= 0.0:
		print("    ⚠️ curseur « Tremblements de l'interface » à %.2f sous ce HOME : " % curseur
			+ "tout décalage vaut 0 et est contrôlé tel quel — la référence reste run_suites.sh")

	# ── La fonction pure ────────────────────────────────────────────────────
	var d0: float = c.decalage_refus(0.22, 0.22, 1.0)
	_check("à l'armement, le premier écart est franc : toute l'amplitude",
		is_equal_approx(d0, c.AMPLITUDE_REFUS), "%.3f px" % d0)
	_check("éteint, plus rien ; curseur à zéro, plus rien",
		c.decalage_refus(0.0, 0.22, 1.0) == 0.0 and c.decalage_refus(0.2, 0.22, 0.0) == 0.0)
	# Le MAXIMUM le long de chaque bout, pas un point : un cosinus nul rendrait un
	# point isolé vert pour une mauvaise raison.
	var debut := 0.0
	var fin := 0.0
	for i in range(10):
		debut = maxf(debut, absf(c.decalage_refus(0.22 - 0.001 * i, 0.22, 1.0)))
		fin = maxf(fin, absf(c.decalage_refus(0.001 * (i + 1), 0.22, 1.0)))
	_check("il s'éteint : son dernier centième tremble moins de moitié que le premier",
		fin < debut * 0.5, "%.2f px à la fin, %.2f au début" % [fin, debut])

	# ── Dans le vrai conteneur ──────────────────────────────────────────────
	#
	# ⚠️ **Un conteneur CACHÉ ne trie pas ses enfants**, et le HUD l'est quand l'intro
	# a déjà été vue (`intro_vue=true`, qu'une étape antérieure du lot écrit dans le
	# `user://` partagé par toutes les suites) : le tri manuel ne recalait plus rien,
	# et le contenu gardait une position périmée. Vert seul, rouge dans le lot —
	# trouvé le 2026-09-11 en rejouant la séquence du lot. On rend visibles les
	# ancêtres cachés le temps des contrôles, deux images pour la mise en page, et on
	# rétablit tout ensuite.
	var caches: Array[Node] = []
	var n: Node = c
	while n != null:
		if (n is CanvasItem or n is CanvasLayer) and not n.visible:
			caches.append(n)
			n.visible = true
		n = n.get_parent()
	await process_frame
	await process_frame
	_check("la cartouche est visible le temps du contrôle — un conteneur caché ne trie pas",
		c.is_visible_in_tree(), "%d ancêtre(s) rendu(s) visible(s)" % caches.size())
	var m: Control = c.get_child(0)
	var bord: float = c.get_theme_stylebox("panel").get_margin(SIDE_LEFT)
	c.secousse = 0.0
	c._secousse_duree = 0.0
	c.notification(Container.NOTIFICATION_SORT_CHILDREN)
	_check("au repos, le contenu est à sa place, au bord du cadre",
		is_equal_approx(m.position.x, bord), "%.2f pour %.2f" % [m.position.x, bord])
	c.secouer(0.22)
	c.notification(Container.NOTIFICATION_SORT_CHILDREN)
	var attendu: float = bord + c.decalage_refus(0.22, 0.22, curseur)
	_check("au refus, le contenu est décalé APRÈS le tri du conteneur — pas effacé par lui",
		absf(m.position.x - attendu) < 0.01 and (curseur <= 0.0 or m.position.x - bord > 1.0),
		"%.2f pour %.2f (bord %.2f)" % [m.position.x, attendu, bord])
	# Les recopies de chaque image ne relancent pas l'enveloppe : une valeur plus
	# petite ne change rien, une plus grande prolonge sans changer la durée.
	c.secousse = 0.1
	c.secouer(0.09)
	var petite_ignoree: bool = is_equal_approx(c.secousse, 0.1)
	c.secouer(0.15)
	_check("une recopie plus petite ne change rien, et aucune ne relance l'enveloppe",
		petite_ignoree and is_equal_approx(c.secousse, 0.15)
			and is_equal_approx(c._secousse_duree, 0.22),
		"secousse %.3f, durée %.3f" % [c.secousse, c._secousse_duree])
	c.secousse = 0.0
	c._secousse_duree = 0.0
	c.notification(Container.NOTIFICATION_SORT_CHILDREN)
	_check("éteint, il revient EXACTEMENT à sa place", is_equal_approx(m.position.x, bord),
		"%.2f pour %.2f" % [m.position.x, bord])
	for cache in caches:
		cache.visible = false

	# ── De bout en bout : le HUD recopie le refus du joueur ────────────────
	gs.p1.refus_gadget = 0.2
	gs.p1.refus_fusee = 0.2
	_maj_hud(gs)
	_check("le HUD recopie le refus du joueur dans la cartouche du gadget",
		c.secousse > 0.19, "%.3f" % c.secousse)
	_check("et dans celle des fusées", res["panel_fusees"].secousse > 0.19,
		"%.3f" % res["panel_fusees"].secousse)
	gs.p1.refus_gadget = 0.0
	gs.p1.refus_fusee = 0.0
	for cle in ["panel_fusees", "panel_gadget"]:
		res[cle].secousse = 0.0
		res[cle]._secousse_duree = 0.0
		res[cle].notification(Container.NOTIFICATION_SORT_CHILDREN)


## Point 7 — la jauge des fusées. L'hôte envoie l'attente à chaque changement de
## réserve ; le client la décompte entre deux envois, sans estimer. Modélisé comme une
## FILE DE PAQUETS DATÉS : à chaque pas, l'hôte avance (et lance), le client décompte
## PUIS applique les paquets arrivés. Contrôle exact : le client au pas k affiche ce
## que l'hôte affichait au pas k − m, m pas faisant un demi-RTT — « à un RTT près »,
## sans aucune fenêtre exclue.
##
## ⚠️ **Deux instances, et c'est tout le test.** L'hôte est la vraie scène, en mode
## local (l'annonce s'y écrit par `call_local`, et sa jauge se lit sur sa cartouche).
## Le client est une `GameState` NUE, chargée ici — après `main.tscn` — et jamais
## nommée à la compilation : son accumulateur à lui n'avance jamais, c'est l'état RÉEL
## d'un client. Lire l'accumulateur de l'hôte ferait passer pour juste un client qui
## ne lit pas ce qu'on lui envoie. L'état de l'hôte est celui de l'entraînement, et
## le test est SYNCHRONE : aucune image n'avance son accumulateur au temps réel.
func _test_jauge_des_fusees(gs: Node) -> void:
	print("\n[La jauge des fusées : le client est l'hôte retardé d'un demi-RTT]")
	var ui = gs.ui
	_check("la jauge : pleine à attente nulle (« imminente », jusqu'au paquet)",
		ui.fraction_de_retour(0.0, 12.0) == 1.0, str(ui.fraction_de_retour(0.0, 12.0)))
	_check("vide à attente entière, aux trois quarts à 3 s sur 12",
		ui.fraction_de_retour(12.0, 12.0) == 0.0
			and is_equal_approx(ui.fraction_de_retour(3.0, 12.0), 0.75))
	_check("absente quand rien ne revient, ou sans période",
		ui.fraction_de_retour(-1.0, 12.0) < 0.0 and ui.fraction_de_retour(5.0, 0.0) < 0.0)

	var nm := _nm()
	var mode_avant = nm.current_mode
	gs.round_active = false
	gs.sandbox_mode = true
	gs.training_mode = true
	gs.countdown_left = 0.0
	_vider(gs)
	gs.p1.equip_weapon(gs.weapon_for_index(_index_de(gs, "allumeur")))
	gs._accorder_fusees(0.0)   # changement de classe : réserve semée, rien ne revient
	var profil = gs.p1.current_weapon.fusees
	var periode: float = profil.periode_recharge
	_check("l'Allumeur : deux fusées, une toutes les douze secondes",
		profil.plafond_effectif() == 2 and is_equal_approx(periode, 12.0),
		"%d fusées, %.1f s" % [profil.plafond_effectif(), periode])
	var cl: Node = load("res://game_state.gd").new()
	cl.round_active = false
	cl.sandbox_mode = true
	cl.training_mode = true

	# ── A : aucun retard, pas grossiers — deux lancers, un regain avec 0,5 s de
	# report, puis le plein.
	var a := _derouler(gs, cl, periode, 0,
		[0.0, 3.0, 3.0, 3.0, 3.5, 2.0, 3.0, 3.0, 3.0, 1.0], {0: 2})
	var entamees := 0
	for f in a["h"]:
		if f > 0.05 and f < 0.95:
			entamees += 1
	_check("A : le client affiche ce qu'affiche l'hôte, pas à pas",
		a["ecart"] < 1e-4, "écart %.5f — hôte %s, client %s" % [a["ecart"], a["h"], a["c"]])
	_check("A : et on a comparé des jauges ENTAMÉES, pas des absences",
		entamees >= 3, "%d entamées : %s" % [entamees, a["h"]])
	_check("A : juste après le premier lancer, le client attend douze secondes",
		is_equal_approx(float(a["att_c"][0]), 12.0), str(a["att_c"][0]))
	_check("A : le regain garde son report — 0,5 s sur 12 déjà faites",
		absf(float(a["h"][4]) - 0.5 / 12.0) < 1e-4, str(a["h"][4]))
	_check("A : réserve pleine, plus rien ne revient — ni chez l'un, ni chez l'autre",
		float(a["h"][-1]) < 0.0 and float(a["c"][-1]) < 0.0,
		"%.3f / %.3f" % [a["h"][-1], a["c"][-1]])

	# ── B : RTT 100 ms, soit un demi-RTT d'un pas de 0,05 s ; un lancer depuis le
	# plein, un second à 6 s, deux regains jusqu'au plein.
	var pas_b: Array = []
	for i in range(520):
		pas_b.append(0.05)
	var bb := _derouler(gs, cl, periode, 1, pas_b, {0: 1, 120: 1})
	var entamees_b := 0
	for f in bb["h"]:
		if f > 0.05 and f < 0.95:
			entamees_b += 1
	_check("B : le client au pas k affiche l'hôte au pas k − 1 — « à un RTT près »",
		bb["ecart"] < 1e-4, "écart %.5f" % bb["ecart"])
	_check("B : pendant le vol du premier paquet, le client n'invente rien",
		float(bb["c"][0]) < 0.0 and is_zero_approx(float(bb["h"][0])),
		"client %.3f, hôte %.3f" % [bb["c"][0], bb["h"][0]])
	_check("B : puis il l'a, douze secondes", is_equal_approx(float(bb["att_c"][1]), 12.0),
		str(bb["att_c"][1]))
	_check("B : sur des jauges entamées", entamees_b > 400, str(entamees_b))
	_check("B : et le plein à la fin, des deux côtés",
		float(bb["h"][-1]) < 0.0 and float(bb["c"][-1]) < 0.0)

	# ── La garde de manche : l'hôte ne recharge rien hors jeu, le client non plus ─
	cl.round_active = false
	cl.sandbox_mode = false
	cl._fusees_attente[0] = 5.0
	nm.current_mode = _mode("ONLINE_CLIENT")
	cl._accorder_fusees(5.0)
	var gele: float = cl._fusees_attente[0]
	cl.sandbox_mode = true
	cl._accorder_fusees(2.0)
	var decompte: float = cl._fusees_attente[0]
	nm.current_mode = mode_avant
	_check("hors manche et hors bac à sable, le client ne décompte rien",
		gele == 5.0, "%.2f" % gele)
	_check("témoin : en jeu, le même appel décompte", is_equal_approx(decompte, 3.0),
		"%.2f" % decompte)

	# ── La butée à zéro : le paquet du regain arrive APRÈS le décompte ─────────
	# La moitié « game_state » de « imminente jusqu'au paquet » (revue du lot C). Avec
	# de la gigue, le regain peut arriver un peu après que le décompte a touché zéro ;
	# une attente devenue négative, `fraction_de_retour` la rendrait en ABSENCE, et la
	# jauge s'effacerait avant que « FUSÉES n » ait bougé. La file de `_derouler` a une
	# latence FIXE : le paquet y écrase toute valeur négative avant qu'on la lise, et
	# ce cas n'y est jamais exercé. D'où ce contrôle direct : le client passe zéro,
	# puis attend encore le paquet.
	cl.sandbox_mode = true
	cl._fusees_attente[0] = 0.03
	nm.current_mode = _mode("ONLINE_CLIENT")
	cl._accorder_fusees(0.05)
	var butee: float = cl.attente_fusee(0)
	cl._accorder_fusees(0.5)
	var butee_2: float = cl.attente_fusee(0)
	nm.current_mode = mode_avant
	_check("le décompte du client s'arrête à zéro, et y reste tant que le paquet tarde",
		butee == 0.0 and butee_2 == 0.0, "%.3f puis %.3f" % [butee, butee_2])
	_check("et sa jauge reste PLEINE — imminente —, pas effacée",
		gs.ui.fraction_de_retour(butee_2, periode) == 1.0,
		str(gs.ui.fraction_de_retour(butee_2, periode)))

	# ── Témoin : le Spectre, rien ne revient ─────────────────────────────────
	gs.p1.equip_weapon(gs.weapon_for_index(_index_de(gs, "spectre")))
	gs._accorder_fusees(0.0)
	cl.rpc_stock_fusees(0, int(gs._fusees_restantes[0]), float(gs._fusees_attente[0]))
	_maj_hud(gs)
	nm.current_mode = _mode("ONLINE_CLIENT")
	var a_sp: float = cl.attente_fusee(0)
	nm.current_mode = mode_avant
	_check("témoin : le Spectre — ni jauge chez l'hôte, ni attente chez le client",
		gs.ui.p1_reserves["panel_fusees"].fraction < 0.0 and a_sp < 0.0,
		"%.3f / %.3f" % [gs.ui.p1_reserves["panel_fusees"].fraction, a_sp])

	cl.free()
	_vider(gs)
	gs.sandbox_mode = false
	gs.training_mode = false


## Déroule `pas` (secondes par pas) chez l'hôte `gs` et chez le client `cl`, avec un
## demi-RTT de `m` pas. `lancers` : pas → nombre de fusées que l'hôte lance à ce pas,
## par son vrai chemin (`spawn_fusee`). Rend, pas par pas, la jauge de l'hôte (lue sur
## sa cartouche), celle du client (la fonction même du HUD, sur son attente) et son
## attente ; et l'écart maximal entre le client au pas k et l'hôte au pas k − m.
func _derouler(gs: Node, cl: Node, periode: float, m: int, pas: Array,
		lancers: Dictionary) -> Dictionary:
	var nm := _nm()
	var mode_avant = nm.current_mode
	var client: int = _mode("ONLINE_CLIENT")
	# Le client part de ce que l'hôte a dit en dernier.
	var dernier := [int(gs._fusees_restantes[0]), float(gs._fusees_attente[0])]
	cl.rpc_stock_fusees(0, dernier[0], dernier[1])
	var file: Array = []   # [pas d'émission, stock, attente]
	var h: Array = []
	var c: Array = []
	var att_c: Array = []
	for k in pas.size():
		var dt: float = pas[k]
		# 1. L'hôte avance, puis fait ses gestes.
		gs._accorder_fusees(dt)
		for i in int(lancers.get(k, 0)):
			gs.spawn_fusee(gs.p1, POSEUR, 0.0)
		_maj_hud(gs)
		h.append(float(gs.ui.p1_reserves["panel_fusees"].fraction))
		# Ce qu'il a annoncé : `call_local` l'écrit aussi chez lui.
		var dit := [int(gs._fusees_restantes[0]), float(gs._fusees_attente[0])]
		if dit != dernier:
			file.append([k, dit[0], dit[1]])
			dernier = dit
		# 2. Le client décompte, PUIS applique ce qui est arrivé — dans l'autre ordre,
		# il retarderait d'un pas.
		nm.current_mode = client
		cl._accorder_fusees(dt)
		while not file.is_empty() and int(file[0][0]) + m <= k:
			var paquet: Array = file.pop_front()
			cl.rpc_stock_fusees(0, int(paquet[1]), float(paquet[2]))
		var att: float = cl.attente_fusee(0)
		nm.current_mode = mode_avant
		att_c.append(att)
		c.append(float(gs.ui.fraction_de_retour(att, periode)))
	var ecart := 0.0
	for k in range(m, pas.size()):
		ecart = maxf(ecart, absf(float(c[k]) - float(h[k - m])))
	return {"h": h, "c": c, "att_c": att_c, "ecart": ecart}


## Point 7 — la jauge de la recharge de pose, chez l'hôte et chez le client. Le client
## sait déjà tout : son minuteur démarre à la pose qu'il voit, RACCOURCI d'un
## aller-retour (`_do_spawn_gadget`) pour que sa prédiction de pose tienne. Sa jauge
## est donc en AVANCE d'au plus un RTT — l'inverse de la fusée, et voulu.
func _test_jauge_de_pose(gs: Node) -> void:
	print("\n[La jauge de la recharge de pose, chez l'hôte et chez le client]")
	var nm := _nm()
	var mode_avant = nm.current_mode
	var rtt_avant: float = nm.rtt_ms
	gs.round_active = false
	gs.sandbox_mode = true
	gs.training_mode = true
	_vider(gs)
	gs._gadget_attente.fill(0.0)
	gs.p1.equip_weapon(gs.weapon_for_index(_index_de(gs, "spectre")))
	var pos := POSEUR + Vector2(_GB.PORTEE_POSE, 0.0)
	gs._do_spawn_gadget(0, pos, 0.0, "voile", 960)
	_maj_hud(gs)
	var cart = gs.ui.p1_reserves["panel_gadget"]
	var f_h: float = cart.fraction
	var att_h: float = gs.attente_gadget(0)
	_vider(gs)
	gs._gadget_attente.fill(0.0)
	nm.rtt_ms = 100.0
	nm.current_mode = _mode("ONLINE_CLIENT")
	gs._do_spawn_gadget(0, pos, 0.0, "voile", 961)
	var att_c: float = gs.attente_gadget(0)
	nm.current_mode = mode_avant
	nm.rtt_ms = rtt_avant
	var f_c: float = gs.ui.fraction_de_retour(att_c, gs.PERIODE_RECHARGE_GADGET)
	_check("chez l'hôte, la jauge de pose part de zéro",
		is_zero_approx(f_h) and is_equal_approx(att_h, 60.0), "%.4f (%.2f s)" % [f_h, att_h])
	_check("chez le client, en avance d'au plus un aller-retour — jamais en retard",
		f_c - f_h >= 0.0 and f_c - f_h <= 0.1 / 60.0 + 1e-4,
		"%.5f contre %.5f (attente %.2f s)" % [f_c, f_h, att_c])
	gs._maj_reserves_gadgets(30.0)
	_maj_hud(gs)
	_check("à mi-recharge, la jauge est à moitié", absf(cart.fraction - 0.5) < 0.01,
		"%.4f" % cart.fraction)
	_check("et le titre garde la recharge", _titre_gadget(gs).begins_with("RECHARGE"),
		_titre_gadget(gs))
	gs._maj_reserves_gadgets(31.0)
	_maj_hud(gs)
	_check("revenu, plus rien ne bouge : la jauge disparaît", cart.fraction < 0.0,
		"%.4f" % cart.fraction)
	_vider(gs)
	gs._gadget_attente.fill(0.0)
	gs.sandbox_mode = false
	gs.training_mode = false


## Point 7 — le départ de manche remet l'attente des fusées à « rien ne revient »
## (revue du lot C). Sans la remise à -1 de `_do_start_round`, un client qui a lancé
## peu avant la fin d'une manche garde son attente — figée hors manche par la garde —,
## la décompte à zéro dans la suivante et affiche une jauge PLEINE sous une réserve
## pleine jusqu'à son premier lancer : l'hôte, réserve pleine et profil inchangé,
## n'annonce rien qui la corrige. Par le VRAI départ de manche de la scène, celui que
## `rpc_start_round` appelle chez le client. ⚠️ **En DERNIER dans `_run`** : il pose
## l'arène, les armes et le décompte, qu'aucun contrôle ne doit hériter.
func _test_attente_au_depart_de_manche(gs: Node) -> void:
	print("\n[Le départ de manche : réserve pleine, plus aucune attente]")
	var nm := _nm()
	var mode_avant = nm.current_mode
	var client: int = _mode("ONLINE_CLIENT")
	var allumeur := _index_de(gs, "allumeur")
	gs._fusees_attente[0] = 5.0
	gs._fusees_attente[1] = 5.0
	nm.current_mode = client
	var avant_depart: float = gs.attente_fusee(0)
	nm.current_mode = mode_avant
	gs._do_start_round(allumeur, allumeur)
	var apres: Array = [float(gs._fusees_attente[0]), float(gs._fusees_attente[1])]
	nm.current_mode = client
	var apres_client: float = gs.attente_fusee(0)
	nm.current_mode = mode_avant
	# Rien de ce que pose le départ ne doit courir pendant la sortie de la suite.
	gs.round_active = false
	gs.countdown_left = 0.0
	_check("témoin : avant le départ, le client lit l'attente héritée de la manche",
		is_equal_approx(avant_depart, 5.0), "%.2f" % avant_depart)
	_check("au départ de manche, l'attente repart à « rien ne revient », pour les deux",
		apres == [-1.0, -1.0], str(apres))
	_check("et le client n'affiche aucune jauge sous sa réserve pleine",
		apres_client < 0.0 and gs.ui.fraction_de_retour(apres_client, 12.0) < 0.0,
		"%.2f" % apres_client)
