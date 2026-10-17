class_name _ModLoaderScriptExtension
extends RefCounted




const LOG_NAME: = "ModLoader:ScriptExtension"



static func handle_script_extensions() -> void :
	var extension_paths: = []
	for extension_path in ModLoaderStore.script_extensions:
		if FileAccess.file_exists(extension_path):
			extension_paths.push_back(extension_path)
		else:
			ModLoaderLog.error(
				"The child script path '%s' does not exist" % [extension_path], LOG_NAME
			)


	InheritanceSorting.new(extension_paths)


	for extension in extension_paths:
		var script: Script = apply_extension(extension)
		_reload_vanilla_child_classes_for(script)





class InheritanceSorting:
	var stack_cache: = {}

	var load_order: = {}

	func _init(inheritance_array_to_sort: Array) -> void :
		_populate_load_order_table()
		inheritance_array_to_sort.sort_custom(check_inheritances)



	func check_inheritances(extension_a: String, extension_b: String) -> bool:
		var a_stack: = cached_inheritances_stack(extension_a)
		var b_stack: = cached_inheritances_stack(extension_b)

		var last_index: int
		for index in a_stack.size():
			if index >= b_stack.size():
				return false
			if a_stack[index] != b_stack[index]:
				return a_stack[index] < b_stack[index]
			last_index = index

		if last_index < b_stack.size() - 1:
			return true

		return compare_mods_order(extension_a, extension_b)





	func cached_inheritances_stack(extension_path: String) -> Array:
		if stack_cache.has(extension_path):
			return stack_cache[extension_path]

		var stack: = []

		var parent_script: Script = load(extension_path)
		while parent_script:
			stack.push_front(parent_script.resource_path)
			parent_script = parent_script.get_base_script()
		stack.pop_back()

		stack_cache[extension_path] = stack
		return stack



	func compare_mods_order(extension_a: String, extension_b: String) -> bool:
		var mod_a_id: String = _ModLoaderPath.get_mod_dir(extension_a)
		var mod_b_id: String = _ModLoaderPath.get_mod_dir(extension_b)

		return load_order[mod_a_id] < load_order[mod_b_id]


	func _populate_load_order_table() -> void :
		var mod_index: = 0
		for mod in ModLoaderStore.mod_load_order:
			load_order[mod.dir_name] = mod_index
			mod_index += 1


static func apply_extension(extension_path: String) -> Script:

	if not FileAccess.file_exists(extension_path):
		ModLoaderLog.error("The child script path '%s' does not exist" % [extension_path], LOG_NAME)
		return null

	var child_script: Script = load(extension_path)




	child_script.set_meta("extension_script_path", extension_path)







	child_script.reload()

	var parent_script: Script = child_script.get_base_script()
	var parent_script_path: String = parent_script.resource_path



	if not ModLoaderStore.saved_scripts.has(parent_script_path):
		ModLoaderStore.saved_scripts[parent_script_path] = []


		ModLoaderStore.saved_scripts[parent_script_path].append(parent_script.duplicate())

	ModLoaderStore.saved_scripts[parent_script_path].append(child_script)

	ModLoaderLog.info(
		"Installing script extension: %s <- %s" % [parent_script_path, extension_path], LOG_NAME
	)
	child_script.take_over_path(parent_script_path)

	return child_script





static func _reload_vanilla_child_classes_for(script: Script) -> void :
	if script == null:
		return
	var current_child_classes: = []
	var actual_path: String = script.get_base_script().resource_path
	var classes: Array = ProjectSettings.get_global_class_list()

	for _class in classes:
		if _class.path == actual_path:
			current_child_classes.push_back(_class)
			break

	for _class in current_child_classes:
		for child_class in classes:
			if child_class.base == _class.get_class():
				load(child_class.path).reload()
