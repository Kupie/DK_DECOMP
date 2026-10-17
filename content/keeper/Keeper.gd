extends CharacterBody2D

class_name Keeper

signal mined
signal before_killed

@export var techId: = ""
@export var hasMouseGameplay: = false
var playerId: String
var skinId: String
var colorId: String
var remapColorIdPerPalette: bool
var playerName: String
var deviceId: int
var peerId: int
var teamId: String:
	set(value):
		teamId = value
		set_collision_mask_value(CONST.LAYER_BLOCKER_TEAM_1, value == "team1")
		set_collision_mask_value(CONST.LAYER_BLOCKER_TEAM_2, value == "team2")
var goalCameraZoom: float = 4

var disabled: = false
var disable_source = null
var tutorialsActive: = false
var showcaseMode: = false
var killed: = false

var usables: = []
var carryables: = []
var focussedUsable
var focussedCarryable

var moveDirectionInput: = Vector2()
var aimDirectionInput: = Vector2()
var move: = Vector2()
var prevPosition: Vector2
var externallyMoved: = false
const moveDirectionThreshold: = 0.05
const mouseTooCloseThreshold: = 15
var pickupType: = ""
var pressingUse: = false

var animationSuffix: = ""

var carriedCarryables: = []

var isInsideDome: bool
var isInsideStation: bool
var virtuallyIsInsideDome: bool: set = setIsVirtuallyInsideDome

var temporaryBuffs: Array[TemporaryBuff] = []
var isMovementDummy: = false

var _cameraRef: CameraBase
var initialized: = false

var input_settings: KeeperInputSettings

@onready var _nameTagPositioner: Node2D = $NameTagPositioner
var _station: Node

@export_group("Node Assignments")
@export var keeper_sprite: AnimatedSprite2D
@export var keeper_light: KeeperLight
@export var trail_particles: GPUParticles2D
@export var synchronizer: KeeperSynchronizer

var _remote_camera_target: Vector2

func _ready() -> void :
	add_to_group("keepers-changed-listener")

func init():
	if playerId == "":
		Logger.error("playerId is not set before initialising the keeper", "Keeper.init")
	Achievements.addIfOpen(self, "KEEPER_BOTTOM", playerId)
	Achievements.addIfOpen(self, "KEEPER_TIMELY", playerId)
	Achievements.addIfOpen(self, "KEEPER_MARATHON", playerId)

	updatePlayerName(playerName)
	updateShowPlayerName()

	onInputMethodChanged()
	reset_physics_interpolation()
	prevPosition = position
	initialized = true

func get_remote_camera_target() -> Vector2:
	if is_multiplayer_authority():
		return get_camera_target_pos()
	return _remote_camera_target

func setIsVirtuallyInsideDome(newIsVirtuallyInsideDome: bool) -> void :
	if virtuallyIsInsideDome == newIsVirtuallyInsideDome:
		return
	var oldVirtuallyInsideDome: = virtuallyIsInsideDome
	virtuallyIsInsideDome = newIsVirtuallyInsideDome
	if multiplayer.is_server():
		Data.event(teamId + ".event.keepers.virtuallyinsidedome", oldVirtuallyInsideDome, newIsVirtuallyInsideDome)

func updatePlayerName(newPlayerName: String) -> void :
	playerName = newPlayerName
	if not is_inside_tree():
		await ready
	%NameLabel.set_gamer_tag(playerName, Lobby.get_member(peerId, deviceId).platform_id)

func registerCamera(inCamera: CameraBase) -> void :
	_cameraRef = inCamera

func get_camera_target_pos() -> Vector2:
	if not is_instance_valid(_cameraRef):

		Logger.warn("Camera missing (problem if persists)", techId, "is server: "\
		+ str(Network.is_server()) + " local keepers nmb: " + str(Keepers.local.getCount()))
		return global_position
	return _cameraRef.get_target_position()

func serialize() -> Dictionary:
	var data = {}
	data["goalCameraZoom"] = goalCameraZoom
	return data

func deserialize(data: Dictionary):
	goalCameraZoom = data.get("goalCameraZoom", goalCameraZoom)

func get_sound_listener_global_position() -> Vector2:
	if isInsideStation:
		return _cameraRef.global_position
	else:
		return global_position

func getIsInsideDome() -> bool:
	var isInsideSecondaryStation: = Utils.is_position_in_secondary_station(position, teamId)
	return virtuallyIsInsideDome or position.y < CONST.DOME_CELLAR_ENTRANCE_Y or isInsideSecondaryStation

