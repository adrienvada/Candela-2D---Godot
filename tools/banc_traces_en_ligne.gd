## LES TRACES EN LIGNE — deux instances ENet, sans rendu (session cloud « restes », 2026-09-28).
##
## Le banc de « Peinture périmée » (`banc_peinture_en_ligne.gd`), dont la mise à mort passe par de VRAIS tirs de l'hôte
## (le sang naît des balles ; `take_damage` n'en dépose pas) : l'hôte ouvre un salon local (ENet) sur le Cloître,
## l'invité le rejoint, J1 abat J2, l'écran de fin ; l'hôte y choisit la Croisée (CHANGER DE CARTE), REJOUER des deux
## côtés. `--revanche` : l'hôte ne change pas de carte. À chaque étape, chaque instance imprime une ligne `TRACES` : les
## traces vivantes dans SON arène, par groupe. Le verdict (`VERDICT`) : combien de traces de la manche 1 restent sous la
## manche 2.
##
##     CANDELA_PORT=24124 godot --headless --path . res://tools/banc_traces_en_ligne.tscn -- --hote &
##     CANDELA_PORT=24124 godot --headless --path . res://tools/banc_traces_en_ligne.tscn -- --invite
## (`docs/iso/cloud/restes/en_ligne.sh` lance les deux.)
extends Node

const DEPART := "map_001"
const ARRIVEE := "map_003"
const GROUPES := ["blood_stain", "blood_p2", "wall_impact", "wall_impact_p2", "bullet_casing", "casing_p2"]
var _main: Node
var _ui: Node
var _hote := false
var _echecs := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_hote = args.has("--hote")
	var revanche := args.has("--revanche")
	NetworkManager.transport = NetworkManager.Transport.ENET
	GameSettings.mode_iso = true
	MapData.select_map(DEPART)
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node("UI")
	_main.archiver_les_matchs = false
	for enfant in _main.get_children():
		if enfant.get_script() == preload("res://intro_planches.gd"):
			enfant.emit_signal("terminee")
	var qui := "HÔTE" if _hote else "INVITÉ"
	print("=== LA PEINTURE EN LIGNE — %s, port %d ===" % [qui, NetworkManager.DEFAULT_PORT])
	_ui.hub.push(_ui.SCREEN_LOCAL_HOST if _hote else _ui.SCREEN_LOCAL_JOIN)
	await _images(3)
	if _hote:
		_ui._open_lobby()
	else:
		MapData.select_map("default")
		_ui.join_input.text = "127.0.0.1"
		_ui.join_requested.emit()
	if not await _attendre(func() -> bool: return not multiplayer.get_peers().is_empty(), 60.0):
		return _fin("aucun pair")
	await _attendre_secondes(1.0)
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active and _main.countdown_left <= 0.0, 60.0):
		return _fin("la manche 1 n'a pas démarré")
	await _images(10)
	_journal("manche 1")
	_traces("manche 1")
	if _hote:
		await _attendre_secondes(1.0)
		await _abattre_j2()
	if not await _attendre(func() -> bool: return _main.game_over and not _main._end_sequence_active, 90.0):
		return _fin("l'écran de fin n'est jamais venu")
	if is_instance_valid(_main._affiche_de_fin):
		_main._affiche_de_fin.congedier()
	await _images(10)
	_journal("écran de fin")
	var avant := _traces("écran de fin")
	if _hote and not revanche:
		var entree = _ui._entree_changer_carte.get(_ui.hub.current_id(), null)
		print("  entrée CHANGER DE CARTE sur l'écran de fin (%s) : %s" % [_ui.hub.current_id(),
			entree is Button and is_instance_valid(entree) and entree.is_visible_in_tree()])
		if entree is Button:
			_ui.hub.reveal_entry(entree)
		await _images(3)
		_ui.map_gallery._on_tile_pressed(ARRIVEE)
		await _images(3)
		_journal("carte choisie par l'hôte à l'écran de fin")
		await _attendre_secondes(2.0)
	_main._on_replay_requested()
	var attendue := DEPART if revanche else ARRIVEE
	var manche_2 := func() -> bool: return _main.round_active and MapData.selected_map_id == attendue \
			and _main.countdown_left <= 0.0
	if not await _attendre(manche_2, 60.0):
		return _fin("la manche 2 n'a pas démarré sur %s (carte %s)" % [attendue, MapData.selected_map_id])
	await _images(10)
	_journal("manche 2")
	var apres := _traces("manche 2")
	print("VERDICT %s : %s → %s ; %d traces de la manche 1 (sur %d) restent sous la manche 2" % [qui, DEPART,
		MapData.selected_map_id, _originaux(apres), _originaux(avant)])
	await _attendre_secondes(3.0)
	_fin("")


