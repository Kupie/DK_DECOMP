extends Control

const DETAILS_COUNT: = 28

var leaderboardGlobalEntries: Array[PrestigeLeaderboardEntry] = []
var leaderboardSuffix: String = ""
var currentLeaderboardId: String
var handles: = {}
var twoPlayer: bool = false
var friendly: bool = false
var page: = 1
var season: = 8

func _ready():
	Engine.max_fps = 60
	Platform.init(true)
	Platform.connectToLegacyLeaderboardCallbacks(legacy_leaderboard_Find_Result, legacy_leaderboard_Scores_Downloaded, func(success: bool, this_handle: int, score: Dictionary): pass)
	PlayFabServices.logged_in.connect(on_playfab_initialized)
	PlayFabServices.leaderboard_loaded.connect(leaderboard_loaded)
	findLeaderboard("domekeeper_prestige_season")
	find_child("ButtonPrestige").button_pressed = true

	Style.init(self)
	Platform.login_to_playfab()

func findLeaderboard(id: String):
	currentLeaderboardId = id

	if season <= 7 and Platform.hasLegacyLeaderboards():
		Platform.findLegacyLeaderboard(id)

func on_playfab_initialized() -> void :
	if season >= 8:
		print(currentLeaderboardId)
		PlayFabServices.get_leaderboard(currentLeaderboardId, 100 * (page - 1) + 1, 100 * page, -1 if currentLeaderboardId.begins_with("domekeeper_prestige_cheats") else season)

func legacy_leaderboard_Find_Result(handle: int, found: int) -> void :
	if found == 1:
		Logger.info("Leaderboard found")
		handles[currentLeaderboardId] = handle
		Platform.setLegacyLeaderboardDetailsMax(DETAILS_COUNT)
		Platform.downloadLegacyLeaderboardEntries(100 * (page - 1), 100 * page, 0, handle)
	else:
		Logger.error("Leaderboard not found")
		emit_signal("leaderboard_not_found")

func legacy_leaderboard_Scores_Downloaded(message: String, unknown, result: Array):
	leaderboardGlobalEntries.clear()

	for R in result:
		var entry: = PrestigeLeaderboardEntry.from_legacy_leaderboard(R)
		leaderboardGlobalEntries.append(entry)

	fillLeaderboards()

func leaderboard_loaded(result: Dictionary) -> void :
	if result["name"] != currentLeaderboardId:

		return

	leaderboardGlobalEntries.clear()
	for R in result["entries"]:
		var entry: = PrestigeLeaderboardEntry.from_playfab_leaderboard(R)
		leaderboardGlobalEntries.append(entry)

	fillLeaderboards()

func fillLeaderboards():
	var c = find_child("GlobalLeaderboardContainer")
	var filled: = false
	for entry in leaderboardGlobalEntries:
		c.columns = max(c.columns, DETAILS_COUNT + 3)
		if not filled:
			filled = true
			c.add_child(Control.new())
			c.add_child(Control.new())
			c.add_child(Control.new())
			c.add_child(Control.new())
			c.add_child(Control.new())
			c.add_child(Control.new())
			c.add_child(label("mult x base    "))
			c.add_child(label("time"))
			c.add_child(label("waves"))
			c.add_child(label("t/w"))
			c.add_child(label("ch#"))
			c.add_child(Control.new())
			c.add_child(Control.new())
			c.add_child(label("blocks"))
			c.add_child(label("dist"))
			c.add_child(label("kills"))
			c.add_child(label("res"))
			c.add_child(label("wavetime"))
			c.add_child(label("saves"))
			c.add_child(label("dmg in"))
			c.add_child(label("gadgets returned"))
			c.add_child(label("gadgets shredded"))
			c.add_child(label("iron"))
			c.add_child(label("water"))
			c.add_child(label("cobalt"))
			c.add_child(label("stall #"))
			c.add_child(label("stall t"))
			c.add_child(label("esc #"))
			c.add_child(label("gt"))
			c.add_child(label("gt/w"))
			c.add_child(label("with"))

		entry.get_metadata()
		addRow(entry, c)

