class_name Vignette extends ColorRect

const DEFAULT_MAX_ALPHA: float = 0.7

var target: Node2D
var _relatedKeeper: Keeper

var strengthStartY: = 500.0
var strengthEndY: float

var modulateOnPlayerY: = true
var _forceShow: = false
var _forceHide: = false
var _last_alpha: float = 0.0
var viewportStretch: = 2.0

var light_cutout_texture: ViewportTexture = null
var _process_only_target: bool = false

func _ready():
	Data.listen(self, "map.depthpixels", true)
	Data.listen(self, "options.changed")
	Data.listen(self, "world.vignetteFixedStartAt")
	Data.listen(self, "world.vignetteFixedFullStrengthAt")
	Data.listen(self, "game.over")

	material.set_shader_parameter("brightness_bias", Data.ofOr("world.vignetteBrightnessBias", 3.0))
	material.set_shader_parameter("brightness_bands", Data.ofOr("world.vignetteBrightnessBands", 3))

	updateViewportStretch()
	if _disabledDueToOptions():
		hide()

func init(inRelatedKeeper: Keeper) -> void :
	_relatedKeeper = inRelatedKeeper
	var depthpixels: int = Data.ofOr("map.depthpixels", 0)
	_setTargetKeeper(_relatedKeeper, depthpixels)

func _setTargetKeeper(inKeeper: Keeper, newValue: float):
	setTarget(inKeeper, (1500 + newValue) * 0.5)

func setTarget(t, fullStrengthAt: = 1100, startAt: = 500):
	self.target = t
	if StageManager.isInLoadout() or StageManager.isInDeviceSelection():

		strengthStartY = startAt
		strengthEndY = fullStrengthAt
		return
	strengthStartY = Data.ofOr("world.vignetteFixedStartAt", startAt)
	strengthEndY = Data.ofOr("world.vignetteFixedFullStrengthAt", fullStrengthAt)

func processOnlyForTarget() -> void :
	_process_only_target = true

func propertyChanged(property: String, oldValue, newValue):
	match property:
		"map.depthpixels":
			if is_instance_valid(_relatedKeeper):
				_setTargetKeeper(_relatedKeeper, newValue)
		"options.changed":
			updateViewportStretch()
		"world.vignetteFixedStartAt":
			strengthStartY = Data.ofOr("world.vignetteFixedStartAt", strengthStartY)
		"world.vignetteFixedFullStrengthAt":
			strengthEndY = Data.ofOr("world.vignetteFixedFullStrengthAt", strengthEndY)
		"game.over":
			if newValue:
				foreceHide()

func updateViewportStretch():
	viewportStretch = 2.0 if Options.renderHalfRes else 1.0
	material.set_shader_parameter("viewport_stretch", 1.0 / viewportStretch)

func onGameLost():

	target = InputSystem.getCamera()

func _process(delta):
	if not light_cutout_texture:
		light_cutout_texture = Level.map.lights.get_texture()
		material.set_shader_parameter("light_cutouts", light_cutout_texture)

	if not is_instance_valid(target):
		target = null

	if not target or ( not _forceShow and (_disabledDueToOptions() or _forceHide)):
		Audio.enableDelayEffect(Audio.BUS_SOUNDS, false)
		hide()
		return

	visible = true

	var keepers: Array[Keeper] = Keepers.all.getAll()
	var viewport: Viewport = get_viewport()
	var lerp_offset: float = _calculateTargetLerpOffset(target, modulateOnPlayerY)
	var lerp_offset_related_keeper: float = _calculateTargetLerpOffset(_relatedKeeper, modulateOnPlayerY)
	var target_center_offsets_and_strengths: PackedVector4Array = PackedVector4Array()
	var strength: float = lerp(10.0, 2.0, lerp_offset)
	var offset_and_strength: Vector4 = _calc_offset_and_strength(viewport, strength, target)
	target_center_offsets_and_strengths.append(offset_and_strength)
	if not _process_only_target:
		for keeper: Keeper in keepers:
			if keeper == target:

				continue

			lerp_offset = _calculateTargetLerpOffset(keeper, modulateOnPlayerY)
			if _isDarkness():



				var surface_light_edge_y: float = 100
				var surface_influence_radius: float = 130
				var base_lerp_offset: float = lerp_offset
				var percent_close_to_surface_dst = abs(keeper.position.y - surface_light_edge_y) / surface_influence_radius
				percent_close_to_surface_dst = clampf(percent_close_to_surface_dst, 0.0, 1.0)
				var close_to_surface_factor = lerp(1.0, 0.5, percent_close_to_surface_dst)
				lerp_offset = (lerp_offset + close_to_surface_factor)
				lerp_offset = min(lerp_offset_related_keeper, lerp_offset)
				lerp_offset = max(base_lerp_offset, lerp_offset)
			strength = lerp(10.0, 2.0, lerp_offset)
			offset_and_strength = _calc_offset_and_strength(viewport, strength, keeper)
			target_center_offsets_and_strengths.append(offset_and_strength)

	material.set_shader_parameter("nmb_of_targets", target_center_offsets_and_strengths.size())
	material.set_shader_parameter("target_center_offsets_and_strengths", target_center_offsets_and_strengths)

	var aspect_ratio = size.x / size.y
	material.set_shader_parameter("aspect_ratio", aspect_ratio)
	var z = InputSystem.getCamera().zoom * Data.ofOr("world.vignetteLightScale", 1.0)
	material.set_shader_parameter("zoom", Vector2(1.0 / z.x, 1.0 / z.y))
	var alpha: float = lerp(0.0, Data.ofOr("world.vignetteMaxAlpha", DEFAULT_MAX_ALPHA), lerp_offset_related_keeper)
	_set_alpha(alpha)
	updateVignetteLightCutout()

