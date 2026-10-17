extends Node

signal loggedIn

const SETTING_PLAYFAB_TITLE_ID = "playfab/title_id"

@export var logEvents: = false
@export var ignoredEvents: = []

var eventCounter: = 1
var enablePlaystreamTelemetry: bool = false
var enableTracking: bool = true
var _loggedIn: = false

var playerId: = ""
var titleId: = ""

func _init():

	if ProjectSettings.has_setting(SETTING_PLAYFAB_TITLE_ID) && ProjectSettings.get_setting(SETTING_PLAYFAB_TITLE_ID) != "":
		titleId = ProjectSettings.get_setting(SETTING_PLAYFAB_TITLE_ID)
	else:
		push_error("Title Id was not set in ProjectSettings: %s" % SETTING_PLAYFAB_TITLE_ID)

func init():


	var save: = FileAccess.open("user://id.txt", FileAccess.ModeFlags.READ)
	if save != null:
		var i = save.get_as_text()

		var result = JSON.parse_string(i)
		if result:
			playerId = result.get("player-id", "")
		save.close()

	if playerId == "":
		save = FileAccess.open("user://id.txt", FileAccess.ModeFlags.WRITE)
		if save != null:
			playerId = UUID.v4()
			Logger.info("generated random player id", "Backend.init", playerId)
			save.store_string(JSON.stringify({"player-id": playerId}))
		save.close()

	if playerId == "qa-debug":
		GameWorld.qaOptions = true

	if BuildCustomization.has_feature("enable_qa_menu"):
		GameWorld.qaOptions = true

	updateEnableTracking()
	PlayFabServices.logged_in.connect(_on_PlayFabClient_logged_in, CONNECT_ONE_SHOT)

func updateEnableTracking():
	enableTracking = not GameWorld.qaOptions and GameWorld.is_allowOnlineMultiplayer() and not BuildCustomization.has_feature("disable_pc_options")
	if GameWorld.is_allowOnlineMultiplayer() and not Network.playfab_initialized:
		if GameWorld.useRandomPort:
			PlayFabServices.set_port(randi_range(50000, 65535))
		Platform.login_to_playfab()

func sendBufferedEvents():
	if enableTracking and _loggedIn and enablePlaystreamTelemetry:


		pass

func event(type, data = {}):
	if not enableTracking or ignoredEvents.has(type) or not enablePlaystreamTelemetry:
		return

	data["sessionId"] = GameWorld.sessionId
	data["version"] = GameWorld.version
	data["timestamp"] = Time.get_ticks_msec()
	if GameWorld.runId != "":
		data["runId"] = GameWorld.runId
		data["runTime"] = GameWorld.runTime
	eventCounter += 1



	if logEvents:
		print(data)

func parseRunsFromSession(session: Array) -> Array:
	var runs: = []
	var meta: = {}
	var currentRun
	var timeOffset: = 0.0
	session.sort_custom(Callable(self, "sortByTime"))
	for d in session:
		var type = d.get("type").to_lower()
		if type == "game_launched":
			meta = d.get("data")
		elif type == "level_launched":
			currentRun = {"cycles": [], "upgrades": [], "gadgets": [], "waves": [], "state": "", "gadgetUses": [], "battleAbility": []}
			currentRun["level"] = d.get("data")
			timeOffset = d.get("time")
		elif currentRun:
			if d.has("time"):
				d["time"] -= timeOffset
				currentRun["duration"] = max(currentRun.get("duration", 0), d["time"])
			match type:
				"cycle_change":
					currentRun["cycles"].append(d)
				"upgrade":
					currentRun["upgrades"].append(d)
				"gadget_unlocked":
					currentRun["gadgets"].append(d)
				"wave_started":
					currentRun["waves"].append(d)
				"wave_finished":
					currentRun["waves"].append(d)
				"gadget_used":
					currentRun["gadgetUses"].append(d)
				"battle_ability_used":
					currentRun["battleAbility"].append(d)
				"game_won":
					currentRun["state"] = "won"
					if currentRun.get("cycles").size() >= 3:
						runs.append(currentRun)
					currentRun = null
				"game_lost":
					currentRun["state"] = "lost"
					if currentRun.get("cycles").size() >= 3:
						runs.append(currentRun)
					currentRun = null

	if currentRun and currentRun.get("cycles").size() >= 3:
		runs.append(currentRun)

	for run in runs:
		run["meta"] = meta

	return runs

func sortByTime(a, b):
	return a["time"] < b["time"]

func _on_PlayFabClient_logged_in():
	Logger.info("successful login", "Backend._on_PlayFabClient_logged_in")
	_loggedIn = true

	var data = {"date": Time.get_datetime_dict_from_system(), 
		"startupTime": Time.get_ticks_msec(), 
		"platform_name": OS.get_name(), 
		"version": GameWorld.version, 
		"buildType": GameWorld.buildType, 
		}

	event("game_launched", data)
