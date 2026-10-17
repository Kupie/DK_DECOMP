extends PopupPanel

const POPUP_SIZE: Vector2 = Vector2(300, 300)
const POPUP_POSITION_MARGIN: int = 70

const BTN_DIGIT_NAME_PREFIX = "BtnDigit"
const BTN_CANCEL_NAME_POSTFIX = "cancel"
const BTN_ACCEPT_NAME_POSTFIX = "accept"

@export var target_text_input: LineEdit
@export var focus_on_close: Control
@export var focus_on_accept: Control
@export var callback_on_accept: Callable

var material: Material: set = set_material, get = get_material

@onready var _button_container: GridContainer = $ButtonContainer
@onready var _button_cancel: Button = $ButtonContainer / Button_cancel

@onready var _keycode_to_button: Dictionary = {
	KEY_0: $ButtonContainer / BtnDigit0, 
	KEY_1: $ButtonContainer / BtnDigit1, 
	KEY_2: $ButtonContainer / BtnDigit2, 
	KEY_3: $ButtonContainer / BtnDigit3, 
	KEY_4: $ButtonContainer / BtnDigit4, 
	KEY_5: $ButtonContainer / BtnDigit5, 
	KEY_6: $ButtonContainer / BtnDigit6, 
	KEY_7: $ButtonContainer / BtnDigit7, 
	KEY_8: $ButtonContainer / BtnDigit8, 
	KEY_9: $ButtonContainer / BtnDigit9, 
	KEY_KP_0: $ButtonContainer / BtnDigit0, 
	KEY_KP_1: $ButtonContainer / BtnDigit1, 
	KEY_KP_2: $ButtonContainer / BtnDigit2, 
	KEY_KP_3: $ButtonContainer / BtnDigit3, 
	KEY_KP_4: $ButtonContainer / BtnDigit4, 
	KEY_KP_5: $ButtonContainer / BtnDigit5, 
	KEY_KP_6: $ButtonContainer / BtnDigit6, 
	KEY_KP_7: $ButtonContainer / BtnDigit7, 
	KEY_KP_8: $ButtonContainer / BtnDigit8, 
	KEY_KP_9: $ButtonContainer / BtnDigit9, 
	KEY_ENTER: $ButtonContainer / Button_accept, 
	KEY_BACKSPACE: $ButtonContainer / Button_cancel
}

var _ignore_hide_request: bool = false


func set_material(new_material: Material) -> void :
	_button_container.material = new_material

func get_material() -> Material:
	return _button_container.material

func _ready() -> void :
	assert (is_instance_valid(target_text_input))
	assert (is_instance_valid(focus_on_close))
	assert (is_instance_valid(focus_on_accept))

	target_text_input.gui_input.connect(_on_target_text_input_gui_input)
	target_text_input.focus_entered.connect(_on_target_text_input_focus_entered)

	get_tree().get_root().size_changed.connect(_on_root_viewport_size_changed)

	for button: Button in _button_container.get_children():
		button.pressed.connect(_on_buttton_pressed.bind(button))
		assert (_is_substring_part_of_node_name(button, BTN_DIGIT_NAME_PREFIX) or \
		_is_substring_part_of_node_name(button, BTN_CANCEL_NAME_POSTFIX) or \
		_is_substring_part_of_node_name(button, BTN_ACCEPT_NAME_POSTFIX), 
			"Logic depends on the button names")

func _is_substring_part_of_node_name(in_btn: Node, in_substring: String) -> bool:
	return in_btn.get_name().find(in_substring) > -1

func _on_target_text_input_gui_input(event: InputEvent):
	if event.is_action_pressed("ui_accept"):
		_pop()

func _on_target_text_input_focus_entered() -> void :
	_pop()





func _pop(in_focus_cancel: bool = false):
	_ignore_hide_request = false
	target_text_input.focus_mode = Control.FOCUS_NONE
	var size_and_position: Rect2i = _get_desired_position_and_size()
	popup(size_and_position)

	_ensure_focus(in_focus_cancel)
	_init_buttons_visual_state(in_focus_cancel)
	_emulate_visual_focus(target_text_input, true)

func _ensure_focus(in_focus_cancel: bool) -> void :
	var need_to_focus: bool = true
	var current_focus: Control = gui_get_focus_owner()
	for button in _button_container.get_children():
		if button == current_focus:
			need_to_focus = false
			break

	if need_to_focus:
		if in_focus_cancel:
			_button_cancel.grab_focus()
		else:
			var first_btn: Button = _button_container.get_children().front() as Button
			first_btn.grab_focus()

