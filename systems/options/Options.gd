extends Node

signal font_scale_changed(scale: float)

const FONT_SCALE_DEFAULT: = 1.0
const FONT_SCALE_INCREASED: = 1.4

var splitscreen_font_scale: float = FONT_SCALE_DEFAULT

var fixedLocale: String

var masterVolume: float
var musicVolume: float
var ambienceVolume: float
var soundVolume: float
var cyclesWithoutMusic: int
var adaptiveOst: bool
var fixedOstTracks: Array

var singleplayerUseGamepad: = false
var useMouseKeeperGameplay: = false
var useMouseDomeGameplay: = false
var useMouseMenus: = false
var swordSliceWithMouse: = false
var tryAutoSwitchGamepad: = false
var showKeeperAimIndicatorMouse: = false
var showKeeperAimIndicatorGamepad: = false
var keeperMouseSnapDirectionDegrees: = 0
var keeperGamepadSnapDirectionDegrees: = 0
var twinStickControls: = false
var enableSplitScreen: = false
var enableCrossplay: = false
var fullscreen: = false
var borderless: = false
var vsync: = false
var targetfps: int
var renderScale: = 1.0
var renderHalfRes: = false
var reducedParticles: = false
var forcedGamepadType: String = ""
var hideActionHints: = false

var photosensitive: = false
var visibleMonsters: = false
var disableCritters: = false
var disableVignette: = false
var disableWorldBackgrounds: = false

var screenBrightness: = 1.0
var gamepadStickDeadZone: float = 0.2
var gamepadTriggerDeadZone: float = 0.2
var vibrationStrength: = 1.0

var shakeIntensity: = 1.0
var shakeDrill: = true

var enableSeasonalContent: bool
var allowOnlineMultiplayer: bool
var allowCrashReports: bool
var onlineMultiplayerDecided: bool
var pauseWhenOutOfFocus: bool
var useSystemCursor: bool
var showPlayerNames: bool
var showPlayerIndicators: bool
var alwaysShowPing: bool

var lastGamepadDeviceId: = -1
var _actionsRebindedToSupportOnlyOneGamepad: = false

var maximumPlayerCount: = 10

var excludedInputGroups: Array[String] = []

var keeperInputSettings: Dictionary = {
	"keeper1.Mouse": KeeperInputSettings.new(), 
	"keeper1.Gamepad": KeeperInputSettings.new(), 
	"keeper2.Mouse": KeeperInputSettings.new(), 
	"keeper2.Gamepad": KeeperInputSettings.new(), 
	"keeper3.Mouse": KeeperInputSettings.new(), 
	"keeper3.Gamepad": KeeperInputSettings.new(), 
	"keeper4.Mouse": KeeperInputSettings.new(), 
	"keeper4.Gamepad": KeeperInputSettings.new()
}

const optionsPath: = "user://options.txt"
const KEY_BINDINGS = "user://keybindings_4.cfg"

const AXIS_RT: = 5
const AXIS_LT: = 4

var GamepadTranslations: = {
	"0": "A", 
	"1": "B", 
	"2": "X", 
	"3": "Y", 
	"4": "options.keybindings.gamepad.xbox.view", 
	"5": "Xbox", 
	"6": "options.keybindings.gamepad.xbox.menu", 
	"7": "LS", 
	"8": "RS", 
	"9": "LB", 
	"10": "RB", 
	"11": "Up", 
	"12": "Down", 
	"13": "Left", 
	"14": "Right", 
	"axis0": "Left Stick Horizontal", 
	"axis1": "Left Stick Vertical", 
	"axis2": "Right Stick Horizontal", 
	"axis3": "Right Stick Vertical", 
	"axis4": "LT", 
	"axis5": "RT", 
}

var GamepadTranslationsPs4: = {
	"0": "Cross", 
	"1": "Circle", 
	"2": "Square", 
	"3": "Triangle", 
	"4": "Create", 
	"5": "PS", 
	"6": "Options", 
	"9": "L1", 
	"10": "R1", 
	"11": "Up", 
	"12": "Down", 
	"13": "Left", 
	"14": "Right", 
	"axis0": "Left Stick Horizontal", 
	"axis1": "Left Stick Vertical", 
	"axis2": "Right Stick Horizontal", 
	"axis3": "Right Stick Vertical", 
	"axis4": "L2", 
	"axis5": "R2", 
}

