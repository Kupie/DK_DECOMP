class_name Treat
extends Drop

var drillbot: Drillbot

func _ready():
	super._ready()



func setCarriedBy(p):
	super.setCarriedBy(p)
	if p is not Keeper:
		return
	if Data.ofOr(p.teamId + ".drillbot.buffguidance", false):
		for driller in get_tree().get_nodes_in_group(p.teamId + "-drillbots"):
			driller.showNavigationArrow(p)

func freeCarry(p):
	super.freeCarry(p)
	if p is not Keeper:
		return
	for carryable in p.carriedCarryables:
		if carryable is Treat:
			return
	if Data.ofOr(p.teamId + ".drillbot.buffguidance", false):
		for driller in get_tree().get_nodes_in_group(p.teamId + "-drillbots"):
			driller.hideNavigationArrow(p)
