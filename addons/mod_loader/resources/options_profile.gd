class_name ModLoaderOptionsProfile
extends Resource







enum VERSION_VALIDATION{

	DEFAULT, 



	DISABLED, 











	CUSTOM, 
}


@export var enable_mods: bool = true

@export var locked_mods: Array[String] = []

@export var disabled_mods: Array[String] = []

@export var allow_modloader_autoloads_anywhere: bool = false






@export_file var customize_script_path: String

@export_group("Logging")


@export var log_level: = ModLoaderLog.VERBOSITY_LEVEL.DEBUG

@export var ignore_deprecated_errors: bool = false




@export var ignored_mod_names_in_log: Array[String] = []

@export var warning_color: = Color("#ffde66")

@export var success_color: = Color("#5d8c3f")

@export var info_color: = Color("#70bafa")

@export var hint_color: = Color("#b293fa")

@export var debug_color: = Color("#d4d4d4")

@export var debug_bold: = true

@export_group("Game Data")

@export var steam_id: int = 0:
	get:
		if Platform.facade is PlatformFacadeSteam:
			return Platform.facade.STEAM_APP_ID
		return 0



@export var semantic_version: = "0.0.0":
	get:
		return Version.VERSION

@export_group("Mod Sources")

@export var load_from_steam_workshop: bool = false

@export var load_from_local: bool = true





@export var load_from_unpacked: bool = true


@export_dir var override_path_to_mods = ""

@export_dir var override_path_to_configs = ""





@export_dir var override_path_to_workshop = ""

@export_group("Mod Hooks")


@export_global_dir var override_path_to_hook_pack: = ""

@export var override_hook_pack_name: = ""


@export_dir var restart_notification_scene_path: = "res://addons/mod_loader/restart_notification.tscn"

@export var disable_restart: = false

@export_group("Mod Validation")



@export var game_version_validation: = VERSION_VALIDATION.DEFAULT




var custom_game_version_validation_callable: Callable


var customize_script_instance: RefCounted
