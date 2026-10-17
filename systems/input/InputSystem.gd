extends Node

var viewportByDeviceId: Dictionary = {}

var processorsToAdd: Array[InputProcessor] = []
var processorsToRemove: Array[InputProcessor] = []

@onready var _rootProcessor: InputProcessor = get_node("RootProcessor")
var doInputLogging: = true
var processors_changing: = false
var game_not_in_focus: = false


var singleFocus: = false

var _wasInputServedToSubviewports: = false

func _ready():
	add_to_group("pauseL")
	Input.connect("joy_connection_changed", Callable(self, "_on_joy_connection_changed"))

func _on_joy_connection_changed(device_id, connected):
	if not connected and Options.singleplayerUseGamepad:
		Options.setUseGamepad(false)

func pr(s: String):
	if doInputLogging:
		print(s)

func addProcessor(processor: InputProcessor):

	processorsToAdd.append(processor)
	processors_changing = true
	if processor.globalInput:
		_clearProcessors()

func _clearProcessors() -> void :
	for deviceId in viewportByDeviceId.keys():
		var processor = getLastChild(deviceId)
		if processor:
			processor.clearInput()

func removeProcessor(processor: InputProcessor):

	processorsToRemove.append(processor)
	processors_changing = true

func registerViewport(deviceId: int, viewport: Viewport) -> void :
	viewportByDeviceId[deviceId] = viewport

func unregisterViewport(deviceId) -> void :
	viewportByDeviceId.erase(deviceId)

func unregisterViewports() -> void :
	viewportByDeviceId.clear()

func clearProcessors():
	pr("clearing all input processors")
	for successor in _rootProcessor.getSuccessors():
		clearSuccessors(successor)
	processors_changing = true

func clearSuccessors(processor) -> void :
	if not is_instance_valid(processor):
		return
	processorsToRemove.append(processor)
	for successor in processor.getSuccessors():
		clearSuccessors(successor)

func _process(delta):
	processors_changing = false
	for i in range(processorsToRemove.size() - 1, -1, -1):
		if not is_instance_valid(processorsToRemove[i]) or not processorsToRemove[i].predecessor:
			processorsToRemove.remove_at(i)

	for processor in processorsToRemove:
		if processor.canStop():

			var index = processorsToAdd.find(processor)
			if index != -1:
				processorsToAdd.remove_at(index)

			processor.predecessor.eraseSuccessor(processor)
			var lastPredecessor: = processor.predecessor
			if processor.stopSuccessors:
				for successor in processor.getSuccessors():
					stopSuccessors(successor, lastPredecessor)

			deleteInputProcessor(processor)
		printout()
	if processorsToAdd.size() == 0:
		for processor in processorsToRemove:
			getLastChild(processor.deviceId).becameLeaf()
		processorsToRemove.clear()

	for processor in processorsToAdd:














		var lastChild: = getLastChild(processor.deviceId)
		lastChild.notLeaf()
		processor.predecessor = lastChild
		lastChild.addSuccessor(processor)
		processor.emit_signal("onStart")
		processor.handleStart()
		processor.becameLeaf()

		printout()
	processorsToAdd.clear()

func stopSuccessors(successor: InputProcessor, lastPredecessor: InputProcessor) -> void :
	if successor.stopWithPredecessor:
		pr("transitive stop input: " + successor.name)
		deleteInputProcessor(successor)
		var successorIndex = processorsToRemove.find(successor)
		if successorIndex != -1:
			processorsToRemove.remove_at(successorIndex)
		for childSuccessor in successor.getSuccessors():
			stopSuccessors(childSuccessor, lastPredecessor)
	else:
		successor.predecessor = lastPredecessor
		lastPredecessor.addSuccessor(successor)
		for childSuccessor in successor.getSuccessors():
			stopSuccessors(childSuccessor, lastPredecessor)

func printout():
	pass
















func _unhandled_input(event):



	if processors_changing or game_not_in_focus:
		return

	_wasInputServedToSubviewports = false
	var handled: bool = false
	var globalProcessors: Array[InputProcessor] = _findGlobalProcessorsDeepestFirst()
	for globalProcessor in globalProcessors:
		handled = globalProcessor.handle(event)
		if handled:
			break

	if not handled:
		handled = _serveViewportInput(event)

	var currentNode: InputProcessor = getLastChild(getDeviceIndex(event))
	while not handled:
		if currentNode.deviceId == -1 or currentNode.deviceId == getDeviceIndex(event):
			handled = currentNode.handle(event)

		if not handled:
			if currentNode.predecessor != null:
				currentNode = currentNode.predecessor
			else:
				handled = true

	if handled and not singleFocus:
		get_tree().root.set_input_as_handled()
		return

