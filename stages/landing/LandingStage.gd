class_name LandingStage
extends Stage



const SEED_OFFEST_MULTIPLIER: int = 123

var cam_offset = Vector2.ZERO
var shake = false
var levelData
var levelStage: LevelStage

var readiedPeers: = {}

@export var cam_zoom: = 2.0
@export var timeoutTimer: Timer

@onready var sky = find_child("sky")
@onready var streaks = find_child("streaks")
@onready var falling = find_child("falling")
@onready var cam = find_child("Camera2D")
@onready var anim = find_child("AnimationPlayer")
@onready var continueLabel = find_child("ContinueLabel")

var levelStartData: LevelStartData
var generatorsByThread: Dictionary
var readyGenerators: Array[TileDataGenerator]
var thread: Thread
var tween: Tween
var generationFinished: = false
var ending: = false
var timePassed: = 0.0
var lastWarn: = 0.0
var seed_offset = 0
var zoom_modification: = 1.0
var viewport_scale_factor: = 1.0
var _team2MapOffset: Vector2i
var restartedRun: = false

const maximum_map_generation_attemots: = 15

func _ready() -> void :
	get_viewport().size_changed.connect(mainWindowSizeChanged)
	mainWindowSizeChanged()
	$CanvasLayer / SubViewportContainer.stretch_shrink = 2 if Options.renderHalfRes else 1
	zoom_modification = float($CanvasLayer / SubViewportContainer.stretch_shrink)
	Data.listen(self, "options.changed")
	Network.client_ready.connect(on_client_ready)
	Network.peer_disconnected.connect(on_peer_disconnected)

func on_client_ready(peer_id: int) -> void :
	readiedPeers[peer_id] = true
	if allClientsReady():
		if is_instance_valid(tween):
			tween.kill()
		tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(continueLabel, "modulate:a", 1.0, 1.0)
		networkStartEndAnimation()

func on_peer_disconnected(peer_id: int) -> void :

	readiedPeers.erase(peer_id)

	var keepersToRemove: Array = []
	for lk: LoadoutKeeper in levelStartData.loadout.keepers:
		if lk.peerId == peer_id:
			levelStartData.abandonedKeepers.append(lk.duplicate())
			keepersToRemove.append(lk)

	for lk in keepersToRemove:
		levelStartData.loadout.keepers.erase(lk)

func networkStartEndAnimation(fast: bool = false) -> void :
	playEndAnimation(fast)
	for client_peer_id in readiedPeers.keys():
		playEndAnimation.rpc_id(client_peer_id, fast)

func allClientsReady() -> bool:
	if not generationFinished:
		return false

	for readied in readiedPeers.values():
		if not readied:
			return false

	return true

@rpc("reliable")
func playEndAnimation(fast: bool) -> void :
	if not multiplayer.is_server() and GameWorld.devMode:
		anim.queue("end")
		return

	if fast or GameWorld.devMode:
		end()
	else:
		anim.queue("end")

func propertyChanged(property: String, oldValue, newValue):
	match property:
		"options.changed":
			$CanvasLayer / SubViewportContainer.stretch_shrink = 2 if Options.renderHalfRes else 1
			zoom_modification = float($CanvasLayer / SubViewportContainer.stretch_shrink)

func mainWindowSizeChanged():
	var viewport_size: Vector2 = get_viewport().get_size()
	$CanvasLayer / SubViewportContainer.set_deferred("size", viewport_size)
	var scaling: Vector2 = CONST.BASE_RESOLUTION / viewport_size
	var factor: = 1.0
	if scaling.y > scaling.x:
		factor = scaling.y
	else:
		factor = scaling.x
	viewport_scale_factor = factor
	$CanvasLayer / SubViewportContainer.position = Vector2.ZERO
	$CanvasLayer / SubViewportContainer.scale = Vector2.ONE * factor

func build(data: Array):
	levelStartData = data[0]
	if data.size() > 1:
		restartedRun = data[1]

	for lk in levelStartData.loadout.keepers:
		if readiedPeers.has(lk.peerId) or lk.peerId == 1:
			continue
		readiedPeers[lk.peerId] = false

	GameWorld.prepareLevelStart(levelStartData)
	GameWorld.runTime = levelStartData.runTime

	for client in Network.clients:
		client.start_stage("stages/landing/clientlanding", [Level.loadout.to_bytes(), Level.levelSeed, levelStartData.savegame, levelStartData.runTime])

	if levelStartData.tileDataPresetId:
		levelStartData.tileData = load("res://content/map/data/TileData" + levelStartData.tileDataPresetId + ".tscn").instantiate()

