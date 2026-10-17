class_name ModUserProfile
extends Resource




var name: = ""









var mod_list: = {}


func _init(_name: = "", _mod_list: = {}) -> void :
	name = _name
	mod_list = _mod_list


func get_active() -> Array:
	var active: = mod_list.keys().filter(
		func(mod_id: String) -> bool:
			return mod_list[mod_id].is_active
	)
	active.sort()
	return active


func get_active_string() -> String:
	return ",".join(get_active())


func get_shared_active_string() -> String:

	return ""


func _to_string() -> String:
	return "ModUserProfile(name: %s, active: %s)" % [name, get_active_string()]
