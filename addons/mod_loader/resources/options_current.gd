class_name ModLoaderCurrentOptions
extends Resource


@export var current_options: Resource = preload(
	"res://addons/mod_loader/options/profiles/default.tres"
)





@export var feature_override_options: Dictionary = {
	"editor": preload("res://addons/mod_loader/options/profiles/editor.tres")
}
