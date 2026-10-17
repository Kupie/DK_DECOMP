@tool
class_name ModLoaderLog
extends Object





const MOD_LOG_PATH: = "user://logs/modloader.log"

const _LOG_NAME: = "ModLoader:Log"


enum VERBOSITY_LEVEL{
	ERROR, 
	WARNING, 
	INFO, 
	DEBUG, 
}




static var logged_messages: = {
	"all": {}, 
	"by_mod": {}, 
	"by_type": {
		"fatal-error": {}, 
		"error": {}, 
		"warning": {}, 
		"info": {}, 
		"success": {}, 
		"debug": {}, 
		"hint": {}, 
	}
}




static var verbosity: VERBOSITY_LEVEL = VERBOSITY_LEVEL.DEBUG


static var ignored_mods: Array[String] = []


static var warning_color: = Color("#ffde66")
static var success_color: = Color("#5d8c3f")
static var info_color: = Color("#70bafa")
static var hint_color: = Color("#b293fa")
static var debug_color: = Color("#d4d4d4")
static var debug_bold: = true


class ModLoaderLogEntry:
	extends Resource


	var mod_name: String


	var message: String


	var type: String



	var time: String



	var time_stamp: int



	var stack: = []












	func _init(_mod_name: String, _message: String, _type: String, _time: String) -> void :
		mod_name = _mod_name
		message = _message
		type = _type
		time = _time
		time_stamp = Time.get_ticks_msec()





	func get_entry() -> String:
		return str(time, get_prefix(), message)








	func get_prefix(exclude_type: = false) -> String:
		return "%s%s: " % [
			"" if exclude_type else "%s " % type.to_upper(), 
			mod_name
		]





	func get_md5() -> String:
		return str(get_prefix(), message).md5_text()





	func get_all_entries() -> Array:
		var entries: = [self]
		entries.append_array(stack)

		return entries





















static func fatal(message: String, mod_name: String, only_once: = false) -> void :
	_log(message, mod_name, "fatal-error", only_once)












static func error(message: String, mod_name: String, only_once: = false) -> void :
	_log(message, mod_name, "error", only_once)












static func warning(message: String, mod_name: String, only_once: = false) -> void :
	_log(message, mod_name, "warning", only_once)












static func info(message: String, mod_name: String, only_once: = false) -> void :
	_log(message, mod_name, "info", only_once)












static func success(message: String, mod_name: String, only_once: = false) -> void :
	_log(message, mod_name, "success", only_once)












static func debug(message: String, mod_name: String, only_once: = false) -> void :
	_log(message, mod_name, "debug", only_once)
















static func hint(message: String, mod_name: String, only_once: = false) -> void :
	_log(message, mod_name, "hint", only_once)













static func debug_json_print(message: String, json_printable, mod_name: String, only_once: = false) -> void :
	message = "%s\n%s" % [message, JSON.stringify(json_printable, "  ")]
	_log(message, mod_name, "debug", only_once)










static func get_all_as_resource() -> Array:
	return get_all()






static func get_all_as_string() -> Array:
	var log_entries: = get_all()
	return get_all_entries_as_string(log_entries)









static func get_by_mod_as_resource(mod_name: String) -> Array:
	return get_by_mod(mod_name)









static func get_by_mod_as_string(mod_name: String) -> Array:
	var log_entries: = get_by_mod(mod_name)
	return get_all_entries_as_string(log_entries)









static func get_by_type_as_resource(type: String) -> Array:
	return get_by_type(type)









static func get_by_type_as_string(type: String) -> Array:
	var log_entries: = get_by_type(type)
	return get_all_entries_as_string(log_entries)






static func get_all() -> Array:
	var log_entries: = []


	for entry_key in logged_messages.all.keys():
		var entry: ModLoaderLogEntry = logged_messages.all[entry_key]
		log_entries.append_array(entry.get_all_entries())


	log_entries.sort_custom(Callable(ModLoaderLogCompare, "time"))

	return log_entries









