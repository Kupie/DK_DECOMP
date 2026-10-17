class_name CameraBase extends Camera2D

var camMovement: = Vector2()
var cameraRestPositionInDome: = Vector2(0, 0)
var baseOffset: = Vector2.ZERO

const SHAKE_NOISE_SCROLL_SPEED: float = 100.0
const SHAKE_CAMERA_MAX_OFFSET: float = 3.0

var shake_noise: FastNoiseLite
var shake_noise_offset: float = 0

var shake_strength: float = 0
var shake_duration: float = 0
var shake_duration_max: float = 0
var shake_frequency: float = 0

var target


func shake(strength: float, duration: = 0.2, period: = 16.0, pos: Vector2 = Vector2.INF):
	strength = strength / 100.0 * Options.shakeIntensity

	if is_instance_valid(target) and pos != Vector2.INF:

		strength *= 1.0 - clamp((pos.distance_to(target.global_position) - 100) / 500.0, 0.0, 1.0)

	if strength <= shake_strength:

		return

	shake_strength = max(shake_strength, strength)
	if shake_noise:



		var freq: float = 1.0 / period
		shake_noise.frequency = min(freq, 1)
	shake_duration = duration
	shake_duration_max = duration

	var low_strength: = minf(strength, 0.3)
	var high_strength: = clampf((strength - 0.3) * 1.5, 0.0, 1.0)

	if Options.singleplayerUseGamepad:
		Input.start_joy_vibration(0, clamp(low_strength * Options.vibrationStrength, 0.0, 1.0), clamp(high_strength * Options.vibrationStrength, 0.0, 1.0), duration * 0.6)

func getRelatedTeam() -> String:
	var isTargetAKeeper = target is Keeper and is_instance_valid(target)
	if isTargetAKeeper:
		var targetKeeper: Keeper = target as Keeper
		return targetKeeper.teamId
	return ""

func process_shake(delta: float):
	if shake_strength <= 0 or shake_duration <= 0:
		offset = baseOffset
		return

	shake_noise_offset += delta * SHAKE_NOISE_SCROLL_SPEED

	offset = (2 * shake_strength * SHAKE_CAMERA_MAX_OFFSET * Vector2(
		shake_noise.get_noise_2d(shake_noise_offset, 0), 
		shake_noise.get_noise_2d(0, shake_noise_offset)
	)) + baseOffset

	shake_duration -= delta

	var EASING_CURVE = 2.0
	shake_strength *= 1.0 - ease(1.0 - shake_duration / shake_duration_max, EASING_CURVE)

func getCameraRestPosition(zoomLevel: float) -> float:
	return 60 - 65 * (6 - zoomLevel)
