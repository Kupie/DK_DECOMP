extends Control

signal close

func _ready():
	InputSystem.grabFocus(find_child("ButtonApply"))
	Style.init(self)

	if Options.adaptiveOst:
		find_child("ButtonAdaptive").button_pressed = true
		find_child("CheckKeeper1").disabled = true
		find_child("CheckKeeper2").disabled = true
		find_child("CheckKeeper3").disabled = true
		find_child("CheckKeeper4").disabled = true
	else:
		find_child("ButtonFixed").button_pressed = true
		find_child("CheckKeeper1").disabled = false
		find_child("CheckKeeper2").disabled = false
		find_child("CheckKeeper3").disabled = false
		find_child("CheckKeeper4").disabled = false

	var keeper_buttons = {}
	keeper_buttons["keeper1"] = find_child("CheckKeeper1")
	keeper_buttons["keeper2"] = find_child("CheckKeeper2")
	keeper_buttons["keeper3"] = find_child("CheckKeeper3")
	keeper_buttons["keeper4"] = find_child("CheckKeeper4")

	for keeper_id in keeper_buttons:
		keeper_buttons[keeper_id].disabled = Options.adaptiveOst
		if not GameWorld.isUnlocked(keeper_id):
			Options.fixedOstTracks.erase(keeper_id)
			keeper_buttons[keeper_id].disabled = true
		keeper_buttons[keeper_id].button_pressed = Options.fixedOstTracks.has(keeper_id)

func sound():
	Audio.sound("gui_select")

func _on_ButtonAdaptive_pressed():
	sound()
	find_child("CheckKeeper1").disabled = true
	find_child("CheckKeeper2").disabled = true
	find_child("CheckKeeper3").disabled = true
	find_child("CheckKeeper4").disabled = true

func _on_ButtonFixed_pressed():
	sound()
	find_child("CheckKeeper1").disabled = false
	find_child("CheckKeeper2").disabled = false
	find_child("CheckKeeper3").disabled = false
	find_child("CheckKeeper4").disabled = false

func _on_ButtonApply_pressed():
	Audio.sound("gui_apply")
	Options.adaptiveOst = find_child("ButtonAdaptive").button_pressed
	Options.fixedOstTracks.clear()
	if find_child("CheckKeeper1").button_pressed:
		Options.fixedOstTracks.append("keeper1")
	if find_child("CheckKeeper2").button_pressed:
		Options.fixedOstTracks.append("keeper2")
	if find_child("CheckKeeper3").button_pressed:
		Options.fixedOstTracks.append("keeper3")
	if find_child("CheckKeeper4").button_pressed:
		Options.fixedOstTracks.append("keeper4")
	if Options.fixedOstTracks.size() == 0:
		Options.fixedOstTracks.append("keeper1")
		Options.fixedOstTracks.append("keeper2")
		Options.fixedOstTracks.append("keeper3")
		Options.fixedOstTracks.append("keeper4")
	Options.saveOptions()
	Audio.updateTrackList()
	if Level.stage is LevelStage:
		Audio.fadeMusic(GameWorld.currentMusicIndex)
	else:
		Audio.fadeIntro()
	emit_signal("close")

func _on_CancelButton_pressed():
	Audio.sound("gui_cancel")
