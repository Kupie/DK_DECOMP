extends Node

signal keeper_data_loaded
signal continue_loading_save(cancel: bool)

const SAVE_SLOT_FILE_TEMPLATE: = "user://%s/savegame_%d.json"
const SAVE_SLOT_FILE_TEMPLATE_BACKUP: = "user://%s/savegame_%d_backup_%s.json"
const SAVE_TILE_FILE_TEMPLATE: = "user://%s/savegame_%d_map.scn"
const SAVE_TILE_FILE_TEMPLATE_BACKUP: = "user://%s/savegame_%d_map_backup_%s.scn"
const SAVE_TILE_FILE_REPLAY_TEMPLATE: = "user://%s/savegame_%d_map_replay.scn"

const SAVE_META3_FILE_TEMPLATE: = "user://savegame_%s.json"
const SAVE_META4_FILE_TEMPLATE: = "user://savegame4_%s.json"
const SAVE_META4_FILE_TEMPLATE_BACKUP: = "user://savegame4_%s_backup_%s.json"

const SAVE_FILE_PASSWORD = "yaph!o0keu5iTei&"
const VERSION_STATE_FILE: = "user://version.txt"
const TUTORIAL_STATE_FILE: = "user://tutorials.txt"
const DEV_STATE_FILE: = "user://dev.txt"
const SAVE_VERSION = 4

const UNENCRYPTED_META_FILES: = false

const CANCELED: = 2
const ALLOW_MULTIPLAYER_ERROR: = 3

var currentLoadingSavegame: = false
var allow_saving: = true
var scheduled_save_slot: = -1
var scheduled_save_folder: = ""
var _isLocalSave: bool = false

func isCurrentlyLoadingLocalSave() -> bool:
	return currentLoadingSavegame and _isLocalSave

func _process(delta: float) -> void :

	if ( not StageManager.isInLevel() or StageManager.currentStage.stage_ending or GameWorld.gameover) and scheduled_save_slot >= 0:
		scheduled_save_slot = -1
		scheduled_save_folder = ""
		return


	if scheduled_save_slot >= 0 and scheduled_save_folder != "":
		for teamId in Level.teams:
			if Data.of(teamId + ".monsters.wavepresent"):
				return

		_saveGame(scheduled_save_folder, scheduled_save_slot)
		scheduled_save_slot = -1

const MAX_SLOTS: = 3
var saveSlotBackup: = false
var metaStateBackup: = false


func saveGame(save_folder: String, slot: int = 0, immediate: bool = false):
	if immediate:
		for teamId in Level.teams:
			if Data.of(teamId + ".monsters.wavepresent"):
				return
		_saveGame(save_folder, slot)
	else:
		scheduled_save_slot = slot
		scheduled_save_folder = save_folder


func _saveGame(save_folder: String, slot: int = 0):
	if not allow_saving:
		Logger.info("not saving game as saving is not allowed")
		return

	if GameWorld.devMode and \
	(save_folder == "multiplayer" and Network.multiplayer_mode == Network.MultiplayerMode.OFFLINE_SINGLEPLAYER) or \
	(save_folder == "singleplayer" and Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER):
		var error_data: = {
			"loadout": Level.loadout.serialize(), 
			"MultiplayerMode": Network.multiplayer_mode, 
			"RunStarted": GameWorld.runStarted, 
			"SaveFolder": save_folder, 
			"StageName": StageManager.currentStage.name
		}
		var msg: = "failed to save because save folder and multiplayer mode were mismatched"
		Logger.error(msg, "_saveGame", error_data)
		Network.close_session(msg)
		return

	var dir: = DirAccess.open("user://")
	if not dir.dir_exists(save_folder):
		dir.make_dir(save_folder)

	var saveFile: = SAVE_SLOT_FILE_TEMPLATE % [save_folder, slot]

	var f: = FileAccess.open_encrypted_with_pass(saveFile, FileAccess.ModeFlags.WRITE, SAVE_FILE_PASSWORD)
	if f == null:
		var err = FileAccess.get_open_error()
		Logger.error("failed to open encrypted save file", "GameWorld.saveGame", {"error": err, "file": saveFile})
		return err


	var objects = {}
	for o in get_tree().get_nodes_in_group("saveable"):
		if o.has_method("serialize"):
			var data: Dictionary = serialize_saveable(o)
			var priority = data["meta.priority"]
			if not objects.has(priority):
				objects[priority] = []
			objects[priority].append(data)

	GameWorld.incrementRunStat("saves", "team1")

	for lkt in Level.loadout.keeperTemplates:
		var presentInKeepers: = false
		for lk in Level.loadout.keepers:
			if lk.playerId == lkt.playerId:
				presentInKeepers = true
				break

		if presentInKeepers:
			continue

		if Keepers.hasKeeper(lkt.playerId):
			Level.loadout.keepers.append(lkt.duplicate())

	var camPositionsByPlayerId: = {}
	for lk in Level.loadout.keepers:
		assert (Keepers.hasKeeper(lk.playerId), "Keepers.hasKeeper() check is needed here!")
		lk.position = Keepers.getKeeper(lk.playerId).position
		var cam = Level.viewports.getPlayerCam(lk.playerId)

		if cam != null:
			camPositionsByPlayerId[lk.playerId] = var_to_str(cam.position)

	var monster_managers_serialized: = {}
	for teamId in Level.monstersByTeamId:
		monster_managers_serialized[teamId] = Level.monstersByTeamId[teamId].serialize()


	var saveData = {
		"version": SAVE_VERSION, 
		"Monsters": var_to_str(monster_managers_serialized), 
		"Objects": objects, 
		"Upgrades": var_to_str(GameWorld.upgrades.duplicate()), 
		"RunStats": GameWorld.runStats, 
		"UpgradeLimits": GameWorld.upgradeLimits, 
		"BoughtUpgrades": GameWorld.boughtUpgrades, 
		"LockedUpgrades": GameWorld.lockedUpgrades, 
		"unlockablePets": GameWorld.unlockablePets, 
		"availableTechSlots": GameWorld.availableTechSlots, 
		"cycleSpeed": GameWorld.cycleSpeed, 
		"RunStarted": GameWorld.runStarted, 
		"RunTime": GameWorld.runTime, 
		"devModeActivated": GameWorld.devModeActivated, 
		"newSkinsToUnlock": GameWorld.newSkinsToUnlock, 
		"runModifiersToUnlock": GameWorld.runModifiersToUnlock, 
		"Data": Data.serialize(), 
		"Map": Level.map.serialize(), 
		"Recorder": Recorder.serialize(), 
		"loadout": Level.loadout.serialize(), 
		"camPositionsByPlayerId": camPositionsByPlayerId, 
		"keepers": Keepers.serialize(), 
		"runId": GameWorld.runId, 
		"MultiplayerMode": Network.multiplayer_mode, 
		"assignmentRewardStatus": var_to_str(GameWorld.assignmentRewardStatus), 
		"ostKeeperId": GameWorld.ostKeeperId
	}

	var json_data = JSON.stringify(saveData)
	f.store_string(json_data)
	f.close()
	Logger.info("saved game state for save " + str(slot))


	var packedTileData = Level.map.getTileData().pack()
	var tileDataFile = SAVE_TILE_FILE_TEMPLATE % [save_folder, slot]
	var err = ResourceSaver.save(packedTileData, tileDataFile)
	if err != OK:
		Logger.error("failed to save tiledata", "GameWorld.saveGame", {"error": err, "file": tileDataFile})
		return err

	packedTileData = Recorder.initialMapData.pack()
	tileDataFile = SAVE_TILE_FILE_REPLAY_TEMPLATE % [save_folder, slot]
	err = ResourceSaver.save(packedTileData, tileDataFile)
	if err != OK:
		Logger.error("failed to save replay tiledata", "GameWorld.saveGame", {"error": err, "file": tileDataFile})
		return err

	Logger.info("saved map state for save " + str(slot))
	return OK


