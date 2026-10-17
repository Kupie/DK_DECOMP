class_name ClientLandingStage
extends LandingStage

enum StatusCheck{LEVEL_LOADED, MAP_DATA, DATA_UPDATE, UPGRADE_DATA, LANDMARK_DATA}

var statusChecks: Dictionary = {
	StatusCheck.LEVEL_LOADED: false, 
	StatusCheck.MAP_DATA: false, 
	StatusCheck.DATA_UPDATE: false, 
	StatusCheck.LANDMARK_DATA: false
}

func _ready() -> void :
	super._ready()
	Data.full_sync_received.connect(on_full_data_sync)

func start():
	super.start()

	checkReady()

func build(data: Array):
	GameWorld.prepareCleanData()
	Network.update_local_connection_state(Network.ConnectionState.LEVEL_STAGE_MAP_DATA)

	if typeof(data[0]) != TYPE_PACKED_BYTE_ARRAY or typeof(data[1]) != TYPE_INT or typeof(data[2]) != TYPE_BOOL:
		push_error("Invalid data sent to ClientLandingStage.")

	levelStartData = LevelStartData.new()
	levelStartData.loadout = Loadout.from_bytes(data[0])
	Level.loadout = levelStartData.loadout
	Level.levelSeed = data[1]
	levelStartData.savegame = data[2]
	GameWorld.runTime = data[3]
	if levelStartData.savegame:
		GameWorld.musicCountdown = 0

func remote_set_map_data(map_data: Dictionary):
	print("received map data")
	levelStartData.tileData = preload("res://content/map/MapData.tscn").instantiate()
	for layer in map_data.keys():
		levelStartData.tileData.set_layer_data(layer, map_data[layer])

	statusChecks[StatusCheck.MAP_DATA] = true

	checkReady()

func remote_set_upgrade_data(upgrade_data: Dictionary):
	GameWorld.setUpgradeData(upgrade_data)

	statusChecks[StatusCheck.UPGRADE_DATA] = true

	checkReady()

func remote_set_landmark_data(biomes: PackedStringArray, chamber_placements: Dictionary, cave_placements: Dictionary):

	levelStartData.biomes = Array(Array(biomes), TYPE_STRING, "", null)
	levelStartData.chamberPlacements = chamber_placements
	levelStartData.cavePlacements = cave_placements

	statusChecks[StatusCheck.LANDMARK_DATA] = true

	checkReady()

func on_full_data_sync():
	statusChecks[StatusCheck.DATA_UPDATE] = true

	checkReady()

func _process(delta):
	pass

func _input(event):
	pass

func checkReady() -> void :
	if not statusChecks[StatusCheck.LEVEL_LOADED]:
		statusChecks[StatusCheck.LEVEL_LOADED] = is_instance_valid(levelStage)

	for status in statusChecks.values():
		if not status:
			return

	if Network.local_connection_state < Network.ConnectionState.LEVEL_STAGE_SPAWN:
		Network.update_local_connection_state(Network.ConnectionState.LEVEL_STAGE_SPAWN)

	if (GameWorld.devMode or levelStartData.savegame) and not ending:
		end()

func end():
	if not ending:
		ending = true
		set_process(false)


		var isStageValid: = is_instance_valid(levelStage) and is_instance_valid(levelStartData) and is_instance_valid(levelStartData.tileData)
		if not isStageValid:
			return

		if GameWorld.devMode:
			ResourceSaver.save(levelStartData.tileData.pack(), "res://content/map/data/TileDataGenerated.tscn")
		StageManager.activateStage(levelStage, [levelStartData])
