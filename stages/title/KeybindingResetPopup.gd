extends PanelContainer

signal confirmed

func _ready():
	Style.init(self)

func grabFocus():
	InputSystem.grabFocus($VBoxContainer / HBoxContainer / ButtonOk)

func moveOut():
	$Tween.interpolate_property(self, "position:y", position.y, get_viewport_rect().size.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	$Tween.interpolate_callback(self, 0.5, "queue_free")
	$Tween.start()

func _on_button_ok_pressed():
	confirmed.emit()
	moveOut()
