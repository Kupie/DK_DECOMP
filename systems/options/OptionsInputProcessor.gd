extends "res://gui/PopupInput.gd"

var stickReceiver

func stick_move(event: InputEventJoypadMotion) -> bool:
	stickReceiver.stick_move(event)
	return true

func handleStop():
	Audio.sound("gui_back")
	super.handleStop()

func buttonEvent(event) -> bool:
	if _successors.size():
		return false

	if justPressed(event, "ui_tab_left"):
		popup.tabLeft()
		return true
	elif justPressed(event, "ui_tab_right"):
		popup.tabRight()
		return true

	return super.buttonEvent(event)

func becameLeaf():
	super.becameLeaf()

func mouse_move(event: InputEventMouseMotion) -> bool:
	return true