func _physics_process(delta):
	if killed:
		return

	if initialized:
		GameWorld.incrementRunStat("travelledDistance", teamId, (position - prevPosition).length())
		GameWorld.incrementAchievementStat("travelledDistance", playerId, (position - prevPosition).length())
		prevPosition = position



	for i in range(carriedCarryables.size() - 1, -1, -1):
		if not is_instance_valid(carriedCarryables[i]):
			carriedCarryables.remove_at(i)

	if %BuffedSprite.visible:
		%BuffedSprite.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.05)
		%BuffedSprite.position = Vector2.ONE * randf_range(-0.5, 0.5)


	var newIsInsideDome = getIsInsideDome()
	if newIsInsideDome != isInsideDome:
		var oldInsideDome = isInsideDome
		isInsideDome = newIsInsideDome
		if multiplayer.is_server():
			Data.event(teamId + ".event.keepers.insidedome", oldInsideDome, newIsInsideDome)

	if not (isInsideStation or GameWorld.paused or disabled):
		var i: = 0
		while i < temporaryBuffs.size():
			var buff: = temporaryBuffs[i]
			buff.remainingDuration -= delta
			if buff.remainingDuration <= 0:
				Data.changeByInt(playerId + "." + buff.property, - buff.amount)
				temporaryBuffs.remove_at(i)
				continue
			i += 1

	if isInsideStation:
		var newTagPosition: Vector2 = global_position
		newTagPosition = _station.getVisualGlobalPosition() if _station is DomeStation else newTagPosition
		_nameTagPositioner.global_position = newTagPosition

func addTemporaryBuff(property: String, amount, duration: float, origin: String):
	if amount == 0:

		return
	if multiplayer.is_server():
		Data.changeByInt(playerId + "." + property, amount)
	var buff = TemporaryBuff.new()
	buff.property = property
	buff.amount = amount
	buff.remainingDuration = duration
	buff.origin = origin
	temporaryBuffs.append(buff)

func getTemporaryBuff(property: String, origin: String):
	for buff in temporaryBuffs:
		if property == buff.property and origin == buff.origin:
			return buff
	return null

func setSkin(skinId: String, colorId: String = self.colorId):
	self.skinId = skinId
	self.colorId = colorId
	if remapColorIdPerPalette:
		var mapping: Array = Data.palette_rgby.get(Style.paletteId)
		if mapping:
			colorId = "color" + str(mapping[int(colorId.substr(5))] - 1)
		else:
			Logger.error("wanted to remap keeper color, but palette does not have mapping table", "Keeper.setSkin", {"playerId": playerId, "skinId": skinId, "colorId": colorId, "paletteId": Style.paletteId})
	var skinSpritePath: String = "res://content/keeper/" + techId + "/spriteframes-" + skinId + "-" + colorId + ".tres"
	keeper_sprite.sprite_frames = load(skinSpritePath)
	if not keeper_sprite.sprite_frames:
		Logger.error("skin '%s' does not exist" % skinSpritePath, "Keeper.setSkin")

func exitStation():
	if not GameWorld.lost:



		visible = true

	_station = null
	isInsideStation = false
	if multiplayer.is_server():
		Data.event(teamId + ".event.keepers.insidestation")
	trail_particles.visible = true
	keeper_sprite.visible = true
	enableEffects()
	_nameTagPositioner.position = Vector2.ZERO

func enterStation(station, dropResources: = true):
	_station = station
	keeper_sprite.visible = false
	trail_particles.restart()
	trail_particles.visible = false
	disableEffects()
	move *= 0.0
	position = station.getKeeperPosition() + Vector2(0.5, 0)
	isInsideStation = true
	Data.event(teamId + ".event.keepers.insidestation")

	if dropResources:
		for c in carriedCarryables.duplicate():
			if not c.get_collision_mask_value(CONST.LAYER_DOME_EXTERNAL):




				if c.carryableType == "resource" and c.type == "pack":
					c.set_collision_mask_value(CONST.LAYER_DROP_DOME_BORDER, false)
					c.set_collision_mask_value(CONST.LAYER_DROP_COLLISION, false)
				Level.drops.network_set_independent(c, true)
				var dome = Level.domesByTeamId[teamId]
				c.dropTargetRef = dome.getDropTarget(c.type)
				dropCarry(c)

func _on_CarryArea_body_entered(carryable):
	if carryables.has(carryable):
		return

	carryables.append(carryable)

func _on_CarryArea_body_exited(carryable):
	carryables.erase(carryable)

func _on_UseArea_usable_entered(usable):
	if usables.has(usable):
		return

	usables.append(usable)

func _on_UseArea_usable_exited(usable):
	usables.erase(usable)

