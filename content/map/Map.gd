extends Node2D

class_name Map

signal map_ready
signal tile_destroyed(world_tile_pos: Vector2)

const BORDER_TILE_OFFSETS1 = [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]
const BORDER_TILE_OFFSETS2 = [
Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), 
Vector2(-1, 0), Vector2(-1, 1), Vector2(0, -1), Vector2(1, -1), 
Vector2(2, 0), Vector2(2, 1), Vector2(0, 2), Vector2(1, 2)
]
const NEIGHBOR_TILE_OFFSETS1 = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
const NEIGHBOR_TILE_OFFSETS2 = [
Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), 
Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2), 
Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
const NEIGHBOR_TILE_OFFSETS_DIAG = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]

const MAP_TO_TEXTURE_OFFSET_COORD: = Vector2(0, 2)

var tile_scene = load("res://content/map/tile/Tile.tscn")
const RESOURCE_BORDER_OVERLAY = preload("res://content/map/border/ResourceBorderOverlay.tscn")

const BIOME_LIST: = {
	"grey": Color("232532"), 
	"red": Color("3c2436"), 
	"yellow": Color("35221e"), 
	"blue": Color("142137"), 
	"green": Color("19383e")
}
var biomes: = []

var layouts: = {
	1: Vector2(0, 0), 
	2: Vector2(1, 0), 
	3: Vector2(2, 0), 
	4: Vector2(3, 0), 
	5: Vector2(0, 1), 
	6: Vector2(1, 1), 
	7: Vector2(2, 1), 
	8: Vector2(3, 1), 
	9: Vector2(0, 2), 
	10: Vector2(1, 2), 
	11: Vector2(2, 2), 
	12: Vector2(3, 2), 
	13: Vector2(0, 3), 
	14: Vector2(1, 3), 
	15: Vector2(3, 3), 
}

var hardnessOffsets: = {
	0: Vector2(0, 0), 
	1: Vector2(0, 4), 
	2: Vector2(0, 8), 
	3: Vector2(0, 12), 
	4: Vector2(0, 16), 
	5: Vector2(0, 20), 
}

const borderSpriteOffset = Vector2(12, 12)
const mapToWorldOffset = Vector2(12, -72)

var tileData: MapData

var borderSprites: = {}
var tiles: = {}


var visibleTileCoords: = {}
var tileCoordsToReveal: = []
var tileDestroyedListeners: = {}
var tileRevealedListeners: = {}
var onRevealDecorators: = []
var initialUsedRect: Rect2
var visuallyRevealedTiles: = {}


var startingIronCountByLayer: = {}
var currentIronCountByLayer: = {}

var tilesByType: = {CONST.WATER: [], CONST.SAND: [], CONST.IRON: []}

var dropDeltas: = {}
var firstDropByTeam: = []

var pathfinder: Pathfinding

@onready var lights = $ViewportLights
@onready var tiles_node = $Tiles
@onready var bg_elements = $"%BackgroundElements"
@onready var drop_system: Drops = $Drops
@onready var tile_borders_node = $TileBorders
@onready var border_deco = $TileRender / BorderDecorations
@onready var critters = $Critters


var holeTexture: ImageTexture = ImageTexture.new()
var holeImage: Image = Image.new()
var holeTextureIsDirty = false

var rockFalloffTexture: ImageTexture = ImageTexture.new()
var rockFalloffImage: Image = Image.new()
var rockFalloffTextureIsDirty = false

var damageTexture: ImageTexture = ImageTexture.new()
var damageImage: Image = Image.new()
var damageTextureIsDirty = false

var bgCaveTexture: ImageTexture = ImageTexture.new()
var bgCaveImage: Image = Image.new()

var biomeColorTexture: ImageTexture = ImageTexture.new()
var biomeColorImage: Image = Image.new()

var noiseFactorTexture: ImageTexture = ImageTexture.new()
var noiseFactorImage: Image = Image.new()

var edge_scaling = 4


var tilemap_size = Vector2.ONE
var viewport_crack_update: = 0.0
@onready var fg_mat = $TileRender / MainStones.material
@onready var bg_mat = $BackgroundRender / BackgroundSprite.material
@onready var rock_tiles = $ViewportRocks / Rocks
@onready var viewport_crack_impact: SubViewport = $ViewportCrackImpact
@onready var _bulletSmokeManager: BulletSmokeManager = $BulletSmokeManager

var chamberPlacements: Dictionary
var cavePlacements: Dictionary
var landmark_coords: Dictionary = {}
var _isMapReady: bool = false

func getMapData() -> Dictionary:
	var data: Dictionary = {}
	for i: int in range(tileData.get_layers_count()):
		data[i] = tileData.get("layer_%d/tile_data" % i)

	return data

func setTileData(tileDataInstance):
	if tileData:
		tileData.free()
	tileData = tileDataInstance
	if not tileData.get_parent():
		tileData.owner = null
		add_child(tileData)
		getTileData().position = - mapToWorldOffset
	Data.apply("map.depthpixels", tileData.getSize().y * GameWorld.TILE_SIZE)
	initialUsedRect = tileData.get_used_rect()

