extends InputProcessor

var moveableDevice

var leftKeyDown: = false
var rightKeyDown: = false
var upKeyDown: = false
var downKeyDown: = false
var backKeyDown: = false
var stickMove: = Vector2()

func becameLeaf():
	notLeaf()

func notLeaf():
	leftKeyDown = false
	rightKeyDown = false
	upKeyDown = false
	downKeyDown = false
	if moveableDevice:
		moveableDevice.moveDirectionInput.x = 0
		moveableDevice.moveDirectionInput.y = 0

func buttonEvent(event) -> bool:
	if pressed(event, "ui_left"):
		leftKeyDown = true
	elif pressed(event, "ui_right"):
		rightKeyDown = true
	elif pressed(event, "ui_up"):
		upKeyDown = true
	elif pressed(event, "ui_down"):
		downKeyDown = true
	elif released(event, "ui_left"):
		leftKeyDown = false
	elif released(event, "ui_right"):
		rightKeyDown = false
	elif released(event, "ui_up"):
		upKeyDown = false
	elif released(event, "ui_down"):
		downKeyDown = false
	elif justPressed(event, "ui_select"):
		moveableDevice.select()
	elif justPressed(event, "ui_cancel"):
		moveableDevice.deselect()

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
		md += stickMove
	elif md.length() > 1.0:
		md = md.normalized()
	moveableDevice.moveDirectionInput = md

	return true

func stick_move(event: InputEventJoypadMotion) -> bool:
	match event.axis:
		0:
			if abs(event.axis_value) <= Options.gamepadStickDeadZone:
				stickMove.x = 0
			else:
				stickMove.x = (event.axis_value - (sign(event.axis_value) * Options.gamepadStickDeadZone)) * (1.0 / (1.0 - Options.gamepadStickDeadZone))
		1:
			if abs(event.axis_value) <= Options.gamepadStickDeadZone:
				stickMove.y = 0
			else:
				stickMove.y = (event.axis_value - (sign(event.axis_value) * Options.gamepadStickDeadZone)) * (1.0 / (1.0 - Options.gamepadStickDeadZone))
		_:
			return false

	if not (rightKeyDown or leftKeyDown or upKeyDown or downKeyDown):
		var md = Vector2(stickMove.x, stickMove.y)
		if md.length() > 1.0:
			md = md.normalized()

		moveableDevice.moveDirectionInput = md

	return true
