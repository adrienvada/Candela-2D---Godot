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

	# Écran partagé : les DEUX vues rendent, chacune avec son jeu de lumières et
	# d'ombres portées. C'est le pire cas de la passe de performance.
	_ui.btn_mode_local.button_pressed = true
	_select_shotgun(_ui.p1_weapon_group)
	_select_shotgun(_ui.p2_weapon_group)
	_main._on_replay_requested()

	if not await _await(func(): return _main.round_active, 15.0):
		printerr("✗ la manche n'a pas démarré")
		get_tree().quit(1)
		return

	print("Manche lancée — armes : %s / %s" % [
		_main.p1.current_weapon.name, _main.p2.current_weapon.name])
	print("Échauffement %.0f s (chargement des shaders, remplissage du pool)…" % WARMUP_SEC)
	await _stress(WARMUP_SEC, false)

	print("Mesure sur %.0f s…" % _seconds)
	await _stress(_seconds, true)
	_report()
	get_tree().quit(0)


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
			_samples.append(Engine.get_frames_per_second())
			# Relevés au vol : lus après la boucle ils vaudraient zéro, et le
			# banc prétendrait mesurer une charge qu'il n'aurait pas prouvée.
			_peak_particles = maxi(_peak_particles, _main.particle_pool.active_count())
			_peak_bullets = maxi(_peak_bullets, _main.bullet_container.get_child_count())


func _report() -> void:
	if _samples.is_empty():
		printerr("✗ aucun échantillon")
		return
	var sorted := _samples.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += v
	var avg := total / sorted.size()
	# Le 1 % bas dit ce que le joueur ressent comme saccade, la moyenne le cache.
	var low1: float = sorted[maxi(0, int(sorted.size() * 0.01))]

	print("\n=== RÉSULTAT ===")
	print("  Échantillons     : %d" % sorted.size())
	print("  FPS moyen        : %.0f" % avg)
	print("  FPS médian       : %.0f" % sorted[sorted.size() / 2])
	print("  FPS 1 %% bas      : %.0f" % low1)
	print("  FPS minimum      : %.0f" % sorted[0])
	print("  Particules (pic) : %d / %d" % [_peak_particles, ParticlePool.MAX_ACTIVE])
	print("  Balles (pic)     : %d" % _peak_bullets)
	print("  Verdict 120 fps  : %s" % ("TENU" if low1 >= 120.0 else "NON TENU (1 %% bas à %.0f)" % low1))


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
