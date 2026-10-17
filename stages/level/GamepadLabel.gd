extends Label

func _process(delta):
	var linebreak: = false
	text = ""
	for i in Input.get_connected_joypads():
		text += Input.get_joy_name(i)
		if linebreak:
			text += "\n"
		else:
			linebreak = true
