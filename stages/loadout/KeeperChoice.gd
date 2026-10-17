extends Control

const BUTTON_DISABLED_STYLE = preload("res://gui/buttons/button_disabled.tres")
const PANEL_INSIDE_DARK_SELECTED_STYLE = preload("res://gui/panels/panel_inside_dark_selected.tres")
const PANEL_INSIDE_DARK_STYLE = preload("res://gui/panels/panel_inside_dark.tres")

signal select

var id: String
var deviceId: int = -1

var filling: = 0.0
var mouseInside: = false
var selected: = false
var disabled: = true






func _ready():
	Style.init(self)
	find_child("Usable").find_child("CollisionShape2D").shape = RectangleShape2D.new()
	$SelectedPanel.modulate.a = 0.0
	%NameLabel.visible = false

func setName(n: String):
	%NameLabel.visible = true
	%NameLabel.text = n

func setChoice(id: String, texture: Texture2D, styled: = false):
	if not styled:
		%Sprite2D.add_to_group("unstyled")
	%Sprite2D.texture = texture
	if texture:
		%Sprite2D.custom_minimum_size = texture.get_size() * 4
		%Sprite2D.custom_minimum_size.y = 100
	self.id = id

func canFocusUse(keeper: Keeper) -> bool:
	return true

func useHold(keeper: Keeper) -> bool:
	return useHit(keeper)

func useHit(keeper: Keeper) -> bool:
	if disabled:
		return false

	emit_signal("select", keeper)

	$SelectedPanel.modulate.a = 1.0
	$Tween.interpolate_property($SelectedPanel, "modulate:a", $SelectedPanel.modulate.a, 0.0, 0.3, Tween.TRANS_LINEAR, Tween.EASE_IN, 0.3)
	$Tween.start()

	return true

var tmp_style
var grayscale_material: = preload("res://stages/loadout/icon_grayscale_material.tres")
func set_enabled(enable: bool):
	if enable:
		disabled = false
		modulate.a = 1.0
		$LockIcon.hide()
		if %Sprite2D.material and not tmp_style:
			if %Sprite2D.material == grayscale_material:
				%Sprite2D.material = null
		else:
			%Sprite2D.material = tmp_style
		$Usable.monitorable = true
		$Usable.monitoring = true
	else:
		disabled = true
		modulate.a = 0.5
		$LockIcon.show()
		if %Sprite2D.material and %Sprite2D.material != grayscale_material:
			tmp_style = %Sprite2D.material
		%Sprite2D.material = grayscale_material
		set("theme_override_styles/panel", BUTTON_DISABLED_STYLE)
		$Usable.monitorable = false
		$Usable.monitoring = false

func clear_material() -> void :
	%Sprite2D.material = null

func _process(delta):
	if not visible or disabled:
		return

	if selected:
		set("theme_override_styles/panel", PANEL_INSIDE_DARK_SELECTED_STYLE)
	else:
		set("theme_override_styles/panel", PANEL_INSIDE_DARK_STYLE)

	find_child("Usable").position = size * 0.5
	find_child("CollisionShape2D").shape.extents = size * 0.5

	modulate = Color.WHITE * (1.0 + filling * 1.2)

	var areas = $Area2D.get_overlapping_areas()

	for area in areas:
		deviceId = area.get_parent().deviceId
		filling = 0.0
		return

	if mouseInside:
		filling = min(1.0, filling + delta * 6)
	else:
		if find_child("Usable").focussed:
			filling = min(1.0, filling + delta * 4)
		else:
			filling = max(0.0, filling - delta * 6)


func _on_KeeperChoice_mouse_entered():
	mouseInside = true

func _on_KeeperChoice_mouse_exited():
	mouseInside = false

func _on_KeeperChoice_gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_keeper: = Keepers.getLocalMouseUser()
		if is_instance_valid(mouse_keeper) and canFocusUse(mouse_keeper):
			useHit(mouse_keeper)
			return
