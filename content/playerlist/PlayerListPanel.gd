extends CenterContainer

signal close

var current_players: = []

func _ready() -> void :
	Style.init(self)
	InputSystem.grabFocus(find_child("BackButton"))
	refresh_content()


func _process(delta: float) -> void :
	var request_refresh = false
	var keepers = Keepers.getAll()
	if keepers.size() == current_players.size():
		for keeper in keepers:
			if not current_players.has(keeper.peerId):
				request_refresh = true
				break
	else:
		request_refresh = true

	if request_refresh:
		refresh_content()

func refresh_content():
	print("Refreshing Player List")
	var PlayerList = %PlayerList
	for c in PlayerList.get_children():
		c.queue_free()
	current_players.clear()

	var keepers = Keepers.getAll()
	var local_platform_user_id = Platform.get_user_id()
	for keeper in keepers:
		var keeper_platform_id = Lobby.get_member_by_player_id(keeper.playerId).platform_id
		var keeper_platform_user_id = Lobby.get_member_by_player_id(keeper.playerId).platform_user_id
		current_players.append(keeper.peerId)
		if keeper_platform_user_id == local_platform_user_id:
			continue
		var inst = preload("res://content/playerlist/PlayerListLine.tscn").instantiate()
		PlayerList.add_child(inst)
		inst.set_gamer_tag(keeper.playerName, keeper_platform_id)
		inst.platform_user_id = keeper_platform_user_id

func _on_back_button_pressed() -> void :
	emit_signal("close")
