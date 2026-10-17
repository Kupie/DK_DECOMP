extends CanvasLayer

var scaling: = 1.0

func _ready():
	Style.init(self)

	if GameWorld.buildType == CONST.BUILD_TYPE.PLAYTEST:
		%NoStreamContainer.visible = true
		%NoStreamLabel.text += " " + Platform.get_username() + "."
	else:
		%NoStreamContainer.visible = false

	_on_size_probe_resized.call_deferred()

func _on_size_probe_resized() -> void :
	$AreaLimiter.scale = scaling * Vector2.ONE
	$AreaLimiter.size = $SizeProbe.size / scaling

func add_popup(popup):
	$AreaLimiter.add_child(popup)
