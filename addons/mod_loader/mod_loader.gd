


















extends Node



signal logged(entry: ModLoaderLog.ModLoaderLogEntry)


signal current_config_changed(config: ModConfig)

signal new_hooks_created

const LOG_NAME: = "ModLoader"


func _init() -> void :

	if ModLoaderStore.REQUIRE_CMD_LINE and not _ModLoaderCLI.is_running_with_command_line_arg("--enable-mods"):
		return




	if not ModLoaderStore.has_feature.editor and _ModLoaderFile.file_exists(_ModLoaderPath.get_path_to_hook_pack()):
		_load_mod_hooks_pack()


	ModLoaderLog._rotate_log_file()

	if not ModLoaderStore.ml_options.enable_mods:
		ModLoaderLog.info("Mods are currently disabled", LOG_NAME)
		return


	_ModLoaderGodot.check_autoload_positions()


	ModLoaderLog.debug_json_print("Autoload order", _ModLoaderGodot.get_autoload_array(), LOG_NAME)


	ModLoaderLog.info("game_install_directory: %s" % _ModLoaderPath.get_local_folder_dir(), LOG_NAME)


	if ModLoaderUserProfile.is_initialized():
		var _success_user_profile_load: = ModLoaderUserProfile._load()



	if not ModLoaderStore.user_profiles.has("default"):
		var _success_user_profile_create: = ModLoaderUserProfile.create_profile("default")


	var loaded_count: = 0


	var mod_paths: = _ModLoaderPath.get_mod_paths_from_all_sources()

	ModLoaderLog.debug("Found %s mods at the following paths:\n\t - %s" % [mod_paths.size(), "\n\t - ".join(mod_paths)], LOG_NAME)

	for mod_path in mod_paths:
		var is_zip: = _ModLoaderPath.is_zip(mod_path)


		var manifest_data: Dictionary = _ModLoaderFile.load_manifest_file(mod_path)

		var manifest: = ModManifest.new(manifest_data, mod_path)

		if not manifest.validation_messages_error.is_empty():
			ModLoaderLog.error(
				"The mod from path \"%s\" cannot be loaded. Manifest validation failed with the following errors:\n\t - %s" %
				[mod_path, "\n\t - ".join(manifest.validation_messages_error)], LOG_NAME
			)


		var mod: = ModData.new(manifest, mod_path)

		if not mod.load_errors.is_empty():
			ModLoaderStore.ml_options.disabled_mods.append(mod.manifest.get_mod_id())
			ModLoaderLog.error(
				"The mod from path \"%s\" cannot be loaded. ModData initialization has failed with the following errors:\n\t - %s" %
				[mod_path, "\n\t - ".join(mod.load_errors)], LOG_NAME
			)


		ModLoaderStore.mod_data[mod.dir_name] = mod

		if mod.is_loadable:
			if is_zip:
				var is_mod_loaded_successfully: = ProjectSettings.load_resource_pack(mod_path, false)

				if not is_mod_loaded_successfully:
					ModLoaderLog.error("Failed to load mod zip from path \"%s\" into the virtual filesystem." % mod_path, LOG_NAME)
					continue








				if ModLoaderStore.has_feature.editor:
					ModLoaderLog.hint(
						"Loading any resource packs (.zip/.pck) with `load_resource_pack` will WIPE the entire virtual res:// directory. " + 
						"If you have any unpacked mods in %s, they will not be loaded.Please unpack your mod ZIPs instead, and add them to %s" %
						[_ModLoaderPath.get_unpacked_mods_dir_path(), _ModLoaderPath.get_unpacked_mods_dir_path()], LOG_NAME, true
					)

			ModLoaderLog.success("%s loaded." % mod_path, LOG_NAME)
			loaded_count += 1

	ModLoaderLog.success("DONE: Loaded %s mod files into the virtual filesystem" % loaded_count, LOG_NAME)


	var _success_update_mod_lists: = ModLoaderUserProfile._update_mod_lists()


	ModLoaderUserProfile._update_disabled_mods()


	for dir_name in ModLoaderStore.mod_data:
		var mod: ModData = ModLoaderStore.mod_data[dir_name]
		if not mod.is_loadable:
			continue
		if mod.manifest.get("config_schema") and not mod.manifest.config_schema.is_empty():
			mod.load_configs()

	ModLoaderLog.success("DONE: Loaded all mod configs", LOG_NAME)




	for dir_name in ModLoaderStore.mod_data:
		var mod: ModData = ModLoaderStore.mod_data[dir_name]
		if not mod.is_loadable:
			continue
		_ModLoaderDependency.check_load_before(mod)




	for dir_name in ModLoaderStore.mod_data:
		var mod: ModData = ModLoaderStore.mod_data[dir_name]
		if not mod.is_loadable:
			continue
		var _is_circular: = _ModLoaderDependency.check_dependencies(mod, false)



	for dir_name in ModLoaderStore.mod_data:
		var mod: ModData = ModLoaderStore.mod_data[dir_name]
		if not mod.is_loadable:
			continue
		var _is_circular: = _ModLoaderDependency.check_dependencies(mod)


	ModLoaderStore.mod_load_order = _ModLoaderDependency.get_load_order(ModLoaderStore.mod_data.values())


	for mod_index in ModLoaderStore.mod_load_order.size():
		var mod: ModData = ModLoaderStore.mod_load_order[mod_index]
		ModLoaderLog.info("mod_load_order -> %s) %s" % [mod_index + 1, mod.dir_name], LOG_NAME)


	for mod in ModLoaderStore.mod_load_order:
		mod = mod as ModData


		if not mod.is_active or not mod.is_loadable:
			continue

		ModLoaderLog.info("Initializing -> %s" % mod.manifest.get_mod_id(), LOG_NAME)
		_init_mod(mod)

	ModLoaderLog.debug_json_print("mod data", ModLoaderStore.mod_data, LOG_NAME)

	ModLoaderLog.success("DONE: Completely finished loading mods", LOG_NAME)

	_ModLoaderScriptExtension.handle_script_extensions()

	ModLoaderLog.success("DONE: Installed all script extensions", LOG_NAME)

	_ModLoaderSceneExtension.refresh_scenes()

	_ModLoaderSceneExtension.handle_scene_extensions()

	ModLoaderLog.success("DONE: Applied all scene extensions", LOG_NAME)

	ModLoaderStore.is_initializing = false

	new_hooks_created.connect(_ModLoaderHooks.on_new_hooks_created)


