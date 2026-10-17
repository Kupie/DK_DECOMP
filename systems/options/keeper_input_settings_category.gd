extends VBoxContainer

const NO_OPTIONS_TEXT: StringName = "options.input.controls.nooptions"

@export var use_mouse_checkbox: CheckBox
@export var use_twinstick_checkbox: CheckBox
@export var show_aim_indicator_checkbox: CheckBox
@export var auto_pickup_ressources: CheckBox
@export var auto_kunai_carrier_pickup: CheckBox
@export var drop_ressources_before_gadets: CheckBox
@export var movement_snap_box: Control
@export var movement_snap_slider: HSlider
@export var aim1_snap_slider: HSlider
@export var aim2_snap_slider: HSlider
@export var rope_snap_slider: HSlider
@export var rope_camera_follow_slider: HSlider
@export var no_keeper_settings_label: Label

@onready var controls_for_visibility_check = [use_mouse_checkbox, use_twinstick_checkbox, show_aim_indicator_checkbox, drop_ressources_before_gadets, movement_snap_box, aim1_snap_slider, aim2_snap_slider]

var settings: KeeperInputSettings
var is_mouse: bool

var focusable_children: = []

func _ready() -> void :
	populate(settings)
	focusable_children = find_children("*", "", true).filter( func(child): return child.focus_mode != Control.FOCUS_NONE)

func populate(settings: KeeperInputSettings):
	if use_mouse_checkbox:
		use_mouse_checkbox.visible = is_mouse
		use_mouse_checkbox.button_pressed = settings.use_mouse
	if use_twinstick_checkbox:
		use_twinstick_checkbox.visible = not is_mouse
		use_twinstick_checkbox.button_pressed = settings.use_twinstick
	if show_aim_indicator_checkbox:
		show_aim_indicator_checkbox.button_pressed = settings.show_aim_indicator
	if auto_pickup_ressources:
		auto_pickup_ressources.button_pressed = settings.auto_pickup
	if auto_kunai_carrier_pickup:
		auto_kunai_carrier_pickup.button_pressed = settings.auto_kunai_carrier_pickup
	if drop_ressources_before_gadets:
		drop_ressources_before_gadets.button_pressed = settings.drop_ressources_before_gadets
	if movement_snap_slider:
		movement_snap_box.visible = not is_mouse
		movement_snap_slider.value = settings.movement_snap
		movement_snap_slider.value_changed.emit(movement_snap_slider.value)
	if aim1_snap_slider:
		aim1_snap_slider.value = settings.aim1_snap
		aim1_snap_slider.value_changed.emit(aim1_snap_slider.value)
	if aim2_snap_slider:
		aim2_snap_slider.value = settings.aim2_snap
		aim2_snap_slider.value_changed.emit(aim2_snap_slider.value)
	if rope_snap_slider:
		rope_snap_slider.value = settings.rope_snap
		rope_snap_slider.value_changed.emit(rope_snap_slider.value)
	if rope_camera_follow_slider:
		rope_camera_follow_slider.value = settings.rope_camera_follow * 100
		rope_camera_follow_slider.value_changed.emit(rope_camera_follow_slider.value)


	var has_options: bool = false
	for control in controls_for_visibility_check:
		if control and control.visible:
			has_options = true
			break

	if no_keeper_settings_label:
		if is_mouse:
			no_keeper_settings_label.text = tr("options.input.controls.nooptions") % tr("options.input.controls.mouse").to_lower()
		else:
			no_keeper_settings_label.text = tr("options.input.controls.nooptions") % tr("options.input.gamepad").to_lower()
		no_keeper_settings_label.visible = not has_options


func apply_settings():
	if use_mouse_checkbox:
		settings.use_mouse = use_mouse_checkbox.button_pressed
	if use_twinstick_checkbox:
		settings.use_twinstick = use_twinstick_checkbox.button_pressed
	if auto_pickup_ressources:
		settings.auto_pickup = auto_pickup_ressources.button_pressed
	if auto_kunai_carrier_pickup:
		settings.auto_kunai_carrier_pickup = auto_kunai_carrier_pickup.button_pressed
	if drop_ressources_before_gadets:
		settings.drop_ressources_before_gadets = drop_ressources_before_gadets.button_pressed
	if show_aim_indicator_checkbox:
		settings.show_aim_indicator = show_aim_indicator_checkbox.button_pressed
	if movement_snap_slider:
		settings.movement_snap = movement_snap_slider.value
	if aim1_snap_slider:
		settings.aim1_snap = aim1_snap_slider.value
	if aim2_snap_slider:
		settings.aim2_snap = aim2_snap_slider.value
	if rope_snap_slider:
		settings.rope_snap = rope_snap_slider.value
	if rope_camera_follow_slider:
		settings.rope_camera_follow = rope_camera_follow_slider.value / 100

func reset():
	var new_settings = KeeperInputSettings.new()
	new_settings.from_dict({}, is_mouse, settings.keeper_id)
	populate(new_settings)
