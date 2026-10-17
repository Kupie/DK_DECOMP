extends Node

var id: String

func _ready():
	Data.listen(self, "game.over")

func propertyChanged(property: String, oldValue, newValue):
	match property:

		"game.over":
			if newValue and Data.of("team1.prestige.score") >= 1000 and GameWorld.won:
				Achievements.triggerIfOpen(id)
				Data.unlisten(self, "game.over")
				queue_free()