static func get_by_mod(mod_name: String) -> Array:
	var log_entries: = []

	if not logged_messages.by_mod.has(mod_name):
		error("\"%s\" not found in logged messages." % mod_name, _LOG_NAME)
		return []

	for entry_key in logged_messages.by_mod[mod_name].keys():
		var entry: ModLoaderLogEntry = logged_messages.by_mod[mod_name][entry_key]
		log_entries.append_array(entry.get_all_entries())

	return log_entries









static func get_by_type(type: String) -> Array:
	var log_entries: = []

	for entry_key in logged_messages.by_type[type].keys():
		var entry: ModLoaderLogEntry = logged_messages.by_type[type][entry_key]
		log_entries.append_array(entry.get_all_entries())

	return log_entries









static func get_all_entries_as_string(log_entries: Array) -> Array:
	var log_entry_strings: = []


	for entry in log_entries:
		log_entry_strings.push_back(entry.get_entry())

	return log_entry_strings





static func _print_rich(prefix: String, message: String, color: Color, bold: = true) -> void :
	if OS.has_feature("editor"):
		var prefix_text: = "[b]%s[/b]" % prefix if bold else prefix
		print_rich("[color=%s]%s[/color]%s" % [
			color.to_html(false), 
			prefix_text, 
			message
		])
	else:
		print(prefix + message)

static func _log(message: String, mod_name: String, log_type: String = "info", only_once: = false) -> void :
	if _is_mod_name_ignored(mod_name):
		return

	var time: = "%s   " % _get_time_string()
	var log_entry: = ModLoaderLogEntry.new(mod_name, message, log_type, time)

	if only_once and _is_logged_before(log_entry):
		return

	_store_log(log_entry)


	if Engine.get_main_loop() and ModLoader:
		ModLoader.emit_signal("logged", log_entry)

	_code_note(str(
		"If you are seeing this after trying to run the game, there is an error in your mod somewhere.", 
		"Check the Debugger tab (below) to see the error.", 
		"Click through the files listed in Stack Frames to trace where the error originated.", 
		"View Godot's documentation for more info:", 
		"https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html#doc-debugger-panel"
	))

	match log_type.to_lower():
		"fatal-error":
			push_error(message)
			_write_to_log_file(log_entry.get_entry())
			_write_to_log_file(JSON.stringify(get_stack(), "  "))
			assert (false, message)
		"error":
			if ModLoaderStore.has_feature.editor:
				printerr(log_entry.get_prefix(true) + message)
			else:
				printerr(log_entry.get_prefix() + message)
			push_error(message)
			_write_to_log_file(log_entry.get_entry())
		"warning":
			if verbosity >= VERBOSITY_LEVEL.WARNING:
				_print_rich(log_entry.get_prefix(), message, warning_color)
				push_warning(message)
				_write_to_log_file(log_entry.get_entry())
		"success":
			if verbosity >= VERBOSITY_LEVEL.INFO:
				_print_rich(log_entry.get_prefix(), message, success_color)
				_write_to_log_file(log_entry.get_entry())
		"info":
			if verbosity >= VERBOSITY_LEVEL.INFO:
				_print_rich(log_entry.get_prefix(), message, info_color)
				_write_to_log_file(log_entry.get_entry())
		"debug":
			if verbosity >= VERBOSITY_LEVEL.DEBUG:
				_print_rich(log_entry.get_prefix(), message, debug_color, debug_bold)
				_write_to_log_file(log_entry.get_entry())
		"hint":
			if (
				ModLoaderStore.has_feature.editor and 
				verbosity >= VERBOSITY_LEVEL.DEBUG
			):
				_print_rich(log_entry.get_prefix(), message, hint_color)


static func _is_mod_name_ignored(mod_name: String) -> bool:
	if ignored_mods.is_empty():
		return false

	if mod_name in ignored_mods:
		return true

	return false


