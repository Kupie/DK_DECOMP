class_name Unlocks
extends Node

signal updated

var data: Dictionary = {}


var client_unlocks: Dictionary = {}

func clear() -> void :
	client_unlocks.clear()
	update()

func remove_peer(peer_id: int) -> void :
	client_unlocks.erase(peer_id)
	update()

func update() -> void :
	data["unlockedElements"] = GameWorld.unlockedElements
	data["unlockedPets"] = GameWorld.unlockedPets
	data["unlockedRunModifiers"] = GameWorld.unlockedRunModifiers
	data["unlockedSkins"] = GameWorld.unlockedSkins
	for additional in client_unlocks.values():
		data["unlockedElements"] = Utils.combined_set(data["unlockedElements"], additional["unlockedElements"])
		data["unlockedPets"] = Utils.combined_set(data["unlockedPets"], additional["unlockedPets"])
		data["unlockedRunModifiers"] = Utils.combined_set(data["unlockedRunModifiers"], additional["unlockedRunModifiers"])
		data["unlockedSkins"] = Utils.combined_skin_dict(data["unlockedSkins"], additional["unlockedSkins"])

	updated.emit()

func get_unlocked_pets() -> Array:
	return data["unlockedPets"]

func get_unlocked_run_modifiers() -> Array:
	return data["unlockedRunModifiers"]

func get_unlocked_skins() -> Dictionary:
	return data["unlockedSkins"]

func is_unlocked(id: String) -> bool:
	return data["unlockedElements"].has(id)

func get_reward_status(id: String) -> RewardChoice.RewardStatus:
	if multiplayer.is_server():
		return GameWorld.assignmentRewardStatus.get(id, RewardChoice.RewardStatus.LOCKED)
	else:
		if not data.has("assignmentRewardStatus"):

			return RewardChoice.RewardStatus.LOCKED
		return data["assignmentRewardStatus"].get(id, RewardChoice.RewardStatus.LOCKED)

func get_assignment_progress() -> int:
	if multiplayer.is_server():
		return GameWorld.getAssignmentProgress()
	else:
		return data["assignmentProgress"]

func get_assignment_progress_by_id(id: String) -> int:
	if multiplayer.is_server():
		return GameWorld.assignmentProgress.get(id, 0)
	else:
		return data["assignmentProgressById"].get(id, 0)

func calculate_available_badges() -> int:
	var badgeCount = GameWorld.getAssignmentProgress()
	var usedBadges: = 0
	for rewardId in GameWorld.assignmentRewardStatus:
		if GameWorld.assignmentRewardStatus[rewardId] > 0:
			usedBadges += int(Data.rewards.get(rewardId, {}).get("cost", 0))
	var availableBagdes = badgeCount - usedBadges
	return availableBagdes

func get_available_badges() -> int:
	if multiplayer.is_server():
		return calculate_available_badges()
	else:
		return data["availableBadges"]

func get_used_assignment_gadgets() -> Dictionary:
	if multiplayer.is_server():
		return GameWorld.usedAssigmentsGadgets
	else:
		return data["usedAssigmentsGadgets"]

func get_assignment_upgrade_limits() -> Array:
	if multiplayer.is_server():
		var assignmentId = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_ASSIGNMENT)
		var assignment = Data.assignments[assignmentId]
		return assignment.upgradeLimits
	else:
		return data.get("assignmentUpgradeLimits", 0)

func get_assignment_free_gadgets():
	if multiplayer.is_server():
		var assignmentId = Level.loadout.modeConfig.get(CONST.MODE_CONFIG_ASSIGNMENT)
		return Data.assignments.get(assignmentId).freeGadgets
	else:
		return data.get("assignmentFreeGadgets", 0)

func get_last_chosen_assignment_difficulty() -> Dictionary:
	if multiplayer.is_server():
		return GameWorld.lastChosenAssignmentDifficulty
	else:
		return data["lastChosenAssignmentDifficulty"]

func get_unlocked_assignments():
	if multiplayer.is_server():
		return GameWorld.unlockedAssignments
	else:
		return data["unlockedAssignments"]

func get_unlocked_rewards():
	if multiplayer.is_server():
		return GameWorld.unlockedRewards
	else:
		return data["unlockedRewards"]

func serialize() -> Dictionary:
	var serialized_data: = {}
	serialized_data["assignmentRewardStatus"] = GameWorld.assignmentRewardStatus
	serialized_data["assignmentProgress"] = GameWorld.getAssignmentProgress()
	serialized_data["assignmentProgressById"] = GameWorld.assignmentProgress
	serialized_data["unlockedElements"] = data["unlockedElements"]
	serialized_data["unlockedAssignments"] = GameWorld.unlockedAssignments
	serialized_data["unlockedRewards"] = GameWorld.unlockedRewards
	serialized_data["unlockedPets"] = data["unlockedPets"]
	serialized_data["unlockedRunModifiers"] = data["unlockedRunModifiers"]
	serialized_data["unlockedSkins"] = data["unlockedSkins"]
	serialized_data["availableBadges"] = calculate_available_badges()
	if Level.loadout.modeConfig.has(CONST.MODE_CONFIG_ASSIGNMENT):
		var assignmentId = Level.loadout.modeConfig[CONST.MODE_CONFIG_ASSIGNMENT]
		var assignment: Assignment = Data.assignments.get(assignmentId)
		serialized_data["assignmentFreeGadgets"] = assignment.freeGadgets
		serialized_data["assignmentUpgradeLimits"] = assignment.upgradeLimits
	serialized_data["usedAssigmentsGadgets"] = GameWorld.usedAssigmentsGadgets
	serialized_data["lastChosenAssignmentDifficulty"] = GameWorld.lastChosenAssignmentDifficulty
	return serialized_data

func deserialize(_data: Dictionary) -> void :
	data = _data