func init(fromDeserialize: = false, generateChambers: = true):
	var rand = RandomNumberGenerator.new()
	rand.seed = Level.levelSeed
	borderSprites.clear()
	for s in tiles.values():
		if is_instance_valid(s):
			s.queue_free()
	tiles.clear()
	for border in tile_borders_node.get_children():
		border.queue_free()
	visibleTileCoords.clear()
	tileCoordsToReveal.clear()
	tileDestroyedListeners.clear()
	tileRevealedListeners.clear()
	startingIronCountByLayer.clear()
	currentIronCountByLayer.clear()
	for array in tilesByType.values():
		array.clear()
	dropDeltas.clear()
	if pathfinder:
		pathfinder.cleanup()

	border_deco.borderSprites = borderSprites
	border_deco.init()
	Style.init($Background)
	Style.init($BackgroundRender / BackgroundSprite)
	Style.init($TileRender / MainStones)
	tilesByType = {CONST.WATER: [], CONST.SAND: [], CONST.IRON: []}
	Data.apply("map.tilesDestroyed", 0)

	tileData.visible = false



	for ironCell in tileData.get_resource_cells_by_id(Data.TILE_IRON):
		var layer = tileData.get_biome(ironCell.x, ironCell.y)
		startingIronCountByLayer[layer] = 1 + startingIronCountByLayer.get(layer, 0)
	for l in startingIronCountByLayer:
		currentIronCountByLayer[l] = startingIronCountByLayer[l]

	if not fromDeserialize and generateChambers:
		var giftChamberIds: = [
			"skin3", 
			"pet7"
		]
		var halloweenId: = "followEye"
		for chamberId in chamberPlacements:
			var scene: PackedScene
			var isGiftChamber: = false
			if str(chamberId).to_lower() == halloweenId.to_lower():
				scene = preload("res://content/map/decorations/ornaments/FollowEye.tscn")
			elif giftChamberIds.has(chamberId):
				scene = preload("res://content/map/chamber/gift/GiftChamber.tscn")
				isGiftChamber = true
			else:
				scene = getSceneForTileType(int(chamberId))

			for coords in chamberPlacements[chamberId]:
				var chamber = addChamber(Utils.parse_vector2(coords), scene)
				if isGiftChamber:
					chamber.giftType = chamberId

	pathfinder = Pathfinding.new()
	Achievements.addIfOpen(self, "MINE_ALL")


	tilemap_size = tileData.getMaxSize()


	var viewport_size = tilemap_size * GameWorld.TILE_SIZE
	$ViewportRocks.size = viewport_size


	$ViewportRocks.ensureUpdatedAtLeastOnce()
	$ViewportCrackImpact.size = viewport_size
	$ViewportTopEffects.size.x = viewport_size.x
	$PixelatedEffects.position.x = (viewport_size.x - 1024.0) / 2.0
	$ViewportLights.set_size(viewport_size)
	$ViewportBackgroundAlpha.size = viewport_size
	$ViewportLights.map_to_world_offset = mapToWorldOffset
	$TileRender.position = Vector2(( - viewport_size.x / 2.0) - GameWorld.HALF_TILE_SIZE, - GameWorld.TILE_SIZE)
	$BackgroundRender.position = Vector2(( - viewport_size.x / 2.0) - GameWorld.HALF_TILE_SIZE, - GameWorld.TILE_SIZE)

	rock_tiles.position.x = tilemap_size.x / 2 * GameWorld.TILE_SIZE
	$LightSprite.position.x = ( - tilemap_size.x / 2 * GameWorld.TILE_SIZE) - mapToWorldOffset.x
	$ViewportLights.sprite = $LightSprite
	border_deco.position.x = (tilemap_size.x / 2 * GameWorld.TILE_SIZE) + GameWorld.TILE_SIZE
	bg_elements.position.x = (tilemap_size.x / 2 * GameWorld.TILE_SIZE) + GameWorld.HALF_TILE_SIZE
	bg_elements.position.y = GameWorld.TILE_SIZE

	holeImage = prepareTextureAndImage(holeTexture, edge_scaling, Image.FORMAT_RGB8, false, Color.BLACK)
	bgCaveImage = prepareTextureAndImage(bgCaveTexture, 1, Image.FORMAT_RGB8, true, Color.BLACK)
	rockFalloffImage = prepareTextureAndImage(rockFalloffTexture, 1, Image.FORMAT_RGB8, false, Color.BLACK)
	damageImage = prepareTextureAndImage(damageTexture, 2, Image.FORMAT_RGBA8, false, Color(0.0, 0.0, 0.0, 1.0))
	noiseFactorImage = prepareTextureAndImage(noiseFactorTexture, 1, Image.FORMAT_RGB8, false, Color.WHITE)
	biomeColorImage = prepareTextureAndImage(biomeColorTexture, 1, Image.FORMAT_RGB8, false, Color.BLACK)

	var map_scale: Vector2 = viewport_size / Vector2(3768.0, 3768.0)

	fg_mat.set_shader_parameter("mask_map", holeTexture)
	fg_mat.set_shader_parameter("damage_map", damageTexture)
	fg_mat.set_shader_parameter("rock_falloff_map", rockFalloffTexture)
	fg_mat.set_shader_parameter("mask_noise_factor_map", noiseFactorTexture)
	fg_mat.set_shader_parameter("base_scale", map_scale)
	fg_mat.set_shader_parameter("pixel_size", viewport_size)
	fg_mat.set_shader_parameter("light_map", $ViewportLights.get_texture())
	fg_mat.set_shader_parameter("crack_impact", $ViewportCrackImpact.get_texture())
	bg_mat.set_shader_parameter("light_map", $ViewportLights.get_texture())
	bg_mat.set_shader_parameter("bg_alpha_map", $ViewportBackgroundAlpha.get_texture())
	bg_mat.set_shader_parameter("mask_map", holeTexture)
	bg_mat.set_shader_parameter("cave_map", bgCaveTexture)
	bg_mat.set_shader_parameter("base_scale", map_scale)
	bg_mat.set_shader_parameter("pixel_size", viewport_size)

	$BackgroundRender / BackgroundSprite.texture = $ViewportRocks.get_texture()
	$TileRender / MainStones.texture = $ViewportRocks.get_texture()
	$LightSprite.texture = $ViewportLights.get_texture()


	var max_size = tilemap_size

	var bg_cave_spread = [
		Vector2.LEFT, Vector2.RIGHT, 
		Vector2.UP, Vector2.DOWN, 
		Vector2(-1, -1), Vector2(1, 1), 
		Vector2(-1, 1), Vector2(1, -1), 
		]


	for m_x_e in max_size.x:
		rock_tiles.set_cell(MapData.DEFAULT_LAYER, Vector2(m_x_e - max_size.x / 2, -2), 5, Vector2())

	for m_x in max_size.x:
		for m_y in max_size.y:

			var adj_m_y = min(m_y + 1, max_size.y - 1)





			var x_coord = m_x - max_size.x / 2
			var y_coord = m_y - 1

			var bg_cave_col = bgCaveImage.get_pixel(m_x, adj_m_y)
			var bg_cave_img_size = bgCaveImage.get_size()
			var resource = tileData.get_resource(x_coord, y_coord)
			if resource < 10 and resource != -1:
				bg_cave_col.r = 1.0

			var hardness = tileData.get_hardness(x_coord, y_coord)
			if hardness != -1:
				rock_tiles.set_cell(MapData.DEFAULT_LAYER, Vector2(x_coord, y_coord), hardness, Vector2(0, 0))
				var noise_factor_color = Color.BLACK
				if hardness == 5:
					noise_factor_color.r = 1.0
					bg_cave_col.r = 1.0


				hardness = 10 if hardness == 5 else hardness * 0.5
				noise_factor_color.g = float(hardness) / 5.0
				noiseFactorImage.set_pixel(m_x, adj_m_y, noise_factor_color)
			else:
				rock_tiles.set_cell(MapData.DEFAULT_LAYER, Vector2(x_coord, y_coord), 5, Vector2(0, 0))
				bg_cave_col.g = 1.0


			if bg_cave_col.r == 1.0:
				for bcs in bg_cave_spread:
					var spread_coord = Vector2(m_x, m_y) + bcs

					if (spread_coord.x < 0 or spread_coord.y < 0
					or spread_coord.x >= bg_cave_img_size.x
					or spread_coord.y >= bg_cave_img_size.y):
						continue

					var bg_cave_col_s = bgCaveImage.get_pixelv(spread_coord)
					bg_cave_col_s.b = 1.0
					bg_cave_col.b = 1.0
					bgCaveImage.set_pixelv(spread_coord, bg_cave_col_s)

			bgCaveImage.set_pixel(m_x, adj_m_y, bg_cave_col)

			var biome = tileData.get_biome(x_coord, y_coord - 1)
			if biome >= 0:
				biomeColorImage.set_pixel(m_x, m_y, BIOME_LIST[biomes[biome]])
			else:
				biomeColorImage.set_pixel(m_x, m_y, BIOME_LIST[biomes[0]])

	bgCaveImage.generate_mipmaps()
	noiseFactorTexture.set_image(noiseFactorImage)
	biomeColorTexture.set_image(biomeColorImage)
	bgCaveTexture = ImageTexture.create_from_image(bgCaveImage)
	fg_mat.set_shader_parameter("mask_noise_factor_map", noiseFactorTexture)
	fg_mat.set_shader_parameter("biome_color_map", biomeColorTexture)
	bg_mat.set_shader_parameter("biome_color_map", biomeColorTexture)
	bg_mat.set_shader_parameter("cave_map", bgCaveTexture)


	var endY = tilemap_size.y * GameWorld.TILE_SIZE
	$Team1CentralMarker.init(endY)
	$Team2CentralMarker.init(endY)

	if GameWorld.devMode and OS.has_feature("editor") and multiplayer.is_server():
		ResourceSaver.save(Level.map.getTileData().pack(), "res://content/map/data/TileDataInitial.tscn")

	$Critters.init()
	Proximiter.reset(tileData)

	_isMapReady = true if not SaveGame.currentLoadingSavegame or StageManager.isInDeviceSelection() else fromDeserialize
	if _isMapReady:
		map_ready.emit()

func _ready():
	for bgGradientNodes in get_tree().get_nodes_in_group("shader-background-gradient"):
		bgGradientNodes.material.set_shader_parameter("grad_length", 100.0 * $"%Background".scale.y)

	if is_instance_valid(tileData):
		Proximiter.reset(tileData)
	request_ready()

func isMapReady() -> bool:
	return _isMapReady

static func shouldGenerateDrillbertCave() -> bool:
	return GameWorld.isAprilFools and Level.loadout and Level.loadout.modeId == CONST.MODE_RELICHUNT and ( not GameWorld.unlockedRunModifiers.has("drillbert") or Level.loadout.modeConfig.get(CONST.MODE_CONFIG_WORLDMODIFIERS, []).has("drillbert"))

func prepareTextureAndImage(texture: ImageTexture, scaling: float, image_format: int, create_mipmaps: bool, fill_color: Color) -> Image:
	var image: Image = Image.create(tilemap_size.x * scaling, tilemap_size.y * scaling, create_mipmaps, image_format)
	image.fill(fill_color)
	texture = ImageTexture.create_from_image(image)
	return image

func addCaves(minDistanceToCenter: = 10):
	for caveId in cavePlacements:
		var packedScene
		if caveId == "nest":
			packedScene = preload("res://content/map/chamber/nest/NestCave.tscn")
		elif Data.CAVE_SCENES.has(caveId):
			packedScene = Data.CAVE_SCENES[caveId]
		elif Data.SPECIAL_CAVE_SCENES.has(caveId):
			packedScene = Data.SPECIAL_CAVE_SCENES[caveId]
		else:
			push_warning("Could not find scene for caveId ", caveId)
			continue
		for coords in cavePlacements[caveId]:
			var cave = packedScene.instantiate()
			cave.updateUsedTileCoords()

			addLandmark(Utils.parse_vector2(coords), cave)

func getBiomeColorByCoord(_coord: Vector2):
	var biome = tileData.get_biomev(_coord)
	var coord_biome_color = BIOME_LIST[biomes[biome]]
	return coord_biome_color

func addTileDamage(hit_power, health, _direction, _position):
	flashCracks(_position)
	setTileDamage(health, _direction, _position)

func networkSetTileDamage(health: float, direction: Vector2, _position: Vector2) -> void :
	setTileDamage(health, direction, _position)
	Network.rpc_if_state(setTileDamage.bind(health, direction, _position), Network.ConnectionState.LEVEL_STAGE_SYNC)

func networkSetTileHealth(coord: Vector2, health: float) -> void :
	setTileHealth(coord, health)
	Network.rpc_if_state(setTileHealth.bind(coord, health), Network.ConnectionState.LEVEL_STAGE_SYNC)

