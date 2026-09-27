extends "res://tools/photographe.gd"

## LES ESSAIS ÉTEINTS, SUR IMAGE — le photographe, une séance à lui, pour montrer à Adrien chaque essai derrière son drapeau
## (`--faisceau`, `--mannequin`, `--pochoirs-essai`, `--encre-essai`, `--tuyaux-essai`, `--corps-detaille`), éteint et
## allumé, au cadrage du jeu (fenêtre 1920×1080, zoom du duel, lacet par défaut 45° B). Il ne change aucun défaut.
##
## Un lancement = un état des drapeaux. Il prend, sur le Cloître (seule carte qui porte à la fois des pochoirs et des
## tuyaux), trois scènes, chacune torches allumées puis torches éteintes, jeu en pause au moment de la prise :
##   duel — J1 face au mur haut intérieur, J2 debout dans son cône, torche de côté ;
##   sol  — J1 devant le pochoir « ZONE 1 », J2 hors de la carte ;
##   mur  — J1 devant la face la plus meublée de tuyaux (règle de `photo_tuyaux.gd`), J2 hors de la carte.
##
## ⚠️ **Comparer deux lancements ne prouve rien d'emblée** (ROADMAP, usure, levier 1 : hasard des éclats, poussière de la
## torche, instant du gel). D'où trois gestes, et une preuve : la graine du hasard global posée avant le jeu (`--graine`),
## le repos compté en IMAGES de jeu (`--fixed-fps 60` obligatoire), les LED figées (`--led-murs-fige`, passé par le
## lanceur) ; et deux lancements TÉMOINS, sans essai, dont l'écart dit le bruit du protocole. Une mesure d'essai ne vaut
## que rapportée à ce bruit.
##
##     xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/photo_essais.tscn -- \
##         --no-eos --led-murs-fige --sortie=user://essais/temoin1 [--faisceau …]
##
## `docs/iso/cloud/essais/lancer.sh` fait tous les lancements ; `mesurer.py` compare et monte la planche.
## Il EXIGE une vraie fenêtre, comme le photographe.

const TuyauxIsoT := preload("res://tuyaux_iso.gd")
const CARTE_ESSAIS := "res://assets/maps/map_001_le_cloitre.json"
## Le pochoir visé sur le Cloître (`ArenaDecor.POCHOIRS_ESSAI["map_001"]`), en cases.
const POCHOIR_CASE := Vector2(8, 22)
## Le repos avant chaque prise, en images de jeu (1,5 s à 60 Hz) : la caméra et le regard convergent.
const REPOS_IMAGES := 90

