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
## ISO12 v27 — la hauteur visée d'un corps, en pixels de monde (celle de la loupe).
const HAUTEUR_CORPS := 16.0
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
	## ISO12 v27 — l'accroupi, pour le cas limite 8a de la revue : la torche basse d'un accroupi face à un muret.
	var accroupi := false

	func is_crouch_pressed() -> bool:
		return accroupi

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
## ISO12, lot 0 quater — le coup un (bride du corps forcée à 1) et l'enregistrement des quatre capteurs.
var _bride_corps_forcee := false
var _capteurs_en_image := false
## ISO12 v27 — la recette du relief normalisé (`--v27`) : cadrages en bride IDENTITÉ, celle du jeu. Le banc gardait par défaut
## la bride (0 ; 0,05) du lot 0 : une recette du relief prise sous une autre bride que celle du jeu jugerait un rendu que
## personne ne verra. `--relief-max=1.35` pose le plafond du relief sur les trois matériaux éclairés.
var _v27 := false
var _bride_mode_defaut := 0
var _relief_max := -1.0
## `--v27-cadrage=<id>[,<id>…]` : les cadrages de la v27 à prendre (cumul, recouvrement, une_lumiere, deux_distances,
## deux_lumieres, torche, torche_stricte, torche_retro, fusee_seule, torche_et_fusee, adversaire_arbalete, accroupi_muret,
## neuf_lampes).
var _v27_filtre := ""
## `--taille=1920x1080` : la taille de la fenêtre, donc des captures (défaut `TAILLE`). Les captures d'Adrien sont en 1920×1080.
var _taille := TAILLE
## `--diag-gain=4` : ajoute à chaque cadrage v27 les deux prises de l'instrument du relief (numérateur seul, dénominateur seul).
var _diag_gain := -1.0
## `--biais-ombre=2.0` : le `shadow_bias` des lampes 3D, en unités du monde — ici des PIXELS. Les défauts de Godot sont pensés en
## mètres : ici ils valent une fraction de pixel, moins qu'un texel de la carte d'ombre, d'où l'acné qu'on soupçonne sur les
## faces (la face qui regarde la torche noire, rayée de lignes). Essai de banc seulement.
var _biais_ombre := -1.0
## `--energies-neutres` : toutes les énergies de type du miroir à 1,0 (`LumieresIso.energies_neutres`). Depuis la v27 elles ne
## sont plus une luminosité mais un POIDS entre lampes dans R : 52 contre 3,6 fait peser une fusée quarante fois son poids 2D
## face à une torche. La prise dit si le triangle du cône revient là où une fusée et une torche se rencontrent (L4).
var _energies_neutres := false
## `--relief-plancher=0.35` : r_min, le plancher du relief (`Presentation3D.relief_plancher_3d`) ; `--sans-couleur-l2d` : la L2D
## grise d'avant la décision (3), pour comparer la teinte du halo de la fusée.
var _relief_plancher := -1.0
var _sans_couleur_l2d := false
## `--sans-identite` : l'ancien chemin (albédo peint × L2D bridée) au lieu de la couleur du rendu 2D (`identite_2d`).
var _sans_identite := false
## `--plancher-emission` : l'ancien plancher (`ALBEDO × r_min` en émission brute), qui mélangeait deux espaces.
var _plancher_emission := false
## `--lampe-dominante` : le prototype de la lampe dominante (`Presentation3D.relief_dominante_3d`).
var _lampe_dominante := false
## `--biais-normal=2.0` : le `shadow_normal_bias` des lampes 3D, qui suit la taille du texel d'ombre (essai de banc).
var _biais_normal := -1.0
## `--torche-decroissance=0` : `spot_attenuation` des spots, pour isoler au banc le terme de distance du terme de cône.
var _torche_decroissance := -1.0
## `--decroissance-nulle` : TOUTES les lampes du miroir à décroissance 0 (spots et omnis). Essai de banc : le moteur n'applique
## pas d^(−décroissance) comme la formule publiée dans nos unités, et à 0 moteur et dénominateur coïncident (mesuré).
var _decroissance_nulle := false
## `--seuil-noir=0` : le point noir de la 2D posé sur les trois matériaux éclairés (voir `Presentation3D.seuil_noir_2d_3d`).
var _seuil_noir := -1.0
var _fusees_v27: Array[Node2D] = []
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
	_bride_corps_forcee = args.has("--bride-corps-forcee")
	_capteurs_en_image = args.has("--capteurs")
	_brides_seules = args.has("--brides-seules")
	_cadrages_seuls = args.has("--cadrages-seuls")
	_v27 = args.has("--v27")
	for a in args:
		if a.begins_with("--taille="):
			var wh := a.trim_prefix("--taille=").split("x")
			if wh.size() == 2:
				_taille = Vector2i(wh[0].to_int(), wh[1].to_int())
	_decroissance_nulle = args.has("--decroissance-nulle")
	if _decroissance_nulle:
		_torche_decroissance = 0.0
	if _v27:
		_bride_mode_defaut = 1
	for a in args:
		if a.begins_with("--carte="):
			_carte_seule = a.trim_prefix("--carte=")
		elif a.begins_with("--vue="):
			_vue_seule = a.trim_prefix("--vue=")
		elif a.begins_with("--echelle="):
			_echelle_identite = a.trim_prefix("--echelle=").to_float()
		elif a.begins_with("--v27-cadrage="):
			_v27_filtre = a.trim_prefix("--v27-cadrage=")
		elif a.begins_with("--torche-decroissance="):
			_torche_decroissance = a.trim_prefix("--torche-decroissance=").to_float()
		elif a.begins_with("--seuil-noir="):
			_seuil_noir = a.trim_prefix("--seuil-noir=").to_float()
		elif a.begins_with("--biais-normal="):
			_biais_normal = a.trim_prefix("--biais-normal=").to_float()
		elif a == "--energies-neutres":
			_energies_neutres = true
		elif a.begins_with("--relief-plancher="):
			_relief_plancher = a.trim_prefix("--relief-plancher=").to_float()
		elif a == "--sans-couleur-l2d":
			_sans_couleur_l2d = true
		elif a == "--sans-identite":
			_sans_identite = true
		elif a == "--plancher-emission":
			_plancher_emission = true
		elif a == "--lampe-dominante":
			_lampe_dominante = true
		elif a.begins_with("--biais-ombre="):
			_biais_ombre = a.trim_prefix("--biais-ombre=").to_float()
		elif a.begins_with("--diag-gain="):
			_diag_gain = a.trim_prefix("--diag-gain=").to_float()
		elif a.begins_with("--relief-max="):
			_relief_max = a.trim_prefix("--relief-max=").to_float()
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
	get_window().size = _taille
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
	if _preuve_seule or _brides_seules or _cadrages_seuls or _v27:
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
	if _v27:
		await _la_v27(nom)
		if _v27_filtre == "" or _v27_veut("cadrages"):
			await _les_cadrages(nom)
	if not _rapide and not _brides_seules and not _cadrages_seuls and not _v27:
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
	var bride_nom := "identite" if int(v.get("bride_mode", _bride_mode_defaut)) == 1 \
		else "%02d" % roundi((v.get("bride", Vector2(0.0, 0.05)) as Vector2).y * 100.0)
	print("BANC_LUMIERE3D prise=%s carte=%s vue=%s lumiere=%s ombres=%s atlas=%d bride=%s bride_nom=%s pate=%s contact=%s omni=%s torches_seules=%s ombres_vue_unique=%s retro=%s energies_neutres=%s gpu_ms=%.2f fps_median=%.1f fps_1pc_bas=%.1f pire_ms=%.1f appels=%d lumieres3d=%d fichier=%s ancres=%s"
		% [id, carte, vue, str(v.get("lumiere", false)), str(v.get("ombres", false)), int(v.get("atlas", 0)),
		str(v.get("bride", Vector2(0.0, 0.05))), bride_nom, ["a", "c", "b"][int(v.get("pate", 0))],
		str(v.get("contact", true)), str(v.get("omni", true)), str(v.get("torches_seules", false)),
		str(v.get("vue_unique_seulement", false)), str(v.get("retro", true)), str(_energies_neutres), gpu[gpu.size() / 2],
		float(s["fps_median"]), float(s["fps_1pc_bas"]), float(s["pire_image_ms"]),
		appels[appels.size() / 2], lumieres, fichier, JSON.stringify(_ancres(vue == "scinde"))])


