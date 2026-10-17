extends PanelContainer

signal remove
signal selected
signal duplicate

var type: String = "connector"

func init(type):
	pass

func _on_WaveElement_mouse_entered():
	modulate = Style.FOCUS_MODULATE

func _on_WaveElement_mouse_exited():
	modulate = Color.WHITE

func _on_WaveElement_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.command_or_control_autoremap:
			emit_signal("duplicate", type, event.position)
		else:
			if event.button_index == 1:
				emit_signal("selected", type, event.position)
			elif event.button_index == 2:
				emit_signal("remove")

func enableMouse():
	mouse_filter = Control.MOUSE_FILTER_STOP

func disableMouse():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func showVariants():
	pass

func hideVariants():
	pass

func serialize() -> String:
	return "snippet"
