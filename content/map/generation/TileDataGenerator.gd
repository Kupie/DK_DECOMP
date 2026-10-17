class_name TileDataGenerator extends Node2D

var viability_large_noise: FastNoiseLite
var viability_small_noise: FastNoiseLite
var hardness_noise: FastNoiseLite
var gen_seed: int

var a: MapArchetype

var doYields: = false
var finishedSuccessful: = false
var report: = ""
var report_contains_error = false
var report_timer_name: = []
var report_timer: = []
var maxBiome: = 0
var gen_stage: = 0.0
var rand: RandomNumberGenerator
var directions: Array
var diagonals: Array

const gadget_chamber_offset: = [Vector2(0, 0), Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]
const relic_chamber_offset: = [Vector2(0, 0), Vector2(-1, 0), Vector2(-1, 1), Vector2(0, -1), Vector2(1, -1), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(2, 0), Vector2(2, 1), Vector2(0, 2), Vector2(1, 2)]

var teamId: String = "team1"


var resourceMinY
var resourceX

var _mapData: MapData
var _borderMergeMutex: = Mutex.new()
var _invalid: bool = false
var _shapesMerged: bool = false
var _baseShapeReady: bool = false
var _baseShapeReadyMutex: Mutex = Mutex.new()
var _baseShapeReadySemaphore: Semaphore = Semaphore.new()

func _notification(what: int) -> void :
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_mapData = $MapData
	if what == NOTIFICATION_READY:
		if get_parent() == get_tree().root:
			init(preload("res://content/map/generation/archetypes/regular-small.tres"), randi(), teamId)
			generate()
			logReportToOutput()
			var cam = Camera2D.new()
			cam.zoom *= 5
			add_child(cam)
			cam.current = true

func init(archetype: MapArchetype, randSeed, inTeamId: String):
	self.a = archetype
	teamId = inTeamId
	_mapData.teamId = inTeamId
	viability_large_noise = a.viability_large_noise.duplicate()
	viability_small_noise = a.viability_small_noise.duplicate()
	hardness_noise = a.hardness_noise.duplicate()
	gen_seed = randSeed
	viability_large_noise.seed = gen_seed + 1
	viability_small_noise.seed = gen_seed + 2
	hardness_noise.seed = gen_seed + 3
	print("Viability: " + str(a.viability_large_noise_strength))

	directions = CONST.DIRECTIONS.duplicate()
	diagonals = CONST.DIAGONALS.duplicate()

func isInvalid() -> bool:
	return _invalid

func markAsInvalid() -> void :
	_invalid = true

func generate():
	if not viability_large_noise:
		return

	rand = RandomNumberGenerator.new()
	rand.seed = gen_seed

	_mapData.clear()

	reportLog("--- TILE DATA GENERATOR REPORT ---")
	reportLog("Width: " + str(a.width))
	reportLog("Depth: " + str(a.depth))
	reportLog("Target Tile Count: " + str(a.tileCount))
	reportLog("Noise Large: " + str(a.viability_large_noise.resource_path.get_file()))
	reportLog("Noise Small: " + str(a.viability_small_noise.resource_path.get_file()))
	reportLog("Seed:" + str(gen_seed))

	startTimer("total_generation")
	gen_stage = 1
	startTimer("base shape")

	var baseShape: = generate_base_shape()
	finishedSuccessful = not baseShape.is_empty()

	if not finishedSuccessful:
		reportError("generate_base_shape failed.")
		terminate_generation()
		return

	commit_2d_array_data_to_biomes(baseShape, false)
	endTimer()

	gen_stage = 2
	startTimer("biomes")
	finishedSuccessful = generate_biomes()
	endTimer()
	if not finishedSuccessful:
		reportError("generate_biomes failed.")
		terminate_generation()
		return

	gen_stage = 3
	startTimer("hardness")
	generate_hardness()
	endTimer()







	gen_stage = 4
	startTimer("border-1")
	generate_border_prepass()
	endTimer()

	if a.generateResources:
		startTimer("resources")
		generate_resources(rand)
		endTimer()

	var waitForShapeMerge: bool = a.double_dome_map and not a.mirror_double_map
	if waitForShapeMerge:
		_baseShapeReadyMutex.lock()
		_baseShapeReady = true
		_baseShapeReadyMutex.unlock()
		_baseShapeReadySemaphore.wait()

	startTimer("border-2")
	generate_border()
	endTimer()

	gen_stage = 5
	generate_fixed_entrance()

	endTimer()
	terminate_generation()

func isWaitingForBoundariesMerge() -> bool:
	_baseShapeReadyMutex.lock()
	var is_ready_for_boundaries_merge: bool = _baseShapeReady and not _shapesMerged
	_baseShapeReadyMutex.unlock()
	return is_ready_for_boundaries_merge

func resumeGenerationAfterBoundariesMerge() -> void :
	_baseShapeReadySemaphore.post()

func generate_resources(rand):
	var original_cell_coords: Array = _mapData.get_used_biome_cells()
	var borderCells = findOutsideBorderCells()

	for cell in _mapData.get_used_biome_cells():
		if _mapData.get_resourcev(cell) < 0:
			_mapData.set_resourcev(cell, Data.TILE_DIRT_START)

	Utils.shuffle(original_cell_coords, rand)
	gen_stage = 4.1
	startTimer("generate_iron_clusters")
	generate_iron_clusters(original_cell_coords, borderCells)
	endTimer()
	gen_stage = 4.2
	startTimer("generate_gadget_chambers")
	generate_gadget_chambers()
	endTimer()
	gen_stage = 4.3
	startTimer("generate_power_cores")
	generate_power_cores()
	endTimer()
	gen_stage = 4.4
	startTimer("generate_relics")
	generate_relics()
	endTimer()
	gen_stage = 4.5
	startTimer("adjust_ore_amounts")
	adjust_ore_amounts()
	endTimer()
	gen_stage = 4.6
	startTimer("expand_iron_clusters")
	var ironClusterCenters = _mapData.get_resource_cells_by_id(Data.TILE_IRON).duplicate()
	expand_iron_clusters(ironClusterCenters)
	endTimer()
	gen_stage = 4.7
	startTimer("generate_water")
	generate_water(ironClusterCenters, original_cell_coords, borderCells)
	endTimer()
	gen_stage = 4.8
	startTimer("generate_cobalt")
	generate_cobalt(ironClusterCenters, original_cell_coords, borderCells)
	endTimer()
	gen_stage = 4.9
	startTimer("generate_holes")
	var averageCellCountInBiome = a.tileCount / (maxBiome + 1)
	generate_holes(rand, averageCellCountInBiome)
	endTimer()

