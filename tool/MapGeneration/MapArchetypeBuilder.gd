extends Node2D






var viability_large_noise_strength = 60 + randf() * 60
var viability_small_noise_strength = 10 + randf() * 50
var depth = 30 + randf() * 70
var viability_stop_width_factor = 0.2 - randf() * 0.15

var threads: = []
var generating: = false

var minI: = 99999999
var maxI: = 0
var allI: = 0
var minW: = 99999999
var maxW: = 0
var allW: = 0
var minC: = 99999999
var maxC: = 0
var allC: = 0
var minR: = 99999999
var maxR: = 0
var allR: = 0
var minS: = 99999999
var maxS: = 0
var allS: = 0
var hardness: Array
var hardnessMin: Array
var hardnessMax: Array
var count: = 0
var boxIndex: = 0
var pastArchetypes: = []
var pastTileData: = []
var accumulatingTileData: Array

func _ready():
	Platform.init(true)
	Engine.max_fps = 60
	find_child("MapCountLabel").text = str(find_child("MapCountSlider").value)
	find_child("DepthLabel").text = str(find_child("DepthSlider").value)
	find_child("ResourcesButton").button_pressed = find_child("Resources").visible
	find_child("BiomeButton").button_pressed = find_child("Biome").visible
	find_child("ViabilityButton").button_pressed = find_child("Viability").visible
	find_child("SelectArchetypePopup").visible = false
	find_child("SaveArchetypePopup").visible = false

	var i = preload("res://content/shared/MoveCameraInput.gd").new()
	i.camera = $Camera2D
	i.integrate(self)

	if ResourceLoader.exists("user://arch.tres"):
		var r = ResourceLoader.load("user://arch.tres", "", ResourceLoader.CacheMode.CACHE_MODE_IGNORE)
		setArchetype(r)


func get_next_seed():
	if %FixedSeed.button_pressed:
		return 0
	return randi()

func runGeneration():
	if find_child("RunGenerationButton").disabled:
		Audio.sound("gui_err")
		return

	for generator in $Generators.get_children().duplicate():
		$Generators.remove_child(generator)
		generator.queue_free()
	for tileData in $TileData.get_children():
		$TileData.remove_child(tileData)

	minI = 99999999
	maxI = 0
	allI = 0
	minW = 99999999
	maxW = 0
	allW = 0
	minC = 99999999
	maxC = 0
	allC = 0
	minS = 99999999
	maxS = 0
	allS = 0
	hardness = [0, 0, 0, 0, 0, 0]
	hardnessMin = [999999, 999999, 999999, 999999, 999999, 999999]
	hardnessMax = [0, 0, 0, 0, 0, 0]
	count = 0
	accumulatingTileData = []

	Audio.sound("gui_select")
	find_child("RunGenerationButton").disabled = true
	find_child("RunGenerationSingle").disabled = true
	generating = true

	for _i in find_child("MapCountSlider").value:
		var thread = Thread.new()
		var generator = preload("res://content/map/generation/TileDataGenerator.tscn").instantiate(1)
		generator.init(getArchetype(), get_next_seed(), "team1")
		var status: int = thread.start(generateThreaded.bind(generator))
		threads.append(thread)

func runGenerationSingle():
	for generator in $Generators.get_children().duplicate():
		$Generators.remove_child(generator)
		generator.queue_free()
	for tileData in $TileData.get_children():
		$TileData.remove_child(tileData)

	minI = 99999999
	maxI = 0
	allI = 0
	minW = 99999999
	maxW = 0
	allW = 0
	minC = 99999999
	maxC = 0
	allC = 0
	minS = 99999999
	maxS = 0
	allS = 0
	hardness = [0, 0, 0, 0, 0, 0]
	hardnessMin = [999999, 999999, 999999, 999999, 999999, 999999]
	hardnessMax = [0, 0, 0, 0, 0, 0]
	count = 0
	accumulatingTileData = []

	Audio.sound("gui_select")

	var generator = preload("res://content/map/generation/TileDataGenerator.tscn").instantiate(1)
	generator.init(getArchetype(), get_next_seed())
	generator.generate()
	generator.logReportToOutput()
	var t1 = generator.popTileData()

	var md: MapData
	if %CheckBoxDoubleMaps.button_pressed:
		var t2: MapData = null
		if not %CheckBoxMirrorMaps.button_pressed:
			generator = preload("res://content/map/generation/TileDataGenerator.tscn").instantiate(1)
			generator.init(getArchetype(), get_next_seed())
			generator.generate()
			generator.logReportToOutput()
			t2 = generator.popTileData()

		generator = preload("res://content/map/generation/TileDataGenerator.tscn").instantiate(1)
		generator.init(getArchetype(), get_next_seed())
		md = generator.merge_tiledata(t1, t2)
	else:
		md = t1

	$TileData.add_child(md)
	updateLayerVisibility(md)
	addMetaInfoToTileData(md)

