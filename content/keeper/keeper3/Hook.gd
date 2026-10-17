extends RigidBody2D

class_name HookKunai

signal on_connected(Vector2)
signal rope_detached()

var has_hit: = false
var keeper: Keeper
var lastVelocity: Vector2 = Vector2.ZERO
var can_connect: bool = true
var fade_triggered: = false
var fade_duration: = 0.3
var fade_timer: = 0.0
var detach_requested: = false

var chain_rope

var lastPos: Vector2
var lastPosInitialized: = false

@onready var kunaiSprite: Node2D = $KunaiSprite
@onready var chainAnchor: Node2D = $ChainAnchor
@onready var ropeFastenSound = $RopeFasten
@onready var ropeReleaseSound = $RopeRelease

var attached_target: Node
var _attached_target_destroyed_callable: Callable = Callable()
var _attached_target_tree_exited_callable: Callable = Callable()

func updateStyleColor():
	$Sparks.material.set_shader_parameter("palette", Style.palette)

func get_chain_anchor_node() -> Node2D:
	if is_instance_valid(chainAnchor):
		return chainAnchor
	return self

func _set_attached_target(node: Object) -> void :
	var target_node: Node = node if node is Node else null
	_disconnect_attached_target()
	if not is_instance_valid(target_node):
		return
	attached_target = target_node
	if attached_target.has_signal("destroyed"):
		_attached_target_destroyed_callable = Callable(self, "_on_attached_target_destroyed")
		if not attached_target.is_connected("destroyed", _attached_target_destroyed_callable):
			attached_target.connect("destroyed", _attached_target_destroyed_callable)
	if attached_target.has_signal("tree_exited"):
		_attached_target_tree_exited_callable = Callable(self, "_on_attached_target_tree_exited")
		if not attached_target.is_connected("tree_exited", _attached_target_tree_exited_callable):
			attached_target.connect("tree_exited", _attached_target_tree_exited_callable)

func _disconnect_attached_target() -> void :
	if attached_target and is_instance_valid(attached_target):
		if _attached_target_destroyed_callable.is_valid() and attached_target.has_signal("destroyed") and attached_target.is_connected("destroyed", _attached_target_destroyed_callable):
			attached_target.disconnect("destroyed", _attached_target_destroyed_callable)
		if _attached_target_tree_exited_callable.is_valid() and attached_target.has_signal("tree_exited") and attached_target.is_connected("tree_exited", _attached_target_tree_exited_callable):
			attached_target.disconnect("tree_exited", _attached_target_tree_exited_callable)
	attached_target = null
	_attached_target_destroyed_callable = Callable()
	_attached_target_tree_exited_callable = Callable()

func _cleanup_chain() -> void :
	_disconnect_attached_target()
	if not is_instance_valid(chain_rope):
		chain_rope = null
		return
	if chain_rope.is_queued_for_deletion():
		chain_rope = null
		return
	chain_rope.begin_detach()
	chain_rope = null

func _has_active_chain() -> bool:
	if chain_rope == null:
		return false
	if not is_instance_valid(chain_rope):
		chain_rope = null
		return false
	if chain_rope.is_queued_for_deletion():
		return false
	return true

func _ready() -> void :
	contact_monitor = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	max_contacts_reported = 1
	_apply_background_depth()
	Style.init(self)

func _physics_process(delta: float) -> void :
	if GameWorld.paused:
		return
	if not has_hit:
		_update_rotation_from_velocity()
		_process_high_precision_collision()
	if detach_requested:
		_cleanup_chain()
	elif has_hit and not _has_active_chain():
		request_detach()
	if has_hit and detach_requested and not fade_triggered:
		trigger_rope_fade()
	if fade_triggered:
		fade_timer += delta
		if fade_timer >= fade_duration:
			queue_free()

