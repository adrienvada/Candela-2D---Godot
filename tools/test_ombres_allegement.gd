## OMBRES, OM6 — l'allègement : trois gestes, chacun mesuré au banc de cadence du solo (`tools/bench_framerate.gd --solo=…`).
##
##   • **l'ombre d'un halo sans récepteur** (`CanauxLumiere.halo_a_un_recepteur`, `GameState._accorder_les_ombres_des_halos`) : un
##     halo n'éclaire que le canal de la vue de son porteur ; cette vue absente de l'écran, son ombre se calculait pour rien. La règle
##     pure ; puis, dans une vraie salle d'aventure en iso, le halo de J1 garde son ombre, ceux de J2 (caché) et des PNJ la perdent —
##     **`enabled` intact**, que lit le modèle de vue des bots —, et la règle se repose quand les vues changent et quand les figurants
##     changent ;
##   • **le capteur d'un corps qu'on ne montre pas** (`Presentation3D._corps_montre`) : celui de J2, caché en solo, ne rend plus ;
##     J2 montré — ou son fantôme, pendant la killcam —, il rend dès l'image suivante ;
##   • **la lumière de coup, partie à 1 % de son énergie** (`Player.FIN_LUMIERE_DE_COUP`) : là à 0,5 s, partie à 0,7 s — et son ombre
##     tenue jusqu'au bout (aucune image où elle passerait les murs).
##
## Lancer : godot --headless --path . --fixed-fps 60 --script res://tools/test_ombres_allegement.gd
extends SceneTree

const Format := preload("res://aventure_format.gd")
const Progression := preload("res://aventure_progression.gd")

const ESSAI := "res://tools/aventure_essai"
const SOLO_DE_LA_SUITE := "user://test_ombres_allegement_solo.cfg"
const PH_JEU := 1

var _failures := 0
var _verifications := 0
var main: Node = null


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
	print("=== OMBRES, OM6 : L'ALLÈGEMENT ===")
	await process_frame
	_la_regle_pure()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _images(3)
	await _dans_une_salle()
	_sortir()


# ---------------------------------------------------------------------------
# LA RÈGLE PURE
# ---------------------------------------------------------------------------

func _la_regle_pure() -> void:
	print("\n--- La règle : un halo n'a de récepteur que dans la vue de son porteur ---")
	var canaux := load("res://canaux_lumiere.gd") as GDScript
	_check("J1 seul à l'écran : le halo de J1 a un récepteur", bool(canaux.call("halo_a_un_recepteur", 0, [0])))
	_check("J1 seul à l'écran : le halo de J2 — et des PNJ, qui portent l'identité de J2 — n'en a aucun",
		not bool(canaux.call("halo_a_un_recepteur", 1, [0])))
	_check("J2 seul à l'écran (le client en ligne) : le halo de J1 n'en a aucun", not bool(canaux.call("halo_a_un_recepteur", 0, [1])))
	_check("l'écran scindé : les deux en ont un", bool(canaux.call("halo_a_un_recepteur", 0, [0, 1]))
		and bool(canaux.call("halo_a_un_recepteur", 1, [0, 1])))
	_check("aucune vue : aucun", not bool(canaux.call("halo_a_un_recepteur", 0, [])))


# ---------------------------------------------------------------------------
# DANS UNE VRAIE SALLE, EN ISO
# ---------------------------------------------------------------------------