func generateThreaded(generator):
	generator.generate()
	return generator

func getArchetype() -> MapArchetype:
	var archetype = MapArchetype.new()
	archetype.viabilityLargeRange = Vector3(float(find_child("FieldViabilityLargeBase").text), float(find_child("FieldViabilityLargeDelta").text), float(find_child("FieldViabilityLargeExponent").text))
	archetype.viabilitySmallRange = Vector3(float(find_child("FieldViabilitySmallBase").text), float(find_child("FieldViabilitySmallDelta").text), float(find_child("FieldViabilitySmallExponent").text))
	archetype.viability_base = float(find_child("ViabilityBase").text)

	archetype.stop_depth_at_fraction = float(find_child("FieldStopDepthStart").text)
	archetype.stop_depth_factor = float(find_child("FieldStopDepthFactor").text)
	archetype.stop_depth_exponent = float(find_child("FieldStopDepthExponent").text)
	archetype.stop_width_at_fraction = float(find_child("FieldStopWidthStart").text)
	archetype.stop_width_factor = float(find_child("FieldStopWidthFactor").text)
	archetype.stop_width_exponent = float(find_child("FieldStopWidthExponent").text)

	archetype.keep_core_strength = float(find_child("FieldKeepCoreStrength").text)
	archetype.keep_core_falloff_y = float(find_child("FieldKeepCoreFalloffY").text)

	archetype.entry_tightening_until = float(find_child("FieldTightEntryUntil").text)
	archetype.entry_tightening_y_exp = float(find_child("FieldTightEntryExpY").text)
	archetype.entry_tightening_x_exp = float(find_child("FieldTightEntryExpX").text)
	archetype.thin_top_factor = float(find_child("FieldThinTop").text)

	archetype.iron_cluster_size_base = float(find_child("FieldIronClusterSizeBase").text)
	archetype.iron_cluster_size_per_y = float(find_child("FieldIronClusterSizePerY").text)
	archetype.iron_cluster_size_randomness = float(find_child("FieldIronClusterSizeRandomness").text)

	archetype.first_biome_size = int(float( %FirstBiomeSize.text))
	archetype.biome_max_size = int(float( %BiomeMaxSize.text))
	archetype.biome_size_multiplier = int(float( %BiomeSizeMultiplier.text))
	archetype.biome_size_addition = int(float( %BiomeSizeAddition.text))
	archetype.biome_cleanup_passes = int(float( %BiomeCleanupPasses.text))

	archetype.depth = int(find_child("DepthSlider").value)
	archetype.width = int(find_child("WidthSlider").value)
	archetype.tileCount = int(find_child("TileCount").text)

	archetype.generateResources = find_child("GenerateResourcesCheckBox").button_pressed
	archetype.iron_cluster_rate = float(find_child("IronRate").text)
	archetype.water_rate = float(find_child("WaterRate").text)
	archetype.cobalt_rate = float(find_child("CobaltRate").text)
	archetype.iron_cluster_removal_rate = float(find_child("IronRemoval").text)
	archetype.water_removal_rate = float(find_child("WaterRemoval").text)
	archetype.cobalt_removal_rate = float(find_child("CobaltRemoval").text)

	archetype.relics = int(find_child("FieldRelicAmount").text)
	archetype.relic_first_depth = float(find_child("FieldRelicStartY").text)
	archetype.relic_depth_step = float(find_child("FieldRelicStepY").text)

	archetype.relic_switches = int(find_child("FieldRelicSwitchAmount").text)
	archetype.relic_switch_distance_range = Vector2(float(find_child("FieldRelicSwitchMinD").text), float(find_child("FieldRelicSwitchMaxD").text))

	archetype.gadgets = int(find_child("FieldGadgetAmount").text)
	archetype.gadget_first_depth = float(find_child("FieldGadgetStartY").text)
	archetype.gadget_depth_step = float(find_child("FieldGadgetStepY").text)

	archetype.powercores = int(find_child("FieldPowercoreAmount").text)
	archetype.powercore_first_depth = float(find_child("FieldPowercoreStartY").text)
	archetype.powercore_depth_step = float(find_child("FieldPowercoreStepY").text)

	archetype.hardness_offset = float(find_child("FieldHardnessOffset").text)
	archetype.hardness_min = int(find_child("FieldHardnessMin").text)
	archetype.hardness_max = int(find_child("FieldHardnessMax").text)
	archetype.hardness_scale = float(find_child("FieldHardnessScale").text)

	archetype.hole_size_base = float(find_child("FieldHoleSizeBase").text)
	archetype.hole_size_per_biome = float(find_child("FieldHoleSizePerY").text)
	archetype.hole_size_randomness = float(find_child("FieldHoleSizeRandom").text)
	archetype.holes_per_biome = int(find_child("FieldHolesPerBiome").text)
	archetype.holes_per_biome_randomness = float(find_child("FieldHolesPerBiomeRandomness").text)

	var res = load("res://content/map/generation/noises/" + %LargeNoiseName.text)
	archetype.viability_large_noise = res

	res = load("res://content/map/generation/noises/" + %SmallNoiseName.text)
	archetype.viability_small_noise = res

	archetype.ensureNoiseExists()

	return archetype

