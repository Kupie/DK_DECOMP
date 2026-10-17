extends Node

var id: String

func _process(delta):
	for keeper: Keeper in Keepers.local.getAll():
		if GameWorld.achievementStats.get(keeper.playerId + ".blastcharges_used", 0) >= 15:
			Achievements.triggerIfOpen(id)
			queue_free()