func _ready():


	if _ModLoaderHooks.any_mod_hooked:
		if OS.has_feature("editor"):
			ModLoaderLog.hint("No mod hooks .zip will be created when running from the editor.", LOG_NAME)
			ModLoaderLog.hint("You can test mod hooks by running the preprocessor on the vanilla scripts once.", LOG_NAME)
			ModLoaderLog.hint("We recommend using the Mod Loader Dev Tool to process scripts in the editor. You can find it here: %s" % ModLoaderStore.MOD_LOADER_DEV_TOOL_URL, LOG_NAME)
		else:

			_ModLoaderModHookPacker.start()


func _load_mod_hooks_pack() -> void :

	var load_hooks_pack_success: = ProjectSettings.load_resource_pack(_ModLoaderPath.get_path_to_hook_pack())
	if not load_hooks_pack_success:
		ModLoaderLog.error("Failed loading hooks pack from: %s" % _ModLoaderPath.get_path_to_hook_pack(), LOG_NAME)
	else:
		ModLoaderLog.debug("Successfully loaded hooks pack from: %s" % _ModLoaderPath.get_path_to_hook_pack(), LOG_NAME)



func _init_mod(mod: ModData) -> void :
	var mod_main_path: = mod.get_required_mod_file_path(ModData.RequiredModFiles.MOD_MAIN)
	var mod_overwrites_path: = mod.get_optional_mod_file_path(ModData.OptionalModFiles.OVERWRITES)


	if mod.is_overwrite:
		ModLoaderLog.debug("Overwrite script detected -> %s" % mod_overwrites_path, LOG_NAME)
		var mod_overwrites_script: = load(mod_overwrites_path)
		mod_overwrites_script.new()
		ModLoaderLog.debug("Initialized overwrite script -> %s" % mod_overwrites_path, LOG_NAME)

	ModLoaderLog.debug("Loading script from -> %s" % mod_main_path, LOG_NAME)
	var mod_main_script: GDScript = ResourceLoader.load(mod_main_path)
	ModLoaderLog.debug("Loaded script -> %s" % mod_main_script, LOG_NAME)

	var mod_main_instance: Node = mod_main_script.new()
	mod_main_instance.name = mod.manifest.get_mod_id()

	ModLoaderStore.saved_mod_mains[mod_main_path] = mod_main_instance

	ModLoaderLog.debug("Adding mod main instance to ModLoader -> %s" % mod_main_instance, LOG_NAME)
	add_child(mod_main_instance, true)
