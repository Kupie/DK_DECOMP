extends Node

var id: String

func _ready():
	Data.listen(self, "team1.prestige.multiplier")

func propertyChanged(property: String, oldValue, newValue):
	if SaveGame.currentLoadingSavegame:
		return

	match property:

		"team1.prestige.multiplier":
			if newValue >= 10:
				Achievements.triggerIfOpen(id)
				Data.unlisten(self, "team1.prestige.multiplier")
				queue_free()
