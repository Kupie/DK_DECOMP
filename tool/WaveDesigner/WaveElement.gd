extends PanelContainer

signal remove
signal selected
signal duplicate

var type: String

func init(type, variant: = ""):
	self.type = type
	$VBoxContainer / Title.text = type
	$VBoxContainer / TextureRect.texture = load("res://content/icons/monster_" + type + ".png")
	var i: = 0

	var variantsRawData = Data.gameProperties.get(type + ".variants")
	var variantsArray: Array
	if variantsRawData is Array:
		variantsArray = variantsRawData
	else:
		variantsArray = [variantsRawData]

	for v in variantsArray:
		$VBoxContainer / Variants.add_item(v)
		if v == variant:
			$VBoxContainer / Variants.select(i)
		i += 1
	if variant == "":
		$VBoxContainer / Variants.select(0)
	hideVariants()

func _on_WaveElement_mouse_entered():
	modulate = Style.FOCUS_MODULATE

func _on_WaveElement_mouse_exited():
	modulate = Color.WHITE

func _on_WaveElement_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.control:
			emit_signal("duplicate", type, event.position)
		else:
			if event.button_index == 1:
				emit_signal("selected", type, event.position)
			elif event.button_index == 2:
				emit_signal("remove")

func enableMouse():
	mouse_filter = Control.MOUSE_FILTER_STOP

func disableMouse():
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func showVariants():
	$VBoxContainer / Variants.auto_height = true

func hideVariants():
	$VBoxContainer / Variants.auto_height = false

func getVariant() -> String:
	if not $VBoxContainer / Variants.is_anything_selected():
		return ""

	var selectedIdx = $VBoxContainer / Variants.get_selected_items()[0]
	return $VBoxContainer / Variants.get_item_text(selectedIdx)

func serialize() -> String:
	return "add." + type + "." + getVariant()
