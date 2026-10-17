extends Node

var id: String
var teamId: = ""

func _ready():
	teamId = get_parent().teamId
	Data.listen(self, teamId + ".monsters.cycle")

func propertyChanged(property: String, oldValue, newValue):
	if SaveGame.currentLoadingSavegame:
		return

	if property == teamId + ".monsters.cycle":
		var fraction: float = Data.of(teamId + ".dome.health") / float(Data.of(teamId + ".dome.maxHealth"))
		if fraction <= 0.01:
			Achievements.triggerIfOpen(id)
			Data.unlisten(self, teamId + ".monsters.cycle")
			queue_free()
