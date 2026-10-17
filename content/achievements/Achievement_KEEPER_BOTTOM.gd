extends Node

var id: String

var goalY: float

func _ready():
	goalY = CONST.TILE_OFFSET.y + 100 * GameWorld.TILE_SIZE

func _process(delta):
	if goalY <= get_parent().position.y:
		Achievements.triggerIfOpen(id)
		queue_free()
