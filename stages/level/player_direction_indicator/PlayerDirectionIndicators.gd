class_name PlayerDirectionIndicators
extends Control

const INDICATOR_GAP: = 8.0
const INDICATOR_SCENE: = preload("res://stages/level/player_direction_indicator/PlayerDirectionIndicator.tscn")

class PathPlacement extends RefCounted:
	var position: Vector2
	var perimeterOffset: float

	func _init(inPosition: Vector2, inPerimeterOffset: float) -> void :
		position = inPosition
		perimeterOffset = inPerimeterOffset

@onready var _indicatorPath: Path2D = $IndicatorPath

var _viewerPlayerId: = ""
var _indicatorsByPlayerId: Dictionary = {}
var _lastPlacementsByPlayerId: Dictionary = {}
var _authoredCurve: Curve2D
var _authoredPathPoints: = PackedVector2Array()
var _runtimeCurve: Curve2D
var _pathPoints: = PackedVector2Array()
var _pathLength: = 0.0
var _pathMaximumRadius: = 0.0
var _pathPointOffsets: = PackedFloat32Array()
var _viewer: Keeper

func _ready() -> void :
	set_process(false)
	hide()
	Keepers.keepers_changed.connect(_onKeepersChanged)
	resized.connect(rebuildPathCache)
	_authoredCurve = _indicatorPath.curve.duplicate()
	_authoredPathPoints = _authoredCurve.tessellate()
	rebuildPathCache()

func init(viewer: Keeper) -> void :
	_viewerPlayerId = viewer.playerId
	reconcileIndicators()

func _onKeepersChanged() -> void :
	if _viewerPlayerId.is_empty():
		return
	if not Keepers.hasKeeper(_viewerPlayerId):
		hide()
		set_process(false)
		return
	reconcileIndicators()

func reconcileIndicators() -> void :
	_viewer = Keepers.getKeeper(_viewerPlayerId)
	var teammatesByPlayerId: = {}
	for keeper: Keeper in Keepers.getAllOfTeam(_viewer.teamId):
		if keeper.playerId != _viewerPlayerId:
			teammatesByPlayerId[keeper.playerId] = keeper

	for existingPlayerId: String in _indicatorsByPlayerId.keys():
		if not teammatesByPlayerId.has(existingPlayerId):
			_indicatorsByPlayerId[existingPlayerId].queue_free()
			_indicatorsByPlayerId.erase(existingPlayerId)
			_lastPlacementsByPlayerId.erase(existingPlayerId)

	for teammatePlayerId: String in teammatesByPlayerId:
		var teammate: Keeper = teammatesByPlayerId[teammatePlayerId]
		if _indicatorsByPlayerId.has(teammatePlayerId):
			_indicatorsByPlayerId[teammatePlayerId].keeper = teammate
			continue
		var indicator: PlayerDirectionIndicator = INDICATOR_SCENE.instantiate()
		indicator.name = "PlayerDirectionIndicator-" + teammatePlayerId
		add_child(indicator)
		indicator.init(teammate)
		_indicatorsByPlayerId[teammatePlayerId] = indicator

	var hasTeammates: = not _indicatorsByPlayerId.is_empty()
	visible = hasTeammates
	set_process(hasTeammates)

func _process(delta: float) -> void :
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if not Options.showPlayerIndicators:
		for indicator: PlayerDirectionIndicator in _indicatorsByPlayerId.values():
			indicator.hideImmediately()
		return

	var camera: Camera2D = Level.viewports.getPlayerCam(_viewerPlayerId)
	var worldViewport: Viewport = camera.get_viewport()
	var worldToIndicatorScale: Vector2 = size / worldViewport.get_visible_rect().size
	var canvasTransform: Transform2D = worldViewport.get_canvas_transform()
	var viewerInsideDome: bool = _viewer.isInsideDome
	var viewerInsideStation: bool = _viewer.isInsideStation
	var viewerDeviceId: int = _viewer.deviceId
	var pauseMenuOpen: bool = Level.stage.pauseMenuOpen
	var pausedDeviceId: int = Level.stage.pausedDeviceId
	var entries: Array = []

	for teammatePlayerId: String in _indicatorsByPlayerId:
		var indicator: PlayerDirectionIndicator = _indicatorsByPlayerId[teammatePlayerId]
		var keeper: Keeper = indicator.keeper
		if keeper.killed:
			indicator.hideImmediately()
			continue

		var projectedPosition: Vector2 = canvasTransform * keeper.global_position
		projectedPosition *= worldToIndicatorScale
		var offscreen: = not isPointOnScreen(projectedPosition, size)
		var shouldShow: = shouldShowIndicator(
			offscreen, 
			viewerInsideDome, 
			viewerInsideStation, 
			pauseMenuOpen, 
			pausedDeviceId, 
			viewerDeviceId
		)
		var transition: float = indicator.updateTransition(shouldShow, delta)
		if not shouldShow and is_zero_approx(transition):
			indicator.hide()
			continue

		var placement: PathPlacement
		if offscreen:
			placement = getPlacementForTarget(projectedPosition)
		else:
			placement = _lastPlacementsByPlayerId[teammatePlayerId]
		entries.append({
			"indicator": indicator, 
			"placement": placement, 
			"playerId": teammatePlayerId, 
			"projectedKeeperPosition": projectedPosition, 
		})

	placeIndicators(entries)

