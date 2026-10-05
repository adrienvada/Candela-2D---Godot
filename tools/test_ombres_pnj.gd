## OMBRES, OM4b — des règles d'ombre pour N corps (chantier OMBRES, 2026-10-05), sur les objets vivants d'une vraie salle :
##   • **Q86, une couche par PNJ** (décision d'Adrien, 2026-10-05) : tous les PNJ avaient `player_id` 1, donc une étoile sur la
##     couche 8, et leurs lumières (torche, halo, flash de bouche) ne lisaient que la couche 4, celle de J1 : la torche d'un PNJ
##     TRAVERSAIT les autres PNJ, quand celle de J1 les ombrait tous (O6). Chaque PNJ porte désormais, en plus de la 8, une couche
##     à lui (`CanauxLumiere.couche_ombre_pnj`, 512 et au-delà, par sa place de réserve), et ses lumières lisent celles des autres,
##     jamais la sienne. Son leurre porte la même. Rien ne change pour J1 et J2.
##   • **Q87, les lumières posées** (décision d'Adrien, 2026-10-05, duel compris) : la fusée, la mine et la nappe de braises
##     n'avaient que les murs dans leur masque d'ombre (`1`, plus les murs bas au sol) ; or ce masque filtre aussi les RÉCEPTEURS,
##     et aucun corps ne recevait donc leur ombre — posées derrière un mur, elles éclairaient un corps de l'autre côté. Le masque des
##     lumières neutres (`CanauxLumiere.masque_ombre_neutre_pour_les_corps`), celui du plafonnier.
## Les contrôles appliquent la règle du moteur — un occulteur ombre une lumière si son masque croise le masque d'ombre de la
## lumière, et un récepteur ne reçoit l'ombre que si SON masque le croise aussi — sur les masques réellement posés. Ce que ces
## règles changent à l'image se voit au banc des ombres (`tools/planche_ombres.gd`, famille `om4b`), sous Xvfb.
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_ombres_pnj.gd
extends SceneTree

const Format := preload("res://aventure_format.gd")
const Progression := preload("res://aventure_progression.gd")

const ESSAI := "res://tools/aventure_essai"
const SOLO_DE_LA_SUITE := "user://test_ombres_pnj_solo.cfg"
const PH_JEU := 1

var _failures := 0
var _verifications := 0
var main: Node = null
var prog: AventureProgression = null
var chapitre: Dictionary = {}
var brut: Dictionary = {}


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
	print("=== OMBRES, OM4b : UNE COUCHE PAR PNJ, ET DES LUMIÈRES POSÉES QUE LES MURS COUPENT POUR LES CORPS ===")
	await process_frame
	_les_couches_pures()
	var fichier := ProjectSettings.globalize_path(SOLO_DE_LA_SUITE)
	if FileAccess.file_exists(SOLO_DE_LA_SUITE):
		DirAccess.remove_absolute(fichier)
	root.get_node("GameSettings").mode_iso = false
	Format.racine = ESSAI
	Format.niveaux_attendus = 0
	Format.oublier_le_cache()
	chapitre = Format.charger_chapitre(ESSAI.path_join("chapitre_00"), 0)
	brut = Format.lire_chapitre(ESSAI.path_join("chapitre_00"))
	_check("(le chapitre d'essai se charge)", not chapitre.is_empty() and not brut.is_empty())
	if chapitre.is_empty() or brut.is_empty():
		_sortir()
		return
	prog = Progression.new(SOLO_DE_LA_SUITE)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	main.ui.aventure_progression = prog
	main.archiver_les_matchs = false
	await _les_couches_des_pnj()
	await _les_lumieres_posees()
	_sortir()


# ---------------------------------------------------------------------------
# Q86 — UNE COUCHE PAR PNJ
# ---------------------------------------------------------------------------

