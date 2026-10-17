extends PlatformFacade
class_name PlatformFacadeSteam

const STEAM_APP_ID: = 1637320


var IS_OWNED: bool = false
var IS_ONLINE: bool = false
var STEAM_ID: int = 0
var STEAM_USERNAME: String
var statsReceived: = false
var API = null

var active_lobby_id: = -1
var lobbies_to_confirm: = {}


enum LobbyType
{
	LOBBY_TYPE_PRIVATE, 
	LOBBY_TYPE_FRIENDS_ONLY, 
	LOBBY_TYPE_PUBLIC, 
	LOBBY_TYPE_INVISIBLE, 
	LOBBY_TYPE_PRIVATE_UNIQUE
}


func init():

	API = Engine.get_singleton("Steam")
	API.current_stats_received.connect(_steam_Stats_Ready, CONNECT_ONE_SHOT)

	var INIT: Dictionary = API.steamInitEx(STEAM_APP_ID, false)
	if INIT["status"] != 0:

		Logger.error("Steam failed to initialize: " + str(INIT["verbal"]), "PlatformFacadeSteam.init")
		if not GameWorld.devMode:
			open_issue_stage(str(INIT["verbal"]))
		return

	Logger.info("Steam Initialized Correctly")
	IS_ONLINE = API.loggedOn()
	STEAM_ID = API.getSteamID()
	IS_OWNED = API.isSubscribed()
	STEAM_USERNAME = API.getPersonaName()
	API.initRelayNetworkAccess()


	if not IS_OWNED:
		Logger.error("[STEAM] User does not own this game")
		StageManager.clearQueuedStage()
		open_issue_stage()
		return

	API.join_requested.connect(on_join_requested)
	API.lobby_data_update.connect(on_lobby_data_update)

	var branch_name = API.getCurrentBetaName()
	match branch_name:
		"console-reference", "console-reference-2":
			print("Changing title id to dev")
			Backend.titleId = "189F08"
		"console-reference-cert":
			print("Changing title id to cert")
			Backend.titleId = "14BCCE"

func _exit_tree() -> void :
	API.steamShutdown()
	API = null

func open_issue_stage(errorMessage: = ""):
	create_tween().tween_callback(StageManager.startStage.bind("stages/steamissue/steamissue2", [errorMessage])).set_delay(1.0)


func _process(_delta: float) -> void :
	API.run_callbacks()

func _steam_Stats_Ready(game: int, result: int, user: int) -> void :
	statsReceived = true

func get_username() -> String:
	return STEAM_USERNAME

func get_user_id() -> String:
	return str(STEAM_ID)

func get_platform_id() -> String:
	return CONST.PLATFORM_ID_STEAM

func is_owned() -> bool:
	return IS_OWNED

func is_online() -> bool:
	return IS_ONLINE

func runningOnHandheldDevice() -> bool:
	return API.isSteamRunningOnSteamDeck()

func openWebPage(url):
	API.activateGameOverlayToWebPage(url)

func connectToOverlayToggled(c: Callable):
	API.overlay_toggled.connect(c)


func purchased_pioneer_pack() -> bool:
	return API.isSubscribedApp(2152440)

func purchased_assessor_booster() -> bool:
	return API.isSubscribedApp(2380060)

func purchased_keeper_dlc() -> bool:
	return API.isSubscribedApp(4331610)

func open_keeper_dlc_in_store():
	return API.activateGameOverlayToStore(4331610, Steam.OVERLAY_TO_STORE_FLAG_NONE)


func hasLegacyLeaderboards() -> bool:
	return true

func connectToLegacyLeaderboardCallbacks(find_result: Callable, scores_downloaded: Callable, scores_uploaded: Callable):
	API.leaderboard_find_result.connect(find_result)
	API.leaderboard_scores_downloaded.connect(scores_downloaded)
	API.leaderboard_score_uploaded.connect(scores_uploaded)

func findLegacyLeaderboard(leaderboard_name: String):
	API.findLeaderboard(leaderboard_name)

func getFriendPersonaName(id: int) -> String:
	return API.getFriendPersonaName(id)

func setLegacyLeaderboardDetailsMax(amount: int):
	if API.has_method("setLegacyLeaderboardDetailsMax"):
		API.setLeaderboardDetailsMax(amount)

func downloadLegacyLeaderboardEntries(start: int, end: int, type: int = 0, this_leaderboard: int = 0):
	API.downloadLeaderboardEntries(start, end, type, this_leaderboard)


func resetAllStatsAndAchievements():
	API.resetAllStats(true)




func getAchievement(achievement_name: String) -> Dictionary:
	return API.getAchievement(achievement_name)

func unlockAchievement(achievement_name: String) -> bool:
	return API.setAchievement(achievement_name)

func storeStats() -> bool:
	return API.storeStats()

func setStat(stat_name: String, value: int) -> bool:
	return API.setStatInt(stat_name, value)

func getStat(stat_name: String) -> int:
	return API.getStatInt(stat_name)

func requestUserStats():
	API.requestUserStats(STEAM_ID)


