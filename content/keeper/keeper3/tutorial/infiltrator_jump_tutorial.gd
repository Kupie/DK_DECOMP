extends Tutorial


var old_iron: int = 999

func _ready():
	super._ready()
	splitTutorialText("level.tutorial.ninja.rope.desc2", "LabelDesc1", "LabelDesc2")

func process_trigger(delta: float) -> bool:
	var current_iron = Data.of(keeper.teamId + ".inventory.iron")
	if keeper.position.y > 150 or abs(keeper.position.x) > 85 or current_iron > old_iron:
		return true
	old_iron = current_iron
	return false

func process_confirm(delta: float):
	if tutorialParent.jumpAscending:
		confirm()
