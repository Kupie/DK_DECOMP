extends VBoxContainer

class_name Viewports

const DIST_MERGE: = 220.0
const DIST_SPLIT: = 300.0
const MAX_RATIO: = 15.0

var originalWorld: World2D
var originalViewport: SubViewport

var viewportContainersByKeeperId: = {}
var viewportTrackersByViewport: = {}

var bufferedTransitions: = []
var isMerging: = false
var timeInMine: = 0.0

@onready var viewportsTracker = $"%ViewportsTracker"
@onready var transitionTween: = $Tween
@export var camera_scene: PackedScene

func _ready():
	originalViewport = find_child("SubViewport")
	originalWorld = originalViewport.world_2d
	Keepers.local_keeper_registered.connect(on_local_keeper_registered)
	Keepers.local_keeper_unregistered.connect(on_local_keeper_unregistered)
	Keepers.local_keeper_replaced.connect(on_local_keeper_replaced)

	var viewportContainer1 = find_child("ViewportContainer", true, false)
	if not viewportContainer1.logic_size_changed.is_connected(_on_viewport_container_resized):
		viewportContainer1.logic_size_changed.connect(_on_viewport_container_resized.bind(viewportContainer1))

func update_and_network_viewport_sizes(zoom_override: = - Vector2.ONE) -> void :
	if Network.is_server():
		return

	var sizes: = {}
	for keeper: Keeper in Keepers.local.getAll():
		sizes[keeper.playerId] = get_viewport_world_size(keeper.playerId)
	Network.network_main_window_size_changed(sizes)

func get_viewport_world_size(player_id: String, in_zoom_override: Vector2 = - Vector2.ONE) -> Vector2:
	return viewportContainersByKeeperId[player_id].get_world_subviewport_logic_size(in_zoom_override)

func prepareViewportContainers(loadoutKeepers: Array):
	pass

func ensure_viewport_for_all_players():
	var allLocalKeepers: = Keepers.local.getAll()
	var firstPlayerRemoved: = false

	if viewportContainersByKeeperId.size() > 1:
		for id in viewportContainersByKeeperId.keys().duplicate():
			var isIn: = false
			for keeper in allLocalKeepers:
				if id == keeper.playerId:
					isIn = true
					break
			if not isIn:
				var viewport = viewportContainersByKeeperId[id]
				if viewport == find_child("ViewportContainer", true, false):
					removeViewport(get_first_local_player_id())
					firstPlayerRemoved = true
				else:
					removeViewport(id)


	var firstPlayerId: = get_first_local_player_id()
	for keeper in allLocalKeepers:
		if keeper.playerId == firstPlayerId:
			var viewportContainer1 = find_child("ViewportContainer", true, false)

			var viewportKeeperPresent: bool = is_instance_valid(viewportContainer1.keeper)
			var viewportHasDifferentKeeper: bool = ( not viewportKeeperPresent) or viewportContainer1.keeper.playerId != keeper.playerId
			if viewportHasDifferentKeeper:
				viewportContainer1.initialized = false
				if viewportKeeperPresent:
					viewportContainersByKeeperId.erase(viewportContainer1.keeper.playerId)

			if firstPlayerRemoved:
				viewportContainer1.initialized = false
				viewportContainer1.init(originalWorld, Keepers.getKeeper(firstPlayerId), camera_scene)
			viewportContainersByKeeperId[firstPlayerId] = viewportContainer1
			viewportTrackersByViewport[viewportContainer1] = $"%PlayerTracker1"
			viewportContainer1.visible = true
			if not viewportContainer1.logic_size_changed.is_connected(_on_viewport_container_resized):
				viewportContainer1.logic_size_changed.connect(_on_viewport_container_resized.bind(viewportContainer1))
		elif not viewportContainersByKeeperId.has(keeper.playerId):
			var newViewportContainer = preload("res://systems/camera/ViewportContainer.tscn").instantiate()
			var newViewportTrackerContainer = preload("res://systems/camera/ViewportContainerTracker.tscn").instantiate()
			viewportContainersByKeeperId[keeper.playerId] = newViewportContainer
			viewportTrackersByViewport[newViewportContainer] = newViewportTrackerContainer
			newViewportContainer.logic_size_changed.connect(_on_viewport_container_resized.bind(newViewportContainer))


	for i in range(allLocalKeepers.size()):
		var keeper: Keeper = allLocalKeepers[i]
		var viewportContainer: Control = viewportContainersByKeeperId[keeper.playerId]
		var viewportTrackerContainer: Control = viewportTrackersByViewport[viewportContainer]
		if i == 0:
			continue

		if is_instance_valid(viewportContainer.get_parent()):
			viewportContainer.get_parent().remove_child(viewportContainer)
		if is_instance_valid(viewportTrackerContainer.get_parent()):
			viewportTrackerContainer.get_parent().remove_child(viewportTrackerContainer)

		if i < 2:
			$Top.add_child(viewportContainer)
			viewportsTracker.get_node("Top").add_child(viewportTrackerContainer)
		else:
			$Bottom.add_child(viewportContainer)
			viewportsTracker.get_node("Bottom").add_child(viewportTrackerContainer)

	$Bottom.visible = viewportContainersByKeeperId.size() > 2

	if $Bottom.get_child_count() == 0:
		$Bottom.size_flags_vertical = SIZE_FILL
	else:
		$Bottom.size_flags_vertical = SIZE_EXPAND_FILL

	update_and_network_viewport_sizes()

