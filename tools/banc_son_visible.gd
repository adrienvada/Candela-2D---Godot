extends SceneTree

## Le banc d'images du son rendu visible (chantier SON VISIBLE, 0.8.0).
##
## Monte une vraie partie en écran scindé (vue iso, 45° B), pose des sons par
## l'entonnoir d'`AudioManager` — le chemin du jeu, `GameState` compris — et
## photographie la fenêtre. Adrien juge sur image : c'est pour lui.
##
## Exige une VRAIE fenêtre (sous Linux : `xvfb-run`). Ne rejoint aucune suite.
##
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 \
##       --script res://tools/banc_son_visible.gd -- --sortie=/chemin/absolu
##
## Chaque plan écrit `<sortie>/<nom>.png` et une ligne dans `<sortie>/plans.txt`.

const SV := preload("res://son_visible.gd")

var _sortie := "user://son_visible"
var _main: Node
var _audio: Node
var _plans: PackedStringArray = []


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			_sortie = a.trim_prefix("--sortie=")
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_sortie)
	await process_frame
	_audio = root.get_node("AudioManager")
	_main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	var reseau := root.get_node("NetworkManager")
	_main.ui._intended_mode = int(reseau.get_script().get_script_constant_map()["GameMode"]["LOCAL_SPLITSCREEN"])
	_main._on_replay_requested()
	if not await _depart_fini():
		printerr("la manche n'a pas démarré")
		quit(1)
		return
	# Quelques images pour que la vue iso, la peinture et les lumières se posent.
	for i in 30:
		await process_frame
	await _plans_du_banc()
	var f := FileAccess.open(_sortie.path_join("plans.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_plans) + "\n")
	print("banc_son_visible : %d plans dans %s" % [_plans.size(), _sortie])
	quit(0)


func _depart_fini() -> bool:
	var fin := Time.get_ticks_msec() + 8000
	while not (_main.round_active and _main.countdown_left > 0.0):
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	_main.countdown_left = 0.001
	while _main.countdown_left > 0.0:
		if Time.get_ticks_msec() > fin:
			return false
		await physics_frame
	return true


func _vues() -> Array:
	return _main._sons_vues


func _vider() -> void:
	for v in _vues():
		v.vider()


## Fige chaque liseré vivant au sommet de sa vie (la fin de l'attaque), et arrête son
## vieillissement le temps de la photo.
##
## ⚠️ **Sous Xvfb, une image dure bien plus que le liseré ne vit à son sommet.** Le
## premier jet attendait 0,14 s de minuteur : le rendu logiciel mettait plusieurs
## dixièmes par image, et les liserés photographiés étaient déjà presque éteints —
## on aurait jugé leur couleur sur une traîne.
func _figer() -> void:
	for v in _vues():
		for t in v._traces:
			t["age"] = SV.ATTAQUE_S
		v.set_process(false)
		v._toile.queue_redraw()


func _photo(nom: String, legende: String) -> void:
	_figer()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var chemin := _sortie.path_join(nom + ".png")
	img.save_png(chemin)
	var traces := "J1 %d · J2 %d" % [_vues()[0].traces_vivantes(), _vues()[1].traces_vivantes()] \
		if _vues().size() == 2 else ""
	_plans.append("%s\t%s\t%s" % [nom, legende, traces])
	print("  plan ", nom, " — ", legende, " (", traces, ")")


func _p1() -> Node2D:
	return _main.p1


func _p2() -> Node2D:
	return _main.p2


## Un pas de J2 (émetteur 1) à `decalage` de J1, à l'allure donnée.
func _pas_de_j2(decalage: Vector2, allure := 1.0, accroupi := false) -> void:
	_audio.play_footstep(_p1().global_position + decalage, Vector2i(0, 0), accroupi, allure, 1)


func _plans_du_banc() -> void:
	var p1 := _p1()
	var p2 := _p2()
	# J2 se tient loin de J1 pendant tout le banc : c'est lui qui « fait » les bruits,
	# mais les sons sont posés aux points voulus, pas à sa place.
	var origine := p1.global_position

	# 1 — Le pas de course, tout près : l'ancre des 10°.
	_vider()
	_pas_de_j2(Vector2(140, -40))
	await _photo("son_01_course_pres", "J2 court à 145 px de J1 : le liseré le plus précis (≈10-14°), couleur sable")

	# 2 — Le même pas, loin.
	_vider()
	_pas_de_j2(Vector2(560, -300))
	await _photo("son_02_course_loin", "le même pas de course à 635 px : plus large, plus léger")

	# 3 — Mi-stick, distance moyenne.
	_vider()
	_pas_de_j2(Vector2(300, 120), 0.5)
	await _photo("son_03_mi_stick", "J2 marche à mi-stick à 320 px : moins de bruit, liseré plus large (Q47)")

	# 4 — Accroupi, tout près : le bruissement.
	_vider()
	_pas_de_j2(Vector2(-90, 60), 1.0, true)
	await _photo("son_04_accroupi_pres", "J2 accroupi à 110 px : 180°, à peine visible — « un bruissement »")

	# 5 — Derrière un mur : la part occultée forcée à 1 (le banc émet hors image de
	# physique, où le jeu ne sonde pas les murs).
	_vider()
	var ev := {"famille": "footstep_a", "pos": origine + Vector2(140, -40), "emetteur": 1,
		"niveau_db": SV.NIVEAU_NET_DB, "portee": _audio.portee_courante("footstep_a"),
		"fumee_db": 0.0, "wet": float(_audio.reverb_courante().get("wet", 0.3)),
		"diagonale": _audio.portee_carte()}
	_vues()[0].recevoir(ev, p1, 1.0)
	await _photo("son_05_derriere_un_mur", "le pas du plan 1, derrière un mur : plus large, plus doux, plus léger")

	# 6 — Le code couleur : une sorte par direction, à même distance.
	_vider()
	var sortes := [
		["footstep_a", 0.0], ["wall_brush", 0.0], ["shoot", 0.0], ["weapon_dry", 0.0],
		["weapon_reload_pistolet", 0.0], ["shell", 0.0], ["wall_impact", 0.0], ["ricochet", 0.0],
		["hit_center", 0.0], ["fusee_atterrit", 0.0],
	]
	for i in sortes.size():
		var angle := TAU * float(i) / float(sortes.size())
		var ou := origine + Vector2.RIGHT.rotated(angle) * 260.0
		_audio.annoncer_son_2d(String(sortes[i][0]), ou, 1)
	await _photo("son_06_code_couleur",
		"le code couleur, dix sortes à 260 px : pas, frôlement, tir, percuteur, rechargement, douille, impact, ricochet, corps, fusée")

	# 7 — Une fusillade : trop de sons, les bords deviennent chaotiques (Q48).
	_vider()
	_audio.play_weapon_shot("fusil", origine + Vector2(420, -150), 1)
	for k in 5:
		_audio.play_wall_impact(origine + Vector2(-200 + 60 * k, 260 + 15 * k))
	_audio.play_ricochet(origine + Vector2(-380, -60))
	_audio.play_ricochet(origine + Vector2(-320, -140))
	_audio.play_hit(origine + Vector2(30, 180), 0.2)
	_pas_de_j2(Vector2(250, 280))
	_pas_de_j2(Vector2(-150, -330), 0.6)
	await _photo("son_07_fusillade", "une fusillade : un tir, cinq impacts, deux ricochets, un coup au but, deux pas")

	# 8 — L'équité, en miroir : J1 entend J2 et J2 entend J1, à la même distance.
	_vider()
	var d := Vector2(220, -90)
	p2.global_position = origine + d
	for i in 3:
		await physics_frame
	_audio.play_footstep(p2.global_position, Vector2i(0, 0), false, 1.0, 1)
	_audio.play_footstep(p1.global_position, Vector2i(0, 0), false, 1.0, 0)
	await _photo("son_08_equite_miroir",
		"miroir : J1 entend le pas de J2, J2 celui de J1 — même largeur, même angle à l'écran (45° B)")

	# 9 — En vue unique (le cas du jeu en ligne) : la fusillade, plein écran.
	_main.vp2.get_parent().hide()
	_main._accorder_rendu_aux_vues()
	for i in 5:
		await process_frame
	_vider()
	_audio.play_weapon_shot("pistolet", origine + Vector2(500, 200), 1)
	_audio.play_ricochet(origine + Vector2(-420, -100))
	_audio.play_wall_impact(origine + Vector2(-300, 240))
	_pas_de_j2(Vector2(200, -250))
	_pas_de_j2(Vector2(-120, 90), 1.0, true)
	await _photo("son_09_vue_unique", "vue unique (en ligne) : tir, ricochet, impact, un pas, un pas accroupi")