func setArchetype(archetype: MapArchetype):
	find_child("ViabilityBase").text = str(archetype.viability_base)

	find_child("FieldStopDepthStart").text = str(archetype.stop_depth_at_fraction)
	find_child("FieldStopDepthFactor").text = str(archetype.stop_depth_factor)
	find_child("FieldStopDepthExponent").text = str(archetype.stop_depth_exponent)
	find_child("FieldStopWidthStart").text = str(archetype.stop_width_at_fraction)
	find_child("FieldStopWidthFactor").text = str(archetype.stop_width_factor)
	find_child("FieldStopWidthExponent").text = str(archetype.stop_width_exponent)

	find_child("FieldTightEntryUntil").text = str(archetype.entry_tightening_until)
	find_child("FieldTightEntryExpY").text = str(archetype.entry_tightening_y_exp)
	find_child("FieldTightEntryExpX").text = str(archetype.entry_tightening_x_exp)
	find_child("FieldThinTop").text = str(archetype.thin_top_factor)

	find_child("FieldKeepCoreStrength").text = str(archetype.keep_core_strength)
	find_child("FieldKeepCoreFalloffY").text = str(archetype.keep_core_falloff_y)

	find_child("FieldIronClusterSizeBase").text = str(archetype.iron_cluster_size_base)
	find_child("FieldIronClusterSizePerY").text = str(archetype.iron_cluster_size_per_y)
	find_child("FieldIronClusterSizeRandomness").text = str(archetype.iron_cluster_size_randomness)

	%FirstBiomeSize.text = str(archetype.first_biome_size)
	%BiomeMaxSize.text = str(archetype.biome_max_size)
	%BiomeSizeMultiplier.text = str(archetype.biome_size_multiplier)
	%BiomeSizeAddition.text = str(archetype.biome_size_addition)
	%BiomeCleanupPasses.text = str(archetype.biome_cleanup_passes)

	find_child("DepthSlider").value = archetype.depth
	find_child("WidthSlider").value = archetype.width
	find_child("TileCount").text = str(archetype.tileCount)

	find_child("GenerateResourcesCheckBox").button_pressed = archetype.generateResources
	find_child("IronRate").text = str(archetype.iron_cluster_rate)
	find_child("WaterRate").text = str(archetype.water_rate)
	find_child("CobaltRate").text = str(archetype.cobalt_rate)
	find_child("IronRemoval").text = str(archetype.iron_cluster_removal_rate)
	find_child("WaterRemoval").text = str(archetype.water_removal_rate)
	find_child("CobaltRemoval").text = str(archetype.cobalt_removal_rate)

	find_child("FieldRelicAmount").text = str(archetype.relics)
	find_child("FieldRelicStartY").text = str(archetype.relic_first_depth)
	find_child("FieldRelicStepY").text = str(archetype.relic_depth_step)

	find_child("FieldRelicSwitchAmount").text = str(archetype.relic_switches)
	find_child("FieldRelicSwitchMinD").text = str(archetype.relic_switch_distance_range.x)
	find_child("FieldRelicSwitchMaxD").text = str(archetype.relic_switch_distance_range.y)

	find_child("FieldGadgetAmount").text = str(archetype.gadgets)
	find_child("FieldGadgetStartY").text = str(archetype.gadget_first_depth)
	find_child("FieldGadgetStepY").text = str(archetype.gadget_depth_step)

	find_child("FieldPowercoreAmount").text = str(archetype.powercores)
	find_child("FieldPowercoreStartY").text = str(archetype.powercore_first_depth)
	find_child("FieldPowercoreStepY").text = str(archetype.powercore_depth_step)

	find_child("FieldViabilityLargeBase").text = str(archetype.viabilityLargeRange.x)
	find_child("FieldViabilityLargeDelta").text = str(archetype.viabilityLargeRange.y)
	find_child("FieldViabilityLargeExponent").text = str(archetype.viabilityLargeRange.z)

	find_child("FieldViabilitySmallBase").text = str(archetype.viabilitySmallRange.x)
	find_child("FieldViabilitySmallDelta").text = str(archetype.viabilitySmallRange.y)
	find_child("FieldViabilitySmallExponent").text = str(archetype.viabilitySmallRange.z)

	find_child("FieldHardnessOffset").text = str(archetype.hardness_offset)
	find_child("FieldHardnessMin").text = str(archetype.hardness_min)
	find_child("FieldHardnessMax").text = str(archetype.hardness_max)
	find_child("FieldHardnessScale").text = str(archetype.hardness_scale)

	find_child("FieldHoleSizeBase").text = str(archetype.hole_size_base)
	find_child("FieldHoleSizePerY").text = str(archetype.hole_size_per_biome)
	find_child("FieldHoleSizeRandom").text = str(archetype.hole_size_randomness)
	find_child("FieldHolesPerBiome").text = str(archetype.holes_per_biome)
	find_child("FieldHolesPerBiomeRandomness").text = str(archetype.holes_per_biome_randomness)

	var i = "res://content/map/generation/noises/".length()
	%LargeNoiseName.text = archetype.viability_large_noise.resource_path.substr(i)
	%SmallNoiseName.text = archetype.viability_small_noise.resource_path.substr(i)

