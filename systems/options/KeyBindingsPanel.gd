extends Control

signal quit

var translations: = {
	"keeper": "options.keybindings.action.keeper", 
	"keeper_gadget1": "options.keybindings.action.keeper.gadget1", 
	"keeper_gadget2": "options.keybindings.action.keeper.gadget2", 
	"keeper1": "upgrades.keeper1.title", 
	"keeper1_pickup": "options.keybindings.action.keeper.pickup", 
	"keeper1_drop": "options.keybindings.action.keeper.drop", 
	"keeper2": "upgrades.keeper2.title", 
	"keeper2_gravityball": "options.keybindings.action.keeper.gravityball", 
	"keeper2_gravitycollect": "options.keybindings.action.keeper.gravitycollect", 
	"keeper3": "upgrades.keeper3.title", 
	"keeper3_pickup": "options.keybindings.action.keeper.pickup", 
	"keeper3_throw": "options.keybindings.action.keeper.throw", 
	"keeper3_rope": "options.keybindings.action.keeper.rope", 
	"keeper3_jump": "options.keybindings.action.keeper.jump", 
	"keeper4": "upgrades.keeper4.title", 
	"keeper4_pickup": "options.keybindings.action.keeper.pickup", 
	"keeper4_drop": "options.keybindings.action.keeper.drop", 

	"dome": "options.keybindings.action.dome", 
	"dome_upgrades": "options.keybindings.action.dome.upgrade", 
	"dome_battle": "options.keybindings.action.dome.battle", 
	"dome_ability1": "options.keybindings.action.dome.battleability1", 
	"dome_ability2": "options.keybindings.action.dome.battleability2", 
	"dome1": "upgrades.dome1.title", 
	"dome1_fire": "level.station.battle.navbar.shoot", 
	"dome2": "upgrades.dome2.title", 
	"dome2_fire": "level.station.battle.navbar.stab", 
	"dome2_special": "level.station.battle.navbar.stabspeedup", 
	"dome3": "upgrades.dome3.title", 
	"dome3_fire": "level.station.battle.navbar.artilleryshoot", 
	"dome3_special": "level.station.battle.navbar.artilleryflak", 
	"dome4": "upgrades.dome4.title", 
	"dome4_fire": "level.station.battle.navbar.shoot", 

	"ui": "options.keybindings.action.general", 
	"ui_cancel": "options.keybindings.action.general.back", 
	"ui_select": "options.keybindings.action.general.use", 
	"ui_left": "options.keybindings.action.general.left", 
	"ui_right": "options.keybindings.action.general.right", 
	"ui_up": "options.keybindings.action.general.up", 
	"ui_down": "options.keybindings.action.general.down", 
	"pause": "pause.title", 
}


var lastFocusButton

var deviceId: = -1

var _prevViewportFocus: Control = null
@onready var _keyBindings: VBoxContainer = $CenterContainer / PanelContainer / MarginContainer / VBoxContainer / ScrollContainer / KeyBindings
@onready var _scrollContainer: ScrollContainer = $CenterContainer / PanelContainer / MarginContainer / VBoxContainer / ScrollContainer
@onready var _hBoxContainer2: HBoxContainer = $CenterContainer / PanelContainer / MarginContainer / VBoxContainer / HBoxContainer2

func _ready():

	translations["keeper1"] = tr("upgrades.keeper1.title")
	translations["dome1"] = tr("upgrades.dome1.title")
	buildBindingUi()
	$ColorRect.visible = false
	InputSystem.grabFocus(find_child("ButtonApply"))
	Style.init(self)
	get_viewport().gui_focus_changed.connect(_on_viewport_gui_focus_changed)

func _on_ButtonApply_pressed():
	Audio.sound("gui_apply")
	var config = ConfigFile.new()
	for binding in get_tree().get_nodes_in_group("key_bindings"):
		match binding.action_name:
			"ui_select":
				config.set_value(binding.group, "ui_accept", binding.inputEvents)
			"ui_left":
				binding.inputEvents.append("gamepadaxis:0:-1")
			"ui_right":
				binding.inputEvents.append("gamepadaxis:0:1")
			"ui_up":
				binding.inputEvents.append("gamepadaxis:1:-1")
			"ui_down":
				binding.inputEvents.append("gamepadaxis:1:1")
		config.set_value(binding.group, binding.action_name, binding.inputEvents)
	config.save(Options.KEY_BINDINGS)
	emit_signal("quit")

	Options.loadKeyBindings()

