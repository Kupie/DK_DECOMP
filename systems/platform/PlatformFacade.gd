extends Node
class_name PlatformFacade

func init():
	assert (false, "Pure Virtual")

func get_username() -> String:
	assert (false, "Pure Virtual")
	return ""

func get_user_id() -> String:
	assert (false, "Pure Virtual")
	return ""

func get_username_per_device_id(device_id: int) -> String:
	assert (false, "Pure Virtual")
	return ""

func get_user_id_per_device_id(device_id: int) -> String:
	assert (false, "Pure Virtual")
	return ""

func get_platform_id() -> String:
	return ""

func show_player_profile_card(user_id):
	pass

func check_online_privilege(cb: Callable):
	cb.call(true)

func check_crossplay_privilege(cb: Callable):
	cb.call(false)

func show_invite_ui():
	pass

func is_owned() -> bool:
	assert (false, "Pure Virtual")
	return false

func is_online() -> bool:
	assert (false, "Pure Virtual")
	return false

func runningOnHandheldDevice() -> bool:
	assert (false, "Pure Virtual")
	return false

func openWebPage(path):
	assert (false, "Pure Virtual")

func connectToOverlayToggled(c: Callable):
	assert (false, "Pure Virtual")


func purchased_pioneer_pack() -> bool:
	assert (false, "Pure Virtual")
	return false

func purchased_assessor_booster() -> bool:
	assert (false, "Pure Virtual")
	return false

func purchased_keeper_dlc() -> bool:
	assert (false, "Pure Virtual")
	return true

func open_keeper_dlc_in_store() -> void :
	assert (false, "Pure Virtual")
	pass


func hasLegacyLeaderboards() -> bool:
	assert (false, "Pure Virtual")
	return false

func connectToLegacyLeaderboardCallbacks(find_result: Callable, scores_downloaded: Callable, scores_uploaded: Callable):
	assert (false, "Pure Virtual")

func findLegacyLeaderboard(leaderboard_name: String):
	assert (false, "Pure Virtual")

func getFriendPersonaName(id: int) -> String:
	assert (false, "Pure Virtual")
	return ""

func setLegacyLeaderboardDetailsMax(amount: int):
	assert (false, "Pure Virtual")

func downloadLegacyLeaderboardEntries(start: int, end: int, type: int = 0, this_leaderboard: int = 0):
	assert (false, "Pure Virtual")


func resetAllStatsAndAchievements():
	assert (false, "Pure Virtual")




func getAchievement(achievement_name: String) -> Dictionary:
	assert (false, "Pure Virtual")
	return {}

func unlockAchievement(stat_name: String) -> bool:
	assert (false, "Pure Virtual")
	return false

func storeStats() -> bool:
	assert (false, "Pure Virtual")
	return false

func setStat(stat_name: String, value: int) -> bool:
	assert (false, "Pure Virtual")
	return false

func getStat(stat_name: String) -> int:
	assert (false, "Pure Virtual")
	return 0

func requestUserStats():
	assert (false, "Pure Virtual")

func get_package_version():
	return ""


func login_to_playfab() -> void :
	assert (false, "Pure Virtual")
	pass

func get_playfab_lobby_access_policy() -> PlayFabServices.AccessPolicy:
	return PlayFabServices.AccessPolicy.LOBBY_PRIVATE

func can_create_platform_lobby() -> bool:

	return false

func create_platform_lobby() -> void :
	assert (false, "Pure Virtual")
	pass

func create_crossplay_lobby(connection_string: String) -> void :
	assert (false, "Pure Virtual")
	pass

func join_lobby(lobby_id: Variant) -> void :
	assert (false, "Pure Virtual")
	pass

func find_lobbies() -> void :
	assert (false, "Pure Virtual")
	pass

func leave_lobby() -> void :
	assert (false, "Pure Virtual")
	pass

func get_current_lobby_players_profile() -> Array:
	assert (false, "Pure Virtual")
	return []

func is_crossplay_enabled() -> bool:
	assert (false, "Pure Virtual")
	return false

func is_network_initialized() -> bool:
	return true

func is_network_available() -> bool:
	return true

func get_block_list_per_device_id(device_id: int) -> Array:
	return []
