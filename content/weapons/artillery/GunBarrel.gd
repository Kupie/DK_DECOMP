class_name GunBarrel extends Node2D

signal hit_monster(monster: Monster, source: String, damage: float, stun: float)

const Bullet: = preload("res://content/weapons/artillery/Bullet.tscn")
const EmptyShell: = preload("res://content/weapons/artillery/FlakShellEmpty.tscn")

@export var flip_h: = false

var teamId: String

var recoilAmount: = [4.0, 5.0, 3.0, 2.0, 1.0, 1.0, 1.0]
var gunCooldown: float
var soundsDefaultVol: = []
var fastFireVolume: = 0.0
var shotsFired: = 0
var _is_firing: bool = false

@onready var barrels: = [$Upgrade0, $Upgrade1, $Upgrade2, $Upgrade3, $Upgrade4, $Upgrade5, $Upgrade6]
@onready var barrelTops: = [$Upgrade0 / Bottom / Top, 
	$Upgrade1 / Bottom / Top, 
	$Upgrade2 / Bottom / Top, 
	$Upgrade3 / Bottom / Top, 
	$Upgrade4 / Bottom / Top, 
	$Upgrade5 / Bottom / Top, 
	$Upgrade6 / Bottom / Top]
@onready var tween = $Tween
@onready var sounds: = [$MachineGunFire, $HomingRocket, $HomingRocket2]
@onready var _muzzleflash: MuzzleFlash = $Muzzleflash

func _ready():
	for b in barrels:
		if b.visible:
			b.scale.x = 1 if not flip_h else -1
	for s in sounds:
		soundsDefaultVol.append(s.volume_db)

func isFiring() -> bool:
	return _is_firing

func setBarrelSize(index: int = 0):
	for b in barrels:
		b.hide()
	barrels[index].show()
	barrels[index].scale.x = 1 if not flip_h else -1

func getSpawnPoint():
	for b in barrels:
		if b.visible:
			return b.get_node("SpawnPoint")

func proc(delta: float, gunPressedValue: float, delay: float = 0.0) -> float:
	if delay > 0.0:
		gunCooldown = delay
	if gunCooldown > 0:
		gunCooldown -= delta

	if gunCooldown <= 0.0 and gunPressedValue > 0.0:
		fireGunBullet()
		fastFireVolume = clamp(fastFireVolume + delta * 36.0, 0.0, 6.0)
		return gunCooldown

	if gunPressedValue <= 0.0:
		fastFireVolume = 0.0
		if _is_firing:
			_is_firing = false
			$ShellEjectSound.startSound()

	return 0.0

func fireGunBullet():
	InputSystem.shake(20, 0.4, 10, global_position)
	var shell = Bullet.instantiate()
	var shellSpawnPosition: Vector2 = getSpawnPoint().global_position
	shell.s = Level.levelSeed + shotsFired
	shell.hit_monster.connect(on_monster_hit)
	shell.teamId = teamId
	shell.rotation = global_rotation + randf_range(-0.03, 0.03)
	shell.position = shellSpawnPosition
	_is_firing = true
	Level.map.add_child(shell)
	shell.fire(Data.of(teamId + ".artillery.machinegunbulletspeed"))
	gunCooldown = Data.of(teamId + ".artillery.machinegunreloadspeed")
	_muzzleflash.reset(shellSpawnPosition)

	var sound = sounds[int(Data.of(teamId + ".artillery.machinegunsound"))]
	sound.setAdditionalVolume(0.0)
	if Data.of(teamId + ".artillery.machinegunbarrels") >= 2:
		sound.setAdditionalVolume( - fastFireVolume)
	sound.startSound()

	recoil()
	shotsFired += 1

func on_monster_hit(monster: Monster, source: String, damage: float, stun: float) -> void :
	hit_monster.emit(monster, source, damage, stun)

func getBarrelSet() -> Array:
	var barrelIndex: int = -1
	for i in barrels.size():
		if barrels[i].visible:
			barrelIndex = i
	var barrelRecoil = recoilAmount[barrelIndex]
	var barrelTop = barrelTops[barrelIndex]
	return [barrelTop, barrelRecoil]

func recoil():
	var barrelSet = getBarrelSet()
	var recoilY = barrelSet[1]
	var barrelTop = barrelSet[0]
	tween.remove_all()
	tween.interpolate_property(barrelTop, "position:y", recoilY, 0, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
	tween.start()

func pauseChanged():
	if GameWorld.paused:
		tween.stop_all()
	else:
		tween.resume_all()

static func getMachineGunReloadSpeedForTeam(inTeamId: String) -> float:
	var reloadSpeed: float = Data.of(inTeamId + ".artillery.machinegunreloadspeed")
	return reloadSpeed

func isRight() -> bool:
	return flip_h

func getShellSpawnPosition() -> Vector2:
	for b in barrels:
		if b.visible:
			return b.get_node("ShellEject").global_position
	return Vector2()
