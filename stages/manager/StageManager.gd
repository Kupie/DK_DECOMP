extends Node

var currentStage: Stage = null
var pendingStagePacked: PackedScene = null
var pendingStage: Stage = null
var pendingStageResource: = ""
var pendingStageName: = ""
var _backgroundStageNodeName: = ""
var switchingStage: = false

var initData: Dictionary

var sceneCache = {}

signal stage_started
signal level_ready

func startStage(stageName: String, data: Array = []):
	if stageName == pendingStageName:
		Logger.warn("same stage queued again, ignoring", "StageManager.startStage", stageName)
		return

	Network.update_local_connection_state(Network.ConnectionState.STAGE_TRANSITION)
	Logger.info("Start Stage: " + stageName)

	queueStage(stageName, data)

	if is_instance_valid(currentStage):
		_stopOldStage()
	else:
		_addNewStage()

func queueStage(stageName: String, data: Array = []):
	var i = stageName.rfind("/")
	pendingStageResource = stageName.substr(0, i) + "/" + stageName.substr(i + 1, 1).capitalize() + stageName.substr(i + 2) + "Stage.tscn"
	pendingStageName = stageName
	initData[pendingStageResource] = data

func _stopOldStage():
	switchingStage = true
	currentStage.beforeEnd()
	for i in currentStage.inputs:
		if is_instance_valid(i):
			i.desintegrate()
	if currentStage.fadeOutTime > 0:
		$Canvas / ScreenOverlay.fadeOutCallback(currentStage.fadeOutTime, _removeOldStage.bind(currentStage))
	else:
		$Canvas / ScreenOverlay.setOpaque()
		_removeOldStage(currentStage)

func _removeOldStage(oldStage: Stage):


	oldStage.process_mode = Node.PROCESS_MODE_DISABLED

	oldStage.end()
	oldStage.ended.emit()
	var parentNode = oldStage.get_parent()
	parentNode.name = "Freed"
	parentNode.queue_free()



	await get_tree().process_frame

	if pendingStageName:
		_addNewStage()

func clearQueuedStage():
	if initData.has(pendingStageResource):
		initData.erase(pendingStageResource)
	pendingStageResource = ""
	pendingStageName = ""

func startStageInBackground(stageName: String) -> Stage:
	if stageName == pendingStageName:
		Logger.warn("same stage queued again, ignoring", "StageManager.startStage", stageName)
		return

	Logger.info("Start Stage In Background: " + stageName)

	var i = stageName.rfind("/")
	var stageResource = stageName.substr(0, i) + "/" + stageName.substr(i + 1, 1).capitalize() + stageName.substr(i + 2) + "Stage.tscn"
	var newStage: Stage


	if sceneCache.has(stageName):
		newStage = sceneCache.get(stageName).instantiate()
	else:
		var scene = load("res://" + stageResource)
		sceneCache[stageName] = scene
		newStage = load("res://" + stageResource).instantiate()

	_setViewportsVisible(newStage, false)

	newStage.process_mode = Node.PROCESS_MODE_DISABLED
	newStage.beforeReady()
	var container = Node2D.new()
	container.name = newStage.name

	container.add_child(newStage)
	add_child(container)
	_backgroundStageNodeName = newStage.name

	return newStage

func _clearBackgroundStage() -> void :
	if not has_node(_backgroundStageNodeName):
		_backgroundStageNodeName = ""
		return
	var stage: Stage = get_node(_backgroundStageNodeName).get_children().front()
	_removeOldStage(stage)
	_backgroundStageNodeName = ""

func _addNewStage():
	var transitionToMainMenu: bool = pendingStageName == "stages/title/title"
	if transitionToMainMenu:


		_clearBackgroundStage()

	var data = initData[pendingStageResource]
	var newStage: Stage
	initData.erase(pendingStageResource)


	if sceneCache.has(pendingStageName):
		newStage = sceneCache.get(pendingStageName).instantiate()
	else:
		var scene = load("res://" + pendingStageResource)
		sceneCache[pendingStageName] = scene
		newStage = load("res://" + pendingStageResource).instantiate()
	pendingStageResource = ""
	pendingStageName = ""

	currentStage = newStage

	newStage.beforeReady()
	var container = Node2D.new()
	container.name = newStage.name

	container.add_child(newStage)
	add_child(container)

	newStage.request_end.connect(_stopOldStage)
	newStage.build(data)

	stage_started.emit()

	newStage.beforeStart()

	currentStage = newStage
	if newStage.fadeInTime > 0:
		$Canvas / ScreenOverlay.fadeInCallback(newStage.fadeInTime, _startNewStage.bind(newStage))
	else:
		$Canvas / ScreenOverlay.setClear()
		_startNewStage(newStage)

func activateStage(newStage: Stage, data: Array):
	newStage.request_end.connect(_stopOldStage)
	newStage.build(data)

	if is_instance_valid(currentStage):
		_stopOldStage()
		await currentStage.ended

	newStage.beforeStart()
	currentStage = newStage
	_setViewportsVisible(newStage, true)
	newStage.process_mode = Node.PROCESS_MODE_INHERIT

	stage_started.emit()

	if newStage.fadeInTime > 0:
		$Canvas / ScreenOverlay.fadeInCallback(newStage.fadeInTime, _startNewStage.bind(newStage))
	else:
		$Canvas / ScreenOverlay.setClear()
		_startNewStage(newStage)

func _startNewStage(stage: Stage):
	stage.start()
	switchingStage = false

func error(message: String):
	if currentStage:
		queueStage("stages/debug/error", [message])
		currentStage.emit_signal("request_end")
	else:
		startStage("stages/debug/error", [message])

func loadSaveFailed():
	if currentStage:
		queueStage("stages/saveerror/SaveError")
		currentStage.emit_signal("request_end")
	else:
		startStage("stages/saveerror/SaveError")

func loadSaveFallbackPopup():
	var popup = preload("res://gui/savefallback/SaveFallbackPopup.tscn").instantiate()
	$Canvas.add_child(popup)

func getPauseScreenInfo():
	if currentStage:
		return currentStage.getPauseScreenInfo()
	return null

func getContext() -> String:
	var s: = "current="
	if currentStage:
		s += currentStage.getContext()
	return s

func _setViewportsVisible(newStage: Stage, value: bool) -> void :
	var viewports = newStage.find_child("Viewports")
	if viewports:
		viewports.visible = value

func isInLoadout() -> bool:
	return is_instance_valid(currentStage) and currentStage is MultiplayerLoadoutStage

func isInDeviceSelection() -> bool:
	return is_instance_valid(currentStage) and currentStage is DeviceSelectionStage

func isInLanding() -> bool:
	return is_instance_valid(currentStage) and currentStage is LandingStage

func isInClientLanding() -> bool:
	return is_instance_valid(currentStage) and currentStage is ClientLandingStage

func isInLevel() -> bool:
	return is_instance_valid(currentStage) and currentStage is LevelStage

func isInResolvedLevel() -> bool:
	if is_instance_valid(currentStage) and currentStage is LevelStage:
		if GameWorld.gameover:
			return true
	return false

func isInLoading() -> bool:
	return is_instance_valid(currentStage) and currentStage is LoadingStage

func isInTitle() -> bool:
	return is_instance_valid(currentStage) and currentStage is TitleStage

func isTitleStagePending() -> bool:
	return pendingStage is TitleStage or pendingStageResource.find("TitleStage.tscn") > -1

func isSwitchingStage() -> bool:
	return is_instance_valid(pendingStageResource) or not pendingStageName.is_empty() or switchingStage
