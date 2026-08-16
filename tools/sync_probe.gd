## Sonde de synchronisation du banc d'essai transport.
##
## Reproduit la forme exacte du MultiplayerSynchronizer de player.gd — mêmes
## propriétés, même cadence de 30 Hz — pour que les paquets SYNC observés soient
## ceux que le jeu enverra vraiment. Elle n'emprunte rien au netcode : la
## mesurer ne doit pas pouvoir le modifier.
extends Node2D

var net_position: Vector2 = Vector2.ZERO
var net_rotation: float = 0.0
var net_flashlight_on: bool = false
var net_ack_seq: int = 0
var hp: float = 100.0

## Nombre de synchronisations reçues (côté non-autorité).
var received: int = 0

var _t: float = 0.0


func _ready() -> void:
	var sync := MultiplayerSynchronizer.new()
	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:net_position"))
	config.add_property(NodePath(".:net_rotation"))
	config.add_property(NodePath(".:net_flashlight_on"))
	config.add_property(NodePath(".:net_ack_seq"))
	config.add_property(NodePath(".:hp"))
	sync.replication_config = config
	sync.replication_interval = 1.0 / 30.0
	sync.synchronized.connect(func(): received += 1)
	add_child(sync)
	set_process(false)


## Seule l'autorité fait bouger les valeurs : sans changement, rien ne part.
func _process(delta: float) -> void:
	_t += delta
	net_position = Vector2(cos(_t) * 200.0, sin(_t) * 200.0)
	net_rotation = _t
	net_ack_seq += 1
	hp = 100.0 - fmod(_t * 5.0, 90.0)
