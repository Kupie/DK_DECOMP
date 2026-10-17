extends Stage
class_name LevelStage

enum PopupCanvas{GLOBAL, PLAYER_UI, PLAYER_WORLD}

signal revealed
signal level_built
signal offersGenerated(playerId: String, offers: Array[Dictionary], rerollPossible: bool, rerollCost: int, freeRerolls: int)
signal clientOfferSelectionChanged
signal clientPingOffer(offerId: String, playerId: String)
signal viewportsInitialized

var inPauseMenu: Array[int] = []
var pausedDeviceId: = -1
var pausedByPlayer: = false
var keeperInputStarted: = false
var shouldPlayMusic: = false
var shouldStopMusic: = false
var timeWithoutMusic: = 500.0
var blockMusic: = false
var is_revealed: = false
var is_level_built: = false
var keepers_spawned: = false
var areViewportsInitialized: = false
var showingChoicePopup: = false

var offerQueueByPlayerId: Dictionary = {}
var currentOfferTypeByPlayerId: Dictionary = {}
var currentOffersByPlayerId: Dictionary = {}
var currentGadgetPopupByPlayerId: Dictionary = {}

var inputProcessorsByKeeper: = {}

var saveData: = {}
var isSaveGame: = false


var presentPlayerIds: = []

var MAP

var pause_menu_scene: = load("res://content/pause/PauseMenu.tscn")
@onready var _ping_info = %PingInfo

@export var levelKeeperSpawner: LevelKeeperSpawner
@export var cheats: Cheats

func beforeReady() -> void :
	Lobby.member_added.connect(on_lobby_member_added)
	if Network.is_server():
		Lobby.member_removed.connect(on_lobby_member_removed)
	Lobby.member_device_updated.connect(onLobbyMemberDevicedUpdated)


	levelKeeperSpawner.spawned.connect(on_level_keeper_spawned)
	levelKeeperSpawner.initial_spawned.connect(on_level_keeper_initial_spawned)
	levelKeeperSpawner.keeper_removed.connect(on_level_keeper_removed)
	Keepers.keeper_unregistered.connect(on_keeper_unregistered)

func _ready() -> void :

	fadeInTime = 0.1

	get_viewport().size_changed.connect(mainWindowSizeChanged)
	mainWindowSizeChanged()

	Level.stage = self
	if multiplayer.is_server():
		Network.update_local_connection_state(Network.ConnectionState.LEVEL_STAGE_SPAWN)
	if not Network.is_offline_mode() and Network.is_client():
		Network.ping_read.connect(_on_network_ping_read)
		_ping_info.visible = Options.alwaysShowPing
	else:
		_ping_info.visible = false
	Data.listen(self, "options.changed")


	cheats.visible = false


func _on_network_ping_read(new_ping: int) -> void :
	_ping_info.text = str(new_ping) + "ms"

func mainWindowSizeChanged():
	$ViewportsTracker.set_deferred("size", $Viewports.size)
	$ViewportsTracker.scale = $Viewports.scale

