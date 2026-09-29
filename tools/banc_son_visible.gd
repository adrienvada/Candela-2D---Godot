extends SceneTree

## Le banc d'images du son rendu visible (chantier SON VISIBLE, 0.8.0).
##
## Monte une vraie partie en écran scindé (vue iso, 45° B), pose des sons par
## l'entonnoir d'`AudioManager` — le chemin du jeu, `GameState` compris — et
## photographie la fenêtre. Adrien juge sur image : c'est pour lui.
##
## Exige une VRAIE fenêtre (sous Linux : `xvfb-run`). Ne rejoint aucune suite.
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 \
##       --script res://tools/banc_son_visible.gd -- --sortie=/chemin/absolu [--seulement=...]
##
## `--seulement=plans|vies|fusillade|solo|video` n'en fait qu'un (défaut : plans, vies,
## fusillade et solo ; la vidéo, longue, se demande). Chaque plan écrit
## `<sortie>/<nom>.png` et une ligne dans `<sortie>/plans.txt`.
##
## ## La VIE d'un liseré (Adrien, 2026-09-29 : « il faudrait que les liserés s'animent en
## ## fonction du son »)
##
## `vies` photographie huit instants d'un même liseré — un tir en grande salle (et le même
## dans un sas), un pas de course, un pas accroupi, un rechargement — en vue unique, et écrit
## `<sortie>/vies.json` : pour chaque scénario, les instants (âge, opacité, largeur, niveau
## perçu) et la courbe entière. `video` écrit les images de ces vies à 60 par seconde (la cadence du jeu), dans
## `<sortie>/video_<scénario>/`, pour qu'un script les monte.
##
## ⚠️ **Sous Xvfb une image dure bien plus longtemps qu'un sommet de liseré** : le premier jet
## du banc attendait un minuteur, et les liserés photographiés étaient déjà presque éteints.
## L'âge de chaque trace se pose donc À LA MAIN (`_poser_age`), et le vieillissement est arrêté
## le temps de la photo.
##
## ## Le mélange (Q52, Adrien : « on additionne les liserés en couleur pour qu'ils virent au
## ## blanc ? »)
##
## `fusillade` photographie les mêmes sons figés, en mélange normal puis en mélange additif ;
## `solo` un liseré seul sur le noir de l'arène, puis sur un aplat clair posé derrière, dans
## les deux mélanges — de quoi dire ce que l'addition change à un liseré seul.

const SV := preload("res://son_visible.gd")

## Où les sons du banc se posent, à l'écran de J1 (degrés ; 0 = à droite, négatif = vers le haut) :
## hors de la ligne de visée, tireté gris qui traverse l'écran et se lirait comme un dessous non noir.
const ANGLE_BANC := -12.0

var _sortie := "user://son_visible"
var _seulement := ""
var _main: Node
var _audio: Node
var _plans: PackedStringArray = []
var _vies: Array = []


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			_sortie = a.trim_prefix("--sortie=")
		elif a.begins_with("--seulement="):
			_seulement = a.trim_prefix("--seulement=")
	call_deferred("_run")


func _fait(quoi: String) -> bool:
	if _seulement == "":
		return quoi != "video"
	return _seulement == quoi


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
	if _fait("plans"):
		await _plans_du_banc()
	if _fait("vies") or _fait("video") or _fait("fusillade") or _fait("solo"):
		await _vue_unique()
	if _fait("vies") or _fait("video"):
		await _vies_du_banc(_fait("video"))
	if _fait("fusillade"):
		await _fusillade_avant_apres()
	if _fait("solo"):
		await _solo_noir_et_eclaire()
	var f := FileAccess.open(_sortie.path_join("plans.txt"), FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_plans) + "\n")
	if not _vies.is_empty():
		var g := FileAccess.open(_sortie.path_join("vies.json"), FileAccess.WRITE)
		if g != null:
			g.store_string(JSON.stringify(_vies, "\t"))
	print("banc_son_visible : %d plans, %d vies dans %s" % [_plans.size(), _vies.size(), _sortie])
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


## Une seule vue, plein écran : le cas du jeu en ligne, et celui où un liseré se lit le mieux.
## Le HUD est retiré des prises de ce mode — il n'a rien à dire d'un son.
func _vue_unique() -> void:
	_main.vp2.get_parent().hide()
	_main._accorder_rendu_aux_vues()
	_main.ui.visible = false
	for i in 8:
		await process_frame


