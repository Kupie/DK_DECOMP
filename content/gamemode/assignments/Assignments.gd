extends Node

var ending: = false
var relicRetrievalStarted: = false
var relicRetrieved: = false
var relicTriggered: = false
var maxD: = 0.0
var mod2: = 0.0
var mod3: = 0.0
var musicPlaying: = false
var maxDesperation: = 0.0
var runWeightOverride: = -1

var relicRetrievalMusicType: String

var assignment: Assignment

func init():
	Data.listen(self, "team1.dome.health")
	Data.listen(self, "game.over")

	assignment = Data.assignments.get(Data.of("assignment.id"))


	if Data.ofOr("team1.run.durationcycles", 0) > 0:
		Data.listen(self, "team1.monsters.cycle")


	match assignment.goaltype:
		"relic":
			Data.listen(self, "inventory.floatingrelic")
			Data.listen(self, "team1.inventory.relic")
		"property":
			Data.listen(self, "team1." + assignment.goalvalue.property_key)

func afterInitialized():
	if Data.ofOr("team1.game.fixedtimelimit", 0) > 0:
		var hud = preload("res://content/gamemode/assignments/FixedTimeLimitHud.tscn")
		Level.addHudElement(hud, "team1")

	if Data.ofOr("team1.run.durationcycles", 0) > 0:
		Data.apply("team1.wavemeter.showcounter", true)

	GameWorld.upgrades["team1.assignments"]["overwriteTitleKey"] = "assignment." + assignment.id + ".title"
	GameWorld.upgrades["team1.assignments"]["overwriteDescKey"] = "assignment." + assignment.id + ".desc"

	if not GameWorld.upgrades.values().filter( func(upgrade): return upgrade.has("rounddue")).is_empty()\
	and not Data.isListening(self, "team1.monsters.cycle"):
		Data.listen(self, "team1.monsters.cycle")

