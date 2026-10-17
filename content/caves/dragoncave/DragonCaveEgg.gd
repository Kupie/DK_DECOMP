extends Sprite2D

signal hit(keeper: Keeper)
signal egg_taken

func canFocusUse(keeper: Keeper) -> bool:
	return visible

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not visible:
		return false

	hit.emit(keeper)
	return true

func registerHit(playerId: String) -> bool:
	var keeper: = Keepers.getKeeper(playerId)
	if multiplayer.is_server():
		var egg = Level.drops.network_spawn({
			"type": CONST.EGG, 
			"position": global_position, 
			"carriers": [keeper.playerId], 
			"team": keeper.teamId, 
		})
		egg.forcePetId = "pet8"

	visible = false
	egg_taken.emit()
	queue_free()
	return true