var GamepadTranslationsSwitchPro: = {
	"0": "A", 
	"1": "B", 
	"2": "X", 
	"3": "Y", 
	"4": "Minus", 
	"5": "UNKNOWN", 
	"6": "Plus", 
	"9": "L", 
	"10": "R", 
	"11": "Up", 
	"12": "Down", 
	"13": "Left", 
	"14": "Right", 
	"axis0": "Left Stick Horizontal", 
	"axis1": "Left Stick Vertical", 
	"axis2": "Right Stick Horizontal", 
	"axis3": "Right Stick Vertical", 
	"axis4": "ZL", 
	"axis5": "ZR", 
}

var INPUT_ACTIONS = {
	"ui": [
		"ui_select", 
		"ui_cancel", 
		"ui_up", 
		"ui_left", 
		"ui_down", 
		"ui_right", 
		"pause", 
	], 
	"keeper": [
		"keeper_gadget1", 
		"keeper_gadget2", 
	], 
	"keeper1": [
		"keeper1_pickup", 
		"keeper1_drop", 
	], 
	"keeper2": [
		"keeper2_gravityball", 
		"keeper2_gravitycollect", 
	], 
	"keeper3": [
		"keeper3_pickup", 
		"keeper3_throw", 
		"keeper3_rope", 
		"keeper3_jump", 
	], 
	"keeper4": [
		"keeper4_pickup", 
		"keeper4_drop", 
	], 
	"dome": [
		"dome_ability1", 
		"dome_ability2", 
		"dome_upgrades", 
		"dome_battle", 
	], 
	"dome1": [
		"dome1_fire", 
	], 
	"dome2": [
		"dome2_fire", 
		"dome2_special", 
	], 
	"dome3": [
		"dome3_fire", 
		"dome3_special", 
	], 
	"dome4": [
		"dome4_fire", 
	]
}

@onready var _locale_font_remap: LocaleFontRemap = $LocaleFontRemap

func GamepadButtonAxisToIcon(key, gamepad):
	match key:
		"0":
			return load("res://gui/icons/%s/gamepad_button_down.png" % gamepad)
		"1":
			return load("res://gui/icons/%s/gamepad_button_right.png" % gamepad)
		"2":
			return load("res://gui/icons/%s/gamepad_button_left.png" % gamepad)
		"3":
			return load("res://gui/icons/%s/gamepad_button_up.png" % gamepad)
		"9":
			return load("res://gui/icons/%s/gamepad_lb.png" % gamepad)
		"10":
			return load("res://gui/icons/%s/gamepad_rb.png" % gamepad)
		"5":
			return preload("res://gui/icons/gamepad_select.png")
		"7":
			return preload("res://gui/icons/gamepad_menu.png")
		"axis4":
			return load("res://gui/icons/%s/gamepad_lt.png" % gamepad)
		"axis5":
			return load("res://gui/icons/%s/gamepad_rt.png" % gamepad)
		"11":
			return preload("res://gui/icons/gamepad_cross_up.png")
		"12":
			return preload("res://gui/icons/gamepad_cross_down.png")
		"13":
			return preload("res://gui/icons/gamepad_cross_left.png")
		"14":
			return preload("res://gui/icons/gamepad_cross_right.png")
	return null

func getInputSettingsForKeeper(keeper, for_mouse: bool) -> KeeperInputSettings:
	var controller_name = "Mouse" if for_mouse else "Gamepad"
	return keeperInputSettings["%s.%s" % [keeper.techId, controller_name]]

func getInputSettingsForDevice(deviceId: int) -> KeeperInputSettings:
	var keeper = Keepers.getLocalKeeperByDeviceId(deviceId)
	var for_mouse = not useGamepad(deviceId)
	var controller_name = "Mouse" if for_mouse else "Gamepad"

	if keeper == null:
		push_error("No keeper found for deviceId [%s]." % deviceId)

	return keeperInputSettings["%s.%s" % [keeper.techId, controller_name]]

