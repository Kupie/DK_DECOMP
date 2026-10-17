extends SecondaryWeapon

signal state_changed

@export var synchronizer: GadgetSynchronizer

const DISTANCE: = 1000
var dist: float

var active: = false
var shotCooldown: = 0.0

var target: Monster
var pathProbe: PathFollow2D
var cannonStyle: = "0"

var random: RandomNumberGenerator

func _ready():
	Data.listen(self, teamId + ".autocannon.cannonstyle", true)
	Style.init(self)

func propertyChanged(property: String, oldValue, newValue):
	cannonStyle = str(Data.of(teamId + ".autocannon.cannonstyle"))
	if active:
		$Sprite2D.play("start_" + cannonStyle)
	else:
		$Sprite2D.play("stop_" + cannonStyle)

func serialize() -> Dictionary:
	var data = {
		"probeOffset": pathProbe.progress
	}
	data["meta.priority"] = 200
	data["meta.kind"] = "station"
	return data

func deserialize(data: Dictionary):
	await GameWorld.savegame_loaded

	pathProbe.progress = data["probeOffset"]

func init(cupulaPath: Path2D):
	stop()

	pathProbe = cupulaPath.createPathProbe(self)

func _physics_process(delta):
	if GameWorld.paused:
		return

	if playerControlled:
		if shotCooldown > 0.0:
			shotCooldown -= delta * 2.0
		if firing and shotCooldown <= 0.0:
			shoot()

		if move.x != 0.0:
			var baseMoveSpeed = Data.of(teamId + ".autocannon.speed") * 0.5
			if not $MoveSound.playing:
				$MoveSound.startSound()
			acceleration = clamp(acceleration + (5.0 - 2.0 * baseMoveSpeed) * delta, 0.0, 1.0)
			if Options.useGamepad(playerControlledDeviceId):
				currentSpeed = baseMoveSpeed * pow(abs(move.x), 2.0) * sign(move.x)
			else:
				currentSpeed += (baseMoveSpeed * move.x - currentSpeed) * delta * 8.0 * acceleration
			pathProbe.moveBy(currentSpeed * delta)
			$MoveSound.startSound()
		else:
			$MoveSound.startSound()
			currentSpeed = 0
			acceleration = 0
	else:
		if active:
			if not Data.of(teamId + ".monsters.wavepresent") or ( not Keepers.oneInsideStation(teamId) and not Data.ofOr(teamId + ".autocannon.autonomy", false)):
				stop()
				return
		else:
			if Data.of(teamId + ".monsters.wavepresent") and (Keepers.oneInsideStation(teamId) or Data.ofOr(teamId + ".autocannon.autonomy", false)) and not GameWorld.gameover:
				start()
				return

		if not active:
			return

		if not is_instance_valid(target):
			target = null

		if not target:
			findTarget()
			return

		if target:
			var d: Vector2 = target.getCenter() - $Marker2D.global_position
			dist = d.angle() - (rotation - CONST.PI_HALF)
			if dist > PI:
				dist -= 2 * PI
			elif dist < - PI:
				dist += 2 * PI

			if rotation > 0.8 and dist > CONST.PI_HALF:
				dist -= 2 * PI
			elif rotation < -0.8 and dist < - CONST.PI_HALF:
				dist += 2 * PI

			dist = clamp(dist, -0.4, 0.4)
			if abs(dist) > 0.01:
				if abs(dist) < 0.2:
					dist = sign(dist) * 0.2
				pathProbe.moveBy(delta * dist * Data.of(teamId + ".autocannon.speed"))
				$MoveSound.startSound()
		else:
			$MoveSound.stop()

		if shotCooldown > 0.0:
			shotCooldown -= delta

		var c = $RayCast2D.get_collider()
		if $RayCast2D.enabled:
			if c and is_instance_valid(c) and canTarget(c):
				if c != target:
					if multiplayer.is_server():
						setTarget(c.UID)
						state_changed.emit()

				if shotCooldown <= 0.0:
					shoot()
			else:
				if c == target:
					target = null

