extends CanvasLayer

var messages: PackedStringArray = []

func msg(t: String):
	messages.append(t)
	if messages.size() > 5:
		messages.remove_at(0)
	var string = "\n".join(messages)
	$"%Output".text = string
