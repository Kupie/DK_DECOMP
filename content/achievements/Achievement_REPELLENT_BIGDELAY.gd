extends Node

var id: String
var teamId: = ""

func _ready():
	teamId = get_parent().teamId
	Data.listen(self, teamId + ".repellent.delayedcycles")

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".repellent.delayedcycles":
		if oldValue and newValue:
			var diff = newValue - oldValue
			if diff >= 0.5:
				Achievements.triggerIfOpen(id)
				queue_free()
