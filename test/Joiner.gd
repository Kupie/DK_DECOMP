extends Node

func _ready():
	var j: = 1
	var images: = []
	var levelPath: = "res://test/"
	var dir = DirAccess.open(levelPath)
	dir.list_dir_begin()
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif file.ends_with(".png"):
			var image: = Image.new()
			image.load("res://test/" + file)
			images.append(image)
			j += 1

	var cols: = 10
	var rows: = 7
	var imageSize = images[0].get_size() + Vector2(20, 20)
	var image: = Image.create(cols * imageSize.x, rows * imageSize.y, false, images[0].get_format())

	for i in range(0, images.size()):
		var col = i % cols
		var row = i / cols
		image.blit_rect(images[i], Rect2(Vector2(0, 0), imageSize), Vector2(10, 10) + Vector2(col * imageSize.x, row * imageSize.y))

	image.save_png("../all_levels.png")
	get_tree().quit()