var isTrustedPlayer: bool
var isKnownCheater: bool
func addRow(entry: PrestigeLeaderboardEntry, container):
	isTrustedPlayer = CheatDetection.trustedPlayers.has(entry.entity_id)
	isKnownCheater = CheatDetection.confirmedCheaters.has(entry.entity_id)

	var l = label("#" + str(entry.rank), false)
	l.custom_minimum_size.x = 30
	l.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(l)

	if entry.display_name.length() > 24:
		l = label(entry.display_name.substr(0, 24), false)
	else:
		l = label(entry.display_name, false)


	l.size_flags_horizontal = Control.SIZE_EXPAND
	l.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(l)
	l = label(entry.entity_id, false)
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.connect("gui_input", copySteamId.bind(entry))
	container.add_child(l)

	container.add_child(getTextureRectFor(0, entry.dome_id))
	container.add_child(getTextureRectFor(1, entry.keeper_id))
	container.add_child(getTextureRectFor(2, entry.gadget_id))

	container.add_child(label(str(entry.multiplier) + " x " + str(entry.base_per_wave) + " = " + "%5.0f" % entry.score))

	container.add_child(label("%.0f" % (entry.time / 60) + "m"))
	container.add_child(label(entry.wave))
	container.add_child(label("%.1f" % entry.time_per_wave()))
	container.add_child(label(entry.cheat_hash))
	container.add_child(label("v " + str(entry.version_hash / 1024) + "." + str(entry.version_hash % 1024)))

	container.add_child(label(entry.mode_variant))
	container.add_child(label(entry.blocks_mined))
	container.add_child(label(entry.travelled_distance))
	container.add_child(label(entry.monsters_killed))
	container.add_child(label(entry.resources_mined))
	container.add_child(label("%.1f" % (entry.total_time_waves_were_present / float(entry.wave))))
	if entry.version_hash % 1024 < 6 and entry.version_hash / 1024 <= 2:
		container.add_child(label(entry.times_saved - entry.wave * 2))
	else:
		container.add_child(label(entry.times_saved - entry.wave))
	container.add_child(label(entry.total_damage_taken))
	container.add_child(label(entry.gadgets_returned))
	container.add_child(label(entry.gadgets_shredded))

	container.add_child(label(entry.total_iron))
	container.add_child(label(entry.total_water))
	container.add_child(label(entry.total_cobalt))

	container.add_child(label(entry.times_stalled))
	container.add_child(label(str(entry.total_stall_time) + "m"))
	container.add_child(label(entry.spawn_escalation))
	container.add_child(label("%.1fm" % (entry.game_time_without_delay / 60.0)))
	container.add_child(label("%.1f" % (entry.game_time_without_delay / float(entry.wave))))
	container.add_child(label(entry.with))

func copySteamId(event: InputEvent, entry: PrestigeLeaderboardEntry):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.ctrl_pressed:
			Audio.sound("tech_hover")
			var out = str(entry.entity_id) + "\t" + str(entry.display_name) + "\t" + str(entry.score)


			out += "\t" + str(entry.times_saved - entry.wave)
			out += "\t" + str(entry.time / 60)
			DisplayServer.clipboard_set(out)
		else:
			Audio.sound("gui_slider")
			var out = "\"" + str(entry.entity_id) + "\", # " + str(entry.display_name)
			DisplayServer.clipboard_set(out)

func label(t, mono: = true) -> Label:
	var l = Label.new()
	l.text = str(t)
	l.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	if mono:
		l.label_settings = preload("res://gui/fontsettings/NumbersMonospaceFontSettings.tres")

	if isKnownCheater:
		l.add_theme_color_override("font_color", Color.FIREBRICK)
	elif isTrustedPlayer:
		l.add_theme_color_override("font_color", Color.AQUAMARINE)
	return l

func getTextureRectFor(col: int, value: int) -> TextureRect:
	var s = TextureRect.new()
	match col:
		0:
			match value:
				1: s.texture = preload("res://content/gamemode/prestige/leaderboard/dome1.png")
				2: s.texture = preload("res://content/gamemode/prestige/leaderboard/dome2.png")
				3: s.texture = preload("res://content/gamemode/prestige/leaderboard/dome3.png")
				4: s.texture = preload("res://content/gamemode/prestige/leaderboard/dome4.png")
		1:
			match value:
				1: s.texture = preload("res://content/gamemode/prestige/leaderboard/keeper1.png")
				2: s.texture = preload("res://content/gamemode/prestige/leaderboard/keeper2.png")
		2:
			match value:
				1: s.texture = preload("res://content/gamemode/prestige/leaderboard/gadget3.png")
				2: s.texture = preload("res://content/gamemode/prestige/leaderboard/gadget2.png")
				3: s.texture = preload("res://content/gamemode/prestige/leaderboard/gadget1.png")
				4: s.texture = preload("res://content/gamemode/prestige/leaderboard/gadget4.png")
	if s.texture:
		s.custom_minimum_size = s.texture.get_size() * 2
	s.expand = true
	s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return s

