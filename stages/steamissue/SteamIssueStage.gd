extends Stage

func build(data: Array):
	Style.init($CanvasLayer / PanelContainer)
	InputSystem.grabFocus(find_child("Button"))

	if data.size() > 0:
		find_child("LabelError").text = "Error: " + str(data[0])

func _on_button_pressed() -> void :
	get_tree().quit()

var count: = 0
func _process(delta: float) -> void :
	if Input.is_action_just_pressed("cheats"):
		count += 1

	if count == 4:
		StageManager.startStage("stages/title/title")
		return