func _calc_offset_and_strength(in_viewport: Viewport, in_strength: float, in_target: Node2D) -> Vector4:
	var viewport_local_pos: Vector2 = in_viewport.get_canvas_transform() * in_target.global_position
	var viewport_local_center_local_point: Vector2 = in_viewport.get_visible_rect().size / 2.0
	var relative_to_center: Vector2 = viewport_local_pos - viewport_local_center_local_point
	var viewport_half_size: Vector2 = in_viewport.get_visible_rect().size * 0.5
	var screen_center_uv_offset: Vector2 = (relative_to_center / viewport_half_size) * 0.5
	return Vector4(screen_center_uv_offset.x, screen_center_uv_offset.y, in_strength, 0)

func _set_alpha(value: float):
	var crossed_threshold: bool = (_last_alpha <= DEFAULT_MAX_ALPHA) != (value <= DEFAULT_MAX_ALPHA)
	if crossed_threshold:
		Audio.enableDelayEffect(Audio.BUS_SOUNDS, value > DEFAULT_MAX_ALPHA)

	material.set_shader_parameter("vignette_alpha", value)
	_last_alpha = value


func _calculateTargetLerpOffset(inTarget: Node2D, inModulateOnPlayerY: bool) -> float:
	var viewport: Viewport = get_viewport()
	var globalCamPos = viewport.get_camera_2d().global_position
	var y: float
	if inModulateOnPlayerY:
		y = inTarget.position.y
	else:
		y = globalCamPos.y

	if target == inTarget:
		visible = y >= strengthStartY
	var lerp_offset: float = max(0, y - strengthStartY) / (strengthEndY - strengthStartY)
	lerp_offset = clamp(lerp_offset, 0.0, 1.0)

	lerp_offset = ease(lerp_offset, -4.0)
	return lerp_offset

func updateVignetteLightCutout():
	var window_size: Vector2 = get_tree().root.size
	var viewport: Viewport = get_viewport()
	var multi = window_size / Vector2(viewport.size_2d_override)
	var size_multi: Vector2 = window_size / Vector2(StageManager.currentStage.get_viewport().size) * min(multi.x, multi.y)
	var cam_2d: Camera2D = viewport.get_camera_2d()
	var window_size_div_cam_zoom: Vector2 = window_size / cam_2d.zoom / size_multi
	var light_sprite: Sprite2D = Level.map.lights.sprite
	var light_sprite_size: Vector2 = light_sprite.texture.get_size()
	var coverage_ratio: Vector2 = _calc_viewport_screen_coverage_ratio(viewport)
	var normalized_coverage_ratio = coverage_ratio / max(coverage_ratio.x, coverage_ratio.y)
	window_size_div_cam_zoom *= normalized_coverage_ratio

	var light_cutout_offset = (cam_2d.global_position - light_sprite.position - window_size_div_cam_zoom * 0.5) / (light_sprite_size)
	var light_cutout_scale = window_size_div_cam_zoom / light_sprite_size
	light_cutout_scale = Vector2.ONE * 100
	light_cutout_offset = Vector2.ZERO
	material.set_shader_parameter("light_cutout_scale", light_cutout_scale)
	material.set_shader_parameter("light_cutout_offset", light_cutout_offset)

func _calc_viewport_screen_coverage_ratio(inViewport: WorldViewport) -> Vector2:
	var rootViewport: Viewport = get_tree().root
	var rootSize: Vector2 = rootViewport.get_visible_rect().size
	var container: = inViewport.get_viewport_container()
	var rect: = container.get_global_rect()
	return Vector2(rect.size.x / rootSize.x, rect.size.y / rootSize.y)

func forceShow():
	_forceShow = true

func foreceHide():
	_forceHide = true

func stop() -> void :
	visible = false
	set_process(false)

func _on_visibility_changed() -> void :
	if visible:
		return
	var mineCamera: bool = StageManager.isInResolvedLevel()
	if mineCamera:
		return
	if _isDarkness():
		visible = true

func _isDarkness() -> bool:
	var isGuild: bool = Level.loadout.modeConfig.has(CONST.MODE_CONFIG_ASSIGNMENT)
	if not isGuild:
		return false

	var isMinorVisionAssignment: bool = CONST.MODE_ASSIGNMENT_MINOR_VISION == \
	Level.loadout.modeConfig[CONST.MODE_CONFIG_ASSIGNMENT]
	return isMinorVisionAssignment

func _disabledDueToOptions() -> bool:
	return Options.disableVignette and not _isDarkness()
