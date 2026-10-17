extends Node2D

class_name Monsters

var spawnPunishers: bool
var disabled: = false
var waveTime: = 0.0
var softRestartWave: = 0.0
var monsterIndex: = 0
var battleIntensity: = 0.0
var battleIntensityStallThreshold: = 0.0
var timeBattleStalled: = 0.0
var keeperInDomeDuringWave: = false
var finale: = false
var forceCountdown: = false
var forceCountdownWavePunishment: = false
var spawnEscalation: = 0
var monstersInWave: = []
var currentWave: Wave
var spawnPlan: Array
var monsterCount: = 0
var teamId: String

var waveDamageCounter: = 0.0
var lastWaveStrengthModChange: = 0.0


var nextWaveType: = 1

var waveCounter: int
var remainingMonsters: int

@export var monsterSynchronizer: MonsterSynchronizer

@onready var _battle_ambience: Node = $BattleAmbience

func init():
	var dome: Dome = Level.domesByTeamId[teamId]
	global_position = Vector2(dome.global_position.x, global_position.y)
	monsterSynchronizer.spawned.connect(registerMonster)

	$WaveGenerator.teamId = teamId

	spawnPunishers = Data.ofOr(teamId + ".monstermodifiers.punishers", true)
	disabled = GameWorld.devMode
	applyTimeBetweenWaves()
	Data.apply(teamId + ".monsters.wavepresent", false)
	Data.apply(teamId + ".monsters.waveStrengthModifier", 1.0)

	Data.listen(self, "map.tilesdestroyed")
	Data.listen(self, teamId + ".dome.health")
	Data.listen(self, teamId + ".inventory.iron")
	Data.listen(self, teamId + ".shield.health")

	_battle_ambience.init(teamId)

	var localTeams: = Utils.get_local_teams(multiplayer.get_unique_id())
	var isBattleAmbienceLocal: bool = localTeams.find(teamId) > -1
	if not isBattleAmbienceLocal:
		_battle_ambience.disable()

func _ready():


	create_tween().tween_callback(updateWaveBattleEnded).set_delay(0.1)

func updateWaveBattleEnded():
	var wave = Data.of(teamId + ".monsters.wavebattle")
	var present = Data.of(teamId + ".monsters.wavepresent")
	if wave and not present:

		Data.apply(teamId + ".monsters.wavebattle", false)

func propertyChanged(property: String, oldValue, newValue):
	if property == "map.tilesdestroyed":
		if newValue >= 8:
			GameWorld.runStarted = true
			Data.unlisten(self, "map.tilesdestroyed")
	elif property == teamId + ".dome.health":
		if newValue < oldValue:
			waveDamageCounter += oldValue - newValue
	elif property == teamId + ".inventory.iron":
		GameWorld.runStarted = true
		Data.unlisten(self, teamId + ".inventory.iron")
	elif property == teamId + ".shield.health":
		var amount = newValue - oldValue
		if amount < 0:
			waveDamageCounter += amount * 0.33

