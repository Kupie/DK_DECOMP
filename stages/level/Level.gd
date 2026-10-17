extends Node

var levelSeed: = -1

var loadout: Loadout = Loadout.empty()

var map:
	set = setMap
var drops: Drops
var teams: Array[String]
var monstersByTeamId: Dictionary
var worldsByTeamId: Dictionary
var domesByTeamId: Dictionary
var mode
var stage
var viewports
var fullscreenTutorials: = []

var initialized: = false

func _enter_tree():
	setSeed(levelSeed)

func clear():
	domesByTeamId.clear()
	monstersByTeamId.clear()
	worldsByTeamId.clear()
	mode = null
	map = null
	drops = null
	stage = null
	viewports = null
	initialized = false
	fullscreenTutorials.clear()

func addTutorial(parent: Node, id: String, teamOrPlayerId: String):
	if not StageManager.has_node("LevelStage"):
		if not StageManager.isInLoadout():
			push_warning("%s tutorial did not get added because the level stage does not exist." % id)
		return
	var levelStage: LevelStage = StageManager.get_node("LevelStage").get_child(0)


	if not levelStage.is_level_built:
		await levelStage.level_built
		if not Network.is_server():
			await Data.full_sync_received

	if teamOrPlayerId == "":
		push_error("%s tutorial did not have an accompanying team or player id, not adding tutorial." % id)
		return

	var playerId: = ""
	var teamId: = ""

	if teamOrPlayerId.begins_with("player"):
		playerId = teamOrPlayerId
		teamId = Keepers.getKeeper(playerId).teamId
		if not Keepers.local.hasPlayerId(playerId):
			return
	else:
		teamId = teamOrPlayerId
		var localTeams = Utils.get_local_teams(multiplayer.get_unique_id())
		if not localTeams.has(teamId):
			return

	for manager in get_tree().get_nodes_in_group("tutorial-manager"):
		if manager.keeper.teamId != teamId or (playerId != "" and manager.keeper.playerId != playerId):
			continue
		manager.addIfOpen(parent, id)

func difficulty(teamId: String = "map") -> int:
	if loadout:
		return loadout.difficultyByTeamId.get(teamId, 0)
	else:
		return 0

func randomizeSeed():
	randomize()
	levelSeed = randi()

func setSeed(seedID: int):
	levelSeed = seedID
	if levelSeed == -1:
		randomize()
		levelSeed = randi()

func setMap(_map):
	map = _map
	if is_instance_valid(_map):
		drops = _map.drop_system
	else:
		drops = null

func moveHudOut():
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.moveOut()

func immediateMoveOut():
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.immediateMoveOut()

func moveHudIn():
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.moveIn()

func addHudElement(packedScene: PackedScene, teamOrPlayerId: String):
	for hud in get_tree().get_nodes_in_group("hud"):
		if teamOrPlayerId == "" or teamOrPlayerId == hud.playerId or teamOrPlayerId == hud.teamId:
			hud.addHudElement(packedScene.instantiate())

func activateTutorials():
	for tutorialManager in get_tree().get_nodes_in_group("tutorial-manager"):
		tutorialManager.activate()

func deactivateTutorials():
	for tutorialManager in get_tree().get_nodes_in_group("tutorial-manager"):
		tutorialManager.deactivate()

func isMultiplayer() -> bool:
	return Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER

func getDome(teamId: String) -> Dome:
	if domesByTeamId.size() == 0 or not domesByTeamId.has(teamId):
		return null

	return domesByTeamId[teamId]

func getDomes() -> Array:
	return domesByTeamId.values()
