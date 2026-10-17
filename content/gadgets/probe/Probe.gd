extends Node2D

@export var synchronizer: Synchronizer

var remainingTimeToRechargeOneCharge: float

var teamId: String
var playerId: String

var action_hint_probe: = -1

func _ready():
	Data.listen(self, teamId + ".monsters.wavepresent")
	Data.listen(self, teamId + ".probe.autorecharge")

	Achievements.addIfOpen(self, "PROBE_USE", playerId)

func addTutorials():
	Level.addTutorial(self, "probe", playerId)

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".probe.autorecharge":
		updateRechargeTime()
	elif property == teamId + ".monsters.wavepresent":
		if not newValue:
			if Data.of(teamId + ".probe.rechargeAfterBattle"):
				create_tween().tween_callback( func(): Data.apply(playerId + ".probe.chargesRemaining", Data.of(teamId + ".probe.charges"))).set_delay(0.5)
				$ProbeReadySound.startSound()

func serialize() -> Dictionary:
	var data = {
		"remainingTimeToRechargeOneCharge": remainingTimeToRechargeOneCharge
	}
	data["meta.priority"] = 200
	data["meta.kind"] = "station"
	return data

func deserialize(data: Dictionary):
	remainingTimeToRechargeOneCharge = data["remainingTimeToRechargeOneCharge"]
	updateRechargeTime()

func _process(delta):
	if GameWorld.softPaused(teamId) or not multiplayer.is_server():
		return

	if remainingTimeToRechargeOneCharge == 0.0:
		return

	var chargesRemaining = Data.of(playerId + ".probe.chargesRemaining")


	var maxCharges = Data.of(teamId + ".probe.charges")
	if chargesRemaining >= maxCharges:
		return

	remainingTimeToRechargeOneCharge -= delta
	if remainingTimeToRechargeOneCharge <= 0:
		Data.changeByInt(playerId + ".probe.chargesRemaining", 1)
		updateRechargeTime()

func canUseSpecial1(keeper: Keeper) -> bool:
	return not (keeper != get_parent() or keeper.isInsideDome or GameWorld.paused or Data.of(playerId + ".probe.chargesRemaining") == 0)

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

	var chargesRemaining = Data.of(playerId + ".probe.chargesRemaining")
	Data.apply(playerId + ".probe.chargesRemaining", chargesRemaining - 1)
	synchronizer.network_rpc(spawnProbeImpulse.bind(global_position), true)
	updateRechargeTime()

@rpc("reliable")
func spawnProbeImpulse(spawnPosition: Vector2) -> void :
	var probe = load("res://content/gadgets/probe/ProbeImpulse.tscn").instantiate()
	probe.position = spawnPosition
	probe.teamId = teamId

	Level.map.addTileOverlayEffect(probe)

func updateRechargeTime():
	if Data.of(teamId + ".probe.autorecharge") and remainingTimeToRechargeOneCharge <= 0.0 and Data.of(teamId + ".probe.charges") >= Data.of(playerId + ".probe.chargesRemaining"):


		await get_tree().process_frame
		remainingTimeToRechargeOneCharge = GameWorld.getTimeBetweenWaves(teamId) * Data.of(teamId + ".probe.rechargetime")