func _poser_la_variante(v: Dictionary) -> void:
	_p.bride = v.get("bride", Vector2(0.0, 0.05))
	# ISO12, lot 0 ter — la bride de gradient et les deux émissions du lot (la lumière d'un corps par sa propre lampe, le pied
	# de la lampe au sol) : posées à chaque variante, pour qu'une prise ne traîne jamais le réglage de la précédente.
	_p.bride_mode_3d = int(v.get("bride_mode", _bride_mode_defaut))
	_p.bride_echelle_3d = float(v.get("bride_echelle", _echelle_identite))
	_p.gain_corps_propre_3d = float(_energies.get("corps_propre", 0.0))
	_p.gain_pied_lampe_3d = float(_energies.get("pied_lampe", 0.0))
	_p.bride_corps_forcee = _bride_corps_forcee
	_p.relief_neutre = bool(v.get("neutre", false))
	if _seuil_noir >= 0.0:
		_p.seuil_noir_2d_3d = _seuil_noir
	if _relief_plancher >= 0.0:
		_p.relief_plancher_3d = _relief_plancher
	if _sans_couleur_l2d:
		_p.relief_couleur_l2d_3d = false
	if _sans_identite:
		_p.identite_2d_3d = false
	if _plancher_emission:
		_p.relief_plancher_lineaire_3d = false
	if _lampe_dominante:
		_p.relief_dominante_3d = true
	_p.variante_pate_3d = int(v.get("pate", 0))
	_p.masque_preuve = int(v.get("masque", 0))
	_p.ombres_3d = bool(v.get("ombres", true))
	_p.atlas_ombres = int(v.get("atlas", 2048))
	_p.retrodiffusion_3d = bool(v.get("retro", true))
	_p.ombres_omni_3d = bool(v.get("omni", true))
	_p.ombres_torches_joueurs_seules_3d = bool(v.get("torches_seules", false))
	_p.ombres_vue_unique_seulement = bool(v.get("vue_unique_seulement", false))
	# ISO12 v27 — LE SABOTAGE du contrôle rouge (g) : la bride COUPÉE, et le rouge doit monter. smoothstep(-1 ; -0,5) vaut 1
	# pour toute L2D ≥ 0, donc sol et murs prennent la lumière 3D là où la 2D est noire ; le corps a son propre court-circuit.
	# Un contrôle qui resterait à zéro sous ce sabotage ne mesurerait rien. La variante suivante repose tout.
	if bool(v.get("sabotage", false)):
		_p.bride = Vector2(-1.0, -0.5)
		_p.bride_mode_3d = 0
		_p.bride_corps_forcee = true
	_p.poser_lumiere_3d(bool(v.get("lumiere", false)))
	_poser_le_biais()
	for m in _p.call("_materiaux"):
		if m == null:
			continue
		if _relief_max > 0.0:
			(m as ShaderMaterial).set_shader_parameter("relief_max", _relief_max)
		# L'instrument du relief (numérateur seul, dénominateur seul) : remis à 0 à chaque variante qui ne le demande pas.
		(m as ShaderMaterial).set_shader_parameter("relief_diagnostic", int(v.get("diagnostic", 0)))
		(m as ShaderMaterial).set_shader_parameter("relief_diagnostic_gain", float(v.get("gain", 1.0)))
	if _energies.has("led"):
		_p.gain_led_3d = float(_energies["led"])
	if _energies.has("halo_soi"):
		_p.gain_halo_soi_3d = float(_energies["halo_soi"])
	var lumieres: Node = _p.get("_lumieres")
	# La décroissance se pose par la TABLE du miroir : `_torche` et `_omni` la réécrivent à chaque image, une propriété posée sur
	# la lampe serait écrasée à l'image suivante.
	# Le biais d'ombre se pose par la VARIABLE du miroir, pour la même raison que la décroissance.
	if lumieres != null and _biais_ombre >= 0.0:
		lumieres.set("biais_ombre", _biais_ombre)
	if lumieres != null:
		lumieres.set("energies_neutres", _energies_neutres)
	if lumieres != null and (_decroissance_nulle or _torche_decroissance >= 0.0):
		var table_att: Dictionary = lumieres.get("attenuation_par_type")
		for type in lumieres.get("TYPES"):
			table_att[type] = 0.0
		if _torche_decroissance >= 0.0:
			table_att["torche"] = _torche_decroissance
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
	var nom_bride := "identite" if int(v.get("bride_mode", _bride_mode_defaut)) == 1 else "%02d" % roundi(b.y * 100.0)
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
	_fusee = _une_fusee(lieu)


