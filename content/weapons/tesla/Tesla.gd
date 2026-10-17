extends PrimaryWeapon

const activationHeight: = -165.0
const DELTA_DATA_SIZE: int = 16

var move: Vector2
var mouseGlobal: Vector2
var fireValue: float
var specialValue: float

var maxCharge: float
var shotCharge: float
var isCharging: bool
var clampedShotCharge: float
var beamSlowdown: float
var logicDelay: float
var perfectCooldownShotWindow: Vector2
var perfectCooldownShotVisualization: Vector2
var reloadedSoundPlayed: bool

var ringsIdleSpeed: = 0.0
var chargeValue: = 0.0
var remaingingQuickshots: = 0
var perfectTimingEnabled: bool = false

@onready var bgScene = $"%BGScene"
@onready var fgScene = $"%FGScene"
@onready var reticle = $Reticle
@onready var arcAim = $"%ArcAim"
@onready var perfectHitArc = $PerfectHitArc
@onready var arcShoot = $"%ShootAim"
@onready var crystalCenter = $"%CrystalCenter"
@onready var cap = $Cap
@onready var ringSounds = $RingSounds
@onready var ring = $Ring

func _ready() -> void :
	super._ready()
	reticle.init(teamId)
	ring.init(teamId)
	cap.init(teamId)
	bgScene.init(teamId)
	fgScene.init(teamId)

func init(cupulaPath: Path2D):
	bgScene.mainScene = self
	fgScene.mainScene = self
	var dome = Level.domesByTeamId[teamId]
	dome.stations.front().connect("station_hit_top", stationHitTop)
	%TrafoAnim1.play("default")
	%TrafoAnim2.play("default")
	connect("tree_exited", reticle.queue_free)

	Style.init(self)
	maxCharge = Data.of(teamId + ".tesla.maxcharge")

	reticle.showcaseMode = showcaseMode

	$Cap.add_to_group(teamId + "-battle-start-stop-listener")
	$Ring.add_to_group(teamId + "-battle-start-stop-listener")
	bgScene.add_to_group(teamId + "-battle-start-stop-listener")
	fgScene.add_to_group(teamId + "-battle-start-stop-listener")

	Data.listen(self, teamId + ".tesla.perfecttimingwindow", true)
	Data.listen(self, teamId + ".tesla.maxcharge", true)
	Data.listen(self, teamId + ".tesla.ringIdleSpeed", true)

	Level.addTutorial(self, "tesla_intro", teamId)

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".tesla.perfecttimingwindow":

		perfectCooldownShotWindow = Vector2( - newValue * 0.3, newValue * 1.3)
		perfectCooldownShotVisualization = Vector2(0, newValue)
		perfectTimingEnabled = newValue > 0.0
	if property == teamId + ".tesla.maxcharge":
		maxCharge = newValue
	if property == teamId + ".tesla.ringidlespeed":
		ringsIdleSpeed = newValue

func get_delta_data() -> PackedByteArray:
	var stream: = PackedByteStream.new()
	stream.resize(DELTA_DATA_SIZE)
	stream.encode_float(fireValue)
	stream.encode_float(specialValue)
	stream.encode_vector2(reticle.position)
	return stream.data

func set_delta_data(buffer: PackedByteArray) -> void :
	if buffer.size() != DELTA_DATA_SIZE:
		return

	var stream: = PackedByteStream.from_bytes(buffer)
	fireValue = stream.decode_float()
	specialValue = stream.decode_float()
	reticle.position = stream.decode_vector2()

func inputs(moveValue: Vector2, fireValue: float, specialValue: float, inMouseGlobal: Vector2 = Vector2()):
	if GameWorld.paused or not started:
		return

	if not is_multiplayer_authority():
		return

	self.move = moveValue
	self.fireValue = fireValue
	self.specialValue = specialValue
	self.mouseGlobal = inMouseGlobal

