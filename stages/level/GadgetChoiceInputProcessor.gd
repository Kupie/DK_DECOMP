extends InputProcessor

signal gadgetSelected(id: String, playerId: String, teamId: String)
signal dropsSelected(drop_type: String, amount: int, playerId: String, teamId: String)

var teamId: String
var playerId: String

var popup
var primaryDeviceId

func _ready():
	name = "GadgetChoiceInputProcessor"
	popup.connect("selected_by_mouse", wasSelected)

func handleStart():
	popup.moveIn()

func handleStop():
	popup.moveOut()

func becameLeaf():
	popup.moveIn()
	super.becameLeaf()

func notLeaf():
	popup.moveOut()

func wasSelected():
	if not popup.selectedGadget:
		return

	if popup.selectedGadget.has("reroll"):

		pass
	elif popup.selectedGadget.has("amount"):
		emit_signal("dropsSelected", popup.selectedGadget.get("dropType", CONST.IRON), popup.selectedGadget.get("amount", 0), playerId, teamId)
		Audio.sound("cobaltscavenge")
		desintegrate()
	else:
		emit_signal("gadgetSelected", popup.selectedGadget["id"], popup.droptype, playerId, teamId)

func gadgetAcceptedByServer() -> void :
	Audio.sound("gadgetinsert")
	desintegrate()

func buttonEvent(event) -> bool:
	if deviceId == -1 && Keepers.isLocalMultiplayer():

		primaryDeviceId = InputSystem.getDeviceIndex(event)

	if justPressed(event, "ui_select") and popup.animationDone:
		wasSelected()
	elif justPressed(event, "escape"):
		return true
	elif justPressed(event, "cheats"):

		return false

	return true