func saveRollingSavegame(immediate: bool = false):
	var dir = DirAccess.open("user://")
	for s in ["singleplayer", "multiplayer"]:
		if not dir.dir_exists(s):
			dir.make_dir(s)

	if !saveSlotBackup:
		var d: = DirAccess.open("user://")
		var params: = [get_run_folder(), (MAX_SLOTS - 1)]
		if FileAccess.file_exists(SAVE_SLOT_FILE_TEMPLATE % params):
			d.remove(SAVE_SLOT_FILE_TEMPLATE % params)
			d.remove(SAVE_TILE_FILE_TEMPLATE % params)
			d.remove(SAVE_TILE_FILE_REPLAY_TEMPLATE % params)
		for i in range(MAX_SLOTS - 1, -1, -1):
			params[1] = i
			var params2: = [params[0], i + 1]
			if FileAccess.file_exists(SAVE_SLOT_FILE_TEMPLATE % params):
				DirAccess.rename_absolute(SAVE_SLOT_FILE_TEMPLATE % params, SAVE_SLOT_FILE_TEMPLATE % params2)
			if FileAccess.file_exists(SAVE_TILE_FILE_TEMPLATE % params):
				DirAccess.rename_absolute(SAVE_TILE_FILE_TEMPLATE % params, SAVE_TILE_FILE_TEMPLATE % params2)
			if FileAccess.file_exists(SAVE_TILE_FILE_REPLAY_TEMPLATE % params):
				DirAccess.rename_absolute(SAVE_TILE_FILE_REPLAY_TEMPLATE % params, SAVE_TILE_FILE_REPLAY_TEMPLATE % params2)
		saveSlotBackup = true

	saveGame(get_run_folder(), 0, immediate)


func readAndParseSaveFile(folder: String, slot: int = 0) -> Dictionary:
	var saveFile: = SAVE_SLOT_FILE_TEMPLATE % [folder, slot]
	if not FileAccess.file_exists(saveFile):
		return {}



	var f: = FileAccess.open_encrypted_with_pass(saveFile, FileAccess.ModeFlags.READ, SAVE_FILE_PASSWORD)
	if f == null:

		f = FileAccess.open(saveFile, FileAccess.ModeFlags.READ)
		if f == null:
			return {}

	var save_text: = f.get_as_text()

	if GameWorld.qaOptions:
		var f2 = FileAccess.open(SAVE_SLOT_FILE_TEMPLATE % [folder, 99], FileAccess.ModeFlags.WRITE)
		f2.store_string(save_text)
		f2.close()
	var test_json_conv = JSON.new()
	var error = test_json_conv.parse(save_text)
	if error != OK:
		print("Error parsing JSON save file. Error code %d" % error)
		print("Line %d, error message: %s" % [test_json_conv.get_error_line(), test_json_conv.get_error_message()])
		return {}
	var saveData = test_json_conv.get_data()
	f.close()

	if not saveData:
		return {}

	return saveData


