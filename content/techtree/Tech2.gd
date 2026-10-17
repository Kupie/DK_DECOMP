class_name TechPanel
extends TextureRect


signal local_gui_input


enum State{UNAVAILABLE, AVAILABLE, BOUGHT, LOCKED, INITIAL}

const RECT_SCALE_ON_HOVER: = 1.3

var state: int = -1
var teamId: String
var playerId: String
var techId: String
var visualTechId: String
var title: String
var propertyChanges: Array
var icon: Texture2D
var explanationBb: String
var original_position
var costLabels: = {}


var focusCounter: = 0

const colorUnavailable: = Color(200.0 / 255.0, 0, 220.0 / 256.0)
const colorAvailable: = Color(216.0 / 255.0, 0, 220.0 / 256.0)



var track

func build(id: String, tier: = -1):
	self.techId = id
	var data = GameWorld.upgrades.get(id)
	visualTechId = data.get("shadowing", techId)
	var descKey = data.get("shadowing-desc", visualTechId)
	var dotLoc = visualTechId.find(".")
	if dotLoc != -1:
		visualTechId = visualTechId.substr(dotLoc + 1)
	dotLoc = descKey.find(".")
	if dotLoc != -1:
		descKey = descKey.substr(dotLoc + 1)

	if tier == 1:
		state = State.INITIAL
		$Icon.custom_minimum_size = Vector2.ONE * 144
		texture = preload("res://content/techtree/panels/big.png")
		$SelectedPanel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		$SelectedPanel.texture = preload("res://content/techtree/panels/big_focus.png")
	$SelectedPanel.visible = false
	if data.has("cost"):
		var cost = data.get("cost")
		var costsBox = find_child("Costs")
		for costType in cost:
			var label = Label.new()
			label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
			label.size_flags_horizontal = label.SIZE_EXPAND_FILL
			label.text = str(cost[costType])
			label.label_settings = preload("res://gui/fontsettings/NumbersFontSettings.tres")
			costsBox.add_child(label)
			costLabels[costType] = label

			var rect = TextureRect.new()
			rect.stretch_mode = TextureRect.STRETCH_KEEP
			var tex: Texture2D
			match costType:
				CONST.WATER:
					tex = preload("res://content/icons/icon_water.png")
				CONST.IRON:
					tex = preload("res://content/icons/icon_iron.png")
				CONST.SAND:
					tex = preload("res://content/icons/icon_sand.png")
			rect.texture = tex
			costsBox.add_child(rect)

	propertyChanges = data.get("propertychanges", [])
	if data.has("overwriteTitleKey"):
		title = tr(data.get("overwriteTitleKey"))
	else:
		title = tr("upgrades." + visualTechId + ".title")
	if data.has("overwriteDescKey"):
		explanationBb = tr(data.get("overwriteDescKey"))
	else:
		explanationBb = GameWorld.iconify(tr("upgrades." + descKey + ".desc"))

	updateState()

	icon = Data.loadIconOrFallback("res://content/icons/" + visualTechId + ".png")
	find_child("Icon").texture = icon

	_on_Tech_focus_exited()






func _ready():


	if state == State.INITIAL:
		$Icon.position = Vector2(-4, -4)


func _gui_input(event: InputEvent) -> void :
	local_gui_input.emit(event)


func showLockGroup():
	$lockIcon.show()
	$AnimationPlayer.play("afraid")
	$Icon.hide()
	if texture == preload("res://content/techtree/panels/two_bright.png"):
		texture = preload("res://content/techtree/panels/two_dark.png")
	elif texture == preload("res://content/techtree/panels/one_bright.png"):
		texture = preload("res://content/techtree/panels/one_dark.png")

func hideLockGroup():
	$Icon.show()
	$lockIcon.hide()
	$AnimationPlayer.play("calm")
	updateState()

