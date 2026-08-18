## Test headless de bout en bout : le jeu complet (main.tscn), piloté par le
## menu, deux instances qui se trouvent par code de salon et entrent en manche.
##
## Contrairement à test_transport.gd qui n'exerce que la couche transport,
## celui-ci passe par les vrais boutons du lobby, la vraie séquence de départ et
## la vraie sortie de jeu.
##
## Hôte  : godot --headless --path . res://tools/test_online_match.tscn -- --host --eos-ephemeral
## Client: godot --headless --path . res://tools/test_online_match.tscn -- --join <CODE> --eos-ephemeral
extends Node

const EOS_READY_TIMEOUT := 30.0
const CODE_TIMEOUT := 20.0
const PEER_TIMEOUT := 30.0
const ROUND_TIMEOUT := 20.0

var _args: PackedStringArray
var _main: Node
var _ui: Node
var _lan := false
var _rejected_at := -1


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_lan = _value("--transport", "eos") == "enet"
	NetworkManager.transport = NetworkManager.Transport.ENET if _lan else NetworkManager.Transport.EOS

	print("=== MATCH EN LIGNE (bout en bout) ===")
	print("TRANSPORT: %s" % ("ENET" if _lan else "EOS"))

	_main = preload("res://main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_ui = _main.get_node("UI")

	# L'écran partagé et le LAN n'ont rien à attendre d'Epic.
	# L'entraînement est solitaire : il n'a pas plus besoin d'Epic que l'écran
	# partagé, et l'attendre ferait pendre le banc trente secondes pour rien.
	var needs_eos := not _lan and not _has("--local") and not _has("--training")
	if needs_eos:
		if not await _await(func(): return NetworkManager.eos_state == NetworkManager.EosState.READY \
				or NetworkManager.eos_state == NetworkManager.EosState.FAILED, EOS_READY_TIMEOUT):
			_fail("EOS n'est jamais devenu prêt (%s)" % NetworkManager.eos_state_label())
			return
		if NetworkManager.eos_state != NetworkManager.EosState.READY:
			_fail("EOS: %s" % NetworkManager.eos_state_label())
			return
	print("EOS: %s" % NetworkManager.eos_state_label())

	if _has("--host"):
		await _run_host()
	elif _has("--join"):
		await _run_client()
	elif _has("--local"):
		await _run_local()
	elif _has("--training"):
		await _run_training()
	else:
		print("Usage: --host | --join <CODE|IP> | --local | --training")
		_quit(2)


## L'entraînement solitaire. Ce que ce mode protège, dans l'ordre :
##
##   • **rien n'est archivé** — un entraînement n'est pas un match, et le journal
##     local est la source du rejeu vers le classement. Une seule ligne écrite
##     ici polluerait un classement que personne ne saurait plus corriger ;
##   • la cible se tient au point d'apparition de J2, pas devant J1 : c'est ce
##     qui rend l'exercice transférable à un vrai premier échange ;
##   • la carte est celle par défaut, quelle qu'ait été la dernière sélection ;
##   • on peut tirer alors qu'aucune manche n'est active — sans quoi
##     l'entraînement serait un décor.
func _run_training() -> void:
	# La sélection est délibérément salie avant : on vérifie que l'entraînement
	# la remet à la carte par défaut au lieu de la subir.
	var cartes: Array = MapData.list_maps()
	for carte in cartes:
		var id := String((carte as Dictionary).get("id", ""))
		if id != MapData.DEFAULT_MAP_ID:
			MapData.select_map(id)
			break
	var journal_avant := _history_size()

	_ui.hub.push(_ui.SCREEN_TRAINING)
	_check("l'écran est bien celui de l'entraînement",
		_ui.hub.current_id() == _ui.SCREEN_TRAINING)
	_ui.training_requested.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var ids: Array[String] = []
	for c in MapData.list_maps():
		ids.append(String((c as Dictionary).get("id", "?")))
	print("CATALOGUE: %s | DEFAUT: %s | SELECTION: %s"
		% [", ".join(ids), MapData.DEFAULT_MAP_ID, MapData.selected_map_id])
	# `DEFAULT_MAP_ID` est un slug ; la sélection retient un identifiant. Les
	# comparer directement était l'erreur que ce banc a précisément servi à
	# trouver dans `map_data.gd` — on passe donc par le catalogue.
	var defaut: Dictionary = MapData.get_map_by_slug(MapData.DEFAULT_MAP_ID)
	_check("l'arène livrée par défaut est au catalogue", not defaut.is_empty())
	_check("la carte revient à celle par défaut",
		MapData.selected_map_id == String(defaut.get("id", "")),
		"%s attendu %s" % [MapData.selected_map_id, defaut.get("id", "?")])
	_check("aucune manche n'est active", not _main.round_active)
	_check("le bac à sable est armé", _main.sandbox_mode)
	_check("la cible est visible", _main.training_target.visible)
	# Le contrôle qui donne son sens au placement : la cible occupe la place de
	# l'adversaire, à quelques pixels près.
	var spawn_j2: Vector2 = _main._get_spawn_position(1)
	_check("la cible est au point d'apparition de J2",
		_main.training_target.global_position.distance_to(spawn_j2) < 1.0,
		"%s vs %s" % [_main.training_target.global_position, spawn_j2])
	_check("le joueur 2 a quitté la scène", not _main.p2.visible)
	# Un mode solitaire ne coupe pas l'écran en deux pour une moitié vide :
	# défaut relevé par Adrien au premier essai, l'entraînement tournant en mode
	# écran partagé du point de vue du transport.
	_check("l'écran n'est pas partagé", _main.vp1.get_parent().visible
		and not _main.vp2.get_parent().visible,
		"vp1=%s vp2=%s" % [_main.vp1.get_parent().visible,
			_main.vp2.get_parent().visible])
	_check("la ligne de séparation est retirée", not _ui.center_line.visible)
	_check("aucun forfait n'est en attente", not _main._forfeit_pending)
	_check("aucun identifiant de match n'est armé", _main._match_id.is_empty())

	# Tirer doit marcher hors manche, sinon l'entraînement est un décor.
	var balles_avant: int = _main.bullet_container.get_child_count()
	_main.p1.shoot()
	await get_tree().process_frame
	_check("on peut tirer pendant l'entraînement",
		_main.bullet_container.get_child_count() > balles_avant,
		"%d → %d" % [balles_avant, _main.bullet_container.get_child_count()])

	await get_tree().create_timer(1.0).timeout
	_check("le journal local n'a pas bougé",
		_history_size() == journal_avant,
		"%d → %d" % [journal_avant, _history_size()])
	_quit(0)

## Taille du journal de matchs, ou -1 s'il n'existe pas encore.
func _history_size() -> int:
	if not FileAccess.file_exists(MatchRecord.HISTORY_PATH):
		return -1
	var f := FileAccess.open(MatchRecord.HISTORY_PATH, FileAccess.READ)
	if f == null:
		return -1
	var n := f.get_length()
	f.close()
	return n

## L'écran partagé ne doit rien devoir au réseau : le bloc lobby disparaît, les
## deux vues restent, et rien n'est envoyé nulle part.
func _run_local() -> void:
	# L'intention de mode ne se pose plus en cochant un bouton : elle se pose en
	# entrant dans le salon. Ce test le disait par l'état de l'interface ; il le
	# dit maintenant par le geste, ce qui est aussi ce que fait un joueur.
	_ui.hub.push(_ui.SCREEN_LOCAL)
	_check("l'écran est bien le salon local", _ui.hub.current_id() == _ui.SCREEN_LOCAL)
	_check("le mode retenu est l'écran partagé",
		_ui.selected_network_mode() == NetworkManager.GameMode.LOCAL_SPLITSCREEN)
	_check("le choix de transport est masqué en local", not _ui.transport_hbox.visible)
	# `visible` ne dit que l'intention posée sur CE nœud : le champ vit dans un
	# conteneur que le menu cache, et reste donc « visible » pour lui-même. Seul
	# `is_visible_in_tree()` répond à la question posée.
	_check("le champ de saisie est masqué en local",
		not _ui.join_input.is_visible_in_tree())
	_check("le code de salon est masqué en local", not _ui.lobby_code_row.visible)
	_press_play()
	_check("la manche locale démarre", await _await(func(): return _main.round_active, ROUND_TIMEOUT))
	_check("aucun pair réseau", not multiplayer.has_multiplayer_peer())
	_check("mode local conservé",
		NetworkManager.current_mode == NetworkManager.GameMode.LOCAL_SPLITSCREEN)
	_check("les deux vues sont visibles",
		_main.vp1.get_parent().visible and _main.vp2.get_parent().visible)
	await get_tree().create_timer(2.0).timeout
	_check("la manche locale tient", _main.round_active)

	# Jusqu'à l'écran de fin, et c'est tout l'intérêt de ce mode : une seule
	# instance, aucun réseau, et pourtant le chemin exact où vivait le défaut de
	# `frame_post_draw` — une attente de rendu jamais satisfaite en headless, qui
	# laissait la séquence de fin suspendue pour toujours. Ce contrôle-là peut
	# entrer dans le lanceur de suites, là où les deux instances ne le peuvent pas.
	print("KILL: on abat le joueur 2")
	_main.p2.take_damage(1000.0, _main.p1)
	_check("la manche locale se termine",
		await _await(func(): return not _main.round_active, 10.0))
	_check("la séquence de fin se déclenche",
		await _await(func(): return _main._end_sequence_active or _main.game_over, 10.0))
	_check("l'écran de fin finit par se poser",
		await _await(func(): return _main.game_over and not _main._end_sequence_active, 25.0))
	print("FIN: %s" % _ui.game_over_title.text)
	_check("le titre de fin n'est plus celui du menu",
		_ui.game_over_title.text != "CANDELA 2D", _ui.game_over_title.text)
	_check("le score de session est enregistré",
		_main.p1_session_wins + _main.p2_session_wins == 1,
		"%d / %d" % [_main.p1_session_wins, _main.p2_session_wins])
	_quit(0)


func _run_host() -> void:
	await _select_mode(true)
	print("MENU: mode hôte sélectionné, transport %s" % ("LAN" if _lan else "Internet"))
	# L'hôte ouvre son salon depuis le panneau, il n'appuie pas sur PRÊT : le
	# code doit s'afficher avant que quiconque soit là, et PRÊT n'a de sens
	# qu'une fois l'adversaire arrivé.
	_ui._open_lobby()

	if _lan:
		print("CODE: %d" % NetworkManager.DEFAULT_PORT)
	else:
		if not await _await(func(): return not NetworkManager.lobby_code.is_empty(), CODE_TIMEOUT):
			_fail("aucun code de salon publié")
			return
		print("CODE: %s" % NetworkManager.lobby_code)
		# Le code se lit dans le panneau du salon, où l'hôte attend — il n'y a plus
		# d'écran d'attente en jeu, le départ ayant lieu depuis le menu.
		print("PANNEAU: %s" % _ui.lobby_code_engraver.code())
		_check("le panneau du salon affiche le code",
			_ui.lobby_code_engraver.code() == NetworkManager.lobby_code)

	_check("PRÊT est grisé tant que l'hôte est seul", _ready_entry_disabled())

	if not await _await(func(): return not multiplayer.get_peers().is_empty(), PEER_TIMEOUT):
		_fail("aucun adversaire n'a rejoint")
		return
	print("ADVERSAIRE: connecté (id %d)" % multiplayer.get_peers()[0])
	_check("PRÊT s'ouvre à l'arrivée de l'adversaire", not _ready_entry_disabled())
	# Le match n'a PAS démarré tout seul : c'est tout l'objet de la porte.
	_check("aucune manche n'a démarré à la connexion", not _main.round_active)
	# `round_active` dit qu'aucune manche ne tourne ; il ne dit pas où se trouve le
	# joueur. Les deux ont été vrais en même temps le 2026-08-18 : le client était
	# téléporté hors du menu à la connexion, sans qu'aucune manche démarre, et le
	# banc restait vert pendant qu'Adrien était bloqué. C'est `_is_main_menu` qui
	# décrit ce que le joueur PERÇOIT.
	_check("on est toujours dans le menu", _ui._is_main_menu)
	_press_play()
	await _verify_round()
	# Les deux instances ne sont pas lancées en même temps : celle qui finit la
	# première ne doit pas partir pendant que l'autre teste encore son rematch.
	await get_tree().create_timer(10.0).timeout
	_quit(0)


func _run_client() -> void:
	await _select_mode(false)
	_ui.join_input.text = _value("--join", "")
	print("MENU: mode client, saisie « %s »" % _ui.join_input.text)
	_check("la saisie survit à la validation d'alphabet",
		_lan or LobbyCode.is_valid(_ui.join_input.text), _ui.join_input.text)
	# Un code refusé doit se dire tout de suite : on mesure le délai que le
	# joueur subit réellement entre son clic et le message d'erreur.
	# `_rejected_at` est un champ et non une locale : une lambda GDScript capture
	# les locales par valeur, l'affectation n'en ressortirait jamais.
	_rejected_at = -1
	var pressed_at := Time.get_ticks_msec()
	NetworkManager.connection_failed.connect(func(): _rejected_at = Time.get_ticks_msec())
	_check("PRÊT est grisé avant d'avoir rejoint", _ready_entry_disabled())
	# Rejoindre est un geste à part, sous le champ de code : il ne lance rien.
	_ui.join_requested.emit()

	if not await _await(func(): return not multiplayer.get_peers().is_empty() or _rejected_at > 0, PEER_TIMEOUT):
		_fail("aucune réponse du salon en %ds" % PEER_TIMEOUT)
		return
	if _rejected_at > 0:
		_fail("salon refusé après %d ms : %s" % [_rejected_at - pressed_at, NetworkManager.last_error])
		return
	print("HOTE: connecté")
	_check("PRÊT s'ouvre une fois le salon rejoint", not _ready_entry_disabled())
	_check("aucune manche n'a démarré à la connexion", not _main.round_active)
	# `round_active` dit qu'aucune manche ne tourne ; il ne dit pas où se trouve le
	# joueur. Les deux ont été vrais en même temps le 2026-08-18 : le client était
	# téléporté hors du menu à la connexion, sans qu'aucune manche démarre, et le
	# banc restait vert pendant qu'Adrien était bloqué. C'est `_is_main_menu` qui
	# décrit ce que le joueur PERÇOIT.
	_check("on est toujours dans le menu", _ui._is_main_menu)
	_press_play()
	await _verify_round()
	# Les deux instances ne sont pas lancées en même temps : celle qui finit la
	# première ne doit pas partir pendant que l'autre teste encore son rematch.
	await get_tree().create_timer(10.0).timeout
	_quit(0)


## La manche doit démarrer d'elle-même : décompte, puis round_active des deux
## côtés. C'est la partie du flux de match que le changement de transport
## pourrait casser sans qu'aucun test unitaire ne le voie.
func _verify_round() -> void:
	var started := await _await(func(): return _main.round_active, ROUND_TIMEOUT)
	_check("la manche démarre", started)
	if not started:
		return
	print("MANCHE: en cours, décompte restant %.1f s" % _main.countdown_left)
	_check("les deux joueurs sont dans l'arène",
		is_instance_valid(_main.p1) and is_instance_valid(_main.p2))
	_check("le chrono de match tourne", _main.time_left > 0.0)
	# Le client pousse une commande de déplacement constante : c'est l'hôte qui
	# doit simuler J2 à partir d'elle. Sans ce test, rien ne vérifiait que la
	# remontée des commandes fonctionne — seulement que la partie tenait debout.
	var start_p2: Vector2 = _main.p2.global_position
	if NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_CLIENT:
		var stub := NetworkInputProvider.new()
		stub.update_input_state(Vector2.RIGHT, Vector2.RIGHT, false, false, false)
		_main._set_player_input_provider(_main.p2, stub, 0)
		print("DEPLACEMENT: le client pousse une commande vers la droite")

	# Quelques secondes de jeu réel : synchro, ping applicatif, réplication.
	# Les deux instances ne démarrent pas ensemble : l'hôte peut avoir déjà porté
	# son coup pendant cette fenêtre. On vérifie que le match avance, pas qu'il
	# est resté à un instant précis.
	await get_tree().create_timer(4.0).timeout

	var moved: float = _main.p2.global_position.distance_to(start_p2)
	print("DEPLACEMENT: J2 a parcouru %.1f px vu d'ici" % moved)
	_check("le déplacement du client est visible ici", moved > 20.0, "%.1f px" % moved)
	_check("le match avance sans se couper",
		_main.round_active or _main._end_sequence_active or _main.game_over)
	_check("le ping applicatif remonte", NetworkManager.has_rtt, "%.1f ms" % NetworkManager.rtt_ms)
	print("PING_MS: %.1f" % NetworkManager.rtt_ms)
	print("HP: p1=%.0f p2=%.0f" % [_main.p1.hp, _main.p2.hp])

	await _verify_kill_to_rematch()


## Fin de BO1 : un kill décidé par l'hôte doit produire killcam puis écran de
## fin des DEUX côtés, et un rematch doit repartir. On passe par take_damage,
## le même point d'entrée qu'une balle — seule la visée est court-circuitée.
func _verify_kill_to_rematch() -> void:
	var is_host := NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST

	# La killcam de l'invité ne montrait ni tirs ni impacts. take_damage seul ne
	# reproduit rien : il faut de vraies balles dans la fenêtre de rejeu.
	var replayed := [0]
	ReplaySystem.replay_spawn_bullet.connect(func(_s, _p, _r, _w): replayed[0] += 1)

	if is_host:
		print("TIRS: l'hôte tire trois fois")
		for i in 3:
			_main.p1.shoot()
			await get_tree().create_timer(0.35).timeout
	else:
		await get_tree().create_timer(1.05).timeout

	print("ENREG: instantanés=%d évènements=%d recording=%s" % [
		ReplaySystem.snapshots.size(), ReplaySystem.bullet_events.size(),
		ReplaySystem.recording])
	_check("les tirs sont enregistrés pour la killcam",
		ReplaySystem.bullet_events.size() > 0,
		"%d évènement(s)" % ReplaySystem.bullet_events.size())

	if is_host:
		print("KILL: l'hôte abat le joueur 2")
		_main.p2.take_damage(1000.0, _main.p1)

	_check("la manche se termine", await _await(func(): return not _main.round_active, 10.0))
	_check("la séquence de fin se déclenche",
		await _await(func(): return _main._end_sequence_active or _main.game_over, 10.0))
	print("KILLCAM: replay=%s" % ReplaySystem.playing_back)

	# La killcam puis l'écran de fin prennent quelques secondes des deux côtés.
	_check("l'écran de fin de match s'affiche",
		await _await(func(): return _main.game_over and not _main._end_sequence_active, 25.0))
	print("FIN: %s" % _ui.game_over_title.text)
	# Le point décisif : la killcam a-t-elle REJOUÉ les balles enregistrées ?
	# Enregistrement et relecture peuvent échouer indépendamment.
	print("REJEU: impact=%d ralenti=%d balles rejouées=%d / %d enregistrées" % [
		ReplaySystem.impact_frame, ReplaySystem.slow_mo_start_frame,
		replayed[0], ReplaySystem.bullet_events.size()])
	_check("la killcam rejoue les balles enregistrées",
		replayed[0] > 0 or ReplaySystem.bullet_events.is_empty(),
		"%d rejouée(s)" % replayed[0])
	_check("le score du match est enregistré",
		_main.p1_session_wins + _main.p2_session_wins == 1, "%d / %d" % [_main.p1_session_wins, _main.p2_session_wins])
	_check("le lien tient après la killcam", not multiplayer.get_peers().is_empty())

	# Rematch : les deux camps se déclarent prêts, la manche doit repartir.
	print("REMATCH: on se déclare prêt (%s)" % _ui.btn_replay.text)
	_main._on_replay_requested()
	_check("le rematch relance une manche", await _await(func(): return _main.round_active, 25.0))


# ---------------------------------------------------------------------------

## Le transport reste un choix de bouton — Internet ou réseau local est une vraie
## alternative. Le mode, lui, se pose en entrant dans le salon correspondant.
func _select_mode(is_host: bool) -> void:
	if _lan:
		_ui.btn_transport_lan.button_pressed = true
	else:
		_ui.btn_transport_eos.button_pressed = true
	_ui.hub.push(_ui.SCREEN_HOST if is_host else _ui.SCREEN_JOIN)
	# `show_main_menu()` remet la pile à l'accueil, et il peut encore survenir
	# après ce `push` : en EOS l'attente de la session lui laissait le temps de
	# passer, le chemin LAN n'attend rien et le pilotage partait donc d'un écran
	# qui n'était plus le bon. On laisse le menu se poser, puis on vérifie qu'on
	# est bien où l'on croit — plutôt que de découvrir plus tard un contrôle qui
	# accuse l'interface d'un défaut d'écran.
	await get_tree().process_frame
	await get_tree().process_frame
	var attendu: String = _ui.SCREEN_HOST if is_host else _ui.SCREEN_JOIN
	if _ui.hub.current_id() != attendu:
		_ui.hub.push(attendu)
		await get_tree().process_frame
	_check("le salon visé est bien l'écran courant",
		_ui.hub.current_id() == attendu, _ui.hub.current_id())

## Équivalent d'un clic sur « PRÊT ».
func _press_play() -> void:
	print("STATUT: %s" % _ui.lobby_status_label.text)
	_main._on_replay_requested()

## L'entrée « PRÊT » de l'écran courant est-elle grisée ? Le grisage est la façon
## dont le menu dit « il manque quelqu'un » sans faire disparaître le bouton.
func _ready_entry_disabled() -> bool:
	for entree: Button in _ui._ready_entries:
		if is_instance_valid(entree) and entree.is_visible_in_tree():
			return entree.disabled
	# Aucune entrée visible : on n'est pas sur un écran de salon, et répondre
	# « pas grisé » ferait échouer le contrôle en accusant l'interface. C'est le
	# défaut qui a fait passer le chemin LAN pour cassé pendant une journée —
	# l'écran était simplement resté à l'accueil, et les quatre entrées étaient
	# correctement grisées, hors de vue.
	push_error("aucune entrée PRÊT visible — écran courant : %s" % _ui.hub.current_id())
	return true


func _await(predicate: Callable, timeout: float) -> bool:
	var waited := 0.0
	while not predicate.call():
		if waited >= timeout:
			return false
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	return true


var _failures := 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ✓ %s" % label)
	else:
		_failures += 1
		printerr("  ✗ %s%s" % [label, ("  → " + detail) if detail != "" else ""])

func _fail(reason: String) -> void:
	printerr("ECHEC: %s" % reason)
	_quit(1)

func _has(flag: String) -> bool:
	return flag in _args

func _value(flag: String, fallback: String) -> String:
	var idx := _args.find(flag)
	if idx < 0 or idx + 1 >= _args.size():
		return fallback
	return _args[idx + 1]

func _quit(code: int) -> void:
	var final := code if code != 0 else (1 if _failures > 0 else 0)
	if final == 0:
		print("\n✓ Tous les tests passent")
	else:
		printerr("\n✗ %d test(s) en échec" % _failures)
	print("EXIT_CODE: %d" % final)
	# Même porte de sortie que le jeu : c'est aussi ce qu'on veut vérifier.
	NetworkManager.quit_game(final)
