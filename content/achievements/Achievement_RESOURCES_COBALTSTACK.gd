extends Node

var id: String

func _ready():
	if not Level.loadout:
		queue_free()
		return

	var localTeams: = Utils.get_local_teams(multiplayer.get_unique_id())
	for teamId in localTeams:
		Data.listen(self, teamId + ".inventory.sand")

func propertyChanged(property: String, oldValue, newValue):
	if not property.contains(".inventory.sand") or newValue < 8:
		return

	match property:

		"team1.inventory.sand":
			triggerAchievement("team1")
		"team2.inventory.sand":
			triggerAchievement("team2")

func triggerAchievement(teamId: String) -> void :
	Achievements.triggerIfOpen(id)
	Data.unlisten(self, teamId + ".inventory.sand")
	queue_free()
