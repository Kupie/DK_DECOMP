extends TextureRect
class_name Action

enum Modifier{None, Tap, Hold}

const DISSALLOW_INPUT_SHARE: Dictionary = {
	"keeper3": {


			"ui_select": ["keeper3_jump"]
		}
}

@export var action = "": get = get_action, set = set_action
@export var mode = "adaptive"
@export var forceMode: = false
@export var forceCategory = "none"


@export var domeId: String
@export var keeperId: String


@export var forceMouse: bool = false

var clone
var forceKeyboard: bool
var label_text = ""

var teamId: String

func _ready():
	updateGlyphs()

func display() -> void :
	show()
	if is_instance_valid(clone):
		clone.show()

func conceal() -> void :
	hide()
	if is_instance_valid(clone):
		clone.hide()

func set_action(value: String):
	if value != action:
		action = value
		if is_inside_tree():
			updateGlyphs()

func get_action():
	return action

func onKeyBindingChanged():
	updateGlyphs()

func onInputMethodChanged():
	updateGlyphs()

func updateGlyphs():
	var vp = get_viewport()
	if not forceMode:
		mode = ""
		if vp:
			if vp.has_meta("deviceType"):
				mode = vp.get_meta("deviceType")
		var deviceId: int
		if (StageManager.isInLevel() or StageManager.isInLoadout()) or StageManager.isInLanding() or StageManager.isInClientLanding() or StageManager.isInDeviceSelection():
			if Keepers.local.getCount() > 0:
				deviceId = StageManager.currentStage.pausedDeviceId if StageManager.currentStage.pauseMenuOpen and StageManager.currentStage.pausedDeviceId > -1 else\
				Keepers.local.first().deviceId
				keeperId = Keepers.getLocalKeeperByDeviceId(deviceId).techId
			else:
				deviceId = -1

		if mode == "":
			match deviceId:
				-1:
					mode = "adaptive"
				0:
					mode = "keyboard"
				_:
					mode = "gamepad"

	if is_instance_valid(clone):
		clone.queue_free()
		clone = null

	match action:
		"pickup":
			match keeperId:
				"keeper1": action = "keeper1_pickup"
				"keeper2": action = "keeper2_gravitycollect"
				"keeper3": action = "keeper3_pickup"
				"keeper4": action = "keeper4_pickup"
		"drop":
			match keeperId:
				"keeper1": action = "keeper1_drop"
				"keeper2": action = "keeper2_gravityball"
				"keeper3": action = "keeper3_throw"
				"keeper4": action = "keeper4_drop"
		"dome_fire":
			match domeId:
				"dome1": action = "dome1_fire"
				"dome2": action = "dome2_fire"
				"dome3": action = "dome3_fire"
				"dome4": action = "dome4_fire"
				_: action = "dome1_fire"
		"dome_special":
			match domeId:
				"dome1": action = "dome1_fire"
				"dome2":


					var canvasLayer: = get_canvas_layer_node()
					if canvasLayer is PlayerCanvas:
						if teamId == "":
							teamId = Keepers.getKeeper(canvasLayer.playerId).teamId
						if Data.of(teamId + ".sword.stabManualSpeedup"):
							action = "dome2_special"
						else:
							action = "dome2_fire"
					else:
						action = "dome2_fire"
				"dome3": action = "dome3_special"
				"dome4": action = "dome4_fire"
				_: action = "dome1_fire"

	if mode == "gamepad" or (mode == "adaptive" and Options.singleplayerUseGamepad):

		var button = get_first_gamepad_button(action)
		if button[0]:
			texture = button[0]
			label_text = ""
			$Label.text = label_text
		else:
			texture = preload("res://gui/icons/blank_button.png")
			label_text = button[1]
			$Label.text = label_text
	elif mode == "keyboard" or (mode == "adaptive" and not Options.singleplayerUseGamepad):

		var useMouse: = false
		var mouseForUi = Options.useMouseMenus and (action.begins_with("ui") or forceCategory == "ui")
		var mouseForDome = Options.useMouseDomeGameplay and (action.begins_with("dome") or forceCategory == "dome")

		var mouseForKeeper = false
		var mouse_keeper = Keepers.getLocalMouseUser()
		if mouse_keeper:
			mouseForKeeper = Options.getInputSettingsForKeeper(mouse_keeper, true).use_mouse and (action.begins_with("keeper") or forceCategory == "keeper")

		if ( not forceKeyboard and (mouseForUi or mouseForDome or mouseForKeeper)) or forceMouse:
			texture = get_mouse_button(action)
			label_text = ""
			$Label.text = label_text
			useMouse = true
			if texture and not clone and not forceMouse:
				clone = GameWorld.requestActionClone(self, get_parent())
		if not texture or not useMouse:

			var d2 = get_first_key(action)
			if d2[0]:
				texture = d2[0]
				label_text = ""
				$Label.text = label_text
			else:
				texture = preload("res://gui/icons/blank_key.png")
				label_text = d2[1]
				$Label.text = label_text

	custom_minimum_size = texture.get_size() * 4
	if is_instance_valid(clone):
		clone.visible = visible