func _process(delta):
	if Input.is_action_just_pressed("cheats"):
		Audio.sound("gui_hover")
		find_child("Controls").visible = not find_child("Controls").visible

	if Input.is_action_just_pressed("f2"):
		runGeneration()
	if Input.is_action_just_pressed("f3"):
		runGenerationSingle()

	if generating:
		for thread in threads.duplicate():
			if not thread.is_alive():
				var generator = thread.wait_to_finish()
				generator.logReportToOutput()
				var children = $TileData.get_children()
				var tileData = generator.popTileData()
				$TileData.add_child(tileData)
				updateLayerVisibility(tileData)
				accumulatingTileData.append(tileData)
				count += 1
				if children.size() > 0:
					var lastMap = children.back()
					tileData.position = lastMap.position
					var x = lastMap.getMapSizePx().x + 100
					tileData.position.x += x
					if tileData.position.x > sqrt(find_child("MapCountSlider").value) * x:
						tileData.position.x = 0
						tileData.position.y += lastMap.getMapSizePx().y + 600

				addMetaInfoToTileData(tileData)
				threads.erase(thread)
		if threads.size() == 0:
			generating = false
			find_child("RunGenerationButton").disabled = false
			find_child("RunGenerationSingle").disabled = false
			Audio.sound("gui_title_credits")

			var totalBox = VBoxContainer.new()
			totalBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			totalBox.theme = preload("res://gui/theme.tres")
			totalBox.scale *= 2
			var l = Label.new()
			l.text = "Size: " + str(minS) + " ~ " + ("%.0f" % (allS / float(count))) + " ~ " + str(maxS)
			totalBox.add_child(l)
			l = Label.new()
			l.text = "Iron: " + str(minI) + " ~ " + ("%.0f" % (allI / float(count))) + " ~ " + str(maxI)
			totalBox.add_child(l)
			l = Label.new()
			l.text = "Water: " + str(minW) + " ~ " + ("%.0f" % (allW / float(count))) + " ~ " + str(maxW)
			totalBox.add_child(l)
			l = Label.new()
			l.text = "Cobalt: " + str(minC) + " ~ " + ("%.0f" % (allC / float(count))) + " ~ " + str(maxC)
			totalBox.add_child(l)
			l = Label.new()
			l.text = "Resources: " + str(minR) + " ~ " + ("%.0f" % (allR / float(count))) + " ~ " + str(maxR)
			totalBox.add_child(l)
			var grid: = GridContainer.new()
			grid.columns = 2
			l = Label.new()
			l.text = "Hardness 1: "
			grid.add_child(l)
			l = Label.new()
			l.text = "%5.0f" % hardnessMin[0] + " ~ " + "%5.0f" % (hardness[0] / float(count)) + " ~ " + "%5.0f" % hardnessMax[0]
			grid.add_child(l)
			l = Label.new()
			l.text = "Hardness 2: "
			grid.add_child(l)
			l = Label.new()
			l.text = "%5.0f" % hardnessMin[1] + " ~ " + "%5.0f" % (hardness[1] / float(count)) + " ~ " + "%5.0f" % hardnessMax[1]
			grid.add_child(l)
			l = Label.new()
			l.text = "Hardness 3: "
			grid.add_child(l)
			l = Label.new()
			l.text = "%5.0f" % hardnessMin[2] + " ~ " + "%5.0f" % (hardness[2] / float(count)) + " ~ " + "%5.0f" % hardnessMax[2]
			grid.add_child(l)
			l = Label.new()
			l.text = "Hardness 4: "
			grid.add_child(l)
			l = Label.new()
			l.text = "%5.0f" % hardnessMin[3] + " ~ " + "%5.0f" % (hardness[3] / float(count)) + " ~ " + "%5.0f" % hardnessMax[3]
			grid.add_child(l)
			l = Label.new()
			l.text = "Hardness 5: "
			grid.add_child(l)
			l = Label.new()
			l.text = "%5.0f" % hardnessMin[4] + " ~ " + "%5.0f" % (hardness[4] / float(count)) + " ~ " + "%5.0f" % hardnessMax[4]
			grid.add_child(l)
			l = Label.new()
			l.text = "Border Tiles: "
			grid.add_child(l)
			l = Label.new()
			l.text = "%5.0f" % hardnessMin[5] + " ~ " + "%5.0f" % (hardness[5] / float(count)) + " ~ " + "%5.0f" % hardnessMax[5]
			grid.add_child(l)
			totalBox.add_child(grid)
			totalBox.position.y = -1100
			totalBox.position.x = boxIndex * 1000

			var button = Button.new()
			button.text = "load"
			pastArchetypes.append(getArchetype())
			pastTileData.append(accumulatingTileData)
			button.focus_mode = Control.FOCUS_NONE
			button.connect("pressed", Callable(self, "loadRun").bind(boxIndex))
			boxIndex += 1
			totalBox.add_child(button)
			add_child(totalBox)

