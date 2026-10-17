class_name ModLoaderMod
extends Object









const LOG_NAME: = "ModLoader:Mod"

























static func install_script_extension(child_script_path: String) -> void :
	var mod_id: String = _ModLoaderPath.get_mod_dir(child_script_path)
	var mod_data: ModData = get_mod_data(mod_id)
	if not ModLoaderStore.saved_extension_paths.has(mod_data.manifest.get_mod_id()):
		ModLoaderStore.saved_extension_paths[mod_data.manifest.get_mod_id()] = []
	ModLoaderStore.saved_extension_paths[mod_data.manifest.get_mod_id()].append(child_script_path)



	if ModLoaderStore.is_initializing:
		ModLoaderStore.script_extensions.push_back(child_script_path)


	else:
		_ModLoaderScriptExtension.apply_extension(child_script_path)























static func install_script_hooks(vanilla_script_path: String, hook_script_path: String) -> void :
	var hook_script: = load(hook_script_path) as GDScript
	var hook_script_instance: = hook_script.new()





	if hook_script_instance is RefCounted:
		ModLoaderLog.fatal(
			"Scripts holding mod hooks should always extend Object (%s)"
			%hook_script_path, LOG_NAME
		)

	var vanilla_script: = load(vanilla_script_path) as GDScript
	var vanilla_methods: = vanilla_script.get_script_method_list().map(
		func(method: Dictionary) -> String:
			return method.name
	)

	var methods: = hook_script.get_script_method_list()
	for hook in methods:
		if hook.name in vanilla_methods:
			ModLoaderMod.add_hook(Callable(hook_script_instance, hook.name), vanilla_script_path, hook.name)
			continue

		ModLoaderLog.debug(
			"Skipped adding hook \"%s\" (not found in vanilla script %s)"
			%[hook.name, vanilla_script_path], LOG_NAME
		)

		if not OS.has_feature("editor"):
			continue

		vanilla_methods.sort_custom((
			func(a_name: String, b_name: String, target_name: String) -> bool:
				return a_name.similarity(target_name) > b_name.similarity(target_name)
		).bind(hook.name))

		var closest_vanilla: String = vanilla_methods.front()
		if closest_vanilla.similarity(hook.name) > 0.8:
			ModLoaderLog.hint(
				"Did you mean \"%s\" instead of \"%s\"?"
				%[closest_vanilla, hook.name], LOG_NAME
			)


















































































static func add_hook(mod_callable: Callable, script_path: String, method_name: String) -> void :
	_ModLoaderHooks.add_hook(mod_callable, script_path, method_name)

















static func register_global_classes_from_array(new_global_classes: Array) -> void :
	ModLoaderUtils.register_global_classes_from_array(new_global_classes)
	var _savecustom_error: int = ProjectSettings.save_custom(_ModLoaderPath.get_override_path())














static func add_translation(resource_path: String) -> void :
	if not _ModLoaderFile.file_exists(resource_path):
		ModLoaderLog.fatal("Tried to load a position resource from a file that doesn't exist. The invalid path was: %s" % [resource_path], LOG_NAME)
		return

	var translation_object: Translation = load(resource_path)
	if translation_object:
		TranslationServer.add_translation(translation_object)
		ModLoaderLog.info("Added Translation from Resource -> %s" % resource_path, LOG_NAME)
	else:
		ModLoaderLog.fatal("Failed to load translation at path: %s" % [resource_path], LOG_NAME)






















static func refresh_scene(scene_path: String) -> void :
	if scene_path in ModLoaderStore.scenes_to_refresh:
		return

	ModLoaderStore.scenes_to_refresh.push_back(scene_path)
	ModLoaderLog.debug("Added \"%s\" to be refreshed." % scene_path, LOG_NAME)












static func extend_scene(scene_vanilla_path: String, edit_callable: Callable) -> void :
	if not ModLoaderStore.scenes_to_modify.has(scene_vanilla_path):
		ModLoaderStore.scenes_to_modify[scene_vanilla_path] = []

	ModLoaderStore.scenes_to_modify[scene_vanilla_path].push_back(edit_callable)









static func get_mod_data(mod_id: String) -> ModData:
	if not ModLoaderStore.mod_data.has(mod_id):
		ModLoaderLog.error("%s is an invalid mod_id" % mod_id, LOG_NAME)
		return null

	return ModLoaderStore.mod_data[mod_id]






static func get_mod_data_all() -> Dictionary:
	return ModLoaderStore.mod_data






static func get_unpacked_dir() -> String:
	return _ModLoaderPath.get_unpacked_mods_dir_path()









static func is_mod_loaded(mod_id: String) -> bool:
	if ModLoaderStore.is_initializing:
		ModLoaderLog.warning(
			"The ModLoader is not fully initialized. " + 
			"Calling \"is_mod_loaded()\" in \"_init()\" may result in an unexpected return value as mods are still loading.", 
			LOG_NAME
		)


	if not ModLoaderStore.mod_data.has(mod_id) or not ModLoaderStore.mod_data[mod_id].is_loadable:
		return false

	return true









static func is_mod_active(mod_id: String) -> bool:
	return is_mod_loaded(mod_id) and ModLoaderStore.mod_data[mod_id].is_active
