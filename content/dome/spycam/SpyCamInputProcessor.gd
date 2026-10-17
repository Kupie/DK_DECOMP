extends InputProcessor

var teamId: String

var station
var keeper
var popup

func _ready():
	stopSuccessors = false

func handleStart():
	station.transitionToDome(keeper)
	var t: = create_tween()
	popup.modulate.a = 0.0
	t.tween_property(popup, "modulate:a", 1.0, 0.2).set_delay(2.0)

func handleStop():
	var t = popup.create_tween()
	t.tween_property(popup, "modulate:a", 0.0, 0.2)
	t.tween_callback(popup.queue_free).set_delay(0.31)
	keeper.exitStation()
	station.exitStation()

func buttonEvent(event) -> bool:
	if justPressed(event, "ui_cancel"):
		Audio.sound("gui_cancel")
		desintegrate()
	elif justPressed(event, "escape"):
		return false
	elif justPressed(event, "cheats"):

		return false
	elif justPressed(event, "escape"):
		return false

	return true
