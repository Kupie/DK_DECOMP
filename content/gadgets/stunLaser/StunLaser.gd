extends SecondaryWeapon

signal state_changed

@export var synchronizer: GadgetSynchronizer

var dist: float

var playSound: = false

var externallyDisabled: = false
var active: = false
var animatingCountdown: = 0.0
var totalFireTime: float
var remainingFireTime: float
var remainingCooldown: float

var hitAreaBaseSize: float
var animationSuffix: String = "_1"

var target: Monster
var pathProbe: PathFollow2D

var monsterInHitArea: = []
const MAX_RANGE = 450

func _ready():
	Data.listen(self, teamId + ".stunlaser.stunarea", true)
	Data.listen(self, teamId + ".stunlaser.stage", true)

	$CooldownParticles.emitting = false

	Style.init(self)

func init(cupulaPath: Path2D):
	stop()

	pathProbe = cupulaPath.createPathProbe(self)

	remainingFireTime = Data.of(teamId + ".stunLaser.fireTime")
	totalFireTime = remainingFireTime

	$Sprite2D.play("off" + animationSuffix)

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".stunlaser.stunarea":
		hitAreaBaseSize = newValue
		if newValue > 0.0:
			$BeamHitArea / CollisionShape2D.shape.radius = newValue
			$BeamHitArea / CollisionShape2D.disabled = false
			$BeamHitArea.monitoring = true
			$BeamHitArea / Sprite2D.visible = true
		else:
			$BeamHitArea / CollisionShape2D.disabled = true
			$BeamHitArea.monitoring = false
			$BeamHitArea / Sprite2D.visible = false
	elif property == teamId + ".stunlaser.stage":
		$LaserBeam.width = newValue
		$LaserBeam.setStage(newValue)
		animationSuffix = "_" + str(newValue)
		match newValue:
			1: $Cannon.texture = preload("res://content/gadgets/stunLaser/cannont1.png")
			2: $Cannon.texture = preload("res://content/gadgets/stunLaser/cannont2.png")
			3: $Cannon.texture = preload("res://content/gadgets/stunLaser/cannont3.png")

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

func _physics_process(delta):
	if GameWorld.paused or externallyDisabled:
		return

	if animatingCountdown > 0.0:
		animatingCountdown -= delta
		return

	if playerControlled:
		if remainingCooldown > 0.0:
			remainingCooldown -= delta * 3.0
			$CooldownParticles.rotation = - rotation
			$Sprite2D.play("cooldown" + animationSuffix)
			if remainingCooldown <= 0.0:
				finishCooldown()
			if not Data.of(teamId + ".stunLaser.trackingInCooldown"):
				return

		if not active:
			return

		if firing and remainingCooldown <= 0:
			var c = $RayCast2D.get_collider()
			if $RayCast2D.enabled and remainingFireTime > 0 and c and is_instance_valid(c) and canTarget(c):
				target = c
			else:
				target = null
				$BeamHitArea.visible = false

			fire(delta)
			handleFiring(delta)
			updateCannonFraction()
		else:
			stopFire()
			remainingFireTime = min(remainingFireTime + delta, Data.of(teamId + ".stunLaser.fireTime"))
			if remainingCooldown <= 0.0:
				updateCannonFraction()

		if move.x != 0.0:
			var baseMoveSpeed = Data.of(teamId + ".stunLaser.speed") * 0.5
			if not $MoveSound.playing:
				$MoveSound.startSound()
			acceleration = clamp(acceleration + (5.0 - 3.5 * baseMoveSpeed) * delta, 0.0, 1.0)
			if Options.useGamepad(playerControlledDeviceId):
				currentSpeed = baseMoveSpeed * pow(abs(move.x), 2.0) * sign(move.x)
			else:
				currentSpeed += (baseMoveSpeed * move.x - currentSpeed) * delta * 8.0 * acceleration
			pathProbe.moveBy(currentSpeed * delta)
			$Sprite2D.play("move" + animationSuffix)
			$MoveSound.startSound()
		else:
			if remainingCooldown > 0.0:
				$Sprite2D.play("cooldown" + animationSuffix)
			else:
				$Sprite2D.play("idle" + animationSuffix)

			$MoveSound.stop()
			currentSpeed = 0
			acceleration = 0
	else:
		if active:
			if not Data.of(teamId + ".monsters.wavepresent") or ( not Keepers.oneInsideStation(teamId) and not Data.ofOr(teamId + ".stunLaser.autonomy", false)):
				stop()
				return
		else:
			if Data.of(teamId + ".monsters.wavepresent") and (Keepers.oneInsideStation(teamId) or Data.ofOr(teamId + ".stunLaser.autonomy", false)):
				start()
				return

		if not active:
			return

		if remainingCooldown > 0.0:
			$CooldownParticles.rotation = - rotation
			remainingCooldown -= delta
			if remainingCooldown <= 0.0:
				finishCooldown()
				return
			elif not Data.of(teamId + ".stunLaser.trackingInCooldown"):
				return

		updateCannonFraction()
		if firing and handleFiring(delta):
			return

		if not is_instance_valid(target):
			target = null

		if not target and not firing and (remainingCooldown <= 0 or Data.of(teamId + ".stunLaser.trackingInCooldown")):
			findTarget()
			return

		if target and (remainingCooldown <= 0 or Data.of(teamId + ".stunLaser.trackingInCooldown")):



			var d: Vector2 = target.getCenter() - $BasePosition.global_position
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
				pathProbe.moveBy(delta * dist * Data.of(teamId + ".stunLaser.speed"))
				$Sprite2D.play("move" + animationSuffix)
				$MoveSound.startSound()
		else:
			$MoveSound.stop()

		var c = $RayCast2D.get_collider()
		if $RayCast2D.enabled and remainingFireTime > 0:
			if c and is_instance_valid(c):
				if c and canTarget(c):
					if c != target:
						if multiplayer.is_server():
							setTarget(c.UID)
							state_changed.emit()
					fire(delta)
				else:
					stopFire()

