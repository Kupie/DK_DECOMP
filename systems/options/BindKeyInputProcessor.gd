extends InputProcessor

const JOY_DETECTION_THRESHOLD = 0.4

signal captured

var inputLabel
var buttonName: String
var bindingEntry

var capturedEvent: InputEvent

func handleStart():
	inputLabel.text = tr("options.keybindings.rebinding.inputprocessor")

func handle(event) -> bool:
	if capturedEvent:
		return _isNoScrollCapture(event)

	if not capturedEvent:
		handleStart()

	if event is InputEventKey and event.pressed:
		inputLabel.text = OS.get_keycode_string(event.keycode)
		capturedEvent = event
		captured.emit()
	elif event is InputEventJoypadMotion and abs(event.axis_value) > JOY_DETECTION_THRESHOLD:
		inputLabel.text = Options.getGamepadTranslations("axis" + str(event.axis), InputSystem.getDeviceIndex(event))
		capturedEvent = event
		captured.emit()
	elif event is InputEventJoypadButton and event.pressed:
		inputLabel.text = Options.getGamepadTranslations(event.button_index, InputSystem.getDeviceIndex(event))
		capturedEvent = event
		captured.emit()
	elif event is InputEventMouseButton:
		var mouseTranslation: String = Options.getMouseTranslations(event.button_index)
		if not mouseTranslation.is_empty():
			inputLabel.text = mouseTranslation
			capturedEvent = event
			captured.emit()
	return true

func _isNoScrollCapture(inEvent: InputEvent) -> bool:
	var eatScrollEvent: bool = false
	if inEvent is InputEventJoypadMotion:
		var isRightJoy: bool = JOY_AXIS_RIGHT_Y or inEvent.axis == JOY_AXIS_RIGHT_X
		eatScrollEvent = isRightJoy
	return eatScrollEvent

func apply():
	if not capturedEvent or not bindingEntry:
		return

	bindingEntry.apply(buttonName, capturedEvent)

func startCapture():
	capturedEvent = null
