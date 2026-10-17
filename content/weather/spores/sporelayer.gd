extends GPUParticles2D

var teamId: String

func _ready():
	add_to_group(teamId + ".weather")
	Style.init(self)

func set_seed(_new_seed: int) -> void :
	pass

func start_weather(_inParentBackground: ParallaxBG):
	emitting = true

func stop():
	var t = DeprecatedTween.new()
	add_child(t)

	var start = modulate
	start.a = 1
	var end = modulate
	end.a = 0
	emitting = false
	t.interpolate_property(self, "modulate", start, end, 10.0)
	t.interpolate_callback(self, 10.0, "queue_free")
	t.start()