func _physics_process(delta):
	updateCharge(delta)
	updateCrystalOscillation(delta)
	if GameWorld.paused:
		return

	applyDamageFromOrbs(delta)

	if not started:
		return

	var chargePerSecond = float(Data.of(teamId + ".tesla.chargepersecond"))

	updateArcs(delta)

	var filling = clamp(shotCharge / maxCharge, 0.0, 1.0)
	bgScene.targetSpeed = lerp(bgScene.targetSpeed, max(filling * 8, ringsIdleSpeed), delta * 2.0)
	fgScene.targetSpeed = lerp(fgScene.targetSpeed, max(filling * 8, ringsIdleSpeed), delta * 2.0)
	bgScene.power = filling
	fgScene.power = filling

	var perfectTiming: bool = false
	if perfectTimingEnabled:
		reticle.enablePerfectTiming()
		perfectTiming = perfectCooldownShotWindow.x + maxCharge < shotCharge and perfectCooldownShotWindow.y + maxCharge > shotCharge
		var showPerfectTiming = perfectCooldownShotVisualization.x + maxCharge < shotCharge and perfectCooldownShotVisualization.y + maxCharge > shotCharge
		if showPerfectTiming:
			$SingleShotSounds / QuickReloadWindow.startIfNotPlaying()
		reticle.setPerfect(showPerfectTiming)
		$"%PerfectSparks".emitting = showPerfectTiming
		$"%PerfectStatic".emitting = showPerfectTiming

	if shotCharge >= maxCharge and not perfectTiming and not reloadedSoundPlayed:
		$SingleShotSounds / Reloaded.startSound()
		reloadedSoundPlayed = true

	var canShoot = perfectTiming or shotCharge >= maxCharge
	if fireValue > 0.0:
		reticle.charge(true)

		shotCharge = shotCharge + chargePerSecond * delta
		isCharging = true
	else:
		if canShoot:
			shootSingle(perfectTiming, false)
			isCharging = false
		else:
			shotFirstArc = false
			reticle.charge(false)

			if isCharging and shotCharge < 0.6 * maxCharge and remaingingQuickshots > 0:
				shotCharge = 0
				shootSingle(false, true)


			shotCharge = clamp(shotCharge - chargePerSecond * delta * 2, 0, maxCharge)
			isCharging = false

	clampedShotCharge = clamp(shotCharge, 0.0, 1.0)
	ringSounds.shotCharge = clampedShotCharge
	arcAim.target = reticle.getShotPosition()
	arcAim.showEndFork = clampedShotCharge >= 1.0


	if crystalCenter.global_position.y < activationHeight:
		if not reticle.active:
			reticle.activate(deviceId)
			arcGroupL.forceCreateArc()
			arcGroupR.forceCreateArc()
	reticle.move(move, delta, mouseGlobal)
	reticle.shotCharge = clampedShotCharge

func applyDamageFromOrbs(delta: float):




	var thundersByMonster: = {}
	for thunder in get_tree().get_nodes_in_group(teamId + "-tesla-thunder"):
		var monsters = thunder.getMonstersToDamage()
		for m in monsters:
			if m.canBeHit() and m.alive() and not m.invulnerable:
				var orbs = thundersByMonster.get(m, [])
				orbs.append(thunder)
				thundersByMonster[m] = orbs


	var monstersByThunder: = {}
	for monster in thundersByMonster:
		var thunders = thundersByMonster.get(monster, [])
		if thunders.size() > 0:
			var thunder = thunders[randi() % thunders.size()]
			var monsters = monstersByThunder.get(thunder, [])
			monsters.append(monster)
			monstersByThunder[thunder] = monsters


	var stunStrength = Data.of(teamId + ".tesla.persistencestunstrength")
	for thunder in monstersByThunder:
		thunder.damageMonsters(monstersByThunder[thunder], delta, stunStrength)


var crystalOscillationT1: = 0.0
var crystalOscillationT2: = 0.0
func updateCrystalOscillation(delta):
	crystalOscillationT1 = wrapf(crystalOscillationT1 + delta * 20, 0, TAU)
	crystalOscillationT2 = wrapf(crystalOscillationT2 + delta * 40, 0, TAU)
	$"%CrystalSprites".position = Vector2.RIGHT.rotated(crystalOscillationT1) * sin(crystalOscillationT2) * 1.3 * ease(chargeBuffer, 4.0)


var shotFirstArc: = false
func updateArcs(delta):

	$"%CrystalParticle".position.y = fgScene.getRingHeight() - 64 - 25


	for c in arcL.get_children():
		c.target = Vector2(global_position.x + randf_range(-35, 35) * clampedShotCharge, fgScene.getRingHeight() - 275 - 25)
		c.position = Vector2(randf_range(-15, 15), 0).rotated(0.35)
	for c in arcR.get_children():
		c.target = Vector2(global_position.x + randf_range(-35, 35) * clampedShotCharge, fgScene.getRingHeight() - 275 - 25)
		c.position = Vector2(randf_range(-15, 15), 0).rotated(-0.35)







	if fireValue > 0 and not shotFirstArc:
		shotFirstArc = true

		arcGroupL.forceCreateArc()
		arcGroupR.forceCreateArc()





