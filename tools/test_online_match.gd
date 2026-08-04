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
	var needs_eos := not _lan and not _has("--local")
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
	else:
		print("Usage: --host | --join <CODE|IP> | --local")
		_quit(2)


## L'écran partagé ne doit rien devoir au réseau : le bloc lobby disparaît, les
## deux vues restent, et rien n'est envoyé nulle part.
func _run_local() -> void:
	_ui.btn_mode_local.button_pressed = true
	_check("le bloc en ligne est masqué en local", not _ui.online_hbox.visible)
	_check("le choix de transport est masqué en local", not _ui.transport_hbox.visible)
	_check("le champ de saisie est masqué en local", not _ui.join_input.visible)
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
	_quit(0)


func _run_host() -> void:
	_select_mode(true)
	print("MENU: mode hôte sélectionné, transport %s" % ("LAN" if _lan else "Internet"))
	_press_play()

	if _lan:
		print("CODE: %d" % NetworkManager.DEFAULT_PORT)
	else:
		if not await _await(func(): return not NetworkManager.lobby_code.is_empty(), CODE_TIMEOUT):
			_fail("aucun code de salon publié")
			return
		print("CODE: %s" % NetworkManager.lobby_code)
		# Ce que l'hôte a réellement sous les yeux pendant qu'il attend.
		print("ECRAN_ATTENTE: %s" % _ui.waiting_label.text.replace("\n", " / "))
		_check("le code de l'écran d'attente est celui du salon",
			_ui.waiting_label.text.contains(NetworkManager.lobby_code))

	if not await _await(func(): return not multiplayer.get_peers().is_empty(), PEER_TIMEOUT):
		_fail("aucun adversaire n'a rejoint")
		return
	print("ADVERSAIRE: connecté (id %d)" % multiplayer.get_peers()[0])
	await _verify_round()
	_quit(0)


func _run_client() -> void:
	_select_mode(false)
	_ui.join_input.text = _value("--join", "")
	print("MENU: mode client, saisie « %s »" % _ui.join_input.text)
	_check("la saisie survit à la validation d'alphabet",
		_lan or LobbyCode.is_valid(_ui.join_input.text), _ui.join_input.text)
	_press_play()

	if not await _await(func(): return not multiplayer.get_peers().is_empty(), PEER_TIMEOUT):
		_fail("connexion au salon impossible (%s)" % NetworkManager.last_error)
		return
	print("HOTE: connecté")
	await _verify_round()
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
	# Quelques secondes de jeu réel : synchro, ping applicatif, réplication.
	await get_tree().create_timer(4.0).timeout
	_check("la manche tient dans la durée", _main.round_active)
	_check("le ping applicatif remonte", NetworkManager.has_rtt, "%.1f ms" % NetworkManager.rtt_ms)
	print("PING_MS: %.1f" % NetworkManager.rtt_ms)
	print("HP: p1=%.0f p2=%.0f" % [_main.p1.hp, _main.p2.hp])

	await _verify_kill_to_rematch()


## Fin de BO1 : un kill décidé par l'hôte doit produire killcam puis écran de
## fin des DEUX côtés, et un rematch doit repartir. On passe par take_damage,
## le même point d'entrée qu'une balle — seule la visée est court-circuitée.
func _verify_kill_to_rematch() -> void:
	var is_host := NetworkManager.current_mode == NetworkManager.GameMode.ONLINE_HOST
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
	_check("le score du match est enregistré",
		_main.p1_kills + _main.p2_kills == 1, "%d / %d" % [_main.p1_kills, _main.p2_kills])
	_check("le lien tient après la killcam", not multiplayer.get_peers().is_empty())

	# Rematch : les deux camps se déclarent prêts, la manche doit repartir.
	print("REMATCH: on se déclare prêt (%s)" % _ui.btn_replay.text)
	_main._on_replay_requested()
	_check("le rematch relance une manche", await _await(func(): return _main.round_active, 25.0))


# ---------------------------------------------------------------------------

func _select_mode(is_host: bool) -> void:
	if _lan:
		_ui.btn_transport_lan.button_pressed = true
	else:
		_ui.btn_transport_eos.button_pressed = true
	_ui.btn_mode_online.button_pressed = true
	if is_host:
		_ui.btn_mode_host.button_pressed = true
	else:
		_ui.btn_mode_join.button_pressed = true

## Équivalent d'un clic sur le bouton principal du menu.
func _press_play() -> void:
	print("BOUTON: « %s »" % _ui.btn_replay.text)
	print("STATUT: %s" % _ui.lobby_status_label.text)
	_main._on_replay_requested()


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
