extends Tutorial

func _ready():
	super._ready()
	splitTutorialText("level.tutorial.drillingrig.popup2", "Label1", "Label2")

func process_trigger(delta: float) -> bool:
	for d in get_tree().get_nodes_in_group("team1-minedriller_sidedriller"):
		if d.global_position.distance_to(keeper.global_position) < 60:
			return true
	return false

func process_confirm(delta: float):
	for d in get_tree().get_nodes_in_group("team1-minedriller_sidedriller"):
		if abs(d.goalPos - d.global_position.y) >= 2.0:
			confirm()
			return
