extends RefCounted

class_name LoadoutKeeper

var teamId: String
var playerId: String
var playerName: String
var keeperId: String
var skinId: String
var colorId: String
var remapColorIdPerPalette: bool
var deviceId: int
var tutorialsActive: bool
var peerId: int
var platformId: String
var platformName: String
var playfabId: String


var keeper
var position: Vector2
var temporaryBuffs: Array[TemporaryBuff] = []

func serialize() -> Dictionary:
	var data = {
		"teamId": teamId, 
		"keeperId": keeperId, 
		"playerId": playerId, 
		"playerName": playerName, 
		"skinId": skinId, 
		"colorId": colorId, 
		"remapColorIdPerPalette": remapColorIdPerPalette, 
		"deviceId": deviceId, 
		"tutorialsActive": tutorialsActive, 
		"position": var_to_str(position), 
		"platformId": platformId, 
		"platformName": platformName
	}
	var serializedBuffs: = []
	if is_instance_valid(keeper):
		for buff in keeper.temporaryBuffs:
			serializedBuffs.append([buff.property, buff.amount, buff.remainingDuration, buff.origin])
	else:
		for buff in temporaryBuffs:
			serializedBuffs.append([buff.property, buff.amount, buff.remainingDuration, buff.origin])
	data["temporaryBuffs"] = var_to_str(serializedBuffs)
	return data

func deserialize(d: Dictionary) -> void :
	teamId = d.get("teamId", "team1")
	keeperId = d.get("keeperId", "keeper1")
	skinId = d.get("skinId", "skin0")
	colorId = d.get("colorId", "color0")
	remapColorIdPerPalette = d.get("remapColorIdPerPalette", false)
	playerId = d.get("playerId", "player1")
	playerName = d.get("playerName", playerId)
	tutorialsActive = d.get("tutorialsActive", true)
	deviceId = d.get("deviceId", -1)
	platformId = d.get("platformId", "")
	platformName = d.get("platformName", "")
	if d.has("position"):
		position = BackwardCompatibilityUtils.str_to_var(d.get("position"))
	else:
		position = Vector2.ZERO

	if d.has("temporaryBuffs"):
		for b in str_to_var(d.get("temporaryBuffs")):
			var buff = TemporaryBuff.new()
			buff.property = str(b[0])
			buff.amount = float(b[1])
			buff.remainingDuration = float(b[2])
			buff.origin = str(b[3])
			temporaryBuffs.append(buff)

func duplicate() -> LoadoutKeeper:
	var lk = LoadoutKeeper.new()

	lk.teamId = teamId
	lk.keeperId = keeperId
	lk.deviceId = deviceId
	lk.skinId = skinId
	lk.colorId = colorId
	lk.remapColorIdPerPalette = remapColorIdPerPalette
	lk.playerId = playerId
	lk.playerName = playerName
	lk.tutorialsActive = tutorialsActive
	lk.position = position
	lk.platformId = platformId
	lk.platformName = platformName
	lk.playfabId = playfabId

	for tb in temporaryBuffs:
		lk.temporaryBuffs.append(tb.duplicate())

	return lk

func to_bytes() -> PackedByteArray:
	var stream: = PackedByteStream.new()

	stream.encode_u8(int(teamId.lstrip("team")))
	stream.encode_u8(int(playerId.lstrip("player")))
	stream.encode_u8(int(keeperId.lstrip("keeper")))
	stream.encode_u8(int(skinId.lstrip("skin")))
	stream.encode_u8(int(colorId.lstrip("color")))
	stream.encode_u8(int(remapColorIdPerPalette))
	stream.encode_s8(deviceId)
	stream.encode_u8(int(tutorialsActive))
	stream.encode_u64(peerId)
	stream.encode_vector2(position)

	stream.encode_var(playerName)
	stream.encode_var(platformId)
	stream.encode_var(platformName)
	stream.encode_var(playfabId)

	stream.encode_u8(temporaryBuffs.size())
	for tb in temporaryBuffs:
		stream.encode_float(tb.remainingDuration)
		stream.encode_var(tb.property)
		stream.encode_float(tb.amount)
		stream.encode_var(tb.origin)

	return stream.data

static func from_bytes(data: PackedByteArray) -> LoadoutKeeper:
	var lk = LoadoutKeeper.new()
	var stream: = PackedByteStream.from_bytes(data)

	lk.teamId = "team%d" % stream.decode_u8()
	lk.playerId = "player%d" % stream.decode_u8()
	lk.keeperId = "keeper%d" % stream.decode_u8()
	lk.skinId = "skin%d" % stream.decode_u8()
	lk.colorId = "color%d" % stream.decode_u8()
	lk.remapColorIdPerPalette = stream.decode_bool()
	lk.deviceId = stream.decode_s8()
	lk.tutorialsActive = stream.decode_bool()
	lk.peerId = stream.decode_u64()
	lk.position = stream.decode_vector2()

	lk.playerName = stream.decode_var()
	lk.platformId = stream.decode_var()
	lk.platformName = stream.decode_var()
	lk.playfabId = stream.decode_var()

	var temporaryBuffCount: = stream.decode_u8()
	for _i in range(temporaryBuffCount):
		var temporaryBuff: = TemporaryBuff.new()
		temporaryBuff.remainingDuration = stream.decode_float()
		temporaryBuff.property = stream.decode_var()
		temporaryBuff.amount = stream.decode_float()
		temporaryBuff.origin = stream.decode_var()
		lk.temporaryBuffs.append(temporaryBuff)

	return lk