## L'âge où une trace est à son plus fort : le sommet de sa vie, celui qu'on veut photographier.
## Cherché sur toute la vie, à 5 ms — un pas retardé de 110 ms a son sommet à 110 ms, un tir à 0.
func _age_du_sommet(t: Dictionary) -> float:
	var meilleur := 0.0
	var age_meilleur := 0.0
	var age := 0.0
	while age < float(t["duree"]):
		var e := SV.etat(t, age)
		if not e.is_empty() and float(e["alpha"]) > meilleur + 0.0001:
			meilleur = float(e["alpha"])
			age_meilleur = age
		age += 0.005
	return age_meilleur


## Fige chaque liseré vivant à son sommet, et arrête son vieillissement le temps de la photo.
func _figer() -> void:
	for v in _vues():
		for t in v._traces:
			t["age"] = _age_du_sommet(t)
		v.set_process(false)
		v._toile.queue_redraw()


## Pose l'âge de toutes les traces, et arrête leur vieillissement.
func _poser_age(age: float) -> void:
	for v in _vues():
		for t in v._traces:
			t["age"] = age
		v.set_process(false)
		v._toile.queue_redraw()


## Émet un son au temps réel — le pitch d'une voix se multiplie par `Engine.time_scale` — puis
## arrête le temps du jeu : l'arène ne bouge plus d'une image à l'autre, et seul le liseré,
## dont on pose l'âge à la main, change entre deux photos.
func _emettre(quoi: Callable) -> void:
	Engine.time_scale = 1.0
	quoi.call()
	Engine.time_scale = 0.0


func _capture() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _photo(nom: String, legende: String) -> void:
	_figer()
	var img := await _capture()
	img.save_png(_sortie.path_join(nom + ".png"))
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


## L'événement qu'`AudioManager` annoncerait pour un pas de course de J2 en `pos`, à la main : le
## banc le donne à `recevoir` avec la part occultée qu'il veut (il émet hors image de physique,
## où le jeu ne sonde pas les murs).
func _evenement_de_pas(pos: Vector2) -> Dictionary:
	var salle: Dictionary = _audio.reverb_courante()
	return {"famille": "footstep_a", "pos": pos, "emetteur": 1,
		"niveau_db": SV.NIVEAU_NET_DB, "portee": _audio.portee_courante("footstep_a"),
		"fumee_db": 0.0, "wet": float(salle.get("wet", 0.3)),
		"room_size": float(salle.get("room_size", 0.15)), "damping": float(salle.get("damping", 0.22)),
		"chemin": _audio.chemin_variante("footstep_a", 1), "pitch": 1.0,
		"diagonale": _audio.portee_carte()}


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
	_vues()[0].recevoir(_evenement_de_pas(origine + Vector2(140, -40)), p1, 1.0)
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
	_fusillade(origine)
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
	await _vue_unique()
	_main.ui.visible = true
	_vider()
	_audio.play_weapon_shot("pistolet", origine + Vector2(500, 200), 1)
	_audio.play_ricochet(origine + Vector2(-420, -100))
	_audio.play_wall_impact(origine + Vector2(-300, 240))
	_pas_de_j2(Vector2(200, -250))
	_pas_de_j2(Vector2(-120, 90), 1.0, true)
	await _photo("son_09_vue_unique", "vue unique (en ligne) : tir, ricochet, impact, un pas, un pas accroupi")
	_main.ui.visible = false


## La fusillade des plans 7 et de l'avant/après : un tir, cinq impacts, deux ricochets, un
## coup au but, deux pas.
func _fusillade(origine: Vector2) -> void:
	_audio.play_weapon_shot("fusil", origine + Vector2(420, -150), 1)
	for k in 5:
		_audio.play_wall_impact(origine + Vector2(-200 + 60 * k, 260 + 15 * k))
	_audio.play_ricochet(origine + Vector2(-380, -60))
	_audio.play_ricochet(origine + Vector2(-320, -140))
	_audio.play_hit(origine + Vector2(30, 180), 0.2)
	_pas_de_j2(Vector2(250, 280))
	_pas_de_j2(Vector2(-150, -330), 0.6)


# =============================================================================
# LA VIE D'UN LISERÉ
# =============================================================================

## Un point du monde dont l'angle à l'écran, vu de J1, est celui demandé (radians, 0 = à
## droite). En vue iso l'angle du monde n'est plus celui de l'écran : on le mesure par la
## projection même de la vue, comme le fait le liseré.
func _point_a_l_angle(angle_ecran: float, distance: float) -> Vector2:
	var v = _vues()[0]
	var origine := _p1().global_position
	var meilleur := Vector2.RIGHT
	var ecart_min := INF
	for i in 360:
		var dir := Vector2.RIGHT.rotated(deg_to_rad(float(i)))
		var a := SV.angle_a_l_ecran(v._a_l_ecran(origine), v._a_l_ecran(origine + dir * 100.0))
		var e := absf(angle_difference(a, angle_ecran))
		if e < ecart_min:
			ecart_min = e
			meilleur = dir
	return origine + meilleur * distance


