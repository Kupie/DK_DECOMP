class_name Pinball
extends RigidBody2D

signal destroyed
signal exploded(playerId)
signal hit_tile(tile, pinballhit_scale, buffed, position)
signal bounce_sound_played(id: int, volume: float)
signal reflected

var lifeTime: float
var timeAlive: float


var UID: = -1

var baseDamage: float
var damageDealt: = 0.0
var damageModNextHit: float
var size: = 1.0

var speedScale: = 1.0

var maxSpeed: float
var bumpSpeedup: = 30

var generation: = 1
var hitCounter: = 0
var removeBlockers: = 2
var consecutiveIndestructibleHits: = 0
var reflectCounter: = 0
var consecutiveReflections: = 0
var is_destroyed: = false

var approachingBody

var is_paused: = false

var playerId: String
var keeper: Keeper

var destroyTileCooldown: = {}
var oldVelocity = Vector2()

var bounce_sounds = {}

func _ready():
	baseDamage = Data.of(playerId + ".keeper2.spherebasedamage")
	maxSpeed = Data.of(playerId + ".keeper2.spherespeed")
	lifeTime = Data.of(playerId + ".keeper2.spherebaselifetime") * size
	damageModNextHit = Data.of(playerId + ".keeper2.sphereadditionalfirsthitdamage")
	$Sprite2D.play("ready")
	$Trail.amount = 20
	$Trail.emitting = true
	Style.init($Sprite2D)
	linear_damp = 0.0

	$RayCastFront.enabled = is_multiplayer_authority()
	$Amb.startSound()

	pauseChanged()

	Achievements.addIfOpen(self, "KEEPER2_REFLECTIONS", playerId)
	Achievements.addIfOpen(self, "KEEPER2_SPHEREDURATION", playerId)

	bounce_sounds = {
		0: $BounceSound1, 
		1: $BounceSound2, 
		2: $BounceSound3
	}

	freeze = !is_multiplayer_authority()
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC

	if not Keepers.hasKeeper(playerId):

		return

	keeper = Keepers.getKeeper(playerId)
	keeper.tree_exiting.connect(on_keeper_tree_exiting)

func on_keeper_tree_exiting() -> void :
	keeper.synchronizer.pinballs.erase(UID)
	queue_free()

func serialize() -> Dictionary:

	var data = {}
	data["meta.priority"] = 100
	data["meta.kind"] = "generic"
	data["linear_velocity"] = var_to_str(linear_velocity)
	data["oldVelocity"] = var_to_str(oldVelocity)
	data["lifeTime"] = lifeTime
	data["timeAlive"] = timeAlive
	data["baseDamage"] = baseDamage
	data["damageDealt"] = damageDealt
	data["damageModNextHit"] = damageModNextHit
	data["size"] = size
	data["speedScale"] = speedScale
	data["maxSpeed"] = maxSpeed
	data["bumpSpeedup"] = bumpSpeedup
	data["generation"] = generation
	data["hitCounter"] = hitCounter
	data["removeBlockers"] = removeBlockers
	data["consecutiveIndestructibleHits"] = consecutiveIndestructibleHits
	data["reflectCounter"] = reflectCounter
	data["consecutiveReflections"] = consecutiveReflections
	data["destroyed"] = is_destroyed
	data["is_paused"] = is_paused
	data["playerId"] = playerId

	var d: = []
	for coord in destroyTileCooldown:
		var entry: = [var_to_str(coord), var_to_str(destroyTileCooldown[coord][0]), var_to_str(destroyTileCooldown[coord][1])]
		d.append(entry)
	data["destroyTileCooldown"] = var_to_str(d)

	return data

func deserialize(data: Dictionary):
	linear_velocity = BackwardCompatibilityUtils.str_to_var(data["linear_velocity"])
	oldVelocity = BackwardCompatibilityUtils.str_to_var(data["oldVelocity"])
	lifeTime = data["lifeTime"]
	timeAlive = data["timeAlive"]
	baseDamage = data["baseDamage"]
	damageDealt = data["damageDealt"]
	damageModNextHit = data["damageModNextHit"]
	size = data["size"]
	speedScale = data["speedScale"]
	maxSpeed = data["maxSpeed"]
	bumpSpeedup = data["bumpSpeedup"]
	generation = data["generation"]
	hitCounter = data["hitCounter"]
	removeBlockers = data["removeBlockers"]
	consecutiveIndestructibleHits = data["consecutiveIndestructibleHits"]
	reflectCounter = data["reflectCounter"]
	consecutiveReflections = data["consecutiveReflections"]
	is_destroyed = data["destroyed"]
	is_paused = data["is_paused"]
	playerId = data["playerId"]

	var d: Array = str_to_var(data["destroyTileCooldown"])
	destroyTileCooldown = {}
	for entry in d:
		destroyTileCooldown[str_to_var(entry[0])] = [entry[1], str_to_var(entry[2])]
	pauseChanged()


	if is_destroyed:
		is_destroyed = false
		destroy()

	keeper = Keepers.getKeeper(playerId)
	keeper.tree_exiting.connect(on_keeper_tree_exiting)
	keeper.synchronizer.on_pinball_spawned(self)

