extends Label

func _ready():
	visible = false

func _process(delta):
	if Input.is_action_just_pressed("f3"):
		visible = not visible

	if visible:
		text = "%d" % Engine.get_frames_per_second()
