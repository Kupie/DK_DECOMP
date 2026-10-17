extends Keeper

signal tileHit
signal squad_triggered(hole: Node2D)

@onready var DrillHitTestRay = $DrillHitTestRay
@onready var StartDrillHitTestRay = $StartDrillHitTestRay

var hitCooldown: = 0.0
var tilePunchCount: = 0.0
var currentSpeedup: = 0.0
var timeSinceLastPunch: = 0.0
var isMiningMode: = false
var currentMiningTile = null
var currentMiningTentacleIndex: = 0

var currentMiningDirection: = Vector2.ZERO

var forced_velocity: = Vector2.ZERO
var is_forced_movement: = false

var miningMoveTimer: = 0.0
var lastMiningMoveDirection: = Vector2.ZERO

var mining_target_position: = Vector2.ZERO
var is_moving_to_mining_pos: = false
var is_anchoring_for_mining: = false
var mining_recoil_offset: = 0.0
var mining_oscillation_base_pos: = Vector2.ZERO
var continuous_mining_direction: = Vector2.ZERO
var _last_continuous_mining_direction: = Vector2.ZERO
var _last_destroyed_tile_coord: = Vector2.ZERO
var pending_tile_destroyed: = false
var is_searching_next_tile: = false
var _anim_horizontal: = false
var _dig_upgrade_level: int = 0
var _current_dig_loop: Node = null
var _current_dig_end: Node = null
var _claw_attach_base_vol: float = 0.0
var _claw_detach_base_vol: float = 0.0
var _last_speed_tier: int = -1

var _last_drop_time_msec: int = 0
const DROP_INTERVAL_MSEC: int = 100
var isSpawningHole: = false
var isSurfacePunching: = false
var _surface_punch_count: int = 0
var _surface_punch_hole: Node2D = null
var _punch_hit_tween: Tween = null
var _tentacles_visibility_tween: Tween = null
var _squad_triggered_this_punch: = false
var _hole_punch_timer: = 0.0
var _hole_retreat_timer: = 0.0
var _hole_punch_target: Node2D = null
var holeSpawnTargetPos: = Vector2.ZERO
var holeSpawnTentacle = null
var holeSpawnTarget = null

func _handle_normal_movement(delta: float, effective_speed: float, attached_count: int, input_override: Vector2 = Vector2.ZERO, skip_constraint: bool = false) -> void :
	if attached_count == 0:
		_handle_airborne_movement(delta)
		return

	var input: Vector2 = input_override if input_override.length() > 0.1 else moveDirectionInput
	var deceleration: float = Keeper4GameplaySettings.MOVE_DECELERATION
	var acceleration: float = Keeper4GameplaySettings.MOVE_ACCELERATION

	var no_input: bool = input.length() < 0.1
	if no_input:
		velocity *= 1.0 - delta * deceleration * 2.0
		if velocity.length() < 5.0:
			velocity = Vector2.ZERO
	else:
		if velocity.length() > 5.0:
			var vel_dir: Vector2 = velocity.normalized()
			var input_dir: Vector2 = input.normalized()
			var turn_factor: float = pow(1.0 - vel_dir.dot(input_dir), 2.0)
			velocity *= 1.0 - delta * deceleration * turn_factor

	var desired_velocity: Vector2 = input * effective_speed
	if not skip_constraint:
		desired_velocity = $Tentacles.constrain_movement(desired_velocity, delta)

	var velocity_change: Vector2 = desired_velocity * acceleration * delta
	var speed_diff: float = max(0.0, desired_velocity.length() - velocity.length())
	velocity_change = velocity_change.limit_length(speed_diff) if speed_diff > 0.01 else velocity_change

	velocity = (velocity * (1.0 - delta * deceleration)) + velocity_change
	velocity = velocity.limit_length(effective_speed)

func _handle_airborne_movement(delta: float):
	velocity.y += Keeper4GameplaySettings.GRAVITY * delta
	velocity.y = min(velocity.y, Keeper4GameplaySettings.MAX_FALL_SPEED)

	var input: Vector2 = moveDirectionInput
	if input.length() > 0.1:
		velocity.x += input.x * Keeper4GameplaySettings.AIR_CONTROL_SPEED * delta

func _handle_mining_movement(delta: float, effective_speed: float, attached_count: int):
	if is_moving_to_mining_pos:
		var to_target: Vector2 = mining_target_position - global_position
		var dist: float = to_target.length()
		if dist < 0.5:
			velocity = Vector2.ZERO
			is_moving_to_mining_pos = false
			is_anchoring_for_mining = true
			mining_oscillation_base_pos = global_position
			$Tentacles.force_attach_all(currentMiningTile, continuous_mining_direction)
		else:
			_handle_normal_movement(delta, effective_speed, attached_count, to_target.normalized(), true)
			velocity = velocity.limit_length(dist / delta)
			if dist < 5.0:
				var damp_factor: float = dist / 5.0
				velocity *= 0.75 + 0.25 * damp_factor
	elif currentMiningDirection.length_squared() > 0.1 and is_instance_valid(currentMiningTile) and not is_searching_next_tile:
		if attached_count == 0:
			stopMining()
			return
		var dir: Vector2 = currentMiningDirection.normalized()
		mining_recoil_offset = lerpf(mining_recoil_offset, 0.0, 1.0 - exp( - Keeper4GameplaySettings.MINING_OSCILLATION_SPEED * delta))
		var target_pos: Vector2 = mining_oscillation_base_pos - dir * mining_recoil_offset
		global_position = global_position.lerp(target_pos, 0.5)
		velocity = Vector2.ZERO
	elif is_searching_next_tile:
		_handle_normal_movement(delta, effective_speed, attached_count, continuous_mining_direction.normalized())

func _handle_forced_movement(delta: float, attached_count: int):
	velocity += forced_velocity * delta
	forced_velocity = forced_velocity.lerp(Vector2.ZERO, 5.0 * delta)
	var gravity_factor: float = 0.5 if attached_count >= 1 else 1.0
	velocity.y += Keeper4GameplaySettings.GRAVITY * gravity_factor * delta
	velocity.y = min(velocity.y, Keeper4GameplaySettings.MAX_FALL_SPEED)

	if forced_velocity.length() < 1.0:
		is_forced_movement = false
		forced_velocity = Vector2.ZERO

func apply_forced_movement(impulse: Vector2):
	forced_velocity += impulse
	is_forced_movement = true

