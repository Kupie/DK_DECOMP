class_name DeviceSelectionInputProcessor
extends InputProcessor

signal new_device_detected
signal moved
signal change_focus
signal confirm
signal abort

var first_known_device: int = -1
var known_devices: = {}

func handle(event) -> bool:
	var id = InputSystem.getDeviceIndex(event)
	if not known_devices.has(id):
		known_devices[id] = id
		new_device_detected.emit(id)
		if first_known_device == -1:
			first_known_device = id
	return super.handle(event)

func buttonEvent(event) -> bool:
	if pressed(event, "ui_left"):
		moved.emit(InputSystem.getDeviceIndex(event), -1)
	elif pressed(event, "ui_right"):
		moved.emit(InputSystem.getDeviceIndex(event), 1)
	elif InputSystem.getDeviceIndex(event) == first_known_device and pressed(event, "ui_up"):
		change_focus.emit(true)
	elif InputSystem.getDeviceIndex(event) == first_known_device and pressed(event, "ui_down"):
		change_focus.emit(false)
	elif justPressed(event, "ui_cancel") or justPressed(event, "escape"):
		abort.emit(InputSystem.getDeviceIndex(event))
	elif justPressed(event, "ui_select"):
		confirm.emit(InputSystem.getDeviceIndex(event))

	return true

func stick_move(event: InputEventJoypadMotion) -> bool:
	if event.is_action("ui_right") and Input.is_action_just_pressed("ui_right"):
		moved.emit(InputSystem.getDeviceIndex(event), 1)
	elif event.is_action("ui_left") and Input.is_action_just_pressed("ui_left"):
		moved.emit(InputSystem.getDeviceIndex(event), -1)
	elif InputSystem.getDeviceIndex(event) == first_known_device:
		if event.is_action("ui_up") and Input.is_action_just_pressed("ui_up"):
			change_focus.emit(true)
		elif event.is_action("ui_down") and Input.is_action_just_pressed("ui_down"):
			change_focus.emit(false)
	return true
