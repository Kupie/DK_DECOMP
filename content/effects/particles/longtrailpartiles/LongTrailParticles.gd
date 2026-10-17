class_name LongTrailParticles extends GPUParticles2D




const MARGIN: float = remap(MEASURE_FREQUENCY, 0.1, 1.0, 20.0, 150.0)
const MEASURE_FREQUENCY: float = 0.5

var _time_since_last_measurement: float = 0.0
var _max_measurements: int
var _particle_lifetime_positions: = PackedVector2Array()
var _last_measurement_idx: int = 0

func _ready() -> void :
	_max_measurements = ceil(lifetime / MEASURE_FREQUENCY)
	for i in _max_measurements:
		_particle_lifetime_positions.append(Vector2.ZERO)

func _process(delta: float) -> void :
	_time_since_last_measurement += delta
	if _time_since_last_measurement < MEASURE_FREQUENCY:
		return

	var visibilityRectGlobal: Rect2 = Rect2(global_position, Vector2.ZERO)
	for measurement: Vector2 in _particle_lifetime_positions:
		visibilityRectGlobal = visibilityRectGlobal.expand(measurement)

	var local_rect: Rect2 = _convert_global_rect_to_local(visibilityRectGlobal)
	visibility_rect = local_rect.grow(MARGIN)

	_time_since_last_measurement = 0.0
	_last_measurement_idx = (_last_measurement_idx + 1) % _max_measurements
	_particle_lifetime_positions[_last_measurement_idx] = global_position

func _convert_global_rect_to_local(in_global_rect: Rect2) -> Rect2:
	var p0: Vector2 = to_local(in_global_rect.position)
	var p1: Vector2 = to_local(in_global_rect.position + in_global_rect.size)
	var local_pos = Vector2(min(p0.x, p1.x), min(p0.y, p1.y))
	var local_size = Vector2(abs(p1.x - p0.x), abs(p1.y - p0.y))
	return Rect2(local_pos, local_size)
