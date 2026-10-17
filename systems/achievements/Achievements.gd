extends Node

var achievements: = {}

func isOpen(id: String):
	var state: int
	if achievements.has(id):
		state = achievements[id]
	else:
		var achievement: Dictionary = Platform.getAchievement(id)
		if not achievement.get("ret", false):
			state = -1
		elif achievement.get("achieved", false) == false:
			state = 0
		else:
			state = 1
		achievements[id] = state

	return state == 0

func triggerIfOpen(id: String, teamOrPlayerId: = ""):
	if not checkIsLocal(teamOrPlayerId):
		return

	if isOpen(id):
		Logger.info("Achievement " + id + " triggered.")
		Platform.unlockAchievement(id)
		Platform.storeStats()
		achievements[id] = 1

func checkIsLocal(teamOrPlayerId) -> bool:

	if teamOrPlayerId != "":
		if teamOrPlayerId.contains("player"):
			var isLocal: = false
			for member in Lobby.members:
				if member.peer_id != multiplayer.get_unique_id():
					continue
				if member.player_id == Utils.encode_player_id(teamOrPlayerId):
					isLocal = true
					break
			if not isLocal:
				return false
		else:
			var localTeamId: = Utils.get_local_team_id(multiplayer.get_unique_id())
			if localTeamId != "mixed" and teamOrPlayerId != localTeamId:
				return false
	return true

func addIfOpen(parent, id: String, teamOrPlayerId: = ""):
	if not checkIsLocal(teamOrPlayerId):
		return

	if isOpen(id):
		add(parent, id)

func clearCache():
	achievements.clear()

func add(parent, id: String):

	if Level.stage is MultiplayerLoadoutStage or Level.stage is DeviceSelectionStage:
		return

	var a = load("res://content/achievements/Achievement_" + id + ".tscn")
	if a:
		var ac = a.instantiate()
		ac.id = id
		ac.name = "ACHIEVEMENT_" + id

		parent.add_child(ac)
	else:
		Logger.error("achievement scene does not exist", "Achievements.addIfOpen", id)

func reactOnUnlock(unlock: String):
	match unlock:
		"shield-battle3":
			triggerIfOpen("SHIELD_COMPLETE")
		"repellent-battle3":
			triggerIfOpen("REPELLENT_COMPLETE")
		"orchard-battle2":
			triggerIfOpen("ORCHARD_COMPLETE")
		_:
			triggerIfOpen(unlock.to_upper() + "_UNLOCK")

func incrementStat(id: String):
	var val = Platform.getStat(id) + 1
	Platform.setStat(id, val)
	if val >= 10:
		if id == "run_wins" and isOpen("RUN_WINMANY"):
			Platform.unlockAchievement("RUN_WINMANY")
		elif id == "run_losses" and isOpen("RUN_LOSEMANY"):
			Platform.unlockAchievement("RUN_LOSEMANY")
	Platform.storeStats()

func checkAchievementsAndUnlocks():
	if not isOpen("PRESTIGE_WIN"):
		GameWorld.unlockElement(CONST.MODE_PRESTIGE_PRO)

	if GameWorld.isUnlocked("world2"):
		triggerIfOpen("WORLD2_UNLOCK")
	if GameWorld.isUnlocked("world3"):
		triggerIfOpen("WORLD3_UNLOCK")
	if GameWorld.isUnlocked("world4"):
		triggerIfOpen("WORLD4_UNLOCK")
	if GameWorld.isUnlocked("world5"):
		triggerIfOpen("WORLD5_UNLOCK")

	if GameWorld.isUnlocked("dome2"):
		triggerIfOpen("DOME2_UNLOCK")
	if GameWorld.isUnlocked(CONST.MODE_PRESTIGE):
		triggerIfOpen("PRESTIGE_UNLOCK")
	if GameWorld.isUnlocked("keeper2"):
		triggerIfOpen("KEEPER2_UNLOCK")
	if GameWorld.isUnlocked("shield-battle3"):
		triggerIfOpen("SHIELD_COMPLETE")
	if GameWorld.isUnlocked("repellent-battle3"):
		triggerIfOpen("REPELLENT_COMPLETE")
	if GameWorld.isUnlocked("orchard-battle2"):
		triggerIfOpen("ORCHARD_COMPLETE")

	var unlockAssessorSkin: = true
	for id in ["KEEPER2_REFLECTIONS", "KEEPER2_SPHEREDURATION", "KEEPER2_BIGBUNDLE", "KEEPER2_SPLITS", "KEEPER2_EXPLODE", "KEEPER2_AMMO"]:
		if Achievements.isOpen(id):
			unlockAssessorSkin = false
			break
	if unlockAssessorSkin:
		GameWorld.unlockSkin("keeper2", "skin2")
