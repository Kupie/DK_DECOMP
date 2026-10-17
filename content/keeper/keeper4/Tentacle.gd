extends Node2D

const Keeper4Script = preload("res://content/keeper/keeper4/Keeper4.gd")

signal attached(position: Vector2, collider: Node)
signal detached(position: Vector2, collider: Node)

@export var attachment_cooldown: float = 0.2

var parent_tentacles: Node2D
var attachedTile = null
var attachmentPoint: Vector2 = Vector2.ZERO
var attachedNormal: Vector2 = Vector2.ZERO
var moving: = false
var idle_angle: float = 0.0
var cooldown_timer: float = 0.0
var current_bend_vec: Vector2 = Vector2.ZERO
var current_s_factor: float = 1.0
var current_force: Vector2 = Vector2.ZERO

var arc_start: Vector2 = Vector2.ZERO
var arc_end: Vector2 = Vector2.ZERO
var arc_progress: float = 0.0
var arc_active: bool = false
var speed_curve: Curve
var move_speed_scale: float
var claw_velocity: Vector2 = Vector2.ZERO
var idle_target: Vector2 = Vector2.ZERO

const EXTEND_SPEED: = 800.0
const ARC_HEIGHT: = 7.0
const IDLE_DISTANCE: = 15.0
const VIEW_CURVE_MIN: = 25.0
const VIEW_CURVE_MAX: = 35.0
const STRAIGHT_FACTOR: = 0.8

const MINING_ROPE_SAG: = 12.0
const SHOULDER_OFFSET: = Vector2(6.0, -6.0)
const SWAY_SPEED: = 0.002
const SWAY_AMOUNT: = 2.0
const TILE_RADIUS: = 12.0
const HIT_PENETRATION_MIN: = 2.0
const HIT_PENETRATION_MAX: = 7.0
const HIT_SPREAD: = 12.0
const ROTATION_DISTANCE_THRESHOLD: = 3.0

const HIT_ANTICIPATION_PERCENT: = 0.2
const HIT_ANTICIPATION_DISTANCE: = 5.0
const HIT_ARRIVAL_PERCENT: = 0.6
const EASE_IN_POWER: = 3.0
const SPRING_STIFFNESS: = 120.0
const SPRING_DAMPING: = 12.0
const SLOW_SPRING_STIFFNESS: = 30.0
const SLOW_SPRING_DAMPING: = 6.0
const MAX_RETRACTION_TIME: = 0.12
const READY_STANCE_DURATION: = 0.4
const ROTATION_SPEED: = 15.0

const ATTACK_ANTICIPATION_PERCENT: = 0.3
const ATTACK_HOLD_PERCENT: = 0.5

const ARM_CURVE_SIDE_IDLE: = 0.36
const ARM_CURVE_APPROACH_IDLE: = 0.27

const CARRY_HOLD_MAX_DISTANCE: = 85
const CARRY_OFFSET: = Vector2(6.0, -8.0)
const CARRY_GRAB_SPEED: = 600.0

var view_curve_base: = 24.0
var wobble_phase: float = 0.0
var wobble_direction: float = 1.0

var is_mining: = false
var mining_tile = null
var mining_idle_pos: Vector2 = Vector2.ZERO
var is_mining_active: = false
var surface_punch_mode: = false
var side: int = 1

var should_retract: bool = false
var is_retracted: = true
var extending_active: = false
var ready_stance_active: = false
var ready_stance_elapsed: = 0.0
var ready_stance_duration: = READY_STANCE_DURATION
var hit_duration: = 0.0
var hit_elapsed: = 0.0
var extend_start_pos: = Vector2.ZERO
var extend_target_pos: = Vector2.ZERO
var retraction_elapsed: = 0.0
var target_offset_penetration: = 0.0
var target_offset_lateral: = 0.0
var cached_strike_angle: float = 0.0
var current_mining_rotation: float = 0.0

var mining_attack_active: = false
var mining_attack_elapsed: = 0.0
var mining_attack_duration: = 0.0
var mining_attack_hit_applied: = false
var mining_attack_start_pos: = Vector2.ZERO

static var MAX_CARRIED: int = Keeper4GameplaySettings.MAX_CARRY
const CARRY_STACK_OFFSETS: = [
	Vector2.ZERO, 
	Vector2(-3, -4), 
	Vector2(3, -4), 
]

static func get_carry_offset(index: int) -> Vector2:
	if index < 0 or index >= CARRY_STACK_OFFSETS.size():
		return Vector2.ZERO
	return CARRY_STACK_OFFSETS[index]
var carried_resources: Array = []
var is_grabbing: = false
var was_bundled: = false
var grab_target_pos: = Vector2.ZERO

@export var extension_curve: Curve
@onready var speed_mod_particle: GPUParticles2D = $Claw / Static


func _ready():
	view_curve_base = randf_range(VIEW_CURVE_MIN, VIEW_CURVE_MAX)
	wobble_phase = randf() * TAU
	wobble_direction = 1.0 if randf() < 0.5 else -1.0

func is_attached():
	return is_instance_valid(attachedTile) or arc_active

func is_grounded() -> bool:
	return is_instance_valid(attachedTile) and not arc_active

func can_detach() -> bool:
	return cooldown_timer <= 0.0