func _on_Tech_focus_entered():
	Audio.sound("tech_hover")
	var start: Vector2 = Vector2(1, 1)
	var end: Vector2 = Vector2(RECT_SCALE_ON_HOVER, RECT_SCALE_ON_HOVER)
	$Tween.interpolate_property(self, "scale", start, end, 0.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	$Tween.start()
	$SelectedPanel.visible = true

	var repair: = 0
	for propertyChange in propertyChanges:
		if propertyChange.doesRepair:


			if propertyChange.key.contains("dome.baserepair"):
				repair += propertyChange.value
			elif propertyChange.key.contains("dome.healthfractionrepair"):
				repair += propertyChange.value * Data.of(teamId + ".dome.maxhealth")
	Data.localEvent(playerId + ".dome.potentialrepair", 0, repair)

func _on_Tech_focus_exited():
	Audio.ignoreNextHover()
	$Tween.stop(self)
	scale = Vector2.ONE
	$SelectedPanel.visible = false

func upgrade():
	$Tween.remove_all()
	$IconUnlock.texture = $Icon.texture
	$IconUnlock.size = $Icon.custom_minimum_size
	$IconUnlock.position = $Icon.position
	$IconUnlock.show()
	$Tween.interpolate_property($IconUnlock, "modulate:a", 1.0, 0.0, 2.3, Tween.TRANS_EXPO, Tween.EASE_OUT)
	$Tween.interpolate_property($IconUnlock, "scale", Vector2.ONE, Vector2.ONE * 3.5, 2.3, Tween.TRANS_EXPO, Tween.EASE_OUT)
	$Tween.start()

func error():
	Audio.sound("gui_err")
	if original_position == null:
		original_position = position
	var start: Vector2 = position + Vector2(-8, 0)
	var end: Vector2 = original_position
	$Tween.interpolate_property(self, "position", start, end, 0.5, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
	$Tween.start()

func hasMultiplePredecessorLock() -> bool:
	return $AnyAll.visible

func updateState():
	var tech = GameWorld.upgrades.get(techId)
	var isRepeatable: bool
	var repeatableTimes: = -1
	if tech.has("repeatable"):
		var repdata = tech.get("repeatable")
		for change in repdata:
			if change.keyClass == "times":
				repeatableTimes = change.value
		isRepeatable = repeatableTimes != 0
		$RepetitionCountLabel.text = str(repeatableTimes)
	else:
		isRepeatable = false
	$RepetitionCountLabel.visible = repeatableTimes > 0

	$AnyAll.hide()

	var cost = tech.get("cost", [])
	for costType in cost:
		if costLabels.has(costType):
			costLabels[costType].text = str(cost[costType])

	var upgradeBought: = false
	if GameWorld.boughtUpgrades.has(techId):
		upgradeBought = true
	elif tech.get("type", "") == "supplement":
		var base_id: = techId.substr(techId.find(".") + 1)
		for keeper: LoadoutKeeper in Level.loadout.keeperTemplates:
			var player_prefixed_id: = keeper.playerId + "." + base_id
			if GameWorld.boughtUpgrades.has(player_prefixed_id):
				upgradeBought = true
				break

	if state != State.INITIAL:
		state = State.UNAVAILABLE
		if GameWorld.lockedUpgrades.has(techId):
			state = State.LOCKED
		elif (upgradeBought and not isRepeatable) or Data.gadgets.has(techId):
			state = State.BOUGHT
		else:
			if GameWorld.upgrades.has(techId):
				var unlocked = GameWorld.isUpgradeAddable(techId)
				if unlocked:
					state = State.AVAILABLE
				else:
					state = State.UNAVAILABLE

		if not has_focus():
			_on_Tech_focus_exited()

		var open = state == State.UNAVAILABLE or state == State.AVAILABLE
		find_child("Costs").visible = open
		var costsAmount = GameWorld.upgrades[techId].get("cost", []).size()
		var isSupplement = Data.supplements.has(techId)
		if techId.count(".") == 1:
			isSupplement = isSupplement or Data.supplements.has(techId.substr(techId.find(".") + 1))
		match state:
			State.UNAVAILABLE:
				if costsAmount == 1:
					if isRepeatable:
						if repeatableTimes != -1:
							$RepetitionCountLabel.position.y = 81
							texture = preload("res://content/techtree/panels/one_reload_extra_dark.png")
						else:
							texture = preload("res://content/techtree/panels/one_reload_dark.png")
					else:
						texture = preload("res://content/techtree/panels/one_dark.png")

					if $AnyAll.visible:
						$AnyAll.texture = preload("res://content/techtree/panels/lock_dark.png")
					$SelectedPanel.texture = preload("res://content/techtree/panels/one_focus.png")
				else:
					if isRepeatable:
						if repeatableTimes != -1:
							$RepetitionCountLabel.position.y = 85
							texture = preload("res://content/techtree/panels/two_reload_extra_dark.png")
						else:
							texture = preload("res://content/techtree/panels/two_reload_dark.png")
					else:
						texture = preload("res://content/techtree/panels/two_dark.png")
					if $AnyAll.visible:
						$AnyAll.texture = preload("res://content/techtree/panels/lock_dark.png")
					$SelectedPanel.texture = preload("res://content/techtree/panels/two_focus.png")
			State.AVAILABLE:
				if costsAmount == 1:
					if isRepeatable:
						if repeatableTimes != -1:
							$RepetitionCountLabel.position.y = 81
							texture = preload("res://content/techtree/panels/one_reload_extra_bright.png")
						else:
							texture = preload("res://content/techtree/panels/one_reload_bright.png")
					else:
						texture = preload("res://content/techtree/panels/one_bright.png")
					if $AnyAll.visible:
						$AnyAll.texture = preload("res://content/techtree/panels/lock_bright.png")
					$SelectedPanel.texture = preload("res://content/techtree/panels/one_focus.png")
				else:
					if isRepeatable:
						if repeatableTimes != -1:
							$RepetitionCountLabel.position.y = 85
							texture = preload("res://content/techtree/panels/two_reload_extra_bright.png")
						else:
							texture = preload("res://content/techtree/panels/two_reload_bright.png")
					else:
						texture = preload("res://content/techtree/panels/two_bright.png")
					if $AnyAll.visible:
						$AnyAll.texture = preload("res://content/techtree/panels/lock_bright.png")
					$SelectedPanel.texture = preload("res://content/techtree/panels/two_focus.png")
			State.BOUGHT:
				if isSupplement:
					texture = preload("res://content/techtree/panels/square_bright.png")
					$SelectedPanel.texture = preload("res://content/techtree/panels/square_focus.png")
				else:
					texture = preload("res://content/techtree/panels/zero_bright.png")
					if $AnyAll.visible:
						$AnyAll.texture = preload("res://content/techtree/panels/lock_bright.png")
					$SelectedPanel.texture = preload("res://content/techtree/panels/zero_focus.png")
			State.LOCKED:
				if isSupplement:
					texture = preload("res://content/techtree/panels/square_dark.png")
					$SelectedPanel.texture = preload("res://content/techtree/panels/square_focus.png")
				else:
					texture = preload("res://content/techtree/panels/zero_dark.png")
					if $AnyAll.visible:
						$AnyAll.texture = preload("res://content/techtree/panels/lock_dark.png")
					$SelectedPanel.texture = preload("res://content/techtree/panels/zero_focus.png")

	pivot_offset = texture.get_size() * 0.5

func isLocked() -> bool:
	return state == State.LOCKED

func setAnalytics(count):
	$lockIcon.visible = false
	var costsBox = find_child("Costs")
	for c in costsBox.get_children():
		c.queue_free()

	var label = Label.new()
	label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
	label.size_flags_horizontal = label.SIZE_EXPAND_FILL
	label.text = str(count)
	label.add_to_group("unstyled")
	costsBox.add_child(label)

func _on_Tech_mouse_entered():

	InputSystem.grabFocus(self)