func addMetaInfoToTileData(tileData):
	var box = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.theme = preload("res://gui/theme.tres")
	box.scale *= 2
	var l = Label.new()
	var size = tileData.get_mineable_tile_count()
	if size < 100:
		return
	minS = min(minS, size)
	maxS = max(maxS, size)
	allS += size
	l.text = "Size: " + str(tileData.getSize().x) + " x " + str(tileData.getSize().y) + " = " + str(size) + " cells"
	box.add_child(l)
	l = Label.new()
	var iron = tileData.get_resource_cells_by_id(0).size()
	minI = min(minI, iron)
	maxI = max(maxI, iron)
	allI += iron
	l.text = "Iron: " + str(iron)
	box.add_child(l)
	l = Label.new()
	var water = tileData.get_resource_cells_by_id(1).size()
	minW = min(minW, water)
	maxW = max(maxW, water)
	allW += water
	l.text = "Water: " + str(water)
	box.add_child(l)
	l = Label.new()
	var cobalt = tileData.get_resource_cells_by_id(2).size()
	minC = min(minC, cobalt)
	maxC = max(maxC, cobalt)
	allC += cobalt
	l.text = "Cobalt: " + str(cobalt)
	box.add_child(l)
	l = Label.new()
	var res = iron * 2 + cobalt * 2 + water * 2.5
	minR = min(minR, res)
	maxR = max(maxR, res)
	allR += res
	l.text = "Resources: " + str(res)
	box.add_child(l)
	l = Label.new()
	var h0 = tileData.get_hardness_cells_by_grade(0).size()
	var h1 = tileData.get_hardness_cells_by_grade(1).size()
	var h2 = tileData.get_hardness_cells_by_grade(2).size()
	var h3 = tileData.get_hardness_cells_by_grade(3).size()
	var h4 = tileData.get_hardness_cells_by_grade(4).size()
	var h5 = tileData.get_hardness_cells_by_grade(5).size()
	hardness[0] += h0
	hardness[1] += h1
	hardness[2] += h2
	hardness[3] += h3
	hardness[4] += h4
	hardness[5] += h5
	hardnessMin[0] = min(h0, hardnessMin[0])
	hardnessMin[1] = min(h1, hardnessMin[1])
	hardnessMin[2] = min(h2, hardnessMin[2])
	hardnessMin[3] = min(h3, hardnessMin[3])
	hardnessMin[4] = min(h4, hardnessMin[4])
	hardnessMin[5] = min(h5, hardnessMin[5])
	hardnessMax[0] = max(h0, hardnessMax[0])
	hardnessMax[1] = max(h1, hardnessMax[1])
	hardnessMax[2] = max(h2, hardnessMax[2])
	hardnessMax[3] = max(h3, hardnessMax[3])
	hardnessMax[4] = max(h4, hardnessMax[4])
	hardnessMax[5] = max(h5, hardnessMax[5])
	l.text = "Hardness: " + str(h0) + " - " + str(h1) + " - " + str(h2) + " - " + str(h3) + " - " + str(h4) + " - " + str(h5)
	box.add_child(l)

	l = Label.new()
	l.text = "Biome Sizes "
	for i in range(0, 30):
		var amount = tileData.get_biome_cells_by_index(i).size()
		if amount > 0:
			l.text += str(i) + ": " + str(amount) + "  |  "
	box.add_child(l)

	box.position.y = tileData.getMapSizePx().y
	box.position.x = -200
	tileData.add_child(box)

