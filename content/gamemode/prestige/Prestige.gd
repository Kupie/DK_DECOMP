extends Node

func init():
	Data.apply("prestige.score", 0)

	match Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT):
		CONST.MODE_PRESTIGE_MINER:
			Data.apply("prestige.baseperwave", 1)
			Data.apply("prestige.multiplier", 1)
			Data.listen(self, "team1.event.keepers.insidedome")
		CONST.MODE_PRESTIGE_COUNTDOWN:
			Data.apply("prestige.baseperwave", 1)
			Data.apply("prestige.multiplier", 20)
		CONST.MODE_PRESTIGE_PROVOCATION:
			Data.apply("prestige.baseperwave", 100)
			Data.apply("prestige.multiplier", 5)
		CONST.MODE_PRESTIGE_ENDLESS:
			Data.apply("prestige.baseperwave", 1)
			Data.apply("prestige.multiplier", 1)
			Achievements.addIfOpen(self, "PRESTIGE_MULTIPLIER")

	Data.listen(self, "team1.monsters.cycle")
	Data.listen(self, "team1.dome.health")
	Data.listen(self, "team1.upgrade.gameover")

	Achievements.addIfOpen(self, "PRESTIGE_CHUNK")
	Achievements.addIfOpen(self, "PRESTIGE_WIN")

	var backgrounds: Array = get_tree().get_nodes_in_group("ParallaxBG")
	for background: ParallaxBG in backgrounds:
		if background._isPrototype:
			continue
		background.addBackgroundHub(preload("res://content/gamemode/prestige/rocket/RocketHub.tscn").instantiate())

	if multiplayer.is_server():
		Lobby.member_removed.connect(on_member_removed, CONNECT_ONE_SHOT)

	CheatDetection.start()

func afterInitialized():
	if not GameWorld.devMode:
		var enabledIllegalMods: = get_enabled_mods_not_allowed_in_prestige()
		if enabledIllegalMods.size() > 0:
			$ScriptTween.interpolate_callback(StageManager, 0.5, "startStage", "stages/error/error")
			$ScriptTween.start()

	if SaveGame.currentLoadingSavegame:
		await GameWorld.savegame_loaded
		var freeCycles = 2 + round(sqrt(int(Data.of("team1.monsters.cycle"))))
		var overshoot = 0.02 * clamp(GameWorld.loadCount - freeCycles, 0, 20)
		Data.apply("team1.monstermodifiers.totalrunweightmodifier", 1.0 + overshoot)
		Data.apply("team1.monstermodifiers.damage", 1.0 + overshoot)