func _process_high_precision_collision() -> void :
	if not lastPosInitialized:
		lastPos = global_position
		lastPosInitialized = true
		return
	var from: Vector2 = lastPos
	var to: Vector2 = global_position
	lastPos = global_position
	if from.distance_to(to) <= 0.05:
		return
	var res: Dictionary = HighPrecisionCollision.sweep_and_snap(self, Keeper3GameplaySettings.HOOK_COLLISION_RADIUS, from, to, [get_rid()])
	if res.get("collided", false):
		var impact_normal_value: Variant = res.get("normal", null)
		var impact_normal: Vector2 = impact_normal_value if impact_normal_value is Vector2 else Vector2.ZERO
		if res.has("snap_position"):
			global_position = res.snap_position
			lastPos = global_position
		var impact_collider: Object = res.get("collider", null)
		connectHook(impact_normal, impact_collider)

func _update_rotation_from_velocity() -> void :
	var velocity: Vector2 = linear_velocity
	if velocity.length_squared() > Keeper3GameplaySettings.HOOK_ROTATION_VELOCITY_EPS:
		lastVelocity = velocity
	if lastVelocity.length_squared() > Keeper3GameplaySettings.HOOK_ROTATION_VELOCITY_EPS:
		rotation = lastVelocity.angle() + PI * 0.5

func _apply_surface_stick_rotation(hit_normal: Vector2) -> void :
	var forward: Vector2 = lastVelocity
	if forward.length_squared() <= Keeper3GameplaySettings.HOOK_ROTATION_VELOCITY_EPS:
		if hit_normal.length_squared() == 0.0:
			return
		forward = - hit_normal.normalized()
	else:
		forward = forward.normalized()
	var base_angle: float = forward.angle() + PI * 0.5
	rotation = base_angle
	_apply_background_depth()

func _apply_background_depth() -> void :
	z_index = Keeper3GameplaySettings.HOOK_STICK_Z_INDEX
	if is_instance_valid(kunaiSprite):
		kunaiSprite.z_index = Keeper3GameplaySettings.HOOK_STICK_Z_INDEX

func _spawn_tile_burst_vfx(normal: Vector2, spawn_dirt: bool = true) -> void :
	var parent: Node = get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var effect: Node2D = Keeper3SecondarySettings.HOOK_TILE_BURST_VFX.instantiate()
	var offset_normal: Vector2 = normal.normalized() if normal.length_squared() > 0.0 else Vector2.ZERO
	parent.add_child(effect)
	effect.global_position = global_position + offset_normal * 2.0
	if effect.has_method("setup"):
		effect.setup(normal)
	_spawn_impact_particles(global_position, normal, parent, spawn_dirt)

func _spawn_impact_particles(hit_point: Vector2, normal: Vector2, parent: Node, spawn_dirt: bool = true) -> void :
	var impact_rotation: float = normal.angle() if normal.length_squared() > 0.0 else 0.0

	var spark_amount: = 4
	if Options.reducedParticles:
		spark_amount = 2
	for _i in range(spark_amount + randi() % 2):
		var s = Data.KEEPER_SPARK.instantiate()
		s.global_position = hit_point
		parent.add_child(s)
		s.apply_central_impulse(Vector2.RIGHT.rotated(impact_rotation + randf_range(-0.5, 0.5)) * randf_range(20, 100))

	if not spawn_dirt:
		return

	var inward_normal: = - normal if normal.length_squared() > 0.0 else Vector2.ZERO
	var sample_point: = hit_point + inward_normal * Keeper3GameplaySettings.HOOK_COLLISION_RADIUS
	var tile_coord: Vector2 = Vector2(Level.map.getTileCoord(sample_point))
	var tile: Node = Level.map.getTile(tile_coord)

	var dirt_color: Color = Level.map.getBiomeColorByCoord(tile_coord)
	var tile_type = tile.type if tile != null and "type" in tile else ""

	var dirt_amount: = 2
	if Options.reducedParticles:
		dirt_amount = 1
	for _i in range(dirt_amount + randi() % 2):
		var t = Data.TILE_DIRT_PARTICLE.instantiate()
		t.modulate = dirt_color
		t.type = tile_type
		t.global_position = hit_point
		parent.add_child(t)
		t.apply_central_impulse(Vector2.RIGHT.rotated(impact_rotation + randf_range(-0.7, 0.7)) * randf_range(40, 100))

