extends PlatformFacade
class_name PlatformFacadeDummy

var test_user_id: int = -1
var platform_user_id: = ""

func init():
	PlayFabServices.lobbies_found.connect(_on_lobbies_found)
	PlayFabServices.find_lobbies_failed.connect(_on_lobbies_failed)

	var filename: = "platform-id-0"
	if UtilsOS.has_startup_argument("--client"):
		filename = "platform-id-1"

	var save: = FileAccess.open("user://%s.txt" % filename, FileAccess.ModeFlags.READ)
	if save != null:
		var i = save.get_as_text()

		var result = JSON.parse_string(i)
		if result:
			platform_user_id = result.get("platform-id", "")
		save.close()

	if platform_user_id == "":
		save = FileAccess.open("user://%s.txt" % filename, FileAccess.ModeFlags.WRITE)
		if save != null:
			platform_user_id = str(randi())
			save.store_string(JSON.stringify({"platform-id": platform_user_id}))
		save.close()

func get_username() -> String:
	return "User(Dummy)-%s" % get_user_id()

func get_user_id() -> String:
	return platform_user_id if platform_user_id != "" else "3141596"

func get_platform_id() -> String:
	return CONST.PLATFORM_ID_DUMMY

func is_owned() -> bool:
	return true

func is_online() -> bool:
	return true

func runningOnHandheldDevice() -> bool:
	return false

func openWebPage(path):
	OS.shell_open(path)

func connectToOverlayToggled(c: Callable):
	pass


func purchased_pioneer_pack() -> bool:
	return true

func purchased_assessor_booster() -> bool:
	return true

func purchased_keeper_dlc() -> bool:
	return true

func open_keeper_dlc_in_store() -> void :
	pass


func hasLegacyLeaderboards() -> bool:
	return false

func connectToLegacyLeaderboardCallbacks(find_result: Callable, scores_downloaded: Callable, scores_uploaded: Callable):
	pass

func findLegacyLeaderboard(leaderboard_name: String):
	pass

func getFriendPersonaName(id: int) -> String:
	return "Other User(Dummy)"

func setLegacyLeaderboardDetailsMax(amount: int):
	pass

func downloadLegacyLeaderboardEntries(start: int, end: int, type: int = 0, this_leaderboard: int = 0):
	pass


func resetAllStatsAndAchievements():
	pass




func getAchievement(achievement_name: String) -> Dictionary:
	return {"ret": true, "achieved": false}

func unlockAchievement(achievement_name: String) -> bool:
	return true

func storeStats() -> bool:
	return true

func setStat(stat_name: String, value: int) -> bool:
	return true

func getStat(stat_name: String) -> int:
	return 0

func requestUserStats():
	return


func login_to_playfab() -> void :
	var playerId: String
	if GameWorld.devMode:

		playerId = Platform.get_user_id()
	else:
		playerId = Backend.playerId

	PlayFabServices.login_with_custom_id(playerId, Backend.titleId, get_username())

func get_playfab_lobby_access_policy() -> PlayFabServices.AccessPolicy:
	return PlayFabServices.AccessPolicy.LOBBY_PUBLIC

func create_crossplay_lobby(connection_string: String) -> void :

	Platform.crossplay_lobby_created.emit()

func join_lobby(lobby_id: Variant) -> void :

	Platform.crossplay_lobby_joined.emit(lobby_id)

func find_lobbies() -> void :
	if not Network.playfab_initialized:
		return
	PlayFabServices.find_lobbies()

func leave_lobby() -> void :
	pass

func _on_lobbies_found(lobby_count: int) -> void :
	Platform.lobby_search_complete.emit()
	for i: int in range(lobby_count):
		var playfab_lobby_data: = PlayFabServices.get_lobby_search_results(i)
		var lobby_data: = {}
		lobby_data["id"] = playfab_lobby_data["connection_string"]
		lobby_data["name"] = playfab_lobby_data["string_key1"]
		if playfab_lobby_data.has("string_key2"):
			lobby_data["version"] = playfab_lobby_data["string_key2"]
		Platform.lobby_found.emit(lobby_data)

func _on_lobbies_failed(error: String) -> void :
	Platform.lobby_search_error.emit()
