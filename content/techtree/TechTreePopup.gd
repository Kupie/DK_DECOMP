extends Container

var isIn: = false

var teamId: String
var playerId: String

var animationDone: bool
var focussedPanel

var rootsToIgnore: = []
var defaultFontColor

func _ready():
	position.y += size.y
	find_child("TechTree").build(teamId, playerId, rootsToIgnore)

	find_child("Inventory").visible = true
	find_child("LabelIron").text = str(Data.getInventory(CONST.IRON, teamId))
	find_child("LabelWater").text = str(Data.getInventory(CONST.WATER, teamId))
	find_child("LabelSand").text = str(Data.getInventory(CONST.SAND, teamId))

	Data.listen(self, teamId + ".inventory.iron")
	Data.listen(self, teamId + ".inventory.water")
	Data.listen(self, teamId + ".inventory.sand")

	Style.init(self)


	%LabelIronCost.label_settings = %LabelIronCost.label_settings.duplicate()
	%LabelWaterCost.label_settings = %LabelWaterCost.label_settings.duplicate()
	%LabelSandCost.label_settings = %LabelSandCost.label_settings.duplicate()

	defaultFontColor = %LabelIronCost.label_settings.font_color

func propertyChanged(property: String, oldValue, newValue):
	if property == teamId + ".inventory.iron":
		find_child("LabelIron").text = str(clamp(newValue, 0, 999))
	elif property == teamId + ".inventory.water":
		find_child("LabelWater").text = str(clamp(newValue, 0, 999))
	elif property == teamId + ".inventory.sand":
		find_child("LabelSand").text = str(clamp(newValue, 0, 999))
	updateCostLabels()

func focus():
	find_child("TechTree").focus()

func setFocussedTechPanel(p):
	focussedPanel = p

func getFocussedTechPanel():
	return focussedPanel