func terminate_generation():
	if report_contains_error:
		reportError("Generation produced error. Generation failed.")
	finishedSuccessful = finishedSuccessful and not report_contains_error
	reportLog("--- REPORT END ---")

func create2d_array_filled_with(cells, value):
	var arr = []
	var arrw = a.width * 2

	for x in arrw * a.depth * 2:
		arr.append(-1)

	for x in cells:
		arr[x.y * arrw + x.x + a.width] = value
	return arr

func commit_2d_array_data_to_biomes(arr, apply_all: bool):
	var arrw = a.width * 2

	for x in arr.size():
		if apply_all or arr[x] >= 0:
			_mapData.set_biomev(Vector2i(x % arrw - a.width, x / arrw), arr[x])


func calculate_biome_sizes() -> Array:
	var expected_sizes: = []
	var remainingTileCount = a.tileCount if a.tileCount > 0 else _mapData.get_used_biome_cells().size()
	var currentBiomeSize = a.first_biome_size
	expected_sizes.append(currentBiomeSize)
	remainingTileCount -= currentBiomeSize

	while remainingTileCount > 0:
		currentBiomeSize = clamp(currentBiomeSize * a.biome_size_multiplier + a.biome_size_addition, a.first_biome_size, a.biome_max_size)
		if remainingTileCount >= currentBiomeSize:
			remainingTileCount -= currentBiomeSize
			expected_sizes.append(currentBiomeSize)
		else:
			if remainingTileCount < 0.4 * currentBiomeSize:
				expected_sizes[expected_sizes.size() - 1] += remainingTileCount
			else:
				expected_sizes.append(remainingTileCount)
			remainingTileCount = 0

	return expected_sizes

func generate_biomes() -> bool:


	var expected_sizes = calculate_biome_sizes()

	maxBiome = expected_sizes.size() - 1
	var cells = _mapData.get_used_biome_cells()
	var count = cells.size()
	var arrw = a.width * 2

	var arr = create2d_array_filled_with(cells, 99)

	startTimer("biome-floodfill")


	var start_set: = []
	for x in arr.size():
		if arr[x] == 99:
			start_set.append(x)
			break


	for x in maxBiome + 1:
		floodfill(arr, start_set, expected_sizes[x], x, arrw)
		start_set = get_border_tiles_to(arr, x, arrw)
	endTimer()

	startTimer("biome-island-removal")
	clear_islands_smaller_than(arr, arrw, min(25, count / (maxBiome + 1) * 0.2))
	endTimer()

	startTimer("biome-cleanup-kernel")
	for x in a.biome_cleanup_passes:
		run_cleanup_kernel(arr, arrw)
	endTimer()

	startTimer("biome-fill-unreached")

	for x in arr.size():
		if arr[x] == 99:
			floodfill_to_closest(arr, x, arrw, 99)
	endTimer()


	for x in maxBiome + 1:
		var i = count_biome_size(arr, x)
		var deviation = float(i) / (expected_sizes[x])
		reportLog("Biome %s - size %s (deviation %s)" % [x, i, str("%0.2f" % abs(deviation - 1))])

	commit_2d_array_data_to_biomes(arr, false)

	return true

func clear_islands_smaller_than(map: Array, yoffset: int, size: int):
	var marked_map = map.duplicate()
	var c: = 0
	for x in map.size():
		if marked_map[x] >= 0 and marked_map[x] < 100:
			var island_size = flood_fill_count_and_repl(marked_map, [x], yoffset, map[x], 100 + c)
			c += 1
			if island_size > 0 and island_size <= size:
				floodfill_to_closest(map, x, yoffset, map[x])

func flood_fill_count_and_repl(map: Array, col: Array, yoffset: int, value: int, repl: int):
	var size: = 0
	while col.size() > 0:
		var e = col.pop_back()
		if e >= 0 and e < map.size() and map[e] == value:
			map[e] = repl
			size += 1
			col.append(e + 1)
			col.append(e - 1)
			col.append(e + yoffset)
			col.append(e - yoffset)
	return size

func count_biome_size(map: Array, value: int) -> int:
	var count: = 0
	for x in map.size():
		if map[x] == value:
			count += 1
	return count

func get_border_tiles_to(map: Array, value: int, yoffset: int) -> Array:
	var output: = []
	for x in map.size():
		if map[x] == value && x + yoffset < map.size():

			if x + 1 < map.size() and map[x + 1] == 99:
				output.append(x + 1)
			if x - 1 >= 0 and map[x - 1] == 99:
				output.append(x - 1)
			if map[x + yoffset] == 99:
				output.append(x + yoffset)

	return output

func run_cleanup_kernel(map: Array, yoffset: int):
	for x in map.size():
		var value = map[x]
		if value != -1 and value != 99:
			var u = map[x - yoffset] if x - yoffset >= 0 else -1
			var r = map[x + 1] if x + 1 < map.size() else -1
			var d = map[x + yoffset] if x + yoffset < map.size() else -1
			var l = map[x - 1] if x - 1 >= 0 else -1

			var ncount: = 0
			ncount += 1 if u == value else 0
			ncount += 1 if r == value else 0
			ncount += 1 if d == value else 0
			ncount += 1 if l == value else 0

			var bordercount: = 0
			bordercount += 1 if u == -1 else 0
			bordercount += 1 if r == -1 else 0
			bordercount += 1 if d == -1 else 0
			bordercount += 1 if l == -1 else 0


			if bordercount == 0 and ncount < 2:
				map[x] = 99





func floodfill_to_closest(map: Array, element: int, yoffset: int, to_repl: int):
	var col: = [element]
	var out: = []
	var value: = 0
	while (col.size() > 0):
		var e = col.pop_front()

		if e < 0 or e >= map.size():
			continue
		if map[e] == to_repl:
			map[e] = -2
			out.append(e)
			col.append(e + 1)
			col.append(e - 1)
			col.append(e + yoffset)
			col.append(e - yoffset)
		elif map[e] >= 0:
			value = map[e]

	for x in out:
		map[x] = value

func floodfill(map: Array, col: Array, amount: int, value: int, yoffset: int):
	while (col.size() > 0 and amount > 0):
		var e = col.pop_at(rand.randi_range(0, col.size() - 1))

		if e < 0 or e >= map.size():
			continue
		if map[e] != 99:
			continue

		map[e] = value
		amount -= 1
		col.append(e + 1)
		col.append(e - 1)
		col.append(e + yoffset)
		col.append(e - yoffset)

