## Banc de cadence d'image en conditions de pire cas, FENÊTRÉ.
##
## La passe de performance de l'étape 9 avait été mesurée côté CPU seulement
## (`bench_particles.gd`, headless). Déplafonner la cadence d'image déplace la
## question sur le GPU : le jeu tient-il réellement au-dessus de 120 fps quand
## les deux vues rendent, torches allumées, pendant un échange au pompe ?
##
## Headless ne répond pas — rien n'est rasterisé. Ce banc ouvre donc une vraie
## fenêtre. Il n'est jamais lancé par le jeu.
##
## Lancer : godot --path . res://tools/bench_framerate.tscn -- [--seconds 15] [--max-fps 0]
extends Node

const WARMUP_SEC := 2.0
const SHOTGUN_INDEX := 2
## Portée utile du pompe : assez près pour que chaque tir touche.
const DUEL_DISTANCE := 150.0

var _main: Node
var _ui: Node
## **Temps d'image, en secondes — pas des fps.**
##
## Le banc échantillonnait `Engine.get_frames_per_second()` à chaque frame. Or ce
## compteur n'est mis à jour qu'**une fois par seconde** : quinze secondes de
## mesure donnaient quinze valeurs distinctes, recopiées cent quarante fois
## chacune. Le tableau paraissait riche — 2082 échantillons au relevé du
## 2026-08-18 — et ne contenait que quinze mesures.
##
## Conséquence directe sur le seul chiffre qui compte : le « 1 % bas » est censé
## dire ce que le joueur ressent comme saccade, c'est-à-dire le comportement des
## images les plus lentes. Calculé sur des moyennes d'une seconde, **il ne peut
## rien en dire** : une seconde à 150 fps contenant une image à 20 ms se lit
## comme une seconde à 150 fps. Le relevé rendait `1 % bas == minimum`, ce qui
## est la signature du défaut — un percentile sur des doublons est un minimum.
var _samples: Array[float] = []
var _seconds := 15.0
var _peak_particles := 0
var _peak_bullets := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_seconds = float(_value(args, "--seconds", "15"))
	# Le banc impose sa cadence : sans cela il hériterait du plafond enregistré
	# dans les préférences et deux exécutions ne seraient plus comparables.
	Engine.max_fps = int(_value(args, "--max-fps", "0"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	print("=== Banc de cadence d'image ===")
	print("Plafond: %s | vsync: désactivé" % ("aucun" if Engine.max_fps == 0 else str(Engine.max_fps)))

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node("UI")

	# **Vérifier ses appuis AVANT de mesurer.** Le banc lisait `btn_mode_local`,
	# disparu avec la refonte des menus de la Phase 5 : il s'ouvrait, levait une
	# erreur de script, n'entrait jamais dans le duel, et **restait ouvert sans
	# rien mesurer**. Il a fallu le tuer à la main, le jour où on avait besoin du
	# chiffre. Un banc qui échoue doit le dire et sortir.
	var manquants := preconditions_manquantes(_ui, _main)
	if not manquants.is_empty():
		printerr("✗ le banc ne peut pas démarrer — le jeu a changé sous lui :")
		for m in manquants:
			printerr("    · ", m)
		printerr("  Voir tools/test_banc.gd, qui vérifie ces appuis en headless.")
		_sortir(1)
		return

	# Écran partagé : les DEUX vues rendent, chacune avec son jeu de lumières et
	# d'ombres portées. C'est le pire cas de la passe de performance.
	#
	# Le mode ne se choisit plus par un bouton mais par la navigation, qui écrit
	# `_intended_mode`. Le banc n'a pas d'écran à parcourir : il pose l'intention
	# directement, comme le ferait l'entrée « 1V1 écrans scindés ».
	_ui._intended_mode = NetworkManager.GameMode.LOCAL_SPLITSCREEN
	_select_shotgun(_ui.p1_weapon_group)
	_select_shotgun(_ui.p2_weapon_group)
	_main._on_replay_requested()

	if not await _await(func(): return _main.round_active, 15.0):
		printerr("✗ la manche n'a pas démarré")
		_sortir(1)
		return

	print("Manche lancée — armes : %s / %s" % [
		_main.p1.current_weapon.name, _main.p2.current_weapon.name])
	print("Échauffement %.0f s (chargement des shaders, remplissage du pool)…" % WARMUP_SEC)
	await _stress(WARMUP_SEC, false)

	print("Mesure sur %.0f s…" % _seconds)
	await _stress(_seconds, true)
	_report()
	_sortir(0)


## Sortir par la porte du jeu, et non par `get_tree().quit()`.
##
## Le banc instancie `main.tscn`, donc les autoloads EOS : quitter sec ré-entre
## dans `EOS_Platform_Tick()` et le processus meurt en **signal 11** (relevé du
## 2026-08-18, code 134). Les chiffres sortaient avant le crash, donc la mesure
## restait valide — mais c'est le piège d'arrêt propre déjà consigné dans la
## ROADMAP, et en build release la fin du journal serait perdue avec.
func _sortir(code: int) -> void:
	var reseau := get_node_or_null(^"/root/NetworkManager")
	if reseau != null and reseau.has_method("quit_game"):
		reseau.quit_game(code)
		return
	get_tree().quit(code)


## Les deux joueurs se tirent dessus au pompe, torches allumées, HP maintenus
## pleins pour que l'échange ne s'arrête jamais : impacts, sang, étincelles,
## flashs de bouche et lumières dynamiques tournent en continu.
func _stress(duration: float, sampling: bool) -> void:
	var elapsed := 0.0
	while elapsed < duration and _main.round_active:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

		# Les points d'apparition sont aux deux bouts de l'arène : à cette
		# distance les plombs de pompe expirent avant de toucher, et le banc ne
		# produirait aucune particule — il mesurerait une charge imaginaire.
		_main.p2.global_position = _main.p1.global_position + Vector2(DUEL_DISTANCE, 0.0)
		for p in [_main.p1, _main.p2]:
			p.hp = 100.0
			p.flashlight_on = true
			if p.shoot_cooldown <= 0.0:
				p.shoot()
		# Se viser mutuellement : les balles portent, donc les impacts aussi.
		_main.p1.rotation = (_main.p2.global_position - _main.p1.global_position).angle()
		_main.p2.rotation = (_main.p1.global_position - _main.p2.global_position).angle()

		if sampling:
			# Le temps de CETTE image. La première après l'échauffement peut
			# porter le coût d'un changement d'état ; elle compte quand même,
			# c'est une saccade que le joueur verrait.
			var dt := get_process_delta_time()
			if dt > 0.0:
				_samples.append(dt)
			# Relevés au vol : lus après la boucle ils vaudraient zéro, et le
			# banc prétendrait mesurer une charge qu'il n'aurait pas prouvée.
			_peak_particles = maxi(_peak_particles, _main.particle_pool.active_count())
			_peak_bullets = maxi(_peak_bullets, _main.bullet_container.get_child_count())


func _report() -> void:
	if _samples.is_empty():
		printerr("✗ aucun échantillon")
		return
	# Trié du plus RAPIDE au plus lent : ce sont des durées, pas des cadences.
	var sorted := _samples.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += v
	# Moyenne des cadences = images / temps total, et non moyenne des 1/dt : la
	# seconde donne un poids démesuré aux images rapides et flatte le résultat.
	var avg := float(sorted.size()) / total

	# **1 % bas au sens habituel** : la cadence moyenne du centième d'images le
	# plus LENT. Une moyenne sur cette tranche, et non sa borne — un seul pic
	# isolé ne doit pas décider seul du verdict, mais vingt saccades doivent.
	var lents := maxi(1, int(round(sorted.size() * 0.01)))
	var somme_lentes := 0.0
	for i in range(sorted.size() - lents, sorted.size()):
		somme_lentes += sorted[i]
	var low1 := float(lents) / somme_lentes

	print("\n=== RÉSULTAT ===")
	print("  Images mesurées  : %d en %.1f s" % [sorted.size(), total])
	print("  FPS moyen        : %.0f" % avg)
	print("  FPS médian       : %.0f" % (1.0 / sorted[sorted.size() / 2]))
	print("  FPS 1 %% bas      : %.0f  (moyenne des %d images les plus lentes)"
		% [low1, lents])
	print("  Image la plus lente : %.1f ms  (soit %.0f fps)"
		% [sorted[sorted.size() - 1] * 1000.0, 1.0 / sorted[sorted.size() - 1]])
	print("  Particules (pic) : %d / %d" % [_peak_particles, ParticlePool.MAX_ACTIVE])
	print("  Balles (pic)     : %d" % _peak_bullets)
	print("  Verdict 120 fps  : %s" % ("TENU" if low1 >= 120.0 else "NON TENU (1 %% bas à %.0f)" % low1))


## Les appuis du banc sur le jeu, nommés une fois et vérifiables sans fenêtre.
##
## C'est ce qui manquait : **le banc n'est dans aucune suite** — il ouvre une
## fenêtre, il ne peut pas y être — donc rien ne signalait qu'il avait cessé de
## fonctionner. Un outil de mesure hors couverture se périme en silence, et on
## s'en aperçoit au moment précis où on a besoin de la mesure.
##
## La liste est publique et statique pour que `tools/test_banc.gd` la vérifie en
## headless, sans rien rasteriser. Elle ne remplace pas le banc ; elle garantit
## qu'il pourra démarrer.
static func preconditions_manquantes(ui: Node, main: Node) -> Array[String]:
	var absents: Array[String] = []
	if ui == null or main == null:
		absents.append("main.tscn n'expose plus UI ou GameState")
		return absents
	for prop in ["_intended_mode", "p1_weapon_group", "p2_weapon_group"]:
		if not prop in ui:
			absents.append("UI.%s a disparu" % prop)
	for prop in ["round_active", "p1", "p2", "particle_pool", "bullet_container"]:
		if not prop in main:
			absents.append("GameState.%s a disparu" % prop)
	if not main.has_method("_on_replay_requested"):
		absents.append("GameState._on_replay_requested() a disparu")
	for groupe in ["p1_weapon_group", "p2_weapon_group"]:
		if groupe in ui:
			var g: ButtonGroup = ui.get(groupe)
			if g == null or g.get_buttons().size() <= SHOTGUN_INDEX:
				absents.append("UI.%s n'a plus d'arme à l'indice %d (pompe)"
					% [groupe, SHOTGUN_INDEX])
	return absents


func _select_shotgun(group: ButtonGroup) -> void:
	var buttons: Array = group.get_buttons()
	if SHOTGUN_INDEX < buttons.size():
		buttons[SHOTGUN_INDEX].button_pressed = true


func _await(predicate: Callable, timeout: float) -> bool:
	var waited := 0.0
	while not predicate.call():
		if waited >= timeout:
			return false
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	return true


func _value(args: PackedStringArray, flag: String, fallback: String) -> String:
	var idx := args.find(flag)
	if idx < 0 or idx + 1 >= args.size():
		return fallback
	return args[idx + 1]
