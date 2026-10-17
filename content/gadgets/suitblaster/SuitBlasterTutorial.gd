extends Tutorial

func _ready() -> void :
	super._ready()
	var key = keeper.playerId + ".suitblaster.charge"
	listen(key)

	splitTutorialText("level.tutorial.suitblaster.popup_1", "Label1", "Label2")

func propertyChanged(property: String, oldValue, newValue):
	if oldValue and newValue < oldValue:
		confirm()

func process_trigger(delta: float) -> bool:
	return keeper.position.y > 100.0
