extends Node

## D'où viennent les pics ? — le banc qui explique le 1 % bas.
##
## ## Pourquoi il existe
##
## `bench_framerate` dit **combien** : 1 % bas à 43-60 sur six relevés du
## 2026-08-25, pour une cible à 60. Il ne dit pas **pourquoi**, et l'écart le
## demande : la **médiane** tient 115 à 123 fps pendant que le 1 % bas
## s'effondre à 45. Soixante-dix images par seconde d'écart entre le milieu et
## la queue, ce n'est pas une charge de fond — **c'est une poignée d'images
## isolées**, donc quelque chose de traçable plutôt qu'un coût diffus.
##
## Ce banc ne mesure donc pas une moyenne de plus : il **date** chaque image
## lente et **compare** ce qui se passait pendant, à ce qui se passe le reste du
## temps. Trois causes se distinguent par leur signature :
##
## | signature | cause probable |
## |---|---|
## | pics groupés au DÉBUT, puis plus rien | compilation de shader, première allocation |
## | pics corrélés aux tirs, appels de dessin en hausse | salves de particules |
## | pics réguliers, mémoire en dents de scie | allocation / ramassage |
## | pics sans corrélat, dispersés | le système d'exploitation, pas le jeu |
##
## ⚠️ **La distinction qui compte est « groupés au début » contre « étalés ».**
## Un pic de compilation se paie une fois par lancement et **jamais en match** ;
## un joueur ne le verra qu'à l'écran de chargement. Le confondre avec un coût
## permanent, c'est optimiser ce qui ne gêne personne — et `bench_framerate`
## les mélange dans un seul nombre, par construction.
##
## ## Le son
##
## ⚠️ **Coupé, et demandé nommément par Adrien.** Un banc qui joue un duel joue
## aussi ses tirs — seize voix, à plein volume, pendant quinze secondes, sur la
## machine de quelqu'un qui travaille à côté. Le bus `Master` est mis en sourdine
## **avant** d'instancier la scène **et re-vérifié après**, parce qu'`AudioManager`
## règle ses bus à son initialisation et écraserait un réglage posé trop tôt.
##
## Lancer : godot --path . res://tools/banc_pics.tscn -- [--seconds 20] [--vue-unique]

const WARMUP_SEC := 2.0
const DUEL_DISTANCE := 150.0
## Part des images considérées comme « lentes ». 1 % est la définition même de
## la métrique qu'on explique — en changer ferait répondre à une autre question.
const PART_LENTE := 0.01

var _main: Node
var _seconds := 20.0
var _vue_unique := false
var _t := 0.0

## Une ligne par image. On garde tout et on trie après : décider en cours de
## route quelle image est « lente » demanderait de connaître la distribution
## avant de l'avoir mesurée.
var _images: Array[Dictionary] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_seconds = float(_value(args, "--seconds", "20"))
	_vue_unique = args.has("--vue-unique")
	_couper_le_son("avant la scène")

	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("=== Banc des pics — d'où vient le 1 %% bas ===")

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_couper_le_son("après la scène")

	# ⚠️ **Séquence reprise MOT POUR MOT de `bench_framerate.gd`**, et pas
	# réinventée : mon premier jet appelait un `_main.start_game()` qui n'existe
	# pas. L'erreur a arrêté le script en laissant la fenêtre ouverte — un banc
	# qui pend sans rien mesurer, exactement le mode de défaillance que le
	# lanceur surveille depuis le 2026-08-16.
	var ui := _main.get_node("UI")
	ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_choisir_pompe(ui.p1_weapon_group)
	_choisir_pompe(ui.p2_weapon_group)
	_main._on_replay_requested()
	if not await _attendre(func(): return _main.round_active, 15.0):
		printerr("✗ la manche n'a pas démarré — relevé sans objet")
		get_tree().quit(1)
		return
	if _vue_unique:
		# Le geste exact de `_restore_viewports()` : cacher le conteneur, et
		# laisser `_accorder_rendu_aux_vues()` décider du rendu par la racine.
		# Arrêter le SubViewport à la main mesurerait un écran scindé amputé.
		_main.vp2.get_parent().hide()
		_main.ui.center_line.hide()
		_main._accorder_rendu_aux_vues()
		print("  vue unique : seconde vue fermée, rendu par la racine")

	print("Échauffement %.0f s (non mesuré) — il porte justement les compilations." % WARMUP_SEC)
	await _duel(WARMUP_SEC, false)
	print("Mesure %.0f s…" % _seconds)
	_t = 0.0
	await _duel(_seconds, true)
	_rapport()
	get_tree().quit(0)


