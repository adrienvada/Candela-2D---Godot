extends "res://tools/photographe.gd"

## LA PEINTURE ISO PÉRIMÉE, PAR LES CHEMINS DU JEU — une séance du photographe (session cloud « peinture périmée »,
## 2026-09-28). Aucun défaut du jeu ne change.
##
## Le défaut (RAPPORT sol-marque-2 § 1) : `presentation_3d.gd` refait ses murs quand `rebuild_arena()` rappelle le crochet
## vue allumée, pas sa peinture (`_poser_peinture`, posée par `_allumer`). Ce banc ne pose AUCUNE carte à la main : il
## passe par les gestes du joueur — une manche en écran scindé local lancée depuis le menu, J2 abattu, l'écran de fin, puis
## le chemin demandé (`--chemin=`) :
##   carte        — CHANGER DE CARTE (la vignette de la galerie, `MapGallery._on_tile_pressed`), puis REJOUER (le bouton du
##                  cadre, `panel_launch`) : la manche suivante sur une autre carte ;
##   revanche     — REJOUER seul : la même carte, la tache de sang de la manche d'avant au sol ;
##   entrainement — le retour de la liste (`MenuHub.back`, l'accueil sans repasser par le menu principal), puis
##                  ENTRAÎNEMENT (`_on_hub_action("entrainement")`) : la carte par défaut ;
##   direct       — la carte d'arrivée choisie dans le menu, puis JOUER : la référence, sans écran de fin.
## `--depart=<id>` (par défaut le Cloître, `map_001`) et `--arrivee=<id>` (par défaut la Croisée, `map_003`).
##
## À l'arrivée, torches éteintes, J1 et J2 à la mise en scène du duel du photographe sur la carte d'arrivée, trois prises
## de l'écran (`ecran`, l'écran tel que le joueur le voit) :
##   A  — le jeu tel que le chemin l'a laissé ;
##   B  — la peinture refaite à la main (`Presentation3D._poser_peinture`, le geste de `_allumer`), dix images plus tard ;
##   B2 — dix images encore après B : le bruit entre deux prises identiques.
## Les trois au même instant de jeu : l'arbre est en pause de A à B2.
## `--fin=temps` finit la première manche au chronomètre (match nul, sans killcam) au lieu d'abattre J2.
## `A` contre `B` compte ce que la peinture périmée allume ; `B` contre `B2`, le bruit. Avec la correction, A = B.
## La ligne `PEINTURE` du journal donne la taille de la peinture que les murs lisent, contre celle de la carte posée.
##
##     GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . \
##         res://tools/photo_peinture_perimee.tscn -- --no-eos --led-murs-fige --chemin=carte --sortie=user://pp/carte
##
## Il EXIGE une vraie fenêtre, comme le photographe.

const CHEMINS := ["carte", "revanche", "entrainement", "direct"]