func networkStartMining(direction: Vector2):
	synchronizer.network_rpc(startMining.bind(direction), true)

@rpc("reliable", "any_peer")
func startMining(direction: Vector2):
	if isSpawningHole:
		return
	var tile = _get_tile_in_direction(direction)
	if tile and tile.has_meta("destructable") and tile.get_meta("destructable"):
		var prev_dir: Vector2 = continuous_mining_direction if continuous_mining_direction.length_squared() > 0.01 else _last_continuous_mining_direction
		var dot: float = prev_dir.dot(direction) if prev_dir.length_squared() > 0.01 else 1.0
		if dot < 0.5 and tilePunchCount > 0 and Data.ofOr(playerId + ".keeper4.losespeedupondirectionchange", false):
			tilePunchCount = 0.0
		isMiningMode = true
		currentMiningDirection = direction
		currentMiningTile = tile
		continuous_mining_direction = direction
		hitCooldown = 0.0

		mining_target_position = _find_adjacent_empty_tile_center(tile, direction)
		is_moving_to_mining_pos = true
		mining_oscillation_base_pos = mining_target_position
		mining_recoil_offset = 0.0

		if not tile.destroyed.is_connected(_on_mining_tile_destroyed):
			tile.destroyed.connect(_on_mining_tile_destroyed.bind(tile), CONNECT_ONE_SHOT)

		$mining_anchored.startSound()

		if _current_dig_loop:
			_current_dig_loop.baseVolume = -20.0
			_current_dig_loop.startSound()

		_handle_mining(0.0)

func networkStopMining():
	synchronizer.network_rpc(stopMining, true)

@rpc("reliable", "any_peer")
func stopMining():
	if not isMiningMode:
		return
	$mining_deanchored.startSound()
	isMiningMode = false
	currentMiningTile = null
	currentMiningDirection = Vector2.ZERO
	miningMoveTimer = 0.0
	lastMiningMoveDirection = Vector2.ZERO
	is_moving_to_mining_pos = false
	is_anchoring_for_mining = false
	mining_target_position = Vector2.ZERO
	_last_continuous_mining_direction = continuous_mining_direction
	continuous_mining_direction = Vector2.ZERO
	pending_tile_destroyed = false
	is_searching_next_tile = false
	mining_recoil_offset = 0.0
	$Sprite2D.speed_scale = 1.0
	$Tentacles.clear_mining_tentacles()
	if _current_dig_loop:
		_current_dig_loop.stop()
	if _current_dig_end:
		var end_vol: float = lerpf(-20.0, _dig_max_volume(), currentSpeedup)
		_current_dig_end.baseVolume = end_vol
		_current_dig_end.startSound()

func _on_mining_tile_destroyed(inTeamID: String, keeperTechId: String, tile: Node):
	if not isMiningMode or currentMiningTile != tile:
		return
	_last_destroyed_tile_coord = tile.coord
	currentMiningTile = null
	call_deferred("_start_searching_next_tile")

func switch_mining_direction():
	if Data.ofOr(playerId + ".keeper4.losespeedupondirectionchange", false):
		tilePunchCount = 0.0
	currentMiningTile = null
	call_deferred("_start_searching_next_tile")

func _start_searching_next_tile():
	is_searching_next_tile = true

var _spawn_freeze_timer: float = 0.5

func _ready():
	%BuffedSprite.visible = false
	$Sprite2D.frame = 0
	focussedUsable = null
	focussedCarryable = null
	hitCooldown = 0.0
	isMiningMode = false
	currentMiningTile = null
	currentMiningTentacleIndex = 0
	miningMoveTimer = 0.0
	lastMiningMoveDirection = Vector2.ZERO
	$DrillHit.hide()

	Style.init(self)

	$Tentacles.tentacle_attached.connect(_on_tentacle_attached)
	$Tentacles.tentacle_detached.connect(_on_tentacle_detached)

	if multiplayer.is_server():
		while not is_instance_valid(Level.getDome(teamId)):
			await get_tree().process_frame
		Level.getDome(teamId).goblins.register_keeper(self)

func init():
	super.init()
	Level.addTutorial(self, "beastmaster_intro", playerId)
	Level.addTutorial(self, "beastmaster_hole", playerId)
	Level.addTutorial(self, "beastmaster_squad", playerId)

	_claw_attach_base_vol = $TentacleAttachSound.baseVolume
	_claw_detach_base_vol = $TentacleDetachSound.baseVolume

func _dig_max_volume() -> float:
	if _dig_upgrade_level >= 4:
		return 0.0
	if _dig_upgrade_level == 3:
		return -5.0
	if _dig_upgrade_level == 2:
		return -8.0
	return -12.0

func _update_dig_upgrade_tier():
	var path: String = ""
	var level: int = 0
	if GameWorld.boughtUpgrades.has(playerId + ".keeper4punch4"):
		path = "Frenzy"
		level = 4
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper4punch3"):
		path = "Frenzy"
		level = 3
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper4punch2"):
		path = "Frenzy"
		level = 2
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper4punch1"):
		path = "Frenzy"
		level = 1
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper4flexible4"):
		path = "Agility"
		level = 4
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper4flexible3"):
		path = "Agility"
		level = 3
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper4flexible2"):
		path = "Agility"
		level = 2
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper4flexible1"):
		path = "Agility"
		level = 1
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper4ramping4"):
		path = "Momentum"
		level = 4
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper4ramping3"):
		path = "Momentum"
		level = 3
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper4ramping2"):
		path = "Momentum"
		level = 2
	elif GameWorld.boughtUpgrades.has(playerId + ".keeper4ramping1"):
		path = "Momentum"
		level = 1
	_dig_upgrade_level = level
	if path != "":
		_current_dig_loop = $UpgradeSounds.get_node(path + "_loop")
		_current_dig_end = $UpgradeSounds.get_node(path + "_end")
	else:
		_current_dig_loop = null
		_current_dig_end = null

func _update_claw_volume():
	var move_speed: float = Data.ofOr(playerId + ".keeper4.movespeed", 130.0)
	var speed_tier: int = 0
	if move_speed >= 265.0:
		speed_tier = 3
	elif move_speed >= 200.0:
		speed_tier = 2
	elif move_speed >= 165.0:
		speed_tier = 1
	if speed_tier != _last_speed_tier:
		_last_speed_tier = speed_tier
		var db_reduction: float = -2.0 * speed_tier
		$TentacleAttachSound.baseVolume = _claw_attach_base_vol + db_reduction
		$TentacleDetachSound.baseVolume = _claw_detach_base_vol + db_reduction

