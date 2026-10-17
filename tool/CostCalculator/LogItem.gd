extends Control

func buildName(root: String):
	find_child("RootName").text = str("upgrades.", root, ".title")
	find_child("RootIcon").texture = loadIcon(root)
	Style.init(self)

func loadIcon(iconName: String):
	var icon = load(str("res://content/icons/", iconName, ".png"))
	if icon:
		return icon
	return load("res://gui/icons/icon_close.svg")

func buildCosts(costs: Dictionary):
	for cost in costs:
		var t = TextureRect.new()
		t.stretch_mode = TextureRect.STRETCH_KEEP
		t.texture = load(str("res://content/icons/icon_", cost, ".png"))
		find_child("CostContainer").add_child(t)
		var l = Label.new()
		l.text = str(costs.get(cost))
		find_child("CostContainer").add_child(l)
		Style.init(t)

func buildRequired(requiredUpgrades: Array):
	if requiredUpgrades.is_empty():
		find_child("RequiredContainer").visible = false
		return
	for upgrade in requiredUpgrades:
		var t = TextureRect.new()
		t.stretch_mode = TextureRect.STRETCH_KEEP
		t.tooltip_text = upgrade
		t.texture = loadIcon(upgrade)
		find_child("RequiredIconContainer").add_child(t)
		Style.init(t)

func buildBlacklist(blacklist: Array):
	if blacklist.is_empty():
		find_child("BlacklistContainer").visible = false
		return
	for upgrade in blacklist:
		var t = TextureRect.new()
		t.stretch_mode = TextureRect.STRETCH_KEEP
		t.texture = loadIcon(upgrade)
		t.tooltip_text = upgrade
		find_child("BlacklistIconContainer").add_child(t)
		Style.init(t)

func _on_DeleteButton_pressed():
	queue_free()
