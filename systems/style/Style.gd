extends Node

var FOCUS_MODULATE = Color(1.8, 1.8, 1.4)
const TILE_COVER_MODULATE = Color(0.3, 0.3, 0.3)

var STRUCT_DARK: = Color("544E68")
var STRUCT_BRIGHT: = Color("8D697A")

var LIVE: = Color("FFAA5E")
var LIVE_BRIGHT: = Color("FFD4A3")

const keeper_highlight: = Vector2(6, 2)

var OVERLAY_COLOR_IN: = Color("#12121ABB")
var OVERLAY_COLOR_OUT: = Color(0.0, 0.0, 0.0, 0.0)

var FONT_COLOR_WARNING: = Color("#CB4548")
var FONT_COLOR_HIGHLIGHT: = Color("#FFD4A3")

const colors_r: = 32
const colors_b: = 12
const r_step: = 8
const b_step: = 20
const paletteColorSize: = Vector2(10, 10)

var theme: = preload("res://gui/theme.tres")
var spriteShader: = preload("res://systems/style/materials/sprite_palette.tres")
var spriteShaderLabel: = preload("res://systems/style/materials/sprite_palette_for_label.tres")
var additionalShaders: = {
	&"styled_tilebreak_mat": preload("res://content/map/tile/tile_break_particle_material.tres"), 
	&"styled_unmodulated_mat": preload("res://systems/style/materials/palette_swap_unmodulated.tres"), 
	&"styled_control_mat": preload("res://systems/style/materials/palette_swap_shader_control.tres"), 
	&"styled_grayscale_mat": preload("res://systems/style/materials/palette_swap_grayscale.tres"), 
	}
var palette: Texture2D
var colorData: Dictionary = {}
var originalIndexColorsByFontResource: Dictionary = {}
var paletteId: = "palette_1_1"

var additionalPalettes: Dictionary = {}
var additionalPaletteShaders: Dictionary = {}

var styledGradients: = []
var fontSettingResources: = [
	preload("res://gui/fontsettings/ActionHintFontSettings.tres"), 
	preload("res://gui/fontsettings/HeadingFontSettings.tres"), 
	preload("res://gui/fontsettings/HeadingMonospaceFontSettings.tres"), 
	preload("res://gui/fontsettings/HudPixelartMonospacedFontSettings.tres"), 
	preload("res://gui/fontsettings/LargeFontSettings.tres"), 
	preload("res://gui/fontsettings/NormalFontSettings.tres"), 
	preload("res://gui/fontsettings/NormalFontSettingsHighlighted.tres"), 
	preload("res://gui/fontsettings/NumbersFontSettings.tres"), 
	preload("res://gui/fontsettings/NumbersFontSettingsHighlighted.tres"), 
	preload("res://gui/fontsettings/SmallFontSettings.tres"), 
	preload("res://gui/fontsettings/SmallFontSettingsHighlighted.tres"), 
	preload("res://gui/fontsettings/VeryLargeFontSettings.tres"), 
	preload("res://gui/fontsettings/LargeFontSettingsAsOverlay.tres"), 
]

func _ready():
	setPalette(paletteId)

func getPalettePath(paletteId):
	return "res://systems/style/palettes/" + str(paletteId) + ".png"

func setPalette(paletteId: String, forceReload: = false):
	styledGradients = []
	var pal
	Logger.info("setting palette to " + paletteId)
	var palettePath = getPalettePath(paletteId)
	if forceReload:
		var image = Image.new()
		var err = image.load(palettePath)
		if err == OK:
			pal = ImageTexture.create_from_image(image)
	else:
		var new_palette = load(palettePath)
		if new_palette:
			pal = new_palette
		else:
			Logger.error("tried setting a palette that does not exist", "Style.setPalette", {"palettePath": palettePath})

	self.paletteId = paletteId
	setPaletteToImg(pal)


	for keeper in Keepers.getAll():
		keeper.setSkin(keeper.skinId, keeper.colorId)
	for goblin in get_tree().get_nodes_in_group("keeper4_goblins"):
		goblin.set_color()
	for goblin_hole in get_tree().get_nodes_in_group("goblin_holes"):
		goblin_hole.set_color()

