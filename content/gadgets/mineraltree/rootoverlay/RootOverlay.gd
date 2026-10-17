extends Sprite2D

func _notification(what: int) -> void :
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		flip_h = randf() > 0.5
		flip_v = randf() > 0.5


func serialize() -> Dictionary:
	return {
		"flip_h" = flip_h, 
		"flip_v" = flip_v
	}

func deserialize(data: Dictionary):
	flip_h = data["flip_h"]
	flip_v = data["flip_v"]

func to_bytes() -> PackedByteArray:
	var data = {
		"flip_h" = flip_h, 
		"flip_v" = flip_v
	}
	return var_to_bytes(data)

func from_bytes(data: PackedByteArray) -> void :
	var dataDictionary: Dictionary = bytes_to_var(data)
	flip_h = dataDictionary["flip_h"]
	flip_v = dataDictionary["flip_v"]