## ⚠️ Deux fois, et ce n'est pas de la superstition : `AudioManager` pose ses
## volumes de bus à l'initialisation, donc une sourdine mise avant qu'il existe
## serait effacée par lui.
func _couper_le_son(quand: String) -> void:
	var maitre := AudioServer.get_bus_index("Master")
	if maitre < 0:
		printerr("  ⚠ bus Master introuvable — le son n'a PAS pu être coupé")
		return
	AudioServer.set_bus_mute(maitre, true)
	AudioServer.set_bus_volume_db(maitre, -80.0)
	print("  son coupé (%s) : muet=%s, %.0f dB"
		% [quand, AudioServer.is_bus_mute(maitre),
			AudioServer.get_bus_volume_db(maitre)])


func _duel(duree: float, mesure: bool) -> void:
	var ecoule := 0.0
	while ecoule < duree and _main.round_active:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		ecoule += dt
		_t += dt

		_main.p2.global_position = _main.p1.global_position + Vector2(DUEL_DISTANCE, 0.0)
		for p in [_main.p1, _main.p2]:
			p.hp = 100.0
			p.flashlight_on = true
			if p.shoot_cooldown <= 0.0:
				p.shoot()
		_main.p1.rotation = (_main.p2.global_position - _main.p1.global_position).angle()
		_main.p2.rotation = (_main.p1.global_position - _main.p2.global_position).angle()

		if mesure and dt > 0.0:
			# Relevés au vol : lus après la boucle ils vaudraient l'état final,
			# et le banc corrélerait des images avec des chiffres d'après-coup.
			_images.append({
				"t": _t,
				"dt": dt,
				"appels": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"objets": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				"noeuds": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				"memoire": Performance.get_monitor(Performance.MEMORY_STATIC),
				"process": Performance.get_monitor(Performance.TIME_PROCESS),
				"physique": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
				"particules": _main.particle_pool.active_count() if _main.particle_pool else 0,
			})