func _physics_process(delta):
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
	if is_mining:
		_physics_process_mining(delta)
		return

	if is_carrying() or is_grabbing:
		_physics_process_carrying(delta)
		return

	if not is_instance_valid(attachedTile) and not arc_active:
		var keeper: = _get_owner_keeper()
		if keeper:
			var dir = ($Claw.global_position - keeper.global_position)
			if dir.length() > 0.001:
				idle_angle = dir.angle()
		attachedTile = null

	if arc_active:
		var keeper: = _get_owner_keeper()
		if not keeper:
			arc_active = false
			return

		var dist_to_end: float = keeper.global_position.distance_to(arc_end)
		var max_reach: float = parent_tentacles.REACH if parent_tentacles else 60.0
		if dist_to_end > max_reach * 1.2:
			arc_active = false
			attachedTile = null
			claw_velocity = Vector2.ZERO
			return

		var dist = arc_start.distance_to(arc_end)
		var keeper_speed: float = parent_tentacles.keeper_move_speed if parent_tentacles else 50.0
		var base_speed: float = min(move_speed_scale * keeper_speed, Keeper4GameplaySettings.TENTACLE_MOVE_SPEED_MAX)

		var base_duration = dist / max(base_speed, 0.1)

		var duration = base_duration
		if speed_curve:
			var speed_multiplier = max(speed_curve.sample(arc_progress), 0.5)
			duration = base_duration / speed_multiplier

		arc_progress += delta / max(duration, 0.01)

		if arc_progress >= 1.0:
			arc_active = false
			arc_progress = 1.0
			$Claw.global_position = arc_end
			if keeper:
				var dir = ($Claw.global_position - keeper.global_position)
				if dir.length() > 0.001:
					idle_angle = dir.angle()
			if arc_end.y > 40.0:
				$Claw / HitParticles.emitting = true
			claw_velocity = Vector2.ZERO
			cooldown_timer = attachment_cooldown
			emit_signal("attached", arc_end, attachedTile if is_instance_valid(attachedTile) else null)
		else:
			var linear_pos = arc_start.lerp(arc_end, arc_progress)

			var height_factor = sin(arc_progress * PI)

			var movement_dir = arc_end - arc_start
			var movement_length = movement_dir.length()
			var dynamic_arc_height = ARC_HEIGHT
			if keeper and movement_length > 0.001:
				var keeper_to_start = keeper.global_position - arc_start
				var cross = movement_dir.x * keeper_to_start.y - movement_dir.y * keeper_to_start.x
				var perp_distance = abs(cross) / movement_length
				dynamic_arc_height = perp_distance * (2.0 / 3.0)

			var arc_offset: = Vector2.ZERO
			if keeper:
				var keeper_dir = (keeper.global_position - linear_pos)
				if keeper_dir.length() > 0.001:
					arc_offset = keeper_dir.normalized() * dynamic_arc_height * height_factor
			if arc_offset == Vector2.ZERO:
				arc_offset = Vector2(0, - dynamic_arc_height * height_factor)

			var next_pos = linear_pos + arc_offset
			claw_velocity = (next_pos - $Claw.global_position) / delta
			$Claw.global_position = next_pos
			$Claw / HitParticles.emitting = false
			$Claw.play("open")
	elif not is_instance_valid(attachedTile):
		var displacement = idle_target - $Claw.global_position

		var spring_force = displacement * 60.0
		var damping_force = - claw_velocity * 8.0

		claw_velocity += (spring_force + damping_force) * delta
		$Claw.global_position += claw_velocity * delta

		var dist_limit = 40.0
		var dist_to_root = $Claw.global_position.distance_to(global_position)
		if dist_to_root > dist_limit:
			var dir_to_root = ($Claw.global_position - global_position).normalized()
			$Claw.global_position = global_position + dir_to_root * dist_limit
			var vel_radial = claw_velocity.dot(dir_to_root)
			if vel_radial > 0:
				claw_velocity -= dir_to_root * vel_radial

		moving = displacement.length() > 1.0 or claw_velocity.length() > 1.0

	var start_pos = Vector2.ZERO
	var end_pos = $Claw.position
	var dist = start_pos.distance_to(end_pos)

	if dist < 2.0 or view_curve_base <= 0.01:
		$Arm.points = PackedVector2Array([start_pos, end_pos])
		current_bend_vec = Vector2.ZERO
	else:
		var reach_ratio = clamp(dist / 60.0, 0.0, 1.0)
		var straight_factor = 1.0 - reach_ratio * STRAIGHT_FACTOR
		var curve_strength = view_curve_base * reach_ratio * straight_factor

		var arm_dir = (end_pos - start_pos).normalized()
		var perp = Vector2( - arm_dir.y, arm_dir.x)

		var target_bend_dir: Vector2
		var target_s_factor: float = 1.0

		if is_grounded() or arc_active:
			target_s_factor = -1.0
			if attachedNormal != Vector2.ZERO:
				if perp.dot(attachedNormal) < 0:
					perp = - perp
				target_bend_dir = perp
			else:
				var mid_point = start_pos.lerp(end_pos, 0.5)
				if (mid_point + perp).distance_squared_to(start_pos) > (mid_point - perp).distance_squared_to(start_pos):
					perp = - perp
				target_bend_dir = perp
		else:
			target_bend_dir = Vector2.DOWN

		var target_bend_vec = target_bend_dir * curve_strength
		current_bend_vec = current_bend_vec.lerp(target_bend_vec, delta * 5.0)
		current_s_factor = lerpf(current_s_factor, target_s_factor, delta * 5.0)

		var bend_vec = current_bend_vec

		var p0 = start_pos
		var p4 = end_pos

		var wobble_offset: = Vector2.ZERO
		if parent_tentacles and parent_tentacles.is_spread_mode and not parent_tentacles.is_actively_hitting and is_grounded():
			wobble_offset = perp * wobble_direction * sin(Time.get_ticks_msec() / 200.0 + wobble_phase) * 1.0

		var p1 = start_pos.lerp(end_pos, 0.25) + bend_vec * (-0.15 + 0.65 * current_s_factor) + wobble_offset * 0.5
		var p2 = start_pos.lerp(end_pos, 0.5) + bend_vec * (0.5 + 0.5 * current_s_factor) + wobble_offset
		var p3 = start_pos.lerp(end_pos, 0.75) + bend_vec * (0.65 - 0.15 * current_s_factor) + wobble_offset * 0.5

		var curve_points = PackedVector2Array()
		for i in range(21):
			var t = i / 20.0
			var q0 = p0.lerp(p1, t)
			var q1 = p1.lerp(p2, t)
			var q2 = p2.lerp(p3, t)
			var q3 = p3.lerp(p4, t)

			var r0 = q0.lerp(q1, t)
			var r1 = q1.lerp(q2, t)
			var r2 = q2.lerp(q3, t)

			var s0 = r0.lerp(r1, t)
			var s1 = r1.lerp(r2, t)

			curve_points.append(s0.lerp(s1, t))
		curve_points.reverse()
		$Arm.points = curve_points
	if $Arm.get_point_count() > 2:
		var target_angle = $Arm.points[1].direction_to($Arm.points[0]).angle()
		$Claw.global_rotation = target_angle
	else:
		$Claw.global_rotation = ($Claw.global_position - global_position).angle()

	if is_grounded():
		$Claw.global_position = attachmentPoint
		$Claw.play("attached")
		$Claw / HitParticles.emitting = true
	else:
		$Claw / HitParticles.emitting = false
		$Claw.play("open")