func get_mouse_button(action: String):
	var action_list = _get_filetered_event_list_for_action(action)
	for a in action_list:
		if a is InputEventMouseButton:
			match a.button_index:
				MOUSE_BUTTON_LEFT:
					return preload("res://gui/icons/mouse_lmb.png")
				MOUSE_BUTTON_RIGHT:
					return preload("res://gui/icons/mouse_rmb.png")
				MOUSE_BUTTON_MIDDLE:
					return preload("res://gui/icons/mouse_mmb.png")
				MOUSE_BUTTON_XBUTTON1:
					return preload("res://gui/icons/mouse_x1.png")
				MOUSE_BUTTON_XBUTTON2:
					return preload("res://gui/icons/mouse_x2.png")
	return null


func get_first_key(action: String, exceptActions: PackedStringArray = PackedStringArray()) -> Array:
	var key = null
	var key_name = ""
	var action_list = _get_filetered_event_list_for_action(action)
	for a in action_list:
		if a is InputEventKey:
			var keycode
			if a.physical_keycode != 0:
				keycode = DisplayServer.keyboard_get_keycode_from_physical(a.physical_keycode)
				key_name = OS.get_keycode_string(keycode)

			else:
				keycode = a.keycode
				key_name = OS.get_keycode_string(a.keycode)
			match keycode:
				KEY_LEFT:
					key = preload("res://gui/icons/key_links.png")
				KEY_RIGHT:
					key = preload("res://gui/icons/key_rechts.png")
				KEY_UP:
					key = preload("res://gui/icons/key_oben.png")
				KEY_DOWN:
					key = preload("res://gui/icons/key_unten.png")
				KEY_SPACE:
					key = preload("res://gui/icons/key_leer.png")
				KEY_BACKSPACE:
					key = preload("res://gui/icons/key_back.png")
				KEY_ENTER:
					key = preload("res://gui/icons/key_enter.png")
				KEY_TAB:
					key = preload("res://gui/icons/key_tab.png")
				KEY_ESCAPE:
					key = preload("res://gui/icons/key_esc.png")
				KEY_SHIFT:
					key = preload("res://gui/icons/key_shift.png")
				KEY_CTRL:
					key = preload("res://gui/icons/key_control.png")
				KEY_CAPSLOCK:
					key = preload("res://gui/icons/key_capslock.png")

			break
	return [key, key_name]


func get_first_gamepad_button(action: String) -> Array:
	var button = null
	var button_name = ""

	var action_list = _get_filetered_event_list_for_action(action)
	var gamepad = Options.getGamepadName()

	for a in action_list:
		match action:
			"ui_left":
				button = preload("res://gui/icons/gamepad_stick_left.png")
			"ui_right":
				button = preload("res://gui/icons/gamepad_stick_right.png")
			"ui_left":
				button = preload("res://gui/icons/gamepad_stick_left.png")
			"ui_right":
				button = preload("res://gui/icons/gamepad_stick_right.png")

		if button != null:
			break


		if a is InputEventJoypadButton or a is InputEventJoypadMotion:
			var match_against = null
			if a is InputEventJoypadButton:
				match_against = str(a.button_index)

			if a is InputEventJoypadMotion:
				match_against = "axis" + str(a.get_axis())

			if match_against == null:
				break

			button = Options.GamepadButtonAxisToIcon(match_against, gamepad)

	return [button, button_name]

func _get_filetered_event_list_for_action(in_action: String) -> Array[InputEvent]:
	if not DISSALLOW_INPUT_SHARE.has(keeperId):
		return InputMap.action_get_events(in_action)
	if not DISSALLOW_INPUT_SHARE[keeperId].has(in_action):
		return InputMap.action_get_events(in_action)

	var dissallowed: Array = DISSALLOW_INPUT_SHARE[keeperId][in_action]
	var action_list = InputMap.action_get_events(in_action)
	var filtered_list: = action_list.duplicate()
	for event: InputEvent in action_list:
		for action_name in dissallowed:
			if event.is_action(action_name):
				filtered_list.erase(event)
	return filtered_list

func setModifier(mod: Modifier):
	$tap.visible = mod == Modifier.Tap
	$hold.visible = mod == Modifier.Hold