func _process(delta):
	if StageManager.isSwitchingStage():

		return
	if Options.visibleMonsters:
		for m in get_tree().get_nodes_in_group(teamId + "-monster"):
			m.aim(true)

	if not multiplayer.is_server():
		return

	if disabled or GameWorld.paused or not GameWorld.runStarted or GameWorld.lost or GameWorld.won:
		return

	var waveBattle = Data.of(teamId + ".monsters.wavebattle")
	var wavePresent = Data.of(teamId + ".monsters.wavepresent")
	var allInsideStation = Keepers.allInsideStation(teamId)
	if waveBattle and not wavePresent:
		if allInsideStation:
			softRestartWave -= delta
			if softRestartWave <= 0.0:
				Data.apply(teamId + ".monsters.wavebattle", false)
		else:

			Data.apply(teamId + ".monsters.wavebattle", false)

	if forceCountdown:
		var coolodown = Data.of(teamId + ".monsters.waveCooldown")
		if coolodown <= 0.0:
			spawnWave()
		elif coolodown <= GameWorld.getTimeBetweenWaves(teamId) * 0.7 and not forceCountdownWavePunishment:
			forceCountdownWavePunishment = true
			Data.changeByInt(teamId + ".monsters.additionalwaveweight", 40 + ceil(0.2 * Level.mode.getRunWeight(teamId)))

	var atLeastOneKeeperIsInsideDome = Keepers.oneInsideDome(teamId)
	if wavePresent:
		var difficulty: int = Level.difficulty(teamId)
		keeperInDomeDuringWave = keeperInDomeDuringWave or atLeastOneKeeperIsInsideDome
		var gracePeriodOver = waveTime > 10.0 - difficulty * 2.0
		var maxMonsters = max(2, 2 + difficulty)
		var headCount = getCurrentHeadCount()
		var waveStartedFully = keeperInDomeDuringWave or gracePeriodOver
		var belowMinimalMonsterCount = headCount < maxMonsters
		var doSpawn = (waveStartedFully or belowMinimalMonsterCount) and headCount <= currentWave.maxMonsters
		waveTime += delta

		if doSpawn:
			if spawnPlan.size() > monsterIndex + 1:
				var nextMonsterPlan = spawnPlan[monsterIndex + 1]
				if waveTime > nextMonsterPlan.time:
					monsterIndex += 1
					_spawnMonster(nextMonsterPlan.breed, nextMonsterPlan.variant)
			elif monstersInWave.size() == 0 and not $SpawnTween.is_active() and get_tree().get_nodes_in_group(teamId + "-projectile").size() == 0:
				finishWave()
				return

		if waveStartedFully and waveTime >= 10.0:
			if forceCountdown and timeBattleStalled >= 30 + spawnEscalation * 20 and spawnPunishers:
				var monsters: Array
				match spawnEscalation:
					0: monsters = ["walker", "flyer", "stingray", "rockman"]
					1: monsters = ["mucker", "hornet", "worm", "tick"]
					2: monsters = ["diver", "bolter", "shifter", "tick"]
					_: monsters = ["phaser", "breeder", "beast"]
				for _i in 2 + spawnEscalation:
					_spawnMonster(monsters.pick_random(), ["left", "right"].pick_random())
				spawnEscalation += 1
				GameWorld.incrementRunStat("spawn_escalation", teamId)

			var atLeastOneHittable = false
			for m in monstersInWave:
				if m.alive() and not m.invulnerable and m.canBeHit():
					atLeastOneHittable = true
					break

			if atLeastOneHittable:
				battleIntensity = battleIntensity * (1.0 - delta * 0.5) - delta

			if battleIntensity <= battleIntensityStallThreshold and atLeastOneHittable:
				if atLeastOneHittable:
					timeBattleStalled += delta
			elif battleIntensity >= 2 * battleIntensityStallThreshold:
				timeBattleStalled = max(0.0, timeBattleStalled - delta)



		if forceCountdown:
			doWaveCountdown(delta)
		else:
			if timeBattleStalled >= 12.0 and Data.ofOr(teamId + ".monsters.antistall", true):
				applyTimeBetweenWaves()
				countWaveUp()
				forceCountdown = true
				battleIntensityStallThreshold += 30
				GameWorld.incrementRunStat("waves_stalled", teamId)
	elif not waveBattle:
		if Data.of(teamId + ".monsters.wavedelay") > 0.0:
			Data.changeByInt(teamId + ".monsters.wavedelay", - delta * GameWorld.cycleSpeed)
		else:
			doWaveCountdown(delta)

		if Data.of(teamId + ".monsters.waveCooldown") <= 0.0:
			spawnWave()

func hasMonster(UID: int) -> bool:
	return monsterSynchronizer.monsters.has(UID)

func getMonster(UID: int) -> Monster:
	return monsterSynchronizer.monsters.get(UID)

func doWaveCountdown(delta: float):
	var wcd = Data.of(teamId + ".monsters.wavecooldown")
	wcd -= delta * GameWorld.cycleSpeed
	if wcd < 10.0 and Keepers.allInsideStation(teamId):

		wcd -= delta * 1.0
	Data.apply(teamId + ".monsters.waveCooldown", wcd)

func getCurrentHeadCount() -> float:
	var count: = 0.0
	for m in get_tree().get_nodes_in_group(teamId + "-monster"):
		if m.teamId == teamId:
			count += m.headCount
	return count

func applyTimeBetweenWaves(applyOnlyIfCooldownIsZero: = false):
	if not applyOnlyIfCooldownIsZero or Data.of(teamId + ".monsters.waveCooldown") <= 0.0:
		var tbw = GameWorld.getTimeBetweenWaves(teamId)
		Data.apply(teamId + ".monsters.timeBetweenWaves", tbw)
		Data.apply(teamId + ".monsters.waveCooldown", tbw)