func loadGame(baseFolder: String, slot: int = 0):
	if currentLoadingSavegame:
		Logger.error("Failed to load save game because a save game is already loading.", "GameWorld.loadGame", slot)
		return FAILED

	currentLoadingSavegame = true
	var saveData: = readAndParseSaveFile(baseFolder, slot)

	if saveData.size() == 0:
		print("Save data was null. Check for JSON parsing errors.")
		return FAILED

	Network.multiplayer_mode = saveData.get("MultiplayerMode", Network.MultiplayerMode.OFFLINE_SINGLEPLAYER) as Network.MultiplayerMode
	GameWorld.ostKeeperId = saveData.get("ostKeeperId", GameWorld.ostKeeperId)
	var unavailableDlcContent: bool = false
	var rawLoadout: Dictionary = saveData.get("loadout", {})
	for keeper in rawLoadout["keepers"]:
		var keeperId: String = keeper["keeperId"]
		var isDlcKeeper = Data.dlcKeepers.has(keeperId)
		var unavailableDlcKeeper = isDlcKeeper and ( not GameWorld.isUnlocked(keeperId))
		unavailableDlcContent = unavailableDlcContent or unavailableDlcKeeper
	if rawLoadout.has("modeConfig") and rawLoadout["modeConfig"].has("assignment"):
		var assignment = rawLoadout["modeConfig"]["assignment"]
		var dlcAssignment: bool = Data.keeperDlcAssignments.has(assignment)
		var unavailableDlcAssignment = dlcAssignment and ( not GameWorld.isAssignmentUnlocked(assignment))
		unavailableDlcContent = unavailableDlcContent or unavailableDlcAssignment
	if not Platform.purchased_keeper_dlc():
		var unavailableDlcPet = false
		for domeData in rawLoadout.get("domes", []):
			unavailableDlcPet = unavailableDlcPet or Data.keeperDlcPeets.has(domeData.get("petId", ""))
		unavailableDlcContent = unavailableDlcContent or unavailableDlcPet
	if unavailableDlcContent:
		if Network.is_offline_mode():
			Logger.error("Failed to load game due to save game containing unavailable dlc keeper content.", "GameWorld.loadGame", slot)
			return ERR_UNAUTHORIZED
		else:


			GameWorld.update_keeper_dlc(true)

	_isLocalSave = false
	if (baseFolder == "singleplayer" and Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER) or \
	(baseFolder == "multiplayer" and Network.multiplayer_mode == Network.MultiplayerMode.OFFLINE_SINGLEPLAYER):
		print("Failed to load save because the folder was %s and the multiplayer mode was %d - printing debug information:" % [baseFolder, Network.multiplayer_mode])
		var loadout = Loadout.default()
		loadout.deserialize(saveData.get("loadout", loadout))
		Data.sanitizeLoadout(loadout)
		print("There are %d keeper templates in the loadout." % loadout.keeperTemplates.size())
		print("There are %d domes in the loadout." % loadout.domes.size())
		return FAILED

	var online_modes = [Network.MultiplayerMode.ONLINE_CROSSPLAY, Network.MultiplayerMode.ONLINE_PLATFORM]
	if online_modes.has(Network.multiplayer_mode) and not GameWorld.is_allowOnlineMultiplayer():
		currentLoadingSavegame = false
		return ALLOW_MULTIPLAYER_ERROR

	if Network.multiplayer_mode == Network.MultiplayerMode.ONLINE_ENET:
		Network.create_enet_host()
	elif Network.multiplayer_mode == Network.MultiplayerMode.ONLINE_CROSSPLAY:
		Network.create_crossplay_lobby()
	elif Network.multiplayer_mode == Network.MultiplayerMode.ONLINE_PLATFORM:
		Network.create_platform_lobby()
	else:
		_isLocalSave = true

	var levelStartData = LevelStartData.new()
	levelStartData.savegame = true

	var loadout = Loadout.default()
	loadout.deserialize(saveData.get("loadout", loadout.serialize()))
	Data.sanitizeLoadout(loadout)
	sanitizeLegacyAdditionalGadgets(loadout, saveData)


	loadout.loadKeepers()
	Keepers.deserialize(saveData.get("keepers", {}))

	if _isLocalSave:


		for keeper in loadout.keepers:
			keeper.peerId = multiplayer.get_unique_id()

	levelStartData.loadout = loadout
	Level.loadout = loadout

	var savedDataValues: Dictionary = saveData.get("Data", {})
	for lk in loadout.keeperTemplates:
		var keeperDataPrefix: String = (lk.playerId + "." + lk.keeperId + ".").to_lower()
		for key in savedDataValues:
			if key.begins_with(keeperDataPrefix):
				levelStartData.savedDataPlayerIds.append(lk.playerId)
				break

	if Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER:
		keeper_data_loaded.emit()

		var cancel: bool = await continue_loading_save
		if cancel:
			currentLoadingSavegame = false
			return CANCELED

	if not saveData or saveData.is_empty():
		Logger.error("failed to load savegame", "GameWorld.loadGame", slot)
		currentLoadingSavegame = false
		return FAILED

	if not saveData.has("version"):
		Logger.error("savegame does not contain a version", "GameWorld.loadGame")
		currentLoadingSavegame = false
		return FAILED

	if saveData["version"] != SAVE_VERSION:
		Logger.error("savegame from uncompatible version %s. (Current: %s)." % [saveData["version"], SAVE_VERSION], "GameWorld.loadGame")
		currentLoadingSavegame = false
		return FAILED

	var tileDataResource: Resource
	if saveData.has("Map"):
		var tileDataFileName = SAVE_TILE_FILE_TEMPLATE % [baseFolder, slot]
		if FileAccess.file_exists(tileDataFileName) == false:
			Logger.error("cannot load tile data for save, file is missing", "GameWorld.loadGame", tileDataFileName)
			currentLoadingSavegame = false
			return FAILED
		else:


			tileDataResource = ResourceLoader.load(tileDataFileName)
			var tileData: MapData = tileDataResource.instantiate()
			levelStartData.tileData = tileData

	if saveData.has("Recorder"):
		var replayTileDataFileName = SAVE_TILE_FILE_REPLAY_TEMPLATE % [baseFolder, slot]
		if !FileAccess.file_exists(replayTileDataFileName):
			Logger.error("cannot load replay tile data for save, file is missing", "GameWorld.loadGame", replayTileDataFileName)
			currentLoadingSavegame = false
			return FAILED

	levelStartData.runTime = saveData.get("RunTime", 0.0)
	GameWorld.loadCount = saveData.get("RunStats", {}).get("team1.loads", 0)

	StageManager.startStage("stages/landing/landing", [levelStartData])

	GameWorld.assignmentRewardStatus = str_to_var(saveData.get("assignmentRewardStatus", GameWorld.assignmentRewardStatus))
	await StageManager.stage_started
	await StageManager.stage_started

	GameWorld.newSkinsToUnlock = saveData.get("newSkinsToUnlock", [])
	GameWorld.runModifiersToUnlock = saveData.get("runModifiersToUnlock", [])
	if saveData.has("unlockablePets"):
		GameWorld.unlockablePets = saveData.get("unlockablePets")




	if saveData.has("Data"):
		Data.deserialize(saveData["Data"])

	if saveData.has("Recorder"):
		var tileDataFileName = SAVE_TILE_FILE_REPLAY_TEMPLATE % [baseFolder, slot]
		if FileAccess.file_exists(tileDataFileName):
			var tileData = ResourceLoader.load(tileDataFileName)
			Recorder.initialMapData = tileData.instantiate()
		else:
			Logger.error("cannot load tile data for save, file is missing", "GameWorld.loadGame", tileDataFileName)
			currentLoadingSavegame = false
			return FAILED
		Recorder.deserialize(saveData["Recorder"])

	if saveData.has("Map"):
		Level.map.setTileData(tileDataResource.instantiate())
		Level.map.deserialize(saveData["Map"])

	if saveData.has("Monsters"):
		if typeof(saveData["Monsters"]) == TYPE_STRING:

			var monster_manager_data = str_to_var(saveData["Monsters"])
			for teamId in Level.monstersByTeamId:
				Level.monstersByTeamId[teamId].deserialize(monster_manager_data[teamId])
		else:

			for teamId in Level.monstersByTeamId:
				Level.monstersByTeamId[teamId].deserialize(saveData["Monsters"])

	if saveData.has("Upgrades"):
		GameWorld.upgrades = BackwardCompatibilityUtils.str_to_var(saveData["Upgrades"])

	if saveData.has("RunStats"):
		GameWorld.runStats = saveData["RunStats"]

		for key: String in GameWorld.runStats.keys():

			if not key.contains("team") and not key.contains("."):
				GameWorld.runStats["team1." + key] = GameWorld.runStats[key]
				GameWorld.runStats.erase(key)
		GameWorld.incrementRunStat("loads", "team1")

	if saveData.has("UpgradeLimits"):
		GameWorld.upgradeLimits = saveData["UpgradeLimits"]

	GameWorld.devModeActivated = saveData.get("devModeActivated", false)

	if saveData.has("BoughtUpgrades"):
		for upgrade in saveData["BoughtUpgrades"]:
			if GameWorld.boughtUpgrades.has(upgrade):
				continue
			var upgradeParts: = parseBoughtUpgrade(upgrade)



			var split: PackedStringArray = upgradeParts[0].split(".")
			if upgradeParts[0].begins_with("keeper") or (split.size() == 2 and split[1].begins_with("keeper") and split[1].length() == 7):
				continue
			GameWorld.addUpgrade(upgradeParts[0], upgradeParts[1])

	GameWorld.cycleSpeed = saveData.get("cycleSpeed", 1.0)
	GameWorld.runStarted = saveData.get("RunStarted", true)
	GameWorld.availableTechSlots = saveData.get("availableTechSlots", [])


	if saveData.has("Objects"):
		var sorted_priority = saveData["Objects"].keys()
		sorted_priority.sort()
		for priority in sorted_priority:
			for d in saveData["Objects"][priority]:
				match d["meta.kind"]:
					"chamber":
						var chamberScene
						if d.has("meta.scenepath"):
							chamberScene = load(d["meta.scenepath"])
						else:
							chamberScene = Level.map.getSceneForTileType(d["meta.chamberType"])
						var chamber = Level.map.addChamber(BackwardCompatibilityUtils.str_to_var(d["coord"]), chamberScene)
						deserialize_saveable(chamber, d)
					"cave":
						var cave = load(d["meta.filename"]).instantiate()
						deserialize_saveable(cave, d)
					"station":
						var path: String = d["meta.path"]
						path = path.substr(0, path.find("LevelStage")) + "LevelStage"
						var parent = get_node_or_null(path)
						var o
						if parent:
							o = get_node(d["meta.path"])
						if o:
							deserialize_saveable(o, d)
						else:
							prints("WARNING: Station not loaded. path", path, ", name ", d["meta.name"], "data ", var_to_str(d))

					"generic":
						var o = load(d["meta.filename"]).instantiate()

						match d["meta.parent"]:
							"Map":
								Level.map.add_child(o)
							"Drops":
								Level.drops.load_drop(o)
							"Tiles":
								Level.map.find_child("Tiles").add_child(o)
							"team1Dome":
								if not addObjectToDome(o, d):
									continue
							"team2Dome":
								if not addObjectToDome(o, d):
									continue
							"Monsters":
								Level.viewports.addMonster(o)
							"TileOverlays":
								Level.map.addTileOverlayEffect(o)
							"SubViewport":
								Level.viewports.addElement(o)
							_:
								prints("WARNING: Generic not loaded. filename", d["meta.filename"], ", name ", d["meta.name"], "data ", var_to_str(d))
						deserialize_saveable(o, d)

					_:
						prints("WARNING: Unknown kind of object %s" % d["meta.path"], "data ", var_to_str(d))

	for playerId in saveData.get("camPositionsByPlayerId", []):
		var cam = Level.viewports.getPlayerCam(playerId)
		if cam:
			cam.position = BackwardCompatibilityUtils.str_to_var(saveData["camPositionsByPlayerId"][playerId])

	GameWorld.runId = saveData.get("runId", UUID.v4())



	if saveData.has("Data"):
		Data.deserialize(saveData["Data"])

	for teamId in Level.teams:
		Data.apply(teamId + ".dome.secondarystation", Keepers.get_team(teamId).getCount() > 1)



	await get_tree().process_frame
	GameWorld.savegame_loaded.emit()


	currentLoadingSavegame = false

	CheatDetection.resetIfRunning()
	GameWorld.runStarted = true
	Backend.event("run_continued")

	return OK

