extends Container

class_name Tutorial

@export var isFullscreen: = false
@export var showOnSummaryPopup: = true
@export var summaryCategory: = ""

var id: String
var tutorialParent
var keeper: Keeper

var isIn: = false
var isOut: = false

var triggered: = false
var confirmed: = false

@export var moveOutAfter: = 30.0
const moveTime: = 0.3
@export var moveInDelay: = 2.0
@export var listeningDelay: = 0.0
@export var triggerDuringWave: = false
@export var minTimeToWave: = 20.0

const introDelay: = 1.0

var listeningTo: = []

var tween

var split_tutorial_texts: Array

func _ready():
	tween = DeprecatedTween.new()
	add_child(tween)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END
	position.y = get_parent().size.y

	add_to_group("pauseL")
	visible = false

	Style.init(self)

func _notification(what: int) -> void :
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		for entry in split_tutorial_texts:
			splitTutorialText(entry[0], entry[1], entry[2], false)

func process_trigger(delta: float) -> bool:
	return triggered

func process_confirm(delta: float):
	pass

func listen(property: String, immediateCallback: = false):
	Data.listen(self, property, immediateCallback)
	listeningTo.append(property)

func unlisten(property: String):
	Data.unlisten(self, property)
	listeningTo.erase(property)

func moveIn():
	if isIn or isOut:
		return

	beforeMoveIn()

	visible = true
	isIn = true
	tween.stop_all()
	tween.remove_all()

	tween.interpolate_callback(self, moveTime + moveInDelay, "onMovedIn")
	tween.interpolate_callback(Audio, moveTime * 0.65 + moveInDelay, "sound", "gui_tutorial_in")

	if isFullscreen:
		moveInFullscreen()
		if not Options.useGamepad(keeper.deviceId):
			GameWorld.setShowMouse(true)
	else:
		moveInSide()

func onMovedIn():
	pass

func onMoveOut():
	pass

func moveInSide():
	var inGoal = get_parent().size.y - size.y
	tween.interpolate_property(self, "position:y", position.y, inGoal, moveTime, Tween.TRANS_CUBIC, Tween.EASE_OUT, moveInDelay)
	tween.start()

var popupInput
func moveInFullscreen():
	var inGoal = (get_parent().size.y - size.y) * 0.5

	position.x = (size.x - get_parent().size.x) * 0.5
	tween.interpolate_property(self, "position:y", position.y, inGoal, moveTime, Tween.TRANS_CUBIC, Tween.EASE_OUT, moveInDelay)
	tween.start()

	Level.stage.pause(true)

func moveOut():
	if isOut:
		return

	for p in listeningTo:
		Data.unlisten(self, p)

	tween.stop_all()
	tween.remove_all()

	isOut = true
	var outGoal = get_parent().size.y
	tween.interpolate_property(self, "position:y", position.y, outGoal, moveTime, Tween.TRANS_CUBIC, Tween.EASE_IN)
	tween.interpolate_callback(self, moveTime + 0.2, "queue_free")
	tween.start()

	if isFullscreen:
		Level.stage.unpause()
		GameWorld.setShowMouse(false)
		if popupInput:
			popupInput.desintegrate()
	onMoveOut()

func beforeMoveIn():
	pass

func pauseChanged():
	if isFullscreen:

		return

	if GameWorld.paused:
		tween.stop_all()
	else:
		tween.resume_all()

func confirm():
	confirmed = true

func trigger():
	triggered = true

func splitTutorialText(id, label1, label2, require_notification = true):
	var s = tr(id)
	var parts = s.split("|")
	if parts.size() != 2:
		Logger.error("tutorial string is not formatted as expected", name + ".splitTutorialText", s)
		return
	if require_notification:
		split_tutorial_texts.append([id, label1, label2])
	find_child(label1).text = parts[0]
	find_child(label2).text = parts[1]
