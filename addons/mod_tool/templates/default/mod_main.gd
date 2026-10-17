extends Node












const MOD_DIR: = "AuthorName-ModName"
const LOG_NAME: = "AuthorName-ModName:Main"

var mod_dir_path: = ""
var extensions_dir_path: = ""
var translations_dir_path: = ""



func _init() -> void :
	ModLoaderLog.info("Init", LOG_NAME)
	mod_dir_path = ModLoaderMod.get_unpacked_dir().path_join(MOD_DIR)


	install_script_extensions()
	install_script_hook_files()


	add_translations()


func install_script_extensions() -> void :

	extensions_dir_path = mod_dir_path.path_join("extensions")


	ModLoaderMod.install_script_extension(extensions_dir_path.path_join("main.gd"))







func install_script_hook_files() -> void :
	extensions_dir_path = mod_dir_path.path_join("extensions")
	ModLoaderMod.install_script_hooks("res://main.gd", extensions_dir_path.path_join("main.gd"))


func add_translations() -> void :

	translations_dir_path = mod_dir_path.path_join("translations")






	ModLoaderMod.add_translation(translations_dir_path.path_join("modname.en.position"))


func _ready() -> void :
	ModLoaderLog.info("Ready", LOG_NAME)



	ModLoaderLog.info("Translation Demo: " + tr("MODNAME_READY_TEXT"), LOG_NAME)