func _dans_une_salle() -> void:
	print("\n--- Dans une vraie salle d'aventure, en vue iso : trois PNJ ---")
	var fichier := ProjectSettings.globalize_path(SOLO_DE_LA_SUITE)
	if FileAccess.file_exists(SOLO_DE_LA_SUITE):
		DirAccess.remove_absolute(fichier)
	root.get_node("GameSettings").mode_iso = true
	Format.racine = ESSAI
	Format.niveaux_attendus = 0
	Format.oublier_le_cache()
	var chapitre := Format.charger_chapitre(ESSAI.path_join("chapitre_00"), 0)
	var brut := Format.lire_chapitre(ESSAI.path_join("chapitre_00"))
	if chapitre.is_empty() or brut.is_empty():
		_check("(le chapitre d'essai se charge)", false)
		return
	var niveau: Dictionary = (brut["niveaux"][0] as Dictionary).duplicate(true)
	niveau["pnj"] = [{"case": [8, 5], "orientation": 0, "profil": "immobile_sourd_aveugle", "classe": "fusil"},
		{"case": [8, 8], "orientation": 0, "profil": "immobile_sourd_aveugle", "classe": "pompe"},
		{"case": [8, 11], "orientation": 0, "profil": "immobile_sourd_aveugle", "classe": "spectre"}]
	niveau["boss"] = false
	var c := chapitre.duplicate(true)
	c["niveaux"] = [Format.preparer_niveau(niveau)]
	c["niveaux"][0]["fichier"] = "fabrique.json"
	main.ui.aventure_progression = Progression.new(SOLO_DE_LA_SUITE)
	main.archiver_les_matchs = false
	main.graine_du_bot = 4242
	main.demarrer_l_aventure(c, 0, "pistolet", main.ui.aventure_progression)
	await _images(3)
	var partie: Node = main.aventure
	var fin := 300
	while partie != null and partie.phase != PH_JEU and fin > 0:
		await process_frame
		fin -= 1
	await _images(3)
	var pres: Node = (load("res://presentation_3d.gd") as GDScript).call("instance")
	_check("(la vue iso est montée, trois PNJ dans la salle)", pres != null and partie != null and (partie.pnj as Array).size() == 3)
	if pres == null or partie == null or (partie.pnj as Array).size() != 3:
		return
	_les_halos(partie)
	await _les_capteurs(pres)
	await _la_lumiere_de_coup()
	main._on_main_menu_requested()
	await _images(3)
	root.get_node("GameSettings").mode_iso = false


func _les_halos(partie: Node) -> void:
	print("\n--- L'ombre des halos ---")
	var p1: Node = main.p1
	var p2: Node = main.p2
	_check("le solo ne montre que la vue de J1 (%s)" % str(main._vues_montrees), main._vues_montrees == [0])
	_check("le halo de J1 garde son ombre", (p1.ambient_light as Light2D).shadow_enabled)
	_check("le halo de J2, caché, n'a plus d'ombre", not (p2.ambient_light as Light2D).shadow_enabled)
	var sans_ombre := true
	var allumes := true
	for pnj: Node in partie.pnj:
		sans_ombre = sans_ombre and not (pnj.ambient_light as Light2D).shadow_enabled
		allumes = allumes and (pnj.ambient_light as Light2D).enabled
	_check("les halos des trois PNJ n'ont plus d'ombre", sans_ombre)
	_check("… et restent ALLUMÉS (`enabled`, que lit le modèle de vue des bots)", allumes)
	# Les figurants changent : la règle se repose (le setter de `GameState.figurants`).
	(partie.pnj[0].ambient_light as Light2D).shadow_enabled = true
	main.figurants = main.figurants
	_check("des figurants reposés reprennent la règle", not (partie.pnj[0].ambient_light as Light2D).shadow_enabled)
	# Les vues changent : la vue de J2 montrée, les halos de J2 et des PNJ retrouvent leur ombre ; cachée, ils la reperdent.
	var conteneur := main.vp2.get_parent() as Control
	conteneur.visible = true
	main._accorder_rendu_aux_vues()
	var rendus := (p2.ambient_light as Light2D).shadow_enabled and (partie.pnj[1].ambient_light as Light2D).shadow_enabled
	conteneur.visible = false
	main._accorder_rendu_aux_vues()
	_check("la vue de J2 montrée, les halos de J2 et des PNJ retrouvent leur ombre ; cachée, ils la reperdent",
		rendus and not (p2.ambient_light as Light2D).shadow_enabled and not (partie.pnj[1].ambient_light as Light2D).shadow_enabled
		and main._vues_montrees == [0])