func enterStation(station, dropResources: = true):
	if isMiningMode:
		stopMining()
	for t in $Tentacles.tentacles:
		if t.is_attached():
			t.detach()
	hideTentacles()
	super.enterStation(station, dropResources)

func exitStation():
	super.exitStation()
	_update_claw_volume()
	_update_dig_upgrade_tier()
	showTentacles()

func hideTentacles() -> void :
	if _tentacles_visibility_tween and _tentacles_visibility_tween.is_valid():
		_tentacles_visibility_tween.kill()
	_tentacles_visibility_tween = create_tween()
	_tentacles_visibility_tween.tween_property($Tentacles, "modulate:a", 0.0, 0.15)
	_tentacles_visibility_tween.tween_callback($Tentacles.set.bind("visible", false))

func showTentacles() -> void :
	if _tentacles_visibility_tween and _tentacles_visibility_tween.is_valid():
		_tentacles_visibility_tween.kill()
	$Tentacles.visible = true
	$Tentacles.modulate.a = 0.0
	_tentacles_visibility_tween = create_tween()
	_tentacles_visibility_tween.tween_property($Tentacles, "modulate:a", 1.0, 0.2)

func attachCarry(body):
	_ensureFreeFromKunaiCarrier(body)
	Level.drops.network_pickup(body, playerId)

func restoreConverterGravity(body) -> void :
	if body.carryableType != "resource":
		return
	for p in body.physicsOverrides:
		if p.creator == body:
			p.gravity_scale = 1.0
			p.linear_damp = 1.0
	body.removePhysicsOverride(Level.drops.synchronizer)

func _attachCarryInternal(body) -> void :
	if carriedCarryables.has(body):
		return

	var max_carry: int = Keeper4GameplaySettings.MAX_CARRY
	if not Keeper4GameplaySettings.MULTI_CARRY_ALL:
		var has_resource: = body is Drop
		if not has_resource:
			for c in carriedCarryables:
				if c is Drop:
					has_resource = true
					break
		if has_resource:
			max_carry = 1
	if carriedCarryables.size() >= max_carry:
		restoreConverterGravity(body)
		return

	var tentacle = $Tentacles.get_carrying_tentacle()
	if not tentacle:
		tentacle = $Tentacles.get_available_carrying_tentacle()
	if tentacle and tentacle.grab_resource(body):
		$Pickup.startSound()

	body.unfocusCarry(self)
	if body == focussedUsable:
		focussedUsable = null

func _physics_process(delta):
	super._physics_process(delta)
	var maxSpeedupAtPunches: = float(Data.of(playerId + ".keeper4.maxSpeedupAtPunches"))
	currentSpeedup = pow(max(0, tilePunchCount) / maxSpeedupAtPunches, 0.35)

	$Light3D.visible = position.y > 0

	var speedBuff = Data.ofOr(playerId + ".keeper.speedBuff", 0)
	var drillBuff = Data.ofOr(playerId + ".keeper.drillBuff", 0)
	%BuffedSprite.visible = (speedBuff > 0 or drillBuff > 0) and not isInsideStation
	var mining_duration = _compute_mining_duration()[1]
	var clamped_vol = max(ease(mining_duration, 3.0), 0.0001)
	$UpgradeSounds / Rage_loop.baseVolume = linear_to_db(clamped_vol)
	if mining_duration > 0 and not $UpgradeSounds / Rage_loop.playing:
		$UpgradeSounds / Rage_loop.startSound()
	if mining_duration == 0 and $UpgradeSounds / Rage_loop.playing:
		$UpgradeSounds / Rage_loop.stop()
	$Tentacles.set_speed_buildup(mining_duration)
	if isInsideStation or GameWorld.paused or disabled:
		$MoveSound.stop()
		return

	var attached_count: int = $Tentacles.get_planted_count()
	var move_speed: float = Data.ofOr(playerId + ".keeper4.movespeed", 130.0) + speedBuff * Keeper4GameplaySettings.SPEED_BUFF_SCALE
	var effective_move_speed: = move_speed

	if is_searching_next_tile or is_moving_to_mining_pos:
		var speed_multiplier: float = lerp(Keeper4GameplaySettings.MINING_POSITION_SPEED_MULTIPLIER_MIN, Keeper4GameplaySettings.MINING_POSITION_SPEED_MULTIPLIER_MAX, currentSpeedup)
		effective_move_speed = effective_move_speed * speed_multiplier

	if not isMiningMode and not isSpawningHole:
		timeSinceLastPunch += delta
		var speedupretention = Data.ofOr(playerId + ".keeper4.speedupretention", 0.0)
		if timeSinceLastPunch > speedupretention * 5.0:
			var loss = 0.5 * (20 + maxSpeedupAtPunches)

			tilePunchCount = clamp(tilePunchCount - loss * delta * (1.0 - speedupretention), 0, maxSpeedupAtPunches)

	if externallyMoved:
		if $Sprite2D.animation != "default":
			$Sprite2D.play("default")
		return

	if is_forced_movement:
		_handle_forced_movement(delta, attached_count)
	elif isMiningMode:
		_handle_mining_movement(delta, effective_move_speed, attached_count)
	elif isSpawningHole:
		if _hole_retreat_timer > 0:
			var away_dir: Vector2 = (global_position - holeSpawnTargetPos).normalized()
			_handle_normal_movement(delta, effective_move_speed, attached_count, away_dir)
		else:
			_handle_normal_movement(delta, effective_move_speed, attached_count)
	else:
		_handle_normal_movement(delta, effective_move_speed, attached_count)

	var tentacle_input = moveDirectionInput
	if isMiningMode and is_searching_next_tile:
		tentacle_input = continuous_mining_direction
	var is_actively_mining: bool = isMiningMode and not is_moving_to_mining_pos and not is_searching_next_tile
	$Tentacles.update_follow(tentacle_input, velocity, delta, currentMiningTile, is_actively_mining)

	if not is_actively_mining:
		$Tentacles.check_and_detach_overstretched()

	if _spawn_freeze_timer > 0:
		_spawn_freeze_timer -= delta
		velocity = Vector2.ZERO
	else:
		move_and_slide_custom()

	if is_searching_next_tile:
		var distance_traveled: float = (global_position - mining_oscillation_base_pos).dot(continuous_mining_direction)
		if distance_traveled > Keeper4GameplaySettings.MINING_SEARCH_MAX_DISTANCE:
			stopMining()
		elif moveDirectionInput.dot(continuous_mining_direction) < 0.5:
			if Data.ofOr(playerId + ".keeper4.losespeedupondirectionchange", false):
				tilePunchCount = 0.0
			stopMining()
		else:
			var tile = _get_tile_in_direction(continuous_mining_direction)
			if tile and tile.has_meta("destructable") and tile.get_meta("destructable") and tile.coord != _last_destroyed_tile_coord:
				currentMiningTile = tile
				mining_target_position = _find_adjacent_empty_tile_center(tile, continuous_mining_direction)
				is_searching_next_tile = false
				is_moving_to_mining_pos = true
				mining_oscillation_base_pos = mining_target_position
				if not tile.destroyed.is_connected(_on_mining_tile_destroyed):
					tile.destroyed.connect(_on_mining_tile_destroyed.bind(tile), CONNECT_ONE_SHOT)
			elif tile and not (tile.has_meta("destructable") and tile.get_meta("destructable")):
				stopMining()

	$Sprite2D.position.y = 0
	$Tentacles.position.y = 0
	$Sprite2D.rotation = 0

	if $Tentacles.is_attached():
		$Tentacles.velocity = velocity

	_handle_mining(delta)
	_handle_effects(delta)
	updateInteractables()
	updateCarryables()
	_handle_hole_punching(delta)

