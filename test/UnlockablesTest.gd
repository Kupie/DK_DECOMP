extends Control

func _ready():
	GameWorld.unlockableElements.clear()
	GameWorld.unlockedElements.clear()
	GameWorld.unlockableElements.append("repellent")
	GameWorld.unlockableElements.append(CONST.MODE_PRESTIGE)
	GameWorld.unlockableElements.append("shield-battle2")

	Audio.sound("gui_select")
	var i = preload("res://gui/PopupInput.gd").new()
	var unlockablesPopup = preload("res://content/gamemode/unlockables/UnlockablesPopup.tscn").instantiate()
	unlockablesPopup.connect("proceed", Callable(i, "desintegrate"))
	unlockablesPopup.connect("back", Callable(i, "desintegrate"))
	unlockablesPopup.connect("back", Callable(self, "updateFocus"))
	unlockablesPopup.connect("back", Callable(unlockablesPopup, "queue_free"))
	add_child(unlockablesPopup)
	i.popup = unlockablesPopup
	i.integrate(self)
	i.handleStart()


func _on_PaletteTimer_timeout():
	var palettes: Array = Data.gameProperties.get("palettes.world" + str(randi() % 5 + 1))
	Style.setPalette(str(palettes[randi() % palettes.size()]))
