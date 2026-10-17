extends Tutorial

func _ready():
	super._ready()
	splitTutorialText("level.tutorial.station.popup_2", "Label1", "Label2")
	splitTutorialText("level.tutorial.station.popup_4", "Label3", "Label4")

func process_confirm(delta: float):
	if keeper.isInsideStation:
		confirm()

func process_trigger(delta: float) -> bool:
	return Data.of("team1.monsters.wavepresent")

func beforeMoveIn():
	var dome = Level.domesByTeamId.get(keeper.teamId, "missing_dome_of_team_" + keeper.teamId)
	find_child("Station").texture = load("res://content/dome/" + dome.techId + "/station/single.png")
	find_child("Station").custom_minimum_size = find_child("Station").texture.get_size() * 2
