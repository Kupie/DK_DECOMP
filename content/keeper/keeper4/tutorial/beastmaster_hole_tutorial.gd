extends Tutorial

func _ready():
	super._ready()
	splitTutorialText("level.tutorial.beastmaster.hole_1", "LabelDesc1", "LabelDesc2")

func process_trigger(delta: float) -> bool:
	return tutorialParent.carryables.any( func(carryable): return carryable.carryableType == "resource")

func process_confirm(delta: float):
	for hole: GoblinHole in get_tree().get_nodes_in_group(keeper.teamId + "-goblin_holes"):
		if hole._dig_animation_pending:
			confirm()