func setPaletteToImg(palette):
	self.palette = palette

	readColors(palette)

	applyPaletteToAllNodes()
	applyPaletteToFontSettings()

func applyPaletteToFontSettings():
	for setting in fontSettingResources:
		var indexColor: Color
		if originalIndexColorsByFontResource.has(setting):
			indexColor = originalIndexColorsByFontResource.get(setting)
		else:
			indexColor = setting.font_color
			originalIndexColorsByFontResource[setting] = Color(indexColor)
		setting.font_color = mapColor(indexColor)

func applyPaletteToAllNodes():
	spriteShader.set_shader_parameter("palette", palette)
	spriteShaderLabel.set_shader_parameter("palette", palette)

	for s in additionalShaders.values():
		s.set_shader_parameter("palette", palette)

	for node in get_tree().get_nodes_in_group("styleShaderCallback"):
		node.material.set_shader_parameter("palette", palette)

	for node in get_tree().get_nodes_in_group("styleCpuGradientCallback"):
		updateGradientCached(node, node.color_ramp)

	for node in get_tree().get_nodes_in_group("styleGradientCallback"):
		updateGradientCached(node, node.process_material.color_ramp.get_gradient())

	for node in get_tree().get_nodes_in_group("styleModulateCallback"):
		node.modulate = mapColorCached(node, node.modulate)

	for node in get_tree().get_nodes_in_group("colorRectCallback"):
		node.color = mapColorCached(node, node.color)

	for node in get_tree().get_nodes_in_group("styleParticleColorCallback"):
		node.process_material.color = mapColorCached(node, node.process_material.color)

	for node in get_tree().get_nodes_in_group("styleLabelCallback"):
		node.set("theme_override_colors/font_color", \
		mapColorCached(node, node.get("theme_override_colors/font_color")))

	for node in get_tree().get_nodes_in_group("styleRichLabelCallback"):
		node.set("theme_override_colors/default_color", \
		mapColorCached(node, node.get("theme_override_colors/default_color")))

	for node in get_tree().get_nodes_in_group("styleLineCallback"):
		if node.default_color:
			node.default_color = mapColorCached(node, node.default_color)
		if node.material and not node.material is CanvasItemMaterial:
			node.material.set_shader_parameter("palette", palette)

	for node in get_tree().get_nodes_in_group("styleCustomCallback"):
		node.updateStyleColor()

func readColors(tex):
	var image = tex.get_image()
	for i_b in colors_b:
		for i_r in colors_r:
			var key = Vector2(i_r, i_b)
			var color = image.get_pixelv(paletteColorSize * key + paletteColorSize * 0.5)
			if color != Color.WHITE and color != Color.BLACK:
				colorData[key] = color
	colorData[Vector2(32, 12)] = Color.WHITE

