extends ColorRect

signal close

var caveIds: Array
var containers: Array

const extraSize: = Vector2(60, 20)

func _ready():
	color = Style.OVERLAY_COLOR_IN
	var container = find_child("Caves")

	caveIds = GameWorld.customCaveOrder.duplicate()
	for cave in Data.CAVE_SCENES.keys():
		if not caveIds.has(cave):
			caveIds.append(cave)

	var maxSize: = Vector2()
	var i: = 0
	var caves: Array = []
	for caveId in caveIds:
		var li: = Label.new()
		li.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		li.text = str(i + 1)
		container.add_child(li)

		var c = CenterContainer.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var t = Data.CAVE_SCENES[caveId].instantiate()
		t.z_index = 0
		t.scale = Vector2.ONE * 2.0
		c.custom_minimum_size = t.getPixelSize() * t.scale + extraSize
		t.position.x += 30
		c.add_child(t)
		container.add_child(c)
		caves.append(t)
		containers.append(c)
		maxSize.x = max(maxSize.x, c.size.x)
		maxSize.y = max(maxSize.y, c.size.y)
		t.disableParallax()

		if i > 0:
			var bfirst = Button.new()
			bfirst.icon = preload("res://gui/icons/up2.png")
			bfirst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			container.add_child(bfirst)
			bfirst.connect("pressed", Callable(self, "orderUpFirstPressed").bind(i))
		else:
			container.add_child(Control.new())
		if i > 0:
			var bup = Button.new()
			bup.icon = preload("res://gui/icons/up.png")
			bup.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			container.add_child(bup)
			bup.connect("pressed", Callable(self, "orderUpPressed").bind(i))
		else:
			container.add_child(Control.new())
		if i < caveIds.size() - 1:
			var bdown = Button.new()
			bdown.icon = preload("res://gui/icons/down.png")
			bdown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			container.add_child(bdown)
			bdown.connect("pressed", Callable(self, "orderDownPressed").bind(i))
		else:
			container.add_child(Control.new())
		if i < caveIds.size() - 1:
			var blast = Button.new()
			blast.icon = preload("res://gui/icons/down2.png")
			blast.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			container.add_child(blast)
			blast.connect("pressed", Callable(self, "orderDownLastPressed").bind(i))
		else:
			container.add_child(Control.new())
		i += 1

	maxSize *= 0.5
	for cave in caves:
		cave.position.x = maxSize.x - cave.getPixelSize().x

	Style.init(self)

func orderUpFirstPressed(i):
	Audio.sound("gui_confirm")
	if i == 0:
		return
	var t1 = containers[i].get_child(0)
	for j in range(i, 0, -1):
		var t2 = containers[j - 1].get_child(0)
		containers[j].remove_child(t1)
		containers[j - 1].remove_child(t2)
		containers[j].add_child(t2)
		containers[j - 1].add_child(t1)

		containers[j].custom_minimum_size = t2.getPixelSize() * t2.scale + extraSize
		containers[j - 1].custom_minimum_size = t1.getPixelSize() * t1.scale + extraSize

	var id = caveIds[i]
	for j in range(i, 0, -1):
		caveIds[j] = caveIds[j - 1]
	caveIds[0] = id

func orderUpPressed(i):
	Audio.sound("gui_confirm")
	var t1 = containers[i].get_child(0)
	var t2 = containers[i - 1].get_child(0)
	containers[i].remove_child(t1)
	containers[i - 1].remove_child(t2)
	containers[i].add_child(t2)
	containers[i - 1].add_child(t1)

	containers[i].custom_minimum_size = t2.getPixelSize() * t2.scale + extraSize
	containers[i - 1].custom_minimum_size = t1.getPixelSize() * t1.scale + extraSize

	var id = caveIds[i]
	caveIds[i] = caveIds[i - 1]
	caveIds[i - 1] = id

func orderDownPressed(i):
	Audio.sound("gui_confirm")
	var t1 = containers[i].get_child(0)
	var t2 = containers[i + 1].get_child(0)
	containers[i].remove_child(t1)
	containers[i + 1].remove_child(t2)
	containers[i].add_child(t2)
	containers[i + 1].add_child(t1)
	containers[i].custom_minimum_size = t2.getPixelSize() * t2.scale + extraSize
	containers[i + 1].custom_minimum_size = t1.getPixelSize() * t1.scale + extraSize

	var id = caveIds[i]
	caveIds[i] = caveIds[i + 1]
	caveIds[i + 1] = id

func orderDownLastPressed(i):
	Audio.sound("gui_confirm")
	if i >= containers.size() - 1:
		return

	var t1 = containers[i].get_child(0)
	containers[i].remove_child(t1)
	containers[containers.size() - 1].add_child(t1)
	containers[containers.size() - 1].custom_minimum_size = t1.getPixelSize() * t1.scale + extraSize

	for j in range(i, containers.size() - 1):
		var t2 = containers[j + 1].get_child(0)
		containers[j + 1].remove_child(t2)
		containers[j].add_child(t2)
		containers[j].custom_minimum_size = t2.getPixelSize() * t2.scale + extraSize

	var id = caveIds[i]
	for j in range(i, caveIds.size() - 1):
		caveIds[j] = caveIds[j + 1]
	caveIds[caveIds.size() - 1] = id

func open():
	if GameWorld.useCustomCaveOrderSetting and GameWorld.customCaveOrder.size() > 0:
		InputSystem.grabFocus(find_child("ButtonApplyCaveOrder"))
		find_child("ButtonApplyCaveOrder").button_pressed = true
		find_child("ButtonNoCaveOrder").button_pressed = false
		showCaveOrder()
	else:
		InputSystem.grabFocus(find_child("ButtonNoCaveOrder"))
		find_child("ButtonNoCaveOrder").button_pressed = true
		find_child("ButtonApplyCaveOrder").button_pressed = false
		hideCaveOrder()

func _on_ButtonNoCaveOrder_pressed():
	Audio.sound("gui_confirm")
	hideCaveOrder()
	GameWorld.useCustomCaveOrderSetting = false

func _on_ButtonApplyCaveOrder_pressed():
	Audio.sound("gui_confirm")
	showCaveOrder()
	GameWorld.useCustomCaveOrderSetting = true

func showCaveOrder():
	find_child("ScrollContainer").visible = true

func hideCaveOrder():
	find_child("ScrollContainer").visible = false

func _on_CloseButton_pressed():
	_close()
	emit_signal("close")

func _close():
	Audio.sound("gui_back")

	if find_child("ButtonApplyCaveOrder").button_pressed:
		GameWorld.customCaveOrder = caveIds

	queue_free()
