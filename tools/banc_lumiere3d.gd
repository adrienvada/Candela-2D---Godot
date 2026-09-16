## Banc de la lumière 3D bridée — FENÊTRÉ (chantier ISO12, lot 0).
##
## Brief `briefs/iso12_lumiere3d.md` de la session cloud « Fable 5.1 - CLOUD ISO UNRAILED » (2026-09-15, 22:0x), plan-delta
## accepté à 22:15. Adrien, 22:0x : « Ok pour ISO12, enchaîne avec les lumières 3D. » **Aucun réglage n'est choisi ici** :
## le banc photographie et mesure chaque variante ; la session cloud tranche sur image et sur chiffres.
##
## ## La scène
## Carte d'essai des murs bas, puis Le Cloître (la mise en scène de `banc_claustro.gd`). J1 au pistolet, J2 au Braconnier
## (5°), torches tenues ; une fusée posée dans le cône de J1 (`forcer_age`) ; un flash de tir de J1 rejoué toutes les
## `PERIODE_FLASH_S` ; les corps voxel ; vue unique puis écran scindé. Fenêtre 2560×1440 au premier plan.
##
## ## Ce qui est relevé, une ligne `BANC_LUMIERE3D` par prise
## - **cadence** : `IMAGES_MESUREES` images après `IMAGES_DE_REPOS`, `ConditionsDeMatch.statistiques` (médiane, 1 % bas,
##   pire image), appels de dessin médians, lumières 3D allumées, plafond `max_lights_per_object` du projet ;
## - **image** : une capture pleine fenêtre par prise, et les positions à l'écran des ancres de la loupe (J1, J2, bord du
##   cône, pied du mur, fusée) pour les recadrages (`analyse_lumiere3d.py`) ;
## - **preuve** : sous huit visées et dans les deux vues, une prise normale et une prise `masque_preuve` (blanc là où
##   L2D > 0) ; l'analyse compte les pixels lumineux hors du masque — il en faut zéro ;
## - **silhouette de soi** : torches éteintes, flash coupé, fusée retirée, écran scindé — la silhouette de J1 doit se voir
##   dans sa vue et pas dans celle de J2.
##
## Lancer (vraie fenêtre, chien de garde à la main — pas de `timeout` sur ce Mac) :
##   godot --path . res://tools/banc_lumiere3d.tscn -- --captures <dossier absolu> [--rapide]
## `--rapide` : une carte, vue unique, ombres oui/non seulement (la vérification du montage).
## `--carte=<nom>` (murs_bas | cloitre), `--vue=<vue>` (unique | scinde) : n'en prendre qu'une ; `--preuve-seule` : ni
## variantes, seulement la preuve et la silhouette de soi — pour rejouer ce qu'un banc a laissé invalide.
## `--energies torche:30,fusee:50,…` : les constantes d'énergie par type de source (`lumieres_iso.gd`), pour la calibration —
## les mêmes pour les deux joueurs et les deux vues ; un type absent garde sa valeur. Elle porte aussi les deux gains du lot
## 0 ter : `corps_propre` (la lumière d'un corps par sa propre lampe, en émission) et `pied_lampe` (le pied de la lampe au sol).
## `--brides-seules` : les quatre brides sous la preuve et la preuve d'intensité, rien d'autre. `--cadrages-seuls` : les
## cadrages de l'adversaire dans le cône. `--echelle=2.5` : l'échelle de la bride identité (L2D × échelle, plafonné à 1).
extends Node

const CARTES := [
	{"nom": "murs_bas", "chemin": "res://tools/cartes/murs_bas_essai.json"},
	{"nom": "cloitre", "chemin": "res://assets/maps/map_001_le_cloitre.json"},
]
const TAILLE := Vector2i(2560, 1440)
const IMAGES_DE_REPOS := 30
const IMAGES_MESUREES := 300
const PERIODE_FLASH_S := 0.5
const ATLAS := [1024, 2048, 4096]
const BRIDES := [Vector2(0.0, 0.05), Vector2(0.0, 0.2)]
const VISEES_PREUVE := 8
## ISO12, lot 0 ter — les brides à trancher. La bride ne doit pas seulement suivre le SUPPORT de la lumière 2D mais son
## GRADIENT : à (0 ; 0,05), tout souffle de 2D ouvrait la 3D en grand, et la 3D montrait plus que la 2D en intensité. La
## (0 ; 0,05) reste en tête de liste — c'est celle du lot 0 bis, la comparaison se fait contre elle.
const BRIDES_GRADIENT := [
	{"id": "005", "bride": Vector2(0.0, 0.05), "bride_mode": 0},
	{"id": "030", "bride": Vector2(0.0, 0.3), "bride_mode": 0},
	{"id": "060", "bride": Vector2(0.0, 0.6), "bride_mode": 0},
	{"id": "identite", "bride_mode": 1},
]
## Quatre visées sur les huit de la preuve : la comparaison des brides se joue sur les mêmes scènes, pas sur toutes.
const VISEES_BRIDES := [0, 2, 4, 6]
## ISO12, lot 0 ter — les cadrages qui justifient ISO12 : l'adversaire dans mon cône, et la fusée. `distance` en tuiles depuis
## J1, le long de sa visée ; `profil` tourne J2 d'un quart de tour.
const CADRAGES := [
	{"id": "j2_3tuiles_face", "distance": 3.0, "profil": false},
	{"id": "j2_3tuiles_profil", "distance": 3.0, "profil": true},
	{"id": "j2_6tuiles_face", "distance": 6.0, "profil": false},
	{"id": "corps_2tuiles_fusee", "distance": 3.0, "profil": false, "fusee_pres": true},
	{"id": "fusee_derriere_muret", "distance": 3.0, "profil": false, "fusee_muret": true},
]


