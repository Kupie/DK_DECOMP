class_name ModData
extends Resource





const LOG_NAME: = "ModLoader:ModData"

const MOD_MAIN: = "mod_main.gd"
const MANIFEST: = "manifest.json"
const OVERWRITES: = "overwrites.gd"




enum RequiredModFiles{
	MOD_MAIN, 
	MANIFEST, 
}

enum OptionalModFiles{
	OVERWRITES
}





enum Sources{
	UNPACKED, 
	LOCAL, 
	STEAM_WORKSHOP, 
}


var zip_name: = ""

var zip_path: = ""


var dir_name: = ""

var dir_path: = ""

var is_loadable: = true

var is_overwrite: = false

var is_locked: = false

var is_active: = true

var importance: = 0

var manifest: ModManifest


var configs: = {}

var current_config: ModConfig: set = _set_current_config

var source: int

var load_errors: Array[String] = []
var load_warnings: Array[String] = []



func _init(_manifest: ModManifest, path: String) -> void :
	manifest = _manifest

	if _ModLoaderPath.is_zip(path):
		zip_name = _ModLoaderPath.get_file_name_from_path(path)
		zip_path = path


		dir_name = _ModLoaderFile.get_mod_dir_name_in_zip(zip_path)
	else:
		dir_name = path.split("/")[-1]

	dir_path = _ModLoaderPath.get_unpacked_mods_dir_path().path_join(dir_name)
	source = get_mod_source()

	_has_required_files()


	if not manifest.has_parsing_failed:
		_is_mod_dir_name_same_as_id(manifest)

	is_overwrite = _is_overwrite()
	is_locked = manifest.get_mod_id() in ModLoaderStore.ml_options.locked_mods

	if not load_errors.is_empty() or not manifest.validation_messages_error.is_empty():
		is_loadable = false



func load_configs() -> void :

	if not manifest.load_mod_config_defaults():
		return

	var config_dir_path: = _ModLoaderPath.get_path_to_mod_configs_dir(dir_name)
	var config_file_paths: = _ModLoaderPath.get_file_paths_in_dir(config_dir_path)
	for config_file_path in config_file_paths:
		_load_config(config_file_path)


	if ModLoaderUserProfile.is_initialized() and ModLoaderConfig.has_current_config(dir_name):
		current_config = ModLoaderConfig.get_current_config(dir_name)
	else:
		current_config = ModLoaderConfig.get_config(dir_name, ModLoaderConfig.DEFAULT_CONFIG_NAME)



func _load_config(config_file_path: String) -> void :
	var config_data: = _ModLoaderFile.get_json_as_dict(config_file_path)
	var mod_config = ModConfig.new(
		dir_name, 
		config_data, 
		config_file_path, 
		manifest.config_schema
	)


	configs[mod_config.name] = mod_config



func _set_current_config(new_current_config: ModConfig) -> void :
	ModLoaderUserProfile.set_mod_current_config(dir_name, new_current_config)
	current_config = new_current_config

	if ModLoader:
		ModLoader.current_config_changed.emit(new_current_config)


func set_mod_state(should_activate: bool, force: = false) -> bool:
	if is_locked and should_activate != is_active:
		ModLoaderLog.error(
			"Unable to toggle mod \"%s\" since it is marked as locked. Locked mods: %s"
			%[manifest.get_mod_id(), ModLoaderStore.ml_options.locked_mods], LOG_NAME)
		return false

	if should_activate and not is_loadable:
		ModLoaderLog.error(
			"Unable to activate mod \"%s\" since it has the following load errors: %s"
			%[manifest.get_mod_id(), ", ".join(load_errors)], LOG_NAME)
		return false

	if should_activate and manifest.validation_messages_warning.size() > 0:
		if not force:
			ModLoaderLog.warning(
				"Rejecting to activate mod \"%s\" since it has the following load warnings: %s"
				%[manifest.get_mod_id(), ", ".join(load_warnings)], LOG_NAME)
			return false
		ModLoaderLog.info(
			"Forced to activate mod \"%s\" despite the following load warnings: %s"
			%[manifest.get_mod_id(), ", ".join(load_warnings)], LOG_NAME)

	is_active = should_activate
	return true



func _is_mod_dir_name_same_as_id(mod_manifest: ModManifest) -> bool:
	var manifest_id: = mod_manifest.get_mod_id()
	if not dir_name == manifest_id:
		load_errors.push_back("Mod directory name \"%s\" does not match the data in manifest.json. Expected \"%s\" (Format: {namespace}-{name})" % [dir_name, manifest_id])
		return false
	return true


func _is_overwrite() -> bool:
	return _ModLoaderFile.file_exists(get_optional_mod_file_path(OptionalModFiles.OVERWRITES), zip_path)



func _has_required_files() -> bool:
	var has_required_files: = true

	for required_file in RequiredModFiles:
		var required_file_path: = get_required_mod_file_path(RequiredModFiles[required_file])

		if not _ModLoaderFile.file_exists(required_file_path, zip_path):
			load_errors.push_back(
				"ERROR - %s is missing a required file: %s. For more information, please visit \"%s\"." %
				[dir_name, required_file_path, ModLoaderStore.URL_MOD_STRUCTURE_DOCS]
			)
			has_required_files = false

	return has_required_files




func get_required_mod_file_path(required_file: RequiredModFiles) -> String:
	match required_file:
		RequiredModFiles.MOD_MAIN:
			return dir_path.path_join(MOD_MAIN)
		RequiredModFiles.MANIFEST:
			return dir_path.path_join(MANIFEST)
	return ""


func get_optional_mod_file_path(optional_file: OptionalModFiles) -> String:
	match optional_file:
		OptionalModFiles.OVERWRITES:
			return dir_path.path_join(OVERWRITES)
	return ""


func get_mod_source() -> Sources:
	if zip_path.contains("workshop"):
		return Sources.STEAM_WORKSHOP
	if zip_path == "":
		return Sources.UNPACKED

	return Sources.LOCAL
