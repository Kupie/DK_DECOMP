extends ColorRect

signal close

const DEVICETYPE_LABEL_MOUSE: StringName = "options.input.controls.mouse"
const DEVICETYPE_LABEL_GAMEPAD: StringName = "options.input.gamepad"

var readied: = false
var categories: = ["Keeper1", "Keeper2", "Keeper3", "Keeper4"]
var currentCategory: String

func setFromOptions(is_mouse_input: bool):
	if is_mouse_input:
		%DeviceTypeLabel.text = DEVICETYPE_LABEL_MOUSE
	else:
		%DeviceTypeLabel.text = DEVICETYPE_LABEL_GAMEPAD

	for category_id: StringName in categories:
		var controller_name = "Mouse" if is_mouse_input else "Gamepad"
		var settings = Options.keeperInputSettings["%s.%s" % [category_id.to_lower(), controller_name]]
		var category_panel = find_child(category_id + "Category")
		category_panel.settings = settings
		category_panel.is_mouse = is_mouse_input
	readied = true

func tabLeft():
	var i = categories.find(currentCategory)
	if i > 0:
		Audio.sound("gui_tab")
		showCategory(categories[i - 1])

func tabRight():
	var i = categories.find(currentCategory)
	if i < categories.size() - 1:
		Audio.sound("gui_tab")
		showCategory(categories[i + 1])

func showCategory(cat: String):
	currentCategory = cat
	find_child(cat + "Category").visible = true
	var categoryButton = find_child(cat + "Button")
	categoryButton.button_pressed = true
	for category_id in categories:
		if category_id != cat:
			find_child(category_id + "Category").visible = false
	InputSystem.grabFocus(categoryButton)


func _ready() -> void :
	InputSystem.grabFocus(find_child("ButtonApply"))
	Style.init(self)
	if not currentCategory:
		showCategory(categories[0])

func _on_CategoryButton_pressed(cat):
	if readied:
		Audio.sound("gui_tab")
	showCategory(cat)

func _on_SnappingSlider_value_changed(value: float, label_name: StringName, suffix: StringName = "°"):
	find_child(label_name).text = str(value) + suffix

func _on_button_apply_pressed() -> void :
	for category_id: StringName in categories:
		var category_panel = find_child(category_id + "Category")
		category_panel.apply_settings()
		Options.setInputSettings(category_id.to_lower(), category_panel.is_mouse, category_panel.settings)

	Audio.sound("gui_apply")
	emit_signal("close")

func _on_cancel_button_pressed() -> void :
	Audio.sound("gui_cancel")

func _on_reset_button_pressed() -> void :
	var category_panel = find_child(currentCategory + "Category")
	category_panel.reset()
