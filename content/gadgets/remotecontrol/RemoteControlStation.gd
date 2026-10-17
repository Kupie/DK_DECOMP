extends Node2D

@export var synchronizer: Synchronizer

var teamId: String

var speed: = 0.0
var minY: = 0.0
var maxY: = 0.0
var revealCooldown: = 0.0
var isOpen: = false
var keeperInStation: Keeper
var keeperId: String
var controlledWeapons: Array
var virtualCameraTarget
var screenEffect
var tw
var inputProcessor = null

var inRapidAscent: = false
var rapidAscentStartPos: float

var domeStation: DomeStation

func _ready() -> void :
	Style.init(self)
	$KeeperSprite.visible = false
	virtualCameraTarget = preload("res://content/gadgets/remotecontrol/VirtualCameraTarget.tscn").instantiate()
	Level.map.add_child(virtualCameraTarget)

	setDomeStationAndTeamId.call_deferred()

func setDomeStationAndTeamId() -> void :
	domeStation = Level.domesByTeamId[teamId].stations.front()
	domeStation.remoteStation = self

	virtualCameraTarget.teamId = teamId

func _physics_process(delta: float) -> void :
	if GameWorld.paused or inRapidAscent:
		return

	var prev_speed = speed
	var keeper = Keepers.getClosestKeeper(global_position, teamId)
	if keeper:
		var diff = keeper.position.y - global_position.y
		var goalSpeed = clamp(diff * 0.5, -50, 50)
		speed = clamp(speed + (goalSpeed - speed) * delta * 25, -50, 50)

		var dist = global_position - keeper.position
		var coord = Level.map.getTileCoord(global_position)
		var blocked = Level.map.getTile(coord) != null

		if isOpen:
			if dist.length() > 100 or blocked or (domeStation and domeStation.keeperInStation):
				close()
		else:
			if dist.length() < 60 and not blocked and ( not domeStation or not domeStation.keeperInStation):
				open()
	else:
		speed = lerp(speed, 0.0, delta * 5)


	position.y += speed * delta


	if abs(prev_speed) > abs(speed) and abs(speed) > 1.0:
		$MoveParticlesDown.amount_ratio = clamp( - speed / 50.0, 0, 1)
		$MoveParticlesUp.amount_ratio = clamp(speed / 50.0, 0, 1)
	else:
		$MoveParticlesDown.amount_ratio = 0
		$MoveParticlesUp.amount_ratio = 0

	var moveSound = abs(speed) > 1.0
	$StationMoveSound.additionalVolume = min(0, -10 + abs(speed))
	if moveSound != $StationMoveSound.playing:
		if moveSound:
			$StationMoveSound.startSound()
		else:
			$StationMoveSound.stop()


	if position.y < minY:
		position.y = minY
		speed = 0

	if position.y > maxY:
		position.y = maxY
		speed = 0

	if revealCooldown > 0.0:
		revealCooldown -= delta
	else:
		revealCooldown = 1.0
		var radius = Data.of(teamId + ".stationextension.tilerevealdistance")
		var center = Level.map.getTileCoord(global_position)
		var t = create_tween()
		t.set_parallel(true)
		for x in range( - radius, radius + 1):
			for y in range( - radius, radius + 1):
				var dir = Vector2(x, y)
				if dir.length() > radius:
					continue

				var coord = center + Vector2i(x, y)
				if not Level.map.isRevealed(coord):
					var delay = dir.length() * randf_range(0.15, 0.25)
					t.tween_callback(reveal.bind(coord)).set_delay(delay)

func reveal(coord):
	Level.map.tileCoordsToReveal.append(coord)
	Level.map.floodRevealTiles()
	Level.map.revealTileVisually(coord)

func close():
	$Sprite.play("close")
	$CloseDoorSound.startSound()
	isOpen = false

func open():
	$Sprite.play("open")
	$OpenDoorSound.startSound()
	isOpen = true


func canFocusUse(keeper: Keeper) -> bool:
	return isOpen and not keeperInStation and keeper.canEnterRemoteStation() and not domeStation.keeperInStation and keeper.teamId == teamId


func useHold(keeper: Keeper) -> bool:
	return false

func useHit(keeper: Keeper) -> bool:
	if not canFocusUse(keeper):
		return false

	synchronizer.rpc_server(requestStationAuthority.bind(keeper.playerId))
	return true

@rpc("reliable", "any_peer")
func requestStationAuthority(playerId: String) -> void :

	var keeper: = Keepers.getKeeper(playerId)
	if not canFocusUse(keeper):
		return

	synchronizer.network_rpc(registerHit.bind(playerId), true)

@rpc("reliable")
func registerHit(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)

	keeperId = keeper.techId
	keeper.enterStation(self, false)
	$EnterStationSound.startSound()
	keeperInStation = keeper

	for w in getControlledWeapons():
		w.deviceId = keeper.deviceId

	domeStation.setWeaponAuthority(keeper.peerId)

	$Sprite.play("activate")
	$KeeperSprite.sprite_frames = keeperInStation.keeper_sprite.sprite_frames
	$KeeperSprite.visible = true

	if multiplayer.get_unique_id() == keeper.peerId:
		var i = preload("res://content/gadgets/remotecontrol/RemoteStationInputProcessor.gd").new()
		i.teamId = teamId
		i.popup = preload("res://content/gadgets/remotecontrol/RemoteStationPopup.tscn").instantiate()
		i.popup.teamId = teamId
		i.deviceId = keeper.deviceId
		i.keeper = keeper
		i.station = self
		i.integrate(self)
		inputProcessor = i
		Level.stage.showPopup(i.popup, keeper)

	if multiplayer.is_server():
		keeper.tree_exiting.connect(_on_keeper_tree_exiting, CONNECT_ONE_SHOT)