func addObjectToDome(o, d: Dictionary) -> bool:
	var teamId: String = d.get("teamId", "team1")
	if teamId == "":
		prints("WARNING: Discarding orphaned dome object", d.get("meta.filename", ""))
		o.free()
		return false
	Level.domesByTeamId[teamId].add_child(o)
	return true


func sanitizeLegacyAdditionalGadgets(loadout: Loadout, saveData: Dictionary) -> void :
	if loadout.modeId == CONST.MODE_ASSIGNMENTS:
		return

	var phantomGadgets: Dictionary = {}
	for dome: LoadoutDome in loadout.domes:
		for gadgetId in dome.additionalGadgets:
			phantomGadgets[gadgetId] = true
	if phantomGadgets.is_empty():
		return

	var teamIds: Array = []
	for dome: LoadoutDome in loadout.domes:
		if not teamIds.has(dome.teamId):
			teamIds.append(dome.teamId)

	var stripped: Array = []
	for gadgetId: String in phantomGadgets.keys():
		if not Data.gadgets.has(gadgetId):
			continue

		var bought: Array = saveData.get("BoughtUpgrades", [])
		for teamId: String in teamIds:
			var key: String = teamId + "." + gadgetId
			if bought.has(key):
				bought.erase(key)
				stripped.append(key)

		var cellarScene: String = Data.gadgets[gadgetId].get("scenes", {}).get("cellar", "")

		if cellarScene != "" and saveData.has("Objects"):
			var fullScenePath: String = "res://" + cellarScene
			for priority in saveData["Objects"]:
				var arr: Array = saveData["Objects"][priority]
				var i: int = arr.size() - 1
				while i >= 0:
					if arr[i].get("meta.filename", "") == fullScenePath:
						arr.remove_at(i)
						stripped.append("Object:" + fullScenePath)
					i -= 1

	for dome: LoadoutDome in loadout.domes:
		for gadgetId: String in phantomGadgets.keys():
			if dome.additionalGadgets.has(gadgetId):
				dome.additionalGadgets.erase(gadgetId)

	if not stripped.is_empty():
		Logger.warn("Sanitized legacy additional-gadgets corruption from save", 
			"SaveGame.sanitizeLegacyAdditionalGadgets", 
			{"modeId": loadout.modeId, "stripped": stripped})

