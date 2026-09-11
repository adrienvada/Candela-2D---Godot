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
##   • les IMAGES des gadgets, et le pied de la torche qui ne balaie pas (26).
##
## ⚠️ **Fichier séparé de `test_classes.gd`, et ce n'est pas un rangement.** Une
## autre session réécrit la partie interface de celui-là le même jour. Deux diffs
## dans un même fichier se percutent à la fusion ; deux fichiers, jamais.
##
## Lancer : godot --headless --path . --script res://tools/test_tir_et_reserves.gd

const _IP = preload("res://input_provider.gd")
const _GG = preload("res://gadget_gresillement.gd")
const _GV = preload("res://gadget_voile.gd")
const _GTF = preload("res://gadget_torche_fantome.gd")
const _MG = preload("res://map_geometry.gd")

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
	await _test_voile_bloquant(gs)
	_test_sprites_des_gadgets(gs)
	await _test_diffus_intouchables(gs)
	await _test_suie_masque(gs)
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
	# Le compte à rebours sur l'icône (Adrien, 2026-09-11) : batterie pleine,
	# quatorze secondes avant que la zone ne lâche.
	var dec: Label = gs.ui.p1_reserves["gadget_decompte"]
	_check("l'icône compte les secondes de batterie : 14 à la pose",
		dec.visible and dec.text == "14", "%s « %s »" % [dec.visible, dec.text])
	var ico: TextureRect = gs.ui.p1_reserves["gadget_icone"]
	_check("et l'icône porte l'image du gadget", ico.texture != null)
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
