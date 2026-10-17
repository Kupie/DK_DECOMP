extends PanelContainer

signal legacy_leaderboard_not_found
signal legacy_leaderboard_found
signal leaderboard_score_upload_success
signal leaderboard_score_upload_failed
signal leaderboard_download_finished

const CHEATERBOARD = "domekeeper_prestige_cheats"

var leaderboardName = "domekeeper_prestige_weekly"

var leaderboardGridContainers: = {}
var friendLeaderboardGridContainers: = {}

var leaderboardGlobalEntriesByLeadberboard: Dictionary
var leaderboardRelativeEntriesByLeadberboard: Dictionary
var leaderboardFriendEntriesByLeadberboard: Dictionary

var ownRank: int = -1
var ownBestScore: int
var currentScore: int = -1
var cheatHash: int
var rankCount: int
var submitted: PrestigeLeaderboardEntry

var lastDownload: = 0
var nextDownload: = 0

var first_season: int
var season: int
var currentMode: String
var friendsOrGlobal: String
var twoPlayer: bool = false
var uploadDone: = false
var friendLeaderboard: GetPlayFabFriendLeaderboard

var loadedBoards: = []

var entryCount: = 13
var currentCount: = 0

var mode_to_button_map: = {}

func _ready():


	match BuildCustomization.features["playfab_leaderboard_setup"]:
		BuildCustomization.PlayfabLeaderboardMode.STEAM:
			first_season = 1
			season = 8
		BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_SOLO:

			first_season = 0
			season = 0
		BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_MULTI:
			first_season = 8
			season = 8
		BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_SOLO_MULTI:
			first_season = 0
			season = 8
		_:
			assert (false)

	Platform.connectToLegacyLeaderboardCallbacks(leagcy_leaderboard_Find_Result, leagcy_leaderboard_Scores_Downloaded, leagcy_leaderboard_Score_Uploaded)
	PlayFabServices.leaderboard_loaded.connect(leaderboard_loaded)
	PlayFabServices.load_leaderboard_failed.connect(load_leaderboard_failed)
	legacy_leaderboard_not_found.connect(load_leaderboard_failed)
	PlayFabServices.leaderboard_around_entity_loaded.connect(leaderboard_around_entity_loaded)

	friendLeaderboard = GetPlayFabFriendLeaderboard.new()
	friendLeaderboard.load_leaderboard_failed.connect(load_leaderboard_failed)
	friendLeaderboard.leaderboard_loaded.connect(friend_leaderboard_loaded)
	add_child(friendLeaderboard)

	PlayFabServices.score_submitted.connect(score_submitted)
	PlayFabServices.score_submission_failed.connect(score_submission_failed)

	if lastRunWasFriendlyMode():
		%ButtonShowFriends.visible = false
		%ButtonShowGlobal.visible = false
		%VSeparatorFriends.visible = false
		friendsOrGlobal = "friends"
	else:
		if GameWorld.lastLeaderboardSection == "friends":
			friendsOrGlobal = "friends"
			%ButtonShowFriends.button_pressed = true
			%LeaderboardContainers.visible = false
			%FriendLeaderboardContainers.visible = true
		else:
			friendsOrGlobal = "global"
			%ButtonShowGlobal.button_pressed = true
			%LeaderboardContainers.visible = true
			%FriendLeaderboardContainers.visible = false

	match BuildCustomization.features["playfab_leaderboard_setup"]:
		BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_SOLO:
			GameWorld.lastLeaderboardMultiplayer = "singleplayer"
			%VSeparatorFriends.visible = false
			%ButtonShowSingleplayer.visible = false
			%ButtonShowMultiplayer.visible = false
		BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_MULTI:
			GameWorld.lastLeaderboardMultiplayer = "twoplayer"

	if GameWorld.lastLeaderboardMultiplayer == "" or not multiplayer.is_server():
		if lastRunWasMultiplayer():
			GameWorld.lastLeaderboardMultiplayer = "twoplayer"
		else:
			GameWorld.lastLeaderboardMultiplayer = "singleplayer"

	if GameWorld.lastLeaderboardMultiplayer == "singleplayer":
		twoPlayer = false
		%ButtonShowSingleplayer.button_pressed = true
	else:
		twoPlayer = true
		%ButtonShowMultiplayer.button_pressed = true

	var seasonButtonsContainer = find_child("SeasonButtons")
	var label = seasonButtonsContainer.find_child("Label")
	label.text = tr("leaderboard.season").format({"season": ""}).strip_edges()
	var bg = ButtonGroup.new()
	var buttonCounter = 0;
	for i in range(first_season, 1 + season):
		if not BuildCustomization.features["playfab_leaderboard_setup"] == BuildCustomization.PlayfabLeaderboardMode.STEAM:
			if i > 0 and i < 8:
				continue
		buttonCounter += 1
		var button = Button.new()
		button.disabled = true
		button.toggle_mode = true
		button.text = str(buttonCounter)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.button_pressed = i == season
		button.connect("pressed", setSeason.bind(i))
		button.connect("pressed", Audio.sound.bind("gui_select"))
		button.button_group = bg
		seasonButtonsContainer.add_child(button)

	for button in find_child("ModeButtons").get_children():
		var modeName = button.name.substr(10).to_lower()
		button.connect("pressed", setMode.bind("prestige-" + modeName))
		button.connect("pressed", Audio.sound.bind("gui_select"))

	Style.init(self)

