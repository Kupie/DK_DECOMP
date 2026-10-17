extends Stage
class_name MultiplayerLoadoutStage

const LANGUAGE_RELOAD_MARK: = "language_reload"



var _colorPickerCoop: Control
var _actionAdaptive: Control
var _actionKeyboard: Control
var _actionGamepad: Control
var _teamSelectionTeam1: Control
var _teamSelectionTeam2: Control
var _team1Options: Control
var _team2Options: Control
var _startRunChoice: Control
var _startRunChoiceGroup: Control
var _hintContainers: Control
var _visibilityChecker: Node
var _versusModeWinConditions: Node
var _loadoutChoiceZoom1: Node
var _loadoutChoiceZoom2: Node
var _moveReminder: Node
var _HeadlineTeam1: Node
var _HeadlineTeam2: Node
var _AdditionalGadgetContainersTeam1: Node
var _AdditionalGadgetContainersTeam2: Node
var _VersusModifiersBoxTeam1: Node
var _VersusModifiersBoxTeam2: Node
var _DifficultyListTeam1: Node
var _FPS: Node
var _DifficultyContainersRelicHunt: Node
var _DifficultyContainersTeam1: Node
var _DifficultyContainersTeam2: Node
var _PrimaryGadgetContainersTeam1: Node
var _PetListTeam1: Node
var _PetListTeam2: Node
var _DomePositionArea: Node
var _GuildRewardMedalTextureRect: Node
var _ActionKeeperMoveLeft: Node
var _ActionKeeperMoveRight: Node
var _World1: Node
var _ModifiersBox: Node
var _LoadoutChoiceFriendlyMode: Node
var _LoadoutChoiceProMode: Node
var _AvailableBadgesLabel: Node
var _AssignmentRewardsContainer: Node
var _AssignmentsContainer: Node
var _DomeContainersTeam1: Node
var _DomeContainersTeam2: Node
var _PrimaryGadgetContainersTeam2: Node
var _PetContainersTeam1: Node
var _PetContainersTeam2: Node
var _AssignmentLeaderboard: Node
var _AssignmentChoice: Node
var _DomePositionArea1: Node
var _SpacerGameMode: Node
var _BlockGuildReward: Node
var _KeeperSpawnPosition: Node
var _KeeperSpawnPositionInitial: Node
var _UI: Node
var _VersusChoiceIronDelivery: Node
var _FirstCamera: Node
var _ColorPicker: Node
var _Monsters: Node
var _EffectHandler: Node

var loadoutInputProcessor: MultiplayerLoadoutInputProcessor
var inputProcessorsByKeeper: = {}

var initialized: = false
var MAP: Map
var lastStackedTileData: = []
var dugTileCoordinates: = []
var pregeneratedMaps: = {}
var hostPregeneratedMapData: = {}
var visibilityTileShape: RID
var visibilityTileQueue: Array = []
var persistMetaCooldown: = 0.0

var timeInStation: = 0.0
var lastMajorActionTime: = -1000

var neverMovedTime: = 0.0
var neverMovedActivated: = false
var moveHintTween
var is_revealed: = true
var quitting: = false
var pausedDeviceId: = -1
var pausedByPlayer: bool = false
var proModePopupOpen: = false

var pause_menu_scene: = load("res://content/pause/PauseMenu.tscn")
var map_scene: = load("res://content/map/Map.tscn")

var startedRun: = false


var levelStartData: Array

var isReloadingDueLanguageChange: = false


var prev_pioneer_pack_status: = false
var prev_assessor_pack_status: = false
var prev_keeper_dlc_status: = false

var _isGameModeChangeInProgress: bool = false

@export var loadoutKeeperSpawner: LoadoutKeeperSpawner
@export var monsterSynchronizer: MonsterSynchronizer

func _notification(inWhat: int) -> void :
	if inWhat == NOTIFICATION_SCENE_INSTANTIATED:
		_colorPickerCoop = %ColorPickerCoop
		_actionAdaptive = %Action_Adaptive
		_actionKeyboard = %Action_Keyboard
		_actionGamepad = %Action_Gamepad
		_teamSelectionTeam1 = %TeamSelectionTeam1
		_teamSelectionTeam2 = %TeamSelectionTeam2
		_team1Options = %Team1Options
		_team2Options = %Team2Options
		_startRunChoice = %StartRunChoice
		_startRunChoiceGroup = %StartRunChoiceGroup
		_hintContainers = %HintContainers
		_visibilityChecker = %VisibilityChecker
		_versusModeWinConditions = %VersusModeWinConditions
		_loadoutChoiceZoom1 = %LoadoutChoiceZoom1
		_loadoutChoiceZoom2 = %LoadoutChoiceZoom2
		_moveReminder = %MoveReminder
		_HeadlineTeam1 = %HeadlineTeam1
		_HeadlineTeam2 = %HeadlineTeam2
		_AdditionalGadgetContainersTeam1 = %AdditionalGadgetContainersTeam1
		_AdditionalGadgetContainersTeam2 = %AdditionalGadgetContainersTeam2
		_VersusModifiersBoxTeam1 = %VersusModifiersBoxTeam1
		_VersusModifiersBoxTeam2 = %VersusModifiersBoxTeam2
		_DifficultyListTeam1 = %DifficultyListTeam1
		_FPS = %FPS
		_DifficultyContainersRelicHunt = %DifficultyContainersRelicHunt
		_DifficultyContainersTeam1 = %DifficultyContainersTeam1
		_DifficultyContainersTeam2 = %DifficultyContainersTeam2
		_PrimaryGadgetContainersTeam1 = %PrimaryGadgetContainersTeam1
		_PetListTeam1 = %PetListTeam1
		_PetListTeam2 = %PetListTeam2
		_DomePositionArea = %DomePositionArea
		_GuildRewardMedalTextureRect = %GuildRewardMedalTextureRect
		_ActionKeeperMoveLeft = %ActionKeeperMoveLeft
		_ActionKeeperMoveRight = %ActionKeeperMoveRight
		_World1 = %World1
		_ModifiersBox = %ModifiersBox
		_LoadoutChoiceFriendlyMode = %LoadoutChoiceFriendlyMode
		_LoadoutChoiceProMode = %LoadoutChoiceProMode
		_AvailableBadgesLabel = %AvailableBadgesLabel
		_AssignmentRewardsContainer = %AssignmentRewardsContainer
		_AssignmentsContainer = %AssignmentsContainer
		_DomeContainersTeam1 = %DomeContainersTeam1
		_DomeContainersTeam2 = %DomeContainersTeam2
		_PrimaryGadgetContainersTeam2 = %PrimaryGadgetContainersTeam2
		_PetContainersTeam1 = %PetContainersTeam1
		_PetContainersTeam2 = %PetContainersTeam2
		_AssignmentLeaderboard = %AssignmentLeaderboard
		_AssignmentChoice = %AssignmentChoice
		_DomePositionArea1 = %DomePositionArea1
		_SpacerGameMode = %SpacerGameMode
		_BlockGuildReward = %BlockGuildReward
		_KeeperSpawnPosition = %KeeperSpawnPosition
		_KeeperSpawnPositionInitial = %KeeperSpawnPositionInitial
		_UI = %UI
		_VersusChoiceIronDelivery = %VersusChoiceIronDelivery
		_FirstCamera = %FirstCamera
		_ColorPicker = %ColorPicker
		_Monsters = %Monsters
		_EffectHandler = $EffectHandler

func beforeReady():
	monsterSynchronizer.spawned.connect(on_monster_spawned)
	loadoutKeeperSpawner.spawned.connect(on_loadout_keeper_spawned)
	Lobby.member_added.connect(on_lobby_member_added)
	Lobby.member_removed.connect(onLobbyMemberRemoved)
	Lobby.member_color_updated.connect(onLobbyMemberColorUpdated)
	Lobby.member_device_updated.connect(onLobbyMemberDevicedUpdated)
	loadoutKeeperSpawner.keeper_removed.connect(onRemoveKeeper)
	loadoutKeeperSpawner.keeper_replaced.connect(onKeeperReplaced)
	loadoutKeeperSpawner.spawned.connect(onKeeperSpawned)
	Keepers.keeper_unregistered.connect(onKeeperUnregistered)


	visibilityTileShape = PhysicsServer2D.rectangle_shape_create()
	PhysicsServer2D.shape_set_data(visibilityTileShape, GameWorld.TILE_SIZE * 0.5 * Vector2.ONE)

	Audio.muteSoundAndUI()
	_EffectHandler.init()
	MAP = %Map
	Level.teams.clear()
	Level.teams.append("team1")
	GameWorld.prepareCleanData()

	Level.stage = self
	Level.viewports = self
	Level.monstersByTeamId["team1"] = preload("res://stages/loadout/MonstersMock.gd").new()
	Level.monstersByTeamId["team1"].monsterSynchronizer = monsterSynchronizer
	Level.worldsByTeamId["team1"] = _World1

	Style.additionalPalettes.clear()
	Style.setPalette("palette_1_1")
	Style.init(find_child("ChoiceHintContainer", true, false))
	Style.init(_GuildRewardMedalTextureRect)
	Style.init(_ActionKeeperMoveLeft)
	Style.init(_ActionKeeperMoveRight)

	GameWorld.setShowMouse(false)

	find_child("BlockPrestigeLoadout", true, false).visible = false
	find_child("BlockRelicHuntLoadout", true, false).visible = false
	find_child("BlockVersusLoadout", true, false).visible = false
	find_child("BlockAssignmentsLoadout", true, false).visible = false

	var s = tr("loadout.controls.pickoption")
	var parts = s.split("|")
	if parts.size() == 2:
		find_child("LabelPickOption1", true, false).text = parts[0]
		find_child("LabelPickOption2", true, false).text = parts[1]

	Data.apply("map.tileHealthMultiplierPerLayer", 1)

	_DomePositionArea.body_entered.connect(onPlayerEnterDomeArea)
	_DomePositionArea.body_exited.connect(onPlayerExitDomeArea)

	if BuildCustomization.has_feature("dlc_poll"):
		prev_pioneer_pack_status = Platform.purchased_pioneer_pack()
		prev_assessor_pack_status = Platform.purchased_assessor_booster()
		prev_keeper_dlc_status = Platform.purchased_keeper_dlc()
		GameWorld.update_pioneer_pack(prev_pioneer_pack_status)
		GameWorld.update_assessor_booster(prev_assessor_pack_status)
		GameWorld.update_keeper_dlc(prev_keeper_dlc_status)

	if GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
		Network.multiplayer_mode = Network.MultiplayerMode.OFFLINE_SPLITSCREEN

func onPlayerEnterDomeArea(x):
	pass

func onPlayerExitDomeArea(x):
	pass