func set_speed_buildup(v: float):
	if not is_mining:
		if speed_mod_particle.emitting:
			speed_mod_particle.amount_ratio = lerp(speed_mod_particle.amount_ratio, 0.0, get_physics_process_delta_time() * 3.0)
			if speed_mod_particle.amount_ratio <= 0.01:
				speed_mod_particle.emitting = false
	else:
		speed_mod_particle.amount_ratio = ease(v, 10.0)
		if not speed_mod_particle.emitting and v > 0.5:
			speed_mod_particle.restart()
		else:
			speed_mod_particle.emitting = v > 0.5

func detach():
	var keeper: = _get_owner_keeper()
	var detach_pos: Vector2 = $Claw.global_position
	var detach_collider = attachedTile
	if keeper:
		var dir = ($Claw.global_position - keeper.global_position)
		if dir.length() > 0.001:
			idle_angle = dir.angle()
	attachedTile = null
	arc_active = false
	moving = false
	$Claw / HitParticles.emitting = false
	emit_signal("detached", detach_pos, detach_collider)

func attach_to(tile, point: Vector2, start_pos: Vector2, normal: Vector2 = Vector2.ZERO):
	attachedTile = tile
	attachmentPoint = point
	attachedNormal = normal
	arc_start = start_pos
	arc_end = point
	arc_progress = 0.0
	arc_active = true
	moving = true
	$Claw / HitParticles.emitting = false
	view_curve_base = randf_range(VIEW_CURVE_MIN, VIEW_CURVE_MAX)

func set_idle_pos(pos: Vector2):
	idle_target = pos
	if not is_attached():
		moving = $Claw.global_position.distance_to(pos) > 1.0

func get_claw_pos() -> Vector2:
	return $Claw.global_position

func _get_owner_keeper() -> Keeper:
	var node: Node = self
	while node:
		if node is Keeper:
			return node
		node = node.get_parent()
	return null

func set_mining_mode(mining: bool, tile = null):
	if is_carrying():
		is_mining = false
		is_mining_active = false
		return

	var was_mining: bool = is_mining
	var claw_world_pos: Vector2 = $Claw.global_position
	z_index = 0 if mining else -1
	is_mining = mining
	if not mining:
		mining_tile = null
		should_retract = false
		retraction_elapsed = 0.0
		extending_active = false
		ready_stance_active = false
		mining_attack_active = false
		mining_attack_hit_applied = false
		$Claw / HitParticles.emitting = false
		_update_mining_view_visibility()

		if was_mining:
			attachedTile = null
			arc_active = false
			var keeper: = _get_owner_keeper()
			if keeper:
				idle_target = claw_world_pos
				var dir = (claw_world_pos - keeper.global_position)
				if dir.length() > 0.001:
					idle_angle = dir.angle()
	elif tile and is_instance_valid(tile):
		var was_mining_different_tile: bool = mining_tile != tile
		mining_tile = tile
		is_mining_active = true
		should_retract = false
		retraction_elapsed = 0.0
		if was_mining_different_tile:
			is_retracted = false
			extending_active = false
			ready_stance_active = false
			mining_attack_active = false
			mining_attack_hit_applied = false
		attachedTile = null
		arc_active = false
		var keeper: = _get_owner_keeper()
		if keeper:
			var dir = (tile.global_position - keeper.global_position)
			if dir.length() > 0.001:
				idle_angle = dir.angle()
				mining_idle_pos = keeper.global_position + Vector2(IDLE_DISTANCE, 0).rotated(idle_angle)
				current_mining_rotation = ($Claw.global_position - keeper.global_position).angle()
		_update_mining_view_visibility()
	else:
		mining_tile = null
		is_mining_active = false
		$Claw / HitParticles.emitting = false
		_update_mining_view_visibility()

