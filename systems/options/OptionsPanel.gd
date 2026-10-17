extends CenterContainer

signal close

var autoSwitchGamepad: = true
var fullscreen: = false
var borderless: = false
var stretchmode: int
var screenBrightness: = 1.0
var gamepadStickDeadZone: float = 0.2

var readied: = false

var categories: = ["Game", "Video", "Audio", "Input", "Gamepad", "Accessibility"]
var currentCategory: String

var deviceId: = -1

@onready var _show_ping_button: CheckBox = $PanelContainer / VBoxContainer / PanelContainer / MarginContainer / GameCategory / VBoxContainer2 / MultiplayerVBoxContainer / ShowPingButton


func _ready():
	find_child("StickMoveRect").color = Style.STRUCT_DARK
	find_child("ButtonBorderless").visible = OS.get_name() != "macOS"

	if GameWorld.qaOptions:
		categories.insert(0, "QA")
		find_child("QACategoryButton").visible = true
	else:
		find_child("QACategoryButton").visible = false
		find_child("QACategory").visible = false

	if BuildCustomization.has_feature("disable_pc_options"):
		find_child("SystemCursorButton").visible = false
		find_child("AutoSwitchGamepadCheckBox").visible = false
		%AllowTelemetryButton.visible = false


		%GraphicsLabel.visible = false
		%GraphicsVBoxContainer.visible = false
		%VideoSpacer1.visible = false
		%PerformanceLabel.visible = false
		%PerformanceVBoxContainer.visible = false
		%VideoSpacer2.visible = false


		%MouseUsageVBoxContainer.visible = false


		%KeyboardGamepadSwitchLabel.visible = false

	if BuildCustomization.has_feature("disable_deadzone_option"):

		%DeadzoneLabel.visible = false
		%DeadzoneVBoxContainer.visible = false

	if BuildCustomization.has_feature("force_xbox_controller_layout") or BuildCustomization.has_feature("force_ps_controller_layout") or BuildCustomization.has_feature("force_switch_controller_layout"):

		%IconSelectionLabel.visible = false
		%IconSelectionHBoxContainer.visible = false

	if BuildCustomization.has_feature("disable_input_rebinding"):
		%KeybindingsVBoxContainer.visible = false

	if BuildCustomization.has_feature("disable_multi"):
		%MultiplayerVBoxContainer.visible = false

	if BuildCustomization.has_feature("disable_allow_online_option"):
		%AllowTelemetryButton.visible = false

	if BuildCustomization.has_feature("enable_block"):
		%BlockListButton.visible = true

	showCategory(GameWorld.lastViewedOptionsCategory if GameWorld.lastViewedOptionsCategory else "Game")

	Style.init(self)

func showCategory(cat: String):
	GameWorld.lastViewedOptionsCategory = cat
	currentCategory = cat
	find_child(cat + "Category").visible = true
	var categoryButton = find_child(cat + "CategoryButton")
	categoryButton.button_pressed = true
	for c in categories:
		if c != cat:
			find_child(c + "Category").visible = false
	InputSystem.grabFocus(categoryButton)

