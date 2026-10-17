extends Node

const border: = 8

func _ready():
	var image: = Image.new()
	var err = image.load("res://content/map/border/tile_sheet.png")
	if err:
		find_child("Label").text = "did not find tile sheet: " + str(err)
		return

	var cols: int = image.get_width() / GameWorld.TILE_SIZE
	var rows: int = image.get_height() / GameWorld.TILE_SIZE
	var out: = Image.create(cols * (GameWorld.TILE_SIZE + border * 2), rows * (GameWorld.TILE_SIZE + border * 2), false, image.get_format())

	for x in range(0, cols):
		for y in range(0, rows):
			out.blit_rect_mask(image, image, 
			Rect2(x * GameWorld.TILE_SIZE, y * GameWorld.TILE_SIZE, GameWorld.TILE_SIZE, GameWorld.TILE_SIZE), 
			Vector2(border + (GameWorld.TILE_SIZE + border * 2) * x, border + (GameWorld.TILE_SIZE + border * 2) * y))
	out.save_png("res://content/map/border/reference_sheet_spaced.png")

	for x in range(0, cols):
		for y in range(0, rows):
			for i in range(1, border + 1):
				out.blit_rect_mask(image, image, 
				Rect2(x * GameWorld.TILE_SIZE, y * GameWorld.TILE_SIZE, GameWorld.TILE_SIZE, 1), 
				Vector2(border + (GameWorld.TILE_SIZE + border * 2) * x, border + (GameWorld.TILE_SIZE + border * 2) * y - i))
				out.blit_rect_mask(image, image, 
				Rect2(x * GameWorld.TILE_SIZE, y * GameWorld.TILE_SIZE + GameWorld.TILE_SIZE - 1, GameWorld.TILE_SIZE, 1), 
				Vector2(border + (GameWorld.TILE_SIZE + border * 2) * x, border + (GameWorld.TILE_SIZE + border * 2) * y + GameWorld.TILE_SIZE + i - 1))
				out.blit_rect_mask(image, image, 
				Rect2(x * GameWorld.TILE_SIZE, y * GameWorld.TILE_SIZE, 1, GameWorld.TILE_SIZE), 
				Vector2(border + (GameWorld.TILE_SIZE + border * 2) * x - i, border + (GameWorld.TILE_SIZE + border * 2) * y))
				out.blit_rect_mask(image, image, 
				Rect2(x * GameWorld.TILE_SIZE + GameWorld.TILE_SIZE - 1, y * GameWorld.TILE_SIZE, 1, GameWorld.TILE_SIZE), 
				Vector2(border + (GameWorld.TILE_SIZE + border * 2) * x + GameWorld.TILE_SIZE + i - 1, border + (GameWorld.TILE_SIZE + border * 2) * y))
	out.save_png("res://content/map/border/reference_sheet_extruded.png")

	var out2: = Image.create(cols * (GameWorld.TILE_SIZE + 1) - 1, rows * (GameWorld.TILE_SIZE + 1) - 1, false, image.get_format())


	for x in range(0, cols):
		for y in range(0, rows):
			out2.blit_rect_mask(image, image, 
			Rect2(x * GameWorld.TILE_SIZE, y * GameWorld.TILE_SIZE, GameWorld.TILE_SIZE, GameWorld.TILE_SIZE), 
			Vector2((GameWorld.TILE_SIZE + 1) * x, (GameWorld.TILE_SIZE + 1) * y))

	false
	for x in range(1, cols):
		for y in range(0, out2.get_height()):
			out2.set_pixel(x * (GameWorld.TILE_SIZE + 1) - 1, y, Color.BLACK)
	for y in range(1, rows):
		for x in range(0, out2.get_width()):
			out2.set_pixel(x, y * (GameWorld.TILE_SIZE + 1) - 1, Color.BLACK)
	false
	out2.save_png("res://content/map/border/reference_sheet_separated.png")

	find_child("Label").text = "done"
