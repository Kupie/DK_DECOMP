extends Control

var isIn: = false

func _ready():
	visible = true
	position.y -= size.y

func moveIn():
	if isIn:
		return

	isIn = true
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property(self, "position:y", position.y, 5.0, 0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	$Tween.start()

func moveOut():
	if not isIn:
		return

	isIn = false
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property(self, "position:y", position.y, - size.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	$Tween.start()

func pauseChanged():
	if GameWorld.paused:
		moveIn()
	else:
		moveOut()
