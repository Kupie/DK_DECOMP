extends Sprite2D
class_name AcidRain

var teamId: String
const DAMAGE_SOURCE = "ACID_RAIN"

func calculate_damage(team_id: String, max_dome_health: int):
	var damage_per_minute: float = Data.ofOr(team_id + ".acidrain.fixedDamagePerMinute", 58.0)
	var damage_per_second: float = damage_per_minute / 60
	Data.apply(team_id + ".acidrain.damage", damage_per_second)

func _ready():
	if not Data.has(teamId + ".acidrain.damage"):
		calculate_damage(teamId, Data.of(teamId + ".dome.maxHealth"))

	Data.listen(self, "game.over")
	add_to_group(teamId + ".weather")
	%Timer.timeout.connect(applyDamage)

func set_seed(_new_seed: int) -> void :
	pass

func disableSounds():
	for child in get_children():
		if child is Sound:
			child.prohibitStart()
			child.autoplay = false

func get_weather_slot() -> String:
	return teamId + "-weather-rain"

func start_weather(_inParentBackground: ParallaxBG):
	var t = DeprecatedTween.new()
	add_child(t)
	var start = modulate
	start.a = 0
	var end = modulate
	end.a = 1
	$RainSound.baseVolume = -40
	$RainSound.startSound()
	t.interpolate_property(self, "modulate", start, end, 10.0)
	t.interpolate_property($RainSound, "baseVolume", $RainSound.baseVolume, 0, 10.0)
	t.interpolate_callback(t, 10.0, "queue_free")
	t.start()
	%Timer.start()

func stop():
	var t = DeprecatedTween.new()
	add_child(t)

	var start = modulate
	start.a = 1
	var end = modulate
	end.a = 0
	t.interpolate_property(self, "modulate", start, end, 3.0)
	t.interpolate_property($RainSound, "baseVolume", 0, -40, 3.0)
	t.interpolate_callback(self, 3.0, "queue_free")
	t.start()
	%Timer.stop()

func applyDamage():
	if multiplayer.is_server():
		var dome = Level.domesByTeamId[teamId]
		var damage_per_second = Data.ofOr(teamId + ".acidrain.damage", 1)
		dome.requestEnvironmentalDamage(damage_per_second * %Timer.wait_time, DAMAGE_SOURCE, dome.position)
	%AcidSplashSound.startSound()

func pauseChanged():
	if GameWorld.paused:
		for c in get_children():
			if c is DeprecatedTween:
				c.stop_all()
		%Timer.paused = true
	else:
		for c in get_children():
			if c is DeprecatedTween:
				c.resume_all()
		%Timer.paused = false


func propertyChanged(property: String, oldValue, newValue):
	if property == "game.over":
		%Timer.stop()
