extends VBoxContainer

signal playSound(soundName: String)

@export var teamId: String

func _ready():
	var teamNumber: = teamId.lstrip("team")
	%TeamSelectionHeadline.text = tr("loadout.team.selection") % (tr("loadout.team") % teamNumber)
	%LoadoutChoiceJoin.connect("select", StageManager.currentStage._on_loadout_choice_keeper_join_team.bind(teamId))
	%LoadoutChoiceOpen.selected = true

	%LoadoutChoiceOpen.team_exclusive = teamId
	%LoadoutChoiceClosed.team_exclusive = teamId

	for c in $ColorPicker.get_children():
		c.connect("on_selected", networkSetColor)
		c.playSound.connect( func(soundName: String): playSound.emit(soundName))
		c.team_exclusive = teamId

func networkSetColor(colorId: String, keeper: Keeper):
	Network.rpc_server(setColor.bind(colorId))

@rpc("reliable", "any_peer")
func setColor(colorId: String) -> void :
	for i in 4:
		var cc = find_child("ColorChoice" + str(i + 1))
		cc.selected = cc.color == colorId
		for k: LoadoutKeeper in Level.loadout.keepers:
			if k.teamId == teamId:
				k.colorId = colorId
				k.keeper.setSkin(k.skinId, k.colorId)
				if multiplayer.is_server():
					Lobby.update_color.rpc(int(k.playerId.lstrip("player")), int(colorId.lstrip("color"))
	)

	if multiplayer.is_server():
		Network.rpc_if_state(updateColorSelection.bind(colorId), Network.ConnectionState.LOADOUT_STAGE_SYNC)

@rpc("reliable")
func updateColorSelection(colorId: String) -> void :
	for i in 4:
		var cc = find_child("ColorChoice" + str(i + 1))
		cc.selected = cc.color == colorId

func getColor() -> String:
	for i in 4:
		var cc = find_child("ColorChoice" + str(i + 1))
		if cc.selected:
			return cc.color
	return "color0"

func _on_loadout_choice_open_team_select(open: bool) -> void :
	Network.rpc_server(setOpenClosedToggle.bind(open))

@rpc("reliable", "any_peer")
func setOpenClosedToggle(open: bool) -> void :
	%LoadoutChoiceJoin.set_enabled(open)
	%LoadoutChoiceOpen.selected = open
	%LoadoutChoiceClosed.selected = not open

	if multiplayer.is_server():
		Network.rpc_if_state(setOpenClosedToggle.bind(open), Network.ConnectionState.LOADOUT_STAGE_SYNC)

func updateTeamPlayerNameList():
	for c in %TeamMemberList.get_children():
		c.queue_free()
	for k: LoadoutKeeper in Level.loadout.keepers:
		if k.teamId != teamId:
			continue
		var label = preload("res://gui/platform/gamertag/GamerTagLabel.tscn").instantiate()
		label.icon_size = 50
		label.set_gamer_tag(k.playerName, Lobby.get_member_by_player_id(k.playerId).platform_id)
		label.find_child("NameLabel").label_settings = preload("res://gui/fontsettings/NormalFontSettings.tres")
		label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		%TeamMemberList.add_child(label)

func open_sound() -> void :
	playSound.emit("loadout_team_open")

func close_sound() -> void :
	playSound.emit("loadout_team_close")
