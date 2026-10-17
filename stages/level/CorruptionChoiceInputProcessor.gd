extends InputProcessor

signal corruptionSelected(selectedCorruptionId: String, teamId: String, playerId: String)

var teamId: String
var playerId: String
var popup
var _lastOptionFocussed: Control = null

func _ready():
	name = "CorruptionChoiceInputProcessor"
	popup.connect("selected_by_mouse", wasSelected)

func handleStart():
	popup.moveIn()

func handleStop():
	popup.moveOut()

func becameLeaf():
	super.becameLeaf()
	if _lastOptionFocussed:
		_lastOptionFocussed.grab_focus()
		_lastOptionFocussed = null

func notLeaf():
	_lastOptionFocussed = popup.get_viewport().gui_get_focus_owner()

func wasSelected():
	if popup.selectedCorruptionId == "":
		return

	corruptionSelected.emit(popup.selectedCorruptionId, teamId, playerId)

	Audio.sound("gadgetinsert")
	desintegrate()

func buttonEvent(event) -> bool:
	if justPressed(event, "ui_select") and popup.animationDone:
		wasSelected()
	elif justPressed(event, "escape"):
		return true
	elif justPressed(event, "cheats"):

		return false

	return true
