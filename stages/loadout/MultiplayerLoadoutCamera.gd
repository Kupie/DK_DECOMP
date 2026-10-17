extends CameraBase

signal target_zoom_changed
@export var scroll_speed: float = 2.0

var zoomStagePx: float = 4.0
var camMoveSpeed: = 1.0
var zoomSpeed: = 2.0
var mergeScreenZoom: = 0.0
var prevInsideStation
var playerId: String
var targetOffset: = Vector2.ZERO

func init(keeper):
	target = keeper
	playerId = keeper.playerId

	if target is Keeper:
		target = target as Keeper
		target.registerCamera(self)

func getTargetZoom() -> float:
	return zoomStagePx

func _process(delta):
	if not target:
		return

	if target.isInsideStation:
		var d = (Level.domesByTeamId.values().front().position + Vector2(0, -180)) - position
		position += d * delta * camMoveSpeed
		var stationZoom: float = _getStationZoom()
		zoomTo(stationZoom)
	else:
		var diff = (target.position - position).limit_length(20)
		var change = diff * delta * scroll_speed

		var vpSize = get_viewport_rect().size * (Vector2(1.0 / zoom.x, 1.0 / zoom.y))
		var margin: = 10
		var width = 0.3 * vpSize.x
		var height = 0.4 * vpSize.y
		$TileDetectorLeft.position = Vector2( - vpSize.x * 0.5 + margin, 0)
		$TileDetectorLeft / CollisionShape2D.shape.extents = Vector2(10, height)
		$TileDetectorRight.position = Vector2(vpSize.x * 0.5 - margin, 0)
		$TileDetectorRight / CollisionShape2D.shape.extents = Vector2(10, height)



		$TileDetectorUp.position = Vector2(0, - vpSize.y * 0.5 + margin)
		$TileDetectorUp / CollisionShape2D.shape.extents = Vector2(width, 10)
		$TileDetectorUpSmall.position = Vector2(0, - vpSize.y * 0.5 + margin)
		$TileDetectorUpSmall / CollisionShape2D.shape.extents = Vector2(width, 5)
		$TileDetectorDown.position = Vector2(0, vpSize.y * 0.5 - margin)
		$TileDetectorDown / CollisionShape2D.shape.extents = Vector2(width, 10)
		if $TileDetectorLeft.get_overlapping_areas().is_empty():
			change.x = max(0, change.x)
		if $TileDetectorRight.get_overlapping_areas().is_empty():
			change.x = min(0, change.x)



		if $TileDetectorUpSmall.get_overlapping_areas().is_empty():
			if $TileDetectorUp.get_overlapping_areas().is_empty():
				change.y = max(100 * delta, change.y)
			else:
				change.y = max(0, change.y)

		var isAboveSurface = position.y < 0
		if $TileDetectorDown.get_overlapping_areas().is_empty() and not isAboveSurface:
			change.y = min(0, change.y)
		position += change

		zoomTo(GameWorld.getEffectiveLoadoutZoom())

func _getStationZoom() -> float:
	var isOneLocalPlayer: bool = Keepers.local.getAll().size() == 1
	var areExactlyTwoLocalPlayers: bool = Keepers.local.getAll().size() == 2
	var areMoreThenTwoPlayers: bool = Keepers.local.getAll().size() > 2
	if isOneLocalPlayer:
		return 2.0
	elif areExactlyTwoLocalPlayers:
		return 2.5
	elif areMoreThenTwoPlayers:
		return 1.5
	return 2.0

func zoomTo(pixelStage: float):
	if pixelStage == zoomStagePx:
		return

	var yOffset: = 0
	if Keepers.local.oneInsideDome():
		yOffset = 330

	self.zoomStagePx = pixelStage
	$Tween.interpolate_property(self, "cameraRestPositionInDome:y", cameraRestPositionInDome.y, getCameraRestPosition(zoomStagePx) + yOffset, 1.0, Tween.TRANS_QUINT, Tween.EASE_OUT)
	$Tween.interpolate_property(self, "zoom", zoom, Vector2.ONE * zoomStagePx, zoomSpeed, Tween.TRANS_QUAD, Tween.EASE_OUT)
	$Tween.start()

	target_zoom_changed.emit()
