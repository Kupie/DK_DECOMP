class_name ViewportContainer extends Control

const PLAYER_IDX_TO_CANVAS_LAYER_BIT: = {
	0: Const.CANVAS_LAYER_BIT_FIRST_LOCAL_PLAYER, 
	1: Const.CANVAS_LAYER_BIT_SECOND_LOCAL_PLAYER, 
	2: Const.CANVAS_LAYER_BIT_THIRD_LOCAL_PLAYER, 
	3: Const.CANVAS_LAYER_BIT_FOURTH_LOCAL_PLAYER
}

signal logic_size_changed

@export var camera: Camera2D
@export var viewport: SubViewport

var initialized: bool = false
var keeper: Keeper

var _worldCanvas: WorldCanvas
var _uiSubviewport: SubViewport
var _uiSubviewportRect: TextureRect
var _worldSubviewport: SubViewport
var _worldSubviewportRect: TextureRect
var _vignette: Vignette
var _curtain: TextureRect

func _notification(what: int) -> void :
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_worldCanvas = $SubViewportContainer / SubViewport / WorldCanvas
		_uiSubviewport = $UISubviewportRect / SubViewport
		_uiSubviewportRect = $UISubviewportRect
		_worldSubviewport = $SubViewportContainer / SubViewport
		_worldSubviewportRect = $SubViewportContainer
		_vignette = $SubViewportContainer / SubViewport / VignetteLayer / Vignette
		_curtain = $UISubviewportRect / Curtain

func init(originalWorld: World2D, keeper, camera_scene: PackedScene):
	Options.ensureFontOversamplig()
	self.keeper = keeper
	self.keeper.tree_exited.connect(_on_keeper_tree_exited)
	if originalWorld:
		viewport.world_2d = originalWorld
	if not camera:
		camera = camera_scene.instantiate()
		viewport.add_child(camera)
	camera.init(keeper)
	if not camera.target_zoom_changed.is_connected(_on_camera_target_zoom_changed):
		camera.target_zoom_changed.connect(_on_camera_target_zoom_changed)

	if not viewport.gui_focus_changed.is_connected(Audio.playUiHoverSound):
		viewport.gui_focus_changed.connect(Audio.playUiHoverSound)

	var deviceId = keeper.deviceId
	if deviceId == -1:
		viewport.set_meta("deviceType", "adaptive")
		_uiSubviewport.set_meta("deviceType", "adaptive")
	elif deviceId == 0:
		viewport.set_meta("deviceType", "keyboard")
		_uiSubviewport.set_meta("deviceType", "keyboard")
	else:
		viewport.set_meta("deviceType", "gamepad")
		_uiSubviewport.set_meta("deviceType", "gamepad")

	var offsetR = 4.5 / 32.0 if keeper.playerId == "player1" else 8.5 / 32.0
	$SplitGlow.material = $SplitGlow.material.duplicate()
	$SplitGlow.material.set_shader_parameter("palette", Style.palette)
	$SplitGlow.material.set_shader_parameter("i_r", offsetR)
	initialized = true

	_initParalaxForLocalKeeper(keeper)
	_refreshCullMask(keeper)
	_vignette.init(keeper)
	_revealContent()

func _on_camera_target_zoom_changed() -> void :
	logic_size_changed.emit()

func get_world_subviewport_logic_size(in_zoom_override: Vector2 = - Vector2.ONE) -> Vector2:
	if not is_instance_valid(camera):
		return Vector2()
	var zoom: Vector2 = Vector2.ONE * camera.getTargetZoom() if in_zoom_override == - Vector2.ONE else in_zoom_override
	return Vector2(_worldSubviewport.size_2d_override) / zoom

func _on_keeper_tree_exited() -> void :
	if not is_instance_valid(keeper) or keeper.is_queued_for_deletion():
		viewport.remove_meta("deviceType")

func getVignette() -> Vignette:
	return _vignette

func _initParalaxForLocalKeeper(inKeeper: Keeper) -> void :
	var worlds: Array = Level.worldsByTeamId.values()
	for world: Worldd in worlds:
		var parallax: ParallaxBG = world.createNewParallaxBG()
		_worldSubviewport.add_parallax_background(parallax, world.teamId)
		var keeperIdx = calcKeeperLocalIdx(keeper)
		var keeperSpecyficCanvasLayer = PLAYER_IDX_TO_CANVAS_LAYER_BIT[keeperIdx]
		parallax.init(inKeeper.playerId, keeperSpecyficCanvasLayer)

static func calcKeeperLocalIdx(inKeeper: Keeper) -> int:
	var localKeepers: Array[Keeper] = Keepers.local.getAll()
	var localIdx: = 0
	for localKeeper in localKeepers:
		if localKeeper == inKeeper:
			break
		localIdx += 1
	return localIdx