func build(data: Array):
	get_viewport().size_changed.connect(mainWindowSizeChanged)
	mainWindowSizeChanged()
	if not multiplayer.is_server() and data.size() > 1:
		levelStartData = data

		Level.loadout = Loadout.from_bytes(data[0], false)
		hostPregeneratedMapData = data[1]
		Level.setSeed(data[2])
		GameWorld.unlocks.deserialize(data[3])
		setTeamSelection(data[4])

		GameWorld.devMode = data[5]
		if GameWorld.devMode:
			GameWorld.devModeActivated = true

	isReloadingDueLanguageChange = data.find(LANGUAGE_RELOAD_MARK) > -1

	Level.viewports = $Viewports
	$Viewports.init()

	if multiplayer.is_server():
		if Level.loadout.modeId == CONST.MODE_VERSUS:
			var team1ColorId: = "color0"
			var team2ColorId: = "color1"
			for member in Lobby.members:
				match member.team_id:
					1:
						team1ColorId = "color%d" % member.color_id
					2:
						team2ColorId = "color%d" % member.color_id

			_teamSelectionTeam1.updateColorSelection(team1ColorId)
			_teamSelectionTeam2.updateColorSelection(team2ColorId)
		else:
			_teamSelectionTeam1.updateColorSelection("color0")
			_teamSelectionTeam2.updateColorSelection("color1")

	Level.loadout.keepers.clear()
	if multiplayer.is_server():
		for member in Lobby.members:
			spawn_existing_member(member)

	loadoutInputProcessor = MultiplayerLoadoutInputProcessor.new()
	if GameWorld.isSplitScreen():
		loadoutInputProcessor.new_device_detected.connect(addNewDevice)
		loadoutInputProcessor.joystick_disconnected.connect(onDeviceDisconnected)
	else:
		if multiplayer.is_server():
			addNewDevice(-1)
	loadoutInputProcessor.integrate(self)

	Level.map = MAP
	MAP.biomes = Map.generateBiomes()
	MAP.setTileData(preload("res://stages/loadout/TileDataStartArea.tscn").instantiate())
	MAP.init(false, false)
	for coord in MAP.getTileData().get_mineable_tile_coords():
		MAP.addTileDestroyedListener(self, coord)
	pregeneratedMaps[[]] = MAP

	Audio.startIntro()

	_PrimaryGadgetContainersTeam1.visible = false
	_PetListTeam1.visible = false
	_PetListTeam2.visible = false
	_colorPickerCoop.visible = false
	_AdditionalGadgetContainersTeam1.visible = false

	GameWorld.prepareUnlockables()
	fillKeepers()
	fillGameModes()
	fillDomes()
	fillPrimaryGadgets()
	fillPets()
	fillDifficulties()
	fillMapSizes()
	setLoadout(Level.loadout)
	_VersusChoiceIronDelivery.setDescription(tr("loadout.versus.condition.irondelivery.desc") % str(CONST.VERSUS_IRONDELIVERY_WIN))

	GameWorld.levelInitialized()
	initialized = true

	if is_multiplayer_authority():
		Data.apply("team1.dome.autohealdamagethreshold", 400)
		Data.apply("team1.dome.autohealamount", 1000)
	_UI.visible = GameWorld.getFiguredOutMovementInLoadout()

	_moveReminder.modulate = Color(0, 0, 0, 0)
	var spawnPosition
	if GameWorld.getFiguredOutMovementInLoadout():
		_UI.visible = true
		spawnPosition = _KeeperSpawnPosition.position
	else:
		_UI.visible = false
		moveHintTween = create_tween()
		moveHintTween.tween_interval(2.8)
		moveHintTween.tween_property(_moveReminder, "modulate", Color.WHITE, 0.5)
		spawnPosition = _KeeperSpawnPositionInitial.position

	MAP.revealInitialState(MAP.getTileCoord(spawnPosition))
	MAP.addTileRevealedListener(self, Vector2(0, 5))

	_FirstCamera.position = spawnPosition
	updateBlockVisibility(true)

	if GameWorld.goalCameraZoomLoadout == 3:
		_loadoutChoiceZoom1.selected = false
		_loadoutChoiceZoom2.selected = true
	else:
		_loadoutChoiceZoom1.selected = true
		_loadoutChoiceZoom2.selected = false

	_FirstCamera.zoom = GameWorld.getEffectiveLoadoutZoom() * Vector2.ONE

	if multiplayer.is_server():
		_AssignmentChoice.challengeModeSelected.connect(updateClientLoadout)
		_LoadoutChoiceFriendlyMode.toggled.connect( func(_toggled): updateClientLoadout())
		_ModifiersBox.modifiersUpdated.connect(updateClientLoadout)
		_VersusModifiersBoxTeam1.modifiersUpdated.connect(updateClientLoadout)
		_VersusModifiersBoxTeam2.modifiersUpdated.connect(updateClientLoadout)
	else:
		_AssignmentChoice.challengeModeSelected.connect(clientSelectChallengeMode)
		_ModifiersBox.modifiersUpdated.connect(clientModifiersUpdated)
		_VersusModifiersBoxTeam1.modifiersUpdated.connect(clientVersusModifiersUpdated.bind("team1"))
		_VersusModifiersBoxTeam2.modifiersUpdated.connect(clientVersusModifiersUpdated.bind("team2"))

	_AssignmentChoice.playSound.connect(networkPlayAssignmentDisplaySound)
	_ModifiersBox.playSound.connect(networkSound)
	_VersusModifiersBoxTeam1.playSound.connect(networkSound)
	_VersusModifiersBoxTeam2.playSound.connect(networkSound)
	_teamSelectionTeam1.playSound.connect(networkSound)
	_teamSelectionTeam2.playSound.connect(networkSound)
	_ColorPicker.playSound.connect(networkSound)


	_startRunChoice.visible = not isMultiplayerMode()
	if not _startRunChoice.visible:
		_startRunChoice.queue_free()
	_startRunChoiceGroup.visible = isMultiplayerMode()
	if not _startRunChoiceGroup.visible:
		_startRunChoiceGroup.queue_free()
	updateStartRunButton()


	if not isReloadingDueLanguageChange:
		if multiplayer.is_server():
			for client in Network.clients:
				client.start_stage("stages/loadout/multiplayerloadout", [
					Level.loadout.to_bytes(), 
					serializePreGeneratedMaps(), 
					Level.levelSeed, 
					GameWorld.unlocks.serialize(), 
					getTeamSelections(), 
					GameWorld.devMode
				])
		elif not GameWorld.isSplitScreen() and Lobby.local_member_count() == 0:
			Lobby.simple_add(-1)
	isReloadingDueLanguageChange = false

	update_keeper4_entrance_hole_visibility()

	GameWorld.unlocks.updated.connect(onUnlocksUpdated)

func clientSelectChallengeMode() -> void :
	Network.rpc_server(setServerChallengeMode.bind(_AssignmentChoice.isChallengeMode))

@rpc("reliable", "any_peer")
func setServerChallengeMode(isChallengeMode: bool) -> void :
	_AssignmentChoice.setChallengeMode(isChallengeMode)

func networkPlayAssignmentDisplaySound(isChallengeMode: bool) -> void :
	Network.rpc_if_state(playAssignmentDisplaySound.bind(isChallengeMode), Network.ConnectionState.LOADOUT_STAGE_SYNC, true)

@rpc("reliable", "any_peer")
func playAssignmentDisplaySound(isChallengeMode: bool) -> void :
	if isChallengeMode:
		_AssignmentChoice.playChallengeSound()
	else:
		_AssignmentChoice.playRegularSound()

func clientModifiersUpdated() -> void :
	var modifiers: Array = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_WORLDMODIFIERS, [])
	Network.rpc_server(serverModifiersUpdated.bind(modifiers))

@rpc("reliable", "any_peer")
func serverModifiersUpdated(modifiers: Array) -> void :
	Level.loadout.modeConfig[CONST.MODE_CONFIG_WORLDMODIFIERS] = modifiers
	_ModifiersBox.updateModifierLabels()
	updateClientLoadout()

func clientVersusModifiersUpdated(teamId: String) -> void :
	var modifiers: Array = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_VERSUSMODIFIERS + teamId, [])
	Network.rpc_server(serverVersusModifiersUpdated.bind(teamId, modifiers))

@rpc("reliable", "any_peer")
func serverVersusModifiersUpdated(teamId: String, modifiers: Array) -> void :
	Level.loadout.modeConfig[CONST.MODE_CONFIG_VERSUSMODIFIERS + teamId] = modifiers
	match teamId:
		"team1":
			_VersusModifiersBoxTeam1.updateModifierLabels()
		"team2":
			_VersusModifiersBoxTeam2.updateModifierLabels()

	updateClientLoadout()


func tileRevealed(coord):
	if GameWorld.getFiguredOutMovementInLoadout():
		return
	GameWorld.figuredOutMovementInLoadout = true
	if moveHintTween:
		moveHintTween.kill()
	moveHintTween = create_tween()
	moveHintTween.tween_property(_moveReminder, "modulate", Color(1, 1, 1, 0), 0.5)
	_UI.visible = true
	updateBlockVisibility()

func beforeStart():
	$Tween.interpolate_callback(Audio, 0.1, "unmuteSoundAndUI")
	$Tween.start()
	Network.update_local_connection_state(Network.ConnectionState.LOADOUT_STAGE_SPAWN)
	if multiplayer.is_server():
		Network.update_local_connection_state(Network.ConnectionState.LOADOUT_STAGE_SYNC)
	else:
		loadoutKeeperSpawner.initial_spawned.connect(onInitialKeepersSpawned)

	add_to_group("gamepadListeners")

func onInputMethodChanged():
	updateDeviceHints()

func onInitialKeepersSpawned():
	Network.update_local_connection_state(Network.ConnectionState.LOADOUT_STAGE_SYNC)

func beforeEnd():
	super.beforeEnd()
	if loadoutKeeperSpawner.initial_spawned.is_connected(onInitialKeepersSpawned):
		loadoutKeeperSpawner.initial_spawned.disconnect(onInitialKeepersSpawned)

	for k in Keepers.getAll():
		k.kill()

	Data.clearListeners()
	Keepers.clear()

	GameWorld.runId = ""
	GameWorld.runTime = 0.0

func end():
	loadoutKeeperSpawner.spawned.disconnect(on_loadout_keeper_spawned)
	Lobby.member_added.disconnect(on_lobby_member_added)
	Lobby.member_removed.disconnect(onLobbyMemberRemoved)
	Lobby.member_color_updated.disconnect(onLobbyMemberColorUpdated)
	Lobby.member_device_updated.disconnect(onLobbyMemberDevicedUpdated)
	loadoutKeeperSpawner.keeper_removed.disconnect(onRemoveKeeper)
	Keepers.keeper_unregistered.disconnect(onKeeperUnregistered)
	Level.clear()

func addElement(e):
	$Viewports.addElement(e)

func pause(byPlayer: = true):
	if Keepers.isMultiplayer():
		return
	pausedByPlayer = byPlayer
	GameWorld.pause()
	get_tree().call_group("monster", "pause")

func unpause(byPlayer: = true):
	GameWorld.unpause()
	get_tree().call_group("monster", "unpause")

func openPauseMenu(keeper: Keeper):
	if pauseMenuOpen:
		return

	pausedDeviceId = keeper.deviceId
	pauseMenuOpen = true
	if not Options.useGamepad(keeper.deviceId):
		GameWorld.setShowMouse(true)
	var i = preload("res://content/pause/PauseInputProcessor.gd").new()
	i.name = "PauseInputProcessor"
	i.deviceId = keeper.deviceId
	i.popup = pause_menu_scene.instantiate()
	i.popup.deviceId = keeper.deviceId
	i.popup.saveOnQuit = false
	i.globalInput = true
	i.blockAllKeys = true
	add_child(i.popup)
	i.integrate(self)
	i.connect("stopping", i.popup.fadeOut.bind(0.3))
	i.connect("onStop", pauseClosed.bind(keeper.deviceId))
	i.popup.connect("close", i.desintegrate)
	pause()
	pauseMenuOpenChanged.emit()

func pauseClosed(deviceId: int):
	pauseMenuOpen = false
	unpause(false)
	pauseMenuOpenChanged.emit()

func toggleCheats():
	pass

func _process(delta):
	if BuildCustomization.has_feature("dlc_poll"):
		_update_packs()

	if (GameWorld.devMode or BuildCustomization.has_feature("enable_cheats")) and Keepers.hasKeeper("player1"):
		_FPS.text = "%.2f (%.2f) [%.2f] %d - %s" % [Engine.get_frames_per_second(), 1.0 / delta, Keepers.getKeeper("player1").synchronizer._tps, Network.tick_count, GameWorld.version]

	_isGameModeChangeInProgress = false


	updateAllHintContainerPositions()
	var c1 = find_child("GameModeMarginContainer", true, false)
	var c2 = find_child("GameModeContainers", true, false)
	var diffX = 40 + c2.size.x - c1.size.x
	var marginLeft = c1.get("theme_override_constants/margin_left")
	c1.set("theme_override_constants/margin_left", marginLeft + diffX)

	for keeper in Keepers.local.getAll():
		var ua = keeper.find_child("UseArea")
		if keeper.position.y < 0:
			ua.get_child(0).shape.radius = 22.0
		else:
			ua.get_child(0).shape.radius = 1.0

	if Keepers.oneInsideStation() and multiplayer.is_server():
		timeInStation += delta
		if timeInStation > 4.0:
			if get_tree().get_nodes_in_group("team1-monster").size() < 3:
				var monsterType: = Monster.Type.WALKER if randf() > 0.3 else Monster.Type.FLYER
				var variant: = "left" if randf() > 0.5 else "right"

				var buffer: PackedByteArray
				match monsterType:
					Monster.Type.WALKER:
						buffer = Walker.get_spawn_data(variant, "team1")
					Monster.Type.FLYER:
						buffer = Flyer.get_spawn_data(variant, "team1")

				monsterSynchronizer.network_spawn(monsterType, buffer, "team1")
				timeInStation = 0.0
	else:
		timeInStation = 0.0

	if Options.visibleMonsters:
		for m in get_tree().get_nodes_in_group("team1-monster"):
			m.aim(true)

	if persistMetaCooldown > 0.0:
		persistMetaCooldown -= delta
		if persistMetaCooldown <= 0.0:
			SaveGame.saveRollingMetaState()


func _update_packs():
	var needs_update = false
	var pioneer_pack_status = Platform.purchased_pioneer_pack()
	if pioneer_pack_status != prev_pioneer_pack_status:
		GameWorld.update_pioneer_pack(pioneer_pack_status)
		prev_pioneer_pack_status = pioneer_pack_status
		needs_update = true

	var assessor_pack_status = Platform.purchased_assessor_booster()
	if assessor_pack_status != prev_assessor_pack_status:
		GameWorld.update_assessor_booster(assessor_pack_status)
		prev_assessor_pack_status = assessor_pack_status
		needs_update = true

	var keeper_dlc_status = Platform.purchased_keeper_dlc()
	if keeper_dlc_status != prev_keeper_dlc_status:
		GameWorld.update_keeper_dlc(keeper_dlc_status)
		prev_keeper_dlc_status = keeper_dlc_status
		needs_update = true


	if needs_update:
		onLocaleChanged()

func on_monster_spawned(monster: Monster):
	monster.synchronizer = monsterSynchronizer
	_Monsters.add_child(monster)

func onLoadoutChoiceSelected(callback: Callable):
	Network.rpc_if_state(_cleanBeforeModeChange, Network.ConnectionState.LOADOUT_STAGE_SYNC, true)
	Network.rpc_server(callback)

@rpc("reliable", "any_peer")
func _cleanBeforeModeChange() -> void :
	for monster in get_tree().get_nodes_in_group("team1-monster"):
		monster.die()
		monster.removeFreeBlocker()
		monster.removeFreeBlocker()
	for projectile in get_tree().get_nodes_in_group("projectile"):
		projectile.deactivate()

func networkSound(id: String, teamId: = "") -> void :
	Network.rpc_if_state(sound.bind(id, teamId), Network.ConnectionState.LOADOUT_STAGE_SYNC, true)

@rpc("reliable", "any_peer")
func sound(id: String, teamId: = "") -> void :
	if teamId != "":
		var localTeams: = Utils.get_local_teams(multiplayer.get_unique_id())
		if not localTeams.has(teamId):
			return
	Audio.sound(id)