## Une fusée POSÉE à cet endroit, à l'âge d'une fusée tombée (`forcer_age`), sans physique : elle ne bouge plus.
func _une_fusee(lieu: Vector2) -> Node2D:
	var f := (load("res://fusee.gd") as GDScript).new() as Node2D
	f.set("depart", lieu)
	f.set("direction", Vector2.DOWN)
	f.set("joueurs", [_main.p1, _main.p2])
	_main.bullet_container.add_child(f)
	f.set_physics_process(false)
	f.global_position = lieu
	f.call("forcer_age", 1.0)
	return f


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
	# ISO12 v27 — la torche de J2 ÉTEINTE, comme au photographe (`loupe-corps`). Allumée, elle tient J1 ébloui à demeure et le
	# jeu efface le sprite adverse, donc le corps voxel : le lot 0 quater a payé trois heures pour ce faux défaut.
	(_pantins[1] as Pantin).torche = not _v27
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
			# Derrière la pierre VUE DE J1 : on prolonge la ligne J1 → muret, pour que la lueur monte de l'autre côté.
			var vers_muret: Vector2 = (muret.get_center() - p1).normalized()
			_poser_la_fusee(muret.get_center() + vers_muret * (muret.size.length() * 0.5 + MursBas.TUILE))
			# Et J1 regarde la pierre : sans cela le cadrage montre une fusée hors champ.
			_scene["v1"] = vers_muret
			(_pantins[0] as Pantin).visee = vers_muret
		else:
			_retirer_la_fusee()
		var nom := "%s_%s" % [carte, cadrage["id"]]
		# ⚠️ LES IMAGES DE REPOS D'ABORD, LA MESURE ENSUITE. `_tenir()` applique `_scene["p2"]` à l'image suivante : mesurer
		# ici sans attendre, c'est décrire le cadrage PRÉCÉDENT sous le nom du cadrage courant. C'est ce qui a produit des
		# opacités « inversées » (0,648 de face, 0,000 de profil) et des corps aux DÉPARTS de la carte, à 665 px l'un de
		# l'autre, quand le cadrage les veut à 105.
		await _images(IMAGES_DE_REPOS)
		_dire_l_etat_du_rejeu(nom)
		if _v27:
			# `j2_pied` : le pied de J2 AU SOL, d'où part son ombre — le décollement d'un biais d'ombre trop fort s'y mesure.
			var ancres := {"j1": [p1, HAUTEUR_CORPS], "j2": [place, HAUTEUR_CORPS], "j2_pied": [place, 0.0],
				"au_dela": [place + dir * 1.2 * MursBas.TUILE, 0.0]}
			if is_instance_valid(_fusee):
				ancres["fusee"] = [_fusee.global_position, 0.0]
			await _serie_v27(nom, ancres)
			continue
		await _prendre(nom, "scinde", {"lumiere": false})
		if _capteurs_en_image:
			await _enregistrer_les_capteurs(nom)
		await _prendre(nom, "scinde", {"lumiere": true, "ombres": false})
		await _prendre(nom, "scinde", {"lumiere": true, "ombres": true, "atlas": 2048})
	_scene["p2"] = p2_origine
	_scene["v2"] = v2_origine
	_scene["v1"] = v1
	(_pantins[0] as Pantin).visee = v1
	(_pantins[1] as Pantin).torche = true
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


## Le muret le plus PROCHE à portée, quel que soit son relèvement : celui derrière lequel poser une fusée pour la voir du côté
## sombre.
##
## ⚠️ **Il exigeait avant un muret dans un cône de 36° autour de la direction du cadrage, ET il n'en trouvait aucun sur les deux
## cartes.** La carte d'essai en porte pourtant cinq suites, dont une droit entre les deux départs : la direction du cadrage est
## celle où l'adversaire a trouvé une PLACE LIBRE, qui n'a aucune raison de pointer vers une pierre. Le cadrage demande un muret
## ATTEIGNABLE, pas un muret droit devant — et un banc qui répond « aucun muret » sur une carte qui en porte accuse la carte à
## la place de sa propre recherche.
func _muret_devant(depart: Vector2, _sens: Vector2) -> Rect2:
	var meilleur := Rect2()
	var meilleure_distance := 12.0 * MursBas.TUILE
	for m in _main.murs_bas as Array:
		var r := m as Rect2
		var d: float = (r.get_center() - depart).length()
		if d < MursBas.TUILE or d > meilleure_distance:
			continue
		meilleure_distance = d
		meilleur = r
	return meilleur


## ISO12, lot 0 quater — LE REJEU TOURNE-T-IL ? Imprimé par la prise, jamais déduit.
##
## `game_state.gd` cache les visuels des DEUX joueurs (`hide_all_visuals`, qui emporte `visual_enemy`) et montre les fantômes
## à leur place tant que `ReplaySystem.playing_back` est vrai. Si cela arrivait pendant un cadrage, le corps visible serait un
## fantôme, l'ancre `j2` pointerait sur un sprite caché, et « l'adversaire n'est pas éclairé » serait un défaut d'instrument.
func _dire_l_etat_du_rejeu(nom: String) -> void:
	var rejeu := get_node_or_null(^"/root/ReplaySystem")
	var en_lecture := bool(rejeu.get("playing_back")) if rejeu != null else false
	var g1 = _main.get("ghost_p1")
	var g2 = _main.get("ghost_p2")
	var v1 := is_instance_valid(g1) and bool((g1 as Node2D).visible)
	var v2 := is_instance_valid(g2) and bool((g2 as Node2D).visible)
	var p1_visible := is_instance_valid(_main.p1) and bool(_main.p1.get("visual").visible)
	print("BANC_LUMIERE3D rejeu carte=%s en_lecture=%s fantome1=%s fantome2=%s visuel_j1=%s"
		% [nom, str(en_lecture), str(v1), str(v2), str(p1_visible)])
	_dire_l_opacite_des_corps(nom)


## ISO12, lot 0 quater — L'OPACITÉ RENDUE DU SPRITE ADVERSE, la dernière quantité en jeu.
##
## `Presentation3D.opacite_du_corps(joueur, le_sien)` rend `opacite_rendue()` du sprite que ce corps remplace : `visual` pour
## le sien, `visual_enemy` pour celui d'en face. Cette valeur part telle quelle dans `opacite_N` du shader des corps. Si elle
## vaut 0 pour J2 vu par J1, le corps voxel est TRANSPARENT par construction — et ses trois entrées disent alors pourquoi,
## puisque `opacite_rendue` rend zéro dès qu'un ancêtre de canevas est caché.
func _dire_l_opacite_des_corps(nom: String) -> void:
	for j in 2:
		var joueur = _main.p1 if j == 0 else _main.p2
		if not is_instance_valid(joueur):
			continue
		var sien: float = Presentation3D.opacite_du_corps(joueur, true)
		var adverse: float = Presentation3D.opacite_du_corps(joueur, false)
		var sprite = joueur.get("visual_enemy")
		var visible := is_instance_valid(sprite) and bool((sprite as CanvasItem).visible)
		var self_a := float((sprite as CanvasItem).self_modulate.a) if is_instance_valid(sprite) else -1.0
		var mod_a := float((sprite as CanvasItem).modulate.a) if is_instance_valid(sprite) else -1.0
		var parent_cache := false
		if is_instance_valid(sprite):
			var n: Node = (sprite as Node).get_parent()
			while n is CanvasItem:
				if not (n as CanvasItem).visible:
					parent_cache = true
					break
				n = n.get_parent()
		print("BANC_LUMIERE3D opacite carte=%s corps=%d sien=%.3f adverse=%.3f sprite_visible=%s self_a=%.3f modulate_a=%.3f parent_cache=%s"
			% [nom, j + 1, sien, adverse, str(visible), self_a, mod_a, str(parent_cache)])
		# ⚠️ L'ÉBLOUISSEMENT LUI-MÊME, et la visée réelle du pantin. `visual_enemy.modulate.a` vaut
		# `Brouillage.opacite(dazzle_du_REGARDEUR)` : pour le corps de J2, c'est le dazzle de J1. Les valeurs mesurées sont
		# à l'envers de la géométrie (de face 0,648, de profil 0,000), donc on lit la quantité au lieu de la raconter.
		var dazzle := float(joueur.get("dazzle_amount"))
		var visee_pantin := Vector2.ZERO
		if j < _pantins.size() and _pantins[j] != null:
			visee_pantin = (_pantins[j] as Pantin).visee
		# Et le corps voxel : un alpha de 0,648 devrait laisser une forme visible ; si le nœud est caché, le compte est ailleurs.
		var voxels = _p.get("_voxels")
		var voxel_visible := false
		var voxel_pos := Vector3.ZERO
		if voxels != null and j < (voxels as Array).size() and voxels[j] != null:
			var noeud = voxels[j]
			if is_instance_valid(noeud) and noeud is Node3D:
				voxel_visible = bool((noeud as Node3D).visible)
				voxel_pos = (noeud as Node3D).global_position
		var pos_joueur := (joueur as Node2D).global_position
		var voulu: Vector2 = _scene.get("p%d" % (j + 1), Vector2.ZERO)
		print("BANC_LUMIERE3D dazzle carte=%s joueur=%d dazzle=%.3f visee=(%.2f,%.2f) voxel_visible=%s voxel_pos=(%.1f,%.1f,%.1f) joueur_pos=(%.1f,%.1f) voulu=(%.1f,%.1f)"
			% [nom, j + 1, dazzle, visee_pantin.x, visee_pantin.y, str(voxel_visible),
			voxel_pos.x, voxel_pos.y, voxel_pos.z, pos_joueur.x, pos_joueur.y, voulu.x, voulu.y])


