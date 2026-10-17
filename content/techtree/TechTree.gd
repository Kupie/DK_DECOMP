class_name TechTree extends Control

signal techFocussed(techPanel)

var teamId: String
var playerId: String
var trackIds: = []

var focussedTechPanel
var rootsToIgnore: Array

func _ready() -> void :
	GameWorld.upgradeBought.connect(onUpgradeBought)
	GameWorld.upgradeError.connect(onUpgradeError)
	GameWorld.upgradeAdded.connect(onUpgradeAdded)

func _process(delta: float) -> void :
	var dirty: = false
	for track in $Tracks.get_children():
		dirty = dirty or track.dirty
		track.dirty = false
	if dirty:
		_on_Tracks_sort_children2()

func build(teamId: String, playerId: String, rootsToIgnore: Array):
	self.teamId = teamId
	self.playerId = playerId
	self.rootsToIgnore = rootsToIgnore

	calculateTracks()

	focussedTechPanel = null
	for t in trackIds:
		var track = preload("res://content/techtree/techtrack/TechTrack.tscn").instantiate()
		track.playerId = playerId
		track.build(t, self)
		$Tracks.add_child(track)

func calculateTracks():
	trackIds.clear()

	var upgrades: = {}
	var toErase: = []
	for key in Data.orderedUpgradeKeys.duplicate():
		var teamKey: String = teamId + "." + key
		var playerKey: String = playerId + "." + key
		if GameWorld.upgrades.has(teamKey):
			key = teamKey
		elif GameWorld.upgrades.has(playerKey):
			key = playerKey
		else:
			continue

		var upgrade: Dictionary = GameWorld.upgrades[key]
		if upgrade["tier"] == 0 and key in GameWorld.boughtUpgrades and not GameWorld.isUpgradeLimited(upgrade):
			if not rootsToIgnore.has(key):
				trackIds.append([[key]])
			toErase.append(key)
		upgrades[key] = upgrade

	for u in toErase:
		upgrades.erase(u)


	for track in trackIds:
		var removed: = 1
		var currentTier: = 1
		while removed > 0:
			removed = 0
			var newTechs: = []
			for u in upgrades:
				if not GameWorld.upgrades.has(u):
					continue
				if GameWorld.lockedUpgrades.has(u):
					continue

				var upgrade: Dictionary = upgrades[u]
				if GameWorld.isUpgradeLimited(upgrade):
					continue

				if upgrade["tier"] != track.size():
					continue

				var predecessors: Array = upgrade.get("predecessors")
				var missingPredecessorCount: = 1 if upgrade.get("predecessorsany", false) else predecessors.size()
				for predecessor in predecessors:
					if track[currentTier - 1].has(predecessor):
						missingPredecessorCount -= 1
				if missingPredecessorCount <= 0:
					newTechs.append(u)



			if newTechs.size() > 0:
				track.append(newTechs)
			for u in newTechs:
				upgrades.erase(u)
				removed += 1
			currentTier += 1


func focus():
	if not focussedTechPanel:
		focussedTechPanel = $Tracks.get_children().front().panelsByTier.front().front()
	InputSystem.grabFocus(focussedTechPanel)

func _on_Tracks_sort_children2():
	for track in $Tracks.get_children():
		track.updateLines()

	var tracks: Array = $Tracks.get_children()
	for i in range(0, tracks.size()):
		var track = tracks[i]


		for tier in track.panelsByTier:
			for j in range(1, tier.size()):
				tier[j].focus_neighbor_top = tier[j - 1].get_path()
				tier[j - 1].focus_neighbor_bottom = tier[j].get_path()

		if i > 0:

			var bottomSize = tracks[i - 1].bottomTechPanelsByTier.size() - 1
			for j in range(0, track.topTechPanelsByTier.size()):
				track.topTechPanelsByTier[j].focus_neighbor_top = tracks[i - 1].bottomTechPanelsByTier[min(j, bottomSize)].get_path()
		else:

			for j in range(0, track.topTechPanelsByTier.size()):
				track.topTechPanelsByTier[j].focus_neighbor_top = track.topTechPanelsByTier[j].get_path()

		if i < tracks.size() - 1:

			var topSize = tracks[i + 1].topTechPanelsByTier.size() - 1
			for j in range(0, track.bottomTechPanelsByTier.size()):
				track.bottomTechPanelsByTier[j].focus_neighbor_bottom = tracks[i + 1].topTechPanelsByTier[min(j, topSize)].get_path()
		else:

			for j in range(0, track.bottomTechPanelsByTier.size()):
				track.bottomTechPanelsByTier[j].focus_neighbor_bottom = track.bottomTechPanelsByTier[j].get_path()

		for techPanel in track.rightTechPanels:
			techPanel.focus_neighbor_right = techPanel.get_path()