func build(data: Array):
	if data.size() == 0 or not data[0] is LevelStartData:
		Logger.error("invalid LevelStage start data", "LevelStage.build", data)
		return

	Level.stage = self

	var startData: LevelStartData = data[0]
	var restartedRun: = false
	if data.size() > 1:
		restartedRun = data[1]

	MAP = find_child("Map")

	if startData.savegame:
		shouldPlayMusic = true

	isSaveGame = startData.savegame and multiplayer.is_server()
	if not isSaveGame:
		MAP.biomes = startData.biomes
		MAP.chamberPlacements = startData.chamberPlacements
		MAP.cavePlacements = startData.cavePlacements
	else:
		MAP.biomes = Map.generateBiomes()


	$Viewports.prepareViewportContainers(startData.loadout.keepers)
	areViewportsInitialized = true
	viewportsInitialized.emit()
	$Viewports.hideViewportsContent()

	var entries = startData.tileData.get_entry_coords()
	if entries.size() != startData.loadout.domes.size():
		Logger.error("The amount of domes in the loadout does not match the amount of entry points of the map. Domes: %d. Entry points in map data: %d" % [entries.size(), startData.loadout.domes.size()], "LevelStage.build")
		if startData.loadout.domes.size() > entries.size():
			Logger.error("Ignoring domes that have no entry point.", "LevelStage.build", startData.loadout.domes)
			startData.loadout.domes.resize(entries.size())
	for i in startData.loadout.domes.size():
		var dome = startData.loadout.domes[i]
		var worldScene = Data.worldScene(startData.loadout.worldId).instantiate()
		worldScene.name = dome.teamId + "World"
		worldScene.teamId = dome.teamId
		$Viewports.addElement(worldScene)
		worldScene.position.x = entries[i].x * GameWorld.TILE_SIZE
		Level.worldsByTeamId[dome.teamId] = worldScene

		var monsterManager = preload("res://stages/level/MonsterManager.tscn").instantiate()
		monsterManager.teamId = dome.teamId
		Level.monstersByTeamId[dome.teamId] = monsterManager
		monsterManager.name = "MonsterManager-%s" % dome.teamId
		add_child(monsterManager)

	Level.map = MAP
	MAP.setTileData(startData.tileData)

	for loadoutDome in startData.loadout.domes:
		GameWorld.addUpgrade(loadoutDome.domeId, loadoutDome.teamId)



	if not isSaveGame and not restartedRun:
		Level.loadout.saveKeepersToTemplates(startData.abandonedKeepers)


	if not isSaveGame or restartedRun:
		for lkt: LoadoutKeeper in Level.loadout.keeperTemplates:
			lkt.position = getRandomKeeperStartPosition(lkt.teamId, lkt.keeperId)
			for keeper: LoadoutKeeper in Level.loadout.keepers:
				if keeper.playerId == lkt.playerId:
					keeper.position = lkt.position

	for lk: LoadoutKeeper in Level.loadout.keeperTemplates:
		if isSaveGame and not startData.savedDataPlayerIds.has(lk.playerId):
			continue
		presentPlayerIds.append(lk.playerId)


	if Network.multiplayer_mode == Network.MultiplayerMode.OFFLINE_SINGLEPLAYER:
		Level.loadout.keepers.clear()
		if isSaveGame:

			Lobby.simple_add(-1, 1)
		else:
			var member = Lobby.members[0]
			var lk = Level.loadout.getLoadoutKeeperByPlayerId(Utils.decode_player_id(member.player_id))
			lk.peerId = member.peer_id
			levelKeeperSpawner.spawn_from_bytes(lk.to_bytes())
	elif multiplayer.is_server():
		Level.loadout.keepers.clear()
		for member in Lobby.members:
			var lk = Level.loadout.getLoadoutKeeperByPlayerId(Utils.decode_player_id(member.player_id))
			lk.playerId = Utils.decode_player_id(member.player_id)
			lk.playerName = Utils.get_player_name(lk.playerId, member.peer_id, member.device_id)
			lk.deviceId = member.device_id
			lk.platformId = member.platform_user_id
			lk.platformName = member.platform_id
			lk.playfabId = member.playfab_id
			lk.peerId = member.peer_id
			levelKeeperSpawner.spawn_from_bytes(lk.to_bytes())

	var mode = load("res://content/gamemode/" + startData.loadout.modeId + "/" + startData.loadout.modeId.capitalize() + ".tscn").instantiate()
	add_child(mode)

	Level.mode = mode

	if not Keepers.local.getCount() > 0:
		await Keepers.initial_keepers_spawned

	Audio.updateTrackList()

	Level.viewports = $Viewports




	$Viewports.init()
	for keeper in Keepers.local.getAll():
		if not startData.savegame and not Level.domesByTeamId.size() > 1:
			keeper.goalCameraZoom = 2
			keeper._cameraRef.snapZoomTo(2)
		var vc = $Viewports.getViewportContainer(keeper)
		vc.getPlayerUICanvas().init(keeper)

	Level.initialized = true
	Audio.unmuteSounds()

	MAP.init()
	MAP.addCaves()


	for l in get_tree().get_nodes_in_group("keepers-changed-listener"):
		l.keepers_changed()

	mode.init()

	for loadoutDome: LoadoutDome in startData.loadout.domes:
		if multiplayer.is_server():
			var pid = loadoutDome.petId
			if not isSaveGame and pid != "pet0" and pid != "":
				var dome = Level.domesByTeamId[loadoutDome.teamId]
				dome.addPet(pid)

		var pgid = loadoutDome.primaryGadgetId
		if Data.gadgets.has(pgid):
			GameWorld.addUpgrade(pgid, loadoutDome.teamId)

		for gadgetId in loadoutDome.additionalGadgets:
			var asKeeperGadget: bool = Data.gadgets[gadgetId].get("takeslots", []).has("keepersuit")
			if asKeeperGadget:
				for keeper: Keeper in Keepers.getAllOfTeam(loadoutDome.teamId):
					GameWorld.addUpgrade(keeper.playerId + "." + gadgetId, loadoutDome.teamId)
			else:
				GameWorld.addUpgrade(gadgetId, loadoutDome.teamId)

	cheats.init()

	find_child("EffectHandler").init()

	GameWorld.levelInitialized()

	if not multiplayer.is_server():

		Network.upgrades_set.connect( func():
			for id in GameWorld.boughtUpgrades:
				if not GameWorld.upgrades.has(id):
					continue
				var upgradeData: Dictionary = GameWorld.upgrades[id]
				if upgradeData.get("scenes", {}).keys().has("hud"):

					var teamId: = ""
					if id.contains("player"):
						teamId = Keepers.getKeeper(id.split(".")[0]).teamId
					else:
						teamId = id.split(".")[0]

					var scene = load("res://" + upgradeData.get("scenes", {})["hud"])
					if scene:
						var perPlayer: String
						if id.begins_with("player") and id.find(".") > 0:
							perPlayer = GameWorld.extractPlayerIdFromItemId(id)
						Level.addHudElement(scene, teamId if perPlayer == "" else perPlayer)
	, CONNECT_ONE_SHOT)

	Recorder.startRecording()

	MAP.revealInitialState()

	var mapSpace = Level.map.get_viewport().find_world_2d().space
	for paramId in startData.loadout.globalAreaOverrides:
		PhysicsServer2D.area_set_param(mapSpace, int(paramId), startData.loadout.globalAreaOverrides[paramId])

	Keepers.connect("keepers_changed", updateDifficulty)
	updateDifficulty()

	if GameWorld.devMode or startData.savegame or Level.domesByTeamId.size() > 1:
		onRevealed()
		startKeeperInput()
	else:

		Level.immediateMoveOut()
		var impact = load("res://stages/landing/Impact.tscn").instantiate()
		impact.dome = Level.domesByTeamId.values().front()
		impact.revealed.connect(onRevealed)
		impact.landed.connect(startKeeperInput)
		impact.landed.connect(Level.moveHudIn)
		$Viewports.addElement(impact)

	Platform.connectToOverlayToggled(steam_overlay_toggled)
	StageManager.emit_signal("level_ready")
	if multiplayer.is_server():
		Network.update_local_connection_state(Network.ConnectionState.LEVEL_STAGE_SYNC)


	if multiplayer.is_server():
		for client in Network.clients:
			if client.connection_state == Network.ConnectionState.LEVEL_STAGE_MAP_DATA:
				client.full_data_sync.call_deferred()

	is_level_built = true
	level_built.emit()
	attempt_to_start_sync.call_deferred()

func updateDifficulty():
	if Level.teams.size() == 0:
		push_error("Tried to update difficulty but there were no teams available. Preventing apply.")
		return
	var additionalKeeperCount: = 0.0
	for teamId in Level.teams:
		var keeperCount = Keepers.getAllOfTeam(teamId).size()
		if keeperCount == 0:
			continue
		additionalKeeperCount += keeperCount - 1
		if keeperCount <= 1:
			Data.apply(teamId + ".monsters.strengthmodfromplayercount", 1)
		else:
			match keeperCount:
				2: Data.apply(teamId + ".monsters.strengthmodfromplayercount", 1.6)
				3: Data.apply(teamId + ".monsters.strengthmodfromplayercount", 2.08)
				4: Data.apply(teamId + ".monsters.strengthmodfromplayercount", 2.39)
				5: Data.apply(teamId + ".monsters.strengthmodfromplayercount", 2.57)
				6: Data.apply(teamId + ".monsters.strengthmodfromplayercount", 2.66)
				_: Data.apply(teamId + ".monsters.strengthmodfromplayercount", 2.71)
	additionalKeeperCount /= Level.teams.size()
	var baseHealth = Data.gameProperties.get("map.tilebasehealth", 3)
	var addition = clamp(1.5 * (pow(additionalKeeperCount, 0.4) - 1), 0, 1)
	Data.apply("map.tileBaseHealth", baseHealth + addition)