func _handle_hole_punching(delta):
	if not isSpawningHole:
		return

	if _hole_retreat_timer > 0:
		_hole_retreat_timer -= delta
		var dist_to_hole: float = global_position.distance_to(holeSpawnTargetPos)
		if _hole_retreat_timer > 0 and dist_to_hole < Keeper4GameplaySettings.HOLE_RETREAT_DISTANCE:
			return
		_hole_retreat_timer = 0.0
		_hole_punch_timer = 0.0

	var dist = global_position.distance_to(holeSpawnTargetPos)
	if dist > Keeper4GameplaySettings.HOLE_CANCEL_DISTANCE:
		stopHolePunch()
		return

	_hole_punch_timer -= delta
	if _hole_punch_timer > 0:
		return


	if not holeSpawnTentacle.can_hit():
		return

	var holepunchspeed: float = 1.0

	if isSurfacePunching:
		holeSpawnTentacle.hit_tile(holeSpawnTarget)
		holeSpawnTentacle.start_hit(Keeper4GameplaySettings.HOLE_SPAWN_PUNCH_DURATION)
		_hole_punch_timer = Keeper4GameplaySettings.HOLE_PUNCH_BASE_INTERVAL / (holepunchspeed * Keeper4GameplaySettings.SURFACE_PUNCH_SPEED_SCALE)
		var hit_delay: float = Keeper4GameplaySettings.HOLE_SPAWN_PUNCH_DURATION * Keeper4GameplaySettings.HOLE_PUNCH_HIT_PERCENT
		if _punch_hit_tween and _punch_hit_tween.is_valid():
			_punch_hit_tween.kill()
		_punch_hit_tween = create_tween()
		_punch_hit_tween.tween_callback(_on_surface_knock).set_delay(hit_delay)
		return

	if _hole_punch_target == null and is_multiplayer_authority():
		var hole: = Level.getDome(teamId).goblins.spawn_hole(playerId, holeSpawnTargetPos)
		_hole_punch_target = hole

	holeSpawnTentacle.hit_tile(holeSpawnTarget)
	holeSpawnTentacle.start_hit(Keeper4GameplaySettings.HOLE_SPAWN_PUNCH_DURATION)

	var hit_delay: float = Keeper4GameplaySettings.HOLE_SPAWN_PUNCH_DURATION * Keeper4GameplaySettings.HOLE_PUNCH_HIT_PERCENT
	if _punch_hit_tween and _punch_hit_tween.is_valid():
		_punch_hit_tween.kill()
	_punch_hit_tween = create_tween()
	_punch_hit_tween.tween_callback(_hole_punch_hit).set_delay(hit_delay)

	_hole_punch_timer = Keeper4GameplaySettings.HOLE_PUNCH_BASE_INTERVAL / holepunchspeed

func _handle_mining(delta):
	if isMiningMode:
		if is_moving_to_mining_pos or is_searching_next_tile:
			return

		if is_anchoring_for_mining:
			var ready_to_mine: = false
			if $Tentacles.get_planted_count() >= 1:
				ready_to_mine = true
			else:
				$Tentacles.force_attach_all(currentMiningTile, continuous_mining_direction)

			if ready_to_mine:
				is_anchoring_for_mining = false
				if $Tentacles.has_mining_tentacles():
					$Tentacles.update_mining_target(currentMiningTile)
				else:
					$Tentacles.assign_initial_mining_tentacles(currentMiningTile)
			else:
				return

		if not is_instance_valid(currentMiningTile):
			var tile = _get_tile_in_direction(currentMiningDirection)
			if tile and tile.has_meta("destructable") and tile.get_meta("destructable"):
				currentMiningTile = tile
			else:
				$Tentacles.clear_mining_tentacles()

		if is_instance_valid(currentMiningTile):
			if not $Tentacles.has_mining_tentacles():
				$Tentacles.assign_initial_mining_tentacles(currentMiningTile)
			else:
				$Tentacles.update_mining_target(currentMiningTile)

			for tentacle in $Tentacles.get_mining_tentacles():
				if tentacle.is_carrying():
					continue
				if tentacle.is_mining_attack_done():
					_apply_mining_damage(currentMiningTile)
					tentacle.acknowledge_mining_attack()

			var any_attacking: = false
			for tentacle in $Tentacles.get_mining_tentacles():
				if not tentacle.is_carrying() and tentacle.mining_attack_active:
					any_attacking = true
					break
			var duration: Array = _compute_mining_duration()
			if not any_attacking and is_instance_valid(currentMiningTile):
				var active_tentacle = _get_active_mining_tentacle()
				if active_tentacle and active_tentacle.can_start_mining_attack():
					active_tentacle.hit_tile(currentMiningTile)
					active_tentacle.start_mining_attack(duration[0])
					if _get_available_mining_tentacle_count() == 2:
						_advance_mining_tentacle_index()
			if _current_dig_loop:
				var target_vol: float = lerpf(-20.0, _dig_max_volume(), currentSpeedup)
				_current_dig_loop.baseVolume = target_vol
				if not _current_dig_loop.playing:
					_current_dig_loop._start()
	else:
		if holeSpawnTentacle == null:
			$Tentacles.clear_mining_tentacles()
		currentMiningTile = null

