class_name Relichunt extends Node

var started: = false
var relicRetrieved: = false
var relicTriggered: = false
var maxD: = 0.0
var mod2: = 0.0
var mod3: = 0.0
var musicPlaying: = false
var maxDesperation: = 0.0
var runWeightOverride: = -1

var relicRetrievalMusicType: String

func init():
	Data.listen(self, "inventory.floatingrelic")
	Data.listen(self, "team1.inventory.relic")
	Data.listen(self, "team1.dome.health")
	Data.listen(self, "game.over")

	Achievements.addIfOpen(self, "RELICHUNT_SPEEDY")

func afterInitialized():
	if not multiplayer.is_server() or Network.multiplayer_mode != Network.MultiplayerMode.OFFLINE_SINGLEPLAYER:
		return

	if GameWorld.gadgetToKeep != "":
		if GameWorld.keptGadgetUsed:
			GameWorld.gadgetToKeep = ""
		else:
			var teamId: = "team1"
			if GameWorld.isUpgradeAddable(GameWorld.gadgetToKeep, teamId):

				var gadgetId: String = GameWorld.gadgetToKeep
				if Data.gadgets[GameWorld.gadgetToKeep].get("takeslots", []).has("keepersuit"):
					gadgetId = "player1." + gadgetId
				GameWorld.addUpgrade(gadgetId, teamId)

				Data.changeByInt("team1.inventory.gadget", -1)
				GameWorld.keptGadgetUsed = true
				print("Consuming the kept gadget from the last relichunt run: ", GameWorld.gadgetToKeep)

func propertyChanged(property: String, oldValue, newValue):
	match property:
		"game.over":
			if newValue == "won":
				await get_tree().create_timer(3.0).timeout

				if not relicTriggered:
					Achievements.triggerIfOpen("RELICHUNT_BEATFINALE")
					if Keepers.local.getAll().any( func(keeper: Keeper): return keeper.techId == "keeper1"):
						GameWorld.newSkinsToUnlock.append({"keeperId": "keeper1", "skinId": "skin2"})

				if Level.difficulty("team1") == 2\
				and Level.loadout.modeConfig.get(CONST.MODE_CONFIG_MAP_ARCHETYPE, "") == CONST.MAP_HUGE\
				and Level.loadout.modeConfig.get(CONST.MODE_CONFIG_WORLDMODIFIERS, []) == []\
				and Keepers.local.getAll().any( func(keeper: Keeper): return keeper.techId == "keeper4")\
				and Platform.purchased_keeper_dlc():
					GameWorld.newSkinsToUnlock.append({"keeperId": "keeper4", "skinId": "skin2"})

				if GameWorld.is_coop()\
				and Platform.purchased_keeper_dlc()\
				and Keepers.local.getAll().any( func(keeper: Keeper): return keeper.techId == "keeper4")\
				and not GameWorld.upgradeLimits.has("team1.hostile"):
					GameWorld.newSkinsToUnlock.append({"keeperId": "keeper4", "skinId": "skin4"})

				match Level.loadout.modeConfig.get(CONST.MODE_CONFIG_MAP_ARCHETYPE, ""):
					CONST.MAP_SMALL: Achievements.triggerIfOpen("RELICHUNT_MAPSMALL")
					CONST.MAP_MEDIUM: Achievements.triggerIfOpen("RELICHUNT_MAPMEDIUM")
					CONST.MAP_LARGE: Achievements.triggerIfOpen("RELICHUNT_MAPLARGE")

		"team1.monsters.wavepresent":

			if not newValue:
				GameWorld.handleGameWon()

				Audio.stopBattleMusic()
				Level.stage.stopKeeperInput()
				for mm in get_tree().get_nodes_in_group("monster-manager"):
					mm.disabled = true
				fadeDesperationOut(true)

				await get_tree().create_timer(3.0).timeout

				if relicTriggered:
					Audio.startEnding()
				else:
					Audio.startEnding(0.0, true)

				await get_tree().create_timer(4.0).timeout

				var popup = preload("res://content/gamemode/relichunt/RunFinishedPopup.tscn").instantiate()
				popup.init(multiplayer.is_server())
				Level.stage.showEndingPanel(popup)
				SaveGame.delete_autosave()
			else:
				$DesperationLayer1.volume_db = -60
				$DesperationLayer2.volume_db = -60
				$DesperationLayer1.play()
				$DesperationLayer2.play()
				$DesperationTween.interpolate_property($DesperationLayer1, "volume_db", -60, 0, 5.0)
				$DesperationTween.start()
		"inventory.floatingrelic":
			started = true
		"team1.inventory.relic":
			if newValue == 1:
				SaveGame.allow_saving = false
				relicRetrieved = true
				if GameWorld.upgradeLimits.has("team1.hostile"):
					for mm in get_tree().get_nodes_in_group("monster-manager"):
						$ScriptTween.interpolate_callback(mm, 3.0, "startFinalAct")
					$ScriptTween.start()
					Data.changeDomeHealth(Data.of("team1.dome.maxHealth") - Data.of("team1.dome.health"), "team1")
					if not Data.of("team1.monsters.wavepresent"):
						Data.listen(self, "team1.monsters.wavepresent")
					else:



						await get_tree().create_timer(3).timeout
						Data.listen(self, "team1.monsters.wavepresent")

					fadeRetrievalMusicOut()
				else:
					GameWorld.handleGameWon()
					Audio.stopBattleMusic()
					Level.stage.stopKeeperInput()
					await get_tree().create_timer(2.5).timeout
					Audio.startEnding()
					await get_tree().create_timer(4.0).timeout
					var popup = preload("res://content/gamemode/relichunt/RunFinishedPopup.tscn").instantiate()
					popup.init(multiplayer.is_server())
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
					var vignette: Vignette = Level.stage.getVignette(keeper)
					vignette.setTarget(bomb.get_node("Orbs"))
					vignette.strengthStartY = -450
					vignette.strengthEndY = 1000
					vignette.processOnlyForTarget()
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
				var popup = preload("res://content/gamemode/relichunt/RunFinishedPopup.tscn").instantiate()
				popup.init(multiplayer.is_server())
				Level.stage.showEndingPanel(popup)

func getRunWeight(teamId: String) -> float:
	if runWeightOverride != -1:
		return float(runWeightOverride)

	var weight: = 10.0 + float(Data.ofOr(teamId + ".monsters.additionalwaveweight", 0))
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
	if not started:
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

	Level.stage.blockMusic = true
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
	Level.stage.blockMusic = false
	$MusicTween.stop_all()
	$MusicTween.remove_all()
	$MusicTween.interpolate_property($RelicRetrievalLayer1Intro, "volume_db", $RelicRetrievalLayer1Intro.volume_db, -60, time, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$MusicTween.interpolate_property($RelicRetrievalLayer1Loop, "volume_db", $RelicRetrievalLayer1Loop.volume_db, -60, time, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$MusicTween.interpolate_property($RelicRetrievalLayer2Loop, "volume_db", $RelicRetrievalLayer2Loop.volume_db, -60, time, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$MusicTween.interpolate_property(self, "mod2", mod2, 0.0, 1.0, Tween.TRANS_LINEAR, Tween.EASE_IN)
	$MusicTween.start()

func _on_RelicRetrievalLayer1Intro_finished():
	if not GameWorld.gameover and musicPlaying:
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