func start():
	$"%StationLight".show()
	ringSounds.start()
	started = true

func stationHitTop():
	match int(Data.of(teamId + ".tesla.powervfx")):
		4, 3:
			$SingleShotSounds / RingStart3.startSound()
		2, 1:
			$SingleShotSounds / RingStart2.startSound()
		_:
			$SingleShotSounds / RingStart1.startSound()

func stop():
	started = false
	$"%StationLight".hide()
	arcAim.hide()
	reticle.deactivate()
	reticle.shotCharge = 0.0
	shotCharge = 0.0
	clampedShotCharge = 0.0
	ringSounds.stop()


var chargePulse: = 0.0
var oldCharge: = 0.0
var chargeBuffer: = 0.0

@onready var arcL = $"%ArcL"
@onready var arcR = $"%ArcR"
@onready var arcGroupL = $"%ArcGroupL"
@onready var arcGroupR = $"%ArcGroupR"
@onready var trafoParticle1 = $"%TrafoParticle1"
@onready var trafoParticle2 = $"%TrafoParticle2"

func updateCharge(delta: float):
	var holdingFire: bool = fireValue > 0
	arcL.visible = holdingFire
	arcR.visible = holdingFire
	arcGroupL.randomInterval = remap(clampedShotCharge, 0, 1, 1.9, 0.1)
	arcGroupR.randomInterval = remap(clampedShotCharge, 0, 1, 1.9, 0.1)

	$"%SchnabelParticleL".emitting = holdingFire
	$"%SchnabelParticleR".emitting = holdingFire

	chargePulse = wrapf(chargePulse + delta * clampedShotCharge * 4, 0, 1)
	var mod = (sin(ease(chargePulse, 5) * TAU) + 2) * 0.5 + 0.2
	var modColor = Color(mod, mod, mod, clampedShotCharge)

	$"%TeslaCrystalAdditive".modulate.a = lerp(0.12, 1.0, clampedShotCharge)
	$"%CrystalPolarEffect".setPower(ease(clampedShotCharge, 3.6) * 0.8)

	%TrafoAnim1.modulate = modColor
	%TrafoAnim2.modulate = modColor
	%TrafoAnim1.speed_scale = clampedShotCharge * 2.0 + 0.3
	%TrafoAnim2.speed_scale = clampedShotCharge * 2.0 + 0.3
	trafoParticle1.emitting = holdingFire
	trafoParticle1.scale = Vector2.ONE * clampedShotCharge
	trafoParticle2.emitting = holdingFire
	trafoParticle2.scale = Vector2.ONE * clampedShotCharge

	$"%CrystalParticle".emitting = clampedShotCharge > 0.99
	$"%TeslaCrystalParticle".emitting = clampedShotCharge > 0.99
	$"%CrystalSprites".modulate = lerp(Color.WHITE, Color(2, 2, 2, 1.0), ease(chargeBuffer, 2.0))


	$"%ShaderTrafo".visible = chargeBuffer > 0.0
	$"%ShaderTrafo".material.set_shader_parameter("power", ease(clampedShotCharge, 2))
	if shotCharge > oldCharge:
		chargeBuffer = lerp(chargeBuffer, ease(clampedShotCharge, 20.2), delta * 12)
	else:
		chargeBuffer = lerp(chargeBuffer, 0.0, delta * 4)
	$"%ShaderTrafo".material.set_shader_parameter("fill", chargeBuffer)
	$"%StationLight".modulate.a = chargeBuffer
	oldCharge = shotCharge
	if holdingFire:
		trafoParticle1.self_modulate = modColor
		trafoParticle2.self_modulate = modColor

func getFireName():
	return "level.station.battle.navbar.shoot"

func getSpecialName():
	return ""

