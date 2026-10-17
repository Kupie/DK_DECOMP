extends Node

var id: String

func _process(delta):
	for keeper: Keeper in Keepers.local.getAll():
		if GameWorld.runStats.get(keeper.teamId + ".lift_carried_drops", 0) >= 200:
			Achievements.triggerIfOpen(id)
			queue_free()
