class_name DeviceInPopup
extends MarginContainer

var device_id: int
var peer_id: int

func _ready():
	Style.init( %Check)
	Style.init( %Button)

	$Label.visible = peer_id == multiplayer.get_unique_id()
	%Button.visible = peer_id != multiplayer.get_unique_id()

func set_data(display_name: String, peer_id: int, device_id: int):
	self.peer_id = peer_id
	self.device_id = device_id

	$Label.text = Utils.clip_text(display_name, 10, true)
	if device_id > 0:
		$Label.text += " " + str(device_id)

	%Button.text = $Label.text

func set_checked(b: bool):
	%Check.visible = b

func is_checked() -> bool:
	return %Check.visible