func init(node, customPaletteId = ""):
	var appliedPalette: = palette
	var appliedShader: = spriteShader

	if customPaletteId != "":
		if not additionalPalettes.has(customPaletteId):
			additionalPalettes[customPaletteId] = load(getPalettePath(customPaletteId))
			additionalPaletteShaders[customPaletteId] = spriteShader.duplicate()
			additionalPaletteShaders[customPaletteId].set_shader_parameter("palette", additionalPalettes[customPaletteId])
		appliedPalette = additionalPalettes[customPaletteId]
		appliedShader = additionalPaletteShaders[customPaletteId]

	if node.is_in_group("styled") or node.is_in_group("unstyled"):
		return

	if node.is_in_group("customStyle"):
		node.add_to_group("styleCustomCallback")
		node.updateStyleColor()
	elif (node is Sprite2D or node is AnimatedSprite2D or node is TileMap):
		if node.material:
			if node.material is ShaderMaterial and node.material.get_shader_parameter("palette") != null:
				node.material.set_shader_parameter("palette", appliedPalette)
				node.add_to_group("styleShaderCallback")
				node.add_to_group("styled")
		else:
			node.material = appliedShader
		if node.modulate != Color.WHITE:
			node.modulate = mapColorCached(node, node.modulate)
			node.add_to_group("styleModulateCallback")
			node.add_to_group("styled")
	elif node is CPUParticles2D:
		if node.color_ramp:
			if not styledGradients.has(node.color_ramp):
				updateGradientCached(node, node.color_ramp)
				node.add_to_group("styleCpuGradientCallback")
				node.add_to_group("styled")
				styledGradients.append(node.color_ramp)
		elif node.color:
			node.color = mapColorCached(node, node.color)
	elif node is GPUParticles2D and node.process_material:
		if node.process_material.get("color_ramp"):
			if not styledGradients.has(node.process_material.color_ramp):
				var gradient = node.process_material.color_ramp.get_gradient()
				updateGradientCached(node, gradient)
				node.add_to_group("styleGradientCallback")
				node.add_to_group("styled")
				styledGradients.append(node.process_material.color_ramp)
		elif node.process_material.get("color"):
			node.process_material.color = mapColorCached(node, node.process_material.color)
			node.add_to_group("styleParticleColorCallback")
			node.add_to_group("styled")
	elif node is TextureRect:
		if node.material:
			node.material.set_shader_parameter("palette", appliedPalette)
			node.add_to_group("styleShaderCallback")
			node.add_to_group("styled")
		else:
			node.material = appliedShader
	elif node is PanelContainer or node is Panel or node is BaseButton or node is Separator or node is Range or node is HSeparator or node is VSeparator or node is OptionButton or node is Popup or node is ItemList:
		node.material = spriteShaderLabel
	elif node is ColorRect:
		if not node.color.is_equal_approx(OVERLAY_COLOR_IN):
			node.color = mapColorCached(node, node.color)
			node.add_to_group("colorRectCallback")
			node.add_to_group("styled")
	elif node is RichTextLabel:
		var c = node.get("theme_override_colors/default_color")
		if c:
			node.set("theme_override_colors/default_color", mapColorCached(node, c))
			node.add_to_group("styleRichLabelCallback")
			node.add_to_group("styled")
	if node is Line2D:
		node.add_to_group("styleLineCallback")
		node.add_to_group("styled")
		if node.material and not node.material is CanvasItemMaterial:
			node.material.set_shader_parameter("palette", appliedPalette)
			node.default_color = Color.WHITE
		elif node.texture:
			node.material = appliedShader
		if not node.default_color.is_equal_approx(Color.WHITE):
			node.default_color = mapColorCached(node, node.default_color)


	if node is ScrollContainer or node is TextureRect or node is AnimatedSprite2D or node is Sprite2D:
		if node.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if node is Label or node is RichTextLabel or node is Button:
		if node.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	var children: Array[Node] = node.get_children(true) if node is ScrollContainer else node.get_children()
	for n in children:
		init(n, customPaletteId)

func get_cached_source_color_or(node, color):
	if node.has_meta("style_source_color"):
		color = node.get_meta("style_source_color")
	else:
		node.set_meta("style_source_color", color)
	return color

func mapColorCached(node: Node, c: Color):
	return mapColor(get_cached_source_color_or(node, c))

func mapColor(c: Color) -> Color:
	var r = round(c.r * (255.0 / r_step))
	var b = round(c.b * (255.0 / b_step))
	var key = Vector2(r, b)
	if colorData.has(key):
		var map = colorData.get(key)
		return Color(map.r, map.g, map.b, c.a)
	else:

		return c

func updateGradientCached(node, gradient: Gradient):
	var source = gradient
	if node.has_meta("style_source_gradient"):
		source = node.get_meta("style_source_gradient")
	else:
		node.set_meta("style_source_gradient", source.duplicate())

	for i in range(0, gradient.colors.size()):
		gradient.set_color(i, mapColor(source.colors[i]))

func getColor(key: Vector2) -> Color:
	return colorData.get(key, Color.WHITE)
