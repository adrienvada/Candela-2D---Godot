extends "res://tools/photographe.gd"
## L'USINE VUE PAR CHAQUE JOUEUR, EN ISO À 45° B — la planche avant / après (2026-09-29).
##
## Adrien, 2026-09-29 : « Oui corrige l'usine » (ses blocs centraux de 3 cases, décalés d'une colonne, ne se répondaient pas dans le
## miroir gauche-droite : `tools/test_usine_symetrie.gd`). Cet outil montre la carte, telle que chacun la voit : le vrai `main.tscn`, en
## écran scindé (les deux vues iso, 45° B : J1 à 45°, J2 à 225°), sur la carte demandée — celle du dépôt, ou l'ancienne (`--carte=` : un
## chemin de fichier) —, J1 et J2 posés de part et d'autre de l'axe, sur la rangée 11, à égale distance de lui, chacun tourné vers le centre.
##
## ⚠️ **La lumière est celle du DÉBOGAGE, pas celle du jeu** : l'ambiance de la killcam (`Charte.NOIR` vers `Charte.ACIER` à 38 %),
## posée sur le `CanvasModulate` de l'arène, pour que la géométrie se voie. Dans le noir du jeu on ne verrait que les torches. Les
## torches sont éteintes.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --fixed-fps 60 --path . --resolution 1920x1080 res://tools/planche_usine.tscn -- \
##     --sortie=<dossier> --nom=apres [--carte=res://assets/maps/map_002_l_usine.json] [--tuile=9] [--ambiance=0.38] --led-murs-fige=0.5 --no-eos
##
## Écrit `<dossier>/<nom>_J1.png` et `<nom>_J2.png` (la vue entière de chaque joueur, à la résolution de la vue), et `<nom>_journal.json`.

const CARTE_DEFAUT := "res://assets/maps/map_002_l_usine.json"
const RANGEE := 11
const IMAGES_STABILISATION := 40
const IMAGES_REPOS := 6

