class_name Spore
extends Carryable

signal infectSoundPlayed(UID: int)

var type: = CONST.SPORE
@export var infectSound: Node

func _ready():
	super._ready()
	Style.init(self)

func _on_body_entered(body: Node) -> void :
	if not multiplayer.is_server():
		return

	if body is Tile and not isCarried() and not body.hasTileOverlay():
		infectSoundPlayed.emit(UID)
		Level.map.tiles_node.network_infect_tile(body.coord, teamId, UID)
		Level.drops.network_free_drop(UID)


func playInfectSound():
	infectSound.startSound()
