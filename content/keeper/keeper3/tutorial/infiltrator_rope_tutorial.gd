extends Tutorial

func _ready():
	super._ready()
	updateTexts()

func process_trigger(delta: float) -> bool:
	return keeper.position.y > 200 or abs(keeper.position.x) > 170

func process_confirm(delta: float):
	if not tutorialParent.cooldownManager.is_ready("rope"):
		confirm()

func onInputMethodChanged():
	updateTexts()

func updateTexts():
	var ninja_keeper = Keepers.local.getAll().filter( func(keeper): return keeper is Keeper3).front()
	var is_mouse = ninja_keeper.deviceId == 0 or not Options.singleplayerUseGamepad
	var control_option = "options.input.controls.mouse" if is_mouse else "options.input.gamepad.thumbstick"
	splitTutorialText(tr("level.tutorial.ninja.rope.desc1") % tr(control_option), "LabelDesc1", "LabelDesc2")
