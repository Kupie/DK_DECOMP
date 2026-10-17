extends Node

var id: String
var teamId: String

var markers: = []

func _process(delta):
	for m in get_tree().get_nodes_in_group(teamId + "-probe_markers"):
		if not markers.has(m.tileCoord):
			markers.append(m.tileCoord)
	if markers.size() >= 15:
		Achievements.triggerIfOpen(id)
		Data.unlisten(self, teamId + ".monsters.cycle")
		queue_free()

func _ready():
	teamId = get_parent().teamId
	Data.listen(self, teamId + ".monsters.cycle")

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".monsters.cycle":
		if newValue:
			markers.clear()
