extends Node

var id: String
var teamId: = ""

func _ready():
	teamId = get_parent().teamId
	for keeper in Keepers.local.getAllFromTeam(teamId):
		Data.listen(self, keeper.playerId + ".orchard.remainingbuffduration")

func propertyChanged(property: String, oldValue, newValue):
	if newValue >= 0.74 * GameWorld.getTimeBetweenWaves(teamId):
		Achievements.triggerIfOpen(id)
		for keeper in Keepers.local.getAllFromTeam(teamId):
			Data.unlisten(self, keeper.playerId + ".orchard.remainingbuffduration")
		queue_free()