func setFromOptions():
	find_child("MasterVolumeSlider").value = Options.masterVolume
	find_child("SoundVolumeSlider").value = Options.soundVolume
	find_child("AmbienceVolumeSlider").value = Options.ambienceVolume
	find_child("MusicVolumeSlider").value = Options.musicVolume
	find_child("MusicFrequencySlider").value = Options.cyclesWithoutMusic
	find_child("GamepadDeadZoneSlider").value = Options.gamepadStickDeadZone
	find_child("ButtonPhotoSensitivity").button_pressed = Options.photosensitive
	find_child("ButtonDisableCritters").button_pressed = Options.disableCritters
	find_child("AutoSwitchGamepadCheckBox").button_pressed = Options.tryAutoSwitchGamepad
	find_child("AutoPauseButton").button_pressed = Options.pauseWhenOutOfFocus
	find_child("EnableSeasonalEventButton").button_pressed = Options.enableSeasonalContent
	find_child("AllowTelemetryButton").button_pressed = Options.allowOnlineMultiplayer

	find_child("ButtonVsync").button_pressed = Options.vsync
	fullscreen = Options.fullscreen
	borderless = Options.borderless
	if fullscreen:
		find_child("ButtonFullscreen").button_pressed = true
		find_child("ButtonWindowed").button_pressed = false
		find_child("ButtonBorderless").button_pressed = false
	elif borderless:
		find_child("ButtonFullscreen").button_pressed = false
		find_child("ButtonBorderless").button_pressed = true
		find_child("ButtonWindowed").button_pressed = false
	else:
		find_child("ButtonFullscreen").button_pressed = false
		find_child("ButtonBorderless").button_pressed = false
		find_child("ButtonWindowed").button_pressed = true

	match Options.forcedGamepadType:
		"xbox": find_child("ButtonGamepadIconXbox").button_pressed = true
		"playstation": find_child("ButtonGamepadIconPlaystation").button_pressed = true
		"nintendo": find_child("ButtonGamepadIconNintendo").button_pressed = true
		_: find_child("ButtonGamepadIconAuto").button_pressed = true


	find_child("RenderscaleSlider").value = Options.renderScale
	find_child("ButtonRenderHalfRes").button_pressed = Options.renderHalfRes
	_on_renderscale_slider_value_changed(Options.renderScale)
	find_child("ButtonReducedParticles").button_pressed = Options.reducedParticles
	find_child("BrightnessSlider").value = Options.screenBrightness
	_on_BrightnessSlider_value_changed(Options.screenBrightness)
	find_child("ButtonVignette").button_pressed = Options.disableVignette
	find_child("ButtonBackgrounds").button_pressed = Options.disableWorldBackgrounds

	find_child("SystemCursorButton").button_pressed = Options.useSystemCursor
	InputSystem.useSystemCursor(Options.useSystemCursor)
	find_child("ShowKeeperNamesButton").button_pressed = Options.showPlayerNames
	find_child("ShowPlayerIndicatorsButton").button_pressed = Options.showPlayerIndicators
	_show_ping_button.button_pressed = Options.alwaysShowPing

	find_child("ShakeIntensitySlider").value = Options.shakeIntensity
	find_child("ShakeDrill").button_pressed = Options.shakeDrill
	find_child("VibrationIntensitySlider").value = Options.vibrationStrength

	find_child("ButtonHighlightedMonsters").button_pressed = Options.visibleMonsters

	%HideActionHints.button_pressed = Options.hideActionHints

	find_child("UseMouseDomeCheckbox").button_pressed = Options.useMouseDomeGameplay
	_on_UseMouseDomeCheckbox_toggled(Options.useMouseDomeGameplay)
	find_child("UseMouseMenuCheckbox").button_pressed = Options.useMouseMenus
	find_child("UseMouseSwordSliceCheckbox").button_pressed = Options.swordSliceWithMouse
	%SplitscreenLargeFont.button_pressed = Options.splitscreen_font_scale > Options.FONT_SCALE_DEFAULT

	if BuildCustomization.has_feature("enable_block"):
		BlockList.clear_pending_changes()

	readied = true


func _on_SystemCursorButton_pressed():
	Options.useSystemCursor = find_child("SystemCursorButton").button_pressed
	InputSystem.useSystemCursor(Options.useSystemCursor)

func _on_ButtonWindow_pressed() -> void :
	fullscreen = false
	borderless = false
	Audio.sound("gui_select")

func _on_ButtonBorderlessWindow_pressed():
	fullscreen = false
	borderless = true
	Audio.sound("gui_select")

func _on_ButtonFullscreen_pressed() -> void :
	fullscreen = true
	borderless = false
	Audio.sound("gui_select")

