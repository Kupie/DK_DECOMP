extends Sprite2D

@onready var dust1 = $Dust1
@onready var dust2 = $Dust2
@onready var tornado = $Tornado
var direction = 1
var change_direction = 0.0

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
	return teamId + "-weather-windstorm"

func start_weather(inParentBackground: ParallaxBG):
	var t = DeprecatedTween.new()
	add_child(t)
	var start = modulate
	start.a = 0
	var end = modulate
	end.a = 1
	$WindSound.baseVolume = -40
	$WindSound.startSound()
	t.interpolate_property(self, "modulate", start, end, 3.0)
	t.interpolate_property(dust1, "modulate", start, end, 3.0)
	t.interpolate_property(dust2, "modulate", start, end, 3.0)
	tornado.self_modulate = start
	t.interpolate_property(tornado, "self_modulate", start, end, 3.0, Tween.TRANS_CUBIC, Tween.EASE_IN, 2.0)
	t.interpolate_property($WindSound, "baseVolume", $WindSound.baseVolume, 0, 3.0)
	t.interpolate_callback(t, 10.0, "queue_free")
	t.start()

	var farSlot: String = teamId + "-weather-windstormfar"
	var slotExists: bool = inParentBackground.hasWeatherSlot(farSlot)
	if slotExists:
		remove_child(dust2)
		inParentBackground.addWeatherEffectUnderSlot(dust2, farSlot)
		remove_child(tornado)
		inParentBackground.addWeatherEffectUnderSlot(tornado, farSlot)

func stop():
	var t = DeprecatedTween.new()
	add_child(t)

	var start = modulate
	start.a = 1
	var end = modulate
	end.a = 0
	t.interpolate_property(self, "modulate", start, end, 3.0)
	t.interpolate_property(dust1, "modulate", start, end, 3.0)
	t.interpolate_property(dust2, "modulate", start, end, 3.0)
	tornado.emitting = false
	t.interpolate_property($WindSound, "baseVolume", 0, -40, 3.0)
	t.interpolate_callback(self, 3.0, "queue_free")
	t.start()

func _process(delta):
	dust1.region_rect.position.x -= 2000 * delta
	dust1.region_rect.position.y = 0

	dust2.region_rect.position.x -= 500 * delta
	dust2.region_rect.position.y = 0

	change_direction -= delta
	if change_direction <= 0:
		change_direction = 3
		if rand.randf() < 0.5:
			direction = 1
		else:
			direction = -1
		if tornado.position.x > 200:
			direction = -1
		elif tornado.position.x < -200:
			direction = 1
	tornado.position.x += direction * 20 * delta
	tornado.position.x += sin(Time.get_ticks_msec() / 290.0) + sin(Time.get_ticks_msec() / 130.0)

func pauseChanged():
	if GameWorld.paused:
		for c in get_children():
			if c is DeprecatedTween:
				c.stop_all()
	else:
		for c in get_children():
			if c is DeprecatedTween:
				c.resume_all()