func _get_active_mining_tentacle():
	var mining_tents: Array = $Tentacles.get_mining_tentacles()
	if mining_tents.is_empty():
		return null

	for i in range(mining_tents.size()):
		var index: int = (currentMiningTentacleIndex + i) % mining_tents.size()
		var tentacle = mining_tents[index]
		if not tentacle.is_carrying():
			return tentacle
	return null

func _get_other_mining_tentacle(active_tentacle):
	var mining_tents: Array = $Tentacles.get_mining_tentacles()
	if mining_tents.size() < 2:
		return null

	for tentacle in mining_tents:
		if tentacle != active_tentacle and not tentacle.is_carrying():
			return tentacle
	return null

func _get_available_mining_tentacle_count() -> int:
	var count: = 0
	for tentacle in $Tentacles.get_mining_tentacles():
		if not tentacle.is_carrying():
			count += 1
	return count

func _advance_mining_tentacle_index():
	var mining_tents: Array = $Tentacles.get_mining_tentacles()
	if mining_tents.is_empty():
		return

	currentMiningTentacleIndex = (currentMiningTentacleIndex + 1) % mining_tents.size()
	if mining_tents[currentMiningTentacleIndex].is_carrying():
		currentMiningTentacleIndex = (currentMiningTentacleIndex + 1) % mining_tents.size()

func _compute_mining_duration() -> Array:
	var mod: float = min(1.0, tilePunchCount / float(Data.ofOr(playerId + ".keeper4.maxSpeedupAtPunches", 12)))
	$Sprite2D.speed_scale = 0.6 + 1.6 * mod
	mod = pow(mod, 0.3)
	var duration: float = lerp(float(Data.ofOr(playerId + ".keeper4.maxpunchdelay", 0.6)), float(Data.ofOr(playerId + ".keeper4.minpunchdelay", 0.35)), mod)
	return [duration, mod]

func _apply_mining_damage(tile):
	DrillHitTestRay.rotation = currentMiningDirection.angle()
	DrillHitTestRay.force_raycast_update()
	var dir: Vector2 = global_position - tile.global_position
	hit_tile(tile, dir)

func _handle_effects(delta):
	var has_input: = moveDirectionInput.length() > 0.1

	if has_input:
		trail_particles.emitting = false
		$MoveSound.stop()
		$StillSound.stop()
	else:
		trail_particles.emitting = velocity.length() > 10.0 and hitCooldown <= 0.0
		trail_particles.process_material.angle_min = - velocity.angle()
		trail_particles.process_material.angle_max = - velocity.angle()


	if isSpawningHole:
		var hole_dir: Vector2 = holeSpawnTargetPos - global_position
		if abs(hole_dir.x) > abs(hole_dir.y):
			$Sprite2D.play("left" if hole_dir.x < 0 else "right")
		else:
			$Sprite2D.play("up" if hole_dir.y < 0 else "down")
	elif isMiningMode and currentMiningDirection.length_squared() > 0.1:
		if abs(currentMiningDirection.x) > abs(currentMiningDirection.y):
			$Sprite2D.play("punch_left" if currentMiningDirection.x < 0 else "punch_right")
		else:
			$Sprite2D.play("punch_up" if currentMiningDirection.y < 0 else "punch_down")
	elif velocity.length() > 10.0:
		var abs_x: float = abs(velocity.x)
		var abs_y: float = abs(velocity.y)
		if _anim_horizontal:
			if abs_y > abs_x * 1.3:
				_anim_horizontal = false
		else:
			if abs_x > abs_y * 1.3:
				_anim_horizontal = true
		if _anim_horizontal:
			$Sprite2D.play("left" if velocity.x < 0 else "right")
		else:
			$Sprite2D.play("up" if velocity.y < 0 else "down")
	else:
		$Sprite2D.play("default")

func currentSpeed() -> float:
	return (Data.ofOr(playerId + ".keeper4.movespeed", 0) + Data.ofOr(playerId + ".keeper.speedBuff", 0) * Keeper4GameplaySettings.SPEED_BUFF_SCALE) * 23.3

func updateCarryables():
	if not is_multiplayer_authority():
		return

	if not is_instance_valid(focussedCarryable):
		focussedCarryable = null

	if focussedCarryable:
		if not focussedCarryable.canFocusCarry(teamId)\
		or not carryables.has(focussedCarryable)\
		or carriedCarryables.has(focussedCarryable)\
		or (focussedCarryable.is_in_group("usables") and not usables.has(focussedCarryable.get_meta("usable"))):
			focussedCarryable.unfocusCarry(self)
			focussedCarryable = null

	var potentialCarryables: = []
	for carryable in carryables:
		if not is_instance_valid(carryable):
			continue

		if not carriedCarryables.has(carryable)\
		and carryable.canFocusCarry(teamId)\
		and (pickupType == "" or pickupType == carryable.carryableType)\
		and ( not carryable.is_in_group("usables") or usables.has(carryable.get_meta("usable"))):
			potentialCarryables.append(carryable)

	potentialCarryables.sort_custom(Callable(self, "sortByDistance"))

	for carryable in potentialCarryables:
		if focussedCarryable == carryable:
			return
		else:
			if focussedCarryable:
				focussedCarryable.unfocusCarry(self)
			focussedCarryable = carryable
			focussedCarryable.focusCarry(self)
		return

func pickupHit():
	if isInsideStation or disabled:
		return false

	updateCarryables()
	if focussedCarryable:
		pickup(focussedCarryable)

func pickupHold():
	if isInsideStation or disabled:
		return false
	updateCarryables()
	if focussedCarryable:
		pickup(focussedCarryable)
		pickupType = focussedCarryable.carryableType

func pickupHoldStopped():
	pickupType = ""

func pickup(drop):
	var otherKeeper4: Keeper = null
	for carrier in drop.carriedBy:
		if carrier is Keeper and carrier != self and carrier.techId == "keeper4":
			otherKeeper4 = carrier
			break

	if otherKeeper4:
		if carriedCarryables.size() >= Keeper4GameplaySettings.MAX_CARRY:
			return
		attachCarry(drop)
		return

	for carried in carriedCarryables.duplicate():
		if carried.carrierCount() > 1:
			dropCarry(carried)

	if $Tentacles.get_available_carrying_tentacle():
		attachCarry(drop)