func generate_base_shape() -> Array:

	var closestSize: = 0
	var startDepthReductionAt = round(a.depth * float(a.stop_depth_at_fraction))
	var depthReductionLength = a.depth - startDepthReductionAt

	var startWidthReductionAt = round(float(a.width) * 0.5 * float(a.stop_width_at_fraction))
	var widthReductionLength = 0.5 * a.width - startWidthReductionAt

	var stopTighteningAt = round(float(a.depth) * float(a.entry_tightening_until))
	var viabilityTileCountModifier: float = 0.0

	var arr = create2d_array_filled_with([], 0)

	var sizeIterations: = 1
	if a.tileCount > 0:
		sizeIterations = 10

	for i in sizeIterations:
		gen_stage = 1 + i * 0.01

		for x in range( - a.width, a.width):
			var absX = abs(x)
			var stopWidth: = pow(a.stop_width_factor * (max(0, (absX - startWidthReductionAt))) / widthReductionLength, a.stop_width_exponent)
			for y in range(0, a.depth * 2.0):
				var n1 = viability_large_noise.get_noise_2d(x, y)
				var n2 = viability_small_noise.get_noise_2d(x, y)

				var stopDepth: = pow(a.stop_depth_factor * (max(0, (y - startDepthReductionAt))) / depthReductionLength, a.stop_depth_exponent)


				var tighteningYFraction = max(0, (stopTighteningAt - y)) / stopTighteningAt
				var startTightening = pow(tighteningYFraction, a.entry_tightening_y_exp) * pow(absX, a.entry_tightening_x_exp)


				var thinTopFraction = max(0, pow(max(0, 10 - y), 3) - pow(max(0, a.thin_top_factor - absX), 2))


				var keepCore = max(0, max(0, a.keep_core_strength * (a.width - pow(absX, 2))) - pow(max(0, (y - a.depth * a.keep_core_falloff_y)), 2))

				var viability = a.viability_base + a.viability_large_noise_strength * n1 + a.viability_small_noise_strength * n2
				viability -= stopWidth
				viability -= stopDepth
				viability -= startTightening
				viability -= thinTopFraction
				viability += keepCore
				viability += viabilityTileCountModifier

				arr[a.width + x + y * a.width * 2] = -1 if viability < 0 else 99




		var arrw = a.width * 2
		var startidx = a.width
		var size = flood_fill_count_and_repl(arr, [startidx], arrw, 99, 0)

		for x in arr.size():
			if arr[x] == 99:
				arr[x] = -1



		var diff = a.tileCount - size
		if abs(diff) < max(60, a.tileCount * a.max_tile_count_deviation):
			reportLog("Generated Tile Count: " + str(size))
			return arr

		if abs(diff) < abs(a.tileCount - closestSize):
			closestSize = size

		var changeStrength = 0.01 * sizeIterations / float(i + 1)
		var maxSwitch = 200 / float(i + 1)
		viabilityTileCountModifier += clamp(diff * changeStrength, - maxSwitch, maxSwitch)

	if a.tileCount > 0:
		reportError("Map did not reach sufficient size. Expected size is " + str(a.tileCount) + " tiles, but closest achieved size is " + str(closestSize))
		return []

	return arr

func generate_hardness():

	var hardnessStabilizer: = 0.0
	for i in 10:
		var cells = _mapData.get_used_biome_cells()
		for cell in cells:
			var normalizedEntrance = min(1.0, pow(cell.length() * 0.16, 2))
			var hardnessNoise = hardness_noise.get_noise_2d(cell.x * 10, cell.y * 10) * normalizedEntrance

			var hardness = clamp(hardnessStabilizer + 2.0 + hardnessNoise * a.hardness_scale, 0, 4)
			_mapData.set_hardnessv(cell, hardness)

		var softest = _mapData.get_hardness_cells_by_grade(Data.HARDNESS_VERY_SOFT).size()
		var hardest = _mapData.get_hardness_cells_by_grade(Data.HARDNESS_VERY_HARD).size()
		if abs(softest - hardest) < cells.size() * 0.0025:
			break

		hardnessStabilizer += 2.0 * (softest - hardest) / float(cells.size())


	var cells = _mapData.get_used_biome_cells()
	for cell in cells:
		var normalizedEntrance = min(1.0, pow(cell.length() * 0.16, 2))
		var hardnessNoise = hardness_noise.get_noise_2d(cell.x * 10, cell.y * 10) * normalizedEntrance
		var hardness = clamp(hardnessStabilizer + a.hardness_offset + 2.0 + hardnessNoise * a.hardness_scale, a.hardness_min, a.hardness_max)
		_mapData.set_hardnessv(cell, hardness)


func generate_border_prepass():
	var original_cell_coords: Array = _mapData.get_used_biome_cells()
	for cell in original_cell_coords:
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				var c = Vector2(cell.x + ox, cell.y + oy)
				if _mapData.get_biomev(c) < 0:
					_mapData.set_resourcev(c, Data.TILE_BORDER)

func generate_border():
	_mapData.set_biomev(Vector2i(0, 0), 0)
	for cell in _mapData.get_used_biome_cells():
		var biome = _mapData.get_biomev(cell)
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				var neighbor_coord = Vector2i(cell.x + ox, cell.y + oy)
				if _mapData.get_biomev(neighbor_coord) < 0:
					_mapData.set_biomev(neighbor_coord, biome)
					_mapData.set_resourcev(neighbor_coord, Data.TILE_BORDER)
					_mapData.set_hardnessv(neighbor_coord, Data.HARDNESS_INDESTRUCTIBLE)


func generate_fixed_entrance():
	_mapData.set_biomev(Vector2i(0, -1), 0)
	_mapData.set_biomev(Vector2i(-1, -2), 0)
	_mapData.set_biomev(Vector2i(0, -2), 0)
	_mapData.set_biomev(Vector2i(1, -2), 0)
	_mapData.set_biomev(Vector2i(0, 0), 0)

	_mapData.set_resourcev(Vector2i(0, -1), -1)
	_mapData.set_resourcev(Vector2i(0, 0), Data.TILE_DIRT_START)

	_mapData.set_hardnessv(Vector2i(0, -2), Data.HARDNESS_MEDIUM)
	_mapData.set_hardnessv(Vector2i(0, -1), Data.HARDNESS_MEDIUM)
	_mapData.set_hardnessv(Vector2i(0, 0), Data.HARDNESS_MEDIUM)

