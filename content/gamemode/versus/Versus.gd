extends Node

func init():

	for teamId in ["team1", "team2"]:
		Data.listen(self, teamId + ".dome.health")
		Data.listen(self, teamId + ".inventory.relic")
		Data.listen(self, teamId + ".versus.ironcontribution")
		Data.listen(self, teamId + ".versus.disruptioncounter")

	if multiplayer.is_server():
		Lobby.member_removed.connect(on_member_removed, CONNECT_ONE_SHOT)

func afterInitialized():
	var wc = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_VERSUS_WINCONDITION, "")
	match wc:
		CONST.MODE_VERSUS_WINCONDITION_DEATHMATCH:
			pass
		CONST.MODE_VERSUS_WINCONDITION_IRONDELIVERY:
			var ironContributionPropertyChange: PropertyChange = _findIronContributionChange()
			var ironContributionRawVal: float = ironContributionPropertyChange.value
			for teamId in Level.teams:

				var costFactor = Data.ofOr(teamId + ".upgrademodifiers.cost.iron", 1.0)
				ironContributionPropertyChange.value = ironContributionRawVal * costFactor
				GameWorld.setUpgradeLimitAvailable(teamId + ".versus-iron")
				GameWorld.updateAvailableUpgrades(teamId)
			ironContributionPropertyChange.value = ironContributionRawVal
		_:
			Logger.error("unknown win condition '%s'" % wc)

func _findIronContributionChange() -> PropertyChange:
	if Data.upgrades.has("versussendiron"):
		var propertyChanges: Array = Data.upgrades["versussendiron"]["propertychanges"]
		for propertyChange in propertyChanges:
			if propertyChange.key == "versus.ironcontribution":
				return propertyChange
	return null

func propertyChanged(property: String, oldValue, newValue):
	if property.ends_with(".inventory.relic"):
		if not multiplayer.is_server():
			return

		if ( not oldValue and newValue > 0) or (oldValue != null and newValue > oldValue):
			var teamId = property.substr(0, 5)
			var playerId = Data.ofOr(teamId + ".lastreliccarrier.playerid", "")
			if playerId == "":
				Logger.error("Would like to open corruption popup for team '" + teamId + "', but cannot find a player id set for property '" + teamId + ".lastreliccarrier.playerid'.", "Versus.propertyChanged")
				return

			Level.stage.queueChoice(CONST.RELIC, teamId, playerId)
	elif property.ends_with(".dome.health"):
		var dead_team: = ""
		if newValue <= 0 and not GameWorld.won:
			dead_team = property.substr(0, 5)
		if dead_team != "":
			for mm in get_tree().get_nodes_in_group("monster-manager"):
				mm.disabled = true
			Level.stage.fadeOutTime = 2.5
			Data.unlisten(self, "team1.dome.health")
			Data.unlisten(self, "team2.dome.health")
			Audio.stopBattleMusic()
			Level.stage.stopKeeperInput()

			var t: = create_tween()
			t.tween_callback(Data.apply.bind("team1.monsters.wavepresent", false)).set_delay(5.0)
			t.tween_callback(Data.apply.bind("team2.monsters.wavepresent", false)).set_delay(5.0)

			Level.moveHudOut()
			GameWorld.handleGameWon()
			var delay = Level.stage.playGameLostAnimation()
			await get_tree().create_timer(delay).timeout
			Audio.startEnding()
			for m in get_tree().get_nodes_in_group("team1-monster"):
				m.onGameLost()
			for m in get_tree().get_nodes_in_group("team2-monster"):
				m.onGameLost()
			var dome = Level.domesByTeamId.get(dead_team)
			if dome:
				dome.onGameLost()
			for drone in get_tree().get_nodes_in_group(dead_team + "-transport_drones"):
				drone.onGameLost()
			for keeper in Keepers.getAllOfTeam(dead_team):
				keeper.onGameLost()

			await get_tree().create_timer(4.0).timeout

			var popup = preload("res://content/gamemode/versus/RunFinishedPopup.tscn").instantiate()
			popup.init(multiplayer.is_server(), dead_team)
			Level.stage.showEndingPanel(popup)
			GameWorld.gameover = true
	elif property.ends_with(".versus.ironcontribution"):
		var teamId: String = property.substr(0, 5)
		var ironFactor = Data.ofOr(teamId + ".upgrademodifiers.cost.iron", 1.0)
		if newValue >= CONST.VERSUS_IRONDELIVERY_WIN * ironFactor:
			Level.stage.fadeOutTime = 2.5
			Data.unlisten(self, "team1.dome.health")
			Data.unlisten(self, "team2.dome.health")
			Level.stage.stopKeeperInput()

			var t: = create_tween()
			t.tween_callback(Data.apply.bind("team1.monsters.wavepresent", false)).set_delay(5.0)
			t.tween_callback(Data.apply.bind("team2.monsters.wavepresent", false)).set_delay(5.0)

			Level.moveHudOut()
			GameWorld.handleGameWon()
			var delay = Level.stage.playGameLostAnimation()
			await get_tree().create_timer(delay).timeout
			Audio.startEnding()
			for m in get_tree().get_nodes_in_group("team1-monster"):
				m.onGameLost()
			for m in get_tree().get_nodes_in_group("team2-monster"):
				m.onGameLost()

			await get_tree().create_timer(4.0).timeout
			var other_team = other_team(property)
			var popup = preload("res://content/gamemode/versus/RunFinishedPopup.tscn").instantiate()
			popup.init(multiplayer.is_server(), other_team)
			Level.stage.showEndingPanel(popup)
			GameWorld.gameover = true
	elif property.ends_with(".versus.disruptioncounter"):
		if newValue > 0:
			var other_team = other_team(property)
			Data.event(other_team + ".versus.disruption")

func other_team(teamId: String) -> String:
	return "team" + str(3 - int(teamId.substr(4, 5)))

func getRunWeight(teamId: String) -> float:
	var weight: = 0.0
	var cycle = Data.of(teamId + ".monsters.cycle")
	var other_team = other_team(teamId)
	var additiveWaveStrength = Data.of(other_team + ".versus.additivewave")
	var multiplicativeWaveStrength = Data.of(other_team + ".versus.multiplicativeewave")

	var cycleWeight = round(pow(2, ((cycle - (1 + Level.difficulty(teamId))) * 0.06)) * cycle * 7 + cycle * 10)
	weight += Data.ofOr(teamId + ".monstermodifiers.additionalrunweight", 0)
	weight += additiveWaveStrength
	weight += cycleWeight * Data.of(teamId + ".monstermodifiers.cyclesrunweightmodifier")
	weight += GameWorld.additionalRunWeight
	weight *= Data.of(teamId + ".monstermodifiers.totalrunweightmodifier")
	weight *= 1.0 + multiplicativeWaveStrength
	weight *= 1.0 + Level.difficulty(teamId) * 0.1
	weight *= Data.of(teamId + ".monsters.strengthmodfromplayercount")
	return max(15, weight)

func on_member_removed(member: Lobby.Member) -> void :
	if GameWorld.gameover:
		return
	var team1Count: = 0
	var team2Count: = 0
	for m: Lobby.Member in Lobby.members:
		if member == m:
			continue

		match m.team_id:
			1:
				team1Count += 1
			2:
				team2Count += 1

	if team1Count == 0 or team2Count == 0:
		SaveGame.saveRollingSavegame(true)
		Network.network_team_empty_close.call_deferred()