func _physics_process(delta):
	if GameWorld.paused or is_destroyed:
		_recentlyPaused = true
		return

	var speedScale = (linear_velocity.length() - 40) / 150.0
	var sizeScale = min(1.0, (0.6 + 1.0 * speedScale)) * min(size, 1.4)
	$Sprite2D.scale = Vector2.ONE * sizeScale
	$Trail.process_material.scale_min = sizeScale
	$Trail.process_material.scale_max = sizeScale
	$CollisionShape2D.shape.radius = 4.0
	$Sprite2D.modulate.r = 0.5 + speedScale * 0.5
	$Sprite2D.modulate.g = 0.25 + speedScale * 0.75
	$RayCastFront.rotation = linear_velocity.angle() - CONST.PI_HALF - rotation
	$RayCastFront.position = Vector2.DOWN.rotated($RayCastFront.rotation + PI) * 20

	if not is_multiplayer_authority():
		return

	_worldPauseIgnoresReflectWorkaround(delta)

	lifeTime = lifeTime - delta
	timeAlive += delta

	if lifeTime <= 0.0:
		linear_damp = 3.0
		$Trail.emitting = false
		if linear_velocity.length() <= 60.0:
			destroy()
			return

	for coord in destroyTileCooldown.keys().duplicate():
		var data: Array = destroyTileCooldown[coord]
		data[0] -= delta
		if data[0] <= 0.0:
			var otherTile = Level.map.getTile(Vector2i(coord))

			if otherTile and Data.isDestructable(otherTile):
				var dir = data[1] - otherTile.coord
				if otherTile.type == "dirt":
					otherTile.hit(dir, otherTile.max_health, keeper.teamId)
					showHitEffect(otherTile, 1.0, false, dir * 0.5)
				else:
					otherTile.hit(dir, data[2] * 0.5, keeper.teamId)
			destroyTileCooldown.erase(coord)

	if $RayCastFront.enabled:
		var c = $RayCastFront.get_collider()
		if c:
			c.sphereApproaching(self)
			approachingBody = c
		elif approachingBody:
			approachingBody.spherePassed(self)
			approachingBody = null

	var isAlive = lifeTime > 0.0
	var aliveMinimalSpeed: float = maxSpeed * 0.25
	var aliveMinimalSpeedSqr: float = aliveMinimalSpeed * aliveMinimalSpeed
	var directionDetermined: bool = not linear_velocity.is_zero_approx()
	var isMovingTooSlow: bool = linear_velocity.length_squared() < aliveMinimalSpeedSqr
	var needsToMaintainMinimalSpeed: bool = isAlive and directionDetermined and isMovingTooSlow
	if needsToMaintainMinimalSpeed:
		linear_velocity = linear_velocity.normalized() * aliveMinimalSpeed



var _forceDirectionAfterReflect: Vector2 = Vector2.RIGHT
var _forceDirectionDuration: float = 0.0
var _recentlyPaused: bool = false
func _worldPauseIgnoresReflectWorkaround(inDelta: float) -> void :
	var reflectedRecently: bool = _forceDirectionDuration > 0.0
	_forceDirectionDuration -= inDelta
	if ( not _recentlyPaused) or ( not reflectedRecently):
		return

	var isMovingInOppositeDirection: bool = linear_velocity.dot(_forceDirectionAfterReflect) < 0.0
	if isMovingInOppositeDirection:
		linear_velocity = linear_velocity.length() * _forceDirectionAfterReflect
	_recentlyPaused = false

func reflect():
	reflected.emit()

func onPinballReflected():
	if is_multiplayer_authority():
		if reflectCounter < 2:
			lifeTime += 0.5
		damageModNextHit = Data.of(playerId + ".keeper2.reflectnexthitdamage")
		var speedup = 1.0 + Data.of(playerId + ".keeper2.reflectspeed")
		var direction: Vector2 = - linear_velocity - linear_velocity.normalized() * maxSpeed * speedup
		apply_central_impulse(direction)
		_forceDirectionAfterReflect = direction.normalized()
		_forceDirectionDuration = 0.15




		if reflectCounter > 0:
			consecutiveReflections += 1
		else:
			consecutiveReflections = 0
		reflectCounter = 2
	$ReflectionBaseSound.startSound()
	$Sprite2D.modulate.b = 0.0

func onPinballCaught() -> void :
	var slice = preload("res://content/keeper/keeper2/SplitSlice.tscn").instantiate()
	slice.global_position = global_position
	slice.global_rotation = linear_velocity.angle()
	Keepers.getKeeper(playerId).get_parent().add_child(slice)

	linear_damp = 12
	$Sprite2D.play("vanish")
	$Sprite2D.frame = 0
	if approachingBody:
		approachingBody.spherePassed(self)
		approachingBody = null
	$RayCastFront.set_deferred("enabled", false)
	is_destroyed = true
	$SphereCatchSound.startSound()

func destroy():
	if is_destroyed:
		return

	destroyed.emit()

