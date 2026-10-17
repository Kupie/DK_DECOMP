class_name KeeperCamera extends CameraBase

enum _Edge{LEFT, RIGHT, TOP, BOTTOM}


const BATTLE_TOP_RIGHT_LOCAL_FOCUS_POINT = Vector2(450, -465)
const BATTLE_BOTTOM_LOCAL_FOCUS_POINT_TWO_LOCAL_PLAYERS = Vector2(0, 24)
const BATTLE_BOTTOM_LOCAL_FOCUS_POINT_THREE_AND_MORE_LOCAL_PLAYERS = Vector2(0, 70)

signal target_zoom_changed

var tween: DeprecatedTween

var zoomStagePx: float = 4.0
var camMoveSpeed: = 1.0
var zoomSpeed: = 3.0
var mergeScreenZoom: = 0.0
var playerId: String
var _timeSinceWave: float = INF
var targetOffset: = Vector2.ZERO

func init(target):
	self.target = target
	zoomStagePx = target.goalCameraZoom
	playerId = target.playerId
	updateCameraRestPosition()
	if target.getIsInsideDome():
		position = cameraRestPositionInDome
	else:
		position = target.position

	shake_noise = FastNoiseLite.new()
	shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	zoom = Vector2.ONE * zoomStagePx
	tween = DeprecatedTween.new()
	add_child(tween)
	tween.setProcessingMode(Tween.TweenProcessMode.TWEEN_PROCESS_PHYSICS)
	if not get_tree().get_root().size_changed.is_connected(screen_size_changed):
		get_tree().get_root().size_changed.connect(screen_size_changed)
	screen_size_changed()
	if target is Keeper:
		target = target as Keeper
		target.registerCamera(self)

func updateCameraRestPosition():
	cameraRestPositionInDome.y = getCameraRestPosition(zoomStagePx)
	var dome = Level.domesByTeamId[target.teamId]
	cameraRestPositionInDome.x = dome.position.x

func screen_size_changed():



	cameraRestPositionInDome.y = getCameraRestPosition(zoomStagePx)
	if target.isInsideDome:
		position.y = getCurrentParallaxRestPosition(zoomStagePx)

func hasValidTarget() -> bool:
	return is_instance_valid(target)

func _process(delta: float) -> void :
	if not target:
		return

	var isWaveOngoing: bool = Data.of(target.teamId + ".monsters.wavepresent")
	if isWaveOngoing and target.isInsideDome:
		if Keepers.isSplitScreen:
			camMoveSpeed = 2.0
			var teamId: String = Keepers.getKeeper(playerId).teamId
			var domePosition: Vector2 = Utils.get_dome_position(teamId)
			var globalTopRightFocusPoint: Vector2 = domePosition + BATTLE_TOP_RIGHT_LOCAL_FOCUS_POINT
			var globalBottomFocusPoint: Vector2 = domePosition + _getWaveLocalFocusPoint()
			var new_zoom: float = _calcZoomToFitPoints(globalTopRightFocusPoint, globalBottomFocusPoint, teamId)
			zoomTo(new_zoom)
		else:
			zoomTo(2)
	else:
		if target.isInsideDome:
			var camZoom: float = _getDomePeaceZoom()
			zoomTo(camZoom)
		else:
			if Keepers.isSplitScreen:
				zoomTo(Data.of(target.playerId + ".keeper.zoominmine") - 1)
				camMoveSpeed = 2.0
			else:
				zoomTo(Data.of(target.playerId + ".keeper.zoominmine") - mergeScreenZoom)
				camMoveSpeed = 1.0

	_timeSinceWave = 0.0 if isWaveOngoing else _timeSinceWave + delta
	process_shake(delta)

	if GameWorld.won or GameWorld.lost:
		return

	var camDelta: = getCamDelta()

	camDelta.y += sign(camDelta.y)

	camDelta.y = camDelta.y + (max(0, abs(camDelta.y) - 30) / 30.0) * camDelta.y
	var s = target.currentSpeed() * 2.0
	var _camDeltaBeforeClamp: = camDelta
	camDelta.y = clamp(camDelta.y, - s, s)


	camMovement = camDelta

	if camMovement.length() > 5.0:
		position += camMovement * camMoveSpeed * delta

func _getWaveLocalFocusPoint() -> Vector2:
	var twoLocalPlayers: bool = Keepers.local.getCount() == 2
	if twoLocalPlayers:
		return BATTLE_BOTTOM_LOCAL_FOCUS_POINT_TWO_LOCAL_PLAYERS
	else:
		return BATTLE_BOTTOM_LOCAL_FOCUS_POINT_THREE_AND_MORE_LOCAL_PLAYERS

func _calcZoomToFitPoints(inTopRightPoint: Vector2, inBottomPoint: Vector2, inTeamID: String) -> float:
	var viewportSize: Vector2 = get_viewport().get_visible_rect().size
	var cameraRestPos: Vector2 = _calcCameraBattleRestPositionInDome()

	var focusOffset = (inTopRightPoint - cameraRestPos).abs()

	focusOffset.x = max(focusOffset.x, 0.001)
	focusOffset.y = max(focusOffset.y, 0.001)

	var zoomX = (viewportSize.x / 2.0) / focusOffset.x
	var zoomY = (viewportSize.y / 2.0) / focusOffset.y
	var smallerZoom: float = min(zoomX, zoomY)
	var domeRest: Vector2 = Utils.get_global_from_local_dome_position(getDomeRestPos(), inTeamID)
	var rightEdgeFreeSpace: float = _distanceToCameraEdge(domeRest, inTopRightPoint, _Edge.RIGHT)
	var bottomFreeSpace: float = _distanceToCameraEdge(global_position, inBottomPoint, _Edge.BOTTOM)
	var isSpaceOptimizationPossible: bool = bottomFreeSpace < 0 and rightEdgeFreeSpace < 0
	var moreSignificantSpace: float = max(bottomFreeSpace, rightEdgeFreeSpace)
	if isSpaceOptimizationPossible:
		var aspect = abs(moreSignificantSpace / 100.0)
		var zoomFactor = min(2.0, lerp(1.0, 2.0, aspect))
		return smallerZoom * zoomFactor
	return smallerZoom

