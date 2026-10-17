extends Tutorial

func _ready():
	super._ready()
	splitTutorialText("level.tutorial.ninja.gadgetpickup.desc2", "LabelDesc1", "LabelDesc2")

func process_trigger(delta: float) -> bool:
	if tutorialParent.carryables.any( func(carryable): return carryable.carryableType != "resource"):
		return true
	return false

func process_confirm(delta: float):
	if tutorialParent.carriedCarryables.any( func(carryable): return carryable.carryableType != "resource"):
		confirm()