func handleFiring(delta: float) -> bool:
	remainingFireTime -= delta

	if remainingFireTime <= 0.0:
		stopFire()
		remainingCooldown = Data.of(teamId + ".stunLaser.cooldown")
		$Sprite2D.play("cooldown" + animationSuffix)
		$CooldownParticles.emitting = true
		return true
	return false

func updateCannonFraction():
	var fraction = floor(min(11, 12.0 * remainingFireTime / totalFireTime))
	setCannonFraction(fraction)

func finishCooldown():
	$CooldownParticles.emitting = false
	remainingFireTime = Data.of(teamId + ".stunLaser.fireTime")
	if active:
		$ActivateSound.startSound()
		$Tween.stop_all()
		$Tween.remove_all()
		$Tween.interpolate_method(self, "setCannonFraction", 0, 11, 1.0, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
		$Tween.start()
		animatingCountdown = 1.0

func setCannonFraction(fraction: int):
	$Cannon.region_rect.size.y = fraction
	$Cannon.region_rect.position.y = 0
	$Cannon.offset.y = 11 - fraction

func start():
	$Sprite2D.play("start" + animationSuffix)
	animatingCountdown = 0.7
	active = true
	if remainingCooldown <= 0:
		$Tween.stop_all()
		$Tween.remove_all()
		$Tween.interpolate_method(self, "setCannonFraction", 0, 11, 0.7, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
		$Tween.start()
		$ActivateSound.startSound()

func stop():
	stopFire()
	$Sprite2D.play("shutdown" + animationSuffix)
	active = false
	target = null
	var time = max(0.1, $Cannon.region_rect.size.y / 11.0)
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_method(self, "setCannonFraction", $Cannon.region_rect.size.y, 0, time, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	$Tween.interpolate_callback(self, time, "set", "animating", false)
	$Tween.start()
	animatingCountdown = time

func fire(delta: float):
	var laserEndPos: Vector2

	if target:
		var collisionPoint = $RayCast2D.get_collision_point()
		laserEndPos = Vector2(0, -1) * ((collisionPoint - global_position).length() + 8)

		var stunStrength = Data.of(teamId + ".stunLaser.stunstrength")
		if multiplayer.is_server():
			target.hit("stunlaser", 0, stunStrength)

		if $BeamHitArea.monitoring:
			$BeamHitArea.rotation = - rotation
			if not $BeamHitArea.visible:
				$BeamHitArea.visible = true
				$StunAreaSound.startSound()
				$BeamHitArea.position = laserEndPos
			else:

				var beamdelta = laserEndPos - $BeamHitArea.position
				if beamdelta.length() > 30:
					$BeamHitArea.position = laserEndPos
				else:
					$BeamHitArea.position += beamdelta.normalized() * 60 * delta

			var additionalMonsters = (monsterInHitArea.size() - 1)
			var radius = hitAreaBaseSize + additionalMonsters * Data.of(teamId + ".stunLaser.areagrowthpermonster")
			$BeamHitArea / CollisionShape2D.shape.radius = radius
			$BeamHitArea / Sprite2D.material.set_shader_parameter("pixelation_factor", radius * 2)
			$BeamHitArea / Sprite2D.scale = Vector2(1.2, 1.2) / ($BeamHitArea / Sprite2D.texture.get_size() / (radius * 2))
			var areaStunStrength = Data.of(teamId + ".stunLaser.areastunstrength")
			var damage = Data.of(teamId + ".stunLaser.damagepermonster") * additionalMonsters
			if playerControlled and damage > 0:
				damage = (damage + 1) * 3
			for monster in monsterInHitArea:
				if multiplayer.is_server():
					monster.hit("stunlaser", damage * delta, stunStrength * areaStunStrength)
				areaStunStrength *= 0.85
	else:
		laserEndPos = Vector2(0, -1) * 600

	$Sprite2D.play("shoot" + animationSuffix)
	$LaserBeam.shootAt(laserEndPos)

	if not firing:
		$FireSound.startSound()
		state_changed.emit()
	firing = true

func stopFire():
	$LaserBeam.stopShooting()
	$BeamHitArea.visible = false
	$StunAreaSound.stop()

	if firing:
		$FireSound.stop()
		$StopSound.startSound()
		firing = false
		state_changed.emit()

func canTarget(m):
	var dome: Dome = Level.domesByTeamId[teamId]
	var distanceToDome: = dome.global_position.distance_to(m.global_position)

	return m.alive()\
	and m.stunPriority > 0\
	and not m.invulnerable\
	and m.canBeHit()\
	and distanceToDome < MAX_RANGE

func findTarget():
	if not multiplayer.is_server():
		return

	var closestM
	var minimalAngle: = 99.0

	var monsters = get_tree().get_nodes_in_group(teamId + "-monster")
	for i in range(1, 5):
		for m in monsters:
			if i != m.stunPriority or not canTarget(m):
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
			return

func setTarget(monsterUID: int):
	if not Level.monstersByTeamId[teamId].hasMonster(monsterUID):
		return

	var m: Monster = Level.monstersByTeamId[teamId].getMonster(monsterUID)

	if target:
		target.disconnect("died", targetDied)
	target = m
	if not target.is_connected("died", targetDied):
		target.connect("died", targetDied)

func targetDied():
	target = null
	stopFire()
	if multiplayer.is_server():
		findTarget()

func _on_Sprite_animation_finished():
	if $Sprite2D.animation == "start":
		$Cannon.visible = true

func onGameLost():
	externallyDisabled = true
	stop()

func _on_BeamHitArea_area_entered(area):
	if not monsterInHitArea.has(area):
		monsterInHitArea.append(area)

func _on_BeamHitArea_area_exited(area):
	monsterInHitArea.erase(area)

func pauseChanged():
	if GameWorld.paused:
		$Tween.stop_all()
	else:
		$Tween.resume_all()

func get_gadget_state() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.encode_bool(externallyDisabled)
	stream.encode_bool(active)
	stream.encode_float(animatingCountdown)
	stream.encode_float(totalFireTime)
	stream.encode_float(remainingFireTime)
	stream.encode_float(remainingCooldown)
	stream.encode_float(pathProbe.progress)
	var hasTarget: = target != null
	stream.encode_bool(hasTarget)
	if hasTarget:
		stream.encode_u32(target.UID)

	return stream.data

func set_gadget_state(buffer: PackedByteArray) -> void :
	var stream: = PackedByteStream.from_bytes(buffer)
	externallyDisabled = stream.decode_bool()
	active = stream.decode_bool()
	animatingCountdown = stream.decode_float()
	totalFireTime = stream.decode_float()
	remainingFireTime = stream.decode_float()
	remainingCooldown = stream.decode_float()
	pathProbe.progress = stream.decode_float()
	var hasTarget: = stream.decode_bool()
	if hasTarget:
		setTarget(stream.decode_u32())
	else:
		target = null

	if firing and remainingFireTime <= 0:
		stopFire()

		if remainingCooldown > 0.0:
			$Sprite2D.play("cooldown" + animationSuffix)
			$CooldownParticles.emitting = true
