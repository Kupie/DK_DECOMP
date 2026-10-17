extends "res://gui/PopupInput.gd"

var scrollTarget: ScrollBar

var axisChange: = 0.0

func stick_move(event: InputEventJoypadMotion) -> bool:
	if InputMap.event_is_action(event, "ui_page_down"):
		if event.axis_value < 0.0:

			setAxis(event.axis_value)
		else:
			setAxis(abs(event.axis_value))
		return true
	if InputMap.event_is_action(event, "ui_page_up"):
		setAxis( - abs(event.axis_value))
		return true
	return blockStickMove

func setAxis(axis_value):
	if abs(axis_value) >= Options.gamepadStickDeadZone:
		axisChange = axis_value
	else:
		axisChange = 0

func _process(delta):
	scrollTarget.value += sign(axisChange) * pow(axisChange, 2) * 1000 * delta
