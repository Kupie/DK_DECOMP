extends AnimatedSprite2D

func _ready():
	Style.init(self)
	var tw = create_tween()
	$smoke.global_rotation = 0
	tw.tween_callback( func():
		$smoke.frame = 0
		$smoke.play()
		$smoke.animation_finished.connect(queue_free)
		).set_delay(0.2)

func setup(big):
	rotate(PI * 0.5)

	play("big" if big else "small")
