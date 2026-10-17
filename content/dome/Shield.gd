extends Sprite2D

enum Mode{NOTHING, BLAST, REFLECT, INVULNERABLE}
var mode: int = Mode.NOTHING

var teamId: String

var monstersInBlastArea: = []
var projectilesInReflectArea: = []

var active: = false
var maxAdditionalCharge: = 0.0
var chargedAfter: float = 1.0
var blastSpriteFrame: float
var lastDuration: = 0.0

var DESTRUCTION_PREVENTION_COOLDOWN: = 3

@onready var blastArc: TeslaArc = $Blast / BlastArc
@onready var blastShootArc: TeslaArc = $Blast / BlastShootArc
@onready var blastParticles: GPUParticles2D = $Blast / ShieldBlastParticles

func init(teamId: String):
	self.teamId = teamId

	$Blast.visible = false
	$Reflect.visible = false
	$Invulnerable.visible = false
	$OverchargeShield.visible = false
	$Reflect.monitoring = false
	$Reflect / CollisionPolygon2D.disabled = true
	$Blast.monitoring = false
	$Blast / CollisionPolygon2D.disabled = true

	visible = false
	set_process(false)
	Data.listen(self, teamId + ".shield.stage", true)
	Data.listen(self, teamId + ".shield.overchargestrength", true)
	Data.listen(self, teamId + ".shield.battleuses")
	if multiplayer.is_server():
		Data.apply(teamId + ".shield.strength", 0)
		Data.apply(teamId + ".shield.additionalstrength", 0)
		Data.apply(teamId + ".shield.remainingbattleuses", 0)
		Data.apply(teamId + ".shield.remainingabilityduration", 0)
		Data.apply(teamId + ".shield.dorecharge", true)

	Achievements.addIfOpen(self, "SHIELD_STRONG", teamId)

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".shield.overchargestrength":
		maxAdditionalCharge = newValue
	elif property == teamId + ".monsters.wavepresent":
		if not multiplayer.is_server():
			return

		if newValue == oldValue:

			chargedAfter = GameWorld.getTimeBetweenWaves(teamId) * float(Data.of(teamId + ".shield.growthTime"))
			return

		if newValue:
			Data.apply(teamId + ".shield.remainingbattleuses", Data.of(teamId + ".shield.battleuses"))
		else:
			Data.apply(teamId + ".shield.overcharged", false)
			Data.apply(teamId + ".shield.additionalstrength", 0.0)
			Data.apply(teamId + ".shield.remainingbattleuses", 0)
			Data.apply(teamId + ".shield.remainingabilityduration", 0)

			chargedAfter = GameWorld.getTimeBetweenWaves(teamId) * float(Data.of(teamId + ".shield.growthTime"))
			var currentCooldown = Data.of(teamId + ".shield.battlepreventioncooldown")
			if currentCooldown == DESTRUCTION_PREVENTION_COOLDOWN:
				Data.apply(teamId + ".shield.dorecharge", false)
			else:
				Data.apply(teamId + ".shield.dorecharge", true)
			if currentCooldown > 0:
				Data.apply(teamId + ".shield.battlepreventioncooldown", max(0, currentCooldown - 1))
	elif property == teamId + ".shield.overcharged":
		if newValue:
			if multiplayer.is_server():
				Data.apply(teamId + ".shield.additionalstrength", maxAdditionalCharge)
			$OverchargeShield.visible = true
	elif property == teamId + ".shield.battlereflect":
		if mode == Mode.NOTHING and newValue:
			add_to_group(teamId + "-dome_ability1")
			$Reflect.monitoring = true
			$Reflect / CollisionPolygon2D.disabled = false
			mode = Mode.REFLECT
	elif property == teamId + ".shield.battleblast":
		if mode == Mode.NOTHING and newValue:
			add_to_group(teamId + "-dome_ability1")
			$Blast.monitoring = true
			$Blast / CollisionPolygon2D.disabled = false
			mode = Mode.BLAST
	elif property == teamId + ".shield.battleinvulnerable":
		if mode == Mode.NOTHING and newValue:
			add_to_group(teamId + "-dome_ability1")
			mode = Mode.INVULNERABLE
	elif property == teamId + ".shield.stage":
		if newValue > 0:
			if not visible:
				visible = true
				self_modulate.a = 0.0
				set_process(true)
				Data.listen(self, teamId + ".shield.battlereflect", true)
				Data.listen(self, teamId + ".shield.battleblast", true)
				Data.listen(self, teamId + ".shield.battleinvulnerable", true)
				Data.listen(self, teamId + ".monsters.wavepresent")
				Data.listen(self, teamId + ".shield.overcharged")
				if multiplayer.is_server():
					Data.apply(teamId + ".shield.battlepreventioncooldown", 0)
		else:
			visible = false
			set_process(false)
	elif property == teamId + ".shield.battleuses":
		if oldValue != null:
			var delta = newValue - oldValue
			if delta > 0 and Data.of(teamId + ".monsters.wavepresent"):
				Data.changeByInt(teamId + ".shield.remainingbattleuses", delta)