class Pantin extends InputProvider:
	var visee := Vector2.UP
	var torche := true

	func get_movement_vector() -> Vector2:
		return Vector2.ZERO

	func get_aim_direction(_pos: Vector2) -> Vector2:
		return visee

	func is_shoot_pressed() -> bool:
		return false

	func is_flashlight_pressed() -> bool:
		return torche

	func is_flare_pressed() -> bool:
		return false

	func is_reload_pressed() -> bool:
		return false


var _main: Node
var _ui: Node
var _p: Presentation3D
var _dossier := ""
var _rapide := false
var _energies := {}
var _carte_seule := ""
var _vue_seule := ""
var _preuve_seule := false
var _pantins: Array = []
var _scene := {}
var _fusee: Node2D = null
var _flash_t := 0.0
var _flash_actif := true
var _contact_rayon := -1.0
## ISO12, lot 0 ter — l'échelle de la bride identité, et les deux passes qui peuvent être jouées seules.
var _echelle_identite := 1.0
var _brides_seules := false
var _cadrages_seuls := false
var _echecs := 0
var _prises := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--captures")
	if i < 0 or i + 1 >= args.size():
		printerr("✗ banc_lumiere3d : --captures <dossier absolu> est obligatoire")
		get_tree().quit(2)
		return
	var refus := RenduCommun.refus_headless()
	if refus != "":
		printerr("✗ banc_lumiere3d : ", refus)
		get_tree().quit(2)
		return
	_dossier = args[i + 1]
	_rapide = args.has("--rapide")
	_preuve_seule = args.has("--preuve-seule")
	_brides_seules = args.has("--brides-seules")
	_cadrages_seuls = args.has("--cadrages-seuls")
	for a in args:
		if a.begins_with("--carte="):
			_carte_seule = a.trim_prefix("--carte=")
		elif a.begins_with("--vue="):
			_vue_seule = a.trim_prefix("--vue=")
		elif a.begins_with("--echelle="):
			_echelle_identite = a.trim_prefix("--echelle=").to_float()
	var e := args.find("--energies")
	if e >= 0 and e + 1 < args.size():
		for paire in args[e + 1].split(","):
			var kv := paire.split(":")
			if kv.size() == 2 and kv[1].is_valid_float():
				_energies[kv[0].strip_edges()] = kv[1].to_float()
	DirAccess.make_dir_recursive_absolute(_dossier)
	GameSettings.pilotage_externe = true
	GameSettings.intro_vue = true
	GameSettings.mode_iso = true
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().size = TAILLE
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	AudioServer.set_bus_mute(0, true)

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node("UI")
	_main.archiver_les_matchs = false
	_ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active and _main.countdown_left <= 0.0, 20.0):
		_echouer("la manche n'a pas démarré")
		_finir()
		return
	for j in [_main.p1, _main.p2]:
		var pantin := Pantin.new()
		pantin.name = "PantinDuBancLumiere3D"
		_main._set_player_input_provider(j, pantin)
		_pantins.append(pantin)
	_main.p1.equip_weapon(_main.weapon_pistolet)
	_main.p2.equip_weapon(_main.weapon_arbalete)
	_ui.visible = false
	_p = Presentation3D.instance()
	if _p == null:
		_echouer("pas de Presentation3D")
		_finir()
		return
	print("=== Banc de la lumière 3D bridée (ISO12, lot 0) — plafond max_lights_per_object=%s, énergies %s ===" \
		% [str(ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object", "?")), JSON.stringify(_energies)])
	for carte in (CARTES.slice(0, 1) if _rapide else CARTES):
		if _carte_seule != "" and String(carte["nom"]) != _carte_seule:
			continue
		await _une_carte(carte)
	_finir()


func _process(delta: float) -> void:
	if _scene.is_empty() or not is_instance_valid(_main):
		return
	_tenir()
	_flash_t += delta
	if _flash_actif and _flash_t >= PERIODE_FLASH_S:
		_flash_t = 0.0
		if is_instance_valid(_main.p1):
			_main.p1.trigger_shoot_visuals()


func _une_carte(carte: Dictionary) -> void:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(String(carte["chemin"]))) != OK or not (json.data is Dictionary):
		_echouer("carte illisible : %s" % carte["chemin"])
		return
	var data: Dictionary = MapCodec.validate(json.data as Dictionary)["data"]
	MapData.current_map_data = data
	_main.rebuild_arena()
	await _images(8)
	_scene = _mise_en_scene(data)
	if _scene.is_empty():
		_echouer("%s : aucune mise en scène" % carte["nom"])
		return
	_poser_la_fusee()
	var nom := String(carte["nom"])
	var vues := ["unique"] if _rapide else ["unique", "scinde"]
	if _vue_seule != "":
		vues = [_vue_seule]
	if _preuve_seule or _brides_seules or _cadrages_seuls:
		vues = []
	for vue in vues:
		_poser_la_vue(vue == "scinde")
		# La référence : la vue iso d'ISO11, lumière 3D éteinte.
		await _prendre(nom, vue, {"lumiere": false})
		await _prendre(nom, vue, {"lumiere": true, "ombres": false})
		for atlas in ([2048] if _rapide else ATLAS):
			await _prendre(nom, vue, {"lumiere": true, "ombres": true, "atlas": atlas})
		if _rapide:
			continue
		for b in BRIDES:
			for pate in [0, 2, 1]:
				for contact in [true, false]:
					await _prendre(nom, vue, {"lumiere": true, "ombres": true, "atlas": 2048, "bride": b,
						"pate": pate, "contact": contact})
		# ISO12, lot 0 ter — les trois brides de gradient, colonnes neuves de la planche v26.
		for variante in BRIDES_GRADIENT:
			var v := {"lumiere": true, "ombres": true, "atlas": 2048}
			v.merge(variante, true)
			v.erase("id")
			await _prendre(nom, vue, v)
		# L'échelle des économies du brief, dans son ordre (session cloud, 22:48) : chacune chiffrée.
		await _prendre(nom, vue, {"lumiere": true, "ombres": true, "atlas": 1024, "omni": false})
		await _prendre(nom, vue, {"lumiere": true, "ombres": true, "atlas": 1024, "omni": false, "torches_seules": true})
		if vue == "scinde":
			await _prendre(nom, vue, {"lumiere": true, "ombres": true, "atlas": 2048, "vue_unique_seulement": true})
		await _prendre(nom, vue, {"lumiere": true, "ombres": true, "atlas": 2048, "retro": false})
	if _brides_seules:
		await _les_brides(nom)
	if _cadrages_seuls:
		await _les_cadrages(nom)
	if not _rapide and not _brides_seules and not _cadrages_seuls:
		await _les_brides(nom)
		await _les_cadrages(nom)
		await _la_preuve(nom)
		await _la_silhouette(nom)
	_retirer_la_fusee()
	_p.poser_lumiere_3d(false)


## Une variante : posée, reposée, mesurée, capturée.
func _prendre(carte: String, vue: String, v: Dictionary) -> void:
	_poser_la_variante(v)
	await _images(IMAGES_DE_REPOS)
	var durees := PackedFloat32Array()
	var appels: Array[int] = []
	# Le temps GPU de la fenêtre et des sous-vues iso, indépendant du cadencement de la fenêtre (voir l'en-tête du banc).
	var vues_mesurees: Array[RID] = [get_viewport().get_viewport_rid()]
	for sous_vue in _p.get("_vues3d"):
		vues_mesurees.append((sous_vue as SubViewport).get_viewport_rid())
	for rid in vues_mesurees:
		RenderingServer.viewport_set_measure_render_time(rid, true)
	var gpu: Array[float] = []
	for k in IMAGES_MESUREES:
		await RenderingServer.frame_post_draw
		durees.append(get_process_delta_time())
		appels.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		var total := 0.0
		for rid in vues_mesurees:
			total += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		gpu.append(total)
	appels.sort()
	gpu.sort()
	var s := ConditionsDeMatch.statistiques(durees)
	var id := _id_variante(carte, vue, v)
	var fichier := await _capturer(id)
	var lumieres := int(_p.get("_lumieres").call("allumees")) if _p.get("_lumieres") != null else 0
	# ISO12, lot 0 ter — le NOM de la bride à côté de son vecteur : la bride identité n'a pas de vecteur et s'imprimait
	# comme la (0 ; 0,05). Les colonnes de la planche se choisissent sur ces champs, pas sur le nom de fichier.
	var bride_nom := "identite" if int(v.get("bride_mode", 0)) == 1 \
		else "%02d" % roundi((v.get("bride", Vector2(0.0, 0.05)) as Vector2).y * 100.0)
	print("BANC_LUMIERE3D prise=%s carte=%s vue=%s lumiere=%s ombres=%s atlas=%d bride=%s bride_nom=%s pate=%s contact=%s omni=%s torches_seules=%s ombres_vue_unique=%s retro=%s gpu_ms=%.2f fps_median=%.1f fps_1pc_bas=%.1f pire_ms=%.1f appels=%d lumieres3d=%d fichier=%s ancres=%s"
		% [id, carte, vue, str(v.get("lumiere", false)), str(v.get("ombres", false)), int(v.get("atlas", 0)),
		str(v.get("bride", Vector2(0.0, 0.05))), bride_nom, ["a", "c", "b"][int(v.get("pate", 0))],
		str(v.get("contact", true)), str(v.get("omni", true)), str(v.get("torches_seules", false)),
		str(v.get("vue_unique_seulement", false)), str(v.get("retro", true)), gpu[gpu.size() / 2],
		float(s["fps_median"]), float(s["fps_1pc_bas"]), float(s["pire_image_ms"]),
		appels[appels.size() / 2], lumieres, fichier, JSON.stringify(_ancres(vue == "scinde"))])


func _poser_la_variante(v: Dictionary) -> void:
	_p.bride = v.get("bride", Vector2(0.0, 0.05))
	# ISO12, lot 0 ter — la bride de gradient et les deux émissions du lot (la lumière d'un corps par sa propre lampe, le pied
	# de la lampe au sol) : posées à chaque variante, pour qu'une prise ne traîne jamais le réglage de la précédente.
	_p.bride_mode_3d = int(v.get("bride_mode", 0))
	_p.bride_echelle_3d = float(v.get("bride_echelle", _echelle_identite))
	_p.gain_corps_propre_3d = float(_energies.get("corps_propre", 0.0))
	_p.gain_pied_lampe_3d = float(_energies.get("pied_lampe", 0.0))
	_p.variante_pate_3d = int(v.get("pate", 0))
	_p.masque_preuve = int(v.get("masque", 0))
	_p.ombres_3d = bool(v.get("ombres", true))
	_p.atlas_ombres = int(v.get("atlas", 2048))
	_p.retrodiffusion_3d = bool(v.get("retro", true))
	_p.ombres_omni_3d = bool(v.get("omni", true))
	_p.ombres_torches_joueurs_seules_3d = bool(v.get("torches_seules", false))
	_p.ombres_vue_unique_seulement = bool(v.get("vue_unique_seulement", false))
	_p.poser_lumiere_3d(bool(v.get("lumiere", false)))
	if _energies.has("led"):
		_p.gain_led_3d = float(_energies["led"])
	if _energies.has("halo_soi"):
		_p.gain_halo_soi_3d = float(_energies["halo_soi"])
	var lumieres: Node = _p.get("_lumieres")
	if lumieres != null and not _energies.is_empty():
		var table: Dictionary = lumieres.get("energie_par_type")
		for type in _energies:
			table[type] = _energies[type]
	for m in _p.get("_mat_sols"):
		var mat := m as ShaderMaterial
		if _contact_rayon < 0.0:
			_contact_rayon = float(mat.get_shader_parameter("contact_corps_rayon_px"))
		mat.set_shader_parameter("contact_corps_rayon_px", _contact_rayon if bool(v.get("contact", true)) else 0.0)


## La preuve « visible en 3D ⊆ L2D > 0 » : huit visées, les deux vues, une prise normale et une prise masque chacune.
func _la_preuve(carte: String) -> void:
	_poser_la_vue(true)
	# Le flash rejoué tomberait dans une prise et pas dans l'autre : la paire ne comparerait plus la même scène.
	_flash_actif = false
	for k in VISEES_PREUVE:
		var angle := TAU * float(k) / float(VISEES_PREUVE)
		(_pantins[0] as Pantin).visee = Vector2.RIGHT.rotated(angle)
		(_pantins[1] as Pantin).visee = Vector2.RIGHT.rotated(angle + PI)
		_scene["v1"] = (_pantins[0] as Pantin).visee
		_scene["v2"] = (_pantins[1] as Pantin).visee
		# La référence 2D de cette visée : la vue iso d'ISO11, lumière 3D éteinte — le bleu se juge contre ce que la 2D MONTRE.
		_poser_la_variante({"lumiere": false})
		await _images(IMAGES_DE_REPOS)
		var id_ref := "%s_preuve_v%d_reference2d" % [carte, k]
		var fichier_ref := await _capturer(id_ref)
		print("BANC_LUMIERE3D preuve_reference carte=%s visee=%d fichier=%s" % [carte, k, fichier_ref])
		# La preuve dans les deux sens, rétrodiffusion oui puis non (la seconde montre ce que la première répare).
		for retro in [true, false]:
			for masque in [0, 1]:
				_poser_la_variante({"lumiere": true, "ombres": true, "atlas": 2048, "masque": masque, "retro": retro})
				await _images(IMAGES_DE_REPOS)
				var id := "%s_preuve_v%d_retro%d_%s" % [carte, k, 1 if retro else 0, "masque" if masque == 1 else "normal"]
				var fichier := await _capturer(id)
				print("BANC_LUMIERE3D preuve carte=%s visee=%d retro=%d masque=%d fichier=%s"
					% [carte, k, 1 if retro else 0, masque, fichier])
	_scene["v1"] = Vector2.UP
	_scene["v2"] = Vector2.UP
	_flash_actif = true


## La silhouette de soi : noir complet (torches éteintes, flash coupé, fusée retirée), écran scindé.
func _la_silhouette(carte: String) -> void:
	_poser_la_vue(true)
	for pantin in _pantins:
		(pantin as Pantin).torche = false
	_flash_actif = false
	_retirer_la_fusee()
	_poser_la_variante({"lumiere": true, "ombres": true, "atlas": 2048})
	await _images(90)
	var fichier := await _capturer("%s_silhouette" % carte)
	print("BANC_LUMIERE3D silhouette carte=%s fichier=%s ancres=%s" % [carte, fichier, JSON.stringify(_ancres(true))])
	for pantin in _pantins:
		(pantin as Pantin).torche = true
	_flash_actif = true
	_poser_la_fusee()


## Les ancres de la loupe, en pixels de la fenêtre : J1, J2, le bord du cône de J1, le pied du mur devant J1, la fusée.
## Par vue regardée : `j1` dans la vue de J1, `j2_vue2` dans celle de J2 en écran scindé.
func _ancres(scinde: bool) -> Dictionary:
	var out := {}
	var arme: WeaponData = _main.p1.get("current_weapon")
	var devant := Vector2(_scene["v1"])
	var portee := arme.portee_torche() if arme != null else 300.0
	var demi := deg_to_rad(arme.torch_angle_deg if arme != null else 30.0)
	var points := {
		"j1": _main.p1.global_position,
		"j2": _main.p2.global_position,
		"bord_cone": _main.p1.global_position + devant.rotated(demi) * portee * 0.6,
		"pied_mur": _main.p1.global_position + devant * 3.2 * MursBas.TUILE,
		"sol": _main.p1.global_position + devant * 1.6 * MursBas.TUILE + devant.orthogonal() * 0.8 * MursBas.TUILE,
	}
	if is_instance_valid(_fusee):
		points["fusee"] = _fusee.global_position
	for nom in points:
		out[nom] = _a_l_ecran(0, points[nom])
		if scinde:
			out[nom + "_vue2"] = _a_l_ecran(1, points[nom])
	return out


func _a_l_ecran(pid: int, monde: Vector2) -> Array:
	var projecteur: Callable = _p.projecteur_ecran(pid)
	var cadre: Rect2 = _p._cadre(pid)
	var local: Vector2 = projecteur.call(monde)
	var fenetre := Vector2(DisplayServer.window_get_size())
	var echelle := fenetre / Vector2(get_viewport().get_visible_rect().size)
	var p := (local + cadre.position) * echelle
	return [roundi(p.x), roundi(p.y)]


func _capturer(id: String) -> String:
	_tenir()
	DisplayServer.window_move_to_foreground()
	var img: Image = await RenduCommun.capturer(get_tree(), 15000)
	if img == null:
		_echouer("%s : aucune image rendue en 15 s (fenêtre au second plan ?)" % id)
		return ""
	var nom := id + ".png"
	img.save_png(_dossier.path_join(nom))
	_prises += 1
	return nom


func _id_variante(carte: String, vue: String, v: Dictionary) -> String:
	if not bool(v.get("lumiere", false)):
		return "%s_%s_reference2d" % [carte, vue]
	var b: Vector2 = v.get("bride", Vector2(0.0, 0.05))
	var nom_bride := "identite" if int(v.get("bride_mode", 0)) == 1 else "%02d" % roundi(b.y * 100.0)
	var suffixe := ""
	if not bool(v.get("omni", true)):
		suffixe += "_omni0"
	if bool(v.get("torches_seules", false)):
		suffixe += "_torchesseules"
	if bool(v.get("vue_unique_seulement", false)):
		suffixe += "_ombresvueunique"
	if not bool(v.get("retro", true)):
		suffixe += "_retro0"
	return "%s_%s_ombres%s_atlas%d_bride%s_pate%s_contact%s%s" % [carte, vue, "1" if v.get("ombres", true) else "0",
		int(v.get("atlas", 2048)), nom_bride, ["a", "c", "b"][int(v.get("pate", 0))],
		"1" if v.get("contact", true) else "0", suffixe]


func _poser_la_fusee(ou := Vector2.INF) -> void:
	_retirer_la_fusee()
	var lieu: Vector2 = ou
	if ou == Vector2.INF:
		lieu = _main.p1.global_position + Vector2(_scene["v1"]) * 2.2 * MursBas.TUILE \
			+ Vector2(_scene["v1"]).orthogonal() * 1.5 * MursBas.TUILE
	_fusee = (load("res://fusee.gd") as GDScript).new()
	_fusee.set("depart", lieu)
	_fusee.set("direction", Vector2.DOWN)
	_fusee.set("joueurs", [_main.p1, _main.p2])
	_main.bullet_container.add_child(_fusee)
	_fusee.set_physics_process(false)
	_fusee.global_position = lieu
	_fusee.call("forcer_age", 1.0)


## ISO12, lot 0 ter — LES BRIDES DE GRADIENT, sous la preuve et sous la preuve d'intensité.
##
## La référence 2D et le masque L2D > 0 ne dépendent PAS de la bride : une seule prise de chacun par visée, réutilisée par les
## quatre. La référence sans encre, elle, définit le masque d'encre (voir `_sans_encre`).
func _les_brides(carte: String) -> void:
	_poser_la_vue(true)
	# Le flash rejoué tomberait dans une prise et pas dans l'autre : la paire ne comparerait plus la même scène.
	_flash_actif = false
	for k in VISEES_BRIDES:
		var angle := TAU * float(k) / float(VISEES_PREUVE)
		_scene["v1"] = Vector2.RIGHT.rotated(angle)
		_scene["v2"] = Vector2.RIGHT.rotated(angle + PI)
		(_pantins[0] as Pantin).visee = _scene["v1"]
		(_pantins[1] as Pantin).visee = _scene["v2"]
		_poser_la_variante({"lumiere": false})
		await _images(IMAGES_DE_REPOS)
		var f_ref := await _capturer("%s_brides_v%d_reference2d" % [carte, k])
		print("BANC_LUMIERE3D preuve_reference carte=%s visee=%d fichier=%s" % [carte, k, f_ref])
		_sans_encre(1)
		await _images(IMAGES_DE_REPOS)
		var f_encre := await _capturer("%s_brides_v%d_sansencre" % [carte, k])
		print("BANC_LUMIERE3D preuve_encre carte=%s visee=%d fichier=%s" % [carte, k, f_encre])
		_sans_encre(2)
		await _images(IMAGES_DE_REPOS)
		var f_decor := await _capturer("%s_brides_v%d_sansdecor" % [carte, k])
		print("BANC_LUMIERE3D preuve_decor carte=%s visee=%d fichier=%s" % [carte, k, f_decor])
		_sans_encre(0)
		await _images(IMAGES_DE_REPOS)
		_poser_la_variante({"lumiere": true, "ombres": true, "atlas": 2048, "masque": 1})
		await _images(IMAGES_DE_REPOS)
		var f_masque := await _capturer("%s_brides_v%d_masque" % [carte, k])
		for variante in BRIDES_GRADIENT:
			var v := {"lumiere": true, "ombres": true, "atlas": 2048}
			v.merge(variante, true)
			v.erase("id")
			_poser_la_variante(v)
			await _images(IMAGES_DE_REPOS)
			var f := await _capturer("%s_brides_v%d_%s" % [carte, k, variante["id"]])
			print("BANC_LUMIERE3D preuve carte=%s visee=%d retro=1 bride=%s masque=0 fichier=%s"
				% [carte, k, variante["id"], f])
			print("BANC_LUMIERE3D preuve carte=%s visee=%d retro=1 bride=%s masque=1 fichier=%s"
				% [carte, k, variante["id"], f_masque])
	_scene["v1"] = Vector2.UP
	_scene["v2"] = Vector2.UP
	_flash_actif = true


## ISO12, lot 0 ter — L'ENCRE CACHÉE, pour la référence qui DÉFINIT le masque d'encre.
##
## ⚠️ Dans l'arène ET dans la peinture. `peinture_iso` garde des COPIES des calques dessinés (`…_Peinture`), et c'est la
## peinture que la 3D lit comme albédo : cacher l'original seul n'aurait rien changé à l'image, le masque serait sorti vide, et
## on aurait conclu « pas d'encre » — l'exclusion aurait été décrétée au lieu d'être mesurée.
##
## DEUX NIVEAUX, parce qu'un seul était trop large : 0 = tout montré ; 1 = `MurEncre` caché (le liseré du pied des faces, ce que
## la session cloud a nommé en premier) ; 2 = `MurEncre` ET le décor cachés. Le décor porte le hachurage de la zone morte des
## murets, mais aussi les marquages et pochoirs de l'arène : le compte qui en sort est un MAJORANT de l'encre, jamais l'encre.
## Mesuré au premier jet, masque unique : jusqu'à 33 % des pixels éclairés en 2D en sortaient — une exclusion de cette taille
## cache un vrai manque au lieu de l'expliquer.
func _sans_encre(niveau: int) -> void:
	var calques := {"MurEncre_P1": 1, "MurEncre_P2": 1, "ArenaDecor_P1": 2, "ArenaDecor_P2": 2}
	for nom in calques:
		var n := _main.arena.get_node_or_null(nom) as CanvasItem
		if n != null:
			n.visible = niveau < int(calques[nom])
	var peinture: SubViewport = _p.get("_peinture")
	if peinture == null:
		return
	for nom in {"MurEncre_P1_Peinture": 1, "ArenaDecor_P1_Peinture": 2}:
		var c := peinture.get_node_or_null(nom) as CanvasItem
		if c != null:
			c.visible = niveau < (1 if nom.begins_with("MurEncre") else 2)
	peinture.call("salir")


## ISO12, lot 0 ter — LES CADRAGES QUI JUSTIFIENT ISO12 : l'adversaire dans mon cône, et la fusée.
##
## Chacun en référence 2D, 3D sans ombres et 3D avec ombres : si les ombres n'apportent rien de visible ICI, elles n'apportent
## rien du tout, et « ombres non » devient le défaut. La colonne ×4 sur le corps est faite à l'analyse, sur l'ancre `j2`.
func _les_cadrages(carte: String) -> void:
	_poser_la_vue(true)
	_flash_actif = false
	var p2_origine: Vector2 = _scene["p2"]
	var v2_origine: Vector2 = _scene["v2"]
	var p1: Vector2 = _scene["p1"]
	var v1 := Vector2(_scene["v1"])
	for cadrage in CADRAGES:
		var distance := float(cadrage["distance"]) * MursBas.TUILE
		var dir := _direction_libre(p1, v1, distance)
		if dir == Vector2.ZERO:
			print("BANC_LUMIERE3D cadrage_ignore carte=%s id=%s raison=aucune_direction_libre" % [carte, cadrage["id"]])
			continue
		var place := p1 + dir * distance
		# J1 se tourne vers son adversaire : le cadrage demandé est « l'adversaire DANS MON CÔNE ».
		_scene["v1"] = dir
		(_pantins[0] as Pantin).visee = dir
		_scene["p2"] = place
		_scene["v2"] = dir.orthogonal() if bool(cadrage.get("profil", false)) else -dir
		(_pantins[1] as Pantin).visee = _scene["v2"]
		if bool(cadrage.get("fusee_pres", false)):
			_poser_la_fusee(place + dir.orthogonal() * 2.0 * MursBas.TUILE)
		elif bool(cadrage.get("fusee_muret", false)):
			var muret := _muret_devant(p1, dir)
			if muret.size == Vector2.ZERO:
				print("BANC_LUMIERE3D cadrage_ignore carte=%s id=%s raison=aucun_muret" % [carte, cadrage["id"]])
				continue
			_poser_la_fusee(muret.get_center() + dir * (muret.size.length() * 0.5 + MursBas.TUILE))
		else:
			_retirer_la_fusee()
		var nom := "%s_%s" % [carte, cadrage["id"]]
		await _prendre(nom, "scinde", {"lumiere": false})
		await _prendre(nom, "scinde", {"lumiere": true, "ombres": false})
		await _prendre(nom, "scinde", {"lumiere": true, "ombres": true, "atlas": 2048})
	_scene["p2"] = p2_origine
	_scene["v2"] = v2_origine
	_scene["v1"] = v1
	(_pantins[0] as Pantin).visee = v1
	_poser_la_fusee()
	_flash_actif = true


## La première direction à cette distance où la place est LIBRE **et la vue DÉGAGÉE**, en s'écartant de la visée de J1 par pas
## de 22,5°, alternativement d'un côté puis de l'autre — la plus proche de sa visée d'abord. `Vector2.ZERO` si le tour complet
## ne donne rien.
##
## Les deux conditions, et pas une seule :
## - la mise en scène du banc met un MUR ENTRE LES DEUX JOUEURS, donc droit devant la place est prise par construction ;
## - ⚠️ mais une place LIBRE peut être derrière un coin de mur. L'adversaire y est alors dans le noir, donc pas rendu dans la
##   vue de J1 — et le cadrage « l'adversaire dans mon cône » photographie du sol vide sans que rien ne le signale. C'est
##   arrivé sur les dix cadrages, et les mesures de corps qui en sont sorties mesuraient ce sol.
func _direction_libre(depart: Vector2, visee: Vector2, distance: float) -> Vector2:
	for k in 16:
		var cote := 1.0 if k % 2 == 0 else -1.0
		var pas := float((k + 1) / 2) * TAU / 16.0 * cote
		var dir := visee.rotated(pas)
		var place := depart + dir * distance
		if _libre(place, MursBas.RAYON_ENCOMBREMENT) and not _mur_entre(depart, place):
			return dir
	return Vector2.ZERO


## Le muret le mieux aligné sur la visée de J1, à portée : celui derrière lequel poser une fusée pour la voir du côté sombre.
func _muret_devant(depart: Vector2, sens: Vector2) -> Rect2:
	var meilleur := Rect2()
	var meilleure_note := 0.8
	for m in _main.murs_bas as Array:
		var r := m as Rect2
		var vers: Vector2 = r.get_center() - depart
		var d := vers.length()
		if d < MursBas.TUILE or d > 10.0 * MursBas.TUILE:
			continue
		var note := sens.dot(vers.normalized())
		if note > meilleure_note:
			meilleure_note = note
			meilleur = r
	return meilleur


func _retirer_la_fusee() -> void:
	if is_instance_valid(_fusee):
		_fusee.queue_free()
	_fusee = null


func _tenir() -> void:
	# La manche dure cinq minutes : sans cela, les dernières prises du banc tombent après la fin de la manche, torches éteintes.
	if _main.get("time_left") != null and float(_main.time_left) < 240.0:
		_main.time_left = 280.0
	for pid in 2:
		var j: Node2D = _main.p1 if pid == 0 else _main.p2
		if not is_instance_valid(j):
			continue
		j.global_position = _scene["p%d" % (pid + 1)]
		j.set("velocity", Vector2.ZERO)
		(_pantins[pid] as Pantin).visee = _scene["v%d" % (pid + 1)]
		if not bool(j.get("dead")):
			j.set("hp", 100.0)


func _poser_la_vue(scinde: bool) -> void:
	var c2 := _main.vp2.get_parent() as Control
	if c2 != null:
		c2.visible = scinde
	_main._accorder_rendu_aux_vues()


## La mise en scène de `banc_claustro.gd`, reprise telle quelle.
func _mise_en_scene(data: Dictionary) -> Dictionary:
	var tuile := Vector2(CandelaTileSet.TILE_SIZE)
	var t := tuile.y
	var grille := Vector2(MapCodec.get_grid_size(data)) * tuile
	var interieurs: Array[Rect2] = []
	for r in IsoGeometrie.rects_px(data, MapGeometry.Kind.WALLS, tuile):
		if r.position.x >= 3.0 * t - 0.5 and r.position.y >= 3.0 * t - 0.5 \
				and r.end.x <= grille.x - 3.0 * t + 0.5 and r.end.y <= grille.y - 3.0 * t + 0.5:
			interieurs.append(r)
	interieurs.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.size.x > b.size.x)
	for r in interieurs:
		if r.size.x < 2.0 * t:
			continue
		var p1 := Vector2(r.get_center().x, r.end.y + 3.5 * t)
		var p2 := Vector2(r.get_center().x, r.position.y - 1.2 * t)
		if _libre(p1) and _libre(p2) and _mur_entre(p1, p2):
			return {"p1": p1, "v1": Vector2.UP, "p2": p2, "v2": Vector2.UP}
	var muret := Rect2()
	for m in _main.murs_bas as Array:
		var rect := m as Rect2
		if rect.size.x > rect.size.y and (muret.size == Vector2.ZERO or rect.position.y < muret.position.y):
			muret = rect
	if interieurs.is_empty() and muret.size != Vector2.ZERO:
		return {"p1": Vector2(16.0 * t, 3.0 * t + 3.5 * t), "v1": Vector2.UP,
			"p2": Vector2(muret.get_center().x, muret.end.y + 32.0), "v2": Vector2.DOWN}
	return {}


## ⚠️ `rayon` par défaut à 40 px — soit 80 px de diamètre, pour une tuile de 35. `banc_claustro` s'en accommode parce qu'il
## place ses pantins au large ; un cadrage serré doit passer le rayon d'un corps, sans quoi aucun couloir d'une tuile n'est
## jamais « libre » (les dix cadrages du premier essai ont tous été refusés ainsi).
func _libre(p: Vector2, rayon := 40.0) -> bool:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var disque := CircleShape2D.new()
	disque.radius = rayon
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = disque
	q.collision_mask = MapGeometry.WALL_LAYER
	q.transform = Transform2D(0.0, p)
	q.exclude = [_main.p1.get_rid(), _main.p2.get_rid()]
	return espace.intersect_shape(q, 1).is_empty()


func _mur_entre(a: Vector2, b: Vector2) -> bool:
	var espace := (_main.p1 as Node2D).get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b, MapGeometry.WALL_LAYER)
	q.exclude = [_main.p1.get_rid(), _main.p2.get_rid()]
	return not espace.intersect_ray(q).is_empty()


func _images(n: int) -> void:
	for k in n:
		await RenderingServer.frame_post_draw


func _attendre(condition: Callable, delai: float) -> bool:
	var fin := Time.get_ticks_msec() + int(delai * 1000.0)
	while Time.get_ticks_msec() < fin:
		if condition.call():
			return true
		await get_tree().process_frame
	return false


func _echouer(raison: String) -> void:
	_echecs += 1
	printerr("  ✗ ", raison)


func _finir() -> void:
	if _p != null:
		_p.poser_lumiere_3d(false)
	print("BANC_LUMIERE3D VERDICT=%s prises=%d echecs=%d" % ["OK" if _echecs == 0 else "ECHEC", _prises, _echecs])
	get_tree().quit(0 if _echecs == 0 else 1)
