@tool
extends EditorPlugin

const SAVE_FILE_PATH: = "res://addons/exqueezite_data/exqueezite_used_properties.txt"
const DATA_UPDATE_FUNC_TEMPLATE: = "\nfunc data_update(_property, new_val, old_val):\n\tmatch _property:\n\t\t\"\":\n\t\t\tpass\n"






var used_properties: Array = []
var button: Button

var regex_property_search_patterns = {
		"apply": "Data\\.apply\\(\\\"([^\\\"]+)\\\"", 
		"event": "Data\\.event\\(\\\"([^\\\"]+)\\\"", 
		"of": "Data\\.of\\(\\\"([^\\\"]+)\\\"", 
		"ofOr": "Data\\.ofOr\\(\\\"([^\\\"]+)\\\"", 
		"changeByInt": "Data\\.changeByInt\\(\\\"([^\\\"]+)\\\""
	}
var regex_properties: = {}

var regex_autocomplete_patterns = {
		"apply": ["Data\\.apply\\([^)]*$", "\"%s\", "], 
		"of": ["Data\\.of\\([^)]*$", "\"%s\""], 
		"changeByInt": ["Data\\.changeByInt\\([^)]*$", "\"%s\", 1"], 
		"event": ["Data\\.event\\([^)]*$", "\"%s\""], 
		"ofOr": ["Data\\.ofOr\\([^)]*$", "\"%s\", null"], 
		"listen": ["Data\\.listen\\([^)]*$", "self, \"%s\""]
	}
var regex_autocomplete: = {}


func _enter_tree():
	button = Button.new()
	button.text = "🧡 Scrub Data\nProperties"
	button.pressed.connect(_scrub_properties)
	add_control_to_container(CONTAINER_TOOLBAR, button)

	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	script_editor.editor_script_changed.connect(_on_editor_script_changed)
	_load_properties_from_file()

	regex_autocomplete.clear()
	for key in regex_autocomplete_patterns.keys():
		var r: = RegEx.new()
		r.compile(regex_autocomplete_patterns[key][0])
		regex_autocomplete[key] = r

func _exit_tree():
	remove_control_from_container(CONTAINER_TOOLBAR, button)
	button.queue_free()

	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	if script_editor.editor_script_changed.is_connected(_on_editor_script_changed):
		script_editor.editor_script_changed.disconnect(_on_editor_script_changed)

	var base_editor: CodeEdit = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
	if base_editor:
		if base_editor.code_completion_requested.is_connected(_on_code_completion_requested):
			base_editor.code_completion_requested.disconnect(_on_code_completion_requested)

func _scrub_properties():
	used_properties.clear()
	var script_files = _get_all_scripts()

	regex_properties.clear()
	for key in regex_property_search_patterns.keys():
		var r: = RegEx.new()
		r.compile(regex_property_search_patterns[key])
		regex_properties[key] = r

	for script in script_files:
		_scrub_script(script)

	print("🧡 Exqueezite Data - found %s properties." % used_properties.size())
	_save_properties_to_file()

func _get_all_scripts() -> Array:
	var scripts = []
	var dir = DirAccess.open("res://")
	if dir:
		_scan_directory(dir, scripts)
	return scripts

func _scan_directory(directory: DirAccess, scripts: Array):
	directory.list_dir_begin()
	var file_name = directory.get_next()

	while file_name != "":
		if directory.current_is_dir():
			var new_dir_path = directory.get_current_dir().path_join(file_name)
			var new_dir = DirAccess.open(new_dir_path)
			_scan_directory(new_dir, scripts)
		elif file_name.ends_with(".gd"):
			scripts.append(directory.get_current_dir().path_join(file_name))

		file_name = directory.get_next()

	directory.list_dir_end()

func _scrub_script(script_path: String):
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		while not file.eof_reached():
			var line = file.get_line()
			_process_line(line)
		file.close()

func _process_line(line: String):
	for key in regex_property_search_patterns.keys():
		var regex_match: RegExMatch = regex_properties[key].search(line)
		if regex_match:
			var property = regex_match.get_string(1)
			if not used_properties.has(property):
				used_properties.append(property)

func _on_editor_script_changed(_script):
	var base_editor: CodeEdit = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
	if base_editor:
		if not base_editor.code_completion_requested.is_connected(_on_code_completion_requested):
			base_editor.code_completion_requested.connect(_on_code_completion_requested.bind(base_editor))

func _on_code_completion_requested(code_editor):
	if not (code_editor and code_editor is CodeEdit):
		return

	var text_for_completion = code_editor.get_text_for_code_completion()
	var completion_index = text_for_completion.find(char(65535))


	var last_space = text_for_completion.rfind(" ", completion_index)
	var word = ""
	if last_space > -1:
		word = text_for_completion.substr(last_space + 1, completion_index - last_space - 1)
	else:
		word = text_for_completion.substr(0, completion_index)

	word = word.strip_edges()
	var template: = ""
	if word.ends_with("Data"):
		code_editor.cancel_code_completion()
		code_editor.add_code_completion_option(CodeEdit.CodeCompletionKind.KIND_FUNCTION, "Add `data_update`", DATA_UPDATE_FUNC_TEMPLATE, Color.AQUA)
		code_editor.update_code_completion_options(true)
	else:
		for key in regex_autocomplete_patterns.keys():
			if regex_autocomplete[key].search(word):
				template = regex_autocomplete_patterns[key][1]
	if template != "":
		code_editor.cancel_code_completion()
		for prop in used_properties:
			code_editor.add_code_completion_option(CodeEdit.CodeCompletionKind.KIND_VARIABLE, prop, template % prop)
		code_editor.update_code_completion_options(true)

func _save_properties_to_file():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_line(JSON.stringify(used_properties))
		file.close()

func _load_properties_from_file():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		used_properties = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		_scrub_properties()