func moveIn():
	if isIn:
		return

	visible = true
	isIn = true
	animationDone = false

	$Tween.interpolate_property(self, "position:y", position.y, get_parent().size.y - size.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	$Tween.interpolate_callback(self, 0.4, "set", "animationDone", true)
	$Tween.start()

func moveOut():
	if not isIn:
		return

	isIn = false

	Data.unlisten(self, teamId + ".inventory.iron")
	Data.unlisten(self, teamId + ".inventory.water")
	Data.unlisten(self, teamId + ".inventory.sand")
	Data.localEvent(playerId + ".dome.potentialrepair", 0, 0)

	$Tween.interpolate_property(self, "position:y", position.y, get_parent().size.y, 0.3, Tween.TRANS_CUBIC, Tween.EASE_IN)
	$Tween.interpolate_callback(self, 0.5, "queue_free")
	$Tween.start()

	if focussedPanel:
		focussedPanel.release_focus()
	focussedPanel = null

func buyUpgrade():
	if animationDone:
		find_child("TechTree").buyCurrentUpgrade()
		updateCostLabels()


func getRootTechs(techPanel) -> Dictionary:
	var allProps: = {}
	var rootTech = GameWorld.upgrades.get(techPanel.track.rootTechId)
	if rootTech and rootTech.has("propertychanges"):
		for prop in rootTech.propertychanges:
			if prop.hidden:
				continue
			allProps[prop.key] = prop

	return allProps

func removeHiddenProperties(techId: String, allProps: Dictionary) -> Dictionary:
	var newProps = {}

	for p in allProps:
		if not isHidden(techId, p):
			newProps[p] = allProps[p]

	return newProps

func isHidden(techId: String, property: String) -> bool:
	var tech = GameWorld.upgrades.get(techId)
	if not tech:
		return false

	if tech.has("propertychanges"):
		for p in tech.propertychanges:
			if p.key == property:
				return p.hidden

	if tech.has("predecessors"):
		var isHidden = true
		for pred in tech.predecessors:
			isHidden = isHidden and isHidden(pred, property)
		return isHidden

	return false

func getAncestors(techId: String) -> Array:
	var ancestors: = []

	var tech = GameWorld.upgrades.get(techId)


	if tech and not tech.has("predecessors"):
		return []

	if tech.tier == 2:
		for pred in tech.predecessors:
			if not ancestors.has(pred): ancestors.append(pred)
		return ancestors

	if tech.tier == 1:
		if not ancestors.has(tech.id): ancestors.append(tech.id)
		return ancestors

	for pred in tech.predecessors:
		if not ancestors.has(pred) and GameWorld.upgrades.has(pred):
			var ancestorPreds = getAncestors(pred)
			for ancestorPred in ancestorPreds:
				if not ancestors.has(ancestorPred):
					ancestors.append(ancestorPred)

	return ancestors


func getCoreProperties(ancestors: Array, techs: Dictionary, maxTier) -> Dictionary:
	var allProps = {}


	for a in ancestors:
		if not techs.has(a):
			continue

		var tech = GameWorld.upgrades.get(a)

		if techs[a].children.size():
			var childProps = getCoreProperties(techs[a].children, techs, maxTier)
			for p in childProps:
				allProps[p] = childProps[p]

		if tech and tech.has("propertychanges"):
			for p in tech.propertychanges:
				if p.hidden:
					continue
				if tech.has("repeatable"):
					continue
				allProps[p.key] = p

	return allProps

func _on_TechTree_techFocussed(techPanel) -> void :
	if not isIn:
		return

	find_child("TechTitle").text = techPanel.title
	find_child("TechDescription").text = tr(techPanel.explanationBb)


	var bonusSection = find_child("BonusSection")
	for c in bonusSection.get_children():
		c.free()


	var tech = GameWorld.upgrades.get(techPanel.techId)


	var ancestors: = getAncestors(techPanel.techId)
	var allProps: = getCoreProperties(ancestors, techPanel.track.techs, tech.tier)
	allProps = removeHiddenProperties(techPanel.techId, allProps)


	var thisProps: = []
	for prop in techPanel.propertyChanges:
		if prop.hidden:
			continue
		prop = prop.duplicate()
		allProps[prop.key] = prop
		thisProps.append(prop.key)





	var highlight = GameWorld.upgrades.get(techPanel.techId).tier != 0
	if tech and tech.has("repeatable"):
		highlight = true
	var rawTechId = techPanel.techId.split(".")[-1]
	var boughtByTeam = GameWorld.boughtUpgrades.has("%s.%s" % [techPanel.teamId, rawTechId])
	var boughtByPlayer = GameWorld.boughtUpgrades.has("%s.%s" % [techPanel.playerId, rawTechId])
	var alreadyBought = boughtByPlayer or boughtByTeam


	var regex = RegEx.new()
	regex.compile("\\{.*\\}[^\\s]*")
	var regex2 = RegEx.new()
	regex2.compile("\\{.*\\}")


	var sortedKeys = allProps.keys()
	sortedKeys.sort()

	for p in sortedKeys:
		var propertyChange = allProps[p]
		if propertyChange.hidden:
			continue

		var outString = null
		var statString: = ""
		var newValueString: = ""
		var translationKey: String
		if propertyChange.key.count(".") == 2:
			translationKey = "properties." + propertyChange.key.substr(propertyChange.key.find(".") + 1)
		else:
			translationKey = "properties." + propertyChange.key
		var template = tr(translationKey)
		if template != translationKey:
			var result = regex.search(template)
			if not result or result.strings.is_empty():

				outString = template




				if not thisProps.has(propertyChange.key):
					continue
			else:

				var placeholder = result.strings[0]
				var after
				var before
				var replacement: = ""
				var unit: = ""
				var dotPos = placeholder.find(".")
				var isPercent = placeholder.find(".percent") != -1


				outString = regex.sub(template, "").strip_edges()
				outString = outString.replace("  ", " ")

				var beforeAfter = getBeforeAfterValues(propertyChange, tech.id)
				before = beforeAfter["before"]
				after = beforeAfter["after"]


				if dotPos > 1:
					unit = placeholder.substr(1, dotPos - 1)


				if isPercent:
					after = int(after * 100)
					unit = "%"
					if before and not propertyChange.multiplicative:
						before = int(before * 100)


				if (typeof(before) == TYPE_INT or typeof(before) == TYPE_FLOAT):
					var valueTemplate: String
					if before == int(before):
						valueTemplate = "%d"
					else:
						valueTemplate = "%0.2f"

					if propertyChange.multiplicative:
						replacement += valueTemplate % [before]
					else:
						replacement += valueTemplate % [before] + unit

					if highlight and thisProps.has(propertyChange.key):
						statString = regex2.sub(placeholder, replacement)


				if alreadyBought and not is_repeatable(tech):
					statString = ""
					highlight = false
					after = Data.of(Utils.get_full_upgrade_id(propertyChange.key, teamId, playerId))
					if isPercent:
						after = int(after * 100)
						unit = "%"

				if after == int(after):
					replacement = "%d" % after
				else:
					replacement = "%0.2f" % after
				replacement = regex2.sub(placeholder, replacement)
				newValueString += replacement + unit


			var icon = TextureRect.new()
			icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			bonusSection.add_child(icon)

			var label: Label = Label.new()
			label.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT
			label.autowrap_mode = TextServer.AutowrapMode.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = SIZE_EXPAND_FILL
			label.text = outString
			label.add_to_group(FontScaler.GROUP)
			bonusSection.add_child(label)

			var labelStat = Label.new()
			labelStat.text = str(statString)
			labelStat.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
			labelStat.add_to_group(FontScaler.GROUP)
			bonusSection.add_child(labelStat)

			if statString:
				var changeIcon = TextureRect.new()
				changeIcon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				changeIcon.texture = load("res://content/techtree/common/change-icon.png")
				bonusSection.add_child(changeIcon)
			else:
				bonusSection.add_child(Control.new())

			var labelNew = Label.new()
			labelNew.text = str(newValueString)
			labelNew.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT
			labelNew.add_to_group(FontScaler.GROUP)
			bonusSection.add_child(labelNew)



			if highlight and thisProps.has(propertyChange.key):
				var markerColor = Style.mapColor(Color("D89DDC"))
				label.set("theme_override_colors/font_color", markerColor)
				labelStat.set("theme_override_colors/font_color", markerColor)
				labelNew.set("theme_override_colors/font_color", markerColor)
				icon.texture = preload("res://content/techtree/common/star.png")
			else:
				icon.texture = preload("res://content/techtree/common/dot.png")

			Style.init(bonusSection)

	focussedPanel = techPanel
	updateCostLabels()

func is_repeatable(tech) -> bool:
	if not tech.has("repeatable"):
		return false

	var repeatableTimes = -1
	for change in tech.get("repeatable"):
		if change.keyClass == "times":
			repeatableTimes = change.value
	return repeatableTimes != 0






func getBeforeAfterValues(propertyChange, techId):
	var before = null
	var after = null
	var values = getPropertyValue(propertyChange.key, techId)

	if not propertyChange.doesRepair:
		before = values["before"]
	after = values["after"]

	return {"before": before, "after": after}

const MAX_DEPTH: = 4

func get_predecessor_from_active_path(predecessors):


	var best_pred = null
	var best_depth: = -1
	for pred in predecessors:
		var d: = _depth_to_bought(pred)
		if d == -1:
			continue
		if best_depth == -1 or d < best_depth:
			best_depth = d
			best_pred = pred

	return best_pred

func _depth_to_bought(upgrade_id, depth: = 0) -> int:
	if GameWorld.boughtUpgrades.has(upgrade_id):
		return 0
	var upgrade = GameWorld.upgrades.get(upgrade_id)
	if depth >= MAX_DEPTH:
		return -1
	var best: = -1
	if not upgrade.get("predecessors", []).is_empty():
		for pred in upgrade["predecessors"]:
			var d: = _depth_to_bought(pred, depth + 1)
			if d != -1 and (best == -1 or d < best):
				best = d
	return -1 if best == -1 else best + 1

func getPropertyValue(propertyKey, techId, depth = 0):
	var tech = GameWorld.upgrades.get(techId)

	var full_property_key: = Utils.get_full_upgrade_id(propertyKey, teamId, playerId)
	if not tech.has("repeatable") and (GameWorld.boughtUpgrades.has(techId) or not tech.has("predecessors")):
		return {"before": null, "after": Data.of(full_property_key)}

	if not tech["predecessors"].is_empty():

		var target = null
		for x in tech["predecessors"]:
			if GameWorld.boughtUpgrades.has(x):
				target = x
				break
		if not target:
			target = get_predecessor_from_active_path(tech["predecessors"])

		var values = getPropertyValue(propertyKey, target)
		values["before"] = values["after"]

		if tech and tech.has("propertychanges"):
			for prop in tech["propertychanges"]:
				if prop.key == propertyKey:
					if prop.cumulative:
						values["after"] += prop.value
					elif prop.multiplicative:
						values["after"] *= prop.value
					else:
						values["after"] = prop.value

		return values

	Logger.error("invalid state of property, can't find before and after values", "TechTreePopup.getPropertyValue", {"propertyKey": propertyKey, "techId": techId, "depth": depth})
	return {"before": "error", "after": "error"}

func updateCostLabels():
	find_child("LabelIronCost").text = ""
	find_child("LabelWaterCost").text = ""
	find_child("LabelSandCost").text = ""

	if not focussedPanel:
		return

	var upgrade = GameWorld.upgrades[focussedPanel.techId]
	var costs = upgrade.get("cost", [])
	for costType in costs:
		var cost = costs[costType]
		var newInventory = int(Data.getInventory(costType, teamId)) - int(cost)
		var color = defaultFontColor
		if GameWorld.boughtUpgrades.has(focussedPanel.techId) and not upgrade.has("repeatable"):
			newInventory = 0
		if newInventory < 0:
			color = Style.FONT_COLOR_WARNING
		find_child("Label" + costType.capitalize() + "Cost").text = "%s" % cost
		find_child("Label" + costType.capitalize() + "Cost").label_settings.font_color = color
