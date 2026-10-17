extends RefCounted

class_name Loadout




var domes: Array
var keepers: Array
var modeId: String
var modeConfig: Dictionary
var keeperTemplates: Array

var worldId: String
var palette: String

var globalAreaOverrides: Dictionary

var difficultyByTeamId: Dictionary

static func default():
	var l = load("res://stages/loadout/data/Loadout.gd").new()
	l.domes = [createDefaultDome()]
	l.keepers = []
	l.modeId = "relichunt"
	l.modeConfig = {}

	l.keeperTemplates = [createDefaultKeeper()]

	return l

static func empty():
	var l = load("res://stages/loadout/data/Loadout.gd").new()
	l.domes = [createDefaultDome()]
	l.keepers = []
	l.modeConfig = {}

	var lk = createDefaultKeeper()
	l.keeperTemplates = [lk]
	return l

static func createDefaultKeeper() -> LoadoutKeeper:
	var lk = LoadoutKeeper.new()
	lk.deserialize({})
	return lk

static func createDefaultDome() -> LoadoutDome:
	var ld = LoadoutDome.new()
	ld.deserialize({})
	return ld

func addDome(newDome: LoadoutDome) -> void :
	if domes.find(newDome) == -1:
		domes.append(newDome)


func getLoadoutKeepers() -> Array:
	return keeperTemplates.duplicate()

func getLoadoutKeeperByDeviceId(deviceId: int) -> LoadoutKeeper:
	for keeper in keeperTemplates:
		if (deviceId == 0 and keeper.deviceId == -1) or (deviceId == -1 and keeper.deviceId == 0) or keeper.deviceId == deviceId:
			return keeper.duplicate()

	return Loadout.createDefaultKeeper()

func updateTemplatePlayerPeer(playerId: String, newPeerId: int) -> void :
	for keeper: LoadoutKeeper in keeperTemplates:
		if (keeper.playerId == playerId):
			keeper.peerId = newPeerId

func updatePlayerIdForKeeper(newPlayerId: String, inKeeperId: String) -> void :
	for keeper: LoadoutKeeper in keepers:
		if (keeper.keeperId == inKeeperId):
			keeper.playerId = newPlayerId

func getLoadoutKeeperByPlayerId(playerId: String) -> LoadoutKeeper:
	for keeper in keeperTemplates:
		if keeper.playerId == playerId:
			return keeper.duplicate()

	return Loadout.createDefaultKeeper()

func saveStateToTemplate(keeper: Keeper) -> void :
	for lkt in keeperTemplates:
		if lkt.playerId == keeper.playerId:
			lkt.temporaryBuffs.clear()
			lkt.position = keeper.position
			for tb in keeper.temporaryBuffs:
				lkt.temporaryBuffs.append(tb.duplicate())
			break

func serialize() -> Dictionary:
	var keepersSerialized: = []
	var alreadySerializedPlayerIds: = []
	for keeper in keepers:
		alreadySerializedPlayerIds.append(keeper.playerId)
		keepersSerialized.append(keeper.serialize())
	for keeper in keeperTemplates:
		if alreadySerializedPlayerIds.has(keeper.playerId):
			continue
		keepersSerialized.append(keeper.serialize())

	var domesSerialized: = []
	for dome in domes:
		domesSerialized.append(dome.serialize())

	var data = {
		"domes": domesSerialized, 
		"keepers": keepersSerialized, 
		"modeId": modeId, 
		"modeConfig": modeConfig, 
		"worldId": worldId, 
		"palette": palette, 
		"difficultyByTeamId": var_to_str(difficultyByTeamId), 
	}
	return data

func deserialize(d: Dictionary):
	modeConfig = d.get("modeConfig", {})

	if d.has("domes"):
		domes = []
		var i: = 0
		var loadoutModeId: String = d.get("modeId", CONST.MODE_RELICHUNT)
		for dome in d.get("domes"):
			var ld = LoadoutDome.new()
			ld.deserialize(dome)
			domes.append(ld)
			if i == 0:


				var additionalGadgets: Array = modeConfig.get(CONST.MODE_CONFIG_ADDITIONAL_GADGETS, [])
				if loadoutModeId == CONST.MODE_ASSIGNMENTS and additionalGadgets.size() > 0 and ld.additionalGadgets.size() == 0:
					push_warning("Found additional gadgets in mode config, adding to loadout dome: ", additionalGadgets)
					ld.additionalGadgets.append_array(additionalGadgets)
				modeConfig.erase(CONST.MODE_CONFIG_ADDITIONAL_GADGETS)
			i += 1
	else:
		var ld = LoadoutDome.new()
		ld.deserialize(d)
		domes = [ld]

	if d.has("keepers"):
		keeperTemplates = []
		for keeper in d.get("keepers"):
			var lk = LoadoutKeeper.new()
			lk.deserialize(keeper)
			keeperTemplates.append(lk)
	else:
		var lk = LoadoutKeeper.new()

		lk.keeperId = d.get("keeperId", "keeper1")
		lk.skinId = d.get("skinId", "skin0")
		keeperTemplates = [lk]

	modeId = d.get("modeId", CONST.MODE_RELICHUNT)
	worldId = d.get("worldId", "world1")
	palette = d.get("palette", "")
	if d.has("difficultyByTeamId"):
		difficultyByTeamId = str_to_var(d.get("difficultyByTeamId"))