func fillKeepers(reload: bool = false):
	var kc = find_child("KeeperContainers")
	if reload:
		for child in kc.get_children():
			child.queue_free()

	for id in Data.loadoutKeepers:
		var box = VBoxContainer.new()
		box.set("theme_override_constants/separation", 10)
		var label = Label.new()
		label.label_settings = preload("res://gui/fontsettings/LargeFontSettings.tres")
		label.text = tr("upgrades." + id + ".title")
		label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		box.add_child(label)
		label = Label.new()
		label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AutowrapMode.AUTOWRAP_WORD_SMART
		label.label_settings = preload("res://gui/fontsettings/SmallFontSettings.tres")
		label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if GameWorld.unlocks.is_unlocked(id):
			label.text = tr("upgrades." + id + ".desc")
		elif id == "keeper3" or id == "keeper4":
			if multiplayer.is_server():
				label.text = tr("unlock.buy.keeperdlc") % tr("keeperdlc.title")
				var element = VBoxContainer.new()
				element.add_child(label)
				var choice = preload("res://stages/loadout/LoadoutChoice.tscn").instantiate()
				choice.titleLocId = "keeperdlc.title"
				choice.select.connect(Platform.open_keeper_dlc_in_store)
				element.add_child(choice)
				label = element
			else:
				label.text = tr("unlock.host.locked") % tr("keeperdlc.title")

		else:
			label.text = tr("unlock.generic")
		box.add_child(label)

		var grid: = GridContainer.new()
		box.add_child(grid)

		var skins = GameWorld.unlocks.get_unlocked_skins().get(id, [])
		if not skins.has("skin0"):
			skins.insert(0, "skin0")
		for skinId in skins:
			var skinSpritePath: String = "res://content/keeper/" + id + "/spriteframes-" + skinId + "-color0.tres"
			if not ResourceLoader.exists(skinSpritePath):
				continue
			var image = load("res://content/icons/loadout_" + id + "-" + skinId + ".png")
			var e = preload("res://stages/loadout/KeeperChoice.tscn").instantiate()
			e.connect("select", networkChangeKeeper.bind(id + "-" + skinId))
			e.setChoice(id + "-" + skinId, image)
			e.set_enabled(GameWorld.unlocks.is_unlocked(id))
			grid.add_child(e)

		if skins.size() > 4:
			grid.columns = 3
		else:
			grid.columns = 4

		if grid.get_child_count() > 0:
			kc.add_child(box)
		else:
			box.free()

func fillGameModes():
	var container = find_child("GameModeContainers")
	for id in Data.loadoutGameModes:
		if not isMultiplayerMode() and id == CONST.MODE_VERSUS:
			continue
		var image = load("res://content/icons/loadout_" + id + ".png")
		var e = preload("res://stages/loadout/LoadoutChoice.tscn").instantiate()
		e.hostOnly = true
		if GameWorld.unlocks.is_unlocked(id):
			e.setChoice("upgrades." + id + ".title", id, image, "upgrades." + id + ".desc")
		else:
			e.setChoice("upgrades." + id + ".title", id, image, "unlock.generic")
			e.set_enabled(false)
		container.add_child(e)
		e.select.connect(onLoadoutChoiceSelected.bind(gameModeSelected.bind(id)))

	container = find_child("PrestigeModeVariantContainer")
	for id in Data.loadoutPrestigeModeVariants:

		var e = preload("res://stages/loadout/LoadoutChoice.tscn").instantiate()
		var modePrefix = "loadout." + id.replace("-", ".")
		if GameWorld.unlocks.is_unlocked(id):
			e.setChoice(modePrefix, id, null, modePrefix + ".description")
		else:
			e.setChoice(modePrefix, id, null, "unlock.generic")
			e.set_enabled(false)
		container.add_child(e)
		e.select.connect(onLoadoutChoiceSelected.bind(prestigeModeVariantSelected.bind(id)))
	if not GameWorld.unlocks.is_unlocked(CONST.MODE_PRESTIGE_PRO):
		_LoadoutChoiceProMode.setDescription(tr("unlock.prestige.promode"))
		_LoadoutChoiceProMode.set_enabled(false)

	if Level.loadout.modeConfig.has(CONST.MODE_CONFIG_PRESTIGE_VARIANT):
		prestigeModeVariantSelected(Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT, CONST.MODE_PRESTIGE_COUNTDOWN), false)

	var assignmentProgress: = GameWorld.unlocks.get_assignment_progress()
	var unlockedAssignments = GameWorld.unlocks.get_unlocked_assignments()
	var assignmentIds = Data.assignments.keys().duplicate()
	assignmentIds.sort_custom( func(a, b): return Data.assignments[a].tier < Data.assignments[b].tier)
	for assignmentId in assignmentIds:
		if not unlockedAssignments.has(assignmentId):
			continue
		if Data.assignments[assignmentId].hidden:
			continue
		var e = preload("res://stages/loadout/AssignmentChoice.tscn").instantiate()
		e.setAssignment(assignmentId, GameWorld.unlocks.get_assignment_progress_by_id(assignmentId), assignmentProgress)
		e.select.connect(onLoadoutChoiceSelected.bind(assignmentSelected.bind(assignmentId)))
		_AssignmentsContainer.add_child(e)
	if _AssignmentsContainer.get_children().size() > 16:
		_AssignmentsContainer.columns = 5

	var unlockedRewards = GameWorld.unlocks.get_unlocked_rewards()
	for rewardId in Data.rewards:
		if not unlockedRewards.has(rewardId):
			continue
		var e = preload("res://stages/loadout/RewardChoice.tscn").instantiate()
		var title = "reward." + rewardId + ".title"
		var desc = "reward." + rewardId + ".desc"
		if desc == tr(desc):
			desc = ""
		var icon
		if Data.rewards[rewardId].has("icon"):
			icon = load("res://content/icons/" + str(Data.rewards[rewardId].icon))
			e.loadoutScale = 4.0
		e.setChoice(title, rewardId, icon, desc)
		e.connect("toggled", rewardSelected.bind(rewardId))
		e.disable_toggle = (Data.rewards[rewardId].get("disable_toggle", false))
		_AssignmentRewardsContainer.add_child(e)
	if _AssignmentRewardsContainer.get_children().size() > 12:
		_AssignmentRewardsContainer.columns = 4


	if not isMultiplayerMode() and Level.loadout.modeId == CONST.MODE_VERSUS:
		gameModeSelected(CONST.MODE_RELICHUNT, false, true)
	else:
		gameModeSelected(Level.loadout.modeId, false, true)

func updateRewardStatus():
	var availableBadges = GameWorld.unlocks.get_available_badges()
	_AvailableBadgesLabel.text = tr("level.assignment.badges.available") % availableBadges

	for choice in get_tree().get_nodes_in_group("reward-choice"):
		choice.status = GameWorld.unlocks.get_reward_status(choice.id)
		choice.update(availableBadges)

@rpc("reliable", "any_peer")
func rewardSelected(toggled: bool, id, requestFromClient: = false):
	resetPersistMetaCooldown()
	if not multiplayer.is_server():
		Network.rpc_server(rewardSelected.bind(toggled, id, true))
		return

	if GameWorld.assignmentRewardStatus.get(id, 0) == 0:
		if not requestFromClient:
			if toggled:
				Network.rpc_if_state(playUnlockRewardAnimation.bind(id), Network.ConnectionState.LOADOUT_STAGE_SYNC, true)
				GameWorld.setAssignmentRewardStatus(id, 2)
	else:
		if toggled:
			networkSound("gui_confirm")
		else:
			networkSound("gui_back")


		if not Data.rewards[id].get("disable_toggle", false):
			GameWorld.setAssignmentRewardStatus(id, 3 - GameWorld.assignmentRewardStatus[id])
		else:
			GameWorld.setAssignmentRewardStatus(id, 2)

	fillKeepers(true)
	fillPets(true)
	updateRewardStatus()
	updateClientLoadout()

@rpc("call_local")
func playUnlockRewardAnimation(rewardId: String):
	var rewardButton: RewardChoice
	for choice: RewardChoice in get_tree().get_nodes_in_group("reward-choice"):
		if (choice.id == rewardId):
			rewardButton = choice
			break

	Audio.sound("guild_reward_unlocked")
	rewardButton.playUnlockAnimation()

func fillDomes():
	for data in [[_DomeContainersTeam1, "team1"], [_DomeContainersTeam2, "team2"]]:
		var dc = data[0]
		var teamId: String = data[1]
		var atLeastOneUnlockable: = false
		for id in Data.loadoutDomes:
			var image = load("res://content/icons/loadout_" + id + ".png")
			var e = preload("res://stages/loadout/LoadoutChoice.tscn").instantiate()
			e.team_exclusive = teamId
			if GameWorld.unlocks.is_unlocked(id):
				var hc = getNewHintContainer("upgrades." + id + ".desc")
				hc.mode = "right"
				e.setChoice("upgrades." + id + ".title", id, image, hc)
			else:
				e.setChoice("", id, image, null)
				e.set_enabled(false)
				atLeastOneUnlockable = true
			dc.add_child(e)
			e.select.connect(onLoadoutChoiceSelected.bind(domeSelected.bind(id, teamId, true)))

		if atLeastOneUnlockable:
			var l = Label.new()
			l.label_settings = preload("res://gui/fontsettings/SmallFontSettings.tres")
			l.text = tr("unlock.generic")
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
			dc.add_child(l)

func fillPrimaryGadgets():
	for data in [[_PrimaryGadgetContainersTeam1, "team1"], [_PrimaryGadgetContainersTeam2, "team2"]]:
		var pgc = data[0]
		var teamId: String = data[1]
		var atLeastOneUnlockable: = false
		for id in Data.loadoutGadgets:
			var image = load("res://content/icons/loadout_" + id + ".png")
			var e = preload("res://stages/loadout/LoadoutChoice.tscn").instantiate()
			e.team_exclusive = teamId

			if GameWorld.unlocks.is_unlocked(id):
				var hc = getNewHintContainer("upgrades." + id + ".desc")
				hc.mode = "right"
				e.setChoice("upgrades." + id + ".title", id, image, hc)
			else:
				e.setChoice("", id, image, null)
				e.set_enabled(false)
				atLeastOneUnlockable = true
			pgc.add_child(e)
			e.select.connect(onLoadoutChoiceSelected.bind(primaryGadgetSelected.bind(id, teamId)))

		if atLeastOneUnlockable:
			var l = Label.new()
			l.label_settings = preload("res://gui/fontsettings/SmallFontSettings.tres")
			l.text = tr("unlock.generic")
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
			pgc.add_child(l)

func fillDifficulties():
	var difficulties: = [-2, -1, 0, 2]
	for i in 4:
		for data in [[_DifficultyContainersRelicHunt, "team1", true], [_DifficultyContainersTeam1, "team1"], [_DifficultyContainersTeam2, "team2"]]:
			var image = load("res://content/icons/loadout_diff" + str(i) + ".png") if data.size() > 2 else null
			var e = preload("res://stages/loadout/LoadoutChoice.tscn").instantiate()
			e.team_exclusive = "team1" if data[1] == "map" else data[1]
			e.loadoutScale = 2.0
			var diffName = CONST.difficultyStringByInt.get(difficulties[i])
			var desc: String
			if GameWorld.unlocks.is_unlocked(CONST.difficultyIdByInt[difficulties[i]]):
				desc = diffName + ".description"
			else:
				desc = diffName.replace("loadout", "unlock")
				e.set_enabled(false)
			e.setChoice(diffName, str(difficulties[i]), image, desc if image else "")
			data[0].add_child(e)
			e.select.connect(onLoadoutChoiceSelected.bind(difficultySelected.bind(difficulties[i], data[1], true)))

	difficultySelected(Level.difficulty("team1"), "team1", false)
	difficultySelected(Level.difficulty("team2"), "team2", false)

func fillPets(reload: bool = false):
	for data in [[_PetContainersTeam1, "team1"], [_PetContainersTeam2, "team2"]]:
		var pc = data[0]
		if reload:
			for child in pc.get_children():
				child.queue_free()
		var teamId: String = data[1]
		var pets = ["pet0"]
		pets.append_array(GameWorld.unlocks.get_unlocked_pets())
		for id in pets:
			var image = load("res://content/icons/loadout_" + id + ".png")
			var e = preload("res://stages/loadout/LoadoutChoice.tscn").instantiate()
			e.team_exclusive = teamId
			e.loadoutScale = 4.0
			e.expand_icon = false
			e.custom_minimum_size = Vector2(130, 110)
			e.setChoice("", id, image)
			pc.add_child(e)
			e.select.connect(onLoadoutChoiceSelected.bind(petSelected.bind(id, teamId)))
		if pc.get_children().size() > 13:
			pc.columns = 3

func fillMapSizes():
	var pgc = find_child("MapsizeContainers")
	var mapsizes: = []
	for ms in [CONST.MAP_SMALL, CONST.MAP_MEDIUM, CONST.MAP_LARGE, CONST.MAP_HUGE]:
		if GameWorld.unlocks.is_unlocked(ms):
			mapsizes.append(ms)
	for ms in [CONST.MAP_SMALL, CONST.MAP_MEDIUM, CONST.MAP_LARGE, CONST.MAP_HUGE]:
		var e = preload("res://stages/loadout/LoadoutChoice.tscn").instantiate()
		e.loadoutScale = 2.0
		var desc: String
		if GameWorld.unlocks.is_unlocked(ms):
			desc = CONST.mapSizesStringsById.get(ms) + ".description"
		else:
			desc = "unlock.mapsize." + ms.replace("regular-", "")
			e.set_enabled(false)
		var title = CONST.mapSizesStringsById.get(ms)
		e.setChoice(title, ms, null, desc)
		pgc.add_child(e)
		e.select.connect(onLoadoutChoiceSelected.bind(mapSizeSelected.bind(ms)))
		if GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION and ms != CONST.MAP_SMALL:
			e.set_enabled(false)

	if GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
		mapSizeSelected(CONST.MAP_SMALL, false, false)
	else:
		var conf = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_MAP_ARCHETYPE)
		if not [CONST.MAP_SMALL, CONST.MAP_MEDIUM, CONST.MAP_LARGE, CONST.MAP_HUGE].has(conf):
			conf = CONST.MAP_SMALL
		mapSizeSelected(conf, false, false)

