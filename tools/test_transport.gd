## Banc d'essai headless de la couche transport (missions A, B, C).
##
## Deux instances, un code de salon, du trafic RPC et un MultiplayerSynchronizer
## qui tourne : c'est le scénario minimal qui prouve qu'EOS remplace ENet sans
## que le reste du jeu s'en aperçoive.
##
## Hôte  : godot --headless --path . res://tools/test_transport.tscn -- --host [--transport enet] [--eos-ephemeral]
## Client: godot --headless --path . res://tools/test_transport.tscn -- --join <CODE|IP> [--transport enet] [--eos-ephemeral]
##
## Le mouchard (--spy) s'intercale devant le vrai pair pour relever le mode de
## transfert réellement demandé par Godot, commande par commande.
extends Node

const EOS_READY_TIMEOUT := 30.0
const PEER_TIMEOUT := 30.0
const PING_INTERVAL := 0.1
const PONG_TIMEOUT := 3.0

var _args: PackedStringArray
var _duration := 8.0
var _spy: PeerSpy = null

var _remote_id := 0
var _seq := 0
var _sent_at := {}
var _rtts: Array[float] = []
var _lost := 0
var _fps_samples: Array[float] = []

var _probe: Node2D
var _extra_ticker: Node = null


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	if _has("--duration"):
		_duration = float(_value("--duration", "8"))
	# EOSGRuntime tick une fois par frame : le nombre d'images par seconde EST la
	# cadence à laquelle EOS pompe le réseau. Le brider permet de vérifier si le
	# plancher de RTT vient de là ou du SDK lui-même.
	#
	# Toujours affecté, jamais seulement quand l'argument est présent : sinon le
	# banc hériterait du plafond enregistré dans les préférences du joueur et
	# deux exécutions ne seraient plus comparables.
	Engine.max_fps = int(_value("--max-fps", "0"))
	if _has("--extra-tick"):
		_extra_ticker = preload("res://tools/eos_extra_ticker.gd").new()
		add_child(_extra_ticker)

	NetworkManager.transport = NetworkManager.Transport.ENET if _value("--transport", "eos") == "enet" \
		else NetworkManager.Transport.EOS

	_log("=== TRANSPORT TEST ===")
	_log("TRANSPORT: %s" % ("ENET" if NetworkManager.transport == NetworkManager.Transport.ENET else "EOS"))
	_log("EPHEMERAL: %s" % NetworkManager.is_ephemeral_identity())

	NetworkManager.connection_failed.connect(func(): _log("CONNECTION_FAILED: %s" % NetworkManager.last_error))

	if NetworkManager.transport == NetworkManager.Transport.EOS:
		if not await _await_eos_ready():
			_log("EOS: ECHEC (%s)" % NetworkManager.eos_state_label())
			_quit(1)
			return
		_log("EOS: PRET")
		_log("PUID: %s" % NetworkManager.eos_puid)

	if _has("--host"):
		await _run_host()
	elif _has("--join"):
		await _run_client()
	else:
		_log("Usage: --host | --join <CODE|IP>")
		_quit(2)


# ---------------------------------------------------------------------------
# Scénarios
# ---------------------------------------------------------------------------

func _run_host() -> void:
	if not NetworkManager.host_game():
		_log("HOST: ECHEC (%s)" % NetworkManager.last_error)
		_quit(1)
		return
	_install_spy()
	_build_sync_probe(true)

	if NetworkManager.transport == NetworkManager.Transport.EOS:
		var code: String = await NetworkManager.lobby_code_ready
		_log("CODE: %s" % code)
	else:
		_log("CODE: %s" % NetworkManager.DEFAULT_PORT)

	if not await _await_peer():
		_log("PEER: TIMEOUT")
		_quit(1)
		return
	await _run_traffic()
	_quit(0)


func _run_client() -> void:
	var target := _value("--join", "")
	if not NetworkManager.join_game(target):
		_log("JOIN: ECHEC (%s)" % NetworkManager.last_error)
		_quit(1)
		return
	_build_sync_probe(false)

	# En ENet le pair existe déjà (connexion en cours) ; en EOS il n'apparaît
	# qu'après la recherche de salon, trop tard pour s'intercaler.
	_install_spy()
	if not await _await_peer():
		_log("PEER: TIMEOUT (%s)" % NetworkManager.last_error)
		_quit(1)
		return
	await _run_traffic()
	_quit(0)


func _await_eos_ready() -> bool:
	var waited := 0.0
	while NetworkManager.eos_state == NetworkManager.EosState.INITIALIZING \
			or NetworkManager.eos_state == NetworkManager.EosState.UNCONFIGURED:
		if waited >= EOS_READY_TIMEOUT:
			return false
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	return NetworkManager.eos_state == NetworkManager.EosState.READY


func _await_peer() -> bool:
	var waited := 0.0
	while multiplayer.get_peers().is_empty():
		if waited >= PEER_TIMEOUT:
			return false
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	_remote_id = multiplayer.get_peers()[0]
	_log("PEER_CONNECTED: id=%d après %.2fs" % [_remote_id, waited])
	_log("CONNECTION_TYPE: %s" % _network_type_name())
	return true