## ISO12, lot 0 quater — LES QUATRE CAPTEURS, EN IMAGE.
##
## `CapteurCorps` est un `SubViewport` de 256 texels couvrant 128 px de monde, centré sur un corps, où un disque de rayon 18 px
## reçoit la lumière 2D par `masque_capteur(vue, corps)`. Le shader du corps y lit sa lumière (`capteur_N`). Enregistrer la
## texture telle quelle dit, sans raisonnement, si le corps est noir PARCE QUE son capteur l'est.
##
## Le capteur qui décide est « vue 1, corps 2 » : ce que la vue de J1 sait de la lumière sur le corps de J2.
func _enregistrer_les_capteurs(nom: String) -> void:
	var capteurs = _p.get("_capteurs")
	if capteurs == null:
		print("BANC_LUMIERE3D capteurs carte=%s raison=aucun_capteur" % nom)
		return
	for id in 2:
		for j in 2:
			var c = capteurs[id][j]
			if c == null or not is_instance_valid(c):
				continue
			var texture := (c as SubViewport).get_texture()
			if texture == null:
				continue
			var img := texture.get_image()
			if img == null:
				continue
			var fichier := "%s_capteur_vue%d_corps%d.png" % [nom, id + 1, j + 1]
			img.save_png(_dossier.path_join(fichier))
			# La luminance moyenne et le maximum : un capteur noir se lit au chiffre, pas seulement à l'œil.
			var somme := 0.0
			var haut := 0.0
			for y in img.get_height():
				for x in img.get_width():
					var p := img.get_pixel(x, y)
					var l := 0.299 * p.r + 0.587 * p.g + 0.114 * p.b
					somme += l
					haut = maxf(haut, l)
			var n := float(img.get_width() * img.get_height())
			print("BANC_LUMIERE3D capteur carte=%s vue=%d corps=%d moyenne=%.4f max=%.4f fichier=%s"
				% [nom, id + 1, j + 1, somme / maxf(n, 1.0), haut, fichier])


