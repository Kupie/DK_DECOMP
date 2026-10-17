class_name ModManifest
extends Resource




const LOG_NAME: = "ModLoader:ModManifest"



var name: = ""


var mod_namespace: = ""


var version_number: = "0.0.0"
var description: = ""
var website_url: = ""

var dependencies: PackedStringArray = []

var optional_dependencies: PackedStringArray = []

var authors: PackedStringArray = []

var compatible_game_version: PackedStringArray = []

var compatible_mod_loader_version: PackedStringArray = []

var incompatibilities: PackedStringArray = []

var load_before: PackedStringArray = []

var tags: PackedStringArray = []



var scope: String = "":
	get:
		if scope.is_empty():
			return "shared"
		return scope

var config_schema: = {}
var description_rich: = ""
var image: CompressedTexture2D

var steam_workshop_id: = ""

var validation_messages_error: Array[String] = []
var validation_messages_warning: Array[String] = []

var is_valid: = false
var has_parsing_failed: = false


const REQUIRED_MANIFEST_KEYS_ROOT: Array[String] = [
	"name", 
	"namespace", 
	"version_number", 
	"website_url", 
	"description", 
	"dependencies", 
	"extra", 
]


const REQUIRED_MANIFEST_KEYS_EXTRA: Array[String] = [
	"authors", 
	"compatible_mod_loader_version", 
	"compatible_game_version", 
]




func _init(manifest: Dictionary, path: String) -> void :
	if manifest.is_empty():
		validation_messages_error.push_back("The manifest cannot be validated due to missing data, most likely because parsing the manifest.json file failed.")
		has_parsing_failed = true
	else:
		is_valid = validate(manifest, path)


func validate(manifest: Dictionary, path: String) -> bool:
	var missing_fields: Array[String] = []

	missing_fields.append_array(ModLoaderUtils.get_missing_dict_fields(manifest, REQUIRED_MANIFEST_KEYS_ROOT))
	missing_fields.append_array(ModLoaderUtils.get_missing_dict_fields(manifest.extra, ["godot"]))
	missing_fields.append_array(ModLoaderUtils.get_missing_dict_fields(manifest.extra.godot, REQUIRED_MANIFEST_KEYS_EXTRA))

	if not missing_fields.is_empty():
		validation_messages_error.push_back("Manifest is missing required fields: %s" % str(missing_fields))

	name = manifest.name
	mod_namespace = manifest. namespace 
	version_number = manifest.version_number

	is_name_or_namespace_valid(name)
	is_name_or_namespace_valid(mod_namespace)

	var mod_id = get_mod_id()

	is_semver_valid(mod_id, version_number, "version_number")

	description = manifest.description
	website_url = manifest.website_url
	dependencies = manifest.dependencies

	var godot_details: Dictionary = manifest.extra.godot
	authors = ModLoaderUtils.get_array_from_dict(godot_details, "authors")
	optional_dependencies = ModLoaderUtils.get_array_from_dict(godot_details, "optional_dependencies")
	incompatibilities = ModLoaderUtils.get_array_from_dict(godot_details, "incompatibilities")
	load_before = ModLoaderUtils.get_array_from_dict(godot_details, "load_before")
	compatible_game_version = ModLoaderUtils.get_array_from_dict(godot_details, "compatible_game_version")
	compatible_mod_loader_version = _handle_compatible_mod_loader_version(mod_id, godot_details)
	description_rich = ModLoaderUtils.get_string_from_dict(godot_details, "description_rich")
	tags = ModLoaderUtils.get_array_from_dict(godot_details, "tags")
	scope = ModLoaderUtils.get_string_from_dict(godot_details, "scope")
	config_schema = ModLoaderUtils.get_dict_from_dict(godot_details, "config_schema")
	steam_workshop_id = ModLoaderUtils.get_string_from_dict(godot_details, "steam_workshop_id")

	if ModLoaderStore.ml_options.game_version_validation == ModLoaderOptionsProfile.VERSION_VALIDATION.DEFAULT:
		_is_game_version_compatible(mod_id)

	if ModLoaderStore.ml_options.game_version_validation == ModLoaderOptionsProfile.VERSION_VALIDATION.CUSTOM:
		if ModLoaderStore.ml_options.custom_game_version_validation_callable:
			ModLoaderStore.ml_options.custom_game_version_validation_callable.call(self)
		else:
			ModLoaderLog.error("No custom game version validation callable detected. Please provide a valid validation callable.", LOG_NAME)

	is_mod_id_array_valid(mod_id, dependencies, "dependency")
	is_mod_id_array_valid(mod_id, incompatibilities, "incompatibility")
	is_mod_id_array_valid(mod_id, optional_dependencies, "optional_dependency")
	is_mod_id_array_valid(mod_id, load_before, "load_before")

	validate_distinct_mod_ids_in_arrays(mod_id, dependencies, incompatibilities, ["dependencies", "incompatibilities"])
	validate_distinct_mod_ids_in_arrays(mod_id, optional_dependencies, dependencies, ["optional_dependencies", "dependencies"])
	validate_distinct_mod_ids_in_arrays(mod_id, optional_dependencies, incompatibilities, ["optional_dependencies", "incompatibilities"])
	validate_distinct_mod_ids_in_arrays(
		mod_id, 
		load_before, 
		dependencies, 
		["load_before", "dependencies"], 
		"\"load_before\" should be handled as optional dependency adding it to \"dependencies\" will cancel out the desired effect."
	)
	validate_distinct_mod_ids_in_arrays(
		mod_id, 
		load_before, 
		optional_dependencies, 
		["load_before", "optional_dependencies"], 
		"\"load_before\" can be viewed as optional dependency, please remove the duplicate mod-id."
	)
	validate_distinct_mod_ids_in_arrays(mod_id, load_before, incompatibilities, ["load_before", "incompatibilities"])

	_validate_workshop_id(path)

	return validation_messages_error.is_empty()




