class_name TeleporterStation
extends "res://content/gadgets/CellarGadget.gd"

signal state_changed

@export var synchronizer: GadgetSynchronizer
@export var effect_curve: Curve

var hasTeleporter: = true
var teleporter: Teleporter

func _ready():
	$Sprite2D.play("default")

	Style.init(self)

	Level.addTutorial(self, "teleporter_take", teamId)
	Keepers.keeper_unregistered.connect(on_keeper_removed)

func serialize() -> Dictionary:
	var data = super.serialize()
	data["hasTeleporter"] = hasTeleporter
	return data

func deserialize(data: Dictionary):
	super.deserialize(data)
	hasTeleporter = data["hasTeleporter"]
	setTeleporterStations.call_deferred()

func setTeleporterStations() -> void :
	for teleporter: Teleporter in get_tree().get_nodes_in_group("teleporters"):
		if teleporter.teamId == teamId:
			teleporter.station = self
			setTeleporter(teleporter)

func get_gadget_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(hasTeleporter)
	stream.encode_u32(teleporter.UID if is_instance_valid(teleporter) else 0)

	return stream.data

func set_gadget_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	hasTeleporter = stream.decode_bool()
	var teleporterUID: = stream.decode_u32()
	if teleporterUID != 0:
		if Level.drops.has_drop(teleporterUID):
			setTeleporter(Level.drops.get_drop(teleporterUID))
		else:
			await Level.drops.synchronizer.drop_spawned

			if Level.drops.has_drop(teleporterUID):
				setTeleporter(Level.drops.get_drop(teleporterUID))
			else:
				push_error("Could not find a teleporter of UID: %d" % teleporterUID)

func useHold(keeper: Keeper) -> bool:
	if hasTeleporter:
		return useHit(keeper)
	return false

func canFocusUse(keeper: Keeper) -> bool:
	return hasTeleporter or (teleporter and not teleporter.teleporting and not teleporter.isCarried())

func setTeleporter(new_teleporter: Teleporter):
	teleporter = new_teleporter
	teleporter.station = self
	hasTeleporter = false

	$Teleporter.queue_free()

func useHit(keeper: Keeper) -> bool:
	if teleporter and teleporter.teleporting and keeper.teamId == teamId:
		return false
	synchronizer.rpc_server(registerHit.bind(keeper.playerId))
	return true

@rpc("reliable", "any_peer")
func registerHit(playerId: String) -> void :
	if hasTeleporter:
		var spawnData: = {
			"type": CONST.TELEPORTER, 
			"team": teamId, 
			"position": $DropPosition.global_position, 
			"carriers": [playerId]
		}

		setTeleporter(Level.drops.network_spawn(spawnData))
		hasTeleporter = false
		state_changed.emit()
	elif teleporter and Data.of(teamId + ".teleporter.teleportTo") and teleporter.position.y > 50:
		synchronizer.network_rpc(networkTeleportFromStation.bind(playerId), true)

@rpc("reliable")
func networkTeleportFromStation(playerId: String) -> void :
	var keeper = Keepers.getKeeper(playerId)
	teleporter.teleporting = true
	teleporter.warpCommitted = false
	var shrinkTime: float = min(2.0, Data.of(teamId + ".teleporter.teleportDuration") * 0.33)
	var transitionTime: float = Data.of(teamId + ".teleporter.teleportDuration") - (2 * shrinkTime)
	%EffectTween.interpolate_method(self, "setEffectPower", 0.0, 1.0, shrinkTime, Tween.TRANS_SINE, Tween.EASE_OUT)
	%EffectTween.interpolate_method(self, "setEffectPower", 1.0, 0.0, 0.01, Tween.TRANS_SINE, Tween.EASE_OUT, shrinkTime)
	%EffectTween.interpolate_callback(teleporter, shrinkTime * 0.7, "set", "warpCommitted", true)
	%EffectTween.interpolate_callback(self, shrinkTime, "complete_teleport", false, keeper, shrinkTime, transitionTime)
	%EffectTween.start()
	keeper.startTeleportation(self, shrinkTime, teleportPosition(), teleporter.global_position, Data.ofOr(teamId + ".teleporter.teleportitems", false))

