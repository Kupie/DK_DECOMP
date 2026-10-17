extends Area2D

func update():
	var map: TileMap = get_parent().get_node("Biomes")
	var tiles: = map.get_used_cells(MapData.DEFAULT_LAYER)
	var minX: = 99999999
	var minY: = 99999999
	var maxX: = -99999999
	var maxY: = -99999999
	for coord in tiles:
		minX = min(minX, coord.x)
		maxX = max(maxX, coord.x)
		minY = min(minY, coord.y)
		maxY = max(maxY, coord.y)

	var center: = Vector2(minX + 0.5 * (maxX - minX), minY + 0.5 * (maxY - minY))
	position = center * GameWorld.TILE_SIZE + GameWorld.TILE_SIZE * Vector2.ONE * 0.5

	$CollisionShape2D.shape = RectangleShape2D.new()
	$CollisionShape2D.shape.extents.x = (1 + maxX - minX) * GameWorld.TILE_SIZE * 0.5
	$CollisionShape2D.shape.extents.y = (1 + maxY - minY) * GameWorld.TILE_SIZE * 0.5