func _refreshCullMask(inKeeper: Keeper) -> void :
	var keeperIdx = calcKeeperLocalIdx(inKeeper)
	var keeperSpecyficCanvasLayer = PLAYER_IDX_TO_CANVAS_LAYER_BIT[keeperIdx]
	_worldSubviewport.canvas_cull_mask = 0
	_worldSubviewport.canvas_cull_mask |= 1 << Const.CANVAS_LAYER_BIT_ALL
	_worldSubviewport.canvas_cull_mask |= 1 << keeperSpecyficCanvasLayer

func _enter_tree() -> void :
	if isForcePixelPerfectStage():
		_worldSubviewportRect.texture_filter = CanvasItem.TextureFilter.TEXTURE_FILTER_LINEAR
	mainWindowSizeChanged()







	_ensureListeningOptionChanged.call_deferred()

	_uiSubviewportRect.texture = _uiSubviewport.get_texture()
	_worldSubviewportRect.texture = _worldSubviewport.get_texture()

func isForcePixelPerfectStage() -> bool:
	if StageManager.isInLoadout():

		return true
	return false

func _ensureListeningOptionChanged() -> void :
	if not Data.isListening(self, "options.changed"):
		Data.listen(self, "options.changed")

func _on_sub_viewport_container_resized() -> void :
	mainWindowSizeChanged()

func mainWindowSizeChanged():
	await RenderingServer.frame_post_draw
	var parent = get_parent()
	if not parent:
		return

	var activeViewportsCount: = 0
	for keeper: Keeper in Keepers.local.getAll():
		var vc: ViewportContainer = Level.viewports.getViewportContainerForPlayerID(keeper.playerId)
		if is_instance_valid(vc) and vc.is_visible_in_tree():
			activeViewportsCount += 1

	var screenTransform: = get_viewport().get_screen_transform()
	var scaleFactor: Vector2 = screenTransform.get_scale()
	var screenPixelSize: Vector2 = _worldSubviewportRect.size * scaleFactor
	var manyLocalPlayers: bool = activeViewportsCount > 1
	_worldSubviewport.size = screenPixelSize

	if not isForcePixelPerfectStage():
		_worldSubviewport.size /= 2.0 if Options.renderHalfRes else 1.0

	var overrideResolution: Vector2 = ViewportContainer.calcOverrideResolution(size)
	_worldSubviewport.size_2d_override = overrideResolution
	_uiSubviewport.size = _uiSubviewportRect.size * scaleFactor
	_uiSubviewport.size_2d_override = overrideResolution

	if manyLocalPlayers:


		var resolutionSizeFactor: float = 1.75
		_worldSubviewport.size_2d_override /= resolutionSizeFactor
		_uiSubviewport.size_2d_override /= resolutionSizeFactor
	logic_size_changed.emit()

static func calcOverrideResolution(window_resolution: Vector2, baseline_resolution: = CONST.BASE_RESOLUTION) -> Vector2:
	var window_aspect_ratio = window_resolution.x / window_resolution.y
	var baseline_aspect_ratio = baseline_resolution.x / baseline_resolution.y
	var adjusted_width = baseline_resolution.x
	var adjusted_height = baseline_resolution.y
	if window_aspect_ratio > baseline_aspect_ratio:
		adjusted_width = baseline_resolution.y * window_aspect_ratio
	else:
		adjusted_height = baseline_resolution.x / window_aspect_ratio
	return Vector2(round(adjusted_width), round(adjusted_height))

func propertyChanged(property: String, oldValue, newValue):
	match property:
		"options.changed":
			mainWindowSizeChanged()



func getZoom() -> Vector2:
	if camera == null:
		return Vector2.ZERO
	return camera.zoom

func getCam() -> Camera2D:
	return camera

func getUISubViewport() -> SubViewport:
	return _uiSubviewport

func hideBorder():
	$ViewportBorder.visible = false

func showBorder():
	$ViewportBorder.visible = true


