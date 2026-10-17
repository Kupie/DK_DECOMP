extends "res://gui/PopupInput.gd"


func buttonEvent(event) -> bool:
	if (justPressed(event, "ui_cancel") or justPressed(event, "escape")):
		if popup.shouldRestart:
			return false
		else:
			close()
			return true
	return super.buttonEvent(event)