@rpc("reliable", "any_peer")
func gameModeSelected(id: String, playSound: = true, firstLoad: = false):
	if ensureDelayBetweenMajorActions():
		return
	_isGameModeChangeInProgress = true

	var lastLoadout: Loadout
	if firstLoad and multiplayer.is_server() and GameWorld.hasLastLoadoutsByMode("last"):
		lastLoadout = GameWorld.getLastLoadoutsByMode("last").duplicate()

		if lastLoadout.modeId == CONST.MODE_VERSUS and not isMultiplayerMode():
			id = CONST.MODE_RELICHUNT
		else:
			id = lastLoadout.modeId
	else:
		lastLoadout = Level.loadout.duplicate()

	match id:
		CONST.MODE_VERSUS:
			ensureTwoTeams()
		_:
			if multiplayer.is_server():
				Network.rpc_if_state(ensureOneTeam, Network.ConnectionState.LOADOUT_STAGE_SYNC, true)
			else:
				ensureOneTeam()

	var oldId = lastLoadout.modeId
	if not firstLoad and id != oldId and playSound:
		networkSound("loadout_" + id)

	if oldId == CONST.MODE_PRESTIGE and lastLoadout.modeConfig.has(CONST.MODE_CONFIG_PRESTIGE_VARIANT):
		oldId = lastLoadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT)
	GameWorld.setLastLoadoutsByMode(oldId, lastLoadout.duplicate())


	if Level.loadout.modeId != CONST.MODE_ASSIGNMENTS:
		for dome: LoadoutDome in Level.loadout.domes:
			dome.additionalGadgets.clear()
	Level.loadout.modeConfig.erase(CONST.MODE_CONFIG_ASSIGNMENT)
	Level.loadout.modeConfig.erase(CONST.MODE_CONFIG_WORLDMODIFIERS)
	Level.loadout.modeConfig.erase(CONST.MODE_CONFIG_ADDITIONAL_GADGETS)

	Level.loadout.modeId = id

	_PetListTeam1.visible = GameWorld.unlocks.get_unlocked_pets().size() > 0
	_PetListTeam2.visible = false
	_AdditionalGadgetContainersTeam1.visible = false
	_AdditionalGadgetContainersTeam2.visible = false

	match id:
		CONST.MODE_VERSUS:
			_PetListTeam2.visible = GameWorld.unlocks.get_unlocked_pets().size() > 0
			_teamSelectionTeam1.setColor(_teamSelectionTeam1.getColor())
			_teamSelectionTeam2.setColor(_teamSelectionTeam2.getColor())
			if GameWorld.hasLastLoadoutsByMode(id):
				setLoadout(GameWorld.getLastLoadoutsByMode(id), false)

		CONST.MODE_RELICHUNT:
			if GameWorld.hasLastLoadoutsByMode(id):
				setLoadout(GameWorld.getLastLoadoutsByMode(id), false)

		CONST.MODE_PRESTIGE:
			var found = false
			for c in find_child("PrestigeModeVariantContainer").get_children():
				if not c is Label and c.selected:
					if GameWorld.hasLastLoadoutsByMode(c.id):
						setLoadout(GameWorld.getLastLoadoutsByMode(c.id), false)
						found = true
						break
			if not found and GameWorld.hasLastLoadoutsByMode(id):
				setLoadout(GameWorld.getLastLoadoutsByMode(id), false)

		CONST.MODE_ASSIGNMENTS:
			if GameWorld.hasLastLoadoutsByMode(id):
				setLoadout(GameWorld.getLastLoadoutsByMode(id), false)
			_AssignmentLeaderboard.start()
			updateRewardStatus()

	for c in find_child("GameModeContainers").get_children():
		if not c is Label:
			c.selected = c.id == id

	updateAllHintContainerPositions()
	if not isReloadingDueLanguageChange:
		updateClientLoadout()

func ensureTwoTeams() -> void :
	if Level.loadout.domes.size() == 1:
		var secondDome: = Loadout.createDefaultDome()
		secondDome.teamId = "team2"
		Level.loadout.domes.append(secondDome)

	var team1Count = Keepers.get_team("team1").getCount()
	var team2Count = Keepers.get_team("team2").getCount()
	if team1Count == 0 or team2Count == 0:

		var i: int = 0
		for lk: LoadoutKeeper in Level.loadout.keepers:
			lk.teamId = "team%d" % [i + 1]
			Lobby.update_team_id.rpc(Utils.encode_player_id(lk.playerId), i + 1)
			lk.keeper.teamId = lk.teamId

			Network.rpc_if_state(setKeeperTeam.bind(lk.playerId, lk.teamId), Network.ConnectionState.LOADOUT_STAGE_SYNC, true)
			Network.rpc_if_state(Lobby.update_team_id.bind(Utils.encode_player_id(lk.playerId), i + 1), Network.ConnectionState.LOADOUT_STAGE_SYNC, true)
			i = 1 - i
	Keepers.updateTeams()
	_teamSelectionTeam1.updateTeamPlayerNameList()
	_teamSelectionTeam2.updateTeamPlayerNameList()

@rpc("reliable")
func ensureOneTeam() -> void :
	if Level.loadout.domes.size() > 1:
		Level.loadout.domes = [Level.loadout.domes.front()]

	for lk: LoadoutKeeper in Level.loadout.keepers:
		lk.teamId = "team1"
		lk.keeper.teamId = "team1"
		Lobby.get_member_by_player_id(lk.playerId).team_id = 1
	Keepers.updateTeams()

func setLoadout(loadout: Loadout, updateLoadout: = true):
	if loadout.domes.size() == 0:
		loadout.domes.append(Loadout.createDefaultDome())
	if loadout.modeId == CONST.MODE_VERSUS:
		if loadout.domes.size() == 1:
			var loadoutDome: = Loadout.createDefaultDome()
			loadout.domes.append(loadoutDome)

		loadout.domes[1].teamId = "team2"


	if loadout.domes.size() > 2:
		push_warning("Setting loadout with dome array that had %d elements" % loadout.domes.size())
	if loadout.modeId == CONST.MODE_VERSUS:
		loadout.domes.resize(2)
	else:
		loadout.domes.resize(1)

	Level.loadout.domes = loadout.domes.duplicate()

	adjust_primary_gadget_for_loadout(loadout)
	for dome: LoadoutDome in loadout.domes:
		domeSelected(dome.domeId, dome.teamId, false, false)
		petSelected(dome.petId, dome.teamId, false, false)
		primaryGadgetSelected(dome.primaryGadgetId, dome.teamId, false, false)

	if loadout.modeConfig.has(CONST.MODE_CONFIG_WORLDMODIFIERS):
		Level.loadout.modeConfig[CONST.MODE_CONFIG_WORLDMODIFIERS] = loadout.modeConfig[CONST.MODE_CONFIG_WORLDMODIFIERS]


	if Level.loadout.modeId == Const.MODE_RELICHUNT:
		var modifiers: Array = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_WORLDMODIFIERS, [])
		for modifier: String in modifiers:
			if modifier.replace("worldmodifier", "") not in GameWorld.unlocks.get_unlocked_run_modifiers():
				modifiers.erase(modifier)
		Level.loadout.modeConfig[CONST.MODE_CONFIG_WORLDMODIFIERS] = modifiers

	_ModifiersBox.initialize(get_run_modifiers())

	_LoadoutChoiceFriendlyMode.selected = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_FRIENDLY_MODE, false)
	_LoadoutChoiceProMode.visible = GameWorld.unlocks.is_unlocked(CONST.MODE_PRESTIGE_PRO)
	_AdditionalGadgetContainersTeam1.visible = false
	if loadout.modeId == CONST.MODE_ASSIGNMENTS and loadout.modeConfig.has(CONST.MODE_CONFIG_ASSIGNMENT):
		var assignmentId = loadout.modeConfig.get(CONST.MODE_CONFIG_ASSIGNMENT)
		if not assignmentId or not Data.assignments.has(assignmentId):
			assignmentId = Data.assignments.keys().front()
		assignmentSelected(assignmentId, false, false)
	elif loadout.modeId == CONST.MODE_RELICHUNT:
		mapSizeSelected(loadout.modeConfig.get(CONST.MODE_CONFIG_MAP_ARCHETYPE, CONST.MAP_SMALL), false, false)
		difficultySelected(loadout.difficultyByTeamId.get("team1", 0), "team1", false, false)

	setVersusWinCondition(loadout.modeConfig.get(CONST.MODE_CONFIG_VERSUS_WINCONDITION, ""), false, false)

	if updateLoadout:
		updateClientLoadout()
	resetPersistMetaCooldown()

func onUnlocksUpdated() -> void :
	fillKeepers(true)
	fillPets(true)
	_PetListTeam1.visible = GameWorld.unlocks.get_unlocked_pets().size() > 0
	_PetListTeam2.visible = Level.loadout.modeId == CONST.MODE_VERSUS and GameWorld.unlocks.get_unlocked_pets().size() > 0
	_ModifiersBox.initialize(get_run_modifiers())
	updateClientLoadout()

func get_run_modifiers():
	var runModifiers = GameWorld.unlocks.get_unlocked_run_modifiers().duplicate()

	if Keepers.getAll().size() < 2:
		for modifier in Data.COOP_RUN_MODIFIERS:
			runModifiers.erase(modifier)

	return runModifiers

@rpc("reliable")
func setClientLoadout(buffer: PackedByteArray, hostUnlocks: Dictionary, customSettings: Dictionary) -> void :
	var loadout = Loadout.from_bytes(buffer)
	GameWorld.unlocks.deserialize(hostUnlocks)
	GameWorld.deserializeCustomSettings(customSettings)


	fillKeepers(true)


	var keepers = Level.loadout.keepers
	Level.loadout = loadout
	for lk in loadout.keepers:
		for keeper in keepers:
			if lk.playerId == keeper.playerId:
				keeper.teamId = lk.teamId
	Level.loadout.keepers = keepers
	Keepers.updateTeams()

	_AdditionalGadgetContainersTeam1.visible = loadout.modeId == CONST.MODE_ASSIGNMENTS

	adjust_primary_gadget_for_loadout(loadout)
	for dome in loadout.domes:
		domeSelected(dome.domeId, dome.teamId, false, false)
		petSelected(dome.petId, dome.teamId, false, false)
		primaryGadgetSelected(dome.primaryGadgetId, dome.teamId, false, false)
	if loadout.modeId == CONST.MODE_ASSIGNMENTS and loadout.modeConfig.has(CONST.MODE_CONFIG_ASSIGNMENT):
		assignmentSelected(loadout.modeConfig[CONST.MODE_CONFIG_ASSIGNMENT], false, false)

	if Level.loadout.modeConfig.has(CONST.MODE_CONFIG_WORLDMODIFIERS):
		Level.loadout.modeConfig[CONST.MODE_CONFIG_WORLDMODIFIERS] = loadout.modeConfig[CONST.MODE_CONFIG_WORLDMODIFIERS]
	_ModifiersBox.updateModifierLabels()

	_LoadoutChoiceFriendlyMode.selected = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_FRIENDLY_MODE, false)

	for c in find_child("GameModeContainers").get_children():
		if not c is Label:
			c.selected = c.id == loadout.modeId

	for c in find_child("MapsizeContainers").get_children():
		if not c is Label:
			c.selected = c.id == Level.loadout.modeConfig[CONST.MODE_CONFIG_MAP_ARCHETYPE]

	if Level.loadout.modeConfig.has(CONST.MODE_CONFIG_PRESTIGE_VARIANT):
		for c in find_child("PrestigeModeVariantContainer").get_children():
			if not c is Label:
				c.selected = c.id == Level.loadout.modeConfig[CONST.MODE_CONFIG_PRESTIGE_VARIANT]

	setVersusWinCondition(loadout.modeConfig.get(CONST.MODE_CONFIG_VERSUS_WINCONDITION, ""), false, false)

	for dome in Level.loadout.domes:
		var container = find_child("DomeContainers" + Data.startCaptialized(dome.teamId))
		for c in container.get_children():
			if not c is Label:
				c.selected = c.id == dome.domeId

		container = find_child("PrimaryGadgetContainers" + Data.startCaptialized(dome.teamId))
		for c in container.get_children():
			if not c is Label:
				c.selected = c.id == dome.primaryGadgetId

	for c in _DifficultyContainersRelicHunt.get_children():
		if not c is Label:
			c.selected = c.id == str(Level.difficulty("team1"))
	for c in _DifficultyContainersTeam1.get_children():
		if not c is Label:
			c.selected = c.id == str(Level.difficulty("team1"))
	for c in _DifficultyContainersTeam2.get_children():
		if not c is Label:
			c.selected = c.id == str(Level.difficulty("team2"))

	_VersusModifiersBoxTeam1.updateModifierLabels()
	_VersusModifiersBoxTeam2.updateModifierLabels()

	updateAllHintContainerPositions()
	updateBlockVisibility()

func adjust_primary_gadget_for_loadout(loadout: Loadout) -> bool:
	if loadout.modeId != CONST.MODE_PRESTIGE:
		return false

	if loadout.modeConfig.has(CONST.MODE_CONFIG_PRESTIGE_VARIANT):
		var prestige = loadout.modeConfig[CONST.MODE_CONFIG_PRESTIGE_VARIANT]
		if prestige == CONST.MODE_PRESTIGE_MINER:

			for dome in loadout.domes:
				if Data.gadgets.get(dome.primaryGadgetId, {}).get("limit", []).has("hostile"):
					dome.primaryGadgetId = "orchard"
			return true
	return false

