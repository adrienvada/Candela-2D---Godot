extends "res://tools/photo_ecart.gd"

## LE JUMEAU PAR LE DEMI-TOUR, SUR IMAGE — une séance du photographe, héritière de `photo_ecart.gd` (graine, repos en images
## de jeu, LED figées, congé de l'intro), pour les décors corrigés par la session cloud « décor demi-tour » (2026-09-28).
## Aucun défaut ne change.
##
## Chaque scène est en ÉCRAN SCINDÉ, lacet 45° B (le défaut) : J1 à gauche, J2 à droite, J2 posé au DEMI-TOUR de J1 et
## visant à l'opposé — il regarde donc, depuis le côté opposé, la place jumelle de celle que regarde J1. Chaque prise est
## TRIPLE, au même instant, jeu en pause : A (le décor), B (le décor retiré), A' (le décor remis). A − B, dans chaque moitié,
## c'est ce que chaque joueur voit du décor ; A − A', le bruit du protocole. Puis la même scène torches éteintes : aucun
## pixel noir de B ne doit s'allumer en A ni en A'.
##
## Les scènes, sur l'Arène Standard (32 × 32 : le demi-tour de la case (x, y) est (31 − x, 31 − y)) :
##   pochoirs — J1 devant « ZONE 1 » (8, 23), J2 devant sa place jumelle (23, 8) : « ZONE 2 » après correction, rien avant ;
##   cadres   — J1 devant le « DEATHMATCH » nord et son cadre (15,5, 6), J2 devant le jumeau (15,5, 25) ; bascule du sol
##              marqué entier (les marques du cône, cadre compris) ;
##   tuyaux   — J1 devant la face sud du mur d'enceinte nord, J2 devant la face nord du mur sud : meublée après correction,
##              nue avant.
##
##     xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . res://tools/photo_demi_tour.tscn -- \
##         --no-eos --led-murs-fige --pochoirs-essai --sol-marque-essai --tuyaux-essai --sortie=user://demi-tour/apres
##
## `docs/iso/cloud/decor-demi-tour/lancer.sh` fait les deux lancements (avant : un arbre de travail à la base ; après : la
## branche) ; `mesurer.py` mesure et monte la planche.

const CARTE_STANDARD := "res://assets/maps/default.json"
## [J1 en cases, visée de J1, bascule].
const SCENES := {
	"pochoirs": [Vector2(8, 20.4), Vector2.DOWN, "pochoirs"],
	"cadres": [Vector2(15.5, 8.6), Vector2.UP, "marques"],
	"tuyaux": [Vector2(16, 5.6), Vector2.UP, "tuyaux"],
}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	seed(int(_valeur(args, "--graine", "20260928")))
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la planche du demi-tour exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	for drapeau in ["--pochoirs-essai", "--sol-marque-essai", "--tuyaux-essai"]:
		if not args.has(drapeau):
			printerr("✗ lancer avec %s : sans lui, le décor n'est pas posé et A = B" % drapeau)
			_sortir(1)
			return
	_dossier = _valeur(args, "--sortie", "user://demi-tour")
	_scenes = _valeur(args, "--scenes", "pochoirs,cadres,tuyaux").split(",")
	_sans_hud = true
	_carte_duel = CARTE_STANDARD
	_zoom = 1.0
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== Le jumeau par le demi-tour ===")
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
	await _passer_sur_la_carte_des_murs_bas()
	var reglages := get_node_or_null(^"/root/GameSettings")
	print("  lacets : J1 %s° · J2 %s°" % [str(reglages.call("lacet_de", 0)), str(reglages.call("lacet_de", 1))]
		if reglages != null else "  ! pas de réglages")
	var decor := _decor()
	if decor != null:
		print("  pochoirs posés : %d · marques posées : %d" % [(decor.get("_pochoirs") as Array).size(),
			(decor.get("_marques") as Array).size()])
	var iso := Presentation3D.instance()
	print("  tuyaux : %s" % ("un nœud" if iso != null and iso.get("_noeud_tuyaux") != null else "aucun nœud"))
	_deux_vues()
	for nom in _scenes:
		if not SCENES.has(nom):
			continue
		var j1: Vector2 = SCENES[nom][0]
		var visee: Vector2 = SCENES[nom][1]
		# J2 au demi-tour de J1 sur la Standard ((x, y) → (31 − x, 31 − y)), visée retournée.
		_poser(_px(j1), visee, _px(Vector2(31.0 - j1.x, 31.0 - j1.y)), -visee)
		print("SCENE %s : J1 %s · J2 %s" % [nom, str(_j1), str(_j2)])
		await _trois_prises(nom, String(SCENES[nom][2]), true)
		await _trois_prises(nom + "_noir", String(SCENES[nom][2]), false)
	_vue_unique()
	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


func _px(cases: Vector2) -> Vector2:
	return (cases + Vector2(0.5, 0.5)) * float(CandelaTileSet.TILE_SIZE.x)


func _decor() -> Node:
	return _main.arena.get_node_or_null("ArenaDecor") if is_instance_valid(_main.arena) else null


## Pose ou retire le décor de la scène, jeu en pause. Pochoirs et marques : recuits dans le décor, la peinture iso reprise à
## la main (son `_process` est arrêté par la pause). Tuyaux : le nœud montré ou caché.
func _basculer(bascule: String, avec: bool) -> void:
	if bascule == "tuyaux":
		var iso := Presentation3D.instance()
		var noeud: Node3D = iso.get("_noeud_tuyaux") if iso != null else null
		if noeud == null:
			printerr("  ✗ pas de nœud de tuyaux : bascule impossible")
			return
		noeud.visible = avec
	else:
		var decor := _decor()
		if decor == null:
			printerr("  ✗ pas de décor : bascule impossible")
			return
		if bascule == "pochoirs":
			await decor.poser_pochoirs(avec)
		else:
			await decor.poser_marques(avec)
		for n in get_tree().root.find_children("*", "SubViewport", true, false):
			if n.get_script() == preload("res://peinture_iso.gd"):
				n._process(0.0)
	await _attendre_images(4)


## A, B, A' au même instant (voir l'en-tête), en écran scindé.
func _trois_prises(nom: String, bascule: String, allumees: bool) -> void:
	_torches_allumees = allumees
	_torches(allumees)
	for i in REPOS_IMAGES:
		_tenir()
		await get_tree().process_frame
	_tenir()
	get_tree().paused = true
	await _attendre_images(3)
	_ecrire_prise(await _capturer("ecran"), nom + "_A")
	await _basculer(bascule, false)
	_ecrire_prise(await _capturer("ecran"), nom + "_B")
	await _basculer(bascule, true)
	_ecrire_prise(await _capturer("ecran"), nom + "_A2")
	get_tree().paused = false
	_torches_allumees = true
	_torches(true)
