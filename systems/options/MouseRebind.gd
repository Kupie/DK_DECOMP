extends ColorRect

func _ready():
	set_process_unhandled_input(false)

func _gui_input(event):
	if event is InputEventMouseButton:
		InputSystem._unhandled_input(event)
