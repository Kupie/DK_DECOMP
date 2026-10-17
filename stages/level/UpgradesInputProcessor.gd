extends InputProcessor

signal buyUpgrade
signal toggleMode

var popup
var lastPanel

func handleStart():
	popup.moveIn()
	if not Options.useGamepad(deviceId):
		GameWorld.setShowMouse(true)

	Level.stage.pause()

	Audio.sound("open_upgrades")

func handleStop():
	popup.moveOut()
	if not Options.useGamepad(deviceId):
		GameWorld.setShowMouse(false)

	Level.stage.unpause()

	Audio.sound("close_upgrades")

func becameLeaf():
	if lastPanel:
		popup.setFocussedTechPanel(lastPanel)
		lastPanel = null

	popup.focus()

func notLeaf():
	lastPanel = popup.getFocussedTechPanel()

func buttonEvent(event) -> bool:
	if justPressed(event, "ui_cancel"):
		Audio.sound("gui_cancel")
		desintegrate()

	elif justPressed(event, "ui_select") && not (event is InputEventMouseButton):
		emit_signal("buyUpgrade")
	elif justPressed(event, "cheats"):

		return false
	elif justPressed(event, "escape"):
		return false

	return true