func _on_ButtonApply_pressed() -> void :
	Audio.sound("gui_apply")

	Options.fullscreen = fullscreen
	Options.borderless = borderless
	Options.screenBrightness = screenBrightness
	Options.disableVignette = find_child("ButtonVignette").button_pressed
	Options.disableWorldBackgrounds = find_child("ButtonBackgrounds").button_pressed
	Options.vsync = find_child("ButtonVsync").button_pressed
	Options.renderScale = find_child("RenderscaleSlider").value
	Options.renderHalfRes = find_child("ButtonRenderHalfRes").button_pressed
	Options.reducedParticles = find_child("ButtonReducedParticles").button_pressed
	Options.masterVolume = find_child("MasterVolumeSlider").value
	Options.soundVolume = find_child("SoundVolumeSlider").value
	Options.ambienceVolume = find_child("AmbienceVolumeSlider").value
	Options.musicVolume = find_child("MusicVolumeSlider").value
	Options.gamepadStickDeadZone = find_child("GamepadDeadZoneSlider").value
	Options.shakeIntensity = find_child("ShakeIntensitySlider").value
	Options.vibrationStrength = find_child("VibrationIntensitySlider").value
	Options.shakeDrill = find_child("ShakeDrill").button_pressed
	Options.photosensitive = find_child("ButtonPhotoSensitivity").button_pressed
	Options.disableCritters = find_child("ButtonDisableCritters").button_pressed
	Options.tryAutoSwitchGamepad = find_child("AutoSwitchGamepadCheckBox").button_pressed
	Options.enableSeasonalContent = find_child("EnableSeasonalEventButton").button_pressed
	Options.pauseWhenOutOfFocus = find_child("AutoPauseButton").button_pressed
	Options.allowOnlineMultiplayer = find_child("AllowTelemetryButton").button_pressed
	Options.useMouseDomeGameplay = find_child("UseMouseDomeCheckbox").button_pressed
	Options.useMouseMenus = find_child("UseMouseMenuCheckbox").button_pressed
	Options.swordSliceWithMouse = find_child("UseMouseSwordSliceCheckbox").button_pressed
	Options.hideActionHints = %HideActionHints.button_pressed
	Backend.updateEnableTracking()

	Options.onlineMultiplayerDecided = true
	Options.cyclesWithoutMusic = find_child("MusicFrequencySlider").value
	if find_child("ButtonGamepadIconXbox").button_pressed:
		Options.forcedGamepadType = "xbox"
	elif find_child("ButtonGamepadIconPlaystation").button_pressed:
		Options.forcedGamepadType = "playstation"
	elif find_child("ButtonGamepadIconNintendo").button_pressed:
		Options.forcedGamepadType = "nintendo"
	else:
		Options.forcedGamepadType = ""

	GameWorld.updateSeasonalEvents()

	Options.visibleMonsters = find_child("ButtonHighlightedMonsters").button_pressed

	Options.setFontScale(Options.FONT_SCALE_INCREASED if %SplitscreenLargeFont.button_pressed else Options.FONT_SCALE_DEFAULT)
	Options.saveOptions()
	if BuildCustomization.has_feature("enable_block"):
		BlockList.save_block_list()

	for l in get_tree().get_nodes_in_group("gamepadListeners"):
		l.onInputMethodChanged()

	emit_signal("close")

func _on_ButtonCancel_pressed() -> void :

	_on_BrightnessSlider_value_changed(Options.screenBrightness)
	Options.updateAudioBusses()
	Options.updateGraphicSettings()
	Audio.sound("gui_cancel")

func _on_MasterVolumeSlider_value_changed(value: float) -> void :






	if readied:
		Audio.sound("gui_slider")
	find_child("MasterVolumeLabel").text = "%.0f" % (10 * value)
	if value == 0:
		Audio.set_bus_volume(Audio.BUS_MASTER, -90)
	else:
		Audio.set_bus_volume(Audio.BUS_MASTER, (value * 24) - 24)

func _on_ShakeIntensitySlider_value_changed(value: float) -> void :
	if readied:
		Audio.sound("gui_slider")
	find_child("ShakeIntensityLabel").text = "%0.f%%" % (100 * value)