func refresh_selection():
	for button: Button in find_child("ModeButtons").get_children():
		if button.button_pressed:
			button.pressed.emit()
			return
	printerr("Refreshing leaderboard selection but none is selected")

func lastRunWasFriendlyMode() -> bool:
	return Level.loadout and Level.loadout.modeId == "prestige" and Level.loadout.modeConfig.get("friendly-mode", false)

func lastRunWasMultiplayer() -> bool:
	return Level.loadout and Level.loadout.modeId == "prestige" and Level.loadout.keepers.size() > 1

func setButtonsDisabled(disabled: bool):
	%ButtonShowFriends.disabled = disabled
	%ButtonShowGlobal.disabled = disabled
	%ButtonShowSingleplayer.disabled = disabled
	%ButtonShowMultiplayer.disabled = disabled
	for button in find_child("SeasonButtons").get_children():
		if button is Button:
			button.disabled = disabled
	for button in find_child("ModeButtons").get_children():
		button.disabled = disabled

	%LeaderboardLoadingLabel.visible = disabled

	if disabled:
		for board in %LeaderboardContainers.get_children():
			board.visible = false
		for board in %FriendLeaderboardContainers.get_children():
			board.visible = false
	else:
		updateVisibleBoard()

func start(currentMode: String, showSeasonControls: = true, showModeControls: = false, wait_for_upload: = false):
	self.currentMode = currentMode

	find_child("ButtonMode" + currentMode.substr(9).capitalize()).button_pressed = true
	find_child("SeasonButtons").visible = showSeasonControls
	find_child("ModeButtons").visible = showModeControls


	if CheatDetection.isRunning:
		cheatHash = CheatDetection.stop()
		Backend.event("cheat_stats", {"cheatHash": cheatHash})

	updateLeaderboardName()

	if not wait_for_upload:
		if season <= 7 and Platform.hasLegacyLeaderboards():
			setButtonsDisabled(true)
			%LeaderboardLoadingLabel.text = "leaderboard.loading"
			Platform.findLegacyLeaderboard(leaderboardName)
		elif GameWorld.is_allowOnlineMultiplayer():
			setButtonsDisabled(true)
			%LeaderboardLoadingLabel.text = "leaderboard.loading"

			var version: = -1 if leaderboardName.begins_with(CHEATERBOARD) else season
			friendLeaderboard.get_leaderboard(leaderboardName, version)
			PlayFabServices.get_leaderboard(leaderboardName, 1, entryCount, version)
			PlayFabServices.get_leaderboard_around(leaderboardName, 4, version)
		else:
			%LeaderboardLoadingLabel.text = "leaderboard.needsOnlineServices"

