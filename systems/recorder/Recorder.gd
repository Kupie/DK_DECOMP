extends Node

const ids_to_ignore: = [
	"scarabarm", 
	"rock"
	]

var tileEvents: = []
var monsterEventsByTeamId: = {}

var initialMapData: MapData
var finalMapData: MapData

func startRecording():
	tileEvents.clear()
	monsterEventsByTeamId.clear()
	for teamId in Level.teams:
		monsterEventsByTeamId[teamId] = []

	if Level.map:
		var td = Level.map.getTileData()
		if td:
			initialMapData = td.duplicate()

func recordTileDestroyed(coord: Vector2):
	tileEvents.append(TileDestroyedEvent.new(GameWorld.runTime, coord))

func recordTileChangedType(coord: Vector2, typeId: int):
	tileEvents.append(TileDestroyedEvent.new(GameWorld.runTime, coord, typeId))

func recordMonsterKilled(id: String, teamId: String) -> bool:
	if ids_to_ignore.has(id):
		return false
	monsterEventsByTeamId[teamId].append(MonsterKillEvent.new(GameWorld.runTime, id))
	return true

func finishRecording():
	if Level.map:
		var td = Level.map.getTileData()
		if td:


			finalMapData = td.duplicate(DuplicateFlags.DUPLICATE_SCRIPTS)

func serialize() -> Dictionary:
	var out: = {}

	var tiles = []
	for x in tileEvents:
		tiles.append(x.serialize())

	out["tileEvents"] = tiles

	var monsters = {}
	for teamId in monsterEventsByTeamId.keys():
		monsters[teamId] = []
		for x in monsterEventsByTeamId[teamId]:
			monsters[teamId].append(x.serialize())
	out["monsterEvents"] = monsters

	var receivedDamageEntries = {}
	for teamId in Level.teams:
		receivedDamageEntries[teamId] = {}
		for key in GameWorld.trackedDamageReceivedByTeamId[teamId]:
			receivedDamageEntries[teamId][key] = GameWorld.trackedDamageReceivedByTeamId[teamId][key]
	out["trackedDamageReceivedByTeam"] = receivedDamageEntries

	var dealtDamageEntries = {}
	for teamId in Level.teams:
		dealtDamageEntries[teamId] = {}
		for key in GameWorld.trackedDamageDealtByTeamId[teamId]:
			dealtDamageEntries[teamId][key] = GameWorld.trackedDamageDealtByTeamId[teamId][key]
	out["trackedDamageDealtByTeam"] = dealtDamageEntries

	return out

func deserialize(data: Dictionary):
	tileEvents.clear()
	for x in data["tileEvents"]:
		tileEvents.append(TileDestroyedEvent.deserialize_new(x))

	monsterEventsByTeamId.clear()
	for team in Level.teams:
		monsterEventsByTeamId[team] = []

	var monsterEventsData = data["monsterEvents"]

	if monsterEventsData is Array:
		for x in monsterEventsData:
			monsterEventsByTeamId["team1"].append(MonsterKillEvent.deserialize_new(x))
	else:
		for teamId in monsterEventsData.keys():
			for x in monsterEventsData[teamId]:
				monsterEventsByTeamId[teamId].append(MonsterKillEvent.deserialize_new(x))

	var receivedDamageEntries = data.get("trackedDamageReceivedByTeam", {})
	for teamId in Level.teams:
		if teamId in receivedDamageEntries:
			GameWorld.trackedDamageReceivedByTeamId[teamId] = {}
			for key in receivedDamageEntries[teamId]:
				GameWorld.trackedDamageReceivedByTeamId[teamId][key] = receivedDamageEntries[teamId][key]

	var dealtDamageEntries = data.get("trackedDamageDealtByTeam", {})
	for teamId in Level.teams:
		if teamId in dealtDamageEntries:
			GameWorld.trackedDamageDealtByTeamId[teamId] = {}
			for key in dealtDamageEntries[teamId]:
				GameWorld.trackedDamageDealtByTeamId[teamId][key] = dealtDamageEntries[teamId][key]

func to_bytes() -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_u32(tileEvents.size())
	for event: TileDestroyedEvent in tileEvents:
		stream.append_array(event.to_bytes())

	stream.encode_u8(Level.teams.size())
	for teamId in Level.teams:
		stream.encode_u32(monsterEventsByTeamId[teamId].size())
		for event: MonsterKillEvent in monsterEventsByTeamId[teamId]:
			stream.append_array(event.to_bytes())

		stream.encode_u8(GameWorld.trackedDamageReceivedByTeamId[teamId].size())
		for key in GameWorld.trackedDamageReceivedByTeamId[teamId]:
			var value = GameWorld.trackedDamageReceivedByTeamId[teamId][key]
			stream.encode_var(key)
			stream.encode_float(value)

		stream.encode_u8(GameWorld.trackedDamageDealtByTeamId[teamId].size())
		for key in GameWorld.trackedDamageDealtByTeamId[teamId]:
			var value = GameWorld.trackedDamageDealtByTeamId[teamId][key]
			stream.encode_var(key)
			stream.encode_float(value)

	return stream.data

func from_bytes(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)

	tileEvents.clear()
	var remaining: = stream.decode_u32()
	while remaining > 0:
		tileEvents.append(TileDestroyedEvent.from_bytes(stream.slice(TileDestroyedEvent.BYTE_SIZE).data))
		remaining -= 1

	monsterEventsByTeamId.clear()
	GameWorld.trackedDamageReceivedByTeamId.clear()
	GameWorld.trackedDamageDealtByTeamId.clear()
	var teamCount: = stream.decode_u8()
	for i in range(teamCount):
		var teamId: = Utils.decode_team_id(i + 1)
		remaining = stream.decode_u32()
		monsterEventsByTeamId[teamId] = []
		while remaining > 0:
			monsterEventsByTeamId[teamId].append(MonsterKillEvent.from_bytes(stream.slice(MonsterKillEvent.BYTE_SIZE).data))
			remaining -= 1

		GameWorld.trackedDamageReceivedByTeamId[teamId] = {}
		var damageReceivedCount: = stream.decode_u8()
		for _i in range(damageReceivedCount):
			var key: String = stream.decode_var()
			var value: = stream.decode_float()
			GameWorld.trackedDamageReceivedByTeamId[teamId][key] = value

		GameWorld.trackedDamageDealtByTeamId[teamId] = {}
		var damageDealtCount: = stream.decode_u8()
		for _i in range(damageDealtCount):
			var key: String = stream.decode_var()
			var value: = stream.decode_float()
			GameWorld.trackedDamageDealtByTeamId[teamId][key] = value
