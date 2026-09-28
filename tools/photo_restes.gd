extends "res://tools/photo_peinture_perimee.gd"

## LES TRACES D'UNE CARTE À L'AUTRE, PAR LES GESTES DU JOUEUR — une séance du photographe (session cloud « restes »,
## 2026-09-28). Aucun défaut du jeu ne change.
##
## La question (RAPPORT peinture-perimee § 5.1) : `blood_stain.gd` garde les taches « le match entier, rematch
## compris ; seul le retour au menu principal les balaie ». L'écran de fin permet pourtant de CHANGER DE CARTE sans y
## repasser. Les traces de la carte d'avant restent-elles sur la suivante, et où ?
##
## Le banc ne pose AUCUNE trace à la main : une manche en écran scindé local lancée depuis le menu sur `--depart`
## (le Cloître), J1 tire de vrais coups — une salve dans le mur le plus proche (éclats), un rechargement (douille), puis
## sur J2 jusqu'à sa mort (le sang naît des BALLES : `take_damage` n'en dépose pas) —, l'écran de fin, puis le chemin
## demandé (`--chemin=`, ceux de `photo_peinture_perimee.gd`) : `carte` (CHANGER DE CARTE vers `--arrivee`, REJOUER),
## `revanche` (REJOUER, la même carte), `entrainement` (retour, ENTRAÎNEMENT).
##
## À l'arrivée, les lignes `TRACES` comptent les traces vivantes par groupe, et `TRACE` dit, pour chaque original,
## où il tombe sur la NOUVELLE carte (sol, mur, muret, vide) et où il était sur l'ancienne. Puis J1 est posé à 70 px
## au sud de la première tache de sang tombée sur du sol, torche braquée dessus, jeu en pause, et trois prises de
## l'écran (`ecran`, interface comprise) :
##   A  — le jeu tel que le chemin l'a laissé ;
##   B  — les traces retirées à la main (le geste de la correction proposée), quelques images plus tard ;
##   B2 — dix images encore après B : le bruit.
## `A` contre `B` compte ce que les traces survivantes allument à l'écran.
##
##     GODOT_ARGS="--fixed-fps 60" xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . \
##         res://tools/photo_restes.tscn -- --no-eos --led-murs-fige --chemin=carte --sortie=user://restes/carte_iso
##     (ajouter `--2d` pour la vue de dessus)
##
## Il EXIGE une vraie fenêtre, comme le photographe.

## Les groupes des traces qui durent (originaux, puis copies de la vue de J2) — ceux de `peinture_iso.gd` (`TRACES`).
const GROUPES := ["blood_stain", "blood_p2", "wall_impact", "wall_impact_p2", "bullet_casing", "casing_p2"]
const ORIGINAUX := ["blood_stain", "wall_impact", "bullet_casing"]