func set_keeper(player: Keeper) -> void :
	keeper = player

func begin_travel_chain() -> void :
	if not is_instance_valid(keeper):
		return
	if chain_rope:
		return
	detach_requested = false
	chain_rope = Keeper3SecondarySettings.HOOK_CHAIN_ROPE_SCRIPT.new()
	chain_rope.connect("rope_ready", Callable(self, "_on_chain_ready"))
	chain_rope.connect("rope_finished", Callable(self, "_on_chain_finished"))
	chain_rope.connect("rope_detached", Callable(self, "_on_chain_detached"))
	var spawn_pivot: Node2D = keeper.getChainSpawnNode()
	var parent: Node = get_parent()
	if parent:
		parent.add_child(chain_rope)
		chain_rope.setup_for_travel(keeper, self, spawn_pivot)
	else:
		add_child(chain_rope)
		chain_rope.setup_for_travel(keeper, self, spawn_pivot)

func connectHook(impact_normal: Vector2 = Vector2.ZERO, impact_collider: Object = null) -> void :
	if has_hit:
		return
	detach_requested = false
	has_hit = true
	freeze = true
	sleeping = true
	$Sparks.emitting = false
	if is_instance_valid(ropeFastenSound):
		ropeFastenSound.startSound()
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_apply_surface_stick_rotation(impact_normal)
	var is_dome: bool = false
	if impact_collider is CollisionObject2D:
		var collider: = impact_collider as CollisionObject2D
		is_dome = collider.get_collision_layer_value(4) or collider.get_collision_layer_value(10)
	_spawn_tile_burst_vfx(impact_normal, not is_dome)
	if impact_collider is Node:
		_set_attached_target(impact_collider)
	else:
		_set_attached_target(null)
	if not chain_rope:
		begin_travel_chain()
	if chain_rope:
		chain_rope.start_retraction(Keeper3GameplaySettings.HOOK_RETRACTION_DELAY)
	if can_connect:
		on_connected.emit(global_position)

func _on_attached_target_destroyed(_teamId: String, _keeperTechId: String) -> void :
	_handle_attached_target_removed()

func _on_attached_target_tree_exited() -> void :
	_handle_attached_target_removed()

func _handle_attached_target_removed() -> void :
	_disconnect_attached_target()
	if detach_requested:
		return
	if is_instance_valid(keeper) and keeper.has_method("releaseHookInput"):
		keeper.releaseHookInput()
	else:
		request_detach()

func _on_chain_ready(ball) -> void :
	if is_instance_valid(keeper):
		keeper.attach_to_chain(chain_rope, ball)

func _on_chain_finished() -> void :
	if detach_requested:
		trigger_rope_fade()

func _on_chain_detached() -> void :
	if is_instance_valid(keeper):
		keeper.detach_from_chain()
	chain_rope = null
	if detach_requested:
		return
	detach_requested = true
	if is_instance_valid(ropeReleaseSound):
		ropeReleaseSound.startSound()
	visible = false
	_cleanup_chain()
	trigger_rope_fade()

func trigger_rope_fade() -> void :
	if fade_triggered:
		return
	fade_triggered = true
	fade_timer = 0.0
	_cleanup_chain()
	rope_detached.emit()

func ignore_hook() -> void :
	can_connect = false
	_cleanup_chain()
	queue_free()

func _on_body_entered(body: Node) -> void :
	pass

func _notification(what: int) -> void :
	if what == NOTIFICATION_PREDELETE:
		_cleanup_chain()

func request_detach() -> void :
	if detach_requested:
		return
	detach_requested = true
	if is_instance_valid(ropeReleaseSound):
		ropeReleaseSound.startSound()
	_cleanup_chain()
	if has_hit:
		trigger_rope_fade()
	else:
		queue_free()