func onRevealed():
	is_revealed = true
	revealed.emit()

func addDome(dome, teamId: String):
	Level.domesByTeamId[teamId] = dome
	dome.teamId = teamId
	var world = Level.worldsByTeamId[teamId]
	dome.position = world.getDomePosition()

	$Viewports.addElement(dome)
	dome.init()

func addKeeper(keeper):
	$Viewports.addElement(keeper)

func beforeStart():
	GameWorld.setShowMouse(false)
	fadeOutTime = 0.6

	cheats.visible = false

	for teamId in Level.teams:
		Data.listen(self, teamId + ".monsters.wavepresent")
	Data.listen(self, "team1.game.cyclespeed")

	for mm in get_tree().get_nodes_in_group("monster-manager"):
		mm.init()

	Audio.stopMusic()

	Input.connect("joy_connection_changed", Callable(self, "_on_joy_connection_changed"))

	if multiplayer.is_server():
		for client in Network.clients:
			if client.connection_state == Network.ConnectionState.LEVEL_STAGE_SPAWN:
				sendStageSpawnPackets(client.peer_id)

func beforeEnd():
	super.beforeEnd()
	Keepers.keepers_changed.disconnect(updateDifficulty)
	Audio.stopBattleMusic()

	if not GameWorld.won:
		Audio.stopMusic()
	Data.clearListeners()
	Level.deactivateTutorials()
	$Viewports.set_process(false)

	GameWorld.runId = ""
	GameWorld.runTime = 0.0

func end():
	Level.clear()
	Keepers.clear()
	Lobby.member_added.disconnect(on_lobby_member_added)
	Lobby.member_removed.disconnect(on_lobby_member_removed)
	Lobby.member_device_updated.disconnect(onLobbyMemberDevicedUpdated)
	levelKeeperSpawner.spawned.disconnect(on_level_keeper_spawned)
	levelKeeperSpawner.initial_spawned.disconnect(on_level_keeper_initial_spawned)
	levelKeeperSpawner.keeper_removed.disconnect(on_level_keeper_removed)
	Keepers.keeper_unregistered.disconnect(on_keeper_unregistered)

func _notification(what):
	match what:
		MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
			var modeCondition: bool = ( not Level.mode.relicTriggered) if Level.mode is Relichunt else true
			if Options.pauseWhenOutOfFocus\
			and not GameWorld.paused\
			and keeperInputStarted\
			and not GameWorld.gameover\
			and modeCondition:
				openPauseMenu.bind(Keepers.first()).call_deferred()

func _on_joy_connection_changed(device_id, connected):
	if not connected and keeperInputStarted and not GameWorld.paused:
		var keeper: = Keepers.getLocalKeeperByDeviceId(device_id)
		if not is_instance_valid(keeper):
			return
		openPauseMenu(keeper)



func pause(byPlayer: = true):
	if not GameWorld.can_pause_game():
		return

	pausedByPlayer = byPlayer
	GameWorld.pause()
	$Tween.stop_all()
	get_tree().call_group("monster", "pause")

func unpause(byPlayer: = true):
	if byPlayer or not pausedByPlayer:
		pausedByPlayer = false
		GameWorld.unpause()
		$Tween.resume_all()
		get_tree().call_group("monster", "unpause")
		showingChoicePopup = false

func openPauseMenu(keeper: Keeper):
	if pauseMenuOpen or showingChoicePopup:
		return

	pausedDeviceId = keeper.deviceId
	pauseMenuOpen = true
	if not Options.useGamepad(keeper.deviceId):
		GameWorld.setShowMouse(true)
	var i = preload("res://content/pause/PauseInputProcessor.gd").new()
	var deviceId = keeper.deviceId if keeper else -1
	i.deviceId = deviceId
	i.globalInput = true
	i.popup = pause_menu_scene.instantiate()
	i.popup.deviceId = deviceId
	i.blockAllKeys = true

	Level.stage.showPopup(i.popup, keeper, "", LevelStage.PopupCanvas.GLOBAL)
	i.integrate(self)
	i.connect("stopping", i.popup.fadeOut.bind(0.3))
	i.connect("onStop", pauseClosed.bind(keeper.deviceId))
	i.popup.connect("close", i.desintegrate)
	if not pausedByPlayer:
		pause(false)

	if Keepers.isMultiplayer():
		Network.rpc_server(markPauseOpen)
	pauseMenuOpenChanged.emit()

func pauseClosed(deviceId: int):
	if Keepers.isMultiplayer():
		Network.rpc_server(markPauseClosed)

	pauseMenuOpen = false
	unpause(false)

	pauseMenuOpenChanged.emit()

@rpc("reliable", "any_peer")
func markPauseOpen() -> void :
	var peerId: = multiplayer.get_remote_sender_id()
	if peerId == 0:
		peerId = 1
	if not inPauseMenu.has(peerId):
		inPauseMenu.append(peerId)

	checkForGroupPause()

@rpc("reliable", "any_peer")
func markPauseClosed() -> void :
	var peerId: = multiplayer.get_remote_sender_id()
	if peerId == 0:
		peerId = 1
	inPauseMenu.erase(peerId)

	checkForGroupPause()

func checkForGroupPause():
	var all_paused: = true
	var required: = multiplayer.get_peers()
	required.append(1)
	for connected: int in required:
		if not inPauseMenu.has(connected):
			all_paused = false

	if GameWorld.paused and not all_paused:
		Network.rpc_if_state(groupUnpause, Network.ConnectionState.LEVEL_STAGE_SYNC, true)

	if all_paused:
		Network.rpc_if_state(groupPause, Network.ConnectionState.LEVEL_STAGE_SYNC, true)

@rpc("reliable")
func groupPause() -> void :
	GameWorld.pause(true)
	$Tween.stop_all()
	get_tree().call_group("monster", "pause")

@rpc("reliable")
func groupUnpause() -> void :
	GameWorld.unpause()
	$Tween.resume_all()
	get_tree().call_group("monster", "unpause")
	showingChoicePopup = false