func _serveViewportInput(inEvent: InputEvent) -> bool:
	var outIsHandled: bool = false
	if viewportByDeviceId.is_empty():
		return outIsHandled
	if _wasInputServedToSubviewports:
		return outIsHandled

	var relatedWorldViewport: WorldViewport
	if Keepers.isSplitScreen:
		var deviceId: int = getDeviceIndex(inEvent)
		if not viewportByDeviceId.has(deviceId):

			return outIsHandled
		relatedWorldViewport = viewportByDeviceId[deviceId]
	else:
		relatedWorldViewport = viewportByDeviceId.values().front()
	if is_instance_valid(relatedWorldViewport):
		outIsHandled = _serveWorldViewportInput(inEvent, relatedWorldViewport)
		_wasInputServedToSubviewports = true
	return outIsHandled

func _serveWorldViewportInput(inEvent: InputEvent, inWorldViewport: WorldViewport) -> bool:
	var viewportContainer: ViewportContainer = inWorldViewport.get_viewport_container()
	var relatedUiViewport = viewportContainer.getUISubViewport()
	_serveSubviewportEvent(inEvent, inWorldViewport)
	_serveSubviewportEvent(inEvent, relatedUiViewport)
	var outIsHandled: bool = inWorldViewport.is_input_handled() or relatedUiViewport.is_input_handled()
	return outIsHandled

func _serveSubviewportEvent(in_event: InputEvent, inViewport: SubViewport) -> void :
	var subviewportContainer: Control = inViewport.get_parent()
	var container_rect: Rect2 = subviewportContainer.get_rect()
	if in_event is InputEventMouse:
		var is_inside_proper_viewport: bool = container_rect.has_point(in_event.position)
		if not is_inside_proper_viewport:
			return
		var transformed_event: InputEventMouse = _mapMouseForSubviewport(in_event, container_rect, inViewport)
		inViewport.push_input(transformed_event, true)
		return
	inViewport.push_input(in_event)
	return

func _mapMouseForSubviewport(inEvent: InputEventMouse, inDisplayRect: Rect2, inSubviewport: SubViewport) -> InputEventMouse:
	var isViewportStretch: = inSubviewport.size_2d_override != Vector2i.ZERO and inSubviewport.size_2d_override_stretch
	var logicalSize: Vector2 = Vector2(inSubviewport.size_2d_override) if isViewportStretch else Vector2(inSubviewport.size)
	var scale: = Vector2(logicalSize.x / max(1.0, inDisplayRect.size.x), logicalSize.y / max(1.0, inDisplayRect.size.y))
	var out: = inEvent.duplicate(true) as InputEventMouse
	out.position = (inEvent.position - inDisplayRect.position) * scale
	out.global_position = out.position
	if out is InputEventMouseMotion:
		var mm: = out as InputEventMouseMotion
		mm.relative *= scale
		mm.velocity *= scale
	return out

func is_valid_successor(successor: InputProcessor, deviceId: int) -> bool:
	return\
	is_instance_valid(successor)\
	and successor.is_inside_tree()\
	and (deviceId == -1 or successor.deviceId == -1 or successor.deviceId == deviceId)

func getLastChild(deviceId: = -1) -> InputProcessor:
	var currentNode: InputProcessor = get_child(0)
	var lastProcessor = currentNode
	while currentNode.hasSuccessors():
		var valid_successor: bool = false
		for successor in currentNode.getSuccessors():
			if is_valid_successor(successor, deviceId):
				currentNode = successor
				valid_successor = true
				break

		if not currentNode.desintegrating:
			lastProcessor = currentNode

		if not valid_successor:
			break

	return lastProcessor

func _findGlobalProcessorsDeepestFirst() -> Array[InputProcessor]:
	var outGlobalProcessors: Array[InputProcessor] = []
	var globalProcessors: Array[Array] = []
	var rootProcessor: InputProcessor = get_child(0)
	_collectDeepestProcessors(rootProcessor, globalProcessors)
	globalProcessors.sort_custom(_sortDeepestFirst)

	for pair in globalProcessors:
		outGlobalProcessors.append(pair[0] as InputProcessor)
	return outGlobalProcessors

func _collectDeepestProcessors(inProcessor: InputProcessor, outGlobalProcessors: Array[Array], inDepth: int = 0) -> void :

	var successors: Array[InputProcessor] = inProcessor.getSuccessors()
	for childProcessor: InputProcessor in successors:
		if not is_valid_successor(childProcessor, -1):
			continue
		_collectDeepestProcessors(childProcessor, outGlobalProcessors, inDepth + 1)


	if inDepth > 0 and inProcessor.globalInput:
		outGlobalProcessors.append([inProcessor, inDepth])