func hit_tile(tile):
	var keeper: = _get_owner_keeper()
	if keeper:
		var dir = (tile.global_position - keeper.global_position)
		if dir.length() > 0.001:
			idle_angle = dir.angle()
			mining_idle_pos = keeper.global_position + Vector2(IDLE_DISTANCE, 0).rotated(idle_angle)

	mining_tile = tile
	_update_extend_target()

func update_mining_target(new_tile) -> void :
	if not is_mining:
		return
	if mining_tile == new_tile:
		return
	set_mining_mode(true, new_tile)

func start_hit(duration: float = 0.5):
	if can_hit():
		ready_stance_active = false
		ready_stance_elapsed = 0.0

		if is_instance_valid(mining_tile) and mining_tile.has_meta("hole_target"):
			target_offset_penetration = TILE_RADIUS
			target_offset_lateral = 0.0
		else:
			target_offset_penetration = randf_range(HIT_PENETRATION_MIN, HIT_PENETRATION_MAX)
			target_offset_lateral = randf_range( - HIT_SPREAD * 0.5, HIT_SPREAD * 0.5)

		hit_duration = duration
		ready_stance_duration = min(READY_STANCE_DURATION, duration)
		hit_elapsed = 0.0
		retraction_elapsed = 0.0
		extending_active = true
		should_retract = false
		is_retracted = false

		extend_start_pos = $Claw.global_position
		_update_extend_target()
		cached_strike_angle = (extend_target_pos - extend_start_pos).angle()

		var keeper: = _get_owner_keeper()
		if keeper and is_instance_valid(mining_tile):
			var dir: Vector2 = (mining_tile.global_position - keeper.global_position)
			if dir.length() > 0.001:
				idle_angle = dir.angle()
				mining_idle_pos = keeper.global_position + Vector2(IDLE_DISTANCE, 0).rotated(idle_angle)

func can_hit() -> bool:
	return is_mining_active and is_mining and (is_retracted or ready_stance_active) and not extending_active and not should_retract and is_instance_valid(mining_tile)

func can_start_mining_attack() -> bool:
	return is_mining and is_mining_active and not mining_attack_active and is_instance_valid(mining_tile)

func start_mining_attack(duration: float):
	if not can_start_mining_attack():
		return

	extending_active = false
	ready_stance_active = false
	should_retract = false
	is_retracted = false

	mining_attack_active = true
	mining_attack_elapsed = 0.0
	mining_attack_duration = duration
	mining_attack_hit_applied = false

	target_offset_penetration = randf_range(HIT_PENETRATION_MIN, HIT_PENETRATION_MAX)
	target_offset_lateral = randf_range( - HIT_SPREAD * 0.5, HIT_SPREAD * 0.5)

	mining_attack_start_pos = $Claw.global_position
	_update_extend_target()
	cached_strike_angle = (extend_target_pos - mining_attack_start_pos).angle()

	var keeper: = _get_owner_keeper()
	if keeper and is_instance_valid(mining_tile):
		var dir: Vector2 = (mining_tile.global_position - keeper.global_position)
		if dir.length() > 0.001:
			idle_angle = dir.angle()
			mining_idle_pos = keeper.global_position + Vector2(IDLE_DISTANCE, 0).rotated(idle_angle)

func _update_mining_attack(delta):
	mining_attack_elapsed += delta
	var progress: float = clamp(mining_attack_elapsed / mining_attack_duration, 0.0, 1.0)

	var anticipation_end: float = ATTACK_ANTICIPATION_PERCENT
	var hold_end: float = ATTACK_ANTICIPATION_PERCENT + ATTACK_HOLD_PERCENT

	var shoulder_pos: Vector2 = _get_shoulder_pos()
	var dir_to_target: Vector2 = (extend_target_pos - shoulder_pos).normalized()
	var shoulder_offset: Vector2 = SHOULDER_OFFSET if side == 1 else Vector2( - SHOULDER_OFFSET.x, SHOULDER_OFFSET.y)
	var anticipation_dist: float = HIT_ANTICIPATION_DISTANCE * 2.0 if shoulder_offset.dot(dir_to_target) > 0 else HIT_ANTICIPATION_DISTANCE
	var anticipation_pos: Vector2 = shoulder_pos - dir_to_target * anticipation_dist

	var effective_anticipation_pos: Vector2 = anticipation_pos

	var new_pos: Vector2
	var new_rotation: float
	if progress < anticipation_end:
		var phase_progress: float = progress / anticipation_end
		var eased: float = 1.0 - pow(1.0 - phase_progress, 2.0)
		new_pos = mining_attack_start_pos.lerp(effective_anticipation_pos, eased)
		var to_target: Vector2 = extend_target_pos - new_pos
		if to_target.length() > ROTATION_DISTANCE_THRESHOLD:
			cached_strike_angle = to_target.angle()
		new_rotation = cached_strike_angle
		$Claw / HitParticles.emitting = false
	elif progress < hold_end:
		var displacement: Vector2 = effective_anticipation_pos - $Claw.global_position
		var spring_force: Vector2 = displacement * SPRING_STIFFNESS
		var damping_force: Vector2 = - claw_velocity * SPRING_DAMPING
		claw_velocity += (spring_force + damping_force) * delta
		new_pos = $Claw.global_position + claw_velocity * delta
		var to_target: Vector2 = extend_target_pos - new_pos
		if to_target.length() > ROTATION_DISTANCE_THRESHOLD:
			cached_strike_angle = to_target.angle()
		new_rotation = cached_strike_angle
		$Claw / HitParticles.emitting = false
	else:
		var strike_progress: float = (progress - hold_end) / (1.0 - hold_end)
		var eased: float = _sample_extension_curve(strike_progress)
		new_pos = effective_anticipation_pos.lerp(extend_target_pos, eased)
		new_rotation = cached_strike_angle
		$Claw / HitParticles.emitting = strike_progress > 0.8

	claw_velocity = (new_pos - $Claw.global_position) / max(delta, 0.001)
	$Claw.global_position = new_pos
	$Claw.global_rotation = _smooth_rotate_toward(new_rotation, delta)

	if progress >= 1.0:
		var impact: = preload("res://content/keeper/keeper4/ClawMiningImpact.tscn").instantiate()
		impact.position = $Claw.global_position
		impact.rotation = new_rotation
		Level.map.addDrop(impact)
		mining_attack_active = false
		mining_attack_hit_applied = true
		claw_velocity = Vector2.ZERO

