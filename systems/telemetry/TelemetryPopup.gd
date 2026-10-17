extends PanelContainer

signal enable_online
signal disable_online

func _ready():
	Style.init(self)
	InputSystem.grabFocus(find_child("ButtonAllow"))

func _on_ButtonOptions_pressed():
	emit_signal("disable_online")
	moveOut()

func _on_ButtonAllow_pressed():
	emit_signal("enable_online")
	moveOut()

func moveOut():
	$Tween.interpolate_property(self, "position:y", position.y, get_viewport_rect().size.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	$Tween.interpolate_callback(self, 0.5, "queue_free")
	$Tween.start()