func updateLeaderboardName():
	if cheatHash > 0:
		leaderboardName = CHEATERBOARD
	else:
		match BuildCustomization.features["playfab_leaderboard_setup"]:
			BuildCustomization.PlayfabLeaderboardMode.STEAM:
				match season:
					1:
						leaderboardName = "domekeeper_prestige_weekly"
					2, 3, 4, 5, 6, 7:
						leaderboardName = "domekeeper_prestige_season" + str(season)
					_:
						leaderboardName = "domekeeper_prestige_season"
			BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_SOLO: leaderboardName = "domekeeper_prestige_console"
			BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_MULTI: leaderboardName = "domekeeper_prestige_season"
			BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_SOLO_MULTI:
				match season:
					0: leaderboardName = "domekeeper_prestige_console"
					8: leaderboardName = "domekeeper_prestige_season"

		match currentMode:
			CONST.MODE_PRESTIGE_ENDLESS:

				pass
			CONST.MODE_PRESTIGE_COBALT:
				leaderboardName += "_cobalt"
			CONST.MODE_PRESTIGE_COUNTDOWN:
				leaderboardName += "_countdown"
			CONST.MODE_PRESTIGE_PROVOCATION:
				leaderboardName += "_provocation"
			CONST.MODE_PRESTIGE_MINER:
				leaderboardName += "_miner"

	if twoPlayer:
		leaderboardName += "_twoplayer"

	if lastRunWasFriendlyMode() and cheatHash == 0:
		leaderboardName += "_friendly"

	Logger.info("Goal leaderboard is %s" % leaderboardName, "PrestigeLeaderboard.updateLeaderboardName")

func setOwnRank(ownRank):
	self.ownRank = ownRank

func leagcy_leaderboard_Find_Result(handle: int, found: int) -> void :
	if found == 1:
		Logger.info("Leaderboard found")
		GameWorld.leaderboardHandles[leaderboardName] = handle
		onLegacyLeaderboardFound()
	else:
		Logger.error("Leaderboard not found")
		emit_signal("legacy_leaderboard_not_found", "Leaderboard not found")

func ensureGridContainerExists(id: String):
	if leaderboardGridContainers.has(id):
		return

	var new_container = %LeaderboardContainer.duplicate()
	%LeaderboardContainers.add_child(new_container)
	leaderboardGridContainers[id] = new_container
	new_container = %LeaderboardContainer.duplicate()
	%FriendLeaderboardContainers.add_child(new_container)
	friendLeaderboardGridContainers[id] = new_container

func fillLeaderboards():
	var id: = get_currently_selected_leaderboard_id()
	if loadedBoards.has(id):


		push_warning("Tried to fill leaderboard with a leaderboard that has already been loaded: ", id)
		return

	rankCount = 1
	currentCount = 0
	ensureGridContainerExists(id)
	var c = leaderboardGridContainers.get(id)

	var isTop10: = false
	var i: = 0
	var count: = entryCount if ownRank <= entryCount else entryCount - 6

	for entry: PrestigeLeaderboardEntry in leaderboardGlobalEntriesByLeadberboard.get(id, []):
		if i >= count:
			break

		if entry.is_self():
			isTop10 = true
		addRow(entry, c)

		i += 1
		currentCount += 1

	if not isTop10 and ownRank != -1:
		c.add_child(Control.new())
		var l = Label.new()
		l.text = "..."
		c.add_child(l)
		c.add_child(Control.new())
		c.add_child(Control.new())
		c.add_child(Control.new())
		c.add_child(Control.new())
		currentCount += 1

		for entry: PrestigeLeaderboardEntry in leaderboardRelativeEntriesByLeadberboard.get(id, []):
			addRow(entry, c)
			currentCount += 1

	rankCount = 1
	currentCount = 0
	c = friendLeaderboardGridContainers.get(id)
	for entry: PrestigeLeaderboardEntry in leaderboardFriendEntriesByLeadberboard.get(id, []):
		addRow(entry, c)

func getRank(entry: PrestigeLeaderboardEntry) -> int:
	var rank: int
	if lastRunWasFriendlyMode():
		rank = rankCount
		rankCount += 1
	else:
		rank = entry.rank
	return rank

