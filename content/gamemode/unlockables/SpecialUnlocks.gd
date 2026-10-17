extends Container

func _ready():
	if not GameWorld.won or GameWorld.buildType == CONST.BUILD_TYPE.EXHIBITION:
		visible = false
		return

	var newDifficulty: bool = false
	if Level.difficulty("team1") == 0 and Level.loadout.modeId == CONST.MODE_RELICHUNT:
		newDifficulty = GameWorld.unlockElement(CONST.DIFFICULTY_YAFI) != ""

	var newWorld: bool = false
	var nextWorld = GameWorld.nextUnlock(Level.loadout.worldId)
	var can_unlock_world = Level.loadout.modeId == CONST.MODE_RELICHUNT or Level.loadout.modeId == CONST.MODE_ASSIGNMENTS or Level.loadout.modeId == CONST.MODE_VERSUS
	if can_unlock_world and nextWorld and GameWorld.unlockElement(nextWorld) != "":
		newWorld = true
		var id = nextWorld.to_upper() + "_UNLOCK"
		Achievements.triggerIfOpen(id)

	var newMapSize: bool = false
	var nextMapSize = GameWorld.nextUnlock(Level.loadout.modeConfig.get(CONST.MODE_CONFIG_MAP_ARCHETYPE, ""))
	if nextMapSize and GameWorld.unlockElement(nextMapSize) != "" and Level.loadout.modeId == CONST.MODE_RELICHUNT:
		newMapSize = true

	var newPet: = false
	for p in get_tree().get_nodes_in_group("pets"):
		if not GameWorld.unlockedPets.has(p.id) and p.hatchedThisRun:
			GameWorld.unlockablePets.erase(p.id)
			GameWorld.unlockedPets.append(p.id)
			if newPet:
				var icon = $NewPetUnlockedPanel / MarginContainer / HBoxContainer / PetUnlockIcon.duplicate()
				$NewPetUnlockedPanel / MarginContainer / HBoxContainer / PetUnlockIcon.get_parent().add_child(icon)
				icon.texture = load("res://content/icons/loadout_" + p.id + ".png")
			else:
				$NewPetUnlockedPanel / MarginContainer / HBoxContainer / PetUnlockIcon.texture = load("res://content/icons/loadout_" + p.id + ".png")
			newPet = true

	var assignmentUnlocked: bool = not GameWorld.unlockedElements.has(CONST.MODE_ASSIGNMENTS)
	var versusUnlocked: = false
	if assignmentUnlocked:
		GameWorld.unlockElement(CONST.MODE_ASSIGNMENTS)
	elif not BuildCustomization.has_feature("disable_multi"):
		versusUnlocked = not GameWorld.unlockedElements.has(CONST.MODE_VERSUS)
		if versusUnlocked:
			GameWorld.unlockElement(CONST.MODE_VERSUS)

	var unlockAssessorSkin: = Keepers.local.getAll().any( func(keeper: Keeper): return keeper.techId == "keeper2")
	for id in ["KEEPER2_REFLECTIONS", "KEEPER2_SPHEREDURATION", "KEEPER2_BIGBUNDLE", "KEEPER2_SPLITS", "KEEPER2_EXPLODE", "KEEPER2_AMMO"]:
		if Achievements.isOpen(id):
			unlockAssessorSkin = false
			break
	if unlockAssessorSkin:
		GameWorld.newSkinsToUnlock.append({"keeperId": "keeper2", "skinId": "skin2"})

	for local_keeper in Keepers.local.getAll():
		if local_keeper.techId == "keeper4"\
		and Data.ofOr(local_keeper.playerId + ".keeper4.catgoblincount", 0) == 16:
			GameWorld.newSkinsToUnlock.append({"keeperId": "keeper4", "skinId": "skin1"})

	var newSkin: = false
	for entry in GameWorld.newSkinsToUnlock:

		if entry is String:
			continue
		var entryKeeperId: String = entry["keeperId"]
		var skin: String = entry["skinId"]
		if not GameWorld.unlockedSkins.get(entryKeeperId, []).has(skin):
			if newSkin:
				var icon = $SkinUnlockPanel / MarginContainer / HBoxContainer / SkinUnlockIcon.duplicate()
				$SkinUnlockPanel / MarginContainer / HBoxContainer / SkinUnlockIcon.get_parent().add_child(icon)
				icon.texture = load("res://content/icons/loadout_" + entryKeeperId + "-" + skin + ".png")
			else:
				$SkinUnlockPanel / MarginContainer / HBoxContainer / SkinUnlockIcon.texture = load("res://content/icons/loadout_" + entryKeeperId + "-" + skin + ".png")

			GameWorld.unlockSkin(entryKeeperId, skin)
			newSkin = true

	var newGadget: = false
	for teamId: String in Level.teams:
		for keeper in Keepers.getAllOfTeam(teamId):
			for gadgetId: String in Data.gadgets:
				var fullId: = Utils.get_full_upgrade_id(gadgetId, teamId, keeper.playerId)
				if GameWorld.upgrades.has(fullId) and GameWorld.upgrades[fullId].get("type", "") == "gadget" and not GameWorld.unlockedElements.has(gadgetId):
					if newGadget:
						var icon = $NewGadgetPanel / MarginContainer / HBoxContainer / GadgetUnlockIcon.duplicate()
						$NewGadgetPanel / MarginContainer / HBoxContainer / GadgetUnlockIcon.get_parent().add_child(icon)
						icon.texture = load("res://content/icons/" + gadgetId + ".png")
					else:
						$NewGadgetPanel / MarginContainer / HBoxContainer / GadgetUnlockIcon.texture = load("res://content/icons/" + gadgetId + ".png")
					newGadget = true
					GameWorld.unlockElement(gadgetId)

	var proMode = not Achievements.isOpen("PRESTIGE_WIN") and not GameWorld.isUnlocked(CONST.MODE_PRESTIGE_PRO)
	if proMode:
		GameWorld.unlockElement(CONST.MODE_PRESTIGE_PRO)

	find_child("NewDifficultyUnlockedPanel").visible = newDifficulty
	find_child("NewWorldUnlockedPanel").visible = newWorld
	find_child("NewMapSizeUnlockedPanel").visible = newMapSize
	find_child("NewPetUnlockedPanel").visible = newPet
	find_child("SkinUnlockPanel").visible = newSkin
	find_child("NewGadgetPanel").visible = newGadget
	find_child("AssignmentPanel").visible = assignmentUnlocked
	find_child("VersusPanel").visible = versusUnlocked
	find_child("ProModeUnlockPanel").visible = proMode

	var visiblePanels: = []
	if assignmentUnlocked:
		visiblePanels.append(find_child("AssignmentPanel"))
	if versusUnlocked:
		visiblePanels.append(find_child("VersusPanel"))
	if newDifficulty:
		visiblePanels.append(find_child("NewDifficultyUnlockedPanel"))
	if newPet:
		visiblePanels.append(find_child("NewPetUnlockedPanel"))
	if newWorld:
		visiblePanels.append(find_child("NewWorldUnlockedPanel"))
	if newMapSize:
		visiblePanels.append(find_child("NewMapSizeUnlockedPanel"))

	var possibleModifiers = GameWorld.runModifiersToUnlock.duplicate()
	if visiblePanels.size() <= 2 and Level.loadout.modeId == CONST.MODE_RELICHUNT:
		Data.RUN_MODIFIERS.shuffle()
		possibleModifiers.append_array(Data.RUN_MODIFIERS)
	var modifierUnlocked: = false
	for mod in possibleModifiers:
		if not GameWorld.unlockedRunModifiers.has(mod):
			GameWorld.unlockedRunModifiers.append(mod)
			visiblePanels.append(find_child("ModifiersUnlockedPanel"))
			modifierUnlocked = true
			break
	find_child("ModifiersUnlockedPanel").visible = modifierUnlocked

	if newSkin:
		visiblePanels.append(find_child("SkinUnlockPanel"))
	if proMode:
		visiblePanels.append(find_child("ProModeUnlockPanel"))
	if newGadget:
		visiblePanels.append(find_child("NewGadgetPanel"))

	SaveGame.saveRollingMetaState()

	var delay: = 1.0
	for panel in visiblePanels:
		delay += animateUpdate(panel, delay)

const medalScale: = 1.8
func animateUpdate(panel, delay: float) -> float:
	var duration1 = 0.5
	var duration2 = 0.15

	panel.scale = Vector2.ZERO
	panel.modulate.a = 0.0


	$Tween.interpolate_callback(panel, delay, "set", "modulate", Color.WHITE)
	panel.pivot_offset = panel.get_size() * 0.5



	$Tween.interpolate_property(panel, "scale", Vector2.ZERO, Vector2.ONE * medalScale, duration1, Tween.TRANS_CUBIC, Tween.EASE_OUT, delay)
	$Tween.interpolate_property(panel, "scale", Vector2.ONE * medalScale, Vector2.ONE, duration2, Tween.TRANS_CUBIC, Tween.EASE_IN, delay + duration1)
	$Tween.interpolate_callback(Audio, delay + duration1 + 0.0, "sound", "unlock_event")
	$Tween.start()

	return duration1 + duration2 + 0.4
