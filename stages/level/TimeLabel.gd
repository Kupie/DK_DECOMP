extends Label

var minutes: = 0
var seconds: = 0.0

func _process(delta):
	seconds += delta
	if seconds >= 60.0:
		seconds -= 60.0
		minutes += 1
	text = "%.0f:%.0f" % [minutes, clamp(seconds, 0, 59)]