func _les_capteurs(pres: Node) -> void:
	print("\n--- Le capteur d'un corps qu'on ne montre pas ---")
	var capteurs: Array = pres.call("capteurs")
	var id := 0
	var c_j1: SubViewport = (capteurs[id] as Array)[0]
	var c_j2: SubViewport = (capteurs[id] as Array)[1]
	_check("(les capteurs de J1 et J2 existent dans la vue de J1)", c_j1 != null and c_j2 != null)
	if c_j1 == null or c_j2 == null:
		return
	await _images(2)
	_check("le capteur de J1 rend à chaque image", c_j1.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	_check("celui de J2, caché, ne rend plus", c_j2.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"mode %d" % c_j2.render_target_update_mode)
	var p2: Node2D = main.p2
	var visible_avant := p2.visible
	p2.visible = true
	await _images(2)
	var rend := c_j2.render_target_update_mode == SubViewport.UPDATE_ALWAYS
	p2.visible = visible_avant
	await _images(2)
	_check("J2 montré, son capteur rend ; caché de nouveau, il s'arrête",
		rend and c_j2.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	# La killcam : J2 caché, son FANTÔME montré (`GameState.ghost_p2`, que le rejeu montre à sa place) — le corps est montré, et
	# c'est par ce capteur que la vue l'éclaire.
	var fantome: Node2D = main.ghost_p2
	_check("(le fantôme de J2 existe)", fantome != null)
	if fantome != null:
		fantome.global_position = p2.global_position
		fantome.show()
		await _images(2)
		var rend_fantome := c_j2.render_target_update_mode == SubViewport.UPDATE_ALWAYS
		fantome.hide()
		await _images(2)
		_check("pendant la killcam, le FANTÔME de J2 montré, son capteur rend ; le fantôme caché, il s'arrête",
			rend_fantome and c_j2.render_target_update_mode == SubViewport.UPDATE_DISABLED)


func _la_lumiere_de_coup() -> void:
	print("\n--- La lumière de coup, partie à 1 % de son énergie ---")
	var p1: Node = main.p1
	var fin: float = float((p1.get_script() as GDScript).get_script_constant_map().get("FIN_LUMIERE_DE_COUP", -1.0))
	_check("l'instant de départ est entre 0,5 et 0,7 s (%.2f s) : 3 à 0,4 %% de l'énergie de départ" % fin, fin >= 0.5 and fin <= 0.7)
	var avant := _lumieres_de_coup(p1)
	p1.hp = 1000.0
	var cause: int = int((load("res://gadget_base.gd") as GDScript).get_script_constant_map().get("DEGATS_BALLE", 0))
	p1.rpc_update_hp(990.0, 1, cause)
	var nees := _lumieres_de_coup(p1)
	_check("un coup reçu allume une lumière de coup", nees.size() == avant.size() + 1)
	if nees.size() != avant.size() + 1:
		return
	var lumiere: PointLight2D = null
	for l in nees:
		if not avant.has(l):
			lumiere = l
	var ombre_tenue := true
	for i in 30:
		await process_frame
		ombre_tenue = ombre_tenue and is_instance_valid(lumiere) and lumiere.shadow_enabled
	_check("à 0,5 s elle est encore là, son ombre tenue à chaque image", is_instance_valid(lumiere) and ombre_tenue)
	for i in 12:
		await process_frame
	_check("à 0,7 s elle est partie (elle durait une seconde)", not is_instance_valid(lumiere))


## Les lumières de coup d'un corps : les `PointLight2D` qu'il porte, de la couleur du sang.
func _lumieres_de_coup(corps: Node) -> Array:
	var charte := load("res://charte.gd") as GDScript
	var carmin: Color = charte.get_script_constant_map().get("CARMIN", Color.RED)
	var sortie: Array = []
	for n in corps.get_children():
		if n is PointLight2D and (n as PointLight2D).color == carmin and not (n as Node).is_queued_for_deletion():
			sortie.append(n)
	return sortie


func _images(n: int) -> void:
	for i in n:
		await process_frame


func _sortir() -> void:
	if _failures == 0:
		print("\n✓ Tous les tests passent (%d vérifications)" % _verifications)
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	quit(1 if _failures > 0 else 0)
