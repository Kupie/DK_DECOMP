extends Container

signal challengeModeSelected
signal playSound(isChallengeMode: bool)

var isChallengeMode: = false
var playerCount: = 1
var assignment: Assignment

func _ready():
	%DescriptionLabel.visible = false
	%GridContainer.visible = false
	%ButtonRegular.visible = false
	%ButtonChallenge.visible = false

	Style.init(self)

func setAssignment(id: String, isChallengeMode, playerCount):
	assignment = Data.assignments.get(id)
	if assignment == null:
		return

	self.isChallengeMode = isChallengeMode
	self.playerCount = playerCount

	%DescriptionLabel.visible = true
	%GridContainer.visible = true

	%TitleLabel.text = tr("assignment." + assignment.id + ".title")
	%DescriptionLabel.text = tr("assignment." + assignment.id + ".desc")
	if assignment.goalvalue is PropertyCheck and assignment.goalvalue.property_key.ends_with("contribution"):
		var resource = assignment.goalvalue.property_key.replace("assignments.", "").replace("contribution", "")
		%GoalLabel.text = tr("assignment.condition.deliver" + resource) % assignment.goalvalue.expected_value
	else:
		%GoalLabel.text = tr("assignment.goaltype." + assignment.goaltype)

	_update_condition_display()



func _get_multiplayer_modified_value(value, key: StringName):
	var result = value
	for propertyChange in assignment.multiplayerModifier:
		if propertyChange.key == key:
			for player in self.playerCount - 1:
				result = propertyChange.getChangedValue(result)
	return result

func _on_button_regular_select() -> void :
	playSound.emit(false)
	setChallengeMode(false)

func _on_button_challenge_select() -> void :
	playSound.emit(true)
	setChallengeMode(true)

func playRegularSound() -> void :
	$SfxChooseRegular.play()

func playChallengeSound() -> void :
	$SfxChooseChallenge.play()

func setPLayerCount(playerCount: int):
	self.playerCount = playerCount
	_update_condition_display()

func setChallengeMode(_isChallengeMode: bool) -> void :
	isChallengeMode = _isChallengeMode
	%ButtonRegular.selected = not _isChallengeMode
	%ButtonChallenge.selected = _isChallengeMode
	if multiplayer.is_server():
		Level.loadout.modeConfig[CONST.MODE_CONFIG_ASSIGNMENT_CHALLENGE_MODE] = _isChallengeMode
		setAssignment(assignment.id, isChallengeMode, playerCount)
		GameWorld.lastChosenAssignmentDifficulty[assignment.id] = int(_isChallengeMode)

	challengeModeSelected.emit()

func _update_condition_display():
	if not assignment:
		return

	var conditionStrings: = {}

	if assignment.freeGadgets > 0:
		var conditionKey = "assignment.condition.freegadget.plural" if assignment.freeGadgets > 1 else "assignment.condition.freegadget.singular"
		conditionStrings[conditionKey] = assignment.freeGadgets
	var changesToDisplay: = [assignment.propertyChanges]
	if isChallengeMode:
		changesToDisplay.append(assignment.challengePropertyChanges)

	for changeArray in changesToDisplay:
		for propertyChange: PropertyChange in changeArray:
			match propertyChange.key:
				"monsters.additionalwaveweight":
					var value = _get_multiplayer_modified_value(propertyChange.value, "monsters.additionalwaveweight")
					conditionStrings["properties.monsters.additionalstartweight"] = value
				"run.durationcycles":
					var value = _get_multiplayer_modified_value(propertyChange.value, "run.durationcycles")
					conditionStrings["assignment.condition.duration"] = value
				"game.fixedtimelimit":
					var value = _get_multiplayer_modified_value(propertyChange.value, "game.fixedtimelimit")
					conditionStrings["properties.game.fixedtimelimit"] = value
				"monstermodifiers.totalrunweightmodifier":
					var value = _get_multiplayer_modified_value(propertyChange.value, "monstermodifiers.totalrunweightmodifier")
					conditionStrings["properties.monstermodifiers.totalrunweightmodifier"] = value
				"monsters.waveinterval":
					var value = _get_multiplayer_modified_value(propertyChange.value, "monsters.waveinterval")
					conditionStrings["properties.monsters.waveinterval"] = value
				"monsters.fixedweight":
					var value = _get_multiplayer_modified_value(propertyChange.value, "monsters.fixedweight")
					conditionStrings["properties.monsters.fixedweight"] = value
				"monsters.finalwavefixedstrength":
					var value = _get_multiplayer_modified_value(propertyChange.value, "monsters.finalwavefixedstrength")
					conditionStrings["properties.monsters.finalwavefixedstrength"] = value
				"acidrain.fixeddamageperminute":
					var value = _get_multiplayer_modified_value(propertyChange.value, "acidrain.fixeddamageperminute")
					conditionStrings["properties.acidrain.fixeddamageperminute"] = value

	var txt = ""
	for key in conditionStrings:
		if txt != "":
			txt += "\n"
		var string = tr(key)
		if string.find("{") >= 0:
			if string.find("{.percent}") >= 0:
				txt += string.replace("{.percent}", str(conditionStrings[key] * 100) + "%")
			else:
				txt += string.replace("{}", str(conditionStrings[key]))
		elif string.find("%") >= 0:
			txt += string % conditionStrings[key]
		else:
			txt += string

	if txt == "":
		%Conditions.visible = false
	else:
		%Conditions.visible = true
		%ConditionValueLabel.text = txt

	%ButtonRegular.visible = true
	%ButtonChallenge.visible = true
	if isChallengeMode:
		%ButtonRegular.selected = false
		%ButtonChallenge.selected = true
	else:
		%ButtonRegular.selected = true
		%ButtonChallenge.selected = false
