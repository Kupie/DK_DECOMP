extends "res://content/gadgets/PrimaryGadget.gd"

@export var synchronizer: Synchronizer

enum Mode{NOTHING, HEALTH_REDUCTION, SLOWDOWN}
var mode: int = Mode.NOTHING

var shouldFocus: = false

var repellentReady: = false
var producing: = false
var grownAfter: = 0.0
var growFactor: = 1.0

var vulnerabilityChange: float = 0.0

var coolDown: = 0.0
var oldStage: = -1
var emitting: = false
var lastBattleAbilityDuration: = 0.0

var battleAbilityActive: = false
var maxStage: int

var affectedMonsters: = {}
var particles
var worldGlitterEffect

func _ready():
	maxStage = $Sprite2D.sprite_frames.get_frame_count("filling_" + domeId)
	$Filling.modulate.a = 0.0
	$Cloud.play("empty")
	$Spinner.pause()
	$FullScreenMist1Particles.emitting = false
	$FullScreenMist2Particles.emitting = false
	$Overcharge.play()
	$Overcharge.visible = false

	worldGlitterEffect = preload("res://content/gadgets/repellent/ScreenGlitterParticles.tscn").instantiate()
	if Level.viewports:
		Level.viewports.addElement(worldGlitterEffect)

	match domeId:
		"dome1":
			$Filling.texture = preload("res://content/gadgets/repellent/dome1/fluid.png")
			$Filling.position = Vector2(0, -13)
			$Spinner.position = Vector2(0, -25)
			$Cloud.position = Vector2(0, -25)
			$Overcharge.position = Vector2(-1, -12)
			position += Vector2(0, 3)
		"dome2":
			$Filling.texture = preload("res://content/gadgets/repellent/dome2/fluid_dome2.png")
			$Filling.position = Vector2(3, -18)
			$Spinner.position = Vector2(3, -36)
			$Cloud.position = Vector2(-7, -32)
			$Overcharge.position = Vector2(1, -18)
			position += Vector2(0, -9)
		"dome3":
			$Filling.texture = preload("res://content/gadgets/repellent/dome3/fluid_dome3.png")
			$Filling.position = Vector2(-3, -8)
			$Spinner.position = Vector2(-3, -20)
			$Cloud.position = Vector2(-13, -14)
			$Overcharge.position = Vector2(-3, -10)
			position += Vector2(4, 0)
		"dome4":
			$Filling.texture = preload("res://content/gadgets/repellent/dome4/fluid_dome4.png")
			$Filling.position = Vector2(3, -18)
			$Spinner.position = Vector2(3, -36)
			$Cloud.position = Vector2(-7, -32)
			$Overcharge.position = Vector2(1, -18)
			position += Vector2(0, -10)
	updateFilling(0)
	$Sprite2D.play("empty_" + domeId)

	if multiplayer.is_server():
		Data.apply(teamId + ".repellent.currentgrowth", 0)
	Data.listen(self, teamId + ".repellent.battlemonstervulnerability", true)
	Data.listen(self, teamId + ".repellent.battleslowdown", true)
	Data.listen(self, teamId + ".repellent.overcharged")
	Data.listen(self, teamId + ".repellent.battleuses")
	Data.listen(self, teamId + ".monsters.wavepresent")
	if multiplayer.is_server() and not SaveGame.currentLoadingSavegame:
		Data.apply(teamId + ".repellent.overcharged", false)
		Data.apply(teamId + ".repellent.remainingbattleuses", 0)

	Style.init(self)

	Level.addTutorial(self, "repellent", teamId)
	Level.addTutorial(self, "overcharge", teamId)

	Achievements.addIfOpen(self, "REPELLENT_BIGDELAY", teamId)

func serialize() -> Dictionary:
	var data = {
		"mode": mode, 
		"shouldFocus": shouldFocus, 
		"repellentReady": repellentReady, 
		"producing": producing, 
		"grownAfter": grownAfter, 
		"growFactor": growFactor, 
		"coolDown": coolDown, 
		"oldStage": oldStage, 
		"emitting": emitting, 
		"maxStage": maxStage, 
		"vulnerabilityChange": vulnerabilityChange
	}
	data["meta.priority"] = 200
	data["meta.kind"] = "station"
	return data