func get_mod_id() -> String:
	return "%s-%s" % [mod_namespace, name]




func get_package_id() -> String:
	return "%s-%s-%s" % [mod_namespace, name, version_number]



func get_as_dict() -> Dictionary:
	return {
		"name": name, 
		"namespace": mod_namespace, 
		"version_number": version_number, 
		"description": description, 
		"website_url": website_url, 
		"dependencies": dependencies, 
		"optional_dependencies": optional_dependencies, 
		"authors": authors, 
		"compatible_game_version": compatible_game_version, 
		"compatible_mod_loader_version": compatible_mod_loader_version, 
		"incompatibilities": incompatibilities, 
		"load_before": load_before, 
		"tags": tags, 
		"scope": scope, 
		"config_schema": config_schema, 
		"description_rich": description_rich, 
		"image": image, 
	}



func to_json() -> String:
	return JSON.stringify({
		"name": name, 
		"namespace": mod_namespace, 
		"version_number": version_number, 
		"description": description, 
		"website_url": website_url, 
		"dependencies": dependencies, 
		"extra": {
			"godot": {
				"authors": authors, 
				"optional_dependencies": optional_dependencies, 
				"compatible_game_version": compatible_game_version, 
				"compatible_mod_loader_version": compatible_mod_loader_version, 
				"incompatibilities": incompatibilities, 
				"load_before": load_before, 
				"tags": tags, 
				"scope": scope, 
				"config_schema": config_schema, 
				"description_rich": description_rich, 
				"image": image, 
			}
		}
	}, "\t")



func load_mod_config_defaults() -> ModConfig:
	var default_config_save_path: = _ModLoaderPath.get_path_to_mod_config_file(get_mod_id(), ModLoaderConfig.DEFAULT_CONFIG_NAME)
	var config: = ModConfig.new(
		get_mod_id(), 
		{}, 
		default_config_save_path, 
		config_schema
	)


	if not _ModLoaderFile.file_exists(config.save_path):

		config.data = _generate_default_config_from_schema(config.schema.properties)


	else:
		var current_schema_md5: = config.get_schema_as_string().md5_text()
		var cache_schema_md5s: = _ModLoaderCache.get_data("config_schemas")
		var cache_schema_md5: String = cache_schema_md5s[config.mod_id] if cache_schema_md5s.has(config.mod_id) else ""


		if not current_schema_md5 == cache_schema_md5 or cache_schema_md5.is_empty():
			config.data = _generate_default_config_from_schema(config.schema.properties)


		else:
			config.data = _ModLoaderFile.get_json_as_dict(config.save_path)


	if config.is_valid():

		config.save_to_file()


		_ModLoaderCache.update_data("config_schemas", {config.mod_id: config.get_schema_as_string().md5_text()})


		return config

	ModLoaderLog.fatal("The default config values for %s-%s are invalid. Configs will not be loaded." % [mod_namespace, name], LOG_NAME)
	return null