func _salle(nom: String) -> void:
	var grille := Vector2i(15, 15) if nom == "sas" else Vector2i(45, 45)
	_audio.appliquer_reverb_carte(_audio.calculer_reverb_carte(grille, CandelaTileSet.TILE_SIZE))


## Les scénarios d'une vie : un son précis (fichier et pitch fixés : la vie se compare d'un
## jour à l'autre), une salle, un point d'écoute.
func _scenarios() -> Array:
	var accroupi_db: float = _audio.get_script().get_script_constant_map()["PAS_ACCROUPI_DB"]
	var accroupi_portee: float = _audio.get_script().get_script_constant_map()["PAS_ACCROUPI_PORTEE"]
	return [
		{"nom": "tir_hangar", "salle": "hangar", "distance": 520.0,
			"legende": "un coup de pistolet à 520 px, dans un HANGAR (45×45) : il claque, décroît, puis la salle le prolonge et l'ouvre",
			"jouer": func(pos: Vector2): _audio.play_sfx_2d(_audio.chemin_tir("pistolet", 1), pos, 1.0, 0.0, "SFX", 1)},
		{"nom": "tir_sas", "salle": "sas", "distance": 520.0,
			"legende": "le même coup de pistolet, dans un SAS (15×15) : sec, il s'éteint avec le son",
			"jouer": func(pos: Vector2): _audio.play_sfx_2d(_audio.chemin_tir("pistolet", 1), pos, 1.0, 0.0, "SFX", 1)},
		{"nom": "pas_course", "salle": "hangar", "distance": 150.0,
			"legende": "un pas de course à 150 px : un bref coup sourd, après ~100 ms de silence — la salle ne le prolonge pas",
			"jouer": func(pos: Vector2): _audio.play_sfx_2d(_audio.chemin_variante("footstep_a", 1), pos, 1.0, 0.0, "SFX", 1)},
		{"nom": "pas_accroupi", "salle": "hangar", "distance": 110.0,
			"legende": "un pas ACCROUPI à 110 px : 180°, « un bruissement », et presque aussitôt éteint",
			"jouer": func(pos: Vector2): _audio.play_sfx_2d(_audio.chemin_variante("footstep_a", 1), pos, 1.0, accroupi_db, "SFX", 1, accroupi_portee)},
		{"nom": "recharge", "salle": "hangar", "distance": 260.0,
			"legende": "un rechargement de pistolet à 260 px : le froissement ne se voit pas, ses CLICS oui",
			"jouer": func(pos: Vector2): _audio.play_sfx_2d("weapon_reload_pistolet", pos, 1.0, 0.0, "SFX", 1)},
	]


## Huit instants d'un même liseré, du premier visible au dernier, plus sa courbe entière.
func _vies_du_banc(avec_video: bool) -> void:
	print("\n--- La vie d'un liseré ---")
	var garde: Dictionary = _audio.reverb_courante().duplicate()
	for sc in _scenarios():
		_salle(String(sc["salle"]))
		_vider()
		var pos := _point_a_l_angle(deg_to_rad(ANGLE_BANC), float(sc["distance"]))
		_emettre(func(): (sc["jouer"] as Callable).call(pos))
		var v = _vues()[0]
		if v.traces_vivantes() != 1:
			printerr("  ✗ %s : %d liserés (1 attendu)" % [sc["nom"], v.traces_vivantes()])
			continue
		var t: Dictionary = v._traces[0]
		# La courbe entière, à 10 ms, et les instants où quelque chose se voit.
		var courbe: Array = []
		var visibles: Array = []
		var age := 0.0
		while age < float(t["duree"]):
			var e := SV.etat(t, age)
			if not e.is_empty():
				courbe.append([snappedf(age, 0.001), snappedf(float(e["alpha"]), 0.001), snappedf(float(e["largeur"]), 0.1),
					snappedf(float(e["epaisseur"]), 0.1), snappedf(float(e.get("niveau", 0.0)), 0.1), snappedf(float(e.get("diffus", 0.0)), 0.001)])
				if float(e["alpha"]) > 0.01:
					visibles.append(age)
			age += 0.01
		# Huit instants pris parmi les VISIBLES, à égale distance : un rechargement dont le
		# froissement ne se voit pas ne gaspille pas la moitié de la planche dans le noir.
		var instants: Array = []
		var n := 8
		for i in n:
			var a: float = visibles[int(round(float(i) * float(visibles.size() - 1) / float(n - 1)))]
			_poser_age(a)
			var img := await _capture()
			var fichier := "vie_%s_%d.png" % [sc["nom"], i]
			img.save_png(_sortie.path_join(fichier))
			var e := SV.etat(t, a)
			instants.append({"image": fichier, "age": snappedf(a, 0.001), "alpha": snappedf(float(e["alpha"]), 0.001),
				"largeur": snappedf(float(e["largeur"]), 0.1), "niveau": snappedf(float(e["niveau"]), 0.1),
				"diffus": snappedf(float(e["diffus"]), 0.001)})
		var entree := {"nom": sc["nom"], "legende": sc["legende"], "salle": sc["salle"], "duree": t["duree"],
			"pic_alpha": t["alpha"], "largeur_pic": t["largeur"], "instants": instants, "courbe": courbe}
		_vies.append(entree)
		print("  vie ", sc["nom"], " — ", sc["legende"], " (", snappedf(float(t["duree"]), 0.01), " s)")
		if avec_video:
			await _images_de_video(String(sc["nom"]), t, float(t["duree"]))
		Engine.time_scale = 1.0
	_audio.appliquer_reverb_carte(garde)
	_vider()


