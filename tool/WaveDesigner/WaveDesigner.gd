extends Control

var draggedElement
var dragOffset: = Vector2()

func _ready():
	Data.reset()
	call_deferred("init")
	var i = preload("res://tool/WaveDesigner/WaveDesignerInputProcessor.gd").new()
	i.integrate(self)

func init():
	var scene = preload("res://tool/WaveDesigner/WaveConnector.tscn")
	var c = scene.instantiate()
	find_child("WaveElements").add_child(c)
	c.connect("selected", Callable(self, "dragNewElement").bind(scene))

	for type in ["walker", "flyer", "driller", "diver", "tick", "worm", "bolter", "mucker", "shifter", "bigtick", "butterfly", "beast", "rockman", "stingray", "scarab", "stag"]:
		scene = preload("res://tool/WaveDesigner/WaveElement.tscn")
		var e = scene.instantiate()
		e.init(type)
		find_child("WaveElements").add_child(e)
		e.connect("selected", Callable(self, "dragNewElement").bind(scene))

	_on_LoadButton_pressed()
	Style.init(self)

func duplicateElement(type: String, offset: Vector2):
	if type != "connector":
		right_click()
		dragOffset = offset
		draggedElement = preload("res://tool/WaveDesigner/WaveElement.tscn").instantiate()
		draggedElement.init(type)
		draggedElement.disableMouse()
		draggedElement.connect("remove", Callable(self, "removeElement").bind(draggedElement))
		draggedElement.connect("duplicate", Callable(self, "duplicateElement"))
		$Control.add_child(draggedElement)
		Style.init(draggedElement)


func dragNewElement(type: String, offset: Vector2, scene):
	right_click()
	dragOffset = offset
	draggedElement = scene.instantiate()
	draggedElement.init(type)
	draggedElement.disableMouse()
	draggedElement.connect("remove", Callable(self, "removeElement").bind(draggedElement))
	draggedElement.connect("duplicate", Callable(self, "duplicateElement"))
	$Control.add_child(draggedElement)
	Style.init(draggedElement)


func initNewElement(el):
	el.connect("remove", Callable(self, "removeElement").bind(el))
	if el.has_signal("duplicate"):
		el.connect("duplicate", Callable(self, "duplicateElement"))

func dragExistingElement(type, offset, element):
	right_click()
	dragOffset = offset
	draggedElement = element
	draggedElement.hideVariants()
	draggedElement.disableMouse()
	draggedElement.get_parent().remove_child(draggedElement)
	$Control.add_child(draggedElement)

func removeElement(element):
	if draggedElement:
		return

	element.get_parent().remove_child(element)
	element.queue_free()

func _process(delta):
	if draggedElement:
		draggedElement.position = get_global_mouse_position() - dragOffset

func left_click():
	pass

func left_click_released(event: InputEventMouseButton) -> bool:
	if draggedElement:
		for part in find_child("WaveParts").get_children():
			if event.position.x >= part.global_position.x\
			and event.position.y >= part.global_position.y\
			and event.position.x < part.global_position.x + part.size.x\
			and event.position.y < part.global_position.y + part.size.y:
				part.dropDraggedElement(draggedElement, event.position - part.global_position, dragOffset)
				draggedElement = null
				return true
		right_click()
		return true
	return false

func right_click():
	if draggedElement:
		draggedElement.queue_free()
		draggedElement = null
		dragOffset *= 0

func dropElement(wavePart, pos: Vector2):
	if draggedElement:
		wavePart.dropDraggedElement(draggedElement, pos, dragOffset)
		draggedElement = null

func _on_NewButton_pressed():
	var wavePart = preload("res://tool/WaveDesigner/WavePart.tscn").instantiate()
	wavePart.connect("dropElement", Callable(self, "dropElement"))
	wavePart.connect("dragExistingElement", Callable(self, "dragExistingElement"))
	wavePart.connect("newElementCreated", Callable(self, "initNewElement"))
	find_child("WaveParts").add_child(wavePart)
	Style.init(wavePart)


func _on_LoadButton_pressed():
	for c in find_child("WaveParts").get_children():
		c.queue_free()

	var f = FileAccess.open("res://wavepart.txt", FileAccess.ModeFlags.READ)
	if f != null:
		while not f.eof_reached():
			var line: String = f.get_line()
			if line.strip_edges().length() > 1:
				var wavePart = preload("res://tool/WaveDesigner/WavePart.tscn").instantiate()
				wavePart.connect("dropElement", Callable(self, "dropElement"))
				wavePart.connect("dragExistingElement", Callable(self, "dragExistingElement"))
				wavePart.connect("newElementCreated", Callable(self, "initNewElement"))
				find_child("WaveParts").add_child(wavePart)
				wavePart.init(BackwardCompatibilityUtils.str_to_var(line))
	f.close()

func _on_SaveButton_pressed():
	var f = FileAccess.open("res://wavepart.txt", FileAccess.ModeFlags.WRITE)
	if f != null:
		for wp in find_child("WaveParts").get_children():
			f.store_string(var_to_str(wp.serialize()) + "\n")
	f.close()