func _init_buttons_visual_state(in_ignore_cancel: bool) -> void :
	for button: Button in _button_container.get_children():
		if in_ignore_cancel and button == _button_cancel:

			continue
		_unpress_button_visually(button)

func _emulate_visual_focus(in_line_edit_to_visually_focus: LineEdit, in_is_focused: bool) -> void :
	if in_is_focused:
		var focusStylebox: StyleBox = in_line_edit_to_visually_focus.get_theme_stylebox("focus")
		in_line_edit_to_visually_focus.add_theme_stylebox_override("normal", focusStylebox)
	else:
		in_line_edit_to_visually_focus.remove_theme_stylebox_override("normal")

func _on_root_viewport_size_changed() -> void :

	_reposition()

func _reposition() -> void :
	var position_and_size: Rect2i = _get_desired_position_and_size()
	position = position_and_size.position
	size = position_and_size.size

func _get_desired_position_and_size() -> Rect2i:
	var popup_at_position: Vector2 = target_text_input.get_global_rect().position
	popup_at_position.y = popup_at_position.y + POPUP_POSITION_MARGIN
	var viewport_size: Vector2i = get_tree().get_root().get_visible_rect().size
	popup_at_position.x = (viewport_size.x - POPUP_SIZE.x) / 2
	return Rect2i(popup_at_position, POPUP_SIZE)

func _on_buttton_pressed(in_button: Button) -> void :
	_use_button(in_button)

func _use_button(in_button: Button) -> void :
	var btnName: String = in_button.get_name()
	in_button.grab_focus()
	if btnName.begins_with(BTN_DIGIT_NAME_PREFIX):
		_send_digit(in_button)
	elif btnName.ends_with(BTN_CANCEL_NAME_POSTFIX):
		_send_cancel()
	elif btnName.ends_with(BTN_ACCEPT_NAME_POSTFIX):
		_send_accept()

func _send_digit(in_button: Button) -> void :
	var digit: int = _get_digit_from_button(in_button)
	target_text_input.insert_text_at_caret(str(digit))

func _get_digit_from_button(in_button: Button) -> int:
	var digit: int = in_button.text.to_int()
	return digit

func _send_cancel() -> void :
	if target_text_input.text.is_empty():
		hide()
	else:
		target_text_input.delete_char_at_caret()

func _send_accept() -> void :
	hide()
	focus_on_accept.grab_focus()
	if callback_on_accept != null:
		if not target_text_input.text.is_empty():
			callback_on_accept.call_deferred()

func _on_window_input(event: InputEvent) -> void :
	if event is InputEventKey:
		event = event as InputEventKey
		if event.is_action_pressed("escape"):
			hide_keyboard()
		elif (event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_V:
			if not event.pressed:
				return
			var clipped_clipboard: String = DisplayServer.clipboard_get().substr(0, target_text_input.max_length)
			var nmb_only_clipboard: String = _ensure_only_numbers(clipped_clipboard)
			_send_str(nmb_only_clipboard)
		elif event.keycode in _keycode_to_button and event.is_pressed():
			_use_button(_keycode_to_button[event.keycode])
			_press_button_visually(_keycode_to_button[event.keycode])
			if event.keycode == KEY_BACKSPACE:
				_ignore_hide_request = true
		elif not event.is_pressed() and event.keycode in _keycode_to_button:
			_unpress_button_visually(_keycode_to_button[event.keycode])

	if event is InputEventJoypadButton:

		if event.is_action_pressed("ui_cancel"):
			_use_button(_keycode_to_button[KEY_BACKSPACE])
			_press_button_visually(_keycode_to_button[KEY_BACKSPACE])
			_ignore_hide_request = true
		elif event.is_action_released("ui_cancel"):
			_unpress_button_visually(_keycode_to_button[KEY_BACKSPACE])

func _ensure_only_numbers(in_string: String) -> String:
	var numbers_only: = ""
	for c in in_string:
		if c >= "0" and c <= "9":
			numbers_only += c
	return numbers_only

func _send_str(in_str: String) -> void :
	target_text_input.insert_text_at_caret(in_str)

func _press_button_visually(in_button: Button) -> void :
	in_button.toggle_mode = true
	in_button.set_pressed_no_signal(true)

func _unpress_button_visually(in_button: Button) -> void :
	in_button.toggle_mode = false
	in_button.set_pressed_no_signal(false)

func _on_popup_hide() -> void :
	if _ignore_hide_request:
		_pop.bind(true).call_deferred()
		return
	target_text_input.focus_mode = Control.FOCUS_ALL
	hide_keyboard()
	_emulate_visual_focus(target_text_input, false)

func hide_keyboard() -> void :
	focus_on_close.grab_focus()
	hide()

func _on_focus_exited() -> void :
	hide()