func login_to_playfab() -> void :
	var auth_ticket: Dictionary = API.getAuthSessionTicket()
	if auth_ticket.has("buffer"):
		PlayFabServices.login_with_steam(auth_ticket["buffer"], Backend.titleId, get_username())

func get_playfab_lobby_access_policy() -> PlayFabServices.AccessPolicy:
	return PlayFabServices.AccessPolicy.LOBBY_PRIVATE

func can_create_platform_lobby() -> bool:
	return ClassDB.can_instantiate("SteamMultiplayerPeer")

func create_platform_lobby() -> void :
	API.lobby_created.connect(on_steam_lobby_created, CONNECT_ONE_SHOT)
	API.createLobby(LobbyType.LOBBY_TYPE_FRIENDS_ONLY, Options.maximumPlayerCount)

func create_crossplay_lobby(connection_string: String) -> void :
	API.lobby_created.connect(on_crossplay_lobby_created.bind(connection_string), CONNECT_ONE_SHOT)
	API.createLobby(LobbyType.LOBBY_TYPE_FRIENDS_ONLY, Options.maximumPlayerCount)

func join_lobby(lobby_id: Variant) -> void :
	Engine.get_singleton("Steam").lobby_joined.connect(on_steam_lobby_joined, CONNECT_ONE_SHOT)
	API.joinLobby(int(lobby_id))

func find_lobbies() -> void :
	lobbies_to_confirm.clear()
	for friend in API.getUserSteamFriends():
		if friend["status"] == API.PERSONA_STATE_ONLINE:
			var playing: Dictionary = API.getFriendGamePlayed(friend["id"])
			if playing:
				if playing["id"] == API.getAppID():
					var lobbyString: = str(playing["lobby"])
					if lobbyString.is_valid_int() and lobbyString != "0":
						var lobby_id: int = playing["lobby"]
						var lobby_data: = {}
						lobby_data["id"] = lobby_id
						lobbies_to_confirm[lobby_id] = lobby_data
						API.requestLobbyData(lobby_id)

	Platform.lobby_search_complete.emit()

func leave_lobby() -> void :
	if is_instance_valid(API) and active_lobby_id != -1:
		API.leaveLobby(active_lobby_id)

func on_steam_lobby_created(_connect: int, lobby_id: int):
	active_lobby_id = lobby_id
	API.setLobbyData(lobby_id, "name", Platform.get_username())
	API.setLobbyData(lobby_id, "version", Version.VERSION)
	Platform.platform_lobby_created.emit(ClassDB.instantiate("SteamMultiplayerPeer"), lobby_id)

func on_crossplay_lobby_created(_connect: int, lobby_id: int, connection_string: String):
	active_lobby_id = lobby_id
	API.setLobbyData(lobby_id, "name", Platform.get_username())
	API.setLobbyData(lobby_id, "connection_string", connection_string)
	API.setLobbyData(lobby_id, "version", Version.VERSION)
	Platform.crossplay_lobby_created.emit()

func on_join_requested(lobby_id: int, _steam_id: int):
	Network.close_session()
	join_lobby(str(lobby_id))

func on_steam_lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int):
	if response != 1:
		Platform.join_lobby_failed.emit(get_lobby_join_response_message(response))
		return

	if API.getLobbyOwner(lobby_id) == API.getSteamID():
		return
	active_lobby_id = lobby_id
	var connection_string = API.getLobbyData(lobby_id, "connection_string")
	if connection_string == "":
		if ClassDB.can_instantiate("SteamMultiplayerPeer"):
			Platform.platform_lobby_joined.emit(ClassDB.instantiate("SteamMultiplayerPeer"), lobby_id)
		else:
			Platform.join_lobby_failed.emit("Steam only game but the multiplayer peer is not present.")
	else:
		Platform.crossplay_lobby_joined.emit(connection_string)

func on_lobby_data_update(success: int, lobby_id: int, member_id: int):
	if lobby_id != member_id:
		return

	if lobbies_to_confirm.has(lobby_id):
		lobbies_to_confirm[lobby_id]["name"] = API.getLobbyData(lobby_id, "name")
		lobbies_to_confirm[lobby_id]["version"] = API.getLobbyData(lobby_id, "version")
		Platform.lobby_found.emit(lobbies_to_confirm[lobby_id])

func get_lobby_join_response_message(response: int) -> String:
	match response:
		1: return "Success."
		2: return "Chat doesn't exist (probably closed)."
		3: return "General Denied - You don't have the permissions needed to join the chat."
		4: return "Chat room has reached its maximum size."
		5: return "Unexpected Error."
		6: return "You are banned from this chat room and may not join."
		7: return "Joining this chat is not allowed because you are a limited user (no value on account)."
		8: return "Attempt to join a clan chat when the clan is locked or disabled."
		9: return "Attempt to join a chat when the user has a community lock on their account."
		10: return "Join failed - a user that is in the chat has blocked you from joining."
		11: return "Join failed - you have blocked a user that is already in the chat."
		15: return "Join failed - too many join attempts in a very short period of time."
		_: return "Unknown response code."
