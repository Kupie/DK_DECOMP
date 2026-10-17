extends Area2D

signal relic_recovered

@export var synchronizer: Synchronizer

var teamId: String

func dropTarget() -> Vector2:
	return global_position

func arrived(relic):
	Level.drops.network_shrink(relic, teamId)
	synchronizer.network_rpc(_emit_relic_recovered, true)

@rpc("reliable", "any_peer")
func _emit_relic_recovered():
	relic_recovered.emit()

func _on_RelicDropPoint_area_entered(area):
	var drop = area.getDeliverableDrop("relic")

	if not drop:
		return

	if Keepers.hasKeeper(drop.lastCarriedPlayerId):
		var lastCarrier = Keepers.getKeeper(drop.lastCarriedPlayerId)
		if lastCarrier.teamId != teamId:
			return

	drop.floatToDropTarget(self)
	drop.teamId = teamId
