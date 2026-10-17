class_name ProximityProxy extends Node2D

enum Group{
	CARRYABLE = 1, 
}

signal moved()
signal predelete()
signal tree_reenter()

@export
var group: Group = Group.CARRYABLE

@warning_ignore("unused_private_class_variable")
var _segment_id: Vector2i = Vector2i(-10000, -10000)
var _id: int = -1
var _has_been_in_tree: bool = false

func _ready() -> void :
	set_notify_transform(true)
	Proximiter.__register_new_proxy(self)
	request_ready()

func _enter_tree() -> void :
	if not _has_been_in_tree:
		_has_been_in_tree = true
		return
	tree_reenter.emit()

func set_id(in_unique_id: int) -> void :
	if _id != -1:

		return
	_id = in_unique_id

func _notification(what: int) -> void :
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		moved.emit()
	elif what == NOTIFICATION_PREDELETE:
		predelete.emit()
