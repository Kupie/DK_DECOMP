extends PanelContainer

const PANEL_INSIDE_DARK_SELECTED_STYLE = preload("res://gui/panels/panel_inside_dark_selected.tres")
const PANEL_INSIDE_STYLE = preload("res://gui/panels/panel_inside.tres")
const PANEL_INSIDE_DARK_STYLE = preload("res://gui/panels/panel_inside_dark.tres")

signal on_selected
signal playSound

@export var color: = ""
@export var team_exclusive: = ""

var selected: = false
var mouseInside: = false
var hovered: = false

func _ready():
	$SelectedPanel.modulate.a = 0
	find_child("CollisionShape2D").shape = RectangleShape2D.new()

	match color:
		"color0":
			%ColorRect1.color = Color("082528")
			%ColorRect2.color = Color("082528")
		"color1":
			%ColorRect1.color = Color("604D28")
			%ColorRect2.color = Color("604D28")
		"color2":
			%ColorRect1.color = Color("704228")
			%ColorRect2.color = Color("704228")
		"color3":
			%ColorRect1.color = Color("803F28")
			%ColorRect2.color = Color("803F28")

	Style.init(self)

func canFocusUse(keeper: Keeper) -> bool:
	return is_visible_in_tree() and team_exclusive == "" or keeper.teamId == team_exclusive

func useHold(keeper: Keeper) -> bool:
	return false

func useHit(keeper: Keeper) -> bool:
	if not is_visible_in_tree():
		return false
	playSound.emit("gui_select")
	on_selected.emit(color, keeper)
	return true

func _process(delta):
	if not visible:
		return

	modulate = Color.WHITE
	if selected:
		set("theme_override_styles/panel", PANEL_INSIDE_DARK_SELECTED_STYLE)
	elif hovered:
		modulate = Color.WHITE * 1.4
	else:
		set("theme_override_styles/panel", PANEL_INSIDE_DARK_STYLE)

	%Usable.position = size * 0.5
	find_child("CollisionShape2D").shape.extents = size * 0.5

	if mouseInside:
		hovered = true
	else:
		if %Usable.focussed:
			hovered = true
		else:
			hovered = false

func _on_LoadoutChoice_mouse_entered():
	var mouse_keeper: = Keepers.getLocalMouseUser()
	if is_instance_valid(mouse_keeper) and canFocusUse(mouse_keeper):
		mouseInside = true

func _on_LoadoutChoice_mouse_exited():
	mouseInside = false

func _on_LoadoutChoice_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:

		var mouse_keeper: = Keepers.getLocalMouseUser()
		if is_instance_valid(mouse_keeper) and canFocusUse(mouse_keeper):
			useHit(mouse_keeper)
			return



		if team_exclusive == "":
			useHit(null)

func getGlobalPosition() -> Vector2:
	return $Usable.global_position
