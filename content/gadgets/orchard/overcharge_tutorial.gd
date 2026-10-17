extends Tutorial

var type: String
var techId: String
var teamId: String

func _ready():
	super._ready()
	splitTutorialText("level.tutorial.overcharge.popup_2", "Label1", "Label2")
	splitTutorialText("level.tutorial.overcharge.popup_3", "Label3", "Label4")

	self.teamId = keeper.teamId

	if GameWorld.upgrades.has(teamId + ".orchard"):
		type = "orchard"
		techId = "orchardovercharge"
	elif GameWorld.upgrades.has(teamId + ".repellent"):
		type = "repellent"
		techId = "repellentovercharge"
	elif GameWorld.upgrades.has(teamId + ".droneyard"):
		type = "droneyard"
		techId = "droneyardovercharge1"
	elif GameWorld.upgrades.has(teamId + ".shield"):
		type = "shield"
		techId = "shieldovercharge"
	else:
		Logger.error("Can't add overcharge tutorial without having a primary gadget present.", "OverchargeTutorial._ready")
		type = "unknown"

	Data.listen(self, teamId + "." + type + ".overcharged")

func propertyChanged(property: String, oldValue, newValue):
	if newValue:
		confirm()
		Data.unlisten(self, teamId + "." + type + ".overcharged")

func process_trigger(delta: float) -> bool:
	if GameWorld.boughtUpgrades.has(teamId + "." + techId):
		if keeper.isInsideDome and not keeper.isInsideStation:
			return true
	return false
