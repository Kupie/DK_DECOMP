class_name PlayerCanvas
extends CanvasLayer

@export var overlay: ColorRect
@onready var areaLimiter: Control = $AreaLimiter

var scaling: = 0.75
var playerId: String
var teamId: String

func _ready():
	Style.init(self)


	visible = false

	var viewport: Viewport = get_viewport()
	viewport.size_changed.connect(_onViewportSizeChange)
	_refreshAreaLimiter.call_deferred()

func _onViewportSizeChange() -> void :
	_refreshAreaLimiter()

func _refreshAreaLimiter() -> void :
	if not is_inside_tree():
		await (tree_entered)
	scale = scaling * Vector2.ONE
	areaLimiter.position = Vector2(0, 0)
	areaLimiter.size = Vector2(get_viewport().size_2d_override) / scaling
	%Hud.updatePosition()

func init(keeper):
	visible = true
	self.playerId = keeper.playerId
	self.teamId = keeper.teamId

	Data.listen(self, teamId + ".versus.disruption")
	Data.listen(self, teamId + ".versus.corruption")

	if keeper is Keeper:
		%Hud.init(keeper)
		%TutorialManager.init(keeper)
		%PlayerDirectionIndicators.init(keeper)
	else:
		%Hud.queue_free()
		%TutorialManager.queue_free()
		%PlayerDirectionIndicators.queue_free()

	%ActionHintPopup.init(keeper.teamId)

	var nmbOfKeepers = Keepers.local.getCount()
	var singleplayer: bool = nmbOfKeepers == 1
	if singleplayer:
		scaling = 1.0
	_refreshAreaLimiter()

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".versus.disruption":
		show_event_text(tr("versus.message.disruption"))
		$DisruptionSound.play()
	elif property == teamId + ".versus.corruption":
		show_event_text(tr("versus.message.corruption"))
		$CorruptionSound.play()
		var t: = create_tween()
		t.tween_interval(0.08)
		t.tween_callback($CorruptionSound.play)
		t.tween_interval(0.2)
		t.tween_callback($CorruptionSound.play)
		t.tween_interval(0.3)
		t.tween_callback($CorruptionSound.play)
		t.tween_interval(0.5)
		t.tween_callback($CorruptionSound.play)

func show_event_text(text: String):
	%EventLabel.start(text)

func add_popup(popup):
	$AreaLimiter.add_child(popup)