func dropCarry(body):
	Level.drops.network_drop(body, playerId)

func updateInteractables():
	if not is_multiplayer_authority():
		return

	updateUsables()
	updateCarryables()

func getChainSpawnNode() -> Node2D:
	return null

func getChainSpawnGlobalPosition() -> Vector2:
	var pivot: = getChainSpawnNode()
	if is_instance_valid(pivot):
		return pivot.global_position
	return global_position

func updateUsables():
	if not is_instance_valid(focussedUsable):
		focussedUsable = null

	if focussedUsable:
		if usables.has(focussedUsable):
			if focussedUsable.canFocusUse(self):
				return
			else:
				focussedUsable.unfocusUse(self)
				focussedUsable = null
		else:
			focussedUsable.unfocusUse(self)
			focussedUsable = null
	else:
		for usable in usables:
			if usable.canFocusUse(self):
				focussedUsable = usable
				usable.focusUse(self)
				break

func updateCarryables():
	pass

func sortByDistance(b1, b2):
	return (b1.global_position - global_position).length() < (b2.global_position - global_position).length()

func useHit() -> bool:
	if isInsideStation or disabled:
		return false

	if focussedUsable and is_instance_valid(focussedUsable):
		var handled = focussedUsable.useHit(self)
		if handled:
			return true

	return false

func useHold() -> bool:
	if isInsideStation or disabled:
		return false

	if focussedUsable:
		return focussedUsable.useHold(self)

	return false

func useTryCancelDisable():
	if disabled and disable_source:
		if disable_source.has_method("keeperWantsToAbort"):
			disable_source.keeperWantsToAbort(self)
			if focussedUsable:
				focussedUsable.updateFocus()

func onGameLost():
	$UseArea.monitoring = false
	if focussedUsable:
		focussedUsable.unfocusUse(self)
		focussedUsable = null
	if focussedCarryable:
		focussedCarryable.unfocusCarry(self)
		focussedCarryable = null
	disabled = true

	visible = false

func teleport(pos: Vector2):
	if not is_instance_valid(focussedUsable):
		focussedUsable = null

	if focussedUsable:
		focussedUsable.unfocusUse(self)
		focussedUsable = null
	move *= 0.0
	moveDirectionInput *= 0.0
	position = pos
	for c in carriedCarryables:
		if is_instance_valid(c):
			c.teleport(pos + Vector2.UP.rotated(randf_range( - PI, PI)) * (3 + randf() * 7))
	if isInsideStation:
		exitStation()