## Les images d'une vie à 60 par seconde, réduites en 1280×720, pour qu'un script les monte.
func _images_de_video(nom: String, t: Dictionary, duree: float) -> void:
	var dossier := _sortie.path_join("video_" + nom)
	DirAccess.make_dir_recursive_absolute(dossier)
	var n := int(ceil((duree + 0.10) * 60.0))
	for k in n:
		var age := float(k) / 60.0
		# Passé son terme il n'y a plus de liseré : les dernières images montrent l'arène nue.
		_poser_age(minf(age, duree - 0.001))
		if age >= duree:
			for v in _vues():
				v._traces.clear()
				v._toile.queue_redraw()
		var img := await _capture()
		img.resize(1280, 720, Image.INTERPOLATE_BILINEAR)
		img.save_png(dossier.path_join("f_%04d.png" % k))
	print("    ", n, " images dans ", dossier)


# =============================================================================
# LE MÉLANGE — Q52
# =============================================================================

## La fusillade, figée aux sommets, en mélange normal puis en mélange additif : les mêmes
## sons, les mêmes instants, seul le mélange change.
func _fusillade_avant_apres() -> void:
	print("\n--- Fusillade : mélange normal contre addition ---")
	var origine := _p1().global_position
	# Le fond seul, sans aucun liseré : ce qui permet de compter ce que les liserés changent.
	_vider()
	Engine.time_scale = 0.0
	var vide := await _capture()
	vide.save_png(_sortie.path_join("fusillade_fond.png"))
	# Deux fusillades : celle du plan 7, éparpillée autour de J1, et une DENSE, où tout arrive de
	# la même direction — c'est là que les couleurs s'additionnent vraiment.
	for cas in [["fusillade", "la fusillade du plan 7", func(): _fusillade(origine)],
			["fusillade_dense", "une fusillade dense, tout arrive du même côté", func(): _fusillade_dense()]]:
		_vider()
		_emettre(cas[2] as Callable)
		_figer()
		for additif in [false, true]:
			for v in _vues():
				v.poser_melange(additif)
			var img := await _capture()
			var nom := "%s_%s" % [cas[0], "addition" if additif else "melange"]
			img.save_png(_sortie.path_join(nom + ".png"))
			_plans.append("%s\t%s, en mélange %s\t%s" % [nom, cas[1], "ADDITIF" if additif else "normal",
				"J1 %d" % _vues()[0].traces_vivantes()])
			print("  plan ", nom, " (", _vues()[0].traces_vivantes(), " liserés)")
	for v in _vues():
		v.poser_melange(true)
	Engine.time_scale = 1.0
	_vider()


## Une fusillade DENSE : un tir de fusil, cinq impacts, deux ricochets et un coup au but, tous dans
## un secteur de 40° à l'écran (vers la droite, un peu au-dessus de la ligne de visée).
func _fusillade_dense() -> void:
	var a := deg_to_rad(ANGLE_BANC)
	_audio.play_weapon_shot("fusil", _point_a_l_angle(a - deg_to_rad(8.0), 420.0), 1)
	for k in 5:
		_audio.play_wall_impact(_point_a_l_angle(a + deg_to_rad(-18.0 + 9.0 * float(k)), 330.0 + 40.0 * float(k)))
	_audio.play_ricochet(_point_a_l_angle(a - deg_to_rad(14.0), 300.0))
	_audio.play_ricochet(_point_a_l_angle(a + deg_to_rad(14.0), 380.0))
	_audio.play_hit(_point_a_l_angle(a + deg_to_rad(4.0), 260.0), 0.2, 1)