func _on_viewport_container_resized(in_viewport_container: ViewportContainer) -> void :
	if not multiplayer.is_server():
		update_and_network_viewport_sizes()

func getViewportContainerForPlayerID(inPlayerID: String) -> ViewportContainer:
	if viewportContainersByKeeperId.has(inPlayerID):
		return viewportContainersByKeeperId[inPlayerID]
	return null

func removeViewport(id: String) -> void :
	var viewport = viewportContainersByKeeperId[id].viewport
	var viewportContainer = viewportContainersByKeeperId[id]
	viewport.queue_free()
	viewport.get_parent().remove_child(viewport)
	viewportContainersByKeeperId.erase(id)
	if viewportTrackersByViewport.has(viewportContainer):
		viewportTrackersByViewport[viewportContainer].queue_free()
		viewportTrackersByViewport[viewportContainer].get_parent().remove_child(viewportTrackersByViewport[viewportContainer])
		viewportTrackersByViewport.erase(viewportContainer)
	InputSystem.unregisterViewport(viewportContainer.keeper.deviceId)
	viewportContainer.queue_free()

func init():
	ensure_viewport_for_all_players()
	for keeper in Keepers.local.getAll():
		if not viewportContainersByKeeperId[keeper.playerId].initialized:
			viewportContainersByKeeperId[keeper.playerId].init(originalWorld, keeper, camera_scene)
		viewportContainersByKeeperId[keeper.playerId].camera.target = keeper
		InputSystem.registerViewport(keeper.deviceId, viewportContainersByKeeperId[keeper.playerId].viewport)

	if viewportContainersByKeeperId.size() < 2:
		singleScreen()
		get_window().multi_viewport_focus = false
	else:
		fromMergedToSplitInstant()
		get_window().multi_viewport_focus = true

	await get_tree().create_timer(0.1).timeout
	update_and_network_viewport_sizes()

func on_local_keeper_registered(new_keeper: Keeper) -> void :
	ensure_viewport_for_all_players()
	for keeper in Keepers.local.getAll():
		if not viewportContainersByKeeperId[keeper.playerId].initialized:
			viewportContainersByKeeperId[keeper.playerId].init(originalWorld, keeper, camera_scene)
		viewportContainersByKeeperId[keeper.playerId].camera.target = keeper
		InputSystem.registerViewport(keeper.deviceId, viewportContainersByKeeperId[keeper.playerId].viewport)

	if viewportContainersByKeeperId.size() < 2:
		singleScreen()
	else:
		fromMergedToSplitInstant()

func _exit_tree() -> void :
	InputSystem.unregisterViewports()

func on_local_keeper_unregistered(removed_keeper: Keeper):
	ensure_viewport_for_all_players()
	var related_vc = getViewportContainerForPlayerID(removed_keeper.playerId)
	viewportTrackersByViewport.erase(related_vc)
	viewportContainersByKeeperId.erase(removed_keeper.playerId)
	if viewportContainersByKeeperId.size() < 2:
		singleScreen()