func serialize() -> Dictionary:
	var data: = {
		"disabled": disabled, 
		"waveTime": waveTime, 
		"waveCooldown": Data.of(teamId + ".monsters.waveCooldown"), 
		"wavepresent": Data.of(teamId + ".monsters.wavepresent"), 
		"spawnPlan": var_to_str(spawnPlan), 
		"monsterIndex": monsterIndex, 
		"lastMonsters": var_to_str($WaveGenerator.lastMonsters)
	}
	return data

func deserialize(data: Dictionary):
	for m in monstersInWave:
		if is_instance_valid(m):
			m.free()
	monstersInWave.clear()

	await GameWorld.savegame_loaded

	disabled = data["disabled"]
	waveTime = data["waveTime"]
	spawnPlan = BackwardCompatibilityUtils.str_to_var(data["spawnPlan"])
	monsterIndex = data["monsterIndex"]
	if data.has("lastMonsters"):
		$WaveGenerator.lastMonsters = BackwardCompatibilityUtils.str_to_var(data["lastMonsters"])
	Data.apply(teamId + ".monsters.waveCooldown", data["waveCooldown"])
	Data.apply(teamId + ".monsters.wavepresent", data["wavepresent"])

func spawnWave():
	var currentRunWeight = Level.mode.getRunWeight(teamId)
	if currentRunWeight <= 0.0:
		finishWave()
		return

	currentRunWeight *= Data.ofOr(teamId + ".monstermodifiers.onetimewavestrengthmultiplier", 1.0)
	Data.apply(teamId + ".monstermodifiers.onetimewavestrengthmultiplier", 1.0)

	if not Data.of(teamId + ".monsters.wavepresent"):
		SaveGame.saveRollingSavegame(true)
		GameWorld.removeAvailableUpgradeLimit(teamId + ".between_waves")

	waveTime = -2.0
	monsterIndex = -1
	Data.apply(teamId + ".monsters.wavepresent", true)
	Data.apply(teamId + ".monsters.wavebattle", true)
	keeperInDomeDuringWave = false
	forceCountdown = false
	waveDamageCounter = 0
	battleIntensity = 0.0
	GameWorld.incrementRunStat("wave_stall_time", teamId, timeBattleStalled)
	timeBattleStalled = 0
	spawnEscalation = 0
	battleIntensityStallThreshold = Data.ofOr(teamId + ".monsters.antistallthreshold", 20)

	var minimumTimeBetweenMonsters: float
	if Data.has(teamId + ".monsters.minimumtimebetweenmonsters"):
		minimumTimeBetweenMonsters = Data.of(teamId + ".monsters.minimumtimebetweenmonsters")
	else:
		match Level.difficulty(teamId):
			-2: minimumTimeBetweenMonsters = 0.5
			-1: minimumTimeBetweenMonsters = 0.3
			0: minimumTimeBetweenMonsters = 0.17
			2: minimumTimeBetweenMonsters = 0.08
		if Keepers.get_team(teamId).getCount() > 1:
			minimumTimeBetweenMonsters *= 0.66

	var divisor = 2.6 - Level.difficulty(teamId) * 0.1
	var runWeightProgression = 1.0 - ((log(currentRunWeight) / log(10)) - 1.17) / divisor
	Data.apply(teamId + ".monsters.timingmod", clamp(runWeightProgression, minimumTimeBetweenMonsters, 1.0))
	currentWave = $WaveGenerator.generateWave(currentRunWeight, Data.of(teamId + ".monsters.waveStrengthModifier"))
	spawnPlan = currentWave.generateSpawnPlan()

	var w = {
		"waveIndex": Data.of(teamId + ".monsters.cycle"), 
		"currentRunWeight": currentRunWeight, 
		"wave": currentWave.entries, 
		}
	Backend.event("wave_started", w)

func countWaveUp():
	var cycles = Data.of(teamId + ".monsters.cycle") + 1
	Data.apply(teamId + ".monsters.cycle", cycles)
	Data.apply(teamId + ".monsters.additionalcycletime", 15 * pow(cycles, 0.7) - (14 + cycles * 2))
	waveCounter += 1
	forceCountdownWavePunishment = false

