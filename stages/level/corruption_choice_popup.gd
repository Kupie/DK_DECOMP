extends Container

signal focus_changed
signal selected_by_mouse

var teamId: String
var playerId: String

var isIn: = false
var animationDone: bool

var selectedCorruptionId: = ""

func _ready():
	visible = true

	Style.init(self)

	for panel in %Corruptions.get_children():
		panel.connect("focussed", optionFocussed.bind(panel))
		panel.connect("selected", emit_signal.bind("selected_by_mouse"))

	InputSystem.grabFocus( %Corruptions.get_children().front())

	if Keepers.isSplitScreen:
		%Corruptions.columns = 2

func optionFocussed(panel):
	if isIn:
		Audio.sound("gui_move")

	for g in %Corruptions.get_children():
		g._on_GadgetChoice_focus_exited()

	if panel:
		panel.setFocus()

	selectedCorruptionId = panel.id
	focus_changed.emit()

func moveIn():
	if isIn:
		return

	isIn = true
	animationDone = false
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property(self, "position:y", position.y, 0, 0.6, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	$Tween.interpolate_callback(self, 0.7, "set", "animationDone", true)
	$Tween.start()

func moveOut(inSelfDelete: bool = true):
	if not isIn:
		return

	for c in %Corruptions.get_children():
		if c.has_focus():
			c.release_focus()

	isIn = false
	$Tween.stop_all()
	$Tween.remove_all()
	$Tween.interpolate_property(self, "position:y", position.y, get_viewport_rect().size.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	if inSelfDelete:
		$Tween.interpolate_callback(self, 0.3, "queue_free")
	$Tween.start()
