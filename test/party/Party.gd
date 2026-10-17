extends Stage

var soundBusVolume
var isIn: = false

func beforeStart():
	soundBusVolume = Audio.get_bus_volume(Audio.BUS_SOUNDS)
	Audio.set_bus_volume(Audio.BUS_SOUNDS, -90)

	$Tween.interpolate_callback(self, 2.0, "set", "isIn", true)
	$Tween.start()

	Audio.startEnding()

func beforeEnd():
	Audio.stopMusic()
	Audio.set_bus_volume(Audio.BUS_SOUNDS, soundBusVolume)

func _process(delta):

	if isIn and Input.is_action_just_pressed("ui_select"):
		StageManager.startStage("stages/title/title")