var _nom := "usine"
var _ambiance := 0.38
var _tuile_j1 := 9
var _iso: Presentation3D
var _positions: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var refus := Commun.refus_headless()
	if refus != "":
		printerr("✗ planche_usine : ", refus)
		_sortir(1)
		return
	_dossier = _valeur(args, "--sortie", "user://usine")
	_nom = _valeur(args, "--nom", "usine")
	_ambiance = float(_valeur(args, "--ambiance", "0.38"))
	_tuile_j1 = int(_valeur(args, "--tuile", "9"))
	_carte_duel = _valeur(args, "--carte", CARTE_DEFAUT)
	_taille = _lire_taille(_valeur(args, "--taille", "1920x1080"))
	print("=== Planche de l'Usine : la carte vue par chaque joueur (%s) ===" % _carte_duel)
	_poser_la_fenetre()
	AudioServer.set_bus_mute(0, true)
	var intro_vue_avant: bool = GameSettings.intro_vue
	GameSettings.intro_vue = true
	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	GameSettings.intro_vue = intro_vue_avant
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	_main.rendu_racine_autorise = true
	_main.archiver_les_matchs = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dossier))
	var allumage := _main.get_node_or_null(^"PowerOn")
	if allumage != null and allumage.has_method("terminer"):
		allumage.terminer()
		await _attendre_disparition(allumage, 3.0)
	_ui.hub.reset()
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_main._on_replay_requested()
	if not await _attendre(func() -> bool: return _main.round_active, 120.0):
		printerr("✗ la manche n'a jamais démarré")
		_sortir(1)
		return
	_prendre_les_commandes()
	Engine.time_scale = 4.0
	var decompte_fini: bool = await _attendre(func() -> bool: return _main.countdown_left <= 0.0, 240.0)
	Engine.time_scale = 1.0
	if not decompte_fini:
		printerr("✗ le décompte n'a jamais fini")
		_sortir(1)
		return
	_torches(false)
	_sans_hud = true
	if _ui.match_hud != null:
		_ui.match_hud.hide()
	await _passer_sur_la_carte_des_murs_bas()
	_iso = Presentation3D.instance()
	if _iso == null or _iso.viewport_ecran(0) == null or _iso.viewport_ecran(1) == null:
		printerr("✗ les deux vues iso ne sont pas en place (écran scindé attendu)")
		_sortir(1)
		return
	var donnees: Dictionary = MapData.current_map_data
	var grille := MapCodec.get_grid_size(donnees)
	var t := float(CandelaTileSet.TILE_SIZE.x)
	# J1 et J2 s'échangent par le miroir gauche-droite (x → largeur − 1 − x) : la même distance à l'axe, la même rangée.
	_positions[0] = (Vector2(_tuile_j1, RANGEE) + Vector2(0.5, 0.5)) * t
	_positions[1] = (Vector2(grille.x - 1 - _tuile_j1, RANGEE) + Vector2(0.5, 0.5)) * t
	var modulateur := _main.arena.get_node_or_null("CanvasModulate") as CanvasModulate
	if modulateur != null:
		modulateur.color = Charte.NOIR.lerp(Charte.ACIER, _ambiance)
	print("  carte « %s » %d×%d, %d murs ; J1 en %s, J2 en %s ; lacet %s %s, zoom %s ; ambiance de débogage %.2f" % [
		String(donnees.get("name", "?")), grille.x, grille.y, MapCodec.get_wall_cells(donnees).size(), str(_positions[0]),
		str(_positions[1]), str(GameSettings.lacet_duel), GameSettings.option_lacet, str(_main.cam1.zoom), _ambiance])
	for j in [_main.p1, _main.p2]:
		(j.noise as FastNoiseLite).frequency = 0.0
	Engine.time_scale = 4.0
	await _laisser_passer(IMAGES_STABILISATION)
	Engine.time_scale = 1.0
	await _laisser_passer(IMAGES_REPOS)

	await RenderingServer.frame_post_draw
	var journal := {"carte": String(donnees.get("name", "?")), "chemin": _carte_duel, "commit": _commit(), "fenetre": [_taille.x, _taille.y],
		"zoom": _main.cam1.zoom.x, "lacet": GameSettings.lacet_duel, "option_lacet": GameSettings.option_lacet,
		"positions": [[_positions[0].x, _positions[0].y], [_positions[1].x, _positions[1].y]], "ambiance": _ambiance,
		"murs": MapCodec.get_wall_cells(donnees).size(), "sol": MapCodec.get_floor_cells(donnees).size(), "vues": {}}
	for k in 2:
		var img: Image = _iso.viewport_ecran(k).get_texture().get_image()
		var chemin := "%s/%s_J%d.png" % [_dossier, _nom, k + 1]
		img.save_png(chemin)
		journal["vues"]["J%d" % (k + 1)] = {"fichier": chemin.get_file(), "taille": [img.get_width(), img.get_height()]}
		print("  écrit %s (%dx%d)" % [chemin.get_file(), img.get_width(), img.get_height()])
	var f := FileAccess.open("%s/%s_journal.json" % [_dossier, _nom], FileAccess.WRITE)
	f.store_string(JSON.stringify(journal, "  "))
	f.close()
	_sortir(0)


## Les joueurs restent où on les a posés, chacun tourné vers le centre de la carte. Rappelé à CHAQUE image.
func _tenir() -> void:
	for k in 2:
		var j = _main.p1 if k == 0 else _main.p2
		j.global_position = _positions[k]
		j.velocity = Vector2.ZERO
		j.set("_dust_accum", -1.0e9)
		var vers := Vector2.RIGHT if k == 0 else Vector2.LEFT
		_viser(k, vers)
		j.global_rotation = vers.angle()
	_vivants()
	for cam in [_main.cam1, _main.cam2]:
		if is_instance_valid(cam):
			cam.reset_smoothing()


func _laisser_passer(n: int) -> void:
	for i in n:
		_tenir()
		await get_tree().process_frame