func is_mining_attack_done() -> bool:
	return mining_attack_hit_applied and not mining_attack_active

func acknowledge_mining_attack():
	mining_attack_hit_applied = false

func is_extending() -> bool:
	return extending_active

func set_should_retract(retract: bool):
	if retract and is_retracted:
		return
	should_retract = retract

func _get_shoulder_pos() -> Vector2:
	var keeper: = _get_owner_keeper()
	if not keeper:
		return global_position
	var shoulder_pos: Vector2 = keeper.global_position + SHOULDER_OFFSET
	if side == -1:
		shoulder_pos = keeper.global_position + Vector2( - SHOULDER_OFFSET.x, SHOULDER_OFFSET.y)
	return shoulder_pos

func _update_extend_target():

	var keeper: = _get_owner_keeper()
	if not keeper:
		return

	var target_pos: Vector2 = mining_tile.global_position
	var dir_to_tile: Vector2 = (mining_tile.global_position - keeper.global_position).normalized()
	var perp: Vector2 = Vector2( - dir_to_tile.y, dir_to_tile.x)

	target_pos -= dir_to_tile * (TILE_RADIUS - target_offset_penetration)
	target_pos += perp * target_offset_lateral

	extend_target_pos = target_pos

func _update_extension(delta):
	hit_elapsed += delta

	var anticipation_time: float = hit_duration * HIT_ANTICIPATION_PERCENT
	var arrival_time: float = hit_duration * HIT_ARRIVAL_PERCENT
	var extension_duration: float = arrival_time - anticipation_time
	var bounce_duration: float = hit_duration - arrival_time

	var dir_to_target: Vector2 = (extend_target_pos - extend_start_pos).normalized()
	var anticipation_pos: Vector2 = extend_start_pos - dir_to_target * HIT_ANTICIPATION_DISTANCE

	var default_angle: float = ($Claw.global_position - global_position).angle()

	var new_pos: Vector2
	var new_rotation: float

	if hit_elapsed <= anticipation_time:
		var anticipation_progress: float = clamp(hit_elapsed / anticipation_time, 0.0, 1.0)
		var eased_progress: float = 1.0 - pow(1.0 - anticipation_progress, 2.0)
		new_pos = extend_start_pos.lerp(anticipation_pos, eased_progress)
		var to_target: Vector2 = extend_target_pos - new_pos
		if to_target.length() > ROTATION_DISTANCE_THRESHOLD:
			cached_strike_angle = to_target.angle()
		new_rotation = cached_strike_angle
		$Claw / HitParticles.emitting = false
	elif hit_elapsed <= arrival_time:
		var extension_elapsed: float = hit_elapsed - anticipation_time
		var extension_progress: float = clamp(extension_elapsed / extension_duration, 0.0, 1.0)
		var eased_progress: float = _sample_extension_curve(extension_progress)
		new_pos = anticipation_pos.lerp(extend_target_pos, eased_progress)
		var to_target: Vector2 = extend_target_pos - new_pos
		if to_target.length() > ROTATION_DISTANCE_THRESHOLD:
			cached_strike_angle = to_target.angle()
		new_rotation = cached_strike_angle
		$Claw / HitParticles.emitting = extension_progress > 0.8
	else:
		new_pos = extend_target_pos
		var bounce_progress: float = clamp((hit_elapsed - arrival_time) / bounce_duration, 0.0, 1.0)
		var to_target: Vector2 = extend_target_pos - new_pos
		if to_target.length() > ROTATION_DISTANCE_THRESHOLD:
			cached_strike_angle = to_target.angle()
		new_rotation = lerp_angle(cached_strike_angle, default_angle, bounce_progress)
		$Claw / HitParticles.emitting = false

	claw_velocity = (new_pos - $Claw.global_position) / max(delta, 0.001)
	$Claw.global_position = new_pos
	$Claw.global_rotation = _smooth_rotate_toward(new_rotation, delta)

	is_retracted = false

	if hit_elapsed >= hit_duration:
		extending_active = false
		ready_stance_active = true
		ready_stance_elapsed = 0.0

func _sample_extension_curve(t: float) -> float:
	if extension_curve:
		return extension_curve.sample(t)
	return pow(t, EASE_IN_POWER)