func setInputSettings(input_id: StringName, for_mouse: bool, data: KeeperInputSettings):
	var controller = "Mouse" if for_mouse else "Gamepad"
	var key = "%s.%s" % [input_id, controller]
	keeperInputSettings[key] = data


func getGamepadName(deviceId: = -1) -> String:
	if forcedGamepadType != "":
		return forcedGamepadType

	if deviceId < 1:
		deviceId = 0
	else:
		deviceId -= 1

	var gamepad: String = Input.get_joy_name(deviceId)
	gamepad = gamepad.to_lower()
	if gamepad.find("sony") >= 0 or gamepad.find("ps4") >= 0 or gamepad.find("ps5") >= 0 or gamepad.find("dualshock") >= 0:
		gamepad = "playstation"
	elif gamepad.find("nintendo") >= 0 and gamepad.find("pro") >= 0:
		gamepad = "nintendo"
	else:
		gamepad = "xbox"
	return gamepad

func getGamepadTranslations(input, deviceId: = -1):
	match getGamepadName(deviceId):
		"playstation":
			return GamepadTranslationsPs4.get(str(input), str(input))
		"nintendo":
			return GamepadTranslationsSwitchPro.get(str(input), str(input))
		_:
			return GamepadTranslations.get(str(input), str(input))

func getMouseTranslations(input) -> String:
	match input:
		MOUSE_BUTTON_LEFT:
			return "LMB"
		MOUSE_BUTTON_RIGHT:
			return "RMB"
		MOUSE_BUTTON_MIDDLE:
			return "MMB"
		MOUSE_BUTTON_XBUTTON1:
			return "Back"
		MOUSE_BUTTON_XBUTTON2:
			return "Forward"
	return ""

func init():
	if BuildCustomization.has_feature("enable_block"):
		BlockList.load_block_list()
	loadOptions()
	updateFontSizes()

func saveOptionsToDisk(keysToRemove) -> Dictionary:
	var save = FileAccess.open(optionsPath, FileAccess.ModeFlags.WRITE)
	if save != null:
		var d = {
			"gamepadStickDeadZone": gamepadStickDeadZone, 
			"tryAutoSwitchGamepad": tryAutoSwitchGamepad, 
			"forcedGamepadType": forcedGamepadType, 
			"screenBrightness": screenBrightness, 
			"enableSplitScreen": enableSplitScreen, 
			"enableCrossplay": enableCrossplay, 
			"fullscreen": fullscreen, 
			"borderless": borderless, 
			"vsync": vsync, 
			"renderScale": renderScale, 
			"renderHalfRes": renderHalfRes, 
			"photosensitive": photosensitive, 
			"visibleMonsters": visibleMonsters, 
			"disableCritters": disableCritters, 
			"disableVignette": disableVignette, 
			"disableWorldBackgrounds": disableWorldBackgrounds, 
			"masterVolume": masterVolume, 
			"musicVolume": musicVolume, 
			"ambienceVolume": ambienceVolume, 
			"soundVolume": soundVolume, 
			"cyclesWithoutMusic": cyclesWithoutMusic, 
			"adaptiveOst": adaptiveOst, 
			"fixedOstTracks": fixedOstTracks, 
			"vibrationStrength": vibrationStrength, 
			"shakeIntensity": shakeIntensity, 
			"shakeDrill": shakeDrill, 
			"enableSeasonalContent": enableSeasonalContent, 
			"allowOnlineMultiplayer": allowOnlineMultiplayer, 
			"allowCrashReports": allowCrashReports, 
			"onlineMultiplayerDecided": onlineMultiplayerDecided, 
			"useMouseDomeGameplay": useMouseDomeGameplay, 
			"useMouseMenus": useMouseMenus, 
			"swordSliceWithMouse": swordSliceWithMouse, 
			"pauseWhenOutOfFocus": pauseWhenOutOfFocus, 
			"useSystemCursor": useSystemCursor, 
			"showPlayerNames": showPlayerNames, 
			"showPlayerIndicators": showPlayerIndicators, 
			"alwaysShowPing": alwaysShowPing, 
			"targetfps": Engine.max_fps, 
			"hideActionHints": hideActionHints, 
			"reducedParticles": reducedParticles, 
			"splitscreenFontScale": splitscreen_font_scale, 

			"locale": TranslationServer.get_locale()
			}


		for key in keeperInputSettings:
			d[key] = keeperInputSettings[key].to_dict()

		for key in keysToRemove:
			d.erase(key)
		save.store_string(JSON.stringify(d))
		save.close()
		return d
	return {}

