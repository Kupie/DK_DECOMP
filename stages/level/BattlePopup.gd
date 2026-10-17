extends Container

var isIn: = false
var outLeft: = false
var outRight: = false


var tween2: DeprecatedTween

var primaryWeaponId: String
var teamId: String
var deviceId: int

func init(domeId: String, teamId: String, deviceId: int):
	%ActionSpecial.domeId = domeId
	%ActionShoot.domeId = domeId
	primaryWeaponId = Level.domesByTeamId[teamId].primaryWeapon
	self.teamId = teamId

func _ready():
	onInputMethodChanged()

	tween2 = DeprecatedTween.new()
	add_child(tween2)

	match primaryWeaponId:
		"laser":
			find_child("ActionWeaponMoveUp").visible = false
			find_child("ActionWeaponMoveDown").visible = false
		"sword":
			find_child("ActionWeaponMoveUp").visible = false
			find_child("ActionWeaponMoveDown").visible = false
		"artillery":
			find_child("ActionWeaponMoveUp").visible = false
			find_child("ActionWeaponMoveDown").visible = false
		"tesla":
			find_child("ActionWeaponMoveUp").visible = true
			find_child("ActionWeaponMoveDown").visible = true
		_:
			find_child("ActionWeaponMoveLeft").visible = false
			find_child("ActionWeaponMoveRight").visible = false

	find_child("LeftRightLabel").text = "level.station.battle.navbar.move"

	Style.init(self)

func moveIn(delay: = false):
	if isIn:
		return

	var b1 = get_tree().get_nodes_in_group(teamId + "-dome_ability1")
	var bc1 = find_child("Battle1Container")
	if b1.size() > 0:
		var abilityName = b1.front().getBattleAbilityName()
		if abilityName == "":
			bc1.visible = false
		else:
			bc1.get_node("Label").text = abilityName
			bc1.visible = true
	else:
		bc1.visible = false

	var b2 = get_tree().get_nodes_in_group(teamId + "-dome_ability2")
	var bc2 = find_child("Battle2Container")
	if b2.size() > 0:
		var abilityName = b2.front().getBattleAbilityName()
		if abilityName == "":
			bc2.visible = false
		else:
			bc2.get_node("Label").text = abilityName
			bc2.visible = true
	else:
		bc2.visible = false

	var primaries = get_tree().get_nodes_in_group(teamId + "-primaryweapon")
	var fc = find_child("HBoxContainer2")
	var sc = find_child("SpecialContainer")
	if primaries.size() > 0:
		var fireName = primaries.front().getFireName()
		if fireName == "":

			fc.visible = false
		else:
			fc.get_node("UpLabel").text = fireName
			fc.visible = true

		var specialName = primaries.front().getSpecialName()
		if specialName == "":
			sc.visible = false
		else:
			sc.get_node("SpecialLabel").text = specialName
			sc.visible = true
	else:
		fc.visible = false
		sc.visible = false

	var visible_count: = 0
	for container in $PanelContainer / HintContainers.get_children():
		if container.visible:
			visible_count += 1
	var i: = 0

	for container in $PanelContainer / HintContainers.get_children():
		i += 1
		if container.visible and (i % visible_count == 0 or i % $PanelContainer / HintContainers.columns == 0):
			var sep = container.find_child("VSeparator")
			if sep:
				sep.visible = false

	position.x = - size.x
	position.y = get_parent().size.y - size.y

	isIn = true
	tween2.stop_all()
	tween2.remove_all()
	var s = get_parent().size
	$Tween.interpolate_property(self, "position", position, Vector2(s.x * anchor_left - size.x * 0.5, s.y - size.y), 0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0.3 if delay else 0.0)
	$Tween.start()

func moveOut(dir: = 0):
	if not isIn:
		return

	isIn = false
	$Tween.stop_all()
	$Tween.remove_all()
	var s = get_parent().size
	if dir == 0:
		tween2.interpolate_property(self, "position:y", position.y, s.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	elif dir == -1:
		tween2.interpolate_property(self, "position:x", position.x, - size.x, 0.45, Tween.TRANS_CUBIC, Tween.EASE_IN)
	elif dir == 1:
		tween2.interpolate_property(self, "position:x", position.x, s.x, 0.45, Tween.TRANS_CUBIC, Tween.EASE_IN)
	tween2.interpolate_callback(self, 0.5, "queue_free")
	tween2.start()

func onInputMethodChanged():
	find_child("MoveContainer").visible = not Options.useMouseDomeGameplay or Options.useGamepad(deviceId)

func showExitHints():
	find_child("ExitContainer").visible = true
