extends Tutorial

func _ready():
	super._ready()
	splitTutorialText("level.tutorial.repellent.popup_2", "Label1", "Label2")

func process_trigger(delta: float) -> bool:
	if Data.of("team1.repellent.currentgrowth") >= 1.0:
		if keeper.isInsideDome and not keeper.isInsideStation:
			return true
		return false
	else:
		return false

func process_confirm(delta: float):
	if Data.of("team1.monsters.wavedelay") > 0.0:
		confirm()
