@tool
class_name DomeEditorExtension extends EditorPlugin

const EDITOR_SETTING_RESTORE_WINDOWS = "dome_keeper/restore_windows_positions"

var config: DomeEditorConf
var keeper_options: = ["keeper1", "keeper2", "keeper3", "keeper4"]
var mode_icons: = [
	resize_icon(preload("res://content/icons/loadout_relichunt.png"), 32, 32), 
	resize_icon(preload("res://content/icons/loadout_versus.png"), 32, 32)
]

var dome_icons: = [
	resize_icon(preload("res://content/icons/loadout_dome1.png"), 32, 32), 
	resize_icon(preload("res://content/icons/loadout_dome2.png"), 32, 32), 
	resize_icon(preload("res://content/icons/loadout_dome3.png"), 32, 32), 
	resize_icon(preload("res://content/icons/loadout_dome4.png"), 32, 32), 
]
var dome_options: = ["laser", "sword", "artillery", "tesla"]

var keeper_icons: = [
	preload("res://content/icons/loadout_keeper1-skin0.png"), 
	preload("res://content/icons/loadout_keeper2-skin0.png"), 
	preload("res://content/icons/loadout_keeper3-skin0.png"), 
	preload("res://content/icons/loadout_keeper4-skin0.png"), 
]
var primary_gadget_options: = ["shield", "orchard", "repellent", "droneyard"]
var primary_gadget_icons: = [
	preload("res://content/icons/shield.png"), 
	preload("res://content/icons/orchard.png"), 
	preload("res://content/icons/repellent.png"), 
	preload("res://content/icons/droneyard.png"), 
]

var runbar: Node
var parent: Node
var main_panel: Node
var play_mode: OptionButton
var game_mode: OptionButton
var local_players: OptionButton
var p1_keeper_selector: OptionButton
var p2_keeper_selector: OptionButton
var p1_primary_gadget_selector: OptionButton
var p2_primary_gadget_selector: OptionButton
var p1_dome_selector: OptionButton
var p2_dome_selector: OptionButton
var stop_from_menu: Button
var player2_options: Array[Control] = []
var versus_options: Array[Control] = []
var started_pids: = PackedInt32Array()