func parseBoughtUpgrade(upgrade: String) -> PackedStringArray:
	var parts: = PackedStringArray()
	parts.resize(2)


	if upgrade.contains("."):
		var raw_parts: = upgrade.split(".", false, 1)
		if raw_parts[0].begins_with("team"):
			parts[0] = raw_parts[1]
			parts[1] = raw_parts[0]
			return parts
		if raw_parts[0].begins_with("player"):



			parts[0] = upgrade
			parts[1] = Keepers.getKeeper(raw_parts[0]).teamId if Keepers.hasKeeper(raw_parts[0]) else "team1"
			return parts


	parts[0] = upgrade
	if Data.gadgets.has(upgrade):
		if Data.gadgets[upgrade].get("takeslots", []).has("keepersuit"):
			parts[0] = "player1." + upgrade
	parts[1] = "team1"

	return parts


func loadRollingSavegame(baseFolder: String):
	var save_slots = []
	var backupLoaded = false
	var backupLoadFailed = false


	for slot in range(MAX_SLOTS):
		var save_file = SAVE_SLOT_FILE_TEMPLATE % [baseFolder, slot]
		if FileAccess.file_exists(save_file):
			var mod_time = FileAccess.get_modified_time(save_file)
			save_slots.append({"slot": slot, "time": mod_time})



	if save_slots.size() == 0:
		Logger.error("No valid savegame found")
		backupLoadFailed = true


	for i in range(save_slots.size()):
		var slot = save_slots[i]["slot"]
		var error = await loadGame(baseFolder, slot)
		if error == OK:
			Logger.info("Loaded save in slot " + str(slot))
			if i > 0:
				backupLoaded = true
			break
		elif error == CANCELED:
			return
		elif error == ALLOW_MULTIPLAYER_ERROR:
			Network.close_session("multiplayer.continue.allowmultiplayererror")
			return
		elif error == ERR_UNAUTHORIZED:
			delete_autosave(baseFolder)
			Network.close_session("keeperdlc.load.missing")
			return
		else:
			Logger.error("Failed to load save in slot " + str(slot))
			if i == save_slots.size() - 1:
				backupLoadFailed = true


	if backupLoaded:
		StageManager.loadSaveFallbackPopup()
		return
	if backupLoadFailed:
		StageManager.loadSaveFailed()
		Logger.error("Failed to load any valid savegame.")
		return


func has_autosave(singleplayer: bool) -> bool:
	for i in range(MAX_SLOTS):
		if FileAccess.file_exists(SAVE_SLOT_FILE_TEMPLATE % ["singleplayer" if singleplayer else "multiplayer", i]):
			return true
	return false


func delete_autosave(baseFolder: String = get_run_folder()) -> void :
	var run_dir: String = "user://" + baseFolder
	UtilsOS.ensure_dir_exists(run_dir)
	var d: = DirAccess.open(run_dir)
	for i in range(MAX_SLOTS):
		var saveFile: = SAVE_SLOT_FILE_TEMPLATE % [baseFolder, i]
		if d.file_exists(saveFile):
			d.remove(saveFile)
		saveFile = SAVE_TILE_FILE_TEMPLATE % [baseFolder, i]
		if d.file_exists(saveFile):
			d.remove(saveFile)
		saveFile = SAVE_TILE_FILE_REPLAY_TEMPLATE % [baseFolder, i]
		if d.file_exists((saveFile)):
			d.remove(saveFile)