func shoot():
	var source = $FireSound
	match int(cannonStyle):
		0: source = $FireSound
		1: source = $HeavyFireSound
		2: source = $FastFireSound
	source.basePitch = 1.0 if Data.ofOr(teamId + ".autocannon.highpitch", false) else 0.8
	source.startSound()

	shotCooldown = Data.of(teamId + ".autocannon.timebetweenshots") / Data.of(teamId + ".autocannon.rateoffire")

	for i in max(1, Data.of(teamId + ".autocannon.shotgun")):
		shootBullet()

	$Sprite2D.frame = 0
	$Sprite2D.play("fire_" + cannonStyle)

	$MuzzleFlash.play("default")
	$MuzzleFlash.frame = 0

func shootBullet():
	var projectile = preload("res://content/gadgets/autocannon/AutoCannonShot.tscn").instantiate()
	projectile.setAnimationSuffix("_" + str(Data.of(teamId + ".autocannon.bullet")))
	projectile.global_position = $ProjectilePosition.global_position
	projectile.damageSource = "autocannon"
	projectile.origin = global_position
	projectile.teamId = teamId
	projectile.speed = Data.of(teamId + ".autocannon.shotspeed") * random.randf_range(0.9, 1.1)
	var spray = Data.of(teamId + ".autocannon.spray")
	if target:
		var targetPos = target.getHitboxCenter()
		var dist: float = (targetPos - projectile.global_position).length()
		var time = dist / projectile.speed
		var dir: Vector2
		if target.autoAimShouldLeadShot:
			dir = ((targetPos + target.linear_velocity * time) - projectile.global_position).normalized()
		else:
			dir = (targetPos - projectile.global_position).normalized()
		projectile.target = projectile.global_position + (dir.rotated(random.randf_range( - spray, spray)) * DISTANCE)
	else:
		projectile.target = Vector2.UP.rotated(rotation + random.randf_range( - spray, spray)) * DISTANCE
	projectile.damage = Data.of(teamId + ".autocannon.damage")
	if playerControlled:
		projectile.damage *= 1.8
		projectile.speed *= 1.2
	Level.map.add_child(projectile)
	Style.init(projectile)

func start():
	$Sprite2D.play("start_" + cannonStyle)
	active = true
	$ActivateSound.startSound()

func stop():
	$StopSound.startSound()
	$MoveSound.stop()
	$Sprite2D.play("stop_" + cannonStyle)
	active = false
	target = null

func canTarget(m):
	return m.alive() and not m.invulnerable and m.canBeHit()

func findTarget():
	var closestM
	var minimalAngle: = 99.0

	var monsters = get_tree().get_nodes_in_group(teamId + "-monster")
	for m in monsters:
		if not canTarget(m):
			continue
		var angle = abs((m.global_position - global_position).angle() - (rotation - CONST.PI_HALF))
		if angle < minimalAngle:
			minimalAngle = angle
			closestM = m

	if closestM:
		if closestM != target:
			if multiplayer.is_server():
				setTarget(closestM.UID)
				state_changed.emit()

func setTarget(monsterUID: int):
	if not Level.monstersByTeamId[teamId].hasMonster(monsterUID):
		return

	var m: Monster = Level.monstersByTeamId[teamId].getMonster(monsterUID)

	if target and m.UID == target.UID:
		return


	random = RandomNumberGenerator.new()
	random.seed = m.UID

	if target:
		target.disconnect("died", targetDied)
	target = m
	if not target.is_connected("died", targetDied):
		target.connect("died", targetDied)

func targetDied():
	target = null
	findTarget()

func onGameLost():
	stop()

func _on_sprite_2d_animation_looped() -> void :
	_SpriteAnimationFinishedCheck()

func _on_Sprite_animation_finished() -> void :
	_SpriteAnimationFinishedCheck()

func _SpriteAnimationFinishedCheck() -> void :
	if $Sprite2D.animation.begins_with("stop"):
		$Sprite2D.play("asleep_" + cannonStyle)

func get_gadget_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(active)
	stream.encode_float(shotCooldown)
	stream.encode_float(pathProbe.progress)
	var hasTarget: = target != null
	stream.encode_bool(hasTarget)
	if hasTarget:
		stream.encode_u32(target.UID)

	return stream.data

func set_gadget_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	active = stream.decode_bool()
	shotCooldown = stream.decode_float()
	pathProbe.progress = stream.decode_float()
	var hasTarget: = stream.decode_bool()
	if hasTarget:
		setTarget(stream.decode_u32())
	else:
		target = null
