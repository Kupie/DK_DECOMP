extends HBoxContainer

var platform_user_id: = ""

func _ready() -> void :
	Style.init(self)

func set_gamer_tag(line_name: String, platform_id: String = ""):
	%GamerTagLabel.set_gamer_tag(line_name, platform_id)

	if BuildCustomization.has_feature("enable_see_profile_buttons") and platform_id == Platform.get_platform_id():
		%ProfileButton.visible = true

func _on_profile_button_pressed() -> void :
	Platform.show_player_profile_card(platform_user_id)