func placeIndicators(entries: Array) -> void :
	if entries.is_empty():
		return
	entries.sort_custom(compareEntriesByPerimeterOffset)

	var idealOffsets: Array[float] = []
	var spacingDiameters: Array[float] = []
	for entry: Dictionary in entries:
		var placement: PathPlacement = entry["placement"]
		var indicator: PlayerDirectionIndicator = entry["indicator"]
		idealOffsets.append(placement.perimeterOffset)
		spacingDiameters.append(indicator.getSeparationDiameter())
	var separatedOffsets: = separateOffsets(idealOffsets, spacingDiameters, INDICATOR_GAP)

	for index in entries.size():
		var entry: Dictionary = entries[index]
		var placement: = getPlacementAtOffset(separatedOffsets[index])
		var indicator: PlayerDirectionIndicator = entry["indicator"]
		indicator.placeAt(placement.position, entry["projectedKeeperPosition"])
		indicator.show()
		_lastPlacementsByPlayerId[entry["playerId"]] = placement

static func compareEntriesByPerimeterOffset(a: Dictionary, b: Dictionary) -> bool:
	var aOffset: float = a["placement"].perimeterOffset
	var bOffset: float = b["placement"].perimeterOffset
	if is_equal_approx(aOffset, bOffset):
		return a["playerId"] < b["playerId"]
	return aOffset < bOffset

func rebuildPathCache() -> void :
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var previousPathLength: = _pathLength
	var viewportScale: = size / CONST.BASE_RESOLUTION
	_runtimeCurve = _authoredCurve.duplicate()
	for index in _runtimeCurve.point_count:
		_runtimeCurve.set_point_position(index, _authoredCurve.get_point_position(index) * viewportScale)
		_runtimeCurve.set_point_in(index, _authoredCurve.get_point_in(index) * viewportScale)
		_runtimeCurve.set_point_out(index, _authoredCurve.get_point_out(index) * viewportScale)
	_pathPoints.clear()
	for point: Vector2 in _authoredPathPoints:
		_pathPoints.append(point * viewportScale)

	_pathLength = _runtimeCurve.get_baked_length()
	_pathPointOffsets.clear()
	for point: Vector2 in _pathPoints:
		_pathPointOffsets.append(_runtimeCurve.get_closest_offset(point))
	_pathPointOffsets[_pathPointOffsets.size() - 1] = _pathLength
	_pathMaximumRadius = 0.0
	var origin: = size * 0.5
	for point: Vector2 in _pathPoints:
		_pathMaximumRadius = maxf(_pathMaximumRadius, origin.distance_to(point))

	if previousPathLength > 0.0:
		for playerId: String in _lastPlacementsByPlayerId:
			var previousPlacement: PathPlacement = _lastPlacementsByPlayerId[playerId]
			var scaledOffset: = previousPlacement.perimeterOffset / previousPathLength * _pathLength
			_lastPlacementsByPlayerId[playerId] = getPlacementAtOffset(scaledOffset)

func getPlacementForTarget(targetPosition: Vector2) -> PathPlacement:
	var origin: = size * 0.5
	var direction: = (targetPosition - origin).normalized()
	var rayEnd: = origin + direction * (_pathMaximumRadius + 1.0)
	var closestDistance: = INF
	var closestPosition: = Vector2.ZERO
	var closestOffset: = 0.0

	for index in _pathPoints.size() - 1:
		var segmentStart: = _pathPoints[index]
		var segmentEnd: = _pathPoints[index + 1]
		var intersection: Variant = Geometry2D.segment_intersects_segment(
			origin, 
			rayEnd, 
			segmentStart, 
			segmentEnd
		)
		if intersection == null:
			continue
		var intersectionPosition: Vector2 = intersection
		var rayDistance: = origin.distance_to(intersectionPosition)
		if rayDistance < closestDistance:
			closestDistance = rayDistance
			closestPosition = intersectionPosition
			var segmentProgress: = segmentStart.distance_to(intersectionPosition)\
			/ segmentStart.distance_to(segmentEnd)
			closestOffset = lerpf(_pathPointOffsets[index], _pathPointOffsets[index + 1], segmentProgress)

	return PathPlacement.new(closestPosition, closestOffset)

