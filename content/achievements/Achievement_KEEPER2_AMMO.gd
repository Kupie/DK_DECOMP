extends Node

var id: String

func _ready():
	var keeper: = get_parent() as Keeper2
	if keeper:
		keeper.remainingSpheresChanged.connect(onRemainingSpheresChanged)

func onRemainingSpheresChanged(newValue: int):
	if SaveGame.currentLoadingSavegame:
		return

	if newValue == 6:
		Achievements.triggerIfOpen(id)
		queue_free()
