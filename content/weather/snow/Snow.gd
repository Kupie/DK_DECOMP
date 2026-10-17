extends Sprite2D

@export var noise: FastNoiseLite
@export var snow_particle_mat: Material

enum {STARTING, RUNNING, ENDING}
var state = STARTING

var teamId: String

var far_snow = null
var far_bg = null
var noise_seed_set: bool = false
var time: = 0.0

func _ready():
	add_to_group(teamId + ".weather")
	Style.init(self)
	var dome_pos: Vector2 = Utils.get_dome_position(teamId)
	$Snow.process_material = snow_particle_mat.duplicate()
	$Snow.process_material.set_shader_parameter("spawn_x_start", dome_pos.x)

func set_seed(new_seed: int) -> void :
	if not noise_seed_set:
		noise.seed = new_seed

func get_weather_slot() -> String:
	return teamId + "-weather-rain"

func disableSounds():
	for child in get_children():
		if child is Sound:
			child.prohibitStart()
			child.autoplay = false

func _process(delta):
	if GameWorld.paused:
		return
	time += delta
	$Snow.process_material.set_shader_parameter("wind", Vector3(-30.0 - noise.get_noise_1d(time * 5.0) * 20.0, 0, 0))
	far_snow.process_material.set_shader_parameter("wind", Vector3(-45.0 - noise.get_noise_1d(time * 5.0) * 20.0, 0, 0))

func freeze(v):
	var mat: ShaderMaterial = $ice / overlay.material
	mat.set_shader_parameter("strength", v)

func start_weather(inParentBackground: ParallaxBG):
	state = STARTING

	var start = modulate
	start.a = 0.0
	var end = modulate
	end.a = 1

	var dome_pos: Vector2 = Utils.get_dome_position(teamId)
	var farSlot: String = teamId + "-weather-snowfar"
	var slotExists: bool = inParentBackground.hasWeatherSlot(farSlot)
	if slotExists:
		far_snow = $Snow.duplicate()


		far_snow.process_material = snow_particle_mat.duplicate()
		(far_snow.process_material as ShaderMaterial).set_shader_parameter("scale", 0.5)
		(far_snow.process_material as ShaderMaterial).set_shader_parameter("spawn_x_start", dome_pos.x)
		inParentBackground.addWeatherEffectUnderSlot(far_snow, farSlot)
		$Tween.interpolate_property(far_snow, "modulate", start, end, 10.0)

		far_bg = $ColorRect.duplicate()
		far_bg.modulate.a = 0.5
		inParentBackground.addWeatherEffectUnderSlot(far_bg, farSlot)
		$Tween.interpolate_property(far_bg, "modulate", start, end, 10.0)

	$Tween.interpolate_property(self, "modulate", start, end, 10.0)
	$Tween.interpolate_property($SnowSound, "baseVolume", -30, 0, 10.0)
	$Tween.interpolate_callback(self, 10.0, "started")
	$Tween.start()
	$ice / overlay.modulate.a = 0

func started():
	state = RUNNING

func stop():
	state = ENDING
	var start = modulate
	var end = modulate
	end.a = 0
	$Tween.interpolate_property(self, "modulate", start, end, 3.0)
	$Tween.interpolate_property($SnowSound, "baseVolume", 0, -40, 3.0)
	$Tween.interpolate_callback(self, 3.0, "queue_free")
	if far_snow:
		$Tween.interpolate_property(far_snow, "modulate", start, end, 3.0)
		$Tween.interpolate_callback(far_snow, 3.0, "queue_free")
	if far_bg:
		$Tween.interpolate_property(far_bg, "modulate", start, end, 3.0)
		$Tween.interpolate_callback(far_bg, 3.0, "queue_free")
	$Tween.start()






func pauseChanged():
	if GameWorld.paused:
		$Tween.stop_all()
	else:
		$Tween.resume_all()
