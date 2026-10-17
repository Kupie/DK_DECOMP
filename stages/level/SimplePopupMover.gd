extends Container

var isIn: = false

func _ready():
	position.y += size.y

func moveIn(moveOutAfter: = 0.0):
	if isIn:
		return

	visible = true
	isIn = true
	if moveOutAfter > 0.0:
		$Tween.interpolate_callback(self, moveOutAfter, "moveOut")

	$Tween.interpolate_property(self, "position:y", position.y, get_parent().size.y - size.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT, 2.0)
	$Tween.start()

func moveOut():
	if not isIn:
		return

	isIn = false
	$Tween.interpolate_property(self, "position:y", position.y, get_parent().size.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	$Tween.interpolate_callback(self, 0.5, "queue_free")
	$Tween.start()