func is_autosave_from_unsupported_version():
	if not has_autosave(true):
		return false

	var data = readAndParseSaveFile(get_run_folder())

	if not data or data.is_empty():
		return true
	if not data.has("version"):
		return true
	if data["version"] != SAVE_VERSION:
		return true

	return false

func create_autosave_backup():
	var saveFile: = SAVE_SLOT_FILE_TEMPLATE % [get_run_folder(), 0]
	var time = Time.get_datetime_dict_from_system()
	var timestr = "%s_%s_%s_%s_%s" % [time.year, time.month, time.day, time.hour, time.minute]
	var d: = DirAccess.open("user://")
	if d.file_exists(saveFile):
		d.copy(saveFile, SAVE_SLOT_FILE_TEMPLATE_BACKUP % [get_run_folder(), 0, timestr])
	saveFile = SAVE_TILE_FILE_TEMPLATE % [get_run_folder(), 0]
	if d.file_exists(saveFile):
		d.copy(saveFile, SAVE_TILE_FILE_TEMPLATE_BACKUP % [get_run_folder(), 0, timestr])

func create_metadata_backup():
	var id = "full"
	var saveFile: String = SAVE_META4_FILE_TEMPLATE % id
	var time = Time.get_datetime_dict_from_system()
	var timestr = "%s_%s_%s_%s_%s" % [time.year, time.month, time.day, time.hour, time.minute]
	var d: = DirAccess.open("user://")
	if d.file_exists(saveFile):
		d.copy(saveFile, SAVE_META4_FILE_TEMPLATE_BACKUP % [id, timestr])

func deleteMetaState():
	var saveFile = SAVE_META4_FILE_TEMPLATE % CONST.BUILD_TYPE.keys()[GameWorld.buildType].to_lower()
	var err: Error = DirAccess.remove_absolute(saveFile)
	if err == Error.OK:
		Logger.info("deleted savegame")
	else:
		Logger.info("failed to delete savegame")

func deleteAllMetaState():
	for slot in range(MAX_SLOTS):
		var file_str: String = str(CONST.BUILD_TYPE.keys()[GameWorld.buildType].to_lower(), str(slot))
		var save_file = SAVE_META4_FILE_TEMPLATE % file_str
		if FileAccess.file_exists(save_file):
			var err: Error = DirAccess.remove_absolute(save_file)
			if err == Error.OK:
				Logger.info("Deleted savegame: " + save_file)
			else:
				Logger.error("Failed to delete savegame: " + save_file)
		else:
			Logger.info("Savegame not found: " + save_file)

func serialize_saveable(object):
	var data = {}
	if object.has_method("serialize"):
		data = object.serialize()

	data["meta.name"] = object.name
	data["meta.filename"] = object.scene_file_path
	data["meta.path"] = object.get_path()
	data["meta.parent"] = object.get_parent().name
	if data.get("meta.kind") != "station":
		data["meta.position"] = var_to_str(object.global_position)
		data["meta.rotation"] = object.global_rotation

	if "teamId" in object:
		data["teamId"] = object.teamId

	return data

func deserialize_saveable(object, data):
	if data.has("teamId"):
		object.teamId = data.get("teamId", "team1")
	if data.has("meta.position"):
		object.global_position = BackwardCompatibilityUtils.str_to_var(data["meta.position"])
	if data.has("meta.rotation"):
		object.global_rotation = data["meta.rotation"]
	if object.has_method("deserialize"):
		object.deserialize(data)

func loadMetaStateFile(slot: int = 0) -> Array:
	var metastate: = {}
	var fallback: = false
	var saveFile

	if slot == -1:
		saveFile = SAVE_META4_FILE_TEMPLATE % CONST.BUILD_TYPE.keys()[GameWorld.buildType].to_lower()
	else:
		var file_str: String = str(CONST.BUILD_TYPE.keys()[GameWorld.buildType].to_lower(), str(slot))
		saveFile = SAVE_META4_FILE_TEMPLATE % file_str


	if not FileAccess.file_exists(saveFile):
		saveFile = SAVE_META3_FILE_TEMPLATE % CONST.BUILD_TYPE.keys()[GameWorld.buildType].to_lower()
		fallback = true

	var save
	if UNENCRYPTED_META_FILES:
		save = FileAccess.open(saveFile, FileAccess.READ)
	else:
		save = FileAccess.open_encrypted_with_pass(saveFile, FileAccess.ModeFlags.READ, SAVE_FILE_PASSWORD)
	if save == null:
		var err = FileAccess.get_open_error()
		if err != 0:
			Logger.error("failed to read meta state", "SaveGame.loadMetaState", err)
			if err == ERR_FILE_CORRUPT:
				var txt = parse_godot3_encrypted_file(saveFile)
				var result = JSON.parse_string(txt)
				if result:
					metastate = result
				else:
					GameWorld.notifyDamagedMetaFile = true
			elif err == ERR_FILE_NOT_FOUND:
				pass
			else:
				GameWorld.notifyDamagedMetaFile = true
				Logger.error("Failed to load meta save in slot " + str(slot))
				return [{}, false]
		else:

			save = FileAccess.open(saveFile, FileAccess.ModeFlags.READ)
	if save != null and metastate.is_empty():
		var i = save.get_as_text()
		var result = JSON.parse_string(i)
		if result:
			metastate = result

		save.close()

	return [metastate, fallback]


