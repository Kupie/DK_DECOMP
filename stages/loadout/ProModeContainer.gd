extends PanelContainer

var deviceId: int = -1

func _ready():
	Style.init(self)
	InputSystem.grabFocus(find_child("CancelButton"))
	updateOrderLabels()

func _on_prestige_mode_gadget_order_button_pressed():
	Audio.sound("gui_confirm")
	Audio.ignoreNextHover()
	var i = preload("res://content/shared/ControllerScrollInputProcessor.gd").new()
	i.deviceId = deviceId
	i.blockAllKeys = true
	i.globalInput = true
	i.blockStickMove = true
	i.popup = preload("res://stages/loadout/GadgetOrderPopup.tscn").instantiate()
	i.scrollTarget = i.popup.find_child("ScrollContainer").get_v_scroll_bar()
	i.popup.connect("close", Callable(i, "desintegrate"))
	i.connect("onStop", Callable(InputSystem, "grabFocus").bind(find_child("PrestigeModeGadgetOrderButton")))
	i.connect("onStop", Callable(i.popup, "_close"))
	i.connect("onStop", Callable(self, "updateOrderLabels"))
	get_parent().add_child(i.popup)
	i.popup.open()
	i.integrate(StageManager.currentStage)

func _on_prestige_mode_cave_order_button_pressed():
	Audio.sound("gui_confirm")
	Audio.ignoreNextHover()
	var i = preload("res://content/shared/ControllerScrollInputProcessor.gd").new()
	i.deviceId = deviceId
	i.blockAllKeys = true
	i.globalInput = true
	i.blockStickMove = true
	i.popup = preload("res://stages/loadout/CaveOrderPopup.tscn").instantiate()
	i.scrollTarget = i.popup.find_child("ScrollContainer").get_v_scroll_bar()
	i.popup.connect("close", Callable(i, "desintegrate"))
	i.connect("onStop", Callable(InputSystem, "grabFocus").bind(find_child("PrestigeModeCaveOrderButton")))
	i.connect("onStop", Callable(i.popup, "_close"))
	i.connect("onStop", Callable(self, "updateOrderLabels"))
	get_parent().add_child(i.popup)
	i.popup.open()
	i.integrate(StageManager.currentStage)

func _on_prestige_mode_supplement_order_button_pressed():
	Audio.sound("gui_confirm")
	Audio.ignoreNextHover()
	var i = preload("res://content/shared/ControllerScrollInputProcessor.gd").new()
	i.deviceId = deviceId
	i.blockAllKeys = true
	i.globalInput = true
	i.blockStickMove = true
	i.popup = preload("res://stages/loadout/SupplementOrderPopup.tscn").instantiate()
	i.scrollTarget = i.popup.find_child("ScrollContainer").get_v_scroll_bar()
	i.popup.connect("close", Callable(i, "desintegrate"))
	i.connect("onStop", Callable(InputSystem, "grabFocus").bind(find_child("PrestigeModeSupplementOrderButton")))
	i.connect("onStop", Callable(i.popup, "_close"))
	i.connect("onStop", Callable(self, "updateOrderLabels"))
	get_parent().add_child(i.popup)
	i.popup.open()
	i.integrate(StageManager.currentStage)

func updateOrderLabels():
	if GameWorld.useCustomCaveOrderSetting:
		find_child("LabelCaveOrder").text = tr("loadout.prestige.pro.customorder")
	else:
		find_child("LabelCaveOrder").text = tr("loadout.prestige.pro.randomorder")

	if GameWorld.useCustomGadgetOrderSetting:
		find_child("LabelGadgetOrder").text = tr("loadout.prestige.pro.customorder")
	else:
		find_child("LabelGadgetOrder").text = tr("loadout.prestige.pro.randomorder")

	if GameWorld.useCustomSupplementOrderSetting:
		find_child("LabelSupplementOrder").text = tr("loadout.prestige.pro.customorder")
	else:
		find_child("LabelSupplementOrder").text = tr("loadout.prestige.pro.randomorder")
