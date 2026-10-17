extends Node2D

@export var synchronizer: Synchronizer

var teamId: String
var playerId: String

var remainingRechargeTime: float
var totalRechargeTime: float

var action_hint: = -1
var useCooldown: = 0.0

var resourcePackerEffects: = {}

func _ready():
	playerId = get_parent().playerId






	Data.listen(self, teamId + ".resourcepacker.charges")
	Data.listen(self, teamId + ".resourcepacker.packscale")
	Data.listen(self, teamId + ".resourcepacker.rechargetime")
	Data.apply(playerId + ".resourcepacker.chargesremaining", Data.ofOr(playerId + ".resourcepacker.chargesremaining", Data.of(teamId + ".resourcepacker.charges")))

	Level.addTutorial(self, "resourcepacker", playerId)


func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".resourcepacker.charges":
		if oldValue != newValue:
			Data.apply(playerId + ".resourcepacker.chargesremaining", newValue)
			checkStartRecharge()
	elif property == teamId + ".resourcepacker.packscale":
		if newValue > oldValue:
			reset_data.call_deferred(teamId + ".resourcepacker.packscale", oldValue)
	elif property == teamId + ".resourcepacker.rechargetime":
		if newValue > oldValue:
			reset_data.call_deferred(teamId + ".resourcepacker.rechargetime", oldValue)

func reset_data(id: String, val):
	Data.apply(id, val)

func addTutorials():
	Level.addTutorial(self, "resourcepacker", playerId)

func serialize() -> Dictionary:
	var data = {
		"remainingRechargeTime": remainingRechargeTime, 
		"totalRechargeTime": totalRechargeTime
	}
	data["meta.priority"] = 200
	data["meta.kind"] = "station"
	return data

func deserialize(data: Dictionary):
	remainingRechargeTime = data["remainingRechargeTime"]
	totalRechargeTime = data["totalRechargeTime"]

func _process(delta):
	if GameWorld.paused or not multiplayer.is_server():
		return

	var charges = Data.of(playerId + ".resourcepacker.chargesremaining")


	if useCooldown > 0.0:
		useCooldown -= delta

	if totalRechargeTime == 0.0:
		return

	remainingRechargeTime -= delta
	if remainingRechargeTime <= 0:
		Data.changeByInt(playerId + ".resourcepacker.chargesremaining", 1)
		checkStartRecharge()

func checkStartRecharge():
	totalRechargeTime = 0.0
	if Data.of(playerId + ".resourcepacker.chargesremaining") < Data.of(teamId + ".resourcepacker.charges"):
		totalRechargeTime = Data.of(teamId + ".resourcepacker.rechargetime")
		remainingRechargeTime = totalRechargeTime

func canUseSpecial1(keeper: Keeper) -> bool:
	return keeper == get_parent() and not keeper.isInsideDome and not GameWorld.paused and useCooldown <= 0.0 and Data.of(keeper.playerId + ".resourcepacker.chargesremaining") > 0

func executeSpecial1(keeper: Keeper) -> bool:
	if not canUseSpecial1(keeper):
		var chargesremaining = Data.of(keeper.playerId + ".resourcepacker.chargesremaining")
		if chargesremaining == 0:
			Audio.sound("gui_err")
		return false

	synchronizer.rpc_server(serverExecuteSpecial1.bind(keeper.playerId))
	return true

@rpc("reliable", "any_peer")
func serverExecuteSpecial1(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)
	if not canUseSpecial1(keeper):
		return

	useCooldown = Data.of(teamId + ".resourcepacker.cooldown")
	var chargesremaining = Data.of(playerId + ".resourcepacker.chargesremaining")
	if chargesremaining > 0:
		Data.apply(playerId + ".resourcepacker.chargesremaining", chargesremaining - 1)
		checkStartRecharge()

		var uid = randi()
		synchronizer.network_rpc(spawnResourcePackerEffect.bind(keeper.playerId, uid), true)

@rpc("reliable")
func spawnResourcePackerEffect(playerId: String, uid: int) -> void :
	var keeper: = Keepers.getKeeper(playerId)
	$PackingSound.startSound()
	var resourcepacker = preload("res://content/gadgets/ressourcepacker/ResourcePackerEffect.tscn").instantiate()
	resourcepacker.UID = uid
	resourcepacker.teamId = teamId
	resourcepacker.position = global_position
	resourcepacker.set_carrier(keeper)
	resourcePackerEffects[uid] = resourcepacker
	Level.map.addTileOverlayEffect(resourcepacker)

	if multiplayer.is_server():
		resourcepacker.packedDropCreated.connect(networkCreatePackedDrop)

func networkCreatePackedDrop(UID: int, dropsAndPositions: Dictionary) -> void :
	synchronizer.network_rpc(createPackedDrop.bind(UID, dropsAndPositions), true)

@rpc("reliable")
func createPackedDrop(UID: int, dropsAndPositions: Dictionary) -> void :
	if not resourcePackerEffects.has(UID):
		return
	var resourcePackerEffect: = resourcePackerEffects[UID] as ResourcePackerEffect
	resourcePackerEffect.create_packed_drop(dropsAndPositions)