func _on_MusicVolumeSlider_value_changed(value: float) -> void :
	if readied:
		Audio.sound("gui_slider")
	find_child("MusicVolumeLabel").text = "%.0f" % (10 * value)
	if value == 0:
		Audio.set_bus_volume(Audio.BUS_MUSIC, -90)
	else:
		Audio.set_bus_volume(Audio.BUS_MUSIC, (value * 24) - 24)

func _on_SoundVolumeSlider_value_changed(value: float) -> void :
	if readied:
		Audio.sound("gui_slider")
	find_child("SoundVolumeLabel").text = "%.0f" % (10 * value)
	if value == 0:
		Audio.set_bus_volume(Audio.BUS_SOUNDS, -90)
	else:
		Audio.set_bus_volume(Audio.BUS_SOUNDS, (value * 24) - 24)

	if readied:
		$SoundExample.play()

func _on_AmbienceVolumeSlider_value_changed(value):
	if readied:
		Audio.sound("gui_slider")
	find_child("AmbienceVolumeLabel").text = "%.0f" % (10 * value)
	if value == 0:
		Audio.set_bus_volume(Audio.BUS_AMBIENCE, -90)
	else:
		Audio.set_bus_volume(Audio.BUS_AMBIENCE, (value * 24) - 24)

func _on_GamepadDeadZoneSlider_value_changed(value: float) -> void :
	if readied:
		Audio.sound("gui_slider")
	gamepadStickDeadZone = value
	find_child("GamepadDeadZoneLabel").text = "%.2f" % (value)

func _on_GamepadStickDeadZoneTimer_timeout() -> void :
	find_child("StickMoveRect").color = Style.STRUCT_DARK

func stick_move(event: InputEventJoypadMotion):
	if abs(event.axis_value) >= gamepadStickDeadZone:
		find_child("StickMoveRect").color = Style.LIVE
	else:
		$GamepadStickDeadZoneTimer.start()

func toggleButtonSound(button_pressed):
	if readied:
		Audio.sound("gui_toggle")

func _on_CategoryButton_pressed(cat):
	if readied:
		Audio.sound("gui_tab")
	showCategory(cat)

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

func _on_KeybindingsButton_pressed():
	Audio.sound("gui_select")
	var i = preload("res://content/shared/ControllerScrollInputProcessor.gd").new()
	i.deviceId = deviceId
	i.blockAllKeys = true
	i.globalInput = true
	i.popup = preload("res://systems/options/KeyBindingsPanel.tscn").instantiate()
	i.popup.deviceId = deviceId
	i.scrollTarget = i.popup.find_child("ScrollContainer").get_v_scroll_bar()
	i.popup.connect("quit", Callable(i, "desintegrate"))
	i.connect("stopping", Callable(i.popup, "queue_free"))
	i.connect("stopping", Callable(InputSystem, "grabFocus").bind(find_child("KeybindingsButton")))
	get_parent().add_child(i.popup)
	i.integrate(self)


func _on_button_renderscale_reset_pressed() -> void :
	find_child("RenderscaleSlider").value = 1.0


func _on_renderscale_slider_value_changed(value: float) -> void :
	%RenderscaleLabel.text = str(round(value * 100.0)) + "%"


func _on_BrightnessSlider_value_changed(value):
	Data.localEvent("options.screenbrightnesspreview", screenBrightness, value)
	screenBrightness = value
	%BrightnessLabel.text = str(screenBrightness).pad_decimals(2)


func _on_LanguageSelectButton_pressed():
	Audio.sound("gui_select")
	var i = preload("res://content/shared/ControllerScrollInputProcessor.gd").new()
	i.popup = preload("res://systems/options/LanguageSelectPanel.tscn").instantiate()
	i.scrollTarget = i.popup.find_child("ScrollContainer").get_v_scroll_bar()
	i.blockAllKeys = true
	i.blockStickMove = true
	i.globalInput = true
	i.deviceId = deviceId
	i.popup.connect("quit", Callable(i, "desintegrate"))
	i.connect("stopping", Callable(i.popup, "queue_free"))
	i.connect("stopping", Callable(InputSystem, "grabFocus").bind(find_child("LanguageSelectButton")))
	get_parent().add_child(i.popup)
	i.integrate(self)

