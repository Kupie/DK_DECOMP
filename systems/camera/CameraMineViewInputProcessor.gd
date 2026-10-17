extends InputProcessor

signal reveal_resources

const MIN_BETWEEN_DOME_SURFACE_DISTANCE = 200.0

var popup
var cam

var autoSpeed: = 30.0
var manualSpeed: = 120.0
var camDirection: = Vector2.ZERO
var nextPoI
var emptyTravelPoint: Vector2

var leftKeyDown: = false
var rightKeyDown: = false
var upKeyDown: = false
var downKeyDown: = false
var leftStickMove: = Vector2()

func handleStart():
	cam = InputSystem.getCamera()
	setAutoMove(GameWorld.autoMoveCameraInMineView)

func setAutoMove(do: bool):
	if GameWorld.autoMoveCameraInMineView != do:
		manualSpeed = 120
	GameWorld.autoMoveCameraInMineView = do
	popup.updateForAutoMove()
	if GameWorld.autoMoveCameraInMineView:
		updateNextPoI()

func buttonEvent(event) -> bool:
	popup.updateDevice(event)
	if pressed(event, "ui_left"):
		setAutoMove(false)
		leftKeyDown = true
	elif pressed(event, "ui_right"):
		setAutoMove(false)
		rightKeyDown = true
	elif pressed(event, "ui_up"):
		setAutoMove(false)
		upKeyDown = true
	elif pressed(event, "ui_down"):
		setAutoMove(false)
		downKeyDown = true
	elif justPressed(event, "dome_ability1"):
		popup.hideRevealResourcesContainer()
		emit_signal("reveal_resources")
	elif pressed(event, "ui_cancel"):
		desintegrate()
		return true
	elif justPressed(event, "ui_select"):
		setAutoMove( not GameWorld.autoMoveCameraInMineView)
	elif justPressed(event, "cheats"):
		Level.stage.toggleCheats()
	elif released(event, "ui_left"):
		leftKeyDown = false
	elif released(event, "ui_right"):
		rightKeyDown = false
	elif released(event, "ui_up"):
		upKeyDown = false
	elif released(event, "ui_down"):
		downKeyDown = false
	return true

func _process(delta):
	if not GameWorld.autoMoveCameraInMineView:
		processManualCam(delta)
		return

	var toGoal: Vector2
	if nextPoI:
		toGoal = nextPoI.global_position - cam.global_position
		if toGoal.length() < 80:
			updateNextPoI()
	else:
		updateNextPoI()
		if is_instance_valid(nextPoI):
			toGoal = nextPoI.global_position - cam.global_position
		else:
			if not emptyTravelPoint:
				updateEmptyTravelPoint()
			toGoal = emptyTravelPoint - cam.global_position
			if toGoal.length() <= 1.0:
				updateEmptyTravelPoint()

	camDirection = lerp(camDirection, toGoal.normalized(), 0.02)
	var speed = autoSpeed * clamp(toGoal.length() / 50.0, 0.4, 1.0)
	cam.position += delta * speed * camDirection
	var cameraNearSurfaceBgEdge = _isPositionBetweenDomes(cam.position) and \
	cam.position.y < MIN_BETWEEN_DOME_SURFACE_DISTANCE
	if cameraNearSurfaceBgEdge:
		var expectedTravelLength: float = delta * speed * camDirection.length()
		cam.position.y += expectedTravelLength

	var godot3CameraZoom = Vector2.ONE * clamp(float(clamp(max(0, cam.position.y - 150) / 500, 0.25, 1.0)), 0.25, 0.5)
	cam.zoom = Vector2.ONE / godot3CameraZoom

func _isPositionBetweenDomes(inPosition: Vector2) -> bool:
	if Level.teams.size() == 1:
		return false
	var margin: = Vector2(100.0, 0.0)
	var dome1MarginPos: Vector2 = Utils.get_dome_position("team1") + margin
	var dome2MarginPos: Vector2 = Utils.get_dome_position("team2") - margin
	var isBetweenDomes: bool = Level.teams.size() > 1 and inPosition.x > dome1MarginPos.x and \
	inPosition.x < dome2MarginPos.x
	return isBetweenDomes

func processManualCam(delta):
	var md: = Vector2()
	if leftKeyDown:
		md.x -= 1
	if rightKeyDown:
		md.x += 1
	if upKeyDown:
		md.y -= 1
	if downKeyDown:
		md.y += 1

	if md.length() == 0:
		md += leftStickMove
	if md.length() == 0:
		manualSpeed = lerp(manualSpeed, 120.0, 0.5)
	else:
		manualSpeed = lerp(manualSpeed, 450.0, 0.03)
	if md.length() > 1:
		md = md.normalized()
	camDirection = lerp(camDirection, md, 0.2)
	cam.position = keepInBounds(cam.position + delta * manualSpeed * camDirection)
	cam.zoom = Vector2.ONE / 0.5