@rpc("reliable")
func setTileHealth(coord: Vector2, health: float) -> void :
	if not tiles_node.tiles.has(coord):
		return

	tiles_node.tiles[coord].health = health

@rpc("reliable")
func setTileDamage(health, direction, _position):

	_position += Vector2(0, 24)

	if health != 0:
		health = ease((health * 0.6) + 0.4, 1.2)

	if abs(direction.x) > abs(direction.y):
		direction.y = 0
	else:
		direction.x = 0

	var from_dir = direction.normalized().round()
	var modded_pos = (_position / GameWorld.TILE_SIZE) + Vector2(tilemap_size.x / 2, 0.0) + Vector2.DOWN

	modded_pos *= 2
	for x in 2:
		for y in 2:
			var current_pos = modded_pos + Vector2(x, y)
			var current_color_center = damageImage.get_pixelv(current_pos)
			current_color_center.b = health
			damageImage.set_pixelv(current_pos, current_color_center)

			if from_dir.x == -1:

				var current_color = damageImage.get_pixelv(current_pos)
				current_color.r = health
				damageImage.set_pixelv(current_pos, current_color)

			elif from_dir.x == 1:

				var current_color = damageImage.get_pixelv(current_pos + (Vector2.RIGHT * 2))
				current_color.r = health
				damageImage.set_pixelv(current_pos + (Vector2.RIGHT * 2), current_color)

			elif from_dir.y == -1:

				var current_color = damageImage.get_pixelv(current_pos)
				current_color.g = health
				damageImage.set_pixelv(current_pos, current_color)

			elif from_dir.y == 1:

				var current_color = damageImage.get_pixelv(current_pos + (Vector2.DOWN * 2))
				current_color.g = health
				damageImage.set_pixelv(current_pos + (Vector2.DOWN * 2), current_color)

	damageTextureIsDirty = true
	updateDirtyTextures()

const CrackImpact = preload("res://content/map/tile/CrackImpact.tscn")
func flashCracks(_pos: Vector2):

	var tile_pos = _pos + (Vector2(tilemap_size.x / 2, 0.0) * GameWorld.TILE_SIZE)
	tile_pos += Vector2(12, 58)
	var new_impact = CrackImpact.instantiate()
	new_impact.position = tile_pos
	viewport_crack_impact.add_child(new_impact)
	viewport_crack_update = 0.1

func updateDirtyTextures():
	if damageTextureIsDirty:
		damageTextureIsDirty = false
		damageTexture.set_image(damageImage)
		fg_mat.set_shader_parameter("damage_map", damageTexture)

	if holeTextureIsDirty:
		holeTextureIsDirty = false
		holeTexture.set_image(holeImage)
		fg_mat.set_shader_parameter("mask_map", holeTexture)
		bg_mat.set_shader_parameter("mask_map", holeTexture)

	if rockFalloffTextureIsDirty:
		rockFalloffTextureIsDirty = false
		rockFalloffTexture.set_image(rockFalloffImage)
		fg_mat.set_shader_parameter("rock_falloff_map", rockFalloffTexture)


func removeTileVisually(tileCoord: Vector2):
	visuallyRevealedTiles.erase(tileCoord)

	tileCoord += MAP_TO_TEXTURE_OFFSET_COORD

	var draw_pos_es = (Vector2(tileCoord.x, tileCoord.y) + Vector2(tilemap_size.x / 2, 0)) * edge_scaling
	var draw_pos = (Vector2(tileCoord.x, tileCoord.y) + Vector2(tilemap_size.x / 2, 0))

	for x in edge_scaling:
		for y in edge_scaling:
			holeImage.set_pixelv(draw_pos_es + Vector2(x, y), Color.WHITE)
	holeTextureIsDirty = true

	var rock_falloff_color = rockFalloffImage.get_pixelv(draw_pos)
	rock_falloff_color.r = 1.0
	rockFalloffImage.set_pixelv(draw_pos, rock_falloff_color)
	rockFalloffTextureIsDirty = true

	var offsets = get("BORDER_TILE_OFFSETS" + str(Data.of("map.revealdistance")))
	for offset in offsets:
		var drawpos_offset = draw_pos + offset
		if drawpos_offset.y < 0:
			continue
		var rock_falloff_color_offset = rockFalloffImage.get_pixelv(drawpos_offset)
		rock_falloff_color_offset.g = 1.0
		rockFalloffImage.set_pixelv(drawpos_offset, rock_falloff_color_offset)


	var rock_falloff_image_size: = rockFalloffImage.get_size()

	if not ((draw_pos.x < 0 or draw_pos.x > rock_falloff_image_size.x)
		or (draw_pos.y < 0 or draw_pos.y > rock_falloff_image_size.y)):

		var cell_color: float = rockFalloffImage.get_pixelv(draw_pos).r
		if cell_color == 1:
			for x in 2:
				for y in 2:

					var red_coord = ((draw_pos) * 2) + Vector2(x + 2, y)
					var oc_r: Color = damageImage.get_pixelv(red_coord)
					oc_r.r = 0
					damageImage.set_pixelv(red_coord, oc_r)


					var green_coord = ((draw_pos) * 2) + Vector2(x, y + 2)
					var oc_g: Color = damageImage.get_pixelv(green_coord)
					oc_g.g = 0
					damageImage.set_pixelv(green_coord, oc_g)


					var final_coord = ((draw_pos) * 2) + Vector2(x, y)
					damageImage.set_pixelv(final_coord, Color.BLACK)
			damageTextureIsDirty = true

func saveDebugImagesFG():
	$ViewportLights.get_texture().get_image().save_png("res://content/map/shaders/debugimages/lightsprite_texture.png")
	$ViewportCrackImpact.get_texture().get_image().save_png("res://content/map/shaders/debugimages/foreground_crack_impact.png")
	damageImage.save_png("res://content/map/shaders/debugimages/foreground_damage_map.png")
	holeImage.save_png("res://content/map/shaders/debugimages/foreground_mask_map.png")
	damageImage.save_png("res://content/map/shaders/debugimages/foreground_damage_map.png")
	rockFalloffImage.save_png("res://content/map/shaders/debugimages/foreground_rock_falloff_map.png")
	noiseFactorImage.save_png("res://content/map/shaders/debugimages/foreground_mask_noise_factor_map.png")
	biomeColorImage.save_png("res://content/map/shaders/debugimages/foreground_biome_color_map.png")
	var file = FileAccess.open("res://content/map/shaders/debugimages/foreground_shader_uniforms.txt", FileAccess.WRITE)
	var viewport_size = tilemap_size * GameWorld.TILE_SIZE
	var shaderSettings: = "base_scale: %s | pixel_size: %s" % [var_to_str(viewport_size / Vector2(3768.0, 3768.0)), var_to_str(viewport_size)]
	file.store_var(shaderSettings)

func saveDebugImagesBG():
	$ViewportBackgroundAlpha.get_texture().get_image().save_png("res://content/map/shaders/debugimages/background_bg_alpha_map.png")
	$ViewportRocks.get_texture().get_image().save_png("res://content/map/shaders/debugimages/background_texture.png")
	holeImage.save_png("res://content/map/shaders/debugimages/background_mask_map.png")
	bgCaveImage.save_png("res://content/map/shaders/debugimages/background_cave_map.png")
	biomeColorImage.save_png("res://content/map/shaders/debugimages/background_biome_color_map.png")
	var file = FileAccess.open("res://content/map/shaders/debugimages/backround_shader_uniforms.txt", FileAccess.WRITE)
	var viewport_size = tilemap_size * GameWorld.TILE_SIZE
	var shaderSettings: = "base_scale: %s | pixel_size: %s" % [var_to_str(viewport_size / Vector2(3768.0, 3768.0)), var_to_str(viewport_size)]
	file.store_var(shaderSettings)

func floodRevealTiles(forceUpdate: = false):
	var closedCells: = {}
	var offsets = get("NEIGHBOR_TILE_OFFSETS" + str(Data.of("map.revealdistance")))
	while not tileCoordsToReveal.is_empty():
		var cell: Vector2 = tileCoordsToReveal.pop_back()
		closedCells[cell] = true
		if tileData.get_hardnessv(cell) <= -1:

			continue

		var resv = tileData.get_resourcev(cell)
		if resv == -1:

			if not visibleTileCoords.has(cell) or visibleTileCoords[cell] != -1:
				visibleTileCoords[cell] = -1
				revealTile(cell)
				onTileRemoved(cell)
				removeTileVisually(cell)


			for d in offsets:
				if closedCells.has(cell + d):

					continue
				if visibleTileCoords.has(cell + d) and not forceUpdate:

					continue


				tileCoordsToReveal.append(cell + d)
		else:

			if not visibleTileCoords.has(cell) or visibleTileCoords[cell] != resv:
				revealTile(cell)

	updateDirtyTextures()


