extends Node2D

const sizeX = 80

var colorData: = {}

func _ready():
	var image = Image.new()
	image.load("res://palette/slso8-base.png")
	false

	var centers: = []
	var lastGrey = grey(image.get_pixel(0, 0))
	centers.append(lastGrey)
	for x in range(1, image.get_width()):
		var c = image.get_pixel(x, 1)
		var currentGrey = grey(c)
		if currentGrey != lastGrey:
			centers.append(currentGrey)
			lastGrey = currentGrey

	var dir: = DirAccess.open("res://palette/in_palettes")
	dir.list_dir_begin()

	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with(".") and file.ends_with(".png"):
			createPalette(file, centers)

	dir.list_dir_end()

	var save = FileAccess.open("res://palette/out_palettes/data.json", FileAccess.ModeFlags.WRITE)
	if save != null:
		save.store_string(JSON.stringify(colorData))
		save.close()
	else:
		print("failed to save color data file")

	print("finished generating palettes")

func grey(c: Color) -> float:
	return (c.r * 1.0 + c.g * 1.0 + c.b * 1.0) / 3.0


func createPalette(file: String, centers: Array):
	var image = Image.new()
	image.load("res://palette/in_palettes/" + file)
	var colors: = getColors(image)
	colorData[file] = colors

	var out: = Image.create(sizeX, 4, false, Image.FORMAT_RGB8)
	false
	var lastBorder: = 0.0
	for i in range(0, colors.size()):
		var nextBorder = 0.5 * (centers[i] + centers[i + 1]) if i < centers.size() - 1 else 1.0
		for ox in range(lastBorder * sizeX, nextBorder * sizeX):
			for oy in range(0, 4):
				out.set_pixel(ox, oy, colors[i])
		lastBorder = nextBorder
	false
	out.save_png("res://palette/out_palettes/" + file.substr(0, file.find(".")) + ".png")

func getColors(image: Image) -> Array:
	false
	var colors: = []
	colors.append(image.get_pixel(0, 0))
	var lastGrey = grey(image.get_pixel(0, 0))
	for x in range(1, image.get_width()):
		var c = image.get_pixel(x, 1)
		var currentGrey = grey(c)
		if currentGrey != lastGrey:
			colors.append(c)
			lastGrey = currentGrey
	false
	return colors
