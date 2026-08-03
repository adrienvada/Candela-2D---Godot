extends Node


enum GameMode { LOCAL_SPLITSCREEN, ONLINE_HOST, ONLINE_CLIENT }
var current_mode: GameMode = GameMode.LOCAL_SPLITSCREEN

const DEFAULT_PORT := 7777
const MAX_CLIENTS  := 1 # Only 1v1 (1 Host + 1 Client)

var peer: ENetMultiplayerPeer

# Écho applicatif plutôt que le RTT interne d'ENet : c'est le délai réellement
# subi par la boucle de jeu (files d'attente, cadence de traitement) qui sert
# à compenser les tirs, et lui seul est comparable des deux côtés.
const PING_INTERVAL := 1.0
const RTT_SMOOTHING := 0.3

var rtt_ms: float = 0.0
var has_rtt: bool = false
var _ping_accum: float = 0.0

signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_failed
signal connection_success
signal host_disconnected

func host_game(port: int = DEFAULT_PORT) -> void:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("NetworkManager: create_server failed — error %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	current_mode = GameMode.ONLINE_HOST
	_connect_signals()
	print("NetworkManager: hosting on port %d" % port)

func join_game(address: String, port: int = DEFAULT_PORT) -> void:
	if address.is_empty():
		address = "127.0.0.1"
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: create_client failed — error %d" % err)
		return
	multiplayer.multiplayer_peer = peer
	current_mode = GameMode.ONLINE_CLIENT
	_connect_signals()
	print("NetworkManager: connecting to %s:%d" % [address, port])

func disconnect_from_game() -> void:
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null
	current_mode = GameMode.LOCAL_SPLITSCREEN
	_reset_rtt()

func _process(delta: float) -> void:
	var target := _remote_peer()
	if target == 0:
		_reset_rtt()
		return
	_ping_accum += delta
	if _ping_accum < PING_INTERVAL:
		return
	_ping_accum = 0.0
	rpc_id(target, "rpc_ping", Time.get_ticks_msec())

## Unique interlocuteur (1v1) : l'hôte pour le client, le client pour l'hôte.
func _remote_peer() -> int:
	if current_mode == GameMode.LOCAL_SPLITSCREEN or not multiplayer.has_multiplayer_peer():
		return 0
	var peers := multiplayer.get_peers()
	return peers[0] if peers.size() > 0 else 0

func _reset_rtt() -> void:
	rtt_ms = 0.0
	has_rtt = false
	_ping_accum = 0.0

## L'horodatage repart tel quel : seul l'émetteur l'interprète, aucune horloge
## commune n'est nécessaire.
@rpc("any_peer", "unreliable")
func rpc_ping(stamp: int) -> void:
	rpc_id(multiplayer.get_remote_sender_id(), "rpc_pong", stamp)

@rpc("any_peer", "unreliable")
func rpc_pong(stamp: int) -> void:
	var sample := float(Time.get_ticks_msec() - stamp)
	rtt_ms = sample if not has_rtt else lerpf(rtt_ms, sample, RTT_SMOOTHING)
	has_rtt = true

func _connect_signals() -> void:
	# Avoid connecting multiple times
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
		multiplayer.connection_failed.connect(_on_connection_failed)

func _on_peer_connected(id: int) -> void:
	print("NetworkManager: peer connected — id %d" % id)
	if peer:
		var p = peer.get_peer(id)
		if p:
			p.set_timeout(0, 1500, 3000)
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: peer disconnected — id %d" % id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	print("NetworkManager: connected to server — my id is %d" % multiplayer.get_unique_id())
	connection_success.emit()

func _on_connection_failed() -> void:
	push_error("NetworkManager: connection failed")
	connection_failed.emit()


func _on_server_disconnected() -> void:
	print("NetworkManager: server disconnected")
	current_mode = GameMode.LOCAL_SPLITSCREEN
	host_disconnected.emit()