func _get_farthest_available_tentacle(target_pos: Vector2):
	return $Tentacles.get_farthest_available_tentacle(target_pos)

func _get_carrying_tentacle():
	return $Tentacles.get_carrying_tentacle()

func dropHit():
	if isInsideStation or disabled:
		return

	var tentacle = _get_carrying_tentacle()
	if tentacle and tentacle.is_grabbing:
		return
	if not tentacle:
		return

	var now: = Time.get_ticks_msec()
	if now - _last_drop_time_msec < DROP_INTERVAL_MSEC:
		return

	var co_carried: Array = []
	var gadget_to_drop: Carryable = null
	var resource_to_drop: Carryable = null
	for res in tentacle.carried_resources:
		if res.carrierCount() > 1:
			co_carried.append(res)
		elif res.carryableType == "resource":
			resource_to_drop = res
		else:
			gadget_to_drop = res

	if not co_carried.is_empty():
		_last_drop_time_msec = now
		for res in co_carried:
			dropCarry(res)
		return

	var to_drop: Carryable
	if resource_to_drop and input_settings.drop_ressources_before_gadets:
		to_drop = resource_to_drop
	else:
		to_drop = gadget_to_drop if gadget_to_drop else resource_to_drop
	if to_drop == null:
		return

	_last_drop_time_msec = now
	dropCarry(to_drop)

	if moveDirectionInput.length() > 0.3:
		var throw_direction: Vector2 = moveDirectionInput.normalized()
		Level.drops.network_throw_drop(to_drop.UID, throw_direction * Keeper4GameplaySettings.THROW_FORCE)

func dropHold():
	return dropHit()

func _dropCarryInternal(body) -> void :
	var tentacle = _get_carrying_tentacle()
	if is_instance_valid(tentacle):
		tentacle.drop_resource(body)
		$Drop.startSound()

func _get_tile_in_direction(direction: Vector2):
	if direction == Vector2.ZERO:
		return null
	DrillHitTestRay.rotation = direction.angle()
	DrillHitTestRay.force_raycast_update()
	return DrillHitTestRay.get_collider()

func _get_tile_in_direction_for_start(direction: Vector2):
	if direction == Vector2.ZERO:
		return null
	StartDrillHitTestRay.rotation = direction.angle()
	StartDrillHitTestRay.force_raycast_update()
	return StartDrillHitTestRay.get_collider()

func _normalize_to_cardinal(direction: Vector2) -> Vector2:
	if direction.length() < 0.1:
		return Vector2.ZERO

	var abs_x: float = abs(direction.x)
	var abs_y: float = abs(direction.y)

	if abs_x > abs_y * 1.4:
		return Vector2(sign(direction.x), 0)
	elif abs_y > abs_x * 1.4:
		return Vector2(0, sign(direction.y))

	return Vector2.ZERO

func _find_adjacent_empty_tile_center(tile: Node, direction: Vector2) -> Vector2:
	var tile_pos: Vector2 = tile.global_position
	var dir: Vector2 = direction.normalized()
	return tile_pos - (dir * Keeper4GameplaySettings.MINING_POSITION_OFFSET)

func hit_tile(tile, dir):
	var damage = Data.of(playerId + ".keeper4.punchstrength")

	var punch_value: = 1.0
	var drillBuff: float = Data.ofOr(playerId + ".keeper.drillBuff", 0.0)
	if drillBuff > 0.0:
		punch_value += drillBuff * 3.0 * (1.0 - currentSpeedup)
		damage *= 1.0 + drillBuff * currentSpeedup
	tilePunchCount = min(tilePunchCount + punch_value, float(Data.of(playerId + ".keeper4.maxSpeedupAtPunches")))

	if is_multiplayer_authority():
		tile.hit(dir, damage, teamId, techId)
		timeSinceLastPunch = 0.0
		emit_signal("mined", 0.02)
		if Options.shakeDrill:
			InputSystem.getCamera(playerId).shake(20, 0.2, 8)
	if _dig_upgrade_level >= 4:
		$RageHit.baseVolume = lerpf(-20.0, -6.0, currentSpeedup)
		$RageHit.startSound()
	if isMiningMode:
		mining_recoil_offset = Keeper4GameplaySettings.MINING_OSCILLATION_AMPLITUDE

	if tile.health <= 0:
		if currentMiningTile == tile:
			pending_tile_destroyed = true

	emit_signal("tileHit")
	if is_multiplayer_authority():
		synchronizer.network_rpc(playSoundsAndSparks.bind(tile.coord, tile.health, tile.max_health, tile.type, tile.hardness), true)

@rpc("reliable")
func playSoundsAndSparks(tileCoord: Vector2, tileHealth: int, tileMaxHealth: int, tileType: String, tileHardness: int):
	var soundPlayer: AudioStreamPlayer = get_node("TileHitHardness" + str(tileHardness))
	$TileHitPitch.pitch_scale = 0.8 + 0.4 * (1.0 - tileHealth / tileMaxHealth)
	$TileHitPitch.startSound()
	soundPlayer.startSound()

	if has_node("TileHit" + tileType.capitalize()):
		soundPlayer = get_node("TileHit" + tileType.capitalize())
		soundPlayer.startSound()

	var hits_needed_to_destroy: float = float(tileMaxHealth) / float(Data.of(playerId + ".keeper4.punchstrength"))
	emit_sparks(DrillHitTestRay.get_collision_point(), tileType, tileCoord, hits_needed_to_destroy)

