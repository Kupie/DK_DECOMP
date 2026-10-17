extends "res://content/shared/VideoTutorial.gd"

func _ready():
	super._ready()
	updateTexts()
	var is_pc = OS.has_feature("pc")
	%LabelDesc5.visible = is_pc

func onInputMethodChanged():
	updateTexts()

func updateTexts():
	var ninja_keeper = Keepers.local.getAll().filter( func(keeper): return keeper is Keeper3).front()
	var is_mouse = ninja_keeper.deviceId == 0 or not Options.singleplayerUseGamepad
	var control_option = "options.input.controls.mouse" if is_mouse else "options.input.gamepad.thumbstick"

	splitTutorialText(tr("level.tutorial.ninja.bombs.desc1") % tr(control_option), "LabelDesc1_1", "LabelDesc1_2")
	splitTutorialText(tr("level.tutorial.ninja.rope.desc1") % tr(control_option), "LabelDesc2_1", "LabelDesc2_2")
	splitTutorialText("level.tutorial.ninja.rope.desc2", "LabelDesc2_3", "LabelDesc2_4")
	splitTutorialText(tr("level.tutorial.ninja.carry.desc1") % tr(control_option), "LabelDesc3_1", "LabelDesc3_2")
