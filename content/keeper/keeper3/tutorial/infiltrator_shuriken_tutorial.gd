extends Tutorial

var shuriken_unlocked: bool = false

func _ready():
	super._ready()
	splitTutorialText("level.tutorial.ninja.shuriken.desc1", "LabelDesc1", "LabelDesc2")
	Data.listen(self, keeper.playerId + ".keeper3.hasshuriken", true)

func process_trigger(delta: float) -> bool:
	return shuriken_unlocked and not keeper.isInsideDome and tutorialParent.cooldownManager.is_ready("kunai_special")

func process_confirm(delta: float):
	if shuriken_unlocked and not tutorialParent._specialKunaiIsReady:
		confirm()

func propertyChanged(property: String, oldValue, newValue):
	if property == keeper.playerId + ".keeper3.hasshuriken":
		shuriken_unlocked = newValue
