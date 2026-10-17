class_name FlakGunParticles extends GPUParticles2D

const PHYSICS_MATERIAL_PATH: String = "res://content/weapons/artillery/flakgunparticles/flak_particles_physical_process_material.tres"
const SIMPLE_MATERIAL_PATH: String = "res://content/weapons/artillery/flakgunparticles/flak_particles_simple_process_material.tres"
const SIMPLE_PROCESS_LIFETIME = 0.8
var SIMPLE_PARTICLES_LOWEST_RIGHT_DIR: Vector2 = Vector2.RIGHT
var SIMPLE_PARTICLES_LOWEST_LEFT_DIR: Vector2 = Vector2.LEFT

@export var styleColor: Color = Color("#70aac8")

var _point_count: int = 1
var _points_img: Image
var _normals_img: Image
var _points_tex: ImageTexture
var _normals_tex: ImageTexture
var _reload_speed: float = 0.0
var _nmb_of_shell_spawn_points: int = 0
var _is_using_simple_process_material: bool

@onready var _amount_calculation_delayer: Timer = $AmountCalculationDelayer

func _enter_tree():
	add_to_group("customStyle")

func _ready() -> void :
	assert (process_material.resource_path == PHYSICS_MATERIAL_PATH, PHYSICS_MATERIAL_PATH + " should be set by deault")
	emitting = false
	_is_using_simple_process_material = OS.has_feature("SEAVEN")
	if _is_using_simple_process_material:
		var _base_process_lifetime: float = lifetime
		var lifetime_factor: float = SIMPLE_PROCESS_LIFETIME / _base_process_lifetime
		amount *= lifetime_factor
		lifetime = SIMPLE_PROCESS_LIFETIME
		process_material = load(SIMPLE_MATERIAL_PATH)
	else:
		process_material = process_material.duplicate()
	Style.init(self)
	_init_directed_points(_point_count)

func updateStyleColor():
	modulate = Style.mapColor(styleColor).lightened(0.4)
	material.set_shader_parameter("palette", Style.palette)

func update_weapon_particles(in_reload_speed: float, in_nmb_of_shell_spawn_points: int, 
			in_shell_spawn_positions: PackedVector2Array, in_shell_normals: PackedVector2Array) -> void :
	if in_nmb_of_shell_spawn_points == 0:
		emitting = false
		_nmb_of_shell_spawn_points = in_nmb_of_shell_spawn_points
		return

	var new_gun_activated: = _nmb_of_shell_spawn_points != in_nmb_of_shell_spawn_points
	_reload_speed = in_reload_speed
	_nmb_of_shell_spawn_points = in_nmb_of_shell_spawn_points
	if new_gun_activated:
		amount_ratio = 1.0
		_amount_calculation_delayer.start(0.03)
		if emitting == false:
			emitting = true

	if _point_count != in_nmb_of_shell_spawn_points:
		_set_point_count_and_rebuild(in_nmb_of_shell_spawn_points)

	for idx: int in _point_count:
		var normal: Vector2 = - in_shell_normals[idx].normalized()
		if _is_using_simple_process_material:
			var dot: float = normal.dot(Vector2.DOWN)
			if dot >= 0.0:
				normal = SIMPLE_PARTICLES_LOWEST_LEFT_DIR if normal.x < 0.0 else SIMPLE_PARTICLES_LOWEST_RIGHT_DIR

		_set_directed_point(idx, to_local(in_shell_spawn_positions[idx]), normal)

func _set_point_count_and_rebuild(count: int) -> void :
	_point_count = count
	_init_directed_points(_point_count)

func _on_amount_calculation_delayer_timeout() -> void :


	_updateEjectShellAmountRatio(_reload_speed, _nmb_of_shell_spawn_points)

func _updateEjectShellAmountRatio(in_reload_speed: float, in_nmb_of_spawn_points: int) -> void :
	const SHORTEST_FIRE_DELAY: = 0.05
	const LONGEST_FIRE_DELAY: = 0.17
	const PARTICLE_RATIO_AT_SHORT: = 0.25
	const PARTICLE_RATIO_AT_LONG: = 0.125
	var newAmountRatio = remap(in_reload_speed, SHORTEST_FIRE_DELAY, LONGEST_FIRE_DELAY, 
		PARTICLE_RATIO_AT_SHORT, PARTICLE_RATIO_AT_LONG)
	var ratio: float = newAmountRatio * in_nmb_of_spawn_points
	amount_ratio = newAmountRatio * in_nmb_of_spawn_points
	assert (amount_ratio >= 0.0 and amount_ratio <= 1.0, "ratio should always be in 0-1 range")

func _init_directed_points(count: int) -> void :
	assert (count > 0, "at least one emission point is needed")

	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	process_material.emission_point_count = count

	_points_img = Image.create(count, 1, false, Image.FORMAT_RGBAF)
	_normals_img = Image.create(count, 1, false, Image.FORMAT_RGBAF)

	for i in count:
		_points_img.set_pixel(i, 0, Color(0.0, 0.0, 0.0, 1.0))
		_normals_img.set_pixel(i, 0, Color(1.0, 0.0, 0.0, 1.0))

	_points_tex = ImageTexture.create_from_image(_points_img)
	_normals_tex = ImageTexture.create_from_image(_normals_img)

	process_material.emission_point_texture = _points_tex
	process_material.emission_normal_texture = _normals_tex

func _set_directed_point(index: int, local_pos: Vector2, direction: Vector2) -> void :
	assert (index > -1 and index < _point_count, "Point index out of range: %d" % index)
	if _points_tex == null or _normals_tex == null:
		_init_directed_points(_point_count)

	var dir: = direction
	if dir.length_squared() > 0.0:
		dir = dir.normalized()
	else:
		dir = Vector2(1, 0)

	_points_img.set_pixel(index, 0, Color(local_pos.x, local_pos.y, 0.0, 1.0))
	_normals_img.set_pixel(index, 0, Color(dir.x, dir.y, 0.0, 1.0))

	_points_tex.update(_points_img)
	_normals_tex.update(_normals_img)