var _carte_depart: Dictionary = {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	seed(int(_valeur(args, "--graine", "20260928")))
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ la séance exige une vraie fenêtre : ", refus)
		_sortir(1)
		return
	_chemin = _valeur(args, "--chemin", "carte")
	if not ["carte", "revanche", "entrainement"].has(_chemin):
		printerr("✗ --chemin=%s inconnu (carte, revanche, entrainement)" % _chemin)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://restes/%s" % _chemin)
	var depart := _valeur(args, "--depart", "map_001")
	var arrivee := _valeur(args, "--arrivee", "map_003")
	_sans_hud = true
	_taille = _lire_taille(_valeur(args, "--taille", "%dx%d" % [TAILLE_DEFAUT.x, TAILLE_DEFAUT.y]))
	print("=== Les restes — chemin %s, vue %s ===" % [_chemin, "de dessus" if GameSettings.mode_iso == false else "iso"])
	print("  drapeaux : %s" % " ".join(args))
	_poser_la_fenetre()
	await _lire_l_horloge()
	if _pas_fixe <= 0.0:
		printerr("✗ lancer avec --fixed-fps 60")
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
	# L'intro en planches d'un user:// neuf couvrirait chaque prise : congédiée.
	for enfant in _main.get_children():
		if enfant.get_script() == preload("res://intro_planches.gd"):
			enfant.emit_signal("terminee")
	await _traiter_l_allumage([] as Array[Dictionary])

	# --- La première manche, lancée depuis le menu comme un joueur : l'écran 1v1 local, la carte, JOUER.
	_ui.hub.reset()
	_ui.hub.push(_ui.SCREEN_LOCAL)
	if not MapData.select_map(depart):
		printerr("✗ carte %s introuvable" % depart)
		_sortir(1)
		return
	_carte_depart = MapData.get_selected().duplicate(true)
	_main._on_replay_requested()
	if not await _manche_prete():
		return
	print("MANCHE 1 : %s" % MapData.selected_map_id)

	# --- De vrais coups de feu.
	_torches(true)
	await _salve_dans_un_mur()
	await _recharger()
	if not await _abattre_j2():
		return
	_compter("après la mise à mort (%s)" % MapData.selected_map_id)

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
	_compter("écran de fin (écran du hub : %s)" % _ui.hub.current_id())
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
			print("  carte choisie à l'écran de fin : %s" % MapData.selected_map_id)
			_ui.panel_launch.emit_signal("pressed")
		"revanche":
			_ui.panel_launch.emit_signal("pressed")
		"entrainement":
			_ui.hub.back()
			await _attendre_images(5)
			_ui._on_hub_action("entrainement")
			await _attendre(func() -> bool: return _main.training_mode and _main.sandbox_mode, 30.0)
	if not await _manche_prete():
		return
	print("MANCHE 2 : %s" % MapData.selected_map_id)
	_journal("manche 2")
	_compter("manche 2 (%s)" % MapData.selected_map_id)
	var cible := _situer_les_traces()

	# --- La photographie : J1 à 70 px au sud de la tache, torche braquée dessus, J2 loin, torche éteinte.
	var data: Dictionary = MapData.get_selected()
	if cible == Vector2.INF:
		print("  aucune trace à photographier : prises sur la mise en scène du duel")
		cible = _mise_en_scene_du_duel(data)["p1"] + Vector2(0, -70)
	var p1 := cible + Vector2(0, 70)
	var p2: Vector2 = Vector2(MapCodec.get_spawn(data, 1)) * float(CandelaTileSet.TILE_SIZE.x)
	for pantin in _pantins:
		pantin.torche = false
	if not _pantins.is_empty():
		_pantins[0].torche = true
	Input.action_release("p2_torch")
	for i in 40:
		_poser(p1, p2)
		await get_tree().process_frame
	_poser(p1, p2)
	get_tree().paused = true
	await _attendre_images(3)
	await _prise("A")
	var retirees := _balayer()
	print("  traces retirées à la main : %d nœuds" % retirees)
	# Jeu en pause : la peinture iso (`peinture_iso.gd`) et l'usure des murs ne se refont qu'à leur `_process`, arrêté.
	# Sans ce geste, les murs divisent la lumière neuve par la peinture d'avant (le sang y est encore) et virent au vert :
	# un effet du banc, pas du jeu, qui tourne pendant qu'on retire.
	await _attendre_images(2)
	var iso := Presentation3D.instance()
	if iso != null and bool(iso.get("_actif")):
		var peinture: SubViewport = iso.peinture()
		if peinture != null:
			peinture.render_target_update_mode = SubViewport.UPDATE_ONCE
		iso.call("_suivre_usure")
	await _attendre_images(6)
	_compter("après le balayage à la main")
	await _prise("B")
	await _attendre_images(10)
	await _prise("B2")
	get_tree().paused = false
	AudioServer.set_bus_mute(0, _mute_avant)
	print("images : %s" % ProjectSettings.globalize_path(_dossier))
	_sortir(0)


## Trois coups dans le mur le plus proche : des éclats (`wall_impact.gd`). J2 est rangé derrière J1.
func _salve_dans_un_mur() -> void:
	_face_a_un_mur()
	var axe: Vector2 = _pantins[0].visee if not _pantins.is_empty() else Vector2.RIGHT
	for coup in 3:
		for i in 12:
			_main.p1.rotation = axe.angle()
			_main.p2.global_position = _main.p1.global_position - axe * 120.0
			_vivants()
			await get_tree().process_frame
		_main.p1.current_ammo = max(_main.p1.current_ammo, 1)
		_main.p1.shoot()
	await _attendre_images(20)


## Un rechargement : la douille tombe (`player.start_reload`, la seule source de douilles).
func _recharger() -> void:
	_main.p1.current_ammo = 0
	_main.p1.start_reload()
	for i in 60:
		_vivants()
		await get_tree().process_frame


## J1 tire sur J2 à 160 px jusqu'à sa mort. J1 reste en vie, J2 non (on ne remet pas ses points de vie).
func _abattre_j2() -> bool:
	var axe: Vector2 = Vector2.RIGHT
	var depart: Vector2 = _main.p1.global_position
	# Un axe libre : le premier des huit caps sans mur à 220 px.
	var espace: PhysicsDirectSpaceState2D = _main.p1.get_world_2d().direct_space_state
	for i in 8:
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
		var q := PhysicsRayQueryParameters2D.create(depart, depart + dir * 220.0, MapGeometry.WALL_LAYER)
		q.exclude = [_main.p1.get_rid(), _main.p2.get_rid()]
		if espace.intersect_ray(q).is_empty():
			axe = dir
			break
	for pantin in _pantins:
		pantin.visee = axe
	var reste := 6.0
	while reste > 0.0 and not _main.p2.dead:
		_main.p1.hp = 100.0
		_main.p1.rotation = axe.angle()
		_main.p2.global_position = depart + axe * 160.0
		if _main.p1.shoot_cooldown <= 0.0:
			_main.p1.current_ammo = max(_main.p1.current_ammo, 1)
			_main.p1.shoot()
		await get_tree().process_frame
		reste -= get_process_delta_time()
	if not _main.p2.dead:
		printerr("✗ J2 n'est pas mort sous les balles")
		_sortir(1)
		return false
	return true


func _poser(p1: Vector2, p2: Vector2) -> void:
	if is_instance_valid(_main.p1):
		_main.p1.global_position = p1
		_main.p1.velocity = Vector2.ZERO
		_main.p1.rotation = Vector2.UP.angle()
	if is_instance_valid(_main.p2):
		_main.p2.global_position = p2
		_main.p2.velocity = Vector2.ZERO
	for pantin in _pantins:
		pantin.visee = Vector2.UP
	_vivants()


func _compter(etape: String) -> void:
	var morceaux: Array[String] = []
	for g in GROUPES:
		morceaux.append("%s %d" % [g, get_tree().get_nodes_in_group(g).size()])
	var iso := Presentation3D.instance()
	var usure := "-"
	if iso != null and iso.get("_mat_mur") != null:
		usure = str((iso.get("_mat_mur") as ShaderMaterial).get_shader_parameter("usure_impacts_n"))
	print("TRACES %s : %s · impacts lus par les murs iso %s" % [etape, ", ".join(morceaux), usure])


## Où tombe chaque original sur la carte posée, et où il était sur la carte de départ. Rend la place de la première tache
## de sang tombée sur du sol (la cible des prises), ou `Vector2.INF`.
func _situer_les_traces() -> Vector2:
	var cible := Vector2.INF
	var bilan := {}
	for g in ORIGINAUX:
		for n in get_tree().get_nodes_in_group(g):
			var pos: Vector2 = (n as Node2D).global_position
			var ici := _case(MapData.get_selected(), pos)
			var avant := _case(_carte_depart, pos)
			print("TRACE %s %s : ici %s · sur la carte de départ %s" % [g, str(pos.round()), ici, avant])
			var cle := "%s:%s" % [g, ici]
			bilan[cle] = int(bilan.get(cle, 0)) + 1
			if g == "blood_stain" and ici == "sol" and cible == Vector2.INF:
				cible = pos
	print("BILAN %s" % str(bilan))
	return cible


func _case(data: Dictionary, pos: Vector2) -> String:
	var t := float(CandelaTileSet.TILE_SIZE.x)
	var c := Vector2i(floori(pos.x / t), floori(pos.y / t))
	if MapCodec.get_wall_cells(data).has(c):
		return "mur"
	if MapCodec.get_low_wall_cells(data).has(c):
		return "muret"
	if MapCodec.get_floor_cells(data).has(c):
		return "sol"
	return "vide"


## Le geste de la correction proposée, à la main : toutes les traces qui durent, originaux et copies, hors de l'arbre.
func _balayer() -> int:
	var n := 0
	for g in GROUPES:
		for trace in get_tree().get_nodes_in_group(g):
			trace.remove_from_group(g)
			if trace.get_parent() != null:
				trace.get_parent().remove_child(trace)
			trace.queue_free()
			n += 1
	return n