func tryPlace(cellType: int, cells: Array) -> bool:
	var lastHardness: = 0
	for cell in cells:
		var id = _mapData.get_resourcev(cell)
		if id >= 3 and id <= 9:
			return false
		var hd = _mapData.get_hardnessv(cell)
		if hd < 0:
			_mapData.set_hardnessv(cell, lastHardness)
			lastHardness = hd


	var biome = -1
	for cell in cells:
		var v = _mapData.get_biomev(cell)
		if v != -1:
			biome = v
			break

	if biome == -1:
		return false

	for cell in cells:
		_mapData.set_resourcev(cell, cellType)
		_mapData.set_biomev(cell, biome)
		if _mapData.get_hardnessv(cell) < a.hardness_min:
			_mapData.set_hardnessv(cell, a.hardness_min)
	return true

func generate_iron_clusters(original_cell_coords, borderCells):
	var ironClusterAmount = round(a.iron_cluster_rate * 0.001 * original_cell_coords.size())

	for i in ironClusterAmount:
		_mapData.set_resourcev(original_cell_coords[i], Data.TILE_IRON)


	var iterations: = 100
	var totalMove: = Vector2()
	var averagedLastTotalMoves: = Vector2()
	for iteration in iterations:
		var ironTiles = _mapData.get_resource_cells_by_id(Data.TILE_IRON)
		Utils.shuffle(ironTiles, rand)
		for tileCoord in ironTiles:
			var sum: = Vector2()
			for otherCoord in ironTiles:
				if otherCoord == tileCoord:
					continue
				var delta = tileCoord - otherCoord
				var strength = 20 + 5 * round(otherCoord.y * a.iron_cluster_size_per_y)
				var mod = strength / delta.length_squared()
				if mod < 0.02:
					continue
				sum += (Vector2(delta).normalized()) * mod
			for borderCell in borderCells:
				var strength = 500 + round(borderCell.y * 2.0)
				var delta = tileCoord - borderCell
				var deltal = delta.length()
				var mod = 0.02 * strength / (deltal * deltal * deltal)
				if mod < 0.002:
					continue
				sum += (Vector2(delta).normalized()) * mod
			if sum.length() > 0.2:
				sum = sum.normalized()
			sum.x = round(sum.x)
			sum.y = round(sum.y)
			if _mapData.get_resourcev(Vector2(tileCoord) + sum) == Data.TILE_DIRT_START:
				totalMove += sum
				moveResource(tileCoord, sum.x, sum.y, Data.TILE_IRON)
		averagedLastTotalMoves = averagedLastTotalMoves * 0.5 + totalMove * 0.5






func generate_gadget_chambers():

	resourceMinY = a.gadget_first_depth
	resourceX = sign(rand.randf_range(-1, 1)) * a.width * 0.1 + rand.randf_range(0, a.width * 0.1)
	var remainingGadgets = a.gadgets
	var failsafe: = 1000
	while remainingGadgets > 0:
		failsafe -= 1
		if failsafe % 100 == 0:

			resourceMinY = resourceMinY + a.gadget_depth_step * 0.2
		elif failsafe == 100:
			resourceMinY = a.gadget_first_depth + (a.gadgets - remainingGadgets) * a.gadget_depth_step
		elif failsafe == 50:
			resourceMinY = a.gadget_first_depth
		elif failsafe <= 0:
			reportError("Failsafe reached: failed to generate gadgets")
			break

		var ironTiles = _mapData.get_resource_cells_by_id(Data.TILE_IRON)
		sortByDistanceReferencePoint = Vector2(round(resourceX), resourceMinY)
		ironTiles.sort_custom(Callable(self, "sortByDistance"))
		if ironTiles.size() < 4:
			break

		var averageCell: Vector2
		if failsafe > 100:
			averageCell = sortByDistanceReferencePoint * 0.4 + 0.6 * 0.25 * (ironTiles[0] + ironTiles[1] + ironTiles[2] + ironTiles[3])
		else:
			averageCell = Vector2(ironTiles[0]) + Vector2(round(rand.randf_range(-4, 4)), round(rand.randf_range(-4, 4)))
		if _mapData.get_resourcev(averageCell) != Data.TILE_DIRT_START:
			continue

		var coords: = []
		for c in gadget_chamber_offset:
			coords.append(c + averageCell)
		var placed = tryPlace(3, coords)
		if placed:
			remainingGadgets -= 1
			resourceMinY = resourceMinY + a.gadget_depth_step + (a.gadgets - remainingGadgets)
			var relativeDepth = averageCell.y / float(a.depth)
			if averageCell.x == 0:
				averageCell.x = 1 if rand.randf() > 0.5 else -1
			resourceX = - sign(averageCell.x) * a.width * (0.1 + relativeDepth * 0.2) * rand.randf_range(0.5, 2.0)

	if remainingGadgets != 0:
		reportError("Gadgets generation failed: %s remaining gadgets" % remainingGadgets)