func _update_ready_stance(delta):
	ready_stance_elapsed += delta

	var shoulder_pos: Vector2 = _get_shoulder_pos()
	var dir_to_target: Vector2 = (extend_target_pos - shoulder_pos).normalized()
	var anticipation_pos: Vector2 = shoulder_pos - dir_to_target * HIT_ANTICIPATION_DISTANCE

	var displacement: Vector2 = anticipation_pos - $Claw.global_position
	var spring_force: Vector2 = displacement * SPRING_STIFFNESS
	var damping_force: Vector2 = - claw_velocity * SPRING_DAMPING
	claw_velocity += (spring_force + damping_force) * delta
	$Claw.global_position += claw_velocity * delta

	var target_angle: float = (extend_target_pos - $Claw.global_position).angle()
	$Claw.global_rotation = _smooth_rotate_toward(target_angle, delta)
	$Claw / HitParticles.emitting = false

	if ready_stance_elapsed >= ready_stance_duration:
		ready_stance_active = false

func _update_mining_spring_retraction(target_pos: Vector2, delta, stiffness: float = SPRING_STIFFNESS, damping: float = SPRING_DAMPING):
	if should_retract:
		retraction_elapsed += delta

	var displacement: Vector2 = target_pos - $Claw.global_position

	var spring_force: Vector2 = displacement * stiffness
	var damping_force: Vector2 = - claw_velocity * damping

	claw_velocity += (spring_force + damping_force) * delta
	$Claw.global_position += claw_velocity * delta

	var near_shoulder: bool = displacement.length() < 3.0 and claw_velocity.length() < 10.0
	var time_exceeded: bool = should_retract and retraction_elapsed >= MAX_RETRACTION_TIME

	if near_shoulder or time_exceeded:
		should_retract = false
		is_retracted = true
		if time_exceeded:
			$Claw.global_position = target_pos
			claw_velocity = Vector2.ZERO
	else:
		is_retracted = false

	$Claw / HitParticles.emitting = false

func _update_arm_visual_mining():
	var start_pos: = Vector2.ZERO
	var end_pos: Vector2 = $Claw.position
	var dist: float = start_pos.distance_to(end_pos)

	if dist < 2.0:
		$Arm.points = PackedVector2Array([start_pos, end_pos])
		return

	var curve_points: = PackedVector2Array()

	if is_mining and is_instance_valid(mining_tile):
		var arm_dir: Vector2 = (end_pos - start_pos).normalized()
		var arm_perp: Vector2 = Vector2( - arm_dir.y, arm_dir.x)
		var claw_facing: Vector2 = Vector2.RIGHT.rotated($Claw.rotation)

		var curve_side: float = ARM_CURVE_SIDE_IDLE
		var curve_approach: float = ARM_CURVE_APPROACH_IDLE

		var p0: Vector2 = start_pos
		var p3: Vector2 = end_pos
		var p1_curved: Vector2 = start_pos + arm_dir * (dist * 0.6) + arm_perp * side * (dist * curve_side)

		var keeper: = _get_owner_keeper()
		if keeper:
			var mining_dir: Vector2 = (mining_tile.global_position - keeper.global_position).normalized()
			var is_horizontal: bool = abs(mining_dir.x) > abs(mining_dir.y)
			if is_horizontal:
				var s_offset: Vector2 = SHOULDER_OFFSET if side == 1 else Vector2( - SHOULDER_OFFSET.x, SHOULDER_OFFSET.y)
				if s_offset.dot(mining_dir) > 0:
					p1_curved.y += dist * 0.4

		var p2_curved: Vector2 = end_pos - claw_facing * (dist * curve_approach)

		for i in range(13):
			var t: float = i / 12.0
			var t2: float = t * t
			var t3: float = t2 * t
			var mt: float = 1.0 - t
			var mt2: float = mt * mt
			var mt3: float = mt2 * mt
			var curved_point: Vector2 = mt3 * p0 + 3.0 * mt2 * t * p1_curved + 3.0 * mt * t2 * p2_curved + t3 * p3
			var straight_point: Vector2 = start_pos.lerp(end_pos, t)
			curve_points.append(curved_point.lerp(straight_point, 0.0))
	else:
		var mid: Vector2 = start_pos.lerp(end_pos, 0.6)
		var sag: float = MINING_ROPE_SAG * (dist / 60.0)
		var control: Vector2 = mid + Vector2(0, sag)

		for i in range(11):
			var t: float = i / 10.0
			var q0: Vector2 = start_pos.lerp(control, t)
			var q1: Vector2 = control.lerp(end_pos, t)
			curve_points.append(q0.lerp(q1, t))
	curve_points.reverse()
	$Arm.points = curve_points

func _smooth_rotate_toward(target_angle: float, delta: float) -> float:
	current_mining_rotation = lerp_angle(current_mining_rotation, target_angle, ROTATION_SPEED * delta)
	return current_mining_rotation

func _update_mining_view_visibility():
	var show_mining_view: bool = is_mining and not surface_punch_mode
	if has_node("Claw/MiningView"):
		$Claw / MiningView.visible = show_mining_view
	if $Claw is AnimatedSprite2D:
		$Claw.self_modulate.a = 0.0 if show_mining_view else 1.0