## Imprime l'état ; rend vrai si la peinture en place est cadrée sur la carte posée.
func _journal(etape: String) -> bool:
	var iso := Presentation3D.instance()
	var peinture: SubViewport = iso.peinture() if iso != null else null
	var tuile := Vector2(CandelaTileSet.TILE_SIZE)
	var grille := Vector2(MapCodec.get_grid_size(MapData.get_selected()))
	var attendu := Rect2(-tuile, (grille + Vector2(2, 2)) * tuile)
	var bonne: bool = peinture != null and peinture.cadre == attendu
	print("PEINTURE %s %s : vue iso %s (bascules %d), %s · peinture %s · carte %s, cadre attendu %s → %s" % [
		"HÔTE" if _hote else "INVITÉ", etape,
		"allumée" if iso != null and bool(iso.get("_actif")) else "éteinte",
		int(iso.get("bascules")) if iso != null else -1, iso.raison_des_vues() if iso != null else "?",
		str(peinture.cadre) if peinture != null else "aucune", MapData.selected_map_id, str(attendu),
		"à jour" if bonne else "PÉRIMÉE"])
	return bonne


func _attendre(predicat: Callable, plafond: float) -> bool:
	var fin := Time.get_ticks_msec() + int(plafond * 1000.0)
	while Time.get_ticks_msec() < fin:
		if predicat.call():
			return true
		await get_tree().process_frame
	return false


func _attendre_secondes(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _images(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _fin(raison: String) -> void:
	if raison != "":
		printerr("✗ ", raison)
		_echecs += 1
	NetworkManager.disconnect_from_game()
	await _images(2)
	get_tree().quit(1 if _echecs > 0 else 0)


## Les traces vivantes dans l'arène de cette instance (les copies de la peinture iso, hors de l'arène, non comptées).
func _traces(etape: String) -> Dictionary:
	var n := {}
	for g in GROUPES:
		var k := 0
		for t in get_tree().get_nodes_in_group(g):
			if t.get_parent() == _main.arena:
				k += 1
		n[g] = k
	print("TRACES %s %s : %s" % ["HÔTE" if _hote else "INVITÉ", etape, str(n)])
	return n


func _originaux(n: Dictionary) -> int:
	return int(n.get("blood_stain", 0)) + int(n.get("wall_impact", 0)) + int(n.get("bullet_casing", 0))


## L'hôte, autoritaire, fait tirer J1 sur J2 posé à 160 px devant lui, et recharge une fois (une douille).
func _abattre_j2() -> void:
	var p1: Node2D = _main.p1
	var p2: Node2D = _main.p2
	p1.current_ammo = 0
	p1.start_reload()
	await _attendre_secondes(0.5)
	var fin := Time.get_ticks_msec() + 8000
	while not p2.dead and Time.get_ticks_msec() < fin:
		p1.hp = 100.0
		p2.global_position = p1.global_position + Vector2.from_angle(p1.rotation) * 160.0
		if p1.shoot_cooldown <= 0.0:
			p1.current_ammo = maxi(p1.current_ammo, 1)
			p1.shoot()
		await get_tree().physics_frame
	print("  J2 %s sous les balles de l'hôte" % ("abattu" if p2.dead else "TOUJOURS DEBOUT"))
