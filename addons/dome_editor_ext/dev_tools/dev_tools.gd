extends Node




const STORAGE_DIRECTORY_PATH: = "res://.godot/dome_editor_ext_dev_tools/"
const DEFAULT_FILE = "default.json"
const CLIENT_FILE = "client.json"

var _in_custom_editor_play: bool = false
var _restore_windows_upon_startup: bool = false

func _ready() -> void :
	if Engine.is_editor_hint():
		return
	if OS.has_feature("editor") and ResourceLoader.exists(Const.EDITOR_CONF_PATH):
		var editor_conf: DomeEditorConf = load(Const.EDITOR_CONF_PATH)
		if editor_conf:
			_in_custom_editor_play = editor_conf.custom_play_pressed
			_restore_windows_upon_startup = editor_conf.restore_windows_upon_startup

	if not _in_custom_editor_play:
		return

	var is_client: = UtilsOS.has_startup_argument("--client")
	var filename: = CLIENT_FILE if is_client else DEFAULT_FILE
	var dev_data: Dictionary = _load_dict_from_file(filename)
	if dev_data.is_empty():
		return

	if _restore_windows_upon_startup:
		_startup_windows_restore(dev_data)

func _startup_windows_restore(in_dev_data) -> void :
	get_tree().root.mode = int(in_dev_data.get("window_mode", 0))
	await get_tree().process_frame
	get_tree().root.current_screen = int(in_dev_data.get("current_screen", get_tree().root.current_screen))
	get_tree().root.size = vector2_from_string(in_dev_data.get("window_size"))
	get_tree().root.position = vector2_from_string(in_dev_data.get("window_position"))


func vector2_from_string(s: String) -> Vector2:
	var trimmed: = s.strip_edges().strip_escapes().replace("(", "").replace(")", "")
	var parts: = trimmed.split(",")
	if parts.size() == 2:
		return Vector2(parts[0].to_float(), parts[1].to_float())
	return Vector2.ZERO


func _exit_tree() -> void :
	if Engine.is_editor_hint():
		return
	if not _in_custom_editor_play:
		return

	var dev_data: Dictionary = {
		"window_position": get_tree().root.position, 
		"window_size": get_tree().root.size, 
		"window_mode": get_tree().root.mode, 
		"current_screen": get_tree().root.current_screen
	}
	var is_client: = UtilsOS.has_startup_argument("--client")
	var filename: = CLIENT_FILE if is_client else DEFAULT_FILE
	_save_dict_to_file(filename, dev_data)


func _save_dict_to_file(path: String, data: Dictionary) -> void :
	path = STORAGE_DIRECTORY_PATH + path
	_ensure_directory_exists(STORAGE_DIRECTORY_PATH)
	var file: = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _load_dict_from_file(path: String) -> Dictionary:
	path = STORAGE_DIRECTORY_PATH + path
	var file: = FileAccess.open(path, FileAccess.READ)
	if file:
		var content: = file.get_as_text()
		file.close()
		var result: Dictionary = JSON.parse_string(content)
		if typeof(result) == TYPE_DICTIONARY:
			return result
	return {}


func _ensure_directory_exists(path: String) -> void :
	if not DirAccess.dir_exists_absolute(path):
		var err: = DirAccess.make_dir_recursive_absolute(path)
		if err != OK:
			push_error("Failed to create directory: %s (Error %d)" % [path, err])
