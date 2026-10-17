@tool
extends Node
class_name ModToolUtils






static func reload_script(script: Script, mod_tool_store: ModToolStore) -> void :
	var pending_reloads: = mod_tool_store.pending_reloads

	if script.resource_path in pending_reloads:
		var source_code_from_disc: = FileAccess.open(script.resource_path, FileAccess.READ).get_as_text()

		var script_editor: = EditorInterface.get_script_editor()
		var text_edit: CodeEdit = script_editor.get_current_editor().get_base_editor()

		var column: = text_edit.get_caret_column()
		var row: = text_edit.get_caret_line()
		var scroll_position_h: = text_edit.get_h_scroll_bar().value
		var scroll_position_v: = text_edit.get_v_scroll_bar().value

		text_edit.text = source_code_from_disc
		text_edit.set_caret_column(column)
		text_edit.set_caret_line(row)
		text_edit.scroll_horizontal = scroll_position_h
		text_edit.scroll_vertical = scroll_position_v

		text_edit.tag_saved_version()

		pending_reloads.erase(script.resource_path)



static func is_file_extension(path: String, excluded_extensions: PackedStringArray) -> bool:
	var is_extension: = false

	for extension in excluded_extensions:
		var file_name: = path.get_file()
		if (extension in file_name):
			is_extension = true
			break
		else:
			is_extension = false

	return is_extension



static func file_get_as_text(path: String) -> String:
	var file_access: = FileAccess.open(path, FileAccess.READ)
	var content: = file_access.get_as_text()
	file_access.close()
	return content





static func file_copy(src: String, dst: String) -> void :
	var dst_dir: = dst.get_base_dir()

	if not DirAccess.dir_exists_absolute(dst_dir):
		DirAccess.make_dir_recursive_absolute(dst_dir)

	DirAccess.copy_absolute(src, dst)



static func output_error(message) -> void :
	printerr("ModTool Error: " + str(message))


static func output_info(message) -> void :
	print("ModTool: " + str(message))


static func save_to_manifest_json(manifest_data: ModManifest, path_manifest: String) -> bool:
	var is_success: = _ModLoaderFile._save_string_to_file(
		manifest_data.to_json(), 
		path_manifest
	)

	if is_success:
		output_info("Successfully saved manifest.json file!")

	return is_success


static func make_dir_recursive(dst_dir: String) -> bool:
	var error: = DirAccess.make_dir_recursive_absolute(dst_dir)
	if not error == OK:
		output_error("Failed creating directory at %s with error \"%s\"" % [dst_dir, error_string(error)])
		return false
	return true




static func remove_recursive(path: String) -> void :
	var directory: = DirAccess.open(path)

	if not directory:
		print("Error removing " + path)
		return


	directory.list_dir_begin()
	var file_name: = directory.get_next()
	while file_name != "":
		if directory.current_is_dir():
			remove_recursive(path + "/" + file_name)
		else:
			directory.remove(file_name)
		file_name = directory.get_next()


	directory.remove(path)


static func check_for_hooked_script(script_paths: Array[String], mod_tool_store: ModToolStore) -> int:
	var count: = 0

	for script_path in script_paths:
		if mod_tool_store.hooked_scripts.has(script_path):
			count += 1

	return count


static func quote_string(string: String) -> String:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings.get_setting("text_editor/completion/use_single_quotes"):
		return "'%s'" % string
	return "\"%s\"" % string


static func script_has_method(script_path: String, method: String) -> bool:
	var script: Script = load(script_path)

	for script_method in script.get_script_method_list():
		if script_method.name == method:
			return true

	if method in script.source_code:
		return true

	return false


static func get_index_at_method_end(method_name: String, text: String) -> int:
	var starting_index: = text.rfind(method_name)


	var next_method_line_index: = text.find("func ", starting_index)
	var method_end: = -1

	if next_method_line_index == -1:

		method_end = text.length() - 1
	else:

		method_end = text.rfind("\n", next_method_line_index)


	var last_non_empty_line_index: = method_end
	while last_non_empty_line_index > starting_index:
		last_non_empty_line_index -= 1

		if text[last_non_empty_line_index].rstrip("\t\n "):
			break

	return last_non_empty_line_index + 1







static func get_flat_view_dict(
	p_dir: = "res://", 
		p_match: = "", 
	p_match_file_extensions: Array[StringName] = [], 
	p_match_is_regex: = false, 
	include_empty_dirs: = false, 
	ignored_dirs: Array[StringName] = []
) -> PackedStringArray:
	var data: PackedStringArray = []
	var regex: RegEx

	if p_match_is_regex:
		regex = RegEx.new()
		var _compile_error: int = regex.compile(p_match)
		if not regex.is_valid():
			return data

	var dirs: = [p_dir]
	var first: = true
	while not dirs.is_empty():
		var dir_name: String = dirs.back()
		var dir: = DirAccess.open(dir_name)
		dirs.pop_back()

		if dir_name.lstrip("res://").get_slice("/", 0) in ignored_dirs:
			continue

		if dir:
			var _dirlist_error: int = dir.list_dir_begin()
			var file_name: = dir.get_next()
			if include_empty_dirs and not dir_name == p_dir:
				data.append(dir_name)
			while file_name != "":
				if not dir_name == "res://":
					first = false

				if not file_name.begins_with(".") and not file_name.get_extension() == "tmp":

					if dir.current_is_dir():
						dirs.push_back(dir.get_current_dir() + "/" + file_name)

					else:
						var path: = dir.get_current_dir() + ("/" if not first else "") + file_name

						if not p_match and not p_match_file_extensions:
							data.append(path)

						elif not p_match_is_regex and p_match and file_name.contains(p_match):
							data.append(path)

						elif p_match_file_extensions and file_name.get_extension() in p_match_file_extensions:
							data.append(path)

						elif p_match_is_regex:
							var regex_match: = regex.search(path)
							if regex_match != null:
								data.append(path)

				file_name = dir.get_next()

			dir.list_dir_end()
	return data