func onPinballDestroyed() -> void :
	linear_damp = 8
	$Sprite2D.play("vanish")
	$Sprite2D.frame = 0
	$VanishSound.startSound()
	if approachingBody:
		approachingBody.spherePassed(self)
		approachingBody = null
	$RayCastFront.set_deferred("enabled", false)
	is_destroyed = true

func _on_Pinball_body_entered(body):
	if not body or is_destroyed:
		return

	if is_paused:
		return

	$Sprite2D.modulate.b = 1.0

	if not is_multiplayer_authority():
		return

	var velocity = linear_velocity.length()
	if velocity <= 20.0:
		destroy()
		return

	var dir = global_position - body.global_position
	var surface: Vector2
	if abs(dir.x) > abs(dir.y):
		surface = Vector2(0, linear_velocity.y)
	else:
		surface = Vector2(linear_velocity.x, 0)
	var steepnessMod: = 1.0 - surface.normalized().dot(linear_velocity.normalized())
	if steepnessMod < 0.2:
		return

	var volume: = -6 + 6 * steepnessMod
	var bsId = getFreeBounceSoundId()
	playBounceSound(bsId, volume)
	bounce_sound_played.emit(bsId, volume)

	var isDestructible = body.has_meta("destructable") and body.get_meta("destructable")

	if isDestructible:
		var damage = baseDamage + baseDamage * max(0, (velocity - 100)) / 100.0

		damage += Data.of(playerId + ".keeper2.spherefractiondamage") * body.max_health
		damage = damage * steepnessMod * size
		var mod = 1.0 + damageModNextHit
		damageModNextHit *= 0.5
		damage *= mod
		hitCounter += 1

		body.hit(dir, damage, keeper.teamId)
		damageDealt += damage

		showHitEffect(body, clamp(velocity / 150.0, 0.25, 1), damageModNextHit > 0.2)


		lifeTime = max(lifeTime, 0.5)
		consecutiveIndestructibleHits = 0
		if Data.of(playerId + ".keeper2.pinballdestroyadjacenttiles") and generation == 1:
			var tileDir: Vector2 = body.coord - Vector2(Level.map.getTileCoord(global_position))
			for offAngle in [CONST.PI_HALF, - CONST.PI_HALF]:
				var otherDir = tileDir.rotated(offAngle)
				var otherCoord = body.coord + otherDir
				if body.health <= 0:






					destroyTileCooldown[otherCoord] = [randf_range(0.05, 0.2), body.coord, damage]
				else:
					var otherTile = Level.map.getTile(otherCoord)
					if otherTile and otherTile.has_meta("destructable") and otherTile.get_meta("destructable"):
						otherTile.hit(body.coord - otherTile.coord, damage * 0.5, keeper.teamId)
	else:
		consecutiveIndestructibleHits += 1

	if consecutiveIndestructibleHits > 5:
		destroy()

	if linear_velocity.length() < maxSpeed * (1.0 + 0.5 * Data.of(playerId + ".keeper.drillBuff")):
		apply_central_impulse(linear_velocity.normalized() * bumpSpeedup * steepnessMod)

	reflectCounter -= 1

func showHitEffect(tile, pinballhit_scale, buffed, pos = global_position):
	hit_tile.emit(tile, pinballhit_scale, buffed, pos)
	var pinballhit = preload("res://content/keeper/keeper2/PinballHit.tscn").instantiate()
	Level.viewports.addElement(pinballhit)
	pinballhit.scale = Vector2(pinballhit_scale, pinballhit_scale)
	pinballhit.global_position = pos

	$TileHitSounds.hit(tile, buffed, false)

func playBounceSound(id: int, volume: float):
	var bs = bounce_sounds[id]
	bs.baseVolume = volume
	bs.startSound()

func getFreeBounceSoundId() -> int:
	if not $BounceSound1.playing:
		return 0
	elif not $BounceSound2.playing:
		return 1
	elif not $BounceSound3.playing:
		return 2
	return 0

func explode(explodingPlayerId: String):
	if is_destroyed:
		return

	exploded.emit(explodingPlayerId)

func onPinballExploded(explodingPlayerId: String):
	var ex = load("res://content/keeper/keeper2/Explode.tscn").instantiate()
	ex.position = position
	ex.playerId = explodingPlayerId
	ex.teamId = keeper.teamId
	ex.pinball_UID = UID
	get_parent().add_child(ex)
	queue_free()

func _on_Sprite_animation_finished():
	if $Sprite2D.animation == "vanish":
		removeBlockerFreed()

func removeBlockerFreed():
	removeBlockers -= 1
	if removeBlockers <= 0:
		queue_free()

func pauseChanged():
	if GameWorld.paused:
		if not is_paused:
			oldVelocity = linear_velocity
			set_axis_velocity(Vector2.ZERO)
			freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
			freeze = true
			is_paused = true
	else:
		is_paused = false
		freeze = false
		set_axis_velocity(oldVelocity)

func _on_vanish_sound_sound_duration_elapsed() -> void :
	removeBlockerFreed()

func _on_sphere_catch_sound_sound_duration_elapsed() -> void :
	removeBlockerFreed()
