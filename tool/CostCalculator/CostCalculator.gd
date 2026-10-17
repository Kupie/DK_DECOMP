extends Node2D

func _ready():
	Style.setPalette("palette_1_1")
	var roots: = getRoots()
	var rootList: PackedStringArray
	for rootType in roots.keys():
		rootList.append_array(roots.get(rootType))
	for r in rootList:
		find_child("RootList").add_item(r, loadIcon(r))
	find_child("RootList").sort_items_by_text()
	Style.init(self)
	find_child("LockContainer").visible = false

func _process(delta):
	if Input.is_action_just_pressed("cheats"):
		Audio.sound("gui_hover")
		find_child("ListContainer").visible = not find_child("ListContainer").visible
		find_child("UIContainer").visible = not find_child("UIContainer").visible

	if Input.is_action_just_pressed("f2"):
		generateSingleItem()
	if Input.is_action_just_pressed("f3"):
		generateAllItems()
	if Input.is_action_just_pressed("f4"):
		clearLog()

	if Input.is_action_just_pressed("keeper1_drop"):
		updateMaxRepeats()
	if Input.is_action_just_pressed("dome_ability1"):
		find_child("RepeatSpinBox").value -= 1
	if Input.is_action_just_pressed("dome_ability2"):
		find_child("RepeatSpinBox").value += 1


func getRoots(invert: = false) -> Dictionary:
	var rootTypes: = {}
	var roots: PackedStringArray = []
	for u in Data.upgrades.values():
		if not roots.has(u.get("root", "")):
			roots.append(u.get("root", ""))

	for root in roots:
		var rootType: String = Data.gadgets.get(root, {}).get("type", "empty")
		var rootsOfType: PackedStringArray
		if rootTypes.has(rootType):
			rootsOfType = rootTypes.get(rootType)
		else:
			rootsOfType = []
		rootsOfType.append(root)
		rootsOfType.sort()
		if invert:

			rootsOfType.reverse()
		rootTypes[rootType] = rootsOfType

	return rootTypes

func getUpgrades(item: String) -> Array:
	var upgrades: = []
	for u in Data.upgrades:
		if Data.upgrades.get(u).get("root") == item:
			upgrades.append(u)
	upgrades.sort_custom(Callable(self, "sortByTier"))
	return upgrades

func sortByTier(u1, u2):
	return Data.upgrades.get(u1).get("tier") < Data.upgrades.get(u2).get("tier")

func getUpgradesAndBlacklist(root: String, requiredUpgrades: = []) -> Array:
	var bought: = []
	var blacklisted: = []
	var upgrades: = requiredUpgrades
	for i in 2:
		for upgrade in upgrades:
			if bought.has(upgrade):
				continue
			if blacklisted.has(upgrade):
				continue
			var predecessors: Array = Data.upgrades.get(upgrade).get("predecessors", [])
			var forbidden: = false
			var any: bool = Data.upgrades.get(upgrade).get("predecessorsany", false)
			for p in predecessors:
				if blacklisted.has(p):
					blacklisted.append(upgrade)
					forbidden = true
			for p in predecessors:
				if any and bought.has(p):
					blacklisted.erase(upgrade)
					forbidden = false
			if forbidden:
				continue
			var lockedUpgrades: Array = Data.upgrades.get(upgrade).get("locks", [])
			if lockedUpgrades.is_empty():
				bought.append(upgrade)
				continue
			bought.append(upgrade)
			blacklisted.append_array(lockedUpgrades)
		upgrades = getUpgrades(root)
	return [bought, blacklisted]









func _on_RootList_item_selected(index):
	buildUpgradeList(find_child("RootList").get_item_text(index))
	buildLockList(find_child("RootList").get_item_text(index))

func buildUpgradeList(root: String):
	var list: ItemList = find_child("UpgradeList")
	list.clear()
	for c in find_child("RepeatablesContainer").get_children():
		c.queue_free()
	var upgrades = getUpgrades(root)
	for upgrade in upgrades:
		list.add_item(upgrade, loadIcon(upgrade))
		var repeat = Data.upgrades.get(upgrade, {}).get("repeatable", null)
		if repeat:
			var r = repeat.front()
			var spinner = SpinBox.new()
			if r.keyClass == "cost":
				spinner.max_value = 100
			elif r.keyClass == "times":
				spinner.max_value = r.value
			spinner.prefix = upgrade
			spinner.get_line_edit().expand_to_text_length = true
			find_child("RepeatablesContainer").add_child(spinner)