func absorbDamage(rawDamage, pos: Vector2) -> float:
	if not visible:
		return rawDamage

	if active and mode == Mode.INVULNERABLE:
		return 0.0

	var add = Data.of(teamId + ".shield.additionalstrength")
	var remainingAfterAdditional = max(0, rawDamage - add)
	add = max(add - rawDamage, 0)
	if multiplayer.is_server():
		Data.apply(teamId + ".shield.additionalstrength", add)

	var s = Data.of(teamId + ".shield.strength")
	var remaining = max(0.0, remainingAfterAdditional - s)
	var newS = max(s - remainingAfterAdditional, 0)
	if multiplayer.is_server():
		Data.apply(teamId + ".shield.strength", newS)


	if newS == 0.0 and s > 0.0 and Data.of(teamId + ".shield.battleactivateondepletion"):
		if active:
			var duration = getBattleAbilityDuration()
			duration += duration - $Tween.tell()
			lastDuration = duration
			active = true
			$Tween.stop_all()
			$Tween.remove_all()
			$Tween.interpolate_callback(self, duration, "deactivate")
			$Tween.start()
		elif multiplayer.is_server():
			executeBattle1(0, false)
			Network.rpc_if_state(remoteExecuteBattle1, Network.ConnectionState.LEVEL_STAGE_SYNC)
			if active and mode == Mode.INVULNERABLE:
				return 0.0
		elif active and mode == Mode.INVULNERABLE:
			return 0.0


	var preventionTime = Data.of(teamId + ".shield.battledestructionprevention")
	if preventionTime > 0 and remaining + 1.0 > Data.of(teamId + ".dome.health") and Data.of(teamId + ".shield.battlepreventioncooldown") == 0:
		if multiplayer.is_server():
			executeBattle1(preventionTime, false)
			Network.rpc_if_state(remoteExecuteBattle1.bind(preventionTime), Network.ConnectionState.LEVEL_STAGE_SYNC)
			Data.apply(teamId + ".shield.battlepreventioncooldown", DESTRUCTION_PREVENTION_COOLDOWN)
			Data.apply(teamId + ".dome.health", 2.0)
			Data.changeByInt(teamId + ".shield.absorbeddamage", rawDamage)
		return 0.0
	if s > 0.0:
		if multiplayer.is_server():
			Data.changeByInt(teamId + ".shield.absorbeddamage", remaining * 0.5)
		return remaining * 0.5
	else:
		if multiplayer.is_server():
			Data.changeByInt(teamId + ".shield.absorbeddamage", remaining)
		return remaining