var _chemin := "carte"
## Comment finit la première manche : `kill` (J2 abattu, gel et killcam) ou `temps` (le chronomètre à zéro, match nul).
var _fin := "kill"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	seed(int(_valeur(args, "--graine", "20260928")))
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la séance exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	_chemin = _valeur(args, "--chemin", "carte")
	if not CHEMINS.has(_chemin):
		printerr("✗ --chemin=%s inconnu (%s)" % [_chemin, ", ".join(CHEMINS)])
		_sortir(1)
		return
	_fin = _valeur(args, "--fin", "kill")
	_dossier = _valeur(args, "--sortie", "user://pp/%s" % _chemin)
	var depart := _valeur(args, "--depart", "map_001")
	var arrivee := _valeur(args, "--arrivee", "map_003")
	if _chemin == "entrainement":
		arrivee = MapData.DEFAULT_MAP_ID
	_sans_hud = true
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== La peinture périmée — chemin %s, fin %s ===" % [_chemin, _fin])
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
	_main.archiver_les_matchs = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	# L'intro en planches d'un user:// neuf couvrirait chaque prise : congédiée (piège payé deux fois la nuit du 27/09).
	for enfant in _main.get_children():
		if enfant.get_script() == preload("res://intro_planches.gd"):
			enfant.emit_signal("terminee")
	await _traiter_l_allumage([] as Array[Dictionary])

	# --- La première manche, lancée depuis le menu comme un joueur : l'écran 1v1 local, la carte, JOUER.
	_ui.hub.reset()
	_ui.hub.push(_ui.SCREEN_LOCAL)
	var premiere := arrivee if _chemin == "direct" else depart
	if not MapData.select_map(premiere):
		printerr("✗ carte %s introuvable" % premiere)
		_sortir(1)
		return
	_main._on_replay_requested()
	if not await _manche_prete():
		return
	_journal("manche 1 (%s)" % MapData.selected_map_id)

	if _chemin != "direct":
		# --- J2 abattu : la séquence de fin du jeu (gel, killcam, écran de fin), sans la piloter.
		_torches(true)
		for i in 20:
			_vivants()
			await get_tree().process_frame
		if _fin == "temps":
			# La fin au temps : le chronomètre du jeu mené à son terme (`_process` → `_do_end_round(-1)`), sans kill ni
			# killcam — le match nul des cinq minutes, raccourci.
			_main.time_left = 0.05
		else:
			_main.p2.take_damage(9999.0, _main.p1)
		if not await _attendre(func() -> bool: return _main.game_over and _ui.game_over_panel.visible, 90.0):
			printerr("✗ l'écran de fin n'est jamais venu")
			_sortir(1)
			return
		await _attendre_images(10)
		if is_instance_valid(_main._affiche_de_fin) and _main._affiche_de_fin.est_active():
			_main._affiche_de_fin.congedier()
			await _attendre(func() -> bool: return not (is_instance_valid(_main._affiche_de_fin)
				and _main._affiche_de_fin.est_active()), 10.0)
		await _attendre_images(10)
		_journal("écran de fin (écran du hub : %s)" % _ui.hub.current_id())
		match _chemin:
			"carte":
				var entree = _ui._entree_changer_carte.get(_ui.hub.current_id(), null)
				if not (entree is Button and is_instance_valid(entree) and entree.is_visible_in_tree()):
					printerr("✗ pas d'entrée CHANGER DE CARTE sur l'écran de fin (%s)" % _ui.hub.current_id())
					_sortir(1)
					return
				_ui.hub.reveal_entry(entree)
				await _attendre_images(5)
				_ui.map_gallery._on_tile_pressed(arrivee)
				await _attendre_images(5)
				_journal("carte choisie à l'écran de fin : %s" % MapData.selected_map_id)
				_ui.panel_launch.emit_signal("pressed")
			"revanche":
				_ui.panel_launch.emit_signal("pressed")
			"entrainement":
				_ui.hub.back()
				await _attendre_images(5)
				_journal("retour à l'accueil (écran du hub : %s)" % _ui.hub.current_id())
				_ui._on_hub_action("entrainement")
				await _attendre(func() -> bool: return _main.training_mode and _main.sandbox_mode, 30.0)
		if not await _manche_prete():
			return
		_journal("manche 2 (%s)" % MapData.selected_map_id)

	# --- La mise en scène, torches éteintes, puis A / B / B2.
	_torches(false)
	var data: Dictionary = MapData.get_selected()
	_scene_duel = _mise_en_scene_du_duel(data)
	var t := float(CandelaTileSet.TILE_SIZE.x)
	var p1: Vector2 = _scene_duel["p1"]
	var p2 := p1 + Vector2(0.6 * t, -2.6 * t)
	print("  mise en scène : %s · J1 %s · J2 %s" % [_scene_duel.get("mur", "?"), str(p1), str(p2)])
	await _tenir_pendant(30, p1, p2)
	var iso := Presentation3D.instance()
	if iso == null or not bool(iso.get("_actif")):
		printerr("✗ la vue iso n'est pas allumée à l'arrivée : rien à mesurer")
		_sortir(1)
		return
	# Jeu en pause pour les trois prises : rien ne bouge entre elles (ni le chronomètre, ni le souffle des corps, ni les
	# LED). La peinture neuve se rend quand même : sa sous-vue est en `UPDATE_ONCE` dès sa création.
	get_tree().paused = true
	await _attendre_images(3)
	await _prise("A")
	# Le coût du geste que la correction ajoute à chaque reconstruction : le temps de `_poser_peinture` (processeur du
	# cloud : un ordre de grandeur, pas une mesure de cadence) et les appels de dessin des images qui suivent, contre
	# ceux des images d'avant (jeu en pause : rien d'autre ne change).
	var avant: Array[int] = []
	for i in 3:
		await get_tree().process_frame
		avant.append(_appels_de_dessin())
	var t0 := Time.get_ticks_usec()
	iso.call("_poser_peinture")
	var duree := Time.get_ticks_usec() - t0
	var apres: Array[int] = []
	for i in 6:
		await get_tree().process_frame
		apres.append(_appels_de_dessin())
	print("COUT _poser_peinture : %d µs (processeur du cloud) · appels de dessin par image, avant %s, après %s"
		% [duree, str(avant), str(apres)])
	await _attendre_images(4)
	_journal("peinture refaite à la main")
	await _prise("B")
	await _attendre_images(10)
	await _prise("B2")
	get_tree().paused = false
	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


