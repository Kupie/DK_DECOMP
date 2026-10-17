extends Stage

func beforeStart():
	Style.init(self)
	GameWorld.setShowMouse(true)
	InputSystem.grabFocus($CanvasLayer / PanelContainer / MarginContainer / VBoxContainer / Button)

func _on_Button_pressed():
	StageManager.startStage("stages/title/title")