func beforeStart():
	sky.texture = load("res://content/worlds/" + levelStartData.loadout.worldId + "/bg.png")
	find_child("streaks").texture = load("res://content/worlds/" + levelStartData.loadout.worldId + "/clouds.png")

	Style.setPalette(levelStartData.loadout.palette)
	find_child("ContinueLabel").modulate.a = 0.0

	if levelStartData.savegame:
		$CanvasLayer / SubViewportContainer.visible = false

		if multiplayer.is_server():
			fadeOutTime = 0
			generationFinished = true
			networkStartEndAnimation(true)
		else:
			fadeOutTime = 0.1
	else:
		Style.init(sky)
		Style.init(streaks)
		Style.init(falling)
		fadeOutTime = 0.1
		Audio.stopMusic(0.0)

	Keepers.has_initial_keepers_spawned = false

func beforeEnd():
	super.beforeEnd()
	find_child("FallingSound").stop()

func getMapData() -> Dictionary:
	var data: Dictionary = {}
	for i: int in range(levelStartData.tileData.get_layers_count()):
		data[i] = levelStartData.tileData.get("layer_%d/tile_data" % i)

	return data

func generateThreaded(generator: TileDataGenerator, inTeamId: String, inSeedOffset: int):
	generator.init(levelStartData.mapArchetype, Level.levelSeed + inSeedOffset * SEED_OFFEST_MULTIPLIER, inTeamId)
	generator.generate()

func _physics_process(delta):
	if shake:
		streaks.region_rect.position.y += 3000 * delta

	if shake and Engine.get_frames_drawn() % 5 == 0:
		cam_offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		streaks.region_rect.position.x = randi() % 1000
		streaks.scale.x = randi() % 3 + 1

	var lerp_offset = lerp(cam.offset, (cam_offset / zoom_modification), 0.1)
	cam.offset = lerp_offset
	cam.zoom = Vector2.ONE * (cam_zoom / zoom_modification) / viewport_scale_factor

func _process(delta):
	for client in Network.clients:
		if not [Network.ConnectionState.LEVEL_STAGE_MAP_DATA, Network.ConnectionState.LEVEL_STAGE_SPAWN].has(client.connection_state):
			return

	var archetype: MapArchetype = levelStartData.mapArchetype
	timePassed += delta
	if levelStartData.tileData:
		if GameWorld.devMode:
			for keeper in Keepers.getAll():
				Data.apply(keeper.playerId + ".keeper.zoominmine", 4)
			end()
		if timePassed > 1.0 and not generationFinished:
			generationFinished = true
			generate_landmark_data(levelStartData.tileData)
			send_to_clients()
			if allClientsReady():
				if is_instance_valid(tween):
					tween.kill()
				tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tween.tween_property(continueLabel, "modulate:a", 1.0, 1.0)
	else:
		if timePassed > 0.1 and generatorsByThread.is_empty():
			startGenerationThread("team1")
			var independentGenerators: bool = archetype.double_dome_map and not archetype.mirror_double_map
			if independentGenerators:
				startGenerationThread("team2")

	var independentGeneratorsBoundaryMerge: bool = archetype.double_dome_map and not archetype.mirror_double_map
	if independentGeneratorsBoundaryMerge:
		_boundaryMergeCheck()

	for thread in generatorsByThread:
		if not thread.is_alive() and not generationFinished:
			thread.wait_to_finish()
			var generator = generatorsByThread[thread]
			generatorsByThread.erase(thread)
			generator.logReportToOutput()

			if not generator.finishedSuccessful:
				Logger.error("Map generation %s failed, map is Generator Unsuccessful. Trying again." % generator.gen_seed)
				retry_generation(generator.teamId)
				generator.queue_free()
				var invalidateOtherGenerators: bool = archetype.double_dome_map and not archetype.mirror_double_map
				if invalidateOtherGenerators:
					for gen: TileDataGenerator in generatorsByThread.values():
						gen.markAsInvalid()
				return

			if generator.isInvalid():
				Logger.error("Map for: %s with seed: %s is invalid due to other half failure. Trying again." % [generator.teamId, generator.gen_seed])
				retry_generation(generator.teamId)
				generator.queue_free()
				return

			if generator.getMineableTileCount() < 300:
				Logger.error("Map generation %s failed, map is too small. Trying again." % generator.gen_seed)
				retry_generation(generator.teamId)
				generator.queue_free()
				return

			readyGenerators.append(generator)

			var generationDone: bool = generatorsByThread.is_empty()
			if generationDone:
				match readyGenerators.size():
					0:
						Logger.error("No map generation thread running but also generated no map. Aborting.")
						StageManager.startStage("stages/title/title")
					1:
						var success: bool = _finalizeOneGenerator(generator.gen_seed)
						if not success:
							return
					2:
						var success: bool = _finalizeTwoGenerators(generator.gen_seed)
						if not success:
							return
					_:
						Logger.error("Somehow generated too many maps. Unclear what to do with them. Aborting.")
						StageManager.startStage("stages/title/title")
				generationFinished = true
				generate_landmark_data(levelStartData.tileData)
				send_to_clients()
				Logger.info("procedural generation finished")
				if allClientsReady():
					if is_instance_valid(tween):
						tween.kill()
					tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					tween.tween_property(continueLabel, "modulate:a", 1.0, 1.0)

				if GameWorld.devMode:
					networkStartEndAnimation(true)

	if GameWorld.devMode:
		if not generatorsByThread.is_empty() and timePassed > 2:
			if lastWarn < (floor(timePassed)):
				for thread in generatorsByThread:
					Logger.warn("%s: Generator in %s is at stage %s" % [str(lastWarn), str(thread.get_id()), str(generatorsByThread[thread].gen_stage)])
					lastWarn = floor(timePassed)

	if not anim.is_playing() and generationFinished and allClientsReady():
		networkStartEndAnimation()

