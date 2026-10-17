extends Control

var indexColors: = []
var allColors: = {}
var allColorsReverse: = {}
var colorMap: = {}
var reverseColorMap: = {}
var paletteRows: = {
	0: {"name": "Dome", "value": 0.0}, 
	1: {"name": "Cellar", "value": 20.0}, 
	2: {"name": "Keeper", "value": 40.0}, 
	3: {"name": "Resources", "value": 60.0}, 
	4: {"name": "Chambers", "value": 80.0}, 
	5: {"name": "Gadgets-Outside", "value": 100.0}, 
	6: {"name": "Gadgets-Inside", "value": 120.0}, 
	7: {"name": "Gadgets-Cellar", "value": 140.0}, 
	8: {"name": "Gadgets-Mine", "value": 160.0}, 
	9: {"name": "Monsters", "value": 180.0}, 
	10: {"name": "World", "value": 200.0}, 
	11: {"name": "UI", "value": 220.0}, 
	12: {"name": "UI-Icons", "value": 240.0}, 
}
var folderPath: = ""

func _ready():
	find_child("PaletteRowButton").add_item("Select Target Palette Row", -1)
	_on_PaletteRowButton_item_selected(0)
	for p in paletteRows:
		find_child("PaletteRowButton").add_item(paletteRows[p].name)
	Audio.set_bus_volume(Audio.BUS_MASTER, -30)
	Options.useSystemCursor = true
	generateIndexColors(0)
	_on_ClearButton_pressed()

func imageLoadNoWarning(filepath):
	var image = Image.new()
	image.load(ProjectSettings.globalize_path(filepath))
	return image

func generateIndexColors(bOffset: = 0):
	colorMap.clear()
	indexColors.clear()
	reverseColorMap.clear()
	var indexImage: = load("res://tool/IndexPaletteRecolor/index_palette.png")
	var palette1Image: = load("res://tool/IndexPaletteRecolor/palette_1_1.png")
	var yLength = indexImage.get_height() / 10
	var xLength = indexImage.get_width() / 10
	if indexImage and palette1Image:
		false
		false
		for x in xLength:
			for y in yLength:
				var key = Vector2(x * 10 + 5, (yLength - y - 1) * 10 + 5)
				var color = indexImage.get_pixelv(key)
				var r = round(255 * color.r)
				if abs(color.b - bOffset / 255.0) <= 0.01 and not indexColors.has(r):
					indexColors.append(r)
					var lookupColor = palette1Image.get_pixelv(key)
					colorMap[lookupColor] = color
					reverseColorMap[color] = lookupColor
		false
		false
	updatePreview()

func _on_PalettePickFileButton_pressed():
	find_child("FileDialog").popup()

func _on_PalettePickFolderButton_pressed():
	find_child("FolderDialog").popup()

func _on_FileDialog_dir_selected(dirPath):
	_on_ClearButton_pressed()
	var dir: = DirAccess.open(dirPath)
	dir.list_dir_begin()
	folderPath = dirPath
	$"%FolderPathLabel".text = "Folder:\n" + folderPath
	while true:
		var file = dir.get_next()
		if file == "":
			break
		if file.ends_with(".png"):
			$"%FilesToConvert".add_item(file, null, false)
	updatePreview()


func _on_FileDialog_file_selected(path: String) -> void :
	_on_FileDialog_files_selected([path])


func _on_FileDialog_files_selected(paths: Array):
	_on_ClearButton_pressed()
	if paths.is_empty():
		return
	var fileName: String = paths[0].split("/")[-1]
	folderPath = paths[0].trim_suffix(fileName)
	$"%FolderPathLabel".text = "Folder:\n" + folderPath
	for p in paths:
		$"%FilesToConvert".add_item(p.split("/")[-1], null, false)
	updatePreview()

func updatePreview():
	for c in $"%Images".get_children():
		c.queue_free()
	for c in $"%PreviewImages".get_children():
		c.queue_free()
	var showNext: bool = $"%FilesToConvert".get_item_count() > 0
	$"%FilesToConvert".visible = showNext
	$"%ClearButton".visible = showNext
	$"%ConvertGroup".visible = showNext
	$"%FilesForConversion".visible = showNext
	for p in getPaths():
		var f = FileAccess.open(p, FileAccess.ModeFlags.READ)
		if f == null:
			print("something went wrong: " + str(FileAccess.get_open_error()))
			return
		var imgBuffer = f.get_buffer(f.get_length())
		f.close()
		var img = Image.new()
		img.load_png_from_buffer(imgBuffer)
		var tex = ImageTexture.create_from_image(img)

		var newImage = TextureRect.new()
		newImage.texture = tex
		newImage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		newImage.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		newImage.custom_minimum_size = Vector2(200.0, 200.0)
		$"%Images".add_child(newImage)

		var newPreviewImage = TextureRect.new()
		newPreviewImage.texture = convertToPaletteFromTex(tex)
		newPreviewImage.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		newPreviewImage.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		newPreviewImage.custom_minimum_size = Vector2(200.0, 200.0)
		$"%PreviewImages".add_child(newPreviewImage)
		await get_tree().physics_frame

func _on_ToImageButton_pressed():
	find_child("ToImageButton").disabled = true
	convertToImage(getPaths())
	find_child("ToImageButton").disabled = false
	success()
	updatePreview()