@onready var drill_hit = $DrillHit
func emit_sparks(hit_position: Vector2, tileType: String, tileCoord: Vector2, hits_needed_to_destroy: float):
	var tile_type = tileType
	drill_hit.position = to_local(hit_position)
	drill_hit.rotation = DrillHitTestRay.rotation + PI
	drill_hit.frame = 0
	drill_hit.play("hit")
	var clamped_hits = clamp(hits_needed_to_destroy, 1.0, 8.0)
	var particle_amount = int(round(remap(clamped_hits, 1.0, 8.0, 60.0, 10.0)))
	$DrillHit / DrillHitParticles.amount = particle_amount
	$DrillHit / DrillHitParticles.restart()

	var spark_amount = int(round(remap(clamped_hits, 1.0, 8.0, 20.0, 3.0)))
	for _i in range(spark_amount + randi() % 3):
		var s = Data.KEEPER_SPARK.instantiate()
		s.global_position = hit_position
		s.apply_central_impulse(Vector2.RIGHT.rotated(drill_hit.rotation + randf_range(-0.4, 0.4)) * randf_range(30, 150))
		get_parent().call_deferred("add_child", s)

	var dirt_color = Level.map.getBiomeColorByCoord(tileCoord)

	var dirt_amount = int(round(remap(clamped_hits, 1.0, 8.0, 5.0, 0.0)))
	for _i in range(dirt_amount + randi() % 2):
		var t = Data.TILE_DIRT_PARTICLE.instantiate()
		t.modulate = dirt_color
		t.type = tile_type
		t.global_position = hit_position
		t.apply_central_impulse(Vector2.RIGHT.rotated(drill_hit.rotation + randf_range(-0.7, 0.7)) * randf_range(60, 130))
		get_parent().call_deferred("add_child", t)

func _is_metal_surface(collider) -> bool:
	if not collider is PhysicsBody2D:
		return false
	if collider.get_collision_layer_value(32):
		return true
	var node: Node = collider
	while node:
		if node is Dome:
			return true
		node = node.get_parent()
	return false

func _on_tentacle_attached(pos: Vector2, collider: Node):
	if _is_metal_surface(collider):
		if pos.y > 40.0:
			_spawn_tentacle_debris(pos, Keeper4GameplaySettings.METAL_ATTACH_SPARK_COUNT, 0, Keeper4GameplaySettings.METAL_ATTACH_IMPULSE_MIN, Keeper4GameplaySettings.METAL_ATTACH_IMPULSE_MAX, Keeper4GameplaySettings.METAL_ATTACH_SCALE)
		$TentacleAttachMetalSound.pitch_scale = randf_range(0.8, 1.2)
		$TentacleAttachMetalSound.startSound()
	else:
		if pos.y > 40.0:
			_spawn_tentacle_debris(pos, Keeper4GameplaySettings.ATTACH_SPARK_COUNT, Keeper4GameplaySettings.ATTACH_DIRT_COUNT, Keeper4GameplaySettings.ATTACH_IMPULSE_MIN, Keeper4GameplaySettings.ATTACH_IMPULSE_MAX, Keeper4GameplaySettings.ATTACH_SCALE)
		$TentacleAttachSound.pitch_scale = randf_range(0.4, 0.6)
		$TentacleAttachSound.startSound()

func _on_tentacle_detached(pos: Vector2, collider: Node):
	if _is_metal_surface(collider):
		if pos.y > 40.0:
			_spawn_tentacle_debris(pos, Keeper4GameplaySettings.METAL_DETACH_SPARK_COUNT, 0, Keeper4GameplaySettings.METAL_DETACH_IMPULSE_MIN, Keeper4GameplaySettings.METAL_DETACH_IMPULSE_MAX, Keeper4GameplaySettings.METAL_DETACH_SCALE)
		$TentacleDetachMetalSound.pitch_scale = randf_range(1.6, 2.0)
		$TentacleDetachMetalSound.startSound()
	else:
		if pos.y > 40.0:
			_spawn_tentacle_debris(pos, Keeper4GameplaySettings.DETACH_SPARK_COUNT, Keeper4GameplaySettings.DETACH_DIRT_COUNT, Keeper4GameplaySettings.DETACH_IMPULSE_MIN, Keeper4GameplaySettings.DETACH_IMPULSE_MAX, Keeper4GameplaySettings.DETACH_SCALE)
		$TentacleDetachSound.pitch_scale = randf_range(1.4, 1.6)
		$TentacleDetachSound.startSound()

func _spawn_tentacle_debris(hit_position: Vector2, spark_count: int, dirt_count: int, impulse_min: float, impulse_max: float, debris_scale: float):
	var dir_from_keeper = (hit_position - global_position).normalized()
	var base_angle = dir_from_keeper.angle() + PI

	for _i in range(spark_count + randi() % 2):
		var s = Data.KEEPER_SPARK.instantiate()
		s.global_position = hit_position
		s.apply_central_impulse(Vector2.RIGHT.rotated(base_angle + randf_range(-0.6, 0.6)) * randf_range(impulse_min, impulse_max))
		get_parent().call_deferred("add_child", s)
		s.ready.connect(_apply_debris_scale.bind(s, debris_scale), CONNECT_ONE_SHOT)

	var tileCoord = Level.map.getTileCoord(hit_position)
	var dirt_color = Level.map.getBiomeColorByCoord(tileCoord)

	for _i in range(dirt_count + randi() % 2):
		var t = Data.TILE_DIRT_PARTICLE.instantiate()
		t.modulate = dirt_color
		t.type = "dirt"
		t.global_position = hit_position
		t.apply_central_impulse(Vector2.RIGHT.rotated(base_angle + randf_range(-0.8, 0.8)) * randf_range(impulse_min * 1.5, impulse_max * 1.5))
		get_parent().call_deferred("add_child", t)
		t.ready.connect(_apply_debris_scale.bind(t, debris_scale), CONNECT_ONE_SHOT)

func _apply_debris_scale(node: Node, debris_scale: float):
	node.scale *= debris_scale
	if node.has_node("Sprite2D"):
		node.get_node("Sprite2D").scale *= debris_scale

func disableEffects():
	$StillSound.stop()

func enableEffects():
	$StillSound.startSound()

func kill():
	if has_node("Light3D/LightSmall"):
		$Light3D / LightSmall.set_light_active(false)
	$Light3D / LightBig.set_light_active(false)
	queue_free()
	super.kill()

func find_overlapping_hole(spawn_pos: Vector2) -> Node2D:
	var holes = get_tree().get_nodes_in_group("goblin_holes")
	var radius_sq: float = Keeper4GameplaySettings.HOLE_CANCEL_DISTANCE * Keeper4GameplaySettings.HOLE_CANCEL_DISTANCE
	for hole in holes:
		if not is_instance_valid(hole):
			continue
		if hole.is_entrance_hole:
			continue
		if hole.hole_state != hole.HoleState.INCOMPLETE:
			continue
		if hole.punch_count >= Keeper4GameplaySettings.HOLE_TOTAL_PUNCHES:
			continue
		var dist_sq: float = spawn_pos.distance_squared_to(hole.global_position)
		if dist_sq < radius_sq:
			return hole
	return null