func isAutoSwitchingGamepads() -> bool:
	if Keepers.local.getCount() <= 1:


		return tryAutoSwitchGamepad
	return false

func saveOptions(keysToRemove: = []):

	updateAudioBusses()
	updateGraphicSettings()
	updateDeadzone()

	for l in get_tree().get_nodes_in_group("keybindingListeners"):
		l.onKeyBindingChanged()
	for p in get_tree().get_nodes_in_group("keeper"):
		p.onShowKeeperAimIndicatorChanged()
		p.updateShowPlayerName()

	for world in Level.worldsByTeamId.values():
		world.updateBackgroundVisibility()

	Data.localEvent("options.changed")

	var d = saveOptionsToDisk(keysToRemove)
	Backend.event("options_changed", d)

func hasOptionsSave() -> bool:
	var save = FileAccess.open(optionsPath, FileAccess.ModeFlags.READ)
	return save != null

func loadOptions():
	var save = FileAccess.open(optionsPath, FileAccess.ModeFlags.READ)
	var options = {}
	if save != null:
		var i = save.get_as_text()
		var test_json_conv = JSON.new()
		test_json_conv.parse(i)
		var parsed = test_json_conv.get_data()
		if parsed:
			options = parsed


	for key: StringName in keeperInputSettings:
		var for_mouse: bool = key.contains("Mouse")
		keeperInputSettings[key].from_dict(options.get(key, {}), for_mouse, key.split(".")[0])

	gamepadStickDeadZone = options.get("gamepadStickDeadZone", 0.2)
	showKeeperAimIndicatorMouse = options.get("showKeeperAimIndicatorMouse", false)
	showKeeperAimIndicatorGamepad = options.get("showKeeperAimIndicatorGamepad", false)
	tryAutoSwitchGamepad = options.get("tryAutoSwitchGamepad", false)
	forcedGamepadType = options.get("forcedGamepadType", "")
	enableSplitScreen = options.get("enableSplitScreen", false)
	enableCrossplay = options.get("enableCrossplay", false)
	fullscreen = options.get("fullscreen", true)
	borderless = options.get("borderless", false)
	screenBrightness = options.get("screenBrightness", 1.0)
	disableVignette = options.get("disableVignette", false)
	disableWorldBackgrounds = options.get("disableWorldBackgrounds", false)
	vsync = options.get("vsync", true)
	renderScale = options.get("renderScale", 1.0)
	renderHalfRes = options.get("renderHalfRes", false)
	photosensitive = options.get("photosensitive", false)
	visibleMonsters = options.get("visibleMonsters", false)
	disableCritters = options.get("disableCritters", false)
	masterVolume = options.get("masterVolume", 1.0)
	soundVolume = options.get("soundVolume", 1.0)
	ambienceVolume = options.get("ambienceVolume", 1.0)
	musicVolume = options.get("musicVolume", 0.9)
	cyclesWithoutMusic = options.get("cyclesWithoutMusic", 2)
	adaptiveOst = options.get("adaptiveOst", true)
	fixedOstTracks = options.get("fixedOstTracks", ["keeper1"])
	shakeIntensity = options.get("shakeIntensity", 1.0)
	vibrationStrength = options.get("vibrationStrength", 1.0)
	shakeDrill = options.get("shakeDrill", false)
	targetfps = options.get("targetfps", 250)
	reducedParticles = options.get("reducedParticles", false)
	if options.has("useMouseDomeGameplay"):
		useMouseDomeGameplay = options.get("useMouseDomeGameplay")
	else:
		useMouseDomeGameplay = GameWorld.isFirstTimePlaying
	useMouseMenus = options.get("useMouseMenus", true)
	swordSliceWithMouse = options.get("swordSliceWithMouse", false)
	Logger.info("setting target fps to " + str(targetfps))
	Engine.max_fps = targetfps

	enableSeasonalContent = options.get("enableSeasonalContent", true)
	allowOnlineMultiplayer = options.get("allowOnlineMultiplayer", false)
	allowCrashReports = options.get("allowCrashReports", allowOnlineMultiplayer)
	onlineMultiplayerDecided = options.get("onlineMultiplayerDecided", false)
	pauseWhenOutOfFocus = options.get("pauseWhenOutOfFocus", true)
	useSystemCursor = options.get("useSystemCursor", false)
	showPlayerNames = options.get("showPlayerNames", true)
	showPlayerIndicators = options.get("showPlayerIndicators", true)
	alwaysShowPing = options.get("alwaysShowPing", false)
	hideActionHints = options.get("hideActionHints", false)
	splitscreen_font_scale = options.get("splitscreenFontScale", FONT_SCALE_DEFAULT)

	if BuildCustomization.has_feature("disable_pc_options"):
		singleplayerUseGamepad = true
		useMouseDomeGameplay = false
		useMouseKeeperGameplay = false
		useMouseMenus = false

	if BuildCustomization.has_feature("disable_allow_online_option"):
		onlineMultiplayerDecided = true

	if BuildCustomization.has_feature("force_xbox_controller_layout"):
		forcedGamepadType = "xbox"
	if BuildCustomization.has_feature("force_ps_controller_layout"):
		forcedGamepadType = "playstation"
	if BuildCustomization.has_feature("force_switch_controller_layout"):
		forcedGamepadType = "nintendo"


	GameWorld.updateSeasonalEvents()

	updateDeadzone()
	updateGraphicSettings()
	updateAudioBusses()

	loadKeyBindings()

	var locale: String
	if fixedLocale:
		locale = fixedLocale
	else:
		locale = options.get("locale", OS.get_locale())
	if locale != TranslationServer.get_locale():
		Logger.info("current locale is " + str(TranslationServer.get_locale()) + ", changing to " + locale)
		$Tween.interpolate_callback(self, 1.0, "transitionToLocale", locale)
		$Tween.start()
	else:
		_locale_font_remap.remap_fonts_to_language(locale)
		Logger.info("leaving locale at " + locale)

