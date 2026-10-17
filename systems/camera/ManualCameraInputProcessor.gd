extends InputProcessor

var cam
var stickMove: = Vector2()
var stickMovePersist: = Vector2()
var stickMovePersist2: = Vector2()
var stickMoveLocked: = false
var zoomLocked: = false
var zoomPersist: = 0.0
var zoomChange: = 0.0
var speed: = 100
var zoomSpeed: = 0.1

var fixedZoom: = 0.0
var fixedPosition: = Vector2()

func _ready():
	doTransitiveStop = false

func _process(delta):
	cam.position += stickMove * speed * delta
	cam.position += stickMovePersist2 * speed * delta
	cam.zoom += Vector2.ONE * zoomChange * delta * zoomSpeed
	if zoomLocked:
		cam.zoom += Vector2.ONE * zoomPersist * delta * zoomSpeed
	if stickMoveLocked:
		cam.position += stickMovePersist * speed * delta

func stick_move(event: InputEventJoypadMotion) -> bool:
	if event.axis == 0:
		var val = sign(event.axis_value) * pow(event.axis_value, 2)
		if abs(val) <= Options.gamepadStickDeadZone:
			stickMove.x = 0
		else:
			stickMove.x = (val - (sign(val) * Options.gamepadStickDeadZone))
	elif event.axis == 1:
		var val = sign(event.axis_value) * pow(event.axis_value, 2)
		if abs(val) <= Options.gamepadStickDeadZone:
			stickMove.y = 0
		else:
			stickMove.y = (val - (sign(val) * Options.gamepadStickDeadZone))








	elif event.axis == Options.AXIS_RT:
		zoomChange = - pow(event.axis_value, 2)
	elif event.axis == Options.AXIS_LT:
		zoomChange = pow(event.axis_value, 2)
	else:
		return false

	if stickMove.length() > 0:
		stickMovePersist2 *= 0

	return true

func buttonEvent(event) -> bool:
	if event is InputEventJoypadMotion:
		if event.axis == Options.AXIS_RT:
			zoomChange = - pow(event.axis_value * 4, 2)
		elif event.axis == Options.AXIS_LT:
			zoomChange = pow(event.axis_value * 4, 2)
		return true
	elif event is InputEventJoypadButton:
		if event.pressed:
			if event.button_index == 0:
				if stickMoveLocked:
					stickMoveLocked = false
				elif stickMove.length() == 0 and stickMovePersist.length() > 0 and not stickMoveLocked:
					stickMoveLocked = true
				elif stickMove.length() > 0:
					Audio.sound("alarm")
					stickMovePersist = stickMove
			elif event.button_index == 2:
				if zoomLocked:
					zoomLocked = false
				elif zoomChange == 0 and zoomPersist != 0 and not zoomLocked:
					zoomLocked = true
				elif zoomChange != 0:
					Audio.sound("alarm")
					zoomPersist = zoomChange
			elif event.button_index == 12:
				speed += 20
			elif event.button_index == 13:
				speed -= 20
			elif event.button_index == 14:
				zoomSpeed -= 0.02
			elif event.button_index == 15:
				zoomSpeed += 0.02
			elif event.button_index == 4:
				Audio.sound("alarm")
				fixedZoom = cam.zoom.x
				fixedPosition = cam.position
			elif event.button_index == 5 and fixedZoom > 0.0:
				cam.position = fixedPosition
				cam.zoom = Vector2.ONE * fixedZoom
		return true
	return false