## ISO12 v27 — LA RECETTE DU RELIEF NORMALISÉ, dans l'ordre acté avec la session cloud (ordres 105 et 107).
##
## Vue unique : toute la fenêtre pour J1, donc la résolution la plus haute sur chaque face. Flash coupé : un tir rejoué
## tomberait dans une prise et pas dans l'autre. Chaque cadrage passe par `_serie_v27` : référence 2D, masque L2D > 0,
## 3D sans ombres, 3D avec ombres, et pour le cumul le SABOTAGE qui doit faire rougir le contrôle.
##
## a. le CUMUL — une fusée posée entre les deux torches, toutes deux braquées sur la face sud du mur : le rapport au centre du
##    halo, et la face, que le calcul donne à 1,659 (la fusée écrêtée à `relief_max`, les torches par-dessus) ;
## b. la COURBE — la torche seule sur un sol dégagé, (a) à trois distances : près, milieu, bord de portée ;
## c. le RECOUVREMENT — deux fusées au pied de la face, torches éteintes : l'écrêtage par contribution, lu sur la face ;
## h. UNE lumière puis DEUX, rétrodiffusion coupée, ombres oui contre non : les ombres ajoutent-elles de la lumière ?
func _la_v27(carte: String) -> void:
	_poser_la_vue(false)
	_flash_actif = false
	_retirer_la_fusee()
	var origine := _scene.duplicate()
	var t := MursBas.TUILE
	var p1: Vector2 = origine["p1"]
	# J2 hors de la scène : sa place d'origine est DERRIÈRE le mur, et sa torche est éteinte.
	var loin: Vector2 = origine["p2"]
	var h_face := IsoGeometrie.hauteur_mur_haut() * t * 0.5
	var arme: WeaponData = _main.p1.get("current_weapon")
	var portee := arme.portee_torche() if arme != null else 300.0
	var demi := deg_to_rad(arme.torch_angle_deg if arme != null else 30.0)
	print("BANC_LUMIERE3D v27_debut carte=%s relief_max=%s portee=%.0f demi_cone=%.1f hauteur_face_visee=%.1f"
		% [carte, _relief_max_dit(), portee, rad_to_deg(demi), h_face])
	if not origine.has("face"):
		print("BANC_LUMIERE3D cadrage_ignore carte=%s id=v27_face raison=aucun_mur_haut" % carte)
	else:
		var face: Vector2 = origine["face"]
		if _v27_veut("cumul"):
			var c1 := face + Vector2(-1.2 * t, 3.5 * t)
			var c2 := face + Vector2(1.2 * t, 3.5 * t)
			var cf := face + Vector2(0.0, 1.8 * t)
			if _libre(c1, MursBas.RAYON_ENCOMBREMENT) and _libre(c2, MursBas.RAYON_ENCOMBREMENT):
				_placer(c1, Vector2.UP, true, c2, Vector2.UP, true)
				_fusees_v27.append(_une_fusee(cf))
				await _serie_v27(carte + "_v27_cumul", {"fusee": [cf, 0.0], "face": [face, h_face],
					"face_gauche": [face + Vector2(-t, 0.0), h_face], "face_droite": [face + Vector2(t, 0.0), h_face],
					"sol_devant": [face + Vector2(0.0, 0.8 * t), 0.0], "j1": [c1, HAUTEUR_CORPS],
					"j2": [c2, HAUTEUR_CORPS]}, true)
				_retirer_fusees_v27()
			else:
				print("BANC_LUMIERE3D cadrage_ignore carte=%s id=v27_cumul raison=place_occupee" % carte)
		if _v27_veut("recouvrement"):
			var r1 := face + Vector2(-0.9 * t, 0.7 * t)
			var r2 := face + Vector2(0.9 * t, 0.7 * t)
			_placer(p1, Vector2.UP, false, loin, Vector2.UP, false)
			_fusees_v27.append(_une_fusee(r1))
			_fusees_v27.append(_une_fusee(r2))
			await _serie_v27(carte + "_v27_recouvrement", {"face": [face, h_face],
				"face_f1": [Vector2(r1.x, face.y), h_face], "face_f2": [Vector2(r2.x, face.y), h_face],
				"fusee": [r1, 0.0], "fusee2": [r2, 0.0]})
			_retirer_fusees_v27()
		var ancres_une := {"face": [face, h_face], "sol_devant": [face + Vector2(0.0, 1.5 * t), 0.0],
			"j1": [p1, HAUTEUR_CORPS]}
		if _v27_veut("une_lumiere"):
			_placer(p1, Vector2.UP, true, loin, Vector2.UP, false)
			await _serie_v27(carte + "_v27_une_lumiere", ancres_une, false, {"retro": false})
		# Condition de la décroissance nulle (session cloud, 23:46) : une face atteinte par DEUX lampes à DEUX distances — la
		# torche proche, de face, et une fusée loin, de biais. Décroissance nulle, la lointaine pèse autant que la proche dans sa
		# portée : l'œil juge si le modelé de la face suit la bonne lampe.
		if _v27_veut("deux_distances"):
			var pp := face + Vector2(0.0, 2.0 * t)
			_placer(pp, Vector2.UP, true, loin, Vector2.UP, false)
			var fl := face + Vector2(2.2 * t, 1.6 * t)
			_fusees_v27.append(_une_fusee(fl))
			await _serie_v27(carte + "_v27_deux_distances", {"face": [face, h_face],
				"face_gauche": [face + Vector2(-t, 0.0), h_face], "face_droite": [face + Vector2(t, 0.0), h_face],
				"sol_devant": [face + Vector2(0.0, 0.8 * t), 0.0], "fusee": [fl, 0.0], "j1": [pp, HAUTEUR_CORPS]})
			_retirer_fusees_v27()
		if _v27_veut("deux_lumieres"):
			_placer(p1, Vector2.UP, true, loin, Vector2.UP, false)
			var df := face + Vector2(1.5 * t, 2.0 * t)
			_fusees_v27.append(_une_fusee(df))
			var ancres_deux := ancres_une.duplicate()
			ancres_deux["fusee"] = [df, 0.0]
			await _serie_v27(carte + "_v27_deux_lumieres", ancres_deux, false, {"retro": false})
			_retirer_fusees_v27()
	var dir := _direction_libre(p1, Vector2.DOWN, portee * 0.9)
	if dir == Vector2.ZERO:
		print("BANC_LUMIERE3D cadrage_ignore carte=%s id=v27_torche raison=aucun_sol_degage" % carte)
	else:
		if _v27_veut("torche"):
			_placer(p1, dir, true, loin, Vector2.UP, false)
			await _serie_v27(carte + "_v27_torche", {"pres": [p1 + dir * 1.5 * t, 0.0],
				"milieu": [p1 + dir * portee * 0.5, 0.0], "bord": [p1 + dir * portee * 0.85, 0.0],
				"bord_cone": [p1 + dir.rotated(demi) * portee * 0.6, 0.0], "j1": [p1, HAUTEUR_CORPS]})
		# La torche SEULE au sens strict : rétrodiffusion coupée, une lampe, et l'axe échantillonné tous les 30 px.
		if _v27_veut("torche_stricte"):
			_placer(p1, dir, true, loin, Vector2.UP, false)
			var axe := {"j1": [p1, HAUTEUR_CORPS]}
			for k in range(1, 10):
				axe["d%03d" % (k * 30)] = [p1 + dir * float(k * 30), 0.0]
			axe["travers_g"] = [p1 + dir * portee * 0.4 + dir.orthogonal() * 40.0, 0.0]
			axe["travers_d"] = [p1 + dir * portee * 0.4 - dir.orthogonal() * 40.0, 0.0]
			await _serie_v27(carte + "_v27_torche_stricte", axe, false, {"retro": false})
		# La même, rétrodiffusion ALLUMÉE : isole ce que la rétrodiffusion change à R (l'écart de torche + fusée à 160-200 px).
		if _v27_veut("torche_retro"):
			_placer(p1, dir, true, loin, Vector2.UP, false)
			var axe_r := {"j1": [p1, HAUTEUR_CORPS]}
			for k in range(1, 10):
				axe_r["d%03d" % (k * 30)] = [p1 + dir * float(k * 30), 0.0]
			await _serie_v27(carte + "_v27_torche_retro", axe_r)
		# LA VALIDATION DU CORRECTIF (session cloud) : sur sol plat, R LU AU BANC doit valoir 1 ± 0,05 sous une torche seule (le
		# cadrage `torche` ci-dessus), sous une fusée seule, et sous les deux — d'un bout à l'autre du cône et du halo.
		var fv := p1 + dir * 3.0 * t
		if _v27_veut("fusee_seule"):
			_placer(p1, dir, false, loin, Vector2.UP, false)
			_fusees_v27.append(_une_fusee(fv))
			await _serie_v27(carte + "_v27_fusee_seule", {"fusee": [fv, 0.0],
				"a30": [fv + dir * 30.0, 0.0], "a60": [fv + dir * 60.0, 0.0], "a100": [fv + dir * 100.0, 0.0],
				"a150": [fv + dir * 150.0, 0.0]})
			_retirer_fusees_v27()
		if _v27_veut("torche_et_fusee"):
			_placer(p1, dir, true, loin, Vector2.UP, false)
			var ft := fv + dir.orthogonal() * 1.0 * t
			_fusees_v27.append(_une_fusee(ft))
			await _serie_v27(carte + "_v27_torche_et_fusee", {"fusee": [ft, 0.0], "pres": [p1 + dir * 1.5 * t, 0.0],
				"milieu": [p1 + dir * portee * 0.5, 0.0], "bord": [p1 + dir * portee * 0.85, 0.0],
				"entre": [p1 + dir * 3.0 * t, 0.0]})
			_retirer_fusees_v27()
		# LE SEUIL AU POINT NOIR NE DOIT EFFACER AUCUN CORPS (arbitrage de la session cloud, 2026-09-23, 00:30) : l'adversaire à
		# l'ARBALÈTE, torche allumée, vu DEPUIS LA VUE DE J1 — tout pixel de son corps que la 2D montre doit rester visible en 3D
		# (« moins » dans sa fenêtre : zéro). Sa torche vise de côté, pour que le corps ne soit lu que par sa rétrodiffusion, la
		# lumière la plus faible que le capteur lise ; puis la torche de J1 le prend de face.
		if _v27_veut("adversaire_arbalete"):
			var pa2 := p1 + dir * 2.5 * t
			if _libre(pa2, MursBas.RAYON_ENCOMBREMENT):
				var ancres_adv := {"j2": [pa2, HAUTEUR_CORPS], "j2_pied": [pa2, 0.0], "j1": [p1, HAUTEUR_CORPS]}
				_placer(p1, dir, false, pa2, dir.orthogonal(), true)
				await _serie_v27(carte + "_v27_adversaire_arbalete", ancres_adv)
				_placer(p1, dir, true, pa2, dir.orthogonal(), true)
				await _serie_v27(carte + "_v27_adversaire_arbalete_eclaire", ancres_adv)
			else:
				print("BANC_LUMIERE3D cadrage_ignore carte=%s id=v27_adversaire_arbalete raison=place_occupee" % carte)
		# Cas limite 8a de la revue : la torche d'un ACCROUPI (≈ 14 px du sol) face à un muret. Au-dessus de la lampe, haut·L ≤ 0,
		# donc ε, donc R = N·L / 0,02 : Beauté prédit la face ENTIÈRE au plafond, et non plus une bande. Chiffré ici, sur la carte
		# qui porte des murets (le Cloître n'en a aucun).
		if _v27_veut("accroupi_muret"):
			var muret := _muret_devant(p1, dir)
			if muret.size == Vector2.ZERO or muret.size.x < muret.size.y:
				print("BANC_LUMIERE3D cadrage_ignore carte=%s id=v27_accroupi_muret raison=aucun_muret_horizontal" % carte)
			else:
				var pied := Vector2(muret.get_center().x, muret.end.y)
				var pa := pied + Vector2(0.0, 1.6 * t)
				var h_muret := IsoGeometrie.hauteur_mur_bas() * t
				if _libre(pa, MursBas.RAYON_ENCOMBREMENT):
					_placer(pa, Vector2.UP, true, loin, Vector2.UP, false)
					(_pantins[0] as Pantin).accroupi = true
					await _images(IMAGES_DE_REPOS)
					await _serie_v27(carte + "_v27_accroupi_muret", {"face_bas": [pied, h_muret * 0.25],
						"face_milieu": [pied, h_muret * 0.5], "face_haut": [pied, h_muret * 0.85],
						"face_cote": [pied + Vector2(0.6 * t, 0.0), h_muret * 0.5], "sol": [pied + Vector2(0.0, 0.7 * t), 0.0],
						"j1": [pa, 8.0]}, false, {"retro": false})
					(_pantins[0] as Pantin).accroupi = false
				else:
					print("BANC_LUMIERE3D cadrage_ignore carte=%s id=v27_accroupi_muret raison=place_occupee" % carte)
		# Défaut 7 de la revue d'ISO7 Beauté : NEUF lampes et plus. Le dénominateur n'en décrit que huit, triées par intensité
		# sur toute la carte ; le moteur, lui, apparie par maillage. Sept fusées posées LOIN de J1 (derrière le mur, hors de
		# portée de ses pieds) et les deux torches : la lumière aux pieds de J1 ne devrait pas dépendre d'une fusée à l'autre
		# bout de la carte. Même prise à huit lampes (une fusée retirée) : l'écart aux pieds de J1 se lit entre les deux.
		if _v27_veut("neuf_lampes"):
			_placer(p1, dir, true, loin, Vector2.UP, true)
			for k in 7:
				_fusees_v27.append(_une_fusee(loin + Vector2((float(k) - 3.0) * 0.8 * t, -2.5 * t)))
			var ancres_neuf := {"pieds_j1": [p1 + dir * 0.6 * t, 0.0], "pres": [p1 + dir * 1.5 * t, 0.0],
				"milieu": [p1 + dir * portee * 0.5, 0.0], "j1": [p1, HAUTEUR_CORPS]}
			await _serie_v27(carte + "_v27_neuf_lampes", ancres_neuf)
			var derniere: Node2D = _fusees_v27.pop_back()
			derniere.queue_free()
			await _serie_v27(carte + "_v27_huit_lampes", ancres_neuf)
			_retirer_fusees_v27()
	# Les captures d'Adrien : seulement demandées NOMMÉMENT (`--v27-cadrage=adrien`), jamais par un filtre vide.
	if _v27_filtre.split(",").has("adrien"):
		await _les_captures_adrien(carte, origine, p1, dir, portee)
	if _v27_filtre.split(",").has("adrien_1b") and carte == "cloitre" and dir != Vector2.ZERO:
		await _le_croisement_adrien(carte, p1, dir)
	_scene = origine
	(_pantins[0] as Pantin).torche = true
	(_pantins[1] as Pantin).torche = true
	_flash_actif = true
	_poser_la_fusee()