func loadMetaState(slot: int = 0):
	var metastate: = {}
	var usedFallback: = false
	if not GameWorld.resetBetweenRuns:
		var file = loadMetaStateFile(slot)
		if file == [{}, false] && GameWorld.notifyDamagedMetaFile:
			return ERR_BUG

		metastate = file[0]
		usedFallback = file[1]

	var defaultUnlocks: = ["dome1", "keeper1", "shield", CONST.MODE_RELICHUNT, "world1", CONST.MAP_SMALL, CONST.DIFFICULTY_RELAXED, CONST.DIFFICULTY_HARD, CONST.DIFFICULTY_BRUTAL, CONST.MODE_PRESTIGE_COUNTDOWN]

	GameWorld.currentMusicIndex = metastate.get("currentMusicIndex", 0)
	GameWorld.lastWorldIds = metastate.get("lastWorldIds", [])
	GameWorld.lastLeaderboardSection = metastate.get("lastLeaderboardSection", "friends")
	GameWorld.lastLeaderboardMultiplayer = metastate.get("lastLeaderboardMultiplayer", "singleplayer")
	GameWorld.lastHostMode = metastate.get("lastHostMode", "online")
	GameWorld.ostKeeperId = metastate.get("ostKeeperId", "keeper1")
	GameWorld.runCount = metastate.get("runCount", 0)
	GameWorld.unlockedElements = metastate.get("unlockedElements", defaultUnlocks)
	GameWorld.gadgetToKeep = metastate.get("gadgetToKeep", "")
	GameWorld.keptGadgetUsed = metastate.get("keptGadgetUsed", false)
	GameWorld.customCaveOrder = metastate.get("customCaveOrder", [])
	GameWorld.useCustomCaveOrderSetting = metastate.get("useCustomCaveOrderSetting", false)
	GameWorld.goalCameraZoomLoadout = metastate.get("goalCameraZoomLoadout", 4.0)
	GameWorld.customGadgetOrder = metastate.get("customGadgetOrder", [])
	GameWorld.useCustomGadgetOrderSetting = metastate.get("useCustomGadgetOrderSetting", false)
	GameWorld.customSupplementOrder = metastate.get("customSupplementOrder", [])
	GameWorld.useCustomSupplementOrderSetting = metastate.get("useCustomSupplementOrderSetting", false)
	GameWorld.assignmentProgress = metastate.get("assignmentProgress", {})
	GameWorld.unlockedPets = metastate.get("unlockedPets", [])
	GameWorld.unlockedSkins = metastate.get("unlockedSkins", {})
	GameWorld.unlockedRunModifiers = metastate.get("unlockedRunModifiers", [])
	GameWorld.usedAssigmentsGadgets = metastate.get("usedAssigmentsGadgets", {})
	GameWorld.assignmentRewardStatus = metastate.get("assignmentRewardStatus", {})
	GameWorld.lastChosenAssignmentDifficulty = metastate.get("lastChosenAssignmentDifficulty", {})
	GameWorld.lastUploadedAssignmentScore = metastate.get("lastUploadedAssignmentScore", -1)
	GameWorld.figuredOutMovementInLoadout = metastate.get("figuredOutMovementInLoadout", false)

	if GameWorld.unlockedElements.has("world-modifiers"):

		for m in Data.RUN_MODIFIERS:
			if not GameWorld.unlockedRunModifiers.has(m):
				GameWorld.unlockedRunModifiers.append(m)

	var pioneerPack = Platform.purchased_pioneer_pack() or GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION
	Logger.info("Pioneer pack subscription: " + str(pioneerPack))
	GameWorld.update_pioneer_pack(pioneerPack)

	var assessorBooster = Platform.purchased_assessor_booster() or GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION
	Logger.info("Assessor Booster pack subscription: " + str(assessorBooster))
	GameWorld.update_assessor_booster(assessorBooster)

	var keeperDlc = Platform.purchased_keeper_dlc() or GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION
	Logger.info("Keeper Dlc subscription: " + str(keeperDlc))
	GameWorld.update_keeper_dlc(keeperDlc)

	for u in defaultUnlocks:
		if not GameWorld.isUnlocked(u):
			GameWorld.unlockElement(u)


	GameWorld.unlockedElements.erase("prestige-cobalt")


	if not metastate.is_empty() and usedFallback:
		Logger.warn("Metastate loaded from godot3 version.")
		GameWorld.upgrade_progression_from_3_to_4()

	Level.loadout = Loadout.empty()
	if metastate.has("lastLoadoutsByMode"):
		var rawLoadouts: Dictionary = metastate.get("lastLoadoutsByMode")
		GameWorld.lastLoadoutsByMode = {}
		for key in rawLoadouts:
			var loadout = Loadout.new()
			loadout.deserialize(rawLoadouts[key])
			Data.sanitizeLoadout(loadout)

			GameWorld.lastLoadoutsByMode[key] = loadout
			if key == "last":
				Level.loadout = loadout

	GameWorld.sanitizeMetaState()
	GameWorld.unlocks.update()
	return OK

func loadRollingMetaState():
	var save_slots = []


	for slot in range(MAX_SLOTS):
		var file_str: String = str(CONST.BUILD_TYPE.keys()[GameWorld.buildType].to_lower(), str(slot))
		var save_file = SAVE_META4_FILE_TEMPLATE % file_str
		if FileAccess.file_exists(save_file):
			var mod_time = FileAccess.get_modified_time(save_file)
			save_slots.append({"slot": slot, "time": mod_time})



	if save_slots.size() == 0:
		Logger.error("No valid metadata found, checking for slotless file.")
		var error = loadMetaState(-1)
		if error != OK:
			Logger.info("Loaded MetaState file without any assigned slot - started the game for the first time?")
	else:

		for i in range(save_slots.size()):
			var slot = save_slots[i]["slot"]
			var error = loadMetaState(slot)
			if error == OK:
				Logger.info("Loaded meta save in slot " + str(slot))
				return
		GameWorld.notifyAllMetaFileDamaged = true
		Logger.error("Failed to load any valid meta save.")


