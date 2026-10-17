class_name KeeperInputProcessor
extends InputProcessor

signal escape

var leftStickMove: = Vector2()
var rightStickMove: = Vector2()

var leftKeyDown: = false
var rightKeyDown: = false
var upKeyDown: = false
var downKeyDown: = false

var useKeyDown: = false
var useHold: = false
var useHoldHandled: = false
var useKeyDownTime: = 0.0
var useKeyCooldown: = 0.0

var keeper
var playerId: String

var runningInLoadout: = false
var isLeaf: = false

func _ready():
	stopWithPredecessor = false
	add_to_group("gamepadListeners")

func handleStart():
	if is_instance_valid(keeper):
		keeper.onInputMethodChanged()

func _process(delta):
	if GameWorld.paused or desintegrating:
		return
	if not is_instance_valid(keeper):
		desintegrate()
		queue_free()
		return

	if useKeyDown:
		useKeyDownTime += delta
		if useKeyDownTime > 0.3:
			useHoldHandled = keeper.useHold()
			useHold = true

			useKeyDownTime -= useKeyCooldown
			useKeyCooldown = max(0.05, useKeyCooldown * 0.6)
	else:
		useKeyCooldown = 0.25

func notLeaf():
	isLeaf = false
	clearInput()

func becameLeaf():
	isLeaf = true
	setShowMouse()
	tryRestoreInput()

func setShowMouse() -> void :
	if not is_instance_valid(keeper):

		return
	if Options.useGamepad(keeper.deviceId):
		return

	var anyKeeperUsingMouse: bool = false
	for keeper: Keeper in Keepers.local.getAll():
		anyKeeperUsingMouse = anyKeeperUsingMouse or keeper.hasMouseGameplay

	GameWorld.setShowMouse(runningInLoadout or (anyKeeperUsingMouse and keeper.input_settings.use_mouse))

func handle(event) -> bool:
	if isLeaf and not InputSystem.singleFocus:
		setShowMouse()

	return super.handle(event)