## ISO12 — (1b) LE CROISEMENT : les deux torches visent le MÊME point du sol, à angle droit. Le face-à-face de (1) faisait se
## recouvrir les deux cônes sur une même ligne ; ici ils se coupent, et le relief de leur recouvrement se lit en croix.
func _le_croisement_adrien(carte: String, p1: Vector2, dir: Vector2) -> void:
	var t := MursBas.TUILE
	# Au premier passage, une seule géométrie (3 tuiles devant, 3 de côté) ne trouvait aucune place au Cloître : on cherche
	# la plus proche du duel, de deux à quatre tuiles devant et de deux à quatre de côté, des deux côtés.
	for avance in [3.0, 2.5, 3.5, 2.0, 4.0]:
		var cible: Vector2 = p1 + dir * avance * t
		if not _libre(cible, MursBas.RAYON_ENCOMBREMENT) or _mur_entre(p1, cible):
			continue
		# Au deuxième passage, l'angle droit strict ne trouvait toujours rien (le départ du Cloître est serré entre deux
		# murs) : J2 peut venir de 60 à 120° de l'axe de J1, les cônes se coupent encore franchement.
		for ecart in [3.0, 2.5, 3.5, 2.0, 4.0]:
			for angle in [90.0, -90.0, 60.0, -60.0, 120.0, -120.0]:
				var p2: Vector2 = cible + dir.rotated(deg_to_rad(angle)) * ecart * t
				if _libre(p2, MursBas.RAYON_ENCOMBREMENT) and not _mur_entre(p2, cible):
					_placer(p1, dir, true, p2, (cible - p2).normalized(), true)
					await _serie_v27("adrien_1b_croisement", {"j1": [p1, HAUTEUR_CORPS], "j2": [p2, HAUTEUR_CORPS],
						"croisement": [cible, 0.0]})
					return
	print("BANC_LUMIERE3D cadrage_ignore carte=%s id=adrien_1b_croisement raison=aucune_place" % carte)