func generate_relics():

	resourceX = sign(rand.randf_range(-1, 1)) * a.width * 0.1 + rand.randf_range(0, a.width * 0.1)
	var failsafe: = 100

	var currentRelicStep: = 0
	while currentRelicStep < a.relics:
		var xLeft = rand.randf_range(a.width * -0.5, a.width * -0.2)
		var xRight = rand.randf_range(a.width * 0.2, a.width * 0.5)
		var offsetY = a.relic_first_depth + currentRelicStep * a.relic_depth_step
		var goalLeft = Vector2(resourceX + xLeft, a.depth - offsetY)
		var goalRight = Vector2(resourceX + xRight, a.depth - offsetY)

		failsafe -= 1
		if failsafe <= 0:
			reportError("Failsafe reached: failed to generate relic chamber")
			break

		var ironTiles = _mapData.get_resource_cells_by_id(Data.TILE_IRON)
		var bestCell: Vector2
		var bestD: = 999999
		for cell in ironTiles:
			var left = goalLeft - Vector2(cell)
			var right = goalRight - Vector2(cell)
			var best = left if left.length() < right.length() else right
			var d = best.length()
			if d < bestD:
				bestD = d
				bestCell = cell

		var coords: = []
		for c in relic_chamber_offset:
			coords.append(c + bestCell)
		var placed = tryPlace(4, coords)
		if placed:
			currentRelicStep += 1
			var deltaWidth = sign(bestCell.x) * a.width * 0.2 - bestCell.x
			resourceX = - bestCell.x - deltaWidth

			var remainingSwitches = a.relic_switches

			var switchDirections: Array
			var distanceNormalization: = 0.0
			failsafe = 50
			var averageDistance = 0.5 * (a.relic_switch_distance_range.x + a.relic_switch_distance_range.y)
			var minDistance = a.relic_switch_distance_range.x
			while remainingSwitches > 0:
				failsafe -= 1
				if failsafe < 0:
					reportError("Failsafe reached: Failed to generate relic switch chambers")
					break
				if rand.randf() < 0.2:
					if rand.randf() > 0.5:
						switchDirections = [Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN]
					else:
						switchDirections = [Vector2.UP, Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN]
				else:
					if rand.randf() > 0.5:
						switchDirections = [Vector2.LEFT, Vector2.RIGHT, Vector2.DOWN, Vector2.UP]
					else:
						switchDirections = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]

				var distance = rand.randf_range(a.relic_switch_distance_range.x, a.relic_switch_distance_range.y) + distanceNormalization
				distance = clamp(distance, a.relic_switch_distance_range.x, a.relic_switch_distance_range.y)
				while switchDirections.size() > 0:
					var direction = switchDirections.pop_front()
					var result: Vector2 = tryPlaceRelicSwitch(bestCell, direction, distance, minDistance)
					if result != Vector2.ZERO:
						var distanceToSwitch = (result - bestCell).length()
						distanceNormalization += averageDistance - distanceToSwitch
						remainingSwitches -= 1
						if remainingSwitches == 0:
							break
				minDistance -= 1

	if a.relics > currentRelicStep:
		reportError("Relic generation failed. Failed to place %s relics" % (a.relics - currentRelicStep))

func generate_power_cores():

	resourceMinY = a.powercore_first_depth
	resourceX = sign(rand.randf_range(-1, 1)) * a.width * 0.25 + rand.randf_range(0, a.width * 0.1)
	var remainingPowercores = a.powercores
	var failsafe = 100
	var ironTiles = _mapData.get_resource_cells_by_id(Data.TILE_IRON)
	var offsets: = [0.5, 0.55, 0.45, 0.6, 0.4, 0.7, 0.3]
	while remainingPowercores > 0:
		failsafe -= 1
		if failsafe <= 0:
			reportError("Failsafe reached: failed to generate powercores")
			break

		if ironTiles.size() < 2:
			break

		sortByDistanceReferencePoint = Vector2(round(resourceX), resourceMinY)
		ironTiles.sort_custom(sortByDistance)
		var cell = ironTiles.pop_front()

		for offset in offsets:
			var averageCell: Vector2 = cell * offset + (1.0 - offset) * sortByDistanceReferencePoint

			if _mapData.get_resourcev(averageCell) != Data.TILE_DIRT_START:
				continue

			var placed = tryPlace(7, [averageCell, averageCell + Vector2(0, -1), averageCell + Vector2(1, 0), averageCell + Vector2(0, 1), averageCell + Vector2(1, 1)])
			if placed:
				remainingPowercores -= 1
				resourceMinY = resourceMinY + a.powercore_depth_step + (a.powercores - remainingPowercores)
				var relativeDepth = averageCell.y / float(a.depth)
				if averageCell.x == 0:
					averageCell.x = 1 if rand.randf() > 0.5 else -1
				resourceX = - sign(averageCell.x) * a.width * (0.1 + relativeDepth * 0.2) * rand.randf_range(0.5, 2.0)
				break

	if remainingPowercores != 0:
		reportError("Power cores generation failed. Only placed %d of %d power cores" % [a.powercores - remainingPowercores, a.powercores])

func adjust_ore_amounts():
	var ironTilesByBiome: = []
	var waterTilesByBiome: = []
	var sandTilesByBiome: = []
	for i in maxBiome + 1:
		ironTilesByBiome.append([])
		waterTilesByBiome.append([])
		sandTilesByBiome.append([])

	for cell in _mapData.get_resource_cells_by_id(Data.TILE_IRON):
		var index = _mapData.get_biomev(cell)
		if index < 0:
			continue
		ironTilesByBiome[index].append(cell)
	for cell in _mapData.get_resource_cells_by_id(Data.TILE_WATER):
		var index = _mapData.get_biomev(cell)
		if index < 0:
			continue
		waterTilesByBiome[index].append(cell)
	for cell in _mapData.get_resource_cells_by_id(Data.TILE_SAND):
		var index = _mapData.get_biomev(cell)
		if index < 0:
			continue
		sandTilesByBiome[index].append(cell)

	var removeCount: = 0.0
	for i in ironTilesByBiome.size():
		var tiles = ironTilesByBiome[i]
		Utils.shuffle(tiles, rand)
		for tile in tiles:
			removeCount += float(a.iron_cluster_removal_rate)
			if removeCount > 1.0:
				removeCount -= 1.0
				_mapData.set_resourcev(tile, Data.TILE_DIRT_START)
	removeCount = 0.0
	for i in waterTilesByBiome.size():
		var tiles = waterTilesByBiome[i]
		Utils.shuffle(tiles, rand)
		for tile in tiles:
			removeCount += float(a.water_removal_rate)
			if removeCount > 1.0:
				removeCount -= 1.0
				_mapData.set_resourcev(tile, Data.TILE_DIRT_START)
	removeCount = 0.0
	for i in sandTilesByBiome.size():
		var tiles = sandTilesByBiome[i]
		Utils.shuffle(tiles, rand)
		for tile in tiles:
			removeCount += float(a.cobalt_removal_rate)
			if removeCount > 1.0:
				removeCount -= 1.0
				_mapData.set_resourcev(tile, Data.TILE_DIRT_START)

func expand_iron_clusters(ironClusterCenters):


	for cell in ironClusterCenters:
		var cluster: = [cell]
		var goalSize = round(a.iron_cluster_size_base + cell.y * (a.iron_cluster_size_per_y - a.iron_cluster_size_randomness * 0.5 + a.iron_cluster_size_randomness * rand.randf()))
		for i in 50:
			if cluster.size() >= goalSize:
				break
			var randomCell = cluster[rand.randi() % cluster.size()]
			Utils.shuffle(directions, rand)
			for d in directions:
				var neighbor = randomCell + Vector2i(d)
				if _mapData.get_resourcev(neighbor) == Data.TILE_DIRT_START:
					_mapData.set_resourcev(neighbor, Data.TILE_IRON)
					cluster.append(neighbor)
					break

