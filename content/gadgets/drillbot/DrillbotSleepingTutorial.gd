extends Tutorial

var wokeUpByHitting: = false

func _ready():
	super._ready()
	splitTutorialText("level.tutorial.drillbot.sleeping2", "Label1", "Label2")
	splitTutorialText("level.tutorial.drillbot.sleeping3", "Label3", "Label4")

func process_trigger(delta: float) -> bool:
	if tutorialParent.getRemainingSleepTime() >= 15 and keeper.global_position.distance_to(tutorialParent.global_position) < 72:
		return true
	return false

func process_confirm(delta: float):
	if confirmed:
		return

	if not tutorialParent.usedHit.is_connected(usedHit):
		tutorialParent.usedHit.connect(usedHit, CONNECT_ONE_SHOT)

	if wokeUpByHitting:
		confirm()

func usedHit(UID: int, playerId: String) -> void :
	if Keepers.local.hasPlayerId(playerId) and not tutorialParent.wokeUp.is_connected(wokeUp):
		tutorialParent.wokeUp.connect(wokeUp, CONNECT_ONE_SHOT)

func wokeUp(UID: int) -> void :
	wokeUpByHitting = true
