extends Node2D

var teamId: String

@export
var wind_dir: FastNoiseLite
@export
var wind_dir2: FastNoiseLite

@onready var particle_mat: ParticleProcessMaterial = $ParticlesSmoke.process_material

var prev_emission: = DEFAULT_EMISSION

const DEFAULT_EMISSION: = 0.2

func _ready():
	Style.init(self)
	$ParticlesSmoke.emitting = true
	$SmokeSound.startSound()
	$ParticlesSmoke.amount_ratio = 0.2

	Data.listen(self, teamId + ".furnace.isburningiron", true)
	Data.listen(self, teamId + ".furnace.isburningwater", true)
	particle_mat.color = Color.BLACK
	$SpriteBack.stop()

func update_emission():
	var emission = DEFAULT_EMISSION
	if $Spriteiron.visible:
		emission += 0.4
	if $Spritewater.visible:
		emission += 0.4
	$ParticlesSmoke.amount_ratio = emission


	if prev_emission == DEFAULT_EMISSION and emission != DEFAULT_EMISSION:
		$IgniteSound.startSound()
		$SpriteBack.play()


	if prev_emission != DEFAULT_EMISSION and emission == DEFAULT_EMISSION:
		$ExtinguishSound.startSound()
		$SpriteBack.pause()

	$SpriteBack.speed_scale = 1.0 if emission < 1.0 else 1.5
	prev_emission = emission

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".furnace.isburningiron":
		$Spriteiron.visible = newValue
		$Particles_ExpIron.emitting = newValue
		update_emission()

		if newValue != $FireLoopSound.playing:
			if newValue:
				$FireLoopSound.startSound()
			else:
				$FireLoopSound.stop()

		if newValue:
			$Spriteiron.scale *= 0
			create_tween().tween_property($Spriteiron, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_delay(0.3)
	if property == teamId + ".furnace.isburningwater":
		$Spritewater.visible = newValue
		$Particles_ExpWater.emitting = newValue
		update_emission()

		if newValue != $WaterLoopSound.playing:
			if newValue:
				$WaterLoopSound.startSound()
			else:
				$WaterLoopSound.stop()

		if newValue:
			$Spritewater.scale *= 0
			create_tween().tween_property($Spritewater, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_delay(0.3)

func _process(delta: float) -> void :
	if randf() > 0.8:
		$Spriteiron.offset.x = randi_range(0, 1)
	if randf() > 0.8:
		$Spriteiron.offset.y = randi_range(0, 1)
	if randf() > 0.8:
		$Spritewater.offset.x = randi_range(0, 1)
	if randf() > 0.8:
		$Spritewater.offset.y = randi_range(0, 1)

	var wind = wind_dir.get_noise_1d(Time.get_ticks_msec() * 0.001) * 50.0
	wind += wind_dir2.get_noise_1d(Time.get_ticks_msec() * 0.002) * 25.0
	particle_mat.gravity.x = wind
