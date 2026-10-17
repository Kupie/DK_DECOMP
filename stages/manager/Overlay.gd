extends ColorRect

var tween: Tween

func fadeInCallback(fadeTime: float, callback: Callable):
	if is_instance_valid(tween):
		tween.kill()

	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "color", Color(0, 0, 0, 0), fadeTime)
	tween.tween_callback(callback)

func fadeOutCallback(fadeTime: float, callback: Callable):
	if is_instance_valid(tween):
		tween.kill()

	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "color", Color.BLACK, fadeTime)
	tween.tween_callback(callback)


func setClear():
	self.color = Color(0, 0, 0, 0)

func setOpaque():
	self.color = Color(0, 0, 0, 1)