var glowTween: Tween
func showGlow(side: = "bottom", length: = 1.6):
	if glowTween:
		glowTween.kill()
	glowTween = create_tween()
	glowTween.tween_property($SplitGlow.material, "shader_parameter/blend_%s" % side, 0.3, length * 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	glowTween.tween_property($SplitGlow.material, "shader_parameter/blend_%s" % side, 0, length * 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func setBorderAlpha(value: float):
	$ViewportBorder.modulate.a = value

func setBlendLeft(value: float):
	$SubViewportContainer.material.set_shader_parameter("blend_left", value)

func setScreenCoverActive(value):
	pass



func abortTeleportAnimation():
	if coverTween:
		coverTween.kill()
	setScreenCoverActive(false)

func display() -> void :
	show()

func conceal() -> void :
	hide()

var coverTween: Tween
var camTween: Tween
func startTeleportAnimation(time: float, from: Vector2, to: Vector2, cameraAnimationDelay: = 0.0):
	if cameraAnimationDelay > 0.0:
		if coverTween:
			coverTween.kill()
		coverTween = create_tween()
		coverTween.tween_callback(startTeleportAnimation.bind(time, from, to)).set_delay(cameraAnimationDelay)
		return

	var distance: float = from.distance_to(to)
	var camSpeed = remap(clamp(distance, 100, 1500), 100, 1500, 0.7, 2.5)






	var CAMERA: Camera2D = camera
	var SCREEN_COVER: TeleportingScreenspaceEffect = _worldCanvas.get_teleport_screenspace_effect()

	CAMERA.camMoveSpeed = 0.0
	CAMERA.zoomSpeed = 2.0 * camSpeed * 0.5
	var cameraMoveTime: float = max(time, 1.0)
	var camPosStart: Vector2 = CAMERA.position
	var camPosTarget: Vector2 = to
	var transLength: float = min(distance * 0.1, 100.0)
	var camPosStop1: Vector2 = camPosStart + Vector2(0, sign(camPosTarget.y - camPosStart.y) * transLength)
	var camPosStop2: Vector2 = camPosTarget + Vector2(0, sign(camPosStart.y - camPosTarget.y) * transLength)
	SCREEN_COVER.show()
	if camTween:
		camTween.kill()
	camTween = create_tween()
	camTween.set_parallel().tween_property(CAMERA, "position", camPosStop1, cameraMoveTime * 0.4).from(camPosStart).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	camTween.tween_property(CAMERA, "position", camPosStop2, cameraMoveTime * 0.2).set_delay(cameraMoveTime * 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	camTween.tween_property(CAMERA, "position", camPosTarget, cameraMoveTime * 0.4).set_delay(cameraMoveTime * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	camTween.tween_property(CAMERA, "camMoveSpeed", 1.0, 0.1).from(0.0).set_delay(cameraMoveTime).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	camTween.tween_property(CAMERA, "zoomSpeed", 2, 0.1).set_delay(cameraMoveTime).from(CAMERA.zoomSpeed).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	camTween.tween_callback(SCREEN_COVER.hide).set_delay(cameraMoveTime)

	var speed = 1.0 if from.y < to.y else -1.0
	SCREEN_COVER.material.set_shader_parameter("strength", 0.0)
	SCREEN_COVER.material.set_shader_parameter("speed", speed)

	var soundDelay = cameraMoveTime * 1.1 if cameraMoveTime > 1.2 else cameraMoveTime * 0.4
	if coverTween:
		coverTween.kill()
	coverTween = create_tween()
	coverTween.set_parallel().tween_callback(playTeleportSound.bind(cameraMoveTime <= 1.5)).set_delay(soundDelay)
	coverTween.tween_property(SCREEN_COVER.material, "shader_parameter/strength", 1.0, cameraMoveTime * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	coverTween.tween_property(SCREEN_COVER.material, "shader_parameter/fade_value", 0.2, cameraMoveTime * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	coverTween.tween_property(SCREEN_COVER.material, "shader_parameter/strength", 0.0, cameraMoveTime * 0.4).set_delay(cameraMoveTime * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	coverTween.tween_property(SCREEN_COVER.material, "shader_parameter/fade_value", 0.0, cameraMoveTime).set_delay(cameraMoveTime * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func playTeleportSound(upgraded: bool):
	if upgraded:
		find_child("TeleportFadeUpgrade").play()
	else:
		find_child("TeleportFade").play()


func pauseChanged():
	if GameWorld.paused:
		if camTween:
			camTween.pause()
		if coverTween:
			coverTween.pause()
		if glowTween:
			glowTween.pause()
	else:
		if camTween:
			camTween.play()
		if coverTween:
			coverTween.play()
		if glowTween and glowTween.is_valid():
			glowTween.play()

func getPlayerUICanvas() -> PlayerCanvas:
	return %PlayerCanvas

func getPlayerWorldCanvas() -> WorldCanvas:
	return _worldCanvas

func _on_mouse_entered() -> void :
	_uiSubviewport.notification(NOTIFICATION_VP_MOUSE_ENTER)
	_worldSubviewport.notification(NOTIFICATION_VP_MOUSE_ENTER)

func _on_mouse_exited() -> void :
	if is_queued_for_deletion():
		return
	_uiSubviewport.notification(NOTIFICATION_VP_MOUSE_EXIT)
	_worldSubviewport.notification(NOTIFICATION_VP_MOUSE_EXIT)

func _on_resized() -> void :
	mainWindowSizeChanged()


func hideContent() -> void :
	_curtain.show()


func _revealContent() -> void :
	_curtain.hide()