@rpc("reliable", "any_peer")
func prestigeModeVariantSelected(id: String, playSound: = true):
	if Level.loadout.modeId == CONST.MODE_PRESTIGE and \
	Level.loadout.modeConfig.has(CONST.MODE_CONFIG_PRESTIGE_VARIANT) and multiplayer.is_server():
		GameWorld.setLastLoadoutsByMode(Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT), Level.loadout.duplicate())
	Level.loadout.modeConfig[CONST.MODE_CONFIG_PRESTIGE_VARIANT] = id

	for c in find_child("PrestigeModeVariantContainer").get_children():
		if not c is Label:
			c.selected = c.id == id
	if playSound:
		match id:
			CONST.MODE_PRESTIGE_COUNTDOWN:
				networkSound("loadout_modecountdown")
			CONST.MODE_PRESTIGE_ENDLESS:
				networkSound("loadout_modebasic")
			CONST.MODE_PRESTIGE_PROVOCATION:
				networkSound("loadout_modecobolt")
			CONST.MODE_PRESTIGE_MINER:
				networkSound("loadout_modeminer")

	if Level.loadout.modeId == CONST.MODE_PRESTIGE:
		if GameWorld.hasLastLoadoutsByMode(id):
			setLoadout(GameWorld.getLastLoadoutsByMode(id), false)

		elif adjust_primary_gadget_for_loadout(Level.loadout):
			primaryGadgetSelected(Level.loadout.domes.front().primaryGadgetId, "team1", false, false)

	updateClientLoadout()

@rpc("reliable", "any_peer")
func assignmentSelected(id: String, playSound: = true, updateLoadout: = true):
	resetPersistMetaCooldown()
	if not Level.loadout.modeConfig.has(CONST.MODE_CONFIG_ASSIGNMENT) or Level.loadout.modeConfig[CONST.MODE_CONFIG_ASSIGNMENT] != id:
		if playSound:
			networkSound("loadout_assignment_on")

	Level.loadout.modeConfig[CONST.MODE_CONFIG_ASSIGNMENT] = id

	for c in _AssignmentsContainer.get_children():
		if not c is Label:
			c.selected = c.id == id

	var isChallengeMode = GameWorld.unlocks.get_last_chosen_assignment_difficulty().get(id, 0) == 1
	Level.loadout.modeConfig[CONST.MODE_CONFIG_ASSIGNMENT_CHALLENGE_MODE] = isChallengeMode
	_AssignmentChoice.setAssignment(id, isChallengeMode, Level.loadout.keepers.size())

	var freeGadgets = GameWorld.unlocks.get_assignment_free_gadgets()
	_AdditionalGadgetContainersTeam1.visible = freeGadgets > 0
	for c in _AdditionalGadgetContainersTeam1.get_children():
		if not c is Label:
			c.remove_from_group("additional-gadget-choice")
			c.queue_free()

	var preselected = GameWorld.unlocks.get_used_assignment_gadgets().get(id, [])
	var assignment_upgrade_limits = GameWorld.unlocks.get_assignment_upgrade_limits()

	for i in freeGadgets:
		var gadgetId = ""
		if preselected.size() > i:
			gadgetId = preselected[i]

		var choice = preload("res://stages/loadout/AdditionalGadgetChoice.tscn").instantiate()
		_AdditionalGadgetContainersTeam1.add_child(choice)
		choice.emit_keeper_on_selected = true
		choice.connect("select", openAdditionalGadgetPopup.bind(choice, i, assignment_upgrade_limits))
		choice.setGadget(gadgetId, null)

	updateAdditionalGadgetChoice()
	if updateLoadout:
		updateClientLoadout()

func openAdditionalGadgetPopup(keeper: Keeper, choice, idx: int, limits: Array):
	Audio.sound("gui_select")
	var i = preload("res://content/shared/ControllerScrollInputProcessor.gd").new()
	var popup = preload("res://stages/loadout/AdditionalGadgetPopup.tscn").instantiate()
	pause()
	i.deviceId = keeper.deviceId
	i.popup = popup
	i.popup.playerId = keeper.playerId
	i.popup.teamId = keeper.teamId
	i.popup.setOpenerIndex(idx)
	i.popup.setLimits(limits)
	i.blockAllKeys = true
	i.globalInput = true
	i.blockStickMove = true
	i.scrollTarget = i.popup.find_child("ScrollContainer").get_v_scroll_bar()
	i.connect("onStop", popup.queue_free)
	i.connect("onStop", unpause)
	i.popup.selected.connect(networkRequestSelectAdditionalGadget.bind(idx, i))
	$CanvasLayer.add_child(i.popup)
	i.integrate(self)

func networkRequestSelectAdditionalGadget(gadgetId: String, idx: int, ip: InputProcessor) -> void :
	ip.close()
	Network.rpc_server(requestSelectAdditionalGadget.bind(gadgetId, idx))

@rpc("reliable", "any_peer")
func requestSelectAdditionalGadget(gadgetId: String, idx: int) -> void :
	var additionalGadgets: = GameWorld.getPossibleAdditionalGadgets(idx, "team1")

	if gadgetId != "" and not additionalGadgets["available_gadgets"].has(gadgetId):
		return

	var gadget_choices = get_tree().get_nodes_in_group("additional-gadget-choice")
	if gadget_choices.size() > idx:
		gadget_choices[idx].setGadget(gadgetId, null)

	updateAdditionalGadgetChoice()
	updateClientLoadout()

func updateAdditionalGadgetChoice():
	if not multiplayer.is_server():
		return

	var picks: = []
	for choice in get_tree().get_nodes_in_group("additional-gadget-choice"):
		if choice.id != "":
			picks.append(choice.id)

	var id = Level.loadout.modeConfig[CONST.MODE_CONFIG_ASSIGNMENT]
	GameWorld.usedAssigmentsGadgets[id] = picks
	Level.loadout.domes[0].additionalGadgets = picks

@rpc("reliable", "any_peer")
func domeSelected(id, teamId: String, playSound: = true, updateLoadout: = true):
	resetPersistMetaCooldown()
	_correctDomeKeepers(teamId)
	var dome = Level.domesByTeamId.get(teamId, null)
	if not is_instance_valid(dome) or dome.techId != id:
		if playSound:
			networkSound("loadout_" + id, teamId)

		GameWorld.availableTechSlots.clear()
		if Level.loadout.modeId != CONST.MODE_VERSUS and teamId == "team1":

			GameWorld.boughtUpgrades.erase(teamId + "." + Level.loadout.domes.front().domeId)
			GameWorld.addUpgrade(id, teamId)

		find_child("PrimaryGadgetContainers" + Data.startCaptialized(teamId)).visible = true
		find_child("PetList" + Data.startCaptialized(teamId)).visible = GameWorld.unlocks.get_unlocked_pets().size() > 0

	for d: LoadoutDome in Level.loadout.domes:
		if d.teamId == teamId:
			d.domeId = id
	for c in find_child("DomeContainers" + Data.startCaptialized(teamId)).get_children():
		if not c is Label:
			c.selected = c.id == id


	if Network.is_server():
		for keeper in Keepers.getAllOfTeam(teamId):
			if keeper.techId == "keeper4":
				if is_instance_valid(Level.getDome(teamId)):
					Level.getDome(teamId).goblins.register_keeper(keeper)

	if updateLoadout:
		updateClientLoadout()

func _correctDomeKeepers(inDomeTeamId: String) -> void :
	const KEEPER_SAFE_DOME_POSITION: Vector2 = Vector2(0, -50)

	for child in get_children():
		if child is BattleInputProcessor:
			child.desintegrate()

	var wasStationInUse: bool = false
	var allKeepers: Array = Keepers.all.getAll()
	for keeper: Keeper in allKeepers:
		if keeper.isInsideStation:
			keeper.exitStation()
			wasStationInUse = true
		if keeper.position.y < KEEPER_SAFE_DOME_POSITION.y:
			keeper.teleport(KEEPER_SAFE_DOME_POSITION)

	if wasStationInUse:
		var dome: Dome = Level.domesByTeamId.get(inDomeTeamId, null)
		if is_instance_valid(dome):
			for stationIdx: int in dome.stations.size():
				dome.stopWeapons(stationIdx)

func addDome(newDome, teamId: String):
	var dome = Level.domesByTeamId.get(teamId, null)
	if dome:
		dome.unlisten()
		dome.free()


	for monster in get_tree().get_nodes_in_group("team1-monster"):
		monster.die()
		monster.removeFreeBlocker()
		monster.removeFreeBlocker()

	dome = newDome
	dome.remainingHeals = 99999999999
	dome.teamId = teamId
	Level.domesByTeamId[teamId] = dome
	_DomePositionArea1.monitorable = true
	dome.position = %DomePosition.position
	$Viewports.addElement(dome)
	dome.init()

	for ld: LoadoutDome in Level.loadout.domes:
		if ld.teamId == teamId:
			if dome.primaryWeapon:
				GameWorld.addUpgrade(dome.primaryWeapon, dome.teamId)

			if ld.primaryGadgetId:
				GameWorld.addUpgrade(ld.primaryGadgetId, dome.teamId)

			if ld.petId and multiplayer.is_server():
				addPet(ld.petId)

@rpc("reliable", "any_peer")
func primaryGadgetSelected(id, teamId: String, playSound: = true, updateLoadout: = true):
	resetPersistMetaCooldown()
	for ld: LoadoutDome in Level.loadout.domes:
		if ld.teamId == teamId:
			if ld.primaryGadgetId != id and playSound:
				networkSound("loadout_" + id, teamId)

			for c in find_child("PrimaryGadgetContainers" + Data.startCaptialized(teamId)).get_children():
				if not c is Label:
					c.selected = c.id == id

			if ld.primaryGadgetId and Level.domesByTeamId.has(teamId):
				Level.domesByTeamId[teamId].removePrimaryGadget()

			ld.primaryGadgetId = id
			if Level.loadout.modeId != CONST.MODE_VERSUS:
				GameWorld.addUpgrade(id, teamId)
			if updateLoadout:
				updateClientLoadout()
			return

@rpc("reliable", "any_peer")
func difficultySelected(d, teamId: String, playSound: = false, updateLoadout: = true):
	resetPersistMetaCooldown()
	if playSound:
		networkSound("gui_select", teamId)
	Level.loadout.difficultyByTeamId[teamId] = d
	for c in _DifficultyContainersRelicHunt.get_children():
		if not c is Label:
			c.selected = c.id == str(d)

	if teamId != "map":
		for c in (_DifficultyContainersTeam1 if teamId == "team1" else _DifficultyContainersTeam2).get_children():
			if not c is Label:
				c.selected = c.id == str(d)

	if updateLoadout:
		updateClientLoadout()

@rpc("reliable", "any_peer")
func petSelected(id, teamId: String, playSound: = true, updateLoadout: = true):
	resetPersistMetaCooldown()

	for c in find_child("PetContainers" + Data.startCaptialized(teamId)).get_children():
		if not c is Label:
			if c.id == id:
				c.selected = true
			else:
				c.selected = false

	for dome: LoadoutDome in Level.loadout.domes:
		if dome.teamId != teamId:
			continue

		if dome.petId != id and playSound:
			networkPetSound(id, teamId)

		dome.petId = id

	if updateLoadout:
		updateClientLoadout()
	addPet(id)

func networkPetSound(id: String, teamId: String) -> void :
	Network.rpc_if_state(petSound.bind(id, teamId), Network.ConnectionState.LOADOUT_STAGE_SYNC, true)

@rpc("reliable")
func petSound(id: String, teamId: String) -> void :
	if teamId != "":
		var localTeams: = Utils.get_local_teams(multiplayer.get_unique_id())
		if not localTeams.has(teamId):
			return


	var pet = load("res://content/pets/" + id + "/" + Data.startCaptialized(id) + ".tscn")
	if pet:
		pet = pet.instantiate()
		var baseSound = pet.find_child("GreetingSound")
		var newSound = load("res://systems/audio/Sound.tscn").instantiate()
		if baseSound:
			newSound.streams = baseSound.streams
			newSound.maxAudibleDistance = 0.0
			newSound.additionalVolume = 4.0
			newSound.removeAfterPlaying = true
			add_child(newSound)
			newSound.startSound()
		pet.queue_free()

func addPet(id):
	for pet in get_tree().get_nodes_in_group("pets"):
		pet.queue_free()

	if not multiplayer.is_server():
		return

	if Level.domesByTeamId.has("team1") and id and id != "pet0":
		Level.domesByTeamId["team1"].addPet(id)

@rpc("reliable", "any_peer")
func mapSizeSelected(id, playSound: = true, updateLoadout: = true):
	resetPersistMetaCooldown()
	if playSound:
		networkSound("gui_select")
	Level.loadout.modeConfig[CONST.MODE_CONFIG_MAP_ARCHETYPE] = id
	for c in find_child("MapsizeContainers").get_children():
		if not c is Label:
			c.selected = c.id == id

	if updateLoadout:
		updateClientLoadout()