func transitionToLocale(locale: String):
	_locale_font_remap.remap_fonts_to_language(locale)
	TranslationServer.set_locale(locale)
	for l in get_tree().get_nodes_in_group("locale"):
		l.onLocaleChanged()
	Style.applyPaletteToFontSettings()
	Options.updateFontSizes()

func ensureFontOversamplig() -> void :
	_locale_font_remap.ensure_font_oversampling()

func updateGraphicSettings():
	updateWindowMode()
	updateVsync()
	var window = get_window()
	prints("Update Graphics Settings:", "mode", window.mode, "borderless", window.borderless, "vsync", DisplayServer.window_get_vsync_mode(), \
	"size", window.size)

func updateWindowMode(force: bool = false):
	var window = get_window()

	var target_mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (fullscreen) else Window.MODE_WINDOWED
	if not fullscreen:
		var w = window.get_size_with_decorations()
		var s = DisplayServer.screen_get_size()
		s.y *= 0.95
		if w.x > s.x or w.y > s.y:
			target_mode = Window.MODE_MAXIMIZED

	if window.mode != target_mode or force:
		window.mode = target_mode
	if not OS.has_feature("macos") and window.borderless != borderless:
		window.borderless = borderless

func updateVsync():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if (vsync) else DisplayServer.VSYNC_DISABLED)

