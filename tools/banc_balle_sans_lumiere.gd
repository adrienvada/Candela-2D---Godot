## Banc « la balle n'éclaire plus » — FENÊTRÉ (décision d'Adrien, 2026-09-15 vers 10:55).
##
## Adrien : « Supprimons le fait que la balle soit une source de lumière. Cela fait saturer le nombre de
## lumières possibles du moteur et fait buguer lors de tirs vifs avec une source comme une fusée
## éclairante. » Godot n'applique jamais plus de quinze lumières à un même `CanvasItem`, tout ou rien
## (« Pièges connus », « quinze par item ») ; chaque balle portait sa `PointLight2D`.
##
## La scène, identique avant et après : une fusée posée par le vrai chemin (`GameState._do_spawn_fusee`,
## puis plein feu), J1 à côté, et cinq balles tirées par le vrai chemin (`_do_spawn_bullet`) en rafale,
## qui frôlent la fusée. Quand les cinq sont en l'air :
##   - le RECENSEMENT des lumières `enabled` et visibles du duel, dont celles des balles ;
##   - la RONDEUR du halo de la fusée dans la lightmap de J1 : la valeur minimale sur la valeur maximale de
##     seize points pris sur un cercle autour d'elle (1 = rond ; un quadrant coupé la fait tomber) ;
##   - une capture de la fenêtre, `balle_<nom>.png`.
##
## Relevés : lignes `BANC_BALLE …`. Lancer :
##   godot --path . res://tools/banc_balle_sans_lumiere.tscn -- --captures <dossier> --nom avant|apres
extends Node

## Dans le halo plein feu, pas à son bord : à 110 px, les seize points étaient déjà noirs (premier passage).
const RAYON_RONDEUR := 60.0
const SEUIL := 10.0 / 255.0

var _main: Node
var _dossier := ""
var _nom := "capture"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--captures")
	_dossier = args[i + 1] if i >= 0 and i + 1 < args.size() \
		else ProjectSettings.globalize_path("res://docs/iso/captures_balle")
	var n := args.find("--nom")
	if n >= 0 and n + 1 < args.size():
		_nom = args[n + 1]
	DirAccess.make_dir_recursive_absolute(_dossier)
	GameSettings.pilotage_externe = true
	GameSettings.intro_vue = true
	GameSettings.mode_iso = true
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	AudioServer.set_bus_mute(0, true)
	print("=== Banc « la balle n'éclaire plus » (%s) ===" % _nom)

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	var ui := _main.get_node("UI")
	ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_main._on_replay_requested()
	var fin := Time.get_ticks_msec() + 20000
	while not (_main.round_active and _main.countdown_left <= 0.0):
		if Time.get_ticks_msec() > fin:
			printerr("  ✗ la manche n'a pas démarré")
			get_tree().quit(1)
			return
		await get_tree().process_frame
	ui.visible = false
	var p1 := _main.p1 as Node2D
	var p2 := _main.p2 as Node2D
	for p: Node2D in [p1, p2]:
		p.set_physics_process(false)
		p.set("velocity", Vector2.ZERO)
		p.set("dazzle_amount", 0.0)
	# La fusée posée à 120 px devant J1, plein feu.
	var centre := p1.global_position + Vector2(0.0, 120.0)
	_main._do_spawn_fusee(0, centre, 0.0, 4242)
	await _images(3)
	var fusee: Node2D = null
	for c in _main.bullet_container.get_children():
		if "_atterrie" in c and "graine" in c:
			fusee = c
	if fusee == null:
		printerr("  ✗ la fusée n'a pas été posée")
		get_tree().quit(1)
		return
	fusee.global_position = centre
	fusee.call("forcer_age", 0.5)
	await _images(30)
	_sauver(get_viewport().get_texture().get_image(), "balle_%s_fusee_seule" % _nom)
	var rondeur_seule := _rondeur(centre)
	# La rafale : cinq balles vers l'est, qui passent à 45 px de la fusée.
	# ⚠️ Depuis le sol dégagé devant J1 : le premier passage partait à 260 px à gauche de la fusée, DANS un
	# mur — les cinq balles y mouraient aussitôt, 0 en vol et 68 lumières d'étincelles d'impact.
	var depart := centre + Vector2(20.0, -45.0)
	for k in 5:
		_main._do_spawn_bullet(p1, depart, 0.0, p1.get("current_weapon"))
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var balles := 0
	var lumieres_balles := 0
	for c in _main.bullet_container.get_children():
		if "bounces_left" in c:
			balles += 1
			for l in (c as Node).find_children("*", "Light2D", true, false):
				if (l as Light2D).enabled and (l as Light2D).is_visible_in_tree():
					lumieres_balles += 1
	var actives := 0
	# Le recensement PAR FAMILLE (second volet, 2026-09-15 12:05) : le fichier qui crée la lumière (le
	# premier ancêtre qui porte un script), et le nom du nœud — « player.gd:MuzzleFlash »,
	# « particle_pool.gd:Light »… Un mécanisme plausible ne vaut rien tant qu'on n'a pas compté.
	var familles := {}
	for l in _main.find_children("*", "Light2D", true, false):
		if (l as Light2D).enabled and (l as Light2D).is_visible_in_tree():
			actives += 1
			var cle := "%s:%s" % [_fichier_createur(l as Node), _nom_sans_numero(l as Node)]
			familles[cle] = int(familles.get(cle, 0)) + 1
	var cles := familles.keys()
	cles.sort()
	for cle in cles:
		print("BANC_BALLE_FAMILLE nom=%s famille=%s lumieres=%d" % [_nom, cle, familles[cle]])
	var rondeur_rafale := _rondeur(centre)
	_sauver(get_viewport().get_texture().get_image(), "balle_%s_rafale" % _nom)
	print("BANC_BALLE nom=%s balles_en_vol=%d lumieres_actives=%d dont_balles=%d rondeur_fusee_seule=%.2f rondeur_pendant_rafale=%.2f" % [
		_nom, balles, actives, lumieres_balles, rondeur_seule, rondeur_rafale])
	GameSettings.mode_iso = false
	get_tree().quit(0)


