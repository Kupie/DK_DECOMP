extends Stage

func _ready():
	GameWorld.setShowMouse(true)
	InputSystem.grabFocus( %Button)
	Style.init(self)

func _on_Button_pressed():
	if BuildCustomization.has_feature("disable_quit_on_save_error"):
		StageManager.startStage("stages/title/title")
		return
	get_tree().quit()
