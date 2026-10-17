extends Node

var id: String
var teamId: = ""

func _ready():
	teamId = get_parent().teamId
	Level.drops.synchronizer.drop_picked_up.connect(_drop_picked_up)

func _drop_picked_up(carryable: Carryable, keeper: Keeper) -> void :
	var relHealth = Data.of(teamId + ".dome.health") / float(Data.of(teamId + ".dome.maxhealth"))
	if not relHealth <= 0.1 or keeper.teamId != teamId:
		return

	if carryable is not Drop or carryable.type != CONST.SAND:
		return

	Achievements.triggerIfOpen(id)
	queue_free()