func steam_overlay_toggled(active: bool):
	if active and keeperInputStarted and not GameWorld.paused:
		openPauseMenu(Keepers.first())

func _process(delta):
	if GameWorld.devMode and Input.is_action_just_pressed("hide_hud"):
		%LevelCanvas.layer = 1 - %LevelCanvas.layer
		for keeper in Keepers.local.getAll():
			var vc = $Viewports.getViewportContainer(keeper)
			vc.getPlayerUICanvas().layer = 1 - vc.getPlayerUICanvas().layer

	if GameWorld.won or GameWorld.lost:
		return

	var localTeamId: = Utils.get_local_team_id(multiplayer.get_unique_id())

	if localTeamId == "mixed":
		return

	var monstersIn: float = 999.0
	var waveDelay: float = Data.ofOr(localTeamId + ".monsters.wavedelay", 0.0)
	var waveCooldown: float = Data.ofOr(localTeamId + ".monsters.waveCooldown", 0.0)
	monstersIn = min(monstersIn, waveDelay + waveCooldown)
	var timeLimit = Data.ofOr("team1.game.fixedtimelimit", 0)
	if timeLimit > 0:
		monstersIn += timeLimit * 60 - GameWorld.runTime

	var isMusicPlaying: bool = Audio.isMusicPlaying()
	if not isMusicPlaying:
		timeWithoutMusic += delta
	if Keepers.local.oneInsideMine() and not Data.ofOr("map.relictaken", false):
		if shouldPlayMusic and Options.musicVolume > 0.0 and (timeWithoutMusic > 20.0 or Options.cyclesWithoutMusic == 0):
			timeWithoutMusic = 0.0
			Audio.startMusic(GameWorld.currentMusicIndex, 2.0 + randf() * 1.0)
			shouldPlayMusic = false
			GameWorld.currentMusicIndex += 1

		if not shouldStopMusic and (
			blockMusic\
			or not shouldPlayMusic\
			or Data.of(localTeamId + ".monsters.wavepresent")\
			or monstersIn > 40.0\
			or isMusicPlaying):
			shouldPlayMusic = false
			shouldStopMusic = true

	if shouldStopMusic and monstersIn <= 2.0:
		if GameWorld.isUpgradeLimitAvailable(localTeamId + ".hostile"):
			Audio.stopMusic(0, 10.0)
		shouldStopMusic = false

func toggleCheats():
	var qaOnHandheld: bool = Platform.runningOnHandheldDevice() and GameWorld.qaOptions
	if not (GameWorld.devMode or BuildCustomization.has_feature("enable_cheats") or qaOnHandheld):
		return

	cheats.visible = not cheats.visible
	if cheats.visible:
		Audio.sound("gui_cheats")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		GameWorld.setShowMouse(true)
	else:
		Audio.sound("gui_cheats")
		if not GameWorld.showMouse:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

@rpc("reliable")
func startCorruptionChoiceInput(teamId: String, playerId: String):
	var i = preload("res://stages/level/CorruptionChoiceInputProcessor.gd").new()
	i.deviceId = Keepers.getKeeper(playerId).deviceId
	i.popup = preload("res://stages/level/CorruptionChoicePopup.tscn").instantiate()
	i.popup.teamId = teamId
	i.popup.playerId = playerId
	i.teamId = teamId
	i.playerId = playerId

	showPopup(i.popup, Keepers.getKeeper(playerId))
	showingChoicePopup = true

	i.connect("onStop", unpause)
	i.connect("onStop", Network.rpc_server.bind(continueOfferQueue.bind(playerId)))
	i.corruptionSelected.connect(onCorruptionSelected)
	i.integrate(self)
	pause()

func onCorruptionSelected(selectedCorruptionId: String, teamId: String, playerId: String) -> void :
	if Platform.purchased_keeper_dlc()\
	and Keepers.getKeeper(playerId).techId == "keeper3":
		GameWorld.newSkinsToUnlock.append({"keeperId": "keeper3", "skinId": "skin3"})

	Network.rpc_if_state(remoteSelectCorruption.bind(selectedCorruptionId, teamId), Network.ConnectionState.LEVEL_STAGE_SYNC, true)

@rpc("reliable", "any_peer")
func remoteSelectCorruption(selectedCorruptionId: String, teamId: String) -> void :
	if multiplayer.is_server():
		var other_team = "team" + str(3 - int(teamId.substr(4, 1)))
		Data.event(other_team + ".versus.corruption")
		match selectedCorruptionId:
			"bigwave":
				var id = other_team + ".monstermodifiers.onetimewavestrengthmultiplier"
				var old_val = Data.ofOr(id, 1.0)
				Data.apply(id, old_val + 1.0)
			"fastmonsters":
				var id = other_team + ".monstermodifiers.move_speed"
				var old_val = Data.of(id)
				Data.apply(id, old_val + 0.85)
			"fastprojectiles":
				var id = other_team + ".monstermodifiers.projectilespeed"
				var old_val = Data.of(id)
				Data.apply(id, old_val + 0.8)
			"monsterhealth":
				var id = other_team + ".monstermodifiers.health"
				var old_val = Data.of(id)
				Data.apply(id, old_val + 0.8)
			"monsterdamage":
				var id = other_team + ".monstermodifiers.damage"
				var old_val = Data.ofOr(id, 1.0)
				Data.apply(id, old_val + 0.4)
			"stunresistance":
				var id = other_team + ".monstermodifiers.minstunlevel"
				var old_val = Data.ofOr(id, 1.0)
				Data.apply(id, old_val * 0.1)

	var dome = Level.domesByTeamId.get(teamId, null)
	if dome:
		dome.deactivate_relic()

@rpc("reliable")
func startGadgetChoiceInput(teamId: String, playerId: String, offerType: String):
	var i = preload("res://stages/level/GadgetChoiceInputProcessor.gd").new()
	var keeper: Keeper = Keepers.getKeeper(playerId)
	i.deviceId = keeper.deviceId
	i.popup = preload("res://stages/level/GadgetChoicePopup.tscn").instantiate()
	i.popup.droptype = offerType
	i.popup.teamId = teamId
	i.popup.playerId = playerId
	i.popup.inputProcessor = i
	i.teamId = teamId
	i.playerId = playerId
	i.stopWithPredecessor = false
	currentGadgetPopupByPlayerId[playerId] = i.popup
	showPopup(i.popup, keeper)

	if keeper.techId == "keeper3":
		keeper.autoHookHang()

	showingChoicePopup = true

	i.connect("onStop", unpause)
	i.connect("onStop", Network.rpc_server.bind(continueOfferQueue.bind(playerId)))
	i.connect("dropsSelected", onDropsSelected)
	i.connect("gadgetSelected", onGadgetSelected)
	i.integrate(self)
	pause()