func updateStartRunButton():
	var area
	if isMultiplayerMode():
		area = _startRunChoiceGroup
	else:
		area = _startRunChoice

	area.set_enabled(false)
	var blockLoadout = find_child("BlockDomeLoadoutTeam1", true, false)

	if Level.loadout.modeId == "":
		area.setChoice("loadout.hint.gamemode", "", null)
		return

	if not blockLoadout.visible:
		area.setChoice("loadout.hint.gamemodecompletion", "", null)
		return

	if not Level.loadout.domes.front() or Level.loadout.domes.front().domeId == "":
		area.setChoice("loadout.hint.dome", "", null)
		return

	if Level.loadout.domes.front().primaryGadgetId == "":
		area.setChoice("loadout.hint.loadout", "", null)
		return

	if Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER and GameWorld.buildType != CONST.BUILD_TYPE.EXHIBITION:
		if Level.loadout.keepers.size() < 2:
			area.setChoice("loadout.hint.multiplayer.playerminimum", "", null)
			return
		elif Level.loadout.keepers.size() > 8:
			area.setChoice("loadout.hint.multiplayer.playermaximum", "", null)
			return

	match Level.loadout.modeId:
		CONST.MODE_PRESTIGE:
			if not Level.loadout.modeConfig.has(CONST.MODE_CONFIG_PRESTIGE_VARIANT):
				area.setChoice("loadout.hint.gamemodecompletion", "", null)
				return
			if Level.loadout.keepers.size() > 2:
				area.setChoice("loadout.hint.playerlimitprestige", "", null)
				area.set_enabled(true)
				return
		CONST.MODE_VERSUS:
			for dome in Level.loadout.domes:
				if dome.domeId == "" or dome.primaryGadgetId == "":
					area.setChoice("loadout.hint.loadout", "", null)
					return
			var hasTeam1: = false
			var hasTeam2: = false
			for keeper in Level.loadout.keepers:
				if keeper.teamId == "team1":
					hasTeam1 = true
				elif keeper.teamId == "team2":
					hasTeam2 = true
			if not (hasTeam1 and hasTeam2):
				area.setChoice("loadout.hint.teams", "", null)
				return
			if not Level.loadout.modeConfig.get(CONST.MODE_CONFIG_VERSUS_WINCONDITION, "") != "":
				area.setChoice("loadout.hint.gamemodecompletion", "", null)
				return

	area.set_enabled(true)
	area.setChoice("loadout.secondstage.start", "", null)

func createMapDataFor(requiremnts) -> MapData:
	var tileData = preload("res://content/map/MapData.tscn").instantiate()
	tileData.clear()
	tileData.stack(preload("res://stages/loadout/TileDataStartArea.tscn").instantiate(), Vector2(0, 0))

	for x in requiremnts:
		match x:
			"relichunt":
				tileData.stack(preload("res://stages/loadout/TileDataModeRelicHunt.tscn").instantiate(), Vector2(-9, 2))
			"prestige":
				tileData.stack(preload("res://stages/loadout/TileDataModePrestige.tscn").instantiate(), Vector2(-9, 2))
			"assignments":
				tileData.stack(preload("res://stages/loadout/TileDataModeAssignments.tscn").instantiate(), Vector2(-9, 2))
			"loadout":
				tileData.stack(preload("res://stages/loadout/TileDataLoadout.tscn").instantiate(), Vector2(4, 2))
			"dome-opening":
				tileData.stack(preload("res://stages/loadout/TileDataDomeOpening.tscn").instantiate(), Vector2(-1, 2))
			"guildrewards":
				tileData.stack(preload("res://stages/loadout/TileDataGuildRewards.tscn").instantiate(), Vector2(5, 13))
			"versus":
				tileData.stack(preload("res://stages/loadout/TileDataModeVersus.tscn").instantiate(), Vector2(-9, 2))
				tileData.stack(preload("res://stages/loadout/TileDataModeLoadoutExtension.tscn").instantiate(), Vector2(16, 2))

	for coord in dugTileCoordinates:
		var res = tileData.get_resourcev(coord)
		if res >= 0 and res <= 10:
			tileData.clear_resource(coord)

	return tileData


func preGenerateMap(requirements):
	var generated = map_scene.instantiate()
	var map_name: String = ""
	for r in requirements:
		map_name += r
	generated.name = map_name
	add_child(generated)
	if hostPregeneratedMapData.has(requirements):
		var tileData = preload("res://content/map/MapData.tscn").instantiate()
		tileData.clear()
		generated.setTileData(tileData)
		var map_data = hostPregeneratedMapData[requirements]
		for layer in map_data.keys():
			generated.tileData.set_layer_data(layer, map_data[layer])
	else:
		generated.setTileData(createMapDataFor(requirements))
	generated.biomes = Map.generateBiomes()
	generated.init(false, false)
	generated.revealInitialState(Vector2(0, 4))
	pregeneratedMaps[requirements] = generated
	remove_child(generated)
	return generated

func serializePreGeneratedMaps() -> Dictionary:
	var maps = {}
	for key in pregeneratedMaps.keys():
		maps[key] = pregeneratedMaps[key].getMapData()
	return maps

func updateBlockVisibility(forceRebuild: = false):
	if not initialized:
		return

	var stackedTileDataIds: = []
	if GameWorld.getFiguredOutMovementInLoadout():
		var blockRelicHunt = find_child("BlockRelicHuntLoadout", true, false)
		blockRelicHunt.visible = Level.loadout.modeId == CONST.MODE_RELICHUNT
		if blockRelicHunt.visible:
			stackedTileDataIds.append("relichunt")

		var blockPrestige = find_child("BlockPrestigeLoadout", true, false)
		blockPrestige.visible = Level.loadout.modeId == CONST.MODE_PRESTIGE
		if blockPrestige.visible:
			stackedTileDataIds.append("prestige")

		var blockVersus = find_child("BlockVersusLoadout")
		blockVersus.visible = Level.loadout.modeId == CONST.MODE_VERSUS and not BuildCustomization.has_feature("disable_multi")
		_SpacerGameMode.visible = not blockVersus.visible

		var blockAssignments = find_child("BlockAssignmentsLoadout")
		blockAssignments.visible = Level.loadout.modeId == CONST.MODE_ASSIGNMENTS
		if blockAssignments.visible:
			stackedTileDataIds.append("assignments")

		var blockLoadout = find_child("BlockDomeLoadoutTeam1")
		blockLoadout.visible = (blockRelicHunt.visible and Level.loadout.modeConfig.has(CONST.MODE_CONFIG_MAP_ARCHETYPE))\
		or (blockPrestige.visible and Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT, "") != "")\
		or (blockAssignments.visible and Level.loadout.modeConfig.get(CONST.MODE_CONFIG_ASSIGNMENT, "") != "")\
		or (blockVersus.visible)
		if blockLoadout.visible:
			stackedTileDataIds.append("loadout")
			blockLoadout.size.x = 0

		if blockVersus.visible:

			stackedTileDataIds.append("versus")

		_BlockGuildReward.visible = GameWorld.unlocks.is_unlocked(CONST.MODE_ASSIGNMENTS) and blockLoadout.visible
		if _BlockGuildReward.visible:
			updateRewardStatus()
			stackedTileDataIds.append("guildrewards")

		if Level.loadout.modeId != CONST.MODE_VERSUS and Level.domesByTeamId.has("team1"):
			stackedTileDataIds.append("dome-opening")

	updateStartRunButton()

	var rebuildMap: = false
	for id in lastStackedTileData:
		if not stackedTileDataIds.has(id):
			rebuildMap = true
			break
	for id in stackedTileDataIds:
		if not lastStackedTileData.has(id):
			rebuildMap = true
			break

	if rebuildMap or forceRebuild:
		var drops: Dictionary = Level.drops.get_all_drops()
		for drop: Carryable in drops.values():
			if not drop.isCarried():
				Level.drops.network_free_drop(drop.UID)
				drops.erase(drop.UID)
			else:
				Level.drops.remove_child(drop)

		var bundles: Dictionary = Level.drops.get_all_bundles()
		for bundle in bundles.values():
			Level.drops.remove_child(bundle)

		var map
		if pregeneratedMaps.has(stackedTileDataIds):
			map = pregeneratedMaps[stackedTileDataIds]
		else:
			map = preGenerateMap(stackedTileDataIds)

		MAP.get_parent().remove_child(MAP)
		$Viewports.addElement(map)
		MAP = map
		Level.map = map
		runDecoration()

		ensure_player_in_bounds()
		create_tween().tween_callback(ensure_player_in_bounds).set_delay(0.1)

		Level.drops.bulk_add(drops)
		Level.drops.bulk_bundle(bundles)

		for coord in MAP.tileData.get_mineable_tile_coords():
			MAP.addTileDestroyedListener(self, coord)

		if GameWorld.devMode:
			var packedTileData = MAP.tileData.pack()
			ResourceSaver.save(packedTileData, "res://stages/loadout/TileDataLoadoutResultDebug.tscn")

		PhysicsServer2D.area_clear_shapes(_visibilityChecker.get_rid())
		visibilityTileQueue.clear()

		visibilityTileQueue = MAP.getTileData().getRevealedCells()
		visibilityTileQueue.sort_custom( func(x, y): return x.y < y.y)

	lastStackedTileData = stackedTileDataIds


	for c in _PrimaryGadgetContainersTeam1.get_children():
		if not c is Label:
			if Level.loadout.modeId == CONST.MODE_PRESTIGE and \
			Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT, "") == CONST.MODE_PRESTIGE_MINER:
				c.visible = not Data.gadgets.get(c.id).get("limit", []).has("hostile")
			else:
				c.visible = true


	if Level.loadout.modeId == CONST.MODE_VERSUS:
		for dome in Level.domesByTeamId.values():
			dome.unlisten()
			dome.free()
		Level.domesByTeamId.clear()
		_HeadlineTeam1.text = tr("loadout.title") + " " + (tr("loadout.team") % "1")
		_HeadlineTeam2.text = tr("loadout.title") + " " + (tr("loadout.team") % "2")
		_AdditionalGadgetContainersTeam1.visible = false
		_AdditionalGadgetContainersTeam2.visible = false
		_teamSelectionTeam1.visible = true
		_teamSelectionTeam2.visible = true
		_VersusModifiersBoxTeam1.visible = true
		_VersusModifiersBoxTeam2.visible = true
		_DifficultyListTeam1.visible = true
		_teamSelectionTeam1.updateTeamPlayerNameList()
		_teamSelectionTeam2.updateTeamPlayerNameList()
	else:
		_HeadlineTeam1.text = tr("loadout.title")
		_HeadlineTeam2.text = tr("loadout.title")
		_DifficultyListTeam1.visible = false
		_teamSelectionTeam1.visible = false
		_teamSelectionTeam2.visible = false
		_VersusModifiersBoxTeam1.visible = false
		_VersusModifiersBoxTeam2.visible = false

	onKeepersChanged()

func _physics_process(delta: float) -> void :
	if visibilityTileQueue.size():
		var visiblity_rid: RID = _visibilityChecker.get_rid()
		for i in range(10):
			if visibilityTileQueue.size():
				var coord: Vector2 = visibilityTileQueue.pop_front()
				PhysicsServer2D.area_add_shape(visiblity_rid, visibilityTileShape, _visibilityChecker.global_transform.translated(coord * GameWorld.TILE_SIZE + CONST.TILE_OFFSET))

var decorationRan: = false
func runDecoration():
	await get_tree().create_timer(0.05).timeout

	var rng: = RandomNumberGenerator.new()
	rng.seed = Level.levelSeed

	decorationRan = true
	MAP.border_deco.runDecoration()
	for d in get_tree().get_nodes_in_group("decoration"):
		d.visible = rng.randf() < 0.7

func addVisibilitiyTileArr(arr):
	for x in arr:
		addVisibilityTile(x)

func find_all_children_of_type(node, T):
	return node.find_children("*", T)

func ensure_player_in_bounds():
	for x in Keepers.getAll():
		var coord = MAP.getTileCoord(x.global_position)
		var res = MAP.tileData.get_resourcev(coord)
		var hardness = MAP.tileData.get_hardnessv(coord)

		var sp = MAP.getTileCoord(_KeeperSpawnPosition.position)


		var isAtSpawnPos: bool = (sp - coord).length_squared() == 0
		var isAtEmptyTile: bool = (hardness == -1 or res != Data.TILE_EMPTY)
		var isInsideIndestructableTile: bool = hardness == Data.HARDNESS_INDESTRUCTIBLE
		while ( not isAtSpawnPos and isAtEmptyTile) or isInsideIndestructableTile:
			var dt = sp - coord
			if abs(dt.x) > abs(dt.y):
				coord += Vector2i(sign(dt.x), 0)
			else:
				coord += Vector2i(0, sign(dt.y))

			res = MAP.tileData.get_resourcev(coord)
			hardness = MAP.tileData.get_hardnessv(coord)
			isAtEmptyTile = (hardness == -1 or res != Data.TILE_EMPTY)
			isAtSpawnPos = (sp - coord).length_squared() == 0
			isInsideIndestructableTile = hardness == Data.HARDNESS_INDESTRUCTIBLE
		var target = MAP.getTilePos(coord)
		x.teleport(target)

func addVisibilityTile(coord: Vector2):
	PhysicsServer2D.area_add_shape(_visibilityChecker.get_rid(), visibilityTileShape, _visibilityChecker.global_transform.translated(coord * GameWorld.TILE_SIZE + CONST.TILE_OFFSET))


func tileDestroyed(coord: Vector2):
	dugTileCoordinates.append(coord)
	addVisibilityTile(coord)

func addNewDevice(id: int):
	if _isGameModeChangeInProgress:
		loadoutInputProcessor.unregisterDevice(id)
		return

	for existing in Lobby.members:
		if existing.peer_id == multiplayer.get_unique_id() and existing.device_id == id:
			return

	if Keepers.local.getCount() == 4:

		loadoutInputProcessor.unregisterDevice(id)
		return

	var platform_user_id: String
	var platform_user_name: String
	if BuildCustomization.has_feature("enable_multiple_local_account"):

		platform_user_id = Platform.get_user_id_per_device_id(id)
		platform_user_name = Platform.get_username_per_device_id(id)
	else:

		platform_user_id = Platform.get_user_id()
		platform_user_name = Platform.get_username()

	var platform_block_list = []
	if BuildCustomization.has_feature("enable_block"):
		platform_block_list = Platform.get_block_list_per_device_id(id)

	var add_keeper_cb: Callable = _askLobbyToAddNewLocalKeeper.bind(
		multiplayer.get_unique_id(), 
		id, 
		PlayFabServices.get_entity_id(), 
		Platform.get_platform_id(), 
		platform_user_id, 
		platform_user_name, 
		platform_block_list, 
	)

	if multiplayer.is_server():
		add_keeper_cb.call()
	else:
		Network.chunker.send(1, Chunker.ChunkRequestType.ASK_LOBBY_TO_ADD_NEW_LOCAL_KEEPER, add_keeper_cb)