func finishWave():
	applyTimeBetweenWaves(true)
	Data.apply(teamId + ".monsters.wavepresent", false)
	$WaveGenerator.waveFinished(currentWave)

	if Data.of(teamId + ".monsters.wavebattle") and not Keepers.allInsideStation(teamId):

		Data.apply(teamId + ".monsters.wavebattle", false)

	GameWorld.incrementRunStat("waves_survived", teamId)

	if not forceCountdown:
		countWaveUp()
	softRestartWave = 5.0
	forceCountdown = false


	if Level.loadout.modeId == CONST.MODE_RELICHUNT:
		var mod: = 1.0
		var damageConsideredBad = 200
		var damageConsideredGood = 80

		if waveDamageCounter > damageConsideredBad:
			mod = -0.6 * ((waveDamageCounter - damageConsideredBad) / (damageConsideredBad * 3.0))

		elif waveDamageCounter < damageConsideredGood:
			mod = 0.05 + (1.0 - (waveDamageCounter / damageConsideredGood)) * 0.1

		else:
			mod = (1.0 - Data.of(teamId + ".monsters.waveStrengthModifier")) * 0.5

		lastWaveStrengthModChange = mod
		var difficulty = Level.difficulty(teamId)
		var oldWaveStrengthModifier = Data.of(teamId + ".monsters.waveStrengthModifier")
		var newWaveStrengthModifier = clamp(oldWaveStrengthModifier + mod, 0.7 - difficulty * 0.1, 1.3 + difficulty * 0.1)
		Data.apply(teamId + ".monsters.waveStrengthModifier", newWaveStrengthModifier)


	SaveGame.saveRollingSavegame()
	currentWave = null
	GameWorld.setUpgradeLimitAvailable(teamId + ".between_waves")

	Backend.event("wave_finished", {
		"waveIndex": Data.of(teamId + ".monsters.cycle"), 
		"waveDamageCounter": waveDamageCounter, 
		"trackedDamageDealt": GameWorld.trackedDamageDealtByTeamId, 
		"trackedDamageReceived": GameWorld.trackedDamageReceivedByTeamId, 
		})

func networkSpawnMonster(breed: String, variant: String, groupSize: = 1):
	var monsterType: Monster.Type
	var buffer: PackedByteArray

	match breed:
		"walker":
			monsterType = Monster.Type.WALKER
			buffer = Walker.get_spawn_data(variant, teamId)
		"flyer":
			monsterType = Monster.Type.FLYER
			buffer = Flyer.get_spawn_data(variant, teamId)
		"stingray":
			monsterType = Monster.Type.STINGRAY
			buffer = Stingray.get_spawn_data(variant, teamId)
		"mucker":
			monsterType = Monster.Type.MUCKER
			buffer = Mucker.get_spawn_data(variant, teamId)
		"bolter":
			monsterType = Monster.Type.BOLTER
			buffer = Bolter.get_spawn_data(variant, teamId)
		"driller":
			monsterType = Monster.Type.DRILLER
			buffer = Driller.get_spawn_data(variant, teamId)
		"shifter":
			monsterType = Monster.Type.SHIFTER
			buffer = Shifter.get_spawn_data(variant, teamId)
		"rockman":
			monsterType = Monster.Type.ROCKMAN
			buffer = Rockman.get_spawn_data(variant, teamId)
		"tormentor":
			monsterType = Monster.Type.TORMENTOR
			buffer = Tormentor.get_spawn_data(variant, teamId)
		"butterfly":
			monsterType = Monster.Type.BUTTERFLY
			buffer = Butterfly.get_spawn_data(variant, teamId)
		"beast":
			monsterType = Monster.Type.BEAST
			buffer = Beast.get_spawn_data(variant, teamId)
		"worm":
			monsterType = Monster.Type.WORM
			buffer = Worm.get_spawn_data(variant, teamId)
		"hornet":
			monsterType = Monster.Type.HORNET
			buffer = Hornet.get_spawn_data(variant, teamId)
		"phaser":
			monsterType = Monster.Type.PHASER
			buffer = Phaser.get_spawn_data(variant, teamId)
		"stag":
			monsterType = Monster.Type.STAG
			buffer = Stag.get_spawn_data(variant, teamId)
		"tick":
			var amount: int = Data.of("tick.groupsize") + round(randf() * Data.of("tick.grouprandom"))
			var time: = 0.0
			var interspawntime = Data.of("tick.interspawntime")
			for _i in range(0, amount):
				$SpawnTween.interpolate_callback(self, time, "_spawnMonster", "tick_single", variant, amount)
				time += interspawntime + randf() * interspawntime

			waveTime -= time * 0.75
			$SpawnTween.start()
			return
		"tick_single":
			monsterType = Monster.Type.TICK
			buffer = Tick.get_spawn_data(variant, teamId, groupSize)
		"bigtick":
			var amount: int = Data.of("bigtick.groupsize") + round(randf() * Data.of("bigtick.grouprandom"))
			var time: = 0.0
			var interspawntime = Data.of("bigtick.interspawntime")
			for _i in range(0, amount):
				$SpawnTween.interpolate_callback(self, time, "_spawnMonster", "bigtick_single", variant, amount)
				time += interspawntime + randf() * interspawntime

			waveTime -= time * 0.75
			$SpawnTween.start()
			return
		"bigtick_single":
			monsterType = Monster.Type.BIGTICK
			buffer = BigTick.get_spawn_data(variant, teamId, groupSize)
		"diver":
			monsterType = Monster.Type.DIVER
			buffer = Diver.get_spawn_data(variant, teamId)
		"breeder":
			monsterType = Monster.Type.BREEDER
			buffer = Breeder.get_spawn_data(variant, teamId)
		"bloater":
			monsterType = Monster.Type.BLOATER
			buffer = Bloater.get_spawn_data(variant, teamId)
		"scarab":
			monsterType = Monster.Type.SCARAB
			buffer = Scarab.get_spawn_data(variant, teamId)
		_:
			push_warning(breed + " not yet supported")

	monsterSynchronizer.network_spawn(monsterType, buffer, teamId, true)

