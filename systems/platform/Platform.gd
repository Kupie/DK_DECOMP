extends Node

signal lobby_found(lobby: Dictionary)
signal lobby_search_complete
signal lobby_search_error
signal platform_lobby_created(peer)
signal platform_lobby_joined(peer)
signal crossplay_lobby_created
signal crossplay_lobby_joined(connection_string: String)
signal join_lobby_failed(error_message: String)

var facade: PlatformFacade = null

var time_waiting_playfab_login: float
var duration_between_playfab_login: = 15

func init(useSteamInEditor: bool):
	facade = create_facade(useSteamInEditor)
	var s: GDScript = facade.get_script()
	facade.name = s.resource_path.get_file() if s else "PlatformFacade"
	add_child(facade)
	Logger.info("Initializing Platform: %s" % [facade.name])
	facade.init()
	if GameWorld.is_allowOnlineMultiplayer():
		login_to_playfab()

	PlayFabServices.login_failed.connect(_login_failed)

func create_facade(useSteamInEditor) -> PlatformFacade:

	if useSteamInEditor and OS.has_feature("editor") and Engine.has_singleton("Steam"):
		return PlatformFacadeSteam.new()

	if OS.has_feature("steam") and Engine.has_singleton("Steam"):
		return PlatformFacadeSteam.new()


	return PlatformFacadeDummy.new()

func _process(delta: float) -> void :
	if GameWorld.is_allowOnlineMultiplayer() and Platform.is_network_available() and not PlayFabServices.is_initialized() and not PlayFabServices.is_initializing():
		time_waiting_playfab_login += delta
		if time_waiting_playfab_login > duration_between_playfab_login:
			time_waiting_playfab_login = 0
			login_to_playfab()

func _login_failed(message: String):
	print("Loggin failed: ", message)
	time_waiting_playfab_login = 0



func get_username() -> String:
	return facade.get_username()

func get_user_id() -> String:
	return facade.get_user_id()

func get_username_per_device_id(device_id: int) -> String:
	var godot_device_id = 0 if device_id <= 0 else (device_id - 1)
	return facade.get_username_per_device_id(godot_device_id)

func get_user_id_per_device_id(device_id: int) -> String:
	var godot_device_id = 0 if device_id <= 0 else (device_id - 1)
	return facade.get_user_id_per_device_id(godot_device_id)


func get_platform_id() -> String:
	return facade.get_platform_id()

func show_player_profile_card(user_id):
	facade.show_player_profile_card(user_id)

func check_online_privilege(cb: Callable):
	facade.check_online_privilege(cb)

func check_crossplay_privilege(cb: Callable):
	facade.check_crossplay_privilege(cb)

func show_invite_ui():
	facade.show_invite_ui()

func is_owned() -> bool:
	return facade.is_owned()

func is_online() -> bool:
	return facade.is_online()

func runningOnHandheldDevice() -> bool:
	return facade and facade.runningOnHandheldDevice()

func openWebPage(path):
	facade.openWebPage(path)

func connectToOverlayToggled(c: Callable):
	facade.connectToOverlayToggled(c)


func purchased_pioneer_pack() -> bool:
	return facade.purchased_pioneer_pack()

func purchased_assessor_booster() -> bool:
	return facade.purchased_assessor_booster()

func purchased_keeper_dlc() -> bool:
	return facade.purchased_keeper_dlc()

func open_keeper_dlc_in_store() -> void :
	return facade.open_keeper_dlc_in_store()


func hasLegacyLeaderboards() -> bool:
	return facade.hasLegacyLeaderboards()

func connectToLegacyLeaderboardCallbacks(find_result: Callable, scores_downloaded: Callable, scores_uploaded: Callable):
	facade.connectToLegacyLeaderboardCallbacks(find_result, scores_downloaded, scores_uploaded)

func findLegacyLeaderboard(leaderboard_name: String):
	facade.findLegacyLeaderboard(leaderboard_name)

func getFriendPersonaName(id: int) -> String:
	return facade.getFriendPersonaName(id)

func setLegacyLeaderboardDetailsMax(amount: int):
	facade.setLegacyLeaderboardDetailsMax(amount)

func downloadLegacyLeaderboardEntries(start: int, end: int, type: int = 0, this_leaderboard: int = 0):
	facade.downloadLegacyLeaderboardEntries(start, end, type, this_leaderboard)


func resetAllStatsAndAchievements():
	return facade.resetAllStatsAndAchievements()




func getAchievement(achievement_name: String) -> Dictionary:
	return facade.getAchievement(achievement_name)

func unlockAchievement(achievement_name: String) -> bool:
	return facade.unlockAchievement(achievement_name)

func storeStats() -> bool:
	return facade.storeStats()

func setStat(stat_name: String, value: int) -> bool:
	return facade.setStat(stat_name, value)

func getStat(stat_name: String) -> int:
	return facade.getStat(stat_name)

func requestUserStats():
	facade.requestUserStats()

func get_package_version():
	return facade.get_package_version()


func login_to_playfab() -> void :
	facade.login_to_playfab()

func get_playfab_lobby_access_policy() -> PlayFabServices.AccessPolicy:
	return facade.get_playfab_lobby_access_policy()

func can_create_platform_lobby() -> bool:
	return facade.can_create_platform_lobby()

func create_platform_lobby() -> void :
	facade.create_platform_lobby()

func create_crossplay_lobby(connection_string: String) -> void :
	facade.create_crossplay_lobby(connection_string)

func join_lobby(lobby_id: Variant) -> void :
	facade.join_lobby(lobby_id)

func find_lobbies() -> void :
	facade.find_lobbies()

func leave_lobby() -> void :
	facade.leave_lobby()

func get_current_lobby_players_profile() -> Array:
	return facade.get_current_lobby_players_profile()

func is_crossplay_enabled() -> bool:
	return facade.is_crossplay_enabled()


func is_network_initialized() -> bool:
	return facade.is_network_initialized()


func is_network_available() -> bool:
	return facade.is_network_available()

func get_block_list_per_device_id(device_id: int) -> Array:
	var godot_device_id = 0 if device_id <= 0 else (device_id - 1)
	return facade.get_block_list_per_device_id(godot_device_id)
