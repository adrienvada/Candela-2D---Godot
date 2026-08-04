## Mouchard de transport : s'intercale entre la MultiplayerAPI et le vrai pair
## réseau, et relève le mode de transfert demandé par Godot pour CHAQUE paquet
## sortant.
##
## Outil de mesure uniquement (Mission B) : jamais branché par le jeu. Le
## premier octet d'un paquet SceneMultiplayer porte la commande sur ses 3 bits
## de poids faible — 6 = SYNC, c'est-à-dire les paquets du
## MultiplayerSynchronizer (position, rotation, HP à 30 Hz).
class_name PeerSpy
extends MultiplayerPeerExtension

const CMD_NAMES := {
	0: "REMOTE_CALL", 1: "SIMPLIFY_PATH", 2: "CONFIRM_PATH", 3: "RAW",
	4: "SPAWN", 5: "DESPAWN", 6: "SYNC", 7: "SYS",
}
const MODE_NAMES := {
	MultiplayerPeer.TRANSFER_MODE_UNRELIABLE: "unreliable",
	MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED: "unreliable_ordered",
	MultiplayerPeer.TRANSFER_MODE_RELIABLE: "reliable",
}

var inner: MultiplayerPeer
## commande → { mode → nombre de paquets }
var sent: Dictionary = {}

func _init(p_inner: MultiplayerPeer = null) -> void:
	if p_inner != null:
		attach(p_inner)

func attach(p_inner: MultiplayerPeer) -> void:
	inner = p_inner
	# La MultiplayerAPI écoute le pair qu'on lui donne, pas celui du dessous :
	# sans ce relais elle ne verrait jamais personne se connecter.
	inner.peer_connected.connect(func(id: int): peer_connected.emit(id))
	inner.peer_disconnected.connect(func(id: int): peer_disconnected.emit(id))

func report() -> String:
	var lines: Array[String] = []
	for cmd in sent.keys():
		for mode in sent[cmd].keys():
			lines.append("  %-14s %-18s %d paquets" % [
				CMD_NAMES.get(cmd, "CMD_%d" % cmd),
				MODE_NAMES.get(mode, "mode_%d" % mode),
				sent[cmd][mode],
			])
	lines.sort()
	return "\n".join(lines)

## Mode observé pour une commande, ou -1 si elle n'a jamais été émise.
## Plus d'un mode pour la même commande renvoie -2 : le cas mérite d'être vu.
func mode_for(cmd: int) -> int:
	if not sent.has(cmd):
		return -1
	var modes: Array = sent[cmd].keys()
	return modes[0] if modes.size() == 1 else -2

# --- Surcharges MultiplayerPeerExtension --------------------------------------

func _put_packet_script(buffer: PackedByteArray) -> Error:
	if buffer.size() > 0:
		var cmd := buffer[0] & 7
		var mode := inner.get_transfer_mode()
		if not sent.has(cmd):
			sent[cmd] = {}
		sent[cmd][mode] = sent[cmd].get(mode, 0) + 1
	return inner.put_packet(buffer)

func _get_packet_script() -> PackedByteArray:
	return inner.get_packet()

func _get_available_packet_count() -> int:
	return inner.get_available_packet_count()

func _get_max_packet_size() -> int:
	return inner.get_max_packet_size()

func _get_packet_channel() -> int:
	return inner.get_packet_channel()

func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return inner.get_packet_mode()

func _set_transfer_channel(channel: int) -> void:
	inner.transfer_channel = channel

func _get_transfer_channel() -> int:
	return inner.transfer_channel

func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	inner.transfer_mode = mode

func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return inner.transfer_mode

func _set_target_peer(peer: int) -> void:
	inner.set_target_peer(peer)

func _get_packet_peer() -> int:
	return inner.get_packet_peer()

func _is_server() -> bool:
	return inner.is_server()

func _poll() -> void:
	inner.poll()

func _close() -> void:
	inner.close()

func _disconnect_peer(peer: int, force: bool) -> void:
	inner.disconnect_peer(peer, force)

func _get_unique_id() -> int:
	return inner.get_unique_id()

func _set_refuse_new_connections(enable: bool) -> void:
	inner.refuse_new_connections = enable

func _is_refusing_new_connections() -> bool:
	return inner.refuse_new_connections

func _is_server_relay_supported() -> bool:
	return inner.is_server_relay_supported()

func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return inner.get_connection_status()