func _run_traffic() -> void:
	_log("TRAFFIC: %.1fs à %d Hz" % [_duration, int(1.0 / PING_INTERVAL)])
	var elapsed := 0.0
	while elapsed < _duration:
		if not multiplayer.get_peers().has(_remote_id):
			_log("TRAFFIC: pair perdu en cours de route")
			break
		_seq += 1
		_sent_at[_seq] = Time.get_ticks_usec()
		_rpc_probe_ping.rpc_id(_remote_id, _seq, Time.get_ticks_usec())
		await get_tree().create_timer(PING_INTERVAL).timeout
		elapsed += PING_INTERVAL
		_fps_samples.append(Engine.get_frames_per_second())
		_sweep_lost()

	await get_tree().create_timer(PONG_TIMEOUT).timeout
	_sweep_lost(true)
	_report()


func _sweep_lost(force := false) -> void:
	var cutoff := Time.get_ticks_usec() - int(PONG_TIMEOUT * 1_000_000)
	for seq in _sent_at.keys():
		if force or _sent_at[seq] < cutoff:
			_lost += 1
			_sent_at.erase(seq)


func _report() -> void:
	_log("=== RESUME ===")
	_log("PINGS_SENT: %d" % _seq)
	_log("PONGS_RECEIVED: %d" % _rtts.size())
	_log("PACKET_LOSS: %d/%d" % [_lost, _seq])
	if not _rtts.is_empty():
		var total := 0.0
		for v in _rtts:
			total += v
		_log("RTT_MIN_MS: %.2f" % _rtts.min())
		_log("RTT_AVG_MS: %.2f" % (total / _rtts.size()))
		_log("RTT_MAX_MS: %.2f" % _rtts.max())
	_log("APP_RTT_MS: %.2f" % NetworkManager.rtt_ms)
	if not _fps_samples.is_empty():
		var fps_total := 0.0
		for v in _fps_samples:
			fps_total += v
		_log("FPS_AVG: %.0f (= ticks EOS/s)" % (fps_total / _fps_samples.size()))
	_log("SYNC_RECEIVED: %d" % (_probe.received if _probe != null else 0))
	_log("CONNECTION_TYPE: %s" % _network_type_name())
	if _spy != null:
		_log("=== MODES DE TRANSFERT OBSERVES ===")
		_log(_spy.report())
		var sync_mode := _spy.mode_for(6)
		_log("VERDICT_SYNC: %s" % PeerSpy.MODE_NAMES.get(sync_mode, "aucun paquet SYNC observé"))


# ---------------------------------------------------------------------------
# Sonde de synchronisation : même forme que celle de player.gd (30 Hz, position,
# rotation, HP), sans rien emprunter au netcode du jeu.
# ---------------------------------------------------------------------------

func _build_sync_probe(is_authority: bool) -> void:
	_probe = Node2D.new()
	_probe.name = "SyncProbe"
	_probe.set_script(preload("res://tools/sync_probe.gd"))
	add_child(_probe)
	_probe.set_multiplayer_authority(1)
	if is_authority:
		_probe.set_process(true)


## Réaffecter `multiplayer_peer` purge la liste des pairs connus de la
## MultiplayerAPI : le mouchard ne peut s'intercaler qu'avant toute connexion,
## sinon il coupe la liaison qu'il devait observer.
func _install_spy() -> void:
	if not _has("--spy"):
		return
	var real := multiplayer.multiplayer_peer
	if real == null:
		_log("SPY: ignoré (pas encore de pair — cas EOS côté client)")
		return
	if not multiplayer.get_peers().is_empty():
		_log("SPY: ignoré (connexion déjà établie)")
		return
	_spy = PeerSpy.new(real)
	multiplayer.multiplayer_peer = _spy
	_log("SPY: branché sur %s" % real.get_class())


func _network_type_name() -> String:
	match NetworkManager.eos_network_type:
		EOS.P2P.NetworkType.DirectConnection: return "DIRECT"
		EOS.P2P.NetworkType.RelayedConnection: return "RELAYE"
		EOS.P2P.NetworkType.NoConnection: return "AUCUN"
	return "N/A"


# ---------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_probe_ping(seq: int, stamp: int) -> void:
	_rpc_probe_pong.rpc_id(multiplayer.get_remote_sender_id(), seq, stamp)

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_probe_pong(seq: int, stamp: int) -> void:
	if not _sent_at.has(seq):
		return
	_rtts.append((Time.get_ticks_usec() - stamp) / 1000.0)
	_sent_at.erase(seq)


func _has(flag: String) -> bool:
	return flag in _args

func _value(flag: String, fallback: String) -> String:
	var idx := _args.find(flag)
	if idx < 0 or idx + 1 >= _args.size():
		return fallback
	return _args[idx + 1]

func _log(msg: String) -> void:
	print(msg)

func _quit(code: int) -> void:
	_log("EXIT_CODE: %d" % code)
	# Le tick supplémentaire doit s'arrêter AVANT le release de la plateforme,
	# au même titre que celui d'EOSGRuntime : ticker pendant la libération, c'est
	# le segfault garanti.
	if _extra_ticker != null:
		_extra_ticker.set_physics_process(false)
	NetworkManager.quit_game(code)
