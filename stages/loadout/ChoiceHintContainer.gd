extends HBoxContainer


func _ready() -> void :
	var s = tr("loadout.hint.selection")
	var parts = s.split("|")
	if parts.size() != 2:
		Logger.error("string is not formatted as expected", "loadout.hint.selection", s)
		return
	$Label1.text = parts[0]
	$Label3.text = parts[1]
