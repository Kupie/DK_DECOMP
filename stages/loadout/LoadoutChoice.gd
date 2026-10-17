class_name LoadoutChoice
extends PanelContainer

const PANEL_INSIDE_DARK_SELECTED_STYLE = preload("res://gui/panels/panel_inside_dark_selected.tres")
const PANEL_INSIDE_STYLE = preload("res://gui/panels/panel_inside.tres")
const PANEL_INSIDE_DARK_STYLE = preload("res://gui/panels/panel_inside_dark.tres")
const BUTTON_DISABLED_STYLE = preload("res://gui/buttons/button_disabled.tres")

signal select
signal toggled(bool)

@export var toggleable: = false

@export var id: String
@export var titleLocId: String
@export var descLocId: String
@export var icon: Texture2D
@export var disabledAlpha: = 0.5
@export var emit_keeper_on_selected: bool = false
@export var team_exclusive: = ""
var setChoiceCalled: = false

var filling: float
var selected: = false
var disabled: = false
var mouseInside: = false
var hovered: = false
var hostOnly: = false

var loadoutScale: = 3.0
var expand_icon: = true

var _visible_on_screen_notifier_2d: VisibleOnScreenNotifier2D
var _usable: Area2D
var _label_title: Label
var _label_desc: Label
var _collision_shape: CollisionShape2D

var _coll_shape_extends_cached: Vector2
var _current_theme

func _notification(in_what: int) -> void :
	if in_what == NOTIFICATION_SCENE_INSTANTIATED:
		_visible_on_screen_notifier_2d = $VisibleOnScreenNotifier2D
		_usable = %Usable
		_label_title = %LabelTitle
		_label_desc = %LabelDesc

func _ready():
	Style.init(self)
	$SelectedPanel.modulate.a = 0
	_collision_shape = find_child("CollisionShape2D")
	_collision_shape.shape = RectangleShape2D.new()

	if not setChoiceCalled:
		setChoice(titleLocId, id, icon, descLocId)

	_current_theme = get("theme_override_styles/panel")

func set_scale(value) -> void :
	if typeof(value) == TYPE_FLOAT:
		assert (false, """This call happened most probably due to name clashes, this gdscript had property called 'scale'
				in Godot 3, but it's impossible in Godot 4 since Control has property named in the same way, it has been
				renamed to 'loadoutScale'""")
		loadoutScale = value
	scale = value

func get_scale():
	assert (false, """This call happened most probably due to name clashes, this gdscript had property called 'scale'
		in Godot 3, but it's impossible in Godot 4 since Control has property named in the same way, it has been
		renamed to 'loadoutScale'""")
	return loadoutScale

func canFocusUse(keeper: Keeper) -> bool:
	return is_visible_in_tree() and (team_exclusive == "" or keeper.teamId == team_exclusive) and ( not hostOnly or keeper.peerId == 1)

func useHold(keeper: Keeper) -> bool:
	return false

func useHit(keeper: Keeper) -> bool:
	if disabled:
		return false

	if toggleable:
		selected = not selected
		emit_signal("toggled", selected)
	else:
		if emit_keeper_on_selected:
			emit_signal("select", keeper)
		else:
			emit_signal("select")

	if not (toggleable and not selected):
		$SelectedPanel.modulate.a = 1.0
		$Tween.interpolate_property($SelectedPanel, "modulate:a", $SelectedPanel.modulate.a, 0.0, 0.3, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.3)
		$Tween.start()
	return true

func onLocaleChanged():
	setChoice(titleLocId, id, icon, descLocId)

func setChoiceNoTr(title: String, id: String, icon: Texture2D, hint = null):
	setChoiceCalled = true
	_label_title.text = title
	self.id = id