func loadRun(i: int):
	setArchetype(pastArchetypes[i])
	for tileData in $TileData.get_children():
		$TileData.remove_child(tileData)
	for tileData in pastTileData[i]:
		$TileData.add_child(tileData)
		updateLayerVisibility(tileData)

func _on_RunGenerationButton_pressed():
	runGeneration()

func _on_RunGenerationSingle_pressed():
	runGenerationSingle()

func _on_MapCountSlider_value_changed(value):
	find_child("MapCountLabel").text = str(value)

func _on_DepthSlider_value_changed(value):
	find_child("DepthLabel").text = str(value)

func _on_WidthSlider_value_changed(value):
	find_child("WidthLabel").text = str(value)

func _on_SaveButton_pressed():
	find_child("SaveArchetypePopup").visible = true
	find_child("SelectArchetypePopup").visible = false
	for c in find_child("SaveArchetypeList").get_children():
		if c is Button:
			c.queue_free()

	var dir = DirAccess.open("res://content/map/generation/archetypes")
	dir.list_dir_begin()
	var fileNames: = []
	while true:
		var fileName = dir.get_next()
		if fileName == "":
			break
		if fileName.ends_with(".tres"):
			fileNames.append(fileName)
	if not fileNames.has("arch.tres"):
		fileNames.append("arch.tres")
	for fileName in fileNames:
		var b: = Button.new()
		b.text = fileName.substr(0, fileName.find("."))
		b.connect("pressed", Callable(self, "saveArchetype").bind("res://content/map/generation/archetypes/" + fileName))
		find_child("SaveArchetypeList").add_child(b)

func saveArchetype(path: String):
	var result = ResourceSaver.save(getArchetype(), path)
	find_child("CurrentArchetypeLabel").text = path.substr(path.rfind("/") + 1)
	find_child("SaveArchetypePopup").visible = false