func on_local_keeper_replaced(keeper: Keeper) -> void :
	viewportContainersByKeeperId[keeper.playerId].camera.target = keeper
	viewportContainersByKeeperId[keeper.playerId].keeper = keeper

func _process(delta):
	return
	@warning_ignore("unreachable_code")
	var keeperDist: = getKeeperDist()

	if Keepers.local.allInsideMine():
		timeInMine = min(timeInMine + delta, 1.0)
	else:
		timeInMine = 0.0


	if Keepers.isSplitScreen:
		if Keepers.local.allInsideDome() and not isMerging:

			addTransition("fromSplitToDome")

		elif Keepers.local.allInsideMine():

			if keeperDist < DIST_MERGE and not isMerging:
				addTransition("fromSplitToMerged")


	else:
		if Keepers.local.allInsideMine():

			camPosInMine(keeperDist, delta)
			if keeperDist > DIST_SPLIT:

				addTransition("fromMergedToSplit")

		if not Keepers.local.allInsideDome() and Keepers.local.oneInsideDome() and should_split():

			addTransition("fromDomeToSplit")


	if not bufferedTransitions.is_empty():
		transitionTween.remove_all()

		match bufferedTransitions.pop_front():
			"fromSplitToDome":
				biggestViewport = getDomeViewport()
				for viewport in viewportContainersByKeeperId.values():
					changeStretchRatio(viewport, 1.0)
				transitionTween.interpolate_method(self, "fromSplitToDome", 0, 1, 0.6, Tween.TRANS_SINE, Tween.EASE_OUT)
			"fromDomeToSplit":
				biggestViewport = getDomeViewport()
				for viewport in viewportContainersByKeeperId.values():
					changeStretchRatio(viewport, 1.0)
				changeStretchRatio(biggestViewport, MAX_RATIO)
				transitionTween.interpolate_method(self, "fromDomeToSplit", 0, 1, 0.6, Tween.TRANS_SINE, Tween.EASE_OUT)
			"fromSplitToMerged":
				transitionTween.interpolate_method(self, "fromSplitToMerged", 0, 1, 0.6, Tween.TRANS_SINE, Tween.EASE_OUT)
			"fromMergedToSplit":

				fromMergedToSplitInstant()

		transitionTween.start()

func should_split() -> bool:
	var keeperDist: = getKeeperDist()
	for keeper1 in Keepers.local.getAll():
		for keeper2 in Keepers.local.getAll():
			if keeper1 != keeper2:
				var movementDot = keeper1.moveDirectionInput.normalized().dot(keeper2.moveDirectionInput.normalized())
				if keeperDist > DIST_MERGE * remap(movementDot, -1, 1, 0, 2):
					return true
	return false

func addTransition(t: = ""):
	if ["fromDomeToSplit", "fromMergedToSplit"].has(t):
		isMerging = false
	else:
		isMerging = true
	bufferedTransitions.append(t)


func fromSplitToMerged(camMove: float):


	get_tree().call_group("coop_light_source", "setGlow", camMove)
	for keeper in Keepers.local.getAll():
		var viewport = viewportContainersByKeeperId[keeper.playerId]
		var cam: Camera2D = getPlayerCam(keeper.playerId)
		viewport.showBorder()
		viewport.setBorderAlpha(ease(abs(1.0 - camMove), 0.5))
		changeStretchRatio(viewport, 1.0)
		if camMove >= 1:
			singleScreen()
			cam.baseOffset = Vector2.ZERO
			isMerging = false
			viewport.setBlendLeft(0)
			Level.stage.showGUI()
			viewport.hideBorder()
		else:
			var otherKeeperId: = ""
			for otherKeeper in Keepers.local.getAll():
				if keeper == otherKeeper:
					continue
				otherKeeperId = otherKeeper.playerId
			if keeper.playerId != get_first_local_player_id():
				Level.stage.hideGUI()

			var centerOffset: Vector2 = (viewportTrackersByViewport[viewport].getCenterOffset()) * cam.zoom
			cam.baseOffset = lerp(Vector2.ZERO, centerOffset + toPlayerVector(keeper.playerId, otherKeeperId) * 0.5, ease(camMove, 0.5))