func _on_ResetTutorialsButton_pressed():
	Audio.sound("gui_select")
	find_child("ResetTutorialsButton").disabled = true
	GameWorld.resetTutorials()

func playButtonSound():
	if readied:
		Audio.sound("gui_select")

func _on_UnlockEverythingButton_pressed():
	GameWorld.unlockEverything()

func _on_ResetProgressButton_pressed():
	GameWorld.unlockedElements.clear()
	GameWorld.unlockedSkins.clear()
	GameWorld.unlockedPets.clear()
	SaveGame.deleteAllMetaState()
	SaveGame.loadRollingMetaState()

func _on_ResetAchievementsButton_pressed():
	Achievements.clearCache()
	Platform.resetAllStatsAndAchievements()

func _on_VibrationIntensitySlider_value_changed(value):
	if readied:
		Audio.sound("gui_slider")
	find_child("VibrationIntensityLabel").text = "%0.f%%" % (100 * value)

func _on_MusicFrequencySlider_value_changed(value):
	if readied:
		Audio.sound("gui_slider")
	find_child("MusicFrequencyLabel").text = "%.0f" % (value)

func _on_TelemetryInfoButton_pressed():
	pass

func highlightTelemetryButton():
	var button = find_child("AllowTelemetryButton")
	for i in 6:
		$Tween.interpolate_property(button, "modulate", Color.WHITE, Color.WHITE * 2, 0.2, Tween.TRANS_QUAD, Tween.EASE_IN_OUT, 2 * i * 0.2)
		$Tween.interpolate_property(button, "modulate", Color.WHITE * 2, Color.WHITE, 0.2, Tween.TRANS_QUAD, Tween.EASE_IN_OUT, (2 * i + 1) * 0.2)
	$Tween.start()

func _on_ResetTelemetrySetting_pressed():
	Options.deleteOptions()

func _on_ButtonBrightnessReset_pressed():
	find_child("BrightnessSlider").value = 1.0

func _on_ButtonVignette_pressed():
	playButtonSound()
	if Level.stage:
		for keeper: Keeper in Keepers.local.getAll():
			var v: Vignette = Level.stage.getVignette(keeper)
			if v:
				v.visible = not find_child("ButtonVignette").button_pressed

func _on_SoundtrackButton_pressed():
	Audio.sound("gui_select")
	var i = preload("res://gui/PopupInput.gd").new()
	i.popup = preload("res://systems/options/SoundtrackPanel.tscn").instantiate()
	i.deviceId = deviceId
	i.globalInput = true
	i.blockAllKeys = true
	i.popup.connect("close", Callable(i, "desintegrate"))
	i.connect("stopping", Callable(i.popup, "queue_free"))
	i.connect("stopping", Callable(InputSystem, "grabFocus").bind(find_child("SoundtrackButton")))
	get_parent().add_child(i.popup)
	i.integrate(self)

func _on_UnlockAchievementsButton_pressed():
	for id in ["RELICHUNT_RELICTAKEN", "SHIELD_COMPLETE", "WORLD2_UNLOCK", 
	"WORLD3_UNLOCK", "WORLD4_UNLOCK", "WORLD5_UNLOCK", "DOME2_UNLOCK", 
	"RESOURCES_COBALTSTACK", "DRILLBERT_TREATS", "RELICHUNT_SPEEDY", 
	"PRESTIGE_MULTIPLIER", "PRESTIGE_WIN", "PRESTIGE_UNLOCK", "PRESTIGE_CHUNK", 
	"DOME_LOWHEALTH", "KEEPER_BOTTOM", "KEEPER_TIMELY", "KEEPER_MARATHON", 
	"KEEPER1_SHOPPINGBAG", "LIFT_JAM", "MINE_ALL", "RELICHUNT_BEATFINALE", 
	"RELICHUNT_MAPLARGE", "RELICHUNT_MAPMEDIUM", "RELICHUNT_MAPSMALL", 
	"REPELLENT_BIGDELAY", "SHIELD_STRONG", "BLASTMINING_USE", "PROBE_USE", 
	"CONDENSER_USE", "CONVERTER_USE", "REPELLENT_COMPLETE", "ORCHARD_COMPLETE", 
	"LIFT_TRANSPORT", "RUN_WINMANY", "RUN_LOSEMANY", "ORCHARD_LONG", 
	"RESOURCES_COBALTRESCUE", "PET_FOUND", "KEEPER1_SPEED", "KEEPER2_REFLECTIONS", 
	"KEEPER2_SPHEREDURATION", "KEEPER2_UNLOCK", "KEEPER2_BIGBUNDLE", 
	"KEEPER2_SPLITS", "KEEPER2_EXPLODE", "KEEPER2_AMMO"]:
		Achievements.triggerIfOpen(id)