func saveKeybindings():
	if BuildCustomization.has_feature("disable_input_rebinding"):
		return

	var config = ConfigFile.new()
	for groupName in INPUT_ACTIONS:
		for action in INPUT_ACTIONS[groupName]:
			var inputEvents = []
			for input in InputMap.action_get_events(action):
				inputEvents.append(eventToKeyConfig(input))
			match action:
				"ui_select":
					config.set_value(groupName, "ui_accept", inputEvents)
				"ui_left":
					inputEvents.append("gamepadaxis:0:-1")
				"ui_right":
					inputEvents.append("gamepadaxis:0:1")
				"ui_up":
					inputEvents.append("gamepadaxis:1:-1")
				"ui_down":
					inputEvents.append("gamepadaxis:1:1")
			config.set_value(groupName, action, inputEvents)
	config.save(Options.KEY_BINDINGS)

func resetKeyBindingsToDefault():
	Logger.info("resetting key bindings to default.")
	InputMap.load_from_project_settings()
	saveKeybindings()

func eventToKeyConfig(event: InputEvent):
	if event is InputEventKey:
		if event.physical_keycode != 0:
			return "keyboardphysical:" + str(event.physical_keycode)
		return "keyboard:" + str(event.keycode)
	elif event is InputEventJoypadButton:
		return "gamepadbutton:" + str(event.button_index)
	elif event is InputEventJoypadMotion:
		return "gamepadaxis:" + str(event.axis) + ":" + str(event.axis_value)
	elif event is InputEventMouseButton:
		return "mouse:" + str(event.button_index)

func deleteOptions():
	if FileAccess.file_exists(optionsPath):
		var err: Error = DirAccess.remove_absolute(optionsPath)
		assert (err == Error.OK)

func loadKeyBindings(ignoredEvents: = []):
	if BuildCustomization.has_feature("disable_input_rebinding"):
		InputMap.load_from_project_settings()
		return

	var config = ConfigFile.new()
	var err = config.load(KEY_BINDINGS)
	if not err:
		for section in config.get_sections():
			for action_name in config.get_section_keys(section):
				if ignoredEvents.has(action_name):
					print("ignoring " + action_name)
					continue
				InputMap.action_erase_events(action_name)
				var allBindings = config.get_value(section, action_name)
				for binding in allBindings:
					if binding and binding.find(":") != -1:
						var split = binding.split(":")
						var event: InputEvent
						match split[0]:
							"keyboardphysical":
								event = InputEventKey.new()
								event.physical_keycode = int(split[1])
							"keyboard":
								event = InputEventKey.new()
								event.keycode = int(split[1])
							"gamepadbutton":
								event = InputEventJoypadButton.new()
								event.button_index = int(split[1])
								event.device = -1
							"gamepad":

								event = InputEventJoypadButton.new()
								event.button_index = int(split[1])
								event.device = -1
							"gamepadaxis":
								event = InputEventJoypadMotion.new()
								event.axis = int(split[1])
								var axis_val: = float(split[2])
								axis_val = -1.0 if axis_val < 0.0 else 1.0
								event.axis_value = axis_val
								event.device = -1
							"mouse":
								event = InputEventMouseButton.new()
								event.button_index = int(split[1])
						InputMap.action_add_event(action_name, event)

func remapInputEvent(from: String, to: String):
	Logger.info("remapping input action '" + from + "' to " + str(to))
	var config = ConfigFile.new()
	var err = config.load(KEY_BINDINGS)
	if err:
		return
	var hasChanges: = false
	for section in config.get_sections():
		for action_name in config.get_section_keys(section):
			if action_name == from:
				config.set_value(section, to, config.get_value(section, action_name))
				config.erase_section_key(section, from)
				hasChanges = true

	if hasChanges:
		config.save(Options.KEY_BINDINGS)

func setInputEventFromDefault(events: Array):
	Logger.info("setting input action '" + str(events) + "' to default bindings.")
	InputMap.load_from_project_settings()
	loadKeyBindings(events)
	saveKeybindings()
	loadKeyBindings()