func _rapport() -> void:
	if _images.size() < 100:
		printerr("trop peu d'images (%d) — relevé sans valeur" % _images.size())
		return
	var tries := _images.duplicate()
	tries.sort_custom(func(a, b): return a["dt"] > b["dt"])
	var n_lentes := maxi(1, int(_images.size() * PART_LENTE))
	var lentes := tries.slice(0, n_lentes)

	print("\n=== %d images mesurées en %.1f s ===" % [_images.size(), _t])
	print("  médiane        : %5.1f fps" % (1.0 / _mediane(_images, "dt")))
	print("  1 %% bas (%2d img): %5.1f fps" % [n_lentes, 1.0 / _moyenne(lentes, "dt")])
	print("  la pire        : %5.2f ms  à t = %.1f s"
		% [lentes[0]["dt"] * 1000.0, lentes[0]["t"]])

	# ── QUAND ? La question qui sépare « coût permanent » de « coût de départ ».
	print("\n--- QUAND les images lentes tombent-elles ---")
	var tranches := 10
	var par_tranche := []
	par_tranche.resize(tranches)
	par_tranche.fill(0)
	for img in lentes:
		var i: int = clampi(int(float(img["t"]) / _t * tranches), 0, tranches - 1)
		par_tranche[i] += 1
	for i in tranches:
		var barre := ""
		for _j in par_tranche[i]:
			barre += "█"
		print("  %4.1f-%4.1f s |%-20s %d"
			% [_t * i / tranches, _t * (i + 1) / tranches, barre, par_tranche[i]])
	var debut: int = par_tranche[0] + par_tranche[1]
	var part_debut := float(debut) / float(n_lentes) * 100.0
	print("  → %.0f %% des images lentes sont dans le premier cinquième du relevé." % part_debut)
	if part_debut >= 50.0:
		print("    ⚠️ GROUPÉES AU DÉBUT : signature d'une compilation ou d'une")
		print("       première allocation. Ce coût se paie au chargement, PAS en")
		print("       match — et `bench_framerate` le compte quand même.")
	else:
		print("    → ÉTALÉES : le coût est permanent, il se paiera en match.")

	# ── QUOI ? Ce qui distingue une image lente d'une image ordinaire.
	print("\n--- CE QUI DISTINGUE une image lente (médiane lente / médiane globale) ---")
	print("  %-14s %14s %12s %10s" % ["grandeur", "images lentes", "toutes", "écart"])
	# ⚠️ **`process` et `physique` sont en SECONDES.** Le premier jet les imprimait
	# en entiers : les deux colonnes qui disent si le CPU est en cause
	# affichaient « 0 », et le banc paraissait n'avoir rien mesuré là où il avait
	# mesuré l'essentiel. Un format qui écrase la donnée ment autant qu'un
	# contrôle qui ne peut pas échouer.
	for cle in ["appels", "objets", "particules", "noeuds"]:
		var a := _mediane(lentes, cle)
		var b := _mediane(_images, cle)
		var ecart := ((a / b - 1.0) * 100.0) if b > 0.0 else 0.0
		var marque := "  <-- suspect" if absf(ecart) >= 25.0 else ""
		print("  %-14s %14.0f %12.0f %9.0f %%%s" % [cle, a, b, ecart, marque])
	for cle in ["process", "physique"]:
		var a := _mediane(lentes, cle) * 1000.0
		var b := _mediane(_images, cle) * 1000.0
		var ecart := ((a / b - 1.0) * 100.0) if b > 0.0 else 0.0
		print("  %-14s %11.3f ms %9.3f ms %9.0f %%" % [cle, a, b, ecart])
	# ⚠️ **Ce partage CPU / reste, le banc REFUSE de le faire — et le refus est
	# le résultat.** L'idée était bonne : si une image lente dure bien plus que
	# `process + physique`, le coût est hors du code de jeu, et aucune
	# optimisation de GDScript n'y changera rien. Mais la mesure ne la porte pas.
	#
	# Relevé le 2026-08-25 : `process` vaut **19,3 ms** pendant que l'image
	# MÉDIANE dure **9,1 ms**. Un temps de traitement ne peut pas dépasser le
	# temps de l'image qui le contient : `Performance.TIME_PROCESS` n'est donc
	# pas échantillonné à l'image, c'est une moyenne glissante entretenue par le
	# moteur. Le premier jet de ce banc en tirait « −3,1 % du temps est hors du
	# code de jeu » — un pourcentage **négatif**, imprimé sans broncher.
	#
	# **Un banc qui rend un nombre impossible est pire qu'un banc muet** : il a
	# l'autorité d'une mesure. On garde donc les deux colonnes, qui restent
	# valables en COMPARAISON (lentes contre toutes, même biais des deux côtés),
	# et on refuse le partage en valeur absolue.
	var cpu_lent := (_mediane(lentes, "process") + _mediane(lentes, "physique")) * 1000.0
	var img_lente := _moyenne(lentes, "dt") * 1000.0
	print("\n  Image lente : %.2f ms | médiane : %.2f ms | moniteur CPU : %.2f ms"
		% [img_lente, _mediane(_images, "dt") * 1000.0, cpu_lent])
	# ⚠️ **Comparé à l'image MÉDIANE, pas à l'image lente.** Premier garde : il
	# testait le moniteur contre l'image lente (21 ms), qu'il dépasse une fois
	# sur deux — donc il ne se déclenchait qu'une fois sur deux, et le banc
	# concluait le reste du temps à partir d'une mesure qu'il savait fausse. Un
	# garde intermittent est un faux vert qui attend son tour. La médiane, elle,
	# tranche à tous les coups : un temps de traitement de 19,6 ms sur des images
	# médianes de 10 ms est impossible, quelle que soit la queue de distribution.
	var img_mediane := _mediane(_images, "dt") * 1000.0
	if cpu_lent >= img_mediane:
		print("  ⚠️ Le moniteur CPU dépasse le temps d'image : il n'est PAS")
		print("     échantillonné à l'image (moyenne glissante du moteur). Ces")
		print("     deux colonnes ne valent qu'en COMPARAISON, jamais en absolu.")
		print("     Le banc ne conclut donc RIEN sur le partage CPU / GPU ici.")
	else:
		print("  → %.1f %% du temps d'une image lente est hors du code de jeu."
			% ((1.0 - cpu_lent / img_lente) * 100.0))

	var mem_debut: float = _images[0]["memoire"]
	var mem_fin: float = _images[_images.size() - 1]["memoire"]
	print("\n  mémoire statique : %.1f Mo → %.1f Mo (%+.1f Mo sur le relevé)"
		% [mem_debut / 1048576.0, mem_fin / 1048576.0,
			(mem_fin - mem_debut) / 1048576.0])
	print("\n  ⚠️ Aucune de ces colonnes ne PROUVE une cause : elles la désignent.")
	print("     Un écart de 25 %% ou plus vaut qu'on aille voir ; le reste est du bruit.")


func _mediane(a: Array, cle: String) -> float:
	if a.is_empty():
		return 0.0
	var v := []
	for e in a:
		v.append(float(e[cle]))
	v.sort()
	return v[v.size() / 2]


func _moyenne(a: Array, cle: String) -> float:
	var s := 0.0
	for e in a:
		s += float(e[cle])
	return s / float(a.size()) if a.size() > 0 else 0.0


## Le pompe : l'arme qui produit le plus de plombs, donc de particules et
## d'impacts. C'est le pire cas, et c'est lui qu'on veut voir échouer.
func _choisir_pompe(groupe: ButtonGroup) -> void:
	var boutons: Array = groupe.get_buttons()
	if boutons.size() > 2:
		boutons[2].button_pressed = true


func _attendre(predicat: Callable, delai: float) -> bool:
	var attendu := 0.0
	while not predicat.call():
		if attendu >= delai:
			return false
		await get_tree().create_timer(0.25).timeout
		attendu += 0.25
	return true


func _value(args: PackedStringArray, cle: String, defaut: String) -> String:
	var i := args.find(cle)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else defaut