func _process(delta):
	if GameWorld.paused:
		return


	lastZapTime += delta

	var currentShieldStrength = Data.of(teamId + ".shield.strength")
	var maxShieldStrength = Data.of(teamId + ".shield.maxStrength")
	var filling: float = currentShieldStrength / maxShieldStrength
	self_modulate.a = min(filling, 1.0)
	if $OverchargeShield.visible:
		$OverchargeShield.modulate.a = Data.of(teamId + ".shield.additionalstrength") / float(maxAdditionalCharge)


	if multiplayer.is_server() and not GameWorld.softPaused(teamId) and Data.of(teamId + ".shield.dorecharge") and not is_equal_approx(currentShieldStrength, maxShieldStrength):
		var rechargeRate = maxShieldStrength / chargedAfter
		currentShieldStrength = min(currentShieldStrength + delta * GameWorld.cycleSpeed * rechargeRate, maxShieldStrength)
		Data.apply(teamId + ".shield.strength", currentShieldStrength)

	if active and multiplayer.is_server():
		Data.apply(teamId + ".shield.remainingabilityduration", lastDuration - $Tween.tell())

	if active:
		match mode:
			Mode.BLAST:
				playBlastAnimation(delta)
				if multiplayer.is_server():
					var dmg = Data.of(teamId + ".shield.battleblastdamage") * delta
					var stun = Data.of(teamId + ".shield.battleblaststun")
					for area in monstersInBlastArea.duplicate():
						area.hit("shieldbattleelectroblast", dmg, stun, false)
			Mode.INVULNERABLE:
				pass
			Mode.REFLECT:
				var reflected: = false
				for area in projectilesInReflectArea:
					if not is_instance_valid(area):
						continue

					area.domeReflectsDamage(0.0, Data.of(teamId + ".shield.battlereflectspeedup"), 2.0)
					$Reflect / ReflectProjectileSound2.startSound()
					reflected = true

				if reflected:

					$Reflect / Tween.remove_all()
					$Reflect / ReflectSprite.modulate = Color(1, 1, 1, 1)
					$Reflect / Tween.interpolate_property($Reflect / ReflectSprite, "scale", Vector2(1.05, 1.05), Vector2(1, 1), 0.5, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
					$Reflect / Tween.start()

				projectilesInReflectArea.clear()

var lastArcTime: = 0.0
var nextArcTime: = 0.1

var lastZapTime: = 0.0
var nextZapTime: = 0.1

func playBlastAnimation(delta):

	var particlePos: Vector3 = get_parent().getCupolaPosition(wrapf(Time.get_ticks_msec() / 100.0, 0.05, 0.97), teamId)
	blastParticles.global_position = Vector2(particlePos.x, particlePos.y) + Vector2(0, -10).rotated(particlePos.z)
	blastParticles.rotation = particlePos.z
	var particleAmount = int(remap(Data.of(teamId + ".shield.battleblastdamage"), 30.0, 80.0, 100, 300))
	if particleAmount != blastParticles.amount:
		blastParticles.amount = particleAmount


	lastArcTime += delta
	if lastArcTime > nextArcTime:
		lastArcTime = 0.0
		nextArcTime = randf_range(0.05, 0.13) * remap(Data.of(teamId + ".shield.battleblastdamage"), 30.0, 80.0, 1.0, 0.5)

		var start = randf() * 0.6 + 0.1
		var startPos: Vector3 = get_parent().getCupolaPosition(start, teamId)
		var endPos: Vector3 = get_parent().getCupolaPosition(min(start + max(0.1, randf() * 0.4), 0.9), teamId)
		blastArc.global_position = Vector2(startPos.x, startPos.y) + Vector2(0, -10).rotated(startPos.z)
		blastArc.target = Vector2(endPos.x, endPos.y) + Vector2(0, -10).rotated(endPos.z)
		blastArc.forceCreateArc()


	if not monstersInBlastArea.is_empty():
		var zapTimeMod = remap(Data.of(teamId + ".shield.battleblastdamage"), 30.0, 80.0, 1.0, 0.5)
		zapMonsters(monstersInBlastArea, zapTimeMod)

var bufferedMonsters: = []
func zapMonsters(monsters: Array, zapTimeMod: = 1.0, force: = false):
	for m in monsters:
		if not bufferedMonsters.has(m):
			bufferedMonsters.append(m)
	if not force and lastZapTime < nextZapTime * zapTimeMod:
		return
	lastZapTime = 0.0
	nextZapTime = randf_range(0.03, 0.08)
	$Blast / BlastTick.startSound()
	for m in bufferedMonsters:
		if not is_instance_valid(m) or m.dead:
			continue
		var targetPos = m.getCenter() + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		var startPos = get_parent().getCupolaClosestPos(targetPos, teamId)
		blastShootArc.global_position = startPos + startPos.direction_to(targetPos) * 8.0
		blastShootArc.target = targetPos
		blastShootArc.forceCreateArc()
	bufferedMonsters.clear()

func _on_BlastArea_area_entered(area):
	if area.is_in_group("monster") and not monstersInBlastArea.has(area):
		monstersInBlastArea.append(area)
		area.connect("died", Callable(self, "monsterDied").bind(area))

func monsterDied(monster):
	monstersInBlastArea.erase(monster)

func _on_BlastArea_area_exited(area):
	if area.is_in_group("monster"):
		monstersInBlastArea.erase(area)
		area.disconnect("died", monsterDied)

func _on_ReflectArea_area_entered(area):
	if area.is_in_group("projectile"):
		projectilesInReflectArea.append(area)

func _on_ReflectArea_area_exited(area):
	if area.is_in_group("projectile"):
		projectilesInReflectArea.erase(area)

func executeBattle1(extraTime: = 0.0, useCharge: = true) -> bool:
	if mode == Mode.NOTHING:
		return false

	if active:
		return false

	if useCharge:
		var remainingUses = Data.of(teamId + ".shield.remainingbattleuses")
		if remainingUses <= 0:
			Audio.sound("gui_err")
			return false
		Data.apply(teamId + ".shield.remainingbattleuses", remainingUses - 1)

	var duration = getBattleAbilityDuration() + extraTime
	lastDuration = duration
	active = true
	Audio.sound("gui_toggle")

	startBattleAbilityVisuals(duration)

	Backend.event("battle_ability_used", {"gadget": "shield", "ability": Mode.keys()[mode]})
	return true

@rpc("reliable")
func remoteExecuteBattle1(extraTime: = 0.0) -> void :
	if mode == Mode.NOTHING:
		return

	if active:
		return

	active = true
	startBattleAbilityVisuals(getBattleAbilityDuration() + extraTime)

func startBattleAbilityVisuals(duration: float) -> void :
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_callback(self, duration, "deactivate")
	$Tween.start()

	match mode:
		Mode.BLAST:
			$Blast.visible = true
			blastSpriteFrame = 49.0
			$Blast / BlastSound.startSound()
			$Blast / BlastLoopSound.startSound()
		Mode.INVULNERABLE:
			$Invulnerable.activate()
		Mode.REFLECT:
			$Reflect / Tween.remove_all()
			$Reflect.visible = true
			$Reflect / ReflectSprite.modulate = Color(1, 1, 1, 1)
			$Reflect / ReflectSprite.scale = Vector2(1, 1)
			$Reflect / ReflectSound.startSound()
			$Reflect / InitiateReflectSound.startSound()

func getBattleAbilityName() -> String:
	match mode:
		Mode.BLAST:
			return tr("upgrades.shieldbattleelectroblast.title")
		Mode.INVULNERABLE:
			return tr("upgrades.shieldbattleinvulnerable.title")
		Mode.REFLECT:
			return tr("upgrades.shieldbattlereflect.title")
	return ""

func getBattleAbilityDuration() -> float:
	var duration = Data.of(teamId + ".shield.battleabilityduration")
	if Data.of(teamId + ".shield.strength") <= 0.0:
		duration += Data.of(teamId + ".shield.battleadditionalabilitydurationafterdepletion")
	return duration

func deactivate():
	active = false
	match mode:
		Mode.BLAST:
			$Blast.visible = false
			$Blast / BlastLoopSound.stop()
			$Blast / BlastEndSound.startSound()
		Mode.INVULNERABLE:
			$Invulnerable.deactivate()
		Mode.REFLECT:
			var duration = 0.15
			$Reflect / Tween.remove_all()
			$Reflect / ReflectSprite.scale = Vector2(1, 1)
			$Reflect / Tween.interpolate_property($Reflect / ReflectSprite, "modulate", Color(1, 1, 1, 1), Color(1, 1, 1, 0), duration, Tween.TRANS_LINEAR)
			$Reflect / Tween.interpolate_callback($Reflect, duration, "hide")
			$Reflect / Tween.start()

	if multiplayer.is_server():
		Data.apply(teamId + ".shield.remainingabilityduration", 0.0)

func pauseChanged():
	if GameWorld.paused:
		$Tween.stop_all()
	else:
		$Tween.resume_all()