func getCamDelta() -> Vector2:
	var camDelta: = Vector2()
	if target.isInsideDome:
		var isWave: bool = Data.of(target.teamId + ".monsters.wavepresent")
		if isWave:
			camDelta = _calcCameraBattleRestPositionInDome() - position
		else:
			camDelta = cameraRestPositionInDome - position
	else:
		var targetPos: Vector2 = target.position + targetOffset
		camDelta.x = targetPos.x - position.x
		camDelta.y = targetPos.y - position.y

	return camDelta

func getCurrentParallaxRestPosition(zoomLevel: float) -> float:

	var peaceRestPosition: float = super.getCameraRestPosition(zoomLevel)
	var battleRestPosition: float = _calcCameraBattleRestPositionInDome().y
	var transitionDuration: float = 2.0
	var weight: float = min(_timeSinceWave, transitionDuration) / transitionDuration
	var rest: float = lerp(battleRestPosition, peaceRestPosition, weight)
	return rest




func _calcCameraBattleRestPositionInDome() -> Vector2:
	var dstToTopEdge = _distanceToCameraEdge(getDomeRestPos(), BATTLE_TOP_RIGHT_LOCAL_FOCUS_POINT, _Edge.TOP)
	var newCamRestPos: Vector2 = cameraRestPositionInDome - Vector2(0, dstToTopEdge)
	var bottomLocalFocusPoint: Vector2 = _getWaveLocalFocusPoint()
	var dst2Dome = _distanceToCameraEdge(newCamRestPos, bottomLocalFocusPoint, _Edge.BOTTOM)
	if dst2Dome > 0:
		newCamRestPos.y += dst2Dome
	return newCamRestPos



func _distanceToCameraEdge(inCameraPos: Vector2, point: Vector2, inEdge: _Edge) -> float:
	var viewportSize = get_viewport().get_visible_rect().size
	var visibleWorldSize = viewportSize / zoom

	var edgeLeft = inCameraPos.x - visibleWorldSize.x / 2.0
	var edgeRight = inCameraPos.x + visibleWorldSize.x / 2.0
	var edgeTop = inCameraPos.y - visibleWorldSize.y / 2.0
	var edgeBottom = inCameraPos.y + visibleWorldSize.y / 2.0

	var distLeft = edgeLeft - point.x
	var distRight = point.x - edgeRight
	var distTop = edgeTop - point.y
	var distBottom = point.y - edgeBottom
	if inEdge == _Edge.LEFT:
		return distLeft
	if inEdge == _Edge.RIGHT:
		return distRight
	if inEdge == _Edge.TOP:
		return distTop
	if inEdge == _Edge.BOTTOM:
		return distBottom
	return 0.0

func _getDomePeaceZoom() -> float:
	const TWO_PLAYER_ZOOM: = 4.0
	const THREE_AND_MORE_PLAYER_ZOOM: = 2.5

	var isOneLocalPlayer = not Keepers.isSplitScreen
	if isOneLocalPlayer:
		return target.goalCameraZoom

	var twoLocalPlayers: bool = Keepers.local.getCount() == 2
	if twoLocalPlayers:
		return TWO_PLAYER_ZOOM
	else:
		return THREE_AND_MORE_PLAYER_ZOOM

func jump():
	position += getCamDelta()

func getDomeRestPos() -> Vector2:
	return Vector2(0, cameraRestPositionInDome.y)

func overrideZoom(value: Vector2):
	zoom = value
	tween.remove_all()

func getTargetZoom() -> float:
	return zoomStagePx

func zoomTo(pixelStage: float):
	if pixelStage == zoomStagePx:
		return

	var yOffset: = 0
	var mustLowerCameraForSecondStationVisibility: bool = Keepers.local.getCount() > 2
	if target.isInsideDome and pixelStage == 1.0:
		yOffset = 330
	elif mustLowerCameraForSecondStationVisibility:
		yOffset = 110

	self.zoomStagePx = pixelStage
	tween.interpolate_property(self, "cameraRestPositionInDome:y", cameraRestPositionInDome.y, getCameraRestPosition(zoomStagePx) + yOffset, 1.0, Tween.TRANS_QUINT, Tween.EASE_OUT)
	tween.interpolate_property(self, "zoom", zoom, Vector2.ONE * zoomStagePx, zoomSpeed, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.start()

	target_zoom_changed.emit()

func snapZoomTo(pixelStage: float):
	tween.remove_all()
	if pixelStage == zoomStagePx:
		return

	var yOffset: = 0
	var mustLowerCameraForSecondStationVisibility: bool = Keepers.local.getCount() > 2
	if target.isInsideDome and pixelStage == 1.0:
		yOffset = 330
	elif mustLowerCameraForSecondStationVisibility:
		yOffset = 110

	self.zoomStagePx = pixelStage
	cameraRestPositionInDome.y = getCameraRestPosition(zoomStagePx) + yOffset
	position = cameraRestPositionInDome
	zoom = Vector2.ONE * pixelStage

	target_zoom_changed.emit()
