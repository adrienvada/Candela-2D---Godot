extends "res://tools/photographe.gd"

## Q40 — LA LAMPE CLAIRE, SUR IMAGE : une séance du photographe, héritière de `photo_essais.gd` (maintien des joueurs,
## graine, repos en images de jeu, congé de l'intro — recopiés : `photo_essais.gd` lit `tuyaux_iso.gd`, absent de cette base), qui prend chaque scène DEUX fois AU MÊME INSTANT — jeu en pause, la
## lampe claire basculée à chaud sur le sol et les murs (`Presentation3D.poser_lampe_claire`) — puis une troisième fois
## éteinte, pour le bruit (il doit être nul : rien ne bouge en pause). L'écart entre « défaut » et « essai » est donc
## l'essai et rien d'autre, sans comparer deux lancements.
##
## Les scènes, sur les six cartes livrées, lacet par défaut (45° B), fenêtre 1920×1080, zoom du duel :
##   duel    — J1 au sud d'un mur, torche vers lui ; J2 debout dans son cône, torche de côté ; puis torches éteintes ;
##   scinde  — l'écran scindé, J1 et J2 de part et d'autre du mur (quand la carte en offre un), J2 vu depuis l'autre côté ;
##   classes — (Cloître seulement) J2 au BORD du cône de J1, les dix classes l'une après l'autre ; chaque prise aussi
##             corps de J2 caché (le masque du corps), et la lecture brute des capteurs de corps.
## Les lectures des capteurs (le maximum du disque, en 0..1, par vue et par corps) vont dans `capteurs.json`.
##
##     GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . \
##         res://tools/photo_lampe.tscn -- --no-eos --led-murs-fige --sortie=user://lampe
##
## Il EXIGE une vraie fenêtre, comme le photographe.

const CARTES := [
	"res://assets/maps/map_001_le_cloitre.json",
	"res://assets/maps/map_002_l_usine.json",
	"res://assets/maps/map_003_la_croisee.json",
	"res://assets/maps/map_004_le_bunker.json",
	"res://assets/maps/arene_circulaire.json",
	"res://assets/maps/default.json",
]
## La part de la portée de la torche de J1 où J2 se tient pour la scène des classes : le bord du cône.
const BORD_DU_CONE := 0.92

## Le repos avant chaque prise, en images de jeu (1,5 s à 60 Hz) : la caméra et le regard convergent.
const REPOS_IMAGES := 90

