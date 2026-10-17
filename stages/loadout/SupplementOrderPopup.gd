extends ColorRect

signal close

var supplements: Array
var labels: Array
var textures: Array

func _ready():
	color = Style.OVERLAY_COLOR_IN

	var container = find_child("SupplementsContainer")

	supplements = GameWorld.customSupplementOrder.duplicate()

	for supplement in GameWorld.customSupplementOrder:
		if not Data.supplements.has(supplement):
			supplements.erase(supplement)


	for supplement in Data.supplements:
		if not supplements.has(supplement):
			supplements.append(supplement)

	var i: = 0
	for supplement in supplements:
		var li = Label.new()
		li.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
		li.text = str(i + 1)
		container.add_child(li)

		var t = TextureRect.new()
		t.texture = Data.loadIconOrFallback("res://content/icons/" + supplement + ".png")
		if t.texture:
			t.custom_minimum_size = t.texture.get_size() * 2
		t.expand = true
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		container.add_child(t)
		textures.append(t)

		var l = Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND
		l.text = tr("upgrades." + supplement + ".title")
		container.add_child(l)
		labels.append(l)

		if i > 0:
			var bfirst = Button.new()
			bfirst.icon = preload("res://gui/icons/up2.png")
			container.add_child(bfirst)
			bfirst.connect("pressed", Callable(self, "orderUpFirstPressed").bind(i))
		else:
			container.add_child(Control.new())
		if i > 0:
			var bup = Button.new()
			bup.icon = preload("res://gui/icons/up.png")
			container.add_child(bup)
			bup.connect("pressed", Callable(self, "orderUpPressed").bind(i))
		else:
			container.add_child(Control.new())
		if i < supplements.size() - 1:
			var bdown = Button.new()
			bdown.icon = preload("res://gui/icons/down.png")
			container.add_child(bdown)
			bdown.connect("pressed", Callable(self, "orderDownPressed").bind(i))
		else:
			container.add_child(Control.new())
		if i < supplements.size() - 1:
			var blast = Button.new()
			blast.icon = preload("res://gui/icons/down2.png")
			container.add_child(blast)
			blast.connect("pressed", Callable(self, "orderDownLastPressed").bind(i))
		else:
			container.add_child(Control.new())

		i += 1

	Style.init(self)

func orderUpFirstPressed(i):
	Audio.sound("gui_confirm")
	if i <= 0 or i >= labels.size():
		return

	var t_label = labels[i].text
	var t_texture = textures[i].texture
	var t_supplement = supplements[i]

	for j in range(i, 0, -1):
		labels[j].text = labels[j - 1].text
		textures[j].texture = textures[j - 1].texture
		supplements[j] = supplements[j - 1]

	labels[0].text = t_label
	textures[0].texture = t_texture
	supplements[0] = t_supplement

func orderUpPressed(i):
	Audio.sound("gui_confirm")
	var t = labels[i].text
	labels[i].text = labels[i - 1].text
	labels[i - 1].text = t

	var tex = textures[i].texture
	textures[i].texture = textures[i - 1].texture
	textures[i - 1].texture = tex

	var g = supplements[i]
	supplements[i] = supplements[i - 1]
	supplements[i - 1] = g

func orderDownPressed(i):
	Audio.sound("gui_confirm")
	var t = labels[i].text
	labels[i].text = labels[i + 1].text
	labels[i + 1].text = t

	var tex = textures[i].texture
	textures[i].texture = textures[i + 1].texture
	textures[i + 1].texture = tex

	var g = supplements[i]
	supplements[i] = supplements[i + 1]
	supplements[i + 1] = g

func orderDownLastPressed(i):
	Audio.sound("gui_confirm")
	if i < 0 or i >= labels.size() - 1:
		return

	var t_label = labels[i].text
	var t_texture = textures[i].texture
	var t_supplement = supplements[i]

	for j in range(i, labels.size() - 1):
		labels[j].text = labels[j + 1].text
		textures[j].texture = textures[j + 1].texture
		supplements[j] = supplements[j + 1]

	labels[labels.size() - 1].text = t_label
	textures[textures.size() - 1].texture = t_texture
	supplements[supplements.size() - 1] = t_supplement

func open():
	if GameWorld.useCustomSupplementOrderSetting and GameWorld.customSupplementOrder.size() > 0:
		InputSystem.grabFocus(find_child("ButtonApplySupplementOrder"))
		find_child("ButtonApplySupplementOrder").button_pressed = true
		find_child("ButtonNoSupplementOrder").button_pressed = false
		showSupplementOrder()
	else:
		InputSystem.grabFocus(find_child("ButtonNoSupplementOrder"))
		find_child("ButtonNoSupplementOrder").button_pressed = true
		find_child("ButtonApplySupplementOrder").button_pressed = false
		hideSupplementOrder()

func _on_ButtonNoSupplementOrder_pressed():
	Audio.sound("gui_confirm")
	hideSupplementOrder()
	GameWorld.useCustomSupplementOrderSetting = false

func _on_ButtonApplySupplementOrder_pressed():
	Audio.sound("gui_confirm")
	showSupplementOrder()
	GameWorld.useCustomSupplementOrderSetting = true

func showSupplementOrder():
	find_child("ScrollContainer").visible = true

func hideSupplementOrder():
	find_child("ScrollContainer").visible = false

func _on_CloseButton_pressed():
	_close()
	emit_signal("close")

func _close():
	Audio.sound("gui_back")

	if find_child("ButtonApplySupplementOrder").button_pressed:
		GameWorld.customSupplementOrder = supplements

	queue_free()