## ISO12 — LES CAPTURES D'ADRIEN : cinq cadrages pour juger à l'œil, en vue unique, plein cadre. Chaque cadrage passe par
## `_serie_v27` : la référence 2D (C), sans ombres (A) et avec ombres (B) sont prises à la suite, corps immobiles, caméra
## posée et vérifiée — le même instant au sens du banc. Le Cloître porte les murs hauts, la carte d'essai les murets : chaque
## cadrage dit sur quelle carte il se prend, et `cadrage_ignore` s'il ne trouve pas sa place.
func _les_captures_adrien(carte: String, origine: Dictionary, p1: Vector2, dir: Vector2, portee: float) -> void:
	var t := MursBas.TUILE
	if carte == "cloitre" and dir != Vector2.ZERO:
		# (1) Le duel : face à face à cinq tuiles, les deux torches se croisent au milieu.
		var d5 := _direction_libre(p1, dir, 5.0 * t)
		if d5 != Vector2.ZERO:
			var p2 := p1 + d5 * 5.0 * t
			_placer(p1, d5, true, p2, -d5, true)
			await _serie_v27("adrien_1_duel", {"j1": [p1, HAUTEUR_CORPS], "j2": [p2, HAUTEUR_CORPS],
				"milieu": [(p1 + p2) * 0.5, 0.0]})
		else:
			print("BANC_LUMIERE3D cadrage_ignore carte=%s id=adrien_1_duel raison=aucune_place" % carte)
		# (2) Une torche et une fusée qui se recouvrent : la fusée posée dans le cône, à mi-portée, un peu de côté.
		_placer(p1, dir, true, origine["p2"], Vector2.UP, false)
		var fr := p1 + dir * portee * 0.45 + dir.orthogonal() * 0.8 * t
		_fusees_v27.append(_une_fusee(fr))
		await _serie_v27("adrien_2_torche_et_fusee", {"j1": [p1, HAUTEUR_CORPS], "fusee": [fr, 0.0]})
		_retirer_fusees_v27()
		# (4) Un corps de près, éclairé de côté : J2 à deux tuiles, la torche de J1 le prend par le flanc, la sienne éteinte.
		var dc := _direction_libre(p1, Vector2.RIGHT, 2.0 * t)
		if dc != Vector2.ZERO:
			var pc := p1 + dc * 2.0 * t
			_placer(p1, dc, true, pc, Vector2.DOWN, false)
			await _serie_v27("adrien_4_corps_de_pres", {"j1": [p1, HAUTEUR_CORPS], "j2": [pc, HAUTEUR_CORPS]})
		else:
			print("BANC_LUMIERE3D cadrage_ignore carte=%s id=adrien_4_corps_de_pres raison=aucune_place" % carte)
		# (5) Le long d'un mur haut, sous la torche : les faces lues par l'angle, la torche parallèle au mur.
		if origine.has("face"):
			var face: Vector2 = origine["face"]
			var pm := face + Vector2(-2.5 * t, 1.0 * t)
			if _libre(pm, MursBas.RAYON_ENCOMBREMENT):
				_placer(pm, Vector2.RIGHT, true, origine["p2"], Vector2.UP, false)
				await _serie_v27("adrien_5_mur_haut_rasant", {"j1": [pm, HAUTEUR_CORPS],
					"face": [face, IsoGeometrie.hauteur_mur_haut() * t * 0.5]})
			else:
				print("BANC_LUMIERE3D cadrage_ignore carte=%s id=adrien_5_mur_haut_rasant raison=place_occupee" % carte)
	if carte == "murs_bas":
		# (3) L'adversaire derrière un muret, éclairé par la torche de J1 : l'ombre portée de son corps s'y voit, ou non.
		var muret := _muret_devant(p1, dir)
		if muret.size == Vector2.ZERO or muret.size.x < muret.size.y:
			print("BANC_LUMIERE3D cadrage_ignore carte=%s id=adrien_3_derriere_muret raison=aucun_muret_horizontal" % carte)
		else:
			var derriere := Vector2(muret.get_center().x, muret.position.y - 0.7 * t)
			var devant := Vector2(muret.get_center().x, muret.end.y + 3.0 * t)
			if _libre(derriere, MursBas.RAYON_ENCOMBREMENT) and _libre(devant, MursBas.RAYON_ENCOMBREMENT):
				_placer(devant, Vector2.UP, true, derriere, Vector2.DOWN, false)
				await _serie_v27("adrien_3_derriere_muret", {"j1": [devant, HAUTEUR_CORPS], "j2": [derriere, HAUTEUR_CORPS],
					"muret": [Vector2(muret.get_center().x, muret.end.y), IsoGeometrie.hauteur_mur_bas() * t * 0.5]})
			else:
				print("BANC_LUMIERE3D cadrage_ignore carte=%s id=adrien_3_derriere_muret raison=place_occupee" % carte)