func addRow(entry: PrestigeLeaderboardEntry, container):
	if currentCount >= entryCount:
		push_warning("Trying to add too many rows to the prestige leaderboard.")


		if not GameWorld.devMode:
			return

	var l = Label.new()
	l.text = "#" + str(getRank(entry))
	l.custom_minimum_size.x = 30
	if entry.is_self():
		l.label_settings = preload("res://gui/fontsettings/NumbersFontSettingsHighlighted.tres")
	else:
		l.label_settings = preload("res://gui/fontsettings/NumbersFontSettings.tres")
	container.add_child(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l = preload("res://gui/platform/gamertag/GamerTagLabel.tscn").instantiate()
	l.icon_size = 40
	var entry_platform_id = entry.get_platform_id_string()
	if entry.is_self():
		l.set_gamer_tag(Utils.clip_text(entry.display_name, 24), entry_platform_id)
	else:
		l.set_gamer_tag_for_menu(Utils.clip_text(entry.display_name, 24), entry_platform_id, _on_profile_button_pressed.bind(entry))
	var gamertag_label = l.find_child("NameLabel")
	l.size_flags_horizontal = Control.SIZE_EXPAND
	gamertag_label.max_lines_visible = 1
	gamertag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gamertag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if entry.is_self():
		gamertag_label.label_settings = preload("res://gui/fontsettings/NormalFontSettingsHighlighted.tres")
	else:
		gamertag_label.label_settings = preload("res://gui/fontsettings/NormalFontSettings.tres")
	container.add_child(l)

	container.add_child(getTextureRectFor(0, entry.dome_id))
	container.add_child(getTextureRectFor(1, entry.keeper_id))
	container.add_child(getTextureRectFor(2, entry.gadget_id))

	l = Label.new()
	l.text = "%5.0f" % entry.score
	l.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if entry.is_self():
		l.label_settings = preload("res://gui/fontsettings/NumbersFontSettingsHighlighted.tres")
	else:
		l.label_settings = preload("res://gui/fontsettings/NumbersFontSettings.tres")
	container.add_child(l)

func getTextureRectFor(col: int, value: int) -> TextureRect:
	var s = TextureRect.new()
	match col:
		0:
			match value:
				1: s.texture = preload("res://content/gamemode/prestige/leaderboard/dome1.png")
				2: s.texture = preload("res://content/gamemode/prestige/leaderboard/dome2.png")
				3: s.texture = preload("res://content/gamemode/prestige/leaderboard/dome3.png")
				4: s.texture = preload("res://content/gamemode/prestige/leaderboard/dome4.png")
				_:
					Logger.error("missing icon for prestige leaderboard column %d, index %d" % [col, value])
		1:
			match value:
				1: s.texture = preload("res://content/gamemode/prestige/leaderboard/keeper1.png")
				2: s.texture = preload("res://content/gamemode/prestige/leaderboard/keeper2.png")
				3: s.texture = preload("res://content/gamemode/prestige/leaderboard/keeper3.png")

				0: s.texture = preload("res://content/gamemode/prestige/leaderboard/keeper4.png")
				_:
					Logger.error("missing icon for prestige leaderboard column %d, index %d" % [col, value])
		2:
			match value:
				1: s.texture = preload("res://content/gamemode/prestige/leaderboard/gadget3.png")
				2: s.texture = preload("res://content/gamemode/prestige/leaderboard/gadget2.png")
				3: s.texture = preload("res://content/gamemode/prestige/leaderboard/gadget1.png")
				4: s.texture = preload("res://content/gamemode/prestige/leaderboard/gadget4.png")
				_:
					Logger.error("missing icon for prestige leaderboard column %d, index %d" % [col, value])
	if s.texture:
		s.custom_minimum_size = s.texture.get_size() * 2
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return s

func is_fully_loaded(cache_name: String) -> bool:

	if cache_name != get_currently_selected_leaderboard_id():
		return false

	return leaderboardRelativeEntriesByLeadberboard.has(cache_name) and leaderboardFriendEntriesByLeadberboard.has(cache_name) and leaderboardGlobalEntriesByLeadberboard.has(cache_name)

func mark_loaded(cache_name: String) -> void :
	fillLeaderboards()
	if not loadedBoards.has(cache_name):
		loadedBoards.append(cache_name)
	setButtonsDisabled(false)

func leaderboard_around_entity_loaded(result: Dictionary) -> void :
	var prevBestScore: = ownBestScore
	var prevOwnRank: = ownRank
	ownRank = -1
	ownBestScore = 0
	if result["name"] == leaderboardName:

		for entry in result["entries"]:
			if entry["entity_id"] == PlayFabServices.get_entity_id():
				ownRank = entry["rank"]
				ownBestScore = entry["Score"].to_int()
				if currentScore != -1:
					uploadDone = true
					leaderboard_score_upload_success.emit(1 if ownBestScore != prevBestScore and currentScore != 0 else 0, ownRank, prevOwnRank, leaderboardName)


	var cache_name: String = "%s_%d" % [result["name"], result["version"]]
	if result["name"] == CHEATERBOARD:
		cache_name = CHEATERBOARD
	leaderboardRelativeEntriesByLeadberboard[cache_name] = []
	for entry_dict in result["entries"]:
		leaderboardRelativeEntriesByLeadberboard[cache_name].append(
			PrestigeLeaderboardEntry.from_playfab_leaderboard(entry_dict)
		)

	if is_fully_loaded(cache_name):
		mark_loaded(cache_name)

func friend_leaderboard_loaded(result: Dictionary) -> void :
	var cache_name: String = "%s_%d" % [result["name"], result["version"]]
	if result["name"] == CHEATERBOARD:
		cache_name = CHEATERBOARD
	leaderboardFriendEntriesByLeadberboard[cache_name] = []
	for entry_dict in result["entries"]:
		leaderboardFriendEntriesByLeadberboard[cache_name].append(
			PrestigeLeaderboardEntry.from_playfab_leaderboard(entry_dict)
		)

	if is_fully_loaded(cache_name):
		mark_loaded(cache_name)

func leaderboard_loaded(result: Dictionary) -> void :
	var cache_name: String = "%s_%d" % [result["name"], result["version"]]
	if result["name"] == CHEATERBOARD:
		cache_name = CHEATERBOARD
	leaderboardGlobalEntriesByLeadberboard[cache_name] = []
	for entry_dict in result["entries"]:
		leaderboardGlobalEntriesByLeadberboard[cache_name].append(
			PrestigeLeaderboardEntry.from_playfab_leaderboard(entry_dict)
		)

	if is_fully_loaded(cache_name):
		mark_loaded(cache_name)

func load_leaderboard_failed(error: String) -> void :
	push_error("Failed to load leaderboard: ", error)
	setButtonsDisabled(false)
	match BuildCustomization.features["playfab_leaderboard_setup"]:
		BuildCustomization.PlayfabLeaderboardMode.STEAM:
			%LeaderboardLoadingLabel.text = "network.error.offline" if season >= 8 and GameWorld.is_allowOnlineMultiplayer() and not Network.is_network_ready(true) else "leaderboard.failed"
		BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_SOLO, BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_MULTI, BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_SOLO_MULTI:
			%LeaderboardLoadingLabel.text = "network.error.offline" if GameWorld.is_allowOnlineMultiplayer() and not Network.is_network_ready(true) else "leaderboard.failed"
	%LeaderboardLoadingLabel.visible = true

func onLegacyLeaderboardFound():
	downloadLegacyLeaderboard()

func downloadLegacyLeaderboard():
	if loadedBoards.has(leaderboardName):
		setButtonsDisabled(false)
		return

	setButtonsDisabled(true)

	var h = GameWorld.leaderboardHandles[leaderboardName]
	lastDownload = nextDownload
	prints("loading", leaderboardName, nextDownload)
	match nextDownload:
		0:
			ownRank = -1
			Platform.downloadLegacyLeaderboardEntries(1, entryCount, 2, h)
			nextDownload += 1
		1:
			if ownRank <= entryCount:
				nextDownload += 2
				Platform.downloadLegacyLeaderboardEntries(1, entryCount, 0, h)
			else:
				nextDownload += 1
				Platform.downloadLegacyLeaderboardEntries(1, entryCount - 6, 0, h)
		2:
			nextDownload += 1
			Platform.downloadLegacyLeaderboardEntries(max(entryCount - ownRank, -3), 1, 1, h)
		3:
			fillLeaderboards()
			loadedBoards.append(leaderboardName)
			setButtonsDisabled(false)
			emit_signal("leaderboard_download_finished")
			prints("finished loading", leaderboardName)


func leagcy_leaderboard_Scores_Downloaded(message: String, handle: int, result: Array):
	match lastDownload:
		0:
			leaderboardFriendEntriesByLeadberboard[leaderboardName] = []
			for R in result:
				var entry: = PrestigeLeaderboardEntry.from_legacy_leaderboard(R)
				leaderboardFriendEntriesByLeadberboard[leaderboardName].append(entry)

				if str(R.get("steam_id", 0)) == Platform.get_user_id():
					ownRank = R.get("global_rank", -1)
		1:
			leaderboardGlobalEntriesByLeadberboard[leaderboardName] = []
			for R in result:
				var entry: = PrestigeLeaderboardEntry.from_legacy_leaderboard(R)
				leaderboardGlobalEntriesByLeadberboard[leaderboardName].append(entry)
		2:
			leaderboardRelativeEntriesByLeadberboard[leaderboardName] = []
			for R in result:
				var entry: = PrestigeLeaderboardEntry.from_legacy_leaderboard(R)
				leaderboardRelativeEntriesByLeadberboard[leaderboardName].append(entry)

	downloadLegacyLeaderboard()

func uploadScore(score):
	currentScore = score
	if GameWorld.is_allowOnlineMultiplayer() and score > 0:
		var entry: = generateEntry(score)
		submitted = entry
		PlayFabServices.submit_score(leaderboardName, entry.get_scores(), entry.get_metadata())
	else:
		emit_signal("leaderboard_score_upload_success", 0, 0, 0, leaderboardName)
		ownRank = 0
		ownBestScore = 0

func score_submitted(result: Dictionary) -> void :

	var version: = -1 if leaderboardName.begins_with(CHEATERBOARD) else season
	friendLeaderboard.get_leaderboard(result["name"], version)
	PlayFabServices.get_leaderboard(result["name"], 1, entryCount, version)
	PlayFabServices.get_leaderboard_around(result["name"], 4, version)

func score_submission_failed() -> void :
	leaderboard_score_upload_failed.emit()

func leagcy_leaderboard_Score_Uploaded(_success: bool, _this_handle: int, _score: Dictionary) -> void :
	pass

func generateEntry(score) -> PrestigeLeaderboardEntry:
	var entry: = PrestigeLeaderboardEntry.new()
	entry.score = score
	entry.run_id = Data.ofOr("runID", -1)
	entry.dome_id = int(Level.loadout.domes.front().domeId.substr(4))

	var keeperId = Level.loadout.keepers.front().keeperId
	entry.keeper_id = int(keeperId.substr(6))

	match Level.loadout.domes.front().primaryGadgetId:
		"orchard": entry.gadget_id = 1
		"repellent": entry.gadget_id = 2
		"shield": entry.gadget_id = 3
		"droneyard": entry.gadget_id = 4
		_: entry.gadget_id = 0

	entry.world_id = int(Level.loadout.worldId.substr(5))
	entry.time = int(GameWorld.runTime)
	entry.base_per_wave = int(Data.of("team1.prestige.baseperwave"))
	entry.multiplier = int(Data.of("team1.prestige.multiplier"))
	entry.wave = int(Data.of("team1.monsters.cycle"))
	entry.won = 1 if GameWorld.won else 0
	entry.cheat_hash = cheatHash

	var versionParts = GameWorld.version.split(".")
	var versionHash = 1024 * int(versionParts[0].substr(1)) + int(versionParts[1])
	entry.version_hash = versionHash

	var modeId: int
	match Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT, ""):
		CONST.MODE_PRESTIGE_COUNTDOWN:
			modeId = 2
		CONST.MODE_PRESTIGE_MINER:
			modeId = 3
		_:
			modeId = 0

	entry.mode_variant = modeId
	entry.blocks_mined = int(GameWorld.runStats.get("team1.tiles_destroyed", 0))
	entry.travelled_distance = int(GameWorld.runStats.get("team1.travelled_distance", 0))
	entry.monsters_killed = int(GameWorld.runStats.get("team1.monsters_killed", 0))
	entry.resources_mined = int(GameWorld.runStats.get("team1.resources_mined", 0))
	entry.total_time_waves_were_present = int(Data.of("team1.monsters.wavePresentTime"))
	entry.times_saved = int(GameWorld.runStats.get("team1.saves", 0))
	entry.total_damage_taken = int(GameWorld.runStats.get("team1.damage_taken", 0))
	entry.gadgets_returned = int(GameWorld.runStats.get("team1.gadgets_returned", 0))
	entry.gadgets_shredded = int(GameWorld.runStats.get("team1.gadgets_shredded", 0))
	entry.total_iron = int(Data.of("inventory.totaliron"))
	entry.total_water = int(Data.of("inventory.totalwater"))
	entry.total_cobalt = int(Data.of("inventory.totalsand"))
	entry.times_stalled = int(GameWorld.runStats.get("team1.waves_stalled", 0))
	entry.total_stall_time = int(GameWorld.runStats.get("team1.wave_stall_time", 0))
	entry.spawn_escalation = int(GameWorld.runStats.get("team1.spawn_escalation", 0))
	entry.game_time_without_delay = int(Data.of("team1.monsters.gameTimeWithoutDelay"))
	entry.set_platform(Platform.get_platform_id())

	if Level.loadout.keepers.size() > 1:
		if Keepers.local.getCount() > 1:
			entry.with = PlayFabServices.get_entity_id()
		else:
			for keeper: LoadoutKeeper in Level.loadout.keepers:
				if keeper.playfabId != PlayFabServices.get_entity_id():
					entry.with = keeper.playfabId

	return entry