func _on_ResetButton_pressed():
	Audio.sound("gui_select")
	InputMap.load_from_project_settings()
	buildBindingUi()

func buildBindingUi():
	var firstButtonFocusChangeConnected: bool = false
	for c in _keyBindings.get_children():
		c.queue_free()
	for groupName in Options.INPUT_ACTIONS:
		if Options.excludedInputGroups.has(groupName):
			continue
		var sep = HSeparator.new()
		_keyBindings.add_child(sep)
		var l = Label.new()
		l.text = translations[groupName]
		l.label_settings = preload("res://gui/fontsettings/LargeFontSettings.tres")

		_keyBindings.add_child(l)
		for action_name in Options.INPUT_ACTIONS[groupName]:
			var bindingEntry = preload("res://systems/options/KeyBinding.tscn").instantiate()
			bindingEntry.init(action_name, translations[action_name], groupName)
			_keyBindings.add_child(bindingEntry)
			bindingEntry.request_change.connect(showInputPopup.bind(bindingEntry))
			bindingEntry.request_unbind.connect(bindingEntry.unbind)
			if not firstButtonFocusChangeConnected:
				bindingEntry.button_focus_entered.connect(_on_first_binding_focus_entered)
				firstButtonFocusChangeConnected = true

	if BuildCustomization.has_feature("disable_pc_options"):
		%KeyboardLabel.visible = false
		%MouseLabel.visible = false

	Style.init(_keyBindings)

var catchNewInputInputProcessor
func showInputPopup(actionName: String, buttonName: String, bindingEntry):
	Audio.sound("gui_select")
	find_child("RebindingTitleLabel").text = tr("options.keybindings.rebinding") + " \"" + tr(translations[actionName]) + "\""
	catchNewInputInputProcessor = preload("res://systems/options/BindKeyInputProcessor.gd").new()
	catchNewInputInputProcessor.deviceId = deviceId
	catchNewInputInputProcessor.globalInput = true
	catchNewInputInputProcessor.buttonName = buttonName
	catchNewInputInputProcessor.bindingEntry = bindingEntry
	var newKeyLabel = find_child("NewKeyLabel")
	catchNewInputInputProcessor.inputLabel = newKeyLabel
	catchNewInputInputProcessor.connect("onStart", Callable(self, "showCatchInputPopup"))
	catchNewInputInputProcessor.connect("onStop", Callable(self, "hideCatchInputPopup"))
	catchNewInputInputProcessor.connect("captured", Callable(self, "setCaptured"))
	catchNewInputInputProcessor.integrate(self)

func showCatchInputPopup():
	$ColorRect.visible = true
	lastFocusButton = get_viewport().gui_get_focus_owner()
	lastFocusButton.release_focus()
	find_child("CaptureKeyControls").visible = false
	find_child("ErrorMessageLabel").visible = false

func hideCatchInputPopup():
	$ColorRect.visible = false
	InputSystem.grabFocus(lastFocusButton)

func _on_CancelInputButton_pressed():
	Audio.sound("gui_cancel")
	catchNewInputInputProcessor.desintegrate()
	catchNewInputInputProcessor = null

func _on_ApplyInputButton_pressed():
	Audio.sound("gui_apply")
	if not catchNewInputInputProcessor:

		return

	clearReservedKeyConflicts(catchNewInputInputProcessor.bindingEntry, catchNewInputInputProcessor.capturedEvent)
	catchNewInputInputProcessor.apply()
	catchNewInputInputProcessor.desintegrate()
	catchNewInputInputProcessor = null

