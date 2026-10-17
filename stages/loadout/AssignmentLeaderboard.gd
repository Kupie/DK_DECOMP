extends VBoxContainer

var done: = false
var pendingSubmission: = false
var friendLeaderboard: GetPlayFabFriendLeaderboard

func _ready():
	friendLeaderboard = GetPlayFabFriendLeaderboard.new()
	friendLeaderboard.leaderboard_loaded.connect(on_leaderboard_loaded)
	friendLeaderboard.load_leaderboard_failed.connect(on_load_leaderboard_failed)
	add_child(friendLeaderboard)

	PlayFabServices.score_submitted.connect(on_score_submitted)
	PlayFabServices.score_submission_failed.connect(on_score_submission_failed)

	var badgeCount = GameWorld.getAssignmentProgress()
	if GameWorld.lastUploadedAssignmentScore != badgeCount:
		pendingSubmission = true
		PlayFabServices.submit_score("assignment_badges", PackedStringArray([badgeCount]), "")

func start():
	if done:
		return

	done = true

	$GridContainer.visible = false
	$ErrorLabel.visible = true
	$ErrorLabel.text = tr("leaderboard.loading")

	if not pendingSubmission:
		friendLeaderboard.get_leaderboard("assignment_badges")


func on_leaderboard_loaded(result: Dictionary) -> void :
	if result["name"] != "assignment_badges":
		return

	$GridContainer.visible = true
	$ErrorLabel.visible = false

	for entry in result["entries"]:
		var platform_id = Platform.get_platform_id()
		addRow(int(entry["Badges"]), entry["display_name"], platform_id, entry["entity_id"], entry["entity_id"] == PlayFabServices.get_entity_id())

func on_load_leaderboard_failed(in_error: String) -> void :
	push_warning(in_error)
	$ErrorLabel.text = tr("leaderboard.failed")

func on_score_submitted(result: Dictionary) -> void :
	if result["name"] != "assignment_badges":
		return

	GameWorld.lastUploadedAssignmentScore = GameWorld.getAssignmentProgress()
	pendingSubmission = false
	if done:
		friendLeaderboard.get_leaderboard("assignment_badges")

func on_score_submission_failed() -> void :
	if not pendingSubmission:
		return

	pendingSubmission = false
	if done:
		friendLeaderboard.get_leaderboard("assignment_badges")

func addRow(score: int, playerName: String, playerPlatformId: String, entity_id: String, highlight: = false):
	if playerName.length() > 24:
		playerName = playerName.substr(0, 24)

	var l = preload("res://gui/platform/gamertag/GamerTagLabel.tscn").instantiate()
	l.size_flags_horizontal = Control.SIZE_EXPAND
	var gamertag_label = l.find_child("NameLabel")
	gamertag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gamertag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if highlight:
		gamertag_label.label_settings = preload("res://gui/fontsettings/NormalFontSettingsHighlighted.tres")
	else:
		gamertag_label.label_settings = preload("res://gui/fontsettings/NormalFontSettings.tres")
	l.set_gamer_tag_for_loadout(playerName, playerPlatformId, show_player_profile.bind(entity_id))
	$GridContainer.add_child(l)

	l = Label.new()
	l.text = "%d" % score
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if highlight:
		l.label_settings = preload("res://gui/fontsettings/NumbersFontSettingsHighlighted.tres")
	else:
		l.label_settings = preload("res://gui/fontsettings/NumbersFontSettings.tres")
	$GridContainer.add_child(l)

func show_player_profile(entity_id) -> void :
	Network.get_xuid_from_entity_id(entity_id, Platform.show_player_profile_card)