func generate_water(ironClusterCenters, original_cell_coords, borderCells):
	var waterAmount = round(a.water_rate * 0.001 * original_cell_coords.size())
	var availableCells = _mapData.get_resource_cells_by_id(Data.TILE_DIRT_START)
	Utils.shuffle(availableCells, rand)
	var freeTileIndex: = 0
	for _j in min(waterAmount, availableCells.size()):
		_mapData.set_resourcev(availableCells[freeTileIndex], Data.TILE_WATER)
		freeTileIndex += 1

	var iterations = 100
	var totalMove = Vector2()
	var averagedLastTotalMoves = Vector2()
	var zeroMoves = 0
	for iteration in iterations:
		var waterTiles = _mapData.get_resource_cells_by_id(Data.TILE_WATER)
		Utils.shuffle(waterTiles, rand)
		for tileCoord in waterTiles:
			var sum: = Vector2()
			for otherCoord in waterTiles:
				if otherCoord == tileCoord:
					continue
				var strength = 30 + round(otherCoord.y * 0.5)
				var delta = tileCoord - otherCoord
				var mod = strength / pow(delta.length(), 2)
				if mod < 0.001:
					continue
				sum += (Vector2(delta).normalized()) * mod
			for otherCoord in ironClusterCenters:
				var strength = 5
				var delta = tileCoord - otherCoord
				var mod = strength / pow(delta.length(), 3)
				if mod < 0.001:
					continue
				sum += (Vector2(delta).normalized()) * mod
			for borderCell in borderCells:
				var strength = 22
				var delta = tileCoord - borderCell
				var mod = strength / pow(delta.length(), 3)
				if mod < 0.001:
					continue
				sum += (Vector2(delta).normalized()) * mod
			if sum.length() > 0.2:
				sum = sum.normalized()
			sum.x = round(sum.x)
			sum.y = round(sum.y)
			if _mapData.get_resourcev(Vector2(tileCoord) + sum) == Data.TILE_DIRT_START:
				totalMove += sum
				moveResource(tileCoord, sum.x, sum.y, Data.TILE_WATER)
		averagedLastTotalMoves = averagedLastTotalMoves * 0.5 + totalMove * 0.5
		if (totalMove - averagedLastTotalMoves).length() < 1.0:
			zeroMoves += 1
			if zeroMoves >= 5:
				break

func generate_cobalt(ironClusterCenters, original_cell_coords, borderCells):
	var cobaltAmount = round(a.cobalt_rate * 0.001 * original_cell_coords.size())
	var availableCells = _mapData.get_resource_cells_by_id(Data.TILE_DIRT_START)
	Utils.shuffle(availableCells, rand)
	var freeTileIndex = 0
	for _j in cobaltAmount:
		_mapData.set_resourcev(availableCells[freeTileIndex], Data.TILE_SAND)
		freeTileIndex += 1
	var iterations = 100
	var totalMove = Vector2()
	var averagedLastTotalMoves = Vector2()
	var zeroMoves = 0

	for iteration in iterations:
		var cobaltTiles = _mapData.get_resource_cells_by_id(Data.TILE_SAND)
		Utils.shuffle(ironClusterCenters, rand)
		for tileCoord in cobaltTiles:
			var sum: = Vector2()
			for otherCoord in cobaltTiles:
				if otherCoord == tileCoord:
					continue
				var strength = 100 + round(otherCoord.y * 2.0)
				var delta = tileCoord - otherCoord
				var mod = strength / pow(delta.length(), 2)
				if mod < 0.01:
					continue
				sum += (Vector2(delta).normalized()) * mod
			for otherCoord in ironClusterCenters:
				var strength = 10
				var delta = tileCoord - otherCoord
				var mod = strength / pow(delta.length(), 2)
				if mod < 0.001:
					continue
				sum += (Vector2(delta).normalized()) * mod
			for borderCell in borderCells:
				var strength = 20
				var delta = tileCoord - borderCell
				var mod = strength / pow(delta.length(), 3)
				if mod < 0.001:
					continue
				sum += (Vector2(delta).normalized()) * mod
			if sum.length() > 0.2:
				sum = sum.normalized()
			sum.x = round(sum.x)
			sum.y = round(sum.y)
			if _mapData.get_resourcev(Vector2(tileCoord) + sum) == Data.TILE_DIRT_START:
				totalMove += sum
				moveResource(tileCoord, sum.x, sum.y, 2)

		averagedLastTotalMoves = averagedLastTotalMoves * 0.5 + totalMove * 0.5
		if (totalMove - averagedLastTotalMoves).length() < 1.0:
			zeroMoves += 1
			if zeroMoves >= 5:
				break

func generate_holes(rand, averageCellCountInBiome):

	for i in maxBiome + 1:
		var failsafe = 99
		var biome_cells = _mapData.get_biome_cells_by_index(i)
		var cellCount = biome_cells.size()
		var relativeBiomeSize: float = cellCount / float(averageCellCountInBiome)
		var holeAmount: int = round(relativeBiomeSize * a.holes_per_biome * rand.randf_range(1 - a.holes_per_biome_randomness, 1 / (1 - a.holes_per_biome_randomness)))
		for j in holeAmount:
			if biome_cells.is_empty():
				continue
			var startTile: Vector2 = biome_cells[rand.randi() % biome_cells.size()]

			while _mapData.get_resourcev(startTile) >= 3 and _mapData.get_resourcev(startTile) <= 9:
				startTile = biome_cells[rand.randi() % biome_cells.size()]
				failsafe -= 1
				if failsafe <= 0:
					break
			if failsafe <= 0:
				break

			var holeSizeRandomness: float = rand.randf_range(1 - a.hole_size_randomness, 1 / (1 - a.hole_size_randomness))
			var baseSize: float = a.hole_size_base + i * a.hole_size_per_biome
			var goalSize: = roundf(holeSizeRandomness * baseSize)
			placeHole(startTile, goalSize)


		if failsafe <= 0:
			continue


