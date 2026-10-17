extends Node2D

@export var synchronizer: Synchronizer

var teamId: String
var playerId: String

var action_hint: = -1

func _ready():
	Data.apply(playerId + ".suitblaster.charge", Data.ofOr(playerId + ".suitblaster.charge", 1.0))
	Data.listen(self, teamId + ".suitblaster.maxcharge")

	Level.addTutorial(self, "suitblaster", playerId)


func propertyChanged(property: String, oldValue, newValue):
	var diff = newValue - oldValue
	var charge = Data.of(playerId + ".suitblaster.charge")
	Data.apply(playerId + ".suitblaster.charge", min(charge + diff, newValue))

func serialize() -> Dictionary:
	var data = {
	}
	data["meta.priority"] = 200
	data["meta.kind"] = "station"
	return data

func deserialize(data: Dictionary):
	pass

func _process(delta):
	if GameWorld.softPaused(teamId) or not multiplayer.is_server():
		return
	var oldcharge = Data.of(playerId + ".suitblaster.charge")
	var mod = 1.0 + floor(oldcharge) * Data.of(teamId + ".suitblaster.chargespeedpercharge")
	var newcharge = min(Data.of(teamId + ".suitblaster.maxcharge"), oldcharge + mod * Data.of(teamId + ".suitblaster.chargespeed") * delta / GameWorld.getTimeBetweenWaves(teamId))
	if oldcharge != newcharge:
		Data.apply(playerId + ".suitblaster.charge", newcharge)



func canUseSpecial1(keeper: Keeper) -> bool:
	return (keeper == get_parent() and not keeper.isInsideDome and not GameWorld.paused and Data.ofOr(keeper.playerId + ".suitblaster.charge", 0.0) >= 1.0)

func executeSpecial1(keeper: Keeper) -> bool:
	if not canUseSpecial1(keeper):
		return false

	synchronizer.rpc_server(serverExecuteSpecial1.bind(keeper.playerId))
	return true

@rpc("reliable", "any_peer")
func serverExecuteSpecial1(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)
	if not canUseSpecial1(keeper):
		return

	Data.changeByInt(playerId + ".suitblaster.charge", -1.0)
	Backend.event("gadget_used", {"gadget": "suitblaster"})
	GameWorld.incrementRunStat("suitblasts_used", teamId)

	synchronizer.network_rpc(spawnSuitBlasterExplosion.bind(playerId), true)

@rpc("reliable")
func spawnSuitBlasterExplosion(playerId: String) -> void :
	var inst = preload("res://content/gadgets/suitblaster/SuitblasterExplosion.tscn").instantiate()
	inst.teamId = teamId
	Level.map.add_child(inst)

	var keeper: = Keepers.getKeeper(playerId)
	inst.setup(keeper)