## Attend que la manche tourne et que le décompte soit fini, puis reprend les commandes (le démarrage d'une manche repose
## les fournisseurs d'entrées du mode).
func _manche_prete() -> bool:
	# L'entraînement n'arme pas de manche (`_on_training_requested` : `round_active` faux, bac à sable, aucun décompte).
	if _main.training_mode and _main.sandbox_mode:
		_prendre_les_commandes()
		await _attendre_images(10)
		return true
	if not await _attendre(func() -> bool: return _main.round_active or (_main.training_mode and _main.sandbox_mode), 30.0):
		printerr("✗ la manche n'a jamais démarré")
		_sortir(1)
		return false
	_prendre_les_commandes()
	if not await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 30.0):
		printerr("✗ le décompte n'a jamais fini")
		_sortir(1)
		return false
	_prendre_les_commandes()
	await _attendre_images(10)
	return true


func _tenir_pendant(images: int, p1: Vector2, p2: Vector2) -> void:
	for i in images:
		_placer(p1, p2)
		await get_tree().process_frame
	_placer(p1, p2)


func _placer(p1: Vector2, p2: Vector2) -> void:
	for pantin in _pantins:
		pantin.visee = Vector2.UP
	if is_instance_valid(_main.p1):
		_main.p1.global_position = p1
		_main.p1.velocity = Vector2.ZERO
		_main.p1.rotation = Vector2.UP.angle()
	if is_instance_valid(_main.p2):
		_main.p2.global_position = p2
		_main.p2.velocity = Vector2.ZERO
		_main.p2.rotation = Vector2.RIGHT.angle()
	for j in [_main.p1, _main.p2]:
		if is_instance_valid(j):
			j.flashlight_on = false
	_vivants()


func _prise(nom: String) -> void:
	var img: Image = await _capturer("ecran")
	if img == null:
		printerr("  ✗ prise %s perdue" % nom)
		_perdues += 1
		return
	var chemin := ProjectSettings.globalize_path("%s/%s.png" % [_dossier, nom])
	img.convert(Image.FORMAT_RGB8)
	img.save_png(chemin)
	print("PRISE %s %s (%dx%d)" % [_chemin, nom, img.get_width(), img.get_height()])


## L'état de la vue iso et de sa peinture, face à la carte posée : la preuve que le chemin a été suivi vue allumée.
func _journal(etape: String) -> void:
	var iso := Presentation3D.instance()
	var actif := iso != null and bool(iso.get("_actif"))
	var peinture: SubViewport = iso.peinture() if iso != null else null
	var grille := Vector2(MapCodec.get_grid_size(MapData.get_selected())) * float(CandelaTileSet.TILE_SIZE.x)
	var mat: ShaderMaterial = iso.get("_mat_mur") if iso != null else null
	print("PEINTURE %s : vue iso %s (bascules %d), %s · peinture %s, cadre %s, id %s · lue par les murs %s · carte posée %s px"
		% [etape, "allumée" if actif else "éteinte", int(iso.get("bascules")) if iso != null else -1,
		iso.raison_des_vues() if iso != null else "?",
		str(peinture.size) if peinture != null else "aucune", str(peinture.cadre) if peinture != null else "-",
		str(peinture.get_instance_id()) if peinture != null else "-",
		str(mat.get_shader_parameter("peinture_taille_px")) if mat != null else "?", str(grille)])


func _appels_de_dessin() -> int:
	return int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
