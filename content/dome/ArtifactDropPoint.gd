extends Area2D

var teamId: String

func dropTarget() -> Vector2:
	return global_position

func arrived(gadget):
	gadget.teamId = teamId
	Level.drops.network_shred(gadget, teamId)

func _on_ArtifactDropPoint_area_entered(area):
	var drop = area.getDeliverableDrop(CONST.GADGET)
	if not drop:
		drop = area.getDeliverableDrop(CONST.POWERCORE)

	if not drop:
		return

	if Keepers.hasKeeper(drop.lastCarriedPlayerId):
		var lastCarrier = Keepers.getKeeper(drop.lastCarriedPlayerId)
		if lastCarrier.teamId != teamId:
			return

	drop.floatToDropTarget(self)
	drop.teamId = teamId
