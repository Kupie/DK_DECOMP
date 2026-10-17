class_name WeatherSystem
extends Node2D

var teamId: String

@export var enabled: = false
@export var ClearPercentage: int = 50
@export var Lightning: bool = true
@export var Fog: bool = true
@export var Rain: bool = true
@export var Snow: bool = true
@export var Meteors: bool = true
@export var Spores: bool = true

@onready var synchronizer: Synchronizer = $Synchronizer

var WEATHER = [
	[preload("res://content/weather/lightning/LightningStorm.tscn")], 
	[preload("res://content/weather/fog/Fog.tscn")], 
	[preload("res://content/weather/rain/Rain.tscn")], 
	[preload("res://content/weather/rain/Rain.tscn"), preload("res://content/weather/lightning/LightningStorm.tscn")], 
	[preload("res://content/weather/snow/Snow.tscn")], 
	[preload("res://content/weather/meteor/meteorshower.tscn")], 
	[preload("res://content/weather/spores/spores.tscn")], 
	[preload("res://content/weather/windstorm/windstorm.tscn")], 
	[preload("res://content/weather/acid_rain/AcidRain.tscn")], 
]

func _ready():
	if not enabled:
		queue_free()

	if Data.has("world.initialweatherchangeseconds"):
		get_tree().create_timer(Data.of("world.initialweatherchangeseconds")).timeout.connect(_on_changeWeatherTimer_timeout)

func get_potential_weathers() -> Array[int]:
	var weathers: Array[int] = []

	var foreced_weather_id: int = Data.ofOr("world.forcedWeatherId", -1)
	if foreced_weather_id >= 0:
		weathers.append(foreced_weather_id)
		return weathers

	if randf() <= float(ClearPercentage) / 100.0:
		return weathers

	if Lightning:
		weathers.append(0)

	if Fog:
		weathers.append(1)

	if Rain and not GameWorld.isChristmas:
		weathers.append(2)
		if Lightning:
			weathers.append(3)

	if Snow or GameWorld.isChristmas:
		weathers.append(4)

	if Meteors:
		weathers.append(5)

	if Spores:
		weathers.append(6)

	return weathers

func _on_changeWeatherTimer_timeout():
	if not enabled or not multiplayer.is_server():
		return

	var potential_weathers = get_potential_weathers()
	var weather_index: int = -1
	if not potential_weathers.is_empty():
		weather_index = potential_weathers.pick_random()

	synchronizer.network_rpc(update_weather.bind(weather_index, randi()), true)

@rpc("reliable")
func update_weather(weather_index: int, weather_seed: int):
	var current_weathers = get_tree().get_nodes_in_group(teamId + ".weather")
	var weathers_to_clear: = current_weathers.duplicate()
	var weathers_to_spawn: = []

	var weathers: Array = WEATHER[weather_index] if weather_index >= 0 else []
	for new_weather in weathers:
		var already_present: = false
		for w in current_weathers:
			if is_instance_valid(w) and w.has_method("stop"):
				if w.get_meta("resource_path") == new_weather.resource_path:
					weathers_to_clear.erase(w)
					already_present = true
					w.set_seed(weather_seed)
		if not already_present:
			weathers_to_spawn.append(new_weather)

	var backgrounds: Array = get_tree().get_nodes_in_group("ParallaxBG")
	for background in backgrounds:
		var add_other_team_weather: bool = true
		if not add_other_team_weather:
			if not background.isRelatedToTeam(teamId):
				continue

		for weather in weathers_to_spawn:
			var w = weather.instantiate()
			w.teamId = teamId
			w.set_meta("resource_path", weather.resource_path)
			w.set_seed(weather_seed)
			var wslot = w.get_weather_slot()
			if not background._isPrototype and background.hasWeatherSlot(wslot):
				background.addWeatherEffectUnderSlot(w, wslot)

	for weather in weathers_to_clear:
		weather.stop()


func pauseChanged():
	$changeWeatherTimer.paused = GameWorld.paused