func tryRestoreInput():
	if not is_instance_valid(keeper):
		return

	if Options.useGamepad(keeper.deviceId):
		if not GameWorld.isSplitScreen():





			leftStickMove.x = Utils.convertGamepadAxisInput(Input.get_joy_axis(0, JOY_AXIS_LEFT_X))
			leftStickMove.y = Utils.convertGamepadAxisInput(Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
			rightStickMove.x = Utils.convertGamepadAxisInput(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X))
			rightStickMove.y = Utils.convertGamepadAxisInput(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
			leftKeyDown = false
			rightKeyDown = false
			upKeyDown = false
			downKeyDown = false
			processStickMove()
	else:
		rightStickMove *= 0
		leftStickMove *= 0




		leftKeyDown = isActionKeyPressed("ui_left")
		rightKeyDown = isActionKeyPressed("ui_right")
		upKeyDown = isActionKeyPressed("ui_up")
		downKeyDown = isActionKeyPressed("ui_down")

		var md: = calculateMoveDirection()
		if keeper and is_instance_valid(keeper):
			keeper.moveDirectionInput = md

func isActionKeyPressed(action: String) -> bool:
	if not Input.is_action_pressed(action):
		return false

	var events: = InputMap.action_get_events(action)
	for event in events:
		if not event is InputEventKey:
			continue
		var inputEventKey: = event as InputEventKey
		if Input.is_physical_key_pressed(inputEventKey.physical_keycode):
			return true

	return false

func onInputMethodChanged():
	tryRestoreInput()

func clearInput():
	leftKeyDown = false
	rightKeyDown = false
	upKeyDown = false
	downKeyDown = false
	useKeyDown = false
	useHold = false
	useHoldHandled = false
	useKeyDownTime = 0.0
	leftStickMove = Vector2()
	rightStickMove = Vector2()
	if keeper and is_instance_valid(keeper):
		keeper.moveDirectionInput.x = 0
		keeper.moveDirectionInput.y = 0
		keeper.aimDirectionInput.x = 0
		keeper.aimDirectionInput.y = 0
		keeper.pressingUse = false

func handleStop():
	notLeaf()

func buttonEvent(event) -> bool:
	var handled: = true
	if keeper == null:
		return false
	if pressed(event, "ui_left"):
		leftKeyDown = true
	elif pressed(event, "ui_right"):
		rightKeyDown = true
	elif pressed(event, "ui_up"):
		upKeyDown = true
	elif pressed(event, "ui_down"):
		downKeyDown = true
	elif justPressed(event, "escape"):
		Level.stage.openPauseMenu(keeper)
	elif justPressed(event, "ui_select"):
		useKeyDownTime = 0.0
		useHold = false
		useHoldHandled = false
		useKeyDown = true
		keeper.pressingUse = true
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
	elif released(event, "ui_select"):
		keeper.pressingUse = false




		if event is InputEventMouseButton and runningInLoadout and keeper.position.y > 0:
			handled = true
			useKeyDown = false
		elif useKeyDown:
			useKeyDown = false
			if not useHold and not GameWorld.paused:
				handled = keeper.useHit()
				useKeyDownTime = 0.0
			else:
				handled = false
		useHoldHandled = false
	elif justPressed(event, "pause"):
		if not Level.stage.pauseMenuOpen:
			if GameWorld.paused:
				if Level.stage.pausedByPlayer:
					Level.stage.unpause(true)
			else:
				Level.stage.pause(true)
	else:
		handled = false

	keeperButtonEvent(event, handled)

	if justPressed(event, "keeper_gadget1"):
		for s in get_tree().get_nodes_in_group("special1"):
			if s.teamId == keeper.teamId:
				var consumed = s.executeSpecial1(keeper)
				if consumed:
					break
	elif justPressed(event, "keeper_gadget2"):
		for s in get_tree().get_nodes_in_group("special2"):
			if s.teamId == keeper.teamId:
				var consumed = s.executeSpecial2(keeper)
				if consumed:
					break
	elif justPressed(event, "cheats"):

		return false
	elif justPressed(event, "escape"):
		return false

	if desintegrating:
		return true

	var md: = calculateMoveDirection()
	if keeper:
		keeper.moveDirectionInput = md
	if Options.useGamepad(deviceId) and not keeper.input_settings.use_twinstick:
		if keeper:
			keeper.aimDirectionInput = md
	return md.length() > 0 or handled

func calculateMoveDirection() -> Vector2:
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
	elif md.length() > 1.0:
		md = md.normalized()
	return md

func onUserTabbedOut():
	clearInput()

func onPaused():
	clearInput()
	pass

func keeperButtonEvent(event, handled: bool):
	pass

func stick_move(event: InputEventJoypadMotion) -> bool:
	var value = Utils.convertGamepadAxisInput(event.axis_value)
	match event.axis:
		JOY_AXIS_LEFT_X:
			leftStickMove.x = value
		JOY_AXIS_LEFT_Y:
			leftStickMove.y = value
		JOY_AXIS_RIGHT_X:
			rightStickMove.x = value
		JOY_AXIS_RIGHT_Y:
			rightStickMove.y = value
		_:
			return false

	processStickMove()


	return true

func processStickMove():
	if not keeper:
		return

	if not (rightKeyDown or leftKeyDown or upKeyDown or downKeyDown):
		var left = Vector2(leftStickMove.x, leftStickMove.y)
		if left.length() > 1.0:
			left = left.normalized()

		var right = Vector2(rightStickMove.x, rightStickMove.y)
		if right.length() > 1.0:
			right = right.normalized()

		keeper.moveDirectionInput = left
		if keeper.input_settings.use_twinstick:
			keeper.aimDirectionInput = right
		else:
			keeper.aimDirectionInput = left
	elif keeper.input_settings.use_twinstick:
		var right = Vector2(rightStickMove.x, rightStickMove.y)
		if right.length() > 1.0:
			right = right.normalized()
		keeper.aimDirectionInput = right