func _les_couches_pures() -> void:
	print("\n--- Q86 : les couches propres aux PNJ, onze bits libres au-dessus de 256 ---")
	_check("J1 et J2 n'en ont pas (places 0 et 1)", CanauxLumiere.couche_ombre_pnj(0) == 0 and CanauxLumiere.couche_ombre_pnj(1) == 0
		and CanauxLumiere.couche_ombre_pnj(-1) == 0)
	var vues := {}
	var libres := true
	for slot in range(2, 13):
		var c := CanauxLumiere.couche_ombre_pnj(slot)
		vues[c] = true
		libres = libres and c >= 512 and c < (1 << 20) and (c & 511) == 0 and (c & (c - 1)) == 0
	_check("les places 2 à 12 ont onze couches distinctes, chacune un seul bit, toutes au-dessus des couches du jeu (1 à 256)",
		vues.size() == 11 and libres)
	_check("au-delà de onze PNJ, la place reprend au premier bit (deux PNJ partagent alors une couche, l'état d'avant)",
		CanauxLumiere.couche_ombre_pnj(13) == CanauxLumiere.couche_ombre_pnj(2))
	var tous := 0
	for c in vues:
		tous |= int(c)
	_check("`masque_des_pnj` les réunit, et rien d'autre", CanauxLumiere.masque_des_pnj() == tous)


func _les_couches_des_pnj() -> void:
	print("\n--- Q86 : dans une vraie salle, trois PNJ, chacun SA couche ; leurs lumières lisent celles des autres ---")
	var c := _chapitre_de([
		{"case": [4, 4], "orientation": 0, "profil": "immobile_sourd_aveugle", "classe": "fusil"},
		{"case": [4, 8], "orientation": 0, "profil": "immobile_sourd_aveugle", "classe": "pistolet"},
		{"case": [4, 12], "orientation": 0, "profil": "immobile_sourd_aveugle", "classe": "spectre"},
	])
	var partie: Node = await _demarrer(c)
	var pnj: Array = partie.pnj
	_check("(trois PNJ dans la salle)", pnj.size() == 3)
	if pnj.size() != 3:
		await _quitter()
		return
	var couches := {}
	var etoiles_justes := true
	for p in pnj:
		var occ: LightOccluder2D = p.etoile()
		var propre: int = p.couche_ombre_pnj()
		couches[propre] = true
		etoiles_justes = etoiles_justes and propre >= 512 and occ != null and occ.occluder_light_mask == (8 | propre)
	_check("chaque PNJ a sa couche, distincte des autres, et son étoile la porte avec la 8", etoiles_justes and couches.size() == 3)
	var lumieres_justes := true
	var detail := ""
	for a in pnj:
		var propre_a: int = a.couche_ombre_pnj()
		for nom in ["flashlight", "ambient_light", "muzzle_flash"]:
			var l: Light2D = a.get(nom)
			var m := l.shadow_item_cull_mask
			var juste := (m & propre_a) == 0 and (m & 1) != 0
			for b in pnj:
				if b != a:
					juste = juste and (m & int(b.couche_ombre_pnj())) != 0
			if not juste:
				lumieres_justes = false
				detail += "%s.%s=%d " % [a.name, nom, m]
	_check("la torche, le halo et le flash de chaque PNJ lisent les couches des deux autres, jamais la sienne", lumieres_justes, detail)
	# La règle du moteur, sur les masques posés : l'étoile de B ombre la torche de A ; la sienne, non.
	var a0: Node = pnj[0]
	var b0: Node = pnj[1]
	var torche_a: int = (a0.get("flashlight") as Light2D).shadow_item_cull_mask
	_check("l'étoile d'un PNJ ombre la torche d'un autre PNJ (O6 : elle la laissait passer)",
		((b0.etoile() as LightOccluder2D).occluder_light_mask & torche_a) != 0)
	_check("… et pas la torche de son propre corps", ((a0.etoile() as LightOccluder2D).occluder_light_mask & torche_a) == 0)
	var j1_torche: int = (main.p1.get("flashlight") as Light2D).shadow_item_cull_mask
	_check("rien ne change pour J1 : sa torche lit la 8, que toute étoile de PNJ porte, et aucune couche de PNJ",
		(j1_torche & 8) != 0 and (j1_torche & CanauxLumiere.masque_des_pnj()) == 0 and int(main.p1.couche_ombre_pnj()) == 0)
	# La posture ne touche que le bit des murs bas.
	a0.poser_posture(true)
	var accroupi := (a0.get("flashlight") as Light2D).shadow_item_cull_mask
	a0.poser_posture(false)
	var debout := (a0.get("flashlight") as Light2D).shadow_item_cull_mask
	_check("accroupi, la torche d'un PNJ gagne le bit des murs bas et garde les couches des autres PNJ",
		(accroupi & CanauxLumiere.COUCHE_OMBRE_MUR_BAS) != 0 and (accroupi & CanauxLumiere.masque_des_pnj()) == (debout & CanauxLumiere.masque_des_pnj())
		and (debout & CanauxLumiere.COUCHE_OMBRE_MUR_BAS) == 0)
	# Un changement de classe refait l'étoile : elle garde la couche du PNJ.
	a0.equip_weapon(main.weapon_for_index(_index_de("pompe")))
	_check("un changement de classe refait l'étoile, qui garde la couche du PNJ",
		(a0.etoile() as LightOccluder2D).occluder_light_mask == (8 | int(a0.couche_ombre_pnj())))
	a0.equip_weapon(main.weapon_for_index(_index_de("fusil")))
	# Le leurre d'un PNJ porte la couche de son poseur : la torche d'un autre PNJ s'y arrête comme sur lui.
	var slot_a: int = a0.slot_de_reserve()
	main._gadgets_poses_par[slot_a] = 0
	main._gadget_attente[slot_a] = 0.0
	main.spawn_gadget(a0, a0.global_position + Vector2(40.0, 0.0), 0.0)
	await _images(2)
	var leurre: Node = null
	for g in main.bullet_container.get_children():
		if _est_de(g, "res://gadget_leurre.gd") and int(g.get("slot_reserve")) == slot_a:
			leurre = g
	_check("(le PNJ Illusionniste pose son leurre)", leurre != null)
	if leurre != null:
		var occ_l: LightOccluder2D = leurre.etoile()
		var torche_b: int = (b0.get("flashlight") as Light2D).shadow_item_cull_mask
		_check("son leurre porte la couche du poseur, avec la 8", occ_l.occluder_light_mask == (8 | int(a0.couche_ombre_pnj())))
		_check("… et la torche d'un autre PNJ s'y arrête, comme sur le poseur — le leurre ne se trahit pas",
			(occ_l.occluder_light_mask & torche_b) != 0)
		_check("… mais pas celle de son poseur", (occ_l.occluder_light_mask & torche_a) == 0)
		leurre.queue_free()
	await _quitter()
	_check("la salle quittée, J2 revient sans couche de PNJ", int(main.p2.couche_ombre_pnj()) == 0)


