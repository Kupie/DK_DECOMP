extends Node

var id: String

func _process(delta):
	for keeper in Keepers.local.getAll():
		if GameWorld.achievementStats.get(keeper.playerId + ".travelledDistance", 0) * CONST.PixelPerKilometer >= 21.097:
			Achievements.triggerIfOpen(id)
			queue_free()