func deserialize(data: Dictionary):
	mode = int(data["mode"])
	shouldFocus = data["shouldFocus"]
	repellentReady = data["repellentReady"]
	producing = data["producing"]
	grownAfter = data["grownAfter"]
	growFactor = data["growFactor"]
	coolDown = data["coolDown"]
	oldStage = data["oldStage"]
	emitting = data["emitting"]
	maxStage = data["maxStage"]
	vulnerabilityChange = data.get("vulnerabilityChange", 0.0)

	await GameWorld.savegame_loaded

	if repellentReady:
		$Filling / BubbleParticles.emitting = true
		$Spinner.pause()
		$Usable.updateFocus()
		$Filling.modulate.a = 1.0
	else:
		$Filling.modulate.a = 0.0
		$Filling / BubbleParticles.emitting = false

	if producing:
		$Sprite2D.frame = 0
		$Spinner.play()

	if emitting:
		$Sprite2D.frame = 0
		updateFilling(0)
		$Filling.modulate.a = 0.0
		worldGlitterEffect.emitting = true
	else:
		worldGlitterEffect.emitting = false

	$Overcharge.visible = Data.of(teamId + ".repellent.overcharged")

	$Sprite2D.play("filling_" + domeId)

	deactivate()

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".monsters.wavepresent":
		if newValue:
			Data.apply(teamId + ".repellent.remainingbattleuses", Data.of(teamId + ".repellent.battleuses"))
		elif not SaveGame.currentLoadingSavegame:
			Data.apply(teamId + ".repellent.remainingbattleuses", 0)
			Data.apply(teamId + ".repellent.overcharged", false)
			Data.apply(teamId + ".repellent.remainingabilityduration", 0)
			deactivate()
	elif property == teamId + ".repellent.battlemonstervulnerability":
		if mode == Mode.NOTHING and newValue > 0:
			mode = Mode.HEALTH_REDUCTION
			add_to_group(teamId + "-dome_ability1")
			$FullScreenMist1Particles.queue_free()
			Style.init($FullScreenMist2Particles)
			particles = $FullScreenMist2Particles
	elif property == teamId + ".repellent.battleslowdown":
		if mode == Mode.NOTHING and newValue > 0:
			mode = Mode.SLOWDOWN
			add_to_group(teamId + "-dome_ability1")
			$FullScreenMist2Particles.queue_free()
			Style.init($FullScreenMist1Particles)
			particles = $FullScreenMist1Particles
	elif property == teamId + ".repellent.overcharged":
		$Overcharge.visible = newValue
	elif property == teamId + ".repellent.battleuses":
		if oldValue != null:
			var delta = newValue - oldValue
			if delta > 0 and Data.of(teamId + ".monsters.wavepresent"):
				Data.changeByInt(teamId + ".repellent.remainingbattleuses", delta)