func loadKeepers() -> void :


	for keeper in keeperTemplates:
		var loaded = keeper.duplicate()
		if loaded.platformId == Platform.get_user_id():
			loaded.peerId = 1
		keepers.append(loaded)

func duplicate():
	var loadout = get_script().new()

	loadout.domes = domes.duplicate(true)
	loadout.keepers = keepers.duplicate(true)
	loadout.modeId = modeId
	loadout.modeConfig = modeConfig.duplicate()
	loadout.worldId = worldId
	loadout.palette = palette
	loadout.difficultyByTeamId = difficultyByTeamId.duplicate()
	return loadout

func asLoadout():
	var copy = duplicate()
	copy.worldId = ""
	copy.palette = ""

	for x in copy.keepers:
		x.position = Vector2.ZERO
		x.keeper = null
		x.temporaryBuffs.clear()
	return copy

func asLoadoutWithTemplates():
	var copy = duplicate()
	copy.worldId = ""
	copy.palette = ""
	copy.keeperTemplates = keeperTemplates.duplicate()

	for x in copy.keepers:
		x.position = Vector2.ZERO
		x.keeper = null
		x.temporaryBuffs.clear()
	return copy


func keeper() -> LoadoutKeeper:
	return keepers.front()

func saveKeepersToTemplates(additionalTemplates: Array = []) -> void :
	keeperTemplates.clear()
	for keeper: LoadoutKeeper in keepers:
		keeperTemplates.append(keeper.duplicate())
	for keeper: LoadoutKeeper in additionalTemplates:
		keeperTemplates.append(keeper.duplicate())

func updateTemplates() -> void :
	for kt: LoadoutKeeper in keeperTemplates.duplicate():
		var currentLK: LoadoutKeeper
		for k in keepers:
			if k.playerId == kt.playerId:
				currentLK = k.duplicate()
		if is_instance_valid(currentLK):
			keeperTemplates.erase(kt)
			keeperTemplates.append(currentLK)

func to_bytes() -> PackedByteArray:
	var keepersSerialized: = []
	for keeper in keepers:
		keepersSerialized.append(keeper.to_bytes())

	var domesSerialized: = []
	for dome in domes:
		domesSerialized.append(dome.to_bytes())

	var data: = {
		"keepers": keepersSerialized, 
		"domes": domesSerialized, 
		"modeId": modeId, 
		"modeConfig": modeConfig, 
		"worldId": worldId, 
		"palette": palette, 
		"difficultyByTeamId": difficultyByTeamId, 
	}


	return var_to_bytes(data)

static func from_bytes(buffer: PackedByteArray, set_keepers: bool = true) -> Loadout:
	var loadout = Loadout.new()

	var d: Dictionary = bytes_to_var(buffer)

	loadout.keepers = []
	if set_keepers:
		for keeper in d.get("keepers"):
			var lk: = LoadoutKeeper.from_bytes(keeper)
			loadout.keepers.append(lk)

	for dome in d.get("domes", []):
		var ld: = LoadoutDome.from_bytes(dome)
		loadout.domes.append(ld)

	loadout.modeId = d.get("modeId", CONST.MODE_RELICHUNT)
	loadout.modeConfig = d.get("modeConfig", {})
	loadout.worldId = d.get("worldId", "world1")
	loadout.palette = d.get("palette", "")
	loadout.difficultyByTeamId = d.get("difficultyByTeamId", {})

	return loadout

func loadout_keepers_to_bytes() -> PackedByteArray:
	var keeperBytes: = []
	for keeper in keeperTemplates:
		keeperBytes.append(keeper.to_bytes())

	return var_to_bytes(keeperBytes)

func loadout_keepers_from_bytes(buffer: PackedByteArray) -> void :
	var keeperBytes: Array = bytes_to_var(buffer)
	keeperTemplates.clear()
	for kb in keeperBytes:
		var lk: = LoadoutKeeper.from_bytes(kb)
		keeperTemplates.append(lk)