func setChoice(titleKey: String, id: String, icon: Texture2D, hint = null):
	titleLocId = titleKey
	if hint is String:
		descLocId = hint
	setChoiceCalled = true
	self.id = id

	if titleKey == "":
		_label_title.visible = false


	else:
		_label_title.visible = true
		_label_title.text = tr(titleKey)

	setDescription(hint)

	if icon:
		%Icon.texture = icon
		if not expand_icon:
			%Icon.size_flags_horizontal = SIZE_SHRINK_CENTER
			%Icon.size_flags_vertical = SIZE_EXPAND_FILL
			if icon.get_size().x < 10:
				loadoutScale += 1
			if icon.get_size().x < 20:
				loadoutScale += 1
		%Icon.custom_minimum_size = icon.get_size() * loadoutScale
		%Icon.visible = true

	else:
		%Icon.visible = false

func setDescription(hint):
	if hint is String and hint != "":
		_label_desc.text = tr(hint)
	else:
		_label_desc.visible = false
		if hint:
			hint.setFollowControl(self)

func _process(delta):
	if not _visible_on_screen_notifier_2d.is_on_screen():
		set_process(false)

	if not visible or disabled:
		return

	if selected:
		_set_theme(PANEL_INSIDE_DARK_SELECTED_STYLE)
	elif hovered:
		_set_theme(PANEL_INSIDE_STYLE)
	else:
		_set_theme(PANEL_INSIDE_DARK_STYLE)

	var current_size: Vector2 = size * 0.5
	if _usable.position != current_size:
		_usable.position = current_size

	var update_collision: bool = not is_zero_approx(_coll_shape_extends_cached.distance_squared_to(current_size))
	if update_collision:
		_visible_on_screen_notifier_2d.position = _usable.position
		_visible_on_screen_notifier_2d.rect = Rect2( - current_size, current_size * 2.0)
		_collision_shape.shape.extents = current_size
		_coll_shape_extends_cached = current_size

	var targetModulate: Color = Color.WHITE * (1.0 + filling * 1.0)
	if _label_title.self_modulate != targetModulate:
		_label_title.self_modulate = targetModulate
		_label_desc.self_modulate = targetModulate

	if mouseInside and ( not hostOnly or multiplayer.is_server()):
		hovered = true
		filling = min(1.0, filling + delta * 6)
	else:
		if _usable.focussed:
			hovered = true
			filling = min(1.0, filling + delta * 4)
		else:
			hovered = false
			filling = max(0.0, filling - delta * 6)

func _set_theme(new_theme) -> void :
	if _current_theme == new_theme:
		return
	_current_theme = new_theme
	set("theme_override_styles/panel", new_theme)

func set_enabled(enable: bool, useLockIcon: = true):
	if enable:
		disabled = false
		modulate.a = 1.0
		$LockIcon.hide()
		%Icon.material = null
		$Usable.monitorable = true
		$Usable.monitoring = true
	else:
		disabled = true
		modulate.a = disabledAlpha
		if useLockIcon:
			$LockIcon.show()
		%Icon.material = preload("res://stages/loadout/icon_grayscale_material.tres")
		_set_theme(BUTTON_DISABLED_STYLE)
		$Usable.monitorable = false
		$Usable.monitoring = false

func _on_LoadoutChoice_mouse_entered():
	var mouse_keeper: = Keepers.getLocalMouseUser()
	if is_instance_valid(mouse_keeper) and canFocusUse(mouse_keeper) and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		mouseInside = true

func _on_LoadoutChoice_mouse_exited():
	mouseInside = false

func _on_LoadoutChoice_gui_input(event):
	if hostOnly and not multiplayer.is_server():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:

		var mouse_keeper: = Keepers.getLocalMouseUser()
		if is_instance_valid(mouse_keeper) and canFocusUse(mouse_keeper):
			useHit(mouse_keeper)
			return



		if team_exclusive == "":
			useHit(null)

func getGlobalPosition() -> Vector2:
	return $Usable.global_position


func _on_visible_on_screen_notifier_2d_screen_entered() -> void :
	set_process(true)


func _on_visible_on_screen_notifier_2d_screen_exited() -> void :
	set_process(false)

func onInputMethodChanged():
	if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		mouseInside = false