func _finalizeOneGenerator(inGenSeed: int) -> bool:
	var outSuccess: = true
	var archetype: MapArchetype = levelStartData.mapArchetype
	var team1Generator: TileDataGenerator = readyGenerators.front()
	var mapData: MapData = team1Generator.popTileData()
	var mirrorGenerator: bool = archetype.double_dome_map and archetype.mirror_double_map
	var oneDomeMap: = not mirrorGenerator
	if oneDomeMap:
		levelStartData.tileData = mapData
	elif mirrorGenerator:
		var gen = preload("res://content/map/generation/TileDataGenerator.tscn").instantiate()
		gen.a = archetype
		_team2MapOffset = TileDataGenerator.calculate_map_offset(team1Generator, team1Generator)
		levelStartData.tileData = gen.merge_tiledata(mapData, null, _team2MapOffset)
		gen.queue_free()
		var generationSuccessfull: bool = is_instance_valid(levelStartData.tileData)
		if not generationSuccessfull:
			Logger.error("Map generation %s failed, merge of maps was not successfull. Trying again." % inGenSeed)
			mapData.queue_free()
			for readyGenerator: TileDataGenerator in readyGenerators:
				readyGenerator.queue_free()
			readyGenerators.clear()
			retry_generation("team1")
			outSuccess = false
	return outSuccess

func _finalizeTwoGenerators(inGenSeed: int) -> bool:
	var outSuccess: bool = true
	var archetype: MapArchetype = levelStartData.mapArchetype
	assert (archetype.double_dome_map, "I have two generators but I should not try to merge two maps!")
	assert ( not archetype.mirror_double_map, "I have two generators in mirror mode!")
	var team1_generator: TileDataGenerator = readyGenerators[0] if readyGenerators[0].teamId == "team1" else readyGenerators[1]
	var idx0TileData: MapData = readyGenerators[0].popTileData()
	var idx1TileData: MapData = readyGenerators[1].popTileData()
	var team1_mapdata = idx0TileData if idx0TileData.teamId == "team1" else idx1TileData
	var team2_mapdata = idx1TileData if idx1TileData.teamId == "team2" else idx0TileData
	var gen = preload("res://content/map/generation/TileDataGenerator.tscn").instantiate()
	gen.a = team1_generator.a
	levelStartData.tileData = gen.merge_tiledata(team1_mapdata, team2_mapdata, _team2MapOffset)
	gen.queue_free()
	var invalidateGenerationForBothTeams: bool = not levelStartData.tileData
	if invalidateGenerationForBothTeams:
		Logger.error("Map generation %s failed, merge of maps was not successfull. Trying again." % inGenSeed)
		for readyGenerator: TileDataGenerator in readyGenerators:
			readyGenerator.queue_free()
		readyGenerators.clear()
		retry_generation("team1")
		retry_generation("team2")
		outSuccess = false
	return outSuccess

