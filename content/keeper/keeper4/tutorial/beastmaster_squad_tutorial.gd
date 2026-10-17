extends Tutorial

var squad_triggered: bool = false
var time_near_hole: float = 0.0
var squad_unlocked: bool = false

func _ready():
	super._ready()
	splitTutorialText("level.tutorial.beastmaster.squad_1", "LabelDesc1", "LabelDesc2")
	if tutorialParent:
		tutorialParent.squad_triggered.connect(_on_squad_triggered)

	Data.listen(self, keeper.playerId + ".keeper4.squadcount", true)

func process_trigger(delta: float) -> bool:
	if not squad_unlocked:
		return false

	var tileCoord = Level.map.getTileCoord(tutorialParent.position)
	var pos = Level.map.getTilePos(tileCoord)
	var hole = tutorialParent.find_hole_in_range(pos)
	if hole and hole.hole_state == GoblinHole.HoleState.DUG_OUT:
		time_near_hole += delta

	return time_near_hole > 4

func process_confirm(delta: float):
	if squad_triggered:
		confirm()

func _on_squad_triggered(hole: Node2D):
	squad_triggered = true
	tutorialParent.squad_triggered.disconnect(_on_squad_triggered)

func propertyChanged(property: String, oldValue, newValue):
	if property == keeper.playerId + ".keeper4.squadcount":
		squad_unlocked = newValue > 0