## Un cadrage de la v27, en quatre prises (cinq avec le sabotage), toutes à la bride IDENTITÉ du jeu.
##
## ⚠️ Les ancres sont projetées UNE fois, après le repos : les corps ne bougent plus, la caméra non plus. Elles portent une
## HAUTEUR (`CameraIso.vers_ecran`) : une face de mur se vise à mi-hauteur, pas à son pied, sinon on mesure le sol devant.
func _serie_v27(nom: String, ancres: Dictionary, sabotage := false, extra := {}) -> void:
	await _images(IMAGES_DE_REPOS)
	# ⚠️ LA CAMÉRA D'ABORD. Elle glisse vers l'avant de la visée de J1 (le décalage de visée), et ce glissement dure bien plus
	# que trente images quand la visée vient de changer. Projeter les ancres avant qu'elle soit posée, c'est viser à côté —
	# et pire, comparer pixel à pixel des prises prises sous deux caméras. Vécu au premier passage du correctif (2026-09-22) :
	# l'ancre de J1 à (960 ; 560), J1 à l'image vers (600 ; 280), et des « R ≈ 0,44 » mesurés à côté du cône. On attend donc
	# que l'ancre de J1 ne bouge plus d'un pixel sur dix images, six secondes au plus.
	var avant := _a_l_ecran_h(0, _scene["p1"], HAUTEUR_CORPS)
	var posee := false
	for essai in 60:
		await _images(10)
		var ici := _a_l_ecran_h(0, _scene["p1"], HAUTEUR_CORPS)
		if ici == avant:
			posee = true
			break
		avant = ici
	if not posee:
		_echouer("%s : la caméra ne s'est pas posée en 600 images" % nom)
	# Les lampes nées pendant le repos (une fusée posée juste avant) reçoivent le biais d'essai elles aussi.
	_poser_le_biais()
	_dire_l_etat_du_rejeu(nom)
	var ecran := {}
	for k in ancres:
		var a: Array = ancres[k]
		ecran[k] = _a_l_ecran_h(0, a[0], float(a[1]))
	var variantes := [
		["reference2d", {"lumiere": false}],
		["masque", {"lumiere": true, "ombres": true, "atlas": 2048, "masque": 1}],
		["sans_ombres", {"lumiere": true, "ombres": false}],
		["ombres", {"lumiere": true, "ombres": true, "atlas": 2048}],
		# R = 1 forcé (aucune lampe au relief, la garde émet la 2D) : le diviseur qui donne R LU À L'IMAGE.
		["neutre", {"lumiere": true, "ombres": false, "neutre": true}],
	]
	if _diag_gain > 0.0:
		# L'instrument : le numérateur seul, puis le dénominateur seul, à la même échelle — leur rapport pixel par pixel est R.
		variantes.append(["diag_num", {"lumiere": true, "ombres": false, "diagnostic": 1, "gain": _diag_gain}])
		variantes.append(["diag_den", {"lumiere": true, "ombres": false, "diagnostic": 2, "gain": _diag_gain}])
		# Et chaque terme du dénominateur pour la lampe 0, sur le sol : distance, fenêtre, décroissance, cône, incidence.
		for mode in [3, 4, 5, 6, 7]:
			variantes.append(["terme%d" % mode, {"lumiere": true, "ombres": false, "diagnostic": mode}])
		# La L2D brute, pour mesurer le point noir de la 2D contre la référence.
		variantes.append(["l2d", {"lumiere": true, "ombres": false, "diagnostic": 10}])
		# Le varying tel que `light()` le reçoit (une lampe : l'image vaut relief_d × gain, comme la prise diag_den).
		variantes.append(["diag_recu", {"lumiere": true, "ombres": false, "diagnostic": 9, "gain": _diag_gain}])
		for c in [0.25, 0.5, 1.0]:
			variantes.append(["constante_%03d" % roundi(c * 100.0), {"lumiere": true, "ombres": false, "diagnostic": 8, "gain": c}])
	if sabotage:
		variantes.append(["sabotage", {"lumiere": true, "ombres": true, "atlas": 2048, "sabotage": true}])
	for e in variantes:
		var v: Dictionary = (e[1] as Dictionary).duplicate()
		v["bride_mode"] = 1
		v.merge(extra, false)
		_poser_la_variante(v)
		await _images(IMAGES_DE_REPOS)
		var id := "%s_%s" % [nom, e[0]]
		var fichier := await _capturer(id)
		var lumieres := int(_p.get("_lumieres").call("allumees")) if _p.get("_lumieres") != null else 0
		# Les lampes du dénominateur, telles que le miroir les décrit CETTE image, et toutes les Light3D de la scène : une lampe
		# que le moteur rend et que la liste ignore se voit ici, pas à l'image.
		if e[0] == "diag_num" and _p.get("_lumieres") != null:
			# Les ÉCHELLES : le moteur éclaire dans l'espace de la CAMÉRA. Une caméra ou une scène mise à l'échelle déforme ses
			# distances sans toucher aux portées des lampes, et le dénominateur, en monde, ne le voit pas.
			var cam3: Camera3D = _p._camera_de(0)
			var lum_parent := (_p.get("_lumieres") as Node3D)
			print("BANC_LUMIERE3D v27_echelles cadrage=%s camera_globale=%s camera_parent=%s lumieres=%s vue_camera_active=%s"
				% [nom, str(cam3.global_transform.basis.get_scale()) if cam3 != null else "?",
				str((cam3.get_parent() as Node3D).global_transform.basis.get_scale()) if cam3 != null and cam3.get_parent() is Node3D else "pas_node3d",
				str(lum_parent.global_transform.basis.get_scale()), str(get_viewport().get_camera_3d())])
			for mi in get_tree().root.find_children("*", "MeshInstance3D", true, false):
				var m3 := mi as MeshInstance3D
				if m3.get_surface_override_material(0) is ShaderMaterial or m3.material_override is ShaderMaterial:
					var sm: ShaderMaterial = m3.material_override if m3.material_override is ShaderMaterial else m3.get_surface_override_material(0)
					if sm.shader != null and sm.shader.resource_path.ends_with("sol_iso_eclaire.gdshader"):
						print("BANC_LUMIERE3D v27_sol cadrage=%s nom=%s echelle=%s origine=%s"
							% [nom, m3.name, str(m3.global_transform.basis.get_scale()), str(m3.global_position)])
						break
			for lampe in (_p.get("_lumieres") as Node).call("decrire_pour_relief"):
				print("BANC_LUMIERE3D v27_lampe cadrage=%s %s" % [nom, str(lampe)])
			for l3 in get_tree().root.find_children("*", "Light3D", true, false):
				var lum3 := l3 as Light3D
				print("BANC_LUMIERE3D v27_light3d cadrage=%s nom=%s type=%s visible=%s energie=%.3f pos=%s"
					% [nom, lum3.name, lum3.get_class(), str(lum3.is_visible_in_tree()), lum3.light_energy,
					str(lum3.global_position)])
		# La caméra DE CETTE PRISE : l'analyse refuse de comparer deux prises dont J1 n'est pas au même pixel.
		var camera: Array = _a_l_ecran_h(0, _scene["p1"], HAUTEUR_CORPS)
		print("BANC_LUMIERE3D v27 cadrage=%s variante=%s lumieres3d=%d relief_max=%s energies_neutres=%s plancher=%.2f couleur_l2d=%s identite=%s plancher_lineaire=%s dominante=%s camera=%d,%d fichier=%s ancres=%s"
			% [nom, e[0], lumieres, _relief_max_dit(), str(_energies_neutres), float(_p.relief_plancher_3d),
			str(_p.relief_couleur_l2d_3d), str(_p.identite_2d_3d), str(_p.relief_plancher_lineaire_3d),
			str(_p.relief_dominante_3d), int(camera[0]), int(camera[1]), fichier,
			JSON.stringify(ecran)])
	# Le sabotage ne doit jamais survivre à sa prise : on repose l'état du jeu, lumière éteinte.
	_poser_la_variante({"lumiere": false})


func _placer(p1: Vector2, v1: Vector2, torche1: bool, p2: Vector2, v2: Vector2, torche2: bool) -> void:
	_scene["p1"] = p1
	_scene["v1"] = v1
	_scene["p2"] = p2
	_scene["v2"] = v2
	(_pantins[0] as Pantin).visee = v1
	(_pantins[0] as Pantin).torche = torche1
	(_pantins[1] as Pantin).visee = v2
	(_pantins[1] as Pantin).torche = torche2


## `_a_l_ecran` avec une HAUTEUR au-dessus du sol, en pixels de monde.
func _a_l_ecran_h(pid: int, monde: Vector2, hauteur: float) -> Array:
	var cam: CameraIso = _p._camera_de(pid)
	var ecran := _p.viewport_ecran(pid)
	if cam == null or ecran == null:
		return [0, 0]
	var local := cam.vers_ecran(monde, ecran.get_visible_rect().size, hauteur)
	var cadre: Rect2 = _p._cadre(pid)
	var fenetre := Vector2(DisplayServer.window_get_size())
	var echelle := fenetre / Vector2(get_viewport().get_visible_rect().size)
	var p := (local + cadre.position) * echelle
	return [roundi(p.x), roundi(p.y)]


func _poser_le_biais() -> void:
	if (_biais_ombre < 0.0 and _biais_normal < 0.0) or _p == null or _p.get("_lumieres") == null:
		return
	for l in (_p.get("_lumieres") as Node).find_children("*", "Light3D", true, false):
		if _biais_normal >= 0.0:
			(l as Light3D).shadow_normal_bias = _biais_normal


func _v27_veut(id: String) -> bool:
	return _v27_filtre == "" or id in _v27_filtre.split(",")


func _relief_max_dit() -> String:
	return ("%.2f" % _relief_max) if _relief_max > 0.0 else "1.50(defaut)"


func _retirer_fusees_v27() -> void:
	for f in _fusees_v27:
		if is_instance_valid(f):
			f.queue_free()
	_fusees_v27.clear()


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
			# `face` : le milieu de la face SUD du mur, celle que la caméra voit et que la torche de J1 éclaire (v27).
			return {"p1": p1, "v1": Vector2.UP, "p2": p2, "v2": Vector2.UP, "face": Vector2(r.get_center().x, r.end.y)}
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
