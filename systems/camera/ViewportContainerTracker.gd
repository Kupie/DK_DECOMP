extends CenterContainer

@onready var tracker = $Tracker / TrackerPos
var parent: Control = null

func _ready():
	parent = get_parent().get_parent()

func getPos() -> Vector2:
	return tracker.global_position

func getCenterOffset() -> Vector2:
	return tracker.global_position - (parent.get_rect().size / 2)
