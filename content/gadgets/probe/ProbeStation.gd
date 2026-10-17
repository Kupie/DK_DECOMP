extends "res://content/gadgets/CellarGadget.gd"

@export var synchronizer: GadgetSynchronizer

signal state_changed

var charging: = false
var chargingKeeper: Keeper

func get_gadget_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(charging)
	stream.encode_var(chargingKeeper.playerId if is_instance_valid(chargingKeeper) else "")
	return stream.data

func set_gadget_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	charging = stream.decode_bool()
	var playerId: String = stream.decode_var()
	chargingKeeper = Keepers.getKeeper(playerId) if playerId != "" else null

func _ready():
	for keeper in Keepers.getAllOfTeam(teamId):
		Data.apply(keeper.playerId + ".probe.chargesRemaining", Data.of(teamId + ".probe.charges"))
		Data.listen(self, keeper.playerId + ".probe.chargesRemaining")
	Data.listen(self, teamId + ".probe.charges")
	$Sprite2D.play("off")

	Data.listen(self, teamId + ".probe.hasstation")

	Style.init(self)

func canFocusUse(keeper: Keeper) -> bool:
	return not charging and Data.of(keeper.playerId + ".probe.chargesRemaining") < Data.of(teamId + ".probe.charges") and teamId == keeper.teamId

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not canFocusUse(keeper):
		return false

	synchronizer.rpc_server(registerHit.bind(keeper.playerId))
	return true

@rpc("reliable", "any_peer")
func registerHit(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)
	if not canFocusUse(keeper):
		return

	synchronizer.network_rpc(moveKeeperToStation.bind(playerId), true)

@rpc("reliable")
func moveKeeperToStation(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)
	keeper.externallyMoved = true
	keeper.move *= 0
	$Tween.interpolate_property(keeper, "position", keeper.position, $KeeperPos.global_position, 0.2, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	$Tween.start()
	chargingKeeper = keeper
	get_tree().create_timer(0.3).timeout.connect(_on_tree_timer_timeout.bind(keeper))

func _on_tree_timer_timeout(keeper) -> void :
	var p1 = Vector2($Slider.position.x, -20)
	var p2 = Vector2($Slider.position.x, -4)
	$Tween.interpolate_property($Slider, "position", p1, p2, 0.2, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	$Tween.interpolate_property($Slider, "position", p2, p1, 0.2, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, 0.2)
	$Tween.interpolate_property($Slider, "position", p1, p2, 0.2, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, 0.4)
	$Tween.interpolate_property($Slider, "position", p2, p1, 0.2, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, 0.6)
	$Tween.interpolate_property($Slider, "position", p1, p2, 0.2, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, 0.8)
	$Tween.interpolate_property($Slider, "position", p2, p1, 0.2, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, 1.0)
	$Tween.interpolate_callback(keeper, 1.2, "set", "externallyMoved", false)
	if multiplayer.is_server():
		$Tween.interpolate_callback(Data, 1.2, "apply", keeper.playerId + ".probe.chargesRemaining", Data.of(teamId + ".probe.charges"))
	$Tween.start()
	charging = true
	$ChargeSound.startSound()
	if multiplayer.is_server():
		state_changed.emit()

func propertyChanged(property: String, oldValue, newValue):
	if property.ends_with(".probe.chargesremaining"):
		var on: = false
		for keeper in Keepers.getAllOfTeam(teamId):
			var key = keeper.playerId + ".probe.chargesremaining"
			if Data.of(key) < Data.of(teamId + ".probe.charges"):
				on = true

		if on:
			$Sprite2D.play("on")
		else:
			$Sprite2D.play("off")

		if oldValue == null or newValue > oldValue:
			charging = false
			chargingKeeper = null
			if multiplayer.is_server():
				state_changed.emit()
		return
	elif property == teamId + ".probe.charges":

		if SaveGame.currentLoadingSavegame:
			return
		for keeper in Keepers.getAllOfTeam(teamId):
			var key = keeper.playerId + ".probe.chargesremaining"
			Data.apply(key, Data.of(teamId + ".probe.charges"))
	elif property == teamId + ".probe.hasstation":
		if not newValue:
			queue_free()
			if is_instance_valid(chargingKeeper):
				chargingKeeper.externallyMoved = false
			if multiplayer.is_server():
				for keeper in Keepers.getAll():
					var playerId: = keeper.playerId
					var idToCheck = playerId + ".probe"
					if GameWorld.upgrades.has(idToCheck):
						GameWorld.upgrades[idToCheck]["scenes"].erase("cellar")
				GameWorld.availableTechSlots.append(teamId + ".cellar")