func findOutsideBorderCells() -> Array:
	var allBorderCells: Array = _mapData.get_used_resource_cells()
	var borderGroups: = []
	var currentGroup = null
	var openCells: = []
	while allBorderCells.size() > 0:
		if currentGroup == null:
			var cell = allBorderCells.pop_back()
			openCells.append(cell)
			currentGroup = []

		if openCells.size() == 0:
			borderGroups.append(currentGroup)
			currentGroup = null
			continue

		var cell = openCells.pop_back()
		currentGroup.append(cell)

		for d in directions:
			var otherCell = cell + Vector2i(d)
			if allBorderCells.has(otherCell):
				openCells.append(otherCell)
				allBorderCells.erase(cell)

	var largestGroup: = []
	var size: = 0
	for group in borderGroups:
		if group.size() > size:
			largestGroup = group
			size = group.size()
	return largestGroup

func tryPlaceRelicSwitch(baseCell: Vector2, direction: Vector2, distance: float, minDistance: int) -> Vector2:
	var rand: = RandomNumberGenerator.new()
	rand.seed = gen_seed + 100
	for _d in round(distance) - minDistance:
		var delta = direction * distance
		for _r in 6:
			var angle = PI * rand.randf_range(a.relic_switch_angle_range_pi.x, a.relic_switch_angle_range_pi.y)
			var goalCell = delta.rotated(angle) + baseCell
			goalCell.x = round(goalCell.x)
			goalCell.y = round(goalCell.y)
			var source_id = _mapData.get_resourcev(goalCell)
			if source_id == 10:
				_mapData.set_resourcev(goalCell, 6)
				return goalCell
		distance -= 1
	return Vector2.ZERO

func moveResource(from: Vector2, byX, byY, newValue):
	_mapData.set_resourcev(Vector2(from.x + byX, from.y + byY), newValue)
	_mapData.set_resourcev(Vector2(from.x, from.y), 10)

func popTileData() -> MapData:
	var td = _mapData
	remove_child(td)
	return td

func getMineableTileCount() -> int:
	return _mapData.get_mineable_tile_count()

var sortByDistanceReferencePoint: Vector2
const yMult: = Vector2(1, 3)
func sortByDistance(v1: Vector2, v2: Vector2):
	return (v1 * yMult - sortByDistanceReferencePoint * yMult).length() < (v2 * yMult - sortByDistanceReferencePoint * yMult).length()

func placeHole(at: Vector2, size: int):
	var holeCoords: = [at]

	var origin: = at
	var snakeyThreshold: float = [0.2, 0.5, 0.6, 0.7][rand.randi() % 4]


	for i in size - 1:
		var expansionDir = Vector2.ZERO
		var surroundedBySelf: = true


		Utils.shuffle(directions, rand)
		for gd in directions:
			var testTile = origin + gd
			if not holeCoords.has(testTile):
				surroundedBySelf = false
				if _mapData.get_resourcev(testTile) <= 2 or _mapData.get_resourcev(testTile) == Data.TILE_DIRT_START:
					expansionDir = gd
					break


		if surroundedBySelf:
			Utils.shuffle(diagonals, rand)
			for gd in diagonals:
				var testTile = origin + gd
				if (_mapData.get_resourcev(testTile) <= 2 or _mapData.get_resourcev(testTile) == Data.TILE_DIRT_START) and not holeCoords.has(testTile):
					expansionDir = gd
					break


		if expansionDir == Vector2.ZERO:
			for hc in holeCoords:
				Utils.shuffle(directions, rand)
				for dir in directions:
					var testTile = hc + dir
					if (_mapData.get_resourcev(testTile) <= 2 or _mapData.get_resourcev(testTile) == Data.TILE_DIRT_START) and not holeCoords.has(testTile):
						expansionDir = dir
						origin = hc
						break

		if expansionDir == Vector2.ZERO:
			break
		holeCoords.append(origin + expansionDir)

		if rand.randf() < snakeyThreshold:
			origin += expansionDir


	var removedResources: = {}
	for hc in holeCoords:
		if _mapData.get_resourcev(hc) >= 0 and _mapData.get_resourcev(hc) <= 2:
			removedResources[hc] = _mapData.get_resourcev(hc)
		_mapData.clear_resource(hc)


	for removalCoord in removedResources:
		scatterResource(removalCoord, removedResources.get(removalCoord))

func scatterResource(coord: Vector2, cellType: int):
	var offset: = 1
	var grown: = false
	var usedCells = _mapData.get_used_biome_cells()


	while not grown:
		Utils.shuffle(directions, rand)
		for dir in directions:
			var moveTarget: Vector2i = Vector2i(coord + dir * offset)
			if not usedCells.has(moveTarget):
				continue
			if _mapData.get_resourcev(moveTarget) == Data.TILE_DIRT_START:
				_mapData.set_resourcev(moveTarget, cellType)
				grown = true
				break
		offset += 1
		if offset >= 99:
			reportError("Failsafe reached: scatter resources maxed out")
			break

static func calculate_map_offset(inFirstGenerator: TileDataGenerator, inSecondGenerator: TileDataGenerator, 
			overlap_threshold: = 0.06) -> Vector2i:
	var t1: MapData = inFirstGenerator._mapData
	var t2: MapData = inSecondGenerator._mapData
	var mirror_t1: bool
	if t2 == null:
		mirror_t1 = true
		t2 = t1
	else:
		mirror_t1 = false

	var offset: = Vector2i(round((t1.getSize().x + t2.getSize().x) * 0.38), 0)
	var bound: = offset.x
	var failsafe: = 0
	var mirror_mult: = -1 if mirror_t1 else 1
	var direction: = 0
	while true:
		failsafe += 1
		if failsafe > bound:
			inFirstGenerator.reportLog("failed to place second map in the right distance to my map")
			inSecondGenerator.reportLog("failed to place my map in the right distance to the first one")
			break
		var b1: = t1.get_used_biome_cells()
		var b2: = t2.get_used_biome_cells()
		var total_size: int = b1.size() + b2.size()
		var overlapping_cell_count: = 0
		for cell in b1:
			var target_cell: = Vector2i(offset.x + mirror_mult * cell.x, cell.y)
			if b2.has(target_cell):
				overlapping_cell_count += 1
		var fraction = overlapping_cell_count / float(total_size)
		if fraction > overlap_threshold:
			if direction >= 0:
				offset.x += 1
				direction = 1
			else:
				break
		elif fraction < overlap_threshold:
			if direction <= 0:
				offset.x -= 1
				direction = -1
			else:
				break
	return offset