func _generate_default_config_from_schema(property: Dictionary, current_prop: = {}) -> Dictionary:

	if property.is_empty():
		return current_prop

	for property_key in property.keys():
		var prop = property[property_key]


		if "properties" in prop:
			current_prop[property_key] = {}
			_generate_default_config_from_schema(prop.properties, current_prop[property_key])

			return current_prop


		if JSONSchema.JSKW_DEFAULT in prop:

			if not current_prop.has(property_key):
				current_prop[property_key] = {}


			current_prop[property_key] = prop.default

	return current_prop



func _handle_compatible_mod_loader_version(mod_id: String, godot_details: Dictionary) -> Array:
	var link_manifest_docs: = "https://github.com/GodotModding/godot-mod-loader/wiki/Mod-Files#manifestjson"
	var array_value: = ModLoaderUtils.get_array_from_dict(godot_details, "compatible_mod_loader_version")


	if array_value.size() > 0:

		if not is_semver_version_array_valid(mod_id, array_value, "compatible_mod_loader_version"):
			return []

		return array_value


	var string_value: = ModLoaderUtils.get_string_from_dict(godot_details, "compatible_mod_loader_version")

	if string_value == "":

		validation_messages_error.push_back(
			str(
				"%s - \"compatible_mod_loader_version\" is a required field." + 
				" For more details visit %s"
			) % [mod_id, link_manifest_docs])
		return []

	return [string_value]





func is_name_or_namespace_valid(check_name: String, is_silent: = false) -> bool:
	var re: = RegEx.new()
	var _compile_error_1 = re.compile("^[a-zA-Z0-9_]*$")

	if re.search(check_name) == null:
		if not is_silent:
			validation_messages_error.push_back("Invalid name or namespace: \"%s\". You may only use letters, numbers and underscores." % check_name)
		return false

	var _compile_error_2 = re.compile("^[a-zA-Z0-9_]{3,}$")
	if re.search(check_name) == null:
		if not is_silent:
			validation_messages_error.push_back("Invalid name or namespace: \"%s\". Must be longer than 3 characters." % check_name)
		return false

	return true


func is_semver_version_array_valid(mod_id: String, version_array: PackedStringArray, version_array_descripton: String, is_silent: = false) -> bool:
	var is_valid: = true

	for version in version_array:
		if not is_semver_valid(mod_id, version, version_array_descripton, is_silent):
			is_valid = false

	return is_valid





func is_semver_valid(mod_id: String, check_version_number: String, field_name: String, is_silent: = false) -> bool:
	var re: = RegEx.new()
	var _compile_error = re.compile("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")

	if re.search(check_version_number) == null:
		if not is_silent:

			validation_messages_error.push_back(
				str(
					"Invalid semantic version: \"%s\" in field \"%s\" of mod \"%s\". " + 
					"You may only use numbers without leading zero and periods " + 
					"following this format {mayor}.{minor}.{patch}"
				) % [check_version_number, field_name, mod_id]
			)
		return false

	if check_version_number.length() > 16:
		if not is_silent:
			validation_messages_error.push_back(
				str(
					"Invalid semantic version: \"%s\" in field \"%s\" of mod \"%s\". " + 
					"Version number must be shorter than 16 characters."
				) % [check_version_number, field_name, mod_id]
			)
		return false

	return true


func validate_distinct_mod_ids_in_arrays(
	mod_id: String, 
	array_one: PackedStringArray, 
	array_two: PackedStringArray, 
	array_description: PackedStringArray, 
	additional_info: = "", 
	is_silent: = false
) -> bool:

	var overlaps: PackedStringArray = []


	for loop_mod_id in array_one:
		if array_two.has(loop_mod_id):
			overlaps.push_back(loop_mod_id)


	if overlaps.size() == 0:
		return true


	if not is_silent:
		validation_messages_error.push_back(
			(
				"The mod -> %s lists the same mod(s) -> %s - in \"%s\" and \"%s\". %s"
				%[mod_id, overlaps, array_description[0], array_description[1], additional_info]
			)
		)
		return false


	return false


func is_mod_id_array_valid(own_mod_id: String, mod_id_array: PackedStringArray, mod_id_array_description: String, is_silent: = false) -> bool:
	var is_valid: = true


	if mod_id_array.size() > 0:
		for mod_id in mod_id_array:

			if mod_id == own_mod_id:
				is_valid = false
				if not is_silent:
					validation_messages_error.push_back("The mod \"%s\" lists itself as \"%s\" in its own manifest.json file" % [mod_id, mod_id_array_description])


			if not is_mod_id_valid(own_mod_id, mod_id, mod_id_array_description, is_silent):
				is_valid = false

	return is_valid


