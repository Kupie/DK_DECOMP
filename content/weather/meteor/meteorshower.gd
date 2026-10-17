extends Sprite2D

const Meteor = preload("res://content/weather/meteor/meteor.tscn")

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

func _on_meteorTimer_timeout():
	$meteorTimer.wait_time = randf_range(0.5, 1.5)
	$meteorTimer.start()
	var m = Meteor.instantiate()
	add_child(m)
	m.initialize(rand, teamId)

func get_weather_slot() -> String:
	return teamId + "-weather-meteor"

func start_weather(_inParentBackground: ParallaxBG):
	pass

func stop():
	var t = DeprecatedTween.new()
	add_child(t)

	$meteorTimer.stop()
	t.interpolate_callback(self, 3.0, "queue_free")
	t.start()

func pauseChanged():
	$meteorTimer.paused = GameWorld.paused