func convertToImage(paths):
	for fullPath in paths:
		var image: = loadExternalImage(fullPath)
		false
		for x in image.get_width():
			for y in image.get_height():
				var key = Vector2(x, y)
				var color: Color = image.get_pixelv(key)
				if color.a == 0.0:
					continue
				var bestColor
				var bestColorDelta: = INF
				for c in reverseColorMap.keys():
					var colorDelta = abs(c.r - color.r) + abs(c.g - color.g) + abs(c.b - color.b)
					if colorDelta < bestColorDelta and colorDelta < 0.4:
						bestColor = c
						bestColorDelta = colorDelta
				if bestColor:
					image.set_pixelv(key, reverseColorMap[bestColor])
		false
		if $"%RecolorNameCheckBox".button_pressed:
			fullPath = fullPath.trim_suffix(".png")
			fullPath += "_recolor.png"
		image.save_png(fullPath)

func _on_ToPaletteButton_pressed():
	find_child("ToPaletteButton").disabled = true
	convertToPalette(getPaths())
	find_child("ToPaletteButton").disabled = false
	success()
	updatePreview()

func convertToPalette(paths):
	for fullPath in paths:
		var image: = loadExternalImage(fullPath)
		false
		for x in image.get_width():
			for y in image.get_height():
				var key = Vector2(x, y)
				var color: Color = image.get_pixelv(key)
				if color.a == 0.0:
					continue
				var bestColor
				var bestColorDelta: = INF
				for c in colorMap.keys():
					var colorDelta = abs(c.r - color.r) + abs(c.g - color.g) + abs(c.b - color.b)
					if colorDelta < bestColorDelta and colorDelta < 0.4:
						bestColor = c
						bestColorDelta = colorDelta
				if bestColor:
					image.set_pixelv(key, colorMap[bestColor])
		false
		if $"%RecolorNameCheckBox".button_pressed:
			fullPath = fullPath.trim_suffix(".png")
			fullPath += "_recolor.png"
		image.save_png(fullPath)

func convertToPaletteFromTex(texture: ImageTexture):
	var image = texture.get_image()
	false
	for x in image.get_width():
		for y in image.get_height():
			var key = Vector2(x, y)
			var color: Color = image.get_pixelv(key)
			if color.a == 0.0:
				continue
			var bestColor
			var bestColorDelta: = INF
			for c in colorMap.keys():
				var colorDelta = abs(c.r - color.r) + abs(c.g - color.g) + abs(c.b - color.b)
				if colorDelta < bestColorDelta and colorDelta < 0.4:
					bestColor = c
					bestColorDelta = colorDelta
			if bestColor:
				image.set_pixelv(key, colorMap[bestColor])
	false
	var tex = ImageTexture.create_from_image(image)
	return tex

func _on_PaletteRowButton_item_selected(index):
	index -= 1
	if index == -1:
		$"%ToPaletteButton".disabled = true
		$"%ToImageButton".disabled = true
		$"%ToPaletteButton".modulate.a = 0.4
		$"%ToImageButton".modulate.a = 0.4
		$"%ToPaletteLabel".modulate.a = 0.4
		$"%ToImageLabel".modulate.a = 0.4
		$"%PreviewPanelTop".hide()
		$"%PreviewPanel".hide()
	else:
		generateIndexColors(int(paletteRows[index].value) + 1)
		$"%ToPaletteButton".disabled = false
		$"%ToImageButton".disabled = false
		$"%ToPaletteButton".modulate.a = 1.0
		$"%ToImageButton".modulate.a = 1.0
		$"%ToPaletteLabel".modulate.a = 1.0
		$"%ToImageLabel".modulate.a = 1.0
		$"%PreviewPanelTop".show()
		$"%PreviewPanel".show()

func _on_ClearButton_pressed():
	$"%FilesToConvert".clear()
	$"%FilesToConvert".hide()
	$"%ClearButton".hide()
	$"%ConvertGroup".hide()
	$"%FilesForConversion".hide()
	folderPath = ""
	$"%FolderPathLabel".text = ""
	for c in $"%PreviewImages".get_children():
		c.queue_free()
	for c in $"%Images".get_children():
		c.queue_free()

func getPaths() -> Array:
	var paths: = []
	for i in $"%FilesToConvert".get_item_count():
		var fullPath = folderPath + "/" + $"%FilesToConvert".get_item_text(i)
		paths.append(fullPath)
	return paths

func _on_PostConversionPreviewButton_pressed():
	if $"%PostConversionPreviewButton".button_pressed:
		$"%PostConversionLabel".text = "Post-Conversion preview with Palette 1"
		$"%PostConversionPreviewButton".text = "Palette Preview: On"
		$"%Shader".show()
	else:
		$"%PostConversionLabel".text = "Post-Conversion preview"
		$"%PostConversionPreviewButton".text = "Palette Preview: Off"
		$"%Shader".hide()

func loadExternalImage(path) -> Image:
	var tex_file = FileAccess.open(path, FileAccess.ModeFlags.READ)
	var bytes = tex_file.get_buffer(tex_file.get_length())
	var img = Image.new()
	img.load_png_from_buffer(bytes)
	tex_file.close()
	return img

func success():
	$"%Success".show()
	$"%Success".modulate.a = 1.0
	$"%SuccessTween".interpolate_property($"%Success", "modulate:a", 1, 0, 2.0, Tween.TRANS_EXPO, Tween.EASE_IN)
	$"%SuccessTween".interpolate_callback($"%Success", 2.0, "set_visible", false)
	$"%SuccessTween".start()

func _on_RecolorNameCheckBox_pressed():
	$"%OverwriteCheckBox".button_pressed = false
	$"%RecolorNameCheckBox".button_pressed = true

func _on_OverwriteCheckBox_pressed():
	$"%OverwriteCheckBox".button_pressed = true
	$"%RecolorNameCheckBox".button_pressed = false