func get_first_local_player_id() -> String:
	for k in Keepers.local.getAll():
		return k.playerId
	return ""

func fromMergedToSplit(camMove: float):
	splitScreen()

	for keeper in Keepers.local.getAll():
		var viewport = viewportContainersByKeeperId[keeper.playerId]
		var cam: Camera2D = getPlayerCam(keeper.playerId)
		viewport.showBorder()
		viewport.setBorderAlpha(ease(camMove, 4))
		changeStretchRatio(viewport, 1.0)
		if camMove >= 1:
			viewport.showBorder()
			Level.stage.showGUI()
			cam.baseOffset = Vector2.ZERO
		else:
			var otherKeeperId: = ""
			for otherKeeper in Keepers.local.getAll():
				if keeper == otherKeeper:
					continue
				otherKeeperId = otherKeeper.playerId
			if keeper.playerId != get_first_local_player_id():
				Level.stage.hideGUI()
			var centerOffset: Vector2 = (viewportTrackersByViewport[viewport].getCenterOffset()) * cam.zoom
			cam.baseOffset = lerp(centerOffset + toPlayerVector(keeper.playerId, otherKeeperId) * 0.5, Vector2.ZERO, camMove)

var biggestViewport
func fromSplitToDome(camMove: float):
	var biggestCam: Camera2D = biggestViewport.getCam()
	splitScreen(false)

	var split: float = lerp(0.0, -100.0, camMove)
	changeSeparation(split)

	for keeper in Keepers.local.getAll():
		var viewport = viewportContainersByKeeperId[keeper.playerId]
		viewport.hideBorder()

		var cam: Camera2D = getPlayerCam(keeper.playerId)
		if not cam:
			return
		if camMove >= 1:
			singleScreen()
			cam.baseOffset = Vector2.ZERO
			isMerging = false
			Level.stage.showGUI()
			viewport.setBlendLeft(0)
		else:
			Level.stage.hideGUI()
			if cam == biggestCam:
				changeStretchRatio(viewport, lerp(1.0, MAX_RATIO, camMove))
				var centerOffset: Vector2 = viewportTrackersByViewport[viewport].getCenterOffset() * cam.zoom
				cam.baseOffset = lerp(Vector2.ZERO, centerOffset, camMove)
			else:
				changeStretchRatio(viewport, 1.0)
				viewport.modulate.a = 1
				viewportContainersByKeeperId["player2"].setBlendLeft(camMove * 100)
				var centerOffset: Vector2 = (viewportTrackersByViewport[viewport].getCenterOffset() - cam.position * 2) * cam.zoom
				cam.baseOffset = lerp(Vector2.ZERO, biggestCam.global_position + centerOffset, ease(camMove, 1.3))
				cam.position = lerp(cam.position, biggestCam.position, camMove)


func fromDomeToSplit(camMove: float):
	var biggestCam: Camera2D = biggestViewport.getCam()
	splitScreen()

	var split: float = lerp(-100.0, 0.0, camMove)
	changeSeparation(split)

	for keeper in Keepers.local.getAll():
		var viewport = viewportContainersByKeeperId[keeper.playerId]
		var cam: Camera2D = getPlayerCam(keeper.playerId)

		viewport.hideBorder()
		viewport.setBlendLeft(0)


		if camMove >= 1:
			viewport.showBorder()
			Level.stage.showGUI()
			cam.baseOffset = Vector2.ZERO
		else:
			Level.stage.hideGUI()
			viewportContainersByKeeperId["player2"].setBlendLeft(abs(1.0 - camMove) * 100)
			if cam == biggestCam:
				changeStretchRatio(viewport, lerp(MAX_RATIO, 1.0, camMove))
				var centerOffset: Vector2 = viewportTrackersByViewport[viewport].getCenterOffset() * cam.zoom
				cam.baseOffset = lerp(centerOffset, Vector2.ZERO, camMove)
			else:
				changeStretchRatio(viewport, 1.0)
				var centerOffset: Vector2 = (viewportTrackersByViewport[viewport].getCenterOffset() - cam.position * 2) * cam.zoom
				cam.baseOffset = lerp(biggestCam.global_position + centerOffset, Vector2.ZERO, camMove)



