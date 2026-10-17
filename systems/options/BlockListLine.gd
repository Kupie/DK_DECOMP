extends Control

var playfab_id: String
var user_name: String
var platform_user_id: String
var platform_id: String

func _ready() -> void :
	%GamerTagLabel.icon_size = 40
	%GamerTagLabel.set_gamer_tag_for_menu(user_name, platform_id, _on_profile_button_pressed)
	%UnblockButton.disabled = not BlockList.is_user_blocked(playfab_id)

func _on_unblock_button_pressed() -> void :
	Audio.sound("gui_select")
	if BlockList.remove_blocked_user(playfab_id):
		%UnblockButton.disabled = true

func _on_profile_button_pressed() -> void :
	Platform.show_player_profile_card(platform_user_id)