func _process(delta):
	if GameWorld.paused:
		return

	if multiplayer.is_server() and battleAbilityActive:
		var tell = $AbilityTween.tell()
		var time = $AbilityTween.get_runtime() - tell
		Data.apply(teamId + ".repellent.remainingabilityduration", lastBattleAbilityDuration - tell)
		match int(mode):
			Mode.HEALTH_REDUCTION:
				var damage = Data.of(teamId + ".repellent.battledamageovertime")
				if damage > 0:
					var times = round(time)
					if times > 0 and damage > 0:
						for m in get_tree().get_nodes_in_group(teamId + "-monster"):
							if affectedMonsters.get(m, 0) < 2 and m.canBeHit():
								affectedMonsters[m] = 2
								var stun = 0.33 * m.fullStunAt
								m.sustainIntervalDamage(teamId + ".repellent", damage, stun, 1.0, times, 0.1 + 0.3 * randf())
			Mode.SLOWDOWN:
				var stun = Data.of(teamId + ".repellent.battleslowdown")
				for m in get_tree().get_nodes_in_group(teamId + "-monster"):
					if not affectedMonsters.has(m) and m.canBeHit():
						affectedMonsters[m] = 0
						m.sustainStun(stun * Data.of(m.techId + ".fullStunThreshold"), time)

	if GameWorld.softPaused(teamId):
		return

	if Data.of(teamId + ".monsters.wavedelay") > 0.0:
		return
	elif emitting:
		emitting = false
		$RepellentActiveSound.stop()
		worldGlitterEffect.emitting = false
		return

	if not repellentReady:
		if producing and GameWorld.runStarted:
			var d: float = delta * GameWorld.cycleSpeed
			var repellentGrowth = Data.of(teamId + ".repellent.currentgrowth") + d / grownAfter
			if multiplayer.is_server():
				Data.apply(teamId + ".repellent.currentgrowth", repellentGrowth)
				if repellentGrowth >= 1.0:
					synchronizer.network_rpc(finishProduction, true)
			updateFilling(repellentGrowth)
		elif GameWorld.runStarted and multiplayer.is_server():
			synchronizer.network_rpc(startCharging, true)

func updateFilling(growth: float):
	var frame = clamp(floor((maxStage) * growth), 0, maxStage)
	$Sprite2D.frame = int(frame)