## Un liseré seul, sur l'arène telle quelle puis sur un aplat opaque posé DERRIÈRE lui (sous la
## couche des liserés) — noir, lueur (18 %), béton bien éclairé (36 %) —, dans les deux
## mélanges, plus le fond seul de chacun : de quoi calculer ce que l'addition change.
## Sur du noir elle ne change rien (`dessous + couleur × alpha`, dessous nul) ; sur une zone
## éclairée elle AJOUTE au lieu de recouvrir, donc éclaircit de `dessous × alpha`.
##
## La source est posée à -12° de l'horizontale, hors de la ligne de visée (un tireté gris qui
## traverse l'écran de part en part et se lirait comme un dessous non noir).
func _solo_noir_et_eclaire() -> void:
	print("\n--- Un liseré seul : noir de l'arène, puis zone éclairée ---")
	var garde: Dictionary = _audio.reverb_courante().duplicate()
	_salle("hangar")
	var calque := CanvasLayer.new()
	calque.name = "AplatClair"
	calque.layer = 4
	root.add_child(calque)
	var aplat := ColorRect.new()
	aplat.set_anchors_preset(Control.PRESET_FULL_RECT)
	aplat.visible = false
	calque.add_child(aplat)
	var consts: Dictionary = _audio.get_script().get_script_constant_map()
	var cas := [
		["tir", "un coup de pistolet à 520 px", func(pos: Vector2): _audio.play_sfx_2d(_audio.chemin_tir("pistolet", 1), pos, 1.0, 0.0, "SFX", 1), 520.0],
		["pas_accroupi", "un pas accroupi à 110 px", func(pos: Vector2): _audio.play_sfx_2d(_audio.chemin_variante("footstep_a", 1), pos, 1.0,
			consts["PAS_ACCROUPI_DB"], "SFX", 1, consts["PAS_ACCROUPI_PORTEE"]), 110.0],
		# Un liseré large à cheval sur le COIN de l'écran : l'addition doublerait-elle la couture entre
		# deux rayons ? (Un pas derrière un mur, dans la direction du coin haut-droit.)
		["coin", "un pas derrière un mur, plein coin haut-droit", func(pos: Vector2): _vues()[0].recevoir(_evenement_de_pas(pos), _p1(), 1.0), 250.0, -24.8],
	]
	# L'arène telle quelle (le jeu dessous : ce qu'on verrait), puis un aplat OPAQUE qui la cache :
	# noir pur (la preuve de calcul : `dessous + couleur × alpha`, dessous nul), une lueur, un béton
	# éclairé par une lampe (gris chaud).
	var fonds := [["arene", -1.0], ["noir", 0.0], ["lueur", 0.18], ["eclaire", 0.36]]
	for c in cas:
		for fond in fonds:
			aplat.visible = float(fond[1]) >= 0.0
			aplat.color = Color(1.0, 0.89, 0.75) * maxf(float(fond[1]), 0.0)
			# Le fond seul, sans aucun liseré.
			_vider()
			Engine.time_scale = 0.0
			var vide := await _capture()
			vide.save_png(_sortie.path_join("solo_%s_%s_fond.png" % [c[0], fond[0]]))
			for additif in [false, true]:
				_vider()
				for v in _vues():
					v.poser_melange(additif)
				var ou := _point_a_l_angle(deg_to_rad(float(c[4]) if c.size() > 4 else ANGLE_BANC), float(c[3]))
				_emettre(func(): (c[2] as Callable).call(ou))
				_figer()
				var img := await _capture()
				var nom := "solo_%s_%s_%s" % [c[0], fond[0], "addition" if additif else "melange"]
				img.save_png(_sortie.path_join(nom + ".png"))
				_plans.append("%s\t%s\t%s" % [nom, "%s, fond %s (%.0f %%), mélange %s" % [c[1], fond[0], 100.0 * float(fond[1]),
					"additif" if additif else "normal"], "J1 %d" % _vues()[0].traces_vivantes()])
				print("  plan ", nom)
	for v in _vues():
		v.poser_melange(true)
	Engine.time_scale = 1.0
	calque.queue_free()
	_audio.appliquer_reverb_carte(garde)
	_vider()
