class_name GetPlayFabFriendLeaderboard
extends HTTPRequest

signal load_leaderboard_failed(error: String)
signal leaderboard_loaded(leaderboard: Dictionary)

func _ready() -> void :
	use_threads = true
	request_completed.connect(on_request_completed)


func get_leaderboard(leaderboard_name: String, version: int = -1) -> void :
	cancel_request()
	if not GameWorld.is_allowOnlineMultiplayer():
		load_leaderboard_failed.emit("Disallowed by permissions.")
		return

	var data_dict: Dictionary = {
	"Entity": {
		"Id": PlayFabServices.get_entity_id(), 
		"Type": PlayFabServices.get_entity_type()
	}, 
	"LeaderboardName": leaderboard_name, 
	"ExternalFriendSources": "all"
	}

	if Platform.get_platform_id() == CONST.PLATFORM_ID_XBOX:
		data_dict["XboxToken"] = PlayFabServices.get_platform_user_token()

	if version != -1:
		data_dict["Version"] = version

	var data: String = JSON.stringify(data_dict)

	var headers: = PackedStringArray()
	headers.append("X-EntityToken: %s" % PlayFabServices.get_entity_token())
	headers.append("Content-Type: application/json")
	headers.append("Accept-Encoding: gzip")
	headers.append("Content-Length: %s" % str(data.length()))

	var error: = request("https://%s.playfabapi.com/Leaderboard/GetFriendLeaderboardForEntity" % Backend.titleId, headers, HTTPClient.METHOD_POST, data)
	if error != OK:
		load_leaderboard_failed.emit("Leaderboard error with code %d" % error)
		return

func on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void :
	if response_code >= 400:
		var error: String = "GetPlayFabFriendLeaderboard request failed with code: %d" % response_code
		load_leaderboard_failed.emit(error)

	var data: = body.get_string_from_utf8()
	var json: = JSON.new()
	var error: = json.parse(data)
	if error != OK:
		load_leaderboard_failed.emit("Leaderboard error with json code %d" % error)
		return

	if not json.data.has("data") or json.data.get("code") != 200:
		load_leaderboard_failed.emit("Unexpected JSON structure.")
		return

	var response_data = json.data["data"]
	var leaderboard_name: String = ""
	var columns: PackedStringArray = []
	for col: Dictionary in response_data["Columns"]:
		if leaderboard_name == "":
			leaderboard_name = col.get("LinkedStatisticColumn", {}).get("LinkedStatisticName", "")
		columns.append(col["Name"])

	var entries: Array[Dictionary] = []
	for row: Dictionary in response_data["Rankings"]:
		var entry: = {
			"rank": row["Rank"], 
			"display_name": row.get("DisplayName", ""), 
			"entity_id": row["Entity"]["Id"], 
			"metadata": row.get("Metadata", ""), 
		}
		var scores: Array = row.get("Scores", [])
		for i in range(scores.size()):
			entry[columns[i]] = scores[i]

		entries.append(entry)

	var leaderboard: Dictionary = {
		"name": leaderboard_name, 
		"version": response_data["Version"], 
		"entries": entries, 
		"count": response_data["EntryCount"]
	}

	leaderboard_loaded.emit(leaderboard)
