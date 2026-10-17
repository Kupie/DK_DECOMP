extends Node

class_name BlockList
signal close

const BLOCK_LIST_PATH: String = "user://block_list.json"
const BLOCK_LIST_MAX_ENTRY: int = 100

static var local_list: Dictionary
static var to_remove_from_block_list: Array
static var to_add_to_block_list: Dictionary

func _ready() -> void :
	for blocked_user in BlockList.local_list:
		var line: Control = preload("res://systems/options/BlockListLine.tscn").instantiate()
		line.playfab_id = blocked_user
		line.user_name = BlockList.local_list[blocked_user].user_name
		line.platform_id = BlockList.local_list[blocked_user].platform_id
		line.platform_user_id = BlockList.local_list[blocked_user].platform_user_id
		%BlockVBoxContainer.add_child(line)
	%DescriptionLabel.text = tr("options.game.blocklist.desc") % str(BLOCK_LIST_MAX_ENTRY)
	%UnblockAllButton.disabled = BlockList.local_list.is_empty()
	InputSystem.grabFocus( %CloseButton)
	Style.init(self)

func _on_close_button_pressed() -> void :
	Audio.sound("gui_back")
	emit_signal("close")

func _on_unblock_all_button_pressed() -> void :
	Audio.sound("gui_select")
	BlockList.remove_all_blocked_user()
	%UnblockAllButton.disabled = true
	for entry in %BlockVBoxContainer.get_children():
		entry.get_node("UnblockButton").disabled = true

static func load_block_list():
	if has_pending_changes():
		Logger.info("Unsaved changes when loading the Block List")
	var file: = FileAccess.open(BLOCK_LIST_PATH, FileAccess.READ)
	if file:
		var content: = file.get_as_text()
		var parsed = JSON.parse_string(content)
		if parsed:
			local_list = parsed
		clear_pending_changes()
		Logger.info("Block List loaded: %s" % str(local_list))
	else:
		Logger.error("Failed to load Block List at '%s'" % BLOCK_LIST_PATH)

static func save_block_list():
	if not has_pending_changes():
		return
	var file: = FileAccess.open(BLOCK_LIST_PATH, FileAccess.WRITE)
	if file:
		for blocked_user in to_remove_from_block_list:
			local_list.erase(blocked_user)
		local_list.merge(to_add_to_block_list)
		file.store_string(JSON.stringify(local_list))
		clear_pending_changes()
		Logger.info("Block List saved: %s" % str(local_list))
	else:
		Logger.error("Failed to save Block List at '%s'" % BLOCK_LIST_PATH)

static func block_user(playfab_id: String, user_name: String, platform_id: String, platform_user_id: String):
	if is_user_blocked(playfab_id) or is_block_list_full():
		return false
	Logger.info("User %s is added to the Block List (%s/ %s / %s)" % [str(user_name), str(playfab_id), str(platform_id), str(platform_user_id)])
	to_add_to_block_list[playfab_id] = {
		"user_name": user_name, 
		"platform_id": platform_id, 
		"platform_user_id": platform_user_id
	}
	return true

static func remove_blocked_user(playfab_id: String):
	if not is_user_blocked(playfab_id):
		return false
	Logger.info("User %s is removed from the Block List" % str(playfab_id))
	to_remove_from_block_list.append(playfab_id)
	return true

static func remove_all_blocked_user():
	clear_pending_changes()
	for blocked_user in local_list:
		remove_blocked_user(blocked_user)

static func is_user_blocked(playfab_id: String, ignore_current_changes: bool = false):
	if ignore_current_changes:
		return local_list.has(playfab_id)
	else:
		return (local_list.has(playfab_id) and not to_remove_from_block_list.has(playfab_id)) or to_add_to_block_list.has(playfab_id)

static func is_block_list_full(ignore_current_changes: bool = false):
	if ignore_current_changes:
		return local_list.size() >= BLOCK_LIST_MAX_ENTRY
	else:
		return local_list.size() - to_remove_from_block_list.size() + to_add_to_block_list.size() >= BLOCK_LIST_MAX_ENTRY

static func clear_pending_changes():
	to_remove_from_block_list.clear()
	to_add_to_block_list.clear()

static func has_pending_changes():
	return not to_remove_from_block_list.is_empty() or not to_add_to_block_list.is_empty()


static func get_full_block_list():
	var full_block_list: Dictionary
	full_block_list["playfab"] = []
	for blocked_user in local_list:
		full_block_list["playfab"].append(blocked_user)
	full_block_list[Platform.get_platform_id()] = Platform.get_block_list_per_device_id(0)
	return full_block_list