@rpc("reliable")
func finishProduction():
	producing = false
	repellentReady = true
	$Usable.updateFocus()
	$Tween.interpolate_property($Filling, "modulate:a", 0.0, 1.0, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	$Tween.start()
	$Filling / BubbleParticles.emitting = true
	$Spinner.pause()

	$RepellentReadySound.startSound()
	$RepellentCharging.stop()

@rpc("reliable")
func startCharging() -> void :
	repellentReady = false
	$RepellentCharging.startSound()
	producing = true
	grownAfter = GameWorld.getTimeBetweenWaves(teamId) * float(Data.of(teamId + ".repellent.growthTime"))
	$Sprite2D.play("filling_" + domeId)
	$Sprite2D.frame = 0
	updateFilling(0)
	$Spinner.play()

func executeBattle1() -> bool:
	if mode == Mode.NOTHING:
		return false

	if battleAbilityActive:
		return false

	var remainingUses = Data.of(teamId + ".repellent.remainingbattleuses")
	if remainingUses <= 0:
		Audio.sound("gui_err")
		return false

	if multiplayer.is_server():
		Data.apply(teamId + ".repellent.remainingbattleuses", remainingUses - 1)

	var duration = getBattleAbilityDuration()

	battleAbilityActive = true
	match int(mode):
		Mode.HEALTH_REDUCTION:
			if vulnerabilityChange != 0.0:
				Data.changeByInt(teamId + ".monstermodifiers.damagetaken", - vulnerabilityChange)

			vulnerabilityChange = Data.ofOr(teamId + ".repellent.battlemonstervulnerability", 0.0)
			Data.changeByInt(teamId + ".monstermodifiers.damagetaken", vulnerabilityChange)
			$WitherSound.startSound()
		Mode.SLOWDOWN:
			$DebilitateSound.startSound()

	$AbilityTween.interpolate_callback(self, duration, "deactivate")
	$AbilityTween.start()
	lastBattleAbilityDuration = duration

	particles.emitting = true
	$Cloud.play("spray")

	Backend.event("battle_ability_used", {"gadget": "repellent", "ability": Mode.keys()[mode]})
	return true

@rpc("reliable")
func remoteExecuteBattle1(extraTime: = 0.0) -> void :
	var duration = getBattleAbilityDuration()

	battleAbilityActive = true
	match int(mode):
		Mode.HEALTH_REDUCTION:
			vulnerabilityChange = Data.ofOr(teamId + ".repellent.battlemonstervulnerability", 0.0)
			$WitherSound.startSound()
		Mode.SLOWDOWN:
			$DebilitateSound.startSound()

	$AbilityTween.interpolate_callback(self, duration, "deactivate")
	$AbilityTween.start()
	lastBattleAbilityDuration = duration

	particles.emitting = true
	$Cloud.play("spray")

func deactivate():
	if not battleAbilityActive:
		return

	battleAbilityActive = false
	affectedMonsters.clear()
	particles.emitting = false
	match int(mode):
		Mode.HEALTH_REDUCTION:
			Data.changeByInt(teamId + ".monstermodifiers.damagetaken", - vulnerabilityChange)
			vulnerabilityChange = 0
		Mode.SLOWDOWN:
			pass

func getBattleAbilityName() -> String:
	match int(mode):
		Mode.HEALTH_REDUCTION:
			return tr("upgrades.repellentbattlehealthreduction.title")
		Mode.SLOWDOWN:
			return tr("upgrades.repellentbattleslowdown.title")
	return ""

func getBattleAbilityDuration() -> float:
	var duration = Data.of(teamId + ".repellent.battleabilityduration")
	if Data.of(teamId + ".repellent.overcharged"):
		duration += duration * Data.of(teamId + ".repellent.overchargebattleabilityduration")
	return duration

func canFocusUse(keeper: Keeper) -> bool:
	if not Data.of(teamId + ".monsters.wavepresent") and repellentReady:
		return true
	if canOvercharge():
		return true
	return false

func useHold(keeper: Keeper) -> bool:
	if canOvercharge():
		synchronizer.rpc_server(registerHold.bind(keeper.playerId))
		if Data.of(teamId + ".inventory.water") > 0:
			if not $NoOverchargeSound.playing:
				$NoOverchargeSound.startSound()
			return false
		else:
			return true
	else:
		return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if not canFocusUse:
		return false

	synchronizer.rpc_server(registerHit.bind(keeper.playerId))
	return true

@rpc("reliable", "any_peer")
func registerHold(playerId: String) -> void :
	if canOvercharge():
		return tryOvercharge()
	else:
		registerHit(playerId)

@rpc("reliable", "any_peer")
func registerHit(playerId: String) -> void :
	if repellentReady:
		Data.apply(teamId + ".repellent.currentgrowth", 0.0)

		var delay: float = Data.of(teamId + ".repellent.wavedelay")
		Data.changeByInt(teamId + ".repellent.delayedcycles", delay)

		delay = delay * 0.3 * GameWorld.getTimeBetweenWaves(teamId) + delay * 0.7 * 60
		Data.changeByInt(teamId + ".monsters.wavedelay", delay)

		Backend.event("gadget_used", {"gadget": "repellent"})

		synchronizer.network_rpc(playHitVisuals, true)
	else:
		return tryOvercharge()

@rpc("reliable")
func playHitVisuals() -> void :
	repellentReady = false
	$ReleaseSound.startSound()
	$Tween.stop_all()
	$Tween.remove_all()
	$Filling.modulate.a = 0.0
	$Filling / BubbleParticles.emitting = false

	$Tween.interpolate_callback(worldGlitterEffect, 2.0, "set", "emitting", true)
	$Tween.start()
	emitting = true
	$Sprite2D.play("spray_" + domeId)
	$Cloud.play("spray")

	$RepellentActiveSound.startSound()

func overcharge():
	Data.apply(teamId + ".repellent.overcharged", true)

	Data.changeByInt(teamId + ".inventory.water", -1)
	Backend.event("gadget_overcharged", {"gadget": "repellent"})

	synchronizer.network_rpc(playOverchargeVisuals, true)

@rpc("reliable")
func playOverchargeVisuals() -> void :
	$OverchargeSound.startSound()
	$Overcharge.visible = true

func canOvercharge() -> bool:
	return not Data.of(teamId + ".repellent.overcharged") and Data.of(teamId + ".repellent.overchargebattleabilityduration") > 0.0

func _on_Cloud_animation_finished():
	$Cloud.play("empty")

func pauseChanged():
	if GameWorld.paused:
		$Tween.stop_all()
		$AbilityTween.stop_all()
	else:
		$Tween.resume_all()
		$AbilityTween.resume_all()

func remove():
	queue_free()