func removeAllEmptyBorderTilesVisually():
	var map: = {}
	for x in visibleTileCoords:
		if visibleTileCoords[x] == -1:
			map[x] = true

	for x in map:
		var count: = 0
		for y in NEIGHBOR_TILE_OFFSETS1:
			if map.has(x + y):
				count += 1


		if count < 4:
			removeTileVisually(x)

	updateDirtyTextures()




func revealTileVisually(_pos: Vector2):
	if revealTileVisuallyWithoutTexturesUpdate(_pos):
		updateDirtyTextures()

func revealTileVisuallyWithoutTexturesUpdate(_pos: Vector2):
	if visuallyRevealedTiles.has(_pos):
		return false
	visuallyRevealedTiles[_pos] = true


	_pos += Vector2.DOWN
	if _pos.y < 0:
		return false

	var draw_pos = (Vector2(floor(_pos.x), floor(_pos.y + 1)) + Vector2(tilemap_size.x / 2, 0))
	var rock_falloff_color = rockFalloffImage.get_pixelv(draw_pos)
	rock_falloff_color.r = 1.0
	rockFalloffImage.set_pixelv(draw_pos, rock_falloff_color)
	rockFalloffTextureIsDirty = true

	return true

func revealInitialState(startVector: = Vector2(0, -1)):
	tileCoordsToReveal.append_array(tileData.get_entry_coords(true))
	if not tileCoordsToReveal.has(startVector):
		tileCoordsToReveal.append(startVector)
	floodRevealTiles()

	onRevealDecorators.clear()
	var hiddenCaveCells: = []
	for cell in tileData.getRevealedCells():
		if not visibleTileCoords.has(cell):
			hiddenCaveCells.append(cell)
	var currentDecorator
	var closedCells: = []

	while not hiddenCaveCells.is_empty():
		var starterCell = hiddenCaveCells.pop_back()
		var openCells: = [starterCell]
		currentDecorator = preload("res://content/map/decorations/OnRevealDecorator.gd").new()
		onRevealDecorators.append(currentDecorator)
		addTileRevealedListener(currentDecorator, starterCell)
		while openCells.size() > 0:
			var cell = openCells.pop_back()
			closedCells.append(cell)
			hiddenCaveCells.erase(cell)
			if tileData.get_resourcev(cell) == -1 and tileData.get_hardnessv(cell) >= 0:
				currentDecorator.addCell(cell)
				for d in CONST.DIRECTIONS:
					var newCoord = Vector2(cell) + d
					if not closedCells.has(newCoord) and not openCells.has(newCoord):
						openCells.append(newCoord)

func _process(delta):
	if GameWorld.devMode and Input.is_action_just_pressed("num6"):
		var i = randi()
		holeImage.save_png("../" + str(i) + "holeImage.png")
		rockFalloffImage.save_png("../" + str(i) + "rockFalloffImage.png")
		damageImage.save_png("../" + str(i) + "damageImage.png")
		bgCaveImage.save_png("../" + str(i) + "bgCaveImage.png")
		biomeColorImage.save_png("../" + str(i) + "biomeColorImage.png")
		noiseFactorImage.save_png("../" + str(i) + "noiseFactorImage.png")
	if GameWorld.devMode and Input.is_action_just_pressed("num7"):
		saveDebugImagesFG()
		saveDebugImagesBG()
	if not GameWorld.paused:
		if viewport_crack_update > 0.0:
			viewport_crack_update -= delta
			viewport_crack_impact.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		else:
			viewport_crack_impact.render_target_update_mode = SubViewport.UPDATE_DISABLED

func growTile(coord: Vector2, type: int):
	tileData.set_resourcev(coord, type)
	revealTile(coord)

func networkRevealTile(coord: Vector2, delay: float) -> void :
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	Network.rpc_if_state(remoteRevealTile.bind(coord), Network.ConnectionState.LEVEL_STAGE_SYNC, true)

@rpc("reliable", "any_peer")
func remoteRevealTile(coord: Vector2) -> void :
	revealTile(coord)
	revealTileVisually(coord)

func revealTile(coord: Vector2):


	coord = Vector2(int(coord.x), int(coord.y))
	var invalids: = []
	if tileRevealedListeners.has(coord):
		for listener in tileRevealedListeners[coord]:
			if is_instance_valid(listener):
				listener.tileRevealed(coord)
			else:
				invalids.append(listener)
		for invalid in invalids:
			tileRevealedListeners.erase(invalid)

	var typeId: int = tileData.get_resource(coord.x, coord.y)
	if typeId == Data.TILE_EMPTY:
		return

	if tiles.has(coord):
		return

	var tile = tile_scene.instantiate()
	var biomeId: int = tileData.get_biome(coord.x, coord.y)
	tile.layer = biomeId
	tile.biome = biomes[tile.layer]
	tile.position = coord * GameWorld.TILE_SIZE
	tile.coord = coord

	tile.hardness = tileData.get_hardness(coord.x, coord.y)

	tile.type = Data.TILE_ID_TO_STRING_MAP.get(typeId, "dirt")
	match tile.type:
		CONST.IRON:
			tile.richness = Data.ofOr("map.ironrichness", 2)
			revealTileVisually(coord)
		CONST.SAND:
			tile.richness = Data.ofOr("map.cobaltrichness", 2)
			revealTileVisually(coord)
		CONST.WATER:
			tile.richness = Data.ofOr("map.waterrichness", 2.5)
			revealTileVisually(coord)
	tiles[coord] = tile

	if tilesByType.has(tile.type):
		tilesByType[tile.type].append(tile)
	tile.connect("destroyed", destroyTile.bind(tile))

	tiles_node.add_tile(tile)


	visibleTileCoords[coord] = typeId