func _physics_process_mining(delta):
	var keeper: = _get_owner_keeper()
	if not keeper:
		return

	var claw_world_pos: Vector2 = $Claw.global_position
	global_position = keeper.global_position
	$Claw.global_position = claw_world_pos

	if is_carrying() or is_grabbing:
		_update_carry(delta)
		_update_arm_visual_carry(delta)
		return

	var shoulder_pos: Vector2 = _get_shoulder_pos()
	var time: float = Time.get_ticks_msec() * SWAY_SPEED
	var sway: Vector2 = Vector2(sin(time + side), cos(time * 0.7 + side)) * SWAY_AMOUNT
	shoulder_pos += sway

	if not is_mining_active:
		_update_mining_spring_retraction(shoulder_pos, delta, SLOW_SPRING_STIFFNESS, SLOW_SPRING_DAMPING)
	elif not is_mining or not is_instance_valid(mining_tile):
		if extending_active or ready_stance_active or mining_attack_active:
			extending_active = false
			ready_stance_active = false
			mining_attack_active = false
			claw_velocity = Vector2.ZERO
		_update_mining_spring_retraction(shoulder_pos, delta)
		$Claw / HitParticles.emitting = false
		if is_retracted:
			is_mining_active = false
	elif is_instance_valid(mining_tile):
		if mining_attack_active:
			_update_mining_attack(delta)
		elif extending_active:
			_update_extension(delta)
		elif ready_stance_active:
			_update_ready_stance(delta)
		else:
			_update_mining_spring_retraction(shoulder_pos, delta)

	_update_arm_visual_mining()

	if not extending_active and not ready_stance_active and not mining_attack_active:
		var target_angle: float
		if is_mining and is_instance_valid(mining_tile):
			target_angle = (mining_tile.global_position - global_position).angle()
		elif $Arm.get_point_count() > 2:
			target_angle = $Arm.points[-2].direction_to($Arm.points[-1]).angle()
		else:
			target_angle = ($Claw.global_position - global_position).angle()
		$Claw.global_rotation = target_angle
		$Claw.global_rotation = _smooth_rotate_toward(target_angle, delta)

func _physics_process_carrying(delta: float):
	var keeper: = _get_owner_keeper()
	if not keeper:
		return
	var claw_world_pos: Vector2 = $Claw.global_position
	global_position = keeper.global_position
	$Claw.global_position = claw_world_pos

	_update_carry(delta)
	_update_arm_visual_carry(delta)

	var target_angle: float = ($Claw.global_position - global_position).angle()
	$Claw.global_rotation = target_angle

func is_carrying() -> bool:
	return carried_resources.size() > 0

func can_carry() -> bool:
	return carried_resources.size() < MAX_CARRIED

func grab_resource(resource) -> bool:
	var keeper: = _get_owner_keeper()
	var otherKeeper4: = _get_other_keeper4_carrier(resource)
	if otherKeeper4:
		for theirs in otherKeeper4.carriedCarryables:
			for mine in carried_resources:
				mine.add_collision_exception_with(theirs)
				theirs.add_collision_exception_with(mine)

	for existing in carried_resources:
		if is_instance_valid(existing):
			existing.add_collision_exception_with(resource)
			resource.add_collision_exception_with(existing)
	carried_resources.append(resource)
	is_grabbing = true
	grab_target_pos = resource.global_position

	if keeper:
		resource.unfocusCarry(keeper)
		resource.dissolveCarryInfluence()
		var po = CarryablePhysicsOverride.new(keeper)
		po.linear_damp = 2
		po.angular_damp = 2
		po.gravity_scale = 0
		if resource.is_node_ready():
			resource.addPhysicsOverride(po)
		else:
			resource.ready.connect(resource.addPhysicsOverride.bind(po), CONNECT_ONE_SHOT)
		keeper.carriedCarryables.append(resource)
		resource.setCarriedBy(keeper)

	return true

func _get_other_keeper4_carrier(resource) -> Keeper:
	var keeper: = _get_owner_keeper()
	for carrier in resource.carriedBy:
		if carrier is Keeper and carrier != keeper and carrier.techId == "keeper4":
			return carrier
	return null

func _get_bundle_partner() -> Keeper:
	for res in carried_resources:
		var carrier: = _get_other_keeper4_carrier(res)
		if carrier:
			return carrier
	return null

func drop_resource(resource) -> void :
	var keeper: = _get_owner_keeper()
	var saved_pos: Vector2 = resource.global_position
	if keeper:
		keeper.carriedCarryables.erase(resource)
		resource.freeCarry(keeper)
		keeper.restoreConverterGravity(resource)

	var otherKeeper4: = _get_other_keeper4_carrier(resource)
	carried_resources.erase(resource)
	var partner: = _get_bundle_partner()

	if otherKeeper4 == null:
		_remove_collision_exceptions(resource)
		if partner:
			for theirs in partner.carriedCarryables:
				resource.remove_collision_exception_with(theirs)
				theirs.remove_collision_exception_with(resource)
	elif partner == null:
		for mine in carried_resources:
			for theirs in otherKeeper4.carriedCarryables:
				mine.remove_collision_exception_with(theirs)
				theirs.remove_collision_exception_with(mine)

	resource.global_position = saved_pos
	if carried_resources.is_empty():
		is_grabbing = false

func set_color(color_id: String, remap_color_palette: bool):
	if remap_color_palette:
		var mapping: Array = Data.palette_rgby.get(Style.paletteId)
		if mapping:
			color_id = "color" + str(mapping[int(color_id.substr(5))] - 1)
		else:
			Logger.error("wanted to remap tentacle color, but palette does not have mapping table", "Tentacle.set_color", {"color_id": color_id, "paletteId": Style.paletteId})

	var texture_path: String = "res://content/keeper/keeper4/tentacle_tex_" + color_id + ".png"
	%Arm.texture = load(texture_path)

func _remove_collision_exceptions(resource) -> void :
	for res in carried_resources:
		if is_instance_valid(res) and res != resource:
			res.remove_collision_exception_with(resource)
			resource.remove_collision_exception_with(res)