@rpc("any_peer", "reliable")
func _askLobbyToAddNewLocalKeeper(peer_id: int, device_id: int, playfab_id: String, platform_id: String, platform_user_id: String, platform_user_name: String, platform_block_list: Array) -> void :
	assert (multiplayer.is_server())
	if Lobby.can_add_new_member() and not Network.is_platform_client_blocked(platform_id, platform_user_id, platform_block_list):
		Lobby.add(peer_id, device_id, playfab_id, platform_id, platform_user_id, platform_user_name)
		Lobby.get_member(peer_id, device_id).platform_block_list = platform_block_list
	else:
		Network.rpc_or_local(peer_id, _handle_lobbyAddRpcRejected.bind(device_id))

@rpc("reliable")
func _handle_lobbyAddRpcRejected(device_id: int) -> void :
	loadoutInputProcessor.unregisterDevice(device_id)

func onDeviceDisconnected(deviceId: int) -> void :
	Network.rpc_server(Lobby.remove.bind(deviceId, Keepers.local.getCount()))

	var keepers = Keepers.local.getAll()
	for keeper: Keeper in keepers:
		if keeper.deviceId != deviceId:
			continue
		var isLastLocalKeeper: bool = keepers.size() < 2
		if isLastLocalKeeper and not GameWorld.isSplitScreen():
			_local_switch_device(deviceId, InputProcessor.KEYBOARD_AND_MOUSE_DEVICE_ID)
		else:
			Keepers.unregisterKeeper(keeper)

func _local_switch_device(old_device_id: int, new_device_id: int) -> void :
	assert (Network.is_client())
	var localKeeperToUpdate: Keeper = Keepers.getLocalKeeperByDeviceId(old_device_id)
	if is_instance_valid(localKeeperToUpdate):
		var lk: LoadoutKeeper = Level.loadout.getLoadoutKeeperByDeviceId(new_device_id)
		localKeeperToUpdate.deviceId = new_device_id
		lk.deviceId = new_device_id
		if StageManager.currentStage is MultiplayerLoadoutStage:
			StageManager.currentStage.updateKeeperDeviceId(localKeeperToUpdate)

	for keeper: LoadoutKeeper in Level.loadout.keepers:
		if keeper.deviceId == old_device_id:
			keeper.deviceId = new_device_id

func on_lobby_member_added(member: Lobby.Member) -> void :
	var player_id: = Utils.decode_player_id(member.player_id)
	var lk = Level.loadout.getLoadoutKeeperByPlayerId(player_id)
	lk.playerId = player_id
	lk.playerName = Utils.get_player_name(lk.playerId, member.peer_id, member.device_id)
	lk.deviceId = member.device_id
	lk.peerId = member.peer_id
	lk.teamId = Utils.decode_team_id(member.team_id)
	lk.platformId = member.platform_user_id
	lk.platformName = member.platform_id
	lk.playfabId = member.playfab_id

	var nextColor: = Utils.get_next_player_color()
	lk.colorId = Utils.decode_color_id(nextColor)

	member.skin_id = int(lk.skinId.lstrip("skin"))
	member.color_id = nextColor
	member.keeper_id = int(lk.keeperId.lstrip("keeper"))

	Audio.sound("loadout_keeper_join")

	updatePlayerNames.call_deferred()

	spawn_keeper(lk)

func spawn_existing_member(member: Lobby.Member) -> void :
	var lk = Level.loadout.getLoadoutKeeperByDeviceId(member.device_id)
	lk.playerId = "player%d" % member.player_id
	lk.deviceId = member.device_id
	lk.peerId = member.peer_id
	lk.playerName = Utils.get_player_name(lk.playerId, lk.peerId, lk.deviceId)
	lk.teamId = "team%d" % member.team_id
	lk.skinId = "skin%d" % member.skin_id
	lk.colorId = "color%d" % member.color_id
	lk.keeperId = "keeper%d" % member.keeper_id
	lk.platformId = member.platform_user_id
	lk.platformName = member.platform_id
	lk.playfabId = member.playfab_id

	spawn_keeper(lk)

func spawn_keeper(lk: LoadoutKeeper) -> void :
	Lobby.send_lobby_update()
	var spawnPosition: Vector2
	if not GameWorld.getFiguredOutMovementInLoadout():
		_UI.visible = false
		spawnPosition = _KeeperSpawnPositionInitial.position
	else:
		spawnPosition = Vector2.ZERO
		spawnPosition = _KeeperSpawnPosition.position
		spawnPosition += Vector2.ONE.rotated(randf_range( - PI, PI)) * 10
	lk.position = spawnPosition

	if isReloadingDueLanguageChange:
		loadoutKeeperSpawner.spawn_from_bytes(lk.to_bytes())
	else:
		loadoutKeeperSpawner.network_spawn(lk.to_bytes())

	onKeepersChanged()

func onLobbyMemberRemoved(member: Lobby.Member) -> void :
	if member.peer_id == multiplayer.get_unique_id():
		loadoutInputProcessor.unregisterDevice(member.device_id)

	if multiplayer.is_server():
		loadoutKeeperSpawner.network_despawn(member.peer_id, member.device_id)
	onKeepersChanged()

	updatePlayerNames.call_deferred()

	Audio.sound("loadout_keeper_leave")

func updatePlayerNames() -> void :
	if Lobby.members.size() == 0:
		return
	for lk in Level.loadout.keepers:
		var newPlayerName = Utils.get_player_name(lk.playerId, lk.peerId, lk.deviceId)
		lk.playerName = newPlayerName
		lk.keeper.updatePlayerName(newPlayerName)

func onLobbyMemberColorUpdated(member: Lobby.Member) -> void :
	for lk: LoadoutKeeper in Level.loadout.keepers:
		if lk.playerId == "player%d" % member.player_id:
			lk.colorId = "color%d" % member.color_id
			lk.keeper.setSkin("skin%d" % member.skin_id, "color%d" % member.color_id)

	for goblin in get_tree().get_nodes_in_group("keeper4_goblins"):
		if goblin.playerId == "player%d" % member.player_id:
			goblin.set_color()

	for goblin_hole in get_tree().get_nodes_in_group("goblin_holes"):
		if goblin_hole.playerId == "player%d" % member.player_id:
			goblin_hole.set_color()

func onLobbyMemberDevicedUpdated(peer_id: int, old_device_id: int, new_device_id: int) -> void :
	for lk: LoadoutKeeper in Level.loadout.keepers:
		if lk.peerId == peer_id and lk.deviceId == old_device_id:
			lk.deviceId = new_device_id
			lk.keeper.deviceId = new_device_id
			updateKeeperDeviceId(lk.keeper)
			return

func sendStageSpawnPackets(peer_id: int) -> void :
	var spawnBytes: = PackedByteStream.new()
	spawnBytes.encode_u8(Level.loadout.keepers.size())
	for lk: LoadoutKeeper in Level.loadout.keepers:
		var lkBytes: = lk.to_bytes()
		spawnBytes.encode_u8(lkBytes.size())
		spawnBytes.append_array(lkBytes)
	loadoutKeeperSpawner.spawn_initial.rpc_id(peer_id, spawnBytes.data)

func addKeeper(keeper: Keeper):
	$Viewports.addKeeper(keeper)

func onRemoveKeeper(keeper: Keeper):
	updateStartRunButton()
	loadoutInputProcessor.unregisterDevice(keeper.deviceId)
	Keepers.unregisterKeeper(keeper)
	_AssignmentChoice.setPLayerCount(Level.loadout.keepers.size())
	update_keeper4_entrance_hole_visibility()

func onKeeperSpawned(keeper):
	_AssignmentChoice.setPLayerCount(Level.loadout.keepers.size())
	update_keeper4_entrance_hole_visibility()

func onKeeperReplaced(new_keeper: Keeper, old_keeper: Keeper) -> void :
	killKeeper(old_keeper)
	update_keeper4_entrance_hole_visibility()

func onKeeperUnregistered(keeper: Keeper) -> void :
	killKeeper(keeper)
	_teamSelectionTeam1.updateTeamPlayerNameList()
	_teamSelectionTeam2.updateTeamPlayerNameList()

func killKeeper(keeper: Keeper) -> void :
	keeper.kill()
	if inputProcessorsByKeeper.has(keeper):
		inputProcessorsByKeeper[keeper].desintegrate()
		inputProcessorsByKeeper[keeper].keeper = null
		inputProcessorsByKeeper.erase(keeper)

func networkChangeKeeper(keeper: Keeper, techId: String):
	resetPersistMetaCooldown()

	if multiplayer.is_server():
		changeKeeper(keeper.playerId, techId)
	else:
		keeper.synchronizer.paused = true
		changeKeeper.rpc_id(1, keeper.playerId, techId)

	Level.loadout.saveKeepersToTemplates()

func updatePlayerIds():
	var keepers: = Keepers.getAll()
	for keeper in keepers:
		if keeper.visible:
			keeper.init()
			match keeper.techId:
				"keeper1":
					Data.apply(keeper.playerId + ".keeper1.maxSpeed", 180)
				"keeper2":
					Data.apply(keeper.playerId + ".keeper2.maxSpeed", 200)
					Data.apply(keeper.playerId + ".keeper2.acceleration", 110)
					Data.apply(keeper.playerId + ".keeper2.deceleration", 5)
				"keeper3":
					pass
				"keeper4":
					Data.apply(keeper.playerId + ".keeper4.movespeed", 300)


@rpc("reliable", "any_peer")
func serverStartRunSelected() -> void :
	if is_instance_valid(_startRunChoiceGroup) and _startRunChoiceGroup.visible and _startRunChoiceGroup.isAnyPeerOutsideStartButton():
		return
	startRun()

func startRun():
	if quitting or startedRun or (is_instance_valid(_startRunChoice) and _startRunChoice.visible and _startRunChoice.disabled) or \
	(is_instance_valid(_startRunChoiceGroup) and _startRunChoiceGroup.visible and _startRunChoiceGroup.disabled):
		return

	startedRun = true

	if is_instance_valid(_startRunChoice):
		_startRunChoice.set_enabled(false)
	if is_instance_valid(_startRunChoiceGroup):
		_startRunChoiceGroup.set_enabled(false)

	networkSound("gui_loadout_startrun")
	for loadoutKeeper in Level.loadout.keepers:
		if loadoutKeeper.keeper == null:
			return
		loadoutKeeper.playerId = loadoutKeeper.keeper.playerId


	if Level.loadout.modeId != CONST.MODE_ASSIGNMENTS:
		for dome: LoadoutDome in Level.loadout.domes:
			dome.additionalGadgets.clear()

	match Level.loadout.modeId:
		CONST.MODE_PRESTIGE:
			if Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_FRIENDLY_MODE, false):
				Level.loadout.difficultyByTeamId["team1"] = -2
			else:
				Level.loadout.difficultyByTeamId["team1"] = 0
			GameWorld.lastLeaderboardSection = ""
			GameWorld.lastLeaderboardMultiplayer = ""
		CONST.MODE_ASSIGNMENTS:
			if Level.loadout.modeConfig.get(CONST.MODE_CONFIG_ASSIGNMENT_CHALLENGE_MODE, false):
				Level.loadout.difficultyByTeamId["team1"] = 0
			else:
				Level.loadout.difficultyByTeamId["team1"] = 0
		CONST.MODE_VERSUS:
			Level.loadout.modeConfig[CONST.MODE_CONFIG_WORLDMODIFIERS] = []
			for teamId in ["team1", "team2"]:
				for mod in Level.loadout.modeConfig.get(CONST.MODE_CONFIG_VERSUSMODIFIERS + teamId, []):
					if not Level.loadout.modeConfig[CONST.MODE_CONFIG_WORLDMODIFIERS].has(mod):
						Level.loadout.modeConfig[CONST.MODE_CONFIG_WORLDMODIFIERS].append(mod)


	Level.loadout.difficultyByTeamId["map"] = Level.loadout.difficultyByTeamId["team1"]

	var startData = LevelStartData.new()
	startData.loadout = Level.loadout.asLoadout()

	if GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
		startData.tileDataPresetId = "Exhibition"

	GameWorld.setLastLoadoutsByMode("last", Level.loadout.duplicate())
	Level.randomizeSeed()

	Audio.stopMusic()
	for client in Network.clients:
		client.start_stage("stages/client/loading")

	for ki: InputProcessor in inputProcessorsByKeeper.values():
		ki.desintegrate()

	StageManager.startStage("stages/landing/landing", [startData])

func _on_StartRunChoice_select():
	Network.rpc_server(serverStartRunSelected)

func getNewHintContainer(descKey: String = ""):
	var hc = preload("res://stages/loadout/HintContainer.tscn").instantiate()
	hc.setHint(tr(descKey))
	_hintContainers.add_child(hc)
	return hc

func updateAllHintContainerPositions():
	for x in _hintContainers.get_children():
		x.shouldUpdatePosition()

func startStationInput(keeper, station):
	var i = preload("res://content/dome/station/BattleInputProcessor.gd").new()
	i.popup = preload("res://stages/level/BattlePopup.tscn").instantiate()
	i.popup.showExitHints()
	var dome = Level.domesByTeamId[keeper.teamId]
	i.domeId = dome.techId
	i.teamId = keeper.teamId
	i.stationIndex = station.getIndex()
	i.popup.init(dome.techId, keeper.teamId, keeper.deviceId)
	$CanvasLayer / AreaLimiter.add_child(i.popup)
	i.popup.moveIn()
	i.deviceId = keeper.deviceId
	i.controlledWeapons = station.getControlledWeapons()
	i.connect("onStop", keeper.exitStation)
	i.connect("onStop", station.exitStation)
	i.connect("onStop", i.popup.moveOut)
	i.integrate(self)