func buildLockList(root: String):
	var upgrades = getUpgrades(root)
	var lockGroups: = []
	for upgrade in upgrades:
		var lockedUpgrades: Array = Data.upgrades.get(upgrade).get("locks", [])
		if lockedUpgrades.is_empty():
			continue
		var lockGroup: = []
		for group in lockGroups:
			if group.has(upgrade):
				lockGroup = group
				break
		var isNewGroup = lockGroup.is_empty()
		for l in lockedUpgrades:
			if not lockGroup.has(l):
				lockGroup.append(l)
		if not lockGroup.has(upgrade):
			lockGroup.append(upgrade)
		if isNewGroup:
			lockGroups.append(lockGroup)
	find_child("LockContainer").visible = not lockGroups.is_empty()
	for c in find_child("LockGroupContainer").get_children():
		c.queue_free()
	var i: = 0
	while i < lockGroups.size():
		var group = lockGroups[i]
		for upgrade in group:
			var t = TextureRect.new()
			t.stretch_mode = TextureRect.STRETCH_KEEP
			t.texture = loadIcon(upgrade)
			t.tooltip_text = upgrade
			find_child("LockGroupContainer").add_child(t)
			Style.init(t)
		if i < lockGroups.size() - 1:
			var separator = VSeparator.new()
			find_child("LockGroupContainer").add_child(separator)
			Style.init(separator)
		i += 1

func totalCost(upgrades: Array, useRepeatablesMap: = true):
	var repeatablesMap: = {}
	var maxRepeats: = int(find_child("RepeatSpinBox").value)
	if useRepeatablesMap:
		for c in find_child("RepeatablesContainer").get_children():
			repeatablesMap[c.prefix] = int(c.value)
	var totalCost: = {}
	for u in upgrades:
		var repeatableChange = Data.upgrades.get(u).get("repeatable", null)
		if repeatableChange:
			var first = repeatableChange[0]
			var second = repeatableChange.back()
			var times: int
			if useRepeatablesMap:
				times = repeatablesMap.get(u)
			else:
				if first.keyClass == "cost":
					times = maxRepeats
				elif first.keyClass == "times":
					times = min(first.value, maxRepeats)
			var cost
			if first.keyClass == "cost":
				cost = first
			elif first.keyClass == "times":
				cost = second
			var baseCost: Dictionary = Data.upgrades.get(u).get("cost", {})
			var virtualCost: = baseCost.duplicate(true)
			for i in times:
				if cost.multiplicative:
					for c in virtualCost:
						virtualCost[c] = virtualCost.get(c, 0.0) * baseCost.get(c)
				elif cost.cumulative:
					for c in virtualCost:
						var b = baseCost.get(c)
						if cost.keyName == c:
							b += cost.value
						virtualCost[c] = virtualCost.get(c, 0.0) + b
			for c in baseCost:
				totalCost[c] = totalCost.get(c, 0.0) + virtualCost.get(c)
		else:
			var cost: Dictionary = Data.upgrades.get(u).get("cost", {})
			for c in cost:
				totalCost[c] = totalCost.get(c, 0.0) + cost.get(c)
	return totalCost

func addToLog(root: String, requiredUpgrades: = [], isSingle: = true):
	var content: = getUpgradesAndBlacklist(root, requiredUpgrades)
	var upgrades = content[0]
	var blacklist = content[1]

	var logItem = preload("res://tool/CostCalculator/LogItem.tscn").instantiate()
	find_child("LogContainer").add_child(logItem)
	logItem.buildName(root)
	logItem.buildCosts(totalCost(upgrades, isSingle))
	logItem.buildRequired(requiredUpgrades)
	logItem.buildBlacklist(blacklist)
	if isSingle:
		find_child("LogContainer").move_child(logItem, 0)

func loadIcon(iconName: String):
	var icon = load(str("res://content/icons/", iconName, ".png"))
	if icon:
		return icon
	return load("res://gui/icons/icon_close.svg")

func generateSingleItem():
	if not find_child("RootList").is_anything_selected():
		return
	var selectedRoot: String = find_child("RootList").get_item_text(find_child("RootList").get_selected_items()[0])
	var selectedUpgrades: = []
	var selectedItems: PackedInt32Array = find_child("UpgradeList").get_selected_items()
	for idx in selectedItems:
		selectedUpgrades.append(find_child("UpgradeList").get_item_text(idx))
	addToLog(selectedRoot, selectedUpgrades)

func generateAllItems():
	var roots: = getRoots()
	for rootType in roots.keys():
		var rootsOfType: PackedStringArray = roots.get(rootType)
		if rootsOfType.is_empty():
			continue
		for root in rootsOfType:
			print(root)
			addToLog(root, [], false)
		while find_child("LogContainer").get_child_count() % find_child("LogContainer").columns != 0:
			var filler = HSeparator.new()
			find_child("LogContainer").add_child(filler)
			filler.modulate.a = 0.0
			Style.init(filler)
		for i in find_child("LogContainer").columns:
			var filler = HSeparator.new()
			find_child("LogContainer").add_child(filler)
			Style.init(filler)

func clearLog():
	for c in find_child("LogContainer").get_children():
		c.queue_free()

func updateMaxRepeats():
	for c in find_child("RepeatablesContainer").get_children():
		var maxRepeats: = int(find_child("RepeatSpinBox").value)
		c.value = maxRepeats

func _on_GenerateSingleButton_pressed():
	generateSingleItem()

func _on_GenerateAllButton_pressed():
	generateAllItems()

func _on_ClearAllButton_pressed():
	clearLog()

func _on_MaxRepeatButton_pressed():
	updateMaxRepeats()