static func _store_log(log_entry: ModLoaderLogEntry) -> void :
	var existing_entry: ModLoaderLogEntry



	if not logged_messages.all.has(log_entry.get_md5()):
		logged_messages.all[log_entry.get_md5()] = log_entry

	else:
		existing_entry = logged_messages.all[log_entry.get_md5()]
		existing_entry.time = log_entry.time
		existing_entry.stack.push_back(log_entry)



	if not logged_messages.by_mod.has(log_entry.mod_name):
		logged_messages.by_mod[log_entry.mod_name] = {}

	logged_messages.by_mod[log_entry.mod_name][log_entry.get_md5()] = log_entry if not existing_entry else existing_entry


	logged_messages.by_type[log_entry.type.to_lower()][log_entry.get_md5()] = log_entry if not existing_entry else existing_entry


static func _is_logged_before(entry: ModLoaderLogEntry) -> bool:
	if not logged_messages.all.has(entry.get_md5()):
		return false

	return true


class ModLoaderLogCompare:

	static func time(a: ModLoaderLogEntry, b: ModLoaderLogEntry) -> bool:
		if a.time_stamp > b.time_stamp:
			return true
		else:
			return false






static func _get_time_string() -> String:
	var date_time: = Time.get_datetime_dict_from_system()
	return "%02d:%02d:%02d" % [date_time.hour, date_time.minute, date_time.second]



static func _get_date_string() -> String:
	var date_time: = Time.get_datetime_dict_from_system()
	return "%s-%02d-%02d" % [date_time.year, date_time.month, date_time.day]



static func _get_date_time_string() -> String:
	return "%s_%s" % [_get_date_string(), _get_time_string()]






static func _write_to_log_file(string_to_write: String) -> void :
	if OS.has_feature("SEAVEN"):
		return
	if not FileAccess.file_exists(MOD_LOG_PATH):
		_rotate_log_file()

	var log_file: = FileAccess.open(MOD_LOG_PATH, FileAccess.READ_WRITE)

	if log_file == null:
		assert (false, "Could not open log file, error code: %s" % error)
		return

	log_file.seek_end()
	log_file.store_string("\n" + string_to_write)
	log_file.close()




static func _rotate_log_file() -> void :
	if OS.has_feature("SEAVEN"):
		return
	var MAX_LOGS: int = ProjectSettings.get_setting("debug/file_logging/max_log_files")

	if FileAccess.file_exists(MOD_LOG_PATH):
		if MAX_LOGS > 1:
			var datetime: = _get_date_time_string().replace(":", ".")
			var backup_name: String = MOD_LOG_PATH.get_basename() + "_" + datetime
			if MOD_LOG_PATH.get_extension().length() > 0:
				backup_name += "." + MOD_LOG_PATH.get_extension()

			var dir: = DirAccess.open(MOD_LOG_PATH.get_base_dir())
			if not dir == null:
				dir.copy(MOD_LOG_PATH, backup_name)
			_clear_old_log_backups()


	var log_file: = FileAccess.open(MOD_LOG_PATH, FileAccess.WRITE)
	if log_file == null:
		assert (false, "Could not open log file, error code: %s" % error)
	log_file.store_string("%s Created log" % _get_date_string())
	log_file.close()


static func _clear_old_log_backups() -> void :
	var MAX_LOGS: = int(ProjectSettings.get_setting("debug/file_logging/max_log_files"))
	var MAX_BACKUPS: = MAX_LOGS - 1
	var basename: = MOD_LOG_PATH.get_file().get_basename() as String
	var extension: = MOD_LOG_PATH.get_extension() as String

	var dir: = DirAccess.open(MOD_LOG_PATH.get_base_dir())
	if dir == null:
		return

	dir.list_dir_begin()
	var file: = dir.get_next()
	var backups: = []
	while file.length() > 0:
		if ( not dir.current_is_dir() and 
				file.begins_with(basename) and 
				file.get_extension() == extension and 
				not file == MOD_LOG_PATH.get_file()):
			backups.append(file)
		file = dir.get_next()
	dir.list_dir_end()

	if backups.size() > MAX_BACKUPS:
		backups.sort()
		backups.resize(backups.size() - MAX_BACKUPS)
		for file_to_delete in backups:
			dir.remove(file_to_delete)











static func _code_note(_msg: String):
	pass