func clearReservedKeyConflicts(targetRow, capturedEvent):
	var isReserved: = false
	if capturedEvent is InputEventKey and (capturedEvent.keycode == KEY_ESCAPE or capturedEvent.physical_keycode == KEY_ESCAPE):
		isReserved = true
	elif capturedEvent is InputEventJoypadButton and capturedEvent.button_index == JOY_BUTTON_START:
		isReserved = true
	if not isReserved:
		return

	var newKey = Options.eventToKeyConfig(capturedEvent)
	for row in get_tree().get_nodes_in_group("key_bindings"):
		if row == targetRow or row.group != targetRow.group:
			continue
		for i in range(row.inputEvents.size()):
			if row.inputEvents[i] == newKey:
				row.unbind(row.controls[i])

func clearCapture():
	find_child("CaptureKeyControls").visible = false
	find_child("ErrorMessageLabel").visible = false
	if catchNewInputInputProcessor:
		catchNewInputInputProcessor.startCapture()

func setCaptured():
	find_child("CaptureKeyControls").visible = true
	var isKey = catchNewInputInputProcessor.capturedEvent is InputEventKey
	var isJoy = catchNewInputInputProcessor.capturedEvent is InputEventJoypadButton or catchNewInputInputProcessor.capturedEvent is InputEventJoypadMotion
	var isMouse = catchNewInputInputProcessor.capturedEvent is InputEventMouseButton
	var mismatchKey = (isJoy or isMouse) and catchNewInputInputProcessor.buttonName.find("KeyboardButton") != -1
	var mismatchPad = (isKey or isMouse) and catchNewInputInputProcessor.buttonName.find("GamepadButton") != -1
	var mismatchMouse = (isJoy or isKey) and catchNewInputInputProcessor.buttonName.find("MouseButton") != -1
	var mismatch = mismatchKey or mismatchPad or mismatchMouse
	find_child("ErrorMessageLabel").visible = mismatch
	if mismatchKey:
		find_child("ErrorMessageLabel").text = "options.keybindings.rebinding.error.keyboard"
	if mismatchPad:
		find_child("ErrorMessageLabel").text = "options.keybindings.rebinding.error.gamepad"
	if mismatchMouse:
		find_child("ErrorMessageLabel").text = "options.keybindings.rebinding.error.mouse"
	find_child("ApplyInputButton").disabled = mismatch
	if mismatch:
		InputSystem.grabFocus(find_child("CaptureButton"))
	else:
		InputSystem.grabFocus(find_child("ApplyInputButton"))

func _on_CancelButton_pressed():
	Audio.sound("gui_cancel")
	emit_signal("quit")



func _on_first_binding_focus_entered() -> void :
	_scrollToTheVeryTop()

func _scrollToTheVeryTop() -> void :
	var topControl: Control = _keyBindings.get_children().front()
	_scrollContainer.ensure_control_visible(topControl)

func _on_viewport_gui_focus_changed(newFocusNode: Control) -> void :
	var bottomRowButtonJustFocused: bool = newFocusNode in _hBoxContainer2.get_children()
	if not bottomRowButtonJustFocused:
		_prevViewportFocus = newFocusNode
		return

	var isFocusedDueToScrollDown = not (_prevViewportFocus in _hBoxContainer2.get_children())
	if not isFocusedDueToScrollDown:
		_prevViewportFocus = newFocusNode
		return

	_scrollToFirstButtonBelowVisibleArea()
	_prevViewportFocus = newFocusNode

func _scrollToFirstButtonBelowVisibleArea() -> void :
	for child: Control in _keyBindings.get_children():
		if not child is HBoxContainer:
			continue
		var isBelow: bool = _isControlBelowVisibleScrollArea(child, _scrollContainer)
		if isBelow:
			_scrollContainer.ensure_control_visible(child)
			return

func _isControlBelowVisibleScrollArea(control: Control, scroll_container: ScrollContainer) -> bool:
	if not is_instance_valid(control) or not is_instance_valid(scroll_container):
		return false

	var scrollContainerRect: Rect2 = scroll_container.get_global_rect()
	var controlRect: Rect2 = control.get_global_rect()
	var scrollContainerBottom: = scrollContainerRect.position.y + scrollContainerRect.size.y
	var isBelowScrollContainerRect: bool = controlRect.position.y >= scrollContainerBottom
	return isBelowScrollContainerRect
