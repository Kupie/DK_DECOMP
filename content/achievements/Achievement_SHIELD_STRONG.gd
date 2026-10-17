extends Node

var id: String
var teamId: = ""

func _ready():
	teamId = get_parent().teamId
	Data.listen(self, teamId + ".shield.strength")
	Data.listen(self, teamId + ".shield.additionalstrength")

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".shield.additionalstrength":
		finishIfEnough(newValue + Data.of(teamId + ".shield.strength"))
	elif property == teamId + ".shield.strength":
		finishIfEnough(newValue + Data.of(teamId + ".shield.additionalstrength"))

func finishIfEnough(newValue):
	if newValue >= 200:
		Achievements.triggerIfOpen(id)
		Data.unlisten(self, teamId + ".shield.strength")
		Data.unlisten(self, teamId + ".shield.additionalstrength")
		queue_free()