var _j1 := Vector2.ZERO
var _visee_j1 := Vector2.UP
var _j2 := Vector2.ZERO
var _visee_j2 := Vector2.RIGHT
var _j2_present := true
var _torches_allumees := true
var _scenes := PackedStringArray()
var _lectures := {}
var _cartes_voulues := PackedStringArray()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	seed(int(_valeur(args, "--graine", "20260928")))
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la planche de la lampe claire exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://lampe")
	_scenes = _valeur(args, "--scenes", "duel,scinde,classes").split(",")
	_cartes_voulues = _valeur(args, "--cartes", "").split(",", false)
	_sans_hud = true
	_carte_duel = CARTES[0]
	_zoom = 1.0
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== La lampe claire (Q40) ===")
	print("  drapeaux : %s" % " ".join(args))
	_poser_la_fenetre()
	await _lire_l_horloge()
	if _pas_fixe <= 0.0:
		printerr("✗ lancer avec --fixed-fps 60 : sans horloge fixe, deux lancements ne gèlent pas au même instant")
		_sortir(1)
		return
	_mute_avant = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	_main.rendu_racine_autorise = false
	_main.archiver_les_matchs = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	# L'intro en planches d'un user:// neuf couvrirait chaque prise : congédiée (piège payé deux fois la nuit du 27/09).
	for enfant in _main.get_children():
		if enfant.get_script() == preload("res://intro_planches.gd"):
			enfant.emit_signal("terminee")
	await _traiter_l_allumage([] as Array[Dictionary])

	_ui.hub.reset()
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active, 20.0):
		printerr("✗ la manche n'a jamais démarré")
		_sortir(1)
		return
	_prendre_les_commandes()
	if not await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 20.0):
		printerr("✗ le décompte n'a jamais fini")
		_sortir(1)
		return
	_torches(true)
	_vue_unique()
	var reglages := get_node_or_null(^"/root/GameSettings")
	var lacet := float(reglages.call("lacet_de", 0)) if reglages != null else 0.0
	print("  lacet de J1 : %s° · zoom caméra : %s" % [str(lacet), str(_main.cam1.zoom.x)])
	var iso := Presentation3D.instance()
	if iso == null:
		printerr("✗ la vue iso n'est pas là")
		_sortir(1)
		return
	print("  lampe claire au départ : %s (le drapeau n'est pas posé : l'outil la bascule lui-même)" % str(iso.lampe_claire))

	var t := float(CandelaTileSet.TILE_SIZE.x)
	for chemin in CARTES:
		var slug := String(chemin).get_file().get_basename()
		if not _cartes_voulues.is_empty() and not _cartes_voulues.has(slug):
			continue
		var data := _charger(chemin)
		if data.is_empty():
			continue
		MapData.current_map_data = data
		_main.rebuild_arena()
		await _attendre_images(5)
		var scene := _mise_en_scene_du_duel(data)
		print("CARTE %s : %s" % [slug, scene.get("mur", "?")])
		_j1 = scene["p1"]
		_visee_j1 = Vector2.UP
		# J2 debout dans le cône de J1, entre lui et le mur : la première place libre (sol, pas de muret entre eux).
		_j2_present = false
		for decalage in [Vector2(0.6, -2.6), Vector2(0.4, -2.0), Vector2(-0.4, -2.0), Vector2(0.3, -1.6), Vector2(0.0, -1.3)]:
			_j2 = _j1 + decalage * t
			if _sol_libre(_j2) and not _mur_entre(_j1, _j2):
				_j2_present = true
				break
		_visee_j2 = Vector2.RIGHT
		if _scenes.has("duel"):
			print("SCENE %s_duel : J1 %s · J2 %s (présent : %s)" % [slug, str(_j1), str(_j2), str(_j2_present)])
			await _prises("%s_duel" % slug, "vue", true)
			await _prises("%s_noir" % slug, "vue", false)
		if _scenes.has("scinde") and scene.has("p2"):
			var j2_duel := _j2
			var present := _j2_present
			_j2 = scene["p2"]
			_visee_j2 = Vector2.DOWN
			_j2_present = true
			print("SCENE %s_scinde : J1 %s · J2 %s" % [slug, str(_j1), str(_j2)])
			_deux_vues()
			await _prises("%s_scinde" % slug, "ecran", true)
			await _prises("%s_scinde_noir" % slug, "ecran", false)
			_vue_unique()
			_j2 = j2_duel
			_j2_present = present
			_visee_j2 = Vector2.RIGHT
		if _scenes.has("classes") and slug == "map_001_le_cloitre":
			await _scene_des_classes(slug)

	var f := FileAccess.open(ProjectSettings.globalize_path("%s/capteurs.json" % _dossier), FileAccess.WRITE)
	f.store_string(JSON.stringify(_lectures, "\t"))
	f.close()
	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


func _charger(chemin: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(chemin)) != OK or not (json.data is Dictionary):
		printerr("  ! carte illisible : %s" % chemin)
		return {}
	return MapCodec.validate(json.data as Dictionary)["data"]


## J2 au bord du cône de J1 : la première direction (vers le mur d'abord) où la ligne jusqu'à `BORD_DU_CONE` × la portée
## est libre ; J2 regarde de côté (aucun des deux n'éblouit l'autre). Les dix classes pour J2, J1 garde la sienne.
func _scene_des_classes(slug: String) -> void:
	var portee: float = _main.p1.current_weapon.portee_torche() if _main.p1.current_weapon else 200.0
	var r := portee * BORD_DU_CONE
	var choisie := Vector2.ZERO
	for d in [Vector2.UP, Vector2.UP.rotated(0.5), Vector2.UP.rotated(-0.5), Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]:
		var p: Vector2 = _j1 + d * r
		if _sol_libre(p) and not _mur_entre(_j1, p):
			choisie = d
			break
	if choisie == Vector2.ZERO:
		printerr("  ! %s : aucune direction libre sur %d px, pas de scène des classes" % [slug, int(r)])
		return
	_visee_j1 = choisie
	_j2 = _j1 + choisie * r
	_visee_j2 = choisie.rotated(PI * 0.5)
	_j2_present = true
	var avant = _main.p2.current_weapon
	var n := 10
	for i in n:
		var classe = _main.weapon_for_index(i)
		if classe == null:
			continue
		_main.p2.equip_weapon(classe)
		var nom := "%s_classe%d" % [slug, i]
		print("SCENE %s : %s · J2 à %d px (portée %d) · J1 %s vers %s" % [nom, str(classe.name), int(r), int(portee),
			str(_j1), str(choisie)])
		await _prises(nom, "vue", true, true)
	_main.p2.equip_weapon(avant)
	_visee_j1 = Vector2.UP


