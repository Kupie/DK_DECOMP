extends Tutorial

@export var carry_limit_trigger_time: = 2.5

var was_shown: = false
var shown_drop_count: = 0
var carry_limit_time: = 0.0

func _ready():
	super._ready()
	updateTexts()

func process_trigger(delta: float) -> bool:
	if tutorialParent.hasBlockedNearbyCarryable():
		carry_limit_time += delta
	else:
		carry_limit_time = 0.0

	if carry_limit_time >= carry_limit_trigger_time or tutorialParent.downwardsDropCount > 0:
		trigger()
	return triggered

func onMovedIn():
	was_shown = true
	shown_drop_count = tutorialParent.downwardsDropCount

func process_confirm(delta: float):
	if was_shown and tutorialParent.downwardsDropCount > shown_drop_count:
		confirm()

func onInputMethodChanged():
	updateTexts()

func updateTexts():
	var ninja_keeper = Keepers.local.getAll().filter( func(keeper): return keeper is Keeper3).front()
	var is_mouse = ninja_keeper.deviceId == 0 or not Options.singleplayerUseGamepad
	var control_option = "options.input.controls.mouse" if is_mouse else "options.input.gamepad.thumbstick"

	splitTutorialText(tr("level.tutorial.ninja.drop.desc1") % tr(control_option), "LabelDesc1", "LabelDesc2")