var tempLeftNeighborOverrides: = {}
var tempRightNeighborOverrides: = {}
func technologyFocussed(techPanel):
	if focussedTechPanel and focussedTechPanel.track == techPanel.track:


		if techPanel.global_position.x < focussedTechPanel.global_position.x:
			if not tempRightNeighborOverrides.has(techPanel):
				tempRightNeighborOverrides[techPanel] = techPanel.focus_neighbor_right
			techPanel.focus_neighbor_right = focussedTechPanel.get_path()
		elif tempRightNeighborOverrides.has(techPanel):
			techPanel.focus_neighbor_right = tempRightNeighborOverrides[techPanel]
			tempRightNeighborOverrides.erase(techPanel)



		if techPanel.global_position.x > focussedTechPanel.global_position.x:
			if GameWorld.upgrades.get(techPanel.techId, {}).get("predecessors", []).has(focussedTechPanel.techId):
				if not tempLeftNeighborOverrides.has(techPanel):
					tempLeftNeighborOverrides[techPanel] = techPanel.focus_neighbor_left
				techPanel.focus_neighbor_left = focussedTechPanel.get_path()
		elif tempLeftNeighborOverrides.has(techPanel):
			techPanel.focus_neighbor_left = tempLeftNeighborOverrides[techPanel]
			tempLeftNeighborOverrides.erase(techPanel)

	if focussedTechPanel != techPanel:
		techPanel.focusCounter = 0
	focussedTechPanel = techPanel

	var scrollX = techPanel.global_position.x + get_parent().scroll_horizontal - get_parent().global_position.x - get_parent().size.x * 0.5 + techPanel.size.x * 0.5
	var scrollY = techPanel.track.global_position.y - get_parent().size.y * 0.5 + techPanel.track.size.y * 0.5 + get_parent().scroll_vertical - get_parent().global_position.y
	if abs(get_parent().scroll_horizontal - scrollX) > 30:
		$Tween.interpolate_property(get_parent(), "scroll_horizontal", get_parent().scroll_horizontal, scrollX, 0.2, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	if abs(get_parent().scroll_vertical - scrollY) > 30:
		$Tween.interpolate_property(get_parent(), "scroll_vertical", get_parent().scroll_vertical, scrollY, 0.2, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	$Tween.start()
	emit_signal("techFocussed", techPanel)

func techUnfocussed(techPanel):
	pass




func techInput(event, techPanel):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if techPanel == focussedTechPanel:
			techPanel.focusCounter += 1
			if techPanel.focusCounter > 1:
				buyCurrentUpgrade()


		pass

func buyCurrentUpgrade():
	if focussedTechPanel and focussedTechPanel.state == 1:
		GameWorld.buyUpgrade(focussedTechPanel.techId, teamId, playerId)

func onUpgradeBought(id: String, teamId: String, _playerId: String) -> void :
	if self.teamId != teamId:
		return

	if focussedTechPanel and focussedTechPanel.techId == id:
		focussedTechPanel.upgrade()
		emit_signal("techFocussed", focussedTechPanel)

		var upgrade = GameWorld.upgrades.get(id)
		var shouldPlayMax = upgrade.get("tier", 0) >= 3 and upgrade.get("successors", []).is_empty()
		if upgrade.has("repeatable"):
			for propertyChange in upgrade.get("repeatable"):
				if propertyChange.keyClass == "times" and propertyChange.value == 0:
					shouldPlayMax = true
		if shouldPlayMax:
			Audio.sound("tech_maxed")
		else:
			Audio.sound("upgrade")

func onUpgradeAdded(id: String, teamId: String) -> void :
	if self.teamId != teamId:
		return

	var track: TechTrack
	for techTrack: TechTrack in $Tracks.get_children():
		for techPanel: TechPanel in techTrack.techPanels.values():
			if techPanel.techId == id:
				track = techPanel.track
				break
	if not is_instance_valid(track):


		return
	var upgrade = GameWorld.upgrades.get(id)
	if upgrade.get("rebuildtechtree", false):

		var focused_track: TechTrack
		if is_instance_valid(focussedTechPanel):
			focused_track = focussedTechPanel.track

		calculateTracks()

		var upgrades_of_track: Array
		for t in trackIds:
			if t[0][0] == track.rootTechId:
				upgrades_of_track = t
				break

		track.build(upgrades_of_track, self)

		if is_instance_valid(focused_track):
			focussedTechPanel = focused_track.techPanels[focused_track.rootTechId]

	else:
		track.updateState()
		track.updateLineColors()
		track.updateLines()

func onUpgradeError(id: String, teamId: String, playerId: String) -> void :
	if self.teamId != teamId or self.playerId != playerId:
		return

	focussedTechPanel.error()

func _on_Tracks_resized() -> void :
	pass
