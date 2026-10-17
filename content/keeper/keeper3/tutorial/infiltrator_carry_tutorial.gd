extends Tutorial

@export var carry_trigger_time: = 6.0

var carry_time: = 0.0

func _ready():
	super._ready()
	updateTexts()

func process_trigger(delta: float) -> bool:


	if tutorialParent.carriedCarryables.any( func(carryable): return carryable.carryableType == "resource"):
		carry_time += delta

	if carry_time >= carry_trigger_time:
		trigger()
	return triggered

func process_confirm(delta: float):
	if tutorialParent.kunaiCarrierDeployCount > 0:
		confirm()

func onInputMethodChanged():
	updateTexts()

func updateTexts():
	var ninja_keeper = Keepers.local.getAll().filter( func(keeper): return keeper is Keeper3).front()
	var is_mouse = ninja_keeper.deviceId == 0 or not Options.singleplayerUseGamepad
	var control_option = "options.input.controls.mouse" if is_mouse else "options.input.gamepad.thumbstick"

	splitTutorialText(tr("level.tutorial.ninja.carry.desc1") % tr(control_option), "LabelDesc1", "LabelDesc2")