func propertyChanged(property: String, oldValue, newValue):
	if assignment.goalvalue and "team1." + assignment.goalvalue.property_key == property:
		if GameWorld.runStarted and assignment.goalvalue.fulfilled(Data.values, "team1"):
			handlePropertyGoalGameEnd()
		return
	match property:
		"team1.monsters.cycle":
			if SaveGame.currentLoadingSavegame:
				return

			if int(newValue) == int(Data.ofOr("team1.run.durationcycles", -1)):
				match assignment.goaltype:
					"survive":
						SaveGame.allow_saving = false
						for mm in get_tree().get_nodes_in_group("monster-manager"):
							$ScriptTween.interpolate_callback(mm, 3.0, "startFinalAct")
						$ScriptTween.start()
						Data.listen(self, "team1.monsters.wavepresent")
					"property":
						handlePropertyGoalGameEnd()

			var cycle: int = Data.of("team1.monsters.cycle")
			for upgradeKey in GameWorld.upgrades:
				var upgrade = GameWorld.upgrades[upgradeKey]
				if cycle >= upgrade.get("rounddue", 99999)\
				and not GameWorld.boughtUpgrades.has(upgradeKey):
					handlePropertyGoalGameEnd()
					break
		"game.over":
			if newValue == "won"\
			and Keepers.local.getAll().any( func(keeper: Keeper): return keeper.techId == "keeper3")\
			and Data.ofOr("assignment.challengemode", false)\
			and Platform.purchased_keeper_dlc():
				GameWorld.newSkinsToUnlock.append({"keeperId": "keeper3", "skinId": "skin2"})

			if newValue == "won"\
			and GameWorld.is_coop()\
			and Platform.purchased_keeper_dlc()\
			and Keepers.local.getAll().any( func(keeper: Keeper): return keeper.techId == "keeper4")\
			and not GameWorld.upgradeLimits.has("team1.hostile"):
				GameWorld.newSkinsToUnlock.append({"keeperId": "keeper4", "skinId": "skin4"})

		"team1.monsters.wavepresent":
			if relicRetrievalStarted:
				if not newValue:
					GameWorld.handleGameWon()

					Audio.stopBattleMusic()
					Level.stage.stopKeeperInput()
					for mm in get_tree().get_nodes_in_group("monster-manager"):
						mm.disabled = true
					fadeDesperationOut(true)

					await get_tree().create_timer(3.0).timeout

					if not relicTriggered:
						Achievements.triggerIfOpen("RELICHUNT_BEATFINALE")
						if Keepers.local.getAll().any( func(keeper: Keeper): return keeper.techId == "keeper1"):
							GameWorld.newSkinsToUnlock.append({"keeperId": "keeper1", "skinId": "skin2"})
						Audio.startEnding(0.0, true)
					else:
						Audio.startEnding()
					await get_tree().create_timer(4.0).timeout

					var popup = preload("res://content/gamemode/assignments/RunFinishedPopup.tscn").instantiate()
					var medals_earned = update_assignments_progress(assignment)
					popup.init(multiplayer.is_server(), assignment, medals_earned)
					Level.stage.showEndingPanel(popup)
					SaveGame.delete_autosave()
				else:
					$DesperationLayer1.volume_db = -60
					$DesperationLayer2.volume_db = -60
					$DesperationLayer1.play()
					$DesperationLayer2.play()
					$DesperationTween.interpolate_property($DesperationLayer1, "volume_db", -60, 0, 5.0)
					$DesperationTween.start()
			else:
				if not newValue:
					Level.moveHudOut()
					Level.stage.stopKeeperInput()
					Audio.startEnding()

					await get_tree().create_timer(3.0).timeout
					GameWorld.handleGameWon({"assignment-id": assignment.id})
					var popup = preload("res://content/gamemode/assignments/RunFinishedPopup.tscn").instantiate()
					var medals_earned = update_assignments_progress(assignment)
					popup.init(multiplayer.is_server(), assignment, medals_earned)
					Level.stage.showEndingPanel(popup)
		"inventory.floatingrelic":
			relicRetrievalStarted = true
		"team1.inventory.relic":
			if newValue == 1:
				SaveGame.allow_saving = false
				relicRetrieved = true
				if GameWorld.upgradeLimits.has("team1.hostile"):
					for mm in get_tree().get_nodes_in_group("monster-manager"):
						$ScriptTween.interpolate_callback(mm, 3.0, "startFinalAct")
					$ScriptTween.start()
					Data.changeDomeHealth(Data.of("team1.dome.maxHealth") - Data.of("team1.dome.health"), "team1")
					Data.listen(self, "team1.monsters.wavepresent")
					fadeRetrievalMusicOut()
				else:
					GameWorld.handleGameWon()
					Audio.stopBattleMusic()
					Level.stage.stopKeeperInput()
					await get_tree().create_timer(2.5).timeout
					Audio.startEnding()
					await get_tree().create_timer(4.0).timeout
					var popup = preload("res://content/gamemode/assignments/RunFinishedPopup.tscn").instantiate()
					var medals_earned = update_assignments_progress(assignment)
					popup.init(multiplayer.is_server(), assignment, medals_earned)
					Level.stage.showEndingPanel(popup)
					SaveGame.delete_autosave()
		"team1.dome.health":
			if not Data.of("team1.dome.healthlocked") and newValue > 0:
				maxDesperation = min(maxDesperation, 1.0 - Data.of("team1.dome.health") / float(Data.of("team1.dome.maxhealth")))
				$DesperationLayer2.volume_db = -40 + 40 * maxDesperation
			else:
				fadeDesperationOut()

			if relicRetrieved and (newValue <= 0 and not (Data.of("team1.inventory.sand") > 0 and Data.ofOr("team1.dome.autorepair", false))) and not relicTriggered:
				relicTriggered = true
				for keeper: Keeper in Keepers.local.getAll():
					Level.stage.getVignette(keeper).forceShow()
				Data.apply("team1.dome.healthlocked", true)
				var busIdx = AudioServer.get_bus_index(Audio.BUS_WORLD)
				var amplify: AudioEffectAmplify = AudioServer.get_bus_effect(busIdx, 0)
				amplify.volume_db = -9

				var bomb = load("res://content/gadgets/cobaltbomb/CobaltBomb.tscn").instantiate()
				bomb.teamId = "team1"
				Level.viewports.addElement(bomb)
				for mm in get_tree().get_nodes_in_group("monster-manager"):
					mm.disabled = true
				Level.stage.fadeOutTime = 2.5
				Data.unlisten(self, "team1.dome.health")
				Audio.stopBattleMusic()
				Level.stage.stopKeeperInput()
				InputSystem.shake(80, 1, 8)

				for keeper: Keeper in Keepers.local.getAll():
					var vignette = Level.stage.getVignette(keeper)
					vignette.setTarget(bomb.get_node("Orbs"))
					vignette.strengthStartY = -450
					vignette.strengthEndY = 1000
					$ScriptTween.interpolate_property(vignette, "strengthEndY", vignette.strengthEndY, -100, 1.0, Tween.TRANS_LINEAR, 0.0)
					$ScriptTween.interpolate_property(vignette, "strengthEndY", -100, vignette.strengthEndY, 2.5, Tween.TRANS_LINEAR, Tween.EASE_IN, 2.0)
				$ScriptTween.interpolate_callback(Data, 5.0, "apply", "team1.monsters.wavepresent", false)
				$ScriptTween.start()
			elif newValue <= 0 and not GameWorld.lost:
				Level.moveHudOut()
				fadeDesperationOut()
				GameWorld.lost = true
				var delay = Level.stage.playGameLostAnimation()

				await get_tree().create_timer(delay).timeout
				Audio.sound("lose")
				await get_tree().create_timer(0.2).timeout
				GameWorld.handleGameLost()

				Audio.startGameOver(1.0)
				await get_tree().create_timer(5.0).timeout
				var popup = preload("res://content/gamemode/assignments/RunFinishedPopup.tscn").instantiate()
				var medals_earned = update_assignments_progress(assignment)
				popup.init(multiplayer.is_server(), assignment, medals_earned)
				Level.stage.showEndingPanel(popup)

