extends HBoxContainer

@export var icon_size: = 100

var undefined_logo = "res://gui/platform/Platform_icon_non_defined.png"
var ps_logo = "res://gui/platform/Platform_icon_PlayStation.png"
var steam_logo = "res://gui/platform/Platform_icon_Steam.png"
var switch_logo = "res://gui/platform/Platform_icon_Switch.png"
var xbox_logo = "res://gui/platform/Platform_icon_Xbox.png"

func _ready() -> void :
	Style.init($IconButton)

func get_icon(platform_id: String):
	var icon = ""
	if BuildCustomization.has_feature("enable_gamertag_platform_logo"):
		icon = undefined_logo
		if platform_id == Platform.get_platform_id():
			match platform_id:
				CONST.PLATFORM_ID_XBOX:
					icon = xbox_logo
				CONST.PLATFORM_ID_PSN:
					icon = ps_logo
				CONST.PLATFORM_ID_SWITCH:
					icon = switch_logo
				CONST.PLATFORM_ID_STEAM:
					icon = steam_logo
	return icon

func set_gamer_tag(gamer_tag: String, platform_id: String = "") -> void :
	var icon = get_icon(platform_id)
	%IconRichTextLabel.visible = true
	%IconLoadoutChoice.visible = false
	%IconButton.visible = false

	if not icon.is_empty():
		var img_start = str("[img=", icon_size, "]")
		%IconRichTextLabel.text = str(img_start, icon)
	else:
		%IconRichTextLabel.text = ""
	%NameLabel.text = gamer_tag

func set_gamer_tag_for_loadout(gamer_tag: String, platform_id: String, cb: Callable) -> void :
	if not BuildCustomization.has_feature("enable_see_profile_buttons"):
		set_gamer_tag(gamer_tag, platform_id)
		return
	var icon = get_icon(platform_id)
	%IconRichTextLabel.visible = false
	%IconLoadoutChoice.visible = icon != ""
	%IconButton.visible = false

	%IconLoadoutChoice.icon = load(icon)
	%IconLoadoutChoice.connect("select", cb)
	%NameLabel.text = gamer_tag

	var margincontainer: MarginContainer = %IconLoadoutChoice.find_child("MarginContainer")
	var margsize = -3
	margincontainer.add_theme_constant_override("margin_top", margsize)
	margincontainer.add_theme_constant_override("margin_down", margsize)
	margincontainer.add_theme_constant_override("margin_left", margsize)
	margincontainer.add_theme_constant_override("margin_right", margsize)
	var textrect: TextureRect = %IconLoadoutChoice.find_child("Icon")
	textrect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	%IconLoadoutChoice.loadoutScale = 0.5


func set_gamer_tag_for_menu(gamer_tag: String, platform_id: String, cb: Callable) -> void :
	if not BuildCustomization.has_feature("enable_see_profile_buttons") or platform_id != Platform.get_platform_id():
		set_gamer_tag(gamer_tag, platform_id)
		return
	var icon = get_icon(platform_id)
	%IconRichTextLabel.visible = false
	%IconLoadoutChoice.visible = false
	%IconButton.visible = icon != ""

	%IconTextureRect.texture = load(icon)
	%IconButton.connect("pressed", cb)
	%NameLabel.text = gamer_tag