func _on_UseMouseDomeCheckbox_toggled(button_pressed):
	find_child("UseMouseSwordSliceCheckbox").disabled = not button_pressed

func _on_show_keeper_names_button_pressed() -> void :
	Options.showPlayerNames = find_child("ShowKeeperNamesButton").button_pressed

func _on_show_player_indicators_button_pressed() -> void :
	Options.showPlayerIndicators = find_child("ShowPlayerIndicatorsButton").button_pressed

func _on_show_ping_button_pressed() -> void :
	Options.alwaysShowPing = _show_ping_button.button_pressed

func _on_open_keeper_input_settings_button_pressed(is_mouse: bool) -> void :
	Audio.sound("gui_select")
	var i = preload("res://systems/options/OptionsInputProcessor.gd").new()
	i.popup = preload("res://systems/options/KeeperInputSettingsPopup.tscn").instantiate()
	i.deviceId = deviceId
	i.globalInput = true
	i.blockAllKeys = true
	i.stickReceiver = self
	i.popup.setFromOptions(is_mouse)
	if Keepers.getLocalKeeperByDeviceId(deviceId):
		i.popup.showCategory(Keepers.getLocalKeeperByDeviceId(deviceId).techId.to_pascal_case())
	i.popup.connect("close", i.desintegrate)
	i.connect("stopping", i.popup.queue_free)
	var focus_target = "OpenMouseKeeperInputSettingsButton" if is_mouse else "OpenGamepadKeeperInputSettingsButton"
	i.connect("stopping", InputSystem.grabFocus.bind(find_child(focus_target)))
	get_parent().add_child(i.popup)
	i.integrate(self)


func _on_input_reset_button_pressed() -> void :
	find_child("UseMouseDomeCheckbox").button_pressed = Options.useMouseDomeGameplay
	_on_UseMouseDomeCheckbox_toggled(Options.useMouseDomeGameplay)
	find_child("UseMouseMenuCheckbox").button_pressed = Options.useMouseMenus
	find_child("UseMouseSwordSliceCheckbox").button_pressed = Options.swordSliceWithMouse

	for key in Options.keeperInputSettings:
		var split = key.split(".")
		var keeper_id = split[0]
		var for_mouse = split[1]
		var new_settings = KeeperInputSettings.new()
		new_settings.from_dict({}, for_mouse, keeper_id)
		Options.keeperInputSettings[key] = new_settings

func _on_splitscreen_large_font_toggled(toggled_on: bool) -> void :
	if readied:
		Audio.sound("gui_toggle")

func _on_block_list_button_pressed() -> void :
	Audio.sound("gui_select")
	var i = preload("res://content/shared/ControllerScrollInputProcessor.gd").new()
	i.popup = preload("res://systems/options/BlockListPanel.tscn").instantiate()
	i.scrollTarget = i.popup.find_child("BlockListScrollContainer").get_v_scroll_bar()
	i.blockAllKeys = true
	i.blockStickMove = true
	i.globalInput = true
	i.deviceId = deviceId
	i.popup.connect("quit", Callable(i, "desintegrate"))
	i.connect("stopping", Callable(i.popup, "queue_free"))
	i.connect("stopping", Callable(InputSystem, "grabFocus").bind(find_child("BlockListButton")))
	get_parent().add_child(i.popup)
	i.integrate(self)