func find_hole_in_range(pos: Vector2) -> Node2D:
	var holes = get_tree().get_nodes_in_group(teamId + "-goblin_holes")
	var radius_sq: float = Keeper4GameplaySettings.SQUAD_TRIGGER_RANGE * Keeper4GameplaySettings.SQUAD_TRIGGER_RANGE
	for hole in holes:
		if not is_instance_valid(hole):
			continue
		if hole.is_entrance_hole:
			continue
		if hole.hole_state != hole.HoleState.DUG_OUT and not hole._dig_animation_pending:
			continue
		var dist_sq: float = pos.distance_squared_to(hole.global_position)
		if dist_sq < radius_sq:
			return hole
	return null

func networkStartHolePunch():
	synchronizer.network_rpc(startHolePunch.bind(global_position), true)

@rpc("reliable", "any_peer")
func startHolePunch(playerPosition: Vector2):
	if isSpawningHole:
		return

	var tileCoord = Level.map.getTileCoord(playerPosition)
	var pos = Level.map.getTilePos(tileCoord)

	if not Level.map.is_tile_empty(tileCoord) or Level.map.is_landmark_tile(tileCoord):
		return

	var overlapping_hole = find_overlapping_hole(pos)
	if overlapping_hole:
		_hole_punch_target = overlapping_hole
		pos = overlapping_hole.global_position
	else:
		_hole_punch_target = null

	_surface_punch_hole = find_hole_in_range(pos)
	var hole_nearby: bool = _surface_punch_hole != null
	var tentacle = _get_farthest_available_tentacle(pos)
	if not tentacle:
		return

	if isMiningMode:
		stopMining()

	isSpawningHole = true
	isSurfacePunching = hole_nearby and _hole_punch_target == null
	_surface_punch_count = 0
	_squad_triggered_this_punch = false
	holeSpawnTargetPos = pos
	holeSpawnTentacle = tentacle

	holeSpawnTarget = _create_hole_target_tile(pos)
	if isSurfacePunching:
		tentacle.surface_punch_mode = true
	tentacle.set_mining_mode(true, holeSpawnTarget)

	if isSurfacePunching:
		_hole_retreat_timer = 0.0
	else:
		var dist_to_hole: float = playerPosition.distance_to(pos)
		if dist_to_hole < Keeper4GameplaySettings.HOLE_RETREAT_DISTANCE:
			_hole_retreat_timer = Keeper4GameplaySettings.HOLE_RETREAT_TIMEOUT
		else:
			_hole_retreat_timer = 0.0
	_hole_punch_timer = 0.0

func networkStopHolePunch():
	synchronizer.network_rpc(stopHolePunch, true)

@rpc("reliable", "any_peer")
func stopHolePunch():
	if not isSpawningHole:
		return

	if _punch_hit_tween and _punch_hit_tween.is_valid():
		_punch_hit_tween.kill()
	_punch_hit_tween = null

	if not isSurfacePunching and _hole_punch_target != null:
		_hole_punch_target.on_punch_stopped()
	_hole_punch_target = null

	isSpawningHole = false
	isSurfacePunching = false
	_surface_punch_count = 0
	_surface_punch_hole = null
	_squad_triggered_this_punch = false
	_hole_retreat_timer = 0.0

	holeSpawnTentacle.surface_punch_mode = false
	holeSpawnTentacle.set_mining_mode(false)
	holeSpawnTentacle = null

	holeSpawnTarget.queue_free()
	holeSpawnTarget = null

func _on_surface_knock():
	if not isSpawningHole or not isSurfacePunching:
		return
	$KnockSound.startSound()
	if is_instance_valid(_surface_punch_hole):
		_surface_punch_hole.pulse()
	_surface_punch_count += 1
	if _surface_punch_count >= Keeper4GameplaySettings.SQUAD_TRIGGER_KNOCK_COUNT and not _squad_triggered_this_punch:
		var squad_count: int = Data.ofOr(playerId + ".keeper4.holesquad", 0)
		if squad_count > 0 and is_instance_valid(_surface_punch_hole) and _surface_punch_hole.hole_state == _surface_punch_hole.HoleState.DUG_OUT:
			var sd: Goblins.SquadData = Level.getDome(teamId).goblins.get_squad_data(playerId)
			var can_spawn: bool = sd.contexts.size() < Data.ofOr(playerId + ".keeper4.squadcount", 1)
			for ctx in sd.contexts:
				if ctx.hole == _surface_punch_hole and ctx.remaining > 0:
					can_spawn = false
			if can_spawn:
				Level.getDome(teamId).goblins.network_trigger_squad(self, _surface_punch_hole)
				$CBSquad_summon.startSound()
				squad_triggered.emit(_surface_punch_hole)
			_squad_triggered_this_punch = true
		_surface_punch_count = 0

func _hole_punch_hit():
	if not isSpawningHole:
		return

	$TileHitPitch.pitch_scale = Keeper4GameplaySettings.HOLE_PUNCH_PITCH
	$TileHitPitch.startSound()
	$TileHitHardness0.startSound()
	$HolePunch.startSound()

	if not is_multiplayer_authority():
		return

	_hole_punch_target.receive_punch()

	if _hole_punch_target.punch_count >= Keeper4GameplaySettings.HOLE_TOTAL_PUNCHES:
		networkStopHolePunch()

func _create_hole_target_tile(pos: Vector2) -> Node2D:
	var target = Node2D.new()
	Level.map.add_child(target)
	target.global_position = pos
	target.set_meta("hole_target", true)
	return target

func setSkin(skinId: String, colorId: String = self.colorId):
	super.setSkin(skinId, colorId)
	%Tentacles.set_color(colorId, remapColorIdPerPalette)

func startTeleportation(source, duration: float, fromPos: Vector2, goalPos: Vector2, allowCarryableTeleportation: bool, allowLargeDropTeleportation: = false):
	super.startTeleportation(source, duration, fromPos, goalPos, allowCarryableTeleportation, allowLargeDropTeleportation)
	hideTentacles()

func teleportComplete() -> void :
	for t in $Tentacles.tentacles:
		if t.is_attached():
			t.detach()
	super.teleportComplete()
	while (disabled):
		await get_tree().process_frame
	showTentacles()
