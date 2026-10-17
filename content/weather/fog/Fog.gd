extends Node2D

var FogLayer = preload("res://content/weather/fog/FogLayer.tscn")

var teamId: String

var rand: RandomNumberGenerator

func _ready():
	add_to_group(teamId + ".weather")
	Style.init(self)

func set_seed(new_seed: int) -> void :
	rand = RandomNumberGenerator.new()
	rand.seed = new_seed

func disableSounds():
	for child in get_children():
		if child is Sound:
			child.prohibitStart()
			child.autoplay = false

func get_weather_slot() -> String:
	return teamId + "-weather-fognear"

func start_weather(inParentBackground: ParallaxBG):
	var fog_instances = 0
	var direction: Vector2

	match rand.randi() % 3:
		0:
			direction = Vector2.UP
		1:
			direction = Vector2.RIGHT
		2:
			direction = Vector2.LEFT


	var fog_speed = rand.randf_range(10, 40)

	var nearSlot: String = get_weather_slot()
	var hasNearSlot: bool = inParentBackground.hasWeatherSlot(nearSlot)
	if hasNearSlot:
		var fog = FogLayer.instantiate()
		fog.set_meta("resource_path", get_meta("resource_path"))
		fog.direction = direction
		fog.teamId = teamId
		fog.speed = fog_speed
		inParentBackground.addWeatherEffectUnderSlot(fog, nearSlot)
		fog_instances += 1


	var farSlot: String = teamId + "-weather-fogfar"
	var hasFarSlot: bool = inParentBackground.hasWeatherSlot(farSlot)
	if hasFarSlot:
		var fog = FogLayer.instantiate()
		fog.set_meta("resource_path", get_meta("resource_path"))
		fog.direction = direction
		fog.teamId = teamId
		fog.speed = fog_speed / 2.0
		inParentBackground.addWeatherEffectUnderSlot(fog, farSlot)
		fog_instances += 1

	if fog_instances == 0:
		queue_free()

func stop():
	queue_free()