func _on_ButtonShowFriends_pressed():
	Audio.sound("gui_select")
	friendsOrGlobal = "friends"
	GameWorld.lastLeaderboardSection = "friends"
	updateVisibleBoard()

func _on_ButtonShowLeaderboard_pressed():
	Audio.sound("gui_select")
	friendsOrGlobal = "global"
	GameWorld.lastLeaderboardSection = "global"
	updateVisibleBoard()

func updateVisibleBoard():
	var id: = get_currently_selected_leaderboard_id()
	ensureGridContainerExists(id)
	if friendsOrGlobal == "friends":
		%LeaderboardContainers.visible = false
		%FriendLeaderboardContainers.visible = true
		var containerToShow = friendLeaderboardGridContainers.get(id)
		for container in %FriendLeaderboardContainers.get_children():
			container.visible = container == containerToShow
	else:
		%LeaderboardContainers.visible = true
		%FriendLeaderboardContainers.visible = false
		var containerToShow = leaderboardGridContainers.get(id)
		for container in %LeaderboardContainers.get_children():
			container.visible = container == containerToShow

func get_currently_selected_leaderboard_id() -> String:
	match season:
		1, 2, 3, 4, 5, 6, 7:
			return leaderboardName
		_:
			if leaderboardName == CHEATERBOARD:
				return CHEATERBOARD

			return "%s_%d" % [leaderboardName, season]