func _update_carry(delta: float):
	var keeper: = _get_owner_keeper()
	if not keeper:
		return

	for i in range(carried_resources.size() - 1, -1, -1):
		if not is_instance_valid(carried_resources[i]):
			carried_resources.remove_at(i)

	if carried_resources.is_empty():
		was_bundled = false
		return

	if is_grabbing:
		var grab_target: Node2D = carried_resources[carried_resources.size() - 1]
		var claw_to_resource: float = $Claw.global_position.distance_to(grab_target.global_position)
		if claw_to_resource < 5.0:
			is_grabbing = false
		else:
			var grab_dir: Vector2 = (grab_target.global_position - $Claw.global_position).normalized()
			$Claw.global_position += grab_dir * CARRY_GRAB_SPEED * delta
			for i in range(carried_resources.size() - 1):
				var res: = carried_resources[i] as Carryable
				if res.lastCarriedPlayerId != keeper.playerId:
					continue
				res.global_position = $Claw.global_position + get_carry_offset(i)
				res.linear_velocity = Vector2.ZERO
			return

	var keeper_pos: Vector2 = keeper.global_position
	var target_base_offset: Vector2 = CARRY_OFFSET
	if side == -1:
		target_base_offset.x = - target_base_offset.x

	if keeper.moveDirectionInput.length() > 0.1:
		target_base_offset = - keeper.moveDirectionInput.normalized() * target_base_offset.length()

	var base_offset: Vector2 = target_base_offset

	var anchor: Vector2 = keeper_pos + base_offset
	var partner: = _get_bundle_partner()
	if partner:
		was_bundled = true
		anchor = (keeper.global_position + partner.global_position) * 0.5
		if keeper.global_position.distance_to(anchor) > CARRY_HOLD_MAX_DISTANCE:
			for res in carried_resources.duplicate():
				if res.carrierCount() > 1 and res.lastCarriedPlayerId != keeper.playerId and res.is_multiplayer_authority():
					keeper.dropCarry(res)
			return
	elif was_bundled:
		var all_home: = true
		for i in range(carried_resources.size()):
			var res: = carried_resources[i] as Carryable
			if res.global_position.distance_to(anchor + get_carry_offset(i)) > CARRY_HOLD_MAX_DISTANCE:
				all_home = false
				break
		if all_home:
			was_bundled = false

	var slowestResource: Carryable = carried_resources[0]
	var curMass: = 0
	var resIndex = 0
	for i in range(carried_resources.size()):
		var res: = carried_resources[i] as Carryable
		if res.mass >= curMass:
			curMass = res.mass
			slowestResource = res
			resIndex = i

	var target_pos: Vector2 = anchor + get_carry_offset(resIndex)
	var to_target: Vector2 = target_pos - slowestResource.global_position
	var dist: float = to_target.length()
	var distFactor: = 0.3
	var lengthLimit: = 200.0
	var impulse: Vector2 = (to_target.normalized() * pow(dist * distFactor, 2)).limit_length(lengthLimit)
	if slowestResource.is_multiplayer_authority() and slowestResource.lastCarriedPlayerId == keeper.playerId:
		slowestResource.apply_central_impulse(impulse * slowestResource.mass)

		var relative_vel: Vector2 = slowestResource.linear_velocity - keeper.velocity
		var damp_factor: float = 0.35 + min(keeper.velocity.length() / 300.0, 1.0) * 0.5
		slowestResource.apply_central_impulse( - relative_vel * damp_factor * slowestResource.mass)

	var max_hold_dist: float = CARRY_HOLD_MAX_DISTANCE * 2 if was_bundled else CARRY_HOLD_MAX_DISTANCE
	for i in range(carried_resources.size()):
		var res: = carried_resources[i] as Carryable

		target_pos = anchor + get_carry_offset(i)
		to_target = target_pos - res.global_position
		dist = to_target.length()

		if dist > max_hold_dist and res.is_multiplayer_authority():
			keeper.dropCarry(res)
			return
		if res == slowestResource:
			continue
		if res.lastCarriedPlayerId != keeper.playerId:
			continue

		res.global_position = slowestResource.global_position - get_carry_offset(resIndex) + get_carry_offset(i)

	if carried_resources.size() > 0 and not is_grabbing:
		$Claw.global_position = slowestResource.global_position

func _update_arm_visual_carry(delta: float):
	var start_pos: = Vector2.ZERO
	var end_pos: Vector2 = $Claw.position
	var dist: float = start_pos.distance_to(end_pos)

	var sag_amount: float = MINING_ROPE_SAG
	if is_carrying():
		sag_amount = MINING_ROPE_SAG * 1.5

	if dist < 2.0 or sag_amount <= 0.01:
		$Arm.points = PackedVector2Array([start_pos, end_pos])
	else:
		var mid: Vector2 = start_pos.lerp(end_pos, 0.6)
		var sag: float = sag_amount * (dist / 60.0)
		var control: Vector2 = mid + Vector2(0, sag)

		var curve_points: = PackedVector2Array()
		for i in range(11):
			var t: float = i / 10.0
			var q0: Vector2 = start_pos.lerp(control, t)
			var q1: Vector2 = control.lerp(end_pos, t)
			curve_points.append(q0.lerp(q1, t))
		curve_points.reverse()
		$Arm.points = curve_points

	if $Arm.get_point_count() < 2:
		var target_angle: float = ($Claw.global_position - global_position).angle()
		$Claw.global_rotation = _smooth_rotate_toward(target_angle, delta)
	else:
		$Claw.global_rotation = $Arm.points[0].direction_to($Arm.points[1]).angle()
	$Claw / HitParticles.emitting = false
