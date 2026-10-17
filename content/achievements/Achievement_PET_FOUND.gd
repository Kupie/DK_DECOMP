extends Node

var id: String

func _process(delta):
	var egg: = get_parent() as Egg
	if egg.hatched and Keepers.get_team(egg.teamId).oneInsideDome():
		Achievements.triggerIfOpen(id)
		queue_free()
