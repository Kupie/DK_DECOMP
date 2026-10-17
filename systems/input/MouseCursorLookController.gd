extends Node

var textures: Array[ImageTexture] = [null, null, null]
var texturesCrosshair: = [null, null, null]
var cursorSize: = 1

var cursor: = "default"
var hotspot: = Vector2.ZERO

func _enter_tree():
	get_viewport().connect("size_changed", Callable(self, "updateCursorSize"))
	Style.init($"%MouseCursor2x")
	Style.init($"%MouseCursor3x")
	Style.init($"%MouseCursor4x")
	Style.init($"%MouseCursorCH2x")
	Style.init($"%MouseCursorCH3x")
	Style.init($"%MouseCursorCH4x")
	Style.init(self)


func _ready():
	await RenderingServer.frame_post_draw
	updateStyleColor(true)
	updateCursorSize()


func useSystemCursor(use: bool):
	await RenderingServer.frame_post_draw
	for i in textures.size():
		mouseCursorFromViewport(i)
	await RenderingServer.frame_post_draw
	if use:
		_updateMouseCursor()
	else:
		await RenderingServer.frame_post_draw
		updateCursorSize()


func updateCursorSize():
	var screenSizeY: = DisplayServer.screen_get_size().y
	if screenSizeY > 2000:
		cursorSize = 2
	if screenSizeY > 1200:
		cursorSize = 1
	else:
		cursorSize = 0
	cursorSize += 1
	_updateMouseCursor()


func updateStyleColor(force: = false):
	if not force and not textures[0]:
		return
	await RenderingServer.frame_post_draw
	for i in textures.size():
		mouseCursorFromViewport(i)
	await RenderingServer.frame_post_draw
	_updateMouseCursor(hotspot)


func mouseCursorFromViewport(index: int):
	for i in textures.size():
		get_node(str("Viewport_", i, "/MouseCursor", i + 2, "x")).visible = true
		get_node(str("Viewport_", i, "/MouseCursorCH", i + 2, "x")).visible = false
	await RenderingServer.frame_pre_draw
	var viewport: SubViewport = get_node("Viewport_%s" % str(index))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	var texture: ImageTexture = ImageTexture.create_from_image(img)
	textures[index] = texture

	for i in textures.size():
		get_node(str("Viewport_", i, "/MouseCursor", i + 2, "x")).visible = false
		get_node(str("Viewport_", i, "/MouseCursorCH", i + 2, "x")).visible = true
	await RenderingServer.frame_pre_draw
	viewport = get_node("Viewport_%s" % str(index))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	await RenderingServer.frame_post_draw
	img = viewport.get_texture().get_image()
	texture = ImageTexture.create_from_image(img)
	texturesCrosshair[index] = texture


func _updateMouseCursor(newHotspot: = hotspot):
	var tex: ImageTexture = textures[cursorSize] if cursor == "default" else texturesCrosshair[cursorSize]
	if _useSystemCursor():
		tex = null
		newHotspot = Vector2.ZERO
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, newHotspot)


func setCursor(newCursor: String):
	cursor = newCursor
	updateCursorSize()
	hotspot = Vector2.ZERO if cursor == "default" else Vector2(11, 18)
	hotspot *= 1.0 + float(cursorSize) * 0.5
	_updateMouseCursor(hotspot)

func _useSystemCursor() -> bool:
	return cursor != "crosshairs" and Options.useSystemCursor
