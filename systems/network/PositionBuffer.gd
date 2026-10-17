class_name PositionBuffer
extends RefCounted

const MIN_BUFFER_SIZE: int = 2
const MAX_BUFFER_SIZE: int = 20
const JITTER_SMOOTHING_RISE: float = 0.3
const JITTER_SMOOTHING_FALL: float = 0.1
const JITTER_DELAY: float = 2.0
const MAX_EXTRAPOLATION_TICKS: float = 10.0
const EXTRAPOLATION_DECAY_TICKS: float = 3.0
const CORRECTION_DECAY: float = 10.0
const CORRECTION_THRESHOLD: float = 50.0

class Packet:
	var tick: int
	var position: Vector2
	var velocity: Vector2
	var rotation: float

	func _init(_tick: int, _position: Vector2, _velocity: Vector2, _rotation: float = 0.0) -> void :
		tick = _tick
		position = _position
		velocity = _velocity
		rotation = _rotation

class Sample:
	var position: Vector2
	var velocity: Vector2
	var rotation: float
	var extrapolating: bool

	var a: Packet
	var b: Packet

	func _init(_position: Vector2, _velocity: Vector2, _rotation: float, _extrapolating: bool) -> void :
		position = _position
		velocity = _velocity
		extrapolating = _extrapolating
		rotation = _rotation

var buffer: Array[Packet] = []

var expected_tick_gap: float = MIN_BUFFER_SIZE

var last_received_time: int = -1
var last_received_tick: int = -1
var samples_received: int = 0
var mean_tick_gap: float = 1.0
var variance_tick_gap: float = 0.0
var adaptive_delay_ticks: float = 0.0

var skip_correction: bool = true
var correction_offset: Vector2 = Vector2.ZERO

var last_push_frame: int = -1
var burst_count: int = 0

func push_packet(tick: int, position: Vector2, velocity: Vector2, rotation: float = 0.0) -> void :
	var packet: = Packet.new(tick, position, velocity, rotation)


	update_jitter_stats(tick)
	last_received_time = Time.get_ticks_msec()


	var current_frame: = Engine.get_physics_frames()
	if current_frame == last_push_frame:
		burst_count += 1
		adaptive_delay_ticks = maxf(adaptive_delay_ticks, float(maxi(burst_count, MIN_BUFFER_SIZE)))
	else:
		last_push_frame = current_frame
		burst_count = 1


	var idx: int = buffer.size()
	while idx > 0 and buffer[idx - 1].tick > tick:
		idx -= 1

	if idx > 0 and buffer[idx - 1].tick == tick:

		buffer[idx - 1] = packet
		return

	buffer.insert(idx, packet)


	while buffer.size() > MAX_BUFFER_SIZE:
		buffer.pop_front()

func sample(current_position: Vector2, current_rotation: float = 0.0) -> Sample:
	if buffer.size() == 0:

		return Sample.new(current_position, Vector2.ZERO, current_rotation, false)

	var is_skip_frame: = skip_correction
	if skip_correction:
		skip_correction = false



	var current_network_tick: float = get_current_network_tick()
	var exact: Packet = find_packet(current_network_tick)

	var result: Sample

	if is_instance_valid(exact):
		result = Sample.new(exact.position, exact.velocity, exact.rotation, false)
	elif buffer.size() == 1 and buffer.back().tick > current_network_tick:

		result = Sample.new(current_position, Vector2.ZERO, current_rotation, false)
	else:
		var interpolated: Array[Packet] = find_bounding_pair(current_network_tick)
		if interpolated.size():
			var a: Packet = interpolated[0]
			var b: Packet = interpolated[1]

			var tick_duration: = float(b.tick - a.tick)
			var t: float = 0.0 if tick_duration <= 0.0 else clampf((current_network_tick - float(a.tick)) / tick_duration, 0.0, 1.0)
			var position: = a.position.lerp(b.position, t)
			var velocity: = a.velocity.lerp(b.velocity, t)
			var rotation: = lerp_angle(a.rotation, b.rotation, t)
			result = Sample.new(position, velocity, rotation, false)

		else:

			var last_packet: Packet = buffer.back()
			var delta_ticks: float = current_network_tick - last_packet.tick
			if delta_ticks > MAX_EXTRAPOLATION_TICKS:
				delta_ticks = MAX_EXTRAPOLATION_TICKS

			var velocity: = last_packet.velocity * exp( - delta_ticks / EXTRAPOLATION_DECAY_TICKS)
			var position: = last_packet.position + last_packet.velocity * Network.NETWORK_POSITION_TICK_RATE * EXTRAPOLATION_DECAY_TICKS * (1.0 - exp( - delta_ticks / EXTRAPOLATION_DECAY_TICKS))
			result = Sample.new(position, last_packet.velocity, last_packet.rotation, true)




	if not is_skip_frame:
		var jump: Vector2 = result.position - current_position
		var jump_length: = jump.length()
		if jump_length > CORRECTION_THRESHOLD:
			var allowed: = jump * (CORRECTION_THRESHOLD / jump_length)
			correction_offset = - (jump - allowed)

	if correction_offset.length() > CORRECTION_THRESHOLD * 5.0:

		correction_offset = Vector2.ZERO
	else:
		result.position += correction_offset

	return result

func reset() -> void :

	buffer.clear()
	mean_tick_gap = 1.0
	variance_tick_gap = 0.0
	last_received_tick = -1
	adaptive_delay_ticks = 0.0
	samples_received = 0
	correction_offset = Vector2.ZERO
	skip_correction = true

func get_current_network_tick() -> float:
	if samples_received < 2:
		return Network.tick_count - MIN_BUFFER_SIZE
	return Network.tick_count - maxf(adaptive_delay_ticks, 1.0)

func find_packet(current_network_tick: int) -> Packet:
	for i in range(buffer.size() - 1, -1, -1):
		if buffer[i].tick == current_network_tick:
			return buffer[i]
	return null

func find_bounding_pair(current_network_tick: int) -> Array[Packet]:
	for i in range(buffer.size() - 1, 0, -1):
		if current_network_tick >= buffer[i - 1].tick and current_network_tick <= buffer[i].tick:
			return [buffer[i - 1], buffer[i]]


	if buffer.size() >= 2:
		if current_network_tick < buffer[0].tick:
			return [buffer[0], buffer[1]]


	return []

func update_jitter_stats(tick: int) -> void :
	if last_received_tick < 0:
		last_received_tick = tick
		samples_received = 1
		return

	var gap: float = float(tick - last_received_tick)
	last_received_tick = tick
	samples_received += 1

	var diff: float = gap - expected_tick_gap
	mean_tick_gap += JITTER_SMOOTHING_RISE * (gap - mean_tick_gap)
	variance_tick_gap += JITTER_SMOOTHING_RISE * (diff * diff - variance_tick_gap)

	var jitter_stddev: float = sqrt(variance_tick_gap)
	var target: float = maxf(float(MIN_BUFFER_SIZE), expected_tick_gap) + JITTER_DELAY * jitter_stddev
	var rate: float = JITTER_SMOOTHING_RISE if target > adaptive_delay_ticks else JITTER_SMOOTHING_FALL
	adaptive_delay_ticks = lerpf(adaptive_delay_ticks, target, rate)

func update_correction(delta: float) -> void :
	correction_offset *= exp( - CORRECTION_DECAY * delta)
	if correction_offset.length_squared() < 0.01:
		correction_offset = Vector2.ZERO