static func mergeMapBoundaries(outTeam1Generator: TileDataGenerator, outTeam2Generator: TileDataGenerator) -> Vector2i:
	outTeam1Generator._borderMergeMutex.lock()
	outTeam2Generator._borderMergeMutex.lock()
	var team1MapData: MapData = outTeam1Generator._mapData
	var team2MapData: MapData = outTeam2Generator._mapData
	assert (outTeam1Generator.teamId == "team1")
	assert (outTeam2Generator.teamId == "team2")
	var b1: = team1MapData.get_used_biome_cells()
	var b2: = team2MapData.get_used_biome_cells()
	var mirror_mult = 1
	var team2MapOffset: Vector2i = TileDataGenerator.calculate_map_offset(outTeam1Generator, outTeam2Generator)
	var team1MapRect: Rect2i = team1MapData.get_used_rect()
	var team2MapRect: Rect2i = team2MapData.get_used_rect()
	var big_x: int = team2MapOffset.x + mirror_mult * (team2MapRect.position.x + team2MapRect.size.x)
	var small_x: int = team1MapRect.position.x
	var x_middle: int = ((small_x + big_x) / 2.0)

	for team2CellCoords in b2:
		var team1CellCoords: = Vector2i(team2MapOffset.x + mirror_mult * team2CellCoords.x, team2CellCoords.y)
		var isCellSharedInBothMaps = b1.has(team1CellCoords)
		if isCellSharedInBothMaps:
			var team1MapEdit: bool = team1CellCoords.x > x_middle
			if team1MapEdit:
				team1MapData.erase_cell(MapData.LAYER_BIOME, team1CellCoords)

			var team2MapEdit: bool = team1CellCoords.x < (x_middle - 1)
			if team2MapEdit:
				team2MapData.erase_cell(MapData.LAYER_BIOME, team2CellCoords)

	outTeam1Generator._shapesMerged = true
	outTeam2Generator._shapesMerged = true
	outTeam1Generator._borderMergeMutex.unlock()
	outTeam2Generator._borderMergeMutex.unlock()
	return team2MapOffset


func merge_tiledata(t1: MapData, t2: MapData, team2MapOffset: Vector2i, overlap_threshold: = 0.06) -> MapData:
	var correctOffsetProvided: bool = not is_zero_approx(team2MapOffset.length())
	assert (correctOffsetProvided)

	_mapData.clear()

	var mirror_t1: bool = t2 == null
	var mirror_mult: = -1 if mirror_t1 else 1
	if mirror_t1:
		t2 = t1

	if not mirror_t1:
		assert (t2.teamId == "team2")
	assert (t1.teamId == "team1")

	var offset: = team2MapOffset
	for cell in t1.get_used_biome_cells():
		_mapData.set_biomev(cell, t1.get_biomev(cell))
		_mapData.set_hardnessv(cell, t1.get_hardnessv(cell))
		_mapData.set_resourcev(cell, t1.get_resourcev(cell))

	var dodge_offsets: Array = []
	var max_dodge_range = 6
	for length in range(1, max_dodge_range + 1):
		for x in range( - length, length + 1):
			for y in range( - length, length + 1):
				var v: = Vector2(x, y)
				dodge_offsets.append(v)

	var collided_cells: = []
	for cell in t2.get_used_biome_cells():
		var target_cell: = Vector2(offset.x + mirror_mult * cell.x, cell.y)
		var hardness2 = t2.get_hardnessv(cell)
		var res2 = t2.get_resourcev(cell)
		var biome2 = t2.get_biomev(cell)
		var biome1 = _mapData.get_biomev(target_cell)
		if biome1 != -1:
			var hardness1 = _mapData.get_hardnessv(target_cell)
			var res1 = _mapData.get_resourcev(target_cell)
			biome2 = min(biome1, biome2)
			hardness2 = min(hardness1, hardness2)
			if res1 >= Data.TILE_GADGET and res1 <= Data.TILE_CAVE and res2 >= Data.TILE_GADGET and res2 <= Data.TILE_CAVE:
				res2 = res1
				collided_cells.append(target_cell)
			else:
				res2 = min(res1, res2)
		_mapData.set_biomev(target_cell, biome2)
		_mapData.set_hardnessv(target_cell, hardness2)
		_mapData.set_resourcev(target_cell, res2)


	while not collided_cells.is_empty():
		var sourceCell: Vector2 = collided_cells.pop_back()
		var newCluster = []
		var openCells = [sourceCell]
		var tileType = t2.get_resourcev(sourceCell)
		var topLeft = Vector2(9999, 9999)
		while openCells.size() > 0:
			var currentCell: Vector2 = openCells.pop_back()
			newCluster.append(currentCell)
			t2.set_resourcev(currentCell, Data.TILE_DIRT_MARK_BLOCKED_FOR_CHAMBER)
			collided_cells.erase(currentCell)
			for o in Map.NEIGHBOR_TILE_OFFSETS1:
				var neighborCell = currentCell + o
				var otherCellId = t2.get_resourcev(neighborCell)
				if otherCellId == tileType and not newCluster.has(neighborCell) and not openCells.has(neighborCell):
					openCells.append(neighborCell)
			for cell in newCluster:
				topLeft.x = min(topLeft.x, cell.x)
				topLeft.y = min(topLeft.y, cell.y)

		var done: = false
		for dodge_offset in dodge_offsets:
			var coords: = []
			var offsets: Array
			match tileType:
				Data.TILE_GADGET: offsets = gadget_chamber_offset
				Data.TILE_NEST: offsets = gadget_chamber_offset
				Data.TILE_SUPPLEMENT: offsets = gadget_chamber_offset
				Data.TILE_RELIC: offsets = relic_chamber_offset
				Data.TILE_RELIC_SWITCH: offsets = [Vector2()]
			for c in offsets:
				coords.append(c + sourceCell + dodge_offset)
			done = tryPlace(tileType, coords)
			if done:
				break
		if not done:
			t1.queue_free()
			t2.queue_free()
			return null

	t1.queue_free()
	t2.queue_free()
	return popTileData()

func startTimer(timer_name):
	report_timer_name.append(timer_name)
	report_timer.append(Time.get_ticks_usec())

func endTimer():
	var dashes = ""
	for i in report_timer.size():
		dashes += "---"

	var n = report_timer_name.pop_back()
	var t = report_timer.pop_back()
	reportLog("%s took %sms for %s" % [dashes, float(Time.get_ticks_usec() - t) / 1000, n])

func reportLog(inStr: String):
	report += inStr + "\n"

func reportError(inStr: String):
	report_contains_error = true
	reportLog(inStr)

func logReportToOutput():
	if report_contains_error:
		Logger.error(report)
	else:
		Logger.info(report)