func onGagdetConfirmationRequested(id: String, playerId: String, teamId: String) -> void :
	Network.rpc_server(addGadgetUpgrade.bind(id, playerId, teamId))

func queueChoice(offerType: String, teamId: String, playerId: String) -> void :
	GameWorld.incrementRunStat(offerType + "s_returned", teamId)
	if playerId == "":
		playerId = "player1"
	if currentOfferTypeByPlayerId.get(playerId, "") != "":
		if offerQueueByPlayerId.get(playerId, null) == null:
			offerQueueByPlayerId[playerId] = []
		offerQueueByPlayerId[playerId].append([offerType, teamId, playerId])
	else:
		currentOfferTypeByPlayerId[playerId] = offerType
		var keeper: = Keepers.getKeeper(playerId)
		if offerType == CONST.RELIC:
			Network.rpc_or_local(keeper.peerId, Level.stage.startCorruptionChoiceInput.bind(teamId, playerId))
		else:
			Network.rpc_or_local(keeper.peerId, startGadgetChoiceInput.bind(teamId, playerId, currentOfferTypeByPlayerId[playerId]))
			generateOffers(teamId, playerId)

@rpc("reliable", "any_peer")
func rerollOffers(teamId: String, playerId: String) -> void :
	var freeRerollsUsed: int = Data.ofOr(playerId + ".gadgetselection.freerollsused", 0)
	var freeRerolls: int = Data.ofOr(teamId + ".gadgetselection.freererolls", 0) - freeRerollsUsed
	var paidReroll: bool = Data.ofOr(teamId + ".gadgetselection.paidreroll", false)

	if freeRerolls == 0 and paidReroll:
		if Data.ofOr(teamId + ".inventory.water", 0) <= 0:
			return
		Data.changeByInt(teamId + ".inventory.water", -1)
	else:
		Data.apply(playerId + ".gadgetselection.freerollsused", freeRerollsUsed + 1)

	GameWorld.incrementRunStat(currentOfferTypeByPlayerId.get(playerId, "") + "s_rerolled", teamId)
	generateOffers(teamId, playerId)

func generateOffers(teamId: String, playerId: String) -> void :
	var excluded: Array[String] = []
	var newOffers: Array[Dictionary]
	var goalCount: int


	for current in currentOffersByPlayerId.get(playerId, []):
		if not current.has("dropType"):

			excluded.append(current["id"])

	match currentOfferTypeByPlayerId[playerId]:
		CONST.POWERCORE:
			newOffers = GameWorld.generateSupplements(teamId, playerId, excluded)
			goalCount = Data.of(teamId + ".artifacts.supplementChoicesPerArtifact")
		CONST.GADGET:
			newOffers = GameWorld.generateGadgets(teamId, playerId, excluded)
			goalCount = Data.of(teamId + ".artifacts.gadgetChoicesPerArtifact")
		_:
			push_error("Unexpected offer type. Not generating offers.")
			return


	while newOffers.size() < goalCount and excluded.size() > 0:
		var included: String = excluded.pick_random()
		for current in currentOffersByPlayerId.get(playerId, []):
			if current["id"] == included:
				newOffers.append(current)
				break
		excluded.erase(included)

	var freeRerolls: int = Data.ofOr(teamId + ".gadgetselection.freererolls", 0) - Data.ofOr(playerId + ".gadgetselection.freerollsused", 0)
	var paidReroll: bool = Data.ofOr(teamId + ".gadgetselection.paidreroll", false)
	var rerollPossible = (freeRerolls > 0 or paidReroll) and (newOffers.size() + excluded.size()) > goalCount
	match currentOfferTypeByPlayerId[playerId]:
		CONST.POWERCORE:
			rerollPossible = rerollPossible and not GameWorld.useCustomSupplementOrder
		CONST.GADGET:
			rerollPossible = rerollPossible and not GameWorld.useCustomGadgetOrder
	var rerollCost: int = 0 if freeRerolls > 0 else 1


	newOffers.resize(min(goalCount, newOffers.size()))
	currentOffersByPlayerId[playerId] = newOffers


	newOffers.append({
		"id": "shredgadgettocobalt", 
		"dropType": CONST.SAND, 
		"amount": 2
	})

	offersGenerated.emit(playerId, newOffers, rerollPossible, rerollCost, freeRerolls)


	var offerIds: Array[String] = []
	for offer in newOffers:
		if offer["id"] != "shredgadgettocobalt":
			offerIds.append(offer["id"])

	var keeper: = Keepers.getKeeper(playerId)
	Network.rpc_or_local(keeper.peerId, remoteSetOffers.bind(playerId, currentOfferTypeByPlayerId[playerId], offerIds, rerollPossible, rerollCost, freeRerolls))

@rpc("reliable")
func remoteSetOffers(playerId: String, offerType: String, offerIds: Array[String], rerollPossible: bool, rerollCost: int, freeRerolls: int) -> void :
	var currentOffers: Array[Dictionary] = []

	match offerType:
		CONST.POWERCORE:
			for offerId in offerIds:
				var offer: Dictionary = GameWorld.getSupplementOffer(offerId)
				if offer.size():
					currentOffers.append(offer)
		CONST.GADGET:
			for offerId in offerIds:
				var offer: Dictionary = GameWorld.getGadgetOffer(offerId)
				if offer.size():
					currentOffers.append(offer)


	currentOffers.append({
		"id": "shredgadgettocobalt", 
		"dropType": CONST.SAND, 
		"amount": 2
	})

	offersGenerated.emit(playerId, currentOffers, rerollPossible, rerollCost, freeRerolls)

func onGadgetSelected(id: String, offerType: String, playerId: String, teamId: String) -> void :
	Network.rpc_server(addGadgetUpgrade.bind(id, offerType, playerId, teamId))

