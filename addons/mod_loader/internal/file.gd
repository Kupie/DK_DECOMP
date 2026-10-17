class_name _ModLoaderFile
extends RefCounted





const LOG_NAME: = "ModLoader:File"






static func get_json_as_dict(path: String) -> Dictionary:
	if not file_exists(path):
		return {}

	var file: = FileAccess.open(path, FileAccess.READ)
	var error = file.get_open_error()

	if file == null:
		ModLoaderLog.error("Error opening file. Code: %s" % error, LOG_NAME)

	var content: = file.get_as_text()
	return _get_json_string_as_dict(content)




static func _get_json_string_as_dict(string: String) -> Dictionary:
	if string == "":
		return {}

	var test_json_conv = JSON.new()
	var error = test_json_conv.parse(string)
	if not error == OK:
		ModLoaderLog.error("Error parsing JSON", LOG_NAME)
		return {}

	if not test_json_conv.data is Dictionary:
		ModLoaderLog.error("JSON is not a dictionary", LOG_NAME)
		return {}
	return test_json_conv.data



static func open_dir(folder_path: String) -> DirAccess:
	var mod_dir: = DirAccess.open(folder_path)
	if mod_dir == null:
		ModLoaderLog.error("Can't open mod folder %s" % [folder_path], LOG_NAME)
		return null

	var mod_dir_open_error: = mod_dir.get_open_error()
	if not mod_dir_open_error == OK:
		ModLoaderLog.info(
			"Can't open mod folder %s (Error: %s, %s)" %
			[folder_path, mod_dir_open_error, error_string(mod_dir_open_error)], 
			LOG_NAME
		)
		return null
	var mod_dir_listdir_error: = mod_dir.list_dir_begin()
	if not mod_dir_listdir_error == OK:
		ModLoaderLog.error(
			"Can't read mod folder %s (Error: %s, %s)" %
			[folder_path, mod_dir_listdir_error, error_string(mod_dir_listdir_error)], 
			LOG_NAME
		)
		return null

	return mod_dir


static func get_json_as_dict_from_zip(zip_path: String, file_path: String, is_full_path: = false) -> Dictionary:
	if not file_exists(zip_path):
		ModLoaderLog.error("Zip was not found at %s" % [zip_path], LOG_NAME)
		return {}

	var reader: = ZIPReader.new()

	var zip_open_error: = reader.open(zip_path)
	if not zip_open_error == OK:
		ModLoaderLog.error(
			"Error opening zip. (Error: %s, %s)" %
			[zip_open_error, error_string(zip_open_error)], 
			LOG_NAME
		)

	var full_path: = ""
	if is_full_path:
		full_path = file_path
		if not reader.file_exists(full_path):
			ModLoaderLog.error("File was not found in zip at path %s" % [file_path], LOG_NAME)
			return {}
	else:



		for path in reader.get_files():
			if Array(path.rsplit("/", false, 1)).back() == file_path:
				full_path = path
		if not full_path:
			ModLoaderLog.error("File was not found in zip at path %s" % [file_path], LOG_NAME)
			return {}

	var content: = reader.read_file(full_path).get_string_from_utf8()
	return _get_json_string_as_dict(content)






static func _save_string_to_file(save_string: String, filepath: String) -> bool:

	var file_directory: = filepath.get_base_dir()
	var dir: = DirAccess.open(file_directory)

	_code_note(str(
		"View error codes here:", 
		"https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error"
	))

	if not dir:
		var makedir_error: = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(file_directory))
		if not makedir_error == OK:
			ModLoaderLog.fatal("Encountered an error (%s) when attempting to create a directory, with the path: %s" % [makedir_error, file_directory], LOG_NAME)
			return false


	var file: = FileAccess.open(filepath, FileAccess.WRITE)

	if not file:
		ModLoaderLog.fatal("Encountered an error (%s) when attempting to write to a file, with the path: %s" % [FileAccess.get_open_error(), filepath], LOG_NAME)
		return false

	file.store_string(save_string)
	file.close()

	return true



static func save_dictionary_to_json_file(data: Dictionary, filepath: String) -> bool:
	var json_string: = JSON.stringify(data, "\t")
	return _save_string_to_file(json_string, filepath)






static func remove_file(file_path: String) -> bool:
	var dir: = DirAccess.open(file_path)

	if not dir.file_exists(file_path):
		ModLoaderLog.error("No file found at \"%s\"" % file_path, LOG_NAME)
		return false

	var error: = dir.remove(file_path)

	if error:
		ModLoaderLog.error(
			"Encountered an error (%s) when attempting to remove the file, with the path: %s"
			%[error, file_path], 
			LOG_NAME
		)
		return false

	return true





static func file_exists(path: String, zip_path: String = "") -> bool:
	if not zip_path.is_empty():
		return file_exists_in_zip(zip_path, path)

	var exists: = FileAccess.file_exists(path)


	if not exists:
		exists = ResourceLoader.exists(path)

	return exists


static func dir_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)


static func file_exists_in_zip(zip_path: String, path: String) -> bool:
	var reader: = zip_reader_open(zip_path)
	if not reader:
		return false

	return reader.get_files().has(path.trim_prefix("res://"))


static func get_mod_dir_name_in_zip(zip_path: String) -> String:
	var reader: = _ModLoaderFile.zip_reader_open(zip_path)
	if not reader:
		return ""

	var file_paths: = reader.get_files()

	for file_path in file_paths:

		if file_path.ends_with("mod_main.gd") and file_path.split("/").size() == 3:
			return file_path.split("/")[-2]

	return ""


static func zip_reader_open(zip_path) -> ZIPReader:
	var reader: = ZIPReader.new()
	var err: = reader.open(zip_path)
	if err != OK:
		ModLoaderLog.error("Could not open zip with error: %s" % error_string(err), LOG_NAME)
		return
	return reader


static func load_manifest_file(path: String) -> Dictionary:
	ModLoaderLog.debug("Loading mod_manifest from -> %s" % path, LOG_NAME)

	if _ModLoaderPath.is_zip(path):
		return get_json_as_dict_from_zip(path, ModData.MANIFEST)

	return get_json_as_dict(path.path_join(ModData.MANIFEST))





static func _code_note(_msg: String):
	pass
