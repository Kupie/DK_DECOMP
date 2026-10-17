extends ColorRect

func _ready() -> void :
	StageManager.stage_started.connect(onStageStarted)
	Data.listen(self, "options.changed")
	Data.listen(self, "options.screenbrightnesspreview")


func onStageStarted():
	material.set_shader_parameter("gamma", Options.screenBrightness)

	if not Data.isListening(self, "options.changed"):
		Data.listen(self, "options.changed")
	if not Data.isListening(self, "options.screenbrightnesspreview"):
		Data.listen(self, "options.screenbrightnesspreview")

func propertyChanged(property: String, oldValue, newValue):
	match property:
		"options.changed":
			material.set_shader_parameter("gamma", Options.screenBrightness)
		"options.screenbrightnesspreview":
			material.set_shader_parameter("gamma", newValue)