func updateAudioBusses():
	if masterVolume == 0:
		Audio.set_bus_volume(Audio.BUS_MASTER, -90)
	else:
		Audio.set_bus_volume(Audio.BUS_MASTER, (masterVolume * 24) - 24)
	if soundVolume == 0:
		Audio.set_bus_volume(Audio.BUS_SOUNDS, -90)
		Audio.set_bus_volume(Audio.BUS_UI, -90)
	else:
		Audio.set_bus_volume(Audio.BUS_SOUNDS, (soundVolume * 24) - 24)
		Audio.set_bus_volume(Audio.BUS_UI, (soundVolume * 24) - 24)
	if musicVolume == 0:
		Audio.set_bus_volume(Audio.BUS_MUSIC, -90)
	else:
		Audio.set_bus_volume(Audio.BUS_MUSIC, (musicVolume * 24) - 24)
	if ambienceVolume == 0:
		Audio.set_bus_volume(Audio.BUS_AMBIENCE, -90)
	else:
		Audio.set_bus_volume(Audio.BUS_AMBIENCE, (ambienceVolume * 24) - 24)

func updateDeadzone():
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		InputMap.action_set_deadzone(action, 0.5)

func setUseGamepad(b, deviceId: int = -1):
	if GameWorld.isSplitScreen():
		if _actionsRebindedToSupportOnlyOneGamepad:
			_actionsRebindedToSupportOnlyOneGamepad = false
			for action in InputMap.get_actions():
				for inputEvent in InputMap.action_get_events(action):
					if inputEvent is InputEventJoypadButton or inputEvent is InputEventJoypadMotion:
						inputEvent.device = -1
		return

	if b == singleplayerUseGamepad and lastGamepadDeviceId == deviceId:
		return

	if b:
		GameWorld.setShowMouse(false)

	if BuildCustomization.has_feature("disable_pc_options"):
		return

	if Platform.runningOnHandheldDevice():
		singleplayerUseGamepad = true
		lastGamepadDeviceId = deviceId
		for l in get_tree().get_nodes_in_group("gamepadListeners"):
			l.onInputMethodChanged()
	else:
		if singleplayerUseGamepad != b:
			singleplayerUseGamepad = b
			lastGamepadDeviceId = deviceId
			for l in get_tree().get_nodes_in_group("gamepadListeners"):
				l.onInputMethodChanged()

			InputSystem.getLastChild().becameLeaf()

	if Keepers.local.getCount() > 1:
		singleplayerUseGamepad = false

	if tryAutoSwitchGamepad:
		if singleplayerUseGamepad and lastGamepadDeviceId != deviceId:
			Logger.info("changing gamepad input events from device " + str(lastGamepadDeviceId) + " to device " + str(deviceId))
			for action in InputMap.get_actions():
				for inputEvent in InputMap.action_get_events(action):
					if inputEvent is InputEventJoypadButton or inputEvent is InputEventJoypadMotion:
						inputEvent.device = deviceId
			lastGamepadDeviceId = deviceId
			_actionsRebindedToSupportOnlyOneGamepad = true

func useGamepad(deviceId: int) -> bool:
	if BuildCustomization.has_feature("disable_pc_options"):
		return true

	if not GameWorld.isSplitScreen() and deviceId == -1:
		return singleplayerUseGamepad

	return deviceId > 0

func updateFontSizes():
	if Platform.runningOnHandheldDevice():
		for font in [
			preload("res://gui/fontsettings/NormalFontSettings.tres"), 
			preload("res://gui/fontsettings/NormalFontSettingsHighlighted.tres"), 
			preload("res://gui/fontsettings/NumbersFontSettings.tres"), 
			preload("res://gui/fontsettings/NumbersFontSettingsHighlighted.tres"), 
			preload("res://gui/fontsettings/NumbersMonospaceFontSettings.tres"), 
		]:
			font.font_size = 28

		for font in [
			load("res://gui/fontsettings/SmallFontSettings.tres"), 
			load("res://gui/fontsettings/SmallFontSettingsHighlighted.tres"), 
		]:
			font.font_size = 24

		Options.font_scale_changed.emit(splitscreen_font_scale)

func setFontScale(scale: float, force: bool = false):
	if not force and scale == splitscreen_font_scale:
		return

	splitscreen_font_scale = scale
	font_scale_changed.emit(splitscreen_font_scale)

func includeInputGroup(groupId: StringName):
	excludedInputGroups.erase(groupId)

func excludeInputGroup(groupId: StringName):
	if not excludedInputGroups.has(groupId):
		excludedInputGroups.append(groupId)
