extends Node

var id: String

func _ready():
	Data.listen(self, "team1.prestige.score")

func propertyChanged(property: String, oldValue, newValue):
	if SaveGame.currentLoadingSavegame:
		return

	match property:

		"team1.prestige.score":
			if newValue - oldValue >= 200:
				Achievements.triggerIfOpen(id)
				Data.unlisten(self, "team1.prestige.score")
				queue_free()
