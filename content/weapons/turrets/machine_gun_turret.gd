extends Node2D

signal state_changed

const DISTANCE: = 1000
var dist: float

var active: = false
var teamId: String

var shotCooldown: = 0.0

var target: Monster
var random: RandomNumberGenerator

var left: bool
var threshold_x: float

func _ready():
	Style.init(self)

	add_to_group(teamId + "-turrets")

func _physics_process(delta):
	if GameWorld.paused:
		return

	if active:
		if not Data.of(teamId + ".monsters.wavepresent"):
			stop()
			return
	else:
		if Data.of(teamId + ".monsters.wavepresent") and not GameWorld.gameover:
			start()
			return

	if not active:
		return

	if not is_instance_valid(target):
		target = null

	if not target:
		findTarget()
		return

	if shotCooldown > 0.0:
		shotCooldown -= delta

	if is_instance_valid(target) and canTarget(target):
		if shotCooldown <= 0.0:
			shoot()
	else:
		target = null

func shoot():




	shotCooldown = Data.of(teamId + ".turrets.machineguntimebetweenshots")

	shootBullet()







func shootBullet():
	var projectile = preload("res://content/gadgets/autocannon/AutoCannonShot.tscn").instantiate()
	projectile.setAnimationSuffix("_1")
	projectile.global_position = $ProjectilePosition.global_position
	projectile.damageSource = "turretsmachinegun"
	projectile.origin = global_position
	projectile.teamId = teamId
	projectile.speed = Data.of(teamId + ".turrets.machinegunshotspeed") * random.randf_range(0.9, 1.1)
	var spray = 0.04
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
	projectile.damage = Data.of(teamId + ".turrets.machinegundamage")
	Level.map.add_child(projectile)
	Style.init(projectile)

func start():

	active = true


func stop():



	active = false
	target = null

func canTarget(m):
	if left:
		if m.global_position.x > threshold_x:
			return false
	else:
		if m.global_position.x < threshold_x:
			return false
	return m.alive() and not m.invulnerable and m.canBeHit()

func findTarget():
	var closestM
	var minDist: = INF

	var monsters = get_tree().get_nodes_in_group(teamId + "-monster")
	for m in monsters:
		if not canTarget(m):
			continue

		var dist = m.global_position.distance_squared_to(global_position)
		if dist < minDist:
			minDist = dist
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