var _j1 := Vector2.ZERO
var _visee_j1 := Vector2.UP
var _j2 := Vector2.ZERO
var _visee_j2 := Vector2.RIGHT
var _j2_present := true
var _torches_allumees := true


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	# Le hasard global rendu identique d'un lancement à l'autre, AVANT que le jeu n'existe.
	seed(int(_valeur(args, "--graine", "20260927")))
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la planche des essais exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://essais")
	_sans_hud = true
	_carte_duel = CARTE_ESSAIS
	_zoom = maxf(0.2, float(_valeur(args, "--zoom-photo", "1.0")))
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== La planche des essais ===")
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
	# L'intro en planches du tout premier lancement (conteneur neuf) couvrirait chaque prise : congédiée, comme l'allumage.
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
	await _passer_sur_la_carte_des_murs_bas()
	var reglages := get_node_or_null(^"/root/GameSettings")
	var lacet := float(reglages.call("lacet_de", 0)) if reglages != null else 0.0
	print("  lacet de J1 : %s° · zoom caméra : %s" % [str(lacet), str(_main.cam1.zoom.x)])

	var t := float(CandelaTileSet.TILE_SIZE.x)
	# --- duel
	var scene: Dictionary = _scene_duel
	if not scene.has("rect"):
		printerr("✗ le Cloître n'a pas de mur haut intérieur (%s)" % scene.get("mur", "?"))
		_sortir(1)
		return
	_j1 = scene["p1"]
	_visee_j1 = Vector2.UP
	_j2 = _j1 + Vector2(0.6 * t, -2.6 * t)
	_visee_j2 = Vector2.RIGHT
	_j2_present = true
	print("SCENE duel : %s · J1 %s · J2 %s" % [scene["mur"], str(_j1), str(_j2)])
	await _deux_prises("duel")

	# --- sol : le pochoir « ZONE 1 », J1 à 2,5 cases au sud, visée au nord (au nord si le sud est pris).
	var centre := (POCHOIR_CASE + Vector2(0.5, 0.5)) * t
	_j1 = centre + Vector2(0.0, 2.5 * t)
	_visee_j1 = Vector2.UP
	if not _sol_libre(_j1):
		_j1 = centre - Vector2(0.0, 2.5 * t)
		_visee_j1 = Vector2.DOWN
	_j2_present = false
	print("SCENE sol : pochoir %s · J1 %s · visée %s · sol libre %s" % [str(centre), str(_j1), str(_visee_j1),
		str(_sol_libre(_j1))])
	await _deux_prises("sol")

	# --- mur : la face la plus meublée de tuyaux (même choix que `photo_tuyaux.gd`, le cône à 20° de biais).
	var face := _choisir_la_face(MapData.current_map_data)
	if face.is_empty():
		printerr("  ! aucune face meublée : pas de scène mur")
	else:
		var n: Vector2 = face["n"]
		var tg := Vector2(-n.y, n.x)
		var milieu := (float(face["s0"]) + float(face["s1"])) * 0.5
		var pied := n * float(face["d"]) + tg * milieu
		_j1 = pied + n * (3.2 * t) + tg * 20.0
		_visee_j1 = (-n).rotated(deg_to_rad(20.0))
		print("SCENE mur : face %s (%d cases) · J1 %s" % [str(face["cle"]), int(face["cases"]), str(_j1)])
		await _deux_prises("mur")

	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


## La scène, torches allumées puis éteintes. Chaque prise : repos de `REPOS_IMAGES` images à tenir la scène, puis l'arbre en
## pause, trois images, la prise.
func _deux_prises(nom: String) -> void:
	for allumees in [true, false]:
		_torches_allumees = allumees
		_torches(allumees)
		for i in REPOS_IMAGES:
			_tenir()
			await get_tree().process_frame
		_tenir()
		get_tree().paused = true
		await _attendre_images(3)
		var img: Image = await _capturer("vue")
		get_tree().paused = false
		var cle := "%s_%s" % [nom, "allumees" if allumees else "eteintes"]
		if img == null:
			printerr("  ✗ prise %s perdue" % cle)
			continue
		img.convert(Image.FORMAT_RGB8)
		var chemin := ProjectSettings.globalize_path("%s/%s.png" % [_dossier, cle])
		img.save_png(chemin)
		print("PRISE %s %dx%d %s" % [cle, img.get_width(), img.get_height(), chemin])
	_torches_allumees = true
	_torches(true)


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


## La face à photographier : la règle de `photo_tuyaux.gd` (face sud intérieure, conduite et câbles d'abord).
func _choisir_la_face(data: Dictionary) -> Dictionary:
	var faces := TuyauxIsoT.faces(data)
	var grille := Vector2(MapCodec.get_grid_size(data)) * float(CandelaTileSet.TILE_SIZE.x)
	var rang_de := {1: 3, 3: 2, 0: 1, 2: 1}
	var meilleure := {}
	var meilleur := -1
	for f in faces:
		var n: Vector2 = f["n"]
		if n != Vector2(0, 1) or int(f["cases"]) < 3:
			continue
		var d := float(f["d"])
		if d < 4.0 * 35.0 or d > grille.y - 6.0 * 35.0:
			continue
		var rang := int(rang_de.get(TuyauxIsoT.programme_de(f), 0)) * 100 + int(f["cases"])
		if rang > meilleur:
			meilleur = rang
			meilleure = f
	return meilleure
