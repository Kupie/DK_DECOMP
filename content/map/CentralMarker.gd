extends Line2D

@export var teamId: String

func init(endY):
	visible = false

	if not Level.worldsByTeamId.has(teamId):
		return

	var dome_x: int = Level.worldsByTeamId[teamId].getDomePosition().x
	set_point_position(0, Vector2(dome_x, endY))
	set_point_position(1, Vector2(dome_x, 0))

	for keeper in Keepers.getAllOfTeam(teamId):
		if keeper.techId == "keeper2":
			Data.listen(self, keeper.playerId + ".keeper2.bundlecentralmarker", true)
	Keepers.keeper_registered.connect(on_keeper_registered)
	Data.listen(self, teamId + ".keeper2.bundlecentralmarker", true)

func propertyChanged(property: String, oldValue, newValue):
	if StageManager.isInLoadout():
		return
	if newValue:
		visible = true

func on_keeper_registered(keeper: Keeper) -> void :
	if keeper.teamId == teamId and keeper.techId == "keeper2":
		Data.listen(self, keeper.playerId + ".keeper2.bundlecentralmarker", true)
