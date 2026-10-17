extends Node

var id: String
var wavePresentTime: float = -2000
var enterDomeTime: float = -1000
var teamId: = ""

func _ready():
	teamId = get_parent().teamId
	Data.listen(self, teamId + ".event.keepers.insidedome")
	Data.listen(self, teamId + ".monsters.wavepresent")

func propertyChanged(property: String, oldValue, newValue):
	if SaveGame.currentLoadingSavegame:
		return

	if property == teamId + ".monsters.wavepresent":
		if newValue:
			wavePresentTime = GameWorld.runTime
			triggerIfClose()
	elif property == teamId + ".event.keepers.insidedome":
		var inDome: = (get_parent() as Keeper).isInsideDome
		if newValue and inDome:
			if GameWorld.runTime - enterDomeTime < 20.0:

				enterDomeTime = GameWorld.runTime
			else:
				enterDomeTime = GameWorld.runTime
				triggerIfClose()

func triggerIfClose():
	if abs(wavePresentTime - enterDomeTime) <= 1.0:
		Achievements.triggerIfOpen(id)
		Data.unlisten(self, teamId + ".monsters.wavepresent")
		Data.unlisten(self, teamId + ".event.keepers.insidedome")
		queue_free()
