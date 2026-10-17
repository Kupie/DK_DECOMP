extends Container

signal request_change(actionName, buttonName)
signal request_unbind(buttonName)
signal button_focus_entered()

var inputEvents: = [null, null, null, null, null]
var controls: = [null, null, null, null, null]

@onready var _keyboard_button_1: Button
@onready var _keyboard_button_2: Button
@onready var _mouse_button: Button
@onready var _gamepad_button_1: Button
@onready var _gamepad_button_2: Button


var group: String
var action_name: String

func _notification(what: int) -> void :
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_keyboard_button_1 = $KeyboardButton1
		_keyboard_button_2 = $KeyboardButton2
		_mouse_button = $MouseButton
		_gamepad_button_1 = $GamepadButton1
		_gamepad_button_2 = $GamepadButton2


func init(action_name: String, title: String, group: String):
	self.group = group
	self.action_name = action_name
	var action_list = InputMap.action_get_events(action_name)
	var keyboardActions: = 0
	var gamepadActions: = 0
	find_child("ActionNameLabel").text = title
	for action in action_list:
		if action is InputEventKey:
			if keyboardActions <= 1:
				keyboardActions += 1
				var l = find_child("KeyboardButton" + str(keyboardActions))
				if action.physical_keycode != 0:
					l.text = OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(action.physical_keycode))
				else:
					l.text = OS.get_keycode_string(action.keycode)
				inputEvents[keyboardActions - 1] = Options.eventToKeyConfig(action)
		elif action is InputEventJoypadButton:
			if gamepadActions <= 1:
				gamepadActions += 1
				var l = find_child("GamepadButton" + str(gamepadActions))
				l.text = Options.getGamepadTranslations(action.button_index)
				inputEvents[2 + gamepadActions - 1] = Options.eventToKeyConfig(action)
		elif action is InputEventJoypadMotion:
			if gamepadActions <= 1:
				gamepadActions += 1
				var l = find_child("GamepadButton" + str(gamepadActions))
				l.text = Options.getGamepadTranslations("axis" + str(action.axis))
				inputEvents[2 + gamepadActions - 1] = Options.eventToKeyConfig(action)
		elif action is InputEventMouseButton:
			var l = find_child("MouseButton")
			l.text = Options.getMouseTranslations(action.button_index)
			inputEvents[4] = Options.eventToKeyConfig(action)

	if (action_name == "ui_left" or action_name == "ui_right" or action_name == "ui_up" or action_name == "ui_down"):
		var l = find_child("GamepadButton" + str(gamepadActions))
		l.disabled = true
		var d = find_child("DeleteGamepadButton" + str(gamepadActions))
		d.disabled = true

	if (action_name == "ui_select"):
		var d = find_child("DeleteGamepadButton" + str(gamepadActions))
		d.disabled = true


	for i in range(0, 2):
		var nodeName = "KeyboardButton" + str(i + 1)
		var l = find_child(nodeName)
		l.connect("pressed", request_change.emit.bind(action_name, nodeName))
		controls[i] = nodeName

		var deleteNodeName = "Delete" + nodeName
		var deleteButton = find_child(deleteNodeName)
		deleteButton.connect("pressed", request_unbind.emit.bind(nodeName))

	for i in range(0, 2):
		var nodeName = "GamepadButton" + str(i + 1)
		var l = find_child(nodeName)
		if not l.disabled:
			l.connect("pressed", request_change.emit.bind(action_name, nodeName))
			var deleteNodeName = "Delete" + nodeName
			var deleteButton = find_child(deleteNodeName)
			deleteButton.connect("pressed", request_unbind.emit.bind(nodeName))
		controls[2 + i] = nodeName

	var mb = find_child("MouseButton")
	var delete_mb = find_child("DeleteMouseButton")

	mb.connect("pressed", request_change.emit.bind(action_name, "MouseButton"))
	delete_mb.connect("pressed", request_unbind.emit.bind("MouseButton"))

	controls[4] = "MouseButton"
	if [
	"ui_up", 
	"ui_left", 
	"ui_down", 
	"ui_right", 
	].has(action_name):
		mb.disabled = true
		delete_mb.disabled = true

	if BuildCustomization.has_feature("disable_pc_options"):
		find_child("KeyboardButton1").visible = false
		find_child("KeyboardButton2").visible = false
		find_child("DeleteKeyboardButton1").visible = false
		find_child("DeleteKeyboardButton2").visible = false
		find_child("Control").visible = false
		find_child("Control2").visible = false
		find_child("Control3").visible = false
		find_child("MouseButton").visible = false
		find_child("DeleteMouseButton").visible = false

	_keyboard_button_1.focus_entered.connect(_on_button_focus_entered)
	_keyboard_button_2.focus_entered.connect(_on_button_focus_entered)
	_mouse_button.focus_entered.connect(_on_button_focus_entered)
	_gamepad_button_1.focus_entered.connect(_on_button_focus_entered)
	_gamepad_button_2.focus_entered.connect(_on_button_focus_entered)

func _on_button_focus_entered() -> void :
	button_focus_entered.emit()

func apply(buttonName, capturedEvent):
	var l = find_child(buttonName)

	var i = controls.find(buttonName)
	if capturedEvent is InputEventKey:
		l.text = OS.get_keycode_string(capturedEvent.keycode)
		inputEvents[i] = Options.eventToKeyConfig(capturedEvent)
	elif capturedEvent is InputEventJoypadButton:
		l.text = Options.getGamepadTranslations(capturedEvent.button_index, InputSystem.getDeviceIndex(capturedEvent))
		inputEvents[i] = Options.eventToKeyConfig(capturedEvent)
	elif capturedEvent is InputEventJoypadMotion:
		l.text = Options.getGamepadTranslations("axis" + str(capturedEvent.axis), InputSystem.getDeviceIndex(capturedEvent))
		inputEvents[i] = Options.eventToKeyConfig(capturedEvent)
	elif capturedEvent is InputEventMouseButton:
		l.text = Options.getMouseTranslations(capturedEvent.button_index)
		inputEvents[i] = Options.eventToKeyConfig(capturedEvent)

func unbind(buttonName):
	var l = find_child(buttonName)
	var i = controls.find(buttonName)
	l.text = ""
	inputEvents[i] = ""
