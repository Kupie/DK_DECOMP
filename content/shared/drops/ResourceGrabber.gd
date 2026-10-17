class_name ResourceGrabber
extends Area2D

signal grabbed_resource

@export var dropType: = ""

var spent: = false
var teamId: String

func dropTarget() -> Vector2:
	return global_position

func arrived(gadget):

	if not multiplayer.is_server():
		return

	Level.drops.network_free_drop(gadget.UID)
	Data.changeByInt("inventory.floating" + gadget.type, -1)
	grabbed_resource.emit()

func _on_ResourceGrabber_area_entered(area):
	if not is_instance_valid(area):
		return
	if spent or not multiplayer.is_server():
		return

	if area.canBeDelivered():
		var drop = area.getDeliverableDrop(dropType)
		if drop and drop.teamId != "":
			for carrier in drop.carriedBy:
				if carrier is Goblin:
					Level.drops.network_goblin_release(drop, carrier)

			drop.floatToDropTarget(self)
			Level.drops.network_set_independent(drop, true)
			teamId = drop.teamId
			spent = true

func disable():
	set_deferred("monitoring", false)

func enable():
	set_deferred("monitoring", true)
