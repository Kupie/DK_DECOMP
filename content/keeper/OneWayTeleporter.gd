class_name OneWayTeleporter extends Node2D

@export var synchronizer: Synchronizer

var teamId: String
var playerId: String

var teleporting: = false

var action_hint_teleport: = -1

func _ready():
	playerId = get_parent().playerId
	Data.apply(playerId + ".keeper.onewayteleportercooldown", 0)
	Data.apply(playerId + ".keeper.onewayteleporterportalpresent", false)

func addTutorials():
	Level.addTutorial(self, "onewayteleporter", playerId)

func serialize() -> Dictionary:
	var data = {}
	data["playerId"] = playerId
	data["teleporting"] = teleporting
	data["meta.priority"] = 200
	data["meta.kind"] = "station"
	return data

func deserialize(data: Dictionary):
	playerId = data["playerId"]
	teleporting = data["teleporting"]

func _process(delta):
	if GameWorld.softPaused(teamId):
		return

	var cooldown = Data.ofOr(playerId + ".keeper.onewayteleportercooldown", 0)
	if cooldown > 0.0:
		cooldown -= delta * GameWorld.cycleSpeed
		Data.apply(playerId + ".keeper.onewayteleportercooldown", cooldown)

func executeSpecial2(keeper: Keeper) -> bool:
	if keeper != get_parent() or GameWorld.paused:
		return false
	var cooldown = Data.ofOr(playerId + ".keeper.onewayteleportercooldown", 0)
	if cooldown > 0 or GameWorld.paused or teleporting:
		Audio.sound("gui_err")
		return false

	synchronizer.rpc_server(serverExecuteSpecial2.bind(playerId))
	return true

@rpc("reliable")
func playErrorSound() -> void :
	Audio.sound("gui_err")

@rpc("reliable", "any_peer")
func serverExecuteSpecial2(playerId: String) -> void :
	var keeper = Keepers.getKeeper(playerId)

	if keeper != get_parent() or GameWorld.paused:
		return

	var sender_id = multiplayer.get_remote_sender_id()

	var cooldown = Data.ofOr(playerId + ".keeper.onewayteleportercooldown", 0)
	if cooldown > 0 or GameWorld.paused or teleporting:
		synchronizer.rpc_or_local(sender_id, playErrorSound)
		return

	var portals = get_tree().get_nodes_in_group(playerId + "-onewayteleporter")

	if not portals.is_empty():
		synchronizer.network_rpc(executeSpecial2Teleport.bind(keeper.playerId), true)
		Data.apply(playerId + ".keeper.onewayteleporterportalpresent", false)
	elif not keeper.isInsideDome and keeper.position.y > 50:
		synchronizer.network_rpc(createTeleporterEye.bind(keeper.playerId, keeper.position), true)
		Data.apply(playerId + ".keeper.onewayteleporterportalpresent", true)
	else:
		synchronizer.rpc_or_local(sender_id, playErrorSound)

@rpc("reliable")
func createTeleporterEye(playerId: String, pos: Vector2) -> void :
	var keeperPlacedEye = preload("res://content/caves/teleportcave/TeleporterEye.tscn").instantiate()
	keeperPlacedEye.position = pos
	keeperPlacedEye.add_to_group(playerId + "-onewayteleporter")
	Level.map.add_child(keeperPlacedEye)

@rpc("reliable")
func executeSpecial2Teleport(playerId: String):
	var keeper = Keepers.getKeeper(playerId)
	var portals = get_tree().get_nodes_in_group(playerId + "-onewayteleporter")
	if portals.is_empty():
		return

	teleporting = true
	var shrinkTime: = 0.5
	var transitionTime: float = 0.5

	var eye = portals.front()
	keeper.startTeleportation(self, shrinkTime, keeper.global_position, eye.global_position, true, true)

	await get_tree().create_timer(shrinkTime).timeout

	if teleporting:
		complete_teleport(keeper, false, shrinkTime, transitionTime)

func complete_teleport(keeper: Keeper, abort: bool, shrinkTime, transitionTime):
	var portals = get_tree().get_nodes_in_group(playerId + "-onewayteleporter")
	if portals.is_empty():
		abort = true

	keeper.teleportComplete()
	keeper.grow(shrinkTime, transitionTime - 0.2)

	if not abort:
		var eye = portals.front()
		keeper.teleport(eye.position)
		if multiplayer.is_server():
			var maxCooldown = Data.of(playerId + ".keeper.onewayteleportermaxcooldown")
			Data.apply(playerId + ".keeper.onewayteleportermaxcooldown", maxCooldown)
			Data.apply(playerId + ".keeper.onewayteleportercooldown", maxCooldown)
		eye.onUsed()
	else:
		Level.viewports.abortTeleportAnimation(keeper)
	teleporting = false

func keeperWantsToAbort(keeper: Keeper):
	if not teleporting:
		return

	synchronizer.network_rpc(remoteCompleteTeleport.bind(keeper.playerId, true, 0, 0.2), true)

@rpc("reliable", "any_peer")
func remoteCompleteTeleport(playerId: String, abort: bool, shrinkTime: float, transitionTime: float) -> void :
	if not teleporting:
		return

	complete_teleport(Keepers.getKeeper(playerId), true, 0, 0.2)
