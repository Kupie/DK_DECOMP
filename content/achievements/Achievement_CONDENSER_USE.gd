extends Node

var id: String
var teamId: = ""

var count: = 0
var lastVal: = 0

func _ready():
	teamId = get_parent().teamId

	if not Data.has(teamId + ".achievement.condenser.use"):
		count = Data.ofOr("achievement.condenser.use", 0)
	else:
		count = Data.ofOr(teamId + ".achievement.condenser.use", 0)

func _process(delta):
	var newVal = get_parent().resourceCount
	var d = lastVal - newVal
	lastVal = newVal

	if d > 0:
		count += d
		Data.apply(teamId + ".achievement.condenser.use", count)

	if count >= 10:
		Achievements.triggerIfOpen(id)
		queue_free()