func _on_ButtonUpdate_pressed():
	if currentLeaderboardId.begins_with("domekeeper_prestige_cheats"):
		currentLeaderboardId = "domekeeper_prestige_cheats"
	else:
		match season:
			1:
				currentLeaderboardId = "domekeeper_prestige_weekly" + leaderboardSuffix
			2, 3, 4, 5, 6, 7:
				currentLeaderboardId = "domekeeper_prestige_season" + str(season) + leaderboardSuffix
			_:
				currentLeaderboardId = "domekeeper_prestige_season" + leaderboardSuffix

	var c = find_child("GlobalLeaderboardContainer")
	for e in c.get_children():
		e.queue_free()
	if season <= 7 and Platform.hasLegacyLeaderboards():
		if handles.has(currentLeaderboardId):
			Platform.downloadLegacyLeaderboardEntries(100 * (page - 1) + 1, 100 * page, 0, handles[currentLeaderboardId])
		else:
			findLeaderboard(currentLeaderboardId)
	elif season >= 8:
		if twoPlayer:
			currentLeaderboardId += "_twoplayer"
		if friendly:
			currentLeaderboardId += "_friendly"

		PlayFabServices.get_leaderboard(currentLeaderboardId, 100 * (page - 1) + 1, 100, -1 if currentLeaderboardId.begins_with("domekeeper_prestige_cheats") else season)
	find_child("LabelPage").text = "Page " + str(page)



func _on_ButtonPrestige_pressed():
	leaderboardSuffix = ""
	_on_ButtonUpdate_pressed()

func _on_ButtonPrestige2_pressed():
	leaderboardSuffix = "_cobalt"
	_on_ButtonUpdate_pressed()

func _on_ButtonPrestige3_pressed():
	leaderboardSuffix = "_countdown"
	_on_ButtonUpdate_pressed()

func _on_ButtonPrestige4_pressed():
	leaderboardSuffix = "_miner"
	_on_ButtonUpdate_pressed()

func _on_button_prestige_6_pressed() -> void :
	leaderboardSuffix = "_provocation"
	_on_ButtonUpdate_pressed()

func _on_ButtonPrestige5_pressed():
	currentLeaderboardId = "domekeeper_prestige_cheats"
	_on_ButtonUpdate_pressed()

func _on_ButtonBack_pressed():
	page = max(1, page - 1)
	_on_ButtonUpdate_pressed()

func _on_ButtonForward_pressed():
	page = page + 1
	_on_ButtonUpdate_pressed()

func _on_ButtonSeason1_pressed():
	season = 1
	_on_ButtonUpdate_pressed()

func _on_ButtonSeason2_pressed():
	season = 2
	_on_ButtonUpdate_pressed()

func _on_ButtonSeason3_pressed():
	season = 3
	_on_ButtonUpdate_pressed()

func _on_ButtonSeason4_pressed():
	season = 4
	_on_ButtonUpdate_pressed()

func _on_ButtonSeason5_pressed():
	season = 5
	_on_ButtonUpdate_pressed()

func _on_button_season_6_pressed() -> void :
	season = 6
	_on_ButtonUpdate_pressed()

func _on_button_season_7_pressed() -> void :
	season = 7
	_on_ButtonUpdate_pressed()

func _on_button_season_8_pressed() -> void :
	season = 8
	_on_ButtonUpdate_pressed()

func _on_ButtonBack10_pressed():
	page = max(1, page - 5)
	_on_ButtonUpdate_pressed()

func _on_ButtonForward10_pressed():
	page = page + 5
	_on_ButtonUpdate_pressed()

func _on_button_single_pressed() -> void :
	twoPlayer = false
	_on_ButtonUpdate_pressed()

func _on_button_multi_pressed() -> void :
	twoPlayer = true
	_on_ButtonUpdate_pressed()

func _on_button_global_pressed() -> void :
	friendly = false
	_on_ButtonUpdate_pressed()

func _on_button_friendly_pressed() -> void :
	friendly = true
	_on_ButtonUpdate_pressed()