## Min / max de la lightmap de J1 sur seize points d'un cercle autour de la fusée (1 = halo rond).
func _rondeur(centre: Vector2) -> float:
	var v: SubViewport = _main.vp1
	var img := v.get_texture().get_image()
	var xf: Transform2D = v.get_final_transform() * v.get_canvas_transform()
	var mini := INF
	var maxi := 0.0
	for k in 16:
		var p: Vector2 = xf * (centre + Vector2.RIGHT.rotated(TAU * k / 16.0) * RAYON_RONDEUR)
		if not Rect2(Vector2.ZERO, Vector2(img.get_size())).has_point(p):
			continue
		var c := img.get_pixel(int(p.x), int(p.y))
		var l := maxf(c.r, maxf(c.g, c.b))
		mini = minf(mini, l)
		maxi = maxf(maxi, l)
	return mini / maxi if maxi > SEUIL else 0.0


## Le fichier du premier nœud qui porte un script, en remontant depuis la lumière (elle-même comprise).
static func _fichier_createur(n: Node) -> String:
	var p := n
	while p != null:
		var s: Script = p.get_script()
		if s != null and s.resource_path != "":
			return s.resource_path.get_file()
		p = p.get_parent()
	return "?"


## Le nom du nœud sans le numéro qu'ajoute Godot aux homonymes (« @PointLight2D@123 » → « PointLight2D »).
static func _nom_sans_numero(n: Node) -> String:
	var nom := String(n.name)
	if nom.begins_with("@"):
		var morceaux := nom.split("@", false)
		return morceaux[0] if morceaux.size() > 0 else nom
	return nom


func _images(n: int) -> void:
	for k in n:
		await RenderingServer.frame_post_draw


func _sauver(img: Image, nom: String) -> void:
	img.save_png(_dossier.path_join(nom + ".png"))
