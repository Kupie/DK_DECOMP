extends Node

signal keeper_registered(keeper: Keeper)
signal keeper_unregistered(keeper: Keeper)

signal local_keeper_registered(keeper: Keeper)
signal local_keeper_unregistered(keeper: Keeper)
signal local_keeper_replaced(keeper: Keeper)

signal keepers_changed
signal split_screen_changed(is_split: bool)

signal initial_keepers_spawned
var has_initial_keepers_spawned: = false

class KeeperQuery:
	var keepers: Array[Keeper]

	func oneInsideDome() -> bool:
		for keeper in keepers:
			if keeper.isInsideDome:
				return true
		return false

	func allInsideDome() -> bool:
		for keeper in keepers:
			if not keeper.isInsideDome:
				return false
		return true

	func oneInsideMine() -> bool:
		for keeper in keepers:
			if not keeper.isInsideDome:
				return true
		return false

	func allInsideMine() -> bool:
		for keeper in keepers:
			if keeper.isInsideDome:
				return false
		return true

	func oneInsideStation() -> bool:
		for keeper in keepers:
			if keeper.isInsideStation:
				return true
		return false

	func allInsideStation() -> bool:
		for keeper in keepers:
			if not keeper.isInsideStation:
				return false
		return true

	func getAll() -> Array[Keeper]:
		return keepers

	func getCount() -> int:
		return keepers.size()

	func first() -> Keeper:
		return keepers.front()

	func has(keeper: Keeper) -> bool:
		return keepers.has(keeper)

	func hasPlayerId(playerId: String) -> bool:
		return keepers.has(Keepers.getKeeper(playerId))

	func getAllFromTeam(team: String) -> Array[Keeper]:
		var teamKeepers: Array[Keeper] = []
		for keeper: Keeper in keepers:
			if keeper.teamId == team:
				teamKeepers.append(keeper)
		return teamKeepers

	func getRelatedTeams() -> PackedStringArray:
		var relatedTeams: Dictionary = {}
		for keeper: Keeper in keepers:
			relatedTeams[keeper.teamId] = true
		return PackedStringArray(relatedTeams.keys())

	func getClosest(to: Vector2) -> Keeper:
		var closestKeeper = null
		for keeper in getAll():
			if not closestKeeper or (keeper.position - to).length() < (closestKeeper.position - to).length():
				closestKeeper = keeper
		return closestKeeper

var none: KeeperQuery = KeeperQuery.new()
var all: KeeperQuery = KeeperQuery.new()
var local: KeeperQuery = KeeperQuery.new()
var isSplitScreen: bool = true:
	set(value):
		if value == isSplitScreen:
			return
		isSplitScreen = value
		split_screen_changed.emit(isSplitScreen)


var _peers: Dictionary = {}
var _teams: Dictionary = {}
var _keeperByPlayerId: Dictionary = {}

func _ready() -> void :
	initial_keepers_spawned.connect( func(): has_initial_keepers_spawned = true)

func updateTeams():
	for team in _teams.values():
		team.keepers.clear()

	for keeper in all.keepers:
		var team: KeeperQuery = get_team(keeper.teamId)
		team.keepers.append(keeper)

func get_peer(peerId: int) -> KeeperQuery:
	if not _peers.has(peerId):
		_peers[peerId] = KeeperQuery.new()
	return _peers[peerId]

func get_team(teamId: String) -> KeeperQuery:
	if not _teams.has(teamId):
		_teams[teamId] = KeeperQuery.new()
	return _teams[teamId]


func first() -> Keeper:

	return local.keepers[0]

func registerKeeper(keeper: Keeper) -> void :

	if keeper.deviceId == 0 and all.keepers.size() > 0:
		all.keepers.insert(0, keeper)
		if keeper.peerId == multiplayer.get_unique_id():
			local.keepers.insert(0, keeper)
			local_keeper_registered.emit(keeper)
		get_peer(keeper.peerId).keepers.insert(0, keeper)
		get_team(keeper.teamId).keepers.insert(0, keeper)
		_keeperByPlayerId[keeper.playerId] = keeper
	else:
		all.keepers.append(keeper)
		if keeper.peerId == multiplayer.get_unique_id():
			local.keepers.append(keeper)
			local_keeper_registered.emit(keeper)
		get_peer(keeper.peerId).keepers.append(keeper)
		get_team(keeper.teamId).keepers.append(keeper)
		_keeperByPlayerId[keeper.playerId] = keeper

	keeper_registered.emit(keeper)
	keepers_changed.emit()

	for l in get_tree().get_nodes_in_group("keepers-changed-listener"):
		l.keepers_changed()