func destroyTile(teamId: String, keeperTechId: String, tile: Tile):
	var sound: Sound
	match tile.type:
		CONST.IRON:
			sound = $TileDestroyedIron.duplicate(Node.DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
		CONST.WATER:
			sound = $TileDestroyedWater.duplicate(Node.DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
		CONST.SAND:
			sound = $TileDestroyedSand.duplicate(Node.DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
		CONST.GADGET:
			sound = $TileDestroyedChamber.duplicate(Node.DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
		CONST.POWERCORE:
			sound = $TileDestroyedChamber.duplicate(Node.DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
		CONST.RELIC:
			sound = $TileDestroyedChamber.duplicate(Node.DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
		_:
			var useKeeper4Sounds: bool = keeperTechId == "keeper4"
			if useKeeper4Sounds:
				sound = $TileDestroyedKeeper4.duplicate(Node.DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
			else:
				sound = $TileDestroyed.duplicate(Node.DuplicateFlags.DUPLICATE_USE_INSTANTIATION)
	sound.setSimulatedPosition(tile.global_position)
	add_child(sound)
	sound.startSound()

	if tile.type == CONST.IRON:

		currentIronCountByLayer[tile.layer] = currentIronCountByLayer[tile.layer] - 1

	if tile.hardness == 5:

		buildBorderAroundTile(tile.coord, tileData.get_biomev(tile.coord))

	tiles.erase(tile.coord)
	for t in tilesByType.values():
		t.erase(tile)
	tilesByType.get(tile.type, {}).erase(tile)
	tile.queueDelete()

	onTileRemoved(tile.coord)


	tileCoordsToReveal.append(tile.coord)
	floodRevealTiles()

	if not is_inside_tree() or not is_server():
		return

	Data.changeByInt("map.tilesDestroyed", 1)
	Recorder.recordTileDestroyed(tile.coord)

	if tile.type == CONST.IRON or tile.type == CONST.SAND or tile.type == CONST.WATER:
		var goalRichness = tile.richness * Data.ofOr("resourcemodifiers.richness." + tile.type, 1.0)
		var drops = floor(goalRichness - 1 + (randi() % 3))
		if tile.type == CONST.IRON:
			if not firstDropByTeam.has(teamId):

				firstDropByTeam.append(teamId)
				drops = 2
		var newDelta = dropDeltas.get(tile.type, 0) + drops - goalRichness
		if newDelta >= 3:
			drops -= 1
			newDelta -= 1
		elif newDelta <= -3:
			drops += 1
			newDelta += 1
		dropDeltas[tile.type] = newDelta

		if tile.type == CONST.SAND and drops < 3 and Level.loadout.modeId == CONST.MODE_RELICHUNT and Level.difficulty() <= 0:

			var sandWithFloating = Data.of("team1.inventory.sand") + Data.of("inventory.floatingsand")
			if Data.of("team1.dome.health") < 350 - 60 * sandWithFloating:
				drops += 1
		if drops < 3 and Level.difficulty() * 0.1 < - randf():
			drops += 1

		for _i in range(0, drops):
			spawnDrop(tile, teamId)

func is_server() -> bool:
	return multiplayer.is_server()

func spawnDrop(tile: Tile, teamId: String) -> void :
	var data: = {}
	data["type"] = tile.type
	data["position"] = tile.global_position + 0.6 * Vector2(GameWorld.HALF_TILE_SIZE - randf() * GameWorld.TILE_SIZE, GameWorld.HALF_TILE_SIZE - randf() * GameWorld.TILE_SIZE)
	data["impulse"] = Vector2(0, 40).rotated(randf() * TAU)
	drop_system.network_spawn(data)
	GameWorld.incrementRunStat("resources_mined", teamId)

func onTileRemoved(tileCoord: Vector2):
	tileData.clear_resource(tileCoord)

	for listener in tileDestroyedListeners.get(tileCoord, []):
		listener.tileDestroyed(tileCoord)

	pathfinder.add_point_in_coord(tileCoord)

	for n in NEIGHBOR_TILE_OFFSETS1:
		var c = n + tileCoord
		if not tiles.has(c):
			pathfinder.try_connect_coord(tileCoord, c)

	updateBorderSpriteOfTileCoord(tileCoord)

	for c in tileData.get_entry_coords():
		if c.x == tileCoord.x:
			updateLiftLength(tileCoord.x)

	var world_tile_pos: Vector2 = getTilePos(tileCoord)
	tile_destroyed.emit(world_tile_pos)

func updateBorderSpriteOfTileCoord(tileCoord: Vector2):
	for x in range(-1, 1):
		for y in range(-1, 1):
			updateBorderSprite(tileCoord.x + x, tileCoord.y + y)

func changeTileType(tile, typeId: int):
	tiles_node.network_change_tile_type(tile.coord, typeId)



func addTileRevealedListener(listener, coord: Vector2):
	var listeners: Array

	if tileRevealedListeners.has(coord):
		listeners = tileRevealedListeners[coord]
	else:
		listeners = []
		tileRevealedListeners[coord] = listeners
	listeners.append(listener)

func removeTileRevealedListener(listener, coord: Vector2):
	if tileRevealedListeners.has(coord):
		var listeners = tileRevealedListeners.get(coord)
		listeners.erase(listener)
		tileRevealedListeners[coord] = listeners



func addTileDestroyedListener(listener, coord: Vector2):
	var listeners: Array
	if tileDestroyedListeners.has(coord):
		listeners = tileDestroyedListeners[coord]
	else:
		listeners = []
		tileDestroyedListeners[coord] = listeners
	listeners.append(listener)

func removeTileDestroyedListener(listener, coord: Vector2):
	if tileDestroyedListeners.has(coord):
		var listeners = tileDestroyedListeners.get(coord)
		listeners.erase(listener)
		tileDestroyedListeners[coord] = listeners

func findPath(fromPos: Vector2, toPos: Vector2, teamId: String):
	var fromCoord = Vector2(getTileCoord(fromPos)) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET
	if fromCoord.y < 0:
		var dome: Dome = Level.domesByTeamId[teamId]
		var yPos = (Vector2(0, -1) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET).y
		var xPos = dome.global_position.x
		var fromDomePos: = Vector2(xPos, yPos)
		fromCoord = fromDomePos
	var toCoord = Vector2(getTileCoord(toPos)) * GameWorld.TILE_SIZE + CONST.TILE_OFFSET

	return pathfinder.findPath(fromCoord, toCoord)

func updateBorderSprite(x: int, y: int):
	var key = Vector2(x, y)
	border_deco.markDirtyTile(key)
	var r_tl: int = tileData.get_resource(x, y)
	var r_tr: int = tileData.get_resource(x + 1, y)
	var r_br: int = tileData.get_resource(x + 1, y + 1)
	var r_bl: int = tileData.get_resource(x, y + 1)
	var borderLayout = int(r_tl > Data.TILE_EMPTY) * 1 + int(r_tr > Data.TILE_EMPTY) * 2 + int(r_br > Data.TILE_EMPTY) * 4 + int(r_bl > Data.TILE_EMPTY) * 8
	var tileMeta = borderSprites.get(key, null)
	if borderLayout > 0:
		if not tileMeta:
			var biome_id_tl: int = tileData.get_biome(x, y)
			var biome_id_tr: int = tileData.get_biome(x + 1, y)
			var biome_id_bl: int = tileData.get_biome(x, y + 1)
			var biome_id_br: int = tileData.get_biome(x + 1, y + 1)
			var biomeEdgeCase: = biome_id_tl != biome_id_tr or biome_id_tr != biome_id_bl or biome_id_bl != biome_id_br
			var biome: = "mixed"
			if not biomeEdgeCase:
				biome = biomes[biome_id_tl]
			tileMeta = [borderLayout, biome, {}]
			borderSprites[key] = tileMeta

			var overlays: Dictionary = tileMeta[2]
			for typeId in [Data.TILE_IRON, Data.TILE_SAND, Data.TILE_WATER]:
				if r_tl == typeId or r_tr == typeId or r_bl == typeId or r_br == typeId:
					var overlay = RESOURCE_BORDER_OVERLAY.instantiate()
					overlay.material = overlay.material.duplicate()
					overlay.position.x = x * GameWorld.TILE_SIZE + borderSpriteOffset.x
					overlay.position.y = y * GameWorld.TILE_SIZE + borderSpriteOffset.y
					overlay.name = "%dx%d" % [key.x, key.y]
					tile_borders_node.add_child(overlay)
					overlays[typeId] = overlay
					Style.init(overlay)

		assert (tileMeta.size() == 3)
		tileMeta[0] = borderLayout

		var overlays: Dictionary = tileMeta[2]
		var has_empty: bool = r_tl == Data.TILE_EMPTY or r_tr == Data.TILE_EMPTY or r_br == Data.TILE_EMPTY or r_bl == Data.TILE_EMPTY
		for ok in tileMeta[2]:
			var offset: = Vector2()
			match ok:
				Data.TILE_IRON:
					offset.y += 8
				Data.TILE_WATER:
					offset.y += 4
			overlays[ok].set_frame_coords(layouts[borderLayout] + offset)
			overlays[ok].material.set_shader_parameter("frame_coords", layouts[borderLayout] + offset)
			overlays[ok].material.set_shader_parameter("hide_tl", float(r_tl != ok or not has_empty))
			overlays[ok].material.set_shader_parameter("hide_tr", float(r_tr != ok or not has_empty))
			overlays[ok].material.set_shader_parameter("hide_bl", float(r_bl != ok or not has_empty))
			overlays[ok].material.set_shader_parameter("hide_br", float(r_br != ok or not has_empty))
	elif borderSprites.has(key):
		assert (tileMeta.size() == 3)
		for ok in tileMeta[2]:
			tileMeta[2][ok].queue_free()
		borderSprites.erase(key)
		border_deco.markDirtyTile(key)

func addTileOverlayEffect(overlay):
	$TileOverlays.add_child(overlay)

func getSceneForTileType(tileType: int) -> PackedScene:
	match tileType:
		Data.TILE_GADGET: return preload("res://content/map/chamber/gadget/GadgetChamber.tscn")
		Data.TILE_RELIC: return preload("res://content/map/chamber/relic/RelicChamber.tscn")
		Data.TILE_NEST: return preload("res://content/map/chamber/nest/NestCave.tscn")
		Data.TILE_RELIC_SWITCH: return preload("res://content/map/chamber/relicswitch/RelicSwitchChamber.tscn")
		Data.TILE_SUPPLEMENT: return preload("res://content/map/chamber/supplement/PowerCoreChamber.tscn")
		_: return null

func addChamber(coord: Vector2, scene: PackedScene):
	var chamber = scene.instantiate()
	addLandmark(coord, chamber)
	for c in chamber.tileCoords:
		var absCoord = chamber.coord + Vector2(c)
		if tileData.get_cell_source_id(MapData.LAYER_RESOURCES, absCoord) == CONST.TILEMAP_INVALID_CELL:
			continue
		addTileDestroyedListener(chamber, absCoord)
		tileData.set_resourcev(absCoord, chamber.getTileType())

	return chamber

func addCave(rand, cave, biomeIndex, minDistanceToCenter):
	cave.updateUsedTileCoords()


	for _i in 30:
		var cells = tileData.get_biome_cells_by_index(biomeIndex)
		if cells.size() < cave.tileCoords.size():
			return

		var cell = cells[rand.randi() % cells.size()]
		if abs(cell.x) < minDistanceToCenter:
			continue

		if not tileData.is_area_free(cell, cave.tileCoords):
			continue

		addLandmark(cell, cave)
		for c in cave.tileCoords:
			var absCoord = Vector2(cell) + c
			tileData.clear_resource(absCoord)
		return

	Logger.error("failed to place cave", "Map.addCave", {"biomeIndex": biomeIndex, "cave": cave.scene_file_path})

func addLandmark(coord: Vector2, landmark):
	landmark.place(coord)
	var landmarkBiome = tileData.get_biomev(landmark.coord)

	for c in landmark.tileCoords:
		var absCoord = landmark.coord + Vector2(c)
		addTileRevealedListener(landmark, absCoord)
		tileData.set_biomev(absCoord, landmarkBiome)
		tileData.set_hardnessv(absCoord, clamp(tileData.get_hardnessv(absCoord), 0, 4))
		border_deco.markTileUndecoratable(absCoord)
		landmark_coords[absCoord] = true


	for c in landmark.tileCoords:
		for neighborsOffset in NEIGHBOR_TILE_OFFSETS_DIAG:
			var landmarkCoord = Vector2(c) + neighborsOffset
			if landmark.tileCoords.has(landmarkCoord):
				continue

			var neighborCoord = landmark.coord + landmarkCoord
			if tileData.get_biomev(neighborCoord) < 0:
				tileData.set_biomev(neighborCoord, tileData.get_biomev(coord))
				tileData.set_resourcev(neighborCoord, Data.TILE_BORDER)
				tileData.set_hardnessv(neighborCoord, Data.HARDNESS_INDESTRUCTIBLE)

	if GameWorld.devMode:
		print("placed " + landmark.name + " at " + str(coord))
	tiles_node.add_child(landmark, true)

func revealCave(cave):
	for c in cave.tileCoords:
		var absCoord = cave.coord + c
		revealTile(absCoord)
		removeTileVisually(absCoord)
	updateDirtyTextures()

func addDrop(drop):
	add_child(drop)

func freeTiles(tileCoords: Array) -> int:
	var destroyed: = 0
	for c in tileCoords:
		if tiles.has(c):
			var tile = tiles[c]
			if tile.has_meta("destructable") and Data.isDestructable(tile):
				tile.hit(Vector2(0, -1), tile.health, "cheats")
				destroyed += 1
	return destroyed

func damageTileDirection(pos: Vector2, dir: Vector2i, distance: int, damage: float, teamId: String, delay: = 0.0):
	if delay > 0.0:
		$Tween.interpolate_callback(self, delay, "damageTileDirection", pos, dir, distance, damage, teamId)
		$Tween.start()
		return

	var startCoord = Vector2(getTileCoord(pos) + dir)
	for i in distance:
		var coord = startCoord + Vector2(dir * i)
		if tiles.has(coord):
			var tile = tiles.get(coord)
			if Data.isDestructable(tile):
				var v = coord - startCoord

				tile.exploded = true
				tile.hit(v, tile.max_health + 1, teamId)
		elif is_tile_empty(coord):
			network_spawn_tile_break_particles(coord, getTilePos(coord), Vector2(), "default", true, false)

		await get_tree().create_timer(0.08).timeout
		while GameWorld.paused:
			await get_tree().create_timer(0.08).timeout

func network_spawn_tile_break_particles(coord, location, direction, type, explosion, spawn_dirt) -> void :
	Network.rpc_if_state(spawn_tile_break_particles.bind(coord, location, direction, type, explosion, spawn_dirt), Network.ConnectionState.LEVEL_STAGE_SYNC, true)

@rpc("reliable", "any_peer")
func spawn_tile_break_particles(coord, location, direction, type, explosion, spawn_dirt) -> void :
	Tile.spawn_tile_break_particles(self, coord, location, direction, type, explosion, spawn_dirt)

func is_tile_empty(coord):
	return tileData.get_hardnessv(coord) > -1 and tileData.get_resourcev(coord) == -1

func is_landmark_tile(coord: Vector2) -> bool:
	return landmark_coords.has(coord)

func damageTileCircleArea(pos: Vector2, radius: float, damage: float, teamId: String, delay: = 0.0, offset: Vector2 = Vector2.ZERO):
	if delay > 0.0:
		$Tween.interpolate_callback(self, delay, "damageTileCircleArea", pos, radius, damage, teamId, 0.0, offset)
		$Tween.start()
		return

	var explosionCenterCoord = Vector2(getTileCoord(pos + offset))
	var startCoord = Vector2(getTileCoord(pos))
	var open: = [startCoord]
	var closed: = []
	while open.size() > 0:
		var newOpen: = []
		for coord in open:
			if closed.has(coord):
				continue

			for off in NEIGHBOR_TILE_OFFSETS1:
				var c2 = off + Vector2(coord)
				if (c2 - explosionCenterCoord).length() <= radius and not closed.has(c2) and not newOpen.has(c2):
					newOpen.append(c2)

			if tiles.has(coord):
				var tile = tiles.get(coord)
				if Data.isDestructable(tile):
					var v = coord - explosionCenterCoord

					tile.exploded = true
					tile.hit(v, tile.max_health + 1, teamId)
			elif is_tile_empty(coord):
				network_spawn_tile_break_particles(coord, getTilePos(coord), Vector2(), "default", true, false)
			closed.append(coord)

		await get_tree().create_timer(0.08).timeout
		while GameWorld.paused:
			await get_tree().create_timer(0.08).timeout
		open = newOpen

func getTileCoord(pos: Vector2) -> Vector2i:
	return tileData.local_to_map(pos + mapToWorldOffset)

func getTilePos(coord: Vector2) -> Vector2:
	return tileData.map_to_local(coord) + tileData.position

func addMineShaftGadget(gadget, teamId: String):
	var dome = Level.domesByTeamId[teamId]
	gadget.teamId = teamId
	gadget.position.x = dome.position.x


	gadget.name = teamId + "-" + gadget.name
	add_child(gadget)
	updateLiftLength(dome.position.x / GameWorld.TILE_SIZE)

func updateLiftLength(coordX: int):
	var goalY: = 0
	var potentialTilesToConvert: = []
	var tilesToConvert: = []
	var lastBiome: int
	for y in tileData.getSize().y + 20:
		var hardness = tileData.get_hardness(coordX, y)


		if tileData.get_resource(coordX, y) == -1 and hardness >= 0:

			goalY = y + 1
			lastBiome = tileData.get_biome(coordX, y)
			if potentialTilesToConvert.size() > 0:
				tilesToConvert = potentialTilesToConvert.duplicate()
			potentialTilesToConvert.clear()
		elif hardness >= 0 and hardness <= 4:

			break
		else:
			potentialTilesToConvert.append(y)

	var hadGadgetAtX: = false
	var teamId: = ""
	var tree: = get_tree()
	if tree:
		for gadget in tree.get_nodes_in_group("shaft-gadget"):
			if int(gadget.position.x / GameWorld.TILE_SIZE) == coordX:
				for i in range(gadget.tileLength, goalY):
					border_deco.markTileUndecoratable(Vector2(coordX, i))
					border_deco.markTileUndecoratable(Vector2(coordX - 1, i))
				gadget.setLength(goalY)
				hadGadgetAtX = true
				teamId = gadget.teamId

	if hadGadgetAtX and tilesToConvert.size() > 0:
		var t = create_tween()
		var delay: = 0.5
		for y in tilesToConvert:
			t.tween_callback(createEmptyTile.bind(Vector2(coordX, y), lastBiome, teamId)).set_delay(delay)
			delay = 1.5

func createEmptyTile(coord: Vector2, biome, teamId: String):
	if tiles.has(coord):
		destroyTile(teamId, "", tiles.get(coord))
	else:
		tileData.set_biomev(coord, biome)
		tileData.set_hardnessv(coord, 1)

	buildBorderAroundTile(coord, biome)

func buildBorderAroundTile(coord, biome):
	for dir in CONST.DIRECTIONS_AND_DIAGONALS:
		var otherCoord = coord + dir
		if tiles.has(otherCoord) or tileData.get_hardnessv(otherCoord) != -1:
			continue
		tileData.set_biomev(otherCoord, biome)
		tileData.set_hardnessv(otherCoord, Data.HARDNESS_INDESTRUCTIBLE)
		tileData.set_resourcev(otherCoord, Data.TILE_BORDER)
	tileCoordsToReveal.append(coord)
	floodRevealTiles()

func getProgress() -> float:
	var layerCount = startingIronCountByLayer.size()
	if layerCount == 0:
		return 0.0

	var progress = 0.0
	for layer in startingIronCountByLayer:
		progress += 1.0 - (currentIronCountByLayer[layer] / float(startingIronCountByLayer[layer]))
	progress /= layerCount
	return progress

func isResourceTile(typeId: int) -> bool:
	return typeId == Data.TILE_IRON or typeId == Data.TILE_SAND or typeId == Data.TILE_WATER

func isCaveTile(coord: Vector2) -> bool:
	var res = tileData.get_resourcev(coord)
	var bio = tileData.get_biomev(coord)
	return bio >= 0 and res < 0

func isRevealed(coord: Vector2) -> bool:
	return tiles.has(coord)

func getTile(coord: Vector2):
	return tiles.get(coord, null)

func serialize() -> Dictionary:
	var tileSpecial = {}
	for t in tiles.keys():
		if tiles[t].health < tiles[t].max_health or tiles[t].hasTileOverlay():
			tileSpecial[var_to_str(t)] = tiles[t].serialize()
	var data = {
		"TileSpecial": tileSpecial, 
		"dropDeltas": dropDeltas, 
		"Biomes": biomes, 
		"StartingIronCountByLayer": startingIronCountByLayer, 
		"CurrentIronCountByLayer": currentIronCountByLayer, 
		"initialUsedRect": var_to_str(initialUsedRect), 
		"revealedTiles": Marshalls.raw_to_base64(var_to_bytes(tiles.keys())), 
		"visuallyRevealedTiles": Marshalls.raw_to_base64(var_to_bytes(visuallyRevealedTiles.keys())), 
		"chamberPlacements": chamberPlacements, 
		"cavePlacements": cavePlacements
	}
	return data

func deserialize(data: Dictionary):
	tileDestroyedListeners = {}
	tileRevealedListeners = {}
	for child in tiles_node.get_children():
		child.free()

	if data.has("Biomes"):
		biomes = data["Biomes"]

	chamberPlacements = data.get("chamberPlacements", {})
	cavePlacements = data.get("cavePlacements", {})

	init(true)

	if data.has("revealedTiles"):
		var tilesStr = Marshalls.base64_to_raw(data["revealedTiles"])
		var tiles = bytes_to_var(tilesStr)
		tileCoordsToReveal.append_array(tiles)
	revealInitialState()

	if data.has("visuallyRevealedTiles"):
		var tilesStr = Marshalls.base64_to_raw(data["visuallyRevealedTiles"])
		var tiles = bytes_to_var(tilesStr)
		for x in tiles:
			revealTileVisuallyWithoutTexturesUpdate(x)

	if data.has("StartingIronCountByLayer"):
		startingIronCountByLayer = {}
		for key in data["StartingIronCountByLayer"].keys():
			startingIronCountByLayer[int(key)] = data["StartingIronCountByLayer"][key]

	if data.has("CurrentIronCountByLayer"):
		currentIronCountByLayer = {}
		for key in data["CurrentIronCountByLayer"].keys():
			currentIronCountByLayer[int(key)] = data["CurrentIronCountByLayer"][key]

	dropDeltas = data.get("dropDeltas", {})
	initialUsedRect = str_to_var(data.get("initialUsedRect", null))


	for t in tileCoordsToReveal:
		revealTile(t)
	tileCoordsToReveal.clear()

	if data.has("TileSpecial"):
		for key in data["TileSpecial"].keys():
			var t = BackwardCompatibilityUtils.str_to_var(key)
			if tiles.has(t):
				tiles[t].deserialize(data["TileSpecial"][key])

	updateDirtyTextures()

func hideTiles():
	for gadget in get_tree().get_nodes_in_group("shaft-gadget"):
		gadget.hide()

	tiles_node.hide()
	tile_borders_node.hide()
	border_deco.hide()
	$TileRender.hide()
	$BackgroundRender.hide()
	$LightSprite.hide()

func showTiles():
	for gadget in get_tree().get_nodes_in_group("shaft-gadget"):
		gadget.show()
	tiles_node.show()
	tile_borders_node.show()
	border_deco.show()
	$TileRender.show()
	$BackgroundRender.show()
	$LightSprite.show()

func getTileData() -> MapData:
	return tileData

func decorations():
	return border_deco

func getBiomeOfCoord(coord: Vector2) -> String:
	var b = tileData.get_biomev(coord)
	if b >= 0 and b < biomes.size():
		return biomes[b]
	else:
		return ""

func getLayerOfCoord(coord: Vector2) -> int:
	var b = tileData.get_biomev(coord)
	return b

func addSpriteToBGAlpha(_new_sprite: Sprite2D):
	var bg_alpha_pos_offset = Vector2($ViewportBackgroundAlpha.size.x / 2, 48)
	var alpha_sprite_pos = _new_sprite.global_position + bg_alpha_pos_offset + mapToWorldOffset
	var alpha_sprite = _new_sprite.duplicate()
	alpha_sprite.show()
	$ViewportBackgroundAlpha / AlphaImages.add_child(alpha_sprite)
	alpha_sprite.position = alpha_sprite_pos
	$ViewportBackgroundAlpha.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	$ViewportBackgroundAlpha.render_target_update_mode = SubViewport.UPDATE_ONCE

func toggleTileDataVisibility():
	tileData.visible = !tileData.visible

@onready var viewportTopEffectsAnchor = $"%ViewportTopEffectsAnchor"
func addPixelEffect(node: Node2D):
	viewportTopEffectsAnchor.add_child(node)

func registerAdditionalEffect(effect):
	$AdditionalEffects.add_child(effect)

func getAdditionalEffects() -> Array:
	return $AdditionalEffects.get_children()

func isWithinBounds(coord) -> bool:
	if coord.y < 0:
		return false
	if coord.x <= initialUsedRect.position.x or coord.x >= initialUsedRect.end.x:
		return false
	if coord.y >= initialUsedRect.end.y:
		return false
	return true

func getTileStateData() -> PackedByteArray:
	var data: = {}
	for tile: Tile in tiles.values():
		if tile.health < tile.max_health or tile.hasTileOverlay():
			var tileData: = {}
			tileData["health"] = tile.health
			tileData["max_health"] = tile.max_health
			tileData["tileOverlayType"] = tile.tileOverlayType
			if tile.hasTileOverlay():
				var buffer: PackedByteArray
				if tile.tileOverlay.has_method("to_bytes"):
					buffer = tile.tileOverlay.to_bytes()
				else:
					buffer = var_to_bytes(tile.tileOverlay.serialize())
				tileData["tileOverlay"] = buffer
			data[tile.coord] = tileData

	return var_to_bytes(data)

func setTileStateData(tileStateData: PackedByteArray) -> void :
	var dataDictionary: Dictionary = bytes_to_var(tileStateData)

	for coord in dataDictionary.keys():
		if not tiles.has(coord):
			continue

		var data = dataDictionary[coord]
		var tile: Tile = tiles[coord]
		tile.health = data["health"]
		var tileOverlayType = data.get("tileOverlayType", "")
		if tileOverlayType != "":
			tile.setTileOverlay(data.get("tileOverlayType", ""))
			var buffer: PackedByteArray = data["tileOverlay"]
			if tile.tileOverlay.has_method("from_bytes"):
				tile.tileOverlay.from_bytes(buffer)
			else:
				var serializedData: Dictionary = bytes_to_var(buffer)
				tile.tileOverlay.deserialize(serializedData)
			tile.tileOverlay.from_bytes(data["tileOverlay"])


func getPooledBulletSmoke() -> BulletSmoke:
	return _bulletSmokeManager.get_pooled_smoke()

func returnBulletSmokeToPool(inBulletSmoke: BulletSmoke) -> void :
	_bulletSmokeManager.return_smoke_to_pool(inBulletSmoke)





static func generateBiomes() -> Array[String]:
	var rand = RandomNumberGenerator.new()
	rand.seed = Level.levelSeed

	var biomes: Array[String] = []
	if GameWorld.useCustomCaveOrder and GameWorld.customCaveOrder and GameWorld.customCaveOrder.size() > 0:
		biomes.clear()
		biomes.append("grey")
		for caveId in GameWorld.customCaveOrder:


			if Data.CAVE_SCENES.has(caveId):
				var cave = Data.CAVE_SCENES[caveId].instantiate()
				biomes.append(cave.biome)
				cave.queue_free()
	else:

		biomes.clear()
		biomes.append("grey")
		if Map.shouldGenerateDrillbertCave():
			biomes.append("blue")
		if rand.randf() > 0.4:
			biomes.append("green")
			if rand.randf() > 0.5:
				biomes.append("yellow")
				biomes.append("red")
			else:
				biomes.append("red")
				biomes.append("yellow")
		else:
			if rand.randf() > 0.5:
				biomes.append("yellow")
				if rand.randf() > 0.2:
					biomes.append("green")
					biomes.append("red")
				else:
					biomes.append("red")
					biomes.append("green")
			else:
				biomes.append("red")
				if rand.randf() > 0.2:
					biomes.append("green")
					biomes.append("yellow")
				else:
					biomes.append("yellow")
					biomes.append("green")
		if rand.randf() > 0.25:
			biomes.append("blue")
		else:
			biomes.insert(biomes.size() - 2, "blue")

	var availableBiomes = Map.BIOME_LIST.keys().duplicate()
	for _i in range(1, 100):
		var biomeId = availableBiomes[rand.randi() % availableBiomes.size()]
		if biomeId == biomes[biomes.size() - 1] or biomeId == biomes[biomes.size() - 2]:
			continue
		biomes.append(biomeId)
		availableBiomes.erase(biomeId)
		if availableBiomes.size() == 0:
			availableBiomes = Map.BIOME_LIST.keys().duplicate()
			availableBiomes.erase(biomeId)
	if biomes.size() < 30:
		for _i in 4:
			availableBiomes = Map.BIOME_LIST.keys().duplicate()
			Utils.shuffle(availableBiomes, rand)
			biomes.append_array(availableBiomes)

	return biomes

static func is_assessor(lk: LoadoutKeeper) -> bool:
	return lk.keeperId == "keeper2"

static func generateChamberPlacements(tileData) -> Dictionary:
	var chamberPlacements: = {}

	getResourceClusterAndAppendCoords(Data.TILE_GADGET, tileData, chamberPlacements)
	getResourceClusterAndAppendCoords(Data.TILE_RELIC, tileData, chamberPlacements)
	getResourceClusterAndAppendCoords(Data.TILE_RELIC_SWITCH, tileData, chamberPlacements)
	getResourceClusterAndAppendCoords(Data.TILE_SUPPLEMENT, tileData, chamberPlacements)

	if GameWorld.isChristmas and Level.loadout and Level.loadout.modeId == CONST.MODE_RELICHUNT:
		var skinAlreadyUnlocked = GameWorld.unlockedSkins.get("keeper2", []).has("skin3")
		var petAlreadyUnlocked = GameWorld.unlockedPets.has("pet7")
		if Level.loadout.keepers.any(is_assessor) and not skinAlreadyUnlocked:
			addGiftChamber("skin3", tileData, chamberPlacements)
		elif not petAlreadyUnlocked:
			addGiftChamber("pet7", tileData, chamberPlacements)

	if GameWorld.isHalloween:
		chamberPlacements["followeye"] = []
		for c in tileData.get_resource_cells_by_id(Data.TILE_SAND):
			chamberPlacements["followeye"].append(c)

	return chamberPlacements

static func addGiftChamber(giftType: String, tileData, chamberPlacements):

	if not chamberPlacements.has(giftType):
		chamberPlacements[giftType] = []

	var biomes: = [3, 4, 5]
	biomes.shuffle()
	for biomeIndex in biomes:
		var cells = tileData.get_biome_cells_by_index(biomeIndex)
		if cells.size() < 50:
			continue
		for i in 20:
			var baseCoord = cells[randi() % cells.size()]
			var free: = true
			for xOff in 2:
				for yOff in 2:
					var r = tileData.get_resource(baseCoord.x + xOff, baseCoord.y + yOff)
					free = free and (r == Data.TILE_DIRT_START)
			if free:
				chamberPlacements[giftType].append(baseCoord)
				return

static func getResourceClusterAndAppendCoords(chamberId: int, tileData, chamberPlacements: Dictionary) -> void :
	var clusterCenters = getResourceClusterTopLeft(chamberId, tileData)
	chamberPlacements[chamberId] = []
	chamberPlacements[chamberId].append_array(clusterCenters)

static func getResourceClusterTopLeft(tileType: int, tileData) -> Array:
	var resourceCells = tileData.get_resource_cells_by_id(tileType)
	var clustersCenters = []
	while resourceCells.size() > 0:
		var sourceCell = resourceCells.pop_back()
		var newCluster = []
		var openCells = [sourceCell]
		while openCells.size() > 0:
			var currentCell: Vector2i = openCells.pop_back() as Vector2i
			newCluster.append(currentCell)
			tileData.set_resourcev(currentCell, Data.TILE_DIRT_MARK_BLOCKED_FOR_CHAMBER)
			resourceCells.erase(currentCell)
			for offset in Map.NEIGHBOR_TILE_OFFSETS1:
				var neighborCell = Vector2(currentCell) + offset
				var otherCellId = tileData.get_resourcev(neighborCell)
				if otherCellId == tileType and not newCluster.has(neighborCell) and not openCells.has(neighborCell):
					openCells.append(neighborCell)

		var topLeft = Vector2(9999, 9999)
		for cell in newCluster:
			topLeft.x = min(topLeft.x, cell.x)
			topLeft.y = min(topLeft.y, cell.y)
		clustersCenters.append(topLeft)
	return clustersCenters

static func generateCaves(tileData, biomes: Array[String]) -> Dictionary:
	var minDistanceToCenter: int = Data.ofOr("world.min_cave_distance_to_center", 10)
	var cavePlacements: = {}
	var startingIronCountByLayer: = {}

	for ironCell in tileData.get_resource_cells_by_id(Data.TILE_IRON):
		var layer = tileData.get_biome(ironCell.x, ironCell.y)
		startingIronCountByLayer[layer] = 1 + startingIronCountByLayer.get(layer, 0)



	var rand = RandomNumberGenerator.new()
	rand.seed = Level.levelSeed
	var caveScenesById = Data.CAVE_SCENES.duplicate()
	var specialCaveScenesById = Data.SPECIAL_CAVE_SCENES.duplicate()

	var cavePackedScenes: = []
	var caveIds: Array[String] = []

	if Level.loadout.modeId == CONST.MODE_RELICHUNT:
		if GameWorld.isPetUnlockable():
			caveIds.append("nest")

	if GameWorld.useCustomCaveOrder and GameWorld.customCaveOrder and GameWorld.customCaveOrder.size() > 0:
		for caveId in GameWorld.customCaveOrder:
			if caveScenesById.has(caveId):
				caveIds.append(caveId)

	else:
		for caveId in Data.ofOr("world.allowed_caves", Data.CAVE_SCENES):
			if caveScenesById.has(caveId):
				caveIds.append(caveId)
			elif specialCaveScenesById.has(caveId):
				caveIds.append(caveId)
		Utils.shuffle(caveIds, rand)

	for caveId in caveIds:
		if specialCaveScenesById.has(caveId):
			cavePackedScenes.append(specialCaveScenesById[caveId])
		else:
			cavePackedScenes.append(caveScenesById[caveId])

	if Level.loadout.modeId == CONST.MODE_RELICHUNT:
		for keeper in Level.loadout.keepers:
			if keeper.keeperId == "keeper1":
				if GameWorld.isHalloween and Level.loadout.modeId == CONST.MODE_RELICHUNT:
					cavePackedScenes.insert(0, preload("res://content/caves/halloweencave/HalloweenSkeletonCave.tscn"))
					caveIds.insert(0, "halloween")
					break
		if GameWorld.isLunarNewYear and not GameWorld.unlockedPets.has("pet8"):
			cavePackedScenes.insert(0, preload("res://content/caves/dragoncave/LunarNewYearDragonCave.tscn"))
			caveIds.insert(0, "lunar")
		if Map.shouldGenerateDrillbertCave():
			cavePackedScenes.insert(0, preload("res://content/caves/drillicave/DrillbertCave.tscn"))
			caveIds.insert(0, "drillbert")
	elif Level.loadout.modeId == CONST.MODE_VERSUS:

		var scannerIdx: int = caveIds.find("scanner")
		caveIds.erase("scanner")
		caveScenesById.erase("scanner")
		cavePackedScenes.remove_at(scannerIdx)

	var availableCaves: Array
	var availableCaveIds: Array[String]
	var caveCount: = {}
	var maxLayer = startingIronCountByLayer.size()
	for layerIndex in maxLayer:
		var caves_allowed_in_biome = Data.ofOr("world.max_caves_per_biome", 1)
		if availableCaves.is_empty():
			availableCaves = cavePackedScenes.duplicate()
			availableCaves.reverse()
			availableCaveIds = caveIds.duplicate()
			availableCaveIds.reverse()
		for i in range(availableCaves.size() - 1, -1, -1):
			var cavePackedScene = availableCaves[i]
			var caveId: = availableCaveIds[i]

			var cave = cavePackedScene.instantiate()
			var biomeFits = cave.biome == "" or biomes[layerIndex] == cave.biome
			var minLayerFits = cave.minLayer <= layerIndex
			var relativeDepth = layerIndex / float(maxLayer)
			var minDepthFits = round(relativeDepth * cave.minRelativeDepth) <= layerIndex
			var maxDepthFits = layerIndex <= round(maxLayer * cave.maxRelativeDepth)
			var withinAllowedCount = caveCount.get(cavePackedScene, 0) < cave.maxCount
			if biomeFits and minLayerFits and minDepthFits and maxDepthFits and withinAllowedCount:
				cave.updateUsedTileCoords()


				var placedCave: = false
				for _i in 30:
					var cells = tileData.get_biome_cells_by_index(layerIndex)
					if cells.size() < cave.tileCoords.size():
						break

					var cell = cells.pick_random()
					if abs(cell.x) < minDistanceToCenter:
						continue

					if not tileData.is_area_free(cell, cave.tileCoords):
						continue

					if not cavePlacements.has(caveId):
						cavePlacements[caveId] = []

					placedCave = true
					cavePlacements[caveId].append(cell)

					for c in cave.tileCoords:
						var absCoord = Vector2(cell) + c
						tileData.clear_resource(absCoord)
					break

				if not placedCave:
					Logger.error("failed to place cave", "Map.addCave", {"biomeIndex": layerIndex, "cave": cave.scene_file_path})

				availableCaves.erase(cavePackedScene)
				availableCaveIds.erase(caveId)
				caveCount[cavePackedScene] = caveCount.get(cavePackedScene, 0) + 1
				caves_allowed_in_biome -= 1
				if caves_allowed_in_biome <= 0:
					break
			else:
				cave.queue_free()

	return cavePlacements