## Une scène : repos, pause, puis au même instant « défaut », « essai », « défaut2 » (le bruit), et, pour les classes,
## « essai » et « défaut » corps de J2 caché.
func _prises(nom: String, source: String, allumees: bool, masque_du_corps := false) -> void:
	var iso := Presentation3D.instance()
	_torches_allumees = allumees
	_torches(allumees)
	for i in REPOS_IMAGES:
		_tenir()
		await get_tree().process_frame
	_tenir()
	get_tree().paused = true
	await _attendre_images(3)
	var lectures := {}
	for etat in [["defaut", false], ["essai", true], ["defaut2", false]]:
		iso.poser_lampe_claire(etat[1])
		await _attendre_images(3)
		_ecrire_prise(await _capturer(source), "%s__%s" % [nom, etat[0]])
		lectures[etat[0]] = _lire_les_capteurs(iso)
	if masque_du_corps:
		var corps := iso.get("_voxels") as Array
		if corps.size() > 1 and corps[1] is Node3D:
			(corps[1] as Node3D).visible = false
			for etat in [["sans_corps_defaut", false], ["sans_corps_essai", true]]:
				iso.poser_lampe_claire(etat[1])
				await _attendre_images(3)
				_ecrire_prise(await _capturer(source), "%s__%s" % [nom, etat[0]])
			(corps[1] as Node3D).visible = true
	iso.poser_lampe_claire(false)
	lectures["eblouissement"] = [_main.p1.dazzle_amount, _main.p2.dazzle_amount]
	lectures["arme_j2"] = str(_main.p2.current_weapon.name) if _main.p2.current_weapon else ""
	_lectures[nom] = lectures
	print("CAPTEURS %s %s" % [nom, JSON.stringify(lectures)])
	get_tree().paused = false
	_torches_allumees = true
	_torches(true)


## Le maximum de chaque disque de capteur (luminance aux poids de la pâte, 0..1), `[vue][corps]` ; -1 si absent.
func _lire_les_capteurs(iso: Presentation3D) -> Array:
	var sortie := []
	var capteurs := iso.get("_capteurs") as Array
	for v in 2:
		var ligne := []
		for c in 2:
			var cap = capteurs[v][c]
			if cap == null or not is_instance_valid(cap):
				ligne.append(-1.0)
				continue
			var img: Image = (cap as SubViewport).get_texture().get_image()
			var mx := 0.0
			var somme := 0.0
			for y in img.get_height():
				for x in img.get_width():
					var p := img.get_pixel(x, y)
					var l := 0.2126 * p.r + 0.7152 * p.g + 0.0722 * p.b
					mx = maxf(mx, l)
					somme += l
			ligne.append([mx, somme])
		sortie.append(ligne)
	return sortie


func _ecrire_prise(img: Image, cle: String) -> void:
	if img == null:
		printerr("  ✗ prise %s perdue" % cle)
		return
	img.convert(Image.FORMAT_RGB8)
	var chemin := ProjectSettings.globalize_path("%s/%s.png" % [_dossier, cle])
	img.save_png(chemin)
	print("PRISE %s %dx%d %s" % [cle, img.get_width(), img.get_height(), chemin])


## Les joueurs tenus en place et en vie à chaque image (recopié de `photo_essais.gd`, branche claude/cloud-essais).
func _tenir() -> void:
	if not is_instance_valid(_main.p1) or not is_instance_valid(_main.p2):
		return
	_main.p1.global_position = _j1
	_viser(0, _visee_j1)
	if _j2_present:
		_main.p2.global_position = _j2
		_viser(1, _visee_j2)
	else:
		_main.p2.global_position = _j1 + Vector2(0.0, 4000.0)
		_viser(1, Vector2.RIGHT)
	if _pantins.size() > 1:
		_pantins[0].torche = _torches_allumees
		_pantins[1].torche = _torches_allumees and _j2_present
	if not (_torches_allumees and _j2_present):
		Input.action_release("p2_torch")
		_main.p2.flashlight_on = false
	if not _torches_allumees:
		Input.action_release("p1_torch")
		_main.p1.flashlight_on = false
	_vivants()