func _on_LoadButton_pressed():
	find_child("SelectArchetypePopup").visible = true
	find_child("SaveArchetypePopup").visible = false
	for c in find_child("ArchetypeList").get_children():
		if c is Button:
			c.queue_free()
	var dir = DirAccess.open("res://content/map/generation/archetypes")
	dir.list_dir_begin()
	while true:
		var fileName = dir.get_next()
		if fileName == "":
			break
		if fileName.ends_with(".tres"):
			var b: = Button.new()
			b.text = fileName.substr(0, fileName.find("."))
			b.connect("pressed", Callable(self, "loadArchetype").bind("res://content/map/generation/archetypes/" + fileName))
			find_child("ArchetypeList").add_child(b)


func loadArchetype(path: String):
	if ResourceLoader.exists(path):
		var r = ResourceLoader.load(path, "", ResourceLoader.CacheMode.CACHE_MODE_IGNORE)
		setArchetype(r)
		find_child("SelectArchetypePopup").visible = false
		find_child("CurrentArchetypeLabel").text = path.substr(path.rfind("/") + 1)

func _on_hardness_button_toggled(toggled_on: bool) -> void :
	for mapData: MapData in $TileData.get_children():
		updateLayerVisibility(mapData)

func _on_biomes_button_toggled(toggled_on: bool) -> void :
	for mapData: MapData in $TileData.get_children():
		updateLayerVisibility(mapData)

func _on_resources_button_toggled(toggled_on: bool) -> void :
	for mapData: MapData in $TileData.get_children():
		updateLayerVisibility(mapData)

func updateLayerVisibility(mapData):
	mapData.set_layer_modulate(mapData.LAYER_RESOURCES, Color(1, 1, 1, 0.5) if %ResourcesButton.button_pressed else Color.TRANSPARENT)
	mapData.set_layer_modulate(mapData.LAYER_BIOME, Color.WHITE if %BiomesButton.button_pressed else Color.TRANSPARENT)
	mapData.set_layer_modulate(mapData.LAYER_HARDNESS, Color(1, 1, 1, 0.5) if %HardnessButton.button_pressed else Color.TRANSPARENT)


func _on_CloseArchetypeButton_pressed():
	find_child("SelectArchetypePopup").visible = false

func _on_CloseSaveArchetypeButton_pressed():
	find_child("SaveArchetypePopup").visible = false

func _on_ClearRunsButton_pressed():
	pastArchetypes.clear()
	for i in pastTileData:
		for j in i:
			j.queue_free()
	pastTileData.clear()

	for c in get_children():
		if c is VBoxContainer:
			c.queue_free()

	boxIndex = 0

func _on_save_map_data_pressed() -> void :
	for md in $TileData.get_children():
		ResourceSaver.save(md.pack(), "res://content/map/data/TileDataGenerated.tscn")

func _on_set_large_noise_pressed():
	load_noise( func(x):
		%LargeNoiseName.text = x
		)

func _on_set_small_noise_pressed():
	load_noise( func(x):
		%SmallNoiseName.text = x
		)

func load_noise(callback: Callable):
	find_child("SelectArchetypePopup").visible = true
	find_child("SaveArchetypePopup").visible = false
	for c in find_child("ArchetypeList").get_children():
		if c is Button:
			c.queue_free()
	var dir = DirAccess.open("res://content/map/generation/noises")
	dir.list_dir_begin()
	while true:
		var fileName = dir.get_next()
		if fileName == "":
			break
		if fileName.ends_with(".tres"):
			var b: = Button.new()
			b.text = fileName.substr(0, fileName.find("."))
			b.pressed.connect( func():
				callback.call(fileName)
				find_child("SelectArchetypePopup").visible = false
				)
			find_child("ArchetypeList").add_child(b)

func _on_biome_button_toggled(toggled_on: bool) -> void :
	Audio.sound("gui_move")
	%Biome.visible = toggled_on

func _on_ViabilityButton_toggled(button_pressed):
	Audio.sound("gui_move")
	%Viability.visible = button_pressed

func _on_resourcecontainer_button_toggled(toggled_on: bool) -> void :
	Audio.sound("gui_move")
	%Resources.visible = toggled_on
