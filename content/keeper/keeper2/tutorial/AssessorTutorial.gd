extends "res://content/shared/VideoTutorial.gd"

func _ready():
	super._ready()
	updateTexts()

func onInputMethodChanged():
	updateTexts()

func updateTexts():
	var assessor_keeper = Keepers.local.getAll().filter( func(keeper): return keeper is Keeper2).front()
	var use_mouse_or_twinstick: = true
	var is_mouse = assessor_keeper.deviceId == 0 or not Options.singleplayerUseGamepad
	var keeper2_input = Options.getInputSettingsForKeeper(assessor_keeper, is_mouse)
	if is_mouse:
		use_mouse_or_twinstick = keeper2_input.use_mouse
	else:
		use_mouse_or_twinstick = keeper2_input.use_twinstick
	if use_mouse_or_twinstick:
		var control_option = "options.input.controls.mouse" if is_mouse else "options.input.gamepad.thumbstick"
		var text = tr("level.tutorial.assessor.spheres.desc1.aiming") % tr(control_option)
		splitTutorialText(text, "LabelDesc1_1", "LabelDesc1_2")
	else:
		splitTutorialText("level.tutorial.assessor.spheres.desc1", "LabelDesc1_1", "LabelDesc1_2")
	splitTutorialText("level.tutorial.assessor.carry.desc1", "LabelDesc3_1", "LabelDesc3_2")
	splitTutorialText("level.tutorial.assessor.carry.desc2", "LabelDesc4_1", "LabelDesc4_2")