func fromMergedToSplitInstant():
	changeSeparation(0.0)
	for keeperId in viewportContainersByKeeperId:
		var viewport = viewportContainersByKeeperId[keeperId]
		viewport.setBorderAlpha(1.0)
		viewport.showBorder()
		if Level.stage is LevelStage:
			Level.stage.showGUI()
		changeStretchRatio(viewport, 1.0)

	splitScreen()


func changeSeparation(value: float):
	$Top.add_theme_constant_override("separation", value)
	$"../ViewportsTracker/Top".add_theme_constant_override("separation", value)


func changeStretchRatio(viewport, ratio):
	viewport.size_flags_stretch_ratio = ratio
	viewportTrackersByViewport[viewport].size_flags_stretch_ratio = ratio


func toPlayerVector(from: String, to: String) -> Vector2:
	return getPlayerCam(to).position - getPlayerCam(from).position


func camPosInMine(keeperDist: float, delta):
	var mainPlayerId: = ""
	for playerId in viewportContainersByKeeperId:
		if viewportContainersByKeeperId[playerId].visible:
			mainPlayerId = playerId

	var avgVector = Vector2.ZERO
	for playerId in viewportContainersByKeeperId:
		getPlayerCam(playerId).mergeScreenZoom = clamp(remap(keeperDist, DIST_MERGE, DIST_SPLIT, 0, 1), 0, 1)
		if playerId == mainPlayerId:
			continue
		avgVector += toPlayerVector(mainPlayerId, playerId)
	avgVector *= 0.5
	getPlayerCam(mainPlayerId).baseOffset = lerp(lerp(getPlayerCam(mainPlayerId).baseOffset, avgVector, delta * 2.0), avgVector, timeInMine)

func splitScreen(showGlow: = true):
	if Keepers.isSplitScreen:
		return



	for viewport in viewportContainersByKeeperId.values():
		if showGlow:
			viewport.showGlow()




	Keepers.isSplitScreen = true
	for viewport in viewportContainersByKeeperId.values():
		viewport.visible = true

	$Bottom.visible = true

func getPlayerCam(keeperID) -> Camera2D:
	if not viewportContainersByKeeperId.has(keeperID):
		return null
	return viewportContainersByKeeperId[keeperID].getCam()

func getKeeperDist() -> float:
	var keepers = Keepers.local.getAll()

	var keeperDist: = 0.0
	for p1 in keepers:
		for p2 in keepers:
			if p1 != p2:


				keeperDist = max(keeperDist, ((p1.position - p2.position) * Vector2(1, 1.77)).length())
	return keeperDist


func singleScreen():
	if not Keepers.isSplitScreen:
		return

	Keepers.isSplitScreen = false

	get_tree().call_group("coop_light_source", "setGlow", 1.0)

	var biggestViewport = getBiggestViewport()

	for viewport in viewportContainersByKeeperId.values():
		if viewport != biggestViewport:
			viewport.visible = false
			viewport.get_parent().visible = false

	if biggestViewport:
		biggestViewport.get_parent().visible = true

func getBiggestViewport():
	var biggestViewport = null
	for viewport in viewportContainersByKeeperId.values():
		if biggestViewport == null or biggestViewport.getZoom().length() < viewport.getZoom().length():
			biggestViewport = viewport
	return biggestViewport

func getDomeViewport():
	var topKeeperId: = ""
	var topKeeperPos: = 90000.0
	for keeper in Keepers.local.getAll():

		if keeper == null or keeper.position.y < topKeeperPos:
			topKeeperPos = keeper.position.y
			topKeeperId = keeper.playerId
	return viewportContainersByKeeperId[topKeeperId]

func addElement(e):
	originalViewport.add_child(e)

func addKeeper(keeper: Keeper) -> void :
	originalViewport.add_child(keeper)
	keeper.registerCamera(originalViewport.get_camera_2d())