# ---------------------------------------------------------------------------
# Q87 — LES LUMIÈRES POSÉES
# ---------------------------------------------------------------------------

func _les_lumieres_posees() -> void:
	print("\n--- Q87 : la fusée, la mine et la nappe de braises — les murs les coupent pour les corps aussi ---")
	var neutre := CanauxLumiere.masque_ombre_neutre_pour_les_corps()
	# Chargés à l'exécution : nommer `Fusee` dans une suite `--script` la ferait compiler avant les autoloads qu'elle nomme (piège
	# consigné) — et la classe resterait cassée pour toute la suite, partie comprise.
	var F := load("res://fusee.gd") as GDScript
	_check("la fusée, en vol : le masque neutre, sans le bit des murs bas", int(F.masque_ombre(false)) == neutre)
	_check("la fusée, posée : le masque neutre et les murs bas", int(F.masque_ombre(true)) == (neutre | CanauxLumiere.COUCHE_OMBRE_MUR_BAS))
	# Les vraies lumières, dans une vraie manche : une mine allumée, une nappe de braises.
	main.ui._intended_mode = _mode_local()
	main._on_replay_requested()
	await _images(10)
	var mine: Node2D = (load("res://gadget_mine.gd") as GDScript).new()
	mine.poseur_id = 0
	mine.global_position = Vector2(400.0, 400.0)
	main.bullet_container.add_child(mine)
	mine.allumer()
	var braises: Node2D = (load("res://gadget_braises.gd") as GDScript).new()
	braises.poseur_id = 0
	braises.global_position = Vector2(500.0, 400.0)
	main.bullet_container.add_child(braises)
	await _images(2)
	var lumieres := {"la mine": mine.get("_lumiere"), "la nappe de braises": braises.get("_lumiere")}
	for nom in lumieres:
		var l := lumieres[nom] as Light2D
		_check("%s (allumée) : le masque neutre, et les murs bas au sol" % nom, l != null
			and l.shadow_item_cull_mask == (neutre | CanauxLumiere.COUCHE_OMBRE_MUR_BAS), str(l.shadow_item_cull_mask if l != null else -1))
	# La règle du moteur : chaque famille de récepteur — le sprite adverse, le capteur croisé, le capteur de soi de J1 et de J2 —
	# reçoit l'ombre des murs de ces trois lumières ; aucune couche de corps n'y entre (un corps ne fait pas d'ombre sous elles).
	var recepteurs := {"le sprite adverse": CanauxLumiere.ENNEMI, "le capteur croisé de J1": CanauxLumiere.masque_vue_adverse(0),
		"le capteur croisé de J2": CanauxLumiere.masque_vue_adverse(1), "le capteur de soi de J1": CanauxLumiere.masque_de_soi(0),
		"le capteur de soi de J2": CanauxLumiere.masque_de_soi(1)}
	var masques := {"la fusée posée": int(F.masque_ombre(true)), "la fusée en vol": int(F.masque_ombre(false))}
	for nom in lumieres:
		if lumieres[nom] != null:
			masques[nom] = (lumieres[nom] as Light2D).shadow_item_cull_mask
	var corps := CanauxLumiere.couche_ombre_corps(0) | CanauxLumiere.couche_ombre_corps(1) | CanauxLumiere.couche_ombre_torse(0) \
		| CanauxLumiere.couche_ombre_torse(1) | CanauxLumiere.masque_des_pnj()
	var tout_recoit := true
	var aucun_corps := true
	var detail := ""
	for nm in masques:
		var m: int = masques[nm]
		aucun_corps = aucun_corps and (m & corps) == 0 and (m & MapGeometry.WALL_LAYER) != 0
		for nr in recepteurs:
			if (m & int(recepteurs[nr])) == 0:
				tout_recoit = false
				detail += "%s ne reçoit pas l'ombre de %s ; " % [nr, nm]
	_check("chaque récepteur — sprite adverse, capteurs croisés, capteurs de soi — reçoit l'ombre des murs de ces lumières (avant : aucun)",
		tout_recoit, detail)
	_check("… les murs y sont, et aucune couche de corps : un corps ne fait toujours pas d'ombre sous elles", aucun_corps)
	mine.queue_free()
	braises.queue_free()


# ---------------------------------------------------------------------------
# OUTILS
# ---------------------------------------------------------------------------

func _chapitre_de(pnj: Array) -> Dictionary:
	var niveau: Dictionary = (brut["niveaux"][0] as Dictionary).duplicate(true)
	niveau["pnj"] = pnj
	niveau["boss"] = false
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
	var fin := 300
	while partie.phase != PH_JEU and fin > 0:
		await process_frame
		fin -= 1
	return partie


func _quitter() -> void:
	main._on_main_menu_requested()
	await _images(3)


func _est_de(n: Object, chemin: String) -> bool:
	return n != null and n.get_script() != null and (n.get_script() as Script).resource_path == chemin


func _index_de(slug: String) -> int:
	for k in 10:
		var w = main.weapon_for_index(k)
		if w != null and w.has_method("slug") and String(w.slug()) == slug:
			return k
	return 0


func _images(n: int) -> void:
	for i in n:
		await process_frame


## `NetworkManager.GameMode.LOCAL_SPLITSCREEN`, lu par l'arbre : nommer l'autoload dans une suite `--script` la ferait compiler
## avant qu'il existe (piège consigné).
func _mode_local() -> int:
	var reseau := root.get_node("NetworkManager")
	return int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
