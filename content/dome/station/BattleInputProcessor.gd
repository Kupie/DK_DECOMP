class_name BattleInputProcessor extends InputProcessor

var teamId: String
var stationIndex: int

var stickMove: = Vector2()
var globalMousePos: Vector2 = Vector2()
var leftKeyDown: = false
var rightKeyDown: = false
var downKeyDown: = false
var upKeyDown: = false
var fireValue: = 0.0
var specialValue: = 0.0

var domeId: String

var popup

var controlledWeapons: Array

func _ready():
	stopSuccessors = false

func notLeaf():
	if _successors.size():
		return

	clearInput()

func clearInput():
	leftKeyDown = false
	rightKeyDown = false
	downKeyDown = false
	upKeyDown = false
	fireValue = 0.0
	specialValue = 0.0
	stickMove = Vector2()
	globalMousePos = Vector2()

func onUserTabbedOut():
	clearInput()

func becameLeaf():
	if not Options.useGamepad(deviceId):
		GameWorld.setShowMouse(Options.useMouseDomeGameplay)
		InputSystem.changeCursor("crosshairs")

func handleStart():
	popup.moveIn(true)
	var dome = Level.domesByTeamId[teamId]
	Network.rpc_for_states(dome.startWeapons.bind(stationIndex), [
		Network.ConnectionState.LOADOUT_STAGE_SYNC, 
		Network.ConnectionState.LEVEL_STAGE_SYNC, 
	], true)

func handleStop():
	popup.moveOut(-1)
	if not Level.domesByTeamId.has(teamId):
		assert (StageManager.isInLoadout(), "Dome is unavailable, it's possible only in loadout when changing game mode")
		return
	var dome = Level.domesByTeamId[teamId]
	Network.rpc_for_states(dome.stopWeapons.bind(stationIndex), [
		Network.ConnectionState.LOADOUT_STAGE_SYNC, 
		Network.ConnectionState.LEVEL_STAGE_SYNC, 
	], true)

func buttonEvent(event) -> bool:
	if pressed(event, "ui_left"):
		leftKeyDown = true
	if pressed(event, "ui_right"):
		rightKeyDown = true
	if pressed(event, domeId + "_fire"):
		fireValue = 1.0
	if pressed(event, domeId + "_special"):
		specialValue = 1.0
	if pressed(event, "ui_down"):
		downKeyDown = true
	if pressed(event, "ui_up"):
		upKeyDown = true
	if justPressed(event, "ui_cancel"):
		desintegrate()
	if released(event, "ui_left"):
		leftKeyDown = false
	if released(event, "ui_right"):
		rightKeyDown = false
	if released(event, domeId + "_fire"):
		fireValue = 0.0
	if released(event, domeId + "_special"):
		specialValue = 0.0
	if released(event, "ui_down"):
		downKeyDown = false
	if released(event, "ui_up"):
		upKeyDown = false
	if justPressed(event, "cheats"):

		return false
	if justPressed(event, "escape"):
		return false
	if justPressed(event, "dome_ability1"):
		var dome = Level.domesByTeamId[teamId]
		Network.rpc_for_states(dome.executeBattle1, [
			Network.ConnectionState.LOADOUT_STAGE_SYNC, 
			Network.ConnectionState.LEVEL_STAGE_SYNC, 
		], true)
	if justPressed(event, "dome_ability2"):
		var dome = Level.domesByTeamId[teamId]
		Network.rpc_for_states(dome.executeBattle2, [
			Network.ConnectionState.LOADOUT_STAGE_SYNC, 
			Network.ConnectionState.LEVEL_STAGE_SYNC, 
		], true)

	return true

func stick_move(event: InputEventJoypadMotion) -> bool:
	if event.axis == 0:
		if abs(event.axis_value) <= Options.gamepadStickDeadZone:
			stickMove.x = 0
		else:
			stickMove.x = axisValueDeadzoned(event.axis_value, Options.gamepadStickDeadZone)
	elif event.axis == 1:
		if abs(event.axis_value) <= Options.gamepadStickDeadZone:
			stickMove.y = 0
		else:
			stickMove.y = axisValueDeadzoned(event.axis_value, Options.gamepadStickDeadZone)

	if InputMap.event_is_action(event, domeId + "_fire"):
		fireValue = event_value(event)
	if InputMap.event_is_action(event, domeId + "_special"):
		specialValue = event_value(event)
	return true


func mouse_move(_event: InputEventMouseMotion) -> bool:

	var stations = Level.domesByTeamId[teamId].stations
	var relatedStation: DomeStation = stations[stationIndex] as DomeStation
	var relatedKeeper: Keeper = relatedStation.getKeeperInStation()
	if is_instance_valid(relatedKeeper):
		var relatedCamera: Camera2D = InputSystem.getCamera(relatedKeeper.playerId)
		globalMousePos = relatedCamera.get_global_mouse_position()
	return false

func axisValueDeadzoned(axis_value, deadzone) -> float:
	var result = axis_value - (sign(axis_value) * deadzone)
	result *= 1.0 / (1.0 - deadzone)
	return result

func event_value(event):
	if event is InputEventJoypadMotion:
		if event.axis <= 3:
			if abs(event.axis_value) > Options.gamepadStickDeadZone:
				return axisValueDeadzoned(event.axis_value, Options.gamepadStickDeadZone)
		elif event.axis == Options.AXIS_LT || event.axis == Options.AXIS_RT:
			if abs(event.axis_value) > Options.gamepadTriggerDeadZone:
				return axisValueDeadzoned(event.axis_value, Options.gamepadTriggerDeadZone)
	elif event is InputEventJoypadButton:

		return event.pressure
	return 0.0

func _physics_process(delta):
	if desintegrating:
		return

	var move: = Vector2()
	if leftKeyDown:
		move.x -= 1
	if rightKeyDown:
		move.x += 1
	move.x = clamp(move.x + stickMove.x, -1.0, 1.0)

	if upKeyDown:
		move.y -= 1
	if downKeyDown:
		move.y += 1
	move.y = clamp(move.y + stickMove.y, -1.0, 1.0)

	for weapon in controlledWeapons:
		weapon.inputs(move, fireValue, specialValue, globalMousePos)
