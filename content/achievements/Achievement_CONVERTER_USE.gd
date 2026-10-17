extends Node

var id: String
var teamId: = ""

var count: = 0
var lastVal: = 0

func _ready():
	teamId = get_parent().teamId

	count = Data.ofOr(teamId + ".achievement.converter.use", 0)
	if not Data.has(teamId + ".achievement.converter.use"):
		count = Data.ofOr("achievement.converter.use", 0)
	lastVal = count

func _process(delta):
	var newVal = get_parent().state
	if newVal == 2:
		if lastVal != 2:
			lastVal = 2
			count += 1
			if count >= 10:
				Achievements.triggerIfOpen(id)
				queue_free()
			else:
				Data.apply(teamId + ".achievement.converter.use", count)
	else:
		lastVal = newVal