func _on_keeper_tree_exiting() -> void :
	synchronizer.network_rpc(releaseStationAuthority, true)

@rpc("reliable", "any_peer")
func releaseStationAuthority() -> void :
	$KeeperSprite.visible = false

	domeStation.setWeaponAuthority(1)

	if is_instance_valid(keeperInStation) and keeperInStation.peerId == multiplayer.get_unique_id():
		if screenEffect:
			closeScreenEffect()
			var tw = create_tween()
			tw.tween_callback( func():
				keeperInStation = null
				$Sprite.play("deactivate")
			).set_delay(1.5)
		else:
			setCamOnKeeper()
			$ExitStationSound.startSound()
			$Sprite.play("deactivate")

	if is_instance_valid(keeperInStation):
		keeperInStation.exitStation()
	domeStation.setWeaponAuthority(1)

	if not screenEffect:
		keeperInStation = null

func transitionToDome(keeper: Keeper):
	if not screenEffect:
		screenEffect = preload("res://content/gadgets/remotecontrol/RemoteStationScreenEffects.tscn").instantiate()
		screenEffect.teamId = teamId
		Level.stage.showPopup(screenEffect, keeper, "", LevelStage.PopupCanvas.PLAYER_WORLD)

	keeper.virtuallyIsInsideDome = true
	synchronizer.rpc_server(_acknowledgeKeeperVirtualState.bind(keeper.playerId, true))

	screenEffect.set_effects_active(false)
	screenEffect.set_visible(true)
	screenEffect.fade_out()

	if tw:
		tw.kill()

	tw = create_tween()
	tw.tween_callback( func():
		screenEffect.set_effects_active(true)
		screenEffect.fade_in()
		$ActivateSound.startSound()
		Level.stage.getVignette(keeper).modulateOnPlayerY = false
		setCamOnDome()
	).set_delay(1)

@rpc("reliable", "any_peer")
func _acknowledgeKeeperVirtualState(inPlayerID: String, isVirtuallyInsideDome: bool) -> void :
	assert (multiplayer.is_server())
	var keeper: Keeper = Keepers.getKeeper(inPlayerID)
	if not is_instance_valid(keeper):
		return
	keeper.virtuallyIsInsideDome = isVirtuallyInsideDome

func setCamOnDome():
	var cam = InputSystem.getCamera(keeperInStation.playerId)
	if cam:
		cam.target = virtualCameraTarget
		cam.jump()

func setCamOnKeeper():
	var cam = InputSystem.getCamera(keeperInStation.playerId)
	if cam:
		cam.target = keeperInStation
		synchronizer.rpc_server(_acknowledgeKeeperVirtualState.bind(keeperInStation.playerId, false))
		keeperInStation.virtuallyIsInsideDome = false
		keeperInStation.isInsideDome = false
		cam.jump()
		Style.setPalette(Style.paletteId)
		Level.stage.getVignette(keeperInStation).modulateOnPlayerY = true

func _on_sprite_animation_finished() -> void :
	if $Sprite.animation == "activate":
		$Sprite.play("running")

func getKeeperPosition() -> Vector2:
	return $Usable.global_position

func exitStation():
	synchronizer.network_rpc(releaseStationAuthority, true)

func closeScreenEffect():
	if not screenEffect:
		return

	if tw:
		tw.kill()

	screenEffect.set_effects_active(true)
	screenEffect.set_visible(true)
	screenEffect.fade_out()
	tw = create_tween()
	tw.tween_callback( func():
		if screenEffect:
			screenEffect.set_effects_active(false)
			screenEffect.fade_in()
		setCamOnKeeper()
		$ExitStationSound.startSound()
	).set_delay(1)
	tw.tween_callback( func():
		if screenEffect:
			screenEffect.queue_free()
			screenEffect = null
	).set_delay(0.5)

func rapidAscentProcess(v):
	position = Vector2(position.x, lerp(rapidAscentStartPos, minY, v))
	keeperInStation.global_position = global_position
	$MoveParticlesDown.amount_ratio = v * 10.0
	InputSystem.getCamera(keeperInStation.playerId).jump()

func startRapidAscent():
	rapidAscentStartPos = position.y
	inRapidAscent = true
	Level.stage.unpause()

	var duration = 3.0
	InputSystem.getCamera(keeperInStation.playerId).shake(200.0, duration)

	var tw = create_tween()
	tw.tween_method(rapidAscentProcess, 0.0, 1.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)

	tw.tween_callback( func():
		inRapidAscent = false
		inputProcessor.desintegrate()
		)

	pass

func getControlledWeapons() -> Array:
	var dome = Level.domesByTeamId[teamId]
	var station = dome.stations.front()
	return station.getControlledWeapons()

func serialize() -> Dictionary:
	var data = {
		"position" = var_to_str(global_position), 
		"speed" = speed, 
		"is_open" = isOpen, 
	}
	return data

func deserialize(data: Dictionary):
	global_position = BackwardCompatibilityUtils.str_to_var(data["position"])
	speed = data["speed"]
	if data["is_open"]:
		open()
	else:
		close()

func getIndex() -> int:
	return 0
