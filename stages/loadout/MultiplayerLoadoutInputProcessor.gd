class_name MultiplayerLoadoutInputProcessor
extends InputProcessor

signal new_device_detected
signal joystick_disconnected(deviceId: int)

var deviceIndices: = []
var devices: = {}

func _init():
	stopWithPredecessor = false
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_joy_connection_changed(device_id: int, connected: bool):
	if not connected:
		device_id += 1
		unregisterDevice(device_id)
		joystick_disconnected.emit(device_id)

func buttonEvent(event) -> bool:
	if event is InputEventJoypadButton:
		if not event.is_pressed():
			return false

	if event is InputEventJoypadMotion:
		if abs(event.axis_value) <= Options.gamepadStickDeadZone:
			return false

	var index = InputSystem.getDeviceIndex(event)

	if not released(event, "ui_select") and not deviceIndices.has(index):
		if Platform.runningOnHandheldDevice():
			if event is InputEventMouseButton:
				return false
			if event is InputEventKey:
				if event.keycode == Key.KEY_ESCAPE:
					return false

		deviceIndices.append(index)
		emit_signal("new_device_detected", index)

	var device = devices.get(index, null)
	if not device:
		return false

	return true

func stick_move(event: InputEventJoypadMotion) -> bool:
	return buttonEvent(event)

func registerDevice(d, id):
	if devices.has(id):
		return

	devices[id] = d

	var i = preload("res://content/keeper/KeeperInputProcessor.gd").new()
	i.moveableDevice = d
	i.deviceId = id
	i.integrate(Level.stage)

func unregisterDevice(id: int) -> void :
	devices.erase(id)
	deviceIndices.erase(id)