func resize_icon(t: CompressedTexture2D, w: int, h: int) -> Texture:
	var image = t.get_image()
	image.resize(w, h, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

func _enter_tree():
	var settings = EditorInterface.get_editor_settings()
	if not settings.has_setting(EDITOR_SETTING_RESTORE_WINDOWS):
		settings.set_setting(EDITOR_SETTING_RESTORE_WINDOWS, false)
	settings.set_initial_value(EDITOR_SETTING_RESTORE_WINDOWS, false, false)


	if !ResourceLoader.exists(Const.EDITOR_CONF_PATH):
		config = DomeEditorConf.new()
		ResourceSaver.save(config, Const.EDITOR_CONF_PATH)
	else:
		config = load(Const.EDITOR_CONF_PATH)


	for x in keeper_icons.size():
		keeper_icons[x] = resize_icon(keeper_icons[x], 18, 21)
	for x in primary_gadget_icons.size():
		primary_gadget_icons[x] = resize_icon(primary_gadget_icons[x], 32, 32)

	main_panel = PanelContainer.new();
	var main_hbox = HBoxContainer.new();
	main_panel.add_child(main_hbox);

	add_control_to_container(CONTAINER_TOOLBAR, main_panel)


	parent = main_panel.get_parent()
	runbar = parent.get_child(4)
	runbar.connect("play_pressed", on_play_pressed)


	main_panel.get_parent().move_child(main_panel, 4)


	p1_keeper_selector = OptionButton.new()
	p1_keeper_selector.tooltip_text = "Local player 1 Keeper"
	for keeper in keeper_icons:
		p1_keeper_selector.add_icon_item(keeper, "")
	for i in keeper_options.size():
		p1_keeper_selector.set_item_tooltip(i, keeper_options[i])
	p1_keeper_selector.select(keeper_options.find(config.p1_keeper))
	p1_keeper_selector.connect("item_selected", _on_p1_keeper_selected)
	main_hbox.add_child(p1_keeper_selector)


	p1_dome_selector = OptionButton.new()
	p1_dome_selector.tooltip_text = "Team 1 Dome"
	for gadget in dome_icons:
		p1_dome_selector.add_icon_item(gadget, "")
	for i in dome_options.size():
		p1_dome_selector.set_item_tooltip(i, dome_options[i])
	p1_dome_selector.select(int(config.p1_dome))
	p1_dome_selector.item_selected.connect(_on_p1_dome_selected)
	main_hbox.add_child(p1_dome_selector)


	p1_primary_gadget_selector = OptionButton.new()
	p1_primary_gadget_selector.tooltip_text = "Player 1 primary Gadget Id"
	for gadget in primary_gadget_icons:
		p1_primary_gadget_selector.add_icon_item(gadget, "")
	for i in primary_gadget_options.size():
		p1_primary_gadget_selector.set_item_tooltip(i, primary_gadget_options[i])
	p1_primary_gadget_selector.select(primary_gadget_options.find(config.p1_primaryGadgetid))
	p1_primary_gadget_selector.connect("item_selected", _on_p1_primary_gadget_selected)
	main_hbox.add_child(p1_primary_gadget_selector)


	p2_keeper_selector = OptionButton.new()
	p2_keeper_selector.tooltip_text = "Local player 2 Keeper"
	for keeper in keeper_icons:
		p2_keeper_selector.add_icon_item(keeper, "")
	for i in keeper_options.size():
		p2_keeper_selector.set_item_tooltip(i, keeper_options[i])
	p2_keeper_selector.select(keeper_options.find(config.p2_keeper))
	p2_keeper_selector.connect("item_selected", _on_p2_keeper_selected)
	main_hbox.add_child(p2_keeper_selector)
	player2_options.append(p2_keeper_selector)


	p2_dome_selector = OptionButton.new()
	p2_dome_selector.tooltip_text = "Team 2 Dome"
	for gadget in dome_icons:
		p2_dome_selector.add_icon_item(gadget, "")
	for i in dome_options.size():
		p2_dome_selector.set_item_tooltip(i, dome_options[i])
	p2_dome_selector.select(int(config.p2_dome))
	p2_dome_selector.item_selected.connect(_on_p2_dome_selected)
	main_hbox.add_child(p2_dome_selector)
	player2_options.append(p2_dome_selector)
	versus_options.append(p2_dome_selector)


	p2_primary_gadget_selector = OptionButton.new()
	p2_primary_gadget_selector.tooltip_text = "Player 2 primary Gadget Id"
	for gadget in primary_gadget_icons:
		p2_primary_gadget_selector.add_icon_item(gadget, "")
	for i in primary_gadget_options.size():
		p2_primary_gadget_selector.set_item_tooltip(i, primary_gadget_options[i])
	p2_primary_gadget_selector.select(primary_gadget_options.find(config.p2_primaryGadgetid))
	p2_primary_gadget_selector.connect("item_selected", _on_p2_primary_gadget_selected)
	main_hbox.add_child(p2_primary_gadget_selector)
	player2_options.append(p2_primary_gadget_selector)
	versus_options.append(p2_primary_gadget_selector)


	play_mode = OptionButton.new()
	play_mode.tooltip_text = "Starting Stage"
	for option in Const.ENTER_PLAY_MODE.keys():
		play_mode.add_item(option)
	play_mode.select(int(config.play_mode))
	play_mode.connect("item_selected", on_play_mode_selected)
	main_hbox.add_child(play_mode)


	game_mode = OptionButton.new()
	game_mode.tooltip_text = "Game Mode"
	game_mode.add_icon_item(mode_icons[0], "R")
	game_mode.add_icon_item(mode_icons[1], "VS")
	game_mode.select(int(config.game_mode))
	game_mode.item_selected.connect(_on_game_mode_selected)
	main_hbox.add_child(game_mode)


	local_players = OptionButton.new()
	local_players.tooltip_text = "Number of local players"
	local_players.add_item("1P")
	local_players.add_item("L 2P")
	local_players.add_item("N 2P")
	local_players.set_item_tooltip(0, "Single player")
	local_players.set_item_tooltip(1, "Local two players")
	local_players.set_item_tooltip(2, "Network two players")
	var idx = _get_current_local_players_item_idx_from_config()
	local_players.select(_get_current_local_players_item_idx_from_config())
	local_players.item_selected.connect(_on_local_players_selected)
	main_hbox.add_child(local_players)


	var run_from_menu = Button.new()
	run_from_menu.icon = preload("res://addons/dome_editor_ext/RunFromMenu.svg")
	run_from_menu.tooltip_text = "Run Project with Settings."
	run_from_menu.pressed.connect(on_run_from_menu_pressed)
	main_hbox.add_child(run_from_menu)


	stop_from_menu = Button.new()
	stop_from_menu.icon = preload("res://addons/dome_editor_ext/StopFromMenu.svg")
	stop_from_menu.tooltip_text = "Run Project with Settings."
	stop_from_menu.pressed.connect(_on_stop_from_menu_pressed)
	stop_from_menu.disabled = true
	main_hbox.add_child(stop_from_menu)

	_refresh_player_2_options_visibility()


func _get_current_local_players_item_idx_from_config() -> int:
	if config.nmb_of_players == Const.ENTER_PLAYERS_NMB.ONE_PLAYER:
		return 0
	if config.nmb_of_players == Const.ENTER_PLAYERS_NMB.TWO_PLAYERS:
		if config.multiplayer_mode == Const.DEV_ENTER_MULTIPLAYER_MODE.SPLIT:
			return 1
		if config.multiplayer_mode == Const.DEV_ENTER_MULTIPLAYER_MODE.NETWORK:
			return 2
	return 0

func _exit_tree():
	_kill_all_known_instances()
	runbar.disconnect("play_pressed", on_play_pressed)
	parent.remove_child(main_panel)
	main_panel.queue_free()

func on_play_pressed():
	config.custom_play_pressed = false
	stop_from_menu.disabled = false

func on_run_from_menu_pressed():
	_kill_all_known_instances()
	config.custom_play_pressed = true
	var settings = EditorInterface.get_editor_settings()
	config.restore_windows_upon_startup = settings.get_setting(EDITOR_SETTING_RESTORE_WINDOWS)
	ResourceSaver.save(config, config.resource_path)

	var editor_interface: = get_editor_interface()
	var is_networked: = config.multiplayer_mode == Const.DEV_ENTER_MULTIPLAYER_MODE.NETWORK
	if not is_networked:
		editor_interface.play_main_scene()
		return

	var is_debug_server_available: bool = _is_debug_server_open()
	if not is_debug_server_available:
		_open_debug_server_confirmation()
		return

	var remote_port: String = str(settings.get("network/debug/remote_port")).strip_edges()
	var path: String = "--path " + ProjectSettings.globalize_path("res://")
	var common_args: = PackedStringArray()
	var server_args: = PackedStringArray()
	var client_args: = PackedStringArray()
	common_args.append("--remote-debug")
	common_args.append("tcp://127.0.0.1:" + remote_port)
	server_args.append("--server")
	client_args.append("--client")
	var server_pid: = OS.create_instance(common_args + server_args)
	var client_pid: = OS.create_instance(common_args + client_args)
	started_pids.append(server_pid)
	started_pids.append(client_pid)
	stop_from_menu.disabled = false

func _is_debug_server_open() -> bool:
	var path: = "res://.godot/editor/project_metadata.cfg"
	if not FileAccess.file_exists(path):
		return false
	var file: = FileAccess.open(path, FileAccess.READ)
	if file:
		var content: = file.get_as_text()
		file.close()
		return content.contains("server_keep_open=true")
	return false

func _open_debug_server_confirmation() -> void :
	var editor_interface: = get_editor_interface()
	var confirmartion_popup: = ConfirmationDialog.new()
	confirmartion_popup.title = "Misconfiguration error"
	confirmartion_popup.dialog_text = "Please enable \"Debug -> Keep debug server open\" and restart the editor"
	confirmartion_popup.remove_button(confirmartion_popup.get_cancel_button())
	editor_interface.popup_dialog_centered(confirmartion_popup)

func _process(delta: float) -> void :
	var invalid_pids: PackedInt32Array = PackedInt32Array()
	for pid: int in started_pids:
		var is_pid_invalid: bool = not OS.is_process_running(pid)
		if is_pid_invalid:
			invalid_pids.append(pid)
	for invalid_pid: int in invalid_pids:
		var pid_idx: int = started_pids.find(invalid_pid)
		started_pids.remove_at(pid_idx)

	var editor_interface: EditorInterface = get_editor_interface()
	stop_from_menu.disabled = started_pids.is_empty() and not editor_interface.is_playing_scene()

func _on_stop_from_menu_pressed():
	_kill_all_known_instances()
	config.custom_play_pressed = false
	stop_from_menu.disabled = true

func _kill_all_known_instances() -> void :
	var i = get_editor_interface()
	if i.is_playing_scene():
		i.stop_playing_scene()
	for pid in started_pids:
		OS.kill(pid)
	started_pids.clear()

func on_play_mode_selected(index: int):
	config.play_mode = Const.ENTER_PLAY_MODE.values()[index]

func _on_game_mode_selected(index: int):
	config.game_mode = Const.ENTER_GAME_MODE.values()[index]
	_refresh_player_2_options_visibility()

func _on_p1_primary_gadget_selected(index: int):
	config.p1_primaryGadgetid = primary_gadget_options[index]

func _on_p2_primary_gadget_selected(index: int):
	config.p2_primaryGadgetid = primary_gadget_options[index]

func _on_p1_keeper_selected(index: int):
	config.p1_keeper = keeper_options[index]

func _on_p2_keeper_selected(index: int):
	config.p2_keeper = keeper_options[index]

func _on_local_players_selected(index: int):
	const INDEX_TO_NMB_OF_PLAYERS: = {
		0: Const.ENTER_PLAYERS_NMB.ONE_PLAYER, 
		1: Const.ENTER_PLAYERS_NMB.TWO_PLAYERS, 
		2: Const.ENTER_PLAYERS_NMB.TWO_PLAYERS
	}
	const INDEX_TO_MULTIPLAYER_MODE: = {
		0: Const.DEV_ENTER_MULTIPLAYER_MODE.SINGLE, 
		1: Const.DEV_ENTER_MULTIPLAYER_MODE.SPLIT, 
		2: Const.DEV_ENTER_MULTIPLAYER_MODE.NETWORK
	}

	config.nmb_of_players = INDEX_TO_NMB_OF_PLAYERS[index]
	config.multiplayer_mode = INDEX_TO_MULTIPLAYER_MODE[index]
	_refresh_player_2_options_visibility()

func _refresh_player_2_options_visibility() -> void :
	var is_versus_run: bool = config.game_mode == Const.ENTER_GAME_MODE.VERSUS
	var is_relic_run: bool = config.game_mode == Const.ENTER_GAME_MODE.RELIC
	local_players.set_item_disabled(0, is_versus_run)
	if is_versus_run and config.nmb_of_players == Const.ENTER_PLAYERS_NMB.ONE_PLAYER:
		config.nmb_of_players = Const.ENTER_PLAYERS_NMB.TWO_PLAYERS
		local_players.select(Const.ENTER_PLAYERS_NMB.TWO_PLAYERS)

	var is_one_player: bool = config.nmb_of_players == Const.ENTER_PLAYERS_NMB.ONE_PLAYER
	if is_one_player and not is_versus_run:
		for option: Control in player2_options:
			option.hide()
	if config.nmb_of_players == Const.ENTER_PLAYERS_NMB.TWO_PLAYERS:
		for option: Control in player2_options:
			var is_versus_option: bool = versus_options.find(option) > -1
			if is_versus_run:
				option.show()
			elif is_relic_run and is_versus_option:
				option.hide()
			else:
				option.show()

func _on_p1_dome_selected(index: int):
	config.p1_dome = Const.ENTER_DOME.values()[index]

func _on_p2_dome_selected(index: int):
	config.p2_dome = Const.ENTER_DOME.values()[index]