func startTeleportation(source, duration: float, fromPos: Vector2, goalPos: Vector2, allowCarryableTeleportation: bool, allowLargeDropTeleportation: = false):
	$TeleportInit.startSound()
	if multiplayer.is_server():
		for c in carriedCarryables.duplicate():
			if not (allowCarryableTeleportation and c.canTeleport) and not (allowLargeDropTeleportation and not c.canTeleport and (c.type == "powercore" or c.type == "gadget")):
				dropCarry(c)
	disabled = true
	disable_source = source

	disableEffects()
	keeper_sprite.play("default" + animationSuffix)
	var teleportColor: Color = Style.mapColor(Color("#304c8c")) * 2.0
	teleportColor.a = 1.0
	$Tween.interpolate_property(keeper_sprite, "modulate", keeper_sprite.modulate, teleportColor, duration, Tween.TRANS_CUBIC, Tween.EASE_IN)
	$Tween.interpolate_property(self, "position", position, fromPos, duration - 0.1, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	$Tween.start()

	if is_multiplayer_authority():
		var cameraAnimationDelay = duration * 0.75
		Level.viewports.startTeleportAnimation(self, duration, fromPos, goalPos, cameraAnimationDelay)

func teleportComplete():
	$Tween.remove_all()
	keeper_light.scale = Vector2.ZERO
	keeper_sprite.modulate.a = 0.0
	visible = false

func ensureUnlockedFromTeleport() -> void :
	var disabledDueToTeleporterStation = disabled and disable_source is TeleporterStation
	if disabledDueToTeleporterStation:

		focussedUsable = null
		disabled = false
		disable_source = null

func grow(duration: float, delay: = 0.0):
	$Tween.interpolate_property(keeper_light, "scale", Vector2.ZERO, Vector2.ONE, duration, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, delay)
	$Tween.interpolate_property(keeper_sprite, "modulate:a", 0.0, 1.0, 0.4, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, duration + delay - 0.4)
	$Tween.interpolate_property(keeper_sprite, "modulate", keeper_sprite.modulate, Color.WHITE, duration, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, delay)
	$Tween.interpolate_callback(self, duration + delay - 0.55, "teleportArrive")
	$Tween.interpolate_callback(self, duration + delay - 0.1, "set", "disabled", false)
	$Tween.interpolate_callback(self, duration + delay - 0.1, "set", "disable_source", false)
	$Tween.interpolate_callback(self, duration + delay - 0.1, "enableEffects")
	$Tween.start()

func teleportArrive():
	visible = true
	var effect = preload("res://content/gadgets/teleporter/TeleportEffect.tscn").instantiate()
	add_child(effect)
	effect.finished.connect(_on_teleportEffect_finished.bind(effect))
	$TeleportDone.startSound()

func _on_teleportEffect_finished(outTeleportEffect: TeleportEffect) -> void :
	outTeleportEffect.queue_free()

func disableEffects():
	pass

func enableEffects():
	pass

func addAddition(addition):
	addition.teamId = teamId
	addition.playerId = playerId
	add_child(addition)

func pauseChanged():
	if GameWorld.paused:
		$Tween.stop_all()
	else:
		$Tween.resume_all()

func remove():
	disableEffects()
	visible = false
	if focussedUsable:
		focussedUsable.unfocusUse(self)
	if focussedCarryable:
		focussedCarryable.unfocusCarry(self)

func kill():
	before_killed.emit()
	keeper_light.kill()
	killed = true
	for c in carriedCarryables.duplicate():
		dropCarry(c)
	carriedCarryables.clear()
	name += "-freed"
	remove()
	queue_free()

func onShowKeeperAimIndicatorChanged():
	pass

func updateShowPlayerName():
	var label = find_child("NameLabel")
	if isMovementDummy and (Network.multiplayer_mode == Network.MultiplayerMode.OFFLINE_SPLITSCREEN or Network.multiplayer_mode == Network.MultiplayerMode.OFFLINE_SINGLEPLAYER):

		label.visible = false
		return

	label.visible = Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER and Options.showPlayerNames

func keepers_changed():
	updateShowPlayerName()

func onInputMethodChanged():
	input_settings = Options.getInputSettingsForKeeper(self, not Options.useGamepad(deviceId))
	onShowKeeperAimIndicatorChanged()

func getAimDirection(aim_id = "") -> Vector2:
	if showcaseMode:
		return moveDirectionInput
	if Options.useGamepad(deviceId):
		return _calcGamepadDirection(aim_id, input_settings)
	elif input_settings.use_mouse:
		return _calcMouseDirection(aim_id, input_settings)
	else:
		return moveDirectionInput

func _calcGamepadDirection(aim_id: String, inInputSettings: KeeperInputSettings) -> Vector2:
	if aimDirectionInput.length() < moveDirectionThreshold:
		return Vector2.ZERO
	elif aim_id:
		return Data.snapVectorToDirections(aimDirectionInput, deg_to_rad(inInputSettings.get(aim_id) * 0.5))
	else:
		return aimDirectionInput

func _calcMouseDirection(aim_id: String, inInputSettings: KeeperInputSettings) -> Vector2:
	var localMousePosition = get_local_mouse_position()
	if localMousePosition.length() < mouseTooCloseThreshold:
		return Vector2.ZERO
	elif aim_id:
		return Data.snapVectorToDirections(localMousePosition, deg_to_rad(inInputSettings.get(aim_id) * 0.5))
	else:
		return localMousePosition.normalized()

func canEnterRemoteStation() -> bool:
	return true

func move_and_slide_custom():
	var dt = get_physics_process_delta_time()

	var prevv = velocity
	var c = move_and_collide(velocity * dt, false, safe_margin)

	if c:

		var lost_velocity = prevv - c.get_remainder() - (c.get_travel() / dt)

		var slide_dir = c.get_normal().rotated(Const.PI_HALF)
		var projected_slide = lost_velocity.dot(slide_dir) * slide_dir

		move_and_collide(projected_slide * dt, false, safe_margin)


		velocity = prevv - c.get_normal() * prevv.dot(c.get_normal())

func as_movement_dummy():
	isMovementDummy = true
	$Visuals.visible = false
	$DrillHitTestRay.enabled = false
	$CarryArea.monitoring = false
	for c in get_children():
		if c is Sound:
			c.baseVolume = -100
	set_collision_layer_value(CONST.LAYER_PLAYER, false)

func _ensureFreeFromKunaiCarrier(inBody) -> void :
	if not inBody is Carryable:
		return
	for carried in inBody.carriedBy:
		if carried is KunaiCarrier:
			Level.drops.network_drop_from_all(inBody)