func register_action_hint(action: String, label: String) -> int:
	return -1

func set_action_hint_visible(index: int, value: bool):
	pass

func _on_loadout_choice_friendly_mode_toggled(toggled: bool) -> void :
	resetPersistMetaCooldown()
	onLoadoutChoiceSelected(setFriendlyMode.bind(toggled))

@rpc("reliable", "any_peer")
func setFriendlyMode(toggled: bool) -> void :
	networkSound("gui_select")
	Level.loadout.modeConfig[CONST.MODE_CONFIG_PRESTIGE_FRIENDLY_MODE] = toggled
	_LoadoutChoiceFriendlyMode.selected = toggled
	updateClientLoadout()

func _on_loadout_choice_pro_mode_select(keeper: Keeper) -> void :
	Network.rpc_server(requestOpenProModePopup.bind(multiplayer.get_unique_id(), keeper.playerId))

@rpc("reliable", "any_peer")
func requestOpenProModePopup(senderId: int, playerId: String) -> void :
	if proModePopupOpen:
		return

	proModePopupOpen = true
	networkSetProModeButtonEnabled(false)
	Network.rpc_or_local(senderId, openProModePopup.bind(playerId))

func networkSetProModeButtonEnabled(enabled: bool) -> void :
	Network.rpc_if_state(setProModeButtonEnabled.bind(enabled), Network.ConnectionState.LOADOUT_STAGE_SYNC, true)

@rpc("reliable")
func setProModeButtonEnabled(enabled: bool) -> void :
	_LoadoutChoiceProMode.set_enabled(enabled, false)

@rpc("reliable")
func openProModePopup(playerId: String) -> void :
	var keeper: = Keepers.getKeeper(playerId)
	Audio.sound("gui_select")
	var i = preload("res://gui/PopupInput.gd").new()
	var popup = preload("res://stages/loadout/ProModeContainer.tscn").instantiate()
	Level.stage.pause()

	i.deviceId = keeper.deviceId
	i.popup = popup
	i.blockAllKeys = true
	i.blockStickMove = true
	i.globalInput = true
	i.connect("onStop", Audio.sound.bind("gui_back"))
	i.connect("onStop", popup.queue_free)
	i.connect("onStop", Level.stage.unpause)
	i.connect("onStop", resetPersistMetaCooldown)
	i.connect("onStop", networkReleaseProModePopup)
	if multiplayer.is_server():
		i.onStop.connect(updateClientLoadout)
	else:
		i.onStop.connect(clientSelectCustomSettings)

	$CanvasLayer.add_child(i.popup)
	i.integrate(self)

func networkReleaseProModePopup() -> void :
	Network.rpc_server(releaseProModePopup)

@rpc("reliable", "any_peer")
func releaseProModePopup() -> void :
	proModePopupOpen = false
	networkSetProModeButtonEnabled(true)

func clientSelectCustomSettings() -> void :
	Network.rpc_server(setServerCustomSettings.bind(GameWorld.serializeCustomSettings()))

@rpc("reliable", "any_peer")
func setServerCustomSettings(customSettings: Dictionary) -> void :
	GameWorld.deserializeCustomSettings(customSettings)
	updateClientLoadout()

func resetPersistMetaCooldown():
	persistMetaCooldown = 1.0

func _on_loadout_choice_zoom_1_toggled(b: Variant) -> void :
	resetPersistMetaCooldown()
	networkSound("gui_confirm")
	_loadoutChoiceZoom2.selected = false
	GameWorld.goalCameraZoomLoadout = 4
	$Viewports.update_and_network_viewport_sizes(Vector2.ONE * GameWorld.getEffectiveLoadoutZoom())

func _on_loadout_choice_zoom_2_toggled(b: Variant) -> void :
	resetPersistMetaCooldown()
	networkSound("gui_confirm")
	_loadoutChoiceZoom1.selected = false
	GameWorld.goalCameraZoomLoadout = 3
	$Viewports.update_and_network_viewport_sizes(Vector2.ONE * GameWorld.getEffectiveLoadoutZoom())

func ensureDelayBetweenMajorActions():
	if Time.get_ticks_msec() - lastMajorActionTime < 500:
		return true

	lastMajorActionTime = Time.get_ticks_msec()
	return false

func _on_drop_deleter_body_entered(body: Node2D) -> void :
	body.shrink("team1")

func onLocaleChanged():
	quitting = true
	if multiplayer.is_server():
		levelStartData = [LANGUAGE_RELOAD_MARK]
	else:
		levelStartData.append(LANGUAGE_RELOAD_MARK)

	for ip in inputProcessorsByKeeper.values():
		ip.desintegrate()
	StageManager.startStage("stages/loadout/multiplayerloadout", levelStartData)

func on_loadout_keeper_spawned(lk: LoadoutKeeper):
	if multiplayer.is_server():
		updatePlayerIds()
	else:
		lk.keeper.init()

	lk.keeper.set_multiplayer_authority(lk.keeper.peerId)

	var tentacles = lk.keeper.get_node_or_null("Tentacles")
	if tentacles:
		tentacles.grid_attach_enabled = true

	onKeepersChanged()
	updateStartRunButton()

	for l in get_tree().get_nodes_in_group("gamepadListeners"):
		l.onInputMethodChanged()

	if lk.keeper.peerId != multiplayer.get_unique_id():
		return

	GameWorld.ostKeeperId = lk.keeperId
	Audio.fadeIntro()



	add_input_processor_for_keeper.call_deferred(lk)

func add_input_processor_for_keeper(lk: LoadoutKeeper) -> void :
	var id = lk.keeper.techId.capitalize().replace(" ", "")
	var keeperInputProcessor: KeeperInputProcessor = load("res://content/keeper/" + id + "InputProcessor.gd").new()
	keeperInputProcessor.keeper = lk.keeper
	keeperInputProcessor.playerId = lk.keeper.playerId
	keeperInputProcessor.deviceId = lk.deviceId
	keeperInputProcessor.runningInLoadout = true
	keeperInputProcessor.integrate(self)
	inputProcessorsByKeeper[lk.keeper] = keeperInputProcessor

@rpc("any_peer", "reliable")
func changeKeeper(playerId: String, techId: String):
	networkSound("loadout_skin")
	loadoutKeeperSpawner.network_replace(playerId, techId)

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

func updateClientLoadout() -> void :
	if multiplayer.is_server():
		updateBlockVisibility()
		Network.rpc_if_state(
			setClientLoadout.bind(Level.loadout.to_bytes(), GameWorld.unlocks.serialize(), GameWorld.serializeCustomSettings()), 
			Network.ConnectionState.LOADOUT_STAGE_SYNC
		)

func _on_loadout_choice_keeper_join_team(keeper: Keeper, teamId: String) -> void :
	if not keeper:
		return

	onLoadoutChoiceSelected(onKeeperJoinTeam.bind(keeper.playerId, teamId))

@rpc("reliable", "any_peer")
func setKeeperTeam(playerId: String, teamId: String) -> void :
	var colorOfTeam = find_child("TeamSelection" + Data.startCaptialized(teamId)).getColor()
	for k: LoadoutKeeper in Level.loadout.keepers:
		if k.playerId == playerId:
			k.teamId = teamId
			k.keeper.teamId = teamId
			k.colorId = colorOfTeam
			k.keeper.colorId = colorOfTeam
			k.keeper.setSkin(k.keeper.skinId, k.keeper.colorId)
			break

	for goblin in get_tree().get_nodes_in_group("keeper4_goblins"):
		goblin.set_color()

	for goblin_hole in get_tree().get_nodes_in_group("goblin_holes"):
		goblin_hole.set_color()

@rpc("reliable", "any_peer")
func onKeeperJoinTeam(playerId: String, teamId: String) -> void :

	if startedRun:
		return

	networkSound("gui_select")

	Network.rpc_if_state(setKeeperTeam.bind(playerId, teamId), Network.ConnectionState.LOADOUT_STAGE_SYNC, true)
	Network.rpc_if_state(Lobby.update_team_id.bind(int(playerId.lstrip("player")), int(teamId.lstrip("team"))), Network.ConnectionState.LOADOUT_STAGE_SYNC, true)

	Keepers.updateTeams()

	onKeepersChanged()
	updateClientLoadout()

func updateDeviceHints(removedDeviceID: int = -100) -> void :
	var deviceToIconMap: = {
		"keyboard": _actionKeyboard, 
		"gamepad": _actionGamepad, 
	}
	var inputTypes: = []
	for keeper in Keepers.local.getAll():
		if (keeper.deviceId == 0 or (keeper.deviceId == -1 and not Options.singleplayerUseGamepad))\
		and not inputTypes.has("keyboard"):
			if keeper.deviceId != removedDeviceID:
				inputTypes.append("keyboard")
		elif keeper.deviceId > 0 or (keeper.deviceId == -1 and Options.singleplayerUseGamepad)\
		and not inputTypes.has("gamepad"):
			if keeper.deviceId != removedDeviceID:
				inputTypes.append("gamepad")

	_actionAdaptive.conceal()
	_actionKeyboard.conceal()
	_actionGamepad.conceal()

	for type in inputTypes:
		var action = deviceToIconMap[type]
		action.display()

func onKeepersChanged():
	updateKeeperColors()
	updateDeviceHints()

	_ModifiersBox.initialize(get_run_modifiers())

	if Level.loadout.modeId != CONST.MODE_VERSUS:
		_team1Options.visible = true
		return

	_teamSelectionTeam1.updateTeamPlayerNameList()
	_teamSelectionTeam2.updateTeamPlayerNameList()


	if Keepers.getAllOfTeam("team1").size() == 0:
		_teamSelectionTeam1._on_loadout_choice_open_team_select(true)
	if Keepers.getAllOfTeam("team2").size() == 0:
		_teamSelectionTeam2._on_loadout_choice_open_team_select(true)

	var local_teams: = []
	for keeper in Keepers.local.getAll():
		if not local_teams.has(keeper.teamId):
			local_teams.append(keeper.teamId)

	_team1Options.visible = local_teams.has("team1")
	_team2Options.visible = local_teams.has("team2")

func update_keeper4_entrance_hole_visibility() -> void :
	var keeper4Present: = false
	for keeper: Keeper in Keepers.getAll():
		if keeper.techId == "keeper4":
			keeper4Present = true
			break
	var dome = Level.getDome("team1")
	if dome:
		dome.goblins.set_entrance_hole_visible(keeper4Present)

func updateKeeperColors():
	for keeper: LoadoutKeeper in Level.loadout.keepers:
		keeper.remapColorIdPerPalette = isMultiplayerMode()
	if not isMultiplayerMode():

		for member in Lobby.members:
			member.color_id = 0
		for keeper: LoadoutKeeper in Level.loadout.keepers:
			keeper.colorId = "color0"
			keeper.keeper.setSkin(keeper.skinId, keeper.colorId)
	if Level.loadout.modeId == CONST.MODE_VERSUS:
		for keeper: LoadoutKeeper in Level.loadout.keepers:
			var teamSelectionName: String = "TeamSelection" + Data.startCaptialized(keeper.teamId)
			var teamSelection: Control = find_child(teamSelectionName, true, false)
			keeper.colorId = teamSelection.getColor()
			if multiplayer.is_server() and keeper.colorId != Utils.decode_color_id(Lobby.get_member_by_player_id(keeper.playerId).color_id):
				Network.rpc_if_state(Lobby.update_color.bind(Utils.encode_player_id(keeper.playerId), Utils.encode_color_id(keeper.colorId)), Network.ConnectionState.LOADOUT_STAGE_SYNC, true)
			keeper.keeper.setSkin(keeper.skinId, keeper.colorId)
	for goblin in get_tree().get_nodes_in_group("keeper4_goblins"):
		goblin.set_color()
	for goblin_hole in get_tree().get_nodes_in_group("goblin_holes"):
		goblin_hole.set_color()
	_colorPickerCoop.visible = isMultiplayerMode() and Level.loadout.modeId != CONST.MODE_VERSUS

func mainWindowSizeChanged():
	$ViewportsTracker.position = Vector2.ZERO
	$ViewportsTracker.set_deferred("size", $Viewports.size)
	$ViewportsTracker.scale = $Viewports.scale

func _on_versus_choice_wincondition_select(wincondition: String) -> void :
	onLoadoutChoiceSelected(setVersusWinCondition.bind(wincondition))

@rpc("reliable", "any_peer")
func setVersusWinCondition(winCondition: String, updateLoadout: = true, playSound: = true) -> void :
	if playSound:
		match winCondition:
			"irondelivery": networkSound("loadout_versus_condition_iron")
			"deathmatch": networkSound("loadout_versus_condition_lastteam")
			_: networkSound("gui_select")
	Level.loadout.modeConfig[CONST.MODE_CONFIG_VERSUS_WINCONDITION] = winCondition
	for c in _versusModeWinConditions.get_children():
		c.selected = winCondition == c.id
	updateStartRunButton()
	if updateLoadout:
		updateClientLoadout()

func getTeamSelections() -> Dictionary:
	return {
		"team1": _teamSelectionTeam1.getColor(), 
		"team2": _teamSelectionTeam2.getColor()
	}

func setTeamSelection(teamSelections: Dictionary) -> void :
	for teamId in teamSelections.keys():
		match teamId:
			"team1":
				_teamSelectionTeam1.updateColorSelection(teamSelections[teamId])
			"team2":
				_teamSelectionTeam2.updateColorSelection(teamSelections[teamId])

func isMultiplayerMode() -> bool:
	return Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER


func _on_tree_exited() -> void :
	for map in pregeneratedMaps.values():
		map.queue_free()