@rpc("reliable")
func handlePropertyGoalGameEnd():
	Level.moveHudOut()
	Level.stage.stopKeeperInput()

	if assignment.goalvalue.fulfilled(Data.values, "team1"):
		Audio.startEnding()
		await get_tree().create_timer(2.5).timeout
		GameWorld.handleGameWon({"assignment-id": assignment.id})
	else:
		Audio.sound("lose")
		await get_tree().create_timer(2.5).timeout
		for dome in Level.domesByTeamId.values():
			dome.collapsed = true
		GameWorld.handleGameLost()
		Keepers.first().visible = true

	var popup = preload("res://content/gamemode/assignments/RunFinishedPopup.tscn").instantiate()
	var medals_earned = update_assignments_progress(assignment)
	popup.init(multiplayer.is_server(), assignment, medals_earned)
	Level.stage.showEndingPanel(popup)

func getRunWeight(teamId: String) -> float:
	var fixedWeight = Data.ofOr(teamId + ".monsters.fixedweight", -1)
	if fixedWeight >= 0:
		return float(fixedWeight)

	var weight: = 10 + float(Data.ofOr(teamId + ".monsters.additionalwaveweight", 0))
	weight += Data.of("inventory.totaliron") * 0.6
	weight += Data.of("inventory.totalsand") * 2.2
	weight += Data.of("inventory.totalwater") * 1.2
	weight += Data.of(teamId + ".inventory.gadget") * 8
	weight += Data.of(teamId + ".inventory.powercore") * 8
	var cycle = Data.of(teamId + ".monsters.cycle")
	var cycleWeight = round(cycle * ((9 + Level.difficulty(teamId)) + cycle * 0.15)) + cycle * 2
	weight += cycleWeight * Data.of(teamId + ".monstermodifiers.cyclesrunweightmodifier")
	weight += GameWorld.additionalRunWeight
	weight *= 1.0 + Level.difficulty(teamId) * 0.1
	weight *= Data.of(teamId + ".monsters.strengthmodfromplayercount")
	return max(15, weight) * Data.of(teamId + ".monstermodifiers.totalrunweightmodifier")

func _process(delta):
	if not ending and multiplayer.is_server():
		var timeLimit = Data.ofOr("team1.game.fixedtimelimit", 0)
		if timeLimit > 0 and timeLimit * 60 <= GameWorld.runTime:
			Network.rpc_if_state(handlePropertyGoalGameEnd, Network.ConnectionState.LEVEL_STAGE_SYNC, true)
			ending = true

	if not relicRetrievalStarted:
		return

	var relics = get_tree().get_nodes_in_group("relic")
	if relics.size() == 0 or relicRetrieved:
		return

	var relic = relics.front()
	if maxD == 0.0:
		maxD = relic.global_position.length()

	if relic.isCarried():
		if not musicPlaying:
			var currentCarrier = relic.carriedBy.front().techId
			fadeRetrievalMusicIn(currentCarrier)
		$RelicRetrievalLayer1Loop.volume_db = -60 + 60 * mod3
		$RelicRetrievalLayer2Loop.volume_db = -60 + 60 * clamp(1.0 - (relic.global_position.length() - 500) / maxD, 0.0, 1.0) * mod2
	elif musicPlaying:
		fadeRetrievalMusicOut()