func _sortDeepestFirst(inFirstProcessorAndDepth: Array, inSecondProcessorAndDepth: Array) -> bool:
	return inFirstProcessorAndDepth[1] > inSecondProcessorAndDepth[1]

func pauseChanged():
	if GameWorld.paused:
		for deviceId in viewportByDeviceId.keys():
			var processor = getLastChild(deviceId)
			if processor:
				processor.onPaused()

func _notification(ev: int):
	if ev == NOTIFICATION_APPLICATION_FOCUS_OUT:
		game_not_in_focus = true
		for deviceId in viewportByDeviceId.keys():
			var processor = getLastChild(deviceId)
			if processor:
				processor.onUserTabbedOut()
	elif ev == NOTIFICATION_APPLICATION_FOCUS_IN:
		game_not_in_focus = false

func deleteInputProcessor(processor: InputProcessor):
	processor.emit_signal("onStop")
	processor.handleStop()

	if not processor.stopSuccessors and processor.hasSuccessors():
		for successor in processor.getSuccessors():
			successor.predecessor = processor.predecessor
			processor.predecessor.addSuccessor(successor)

	processor.predecessor.eraseSuccessor(processor)

	var parent = processor.get_parent()
	if parent:
		parent.remove_child(processor)
	processor.queue_free()

func teamShake(teamID: String, strength: float, duration: = 0.2, period: = 16.0) -> void :
	if Options.shakeIntensity <= 0.0:
		return
	for cam in get_tree().get_nodes_in_group("cameras"):
		var properTeam: bool = cam.getRelatedTeam() == teamID
		if properTeam:
			cam.shake(strength, duration, period)

func shake(strength: float, duration: = 0.2, period: = 16.0, pos: Vector2 = Vector2.INF, teamID: String = ""):
	if Options.shakeIntensity <= 0.0:
		return
	for cam in get_tree().get_nodes_in_group("cameras"):
		cam.shake(strength, duration, period, pos)

func changeCursor(cursor: String):
	$"%MouseCursorLookController".setCursor(cursor)

func shakeTarget(target, strength: float, duration: = 0.2, period: = 16.0):
	for cam in get_tree().get_nodes_in_group("cameras"):
		if cam.target == target:
			cam.shake(strength, duration, period)
			return

func useSystemCursor(use: bool):
	$"%MouseCursorLookController".useSystemCursor(use)

func getCamera(playerId: String = "") -> Camera2D:


	for cam in get_tree().get_nodes_in_group("cameras"):
		if (cam.playerId == playerId or playerId == "") and cam.is_current():
			return cam
	return null

func cleanString(string: String) -> String:
	var regex = RegEx.new()
	regex.compile("[\\p{L} ]*")
	var t = ""
	var matches = regex.search_all(string)
	for m in matches:
		for s in m.strings:
			t += s
	return t

func updateLinEdit(edit, new_text):
	var t = cleanString(new_text)
	var cp = edit.caret_column - (edit.text.length() - t.length())
	edit.text = t
	edit.caret_column = clamp(cp, 0, t.length())

func grabFocusIfNone(uiElement):
	if uiElement.get_viewport().gui_get_focus_owner() == null:
		grabFocus(uiElement)

func grabFocus(uiElement):
	Audio.ignoreNextHover()
	if is_instance_valid(uiElement):
		uiElement.grab_focus()

func getInputDirection() -> Vector2:
	var left = Input.get_action_raw_strength("ui_left")
	var right = Input.get_action_raw_strength("ui_right")
	var up = Input.get_action_raw_strength("ui_up")
	var down = Input.get_action_raw_strength("ui_down")
	left = max(0.0, left - Options.gamepadStickDeadZone)
	right = max(0.0, right - Options.gamepadStickDeadZone)
	up = max(0.0, up - Options.gamepadStickDeadZone)
	down = max(0.0, down - Options.gamepadStickDeadZone)
	var hor = right - left
	var ver = down - up
	if Options.gamepadStickDeadZone > 0.0:
		hor *= (1.0 / (1.0 - Options.gamepadStickDeadZone))
		ver *= (1.0 / (1.0 - Options.gamepadStickDeadZone))
	var movedir = Vector2(hor, ver)

	if movedir.length() > 1.0:
		movedir = movedir.normalized()
	return movedir

func getDeviceIndex(event) -> int:
	var deviceId: int = event.device
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		deviceId += 1
	return deviceId