@rpc("reliable", "any_peer")
func addGadgetUpgrade(id: String, offerType: String, playerId: String, teamId: String):
	var availableIds: Array[String] = GameWorld.getAvailableArtifactIds(offerType, teamId, playerId)
	var senderPeerId = Keepers.getKeeper(playerId).peerId
	if not availableIds.has(id):
		Network.rpc_or_local(senderPeerId, acceptGadgetSelection.bind(false, playerId))
		return

	GameWorld.incrementRunStat(currentOfferTypeByPlayerId.get(playerId, "") + "s_chosen", teamId)
	GameWorld.serverAddUpgrade(id, teamId)

	Network.rpc_or_local(senderPeerId, acceptGadgetSelection.bind(true, playerId))
	for keeper in Keepers.getAllOfTeam(teamId):
		if keeper.playerId == playerId:
			continue
		availableIds = GameWorld.getAvailableArtifactIds(offerType, teamId, keeper.playerId)
		Network.rpc_or_local(keeper.peerId, notifyGadgetSelected.bind(availableIds, playerId, offerType))

@rpc("reliable")
func acceptGadgetSelection(accepted: bool, playerId: String) -> void :
	if not accepted:
		push_warning("Gadget selection for popup not accepted by server.")



		return

	var popup = currentGadgetPopupByPlayerId[playerId]
	popup.inputProcessor.gadgetAcceptedByServer()

@rpc("reliable")
func notifyGadgetSelected(availableIds: Array[String], selectedPlayerdId: String, offerType: String) -> void :
	var teamId = Keepers.getKeeper(selectedPlayerdId).teamId
	for pId in currentGadgetPopupByPlayerId.keys():
		if pId == selectedPlayerdId or Keepers.getKeeper(pId).teamId != teamId or \
		not is_instance_valid(currentGadgetPopupByPlayerId[pId]) or \
		currentGadgetPopupByPlayerId[pId].droptype != offerType:
			continue
		currentGadgetPopupByPlayerId[pId].disableChoicesForSlots(availableIds)

func onDropsSelected(type: String, amount: int, playerId: String, teamId: String) -> void :
	Network.rpc_server(addDropsToDome.bind(type, amount, playerId, teamId))

@rpc("reliable", "any_peer")
func continueOfferQueue(playerId: String) -> void :
	if currentOffersByPlayerId.has(playerId):
		currentOffersByPlayerId[playerId].clear()

	await get_tree().create_timer(0.5).timeout

	var offerQueue = offerQueueByPlayerId.get(playerId, [])
	if offerQueue.size() > 0:
		var offer: Array = offerQueue.pop_front()
		var offerType = offer[0]
		currentOfferTypeByPlayerId[playerId] = offer[0]
		var teamId: String = offer[1]
		var playerid: String = offer[2]
		var keeper: = Keepers.getKeeper(playerid)

		if offerType == CONST.RELIC:
			Network.rpc_or_local(keeper.peerId, Level.stage.startCorruptionChoiceInput.bind(teamId, playerId))
		else:
			Network.rpc_or_local(keeper.peerId, startGadgetChoiceInput.bind(teamId, playerId, offerType))
			generateOffers(teamId, playerid)
	else:
		currentOfferTypeByPlayerId[playerId] = ""

func startBattleInput(keeper: Keeper, station, exitStationOnStop: = false):
	var i = preload("res://content/dome/station/BattleInputProcessor.gd").new()
	i.teamId = keeper.teamId
	i.domeId = Level.domesByTeamId[keeper.teamId].techId
	i.stationIndex = station.getIndex()
	i.popup = preload("res://stages/level/BattlePopup.tscn").instantiate()
	i.popup.init(i.domeId, keeper.teamId, keeper.deviceId)
	Level.stage.showPopup(i.popup, keeper)
	i.popup.moveIn()
	i.deviceId = keeper.deviceId
	i.controlledWeapons = station.getControlledWeapons()
	if exitStationOnStop:
		i.connect("onStop", keeper.exitStation)
		i.connect("onStop", station.exitStation)
	i.integrate(self)
	unpause()




func startKeeperInput():
	if not Keepers.local.getCount() > 0:
		await levelKeeperSpawner.initial_spawned

	for keeper in Keepers.local.getAll():
		var id = keeper.techId.capitalize().replace(" ", "")
		var keeperInputProcessor = load("res://content/keeper/" + id + "InputProcessor.gd").new()
		keeperInputProcessor.keeper = keeper
		keeperInputProcessor.playerId = keeper.playerId
		keeperInputProcessor.deviceId = keeper.deviceId
		keeperInputProcessor.integrate(self)
		inputProcessorsByKeeper[keeper] = keeperInputProcessor

	Level.activateTutorials()




	keeperInputStarted = true

func stopKeeperInput():
	if keeperInputStarted:
		InputSystem.clearProcessors()
		Level.deactivateTutorials()

func startStationInput(keeper: Keeper, station):
	var i = preload("res://content/dome/station/StationInputProcessor.gd").new()
	i.popup = preload("res://stages/level/StationPopup.tscn").instantiate()
	showPopup(i.popup, keeper)
	i.popup.moveIn()
	i.deviceId = keeper.deviceId
	i.keeper = keeper
	i.station = station
	i.integrate(self)
	if station.keeperExitForced.is_connected(_on_station_KeeperExitForced):
		station.keeperExitForced.disconnect(_on_station_KeeperExitForced)
	station.keeperExitForced.connect(_on_station_KeeperExitForced.bind(i))

func _on_station_KeeperExitForced(ip: InputProcessor) -> void :
	ip.handleStop()
	ip.desintegrate()

func startStationAbandonedInput():
	var popup = preload("res://stages/level/AbandonedPopup.tscn").instantiate()
	%LevelCanvas.add_child(popup)

	var ei = preload("res://content/keeper/StationAbandonedInputProcessor.gd").new()
	ei.connect("no_inputs", popup.fadeIn)
	ei.connect("got_input", popup.fadeOut)
	ei.connect("onStop", popup.fadeOut)
	ei.connect("onStop", popup.queue_free)
	ei.integrate(self)

func startUpgradesInput(keeper: Keeper):
	var i = preload("res://stages/level/UpgradesInputProcessor.gd").new()
	i.deviceId = keeper.deviceId
	var techTreePopup = preload("res://content/techtree/TechTreePopup.tscn").instantiate()
	techTreePopup.playerId = keeper.playerId
	techTreePopup.teamId = keeper.teamId
	showPopup(techTreePopup, keeper, "TechtreeContainer")
	i.popup = techTreePopup
	i.connect("buyUpgrade", techTreePopup.buyUpgrade)
	i.integrate(self)