func _spawnMonster(breed: String, variant: String, groupSize: = 1):
	networkSpawnMonster(breed, variant, groupSize)

func registerMonster(monster: Monster) -> void :
	remainingMonsters += 1
	monsterCount += 1
	monster.counter = monsterCount
	monster.connect("died", monsterDied.bind(monster))
	Level.viewports.addMonster(monster)
	monstersInWave.append(monster)

func monsterDied(m):
	monstersInWave.erase(m)
	remainingMonsters -= 1

	if m.inOriginalSpawnPlan:
		battleIntensity += 10 * m.headCount


	if not (finale and disabled):
		var recorded: bool = Recorder.recordMonsterKilled(m.techId, teamId)
		if recorded:
			GameWorld.incrementRunStat("monsters_killed", teamId, m.headCount)

func instantlyKillWave():
	$SpawnTween.remove_all()
	for m in get_tree().get_nodes_in_group(teamId + "-monster"):
		if m.teamId == teamId:
			m.died.emit()
			m.queue_free()
	if Data.of(teamId + ".monsters.wavepresent"):
		remainingMonsters = 0
		finishWave()

func onGameLost():
	disabled = true
	$SpawnTween.remove_all()

func startFinalAct():
	finale = true
	if Data.of(teamId + ".monsters.wavepresent"):

		currentWave = null
		spawnPlan.clear()
	waveTime = -4.0
	monsterIndex = -1
	Data.apply(teamId + ".monsters.timingmod", Data.of(teamId + ".monsters.timingmod") * 0.8)
	Data.apply(teamId + ".monsters.wavepresent", true)
	Data.apply(teamId + ".monsters.wavebattle", true)
	Data.apply(teamId + ".monsters.waveCooldown", 0)
	Data.apply(teamId + ".monsters.wavedelay", 0)

	var fixedStrength = Data.ofOr(teamId + ".monsters.finalwavefixedstrength", 0)
	var mod = Data.ofOr(teamId + ".monstermodifiers.finalwavemultiplicator", 4.5)
	var finalWaveStrength = fixedStrength if fixedStrength > 0 else max(800, Level.mode.getRunWeight(teamId) * mod)
	currentWave = $WaveGenerator.generateWave(finalWaveStrength, 1.0)
	spawnPlan = currentWave.generateSpawnPlan()

func pauseChanged():
	if GameWorld.paused:
		$SpawnTween.stop_all()
	else:
		$SpawnTween.resume_all()

func monsterLostHealth(damageTaken):
	battleIntensity += damageTaken

func domeLostHealth(damageTaken):
	battleIntensity += damageTaken
