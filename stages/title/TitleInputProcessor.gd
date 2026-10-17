extends InputProcessor

signal close_panel

func buttonEvent(event) -> bool:
	if justPressed(event, "ui_cancel") or justPressed(event, "escape"):
		close_panel.emit()
		return true
	return false