func unregisterKeeper(keeper: Keeper) -> void :


	all.keepers.erase(keeper)
	if local.keepers.has(keeper):
		local.keepers.erase(keeper)
		local_keeper_unregistered.emit(keeper)
	get_peer(keeper.peerId).keepers.erase(keeper)
	get_team(keeper.teamId).keepers.erase(keeper)
	_keeperByPlayerId.erase(keeper.playerId)

	keeper_unregistered.emit(keeper)
	keepers_changed.emit()

	for l in get_tree().get_nodes_in_group("keepers-changed-listener"):
		l.keepers_changed()

func replaceKeeper(newKeeper: Keeper, oldKeeper: Keeper) -> void :
	_replaceInQuery(newKeeper, oldKeeper, all)
	_replaceInQuery(newKeeper, oldKeeper, local)
	_replaceInQuery(newKeeper, oldKeeper, get_peer(newKeeper.peerId))
	_replaceInQuery(newKeeper, oldKeeper, get_team(newKeeper.teamId))
	_keeperByPlayerId[newKeeper.playerId] = newKeeper

	if multiplayer.get_unique_id() == newKeeper.peerId:
		local_keeper_replaced.emit(newKeeper)

func _replaceInQuery(newKeeper: Keeper, oldKeeper: Keeper, query: KeeperQuery) -> void :
	var idx: = query.keepers.find(oldKeeper)
	if idx == -1:
		return
	query.keepers[idx] = newKeeper

func unregisterRemoteKeepers(peerId: int) -> void :

	var remoteKeepers: = get_peer(peerId).getAll()
	var i: int = remoteKeepers.size()
	while i > 0:
		i -= 1
		unregisterKeeper(remoteKeepers[i])

func clear() -> void :

	all = KeeperQuery.new()
	local = KeeperQuery.new()
	_peers = {}
	_teams = {}
	_keeperByPlayerId = {}

func oneInsideDome(teamId: = "") -> bool:
	if teamId == "":
		return all.oneInsideDome()
	else:
		return _teams[teamId].oneInsideDome()

func allInsideDome(teamId: = "") -> bool:
	if teamId == "":
		return all.allInsideDome()
	else:
		return _teams[teamId].allInsideDome()

func oneInsideMine(teamId: = "") -> bool:
	if teamId == "":
		return all.oneInsideMine()
	else:
		return _teams[teamId].oneInsideMine()

func allInsideMine(teamId: = "") -> bool:
	if teamId == "":
		return all.allInsideMine()
	else:
		return _teams[teamId].allInsideMine()

func oneInsideStation(teamId: = "") -> bool:
	if teamId == "":
		return all.oneInsideStation()
	else:
		return _teams[teamId].oneInsideStation()

func allInsideStation(teamId: = "") -> bool:
	if _teams.size() == 0:
		return false
	if teamId == "":
		return all.allInsideStation()
	else:
		return _teams[teamId].allInsideStation()

func getAll() -> Array[Keeper]:
	return all.getAll()

func getAllOfTeam(teamId: String) -> Array[Keeper]:
	return _teams.get(teamId, none).getAll()

func hasTeam(teamId: String) -> bool:
	return _teams.has(teamId)

func getClosestKeeper(to: Vector2, teamId: String = "") -> Keeper:
	if teamId != "":
		return get_team(teamId).getClosest(to)
	return all.getClosest(to)

func hasKeeper(playerId: String) -> bool:
	return _keeperByPlayerId.has(playerId)

func getKeeper(playerId: String) -> Keeper:
	return _keeperByPlayerId[playerId]

func isMultiplayer() -> bool:
	return all.getCount() > 1

func isLocalMultiplayer() -> bool:
	return local.getCount() > 1

func getLocalKeeperByDeviceId(deviceId: int) -> Keeper:
	for keeper in local.getAll():
		if keeper.deviceId == deviceId:
			return keeper
	return null

func getLocalMouseUser() -> Keeper:
	for keeper in local.getAll():
		if keeper.deviceId < 1:
			return keeper
	return null


func serialize() -> Dictionary:
	var data = {}
	for keeper in all.getAll():
		data[keeper.playerId] = keeper.serialize()
	return data

func deserialize(data: Dictionary):
	for playerId in data:
		if _keeperByPlayerId.has(playerId):
			var keeper = getKeeper(playerId)
			keeper.deserialize(data)