func getPlacementAtOffset(offset: float) -> PathPlacement:
	var wrappedOffset: = fposmod(offset, _pathLength)
	return PathPlacement.new(_runtimeCurve.sample_baked(wrappedOffset), wrappedOffset)

func separateOffsets(idealOffsets: Array[float], spacingDiameters: Array[float], gap: float) -> Array[float]:
	if idealOffsets.size() <= 1:
		return idealOffsets.duplicate()

	var largestGapIndex: = 0
	var largestFreeGap: = - INF
	for index in idealOffsets.size():
		var nextIndex: = (index + 1) % idealOffsets.size()
		var nextOffset: = idealOffsets[nextIndex]
		if nextIndex == 0:
			nextOffset += _pathLength
		var freeGap: = nextOffset - idealOffsets[index]\
		- spacingDiameters[index] * 0.5 - spacingDiameters[nextIndex] * 0.5
		if freeGap > largestFreeGap:
			largestFreeGap = freeGap
			largestGapIndex = index

	var seam: = fposmod(
		idealOffsets[largestGapIndex] + spacingDiameters[largestGapIndex] * 0.5\
		+ maxf(0.0, largestFreeGap) * 0.5, 
		_pathLength
	)
	var unwrappedOffsets: Array[float] = []
	var unwrappedDiameters: Array[float] = []
	var originalIndices: Array[int] = []
	for orderIndex in idealOffsets.size():
		var originalIndex: = (largestGapIndex + 1 + orderIndex) % idealOffsets.size()
		unwrappedOffsets.append(fposmod(idealOffsets[originalIndex] - seam, _pathLength))
		unwrappedDiameters.append(spacingDiameters[originalIndex])
		originalIndices.append(originalIndex)

	var separatedUnwrapped: = separateLinearOffsets(
		unwrappedOffsets, 
		unwrappedDiameters, 
		gap * 0.5, 
		_pathLength - gap * 0.5, 
		gap
	)
	var separatedOffsets: Array[float] = []
	separatedOffsets.resize(idealOffsets.size())
	for orderIndex in separatedUnwrapped.size():
		separatedOffsets[originalIndices[orderIndex]] = fposmod(seam + separatedUnwrapped[orderIndex], _pathLength)
	return separatedOffsets

static func separateLinearOffsets(idealOffsets: Array[float], spacingDiameters: Array[float], minimum: float, maximum: float, gap: float) -> Array[float]:
	var separated: Array[float] = []
	for index in idealOffsets.size():
		var halfDiameter: = spacingDiameters[index] * 0.5
		var offset: = clampf(idealOffsets[index], minimum + halfDiameter, maximum - halfDiameter)
		if index > 0:
			var previousHalfDiameter: = spacingDiameters[index - 1] * 0.5
			offset = maxf(offset, separated[index - 1] + previousHalfDiameter + gap + halfDiameter)
		separated.append(offset)

	var lastIndex: = separated.size() - 1
	separated[lastIndex] = minf(separated[lastIndex], maximum - spacingDiameters[lastIndex] * 0.5)
	for index in range(separated.size() - 2, -1, -1):
		var halfDiameter: = spacingDiameters[index] * 0.5
		var nextHalfDiameter: = spacingDiameters[index + 1] * 0.5
		separated[index] = minf(separated[index], separated[index + 1] - halfDiameter - gap - nextHalfDiameter)

	separated[0] = maxf(separated[0], minimum + spacingDiameters[0] * 0.5)
	for index in range(1, separated.size()):
		var halfDiameter: = spacingDiameters[index] * 0.5
		var previousHalfDiameter: = spacingDiameters[index - 1] * 0.5
		separated[index] = maxf(separated[index], separated[index - 1] + previousHalfDiameter + gap + halfDiameter)
	return separated

static func isPointOnScreen(point: Vector2, viewportSize: Vector2) -> bool:
	return Rect2(Vector2.ZERO, viewportSize).has_point(point)

static func shouldShowIndicator(
	offscreen: bool, 
	viewerInsideDome: bool, 
	viewerInsideStation: bool, 
	pauseMenuOpen: bool, 
	pausedDeviceId: int, 
	viewerDeviceId: int
) -> bool:
	var viewerPauseMenuOpen: = pauseMenuOpen and pausedDeviceId == viewerDeviceId
	return offscreen and not (viewerInsideDome or viewerInsideStation or viewerPauseMenuOpen)
