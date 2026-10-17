extends Node

class_name InputProcessor

const KEYBOARD_AND_MOUSE_DEVICE_ID: = 0

signal onStart
signal onStop
signal delete
signal justBecameLeaf

var predecessor: InputProcessor
var _successors: Array[InputProcessor]

var stopWithPredecessor: = true
var stopSuccessors: = true

var doTransitiveStop: = true
var desintegrating: = false


var deviceId: = -1
var globalInput: = false

func _notification(what: int) -> void :
	if what == NOTIFICATION_PREDELETE:
		delete.emit()

func integrate(parentNode):
	if parentNode is InputProcessor:
		Logger.error("Cannot add InputProcessors as children of other InputProcessors in the scene tree. Add them to the stage instead and let the InputSystem propagate the events correctly.", "InputProcessor.integrate", {"processor": name, "parentNode": parentNode.name})
		return





	var stage: Stage = parentNode if parentNode is Stage else StageManager.currentStage
	if stage and stage.stage_ending:
		Logger.warn("Stage is ending, preventing input processor %s from integrating." % name)
		return

	if stage:
		stage.inputs.append(self)


	var s = get_script()
	var start = s.resource_path.rfind("/") + 1
	name = s.resource_path.substr(start, s.resource_path.length() - start - 3)
	parentNode.add_child(self)
	InputSystem.addProcessor(self)

func desintegrate():
	if name != "RootProcessor":
		desintegrating = true


		StageManager.currentStage.inputs.erase(self)

		InputSystem.removeProcessor(self)

func handleStart():
	pass

func handleStop():
	pass

func becameLeaf():
	if not Options.useGamepad(deviceId):
		GameWorld.setShowMouse(Options.useMouseMenus)
		InputSystem.changeCursor("default")
	justBecameLeaf.emit()

func notLeaf():
	pass

func resume():
	pass

func canStop() -> bool:
	return true

func getSuccessors() -> Array[InputProcessor]:
	return _successors.duplicate()

func addSuccessor(inSuccessor: InputProcessor) -> void :
	_successors.append(inSuccessor)
	inSuccessor.delete.connect(_on_successor_delete.bind(inSuccessor))

func _on_successor_delete(pending_deletion: InputProcessor):
	eraseSuccessor(pending_deletion)

func eraseSuccessor(inSuccessor: InputProcessor) -> void :
	_successors.erase(inSuccessor)

func getNmbOfSuccessors() -> int:
	return _successors.size()

func hasSuccessors() -> bool:
	return not _successors.is_empty()

func handle(event) -> bool:
	if desintegrating:
		return false

	if event is InputEventMouseButton:
		Options.setUseGamepad(false)
		return buttonEvent(event)
	elif event is InputEventMouseMotion:
		return mouse_move(event)
	elif event is InputEventKey:
		Options.setUseGamepad(false)
		return buttonEvent(event)
	elif event is InputEventJoypadButton:
		Options.setUseGamepad(true, event.device)
		return buttonEvent(event)
	elif event is InputEventJoypadMotion:

		if event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT:
			return buttonEvent(event)
		var isMainGamepadEvent: bool = InputSystem.getDeviceIndex(event) == Options.lastGamepadDeviceId + 1
		if Options.isAutoSwitchingGamepads() and Options.lastGamepadDeviceId != -1 and ( not isMainGamepadEvent):
			return true
		if abs(event.axis_value) >= Options.gamepadStickDeadZone:
			Options.setUseGamepad(true, event.device)
		return stick_move(event)

	return false

func mouse_move(event: InputEventMouseMotion) -> bool:
	return false

func stick_move(event: InputEventJoypadMotion) -> bool:
	return Options.useGamepad(deviceId)

func buttonEvent(event: InputEvent) -> bool:
	for ui_action in ["ui_focus_prev", "ui_focus_next", "ui_left", "ui_up", "ui_right", "ui_down", "ui_accept", "ui_cancel", "ui_select"]:
		if event.is_action(ui_action):
			return true
	return false

func pressed(event, actionName: String) -> bool:
	if event is InputEventJoypadMotion:
		return InputMap.event_is_action(event, actionName) and event.axis_value >= Options.gamepadStickDeadZone
	else:
		return InputMap.event_is_action(event, actionName) and event.pressed

func released(event, actionName: String) -> bool:
	if event is InputEventJoypadMotion:
		return InputMap.event_is_action(event, actionName) and event.axis_value < Options.gamepadStickDeadZone
	else:
		return InputMap.event_is_action(event, actionName) and not event.pressed

func justPressed(event, actionName: String) -> bool:
	var echoes: = false
	if event is InputEventKey:
		echoes = event.echo
	return not echoes and pressed(event, actionName)

func onUserTabbedOut():
	pass

func onPaused():
	pass

func clearInput():
	pass