@rpc("reliable", "any_peer")
func addDropsToDome(type: String, amount: int, playerId: String, teamId: String):
	var dome: Dome = Level.domesByTeamId[teamId]
	GameWorld.incrementRunStat(currentOfferTypeByPlayerId.get(playerId, "") + "s_shredded", teamId)
	for _i in range(0, amount):
		Level.drops.network_spawn({
			"type": type, 
			"position": dome.getDropTarget(type).global_position + Vector2(10 - randf() * 30, 10 - randf() * 30), 
			"carriers": [], 
			"team": teamId, 
		})

func onGameLost():
	stopKeeperInput()
	for keeper in Keepers.getAll():
		if keeper.position.y < -16.0:
			keeper.remove()
	Level.moveHudOut()
	Audio.stopBattleMusic()

func playGameLostAnimation() -> float:
	var time: = 0.0
	for cam in get_tree().get_nodes_in_group("cameras"):
		var distance = abs(cam.cameraRestPositionInDome.y - cam.position.y)
		if distance > 10:
			for keeper: Keeper in Keepers.local.getAll():
				var vignette: Vignette = getVignette(keeper)
				vignette.modulateOnPlayerY = false

			$StageTransitionTween.stop_all()
			$StageTransitionTween.remove_all()
			time = max(time, 1.0 + abs(distance) / 500.0)
			$StageTransitionTween.interpolate_property(cam, "position", cam.position, Vector2(cam.cameraRestPositionInDome.x, -75), time, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
			$StageTransitionTween.start()
	return time + 0.2

func hideOverlays() -> void :
	for keeper in Keepers.local.getAll():
		var vc = $Viewports.getViewportContainer(keeper)
		vc.getPlayerUICanvas().overlay.hideOverlay()

func showOverlays() -> void :
	for keeper in Keepers.local.getAll():
		var vc = $Viewports.getViewportContainer(keeper)
		vc.getPlayerUICanvas().overlay.showOverlay()

func startMineView(inStartedByInput: InputEvent = null):
	if not endingPanel:
		return

	if not Data.ofOr("postrun.showmine", false):
		return

	hideOverlays()
	for keeper: Keeper in Keepers.local.getAll():
		var vignette: Vignette = getVignette(keeper)
		vignette.stop()
	endingPanel.visible = false

	var i = preload("res://systems/camera/CameraMineViewInputProcessor.gd").new()
	i.integrate(self)
	i.popup = preload("res://stages/level/MineViewPopup.tscn").instantiate()
	Level.stage.showPopup(i.popup)
	i.popup.moveIn()
	if not i.popup.is_connected("stop_mine_view", Callable(self, "stopMineView")):
		i.popup.connect("stop_mine_view", Callable(self, "stopMineView"))
	i.connect("reveal_resources", Callable(self, "revealAllMap"))
	if is_instance_valid(inStartedByInput):
		i.popup.updateDevice(inStartedByInput)

	var viewports: Viewports = $Viewports
	var firstKeeper: Keeper = Keepers.local.getAll().front()
	if is_instance_valid(firstKeeper):
		viewports.hideAllViewportsExcept(firstKeeper.playerId)

func stopMineView():
	if not endingPanel:
		return

	showOverlays()
	for keeper: Keeper in Keepers.local.getAll():
		var vignette: Vignette = getVignette(keeper)
		vignette.visible = true
	endingPanel.visible = true
	endingPanel.focusMineViewButton()

	var viewports: Viewports = $Viewports
	viewports.showAllViewports()

func revealAllMap():
	var tileData = Level.map.getTileData()
	var map = Level.map.tileData
	var tw = create_tween()
	var tiles: Array = map.get_used_cells(MapData.LAYER_BIOME)

	const COUNT = 40
	for x in tiles.size() / COUNT:
		tw.tween_callback(revealSubset.bind(tiles.slice(x * COUNT, x * COUNT + COUNT))).set_delay(0.05)

func revealSubset(tiles):
	Level.map.tileCoordsToReveal.append_array(tiles)
	Level.map.floodRevealTiles()

func _on_MuteAmbienceButton_pressed():
	AudioServer.set_bus_volume_db(1, -80 if find_child("MuteAmbienceButton").button_pressed else 0)

func _on_MuteAllButton_pressed():
	AudioServer.set_bus_volume_db(0, -80 if find_child("MuteAllButton").button_pressed else 0)

func _on_SwitchModeButton_pressed():
	if ((get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN) or (get_window().mode == Window.MODE_FULLSCREEN)):
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (false) else Window.MODE_WINDOWED
		find_child("SwitchModeButton").text = "fullscreen"
	else:
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (true) else Window.MODE_WINDOWED
		find_child("SwitchModeButton").text = "windowed"

func propertyChanged(property: String, oldValue, newValue):
	var localTeamId: = Utils.get_local_team_id(multiplayer.get_unique_id())
	if property == localTeamId + ".monsters.wavepresent":
		if newValue:
			Audio.startBattleMusic()
			Audio.sound("wavestart")
		else:
			Audio.stopBattleMusic()

			if shouldPlayMusic:
				return

			if GameWorld.musicCountdown <= 0:
				if Options.cyclesWithoutMusic > 0:
					GameWorld.musicCountdown = Options.cyclesWithoutMusic + randi() % Options.cyclesWithoutMusic
				shouldPlayMusic = true
			else:
				GameWorld.musicCountdown -= 1
	elif property == "team1.game.cyclespeed":
		GameWorld.cycleSpeed = 1.0 / float(newValue)
	elif property == "options.changed":
		_ping_info.visible = Options.alwaysShowPing and not multiplayer.is_server() and not Network.is_offline_mode()

var endingPanel
func showEndingPanel(popup):
	Recorder.finishRecording()

	self.endingPanel = popup
	showOverlays()
	endingPanel.visible = false
	%LevelCanvas.add_popup(popup)
	endingPanel.position.y += endingPanel.get_viewport_rect().size.y
	endingPanel.visible = true
	endingPanel.call_deferred("moveIn")

func removeEndingPanel():
	endingPanel.moveOut()
	hideOverlays()
	endingPanel = null

func getVignette(inKeeper: Keeper):
	var viewportContainer: ViewportContainer = $Viewports.getViewportContainerForPlayerID(inKeeper.playerId)
	return viewportContainer.getVignette()

func showPopup(popup, keeper = null, placement: = "", canvasToUse: PopupCanvas = PopupCanvas.PLAYER_UI):
	var canvas

	if keeper and canvasToUse == PopupCanvas.PLAYER_WORLD:
		var c: ViewportContainer = $Viewports.getViewportContainer(keeper)
		canvas = c.getPlayerWorldCanvas()
		var is_valid: bool = is_instance_valid(canvas)
		assert (is_valid, "player %s has no player canvas. Cannot show popup." % keeper.playerId)
		if not is_valid:
			canvas = %LevelCanvas

	elif keeper and canvasToUse == PopupCanvas.PLAYER_UI:
		var c: ViewportContainer = $Viewports.getViewportContainer(keeper)
		canvas = c.getPlayerUICanvas()
		if not canvas:
			assert (false)
			Logger.error("player %s has no player canvas. Cannot show popup." % keeper.playerId, "LevelStage.showPopup")
			canvas = %LevelCanvas
	else:
		canvas = %LevelCanvas

	if placement == "":
		canvas.add_popup(popup)
	else:
		canvas.find_child(placement).add_child(popup)

func hideGUI():
	for pc in get_tree().get_nodes_in_group("player-canvas"):
		pc.hide()

func showGUI():
	for pc in get_tree().get_nodes_in_group("player-canvas"):
		pc.show()

func sendStageSpawnPackets(peer_id: int) -> void :
	if not is_level_built:
		await level_built

	var client: = Network.get_client(peer_id)
	client.full_data_sync()

	var spawnBytes: = PackedByteStream.new()
	spawnBytes.encode_u8(Level.loadout.keepers.size())
	for lk: LoadoutKeeper in Level.loadout.keepers:
		var lkBytes: = lk.to_bytes()
		spawnBytes.encode_u8(lkBytes.size())
		spawnBytes.append_array(lkBytes)

	setStageSpawnData.rpc_id(peer_id, spawnBytes.data)

@rpc("reliable")
func setStageSpawnData(data: PackedByteArray) -> void :


	if not areViewportsInitialized:
		await viewportsInitialized

	levelKeeperSpawner.spawn_initial(data)

func on_lobby_member_added(member: Lobby.Member) -> void :
	var lk: LoadoutKeeper = Level.loadout.getLoadoutKeeperByPlayerId(Utils.decode_player_id(member.player_id))

	lk.playerId = Utils.decode_player_id(member.player_id)
	lk.playerName = Utils.get_player_name(lk.playerId, member.peer_id, member.device_id)
	lk.deviceId = member.device_id
	lk.peerId = member.peer_id

	levelKeeperSpawner.network_spawn(lk.to_bytes())

func on_lobby_member_removed(member: Lobby.Member) -> void :
	levelKeeperSpawner.network_despawn(member.peer_id, member.device_id)

func on_level_keeper_spawned(keeper: Keeper):
	keeper.set_multiplayer_authority(keeper.peerId)
	keeper.init()

func getRandomKeeperStartPosition(teamId: String, techId: String) -> Vector2:
	var position: Vector2 = Level.domesByTeamId[teamId].getKeeperPosition()

	var teamMemberCount: = 0
	for member: Lobby.Member in Lobby.members:
		if member.team_id == Utils.encode_team_id(teamId):
			teamMemberCount += 1

	if techId == "keeper3":
		position.y = -17.0
		position.x += randi_range(0, -7) * 2 if teamMemberCount > 1 else 0.0
	else:
		position += Vector2.ONE.rotated(randf_range( - PI, PI)) * (10.0 if teamMemberCount > 1 else 0.0)
	return position

func on_level_keeper_initial_spawned() -> void :
	keepers_spawned = true

func attempt_to_start_sync() -> void :
	if is_level_built and keepers_spawned and Network.local_connection_state != Network.ConnectionState.LEVEL_STAGE_SYNC:
		Network.update_local_connection_state(Network.ConnectionState.LEVEL_STAGE_SYNC)

func on_level_keeper_removed(keeper: Keeper) -> void :
	Keepers.unregisterKeeper(keeper)

	var local_peer_id = multiplayer.get_unique_id()
	if BuildCustomization.has_feature("drop_player_fix") and keeper.peerId == local_peer_id and keeper.deviceId == 1:



		Lobby.update_device_id.rpc(2, 1)

func on_keeper_unregistered(keeper: Keeper) -> void :

	Level.loadout.saveStateToTemplate(keeper)
	keeper.kill()

	if inputProcessorsByKeeper.has(keeper) and is_instance_valid(inputProcessorsByKeeper[keeper]):
		inputProcessorsByKeeper[keeper].desintegrate()
		inputProcessorsByKeeper[keeper].keeper = null
		inputProcessorsByKeeper.erase(keeper)

func remote_set_upgrade_data(upgrade_data: Dictionary):
	GameWorld.setUpgradeData(upgrade_data)

func updateKeeperDeviceId(keeper: Keeper) -> void :
	if not keeper.is_multiplayer_authority():
		return

	if inputProcessorsByKeeper.has(keeper):
		inputProcessorsByKeeper[keeper].desintegrate()
		inputProcessorsByKeeper[keeper].keeper = null
		inputProcessorsByKeeper.erase(keeper)

	var id = keeper.techId.capitalize().replace(" ", "")
	var keeperInputProcessor = load("res://content/keeper/" + id + "InputProcessor.gd").new()
	keeperInputProcessor.keeper = keeper
	keeperInputProcessor.playerId = keeper.playerId
	keeperInputProcessor.deviceId = keeper.deviceId
	keeperInputProcessor.runningInLoadout = true
	keeperInputProcessor.integrate(self)
	inputProcessorsByKeeper[keeper] = keeperInputProcessor

func onLobbyMemberDevicedUpdated(peer_id: int, old_device_id: int, new_device_id: int) -> void :
	for lk: LoadoutKeeper in Level.loadout.keepers:
		if lk.peerId == peer_id and lk.deviceId == old_device_id:
			lk.deviceId = new_device_id
			lk.keeper.deviceId = new_device_id
			updateKeeperDeviceId(lk.keeper)
			return