func persistMetaState(slot: int = 0):
	var file_str: String = str(CONST.BUILD_TYPE.keys()[GameWorld.buildType].to_lower(), str(slot))
	var saveFile = SAVE_META4_FILE_TEMPLATE % file_str

	var save
	if UNENCRYPTED_META_FILES:
		save = FileAccess.open(saveFile, FileAccess.WRITE)
	else:
		save = FileAccess.open_encrypted_with_pass(saveFile, FileAccess.ModeFlags.WRITE, SAVE_FILE_PASSWORD)

	var loadoutsToStore: = {}
	for key in GameWorld.lastLoadoutsByMode:
		loadoutsToStore[key] = GameWorld.lastLoadoutsByMode[key].serialize()

	if save != null:
		var metastate: = {}
		metastate["runCount"] = GameWorld.runCount
		metastate["currentMusicIndex"] = GameWorld.currentMusicIndex
		metastate["unlockedElements"] = GameWorld.unlockedElements
		metastate["unlockedPets"] = GameWorld.unlockedPets
		metastate["unlockedSkins"] = GameWorld.unlockedSkins
		metastate["unlockedRunModifiers"] = GameWorld.unlockedRunModifiers
		metastate["gadgetToKeep"] = GameWorld.gadgetToKeep
		metastate["customGadgetOrder"] = GameWorld.customGadgetOrder
		metastate["customCaveOrder"] = GameWorld.customCaveOrder
		metastate["useCustomGadgetOrderSetting"] = GameWorld.useCustomGadgetOrderSetting
		metastate["useCustomCaveOrderSetting"] = GameWorld.useCustomCaveOrderSetting
		metastate["goalCameraZoomLoadout"] = GameWorld.goalCameraZoomLoadout
		metastate["useCustomSupplementOrderSetting"] = GameWorld.useCustomSupplementOrderSetting
		metastate["useCustomSupplementOrder"] = GameWorld.useCustomSupplementOrder
		metastate["customSupplementOrder"] = GameWorld.customSupplementOrder
		metastate["assignmentProgress"] = GameWorld.assignmentProgress
		metastate["lastLeaderboardSection"] = GameWorld.lastLeaderboardSection
		metastate["lastLeaderboardMultiplayer"] = GameWorld.lastLeaderboardMultiplayer
		metastate["lastHostMode"] = GameWorld.lastHostMode
		metastate["lastWorldIds"] = GameWorld.lastWorldIds
		metastate["keptGadgetUsed"] = GameWorld.keptGadgetUsed
		metastate["lastLoadoutsByMode"] = loadoutsToStore
		metastate["ostKeeperId"] = GameWorld.ostKeeperId
		metastate["usedAssigmentsGadgets"] = GameWorld.usedAssigmentsGadgets
		metastate["assignmentRewardStatus"] = GameWorld.assignmentRewardStatus
		metastate["lastChosenAssignmentDifficulty"] = GameWorld.lastChosenAssignmentDifficulty
		metastate["lastUploadedAssignmentScore"] = GameWorld.lastUploadedAssignmentScore
		metastate["figuredOutMovementInLoadout"] = GameWorld.figuredOutMovementInLoadout
		save.store_string(JSON.stringify(metastate, "\t"))
		save.close()

		if GameWorld.qaOptions:
			var f: = FileAccess.open(saveFile.replace("savegame4_", "readable_savegame4_"), FileAccess.ModeFlags.WRITE)
			if f != null:
				f.store_string(JSON.stringify(metastate, "\t"))
				f.close()
	else:
		Logger.error("SaveGame.persistMetaState", "Failed to save meta state with error code " + str(FileAccess.get_open_error()))


func saveRollingMetaState():
	if !metaStateBackup:
		var d: = DirAccess.open("user://")
		if FileAccess.file_exists(SAVE_META4_FILE_TEMPLATE % str(CONST.BUILD_TYPE.keys()[GameWorld.buildType].to_lower(), str(MAX_SLOTS - 1))):
			d.remove(SAVE_META4_FILE_TEMPLATE % str(CONST.BUILD_TYPE.keys()[GameWorld.buildType].to_lower(), str(MAX_SLOTS - 1)))
		for i in range(MAX_SLOTS - 1, -1, -1):
			if FileAccess.file_exists(SAVE_META4_FILE_TEMPLATE % str(CONST.BUILD_TYPE.keys()[GameWorld.buildType].to_lower(), str(i))):
				DirAccess.rename_absolute(SAVE_META4_FILE_TEMPLATE % str(CONST.BUILD_TYPE.keys()[GameWorld.buildType].to_lower(), str(i)), SAVE_META4_FILE_TEMPLATE % str(CONST.BUILD_TYPE.keys()[GameWorld.buildType].to_lower(), str(i + 1)))
		metaStateBackup = true

	persistMetaState(0)

func loadTutorialStages() -> void :
	var save: = FileAccess.open(TUTORIAL_STATE_FILE, FileAccess.ModeFlags.READ)
	if save != null:
		var i = save.get_as_text()
		var test_json_conv = JSON.new()
		test_json_conv.parse(i)
		var parsed = test_json_conv.get_data()
		if parsed:
			GameWorld.tutorialStages = parsed
		save.close()


func persistTutorialStages():
	var save: = FileAccess.open(TUTORIAL_STATE_FILE, FileAccess.ModeFlags.WRITE)
	if save != null:
		save.store_string(JSON.stringify(GameWorld.tutorialStages))
		save.close()
	else:
		Logger.error("GameWorld.persistTutorialStages", "Failed to save tutorials file with error code " + str(FileAccess.get_open_error()))

func parse_godot3_encrypted_file(filename):

	var f = FileAccess.open(filename, FileAccess.READ)
	f.get_32()
	f.get_32()
	f.get_buffer(16)
	var length = f.get_64()
	var ds = length
	if ds % 16:
		ds += 16 - (ds % 16)
	var data = f.get_buffer(ds)
	var aes = AESContext.new()
	aes.start(AESContext.MODE_ECB_DECRYPT, SAVE_FILE_PASSWORD.md5_text().to_ascii_buffer())
	var decrypted = aes.update(data)
	aes.finish()
	decrypted.resize(length)
	f.close()

	return decrypted.get_string_from_utf8()

func get_run_folder() -> String:
	if Level.isMultiplayer():
		return "multiplayer"
	else:
		return "singleplayer"