func keepInBounds(position) -> Vector2:
	const CAM_WIDTH_ADJUSTMENT = 300
	const CAM_HEIGHT_ADJUSTMENT = 200

	var size = Level.map.tilemap_size * GameWorld.TILE_SIZE
	var domeXPosition: int = _getPositionOfCloserDome(position).x
	var clampw = max(domeXPosition, domeXPosition + size.x * 0.5 - CAM_WIDTH_ADJUSTMENT)

	if position.y < 300:
		clampw = 0
	elif position.y < 300 + clampw:
		clampw = lerp(0.0, clampw, (position.y - 300) / clampw)

	position.y = clamp(position.y, -200, size.y - CAM_HEIGHT_ADJUSTMENT)
	position.x = clamp(position.x, domeXPosition - clampw, domeXPosition + clampw)
	return position

func _getPositionOfCloserDome(position: Vector2) -> Vector2:
	var closestDomePos: Vector2 = Utils.get_dome_position(Level.teams.front())
	var smallestHDistance: float = abs(position.x - closestDomePos.x)
	for teamId: String in Level.teams:
		var teamDomePosition: Vector2 = Utils.get_dome_position(teamId)
		var currentHDistance = abs(position.x - teamDomePosition.x)
		if currentHDistance < smallestHDistance:
			smallestHDistance = currentHDistance
			closestDomePos = teamDomePosition
	return closestDomePos

func stick_move(event: InputEventJoypadMotion) -> bool:
	match event.axis:
		0:
			if abs(event.axis_value) <= Options.gamepadStickDeadZone:
				leftStickMove.x = 0
			else:
				popup.updateDevice(event)
				setAutoMove(false)
				leftStickMove.x = (event.axis_value - (sign(event.axis_value) * Options.gamepadStickDeadZone)) * (1.0 / (1.0 - Options.gamepadStickDeadZone))
		1:
			if abs(event.axis_value) <= Options.gamepadStickDeadZone:
				leftStickMove.y = 0
			else:
				popup.updateDevice(event)
				setAutoMove(false)
				leftStickMove.y = (event.axis_value - (sign(event.axis_value) * Options.gamepadStickDeadZone)) * (1.0 / (1.0 - Options.gamepadStickDeadZone))
		_:
			return false

	return true

func updateNextPoI():
	var pointsOfInterest: = []
	for chamber in get_tree().get_nodes_in_group("chamber"):
		if chamber.isRevealed():
			pointsOfInterest.append(chamber)
	for cave in get_tree().get_nodes_in_group("cave"):
		if cave.isRevealed():
			pointsOfInterest.append(cave)

	pointsOfInterest.sort_custom(byDistance)

	if not pointsOfInterest.is_empty():
		if randf() > 0.6 and pointsOfInterest.size() > 1:
			nextPoI = pointsOfInterest[1]
		else:
			nextPoI = pointsOfInterest[0]

func byDistance(a, b):
	return cam.global_position.distance_to(a.global_position) > cam.global_position.distance_to(b.global_position)

func updateEmptyTravelPoint():
	var visibleCoords: Array = Level.map.visibleTileCoords.keys()
	if Level.teams.size() > 1:


		visibleCoords = visibleCoords.filter(_filterOutTooCloseToSurface)

	if randf() > 0.7 and visibleCoords.size() > 0:
		emptyTravelPoint = Level.map.tileData.map_to_local(visibleCoords[randi() % visibleCoords.size()])
		return

	var lowest: Vector2 = Level.map.tileData.local_to_map(_getPositionOfCloserDome(cam.global_position))
	for coord in visibleCoords:
		if coord.y > lowest.y:
			lowest = coord

	emptyTravelPoint = Level.map.tileData.map_to_local(lowest)

func _filterOutTooCloseToSurface(inTileCoord: Vector2) -> bool:
	var tilePos: Vector2 = Level.map.getTilePos(inTileCoord)
	var isTileBetweenDomes = _isPositionBetweenDomes(tilePos)
	if not isTileBetweenDomes:
		return true
	var tooCloseToSurface = (tilePos.y < MIN_BETWEEN_DOME_SURFACE_DISTANCE)
	return not tooCloseToSurface

func handleStop():
	popup.moveOut()