func addMonster(monster):
	originalViewport.find_child("Monsters").add_child(monster)

func startTeleportAnimation(keeper: Keeper, time: float, from: Vector2, to: Vector2, cameraAnimationDelay: = 0.0):
	var vp = viewportContainersByKeeperId.get(keeper.playerId)
	if not vp:
		return

	vp.startTeleportAnimation(time, from, to, cameraAnimationDelay)

func abortTeleportAnimation(keeper: Keeper):
	var vp = viewportContainersByKeeperId.get(keeper.playerId)
	if not vp:
		return

	vp.abortTeleportAnimation()

func getViewportContainer(keeper: Keeper):
	return viewportContainersByKeeperId.get(keeper.playerId)

func register_action_hint(action: String, label: String) -> int:
	var vp = viewportContainersByKeeperId.get(Keepers.local.first().playerId)
	if vp:
		return vp.player_canvas.action_hint_popup.register_hint(action, label)
	return -1

func set_action_hint_visible(index: int, value: bool):
	var keeper = Keepers.local.first()
	if not keeper:
		return

	var vp = viewportContainersByKeeperId.get(keeper.playerId)
	if vp:
		if value:
			vp.player_canvas.action_hint_popup.show_hint(index)
		else:
			vp.player_canvas.action_hint_popup.hide_hint(index)

func hideForAllLocalPlayersExcept(inExceptKeepers: Array[Keeper], inCanvasItem: CanvasItem) -> void :
	inCanvasItem.visibility_layer = 0
	for keeper: Keeper in Keepers.local.getAll():
		if keeper in inExceptKeepers:
			showForLocalKeeper(keeper, inCanvasItem)

func showForLocalKeeper(keeper: Keeper, inCanvasItem: CanvasItem) -> void :
	var keeperIdx: int = ViewportContainer.calcKeeperLocalIdx(keeper)
	var keeperSpecyficCanvasLayer: int = ViewportContainer.PLAYER_IDX_TO_CANVAS_LAYER_BIT[keeperIdx]
	inCanvasItem.visibility_layer |= 1 << keeperSpecyficCanvasLayer

func hideForLocalKeeper(keeper: Keeper, inCanvasItem: CanvasItem) -> void :
	var keeperIdx: int = ViewportContainer.calcKeeperLocalIdx(keeper)
	var keeperSpecyficCanvasLayer: int = ViewportContainer.PLAYER_IDX_TO_CANVAS_LAYER_BIT[keeperIdx]
	inCanvasItem.visibility_layer &= ~ (1 << keeperSpecyficCanvasLayer)

func ensureVisibilityForLocalPlayers(inLocalPlayers: Array[Keeper], inCanvasItem: CanvasItem) -> void :
	for keeper: Keeper in Keepers.local.getAll():
		if not keeper in inLocalPlayers:
			continue
		var keeperIdx: int = ViewportContainer.calcKeeperLocalIdx(keeper)
		var keeperSpecyficCanvasLayer: int = ViewportContainer.PLAYER_IDX_TO_CANVAS_LAYER_BIT[keeperIdx]
		inCanvasItem.visibility_layer |= 1 << keeperSpecyficCanvasLayer

func hideViewportsContent() -> void :
	var viewportsContainers = find_children("ViewportContainer*", "", true, false)
	for vc in viewportsContainers:
		vc.hideContent()

func showAllViewports() -> void :
	var localPlayersViewports: Array = viewportContainersByKeeperId.values()
	for vc: ViewportContainer in localPlayersViewports:
		var topBottomHolder: Control = vc.get_parent()
		topBottomHolder.show()
		vc.display()

func hideAllViewportsExcept(inExceptPlayerId: String) -> void :
	var localPlayersViewports: Array = viewportContainersByKeeperId.values()
	for vc: ViewportContainer in localPlayersViewports:
		vc.conceal()
		var topBottomHolder: Control = vc.get_parent()
		topBottomHolder.hide()
	var topBottomHolder: Control = viewportContainersByKeeperId[inExceptPlayerId].get_parent()
	topBottomHolder.show()
	viewportContainersByKeeperId[inExceptPlayerId].display()
