extends Sprite2D

var SporeLayer = load("res://content/weather/spores/sporelayer.tscn")

var teamId: String

func _ready():
	add_to_group(teamId + ".weather")
	Style.init(self)

func set_seed(_new_seed: int) -> void :
	pass

func disableSounds():
	for child in get_children():
		if child is Sound:
			child.prohibitStart()
			child.autoplay = false

func get_weather_slot() -> String:
	return teamId + "-weather-spores"

func start_weather(inParentBackground: ParallaxBG):

	var has_slot: bool = inParentBackground.hasWeatherSlot(get_weather_slot())
	if has_slot:
		inParentBackground.addWeatherEffectToEverySlot(spore_constuctor, get_weather_slot())
	else:
		queue_free()

func spore_constuctor() -> Node:
	var spores = SporeLayer.instantiate()
	spores.set_meta("resource_path", get_meta("resource_path"))
	spores.teamId = teamId
	return spores

func stop():
	var t = DeprecatedTween.new()
	add_child(t)

	var start = modulate
	start.a = 1
	var end = modulate
	end.a = 0
	t.interpolate_property(self, "modulate", start, end, 3.0)
	t.interpolate_callback(self, 3.0, "queue_free")
	t.start()

func pauseChanged():
	if GameWorld.paused:
		for c in get_children():
			if c is DeprecatedTween:
				c.stop_all()
	else:
		for c in get_children():
			if c is DeprecatedTween:
				c.resume_all()
