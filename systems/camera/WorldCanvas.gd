class_name WorldCanvas extends CanvasLayer

@onready var _main_control: Control
@onready var _screen_cover: TeleportingScreenspaceEffect

func _notification(what: int) -> void :
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_main_control = $MainControl
		_screen_cover = $MainControl / TeleportScreenSpaceEffect
	if what == NOTIFICATION_READY:
		visible = false

func add_popup(popup):
	_main_control.add_child(popup)

func get_teleport_screenspace_effect() -> TeleportingScreenspaceEffect:
	return _screen_cover

func _on_main_control_child_entered_tree(child: Node) -> void :
	var nmb_of_children: int = _main_control.get_child_count()
	visible = nmb_of_children > 0

	if child is CanvasItem:
		if not child.visibility_changed.is_connected(_on_child_visibility_changed):
			child.visibility_changed.connect(_on_child_visibility_changed)

func _on_main_control_child_exiting_tree(_node: Node) -> void :
	_refresh_visibility.call_deferred()

func _on_child_visibility_changed() -> void :
	_refresh_visibility()

func _refresh_visibility() -> void :
	var any_child_visible: bool = false
	for children: Node in _main_control.get_children():
		if children is CanvasItem:
			any_child_visible = children.visible or any_child_visible
	visible = any_child_visible