func fadeRetrievalMusicIn(currentCarrier: String):
	if currentCarrier != relicRetrievalMusicType:
		relicRetrievalMusicType = currentCarrier
		match relicRetrievalMusicType:
			"keeper1":
				$RelicRetrievalLayer1Intro.stream = preload("res://content/music/ENGINEER Relic Retrieval Layer 1 [intro].ogg")
				$RelicRetrievalLayer1Loop.stream = preload("res://content/music/ENGINEER Relic Retrieval Layer 1 [loop].ogg")
				$RelicRetrievalLayer2Loop.stream = preload("res://content/music/ENGINEER Relic Retrieval Layer 2 [loop].ogg")
				$DesperationLayer1.stream = preload("res://content/music/LASER Desperation Layer 1 [loop].ogg")
				$DesperationLayer2.stream = preload("res://content/music/LASER Desperation Layer 2 [loop].ogg")
			"keeper2":
				$RelicRetrievalLayer1Intro.stream = preload("res://content/music/ASSESSOR Relic Retrieval Layer 1 [intro].ogg")
				$RelicRetrievalLayer1Loop.stream = preload("res://content/music/ASSESSOR Relic Retrieval Layer 1 [loop].ogg")
				$RelicRetrievalLayer2Loop.stream = preload("res://content/music/ASSESSOR Relic Retrieval Layer 2 [loop].ogg")
				$DesperationLayer1.stream = preload("res://content/music/ASSESSOR Final Push Layer 1 [loop].ogg")
				$DesperationLayer2.stream = preload("res://content/music/ASSESSOR Final Push Layer 2 [loop].ogg")
			"keeper3":
				$RelicRetrievalLayer1Intro.stream = preload("res://content/music/keeper3/keeper3_relic_layer1_intro.ogg")
				$RelicRetrievalLayer1Loop.stream = preload("res://content/music/keeper3/keeper3_relic_layer1_loop.ogg")
				$RelicRetrievalLayer2Loop.stream = preload("res://content/music/keeper3/keeper3_relic_layer2_loop.ogg")
				$DesperationLayer1.stream = preload("res://content/music/keeper3/keeper3_final_wave_layer1_loop.ogg")
				$DesperationLayer2.stream = preload("res://content/music/keeper3/keeper3_final_wave_layer2_loop.ogg")
			"keeper4":
				$RelicRetrievalLayer1Intro.stream = preload("res://content/music/keeper4/keeper4_relic_layer1_intro.ogg")
				$RelicRetrievalLayer1Loop.stream = preload("res://content/music/keeper4/keeper4_relic_layer1_loop.ogg")
				$RelicRetrievalLayer2Loop.stream = preload("res://content/music/keeper4/keeper4_relic_layer2_loop.ogg")
				$DesperationLayer1.stream = preload("res://content/music/keeper4/keeper4_final_wave_layer1_loop.ogg")
				$DesperationLayer2.stream = preload("res://content/music/keeper4/keeper4_final_wave_layer2_loop.ogg")


	musicPlaying = true

	Audio.stopMusic()
	if not $RelicRetrievalLayer1Loop.playing:
		mod3 = 0.0
		$RelicRetrievalLayer1Intro.play()
		$RelicRetrievalLayer1Loop.play()
		$RelicRetrievalLayer2Loop.play()
	$MusicTween.interpolate_property($RelicRetrievalLayer1Intro, "volume_db", $RelicRetrievalLayer1Intro.volume_db, 0, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$MusicTween.interpolate_property(self, "mod2", 0.0, 1.0, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$MusicTween.start()

func fadeRetrievalMusicOut(time: = 4.0):
	musicPlaying = false
	$MusicTween.stop_all()
	$MusicTween.remove_all()
	$MusicTween.interpolate_property($RelicRetrievalLayer1Intro, "volume_db", $RelicRetrievalLayer1Intro.volume_db, -60, time, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$MusicTween.interpolate_property($RelicRetrievalLayer1Loop, "volume_db", $RelicRetrievalLayer1Loop.volume_db, -60, time, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$MusicTween.interpolate_property($RelicRetrievalLayer2Loop, "volume_db", $RelicRetrievalLayer2Loop.volume_db, -60, time, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$MusicTween.interpolate_property(self, "mod2", mod2, 0.0, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$MusicTween.start()

func _on_RelicRetrievalLayer1Intro_finished():
	if not GameWorld.gameover:
		$RelicRetrievalLayer1Loop.volume_db = 0.0
		mod3 = 1.0

func fadeDesperationOut(force: = false):
	if force:
		$DesperationTween.stop_all()
		$DesperationTween.remove_all()
	if force or not $DesperationTween.is_active():
		$DesperationTween.interpolate_property($DesperationLayer1, "volume_db", $DesperationLayer1.volume_db, -60, 2.0)
		$DesperationTween.interpolate_property($DesperationLayer2, "volume_db", $DesperationLayer2.volume_db, -60, 2.0)
		$DesperationTween.start()


func update_assignments_progress(assignment) -> int:
	if not GameWorld.won:
		return 0

	var previous_progress = GameWorld.assignmentProgress.get(assignment.id, 0)
	var earned: int = maxi(0, (2 if Data.of("assignment.challengemode") else 1) - previous_progress)
	GameWorld.assignmentProgress[assignment.id] = previous_progress + earned

	if Platform.purchased_keeper_dlc()\
	and Keepers.local.getAll().any( func(keeper: Keeper): return keeper.techId == "keeper4"):
		for assignment_id in Data.keeperDlcAssignments:
			if GameWorld.assignmentProgress.get(assignment_id, 0) == 0:
				return earned

		GameWorld.newSkinsToUnlock.append({"keeperId": "keeper4", "skinId": "skin5"})

	return earned
