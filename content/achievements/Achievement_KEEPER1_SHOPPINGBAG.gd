extends Node

var id: String
var keeper: Keeper

func _ready():
	keeper = get_parent() as Keeper
	Data.listen(self, keeper.teamId + ".event.keepers.insidedome")

func propertyChanged(property: String, oldValue, newValue):
	if property == keeper.teamId + ".event.keepers.insidedome":
		if not keeper.isInsideDome:
			return
		if keeper.carriedCarryables.size() >= 20:
			Achievements.triggerIfOpen(id)
			Data.unlisten(self, keeper.teamId + ".event.keepers.insidedome")
			queue_free()