func is_mod_id_valid(original_mod_id: String, check_mod_id: String, type: = "", is_silent: = false) -> bool:
	var intro_text = "A %s for the mod \"%s\" is invalid: " % [type, original_mod_id] if not type == "" else ""


	if not check_mod_id.count("-") == 1:
		if not is_silent:
			validation_messages_error.push_back(str(intro_text, "Expected a single hyphen in the mod ID, but the %s was: \"%s\"" % [type, check_mod_id]))
		return false


	var mod_id_length = check_mod_id.length()
	if mod_id_length < 7:
		if not is_silent:
			validation_messages_error.push_back(str(intro_text, "Mod ID for \"%s\" is too short. It must be at least 7 characters long, but its length is: %s" % [check_mod_id, mod_id_length]))
		return false

	var split = check_mod_id.split("-")
	var check_namespace = split[0]
	var check_name = split[1]
	var re: = RegEx.new()
	re.compile("^[a-zA-Z0-9_]{3,}$")

	if re.search(check_namespace) == null:
		if not is_silent:
			validation_messages_error.push_back(str(intro_text, "Mod ID has an invalid namespace (author) for \"%s\". Namespace can only use letters, numbers and underscores, but was: \"%s\"" % [check_mod_id, check_namespace]))
		return false

	if re.search(check_name) == null:
		if not is_silent:
			validation_messages_error.push_back(str(intro_text, "Mod ID has an invalid name for \"%s\". Name can only use letters, numbers and underscores, but was: \"%s\"" % [check_mod_id, check_name]))
		return false

	return true


func is_string_length_valid(mod_id: String, field: String, string: String, required_length: int, is_silent: = false) -> bool:
	if not string.length() == required_length:
		if not is_silent:
			validation_messages_error.push_back("Invalid length in field \"%s\" of mod \"%s\" it should be \"%s\" but it is \"%s\"." % [field, mod_id, required_length, string.length()])
		return false

	return true


func _validate_workshop_id(path: String) -> void :
	var steam_workshop_id_from_path: = _ModLoaderPath.get_steam_workshop_id(path)
	var is_mod_source_workshop: = not steam_workshop_id_from_path.is_empty()

	if not _is_steam_workshop_id_valid(get_mod_id(), steam_workshop_id_from_path, steam_workshop_id, is_mod_source_workshop):

		if is_mod_source_workshop:
			steam_workshop_id = steam_workshop_id_from_path


func _is_steam_workshop_id_valid(mod_id: String, steam_workshop_id_from_path: String, steam_workshop_id_to_validate: String, is_mod_source_workshop: = false, is_silent: = false) -> bool:
	if steam_workshop_id_to_validate.is_empty():

		return true


	if is_mod_source_workshop:
		if not steam_workshop_id_to_validate == steam_workshop_id_from_path:
			if not is_silent:
				ModLoaderLog.warning("The \"steam_workshop_id\": \"%s\" provided by the mod manifest of mod \"%s\" is incorrect, it should be \"%s\"." % [steam_workshop_id_to_validate, mod_id, steam_workshop_id_from_path], LOG_NAME)
			return false
	else:
		if not is_string_length_valid(mod_id, "steam_workshop_id", steam_workshop_id_to_validate, 10, is_silent):

			return false

	return true


func _is_game_version_compatible(mod_id: String) -> bool:
	var game_version: String = ModLoaderStore.ml_options.semantic_version
	var game_major: = int(game_version.get_slice(".", 0))
	var game_minor: = int(game_version.get_slice(".", 1))

	var valid_major: = false
	var valid_minor: = false
	for version in compatible_game_version:
		var compat_major: = int(version.get_slice(".", 0))
		var compat_minor: = int(version.get_slice(".", 1))
		if compat_major < game_major:
			continue
		valid_major = true

		if compat_minor < game_minor:
			continue
		valid_minor = true

	if not valid_major:
		validation_messages_error.push_back(
			"""The mod \"%s\" is incompatible with the current game version.
			(current game version: %s, mod compatible with game versions: %s)"""%
			[mod_id, game_version, compatible_game_version]
		)
		return false
	if not valid_minor:
		validation_messages_warning.push_back(
			"""The mod \"%s\" may not be compatible with the current game version.
			Enable at your own risk. (current game version: %s, mod compatible with game versions: %s)"""%
			[mod_id, game_version, compatible_game_version]
		)
		return true

	return true