func _boundaryMergeCheck() -> void :
	var generatorsWaitingForBoundariesMerge: Array = []
	for thread: Thread in generatorsByThread:
		if not thread.is_alive():
			continue
		var generator: TileDataGenerator = generatorsByThread[thread]
		if generator.isWaitingForBoundariesMerge():
			generatorsWaitingForBoundariesMerge.append(generator)

	assert (generatorsWaitingForBoundariesMerge.size() < 3, "Only two generators should be processed at once when mapArchetype.double_dome_map")
	var allGeneratorsReadyForBoundariesMerge: bool = generatorsWaitingForBoundariesMerge.size() == 2
	if allGeneratorsReadyForBoundariesMerge:
		var a: = levelStartData.mapArchetype
		var doubleDomeNoMirror: bool = a.double_dome_map and not a.mirror_double_map
		assert (doubleDomeNoMirror, "Im trying to merge two teams map boundaries, but map archetype does not require this")
		var g1: TileDataGenerator = generatorsWaitingForBoundariesMerge.front()
		var g2: TileDataGenerator = generatorsWaitingForBoundariesMerge.back()
		var team1Generator: TileDataGenerator = g1 if g1.teamId == "team1" else g2
		var team2Generator: TileDataGenerator = g2 if g2.teamId == "team2" else g1
		_team2MapOffset = TileDataGenerator.mergeMapBoundaries(team1Generator, team2Generator)
		team1Generator.resumeGenerationAfterBoundariesMerge()
		team2Generator.resumeGenerationAfterBoundariesMerge()

func retry_generation(inTeam: String):
	seed_offset += 1

	if seed_offset >= maximum_map_generation_attemots:
		Logger.error("Map generation failed too many times in a row. Aborting.")
		StageManager.startStage("stages/title/title")
		return
	elif seed_offset >= floor(maximum_map_generation_attemots * 0.8):

		levelStartData.mapArchetype.tileCount = 0

	startGenerationThread(inTeam)

func startGenerationThread(inTeamID: String):
	var generator = preload("res://content/map/generation/TileDataGenerator.tscn").instantiate()
	var thread = Thread.new()
	var status: int = thread.start(generateThreaded.bind(generator, inTeamID, seed_offset))
	if status == Error.OK:
		generatorsByThread[thread] = generator
		seed_offset += 1
	else:
		StageManager.startStage("stages/title/title")

func _input(event):
	if (event is InputEventMouseButton or event is InputEventKey or event is InputEventJoypadButton) and allClientsReady():
		networkStartEndAnimation(true)

func start():
	find_child("FallingSound").startSound()
	levelStage = StageManager.startStageInBackground("stages/level/level")
	if not Network.is_offline_mode():
		timeoutTimer.wait_time = Network.TIMEOUT if not GameWorld.devMode else Network.TIMEOUT_DEV
		timeoutTimer.timeout.connect(_on_timeout)
		timeoutTimer.start()

func _on_timeout() -> void :
	Network.display_error("TIMED OUT", "multiplayer.error.timeout")

func start_shaking():
	shake = true

func generate_landmark_data(tileData) -> void :
	var archetype: MapArchetype = levelStartData.mapArchetype
	levelStartData.chamberPlacements = Map.generateChamberPlacements(tileData)
	levelStartData.biomes = Map.generateBiomes()
	var generateCaves: bool = not archetype.double_dome_map
	if generateCaves:
		levelStartData.cavePlacements = Map.generateCaves(tileData, levelStartData.biomes)

func send_to_clients() -> void :
	for client in Network.clients:
		client.set_map_data(getMapData())
		client.set_upgrade_data(GameWorld.getUpgradeData())
		client.set_landmark_data(levelStartData.biomes, levelStartData.chamberPlacements, levelStartData.cavePlacements)

func end():
	if generationFinished and not ending:

		ending = true

		if GameWorld.devMode:
			ResourceSaver.save(levelStartData.tileData.pack(), "res://content/map/data/TileDataGenerated.tscn")



		if is_instance_valid(levelStage):
			StageManager.activateStage(levelStage, [levelStartData, restartedRun])
		else:
			StageManager.startStage("stages/level/level", [levelStartData, restartedRun])
		set_process(false)