func shootSingle(perfectTiming: bool, quickshot: bool):
	var powervfx = Data.of(teamId + ".tesla.powervfx")
	var shotPosition = reticle.getShotPosition()
	var newImpactSound = preload("res://content/weapons/tesla/sounds/TeslaShotSound.tscn").instantiate()
	Level.viewports.addElement(newImpactSound)
	newImpactSound.play(powervfx, shotPosition, quickshot)

	var newImpact = preload("res://content/weapons/tesla/TeslaImpact.tscn").instantiate()
	newImpact.position = shotPosition
	newImpact.setPower(powervfx, Data.of(teamId + ".tesla.radius"))
	Level.map.addPixelEffect(newImpact)

	arcShoot.target = shotPosition
	var arcDuration = remap(float(powervfx), 0.0, 4.0, 0.7, 2.0)
	arcShoot.forkSpawnArea = Vector2(4, 4) * arcDuration
	$Tween.interpolate_method(self, "controlShootArc", 1, 0, arcDuration, Tween.TRANS_SINE, Tween.EASE_OUT)

	var newShot = preload("res://content/weapons/tesla/TeslaThunder.tscn").instantiate()
	newShot.teamId = teamId
	newShot.perfect = perfectTiming
	newShot.global_position = shotPosition
	newShot.hit_monster.connect(hitMonster)

	var radius = Data.of(teamId + ".tesla.radius")
	var baseDamage = Data.of(teamId + ".tesla.damage")
	var damage = baseDamage
	var strength = Data.of(teamId + ".tesla.persistance")
	if perfectTiming:
		perfectHitArc.target = shotPosition
		perfectHitArc.global_position = Vector2(shotPosition.x, -480.0)
		$Tween.interpolate_method(self, "controlPerfectShootArc", 1, 0, arcDuration * 0.6, Tween.TRANS_SINE, Tween.EASE_OUT)
		var mult = Data.of(teamId + ".tesla.perfecttimingmultiplier")
		damage *= mult
		strength *= mult
		match int(Data.of(teamId + ".tesla.perfecttimingstage")):
			1:
				$SingleShotSounds / QuickReloadSuccess1.startSound()
			2:
				$SingleShotSounds / QuickReloadSuccess2.startSound()
			3:
				$SingleShotSounds / QuickReloadSuccess3.startSound()
	$Tween.start()
	shotCharge = 0
	reloadedSoundPlayed = false

	reticle.shoot()

	if quickshot:
		strength = 0.0
		damage *= Data.of(teamId + ".tesla.quickshotstrength")
	elif Data.of(teamId + ".tesla.nurture"):
		var overlappingOrb = reticle.getClosestOverlappingOrb()
		if overlappingOrb:
			$SingleShotSounds / NurtureHitSound.startSound()
			overlappingOrb.strengthen(strength, reticle.global_position)
			strength = 0.0

	Level.viewports.addElement(newShot)
	newShot.start(damage, radius, strength)

	if quickshot:
		remaingingQuickshots = 0
		reticle.setRemainingQuickshots(0)
	else:
		if Data.of(teamId + ".tesla.quickshotstrength") > 0.0:
			remaingingQuickshots = 1
			reticle.setRemainingQuickshots(remaingingQuickshots)

func controlShootArc(v: float):
	arcShoot.visible = v >= 0.05
	arcShoot.position = (Vector2.RIGHT * float(Data.of(teamId + ".tesla.powervfx")) * 2.0).rotated(randf() * TAU)
	var dir = sign(global_position.x - arcShoot.target.x)
	arcShoot.baseCurvature = remap(v, 1.0, 0.0, 0.0, 0.8) * dir
	arcShoot.spawnInterval = remap(ease(v, 0.5), 1.0, 0.0, 0.01, 0.2)
	arcShoot.arcWildness = remap(v, 1.0, 0.0, 0.0, 20.0)
	arcShoot.modulate = lerp(Color(2, 2, 2, 1), Color(1, 1, 1, 1), ease(v, 1.2))
	arcShoot.impactRadius = remap(ease(v, 0.3), 1.0, 0.0, 4.0, 30.0)


func controlPerfectShootArc(v: float):
	perfectHitArc.visible = v >= 0.05
	perfectHitArc.spawnInterval = remap(ease(v, 0.5), 1.0, 0.0, 0.01, 0.2)
	perfectHitArc.arcWildness = remap(v, 1.0, 0.0, 0.0, 20.0)
	perfectHitArc.modulate = lerp(Color(2, 2, 2, 1), Color(1, 1, 1, 1), ease(v, 1.2))
	perfectHitArc.impactRadius = remap(ease(v, 0.3), 1.0, 0.0, 4.0, 30.0)