func propertyChanged(property: String, oldValue, newValue):
	match property:
		"team1.event.keepers.insidedome":
			if Keepers.oneInsideMine():
				GameWorld.runStarted = true
				Data.apply("team1.wavemeter.showbar", true)
				Data.unlisten(self, "team1.event.keepers.insidedome")
		"team1.upgrade.gameover":
			if GameWorld.is_coop()\
			and Platform.purchased_keeper_dlc()\
			and Keepers.local.getAll().any( func(keeper: Keeper): return keeper.techId == "keeper4")\
			and not GameWorld.upgradeLimits.has("team1.hostile"):
				GameWorld.newSkinsToUnlock.append({"keeperId": "keeper4", "skinId": "skin4"})

			for keeper in Keepers.getAll():
				keeper.exitStation()
			Level.stage.stopKeeperInput()
			Level.moveHudOut()
			GameWorld.handleGameWon({"prestigeScore": Data.of("prestige.score")})
			for mm in get_tree().get_nodes_in_group("monster-manager"):
				mm.disabled = true
			Data.unlisten(self, "team1.dome.health")

			if Data.of("team1.monsters.wavepresent"):
				Data.apply("team1.monsters.wavepresent", false)

			for m in get_tree().get_nodes_in_group("team1-monster"):
				m.onGameLost()

			Audio.stopBattleMusic()
			await get_tree().create_timer(0.2).timeout
			Audio.startEnding()
			await get_tree().create_timer(4.0).timeout



			var popup = preload("res://content/gamemode/prestige/RunFinishedPopup.tscn").instantiate()
			popup.init(multiplayer.is_server())
			Level.stage.showEndingPanel(popup)
		"team1.monsters.cycle":
			var multiplier = Data.of("team1.prestige.multiplier")
			var base = Data.of("team1.prestige.baseperwave")
			var change = max(0, int(base) * int(multiplier))
			var newScore = change + int(Data.of("team1.prestige.score"))
			if SaveGame.currentLoadingSavegame:
				return
			if newValue != oldValue:
				CheatDetection.registerPrestige(base, multiplier, newScore)
			match Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT, ""):
				CONST.MODE_PRESTIGE_PROVOCATION:
					if multiplier == 0:
						Data.apply("team1.prestige.score", newScore * 2)
						Level.stage.stopKeeperInput()
						Audio.startEnding()

						await get_tree().create_timer(3.0).timeout
						GameWorld.handleGameWon({"prestigeScore": newScore})
						var popup = preload("res://content/gamemode/prestige/RunFinishedPopup.tscn").instantiate()
						popup.init(multiplayer.is_server())
						Level.stage.showEndingPanel(popup)
					else:
						Data.apply("team1.prestige.score", newScore)
						Data.apply("team1.prestige.multiplier", multiplier - 1)
				CONST.MODE_PRESTIGE_COUNTDOWN:
					if newValue == 20:
						Data.apply("team1.prestige.score", newScore * 2)
						Level.stage.stopKeeperInput()
						Audio.startEnding()

						await get_tree().create_timer(3.0).timeout
						GameWorld.handleGameWon({"prestigeScore": newScore})
						var popup = preload("res://content/gamemode/prestige/RunFinishedPopup.tscn").instantiate()
						popup.init(multiplayer.is_server())
						Level.stage.showEndingPanel(popup)
					else:
						Data.apply("team1.prestige.score", newScore)
						Data.apply("team1.prestige.multiplier", multiplier - 1)
				CONST.MODE_PRESTIGE_MINER:
					Data.apply("team1.prestige.score", newScore)
					if newValue == 20:
						Level.stage.stopKeeperInput()
						Audio.startEnding()

						await get_tree().create_timer(3.0).timeout
						GameWorld.handleGameWon({"prestigeScore": newScore})
						var popup = preload("res://content/gamemode/prestige/RunFinishedPopup.tscn").instantiate()
						popup.init(multiplayer.is_server())
						Level.stage.showEndingPanel(popup)
				_:
					Data.apply("team1.prestige.score", newScore)

		"team1.dome.health":
			if newValue <= 0 and not GameWorld.lost:
				Level.moveHudOut()
				GameWorld.lost = true
				Data.apply("team1.monsters.wavepresent", false)

				var delay = Level.stage.playGameLostAnimation()
				await get_tree().create_timer(delay).timeout
				Audio.sound("lose")
				await get_tree().create_timer(0.2).timeout
				GameWorld.handleGameLost({"prestigeScore": Data.of("team1.prestige.score")})

				Audio.startGameOver(1.0)
				await get_tree().create_timer(5.0).timeout

				var popup = preload("res://content/gamemode/prestige/RunFinishedPopup.tscn").instantiate()
				popup.init(multiplayer.is_server())
				Level.stage.showEndingPanel(popup)

func getRunWeight(teamId: String) -> float:
	match Level.loadout.modeConfig.get(CONST.MODE_CONFIG_PRESTIGE_VARIANT, ""):
		CONST.MODE_PRESTIGE_MINER:
			return 0.0

	var weight: = 0.0
	var cycle = Data.of("team1.monsters.cycle")

	weight += round(pow(2, ((cycle - (1 + Level.difficulty(teamId))) * 0.08)) * cycle * 10 + cycle * 10)
	weight += GameWorld.additionalRunWeight
	weight += Data.of("team1.prestige.provokedwavestrengthadditive")
	weight *= Data.of("team1.prestige.provokedwavestrength")
	weight *= Data.of("team1.monstermodifiers.totalrunweightmodifier")
	weight *= 1.0 + Level.difficulty(teamId) * 0.1
	weight *= Data.of(teamId + ".monsters.strengthmodfromplayercount")
	return max(15, weight)

static func get_enabled_mods_not_allowed_in_prestige() -> Array:
	var enabledIllegalMods: = []
	var ml = ModLoaderUserProfile.get_current().mod_list
	for modId in ml:
		if not ModLoaderStore.mod_data.has(modId):
			continue
		if not CONST.PRESTIGE_WHITELIST_MOD_IDS.has(modId) and ml[modId].is_active:
			enabledIllegalMods.append(modId)
	return enabledIllegalMods

func on_member_removed(member: Lobby.Member) -> void :
	if GameWorld.gameover or member.peer_id == 1:
		return
	if Level.loadout.getLoadoutKeepers().size() > 2:

		return
	SaveGame.saveRollingSavegame(true)
	Network.close_session("multiplayer.error.otherprestigeplayerquit")