@rpc("reliable", "any_peer")
func teleporterRegisterHit(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)
	if teleporter.teleporting or not (teleporter.position.y > 50 and Data.of(teamId + ".teleporter.teleportBack")) and keeper.teamId == teamId:
		return

	synchronizer.network_rpc(networkTeleportFromTeleporter.bind(playerId), true)

@rpc("reliable")
func networkTeleportFromTeleporter(playerId: String) -> void :
	teleporter.startTeleportation(playerId)

func keeperWantsToAbort(keeper: Keeper):
	if not teleporter.teleporting or teleporter.warpCommitted:
		return

	synchronizer.network_rpc(networkStationAbort.bind(keeper.playerId), true)

@rpc("reliable", "any_peer")
func networkStationAbort(playerId: String) -> void :
	%EffectTween.stop_all()
	%EffectTween.remove_all()
	setEffectPower(0.0)
	var keeper
	if Keepers.hasKeeper(playerId):
		keeper = Keepers.getKeeper(playerId)
	complete_teleport(true, keeper, 0, 0.2)

func complete_teleport(abort: bool, keeper, shrinkTime: float, transitionTime: float) -> void :
	if not teleporter.teleporting:
		keeper.ensureUnlockedFromTeleport()
		return

	if not abort:
		teleporter.warpCommitted = true

	$TeleportEffect.show()
	$TeleportEffect.frame = 0
	$TeleportEffect.play()
	if is_instance_valid(keeper):
		keeper.teleportComplete()
		if not abort:
			keeper.teleport(teleporter.getTeleportPosition())
			teleporter.onTeleported(shrinkTime, transitionTime - 0.2)
		else:
			Level.viewports.abortTeleportAnimation(keeper)
			teleporter.teleporting = false
		keeper.grow(shrinkTime, transitionTime - 0.2)

func onTeleported(duration: float, delay: = 0.0):
	%EffectTween.interpolate_callback($Effects / AppearParticles, delay, "set_emitting", true)
	%EffectTween.interpolate_callback($Effects / AppearParticles2, delay, "set_emitting", true)
	%EffectTween.interpolate_callback($Effects / AppearParticles, duration + delay, "set_emitting", false)
	%EffectTween.interpolate_callback($Effects / AppearParticles2, duration + delay, "set_emitting", false)
	%EffectTween.interpolate_method(self, "setEffectPower", 0.0, 1.0, duration, Tween.TRANS_SINE, Tween.EASE_OUT)
	%EffectTween.interpolate_method(self, "setEffectPower", 1.0, 0.0, 0.01, Tween.TRANS_SINE, Tween.EASE_OUT, duration + delay)
	%EffectTween.start()

	create_tween().tween_callback(stopTeleporting).set_delay(duration + delay)

func setEffectPower(value: float):
	if not %ChargingEffect.is_playing():
		%ChargingEffect.play()

	%ChargingEffect.visible = value > 0.01
	var val = effect_curve.sample(value)
	%ChargingEffect.self_modulate.a = val

func stopTeleporting() -> void :
	teleporter.teleporting = false

func teleportPosition() -> Vector2:
	return $DropPosition.global_position

func pauseChanged():
	$Timer.paused = GameWorld.paused

@rpc("reliable")
func networkSuckAnimation(suckedResourceUID: int) -> void :
	if not is_instance_valid(teleporter):
		return

	teleporter.currentlySuckedResource = Level.drops.get_drop(suckedResourceUID)
	teleporter.startSuckAnimation()

@rpc("reliable")
func networkResourceArrived() -> void :
	if not is_instance_valid(teleporter):
		return

	teleporter.remoteArrived()

@rpc("reliable", "any_peer")
func networkTeleporterAbort(playerId: String) -> void :
	if not is_instance_valid(teleporter):
		return

	teleporter.teleportAbort(playerId)

func on_keeper_removed(keeper: Keeper) -> void :
	if not teleporter.teleporting or teleporter.currentKeeper != keeper:
		return
	keeperWantsToAbort(keeper)