func setSeason(i: int):

	var modechange_boundary_passed = (season < 6 and i >= 6) or (season >= 6 and i < 6)
	if modechange_boundary_passed and BuildCustomization.features["playfab_leaderboard_setup"] == BuildCustomization.PlayfabLeaderboardMode.STEAM:
		%ButtonModeCobalt.visible = i < 6
		%ButtonModeProvocation.visible = i >= 6
		if i >= 6 and currentMode == CONST.MODE_PRESTIGE_COBALT:
			currentMode = CONST.MODE_PRESTIGE_PROVOCATION
			%ButtonModeProvocation.set_pressed_no_signal(true)
		elif i < 6 and currentMode == CONST.MODE_PRESTIGE_PROVOCATION:
			currentMode = CONST.MODE_PRESTIGE_COBALT
			%ButtonModeCobalt.set_pressed_no_signal(true)

	season = i
	startFindLeaderboard()

func setMode(mode: String):
	currentMode = mode
	startFindLeaderboard()

func startFindLeaderboard():
	updateLeaderboardName()

	if not GameWorld.is_allowOnlineMultiplayer():
		return

	if BuildCustomization.features["playfab_leaderboard_setup"] == BuildCustomization.PlayfabLeaderboardMode.PLAYFAB_SOLO_MULTI:
		if season < 8 and GameWorld.lastLeaderboardMultiplayer == "twoplayer":
			setButtonsDisabled(false)
			updateVisibleBoard()
			return

	lastDownload = 0
	nextDownload = 0
	if season <= 7 and Platform.hasLegacyLeaderboards():
		Platform.findLegacyLeaderboard(leaderboardName)
	else:
		if loadedBoards.has(get_currently_selected_leaderboard_id()):
			setButtonsDisabled(false)
			return

		var version: = -1 if leaderboardName.begins_with(CHEATERBOARD) else season
		friendLeaderboard.get_leaderboard(leaderboardName, version)
		PlayFabServices.get_leaderboard(leaderboardName, 1, entryCount, version)
		PlayFabServices.get_leaderboard_around(leaderboardName, 4, version)

	setButtonsDisabled(true)
	%LeaderboardLoadingLabel.text = "leaderboard.loading"

func _on_button_show_singleplayer_pressed() -> void :
	Audio.sound("gui_select")
	twoPlayer = false
	GameWorld.lastLeaderboardMultiplayer = "singleplayer"
	startFindLeaderboard()

func _on_button_show_multiplayer_pressed() -> void :
	Audio.sound("gui_select")
	twoPlayer = true
	GameWorld.lastLeaderboardMultiplayer = "twoplayer"
	startFindLeaderboard()

func _on_profile_button_pressed(entry: PrestigeLeaderboardEntry) -> void :
	Network.get_xuid_from_entity_id(entry.entity_id, Platform.show_player_profile_card)
